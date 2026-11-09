---
tags: [gameplay, ai, ranged, cover, line-of-sight, influence-map, shooters, npc, type/guide, area/gameplay, level/advanced, api/WorldRoot, api/CollectionService]
---
# Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Omniscient threat positions -> Score against perception memory
> - Avoid: Cover that blocks gameplay raycasts -> `CanQuery`, `CanCollide`, `CanTouch` off
> - Avoid: Evaluating every point every tick -> Spatial grid, few candidates, 1 to 2 s cadence
> - Cover points authored with facing, height, peek sides and capacity.
> - Points in a spatial grid; scoring uses perceived threats and raycasts with budget.
> - Influence map adds danger from players and recent NPC deaths.
>
> Cost: TL;DR ~160 tok · whole note ~2.3k tok. Read more: ## 1. Cover points are authored data · ## 2. Scoring a cover point · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A ranged enemy that stands in the open and shoots is a turret with legs. One that picks cover, peeks, shoots, ducks and relocates when flanked reads as intelligent with surprisingly little code, provided the level gives it data to work with. This note covers authored cover points, scoring them against threats with raycasts, a cheap influence map for danger, the peek-and-shoot loop and relocation rules, all server-side and budgeted. Aim quality is in [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]]; group coordination in [[Squad AI - Attack Tokens, Flanking and Attacker Limits]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Cover points are authored data

Automatic cover detection from geometry is possible but brittle and expensive. Author cover instead:

- Small invisible anchored parts tagged `Cover` (`CollectionService`), `CanCollide = false`, `CanQuery = false`, `CanTouch = false` so they never affect gameplay queries (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/BasePart#CanQuery).
- The part's `LookVector` points **toward the open side** (where enemies shoot from).
- Attributes: `Height` (`"Low"` crouch cover or `"High"` standing cover), `PeekSides` (`"L"`, `"R"`, `"LR"`, `"Over"` for low cover), `Capacity` (usually 1).
- A level-design pass places points every few studs along walls, crates and pillars in combat spaces ([[Combat Arena and Encounter Layout]]). A Studio plugin that sprays points along selected walls saves hours ([[Building a Studio Plugin End to End]]).

At server start, load all points into a spatial grid (cell size 32 studs, say) so queries only look at nearby points.

## 2. Scoring a cover point

For a ranged NPC with threats `T` (players it knows about, from its perception memory, not omniscience):

| Term | Test | Weight |
|---|---|---|
| **Protected** | Ray from each threat's head to the point at crouch height is blocked | Required (or large) |
| **Can shoot from peek** | Ray from the peek position (point offset sideways or up) to the threat's torso is clear | Large |
| **Distance to threat** | Inside the NPC's preferred range band | Medium |
| **Travel cost** | Distance from NPC to point; do not run across the open | Medium |
| **Facing** | Point's `LookVector` roughly toward the threat (dot > 0.3) | Small |
| **Danger** | Influence map value at the point (section 3) | Negative |
| **Occupied / reserved** | Another NPC holds it | Excluded |

Raycasts are cheap but not free. **Budget**: evaluate at most 6 to 10 candidate points per decision, decide every 1 to 2 s, and cap cover queries server-wide per tick (**Rule of thumb**). Use `Workspace:Raycast` with an exclude filter containing NPCs and characters except the target (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast).

```lua
--!strict
local Workspace = game:GetService("Workspace")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local CROUCH, STAND = 2.5, 5

local function clear(from: Vector3, to: Vector3): boolean
	return Workspace:Raycast(from, to - from, params) == nil
end

local function scoreCover(point: BasePart, npcPos: Vector3, threat: Vector3, range: NumberRange): number?
	local base = point.Position
	local hidden = not clear(threat, base + Vector3.new(0, CROUCH, 0))
	if not hidden then return nil end

	local sides = point:GetAttribute("PeekSides") :: string?
	local best = 0
	if sides then
		for side in string.gmatch(sides, "%a+") do
			local offset = if side == "L" then -point.CFrame.RightVector * 2.5
				elseif side == "R" then point.CFrame.RightVector * 2.5
				else Vector3.new(0, STAND - CROUCH, 0)
			if clear(base + offset + Vector3.new(0, CROUCH, 0), threat) then
				best = 1
				break
			end
		end
	end
	if best == 0 then return nil end -- safe but useless

	local d = (threat - base).Magnitude
	local rangeScore = if d >= range.Min and d <= range.Max then 1 else 0.3
	local travel = (base - npcPos).Magnitude
	return 2 * best + rangeScore - travel / 60
end
```

`params.FilterDescendantsInstances` should exclude NPC models and the cover parts' folder; set it once per tick, not per ray.

## 3. A lightweight influence map

Danger is where players have been shooting and standing. Keep a coarse grid (8 to 16-stud cells) over each arena:
- Add danger at each player's position and along their recent aim direction (a short line of cells), decaying every second.
- Add danger where NPCs were recently hit or killed.
- Cover points in high-danger cells are penalised, so enemies stop walking into the spot a player is camping.

This is a few hundred numbers per arena, updated at 2 to 4 Hz. It also feeds flank scoring (prefer low-danger approach routes).

## 4. The peek-and-shoot loop

States inside the NPC's `InCover` behaviour:

1. **Hide** (1 to 3 s, randomised): crouched or behind the wall. Reload here.
2. **Peek**: move to the peek offset; small delay (reaction time) before the first shot.
3. **Shoot**: a burst of N shots or until the target breaks line of sight. Aim error converging as usual.
4. **Return** to hide.

Rules that make it read well:
- **Do not peek the same side twice in a row** if both are available; players pre-aim.
- **Peek when the player is reloading or looking away** (player's look vector vs direction to NPC) on harder difficulties.
- **Suppression**: taking hits or near misses during Hide extends Hide; this rewards players who lay down fire.
- **Animation**: peek and lean poses or simple crouch/stand; even a CFrame offset of the upper torso sells it ([[Enemy and NPC Animation]]).

## 5. When to relocate

Leave cover when any of these is true (re-evaluated at decision cadence):
- **Flanked**: any threat now has a clear line to the NPC's hidden position.
- **Too close**: a threat inside minimum range (switch to retreat or melee).
- **Grenaded / in a hazard**: an explosion or area denial at the point ([[Explosions - Radius Damage, Falloff and Cover Checks]]).
- **Stale**: no valid peek shot for several cycles.
- **Ordered**: the squad coordinator wants it to advance or fall back.

Relocation should prefer a route along other cover (chain points by adjacency precomputed at load) and **reserve** the destination so two NPCs do not run to the same box.

## 6. Movement and ownership

Server-owned NPCs moving short distances to cover can use `Humanoid:MoveTo` or a mover-constraint controller ([[Mover Constraints and Physics Controllers]]). Keep network ownership on the server for combat NPCs so positions used for hit validation are authoritative ([[Network Ownership]]). For long relocations use pathfinding with fallbacks ([[Pathfinding Edge Cases and Fallbacks]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Omniscient threat positions | NPCs hide from players they could not know about | Score against perception memory |
| Cover that blocks gameplay raycasts | Bullets stop on invisible parts | `CanQuery`, `CanCollide`, `CanTouch` off |
| Evaluating every point every tick | Server frame spikes | Spatial grid, few candidates, 1 to 2 s cadence |
| Safe cover with no shot | Enemies hide forever | Require a clear peek line |
| No reservation | Two enemies stacked in one spot | Reserve and release points |
| Same peek rhythm | Players pre-aim and farm | Random hide time, alternate sides |

## Checklist
- [ ] Cover points authored with facing, height, peek sides and capacity.
- [ ] Points in a spatial grid; scoring uses perceived threats and raycasts with budget.
- [ ] Influence map adds danger from players and recent NPC deaths.
- [ ] Peek-shoot-hide loop with randomness, suppression and side alternation.
- [ ] Relocation on flank, proximity, hazard or staleness, with reservations.
- [ ] Cover scores visible in the debug overlay ([[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]).

## See also
[[NPC AI and Behaviour]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Combat Arena and Encounter Layout]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Behaviour Trees Utility AI and State Machines for NPCs]]

## Connected notes
<!-- auto-links:start -->
[[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Pathfinding]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Physics Assemblies and Constraints]] · [[Characters and Humanoids]] · [[Police Chases and Wanted Levels]] · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]]
<!-- related:end -->
