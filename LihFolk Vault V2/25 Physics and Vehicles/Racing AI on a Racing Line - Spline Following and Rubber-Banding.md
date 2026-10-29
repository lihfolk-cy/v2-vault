---
tags: [physics, vehicles, racing, ai, splines, rubber-banding, game-design, type/guide, area/physics, area/ai, level/advanced, api/CFrame, api/SetNetworkOwner]
---
# Racing AI on a Racing Line - Spline Following and Rubber-Banding

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Evaluating the spline every frame -> Bake samples once
> - Avoid: Global nearest-point search -> Windowed search around last index
> - Avoid: Fixed lookahead -> Lookahead scales with speed
> - Racing line authored on the ideal line, baked with distance, curvature and half-width.
> - Windowed progress tracking; global reset after respawn.
> - Pure-pursuit steering with speed-scaled lookahead.
>
> Cost: TL;DR ~140 tok · whole note ~2.9k tok. Read more: ## 1. Author the racing line · ## 5. Rubber-banding without resentment · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI racers make a racing game playable with one human in the server, which on Roblox is most servers for the first months. Good racing AI is not pathfinding; it is a car following a hand-authored racing line, choosing a speed it can carry through the next corner, steering toward a point ahead of itself, and quietly adjusting pace so races stay close without the player noticing. This note covers that stack: authoring the line as a spline, tracking progress, pure-pursuit steering, curvature-based speed, overtaking offsets, and rubber-banding that players do not resent. Lap and checkpoint logic lives in [[Racing Laps and Checkpoints End to End]].

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. The algorithms are standard game-AI techniques. Code is strict Luau, reviewed, not run.

## 1. Author the racing line

Place ordered points (Attachments or small anchored parts in a folder, named `1`, `2`, ...) along the ideal line: wide on corner entry, clipping the apex, wide on exit. Then interpolate with a Catmull-Rom spline, which passes through every control point ([[Curves in Luau - Paths Beams and Motion]], [[Interpolation Easing and Curves Math]]).

At load, bake the spline into a dense array of samples every 2 to 4 studs, each with position, cumulative distance and curvature. Everything at runtime reads the baked array; nothing evaluates the spline per frame.

```lua
--!strict
-- ServerScriptService/RacingLine (ModuleScript)
export type Sample = { pos: Vector3, dist: number, curvature: number }

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local RacingLine = {}

function RacingLine.bake(points: { Vector3 }, step: number): { Sample }
	local n = #points
	local raw: { Vector3 } = {}
	for i = 1, n do -- closed loop
		local p0 = points[(i - 2) % n + 1]
		local p1, p2 = points[i], points[i % n + 1]
		local p3 = points[(i + 1) % n + 1]
		local segLen = (p2 - p1).Magnitude
		local count = math.max(1, math.floor(segLen / step))
		for k = 0, count - 1 do
			table.insert(raw, catmull(p0, p1, p2, p3, k / count))
		end
	end
	local samples: { Sample } = {}
	local dist = 0
	local m = #raw
	for i = 1, m do
		local prev, cur, nxt = raw[(i - 2) % m + 1], raw[i], raw[i % m + 1]
		if i > 1 then dist += (cur - raw[i - 1]).Magnitude end
		-- curvature from the turning angle between neighbours over the arc length
		local a, b = (cur - prev), (nxt - cur)
		local ang = math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))
		local curvature = ang / math.max(1e-3, (a.Magnitude + b.Magnitude) / 2)
		table.insert(samples, { pos = cur, dist = dist, curvature = curvature })
	end
	return samples
end

-- Nearest sample index, searching a window around the last known index (cheap and stable).
function RacingLine.track(samples: { Sample }, pos: Vector3, last: number, window: number): number
	local best, bestD = last, math.huge
	local m = #samples
	for o = -window, window do
		local i = (last + o - 1) % m + 1
		local d = (samples[i].pos - pos).Magnitude
		if d < bestD then best, bestD = i, d end
	end
	return best
end

return RacingLine
```

Notes (Rule of thumb):

- **Windowed search, not global.** A global nearest-point search jumps to the wrong part of the track where two sections pass close together (figure-eights, bridges). Search around the last index; reset globally only after a respawn.
- **Smooth the curvature** with a small moving average after baking, because hand-placed points produce noisy angles.
- **Height matters.** Curvature here is 3D; for tracks with hills, project the vectors onto the horizontal plane before measuring the turn angle, or crests read as corners.

## 2. Steer with pure pursuit

Pick a target point a lookahead distance ahead along the line and steer toward it. Lookahead grows with speed: short at low speed for tight corners, long at high speed for stability.

```lua
--!strict
local function steerToward(root: BasePart, target: Vector3, maxSteer: number): number
	local loc = root.CFrame:PointToObjectSpace(target)
	-- LookVector is -Z in object space
	local angle = math.atan2(loc.X, -loc.Z)
	return math.clamp(angle / maxSteer, -1, 1) -- -1..1 steering input
end
```

Lookahead rule of thumb: `max(12, speed * 0.6)` studs. Too short and the car weaves; too long and it cuts corners onto the grass.

The AI then drives its car through **the same input layer as a player**: a throttle, brake and steer value fed to the same drive code. AI that sets velocities directly will be faster than physics allows and looks wrong on collision.

## 3. Choose a speed it can carry

