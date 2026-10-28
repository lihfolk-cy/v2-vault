---
tags: [core-concept, art, texturing, 3d-modeling, performance]
---
# Texel Density

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox's texture specifications page says textures up to 4096 by 4096 are supported, while the same page describes texture...
> - Pick a target per asset class, not one number for everything.
> - Big surfaces should tile. A 200-stud wall cannot get good density from one unique texture, even a 4K one.
> - Scaling a mesh in Studio scales its density down.
>
> Cost: TL;DR ~130 tok · whole note ~1.0k tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Texel density** is how many texture pixels (texels) cover one unit of surface in the world, for example 256 texels per stud. Consistent texel density means a crate, a wall and a sword all look equally sharp at the same viewing distance; inconsistent density makes some objects crisp and others blurry side by side.

## Why it matters on Roblox

Roblox's texture specifications page says textures up to 4096 by 4096 are supported, while the same page describes texture maps in 1024 by 1024 pixel spaces (Roblox docs, "Texture specifications", as of October 2026; the page is ambiguous about which limit applies to which map, so check before planning around 4K). Either way, phones have little texture memory and the engine may serve lower resolutions on weak devices. Throwing a bigger texture at a blurry asset is the expensive fix, so density has to be planned: which assets deserve texels, which can share an atlas, and which can use tiling materials instead.

## The nuance most people miss

1. **Pick a target per asset class, not one number for everything.** Hero items seen up close (weapons in first person, the player's pet) need higher density than background props. A common approach is one density for the world and a higher one for held items (rule of thumb: decide early and write it down).
2. **Big surfaces should tile.** A 200-stud wall cannot get good density from one unique texture, even a 4K one. Use tiling materials, MaterialVariants or trim sheets, which repeat and so keep density at any size.
3. **Scaling a mesh in Studio scales its density down.** A crate textured at the target density, scaled 3x in Studio, has a third of the density on each axis. Kits should be built at final size.
4. **UV space is the budget.** Wasted UV space (large gaps, mirrored parts unmirrored, hidden faces given texels) lowers the effective density. Pack UVs tightly and give hidden faces almost nothing.
5. **Stylised art hides low density.** Flat colours and soft gradients survive low density far better than photo textures with fine detail. Picking a style is partly picking a texture budget.
6. **Mismatched density is more visible than low density.** A uniformly soft world reads as a style; one sharp prop next to a blurry one reads as a mistake.

## Tiny example

A 4 by 4 stud crate with a 512 pixel texture covering all six faces in a 3 by 2 layout gives each face about 170 pixels, roughly 43 texels per stud. A sword 4 studs long with its own 512 texture, unwrapped along its length, gets about 128 texels per stud. If players hold the sword near the camera, that difference is correct; if both sit on the same shelf, the crate will look blurry next to it.

## Where this shows up

- [[UV Unwrapping]]: laying out UVs to the target density.
- [[Textures Decals and Texture Memory]]: memory cost of textures.
- [[Trim Sheets Atlases and Vertex Colors]]: sharing texels across assets.
- [[Tiling Trim Sheets and Decal Tricks]]: tiling for big surfaces.
- [[Texturing and PBR Baking]]: baking at the right resolution.
- [[SurfaceAppearance PBR Workflow]]: PBR maps on Roblox.
- [[MaterialService and Custom Materials]]: tiling materials.
- [[Hand-Painted and Stylized Texturing]]: styles that tolerate low density.
- [[Modular Environment Kits]]: consistent density across a kit.
- [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]: density in 2D art.
- [[Art Budgets - Triangles Draw Calls Memory]]: texture memory in the budget.
- [[Mesh Optimization for Mobile]]: phone memory limits.

Related concepts: [[Triangle Budget]], [[Draw Calls]], [[Thumbnail Contrast]].

## Connected notes
<!-- auto-links:start -->
[[Materials and Surfaces Start Here]] · [[Stylised vs Realistic Material Pipelines]] · [[Modeling in Blender for Roblox]] · [[Baking Lighting and Detail into Textures]] · [[AI Material and Texture Generation]] · [[Links - UVs and texture prep]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
