---
tags: [qol, game-tweaks, tuning, cooldowns, input-buffering, coyote-time, latency, game-feel, server-authority, type/guide, area/game-feel, area/gameplay, level/intermediate, api/Workspace]
---
# Making Numbers Feel Good - Cooldowns Buffering and Coyote Time

<!-- tldr:start -->
> [!tldr] TL;DR
> - "My dash didn't work": Early press dropped -> Buffer plus small server grace
> - Cooldown sweep lags behind: Waits for server reply -> Predict, then correct to server time
> - Ability used twice on lag: Client-owned cooldown -> Server timestamp gate
> - Cooldowns visible on buttons with ready cue and unavailable feedback.
> - Server timestamp cooldowns with `GetServerTimeNow`, predicted on the client.
> - Input buffer: one slot, short window, cleared on death/menu/stun.
>
> Cost: TL;DR ~160 tok · whole note ~2.2k tok. Read more: ## 2. Server-authoritative cooldowns that display instantly · ## 4. Coyote time · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Two games with identical damage, speed and cooldown values can feel completely different. One eats inputs and leaves players guessing when abilities are ready; the other forgives a slightly early press, shows exactly when things come back, and lets you jump a frame after leaving a ledge. This note is about the **tweaks** layer: cooldown visibility, server-authoritative cooldowns that still feel instant, input buffering, coyote time, and latency tolerance. The theory and reference windows are in [[Input Responsiveness Buffering and Coyote Time]], [[Input Buffering]], [[Coyote Time]] and [[Cooldowns]]; this note focuses on wiring them across client and server in Roblox.

Sources: **Roblox docs** for `Workspace:GetServerTimeNow` (https://create.roblox.com/docs/reference/engine/classes/Workspace) and `Humanoid.FloorMaterial` / state events (https://create.roblox.com/docs/reference/engine/classes/Humanoid). Window sizes are **Rule of thumb** (common platformer and action-game practice).

## 1. Cooldowns players can see

Rules (**Rule of thumb**):
- **Every ability with a cooldown shows it on its button**: a radial sweep plus seconds remaining under about 10 s (one decimal under 3 s).
- **A "ready" cue**: small flash or sound when it comes back, especially for long cooldowns. Respect the comfort settings for the flash ([[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]).
- **Pressing during cooldown gives feedback**: a short shake of the icon and an "unavailable" click, never silence.
- **Global cooldowns** shown separately from ability cooldowns, or players think abilities are broken.

## 2. Server-authoritative cooldowns that display instantly

The server owns cooldowns; the client must not wait a round trip to show the sweep. Use shared timestamps:

```lua
--!strict
-- Server: authoritative ability gate using shared server time.
local COOLDOWNS: { [string]: number } = { Dash = 4, Fireball = 8 }
local readyAt: { [Player]: { [string]: number } } = {}
local LATENCY_GRACE = 0.1 -- accept presses slightly early to absorb jitter

local function tryUse(player: Player, ability: string): (boolean, number?)
	local cd = COOLDOWNS[ability]
	if cd == nil then return false, nil end
	local now = workspace:GetServerTimeNow()
	local t = readyAt[player] or {}
	readyAt[player] = t
	if now + LATENCY_GRACE < (t[ability] or 0) then
		return false, t[ability]
	end
	t[ability] = now + cd
	player:SetAttribute("CD_" .. ability, t[ability]) -- replicates the ready time to the client
	return true, t[ability]
end
```

Client: predict the sweep immediately on press using `workspace:GetServerTimeNow() + cd`, then correct to the replicated `CD_` attribute when it arrives. Because `GetServerTimeNow` is synchronised between client and server (**Roblox docs**), the replicated timestamp means the same moment on both. If the server rejects, roll the sweep back and play the "unavailable" cue. The pattern matches [[Server-Authoritative Freeze and Stun Timestamps]].

Grace window: a small tolerance (around 0.1 s, **Rule of thumb**) stops correct-feeling presses from being rejected due to jitter. Keep it small and server-side; it is not a rate-limit bypass, since the next cooldown still starts from the server's time.

## 3. Input buffering

A press that arrives slightly before an action is possible (during the end of an attack, mid-air before landing) should be stored and executed when it becomes possible.

```lua
--!strict
-- Client: one-slot input buffer.
local BUFFER_WINDOW = 0.15

local buffered: { action: string, at: number }? = nil

local function press(action: string, canAct: () -> boolean, perform: (string) -> ())
	if canAct() then
		perform(action)
	else
		buffered = { action = action, at = os.clock() }
	end
end

-- Call when the character becomes able to act (attack recovered, landed, stun ended).
local function onCanAct(perform: (string) -> ())
	local b = buffered
	buffered = nil
	if b and os.clock() - b.at <= BUFFER_WINDOW then
		perform(b.action)
	end
end
```

Points:
- **One slot, newest wins**, with a short window (0.1-0.2 s, **Rule of thumb**). Longer windows make the game feel like it acts on its own.
- **Do not buffer dangerous or expensive actions** (using a consumable, buying) unless the player expects it.
- **Buffered actions still go through the server gate.** Buffering changes when the client sends the request, not whether the server accepts it.
- **Clear on death, menu open and stun.**

## 4. Coyote time

Let the player jump for a short time after walking off a ledge. With the default Humanoid, detect leaving the ground and allow a late jump:

```lua
--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local COYOTE = 0.12
local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local leftGroundAt = -math.huge
local jumpedSinceGround = false

humanoid.StateChanged:Connect(function(_old, new)
	if new == Enum.HumanoidStateType.Freefall and not jumpedSinceGround then
		leftGroundAt = os.clock()
	elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
		jumpedSinceGround = false
	elseif new == Enum.HumanoidStateType.Jumping then
		jumpedSinceGround = true
	end
end)

UserInputService.JumpRequest:Connect(function()
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall and not jumpedSinceGround
		and os.clock() - leftGroundAt <= COYOTE then
		jumpedSinceGround = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)
```

Rebind on `CharacterAdded`. Coyote time is client-side feel for the local character, whose physics the client owns; movement anti-cheat on the server should tolerate this small window ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]). Combine with a jump buffer (press just before landing jumps on landing). Custom controllers implement both directly ([[Custom Character Controllers]]).

