---
tags: [world-building, level-design, layout, hubs, zones, blockout, navigation]
---
# Level Design for Roblox

Level design on Roblox is shaped by things most engines do not have: players join mid-session on phones and controllers, the default camera floats behind the character, characters jump about 7 studs high and run 16 studs/s by default, maps stream in around the player, and a single place often holds a hub plus every zone of the game. This note covers measurement, the blockout process, hub and zone layout, sight lines and gating, combat spaces, and the production lessons of one production game that built and rebuilt a hub and a ten-zone realm several times.

## Know your measurements first

Everything in a level is relative to the character and the camera. Default values (Roblox defaults; your game may change them):

| Quantity | Default | Why it matters |
|---|---|---|
| Character height (R15) | about 5 studs | Door, ceiling and step sizes |
| `Humanoid.WalkSpeed` | 16 studs/s | Walking time between points |
| `Humanoid.JumpPower` / `JumpHeight` | 50 / 7.2 studs | Max jump-up ledge, gap sizes |
| `Humanoid.MaxSlopeAngle` | 89 degrees | Walkable slopes |
| Step climbing | small ledges auto-climbed | Steps 1 stud high feel smooth |
| Camera max zoom | 400 studs (default `CameraMaxZoomDistance`) | How much the player can see at once |

Characters in the reference project were scaled to about 9 studs and enemies to a 13-stud target, so all of its numbers below are bigger than default-character games. **Write your own measurement table on day one** and put a reference character in every blockout.

### Traversal time is the real distance

