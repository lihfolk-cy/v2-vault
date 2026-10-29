---
tags: [delta, deprecations, renames, async-rename, teleport, reserved-servers, textchatservice, chat, policyservice, subscriptions, input-action-system, ai-context, type/reference, area/platform, level/intermediate]
verified: 2026-10-29
---
# API Renames and Deprecations 2025-2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `Chat` service or `LegacyChatService` fork -> `TextChatService` (legacy retired April 30, 2025; auto-migrated from May...
> - Avoid: `BadgeService:AwardBadge(...)` -> `BadgeService:AwardBadgeAsync(...)` in `pcall`, on the server.
> - Avoid: `TeleportService:ReserveServerAsync` + `ReservedServerAccessCode` or `ShouldReserveServer` ->...
> - Reserved servers use a server-generated GUID in `TeleportOptions.ReservedServerId`; IDs never reach clients.
> - Custom direct channels use `CanUsersDirectChatAsync` and `SetDirectChatRequester`; chat-compatible grouping uses...
> - Subscription perks check `HasRobloxSubscription`; the Plus upsell uses `PromptRobloxSubscriptionPurchase`.
>
> Cost: TL;DR ~210 tok · whole note ~4.4k tok. Read more: ## Chat, text and links · ## Input, simulation, rendering, audio, avatars · ## Common mistakes · ## Checklist
<!-- tldr:end -->

One lookup table for Roblox API names that were renamed, deprecated, removed or replaced between January 2025 and October 29, 2026, with the replacement to write instead. Background and code for each area live in [[Engine and API Changes 2025-2026]], [[Server Authority and Input Migration 2026]], [[Policy and Age Rules 2026]], [[Discovery and Monetization Changes 2025-2026]] and [[Data and Cloud Changes 2025-2026]]; the lint patterns are in [[AI Pitfalls - Stale APIs and Luau]].

**Sources.** "Docs" means the official Creator Hub reference or guide (create.roblox.com, mirrored in the Roblox/creator-docs GitHub repository); a date after "Docs" is when that deprecation notice first appeared there. "PSA", "post" and "newsroom" are official Roblox staff announcements. Everything below was checked on 2026-10-29. "Still works" means the old name keeps its behaviour for existing code; deprecated names still show warnings in Script Analysis.

## Yielding methods renamed with `Async` (PSA, January 14, 2026)

46 methods gained an `Async` suffix. Old names are deprecated "informationally": same arguments, same returns, **still work and will not be removed**. Source: https://devforum.roblox.com/t/psa-several-common-yielding-methods-have-been-renamed/4257585

| Old (deprecated) | Write instead |
|---|---|
| `BadgeService:AwardBadge` | `BadgeService:AwardBadgeAsync` |
| `MarketplaceService:GetProductInfo` / `PlayerOwnsAsset` / `PlayerOwnsBundle` | `GetProductInfoAsync` / `PlayerOwnsAssetAsync` / `PlayerOwnsBundleAsync` |
| `Player:LoadCharacter` / `LoadCharacterWithHumanoidDescription` (deprecated) | `LoadCharacterAsync` / `LoadCharacterWithHumanoidDescriptionAsync` |
| `Player:IsInGroup` / `IsFriendsWith` / `GetFriendsOnline` (deprecated) | `IsInGroupAsync` / `IsFriendsWithAsync` / `GetFriendsOnlineAsync` |
| `Player:GetRankInGroup` / `GetRoleInGroup` | `GroupService:GetRolesInGroupAsync` (the `...InGroupAsync` versions are deprecated too, Docs Sept 2026) |
| `Humanoid:ApplyDescription` / `ApplyDescriptionReset` / `PlayEmote` | `ApplyDescriptionAsync` / `ApplyDescriptionResetAsync` / `PlayEmoteAsync` |
| `Players:CreateHumanoidModelFromDescription` / `FromUserId` | `CreateHumanoidModelFromDescriptionAsync` / `CreateHumanoidModelFromUserIdAsync` |
| `Players:GetHumanoidDescriptionFromUserId` / `FromOutfitId` (deprecated) | `GetHumanoidDescriptionFromUserIdAsync` / `GetHumanoidDescriptionFromOutfitIdAsync` |
| `TeleportService:ReserveServer` | No longer `ReserveServerAsync`: see the teleport table (both deprecated) |
| `SocialService:PromptLinkSharing` | `PromptLinkSharingAsync` |
| `AvatarEditorService:GetInventory`, `GetItemDetails`, `SearchCatalog`, `GetOutfits` and 9 more | Same name + `Async` |
| `AssetService:SearchAudio` / `GetAssetIdsForPackage` | `SearchAudioAsync` / `GetAssetIdsForPackageAsync` |
| `InsertService:GetFreeModels` / `GetFreeDecals` (deprecated) | `GetFreeModelsAsync` / `GetFreeDecalsAsync` |
| `AnimationClipProvider:GetAnimations`, `KeyframeSequenceProvider:GetAnimations` (deprecated) | `GetAnimationsAsync` |
| `Plugin:CreateDockWidgetPluginGui`, `ImportFbxRig`, `ImportFbxAnimation`, `PromptForExistingAssetId`, `PromptSaveSelection` (deprecated) | Same name + `Async` |
| Deprecated: `StudioService:PromptImportFile` / `PromptImportFiles`, `TestService:Run` | `PromptImportFileAsync` / `PromptImportFilesAsync`, `RunAsync` |

