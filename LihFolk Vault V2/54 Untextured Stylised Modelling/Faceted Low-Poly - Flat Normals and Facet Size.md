---
tags: [modeling, untextured, low-poly, faceted, flat-shading, normals, facet-size, blender, performance]
---
# Faceted Low-Poly - Flat Normals and Facet Size

<!-- tldr:start -->
> [!tldr] TL;DR
> - Faceted rock looks smooth and blobby in Studio: Normals not exported or recalculated -> FBX Smoothing "Normals Only" or glTF Normals on; Shade Flat before...
> - Rocks look like random noise blobs: Facets too small for the viewing distance, all the same size -> Size facets by on-screen pixels; big planes plus small edge facets
> - Mountains look like fine static: Same facet size in studs as small props -> Scale facets with object size and distance
> - Distance players usually see each asset class written down, and target facet size in studs derived from it.
> - 5 to 12 facets across the silhouette; bigger on planes, smaller on curvature.
> - Shade Flat (or deliberate sharp edges), triangulated, modifiers applied, normals exported.
>
> Cost: TL;DR ~230 tok · whole note ~3.7k tok. Read more: ## Facet size: measure it in pixels, not studs · ## Building a faceted rock, step by step · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Faceted low-poly is the style where every triangle or polygon is a visible flat plane: gem-like rocks, origami trees, crystal mountains, polygon animals. With no texture detail, the facets *are* the surface detail, so two decisions carry the whole look: how the normals are set (every face flat, or a deliberate mix), and how big each facet is on screen. [[Low-Poly and Stylized Modeling]] introduces the style and its segment counts. This note goes deeper into flat normals as data (what they cost, how they survive export and import), facet size measured in on-screen pixels for the Roblox camera, how to distribute facets so a model reads as designed rather than random, and the cases where faceting is the wrong call.

## What flat shading actually is

A mesh's shading normal decides how light hits each point. With **smooth shading**, a vertex shared by several faces has one averaged normal, and light blends smoothly across the faces. With **flat shading**, each face has its own normal at each of its corners, so the whole face receives one lighting value and the edge between two faces is a sharp step in brightness.

On the GPU, a vertex is a position plus its normal, UV and colour. Different normals at the same position mean different GPU vertices. So:

- **Smooth closed mesh:** roughly half as many GPU vertices as triangles (rule of thumb from mesh topology: a closed triangle mesh has about V = T / 2 vertices).
- **Fully flat mesh:** exactly 3 GPU vertices per triangle, because no corner shares a normal with a neighbour.

A 2,000-triangle faceted rock is about 6,000 GPU vertices; the same rock smooth-shaded is about 1,000. That is six times the vertex data. For a few hundred faceted props this is irrelevant on any device. For a forest of 400 faceted trees at 1,500 triangles each, it is 1.8 million GPU vertices of mesh data in memory versus about 300,000 smooth (rule of thumb arithmetic). Faceted style is cheap in triangles and less cheap in vertices; budget for it.

Roblox docs (as of October 2026) cap a single mesh at 20,000 triangles. The docs do not publish a separate vertex limit on the specifications page; treat the triangle cap as the binding limit and keep faceted meshes far below it anyway.

## Getting flat normals out of Blender and into Roblox

Blender manual terms.

1. **Shade Flat** (Object menu, or right-click in Object Mode) sets every face flat. Since Blender 4.1 the old Auto Smooth option is gone; **Shade Auto Smooth / Smooth by Angle** is now an operator and a modifier node group that marks edges sharp above an angle. For a fully faceted mesh you do not need it: Shade Flat is enough.
2. **Mixed models** (a smooth mushroom stem with a faceted cap): Shade Smooth, then mark the cap's edges sharp (Edge > Mark Sharp) or use Smooth by Angle at a low angle (about 5 to 15 degrees) on the cap only.
3. **Export normals.** FBX: the exporter's Geometry panel has a **Smoothing** option (Normals Only, Face, Edge); "Normals Only" writes the custom split normals, which is what you want. glTF: Normals is on by default under Mesh data. Both formats carry split normals; Roblox uses the imported normals (rule of thumb; the importer documentation does not discuss normals, but faceted meshes import faceted in practice).
4. **Apply modifiers** on export, so Decimate, Triangulate and Smooth by Angle results are baked into the file.

A quick check after import: if a faceted rock arrives smooth and blobby in Studio, the normals were not written (or a re-export through another tool recalculated them). If a smooth mesh arrives faceted, the opposite happened, often from a mesh that was split by a UV operation and re-merged without normals.

## Facet size: measure it in pixels, not studs

A facet reads as an intentional plane only if it is big enough on screen. Too small and the surface looks noisy, then at distance it averages out into a smooth-ish blob with sparkle. Too big and the object looks unfinished or like a placeholder.

### The Roblox camera maths

