---
tags: [pipeline, data-format, buffer, compression, keyframesequence, type/guide, area/animation, level/advanced, api/Animator, area/data]
---
# Clip Buffer Format

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Bumping the format without bumping the version byte.
> - Avoid: Decoding on every play. Symptom: hitches on first play of each move, repeated.
> - Avoid: Base64 decoding with a hand-written Luau function.
>
> Cost: TL;DR ~90 tok · whole note ~4.5k tok. Read more: ## Layout · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

The byte-level format ("v2") one production game used to store KeyframeSequence motion compactly: in a base64 attribute on Pose-less stubs ([[Baked Clip Stubs and Archiving]]), and as the payload streamed from server to clients for enemy kits ([[Lua Keyframe Player]]). It is designed around the Roblox `buffer` type, decodes in plain Luau, and plays back within 0.03 deg / 0.002 studs of the original clip in the player that reads it. This note documents every field, the easing codes, the thinning that decides which keys are written, and smallest-three [[Quaternions|quaternion]] packing, with a worked hex example.

All multi-byte values are little-endian, as the `buffer` library reads and writes them. `str` = a `u8` length followed by that many bytes (names longer than 255 bytes are truncated).

## Layout

```
offset  type          field
------  ------------  ---------------------------------------------------------------
0       u8            version = 2
1       f32           length (seconds)
5       u8            loop (1 / 0)
6       u8            priority = Enum.AnimationPriority value % 256
7       u16           nTimes
        f32[nTimes]   times: every distinct key time of the clip, sorted
        u16           nEvents
        nEvents x {   f32 t, u8 kind (0 marker, 1 named keyframe), str name, str value }
        u16           nJoints
        nJoints x {
            str       joint name (or a "Part0\0Part1" key for weapon rigs)
            u8        flags: 1 = nlerp mode, 2 = animated offset, 4 = per-key ease, 8 = constant offset
            u16       nKeys
            [flags 2 or 8]  f32 offset scale S (the largest |component| of any kept offset)
            [flag 8]        i16 x 3 the constant offset, each = round(component / S * 32767)
            nKeys x {
                u16          timeIndex | (droppedComponent << 14)
                i16 x 3      the three smaller quaternion components, each = round(c * 32767 / sqrt(0.5))
                [flag 2]     i16 x 3 offset, each = round(component / S * 32767)
                [flag 4]     u8 ease code
            }
            [not flag 4]    u8 ease code shared by every key
        }
```

Bytes 5 and 6 sit at fixed offsets on purpose: the server patches them from the stub instance before shipping, so editing a stub's `Loop` or `Priority` after baking does not require re-encoding.

### Field notes

- **Times are shared.** The time table is the union of every joint's original key times, written once as f32; keys refer to it by index. Identical times across joints cost 2 bytes per key, not 4. The index has 14 bits, so a clip may have at most **16,384** distinct key times (the encoder asserts it).
- **Events** keep markers and named keyframes. Marker values are stored as strings (`tostring(value)`), names and values each at most 255 bytes.
- **Joint names** are whatever the reading player binds by: the Pose name for characters and enemies, `Part0 .. "\0" .. Part1` for weapon rigs.
- **Flag 1 (nlerp mode)** records which interpolation the source clip used (quaternion nlerp for evenly spaced Linear sequences, rotation-vector blend otherwise, see [[Lua Keyframe Player Internals]]). The decoder does not re-derive it from the stored times, because thinning changes the spacing: the mode belongs to the original clip.
- **Flags 2 and 8 (offsets).** A joint whose kept keys all share one non-zero offset stores it once (flag 8); a joint whose offset changes stores one per key (flag 2); a joint with no offset stores nothing. `S` is the largest absolute offset component over the kept keys, so precision scales with the joint's own range: resolution is `S / 32767` studs.
- **Flag 4 (ease).** If every kept key has the same ease code, one byte after the keys; otherwise one byte per key.

## Ease codes

| Code | Pose easing (as the Animator plays it) |
|---|---|
| 0 | Linear |
| 1 | Constant, In: jumps to the next key at once |
| 2 | Constant, Out: holds until the next key |
| 3 | Constant, InOut: jumps at the segment's midpoint |
| 4 | cubic In curve (`CubicV2` In, or legacy `Cubic` **Out**, which plays reversed) |
| 5 | cubic Out curve (`CubicV2` Out, or legacy `Cubic` **In**) |
| 6 | cubic InOut |
| 7 / 8 / 9 | Elastic In / Out / InOut |
| 10 / 11 / 12 | Bounce In / Out / InOut |

