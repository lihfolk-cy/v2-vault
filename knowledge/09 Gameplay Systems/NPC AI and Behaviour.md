---
tags: [gameplay, ai, npc, enemies, aggro, behaviour, bosses]
---
# NPC AI and Behaviour

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Brains every frame for all enemies -> 10 Hz, distance gating, staggering
> - Avoid: No zone or leash rule -> Same-zone and leash checks
> - Avoid: No attack tokens -> 2 attackers per target
> - Perception ranges in config, with zone and leash rules.
> - State machine with explicit return-home.
> - Tokens limit simultaneous attackers and are always returned.
>
> Cost: TL;DR ~130 tok · whole note ~3.6k tok. Read more: ## 4. Decision: state machine first · ## 5. Group behaviour: fights that read · ## 10. Common mistakes · ## Checklist
<!-- tldr:end -->

Good enemy AI on Roblox is rarely clever. It is readable, cheap, fair and tunable: enemies notice you at a predictable range, announce it, take turns attacking, telegraph every blow, keep out of each other's way, give up when you leave their area, and do all of that for hundreds of enemies on one server without hurting frame time. This note describes the architecture (perception, decision, action, presentation), the scheduling that keeps it cheap, and the group behaviours that make fights feel designed. Numbers come from one production combat game's enemy system, which ran a data-driven "kit" brain for roughly 90 enemy kinds plus elites and bosses.

