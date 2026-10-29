---
tags: [vfx, readability, value, palette, contrast, clutter, smoke, flash, light, review, muddy, washed-out, lihfolk, type/guide, area/vfx, level/intermediate]
verified: 2026-10-29
---
# VFX Readability and Value - Lessons from Blind Reviews

<!-- tldr:start -->
> [!tldr] TL;DR
> - Effect looks muddy: Grey or desaturated dark layer -> Saturated blue-black / deep element ink, never grey
> - Effect looks flat or monochrome: No dark value layer, one hue only -> Deep ink layer + thin white-hot core + one accent hue
> - Effect looks washed out or white: Wide white body, many additive layers -> White only as a thin core; fewer bright layers
> - Every frame has dark ink, element body, thin white core and at most one accent hue
> - Dark ink saturated (no grey)
> - No two repeats identical; later layers shorter; stack thin
>
> Cost: TL;DR ~180 tok · whole note ~2.5k tok. Read more: ## 1. Value first: three layers in every frame · ## 2. Clutter: repeats must be distinct · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Rules that apply to **any** effect (fire, ice, void, lightning, holy, any weapon, any style), distilled from what blind reviewers penalised when scoring LihFolk V2 effects: a 3-spin sword attack (v1 VFX 8.1), void impact and orb one-shots matched to owner reference images, and the slash and ice presets. The specific recipes are in [[Slash VFX Recipes - Crescent and Ring]] and [[Ice Ball Cast to Explosion - Approved Recipe]]; the general design method is [[VFX Design Playbook]]. **Measured** marks review results; **Rule of thumb** marks judgement.

If an effect "looks muddy", "looks washed out", "is a blob", "is too busy" or "tints the character", one of the sections below is almost always the cause.

## 1. Value first: three layers in every frame

Reviewers judge value structure before colour. A near-monochrome effect (every layer a shade of one hue) was the single biggest deduction on the spin attack (**Measured**).

Every frame needs:

1. **A dark value layer ("ink").** A deep, saturated shade of the element: navy for ice/teal, oxblood for fire, blue-black for void, deep plum for violet. It sits behind or around the bright body and gives the shape an edge.
2. **A white-hot core.** Thin, at the leading edge or the centre of the brightest moment. White only as a thin core; a wide white body flattens everything.
3. **The element body** in between, saturated.
4. **One contrasting accent hue**, used sparingly (sparks, a rim, embers): gold on blue, cyan on fire, magenta on teal. One accent, not three.

Dark ink must stay **saturated**: blue-black that thins to blue, never grey. Grey ink reads as dirt and is what reviewers call "muddy" (**Measured**, void impact). The same applies to smoke under fire: warm dark brown-red, not neutral grey.

White on white fails too: white shards or sparks over a white or pale floor vanish. Give white bits a thin dark outline or a faint element tint (**Measured**).

## 2. Clutter: repeats must be distinct

Stacking the same element again and again reads as clutter, not power.

- **No identical repeats.** Three identical rings, one per spin, were called "stamped" and "busy" (**Measured**). Each repeat must differ and **escalate**: bigger, brighter, faster, a different tilt or a new layer. See [[Escalation and Grandeur Without Clutter]].
- **Thinner stacks.** Fewer simultaneous layers, each with a clear job. Later layers live shorter than earlier ones, so the screen clears as the move builds.
- **Ground rings expand and fade**: they grow from small to large while losing opacity, eased out. A ring that pops in at full size and full opacity reads as a stamp.
- **Sparks stay in frame and have a direction.** Sparks drifting slowly off-frame long after the hit read as stray noise. Short lives, high drag, and a direction (along the swing, forward from the impact).

## 3. Smoke and dust need texture and form

Soft, flat, round smoke blobs were penalised on every review that had them (**Measured**).

- Use **textured puffs** (noise, cauliflower edges), not a soft disc.
- **Light tops, darker cores**: smoke lit from above has a bright top edge and a darker, denser centre. A single flat tint looks pasted on.
- **Motion**: smoke rolls outward, rises and slows (drag), with a little rotation. Static blobs that only fade read as stickers.
- **Variety and short life**: identical static puffs lingering about 1 s read as flat discs (**Measured**, spin attack v2.1). Vary size and drift per puff and fade fast.

## 4. Never tint or hide the character

Big translucent layers in front of the body (a wide additive wash, a sphere, a vortex sheet) colour the character; reviewers mark "character tinted green/blue" as a readability failure (**Measured**).

Fix it **in the effect**, never with a preview-only clean pass (the preview must match the game; see [[VFX Previews in Blender for Roblox - Colour and Framing]]):

- **Spawn large layers ahead of the body** (in front of the weapon, at the crescent head), not centred on the torso.
- **Rims, not washes.** A vortex or shell around the character should be a bright rim with a transparent middle, so the body shows through untinted.
- **Keep glow parts and effect lights off the character** (section 6).

## 5. The flash: small, short, late, ahead

The hit flash was "too big and on the body" on the first spin attack review (**Measured**). Rules that held:

- **Small**: smaller than the effect body (about 0.6x of the explosion or crescent).
- **Short**: 1-2 frames at 30 fps.
- **One frame after contact**, so the contact pose or landing is seen first (same rule as the ice ball impact).
- **Placed at the blade or crescent head, ahead of the body**, never centred on the character.

## 6. Lights near the body colour the body

An effect `PointLight` placed at blade or floor height tinted the character's shins green (**Measured**). Effect lights colour whatever is nearest.

- Place effect lights **above and behind** the effect (or ahead of it, away from the character), at **low power** (Brightness about 1-2, short Range).
- One light per effect is usually enough (the shipped budget is 1 per preset, 2 per kit).
- If the character must be lit by the effect (a charge in the hands), make it intentional and brief.

## 7. Light shafts and streaks

- **Light shafts read as flat panels** unless the texture is additive and tapered: falloff along the length **and** to both edges, arranged **radially from the source**. If you cannot make them read that way, cut them; a missing shaft costs nothing, a flat panel costs points (**Measured**).
- **Hairline streaks need low Beam brightness.** Bloom fattens bright thin Beams into bars; keep `Brightness` low and let `LightEmission` and the texture do the work (**Measured**, void impact).
- **Ribbon bands** read thicker and more saturated with **lower body brightness** and white only as a thin core line (**Measured**).

## 8. Dark-element effects (void, shadow, abyss)

Dark elements break the additive rules because black does not add. What matched the owner's references (**Measured**):

- **Black orb**: near-black body plus a bright rim **only at the silhouette**. A slightly larger shell (scale about 1.02, transparency about 0.45) gives the rim; the body itself never glows.
- **Ink** stays blue-black thinning to blue, not grey (section 1).
- Bright accents (rim, cracks, sparks) carry all the light; the body carries the shape.
- Test in dark zones: a near-black effect on a dark floor disappears ([[VFX Design Playbook]] section 4).

## 9. Direction: away from the caster

- **Release bursts** (a throw, a cast, a shot) are biased **forward**, away from the caster's torso. A burst centred on the hand sprays back over the body.
- Slash debris and ground marks are biased along the swing and forward ([[Slash VFX Recipes - Crescent and Ring]]).
- Explosions, auras and charges may be radial.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Effect looks muddy | Grey or desaturated dark layer | Saturated blue-black / deep element ink, never grey |
| Effect looks flat or monochrome | No dark value layer, one hue only | Deep ink layer + thin white-hot core + one accent hue |
| Effect looks washed out or white | Wide white body, many additive layers | White only as a thin core; fewer bright layers |
| Repeats look stamped and busy | Identical rings or crescents per beat | Each repeat distinct and escalating; later layers shorter |
| Smoke looks like stickers | Soft flat round blobs | Textured puffs, light tops, darker cores, rolling motion |
| Ground rings pop | Ring appears at full size and opacity | Expand from small and fade while growing, ease out |
| Stray sparks | Long lives, low drag, no direction | Short lives, high drag, directional, stay in frame |
| Character tinted | Large translucent layer or light in front of the body | Spawn large layers ahead; rims not washes; lights above/behind at low power |
| Flash hides the hit | Big flash on the contact frame, on the body | Small, 1-2 frames, 1 frame late, at the blade head |
| Light shafts look like panels | Untextured or untapered quads | Additive tapered texture, falloff along and across, radial; else cut |
| Thin streaks look like bars | High Beam brightness under bloom | Low Beam brightness |
| White shards vanish | White on a white floor | Thin dark outline or element tint |
| Burst sprays over the caster | Release burst centred on the hand | Bias forward, away from the torso |

## Checklist

- [ ] Every frame has dark ink, element body, thin white core and at most one accent hue
- [ ] Dark ink saturated (no grey)
- [ ] No two repeats identical; later layers shorter; stack thin
- [ ] Ground rings expand and fade; sparks directional and short
- [ ] Smoke textured with light tops and darker cores, moving
- [ ] Nothing large and translucent in front of the body; effect lights above/behind at low power
- [ ] Flash small, 1-2 frames, 1 frame after contact, at the blade head
- [ ] Light shafts tapered and radial, or cut
- [ ] Release bursts biased forward; slashes frontal
- [ ] Judged in a preview that matches the game, at game distance

## See also

- [[VFX Design Playbook]]
- [[Escalation and Grandeur Without Clutter]]
- [[Slash VFX Recipes - Crescent and Ring]]
- [[Ice Ball Cast to Explosion - Approved Recipe]]
- [[VFX Previews in Blender for Roblox - Colour and Framing]]
- [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]]
- [[Light Sources and Shadows]]
- [[Blind Review Scores - Noise, Panels and Shipping the Best Version]]

<!-- related:start -->
## Related
[[Particle Emitters In Depth]] · [[Stylized Lighting Recipes]] · [[Beams and Trails]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Highlights and Selection Effects]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[VFX Performance Budgets and Culling]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]
<!-- related:end -->
