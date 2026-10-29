---
cssclasses: [vault-hub]
tags: [materials, surfaces, hub, start-here, textures, pbr, terrain, type/hub, area/materials, level/beginner, api/Terrain, area/modeling]
---
# Materials and Surfaces Start Here

This section is about everything that sits on the outside of geometry: custom materials, PBR maps, terrain paint, tiling textures, decals and the light you bake into all of them. It builds on three notes and assumes you have met them: [[Links - Free and CC0 asset libraries]] (where to get CC0 texture sets and HDRIs), [[Textures Decals and Texture Memory]] (how image memory works) and [[Stylized Lighting Recipes]] (the lighting your materials will be judged under). The notes here go deeper: API behaviour checked against the Roblox docs (as of October 2026), strict Luau and Blender Python where they help, and a checklist in each.

## The notes

| Note | Read it when |
|---|---|
| [[MaterialService and Custom Materials]] | You are building a library of MaterialVariants, planning theme swaps, or chasing parts that silently look plain |
| [[SurfaceAppearance PBR Workflow]] | You import more than a handful of textured meshes and want them to batch, re-upload cleanly and look right in game |
| [[Terrain Materials and Painting]] | You paint terrain by hand or by script, want slopes painted automatically, or import a colormap |
| [[Tiling Trim Sheets and Decal Tricks]] | Your world is mostly Parts and repeats visibly, or you need signs, grime and impact decals that stay cheap |
| [[Baking Lighting and Detail into Textures]] | Assets look flat on phones, you want AO or gradients without engine support, or you are baking a fixed room |
| [[Stylised vs Realistic Material Pipelines]] | You are choosing a direction, converting CC0 sets to a stylised look, or changing direction mid-project |

## A suggested path

1. Decide the pipeline first: [[Stylised vs Realistic Material Pipelines]].
2. Build the shared layers: [[MaterialService and Custom Materials]] for tiling surfaces, then [[SurfaceAppearance PBR Workflow]] for meshes.
3. Dress the ground: [[Terrain Materials and Painting]].
4. Break repetition and add story: [[Tiling Trim Sheets and Decal Tricks]].
5. Add depth that survives every device: [[Baking Lighting and Detail into Textures]].

## Using the vault's own textures

Section 20 is a working asset library. Where it fits:

- **Custom materials:** downscale a set to 1024 for part variants or 512 for terrain, map `_diff`, `_nor_gl`, `_rough` (and `_metal` for metal sets), and pick [[StudsPerTile]] from density or real-world size. Worked through with `mossy_rock` in [[MaterialService and Custom Materials]].
- **Terrain details:** a grass-top, rock-side override from `forest_ground_04` and `mossy_rock` in [[Terrain Materials and Painting]].
- **AO:** the `_ao` and `_arm` maps Roblox ignores can be composited into colour maps with the script in [[Baking Lighting and Detail into Textures]].
- **HDRIs:** the same HDRI as the Blender world and the Studio sky keeps reflections and baked bounce light consistent ([[SurfaceAppearance PBR Workflow]], [[Baking Lighting and Detail into Textures]]).
- **Stylising:** a batch conversion of realistic sets into simplified, still-tiling stylised materials in [[Stylised vs Realistic Material Pipelines]].

## Related notes elsewhere

- Foundations: [[Materials MaterialVariants and SurfaceAppearance]], [[Texturing and PBR Baking]], [[Normal Maps and Detail Baking]], [[Trim Sheets Atlases and Vertex Colors]], [[Hand-Painted and Stylized Texturing]], [[UV Unwrapping]].
- Terrain: [[Terrain Tools and Terrain API]], [[Terrain Deep Dive - Materials Water and Performance]], [[Procedural World Generation]].
- Lighting: [[Lighting Technologies and Settings]], [[Light Sources and Shadows]], [[Atmosphere Sky Clouds and Post-Processing]].
- Budgets: [[Art Budgets - Triangles Draw Calls Memory]], [[Rendering Performance]], [[Memory Budgets and Leaks]], [[Mobile and Low-End Optimization]].
- Style: [[Environment Art Styles]], [[Zone and Biome Art Direction]], [[Low-Poly and Stylized Modeling]].
- Tools: [[AI Material and Texture Generation]], [[Substance Painter and Texturing Tools]], [[Blender Automation with Python]], [[Asset Upload Automation with Open Cloud]].

## Rules that run through the section

1. **Shared layers first.** Variants, templates and trim sheets are the parts of a look you can change in an afternoon.
2. **Pixels cost memory, files do not.** Size maps to texel density; 1024 is the ceiling for most in-world PBR maps.
3. **Silent fallbacks are the real bugs.** A missing variant or a hidden TextureID looks plain, not broken. Audit by script.
4. **Bake what survives rotation**, and judge everything in game lighting on a phone.

## Connected notes
<!-- auto-links:start -->
[[Texel Density]] · Links - Texturing · Skill - Roblox Asset Import · Links - Materials and MaterialVariants · Untextured Stylised Modelling Start Here · Draw Calls
<!-- auto-links:end -->
