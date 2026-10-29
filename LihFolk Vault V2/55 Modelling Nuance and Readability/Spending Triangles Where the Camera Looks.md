---
tags: [modeling, triangles, budgets, optimization, camera, lod, silhouette, blender, python, mobile, type/guide, area/modeling]
---
# Spending Triangles Where the Camera Looks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Budget met but model looks plain: Triangles spread evenly, none on silhouette or focal feature -> Move triangles to the top silhouette and one focal feature
> - Same segment count everywhere: Style rule written as one number -> Scale segments by radius and distance (sagitta table)
> - Spiky features vanish at range: Generated lower RenderFidelity levels dropped thin parts -> Thicken key features; check at 250 and 500 studs
> - Viewing distance and most-seen angles noted for the asset.
> - Cylinder and sphere segments chosen from radius and distance.
> - Bottom, touching, interior and against-wall faces deleted where safe.
>
> Cost: TL;DR ~200 tok · whole note ~4.0k tok. Read more: ## Segment counts from distance: the sagitta rule · ## Scene-level spending · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A triangle budget says how many triangles an asset may have. It does not say where they should go. Two crates with 600 triangles each can look completely different: one spends its triangles on a rounded silhouette and chunky handles the player sees from the high follow camera, the other spends them on a detailed underside nobody ever sees. [[Art Budgets - Triangles Draw Calls Memory]] sets the totals and [[Environment Art Styles]] lists which places in a world deserve detail. This note is about the distribution **inside** each model and across a scene: how to calculate segment counts from viewing distance, which faces the Roblox camera actually sees, where to delete, where to add, and how to check the spend with a script.

## The principle: triangles are only worth what they change on screen

A triangle earns its cost when it changes one of three things a player can see:

1. **The silhouette edge.** Curvature on the outline is the most visible use of triangles. A round shoulder with 6 segments looks like a polygon in silhouette; with 12 it looks round.
2. **Shading across a curved surface.** Interior curvature affects how light grades across a surface. Smooth shading hides a lot here, so interior faces need far fewer segments than the silhouette suggests.
3. **Separate shapes and colour regions.** A belt, a rim or a colour block on an untextured model needs its own geometry.

Triangles that change none of these (flat faces split into a grid, hidden faces, interior faces, detail smaller than a pixel) are waste. On a phone, they still cost vertex processing and memory. See [[Mesh Optimization for Mobile]].

## Segment counts from distance: the sagitta rule

A circle drawn with `n` straight segments deviates from the true circle by at most the **sagitta**: `s = r * (1 - cos(pi / n))`, where `r` is the radius. If `s` is below about 1 pixel at the viewing distance, nobody can see the facets on the silhouette.

Using the pixel size from [[Modelling to the Roblox Camera and Player Scale]] (about `d / 520` studs per pixel at the default 70-degree vertical field of view on a phone rendering about 720 pixels tall; field of view from Roblox docs, pixel height a rule of thumb), the minimum segment count for a smooth silhouette is roughly:

| Radius | Seen from 8 studs | 15 studs | 40 studs | 100 studs |
|---|---|---|---|---|
| 0.25 studs (handle, finger) | 9 | 7 | 4 | 3 |
| 1 stud (barrel, limb) | 18 | 14 | 8 | 6 |
| 3 studs (tower, tree crown) | 31 | 23 | 14 | 9 |
| 10 studs (dome, big rock) | 57 | 42 | 26 | 16 |

These are counts around the full circle for a truly smooth outline. Stylised art deliberately shows facets, so most games use far fewer: about half these numbers for "soft low poly" and a third for "faceted low poly" (rule of thumb). The table matters for a different reason: it shows that **segment count should scale with distance and radius**, not be one fixed number per style. A 7-segment cylinder is correct for a 0.25-stud handle at 15 studs and far too coarse for a 3-stud tower at the same distance.

### Only the silhouette needs the count

