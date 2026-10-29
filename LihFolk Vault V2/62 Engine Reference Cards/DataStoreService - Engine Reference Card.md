---
tags: [reference, engine, datastoreservice, api/DataStoreService, type/reference, area/scripting, level/intermediate, area/data, api/DataStore, api/UpdateAsync]
---

# DataStoreService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `SetAsync` for data that several servers may touch.
> - Avoid: yielding or doing side effects inside the `UpdateAsync` callback.
> - Avoid: confirming a save with a plain `GetAsync`.
> - Every read and write wrapped in `pcall`, retried with backoff, and checked against `GetRequestBudgetForRequestType` in hot paths.
> - Player data saved with `UpdateAsync` plus a session lock, on leave and in `game:BindToClose`.
> - Keys, names and scopes 50 characters or less; values sized with `#HttpService:JSONEncode(v)`.
>
> Cost: TL;DR ~170 tok · whole note ~1.7k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Persistent, experience-wide key/value storage reached through `DataStore` and `OrderedDataStore` objects, all inheriting the `GlobalDataStore` methods. Topic notes: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]], [[OrderedDataStores and Leaderboards]], [[Debugging DataStore Problems]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| GetDataStore | method | `(name: string, scope: string = "global", options: DataStoreOptions?) -> DataStore` | scope "global" | Server Scripts only | no |
| GetOrderedDataStore | method | `(name: string, scope: string = "global") -> OrderedDataStore` | scope "global" | Integer values, sortable | no |
| [[GetRequestBudgetForRequestType]] | method | `(requestType: Enum.DataStoreRequestType) -> int` | - | Requests left before throttling | no |
| SetRateLimitForRequestType | method | `(requestType: Enum.DataStoreRequestType, baseLimit: int, perPlayerLimit: int)` | - | Call once per type at server start; `UpdateAsync` and `OnUpdate` types error | no |
| GlobalDataStore:GetAsync | method | `(key: string, options: DataStoreGetOptions?) -> (Variant, DataStoreKeyInfo)` | cached read | Second return holds version and metadata | yes |
| GlobalDataStore:SetAsync | method | `(key: string, value: Variant, userIds: {number} = {}, options: DataStoreSetOptions?) -> Variant` | - | Returns the new version id; last writer wins | yes |
| GlobalDataStore:UpdateAsync | method | `(key: string, transformFunction: (old, DataStoreKeyInfo) -> (new, userIds?, metadata?)) -> (Variant, DataStoreKeyInfo)` | - | Read + write budget; callback may rerun, must not yield; `nil` cancels | yes |
| GlobalDataStore:IncrementAsync | method | `(key: string, delta: int = 1, userIds: {number} = {}, options: DataStoreIncrementOptions?) -> Variant` | delta 1 | Integers only | yes |
| GlobalDataStore:RemoveAsync | method | `(key: string) -> (Variant, DataStoreKeyInfo)` | - | Creates a tombstone version; versions can be read back | yes |
| GlobalDataStore:BatchGetAsync | method | `(keys: {string}, options: Dictionary?) -> Dictionary` | max keys 100 (server default) | `OrderedDataStore` only; missing keys omitted | yes |
| OrderedDataStore:GetSortedAsync | method | `(ascending: bool, pagesize: int, minValue: Variant?, maxValue: Variant?) -> DataStorePages` | - | Page size 1-100 | yes |
| DataStore:ListKeysAsync | method | `(prefix: string?, pageSize: int = 0, cursor: string?, excludeDeleted: bool = false) -> DataStoreKeyPages` | - | List budget | yes |
| DataStore:ListVersionsAsync | method | `(key, sortDirection: Enum.SortDirection = Ascending, minDate = 0, maxDate = 0, pageSize = 0) -> DataStoreVersionPages` | Ascending | Dates are Unix ms | yes |
| DataStore:GetVersionAsync | method | `(key: string, version: string) -> (Variant, DataStoreKeyInfo)` | - | Restore a backup | yes |
| DataStoreOptions.AllScopes | prop | boolean | false | Pass `""` as scope; keys become `scope/key` | - |
| DataStoreSetOptions:SetMetadata | method | `(attributes: Dictionary)` | - | Read back through `DataStoreKeyInfo:GetMetadata()` | no |
| DataStoreGetOptions.UseCache | prop | boolean | true | Set false to bypass the 4 s cache | - |

Retired names and their replacements:
- `GlobalDataStore:OnUpdate` -> poll with `GetAsync`, or use `MessagingService` to announce a change.
- `DataStore:RemoveVersionAsync` -> let old versions expire; `RemoveAsync` removes a key.

## Limits and defaults

- Data store name, key name and scope: 50 characters each.
- Value size: 4,194,304 per key, measured serialized as JSON; strings must be valid UTF-8.
- Metadata: key 50 characters, value 250 characters, 300 characters total.
- Per-key throughput: 25 MB/min read and 4 MB/min write (each write rounded up to the next KB).
- Server budgets per minute: read 60 + players x 40; standard write 60 + players x 40; ordered write 30 + players x 5; list 5 + players x 2.
- Experience-wide budgets per minute: read 300 + CCU x 40, write 300 + CCU x 20, list 300 + CCU x 2, remove 300 + CCU x 40.
- Request queue: 30 per queue; a full queue fails requests.
- `GetAsync` cache: 4 s per data store object.
- Superseded versions expire 30 days after a newer write; the latest version is kept.

## Replication and authority

- The service is `NotReplicated`; data stores work only from server `Script`s, and a `LocalScript` call errors.
- Studio reaches the live data only after "Enable Studio Access to API Services" is turned on in a published game; it then shares production data, so use a separate test place for risky tests.

## Common mistakes

- Avoid: `SetAsync` for data that several servers may touch. Symptom: one server silently overwrites another; use `UpdateAsync`.
- Avoid: yielding or doing side effects inside the `UpdateAsync` callback. Symptom: errors, or effects that run twice because the callback was retried.
- Avoid: confirming a save with a plain `GetAsync`. Symptom: you read the cached value from up to 4 s earlier; set `UseCache = false`.
- Avoid: saving a player's profile on every change. Symptom: per-key 4 MB/min and server write budgets throttle and requests queue.
- Avoid: unprotected calls. Symptom: one transient failure stops the save loop; wrap every `...Async` in `pcall` with retries.

## Checklist

- Every read and write wrapped in `pcall`, retried with backoff, and checked against `GetRequestBudgetForRequestType` in hot paths.
- Player data saved with `UpdateAsync` plus a session lock, on leave and in `game:BindToClose`.
- Keys, names and scopes 50 characters or less; values sized with `#HttpService:JSONEncode(v)`.
- `userIds` passed on writes so every key is tagged with the players it belongs to.

Source: https://create.roblox.com/docs/reference/engine/classes/DataStoreService, https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore, https://create.roblox.com/docs/reference/engine/classes/DataStore, https://create.roblox.com/docs/reference/engine/classes/DataStoreOptions and https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits - verified 2026-10-29

<!-- related:start -->
## Related
[[MemoryStoreService - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[HttpService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Players - Engine Reference Card]]
<!-- related:end -->
