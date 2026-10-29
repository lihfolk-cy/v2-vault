---
tags: [ai, agents, ai-skill, modeling, blender, world-building, type/guide, area/modeling, level/intermediate, area/ai]
---
# Skill - Roblox Asset Import

**Skill file:** [skills/roblox-asset-import/SKILL.md](../skills/roblox-asset-import/SKILL.md) (folder name `roblox-asset-import`)

## What it does

This skill makes an agent import models, rigs, kits and textures correctly the first time. Most import problems are decided at export, so the procedure starts in Blender and ends with an audit in Studio:

1. **Hard limits** (Roblox docs): 20,000 triangles per mesh, 4,000 for avatar accessories, one UV set, one material per mesh, frozen rig transforms.
2. **Scale at the source**: 1 Blender unit = 1 stud with the importer's Scale Unit set to Studs. GLB needs no extra scaling; FBX uses Apply Scalings = FBX Unit Scale. Never fix units by scaling in Studio.
3. **Budgets** per asset class for mid-range phones, from 100 to 800 triangles for a small repeated prop up to 10,000 to 30,000 for a boss split across meshes (rules of thumb), with draw calls treated as more important than triangles.
4. **Importer settings**: name, Upload off while iterating, the right Creator, imported pivots, Merge Meshes off for kits.
5. **Pivots**: reset `PivotOffset` on uploaded parts, bottom-centre model pivots, `PrimaryPart.PivotOffset` when a PrimaryPart exists.
6. **Collision**: decoration non-colliding, Box or Hull where collision is needed, PreciseConvexDecomposition only for walkable detail, invisible primitive colliders for floors.
7. **Textures**: sized to on-screen use (256, 512 or 1024 for 5, 10 or 20 stud objects), PBR maps on `SurfaceAppearance` with OpenGL normal maps, `MaterialVariant` for parts and terrain, shared and cloned rather than re-imported.
8. **Vault libraries**: the nine rigs in [[Skeleton Library]], free CC0 sources in [[Links - Free and CC0 asset libraries]], and the separate LihFolk Asset Pack (original models, materials and skies; see the `lihfolk-assets` skill).
9. **Audit**: triangle, mesh, texture, collision and pivot checks, plus a ray-grid test and walking every doorway.

## When to use it

Bringing any FBX, GLB or OBJ into Studio; using the vault's rigs, kits or textures; or fixing wrong sizes, offset pivots, invisible walls or heavy meshes.

## Caveats it repeats

The skeleton rigs were exported and checked by name and size but not yet test-imported into Studio. Texture size limits differ between docs pages (1024 for UV texture maps versus 4096), and Blender unit setup differs between the docs and common guides. Both are in [[Open Questions - Whole Vault]].

## Notes behind it

[[Exporting and Validating Models for Roblox]], [[Blender Workflow for Roblox Creators]], [[Mesh Optimization for Mobile]], [[Modular Environment Kits]], [[Texturing and PBR Baking]], [[Modeling Characters for R15 and Custom Rigs]], [[Art Budgets - Triangles Draw Calls Memory]], [[Collision and Physics Geometry]], [[Materials MaterialVariants and SurfaceAppearance]], [[Textures Decals and Texture Memory]], [[Parts Unions and MeshParts]], [[Art Pipeline - Concept to In-Game Asset]].

## Related

- [[AI Skills Start Here]]
- [[Blender MCP]] and [[MCP Workflows for Building Worlds]] for driving Blender and Studio from an agent
- [[Skill - Roblox Performance Audit]]

## Connected notes
<!-- auto-links:start -->
[[Materials and Surfaces Start Here]] · Links - Importing into Studio · SurfaceAppearance PBR Workflow · Modeling in Blender for Roblox · Triangle Budget · Exporting FBX vs GLB
<!-- auto-links:end -->
