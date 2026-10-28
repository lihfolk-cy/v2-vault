---
tags: [modeling, bevel, chamfer, edge-highlight, normals, vertex-colors, untextured, blender, stylised, lighting]
---
# Bevels Chamfers and Edge Highlights Without Textures

Hand-painted art paints a light line along every edge so shapes read. Untextured art has no paint, so the edge highlight must come from geometry, normals, vertex colour or lighting. [[Hard-Surface Modeling]] already covers the bevel-and-weighted-normal workflow: bevel widths as a percentage of object size, segment counts, and the Weighted Normal modifier. This note goes deeper into the part that matters for non-hand-painted styles: **why** a bevel catches light, how to size bevels for the distance an asset is seen from, what Roblox's materials and lighting do to that highlight, how to add edge brightening with vertex colour when geometry is too expensive, and the outline tricks that stand in for edge lines.

## Why a sharp edge looks wrong

A perfect 90-degree corner has zero width. On screen it is a hard boundary between two faces with different brightness and nothing in between. Real objects never have that: every real edge is slightly rounded, and that rounded strip faces in between the two surfaces, so it catches light from directions neither face does. The eye reads that thin bright line as "solid object". Without it, models look like paper or CAD output.

On a stylised Roblox model the highlight strip has a second job: it **separates planes of similar value**. Two faces of a crate lit almost equally (sun from above, both sides at a similar angle) merge into one shape. A bevel between them catches the sun and draws a line, restoring the corner. That is why untextured art bevels more than textured art: a texture can paint that line, flat colour cannot.

## How the highlight forms

The bevel faces have normals that point between the two adjacent faces. For a 45-degree chamfer on a box corner, the bevel normal points 45 degrees up and out. Under a sun high in the sky (a common Roblox setup), the top face is bright, the side face is darker, and the chamfer sits in the middle, often brighter than the side and close to the top. With smooth shading and 2 or more segments, the strip becomes a gradient from top value to side value, which reads as a soft rounded edge.

Three settings decide how strong that line looks:

1. **Width on screen.** A strip under about 1 pixel wide does not read; it just anti-aliases into the edge. See the width table below.
2. **The angle between the light and the strip.** Lights near the strip's normal brighten it most. Under flat ambient light (overcast skies, heavy ambient) all faces are similar and bevels nearly vanish.
3. **Specular response of the material.** Shiny materials put a sharp highlight on curved strips. Matte materials only change diffuse brightness. Roblox materials differ here (see below).

## Sizing bevels for distance, not object size

[[Hard-Surface Modeling]] sizes bevels as 1 to 3 percent of object size. That is right for objects seen at a normal distance for their size. For untextured stylised art on Roblox, a second constraint matters more: the strip must be wide enough on screen.

From the pixel maths in [[Modelling to the Roblox Camera and Player Scale]] (default 70-degree vertical field of view, Roblox docs, and a phone rendering about 720 pixels tall, rule of thumb), one pixel at distance `d` studs is roughly `d / 520` studs. A bevel needs to be about 2 pixels wide to read as a highlight line:

| Typical viewing distance | Minimum readable bevel width | Typical stylised choice |
|---|---|---|
| 5 to 10 studs (held tools, pets, counters) | 0.02 to 0.04 studs | 0.03 to 0.06 |
| 15 studs (characters, nearby props) | about 0.06 studs | 0.06 to 0.12 |
| 40 studs (buildings, enemies at range) | about 0.15 studs | 0.15 to 0.3 |
| 100 studs (landmarks) | about 0.4 studs | 0.4 to 0.8 |

Take the larger of the two rules: the percentage rule from the hard-surface note, and the pixel rule here. Small props seen close follow the percentage rule; large architecture seen far follows the pixel rule. A 12-stud tower with a "correct" 2 percent bevel has 0.24-stud edges, fine at 40 studs and lost at 100. If it is a landmark, double it.

### Why big bevels look toy-like, and when that is the point