## 5. Other numbers that feel better than they are

- **Round displayed numbers kindly**: show damage as integers, show "99%" only when it really is; progress bars that sit at 99% for long periods frustrate.
- **Front-load feedback**: start the animation and sound on press, even if the server confirms later ([[Client Hit Prediction for Melee Feedback]]).
- **Crit and rarity variance**: pseudo-random distribution (rising chance after misses) feels fairer than pure random at low percentages; disclose odds where policy requires ([[Paid Random Items and Odds Disclosure in Practice]]).
- **Cooldown reductions** displayed as the resulting cooldown ("8 s → 6.4 s"), not just "-20%".

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| "My dash didn't work" | Early press dropped | Buffer plus small server grace |
| Cooldown sweep lags behind | Waits for server reply | Predict, then correct to server time |
| Ability used twice on lag | Client-owned cooldown | Server timestamp gate |
| Jump fails at ledge edges | No coyote time | 0.1-0.15 s window |
| Game acts on its own | Buffer too long | 0.1-0.2 s, one slot |
| Anti-cheat flags late jumps | No tolerance for coyote | Small allowance in movement checks |

## Checklist

- [ ] Cooldowns visible on buttons with ready cue and unavailable feedback.
- [ ] Server timestamp cooldowns with `GetServerTimeNow`, predicted on the client.
- [ ] Input buffer: one slot, short window, cleared on death/menu/stun.
- [ ] Coyote time and jump buffer on the local character.
- [ ] Displayed numbers rounded and explained.

## See also

- [[Input Responsiveness Buffering and Coyote Time]]
- [[Hit-Stop and Screen Shake Tuning by Numbers]]
- [[Locomotion and Melee Reference Numbers]]
- [[Aim Assist and Generous Hitboxes]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Cooldowns]] · Input Buffering · Coyote Time
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Input Buffering]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Top 25 QoL Wins by Effort]] · [[QoL Audit Checklist]] · [[Accessibility Cross-Links for QoL Settings]] · [[Quick Respawn and Spawn Protection]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]]
<!-- related:end -->
