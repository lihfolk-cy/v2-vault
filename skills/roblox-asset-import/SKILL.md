---
name: roblox-asset-import
description: 'LihFolk: import FBX/GLB/OBJ, rigs, kits and PBR textures into Studio at correct scale, budget, pivot and collision. Use for "import this model", wrong size, bad pivot, invisible walls, too many tris.'
---
# LihFolk Asset Import

Most import problems are decided before the file reaches Studio: units, applied transforms, origins and triangle counts. Fix them at export, not by scaling in Studio. Then import with the right settings, reset pivots, set collision on purpose, and audit.

## Inputs

- `VAULT`: LihFolk Vault V2, the knowledge base at `../../knowledge/` relative to this file (plugin root `knowledge/`). Start with `VAULT/INDEX.md` to find notes fast.
- The source file(s) and what they are for (prop, kit piece, character, weapon, terrain material).
- The target device class (assume mid-range phones unless told otherwise).

## Procedure

1. **Check the hard limits** (Roblox docs, as of October 2026):
   - 20,000 triangles per mesh. Split or decimate anything larger.
   - Avatar accessories: 4,000 triangles, one mesh.
   - One UV set (0 to 1), one material per mesh.
   - Formats: `.fbx`, `.obj`, `.gltf` or `.glb`. Textures: `.png`, `.jpg`, `.tga`, `.bmp`.
   - Rigged meshes: bones frozen, scale 1, rotation 0, root at origin.
   - Geometry closed where possible; open meshes import but cause collision and shadow artefacts.

2. **Fix scale at the source.** The vault convention is 1 Blender unit = 1 stud, with the importer's Scale Unit set to Studs. A stud is about 0.28 m in Roblox's real-world conversion, but do not convert: think in studs.
   - GLB/glTF is metres by spec and comes in 1 unit = 1 stud with Scale Unit Studs.
   - FBX is centimetre-based: export with Apply Scalings = FBX Unit Scale and every other scale at 1.0. Do not mix this with the Scale 0.01 workarounds.
   - Apply transforms in Blender. Scaling in Studio to fix units leaves texture density, pivots and offsets wrong.
   - Normals outward, no internal faces, origins set on purpose (bottom centre for props that sit on the ground).

3. **Hold the budgets** (rules of thumb for mid-range phones, from the vault):
   | Asset | Triangles | Textures |
   |---|---|---|
   | Small repeated prop | 100 to 800 | shared trim or palette |
   | Medium prop | 800 to 3,000 | shared atlas |
   | Hero piece | 5,000 to 10,000 | one set, at most 1024 |
   | Tree | 1,000 to 5,000 | shared bark and leaf |
   | Held weapon | 1,000 to 5,000 | 256 to 512 |
   | Enemy (several on screen) | 3,000 to 10,000 | 512 |
   | Boss | 10,000 to 30,000 total, each mesh under 20,000 | 1024 |
   Draw calls matter more than triangles: reuse meshes and textures. Outline hulls double triangles; avoid them in game meshes.

4. **Import with the right settings** (File, Import 3D):
   - Set the Name (GLBs otherwise arrive as a Model named `Scene`).
   - Upload to Roblox off while iterating, on for the final import.
   - Creator: the user or group that owns the experience, or assets may not load in a group game.
   - Use Imported Pivot on; Set Pivot to Scene Origin on for kits modelled around the origin; Merge Meshes off for kits.
   - Scale Unit: Studs. For R6 or R15 characters, set the matching rig type.
   - Read the importer's warnings panel every time.

5. **Reset pivots.** Upload add-ons can leave a rotated `PivotOffset` (measured); reset each uploaded part with `part.PivotOffset = CFrame.new()`. Give each model a bottom-centre pivot. If the model has a `PrimaryPart`, set `PrimaryPart.PivotOffset`, because `WorldPivot` writes are ignored. `PivotTo` with a mirrored CFrame does not mirror a model; mirror in Blender.

6. **Set collision deliberately.**
   - Decoration: `CanCollide`, `CanTouch` and `CanQuery` off.
   - Where collision is needed: Box for small things, Hull for convex shapes, PreciseConvexDecomposition only where walkable detail matters.
   - Better: keep visual meshes non-colliding and add simple invisible Part colliders for floors and walls, moved with the art as one model.
   - `CollisionFidelity` cannot be changed by a script on a loaded part; set it in Studio or use `CreateMeshPartAsync`.
   - Audit transparent parts that still collide (invisible walls).
   - `RenderFidelity` Automatic; small props do not cast shadows.

