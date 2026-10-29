---
tags: [luau, buffer, binary, serialization, networking, compression, type/guide, area/scripting, level/advanced, area/data]
---
# Buffers and Binary Data

<!-- tldr:start -->
> [!tldr] TL;DR
> - Edits to a buffer after sending it never show on the other side: A buffer passed through a remote or bindable arrives as a copy... -> Treat each received buffer as a...
> - "out of bounds" errors: Offsets start at 0; wrong size; writer did not grow -> Growable writer; size checks
> - Values garbled after a format change: No version byte -> Version first; branch on read
> - Layout written down against the buffer rules: fixed size, created zero-filled, 0-based byte offsets, out-of-range reads and...
> - Every format starts with a version byte and has a round-trip test.
> - Writer and reader live together and mirror each other.
>
> Cost: TL;DR ~200 tok · whole note ~5.0k tok. Read more: ## 2. A typed writer and reader · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`buffer` is a Luau type for a fixed-size, mutable block of raw bytes, with functions to read and write integers, floats, strings and bit fields at byte offsets. It replaces most uses of `string.pack`/`string.unpack` and of hand-rolled string encodings. Use it to make network payloads and saved data compact, to implement binary formats, and to give hot numeric code a dense, native-friendly memory layout. This note covers the API and its exact semantics, a typed reader/writer, quantization techniques, buffers across remotes, attributes and DataStores, `EncodingService` (base64, compression, hashing), and a production case where a binary clip format cut animation data to a fraction of its instance size.

---

## 1. API (Docs)

```lua
local b = buffer.create(16)            -- 16 zero bytes; max size 1 GiB (1,073,741,824 bytes)
local s = buffer.fromstring("hello")   -- size = string length
print(buffer.len(b))                   --> 16
print(buffer.tostring(s))              --> hello
```

| Family | Functions |
|---|---|
| Integers | `readi8/readu8`, `readi16/readu16`, `readi32/readu32` and `write*` counterparts |
| Floats | `readf32/writef32`, `readf64/writef64` |
| Strings | `readstring(b, offset, count)`, `writestring(b, offset, value, count?)` |
| Bits | `readbits(b, bitOffset, bitCount)`, `writebits(b, bitOffset, bitCount, value)`, `bitCount` 0 to 32 |
| Bulk | `copy(target, targetOffset, source, sourceOffset?, count?)` (overlap-safe), `fill(b, offset, value, count?)` |

Exact rules (Docs):
- Offsets are **byte offsets from 0** (not 1 like tables). `readbits` takes a **bit** offset.
- Integers and floats are **little-endian**.
- Any read or write outside the buffer **throws**. There is no auto-grow.
- `readbits(b, 0, 8)` equals `readu8(b, 0)`; `readbits` returns an unsigned integer.
- `writestring` with `count` takes only the first `count` bytes; `count` cannot exceed the string length.

### Value conversions to remember

- `writeu8(b, 0, 300)` stores `300 % 256 = 44` (Rule of thumb: integer writes wrap/truncate to the width; verify edge cases in your Studio version and never rely on it; clamp first).
- `writef32` rounds a double to single precision: about 7 significant digits. `0.1` read back is `0.10000000149011612`. Do not compare round-tripped floats with `==`.
- Non-integer values passed to integer writes are converted; clamp and round explicitly so behaviour is obvious.
- `writei16` range is -32,768 to 32,767; `writeu16` 0 to 65,535; `writeu32` 0 to 4,294,967,295.

---

## 2. A typed writer and reader

Fixed-size buffers need a known size. For variable payloads, write into a growing builder and trim at the end:

