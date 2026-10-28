---
tags: [modeling, voxel, magicavoxel, goxel, blockbench, blender, tools, export, pipeline, textures]
---
# MagicaVoxel Goxel and Blockbench Workflows Compared

Three free tools dominate hand-made blocky art: **MagicaVoxel** (a dedicated voxel editor with a path-traced renderer), **Goxel** (an open-source voxel editor with an unbounded scene) and **Blockbench** (a box modeller with per-face UVs and pixel textures, which is not a voxel editor at all, though its output looks blocky). They produce very different data, and that difference decides your whole Roblox pipeline: how colour reaches the mesh, how many triangles you ship, whether you need Blender in the middle, and whether a model can be rigged. [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] introduces MagicaVoxel and Blockbench in a paragraph each. This note compares all three side by side, walks one model through each pipeline, and covers the Roblox-side settings that make or break blocky textures, in particular texture filtering, which most tutorials miss.

Product details change between releases. Facts below are labelled "tool docs" where they come from each project's own pages, and are as of October 2026. MagicaVoxel's official site did not render readable text when checked, so its limits are taken from its published file-format specification and long-standing community documentation and are marked as such.

## 1. What each tool actually produces

| | MagicaVoxel | Goxel | Blockbench |
|---|---|---|---|
| Data model | Dense voxel grids (models) in a scene graph | Sparse voxel layers | Cubes and meshes with UV-mapped pixel textures |
| Model size | Each model up to 256 x 256 x 256 voxels (community documentation; not confirmed on the developer's site); many models per scene | No limit; sparse storage (tool docs) | No voxel grid; size is free |
| Colour | Indexed palette of 256 entries, index 0 meaning empty, so 255 usable colours (file format spec) | 24-bit RGB per voxel (tool docs) | Painted textures, any size |
| Materials | Per-palette-entry material types: diffuse, metal, glass, emit (file format spec, MATL chunk) | Basic | Per-texture |
| Exports relevant to Roblox | OBJ (mesh, MTL and a palette PNG), PLY, VOX | glTF 2, OBJ, PLY, MagicaVoxel, Qubicle (tool docs) | glTF/GLB, FBX, OBJ, DAE and more (tool docs) |
| Animation and bones | None | None | Bones and keyframe animation, exported in glTF, FBX and DAE (tool docs) |
| Licence and platforms | Free; Windows and macOS | GPL 3, with a commercial licence on request; desktop and mobile (tool docs, latest 0.15.1) | Free and open source; desktop and web |

Three consequences:

1. **MagicaVoxel and Goxel give you voxels; Blockbench gives you boxes.** In MagicaVoxel a 0.25-stud stud-detail means one voxel. In Blockbench the same detail is either a tiny extra cube (more triangles) or two pixels painted on a big cube's texture (no triangles). Blockbench art is cheaper in geometry and more expensive in texture memory.
2. **The palette is a constraint you should welcome.** MagicaVoxel's 255 colours force you into a palette, which keeps merges and recolours easy ([[Voxel Palettes - Ramps Hue Shifting and Limits]]). Goxel's free 24-bit colour makes it easy to end up with 400 near-identical greens that block every greedy merge.
3. **Only Blockbench can rig and animate.** Voxel editor output always goes through Blender (or Studio) for joints. See [[Voxel Characters - Proportions Joints and Rigging]].

## 2. Where colour ends up on the Roblox side

How the colour is stored decides how you set up the MeshPart. There are four routes, and each tool favours one.

| Route | How | Favoured by | Roblox cost and caveats |
|---|---|---|---|
| **Palette texture** | Each face's UVs point at a swatch in a small palette image | MagicaVoxel OBJ, Goxel OBJ | One tiny texture shared by every model; UVs must hit swatch centres; filtering can bleed swatches (section 6) |
| **One mesh per colour** | Split the model by colour; each MeshPart gets `Color` | Any, after a split in Blender | No texture; one MeshPart per colour; easy recolour in Studio; more instances |
| **Vertex colours** | Colour stored per face corner | Goxel glTF, the Blender .vox importer, Blender scripts | No texture; the importer reads vertex colours from FBX and glTF (Roblox docs) and they multiply with the MeshPart's `Color` (community-reported and measured in the vault, see [[Trim Sheets Atlases and Vertex Colors]]); not documented on the MeshPart reference page |
| **Painted pixel texture** | A UV-mapped texture per model | Blockbench | One texture per model or per atlas; needs nearest-neighbour filtering or it blurs (section 6) |

Choose the route first and the tool second. If your game will recolour enemies per zone with a script, one mesh per colour or a palette texture with a TintMask-style setup is easier than vertex colours baked into the mesh.

## 3. MagicaVoxel pipeline

MagicaVoxel is the fastest tool for hand-built voxel art: box, voxel, face and line brushes, mirror modes, a pattern brush, and a renderer good enough for icons and store thumbnails.

1. **Set up the volume** at your cell count (from [[Voxel Scale Grids and Stud Alignment]]). Keep the model's bottom on the lowest layer of the volume, so the floor is z = 0.
2. **Load or build the project palette** and keep role slots fixed (for example slots 1 to 4 are the body ramp, 5 to 8 trim, 9 eyes). A fixed slot layout means a recolour is a palette swap.
3. **Split anything that will move** into separate models in the scene (head, body, limbs), each with its own transform. The scene graph is stored in the file (nTRN, nGRP and nSHP nodes, per the format spec).
4. **Export.** Two good options:
   - **OBJ export**: a mesh plus a palette PNG and an MTL file. One voxel is one unit (community documentation). The exporter writes only the outer shell, not interior faces.
   - **Save .vox and import into Blender with the "MagicaVoxel VOX format" extension** (Blender extensions site, supports Blender 4.2 LTS and newer). It offers meshing modes (one object per voxel, simple cubes, simple quads of visible faces, and greedy, with an optional watertight variant that removes T-junctions) and material modes (ignore, vertex colour, material per colour, a 256 x 1 palette texture, or textured models with generated base colour, emission, roughness and metallic maps) (tool docs). This is the better route for Roblox because you choose the meshing and colour route at import.
5. **In Blender**: scale by the cell size, apply transforms, set origins, split by colour or keep the palette texture, then export GLB ([[Meshing Voxels for Roblox - Greedy Meshing and Export]]).

**Strengths**: speed, palette discipline, renders. **Weaknesses**: the 256-voxel model limit (fine for props and characters, limiting for big buildings, which must be split into several models), no rigging, and the renderer's materials (glass, emit, metal) do not carry to Roblox. An "emit" voxel that glows beautifully in MagicaVoxel's render is just a colour in Studio until you give that colour group the Neon material or an emissive SurfaceAppearance.

## 4. Goxel pipeline

Goxel is the open, cross-platform choice. Its sparse storage removes the size cap (tool docs), it runs on Linux and mobile, and it exports glTF directly, which removes a format conversion.

1. **Pick colours from a project palette**, even though Goxel lets you choose any RGB. Load the palette file and stick to it; otherwise you will spend an afternoon quantising (the Luau quantiser in [[Voxel Palettes - Ramps Hue Shifting and Limits]] can rescue a Part build, but it is better not to need it).
2. **Use layers for moving parts**, the same way MagicaVoxel uses models.
3. **Export glTF 2** and import the result into Blender to check scale, merge, set origins and decide the colour route, or import straight into Studio for a quick prop test.
4. **Check the face count.** Exporters differ on whether coplanar same-colour faces are merged. Count triangles in Blender before assuming anything, and run your own greedy pass if the count is close to a voxel-per-face mesh.

**Strengths**: no size cap, open source, direct glTF, layers. **Weaknesses**: a less polished brush set and renderer than MagicaVoxel, and free colour invites palette drift.

## 5. Blockbench pipeline

Blockbench builds models from boxes, each with six UV-mapped faces, and paints a pixel texture onto them. The "Generic Model" format is the one to use for Roblox work: it is not tied to a game's restrictions and supports free rotation (tool docs).

1. **Decide the texel density first**: how many texture pixels per stud. A common blocky look is 16 pixels per block; with a 1-stud block that is 16 pixels per stud, so a 2-stud-tall pet's face gets about 32 vertical pixels. Keep the same density on every model or they will not look like one set.
2. **Use per-face UV** rather than box UV when you want to pack an atlas tightly; box UV (the classic cuboid unwrap) is faster for simple cubes but wastes texture space (community documentation).
3. **Paint in Blockbench's paint mode**, using a palette. Avoid soft brushes: anti-aliased edges defeat nearest-neighbour filtering.
4. **Rig and animate in Blockbench if you like**: groups act as bones with pivots. Export glTF or FBX. The Blockbench export guide notes that glTF triangulates quads and does not share vertices between faces, and that Blender cannot import the ASCII FBX that Blockbench writes (tool docs), so prefer glTF/GLB if Blender is in the middle.
5. **Check scale with a reference cube.** Blockbench works in 16 units per block in many formats; how that maps to metres in its glTF output was not confirmed here, so measure a known cube in Blender before setting your import scale.
6. **In Studio, set the texture to pixelated sampling** (next section), or every pixel-art face will look smeared.

**Strengths**: cheapest geometry for a given look, painted detail, built-in rigging and animation, a large plugin ecosystem. **Weaknesses**: texture memory per model, UV work, and a painted look that drifts away from pure voxel art (pixel detail on large flat boxes).

## 6. Texture filtering: the setting that decides whether blocky art looks crisp

Roblox filters textures bilinearly by default, which is right for photographs and wrong for pixel art. Two cases.

**Painted pixel textures (Blockbench).** A 16 x 16 face texture on a 1-stud cube, seen up close, covers far more screen pixels than it has texels, so bilinear filtering blurs every edge. `SurfaceAppearance` has a `ResampleMode` property: `Default` smooths with bilinear filtering, while `Pixelated` "preserve[s] the sharp edges of pixels using nearest-neighbor filtering" (Roblox docs, as of October 2026). So for pixel art on meshes, put the texture in a `SurfaceAppearance` ColorMap with `ResampleMode = Pixelated` rather than in `MeshPart.TextureID`, which has no such property on the MeshPart reference page. The docs do not say how `Pixelated` interacts with mipmaps when the texture is minified at a distance; test a distant view before relying on it.

**Palette textures (MagicaVoxel, Goxel).** Each face samples the centre of one swatch. Up close, bilinear filtering at a swatch centre returns that swatch's exact colour, so it looks fine. At a distance the GPU switches to smaller mipmap levels, in which neighbouring swatches have been averaged together, and faces drift towards their neighbours' colours: a red cell next to a green palette slot turns brownish at 80 studs. Fixes, best first:

1. **Expand each swatch to a block** of at least 8 x 8 pixels (a 16 x 16 grid of 8-pixel blocks is a 128 x 128 image holding 256 colours) and point UVs at block centres. Mip levels down to the block size stay clean.
2. **Use `ResampleMode = Pixelated`** on a SurfaceAppearance for the palette (with the mip caveat above).
3. **Abandon the palette texture** for that model and split by colour or use vertex colours.

Texture memory for these is trivial. A 128 x 128 palette is a sixty-fourth of the pixels of a 1024 texture (see [[Textures Decals and Texture Memory]]).

## 7. One model through each pipeline

A test model, used to compare: a treasure chest, 16 x 12 x 12 cells at 0.25 studs (4 x 3 x 3 studs), with a body, a lid, metal trim, a lock, and four colours.

| | MagicaVoxel to Blender (.vox importer, greedy) | Goxel glTF (no extra pass) | Blockbench |
|---|---|---|---|
| Geometry | About 150 to 300 triangles after greedy meshing, depending on trim detail (rule of thumb from face counting) | Similar if the exporter merges faces; up to a few thousand if it emits a quad per voxel face | About 12 triangles per box; 6 to 10 boxes is roughly 70 to 120 triangles |
| Colour | Palette texture or one mesh per colour | Vertex colours or palette | One 64 x 64 painted texture |
| Lid hinge | Separate model in the scene, origin set in Blender | Separate layer, origin set in Blender | Group pivot set in Blockbench |
| Time for an experienced artist | About 30 minutes | About 40 minutes | About 45 minutes including painting (rule of thumb) |

The numbers are illustrative, not measured on one specific chest, but they show the shape of the trade-off: voxel editors are faster for sculpting form, Blockbench is cheaper on triangles and better for anything that needs painted fine detail or animation.

## 8. Mixing tools in one game

Many blocky games mix tools: environment in a voxel editor, characters in Blockbench. That works if three things match:

- **Grain and texel density.** A 0.25-stud voxel cell should equal four Blockbench texels per stud times the same visual scale, or the characters will look finer or coarser than the world. Concretely: if the world uses 0.25-stud cells, paint Blockbench characters at 4 pixels per stud so one pixel equals one voxel.
- **Palette.** Export the voxel palette and load it as Blockbench's palette.
- **Shading.** Voxel exports carry no baked shading; painted Blockbench textures usually do. Either bake the same ambient occlusion into both ([[Voxel Shading - Baked AO Edges and Lighting]]) or keep painted shading very light.

## 9. When not to use any of them

- **Procedural or data-driven models** (generated terrain, rarity variants, player-built structures) are better built by script in Blender or Studio from cell data; see the builders in [[Voxel and Blocky Modeling]] and [[Blender Automation with Python]].
- **Smooth stylised assets** belong in Blender.
- **Large buildings** are often quicker as Parts in Studio on a 1 or 0.5 stud grid than as a 600-voxel-wide MagicaVoxel scene split into ten models.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Blockbench pixel art looks blurry in game | Bilinear filtering on `TextureID` | SurfaceAppearance ColorMap with `ResampleMode = Pixelated` |
| Voxel model colours shift at a distance | Mipmaps averaging adjacent 1-pixel palette swatches | Expand swatches to 8 x 8 blocks, or split by colour |
| MagicaVoxel glow voxels are dull in Studio | Emit material does not export | Separate the glow colour group; give it Neon or an emissive SurfaceAppearance |
| Goxel model will not greedy-merge | Hundreds of near-identical free-picked colours | Paint from a fixed palette; quantise before meshing |
| Blockbench FBX will not open in Blender | Blockbench writes ASCII FBX | Export glTF/GLB instead |
| Characters look sharper than the world | Texel density does not match voxel grain | One pixel equals one voxel across tools |
| Large building cut off in MagicaVoxel | Per-model size limit | Split into several models on a shared grid, or build it from Parts |

## Checklist

- [ ] Colour route chosen (palette texture, per-colour meshes, vertex colours or painted texture) before picking the tool.
- [ ] Project palette loaded in every tool; role slots fixed.
- [ ] Reference cube scale tested for each tool's exporter.
- [ ] Moving parts split as models, layers or groups with known pivots.
- [ ] Triangle count checked in Blender after export.
- [ ] Pixel textures use SurfaceAppearance with `ResampleMode = Pixelated`, tested close and far.
- [ ] Palette swatches at least 8 x 8 pixels, or no palette texture.
- [ ] Texel density and palette match across tools in a mixed pipeline.

## Related

[[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Voxel and Blocky Modeling]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Textures Decals and Texture Memory]] · [[SurfaceAppearance PBR Workflow]] · [[Exporting FBX vs GLB]] · [[3D Importer Settings Reference]] · [[Blender Automation with Python]] · [[Voxel Scale Grids and Stud Alignment]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Modelling Start Here]] · [[The Gradient Palette Texture Workflow]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Modeling in Blender for Roblox]] · [[Substance Painter and Texturing Tools]] · [[Untextured Stylised Modelling Start Here]]
<!-- auto-links:end -->
