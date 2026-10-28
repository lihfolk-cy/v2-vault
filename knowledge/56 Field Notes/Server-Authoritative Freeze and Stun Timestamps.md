---
tags: [field-notes, status-effects, stun, freeze, server-authority, attributes, combat, luau]
---
# Server-Authoritative Freeze and Stun Timestamps

<!-- tldr:start -->
> [!tldr] TL;DR
> - Player frozen forever after an error: Unfreeze depended on a delayed callback -> Timestamp that expires by itself
> - Second freeze ends early: First freeze's timer cleared the flag -> `max` of end times
> - Target perma-locked by a group: No immunity -> Immunity window after each freeze
> - Freeze, stun and root use `...Until` server-time attributes on the character.
> - Overlaps merge with `max`; immunity starts at the end of the freeze.
> - Released on death; cleared naturally on respawn.
>
> Cost: TL;DR ~160 tok · whole note ~1.7k tok. Read more: ## 1. A timestamp attribute, not a flag · ## 4. Clients read the same value · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A freeze or stun implemented as "set `Frozen = true`, then `task.delay(2, unfreeze)`" works until the delayed function errors, the character respawns in between, a second freeze overlaps the first, or a message to the client is lost. Then someone is frozen forever. Storing the *end time* instead of a flag removes the whole class of bug: the status expires on its own, overlapping freezes merge with `max`, and clients can read the same value and lock their own input. Stacking rules in general are in [[Status Effects Buffs and Stacking Rules]]; authority in [[Server Authority]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. A timestamp attribute, not a flag

Store `FrozenUntil` on the character as a number in **server time**. `Workspace:GetServerTimeNow()` returns a time that is approximately synchronised between server and clients (Roblox docs), so both sides can compare against the same attribute without sending a separate "unfreeze" message.

```lua
-- Server module: Freeze
local Workspace = game:GetService("Workspace")

local Freeze = {}
local IMMUNITY_AFTER = 2.0 -- seconds of freeze immunity once a freeze ends

function Freeze.isFrozen(character: Model): boolean
	return (character:GetAttribute("FrozenUntil") or 0) > Workspace:GetServerTimeNow()
end

function Freeze.apply(character: Model, seconds: number): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	if (character:GetAttribute("FreezeImmuneUntil") or 0) > now then
		return false -- recently frozen: immune
	end
	local current = character:GetAttribute("FrozenUntil") or 0
	local untilTime = math.max(current, now + seconds) -- overlapping freezes extend, never stack
	character:SetAttribute("FrozenUntil", untilTime)
	character:SetAttribute("FreezeImmuneUntil", untilTime + IMMUNITY_AFTER)
	return true
end

function Freeze.release(character: Model)
	character:SetAttribute("FrozenUntil", nil)
end

return Freeze
```

Properties of this design:

- **It expires on its own.** No timer has to fire. If every script that could clear it errors, it still ends at `FrozenUntil`.
- **Overlaps merge.** Two 2-second freezes 1 second apart give 3 seconds, not 4, and not "the first one's unfreeze cancels the second".
- **Immunity prevents chain-locking.** Without it, a group can keep one target frozen indefinitely. Set immunity from the *end* of the freeze. **Rule of thumb:** immunity at least as long as the typical freeze.
- **Diminishing returns** fit naturally: shorten `seconds` based on how many freezes the target received in the last N seconds.

## 2. Release on death and respawn

Put the attributes on the **character model**, not the `Player`. A respawn creates a new character with no attributes, so a freeze can never survive a respawn. Also release on death, so death animations and ragdolls are not held in place:

```lua
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			Freeze.release(character)
		end)
	end)
end)
```

**Measured.** The reference project ships exactly this shape: a `FrozenUntil` timestamp that expires on its own, immunity afterwards, release on death and respawn, and clients reading the attribute to lock input.

## 3. Every server action checks it

The attribute is information; enforcement is the server refusing actions. Every handler that performs an attack, ability, dash or interaction for a player starts with:

```lua
if Freeze.isFrozen(character) then
	return -- reject silently or send a short "frozen" reason
end
```

Movement is client-owned physics, so the server cannot simply forbid it. The client locks its own controls (below), and the server's movement validation treats significant movement during a freeze as suspicious, the same way it treats speed hacks ([[False Positives Lag and Fair Enforcement]]).

## 4. Clients read the same value

```lua
-- Client: lock input and show the effect while frozen.
local function watch(character: Model)
	local function refresh()
		local untilTime = character:GetAttribute("FrozenUntil") or 0
		local remaining = untilTime - workspace:GetServerTimeNow()
		if remaining > 0 then
			InputLock.set("Freeze", true)
			FreezeVfx.show(character)
			task.delay(remaining, refresh) -- re-check at expiry; an extension will have changed the value
		else
			InputLock.set("Freeze", false)
			FreezeVfx.hide(character)
		end
	end
	character:GetAttributeChangedSignal("FrozenUntil"):Connect(refresh)
	refresh()
end
```

Other clients use the same attribute for the ice VFX on someone else's character. The local player's input lock is a keyed lock (`InputLock.set("Freeze", ...)`), so a freeze ending does not clear a cutscene's lock.

Stuns, roots and silences follow the same pattern with their own `...Until` attributes. Keep each in its own attribute so one effect's expiry never clears another, and register all of them as intended holds for [[A Stuck Player Watchdog That Logs the Cause]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Player frozen forever after an error | Unfreeze depended on a delayed callback | Timestamp that expires by itself |
| Second freeze ends early | First freeze's timer cleared the flag | `max` of end times |
| Target perma-locked by a group | No immunity | Immunity window after each freeze |
| Frozen after respawn | Status stored on `Player` | Store on the character; release on death |
| Exploiter attacks while frozen | Only the client checked | Server checks in every action handler |
| Freeze ending unlocks a cutscene | One shared boolean input lock | Keyed input locks |

## Checklist

- [ ] Freeze, stun and root use `...Until` server-time attributes on the character.
- [ ] Overlaps merge with `max`; immunity starts at the end of the freeze.
- [ ] Released on death; cleared naturally on respawn.
- [ ] Every server action handler checks the status.
- [ ] Clients derive input locks and VFX from the attribute, with keyed locks.
- [ ] Registered as intended holds for the stuck watchdog.

## Connected notes
<!-- auto-links:start -->
[[Status Effects Buffs and Stacking Rules]] · [[Server Authority]] · [[Combat Systems Architecture]] · [[False Positives Lag and Fair Enforcement]] · [[A Stuck Player Watchdog That Logs the Cause]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
