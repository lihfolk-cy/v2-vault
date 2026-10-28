<!-- tldr:start -->
> [!tldr] TL;DR
> - Watchdog unfreezes stunned players: Intended holds not excluded -> One shared intended-hold list
> - Heavy slow effects get "fixed": WalkSpeed compared with a constant -> Compare with the expected speed
> - Exploiters spam the remote: No server rate limit -> Per-player cooldown on the server
> - Client detects sustained input with no movement and reports with a cooldown.
> - Server re-checks state itself and rate-limits reports.
> - Anchored root, WalkSpeed, PlatformStand, controls and stale locks handled.
>
> Read more (8 KB note): ## 1. Detect on the client, decide on the server · ## 2. Free the common causes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

---
tags: [field-notes, characters, movement, watchdog, telemetry, datastore, debugging, luau]
---
# A Stuck Player Watchdog That Logs the Cause

In a large game many systems can stop a character moving: stuns, cutscenes, menus, mounts, attacks that root you, anti-cheat, loading code. Each one sets something and is supposed to clear it. Sooner or later one does not, and a player is stuck: pressing keys, going nowhere, and leaving. A watchdog that notices "trying to move but not moving", frees the common causes, and **records which cause it found** turns an unfixable "sometimes people get stuck" report into a ranked list of bugs. Related: [[Debugging Live Servers]], [[Telemetry Events]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Detect on the client, decide on the server

Only the client knows the player is *trying* to move: `Humanoid.MoveDirection` is set from the local controls. Only the server should change authoritative state. So the client detects and reports; the server diagnoses, repairs and logs.

```lua
-- Client: report sustained "trying to move but not moving".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local StuckReport = ReplicatedStorage:WaitForChild("StuckReport") :: RemoteEvent

local STUCK_AFTER = 3     -- seconds of input with no movement
local COOLDOWN = 20       -- seconds between reports
local stuckFor, lastReport = 0, -math.huge

local function intendedHold(character: Model): boolean
	return character:GetAttribute("KnockedOut") == true
		or (character:GetAttribute("FrozenUntil") or 0) > workspace:GetServerTimeNow()
		or character:GetAttribute("InCutscene") == true
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 or intendedHold(character) then
		stuckFor = 0
		return
	end
	local trying = humanoid.MoveDirection.Magnitude > 0.5
	local moving = root.AssemblyLinearVelocity.Magnitude > 1
	if trying and not moving then
		stuckFor += dt
		if stuckFor >= STUCK_AFTER and os.clock() - lastReport > COOLDOWN then
			lastReport = os.clock()
			stuckFor = 0
			StuckReport:FireServer({
				anchored = root.Anchored,
				walkSpeed = humanoid.WalkSpeed,
				platformStand = humanoid.PlatformStand,
			})
		end
	else
		stuckFor = 0
	end
end)
```

The client's snapshot is a hint for the log, never a reason to act: the server checks its own view.

## 2. Free the common causes

The causes the reference project's watchdog checks and frees (**Measured**; each one was seen in play):

1. **Anchored `HumanoidRootPart`.** Left by a cutscene, a grab or a join "fix" ([[Streaming Joins - Frozen Players and Loading Screen Teardown]]).
2. **Crushed `WalkSpeed`.** A slow effect that multiplied speed and never restored it, or two effects restoring in the wrong order, leaving 0 or near 0.
3. **`PlatformStand` left true.** From a knockback or ragdoll that ended early.
4. **Disabled controls.** A client script called the player module's controls `Disable` and errored before `Enable`.
5. **A stale lock attribute.** A `MoveLocked`-style attribute set by an ability that was interrupted.

```lua
-- Server
local StuckReport = ReplicatedStorage.StuckReport
local DEFAULT_WALKSPEED = 16
local LOCK_MAX_AGE = 15 -- no legitimate move lock lasts longer than this
local lastHandled: { [Player]: number } = {}

StuckReport.OnServerEvent:Connect(function(player: Player, hint)
	local now = os.clock()
	if now - (lastHandled[player] or 0) < 15 then
		return -- rate limit; the client is not trusted to be polite
	end
	lastHandled[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 or IntendedHolds.isHeld(character) then
		return
	end

	local causes = {}
	if root.Anchored then
		root.Anchored = false
		table.insert(causes, "AnchoredRoot")
	end
	local expected = SpeedSystem.expectedWalkSpeed(character) or DEFAULT_WALKSPEED
	if humanoid.WalkSpeed < 1 and expected >= 1 then
		humanoid.WalkSpeed = expected
		table.insert(causes, "WalkSpeed")
	end
	if humanoid.PlatformStand then
		humanoid.PlatformStand = false
		table.insert(causes, "PlatformStand")
	end
	local lockedAt = character:GetAttribute("MoveLockedAt")
	if character:GetAttribute("MoveLocked") and (not lockedAt or workspace:GetServerTimeNow() - lockedAt > LOCK_MAX_AGE) then
		character:SetAttribute("MoveLocked", nil)
		table.insert(causes, "StaleMoveLock")
	end
	if #causes == 0 then
		table.insert(causes, "Unknown")
		StuckReport:FireClient(player, "EnableControls") -- client re-enables its controls if no hold applies
	end
	StuckLog.record(causes, hint)
end)

Players.PlayerRemoving:Connect(function(p) lastHandled[p] = nil end)
```

Compare `WalkSpeed` with what your status system *expects* rather than with a constant, so a legitimate heavy slow is not "fixed".

## 3. Exclude intended holds

The watchdog must know every legitimate reason to be still: dead, knocked out, frozen or stunned ([[Server-Authoritative Freeze and Stun Timestamps]]), in a cutscene, in a vehicle seat, channelling an ability, sitting. Keep that list in one module used by both sides. A watchdog that frees a frozen player is an exploit; one that ignores real bugs is useless.

Pushing into a wall also looks like "trying but not moving". The server finds no cause and logs `Unknown`, which is fine as long as `Unknown` is treated as noise until it dominates.

## 4. Log the cause, then fix the root

The fix-up is a bandage. The value is the log. Aggregate counts per cause in memory and flush every minute or so with `UpdateAsync` on a daily key, staying well inside DataStore request budgets ([[DataStore Fundamentals]]):

```lua
-- StuckLog: batch counts, one write per minute per server
local store = DataStoreService:GetDataStore("StuckLog")
local pending: { [string]: number } = {}

function StuckLog.record(causes: { string }, _hint)
	for _, c in causes do
		pending[c] = (pending[c] or 0) + 1
	end
end

task.spawn(function()
	while true do
		task.wait(60)
		if next(pending) then
			local batch = pending
			pending = {}
			local key = os.date("!%Y-%m-%d")
			pcall(store.UpdateAsync, store, key, function(old)
				old = old or {}
				for cause, n in batch do
					old[cause] = (old[cause] or 0) + n
				end
				return old
			end)
		end
	end
end)
```

**Rule of thumb:** once counts exist, one or two causes usually dominate, and each traces back to a specific system that sets a hold and fails to clear it on some path (interruption, death, respawn). Fix that path; the watchdog's job is to make the bug visible, not to live with it.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Watchdog unfreezes stunned players | Intended holds not excluded | One shared intended-hold list |
| Heavy slow effects get "fixed" | WalkSpeed compared with a constant | Compare with the expected speed |
| Exploiters spam the remote | No server rate limit | Per-player cooldown on the server |
| Stuck players freed but bugs never fixed | No cause logging | Batch counts per cause to a DataStore |
| DataStore throttling warnings | One write per report | Aggregate and flush once a minute |

## Checklist

- [ ] Client detects sustained input with no movement and reports with a cooldown.
- [ ] Server re-checks state itself and rate-limits reports.
- [ ] Anchored root, WalkSpeed, PlatformStand, controls and stale locks handled.
- [ ] Intended holds excluded via one shared module.
- [ ] Cause counts batched and logged daily.
- [ ] Top cause reviewed and fixed at the source each release.

## Connected notes
<!-- auto-links:start -->
[[Debugging Live Servers]] · [[Telemetry Events]] · [[Status Effects Buffs and Stacking Rules]] · [[Server-Authoritative Freeze and Stun Timestamps]] · [[Streaming Joins - Frozen Players and Loading Screen Teardown]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
