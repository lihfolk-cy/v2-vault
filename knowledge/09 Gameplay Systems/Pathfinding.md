---
tags: [gameplay, pathfinding, navigation, npc, ai]
---
# Pathfinding

`PathfindingService` computes walkable routes over a navigation mesh that Roblox builds from your world. It handles stairs, ramps, jumps, gaps and (with links) ladders, boats and teleporters. It is also slower, more failure-prone and more limited than people expect: a path can be blocked a moment after you compute it, the agent shape must be described honestly, long paths fail, and following waypoints with a Humanoid needs care. This note covers the API, costs, modifiers and links, a robust follower, when not to use pathfinding at all, and debugging.

Related: [[NPC AI and Behaviour]] (decisions), [[Characters and Humanoids]] (MoveTo), [[Level Design for Roblox]] (building navigable spaces).

Source labels: **Docs** (PathfindingService, Path and the character pathfinding guide, checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. API overview

```lua
local PathfindingService = game:GetService("PathfindingService")
local path = PathfindingService:CreatePath(agentParameters)
path:ComputeAsync(startPosition, goalPosition) -- yields
if path.Status == Enum.PathStatus.Success then
	for _, wp in path:GetWaypoints() do
		-- wp.Position, wp.Action (Walk / Jump / Custom), wp.Label
	end
end
```

### Agent parameters (Docs)

| Key | Default | Meaning |
|---|---|---|
| `AgentRadius` | 2 | Minimum horizontal clearance (studs) |
| `AgentHeight` | 5 | Minimum vertical clearance |
| `AgentCanJump` | true | Allow jump links |
| `AgentCanClimb` | false | Allow climbing TrussParts (climb cost 1 by default) |
| `WaypointSpacing` | 4 | Distance between intermediate waypoints; `math.huge` for none |
| `Costs` | nil / `{}` | Per-material and per-label traversal costs |

**Describe the real agent.** The defaults fit a standard 5-stud avatar. A boss 20 studs tall with `AgentHeight = 5` gets routed under bridges it cannot fit through and then sticks. A character scaled 1.6x (about 9 studs tall, as in the reference project) needs about `AgentRadius = 3`, `AgentHeight = 9`. Create one `Path` object per agent *size class* and reuse it with `ComputeAsync`.

### Limits and failure cases (Docs)
- The straight-line distance from start to goal must not exceed **3,000 studs**.
- Computation may fail after **20,000 nodes**, even under 3,000 studs.
- It fails if the agent parameters cannot resolve (for example, a route that needs a jump when `AgentCanJump` is false).
- Points inside solid geometry give `NoPath`.
- Waypoints below Y -65,536 or above 65,536 are ignored.

`Path.Status` is `Success` or `NoPath` in the documented flow. Other `PathStatus` values exist in the enum (such as partial-path statuses); their current behaviour is not documented on the main pages, so do not depend on them without testing.

`PathfindingService:FindPathAsync(start, finish)` is the one-call form; it returns a Path whose status may be `NoPath` (Docs).

---

## 2. Costs, modifiers and links

### Costs
Keys are material names (`Enum.Material` names as strings, such as `"Water"` or `"CrackedLava"`) or modifier labels. Every material costs 1 by default; `math.huge` makes it non-traversable; large finite values (100 to 1,000) make it a last resort (Docs).

```lua
local path = PathfindingService:CreatePath({
	AgentRadius = 3,
	AgentHeight = 9,
	AgentCanJump = true,
	Costs = {
		Water = 20,          -- avoid swimming unless much shorter
		CrackedLava = math.huge,
		DangerZone = math.huge, -- a PathfindingModifier label
		UseBoat = 2,          -- a PathfindingLink label, cheaper than Water
	},
})
```

### PathfindingModifier
Put a `PathfindingModifier` inside an **anchored, non-colliding** part that covers a region; its `Label` becomes a cost key (Docs). With `PassThrough` enabled, paths may go through solid obstacles in that region: useful for doors that open, breakable walls, or foliage that is technically collidable.

Patterns:
- **Danger zones:** label `Danger`, cost high. NPCs prefer to go around a lava field without being forbidden from crossing it.
- **Doors:** a modifier with `PassThrough` inside the door frame; the follower opens the door when it reaches the waypoint.
- **Team-only areas:** per-team cost tables (a separate `Path` per team) so defenders path through their base and attackers do not.

### PathfindingLink
A `PathfindingLink` connects two attachments across a gap the navmesh cannot cross (a teleporter, a boat, a zipline, a ladder you climb with a custom animation). Its `Label` appears on the waypoint and can carry a cost (Docs). The follower checks the label and performs the custom traversal.

---

## 3. A robust follower

The docs' example drives the Humanoid toward each waypoint, triggers jumps on Jump waypoints and recomputes when `Blocked` fires for a waypoint ahead. A production follower adds timeouts, stuck detection and periodic recompute for moving goals.

```lua
--!strict
local PathfindingService = game:GetService("PathfindingService")

export type Follower = {
	humanoid: Humanoid,
	path: Path,
	running: boolean,
}

local REPATH_INTERVAL = 0.75  -- for moving targets
local WAYPOINT_TIMEOUT = 2.5  -- seconds to reach one waypoint
local STUCK_SPEED = 0.5       -- studs/s below which we count as stuck

local function followTo(f: Follower, getGoal: () -> Vector3?, onCustom: ((PathWaypoint) -> ())?)
	f.running = true
	local root = f.humanoid.RootPart
	if not root then return end

	while f.running and f.humanoid.Health > 0 do
		local goal = getGoal()
		if not goal then break end

		local ok = pcall(function()
			f.path:ComputeAsync(root.Position, goal)
		end)
		if not ok or f.path.Status ~= Enum.PathStatus.Success then
			-- Fallback: walk straight toward the goal briefly, then retry.
			f.humanoid:MoveTo(goal)
			task.wait(0.5)
			continue
		end

		local waypoints = f.path:GetWaypoints()
		local index = 2 -- 1 is the start position
		local blocked = false
		local conn = f.path.Blocked:Connect(function(blockedIndex: number)
			if blockedIndex >= index then
				blocked = true
			end
		end)

		local computedAt = os.clock()
		while f.running and not blocked and index <= #waypoints do
			local wp = waypoints[index]
			if wp.Label ~= "" and onCustom and wp.Action == Enum.PathWaypointAction.Custom then
				onCustom(wp) -- e.g. ride the boat, use the teleporter (may yield)
			else
				if wp.Action == Enum.PathWaypointAction.Jump then
					f.humanoid.Jump = true
				end
				f.humanoid:MoveTo(wp.Position)
				local started = os.clock()
				local reached = false
				local done = f.humanoid.MoveToFinished:Connect(function(r)
					reached = r
				end)
				while not reached and os.clock() - started < WAYPOINT_TIMEOUT do
					task.wait(0.1)
					local flat = (wp.Position - root.Position) * Vector3.new(1, 0, 1)
					if flat.Magnitude < 2 then
						reached = true
					elseif os.clock() - started > 0.6 and root.AssemblyLinearVelocity.Magnitude < STUCK_SPEED then
						f.humanoid.Jump = true -- simple unstick attempt
					end
				end
				done:Disconnect()
				if not reached then
					blocked = true -- timeout: recompute
				end
			end
			index += 1
			if os.clock() - computedAt > REPATH_INTERVAL then
				break -- goal may have moved: recompute
			end
		end
		conn:Disconnect()
		if index > #waypoints and not blocked then
			local g = getGoal()
			if not g or (g - root.Position).Magnitude < 4 then
				break
			end
		end
	end
	f.running = false
end

return { followTo = followTo }
```

Notes on this code:
- `ComputeAsync` yields and can error; wrap it in `pcall`.
- The `Blocked` index is 1-based; obstacles behind the agent (index below the current one) are ignored, as in the docs.
- Arrival is tested on the flat distance: waypoints on stairs are at floor height and the root is above it.
- Whether a link's waypoint reports `Action == Custom` should be checked in your version; the documented approach is to read the waypoint `Label` (Docs). Testing both is harmless.
- Network ownership: an NPC that a nearby client owns may move erratically when the server drives it. Set `SetNetworkOwner(nil)` on server-driven NPCs ([[Physics Assemblies and Constraints]]).

### Moving targets
Recompute on a timer (0.5 to 1 s) or when the goal moved more than a few studs. Close to the target (within line of sight and about 15 studs), skip pathfinding and move directly; the last few studs of a computed path toward a moving player are always stale.

---

## 4. Costs of pathfinding (and how to spend less)

`ComputeAsync` is not free: it yields while the engine searches, and many agents recomputing every frame will queue. Rules of thumb:
- **Budget computations per second** across all agents (for example 20 per second on the server) and queue the rest.
- **Share paths.** A pack chasing one player can share one path and offset along it.
- **Use direct movement whenever line of sight is clear** and the ground between is walkable.
- **Precompute** routes between fixed points (patrol routes, spawn to arena) at startup.
- **Local steering** for open areas. **Measured:** the reference project's enemies use no pathfinding at all in open forest zones; they steer around a trunk grid at about 0.007 ms per think ([[NPC AI and Behaviour]] section 6). Pathfinding pays off where the topology matters: rooms, corridors, bridges, multi-level buildings.

| Situation | Use |
|---|---|
| Open field with scattered obstacles | Local steering |
| Arena, target visible | Direct movement |
| Buildings, mazes, multi-level | PathfindingService |
| Fixed patrols | Precomputed waypoints |
| Hundreds of agents to one goal | Flow field over your own grid |

### Flow fields
For tower defence and horde games where hundreds of agents go to the same goal, compute one breadth-first distance field over a grid (or over the waypoints of one path) and let every agent descend it. One computation serves every agent. The reference project's walkable masks (a flood-filled 8-stud grid per zone) are the same building block.

---

## 5. Client-side pathfinding

Pathfinding also runs on clients (click-to-move, guide trails). The docs warn that with streaming enabled, a client may not have the target area loaded, so paths can fail or change as parts stream in. Target a part in a persistent model and wait for `Workspace.PersistentLoaded`, or compute on the server and send the waypoints ([[Instance Streaming]]).

A tutorial "follow the trail" guide is a good client use: compute once, draw the trail along the waypoints, recompute when the player strays.

---

## 6. Agents that are not walking humanoids

- **Flyers.** The navmesh is for walkers and swimmers. Flying enemies need their own approach: move in 3D toward the target with obstacle avoidance by raycasts or spherecasts ahead of them, and keep a minimum height above ground. The reference project's flyers simply ignore ground obstacles whose top is below their body.
- **Vehicles and mounts.** A car cannot turn on the spot; follow a smoothed path with a look-ahead point (pure pursuit) instead of driving at each waypoint.
- **Non-Humanoid NPCs.** Movers (`AlignPosition` with `MaxVelocity` as speed) can follow waypoints exactly like `MoveTo`: set the goal to the next waypoint, advance when within a couple of studs. Jumps must be animated or simulated by you.
- **Giant bosses.** Usually better confined to an arena and moved directly; computing paths for a 20-stud agent through a decorated arena fails often and gains little.
- **Swimmers.** Water is traversable by default; set a `Water` cost so land routes are preferred when similar.

## 7. Debugging

- Turn on **Navigation mesh** and **Pathfinding modifiers** in Studio's viewport visualisation options; coloured areas are walkable or swimmable, arrows mark jump links (Docs).
- Draw the waypoints you got (small neon parts, client-only) and colour Jump and Custom ones differently.
- When `NoPath` appears, check: start or goal inside geometry (raise them 2 to 3 studs), agent too big for a gap, an invisible collider blocking a doorway, distance over 3,000 studs.
- Decorative parts with `CanCollide = true` (grass tufts, small rocks) carve holes in the navmesh. Make decor non-colliding ([[Collision and Physics Geometry]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Default agent size for big NPCs | Stuck under bridges and doors | Real radius and height per size class |
| Waiting on `MoveToFinished` forever | NPC freezes on a blocked waypoint | Per-waypoint timeout |
| Ignoring `Blocked` | NPC walks into a closed door | Recompute when blocked ahead |
| Recompute every frame | Server stalls | Timer, budget, direct movement near target |
| Goal inside a part | `NoPath` | Project the goal onto the floor |
| Paths over 3,000 studs | Fail | Chain via intermediate points |
| Client paths with streaming | Random failures | Server paths or persistent targets |

## Checklist
- [ ] Agent parameters match each NPC size class.
- [ ] Costs table includes danger labels and link labels.
- [ ] Follower has per-waypoint timeouts, stuck handling and blocked recompute.
- [ ] Direct movement used when the target is visible and close.
- [ ] Computations budgeted server-wide.
- [ ] Navmesh visualised after every level change.

## See also
[[NPC AI and Behaviour]] · [[Characters and Humanoids]] · [[Level Design for Roblox]] · [[Collision and Physics Geometry]] · [[Instance Streaming]] · [[Flight Flocks and Path Animation]]

## Nuances and edge cases

1. **Path cost scales with NPCs times frequency.** One NPC recomputing a path every second is nothing. Two hundred NPCs doing it every second on one server is a measurable share of server time, and the calls yield, so many in flight at once delay each other. Budget path requests per second server-wide, queue the rest, and give priority to NPCs near players.
2. **Most NPCs do not need a path most of the time.** If the target is visible and close (a clear raycast and under about 20 studs, rule of thumb), steer directly. Use pathfinding only when direct movement fails. This alone often cuts path requests by most of their volume.
3. **Groups need shared work.** Twenty enemies chasing one player compute twenty almost identical paths. Compute one path (or a flow field toward the player) and let followers offset from it. Flow fields pay off when many agents share few goals, such as tower defense or horde modes.
4. **Dynamic obstacles change the navigation mesh.** Doors opening, destructible walls and player-built structures update the navigation data, and paths computed before the change can become invalid. Listen for blocked waypoints and recompute, and avoid moving many obstacles constantly, which keeps the navigation data churning.
5. **Client versus server.** Server pathfinding sees the whole map; client pathfinding sees only what is streamed in, so client paths fail or take odd detours at the streaming edge. Keep authoritative NPC movement on the server, and use client pathfinding only for local helpers (a guide arrow) where failure is harmless.
6. **Network ownership of NPCs.** An unanchored NPC near a player may become owned by that player's client, which then simulates its movement; `MoveTo` calls from the server still work but movement looks different for each player. Set ownership to the server for NPCs whose position matters for combat.
7. **Large or unusual agents.** Agent radius and height must match the NPC, or big enemies try to fit through doors they cannot pass. For flying or swimming agents, built-in pathfinding is often the wrong tool; use waypoint graphs you author.
8. **Phones are not affected, players are.** Pathfinding runs on the server, so device type does not change its cost. What changes with device is how stuck or jittery NPCs look at low client frame rates; smooth the visual movement on the client if NPCs are replicated by position.

The senior trade-off: built-in pathfinding is excellent for occasional, varied routes and expensive for constant, crowded chasing. Most combat games combine it with direct steering, shared paths and simple local avoidance.

## Common mistakes (advanced)

1. **Pathfinding when the target is in plain sight.** Symptom: server time dominated by path computation. Fix: direct steering when line of sight is clear.
2. **Unbounded concurrent path requests.** Symptom: NPCs respond seconds late during big fights. Fix: a server-wide queue with a per-second budget.
3. **Each follower computing its own path to the same target.** Symptom: cost grows with group size. Fix: shared path or flow field.
4. **Client-owned NPCs.** Symptom: enemies teleport or slide differently for each player. Fix: server ownership for gameplay NPCs.
5. **Constantly moving obstacles.** Symptom: frequent path invalidations and stalls. Fix: keep moving obstacles few, or exclude them with modifiers and handle collisions locally.
6. **Agents with default size.** Symptom: large NPCs stuck in doorways. Fix: agent parameters from the NPC's real size.

## Related decisions

- [[Pathfinding Edge Cases and Fallbacks]]: what to do when a path fails.
- [[Behaviour Trees Utility AI and State Machines for NPCs]]: deciding when to path at all.
- [[Horror Monster Chase AI End to End]]: a chase AI combining paths and direct steering.
- [[Tower Defense Waves and Placement End to End]]: shared paths for many agents.
- [[Debugging Physics and Network Ownership]]: NPC ownership problems.
- [[Physics Performance]]: the server cost of many moving NPCs.
- [[Combat Arena and Encounter Layout]]: layouts that keep paths simple.
- [[Dungeon and Room Generation]]: validating generated levels with pathfinding.

## Connected notes
<!-- auto-links:start -->
[[Links - NPCs and AI]] · [[Links - Horror game mechanics]] · [[MCP Workflows for Building Worlds]] · [[Physics and Vehicles Start Here]] · [[Level Design Start Here]] · [[Roblox Studio Assistant]]
<!-- auto-links:end -->
