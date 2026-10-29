---
tags: [qol, afk, idle, idled, kick, rewards, retention, policy, server-authority, type/guide, area/gameplay, area/design, level/intermediate, api/Player]
---
# AFK Detection Idle Kicks and AFK Reward Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Server full of idle avatars: Big AFK rewards, no caps -> Lower, capped AFK income
> - Reading players kicked: Movement-only detection -> Combine signals; menu interaction counts
> - Friends kicked from private server: Global idle kick -> Exempt private/reserved servers
> - Server-side activity model from observable actions.
> - Warning before any game-side idle kick; friendly kick message.
> - Private and reserved servers exempt by default.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 2. Your own activity model (server-side) · ## 4. AFK reward rules · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AFK players are part of every Roblox game: someone goes to dinner, someone leaves a phone running overnight for a playtime reward, someone sits in a lobby waiting for friends. Handling them well means detecting idleness honestly, being clear about what AFK time earns, warning before kicks, and not designing incentives that fill servers with empty avatars. This note covers the engine's idle behaviour, a server-side activity model, AFK reward design and the pitfalls. Session-length metrics are in [[Session Length]] and [[Core Loops and Session Design]].

Sources: **Roblox docs** for `Player.Idled` (https://create.roblox.com/docs/reference/engine/classes/Player#Idled). AFK reward guidance is **Rule of thumb**. Claims about how Roblox discovery treats idle time are **Unverified** (see section 5).

## 1. What the engine does

Per the `Player.Idled` docs (**Roblox docs**, as of October 2026):
- `Idled` fires about two minutes after the engine considers the player idle, then repeatedly while they stay idle, passing the idle time in seconds.
- It fires in **client** scripts, so forward it to the server with a remote if the server needs it.
- Roblox disconnects players who stay idle for about **20 minutes**.

What "idle" means is the engine's definition (no user input). A player holding a key down or using an auto-clicker is not idle to the engine. Verify behaviour in a live server; Studio does not reproduce idle kicks reliably.

## 2. Your own activity model (server-side)

For game logic (AFK zones, reward eligibility, matchmaking), keep your own signal on the server, based on things the server can observe: movement, actions accepted by remotes, purchases, chat. Do not trust a client "I'm active" ping alone.

```lua
--!strict
-- ServerScriptService/Activity
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lastActive: { [Player]: number } = {}
local lastPos: { [Player]: Vector3 } = {}
local M = {}

function M.touch(player: Player) -- call from accepted gameplay remotes
	lastActive[player] = os.clock()
end

function M.idleSeconds(player: Player): number
	return os.clock() - (lastActive[player] or os.clock())
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 2 then return end
	acc = 0
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local prev = lastPos[player]
			if prev and (root.Position - prev).Magnitude > 4 then M.touch(player) end
			lastPos[player] = root.Position
		end
	end
end)

Players.PlayerAdded:Connect(function(p) M.touch(p) end)
Players.PlayerRemoving:Connect(function(p) lastActive[p] = nil; lastPos[p] = nil end)

return M
```

Movement-only checks are fooled by conveyor belts and auto-walk; combine signals and use thresholds generous enough not to punish a player reading a menu.

## 3. Warnings and your own idle kick

If your game is crowded and idle players block slots, you may kick idle players earlier than Roblox does, but warn first:

1. At, say, 12 minutes idle: a sticky critical toast "You'll be moved out for inactivity in 3 minutes. Move to stay." with a sound.
2. At 15 minutes: `player:Kick("Disconnected for inactivity. Rejoin any time!")`.

Kick messages should be friendly and say how to come back. **Never kick players in private servers or reserved party servers for idleness** unless the owner opts in; friends waiting for each other is the point of those servers ([[Reserved and Private Servers in Practice]]).

Gotcha: don't count time in your own full-screen menus (shop, settings, inventory) as idle when the player is interacting. Call `Activity.touch` from menu remotes, or have the client report menu interaction at a low, rate-limited cadence that the server only uses to extend, never to grant rewards.

## 4. AFK reward rules

AFK rewards (AFK zones, [[offline earnings]], "stay 15 minutes for a gift") are common in simulators. Rules that keep them healthy (**Rule of thumb**):

| Rule | Why |
|---|---|
| AFK income lower than active income | Active play must be the better choice |
| Cap AFK rewards per session or per day | Prevents overnight farming dominating the economy |
| Offline earnings computed on the server from saved timestamps, capped | Clock-change and data exploits otherwise |
| Playtime gifts require **some** activity in each interval | Otherwise they reward idling bots |
| Clearly label what AFK gives | Players feel tricked by hidden caps |
| No AFK rewards for paid boosts that expire while offline unless stated | Refund requests and complaints |

Offline earnings: store `lastSeen = os.time()` on save; on join compute `math.min(os.time() - lastSeen, CAP) * rate`. Use server time only, clamp negatives to zero, and show a "While you were away" panel with the amount. Economy impact belongs in [[Economy Inflation Sinks and Faucets Math]].

## 5. Anti-idle tricks and platform rules

- **Do not fake input** to prevent Roblox's idle disconnect for your players (for example simulating user activity from scripts). Even if it works technically, it keeps empty avatars in servers and inflates engagement artificially. Treat it as off-limits (**Rule of thumb**).
- Claims that Roblox discovery or engagement-based payouts discount idle time circulate on the DevForum; I could not confirm the exact current policy, so treat any specific claim as **Unverified** and check the latest Roblox announcements and [[Discovery and the Algorithm]] before designing around it.
- Exploiters run anti-AFK scripts client-side; your server-side activity model, not the engine's `Idled`, should decide reward eligibility.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Server full of idle avatars | Big AFK rewards, no caps | Lower, capped AFK income |
| Reading players kicked | Movement-only detection | Combine signals; menu interaction counts |
| Friends kicked from private server | Global idle kick | Exempt private/reserved servers |
| Offline earnings exploited | Client time or uncapped | Server `os.time`, cap, clamp |
| No warning before kick | Silent kick | Warning toast at T-3 minutes |
| `Idled` never fires on the server | It is client-side | Forward via remote or use server model |

## Checklist

- [ ] Server-side activity model from observable actions.
- [ ] Warning before any game-side idle kick; friendly kick message.
- [ ] Private and reserved servers exempt by default.
- [ ] AFK income lower than active, capped, labelled.
- [ ] Offline earnings from server timestamps, capped.
- [ ] No fake-input anti-idle.

## See also

- [[Retention and Return Hooks]]
- [[Core Loops and Session Design]]
- [[Economy Inflation Sinks and Faucets Math]]
- [[Logging Bans and Appeals]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Quick Respawn and Spawn Protection]] · [[Notification Queues and Limits]] · [[Session Length]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Joining Friends Parties and Private Servers]] · [[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Server Hop Rejoin and Server Lists with Ping]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Purchase Receipts and Purchase History in UI]] · [[Accessibility Cross-Links for QoL Settings]] · [[Block and Mute Respecting Platform Rules]]
<!-- related:end -->
