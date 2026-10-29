---
tags: [data, schema, migrations, serialization, versioning, type/guide, area/data, level/advanced, api/HttpService, area/design, api/DataStore]
---
# Data Schema Design and Migrations

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Sharing one `DEFAULT` table between players (Every new player edits the same table; data bleeds between players)
> - Avoid: Array holes or mixed keys (Fields silently dropped or turned into strings)
> - Avoid: Saving `Vector3`/`CFrame` directly (Write fails with 104 every time)
> - `Schema` integer on every profile, `CURRENT_SCHEMA` in code.
> - Ordered, deterministic, non-yielding steps; never edited after release.
> - Newer schema refused on load.
>
> Cost: TL;DR ~160 tok · whole note ~4.4k tok. Read more: ## What a data store can hold · ## Versioning: the `Schema` field · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Saved data outlives the code that wrote it. A profile written in week one is still loaded by the release you ship in month six, and during every rollout old and new servers run side by side. This note covers how to shape a profile so it survives that, how JSON serialization actually treats Luau values (the edge cases that silently corrupt data), how to build a migration framework that is safe under rolling updates, and what one production game learned doing roughly a dozen migrations and three account resets.

Prerequisites: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]].

## What a data store can hold

Values are serialized to JSON. Roblox docs (`HttpService:JSONEncode`, which follows the same rules) and the data store limits page give the boundaries:

| Luau value | Saved as | Gotcha |
|---|---|---|
| number | JSON number | `inf` and `nan` are accepted but are not valid JSON; Open Cloud returns them as tagged objects like `{"t":"numeric","v":"inf"}` |
| string | JSON string | Must be valid UTF-8 or the write fails |
| boolean | boolean | |
| array table (1..n, no holes) | JSON array | A hole (`nil` in the middle) breaks it: the table may be saved as an object with string keys, or truncated |
| dictionary with string keys | JSON object | |
| table with **both** array part and string keys | Array wins, string keys are dropped | Silent data loss |
| dictionary with **number** keys that are not 1..n | Saved with the keys turned into strings | `t[5]` comes back as `t["5"]` |
| empty table `{}` | `[]` | Indistinguishable from an empty array; harmless if your code treats both as empty |
| Instance, function, thread, userdata | Not allowed | Error 103/104 |
| Vector3, CFrame, Color3, EnumItem, UDim2 | Not allowed | Convert at the boundary |
| `buffer` | Encoded to base64 by `JSONEncode` (up to 50 MiB) | Prefer explicit encoding so you control the format |

The production lesson from one game, recorded in its own rules: "Sparse Lua tables save with string keys: keep saved lists dense." A `Quests.Track.Claimed` list that had `nil` holes came back with string keys and broke `ipairs` loops on the next load. If you need sparse data, store it deliberately as a map with string keys (`Claimed["17"] = true`).

### Serializing engine types

Convert at the edge, store the smallest faithful form, and version the encoding:

```lua
--!strict
local Codec = {}

function Codec.v3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end
function Codec.toV3(t: any): Vector3?
	if type(t) ~= "table" then return nil end
	local x, y, z = tonumber(t[1]), tonumber(t[2]), tonumber(t[3])
	return if x and y and z then Vector3.new(x, y, z) else nil
end

-- 12 numbers is exact; position + YXZ angles (6 numbers) is smaller but lossy near gimbal poles
function Codec.cf(c: CFrame): { number }
	return { c:GetComponents() }
end
function Codec.toCf(t: any): CFrame?
	if type(t) ~= "table" or #t ~= 12 then return nil end
	for i = 1, 12 do
		if type(t[i]) ~= "number" then return nil end
	end
	return CFrame.new(table.unpack(t))
end

function Codec.color(c: Color3): string
	return c:ToHex() -- "ff8800"
end
function Codec.toColor(s: any): Color3?
	if type(s) ~= "string" then return nil end
	local ok, c = pcall(Color3.fromHex, s)
	return if ok then c else nil
end

-- Enums: save the NAME, not .Value (names are stable and readable; values can be reused)
function Codec.enum(e: EnumItem): string
	return e.Name
end

return Codec
```

Never store asset references as full URLs if an id will do; never store display names (they change); never store anything you can recompute from other saved fields (derived totals drift out of sync).

