---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/FindFirstChild]
---
# FindFirstChild

<!-- tldr:start -->
> [!tldr] TL;DR
> - `FindFirstChild` returns the first child with that name.
> - `Size is not a valid member` style confusion: Child named like a property -> `FindFirstChild` (Instances Attributes and Tags)
> - Types and nil. Casts, optional values, `FindFirstChild` results (Luau Type System and Strict Mode).
> - Turn increment naming off if your code looks things up by name; auto-numbered duplicates break `FindFirstChild` assumptions...
>
> Cost: TL;DR ~150 tok · whole note ~2.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`FindFirstChild` returns the first child with that name. (from [[Code Review for Luau Teams]])

API snapshot: member of `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `Size is not a valid member` style confusion: Child named like a property -> `FindFirstChild` ([[Instances Attributes and Tags]])
- Types and nil. Casts, optional values, `FindFirstChild` results (Luau Type System and Strict Mode). ([[Code Review for Luau Teams]])
- Turn increment naming off if your code looks things up by name; auto-numbered duplicates break `FindFirstChild` assumptions quietly. ([[Explorer Properties and Selection]])
- Never use `FindFirstChild("Scene")`. Every GLB import is a top-level model named `Scene` unless renamed, and at one point two unrelated `Scene` models existed at once (one belonged to someone else's batch). ([[Importing Models and Rigs]])

## Mentioned in

157 notes in 38 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Explorer Properties and Selection]]

### 02 Luau Scripting
[[Instances Attributes and Tags]] · [[Luau Performance and Native Codegen]]

### 05 UI and UX
[[ScreenGui Fundamentals]] · [[Virtualized Lists and Large Inventories]]

### 08 Animation
[[Custom Rigs - Weapons and Props]] · [[Importing Models and Rigs]] · [[Snippets - IK]] · [[Testing Animations in Studio]]

### 13 Production and Case Studies
[[Case Study - Phone UI Overhaul]]

### 14 3D Modeling
[[Retopology and Decimation]]

### 24 Worked Builds
[[Melee Combat System End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]]

### 33 Level Design
[[Spawn Points Safe Zones and Respawn Flow]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Horror Monster Chase AI End to End]] · [[Racing Laps and Checkpoints End to End]] · [[Tower Defense Waves and Placement End to End]] · [[Tycoon Plots and Droppers End to End]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

Also mentioned in (not linked): A Stuck Player Watchdog That Logs the Cause · AFK Detection Idle Kicks and AFK Reward Rules · AI Pitfalls - Networking and Security · Ability Kits Architecture · Accessories and Armor That Follow Animation · Animation Editor Advanced · Animation Editor Workflow · AnimationConstraint and Physically Simulated Characters · Art Pipeline - Concept to In-Game Asset · Asset Pipelines · Avatar Context Menus Profiles and Social Surfaces · Batch Processing Tools in Studio · Boats Buoyancy and Water · Building a Studio Plugin End to End · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Case Study - Fast Join and Deferred Loading · Case Study - Instance Cleanup and Place Size · Case Study - Steal a Brainrot · Character Select and Class Systems with Different Rigs · Character and Creature Pipeline · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Client Zone Culling for Interiors and Cities · Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop · CollectionService Patterns · Colour Scripts and Value Structure for Untextured Art · Combat Arena and Encounter Layout · Cookbook - Remotes and Networking · Cookbook - UI · Critiquing a Model - Paintovers and Iteration · CurveAnimation and Curve Channels · Debugging Race Conditions and Yield Order · Debugging UI Layout and Input · Detecting Combat Exploits - Reach Rate and Aim · Detecting Movement Exploits - Speed Fly Noclip Teleport · Documentation and Knowledge Bases · Enemy Import Axis Fix · Engine Gotchas · Error Handling - pcall xpcall and Promise Patterns · Error Handling and Retries · Exploits and Anti-Cheat · Explosions - Radius Damage, Falloff and Cover Checks · Exporting FBX vs GLB · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Flat Colour vs Gradient Atlas vs Vertex Colour · Game Passes · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Puzzle and Escape Rooms · Genre Playbook - Shooters FPS and TPS · Global Leaderboards End to End · HUD Design · In-Game Bug Report Button with Automatic Context · Infinite and Streamed Worlds · Instance Streaming · Instanced Interiors - Pooled House and Room Copies for Many Players · Keeping a Mixed Asset Library Consistent · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Level Design Principles - Flow Sightlines and Landmarks · Level of Detail and Model Streaming · Loading Screen Skip and First-Session Goals · Lore Delivery Without Walls of Text · Luau Performance Patterns with Benchmarks · Luau Type System and Strict Mode · MCP Workflows for Scripting and Debugging · MaterialService and Custom Materials · Materials MaterialVariants and SurfaceAppearance · Modeling in Blender for Roblox · Module Scripts and Requiring · Mover Constraints and Physics Controllers · Multi-Client and Device Playtesting Protocols · Nametags and Overhead Bars - Cost and Visibility Rules · Network Ownership · Obby Checkpoints and Stage Saves End to End · Obby and Platforming Level Design · Objective Mode Maps - Capture the Flag, King of the Hill and Control Points · Packages and Shared Assets Across Places · Pathfinding Edge Cases and Fallbacks · Performance Fundamentals · Pipeline - Importing Animated Enemies · Planning and Scoping a Roblox Game · Player Reports and In-Game Moderation · Plugin Security and Permissions · Police Chases and Wanted Levels · Post-Mortem - Building a Melee Action Game · Projectiles and Ballistics · Prompting and Verifying AI Output · Publishing Animations · R15 Rig Anatomy and Attachments · Reading Luau Errors and Stack Traces · Rebirth and Prestige System End to End · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Rules · Roblox Generative AI - Cube Mesh and Texture Generation · Safe Changes in a Shared Place · Safety Rules for AI Agents in Studio · Scale and Animation · Script Performance · Server Authority and Input Migration 2026 · Server Authority and Validation · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Building and Sampling Clips · Snippets - Playing Animations · Snippets - Procedural Motion · Snippets - Ragdoll · Spawning Teams and Rounds · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Stylized Lighting Recipes · SurfaceAppearance PBR Workflow · Teaching Through Level Design · Team Roles and Workflows · Terrain Tools and Terrain API · Testing Your Own Remotes - Fuzzing and Abuse Tests · Text Chat Customization with TextChatService · Textures Decals and Texture Memory · The Debugging Method - Reproduce Isolate Bisect · The Gradient Palette Texture Workflow · Tiling Trim Sheets and Decal Tricks · Tools and Inventory Systems · UI Asset Pipeline · UI Automation with VirtualInput and StudioTestService · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Version History and Backups · Voxel Characters - Proportions Joints and Rigging · Voxel Props Environments and Modular Tiles · Wave Function Collapse on Roblox · Weekend Build - Arena Shooter with Server-Checked Hits · Weekend Build - Survival Gather, Craft and Place · Working with Contractors and Revenue Splits · World-Space UI - BillboardGui and SurfaceGui · Writing Your Own MCP Server · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience · Zone and Biome Art Direction · ipairs Stops at the First nil - Cleanup Tables That Leak

<!-- atlas:generated -->