```lua
--!strict
local Writer = {}
Writer.__index = Writer

export type Writer = typeof(setmetatable({} :: { buf: buffer, pos: number }, Writer))

function Writer.new(capacity: number?): Writer
	return setmetatable({ buf = buffer.create(capacity or 64), pos = 0 }, Writer)
end

function Writer.ensure(self: Writer, n: number)
	local need = self.pos + n
	local cap = buffer.len(self.buf)
	if need <= cap then return end
	while cap < need do cap *= 2 end
	local bigger = buffer.create(cap)
	buffer.copy(bigger, 0, self.buf, 0, self.pos)
	self.buf = bigger
end

function Writer.u8(self: Writer, v: number)
	self:ensure(1); buffer.writeu8(self.buf, self.pos, v); self.pos += 1
end
function Writer.u16(self: Writer, v: number)
	self:ensure(2); buffer.writeu16(self.buf, self.pos, v); self.pos += 2
end
function Writer.u32(self: Writer, v: number)
	self:ensure(4); buffer.writeu32(self.buf, self.pos, v); self.pos += 4
end
function Writer.i16(self: Writer, v: number)
	self:ensure(2); buffer.writei16(self.buf, self.pos, v); self.pos += 2
end
function Writer.f32(self: Writer, v: number)
	self:ensure(4); buffer.writef32(self.buf, self.pos, v); self.pos += 4
end
function Writer.str(self: Writer, s: string)   -- u16 length prefix
	local n = #s
	assert(n <= 65535, "string too long")
	self:u16(n)
	self:ensure(n); buffer.writestring(self.buf, self.pos, s); self.pos += n
end

function Writer.finish(self: Writer): buffer
	local out = buffer.create(self.pos)
	buffer.copy(out, 0, self.buf, 0, self.pos)
	return out
end

local Reader = {}
Reader.__index = Reader

export type Reader = typeof(setmetatable({} :: { buf: buffer, pos: number }, Reader))

function Reader.new(buf: buffer): Reader
	return setmetatable({ buf = buf, pos = 0 }, Reader)
end
function Reader.u8(self: Reader): number
	local v = buffer.readu8(self.buf, self.pos); self.pos += 1; return v
end
function Reader.u16(self: Reader): number
	local v = buffer.readu16(self.buf, self.pos); self.pos += 2; return v
end
function Reader.u32(self: Reader): number
	local v = buffer.readu32(self.buf, self.pos); self.pos += 4; return v
end
function Reader.i16(self: Reader): number
	local v = buffer.readi16(self.buf, self.pos); self.pos += 2; return v
end
function Reader.f32(self: Reader): number
	local v = buffer.readf32(self.buf, self.pos); self.pos += 4; return v
end
function Reader.str(self: Reader): string
	local n = self:u16()
	local s = buffer.readstring(self.buf, self.pos, n); self.pos += n; return s
end
function Reader.atEnd(self: Reader): boolean
	return self.pos >= buffer.len(self.buf)
end

return { Writer = Writer, Reader = Reader }
```

Rules for formats you will keep:
- **Byte 0 is a version number.** You will change the format; old saves and old clients must be detectable.
- **Write and read in exactly the same order.** Keep the writer and reader for one format next to each other, and test round trips.
- **Validate on read** when data comes from a client: a malicious buffer can claim a string length of 65,535; the read then throws, which is fine if you `pcall` the decode at the boundary, but cap counts before allocating.

---

## 3. Making data small: quantization

Most game values do not need 64-bit doubles.

| Value | Encoding | Size | Precision |
|---|---|---|---|
| Boolean flags | `writebits` 1 bit each | 1/8 byte | exact |
| Health 0..100 | `u8` | 1 | 1 point |
| Position inside a 4096-stud map | `i16` per axis at 1/8 stud | 6 | 0.125 stud |
| Yaw angle | `u8` (256 steps) or `u16` | 1 or 2 | 1.4 or 0.0055 degrees |
| Unit direction | 2 x `i16` octahedral, or 3 x `i8` | 3 to 4 | ~0.01 to ~1 degree |
| Rotation | Smallest-three [[Quaternions\|quaternion]], 3 x `i16` + 2 bits | ~6.25 | ~0.003 |
| Timestamp offset | `u16` milliseconds from a base | 2 | 1 ms, 65 s range |

