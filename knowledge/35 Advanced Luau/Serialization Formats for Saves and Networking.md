---
tags: [luau, advanced-luau, serialization, json, buffer, networking, datastore, versioning]
---
# Serialization Formats for Saves and Networking

<!-- tldr:start -->
> [!tldr] TL;DR
> - Items in slot 3 vanish after rejoin: Sparse numeric keys changed shape through JSON -> String keys or dense arrays only
> - Dictionary keyed by UserId loses entries: Numeric keys on a boundary -> `tostring(userId)` keys
> - Balance stops increasing at a large value: `f32` or a value past 2^53 -> `f64`, or a big-number representation
> - Every table crossing a boundary is either a dense array or a string-keyed record.
> - No NaN, infinity, functions, metatables or Instances reach a serializer; a validation pass runs before saving.
> - Numeric dictionary keys are converted to strings.
>
> Cost: TL;DR ~190 tok · whole note ~6.2k tok. Read more: ## 2. JSON edge cases that bite saves · ## 4. A schema-driven codec · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Serialization is the act of turning live Luau values into something that survives a boundary: a DataStore save, a remote call, a MessagingService message, a MemoryStore entry, an HTTP request. [[Buffers and Binary Data]] teaches the `buffer` API and a byte writer; [[Data Schema Design and Migrations]] teaches how to shape a profile and convert engine types. This note sits above both. It is about choosing a format per boundary, building codecs that cannot drift out of sync, surviving rolling updates where old and new servers read each other's data, and knowing which failures are silent.

The short version: every boundary has its own serializer with its own rules, and almost every serialization bug is a value that one side wrote and the other side read differently without an error.

---

## 1. Every boundary has its own serializer

You rarely call a serializer yourself. The engine calls one for you, and each one behaves differently.

| Boundary | Who serializes | Size limit | What silently changes |
|---|---|---|---|
| DataStore value | JSON (Roblox docs: "Luau data is converted to serialized JSON") | 4,194,304 characters per key (Roblox docs, as of October 2026) | Metatables, functions, Instances, most engine types cannot be stored; numeric key shapes can change |
| RemoteEvent / RemoteFunction | The engine's own network format | No published hard size for reliable remotes; large payloads cost bandwidth and time | Tables copied; non-string keys converted to strings; mixed tables and `nil` holes unsafe; metatables lost; non-replicated Instances arrive as `nil` (Roblox docs) |
| UnreliableRemoteEvent | Same as remotes | Payloads over 1,000 bytes may be dropped (Roblox docs) | Same as remotes, plus whole messages can vanish |
| BindableEvent / BindableFunction | Same copy rules as remotes | None that matters | Copies, lost metatables, stringified keys ([[Events Signals and Connections]]) |
| MessagingService | JSON-like encoding | 1 kB per message (Roblox docs, see [[Cross-Server Messaging]]) | Same as JSON |
| MemoryStore | JSON-like encoding | 32 KB per value (Roblox docs, see [[MemoryStore Service]]) | Same as JSON |
| Attributes | Attribute types only | Not tables at all | Only listed types (string, number, boolean, Vector3, CFrame, Color3 and similar) ([[Instances Attributes and Tags]]) |
| HttpService | `JSONEncode` | Request size limits apply | JSON rules, plus whatever the remote server does |
| Actor messages | Copy across VMs | None that matters | Copies; a buffer cannot be shared between Actor scripts (Roblox docs, see [[Parallel Luau and Actors]]) |

The consequence is that "a table" is not a format. A table that goes to a DataStore and a remote and back must survive two different rule sets. The safe common subset is narrow: string keys or dense arrays (never both in one table), numbers, strings, booleans, and nested tables of the same.

### The common subset, stated precisely (rule of thumb)

1. A table is either a **dense array** (keys `1..n`, no holes) or a **record** (string keys only). Never both.
2. Values are `string`, `number` (finite), `boolean`, or a nested table following rule 1.
3. No `nil` inside arrays. Represent "missing" by omitting a record field, or with a sentinel like `0` or `""` that the schema defines.
4. No metatables, functions, threads, userdata or Instances. Convert them at the edge.
5. Numbers that must be exact are integers below 2^53.

