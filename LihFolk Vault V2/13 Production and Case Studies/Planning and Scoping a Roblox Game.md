---
tags: [production, planning, scope, roadmap, budgets, case-study, type/case-study, area/production, level/intermediate, area/monetization]
---
# Planning and Scoping a Roblox Game

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Planning content without a content unit.
> - Avoid: Building volume before the style gate. Hundreds of assets in a rejected style.
> - Avoid: Deleting the old version before the new one is approved.
> - The 30-second, 5-minute and session loops are written in one paragraph each.
> - The content unit is defined and counted; the launch set is a number.
> - Shared parts (rigs, kits, materials) are identified before production.
>
> Cost: TL;DR ~150 tok · whole note ~4.8k tok. Read more: ## Count the content before you build it · ## Phases with gates · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox projects do not fail because a system is hard to build. They fail because the project keeps changing what it is: the map is rebuilt three times, the progression model is replaced twice, and the content that already exists has to be dragged through every change. This note is about the planning layer above the code: how to decide what the game is, how big it is, what "done" means for each piece, and how to change your mind cheaply when (not if) you do.

The examples come from one production game (the reference project): a live action game with zones of enemies, gear upgrades and bosses. It was built over a few weeks of very fast iteration, and its history is a near-complete catalogue of scoping mistakes and recoveries. Numbers are labelled "measured in the reference project", "Roblox docs" or "rule of thumb".

## What a plan has to answer

A useful plan is short. It answers six questions, in this order, and each answer constrains the next.

| Question | Why it comes first | Example answer |
|---|---|---|
| What is the 30-second loop? | Everything else feeds it | Roll a weapon, hit enemies, collect cash and materials |
| What is the 5 to 10 minute loop? | It decides your economy and UI | Spend on upgrades until your power passes the next gate |
| What is the session goal? | It decides content volume | Open one new zone, or beat one boss |
| What is the long-term hook? | It decides how much content you need at launch | Rarer weapons, new realms, rebirths |
| What is the content unit? | It makes scope countable | A zone = map strip + 2 enemy types + elite + a gate |
| What is the budget per unit? | It makes performance a design input | Instances, triangles, emitters, lights per zone |

The first four are design ([[Core Loops and Session Design]], [[Progression and Pacing Design]]). The last two are production, and they are the ones teams skip. Without a content unit you cannot estimate; without a budget per unit you discover performance problems only after the content exists. See [[Art Budgets - Triangles Draw Calls Memory]] and [[Performance Fundamentals]].

## Count the content before you build it

The single most useful planning habit is turning a vision into a count. The reference project's revamp plan did this well: "2 regular enemy types + 1 mini-boss per zone, one boss per world, 16 zones" became an explicit number: **32 regulars + 14 mini-bosses + 2 world bosses = 48 designs**. With a count you can ask the right questions:

- **How long is one unit?** In the reference project, adding one finished, animated weapon through a mature pipeline took about 1 to 1.5 hours, most of it the move-set design and the arm-animation bake (measured). An enemy with model, rig, about 17 clips and AI data was far more.
- **What can be shared?** The same plan proposed one base rig per body type (biped, quadruped, flyer, crawler, floater, swimmer), so 48 designs needed 6 rigs, not 48. Each design differs in mesh, texture and moves.
- **What is the minimum launch set?** The zone-ladder plan launched 30 zones and grew to 60 later, building half of the later regions as variants of earlier maps.

A count also exposes when scope is silently growing. The reference project went from 2 worlds with 16 zones, to a proposal of 60 zones in 6 regions, to "Six Realms" of 10 zones each, within about 48 hours (measured, project changelog). Every one of those was a reasonable idea. Together they meant nothing was finished.

### A planning spreadsheet that works

Rule of thumb: one row per content unit, one column per production step, and the cell holds a status, not a description.

| Unit | Design | Model | Rig | Clips | Data | In game | Edit-verified | Play-tested |
|---|---|---|---|---|---|---|---|---|
| Zone 1 regular A | done | done | done | 17/17 | done | yes | yes | no |
| Zone 1 regular B | done | done | done | 12/17 | done | stand-in | yes | no |
| Zone 1 mini-boss | done | in progress | - | - | draft | - | - | - |