Bevels above about 6 to 8 percent of the object's smallest dimension read as soft, toy-like, inflated forms (rule of thumb). That is exactly the look of many stylised simulator games, where props look like plastic toys. It is wrong for gritty or realistic styles. Decide it in the style bible ([[Style Bibles for Consistent Models]]) as a number, for example "outer bevel 0.08 studs on props under 3 studs, 0.2 studs on buildings, profile round, 2 segments", and apply it everywhere. Mixed bevel sizes across assets are one of the most visible signs of an inconsistent library.

## Chamfer versus rounded bevel

| Type | Segments | Look | Triangle cost per bevelled edge (rule of thumb) | Use |
|---|---|---|---|---|
| Chamfer | 1 | One flat strip, a crisp single highlight line | Lowest, about 2 triangles per edge span | Faceted low-poly styles, distant architecture, mobile-heavy games |
| Soft bevel | 2 | Rounded gradient | About 4 per span, plus corner patches | Most stylised props and characters |
| Round bevel | 3 or more | Smooth rounded edge, visible curve in silhouette | 6 or more per span | Hero pieces where the curve shows in outline |

For **flat-shaded faceted styles** (see [[Low-Poly and Stylized Modeling]] and the untextured section of the vault), a chamfer is usually better than a rounded bevel. A 1-segment chamfer gives one clear facet with its own flat value, which matches the faceted look. A 3-segment rounded bevel on a flat-shaded model shows three stepped strips and looks like an error.

For **smooth-shaded stylised styles**, 2 segments with Weighted Normal is the default. A trick that saves triangles on long straight edges: use 1 segment with Harden Normals off and a Smooth by Angle threshold above the chamfer angle, so the chamfer shades as a smooth gradient between faces. This gives most of the 2-segment look at half the cost, at the price of slightly softer flat faces. Test under the game's lighting.

## The vertex cost nobody counts

Triangle counts are visible in the Statistics overlay. Vertex counts after normal splitting are not, and they are what the GPU actually processes. Every hard edge (a sharp edge, a UV seam or a colour boundary) duplicates vertices along it, because a vertex can only carry one normal and one UV.

- A smooth-shaded 2-segment bevel shares vertices across the strip, so a bevelled box can have fewer **render** vertices than a sharp, flat-shaded box with the same silhouette, even though it has more triangles.
- A flat-shaded chamfered box has every face split: roughly 3 vertices per triangle in the worst case.

So on mobile-heavy projects the "cheapest" model is often a smooth-shaded low-segment bevel, not the sharpest box. See [[Mesh Optimization for Mobile]] for the general vertex rules.

## Roblox lighting and materials: what survives

Facts here are partly docs and partly rule of thumb from testing practice; Roblox does not publish the shading model per material.

- **Lighting style.** As of October 2026, `Lighting.Technology` is deprecated in favour of newer lighting properties (see [[Lighting Technologies and Settings]] for the current mapping, which the docs only partly describe). In practice, the more realistic lighting paths give sharper specular highlights on bevels, and the voxel-based path lights on a coarse grid (about 4 studs per cell per that note) so small bevels get no local shadowing. Test bevels in every lighting setup your game ships with.
- **Materials.** SmoothPlastic gives a clean diffuse response that suits flat-colour styles. Plastic adds a subtle surface look in some versions. Glass, Metal and Foil push specular. A MaterialVariant can set roughness; lower roughness sharpens bevel highlights. Test the same bevelled crate in your three most-used materials before setting the style rule.
- **Graphics quality.** On low graphics quality, some lighting and shadow detail drops (Roblox docs describe the quality levels in general terms only). Bevels survive because they are geometry; shadow-based edge definition does not. This is the main reason geometry bevels beat relying on shadows for edge reads on phones.
- **Ambient and fog.** High ambient or outdoor ambient values flatten everything; bevels need contrast between light directions to read. A strong key light (sun) with moderate ambient lets bevels pop. That is a lighting decision, not a modelling one, but modellers should know it.

### SurfaceAppearance, MeshPart.Color and vertex colour

Untextured edge tricks often rely on colour, so it matters how Roblox combines colour sources:

