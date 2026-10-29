---
tags: [ai-pitfalls, assets, import, fbx, gltf, glb, blender, scale, textures, meshes, vertex-colors, creator-store]
verified: 2026-10-28
---
# AI Pitfalls - Assets and Import

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Fixing scale, pivots or colours in Studio instead of at the source file.
> - Avoid: Exporting GLB with Apply Modifiers off, so Mirror and Bevel vanish (turning it on keeps Armature skinning but drops shape keys).
> - Avoid: Re-exporting the same model with different settings per teammate.
> - Size checked against an R15 avatar after import.
> - GLB exported with Apply Modifiers on (Armature is kept), or modifiers applied by hand on meshes with shape keys.
> - Vertex colours ACTIVE, `MeshPart.Color` white.
>
> Cost: TL;DR ~170 tok · whole note ~2.0k tok. Read more: ## 1. Models 100x too big or too small (FBX) · ## 7. Mesh and texture limits from old training data · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Asset mistakes come from unit and default mismatches between tools that a model never sees together: Blender, its exporters, the Roblox 3D Importer and the asset pipeline. Most entries are **Measured** in the LihFolk reference project or recorded in the vault's shipped recipes (`skills/quality-score/recipes/model.md`). Hub: [[What AI Models Get Wrong in Roblox]].

## 1. Models 100x too big or too small (FBX)

- **Wrong:** export FBX with default settings, then fix size in Studio with `Model:ScaleTo` or the scale tool.
- **Why:** each tool's default is reasonable alone; the chain (Blender scene units, FBX unit scale, importer Scale Unit) is not.
- **Right:** fix it at export. Roblox's recommended FBX fix is Transform > "Apply Scalings: FBX Unit Scale" with every other scale value left at 1.0 (vault convention: 1 Blender unit = 1 stud, importer Scale Unit "Studs"). Roblox also documents two alternatives: export Transform Scale 0.01, or scene Unit Scale 0.01 (can cause Blender camera issues; re-imports into other tools may need scaling back up). Pick one method, never stack them. GLB needs none of these settings. **Never** rescale animated rigs in Studio: parts scale, but clip translations stay in the old units, so root motion and offsets break.
- **Detect:** imported bounding box vs an R15 avatar (about 5 studs tall; doors 7-8). See [[Exporting FBX vs GLB]].

## 2. Bevels and modifiers missing (glTF)

- **Wrong:** Blender glTF export with defaults on a model built with Bevel, Mirror, Solidify or [[Weighted Normals|Weighted Normal]] modifiers.
- **Right:** the glTF exporter's Data > Mesh > Apply Modifiers (`export_apply`) defaults to off, so the base mesh is exported without Mirror, Bevel or Solidify. Turn it on. It applies every modifier except Armature, so skinned rigs still export their skinning (Blender API docs). **Catch:** with it on, shape keys (morph targets) are not exported; for meshes that need shape keys, apply the other modifiers manually before export and leave the option off.
- Over-bevelling: **Measured** (recipe): more than 2 bevel segments on small props multiplied triangles 9x or more.

## 3. Grey or wrong-coloured meshes

- **Wrong:** vertex-coloured models that import grey; palette textures that ignore Material changes.
- **Right:** **Measured** (recipe): export vertex colours as the ACTIVE colour attribute and leave `MeshPart.Color` white so it does not tint them. Turn on the importer's Ignore Vertex Colors only when a generator left junk colours.
- **Measured:** kit MeshParts with a palette `TextureID` ignored `Material` changes until the TextureID was cleared, and near-black colours hid material textures (see [[Modular Environment Kits]]).

## 4. Transforms, pivots and axes

- **Wrong:** unapplied rotation or scale in Blender; origin in the middle of a floor prop; Z-up assumptions.
- **Right:** apply transforms before export; origin at the bottom for floor props, back for wall props, a corner for [[Modular Kits|modular pieces]] (recipe defaults). Roblox is Y-up; check forward axis on creatures (see [[Enemy Import Axis Fix]]).

## 5. Decal id used as an image id

