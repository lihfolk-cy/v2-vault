---
tags: [ui, minimap, world-map, hud, fog-of-war, editableimage, type/guide, area/ui, level/intermediate, api/CanvasGroup, api/EditableImage, api/ViewportFrame]
---
# Minimap and World Map UI - Projection, Rotation and Fog of War

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Origin typed twice -> One shared `MapSpec`
> - Avoid: Non-square image for a non-square world -> Pad world rect to square
> - Avoid: Rotating a frame with `ClipsDescendants` -> `CanvasGroup` window, rotate an inner frame
> - One projection spec shared by capture and UI; map up = world -Z.
> - Map image square, aligned, and within the upload size limit (tiles if not).
> - Rotating map uses a CanvasGroup window; upright icons counter-rotated.
>
> Cost: TL;DR ~150 tok · whole note ~2.5k tok. Read more: ## 2. Rendering the map surface · ## 3. Fixed versus rotating minimap · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A minimap is a coordinate transform plus a clipping problem plus a performance budget. The transform is easy; the bugs come from clipping rotated content, markers that drift because the map image was not aligned to the world, ViewportFrame minimaps that cost more than the rest of the HUD, and fog of war that eats the client's image budget. This note covers the projection, fixed versus rotating maps, the three ways to render the map surface, markers, and a fog-of-war mask. Where the minimap sits on screen and how it scales is in [[HUD Design]] and [[Responsive UI for Phone Tablet Console and PC]].

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, **reviewed, not run**.

---

## 1. The projection