Code that sticks to this subset can move between every boundary above without surprises. Everything else needs an explicit codec.

---

## 2. JSON edge cases that bite saves

`HttpService:JSONEncode` and the DataStore serializer share JSON's model. The official reference (as of October 2026) documents the signatures and a simple example, and very little about edge cases, so treat the following as observed behaviour and rules of thumb, and test them in your own Studio before relying on the details.

**Arrays versus objects.** Luau has one table type; JSON has two. A table with keys `1..n` is written as a JSON array. A table with string keys is written as an object. An empty table has no keys, so the encoder must pick one; it is usually written as an array (`[]`). That is harmless in Luau, because an empty array and an empty record are the same thing after decoding. It is not harmless for an external service that expects an object.

**Sparse arrays.** `{ [1] = "a", [3] = "c" }` is not dense. What the encoder does with it is not documented. Depending on the encoder you may get an object with string keys `"1"` and `"3"`, an array with a `null`, or a truncated array. After a round trip, `t[3]` may become `t["3"]`, and your code that does `inventory[slot]` with a number now finds nothing. This is the most common "items vanished after rejoin" bug in slot-based inventories.

**Numeric ids as keys.** A dictionary keyed by `UserId` (a number) is a sparse array in disguise. Always key by `tostring(userId)` in anything that crosses a boundary, and convert back with `tonumber` on read. The same applies to item ids that happen to be numeric.

**NaN and infinity.** JSON has no representation for them. Behaviour of the encoder with `0/0` or `math.huge` is not documented. In practice the safe rule is that they must never reach a serializer: a `NaN` in a currency field is a bug, and it is better to catch it with a validation pass before saving than to discover what the encoder wrote. `x ~= x` is the NaN test.

**Integers above 2^53.** JSON numbers are decoded as doubles. Luau numbers are doubles too, so integers are exact only up to 2^53 (about 9.007 x 10^15). Games with "big number" currencies pass that point, and once they do, `+1` stops changing the value. Store big numbers as a mantissa and exponent pair, or as a string, and do the maths in a dedicated module.

**String content.** JSON strings are text. Arbitrary binary data in a Luau string (from `buffer.tostring`, or `string.pack`) is not safe in JSON. Base64 it first with `EncodingService:Base64Encode` ([[Buffers and Binary Data]]).

**Measuring size.** The DataStore limit is measured on the serialized string, so measure the same way: `#HttpService:JSONEncode(profile)`. Log the size on save in Studio and alert when a profile passes a fraction of the limit (rule of thumb: warn at 50 percent, so you have months of growth before an outage).

---

## 3. Picking a format per job

| Format | Size | CPU | Debuggable by hand | Schema evolution | Best for |
|---|---|---|---|---|---|
| Plain tables (records and arrays) | Largest | Free (engine does it) | Yes | Easy: add fields | Profiles, most remotes, config |
| Positional arrays (`{ id, level, xp }`) | Smaller, no key names | Free | Barely | Fragile: order is the schema | Hot remotes with many small records |
| Strings with a custom grammar (`"sword:3:120"`) | Small | Parsing cost | Yes | Fragile | Almost nothing; avoid |
| Binary `buffer` | Smallest | Encode and decode cost in Luau | No | Needs an explicit version byte | Large inventories, replays, grids, high-rate network streams |
| Binary + Zstd + base64 | Smallest for repetitive data, 4/3 overhead from base64 | Highest | No | Version byte plus envelope | Huge saves near the limit, build data |

Two observations decide most cases.

**The engine's serializer is free CPU for you.** Encoding a buffer in Luau costs script time on every save or send. For a profile saved once per minute that is irrelevant. For a remote fired 30 times a second to 40 players it is real. The opposite is also true: the bytes on the wire cost bandwidth for every client, so for high-rate streams the encode cost usually pays for itself ([[Network Bandwidth Budgets and Measuring Them]]).

**Readability is a feature in saves.** When a player reports lost items, a support person or a script using [[Open Cloud APIs]] has to read the save. A JSON profile can be read and patched by hand. A base64 Zstd blob cannot, without the decoder. Go binary in saves only for the part that is actually large, and keep the rest readable.

