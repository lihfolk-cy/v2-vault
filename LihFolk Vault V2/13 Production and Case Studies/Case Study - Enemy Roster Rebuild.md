---
tags: [case-study, enemies, ai, combat, migration, art-pipeline, production, type/case-study, area/production, level/intermediate, area/monetization]
---
# Case Study: Enemy Roster Rebuild

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Building new features into a script at the size limit.
> - Avoid: A big-bang swap from old to new AI.
> - Avoid: Scaling every enemy by the same factor regardless of design.
> - Roles and telegraph language defined before modelling.
> - Enemy data, models and clips independent of level geometry.
> - Zone-by-zone ownership flags; old path intact until the new one is play-tested.
>
> Cost: TL;DR ~140 tok · whole note ~4.0k tok. Read more: ## Migration: the strangler pattern · ## Tuning: size, density, damage, tempo · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Enemies are where combat, AI, art, animation, economy and performance meet, so rebuilding them touches everything. This case study follows one live action game through a complete replacement of its enemy roster: from an old data-driven system living inside one oversized combat script, to a new enemy service with roles and telegraphs, migrated zone by zone while the game kept working, then tuned (size, density, damage, tempo) and finally given an entirely new look in one day without touching the AI.

Related depth: [[NPC AI and Behaviour]], [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Boss Animation and Phases]].

## The starting roster

The first roster had under twenty enemies across a handful of zones plus a boss, run by a data-driven "kit AI": each enemy's attacks, marker times, hits, poise and phases were data; a shared brain ran them. Ranks multiplied stats:

| Rank | Health x | Damage x | Size x | Drops x | Spawn weight |
|---|---|---|---|---|---|
| Basic | 1 | 1 | 1 | 1 | 0.74 |
| Advanced ("elite") | 2.6 | 1.55 | 1.18 | 2.4 | 0.26 |
| Boss | 1 | 1 | 1 | 3 | 0 (placed, not rolled) |

That design was sound. The problem was where it lived: the zone combat script that ran spawns, aggro, hits and rewards was about 199,600 of the 200,000 characters a script's Source can hold (measured). Every enemy feature had to go into child modules or an API module, and the script itself became "never edit". It also had visible quality issues: enemies with no hit animation, inconsistent scale, attacks that could be dodged only by luck.

## The plan: roles, readability, data

A revamp plan set rules before any model was built:

- **Roles:** melee (closes and combos), ranged (keeps distance, telegraphed shots), tank (slow, armour phase, shield bash), swarm (packs of 4 to 6, weak), summoner (spawns adds, priority target).
- **Readability:** every attack has a 0.4 to 0.8 second telegraph (glow plus pose plus ground marker), a silhouette per role, a hit flash and a stagger.
- **Telegraph colours as a language:** red normal, gold unblockable (dash out), blue push / pull / lift, violet summon.
- **Bosses:** 3 phases, about 6 attacks, an intro camera; mini-bosses 2 phases, 3 to 4 attacks.
- **Shared rigs:** one base rig per body type (biped, quadruped, flyer, crawler, floater, swimmer); designs differ in mesh, texture and moves.
- **Server-authoritative hits** on attack frames (animation markers), client-side presentation.
- **Sleep** beyond about 200 studs from any player; animation LOD by distance.

See [[Planning and Scoping a Roblox Game]] for how the plan was gated.

## Building the new service

The new enemy service was built as a slice first: zone 1, two enemy types, telegraphs, hits, rewards. Then the whole first area in one push: data for well over a dozen regulars, a minion and a couple of bosses (every attack from the design documents with real clip timings), spawn tables for every zone, and the mechanics they needed: summons, burrow, teleport and blink, charges that stun on hitting a wall, rolls, tethers and pulls, armour phases, weak points while staggered, projectiles, lingering hazards, perching flyers. A few hundred clips with telegraph and hit markers came from Blender. Grey stand-ins fought until each model was imported, so the AI could be tested before the art existed.

The client played every clip on the real rigs (idle, walk, run, hits, stagger, stun, spawn, taunt, death, layered partial clips) with effects and sounds on markers. See [[Pipeline - Importing Animated Enemies]] and [[Enemy Import Axis Fix]] (imported clips played turned 180 degrees until an axis fix step was added).

### The map was deleted; the enemies survived

The new enemies were built for a new staging map. Shortly after, the owner deleted that map and kept the original one. Because the enemies were data plus models plus clips, with spawn areas read from the map rather than baked into it, the whole roster moved onto the original zones in one evening. A new spawn table read each zone's walk centre and half-size from attributes on the existing zone folders. That is the strongest argument for keeping enemy definitions independent of level geometry.

## Migration: the strangler pattern

Replacing the old system in one cut would have meant one huge untested swap. Instead the new service took over zone by zone:

1. The new service initialises and, only if init succeeds, sets a workspace attribute per zone it owns (`NewEnemiesZone1`, `NewEnemiesZone2`, and so on).
2. The old script's main loop skips any flagged zone (a one-line edit, with comments trimmed to fit under the size limit).
3. Rewards from the new service are emitted in the old reward payload format, so cash, XP, materials, quests and boss unlock logic needed no change. The new final boss paid out under the old boss's reward key, so progression unlocks tied to that boss kept working.
4. Later, a static gate in the old script (reading which rows the new service replaces) made sure old enemies could never reappear in owned zones even if the flags were missing.