**Not renamed:** `Instance:WaitForChild`, `BindableFunction:Invoke`, `RemoteFunction:InvokeServer`, `RemoteFunction:InvokeClient`. New yielding methods will end in `Async` (PSA). The full 46-entry map is `deprecated_api_map` in `_data/roblox_facts_2026.json`. Also deprecated, older: `BadgeService:UserHasBadge` -> `UserHasBadgeAsync`.

## Teleports and reserved servers

| Old | Write instead | Still works? | Date | Source |
|---|---|---|---|---|
| `TeleportService:ReserveServerAsync` (and `ReserveServer`) + `TeleportOptions.ReservedServerAccessCode` (deprecated) | Server generates `HttpService:GenerateGUID(false)`, sets `TeleportOptions.ReservedServerId`, calls `TeleportAsync`; the first teleport with a new ID creates the server, reusing the ID joins it | Yes; access-code servers keep working. `ReserveServerAsync` "simply generates a random GUID" | Docs Oct 29, 2026 | https://create.roblox.com/docs/projects/teleport-private-servers |
| `TeleportOptions.ShouldReserveServer = true` (deprecated) | `ReservedServerId` with a fresh GUID | Yes | Docs Oct 29, 2026 | TeleportOptions reference |
| Access code for player-owned VIP servers | `TeleportOptions.VipServerId = <that server's game.PrivateServerId>` | n/a (new) | Docs Oct 29, 2026 | same guide |
| Mixing routing fields | Set only one of `ReservedServerId`, `VipServerId`, `ServerInstanceId`; more than one errors | n/a | Docs Oct 29, 2026 | same guide |
| `TeleportService:Teleport` (client teleports, deprecated) | Server-side `TeleportAsync`, client asks through a RemoteEvent | Yes; remove every call before setting Access Control for Places to Secure | Docs Aug 2026 | https://create.roblox.com/docs/projects/teleport |
| `TeleportPartyAsync`, `TeleportToPlaceInstance`, `TeleportToSpawnByName`, `TeleportToPrivateServer` (deprecated) | `TeleportAsync` (+ `ServerInstanceId` or `ReservedServerId`) | Yes | Docs Aug 13, 2026 | TeleportService reference |
| `SocialService:GetPartyAsync` entry `ReservedServerAccessCode` | Legacy only; share your own `ReservedServerId` | Field still returned | Docs Oct 2026 | SocialService reference |

On arrival, `game.PrivateServerId` equals the `ReservedServerId` you supplied. `TeleportAsyncResult.ReservedServerAccessCode` is filled only for legacy access-code teleports. No DevForum announcement of the `ReservedServerId` change was found as of 2026-10-29; the reference and guide are the source.

