---
tags: [gameplay, combat, co-op, downed, revive, bleed-out, health, state-machine, type/guide, area/gameplay, level/intermediate, api/Humanoid, api/ProximityPrompt, server-authority]
---
# Downed, Revive and Bleed-Out States

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Letting Health hit 0 then trying to undo -> Intercept in the damage core
> - Avoid: Damage paths outside the core -> Route everything through one function; handle explosions and void
> - Avoid: Client-reported revives -> `ProximityPrompt.Triggered` with server checks
> - `LifeState` attribute owned by the server; all damage routed through the core.
> - Lethal damage downs instead of kills when downs remain; instant-kill sources defined.
> - Bleed-out from server timestamps; pauses while revived; shortens on hits and repeat downs.
>
> Cost: TL;DR ~180 tok · whole note ~2.4k tok. Read more: ## 2. Intercepting lethal damage · ## 4. Revive interaction · ## Common mistakes · ## Checklist
<!-- tldr:end -->

In co-op games, dying should usually be a *state*, not an event: the player goes down, crawls, can be revived by a teammate within a time limit, and only dies for real if nobody comes. It turns deaths into team moments and gives skilled groups a recovery loop. On Roblox the main trap is the Humanoid: when `Health` reaches 0 the character dies, joints break by default, and the respawn timer starts. A downed system must intercept damage *before* that. This note covers the state machine, intercepting death, the revive interaction, bleed-out, and the rules that stop downed states being abused.

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. States

```
Alive --(lethal damage, downs left)--> Downed --(revived)--> Alive (at revive health, with a short shield)
                                     |--(bleed-out timer ends or finished off)--> Dead --(respawn rules)--> Alive
Alive --(lethal damage, no downs left / instant-kill source)--> Dead
```

State lives on the server as an attribute on the character (`LifeState = "Alive" | "Downed" | "Dead"`) so every client can render it and every server system can check it.

## 2. Intercepting lethal damage

Never let downed players' `Humanoid.Health` actually reach 0. With one damage core this is straightforward ([[Combat Systems Architecture]]):

```lua
--!strict
local DOWN_HEALTH = 1
local BLEED_OUT = 30
local REVIVE_HEALTH_FRACTION = 0.3

type Life = { downsLeft: number, downedAt: number?, bleedEnd: number? }
local life: { [Player]: Life } = {}

local function setDowned(player: Player, hum: Humanoid)
	local char = hum.Parent :: Model
	local l = life[player]
	l.downsLeft -= 1
	l.downedAt = workspace:GetServerTimeNow()
	l.bleedEnd = l.downedAt + BLEED_OUT
	hum.Health = DOWN_HEALTH
	char:SetAttribute("LifeState", "Downed")
	char:SetAttribute("BleedEnd", l.bleedEnd)
	hum.WalkSpeed = 4 -- crawl; client also switches animation set from the attribute
	hum.JumpPower = 0 -- or JumpHeight, depending on UseJumpPower
end

-- Called by the damage core for players, before subtracting health
local function applyPlayerDamage(player: Player, hum: Humanoid, amount: number, instantKill: boolean)
	local char = hum.Parent :: Model
	local state = char:GetAttribute("LifeState")
	if state == "Dead" then return end
	if state == "Downed" then
		-- damage on a downed player speeds up bleed-out instead of killing outright
		local l = life[player]
		if l.bleedEnd then
			l.bleedEnd -= amount * 0.1
			char:SetAttribute("BleedEnd", l.bleedEnd)
		end
		return
	end
	if hum.Health - amount <= 0 then
		local l = life[player]
		if not instantKill and l and l.downsLeft > 0 then
			setDowned(player, hum)
		else
			char:SetAttribute("LifeState", "Dead")
			hum.Health = 0
		end
		return
	end
	hum.Health -= amount
end
```

Other things that can still kill a Humanoid bypass your core: the `Explosion` instance's joint breaking, falling below `Workspace.FallenPartsDestroyHeight`, scripts setting `Health = 0`, and `BreakJoints` style resets. Handle them: disable joint breaking on explosions ([[Explosions - Radius Damage, Falloff and Cover Checks]]), treat void falls as instant kills or teleport to a safe point, and keep `Humanoid.BreakJointsOnDeath` in mind for death presentation (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Humanoid#BreakJointsOnDeath).

