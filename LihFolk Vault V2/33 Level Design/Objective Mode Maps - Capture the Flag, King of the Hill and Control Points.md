---
tags: [level-design, pvp, objective-modes, capture-the-flag, king-of-the-hill, control-points, type/guide, area/level-design, level/intermediate, api/GetPartBoundsInBox, api/Teams, area/world]
---
# Objective Mode Maps - Capture the Flag, King of the Hill and Control Points

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hill on high ground -> Lower the zone; height on approaches
> - Avoid: Unequal route timing -> Measure and record per version
> - Avoid: Uncapped capture rate -> Cap counted players
> - Three lanes per objective; objective visible from each spawn exit.
> - Route times per team measured and within about 1 s.
> - Zone radius checked against crossing time at default walk speed.
>
> Cost: TL;DR ~140 tok · whole note ~2.4k tok. Read more: ## 2. Capture the Flag · ## 6. Server-side capture logic · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Team deathmatch maps only need to be fair. Objective maps also need to make the objective the most interesting place on the map, keep both teams arriving at it at the same time, and stop one team from locking the game in the first minute. This note covers layout rules for the three common objective modes, how to size capture zones, how to measure route timing instead of eyeballing it, and the server logic for capture that does not break with lag or exploits. General arena geometry (cover spacing, sightline length) is in [[Combat Arena and Encounter Layout]]; spawn safety in [[Spawn Points Safe Zones and Respawn Flow]].

Source labels: **Roblox docs**, **Rule of thumb** (experience, not a hard limit), **Measured** (when you measure it yourself, the method is given). Code is strict Luau, **reviewed, not run**.

---

## 1. Shared rules for all objective maps

- **Equal arrival time.** Each team's fastest route from spawn to each neutral objective should take the same time to within about 1 second (rule of thumb). Symmetric maps get this for free; asymmetric maps must be measured (section 5).
- **Three lanes.** A main lane (fast, exposed), a flank (slower, covered) and a third route (vertical, or through an interior). Two lanes produce stalemates; four or more on Roblox's typical 8 to 16 player servers spread players too thin to fight.
- **The objective is the landmark.** Light it, colour it in team-neutral accents, and make it visible from each spawn exit ([[Level Design Principles - Flow Sightlines and Landmarks]]).
- **No spawn sightline.** No objective or main lane should be visible from inside an enemy spawn's protected area.
- **Server size sets map size.** Rule of thumb: plan around one meaningful encounter every 10 to 20 seconds per player. Fewer players means shorter lanes, not just fewer spawns.
- **Mobile movement.** Phone players turn slower and jump less precisely. Avoid objectives that require precision parkour to reach.

## 2. Capture the Flag

Layout:

- Bases mirrored, with the flag deep enough that a runner must cross at least two defensive choke points, but not so deep that a return trip takes longer than about 45 to 60 seconds of uncontested running (rule of thumb).
- Give each base **two exits** for the carrier. One exit means a single defender camps the door.
- The midfield should have the best cover and the vertical routes; bases should be readable, not mazes.

Rules that matter on Roblox:

- **Carrier speed.** A small slowdown (around 5 to 10 percent) makes interception possible without making carrying miserable.
- **Dropped flag**: returns after a timer (10 to 20 s) or when touched by its own team. Respawn the flag on the server at the drop point, snapped to ground with a raycast, never inside a kill volume.
- **Carrier leaves the game** or falls out of the world: drop at last grounded position ([[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]]).
- **Vehicles**: decide explicitly whether carriers can drive. If they can, the map needs vehicle-blocking choke points or every capture becomes a drive-through.

## 3. King of the Hill (one moving or fixed point)

- One zone, contested by everyone. Place it on ground that is **slightly lower** than its surroundings on at least two sides, or it becomes a fortress held by whoever arrives first. Height advantage belongs to the attackers' approach, not to the hill itself.
- If the hill rotates between locations, every location must satisfy the equal-arrival rule from both spawns, and the next location should be announced 10 to 15 seconds early so teams rotate rather than teleport-fight.
- Cover inside the zone: enough that a player can survive standing in it for a few seconds, not enough to hold it alone.

## 4. Control Points (multiple zones)

- Three points (A, B, C) is the default. A and C near each team's side, B neutral and central. Two-point maps tend to see-saw; five points suit only large servers.
- Distance between adjacent points should allow a rotation in roughly 10 to 20 seconds of running. Longer and the losing team cannot recover; shorter and points flip constantly.
- Score by **points held per tick**, not by captures, so holding two of three wins slowly and comebacks remain possible.

## 5. Sizing zones and measuring routes

Capture zone size, rule of thumb:

| Zone | Radius / size | Notes |
|---|---|---|
| Small (1v1 to 3v3) | 8 to 12 stud radius | A few players inside should be easy to see |
| Medium (4v4 to 8v8) | 14 to 20 stud radius | Room to dodge inside |
| Large | Over 24 | Usually a mistake; teams hide at the edge |

Default character walk speed is 16 studs/s (Roblox docs, `Humanoid.WalkSpeed` default), so a 20-stud radius takes about 2.5 s to cross. Use that to sanity check.

**Measure route timing**: in a Studio play test, record `os.clock()` when leaving spawn and on entering the zone, for each lane, at default speed, three runs each. Or compute path lengths with `PathfindingService:CreatePath()` and `ComputeAsync` from each spawn to each point and compare `#waypoints` distance sums (see [[Pathfinding]]). Pathfinding distance ignores jumps that players take, so it is a lower-quality but repeatable check. Record results in a table per map version; layout tweaks silently break fairness.

## 6. Server-side capture logic

```lua
--!strict
-- Server: control point ticking at 4 Hz. Membership by distance from root, alive only.
local Players = game:GetService("Players")

type Point = { id: string, centre: Vector3, radius: number, owner: Team?, progress: number }

local CAPTURE_SECONDS = 8
local TICK = 0.25

local function countInside(point: Point): { [Team]: number }
	local counts: { [Team]: number } = {}
	for _, player in Players:GetPlayers() do
		local team = player.Team
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if team and humanoid and humanoid.Health > 0 and root then
			local offset = root.Position - point.centre
			-- Cylinder test: horizontal radius, limited height.
			if Vector2.new(offset.X, offset.Z).Magnitude <= point.radius and math.abs(offset.Y) <= 12 then
				counts[team] = (counts[team] or 0) + 1
			end
		end
	end
	return counts
end

local function tickPoint(point: Point)
	local counts = countInside(point)
	local leader: Team? = nil
	local teamsPresent = 0
	for team in counts do
		teamsPresent += 1
		leader = team
	end
	if teamsPresent ~= 1 or leader == nil then
		return -- empty or contested: no progress (decay optional)
	end
	if leader == point.owner then
		point.progress = 1
		return
	end
	local rate = math.min(counts[leader], 3) / CAPTURE_SECONDS -- cap multi-player bonus at 3
	point.progress -= rate * TICK
	if point.progress <= 0 then
		point.owner = leader
		point.progress = 0 -- now climbs back to 1 for the new owner
	end
end
```

- Membership is computed on the server from character positions. Never accept "I am on the point" from a client.
- Cap the multi-player capture bonus; otherwise a full team on a point captures in under a second.
- Contested means frozen. Whether progress decays when empty is a design choice; decide it once for all points.
- Replicate state as attributes on a point folder (`Owner`, `Progress`) for UI; clients render, server decides.
- Ignore players in vehicles or seated if your design says so; check `humanoid.SeatPart`.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Hill on high ground | First team to arrive holds it all game | Lower the zone; height on approaches |
| Unequal route timing | One team always wins B | Measure and record per version |
| Uncapped capture rate | Points flip instantly to stacks | Cap counted players |
| Flag drops inside a wall or kill volume | Flag lost; match stuck | Raycast-snapped drop, OOB fallback |
| Single base exit | Spawn camping the carrier | Two exits per base |
| Client-reported capture | Exploiters capture from spawn | Server membership test |
| Zones too big | Teams hide at the edge | Size from the table, check crossing time |

## Checklist

- [ ] Three lanes per objective; objective visible from each spawn exit.
- [ ] Route times per team measured and within about 1 s.
- [ ] Zone radius checked against crossing time at default walk speed.
- [ ] Capture logic server-side, alive players only, capped bonus, contested freezes.
- [ ] Flag drop, return and carrier-leaves cases tested.
- [ ] Tested with full servers and with uneven teams.

## See also

[[Combat Arena and Encounter Layout]] · [[Level Design Principles - Flow Sightlines and Landmarks]] · [[Spawn Points Safe Zones and Respawn Flow]] · [[Spawning Teams and Rounds]] · [[Arena Rounds with Teams and Spectating End to End]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Pathfinding]] · [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]]

## Connected notes
<!-- auto-links:start -->
[[Level Design Start Here]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · Server Authority and Validation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Playtest Heatmaps - Position and Death Maps]] · [[Teaching Through Level Design]] · [[Lobby and Hub Design]] · [[Instanced Interiors - Pooled House and Room Copies for Many Players]] · [[PathfindingService - Engine Reference Card]] · [[Teardown - Phantom Forces]] · [[Obby and Platforming Level Design]]
<!-- related:end -->
