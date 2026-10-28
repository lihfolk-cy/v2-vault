---
tags: [blender, chibi, cute, character, stylized]
---
# Chibi Character Rules in Practice

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Eyes above centre. Symptom: the character looks like a regular adult animal with big eyes.
> - Avoid: Solid black eyes with no highlight. Symptom: the pet reads as a stuffed toy with buttons.
> - Avoid: Anything pointing up. Symptom: combs, ears or tail plumes read as horns, so the pet looks aggressive.
> - Smooth stylised, round shape language, no neck.
> - Eyes below the middle, big, with iris depth and two catchlights.
> - Bottom-heavy silhouette; one exaggerated feature (the face).
>
> Read more (8 KB note): ## Version 2: what made the difference · ## Nuances and edge cases · ## Checklist · ## Common mistakes
<!-- tldr:end -->

![[p45_chicken_faceted_v1.png]]
![[p45_chibi_chicken.png]]

A farm chicken went through three versions: a faceted low-poly chicken ("should look way better, chibi"), a first chibi ("good, but make it better"), and a second chibi that landed. The changes between versions are a practical checklist for cute characters.

## Faceted was the wrong style for cute

The first chicken followed the faceted creature workflow (one box-modelled mass, spiky comb, flat plate wings). It read clearly as a chicken but not as cute. [[Low-Poly and Stylized Modeling]] already says it: **round shapes read friendly, triangles read dangerous**. A cute pet wants smooth stylised shading, soft curves and no sharp silhouettes.

## Version 1 chibi: the basics

- **The whole body is the head.** One big soft egg, no neck, tiny stub wings, tail tuft and feet.
- **Smooth shading** with a subdivision modifier on top of a modest base mesh.
- **Big glossy eyes** with two catchlights, pink blush discs, a small beak, a three-lobe comb.

It was cute, but bland. The render was grey because the AgX view transform desaturated it; the cowlick feather read as an antenna.

## Version 2: what made the difference

| Change | Why it works |
|---|---|
| **Eyes moved below the middle of the head** | The single strongest cue for "baby" proportions ([[Organic and Creature Modeling]] section 3); eyes above centre read as a normal adult face |
| **Brown iris crescent at the bottom of each black eye** | Gives the eye depth; pure black ovals read as buttons |
| **Two catchlights, big upper outer and small lower inner** | The classic anime eye; the lower one makes it look wet and alive |
| **Pear body, wider at the bottom, flattened seat** | Bottom-heavy reads soft and plump; a perfect sphere reads like a ball |
| **Colour gradient by height** (warm cream underneath to bright white on top) | Fake light baked into the material survives any lighting and adds volume |
| **Two-part beak** (pointed upper, tucked lower) | Reads as a small smile instead of stacked pills |
| **Tail plumes curled back, not up** | Upright plumes read as horns |
| **Staging**: grass tufts, small flowers, an egg, soft contact shadows | Props at the same scale tell the viewer how small and soft the character is |
| **Standard view transform** instead of AgX for pastel art | Keeps the saturated pastels |

## Proportion numbers used

Rule of thumb from these builds: body about 4.2 wide and 4.5 tall; eyes at about 0.5 of body height, about 0.8 wide apart from centre each, about 0.45 of the body width tall; feet visible but no taller than 0.15 of the body; comb about 0.4 of the body width.

## Budget note

**Measured in these builds:** the second chibi was about 14,000 base triangles before the subdivision modifier, which is high for a Roblox pet. For game use, keep the subdivision off, decimate the body to a few thousand triangles (smooth shading hides it) and keep the eyes and catchlights as separate small meshes or as a face texture. See [[Retopology and Decimation]] and [[Art Budgets - Triangles Draw Calls Memory]].

## Checklist

- [ ] Smooth stylised, round shape language, no neck.
- [ ] Eyes below the middle, big, with iris depth and two catchlights.
- [ ] Bottom-heavy silhouette; one exaggerated feature (the face).
- [ ] Gradient colour by height; blush on the cheeks.
- [ ] Tiny limbs; nothing pointing up that could read as a horn.
- [ ] Rendered with a view transform that keeps saturation; staged with scale props.

