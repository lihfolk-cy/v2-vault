---
tags: [atlas, concept, type/atlas, area/animation, area/gameplay]
---
# Ragdolls

<!-- tldr:start -->
> [!tldr] TL;DR
> - Ragdolls are physics assemblies, and physics scales badly.
> - Avoid: Leaving the Animator playing locomotion during the ragdoll (limbs fight physics or the body slides).
> - Living player dies the instant the ragdoll starts: neck joint disabled with `RequiresNeck = true` -> set it false first.
> - Ragdoll stands back up or slides around: Humanoid still in a normal state -> `Physics` state on the owner, or...
>
> Cost: TL;DR ~140 tok · whole note ~810 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Ragdolls are physics assemblies, and physics scales badly. One R15 ragdoll adds about 15 parts and 14 constraints to the simulation. (from [[Snippets - Ragdoll]])

## Key facts

- Avoid: Leaving the Animator playing locomotion during the ragdoll (limbs fight physics or the body slides). ([[Snippets - Ragdoll]])
- Living player dies the instant the ragdoll starts: neck joint disabled with `RequiresNeck = true` -> set it false first. ([[Ragdolls and Physics-Based Animation]])
- Ragdoll stands back up or slides around: Humanoid still in a normal state -> `Physics` state on the owner, or `EvaluateStateMachine = false` ([[Ragdolls and Physics-Based Animation]])

## Mentioned in

51 notes in 20 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Network Ownership]]

### 07 Lighting VFX and Audio
[[Gore Policy and Kid-Friendly Hit Feedback]]

### 08 Animation
[[Accessories and Armor That Follow Animation]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Animator Deep Dive]] · [[Custom Locomotion Controller Design]] · [[Foot Placement and Ground IK]] · [[Humanoid States and Animation]] · [[Open Questions]] · [[Principles of Animation for Games]] · [[Procedural Animation]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Ragdolls and Physics-Based Animation]] · [[Snippets - Playing Animations]] · [[Snippets - Ragdoll]]

### 09 Gameplay Systems
[[Mover Constraints and Physics Controllers]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Physics Assemblies and Constraints]]

### 10 Game Design and Genres
[[Genre Playbook - Battlegrounds and Arena Fighters]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 22 Anti-Exploit and Security
[[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 32 Case Studies of Top Roblox Games
[[Case Study - The Strongest Battlegrounds]]

### 59 Viral and Trend Game Teardowns
[[Teardown - Fling Things and People]]

### 60 High-Craft Game Teardowns
[[Teardown - Jujutsu Shenanigans]]

Also mentioned in (not linked): 00 Start Here · A Stuck Player Watchdog That Logs the Cause · Animation LOD · Animation Start Here · Avatar Body Types and Scale in Gameplay · Characters and Humanoids · Choosing GUI 2D or Locked-Camera 2.5D · Custom Characters and StarterCharacter · Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations · Debugging Physics and Network Ownership · Genre QA Passes - Test Checklists per Game Type · Grabs, Carries and Throws - Moving Players Safely · Hit Reactions Stagger and Hit-Stop · Level Design Principles - Flow Sightlines and Landmarks · Locomotion Systems · Motor6D Math and CFrame Composition · Obby Checkpoints and Stage Saves End to End · Obby and Platforming Level Design · Physics and Vehicles Start Here · R15 Rig Anatomy and Attachments · Rigs and Joints · Ropes Chains and Soft Bodies · Server-Authoritative Freeze and Stun Timestamps · Skeleton Library · Snippets - Animation Controller Module · The Default Animate Script

<!-- atlas:generated -->
