---
tags: [atlas, api, type/atlas, area/animation, area/vfx, api/Instance]
---
# Instance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Instance count is a proxy, not the goal.
> - Every Instance argument is checked for type, location, ownership and distance.
> - Instance counts before and after recorded.
> - Simulation state lives in tables; no gameplay reads Instance properties.
>
> Cost: TL;DR ~100 tok · whole note ~3.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Instance count is a proxy, not the goal. What players feel is join time, client memory and frame time; what developers feel is Studio responsiveness and publish time. (from [[Case Study - Cutting a Million Instances]])

API snapshot: class, inherits `Object`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every Instance argument is checked for type, location, ownership and distance. ([[Server Authority and Validation]])
- Instance counts before and after recorded. ([[Baked Clip Stubs and Archiving]])
- Simulation state lives in tables; no gameplay reads Instance properties. ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]])
- Avoid: `Instance.new` per one-shot -> Fixed voice pool with stealing. ([[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]])
- Avoid: Starting from `Instance.new("HumanoidDescription")` -> Start from `GetAppliedDescription()` ([[HumanoidDescription and Outfit Systems]])

## Mentioned in

269 notes in 45 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]] · [[Instances Attributes and Tags]]

### 03 Architecture and Networking
[[Instance Streaming]] · [[Server Authority and Validation]]

### 05 UI and UX
[[UI Design Systems]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 06 World Building and Art
[[Level of Detail and Model Streaming]]

### 07 Lighting VFX and Audio
[[Combat Sound Design and Feedback]] · [[Game Feel and Juice]] · [[Music and Adaptive Audio]] · [[The Audio API - Players Emitters Wires and Effects]]

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Case Study - Cutting a Million Instances]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Snippets - Building and Sampling Clips]] · [[Weapon Design Rig Builder]]

### 09 Gameplay Systems
[[Mover Constraints and Physics Controllers]]

### 13 Production and Case Studies
[[Case Study - Instance Cleanup and Place Size]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Selection Editing and Bulk Tools]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]]

