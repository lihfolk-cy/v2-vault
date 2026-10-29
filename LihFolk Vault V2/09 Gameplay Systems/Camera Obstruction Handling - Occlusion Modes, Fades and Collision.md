---
tags: [gameplay, camera, occlusion, invisicam, spherecast, transparency, level-design, type/guide, area/gameplay, level/advanced, api/Camera, api/WorldRoot]
---
# Camera Obstruction Handling - Occlusion Modes, Fades and Collision

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Decorative walls with `CanCollide = false` in Zoom mode -> Collision on shells, or custom occluder rules
> - Avoid: Invisicam on single huge parts -> Split walls; or zoom mode indoors
> - Avoid: Raycast instead of spherecast -> Spherecast with radius 0.5 to 1
> - Occlusion mode chosen per area (zoom outdoors, invisicam or zoom-limit indoors).
> - Decorative and thin props excluded from occlusion deliberately.
> - Custom cameras spherecast from the pivot with instant-in, slow-out.
>
> Cost: TL;DR ~160 tok · whole note ~2.3k tok. Read more: ## 1. The two built-in modes · ## 3. Custom fades · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every third-person game eventually puts a wall between the camera and the character. Roblox gives you two built-in answers (`Zoom` and `Invisicam`) through `DevCameraOcclusionMode`, and both have edge cases that show up as "camera keeps snapping in" or "I can see through the map". Custom cameras (shoulder, chase, top-down) bypass both and need their own collision. This note is the decision guide and the gotchas; base camera architecture is in [[Camera Systems]].

Source labels: **Roblox docs**, **PlayerModule source** (behaviour read from the default camera scripts, which Roblox can change between releases), **Rule of thumb**.

---

## 1. The two built-in modes

