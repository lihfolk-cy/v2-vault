---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/Vector3]
---
# Vector3

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Vector3` is a native value type in Luau: arithmetic on it does not allocate GC objects (luau.org).
> - No timestamps, IDs or big values pass through `Vector3`, `CFrame` or other float32 containers.
> - Avoid: Saving `Vector3`/`CFrame` directly (Write fails with 104 every time) (Data Schema Design and Migrations)
> - Use a tolerance: `math.abs(a - b) < 1e-6`, or `Vector3:FuzzyEq` / `CFrame:FuzzyEq`.
>
> Cost: TL;DR ~140 tok · whole note ~2.5k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Vector3` is a native value type in Luau: arithmetic on it does not allocate GC objects (luau.org). (from [[Luau Performance Patterns with Benchmarks]])

API snapshot: Luau data type (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- No timestamps, IDs or big values pass through `Vector3`, `CFrame` or other float32 containers. ([[Big Numbers Precision and Formatting]])
- Avoid: Saving `Vector3`/`CFrame` directly (Write fails with 104 every time) ([[Data Schema Design and Migrations]])
- Use a tolerance: `math.abs(a - b) < 1e-6`, or `Vector3:FuzzyEq` / `CFrame:FuzzyEq`. ([[Math Vectors and CFrames]])
- Clear above: `Terrain:FillBlock(frame * CFrame.new(0, clearH / 2, 0), Vector3.new(width + 2 * shoulder, clearH, step * 1.5), Enum.Material.Air)` removes hills the road cuts through. ([[Roads, Rivers and Paths Carved Along Curves in Terrain]])

## Mentioned in

210 notes in 39 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Luau Performance Patterns with Benchmarks]] · [[Luau Performance and Native Codegen]] · [[Math Vectors and CFrames]]

### 06 World Building and Art
[[Roads, Rivers and Paths Carved Along Curves in Terrain]] · [[Terrain Tools and Terrain API]]

### 08 Animation
[[Flight Flocks and Path Animation]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - IK]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Ragdoll]] · [[Two-Bone IK Math]] · [[Weapon Design Rig Builder]]

### 25 Physics and Vehicles
[[Centre of Mass, Anti-Flip and Self-Righting]] · [[Projectiles and Ballistics]]

### 29 Luau Cookbook
[[Cookbook - Math CFrame and Vectors]]

### 33 Level Design
[[Spawn Points Safe Zones and Respawn Flow]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]] · [[Dot and Cross Products in Gameplay]] · [[Interpolation Easing and Curves Math]] · [[Intersection and Collision Math]]

### 43 Genre Systems End to End
[[Horror Monster Chase AI End to End]] · [[Tower Defense Waves and Placement End to End]]

