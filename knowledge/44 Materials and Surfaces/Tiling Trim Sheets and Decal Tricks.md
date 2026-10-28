---
tags: [materials, textures, decals, tiling, trim-sheet, world-building, performance]
---
# Tiling Trim Sheets and Decal Tricks

[[Trim Sheets Atlases and Vertex Colors]] covers trim sheets as a modelling technique: layouts, TintMask, palettes and vertex colours for meshes. [[Textures Decals and Texture Memory]] covers what Decals and Textures are and how image memory works. This note sits between them and is about **surfaces built from parts and flat faces**: making a texture that truly tiles, hiding repetition at three scales, aligning tiling across neighbouring parts, pulling single trim strips onto plain Parts with `Texture`, and the decal tricks that the current `Decal` API makes possible (UV transforms, rotation, ordering and PBR maps). Most Roblox worlds are still mostly Parts. These are the tools that make those Parts look authored.

## 1. What changed in the Decal API

As of October 2026 the `Decal` reference (and `Texture`, which inherits from it) lists properties older tutorials do not mention (Roblox docs):

| Property | Type | What it does |
|---|---|---|
| `UVOffset` | Vector2 | Translates UV coordinates |
| `UVScale` | Vector2 | Scales UV coordinates |
| `Rotation` | number | Rotates the texture in degrees, clockwise, applied to UVs |
| `ZIndex` | int | Render order among decals on the **same face**: lower first, higher on top |
| `ColorMapContent` | Content | The albedo (colour and opacity) |
| `NormalMapContent`, `RoughnessMapContent`, `MetalnessMapContent` | Content | PBR maps; setting any "makes the decal PBR" |
| `EmissiveMaskContent`, `EmissiveStrength` (default 1), `EmissiveTint` (default white) | | Glow, as on SurfaceAppearance |
| `Shiny`, `Specular` | | Deprecated and non-functional |

The ContentId versions of the PBR maps are hidden and Plugin security; the reference recommends the Content versions. Treat PBR map assignment as an edit-time job, like SurfaceAppearance maps, and swap prepared decals at runtime (section 7). Two things the docs do **not** say, and which you should test before relying on them: how `UVScale`/`UVOffset` combine with a `Texture`'s `StudsPerTile`/`OffsetStuds`, and whether PBR decals cost more to render than plain ones (likely, since they read more maps).

## 2. Making a texture that actually tiles

A tiling texture is one whose right edge continues into its left edge and whose top continues into its bottom. The CC0 sets in [[CC0 Texture and HDRI Library]] are already seamless, which is one reason they are so useful. When you make or edit your own:

1. **Offset by half.** In any image editor, offset the image by 50 percent horizontally and vertically (wrap around). The seams are now a cross in the middle where you can see and paint them out.
2. **Paint out the cross**, then offset back.
3. **Do the same on every map.** A seamless colour map with a non-seamless normal map shows lighting seams even when the colour looks perfect. Edit all maps together or derive normal and roughness from the finished colour map.
4. **Flatten large-scale variation.** A photo with a lighter left side tiles with a visible stripe every tile. Use a high-pass or "equalise" step so the average brightness is the same everywhere in the tile. This is the single biggest cause of visible grids on large surfaces.
5. **Test tiled 4 x 4** before upload. Put the image on a large flat part with `StudsPerTile` small enough to show sixteen repeats, and look from a distance and at a low angle.

Nuance: seamless is not the same as non-repeating. A perfectly seamless texture with one memorable feature (a dark knot in wood, a single big crack) still shows a grid because the eye finds that feature every tile. Remove or tone down unique features in textures meant for large areas.

## 3. Hiding repetition at three scales

Large surfaces repeat. The fix is not a bigger texture; it is variation at a scale the tile does not have.

| Scale | Technique | Cost |
|---|---|---|
| Micro (inside a tile) | Choose textures with evenly spread detail; `MaterialPattern.Organic` on MaterialVariants ([[MaterialService and Custom Materials]]) | None |
| Meso (several tiles) | Break the surface into parts with slightly different `Color`; rotate alternate parts' textures 90 degrees with `Rotation`; overlay a second, larger-scale `Texture` | Small: one more texture layer |
| Macro (whole area) | Grime and wear decals at edges and corners; props that interrupt the surface (crates, puddles, plants); lighting variation | Draw calls per decal; keep counts low |

### The two-layer overlay