Two columns matter more than they look. "In game" separates assets that exist on disk from assets that are wired in. "Play-tested" separates "it compiles and looks right in Edit" from "a human played it". The reference project ended its first month with a standing note: "Nothing since day 14 is play-tested: assume every system needs the user's playtest." That is a planning failure, not a testing failure: verification capacity was never scheduled. See [[QA Checklists Before Release]].

## Phases with gates

A phase plan is only useful if each phase ends with a gate that can fail. The revamp plan in the reference project had a good shape:

| Phase | Deliverable | Gate |
|---|---|---|
| 0 | Style kit: palette, painted atlas, rock / tree / prop kit, one test enemy | Owner approves the style |
| 1 | Places, teleport, config modules, quality-scaling skeleton | A teleport round trip with save works |
| 2 | Combat core, enemy service, one enemy of each role in a test arena | Owner play-tests the feel |
| 3 | One zone fully finished (map, enemies, mini-boss, rewards, lighting) | Owner approves the vertical slice |
| 4 | Remaining zones of world 1 and its boss | Per-zone check |
| 5 to 8 | Hub, world 2, locomotion and swing animations, economy and performance pass | Final play-test, then swap live |

Why this shape works:

1. **Style before volume.** Phase 0 makes one of everything. If the art direction is rejected after 300 props exist, you lose 300 props. In the reference project a procedurally generated hub kit was built, swapped live, judged "low-detail and pixelated" next to the hand-painted hub it replaced, and reverted the same day (measured). A one-prop style gate would have cost an hour.
2. **Feel before content.** Phase 2 tests combat with one enemy per role. Combat feel problems (damage too low, enemies too slow to attack, hit ranges wrong for scaled characters) are cheap to fix with 5 enemies and expensive with 50.
3. **A vertical slice is the real estimate.** Phase 3 finishes one zone completely. The time it takes, multiplied by the zone count, is your schedule. Any other estimate is a guess.
4. **Build alongside, swap on approval.** New content is built in a staging area (a separate folder, or a separate place) while the live game is untouched. The swap is one small, reversible operation. See [[Safe Changes in a Shared Place]] and [[Release Process and Rollbacks]].

### When the gate is skipped

The same project shows what happens when gates are skipped. A full new map ("Realm I" of a six-realm plan) was built in staging over a day and a half: terrain, 339 cliff and 677 tree blockouts, 11 landmark files, 18 regular enemies and 2 bosses modelled, rigged and animated with about 350 clips. It was then rebuilt shorter, and then the owner deleted the staging map entirely and kept the original map (measured). The enemies survived because they were data plus models, independent of the map, and were later moved onto the original zones. The map work was lost.

The lesson is not "never explore". It is: **separate the parts of a plan that are reusable regardless of the map (enemies, combat, UI, economy) from the parts that are not (terrain, landmarks), and build the reusable parts first.**

## Scope reversals: plan for them

The reference project's map direction changed at least six times in four weeks:

| Change | What survived | What was lost |
|---|---|---|
| World 2 (water realm) built, rebuilt, then deleted | The progression config, renamed for a future realm | All world 2 terrain, 4 enemy families, about 19,200 instances |
| 60-zone ladder planned | The single "zone N" progression idea | Most of the map plan |
| Six-realm staging map built then deleted | All enemy models, data and clips | The staging terrain and landmarks |
| Hub replaced by a new hub, then reverted | The station scripts (same hook names) | The new hub's art |
| "Stage corridor" redesign (50 linear stages, lobby, training dummies) built, then reverted | HUD grid, currencies, shop work, fonts, sounds | The corridor art, travel scripts, weather looks |
| Realm I zones shrunk to 40% length, then the shrink undone | Nothing needed to survive; the undo record restored it exactly | A day of work, and one recovery from autosave |

Two practices made the reversals survivable:

- **Contracts by name.** The replacement hub kept the same folder path and hook names as the old one, so every script that found stations by name kept working, and so did the revert. A plan should name the contract (paths, attribute names, remote names) that content must keep, so content can be swapped without code changes.
- **Exact undo data.** The zone shrink stored every moved instance's original CFrame (and sizes) as attributes plus a terrain backup, so "undo the shrink" was mechanical. See [[Safe Changes in a Shared Place]].

And one practice made them expensive: deleting before the replacement was approved. When a hub was replaced, the old one (4,531 instances) was deleted, so the revert had to open an older place version in a second Studio window and copy one folder back. Rule of thumb: **delete the old version only after the new one has been play-tested and approved, and only as the last step of the swap.** The corridor plan got this right: "Old map deletion is the LAST step."

