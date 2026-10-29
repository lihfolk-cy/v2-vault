---
tags: [modeling, voxel, characters, chibi, art-style, rarity, collectibles, unit-design, palette, silhouette, type/guide, area/modelling, level/intermediate]
---
# Voxel Chibi Heroes - Class Roster and Rarity Ladder

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Head smaller than the shoulders. Symptom: heroes read as generic blocky humans, not chibi collectibles.
> - Avoid: Every class in the same mid-tone colours.
> - Avoid: Escalating rarity by size alone. Symptom: Mythic looks like a scaled-up Common; add trim, glow points and one extra...
> - Head 40-45 % of height, face plate 8-10 voxels wide, eyes 2x2-3 with a white highlight pixel.
> - One dominant hue per class plus the shared gold trim accent.
> - Silhouette hook above the head or past the shoulders; prop 1.2-1.6x hero height, held to the side.
>
> Cost: TL;DR ~180 tok · whole note ~2.4k tok. Read more: ## 4. Class identity: one hue family, one silhouette hook · ## 5. Rarity ladder: how detail escalates · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A collectible hero roster in the chunky voxel chibi style: small soft-edged cubes, a huge block head with a pixel face, one colour family per class, an oversized signature prop, and a visible step up in detail at every rarity. It suits unit collectors, tower defense, gacha-style summons, pet-and-hero simulators and lobby showcases, where players compare many characters side by side at thumbnail size. Proportions and rigging are in [[Voxel Characters - Proportions Joints and Rigging]], colour ramps in [[Voxel Palettes - Ramps Hue Shifting and Limits]], edge and AO treatment in [[Voxel Shading - Baked AO Edges and Lighting]], export in [[Meshing Voxels for Roblox - Greedy Meshing and Export]].

Labels: **rule of thumb** (style guidance written for this vault) unless a line says otherwise.

## 1. The look in one paragraph

Each hero is about 5 to 7 studs tall, built from small voxels (roughly 0.1 to 0.15 studs) whose edges are slightly bevelled, so every cube catches a soft highlight and the model reads as a toy rather than a pixel sprite. The head is a near-cube taking 40 to 45 % of the height, with a flat face plate carrying a pixel face. The body is short and wide, legs are two stubby blocks, hands are single chunky cubes. Colour is flat per voxel with a 3-step ramp per hue; shading comes from the lighting, the bevels and contact AO, not from painted gradients.

## 2. Proportions

| Part | Share of total height | Notes |
|---|---|---|
| Head (with face plate) | 40-45 % | Wider than the shoulders; headgear adds height on top, not to this share |
| Torso | 25-30 % | Box, 1.0-1.2x head depth; belt or sash line at about 40 % of torso height |
| Legs | 20-25 % | Two blocks with a 1-voxel gap; boots 1-2 voxels wider than the shins |
| Arms | reach mid-thigh | Upper arm hidden under a shoulder cap; the hand is one oversized cube |

- Keep the head the biggest single mass even on armoured classes. Shields, wings and scythes may exceed it; helmets and hats grow upward.
- Total footprint stays within about 3 x 3 studs without the prop, so heroes line up evenly in grids and on pedestals.

## 3. The pixel face

- Face plate 8-10 voxels wide, eyes 2 voxels wide x 2-3 tall, set at 45-55 % of the plate height, 2-3 voxels apart.
- Each eye: dark base, one white highlight pixel in the upper corner, optionally one coloured iris pixel (class colour) at the bottom.
- Mouth: 1-2 voxels, darker skin tone, or hidden behind a mask, beard or visor.
- Masked or helmeted classes keep "eyes" as 2 emissive slits or squares in the class colour on a near-black visor. The face stays readable at 40 px.
- Hair or helmet frames the plate on three sides with 1-2 voxel bangs; never cover the eyes.
- The face plate sits flush with the head front and fills about 75-80 % of its width. Hair is bangs plus thin sideburns, never a solid box around a small sunken plate (that reads as a mask in a helmet).
- Highlight pixel in the upper outer corner of each eye, iris pixel in the lower inner corner. A highlight on top reads as raised brows; an iris along the bottom reads as a tear.
- Mouth as a small dark smile or line. A pink block low in the centre reads as a surprised "ooh".

## 4. Class identity: one hue family, one silhouette hook

| Class archetype | Dominant hue | Silhouette hook | Signature prop |
|---|---|---|---|
| Scout or rogue | warm orange, brown leather | bulky hood or cap | short blade, satchel |
| Frost mage | ice blue, white | tall stepped pointed hat | crystal staff, ice shard in hand |
| Ranger | yellow, teal | spiky hair, goggles | longbow taller than the body |
| Guardian or tank | royal blue, silver | horned helm | tower shield wider than the body, hammer |
| Healer | pink, white | nurse cap with halo | lantern staff, heart charm |
| Reaper or dark | violet, near-black | hood with glowing slit eyes | scythe arcing over the head |
| Sage | teal, bronze | wide-brim hat, white beard | hourglass staff, orbiting ring |
| Celestial or paladin | white, gold | crown, feathered wings | star-tipped spear |