```lua
-- Server: party or match into a new reserved server (current docs pattern)
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local function sendToNewReservedServer(placeId: number, group: { Player }): string?
	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = HttpService:GenerateGUID(false) -- server-generated; never from a client
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, group, options)
	if not ok then
		warn("Teleport failed:", err)
		return nil
	end
	return options.ReservedServerId -- store it to send more players to the same server
end

return sendToNewReservedServer
```

## Chat, text and links

| Old | Write instead | Still works? | Date | Source |
|---|---|---|---|---|
| Legacy `Chat` system (`ChatServiceRunner`, `SayMessageRequest`, forked chat) | `TextChatService` (custom UI allowed, transport must be TextChannels) | No: removed, games auto-migrated | Apr 30, 2025 | https://devforum.roblox.com/t/migrate-to-textchatservice-removing-support-for-legacy-chat-and-custom-chat-systems/3237100 |
| Custom whisper/direct channels with no permission check | Filter members with `TextChatService:CanUsersDirectChatAsync(requesterUserId, userIds)`; call `TextChannel:SetDirectChatRequester(requester)` | Required; non-compliant chat may be disabled | Deadline Jan 30, 2025 | https://devforum.roblox.com/t/integrate-textchatservicecanusersdirectchatasync-or-textchannelsetdirectchatrequester-api-to-comply-with-settings/3255672 |
| `TextChatService.ChatVersion` (deprecated) | Nothing: TextChatService is the only chat system | Read-only for scripts | Docs June 2025 | TextChatService reference |
| Pairwise `CanUsersChatAsync` across a lobby | `TextChatService:GetChatGroupsAsync(players)` (server; enable Chat & Voice Groups APIs; same ID = can text chat); `VoiceChatService:GetChatGroupsAsync` for voice | n/a (new) | Feb 5 / Feb 13, 2026 | https://devforum.roblox.com/t/new-chat-apis-teleport-users-who-can-chat-together/4337233 |
| Reading `TextChatMessage.Text` / `.Translation` / `.PrefixText`, moderation in `OnIncomingMessage` or `Player.Chatted`, presets via `TextChannel:SendAsync` | `TextChatCommand`, read-only chat moderation, Quick Words, `TextChannelWindow` for custom UI | Unsupported (empty string + warning) when `TextChatService.PlatformIntegratedChat = Enabled`: opt-in now, auto opt-in Feb 2027, only option May 2027 | Oct 21, 2026 | https://devforum.roblox.com/t/important-textchatservice-updates-how-to-test-and-what%E2%80%99s-next/4948433 |
| Unlimited player text in signs, pet names, boards | Filter, and rate-limit to one submission per minute per player | Required (Phase 0, now) | Oct 21, 2026 | same post |
| `PolicyService` `AllowedExternalLinkReferences` for Discord/social handles in game | Social links only on the game page, profiles and Communities; in game say "see our game page" | Legacy field, always an empty array | Announced Nov 18, 2025; Docs Feb 2026 | https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702 |
| Social links visible to everyone | Visible only to age-checked 16+ viewers (13+ in the Nov 2025 plan) | n/a | June 2026 | https://en.help.roblox.com/hc/articles/360000910966 |

Legacy chat (`Chat` service, `ChatVersion = LegacyChatService`, forked Lua chat) was retired on April 30, 2025, and Roblox auto-migrated the remaining experiences to `TextChatService` in batches from May 2025. Custom or forked chat systems first had to honour `CanUsersDirectChatAsync` (deadline January 30, 2025) or be auto-migrated from February 2025. A revived game should set `TextChatService` and rebuild custom features on its channels and callbacks.

## Monetization and subscriptions

