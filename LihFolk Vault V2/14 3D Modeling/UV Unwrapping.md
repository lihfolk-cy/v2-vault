---
tags: [modeling, uv, unwrapping, texturing, blender, texel-density, type/guide, area/modeling, level/intermediate, api/SurfaceAppearance]
---
# UV Unwrapping

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tiling by scaling UVs past 1 -> Tile with materials, MaterialVariants or Textures
> - Avoid: Relying on a second UV channel -> One UV map
> - Avoid: Smart UV Project on a character -> Hand-marked seams
> - One UV map per mesh, all UVs inside 0 to 1.
> - Seams on hard edges, hidden sides, material boundaries.
> - No visible stretch (Display Stretch overlay).
>
> Cost: TL;DR ~130 tok · whole note ~5.4k tok. Read more: ## 2. Roblox rules that constrain your UVs · ## 5. Texel density · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A UV map tells the engine which pixel of a texture lands on which point of a mesh. Every textured MeshPart in Roblox depends on one: a `TextureID`, a `SurfaceAppearance`, a trim sheet, a palette atlas, a baked VFX gradient. Bad UVs are the most common reason a good model looks cheap in game: blurry patches next to sharp ones, visible seams, stretched stripes, colour bleeding from the neighbouring island. This note covers how unwrapping works, the Roblox-specific rules (Creator Hub, checked October 2026), how to plan seams, pick a texel density, pack islands with the right margins, and how to diagnose UV problems you only see in Studio.

For what goes into the texture once the UVs exist, see [[Texturing and PBR Baking]], [[Trim Sheets Atlases and Vertex Colors]] and [[Hand-Painted and Stylized Texturing]].

## 1. What a UV map is, mechanically

Each vertex of a triangle carries a 2D coordinate (U, V) in texture space, where (0, 0) is one corner of the image and (1, 1) the opposite corner. The GPU interpolates those coordinates across the triangle and samples the texture at each pixel. Two consequences follow:

- **A vertex can only have one UV per face corner.** Where two faces that share an edge need different UV positions (because you cut the surface there), the engine must split the vertex in two. A UV seam therefore costs vertices: a cube with 8 positions becomes 24 vertices once each face is its own island. This is normal and cheap, but it means "triangle count" is not the whole cost story (see [[Art Budgets - Triangles Draw Calls Memory]]).
- **Distortion is a ratio.** If a triangle covers 1 square stud in the world and 0.01 of the UV square, and its neighbour covers 1 square stud and 0.04 of the UV square, the neighbour gets four times as many pixels. That is texel density mismatch, and players see it as one part sharp and the next blurry.

Unwrapping is the act of flattening a 3D surface into 2D with as little stretch as possible, cutting it where it will not flatten.

## 2. Roblox rules that constrain your UVs

| Rule | Value | Source |
|---|---|---|
| UV sets | **One** UV set per component; Studio does not support multiple UV sets | Roblox docs (texture specifications) |
| UV range | All UVs must be inside the 0 to 1 range | Roblox docs |
| Overlap | Overlapping UVs are allowed | Roblox docs |
| Materials per mesh | One material assigned per mesh | Roblox docs |
| Cage UVs (layered clothing) | Never edit or delete cage UVs; cages are matched by vertex and UV | Roblox docs (layered accessory specs) |

What these mean in practice:

- **No second UV channel.** Engines like Unity and Unreal use UV1 for tiling detail and UV2 for lightmaps. Roblox has no lightmap UV and no second channel, so a tiling detail layer and a unique bake cannot coexist on one mesh. If you need both (a tiling stone wall with a unique baked damage mask), split the mesh or bake the tiling into the unique texture. Blender will happily export a second UV map; delete extras before export so you know which one Roblox reads (rule of thumb: keep exactly one UV map named `UVMap`).
- **0 to 1 only.** Tiling by scaling UVs past 1 (a 10 x 10 UV layout so a brick texture repeats ten times) is a standard trick elsewhere and is ruled out by the spec. For repeating surfaces in Roblox, use built-in materials or `MaterialVariant` (which tile in world space by `StudsPerTile`), or a `Texture` object on a part face, or bake the repetition into the image. See [[Materials MaterialVariants and SurfaceAppearance]] and [[Textures Decals and Texture Memory]].

  Nuance: the reference project did lay some meshes out with "8 studs per tile" or "10 studs per tile" box-projected UVs (voxel lobby stations and rebuilt cliff walls). Those were planar projections scaled so the whole mesh still fit a UV square that held a tileable texture, or meshes cut into pieces small enough to stay in range. If a box projection pushes coordinates past 1, the docs say they are out of spec; whether they render wrapped is not documented. Treat out-of-range UVs as unverified behaviour and avoid them on anything you upload for others.