Roblox docs (as of October 2026) give `Camera.FieldOfView` a default of 70 degrees, measured vertically. The height of the view at distance `d` studs is `2 x d x tan(35 degrees)`, about `1.4 x d` studs. So on a screen `H` pixels tall, one stud at distance `d` covers about `H / (1.4 x d)` pixels.

| Distance from camera | Pixels per stud at 1080 px tall | At 720 px tall (a typical phone render height, rule of thumb) |
|---|---|---|
| 10 studs | about 77 | about 51 |
| 25 studs | about 31 | about 21 |
| 50 studs | about 15 | about 10 |
| 100 studs | about 8 | about 5 |
| 200 studs | about 4 | about 3 |

(Phones often render below native resolution; the exact render resolution depends on device and graphics level and Roblox does not publish it. 720 is a planning number.)

### Facet size targets

Rule of thumb, tested against common stylised games:

- A facet should cover **at least about 12 px** on the target screen at the distance players usually see the object, so it reads as a plane with its own lighting value.
- The object's silhouette should show **roughly 5 to 12 facets** across its largest dimension. Fewer looks like a placeholder; more starts to look like a smooth mesh with noise.

Worked numbers: a 4-stud rock usually seen from 25 studs on a phone is about 84 px tall. Twelve-pixel facets give about 7 facets across, so facets of about 0.6 stud. A 40-stud cliff seen from 100 studs is about 200 px tall; 12 to 20 px facets give 10 to 16 across, so facets of 2.5 to 4 studs. The rule scales: **facet size grows with object size and viewing distance, and should be roughly constant in pixels across the scene.** A world where every facet is about 1 stud no matter the object looks wrong: tiny rocks are a single blob, and mountains look like fine noise.

### Facet distribution

Even facets everywhere is the beginner look (an icosphere with displacement). Designed faceting varies size on purpose:

- **Big facets on big planes.** The top of a cliff, the flank of a mountain, the side of a crystal. These planes catch one strong lighting value and read as structure.
- **Small facets where curvature is high.** The edge where top meets side, the tip of a crystal, the knuckle of a root. Small facets there read as a bevel.
- **Long facets along the form's direction.** On a tree trunk, facets taller than wide read as bark grain; on a wave, facets along the crest read as motion.
- **Fewer facets on the shadow side.** Faces turned away from the sun get only ambient light; extra facets there are wasted triangles (rule of thumb).

The squint test from [[Shape Language and Silhouette Testing]] still applies: at a glance the object should split into 2 or 3 big value groups, with facets as texture inside them.

## Triangulation and long thin triangles

A quad that is not perfectly planar shades as two triangles with slightly different normals. In a faceted style this is either a feature (more facets) or noise (a visible diagonal crease across a face you meant as one plane).

- Triangulate yourself before export (Triangulate modifier, or Face > Triangulate Faces) so Blender and Roblox agree on the diagonals.
- On faces that should be one flat plane, flatten them first (scale the selection to zero along its normal, or use the LoopTools Flatten add-on if installed).
- **Avoid long thin triangles** (aspect ratio over about 8:1). They make spiky highlights and break the "designed plane" read. Decimate Collapse often produces them; follow it with **Decimate Planar** (which merges near-coplanar faces into polygons) and retriangulate.

## Building a faceted rock, step by step

Blender, about 10 minutes, no texture.