```lua
-- Position at 1/8-stud resolution, valid for |x| < 4096
local SCALE = 8
local function writePos(w, p: Vector3)
	w:i16(math.clamp(math.round(p.X * SCALE), -32768, 32767))
	w:i16(math.clamp(math.round(p.Y * SCALE), -32768, 32767))
	w:i16(math.clamp(math.round(p.Z * SCALE), -32768, 32767))
end
local function readPos(r): Vector3
	return Vector3.new(r:i16() / SCALE, r:i16() / SCALE, r:i16() / SCALE)
end

-- Eight booleans in one byte
local function packFlags(b: buffer, byteOffset: number, flags: { boolean })
	for i = 1, 8 do
		buffer.writebits(b, byteOffset * 8 + (i - 1), 1, if flags[i] then 1 else 0)
	end
end
```

**Varints** (7 bits per byte, high bit = more) store small integers in 1 byte and large ones in up to 5; good for counts and IDs that are usually small.

```lua
local function writeVarUint(w, v: number)
	repeat
		local byte = v % 128
		v = v // 128
		w:u8(if v > 0 then byte + 128 else byte)
	until v == 0
end
local function readVarUint(r): number
	local v, mul = 0, 1
	repeat
		local byte = r:u8()
		v += (byte % 128) * mul
		mul *= 128
	until byte < 128
	return v
end
```

Quantization trades precision for size; decide the tolerance per field, document it next to the format, and test the worst case (map edges, maximum values).

---

## 4. Production case: a binary animation clip format

The reference project replaced thousands of `KeyframeSequence` instances with a compact binary format built on `buffer` ([[Clip Buffer Format]]): a version byte, an f32 time table shared by all joints, per-joint flags, smallest-three quaternions as three `i16`s plus the dropped component index packed into the high bits of a `u16` time index, offsets scaled per joint, and one-byte easing codes. Measured results:

- Playback within 0.03 degrees and 0.002 studs of the original clips after key thinning.
- **19 to 235 KB per creature kit**, about **1.6 MB** for a whole enemy roster, sent once per client on a dedicated remote and cached; the server-side build took 0.23 s.
- Clips stored on lightweight stub instances as base64 string attributes; large strings slowed the Properties window, so each was kept under a few hundred KB ([[Performance and Memory]]).

Design choices worth copying: shared tables of repeated values (times) referenced by index; fixed offsets for fields the server patches without re-encoding (loop flag, priority); per-field scale factors so precision follows each joint's range.

---

## 5. Buffers across Roblox boundaries

- **Remotes and bindables.** Buffers can be sent; the receiver gets a **copy** ("the identity of the buffer object is not preserved", Docs). A buffer is usually far smaller on the wire than an equivalent table of numbers. Validate on receipt: check `typeof(x) == "buffer"`, `buffer.len` bounds, then decode in `pcall`.
- **Actors.** "The same buffer object cannot be used from multiple Actor scripts" (Docs); send a copy by message.
- **Attributes.** Attribute values cannot be buffers. Store base64 text (see below) in a string attribute.
- **DataStores.** Saving buffers directly in DataStore values has been reported as supported but is **unverified** here. The conservative approach is to base64 the buffer into a string field. DataStore values are JSON; raw binary strings are not safe there.
- **HttpService.** JSON cannot carry raw bytes; base64 first.

### EncodingService (Docs)

| Method | Purpose |
|---|---|
| `Base64Encode(buffer): buffer` / `Base64Decode(buffer): buffer` | Binary to text and back. Decode throws on invalid input |
| `CompressBuffer(buffer, Enum.CompressionAlgorithm.Zstd, level?)` | Zstd levels -7 to 22 (default 1) |
| `DecompressBuffer(...)` | Inverse |
| `ComputeBufferHash(buffer, Enum.HashAlgorithm)` / `ComputeStringHash(string, algo)` | `Md5`, `Sha1`, `Sha256`, `Blake2b`, `Blake3`. Not for passwords (Docs) |

```lua
--!strict
local EncodingService = game:GetService("EncodingService")

local function toBase64String(b: buffer): string
	return buffer.tostring(EncodingService:Base64Encode(b))
end

local function fromBase64String(s: string): buffer
	return EncodingService:Base64Decode(buffer.fromstring(s))
end

-- Compress before encoding when data is repetitive (JSON-like, sparse grids)
local function pack(b: buffer): string
	local z = EncodingService:CompressBuffer(b, Enum.CompressionAlgorithm.Zstd, 3)
	return toBase64String(z)
end
```

