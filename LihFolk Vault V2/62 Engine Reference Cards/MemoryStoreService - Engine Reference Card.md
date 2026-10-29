---
tags: [reference, engine, memorystoreservice, api/MemoryStoreService, type/reference, area/scripting, level/intermediate, area/performance, api/RemoveAsync]
---

# MemoryStoreService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: treating a memory store as permanent storage.
> - Avoid: reading a queue without calling `RemoveAsync`.
> - Avoid: `ReadAsync` with the default `waitTimeout` in a loop you need to stop.
> - Every call in `pcall` with backoff; throttling and quota errors are expected under load.
> - Expirations set as short as possible on every write.
> - Queue consumers remove items with the read id after finishing the work.
>
> Cost: TL;DR ~140 tok · whole note ~1.5k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Fast, shared, temporary storage for every server of one experience: queues, sorted maps and hash maps whose items expire on their own. Topic notes: [[MemoryStore Service]], [[Matchmaking Queues with MemoryStore]], [[Global Leaderboards End to End]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| GetQueue | method | `(name: string, invisibilityTimeout: int = 30) -> MemoryStoreQueue` | 30 s | Server; name is global to the experience | no |
| GetSortedMap | method | `(name: string) -> MemoryStoreSortedMap` | - | Server | no |
| GetHashMap | method | `(name: string) -> MemoryStoreHashMap` | - | Server | no |
| MemoryStoreQueue:AddAsync | method | `(value: Variant, expiration: int64, priority: number = 0)` | priority 0 | Higher priority read first; equal priority in add order | yes |
| MemoryStoreQueue:ReadAsync | method | `(count: int, allOrNothing: bool = false, waitTimeout: number = -1) -> (items: {Variant}, id: string)` | waits forever at -1 | Items turn invisible, not removed; polls every 2 s | yes |
| MemoryStoreQueue:RemoveAsync | method | `(id: string)` | - | Uses the id from `ReadAsync`; no effect after the timeout | yes |
| MemoryStoreQueue:GetSizeAsync | method | `(excludeInvisible: bool = false) -> int` | counts invisible items | Server | yes |
| MemoryStoreSortedMap:SetAsync | method | `(key: string, value: Variant, expiration: int64, sortKey: Variant?) -> bool` | - | `true` when an existing key was overwritten | yes |
| MemoryStoreSortedMap:GetAsync | method | `(key: string) -> (Variant, sortKey)` | - | Both `nil` when missing | yes |
| MemoryStoreSortedMap:UpdateAsync | method | `(key: string, transformFunction: (value, sortKey) -> (value, sortKey), expiration: int64) -> (Variant, sortKey)` | - | Callback may rerun; return `nil` to cancel | yes |
| MemoryStoreSortedMap:GetRangeAsync | method | `(direction: Enum.SortDirection, count: int, exclusiveLowerBound: Variant?, exclusiveUpperBound: Variant?) -> {Dictionary}` | - | count 1-200; costs 1 unit per item | yes |
| MemoryStoreSortedMap:GetSizeAsync | method | `() -> int` | - | Item count | yes |
| MemoryStoreSortedMap:RemoveAsync | method | `(key: string)` | - | Server | yes |
| MemoryStoreHashMap:SetAsync | method | `(key: string, value: Variant, expiration: int64) -> bool` | - | `true` when an existing value was overwritten | yes |
| MemoryStoreHashMap:GetAsync | method | `(key: string) -> Variant` | - | `nil` when missing | yes |
| MemoryStoreHashMap:UpdateAsync | method | `(key: string, transformFunction: (old) -> new, expiration: int64) -> Variant` | - | At least 2 request units | yes |
| MemoryStoreHashMap:ListItemsAsync | method | `(count: int) -> MemoryStoreHashMapPages` | - | Costs partitions scanned + items returned | yes |
| MemoryStoreHashMap:RemoveAsync | method | `(key: string)` | - | Server | yes |

## Limits and defaults

- Memory quota per experience: 64 KB + 1.2 KB x users; it takes 8 days to fall after users leave, and writes that grow memory fail once it is reached.
- Request units: 1,000 + 120 x CCU per minute for the whole experience; most calls cost 1.
- One sorted map or queue: 1,000,000 items, 100 MB, 100,000 request units per minute.
- Hash map: keys up to 128 chars, value 32 KB. Sorted map: keys and sort keys up to 128 chars each, value 32 KB.
- Expiration: 0 to 3,888,000 s (45 days); keep it as short as the feature allows.
- Queue invisibility timeout: 30 s by default; `ReadAsync` count up to 100.

## Replication and authority

- Calls must come from the server (a client call fails with `InvalidClientAccess`), and the place must be published; send results to clients through remotes.
- Data is shared live by all servers of the experience, so the structure itself is the source of truth while it lives; copy anything permanent to a data store.
- Studio and production memory stores are isolated from each other, with the same limits; quotas based on users stay small in a solo test.

## Common mistakes

- Avoid: treating a memory store as permanent storage. Symptom: items vanish when they expire; persist lasting data with `DataStoreService`.
- Avoid: reading a queue without calling `RemoveAsync`. Symptom: items reappear after the invisibility timeout and get processed twice.
- Avoid: `ReadAsync` with the default `waitTimeout` in a loop you need to stop. Symptom: the thread waits indefinitely; pass a finite timeout.
- Avoid: large `GetRangeAsync` pages on every heartbeat. Symptom: request units run out because each returned item costs one.
- Avoid: expirations above 3,888,000 s. Symptom: the call errors.

## Checklist

- Every call in `pcall` with backoff; throttling and quota errors are expected under load.
- Expirations set as short as possible on every write.
- Queue consumers remove items with the read id after finishing the work.
- Request-unit cost estimated per minute at peak CCU.

Source: https://create.roblox.com/docs/reference/engine/classes/MemoryStoreService, https://create.roblox.com/docs/reference/engine/classes/MemoryStoreQueue, https://create.roblox.com/docs/reference/engine/classes/MemoryStoreSortedMap, https://create.roblox.com/docs/reference/engine/classes/MemoryStoreHashMap and https://create.roblox.com/docs/cloud-services/memory-stores - verified 2026-10-29

<!-- related:start -->
## Related
[[MessagingService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[HttpService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Players - Engine Reference Card]]
<!-- related:end -->
