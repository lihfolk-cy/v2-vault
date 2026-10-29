---
tags: [level-design, combat, arena, encounters, enemy-spawning, pvp, cover, telegraphs, type/guide, area/world, level/intermediate, area/ui]
---
# Combat Arena and Encounter Layout

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Telegraph bigger than the escape distance -> `R <= speed * (warning - 0.25)` or add a dash
> - Avoid: Arena too large -> Keep the edge within about 3 telegraph radii
> - Avoid: Chest-high clutter -> Low cover or full cover, little in between
> - Combat numbers table written: speeds, dash, reach, telegraphs.
> - Every telegraph passes the dodge test or is a deliberate damage check.
> - Arena radius leaves dodge room but keeps the fight on one screen.
>
> Cost: TL;DR ~160 tok · whole note ~4.7k tok. Read more: ## 3. Where enemies come from · ## 4. Keeping fights in their space · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

[[Level Design for Roblox]] sets the basic rules for combat spaces: clamp enemies to a walk box, keep colliding props out of it, use invisible tagged combat floors, keep boss spawns clear, seal arenas during fights and keep the floor readable. [[Boss Fight Design Patterns]] covers the fight itself, and [[Genre Playbook - Battlegrounds and Arena Fighters]] covers PvP as a genre. This note sits between them: how to size a space from the combat numbers, where enemies should enter, how cover and verticality interact with the Roblox camera and with pathfinding, how to lay out a PvP arena so it stays fair, and how to stop fights from spilling out of their space.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (a live action game with zone enemies, bosses and a couple of arena modes), **computed**, **rule of thumb**.

## 1. Size the space from the combat numbers

An arena is the right size when the combat verbs fit in it with room to spare. Collect your numbers first:

| Number | Example value | Where it comes from |
|---|---|---|
| Walk / run speed | 16 studs/s default | Roblox docs (`CharacterWalkSpeed`) |
| Dash distance | 12 to 20 studs | Your combat design |
| Melee reach | 6 to 12 studs | Your hitboxes |
| Largest telegraph radius | 20 to 40 studs | Your boss attacks |
| Shortest telegraph warning | 0.6 to 1.2 s | Your boss attacks |
| Boss footprint | 10 to 30 studs | The model |
| Ranged enemy preferred distance | 30 to 60 studs | Your AI |

### The dodge test

A telegraphed area attack is fair only if a player standing at its centre can leave it in the warning time. With walk speed `s`, warning `t` and radius `R`, the escape needs `R <= s * t` (computed), plus reaction time. Human reaction to a visual cue is often quoted around 0.2 to 0.3 s (rule of thumb), so:

`R <= s * (t - 0.25)`

| Warning | Escapable radius at 16 studs/s | With a 16-stud dash |
|---|---|---|
| 0.6 s | about 5.6 studs | about 21 studs |
| 1.0 s | about 12 studs | about 28 studs |
| 1.5 s | about 20 studs | about 36 studs |

If your boss has a 30-stud slam with a 1-second warning and no dash exists, it is not dodgeable from the centre; it is a damage check. That may be intended. If not, lengthen the warning or shrink the radius.

### The arena radius

The arena must leave somewhere to dodge **to**. Rule of thumb:

`arena radius >= largest telegraph radius + boss footprint radius + 2 * dash distance`

With a 30-stud slam, a 10-stud boss half-width and a 16-stud dash, that is at least 72 studs. Measured in the reference project: the pop-up void arena template used a 100-stud radius floor, and the zone boss battleground a floor of radius 286. Both had room; the 286-stud arena was large enough that players lost the boss in the haze, which is the opposite failure. Rule of thumb: the far edge should stay within about 2.5 to 3 times the largest telegraph radius from the boss, so the fight stays on one screen.

### Height

Ceilings in enclosed arenas need room for jumps, knock-ups and the camera. Characters jump about 7 studs by default (Roblox docs); knock-up abilities often add 15 to 30. Rule of thumb: at least 30 studs of clear height over the fighting floor, more for big bosses, or the camera will push against the ceiling during every aerial attack.

## 2. Cover and obstacles

Cover is only worth placing if the combat design uses it: ranged enemies, projectiles, line-of-sight attacks. In a pure melee brawler, pillars mostly block the camera and catch players on corners.

Heights relative to the default (about 5-stud) character, rule of thumb:

| Height | Reads as | Effect |
|---|---|---|
| Under 2 studs | Kerb, step | Decoration; auto-stepped |
| 2.5 to 3.5 studs | Low cover | Blocks low projectiles, can be jumped, does not block the camera |
| 4 to 6 studs | Chest to head | Awkward: blocks aim, not jumpable without effort, blocks the camera when close |
| 7+ studs | Full cover | Breaks line of sight; the camera pulls in when the player hugs it |

Avoid the middle band unless it is a deliberate wall. Low cover and full cover read clearly; chest-high obstacles produce "I could not see" complaints on the third-person camera.

### Cover and the camera

The default camera zooms in when something sits between it and the character (the default occlusion behaviour, Roblox docs). A player backing up against full cover gets a sudden close-up. Two fixes:

- **Place full cover with open space behind the player's likely standing spots,** so the camera has room.
- **Keep thin cosmetic geometry out of the camera's way.** Which parts the default camera treats as occluders is an engine detail this note could not confirm in the docs, so do not rely on transparency or collision settings to make a banner "camera-proof". Test it: walk behind every banner, chain and canopy in the arena and watch the camera. If you need full control, a custom camera can filter its own occlusion raycast. See [[Camera Systems]].

Measured in the reference project: its arena layout rule kept anything taller than 8 studs out of the boss's **camera lanes** (the areas the boss intro camera and the player camera look through), and kept a box around the boss spawn clear of anything over 8 studs. Both rules exist because a single tall prop in the wrong place ruins the most important shot of the fight.

### Cover and pathfinding

Enemies that use `PathfindingService` see your cover as obstacles. A field of small pillars produces jittery paths, enemies hugging corners, and enemies stuck between pillars. Rules:

- **Keep gaps between obstacles either clearly passable or clearly blocked** for your enemy's agent radius. A gap just wider than the agent is the classic stuck point.
- **Use `PathfindingModifier`** (Roblox docs) to mark areas as costly or passable for agents without changing collision, for example to make enemies avoid hazard floors.
- **Big enemies need their own agent parameters** (radius and height), or they plan paths only small enemies can follow. See [[Pathfinding Edge Cases and Fallbacks]].

## 3. Where enemies come from

Enemy entry is the single biggest lever on how an encounter feels.

| Entry | Feel | Use for |
|---|---|---|
| Already present, idle | Planning, ambush by the player | Zone enemies, stealth |
| Visible spawn (portal, ground burst) | Readable, fair | Waves, arenas, bosses |
| Out of view behind the player | Tense, sometimes unfair | Horror, elites, rare surprises |
| From a door or tunnel | Directional, predictable | Defence and wave modes |
| Dropping from above | Dramatic, hard to read on the camera | Bosses, one-offs only |

### Rules for spawn points (rule of thumb, several measured)

- **Never spawn inside melee reach of a player.** An enemy that appears and hits in the same second feels like a bug. Minimum spawn distance should exceed your enemies' aggro-to-attack time times their speed, plus melee reach.
- **Prefer spawns just outside the player's view, then let enemies walk in.** That reads as "they arrived" rather than "they popped".
- **Keep enemy spawns away from player spawns and tutorial landings.** Measured in the reference project: the spawner never placed enemy groups within 140 studs of the tutorial landing.
- **Spread entries.** One entry for every enemy creates a conga line; three or four entries around the arena create pressure from directions the player can still track.

A spawn picker that respects these rules:

```lua
--!strict
-- Server: choose an enemy spawn point that is far enough from every player, and
-- preferably outside every player's forward view cone.
local Players = game:GetService("Players")

local MIN_DISTANCE = 35 -- studs from any player
local VIEW_COS = math.cos(math.rad(60)) -- treat 60 degrees either side of facing as "in view"

local function scorePoint(point: Vector3): number?
	local score = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local offset = point - root.Position
			local distance = offset.Magnitude
			if distance < MIN_DISTANCE then
				return nil -- too close to someone: never use
			end
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local look = root.CFrame.LookVector
			local facing = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0 and facing.Magnitude > 0 then
				local dot = flat.Unit:Dot(facing.Unit)
				if dot < VIEW_COS then
					score += 1 -- outside this player's view cone: good
				end
			end
			score += math.min(distance, 120) / 120 -- mildly prefer farther points
		end
	end
	return score
end

-- points: Attachments or parts placed by the level designer, tagged per arena.
local function pickSpawn(points: { BasePart }): BasePart?
	local best: BasePart? = nil
	local bestScore = -math.huge
	for _, p in points do
		local s = scorePoint(p.Position)
		if s and s > bestScore then
			best, bestScore = p, s
		end
	end
	return best
end

return pickSpawn
```

