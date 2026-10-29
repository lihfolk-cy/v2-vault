---
tags: [atlas, concept, type/atlas, area/animation, area/gameplay]
---
# Hitboxes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Hitboxes change with rigs; competitive games normalise with uniform hitbox parts per class so a small creature is not...
> - Avoid: Relying on MeshPart collision for animated limbs -> Hitbox parts on bones, or data-driven hits.
> - Avoid: Letting avatars change hitbox size -> morph to a fixed rig or use fixed hit volumes.
> - Fixed hitboxes for all players. (Teardown - Arsenal)
>
> Cost: TL;DR ~140 tok · whole note ~1.2k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Hitboxes change with rigs; competitive games normalise with uniform hitbox parts per class so a small creature is not unhittable (Hitboxes and Hit Detection). (from [[Character Select and Class Systems with Different Rigs]])

## Key facts

- Avoid: Relying on MeshPart collision for animated limbs -> Hitbox parts on bones, or data-driven hits. ([[Bones and Skinned Meshes]])
- Avoid: Letting avatars change hitbox size -> morph to a fixed rig or use fixed hit volumes. ([[Teardown - Arsenal]])
- Fixed hitboxes for all players. ([[Teardown - Arsenal]])
- Every move defined in data with frame data, hitbox and damage. ([[Genre Playbook - Battlegrounds and Arena Fighters]])
- Avoid: Cosmetics that change hitboxes or reach. ([[Case Study - Murder Mystery 2]])

## Mentioned in

91 notes in 33 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]]

### 06 World Building and Art
[[Collision and Physics Geometry]]

### 08 Animation
[[Bones and Skinned Meshes]] · [[Scale and Animation]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]] · [[Combat Systems Architecture]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Hitboxes and Hit Detection]] · [[Raycasts Shapecasts and Spatial Queries]]

### 10 Game Design and Genres
[[Boss Fight Design Patterns]] · [[Genre Playbook - Battlegrounds and Arena Fighters]]

### 12 Performance Testing and Debugging
[[Gated Tester Commands and Debug Panels]]

### 17 Pipelines
[[Character and Creature Pipeline]]

### 22 Anti-Exploit and Security
[[Detecting Combat Exploits - Reach Rate and Aim]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]]

### 40 Game Math
[[Dot and Cross Products in Gameplay]]

### 45 Procedural Blender Assets
[[Matching a Concept Sheet - Boss Creature Case Study]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Sprite Sheets and Frame Animation with ImageRectOffset]]

### 55 Modelling Nuance and Readability
[[Proportion Exaggeration and Gameplay Distance]]

### 56 Field Notes
[[Client Hit Prediction for Melee Feedback]]

### 58 Player QoL and Game Tweaks
[[Aim Assist and Generous Hitboxes]]

### 60 High-Craft Game Teardowns
[[Teardown - Arsenal]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · Accessibility Cross-Links for QoL Settings · Accessories and Armor That Follow Animation · Animation LOD · AnimationConstraint and Physically Simulated Characters · Anti-Exploit Start Here · Arena Rounds with Teams and Spectating End to End · Avatars and UGC Start Here · Bundles Animation Packs and Emotes for Sale · Case Study - Blox Fruits · Case Study - Enemy Roster Rebuild · Case Study - Forsaken · Case Study - Murder Mystery 2 · Case Study - The Strongest Battlegrounds · Client-Server Model · Combat Arena and Encounter Layout · Combat Sound Design and Feedback · Controller Support QoL · Cookbook - Players and Characters · Custom Character Controllers · Custom Characters and StarterCharacter · DevEx and Cashing Out · Exploits and Anti-Cheat · Explosions - Radius Damage, Falloff and Cover Checks · Game Math Start Here · Genre Playbook - Combat and RPG · Genre Playbook - Shooters FPS and TPS · High-Craft Teardowns Start Here · Highlights and Selection Effects · Hit-Stop · Input Remapping and One-Handed Play · Interest Management and Per-Player Replication · Intersection and Collision Math · LihFolk R15 Keyframe Pipeline · Luau Performance Patterns with Benchmarks · Luau Performance and Native Codegen · Making Numbers Feel Good - Cooldowns Buffering and Coyote Time · Markers and Events · Math Vectors and CFrames · Mesh VFX Packs Built in Blender · NPC AI and Behaviour · Network Ownership · Physics Assemblies and Constraints · Physics Performance · Physics and Vehicles Start Here · Player QoL Start Here · Projectiles and Ballistics · QoL Audit Checklist · Replication and Ownership · Server Authority and Validation · Skeleton Library · Slash VFX Recipes - Crescent and Ring · Snapshot Interpolation for Custom Replication · Snippets - IK · Status Effects Buffs and Stacking Rules · Teardown - Grace · Teardown - Jujutsu Shenanigans · Teardown - Phantom Forces · Time-to-Kill Math and a Weapon Balance Sheet · Token Cost Benchmarks · Top 25 QoL Wins by Effort · Weapon Swing Design · What Craft Looks Like on Roblox - Lessons from Top Studios · Worked Builds Start Here · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
