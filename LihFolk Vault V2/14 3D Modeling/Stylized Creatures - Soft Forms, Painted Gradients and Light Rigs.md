---
tags: [modeling, creatures, stylized, hand-painted, skinning, bones, blender, procedural, type/guide, area/modelling, area/modeling, area/animation, level/intermediate, api/SurfaceAppearance, api/Bone, api/AnimationController]
---
# Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Thin median fins on a ball body: they read as ears, and thin fins fold during remeshing.
> - Avoid: Paired fins hidden behind the head in the front view, which leaves a featureless disc at 64 px.
> - Avoid: Decimating a dense shell instead of remeshing to quads: star highlights and faceting.
> - Front, side, top and three-quarter silhouettes read at 64 px; paired fins or limbs show from the front
> - One fused shell, quads, mirrored; symmetry error 0; gate passes (A2 watertight, A17 no self-intersections)
> - 2-4k tris, one material, one UV set, mirrored UVs with 0 overlaps
>
> Cost: TL;DR ~190 tok · whole note ~3.4k tok. Read more: ## 4. The painted bake (one texture, no PBR detail) · ## 7. Roblox import and setup · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A cute stylised creature (pet, critter, ambient fish, mount companion) reads on three things: one soft fused body with a clear outline, a painted texture that does the shading work, and a small rig that keeps it alive in an idle loop. This note gives the numbers for that look on Roblox: proportions, triangle and texture budgets, the bake recipe, the bone count, the import settings and the animation loop. It extends [[Low-Poly and Stylized Modeling]] (shape language, flat vs smooth shading), [[Hand-Painted and Stylized Texturing]] (painting by hand), [[Modeling Characters for R15 and Custom Rigs]] (route C custom rigs), [[Exporting and Validating Models for Roblox]] (export and import checks) and [[Mesh Optimization for Mobile]] (budgets). The construction lessons behind it are in [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]]; read that first if you build creatures by script.

The numbers marked **Measured** come from one demo build in this project: a pufferfish ("Puffling", 3,650 tris, 12 bones) made with the plugin's `lihfolk_creature.py` helper and scored by three blind reviewers per round over four rounds. The model passed (median 8.67 / 10); the swim clip did not (5.33). Everything else is a rule of thumb.

## 1. Proportions: design the shape before the mesh

| Part | Rule of thumb | Puffling (Measured) |
|---|---|---|
| Body mass | 60-70 % of the total length, one big rounded volume | body 2.6 of 3.9 studs |
| Eyes | Diameter 30-40 % of body height, set high and forward | 0.84 studs on a 2.2-stud body |
| Paired fins / limbs | Oversized: 35-50 % of body width each, splayed so they show from the front | pectorals reach 0.75 studs out from the side |
| Tail | Taper to 20-30 % of body height at the stalk, then a broad fan or tip | stalk half-height 0.25, fan 1.2 studs tall |
| Small tier | Only eyes, mouth, blush, spots; no geometry smaller than about 2 quads | stubby spines 0.2 studs long |

- **Silhouette test from every side.** Render solid black at 64 and 96 px from front, side, top and three-quarter ([[Shape Language and Silhouette Testing]]). A round creature is a disc from the front unless its paired fins or limbs stick out past the body outline there. Reviewers marked the front view down twice before the pectoral fins were moved forward and out.
- **Exaggerate one feature.** Eyes are the cheapest appeal lever; going from 0.34 to 0.42 studs (+25 %) removed the "eyes are moderate" complaint ([[Proportion Exaggeration and Gameplay Distance]]).
- **Thin upright fins read as ears.** Two tall narrow median fins (top and bottom) on a ball body were called "rabbit ears" by every reviewer. Sweep median fins back and keep them low and broad.

## 2. Build: one fused shell, quads, then mirror

The stable recipe for a smooth stylised body by script:

1. **Signed distance field.** Body from lofted elliptical cross-sections (stations every 0.3-0.5 studs, monotone interpolation, ellipsoidal end caps). Add round cones, ellipsoids and flat rounded fins, each smooth-unioned with a blend radius `k` of 0.06-0.14 studs. Author the right half only and evaluate at |x|, which gives an exact mirror.
2. **Surface nets at 0.025 studs**, then a voxel remesh at 0.9x that step for a clean manifold.
3. **QuadriFlow to the budget.** Even quads with few poles shade far better than a decimated mesh (decimation leaves star-shaped highlights and faceting: see the procedural creatures note).
4. **Keep the +X half**, project the vertices back onto the field (Newton steps along the gradient), relax tangentially twice, then mirror. Symmetry error is 0.0 by construction.
5. **Eyes as separate lens shells** (flattened spheres, depth 0.75x radius) seated 40-45 % of their depth into the head, so they bulge without a gap. Put the sphere poles on the side axis so rings, not a pole fan, face the camera.

