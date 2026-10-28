---
tags: [gameplay, pathfinding, navigation, npc, ai, fallbacks, debugging]
---
# Pathfinding Edge Cases and Fallbacks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Pathing to the player's root position -> Goal resolver: project down, last grounded position, ring samples
> - Avoid: Agent radius equal to the body -> Widest collidable part plus 0.5 to 1 stud
> - Avoid: Velocity-only stuck detection -> Progress over a window
> - Goals and starts resolved onto the floor; airborne targets use last grounded position.
> - Agent parameters measured from the widest collidable part, with margin, per size class.
> - Doors have `PassThrough` modifiers; spawned barriers trigger delayed recomputes.
>
> Read more (20 KB note): ## 2. Bad endpoints: resolve the goal before asking · ## 5. Follower edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Pathfinding]] covers the `PathfindingService` API, costs, modifiers, links and a robust follower. This note is about what happens after the happy path: the goal is in the air, the start is inside a wall, the door just closed, the client has not streamed the target in, the NPC grinds against a corner for nine seconds, forty enemies ask for a path on the same frame. Every one of these looks to players like "the AI is broken", and every one has a cheap fallback. The rule this note is built around: **an NPC must always be doing something sensible, even when no path exists.**

Related: [[Pathfinding]], [[NPC AI and Behaviour]], [[Behaviour Trees Utility AI and State Machines for NPCs]], [[Characters and Humanoids]], [[Raycasts Shapecasts and Spatial Queries]], [[Instance Streaming]], [[Collision and Physics Geometry]].

Source labels: **Docs** (Roblox docs as of October 2026: the character pathfinding guide and the PathfindingService, Path and PathStatus reference pages), **Measured** (the reference project), **Rule of thumb**.

---

## 1. A taxonomy of failures

Most pathfinding bugs fall into one of five families. Diagnose the family first; the fix follows.

| Family | What players see | Typical root cause |
|---|---|---|
| Bad endpoints | NPC stands still or walks the wrong way | Start or goal inside geometry, in the air, under the floor, on a moving part |
| Wrong agent | NPC wedges under a bridge, scrapes along walls, sticks at doorways | Agent parameters smaller than the real body |
| Stale path | NPC walks into a closed door or a newly placed wall | World changed after `ComputeAsync`; `Blocked` ignored |
| Follower bugs | NPC stops halfway, spins on a waypoint, jumps at the wrong time | Timeouts, arrival radius, jump timing, Humanoid state |
| Load | Paths come back late, NPCs pause in groups | Too many requests per second, recomputing every tick |

Docs-stated hard limits worth memorising: start-to-goal straight-line distance must not exceed **3,000 studs**; computation can fail after **20,000 nodes** even below that; parameters that cannot be satisfied (a required jump when `AgentCanJump` is false) fail; waypoints below Y -65,536 or above 65,536 are ignored. `ComputeAsync` can also error, so it belongs in a `pcall` (the docs samples wrap it).

---

## 2. Bad endpoints: resolve the goal before asking

The single biggest improvement to most NPC pathing is a **goal resolver** that turns "where the player is" into "a point on the navmesh near the player". Players jump, stand on props, ride platforms, hang off ledges and stand in doorways. Their `HumanoidRootPart` is 2 to 3 studs above the floor even when grounded.

Resolution steps:
1. **Project down.** Raycast from the target position downward (for example 50 studs) against the world only (exclude characters and NPCs). Use the hit position as the goal.
2. **Airborne targets.** If the target is jumping or falling (Humanoid state `Freefall` or `Jumping`), use their **last grounded position** instead. Record it every time the ray hits within a short distance.
3. **Inside geometry.** If the projected point is inside something solid, a `NoPath` follows. Nudge the goal: sample a ring of points around it (8 directions at 3 and 6 studs) and take the first that projects onto open floor.
4. **Unreachable on purpose.** A player on a tall rock the NPC cannot climb is a design question, not a bug. Decide what the NPC does (ranged attack, wait at the base, leash home), and do not spin on recomputes.

```lua
--!strict
-- Goal resolver: turn a target position into a reachable floor point, or nil.
local Workspace = game:GetService("Workspace")

local DOWN = Vector3.new(0, -50, 0)
local RING = { 3, 6 }
local DIRS = 8

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
-- Fill with the folders that hold characters and NPCs before use:
-- params.FilterDescendantsInstances = { charactersFolder, npcFolder }

local function project(p: Vector3): Vector3?
	local hit = Workspace:Raycast(p + Vector3.new(0, 3, 0), DOWN, params)
	return if hit then hit.Position else nil
end

local lastGrounded: { [Model]: Vector3 } = {}

local function resolveGoal(target: Model): Vector3?
	local hum = target:FindFirstChildOfClass("Humanoid")
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return nil
	end
	local state = hum:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	if not airborne then
		local floor = project(root.Position)
		if floor and (root.Position.Y - floor.Y) < 6 then
			lastGrounded[target] = floor
			return floor
		end
	end
	local remembered = lastGrounded[target]
	if remembered then
		return remembered
	end
	-- No memory: try a ring around the target.
	for _, r in RING do
		for i = 0, DIRS - 1 do
			local a = (i / DIRS) * math.pi * 2
			local p = project(root.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			if p then
				return p
			end
		end
	end
	return nil
end

return { resolveGoal = resolveGoal, forget = function(m: Model) lastGrounded[m] = nil end }
```

