---
tags: [atlas, api, type/atlas, area/animation, area/performance, api/RunService]
---
# RunService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RunService:BindToSimulation(fn, frequency = Hz30, priority = 2000)` runs at the fixed rate for physics controllers and...
> - Avoid: Assuming Pause freezes everything -> Know which RunService events pause.
> - Harness gated by location, `RunService:IsStudio()`, and no remote trigger.
> - Per-frame work uses the correct RunService event and is disconnectable.
>
> Cost: TL;DR ~130 tok · whole note ~2.4k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RunService:BindToSimulation(fn, frequency = Hz30, priority = 2000)` runs at the fixed rate for physics controllers and prediction. (from [[Frame Order and RunService Timing]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Assuming Pause freezes everything -> Know which RunService events pause. ([[Testing Modes - Play Run and Multi-Client]])
- Harness gated by location, `RunService:IsStudio()`, and no remote trigger. ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]])
- Per-frame work uses the correct RunService event and is disconnectable. ([[Task Library Coroutines and Yielding]])
- `RunService:IsEdit()` guard before any UI is created. ([[Building a Studio Plugin End to End]])

## Mentioned in

202 notes in 40 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]]

### 02 Luau Scripting
[[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking
[[Server Lifecycle and Shutdown]]

### 08 Animation
[[Animator Deep Dive]] · [[Cameras and Cutscenes]] · [[Frame Order and RunService Timing]] · [[Idle Breathing and Secondary Motion]] · [[Procedural Animation]] · [[Snippets - IK]] · [[Snippets - Procedural Motion]]

### 09 Gameplay Systems
[[Camera Systems]]

### 12 Performance Testing and Debugging
[[Developer Console and Stats]] · [[Memory Budgets and Leaks]] · [[MicroProfiler Guide]] · [[Script Performance]]

### 22 Anti-Exploit and Security
[[Testing Your Own Remotes - Fuzzing and Abuse Tests]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]] · [[Debugging Physics and Network Ownership]] · [[Debugging Race Conditions and Yield Order]] · [[The Debugging Method - Reproduce Isolate Bisect]]

### 24 Worked Builds
[[Round-Based Minigame Loop End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]] · [[Cookbook - Remotes and Networking]]

### 35 Advanced Luau
[[Custom Schedulers and Coroutine Patterns]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · 2D Multiplayer - Server Authority and Replicating GUI Worlds · A Stuck Player Watchdog That Logs the Cause · AFK Detection Idle Kicks and AFK Reward Rules · AI Code Assistants for Luau · AI Pitfalls - Physics and Animation · Accessories and Armor That Follow Animation · Admin Commands Done Safely - Permissions and Audit Logs · Advanced Luau Start Here · Aircraft and Flight Models · Analytics and Funnels · Animation Glossary · Animation LOD · Animation Start Here · AnimationConstraint and Physically Simulated Characters · Atmosphere Sky Clouds and Post-Processing · Beams and Trails · Behaviour Trees Utility AI and State Machines for NPCs · Big Numbers Precision and Formatting · Boats Buoyancy and Water · Bones and Skinned Meshes · Building a Studio Plugin End to End · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Camera Settings - FOV Shake Sensitivity and Shift-Lock · Cars with Constraints - Suspension Steering and Drive · Case Study - Abilities That Only Worked in Studio · Characters and Humanoids · Chase Cameras and Speed Effects for Vehicles · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Client Prediction and Reconciliation for Combat · Codes Redemption System End to End · CollectionService Patterns · Command Bar and Studio Scripting · Console and VR Release Checklists · Cookbook - Math CFrame and Vectors · Cross-Server Messaging · Curves in Luau - Paths Beams and Motion · Custom Character Controllers · Custom Locomotion Controller Design · Custom Rigs - Weapons and Props · Daily Rewards System End to End · Data Loss Prevention and Recovery · Debugger Breakpoints and Logging · Debugging Animation Problems · Debugging DataStore Problems · Debugging UI Layout and Input · Detecting Combat Exploits - Reach Rate and Aim · Detecting Movement Exploits - Speed Fly Noclip Teleport · Deterministic Simulation · Dialogue System End to End · EditableImage for Pixel Buffers and Procedural 2D · Enemy Animation State Protocol · Engine Gotchas · Entity Component Systems · Events Signals and Connections · Exploits and Anti-Cheat · Feature Flags and Staged Rollouts · Field Notes Start Here · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Foliage Props and Scatter · Foot Placement and Ground IK · Frame Budget · Functions Closures and Upvalues · Gated Tester Commands and Debug Panels · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Open-World City and Crime Roleplay · Global Leaderboards End to End · Graphics and Performance Toggles for Low-End Devices · Grid Placement and Player Building Systems · Held Weapons on Motor6D - Locking the Grip During Attacks · Hit-Stop and Screen Shake Tuning by Numbers · Hitboxes and Hit Detection · Horror Monster Chase AI End to End · How the Animator Really Behaves · Hunting Memory Leaks Step by Step · Infinite and Streamed Worlds · Input Buffering · Interest Management and Per-Player Replication · Interpolation Easing and Curves Math · Juice on a Budget - Mobile and Low-End · Layering Camera Feedback on the Default Camera · Level of Detail and Model Streaming · Light Sources and Shadows · Lighting Mood and Time of Day · Links - Coroutines, task library and async · Links - Services · Load and Soak Testing Servers - Long Sessions and Many Clients · Locomotion Systems · Logging Bans and Appeals · Lua Keyframe Player · Lua Keyframe Player Internals · Luau Performance Patterns with Benchmarks · Luau Performance and Native Codegen · MCP Workflows for Scripting and Debugging · Math Vectors and CFrames · Motion Sensitivity and Camera Comfort · Motor6D Math and CFrame Composition · Mover Constraints and Physics Controllers · Moving Data Out of a Play Session · Multi-Client and Live Testing · NPC AI and Behaviour · Network Performance · Normal Maps and Detail Baking · Obby and Platforming Level Design · Off-Screen Objective Markers and Waypoint Arrows · Open Questions - Whole Vault · Parallel Luau and Actors · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Performance Fundamentals · Performance and Memory · Pet Hatching and Following End to End · Photo Mode and In-Game Screenshots with CaptureService · Physics Assemblies and Constraints · Physics Performance · Playback, Priorities and Blending · Plugin Security and Permissions · Plugin UI with DockWidgets · Plugins - Using and Writing · Procedural Death Knockdown and Hit Reactions · Procedural Gait and Footstep Planning · Procedural World Generation · Project Structure and Bootstrapping · Publishing Animations · Quest Chain System End to End · Race HUD - Position, Laps, Splits, Speedometer and Minimap · Racing Laps and Checkpoints End to End · Reading Luau Errors and Stack Traces · Rebirth and Prestige System End to End · Release Process and Rollbacks · Remote Abuse Patterns and Rate Limiting in Practice · RemoteEvents RemoteFunctions and Unreliable Remotes · Rendering Performance · Replication Rules · Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars · Roblox Changes 2025-2026 · Ropes Chains and Soft Bodies · Saved Inventory End to End · Saving Correctly - Autosave and BindToClose · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · Script Types and Run Context · Server Authority and Input Migration 2026 · Server Authority and Validation · Server Browsers and Server Lists · Server Shutdowns Soft Updates and Migration · Session Locking and Profile Libraries · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Animation Controller Module · Snippets - Camera Shake and FX · Snippets - Enemy Client Animator · Snippets - Lua Keyframe Player Core · Snippets - Playing Animations · Sound Design for Games · Spawning Teams and Rounds · Squash Stretch and Anticipation in UI and Characters · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Studio Plugins and Local HTTP Bridges · Teaching Through Level Design · Terrain Deep Dive - Materials Water and Performance · Terrain Materials and Painting · Testing Time-Based Features with a Controllable Clock · Textures Decals and Texture Memory · Threat Modeling a Roblox Game · Tower Defense Waves and Placement End to End · Tween and CFrame Animation of Objects · Tycoon Plots and Droppers End to End · UI Automation with VirtualInput and StudioTestService · VFX Performance Budgets and Culling · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer · Vehicle Damage, Repair and Wreck States · Vehicle Ownership and Anti-Exploit - Server-Checked Driving · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos · Weather Performance Budgets and Quality Tiers · Weather System Architecture - State Machine, Transitions and Replication · Writing Your Own MCP Server · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience

<!-- atlas:generated -->
