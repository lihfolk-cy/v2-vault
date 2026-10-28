---
tags: [blender, weapons, sword, stylized, materials]
---
# Stylised Weapons From a Concept

A painted concept showed a wide curved falchion: a black blade full of stars, a glowing purple edge, magenta and green flame licks off the spine, an ornate silver guard with a spiked hook quillon, a purple wrapped grip and a silver pommel. The first build was rejected as "looks really bad". The second, rebuilt from proper forged forms, worked. The difference is the lesson.

## Why the first version looked bad

| Part | First build | Problem |
|---|---|---|
| Edge glow | Two glowing tubes along the edge and spine | Thick neon tubes read as a lightsaber outline, not a sharpened edge |
| Flames | Thin tubes with a wobble | Read as lightning or grass, never as flame |
| Guard | A squashed ball plus thin tube "hooks" | Shapeless; a hook made of a tube looks like wire |
| Grip | A cylinder with a spiral tube wrapped round | Looks like a spring on a stick |
| Blade flat | Dark material lit by bright lights | Rendered lavender; never read as void-black |

Tubes and balls are the fastest things to script, which is exactly why they creep in. They are almost never the right shape for a crafted object.

## What the rebuild did

1. **Bevelled cross-section with the glow as the bevel.** Each blade station is a 7-vertex loop: spine chamfer, flat, flat, edge, flat, flat, spine chamfer. Faces between the flat vertices get the void material; faces between flat and edge get a glow material. The glow brightens toward the edge through a per-vertex attribute (0 at the flat, 1 at the edge) read by an Attribute node. Now the glowing band is the ground bevel, exactly as a smith would sharpen it.
2. **Clipped point from the profile, not from a taper.** Two profile functions, `edge_z(s)` and `spine_z(s)`, let the back curve down into the point near the tip instead of rounding the end into a paddle.
3. **Forged parts as extruded 2D silhouettes with bevels.** The guard hub is a shield outline extruded and bevelled; the hook quillon is a tapering stroke outline with thorns inserted along its outer edge, extruded and bevelled; filigree spirals sit on the faces. Flat stock with bevelled edges is how real guards are made, so it reads as metal.
4. **Flames as filled strokes.** A curved centreline, a width that tapers from root to tip, the outline offset on both sides, filled, extruded thinly; a narrower lighter core stroke on top; side tongues peeling off. Filled tapering shapes read as flame.
5. **Moulded strap grip.** One cylinder whose radius follows a helix (flat-topped strap, sharp seam), swelling slightly in the middle: one mesh, reads as wrapped leather.
6. **Real reflections for metal.** A studio HDRI from the vault's CC0 library ([[CC0 Texture and HDRI Library]]) lights the scene and is visible in reflections, while the camera sees a dark backdrop through a Light Path "Is Camera Ray" mix in the world shader.
7. **Void black needs a near-zero albedo.** A base colour of about 0.001 to 0.025 with low roughness and some specular reads black with reflections; anything brighter turns lavender under strong lights and bloom.

**Measured in these builds:** about 25,000 triangles, mostly in the moulded grip (160 rings by 40 segments). That is over the 20,000 per-mesh limit for the grip alone if merged; drop the grip to 60 rings for game use.

## A note on using someone else's concept

The reference was signed by an artist. A private preview is fine; shipping their design in a game needs their permission or a design changed enough to be your own. Ask before you build it into the game.

## Checklist for stylised weapons

- [ ] Blade from a cross-section loop, with the bevel as its own material band.
- [ ] Point shape from the profile curves.
- [ ] Guard and pommel from extruded, bevelled silhouettes; ornament as relief, not floating tubes.
- [ ] Wraps as a modulated surface, not a spring.
- [ ] Glow on edges and runes only; the rest stays physically lit.
- [ ] Reflective metals under an HDRI.
- [ ] Rig on the vault's Weapon_Sword skeleton (Handle as root) when it goes to the game ([[Skeleton Library]]).

Related: [[Modeling Weapons and Props]], [[Dramatic Showcase Renders in Eevee]], [[Procedural Blender Assets Start Here]].

## Nuances and edge cases