## Budgets are planning inputs

Performance budgets belong in the plan because they change what you design. The reference project's plan set per-zone budgets for a "balanced" quality target:

| Budget | Value (reference project plan) | Notes |
|---|---|---|
| Instances per zone | 6,000 | Includes dressing, not enemies |
| Live particle emitters per zone | 40 | Enemy and ability VFX are extra |
| Lights per zone | 12, of which 2 cast shadows | |
| Landmark meshes | up to 10,000 triangles | Regular enemies later ran 10,000 to 42,000 (measured), well over plan |
| Enemy models | 3,000 to 6,000 triangles regulars, 10,000 to 15,000 bosses | Planned, not achieved |
| Ability kit folder | 2,500 instances | Several kits ran 3,000 to 5,400 (measured) |
| Texture | one 2K painted atlas per biome | |

The table also shows the common failure: budgets that are written down and never checked. The enemy triangle counts drifted 3 to 7 times past plan because a later redesign asked for "bigger, more intimidating" creatures and nobody re-ran the budget. Make budgets checkable with a script and run it at each gate.

```lua
--!strict
-- Command bar: report each zone folder against its instance budget.
-- Assumes zones live under one folder; adjust the path for your place.
local ZONE_ROOT = workspace:FindFirstChild("Zones")
local BUDGET = { instances = 6000, emitters = 40, lights = 12 }

if ZONE_ROOT then
	for _, zone in ZONE_ROOT:GetChildren() do
		local instances, emitters, lights, shadowLights = 0, 0, 0, 0
		for _, d in zone:GetDescendants() do
			instances += 1
			if d:IsA("ParticleEmitter") then
				emitters += 1
			elseif d:IsA("Light") then
				lights += 1
				if d.Shadows then shadowLights += 1 end
			end
		end
		local flags = {}
		if instances > BUDGET.instances then table.insert(flags, "INSTANCES") end
		if emitters > BUDGET.emitters then table.insert(flags, "EMITTERS") end
		if lights > BUDGET.lights then table.insert(flags, "LIGHTS") end
		print(string.format("%-28s inst %6d  emit %3d  lights %2d (%d shadow)  %s",
			zone.Name, instances, emitters, lights, shadowLights, table.concat(flags, " ")))
	end
end
```

`Light` is the abstract base class of `PointLight`, `SpotLight` and `SurfaceLight`, so `IsA("Light")` catches all three (Roblox docs).

## The owner's decisions are part of the plan

On a small team, one person (the owner, designer or lead) decides taste. Every plan has questions only that person can answer, and they block work. The reference project kept a **Pending Decisions** table: number, decision, context, notes. At one point it held 19 open items, from "scale bosses?" to "set product ids in the dashboard" to "delete this 511,882-instance backup folder". Two observations:

- **Ask early, in batches.** A 30-question questionnaire answered in one sitting (scope, look, enemies, animation, economy, rollout) produced a plan that held for the parts that were asked. The parts that were not asked (map size, how long zones should take to cross) were the parts that changed later.
- **Record the answer with the reason.** "Enemies 30% smaller" without the reason ("after making them 2.3x bigger the same day") invites the next person to make them bigger again. The reference project's enemy scale went 2.3x, then 1.61, then 1.6x a different base, then 2.1, with size targets added later (measured). See [[Case Study - Enemy Roster Rebuild]].

## Pacing assumptions are scope

How long a zone takes to cross, how many hits an enemy takes, how many minutes of income a gate costs: these are design numbers, but they also decide how much content you need. The reference project's numbers moved a lot:

- Zones were shrunk to 40% length because the runs felt too long, then restored the same day because the owner wanted larger zones. A later change shrank only the starting zone, cutting the portal-to-first-gate walk from about 460 to about 227 studs (measured).
- A difficulty pass made progression about 2x slower: about 2.5x power between rarity tiers, enemy health x1.8, damage x1.35, cash x0.55, gate prices roughly doubled, and a full save wipe (measured). The upgrade costs were later re-priced as "minutes of income at the zone that unlocks them" (ring 1 about 1 to 2 minutes, capstones about 1 to 2 hours), which is the right way to express them because it survives economy changes.
- After a playtest showed players quitting at boss fights, a whole new structure (a linear stage corridor) was planned and built in a day, then reverted.