| Constraint | Value | Why |
|---|---|---|
| Fin half-thickness | at least 0.6x the quad edge length (about 0.06-0.08 studs at 3-4k tris on a 4-stud creature) | Thinner fins fold during projection and the gate fails A17 (self-intersecting faces) |
| QuadriFlow seed | retry seeds 0-5, keep the first clean shell | One seed in three folded a thin fin in this build (Measured: seed 0 gave 12-16 crossings, seed 1 gave 0) |
| Two overlapping fins | blend their paint coordinates by soft-min weights | A hard switch at the crossing paints a visible seam down a forked tail |

## 3. Budgets

| Item | Budget | Note |
|---|---|---|
| Triangles | 2,000-4,000 for a pet-sized creature; class target 5,000 | Puffling 3,650: body about 2,800, eyes 2 x 430 |
| Texture | One 1024 px colour map + one 1024 px roughness map | Texel about 210 px per stud with mirrored UVs on a 4-stud creature (Roblox's default part texture is 128 px per stud) |
| Materials / UV sets | 1 / 1 | Eyes share the body's texture and material |
| Bones | 8-16; 12 here (11 deforming) | Root, Body, Head, Tail1, Tail2, TailFin, Dorsal, Anal, two 2-bone pectoral chains |
| Influences per vertex | at most 4, normalised | Roblox's skinning limit |

At 3-4k tris the quad edge is about 0.1 studs, so fin and eye outlines still show polygon steps in 512 px close-ups. The passing panel scored edges and shading 1 of 2 for exactly that. It costs about 0.7 points out of 10 and did not block the pass. Going higher costs the economy point instead, so decide per asset and say which you chose.

## 4. The painted bake (one texture, no PBR detail)

Bake an emission graph to the colour map with Cycles (EMIT bake, 64 samples, 16 px margin). Everything is computed from object-space position and normal, so the result is symmetric and has no seams:

| Layer | Recipe (Puffling values) |
|---|---|
| Base gradient | Main colour from head to tail (#FFB43F to #FF9440), kept close in hue |
| Top-light warmth | Normal Z from 0.25 to 1 mixes in a warm highlight colour at 0.35, posterised into 3 soft value steps blended 35 % with the smooth ramp (the "painted" step) |
| Counter-shaded belly | Smoothstep over (belly line - z) - 0.3 x normal Z, softness 0.28 studs, to a pale cream |
| Bounce rim | A cool, screen-blended band on the lower flank where normal Z runs from -0.05 to -0.9, at 0.35 |
| Spots, blush | Voronoi spots (scale 3.2, radius 0.20-0.235) on the back only; soft pink cheek ellipses |
| Fins | Their own root-to-tip gradient, 3 painted rays from the across-fin coordinate, and a pale edge band |
| Stroke noise | Stretched noise (7, 2.2, 7) varying value by +-12 % |
| AO in creases | AO distance 0.2 studs (5 % of length), amount 0.55-0.6, multiplied as a warm dark tint (#C0603A), never grey |
| Eyes | Deep navy iris lightening toward the bottom, two glints (radius 0.26 and 0.10 of the eye) computed per pixel from the eye's own frame |

- **Fade AO near the eyes.** Lens shells occlude the skin around them, and the bake paints a dark disc that reads as a stain (all three reviewers flagged it). Store an "eye near" weight (1 at the eye, 0 beyond 1.9 radii) and scale the AO term by 1 - 0.9 x weight.
- **Mirrored, overlapping UVs.** The paint is X-symmetric, so unwrap only the +X half and copy the UVs to each face's mirror twin. That doubles the texel density for free (168 to 210 px per stud, Measured). Triangulate before mirroring so every face has an exact twin.
- **Smart UV Project can overlap itself.** A face cluster that folds (the flank behind a fin root) projects onto itself and bakes a block of fin colour onto the body. Count UV overlaps after unwrapping, and remove the geometry that causes them. Here it was a small spine at the fin root.

Roughness is a second EMIT bake: body 0.55, fins 0.45, lips 0.4, eyes 0.06. That is what makes the eyes glossy with one material.

## 5. Rig: light, automatic, clamped

- **Chain from a polyline.** The spine runs from the head tip to the tail tip on x = 0. `Root` (no deform) sits at the origin. `Body` takes one segment and points to the head; head bones go forward and tail bones go back. Each fin gets a chain of 1-2 bones from root to tip, parented to the nearest spine bone. Bone names are `.L` for +X and `.R` for -X, and the creature faces -Y in Blender ([[Creature Rig Conventions]], [[Skeleton Library]]).
- **Weights.** Use automatic (heat) weights, then put the eyes 100 % on the head bone, fill any unweighted vertex from the nearest bone, clean below 0.01, limit to 4 influences and normalise all.
- **Root motion goes on `Body`.** The top bone's keys are not applied in Roblox ([[Bones and Skinned Meshes]]).

## 6. Animation loop: idle swim

| Setting | Value | Note |
|---|---|---|
| Length | 60 frames at 30 fps (2 s), 2 tail beats | Keys every 2 frames; first frame equals last, loop error 0.0 (Measured) |
| Tail wave | Yaw grows to 40 deg at the last tail bone, phase lag 1.6 rad per bone | |
| Timing | Phase warp `w - 0.55 sin(w)` for a fast power stroke and eased recovery; beat accent `1 + 0.35 cos` | |
| Body | Counter-yaw, roll 7 deg, pitch 6 deg, bob 0.14 studs, surge 0.05 studs | |
| Fins | Paired fins row +-34 deg with a 10 deg twist, the second bone lagging 1 rad, left and right 0.6 rad apart | |

**What the panel still marked down (Measured, 5.33 / 10):** the tail read as a rigid stick and the timing as an even sine. The reason is structural: on a round-bodied creature the first two tail bones sit inside the ball, so their lag is invisible and only the last bone reads. A visible S-wave needs a visible tail stalk, at least 25 % of the length outside the body mass. Hold the extremes for 2-3 frames and let the fan overshoot. Pectoral feathering (broad on the push, edge-on on the return) was the one cue every reviewer credited. For review, render onion skins (6 ghosts over one beat) as well as strips: strips of 8 frames hide timing.

## 7. Roblox import and setup

| Step | Setting |
|---|---|
| Format | GLB (+Y up, 1 unit = 1 stud, Apply Modifiers, skins and the action). Keep an FBX copy (`FBX_SCALE_UNITS`, no leaf bones) in case the importer does not take the glTF animation |
| 3D Importer | Scale Unit studs, import as a rigged model; one animation per file ([[3D Importer Settings Reference]], [[Importing Models and Rigs]]) |
| Look | `SurfaceAppearance` with `ColorMap` + `RoughnessMap` gives glossy eyes on a soft body. `MeshPart.TextureID` alone gives the colour map with uniform plastic shading, which is fine for distant ambient creatures |
| Animator | An `AnimationController` with an `Animator` under the model; Bones drive the skinned MeshPart |
| Physics | Collision follows the rest shape only. Use `CanCollide` off, `CanQuery` on for click or touch, `CollisionFidelity` Box; use separate hitbox parts for gameplay |

```lua
-- Play the looping swim clip on an imported skinned creature.
local model = workspace:WaitForChild("Puffling")
local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
controller.Parent = model
local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
animator.Parent = controller

local swim = Instance.new("Animation")
swim.AnimationId = "rbxassetid://0" -- replace with your uploaded swim clip
local track = animator:LoadAnimation(swim)
track.Priority = Enum.AnimationPriority.Idle
track.Looped = true
track:Play(0.2)
```

**Not verified in Studio:** the Puffling GLB has not been imported. Whether the glTF animation imports, whether custom normals survive, and how `SurfaceAppearance` renders on a skinned MeshPart all need one test import.

## Common mistakes

- Thin median fins on a ball body: they read as ears, and thin fins fold during remeshing. Keep them broad, swept back and at least 0.6x the quad edge in half-thickness.
- Paired fins hidden behind the head in the front view, which leaves a featureless disc at 64 px.
- Decimating a dense shell instead of remeshing to quads: star highlights and faceting.
- Letting the AO bake see the eye shells: a dark stain ring around each eye.
- Trusting Smart UV Project on folded clusters: overlapping islands bake fin colour onto the body.
- Hard switching paint coordinates between overlapping fins: a seam down a forked tail.
- Putting the tail wave in bones that sit inside the body: the motion is invisible, and the clip scores as a rigid paddle.
- Keying root motion on the top `Root` bone.
- Judging a looping clip from an 8-frame strip only.

## Checklist

- [ ] Front, side, top and three-quarter silhouettes read at 64 px; paired fins or limbs show from the front
- [ ] One fused shell, quads, mirrored; symmetry error 0; gate passes (A2 watertight, A17 no self-intersections)
- [ ] 2-4k tris, one material, one UV set, mirrored UVs with 0 overlaps
- [ ] Colour + roughness bake at 1024; AO tinted and faded near the eyes; no seams on forked fins
- [ ] 8-16 bones, at most 4 influences, normalised; eyes on the head bone; root motion on `Body`
- [ ] Loop: first frame equals last; visible tail stalk carries the wave; holds at the extremes
- [ ] Onion-skin and strip renders reviewed blind; Studio test import done before shipping

<!-- related:start -->
## Related
[[Organic and Creature Modeling]] · [[Topology and Edge Flow]] · [[Low-Poly Creature From a Flat Reference Sheet]] · [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]] · [[Procedural Model Kits - Lessons]] · [[Retopology and Decimation]] · [[UV Unwrapping]] · [[Modeling Fundamentals for Games]] · [[Normal Maps and Detail Baking]]
<!-- related:end -->