Pick a world rectangle the map image covers: an origin (the world X/Z of the image's top-left corner) and a size in studs. Then:

```lua
--!strict
-- ReplicatedStorage/MapProjection
export type MapSpec = { originX: number, originZ: number, sizeX: number, sizeZ: number }

local MapProjection = {}

-- World position -> 0..1 UV on the map image (top-left = 0,0).
function MapProjection.toUV(spec: MapSpec, world: Vector3): Vector2
	return Vector2.new((world.X - spec.originX) / spec.sizeX, (world.Z - spec.originZ) / spec.sizeZ)
end

-- Heading in degrees for a UI arrow, from a look vector (0 = map up = world -Z).
function MapProjection.heading(look: Vector3): number
	return math.deg(math.atan2(look.X, -look.Z))
end

return MapProjection
```

Rule of thumb: make "map up" world **-Z**, because that is the default camera forward and what builders think of as north. Write the spec once in a shared module and let both the map-capture step and the UI read it; most "markers are offset" bugs are two hand-typed origins that disagree.

Square aspect: if `sizeX ~= sizeZ`, the image must have the same aspect or markers stretch. Pad the world rectangle to a square instead.

## 2. Rendering the map surface

| Option | How | Cost | Use when |
|---|---|---|---|
| **Pre-rendered image** | Top-down orthographic screenshot or painted map, uploaded as a decal/image | One texture | Static worlds; almost always the right choice |
| **ViewportFrame** | Clone simplified geometry into a ViewportFrame with a top-down camera | Renders its contents every time they change; cloned parts cost memory | Small arenas whose layout changes per round |
| **EditableImage drawn from data** | Paint roads, plots and zones into pixels at runtime | Client memory budget; requires the experience setting | Procedural maps, player-built worlds |

For a pre-rendered image, capture with Studio's camera set high above the map, `FieldOfView` small (a near-orthographic view) and record the exact world rectangle it covers, or paint the map in an image editor using a top-down capture as a guide. Uploaded images are moderated and downscaled to the platform maximum (Roblox docs: images above 1024 px on a side are downscaled), so very large worlds need tiles or a second, zoomed detail image.

ViewportFrame minimaps (Roblox docs: ViewportFrame renders 3D objects with its own `CurrentCamera`, lighting is limited to `Ambient`, `LightColor` and `LightDirection`, no shadows or post-effects) are tempting but you are maintaining a second copy of the world. Keep it to block-out shapes and only move the camera, not the contents.

EditableImage details (creation returns `nil` when the device budget is exhausted, the "Allow Mesh / Image APIs" toggle) are in [[EditableImage for Pixel Buffers and Procedural 2D]].

## 3. Fixed versus rotating minimap

- **Fixed (north-up)**: the map stays still, the player arrow rotates. Easiest to read for navigation and for callouts ("north gate"). The only work is panning.
- **Rotating (heading-up)**: the map rotates so the camera's forward is always up; the player arrow is fixed. Better for driving and fast movement.

Panning: put the map image inside a container, size it to `zoom` times the container, and set its `Position` so the player's UV sits at the centre:

```lua
--!strict
local function placeMap(mapImage: ImageLabel, uv: Vector2, zoom: number)
	mapImage.Size = UDim2.fromScale(zoom, zoom)
	mapImage.AnchorPoint = uv               -- the player's point on the image...
	mapImage.Position = UDim2.fromScale(0.5, 0.5) -- ...sits at the container centre
end
```

Setting `AnchorPoint` to the player's UV pans the map so the player sits at the centre. It does **not** make rotation happen about the player: Roblox docs state `Rotation` is relative to the element's centre, not its `AnchorPoint`. So for a rotating map, rotate a **parent** frame that is centred in the window (anchor 0.5, 0.5, position 0.5, 0.5, same size as the window) by `-heading`, and pan the image inside it as above. The parent's centre is the player, so the map spins about the player.

**Clipping rotated content.** `ClipsDescendants` historically stops clipping when the element or an ancestor is rotated; the Roblox docs describe a `StarterGui.ClipsDescendantsSupportsRotation` option for rotation-aware clipping (see [[ScreenGui Fundamentals]]). The robust choice is a `CanvasGroup` as the minimap window: it renders its descendants to a texture and clips them to its bounds, and a `UICorner` with radius 0.5 scale makes it round. CanvasGroups cost texture memory and re-render when contents change, so keep exactly one for the minimap and update it at 10 to 20 Hz, not every frame (rule of thumb).

## 4. Markers

- Markers are children of the panned/rotated image, positioned by `UDim2.fromScale(uv.X, uv.Y)` with `AnchorPoint = 0.5, 0.5`. They then pan and rotate with the map for free.
- Counter-rotate icons that must stay upright (text, shop icons): set their `Rotation = heading` so the net rotation is zero.
- Off-map markers: clamp to the minimap's edge (same maths as [[Off-Screen Objective Markers and Waypoint Arrows]], in map space instead of screen space).
- Visibility is a server decision. The client should only receive marker data it is allowed to see (teammates, objectives). Sending every enemy position to every client "for the map" is a wallhack waiting for an exploiter ([[Interest Management and Per-Player Replication]]).
- Pool marker frames; do not create and destroy them every update.

## 5. Fog of war

Store exploration in a coarse grid on the **server** (for example 64 x 64 cells over the world), mark cells as the player moves, and save it as a compact string or buffer in their profile. The client gets the grid on join plus deltas.

Display options:

1. **Grid of frames**: one dark frame per unexplored cell over the map. Fine up to a few hundred cells; past that the instance count hurts.
2. **EditableImage mask**: a 64 x 64 image, one pixel per cell, alpha 255 for unexplored and 0 for explored, laid over the map with `ResampleMode = Enum.ResamplerMode.Default` so it blurs softly. 64 x 64 x 4 bytes is 16 KB, well inside any budget. Write only changed pixels with `WritePixelsBuffer`.
3. **Pre-split regions**: reveal whole named regions (one image each) when the player enters the zone ([[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]). The cheapest and often the best design.

Always build a fallback for EditableImage returning `nil` (option 1 or 3).

## 6. Big world map

The full-screen map is the same projection with a different zoom and drag/pinch input. Clamp pan so the image edge never leaves the screen, zoom about the pinch/cursor point (convert the point to UV before and after the zoom and offset by the difference), and pause minimap updates while it is open.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Origin typed twice | Markers drift further off towards one edge | One shared `MapSpec` |
| Non-square image for a non-square world | Markers stretch along one axis | Pad world rect to square |
| Rotating a frame with `ClipsDescendants` | Map leaks out of the round frame | `CanvasGroup` window, rotate an inner frame |
| ViewportFrame with full world clone | Minimap costs more than the game | Pre-rendered image |
| Enemy positions sent for the map | Exploiters see everyone | Server filters marker data |
| Fog as thousands of frames | UI instance count explodes | EditableImage mask or region reveals |
| Updating every frame | CanvasGroup re-renders constantly | 10 to 20 Hz |

## Checklist

- [ ] One projection spec shared by capture and UI; map up = world -Z.
- [ ] Map image square, aligned, and within the upload size limit (tiles if not).
- [ ] Rotating map uses a CanvasGroup window; upright icons counter-rotated.
- [ ] Marker data filtered on the server; marker frames pooled.
- [ ] Fog of war stored server-side, displayed via mask with a fallback.
- [ ] Tested on a phone at the smallest safe-area layout.

## See also

[[HUD Design]] · [[ScreenGui Fundamentals]] · [[EditableImage for Pixel Buffers and Procedural 2D]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Interest Management and Per-Player Replication]] · [[Math Vectors and CFrames]]

## Connected notes
<!-- auto-links:start -->
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[World-Space UI - BillboardGui and SurfaceGui]] · Genre Playbook - Racing and Driving
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Race HUD - Position, Laps, Splits, Speedometer and Minimap]] · [[Layout - Scale Offset and Constraints]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[Figma Property Mapping for Roblox UI]] · [[Safe Areas and Insets]] · [[Virtualized Lists and Large Inventories]] · [[UI Layout Objects - Lists Grids and Pages]] · [[Settings Menu Design for Roblox - Layout, Controls and Motion]]
<!-- related:end -->