7. **Textures and materials.**
   - Size textures to on-screen use: about 256 for a 5 x 5 stud object, 512 for 10 x 10, 1024 for 20 x 20 (Roblox docs). Most props at 512 or below. A 1024 texture costs four times a 512.
   - PBR sets map onto `SurfaceAppearance`: ColorMap, NormalMap (OpenGL style), RoughnessMap, MetalnessMap. Metalness is 0 or 1 for plausible results. AO, ARM and displacement maps are not used directly; bake AO into the colour map in Blender.
   - For parts and terrain, use a `MaterialVariant` in `MaterialService` with a stable naming convention.
   - Clone `SurfaceAppearance`s and meshes from one source; re-imported copies break instancing.

8. **Use the LihFolk libraries.**
   - Section 18 has nine skeleton rigs (R6, R15, quadruped, bird, spider, serpent, sword, bow, flail) built at 1 unit = 1 stud. Characters face -Y in Blender, which is forward in Roblox. Keep bone names: the R15 rig must keep exact R15 names for the importer's Humanoid setup. Weapons use `Handle` as root and grip. These rigs were exported and checked by name and size but not yet test-imported into Studio, so test one first.
   - The LihFolk Asset Pack (optional download, see `../../assets/README.md`) holds original LihFolk models, kits, materials and skies. Check it before importing from elsewhere.
   - Outside texture sets and HDRIs (for example CC0 libraries the user downloads): downscale 2K sets to 1024 before upload. An HDRI becomes a sky by converting it to six 1024 px cube faces for the `Sky` object.
   - Outside environment kits: prefer the GLB version when a kit ships several formats, import with Merge Meshes off, and keep the kit's licence file and source URL next to the source files.

9. **Audit after import.** Run a Studio audit: triangle and unique mesh counts, texture sizes, collision flags, transparent colliders, pivots. Do a ray-grid before and after test on every art pass and walk every gate and doorway.

## Hard rules

- Never scale in Studio to fix a unit error; re-export.
- Never leave decoration colliding by default.
- Never upload test iterations; keep Upload off until final.
- Never re-import copies of the same mesh; clone in Studio.
- Keep credit and licence files for third-party assets; CC0 does not require credit, but record the source.

## Checks before finishing

- [ ] Transforms applied; 1 unit = 1 stud; origin placed; normals outward.
- [ ] Triangles within limit and budget; one UV map, one material.
- [ ] Importer: name, Upload, Creator, pivots, Merge Meshes, Scale Unit.
- [ ] `PivotOffset` reset; bottom-centre model pivots.
- [ ] Collision off for decoration; fidelity chosen; doorways walked.
- [ ] Textures sized; SurfaceAppearances shared; normal maps OpenGL.
- [ ] Audit run and numbers recorded.

## Read these vault notes

- `14 3D Modeling/Exporting and Validating Models for Roblox.md`
- `14 3D Modeling/Blender Workflow for Roblox Creators.md`
- `14 3D Modeling/Mesh Optimization for Mobile.md`
- `14 3D Modeling/Modular Environment Kits.md`
- `14 3D Modeling/Texturing and PBR Baking.md`
- `14 3D Modeling/Modeling Characters for R15 and Custom Rigs.md`
- `06 World Building and Art/Art Budgets - Triangles Draw Calls Memory.md`
- `06 World Building and Art/Collision and Physics Geometry.md`
- `06 World Building and Art/Materials MaterialVariants and SurfaceAppearance.md`
- `06 World Building and Art/Textures Decals and Texture Memory.md`
- `06 World Building and Art/Parts Unions and MeshParts.md`
- `17 Pipelines/Art Pipeline - Concept to In-Game Asset.md`
- `18 Rigs and Skeletons/Skeleton Library.md`
- The LihFolk Asset Pack (original models, materials, skies, animations, VFX) when installed: see `../../assets/README.md`

Disputed: texture size limits (1024 for UV texture maps versus up to 4096 on another docs page) and Blender unit setup (docs say Unit System None; many guides use Metric with 1 m = 1 stud). See `Open Questions - Whole Vault.md`.