Base64 grows data by 4/3; compression often more than pays for it on structured data and does nothing for already-quantized random-looking data. Measure both. Hashes are useful for change detection (skip a save if the hash of the serialized profile did not change) and content addressing, not for security against exploiters who control the client.

---

## 6. Buffers for performance

Buffers are also a compact memory layout: an array of 10,000 positions as `f32` triples is 120 KB in one object, versus 10,000 `Vector3` values in a table (each a separate value slot) or 30,000 numbers. With native code generation, buffer reads and writes compile to direct memory access, and the docs single out "math operations on tables and especially buffer types" as good native candidates ([[Luau Performance and Native Codegen]]).

```lua
--!native
-- Structure-of-arrays particle positions in a buffer
local N = 10000
local pos = buffer.create(N * 12)

@native
local function integrate(vel: buffer, dt: number)
	for i = 0, N - 1 do
		local o = i * 12
		buffer.writef32(pos, o,     buffer.readf32(pos, o)     + buffer.readf32(vel, o)     * dt)
		buffer.writef32(pos, o + 4, buffer.readf32(pos, o + 4) + buffer.readf32(vel, o + 4) * dt)
		buffer.writef32(pos, o + 8, buffer.readf32(pos, o + 8) + buffer.readf32(vel, o + 8) * dt)
	end
end
```

(`@native` inside a `--!native` script is redundant, shown here for illustration; use one or the other.) Only do this for genuinely hot, numeric code; plain tables are clearer and fast enough for most game logic.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Edits to a buffer after sending it never show on the other side | A buffer passed through a remote or bindable arrives as a copy; identity is not kept | Treat each received buffer as a new value; send again after changes |
| "out of bounds" errors | Offsets start at 0; wrong size; writer did not grow | Growable writer; size checks |
| Values garbled after a format change | No version byte | Version first; branch on read |
| Positions jitter or snap | Quantization step too coarse, or overflow at map edges | Choose scale per range; clamp |
| Float equality fails after round trip | f32 precision | Tolerances |
| Server errors on malformed client data | Decoding untrusted buffers without checks | Type/length checks + `pcall` at the boundary |
| Save corrupt or rejected | Raw binary in a string saved to JSON | Base64 |
| Same buffer used by two Actors | Not allowed | Copy via message |

## Checklist

- [ ] Layout written down against the buffer rules: fixed size, created zero-filled, 0-based byte offsets, out-of-range reads and writes throw, remotes deliver a copy, f32 keeps less precision than a Luau number.
- [ ] Every format starts with a version byte and has a round-trip test.
- [ ] Writer and reader live together and mirror each other.
- [ ] Field precision and ranges are documented and clamped.
- [ ] Untrusted buffers are length-checked and decoded in `pcall`.
- [ ] Text channels (attributes, JSON, DataStores) receive base64.
- [ ] Compression is measured, not assumed.

## See also

[[Clip Buffer Format]] · [[Lua Keyframe Player Internals]] · [[Network Performance]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Data Schema Design and Migrations]] · [[Luau Performance and Native Codegen]] · [[Strings Patterns and Formatting]] · [[Math Vectors and CFrames]]

## Nuances and edge cases