The maximum speed through a curve of radius `R = 1 / curvature` at lateral grip `mu` is

```
vCorner = sqrt(mu * g * R)
```

with `g = workspace.Gravity`. A car at speed `v` that must slow to `vCorner` within distance `d` at braking deceleration `aBrake` must start braking when

```
v > sqrt(vCorner^2 + 2 * aBrake * d)
```

So each frame: scan the samples over the next braking distance, compute the allowed speed at the current position from every upcoming corner, take the minimum, and set throttle or brake to approach it. Tune `mu` and `aBrake` to what your car actually achieves, measured by driving it yourself, not to what the formula says. Use a `mu` slightly below the true limit for the easiest AI tier and right at it for the hardest.

## 4. Overtaking and avoidance

A single line makes AI cars queue nose to tail. Add a **lateral offset** to the target point:

- Each AI has a preferred offset (small random value) so packs spread out.
- If another car is ahead within a few car lengths and slower, pick the side with more space (two short side raycasts, or compare the other car's offset) and move the offset that way, limited by track width at that sample (store half-width per control point).
- Blend offset changes over a second or two; instant lane changes look robotic and cause crashes.
- Never offset in the braking zone of a sharp corner; return to the line.

## 5. Rubber-banding without resentment

Rubber-banding keeps races close. Players notice and hate it when an AI that was miles behind teleports past at impossible speed, or when the leader is never allowed to win. Rules that keep it invisible (Rule of thumb):

1. **Measure gap in track distance**, not straight-line distance: `aiProgress - humanProgress` using lap count times lap length plus `samples[i].dist`.
2. **Adjust performance, not position.** Scale the AI's `mu` and engine force by a factor clamped to a narrow band, for example 0.92 to 1.06. Never move a car by script while a player can see it.
3. **Asymmetric.** Help trailing AI more than you slow leading AI; a leading AI that suddenly crawls is more obvious than one that catches up.
4. **Cap catch-up below the player's ability.** A trailing AI at 1.06 should still be slower than a good player on a clean lap, so skill wins.
5. **Mistakes instead of slowdowns.** A leading AI can "run wide" at a corner (bigger offset, slightly early braking). That reads as a mistake, not cheating.
6. **Fade it out on the final lap** or the final sector, so the finish is earned.
7. **Difficulty tiers set the base pace**; rubber-banding only nudges around it.

```lua
--!strict
-- Performance multiplier from the gap to the nearest human (positive gap = AI ahead).
local function rubberBand(gapStuds: number, finalLap: boolean): number
	if finalLap then return 1 end
	if gapStuds < 0 then
		return 1 + math.min(0.06, -gapStuds / 4000) -- behind: up to +6%
	end
	return 1 - math.min(0.04, gapStuds / 6000) -- ahead: down to -4%
end
```

## 6. Running AI cars on Roblox

- **Ownership:** AI cars are server-owned (`SetNetworkOwner(nil)` after spawn), so no client can shove them with local physics and every client sees the same race ([[Network Ownership]]). That costs server physics; budget around a handful of physical AI cars per server and measure ([[Physics Performance]]).
- **Tick rate:** run the AI decision (target point, speed) at 10 to 20 Hz and the drive forces every physics step. Decisions are cheap; forces must be smooth.
- **Ghost or kinematic AI:** for many AI cars, or when no human is near, move them kinematically along the baked line at their computed speed with `PivotTo` and only make them physical near players ([[Interest Management and Per-Player Replication]]).
- **Streaming:** AI cars far from a viewer stream out. HUD positions should come from server-published progress values, not the viewer's workspace ([[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]]).
- **Recovery:** if an AI's progress has not advanced for a few seconds (stuck on a wall, flipped), respawn it at the nearest sample behind, facing along the line, when no player is looking at it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Evaluating the spline every frame | Bake samples once |
| Global nearest-point search | Windowed search around last index |
| Fixed lookahead | Lookahead scales with speed |
| AI sets velocity directly | Same throttle, brake, steer path as players |
| Braking only when inside the corner | Braking-distance check over upcoming samples |
| Teleporting trailing AI forward | Clamp performance multiplier; never move visible cars |
| Rubber-banding on the last lap | Fade it out |
| Client-owned AI cars | Server-owned, or kinematic when far |

## Checklist

- [ ] Racing line authored on the ideal line, baked with distance, curvature and half-width.
- [ ] Windowed progress tracking; global reset after respawn.
- [ ] Pure-pursuit steering with speed-scaled lookahead.
- [ ] Corner speeds and braking points from curvature and measured grip.
- [ ] Lateral offsets for spacing and overtakes, blended.
- [ ] Rubber-banding narrow, asymmetric, faded on the final lap.
- [ ] AI server-owned, decisions at 10 to 20 Hz, stuck recovery off-camera.

## See also

[[Racing Laps and Checkpoints End to End]] · [[Genre Playbook - Racing and Driving]] · [[Curves in Luau - Paths Beams and Motion]] · [[Interpolation Easing and Curves Math]] · [[Dot and Cross Products in Gameplay]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Pathfinding]]

## Connected notes
<!-- auto-links:start -->
[[Bezier Curves and Splines for Modellers]] · Physics Performance · [[Physics and Vehicles Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Centre of Mass, Anti-Flip and Self-Righting]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]]
<!-- related:end -->