`StarterPlayer.DevCameraOcclusionMode` sets the default for new players; `Player.DevCameraOcclusionMode` can change it per player at runtime (**Roblox docs**: https://create.roblox.com/docs/reference/engine/enums/DevCameraOcclusionMode).

| Mode | What it does | Good for | Bad for |
|---|---|---|---|
| `Zoom` | Pulls the camera in front of the nearest obstruction | Outdoor maps, obbies, most games | Tight interiors (camera jams into the head), dense foliage (constant popping) |
| `Invisicam` | Keeps the camera distance and makes obstructing parts transparent locally | Interiors, top-down-ish cameras, building games | Maps built from huge single parts (a whole wall vanishes), horror (reveals what is behind walls) |

### Zoom gotchas (PlayerModule source)
The zoom controller ("Popper") decides what can occlude. In current source a part only blocks the camera if it is mostly opaque, has `CanCollide` on, is not part of the subject's own assembly, and is not a `TrussPart`. Consequences:
- **Non-collidable walls do not stop the camera.** Decorative shells with `CanCollide = false` let the camera pass through into the void. Give the visual shell collision, or add an invisible-but-opaque-to-camera solution of your own.
- **Glass and fences with high transparency are ignored**, which is usually what you want.
- **Trusses never occlude.**

Because this is script behaviour, not engine contract, re-check it when you fork the PlayerModule.

### Invisicam gotchas
- It fades parts by setting `LocalTransparencyModifier`, which is client-only and never replicates (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier). Your own scripts that also write `LocalTransparencyModifier` (first-person body hiding, ghost effects) will be overwritten or will overwrite it.
- Granularity is the part: one 200-stud wall part disappears entirely. Split large walls at about room width.
- It reveals hidden rooms, secret areas and monsters. Horror and hide-and-seek games should prefer zoom or a custom fade with exclusions.

## 2. Map-side fixes beat code

**Rule of thumb.** Most obstruction complaints are fixed in the map, not the camera:
- Ceilings at least 12 to 14 studs in player areas used by a default-distance camera; narrow corridors at least 8 studs wide.
- Put thin foliage, lamp posts and railings in a collision group or set `CanQuery = false` if they should never block (parts with `CanQuery = false` are skipped by raycasts and spatial queries; **Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/BasePart#CanQuery). Check gameplay raycasts still behave.
- Interiors: switch the player to `Invisicam` or shorten `CameraMaxZoomDistance` while inside; restore outside. Drive it from your zone system ([[Zone and Biome Art Direction]]).

## 3. Custom fades

For a top-down or isometric camera, fade only what is *between* the camera and the character, and only categories you allow (tag `CameraFade`).

```lua
--!strict
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
local faded: { [BasePart]: boolean } = {}
local FADE = 0.7

RunService:BindToRenderStep("OccluderFade", Enum.RenderPriority.Camera.Value + 2, function()
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and root) then return end

	local points = { root.Position, root.Position + Vector3.new(0, 2.5, 0) }
	local hits = camera:GetPartsObscuringTarget(points, { char })
	local now: { [BasePart]: boolean } = {}
	for _, inst in hits do
		if inst:IsA("BasePart") and CollectionService:HasTag(inst, "CameraFade") then
			now[inst] = true
			inst.LocalTransparencyModifier = FADE
		end
	end
	for part in faded do
		if not now[part] then
			part.LocalTransparencyModifier = 0
		end
	end
	faded = now
end)
```

`Camera:GetPartsObscuringTarget(castPoints, ignoreList)` returns parts between the camera and each cast point (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Camera#GetPartsObscuringTarget). Two cast points (feet and head) avoid flicker when only half the body is hidden. For a smooth fade, tween a per-part value toward the target instead of setting it instantly; avoid `TweenService` per part per frame, lerp in the same loop.

## 4. Custom camera collision

A custom camera (shoulder, chase, orbit) must do what Popper does: shorten the boom when something is in the way.

- Cast a **sphere**, not a ray: `Workspace:Spherecast(origin, radius, direction, params)` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Spherecast). A ray lets the near clip plane slice into the wall; a sphere of radius 0.5 to 1 keeps it out.
- **Origin is the pivot**, not the root part: the head or shoulder point. Casting from the root lets the camera go under low ceilings.
- **Exclude** the character, vehicles the player is in, and anything tagged non-occluding, with `RaycastParams.FilterType = Exclude`.
- **Asymmetric smoothing**: move *in* instantly (never show the inside of a wall), move *out* slowly (half-life 0.2 to 0.4 s) so the boom does not pump when passing pillars.
- **Minimum distance**: if the boom drops under about 1.5 studs, switch to first-person-like framing or fade the character with `LocalTransparencyModifier`, or the screen fills with the back of the head.

```lua
--!strict
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local current = 12
local function boomLength(pivot: Vector3, dir: Vector3, wanted: number, exclude: { Instance }, dt: number): number
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Spherecast(pivot, 0.75, dir.Unit * wanted, params)
	local target = if hit then math.max(hit.Distance - 0.2, 0.5) else wanted
	if target < current then
		current = target -- in: instant
	else
		current += (target - current) * (1 - math.exp(-dt * 3)) -- out: slow
	end
	return current
end
```

## 5. Testing obstruction

- Walk every interior and corridor with the shipped zoom limits on phone aspect ratios (tall phones see more vertically).
- Back the character into each corner and rotate 360 degrees.
- Test under a low ceiling while jumping; test against moving parts (doors, elevators), which should usually not occlude.
- Watch for flicker: two cast points, and hysteresis on fades.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Decorative walls with `CanCollide = false` in Zoom mode | Camera clips into the void | Collision on shells, or custom occluder rules |
| Invisicam on single huge parts | Whole building vanishes | Split walls; or zoom mode indoors |
| Raycast instead of spherecast | Near plane slices walls | Spherecast with radius 0.5 to 1 |
| Symmetric boom smoothing | Camera clips then pumps | Instant in, slow out |
| Two systems writing `LocalTransparencyModifier` | Parts stuck invisible | One owner, restore on exit |
| Fading everything | Players see through to secrets | Tag what may fade |

## Checklist
- [ ] Occlusion mode chosen per area (zoom outdoors, invisicam or zoom-limit indoors).
- [ ] Decorative and thin props excluded from occlusion deliberately.
- [ ] Custom cameras spherecast from the pivot with instant-in, slow-out.
- [ ] Fades limited to tagged parts and always restored.
- [ ] Corners, low ceilings and tall-phone aspect tested.

## See also
[[Camera Systems]] · [[Cameras and Cutscenes]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Level Design for Roblox]] · [[Modelling to the Roblox Camera and Player Scale]] · [[Chase Cameras and Speed Effects for Vehicles]]

## Connected notes
<!-- auto-links:start -->
[[Layering Camera Feedback on the Default Camera]] · Motion Sensitivity and Camera Comfort · Genre Playbook - Horror and Story
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Pathfinding]] · [[Physics Assemblies and Constraints]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Custom Character Controllers]]
<!-- related:end -->
