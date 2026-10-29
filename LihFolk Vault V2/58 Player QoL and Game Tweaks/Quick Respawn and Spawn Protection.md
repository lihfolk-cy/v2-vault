---
tags: [qol, respawn, spawn-protection, forcefield, spawnlocation, death, server-authority, combat, type/guide, area/gameplay, level/intermediate, api/Players, api/ForceField, api/SpawnLocation]
---
# Quick Respawn and Spawn Protection

<!-- tldr:start -->
> [!tldr] TL;DR
> - Players killed instantly at spawn: No protection -> ForceField or server flag
> - Protected players attacking freely: Protection does not end on attack -> End on first offensive action
> - ForceField ignored: Damage sets `Health` directly -> Check in the damage function
> - Respawn delay matches genre; server-controlled with `LoadCharacterAsync`.
> - Respawn-now after a minimum delay; dead check on the server.
> - Death recap and countdown; no frustration monetisation.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 2. Server-controlled respawn with a "respawn now" option · ## 4. Spawn protection that cannot be abused · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Death is where frustration peaks. A slow, uninformative respawn followed by being killed again at the spawn point is one of the fastest ways to lose a player. This note covers the QoL side: respawn timing and a skip, what to show while dead, where to respawn, and spawn protection that cannot be abused. Spawn layout and safe zones are in [[Spawn Points Safe Zones and Respawn Flow]]; rounds and teams in [[Spawning Teams and Rounds]].

