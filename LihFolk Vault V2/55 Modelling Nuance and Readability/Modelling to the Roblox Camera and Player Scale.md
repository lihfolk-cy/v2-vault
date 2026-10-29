---
tags: [modeling, camera, scale, studs, avatar, field-of-view, readability, blender, luau, studio, type/guide, area/modeling]
---
# Modelling to the Roblox Camera and Player Scale

<!-- tldr:start -->
> [!tldr] TL;DR
> - Model great in Blender, tiny in game: Judged from a close viewport with a wide lens -> Use the matched 70-degree vertical camera at real distances
> - Unfinished sides visible on phones: Framing tested on 16:9 only -> Test at 2.17 aspect; finish sides within the wider view
> - Camera keeps clipping indoors: Real-world ceiling heights -> 2 to 3 avatar heights indoors
> - Avatar proxies (5 and 6.5 studs) in every modelling file.
> - Blender camera at 70 degrees vertical, phone aspect, real distances.
> - Key features checked against `d / 260` studs at their usual distance.
>
> Cost: TL;DR ~180 tok · whole note ~3.9k tok. Read more: ## From studs to pixels · ## Worked example: measuring screen size in Studio · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most modelling mistakes that show up in Roblox playtests are not modelling mistakes. They are framing mistakes: the model was judged from a Blender viewport at a distance, angle and field of view the player never uses, beside no avatar, at a scale nobody checked. This note gives the numbers that tie a model to how Roblox actually shows it: stud scale, avatar heights, the default camera's field of view and zoom, the formula that turns a size in studs into pixels on a phone, how screen shape changes what the player sees, and how to set up Blender and Studio so you judge models the way players will.

Other notes in this folder use the pixel figures derived here. [[Camera Systems]] covers camera scripting; [[Avatar Body Types and Scale in Gameplay]] covers avatar variety in gameplay; this note is about the modeller's side.

## The fixed numbers

| Fact | Value | Source |
|---|---|---|
| Stud length | 1 stud = 0.28 metres (28 cm) | Roblox docs, units page (as of October 2026) |
| Default camera vertical field of view | 70 degrees, clamped 1 to 120 | Roblox docs, `Camera.FieldOfView` (as of October 2026) |
| Field of view axis | Vertical; horizontal follows the screen's aspect ratio | Roblox docs, `Camera.FieldOfView` |
| Near clip plane | Between 0.1 and 0.5 studs in front of the camera, varies by platform | Roblox docs, `Camera.NearPlaneZ` |
| Default jump height | 7.2 studs (`CharacterJumpHeight`); jump power 50 | Roblox docs, Humanoid page |
| Default walk speed | 16 studs per second | Roblox docs, Humanoid page |
| Default max slope | 89 degrees | Roblox docs, Humanoid page |
| Classic blocky avatar | About 5 studs tall | Vault note on avatar body types |
| Realistic-proportion avatar | About 6 to 6.5 studs tall | Vault note on avatar body types (docs) |
| Default max zoom distance | 400 studs | Vault note [[Level Design for Roblox]]; not stated on the current StarterPlayer reference page, so check your Studio's Properties panel |
| Default min zoom distance | 0.5 studs | Rule of thumb from Studio defaults; not stated on the docs page |
| Starting camera distance | About 12 to 13 studs behind the character | Rule of thumb; set by the default camera scripts and not documented |

The 0.28-metre stud means a 5-stud avatar is about 1.4 metres tall in "real" units, and a 6.5-stud one about 1.8 metres. If you model in metres in Blender and convert at export, keep that ratio in mind: a "real" 2-metre door is about 7.1 studs, which is tight for tall avatars with hats. See [[Proportion Exaggeration and Gameplay Distance]] for door sizing.

## From studs to pixels

The single most useful formula for a Roblox modeller:

`pixels = size_in_studs * screen_height_pixels / (2 * distance * tan(FOV / 2))`

With the default 70-degree vertical field of view, `2 * tan(35 degrees)` is about 1.40, so:

