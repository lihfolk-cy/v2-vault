---
tags: [reference, limits, quotas, defaults, platform, type/reference, area/platform, level/intermediate, api/HttpService, area/security, api/MessagingService, api/ParticleEmitter]
---
# Engine Limits, Quotas and Defaults - Cheat Sheet

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: assuming the MessagingService limit is per server.
> - Avoid: sending full state over an `UnreliableRemoteEvent`.
> - Avoid: writing a large profile to one DataStore key many times a minute.
> - DataStore keys, names and scopes are 50 characters or less; values are measured with `JSONEncode` and stay far below 4 MB.
> - Autosave frequency x profile size stays under 4 MB/min per key.
> - `GetRequestBudgetForRequestType` is logged before bulk reads or writes.
>
> Cost: TL;DR ~160 tok · whole note ~4.2k tok. Read more: ## DataStoreService · ## Workspace, Players, Humanoid defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The numbers people most often get wrong, in one place. Every row was checked against the current Creator Hub docs (create.roblox.com, whose source is the public `Roblox/creator-docs` repository), **verified 2026-10-29**. Roblox says several of these "are subject to change", so re-check the linked page before you design around a ceiling. Anything that could not be confirmed in the docs is left out on purpose, including undocumented defaults such as ProximityPrompt `MaxActivationDistance`. For the reasoning behind each limit, see [[DataStore Fundamentals]], [[MemoryStore Service]], [[Cross-Server Messaging]], [[HttpService and External APIs]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Rate Limiting and Abuse Prevention]], [[Instance Streaming]], [[Characters and Humanoids]], [[Particle Emitters In Depth]], [[Textures Decals and Texture Memory]], [[Parts Unions and MeshParts]], [[Raycasts Shapecasts and Spatial Queries]] and [[Data and Cloud Changes 2025-2026]].

Formula notation: `players` means players in this server, `CCU` means concurrent users across the whole game, and `servers` means live servers.

## DataStoreService