The character's facing is a proxy for the camera's facing. For a stricter test you would need each client's camera, which the server does not have; facing is close enough for third-person games where players mostly run forward.

### Waves

Waves are level design over time. Rules of thumb:

- **Each wave uses a different subset of entries**, so the player turns to face the new threat.
- **Overlap waves slightly.** Spawn the next wave when the current one is down to about a quarter, not when it is empty; the dead time between waves is where players lose interest.
- **Cap concurrent enemies by what the player can track,** not by what the server can run. Five to eight melee enemies around one player is already chaos on a phone screen.
- **Introduce a new enemy type alone** first, then in mixed waves. That is teaching, covered in [[Teaching Through Level Design]].

## 4. Keeping fights in their space

Fights spill out: enemies chase players across zones, knockback launches players off cliffs, bosses walk out of their arena. Plan containment.

| Problem | Containment |
|---|---|
| Enemies chase forever | Leash: return to their area and reset after leaving the walk box by a margin |
| Players kite bosses out | Arena seal (server-owned walls during the fight) or boss leash with heal-on-reset |
| Knockback over edges | Raised lips or invisible walls at edges inside combat zones; fall catch below |
| Players fall through floors | Fall guard: put them back on their last safe spot |
| Enemies stuck on decoration | Non-colliding decoration inside walk boxes |

Measured in the reference project:

- Each zone stored its enemy walk box as attributes (`EnemyWalkCenter`, `EnemyWalkHalfSize`) and enemies were clamped to it.
- The void arena template shipped with a wall, a ceiling, four player spawns, a boss spawn and a **fall catch** below the floor, so nothing escaped by falling.
- A server fall guard tracked each player's last grounded spot every 0.25 s and returned them there if they fell too far below it. It had to be narrowed because legitimate boss knock-ups and long drops in the realm tripped it. See [[Spawn Points Safe Zones and Respawn Flow]] for the full design.

### The seal

An arena seal is easy to get wrong because it changes collision for everyone. Rules:

- **Seal only when every participant is inside.** Check positions server-side before raising walls, or teleport stragglers in; never trap a player half in a wall.
- **Make the seal visible** (a barrier effect), not only collision. Invisible walls in a fight read as bugs.
- **Unseal on every exit path**: boss dead, all players dead, all players left, timer expired, server error. A seal that never opens strands players.

```lua
--!strict
-- Server: raise and lower an arena seal safely. The seal is a folder of wall parts kept
-- in ServerStorage and parented into the arena during the fight.
local ServerStorage = game:GetService("ServerStorage")

local Seal = {}
Seal.__index = Seal

export type Seal = typeof(setmetatable({} :: { template: Folder, live: Folder? , arena: Model }, Seal))

function Seal.new(arena: Model, template: Folder): Seal
	return setmetatable({ template = template, live = nil, arena = arena }, Seal)
end

function Seal.raise(self: Seal)
	if self.live then return end
	local walls = self.template:Clone()
	walls.Name = "LiveSeal"
	walls.Parent = self.arena
	self.live = walls
end

function Seal.lower(self: Seal)
	if self.live then
		self.live:Destroy()
		self.live = nil
	end
end

return Seal
```

Wrap the fight in a function that always calls `lower` (for example in a `pcall` around the fight loop with `lower` after it), so an error mid-fight cannot leave the seal up.

## 5. Readability inside the arena

- **Floor contrast for telegraphs.** Telegraph decals and parts must read against the floor at all graphics levels. A busy mosaic floor or a bright emissive floor hides red circles. Test the telegraph colour on the actual floor material in the arena's lighting.
- **Lighting focus.** Light the fighting floor more than its surroundings so attention stays inside. See [[Stylized Lighting Recipes]].
- **Silhouette separation.** The boss and the enemies should not share a colour with the arena walls.
- **Effects budget.** Arenas concentrate VFX from every player. Keep ambient arena effects light so ability effects stay readable, and see [[VFX Performance Budgets and Culling]].

## 6. PvP arenas

PvP adds one rule above all others: **no position should be strictly better than its mirror**.

