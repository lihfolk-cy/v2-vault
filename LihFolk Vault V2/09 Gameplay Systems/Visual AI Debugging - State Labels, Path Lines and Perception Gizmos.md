---
tags: [gameplay, ai, debugging, gizmos, adornments, tooling, agents, npc, type/guide, area/gameplay, level/advanced, api/HandleAdornment, api/UnreliableRemoteEvent]
---
# Visual AI Debugging - State Labels, Path Lines and Perception Gizmos

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server-side neon debug parts -> Client adornments from a debug stream
> - Avoid: Debug for all NPCs -> Nearest plus selected only
> - Avoid: Records built for unwatched NPCs -> `isWatched` check first
> - Debug records defined; brains publish only when watched.
> - Unreliable channel, 4 to 5 Hz, size-capped records.
> - Pooled adornments with a fixed colour language and legend.
>
> Cost: TL;DR ~140 tok · whole note ~2.3k tok. Read more: ## 2. What to publish per NPC · ## 3. Client gizmo renderer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Behaviour Trees Utility AI and State Machines for NPCs]] lists the debugging tools every brain needs (state attribute, overhead label, trace buffer, freeze and step). This note is the implementation: a server-side **debug channel** that publishes what each brain thinks, a client **gizmo renderer** that draws it (perception cones, line-of-sight rays, path polylines, token holders, cover points), and a text snapshot format that AI agents working through Studio MCP can read when they cannot see the viewport well. The whole system costs nothing in production because it never runs for normal players.

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Principles

- **Brains run on the server; gizmos draw on the client.** The server knows the decision; only the client can render adornments without replicating hundreds of parts. Send compact debug records from server to client.
- **Opt-in per viewer.** Only players who pass an admin check (or anyone in Studio) receive debug data ([[Admin Commands Done Safely - Permissions and Audit Logs]]). Use `RunService:IsStudio()` for the Studio default (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/RunService#IsStudio).
- **Opt-in per NPC.** Debug "all" in a 200-enemy wave melts bandwidth. Default to the NPC nearest the viewer's camera, plus explicitly selected ones.
- **Never draw with server-created parts.** Neon debug parts created on the server replicate to everyone, are easy to leave behind, and alter raycasts if they collide or are queryable.

## 2. What to publish per NPC

| Field | Shape | Draw as |
|---|---|---|
| `state` | short string | Overhead label line 1 |
| `target` | player UserId or NPC id | Line from NPC to target, coloured by state |
| `lastDecision` | string + score | Label line 2 |
| `senses` | sight range, half-angle, hearing radius | Cone and circle on the ground |
| `lastSeen` | Vector3 + age | Ghost marker that fades with age |
| `path` | up to N waypoints (Vector3) | Polyline; jump waypoints in another colour |
| `losRays` | list of {from, to, hit} | Green clear, red blocked |
| `token` | holding? cost? committed? | Icon in label |
| `cover` | chosen point + candidates with scores | Spheres sized by score |

Throttle: 4 to 5 Hz per watched NPC is plenty for humans. Use an `UnreliableRemoteEvent` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent): dropped debug frames do not matter, and unreliable events never queue behind gameplay traffic. Keep each record small (quantise positions, cap waypoints to about 16) because unreliable payloads have a size limit; check the docs page for the current value.

```lua
--!strict
-- Server: debug publisher
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebugEvent = ReplicatedStorage:WaitForChild("AIDebug") :: UnreliableRemoteEvent

export type DebugRecord = {
	id: string, state: string, decision: string?,
	target: Vector3?, path: { Vector3 }?, sight: number?, fov: number?,
	los: { { Vector3 | boolean } }?,
}

local watchers: { [Player]: { [string]: boolean } } = {} -- viewer -> watched NPC ids

local AIDebug = {}

function AIDebug.isWatched(id: string): boolean
	for _, set in watchers do
		if set[id] then return true end
	end
	return false
end

function AIDebug.publish(rec: DebugRecord)
	for viewer, set in watchers do
		if set[rec.id] then
			DebugEvent:FireClient(viewer, rec)
		end
	end
end

function AIDebug.setWatch(viewer: Player, ids: { [string]: boolean }?)
	watchers[viewer] = ids -- called from a permission-checked admin command
end

return AIDebug
```

Brains call `AIDebug.isWatched(id)` before building a record so unwatched NPCs pay nothing.

## 3. Client gizmo renderer

Use **HandleAdornments** parented to a client folder with `Adornee = workspace.Terrain` (or any anchored part at the origin), so positions can be set in world space through `CFrame`:

| Gizmo | Class (**Roblox docs**) |
|---|---|
| Lines and rays | `LineHandleAdornment` (`Length`, `Thickness`, `CFrame`) |
| Points, last seen, cover | `SphereHandleAdornment` |
| Sight cone | `ConeHandleAdornment`, or a fan of lines |
| Areas, zones | `BoxHandleAdornment`, `CylinderHandleAdornment` |
| Labels | `BillboardGui` with `AlwaysOnTop = true` on the NPC's head |

Reference: https://create.roblox.com/docs/reference/engine/classes/HandleAdornment. Set `AlwaysOnTop = true` and `ZIndex` on adornments so they show through walls, which is the point of a debug view. Adornments do not collide, are not hit by raycasts and cost little, but still **pool** them: reuse a fixed set per NPC instead of destroying and recreating every update.

```lua
--!strict
local pool: { LineHandleAdornment } = {}
local folder = Instance.new("Folder")
folder.Name = "AIGizmos"
folder.Parent = workspace

local function line(i: number, a: Vector3, b: Vector3, color: Color3): LineHandleAdornment
	local l = pool[i]
	if not l then
		l = Instance.new("LineHandleAdornment")
		l.Adornee = workspace.Terrain
		l.AlwaysOnTop = true
		l.Thickness = 3
		l.Parent = folder
		pool[i] = l
	end
	l.CFrame = CFrame.lookAt(a, b)
	l.Length = (b - a).Magnitude
	l.Color3 = color
	l.Visible = true
	return l
end
```

After drawing a frame, hide pool entries beyond the count used. Clear everything when the debug channel stops sending (no record for 1 s).

Colour language (keep it consistent across the project): idle grey, patrol blue, alert yellow, chase orange, attack red, flee purple, return-home white. Put the legend in the debug panel.

## 4. Built-in Studio visualisers

Combine yours with what Studio already draws: navigation mesh and pathfinding modifiers, collision fidelity, decomposition geometry, and constraint details in the viewport's visualisation options ([[Pathfinding]] section 7). Your gizmos should not duplicate those; they should explain decisions.

## 5. Text snapshots for agents

AI agents controlling Studio through MCP can take screenshots, but text is cheaper and more reliable ([[Roblox Studio MCP Server]], [[MCP Workflows for Scripting and Debugging]]). Add a dev command that writes a compact snapshot for one NPC (or all NPCs within range) to the output:

```
[AI] Brute#14 state=Chase target=Player2 d=18.4 token=held(2,committed) path=7wp next=(102,4,-33) stuck=0.0s lastDecision=Chase(0.82)>Circle(0.40)
```

One line per NPC, fixed key order, no colour codes. An agent can run the snapshot, read the console, change config and re-run, closing the loop without screenshots. Include a "why not" field for the second-best option; most bugs are a wrong second choice.

## 6. Freeze, step, replay

- **Freeze**: a server flag that stops brain ticks (movement still settles). Combine with the gizmos to inspect a frozen fight.
- **Step**: tick one NPC once.
- **Record**: keep the last 10 s of debug records per watched NPC in a ring buffer on the client; scrub them with a slider. This is the cheapest way to diagnose "it did something weird a second ago".

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Server-side neon debug parts | Visible to players, block raycasts, leak | Client adornments from a debug stream |
| Debug for all NPCs | Bandwidth spikes in waves | Nearest plus selected only |
| Records built for unwatched NPCs | Server cost in production | `isWatched` check first |
| Reliable remotes for debug | Gameplay remotes delayed | Unreliable, throttled |
| Create/destroy adornments per frame | GC churn, flicker | Pool and hide |
| Debug channel open to everyone | Players see enemy plans | Admin and Studio only |

## Checklist
- [ ] Debug records defined; brains publish only when watched.
- [ ] Unreliable channel, 4 to 5 Hz, size-capped records.
- [ ] Pooled adornments with a fixed colour language and legend.
- [ ] Admin gate for live servers; Studio default on.
- [ ] One-line text snapshot command for agents.
- [ ] Freeze, step and a short record buffer available.

## See also
[[Behaviour Trees Utility AI and State Machines for NPCs]] · [[NPC AI and Behaviour]] · [[Pathfinding]] · [[Debugging Live Servers]] · [[Debugger Breakpoints and Logging]] · [[Running Many AI Agents on One Roblox Place]]

## Connected notes
<!-- auto-links:start -->
[[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Safety Rules for AI Agents in Studio]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Police Chases and Wanted Levels]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Hitboxes and Hit Detection]]
<!-- related:end -->
