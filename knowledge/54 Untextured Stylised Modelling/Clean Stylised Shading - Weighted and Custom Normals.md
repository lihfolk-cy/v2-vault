---
tags: [modeling, untextured, stylised, normals, weighted-normals, bevel, shading, blender, foliage]
---
# Clean Stylised Shading - Weighted and Custom Normals

Untextured stylised art has nowhere to hide shading errors. On a painted asset, a smudgy gradient across a flat face disappears under brush strokes; on a flat-coloured SmoothPlastic prop, it is the most visible thing on screen. "Clean" stylised shading means flat faces look flat, curved faces look curved, edges catch a crisp highlight, and big soft forms (tree canopies, clouds, cartoon heads) shade like one smooth volume instead of a pile of lumps. Almost all of that is controlled by **normals**, not by geometry or colour.

This note covers the normals toolkit for low and mid-poly stylised meshes: sharp edges, bevels with harden normals, the Weighted Normal modifier, face strength, and normal transfer for foliage and characters. It also covers how those normals survive export into Roblox and what breaks them. The geometric side of bevels (chamfer widths, edge highlight design) is in [[Bevels Chamfers and Edge Highlights Without Textures]] and [[Hard-Surface Modeling]]; faceted styles, where every face is flat on purpose, are in [[Faceted Low-Poly - Flat Normals and Facet Size]].
## The problem in one picture

Take a cube with a small bevel on every edge and Shade Smooth. Each corner vertex averages the normals of the big face and the bevel faces around it. The result: the big flat faces shade with a gradient that darkens toward the edges, as if the cube were slightly inflated. On a textured asset that is barely noticeable. On a white SmoothPlastic crate under Roblox's sun it reads as dirty, soft, "cheap asset pack".

The fix is to make the big faces' normals point straight out (so they shade perfectly flat) while letting the small bevel faces carry the transition. Every technique below is a way of doing that.

## Technique 1: sharp edges (split normals)

Mark the boundaries between surfaces that should not blend as sharp. In Blender 4.1 and later the old Auto Smooth checkbox is gone; use **Shade Auto Smooth** (which adds the "Smooth by Angle" modifier) or **Shade Smooth by Angle** as an operator. Rule of thumb angle for stylised props: **30 to 40 degrees**. Below 30, gentle curves start to facet; above 45, real corners start to smear.

- Cost: every sharp edge splits its vertices, so GPU vertex count rises (as with full flat shading, but only along those edges).
- Weakness: with no bevel, a sharp edge is a hard line of infinitely thin highlight. It reads as computer-generated. Fine for faceted styles, not for "clean chunky".

## Technique 2: bevel with Harden Normals

Add a **Bevel modifier**, then enable **Harden Normals**. The Blender manual describes it as adjusting "the per-vertex face normals of the bevel faces ... to match the surrounding faces". The large faces become dead flat, and the bevel faces carry the curve between them.

Settings that work for stylised props (rule of thumb, starting points):

| Setting | Value | Why |
|---|---|---|
| Amount | 2 to 5 percent of the object's smallest large dimension | Wide enough to catch a highlight at game distance; see the pixel rule below |
| Segments | 1 for small and far props, 2 for hero props, 3 only for big close-up curves | Each segment adds a ring of faces along every bevelled edge |
| Limit Method | Angle, about 30 degrees | Bevels real edges, not gentle curves |
| Shape | 0.5 (default) for a round profile | Shape has no effect with fewer than 2 segments (Blender manual) |
| Clamp Overlap | On | Stops bevels overlapping on short edges (Blender manual) |
| Harden Normals | On | The point of this technique |

Shade the object smooth (or with Smooth by Angle) for Harden Normals to matter. Apply the modifier on export.

### The pixel rule for bevel width

