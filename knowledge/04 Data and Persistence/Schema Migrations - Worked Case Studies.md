---
tags: [data, schema, migrations, versioning, rollback, case-study, luau]
---
# Schema Migrations - Worked Case Studies

[[Data Schema Design and Migrations]] gives you the framework: a `Schema` integer on every profile, an ordered chain of migration steps, a refusal of newer data, and `reconcile` for additive fields. This note is the next level down. It walks through seven migrations of the kind every live game eventually ships, each with the trap that makes the obvious version wrong, working Luau, and the way to tell from production data whether it went well.

Prerequisites: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]].

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (one production RNG and combat game that ran about a dozen live migrations and three account resets), **rule of thumb**.

---

## Before the case studies: three properties every step needs

Every step below obeys three rules. If a step breaks one, it will eventually corrupt someone.

1. **Pure and non-yielding.** A step gets a table and returns a table. No data store calls, no `task.wait`, no `HttpService` requests. The load path already holds a session lease; a yield inside migration widens the window in which a second server can steal it ([[Session Locking and Profile Libraries]]). If a step needs outside data (a config value, a price table), it reads it from a module that is already loaded.
2. **Total.** It handles every shape the old version could have had, including shapes "nobody ever wrote". Real profiles contain fields from abandoned features, half-written arrays from a crash era, and values set by admin commands. A step that indexes `d.Stats.Kills` without checking `d.Stats` is a load failure for the one player whose `Stats` is missing.
3. **Leaves a trail when it takes something away.** If a step deletes, merges, downgrades or converts value, it writes a small audit record into the profile. Support will need it, and you will need it when someone asks "where did my sword go?" (measured in the reference project, see case 4).

A useful helper set, used by the examples:

```lua
--!strict
-- ServerScriptService/Data/MigrateUtil (ModuleScript)
local MigrateUtil = {}

function MigrateUtil.num(v: any, default: number): number
	local n = tonumber(v)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

function MigrateUtil.tbl(v: any): { [any]: any }
	return if type(v) == "table" then v else {}
end

-- Append an audit record, keeping only the newest `cap` entries.
function MigrateUtil.audit(d: { [string]: any }, kind: string, detail: { [string]: any }, cap: number?)
	local log = MigrateUtil.tbl(d.MigrationLog)
	detail.k = kind
	detail.t = os.time()
	table.insert(log, detail)
	local limit = cap or 20
	while #log > limit do
		table.remove(log, 1)
	end
	d.MigrationLog = log
end

return MigrateUtil
```

`os.time()` inside a step is the one acceptable impurity: it does not yield and only feeds the audit trail.

---

## Case 1: revaluing a currency after a rebalance

**Situation.** A difficulty pass cuts cash income to 0.55x and raises prices (measured in the reference project). Players who saved under the old rates hold balances that now buy several gates at once. The team in that project chose a full reset; the alternative is a revaluation migration.

**The obvious version** multiplies `Cash` by 0.55. Three things go wrong:

- **Lazy migration applies it late.** A player who last played four months ago runs the step on their next join. That is correct (their balance was earned at old rates) but only if the step is keyed to the schema version, not to a date. A "if os.time() < cutoff" check is wrong: the player's last save time, not the current time, is what matters, and the schema number already encodes that.
- **Paid currency must not shrink.** If any of the balance came from Robux, scaling it down takes away something people paid for. Either keep paid and free balances separate (best: decide this before you sell anything), or apply the factor only to soft currency that is never sold.
- **Prices of things already in flight.** Pending trades, marketplace listings, auction bids, a crafting job paid for in old cash. Each needs its own rule. The simplest is: cancel and refund in-flight escrow in old units, then scale.

```lua
-- Step 6 -> 7: revalue soft cash after the economy pass. Gems (sold for Robux) untouched.
[6] = function(d)
	local before = MigrateUtil.num(d.Cash, 0)
	-- Refund any escrowed cash first, in old units, so it gets scaled with the rest.
	local escrow = MigrateUtil.num(d.EscrowCash, 0)
	d.EscrowCash = nil
	local after = math.floor((before + escrow) * 0.55)
	d.Cash = after
	if before + escrow > 0 then
		MigrateUtil.audit(d, "Revalue", { from = before + escrow, to = after, f = 0.55 })
	end
	return d
end,
```

