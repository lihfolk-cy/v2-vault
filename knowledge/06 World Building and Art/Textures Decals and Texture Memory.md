---
tags: [world-building, art, textures, decals, memory, performance, images]
---
# Textures Decals and Texture Memory

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Uploading 1024 (or larger) for everything "to be safe".
> - Avoid: A unique texture per prop instead of an atlas or trim sheet.
> - Avoid: Decals for dirt and wear on every wall: more draw calls and overdraw than a baked map.
> - Most props at 512 or below; 1024 only for shared sheets and hero surfaces.
> - PBR sets trimmed to the maps that matter.
> - Kits share trim sheets or atlases; tints instead of duplicate textures.
>
> Read more (16 KB note): ## Decal versus Texture · ## How texture memory works · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Images reach the 3D world in five ways: **Decals**, **Textures**, a **MeshPart's `TextureID`**, **SurfaceAppearance** maps (see [[Materials MaterialVariants and SurfaceAppearance]]) and **MaterialVariant** maps. They also appear in UI, particles and beams, which share the same memory pool. This note covers the two face-projected image objects (Decal and Texture), how image memory really works, and how to keep a world sharp on desktop without blowing the memory budget on phones.

## Decal versus Texture

Both attach to a `BasePart` and draw an image on one face (`Face: Enum.NormalId`).

| | Decal | Texture |
|---|---|---|
| Mapping | Stretches the image once over the whole face | Tiles the image at `StudsPerTileU` / `StudsPerTileV` |
| Offset | none | `OffsetStudsU` / `OffsetStudsV` (animatable for scrolling) |
| Tint and fade | `Color3`, `Transparency` | `Color3`, `Transparency` |
| Typical use | Signs, logos, posters, one-off grime | Tiled patterns: bricks, studs, tiles, scrolling water or conveyor streaks |
| On a MeshPart | Projected onto the mesh's bounding-box face; stretches on anything but flat faces | Same projection problem |

Key nuances:
- **On MeshParts, Decals and Textures project from the bounding box**, not along the surface. A decal on a curved or angled mesh smears. For meshes, bake the detail into the UV texture or SurfaceAppearance instead.
- **Decals and Textures add draw calls and batch poorly** (Roblox docs). A wall with 30 grime decals costs more than one wall with a baked texture.
- **Transparent images layered over each other cause overdraw**: every overlapping pixel is drawn several times (Roblox docs). Ten stacked transparent decals on one face is a classic mobile frame-time killer.
- **Z-fighting between a decal and another coplanar part** happens when two parts share the face. Give the decal's host part a tiny offset.

### A tiling overlay that adapts to every colour

A tiling `Texture` whose image is mostly transparent lets the part's own colour show through, so one image dresses any colour. One production game used a stud overlay this way: one image holding 4 x 4 studs, `StudsPerTileU = StudsPerTileV = 8`, applied to the **top face only** of hub ground, paving and bases.

```lua
--!strict
local STUD_IMAGE = "rbxassetid://0000000000" -- mostly transparent stud overlay
local TILE = 8 -- studs per image tile

-- Add a stud overlay to the up-facing face of every part under `root` whose top faces up.
local function addStudOverlay(root: Instance)
	for _, p in root:GetDescendants() do
		if not p:IsA("BasePart") or p.Transparency >= 1 then
			continue
		end
		-- Which local face points most upward?
		local best: Enum.NormalId? = nil
		local bestDot = 0.9 -- only nearly flat faces
		for _, face in Enum.NormalId:GetEnumItems() do
			local worldNormal = p.CFrame:VectorToWorldSpace(Vector3.fromNormalId(face))
			local d = worldNormal:Dot(Vector3.yAxis)
			if d > bestDot then
				best, bestDot = face, d
			end
		end
		if best and not p:FindFirstChild("StudOverlay") then
			local t = Instance.new("Texture")
			t.Name = "StudOverlay"
			t.Texture = STUD_IMAGE
			t.Face = best
			t.StudsPerTileU = TILE
			t.StudsPerTileV = TILE
			t.Parent = p
		end
	end
end
```