The lesson: **write pacing targets as player time** ("zone 1 takes 2 to 3 minutes, a boss wall takes one forge level to pass") and derive studs, health and prices from them. Then a change of mind is a change of one target, not a rebuild. See [[Balancing with Spreadsheets and Data]] and [[Economies and Currencies]].

## Choosing the place architecture

The plan must decide early whether the game is one place or several, because it is expensive to change later.

| Option | Pros | Cons |
|---|---|---|
| One place, all content | Simple saves, no teleports, everything shares one server | Everything replicates to every client unless you stream or defer; join time grows with content |
| Hub place + one place per world | Each place loads only its content; natural performance boundary | Teleports, cross-place data, more publishing; testing a full loop is harder |
| One place with streaming and deferred loading | One codebase, content arrives as needed | Streaming settings must be set in Studio, code must tolerate missing instances |

The reference project's revamp brief asked for separate places per world "for performance", but the team stayed in one place and later fought join time with streaming and deferred loading instead. Both are valid; the cost was not deciding, so the place kept growing with every added realm until join time and Studio performance forced a cleanup. See [[Teleporting and Multi-Place Games]], [[Instance Streaming]] and [[Case Study - Fast Join and Deferred Loading]].

## Risks worth writing down

A plan should have a risk list with a mitigation for each. From the reference project:

| Risk | What happened | Mitigation |
|---|---|---|
| Very large job, limited time or budget | Map rebuilt several times | Phase gates; a log at the end of each phase so anyone can continue |
| Animations need publishing to the owner's account | Hundreds of clips stayed Studio-only for weeks | Prepare files early; schedule the publish step; see [[Publishing Animations]] |
| Existing systems depend on the old combat API | 100+ ability kits needed an adapter | Adapter tested against a sample of kits before any swap |
| External tool must be running (3D tool bridge, local servers) | Work blocked when a tool was down | Write the manual fallback into the plan |
| Script size limits | Two core modules crossed the 200,000-character Source limit and could not be saved (measured) | Split big modules early; budget module size like any other resource |

## Common mistakes

- **Planning content without a content unit.** "A big world" cannot be estimated; "10 zones of the standard unit" can.
- **Building volume before the style gate.** Hundreds of assets in a rejected style.
- **Deleting the old version before the new one is approved.** Reverts become archaeology.
- **Budgets on paper only.** Write the check script and run it at each gate.
- **Pacing in studs and hit points instead of minutes.** Every economy change then needs a rebuild.
- **Treating "verified in Edit" as done.** Schedule play-tests the way you schedule building.
- **Letting several large redesigns overlap.** Finish or abandon one before starting the next.

## Checklist

- [ ] The 30-second, 5-minute and session loops are written in one paragraph each.
- [ ] The content unit is defined and counted; the launch set is a number.
- [ ] Shared parts (rigs, kits, materials) are identified before production.
- [ ] Each phase has a deliverable and a gate that can fail.
- [ ] Budgets per unit exist and a script checks them.
- [ ] Pacing targets are in player minutes.
- [ ] Contracts (paths, hook names, attributes, remotes) are named so content can be swapped.
- [ ] Old versions are deleted only after the new one is approved and play-tested.
- [ ] A Pending Decisions list exists and is reviewed with the owner regularly.
- [ ] A risk list has a mitigation per risk.

## See also

- [[Team Roles and Workflows]], [[Documentation and Knowledge Bases]], [[Release Process and Rollbacks]]
- [[Post-Mortem - Building a Melee Action Game]] for the full timeline these lessons come from
- [[Core Loops and Session Design]], [[Progression and Pacing Design]], [[Genre Playbook - RNG and Collection Games]]
- [[Project Structure and Bootstrapping]], [[Art Budgets - Triangles Draw Calls Memory]]
- [[Animation Quality Standard]] for a quality bar written as a checkable standard
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Roadmaps Milestones and Scope Control]] · [[Scoping and Roles for Small Teams]] · Genre Playbook - Combat and RPG · Level Design for Roblox · Environment and Level Pipeline · Progression Levels and Unlocks
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Instance Cleanup and Place Size]] · [[Working with AI Assistants in Studio]] · [[Asset Pipelines]] · [[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Template Reskin Checklist - One Codebase, New Game]] · [[Case Study - Phone UI Overhaul]] · [[Live Incident Response and Post-Mortems]]
<!-- related:end -->