A bevel only does its job if it is visible. Using the camera maths from [[Faceted Low-Poly - Flat Normals and Facet Size]] (about `H / (1.4 x d)` pixels per stud with Roblox's default 70 degree vertical field of view), a bevel needs to be about **2 to 3 pixels wide on screen** to read as a highlight rather than aliasing (rule of thumb). On a 720 px tall phone render at 25 studs (about 21 px per stud), that is about 0.1 to 0.15 studs. On a hub prop seen from 10 studs (about 51 px per stud), 0.05 studs is enough. On a far building at 100 studs (about 5 px per stud), even 0.5 studs is borderline; skip bevels on far geometry and use gradient colour instead.

## Technique 3: the Weighted Normal modifier

The **Weighted Normal** modifier recomputes normals so that larger faces dominate. On a bevelled box, the big faces win and stay flat; the small bevel faces take up the slack. The result is close to Harden Normals, with more control, and it works on meshes you did not bevel with the modifier (booleans, imported meshes, hand-modelled chamfers).

Blender manual options: **Weighting Mode** (Face Area, Corner Angle, or Face Area and Angle), **Weight** ("a value of 50 means all faces are weighted uniformly"; higher values bias toward the chosen mode), **Threshold** (areas or angles closer than this get equal weights), **Keep Sharp** (respects sharp edges), **Face Influence** (uses face strength set by the Set Strength tool or the Bevel modifier), and a **Vertex Group** limit.

Starting settings (rule of thumb):

- Mode **Face Area**, Weight **50 to 70**, Threshold **0.01**, **Keep Sharp on**.
- Put it **last** in the modifier stack, after Bevel and after any Smooth by Angle modifier, so it sees the final faces.
- Raise Weight toward 100 if big faces still show gradients; lower it if small curved parts start to look faceted.

### Face strength for tricky models

When areas fight (a small but important flat face, like a logo plate, losing to a large curved face), use **Face Influence**. Mark faces Strong, Medium or Weak with Mesh > Normals > Set Face Strength (or let the Bevel modifier set it with its face strength mode), and enable Face Influence on the Weighted Normal modifier. Strong faces then keep their normals regardless of area.

## Technique 4: normal transfer for soft volumes

Foliage canopies, bushes, clouds and cartoon hair are often built from many overlapping blobs or cards. Smooth-shaded, each blob shades as its own little sphere and the canopy reads as lumpy popcorn. The stylised fix is to borrow normals from one simple smooth shape:

1. Build the canopy from 3 to 8 blobs (icospheres, displaced, decimated) and join them into one mesh.
2. Add a **proxy**: a UV sphere or a smoothed, shrinkwrapped blob that encloses the canopy. It never exports.
3. On the canopy, add a **Data Transfer** modifier: Face Corner Data, **Custom Normals**, source = the proxy, mapping Nearest Face Interpolated (or Projected Face Interpolated). In Blender 4.1 and later custom normals no longer need Auto Smooth enabled.
4. Apply on export.

The canopy now shades like one smooth sphere: lit on the sun side, dark underneath, with no internal lumps. The silhouette keeps its blobby, leafy edge. This is the technique behind many "Ghibli-like" stylised trees in public tutorials (rule of thumb; it is widely documented in Blender community material).

The same idea fixes cartoon character heads built from parts (nose, cheeks, brow merged into the head): transfer normals from a smooth head proxy so the joins vanish. Use a vertex group to limit the transfer to the join areas.

Gotchas:

- Transferred normals make the inside of a cluster look lit when the camera sees into it. Keep blobs overlapping enough that the camera rarely sees deep inside.
- Gradient palette UVs should still follow height or the proxy's normal, not each blob's own shape ([[The Gradient Palette Texture Workflow]]), or colour and shading disagree.

## Technique 5: hand-editing normals

For a handful of hero assets, set normals directly: Mesh > Normals > **Point to Target**, **Set from Faces**, **Average**, **Merge** and **Copy/Paste Vectors**. Useful for making a flat sign face shade perfectly flat on an otherwise smooth mesh, or for pointing a character's face normals forward so the face never goes dark under side lighting. Expensive in time; save it for a few assets.

## Exporting normals so Roblox keeps them

- **Apply the modifier stack** at export (both FBX and glTF exporters have an apply-modifiers option). Weighted Normal, Data Transfer and Smooth by Angle only exist as results if applied.
- **FBX**: Smoothing set to **Normals Only** writes the custom split normals (Blender manual). **Face** or **Edge** smoothing modes write smoothing groups instead; some importers rebuild normals from those, losing weighted normals. glTF writes normals when its Normals option is on (the default).
- **Triangulate before export** if the mesh has non-planar quads, so the triangle split is the one the normals were computed for. A different split in the importer shifts shading slightly.
- **Do not merge by distance after normal editing.** Merging vertices recomputes or loses split normals. Clean geometry first, normals last.
- **Roblox side.** Roblox renders imported normals (rule of thumb; the 3D Importer docs do not describe normal handling as of October 2026). Meshes with `RenderFidelity = Automatic` get simplified versions at distance; whether those keep custom normals exactly is not documented. In practice far LODs are small on screen, so artefacts there rarely matter, but if a hero prop's shading changes as you walk away, test `RenderFidelity = Precise` on it (and pay its cost; see [[Level of Detail and Model Streaming]]).

## How Roblox lighting exposes bad normals

Three settings make normal errors more visible, so test with them on even if your game uses gentler values:

- **SmoothPlastic** shows gradients cleanly; Plastic's surface pattern hides a little.
- **`EnvironmentSpecularScale` near 1**: Roblox docs say smooth objects then "better reflect the environment". Reflections stretch along broken normals, showing every lump. Many stylised games keep it at 0 to 0.2 ([[Stylized Lighting Recipes]]), which hides some errors, but players on high graphics still see specular highlights from the sun.
- **Low sun angle** (`ClockTime` around 7 or 17): grazing light exaggerates gradients across flat faces.

A look-dev check: place the asset next to a white SmoothPlastic cube and sphere (perfect normals) under the game's lighting. The asset's flat faces should match the cube's faces in evenness; its curves should match the sphere's smoothness. See [[Lighting Untextured Art in Roblox]] for the full test room.

## Worked example: a clean chunky crate

Target: a 3-stud stylised crate, flat colour, seen from 10 to 25 studs, about 300 triangles.

1. **Block out** a 3 x 3 x 3 cube. Inset the four side faces (I, about 0.3 studs), extrude the insets inward 0.1 studs for panel recesses.
2. **Add the frame planks** as separate pieces or by extruding the border; keep them as part of one mesh.
3. **Bevel modifier**: Amount 0.08 studs (about 3 percent of 3 studs; about 1.7 px at 25 studs on a phone, 4 px at 10 studs: fine for a mid-distance prop), Segments 1, Limit Method Angle 30 degrees, Clamp Overlap on, Harden Normals on.
4. **Shade Smooth.** Check: big faces should now look flat in Solid view with a matcap like "metal" or "toon" (matcaps exaggerate normal errors, which is what you want while checking).
5. **Weighted Normal modifier** last: Face Area, Weight 50, Threshold 0.01, Keep Sharp on. Compare on and off; with Harden Normals already on, the difference should be small. If the recessed panels show gradients, raise Weight to 70.
6. **Triangulate**, apply all modifiers on export, FBX Smoothing Normals Only.
7. **Colour**: two flat colours via a palette atlas (wood light for planks, wood dark for recesses), or two MeshParts with flat `Color` if the crate appears rarely.
8. **Studio check** next to a white cube and sphere under the zone's lighting, at 10 and 25 studs, in the phone emulator.

Triangle count: about 250 to 350 with 1-segment bevels. A 2-segment bevel roughly doubles the bevelled-edge cost; only do it if the crate is a hero object seen up close.

## When not to bother

- **Faceted styles**: you want the opposite (flat faces everywhere); see the facet note.
- **Voxel and blocky art**: cube faces are flat by construction; normals are already perfect if each face is flat-shaded ([[Voxel and Blocky Modeling]]).
- **Objects under about 30 px on screen**: shading subtleties are invisible; spend nothing.
- **Hand-painted assets**: painted light covers small gradients; weighted normals still help, but they are not critical.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Flat faces darken toward edges ("inflated" look) | Smooth shading averaging across bevels | Harden Normals or Weighted Normal (Face Area) |
| Shading fine in Blender, smeared in Studio | Modifiers not applied, or FBX Smoothing set to Face/Edge | Apply modifiers; FBX Smoothing Normals Only |
| Lumpy, popcorn tree canopy | Each blob shades as its own sphere | Data Transfer custom normals from a proxy sphere |
| Hard thin line of light on every edge | Sharp edges with no bevel | Small bevel with Harden Normals |
| Curved surfaces look faceted after weighting | Weight too high or Smooth by Angle too low | Lower Weight; angle 30 to 40 degrees |
| Shading changed after cleanup | Merge by Distance after normal edits | Clean geometry first, edit normals last |
| Bevel invisible in game | Bevel narrower than 2 px on screen | Size bevels by pixels at the usual camera distance |
| Hero prop shading shifts with distance | Automatic LOD simplification | Test `RenderFidelity = Precise` for that asset only |

## Checklist

- [ ] Smooth by Angle at 30 to 40 degrees, or deliberate sharp edges.
- [ ] Bevels sized to at least 2 to 3 px at the usual viewing distance; Harden Normals on.
- [ ] Weighted Normal last in the stack, Face Area, Keep Sharp, Threshold 0.01.
- [ ] Soft volumes (canopies, clouds, heads) use transferred normals from a proxy.
- [ ] Modifiers applied on export; FBX Smoothing Normals Only or glTF Normals on; triangulated.
- [ ] Checked next to a perfect white cube and sphere in Studio under the game's lighting, including a low sun.

## Related

- [[Hard-Surface Modeling]]
- [[Bevels Chamfers and Edge Highlights Without Textures]]
- [[Faceted Low-Poly - Flat Normals and Facet Size]]
- [[Topology and Edge Flow]]
- [[Low-Poly Tree Set Worked Example]]
- [[Lighting Untextured Art in Roblox]]
- [[Stylized Lighting Recipes]]
- [[Exporting and Validating Models for Roblox]]
- [[Level of Detail and Model Streaming]]
- [[Foliage Props and Scatter]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Keeping a Mixed Asset Library Consistent]] · [[Low-Poly and Stylized Modeling]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]]
<!-- auto-links:end -->