Related: [[Pathfinding]], [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[Spawning Teams and Rounds]]. Animation side: [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Boss Animation and Phases]], [[Animating Creatures and Monsters]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. Architecture: four layers

| Layer | Runs on | Job |
|---|---|---|
| Perception | Server | Who is near, who is visible, who hurt me, am I in my zone |
| Decision (brain) | Server | Pick a state and a goal: idle, wander, aggro, chase, attack, return home |
| Action | Server | Move (mover goal or MoveTo), start attacks, run hit timing |
| Presentation | Clients | Animation, telegraph markers, sounds, VFX, health bars, alerts |

The server owns truth, the clients own looks. Enemies are server-owned assemblies ([[Network Ownership]]); clients never decide what an enemy does. The server sends compact state messages ("enemy 41 starts attack Slam at t, aimed at P"); each client plays the clip and draws the telegraph.

**Measured.** The reference project split its enemy service into modules: World (zones, ground, obstacles), Fighters (combat bodies for players), Brain (perception and decisions), Spawner, Attacks, Bosses, Rewards, Moves (special locomotion), plus a client module that animates and draws everything. The split mattered more than any single algorithm: when the original monolithic combat script hit the 200,000-character source limit, the new modular service carried on growing.

---

## 2. Data-driven brains

Hard-coding each enemy is how a roster of 10 becomes unmaintainable at 50. Describe enemies in data and keep one brain:

```lua
--!strict
export type AttackDef = {
	id: string,
	shape: { kind: "circle" | "cone" | "line", radius: number?, halfAngle: number?, length: number?, width: number? },
	range: number,         -- start this attack when the target is within range
	cooldown: number,
	windup: number,        -- telegraph time before the blow (seconds)
	hitTimes: { number },  -- one or more blows, from attack start
	damage: number,
	weight: number,        -- selection weight among valid attacks
	gold: boolean?,        -- an unblockable / special telegraph
}

export type EnemyDef = {
	id: string,
	rank: "Basic" | "Elite" | "Boss",
	health: number,
	poise: number,         -- damage needed to stagger
	walkSpeed: number,
	aggro: number,         -- notice range (studs)
	chase: number,         -- give up beyond this from home
	attacks: { AttackDef },
	phases: { { at: number, speedMul: number?, damageMul: number? } }?,
}
```

The reference project generated these definitions from a script that read each creature's exported clip list, so attack names, marker times and clip lengths in data always matched the animations. Bosses added `phases` (for example "Enrage" at 50% health and "Desperation" at 20%, each raising speed, damage and mood) and a cutscene block.

---

## 3. Perception

### Ranges
| Range | Measured value | Purpose |
|---|---|---|
| Aggro (notice) | 36 studs, later doubled for noticing (x2 multiplier = 72) | Start fighting |
| Chase | 114 studs | Keep chasing within this of home |
| Leash | 200 studs | Hard limit; return home beyond it |
| Enemy reach | 15 studs | Melee start distance (characters were 1.6x scale) |
| Brain active | 200 studs from any player | Think at 10 Hz only when someone is near |
| Area wake / sleep | 160 / 210 studs (was 220 / 260) | Spawn and despawn whole groups |

The aggro range changed several times as enemies were rescaled (42 to 36 when they shrank by 30%, then a 2x "notice" multiplier because players walked past enemies that ignored them). Keep ranges in config and expect to tune them after every scale or map change.

### Rules that prevent nonsense
- **Same zone only.** A non-boss enemy drops its target as soon as the target's zone differs from its own (measured). Without this, enemies chase players through gates into the next area.
- **Armed players only** in a game where the lobby and fighting areas mix.
- **Line of sight** for ranged attackers (one ray to the head is enough).
- **Damage aggro.** Being hit always aggroes, even beyond notice range; otherwise snipers kill enemies that stand still.

### Announce it
A "!" over the enemy and a short red flash when it aggroes on you (measured) turns an invisible state change into a readable event. Then an **aggro pounce**: a quick attack on aggro with a short guard so it cannot be killed before reacting. Players read "it saw me and came for me" instead of "it was already dead".

---

## 4. Decision: state machine first

A finite state machine is enough for most enemies:

```
Idle ─(player in aggro)─► Alert ─► Chase ─(in range, token)─► Attack ─► Recover ─► Chase
  ▲                                  │
  └──────(target lost / leash)───── Return home (heal, ignore hits briefly)
```

Behaviour trees and utility AI help when one enemy has many competing options (a boss with 12 attacks and phases). A practical middle ground is **weighted attack selection** inside the Attack state: filter attacks whose range and cooldown allow, then pick by weight, never the same twice in a row for bosses.

```lua
--!strict
local rng = Random.new()

local function pickAttack(attacks: { any }, distance: number, now: number, lastId: string?, cooldownUntil: { [string]: number })
	local total = 0
	local valid = {}
	for _, a in attacks do
		if distance <= a.range and now >= (cooldownUntil[a.id] or 0) and a.id ~= lastId then
			table.insert(valid, a)
			total += a.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, a in valid do
		roll -= a.weight
		if roll <= 0 then
			return a
		end
	end
	return valid[#valid]
end
```

### Tempo
Enemies that idle between attacks feel broken; enemies that never pause feel unfair. **Measured** tempo knobs from the reference project (applied only while an enemy has a target):

| Knob | Value |
|---|---|
| First attack after reaching range post-aggro | within 0.4 to 0.7 s |
| Per-attack cooldown multiplier when aggroed | 0.6 |
| Post-swing recover and next-swing gap multiplier | 0.4 |
| Follow-through after the last blow | 1/0.7 faster |
| Re-engage after being out of range | 1 s |
| Starter zone multiplier | 0.5 (gentler) |
| Bosses / elites | 0.5 / 0.75 |
| Recovery between attacks (base) | 0.6 to 1.2 s; bosses 0.4 |
| Enemy attack interval (base) | 2.4 s |

The user feedback that triggered this pass was simply "enemies should attack quicker when aggroed". Expose tempo as a few multipliers so such feedback is a config change.

---

## 5. Group behaviour: fights that read

### Attack tokens
Limit how many enemies attack one player at once. The reference project allowed 2 attackers per target and used **telegraph tokens** per realm (3 normal, 1 gold, 1 blue; swarm members counting 0.5). An enemy that cannot get a token circles or taunts. Two enemies attacking in turn are a fight; six attacking at once are a stun-lock.

```lua
--!strict
local Tokens = {}
local held: { [Player]: number } = {}
local MAX = 2

function Tokens.take(target: Player, cost: number): boolean
	local h = held[target] or 0
	if h + cost > MAX then return false end
	held[target] = h + cost
	return true
end

function Tokens.give(target: Player, cost: number)
	held[target] = math.max(0, (held[target] or 0) - cost)
end

return Tokens
```

Always return tokens in a `finally`-style path: attack finished, attacker died, attack cancelled by stagger. A leaked token makes an enemy group go passive forever.

### Spacing
- **Separation:** push each move goal off zone-mates nearer than both radii plus 4 studs (measured).
- **Ring slots:** melee chasers within 30 studs take an assigned angle on a ring at 0.9 x reach around the target instead of all aiming at the exact point (measured). This turns a clump into a circle and leaves the player gaps to escape.
- **Formations** for special packs: a shield wall that blocks 75% from the front until broken by an ability or stagger for 6 s, a guard that blocks 60% frontally.

### Special movement
Data flags gave enemies distinct movement without new code paths: dodge (sidestep with a glint), strafe, kite (keep distance), burrow (travel underground and pop out), rooted (never moves), ambush (buried or disguised until approached, then wake), camouflage. Variety in *how* enemies move does more for a roster than variety in stats.

---

## 6. Movement without pathfinding

Many open combat areas do not need `PathfindingService`. **Measured:** the reference project's enemies steer around trees and set pieces with a cheap local method, about 0.007 ms per think:
- A trunk grid built at start from tree models (base, radius from 16 rays, height) and anything with an obstacle-radius attribute, on a 32-stud grid.
- Each goal is pushed out of trunk circles (radius + body radius + 1) and out of forbidden holes (arrival pads, boss rings).
- Steering: find the first trunk on the straight line within 70 studs; aim for a waypoint 1.35 R around its near side; remember the chosen side per trunk for 1.5 s (no jitter); up to 3 nested reroutes.
- Flyers ignore trunks below their body.
- Spawns and teleports are pushed out of trunks too.

Dry runs crossed 8 dense groves: 17/17 targets reached with no stalls. When the map has rooms, corridors and bridges, use [[Pathfinding]]; when it is an open field with obstacles, local steering is cheaper and more natural.

Walkable areas came from a flood-filled 8-stud grid per zone (rebuild after map edits), so spawns and wander goals are always on reachable floor.

---

## 7. Scheduling: cost control

| Technique | Effect |
|---|---|
| Think at 5 to 10 Hz, not every frame | 6 to 12x less brain cost; movers smooth motion |
| Only think within 200 studs of a player | Idle zones cost nothing |
| Wake/sleep whole areas by distance | Enemies exist only where players are |
| Stagger think times | Avoid all brains running on the same frame |
| Cache ground heights | Fewer raycasts ([[Raycasts Shapecasts and Spatial Queries]]) |
| Filter broadcasts by distance | Less network traffic |

```lua
--!strict
-- Staggered brain scheduler: each enemy thinks every PERIOD, offset by its slot.
local RunService = game:GetService("RunService")
local PERIOD = 0.1

type Brain = { nextThink: number, think: (Brain, number) -> () }
local brains: { Brain } = {}

local function add(b: Brain)
	b.nextThink = os.clock() + math.random() * PERIOD -- random phase
	table.insert(brains, b)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, b in brains do
		if now >= b.nextThink then
			b.nextThink = now + PERIOD
			b:think(now)
		end
	end
end)

return { add = add }
```

Measure with the MicroProfiler and per-module timers ([[MicroProfiler Guide]], [[Script Performance]]).

---

## 8. Elites, rare spawns and bosses

| Kind | Measured rules |
|---|---|
| Elite | x2.5 health, x1.2 damage, x1.5 poise, x1.08 size, enrage below 30%, x2 cash and XP, crowned gold bar and rim |
| Rare spawn | Zone top level +3, 1.35x size, "RARE" tag, 3x drops, replaced by a fresh roll on death |
| Mini-boss | Open arena, walks home and resets after 20 s empty, cannot be hurt from outside |
| Final boss | Sealed arena, phases, cutscene intro, telegraphed attacks with minimum warnings |

Boss fairness rules (measured): warnings and combo links at least 0.5 s, tracking attacks lock their aim at least 0.45 s before the blow, and big room-wide attacks keep long authored warnings (around 3 s). See [[Boss Animation and Phases]].

---

## 9. Presentation rules

- **Enemy clips never play below 1x speed** except a 0.5x stagger hit, which reads as weight. Slow attacks read as sluggish (measured rule).
- **Every attack is telegraphed** with a marker that is the hit shape ([[Hitboxes and Hit Detection]] section 5).
- **Outline enemies** for readability: one `Highlight` adorned to the enemy folder outlines all enemies for one highlight slot (the reference project's approach; highlights are limited per client).
- **Sound per family** (beast, insect, ghost...), capped per crowd, so packs do not become noise ([[Sound Design for Games]]).

---

## 10. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Brains every frame for all enemies | Server frame time high | 10 Hz, distance gating, staggering |
| No zone or leash rule | Enemy trains across the map | Same-zone and leash checks |
| No attack tokens | Stun-locks in packs | 2 attackers per target |
| Leaked tokens | Pack goes passive | Return tokens on every exit path |
| Hard-coded enemies | Roster changes take days | Data definitions + one brain |
| Silent aggro | "It attacked from nowhere" | "!" alert + pounce |
| Slow-motion attack clips | Enemies feel sluggish | Never below 1x |

## Checklist
- [ ] Perception ranges in config, with zone and leash rules.
- [ ] State machine with explicit return-home.
- [ ] Tokens limit simultaneous attackers and are always returned.
- [ ] Spacing (separation and ring slots).
- [ ] Brains gated by distance and staggered at 5 to 10 Hz.
- [ ] Every attack telegraphed with its real hit shape.

## See also
[[Pathfinding]] · [[Combat Systems Architecture]] · [[Hitboxes and Hit Detection]] · [[Spawning Teams and Rounds]] · [[Enemy and NPC Animation]] · [[Boss Animation and Phases]] · [[Case Study - Enemy Roster Rebuild]] · [[Entity Component Systems]]

## Connected notes
<!-- auto-links:start -->
[[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Genre Playbook - Combat and RPG]] · [[Combat Arena and Encounter Layout]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Boss Fight Design Patterns]] · [[Snippets - Enemy Client Animator]]
<!-- auto-links:end -->
