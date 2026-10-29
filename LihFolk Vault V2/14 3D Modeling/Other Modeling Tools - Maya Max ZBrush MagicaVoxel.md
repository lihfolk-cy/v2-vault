---
tags: [modeling, tools, maya, 3ds-max, zbrush, magicavoxel, blockbench, pipeline, type/guide, area/modeling, level/intermediate]
---
# Other Modeling Tools: Maya, Max, ZBrush, MagicaVoxel

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting each tool's default units -> Reference cube per tool
> - Avoid: Shipping a ZBrush or scan mesh directly -> Retopo or decimate to budget
> - Avoid: Blockbench ASCII FBX into Blender -> Use glTF/GLB or OBJ
> - Tool chosen for what it is uniquely good at.
> - Reference cube and arrow imported into Studio from each tool's preset.
> - Units, axes and pivots normalised (often via Blender) before the final export.
>
> Cost: TL;DR ~150 tok · whole note ~3.7k tok. Read more: ## 2. Getting any tool's output into Roblox · ## 6. MagicaVoxel · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Blender is the default for Roblox creators, but it is not the only tool, and on many teams not the best one for every job. Studios hire artists who already know Maya or 3ds Max; sculptors live in ZBrush; voxel artists work faster in [[MagicaVoxel]] than any general tool; [[Blockbench]] is often the quickest route for blocky low-poly models. This note explains what each tool is good at, how its output gets into Roblox, the unit and axis traps for each, and how to mix tools in one pipeline without losing scale, pivots or normals on every hand-off.

Product details change: licensing, prices and feature names below are as of October 2026 and should be checked on each vendor's site before you budget for them. Roblox import facts are from the Creator Hub.

---

## 1. Choosing a tool

| Tool | Best at | Weak at | Typical Roblox use |
|---|---|---|---|
| **Blender** | Everything, free, Python | Some studio pipelines expect Autodesk formats and tools | Default for solo devs and small teams; see [[Blender Workflow for Roblox Creators]] |
| **Maya** | Rigging, animation, studio pipelines, retopology (Quad Draw) | Cost; modelling is fine but not unique | Teams with industry animators; avatar items (Roblox documents Maya export settings) |
| **3ds Max** | Hard-surface and architectural modelling, modifier stack, large scenes | Character animation is less common | Environment and prop artists from arch-viz or older game pipelines |
| **ZBrush** | Sculpting high detail, organic forms, polypaint | Game-ready topology needs retopology elsewhere (or ZRemesher) | High-poly sources for baking creatures and hero props |
| **MagicaVoxel** | Fast hand-made voxel art, palettes, rendering | Not a general mesh tool; needs cleanup for games | Voxel characters, props, icons ([[Voxel and Blocky Modeling]]) |
| **Blockbench** | Low-poly box modelling with per-face UVs, pixel textures | Not for complex topology | Blocky items, pets, simple characters |
| **Roblox Studio (Parts, Unions)** | Instant in-engine building | Precise organic or complex shapes | Blockouts, simple architecture ([[Parts Unions and MeshParts]]) |

Most teams pick one main tool and use the others for what they are uniquely good at: ZBrush for sculpting, a voxel editor for voxel art, Blender or Maya for everything else.

---

## 2. Getting any tool's output into Roblox

Studio's 3D Importer reads `.fbx`, `.obj` and `.gltf`/`.glb`; only FBX and glTF carry multiple objects, rigs, animation and vertex colours (Docs). So:

- **Static, single-mesh assets**: OBJ works from almost any tool.
- **Multi-part models, rigs, vertex colours**: FBX or glTF.
- **Uncertain tool output**: route through Blender. Import into Blender, fix scale, axes, origins and normals, export with your known-good preset. This "Blender as the normaliser" step costs a minute and removes most import surprises.

Whatever the tool, the same rules apply on arrival in Roblox (see [[Modeling Fundamentals for Games]]): at most 20,000 triangles per mesh, watertight geometry, no zero-thickness faces, at most 4 bone influences, frozen bone transforms (Docs).

### The unit trap

| Tool | Default working unit (typical) | What to do |
|---|---|---|
| Blender | Metres (or None) | 1 unit = 1 stud; GLB needs no scaling (Docs) |
| Maya | Centimetres | Roblox's Maya export settings use *Units: Automatic* (Docs); verify size with a known reference cube |
| 3ds Max | Generic units or inches/cm depending on setup | Set system units deliberately; export FBX with an explicit scale; verify |
| ZBrush | Unitless, often arbitrary scale | Scale in Blender or Maya before export |
| MagicaVoxel | 1 voxel = 1 unit in exports | Scale by your cell size (for example 0.5 for 0.5-stud voxels) in Blender |
| Blockbench | 16 units per block for many formats | Scale on import into Blender |

Make a **reference cube** of exactly 4 x 4 x 4 studs in each tool and import it into Studio once. If it is not 4 studs, fix the export settings before modelling anything else.

### The axis trap

