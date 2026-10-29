---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/Humanoid]
---
# Humanoid

<!-- tldr:start -->
> [!tldr] TL;DR
> - A Humanoid is itself a controller: every frame it applies forces to reach `WalkSpeed` in `MoveDirection`, stands the character...
> - Dashes use Plane mode and agree with the Humanoid.
> - Avoid: `Humanoid:LoadAnimation` in new code -> `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` (Animation...
> - Ragdoll stands back up or slides around: Humanoid still in a normal state -> `Physics` state on the owner, or...
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A Humanoid is itself a controller: every frame it applies forces to reach `WalkSpeed` in `MoveDirection`, stands the character up at `HipHeight`, applies friction and handles slopes. (from [[Mover Constraints and Physics Controllers]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Dashes use Plane mode and agree with the Humanoid. ([[Mover Constraints and Physics Controllers]])
- Avoid: `Humanoid:LoadAnimation` in new code -> `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` ([[Animation Objects]])
- Ragdoll stands back up or slides around: Humanoid still in a normal state -> `Physics` state on the owner, or `EvaluateStateMachine = false` ([[Ragdolls and Physics-Based Animation]])
- Avoid: Changing a player character's Humanoid state from the server. ([[Snippets - Ragdoll]])
- Avoid: Humanoid NPC enemies -> Data-driven enemies, client-rendered. ([[Genre Playbook - Tower Defense]])

## Mentioned in

175 notes in 35 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]]

### 08 Animation
[[Animation Objects]] · [[Animator Deep Dive]] · [[Custom Characters and StarterCharacter]] · [[Emotes and Social Animation]] · [[Humanoid States and Animation]] · [[Locomotion Systems]] · [[Ragdolls and Physics-Based Animation]] · [[Snippets - IK]] · [[Snippets - Ragdoll]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Custom Character Controllers]] · [[Mover Constraints and Physics Controllers]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] · [[Pathfinding Edge Cases and Fallbacks]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 15 AI Tools
[[AI Pitfalls - Physics and Animation]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[HumanoidDescription and Outfit Systems]]

### 46 Resource Library
[[Links - Humanoids and character controllers]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

Also mentioned in (not linked): 00 Start Here · 2D Collision Physics and Platformer Movement · A Stuck Player Watchdog That Logs the Cause · AI Animation and Motion from Video · AI Code Assistants for Luau · AI Pitfalls - Networking and Security · AI Pitfalls - Stale APIs and Luau · Ability Kits Architecture · Accessories and Armor That Follow Animation · Aircraft and Flight Models · Animation Capture and Mocap · Animation Data from Blender to Roblox · Animation Editor Workflow · Animation Glossary · Animation Start Here · AnimationConstraint and Physically Simulated Characters · Arena Rounds with Teams and Spectating End to End · Avatar Body Types and Scale in Gameplay · Behaviour Trees Utility AI and State Machines for NPCs · Bundles Animation Packs and Emotes for Sale · Camera Systems · Cameras and Cutscenes · Cars with Constraints - Suspension Steering and Drive · Case Study - Tower Defense Simulator · Character Select and Class Systems with Different Rigs · Character and Creature Pipeline · Chase Cameras and Speed Effects for Vehicles · Cinematic Ultimates · Code Review for Luau Teams · CollectionService Patterns · Collision and Physics Geometry · Combat Systems Architecture · Cookbook - Math CFrame and Vectors · Cookbook - Remotes and Networking · Creature Rig Conventions · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Custom Locomotion Controller Design · Custom Schedulers and Coroutine Patterns · Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations · Debugger Breakpoints and Logging · Debugging Client-Server Desync · Debugging Race Conditions and Yield Order · Debugging Start Here · Detecting Combat Exploits - Reach Rate and Aim · Detecting Movement Exploits - Speed Fly Noclip Teleport · Dialogue System End to End · Downed, Revive and Bleed-Out States · Enemy and NPC Animation · Engine Gotchas · Entity Component Systems · Events Signals and Connections · Exploits and Anti-Cheat · Foot Placement and Ground IK · Functions Closures and Upvalues · Game Feel Start Here · Genre Playbook - Obbies and Platformers · Genre Playbook - Tower Defense · Genre Playbook - Zombie and Wave Survival Co-op · Grabs, Carries and Throws - Moving Players Safely · Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · How the Animator Really Behaves · IKControl Reference · Idle Breathing and Secondary Motion · Importing Models and Rigs · KeyframeSequence Keyframe and Pose Reference · Kill Credit, Assists, Kill Feed and Death Recaps · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Layered Clothing Creation Workflow · Level Design for Roblox · Level of Detail and Model Streaming · LihFolk R15 Keyframe Pipeline · Links - Rigs · Lobby and Hub Design · Locomotion Readability - Lessons from Blind Panels · Lua Keyframe Player · Luau Garbage Collection and the Memory Model · Luau Type System and Strict Mode · Making Numbers Feel Good - Cooldowns Buffering and Coyote Time · MaterialService and Custom Materials · Melee Combat System End to End · Memory Budgets and Leaks · Mesh Optimization for Mobile · MicroProfiler Guide · Modeling Characters for R15 and Custom Rigs · Modelling to the Roblox Camera and Player Scale · Mounts and Rideable Creatures · Multi-Seat Vehicles - Driver, Passenger and Gunner Roles · Network Ownership · Network Performance · Obby Checkpoints and Stage Saves End to End · Obby and Platforming Level Design · Objective Mode Maps - Capture the Flag, King of the Hill and Control Points · Open Questions · Open Questions - Whole Vault · Pathfinding · Physics Assemblies and Constraints · Pipeline - Importing Animated Enemies · Playtest Heatmaps - Position and Death Maps · Police Chases and Wanted Levels · Procedural Death Knockdown and Hit Reactions · Procedural Gait and Footstep Planning · Prompting and Verifying AI Output · Quest Chain System End to End · Quick Respawn and Spawn Protection · R15 Rig Anatomy and Attachments · Racing Laps and Checkpoints End to End · Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking · Reading Luau Errors and Stack Traces · RemoteEvents RemoteFunctions and Unreliable Remotes · Rendering Performance · Replication Rules · Replication and Ownership · Retargeting Animations Between Rigs · Rigging in Blender · Rigs and Joints · Roblox Studio Assistant · Ropes Chains and Soft Bodies · Round-Based Minigame Loop End to End · Scale and Animation · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · Server Authority and Input Migration 2026 · Server Authority and Validation · Server-Authoritative Freeze and Stun Timestamps · Skeleton Library · Snippets - Animation Controller Module · Snippets - Camera Shake and FX · Snippets - Playing Animations · Snippets - Procedural Motion · Spawn Points Safe Zones and Respawn Flow · Spawning Teams and Rounds · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Status Effects Buffs and Stacking Rules · Terrain Deep Dive - Materials Water and Performance · Testing Animations in Studio · Testing Strategies and Frameworks · The Default Animate Script · Timing Spacing and Frame Charts · Tools and Inventory Systems · Tower Defense Waves and Placement End to End · Troubleshooting Table · Two-Bone IK Math · Tycoon Plots and Droppers End to End · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Voxel Characters - Proportions Joints and Rigging · Weather That Changes Gameplay - Grip, Visibility and Hearing · Weekend Build - Arena Shooter with Server-Checked Hits · What AI Models Get Wrong in Roblox · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile

<!-- atlas:generated -->
