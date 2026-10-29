---
tags: [reference, engine, teleportservice, api/TeleportService, type/reference, area/scripting, level/intermediate, api/TeleportAsync, api/Player]
---

# TeleportService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: calling `TeleportAsync` from a LocalScript.
> - Avoid: new code built on `ReserveServerAsync` access codes.
> - Avoid: setting both `ReservedServerId` and `ServerInstanceId`.
> - Server owns every teleport; clients only request through a validated RemoteEvent.
> - `TeleportAsync` wrapped in `pcall`, plus a `TeleportInitFailed` retry with backoff.
> - Reserved servers keyed by a stored GUID in `ReservedServerId`.
>
> Cost: TL;DR ~150 tok · whole note ~1.4k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Moves players between places and servers through one call, `TeleportAsync`, configured by a `TeleportOptions` instance. Topic notes: [[Teleporting and Multi-Place Games]], [[Parties and Group Teleports]], [[TeleportService]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| TeleportAsync | method | `(placeId: int64, players: {Player}, teleportOptions: TeleportOptions?) -> TeleportAsyncResult` | options = nil | Server only | yes |
| TeleportInitFailed | event | `(player, teleportResult: Enum.TeleportResult, errorMessage: string, placeId: int64, teleportOptions: TeleportOptions)` | - | Fires on client and server | - |
| GetPlayerPlaceInstanceAsync | method | `(userId: number) -> (currentInstance: bool, error: string, placeId: int64, instanceId: string)` | - | Server only; same game; throws if user offline, so pcall | yes |
| GetLocalPlayerTeleportData | method | `() -> Variant` | - | Client only; spoofable | no |
| GetArrivingTeleportGui | method | `() -> ScreenGui` | - | Client; loading screen you arrived with | no |
| SetTeleportGui | method | `(gui: ScreenGui)` | - | Client; set before each teleport | no |
| SetTeleportSetting / GetTeleportSetting | method | `(key: string, value: Variant)` / `(key) -> Variant` | - | Client only; persists across places of one game | no |
| PromptExperienceDetailsAsync | method | `(player: Player, universeId: int64) -> Enum.PromptExperienceDetailsResult` | - | Shows details card with a Join button | yes |
| LocalPlayerArrivedFromTeleport | event | `(loadingGui: Instance, dataTable: Variant)` | - | Client | - |
| TeleportOptions.ReservedServerId | prop | string | "" | Any GUID; first use creates the reserved server, reuse rejoins it | - |
| TeleportOptions.VipServerId | prop | string | "" | Target a private (VIP) server by `PrivateServerId` | - |
| TeleportOptions.ServerInstanceId | prop | string | "" | Target a specific `JobId` | - |
| TeleportOptions:SetTeleportData | method | `(data: Variant)` | - | Read on arrival via `Player:GetJoinData()` | no |
| TeleportOptions:GetTeleportData | method | `() -> Variant` | - | Reads what you set | no |

Retired names and their replacements:
- `ReserveServer`, `ReserveServerAsync`, `TeleportToPrivateServer`, `TeleportOptions.ShouldReserveServer` and `TeleportOptions.ReservedServerAccessCode` -> `TeleportAsync` with `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)`.
- `Teleport`, `TeleportPartyAsync`, `TeleportToPlaceInstance`, `TeleportToSpawnByName` -> `TeleportAsync` (client code fires a RemoteEvent; the server teleports).
- `CustomizedTeleportUI` does nothing now.

## Limits and defaults

- Up to 50 players per `TeleportAsync` call.
- Group teleports stay inside a single experience.
- Only one private-server routing field may be set per `TeleportOptions` (ReservedServerId, VipServerId, ReservedServerAccessCode, ShouldReserveServer, ServerInstanceId); setting two raises "Incompatible Parameters".
- A negative placeId, an empty player list or a non-Player entry each error immediately.
- The custom teleport GUI is ignored when the destination is in a different game and must be set again before each teleport.

## Replication and authority

- `TeleportAsync` is server-only; a client call errors with "TeleportAsync called from Client".
- Settings, arriving GUI and local teleport data are client APIs.
- Teleport data travels through the client, so exploiters can spoof it; keep currency and progress in DataStores.
- Check whether the current server is reserved with `game.PrivateServerId ~= ""` together with `game.PrivateServerOwnerId == 0`.

## Common mistakes

- Avoid: calling `TeleportAsync` from a LocalScript. Symptom: the call errors and nobody moves.
- Avoid: new code built on `ReserveServerAsync` access codes. Symptom: relying on a deprecated, unsupported path; generate a `ReservedServerId` GUID instead.
- Avoid: setting both `ReservedServerId` and `ServerInstanceId`. Symptom: "Incompatible Parameters" failure.
- Avoid: trusting teleport data for rewards. Symptom: exploiters arrive with inflated values.
- Avoid: ignoring `TeleportInitFailed`. Symptom: players stuck after a transient failure; retry with the event's fresh `TeleportOptions`, which already targets the same destination.
- Avoid: batching more than 50 players. Symptom: oversized group teleports fail; split them.

## Checklist

- Server owns every teleport; clients only request through a validated RemoteEvent.
- `TeleportAsync` wrapped in `pcall`, plus a `TeleportInitFailed` retry with backoff.
- Reserved servers keyed by a stored GUID in `ReservedServerId`.
- Teleport data treated as hints; authoritative data loaded on arrival.

Source: https://create.roblox.com/docs/reference/engine/classes/TeleportService and https://create.roblox.com/docs/reference/engine/classes/TeleportOptions - verified 2026-10-29

<!-- related:start -->
## Related
[[Joining Friends Parties and Private Servers]] · [[Reserved and Private Servers in Practice]] · [[MessagingService - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[HttpService - Engine Reference Card]] · [[Players - Engine Reference Card]]
<!-- related:end -->
