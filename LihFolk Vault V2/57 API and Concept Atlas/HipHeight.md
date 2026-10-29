---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/HipHeight]
---
# HipHeight

<!-- tldr:start -->
> [!tldr] TL;DR
> - HipHeight is not "leg length". It is the distance the Humanoid holds the root above the floor.
> - Avoid: Wrong HipHeight -> Compute from the rest model.
> - Floating or sinking: Clips not ground-fitted; wrong HipHeight -> Fit per clip; set HipHeight; runtime slope clamp.
> - Wrong standing height: incorrect HipHeight on 17 enemy templates (one rig's legs 1.5 studs into the floor at idle; others...
>
> Cost: TL;DR ~140 tok · whole note ~430 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

HipHeight is not "leg length". It is the distance the Humanoid holds the root above the floor. (from [[Characters and Humanoids]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Wrong HipHeight -> Compute from the rest model. ([[Custom Characters and StarterCharacter]])
- Floating or sinking: Clips not ground-fitted; wrong HipHeight -> Fit per clip; set HipHeight; runtime slope clamp. ([[Enemy and NPC Animation]])
- Wrong standing height: incorrect HipHeight on 17 enemy templates (one rig's legs 1.5 studs into the floor at idle; others 0.45-0.9). ([[Ground Fitting Pipeline]])

## Mentioned in

19 notes in 6 sections. The 19 most relevant are linked:

### 08 Animation
[[Animating Creatures and Monsters]] · [[Custom Characters and StarterCharacter]] · [[Enemy and NPC Animation]] · [[Foot Placement and Ground IK]] · [[Ground Fitting Pipeline]] · [[Humanoid States and Animation]] · [[Importing Models and Rigs]] · [[Mounts and Rideable Creatures]] · [[Pipeline - Importing Animated Enemies]] · [[R15 Rig Anatomy and Attachments]] · [[Scale and Animation]] · [[Snippets - IK]] · [[The Default Animate Script]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Mover Constraints and Physics Controllers]]

### 14 3D Modeling
[[Modeling Characters for R15 and Custom Rigs]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]]

### 53 Voxel Modelling Deep Dive
[[Voxel Characters - Proportions Joints and Rigging]]

<!-- atlas:generated -->
