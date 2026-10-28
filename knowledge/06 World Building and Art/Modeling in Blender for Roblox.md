---
tags: [world-building, art, blender, modeling, meshes, pipeline, uv, trim-sheet]
---
# Modeling in Blender for Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Scene in metres -> 1 unit = 1 stud; Apply Scalings at export
> - Avoid: Unapplied transforms -> Apply rotation and scale before export
> - Avoid: Several material slots on one object -> Plan splits deliberately
> - 1 unit = 1 stud, a 5-stud reference in the file.
> - Transforms applied; origin where the Studio pivot should be.
> - Under 20,000 triangles per object; hidden faces removed.
>
> Read more (18 KB note): ## Topology for real-time Roblox meshes · ## UVs: texel density, trim sheets and atlases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Blender is the default modelling tool for Roblox creators: free, scriptable in Python, and supported by Roblox's own export docs and upload add-on. This note covers **static** environment and prop modelling: units, topology, triangle budgets, UVs, trim sheets and atlases, splitting a model into MeshParts, pivots, export, upload and the swap from blockout to final art. Rigging and animated characters live in the Animation section ([[Rigging in Blender]], [[Creature Rig Conventions]], [[Pipeline - Importing Animated Enemies]]); file-format details are in [[Exporting FBX vs GLB]] and importer options in [[3D Importer Settings Reference]].

The production numbers here come from one production game that built a hub (three times), two realms of zone kits, 11 gate models and a 49-model enemy roster in Blender, mostly from Python scripts.

## The constraints Roblox puts on a mesh

| Constraint | Value | Source |
|---|---|---|
| Triangles per mesh | 20,000 maximum | Roblox modeling specifications |
| Materials per mesh | 1 (a Blender object with 3 slots imports as 3 MeshParts) | Roblox texture specifications |
| UV sets | 1, coordinates inside 0..1 (overlap allowed) | Roblox texture specifications |
| Texture upload | .png, .jpg, .tga, .bmp; the spec page lists 4096 x 4096 maximum but also says UV "pixel spaces" up to 1024 x 1024 | Roblox texture specifications (the two numbers conflict; plan for 1024 as the practical ceiling for in-game maps) |
| Normal maps | OpenGL tangent space only (flat = 127, 127, 255) | Roblox SurfaceAppearance docs |
| Geometry | Watertight, no zero-thickness faces, quads preferred | Roblox modeling specifications |
| Transforms | Applied: scale 1, rotation 0 | Roblox modeling specifications |

"Watertight, no zero thickness" matters most for **CSG and collision**: an open shell produces bad collision hulls and fails mesh CSG. A single-sided leaf card is the exception, and it should be non-colliding and `DoubleSided` (see [[Foliage Props and Scatter]]).

## Units: model in studs

Set up the Blender scene so **1 Blender unit = 1 stud** and keep it that way for every file. A Roblox character is about 5 studs tall (R15 default); one production game's player measured about 9 studs with its scaled characters. Put a 5-stud reference block in every kit file.