Put a second `Texture` on the same face with a low-contrast, mostly transparent "dirt" image at a different, non-multiple scale (for example the base at `StudsPerTile` 8 and the overlay at 37). Because 8 and 37 share no common factor, the combined pattern only repeats every 296 studs, far larger than most rooms. The overlay image can be small (256 px) because it carries only soft blotches.

```lua
--!strict
-- Add a large-scale breakup overlay to the up face of every floor part under `root`.
local OVERLAY_IMAGE = "rbxassetid://0000000000" -- soft, mostly transparent blotches
local OVERLAY_TILE = 37 -- studs; deliberately not a multiple of the base tile

local function addBreakup(root: Instance)
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Floor") == true and not p:FindFirstChild("Breakup") then
			local t = Instance.new("Texture")
			t.Name = "Breakup"
			t.Texture = OVERLAY_IMAGE
			t.Face = Enum.NormalId.Top
			t.StudsPerTileU = OVERLAY_TILE
			t.StudsPerTileV = OVERLAY_TILE
			t.Transparency = 0.4
			t.ZIndex = 10 -- above any base layer at ZIndex 0..9
			t.Parent = p
		end
	end
end
```

Cost check: every overlay is another transparent layer on that face, which is overdraw ([[Textures Decals and Texture Memory]]). One breakup layer on floors is affordable; three layers on every wall is not.

## 4. Aligning tiling across neighbouring parts

A `Texture` tiles from each part's own face corner, and "resizing the parent BasePart changes only the number of repeats, not the tile size" (Roblox docs). So two floor parts of sizes 10 and 13 placed side by side show a visible break in the pattern where they meet. Builders usually fix this by snapping part sizes to the tile size. When that is not possible, compute `OffsetStudsU/V` from the part's position so every face samples one world-aligned grid.

The face's local axes are relative to the part (the docs say the texture rotates with the part), and the exact mapping of U and V to world axes per face is not documented. The script below handles the common case: up-facing floor faces of parts with no rotation other than yaw in 90-degree steps. Check the sign on one part before running it across a map.

```lua
--!strict
-- Align Top-face Textures on axis-aligned floor parts to one world grid.
-- Assumes parts are not tilted. Verify the sign convention on a test pair first.
local function alignTopTexture(part: BasePart, tex: Texture)
	if tex.Face ~= Enum.NormalId.Top then
		return
	end
	-- World position of the face's corner the texture starts from (min X, min Z).
	local half = part.Size / 2
	local corner = part.CFrame:PointToWorldSpace(Vector3.new(-half.X, half.Y, -half.Z))
	local u = tex.StudsPerTileU
	local v = tex.StudsPerTileV
	-- Shift the pattern so the world origin is a tile corner for every part.
	tex.OffsetStudsU = -(corner.X % u)
	tex.OffsetStudsV = -(corner.Z % v)
end

for _, d in workspace:GetDescendants() do
	if d:IsA("Texture") and d.Parent and d.Parent:IsA("BasePart") then
		alignTopTexture(d.Parent, d)
	end
end
```

If the seams get worse instead of better, flip the sign of one or both offsets, or swap X and Z: that tells you how U and V map on your parts. Record the answer in your project docs so nobody has to rediscover it. Parts rotated by 90 degrees in yaw swap the axes; the robust fix there is to keep floor parts unrotated and resize them instead.

## 5. Pulling one trim strip onto a plain Part

A trim sheet is normally a mesh technique: UVs land on the strip they need. Plain Parts have no custom UVs, but a `Texture` can still show exactly one horizontal strip of a sheet:

- Let the sheet have **N equal rows** and the target face be **h** studs tall.
- Set `StudsPerTileV = N * h`. Now the whole sheet is N times taller than the face, so the face shows exactly one row's worth.
- Set `OffsetStudsV` to move the wanted row into view: row `r` (0-based from the top) needs an offset of about `-r * h` (sign depends on the face orientation; test).
- Set `StudsPerTileU` freely: the strip tiles horizontally along the face's length.

```lua
--!strict
-- Show row `row` (0-based) of an N-row trim sheet on one face of a Part.
local function applyTrimRow(part: BasePart, face: Enum.NormalId, image: string, rows: number, row: number, uStuds: number)
	-- Face height: the part dimension along the face's V axis. For side faces this is Size.Y.
	local h = part.Size.Y
	local t = Instance.new("Texture")
	t.Name = "TrimRow"
	t.Texture = image
	t.Face = face
	t.StudsPerTileV = rows * h
	t.OffsetStudsV = -row * h -- flip sign if the wrong row appears
	t.StudsPerTileU = uStuds
	t.Parent = part
end
```