- **Wrong:** pasting the number from a Decal's Creator Store URL into `ImageLabel.Image` or `ParticleEmitter.Texture`; the image stays blank.
- **Why:** a Decal asset wraps a separate Image asset with its own id.
- **Right:** use the Image asset id (`rbxassetid://<imageId>`). Inserting the decal in Studio and reading its `Texture`, or the asset's image id in the Creator Dashboard, gives the right number. **Reported:** DevForum reports; the official image upload pages are listed in [[Official Docs - Asset Creation]].

## 6. Assets that "do not load" right after upload

- **Measured:** a freshly uploaded image can fail `ContentProvider:PreloadAsync` for about 20-60 seconds while processing and moderation finish. Retry with backoff in tooling; do not conclude the id is wrong (see [[Studio Plugins and Local HTTP Bridges]]).
- **Measured:** HttpService tooling that posted one request per asset hit the roughly 500 requests per minute per server limit. Batch.

## 7. Mesh and texture limits from old training data

| Model believes | Current |
|---|---|
| Textures max 1024 x 1024 | **4096 x 4096** renders on MeshPart, SurfaceAppearance, Texture, Decal and MaterialVariant since January 30, 2026 (8K uploads transcoded to 4K). **Reported:** the decal upload page still downsizes to 1024; clothing docs say 2048. GUI images not covered |
| Set `RenderFidelity` per mesh for LOD | Ignored when `MeshStreamingAndImprovedLoDs` is on; planned for removal. Budget triangles at the source |
| Unlimited triangles | **20,000 triangles per mesh** at import; unions above 20,000 are simplified (Roblox docs, via [[Parts Unions and MeshParts]]) |
| Any number of skin weights | At most **4 bone influences per vertex** (Roblox docs, modeling specifications) |

## 8. Collision and query cost

- **Wrong:** every decorative MeshPart left at default collision with `CanTouch` and `CanQuery` on; `PreciseConvexDecomposition` on props.
- **Right:** `CollisionFidelity = Box` or `Hull` for props; `CanCollide`, `CanTouch`, `CanQuery` off on pure decoration; collision proxies for complex shapes. See [[Mesh Optimization for Mobile]].

## 9. Free models and generated assets

- **Wrong:** inserting Toolbox models or AI-generated kits without inspection.
- **Right:** scan for scripts, `require(<number>)`, `getfenv`, `loadstring`, long obfuscated strings, and hidden welds or sounds. See [[Creator Store and Toolbox Safety]]. Generated meshes (outside tools or Roblox's Cube generation) often arrive non-manifold, overdense and unwrapped; decimate and check under the triangle limit. See [[AI 3D Model Generation Outside Roblox]].

## 10. Studio-only asset paths

- **Measured:** `KeyframeSequenceProvider:RegisterKeyframeSequence` ids and EditableMesh or EditableImage effects worked in Studio and failed in the published game. Upload real assets and test in a live server.
- **Measured:** Windows paths over 260 characters made Blender and other native tools fail to open files from deep temp folders. Keep pipeline paths short.

## Common mistakes

- Fixing scale, pivots or colours in Studio instead of at the source file.
- Exporting GLB with Apply Modifiers off, so Mirror and Bevel vanish (turning it on keeps Armature skinning but drops shape keys).
- Re-exporting the same model with different settings per teammate. Use one export function (the vault's `lf.export_glb`).
- Importing at 4K "because it is allowed" on mobile-heavy games without checking texture memory.

## Checklist

- [ ] Size checked against an R15 avatar after import.
- [ ] GLB exported with Apply Modifiers on (Armature is kept), or modifiers applied by hand on meshes with shape keys.
- [ ] Vertex colours ACTIVE, `MeshPart.Color` white.
- [ ] Transforms applied, origin set by prop type.
- [ ] Under 20,000 triangles per mesh; at most 4 influences per vertex.
- [ ] Image ids (not decal ids) in UI and particles.
- [ ] Decorative parts: collision Box or Hull, touch and query off.

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Exporting and Validating Models for Roblox]]
- [[Exporting FBX vs GLB]]
- [[Modeling in Blender for Roblox]]
- [[Textures Decals and Texture Memory]]
- [[Level of Detail and Model Streaming]]
- [[Engine and API Changes 2025-2026]]

<!-- related:start -->
## Related
[[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[AI Material and Texture Generation]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[AI Pitfalls - Physics and Animation]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Roblox Studio Assistant]]
<!-- related:end -->