1. **Buffers win on volume, not on single messages.** Packing one `Vector3` into 12 bytes instead of sending the Vector3 saves almost nothing, because each remote call carries its own overhead and Roblox already encodes common types compactly. The gain appears when you batch: 40 enemy positions per tick in one buffer, quantized to 16-bit integers, can be several times smaller than 40 separate remote fires or a table of Vector3s (rule of thumb; measure with the network stats in [[Network Bandwidth Budgets and Measuring Them]] before and after).
2. **Packing has a CPU and a debugging cost.** Every packed format needs a writer, a reader, a version byte and tests. A bug in an offset produces garbage that looks plausible (an enemy 300 studs away instead of an error). Only reach for buffers after a measurement shows bandwidth, memory or save size is the problem.
3. **Untrusted input is the default case on the server.** A buffer from a client can be any length. Read `buffer.len(b)` first and reject anything shorter than the header or longer than the largest valid message, then wrap the decode in `pcall`, because an out-of-range read errors. A malicious client can also send valid-looking values out of range (a count of 65,535 items), so validate decoded values as you would table arguments.
4. **Quantization error accumulates if you re-encode.** Decoding a quantized value, adding a small delta and re-encoding each tick rounds every time; over hundreds of ticks the object drifts. Keep the authoritative value at full precision and quantize only on the way out.
5. **Range assumptions break as the game grows.** A 16-bit position scheme centred on the origin with 0.1-stud steps covers about plus or minus 3,276 studs. That fits the first map; the second, bigger map arrives six months later and positions wrap around silently. Put the range and step in a shared constant, assert on encode, and include the format version so you can widen it.
6. **Saves are a long-lived contract.** A binary save format must be readable years later. Write a version byte first, never reuse a field's meaning, and keep old decoders forever (see [[Data Schema Design and Migrations]]). For anything stored as a string, use an encoding that survives text storage (the existing section on EncodingService covers this).
7. **Scale effects.** At 1 player, JSON is fine for everything. At 50 players with a replicated world state, batching and packing typically turns a bandwidth problem into a non-problem. At 700 players per server, per-player interest management (sending each player only what is near) matters far more than byte-level packing; do that first ([[Interest Management and Per-Player Replication]]).
8. **Platform differences.** Low-end phones are hurt more by many small allocations than by bandwidth, so the main win of a buffer on mobile is often fewer tables, not fewer bytes. Console and PC rarely notice either.

The senior trade-off: binary formats trade developer time and debuggability for bytes. Write them for the two or three hottest paths (replicated state, large saves, clip data) and keep everything else as plain tables.

## Common mistakes (advanced)

1. **No length check before decoding client buffers.** Symptom: server error spam from one player, sometimes enough to slow the server. Fix: length bounds and `pcall` around decode, then drop and rate-limit the sender.
2. **Mixing signed and unsigned reads.** Symptom: negative values come back as large positives (or the reverse). Fix: write and read with the matching `i` or `u` variant; put both in one shared codec module so they cannot diverge.
3. **Encoding a boolean per byte.** Symptom: buffers no smaller than the table version. Fix: pack flags into one integer with `bit32` operations.
4. **Changing field order without a version bump.** Symptom: old saves load with swapped stats. Fix: append new fields at the end and bump the version byte.
5. **Writing a codec without a round-trip test.** Symptom: an edge value (maximum, negative zero, empty list) corrupts data in production. Fix: a test that encodes and decodes random and boundary values and compares with a tolerance (see [[Automated Testing with TestEZ and Jest-Lua]]).
6. **Packing data that changes rarely.** Symptom: complex code for a settings table sent once on join. Fix: send it as a normal table.

## Related decisions

- [[Serialization Formats for Saves and Networking]]: choosing between JSON, tables and binary per use.
- [[Network Bandwidth Budgets and Measuring Them]]: how to prove a buffer helped.
- [[Interest Management and Per-Player Replication]]: the bigger lever before byte packing.
- [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]: fuzzing decoders with malformed buffers.
- [[Data Schema Design and Migrations]]: versioning rules that apply equally to binary saves.
- [[Clip Buffer Format]]: a full worked binary format for animation clips.
- [[Luau Garbage Collection and the Memory Model]]: why fewer tables helps low-end devices.
- [[Client Prediction and Reconciliation for Combat]]: compact snapshots for reconciliation.

## Connected notes
<!-- auto-links:start -->
[[Big Numbers Precision and Formatting]] · Snippets - Building and Sampling Clips · [[Luau Performance Patterns with Benchmarks]] · 2D Multiplayer - Server Authority and Replicating GUI Worlds · Baked Clip Stubs and Archiving · Advanced Luau Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Tables Metatables and OOP]] · [[Luau Type System and Strict Mode]] · [[Metatables and OOP - When and When Not]] · [[Luau Language Essentials]] · [[Functions Closures and Upvalues]] · [[Events Signals and Connections]] · [[Instances Attributes and Tags]] · [[Parallel Luau and Actors]]
<!-- related:end -->
