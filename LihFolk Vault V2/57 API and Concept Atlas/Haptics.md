---
tags: [atlas, concept, type/atlas, area/animation, area/ui]
---
# Haptics

<!-- tldr:start -->
> [!tldr] TL;DR
> - Haptics are more forgiving in absolute terms (touch is a slower sense and motors take time to spin up), but a vibration...
> - Haptics through `HapticEffect`, with an on/off and tested on real devices.
> - Rate limit. No more than about 8 to 10 haptic starts per second; at higher rates pulses smear into a constant buzz and drain...
> - Haptics through `HapticEffects` for dramatic events and UI feedback, not constant buzzing (Haptics).
>
> Cost: TL;DR ~150 tok · whole note ~620 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Haptics are more forgiving in absolute terms (touch is a slower sense and motors take time to spin up), but a vibration clearly after the sound feels like an echo. (from [[Feedback Timing - Sound Visual and Haptic Sync]])

## Key facts

- Haptics through `HapticEffect`, with an on/off and tested on real devices. ([[Captions and Audio Accessibility]])
- Rate limit. No more than about 8 to 10 haptic starts per second; at higher rates pulses smear into a constant buzz and drain batteries. ([[Feedback Timing - Sound Visual and Haptic Sync]])
- Haptics through `HapticEffects` for dramatic events and UI feedback, not constant buzzing (Haptics). ([[Console and VR Release Checklists]])
- Haptics and a short sound on pick-up and drop help a lot on phones (Feedback Timing - Sound Visual and Haptic Sync). ([[Drag-and-Drop Inventories and Sliders with UIDragDetector]])

## Mentioned in

26 notes in 13 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Gamepad and Console UX]] · [[Input - UserInputService and ContextActionService]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]

### 08 Animation
[[Camera Shake and Camera FX]] · [[Markers and Events]] · [[Snippets - Camera Shake and FX]] · [[Stance and Charge Moves]]

### 25 Physics and Vehicles
[[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]] · [[Motion Sensitivity and Camera Comfort]]

### 45 Procedural Blender Assets
[[Mesh VFX Packs Built in Blender]]

### 47 Game Feel and Juice
[[Feedback Timing - Sound Visual and Haptic Sync]] · [[Game Feel Start Here]] · [[Reward Moments and Celebrations]]

### 49 Roblox Platform Features
[[Console and VR Release Checklists]]

### 52 Core Concepts
[[Hit-Stop]]

### 56 Field Notes
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]] · [[Player QoL Start Here]]

### 60 High-Craft Game Teardowns
[[Teardown - Blade Ball]] · [[Teardown - Dandy's World]] · [[Teardown - Funky Friday]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]]

Also mentioned in (not linked): 00 Start Here

<!-- atlas:generated -->