- **Symmetry.** Rotational symmetry (the arena looks the same rotated by 180 or 90 degrees) is the safest choice for free-for-all; mirror symmetry suits two teams. Asymmetric arenas are possible but need data to balance.
- **Sightline parity.** Every long sightline should have a matching one. A single high ledge with a view over the whole arena becomes the only place anyone wants to stand.
- **Spawn alcoves.** Players spawn in alcoves around the edge, out of the main sightlines, with a short protected exit. Measured in the reference project: the PvP colosseum used 8 spawn alcoves; after a knock-out (3 s) the player respawned at an alcove picked at the moment of death, kept unless another player stood within 24 studs, with a 2-second [[ForceField]]. Kill rewards had an anti-farm cap of 2 per victim per minute, because spawn layouts are what make farming possible.
- **No spawn sightlines.** No alcove exit should be visible from another alcove or from the centre's best position, or spawn camping follows.
- **Edges.** Ring-out deaths are fun only if they are intended. Unintended ones are knockback plus missing walls; use lips or invisible walls at the edge and a fall catch.

## 7. Encounter density across a zone

Outside arenas, zones carry ambient encounters. Rules of thumb:

- **Encounters at walking intervals.** At 16 studs/s, an encounter every 150 to 300 studs gives a fight every 10 to 20 seconds of travel. Longer gaps are only acceptable with something else to look at.
- **Leave quiet space around gates, shops and spawns.** Players need somewhere to stop.
- **Group enemies, do not spray them.** Three groups of four read better than twelve singles scattered across the zone, and groups make use of the arena space.
- **Wake and sleep areas near players only.** See [[Spawning Teams and Rounds]] for waking areas and caps.

## 8. When not to do this

- **Hack-and-slash crowd games** may want huge open floors with no cover at all; the rules on cover do not apply.
- **Horror** may want enemies to appear out of view and close; the minimum spawn distance becomes a scare dial instead of a fairness rule.
- **Physics sandboxes** where the arena itself is destructible need different containment (see [[Destruction and Fracture]]).

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Telegraph bigger than the escape distance | "Undodgeable" complaints | `R <= speed * (warning - 0.25)` or add a dash |
| Arena too large | Players lose the boss in haze | Keep the edge within about 3 telegraph radii |
| Chest-high clutter | Camera jumps, blocked aim | Low cover or full cover, little in between |
| Tall props in camera lanes | Ruined intro shots and boss views | Keep 8+ stud props out of camera lanes |
| Gaps barely wider than enemies | Enemies stuck between pillars | Clearly passable or clearly blocked gaps |
| Enemies spawn in melee range | Instant hits on spawn | Minimum spawn distance, outside view |
| Seal raised with players outside | Players trapped in walls | Check positions first; always unseal |
| PvP spawns in sightlines | Spawn camping | Alcoves out of sightlines, safe spot choice |

## 10. Checklist

- [ ] Combat numbers table written: speeds, dash, reach, telegraphs.
- [ ] Every telegraph passes the dodge test or is a deliberate damage check.
- [ ] Arena radius leaves dodge room but keeps the fight on one screen.
- [ ] At least 30 studs of clear height over the fighting floor.
- [ ] Cover heights low or full; camera room behind standing spots.
- [ ] Pathfinding gaps clearly passable or blocked; big enemies have their own agent size.
- [ ] Enemy spawns: minimum distance, outside view, spread entries.
- [ ] Containment: leash, seal with guaranteed unseal, edge lips, fall catch.
- [ ] Telegraph colours tested on the real floor and lighting at low quality.
- [ ] PvP: symmetric sightlines, alcove spawns out of view, anti-farm on kill rewards.

## See also

- [[Level Design Start Here]], [[Level Design for Roblox]], [[Boss Fight Design Patterns]].
- [[Genre Playbook - Battlegrounds and Arena Fighters]], [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]].
- [[NPC AI and Behaviour]], [[Pathfinding]], [[Pathfinding Edge Cases and Fallbacks]], [[Spawning Teams and Rounds]].
- [[Spawn Points Safe Zones and Respawn Flow]], [[Level Design Principles - Flow Sightlines and Landmarks]].

## Connected notes
<!-- auto-links:start -->
[[Anticipation]] · Genre Playbook - Combat and RPG · Boss Animation and Phases · Dungeon and Room Generation · Horror Monster Chase AI End to End · Case Study - Enemy Roster Rebuild
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Genre Playbook - Combat and RPG]] · [[Playtest Heatmaps - Position and Death Maps]] · [[Obby and Platforming Level Design]] · [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]] · [[Lobby and Hub Design]] · [[Boss Animation and Phases]]
<!-- related:end -->