- **Overlap is allowed, and useful.** Mirrored halves (left and right pauldron sharing one island), repeated bolts, trim strips stacked on one row of a trim sheet: overlapping islands save texture space. The price is that anything unique (a baked normal map, ambient occlusion, a decal) is shared too. Bake with overlaps moved out of the 0 to 1 square or hidden, then move them back (see [[Normal Maps and Detail Baking]]).
- **One material per mesh.** A Blender object with three material slots imports as separate MeshParts, or merges into one with only one material honoured depending on importer options. Plan one texture set per mesh, which is exactly what atlases and trim sheets are for.

## 3. Seams: where to cut

Every closed surface needs cuts to flatten. A seam is a place where the texture is discontinuous, so seams should go where players will not see the discontinuity or where the surface already has one.

### Where seams belong

| Place | Why |
|---|---|
| Hard edges (angles above roughly 60 degrees) | The shading already breaks there; a texture seam hides in the crease. Also required for clean normal map bakes (see below) |
| Underneath and behind | Bottom of a crate, inside of a sleeve, back of a weapon guard, the side against a wall |
| Natural material boundaries | Where metal meets leather, where a trim band meets a panel |
| Along existing geometry lines | Panel gaps, belt edges, armour plate edges |
| Inner side of limbs | The classic character seam: inside of arms and legs, where the opposite limb hides it |

### Where seams do harm

- Across a smooth, visible, curved surface (a helmet dome, a face, the top of a sword blade). Any colour or normal discontinuity shows as a line.
- Through the middle of a painted detail or gradient. Hand-painted textures are especially sensitive because painters paint across seams in 3D (see [[Hand-Painted and Stylized Texturing]]).
- Across a mirror plane on a symmetric model, when the halves are not mirrored copies. A seam down the centre of a face mask is visible from the front on every character.

### The seam and smoothing rule

For anything that will get a baked normal map: **every hard edge must be a UV seam**. The reverse is not required (a UV seam can sit on a soft edge). The reason: a hard edge splits vertex normals, the baker writes a sharp correction on each side, and bilinear filtering across an island that continues through the hard edge blends two incompatible corrections, giving a visible line. Splitting the island at the hard edge gives each side its own pixels and padding. Blender has this as one click: in Edit Mode, select all, `UV > Seams from Islands` goes the other way; to mark seams from sharp edges use `Select > Select Sharp Edges` then `UV > Mark Seam`.

## 4. Unwrap methods in Blender

| Method | Where | Use it for | Avoid for |
|---|---|---|---|
| `Unwrap` (Angle Based, Conformal, and in recent versions Minimum Stretch) | `UV > Unwrap` after marking seams | Hero meshes, characters, anything with a hand-planned layout | Nothing, if you are willing to mark seams |
| `Smart UV Project` | `UV > Smart UV Project` | Hard-surface props with many flat faces, quick bakes, VFX meshes, kit pieces you will bake | Organic shapes (many small islands, seams everywhere), hand-painted assets |
| `Cube Projection` / box mapping | `UV > Cube Projection` | Blocky and voxel geometry, world-aligned tiling textures | Curved surfaces |
| `Cylinder` / `Sphere Projection` | `UV` menu | Barrels, poles, domes, blade cores | Anything not shaped like the primitive |
| `Project From View` | `UV` menu | Decals and flat stamps, logos, front-facing details | Surfaces seen from other angles |
| `Follow Active Quads` | `UV` menu | Straightening strips: belts, trims, ropes, tank treads, VFX ribbons | Non-quad topology |
| `Lightmap Pack` | `UV` menu | Unique-per-face bakes (AO-only, gradient bakes) where layout quality does not matter | Anything a human will paint |

Methods worth knowing beyond the menu:

- **Straighten strips with Follow Active Quads.** Select a strip of quads, make one face's UVs a perfect rectangle (`UV > Align` or snap), make it active, then `Follow Active Quads` with "Length Average". The strip becomes a straight bar of UV space, ideal for a trim sheet row or a scrolling VFX texture.
- **Pin and re-unwrap.** Pin (`P`) the vertices you have placed by hand and unwrap again; Blender relaxes the rest around the pins.
- **Average Islands Scale** (`UV > Average Islands Scale`) equalises texel density between islands based on their 3D area. Run it before packing on any multi-island mesh.
- **Check stretch.** In the UV editor overlay, enable "Display Stretch" (area or angle). Blue is fine, yellow to red is distortion you will see.

## 5. Texel density

Texel density is pixels per unit of surface: here, pixels per stud. It is the number that keeps your game looking consistent.

### Reference numbers

| Context | Density | Derivation |
|---|---|---|
| Roblox default part materials | 1024 px across an 8 x 8 stud face, so **128 px per stud** | Roblox docs (texture specifications) |
| Terrain materials | 512 px across 8 x 8 studs, so **64 px per stud** | Roblox docs |
| Docs' suggested texture sizes | 256 px for a 5 x 5 stud object, 512 for 10 x 10, 1024 for 20 x 20, which all work out to about **51 px per stud** | Roblox docs |
| Marketplace avatar items | Textures up to 2048 x 2048 | Roblox docs (accessory specs) |
| Maximum texture | 4096 x 4096 per the texture specifications page, which also lists 1024 x 1024 for UV texture maps without explaining the difference | Roblox docs (inconsistent; see below) |

A practical scale for a Roblox game (rule of thumb):

| Asset class | Target density | Why |
|---|---|---|
| Large environment pieces (cliffs, buildings) | 16 to 32 px/stud on a unique texture, or tile with materials | Seen at distance; unique textures at higher density blow memory |
| Mid props (crates, lamps, stalls) | 32 to 64 px/stud | Matches terrain sharpness so props do not look blurrier than the ground |
| Hero props and weapons held near the camera | 64 to 128 px/stud | Viewed close in first or third person |
| Characters and avatar items | 64 to 128 px/stud on the face and chest, lower on legs and back | Face reads at close range; legs rarely do |

The important rule is not the number, it is **consistency within a view**. A crate at 128 px/stud next to a wall at 16 px/stud looks wrong even if each alone is fine.

### The texture size conflict

The texture specifications page lists both a 4096 x 4096 maximum and a 1024 x 1024 entry for UV texture maps. The accessory and layered clothing pages say "higher resolutions are automatically downscaled" and cap Marketplace textures at 2048. As of October 2026 the safe reading is: Marketplace items at most 2048; experience assets may be uploaded larger but may be downscaled at render time depending on device and quality level. Do not author a 4K map expecting every client to see 4K. Test on a low-end phone (see [[Mobile and Low-End Optimization]]).

### Calculating density in Blender

Blender has no built-in texel density readout. Either use a community add-on (several "texel density" add-ons exist; check the licence and source before installing, see [[Plugins - Using and Writing]] for the same caution on the Studio side), or compute it:

```python
# Blender Python: texel density of the active mesh in px per Blender unit.
# With the vault's convention (1 Blender unit = 1 stud) this is px per stud.
import bpy, bmesh, math

TEX = 1024  # texture width in pixels (square texture assumed)

obj = bpy.context.active_object
bm = bmesh.new()
bm.from_object(obj, bpy.context.evaluated_depsgraph_get())
bm.transform(obj.matrix_world)  # measure world-space area, scale included
uv = bm.loops.layers.uv.active

area3d, area2d = 0.0, 0.0
for f in bm.faces:
    area3d += f.calc_area()
    # shoelace formula for the UV polygon
    pts = [l[uv].uv for l in f.loops]
    a = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % len(pts)]
        a += x1 * y2 - x2 * y1
    area2d += abs(a) * 0.5
bm.free()

density = math.sqrt(area2d / area3d) * TEX if area3d > 0 else 0
print(f"{obj.name}: {density:.1f} px/unit, UV coverage {area2d*100:.1f}%")
```

