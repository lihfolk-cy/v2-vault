---
cssclasses: [vault-hub]
tags: [modeling, hub, readability, silhouette, proportion, style-bible, critique, start-here]
---
# Modelling Nuance Start Here

This section is about the judgement calls that separate a model that is technically fine from one that reads well in a Roblox game. The basics live elsewhere: how to model, unwrap, export and budget. Here the question is narrower and harder: will this model be recognisable, attractive and consistent with everything around it when a player sees it through the default camera, on a phone, from 40 studs away, beside an avatar they chose? Most of the notes lean toward non-hand-painted art (flat colour, vertex colour, geometry and lighting doing the work), because those styles have no painted texture to hide weak shapes, but every rule applies to textured art too.

## Read these first

These existing notes hold the foundations this section builds on. Skim them before the notes below, or you will meet ideas here without their basics.

1. [[Modeling Fundamentals for Games]]: silhouette first, the basic black silhouette test, why "it looks fine in Blender" is not a test.
2. [[Low-Poly and Stylized Modeling]]: the basic shape language, proportion rules and segment counts for stylised art.
3. [[Environment Art Styles]]: how a style is written down, palettes, and where detail goes in a world.
4. [[Hard-Surface Modeling]]: the bevel and weighted normal workflow, bevel widths by object size.
5. [[Art Budgets - Triangles Draw Calls Memory]]: the totals that every model has to fit.
6. [[Camera Systems]] and [[Avatar Body Types and Scale in Gameplay]]: the camera and avatars your models are judged against.

## The notes in this section

Read roughly in this order. The camera note comes second because its pixel formula is used by almost every other note.

1. [[Shape Language and Silhouette Testing]]: shape hierarchy (primary, secondary, tertiary with area ratios), dominant and accent shape families, negative space and tangents, the four-view silhouette test needed for Roblox's high follow camera, roster tests for gameplay roles, a Blender silhouette sheet and a Studio silhouette toggle.
2. [[Modelling to the Roblox Camera and Player Scale]]: the fixed numbers (0.28-metre stud, 70-degree vertical field of view, near clip, jump height), the studs-to-pixels formula and table, how screen aspect changes the horizontal view, world sizes in avatar units, a matched Blender camera, and a Studio script that measures on-screen pixel size.
3. [[Proportion Exaggeration and Gameplay Distance]]: distance bands, the smallest readable feature per distance, exaggeration multipliers for characters and props, and where exaggeration breaks collision, navigation, the camera and weapon reach.
4. [[Bevels Chamfers and Edge Highlights Without Textures]]: why bevels catch light, bevel widths sized for viewing distance, chamfer versus round, the hidden vertex cost of hard edges, how Roblox lighting and colour sources affect edges, and four non-texture alternatives including vertex colour edge brightening.
5. [[Spending Triangles Where the Camera Looks]]: the sagitta rule for segment counts by radius and distance, which faces the Roblox camera actually sees, where to delete and where to add, zone-level spend shares, and a Blender script that reports triangle spend by direction.
6. [[Style Bibles for Consistent Models]]: the twelve parts of a modelling style bible, how to write rules people follow, golden assets, and a Studio palette and material audit script.
7. [[Critiquing a Model - Paintovers and Iteration]]: a fixed critique order, in-context review, four kinds of paintover, a Studio greyscale value check, feedback that gets used, and how many review rounds to plan.

## How the notes connect

The camera note gives the numbers. The silhouette and proportion notes use them to decide shape and size. The bevel and triangle notes use them to decide edges and density. The style bible turns all of those decisions into written rules, and the critique note checks new models against the rules. A team that adopts the whole loop gets models that read on phones and a library that stays consistent as it grows.

## Quick rules from this section

- One pixel on a 720-pixel phone at distance `d` studs is about `d / 520` studs. Features smaller than about `d / 260` vanish.
- Test silhouettes from four views, including high three-quarter and top-down, at game pixel size.
- Exaggerate in pairs: one feature up, its neighbour down.
- Size bevels by the larger of the object-size rule and the distance rule.
- Delete undersides and hidden faces; spend triangles on the top silhouette and one focal feature.
- Write style rules as numbers, keep 3 to 5 golden assets, and review in a fixed order.

## Related sections

- [[Voxel Modelling Start Here]]: voxel scale, palettes, meshing and shading in depth.
- [[Untextured Stylised Modelling Start Here]]: flat colour, gradient atlases, vertex colour and lighting for untextured art.
- [[Materials and Surfaces Start Here]]: materials, MaterialVariants and SurfaceAppearance.
- [[Procedural Blender Assets Start Here]]: scripted asset builds, including the [[Low-Poly Tree Set Worked Example]].
- [[Voxel and Blocky Modeling]] and [[Voxel Art - Studs Outlines and Style Kits]]: the existing voxel foundations.
- [[Trim Sheets Atlases and Vertex Colors]]: colour without unique textures.
- [[Posing and Silhouettes]]: silhouette for animated poses.
- [[Level Design Principles - Flow Sightlines and Landmarks]]: how models fit into readable levels.

## Connected notes
<!-- auto-links:start -->
[[Keeping a Mixed Asset Library Consistent]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Hand-Painted and Stylized Texturing]] · [[Texel Density]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]]
<!-- auto-links:end -->
