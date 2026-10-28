---
tags: [blender, eevee, rendering, presentation, volumetrics, lighting]
---
# Dramatic Showcase Renders in Eevee

![[p45_cosmic_sword.png]]
![[p45_celestial_gate.png]]

Two presentation scenes were built for marketing-style previews: a cosmic sword floating in space (nebula-glass blade, micro rocks, gas, sparkles, star flares) and a celestial gate (carved stone ring, rune band, gear rings, crystals, a swirling vortex, lightning, mist). These are render scenes, not game assets: the gate scene was about 48,000 triangles. The techniques below are what made them read as dramatic.

## Building blocks

| Effect | How | Notes |
|---|---|---|
| Nebula material | Two noise textures multiplied, through a colour ramp (black, deep purple, magenta, cyan), into emission; Voronoi distance raised to a power added on top for pinpoint stars | Use Object coordinates so the pattern stays on the mesh |
| Star field world | Voronoi at a high scale, distance mapped and raised to the 6th power, added to a dark navy | Cheap and infinitely sharp |
| Volumetric gas | A big box with a Principled Volume; density = noise through a ramp, times a falloff by distance from the subject's axis; emission from the same density | Keep density low (about 0.15) or it washes the whole frame |
| Floor mist | Same idea with density falling off by height over 1.5-3 units | Too thick hides the base; about 0.07 was right |
| Star flares | A numpy-drawn 4-point star with alpha on planes, emission material, Track To the camera | Place 4-6, not dozens |
| Sparkles | Hundreds of tiny icospheres (radius 0.006-0.035) with strong emission | Bigger ones turn into hexagons under depth of field |
| Floating rocks | Icospheres (subdivision 2) squashed and bumped with sines, dark rough material, a few with glowing emission | Keep them out of the camera's near field |
| Lightning | Recursive midpoint displacement between two points, thin cones per segment, strong emission | 5 bolts read better than 9 |
| Swirling vortex | Polar coordinates in the shader: angle = atan2, radius = length; `angle + log(radius) * twist` fed to a noise; brightness up toward the centre | See the gotcha below |
| Rune band | Procedural glyphs drawn into a long mask texture (strokes on a 3x4 grid per glyph), on an annulus with UV u = angle | 56 glyphs around a 5-unit ring read well |

## Lighting and camera

- **Coloured rim lights** (pink from one side, cyan from the other) do most of the drama; a cool key keeps forms readable.
- **A strong point light inside the portal** lights the stone from within.
- **Bloom** through the compositor's Glare node (Bloom type); threshold about 1.0, strength 0.6-0.9.
- **Depth of field** focused on the hero detail (the guard, the keystone) at f/2.8 sells scale.
- **Tall frames** for swords (2:3), wide for set pieces.

## View transform matters

AgX (with the Punchy look) handled the bright emissive scenes well. For pastel or saturated character art, AgX washed colours toward grey; Standard kept them. Check both before deciding the colours are wrong.

## The swirl shader gotcha

The first vortex rendered as vertical streaks. The disk was created flat in X and Y, then rotated 90 degrees to face the camera; the shader read Object X and Z, and Z is zero on a flat disk, so the angle was constant. **Object coordinates are in the mesh's own space, before the object rotation.** Read the axes the mesh was built in.

## Readability fixes that were needed

- Gas box edges visible as vertical walls: make the box much larger than the falloff radius.
- Pink fog everywhere: lower density and emission; let the background stay dark.
- Rocks reading as flat grey hexagons: subdivision 2, squash and bump, darker albedo.
- Gold trim invisible: trim geometry was inside the wing thickness; make inlays slightly thicker than the part they sit on.

Related: [[Stylized Lighting Recipes]], [[VFX Design Playbook]], [[Stylised Weapons From a Concept]], [[Procedural Blender Assets Start Here]].

## Nuances and edge cases