What it buys you: a skirting board, a cornice band, a metal edge strip or a row of rivets on hundreds of plain parts, all from **one image in memory**. A kit of walls built from parts can share the same trim sheet as the meshes built for it ([[Modular Environment Kits]]).

The catches:

- **Mip bleeding.** At a distance, mip levels average neighbouring rows, so a thin face picks up colour from the rows above and below. Leave padding between rows (8 px or more at 1024; same advice as any atlas in [[UV Unwrapping]]) and put rows with similar colours next to each other.
- **The face must be exactly one strip tall.** If a wall part is 9.5 studs tall and you size for 10, half a stud of the next row appears. Snap part heights to your strip sizes, which is good modular practice anyway.
- **Equal rows only.** The trick assumes rows of equal height. For a sheet with mixed row heights, compute `StudsPerTileV` and the offset from the row's pixel range: `StudsPerTileV = h * sheetPixels / rowPixels`, offset from the row's top pixel in the same ratio.

## 6. Decal tricks that are cheap

### Sprite-sheet decals with UVScale and UVOffset

`UVScale` and `UVOffset` let one decal image act as an atlas: a sheet of 16 signs in a 4 x 4 grid, with each decal showing one cell (scale 0.25, offset in quarter steps). All signs then share **one texture in memory** instead of sixteen. The order in which scale and offset apply is not stated in the reference; try `UVScale = Vector2.new(0.25, 0.25)` with `UVOffset = Vector2.new(col * 0.25, row * 0.25)` first, and if the wrong cell shows, try offsets in whole-cell units instead.

```lua
--!strict
-- Point a decal at one cell of a grid atlas (cols x rows). Test the offset convention once.
local function setAtlasCell(decal: Decal, cols: number, rows: number, col: number, row: number)
	decal.UVScale = Vector2.new(1 / cols, 1 / rows)
	decal.UVOffset = Vector2.new(col / cols, row / rows)
end
```

Leave a few pixels of padding around each cell for the same mip reason as trim rows.

### Rotation for variety

`Rotation` (degrees, clockwise) means one crack, stain or leaf-litter decal can appear in four or more orientations. Combined with `Color3` tint and `Transparency`, ten placements of the same decal stop looking like ten copies.

### ZIndex with gaps

Ordering only applies among decals on the same face; lower values render first. The docs suggest leaving gaps (10 or 100) so you can insert layers later. A convention that holds up: 0 to 9 base patterns, 10 to 19 breakup overlays, 20 to 29 grime, 30 and up signs and posters.

### Decals on an invisible host

Z-fighting appears when a decal's face is coplanar with another part. A thin, fully transparent, non-colliding host part placed 0.01 to 0.02 studs in front of the wall carries the decal cleanly and can be moved, scaled and deleted without touching the wall (rule of thumb). Set `CanCollide`, `CanTouch` and `CanQuery` to false and `CastShadow` to false on the host so it costs nothing in physics and queries.

### PBR decals for damage and detail

With `NormalMapContent` and `RoughnessMapContent`, a crack or a bullet hole responds to light instead of being a painted dark shape. That matters most for decals on surfaces the light moves across (day-night cycles, flashlights in horror games). Keep them small (256 or 512) and few.

### Mesh decals for curved surfaces

Decals project from a part's bounding box and smear on curved meshes ([[Textures Decals and Texture Memory]]). For a sticker that must follow a curve, model a small patch of the curved surface in Blender (a copy of the faces under the sticker, offset outwards by about 0.01 studs), UV it to the sticker image, and give it a `SurfaceAppearance` with `AlphaMode = Transparency` and part `Transparency` 0 for crisp edges ([[SurfaceAppearance PBR Workflow]]). One mesh decal costs one more draw call, like a decal, but sits correctly on any shape.

## 7. Runtime decals: pooling and caps

Bullet holes, scorch marks and footprints are created during play. Without a cap they accumulate until the frame rate drops. Pool them, cap them, and fade the oldest.

