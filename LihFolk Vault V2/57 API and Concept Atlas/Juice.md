---
tags: [atlas, concept, type/atlas, area/animation, area/vfx]
---
# Juice

<!-- tldr:start -->
> [!tldr] TL;DR
> - Juice scales with distance. Other players' small juice only within about 220 studs of your camera (reference project).
> - Juice on whiffs: Feedback scheduled at click time -> Fire on the hit marker.
> - Each juice effect classified by cost bucket and tagged `info` or `decor`.
> - A juice module once triggered hit-stop and flashes twice per hit for exactly this reason.
>
> Cost: TL;DR ~130 tok · whole note ~1.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Juice scales with distance. Other players' small juice only within about 220 studs of your camera (reference project). (from [[Game Feel and Juice]])

Juice work labelled in the MicroProfiler; worst case tested on the weakest phone after 15 minutes. (from [[Juice on a Budget - Mobile and Low-End]])

## Key facts

- Juice on whiffs: Feedback scheduled at click time -> Fire on the hit marker. ([[Game Feel and Juice]])
- Each juice effect classified by cost bucket and tagged `info` or `decor`. ([[Juice on a Budget - Mobile and Low-End]])
- A juice module once triggered hit-stop and flashes twice per hit for exactly this reason. ([[Ability Kits Architecture]])
- Game Feel and Juice: the feedback stack, UI juice code, combat and audio juice, when juice becomes noise. ([[Game Feel Start Here]])

## Mentioned in

86 notes in 26 sections. The 25 most relevant are linked:

### 05 UI and UX
[[HUD Design]] · [[Notification and Toast Systems]] · [[UI Motion Language and Timing]]

### 07 Lighting VFX and Audio
[[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Game Feel and Juice]] · [[Gore Policy and Kid-Friendly Hit Feedback]] · [[Particle Emitters In Depth]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[VFX Design Playbook]] · [[VFX Performance Budgets and Culling]]

### 08 Animation
[[Ability Kits Architecture]] · [[Lua Keyframe Player]] · [[VFX Timing with Animation]]

### 10 Game Design and Genres
[[Genre Playbook - Combat and RPG]] · [[Genre Playbook - RNG and Collection Games]]

### 25 Physics and Vehicles
[[Destruction and Fracture]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]]

### 40 Game Math
[[Interpolation Easing and Curves Math]]

### 42 Accessibility and Inclusive Design
[[Motion Sensitivity and Camera Comfort]]

### 47 Game Feel and Juice
[[Game Feel Start Here]] · [[Juice on a Budget - Mobile and Low-End]] · [[Reward Moments and Celebrations]]

### 58 Player QoL and Game Tweaks
[[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]

### 59 Viral and Trend Game Teardowns
[[Teardown - Tap Simulator REBORN]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): 000 Home · Accessibility Start Here · Atmosphere Sky Clouds and Post-Processing · Badges and Achievement Design · Baked Clip Stubs and Archiving · Camera Shake and Camera FX · Camera Systems · Case Study - Abilities That Only Worked in Studio · Combat Combo Systems · Combat Sound Design and Feedback · Cookbook - UI · Core Loops and Session Design · Currency Architecture - Soft Hard and Event Currencies · Custom Character Controllers · Custom Locomotion Controller Design · Economies and Currencies · Frame Budget · Game Math Start Here · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Shooters FPS and TPS · Genre Playbook - Simulators · Glossary · Graphics and Performance Toggles for Low-End Devices · Hand-Painted and Stylized Texturing · Highlights and Selection Effects · Hit Reactions Stagger and Hit-Stop · Hit-Stop and Screen Shake Tuning by Numbers · Hitboxes and Hit Detection · Locomotion Systems · Melee Combat System End to End · Mesh VFX Packs Built in Blender · Object Pooling · Pipeline - New Animated Weapon · Principles of Animation for Games · Progression Levels and Unlocks · Quest Chain System End to End · Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev · Short-Form Video Marketing · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Camera Shake and FX · Snippets - Playing Animations · Sound Design for Games · Squash Stretch and Anticipation in UI and Characters · Teardown - Anime Vanguards · Teardown - Bee Swarm Simulator · Teardown - Evade · Teardown - Fish It · Teardown - Funky Friday · Teardown - Jujutsu Shenanigans · Teardown - Sol's RNG · Teardown - Steal An Egg · Tween and CFrame Animation of Objects · UI Asset Pipeline · UI Design Systems · UI Style Directions - A Visual Vocabulary for Briefs · UI and GUI Animation · Weather Performance Budgets and Quality Tiers · What Craft Looks Like on Roblox - Lessons from Top Studios · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile · Working with Content Creators · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
