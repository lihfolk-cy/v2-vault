---
tags: [blender, python, buildings, stylised, low-poly, environment, snow, vertex-colors, modules, export, type/guide, area/modeling]
---
# Stylised Log Cabin Worked Example

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Bevelled fan caps left as n-gons. Symptom: the gate fails on n-gons after `finish("soft")`.
> - Avoid: Icicles, firewood and small fittings placed by eye.
> - Avoid: One origin per module. Symptom: modules do not line up when imported together.
> - Log rows from one course spacing; gable logs cut by the roof slope
> - Snow from a rounded outline with a lip; icicles seated just inside it
> - Every module's origin at the cabin's bottom centre
>
> Cost: TL;DR ~150 tok · whole note ~3.7k tok. Read more: ## Logs and corners · ## Gate fixes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

![[p45_log_cabin.png]]

A snowy night log cabin built from one Python script and matched to a painted reference: stacked round-log walls with log ends crossing at every corner, a 50 degree gable roof under a thick snow layer with icicles, a red brick chimney with a smoke wisp, warm glowing windows with teal shutters and an attic window, and a side porch with a plank door, wall lantern, firewood stack and steps. It is built in studs, split into 8 modules totalling about 13,400 triangles, and every module passes the LihFolk gate. The script is `scripts/build_log_cabin.py`. It uses the helpers in `skills/roblox-blender-modeling/scripts` (`lihfolk_bpy`, `lihfolk_curves`).

Numbers are measured in this build (Blender 5.2, October 2026) unless marked rule of thumb.

## Brief and scale

- **Studs, not metres.** The door is 3.6 by 7.5 studs, so a 5 stud R15 avatar fits through with headroom ([[Modelling to the Roblox Camera and Player Scale]]).
- **Footprint:** wall centre lines 18 by 22 studs, eaves about 12.4 studs high, the whole cabin about 26 studs tall without chimney and smoke, on a 33 by 30 stud snow plate.
- **Palette:** five warm log browns, cream end grain, near-white snow with a blue-grey shadow tone, brick reds, teal shutters, one orange glow. Values are hex in sRGB, stored as vertex colours on one white material per module ([[Flat Colour vs Gradient Atlas vs Vertex Colour]]).
- **Seeded:** `random.Random(7)`, so every rebuild is identical.

## Modules, not one mesh

The cabin is eight meshes, split by what they need in Roblox rather than by what they look like:

| Module | Triangles | Why it is separate |
|---|---:|---|
| Walls (stacked logs) | 4,960 | The collision mass; Box or Hull collision |
| Roof (wood, snow, icicles) | 1,572 | Different collision (none or Hull), can be swapped for a summer roof |
| Chimney | 704 | Small, sits on the roof |
| Porch (deck, steps, posts, rails, lean-to, door, lantern, firewood) | 3,310 | The densest detail; walkable deck |
| Trim (frames, mullions, sills, shutters, caps) | 2,052 | Decoration only, no collision |
| Glow (window and lantern glass) | 60 | Needs Neon or emissive in Studio |
| Smoke | 378 | Needs transparency, no collision, could be animated |
| Base (snow plate and drifts) | 384 | Optional: drop it if the map has its own ground |

**Every module's origin is the bottom centre of the whole cabin,** not of the module. After building, the script measures the bounding box of all modules together, shifts every mesh by the same vector, and sets each origin at (0, 0, 0). Imported together, the modules then land on each other exactly, with no hand placement in Studio. This is the same idea as the grid corner origin in [[Modular Environment Kits]], applied to the parts of one building.

## Logs and corners

All wall geometry comes from three numbers: log radius `R = 0.62`, course spacing `DZ = 1.12` and corner overhang `OV = 1.05`.

- **Side walls** run along Y: 11 courses, each log a closed cylinder from one overhang to the other.
- **Gable walls** run along X, offset by half a course (`z = R + DZ/2 + i*DZ`). That half-course offset is what makes the corners interlock: the two walls' logs alternate up the corner instead of colliding at the same height.
- **The bottom gable log** is a thinner sill log (radius 0.47) so the wall sits flat on the ground.
- **Small variation:** each log's radius varies by -4 to +3%, its overhang by up to 0.12 studs, and its colour comes from the five browns with a small jitter. Identical logs read as a texture; varied logs read as a built cabin ([[Stylised Shop Stand Worked Example]] uses the same rule for planks).

### Gable logs cut by the roof

Above the eave, the gable logs shorten so their ends follow the roof slope. Each course's half-length comes from the roof underside function:

```python
T = math.tan(math.radians(50))
def zb(x):                       # roof underside height at x
    return Z_EAVE + (XW - abs(x)) * T

hw = XW - (z + R - Z_EAVE) / T + 0.15   # half-length of the gable log whose top is z + R
```

The loop stops when a log would be shorter than 2 studs. Deriving the length from the same `zb()` that places the roof keeps the logs tucked under the roof boards when the pitch or height changes, like the anchor-point awning in [[Stylised Shop Stand Worked Example]].