Naming every overlay the same makes removal a one-line loop. That project's rule: overlays on walkable ground only; walls, foliage, props, water and effects stay smooth so the eye reads "ground".

### Scrolling textures

`OffsetStudsU/V` scroll a `Texture`. Waterfalls, rivers, conveyor belts and lava use this. Animate it on the **client** (it is purely visual) and stop when far away:

```lua
--!strict
-- LocalScript: scroll every Texture tagged "ScrollTexture" at its "Speed" attribute (studs/s).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MAX_DIST = 300 -- stop updating beyond this many studs from the camera
local camera = workspace.CurrentCamera

RunService.PreRender:Connect(function(dt: number)
	local camPos = camera.CFrame.Position
	for _, t in CollectionService:GetTagged("ScrollTexture") do
		if t:IsA("Texture") then
			local host = t.Parent
			if host and host:IsA("BasePart") and (host.Position - camPos).Magnitude < MAX_DIST then
				local speed = (t:GetAttribute("Speed") :: number?) or 4
				-- Wrap to the tile size so the number never grows unbounded
				t.OffsetStudsV = (t.OffsetStudsV + speed * dt) % t.StudsPerTileV
			end
		end
	end
end)
```

For streams and falls, one production game used two scrolling streak **Beams** per drop plus foam and mist emitters, sleeping beyond 650 studs (see [[Water Sky and Atmosphere Art]] and [[Beams and Trails]]).

## How texture memory works

### Pixels, not file size

"Texture memory depends on pixel count, not disk file size. A 1024x1024 texture uses four times the graphics memory of a 512x512 texture" (Roblox docs). Images are **transcoded to a fixed GPU format** after upload, so saving a smaller PNG, using fewer colours or pre-compressing does **not** reduce memory.

Rules of thumb that follow:
- Memory scales with width x height. Halving both sides quarters the cost.
- Mipmaps add roughly a third on top (standard GPU behaviour; Roblox does not publish the exact factor).
- Every **unique** image costs once, however many surfaces use it. Ten thousand parts sharing one texture cost one texture.

### Roblox's own size guidance

| Guidance | Value | Source |
|---|---|---|
| Limit images to | at most 512 x 512 | Roblox performance docs |
| Most minor images | under 256 x 256 | Roblox performance docs |
| 5 x 5-stud object | 256 x 256 | Roblox texture specifications |
| 10 x 10-stud object | 512 x 512 | Roblox texture specifications |
| 20 x 20-stud object | 1024 x 1024 | Roblox texture specifications |
| Built-in part materials | 1024 x 1024 over 8 x 8 studs | Roblox texture specifications |
| Terrain materials | 512 x 512 over 8 x 8 studs | Roblox texture specifications |
| Upload formats | .png .jpg .tga .bmp | Roblox texture specifications |

These conflict slightly (512 cap versus 1024 for 20-stud objects). Read them as: **1024 only for large hero surfaces and shared trim sheets; 512 for most props; 256 or less for small details and UI icons.**

### A PBR set costs four textures

A SurfaceAppearance with Color, Normal, Roughness and Metalness at 1024 is four 1024 textures. Ways to cut it:
- **Drop maps you do not need.** A non-metal prop needs no metalness map; a matte prop may need no roughness map (set a flat value in the source and leave the slot blank).
- **Share sets.** Trim sheets and tiling materials serve many meshes with one set.
- **Use tint.** `SurfaceAppearance.Color` gives colour variants at zero cost (Roblox docs).
- **Use built-in Materials** where they are close enough: they are already loaded for everyone.

### Budget example (rule of thumb)

| Item | Count | Size | Equivalent 1024 textures |
|---|---|---|---|
| Hub trim sheet (C, N, R, M) | 4 | 1024 | 4 |
| Terrain material overrides (3 materials x 3 maps) | 9 | 1024 | 9 |
| Prop atlas (C, N) | 2 | 1024 | 2 |
| Foliage card atlas (C with alpha) | 1 | 1024 | 1 |
| Skybox | 6 | 1024 | 6 |
| Signs and decals | 20 | 256 | 1.25 |
| UI icons (sprite sheets) | 4 | 1024 | 4 |
| **Total** | | | **about 27** |