```lua
--!strict
-- Old service main loop (excerpt): yield zones the new service owns.
for zoneIndex, zone in zones do
	if workspace:GetAttribute("NewEnemiesZone" .. zoneIndex) == true then
		continue -- owned by the new enemy service
	end
	stepZone(zone)
end
```

```lua
--!strict
-- New service: claim a zone only after it is ready, so a failed init falls back to the old system.
local function claimZone(zoneIndex: number, init: () -> ()): boolean
	local ok, err = pcall(init)
	if ok then
		workspace:SetAttribute("NewEnemiesZone" .. zoneIndex, true)
	else
		warn(`zone {zoneIndex} stays on the old system: {err}`)
	end
	return ok
end
```

This is the strangler-fig migration applied to a Roblox service. Its cost is running two systems for a while; its benefit is that every step is reversible by clearing one attribute.

### Regressions from running two systems

Some behaviour lived only in the old system and was lost silently:

- **Blood and hit sounds.** The old script fired a remote that made clients play blood splats and hit sounds. The new service never fired it, so hits were silent until a player reported it. The fix reused the old payload and the client's existing sounds.
- **Engage guard.** The old system protected an enemy from being one-shot before it reacted to aggro; the new one needed its own.

Lesson: before migrating, list every **side effect** the old system produces (remotes fired, attributes set, sounds, analytics, quest signals), not just its main behaviour, and check each one in the new system. See [[Combat Systems Architecture]].

## Tuning: size, density, damage, tempo

Once enemies ran, most of the remaining work was tuning, and it was where the project churned most.

### Size

| Change | Values (measured) | Trigger |
|---|---|---|
| Enemies 2.3x bigger, new sounds | body scale 2.3 | "enemies bigger, better sounds" |
| Same day: 30% smaller | 2.3 to 1.61 | Too big |
| New service scale | 1.0 to 1.6; megas 1.6 to 2.2; bosses 1.8 (were 1) | "Much larger; megas and bosses should be huge" |
| Later | 1.6 to 2.1; megas 2.0; bosses 2.4 | "Too many small enemies; make small ones bigger" |
| Size targets | target height 13 studs (player about 9), per-model scale clamped 1.15 to 3.2 | After a full redesign with varied proportions |

The final form, a **target height with clamps**, is the right one: designs with very different proportions all read as "bigger than the player" without per-model tweaking, and hit shapes scale with the body. A single scale multiplier on varied designs leaves small designs tiny and large ones absurd. Characters were scaled 1.6x (about 9 studs), so every enemy reach and every player ability range had to account for that too. See [[Scale and Animation]].

### Density and placement

Spawn density was cut to 0.55 of its previous value (one knob over every zone's cap, base and per-player count). Spawns were then pushed back from each zone's entry gate: no group centre within 120 studs of the entry, and acceptance probability rising from 0.25 at that line to 1 at the next gate, with packs near the far end getting an extra member. Simulated over a zone about 600 studs long, the share of spawns per sixth of the zone ran 0%, 9%, 15%, 20%, 26%, 30% from the entry (measured).

```lua
--!strict
-- Accept a candidate spawn point with a probability that rises toward the next gate.
local GATE_CLEAR = 120 -- studs from the entry gate with no spawns
local FAR_MIN = 0.25   -- acceptance right at the clear line

local function acceptSpawn(distanceFromEntry: number, zoneLength: number, rng: Random): boolean
	if distanceFromEntry < GATE_CLEAR then
		return false
	end
	local t = math.clamp((distanceFromEntry - GATE_CLEAR) / (zoneLength - GATE_CLEAR), 0, 1)
	return rng:NextNumber() < FAR_MIN + (1 - FAR_MIN) * t
end
```

Players walking in through a gate now get a breath before the first fight, and difficulty rises as they cross the zone.

### Damage: a floor tied to player health

A play-test report: "enemies barely do damage". Cause: player max health was the held weapon's health stat (low thousands for a mid-tier weapon, several thousand higher up, tens of thousands at the top), while enemy hits stayed at the zone's table damage (a few dozen in mid zones, under a hundred later). Players needed 40 to 100+ hits to die (measured). The fix was a **hit floor**: an enemy hit deals at least a fraction of the target's max health, scaled by the attack's own multiplier, before block and armour.

```lua
--!strict
local HIT_FLOOR = { regular = 0.05, elite = 0.08, mega = 0.10, boss = 0.12 }

local function enemyHitDamage(rank: string, tableDamage: number, attackMult: number, targetMaxHp: number): number
	local floorFraction = HIT_FLOOR[rank] or HIT_FLOOR.regular
	return math.max(tableDamage, targetMaxHp * floorFraction) * attackMult
end
```

Tutorial enemies were exempt. The deeper lesson: when one side of combat scales with a stat (player health with gear) and the other does not, the combat breaks at some point on the curve. Decide what scales with what in the design. See [[Progression and Pacing Design]] and [[Balancing with Spreadsheets and Data]].

### Tempo

"Enemies should attack quicker when aggroed" became an aggro tempo layer: only while an enemy has a target, cooldowns x0.6, think gaps x0.4, follow-through faster, the first swing at most 0.4 to 0.7 seconds after reaching range, with softer multipliers for starter zones, elites and bosses; telegraphs and wind-ups unchanged so attacks stay readable. The change reported its own effect in attacks per minute per enemy (+6% to +41%) and flagged the one above the 40% guideline instead of silently shipping it (measured). Most of each attack cycle was clip length, so bigger gains would need faster clips, not shorter gaps. A single flag turned the layer off.

## The look rebuild: about fifty creatures in a day

At the end of the period the owner asked for every enemy in the first area to be replaced with larger, more intimidating designs. The pipeline made this a look-only change:

- Each of the **roughly fifty slots** (regulars, elites, megas, bosses) kept its **id, skeleton (bones and pivots), clips, AI role, zone and attacks**.
- New creatures were designed as Blender Python scripts on a shared helper library (three-tone colour ramps, a stud atlas, seam lines), rendered from three angles for a contact sheet, uploaded as packages, and installed with a tool that rebuilt the rig from a manifest and re-measured root and ground heights (and hover height for flyers).
- Fit error was 0.000 on every rig (measured). Previous models were kept as one copy and in version history.
- Triangle counts ran from about 10,000 to about 42,000 per creature (several meshes each, under the 20,000-per-mesh limit, Roblox docs). A preview outline was deliberately left out of the game meshes because it would double the triangles; seam lines and studs carried the look instead.

Two warnings from this step. First, the triangle counts were 3 to 7 times the original plan's budget for regulars; a look rebuild must re-run the budget. Second, the cloud save failed repeatedly the day it was installed (every save timed out and the place reopened at the previous day's version), so the install had to be redone and confirmed with a clean save.