```lua
--!strict
-- Client: pooled impact decals on small invisible host parts.
local ImpactDecals = {}

local MAX_DECALS = 64
local TEMPLATE_DECAL: Decal = script:WaitForChild("ImpactDecal") :: Decal -- prepared in Studio (may be PBR)
local SIZE = 1.2 -- studs

type Slot = { host: Part, decal: Decal }
local pool: { Slot } = {}
local nextIndex = 1

local function makeSlot(): Slot
	local host = Instance.new("Part")
	host.Name = "ImpactHost"
	host.Size = Vector3.new(SIZE, SIZE, 0.05)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.CastShadow = false
	local decal = TEMPLATE_DECAL:Clone()
	decal.Face = Enum.NormalId.Front
	decal.Parent = host
	return { host = host, decal = decal }
end

-- Place a decal at a raycast hit. Reuses the oldest slot when full.
function ImpactDecals.place(position: Vector3, normal: Vector3)
	local slot = pool[nextIndex]
	if not slot then
		slot = makeSlot()
		pool[nextIndex] = slot
	end
	nextIndex = nextIndex % MAX_DECALS + 1
	-- The Front face (-Z, the LookVector side) must face out of the surface, towards the viewer.
	slot.host.CFrame = CFrame.lookAt(position + normal * 0.03, position + normal * 2)
	slot.decal.Rotation = math.random(0, 359)
	slot.decal.Transparency = 0
	slot.host.Parent = workspace
end

return ImpactDecals
```

Notes: `CFrame.lookAt(from, target)` points the part's front (-Z, its LookVector) towards the target. The code aims it away from the surface along the normal, so the Front face, and the decal on it, faces the viewer. Aiming it into the wall instead puts the decal on the side nobody sees, which is the most common "my decals do not show" bug. Verify on one wall and leave a comment.

Rules of thumb: 32 to 64 live impact decals is plenty on phones; never create them on the server (purely visual, and they would replicate); clear them on round reset.

## 8. Budgets

| Element | Memory | Draw cost |
|---|---|---|
| Tiling `Texture` with a shared image | One image, counted once | One extra layer per face |
| Breakup overlay | Small image (256) | Overdraw on that face |
| Atlas decals (UVScale) | One image for many signs | One layer per decal |
| PBR decal | Up to 4 images | More than a plain decal (assumed; not documented) |
| Mesh decal | One SurfaceAppearance set | One draw call per patch |

Count per view, not per place. One corridor with 30 decals is worse than a city with 300 spread thinly ([[Rendering Performance]], [[Art Budgets - Triangles Draw Calls Memory]]).

## When not to use these tricks

- **Meshes with real UVs.** Bake the detail into the mesh's own texture or use a mesh trim sheet; decals on meshes project badly.
- **Wide variety from a few decals on a phone game.** Every decal is a layer. Prefer props and lighting for variety on low-end targets.
- **Stylised flat-colour games.** A grid of tiling textures fights the style; colour variation and shape do the work ([[Stylised vs Realistic Material Pipelines]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Seamless colour, non-seamless normal | Light seams on every tile | Make every map tile |
| Brightness drift across the tile | Grid visible from far away | Equalise large-scale brightness |
| Breakup overlay at a multiple of the base tile | Pattern still repeats with the base | Use a non-multiple (37 versus 8) |
| Floor parts of random sizes | Pattern breaks at every seam | Snap sizes or align offsets |
| Trim row on a face of the wrong height | Neighbour row creeps in | Snap part heights to strip sizes |
| Decals coplanar with the wall | Flicker | Offset host part 0.01 to 0.02 studs |
| Unlimited runtime decals | Frame rate decays over a match | Pool and cap |
| Decals on curved meshes | Smearing | Mesh decal with SurfaceAppearance |

## Checklist

- [ ] Every map of a tiling set is seamless; tested 4 x 4.
- [ ] Repetition handled at micro, meso and macro scale.
- [ ] Floor and wall parts snapped to tile sizes or offsets aligned by script.
- [ ] Trim strips on parts use shared sheets with padded rows.
- [ ] Signs and stickers share atlases via UVScale and UVOffset.
- [ ] ZIndex convention written down with gaps.
- [ ] Runtime decals pooled, capped and client-only.
- [ ] Decal and overlay counts checked per view on a phone.

## See also

[[Materials and Surfaces Start Here]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Textures Decals and Texture Memory]] · [[MaterialService and Custom Materials]] · [[SurfaceAppearance PBR Workflow]] · [[CC0 Texture and HDRI Library]] · [[Modular Environment Kits]] · [[UV Unwrapping]] · [[Rendering Performance]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Parts Unions and MeshParts]]

## Connected notes
<!-- auto-links:start -->
[[Texel Density]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Draw Calls]] · [[AI Material and Texture Generation]] · [[Texturing and PBR Baking]] · [[The Gradient Palette Texture Workflow]]
<!-- auto-links:end -->
