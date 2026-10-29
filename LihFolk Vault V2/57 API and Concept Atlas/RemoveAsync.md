---
tags: [atlas, api, type/atlas, area/data, area/networking, api/RemoveAsync]
---
# RemoveAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RemoveAsync` takes the id returned by a `ReadAsync` batch and removes that whole batch (Roblox docs).
> - Avoid: reading a queue without calling `RemoveAsync`.
> - `RemoveAsync` per key; ordered stores handled explicitly.
> - Removes the read batch with `RemoveAsync(readId)`.
>
> Cost: TL;DR ~110 tok · whole note ~430 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RemoveAsync` takes the id returned by a `ReadAsync` batch and removes that whole batch (Roblox docs). (from [[Matchmaking Queues with MemoryStore]])

API snapshot: member of `GlobalDataStore`, `MemoryStoreHashMap`, `MemoryStoreQueue`, `MemoryStoreSortedMap` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: reading a queue without calling `RemoveAsync`. ([[MemoryStoreService - Engine Reference Card]])
- `RemoveAsync` per key; ordered stores handled explicitly. ([[Resetting One Player's Data Safely]])
- Removes the read batch with `RemoveAsync(readId)`. ([[Matchmaking Queues with MemoryStore]])
- If your process crashes before `RemoveAsync(id)`, they come back. ([[MemoryStore Service]])

## Mentioned in

15 notes in 8 sections. The 15 most relevant are linked:

### 04 Data and Persistence
[[DataStore Fundamentals]] · [[MemoryStore Service]] · [[OrderedDataStores and Leaderboards]] · [[Player Privacy and Data Deletion]]

### 24 Worked Builds
[[Codes Redemption System End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Server Browsers and Server Lists]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Experience Notifications and Return Prompts]]

### 56 Field Notes
[[Field Notes Start Here]] · [[Resetting One Player's Data Safely]]

### 62 Engine Reference Cards
[[DataStoreService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
