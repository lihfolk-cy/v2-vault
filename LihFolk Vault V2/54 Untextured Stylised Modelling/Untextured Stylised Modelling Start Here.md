---
cssclasses: [vault-hub]
tags: [hub, modeling, untextured, stylised, flat-colour, gradient-atlas, normals, lighting, art-direction, type/hub, area/modeling, level/beginner]
---
# Untextured Stylised Modelling Start Here

This section is about stylised 3D art that gets its look without painted texture detail: from geometry, flat or gradient colour, vertex colour, normals and Roblox lighting. That covers the bright flat look of many simulator and collection games, faceted low-poly worlds, chunky bevelled "toy" props, and gradient-shaded mobile-style kits. It is cheap in texture memory, survives phones well and ages slowly, but it is unforgiving: with no paint to hide behind, every shading error, off-palette colour and mismatched bevel is visible.

The notes go past the basics in the existing modelling section. They give numbers (facet and bevel sizes in on-screen pixels for the Roblox camera, strip widths that survive mips, palette sizes, sun-to-ambient ratios), explain how each method interacts with Roblox properties (`MeshPart.Color`, `TextureID`, `SurfaceAppearance` alpha modes, vertex colours, `LightingStyle`), and include worked examples in Blender and Luau.

## Read these first

The section builds on existing notes. If you are new to stylised art on Roblox, read these before the notes below:

1. [[Low-Poly and Stylized Modeling]]: the two stylised families, shape rules, segment counts and the three colouring methods in brief.
2. [[Trim Sheets Atlases and Vertex Colors]]: the technical basics of palette atlases and vertex colours, and the vertex colour trap.
3. [[Environment Art Styles]]: style families on Roblox and a palette derivation table.
4. [[Stylized Lighting Recipes]] and [[Lighting Technologies and Settings]]: lighting property sets and what each property does.
5. [[Hard-Surface Modeling]] and [[Topology and Edge Flow]]: bevel and topology fundamentals.
6. [[Stylised vs Realistic Material Pipelines]]: where the flat stylised pipeline sits next to stylised PBR and realistic PBR.

## The notes

| Note | Read it when |
|---|---|
| [[Flat Colour vs Gradient Atlas vs Vertex Colour]] | You are choosing how a kit gets its colour, or a vertex-coloured import looks dark or streaky |
| [[The Gradient Palette Texture Workflow]] | You want one tiny texture to colour and shade a whole world, and need the layout, UV moves, mip rules and palette swaps |
| [[Faceted Low-Poly - Flat Normals and Facet Size]] | You are building gem-like or origami low-poly art and want facets that read at gameplay distance |
| [[Clean Stylised Shading - Weighted and Custom Normals]] | Flat faces show gradients, canopies look lumpy, or shading changes between Blender and Studio |
| [[Colour Scripts and Value Structure for Untextured Art]] | Zones look muddy or samey, players miss interactables, or you are planning palettes across many zones |
| [[Lighting Untextured Art in Roblox]] | Flat art looks like cut-outs, washes out, or falls apart on phones and low graphics settings |
| [[Keeping a Mixed Asset Library Consistent]] | Assets come from Studio, Blender, CC0 packs, the store, voxel tools and AI generators and do not look like one game |

## A suggested path

- **Starting a new stylised game:** colour script and value plan first, then the colouring method decision, then the gradient workflow, then lighting and the look-dev room, then library rules.
- **Fixing a world that looks cheap:** run the library audit, check values in greyscale, fix the sun-to-ambient balance, then fix normals on the worst offenders.
- **Building faceted art:** facet size note, then clean shading for the smooth parts, then lighting for sun angle.

## Rules that run through the section

- **Every Roblox colour path multiplies.** Vertex colour times `Color`, `SurfaceAppearance.Color` times the colour map. Multiplies only darken: author near white where you want to tint, and set `Color` to white on vertex-coloured meshes.
- **Size details in on-screen pixels, not studs.** With the default 70 degree vertical field of view, one stud at distance `d` covers about `H / (1.4 x d)` pixels. Facets, bevels and palette strips all follow from that.
- **Design for the lowest device.** Form that comes from geometry, normals and baked gradients survives phones; form that comes only from shadows does not.
- **Pick colours under the game's lighting**, never in a colour picker, and check values in greyscale with a `ColorCorrectionEffect` at `Saturation = -1`.
- **Write the rules as numbers** and audit them with a script. Consistency is a pipeline, not a mood.

## Facts to re-check

Roblox does not document several behaviours this section relies on. The notes label them, and you should test them in your Studio version: how `MeshPart.Color` combines with an opaque `TextureID`; what `SurfaceAppearance.ResampleMode = Pixelated` does at distance; whether automatic mesh LODs keep custom normals; which features each graphics quality level drops; and the texture size ceiling (the texture specifications page mentions both 1024 and 4096).

## Related sections

- [[Modelling Nuance Start Here]]: shape language, silhouettes, proportion, bevels, triangle spending, camera and player scale, style bibles and critique.
- [[Voxel Modelling Start Here]] and [[Voxel Palettes - Ramps Hue Shifting and Limits]]: the voxel side of untextured art.
- [[Materials and Surfaces Start Here]]: when you do want materials and textures.
- [[Procedural Blender Assets Start Here]] and [[Low-Poly Tree Set Worked Example]]: scripted stylised assets in Blender.
- [[Art Budgets - Triangles Draw Calls Memory]]: the budgets every note here works within.

## Connected notes
<!-- auto-links:start -->
[[Bevels Chamfers and Edge Highlights Without Textures]] · Voxel Shading - Baked AO Edges and Lighting · Style Bibles for Consistent Models · Baking Lighting and Detail into Textures · Hand-Painted and Stylized Texturing · Modeling in Blender for Roblox
<!-- auto-links:end -->
