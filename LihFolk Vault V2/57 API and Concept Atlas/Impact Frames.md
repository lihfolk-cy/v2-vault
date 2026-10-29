---
tags: [atlas, concept, type/atlas, area/animation, area/vfx]
---
# Impact Frames

<!-- tldr:start -->
> [!tldr] TL;DR
> - Impact frames are cheap in Roblox: a full-screen `Frame` (white, or an `ImageLabel` with a negative-looking texture) shown for...
> - Impact frames play inside the hit-stop: 1 or 2 frames of a high-contrast or negative image, at 1/30 s per frame (at least one...
> - Anything that covers a large part of the screen with a sudden brightness change goes through the gate: impact frames, white...
> - Impact frames, screen-wide white flashes, and strobing rarity reveals are the risky effects in Roblox games.
>
> Cost: TL;DR ~170 tok · whole note ~540 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Impact frames are cheap in Roblox: a full-screen `Frame` (white, or an `ImageLabel` with a negative-looking texture) shown for one or two frames, or a `ColorCorrectionEffect` with high contrast and negative saturation toggled on and off. (from [[Camera Shake and Camera FX]])

## Key facts

- Impact frames play inside the hit-stop: 1 or 2 frames of a high-contrast or negative image, at 1/30 s per frame (at least one rendered frame). ([[Camera Shake and Camera FX]])
- Anything that covers a large part of the screen with a sudden brightness change goes through the gate: impact frames, white flashes, lightning on the sky, full-screen colour inversions, strobe reveals. ([[Motion Sensitivity and Camera Comfort]])
- Impact frames, screen-wide white flashes, and strobing rarity reveals are the risky effects in Roblox games. ([[Accessibility]])
- Use `Squash` sparingly for impact frames. ([[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]])

## Mentioned in

19 notes in 8 sections. The 19 most relevant are linked:

### 05 UI and UX
[[Accessibility]]

### 07 Lighting VFX and Audio
[[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Slash VFX Recipes - Crescent and Ring]]

### 08 Animation
[[Camera Shake and Camera FX]] · [[Cinematic Ultimates]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Keyframes, Easing and Interpolation]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Snippets - Camera Shake and FX]] · [[Spec-Driven Move Authoring]] · [[Weapon Swing Design]]

### 42 Accessibility and Inclusive Design
[[Motion Sensitivity and Camera Comfort]]

### 47 Game Feel and Juice
[[Game Feel Start Here]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Squash Stretch and Anticipation in UI and Characters]]

### 51 2D Game Development
[[Sprite Sheets and Frame Animation with ImageRectOffset]]

### 52 Core Concepts
[[Hit-Stop]]

### 58 Player QoL and Game Tweaks
[[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]

<!-- atlas:generated -->
