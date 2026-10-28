---
cssclasses: [vault-hub]
tags: [blender, python, procedural, modeling, rendering, hub]
---
# Procedural Blender Assets Start Here

![[p45_void_owl_posed.png]]

This section records what happened when a set of game assets was built entirely from Python scripts run in background Blender: a boss creature matched against a concept sheet, a chibi pet, two stylised swords, a portal set piece, mesh VFX and a set of trees. Each note says what was tried, what failed, why, and the rule that fixed it. The numbers are from those builds (labelled "measured in these builds", October 2026, Blender 5.2), the rest is rule of thumb.

The short version:

- **Primitives are a blockout, not a model.** Stretched spheres, tubes and bare boxes read as programmer art every time. The fix was always a real modelling technique done in code: box-modelled single masses, extruded and bevelled 2D silhouettes, bevelled cross-sections.
- **Markings belong in textures, not geometry.** Glow marks built as separate little meshes come out at different sizes and angles; a painted mask on proper UVs makes every mark identical.
- **Compare against the reference every render.** Side by side, at the same angle, plus a black silhouette test.
- **Fix one thing per iteration and keep what works.** An undo request ("put the horns back") is cheap when every change is a small, named edit to a build script.

## Notes in this section

| Note | What it covers |
|---|---|
| [[Matching a Concept Sheet - Boss Creature Case Study]] | Four failed passes and the vault workflow that finally matched a faceted boss owl; rigging it on the bird skeleton |
| [[Chibi Character Rules in Practice]] | What made a chibi chicken go from "fine" to appealing: eye height, iris, pear body, gradients, staging |
| [[Stylised Weapons From a Concept]] | A glowing falchion: why tubes looked cheap, bevel band as the glow edge, forged silhouettes, flames as filled strokes |
| [[Dramatic Showcase Renders in Eevee]] | Cosmic sword and portal scenes: volumetric gas, star fields, flares, bloom, view transforms, a swirl shader gotcha |
| [[Mesh VFX Packs Built in Blender]] | Slash crescents, shock rings, flame shells and bolt ribbons as meshes with painted alpha textures |
| [[Low-Poly Tree Set Worked Example]] | Oak, pine and birch at 126-578 triangles following the vault tree recipe, and the icosphere subdivision trap |
| [[Low-Poly Creature From a Flat Reference Sheet]] | A quadruped from a three-view sheet: lofted sections, voxel fuse, carved facets, palette atlas colour, reach-normalised skinning, rotations-only walk |
| [[Stylised Shop Stand Worked Example]] | A market stand in about 110 bevelled parts: varied planks, small tilts, a scalloped striped awning, font-curve sign, the slope sign and brace length fixes |
| [[Dash VFX Presentation on an R15 Rig]] | A dash ability clip on the R15_Blocky rig: additive glow, afterimages, UV-gradient ribbons, burst, camera shake, bloom, MP4 output |
| [[Blender 5 Python Gotchas for Headless Builds]] | API changes and traps hit during these builds (compositor, glare, icosphere levels, bmesh faces, edits) |

## Build scripts

The `scripts` folder holds the build scripts behind these notes (boss owl and its pose, chibi chicken, cosmic sword scene, celestial gate scene, tree set, mesh VFX pack, quadruped wolf, shop stand, dash presentation; the dash script loads the rig from `18 Rigs and Skeletons/R15_Blocky`). Run any of them with `blender -b --factory-startup --python <script>.py`; renders and exports land in a `scripts/out` folder. Treat the code as reviewed working examples: it ran in Blender 5.2 for these builds, but read it before running.

## Related notes elsewhere

- Modelling foundations: [[Low-Poly and Stylized Modeling]], [[Organic and Creature Modeling]], [[Modeling Weapons and Props]], [[Posing and Silhouettes]], [[Topology and Edge Flow]].
- Pipeline: [[Art Pipeline - Concept to In-Game Asset]] (build from a script, not by hand), [[Concept Sheets]], [[AI 3D Model Generation Outside Roblox]].
- Rigging: [[Skeleton Library]] (the Bird_Winged rig used here), [[Creature Rig Conventions]], [[Weight Painting and Skinning for Roblox]], [[Bones and Skinned Meshes]].
- Getting it into Roblox: [[Exporting and Validating Models for Roblox]], [[Retopology and Decimation]], [[Art Budgets - Triangles Draw Calls Memory]].
- Effects and lighting: [[VFX Design Playbook]], [[Beams and Trails]], [[Particle Emitters In Depth]], [[Stylized Lighting Recipes]].

## Connected notes
<!-- auto-links:start -->
[[Untextured Stylised Modelling Start Here]] · [[Skinning Weights]] · [[Blender Automation with Python]] · [[Modelling Nuance Start Here]] · [[Character and Creature Pipeline]] · [[Modeling Characters for R15 and Custom Rigs]]
<!-- auto-links:end -->