Maya is Y-up; Blender, 3ds Max and MagicaVoxel's own view are Z-up; each exporter may convert differently, so check every one. The importer has *World Forward* and *World Up* options (Docs) to correct whole files. Decide your project's "front" (Roblox -Z) and test with a model that has an arrow on its front.

---

## 3. Maya

**Strengths**: the animation and rigging standard in AAA, solid modelling tools, the **Quad Draw** tool in the Modeling Toolkit for retopology, Python and MEL scripting, robust FBX.

**Roblox's documented Maya FBX export settings** (Docs): Geometry *Smooth Mesh* on and *Referenced Asset Content* on; Animation off unless importing an animation (and *Bake Animation* on when you do); *Embed Media* on when importing PNG textures; *Units: Automatic*; *Up Axis: Y*.

**Workflow notes**:
- Freeze transformations and delete history before export (Maya's equivalent of applying transforms and modifiers).
- Set pivots deliberately (Maya's pivot is separate from the transform; "Bake Pivot" to commit it).
- Soften/Harden Edge controls shading like Blender's sharp edges; check normals after export.
- Teams with Maya animators often still model in Blender and rig in Maya, or the reverse. Agree on one rest pose and one scale.

---

## 4. 3ds Max

**Strengths**: a mature modifier stack (similar in spirit to Blender's), excellent hard-surface and architectural workflows, large-scene handling, the **ProOptimizer** modifier for decimation, many legacy game studios' environment pipelines.

**Workflow notes**:
- Z-up like Blender; FBX export converts to Y-up with the *Up Axis* option.
- Reset XForm before export (the equivalent of applying rotation and scale), then collapse the stack.
- Smoothing groups control shading: assign them deliberately, or export with explicit normals.
- Check system units and FBX scale with a reference cube.

---

## 5. ZBrush

**Strengths**: sculpting millions of polygons interactively, organic forms, surface detail, polypaint (vertex colour painting), and remeshing tools: **DynaMesh** (even remeshing while sculpting), **ZRemesher** (automatic quad retopology, guided by curves), **Decimation Master** (high-quality triangle reduction that can preserve UVs and polypaint). ZBrush has been owned by Maxon since 2022; check current licensing and platform versions on Maxon's site.

**Where it fits a Roblox pipeline**:

```
ZBrush sculpt (millions of polys)
  -> ZRemesher or manual retopo (Blender/Maya)   game mesh, 1k-15k tris
  -> UV in Blender/Maya
  -> bake high to low (normal, AO, curvature)   see Normal Maps and Detail Baking
  -> texture (Substance Painter, Blender)
  -> export GLB/FBX to Studio
```

Use Decimation Master for static props (rocks, statues, stumps) where deformation does not matter, and ZRemesher or manual retopology for anything that animates ([[Retopology and Decimation]]).

**Traps**: ZBrush's scale is arbitrary; set the sculpt's real size in Blender/Maya. Exported OBJ from ZBrush can come in flipped on one axis depending on export settings; check against the low poly. Never ship a sculpt's polycount: every sculpt must be reduced to game budget.

Blender's own sculpt mode (with voxel remesh and Dyntopo) covers much of the same ground for stylised work; mobile sculpting apps exist too. Choose ZBrush when the detail level or team experience calls for it.

---

## 6. MagicaVoxel

**Strengths**: a free voxel editor that is the fastest way to hand-build voxel models: box, brush, line and face tools, a 256-colour palette per file, mirroring, and a good path-traced renderer for previews and icons. Models are limited to **256 x 256 x 256 voxels** each (several models can share a scene). Native format `.vox`; exports include **OBJ** (mesh + material file + a palette texture) and **PLY** (sources: MagicaVoxel community documentation; the developer's site is the authority).

### MagicaVoxel to Roblox

1. **Design on a grid that matches your cell size.** If your game's voxel cell is 0.5 studs, a 26-voxel-tall character becomes 13 studs.
2. **One colour per material role**, three tones per material (shadow, body, lit), as in [[Voxel and Blocky Modeling]]. Put each role in a known palette slot so recolouring is a palette swap.
3. **Export OBJ.** MagicaVoxel's OBJ export uses the palette texture with each face's UVs pointing at its colour: a palette atlas, exactly the cheap colouring method from [[Low-Poly and Stylized Modeling]].
4. **Import into Blender**, scale by the cell size (1 voxel = 1 unit on export), rotate to Z-up with the front toward -Y, set the origin (feet or pivot), and check the triangle count.
5. **Split by part** if it will be rigged (a separate object per limb with origins at the joints), or by colour group if you colour by `Color` in Studio.
6. **Reduce**: MagicaVoxel exports already merge coplanar faces in many cases; if not, a Planar decimate merges same-colour coplanar faces. Keep one quad per cell only if you use a per-cell stud texture.
7. **Export GLB** with your preset; import with *Scale Unit Stud*.

### Alternatives

Qubicle (commercial voxel editor), Goxel (open source) and others follow the same idea; the Blender cleanup step is the same. Roblox Studio itself can be a voxel editor with a code builder (see the VoxKit example in [[Voxel and Blocky Modeling]]).

---

## 7. Blockbench

**Strengths**: a free, beginner-friendly low-poly box modeller built for blocky game models (it grew up around Minecraft), with per-face UV control, pixel-art texture painting inside the tool, simple animation, and a *Generic Model* format for engines other than Minecraft.

**Export formats** (Blockbench wiki): **OBJ** (widely supported, no hierarchy or animation), **glTF/GLB** (hierarchy, animation, embedded textures; quads converted to triangles and vertices split per face), and **FBX** (ASCII only, which Blender cannot import).

**Roblox route**: export glTF/GLB, import into Blender to check scale (Blockbench formats often use 16 units per block), axes and origins, then export your preset. For simple static pieces, importing Blockbench's GLB straight into Studio can work; verify scale with the reference cube.

Pixel textures: set texture filtering expectations. Roblox textures are filtered; tiny pixel-art textures look soft unless authored larger (for example upscaled 4x with nearest-neighbour before upload). See [[Hand-Painted and Stylized Texturing]].

---

## 8. Other tools worth knowing

| Tool | What it is | Note for Roblox |
|---|---|---|
| Substance 3D Modeler | VR/desktop sculpting | Sculpt source, then retopo |
| Plasticity, Fusion and other CAD-style tools | NURBS/CAD modelling for clean hard-surface shapes | Export meshes with controlled tessellation; triangle counts can be huge if you do not set it |
| Houdini | Procedural generation, scattering, terrain | Powerful for pipelines; outputs need the same cleanup and budgets |
| Photogrammetry and 3D scan apps | Real objects to meshes | Dense triangle soup with baked lighting: decimate and re-texture; rarely fits stylised Roblox art |
| AI mesh generators | Text or image to 3D | See [[AI 3D Model Generation Outside Roblox]] and [[Roblox Generative AI - Cube Mesh and Texture Generation]]. The reference project banned generated meshes for its map art after early results, requiring hand-built Blender assets with "quad topology, controlled triangulation, [[weighted normals]], consistent texel density, packed atlas, LOD for big pieces" |

---

## 9. Mixing tools without losing data

Every hand-off between tools can lose scale, axes, pivots, normals, UVs or names. Rules that keep a multi-tool pipeline safe:

1. **One "source of truth" scene per asset** in one tool. Other tools produce inputs (a sculpt, a voxel model), not the final asset.
2. **One exchange format per hand-off** (FBX for Maya/Max rigs, OBJ or GLB for static meshes), with a saved export preset in each tool.
3. **Reference cube and arrow** checked once per tool and per preset.
4. **Names are contracts**: keep object names stable across tools (Roblox scripts may depend on them).
5. **Apply or freeze transforms** before every export, in every tool.
6. **Normals**: export explicit normals, or reapply shading in the final tool.
7. **Final export from one place** (usually Blender) with the project's tested Roblox preset ([[Exporting and Validating Models for Roblox]]).

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Trusting each tool's default units | Models 100x off | Reference cube per tool |
| Shipping a ZBrush or scan mesh directly | Over 20,000 triangles, triangle soup | Retopo or decimate to budget |
| Blockbench ASCII FBX into Blender | Import fails | Use glTF/GLB or OBJ |
| MagicaVoxel exports used unscaled | 1 voxel = 1 stud giants | Scale by cell size |
| No freeze / reset transforms | Wrong pivots, odd rotations in Studio | Freeze (Maya), Reset XForm (Max), Apply (Blender) |
| Different "front" per tool | Assets face random directions | One documented front; test arrow |

## Checklist

- [ ] Tool chosen for what it is uniquely good at.
- [ ] Reference cube and arrow imported into Studio from each tool's preset.
- [ ] Units, axes and pivots normalised (often via Blender) before the final export.
- [ ] Sculpts and scans reduced to budget; anything that deforms retopologised.
- [ ] Voxel exports scaled by the cell size, palette preserved.
- [ ] Names stable across tools; one final export preset.

## See also

[[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[Voxel and Blocky Modeling]] · [[Retopology and Decimation]] · [[Substance Painter and Texturing Tools]] · [[Exporting and Validating Models for Roblox]] · [[Exporting FBX vs GLB]] · [[3D Importer Settings Reference]] · [[AI 3D Model Generation Outside Roblox]] · [[Art Pipeline - Concept to In-Game Asset]]

## Connected notes
<!-- auto-links:start -->
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · Voxel Modelling Start Here · Voxel Scale Grids and Stud Alignment · Meshing Voxels for Roblox - Greedy Meshing and Export · Modeling in Blender for Roblox · Flat Colour vs Gradient Atlas vs Vertex Colour
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Voxel Scale Grids and Stud Alignment]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Organic and Creature Modeling]] · [[Normal Maps and Detail Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Mesh Optimization for Mobile]] · [[Modular Environment Kits]] · [[Topology and Edge Flow]] · [[UV Unwrapping]] · [[Hard-Surface Modeling]]
<!-- related:end -->