Related: [[Procedural Blender Assets Start Here]], [[Hand-Painted and Stylized Texturing]].

## Nuances and edge cases

1. **Cute in a render is not cute in a game camera.** The render shows the chicken at eye level, close, with depth of field. In most Roblox games a pet sits behind the player and is seen from above and behind, at 10 to 20 studs, often on a phone. From above, the eyes and blush that carry the cuteness are partly hidden by the top of the head. Check the model from the real follow-camera angle and, if needed, tilt the face slightly upward or push the eyes a little further forward.
2. **Smooth shading needs enough silhouette edges.** Decimating 14,000 triangles to a few thousand works because smooth shading hides flat faces in the interior. It does not hide the outline: a 12-sided silhouette on a round body looks faceted against the sky. Spend triangles on the silhouette loops and save them in the flat belly and back.
3. **Eyes as meshes versus a face texture.** Separate eye meshes stay crisp at any distance and can blink by scaling, but they are extra instances per pet. A face texture is one instance but blurs when close and costs texture memory. For a game with one pet per player, meshes are fine. For a game where players carry several pets each and 30 players share a server, a face texture keeps instance counts down (rule of thumb).
4. **Pastels and lighting.** The gradient-by-height material survives most lighting, but bright pastels can blow out to white under strong sun with bloom, and turn grey in dark zones. Test the pet in the brightest and darkest zone of the game, not only in the default skybox.
5. **Scale against avatars.** Cuteness depends on size relative to the player. A chibi chicken that fills the screen next to a small avatar reads as a monster. Player body scales vary, so pick a pet size that still reads small next to the smallest common avatar and does not hide the largest.
6. **Rarity tiers want the same rules, not new styles.** A shop with common to legendary pets tempts artists to make higher tiers spikier and darker. That can break the cute language. Express rarity with colour, glow, accessories and particles while keeping the round base shape.
7. **Animation exaggerates proportions.** A big head on a tiny body has a high centre of mass in animation; hops and idle bobs look heavier. Keep idle motion small and quick, and use squash and stretch on the whole body instead of moving tiny limbs.

## Common mistakes

1. **Eyes above centre.** Symptom: the character looks like a regular adult animal with big eyes. Fix: move the eyes below the middle of the head.
2. **Solid black eyes with no highlight.** Symptom: the pet reads as a stuffed toy with buttons. Fix: add the iris crescent and two catchlights.
3. **Anything pointing up.** Symptom: combs, ears or tail plumes read as horns, so the pet looks aggressive. Fix: curl them back or round them off.
4. **Shipping the subdivided mesh.** Symptom: one pet is 14,000 triangles; with several per player the scene budget is gone. Fix: decimate with the modifier off, as noted above.
5. **Judging colours under the wrong view transform.** Symptom: the team "fixes" colours that were never wrong. Fix: preview pastel art under Standard.
6. **No staging props in previews.** Symptom: feedback says it "looks big" or "looks off" without a clear reason. Fix: stage with grass, flowers or an egg at the right scale.

## Related decisions

- [[Posing and Silhouettes]]: the silhouette rules that make round shapes read friendly.
- [[Squash Stretch and Anticipation in UI and Characters]]: animating a body that is mostly head.
- [[Idle Breathing and Secondary Motion]]: idle loops that keep a pet alive without big limb motion.
- [[Pet Hatching and Following End to End]]: the system these pets go into, including follow distance.
- [[Avatar Body Types and Scale in Gameplay]]: sizing pets against varied avatars.
- [[Mesh Optimization for Mobile]]: decimating while keeping the silhouette.
- [[Facial Animation and Dynamic Heads]]: options for blinking and expressions.
- [[Rarity Ladders and Drop Pacing Math]]: how many tiers the art has to differentiate.
- [[Thumbnails Icons and Store Page]]: presenting cute characters in icons and thumbnails.

## Connected notes
<!-- auto-links:start -->
[[Matching a Concept Sheet - Boss Creature Case Study]] · [[Voxel and Blocky Modeling]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Lighting Untextured Art in Roblox]] · [[Shape Language and Silhouette Testing]]
<!-- auto-links:end -->
