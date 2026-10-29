---
tags: [atlas, api, type/atlas, area/animation, area/performance, api/ReplicatedStorage]
---
# ReplicatedStorage

<!-- tldr:start -->
> [!tldr] TL;DR
> - ReplicatedStorage is the join cost. Audit it by folder, every week.
> - Avoid: Putting every model the client might ever need in ReplicatedStorage.
> - ReplicatedStorage instance count tracked; top folders known.
> - LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in...
>
> Cost: TL;DR ~120 tok · whole note ~2.4k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

ReplicatedStorage is the join cost. Audit it by folder, every week. (from [[Case Study - Fast Join and Deferred Loading]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Putting every model the client might ever need in ReplicatedStorage. ([[Case Study - Fast Join and Deferred Loading]])
- ReplicatedStorage instance count tracked; top folders known. ([[Case Study - Fast Join and Deferred Loading]])
- LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in ReplicatedStorage. ([[Script Types and Run Context]])
- Client code runs twice: Client-context `Script` in a Starter container -> LocalScript there, or move to ReplicatedStorage. ([[Script Types and Run Context]])
- Avoid: Storing maps in `ReplicatedStorage`. Every client downloads every map at join. ([[Round-Based Minigame Loop End to End]])

## Mentioned in

198 notes in 40 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Script Types and Run Context]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Project Structure and Bootstrapping]]

### 08 Animation
[[Case Study - Cutting a Million Instances]]

### 12 Performance Testing and Debugging
[[Testing Strategies and Frameworks]]

### 13 Production and Case Studies
[[Case Study - Fast Join and Deferred Loading]] · [[Case Study - Instance Cleanup and Place Size]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]]

### 24 Worked Builds
[[Daily Rewards System End to End]] · [[Global Leaderboards End to End]] · [[Melee Combat System End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]] · [[Shop with Game Passes and Developer Products End to End]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Tower Defense Waves and Placement End to End]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 58 Player QoL and Game Tweaks
[[Settings Menu Essentials and Persistence]]