`UV coverage` is how much of the square you used. Below about 60 percent on a unique-texture asset is wasted memory (rule of thumb); overlapping layouts can legitimately read above 100 percent.

## 6. Packing

Packing arranges islands in the 0 to 1 square. Good packing is about using space and about leaving the right gaps.

### Blender's packer

`UV > Pack Islands` (rebuilt in Blender 3.6) has options that matter:

| Option | Setting for Roblox assets |
|---|---|
| Shape Method | "Exact Shape (Concave)" for the tightest pack; "Bounding Box" when you want rectangles a painter can read |
| Scale | On, unless you have already set density by hand |
| Rotate | On with 90 degree steps for painted assets (keeps strokes and wood grain aligned); free rotation for bakes only |
| Margin Method | "Scaled" by default; "Fraction" when you want the margin as an exact fraction of the texture, which is what you want for pixel-exact padding |
| Margin | See the table below |
| Lock Pinned Islands | On when you placed hero islands manually |

### Margins and padding

Two different things get confused:

- **Margin** is empty space between islands in the UV layout.
- **Padding** (Blender calls it bake "margin") is colour bled outward from each island into that empty space when you bake or export, so filtering and mip-mapping do not sample the background.

Why both: the GPU samples textures at lower mip levels as an object gets smaller on screen. At mip level 4 of a 1024 texture (a 64 x 64 image), one texel covers 16 original pixels. A 2-pixel gap between two islands disappears entirely and the colours of neighbouring islands mix. That is the "my sword has a red line on its edge from the gem next to it on the texture" bug.

