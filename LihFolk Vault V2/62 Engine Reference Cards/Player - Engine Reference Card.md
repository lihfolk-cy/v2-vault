---
tags: [reference, engine, player, api/Player, type/reference, area/scripting, level/intermediate, api/CharacterAppearanceLoaded, api/CharacterAdded]
---

# Player - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: reading `player.Character` once at the top of a LocalScript.
> - Avoid: keying saves by Name or DisplayName.
> - Avoid: calling LoadCharacter or IsInGroup in new code.
> - Connect CharacterAdded first, then handle a character that already exists.
> - Use UserId for saves, bans and lookups.
> - Wrap yielding group calls in pcall and cache them per session.
>
> Cost: TL;DR ~130 tok · whole note ~1.4k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The per-user object under Players that owns the character, team and per-user settings; for patterns see [[Player]], [[Cookbook - Players and Characters]] and [[CharacterAdded]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Character | prop | Model | nil until first spawn | Set by the engine on spawn; can be nil between respawns | No |
| UserId | prop | int64 | - | Unique and permanent per account; the key for saved data | No |
| DisplayName | prop | string | - | Non-unique; for display only | No |
| Team | prop | Team | nil when neutral | Tagged Not Replicated on the page; assign it on the server | No |
| TeamColor | prop | BrickColor | - | Setting Team directly is usually clearer | No |
| Neutral | prop | boolean | - | true means Team is nil | No |
| RespawnLocation | prop | SpawnLocation | nil | Must be in Workspace and match TeamColor (or be Neutral) | No |
| CameraMode | prop | Enum.CameraMode | Classic (third person) | LockFirstPerson forces first person | No |
| CameraMaxZoomDistance / CameraMinZoomDistance | prop | float (studs) | From StarterPlayer | Each clamps against the other | No |
| AccountAge | prop | int (days) | - | Read only, Not Replicated | No |
| ReplicationFocus | prop | Instance | nil (character PrimaryPart used) | Steers streaming and replication priority | No |
| CharacterAdded | event | (character: Model) | - | Fires before the character is parented to Workspace | - |
| [[CharacterAppearanceLoaded]] | event | (character: Model) | - | Fires on the server only | - |
| CharacterRemoving | event | (character: Model) | - | Fires right before removal, e.g. on respawn | - |
| Idled | event | (time: double) | - | Client only; about 2 min after idle, then every 30 s | - |
| LoadCharacterAsync | method | () -> () | - | New character; clears Backpack and PlayerGui. Replaces deprecated LoadCharacter | Yes |
| Kick | method | (message: string) -> () | - | Server message up to 500 bytes; a LocalScript can kick only its own user | No |
| [[GetNetworkPing]] | method | () -> float (seconds) | - | Round-trip latency; on the client call it on LocalPlayer | No |
| IsInGroupAsync | method | (groupId: int64) -> boolean | - | Replaces deprecated IsInGroup; result may stay cached until the player leaves | Yes |
| GetRankInGroupAsync | method | (groupId: int64) -> int | - | Deprecated: use GroupService:GetRolesInGroupAsync() | Yes |
| RequestStreamAroundAsync | method | (position: Vector3, timeOut: double = 0) -> () | - | For streaming places, before moving a character far away | Yes |
| HasAppearanceLoaded | method | () -> boolean | - | Pairs with CharacterAppearanceLoaded | No |
| GetJoinData | method | () -> Dictionary | - | Describes how the player joined (SourceGameId and related keys) | No |
| GetMouse | method | () -> Mouse | - | Client input; UserInputService covers more devices | No |

## Limits and defaults

- Kick message sent from the server: at most 500 bytes.
- Idled: first fires about 2 minutes after the engine marks the player idle, then every 30 seconds while idle.
- Group rank from GetRankInGroupAsync: 0 (non-member) to 255 (owner).
- Camera zoom distances are in studs and start from the StarterPlayer values.
- AccountAge is in days; LocaleId is a code such as `en-us`.

## Replication and authority

- The engine creates the Player; the server owns team assignment, respawning and kicking other users.
- Team is tagged Not Replicated on the page, so set it from server code.
- AccountAge and LocaleId are read only and Not Replicated.
- Idled fires only in client scripts; forward it with a RemoteEvent if the server needs it.
- CharacterAppearanceLoaded fires only on the server.

## Common mistakes

- Avoid: reading `player.Character` once at the top of a LocalScript. Symptom: nil errors on spawn or a stale model after respawn; listen to CharacterAdded instead.
- Avoid: keying saves by Name or DisplayName. Symptom: lost or merged data; UserId never changes, so key by that.
- Avoid: calling LoadCharacter or IsInGroup in new code. Symptom: deprecation warnings; LoadCharacterAsync and IsInGroupAsync are the current names.
- Avoid: expecting IsInGroupAsync to refresh mid-session. Symptom: a player who left a group keeps perks until they rejoin.
- Avoid: letting clients ask the server to kick other players. Symptom: abuse; keep kicks behind trusted server checks.

## Checklist

- [ ] Connect CharacterAdded first, then handle a character that already exists.
- [ ] Use UserId for saves, bans and lookups.
- [ ] Wrap yielding group calls in pcall and cache them per session.
- [ ] Do team changes, respawns and kicks on the server.

Source: https://create.roblox.com/docs/reference/engine/classes/Player (verified 2026-10-29)

<!-- related:start -->
## Related
[[Players - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[MessagingService - Engine Reference Card]]
<!-- related:end -->