`pixels = size * screen_height / (1.40 * distance)`

The screen height that matters is the **render** height, not the marketing resolution. Phones often render below their native resolution, and Roblox may scale render resolution on some devices; the exact values are not documented (as of October 2026). Use about 720 pixels as a conservative phone figure and 1080 for a typical PC monitor (rule of thumb).

| Object | Size | Distance | Phone (720 px) | PC (1080 px) |
|---|---|---|---|---|
| Classic avatar | 5 studs | 12.5 studs (start zoom) | about 205 px | about 310 px |
| Classic avatar | 5 studs | 40 studs | about 64 px | about 96 px |
| Enemy | 8 studs | 60 studs | about 69 px | about 103 px |
| Door frame trim | 0.2 studs | 15 studs | about 7 px | about 10 px |
| Window bar | 0.1 studs | 40 studs | about 1.3 px | about 1.9 px |
| Landmark tower | 40 studs | 300 studs | about 69 px | about 103 px |

Inverted, one pixel on a 720-pixel phone at distance `d` covers about `d / 520` studs. That is the rule the other notes in this folder use: features under about 2 pixels flicker or vanish, so the smallest reliable feature is about `d / 260` studs, and a comfortable one about `d / 170`.

Two lessons sit in this table. First, a 0.1-stud window bar is invisible at 40 studs on a phone, however carefully it was modelled. Second, a 40-stud tower at 300 studs is the same screen size as an 8-stud enemy at 60 studs, which is why landmarks can be simple: they are never seen large.

## Screen shape changes what the player sees

Because Roblox keeps the vertical field of view fixed and derives the horizontal one from the aspect ratio, wider screens see more of the world sideways:

`horizontal FOV = 2 * atan(tan(35 degrees) * aspect)`

| Device shape | Aspect | Horizontal FOV |
|---|---|---|
| 4:3 tablet | 1.33 | about 86 degrees |
| 16:9 monitor or TV | 1.78 | about 102 degrees |
| 19.5:9 or 20:9 modern phone | 2.17 to 2.22 | about 113 degrees |

For modellers this means:

- **Wide phones see past the edges** of set dressing designed on a 16:9 monitor. A building facade that ends just off-screen on PC can show its unfinished side on a phone.
- **Tablets see less sideways but the same vertically**, so vertical framing (a tall gate filling the screen) is consistent across devices while horizontal framing is not.
- **Phone UI covers more of the screen** (thumbstick, jump button, menus). The effective view is smaller than the raw numbers suggest, and important models should not rely on the screen corners. See [[Responsive UI for Phone Tablet Console and PC]].

## The default camera's angle

The default follow camera orbits a point near the character's head and starts behind it, slightly above, looking down. Players then orbit freely, but most play happens with the camera somewhat above the character, looking down at roughly 10 to 40 degrees (rule of thumb from watching play sessions; not a documented value). Consequences already used in [[Shape Language and Silhouette Testing]] and [[Spending Triangles Where the Camera Looks]]:

- Top surfaces are seen constantly, undersides almost never.
- The player's own avatar is mostly seen from behind.
- Horizons and skylines appear in the top third of the screen, so skyline silhouettes matter.
- Tall props near the path block the camera, which then zooms in (the default occlusion mode is `Zoom`, per the StarterPlayer docs).

Games that change the camera change all of this. A top-down camera (camera at 60 to 80 degrees) makes top shapes the entire read and side silhouettes irrelevant. A first-person game makes the held item and close walls the most-seen models and puts the near clip plane in play: anything within about 0.5 studs of the camera can be cut away (docs), so first-person tools must sit at least that far in front of the camera.

## Player scale: building the world in avatar units

Model the world in avatar units, not in metres. A short reference list (rule of thumb, stylised third-person game, classic and mixed avatars):