| Texture size | Minimum margin between islands | Bake padding | Source |
|---|---|---|---|
| 512 | 4 px | 8 px | rule of thumb |
| 1024 | 8 px | 16 px | rule of thumb (Blender's default bake margin is 16 px) |
| 2048 | 16 px | 32 px | rule of thumb |

In Blender's pack dialog with "Fraction", 8 px on 1024 is a margin of `8 / 1024 = 0.0078`.

Nuance: **solid-colour palette atlases do not need padding**, because each island samples one flat swatch and the swatch can be made larger than the mip footprint. Gradient and painted islands do.

### Packing for the content

- **Group by material.** Metals near metals, cloth near cloth: if bleeding happens, it bleeds a similar colour.
- **Give density to what is seen.** Scale up the face, the blade edge, the front plate; scale down the underside and the inside. This deliberately breaks texel density consistency, which is fine when the low-density parts are rarely seen.
- **Straight islands on a grid** for anything a human will paint by hand in 2D.
- **Keep mirrored overlaps exactly on top of each other**, not almost on top; almost-overlaps waste space and bake garbage.

## 7. Roblox-specific cases

### Layered clothing and cages

The garment mesh needs a normal unwrap. The cages (`_InnerCage`, `_OuterCage`) have UVs that Roblox uses to match the cage to the body: never unwrap, pack, or delete cage UVs. Start from Roblox's cage templates and only move cage vertices. Many failed garment uploads come from an artist applying "Pack Islands" to everything selected, cages included (see [[UGC Avatar Items and Accessories]] and [[Layered Clothing Cages and Animation]]).

### Palette atlases with collapsed UVs

Low-poly and voxel kits often skip unwrapping altogether: every face's UVs are collapsed onto one pixel of a small palette image (a 64 x 64 grid of colour swatches). This is the cheapest way to colour hundreds of meshes from one texture. The reference project's imported kit meshes used exactly this, and its later re-texturing pass could read each part's colour by sampling the palette at its UVs. See [[Trim Sheets Atlases and Vertex Colors]] for the trade-offs.

### VFX meshes

VFX meshes (slashes, rings, shockwaves, swirls) use UVs as a coordinate system, not as a skin. A slash crescent's U should run along the arc and V across its width, so a baked gradient (bright at the leading edge, fading behind) and a noise erosion line up with the motion. Use `Follow Active Quads` or a cylinder projection and straighten. See [[Texturing and PBR Baking]] for how the reference project baked gradient-times-noise textures onto such meshes.

### Mirrored and instanced pieces

For symmetric kits (pauldrons, gauntlets, boots), you have two options:

| Option | Texture cost | Downside |
|---|---|---|
| Mirror UVs (overlap) | Half | Text and asymmetric details appear mirrored; baked AO identical both sides |
| Unique UVs | Full | Twice the space, but allows asymmetric wear, logos, lighting bakes |

Roblox-specific nuance: if you instead export one mesh and mirror it in Studio, remember that `Model:PivotTo` with a mirrored CFrame does not mirror a composite (measured in the reference project); mirroring is a modelling-side job. See [[Exporting and Validating Models for Roblox]].

## 8. Diagnosing UV problems in Studio

| What you see | Likely cause | Fix |
|---|---|---|
| A thin line of another colour along an edge, worse at distance | Islands too close; no padding; mip bleed | Increase margin, bake with padding, regenerate |
| Texture is a single flat colour across the mesh | UVs collapsed (zero area) or all UVs outside 0 to 1 | Unwrap; check the mesh actually has a UV map at export |
| Texture looks right in Blender, garbled in Studio | Exported the wrong UV map (two maps present), or the importer read a different one | Delete extra UV maps; keep one |
| One half of the model mirrored text | Mirrored overlapping UVs | Unique UVs for that island |
| Visible line on a smooth surface with a normal map | Seam across a curved surface, or hard edge without a seam | Move seam, or split island at the hard edge and rebake |
| Blurry on one piece, sharp on its neighbour | Texel density mismatch | Average Islands Scale, repack |
| Stretched stripes | Unwrap distortion | Add seams, relax, check Display Stretch |
| Layered clothing fails validation or fits wrong | Cage UVs changed | Restore from the template |

A quick in-Studio test: assign a checker texture (a uniform grid image) as the `TextureID` or `ColorMap` while iterating. Distortion, density mismatch and flipped islands are obvious on a checker.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Tiling by scaling UVs past 1 | Out of spec; unpredictable or rejected | Tile with materials, MaterialVariants or Textures |
| Relying on a second UV channel | Ignored; Roblox reads one | One UV map |
| Smart UV Project on a character | Hundreds of tiny islands; unpaintable; seams everywhere | Hand-marked seams |
| Packing cages with the garment | Broken fit, failed validation | Exclude cages from all UV ops |
| Hard edge without a seam on a baked asset | Line artefacts in the normal map | Seams on all hard edges |
| 2 px margins on a 1024 texture | Colour bleeding at distance | 8 px or more, plus bake padding |
| Free rotation when packing hand-painted islands | Painter fights rotated islands | 90 degree steps only |
| Authoring at 4K for a phone game | Downscaled anyway; memory spent in Studio, not in game | Author at the size players will see |

## Checklist

- [ ] One UV map per mesh, all UVs inside 0 to 1.
- [ ] Seams on hard edges, hidden sides, material boundaries.
- [ ] No visible stretch (Display Stretch overlay).
- [ ] Islands averaged, then deliberately scaled for what players see.
- [ ] Texel density matches neighbouring assets (measured, not guessed).
- [ ] Margins sized for the texture resolution; bake padding set.
- [ ] Mirrored overlaps exactly overlapped and moved out during bakes.
- [ ] Cages untouched on layered clothing.
- [ ] Checked with a checker texture in Studio.

## See also

[[Texturing and PBR Baking]] · [[Normal Maps and Detail Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Hand-Painted and Stylized Texturing]] · [[Substance Painter and Texturing Tools]] · [[Exporting and Validating Models for Roblox]] · [[Modeling Fundamentals for Games]] · [[Topology and Edge Flow]] · [[Blender Workflow for Roblox Creators]] · [[Textures Decals and Texture Memory]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Modeling in Blender for Roblox]] · [[Layered Clothing Cages and Animation]]

## Connected notes
<!-- auto-links:start -->
[[Texel Density]] · Official Docs - Asset Creation · Materials and Surfaces Start Here · The Gradient Palette Texture Workflow · Tiling Trim Sheets and Decal Tricks · Baking Lighting and Detail into Textures
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[The Gradient Palette Texture Workflow]] · [[Low-Poly and Stylized Modeling]] · [[Modular Environment Kits]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Hard-Surface Modeling]] · [[Mesh Optimization for Mobile]] · [[Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs]] · [[Retopology and Decimation]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Voxel and Blocky Modeling]]
<!-- related:end -->
