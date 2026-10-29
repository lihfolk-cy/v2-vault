---
tags: [materials, pbr, tiling, procedural, skybox, sky, lighting, blender, qa, lihfolk, type/guide, area/materials, area/lighting, level/advanced]
verified: 2026-10-28
---
# Procedural Materials and Skies - Lessons

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Judging tiling by eye on one tile.
> - Avoid: Baking light direction into the Color map.
> - Avoid: Channel-packing roughness and metalness.
> - Wrap-diff <= 1.25 and half-tile re-bake difference <= 0.004
> - Separate 1024 maps; normal OpenGL; no baked light
> - Material names itself at game distance
>
> Cost: TL;DR ~120 tok · whole note ~1.5k tok. Read more: ## 1. Proving a material tiles · ## 4. Skyboxes: seams and poles · ## Common mistakes · ## Checklist
<!-- tldr:end -->

How a scripted generator produced tiling PBR material sets (for `MaterialVariant` / `SurfaceAppearance`) and six-face Roblox skyboxes that pass measured gates and a blind review panel. From the LihFolk V2 asset pack: 99 material and 46 sky ledger entries (**Measured**). Scores are blind rubric scores out of 10, pass bar 8.5, median of three reviewers.

## 1. Proving a material tiles

Eyeballing a tile is unreliable. Two measured checks did the job:

- **Wrap-diff.** For every map, take the step across the wrapped edge (last row to first row, last column to first column) and divide it by the 95th percentile of the steps between rows and columns inside the map. Pass at 1.25 or below on both axes. A seamless map scores about 1: the seam is just another row.
- **Half-tile re-bake (shift proof).** Re-bake the procedural shader with UV offset by (0.5, 0.5) and compare it with the original bake rolled by half a tile. Mean absolute difference must be 0.004 or less. This proves the shader is periodic even when a mortar line or plank edge happens to sit exactly on the border, where wrap-diff alone can be fooled.

Make noise and patterns periodic in the shader (integer tile counts, wrapped coordinates) rather than trying to fix seams after baking. **Measured:** after a fix round that included even tile counts, the tile sets (cream, mosaic) scored 10.0.

## 2. Other material gates worth automating

- Five separate 1024 x 1024 PNGs: Color, Color_Neutral (for tinting), Normal, Roughness, Metalness. Roblox expects separate greyscale maps, not channel-packed ones.
- Normal maps in OpenGL convention (+Y up): mean XY near 0.5, mean Z high.
- **No baked directional light** in Color: the correlation between luminance and the normal's X or Y must stay under 0.25. Height-based tone (darker grout) is fine.
- Plausible values: dielectric albedo not near black or white; metalness nearly binary; metal albedo bright.

## 3. What reviewers scored down

Normal strength (M3) was the most frequent low criterion across families. Other patterns (**Measured**):

- **Readability at game distance decides most fails.** Mud, icy snow, arcane lava and amber crystal (4.2-5.8) could not be named without the label.
- **Lava needed emissive rework and crust relief**: 4.2-5.4 first pass, 8.8 after two rounds.
- **Crystal stayed hard:** removing the host rock and reducing facets lifted it from 5.8 to 7.5-8.8, then it slipped back to 7.9 in the final round.
- **Planks:** longer, single boards and no knots passed; short busy boards failed on tiling.
- **Narrow the families.** Dropping themes that never passed and keeping variations of passing themes was cheaper than forcing every theme through.

## 4. Skyboxes: seams and poles

Face convention used: Roblox space, Y up, front = -Z. `SkyFt` -Z, `SkyBk` +Z, `SkyRt` +X, `SkyLf` -X, `SkyUp` +Y, `SkyDn` -Y. The in-plane rotation of Up and Dn is easy to get wrong; verify it once in Studio.

- **Cube seam check.** For all 12 cube edges, compare the colour step across the seam with the step between the two rows just inside each face. Worst ratio of 1.6 or less passes. Use a ratio, not an absolute cap, because star fields have big steps everywhere.
- **Pole pinch check.** On Up and Dn, compare the angular gradient on rings close to the face centre with rings further out. A ratio of 2.5 or less passes. A sky painted in latitude-longitude converges at the pole (gradient grows like 1/r); a sky computed from view direction does not.
- **Generate from direction, not from a lat-long image.** Evaluate each pixel of each face from its 3-D view direction and seams and poles disappear by construction.
- **One sun.** If the sky paints a sun disc, set `Sky.CelestialBodiesShown = false`.
- **Match the Lighting preset to the sky.** `Atmosphere.Color` within about 25 RGB of the sky's horizon colour, so the fog melts into the horizon.

## 5. What fixed sky scores

- **Crisp, shaded clouds** (lit tops, darker bases) instead of soft noise; cloud stylisation (K4) was the most common low criterion.
- **A camera roll bug in the preview** made horizons tilt. Fixing the preview camera mattered as much as fixing the sky.
- Sunsets and golden hours passed most easily; storms and toon clouds stayed at 6.4-7.3 because mood was ambiguous.

## Common mistakes

- Judging tiling by eye on one tile.
- Baking light direction into the Color map.
- Channel-packing roughness and metalness.
- Painting skies in lat-long and projecting to a cube.
- A painted sun plus Roblox's own sun.
- Fixing art when the preview camera is wrong.

## Checklist

- [ ] Wrap-diff <= 1.25 and half-tile re-bake difference <= 0.004
- [ ] Separate 1024 maps; normal OpenGL; no baked light
- [ ] Material names itself at game distance
- [ ] Sky faces generated from view direction; seam ratio <= 1.6; pole ratio <= 2.5
- [ ] One sun; Atmosphere colour matched to horizon
- [ ] Preview camera checked (no roll) before review

## See also

- [[SurfaceAppearance PBR Workflow]]
- [[MaterialService and Custom Materials]]
- [[Tiling Trim Sheets and Decal Tricks]]
- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Water Sky and Atmosphere Art]]

## Connected notes

[[Materials and Surfaces Start Here]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · Stylized Lighting Recipes

<!-- related:start -->
## Related
[[Baking Lighting and Detail into Textures]] · [[Stylised vs Realistic Material Pipelines]] · [[Texturing and PBR Baking]] · [[Hand-Painted and Stylized Texturing]] · [[Case Study - Building LihFolk V2 with AI Agents]] · [[Terrain Materials and Painting]]
<!-- related:end -->