## Shape of a good profile

```lua
--!strict
export type Item = { Uid: string, Id: string, Level: number, Stars: number?, Locked: boolean? }
export type ProfileData = {
	Schema: number,          -- the migration version of THIS table
	Coins: number,
	Gems: number,
	Items: { Item },         -- dense array; every entry has a stable Uid
	Equipped: { [string]: string }, -- slot -> Uid
	Unlocks: { [string]: boolean }, -- string keys only
	Settings: { [string]: any },
	Receipts: { string },    -- recent PurchaseIds, capped (see the receipts note)
	Stats: { FirstJoin: number, PlaySeconds: number },
}
```

Principles:

- **One root table per player**, one key ([[DataStore Fundamentals]]). Coupled values (currency and what it bought) live in the same key so one write saves both.
- **Every owned item has a stable unique id** (`HttpService:GenerateGUID(false)` at creation). Equips, trades, locks and receipts reference the `Uid`, never an array index. Indices shift when something is removed.
- **Store facts, not presentation.** Save `Id = "flamesword"`, not its display name, damage or icon. Item definitions live in code or config; when you rebalance, every saved item picks up the new values for free.
- **Bound everything that grows.** Inventories get a hard cap, histories keep the newest N, receipts keep the newest 100 (the reference project's number). Measure: `#HttpService:JSONEncode(data)` on your heaviest real profile, and alert above a budget (rule of thumb: keep player profiles under 100 KB; most are 2 to 30 KB). Remember the 4 MB/min per-key write throughput: a 1 MB profile can only be saved 4 times a minute.
- **Settings are small and separate in meaning, not necessarily in key.** The reference project kept settings in their own store so a progress reset did not wipe keybinds and graphics choices. That is a good reason to split.

## Versioning: the `Schema` field

Every profile carries an integer `Schema`. Code knows `CURRENT_SCHEMA`. On load, a chain of migration functions upgrades old data one step at a time.

```lua
--!strict
-- ServerScriptService/Data/Schema (ModuleScript)
local HttpService = game:GetService("HttpService")

local CURRENT_SCHEMA = 4

local Schema = {}
Schema.Current = CURRENT_SCHEMA

local function default(): { [string]: any }
	return {
		Schema = CURRENT_SCHEMA,
		Coins = 0,
		Gems = 0,
		Items = {},
		Equipped = {},
		Unlocks = {},
		Settings = { Music = true, Sfx = true },
		Receipts = {},
		Stats = { FirstJoin = os.time(), PlaySeconds = 0 },
	}
end

function Schema.newProfile(): { [string]: any }
	return default() -- a fresh table every call: never share one template table between players
end

-- Each step takes data at version N and returns data at version N + 1.
-- Steps must be deterministic, must not yield, and must tolerate missing fields.
local STEPS: { [number]: (any) -> any } = {
	[1] = function(d)
		-- v1 stored "Gold"; v2 renames it to Coins
		d.Coins = (tonumber(d.Coins) or 0) + (tonumber(d.Gold) or 0)
		d.Gold = nil
		return d
	end,
	[2] = function(d)
		-- v2 items were bare ids { "sword", "axe" }; v3 items are records with Uids
		local out = {}
		for _, entry in ipairs(if type(d.Items) == "table" then d.Items else {}) do
			if type(entry) == "string" then
				table.insert(out, { Uid = HttpService:GenerateGUID(false), Id = entry, Level = 1 })
			elseif type(entry) == "table" and type(entry.Id) == "string" then
				entry.Uid = entry.Uid or HttpService:GenerateGUID(false)
				table.insert(out, entry)
			end
		end
		d.Items = out
		d.Equipped = {} -- old index-based equips cannot be mapped safely; re-equip on join
		return d
	end,
	[3] = function(d)
		d.Receipts = if type(d.Receipts) == "table" then d.Receipts else {}
		d.Stats = if type(d.Stats) == "table" then d.Stats else { FirstJoin = os.time(), PlaySeconds = 0 }
		return d
	end,
}

-- Fill fields added WITHOUT a schema bump (purely additive defaults). Never overwrites.
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v) -- recurse into non-empty dictionaries only
		end
	end
end

function Schema.migrate(data: any): { [string]: any }
	if type(data) ~= "table" then
		error("profile is not a table")
	end
	local version = tonumber(data.Schema) or 1
	if version > CURRENT_SCHEMA then
		-- Written by a NEWER release (rolling update, or a rollback). Refuse: loading would
		-- drop fields this code does not know, and the next save would destroy them.
		error(`profile schema {version} is newer than this server ({CURRENT_SCHEMA})`)
	end
	while version < CURRENT_SCHEMA do
		local step = STEPS[version]
		if not step then
			error(`missing migration step from schema {version}`)
		end
		data = step(data)
		version += 1
		data.Schema = version
	end
	reconcile(data, default())
	return data
end

return Schema
```

Why each piece matters:

- **Steps, not a big "fix everything" function.** A player who last played at v1 runs steps 1, 2, 3 in order. Each step only has to understand one transition. Never edit a shipped step; add a new one.
- **Refusing newer data** is the guard for rolling updates. When you publish, Roblox does not swap every server instantly: old servers keep running until they empty or you migrate them. A player can hop from a new server (writes v4) to an old one (knows v3). Without the guard the old server loads v4 data, ignores fields it does not know, and its next save deletes them. With the guard, the old server fails the load and the player rejoins onto a new server. (Pair it with "Migrate To Latest Update" so old servers drain quickly; see [[Release Process and Rollbacks]].)
- **`reconcile` for additive fields.** Adding `Settings.Haptics = true` does not need a step; reconcile fills it on load. Anything that renames, moves, splits, converts or deletes needs a step.
- **Run migration inside the load path, before gameplay sees the data**, and let the first save write the upgraded record. Do not write a migration back immediately on join "to be safe"; the normal save does it, and an extra write is one more chance to fail.

## Idempotent migrations (production lessons)

The reference project migrated live data many times without a reset. The patterns that worked:

- **Idempotent conversions.** When the forge material system replaced two older shard systems, the migration folded both old id sets into the new materials, summing counts. It was written so "running it again changes nothing": an old id only exists until it is converted, and the conversion deletes it. That made it safe to call on every load without a version gate, which is useful when a migration is shipped as a hotfix.
- **Version flags for one-time changes.** Re-numbering the zone ladder (old zone 7 became 10, old 8 became 11, old 14 became 20) used a dedicated `LadderV = 1` flag on the profile so the mapping could never run twice. Mapping split zones to the later half meant "nothing is lost".
- **Paying out instead of deleting.** When quests v1 were replaced, finished-but-unclaimed v1 quests were paid out during migration rather than dropped. Removed items were sold for their value on load, and when developer-only weapons were stripped from normal players the profile got an audit record `DevWeaponStrip = { t = time, ids = {...}, paid = n }`. Leave a trail in the save when a migration takes something away; support will need it.
- **Persisting paid state that lived only in memory.** A paid "Lucky Charm" boost lived only in player attributes, so rolls left were lost on leave. The fix added it to the profile on every save. Audit: anything the player paid for must be in the profile.
- **Rebuilding derived state on load** instead of saving it (UI mirrors such as `QuestsJson` attributes are republished from the profile each join).

## Resets and "new store" versioning

Sometimes you really do want everyone to start over (a wipe for a relaunch, or a beta reset). The safe way, used three times by the reference project: **change the store names** (`Game_v5` to `Game_v6`, `LB_Totals_v5` to `LB_Totals_v6`). The old data stays untouched, and "revert = rename back". They deliberately did **not** rename the receipts store, the gift-intent store or the settings store, so purchase idempotency and preferences survived the reset. Three rules:

1. Never reset by writing defaults over existing keys. You lose the 30-day version history safety net and cannot undo.
2. Keep purchase records across resets, or a retried receipt can be granted twice (see [[Purchase Data and Receipts]]). Decide what paid items mean after a wipe and communicate it; wiping paid progress without compensation is a trust and policy problem ([[Ethical Design and Player Trust]]).
3. Old stores still count toward storage until deleted, and still hold personal data (they need right-to-erasure coverage; [[Player Privacy and Data Deletion]]).

Also note the anti-pattern the same project had to guard against: an admin-only "reset my progress every join" convenience. It was written to reset **only after a successful read**, so "a DataStore outage can never turn into a blank overwrite". Any code that writes defaults must be behind that check.

## Bulk migrations with Open Cloud

Lazy migration (on load) never touches players who do not come back, which is usually fine. Do a bulk migration when you must change data for everyone at once (a currency revaluation, or a leaderboard that reads profiles directly). Use the Open Cloud data store APIs from an external script ([[Open Cloud APIs]]):

- List keys with the prefix, read each entry, transform, write back. Open Cloud has no `UpdateAsync`-style transform, so a game server can write between your read and your write: check the endpoint reference for a conditional-update option (unverified here) and otherwise only touch keys with no live lease.
- Rate-limit it: Open Cloud shares the experience-wide budget with live servers.
- Respect session leases: skip keys whose lease is live, or the live server's next save will overwrite your change (or, with fencing, your change will make that server's session `lost`).
- Take a snapshot first.

