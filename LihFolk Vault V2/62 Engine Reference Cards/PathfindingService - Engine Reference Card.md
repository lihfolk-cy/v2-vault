---
tags: [reference, engine, pathfindingservice, api/PathfindingService, type/reference, area/scripting, level/intermediate, api/Path, api/ComputeAsync]
---

# PathfindingService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: computing a path without pcall. Symptom: a thrown error stops the NPC script; wrap `ComputeAsync` and check `Status`.
> - Avoid: calling `MoveTo` on the final waypoint only.
> - Avoid: ignoring `Blocked`. Symptom: NPCs walk into doors or debris that appeared after the compute; recompute when the blocked...
> - One Path per agent, created with parameters that match the rig size.
> - Waypoint loop handles Jump and custom Label actions.
> - Blocked handling, timeout fallback and a give-up rule are in place.
>
> Cost: TL;DR ~170 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Builds navigation paths for NPCs through `CreatePath` and the `Path` object it returns; see [[PathfindingService]], [[Pathfinding]] and [[Pathfinding Edge Cases and Fallbacks]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| PathfindingService:CreatePath | method | `(agentParameters: {[string]: any}?) -> Path` | defaults below | Usually server, where NPCs live | no |
| Path:ComputeAsync | method | `(start: Vector3, finish: Vector3) -> ()` | - | Call again whenever the path must update; wrap in pcall | yes |
| Path.Status | prop | `Enum.PathStatus` | - | `Success` when a route exists; otherwise a failure value such as `NoPath` | no |
| Path:GetWaypoints | method | `() -> {PathWaypoint}` | - | Empty array when no path was found | no |
| Path.Blocked | event | `(blockedWaypointIdx: int)` | - | Can fire for a waypoint behind the agent | - |
| Path.Unblocked | event | `(unblockedWaypointIdx: int)` | - | Can also fire behind the agent | - |
| AgentRadius | param | integer (studs) | 2 | Minimum horizontal clearance | - |
| AgentHeight | param | integer (studs) | 5 | Minimum vertical clearance | - |
| AgentCanJump | param | boolean | true | Allows Jump waypoints | - |
| AgentCanClimb | param | boolean | false | Climb TrussParts; waypoints labeled "Climb" | - |
| WaypointSpacing | param | number (studs) | 4 | `math.huge` removes intermediate waypoints | - |
| Costs | param | table | `{}` | Material names or modifier labels to cost | - |
| PathWaypoint.Action | datatype field | `Enum.PathWaypointAction` | - | Walk, Jump or Custom | - |
| PathWaypoint.Label | datatype field | string | - | Names a PathfindingLink or "Climb" | - |
| Humanoid:MoveTo + MoveToFinished | method / event | `(location: Vector3)` / `(reached: boolean)` | - | Drives the agent between waypoints | no |

Retired names and their replacements:
- `FindPathAsync` -> `CreatePath()` then `Path:ComputeAsync()` (reuses one Path with custom parameters).
- `ComputeRawPathAsync`, `ComputeSmoothPathAsync`, `EmptyCutoff` -> the same CreatePath flow.
- `Path:GetPointCoordinates` -> `GetWaypoints`; `Path:CheckOcclusionAsync` -> the `Blocked` event.

## Limits and defaults

- Straight-line distance from start to finish must be 3,000 studs or less.
- A compute may run out of its 20,000-node budget well before 3,000 studs in large open worlds or mazes.
- Waypoints whose bottom Y is below -65,536 or above 65,536 studs are ignored.
- Every material costs 1 by default; `math.huge` makes a material or modifier label untraversable, while a high finite cost such as 100 keeps it as a last resort.
- `Humanoid:MoveTo` times out after 8 seconds, so step one waypoint at a time.

## Replication and authority

- `Path` is NotCreatable and NotReplicated; compute it where the agent is simulated, normally the server.
- Region rules come from `PathfindingModifier` instances (Label, PassThrough) and gaps from `PathfindingLink` with two Attachments.
- Studio can draw the navigation mesh and modifier labels from the visualization options for debugging.

## Common mistakes

- Avoid: computing a path without pcall. Symptom: a thrown error stops the NPC script; wrap `ComputeAsync` and check `Status`.
- Avoid: calling `MoveTo` on the final waypoint only. Symptom: the 8-second timeout cuts long walks short and the NPC ignores the route.
- Avoid: ignoring `Blocked`. Symptom: NPCs walk into doors or debris that appeared after the compute; recompute when the blocked index is ahead of the agent.
- Avoid: agent parameters larger than the level allows. Symptom: `NoPath` because the agent is too tall or cannot jump to the only route.
- Avoid: recomputing every frame. Symptom: server time spikes; recompute on a timer or when the target moves far.

## Checklist

- One Path per agent, created with parameters that match the rig size.
- Waypoint loop handles Jump and custom Label actions.
- Blocked handling, timeout fallback and a give-up rule are in place.
- Long trips are split so each request stays under 3,000 studs.

Source: https://create.roblox.com/docs/reference/engine/classes/PathfindingService, https://create.roblox.com/docs/reference/engine/classes/Path and https://create.roblox.com/docs/characters/pathfinding - verified 2026-10-29

<!-- related:start -->
## Related
[[Humanoid - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Workspace - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[HttpService - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]]
<!-- related:end -->