1. **A showcase render is a promise.** Thumbnails, icons and store art built from these scenes set expectations. If the in-game sword has none of the nebula glow, volumetric gas or depth of field, players who clicked for the render feel misled, and early leavers hurt discovery. Keep marketing renders recognisably the same object and palette as the game asset, and push drama through lighting and framing rather than features the game does not have. Platform rules on misleading thumbnails also apply.
2. **What survives the trip into Roblox.** Volumetric gas, real depth of field, emission that lights nearby surfaces and per-pixel procedural shaders do not exist on Roblox parts in the same form. Roblox has its own post-processing (Bloom, DepthOfField, ColorCorrection, Atmosphere), Neon, Beams and particles. If the render is meant to preview the in-game look, build it only from things you can rebuild in Studio; if it is pure marketing, say so internally so nobody tries to match it in the engine.
3. **Thumbnail size changes what matters.** Store thumbnails and icons are often seen tiny on phones. Hundreds of sparkles, fine rune glyphs and subtle gas vanish at that size; a strong silhouette, two contrasting rim colours and one bright focal point remain. Make a downscaled check (for example 150 pixels wide) part of every render review.
4. **Render time and iteration.** Volumetrics and many emissive objects are slow in Eevee. A 48,000-triangle scene with volumes can take long enough per frame that each feedback round costs minutes. Keep a "draft" toggle in the build script (no volumes, lower samples, smaller resolution) and only render the final at full quality.
5. **Colour management varies by viewer.** AgX versus Standard is only one part of the chain. The image will be viewed on phone screens with different brightness and on platforms that recompress it. Very dark navy backgrounds band and blotch after compression. Lift the darkest values slightly and add a little noise to large gradients.
6. **Determinism of procedural scenes.** Sparkle positions, lightning bolts and rocks come from random numbers. Seed them, or the next render after a small lighting tweak will move every bolt and you cannot compare versions side by side.
7. **GPU differences.** Eevee output differs a little between GPUs and drivers, and volumetrics can differ more. If several people render the same scene, expect small differences; final marketing renders should come from one machine.

## Common mistakes

1. **Everything glows.** Symptom: the image is a bright haze with no focal point. Fix: one hero emitter, everything else dimmer, and dark negative space.
2. **Fog density too high.** Symptom: pink or purple wash over the whole frame. Fix: densities around 0.07 to 0.15 as noted above, with falloff.
3. **Visible volume box edges.** Symptom: straight vertical walls in the gas. Fix: make the box much larger than the falloff radius.
4. **Depth of field on the wrong thing.** Symptom: the most important detail is soft. Fix: focus on the hero detail, then check at thumbnail size.
5. **Too many flares and bolts.** Symptom: the scene looks noisy and cheap. Fix: 4 to 6 flares, about 5 bolts.
6. **Text added in Blender.** Symptom: a title is hard to edit later and blurs in compositing. Fix: render clean and add text in an image editor, sized for the smallest display.
7. **Not checking the dark end on a phone.** Symptom: the background turns into blocks after upload. Fix: lift blacks slightly and add grain.

## Related decisions

- [[Thumbnails Icons and Store Page]]: where these renders end up and the sizes they must work at.
- [[Icon and Thumbnail Rendering Pipeline]]: turning one-off scenes into a repeatable render pipeline.
- [[A-B Testing and Experiments on Roblox]]: testing which thumbnail actually performs.
- [[Short-Form Video Marketing]]: reusing the same scenes as animated clips.
- [[Atmosphere Sky Clouds and Post-Processing]]: the in-engine tools for matching the look.
- [[Lighting Mood and Time of Day]]: rim and key light choices that also work in Studio.
- [[Roblox Policies Ratings and Compliance]]: rules on misleading store art.
- [[AI Image Generation for Icons Thumbnails and Concepts]]: an alternative route and its trade-offs.
- [[Readable Text and UI Scale]]: sizing any text added to the final image.

## Connected notes
<!-- auto-links:start -->
[[Dash VFX Presentation on an R15 Rig]] · [[Thumbnail Contrast]] · [[Mesh VFX Packs Built in Blender]] · [[Blender 5 Python Gotchas for Headless Builds]] · [[Voxel and Blocky Modeling]] · [[Colour Scripts and Value Structure for Untextured Art]]
<!-- auto-links:end -->