### End grain on the log ends

Each cylinder cap is a fan around a centre vertex, so there are no n-gons on the cap itself. The vertex colour goes from a light tan at the centre to the log's brown at the rim, which reads as end grain at game distance for zero texture cost.

![[p45_log_cabin_corner_logs.png]]

A blind reviewer read this centre-to-rim shading as "gradients on flat faces" (rubric V5). It is deliberate, but it is a judgement call: if your style bible says flat colours only, use two rings of flat colour instead of a blend.

## Snow and icicles

### Roof snow

The roof is a chevron outline (the gable cross-section) extruded along Y. Both the wood and the snow use it:

- **Wood:** the chevron from the roof underside, 0.9 studs thick.
- **Snow:** a wider chevron (the eaves overhang 2.55 studs past the walls, against 1.9 for the wood), 1.6 studs thick, with a 0.45 stud lip that droops below the roof edge. Its corners are rounded with `lc.round_corners` (radius 0.75 to 1.1 on the ridge and lip), which is what makes it read as soft snow instead of a white board.
- **Colour by normal:** faces pointing up get pure snow, side faces a blue-grey shadow tone, faces pointing down a darker blue. That fakes ambient occlusion in the vertex colours, so the snow still has form under Roblox's flatter lighting.

### Icicles

Icicles are 5-sided cones hung along the eaves (34 per side), plus shorter ones along the gable rakes and the porch roof. Lengths are drawn from a short list (0.7 to 2.1 studs, scaled 0.8 to 1.15) rather than a continuous range, which gives the rhythmic mix of long and short icicles real eaves have.

**Seat them from the snow geometry, not by eye.** The cone top is placed 0.45 studs above the snow underside, just inside the lip, computed from `zb()` and the lip size. The first version placed them at a typed height, and several hung in the air under the lip. The gate's seat check did not catch it, because each icicle is part of the same roof module as the snow (see the floating scan below).

## Windows, door and porch

- **Windows** are a frame, crossed mullions and a sill around a glass box in the Glow module. The front windows get teal shutters and a small snow-capped gable cap; the attic window gets a cap only.
- **Glow** is one emissive material (strength 9 in Blender). In Roblox, emission does not light the world: give the glow module Neon, and add real lights, a [[SurfaceLight]] per window or one PointLight inside, if the snow in front should glow ([[Lighting Technologies and Settings]]).
- **The porch** is a lean-to under the main eave: a plank deck, two steps, posts and a beam, a railing on the window side, and a lean-to roof with its own snow and icicles.
- **Firewood** is stacked in rows of cylinders with the cut ends facing out, alternating half a log per row, and capped with the same end-grain shading as the walls.
- **The smoke** is a sweep along a Catmull-Rom S curve (`lc.catmull_rom`, `lc.sweep`) whose radius swells then thins with height, coloured grey to white upwards. In Blender its alpha fades with height through the material; in Roblox use one MeshPart with Transparency about 0.5, or replace it with a ParticleEmitter for moving smoke.

## Gate fixes

Every module ran through `lf.gate` with the building, medium or small budget class. Two problems failed it, and one was found only by an extra check.

1. **N-gons from bevelled caps.** `lf.finish(style="soft")` adds a one-segment bevel. On the fan caps and box faces, the bevel produces faces with more than 4 vertices, and the gate fails on n-gons. Fix: add a Triangulate modifier straight after the bevel, with `min_vertices = 5` (only n-gons are cut; quads stay quads) and `keep_custom_normals = True` so the weighted normals survive:

    ```python
    tri = m.modifiers.new("LF_TriNgons", "TRIANGULATE"); tri.min_vertices = 5
    tri.keep_custom_normals = True
    m.modifiers.move(len(m.modifiers) - 1, 1)   # directly after the bevel
    ```

2. **Floating shells inside a module.** The gate checks that modules sit on each other, but a module is made of many separate shells (282 in this cabin), and one icicle or log hanging in the air inside the roof module is still "part of the roof". The QA script adds a whole-cabin scan:
    - join the evaluated meshes of every module into one bmesh, in world space;
    - split it into shells by edge connectivity (union-find);
    - find touching shells with `BVHTree.overlap`;
    - flood-fill from the base module's shells; anything not reached is floating.

    The first run found icicles, firewood, the door knob and the lantern bracket floating. Each was moved to touch its support, and the final scan reports 0 of 282 shells floating. Run this scan on any building made of many small parts; it is a few dozen lines and catches what a per-module gate cannot.

## Render and export

