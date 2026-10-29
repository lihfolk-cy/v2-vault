---
tags: [gameplay, ai, spawning, director, pacing, waves, scaling, co-op, type/guide, area/gameplay, level/advanced, server-authority]
---
# Spawn Director - Credit Budgets and Player-Count Scaling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Per-pad timers -> One director with credits
> - Avoid: Linear scaling with players -> Sub-linear earn rate, flat alive cap
> - Avoid: Counting all players in the server -> Count active participants
> - Roster priced in credits; earn rate, cap and alive cap in live config.
> - Intensity tracked; build, peak and relax phases implemented.
> - Scaling uses active participants, sub-linear, smoothed.
>
> Cost: TL;DR ~140 tok · whole note ~2.2k tok. Read more: ## 1. The credit model · ## 4. Where to spawn · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Fixed spawners ("this pad spawns a zombie every 5 seconds") produce either empty maps or swarms, and they scale terribly: two players get the same pressure as eight. A **spawn director** replaces per-spawner timers with one server brain that earns spawn credits over time, spends them on enemies from a priced roster, chooses where they appear, and bends the pace around how the players are doing. This note covers the credit model, intensity-based pacing, player-count scaling, spawn point selection and budgets. Enemy brains themselves are in [[NPC AI and Behaviour]]; wave-based tower defense specifics in [[Tower Defense Waves and Placement End to End]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. The credit model

- Every enemy type has a **cost** in credits, roughly proportional to the threat it adds (health times damage, adjusted for behaviour). Fodder 1, ranged 3, tank 8, elite 20, mini-boss 60 are plausible starting ratios (**Rule of thumb**; tune with [[Time-to-Kill Math and a Weapon Balance Sheet]]).
- The director **earns** credits per second: `rate = baseRate * playerScale * phaseMultiplier * intensityMultiplier`.
- It **spends** when it can afford a pick and the alive-cap allows. Picks are weighted by the current phase's roster (early: fodder heavy; later: more ranged and tanks).
- Credits **cap** (for example 2 to 3 times the most expensive allowed enemy), so a quiet minute does not bank a horde.
- **Saving up** is a feature: sometimes the director deliberately waits to afford an elite rather than dribbling fodder, which creates peaks.

```lua
--!strict
export type EnemyDef = { id: string, cost: number, weight: number, minPhase: number }

local Director = {}
Director.__index = Director

export type Director = typeof(setmetatable({} :: {
	credits: number, cap: number, alive: number, maxAlive: number,
	roster: { EnemyDef }, phase: number, rng: Random,
}, Director))

function Director.new(roster: { EnemyDef }, maxAlive: number): Director
	return setmetatable({
		credits = 0, cap = 60, alive = 0, maxAlive = maxAlive,
		roster = roster, phase = 1, rng = Random.new(),
	}, Director)
end

function Director.tick(self: Director, dt: number, rate: number, spawn: (EnemyDef) -> boolean)
	self.credits = math.min(self.cap, self.credits + rate * dt)
	if self.alive >= self.maxAlive then return end

	local total = 0
	local options: { EnemyDef } = {}
	for _, e in self.roster do
		if e.minPhase <= self.phase and e.cost <= self.credits then
			table.insert(options, e)
			total += e.weight
		end
	end
	if total == 0 then return end
	local roll = self.rng:NextNumber() * total
	for _, e in options do
		roll -= e.weight
		if roll <= 0 then
			if spawn(e) then
				self.credits -= e.cost
				self.alive += 1
			end
			return
		end
	end
end

return Director
```

`spawn` returns false when no valid spawn point exists, so credits are not burned. Decrement `alive` on despawn as well as death.

## 2. Intensity and pacing

A director that spends steadily feels like a treadmill. Track **intensity** per player and shape a build, peak, relax rhythm:

- Intensity rises on damage taken, nearby enemies, low health and being downed; decays over a few seconds.
- **Build**: spend normally.
- **Peak**: when average (or max) intensity crosses a threshold, allow a burst (spend the bank, allow the elite).
- **Relax**: after a peak, cut the earn rate sharply for 15 to 40 s, clean up stragglers, let players loot and heal. Without relax beats players never get to enjoy power (**Rule of thumb**; see [[Progression and Pacing Design]]).

The same signal powers adaptive music ([[Music and Adaptive Audio]]) and the horror tension director in [[Genre Playbook - Horror and Story]].