A cylinder seen side-on shows its segments only at the left and right edges; the front faces are smooth-shaded and look round anyway. That suggests two savings:

- **Non-uniform segments.** On objects with a known facing (a wall-mounted lamp, a stall with its back to a wall), put more segments where the silhouette is seen and fewer on the hidden side.
- **Caps are cheap to simplify.** A cylinder's end caps add `n - 2` triangles each as a fan. A cap that faces away from the camera or into the ground can be deleted entirely.

## Which faces the Roblox camera actually sees

The default third-person camera sits behind and above the character, and the player orbits it freely. Across a session, the viewing directions are not uniform. A rule-of-thumb distribution for a typical third-person Roblox game:

- **Top and upper sides are seen most.** The camera looks down at the world at roughly 15 to 40 degrees most of the time. Top surfaces of props, roofs, terrain props and the tops of characters' heads and shoulders are always in view.
- **The player's own avatar is seen mostly from behind.** Whatever the player carries on their back (a sheathed weapon, a backpack, a cape) is on screen for most of the session. Back details on player-held items deserve more triangles than front details.
- **Other characters are seen from all sides.** NPCs and enemies turn to face the player, so their front three-quarter is the most-seen view.
- **Undersides are almost never seen.** The bottoms of props resting on the ground, the undersides of tables and the soles of static statues are not visible unless the camera goes below the floor.
- **Backs of props against walls are never seen.** A shelf against a wall, a wall-mounted sign, building backs at the map edge.

So for a world prop the priority order is: top silhouette from the high camera, the front and sides, then the back if it is free-standing, and never the underside.

## Where to delete

Deletion is the cheapest optimisation and the one most often skipped.

1. **Bottom faces of grounded props.** A crate sitting on the floor does not need its bottom face. Saving: 2 triangles on a box, but up to a fifth of the model on a bevelled rounded prop, because the bottom bevel ring goes too. Exception: props the player can pick up, knock over or see from below (physics props, floating islands).
2. **Faces that touch other meshes.** Where a pillar meets a floor, the pillar's bottom cap and the floor faces under it are hidden. Where two modular walls meet, the touching faces are hidden. See [[Modular Environment Kits]].
3. **Interior faces.** Faces inside a closed volume from joined parts. Blender's Select All by Trait, Interior Faces finds many of them (Blender manual).
4. **Back faces against walls and map edges.** A building facade along the map boundary needs no back. Keep a thin back shell only if the camera can swing around it.
5. **Detail below 1 pixel.** Any bevel, bolt or ridge smaller than about `d / 520` studs at its closest common viewing distance. Bake it into vertex colour or delete it.

A caution on deleting faces: a mesh with open holes can show a see-through gap if the camera ever reaches the hidden side, and collision derived from the visual mesh (with `CollisionFidelity` set to Default or PreciseConvexDecomposition) may be affected. Use a separate simple collision setup. See [[Collision and Physics Geometry]].

## Where to add

- **Silhouette curvature on the most-seen view.** Shoulders and heads of characters, roof ridges, the tops of tree crowns, the rims of barrels seen from above.
- **Joints that deform.** Elbows, knees and shoulders need loops for clean bending; see [[Topology and Edge Flow]]. These are the only places where "invisible" interior loops are justified, because they become visible as soon as the joint moves.
- **Interactables and focal features.** The thing the player is meant to look at: a chest lid, a gem, a quest-giver's face. [[Low-Poly and Stylized Modeling]] calls this "one focal feature per object".
- **Colour region borders on untextured art.** A colour change on a flat-colour model needs an edge loop to live on. Plan the loops for colour blocks at the modelling stage rather than adding them after.

## Scene-level spending

The same logic applies across a whole zone. A scene of 200 props at 1,000 triangles each spends 200,000 triangles evenly; the same budget spent with intent looks much richer:

| Asset group | Share of zone triangles (rule of thumb) | Why |
|---|---|---|
| Hero landmarks (1 to 3 per zone) | 15 to 25 percent | Seen from everywhere, on thumbnails, as wayfinding |
| Path-side props within about 25 studs of main paths | 30 to 40 percent | Seen close and often |
| Interactables and stations | 15 to 20 percent | Looked at directly |
| Background and filler | 15 to 25 percent | Mass and silhouette only |
| Skyline and far set dressing | 5 to 10 percent | Shape only; streamed or low detail |

Instanced copies of the same mesh are cheaper to draw than unique meshes (see [[Art Budgets - Triangles Draw Calls Memory]] for how Roblox batches identical meshes and materials). That means a well-made 1,200-triangle rock used 40 times can be better value than 40 unique 400-triangle rocks. Spend triangles on the reusable pieces and keep unique one-offs for the focal points.

### Using RenderFidelity and LOD as part of the spend

`MeshPart.RenderFidelity` set to Automatic shows lower-detail versions with distance (Roblox docs give 250 and 500-stud thresholds; see [[Level of Detail and Model Streaming]]). Those versions are generated by Roblox, and you do not control how they simplify. Two consequences:

- Models seen mostly within 250 studs are always drawn at full detail, so your own triangle spend inside that range is what counts.
- A model whose silhouette depends on a few thin features (antennae, spikes) may lose them in the generated lower levels. If a distant read matters, make those features thick enough to survive, or check how the model looks at range in Studio.

## Worked example: re-spending a 2,000-triangle hand cart

Starting point: a stylised hand cart for a market zone, 2,000 triangles, evenly detailed. Seen from 10 to 40 studs, from the high follow camera, never from below. Target: same 2,000 triangles, better read.

