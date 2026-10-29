---
tags: [qol, social, block, mute, safety, textchatservice, voice-chat, moderation, policy, type/guide, area/community, level/intermediate, api/TextChatService, api/StarterGui, api/TextChannel]
---
# Block and Mute Respecting Platform Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Blocked player keeps sending trades: Custom system ignores blocks -> Server `canInteract` check
> - Block list empty at start: `GetCore` not ready -> Retry with backoff
> - Custom block button does nothing outside game: Game-only list -> Use `PromptBlockPlayer`
> - Roblox prompts used for block/unblock; report reachable in-game.
> - Every custom interaction honours blocks in both directions on the server.
> - Block list cached on the client with retries and live updates.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 2. What your systems must do · ## 3. The in-game ignore layer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Blocking and muting are safety features first and QoL second. Roblox owns the block list; your game must respect it everywhere players can interact, and should add lighter, game-level controls (mute in-game emotes, hide trade requests, ignore duels) on top. This note covers what the platform does automatically, what your custom systems must do, and the in-game "ignore" layer players actually use daily. Chat customisation is in [[Text Chat Customization with TextChatService]]; reports in [[Player Reports and In-Game Moderation]]; voice in [[Voice Chat and Safety Features]].

Sources: **Roblox docs** for `StarterGui:SetCore` / `GetCore` (https://create.roblox.com/docs/reference/engine/classes/StarterGui), `TextChatService` (https://create.roblox.com/docs/reference/engine/classes/TextChatService) and `TextChannel.ShouldDeliverCallback` (https://create.roblox.com/docs/reference/engine/classes/TextChannel); Roblox Community Standards (https://en.help.roblox.com/hc/en-us/articles/203313410). Design is **Rule of thumb**.

## 1. What the platform already does

- **Roblox chat respects blocks.** With `TextChatService`, messages from users you blocked are not shown to you. Do not rebuild this.
- **Voice chat** has platform mute and block controls.
- **The player list and avatar context menu** let players block and report through Roblox UI ([[Avatar Context Menus Profiles and Social Surfaces]]).
- Your game can open Roblox's own prompts: `StarterGui:SetCore("PromptBlockPlayer", player)` and `"PromptUnblockPlayer"` (**Roblox docs**, client only). Prefer these over a custom block button, because the result applies to the real block list.

## 2. What your systems must do

Anything you built that lets one player reach another must honour blocks: custom chat bubbles, trade requests, duel invites, party invites, friend-style gifts, player-written signs, pet names shown overhead, emote spam directed at someone.

On the client, read the local player's block list:

```lua
--!strict
-- Client: cache the local player's blocked user ids and keep it fresh.
local StarterGui = game:GetService("StarterGui")

local blocked: { [number]: boolean } = {}

local function refresh()
	local ok, ids = pcall(StarterGui.GetCore, StarterGui, "GetBlockedUserIds")
	if ok and typeof(ids) == "table" then
		table.clear(blocked)
		for _, id in ids do blocked[id] = true end
	end
end

task.spawn(function()
	-- GetCore can fail early in the session before core scripts register.
	for _ = 1, 10 do
		refresh()
		if next(blocked) ~= nil then break end
		task.wait(3)
	end
end)

local ok, blockedEvent = pcall(StarterGui.GetCore, StarterGui, "PlayerBlockedEvent")
if ok and typeof(blockedEvent) == "Instance" and blockedEvent:IsA("BindableEvent") then
	blockedEvent.Event:Connect(function(player: Player) blocked[player.UserId] = true end)
end

return function(userId: number): boolean
	return blocked[userId] == true
end
```

`GetCore` callbacks are registered by Roblox's core scripts and may not be ready in the first frames; retry rather than assuming an empty list (**Roblox docs** note `GetCore` errors if the key is not yet registered). Check the current list of `GetCore` keys in the docs before relying on the event names.

Server enforcement: the server cannot read another player's block list directly from these client APIs. A practical pattern is for each client to report its block list to the server (ids only, capped size); the server then refuses to deliver trade or duel requests between a blocked pair. A client lying about its own block list can only hurt its own experience, so trusting it is acceptable here.

```lua
--!strict
-- Server: per-player reported block sets, used by request systems.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.ReportBlockList :: RemoteEvent
local blocks: { [Player]: { [number]: boolean } } = {}

remote.OnServerEvent:Connect(function(player: Player, ids: any)
	if typeof(ids) ~= "table" then return end
	local set = {}
	local n = 0
	for _, id in ids do
		if typeof(id) == "number" then
			n += 1
			if n > 500 then break end
			set[id] = true
		end
	end
	blocks[player] = set
end)

local function canInteract(a: Player, b: Player): boolean
	local ab, ba = blocks[a], blocks[b]
	return not ((ab and ab[b.UserId]) or (ba and ba[a.UserId]))
end

game:GetService("Players").PlayerRemoving:Connect(function(p) blocks[p] = nil end)
```

Blocks are mutual for interaction purposes: if either side blocked the other, no requests in either direction.

For custom text channels, `TextChannel.ShouldDeliverCallback` lets the server decide per recipient whether a message is delivered (**Roblox docs**); use the same `canInteract` there. Player-written text shown to others must still go through text filtering ([[Text Chat Customization with TextChatService]]).

## 3. The in-game ignore layer

Full blocks are heavy. Players also want light controls, scoped to your game:

| Control | Effect | Saved? |
|---|---|---|
| Ignore trade requests (all / non-friends) | Server rejects incoming trades | Setting |
| Ignore duel / party invites | Server rejects | Setting |
| Hide other players' pets / effects | Client hides | Setting (also helps performance) |
| Mute a player's emotes and sounds | Client mutes that player | Session |
| Hide player-made content (signs, names) | Client hides | Setting |

Requests from friends can bypass "non-friends only" filters. All request-type ignores are enforced on the server, so a modified client cannot spam requests.

## 4. Do not

- **Do not show "X blocked you".** It escalates harassment.
- **Do not let blocked players follow** via your Join-friend panel or teleport-to-player features.
- **Do not require leaving the game to block.** Put "Block" (via Roblox's prompt) and "Report" in your player card.
- **Do not log or expose block lists** beyond what enforcement needs.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Blocked player keeps sending trades | Custom system ignores blocks | Server `canInteract` check |
| Block list empty at start | `GetCore` not ready | Retry with backoff |
| Custom block button does nothing outside game | Game-only list | Use `PromptBlockPlayer` |
| Spam invites from exploiters | Ignore enforced client-side | Server-side rejection |
| Harassment escalates | "You were blocked" message | Silent refusal |

## Checklist

- [ ] Roblox prompts used for block/unblock; report reachable in-game.
- [ ] Every custom interaction honours blocks in both directions on the server.
- [ ] Block list cached on the client with retries and live updates.
- [ ] Ignore settings for trades, invites and cosmetic noise.
- [ ] No disclosure of who blocked whom.

## See also

- [[Text Chat Customization with TextChatService]]
- [[Player Reports and In-Game Moderation]]
- [[Voice Chat and Safety Features]]
- [[Age Checks and Safety Features]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Joining Friends Parties and Private Servers]] · [[Avatar Context Menus Profiles and Social Surfaces]] · Policy and Age Rules 2026
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Notification Queues and Limits]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Top 25 QoL Wins by Effort]] · [[AFK Detection Idle Kicks and AFK Reward Rules]] · [[Server Hop Rejoin and Server Lists with Ping]] · [[Audio Mixer Settings with SoundGroups]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]
<!-- related:end -->
