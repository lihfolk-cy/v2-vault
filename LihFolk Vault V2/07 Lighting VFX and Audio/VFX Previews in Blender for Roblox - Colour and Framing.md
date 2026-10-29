---
tags: [vfx, blender, preview, color, srgb, linear, slash, explosion, review, lihfolk, type/guide, area/vfx, level/advanced]
---
# VFX Previews in Blender for Roblox - Colour and Framing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Feeding Roblox `Color3` sRGB numbers into Blender as linear values.
> - Avoid: Rendering with the AgX or Filmic view transform.
> - Avoid: Close-up cinematic framing instead of the game camera.
> - sRGB -> linear conversion on every colour input
> - View transform set to Standard
> - Camera at game distance; floor at ground height; neutral stage
>
> Cost: TL;DR ~130 tok · whole note ~1.4k tok. Read more: ## 1. Convert Roblox sRGB colours to linear · ## 3. Slashes stay frontal, explosions are radial · ## Common mistakes · ## Checklist
<!-- tldr:end -->

verified: 2026-10-28

Rendering Roblox VFX previews outside Studio (for example in Blender, so an AI reviewer can score frame sequences without opening Studio) is fast and scriptable, but the preview has to show what Roblox will show. Two things went wrong repeatedly in the LihFolk V2 VFX work: colours came out washed out, and attack effects were framed or shaped in ways that read wrong in game. **Measured** marks results from that work.

## 1. Convert Roblox sRGB colours to linear

Roblox `Color3` values in effect scripts (`ParticleEmitter.Color`, `Beam.Color`, neon part colours) are **sRGB** display values. Blender's shader inputs (emission colour, RGB nodes, material base colour) expect **scene-linear** values. Typing the sRGB numbers straight into a Blender emitter applies gamma twice in effect: every colour comes out pale and pastel.

**Measured:** the first two blind reviews of a ring slash and a double crescent scored down colour and value ("pastel body, no dark smear") because the Blender emulator passed sRGB tints as linear. The ledger credits the conversion alone with +1.4 points on the ring and +1.8 on the crescent, a fix to the preview, not to the effect.

Convert each channel `c` (0-1) before use:

- `c <= 0.04045`: `c / 12.92`
- otherwise: `((c + 0.055) / 1.055) ^ 2.4`

Also:

- Set the view transform to **Standard**, not AgX or Filmic, so the output pixel equals the sRGB colour you meant. AgX desaturates bright saturated colours, which is exactly what VFX use.
- Roblox `LightEmission` and `Brightness` are not physical units. Calibrate one reference effect side by side with a Studio capture and reuse the multipliers.
- Dark contrast layers ("ink") must render over the inner half of the bright body, not hidden underneath it, or the reviewer reports "no dark layer".

## 2. Frame like the game camera

- Render from the game's third-person camera distance and height, not a close cinematic angle. Readability at game distance carries the most weight in the VFX rubric.
- Put the preview floor exactly at the character's ground height. **Measured:** a floor 0.16 studs too low (2.84 instead of 3.0) buried every ground decal in the draft previews.
- Keep the camera following the root on dashes, or the effect leaves frame.
- Show a neutral stage. A dark ink cone on a dark stage was invisible to the reviewer.

## 3. Slashes stay frontal, explosions are radial

Shape language must match what the player expects from an attack.

- **Slash arcs stay within about +-100 degrees of the character's LookVector.** Author arcs of 120-200 degrees centred on the facing direction, from the weapon side across the front. No 360-degree rings or spins for slashes: they read as an attack behind the character.
- Debris, sparks and ground marks for slashes and thrusts are biased forward.
- No weapon trail on stabs or spins; a trail streaks behind the back.
- **Explosions, auras and charge-ups are radial**, and dashes follow the path. Radial is correct for them.

**Measured:** a 360-degree ring slash reached 10.0 on the original rubric and was then retired when the project added a frontal criterion (X6). A frontal sweep scored 10.0 under the new rubric.

## 4. Motion details reviewers notice

- Erosion front-loaded (square-root schedule) reads snappier than linear fades.
- Very short holds (0.03 s rather than 0.05 s) avoid a "frozen" frame.
- Drift the arc as it fades (14 -> 30 degrees on the crescent) so it does not hang static.
- Hit flashes must sit on the arc, and late square sparks should not linger as dots.

## 5. Preview is not the shipping effect

The Blender emulator only approximates Roblox. Before shipping, capture the real effect in Studio once and compare it with the preview frame by frame. If they disagree, fix the emulator first, then re-review.

## Common mistakes

- Feeding Roblox `Color3` sRGB numbers into Blender as linear values.
- Rendering with the AgX or Filmic view transform.
- Close-up cinematic framing instead of the game camera.
- A preview floor that does not match character ground height.
- 360-degree slash rings or trails behind the back.
- Treating a reviewer's colour complaint as an art problem before checking the preview pipeline.

## Checklist

- [ ] sRGB -> linear conversion on every colour input
- [ ] View transform set to Standard
- [ ] Camera at game distance; floor at ground height; neutral stage
- [ ] Slash arcs within +-100 degrees of LookVector; explosions radial
- [ ] Ink layer visible over the body
- [ ] One side-by-side check against a Studio capture

## See also

- [[Slash VFX Recipes - Crescent and Ring]]
- [[VFX Design Playbook]]
- [[Mesh VFX Packs Built in Blender]]
- [[VFX Timing with Animation]]

## Connected notes

[[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Particle Emitters In Depth]]

<!-- related:start -->
## Related
[[Ice Ball Cast to Explosion - Approved Recipe]] · [[Case Study - Building LihFolk V2 with AI Agents]] · [[Beams and Trails]] · [[Light Sources and Shadows]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[VFX Performance Budgets and Culling]] · [[Gore Policy and Kid-Friendly Hit Feedback]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]
<!-- related:end -->