1. **Measure the current spend.** Run the script below in Blender. Suppose it reports: top-facing 22 percent, bottom-facing 18 percent, sides 60 percent. The wheels use 640 triangles (two 16-segment wheels with full hubs and both caps).
2. **Delete the underside.** Remove the bottom faces of the cart bed and the bottom bevel ring. Saves about 200 triangles. The cart is never lifted.
3. **Re-segment the wheels.** Wheel radius 1 stud, seen from 10 to 40 studs. From the table, about 8 to 18 segments gives a fully smooth outline (18 at 8 studs, 8 at 40); for a soft stylised look, 10 is enough. Drop from 16 to 10 segments and delete the inner caps facing the cart body. Saves about 260 triangles.
4. **Delete hidden faces.** The faces where the handles enter the bed and where the axle meets the wheels. Saves about 60.
5. **Spend on the top silhouette.** The high camera sees the cart bed rim and the goods on top. Add a rounded 2-segment bevel to the rim (0.12 studs, from the bevel note's 15 to 40-stud range) and give the sacks on top a rounder outline. Costs about 300.
6. **Spend on the focal feature.** Add a chunky awning hoop or a sign board, which gives the cart a recognisable shape from across the market. Costs about 200.
7. **Check.** Re-run the script: top-facing share goes up, bottom-facing share drops to near zero. Total still near 2,000. Render the silhouette sheet from [[Shape Language and Silhouette Testing]]: the cart now has a distinct top outline from the high three-quarter view.

## Script: report triangle spend by direction

Run in Blender's Python console or Text Editor with a mesh selected, in Object mode. It counts triangles (an n-sided face is `n - 2` triangles) and groups them by the direction each face points in world space. Uses `bpy` mesh polygon data as documented in the Blender Python API.

```python
# Blender: report where a mesh's triangles face (world space). Object mode.
import bpy

obj = bpy.context.active_object
mesh = obj.data
rot = obj.matrix_world.to_3x3().normalized()

buckets = {"top": 0, "bottom": 0, "front": 0, "back": 0, "left": 0, "right": 0}
total = 0
for poly in mesh.polygons:
    tris = poly.loop_total - 2
    total += tris
    n = rot @ poly.normal
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 2:
        buckets["top" if n.z > 0 else "bottom"] += tris
    elif ax == 1:
        # Blender's front view looks along +Y, so -Y faces the front.
        buckets["front" if n.y < 0 else "back"] += tris
    else:
        buckets["right" if n.x > 0 else "left"] += tris

print(f"{obj.name}: {total} triangles")
for k, v in buckets.items():
    print(f"  {k:6s} {v:6d}  {100 * v / max(total, 1):5.1f}%")
```

Typical findings: a "bottom" share above about 10 percent on a grounded prop means deletion is due; a "back" share above the "front" share on a wall-mounted prop means the model was not built for its placement. The script does not see occlusion by other meshes, so treat it as a guide, not a proof.

## When not to optimise this way

- **Physics props and anything the player can turn over.** All sides get seen.
- **Items shown in a rotating inspect view or a shop turntable.** The inspect camera sees everything; budget for all sides, or build a separate display version.
- **Avatar items and UGC.** These are seen from every angle and follow Roblox's own validation rules ([[UGC Avatar Items and Accessories]]).
- **Very low counts already.** Below about 300 triangles, the gain from deleting a few faces rarely matters compared with draw calls and instance count.
- **Free camera games.** Games with a free-fly camera, spectator modes or a top-down camera need their own view analysis; the high third-person assumption does not hold.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Budget met but model looks plain | Triangles spread evenly, none on silhouette or focal feature | Move triangles to the top silhouette and one focal feature |
| Same segment count everywhere | Style rule written as one number | Scale segments by radius and distance (sagitta table) |
| Spiky features vanish at range | Generated lower RenderFidelity levels dropped thin parts | Thicken key features; check at 250 and 500 studs |
| Hole visible from an odd camera angle | Deleted faces the camera can reach | Only delete where the camera cannot reach; keep a back shell |
| Detailed undersides on ground props | Modelled as a floating object | Delete bottom faces and bottom bevel rings |
| Heavy wheels and cylinders | Default 32-segment cylinders | Pick segments from the table, delete hidden caps |
| Player's back accessory looks cheap | Detail placed on its front | Spend on the back: it is on screen most of the session |

## Checklist

- [ ] Viewing distance and most-seen angles noted for the asset.
- [ ] Cylinder and sphere segments chosen from radius and distance.
- [ ] Bottom, touching, interior and against-wall faces deleted where safe.
- [ ] Triangles moved to top silhouette and the focal feature.
- [ ] Deformation loops kept on joints.
- [ ] Direction report run; bottom share near zero on grounded props.
- [ ] Silhouette checked at range with RenderFidelity Automatic.
- [ ] Zone-level spend roughly matches the share table.

## Related

- [[Art Budgets - Triangles Draw Calls Memory]]
- [[Environment Art Styles]]
- [[Mesh Optimization for Mobile]]
- [[Level of Detail and Model Streaming]]
- [[Retopology and Decimation]]
- [[Topology and Edge Flow]]
- [[Collision and Physics Geometry]]
- [[Modular Environment Kits]]
- [[Low-Poly Tree Set Worked Example]]
- [[Shape Language and Silhouette Testing]]
- [[Modelling to the Roblox Camera and Player Scale]]
- [[Bevels Chamfers and Edge Highlights Without Textures]]

## Connected notes
<!-- auto-links:start -->
[[Modelling Nuance Start Here]] · [[Style Bibles for Consistent Models]] · [[Triangle Budget]] · Faceted Low-Poly - Flat Normals and Facet Size · Hard-Surface Modeling · Stylised Shop Stand Worked Example
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Proportion Exaggeration and Gameplay Distance]] · [[Modeling Fundamentals for Games]] · [[Stylised Shop Stand Worked Example]] · [[Critiquing a Model - Paintovers and Iteration]] · [[Art-Direction Nitpicks - The Principles Behind Them]]
<!-- related:end -->
