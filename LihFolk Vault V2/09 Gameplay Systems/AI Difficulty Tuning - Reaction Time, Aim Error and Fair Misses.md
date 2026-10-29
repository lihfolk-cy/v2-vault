---
tags: [gameplay, ai, difficulty, aim, reaction-time, fairness, npc, shooters, type/guide, area/gameplay, level/advanced, server-authority]
---
# AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Aiming at the live position -> Tracking lag from a history buffer
> - Avoid: Fixed random spread -> Converging error with disturbances
> - Avoid: Instant reaction -> 0.2 s minimum, distance-scaled detection
> - Perception uses detection time, reaction time and tracking lag.
> - Aim error converges, resets on disturbance and has a floor.
> - First-shot misses and low-health mercy on easy and normal.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 1. The perception pipeline: delay first · ## 2. Aim error that converges · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An NPC on a Roblox server has perfect information: it knows every player's exact position every frame and can raycast a headshot in microseconds. Making it *hard* is trivial; making it *fair and fun* is the work. This note gives the levers that turn a perfect machine into a believable opponent (perception delay, reaction time, aim error that converges, deliberate near misses, attack cadence) and a difficulty table that moves those levers together. It applies to ranged enemies, bot players in shooters and melee enemies alike. Group limits (how many attack at once) are in [[Squad AI - Attack Tokens, Flanking and Attacker Limits]].

Source labels: **Rule of thumb** (game AI practice and human-factors figures commonly used in design), **Roblox docs** where engine calls are used.

---

## 1. The perception pipeline: delay first

Every NPC sees the world through a **delay buffer**, not the live state:

1. **Detection time**: from a target entering view to the NPC becoming aware. Scale by distance, lighting, the target crouching or moving. 0.3 to 1.5 s.
2. **Reaction time**: from aware to first action. Human simple reaction is commonly cited at roughly 0.2 to 0.3 s; choice reactions are slower. Easy bots 0.6 to 0.9 s, normal 0.35 to 0.5 s, hard 0.2 to 0.3 s. **Never below about 0.15 s**, or players perceive aimbotting.
3. **Tracking lag**: the NPC aims at where the target *was* `lag` seconds ago (a position history ring buffer), not where it is. Strafing then works as a real defence.

```lua
--!strict
-- Position history for tracking lag (server). Sample at brain tick rate.
type Sample = { t: number, pos: Vector3 }
local History = {}
History.__index = History

export type History = typeof(setmetatable({} :: { samples: { Sample }, max: number }, History))

function History.new(max: number): History
	return setmetatable({ samples = {}, max = max }, History)
end

function History.push(self: History, t: number, pos: Vector3)
	table.insert(self.samples, { t = t, pos = pos })
	if #self.samples > self.max then table.remove(self.samples, 1) end
end

function History.at(self: History, t: number): Vector3?
	local s = self.samples
	for i = #s, 2, -1 do
		if s[i - 1].t <= t then
			local a, b = s[i - 1], s[i]
			local alpha = math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1)
			return a.pos:Lerp(b.pos, alpha)
		end
	end
	return if #s > 0 then s[1].pos else nil
end

return History
```

## 2. Aim error that converges

Model aim error as an angular cone around the (lagged) target point, then sample inside it:

- **Initial error** when acquiring a target: large (for example 6 to 10 degrees on normal).
- **Convergence**: error shrinks exponentially while the NPC keeps the target in view (half-life 0.6 to 1.5 s), down to a **floor** (1 to 3 degrees).
- **Disturbances** reset error upward: the NPC takes damage, the target moves fast laterally, the NPC moves, the target lands from a jump or dashes.
- **Distance**: angular error naturally means more misses at range, which is what players expect.

Sample uniformly in a disk (use `sqrt` of a random radius) or Gaussian-ish (average two randoms) for more hits near the centre.