The codes describe the **played curve**, not the Pose property: the legacy Cubic's reversal is resolved at encode time. A segment eases by its first key's code. Elastic and Bounce are mapped without reversal by the general player; the weapon rig player maps 7 to 12 back to its own (reversed) reading, so each player round-trips its own behaviour. The pipeline never authors Elastic or Bounce ([[Open Questions]]).

## Smallest-three quaternion packing

A unit quaternion `(x, y, z, w)` has four components but three degrees of freedom. The largest-magnitude component is always at least 0.5 (if all four were smaller, the squares would sum to less than 1), and the other three are each at most `sqrt(0.5)` in magnitude. So:

1. Find the component with the largest magnitude. If it is negative, negate the whole quaternion (q and -q are the same rotation), making it positive.
2. Store its index (0 = x, 1 = y, 2 = z, 3 = w) in the top two bits of the key's `u16`.
3. Store the other three, in order, as `i16 = round(c * 32767 / sqrt(0.5))`, so the full range `[-sqrt(0.5), sqrt(0.5)]` uses `[-32767, 32767]`.

Decoding:

```lua
local Q3 = 32767 / math.sqrt(0.5)
local h = buffer.readu16(b, o); o += 2
local timeIndex = bit32.band(h, 16383)          -- low 14 bits
local dropped = bit32.rshift(h, 14)             -- 0..3
local a = buffer.readi16(b, o) / Q3
local c1 = buffer.readi16(b, o + 2) / Q3
local c2 = buffer.readi16(b, o + 4) / Q3
o += 6
local d = math.sqrt(math.max(0, 1 - a * a - c1 * c1 - c2 * c2))   -- the dropped component, positive by construction
local x, y, z, w
if dropped == 0 then x, y, z, w = d, a, c1, c2
elseif dropped == 1 then x, y, z, w = a, d, c1, c2
elseif dropped == 2 then x, y, z, w = a, c1, d, c2
else x, y, z, w = a, c1, c2, d end
local m = math.sqrt(x * x + y * y + z * z + w * w)
x, y, z, w = x / m, y / m, z / m, w / m
if w < 0 then x, y, z, w = -x, -y, -z, -w end   -- canonical sign, as a Pose CFrame reads back
```

Precision: one step is `sqrt(0.5) / 32767` = about 2.2e-5 per component, an angular resolution of roughly 0.003 deg. Six bytes per rotation instead of nine floats of rotation matrix (36 bytes as f32) or a full Pose instance.

Why canonicalise to `w >= 0` on decode: the player converts each key to a rotation vector, and the Animator's rotation-vector blend depends on which representation a key is held in. Matching the sign a Pose's CFrame would give keeps decoded keys identical to parsed ones.

## Thinning: which keys get written

A key is dropped only when **the joint's own interpolation between the kept neighbours reproduces it, and every midpoint between original keys, within 0.03 deg and 0.002 studs**. Greedy, per joint:

```
keep = { 1 }; a = 1; b = 2
while b < n:
    c = b + 1
    ok = (c - a <= 48)                                     -- bounded runs keep it O(n)
    ok = ok and every segment from a to c-1 is Linear      -- eased keys are never merged away
    ok = ok and no segment from a to c-1 needs a hemisphere / representation flip
    ok = ok and interpolating a -> c keeps the flip-free representation
    ok = ok and every original key strictly between a and c is reproduced within tolerance
    ok = ok and every midpoint between consecutive original keys is reproduced within tolerance
    if ok: b = c                                           -- extend the run
    else: keep b; a = b; b = a + 1
keep n
```

Design reasons:

- **Only Linear runs merge.** Dropping a key between eased segments changes the curve's shape in ways a pointwise check at key times can miss; in practice dense baked clips are Linear and authored sparse clips are eased, so this loses nothing.
- **No merging across a representation flip.** If two neighbours need the negated quaternion (nlerp) or the flipped rotation vector (rotation-vector mode) to interpolate the short way, a merged span could pick a different pair and take the long way. Every kept key therefore reads back exactly as the Animator holds it.
- **Midpoints are checked against the original curve**, not just the dropped keys, so a merge cannot bow away from the original between keys.
- **Runs are capped at 48 keys**, so the cost stays linear.
- The time table still lists all original times; dropped keys simply never reference them.