Call `forget` when a player leaves or respawns; otherwise the table holds dead character models (a classic slow leak: [[Memory Budgets and Leaks]]).

The **start** point needs the same care. An NPC knocked into a wall or spawned partly inside a rock has a start inside geometry. Project the start down from the root and, if the path still fails, try the start nudged 2 studs back along the NPC's last movement direction.

---

## 3. Wrong agent: size honestly, then add margin

`AgentRadius` and `AgentHeight` describe the clearance the path needs (Docs defaults 2 and 5, documented as integers in the guide's table). Two subtleties:

- **Radius is clearance, not the visual half-width.** A wide creature whose shoulders are 3.5 studs from the centre but whose `HumanoidRootPart` hip collider is narrow will still clip walls if you pass `AgentRadius = 2`. Measure the **widest collidable** part of the body at walking height, then add 0.5 to 1 stud. Paths hug corners as closely as the radius allows, so a radius that exactly matches the body grinds every corner.
- **Height includes animation.** A creature that rears up or carries a tall weapon may fit under a beam when idle but not mid-stride. If the weapon is non-colliding it does not matter; if it collides, it does.

When one map holds very different sizes, create **one Path object per size class** and reuse it (as [[Pathfinding]] recommends). If a giant agent fails often, ask whether it should path at all: **measured**, the reference project kept large bosses in arenas and moved them directly, and its regular enemies used local steering around a trunk grid instead of the navmesh in open zones.

---

## 4. Stale paths: the world changes

A computed path is a snapshot. Doors close, players build walls, physics props roll into corridors. `Path.Blocked` fires when an obstacle appears on a waypoint ahead; the docs pattern is to recompute only when the blocked index is ahead of the current one. Edge cases on top:

- **Blocked never fires for small or moving obstacles** in practice (rule of thumb: treat `Blocked` as a hint, not a guarantee). Your stuck detector (section 5) is the real safety net.
- **Doors.** A closed door can make the navmesh treat a room as unreachable. Put a `PathfindingModifier` with `PassThrough` in the doorway (Docs) so paths go through, and let the follower open the door when it reaches that waypoint. Without `PassThrough`, a door that opens after the path was computed leaves the NPC taking the long way round.
- **Streaming.** The docs warn that streaming can block or unblock a path as a character moves along it, and that client-side paths can fail when the target is not streamed in (target a part in a persistent model and wait for `Workspace.PersistentLoaded`) (Docs). Server paths are not affected by client streaming.
- **Navmesh rebuild delay.** The navmesh updates when geometry changes, but not instantly (rule of thumb: assume a short delay; the exact timing is not documented). A path requested on the same frame you spawn a wall may route straight through it. If gameplay spawns barriers, recompute paths of nearby NPCs half a second later.

---

## 5. Follower edge cases

### Arrival radius
A waypoint is "reached" when the flat distance is under 1.5 to 2.5 studs (rule of thumb). Too small and NPCs orbit a waypoint they cannot quite reach (common on slopes); too large and they cut corners into walls. Test flat distance (ignore Y): the root is above the floor, waypoints are on it.

### The MoveTo timeout
`Humanoid:MoveTo` stops trying after about 8 seconds if the goal is not reached. That is long-standing documented behaviour; the current Humanoid reference page shows it indirectly through a sample that calls `MoveTo` again to "refresh the timeout" (Docs). For long walks between distant waypoints (`WaypointSpacing = math.huge`) the NPC can simply stop. Keep waypoint spacing modest, or re-issue `MoveTo` for the same point every few seconds.

### Progress, not speed, detects being stuck
The [[Pathfinding]] follower checks low velocity. That misses two cases: an NPC pushing against a wall can have a non-zero velocity as it slides back and forth, and an NPC orbiting a waypoint moves fast while going nowhere. Track **distance to the current waypoint over a window**:

```lua
--!strict
-- Progress-based stuck detector. Call sample() every brain tick while following.
export type Stuck = { window: number, minGain: number, history: { { t: number, d: number } } }

local function newStuck(window: number?, minGain: number?): Stuck
	return { window = window or 1.2, minGain = minGain or 1.5, history = {} }
end

-- Returns true if the agent has not got minGain studs closer to its waypoint within the window.
local function sample(s: Stuck, now: number, distanceToWaypoint: number): boolean
	table.insert(s.history, { t = now, d = distanceToWaypoint })
	while #s.history > 1 and now - s.history[1].t > s.window do
		table.remove(s.history, 1)
	end
	local first = s.history[1]
	if now - first.t < s.window * 0.9 then
		return false -- not enough history yet
	end
	return (first.d - distanceToWaypoint) < s.minGain
end

local function reset(s: Stuck)
	table.clear(s.history)
end

return { new = newStuck, sample = sample, reset = reset }
```

Reset it whenever the waypoint index changes. At a 10 Hz brain the history holds about 12 entries.

### An escalation ladder for stuck agents
Do not jump straight to teleporting. Escalate:

| Step | Action | When |
|---|---|---|
| 1 | Jump | First stuck detection (often frees lips and small steps) |
| 2 | Skip to the next waypoint | Second detection on the same waypoint |
| 3 | Recompute from a nudged start (2 studs back) | Third |
| 4 | Fall back to direct movement if line of sight is clear | Path keeps failing |
| 5 | Give up the target and return home (leash) | Several seconds of failure |
| 6 | Teleport home or to the next waypoint **while no player is looking** | Stuck at home, or the NPC is critical (escort, quest giver) |

"While no player is looking" is a real technique: if no player camera is within a set distance or facing the NPC (the server can approximate this with player positions and look directions sent for other purposes, or simply with distance), a short teleport is invisible and saves the encounter. Never teleport in view; it reads as a bug.

### Jumps
`PathWaypointAction.Jump` marks waypoints that need a jump (Docs). Two classic errors: jumping when the waypoint is *reached* (too late; the NPC is already at the ledge base and jumps into the wall) and jumping without forward motion. Trigger the jump when the NPC is within a short distance of the jump waypoint while already moving toward the next one. For agents that should never jump (heavy enemies), set `AgentCanJump = false` and accept that some goals become unreachable; handle that in the goal resolver, not by letting them try.

### Humanoid states that break following
- `PlatformStand`, `Seated`, `Physics` and ragdoll states ignore `MoveTo`. After a knock-back or ragdoll, the follower must wait for the NPC to return to a walking state before resuming, or it burns its timeouts while lying down.
- **Network ownership.** A server-driven NPC whose assembly is owned by a nearby client moves erratically. Set the owner to the server on spawn ([[Network Ownership]]).
- **Knock-back mid-path** moves the NPC off the path. If it lands more than a few studs from the current segment, recompute instead of walking back to the old waypoint.

---

## 6. Moving targets and request load

### Do not recompute on every tick
Recompute when the resolved goal has moved more than a threshold **relative to the remaining distance** (rule of thumb: 20% of remaining distance, minimum 3 studs) or after a timer (0.5 to 1 s). A target 100 studs away that moved 4 studs does not need a new path; a target 8 studs away that moved 4 does, or better, does not need a path at all.

### Direct mode near the target
Within about 15 studs with clear line of sight (one shapecast with the agent's radius from chest height, not a thin ray, so the NPC does not try to squeeze through a gap a ray fits through), drop the path and move straight ([[Raycasts Shapecasts and Spatial Queries]]).

### A request queue with a budget
Brains should never call `ComputeAsync` directly. They post a request; a single worker runs a budgeted number per second and writes results back. Benefits: no brain yields, duplicate requests collapse, and you can see load.

```lua
--!strict
-- Path request queue: at most BUDGET computations per second, one pending request per agent.
local PathfindingService = game:GetService("PathfindingService")

local BUDGET_PER_SECOND = 20 -- rule of thumb; tune with the MicroProfiler

export type Request = { agent: Model, from: Vector3, to: Vector3, path: Path, done: (Path?) -> () }

local pending: { [Model]: Request } = {}
local order: { Model } = {}

local function request(r: Request)
	if not pending[r.agent] then
		table.insert(order, r.agent)
	end
	pending[r.agent] = r -- a newer request replaces the older one
end

local function cancel(agent: Model)
	pending[agent] = nil -- left in `order`; skipped when reached
end

task.spawn(function()
	local interval = 1 / BUDGET_PER_SECOND
	while true do
		local agent = table.remove(order, 1)
		local r = agent and pending[agent]
		if r then
			pending[agent] = nil
			if r.agent.Parent then
				local ok = pcall(function()
					r.path:ComputeAsync(r.from, r.to)
				end)
				r.done(if ok and r.path.Status == Enum.PathStatus.Success then r.path else nil)
			end
			task.wait(interval)
		else
			task.wait(if agent then 0 else interval)
		end
	end
end)

return { request = request, cancel = cancel }
```

Caveat on sharing `Path` objects: one `Path` per size class is fine for sequential use, but this worker computes one request at a time precisely so that a shared `Path` is never computed twice at once. If a brain keeps a reference to `path:GetWaypoints()`, copy the waypoints in `done` before the next request reuses the object.

### Cheaper than a path
| Situation | Cheaper option |
|---|---|
| Pack chasing one player | One path, shared; members offset along it |
| Many agents, one fixed goal (tower defence) | Flow field over a grid ([[Pathfinding]] section 4) |
| Patrols | Precomputed at startup, stored as waypoint lists |
| Open field | Local steering (**Measured**: about 0.007 ms per think in the reference project) |
| Short distance, clear sight | Direct movement |

---

## 7. Smoothing: string pulling

Paths with `WaypointSpacing` 4 produce many points and visible zig-zags around corners. A simple smoothing pass: from the current waypoint, look ahead and skip to the furthest waypoint you can reach with a clear **shapecast** of the agent's radius at waist height and no height change larger than a step. Do it lazily as you walk (every tick check whether waypoint `i + 2` is directly reachable) rather than on the whole list, because the world changes. Never skip a `Jump` or link waypoint.

---

## 8. Fallbacks when there is no path at all

The NPC must still behave. Ranked from best to worst for a combat enemy:

1. **Ranged option**: attack from where it stands if it has one.
2. **Wait at the nearest reachable point** to the target, facing it, with an idle "searching" animation. Reads as intentional.
3. **Leash home** after a few seconds and heal, as in [[NPC AI and Behaviour]].
4. **Despawn and respawn elsewhere** for non-unique enemies when no player is near.

For a quest or escort NPC that must arrive: precomputed fallback routes between key points, then an out-of-view teleport as the last resort.

`PathStatus` contains values beyond `Success` and `NoPath` (for example `ClosestNoPath`, described in the enum reference as returning a path to the closest point). Whether and when `ComputeAsync` produces those statuses today is not clearly documented in the main guide (unverified as of October 2026), so treat any non-`Success` status as a failure and run your own fallback rather than relying on partial paths.

---

## 9. Testing the edge cases on purpose

Build a **pathing test map** (a separate place or a hidden area) with one fixture per edge case: a doorway exactly agent-width, a doorway agent-width plus 1, a ledge needing a jump, a 1-stud lip, a ramp at the walkable limit, a moving platform, a door with a `PassThrough` modifier, a pit with no route, a target on a pillar. Run each NPC size class through it after every movement or scale change (**Measured**: the reference project's enemy ranges and gaits had to be retuned after each rescale; pathing clearances change the same way).

Visualise: turn on the navigation mesh and pathfinding modifier overlays in Studio (Docs), draw resolved goals in one colour and waypoints in another, and print the escalation step each NPC reached.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Pathing to the player's root position | `NoPath` while jumping; NPC freezes when the player is on a prop | Goal resolver: project down, last grounded position, ring samples |
| Agent radius equal to the body | Grinding corners and doorways | Widest collidable part plus 0.5 to 1 stud |
| Velocity-only stuck detection | Sliding or orbiting NPCs never flagged | Progress over a window |
| Jump on arrival at the jump waypoint | NPC jumps into the wall | Trigger jump slightly before, while moving |
| Following during ragdoll or stun | Timeouts fire; path abandoned | Pause the follower until a walking state |
| `ComputeAsync` called from brains | Brains yield; spikes when packs aggro | Budgeted request queue |
| Teleporting stuck NPCs in view | "Glitchy AI" reports | Escalation ladder; teleport only unseen |
| Relying on partial path statuses | Unpredictable behaviour across versions | Treat non-Success as failure; own fallback |
| Resolver memory never cleared | Slow leak of character references | Forget on leave and respawn |

## Checklist
- [ ] Goals and starts resolved onto the floor; airborne targets use last grounded position.
- [ ] Agent parameters measured from the widest collidable part, with margin, per size class.
- [ ] Doors have `PassThrough` modifiers; spawned barriers trigger delayed recomputes.
- [ ] Progress-based stuck detection with an escalation ladder ending in an unseen teleport or leash.
- [ ] Follower pauses during non-walking Humanoid states and recomputes after knock-back.
- [ ] Path requests queued with a server-wide budget; one pending request per agent.
- [ ] Direct movement with a shapecast check near the target.
- [ ] A test map with one fixture per edge case, run after every scale or level change.

## See also
[[Pathfinding]] · [[NPC AI and Behaviour]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Characters and Humanoids]] · [[Network Ownership]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Instance Streaming]] · [[Collision and Physics Geometry]] · [[Level Design for Roblox]] · [[Memory Budgets and Leaks]]

## Connected notes
<!-- auto-links:start -->
[[Horror Monster Chase AI End to End]] · [[Combat Arena and Encounter Layout]] · [[Links - NPCs and AI]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Humanoid States and Animation]] · [[Physics Performance]]
<!-- auto-links:end -->
