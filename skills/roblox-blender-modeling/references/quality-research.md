# Blender to Roblox: professional standard for high-quality, Roblox-ready models

Research for the LihFolk plugin's Blender skill. Compiled 2026-10-28.

## Labels used

| Label | Meaning |
|---|---|
| **Roblox docs** | Stated on create.roblox.com, the Roblox/creator-docs GitHub source, or an official Roblox staff or announcement post |
| **Measured** | Verified by running bpy in a live **Blender 5.2.0 LTS** instance: operator defaults read via `get_rna_type()`, test meshes built and exported, and the exported FBX/GLB files parsed |
| **Rule of thumb** | Common practice among game artists, written in our own words. Treat it as convention, not a rule |
| **Derived** | Arithmetic on documented numbers (the working is shown) |
| **Proposed** | A LihFolk default chosen by this report where no source gives a number. Tune it by measurement |
| **Unverified** | Claimed somewhere but not confirmed, or sources conflict |

---

## 1. Roblox hard limits and import behavior

### 1.1 Geometry limits

| Item | Value | Label / source |
|---|---|---|
| Max triangles per individual mesh (MeshPart) | **20,000** | Roblox docs ([specifications](https://create.roblox.com/docs/art/modeling/specifications)) |
| Older figure of 10,000 tris | Outdated. The current specifications page gives 20,000 | Rule of thumb |
| "21,000" tris per MeshPart | Figure seen in some guides that conflicts with the docs. Use 20,000 | Unverified |
| General vertex limit | **Not documented.** No official source found | Unverified |
| Mesh must be watertight, with no exposed holes or backfaces and no zero-thickness geometry. Prefer quads and avoid N-gons | Rule | Roblox docs (specifications) |
| Max bone/joint influences per vertex | **4** | Roblox docs (specifications) |
| Bones frozen: scale 1,1,1, rotation 0,0,0, root at 0,0,0, no influence on the root | Rule | Roblox docs (specifications) |
| One animation track per exported mesh/model | Rule | Roblox docs (specifications) |
| Rigid accessory | **≤ 4,000 tris**, single mesh, textures ≤ **2048²** (larger ones are downscaled) | Roblox docs ([accessory specs](https://create.roblox.com/docs/art/accessories/specifications)) |
| Rigid accessory non-albedo maps | **256×256 max budget** | Roblox docs ([texture specs](https://create.roblox.com/docs/art/modeling/texture-specifications)) |
| Layered clothing | ≤ 4k tris, inner and outer cage, max bounding box 8×8×8 studs for shirts, pants and similar | Roblox docs via search summary ([layered specs](https://create.roblox.com/docs/avatar/layered-accessories/specifications)) |
| Character body budgets | Head 4,000; torso 1,750; each arm 1,248; each leg 1,248; **total 10,742** across 15 meshes. Textures ≤ 2048² | Roblox docs ([character-bodies specs](https://create.roblox.com/docs/avatar/character-bodies/specifications)) |
| MeshPart size cap | 2048 studs per axis | Rule of thumb. Not found in docs |
| Avatar items: Material = Plastic, Transparency 0, VertexColor 1,1,1 | Rule | Roblox docs (accessory and body specs) |

**Triangle math.** Roblox counts triangles, so an n-gon costs n−2 triangles. Roblox suggests estimating triangles as 2 × quads (Roblox docs, body specs). Measured triangle costs of Blender primitives in 5.2:

| Primitive | Tris / verts (Measured) |
|---|---|
| Cube | 12 / 8 |
| Cube + Bevel (width 0.05, Angle limit), 1 segment | 44 / 24 |
| Same, 2 segments | 108 / 56 |
| Same, 3 segments | 188 / 96 |
| Same, 4 segments | 300 / 152 |
| Cylinder with n-gon caps: 6 / 8 / 12 / 16 / 24 / 32 sides | 20 / 28 / 44 / 60 / 92 / 124 tris |
| UV sphere 8×6 / 12×8 / 16×8 / 32×16 | 80 / 168 / 224 / 960 tris |
| Icosphere: base / 1 subdivision / 2 subdivisions | 20 / 80 / 320 tris |

Takeaway (Measured): a 2-segment bevel on every edge of a box makes it **9× more expensive** (12 → 108 tris). A 1-segment chamfer costs about 3.7× (12 → 44 tris), and with weighted normals that usually gives most of the visual benefit (see §2).

### 1.2 Textures

| Item | Value | Label / source |
|---|---|---|
| Max texture resolution | **4096×4096**. Imports up to 8192 are accepted and transcoded to 4K. 4K applies to everything that supports texture streaming: MeshPart, SurfaceAppearance, Texture, Decal and MaterialVariant. Low-end devices automatically get lower mips. 4K works in Studio only when Texture Streaming is enabled | Roblox docs ([texture specs](https://create.roblox.com/docs/art/modeling/texture-specifications)) and Roblox announcement 2026-01-30 ([4k Texture Rendering](https://devforum.roblox.com/t/4k-texture-rendering/4316229)) |
| Conflict | The same texture-specs page still says "Roblox supports up to 1024×1024 pixel spaces for texture maps" in its UV section. Older staff tutorials (Mar 2024) say 1024 | Unverified/conflict. Treat 4K as the cap and **1024 as the practical default** |
| Formats | .png, .jpg, .tga, .bmp | Roblox docs |
| Map types (SurfaceAppearance) | ColorMap (RGB plus alpha), NormalMap, RoughnessMap, MetalnessMap, Emissive mask. Roughness, metalness and emissive are **separate 8-bit grayscale files, not channel-packed** | Roblox docs ([SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance), texture specs) |
| Normal maps | **OpenGL (Y+), tangent space only**. Flat = (127,127,255) | Roblox docs |
| UVs | **Single UV set**, all UVs inside 0–1. Overlapping UVs are allowed | Roblox docs (texture specs) |
| One material per mesh | "Mesh objects can have only one material assigned" | Roblox docs (texture specs) |
| Recommended sizes by object | ~5×5 studs → 256²; ~10×10 → 512²; ~20×20 → 1024² | Roblox docs |
| PBR budget by asset size | 1×1×1 → 64–128²; 2×2×2 → 256²; 4×4×4 → 512²; 8×8×8 → 1024² | Roblox docs |
| Implied texel density | 256/5 = 512/10 = 1024/20 = **51.2 px/stud**. The default Part material is 1024 px over 8 studs (128 px/stud) and terrain is 512 over 8 studs (64 px/stud) | Derived from Roblox docs |
| Memory | Cost scales with pixel count: a 1024² texture uses 4× the memory of a 512². "Keep images to 512×512 at most; most minor images under 256×256." Compressing the file does not reduce GPU memory | Roblox docs ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)) |
| Tileable textures and trim sheets | Max 1024², square. Trim sheets tile on one axis only, with one surface treatment per row (the sample uses 6 rows) | Roblox docs ([Develop polished assets](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/develop-polished-assets)) |
| SurfaceAppearance properties at runtime | Generally can't be changed by scripts; they are preprocessed | Roblox docs |
| SurfaceAppearance.Color tint | Multiplies the ColorMap at no performance cost, so one grayscale map can be reused with many tints | Roblox docs |
| AlphaMode | Overlay (default: transparent areas show MeshPart.Color), Transparency (cutout), TintMask, Opaque (beta) | Roblox docs |
| Cutouts | Keep MeshPart.Transparency = 0 for hard cutouts (foliage). Use ≥ 0.02 for soft translucency | Roblox docs |
| Marketplace emissive | EmissiveStrength 0–40 | Roblox docs |

### 1.3 Vertex colors

- The FBX/glTF importer supports vertex colors. Roblox docs ([3D Importer](https://create.roblox.com/docs/art/modeling/3d-importer)) list an "Ignore Vertex Colors" option that is off by default.
- Studio **multiplies** vertex color by MeshPart.Color. New meshes default to Medium Stone Grey (163,162,165), so set Color to **white (255,255,255)** to see true vertex colors. Color resolution is limited by vertex count. Source: Roblox staff (SCHLEEMPH, 2024-07-02, [DevForum](https://devforum.roblox.com/t/3050119)).
- Vertex colors work with built-in materials such as Fabric or SmoothPlastic. With SurfaceAppearance they show only through transparent ColorMap areas in Overlay mode. Source: Roblox staff post above, plus feature request [3981469](https://devforum.roblox.com/t/vertex-coloring-support-for-surfaceappearance/3981469) (Oct 2025 to Apr 2026, no staff fix noted).
- Vertex colors do not break instancing in themselves. Draw-call batching depends on MeshContent plus identical SurfaceAppearance, TextureContent or material (Roblox docs, Improve performance).

### 1.4 Units, scale and axes

| Fact | Label |
|---|---|
| 1 stud = 0.28 m in physics units | Roblox docs ([units](https://create.roblox.com/docs/physics/units)) |
| Treat DCC units as studs: Studio doesn't convert meters, so **2 m in Blender = 2 studs** | Roblox docs ([Beyond the Dark: building architecture](https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture)) |
| Blender setup: Scene > Units > Unit System **None**, Rotation in degrees | Roblox docs ([Blender page](https://create.roblox.com/docs/art/blender)) |
| FBX: default Blender FBX export often imports "at an unexpectedly large scale". **Recommended fix: Transform > Apply Scalings = "FBX Unit Scale"** with other scales at 1.0. Alternatives: export Scale 0.01, or scene Unit Scale 0.01 (which the docs warn causes camera and modifier issues) | Roblox docs (Blender page) |
| glTF: "does not require these additional scaling configurations" | Roblox docs (Blender page) |
| Export axes: Forward **Z**, Up **Y**, Limit to Selected | Roblox docs (Blender page) |
| Importer: Scale Unit = Stud (default), World Forward = Front, World Up = Top | Roblox docs (3D Importer) |

**Measured, Blender 5.2.0 LTS. Why FBX imports 100× too big.** A 4 m cube was exported with each FBX scale option and the FBX parsed:

| `apply_scale_options` | GlobalSettings UnitScaleFactor | Model Lcl Scaling | Vertex max |
|---|---|---|---|
| `FBX_SCALE_NONE` (**the default**) | 1 (cm) | **100,100,100** on the node | 2.0 |
| `FBX_SCALE_UNITS` (Roblox-recommended) | 100 (m) | none (1) | 2.0 |
| `FBX_SCALE_ALL` | 100 | none | 2.0 |

All FBX variants also carry Lcl Rotation −90° X from the Z-up to Y-up conversion. **GLB** wrote positions in meters directly (POSITION max = 2.0 for the 4 m cube), with no node scale. Conclusion (Measured plus Roblox docs): **prefer GLB for static meshes.** If you use FBX, always pass `apply_scale_options='FBX_SCALE_UNITS'`.

### 1.5 Export settings (Blender)

**FBX** (Roblox docs, [export requirements](https://create.roblox.com/docs/art/modeling/export-requirements)): Path Mode **Copy** with **Embed Textures** on; Apply Scalings **FBX Unit Scale**; **Add Leaf Bones off**; **Bake Animation off** unless exporting animation.

Measured Blender 5.2 defaults for `bpy.ops.export_scene.fbx`, showing what must be overridden:

| Parameter | Default | Set for Roblox |
|---|---|---|
| `use_selection` | False | True |
| `apply_scale_options` | `FBX_SCALE_NONE` | `FBX_SCALE_UNITS` |
| `add_leaf_bones` | **True** | False |
| `bake_anim` | **True** | False (static) |
| `path_mode` | `AUTO` | `COPY` |
| `embed_textures` | False | True |
| `use_mesh_modifiers` | True | True |
| `mesh_smooth_type` | `OFF` ("Normals Only") | Keep `OFF`, or `FACE` (Unverified whether Roblox needs smoothing groups) |
| `axis_forward` / `axis_up` | `-Z` / `Y` | Roblox Blender page says Forward **Z**, Up **Y** (Roblox docs) |
| `colors_type` | `SRGB` | SRGB |

Measured Blender 5.2 defaults for `bpy.ops.export_scene.gltf`:

| Parameter | Default | Set for Roblox |
|---|---|---|
| `export_format` | (GLB in UI) | `'GLB'` |
| `use_selection` | False | True |
| `export_apply` | **False. Modifiers are NOT applied** | **True**, or bevels and weighted normals are lost |
| `export_yup` | True | True |
| `export_normals` | True | True |
| `export_tangents` | False | False (Roblox computes tangents. Unverified) |
| `export_vertex_color` | `MATERIAL`: only exported when used by the material | Wire a Color Attribute node into Base Color, or use `'ACTIVE'` (enum also has `NAME`, `NONE`) |
| `export_image_format` | `AUTO` | `AUTO` (PNG). Avoid WEBP |
| `export_draco_mesh_compression_enable` | False | **Keep False** (Draco support in Roblox: Unverified) |

Measured: when a color attribute exists but the material does not use it, the glTF exporter logs *"The active Vertex Color will not be exported, as it is not used in the node tree of the material"*.

### 1.6 Pivot, origin and naming at import

- Importer defaults: **Set Pivot to Scene Origin = on** (the model pivot sits at the scene origin), **Use Imported Pivot = on** (each child uses its source pivot, i.e. the Blender object origin), Insert Using Scene Position = off, Anchored = off, Merge Meshes = off, Make Double Sided = off, Invert Negative Faces = off (Roblox docs, 3D Importer). Practical consequence: set each Blender object's origin deliberately before export.
- Pivot conventions: base-bottom for floor props such as crates, back for wall props such as an extinguisher, a consistent snap corner for modular kits (Roblox docs, Develop polished assets).
- Name suffixes converted on import: `_Att` → Attachment, `_OuterCage` → WrapTarget, `_InnerCage` plus `_OuterCage` → WrapLayer (Roblox docs, [meshes](https://create.roblox.com/docs/parts/meshes)).
- Each Blender object becomes a child MeshPart under a Model (Roblox docs, Assemble an asset library). One material per mesh means multi-material objects should be split by material in Blender (`bpy.ops.mesh.separate(type='MATERIAL')`) or unified onto one atlas. Rule of thumb.
- The importer does **not** de-duplicate meshes. Upload each unique mesh once and duplicate it in Studio rather than importing a whole map (Roblox docs, Improve performance).

### 1.7 Collision fidelity

| Option | Use | Label |
|---|---|---|
| Box | Cheapest. Use for small or non-interactive objects and **always when CanCollide is off** | Roblox docs; Rule of thumb |
| Hull | Convex. Good for most props; Roblox recommends it over Box for wall trim, because Box can catch jumping players | Roblox docs ([Assemble an asset library](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library)) |
| Default | Approximate shape that supports concavity | Roblox docs |
| PreciseConvexDecomposition | Most expensive. Use only where exact collision matters, such as doorway edges | Roblox docs |
| Tunable (`CollisionPrecision`) | Slider for precision versus cost | Roblox docs ([meshes](https://create.roblox.com/docs/parts/meshes)) |
| Large complex objects: build custom collision from invisible Box parts. For non-colliding parts set CanCollide, CanTouch and CanQuery to false | Rule | Roblox docs (Improve performance) |

### 1.8 RenderFidelity, LOD and mesh streaming

- `RenderFidelity`: **Automatic** (default) means Highest under 250 studs, Medium at 250–500, Lowest at 500+. **Precise** always renders highest. **Performance** prioritizes speed (Roblox docs, [RenderFidelity enum](https://create.roblox.com/docs/reference/engine/enums/RenderFidelity)). Avoid Precise on many meshes (Roblox docs, Improve performance).
- Roblox auto-generates LODs in the cloud: currently **4 LoDs per mesh**. A new system, **Mesh Streaming and Improved Cloud LoDs** (announced 2026-04-27), uses a quadric-error simplifier that better preserves silhouettes, UVs and normals. It **ignores and will remove `RenderFidelity`**. Phase 2 (opt-out, planned around July 2026) maps Default to Enabled. Phase 3 removes the property. In the post's example scene it rendered about 63–64% fewer triangles. Roblox announcement ([DevForum 4601232](https://devforum.roblox.com/t/introducing-mesh-streaming-and-improved-cloud-lods-in-published-experiences-opt-in-phase/4601232)).
- Implication for the skill: **do not author manual LOD meshes for Roblox.** Author one clean mesh whose silhouette survives simplification. Do not rely on RenderFidelity in new work.

### 1.9 Draw calls and instancing

- Meshes with the same MeshContent share a draw call when their SurfaceAppearance is identical, or (without SA) their TextureContent is identical, or their materials match (Roblox docs, Improve performance).
- Example scene budgets of about **500k triangles and about 500 draw calls**, with client memory under 1.3 GB for 2 GB phones. Rule of thumb.
- Kitbash: a tree built from 4 reused meshes, varied by color, rotation and scale, costs about 2 draw calls when its meshes and materials match. Reuse MeshIds (Rule of thumb).
- `DoubleSided` doubles rendering work. Enable it only on planar foliage (Roblox docs, Assemble an asset library).

### 1.10 Shading in Studio

- Roblox's ambient occlusion darkens creases sharper than about 30°, which can make low-poly smooth-shaded meshes look faceted. Fixes are to add supporting geometry or bevels. Rule of thumb. Unverified as engine fact.
- Roblox staff tutorial (blutzer, Mar 2024) uses **Shade Auto Smooth at 30°** before FBX export ([DevForum](https://devforum.roblox.com/t/substance-painter-overview-setup-and-general-pbr-creation/2884177)).
- Custom split normals: Roblox's mesh format may split edges instead of storing custom split normals. Whether weighted or custom normals survive import today is **Unverified**. The skill should verify in Studio once and record the result.

---

## 2. What separates top-tier Roblox models from poor ones

### 2.1 Silhouette and readability
- Spend geometry only where it changes the silhouette. Props should have "only enough geometry for the silhouette to read clearly". Roblox docs (Develop polished assets).
- **Silhouette test:** render the object as solid black at the smallest on-screen size it will appear (rule of thumb: about 32 px) and check it is still identifiable. **Squint test:** 2–3 dominant colors at about 64 px. Work in big → medium → small shapes. Rule of thumb. The "70% silhouette / 30% detail" ratio is a convention, not measured (Unverified).
- Shape language: circles read friendly, squares sturdy, triangles threatening (Rule of thumb, same sources).

### 2.2 Proportion and chunkiness (stylized)
- A chunky, non-uniform mass with tapering and slight edge curves gives props character. Push and Taper (Simple Deform) modifiers help. Rule of thumb.
- Exaggerate proportions: thick planks and posts, oversized handles and rims, flared bases. Avoid perfectly straight, uniform primitives (same sources). Avoid paper-thin parts: Roblox requires real volume (Roblox docs).

### 2.3 Bevels and edge highlights
- No real object has a perfectly sharp edge, and even one bevel segment catches light. Small bevels disappear at game distance, so **exaggerate** them. Use a few standard bevel sizes (S/M/L) consistently. Edges that are too soft can alias. Rule of thumb. Fixed absolute bevel widths keep them consistent.
- **Bevel plus face-weighted normals:** keeps the shading gradient inside thin bevels so large faces stay flat. This is the standard way to get clean low-poly hard surfaces without normal maps. Rule of thumb. Blender: Bevel modifier (`harden_normals` or Face Strength) followed by a Weighted Normal modifier (Face Influence, Keep Sharp). Blender manual ([Bevel](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/bevel.html), [Weighted Normal](https://docs.blender.org/manual/en/latest/modeling/modifiers/normals/weighted_normal.html)).
- Measured Blender 5.2 modifier defaults: Bevel width **0.1 m**, segments 1, limit Angle **30°**, harden_normals False, clamp_overlap True, profile 0.5. Weighted Normal: mode FACE_AREA, weight 50, threshold 0.01, keep_sharp False, face_influence False. The defaults are not tuned for game assets, so set them explicitly.
- Cost (Measured): see the §1.1 table.

### 2.4 Shading, normals and the faceted look
- Smooth vs flat (Measured, 2-segment beveled cube with 56 mesh verts, exported to GLB): **flat = 216 exported vertices, smooth = 56, smooth plus Weighted Normal = 56, Smooth-by-Angle 30° = 96.** Flat shading splits every face corner. Hard edges and seams split vertices.
- Blender 4.1+ removed `mesh.use_auto_smooth`. `bpy.ops.object.shade_auto_smooth(angle=...)` now adds a **"Smooth by Angle" geometry-nodes modifier** (Measured in 5.2; [Blender issue 119633](https://projects.blender.org/blender/blender/issues/119633)). Scripts written for 4.0 that set `use_auto_smooth` fail with AttributeError (Rule of thumb, [Plumber issue](https://www.github.com/lasa01/Plumber/issues/184)).
- Deliberate faceted low-poly (flat shading) is a legitimate style. The failure is *accidental* faceting: smooth shading on hard 90° corners causes dark gradients and "blobby" boxes. Hard-surface work should use bevel plus weighted normals, or sharp-by-angle.

### 2.5 Color and palette
- Use a limited, deliberate palette with 2–3 dominant colors per object at thumbnail size (squint test, §2.1).
- **Palette/gradient atlas:** all props share one small palette texture, and UVs are collapsed or snapped onto color cells. This gives one material, maximum draw-call batching and tiny memory. Use closest-pixel interpolation for crisp cells. Rule of thumb.
- Roblox-native recolor: author albedo as near-white grayscale and use `SurfaceAppearance.Color` tint for variants at no cost (Roblox docs). Or use vertex color times MeshPart.Color (Roblox staff).
- Avoid baked lighting in albedo for PBR. Hand-painted styles paint light into albedo on purpose: bake AO, lay flat colours, then add highlights from one consistent light direction, pushing highlights further on metal than on wood or stone (Rule of thumb).

### 2.6 Texture vs vertex color vs material

| Approach | Pros | Cons | Label |
|---|---|---|---|
| Vertex color + SmoothPlastic/built-in material | No texture memory, recolorable via Color multiply, single mesh | Resolution = vertex density; no SA; set Color white | Roblox staff post |
| Palette atlas (TextureID or SA ColorMap) | One texture for the whole kit, crisp colors, batches | Needs UVs snapped to cells | Rule of thumb |
| Trim sheet + SurfaceAppearance (PBR) | Rich detail at low memory, about 90% of Beyond the Dark's architecture used a few trim sets | UV discipline required | Roblox docs |
| Unique PBR bake per asset | Hero quality | Memory: keep ≤ 1024, mostly ≤ 512 | Roblox docs |
| MaterialVariant | Tiling world-space-style materials with physical properties; terrain override | Not UV-mapped detail | Roblox docs ([materials](https://create.roblox.com/docs/parts/materials)) |

### 2.7 Topology density budgets per object class

Sourced numbers:

| Class | Number | Label |
|---|---|---|
| Any single mesh | ≤ 20,000 tris (hard) | Roblox docs |
| Rigid accessory, hat | ≤ 4,000 (hard). Community target 3–4k | Roblox docs; Rule of thumb |
| Full avatar body | ≤ 10,742 total | Roblox docs |
| Small props | "~50–500 tris" | Rule of thumb |
| Game characters | "under ~2K" | Rule of thumb |
| Whole visible scene | ~500k tris / ~500 draw calls | Rule of thumb |
| Example car | 4,200 tris (used in Roblox's own LoD demo) | Roblox announcement |

**Proposed LihFolk default budgets.** These are not sourced numbers. They are derived to stay inside the sourced bands above and to keep about 300 visible unique objects under the ~500k scene figure. Tune them per game.

| Class | Stylized target | Ceiling |
|---|---|---|
| Tiny prop (cup, coin, pebble) | 20–150 | 300 |
| Small prop (crate, chair, lamp) | 100–600 | 1,500 |
| Medium prop (table, cart, statue) | 400–2,000 | 4,000 |
| Rock (each) | 50–400 | 1,000 |
| Tree (trunk + foliage clusters) | 300–2,000 | 5,000 |
| Hand weapon / tool | 300–2,500 | 4,000 (matches the accessory cap) |
| Building module (wall/floor piece) | 50–800 | 2,000 |
| Whole small building | 1,500–6,000 | split into modules if > 10,000 |
| NPC / creature | 1,000–5,000 | 10,742 (matches the body cap) |
| Hero/showcase asset | up to 10,000 | 20,000 per mesh (hard) |

Rule the skill should enforce: **a budget miss requires justification**, and *under*-budget meshes are fine only if they pass the silhouette and bevel checks.

---

## 3. Styles popular in Roblox and how to make them in Blender

| Style | Look | Blender method | Roblox setup | Labels |
|---|---|---|---|---|
| **Stylized low-poly (flat-shaded or soft)** | Chunky shapes, few tris, flat colors, sometimes faceted | Primitives → proportion edits → 1-segment bevels → Weighted Normal, *or* deliberate flat shading. Decimate (Collapse, about 0.1–0.15 ratio) to stylize organics like rocks and trees. Ico-sphere foliage clusters | Vertex colors + SmoothPlastic (Color = white), or palette atlas | Rule of thumb; Roblox staff vertex-color post |
| **Untextured stylized (Roblox-native color)** | Clean plastic/SmoothPlastic with per-part colors | Split by material/color region into separate meshes, or vertex color; bevels for highlights | MeshPart.Color + Material, recolorable in Studio. Creatures of Sonaria uses built-in Color/Material instead of textures | Roblox newsroom ([2026-07 creator interviews](https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos)) |
| **Gradient/palette atlas** | Soft color ramps, Synty-like | One small palette PNG; UV-snap faces to cells/strips; closest interpolation | One SurfaceAppearance or TextureID shared by every prop, giving maximum batching | Rule of thumb |
| **Hand-painted** | Painted light and shadow in albedo, WoW-like | Clean UVs → bake AO (and optionally curvature) → paint flat colors → highlights and shadows in Texture Paint / 3D-Coat / Substance | ColorMap only (normal/roughness optional). Roblox lighting still applies, so keep painted light subtle | Rule of thumb; Roblox docs ([texture painting](https://create.roblox.com/docs/art/accessories/creating/texture-painting)) |
| **Realistic PBR** | Physically based materials, trim sheets | High→low bake (normal, AO) in Blender or Substance; OpenGL normals; separate R/M grayscale maps; trim sheets for architecture | SurfaceAppearance (4 maps); Future lighting recommended (anecdotal: normal detail vanishes in ShadowMap shadows) | Roblox docs; Roblox staff Substance guide; Rule of thumb |
| **Voxel** | Blocky cubes | MagicaVoxel → Blender add-on with **greedy meshing** (merges coplanar same-color faces) → vertex color or palette UV | MeshPart with vertex colors; never thousands of Parts | Rule of thumb. Roblox specifics Unverified |

---

## 4. Efficient Blender workflows an AI can drive through bpy

### 4.1 Reliability matrix

| Step | API | Reliability | Notes (label) |
|---|---|---|---|
| Primitive creation | `bmesh.ops.create_cube/cone/uvsphere/icosphere` | **Reliable** | No context needed (Measured) |
| Modifiers (Bevel, Weighted Normal, Decimate, Mirror, Solidify, Array, Remesh) | `ob.modifiers.new()` plus property sets | **Reliable** | Data API, no context. Set every parameter explicitly (Measured) |
| Applying modifiers | `bpy.ops.object.modifier_apply` (needs active object) or export with `export_apply=True` / `use_mesh_modifiers=True` | Reliable with correct active/selection | glTF default does not apply (Measured) |
| Evaluated tri count | `ob.evaluated_get(depsgraph).to_mesh()` | **Reliable** | Measured |
| Smooth by angle | `bpy.ops.object.shade_auto_smooth(angle=0.5236)` | Reliable in 4.1+ | Adds a geometry-nodes modifier (Measured). `use_auto_smooth` is gone |
| Shade flat/smooth | `bpy.ops.object.shade_flat/shade_smooth` | Reliable | Measured |
| Recalculate normals | `bpy.ops.mesh.normals_make_consistent(inside=False)` (edit mode), or `bmesh.ops.recalc_face_normals` | Reliable | bmesh preferred (no mode switch) |
| Cleanup | `bmesh.ops.remove_doubles`, `bpy.ops.mesh.delete_loose`, `bpy.ops.mesh.dissolve_limited`, `bpy.ops.mesh.dissolve_degenerate` | Reliable | |
| Smart UV Project | `bpy.ops.uv.smart_project(angle_limit=rad(66), island_margin=0.02)` (edit mode, all selected) | Reliable | Measured (worked from MCP context) |
| Pack islands | `bpy.ops.uv.pack_islands(margin=…, rotate=True, shape_method='CONCAVE'/'AABB')` | Reliable | Fastest is Bounding Box + Add margin. "Fraction" can be about 10× slower (Blender manual). The `custom_region` mode allows packing into trim or atlas zones |
| UV overlap detection | `bpy.ops.uv.select_overlap()` in edit mode | **Worked** headless from MCP (Measured) | May need a UV-sync context in some builds. The bmesh fallback is O(n²) |
| Seams by angle / islands | `bpy.ops.uv.seams_from_islands`, `mark_seam` | Moderate | Hand-placed seams are hard to automate well |
| Baking (AO, Normal, Diffuse, Roughness, Emit) | `bpy.ops.object.bake(type=…)`, Cycles only, with an **active Image Texture node** in each material | **Fragile** | Measured gotchas: (1) other scene objects occlude the AO bake: the first test baked **all black** because test objects overlapped at the origin, and hiding them (`hide_render=True`) fixed it (mean value 0.684, 0.33 s at 256², 16 samples). (2) Result stays an internal image, so call `img.save_render()` or `filepath_raw` plus `save()`. Defaults: margin 16 px, margin_type EXTEND, normal_space TANGENT, swizzle +X +Y +Z (= **OpenGL**, matching Roblox) |
| Selected-to-active (high→low) bake | `use_selected_to_active=True, cage_extrusion=…` | Fragile | Needs tuned extrusion/ray distance. Verify visually |
| Decimate | Modifier `decimate_type` COLLAPSE (ratio) / UNSUBDIV / DISSOLVE (planar, angle limit) | Reliable to run; output quality varies | Planar dissolve suits hard surfaces. Collapse destroys UVs/topology on textured assets (Rule of thumb) |
| Voxel Remesh / QuadriFlow | `REMESH` modifier / `bpy.ops.object.quadriflow_remesh` | Moderate/fragile | Kills UVs; QuadriFlow is slow and may fail on non-manifold input |
| Geometry Nodes procedural assets | Build node groups via `bpy.data.node_groups.new(type='GeometryNodeTree')` | Moderate | Verbose but deterministic; best for rock/tree/fence generators with seeds. Realize instances before export |
| Export | `bpy.ops.export_scene.gltf / fbx` | Reliable once parameters are explicit | Measured defaults in §1.5 |
| Upload | Official Roblox Blender plugin (Open Cloud, packages, Blender ≥ 3.2; a reference implementation, bug-fixes only) | Moderate | [GitHub](https://github.com/Roblox/roblox-blender-plugin). Found installed as `roblox-blender-plugin-main` in this environment |

### 4.2 Recommended pipeline (Proposed, assembled from the sources above)

1. **Scene setup:** Unit System None (Roblox docs). Model at **1 Blender unit = 1 stud**. Reference: R15 character about 5 studs tall (Unverified: verify against the exported Roblox reference rig: export a Roblox part or rig and import it into Blender as a scale reference).
2. **Blockout** in big → medium → small. Run the silhouette test (§2.1).
3. **Proportion pass:** taper, push or exaggerate (Simple Deform Taper, scaling loops).
4. **Edge treatment:** Bevel modifier (Angle limit 30°, fixed absolute width, 1 segment for small props, 2–3 for hero curves, `harden_normals=True`), then Weighted Normal (keep_sharp, face_influence). Or flat shading for the faceted style.
5. **Cleanup:** merge by distance, delete loose, dissolve degenerate, recalc normals outward, Limited Dissolve on flat areas, triangulate check for n-gons.
6. **UVs:** smart_project → pack_islands (margin about 2–4 px at the target resolution) or snap to palette or trim. Keep everything in 0–1 with a single UV map.
7. **Color:** vertex colors, palette atlas, trim + SA, or a unique bake (§2.6). One material per exported object.
8. **Origin/pivot:** bottom-center for floor props, back for wall props, grid corner for modular pieces (Roblox docs). Apply rotation and scale (`transform_apply(location=False, rotation=True, scale=True)`).
9. **Name** objects meaningfully (PascalCase: `Crate_Wood_A`, `Wall_5x15_A`). Use `_Att`, `_OuterCage` and `_InnerCage` only intentionally.
10. **QA script** (§5) must pass.
11. **Export GLB** (`export_apply=True, use_selection=True, export_yup=True`), or FBX with `FBX_SCALE_UNITS`, `add_leaf_bones=False`, `bake_anim=False`, `path_mode='COPY'`, `embed_textures=True`.
12. **In Studio:** CollisionFidelity Box or Hull by default; CanCollide/CanTouch/CanQuery off for decoration; CastShadow off on tiny props; DoubleSided only for foliage cards (Roblox docs).

### 4.3 Batch export snippet (Measured parameters, Blender 5.2)

```python
import bpy, os
def export_each(objs, out_dir, fmt="GLB"):
    for ob in objs:
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True); bpy.context.view_layer.objects.active = ob
        path = os.path.join(out_dir, f"{ob.name}.{'glb' if fmt=='GLB' else 'fbx'}")
        if fmt == "GLB":
            bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                export_apply=True, export_yup=True, export_normals=True,
                export_vertex_color='ACTIVE', export_draco_mesh_compression_enable=False)
        else:
            bpy.ops.export_scene.fbx(filepath=path, use_selection=True,
                apply_scale_options='FBX_SCALE_UNITS', axis_forward='Z', axis_up='Y',
                add_leaf_bones=False, bake_anim=False, path_mode='COPY', embed_textures=True,
                use_mesh_modifiers=True)
```

Note: with `export_vertex_color='ACTIVE'`, the attribute is exported even when the material does not use it. The default `'MATERIAL'` drops it with a warning (Measured).

---

## 5. Objective quality rubric and automated checks

### 5.1 Automated gate (hard reject on any FAIL)

This QA function was tested in Blender 5.2 against a deliberately broken mesh (open hole, one flipped face, loose vertex, unapplied scale), which it flagged correctly, and against a clean cube, which passed. Measured.

```python
import bpy, bmesh, math
def qa_mesh(ob, tri_budget, tex_px=1024):
    r = {'name': ob.name}
    r['scale_applied'] = all(abs(s-1) < 1e-6 for s in ob.scale)
    r['rotation_applied'] = all(abs(a) < 1e-6 for a in ob.rotation_euler)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    bm = bmesh.new(); bm.from_mesh(me)
    r['tris'] = sum(len(f.verts)-2 for f in bm.faces)
    r['ngons'] = sum(1 for f in bm.faces if len(f.verts) > 4)
    r['non_manifold_edges'] = sum(1 for e in bm.edges if not e.is_manifold and not e.is_wire)
    r['boundary_edges'] = sum(1 for e in bm.edges if e.is_boundary)          # holes -> not watertight
    r['inconsistent_normal_edges'] = sum(1 for e in bm.edges if e.is_manifold and not e.is_contiguous)  # flipped faces
    r['loose_verts'] = sum(1 for v in bm.verts if not v.link_edges)
    r['loose_edges'] = sum(1 for e in bm.edges if e.is_wire)
    r['degenerate_faces'] = sum(1 for f in bm.faces if f.calc_area() < 1e-8)
    r['signed_volume'] = bm.calc_volume(signed=True)   # <0 on closed mesh => normals inward
    uv = bm.loops.layers.uv.active
    r['uv_layers'] = len(me.uv_layers)
    if uv:
        us = [l[uv].uv for f in bm.faces for l in f.loops]
        r['uv_out_of_0_1'] = sum(1 for u in us if not (-1e-5 <= u.x <= 1+1e-5 and -1e-5 <= u.y <= 1+1e-5))
        a3 = sum(f.calc_area() for f in bm.faces)
        def uva(f):
            p = [l[uv].uv for l in f.loops]
            return abs(sum(p[i].x*p[(i+1)%len(p)].y - p[(i+1)%len(p)].x*p[i].y for i in range(len(p))))/2
        auv = sum(uva(f) for f in bm.faces)
        r['uv_coverage'] = auv                                   # fraction of 0-1 square used
        r['texel_px_per_stud'] = math.sqrt(auv/a3)*tex_px if a3 else None
    r['materials'] = len([m for m in ob.data.materials if m])
    r['within_budget'] = r['tris'] <= tri_budget
    bm.free(); ob.evaluated_get(dg).to_mesh_clear()
    return r
```

Plus `bpy.ops.uv.select_overlap()` in edit mode for UV overlaps (Measured: works). Roblox *allows* overlaps (Roblox docs), so overlaps fail **only for unique-bake assets**, which need non-overlapping UVs for AO and normal bakes.

| # | Check | Pass criterion | Basis |
|---|---|---|---|
| A1 | Triangles | ≤ 20,000 per mesh (hard); ≤ class budget (§2.7) | Roblox docs; Proposed |
| A2 | Watertight | boundary_edges = 0, non_manifold_edges = 0 (exempt: intentional foliage cards with DoubleSided) | Roblox docs |
| A3 | Normals | inconsistent_normal_edges = 0; signed_volume > 0 on closed meshes | Roblox docs (no backfaces); Rule of thumb |
| A4 | N-gons | 0 after modifiers (or triangulate on export) | Roblox docs ("avoid N-gons") |
| A5 | Loose / degenerate | loose_verts = loose_edges = degenerate_faces = 0 | Rule of thumb |
| A6 | Transforms | rotation and scale applied (1,1,1 / 0,0,0) | Roblox docs (rig rule); Rule of thumb for static meshes |
| A7 | Scale sanity | bounding-box dimensions within the expected stud range for the class (e.g. a door about 7–8 studs tall: Unverified convention), ≤ 2048 per axis | Rule of thumb |
| A8 | UV | exactly 1 UV map if textured; 0 out-of-range; no overlaps when unique-baked | Roblox docs |
| A9 | Texel density | within ±25% of the project target (default **51.2 px/stud**, derived from Roblox's size table) | Derived; ±25% Proposed |
| A10 | Materials | ≤ 1 per exported object | Roblox docs |
| A11 | Texture sizes | power-of-two ≤ 1024 by default (≤ 4096 hard); non-albedo ≤ 256 on accessories; normal maps OpenGL | Roblox docs |
| A12 | Pivot | origin at the documented placement point (bottom-center, back, or grid corner) | Roblox docs |
| A13 | Export settings | GLB `export_apply=True`, or FBX `FBX_SCALE_UNITS`, no leaf bones, no baked anim | Roblox docs; Measured |
| A14 | Naming | unique, descriptive, no `.001` suffixes; no accidental `_Att`/`_Cage` suffixes | Roblox docs (suffix conversion) |

### 5.2 Visual/craft rubric (score 0–2 each; accept ≥ 14/18 with no zeros)

Render a thumbnail turntable (front, 3/4, top, silhouette pass) and score:

| # | Criterion | 0 | 1 | 2 | Basis |
|---|---|---|---|---|---|
| V1 | Silhouette reads at 32–64 px as solid black | Unrecognizable | Readable from 1 angle | Readable from all angles | Rule of thumb |
| V2 | Shape hierarchy (big/medium/small) | Uniform noise | Some hierarchy | Clear B/M/S | Rule of thumb |
| V3 | Proportion/chunkiness fits style | Stiff primitives | Partially exaggerated | Confident, stylized proportions | Rule of thumb |
| V4 | Edge treatment | Razor edges or blobby smoothing | Inconsistent bevels | Consistent S/M/L bevels catch light | Rule of thumb |
| V5 | Shading | Shading artifacts/gradients on flat faces | Minor artifacts | Clean (weighted normals or intentional flat) | Rule of thumb |
| V6 | Palette | Random or noisy colors | OK, too many hues | 2–3 dominant colors with value contrast | Rule of thumb |
| V7 | Geometry economy | Detail on invisible faces, wireframe looks like solid | Some waste | Geometry only where silhouette or shading needs it | Roblox docs; Rule of thumb |
| V8 | Style consistency with kit | Clashes (texel, bevel or palette) | Minor mismatch | Indistinguishable from kit | Rule of thumb |
| V9 | Studio readiness | Wrong scale, pivot or collision | One issue | Correct scale, pivot, collision fidelity and flags | Roblox docs |

---

## 6. Common AI and beginner mistakes, and how to detect them

| Mistake | Symptom in Roblox | Detection (bpy) | Fix | Label |
|---|---|---|---|---|
| Default FBX scale | Imports 100× big (or tiny with ad-hoc 0.01 hacks) | Inspect export params; Measured `Lcl Scaling=100` with FBX_SCALE_NONE | GLB, or `FBX_SCALE_UNITS` | Roblox docs; Measured |
| glTF without `export_apply` | Bevels, weighted normals and mirror missing in Studio | Compare evaluated vs base tri count | `export_apply=True` | Measured |
| Vertex colors dropped | Grey mesh | Exporter warning in log; check COLOR_0 in GLB JSON | Use the color in the material, or `export_vertex_color='ACTIVE'`; set MeshPart.Color white | Measured; Roblox staff |
| MeshPart.Color left grey | Colors look dark or dirty | n/a (Studio) | Color = 255,255,255 | Roblox staff |
| Flipped or inconsistent normals | Invisible faces | `inconsistent_normal_edges`, negative signed volume | `recalc_face_normals` | Rule of thumb |
| Holes / non-manifold / zero thickness | Rejected or see-through | `boundary_edges`, `non_manifold_edges` | Fill, Solidify | Roblox docs |
| N-gons | Bad triangulation and shading | `ngons` > 0 | Triangulate or retopo | Roblox docs |
| Smooth shading on hard surfaces without support | Blobby dark gradients; AO creases > 30° look faceted | Visual; check for sharp edges or weighted-normal modifier | Bevel + Weighted Normal, or Smooth by Angle 30° | Rule of thumb; Roblox staff (30°) |
| Unapplied scale/rotation | Bevel widths and modifiers wrong, pivot odd | `scale_applied` false | `transform_apply` | Rule of thumb |
| Over-dense AI/scan meshes (triangle soup) | Over budget, ugly LoDs | tris ≫ budget; uniform tri density | Decimate/retopo, rebake | Rule of thumb |
| Detail that doesn't change the silhouette | Wasted tris | V7 wireframe check | Remove, bake to normal, or texture it | Roblox docs; Rule of thumb |
| Over-beveling (3–4 segments everywhere) | 9–25× tris on boxes | Bevel modifier segments > 2 on small props | 1 segment + weighted normals | Measured cost |
| Multiple materials on one object | Split into several MeshParts, extra draw calls | `materials` > 1 | Atlas or separate deliberately | Roblox docs |
| Huge unique textures | Memory, crashes on mobile | Image size check | ≤ 512 typical, ≤ 1024 hero; trims/atlases; SA.Color tints | Roblox docs |
| DirectX normal maps | Inverted bumps | Green-channel convention check (bake swizzle +Y) | Bake OpenGL (Blender default) | Roblox docs; Measured default |
| Channel-packed ORM texture | Wrong roughness/metal | File inspection | Separate grayscale maps | Roblox docs |
| Importing whole map as one file | Duplicate mesh assets, memory | n/a | Export unique pieces once and reuse in Studio | Roblox docs |
| Precise collision or RenderFidelity everywhere | Physics/memory/frame cost | Studio audit | Box/Hull; drop RenderFidelity (being removed) | Roblox docs |
| DoubleSided on closed meshes | 2× render cost | Studio audit | Off except foliage | Roblox docs |
| Origin at random point | Placement and rotation awkward | Origin vs bbox check | Set origin to bottom-center or snap corner | Roblox docs |
| Baking AO with other objects nearby | Black or wrong AO | Bake result mean near 0 | Isolate the object (hide_render others) | Measured |
| Using `mesh.use_auto_smooth` (pre-4.1 scripts) | AttributeError | Version check | `shade_auto_smooth()` / Smooth by Angle | Measured; Blender issue |

---

## 7. Open questions and conflicts to resolve with a one-time Studio test

1. Texture cap in practice: 4K documented (2026-01) vs "1024 UV pixel space" on the same page. Upload a 2048 map and inspect.
2. Whether Roblox preserves custom split normals (weighted normals) from GLB/FBX, or re-splits them (2017 suspicion).
3. Whether the importer honors glTF `doubleSided: true`. Blender exports it when material backface culling is off (Measured: the GLB material had `doubleSided: true`). The importer's own "Make Double Sided" setting defaults off.
4. Whether Draco-compressed GLB imports.
5. FBX axis: Roblox docs say Forward Z / Up Y, while Blender's default is −Z / Y. Confirm visually.
6. General vertex limit (undocumented).
7. MeshPart minimum size (forum reports 0.05 historically).

---

## 8. Sources

**Roblox docs and official posts**
- https://create.roblox.com/docs/art/modeling/specifications
- https://create.roblox.com/docs/art/modeling/export-requirements
- https://create.roblox.com/docs/art/blender
- https://create.roblox.com/docs/art/modeling/3d-importer
- https://create.roblox.com/docs/art/modeling/texture-specifications (raw: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/art/modeling/texture-specifications.md)
- https://create.roblox.com/docs/art/modeling/surface-appearance
- https://create.roblox.com/docs/parts/meshes
- https://create.roblox.com/docs/parts/materials
- https://create.roblox.com/docs/reference/engine/enums/RenderFidelity
- https://create.roblox.com/docs/performance-optimization/improve
- https://create.roblox.com/docs/physics/units
- https://create.roblox.com/docs/art/accessories/specifications
- https://create.roblox.com/docs/avatar/character-bodies/specifications
- https://create.roblox.com/docs/avatar/layered-accessories/specifications
- https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture
- https://create.roblox.com/docs/tutorials/curriculums/environmental-art/develop-polished-assets
- https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library
- https://create.roblox.com/docs/art/accessories/creating/texture-painting
- https://devforum.roblox.com/t/4k-texture-rendering/4316229 (Roblox, 2026-01-30)
- https://devforum.roblox.com/t/introducing-mesh-streaming-and-improved-cloud-lods-in-published-experiences-opt-in-phase/4601232 (Roblox, 2026-04-27)
- https://devforum.roblox.com/t/3050119 (Roblox staff SCHLEEMPH, vertex colors, 2024-07-02)
- https://devforum.roblox.com/t/substance-painter-overview-setup-and-general-pbr-creation/2884177 (Roblox staff blutzer, 2024-03-21)
- https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos
- https://github.com/Roblox/roblox-blender-plugin

**Blender**
- https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/bevel.html
- https://docs.blender.org/manual/en/latest/modeling/modifiers/normals/weighted_normal.html
- https://docs.blender.org/manual/en/4.2/modeling/modifiers/normals/smooth_by_angle.html
- https://docs.blender.org/manual/en/3.6/addons/import_export/scene_gltf2.html
- Bundled Blender 5.2 manual: modeling/meshes/uv/editing.rst (Pack Islands), modeling/modifiers/generate/decimate.rst, sculpt_paint/vertex_paint/editing.rst (Dirty Vertex Colors)
- https://projects.blender.org/blender/blender/issues/119633 ; https://www.github.com/lasa01/Plumber/issues/184
- Measured: live Blender 5.2.0 LTS session (operator RNA defaults, export/parse experiments, QA and bake tests); temporary scene and files removed afterwards.