## Performance of the roster

The client cost of enemies was mostly animation: a Lua keyframe player mixing joints per frame with distance-only LOD (every frame under 60 studs, every 2nd under 150, every 4th under 300), with no off-screen cull, plus per-frame foot IK within 140 studs and an elite effect loop with no distance check (measured in a performance audit). The planned fixes were an off-screen freeze (time advances, events fire, joints are not written) and distance checks on every per-enemy loop. See [[Animation LOD]] and [[Script Performance]].

The enemy clips themselves (well over a thousand across dozens of kits) were baked into compact stubs, cutting server storage from 1.96M to 712k instances (measured). See [[Baked Clip Stubs and Archiving]].

## Lessons

1. **Keep enemy definitions independent of the map.** The roster survived a deleted map because of it.
2. **Migrate with flags, zone by zone**, emitting the old reward format so the rest of the game does not notice.
3. **List side effects before migrating**: remotes, sounds, signals, analytics.
4. **Size by target height with clamps**, not by one multiplier.
5. **Tie enemy damage to player health** when player health scales with gear.
6. **Tune tempo, not telegraphs**, and report the measured effect.
7. **Separate identity from appearance** so a look rebuild keeps AI, clips and data.
8. **Re-run budgets after a redesign.**

## Common mistakes

- Building new features into a script at the size limit.
- A big-bang swap from old to new AI.
- Scaling every enemy by the same factor regardless of design.
- Forgetting that the player was scaled too.
- Tuning damage against a fixed health that later starts scaling.
- Swapping models by replacing rigs (and losing clips) instead of rebuilding the rig from a manifest.

## Checklist

- [ ] Roles and telegraph language defined before modelling.
- [ ] Enemy data, models and clips independent of level geometry.
- [ ] Zone-by-zone ownership flags; old path intact until the new one is play-tested.
- [ ] Side-effect inventory checked in the new system.
- [ ] Size targets with clamps; hit shapes scale with bodies.
- [ ] Damage floor or explicit scaling rule against player health.
- [ ] Spawn rules keep entry gates clear.
- [ ] Look rebuilds keep id, skeleton, clips, AI; budgets re-run.

## See also

- [[NPC AI and Behaviour]], [[Pathfinding]], [[Combat Systems Architecture]], [[Spawning Teams and Rounds]]
- [[Enemy and NPC Animation]], [[Creature Rig Conventions]], [[Animating Creatures and Monsters]], [[Procedural Death Knockdown and Hit Reactions]]
- [[Asset Pipelines]], [[Safe Changes in a Shared Place]]
- [[Post-Mortem - Building a Melee Action Game]], [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Combat and RPG]] · Boss Fight Design Patterns · Anticipation · Character and Creature Pipeline · Snippets - Enemy Client Animator · Hit Reactions Stagger and Hit-Stop
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Instance Cleanup and Place Size]] · [[Release Process and Rollbacks]] · [[Team Roles and Workflows]] · [[Case Study - Fast Join and Deferred Loading]] · [[Working with AI Assistants in Studio]] · [[Case Study - Phone UI Overhaul]] · [[Documentation and Knowledge Bases]] · [[Case Study - Building LihFolk V2 with AI Agents]]
<!-- related:end -->
