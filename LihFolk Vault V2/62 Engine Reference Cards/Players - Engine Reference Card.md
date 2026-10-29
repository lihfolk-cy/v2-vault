---
tags: [reference, engine, players, api/Players, type/reference, area/scripting, level/intermediate, api/PlayerRemoving]
---

# Players - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: using LocalPlayer in a server Script.
> - Avoid: calling name and ID lookups without pcall.
> - Avoid: connecting PlayerAdded only after slow setup.
> - Connect PlayerAdded, then run the handler for everyone already in GetPlayers().
> - Look up purchasers with GetPlayerByUserId and handle nil.
> - Wrap every Async lookup in pcall and cache results.
>
> Cost: TL;DR ~130 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The service that lists connected users and handles joins, leaves, lookups and bans; see [[Cookbook - Players and Characters]], [[Player]] and [[PlayerRemoving]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| LocalPlayer | prop | Player | nil on the server | Defined only for client code | No |
| MaxPlayers | prop | int | From place settings | Read only; change it on the Creator Dashboard | No |
| PreferredPlayers | prop | int | From place settings | Read only; matchmaker fill target, below MaxPlayers | No |
| RespawnTime | prop | float (seconds) | 5.0 | Applies while CharacterAutoLoads is true | No |
| CharacterAutoLoads | prop | boolean | true | Not Replicated; false means you call LoadCharacterAsync yourself | No |
| BanningEnabled | prop | boolean | - | Set only in Studio's Properties window; gates the ban API | No |
| PlayerAdded | event | (player: Player) | - | Fires as a player joins | - |
| PlayerRemoving | event | (player: Player, reason: Enum.PlayerExitReason) | - | Fires before ChildRemoved; a good save point | - |
| GetPlayers | method | () -> {Player} | - | Only Player children | No |
| GetPlayerByUserId | method | (userId) -> Player? | - | nil if not in this server; handy in ProcessReceipt | No |
| GetPlayerFromCharacter | method | (character: Model) -> Player? | - | nil for NPC models | No |
| GetUserIdFromNameAsync | method | (userName: string) -> int64 | - | Errors if no account exists; wrap in pcall | Yes |
| GetNameFromUserIdAsync | method | (userId) -> string | - | Errors if no account exists; wrap in pcall | Yes |
| GetUserThumbnailAsync | method | (userId, ThumbnailType, ThumbnailSize) -> (url, isReady) | - | Feed the URL to ImageLabel.Image | Yes |
| GetHumanoidDescriptionFromUserIdAsync | method | (userId) -> HumanoidDescription | - | Replaces deprecated GetHumanoidDescriptionFromUserId | Yes |
| [[CreateHumanoidModelFromDescriptionAsync]] | method | (description, rigType, assetTypeVerification = Default) -> Model | - | Replaces deprecated CreateHumanoidModelFromDescription | Yes |
| GetFriendsAsync | method | (userId) -> FriendPages | - | Paged results | Yes |
| BanAsync | method | (config: Dictionary) -> () | - | Server only; client calls error | Yes |
| UnbanAsync | method | (config: Dictionary) -> () | - | Also lifts Open Cloud user-restriction bans | Yes |
| GetBanHistoryAsync | method | (userId) -> BanHistoryPages | - | Succeeds on production servers only | Yes |

## Limits and defaults

- RespawnTime default: 5.0 seconds.
- BanAsync `UserIds`: up to 50 per call.
- BanAsync `Duration`: seconds; `-1` makes the ban permanent.
- BanAsync `DisplayReason`: up to 400 characters, text-filtered, shown to the user.
- BanAsync `PrivateReason`: up to 1000 characters, never sent to the client.
- BanAsync `ApplyToUniverse` (set false to limit to this place) and `ExcludeAltAccounts` control scope.

## Replication and authority

- Players and its Player children are visible to every client; LocalPlayer resolves only on the client.
- Ban methods run on the server only; bans made in Studio or team test do not reach production.
- MaxPlayers and PreferredPlayers come from place settings and are read only at runtime.
- BanningEnabled is toggled in Studio, not from Luau.

## Common mistakes

- Avoid: using LocalPlayer in a server Script. Symptom: it is nil and the script errors.
- Avoid: calling name and ID lookups without pcall. Symptom: the script stops on unknown names or deleted accounts.
- Avoid: connecting PlayerAdded only after slow setup. Symptom: early joiners never initialize; also loop over GetPlayers() once.
- Avoid: saving data only in PlayerRemoving. Symptom: lost progress on shutdown; pair it with game:BindToClose.
- Avoid: calling BanAsync from a LocalScript. Symptom: an error, because bans are server-side.

## Checklist

- [ ] Connect PlayerAdded, then run the handler for everyone already in GetPlayers().
- [ ] Look up purchasers with GetPlayerByUserId and handle nil.
- [ ] Wrap every Async lookup in pcall and cache results.
- [ ] Enable BanningEnabled in Studio before relying on BanAsync.

Source: https://create.roblox.com/docs/reference/engine/classes/Players (verified 2026-10-29)

<!-- related:start -->
## Related
[[Player - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[Humanoid - Engine Reference Card]]
<!-- related:end -->
