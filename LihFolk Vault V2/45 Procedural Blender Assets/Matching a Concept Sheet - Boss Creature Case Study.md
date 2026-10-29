---
tags: [blender, creature, concept, rigging, case-study, low-poly, type/case-study, area/modeling, level/intermediate, area/animation]
---
# Matching a Concept Sheet - Boss Creature Case Study

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Assembling from primitives. Symptom: the model looks like a collection of parts rather than a creature.
> - Avoid: Many small repeated parts first. Symptom: hours spent on feathers while the silhouette is still wrong.
> - Avoid: Glow marks as meshes. Symptom: marks at different sizes, hidden behind other geometry, extra triangles.
> - Brief written: style, shape language, exaggerated feature, budget, size, facing.
> - Main mass is one box-modelled surface, not stacked primitives.
> - Appendages grown out of the mass (extrusion), not floated next to it.
>
> Cost: TL;DR ~180 tok · whole note ~2.5k tok. Read more: ## What worked: the vault workflow, done in code · ## Nuances and edge cases · ## Transferable checklist · ## Common mistakes
<!-- tldr:end -->

![[p45_void_owl_front.png]]
![[p45_void_owl_silhouette.png]]
![[p45_void_owl_posed.png]]

A boss concept sheet showed a "void owl": a faceted, saturated violet owl with huge raised wings, glowing pink ear tufts, round glowing eyes, a black hooked beak, rows of glowing crescent marks on the wings and chest, and big black talons. The goal was a riggable model that matched it closely. It took five passes. The first four failed for reasons worth knowing before you start your own.

## The passes

| Pass | Approach | Result | Why it failed |
|---|---|---|---|
| 1 | Hexagonal feather prisms fanned along a wing line, ico-sphere body, separate glow "V" pieces | Read as an owl, but spindly and generic | Thin feathers, small body, glow marks hidden behind feathers |
| 2 | Same, wider feathers, chunkier talons | Better, still "a fan of spikes" | Many separate slabs; no big shapes |
| 3 | Bigger proportions, tight framing | Owner: "way too small, not accurate" | Still many small parts; marks were individual meshes of different sizes |
| 4 | Glow marks moved into a painted texture; a covert panel added | Owner: horns wrong, then "missed the mark" | Body and head still separate blobs; tufts stuck on; silhouette wrong |
| 5 | The vault's creature workflow (below) | Owner: "on track", then refined | Shapes built the way a modeller would |

## What worked: the vault workflow, done in code

From [[Organic and Creature Modeling]] and [[Low-Poly and Stylized Modeling]]:

1. **Write the brief first** ([[Art Pipeline - Concept to In-Game Asset]] stage 1): boss, faceted low-poly, aggressive shape language (triangles and spikes), one exaggerated feature (huge raised wings plus talons), eyes as the brightest pixels, a triangle budget, final stud size, facing -Y.
2. **Box-model one mass for body and head.** A subdivided cube is pushed onto a sphere, then each vertex is moved by height profiles (half-width and half-depth at a list of heights), so the neck pinch, chest bulge and flat facial disc come from one continuous surface. Then triangulate, `dissolve_limit` at about 4 degrees to merge into larger facets, triangulate again. This is the step that made it look carved instead of assembled.
3. **Extrude the tufts out of the head** (pick the face nearest the tuft root, extrude three times, move up and out, shrink the last ring to a point). Grown, not attached.
4. **Wings as layered tier plates**, not individual feathers: three plates per wing (coverts, secondaries, primaries), each a strip along the wing's leading edge with a blocky tabbed trailing edge, offset in depth. Each plate's UVs are in world units along the span, so the painted crescents line up across the whole wing.
5. **Paint the markings.** One numpy-drawn mask per plate type; the material mixes base colour and glow colour by the mask and drives emission with it. A "front only" factor (the face normal's -Y component) keeps chest marks off the back.
6. **Silhouette test**: a flat black Workbench render on white, compared with the sheet's front view.

A refinement round then widened the body, enlarged the head, thickened the wing roots and strengthened the brow glow. The owner asked to undo one change (broader tufts); because each change was a small named edit, the undo was one revert.

**Measured in these builds:** the final model was about 2,000 triangles in one skinned mesh, every vertex weighted, on 19 bones.

## Rigging it

The [[Skeleton Library]] Bird_Winged rig's bone names were reused (RootPart, Body, Neck, Head, Beak, Tail1-2, Left/RightWing1-3, Upper/LowerLeg, Foot), placed at the owl's joints, Left = +X. Weighting:

- **Rigid** for beak, talons, legs and tufts: every vertex of a piece 100 percent to one bone.
- **Height blend** for the body mass: Body below the chest, Neck around it, Head above.
- **Span blend** for wing plates: project each vertex onto the leading edge, find which wing bone segment it falls in, blend 50/50 near the joints.

The pose was set only by rotating bones in armature space (rotate each pose bone's matrix about a world axis through its head), which proves the skinning before any animation exists. See [[Creature Rig Conventions]] and [[Weight Painting and Skinning for Roblox]].

## Transferable checklist

- [ ] Brief written: style, shape language, exaggerated feature, budget, size, facing.
- [ ] Main mass is one box-modelled surface, not stacked primitives.
- [ ] Appendages grown out of the mass (extrusion), not floated next to it.
- [ ] Big readable shapes first; small repeated parts last or never.
- [ ] Markings painted on UVs, not modelled.
- [ ] Every render compared side by side with the concept at the same angle, plus a silhouette render.
- [ ] Rig names from a known skeleton; rigid where the style allows, blended only where it bends.

Related: [[Posing and Silhouettes]], [[Concept Sheets]], [[Procedural Blender Assets Start Here]].

## Nuances and edge cases

1. **Matching the sheet is not the same as matching the game camera.** A concept sheet shows a front view at eye level. A boss is usually seen from below and slightly behind a player's shoulder, often at 30 to 80 studs. Huge raised wings that read in the front view can hide the head from below, and chest marks may face away from the player. Once the model matches the sheet, re-check it from the arena's real camera positions and adjust for readability there.
2. **One skinned mesh versus separate parts.** About 2,000 triangles in one skinned mesh with 19 bones is efficient to render, but it limits gameplay: you cannot hide a broken wing, flash only the head when hit, or give the beak its own hitbox without extra work. If the fight design needs breakable or targetable parts, split those pieces into separate meshes now, while the rig is fresh.
3. **Painted markings and phases.** Putting the glowing crescents in a texture saved geometry and made them line up, but swapping textures at runtime per phase is heavier than toggling a part. If phase two should make the marks glow red, plan either a second texture set or a separate glow overlay mesh that can change colour.
4. **Rigid weights and large poses.** Rigid weighting on beak, talons and legs is fine for a faceted style. Extreme poses (wings fully swept back, a deep crouch) show gaps at rigid joints. Decide the most extreme poses the boss will hit and test them before animation starts, not after.
5. **Scale and collision.** A boss scaled up to dominate an arena keeps its 2,000 triangles but its collision and hitboxes grow too. A skinned mesh's collision does not follow the animation, so do not use the mesh itself as the hitbox. Use simple invisible parts attached to bones for hits and leave the mesh visual only.
6. **Server cost of a boss.** One boss is cheap to render. What costs is animating it on the server for 30 players to see. Let the server decide the state (phase, attack, target) and let clients play the animations; replicate state changes, not poses.
7. **Feedback loops.** It took five passes partly because early passes changed many things at once. With an external reviewer (an owner, a client, an art director), small named edits and side-by-side renders at the same angle make each round shorter and each undo one revert, as happened here.

## Common mistakes

1. **Assembling from primitives.** Symptom: the model looks like a collection of parts rather than a creature. Fix: box-model one mass for body and head, then grow appendages out of it.
2. **Many small repeated parts first.** Symptom: hours spent on feathers while the silhouette is still wrong. Fix: big shapes first, details last or as texture.
3. **Glow marks as meshes.** Symptom: marks at different sizes, hidden behind other geometry, extra triangles. Fix: paint them into UV-aligned masks.
4. **No silhouette check.** Symptom: "it does not look like the sheet" without a clear reason. Fix: flat black silhouette render compared with the sheet's front view.
5. **Inventing bone names.** Symptom: animations and tools built for the standard bird rig do not work. Fix: reuse the Bird_Winged names from the skeleton library.
6. **Using the mesh as the hitbox.** Symptom: hits miss when the boss rears up or register on empty air. Fix: bone-attached hit parts.
7. **Changing several things per round.** Symptom: a reviewer dislikes one change and you cannot isolate which. Fix: one named edit per change, reversible on its own.

## Related decisions

- [[Boss Fight Design Patterns]]: what the fight needs from the model (tells, weak points, phases).
- [[Boss Animation and Phases]]: animating phase changes on a skinned rig.
- [[Hitboxes and Hit Detection]]: building bone-attached hit parts instead of mesh collision.
- [[Combat Arena and Encounter Layout]]: the real camera distances the boss is seen from.
- [[Enemy Animation State Protocol]]: replicating boss state rather than poses.
- [[Weight Painting and Skinning for Roblox]]: moving from rigid to blended weights where needed.
- [[Character and Creature Pipeline]]: where concept review rounds sit in the wider creature pipeline.
- [[Colour-Blind Safe Design]]: making glowing tells readable to every player.
- [[Animating Creatures and Monsters]]: motion that suits a heavy winged boss.

## Connected notes
<!-- auto-links:start -->
[[Chibi Character Rules in Practice]] · [[Bones and Skinned Meshes]] · [[Low-Poly Creature From a Flat Reference Sheet]] · Skinning Weights · Rigging in Blender · Modeling Characters for R15 and Custom Rigs
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Low-Poly Tree Set Worked Example]] · [[Stylised Weapons From a Concept]] · [[Stylised Shop Stand Worked Example]] · [[Mesh VFX Packs Built in Blender]] · [[Dash VFX Presentation on an R15 Rig]] · [[Stylised Log Cabin Worked Example]] · [[Blender 5 Python Gotchas for Headless Builds]] · [[Dramatic Showcase Renders in Eevee]]
<!-- related:end -->
