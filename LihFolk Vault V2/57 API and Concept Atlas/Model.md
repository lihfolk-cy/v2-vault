---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/Model]
---
# Model

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Model.LevelOfDetail` applies only with streaming enabled.
> - Model great in Blender, tiny in game: Judged from a close viewport with a wide lens -> Use the matched 70-degree vertical...
> - Model's parts fly apart during a tween: tweening `Position` on a welded root -> tween `CFrame` (Tween and CFrame Animation of...
> - Avoid: Unions for repeated props -> Model once, import, clone.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Model.LevelOfDetail` applies only with streaming enabled. (from [[Level of Detail and Model Streaming]])

API snapshot: class, inherits `PVInstance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Model great in Blender, tiny in game: Judged from a close viewport with a wide lens -> Use the matched 70-degree vertical camera at real distances. ([[Modelling to the Roblox Camera and Player Scale]])
- Model's parts fly apart during a tween: tweening `Position` on a welded root -> tween `CFrame` ([[Tween and CFrame Animation of Objects]])
- Avoid: Unions for repeated props -> Model once, import, clone. ([[Parts Unions and MeshParts]])
- Translation offsets scale with `Model:GetScale()`. ([[Animator Deep Dive]])
- Single objects wrapped in a Model before converting. ([[Packages and Asset Reuse]])

## Mentioned in

174 notes in 36 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Foliage Props and Scatter]] · [[Level of Detail and Model Streaming]] · [[Modeling in Blender for Roblox]]

### 08 Animation
[[Custom Characters and StarterCharacter]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Importing Models and Rigs]] · [[Scale and Animation]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Lua Keyframe Player Core]] · [[Testing Animations in Studio]] · [[Tween and CFrame Animation of Objects]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]] · [[Voxel and Blocky Modeling]]

### 22 Anti-Exploit and Security
[[Detecting Combat Exploits - Reach Rate and Aim]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 25 Physics and Vehicles
[[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 33 Level Design
[[Instanced Interiors - Pooled House and Room Copies for Many Players]]

### 35 Advanced Luau
[[Luau Garbage Collection and the Memory Model]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Tower Defense Waves and Placement End to End]] · [[Tycoon Plots and Droppers End to End]]

### 50 Team Collaboration and Project Management
[[Packages and Shared Assets Across Places]]

### 55 Modelling Nuance and Readability
[[Modelling to the Roblox Camera and Player Scale]]

Also mentioned in (not linked): A Stuck Player Watchdog That Logs the Cause · AI Pitfalls - Assets and Import · AI Pitfalls - Networking and Security · AI Pitfalls - Physics and Animation · Accessories and Armor That Follow Animation · Advanced Types - Generics and Type Functions · Aim Assist and Generous Hitboxes · Animation Capture and Mocap · Animation Editor Advanced · Animation Editor Workflow · Animation Objects · Animator Deep Dive · Asset Upload Automation with Open Cloud · Authoring Clips in Code · Avatar Body Types and Scale in Gameplay · Boats Buoyancy and Water · Bones and Skinned Meshes · Boss Animation and Phases · Building a Signal Library · Cars with Constraints - Suspension Steering and Drive · Case Study - 99 Nights in the Forest · Case Study - Steal a Brainrot · Centre of Mass, Anti-Flip and Self-Righting · Character Select and Class Systems with Different Rigs · Character and Creature Pipeline · Characters and Humanoids · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Client Hit Prediction for Melee Feedback · Client Zone Culling for Interiors and Cities · Code Review for Luau Teams · CollectionService Patterns · Combat Arena and Encounter Layout · Combat Systems Architecture · Cookbook - Remotes and Networking · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Custom Locomotion Controller Design · Custom Rigs - Weapons and Props · Debugging Animation Problems · Debugging Race Conditions and Yield Order · Destruction and Fracture · Detecting Movement Exploits - Speed Fly Noclip Teleport · Dialogue System End to End · Downed, Revive and Bleed-Out States · Enemy Animation State Protocol · Enemy and NPC Animation · Engine Gotchas · Entity Component Systems · Events Signals and Connections · Explosions - Radius Damage, Falloff and Cover Checks · Foot Placement and Ground IK · Genre Playbook - Party and Minigame Collections · Genre Playbook - Roleplay and Social Hangouts · Grabs, Carries and Throws - Moving Players Safely · Grid Placement and Player Building Systems · Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Horror Monster Chase AI End to End · How the Animator Really Behaves · HumanoidDescription and Outfit Systems · Hunting Memory Leaks Step by Step · IKControl Reference · In-Game AI - LLM NPCs and Text Generation · Input Responsiveness Buffering and Coyote Time · Instance Streaming · Interest Management and Per-Player Replication · Kill Credit, Assists, Kill Feed and Death Recaps · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Level Design Principles - Flow Sightlines and Landmarks · Lobby and Hub Design · Lua Keyframe Player · Lua Keyframe Player Internals · Luau Type System and Strict Mode · MCP Workflows for Building Worlds · MaterialService and Custom Materials · Memory Budgets and Leaks · Metatables and OOP - When and When Not · Modular Environment Kits · Module Scripts and Requiring · Motor6D Math and CFrame Composition · Mover Constraints and Physics Controllers · Multi-Seat Vehicles - Driver, Passenger and Gunner Roles · Network Ownership · Obby Checkpoints and Stage Saves End to End · Obby and Platforming Level Design · Open Questions · Open Questions - Whole Vault · Packages and Asset Reuse · Parallel Luau and Actors · Parts Unions and MeshParts · Pathfinding Edge Cases and Fallbacks · Pet Hatching and Following End to End · Physics Assemblies and Constraints · Playtest Heatmaps - Position and Death Maps · Procedural Animation · Procedural World Generation · Prompting and Verifying AI Output · QA Checklists Before Release · Quest Chain System End to End · Quick Respawn and Spawn Protection · R15 Rig Anatomy and Attachments · Racing Laps and Checkpoints End to End · Ragdolls and Physics-Based Animation · Raycasts Shapecasts and Spatial Queries · Reading Luau Errors and Stack Traces · Remote Abuse Patterns and Rate Limiting in Practice · Rendering Performance · Retargeting Animations Between Rigs · Retopology and Decimation · Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars · Rigs and Joints · Roblox Generative AI - Cube Mesh and Texture Generation · Round-Based Minigame Loop End to End · Scoping and Roles for Small Teams · Server Authority and Validation · Server-Authoritative Freeze and Stun Timestamps · Shape Language and Silhouette Testing · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Animation Controller Module · Snippets - Building and Sampling Clips · Snippets - IK · Snippets - Playing Animations · Snippets - Procedural Motion · Snippets - Ragdoll · Spawn Points Safe Zones and Respawn Flow · Spec-Driven Move Authoring · Squad AI - Attack Tokens, Flanking and Attacker Limits · Squash Stretch and Anticipation in UI and Characters · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Status Effects Buffs and Stacking Rules · Streaming Joins - Frozen Players and Loading Screen Teardown · Studio Tooling Architecture · Tables Metatables and OOP · Teaching Through Level Design · Terrain Tools and Terrain API · The Default Animate Script · Trim Sheets Atlases and Vertex Colors · Troubleshooting Table · UV Unwrapping · Vehicle Damage, Repair and Wreck States · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Voxel Characters - Proportions Joints and Rigging · Voxel Palettes - Ramps Hue Shifting and Limits · Voxel Props Environments and Modular Tiles · Water Sky and Atmosphere Art · Wave Function Collapse on Roblox · Weapon Design Rig Builder · Weapon Rig Player · Weekend Build - Arena Shooter with Server-Checked Hits · Weekend Build - Roleplay Town with Jobs and Paychecks · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