### 44 Materials and Surfaces
[[Terrain Materials and Painting]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

Also mentioned in (not linked): AFK Detection Idle Kicks and AFK Reward Rules · AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses · AI Pitfalls - Data and Monetization · Accessories and Armor That Follow Animation · Aircraft and Flight Models · Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools · Animation LOD · Arena Rounds with Teams and Spectating End to End · Arm Baker Internals · Atmosphere Sky Clouds and Post-Processing · Authoring Clips in Code · Automated Testing with TestEZ and Jest-Lua · Avatar Body Types and Scale in Gameplay · Beams and Trails · Big Numbers Precision and Formatting · Boats Buoyancy and Water · Buffers and Binary Data · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Camera Shake and Camera FX · Camera Systems · Captions and Audio Accessibility · Cars with Constraints - Suspension Steering and Drive · Case Study - 99 Nights in the Forest · Characters and Humanoids · Chase Cameras and Speed Effects for Vehicles · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Cinematic Ultimates · Client Prediction and Reconciliation for Combat · Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop · Collision and Physics Geometry · Combat Arena and Encounter Layout · Combat Sound Design and Feedback · Combat Systems Architecture · Cookbook - Data and Saving · Cookbook - Players and Characters · Cookbook - Remotes and Networking · CurveAnimation and Curve Channels · Custom Character Controllers · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Custom Locomotion Controller Design · Custom Rigs - Weapons and Props · Data Schema Design and Migrations · Debugging Client-Server Desync · Destruction and Fracture · Detecting Combat Exploits - Reach Rate and Aim · Detecting Movement Exploits - Speed Fly Noclip Teleport · Documentation and Knowledge Bases · Elbow Poles Swivel and Joint Limits · Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning · Entity Component Systems · Environment and Level Pipeline · Equip Draw and Flourish Systems · Exploits and Anti-Cheat · Explorer Properties and Selection · Explosions - Radius Damage, Falloff and Cover Checks · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Foliage Props and Scatter · Foot Placement and Ground IK · Game Math Start Here · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Obbies and Platformers · Genre Playbook - Shooters FPS and TPS · Genre Playbook - Sports · Genre Playbook - Survival and Crafting · Genre Playbook - Tower Defense · Grid Placement and Player Building Systems · Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers · Hit Reactions Stagger and Hit-Stop · Hitboxes and Hit Detection · House Construction Method - Modular Kit Workflow · How the Animator Really Behaves · Importing Models and Rigs · Infinite and Streamed Worlds · Instances Attributes and Tags · Interest Management and Per-Player Replication · Inverse Kinematics · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Level Design Principles - Flow Sightlines and Landmarks · Level Design for Roblox · Level of Detail and Model Streaming · Light Sources and Shadows · Lighting Untextured Art in Roblox · Lightning Strikes and Thunder - Procedural Bolts and Sound Delay · Load and Soak Testing Servers - Long Sessions and Many Clients · Lobby and Hub Design · Locomotion Systems · Look-At Aim and Head Tracking · Lua Keyframe Player Internals · Luau Garbage Collection and the Memory Model · Luau Language Essentials · Luau Type System and Strict Mode · MCP Workflows for Building Worlds · Map Voting and Rotation for Round Games · Melee Combat System End to End · Metatables and OOP - When and When Not · Minimap and World Map UI - Projection, Rotation and Fog of War · Modeling Weapons and Props · Modelling to the Roblox Camera and Player Scale · Modular Environment Kits · Motion Sensitivity and Camera Comfort · Motor6D Math and CFrame Composition · Mover Constraints and Physics Controllers · Music and Adaptive Audio · Network Bandwidth Budgets and Measuring Them · Network Ownership · Network Performance · Normal Maps and Detail Baking · Obby Checkpoints and Stage Saves End to End · Objective Mode Maps - Capture the Flag, King of the Hill and Control Points · Off-Screen Objective Markers and Waypoint Arrows · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Parts Unions and MeshParts · Pathfinding · Pathfinding Edge Cases and Fallbacks · Performance and Memory · Pet Hatching and Following End to End · Physics Assemblies and Constraints · Pipeline - New Animated Weapon · Pipeline Design Principles · Playtest Heatmaps - Position and Death Maps · Police Chases and Wanted Levels · Procedural Death Knockdown and Hit Reactions · Procedural Weapon Motion · Prompting and Verifying AI Output · Quest Chain System End to End · Race HUD - Position, Laps, Splits, Speedometer and Minimap · Racing AI on a Racing Line - Spline Following and Rubber-Banding · Racing Laps and Checkpoints End to End · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking · Raycasts Shapecasts and Spatial Queries · Reading Luau Errors and Stack Traces · Remote Abuse Patterns and Rate Limiting in Practice · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Rules · Roblox Generative AI - Cube Mesh and Texture Generation · Ropes Chains and Soft Bodies · Rotations Angles and Quaternions · Round-Based Minigame Loop End to End · Safe Changes in a Shared Place · Saved Inventory End to End · Script Performance · Selection Editing and Bulk Tools · Serialization Formats for Saves and Networking · Server Authority and Validation · Snapshot Interpolation for Custom Replication · Snippets - Animation Controller Module · Snippets - Camera Shake and FX · Snippets - Enemy Client Animator · Snippets - Procedural Motion · Snow, Sandstorm, Blizzard and Ash Recipes · Spawning Teams and Rounds · Spec-Driven Move Authoring · Springs Damping and Smoothing · Springs That Survive Long Frames - dt Clamps and NaN Guards · Squash Stretch and Anticipation in UI and Characters · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Teaching Through Level Design · Teardown - +1 Speed Keyboard Escape · Terrain Deep Dive - Materials Water and Performance · Testing Your Own Remotes - Fuzzing and Abuse Tests · Textures Decals and Texture Memory · Tiling Trim Sheets and Decal Tricks · Tween and CFrame Animation of Objects · Tycoon Plots and Droppers End to End · Undo and ChangeHistoryService Done Right · VFX Performance Budgets and Culling · Vehicle Damage, Repair and Wreck States · Vehicle Ownership and Anti-Exploit - Server-Checked Driving · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos · Voxel Art - Studs Outlines and Style Kits · Voxel Characters - Proportions Joints and Rigging · Voxel Scale Grids and Stud Alignment · Voxel and Blocky Modeling · Water Sky and Atmosphere Art · Wave Function Collapse on Roblox · Weapon Swing Design · Weather System Architecture - State Machine, Transitions and Replication · Weekend Build - Arena Shooter with Server-Checked Hits · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile · World-Space UI - BillboardGui and SurfaceGui · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience · Zone and Biome Art Direction

<!-- atlas:generated -->