| Element | Size in avatar heights | Classic 5-stud avatar |
|---|---|---|
| Door height | 1.4 to 1.6 | 7 to 8 studs |
| Door width | 0.8 to 1.2 | 4 to 6 studs |
| Corridor width | 1.6 to 2.4 | 8 to 12 studs (leaves room for the camera) |
| Ceiling height indoors | 2 to 3 | 10 to 15 studs (lower ceilings fight the camera) |
| Table top | 0.5 to 0.6 | 2.5 to 3 studs |
| Step rise | 0.2 to 0.3 | 1 to 1.5 studs |
| Low wall the player can see over | under 0.6 | under 3 studs |
| Jumpable obstacle | under 1.2 | under about 6 studs (default jump 7.2 studs) |

Indoor spaces need more height than real buildings because the third-person camera sits above and behind the head. A real 2.5-metre ceiling (about 9 studs) puts the camera into the ceiling when the player zooms out. Interiors built at 2 to 3 avatar heights avoid constant camera pops.

## Worked example: a Blender camera that matches Roblox

Set this up once in a template .blend and judge every model through it (Blender manual: camera properties, sensor fit, field of view).

1. **Scale.** Decide the unit mapping used by your pipeline (see [[Exporting and Validating Models for Roblox]]) and model so that 1 Blender unit equals 1 stud in the template, or keep a known conversion factor.
2. **Avatar proxies.** Add two simple proxies: a 5-stud classic figure and a 6.5-stud tall figure, origin at the feet. Keep them in a collection named `Scale_Ref` that is hidden from export.
3. **Camera.** Add a camera. In Camera properties set Lens Unit to **Field of View**, Sensor Fit to **Vertical**, and Field of View to **70 degrees**. With vertical sensor fit, the field of view value is the vertical angle, matching Roblox.
4. **Resolution.** Output properties: 1560 by 720 (a 2.17 phone aspect) for the phone camera, and duplicate the scene camera setup at 1920 by 1080 for a PC check.
5. **Position.** Put the camera about 12.5 units behind the proxy's head height, about 3 to 4 units above it, and pitch it down about 15 to 20 degrees so it looks at the head. Add a Track To constraint targeting an empty at the proxy's head to keep it aimed while you move it.
6. **Distance presets.** Add markers on the timeline and keyframe the camera at 12.5, 25, 40 and 80 units back. Scrubbing between markers shows the model at each gameplay band.
7. **Judge in render preview.** Use the camera view (Numpad 0) with the viewport set to Rendered or Solid with your matcap, at the output resolution. Turn on the Safe Areas overlay to see what a 16:9 crop cuts off.

## Worked example: measuring screen size in Studio

The Blender camera is an estimate. Studio can measure real pixel sizes under the actual camera. This command bar script reports the on-screen height of the selected model from the current Studio camera, and what that would be on a 720-pixel phone. It uses `Camera:WorldToViewportPoint` and `Camera.ViewportSize` from the Roblox docs (as of October 2026).

```lua
-- Command bar (Edit mode): on-screen height of the selected Model or BasePart.
local Selection = game:GetService("Selection")
local camera = workspace.CurrentCamera
local TARGET_HEIGHT = 720 -- conservative phone render height

local target = Selection:Get()[1]
assert(target, "Select a Model or BasePart first")

local cf, size
if target:IsA("Model") then
	cf, size = target:GetBoundingBox()
elseif target:IsA("BasePart") then
	cf, size = target.CFrame, target.Size
else
	error("Select a Model or BasePart")
end

local minY, maxY = math.huge, -math.huge
local half = size / 2
for _, sx in { -1, 1 } do
	for _, sy in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
			local screen, onScreen = camera:WorldToViewportPoint(corner)
			if onScreen then
				minY = math.min(minY, screen.Y)
				maxY = math.max(maxY, screen.Y)
			end
		end
	end
end

if minY == math.huge then
	warn("Model is not on screen")
else
	local pixels = maxY - minY
	local scaled = pixels * TARGET_HEIGHT / camera.ViewportSize.Y
	local distance = (camera.CFrame.Position - cf.Position).Magnitude
	print(string.format("%s: %.0f px here, about %.0f px on a %d px phone, %.1f studs away",
		target.Name, pixels, scaled, TARGET_HEIGHT, distance))
end
```