Roblox's open-source Data Stores Batch Processor is meant for exactly these large jobs.

## Testing migrations

Migrations are pure functions; test them without Studio data:

```lua
--!strict
-- Run in the command bar or a TestEZ spec (see the testing notes)
local Schema = require(game.ServerScriptService.Data.Schema)

local v1 = { Gold = 50, Items = { "sword", "axe" } }
local out = Schema.migrate(table.clone(v1))
assert(out.Schema == Schema.Current, "schema not current")
assert(out.Coins == 50 and out.Gold == nil, "gold not renamed")
assert(#out.Items == 2 and type(out.Items[1].Uid) == "string", "items not converted")

-- idempotence on current data
local again = Schema.migrate(out)
assert(#again.Items == 2, "second migrate changed items")

-- newer data must be refused
assert(not pcall(Schema.migrate, { Schema = Schema.Current + 1 }), "newer schema was accepted")
print("migrations ok")
```

Keep a folder of anonymised real profiles from each schema era (exported through Open Cloud or the Data Stores Manager) and run every one through `migrate` in CI ([[Testing Strategies and Frameworks]]). The interesting bugs live in data shapes nobody remembers writing.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Sharing one `DEFAULT` table between players | Every new player edits the same table; data bleeds between players |
| Array holes or mixed keys | Fields silently dropped or turned into strings |
| Saving `Vector3`/`CFrame` directly | Write fails with 104 every time |
| Editing a shipped migration step | Players who already ran it and players who did not end up with different data |
| Deleting a field "because nothing uses it" without a step | During the rollout an old server re-saves it, or a new server deletes it while old code still needs it |
| No refusal of newer schemas | Rolling updates and rollbacks destroy new fields |
| Resetting by overwriting keys | No undo; purchase history lost |
| Equips by array index | Removing one item re-points equips to the wrong item |