- One dominant hue (about 60 % of the voxels), one secondary (about 25 %), skin and darks (about 10 %), accent trim (about 5 %).
- Gold or bronze trim is the shared roster accent: dotted 1-voxel trim lines on shields, hems, belts and hats tie different classes into one family.
- The silhouette hook sits above the head line or beyond the shoulder line, so each hero is recognisable as a black shape alone.
- Props are oversized (1.2-1.6x the hero's height for staffs, spears and scythes) and held off to one side, never covering the face.

## 5. Rarity ladder: how detail escalates

Players should read rarity before they read the name. Escalate a few levers per tier and keep the base body the same.

| Tier | Height | Tri budget | Trim and detail | Glow | Extras |
|---|---|---|---|---|---|
| Common | 5.0-5.2 studs | 5-7k | plain clothing, one prop | none | none |
| Uncommon | 5.2-5.6 | 5-6k | trim on one garment | none | small held effect (ice cube, spark) |
| Rare | 5.3-5.6 | 5-6.5k | trim on two items, patterned shield | 1-2 emissive pixels | goggles, horns |
| Epic | 5.5-6.0 | 6-6.5k | full trim, pattern on chest | eyes or gems emissive | halo, glowing slit eyes |
| Legendary | about 6.0 | 6.5-7k | layered robes, mixed materials | runes or gems in the class colour | orbiting ring or floating charm |
| Mythic | 6.5-7.0 | 8-9k | gold-dominant armour | soft gold glow | wings, crown, star motif |

- Height grows a little with rarity (about +30 % from Common to Mythic); the head stays the same size so higher tiers look grander, not just bigger.
- Glow is reserved: below Epic, at most 1-2 emissive pixels; at Mythic, gold emissive on a few key points only. Glow everywhere flattens the ladder.
- Tri counts depend more on surface complexity than on rarity: a cloaked Common can cost more than a sleek Rare. Budget per hero, about 9k tris at most, so a lineup of 8 stays mobile-friendly.

## 6. Building it in Roblox

- Model in a voxel editor or Blender at 1 voxel = 0.1-0.15 studs. Greedy-mesh flat areas but keep a small bevel (about 10-15 % of the voxel) on outer edges for the soft-toy highlight ([[Meshing Voxels for Roblox - Greedy Meshing and Export]]).
- Colour by vertex colour or a small palette texture (one texel per colour); keep `MeshPart.Color` white so the palette shows as authored.
- Emissive pixels: separate them into their own MeshPart with `Material = Enum.Material.Neon`, or a palette texture plus a SurfaceAppearance emissive mask. Keep them few.
- Rig as R15-compatible parts or a custom Motor6D rig ([[Voxel Characters - Proportions Joints and Rigging]]); props on their own part with a grip Attachment.
- Idle animation: a 2-voxel bob, prop sway, blink by swapping the eye part every 3-5 s. Small motions keep the toy feel.

## 7. Presenting the roster

- A lineup on a soft single-colour floor (pastel lavender or grey-blue), even spacing, all facing about 20-30 degrees toward the camera, soft key light from the front-top and a gentle contact shadow.
- Under each hero: name in bold, then rarity, height and tri count in small text. The same order everywhere teaches players the ladder.
- Rarity colours on labels, frames and pedestals must match the in-game rarity colours used by shop and summon UI.

## Common mistakes

- Avoid: Head smaller than the shoulders. Symptom: heroes read as generic blocky humans, not chibi collectibles.
- Avoid: Every class in the same mid-tone colours. Symptom: a lineup turns into grey noise at thumbnail size; give each class one dominant hue.
- Avoid: Escalating rarity by size alone. Symptom: Mythic looks like a scaled-up Common; add trim, glow points and one extra (wings, halo, ring) instead.
- Avoid: Emissive pixels on low tiers. Symptom: rarity stops reading because everything glows.
- Avoid: A small face plate sunk inside a solid hair or helmet box. Symptom: the face reads as a mask in a window; make the plate flush and wide, hair as bangs.
- Avoid: Generated stepped shapes for hats. Symptom: a tricorn or brim reads as a flat box at 40 px; hand-shape the headgear silhouette.
- Avoid: Props covering the face. Symptom: the pixel eyes, the main appeal, disappear; hold props to the side.
- Avoid: Sharp unbevelled cubes at this voxel size. Symptom: harsh aliasing and a cheap sprite look; bevel outer edges slightly.

## Checklist

- Head 40-45 % of height, face plate 8-10 voxels wide, eyes 2x2-3 with a white highlight pixel.
- One dominant hue per class plus the shared gold trim accent.
- Silhouette hook above the head or past the shoulders; prop 1.2-1.6x hero height, held to the side.
- Rarity ladder escalates trim, glow and one extra per tier; head size constant.
- About 9k tris at most per hero; vertex-colour or palette texture with `MeshPart.Color` white.
- Lineup presentation with name, rarity, height and tris in a fixed order.

<!-- related:start -->
## Related
[[Voxel and Blocky Modeling]] · [[Chibi Character Rules in Practice]] · [[Environment Art Styles]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Voxel Scale Grids and Stud Alignment]] · [[Voxel Props Environments and Modular Tiles]]
<!-- related:end -->
