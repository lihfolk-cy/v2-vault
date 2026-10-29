---
tags: [reference, engine, workspace, api/Workspace, type/reference, area/scripting, level/intermediate, api/GetPartsInPart, api/GetPartBoundsInBox]
---

# Workspace - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: a raycast with a unit-length direction.
> - Avoid: Blockcast or Spherecast to find what is already overlapping.
> - Avoid: trusting GetPartBoundsInBox for precise hits.
> - Reuse RaycastParams and OverlapParams objects instead of rebuilding them per call.
> - Keep ray lengths at or below 15,000 studs.
> - Set streaming radii in Studio and test with streaming on.
>
> Cost: TL;DR ~130 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The service that holds the live 3D world, its physics settings, streaming and spatial queries (inherited from WorldRoot); see [[Raycast]], [[GetPartsInPart]], [[StreamingEnabled]] and [[Instance Streaming]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Gravity | prop | number (studs/s²) | 196.2 | Physics setting | No |
| [[CurrentCamera]] | prop | Camera | - | Not Replicated; each client sees its own | No |
| Terrain | prop | Terrain | - | Read only | No |
| FallenPartsDestroyHeight | prop | number (studs) | - | Clamped -50,000 to 50,000 | No |
| StreamingEnabled | prop | boolean | - | Turns on instance streaming | No |
| StreamingMinRadius | prop | number (studs) | 64 | Not Scriptable; set in Studio | No |
| StreamingTargetRadius | prop | number (studs) | 1024 | Not Scriptable; set in Studio | No |
| ModelStreamingBehavior / StreamOutBehavior | prop | Enum | - | Not Scriptable; streaming policy | No |
| TouchesUseCollisionGroups | prop | boolean | false | Not Scriptable | No |
| AirDensity / GlobalWind | prop | number / Vector3 | Sea-level density | Aerodynamics and wind | No |
| DistributedGameTime | prop | number (seconds) | - | Server: uptime. Client: time connected | No |
| Raycast | method | (origin: Vector3, direction: Vector3, params: RaycastParams?) -> RaycastResult? | - | Direction length is the ray length | No |
| Blockcast | method | (cframe, size, direction, params?) -> RaycastResult? | - | Skips parts it starts inside | No |
| Spherecast | method | (position, radius, direction, params?) -> RaycastResult? | - | Skips parts it starts inside | No |
| Shapecast | method | (part: BasePart, direction, params?) -> RaycastResult? | - | Sweeps a part's shape | No |
| GetPartBoundsInBox | method | (cframe: CFrame, size: Vector3, overlapParams?) -> {BasePart} | - | Bounding-box test, fast | No |
| GetPartBoundsInRadius | method | (position: Vector3, radius: number, overlapParams?) -> {BasePart} | - | Bounding-box test, fast | No |
| GetPartsInPart | method | (part: BasePart, overlapParams?) -> {BasePart} | - | Exact geometry test | No |
| BulkMoveTo | method | (partList, cframeList, eventMode: Enum.BulkMoveMode = FireAllEvents) -> () | - | FireCFrameChanged fires only CFrame Changed | No |
| GetServerTimeNow | method | () -> number | - | Shared clock across server and clients | No |
| GetRealPhysicsFPS / GetNumAwakeParts | method | () -> number | - | Physics diagnostics | No |
| FindPartOnRay | method | (ray, ...) | - | Deprecated: use Raycast | No |
| PersistentLoaded | event | (player: Player) | - | Listed on the page with a Player argument | - |

## Limits and defaults

- Gravity default: 196.2 studs/s².
- Raycast direction vector: at most 15,000 studs long.
- StreamingMinRadius default 64 studs; StreamingTargetRadius default 1024 studs.
- FallenPartsDestroyHeight: clamped between -50,000 and 50,000 studs.
- AirDensity falls to 5% of its ground value at 100,000 studs altitude.
- TouchesUseCollisionGroups default: false.

## Replication and authority

- Workspace content replicates from server to clients; with streaming on, distant parts may not exist on a client yet.
- CurrentCamera is local to each client and Not Replicated.
- Streaming radii, ModelStreamingBehavior, StreamOutBehavior and SignalBehavior are Not Scriptable: set them in Studio.
- DistributedGameTime differs per side, so use GetServerTimeNow for a shared clock.
- Spatial queries run on whichever side calls them and see only what that side has loaded.

## Common mistakes

- Avoid: a raycast with a unit-length direction. Symptom: it misses everything beyond 1 stud; multiply the direction by the range you need.
- Avoid: Blockcast or Spherecast to find what is already overlapping. Symptom: empty results; use GetPartsInPart or GetPartBoundsInBox.
- Avoid: trusting GetPartBoundsInBox for precise hits. Symptom: hits on hollow or rotated parts that do not really overlap; confirm with GetPartsInPart.
- Avoid: FindPartOnRay in new code. Symptom: deprecation warnings; Raycast with RaycastParams is current.
- Avoid: comparing DistributedGameTime across client and server. Symptom: timers disagree; use GetServerTimeNow.

## Checklist

- [ ] Reuse RaycastParams and OverlapParams objects instead of rebuilding them per call.
- [ ] Keep ray lengths at or below 15,000 studs.
- [ ] Set streaming radii in Studio and test with streaming on.
- [ ] Move many parts per frame with BulkMoveTo.

Source: https://create.roblox.com/docs/reference/engine/classes/Workspace, https://create.roblox.com/docs/reference/engine/classes/WorldRoot (verified 2026-10-29)

<!-- related:start -->
## Related
[[Raycasts Shapecasts and Spatial Queries]] · [[BasePart - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[PathfindingService - Engine Reference Card]] · [[PhysicsService - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]] · [[Terrain - Engine Reference Card]]
<!-- related:end -->