- `MeshPart.Color` tints the mesh. Imported vertex colours **multiply** with `Color` (DevForum guides and the experience recorded in [[Trim Sheets Atlases and Vertex Colors]]; not stated on the create.roblox.com modelling pages as of October 2026, so treat it as observed behaviour and verify in your Studio version).
- `SurfaceAppearance` overrides the mesh's texture and has its own `Color` property (listed in the Roblox docs reference as of October 2026, without a full description of how it combines with vertex colour). Whether vertex colours still show under a SurfaceAppearance is not confirmed in the docs; test it before building a pipeline around it.
- The Studio mesh importer has an option to ignore vertex colours (recorded in the vault's existing modelling notes). If your edge highlights disappear after import, check that first.

## Edge highlights without bevel geometry: four alternatives

When a bevel is too expensive (hundreds of crates, a forest of rocks, voxel art where bevels break the grid), these give a similar read.

### 1. Vertex colour edge brightening

Paint convex edges slightly lighter and concave creases slightly darker. On a flat-coloured mesh with `Color` set to the base colour, the vertex colours (multiplied) add edge definition at zero texture cost. Because the colour is interpolated between vertices, it works best on meshes that already have some edge loops near corners; on a plain 8-vertex cube it smears across whole faces.

### 2. Separate trim geometry in a lighter colour

Add a thin strip of geometry (or a separate material region) along key edges in a lighter tint: a roof ridge, a door frame, a table edge. This reads as a painted edge highlight and is very cheap when it is a single quad strip. It is a style choice: it reads as "trim", which suits buildings and furniture more than rocks.

### 3. Inverted hull outlines

Duplicate the mesh, push it out along normals by a small amount, flip its normals, and give it a dark colour. Only the back faces show, forming an outline around the silhouette. Cost: doubles the triangles and adds a draw call per mesh, unless combined into the same mesh. The outline width is in world units, so it thins at distance; size it with the distance table. [[Voxel Art - Studs Outlines and Style Kits]] compares outline methods for blocky styles. Roblox `Highlight` objects can also outline, but they are meant for selection and gameplay feedback, not for every asset in a world.

### 4. Shared gradient atlas edge strip

Not a painted texture but a shared tiny palette image: UV-map bevel faces onto a lighter swatch of the same palette used for the whole kit. One 256 or 512-pixel atlas serves every asset, so memory cost is shared. See [[Trim Sheets Atlases and Vertex Colors]].

## Worked example: edge-highlighted rocks without textures

Goal: a set of 8 stylised rocks for an engagement-band forest zone (seen from 20 to 60 studs), flat colour plus vertex colour, under 400 triangles each. Blender steps (Blender manual: Bevel modifier, Decimate, Vertex Paint, Dirty Vertex Colors).

1. **Block the rock.** Start from a cube, add a Subdivision Surface level 2, then apply it. Sculpt or move vertices to a chunky, flat-topped shape (straight against curve, see [[Shape Language and Silhouette Testing]]).
2. **Facet it.** Add a Decimate modifier in Planar mode at about 10 to 15 degrees, then Collapse mode to land near 250 triangles. Apply. You now have large flat planes, the shape language of stylised rock.
3. **Bevel the big edges.** Bevel modifier: Width type Absolute, width 0.15 studs (from the 40-stud row of the table), Segments 1, Limit Method Angle 35 degrees, Clamp Overlap on. One segment keeps the faceted look. Expect about 350 to 400 triangles.
4. **Shading.** Keep it flat-shaded for the faceted style. The chamfer strips now catch the sun as single crisp lines.
5. **Add a colour attribute.** In Object Data properties, add a Color Attribute (Face Corner, Byte Color) named `Col`, filled white.
6. **Dirty Vertex Colors.** In Vertex Paint mode, use Paint, Dirty Vertex Colors. Start with Highlight Angle about 150 degrees and Dirt Angle about 30 to 60 degrees, Blur Strength 1, Blur Iterations 1. This darkens concave areas and lightens convex ones based on local geometry. Keep the effect subtle: the brightest vertex near 1.0 white, darkest near 0.75 grey. Strong contrast in vertex colour shows the triangle structure as streaks, the same "patchy lines" failure recorded in [[Trim Sheets Atlases and Vertex Colors]].
7. **Top-light the colour.** Optionally paint the top-facing faces a touch lighter (about 5 percent) so the rock reads from the high camera even under flat ambient.
8. **UVs anyway.** Add a simple box-projected UV map so a material or texture can be added later without remodelling.
9. **Export.** FBX with vertex colours enabled (the FBX exporter has a vertex colour option; choose sRGB unless your pipeline says otherwise). For glTF, check the exporter's vertex colour option in your Blender version: some versions only export vertex colours that a material uses (tool docs; verify in your exporter's panel).
10. **Import and set colour.** In Studio, set `MeshPart.Color` to the rock base colour (say a warm grey). Because vertex colours multiply, the white areas show the base colour and the grey creases go darker. Set `Material` to SmoothPlastic or your style's rock material.
11. **Test.** View at 20 and 60 studs under the zone's lighting, and under the lowest graphics quality. The chamfer lines and creases should still define the planes.