A hybrid profile is often best: readable records for currencies, flags, settings and timestamps, plus one binary field for the bulky part.

```lua
-- Saved shape (as JSON):
-- {
--   "Schema": 7,
--   "Coins": 15200,
--   "Settings": { "Music": 0.5 },
--   "Inv": { "fmt": "b1z", "data": "KLUv/WBQ..." }   -- binary inventory, versioned envelope
-- }
```

The envelope (`fmt`, `data`) records how the blob was made, so you can change the codec later without a profile-wide migration.

---

## 4. A schema-driven codec

The writer and reader in [[Buffers and Binary Data]] work, but they invite one bug: the encoder and decoder are two hand-written functions that must list the same fields in the same order. Someone adds a field to one and not the other, and every save after that point reads garbage. The fix is to describe the format once, as data, and derive both directions from it.

The codec below supports unsigned integers, floats, booleans, strings, arrays and structs. It is small enough to read, strict-typed at the edges, and validates on decode.

```lua
--!strict
-- Codec.lua: describe a binary format once, get encode, decode and size from it.

export type Codec<T> = {
	size: (value: T) -> number,                          -- bytes needed
	write: (b: buffer, offset: number, value: T) -> number, -- returns new offset
	read: (b: buffer, offset: number) -> (T, number),    -- returns value, new offset
}

local Codec = {}

Codec.u8 = {
	size = function(_: number) return 1 end,
	write = function(b: buffer, o: number, v: number)
		buffer.writeu8(b, o, v)
		return o + 1
	end,
	read = function(b: buffer, o: number)
		return buffer.readu8(b, o), o + 1
	end,
} :: Codec<number>

Codec.u16 = {
	size = function(_: number) return 2 end,
	write = function(b: buffer, o: number, v: number)
		buffer.writeu16(b, o, v)
		return o + 2
	end,
	read = function(b: buffer, o: number)
		return buffer.readu16(b, o), o + 2
	end,
} :: Codec<number>

Codec.u32 = {
	size = function(_: number) return 4 end,
	write = function(b: buffer, o: number, v: number)
		buffer.writeu32(b, o, v)
		return o + 4
	end,
	read = function(b: buffer, o: number)
		return buffer.readu32(b, o), o + 4
	end,
} :: Codec<number>

Codec.f64 = {
	size = function(_: number) return 8 end,
	write = function(b: buffer, o: number, v: number)
		buffer.writef64(b, o, v)
		return o + 8
	end,
	read = function(b: buffer, o: number)
		return buffer.readf64(b, o), o + 8
	end,
} :: Codec<number>

Codec.bool = {
	size = function(_: boolean) return 1 end,
	write = function(b: buffer, o: number, v: boolean)
		buffer.writeu8(b, o, if v then 1 else 0)
		return o + 1
	end,
	read = function(b: buffer, o: number)
		local raw = buffer.readu8(b, o)
		if raw > 1 then
			error("bool out of range")
		end
		return raw == 1, o + 1
	end,
} :: Codec<boolean>

-- Strings with a u16 length prefix (max 65,535 bytes).
Codec.str = {
	size = function(v: string) return 2 + #v end,
	write = function(b: buffer, o: number, v: string)
		assert(#v <= 65535, "string too long")
		buffer.writeu16(b, o, #v)
		buffer.writestring(b, o + 2, v)
		return o + 2 + #v
	end,
	read = function(b: buffer, o: number)
		local n = buffer.readu16(b, o)
		return buffer.readstring(b, o + 2, n), o + 2 + n
	end,
} :: Codec<string>

-- Arrays with a u16 count and a hard cap, checked before allocating on read.
function Codec.array<T>(item: Codec<T>, maxCount: number): Codec<{ T }>
	return {
		size = function(list: { T })
			local total = 2
			for _, v in list do
				total += item.size(v)
			end
			return total
		end,
		write = function(b: buffer, o: number, list: { T })
			assert(#list <= maxCount, "array over cap")
			buffer.writeu16(b, o, #list)
			o += 2
			for _, v in list do
				o = item.write(b, o, v)
			end
			return o
		end,
		read = function(b: buffer, o: number)
			local n = buffer.readu16(b, o)
			if n > maxCount then
				error(`array count {n} over cap {maxCount}`)
			end
			o += 2
			local out = table.create(n)
			for i = 1, n do
				out[i], o = item.read(b, o)
			end
			return out, o
		end,
	}
end

-- Structs: an ordered field list. The order IS the format; append only.
type Field = { name: string, codec: Codec<any> }

function Codec.struct(fields: { Field }): Codec<{ [string]: any }>
	return {
		size = function(v: { [string]: any })
			local total = 0
			for _, f in fields do
				total += f.codec.size(v[f.name])
			end
			return total
		end,
		write = function(b: buffer, o: number, v: { [string]: any })
			for _, f in fields do
				o = f.codec.write(b, o, v[f.name])
			end
			return o
		end,
		read = function(b: buffer, o: number)
			local out = {}
			for _, f in fields do
				out[f.name], o = f.codec.read(b, o)
			end
			return out, o
		end,
	}
end

-- Whole-message helpers with a leading version byte.
function Codec.encode<T>(version: number, codec: Codec<T>, value: T): buffer
	local b = buffer.create(1 + codec.size(value))
	buffer.writeu8(b, 0, version)
	local final = codec.write(b, 1, value)
	assert(final == buffer.len(b), "size() and write() disagree")
	return b
end

function Codec.decode<T>(codec: Codec<T>, b: buffer): (number?, T?, string?)
	local ok, versionOrErr, value = pcall(function()
		local version = buffer.readu8(b, 0)
		local v, final = codec.read(b, 1)
		if final ~= buffer.len(b) then
			error("trailing bytes")
		end
		return version, v
	end)
	if not ok then
		return nil, nil, tostring(versionOrErr)
	end
	return versionOrErr, value, nil
end

return Codec
```