Players can still reset their character from the Roblox menu. Either accept it (treat as bleed-out) or disable the reset button during downed state with `StarterGui:SetCore("ResetButtonCallback", false)` on the client (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/StarterGui#SetCore). Re-enable it afterwards.

## 3. Bleed-out

- A server timer per downed player (`bleedEnd` in server time). One loop at 2 to 4 Hz checks all downed players rather than a `task.delay` per player that must be cancelled on revive.
- Clients render the countdown from the `BleedEnd` attribute and `workspace:GetServerTimeNow()`, no per-second remotes ([[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]] uses the same pattern).
- **Being revived pauses bleed-out** (Rule of thumb); being hit while downed shortens it or, in harder modes, finishes the player.
- Each subsequent down in the same life is shorter (30 s, then 20 s, then 10 s) or limited by `downsLeft`, so a team cannot revive-loop forever.

## 4. Revive interaction

Use a `ProximityPrompt` on the downed character's root with `HoldDuration` set to the revive time (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt):
- Server creates and enables it on down, disables and destroys it on revive or death.
- Trigger handling on the server re-validates: reviver alive, not downed, within range, on the same team, the target still downed. `ProximityPrompt.Triggered` gives you the player; never trust a client "I revived X" remote.
- Show the prompt only to teammates: a client script disables it locally (`prompt.Enabled = false` on that client) when the downed player is on another team. The server check on trigger is still the real gate.
- Interruptions: if the reviver takes damage or moves out of range, `PromptButtonHoldEnded` fires; the revive progress is lost (or partially kept; a design choice).
- Revive sets `LifeState = "Alive"`, restores walk speed and jump, health to a fraction (25 to 40% of max), and a short damage shield (1 to 2 s) so the revived player is not instantly re-downed.

Self-revive items, auto-revive perks and NPC medics plug into the same `revive(player)` function.

## 5. While downed

| Allowed | Usually not allowed |
|---|---|
| Crawl slowly | Sprint, jump, climb |
| Ping location, chat, emote | Use most abilities and tools |
| Use a sidearm (some designs) | Open shops or trade |
| Be carried by a teammate ([[Grabs, Carries and Throws - Moving Players Safely]]) | Capture objectives |

Gate actions in each server handler by checking `LifeState`; the client UI should also hide what is unavailable. Enemy AI should usually ignore downed players or treat them as low priority, otherwise downed players are camped and the system feels cruel ([[NPC AI and Behaviour]]).

## 6. Presentation

- Downed animation set (crawl, idle on ground), camera lowered, desaturation and heartbeat audio rising as bleed-out approaches ([[Spatial Audio and Mixing]]).
- World markers for teammates showing downed players and their remaining time ([[World-Space UI - BillboardGui and SurfaceGui]]).
- Kill credit: decide whether the down or the final death awards the kill, and keep the damage ledger through the downed state ([[Kill Credit, Assists, Kill Feed and Death Recaps]]).

## 7. Team wipe

If every alive player in the group is downed or dead, the encounter is lost: end it immediately (do not make players watch bleed-out timers), then respawn at a checkpoint. Solo players either skip downed state or get a self-revive.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Letting Health hit 0 then trying to undo | Character dies, respawns anyway | Intercept in the damage core |
| Damage paths outside the core | Instant deaths while downed | Route everything through one function; handle explosions and void |
| Client-reported revives | Self-revive exploits | `ProximityPrompt.Triggered` with server checks |
| Per-player delay tasks | Ghost deaths after revive | One bleed-out loop over server timestamps |
| No shield after revive | Instant re-downs | 1 to 2 s shield |
| Enemies camp downed players | Hopeless revives | AI ignores or deprioritises downed |

## Checklist
- [ ] `LifeState` attribute owned by the server; all damage routed through the core.
- [ ] Lethal damage downs instead of kills when downs remain; instant-kill sources defined.
- [ ] Bleed-out from server timestamps; pauses while revived; shortens on hits and repeat downs.
- [ ] Revive prompt server-created, team-only, validated on trigger; shield after revive.
- [ ] Actions gated by state on the server; AI treats downed players sensibly.
- [ ] Team wipe ends the encounter quickly.

## See also
[[Combat Systems Architecture]] · [[Characters and Humanoids]] · [[Spawn Points Safe Zones and Respawn Flow]] · [[Status Effects Buffs and Stacking Rules]] · [[Social Design and Multiplayer Play]] · [[Server-Authoritative Freeze and Stun Timestamps]]

## Connected notes
<!-- auto-links:start -->
[[Grabs, Carries and Throws - Moving Players Safely]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[Genre Playbook - Horror and Story]] · Procedural Death Knockdown and Hit Reactions
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Spawning Teams and Rounds]] · [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[Hitboxes and Hit Detection]] · [[Character Select and Class Systems with Different Rigs]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]]
<!-- related:end -->