Roblox's own conversion is 1 stud = 0.28 m, so a file modelled in metres imports about 3.6 times off unless the importer's unit matches. FBX adds its own centimetre scale (Roblox's export page: Apply Scalings "FBX Unit Scale"). The family of "100x too big" bugs is always the unit chain; fix it at export, never by scaling in Studio. Full detail: [[Exporting FBX vs GLB]].

Rule of thumb for scale: environment props read best a little **larger** than real life relative to the character. Doors 8 to 10 studs tall, steps 1 stud high and at least 2 deep, railings 3 studs. Roblox cameras sit far behind the character, so small detail disappears.

## Topology for real-time Roblox meshes

Roblox does not subdivide or tessellate. What you export is what renders.

- **Quads in the source, triangles in the export.** Keep quads while modelling; let the exporter triangulate, or triangulate yourself with a Triangulate modifier when you need control over diagonals on curved surfaces (one production game's rule: "controlled triangulation").
- **Weighted normals for hard-surface.** A Weighted Normal modifier (with Auto Smooth or the "Smooth by Angle" node in newer Blender) makes bevelled props read crisp with few triangles. Without it, large flat faces shade with gradients.
- **Bevel the silhouette, not the interior.** One small bevel on outer edges catches light and makes props look finished. Interior edges nobody sees do not need it.
- **Delete hidden faces.** The bottom of a rock sitting on the ground, the back of a wall module against a cliff, faces inside other meshes. They cost triangles and fill rate and contribute nothing.
- **Avoid long thin triangles** on large flat surfaces (they shade and depth-sort badly at distance).
- **Keep it watertight** when the mesh will collide or be used in CSG.

### Triangle budgets that worked in one production game

| Asset | Triangles | Notes |
|---|---|---|
| Hero hub centrepiece (tiered dais, dice, halo, swords) | 7,300 over 9 meshes | Seen up close all the time |
| Hub fountain | 9,200 over 7 meshes | |
| Daily reward chest | 8,000 | |
| Lucky spinner | 7,200 over 7 meshes | |
| Zone gate | 6,000 to 12,000 + an `_LOD1` for stone and dressing | 11 gates |
| Hub kit piece (orbital station kit) | max 9,800 per mesh, 70 meshes | |
| Whole zone terrain set (hand-modelled realm) | 90,000 over 31 meshes | Neon glow parts separate |
| Enemy (voxel style, stud detail baked) | 10,000 to 42,000 per model, largest part about 6,500 | 49 models |
| Top-tier sword | 29,500 over 32 parts | Held by the player, close to camera |

These are **per object** numbers. The scene-level budget is about how many are visible at once and how many unique meshes there are; see [[Art Budgets - Triangles Draw Calls Memory]].

## Splitting a model into MeshParts

A Blender model becomes one MeshPart per object (and per material slot). How you split decides cost and flexibility:

| Split by | Pros | Cons | Use for |
|---|---|---|---|
| One mesh, one atlas texture | Fewest draw calls | Cannot recolour or change material per piece in Studio | Final, fixed props |
| One mesh per **colour / material** | Recolour in Studio, real Roblox Materials per piece, instancing across a kit | More MeshParts | Stylised kits, voxel art, anything using built-in Materials |
| One mesh per **moving piece** | Animate by CFrame or joints | More parts | Doors, wheels, spinning rings, station machinery |
| Separate **glow / glass / accent** meshes | Neon and Glass materials, per-instance accent colour | A few more parts | Lamps, screens, crystals, portals |

One production game's environment kits used all four at once: base geometry merged per colour or per trim-sheet material, moving pieces as separate meshes with an attachment for their pivot, and `*_Glow` / `*_Accent` / `*_Glass` meshes that a Studio script switched to Neon, a station colour, or Glass after import.

## UVs: texel density, trim sheets and atlases

### Texel density

Texel density is texture pixels per stud on the surface. Keep it **consistent** across a kit, or one piece looks sharp next to a blurry neighbour. Roblox's own figures as anchors (Roblox texture specifications): default part materials show 1024 x 1024 across an 8 x 8 stud face (128 px/stud), terrain 512 x 512 across 8 x 8 studs (64 px/stud), and the recommendation is 256 px for 5-stud objects, 512 for 10-stud and 1024 for 20-stud objects (about 50 px/stud).

What happened in one production game:
- A tiling stone sheet at **32 px/stud** looked right on gates seen from mid distance.
- A cliff sheet at **1.85 px/stud** looked soft up close; the fix was a second sheet, not a bigger one.
- A procedurally generated hub kit with low-resolution trim was judged "low detail / pixelated" next to the previous hub, which used painted per-family texture sheets over 118 modular pieces. The procedural hub was reverted within a day.

Takeaway: texel density is the single biggest "looks professional" lever in environment art, and it is cheap to check. Use Blender's UV checker or a numbered grid texture, and look at it from the player's camera, not from a beauty camera.

### Trim sheets

A trim sheet is one texture holding horizontal strips of reusable surface (panel, vent, frame, tread, rune band, stone course), each strip tiling horizontally. Modules UV their faces onto the strip they need. Benefits: one texture set (Color, Normal, Roughness, Metalness) for a whole kit, unlimited mesh variety, consistent density, and instancing-friendly SurfaceAppearances.

A trim sheet that worked: one 1024 sheet with rows "ceramic panel, ceramic vent, graphite frame, tread, ribbed, hazard, dark channel, greeble, glass, solid swatches", plus Color / Normal / ORM maps. A fantasy restyle swapped to rows of "blue-slate ashlar blocks, violet rune band, dressed stone trim, polished floor tiles, fluted columns, gold ornament band, cobble". Swapping the sheet restyled 150 meshes without touching geometry, which is the point of trims.

Trim sheet rules:
- Strips run the full width so faces can slide along U.
- Leave a few pixels of padding between strips (mip bleeding).
- Add a row of flat solid swatches for small details, so not every bolt needs its own UV island.
- Keep the normal map in OpenGL convention.

### Atlases and palette textures

An atlas packs each mesh's unique UV islands into one texture. A **palette** is the extreme case: a grid of flat colours with every face's UVs collapsed onto one swatch. Palettes are perfect for flat-coloured stylised kits, cost almost nothing, and let a whole kit share one texture.

The trap (measured in one production game): a MeshPart with a palette `TextureID` **ignores `Material` changes**, so a later "use real Roblox materials" pass had to clear TextureIDs and set colours from sampled swatches. If you think you might want Roblox Materials later, export **one mesh per colour with no texture** instead, and let `Color` + `Material` do the work.

## Normals, outlines and baked detail

- **Bake small detail to normal maps** rather than modelling it: rivets, studs, cracks, stone joints. Studs on a voxel model as real geometry cost about 20 triangles per stud face; as a tiling normal map they cost nothing (see [[Voxel Art - Studs Outlines and Style Kits]]).
- **Inverted-hull outlines** (Solidify modifier with flipped normals, black back-face-culled material) give a cartoon outline in-engine with no shader. They **double the triangles** of the outlined mesh. One production game kept them in preview renders only and relied on part-seam lines and studs in game; bosses were the only candidates for baked hulls.
- **Vertex colours multiply** with `MeshPart.Color`. Export white vertex colours unless you mean to tint.

## Pivots, origins and orientation

Set the object origin where Studio will want the pivot:
- Props and trees: bottom centre.
- Gates: floor centre of the opening; LookVector toward the approach side.
- Wall and cliff modules: outer bottom corner or bottom centre, consistently across the kit.
- Rotating parts: at the rotation axis (or export an empty/attachment marker and read it in Studio).

Orientation: Studio's importer turns glTF files 180 degrees about Y (measured in one production game: a Blender -Y front lands on Roblox -Z). The FBX route through the upload add-on kept the authored orientation in the same project. Pick one route per kit and verify with an asymmetric test piece (a lamp post with an arm pointing one way). See [[Enemy Import Axis Fix]] for the rigged-model version of the same problem.

## Getting meshes into Studio

| Route | How | Good for | Watch out |
|---|---|---|---|
| Studio 3D Importer (File > Import 3D) | FBX / glTF / OBJ | One-off pieces, checking a file | Whole scenes become many unique meshes |
| Roblox Blender add-on (upload) | Uploads a collection as a package of MeshParts | Kits of 50 to 150 meshes | Token can be revoked silently; long uploads time out |
| Bulk import then save as Package | Import once, publish as a Package | Sharing a kit across places | Package versioning discipline ([[Packages and Asset Reuse]]) |

Upload gotchas from one production game:
- The add-on's login token was revoked silently: the add-on still showed "logged in" while uploads failed with "Token has been revoked". Log out and in again.
- Heavy kits timed out after the add-on's default number of status polls ("Operation Timed Out") and may have left orphan copies; raising the poll count fixed it.
- Do not block Blender's main thread (for example with a sleep in a script) while an upload runs; it stalls the add-on's async loop.
- Studio may need tens of seconds before a freshly uploaded image loads with `PreloadAsync` (measured 20 to 60 s).

## The blockout-to-art swap

Mature Roblox pipelines treat the Studio blockout as the **layout source of truth** and the Blender kit as the **look**. A swap script replaces each blockout part with the right mesh, scaled and placed from the blockout's frame.

```lua
--!strict
-- Replace every blockout Model named "Blockout_<Module>" under `root` with a clone of the
-- template Model named <Module> from `library`. Templates have PrimaryPart "Origin" at the
-- bottom centre. FitMode "height" scales uniformly to the blockout height; "bbox" keeps size.
local function swapBlockouts(root: Instance, library: Instance, dryRun: boolean): (number, { string })
	local placed, missing = 0, {}
	for _, block in root:GetDescendants() do
		if block:IsA("Model") and string.sub(block.Name, 1, 9) == "Blockout_" then
			local moduleName = (block:GetAttribute("Module") :: string?) or string.sub(block.Name, 10)
			local template = library:FindFirstChild(moduleName)
			if not template or not template:IsA("Model") then
				table.insert(missing, moduleName)
				continue
			end
			local frame, size = block:GetBoundingBox()
			local bottomCentre = frame * CFrame.new(0, -size.Y / 2, 0)
			if dryRun then
				placed += 1
				continue
			end
			local art = template:Clone()
			if block:GetAttribute("FitMode") == "height" then
				local _, tSize = template:GetBoundingBox()
				art:ScaleTo(size.Y / tSize.Y)
			end
			art:PivotTo(bottomCentre)
			art.Parent = block.Parent
			block:SetAttribute("SwappedTo", art.Name)
			-- Keep the blockout as an invisible collider instead of deleting it
			for _, p in block:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 1
					p.CastShadow = false
				end
			end
			placed += 1
		end
	end
	return placed, missing
end
```

Run it with `dryRun = true` first and read `missing`. One production game used exactly this shape of tool (plus a yaw fix option) to replace 339 cliff and 677 tree blockouts, and a variant that kept blockout parts as invisible colliders so collision tests stayed identical.

## Scripted modelling in Blender

Python in Blender (`bpy`, `bmesh`) is how a small team produces dozens of consistent kit pieces: a shared library of primitives and palette UVs, one script per piece, a batch build that writes `.blend` files, renders previews (front, side, three-quarter) and a contact sheet, then exports. One production game built its gates, hub kits, stations and enemies this way and could restyle a whole kit by changing a palette table.

Practical rules:
- **Render previews from the player's camera height and distance**, not only beauty shots. Many "looks great in Blender" pieces read as noise at 40 studs.
- **Make a contact sheet** of every piece in a kit at the same scale. Inconsistent density, palette drift and scale errors jump out.
- **Save the file before any long operation** and keep source scripts in version control; one shared Blender instance lost collections when someone else reset the file.
- **Long paths break native tools.** Blender and other executables could not open paths over 260 characters on Windows; use short working directories.
- **Generated Lua data:** when Python writes Lua tables, quote keys that are Lua keywords (`local`, `end`). Python's `str.isidentifier()` accepts them.

## Style lessons from the reference project

- "Professional" meant **hand-built or carefully scripted Blender geometry with real masonry logic** (ashlar piers, voussoir rings, keystones, cornices) and consistent texture density, not more polygons.
- The owner rejected auto-generated meshes and Toolbox assets for the map entirely after early experiments: they did not match each other and could not be edited.
- Enemies could stay voxel; the map should not. Different asset classes can follow different styles if each class is consistent (see [[Environment Art Styles]]).
- When a textured approach kept looking wrong, the winning fix was simpler: flat SmoothPlastic colours in two tones. Complexity is not quality.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Scene in metres | 3.6x or 100x scale on import | 1 unit = 1 stud; Apply Scalings at export |
| Unapplied transforms | Rotated or skewed parts, wrong pivots | Apply rotation and scale before export |
| Several material slots on one object | One model becomes many MeshParts | Plan splits deliberately |
| Inconsistent texel density | Some pieces blurry, some sharp | Checker texture, shared density target |
| Noisy vertex colours | Patchy streaks you cannot fix in Studio | Export white vertex colours, use UVs |
| Detail as geometry | Triangle budget gone on studs and rivets | Bake to normal maps |
| Hidden faces kept | Wasted triangles and overdraw | Delete faces nobody sees |
| Importing a whole level file | Unique mesh per copy, no instancing | Import each kit piece once |
| DirectX normal map | Lighting looks inverted (dents pop out) | Flip green channel to OpenGL |

## Checklist

- [ ] 1 unit = 1 stud, a 5-stud reference in the file.
- [ ] Transforms applied; origin where the Studio pivot should be.
- [ ] Under 20,000 triangles per object; hidden faces removed.
- [ ] One material per object, split by colour / moving part / glow as planned.
- [ ] Consistent texel density; normals in OpenGL convention.
- [ ] Preview renders from the gameplay camera; contact sheet for the kit.
- [ ] Imported once, saved as a library or Package, placed by cloning.
- [ ] Blockout swap run in dry-run mode first.

## See also

- [[Parts Unions and MeshParts]], [[Materials MaterialVariants and SurfaceAppearance]], [[Textures Decals and Texture Memory]]
- [[Voxel Art - Studs Outlines and Style Kits]], [[Environment Art Styles]], [[Art Budgets - Triangles Draw Calls Memory]]
- [[Exporting FBX vs GLB]], [[3D Importer Settings Reference]], [[Rigging in Blender]], [[Asset Pipelines]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Fundamentals for Games]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Exporting and Validating Models for Roblox]] · [[Modular Environment Kits]] · [[Art Pipeline - Concept to In-Game Asset]]
<!-- auto-links:end -->