Using it for an inventory:

```lua
--!strict
local Codec = require(script.Parent.Codec)

local ItemV1 = Codec.struct({
	{ name = "id", codec = Codec.u16 },     -- index into a frozen item catalogue
	{ name = "level", codec = Codec.u8 },
	{ name = "xp", codec = Codec.u32 },
	{ name = "locked", codec = Codec.bool },
})

local InventoryV1 = Codec.array(ItemV1, 5000)

local blob = Codec.encode(1, InventoryV1, {
	{ id = 12, level = 3, xp = 1200, locked = false },
	{ id = 40, level = 1, xp = 0, locked = true },
})
print(buffer.len(blob)) --> 1 (version) + 2 (count) + 2 * 8 = 19 bytes
```

Design points that matter more than the code:

- **`size` before `write`.** Computing the exact size first means one allocation and no growing copies. The `assert` after writing catches the day `size` and `write` disagree, which is exactly the drift the descriptor approach is meant to prevent.
- **Caps on read.** A count read from untrusted bytes is attacker controlled. Checking it against a cap before `table.create` stops a 12-byte remote from asking the server to allocate 65,535 slots per call ([[Remote Abuse Patterns and Rate Limiting in Practice]]).
- **Trailing bytes are an error.** If the decoder finishes early, the format and the data disagree. Silently ignoring leftovers hides the bug until values are wrong.
- **Ids, not names.** `id = 12` indexes a frozen catalogue. That makes the catalogue part of the format: you may append items, but you may never reorder or delete entries, or every saved id points at a different item. Keep a test that fails if an existing catalogue index changes.

---

## 5. Versioning when old and new servers run together

Migrations in [[Data Schema Design and Migrations]] assume the newest code reads old data. During a live update there is a harder case: **old code reads new data.** When you publish, existing servers keep running the old version until they close. A player who joins a new server, gets their profile migrated to schema 8, then teleports or rejoins into an old server, has their schema 8 profile read by schema 7 code. If the old code drops fields it does not know about and saves, the new data is gone.

Three defences, in order of strength:

1. **Refuse to save data newer than you understand.** On load, if `profile.Schema > CURRENT_SCHEMA`, mark the session read-only: the player can play, but nothing is written. Kick with a "please rejoin" message if writes are essential. This is the single most important rule and it costs five lines.
2. **Preserve unknown fields.** Load into a table, touch only the fields you know, and save the same table back. Never rebuild the profile from a template on save; that drops unknown keys.
3. **Make new fields optional for one release.** Ship the reader for a new field one update before the writer starts using it, so every running server can at least carry it.

```lua
--!strict
local CURRENT_SCHEMA = 7

type LoadResult = { profile: { [string]: any }, readOnly: boolean }

local function acceptLoaded(raw: { [string]: any }): LoadResult
	local schema = raw.Schema
	if type(schema) ~= "number" then
		error("profile has no schema")   -- caller treats this as a failed load, never saves
	end
	if schema > CURRENT_SCHEMA then
		-- Written by a newer server. Play allowed, saving forbidden.
		warn(`profile schema {schema} newer than {CURRENT_SCHEMA}; session is read-only`)
		return { profile = raw, readOnly = true }
	end
	-- migrate(raw) up to CURRENT_SCHEMA here, in place, keeping unknown keys
	return { profile = raw, readOnly = false }
end
```

Binary formats need the same discipline. The version byte at offset 0 lets a decoder say "this is format 3, I only know 1 and 2" and stop, instead of decoding nonsense. For network messages the problem is smaller (client and server code ship together in one place version), but cross-server messages and MemoryStore entries can be read by servers on different versions, so they need the version field too ([[Cross-Server Messaging]]).

---

## 6. Numbers: precision is a format decision

| Stored as | Exact integers up to | Decimal precision | Use for |
|---|---|---|---|
| JSON number / `f64` | 2^53 | About 15 to 16 significant digits | Currencies, counters, timestamps |
| `f32` | 2^24 (16,777,216) | About 7 significant digits | Positions, rotations, cosmetic values |
| `u32` | 4,294,967,295 | Integers only | Ids, counts, XP |
| `u16` | 65,535 | Integers only | Small ids, levels, quantized angles |
| Quantized `u16` over a range | n/a | Range / 65,535 | Angles, health fractions on the wire |

Two classic failures:

- **Currency in `f32`.** It works in testing, where balances are small. A player reaches 20 million coins, earns 1, and the save does not change. Currency is `f64` or `u32`, never `f32`.
- **`os.time()` in a `u32`.** Fine until 2106. `os.clock()` in a save is meaningless (it is per-process). `DateTime.now().UnixTimestampMillis` is above 2^32, so it needs `f64`.

Quantization (store a value as an integer step within a known range) is covered with code in [[Buffers and Binary Data]]. The format-level point is that the range and step become part of the version. Changing a quantization range without bumping the version reinterprets every old value.

---

## 7. Network payloads: shape matters more than codec

For remotes, the engine already serializes for you, and reshaping data usually beats writing a binary codec.

**Send ids, not objects.** An Instance reference sent to a client arrives as `nil` if the client cannot see that instance (Roblox docs). With [[Instance Streaming]] that includes anything streamed out. Send a stable id (an attribute, a name in a known folder, a numeric entity id) and let the client resolve it, accepting that it may not exist yet.

**Positional arrays for hot records.** `{ id = 7, hp = 40, x = 10.5, z = -3 }` repeats four key strings per record. `{ 7, 40, 10.5, -3 }` does not. For a snapshot of 40 enemies at 10 Hz, that difference is measurable in the network stats. Keep the field order in one shared module next to a typed decoder so both sides agree.

**Batch, then decide.** Ten remotes per frame with one record each cost more overhead than one remote with ten records (rule of thumb; per-message overhead is not published). Collect events per frame or per tick and flush once ([[Network Performance]]).

**Deltas over snapshots.** Sending only what changed since the last acknowledged state cuts bandwidth for slowly changing data, but on unreliable channels you cannot know what the client has, so deltas need a periodic full snapshot or an acknowledgement scheme. For most Roblox games, reliable events for changes plus a full state on join is the simple correct answer.