Also mentioned in (not linked): A Stuck Player Watchdog That Logs the Cause · A-B Testing and Experiments on Roblox · AI Code Assistants for Luau · AI Pitfalls - Networking and Security · Ability Kits Architecture · Ads and Rewarded Video · Advanced Types - Generics and Type Functions · Animating Creatures and Monsters · Animation Capture and Mocap · Animation Data from Blender to Roblox · Animation Editor Workflow · Animation Objects · Atmosphere Sky Clouds and Post-Processing · Automated Testing with TestEZ and Jest-Lua · Avatar Context Menus Profiles and Social Surfaces · AvatarEditorService and In-Game Avatar Editors · Baked Clip Stubs and Archiving · Balancing with Spreadsheets and Data · Batch Processing Tools in Studio · Battle Pass and Season Design · Block and Mute Respecting Platform Rules · Boats Buoyancy and Water · Building a Signal Library · Centre of Mass, Anti-Flip and Self-Righting · Client Prediction and Reconciliation for Combat · Client Zone Culling for Interiors and Cities · Clip Archive Server · Code Pipeline - Rojo Git and CI · Codes Redemption System End to End · CollectionService Patterns · Colourblind Palettes Text Size and Tooltips · Combat Systems Architecture · Command Bar and Studio Scripting · Commerce and Physical Goods · Confirmation and Undo Patterns for Destructive and Paid Actions · Crash and Error Telemetry · Creator Store and Toolbox Safety · Debugger Breakpoints and Logging · Debugging Live Servers · Debugging Race Conditions and Yield Order · Declarative UI - React-Lua and Fusion · Developer Console and Stats · Developer Products and ProcessReceipt · Difficulty Options and Cognitive Load · Documentation and Knowledge Bases · Documentation and Onboarding New Developers · Drop Tables Rarity and Pity Systems · EditableImage for Pixel Buffers and Procedural 2D · Engine Gotchas · Entity Component Systems · Equip Draw and Flourish Systems · Error Handling - pcall xpcall and Promise Patterns · Exploits and Anti-Cheat · Explorer Properties and Selection · External Tooling - Rojo Wally Selene StyLua · Feature Flags · Feedback - Autosave Indicator Ping Display and Error Toasts · Frameworks - Knit Matter and Others · Gated Tester Commands and Debug Panels · Genre Playbook - Combat and RPG · Genre Playbook - Party and Minigame Collections · Genre Playbook - Puzzle and Escape Rooms · Genre Playbook - RNG and Collection Games · Genre Playbook - Simulators · Genre Playbook - Social Deduction and Murder Mystery · Genre Playbook - Sports · Genre Playbook - Tower Defense · Git and Source Control for Roblox · Grid Placement and Player Building Systems · HUD Design · Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · In-Game AI - LLM NPCs and Text Generation · In-Game Bug Report Button with Automatic Context · Input - UserInputService and ContextActionService · Input Remapping and One-Handed Play · Instance Streaming · Interest Management and Per-Player Replication · Inventory QoL - Sort Filter Search Stack and Lock · Joining Friends Parties and Private Servers · KeyframeSequence Keyframe and Pose Reference · Lessons Learned Index · LihFolk Systems Library · LihFolk UI Design System · Links - Script types · Links - Services · Live Incident Response and Post-Mortems · Live Ops Events and Updates · Load and Soak Testing Servers - Long Sessions and Many Clients · Lore Delivery Without Walls of Text · Luau Type System and Strict Mode · Markers and Events · MaterialService and Custom Materials · Materials MaterialVariants and SurfaceAppearance · Memory Budgets and Leaks · Menu Archetypes - Shop Settings Codes Rewards · Minimap and World Map UI - Projection, Rotation and Fog of War · Mobile and Low-End Optimization · Module Design and Dependency Injection · Module Scripts and Requiring · Moving Data Out of a Play Session · Multi-Client and Device Playtesting Protocols · Multi-Client and Live Testing · Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes · Network Bandwidth Budgets and Measuring Them · Network Performance · Notification and Toast Systems · Obby Checkpoints and Stage Saves End to End · Packages and Asset Reuse · Packages and Shared Assets Across Places · Paid Random Items and Odds Disclosure in Practice · Parallel Luau and Actors · Patch Notes and Player Communication · Performance Fundamentals · Performance and Memory · Pixel Art Pipeline - Aseprite to Roblox Without Blur · Places Universes and Experience Settings · Player Reports and In-Game Moderation · Post-Mortem - Building a Melee Action Game · Pricing Curves and Upgrade Costs · Pricing and Store Design · Progression and Pacing Design · Projectiles and Ballistics · Purchase Receipts and Purchase History in UI · QA Checklists Before Release · Quick Respawn and Spawn Protection · Racing Laps and Checkpoints End to End · Release Process and Rollbacks · Remote Abuse Patterns and Rate Limiting in Practice · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Boundary · Replication Rules · Replication and Ownership · Reserved and Private Servers in Practice · Roblox Generative AI - Cube Mesh and Texture Generation · Roblox Policies Ratings and Compliance · Roblox Studio Assistant · Robux Price Points and Offer Design · Safe Changes in a Shared Place · ScreenGui Fundamentals · Server Authority and Input Migration 2026 · Server Browsers and Server Lists · Server Hop Rejoin and Server Lists with Ping · Skill - Roblox System Builder · Skippable Tutorials and Replayable Tips · Snippets - Enemy Client Animator · Snippets - Playing Animations · Snippets - Ragdoll · SurfaceAppearance PBR Workflow · Team Create Permissions and Workflows · Team Roles and Workflows · Testing Time-Based Features with a Controllable Clock · Testing Your Own Remotes - Fuzzing and Abuse Tests · Threat Modeling a Roblox Game · Troubleshooting Table · Tycoon Plots and Droppers End to End · UI Automation with VirtualInput and StudioTestService · UI Design Systems · UI Style Directions - A Visual Vocabulary for Briefs · Update Cadence and Hype Cycles · VFX Design Playbook · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Version History and Backups · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos · Voxel Props Environments and Modular Tiles · Weapon Design Rig Builder · Weapon Rig Player · Weather System Architecture - State Machine, Transitions and Replication · Weather That Changes Gameplay - Grip, Visibility and Hearing · Worked Builds Start Here · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience · Zone and Biome Art Direction

<!-- atlas:generated -->