## Checklist

- [ ] `Schema` integer on every profile, `CURRENT_SCHEMA` in code.
- [ ] Ordered, deterministic, non-yielding steps; never edited after release.
- [ ] Newer schema refused on load.
- [ ] Additive defaults through reconcile; structural changes through steps.
- [ ] Engine types converted at the boundary; arrays dense; enums by name.
- [ ] Every item has a stable `Uid`.
- [ ] Profile size measured and bounded.
- [ ] Migrations unit-tested on real historical shapes.
- [ ] Snapshot before shipping a migration.

## See also
[[DataStore Fundamentals]] · [[Session Locking and Profile Libraries]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Loss Prevention and Recovery]] · [[Release Process and Rollbacks]] · [[Tables Metatables and OOP]] · [[Buffers and Binary Data]] · [[Economies and Currencies]] · [[Tools and Inventory Systems]]

## Connected notes
<!-- auto-links:start -->
[[Schema Migrations - Worked Case Studies]] · [[Data Schema Versioning]] · Skill - Roblox DataStore Safety · Cookbook - Data and Saving · Serialization Formats for Saves and Networking · Debugging DataStore Problems
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Serialization Formats for Saves and Networking]] · [[Cookbook - Data and Saving]] · [[OrderedDataStores and Leaderboards]] · [[Trading Systems Without Duplication]] · [[Global State and Live Config]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[HttpService and External APIs]]
<!-- related:end -->
