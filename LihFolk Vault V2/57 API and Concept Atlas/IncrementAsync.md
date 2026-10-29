---
tags: [atlas, api, type/atlas, area/data, area/debugging, api/IncrementAsync]
---
# IncrementAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `IncrementAsync` is atomic per key; values must be integers.
> - `SetAsync`, `UpdateAsync` and `IncrementAsync` create a versioned backup on the first write to each key in each UTC hour.
> - `SetAsync`, `IncrementAsync`, `UpdateAsync`, `GetAsync`, `RemoveAsync` work as on a normal store, on integer values.
> - Every 60 s (jittered), one `IncrementAsync` per server adds its local delta to one of N shard keys (`Hatched_0..Hatched_7`...
>
> Cost: TL;DR ~150 tok · whole note ~390 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`IncrementAsync` is atomic per key; values must be integers. (from [[Global State and Live Config]])

API snapshot: member of `GlobalDataStore`, `MemoryStoreDistributedCounter` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `SetAsync`, `UpdateAsync` and `IncrementAsync` create a versioned backup on the first write to each key in each UTC hour. ([[DataStore Fundamentals]])
- `SetAsync`, `IncrementAsync`, `UpdateAsync`, `GetAsync`, `RemoveAsync` work as on a normal store, on integer values. ([[OrderedDataStores and Leaderboards]])
- Every 60 s (jittered), one `IncrementAsync` per server adds its local delta to one of N shard keys (`Hatched_0..Hatched_7`, chosen by `JobId` hash), then resets the local delta. ([[Global State and Live Config]])
- `IncrementAsync` is also atomic, but it cannot enforce a supply cap or attach metadata in the same step. ([[Serial-Numbered Limited Items - Atomic Counters]])

## Mentioned in

7 notes in 4 sections. The 7 most relevant are linked:

### 04 Data and Persistence
[[DataStore Fundamentals]] · [[Global State and Live Config]] · [[OrderedDataStores and Leaderboards]] · [[Serial-Numbered Limited Items - Atomic Counters]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 62 Engine Reference Cards
[[DataStoreService - Engine Reference Card]]

<!-- atlas:generated -->