Options: `tolDeg`, `tolPos`, `rvOnly` (thin as rotation vectors whatever the mode), `yield` (a callback the encoder calls every 4 ms, so Studio can bake many clips without freezing), and `clip` (encode an already-parsed clip table: the weapon-part baker passes the rig player's own reading).

Typical thinning on dense enemy clips keyed at 16-25 fps was large; combined with packing, a kit came to 19-235 KB.

## Worked example

A 1-second clip, priority Action, not looped, keyframes at 0, 0.5 and 1.0, a marker `Hit` at 0.5, one joint `RightUpperArm` keyed at identity, then 60 deg about X, then identity, all Linear (so the sequence is evenly spaced and Linear: nlerp mode).

```
02                                   version
00 00 80 3F                          length 1.0
00                                   loop = false
02                                   priority Action (2)
03 00                                nTimes = 3
00 00 00 00  00 00 00 3F  00 00 80 3F    times 0.0, 0.5, 1.0
01 00                                nEvents = 1
00 00 00 3F  00  03 48 69 74  00     t 0.5, kind marker, "Hit", value ""
01 00                                nJoints = 1
0D 52 69 67 68 74 55 70 70 65 72 41 72 6D   "RightUpperArm"
01                                   flags: nlerp mode only (no offsets, shared ease)
03 00                                nKeys = 3
00 C0  00 00 00 00 00 00             key: time 0, dropped w (3 << 14 = 0xC000), x = y = z = 0
01 C0  82 5A 00 00 00 00             key: time 1, dropped w; x = 0.5 -> round(0.5 * 46340) = 23170 = 0x5A82
02 C0  00 00 00 00 00 00             key: time 2, identity
00                                   shared ease: Linear
```

77 bytes (104 as base64). The same clip as instances: the KeyframeSequence, 3 Keyframes, 12 Poses (HumanoidRootPart, LowerTorso and UpperTorso placeholders plus the arm pose, per keyframe) and a marker: 17 instances.

60 deg about X is the quaternion `(sin 30, 0, 0, cos 30)` = `(0.5, 0, 0, 0.866)`: w is largest, positive, dropped; x is stored.

## Encoding sketch

```lua
local function encodeClip(clip): buffer
	local b, o = buffer.create(8192), 0
	local function need(n: number)                         -- grow by doubling
		if o + n > buffer.len(b) then
			local nb = buffer.create(math.max(buffer.len(b) * 2, o + n))
			buffer.copy(nb, 0, b, 0, o)
			b = nb
		end
	end
	local function u8(v) need(1); buffer.writeu8(b, o, v); o += 1 end
	local function u16(v) need(2); buffer.writeu16(b, o, v); o += 2 end
	local function f32(v) need(4); buffer.writef32(b, o, v); o += 4 end
	local function i16(v) need(2); buffer.writei16(b, o, math.clamp(math.floor(v + 0.5), -32767, 32767)); o += 2 end
	local function str(s) s = string.sub(s, 1, 255); u8(#s); need(#s); buffer.writestring(b, o, s); o += #s end
	-- header, times, events, then per joint: name, flags, nKeys, [scale], [constant], keys, [shared ease]
	-- ... (see the layout above) ...
	local out = buffer.create(o)
	buffer.copy(out, 0, b, 0, o)                           -- trim to size
	return out
end
```

Stored in an attribute as base64 text (`buffer.tostring(EncodingService:Base64Encode(buf))` in Studio); the client-side player decodes base64 with a small table-driven decoder into a `buffer` and reads it with `buffer.read*`.

## Limits and evolution

- 16,384 distinct times per clip; 65,535 joints, keys per joint, events (u16 counts); 255-byte names.
- Offsets quantise to `S / 32767` per joint: a joint that translates 10 studs gets 0.0003-stud steps, fine; but the error budget used for stubs counts 0.01 studs as 1 deg, and very large translations combined with rounding pushed one weapon kit to 0.28-0.31 against a 0.25 bar.
- **Version byte first.** Any change bumps it; decoders assert it. Keep old decoders around until every stored buffer is rebaked.
- Things v2 does not store: per-pose weights (only keys, i.e. weight > 0, are written), Pose names of placeholders, the hierarchy (players match joints by name), `AuthoredHipHeight` (kept on the stub instance instead).

## See also

[[Baked Clip Stubs and Archiving]], [[Lua Keyframe Player Internals]], [[Weapon Rig Player]], [[Keyframes, Easing and Interpolation]], [[Performance and Memory]], [[Snippets - Building and Sampling Clips]]

## Nuances and edge cases

1. **When a binary format is not worth it.** For a game with 30 published clips, all of this is overhead: published animations cost nothing in the place and replicate for free. The format pays off when clip counts reach the hundreds, when clips are streamed to clients on demand, or when Pose instance counts are hurting Studio. Decide on clip count and churn, not on elegance.
2. **Base64 in attributes vs raw buffers on remotes.** Storing in an attribute needs text, so base64 adds about 33 percent. Sending to clients over a RemoteEvent can carry a `buffer` directly (Roblox supports buffers as remote arguments; check current limits on create.roblox.com before relying on large payloads). A sensible split is base64 at rest in the place, raw buffers on the wire.
3. **Payload sizes at scale.** A typical 2 second, 25-joint clip encodes to a few kilobytes after thinning. An enemy kit with 20 clips is tens of kilobytes. Sending every kit to every client at join on a 50-player server is fine; sending all 40 kits to a phone on mobile data at join is a slow join. Stream kits on demand as enemies appear, and cache per session.
4. **Quantisation error compounds down chains.** Each joint's i16 quaternion error is tiny (around 0.004 degrees per component at 32767 steps over the sqrt(0.5) range, by calculation). Down a six-joint arm chain the errors add, so a hand can be off by roughly six times that. Still invisible for characters; possibly visible for a long weapon or tail with 15 or more joints. Test long chains specifically.
5. **Float32 times and long clips.** f32 gives about 7 significant digits. A 60 second cutscene keyed at 1/60 s stores times like 59.983333 with error well under a millisecond, so fine. Clips over several minutes start to quantise keys near the end; split them.
6. **Cross-version servers.** During a soft update, an old server may ship v2 buffers to clients that have a v3 decoder, or the reverse. Decoders should accept the previous version for at least one update cycle, and the version byte check should fall back to a safe pose rather than error.
7. **Endianness and the buffer library.** The `buffer` library is little-endian on every platform, so encoding on PC and decoding on console or phone is consistent. Tools outside Roblox (Python, Blender exporters) must use explicit little-endian packing (`struct` format `<`), or files written on one machine decode as garbage.
8. **Security.** Clip buffers sent to clients are readable by anyone with a modified client. That is harmless for animation, but do not pack gameplay secrets (exact hit frames for PvP, hidden boss patterns you want to stay secret) into a format that ships to clients.

## Common mistakes

1. **Bumping the format without bumping the version byte.** Symptom: some clips play twisted after an encoder tweak. Fix: any layout change bumps the version; decoders assert.
2. **Decoding on every play.** Symptom: hitches on first play of each move, repeated. Fix: decode once per clip and cache the decoded table.
3. **Base64 decoding with a hand-written Luau function.** Symptom: slow loads. Fix: use `EncodingService` base64 where available, which the archive note already uses.
4. **Writing offsets without the per-joint scale.** Symptom: big translations clip at the i16 range, small ones lose precision. Fix: keep `S` per joint as specified.
5. **External tools writing big-endian.** Symptom: all values absurd on decode. Fix: explicit little-endian packing in the exporter, with a round-trip test.

## Related decisions

- [[Buffers and Binary Data]]: the buffer API this format is built on.
- [[Serialization Formats for Saves and Networking]]: comparing this format with JSON and table formats.
- [[Rotations Angles and Quaternions]]: why smallest-three works and where it loses precision.
- [[Network Bandwidth Budgets and Measuring Them]]: sizing clip payloads streamed to clients.
- [[Case Study - Fast Join and Deferred Loading]]: streaming kits on demand instead of at join.
- [[Server Shutdowns Soft Updates and Migration]]: running mixed versions during an update.
- [[Data Schema Design and Migrations]]: the same versioning discipline applied to save data.
- [[Blender Automation with Python]]: writing the exporter side with correct byte order.

## Connected notes
<!-- auto-links:start -->
[[How the Animator Really Behaves]] · [[Authoring Clips in Code]] · [[Animation Data from Blender to Roblox]] · [[Snippets - Lua Keyframe Player Core]] · [[Easing]] · Big Numbers Precision and Formatting · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[KeyframeSequence Keyframe and Pose Reference]] · [[Case Study - Cutting a Million Instances]] · [[Weapon Design Rig Builder]] · [[Animation Editor Advanced]] · [[Animation Editor Workflow]] · [[Engine Gotchas]] · [[Animation Glossary]] · [[Clip Archive Server]]
<!-- related:end -->