```lua
--!strict
local rng = Random.new()

local function aimDirection(from: Vector3, aimPoint: Vector3, errorDeg: number): Vector3
	local forward = (aimPoint - from).Unit
	local r = math.rad(errorDeg) * math.sqrt(rng:NextNumber())
	local theta = rng:NextNumber() * 2 * math.pi
	local cf = CFrame.lookAt(from, from + forward)
	local offset = cf.RightVector * math.cos(theta) * math.tan(r) + cf.UpVector * math.sin(theta) * math.tan(r)
	return (forward + offset).Unit
end

local function updateError(current: number, floor: number, halfLife: number, dt: number): number
	return floor + (current - floor) * math.exp(-dt * 0.693 / halfLife)
end
```

## 3. Fair misses: make the miss part of the show

Misses should **communicate**, not just fail:
- **First-shot miss**: the first shot after acquiring a new target is deliberately offset to pass near the player (visible tracer, impact on a wall beside them, whiz sound). It announces the threat. **Rule of thumb:** guarantee a miss on the first 1 to 2 shots on easy and normal.
- **Miss toward the camera side**, not behind the player, so the miss is seen.
- **Low-health mercy**: when the target is under about 25 to 30% health, increase error or slow cadence briefly. Players remember the clutch survival, not the hidden assist; keep it subtle and never make the NPC visibly stop.
- **Hit budget**: cap hits per target per second from all NPCs (a damage-per-second ceiling per difficulty), so chip from several shooters does not delete a player who cannot see them.

## 4. Melee equivalents

Melee AI difficulty is about **timing and tells**, not accuracy:
- Telegraph length (longer on easy), recovery length (longer is more punishable), combo length, and how often the NPC feints or delays.
- Reaction to player attacks: block or dodge probability per difficulty, with a cooldown so the NPC cannot block everything ([[Combat Combo Systems]]).
- Tracking during the swing: rotation speed limits during windup let players sidestep; hard enemies track longer into the windup.

## 5. A difficulty table that moves together

| Lever | Easy | Normal | Hard |
|---|---|---|---|
| Reaction time (s) | 0.7 | 0.4 | 0.25 |
| Tracking lag (s) | 0.35 | 0.2 | 0.12 |
| Initial aim error (deg) | 10 | 7 | 4 |
| Error floor (deg) | 4 | 2.5 | 1.2 |
| Convergence half-life (s) | 1.5 | 1.0 | 0.6 |
| Guaranteed first misses | 2 | 1 | 0 |
| Max hits/s per target (all NPCs) | 1 | 2 | 3 |
| Melee telegraph multiplier | 1.4 | 1.0 | 0.8 |

All values are **Rule of thumb** starting points. Change one difficulty by moving the whole row, not a single cell, and keep the table in live config ([[Global State and Live Config]]). Accessibility-oriented difficulty options are discussed in [[Difficulty Options and Cognitive Load]].

## 6. Measuring

Log per encounter: hits taken per minute, time-to-first-hit after detection, deaths by enemy type, and near-miss counts. If one enemy type dominates deaths, look at its tells and hit budget before its damage. Watch playtests: players saying "how did that hit me" means tracking lag or reaction is too low; "they never hit anything" means the floor is too high.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Aiming at the live position | Strafing is useless, feels like aimbot | Tracking lag from a history buffer |
| Fixed random spread | Bots either laser or spray | Converging error with disturbances |
| Instant reaction | Players die on peek | 0.2 s minimum, distance-scaled detection |
| Invisible misses | No sense of threat | First-shot misses near and in front of the player |
| No per-target hit cap | Deaths from unseen chip | Hit budget per difficulty |
| Tuning one lever at a time across modes | Incoherent difficulty | Move the whole row |

## Checklist
- [ ] Perception uses detection time, reaction time and tracking lag.
- [ ] Aim error converges, resets on disturbance and has a floor.
- [ ] First-shot misses and low-health mercy on easy and normal.
- [ ] Per-target hit budget across all NPCs.
- [ ] Difficulty rows in live config; encounter telemetry logged.

## See also
[[NPC AI and Behaviour]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Difficulty Options and Cognitive Load]] · [[Probability and Statistics for Designers]] · [[Anticipation]]

## Connected notes
<!-- auto-links:start -->
[[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Boss Fight Design Patterns]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Hitboxes and Hit Detection]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Combat Systems Architecture]] · [[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]] · [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]]
<!-- related:end -->