**Diagnosing.** Log one custom analytics event per step that ran (see the observability section). After release, compare the distribution of "time to afford next gate" for migrated players against fresh players ([[Economies and Currencies]]). If migrated players blow through gates, the factor was too generous; you can ship a second step, but never edit this one.

**When not to.** If income changed by more than an order of magnitude, or if the rebalance also changed what items do, a revaluation rarely feels fair to anyone. A clearly announced reset that keeps purchases (rename the stores, keep the receipts store; see [[Data Schema Design and Migrations]]) is more honest, and it is cheaper to reason about.

---

## Case 2: splitting one key into two

**Situation.** Settings lived inside the main profile. You want them in their own key so a progress reset does not wipe keybinds (the reference project's reason), or because the profile is getting large and settings are written far more often than progress.

**The trap.** A split touches two keys, and nothing makes two writes atomic. The order you write them in decides what a crash costs you.

| Order | Crash between writes | Outcome |
|---|---|---|
| Delete from profile, then write new key | Profile saved without settings, new key never written | Settings lost |
| Write new key, then delete from profile | New key written, profile still has settings | Harmless: next load sees both, and the copy in the new key wins |

So: **copy first, delete later**, and make the reader tolerate both places for as long as old data exists. That second half usually means the deletion happens in a later release, not the same one.

```lua
--!strict
-- Load path for settings during and after the split.
local DataStoreService = game:GetService("DataStoreService")
local SettingsStore = DataStoreService:GetDataStore("Settings_v1")

local function loadSettingsAsync(userId: number, profile: { [string]: any }): { [string]: any }?
	local ok, stored = pcall(SettingsStore.GetAsync, SettingsStore, `u_{userId}`)
	if not ok then
		return nil -- caller treats settings as "unknown" and does NOT save them this session
	end
	if type(stored) == "table" then
		return stored -- the new key wins once it exists
	end
	-- Not split yet: lift from the profile. The profile copy is removed in a later
	-- release, after this code has been live long enough (and only after a confirmed write).
	local legacy = profile.Settings
	return if type(legacy) == "table" then table.clone(legacy) else {}
end
```

Two details people miss:

- **"Not found" and "read failed" are different.** `GetAsync` returning `nil` means no key; `pcall` failing means you do not know. Only the first may fall back to defaults. If you treat a failed read as "new player", the next save writes defaults over real settings ([[Data Loss Prevention and Recovery]]).
- **Privacy coverage.** A new key keyed by user id is new personal data. Add it to your deletion templates or your right to erasure handler before you ship ([[Player Privacy and Data Deletion]]).

**Budget.** A split adds one read per join and one write per settings save. With the per-server default budgets in [[DataStore Fundamentals]] this is nothing, but do the arithmetic if you split into many keys: each key is another read at join, and joins come in bursts after server restarts.

---

## Case 3: restructuring an inventory

**Situation.** Inventory was a dense array of records `{ Uid, Id, Level }`. Common items now number in the hundreds per player and dominate the profile size. You want commons as stack counts (`Stacks[id] = n`) and only notable items as unique records.

**The traps.**

- **Equips and locks reference Uids.** If an equipped item becomes a stack, its Uid disappears. Decide per reference: re-point to a surviving unique copy, or clear the slot and let the join code re-equip a default.
- **"Notable" must be decided by data, not by Id alone.** A common sword with a forge level, a mutation, a star count or a favourite flag is not interchangeable with a fresh copy. Collapsing it loses player investment. Only fully default copies may stack.
- **Caps.** If the new format has a stack cap or a unique-item cap, the migration may meet a player who exceeds it. Never drop the overflow: pay it out or move it to a mailbox.

```lua
-- Step 8 -> 9: collapse pristine common copies into stack counts.
[8] = function(d)
	local Items = MigrateUtil.tbl(d.Items)
	local stacks: { [string]: number } = MigrateUtil.tbl(d.Stacks)
	local keep = {}
	local equippedUids: { [string]: boolean } = {}
	for _, uid in MigrateUtil.tbl(d.Equipped) do
		if type(uid) == "string" then
			equippedUids[uid] = true
		end
	end
	local collapsed = 0
	for _, it in Items do
		if type(it) ~= "table" or type(it.Id) ~= "string" then
			continue -- garbage entry: drop it (it was never usable)
		end
		local def = ItemDefs[it.Id] -- loaded module, no yield
		local pristine = def ~= nil and def.Rarity == "Common"
			and MigrateUtil.num(it.Level, 1) <= 1
			and not it.Stars and not it.Mutation and not it.Locked and not it.Favorite
			and not equippedUids[it.Uid]
		if pristine then
			stacks[it.Id] = (stacks[it.Id] or 0) + 1
			collapsed += 1
		else
			table.insert(keep, it)
		end
	end
	d.Items = keep
	d.Stacks = stacks
	if collapsed > 0 then
		MigrateUtil.audit(d, "Stack", { n = collapsed })
	end
	return d
end,
```

Note what the step does not do: it never collapses an equipped item, so equip references stay valid without remapping. Avoiding a remap is usually cheaper than writing one.

**Measure before and after.** `#HttpService:JSONEncode(profile)` on a sample of heavy profiles before the release and after one week. The point of this migration is size; if the median did not move, your "pristine" rule was too strict.

---

## Case 4: re-tiering and id remaps

**Situation.** Content was reorganised: zones renumbered (measured in the reference project: old zone 7 became 10, 8 became 11, 14 became 20), two item ids merged into one, one item removed, and owner-only test items must be stripped from normal players.

**The traps.**

- **A partial map.** Any old id the map does not mention silently survives with a meaning that no longer exists. Make the map total and check it at boot.
- **Running twice.** A remap that is not idempotent applied twice moves zone 7 to 10 and then, if 10 is also a key in the map, to somewhere else. The reference project used a dedicated `LadderV = 1` flag for exactly this. With a schema step the version gate does the same job; with an every-load repair you need the flag.
- **Removing value.** Removed items were sold for their value on load, and stripped test items wrote an audit record such as `{ t = time, ids = {...}, paid = n }` (measured in the reference project).

```lua
--!strict
-- Data/IdRemap (ModuleScript): one table drives the migration AND a boot check.
local IdRemap = {}

-- old id -> new id, or false = removed (paid out at sell value)
IdRemap.Items = {
	flame_blade = "ember_blade",
	ember_blade_old = "ember_blade",
	beta_hammer = false,
} :: { [string]: string | false }

-- Boot check: every target exists, no target is itself remapped (no chains).
function IdRemap.Validate(defs: { [string]: any })
	for old, new in IdRemap.Items do
		if new then
			assert(defs[new] ~= nil, `remap target {new} for {old} does not exist`)
			assert(IdRemap.Items[new] == nil, `remap chain through {new}`)
		end
	end
end

return IdRemap
```

The "no chains" assertion is the cheap guarantee of idempotence: if no target is also a source, applying the map twice is the same as applying it once.

The step then walks `Items` and `Stacks`, renames, sums stacks that merge, and for `false` entries adds `SellValue(old)` to cash and records the ids. One rule matters for merges: when two unique records become the same id, keep both records (they have different Uids and possibly different levels). Only stacks merge by summing.

**Leaderboards and other stores.** If a leaderboard key, an `OrderedDataStore` name, or a MemoryStore map uses the old ids, those need their own plan. A lazy profile migration does not reach them. See case 7.

---

## Case 5: repairing data after a bug or an exploit

**Situation.** A duplication bug let some players clone an item, or a NaN reached a balance through a bad multiplier, or a crash era left duplicate Uids. You cannot know which profiles are affected until they load.

This is not a schema step. It is a **sanitizer**: an idempotent repair that runs on every load, after the steps, for as long as bad data might exist. It needs no version gate because running it on clean data changes nothing.

```lua
--!strict
-- Runs after Schema.migrate on every load. Returns how many fixes it made.
local function sanitize(d: { [string]: any }): number
	local fixes = 0
	for _, field in { "Cash", "Gems" } do
		local v = d[field]
		if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then
			d[field] = 0
			fixes += 1
			MigrateUtil.audit(d, "BadBalance", { f = field, v = tostring(v) })
		end
	end
	-- Duplicate Uids: keep the first record, give later copies a fresh Uid and flag them.
	local seen: { [string]: boolean } = {}
	for _, it in MigrateUtil.tbl(d.Items) do
		if type(it) == "table" and type(it.Uid) == "string" then
			if seen[it.Uid] then
				it.DupOf = it.Uid
				it.Uid = game:GetService("HttpService"):GenerateGUID(false)
				fixes += 1
			end
			seen[it.Uid] = true
		end
	end
	return fixes
end
```

Notice the duplicate handling flags rather than deletes. Inside one profile you cannot tell the original from the copy, and some duplicates are legitimate (a support re-grant that reused a Uid by mistake). Flagged copies can be reviewed, made untradeable, or removed later with evidence. Cross-profile duplicates (the same Uid in two players' inventories, the classic trade dupe) are invisible to a per-profile sanitizer; you find them with an offline scan over exported data. See [[Trading Systems Without Duplication]].

**Clawback is policy, not code.** Removing exploited currency from a child who received it in a trade is a support decision. Code should make it possible (the audit records), not automatic.

**Retire sanitizers deliberately.** Each one costs CPU on every load. Keep a counter of fixes per day ([[Crash and Error Telemetry]]); when it has been zero for a few weeks and you have bulk-scanned stored data, delete it in a release.

---

## Case 6: migrations that survive a rollback

This is the subtle one, and it is where the "refuse newer schema" guard from [[Data Schema Design and Migrations]] can hurt you.

**Situation.** Release N+1 ships a step from schema 9 to 10. Ten minutes later it has a crash bug and you roll back to release N ([[Release Process and Rollbacks]]). Every player who joined an N+1 server now has `Schema = 10` saved. Release N knows only 9, so the guard refuses to load them. You have converted a gameplay bug into "your data failed to load" for your most active players.

The guard is still right: an old server that loads schema 10 data and saves it back can destroy fields it does not understand. The fix is to separate two questions the single `Schema` number conflates:

- **Which version wrote this?** (`Schema`)
- **What is the oldest code that can safely read and rewrite it?** (`MinReader`)

Additive changes (a new field with a default) do not raise `MinReader`, because old code ignores the field... except it does not ignore it on save. Old code that saves the whole table it loaded keeps unknown fields only if it never rebuilds the table. So the rule needs one more piece: **old code must preserve unknown fields**. If your profile module always mutates the loaded table in place (never rebuilds it from a template), unknown fields survive a round trip through older code.

```lua
--!strict
local CURRENT_SCHEMA = 10
local MIN_READER_FOR_CURRENT = 9 -- schema 10 only ADDED fields; schema 9 code can round-trip it

local function canRead(d: { [string]: any }): (boolean, string?)
	local written = tonumber(d.Schema) or 1
	if written <= CURRENT_SCHEMA then
		return true
	end
	local minReader = tonumber(d.MinReader) or written
	if minReader <= CURRENT_SCHEMA then
		return true -- newer, but declared compatible with us
	end
	return false, `profile needs reader >= {minReader}, this server is {CURRENT_SCHEMA}`
end

-- After migrating, stamp both numbers. An older server that loads compatible newer data
-- must NOT lower Schema or MinReader when it saves.
local function stamp(d: { [string]: any })
	if (tonumber(d.Schema) or 1) < CURRENT_SCHEMA then
		d.Schema = CURRENT_SCHEMA
		d.MinReader = MIN_READER_FOR_CURRENT
	end
end
```

That gives you the **expand and contract** pattern for anything destructive:

| Release | What it does | `MinReader` | Safe to roll back to the previous release? |
|---|---|---|---|
| N+1 (expand) | Writes the new field **and** keeps the old one in sync; reads new if present, else old | unchanged | Yes |
| N+2 (switch) | Reads only the new field, still writes the old one | unchanged | Yes |
| N+3 (contract) | Stops writing the old field, step deletes it | raised | Only to N+2 |

Three releases is slow. It is worth it for currencies, inventories and anything money touched. For cosmetic fields a single release with a raised `MinReader` is fine.

**Diagnosing.** After any rollback, watch load failures by reason. A spike of "needs reader" refusals means a release raised `MinReader` that should not have.

---

## Case 7: when lazy migration is not enough

Lazy migration (on load) never touches players who do not return. That is fine for the profile itself, but wrong for anything read without loading the profile:

- **Leaderboards** built from an `OrderedDataStore` keyed by an old stat name, or holding values in old units after case 1. A revalued currency leaderboard shows returning players next to never-returning ones with ten-times-larger numbers. Start a new board name (`Cash_v2`) and backfill on join, or bulk rewrite ([[OrderedDataStores and Leaderboards]]).
- **Cross-player data**: trade ledgers, gift mailboxes, guild stores that embed item ids. Each needs the same id map from case 4, applied where it is read.
- **Analytics and support tools** that read raw profiles through Open Cloud. They must run the same `migrate` function, or they misreport old profiles.

Bulk migrations run outside the game against the shared experience budget, must skip keys with a live session lease, and should start with a snapshot ([[Open Cloud APIs]]). Rule of thumb: run them in a quiet hour, throttled to a fraction of the budget, and verify a sample of keys by loading them in Studio against a test universe first.

---

## Observability: knowing a migration worked

A migration that runs silently is a migration you cannot judge. Minimum instrumentation:

- **Per step**: count of profiles that ran it, and failures (a step that errors fails the whole load; that must be loud). `AnalyticsService:LogCustomEvent` per step name works, or a server log line you aggregate ([[Analytics and Funnels]]).
- **Per sanitizer**: fixes made.
- **Load failures by reason**: read failed, refused newer, step error, lease timeout.
- **Size**: profile byte size before and after for a sample.

Then a release-day routine (rule of thumb):

1. Snapshot data stores ([[Open Cloud APIs]]).
2. Run `migrate` over the fixture folder of anonymised real profiles from every schema era, in CI or the command bar ([[Testing Strategies and Frameworks]]). Assert idempotence: `migrate(migrate(x))` equals `migrate(x)`.
3. Publish, migrate servers to the latest update so old and new servers overlap for as short a time as possible.
4. Watch the counters for an hour. A step-error count above zero is a rollback trigger only if `MinReader` allows rolling back; otherwise it is a hotfix trigger.

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Step reads a nested field without checking the parent exists | Load failures for a handful of old players, same stack trace | `MigrateUtil.tbl` everywhere; fixture profiles with missing fields |
| Date-based condition inside a step | Players who return late are migrated differently | Gate on schema only |
| Delete before copy when splitting keys | Reports of reset settings after a crash or outage | Copy first, delete in a later release |
| Collapsing items that carry player investment | "My forged sword vanished" tickets | Only pristine items stack; audit record |
| Partial or chained id map | Ghost ids in inventories, items that change twice | Total map, boot assertion, no chains |
| Sanitizer that deletes duplicates | Legitimate items removed | Flag, review, then act |
| Destructive change without expand and contract | Rollback locks players out | `MinReader`, three-release pattern |
| Profile module rebuilds tables from a template on save | Fields from newer releases vanish after a rollback | Mutate in place; preserve unknown keys |
| Leaderboards left in old units | Board dominated by inactive players | New board name plus backfill |

## Checklist

- [ ] Every step pure, non-yielding, total over all historical shapes.
- [ ] Anything taken away leaves a `MigrationLog` entry.
- [ ] Paid value never shrinks in a migration.
- [ ] Multi-key changes: copy first, delete later; failed reads never treated as empty.
- [ ] Id maps total, validated at boot, no chains.
- [ ] Repairs written as idempotent sanitizers with fix counters and a retirement plan.
- [ ] `MinReader` stamped; destructive changes use expand and contract.
- [ ] Profile module preserves unknown fields on save.
- [ ] Cross-player stores and leaderboards have their own migration plan.
- [ ] Fixtures from every schema era run through `migrate` twice in CI.
- [ ] Snapshot before release; counters watched after.

## See also
[[Data Schema Design and Migrations]] · [[Session Locking and Profile Libraries]] · [[Data Loss Prevention and Recovery]] · [[Release Process and Rollbacks]] · [[Open Cloud APIs]] · [[OrderedDataStores and Leaderboards]] · [[Economies and Currencies]] · [[Trading Systems Without Duplication]] · [[Economy Inflation Sinks and Faucets Math]] · [[Testing Strategies and Frameworks]] · [[Player Privacy and Data Deletion]]

## Connected notes
<!-- auto-links:start -->
[[Data Schema Versioning]] · [[Cookbook - Data and Saving]] · [[Saved Inventory End to End]] · [[Server Shutdowns Soft Updates and Migration]] · [[Refunds Chargebacks and Purchase Support]] · [[Skill - Roblox DataStore Safety]]
<!-- auto-links:end -->
