---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/AnimationController]
---
# AnimationController

<!-- tldr:start -->
> [!tldr] TL;DR
> - AnimationController: The Animator host for rigs without a Humanoid (weapons, props, creatures).
> - Avoid: Humanoid per small animal -> CFrame movers and AnimationController.
> - If the Animator is a descendant of a player's character (under its Humanoid or an AnimationController in it), tracks started...
> - Under a `Humanoid` (characters, walking NPCs) or under an `AnimationController` (everything else).
>
> Cost: TL;DR ~140 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

AnimationController: The Animator host for rigs without a Humanoid (weapons, props, creatures). (from [[Animation Glossary]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Humanoid per small animal -> CFrame movers and AnimationController. ([[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]])
- If the Animator is a descendant of a player's character (under its Humanoid or an AnimationController in it), tracks started... ([[Replication and Ownership]])
- Under a `Humanoid` (characters, walking NPCs) or under an `AnimationController` (everything else). ([[Animator Deep Dive]])
- Add `AnimationController` + `Animator`, attributes (`FXModule`, `IdleId`, `SpecialId`, `BladeColor`), and keep the pristine import and previous rig in a work folder for rollback. ([[Custom Rigs - Weapons and Props]])

## Mentioned in

36 notes in 7 sections. The 25 most relevant are linked:

### 08 Animation
[[3D Importer Settings Reference]] · [[Animation Asset Permissions and Groups]] · [[Animation Glossary]] · [[Animation Objects]] · [[Animator Deep Dive]] · [[Bones and Skinned Meshes]] · [[Creature Rig Conventions]] · [[Custom Characters and StarterCharacter]] · [[Custom Rigs - Weapons and Props]] · [[Enemy and NPC Animation]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[IKControl Reference]] · [[Importing Models and Rigs]] · [[Mounts and Rideable Creatures]] · [[Open Questions]] · [[Rigging in Blender]] · [[Rigs and Joints]] · [[Snippets - Playing Animations]] · [[Troubleshooting Table]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 14 3D Modeling
[[Modeling Characters for R15 and Custom Rigs]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]]

### 37 Avatars and UGC
[[HumanoidDescription and Outfit Systems]]

Also mentioned in (not linked): Links - Rigs · Pipeline - Importing Animated Enemies · Pipeline - New Animated Weapon · Replication and Ownership · Scale and Animation · Snippets - Enemy Client Animator · Snippets - IK · Testing Animations in Studio · Weapon Design Rig Builder · Weapon and Combat Animation · Weight Painting and Skinning for Roblox

<!-- atlas:generated -->