**Buffers on remotes.** Buffers can be sent through remotes and bindables, and the receiver gets a copy (Roblox docs). Roblox's buffer announcement also stated that large buffers are compressed on the wire automatically; that is quoted secondhand on the DevForum and not confirmed in the current reference, so do not plan bandwidth around it. Validate received buffers: `typeof(x) == "buffer"`, a length cap, then decode inside `pcall` as the codec above does.

---

## 8. Worked size comparison

An inventory of 2,000 items, each with an id, a level, XP and a lock flag. The numbers below are arithmetic, not measurements, and are labelled rule of thumb.

| Encoding | Approximate size | Notes |
|---|---|---|
| JSON records `{"id":"sword_fire_03","level":3,"xp":1200,"locked":false}` | About 60 bytes each, 120 KB total | String ids and key names dominate |
| JSON positional `[12,3,1200,0]` | About 15 bytes each, 30 KB total | Numeric ids from a frozen catalogue |
| Binary struct above | 8 bytes each, 16 KB total | Plus 3 bytes header |
| Binary + base64 | About 21.3 KB | Base64 adds one third |
| Binary + Zstd + base64 | Depends on repetition | Many duplicate items compress well; random XP values do not |

All of these fit in the 4,194,304 character limit by a wide margin. The real lesson is the first row: a readable profile with long string ids can be ten times larger than it needs to be, and that matters when the inventory is unbounded (pets, collectibles) and grows for years. Cap the collection at the design level first; change the encoding second.

---

## When not to do this

- **Small profiles.** If a profile is under 50 KB and has no unbounded collection, plain records are correct. A binary codec is a maintenance cost with no benefit.
- **Low-rate remotes.** A shop purchase remote fired once a minute gains nothing from a buffer.
- **Data people must read.** Analytics events, support tooling and config pulled by external services should stay JSON.
- **Before measuring.** Log real save sizes and real remote bandwidth first. The fix for a fat save is often deleting a field nobody reads.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Items in slot 3 vanish after rejoin | Sparse numeric keys changed shape through JSON | String keys or dense arrays only |
| Dictionary keyed by UserId loses entries | Numeric keys on a boundary | `tostring(userId)` keys |
| Balance stops increasing at a large value | `f32` or a value past 2^53 | `f64`, or a big-number representation |
| New fields disappear after an update | Old servers rebuilt the profile from a template and saved | Read-only on newer schema; preserve unknown keys |
| Decoder returns plausible wrong values | Encoder and decoder field lists drifted | One schema descriptor; size assert; round-trip tests |
| Server memory spikes from one client | Count read from a buffer used before validation | Cap counts before allocating |
| Client gets `nil` instead of a part | Instance not replicated or streamed out | Send ids, resolve on the client |

## Checklist

- [ ] Every table crossing a boundary is either a dense array or a string-keyed record.
- [ ] No NaN, infinity, functions, metatables or Instances reach a serializer; a validation pass runs before saving.
- [ ] Numeric dictionary keys are converted to strings.
- [ ] Saves carry a `Schema` number; binary blobs carry a version byte and a format envelope.
- [ ] Sessions that load a newer schema than the code knows are read-only.
- [ ] Unknown fields are preserved on save.
- [ ] Binary codecs are described once and derive both directions; round-trip tests exist.
- [ ] Decoders cap counts and reject trailing bytes; decoding of client data runs in `pcall`.
- [ ] Save size is logged and alerts well before the 4,194,304 character limit.
- [ ] Frozen catalogues used as id tables are append-only, guarded by a test.

## See also

[[Advanced Luau Start Here]], [[Buffers and Binary Data]], [[Data Schema Design and Migrations]], [[Schema Migrations - Worked Case Studies]], [[DataStore Fundamentals]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Network Bandwidth Budgets and Measuring Them]], [[Cross-Server Messaging]], [[MemoryStore Service]], [[Advanced Types - Generics and Type Functions]], [[Luau Garbage Collection and the Memory Model]]

## Connected notes
<!-- auto-links:start -->
[[Clip Buffer Format]] · [[Big Numbers Precision and Formatting]] · [[Tables Metatables and OOP]] · [[Replication Boundary]] · [[Data Schema Versioning]] · [[Strings Patterns and Formatting]]
<!-- auto-links:end -->