Players feel time, not studs. At 16 studs/s:
- 100 studs = 6 s.
- 460 studs = about 29 s. One production game halved its portal-to-first-gate walk from about 460 to about 227 studs because new players were bored before their first fight.
- 624-stud zones (that project's zone length) = about 39 s end to end at default speed.

But "shorter" is not automatically better. The same project shrank its realm's zones by 60 percent because players "run for too long", then **reverted the shrink the same day**: the owner preferred the longer zones of the second realm once he saw them side by side. Lesson: compare against an existing space players already like, not against a number.

```lua
--!strict
-- Print walk times between named markers (Parts in a folder) at a given speed.
local function walkTimes(markers: Folder, speed: number)
	local list = markers:GetChildren()
	table.sort(list, function(a, b) return a.Name < b.Name end)
	for i = 1, #list - 1 do
		local a, b = list[i], list[i + 1]
		if a:IsA("BasePart") and b:IsA("BasePart") then
			local d = (a.Position - b.Position).Magnitude
			print(("%s -> %s: %.0f studs, %.1f s"):format(a.Name, b.Name, d, d / speed))
		end
	end
end
```

Straight-line distance understates real paths; walk them in a playtest with a stopwatch too.

## Blockout first, always

A blockout is the level built from grey Parts with no art. It answers: is it fun, is it readable, is it the right size, can players get lost, where do enemies stand, where does the camera clip?

Rules that make blockouts useful:
- **Neutral colours per function.** Walkable floor one grey, walls another, hazards red, interactables yellow, enemy areas a translucent box. Players and testers read function, not art.
- **Name and attribute everything that art will replace.** `Blockout_<Module>` with a `Module` attribute and a bottom-centre pivot lets a script swap in meshes later (see [[Modeling in Blender for Roblox]]).
- **Mark intent with invisible markers.** One production game placed 90 invisible marker parts with attributes (`IntendedCount`, `IntendedScale`, `Replaces`) wherever a new model should go; the art pass filled and deleted markers, and a check listed any left over.
- **Playtest the blockout on a phone.** Distances, UI overlap and camera framing feel different on a small screen.

## Hub design

A hub (lobby) is where players spawn, return between runs, shop, socialise and choose where to go. It is visited more than any zone, so it is the most important space in the game.

### Layout patterns

| Pattern | Description | Works for |
|---|---|---|
| Radial plaza | Centrepiece in the middle, stations around a ring, exits on the rim | Simulators, RNG games, anything with 5 to 10 stations |
| Street | One spine with shops either side, destination at the end | Roleplay, town hubs |
| Courtyard + gates | Central open space, a wall of gates on one side | Games whose main action is "pick a world" |
| Vertical | Tiers stacked; progression unlocks higher tiers | Prestige-based games |

One production game's hubs were all radial: a centre "roll" monument on a tiered dais, a plaza of radius 100, a promenade ring, stations at angles around a 170 to 220-stud ring facing the centre, world gates grouped on one terrace, and leaderboards along the spawn avenue. Writing the layout as **polar coordinates** (angle clockwise from north, radius) made it trivial to rescale the whole hub (a later pass scaled it 1.4x and the centre tower 1.6x without re-placing anything by hand).

### Hub rules that held up

- **Spawn facing the main thing.** The player's first frame should show the centrepiece and at least one station, not a wall.
- **Every station visible from the spawn** or signposted from it. Titles above stations should share one typeface and style; a stray different-looking title was noticed and removed.
- **Interaction prompts close to the object**, not on a pad. That project removed its glowing "stand here" circles: "no circle, just E to interact".
- **Don't fight your own landmarks.** A tree keep-clear radius around stations (46 studs in that project) stopped foliage blocking signs and prompts.
- **Detail density, not size.** The owner's critiques were "feels incredibly cheap" and "bigger, cooler, more detail, match the image". The fixes that worked were real architectural detail on station shells, a taller centrepiece, sky dressing (floating isles, a ringed moon, castle spires) and consistent textures, not just scale.
- **Reversible swaps.** A rebuilt hub replaced a hand-built one of 4,531 instances; the owner preferred the old one and it was restored by copying it from an older place version opened in a second Studio window. Keep the old hub until the new one is approved in play.

## Zones and progression spaces

### Linear zone chains

Many Roblox games are a chain of zones separated by gates that unlock with currency or level. One production game's realm: ten zones of 624 studs along +X, a gate between each, each zone a different biome, the last a boss arena. A second realm climbed a volcano with the floor rising 38 studs per zone.

Design rules:
- **Each zone has one dominant colour and floor material** so players can tell where they are from a screenshot. (Terrain colours are global, so one material per zone was also a technical necessity; see [[Terrain Tools and Terrain API]].)
- **Each zone has a landmark** visible from its gate: a giant tree, a frozen crown, a downed mech, a mine entrance. Landmarks orient players and make screenshots recognisable.
- **The gate frames the next zone.** A themed arch per gate sells progression.

### Hiding locked zones and sight-line leaks

A locked zone should not be visible from the current one: it spoils the reveal and wastes rendering. Techniques:
- **Walls and canyon shoulders** on both sides of each gate. One production game added 11 gap-fill meshes beside gates after finding players could see the next zone around the gate, and verified **0 sight-line leaks** by ray tests.
- **Shadow shells**: dark volumes over locked zones that hide them until unlocked. If you move one for inspection, put it back.
- **Streaming radius** limits how far anything renders at all; see [[Level of Detail and Model Streaming]].

```lua
--!strict
-- Sight-line leak test: cast rays from a grid of eye points in zone A toward points in zone B.
-- Any ray reaching B without hitting a blocker is a leak. Blockers = everything except players.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}

local function leaks(eyeMin: Vector3, eyeMax: Vector3, target: BasePart, step: number): number
	local count = 0
	for x = eyeMin.X, eyeMax.X, step do
		for z = eyeMin.Z, eyeMax.Z, step do
			local eye = Vector3.new(x, eyeMin.Y, z)
			local dir = target.Position - eye
			local hit = workspace:Raycast(eye, dir, params)
			if hit and hit.Instance == target then
				count += 1
			end
		end
	end
	return count
end
-- Put a large invisible target part in the middle of the locked zone (CanQuery = true),
-- run leaks(...) from the current zone's walkable area at eye height, then remove the target.
```

That project ran 466 ray tests above the tallest new prop per zone after a dressing pass to confirm nothing let players walk or see out.

### Bounds

Invisible boundary walls stop players leaving the playable area. Keep them well outside visual edges (players notice invisible walls a stud from a cliff edge), and make them tall enough that jumping, flying abilities and knockback cannot clear them. One realm used 112 to 127 invisible boundary walls traced along its valley edges.

## Combat spaces

### Enemy areas

Enemies need a defined space. One production game gave each zone folder attributes `EnemyWalkCenter` and `EnemyWalkHalfSize` (a box) and clamped enemies to it. Level dressing then followed two rules:
- **Colliding props only outside the enemy box.** Inside it, decoration is non-colliding so enemies (and players) never snag.
- **Trunks and big colliders kept a margin** from the box (tree trunks outside the box plus the trunk radius plus 10 studs in that project).

Overlaps between enemy boxes and gate-shoulder rocks still slipped through in two zones; check boxes against walls after every dressing pass.

### Invisible combat floors

Visual ground is rarely a good collision floor for AI: terrain bumps, mesh seams, paving gaps and decorative steps all confuse ground checks. That project used **invisible, `CanQuery = true` floor parts** as the combat floor (named `<Zone>Ground`), and its enemy grounding code counted parts carrying a **CollectionService tag** (for example `EnemyFloor`) as valid ground (arena dais stones, plaza pavements). Visual paving above it could be anything. Details in [[Collision and Physics Geometry]] and [[NPC AI and Behaviour]].

### Arenas

- **Keep-out zones for bosses.** A boss spawn needs clear space; that project kept anything over 8 studs tall out of a box around its arena boss spawn.
- **Arena seals.** Fights can lock players in with server-owned invisible walls raised at fight start and removed after.
- **Readable floor.** Telegraphs (circles, cones) must be visible on the floor material; busy textures hide them.
- **Pillars and cover** only if the combat design uses them; otherwise they block camera and hits.

## Readability and guidance

- **Light and colour lead.** Brighter, warmer or more saturated areas pull players; dark areas push.
- **Paths are the cheapest guide.** A dirt path 20 to 34 studs wide down the middle of a zone (one project used a 34-stud path with a gentle sine meander) tells players where to go without signs.
- **Wayfinding beacons** (light pillars, floating icons) for objectives, hidden when irrelevant.
- **Silhouettes at distance.** Landmarks should be recognisable as black shapes against the sky.
- **Avoid visual clutter on walkable surfaces**: it hides hazards, drops and telegraphs.

## Process: passes, not one build

Large maps are built in **passes**, each in its own folder, each reversible. One production game's map folder had about 40 numbered pass folders (levels, zone dressing, canyon walls, biome props, lamps, scenery, leaderboards, zone FX, flowers, paths, lobby, map polish, gate frames, landmarks, per-zone polish passes). Benefits:
- You can hide one pass to see what it added.
- You can export a pass to a file before deleting it.
- Ownership is clear when several people work in one place.

Every bulk change stored its "before" state as attributes (old pivots, old colours) so it could be reverted by script, and backups were dated folders in `ServerStorage`, exported to disk and deleted when verified (see [[Case Study - Instance Cleanup and Place Size]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Building art before the blockout is fun | Expensive rework | Blockout and playtest first |
| Spawn facing a wall | Confused new players | Spawn facing the centrepiece |
| Long empty walks | Early quits | Time walks; add content or shorten |
| Visible locked zones | Spoiled reveals, wasted rendering | Walls, gap fills, shells, streaming |
| Colliding props in enemy areas | Enemies stuck, players snag | Non-colliding decor inside combat boxes |
| Visual ground as AI floor | Enemies float or sink | Invisible tagged floors |
| Invisible walls at the visual edge | Feels cheap | Bounds well outside the edge |
| One giant folder for the map | No ownership, no rollback | Numbered pass folders |

## Checklist

- [ ] Measurement table (character, jump, speed, camera) written down.
- [ ] Blockout playtested on PC and phone before art.
- [ ] Walk times measured and compared with a space players like.
- [ ] Spawn view shows the centrepiece and stations.
- [ ] Each zone: one dominant colour, one landmark, a themed gate.
- [ ] No sight-line leaks to locked zones (ray-tested).
- [ ] Enemy boxes clear of colliding props; combat floors invisible and tagged.
- [ ] Each pass in its own folder with reversible attributes.

## See also

- [[Environment Art Styles]], [[Foliage Props and Scatter]], [[Terrain Tools and Terrain API]], [[Collision and Physics Geometry]]
- [[Level of Detail and Model Streaming]], [[Procedural World Generation]]
- [[Core Loops and Session Design]], [[First-Time User Experience and Onboarding]], [[Progression and Pacing Design]], [[Genre Playbook - Obbies and Platformers]]
- [[NPC AI and Behaviour]], [[Pathfinding]], [[Spawning Teams and Rounds]], [[Camera Systems]]

## Connected notes
<!-- auto-links:start -->
[[Lobby and Hub Design]] · [[Environment and Level Pipeline]] · [[Level Design Principles - Flow Sightlines and Landmarks]] · [[Zone and Biome Art Direction]] · [[Level Design Start Here]] · [[Combat Arena and Encounter Layout]]
<!-- auto-links:end -->
