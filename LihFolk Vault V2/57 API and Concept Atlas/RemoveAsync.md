---
tags: [atlas, api, type/atlas, area/data, area/networking, api/RemoveAsync]
---
# RemoveAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RemoveAsync` takes the id returned by a `ReadAsync` batch and removes that whole batch (Roblox docs).
> - `RemoveAsync` per key; ordered stores handled explicitly.
> - Removes the read batch with `RemoveAsync(readId)`.
> - If your process crashes before `RemoveAsync(id)`, they come back.
>
> Cost: TL;DR ~110 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RemoveAsync` takes the id returned by a `ReadAsync` batch and removes that whole batch (Roblox docs). (from [[Matchmaking Queues with MemoryStore]])

API snapshot: member of `GlobalDataStore`, `MemoryStoreHashMap`, `MemoryStoreQueue`, `MemoryStoreSortedMap` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `RemoveAsync` per key; ordered stores handled explicitly. ([[Resetting One Player's Data Safely]])
- Removes the read batch with `RemoveAsync(readId)`. ([[Matchmaking Queues with MemoryStore]])
- If your process crashes before `RemoveAsync(id)`, they come back. ([[MemoryStore Service]])
- `RemoveAsync` writes a tombstone: `GetAsync` returns `nil` afterwards, but earlier versions stay readable through the version APIs until they expire. ([[DataStore Fundamentals]])

## Mentioned in

12 notes in 7 sections. The 12 most relevant are linked:

### 04 Data and Persistence
[[DataStore Fundamentals]] · [[MemoryStore Service]] · [[OrderedDataStores and Leaderboards]] · [[Player Privacy and Data Deletion]]

### 24 Worked Builds
[[Codes Redemption System End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Server Browsers and Server Lists]]

### 49 Roblox Platform Features
[[Experience Notifications and Return Prompts]]

### 56 Field Notes
[[Field Notes Start Here]] · [[Resetting One Player's Data Safely]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