| Item | Value | Notes | Source |
|---|---|---|---|
| Data store name / key name / scope | 50 characters each | Applies to Open Cloud too | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits |
| Value size | 4,194,304 per key | Measured serialized (JSON). Check with `#HttpService:JSONEncode(v)` | same |
| Metadata | Key 50 chars, value 250 chars, total 300 chars | The total is the binding limit. The UserIds and metadata errors (512/513) show a dynamic "X" limit, so keep them small | same |
| Per-key read throughput | 25 MB per minute | Rolling 60 s, across all servers and Open Cloud | same |
| Per-key write throughput | 4 MB per minute | `SetAsync`, `IncrementAsync`, `UpdateAsync`, `RemoveAsync`. Each request is rounded up to the next KB | same |
| Server budget: read (`GetAsync`) | 60 + players x 40 per min | Standard and ordered are the same | same |
| Server budget: write | Standard 60 + players x 40; ordered 30 + players x 5 | Configurable with `SetRateLimitForRequestType` (Standard/Ordered types: base 0-10,000, per player 0-200; UpdateAsync/OnUpdate types can't be set) | same |
| Server budget: list | 5 + players x 2 per min | `ListKeysAsync`, `ListVersionsAsync`, `GetSortedAsync` | same |
| Server budget: remove | Standard 60 + players x 40; ordered 30 + players x 5 | `RemoveVersionAsync` (deprecated): 5 + players x 2 | same |
| Startup burst | One-time extra budget on new servers | Size not documented | same |
| Experience-wide budget (servers + Open Cloud) | Read 300 + CCU x 40, write 300 + CCU x 20, list 300 + CCU x 2, remove 300 + CCU x 40 | `UpdateAsync` spends read and write. The base was 250 before mid-2026 | same |
| Request queue | 30 requests per queue | When it is full, requests fail with 301-306 | same |
| Storage per game | 500 MB + 1 MB x lifetime users | Compressed size of the latest version only. Data stores deleted through `DeleteDataStore` count for their 30-day deletion window | same |
| `GetSortedAsync` page size | 1 to 100 | Min/Max must be integers, Max >= Min | same |
| `GetVersionAtTimeAsync` timestamp | At most 10 minutes in the future | Otherwise InvalidTimestamp | same |
| Version retention | Superseded versions expire 30 days after a newer write | The latest version never expires | https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching |
| `GetAsync` cache | 4 seconds per data store instance | Use `DataStoreGetOptions.UseCache = false` to verify a write | same |

## MemoryStoreService

| Item | Value | Notes | Source |
|---|---|---|---|
| Memory quota | 64 KB + 1.2 KB x users, per game | It takes 8 days to fall after users leave | https://create.roblox.com/docs/cloud-services/memory-stores |
| Request units | 1,000 + 120 x CCU per minute, per game | Most calls cost 1. `GetRangeAsync` and `ReadAsync` cost 1 per item returned (minimum 1). Hash map `UpdateAsync` costs at least 2 | same |
| Per sorted map or queue | 1,000,000 items, 100 MB, 100,000 request units per min | Includes sorted map keys | same |
| Partition throttling | About 30,000 request units per minute per partition | Estimate, may change | same |
| Hash map per key | About 5,000 write units and 15,000 read units per minute | Single-key operations only | same |
| Hash map key / value | 128 characters / 32 KB | | https://create.roblox.com/docs/cloud-services/memory-stores/hash-map |
| Sorted map key / sort key / value | 128 chars / 128 chars / 32 KB | Sort key is a number or a string | https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map |
| Max expiration | 3,888,000 s (45 days) | Values above it error. 45 days is also the default for `AddAsync` and sorted map `SetAsync` | same |
| Queue invisibility timeout | 30 s default | Second argument of `GetQueue` | https://create.roblox.com/docs/cloud-services/memory-stores/queue |

## MessagingService

| Item | Value | Notes | Source |
|---|---|---|---|
| Message size | 1 kB | Send an id and look up the payload elsewhere | https://create.roblox.com/docs/reference/engine/classes/MessagingService |
| Topic name | 1 to 80 characters | | same |
| Messages sent per server | 600 + 240 x players per minute | | same |
| Messages received per topic | 40 + 80 x servers per minute | The usual limit to break with one global topic | same |
| Messages received for the whole game | 400 + 200 x servers per minute | | same |
| Subscriptions per server | 20 + 8 x players | | same |
| Subscribe requests per server | 240 per minute | | same |

## HttpService

| Item | Value | Notes | Source |
|---|---|---|---|
| External requests | 500 per minute per server | Requests over the limit fail | https://create.roblox.com/docs/reference/engine/classes/HttpService |
| Open Cloud via HttpService | 2,500 per minute per server, separate | Over the limit, calls can stall about 30 s with "Number of Open Cloud requests exceeded limit" | https://create.roblox.com/docs/cloud-services/http-service |
| Open Cloud headers | Only `x-api-key` and `content-type` | | same |
| Ports | Ports below 1024 are blocked except 80 and 443; 1194 is blocked | | same |
| Streaming clients (`CreateWebStreamClient`) | 4 at a time | Studio only: remove before publishing; close streams you no longer need | https://create.roblox.com/docs/reference/engine/classes/HttpService |
| `GenerateGUID` length | 36 characters (`8-4-4-4-12`) | | same |

## Remotes

| Item | Value | Notes | Source |
|---|---|---|---|
| Client-to-server rate | About 500 requests per second per client | Shared among all remotes of the same type (all `RemoteEvent`s together) | https://create.roblox.com/docs/reference/engine/classes/RemoteEvent |
| `UnreliableRemoteEvent` payload | Larger than 1,000 bytes is dropped | Not resent. Studio Output says how many bytes it was over | https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent |
| `RemoteEvent` queue | Limited in count and memory (no figure given) | When full, messages are discarded with a "Remote event invocation" error | https://create.roblox.com/docs/scripting/events/remote |
| Arguments | No mixed tables, no nil gaps, non-string keys become strings, functions and metatables are lost, non-replicated instances arrive as nil | | same |

## Teleports, badges, marketplace, bans

| Item | Value | Notes | Source |
|---|---|---|---|
| Players per `TeleportAsync` call | 50 | Group teleports only within one experience | https://create.roblox.com/docs/reference/engine/classes/TeleportService |
| Teleport data | Visible to the client, not encrypted | Size is not documented. Use DataStores or MemoryStores for anything that matters | https://create.roblox.com/docs/projects/teleport |
| `AwardBadgeAsync` | 50 + 35 x users per minute | | https://create.roblox.com/docs/reference/engine/classes/BadgeService |
| `UserHasBadgeAsync` | 50 + 35 x players per minute | | same |
| `CheckUserBadgesAsync` / `GetUserBadgesAsync` | 10 + 5 x players per minute per server | | same |
| Badge creation | 5 free per game per 24 h (GMT), then 100 Robux each | | https://create.roblox.com/docs/production/publishing/badges |
| `RankProductsAsync` / `RecommendTopProductsAsync` | 10 / 5 requests per minute (client-side throttle) | Wait 60 s after hitting it | https://create.roblox.com/docs/reference/engine/classes/MarketplaceService |
| Ban `DisplayReason` / `PrivateReason` | 400 / 1,000 characters | `DisplayReason` is filtered; `PrivateReason` is not, and the client never sees it. `Duration = -1` means permanent | https://create.roblox.com/docs/reference/engine/classes/Players |

## Instances, attributes, queries

| Item | Value | Notes | Source |
|---|---|---|---|
| `Instance.Name` | 100 characters | | https://create.roblox.com/docs/reference/engine/classes/Instance |
| Attribute name | 100 characters; letters, digits, `.` `-` `/` `_`; no spaces; no `RBX` prefix | Unsupported value types throw | same (`SetAttribute`) |
| `Raycast` direction length | 15,000 studs max | The direction's length is the ray's length, so `.Unit` gives a 1-stud ray | https://create.roblox.com/docs/reference/engine/classes/WorldRoot |
| Legacy `FindPartsInRegion3` maxParts | 20 by default | Prefer `GetPartBoundsInBox` with `OverlapParams.MaxParts` | same |

## Workspace, Players, Humanoid defaults

| Item | Value | Notes | Source |
|---|---|---|---|
| `Workspace.Gravity` | 196.2 studs/s² | | https://create.roblox.com/docs/reference/engine/classes/Workspace |
| `FallenPartsDestroyHeight` | Clamped to -50,000 to 50,000 | Parts below it are parented to nil | same |
| `StreamingEnabled` | On for new places | Cannot be set from a script | https://create.roblox.com/docs/workspace/streaming |
| `StreamingMinRadius` / `StreamingTargetRadius` | 64 / 1024 studs | | https://create.roblox.com/docs/reference/engine/classes/Workspace |
| `ModelStreamingBehavior` / `StreamOutBehavior` | `Legacy` / `LowMemory` | Docs recommend `Improved`. Models are `Nonatomic` by default | https://create.roblox.com/docs/workspace/streaming |
| `Players.RespawnTime` | 5 s | Only applies when `CharacterAutoLoads` is true (the default) | https://create.roblox.com/docs/reference/engine/classes/Players |
| `WalkSpeed` | 16 studs/s | From `StarterPlayer.CharacterWalkSpeed` | https://create.roblox.com/docs/reference/engine/classes/Humanoid |
| `UseJumpPower` / `JumpPower` / `JumpHeight` | true / 50 (range 0-1000) / 7.2 | Only one is active, depending on `UseJumpPower` | same |
| `MaxSlopeAngle` | 89° (range 0-89) | | same |
| `RequiresNeck` / `BreakJointsOnDeath` | true / true | | same |
| Health regeneration | Default script heals 1% of `MaxHealth` per second | Disable it with an empty Script named `Health` in StarterCharacterScripts | same |

## UI, VFX, audio

| Item | Value | Notes | Source |
|---|---|---|---|
| `BillboardGui.MaxDistance` | 0 or inf (default) = no limit | `AlwaysOnTop` false, `Brightness` 1 (0-1000) | https://create.roblox.com/docs/reference/engine/classes/BillboardGui |
| `SurfaceGui.MaxDistance` | 1000 (default) | `SizingMode` defaults to `PixelsPerStud` | https://create.roblox.com/docs/reference/engine/classes/SurfaceGui |
| `TweenInfo.new()` | time 1, `Quad`, `Out`, repeat 0, reverses false, delay 0 | `-1` repeat = forever | https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo |
| `ParticleEmitter.Rate` cap | 400 particles/s per emitter (100 on mobile) | | https://create.roblox.com/docs/effects/particle-emitters |
| Particle lifetime cap | 20 s | Higher values are capped at 20 | same |
| `ParticleEmitter.LightInfluence` | 1 from Studio insert, 0 from `Instance.new` | Same script and different look depending on how the emitter was made | https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter |
| `Sound.Volume` | 0.5 default (range 0-10) | `AudioPlayer.Volume` range 0-10, `PlaybackSpeed` range 0-20 | https://create.roblox.com/docs/reference/engine/classes/Sound |
| Audio upload | Under 20 MB and 7 minutes | 2,000 free uploads per 30 days if ID-verified, 100 if not | https://create.roblox.com/docs/audio/assets |

## Assets, places, publishing

| Item | Value | Notes | Source |
|---|---|---|---|
| Mesh triangles | 20,000 per mesh | | https://create.roblox.com/docs/art/modeling/specifications |
| Texture resolution | Up to 4096 x 4096 supported | The same page also says 1024 x 1024 is the "Maximum Texture Resolution" for UV texture maps. Plan for 1024 on meshes and treat 4096 as the upload ceiling | https://create.roblox.com/docs/art/modeling/texture-specifications |
| Texture sizing guide | 256 for 5x5 studs, 512 for 10x10, 1024 for 20x20 | Parts show 1024 across an 8x8 face; terrain 512 across 8x8 | same |
| Place size | 100 MB (104,857,600 bytes) | Over it, Save and Publish may fail | https://create.roblox.com/docs/production/publishing/publish-games-and-places |
| New game releases | 5 never-released games per day | | same |
| Publishing fee | 1,000 Robux, refundable, per game | Refunded after 25 highly engaged players for 60 days. Expedited review costs 50,000 Robux | same |

## Terrain

| Item | Value | Notes | Source |
|---|---|---|---|
| Voxel size | 4 studs | `ReadVoxels`/`WriteVoxels` resolution must be 4 | https://create.roblox.com/docs/reference/engine/classes/Terrain |
| Region per `ReadVoxels`/`WriteVoxels` call | 4,194,304 voxels max | Split larger regions into chunks | same |
| `MaxExtents` | ±32,000 cells (±128,000 studs) | The largest region terrain can occupy | same |

## Common mistakes

- Avoid: assuming the MessagingService limit is per server. Symptom: one busy global topic silently loses messages once received traffic passes 40 + 80 x servers per minute.
- Avoid: sending full state over an `UnreliableRemoteEvent`. Symptom: updates over 1,000 bytes vanish without an error in live servers.
- Avoid: writing a large profile to one DataStore key many times a minute. Symptom: that key throttles at 4 MB/min of writes (rounded up per KB) even though the server's request budget is fine.
- Avoid: using a raw `Unit` vector as the Raycast direction. Symptom: hits only within 1 stud; directions longer than 15,000 studs are also cut off.
- Avoid: MemoryStore expirations above 3,888,000 seconds. Symptom: `SetAsync` or `AddAsync` errors, because the maximum is 45 days.
- Avoid: attribute names with spaces or symbols. Symptom: `SetAttribute` throws for anything other than letters, digits, `.` `-` `/` `_`, or for names over 100 characters.
- Avoid: creating particle emitters with `Instance.new` and copying Studio-tuned values. Symptom: the effect looks brighter in dark areas because `LightInfluence` is 0 instead of 1.
- Avoid: Lifetime over 20 or Rate over 400 on particles. Symptom: the effect is shorter or sparser than set, and sparser still on phones (100/s cap).
- Avoid: verifying a DataStore write with plain `GetAsync`. Symptom: the read returns the value from up to 4 s earlier.
- Avoid: mixing HttpService and Open Cloud calls in one budget calculation. Symptom: external calls fail at 500/min while Open Cloud calls stall at 2,500/min.

## Checklist

- [ ] DataStore keys, names and scopes are 50 characters or less; values are measured with `JSONEncode` and stay far below 4 MB.
- [ ] Autosave frequency x profile size stays under 4 MB/min per key.
- [ ] `GetRequestBudgetForRequestType` is logged before bulk reads or writes.
- [ ] MemoryStore values are 32 KB or less, keys 128 characters or less, and expirations 45 days or less.
- [ ] MessagingService payloads are 1 kB or less; topics are sharded when many servers publish.
- [ ] Unreliable remote payloads are well under 1,000 bytes; remote spam is rate limited per player.
- [ ] HTTP calls stay under 500/min per server, with Open Cloud budgeted separately.
- [ ] Ray directions are scaled to the intended range and stay 15,000 studs or less.
- [ ] Meshes are 20,000 triangles or less; mesh textures are 1024 or less unless there is a reason; the place is under 100 MB.
- [ ] Defaults the game depends on (WalkSpeed 16, JumpPower 50 / JumpHeight 7.2, RespawnTime 5, Gravity 196.2, streaming radii 64/1024) are set explicitly when the design depends on them.

<!-- related:start -->
## Related
[[DataStoreService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[BillboardGui - Engine Reference Card]] · [[Badges and Achievement Design]] · [[Engine and API Changes 2025-2026]]
<!-- related:end -->