Each 1024 equivalent swapped for a 512 saves three quarters of its cost. The skybox alone is often the largest single image cost in a stylised game; consider 512 faces for a painted sky with no fine detail.

## Trim sheets, atlases and sprite sheets

The docs recommend **trim sheets and sprite sheets** for reuse, with `ImageRectOffset` / `ImageRectSize` for UI sprites (Roblox docs). For 3D:
- **Trim sheet:** horizontal tiling strips; meshes UV onto the strip they need. One set for a whole kit. See [[Modeling in Blender for Roblox]].
- **Atlas:** each mesh's unique islands packed into one texture. Good for a set of props always seen together.
- **Palette:** solid swatches. Almost free, but a palette TextureID locks the mesh out of Material changes (measured in one production game).

## Image upload and loading behaviour

- **Fresh uploads take time to become loadable.** One production game measured 20 to 60 seconds before `ContentProvider:PreloadAsync` succeeded on newly uploaded images. Do not panic and re-upload; wait, then test.
- **Moderation.** Every image is moderated. A rejected image shows nothing, which can look like a bug in your code.
- **Ownership.** Images used in a group game should be uploaded to the group, or at least be usable by it.
- **Preloading.** Preload only what the next few seconds need (UI shown at join, the first zone's signage). Preloading everything delays the first playable frame ([[Case Study - Fast Join and Deferred Loading]]).

```lua
--!strict
local ContentProvider = game:GetService("ContentProvider")

-- Preload a handful of critical images and report the slow ones.
local function preload(ids: { string })
	local started = os.clock()
	ContentProvider:PreloadAsync(ids, function(contentId: string, status: Enum.AssetFetchStatus)
		if status ~= Enum.AssetFetchStatus.Success then
			warn("image failed", contentId, status.Name)
		end
	end)
	print(("preloaded %d images in %.2fs"):format(#ids, os.clock() - started))
end
```

## Diagnosing texture problems

| Symptom | Likely cause | Check |
|---|---|---|
| Image missing, part shows plain colour | Moderation pending/rejected, wrong id, not yet loadable | Open the id in the Creator Dashboard; wait 60 s |
| Image blurry up close | Texel density too low, or the device dropped quality | Compare px/stud with neighbours; test at max graphics |
| Image sharp in Studio, blurry on phone | Lower texture quality on low-memory devices | Expected; design for it |
| Decal smeared on a mesh | Bounding-box projection | Bake into the UV texture |
| Frame drops where many transparent decals overlap | Overdraw | Merge into one texture; fewer layers |
| Memory climbs as players explore | Many unique large textures streaming in | Developer Console Memory, `GraphicsTexture` categories ([[Developer Console and Stats]]) |
| Stud/tile pattern misaligned between parts | Different part sizes with the same StudsPerTile start at each part's own corner | Align part edges to the tile size, or use `OffsetStuds` |

The Developer Console's memory view and the MicroProfiler show texture memory and render cost; see [[Memory Budgets and Leaks]] and [[MicroProfiler Guide]].

## Common mistakes

- **Uploading 1024 (or larger) for everything** "to be safe". It is the most expensive safety in the game.
- **A unique texture per prop** instead of an atlas or trim sheet.
- **Decals for dirt and wear on every wall**: more draw calls and overdraw than a baked map.
- **Decals on curved meshes.**
- **Expecting PNG optimisation to save memory.** It does not after transcoding.
- **Animating textures on the server.** Purely visual; do it on the client and cull by distance.

## Checklist

- [ ] Most props at 512 or below; 1024 only for shared sheets and hero surfaces.
- [ ] PBR sets trimmed to the maps that matter.
- [ ] Kits share trim sheets or atlases; tints instead of duplicate textures.
- [ ] No stacks of transparent decals; no decals on curved meshes.
- [ ] Scrolling textures and beams animated on the client with distance culling.
- [ ] Texture memory checked in the Developer Console on a phone.

## See also

- [[Materials MaterialVariants and SurfaceAppearance]], [[Modeling in Blender for Roblox]], [[Art Budgets - Triangles Draw Calls Memory]]
- [[Water Sky and Atmosphere Art]], [[Voxel Art - Studs Outlines and Style Kits]]
- [[Rendering Performance]], [[Memory Budgets and Leaks]], [[Mobile and Low-End Optimization]]
- [[World-Space UI - BillboardGui and SurfaceGui]], [[Beams and Trails]]

## Nuances and edge cases

1. **Memory is decided by pixels on the device, not by upload size.** A 1024 by 1024 texture costs the same GPU memory whether the PNG was 200 KB or 2 MB. Halving resolution cuts memory to a quarter. That makes resolution the main lever, and it makes "a few large textures" more expensive than they look in the file browser.
2. **Low-end devices may load lower resolutions.** The engine can reduce texture detail on devices with limited memory (rule of thumb from observed behaviour; the exact policy is not published). That protects phones from crashing but means fine text or small details painted into textures may blur on exactly the devices with the smallest screens. Never put essential information in small texture detail.
3. **PBR multiplies cost.** A SurfaceAppearance set of colour, normal, roughness and metalness is up to four textures per material. Ten unique PBR materials at 1024 is forty large textures. Share materials across many assets, and drop maps that add little (metalness is often a constant).
4. **Decals add draw calls and overdraw.** Each decal is extra rendering work on top of the surface below. A few dozen are fine; hundreds of wear decals across a town add up on phones. Bake wear into textures or trim sheets for repeated surfaces.
5. **Streaming and textures.** Textures load as content streams in; walking into a new area can show low-detail or missing textures briefly. Keep the first view after spawn or teleport light on unique textures, and reuse textures across areas so they are already loaded.
6. **UI images are textures too.** Inventory icons, backgrounds and badges are all in memory while visible, and sometimes after. A shop that loads 300 unique 512 by 512 icons at once is a memory spike. Use atlases or smaller icons, and load pages of a large list lazily (see [[Virtualized Lists and Large Inventories]]).
7. **Moderation affects timing.** Uploaded images go through moderation before they display for everyone; plan uploads ahead of releases rather than at the last minute.
8. **Scale effects are per client.** Texture memory is a client cost, so player count does not change it directly. But more players means more avatars, each with its own clothing and accessory textures; a 50-player server can carry far more avatar texture memory than your world itself. Leave room in the budget for avatars.

The senior trade-off: texture resolution is where artists and performance most often disagree. Settle it with a written budget per asset class (hero, prop, background, UI icon) and a screenshot test on the lowest target device, not with taste.

## Common mistakes (advanced)

1. **Text painted into world textures.** Symptom: unreadable signs on phones. Fix: SurfaceGui text or larger lettering.
2. **Full PBR sets on background props.** Symptom: memory over budget with no visible gain. Fix: colour-only or shared materials for distant props.
3. **Hundreds of unique UI icons loaded together.** Symptom: memory spike and stutter when opening the shop. Fix: lazy loading and atlases.
4. **No avatar allowance in the budget.** Symptom: crashes on phones only in full servers. Fix: reserve memory for avatars and test with a full server.
5. **Wear decals everywhere.** Symptom: frame drops in towns on phones. Fix: trim sheets with baked wear.
6. **Last-minute image uploads.** Symptom: blank images at launch while moderation completes. Fix: upload early.

## Related decisions

- [[Trim Sheets Atlases and Vertex Colors]]: sharing texture space across assets.
- [[SurfaceAppearance PBR Workflow]]: building PBR sets efficiently.
- [[Tiling Trim Sheets and Decal Tricks]]: replacing decals with trims.
- [[Memory Budgets and Leaks]]: where texture memory fits the whole budget.
- [[Virtualized Lists and Large Inventories]]: lazy icon loading.
- [[Icon and Thumbnail Rendering Pipeline]]: producing icons at the right size.
- [[Links - Image uploading and moderation]]: upload and moderation references.
- [[Readable Text and UI Scale]]: why essential text should not be in textures.

## Connected notes
<!-- auto-links:start -->
[[Texel Density]] · [[Materials and Surfaces Start Here]] · [[UV Unwrapping]] · [[Draw Calls]] · [[AI Material and Texture Generation]] · [[Texturing and PBR Baking]]
<!-- auto-links:end -->