| Old | Write instead | Still works? | Date | Source |
|---|---|---|---|---|
| `MarketplaceService:PromptPremiumPurchase` (deprecated) | `MarketplaceService:PromptRobloxSubscriptionPurchase(player)` (Roblox Plus; creator gets a sign-up bonus) | Yes; Premium closed to new subscribers | Docs Apr 10, 2026 | https://devforum.roblox.com/t/introducing-roblox-plus/4567894 |
| `Player.MembershipType` for the subscription check (deprecated) | `Player.HasRobloxSubscription` | Yes; legacy Premium still reports `Enum.MembershipType.Premium` | Docs Apr 10, 2026 | Player reference |
| Hard-coded Robux prices | `GetProductInfoAsync` (Plus discounts and regional prices change the shown price) | n/a | Apr 2026 | Roblox Plus post |
| Legacy `apis.roblox.com/game-passes/v1` and `developer-products/v1/v2` web endpoints | Open Cloud Game Passes and Developer Products APIs | Deprecated | Apr 2026 | https://devforum.roblox.com/t/official-list-of-deprecated-web-endpoints/62889/119 |

New `PolicyService:GetPolicyInfoForPlayerAsync` flags to honour: `IsPhotoToAvatarAllowed` (Docs Oct 2025), `IsEndlessContentLoadAllowed` and `IsEndlessContentAutoplayAllowed` (Docs June 2026).

## Input, simulation, rendering, audio, avatars

| Old | Write instead | Still works? | Date | Source |
|---|---|---|---|---|
| `require(PlayerModule):GetControls()` and code relying on old input sinking | `InputContext` / `InputAction` / `InputBinding` (Input Action System); opt in with `Workspace.PlayerScriptsUseInputActionSystem` | Yes until Phase 2 (default on, early 2027); old scripts removed mid 2027 (planned) | June 11, 2026 | https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416 |
| `InputAction:Fire` (deprecated) | `InputBinding:Fire` on a binding of type `Enum.InputBindingType.Scriptable` | Yes | Docs Aug 13, 2026 | InputAction reference |
| `Player.InputContexts.CameraContext.CameraAction` under Server Authority | `Player:GetCameraState()` | Removed under Server Authority | July 9, 2026 | https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993 |
| `tick()`, `os.clock()` in simulation code under Server Authority | `time()` inside `RunService:BindToSimulation` | Not rollback-safe | July 9, 2026 | https://create.roblox.com/docs/projects/server-authority |
| `MeshPart.RenderFidelity` as an optimisation | `Workspace.MeshStreamingAndImprovedLoDs` (cloud LoDs + mesh streaming) | Ignored when Enabled; removal planned in Phase 3. Phase 2 (default on) **Unverified** as of Oct 29, 2026 | Apr 27, 2026 | https://devforum.roblox.com/t/introducing-mesh-streaming-and-improved-cloud-lods-in-published-experiences-opt-in-phase/4601232 |
| `AudioPlayer.AssetId` (deprecated) | `AudioPlayer.Asset` | Yes | Docs Feb 2025 | [[AudioPlayer]] reference |
| `AssetService:PromptCreateAssetAsync` (removed) | `AssetService:PromptCreatePlatformContentAsync` (takes an `Object`, e.g. an EditableImage) | Old name gone from the Oct 27, 2026 API dump | Oct 2026 | https://devforum.roblox.com/t/in-game-editable-image-publishing/4944421 |
| `GuiService:IsTenFootInterface` (deprecated) | `GuiService.ViewportDisplaySize` | Yes | Docs Apr 2026 | GuiService reference |
| `OpenCloudService:InvokeAsync` / `GetApiV1` (deprecated, no replacement named) | Open Cloud web APIs from your backend | Yes | Docs July 2026 | OpenCloudService reference |
| R6 avatars in a game that wants the US 18+ DevEx rate ($0.0054/Robux) | Avatar settings "R15 Only", R15 animation packs | R6 games keep the standard rate | June 8, 2026 | https://create.roblox.com/docs/production/monetization/18-plus-devex-rate |

Checked and **not** deprecated as of the October 27, 2026 API snapshot: `UnreliableRemoteEvent`, `Sound` (the Audio API objects are an alternative, not a replacement), `ContextActionService:BindAction`, Humanoid movement APIs (the Character Controller Library is opt-in).

**Left out (could not verify):** a December 1, 2026 date for `AvatarUnificationMode` deprecation; whether mesh streaming Phase 2 has shipped; a DevForum announcement for `ReservedServerId`.

## Common mistakes

