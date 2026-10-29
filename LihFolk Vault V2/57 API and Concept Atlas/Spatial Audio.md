---
tags: [atlas, concept, type/atlas, area/vfx, area/world]
---
# Spatial Audio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Spatial audio decides where a sound seems to be and how loud it is from here.
> - Ask for dry sounds. Generators like to add reverb and tails; Roblox adds space with its own effects and emitters, and baked...
> - Sound captions come from your sound play helper.
> - Limit simultaneously audible remote cars to the nearest 4 to 6 (Rule of thumb; voice limits in Spatial Audio and Mixing).
>
> Cost: TL;DR ~140 tok · whole note ~700 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Spatial audio decides where a sound seems to be and how loud it is from here. (from [[Spatial Audio and Mixing]])

## Key facts

- Ask for dry sounds. Generators like to add reverb and tails; Roblox adds space with its own effects and emitters, and baked reverb clashes with your environment (Spatial Audio and Mixing). ([[AI Audio - Voice Music and SFX]])
- Sound captions come from your sound play helper. Every gameplay sound should already go through one function (for throttling and pooling, see Spatial Audio and Mixing). ([[Captions and Audio Accessibility]])
- Limit simultaneously audible remote cars to the nearest 4 to 6 (Rule of thumb; voice limits in Spatial Audio and Mixing). ([[Engine and Tyre Audio Driven by RPM and Slip]])
- Duck the weather bed slightly when combat sounds play so cues stay audible (Spatial Audio and Mixing, Captions and Audio Accessibility). ([[Weather That Changes Gameplay - Grip, Visibility and Hearing]])

## Mentioned in

30 notes in 15 sections. The 25 most relevant are linked:

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Game Feel and Juice]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Music and Adaptive Audio]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Sound Design for Games]] · [[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]]

### 08 Animation
[[Cameras and Cutscenes]]

### 09 Gameplay Systems
[[Downed, Revive and Bleed-Out States]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]]

### 10 Game Design and Genres
[[Genre Playbook - Horror and Story]] · [[Genre Playbook - Social Deduction and Murder Mystery]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 17 Pipelines
[[Audio Pipeline]]

### 25 Physics and Vehicles
[[Engine, Gearbox and Torque Curve Model for Arcade Cars]]

### 26 Community and Moderation
[[Voice Chat and Safety Features]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 43 Genre Systems End to End
[[Horror Monster Chase AI End to End]]

### 46 Resource Library
[[Official Docs - Audio]]

### 58 Player QoL and Game Tweaks
[[Audio Mixer Settings with SoundGroups]]

Also mentioned in (not linked): 00 Start Here · Accessibility Start Here · SoundService - Engine Reference Card · Terrain Deep Dive - Materials Water and Performance · Zone and Biome Art Direction

<!-- atlas:generated -->