Result: rock planes defined by a chamfer highlight and by vertex-colour ambient occlusion, recolourable per zone through `Color` alone, with no unique textures.

## When not to bevel

- **Voxel and blocky styles on a strict grid.** Bevels change the outline and break the stud grid's crispness. Use vertex colour edges, outlines or stud textures instead. See [[Voxel and Blocky Modeling]].
- **Distant skyline meshes.** At 300 studs and beyond, a bevel needs to be about 1 stud wide to read. Use value and silhouette instead.
- **Collision meshes.** Never bevel colliders; it multiplies physics cost for nothing.
- **Very thin parts.** A bevel wider than about a third of a part's thickness collapses it into a rounded tube. Clamp Overlap prevents broken geometry but not the look.
- **Edges that will be hidden** by another kit piece. Bevelling the meeting faces of modular walls wastes triangles and leaves visible grooves.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Bevels visible in Blender, invisible in game | Width under 2 pixels at play distance | Size from the distance table; double for landmarks |
| Gradients across big flat faces | Smooth shading without normal fix | Weighted Normal or Harden Normals (see [[Hard-Surface Modeling]]) |
| Stepped strips on a faceted model | 3-segment round bevel with flat shading | 1-segment chamfer |
| Streaky "patchy lines" on rocks | Strong vertex colour contrast | Keep vertex colour between about 0.75 and 1.0 |
| Vertex colour gone after import | Importer ignoring vertex colours, or exporter dropped them | Check importer option and exporter vertex colour setting |
| Library looks inconsistent | Bevel widths chosen per asset | Fix widths per size band in the style bible |
| Triangle count tripled | 3-segment bevels on every edge | Limit Method Angle or Weight; 1 to 2 segments |
| Bevels flat under some lighting | High ambient, no strong key light | Test under all shipped lighting; adjust lighting, not just bevels |

## Checklist

- [ ] Bevel width taken as the larger of the size rule and the distance rule.
- [ ] Segment count matches the shading style (chamfer for faceted, 2 for smooth).
- [ ] Bevel widths match the style bible's size bands.
- [ ] Normals fixed: Weighted Normal or Harden Normals, not both.
- [ ] Vertex colour edge brightening subtle (about 0.75 to 1.0).
- [ ] UVs present even on vertex-coloured meshes.
- [ ] Exporter and importer vertex colour settings checked.
- [ ] Tested under every lighting setup and the lowest graphics quality.
- [ ] No bevels on colliders, hidden kit faces or distant skyline meshes.

## Related

- [[Hard-Surface Modeling]]
- [[Low-Poly and Stylized Modeling]]
- [[Trim Sheets Atlases and Vertex Colors]]
- [[Voxel Art - Studs Outlines and Style Kits]]
- [[Voxel and Blocky Modeling]]
- [[Lighting Technologies and Settings]]
- [[Mesh Optimization for Mobile]]
- [[Materials and Surfaces Start Here]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Spending Triangles Where the Camera Looks]]
- [[Style Bibles for Consistent Models]]
- [[Modelling Nuance Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Untextured Stylised Modelling Start Here]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Keeping a Mixed Asset Library Consistent]]
<!-- auto-links:end -->