Also mentioned in (not linked): A 2D Engine in a ScreenGui - Game Loop Entities and Rendering · AI Audio - Voice Music and SFX · AI Code Assistants for Luau · AI Material and Texture Generation · AI Pitfalls - Data and Monetization · AI Pitfalls - Networking and Security · AI Pitfalls - Physics and Animation · Ability Kits Architecture · Accessibility · Accessories and Armor That Follow Animation · Advanced Types - Generics and Type Functions · Age Checks and Safety Features · Aim Assist and Generous Hitboxes · Aircraft and Flight Models · Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools · Animation Objects · AnimationConstraint and Physically Simulated Characters · AnimationTrack Reference · Art Budgets - Triangles Draw Calls Memory · Art Pipeline - Concept to In-Game Asset · Asset Pipelines · Atmosphere Sky Clouds and Post-Processing · Audio Mixer Settings with SoundGroups · Audio Pipeline · Authoring Clips in Code · Avatar Context Menus Profiles and Social Surfaces · Baked Clip Stubs and Archiving · Batch Processing Tools in Studio · Beams and Trails · Block and Mute Respecting Platform Rules · Boats Buoyancy and Water · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Camera Shake and Camera FX · Captions and Audio Accessibility · Cars with Constraints - Suspension Steering and Drive · Case Study - Abilities That Only Worked in Studio · Case Study - Fast Join and Deferred Loading · Centre of Mass, Anti-Flip and Self-Righting · Character and Creature Pipeline · Choosing GUI 2D or Locked-Camera 2.5D · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Cinematic Ultimates · Client Zone Culling for Interiors and Cities · Code Review for Luau Teams · Codes Redemption System End to End · Collision and Physics Geometry · Colour-Blind Safe Design · Commerce and Physical Goods · Community Building · Cookbook - Data and Saving · Cookbook - Players and Characters · Cookbook - Remotes and Networking · Cookbook - UI · Crash and Error Telemetry · Creator Store and Toolbox Safety · Critiquing a Model - Paintovers and Iteration · CurveAnimation and Curve Channels · Curves in Luau - Paths Beams and Motion · Custom Character Controllers · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Custom Rigs - Weapons and Props · Daily Rewards System End to End · DataStore Fundamentals · Debugger Breakpoints and Logging · Debugging DataStore Problems · Debugging Live Servers · Debugging UI Layout and Input · Declarative UI - React-Lua and Fusion · Destruction and Fracture · Detecting Combat Exploits - Reach Rate and Aim · Developer Console and Stats · Drag-and-Drop Inventories and Sliders with UIDragDetector · EditableImage for Pixel Buffers and Procedural 2D · Enemy Import Axis Fix · Engine and API Changes 2025-2026 · Error Handling and Retries · Events Signals and Connections · Exploits and Anti-Cheat · Explorer Properties and Selection · Exporting and Validating Models for Roblox · Feedback Timing - Sound Visual and Haptic Sync · Flat Colour vs Gradient Atlas vs Vertex Colour · Foliage Props and Scatter · Foot Placement and Ground IK · Functions Closures and Upvalues · Game Icon Design - Readable at Small Sizes · Game Passes · Genre Playbook - Party and Minigame Collections · Genre Playbook - Shooters FPS and TPS · Global Leaderboards End to End · Global State and Live Config · Grabs, Carries and Throws - Moving Players Safely · Grid Placement and Player Building Systems · Highlights and Selection Effects · Horror Monster Chase AI End to End · HumanoidDescription and Outfit Systems · IKControl Reference · Impact Decals and Material-Aware Hit Sparks · Importing Models and Rigs · In-Game AI - LLM NPCs and Text Generation · Input - UserInputService and ContextActionService · Intersection and Collision Math · Inverse Kinematics · Joining Friends Parties and Private Servers · Juice on a Budget - Mobile and Low-End · Layout - Scale Offset and Constraints · Light Sources and Shadows · Lighting Technologies and Settings · Lighting Untextured Art in Roblox · Live Content Pipeline · Lobby and Hub Design · Localization · Lore Delivery Without Walls of Text · Lua Keyframe Player Internals · Luau Language Essentials · Luau Performance and Native Codegen · Luau Type System and Strict Mode · Markers and Events · Matchmaking Queues with MemoryStore · MaterialService and Custom Materials · Melee Combat System End to End · Memory Budgets and Leaks · Mesh Optimization for Mobile · Metatables and OOP - When and When Not · Mobile and Low-End Optimization · Modeling in Blender for Roblox · Modular Environment Kits · Module Scripts and Requiring · Motion Sensitivity and Camera Comfort · Moving Data Out of a Play Session · Multi-Bone IK - FABRIK and CCD · Multi-Client and Device Playtesting Protocols · Multi-Client and Live Testing · Network Bandwidth Budgets and Measuring Them · Network Ownership · Network Performance · Normal Maps and Detail Baking · Obby and Platforming Level Design · Parallel Luau and Actors · Particle Emitters In Depth · Parties and Group Teleports · Parts Unions and MeshParts · Performance and Memory · Physics Assemblies and Constraints · Pipeline Design Principles · Plugin Security and Permissions · Plugin UI with DockWidgets · Plugins - Using and Writing · Police Chases and Wanted Levels · Procedural Animation · Procedural World Generation · Publishing Animations · R15 Rig Anatomy and Attachments · Racing Laps and Checkpoints End to End · Ragdolls and Physics-Based Animation · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Raycasts Shapecasts and Spatial Queries · Readable Text and UI Scale · Reading Luau Errors and Stack Traces · Rebirth and Prestige System End to End · Remote Abuse Patterns and Rate Limiting in Practice · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Rules · Responsive UI for Phone Tablet Console and PC · Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars · Rigs and Joints · Roblox Generative AI - Cube Mesh and Texture Generation · Roblox Studio MCP Server · Ropes Chains and Soft Bodies · Round-Based Minigame Loop End to End · Safe Area · Safe Areas and Insets · Safe Changes in a Shared Place · Saved Inventory End to End · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · ScreenGui Fundamentals · Server Authority and Input Migration 2026 · Server Browsers and Server Lists · Server Hop Rejoin and Server Lists with Ping · Server Lifecycle and Shutdown · Server Shutdowns Soft Updates and Migration · Session Locking and Profile Libraries · Session State Across Places · Settings Menu Essentials and Persistence · Shape Language and Silhouette Testing · Shop with Game Passes and Developer Products End to End · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Camera Shake and FX · Snippets - Enemy Client Animator · Snippets - IK · Snippets - Lua Keyframe Player Core · Snippets - Playing Animations · Snippets - Procedural Motion · Snippets - Ragdoll · Social Design and Multiplayer Play · Sound Fundamentals · Spawn Points Safe Zones and Respawn Flow · Studio Tooling Architecture · Stylized Lighting Recipes · SurfaceAppearance PBR Workflow · Task Library Coroutines and Yielding · Team Create Permissions and Workflows · Team Roles and Workflows · Teleporting and Multi-Place Games · Terrain Tools and Terrain API · Testing Animations in Studio · Testing Strategies and Frameworks · Testing Your Own Remotes - Fuzzing and Abuse Tests · Text Chat Customization with TextChatService · Text Fonts and Rich Text · Textures Decals and Texture Memory · The Debugging Method - Reproduce Isolate Bisect · Tilemaps Cameras and Parallax for 2D Levels · Tiling Trim Sheets and Decal Tricks · Tower Defense Waves and Placement End to End · Tween and CFrame Animation of Objects · Two-Bone IK Math · Tycoon Plots and Droppers End to End · UI Asset Pipeline · UI Layout Objects - Lists Grids and Pages · UI Motion Language and Timing · UI Style Directions - A Visual Vocabulary for Briefs · UI and GUI Animation · VFX Design Playbook · VFX Performance Budgets and Culling · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Version History and Backups · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos · Voxel Art - Studs Outlines and Style Kits · Voxel Characters - Proportions Joints and Rigging · Voxel Palettes - Ramps Hue Shifting and Limits · Voxel Props Environments and Modular Tiles · Voxel and Blocky Modeling · Water Sky and Atmosphere Art · Wave Function Collapse on Roblox · Weather That Changes Gameplay - Grip, Visibility and Hearing · Weekend Build - Arena Shooter with Server-Checked Hits · Weekend Build - Survival Gather, Craft and Place · Working with Contractors and Revenue Splits · Writing Your Own MCP Server · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience · Zone and Biome Art Direction · ipairs Stops at the First nil - Cleanup Tables That Leak

<!-- atlas:generated -->