## 3. Player-count scaling

Scale **pressure**, not just count, and do it sub-linearly:

| Lever | Scaling | Why |
|---|---|---|
| Earn rate | `1 + k * (n - 1)` with k around 0.5 to 0.7 | Groups kill faster but also overlap damage; linear scaling over-tunes for 6+ |
| Enemy health | Mild multiplier for elites and bosses only | Fodder should still die fast; bosses need to survive focus fire |
| Alive cap | Grows slower than earn rate; hard cap from performance | Server cost scales with alive count, not with credits |
| Elite frequency | Unlocks earlier with more players | Gives groups set-piece targets |

**Rule of thumb.** Hold the alive cap flat or nearly flat and scale health and composition instead, as tower defense games do ([[Genre Playbook - Tower Defense]]). Recompute `n` from players **alive and in the encounter area**, not server population, so AFK players in the lobby do not raise difficulty; smooth `n` changes over 10 to 20 s so a death does not instantly lower pressure (it should feel like a comeback window, not a stealth nerf).

## 4. Where to spawn

Spawn location is half of perceived fairness. A candidate point is valid when:

1. **Distance band**: between `minDist` (say 40 studs) and `maxDist` (say 120 studs) from the nearest player.
2. **Not in view**: the server has no camera, so approximate with each player's character look direction (dot product above 0.5 means "in front") **plus** a line-of-sight raycast from head to point. Spawning behind cover is fine; spawning in plain sight breaks immersion ([[Dot and Cross Products in Gameplay]]).
3. **Reachable**: precomputed on the navmesh at authoring time, or flagged on the spawn marker; do not compute a path per spawn attempt ([[Pathfinding]]).
4. **Not recently used** (cooldown per point) and not inside a safe zone ([[Spawn Points Safe Zones and Respawn Flow]]).
5. **Ahead of progress** in linear maps: prefer points between the players and their objective.

Author spawn points as tagged parts (`CollectionService` tag `SpawnPoint`) with attributes for allowed enemy classes (`Flyer`, `Large`) and area id. Evaluate a handful of random candidates per spawn, not all of them.

## 5. Budgets and safety

- Director ticks at 2 to 5 Hz; spawning more than a few enemies per tick causes visible hitches ([[MicroProfiler Guide]]). Queue and drip.
- Pool enemy models instead of cloning per spawn when counts are high ([[Memory Budgets and Leaks]]).
- Despawn enemies that end up far from all players or stuck (a stuck watchdog, see [[A Stuck Player Watchdog That Logs the Cause]] for the pattern) and refund part of their cost.
- Everything is server-side. Clients never request spawns; dev commands that do are admin-gated ([[Admin Commands Done Safely - Permissions and Audit Logs]]).
- Make every number live-tunable ([[Global State and Live Config]]) and log per-encounter credits earned, spent and peak intensity for balancing.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Per-pad timers | Empty or flooded maps; no scaling | One director with credits |
| Linear scaling with players | 8-player lobbies drown | Sub-linear earn rate, flat alive cap |
| Counting all players in the server | AFK lobby players raise difficulty | Count active participants |
| No relax phase | Exhaustion, no time to loot | Post-peak earn cut |
| Spawning in view | Pop-in, unfair hits | Look-direction and LOS checks |
| Burning credits on failed spawns | Director stalls | Spawn returns success; refund |

## Checklist
- [ ] Roster priced in credits; earn rate, cap and alive cap in live config.
- [ ] Intensity tracked; build, peak and relax phases implemented.
- [ ] Scaling uses active participants, sub-linear, smoothed.
- [ ] Spawn points tagged with classes; distance, view, reachability and cooldown checked.
- [ ] Spawns dripped and pooled; stuck and far enemies culled.
- [ ] Encounter telemetry logged.

## See also
[[NPC AI and Behaviour]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Combat Arena and Encounter Layout]] · [[Spawning Teams and Rounds]] · [[Tower Defense Waves and Placement End to End]] · [[Balancing with Spreadsheets and Data]]

## Connected notes
<!-- auto-links:start -->
[[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Genre Playbook - Combat and RPG]] · Horror Monster Chase AI End to End · Probability and Statistics for Designers
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Combat Systems Architecture]] · [[Status Effects Buffs and Stacking Rules]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[Downed, Revive and Bleed-Out States]]
<!-- related:end -->
