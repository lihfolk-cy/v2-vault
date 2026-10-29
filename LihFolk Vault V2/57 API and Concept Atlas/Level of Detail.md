---
tags: [atlas, concept, type/atlas, area/animation, area/world]
---
# Level of Detail

<!-- tldr:start -->
> [!tldr] TL;DR
> - LOD: Updating distant or off-screen rigs less often.
> - Animation LOD. Distant NPCs update less often (Animation LOD).
> - A client script that toggles which LOD model is parented (or transparent) based on camera distance, checked a few times per...
> - Do not LOD the rig the player is fighting, even if it is far (a ranged duel at 100 studs).
>
> Cost: TL;DR ~130 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

LOD: Updating distant or off-screen rigs less often. (from [[Animation Glossary]])

LOD: Level of detail: cheaper versions of distant things. (from [[Glossary]])

## Key facts

- Animation LOD. Distant NPCs update less often (Animation LOD). ([[Level of Detail and Model Streaming]])
- A client script that toggles which LOD model is parented (or transparent) based on camera distance, checked a few times per second, not every frame. ([[Retopology and Decimation]])
- Do not LOD the rig the player is fighting, even if it is far (a ranged duel at 100 studs). ([[Animation LOD]])
- A late joiner, a re-streamed enemy, or a client waking an enemy from LOD sleep lands on the right frame. ([[Snippets - Enemy Client Animator]])

## Mentioned in

82 notes in 18 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Instance Streaming]]

### 06 World Building and Art
[[Level of Detail and Model Streaming]] · [[Parts Unions and MeshParts]] · [[Terrain Deep Dive - Materials Water and Performance]]

### 07 Lighting VFX and Audio
[[Engine and Tyre Audio Driven by RPM and Slip]]

### 08 Animation
[[Animation Glossary]] · [[Animation LOD]] · [[Animator Deep Dive]] · [[Bones and Skinned Meshes]] · [[Lua Keyframe Player]] · [[Performance and Memory]] · [[Procedural Animation]] · [[Replication and Ownership]] · [[Snippets - Enemy Client Animator]] · [[Snippets - IK]] · [[Snippets - Lua Keyframe Player Core]] · [[Troubleshooting Table]]

### 12 Performance Testing and Debugging
[[Performance Fundamentals]]

### 13 Production and Case Studies
[[Case Study - Enemy Roster Rebuild]] · [[Case Study - Fast Join and Deferred Loading]]

### 14 3D Modeling
[[Mesh Optimization for Mobile]] · [[Modeling Fundamentals for Games]] · [[Retopology and Decimation]]

### 15 AI Tools
[[AI 3D Model Generation Outside Roblox]]

### 53 Voxel Modelling Deep Dive
[[Meshing Voxels for Roblox - Greedy Meshing and Export]]

Also mentioned in (not linked): 00 Start Here · AI Pitfalls - Assets and Import · AI in Roblox Development Overview · Animation Asset Permissions and Groups · Animation Start Here · Arm Baker Internals · Art Budgets - Triangles Draw Calls Memory · Atmosphere Sky Clouds and Post-Processing · Blender MCP · Case Study - Abilities That Only Worked in Studio · Case Study - Cutting a Million Instances · Clean Stylised Shading - Weighted and Custom Normals · Custom Rigs - Weapons and Props · Debugging Animation Problems · Enemy and NPC Animation · Entity Component Systems · Faceted Low-Poly - Flat Normals and Facet Size · Foliage Props and Scatter · Foot Placement and Ground IK · Frame Budget · Genre Playbook - Combat and RPG · Genre Playbook - Tower Defense · Glossary · Hard-Surface Modeling · House Construction Method - Modular Kit Workflow · How the Animator Really Behaves · Idle Breathing and Secondary Motion · Impact Decals and Material-Aware Hit Sparks · Lessons Learned Index · Low-Poly and Stylized Modeling · Lua Keyframe Player Internals · Luau Performance Patterns with Benchmarks · Markers and Events · Mobile and Low-End Optimization · Multi-Bone IK - FABRIK and CCD · Open Questions · Open Questions - Whole Vault · Other Modeling Tools - Maya Max ZBrush MagicaVoxel · Pipeline - Importing Animated Enemies · Playback, Priorities and Blending · Publishing Animations · Rendering Performance · Roblox Generative AI - Cube Mesh and Texture Generation · Script Performance · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Skeleton Library · Snippets - Procedural Motion · Snippets - Ragdoll · Streaming Radius · Terrain Tools and Terrain API · Testing Animations in Studio · The Default Animate Script · Topology and Edge Flow · Tween and CFrame Animation of Objects · Untextured Stylised Modelling Start Here · VFX Performance Budgets and Culling · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile

<!-- atlas:generated -->
