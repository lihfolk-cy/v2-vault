---
tags: [modeling, 3d, fundamentals, meshes, budgets, topology, type/guide, area/modeling, level/beginner]
---
# Modeling Fundamentals for Games

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Budgeting faces instead of triangles -> Read the triangle count
> - Avoid: One mesh over 20,000 triangles -> Split by material or body part, or decimate
> - Avoid: Unapplied scale -> Apply rotation and scale before export
> - Brief written: camera distance, count on screen, animated or not, triangle budget.
> - Blockout at final scale beside a character proxy, checked in Studio.
> - Silhouette readable as a filled black shape.
>
> Cost: TL;DR ~150 tok · whole note ~4.9k tok. Read more: ## 1. What a mesh is to the engine · ## 3. Budgets that shipped · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A game model is not a sculpture. It is a set of triangles that a phone GPU must draw 30 to 60 times a second, next to hundreds of other models, under a camera that is usually 20 to 200 studs away. Everything in this section follows from that sentence: why triangle counts matter more than polygon counts, why a silhouette beats surface detail, why a pivot in the wrong place costs a programmer a day, and why "it looks fine in Blender" is not a test.

This note is the foundation for the rest of `14 3D Modeling`. It explains what a mesh is to the engine, the hard limits Roblox puts on meshes, the budgets one production game actually shipped with, and the order of work that keeps you from redoing models. Tool steps live in [[Blender Workflow for Roblox Creators]]; style choices in [[Low-Poly and Stylized Modeling]], [[Hard-Surface Modeling]] and [[Organic and Creature Modeling]].

Source labels: **Docs** (Roblox Creator Hub or the Blender manual), **Measured** (the reference project, one live action game), **Rule of thumb** (experience, not a hard limit).

---

## 1. What a mesh is to the engine

### Vertices, edges, faces and triangles

- A **vertex** is a point with a position. In the GPU's eyes it also carries a normal, one or more UV coordinates, a colour and (for skinned meshes) bone indices and weights.
- An **edge** joins two vertices. Edges matter to you (they define loops, seams and sharpness) but the GPU never draws them.
- A **face** is a polygon: a triangle, a quad (4 sides) or an n-gon (5 or more).
- The GPU only draws **triangles**. Every quad becomes two triangles and every n-gon becomes `n - 2` triangles when the mesh is exported or imported.

So the number you budget is **triangles** ("tris"). A model of 5,000 quads is 10,000 triangles. Blender's statistics overlay shows both faces and triangles; always read the triangle line.

### The vertex count you see is not the vertex count the GPU sees

A vertex on the GPU is a unique combination of position, normal, UV and colour. If two faces meet at a corner but need different normals (a hard edge) or different UVs (a UV seam), that corner becomes **two GPU vertices**. A hard-edged cube has 8 positions in Blender but 24 GPU vertices (each face has its own normals). Consequences:

| Thing you do | Effect on GPU vertices |
|---|---|
| Mark an edge sharp (flat shading split) | Splits every vertex along it |
| Put a UV seam on an edge | Splits every vertex along it |
| Flat-shade the whole mesh | Every face gets its own vertices: roughly 3 per triangle |
| Smooth-shade with a few sharp edges where the UV seams already are | Splits only once (seams and sharps coincide) |

**Rule of thumb:** place hard edges on UV seams and UV seams on hard edges. You pay for the split once instead of twice, and normal-map bakes behave better (see [[Normal Maps and Detail Baking]]).

### Normals decide how light sees the surface

A normal is the direction a surface faces. Two kinds matter:

- **Face normals**: one per face, used for flat shading and to decide which side is the front.
- **Vertex (split) normals**: what the renderer interpolates across a face for smooth shading. Blender can also store **custom normals** (written by [[Weighted Normals|Weighted Normal]], by Bevel's Harden Normals, or by hand), and Roblox's importer keeps the normals you export.

Two failure modes recur constantly:

1. **Flipped faces.** A face whose normal points inward renders as a hole from outside (Roblox culls back faces unless the mesh is double-sided). Fix in Blender with *Mesh > Normals > Recalculate Outside*. Roblox's mesh specification asks for watertight meshes with no exposed backfaces (Docs).
2. **Smoothing across a hard corner.** A 90 degree box corner smooth-shaded looks like a dark smeared blob. Use sharp edges, *Smooth by Angle*, or bevel the corner and harden normals. Detailed in [[Hard-Surface Modeling]].

### Draw calls, materials and reuse

Every distinct combination of mesh, material and textures is, roughly, separate work for the renderer. Two ideas follow:

- **Fewer materials per object is cheaper.** A Roblox MeshPart carries one surface (one `TextureID` or one `SurfaceAppearance`), so a prop with five material slots ends up as five MeshParts or loses four of its looks; one with a single atlas texture is one MeshPart. Plan one material per mesh. See [[Trim Sheets Atlases and Vertex Colors]].
- **Reusing the same mesh asset is cheaper than many unique meshes.** Fifty copies of one rock with one texture cost the engine far less memory and setup than fifty unique rocks (Roblox performance guidance encourages reusing meshes and textures; exact batching behaviour is engine-internal, so treat the size of the win as a rule of thumb). This is the whole case for [[Modular Environment Kits]].

---

## 2. The hard limits Roblox puts on meshes

These are verified against the Creator Hub (as of October 2026). Where a fact is the reference project's measurement it says so.

| Limit | Value | Source |
|---|---|---|
| Triangles per mesh | **20,000** | Docs (mesh specifications) |
| Bone influences per vertex | **4** | Docs |
| Bones/joints | frozen: scale 1,1,1, rotation 0,0,0; root at 0,0,0; no influence on the root | Docs |
| Geometry | watertight, no exposed holes or backfaces, quads where possible, avoid n-gons, no zero-thickness faces | Docs |
| Animation per exported model | one animation track | Docs |
| Import formats | `.fbx`, `.obj`, `.gltf`/`.glb`; only FBX and glTF carry multiple objects, rigs, animation and vertex colours | Docs (3D Importer) |
| Avatar body triangle budget | head 4,000; torso 1,750; each limb 1,248; 10,742 total | Docs, see [[R15 Rig Anatomy and Attachments]] |
| Automatic mesh LOD (`RenderFidelity = Automatic`) | full detail under 250 studs, medium 250-500, lowest beyond 500 | Docs |
| Part size per axis | 2,048 studs | Engine limit for BaseParts (rule of thumb to stay well under it) |

Two consequences people learn the hard way:

- **The 20,000 limit is per mesh, not per model.** A 40,000-triangle boss is legal if it is split into several meshes. The reference project's Realm 1 enemies ran 10,268 to 42,240 triangles each, always split into many parts (one boss: 31k triangles over 32 parts, largest part 6.5k) (Measured). The limit shapes how you split, which also affects how you rig: see [[Organic and Creature Modeling]].
- **Zero-thickness geometry is out.** A single plane for a leaf or cape is "zero thickness". In practice Roblox imports planes, but the spec asks for closed volumes and back faces are culled, so a cape plane vanishes from behind. Either give it thickness (Solidify) or import with *Make Double Sided* (costs more, Docs).

---

## 3. Budgets that shipped

Limits say what is allowed; budgets say what keeps a game at frame rate on a mid phone. These are the reference project's real numbers, which you can use as a sanity check for your own.

| Asset class | Triangles (shipped) | Notes |
|---|---|---|
| Realm 1 enemies (voxel style, 49 models) | 10,268 to 42,240 per enemy; most 15k to 37k | Split into many parts; at most a handful on screen per player (Measured) |
| Bosses | 20,580 to 36,456 | Same voxel style as regulars; bosses were not resized (Measured) |
| Planned enemy budget (pre-voxel revamp plan) | 3k to 6k regulars, 10k to 15k bosses | The plan; the voxel style blew through it because every stud and seam is geometry. Worth knowing when you pick a style |
| Hand-modelled sword (32 parts) | 26.8k and 29.5k | One held per player, plus orbiting pieces (Measured) |
| Armour set (13 pieces + glow companions) | 15.0k to 20.3k per set, max 3,140 per mesh | Worn by every player: the per-mesh cap matters (Measured) |
| Hub hero prop: roll altar | 7.3k over 9 meshes | One in the hub (Measured) |
| Hub fountain | 9.2k over 7 meshes | |
| Hub prize spinner | 7.2k over 7 meshes | |
| Daily chest | 8k | |
| Shop kiosk with NPC outfit | 43.5k over 20 meshes | The heaviest single hub piece |
| Canyon wall segment (modular) | about 3.5k each, ~76 studs wide, 190-230 tall | Repeated 194 times along a realm |
| One zone's terrain meshes | 90k over 31 meshes | Hand-modelled zone art (Measured) |
| Landmark meshes (revamp plan) | 10k max each, with LOD via RenderFidelity | Planned budget |

How to read this table:

- **Count by what is on screen, not by asset.** A 40k boss is fine because there is one. A 3k armour piece is "expensive" because 30 players wear 13 of them.
- **Repeated things get the tightest budgets.** The wall segment is cheap per copy because there are hundreds.
- **Styles have costs.** Voxel and studded styles look simple but every cube face is real geometry unless you bake it to a texture. See [[Voxel and Blocky Modeling]].
- **Budgets are shared with VFX, UI and physics.** A model budget that ignores particles is a model budget that will be cut later. See [[Art Budgets - Triangles Draw Calls Memory]].

---

## 4. Shape language: what players actually see

At game distance a model is mostly a silhouette with two or three colour areas. Detail that does not change the silhouette or the big colour shapes is often invisible.

### Silhouette first

Fill your model black against a white background (Blender: Workbench render, flat lighting, single colour). If you cannot tell what it is, no texture will save it. The reference project's style guides all start from this check: "silhouette must be identifiable as a filled black shape" and "reads at 40 px tall against both sky and ground".

### Primary, secondary, tertiary

| Level | What it is | Where the triangles go |
|---|---|---|
| Primary | Overall mass and proportion (big head, long blade, hunched back) | Few triangles, most of the design effort |
| Secondary | Large features that break the outline: horns, pauldrons, guards, spikes | Most of the triangle budget |
| Tertiary | Rivets, scratches, panel lines, stitches | Texture or normal map, almost never geometry |

A beginner spends triangles on tertiary detail. A professional spends them on curvature that shows in the silhouette (a round shoulder needs segments; a flat chest panel needs none).

### Exaggeration

Game characters are read from above and behind, small, in motion. One feature exaggerated 1.5 to 2 times (fists, weapon head, shoulders) gives readability and personality. The reference project's outlined voxel style used fists at 1.4x, forearms 1.25x and the hammer head 1.3x on a boss, scaled about the existing joint pivots so every animation still fit.

### Scale reference

1 Blender unit = 1 stud is the convention in this vault (see [[Blender Workflow for Roblox Creators]]). A default R15 character is about 5.2 studs tall as stored and 5.5 in game once its joints solve; the reference project scaled players 1.6x to about 9 studs (see [[R15 Rig Anatomy and Attachments]]). Keep a proxy of your game's real character in every Blender file. Doors, stairs, weapon lengths and enemy heights only make sense against it. The reference project sized regular enemies to about 13 studs so they loomed over a 9-stud player.

---

## 5. The order of work

Redoing a UV unwrap because you changed the topology, or redoing topology because the pivot was wrong, is the most common waste in modelling. Work in this order:

1. **Brief**: purpose, camera distance, how many on screen, animated or static, budget. Write the budget down.
2. **Blockout**: primitives at final scale beside the character proxy. Check silhouette and proportions in-engine if possible (import a blockout; it takes minutes).
3. **Pivot and axes**: decide the origin and facing now (section 6). Everything downstream depends on it.
4. **Primary and secondary forms**: with modifiers kept live (Mirror, Bevel, Subdivision, Array) so you can still change things.
5. **Topology pass**: clean loops where it deforms, remove what the silhouette does not need. See [[Topology and Edge Flow]].
6. **Optimise**: apply modifiers, decimate or retopologise, check the budget. See [[Retopology and Decimation]].
7. **Normals**: sharp edges, weighted normals, recalc outside.
8. **UVs and texture**: [[UV Unwrapping]], [[Texturing and PBR Baking]].
9. **Export and validate**: [[Exporting and Validating Models for Roblox]].
10. **In-engine check**: lighting, distance, LOD, collision, performance.

Steps 2 and 3 are where most time is saved. A blockout imported into Studio in the first hour finds the "the door is too small for the character" problem before anything is built.

---

## 6. Pivots, origins and facing

In Roblox the pivot of an imported MeshPart (and the model's `WorldPivot`) is what `PivotTo`, rotation tools and most scripts use. A pivot in the wrong place is invisible in Blender and expensive in Studio.

| Asset | Origin (pivot) | Facing |
|---|---|---|
| Characters, creatures | Ground centre between the feet, or the root bone at 0,0,0 | Front toward Blender -Y (lands on Roblox -Z, the `LookVector`, with GLB; see [[Enemy Import Axis Fix]]) |
| Props that sit on the ground | Bottom centre of the footprint | Front toward -Y |
| Doors, lids, hinged parts | On the hinge axis | Hinge axis along a world axis |
| Weapons | Grip centre | Blade along +Z in Blender; see [[Modeling Weapons and Props]] |
| [[Modular Kits\|Modular kit]] pieces | A grid corner or bottom centre on the grid | See [[Modular Environment Kits]] |
| Spinning parts | Centre of rotation | Spin axis along a world axis |

The Studio importer has two pivot options that interact with this (Docs): *Set Pivot to Scene Origin* (on by default; the model's pivot becomes the scene origin) and *Use Imported Pivot* (on by default; each object keeps its own origin as its pivot). If you set origins in Blender, keep both on and your pivots arrive intact. The reference project also found that an Open Cloud upload add-on wrote pivot offsets into uploaded meshes, so parts came in rotated until those offsets were cleared (Measured).

**Apply transforms.** Before export, every mesh object should have rotation 0,0,0 and scale 1,1,1 (Ctrl+A, *All Transforms* or *Rotation & Scale*). Unapplied scale is the cause of bevels that look uneven, modifiers that behave oddly and rigs that import at the wrong size. Location can stay non-zero if you want objects placed relative to each other (the importer's *Insert Using Scene Position* keeps them there).

---

## 7. Detail strategies and their costs

| Want detail? | Technique | Cost | When |
|---|---|---|---|
| Changes silhouette | Real geometry | Triangles | Always for outline features |
| Panel lines, rivets, bevel highlights | Normal map baked from high poly | One texture set (memory) | Hero props, weapons, characters |
| Colour variation, dirt, edge wear | Colour map or vertex colour | Memory, or free with vertex colours | Everything |
| Repeated detail (planks, bricks, trim) | Trim sheet or tiling texture | Shared texture | Environments, kits |
| Soft rounded edges | Small bevel + weighted normals | 2 to 4x tris on beveled edges only | Hard-surface |
| Far away | LOD (`RenderFidelity = Automatic`) or a separate low mesh | Small | Big landmarks |

The texture route is cheaper per object but costs memory, and texture memory is the first thing that runs out on low-end phones (see [[Textures Decals and Texture Memory]]). The geometry route is cheaper on memory but costs triangles. Most good Roblox art mixes: geometry for silhouette, one shared atlas or trim sheet for everything else.

---

## 8. Readability under Roblox lighting

Roblox scenes are often bright, saturated and seen on small screens. Some things that look good in a Blender render fail in Studio:

- **Low contrast between parts.** Two similar greys merge at distance. The voxel references in this vault use a three-tone rule per material: shadow, body, lit top (see [[Voxel and Blocky Modeling]]).
- **Thin features.** A 0.05-stud chain or antenna flickers or vanishes. At typical camera distances, features under about 0.2 studs are unreliable (rule of thumb).
- **Detail inside concavities.** Shadows hide it; the camera rarely sees it.
- **Neon overuse.** Bloom eats shape. The reference project capped glow at roughly 3 to 16 percent of a model's pixels depending on style.

Always check models in the game's real lighting and at the real camera distance, not only in Studio's default lighting.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Budgeting faces instead of triangles | Model "under budget" in Blender, over in Studio | Read the triangle count |
| One mesh over 20,000 triangles | Import fails or is rejected | Split by material or body part, or decimate |
| Unapplied scale | Uneven bevels, wrong sizes, rigs off | Apply rotation and scale before export |
| Flipped normals | Holes or dark faces in Studio | Recalculate Outside; check face orientation overlay |
| Smooth shading on hard corners | Dark gradients across flat faces | Sharp edges, Smooth by Angle, or bevel + harden normals |
| Many material slots per object | Dozens of MeshParts per prop | Atlas or trim sheet; one material per mesh |
| Tertiary detail as geometry | High triangle count, no visible gain | Bake or paint it |
| No scale reference | Doors too small, swords too long | Keep a character proxy in the file |
| Pivot at an arbitrary point | Scripts and rotations behave wrongly | Set origins deliberately before export |
| Checking only in Blender's renderer | Surprise in Studio | Import early, check in game lighting |

## Checklist

- [ ] Brief written: camera distance, count on screen, animated or not, triangle budget.
- [ ] Blockout at final scale beside a character proxy, checked in Studio.
- [ ] Silhouette readable as a filled black shape.
- [ ] Origin and facing set per the table in section 6.
- [ ] Transforms applied (rotation 0, scale 1).
- [ ] Each mesh under 20,000 triangles; whole asset within budget.
- [ ] Normals recalculated outside; hard edges on UV seams.
- [ ] One material per mesh where possible.
- [ ] Checked in Studio at game distance and lighting.

## See also

[[Blender Workflow for Roblox Creators]] · [[Topology and Edge Flow]] · [[Retopology and Decimation]] · [[Low-Poly and Stylized Modeling]] · [[Hard-Surface Modeling]] · [[Organic and Creature Modeling]] · [[Parts Unions and MeshParts]] · [[Modeling in Blender for Roblox]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Level of Detail and Model Streaming]] · [[Exporting and Validating Models for Roblox]] · [[UV Unwrapping]] · [[Rendering Performance]]

## Connected notes
<!-- auto-links:start -->
[[Clean Stylised Shading - Weighted and Custom Normals]] · AI 3D Model Generation Outside Roblox · Meshing Voxels for Roblox - Greedy Meshing and Export · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · Faceted Low-Poly - Flat Normals and Facet Size · Bevels Chamfers and Edge Highlights Without Textures
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Mesh Optimization for Mobile]] · [[AI 3D Model Generation Outside Roblox]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[Hand-Painted and Stylized Texturing]] · [[Procedural Model Kits - Lessons]] · [[UGC Avatar Items and Accessories]] · [[Curve-Based Modelling in Blender for Roblox]] · [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]]
<!-- related:end -->