1. **Add an Ico Sphere** with Subdivisions 2 (80 faces; Subdivisions 1 is the bare 20-face icosahedron, too sharp for a rock).
2. **Scale it** to the rock's real size in studs (1 Blender unit = 1 stud with your import settings; see [[Exporting and Validating Models for Roblox]]), wider than tall: for a 4-stud rock, about 4 x 4 x 2.6.
3. **Shape by hand** in Edit Mode with Proportional Editing on: pull 3 or 4 vertices out to make a dominant plane on top and a heavier side. A rock needs a top plane and a direction, not random bumps.
4. **Add a Displace modifier** with a Voronoi texture at low strength (about 10 to 15 percent of the rock's size) for irregularity.
5. **Decimate, Collapse** to about 60 to 120 triangles, then **Decimate, Planar** at about 5 to 10 degrees to merge near-flat faces into larger facets.
6. **Check facet size** against the table above: for a rock seen from 25 studs, facets of about 0.5 to 0.8 stud.
7. **Flatten the base** (select bottom vertices, scale Z to 0) and sink it 0.2 studs below ground level so it never floats.
8. **Shade Flat.** Triangulate. Apply modifiers.
9. **Colour.** Map faces into a gradient palette strip with a small random V offset per face (see [[The Gradient Palette Texture Workflow]]): this makes neighbouring facets differ slightly even under flat ambient light, which is the classic faceted look. Or use flat `Color` with SmoothPlastic if the rock is one colour.
10. **Make 4 to 6 variants** by changing the hand-pulled planes, not just the noise seed. Scatter with random yaw and 0.8 to 1.3 scale.

Result: about 100 triangles, about 300 GPU vertices, one MeshPart.

## Faceted style under Roblox lighting

Facets need light from a direction to show. Things that flatten them:

- **Strong uniform ambient.** If `Ambient` and `OutdoorAmbient` are bright and `Brightness` is low, every facet gets nearly the same value. Faceting disappears into a silhouette. Keep a clear difference between lit and shadow sides; see [[Lighting Untextured Art in Roblox]].
- **Sun straight overhead.** At noon (`ClockTime` around 12), vertical facets all receive similar grazing light. A sun 30 to 50 degrees above the horizon shows faceting best.
- **`LightingStyle = Soft`.** Softer lights and shadows (Roblox docs, as of October 2026) reduce contrast between facets slightly; usually fine, but check.
- **Low graphics levels.** Shadows may drop or simplify on low levels (rule of thumb). Facet-to-facet shading from the sun direction itself (N dot L) normally survives, which is why faceted art degrades gracefully.

The per-face colour jitter in step 9 above is insurance: even in flat light, adjacent facets still differ.

## Mixing faceted and smooth in one world

A whole world faceted can feel harsh; a common professional mix (rule of thumb from public stylised games such as low-poly survival and exploration titles):

| Faceted | Smooth |
|---|---|
| Rocks, cliffs, mountains, crystals | Characters, pets, NPC faces |
| Tree canopies, bushes | Water, clouds, sky elements |
| Terrain props, ice | UI-adjacent pickups, coins, orbs |
| Architecture in a "polygon" theme | Soft goods: cloth, pillows, banners |

Keep the rule in the style sheet ([[Keeping a Mixed Asset Library Consistent]]). The failure mode is a faceted rock next to a smooth rock of the same size: one of them looks like a mistake.

Characters especially: faceted avatars or pets look good in renders but animate poorly with skinning, because facets stretch and change their lighting value as the mesh deforms, which reads as flicker. Rigid segmented faceted characters (one MeshPart per limb) avoid this.

## When not to facet

- **Skinned, deforming meshes** with large bends (faces flicker as they stretch).
- **Very small props** that will be under about 30 px on screen: facets become noise. Use a smooth low-poly shape with a flat colour.
- **Huge surfaces seen from above at a distance** (a whole island): facets shrink to a few pixels and shimmer as the camera moves. Use bigger facets on the far geometry, or smooth shading with a gradient.
- **Roblox Terrain integration**: Terrain is smooth (or voxel blocky); faceted props on smooth terrain need a strong contact solution (sunk bases, ground-coloured bottoms) or they float visually.
- **Games where avatars dominate the screen**: Roblox avatars are smooth-shaded; a fully faceted world can clash. Facet the far environment, keep near props smooth.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Faceted rock looks smooth and blobby in Studio | Normals not exported or recalculated | FBX Smoothing "Normals Only" or glTF Normals on; Shade Flat before export |
| Rocks look like random noise blobs | Facets too small for the viewing distance, all the same size | Size facets by on-screen pixels; big planes plus small edge facets |
| Mountains look like fine static | Same facet size in studs as small props | Scale facets with object size and distance |
| Spiky highlights and slivers | Long thin triangles from Collapse decimation | Planar decimate, retriangulate, keep aspect under about 8:1 |
| Faceting invisible in game | Flat ambient light, sun overhead | Directional light 30 to 50 degrees up, clearer ambient vs sun contrast; per-face colour jitter |
| Faceted characters flicker in animation | Skinned flat faces stretching | Rigid segmented parts, or smooth shading for characters |
| Unexpected memory use on dense faceted forests | Flat shading triples GPU vertices | Fewer, larger facets; LOD; smooth shading on distant trees |

## Checklist

- [ ] Distance players usually see each asset class written down, and target facet size in studs derived from it.
- [ ] 5 to 12 facets across the silhouette; bigger on planes, smaller on curvature.
- [ ] Shade Flat (or deliberate sharp edges), triangulated, modifiers applied, normals exported.
- [ ] No triangles over about 8:1 aspect.
- [ ] Per-face colour variation via gradient atlas jitter or deliberate per-face colours.
- [ ] Faceted vs smooth rule written in the style sheet.
- [ ] Checked in Studio under the game's lighting, at the usual distance, on a phone emulator.

## Related

- [[Low-Poly and Stylized Modeling]]
- [[Topology and Edge Flow]]
- [[Retopology and Decimation]]
- [[Clean Stylised Shading - Weighted and Custom Normals]]
- [[The Gradient Palette Texture Workflow]]
- [[Lighting Untextured Art in Roblox]]
- [[Shape Language and Silhouette Testing]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Mesh Optimization for Mobile]]
- [[Low-Poly Tree Set Worked Example]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Modeling Fundamentals for Games]] · [[Low-Poly Creature From a Flat Reference Sheet]] · [[Hard-Surface Modeling]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]]
<!-- auto-links:end -->