1. **The render material does not travel.** The void blade uses a per-vertex attribute, Attribute nodes, an HDRI for reflections and near-zero albedo. None of that is a Roblox material. In game, the same look has to be rebuilt from a SurfaceAppearance (colour, normal, roughness, metalness maps), Neon parts for the glow band, and the scene's own lighting and environment reflections. Bake the vertex-attribute glow into a texture mask before export, and expect the edge glow to be a separate Neon mesh or an emissive-looking texture rather than real emission.
2. **Glow on a thin edge vanishes at distance.** A beautifully bevelled glowing edge is a few pixels wide on a phone screen at third-person distance. Players see the overall colour and silhouette of the weapon, not the bevel. If the glow is the identity of the weapon, make the band wider than "realistic", or add a subtle trail when swung.
3. **Per-mesh triangle limit versus total budget.** Roblox meshes are limited to 20,000 triangles each (Roblox docs, as of October 2026). The measured 25,000-triangle sword passes only if it is split into several meshes, but passing the limit is not the target. A held weapon is visible next to many other players' weapons; a few thousand triangles for a hero weapon and well under that for common ones is a sane range (rule of thumb).
4. **Many weapons, one pipeline.** A game with dozens of weapons cannot afford a bespoke script per sword. The rebuild's ideas (cross-section loops, profile functions, extruded silhouettes) scale best when they become a parameterised generator: one script, a table of profiles and colours per weapon. The first weapon is slow; the twentieth should be a data change.
5. **Rarity readability.** Showy flames and spikes for a top-tier weapon are good, but if every tier has them, the top tier stops standing out. Reserve flames, glow and ornate guards for the highest tiers and keep low tiers plain metal with clean silhouettes.
6. **Grip position and hand pose.** A curved falchion with a hook quillon changes where the hand can sit. If the Handle bone is placed where a straight sword's grip would be, the hand clips through the guard in swing animations. Place the Handle from the actual grip mesh and test with the real hold animation.
7. **Ownership of the concept.** The note says it plainly: a signed concept belongs to its artist. That applies to fan art of other games too. Getting written permission, or changing the design enough that it is yours, protects the game from takedowns later when it is too late to redraw.

## Common mistakes

1. **Tubes and balls for crafted parts.** Symptom: guards look like wire, grips look like springs. Fix: extrude bevelled 2D silhouettes and model wraps as one modulated surface.
2. **Glow outlines instead of glow bevels.** Symptom: the blade reads as a lightsaber outline. Fix: make the glow the sharpened bevel band.
3. **Black that is not black.** Symptom: a "void" blade renders lavender. Fix: albedo near zero, low roughness, some specular, reflections from an environment.
4. **Merging everything into one mesh for export.** Symptom: over the per-mesh limit, or no way to make the glow Neon. Fix: separate blade, glow band, guard and grip; merge only what shares a material.
5. **Dense grip geometry.** Symptom: most triangles sit in the part covered by the hand. Fix: drop rings, as noted above, and spend triangles on the blade silhouette.
6. **No swing test.** Symptom: the weapon looks great static but clips the arm or the floor in combos. Fix: test with the real attack animations before final detail.
7. **Mismatched scale across a catalogue.** Symptom: some swords dwarf the player while others look like knives. Fix: fix a length range per weapon class and check against an avatar.

## Related decisions

- [[Custom Rigs - Weapons and Props]]: turning the model into a rigged weapon with a Handle root.
- [[Weapon Swing Design]]: how the blade shape changes swing arcs and trails.
- [[Equip Draw and Flourish Systems]]: where a showpiece weapon gets its moment.
- [[SurfaceAppearance PBR Workflow]]: rebuilding the render look in Roblox materials.
- [[Mesh Optimization for Mobile]]: cutting the grip and guard down for phones.
- [[Data and Config Pipeline - Spreadsheets to Game]]: driving a weapon generator from one table of profiles instead of one-off builds.
- [[Rarity Ladders and Drop Pacing Math]]: matching visual intensity to rarity tier.
- [[Legal Basics - IP Licenses and Assets]]: what you need before shipping someone else's design.
- [[Beams and Trails]]: swing trails that carry the edge glow at distance.

## Connected notes
<!-- auto-links:start -->
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Mesh VFX Packs Built in Blender]] · [[Hand-Painted and Stylized Texturing]] · [[Stylised vs Realistic Material Pipelines]] · [[Texturing and PBR Baking]] · [[Voxel and Blocky Modeling]]
<!-- auto-links:end -->
