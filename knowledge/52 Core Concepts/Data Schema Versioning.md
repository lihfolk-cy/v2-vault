---
tags: [core-concept, data, persistence, migrations]
---
# Data Schema Versioning

**Data schema versioning** stores a version number inside every saved record and keeps a chain of migration functions that upgrade old records step by step to the current shape. A record saved at version 3 is run through migrations 3 to 4, 4 to 5 and so on when it is loaded.

## Why it matters on Roblox

Player data lives for years, and players come back after long breaks. The save format changes with every feature: currencies get renamed, inventories change from lists to dictionaries, stats split. Without versions, load code fills up with guesses ("if data.Gems is nil then maybe it is old"), and a wrong guess wipes or duplicates progress. DataStores have no schema system of their own (Roblox docs, as of October 2026); versioning is your responsibility.

## The nuance most people miss

1. **Migrations run on load, forever.** You cannot migrate every record in advance (there is no practical way to iterate all players' keys at scale), so every old migration must keep working for as long as old records might exist.
2. **Never edit a shipped migration.** If migration 4 to 5 had a bug, add migration 5 to 6 that repairs it. Records already migrated by the buggy version will not run it again.
3. **Old servers meet new data.** During a rolling update, an old server can load a record that a new server already upgraded. Old code that does not understand version 6 must refuse to save it (or load read-only), otherwise it writes back an older shape and destroys new fields.
4. **Fill defaults separately from migrations.** "Reconcile with defaults" (add any missing key with its default value) handles new optional fields; migrations handle renames, moves and type changes. Mixing the two hides bugs.
5. **Keep migrations pure and tested.** A migration is a function from table to table. Test each with real saved samples from before the change.
6. **Large renames are risky.** Prefer additive changes (new field, old one ignored) and remove old fields only after a long time.

## Tiny example

```lua
local CURRENT = 3
local migrations = {
	[1] = function(d) d.Coins = d.Gold; d.Gold = nil; return d end,      -- 1 to 2
	[2] = function(d) d.Inventory = { Items = d.Inventory or {} }; return d end, -- 2 to 3
}

local function migrate(d)
	d.Version = d.Version or 1
	if d.Version > CURRENT then error("data from a newer server; do not save") end
	while d.Version < CURRENT do
		d = migrations[d.Version](d)
		d.Version += 1
	end
	return d
end
```

## Where this shows up

- [[Data Schema Design and Migrations]]: the main reference.
- [[Schema Migrations - Worked Case Studies]]: real migrations.
- [[Session Locking and Profile Libraries]]: where migration runs on load.
- [[Server Shutdowns Soft Updates and Migration]]: old and new servers at once.
- [[Release Process and Rollbacks]]: rolling back without breaking data.
- [[Data Loss Prevention and Recovery]]: recovering from a bad migration.
- [[Serialization Formats for Saves and Networking]]: the shape of saved data.
- [[Saved Inventory End to End]]: a worked versioned inventory.
- [[Economy Resets and Seasonal Wipes]]: planned big migrations.
- [[Debugging DataStore Problems]]: diagnosing migration bugs.
- [[Automated Testing with TestEZ and Jest-Lua]]: testing migrations.
- [[Data and Config Pipeline - Spreadsheets to Game]]: versioned config, the same idea.

Related concepts: [[Session Lock]], [[Idempotency]], [[Feature Flags]].

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Data and Saving]] · [[Skill - Roblox DataStore Safety]] · [[Core Concepts Start Here]] · [[Live Ops Deep Dive Start Here]] · [[Multiplayer Services Start Here]] · [[Links - DataStoreService]]
<!-- auto-links:end -->