Sources: **Roblox docs** for `Players.RespawnTime` and `CharacterAutoLoads` (https://create.roblox.com/docs/reference/engine/classes/Players), `Player:LoadCharacterAsync` (https://create.roblox.com/docs/reference/engine/classes/Player), `SpawnLocation.Duration` (https://create.roblox.com/docs/reference/engine/classes/SpawnLocation) and `ForceField` (https://create.roblox.com/docs/reference/engine/classes/ForceField). Timings are **Rule of thumb**.

## 1. Respawn timing by genre

| Genre | Respawn delay | Notes |
|---|---|---|
| Obby, simulator | 0-1 s | Death is not a punishment; get back fast |
| Casual combat, battlegrounds | 2-4 s | Short beat to read the death recap |
| Team shooters | 4-8 s, wave-based optional | Waves help teams regroup |
| Round-based / permadeath | Until round end | Spectate mode is the QoL |

Roblox's default respawn uses `Players.RespawnTime` (5 s by default per docs). For control, set `Players.CharacterAutoLoads = false` and spawn characters yourself.

## 2. Server-controlled respawn with a "respawn now" option

```lua
--!strict
-- ServerScriptService/RespawnService
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false
local RESPAWN_DELAY = 3
local MIN_DELAY = 1 -- even "respawn now" waits this long
local requestRemote = ReplicatedStorage.Remotes.RequestRespawn :: RemoteEvent

local diedAt: { [Player]: number } = {}
local spawning: { [Player]: boolean } = {}

local function spawnNow(player: Player)
	if spawning[player] or player.Parent == nil then return end
	spawning[player] = true
	local ok, err = pcall(player.LoadCharacterAsync, player)
	if not ok then warn("Respawn failed", player.UserId, err) end
	spawning[player] = nil
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local t = os.clock()
		diedAt[player] = t
		task.delay(RESPAWN_DELAY, function()
			if diedAt[player] == t then spawnNow(player) end
		end)
	end)
end

requestRemote.OnServerEvent:Connect(function(player: Player)
	local t = diedAt[player]
	if t == nil or os.clock() - t < MIN_DELAY then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then return end -- not dead
	diedAt[player] = nil
	spawnNow(player)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(c) onCharacter(player, c) end)
	spawnNow(player)
end)

Players.PlayerRemoving:Connect(function(player)
	diedAt[player] = nil
	spawning[player] = nil
end)
```

The `diedAt` token ensures a manual respawn and the timer cannot both spawn the player. The server checks the player is actually dead, so the remote cannot be used to teleport-reset mid-fight.

## 3. While dead: show something useful

- **Death recap**: who or what killed you, damage taken, the killer's remaining health. Players accept deaths they understand.
- **Countdown** with a "Respawn now" button once the minimum delay passes (touch and gamepad reachable).
- **Spawn choice** where the design allows: last checkpoint, base, team spawn.
- **Kill-cam or spectate** in round games, with a quick way to switch target.
- **No ad or shop popup on death.** Monetising frustration reads as predatory; a revive product can exist, but the free path must be visible and fair ([[Policy and Age Rules 2026]]).

## 4. Spawn protection that cannot be abused

Spawn protection prevents spawn camping. Two common forms:

- **ForceField**: Roblox's `SpawnLocation.Duration` gives spawning characters a `ForceField` for that many seconds (**Roblox docs**). Default weapons respect it via `Humanoid:TakeDamage`; **custom damage code that sets `Health` directly ignores it**, so check for a `ForceField` in your damage function.
- **Server state flag**: set an attribute `SpawnProtectedUntil = workspace:GetServerTimeNow() + 3` and have your damage pipeline skip protected targets.

Rules to stop abuse (**Rule of thumb**):
- **Protection ends early when the player attacks** or uses an ability. Otherwise protected players attack freely.
- **Protection ends when leaving the spawn area**, whichever is first.
- **Show it**: a visible shimmer and a small timer, so both sides know.
- **Server-side only**: the client never decides it is protected.

```lua
--!strict
-- In your server damage function.
local function canDamage(target: Model): boolean
	if target:FindFirstChildOfClass("ForceField") then return false end
	local untilT = target:GetAttribute("SpawnProtectedUntil") :: number?
	return untilT == nil or workspace:GetServerTimeNow() >= untilT
end

local function onAttack(attackerCharacter: Model)
	attackerCharacter:SetAttribute("SpawnProtectedUntil", nil)
	local ff = attackerCharacter:FindFirstChildOfClass("ForceField")
	if ff then ff:Destroy() end
end
```

Timestamps from `GetServerTimeNow` follow the same pattern as [[Server-Authoritative Freeze and Stun Timestamps]].

## 5. Respawn state hygiene

- **Clear status effects, toggles and cooldown UI** on death; reapply settings (FOV, UI scale) on the new character.
- **Restore equipped tool** if auto-equip is on ([[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]).
- **`ResetOnSpawn`** on `ScreenGui`s resets UI state; set it false for HUDs that should persist, true for per-life UI.
- **Camera**: reset subject cleanly; no lingering shake from the death.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Players killed instantly at spawn | No protection | ForceField or server flag |
| Protected players attacking freely | Protection does not end on attack | End on first offensive action |
| ForceField ignored | Damage sets `Health` directly | Check in the damage function |
| Double spawn | Timer and manual respawn both fire | Death token |
| Respawn remote used as a reset | No dead check | Server verifies health is 0 |
| HUD resets every life | `ResetOnSpawn` true on persistent UI | Set false |

## Checklist

- [ ] Respawn delay matches genre; server-controlled with `LoadCharacterAsync`.
- [ ] Respawn-now after a minimum delay; dead check on the server.
- [ ] Death recap and countdown; no frustration monetisation.
- [ ] Spawn protection server-side, visible, ends on attack or leaving spawn.
- [ ] State, toggles and settings cleaned and reapplied on respawn.

## See also

- [[Spawn Points Safe Zones and Respawn Flow]]
- [[Spawning Teams and Rounds]]
- [[Characters and Humanoids]]
- [[Genre Playbook - Battlegrounds and Arena Fighters]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[AFK Detection Idle Kicks and AFK Reward Rules]] · [[Server Authority and Validation]] · Hitboxes and Hit Detection
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Accessibility Cross-Links for QoL Settings]] · [[UI Scale HUD Hide and Compact Mode]] · [[Settings Menu Essentials and Persistence]] · [[Joining Friends Parties and Private Servers]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]
<!-- related:end -->