- **Beauty shot:** Eevee at 64 samples, AgX view transform, a world gradient from warm haze at the horizon to deep navy, a cool moonlight sun (energy 2.6, slight blue), an area light behind each window, a point light at the lantern, and compositor Glare for bloom. The pines, fence, ground, moon and stars are in a separate "Staging" collection and are never exported ([[Dramatic Showcase Renders in Eevee]]).
- **Review renders:** `lf.render_review` with feature close-ups of a window, the chimney, the door and lantern, a corner of logs, the firewood and the eave icicles. Small seating and shading mistakes only show up in the close-ups.
- **Export:** `lf.export_glb` per module, plus one GLB with all modules. To export several objects with the same settings, the script temporarily wraps the helper's object-activation step so every module is selected, then restores it.
- **Rubric:** a blind reviewer scored 14/18 with no zeros before the last fixes (V3, V5, V7 and V9 at 1). After thinning the smoke, smoothing the drifts and adding icicles, the builder's own re-score was 16/18 (Unverified: not re-reviewed blind).

![[p45_log_cabin_silhouette.png]]

## Nuances and edge cases

1. **Triangles are counted after the bevel.** The table above counts the evaluated meshes. The walls carry most of it: 11 side courses and the gable logs at 10 sides each, doubled by the bevel. Cutting log sides from 10 to 8 saves about a fifth of the wall triangles with little visible change at game distance (Rule of thumb).
2. **The porch is the densest module.** Deck planks and firewood are many small parts. For a village of cabins, merge the planks into one slab with painted plank lines, and the firewood into a single block with end-grain caps on the visible face only ([[Mesh Optimization for Mobile]]).
3. **Collision:** walls and porch deck Box or Hull, the roof Hull if players can land on it, everything else CanCollide, CanTouch and CanQuery off ([[Collision and Physics Geometry]]).
4. **Vertex colours need a white MeshPart.** Set MeshPart.Color to white after import, or every colour is tinted.
5. **The snow drifts look faceted with soft finishing.** Low-poly icospheres with hard edges read as rocks. Shade them smooth (`finish("smooth")`); only the hard-surface modules get the soft bevel.
6. **Night scenes hide colour problems.** Check the cabin in a daylight render too: the snow shadow tones and the log browns must still read when the warm glow is not doing the work.
7. **Differences from the reference** were accepted for budget: a shorter side wall with one window, a separate lean-to porch roof, chunkier and fewer icicles, a stylised smoke tube instead of painterly wisps.

## Common mistakes

1. **Bevelled fan caps left as n-gons.** Symptom: the gate fails on n-gons after `finish("soft")`. Fix: a Triangulate modifier straight after the bevel, `min_vertices = 5`, keeping custom normals.
2. **Icicles, firewood and small fittings placed by eye.** Symptom: floating shells the gate does not see, because they are inside one module. Fix: compute seats from the support geometry, and run a whole-model floating-shell scan.
3. **One origin per module.** Symptom: modules do not line up when imported together. Fix: one shared origin at the whole building's bottom centre for every module.
4. **Gable logs sized by hand.** Symptom: log ends poke through the roof, or gaps open under it when the pitch changes. Fix: derive each log's length from the roof underside function.
5. **Logs on the same course height on both walls.** Symptom: logs collide at the corners instead of interlocking. Fix: offset the gable walls by half a course.
6. **Identical logs.** Symptom: the walls read as a texture, not a built cabin. Fix: small random radius, overhang and colour per log, seeded.
7. **Emission expected to light the world in Roblox.** Symptom: glowing windows but dark snow in game. Fix: Neon on the glass and real lights for the spill.

## Checklist

- [ ] Log rows from one course spacing; gable logs cut by the roof slope
- [ ] Snow from a rounded outline with a lip; icicles seated just inside it
- [ ] Every module's origin at the cabin's bottom centre
- [ ] Gable walls offset half a course so the corners interlock
- [ ] Triangulate after the bevel; gate passes on every module
- [ ] Whole-model floating-shell scan reports 0
- [ ] Glow on its own module; Neon and real lights planned for Studio
- [ ] Staging props kept out of the export
- [ ] Triangles counted on evaluated, bevelled meshes

## Related decisions

- [[House Construction Method - Modular Kit Workflow]]: the general method this build fed, with the style-swap table and the `lihfolk_house` builders.
- [[Stylised Shop Stand Worked Example]]: the same script-first approach for a smaller prop.
- [[Low-Poly Tree Set Worked Example]]: pines like the staging trees.
- [[Modular Environment Kits]]: turning the cabin's modules into a kit.
- [[Exporting and Validating Models for Roblox]]: checks to run on the GLB.
- [[Blender 5 Python Gotchas for Headless Builds]]: API traps hit in builds like this.
- [[Procedural Blender Assets Start Here]]: the other builds in this section.

<!-- related:start -->
## Related
[[Dash VFX Presentation on an R15 Rig]] · [[Stylised Weapons From a Concept]] · [[Low-Poly Creature From a Flat Reference Sheet]] · [[Mesh VFX Packs Built in Blender]] · [[Chibi Character Rules in Practice]] · [[Matching a Concept Sheet - Boss Creature Case Study]]
<!-- related:end -->
