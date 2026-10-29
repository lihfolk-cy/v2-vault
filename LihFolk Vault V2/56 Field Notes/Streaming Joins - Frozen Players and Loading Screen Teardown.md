---
tags: [field-notes, streaming, loading-screen, joins, network-ownership, replicatedfirst, luau, type/case-study, area/networking, level/intermediate, area/scripting, api/Player]
---
# Streaming Joins - Frozen Players and Loading Screen Teardown

<!-- tldr:start -->
> [!tldr] TL;DR
> - Other players hang mid-air after spawning: Their client has not started simulating yet -> Expected; spawn on ground, optional cosmetic fade
> - Players stuck after a join "fix": Server anchored roots, unanchor missed -> Never anchor to hide join poses
> - Loading screen never leaves for some players: `WaitForChild` without timeout on streamed instance -> Timeouts plus a watchdog
> - No server-side anchoring of characters to hide join behaviour.
> - Spawns stand on solid ground and stream in first.
> - Loading screen teardown is one idempotent function.
>
> Cost: TL;DR ~180 tok · whole note ~1.8k tok. Read more: ## 1. Frozen players in a fall pose are not a bug · ## 2. A loading screen that always goes away · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Two join-time behaviours generate a steady stream of false bug reports and bad fixes in a streaming-enabled game. Other players appear frozen mid-air in a falling pose for a few seconds after they spawn; that is normal, and "fixing" it with anchoring creates real bugs. And custom loading screens occasionally never go away, leaving a player staring at a logo over a working game; that needs an idempotent teardown and a watchdog. Streaming itself is in [[Instance Streaming]]; join optimisation in [[Case Study - Fast Join and Deferred Loading]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Frozen players in a fall pose are not a bug

When a player joins, the server creates their character and places it at a spawn. The character's physics is owned by that player's client (network ownership of a player's character goes to that player, Roblox docs). Until the joining client has loaded enough to simulate and report positions, nobody is simulating that character. Everyone else sees it hanging where it spawned, often in a fall pose because the humanoid has no floor contact yet from its owner's point of view.

**Measured.** In the reference project this looked like "players spawn frozen in the air" and was reported repeatedly. It always resolved by itself once the joining client finished loading, from a second or two on fast devices to much longer on slow phones.

Do **not** fix it by anchoring the character's root on the server:

- An anchored root is not simulated by anyone, so you now need code to unanchor it at exactly the right moment. If that code misses (the client loaded before your signal, the remote was dropped, the character respawned in between), the player is truly stuck. See [[A Stuck Player Watchdog That Logs the Cause]], which exists partly because of fixes like this.
- Anchoring and unanchoring can disturb physics ownership and replication of the character for a moment, which is worse for the player than a pose others see briefly.

What to do instead, if it bothers you:

- **Spawn players on solid ground** with a little clearance, so the pose is standing, not falling.
- **Hide newly spawned characters from others** briefly (a local transparency fade on other clients for characters younger than a couple of seconds), purely cosmetic.
- **Make spawns persistent** so the joining client streams the spawn area first. `Model.ModelStreamingMode = Persistent` on the spawn model, and `Player:RequestStreamAroundAsync` at the spawn position, both exist for this (Roblox docs).

## 2. A loading screen that always goes away

A custom loading screen is created from `ReplicatedFirst`, which calls `ReplicatedFirst:RemoveDefaultLoadingScreen()` to replace Roblox's own (Roblox docs). From then on, removing the screen is your job, and every path that can fail is a player stuck behind a logo.

**Measured.** In the reference project, a small share of players kept the loading screen over a fully working game until teardown was made idempotent and given a watchdog. The usual causes (rule of thumb): a wait for an instance that is streamed out, a `WaitForChild` with no timeout in the "ready" check, and two teardown paths racing so that one restores the screen after the other hid it.

Two rules fix the class of bug:

1. **Idempotent teardown.** One function removes the screen; calling it twice is harmless; nothing ever re-shows the screen after it runs.
2. **A watchdog timeout.** Regardless of what the ready check is waiting for, tear down after a fixed time and log why.

```lua
-- LocalScript in ReplicatedFirst
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local screen = script:WaitForChild("LoadingScreen"):Clone()
screen.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local WATCHDOG_SECONDS = 25
local tornDown = false

local function teardown(reason: string)
	if tornDown then
		return
	end
	tornDown = true
	-- fade out, then destroy; never set Enabled back to true anywhere
	screen.Enabled = false
	screen:Destroy()
	if reason ~= "ready" then
		warn("Loading screen removed by", reason) -- also report to your analytics
	end
end

task.delay(WATCHDOG_SECONDS, teardown, "watchdog")

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	-- Readiness checks: every wait has a timeout.
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		teardown("no-root")
		return
	end
	teardown("ready")
end)
```

Things to avoid in the ready check: `WaitForChild` without a timeout on anything that can be streamed out; waiting for a server remote that might fire before the client connected its handler; and assuming the first character is the one that matters (death during loading creates a second one).

**Rule of thumb:** a watchdog that fires for more than about 1% of joins means the ready check is waiting for the wrong thing. Log the reason and fix it, rather than raising the timeout.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Other players hang mid-air after spawning | Their client has not started simulating yet | Expected; spawn on ground, optional cosmetic fade |
| Players stuck after a join "fix" | Server anchored roots, unanchor missed | Never anchor to hide join poses |
| Loading screen never leaves for some players | `WaitForChild` without timeout on streamed instance | Timeouts plus a watchdog |
| Loading screen reappears after leaving | Two teardown paths, one re-enables | Idempotent teardown, nothing re-shows |

## Checklist

- [ ] No server-side anchoring of characters to hide join behaviour.
- [ ] Spawns stand on solid ground and stream in first.
- [ ] Loading screen teardown is one idempotent function.
- [ ] A watchdog removes the screen after a fixed time and logs why.
- [ ] Every wait in the ready check has a timeout.
- [ ] Watchdog rate monitored after each release.

## Connected notes
<!-- auto-links:start -->
[[Instance Streaming]] · Case Study - Fast Join and Deferred Loading · Streaming Radius · Spawn Points Safe Zones and Respawn Flow · [[A Stuck Player Watchdog That Logs the Cause]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Loading Screen Skip and First-Session Goals]] · [[Server-Authoritative Freeze and Stun Timestamps]] · [[ipairs Stops at the First nil - Cleanup Tables That Leak]] · [[Centre-Screen Announcements That Stay Centred]] · [[Resetting One Player's Data Safely]] · [[Hold-to-Attack Input That Never Sticks]] · [[Client Hit Prediction for Melee Feedback]] · [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]] · [[Held Weapons on Motor6D - Locking the Grip During Attacks]]
<!-- related:end -->
