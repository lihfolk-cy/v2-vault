---
tags: [reference, engine, camera, api/Camera, type/reference, area/scripting, level/intermediate, api/ViewportSize, api/FieldOfView]
---

# Camera - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: setting `camera.CFrame` while CameraType is still Custom.
> - Avoid: forgetting Focus on a Scriptable camera.
> - Avoid: placing GUI with WorldToViewportPoint.
> - Get the camera from Workspace.CurrentCamera, never a child named Camera.
> - Set CameraType to Scriptable before scripting CFrame, and restore Custom plus CameraSubject afterwards.
> - Pick the Screen or Viewport variant to match your GUI inset setting.
>
> Cost: TL;DR ~150 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Each client's view of the 3D world, reached through Workspace.CurrentCamera; see [[Camera]], [[Camera Systems]] and [[FieldOfView]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| CFrame | prop | CFrame | - | Default camera scripts overwrite it unless CameraType is Scriptable | No |
| Focus | prop | CFrame | Follows CameraSubject | Not auto-updated when Scriptable; set it every frame then | No |
| CameraType | prop | Enum.CameraType | - | Scriptable stops the default scripts moving the camera | No |
| CameraSubject | prop | Instance | Local character's Humanoid | Set back to the Humanoid to restore default follow | No |
| FieldOfView | prop | number (degrees, vertical) | 70 | Clamped 1-120 | No |
| FieldOfViewMode | prop | Enum.FieldOfViewMode | - | Works with DiagonalFieldOfView and MaxAxisFieldOfView | No |
| DiagonalFieldOfView | prop | number (degrees) | - | Not Replicated | No |
| MaxAxisFieldOfView | prop | number (degrees) | - | Longest viewport axis; Not Replicated | No |
| ViewportSize | prop | Vector2 | - | Read only; device safe area; updated only on [[CurrentCamera]] | No |
| NearPlaneZ | prop | number (studs) | -0.1 to -0.5 | Read only; varies by platform | No |
| HeadLocked | prop | boolean | true | VR head tracking combined into the view | No |
| HeadScale | prop | number | - | VR world scale for head movement | No |
| WorldToScreenPoint | method | (worldPoint: Vector3) -> (Vector3, boolean) | - | Accounts for GUI inset; X,Y pixels, Z depth, plus onScreen | No |
| WorldToViewportPoint | method | (worldPoint: Vector3) -> (Vector3, boolean) | - | Ignores GUI inset | No |
| ScreenPointToRay | method | (x, y, depth = 0) -> Ray | - | Unit ray; accounts for GUI inset | No |
| ViewportPointToRay | method | (x, y, depth = 0) -> Ray | - | Unit ray; ignores GUI inset | No |
| GetPartsObscuringTarget | method | (castPoints: {Vector3}, ignoreList: Instances) -> Instances | - | Parts blocking line of sight from the camera | No |
| GetRenderCFrame | method | () -> CFrame | - | The true rendered CFrame, including VR head | No |
| ZoomToExtents | method | (boundingBoxCFrame: CFrame, boundingBoxSize: Vector3) -> () | - | Frames a box | No |
| Interpolate | method | (endPos, endFocus, duration) -> () | - | Deprecated: tween CFrame and Focus with TweenService | No |

## Limits and defaults

- FieldOfView: 1-120 degrees, default 70.
- NearPlaneZ: between -0.1 and -0.5 studs depending on platform.
- ScreenPointToRay / ViewportPointToRay `depth` default: 0 studs.
- Cameras other than CurrentCamera (for example in a ViewportFrame) start with ViewportSize (1, 1).

## Replication and authority

- Each client has its own Camera in its local Workspace; the page tags the class Not Replicated, so server changes to it do not drive player views.
- Drive cameras from LocalScripts; send the server only what it needs (for example an aim direction) through remotes and validate it there.
- ViewportSize refreshes every frame during RunService.PreRender, only for the camera set as Workspace.CurrentCamera.

## Common mistakes

- Avoid: setting `camera.CFrame` while CameraType is still Custom. Symptom: the default scripts snap it back next frame; switch to Scriptable first.
- Avoid: forgetting Focus on a Scriptable camera. Symptom: lights and detail near the view render poorly; update Focus each frame at RenderPriority.Camera.
- Avoid: placing GUI with WorldToViewportPoint. Symptom: markers sit offset by the top bar; WorldToScreenPoint already includes the inset.
- Avoid: treating the onScreen boolean as visibility. Symptom: markers show through walls; the method does no raycast, so add one.
- Avoid: Camera:Interpolate in new code. Symptom: deprecation warnings; TweenService gives easing styles and reliable timing.

## Checklist

- [ ] Get the camera from Workspace.CurrentCamera, never a child named Camera.
- [ ] Set CameraType to Scriptable before scripting CFrame, and restore Custom plus CameraSubject afterwards.
- [ ] Pick the Screen or Viewport variant to match your GUI inset setting.
- [ ] Use GetRenderCFrame for VR-correct view math.

Source: https://create.roblox.com/docs/reference/engine/classes/Camera (verified 2026-10-29)

<!-- related:start -->
## Related
[[Workspace - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[BillboardGui - Engine Reference Card]] · [[GuiService - Engine Reference Card]] · [[Player - Engine Reference Card]]
<!-- related:end -->