Fly the Studio camera to a typical player position (or use Play and run the same logic from a LocalScript), select a model, and run it. The bounding box overestimates rotated models a little; for a quick readability check that is fine. Compare the number with the thresholds in [[Shape Language and Silhouette Testing]]: important assets at least 30 to 40 pixels at their usual distance.

Note that the Studio field of view may differ if your game sets `FieldOfView` or if a camera effect is active; the script uses whatever the camera currently has.

## Edge cases

- **Games that change field of view.** Sprint effects of +6 to +10 degrees (see [[Camera Systems]]) shrink everything slightly. Games that lower the field of view (zoomed aim, binocular modes) magnify, so distant models get judged closer than designed.
- **Scaled characters.** Games that scale all avatars up (for a chunky look) or down change every proportion in the table above. Fix the avatar scale before modelling the world, and rebuild the reference proxies to match.
- **Console and TV.** A TV is large but far from the viewer, so its effective pixel size is similar to a monitor's, and UI safe areas apply. See [[Gamepad and Console UX]].
- **VR.** VR uses its own field of view and true stereo scale; the docs recommend standard Roblox units for VR compatibility (units page). Exaggerated scale that reads well on a flat screen can feel wrong in VR.
- **Thumbnails and icons.** Store thumbnails and item icons are framed by a separate camera, often with a narrow field of view. Models that only look good from the gameplay camera can look odd in a 20-degree icon render. See [[Icon and Thumbnail Rendering Pipeline]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Model great in Blender, tiny in game | Judged from a close viewport with a wide lens | Use the matched 70-degree vertical camera at real distances |
| Unfinished sides visible on phones | Framing tested on 16:9 only | Test at 2.17 aspect; finish sides within the wider view |
| Camera keeps clipping indoors | Real-world ceiling heights | 2 to 3 avatar heights indoors |
| Tall avatars stuck or clipping | Openings sized for the classic avatar | Use both proxies; size for the tallest allowed avatar |
| First-person tool cut away | Tool closer than the near clip plane | Keep it at least 0.5 studs in front of the camera |
| Thin features invisible on phones | Sized above 1 pixel on PC but under 1 pixel on phone | Size for 720-pixel render height, at least `d / 260` studs |
| World feels too big or too small | Modelled in metres without checking the 0.28 m stud | Model in avatar units with proxies |

## Checklist

- [ ] Avatar proxies (5 and 6.5 studs) in every modelling file.
- [ ] Blender camera at 70 degrees vertical, phone aspect, real distances.
- [ ] Key features checked against `d / 260` studs at their usual distance.
- [ ] Framing tested on 4:3, 16:9 and about 2.17 aspect.
- [ ] Indoor heights 2 to 3 avatar heights; doors 1.4 to 1.6.
- [ ] First-person items outside the near clip distance.
- [ ] On-screen pixel size measured in Studio for key assets.
- [ ] Field of view effects and character scaling accounted for.

## Related

- [[Camera Systems]]
- [[Avatar Body Types and Scale in Gameplay]]
- [[Level Design for Roblox]]
- [[Level Design Principles - Flow Sightlines and Landmarks]]
- [[Exporting and Validating Models for Roblox]]
- [[Responsive UI for Phone Tablet Console and PC]]
- [[Icon and Thumbnail Rendering Pipeline]]
- [[Scale and Animation]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Shape Language and Silhouette Testing]]
- [[Spending Triangles Where the Camera Looks]]
- [[Modelling Nuance Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Critiquing a Model - Paintovers and Iteration]] · [[Style Bibles for Consistent Models]] · Choosing GUI 2D or Locked-Camera 2.5D · Cameras and Cutscenes · Side-Scroller in 3D - Locking Camera and Movement to a Plane
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Voxel Scale Grids and Stud Alignment]] · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Blender Workflow for Roblox Creators]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] · [[Choosing GUI 2D or Locked-Camera 2.5D]]
<!-- related:end -->
