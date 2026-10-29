---
tags: [reference, engine, model, api/Model, type/reference, area/scripting, level/intermediate, api/PrimaryPart, api/WorldPivot, api/ScaleTo]
---

# Model - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: SetPrimaryPartCFrame in new code.
> - Avoid: Model:MoveTo when exact placement matters.
> - Avoid: MoveTo without a PrimaryPart. Symptom: an unpredictable root part is used; set PrimaryPart first.
> - Set PrimaryPart (or WorldPivot) deliberately for every movable model.
> - Move with PivotTo and read with GetPivot.
> - Scale with ScaleTo rather than resizing parts by hand.
>
> Cost: TL;DR ~140 tok · whole note ~1.1k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The grouping container for parts that move, stream and scale together; see [[Model]], [[Level of Detail and Model Streaming]] and [[Instance Streaming]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| PrimaryPart | prop | BasePart | nil | Characters use HumanoidRootPart; a non-descendant resets to nil next step | No |
| [[WorldPivot]] | prop | CFrame | - | Not Replicated; ignored when PrimaryPart is set | No |
| ModelStreamingMode | prop | Enum.ModelStreamingMode | - | Streaming only; set in Studio or server Scripts, never LocalScripts | No |
| LevelOfDetail | prop | Enum.ModelLevelOfDetail | - | StreamingMesh or SLIM stand-ins beyond the streaming radius | No |
| Scale | prop | number | 1 | Not Scriptable; use ScaleTo and GetScale | No |
| PivotTo | method | (targetCFrame: CFrame) -> () | - | The main way to move a model (from PVInstance) | No |
| GetPivot | method | () -> CFrame | - | Read the pivot before moving | No |
| MoveTo | method | (position: Vector3) -> () | - | Pushes the model upward out of obstructions | No |
| TranslateBy | method | (delta: Vector3) -> () | - | Keeps rotation; allows overlap | No |
| ScaleTo | method | (newScaleFactor: number) -> () | - | Scales around the pivot relative to scale 1 | No |
| GetScale | method | () -> number | - | Canonical scale factor | No |
| GetBoundingBox | method | () -> (CFrame, Vector3) | - | Orientation and size of the bounds | No |
| GetExtentsSize | method | () -> Vector3 | - | Size of the bounds | No |
| AddPersistentPlayer | method | (playerInstance: Player = nil) -> () | - | Needs ModelStreamingMode PersistentPerPlayer | No |
| RemovePersistentPlayer | method | (playerInstance: Player = nil) -> () | - | Undo the above | No |
| GetPersistentPlayers | method | () -> {Player} | - | Current persistent list | No |
| SetPrimaryPartCFrame | method | (cframe: CFrame) -> () | - | Deprecated: use PivotTo | No |
| GetPrimaryPartCFrame | method | () -> CFrame | - | Deprecated: use GetPivot | No |

## Limits and defaults

- Canonical scale starts at 1 for new models and changes only through ScaleTo.
- PrimaryPart is nil until you set it; Roblox characters set it to HumanoidRootPart.
- ModelStreamingMode has no effect while streaming is off.
- Composite or imposter LOD meshes have no physics, collision or raycasting.

## Replication and authority

- Models replicate like other Workspace content; with streaming on, ModelStreamingMode controls how each model streams in and out (PersistentPerPlayer enables per-player persistence).
- Set ModelStreamingMode from Studio or server Scripts, not LocalScripts.
- WorldPivot is tagged Not Replicated; the pivot follows the PrimaryPart when one exists.
- PivotTo skips Changed events for parts' Position and Orientation for speed; CFrame changes still apply.

## Common mistakes

- Avoid: SetPrimaryPartCFrame in new code. Symptom: deprecation warnings; PivotTo is the current way.
- Avoid: Model:MoveTo when exact placement matters. Symptom: the model pops upward onto whatever is in the way; use PivotTo or TranslateBy.
- Avoid: MoveTo without a PrimaryPart. Symptom: an unpredictable root part is used; set PrimaryPart first.
- Avoid: setting PrimaryPart to a part outside the model. Symptom: it silently resets to nil on the next step.
- Avoid: expecting Position Changed listeners to fire after PivotTo. Symptom: silent listeners; watch CFrame instead.

## Checklist

- [ ] Set PrimaryPart (or WorldPivot) deliberately for every movable model.
- [ ] Move with PivotTo and read with GetPivot.
- [ ] Scale with ScaleTo rather than resizing parts by hand.
- [ ] Choose a ModelStreamingMode for models clients must always have, and test with streaming on.

Source: https://create.roblox.com/docs/reference/engine/classes/Model, https://create.roblox.com/docs/reference/engine/classes/PVInstance (verified 2026-10-29)

<!-- related:start -->
## Related
[[BasePart - Engine Reference Card]] · [[Workspace - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[PathfindingService - Engine Reference Card]] · [[ProximityPrompt - Engine Reference Card]]
<!-- related:end -->