- Avoid: `Chat` service or `LegacyChatService` fork -> `TextChatService` (legacy retired April 30, 2025; auto-migrated from May 2025).
- Avoid: `BadgeService:AwardBadge(...)` -> `BadgeService:AwardBadgeAsync(...)` in `pcall`, on the server.
- Avoid: `TeleportService:ReserveServerAsync` + `ReservedServerAccessCode` or `ShouldReserveServer` -> `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)` + `TeleportAsync`.
- Avoid: `TeleportPartyAsync`, client `TeleportService:Teleport` -> server `TeleportAsync`.
- Avoid: `GetProductInfo`, `PlayerOwnsAsset`, `LoadCharacter`, `IsInGroup`, `IsFriendsWith`, `ApplyDescription` -> the same name + `Async`.
- Avoid: `Player:GetRankInGroup` or `GetRankInGroupAsync` -> `GroupService:GetRolesInGroupAsync` and read the highest role's `Rank`.
- Avoid: Custom whisper/party chat without `CanUsersDirectChatAsync` -> filter members with it and set `TextChannel:SetDirectChatRequester`.
- Avoid: Pairwise chat checks across a lobby -> `TextChatService:GetChatGroupsAsync(players)` once.
- Avoid: `PromptPremiumPurchase` / `MembershipType` -> `PromptRobloxSubscriptionPurchase(player)` / `HasRobloxSubscription`.
- Avoid: Reading `TextChatMessage.Text` for filters or commands -> `TextChatCommand`; test with `PlatformIntegratedChat = Enabled`.
- Avoid: Discord or social handles in game UI -> point players to the game page's social links.
- Avoid: `PlayerModule:GetControls()` to disable movement -> disable an `InputContext`.
- Avoid: `RenderFidelity = Performance` as an optimisation -> budget triangles at the source.

## Checklist

- [ ] Reserved servers use a server-generated GUID in `TeleportOptions.ReservedServerId`; IDs never reach clients.
- [ ] Custom direct channels use `CanUsersDirectChatAsync` and `SetDirectChatRequester`; chat-compatible grouping uses `GetChatGroupsAsync`.
- [ ] Subscription perks check `HasRobloxSubscription`; the Plus upsell uses `PromptRobloxSubscriptionPurchase`.
- [ ] `rg -n ":(AwardBadge|UserHasBadge|GetProductInfo|PlayerOwnsAsset|LoadCharacter|IsInGroup|IsFriendsWith|GetRankInGroup|GetRoleInGroup|ApplyDescription|PlayEmote|ReserveServer|ReserveServerAsync|TeleportPartyAsync|TeleportToPlaceInstance|PromptPremiumPurchase)\("` returns nothing in new code.
- [ ] `rg -n "ReservedServerAccessCode|ShouldReserveServer|MembershipType|AllowedExternalLinkReferences|ChatVersion|\.AssetId"` hits are legacy reads only.
- [ ] Game tested with `TextChatService.PlatformIntegratedChat` and `Workspace.PlayerScriptsUseInputActionSystem` set to `Enabled`.
- [ ] Non-chat player text filtered and limited to one submission per minute.

## See also

- [[Engine and API Changes 2025-2026]]
- [[Roblox Changes 2025-2026]]
- [[Teleporting and Multi-Place Games]]
- [[Reserved and Private Servers in Practice]]
- [[Parties and Group Teleports]]
- [[Badges and Achievement Design]]
- [[Age Checks and Safety Features]]
- [[Text Chat Customization with TextChatService]]
- [[Subscriptions and Premium Payouts]]
- [[Regional Compliance - Paid Random Items and Country Rules]]
- [[The Audio API - Players Emitters Wires and Effects]]
- [[Level of Detail and Model Streaming]]

<!-- related:start -->
## Related
[[TeleportService - Engine Reference Card]] · [[Joining Friends Parties and Private Servers]] · [[TextChatService - Engine Reference Card]] · [[What AI Models Get Wrong in Roblox]] · [[BadgeService - Engine Reference Card]] · [[Avatar Context Menus Profiles and Social Surfaces]]
<!-- related:end -->
