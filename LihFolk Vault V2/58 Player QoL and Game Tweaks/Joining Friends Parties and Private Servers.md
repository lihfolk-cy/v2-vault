---
tags: [qol, social, friends, parties, teleport, private-servers, reserved-servers, invites, type/guide, area/multiplayer, level/intermediate, api/TeleportService, api/SocialService, api/Player]
---
# Joining Friends Parties and Private Servers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Join does nothing: Teleport failure ignored -> Handle failures, show reason
> - Friends split across servers: Teleported one by one -> One `TeleportAsync` with the whole group
> - Join button on private matches: No reserved-server check -> Show status, no button
> - In-game friends panel filtered to this experience, cached.
> - Server-side Join with friend check, cooldown and failure messages.
> - Invite button via `PromptGameInvite` where it makes sense.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 1. A friends panel with Join · ## 4. Private-server QoL · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Playing with friends is the main reason many players are on Roblox. Every extra step between "my friend is in this game" and "I am next to my friend" loses players. This note is the QoL view: an in-game friends panel with a Join button, party teleports that keep groups together, private-server conveniences and invite prompts. The engineering is already covered: [[Parties and Group Teleports]], [[Reserved and Private Servers in Practice]], [[Teleporting and Multi-Place Games]] and [[Friend Invites Referrals and Experience Invites]].

Sources: **Roblox docs** for `Player:GetFriendsOnlineAsync` (https://create.roblox.com/docs/reference/engine/classes/Player), `TeleportService:GetPlayerPlaceInstanceAsync` and `TeleportAsync` with `TeleportOptions` (https://create.roblox.com/docs/reference/engine/classes/TeleportService, https://create.roblox.com/docs/reference/engine/classes/TeleportOptions), `SocialService:PromptGameInvite` (https://create.roblox.com/docs/reference/engine/classes/SocialService). UX guidance is **Rule of thumb**.

## 1. A friends panel with Join

Show online friends who are in **this experience**, with a Join button. Players can already join friends from the Roblox app, but an in-game list saves leaving the game.

Client: `Player:GetFriendsOnlineAsync(maxFriends)` (the non-Async `GetFriendsOnline` is deprecated) returns online friends with location info, including the place and game they are in (**Roblox docs**; it yields and can error, so wrap in `pcall` and cache for 30-60 s). Filter to entries whose `GameId` matches `game.GameId`.

Server: when the player presses Join, the server resolves the friend's server and teleports.

```lua
--!strict
-- ServerScriptService/JoinFriend
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local remote = ReplicatedStorage.Remotes.JoinFriend :: RemoteEvent
local cooldown: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player: Player, friendId: any)
	if typeof(friendId) ~= "number" then return end
	local now = os.clock()
	if now - (cooldown[player] or 0) < 10 then return end
	cooldown[player] = now

	local okFriend, isFriend = pcall(player.IsFriendsWithAsync, player, friendId)
	if not okFriend or not isFriend then return end

	local ok, _sameServer, err, placeId, jobId = pcall(TeleportService.GetPlayerPlaceInstanceAsync, TeleportService, friendId)
	if not ok or err or not placeId or not jobId then
		-- notify client: "Couldn't find your friend's server"
		return
	end
	if jobId == game.JobId then return end -- already together

	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = jobId
	local tpOk, tpErr = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)
	if not tpOk then warn("JoinFriend teleport failed", tpErr) end
end)
```

Check the return order of `GetPlayerPlaceInstanceAsync` against the current docs before shipping; the multi-value return is easy to misread (**Roblox docs** list it as current-instance flag, error, place id, job id). It also only resolves friends inside the same experience.

Gotchas:
- **Full servers**: the teleport fails if the friend's server is full. Tell the player and offer "Notify me when there's room" or "Join a new server together" (party teleport).
- **Reserved servers** (party lobbies, private instances) cannot be joined by `ServerInstanceId`. Show "In a private match" instead of a Join button.
- **Handle `TeleportInitFailed`** and show a retry, not a silent nothing ([[Teleporting and Multi-Place Games]]).
- **Respect privacy**: friends who have joins restricted on Roblox should not be joinable via your panel; if the lookup fails, show nothing rather than guessing.

## 2. Invites

`SocialService:PromptGameInvite(player)` opens Roblox's invite sheet; `CanSendGameInviteAsync` tells you whether to show the button (**Roblox docs**). Put an "Invite friends" button where it is useful (lobby, party screen, after a win), not as a popup. Incentives for invites have policy limits; see [[Friend Invites Referrals and Experience Invites]] and [[Policy and Age Rules 2026]].

## 3. Parties that stay together

When a game teleports to a match place or a new area, friends must not be split:
- Teleport **the whole party in one `TeleportAsync` call** with `ShouldReserveServer` or to the same reserved server, so they land together.
- **Leader starts, members confirm** with a short ready check, and a visible "waiting for X" list.
- **Return together**: when the match ends, teleport the group back to one lobby server.
- Roblox also exposes platform party data (`SocialService:GetPartyAsync`, `Player.PartyId`); check the current docs and availability before relying on them (**Unverified** for rollout and permissions in your context).

Full patterns: [[Parties and Group Teleports]], [[Session State Across Places]].

## 4. Private-server QoL

Private (VIP) servers are bought by players; reserved servers are created by your code (**Roblox docs**). QoL for private-server owners:
- **Owner panel**: change game mode, kick players from the server, toggle events, reset map, pause night cycle (whatever fits your game).
- **No idle kicks** and no forced server-wide events unless the owner enables them ([[AFK Detection Idle Kicks and AFK Reward Rules]]).
- **Clear labelling**: a small badge "Private server" so players know rules may differ.
- **Rewards parity**: decide and state whether private servers earn the same rewards; farming concerns in private servers are an economy question ([[Reserved and Private Servers in Practice]]).

Detect a private server with `game.PrivateServerId ~= ""` and the owner with `game.PrivateServerOwnerId` (**Roblox docs**).

## 5. Lobby layout

A social lobby with clear "play together" spots (portals that gather a group, a party pad) does more for group play than menus. See [[Lobby and Hub Design]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Join does nothing | Teleport failure ignored | Handle failures, show reason |
| Friends split across servers | Teleported one by one | One `TeleportAsync` with the whole group |
| Join button on private matches | No reserved-server check | Show status, no button |
| Friends list slow | `GetFriendsOnlineAsync` every open | Cache 30-60 s |
| Join button abused to spam teleports | No cooldown, no friend check | Cooldown and `IsFriendsWithAsync` |
| Private owners annoyed by events | Public rules applied | Owner panel and opt-in events |

## Checklist

- [ ] In-game friends panel filtered to this experience, cached.
- [ ] Server-side Join with friend check, cooldown and failure messages.
- [ ] Invite button via `PromptGameInvite` where it makes sense.
- [ ] Party teleports move the group together and back.
- [ ] Private-server owner panel, no idle kicks, clear rewards policy.

## See also

- [[Parties and Group Teleports]]
- [[Reserved and Private Servers in Practice]]
- [[Friend Invites Referrals and Experience Invites]]
- [[Avatar Context Menus Profiles and Social Surfaces]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Server Hop Rejoin and Server Lists with Ping]] · [[Block and Mute Respecting Platform Rules]] · [[Teleporting and Multi-Place Games]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Loading Screen Skip and First-Session Goals]] · [[Top 25 QoL Wins by Effort]] · [[Quick Respawn and Spawn Protection]] · [[Purchase Receipts and Purchase History in UI]] · [[Notification Queues and Limits]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]
<!-- related:end -->
