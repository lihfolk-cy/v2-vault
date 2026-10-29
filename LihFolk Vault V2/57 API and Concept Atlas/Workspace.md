---
tags: [atlas, api, type/atlas, area/animation, area/vfx, api/Workspace]
---
# Workspace

<!-- tldr:start -->
> [!tldr] TL;DR
> - Workspace content replicates from server to clients; with streaming on, distant parts may not exist on a client yet.
> - Avoid: Expecting Atomic in ReplicatedStorage -> Streaming settings apply to Workspace only.
> - No LocalScript indexes Workspace parts directly without a wait or a tag.
> - No secrets in ReplicatedStorage, ReplicatedFirst, Workspace, StarterGui or StarterPlayer.
>
> Cost: TL;DR ~140 tok · whole note ~2.4k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Workspace content replicates from server to clients; with streaming on, distant parts may not exist on a client yet. (from [[Workspace - Engine Reference Card]])

API snapshot: service, inherits `WorldRoot` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Expecting Atomic in ReplicatedStorage -> Streaming settings apply to Workspace only. ([[Instance Streaming]])
- No LocalScript indexes Workspace parts directly without a wait or a tag. ([[Instance Streaming]])
- No secrets in ReplicatedStorage, ReplicatedFirst, Workspace, StarterGui or StarterPlayer. ([[Client-Server Model]])
- Beam missing: One attachment missing, same attachment twice, or not in Workspace -> Two distinct attachments in Workspace. ([[Beams and Trails]])
- LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in ReplicatedStorage. ([[Script Types and Run Context]])
- No scripts inside Workspace models unless they are distributed assets with explicit `RunContext`. ([[Script Types and Run Context]])

## Mentioned in

192 notes in 39 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Explorer Properties and Selection]]

### 02 Luau Scripting
[[Script Types and Run Context]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Instance Streaming]] · [[Interest Management and Per-Player Replication]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Replication Rules]] · [[Server Authority and Validation]]

### 06 World Building and Art
[[Level of Detail and Model Streaming]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Beams and Trails]] · [[Lighting Mood and Time of Day]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

### 08 Animation
[[Engine Gotchas]] · [[Pipeline - New Animated Weapon]]

### 09 Gameplay Systems
[[Physics Assemblies and Constraints]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 22 Anti-Exploit and Security
[[Detecting Combat Exploits - Reach Rate and Aim]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 36 Narrative and Worldbuilding
[[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]

### 42 Accessibility and Inclusive Design
[[Motion Sensitivity and Camera Comfort]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 62 Engine Reference Cards
[[Workspace - Engine Reference Card]]

Also mentioned in (not linked): 2D Collision Physics and Platformer Movement · 3D Importer Settings Reference · AI Pitfalls - Physics and Animation · API Renames and Deprecations 2025-2026 · Agent Review Loops and Guardrails in Practice · Aircraft and Flight Models · Animation Asset Permissions and Groups · Animation Editor Workflow · Animation LOD · Animation Objects · AnimationConstraint and Physically Simulated Characters · Animator - Engine Reference Card · Animator Deep Dive · AoE Telegraphs - Readable Ground Warnings · Arena Rounds with Teams and Spectating End to End · Art Pipeline - Concept to In-Game Asset · Avatar Body Types and Scale in Gameplay · BasePart - Engine Reference Card · BillboardGui - Engine Reference Card · Building a Studio Plugin End to End · Camera - Engine Reference Card · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Captions and Audio Accessibility · Cars with Constraints - Suspension Steering and Drive · Case Study - Cutting a Million Instances · Case Study - Fast Join and Deferred Loading · Case Study - Instance Cleanup and Place Size · Characters and Humanoids · Chase Cameras and Speed Effects for Vehicles · Client Prediction and Reconciliation for Combat · Client Zone Culling for Interiors and Cities · CollectionService Patterns · Collision and Physics Geometry · Command Bar and Studio Scripting · Cookbook - Players and Characters · Creator Store and Toolbox Safety · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Developer Console and Stats · Dialogue System End to End · Downed, Revive and Bleed-Out States · Dungeon and Room Generation · Engine Reference Cards Start Here · Engine and API Changes 2025-2026 · Entity Component Systems · Error Handling - pcall xpcall and Promise Patterns · Events Signals and Connections · Explosions - Radius Damage, Falloff and Cover Checks · Exporting FBX vs GLB · External Tooling - Rojo Wally Selene StyLua · Feedback Timing - Sound Visual and Haptic Sync · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Foliage Props and Scatter · Frame Order and RunService Timing · Game Trailers and Clean Footage - Capture, Freecam and Editing · Genre Playbook - Obbies and Platformers · Genre Playbook - Party and Minigame Collections · Git and Source Control for Roblox · Global Leaderboards End to End · Hit-Stop and Screen Shake Tuning by Numbers · Horror Monster Chase AI End to End · House Construction Method - Modular Kit Workflow · How Exploits Work - The Client Boundary · How the Animator Really Behaves · Humanoid - Engine Reference Card · Humanoid States and Animation · Hunting Memory Leaks Step by Step · Importing Models and Rigs · Input - UserInputService and ContextActionService · Instanced Interiors - Pooled House and Room Copies for Many Players · Instances Attributes and Tags · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Layering Camera Feedback on the Default Camera · Layout - Scale Offset and Constraints · Light Sources and Shadows · Lightning Strikes and Thunder - Procedural Bolts and Sound Delay · Loading Screen Skip and First-Session Goals · Lore Delivery Without Walls of Text · Luau Type System and Strict Mode · Making Numbers Feel Good - Cooldowns Buffering and Coyote Time · Markers and Events · Melee Combat System End to End · Memory Budgets and Leaks · Mobile and Low-End Optimization · Model - Engine Reference Card · Modeling Weapons and Props · Modular Environment Kits · Music and Adaptive Audio · Nametags and Overhead Bars - Cost and Visibility Rules · Network Ownership · Network Performance · Obby Checkpoints and Stage Saves End to End · Official Docs - Building and World · Open Questions · Open Questions - Whole Vault · Parallel Luau and Actors · Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run · Particle Emitters In Depth · ParticleEmitter - Engine Reference Card · Pathfinding · Pathfinding Edge Cases and Fallbacks · Performance and Memory · Pet Hatching and Following End to End · Physics Performance · Pipeline - Importing Animated Enemies · Pipeline Design Principles · Player - Engine Reference Card · Project Structure and Bootstrapping · Projectile VFX - Muzzle, Travel and Impact · ProximityPrompt - Engine Reference Card · ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab · Quest Chain System End to End · Race HUD - Position, Laps, Splits, Speedometer and Minimap · Racing Laps and Checkpoints End to End · Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking · Readable Text and UI Scale · Reading Luau Errors and Stack Traces · RemoteEvent - Engine Reference Card · Rendering Performance · Replicating VFX - Server Validates, Clients Render · Replication Boundary · Responsive UI for Phone Tablet Console and PC · Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars · Roads, Rivers and Paths Carved Along Curves in Terrain · Roblox Changes 2025-2026 · Roblox Studio MCP Server · Round-Based Minigame Loop End to End · RunService - Engine Reference Card · Safe Changes in a Shared Place · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · Server Authority and Input Migration 2026 · Server-Authoritative Freeze and Stun Timestamps · Snapshot Interpolation for Custom Replication · Snippets - Playing Animations · Sound Fundamentals · Spawn Points Safe Zones and Respawn Flow · Spawning Teams and Rounds · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Status Effects Buffs and Stacking Rules · Streaming Radius · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Studio Interface Tour · Studio Settings and Shortcuts · Studio Tooling Architecture · Task Library Coroutines and Yielding · Team Create Permissions and Workflows · Team Create and Collaboration · Teardown - Apocalypse Rising 2 · Terrain - Engine Reference Card · Terrain Deep Dive - Materials Water and Performance · Testing Animations in Studio · Testing Time-Based Features with a Controllable Clock · The Audio API - Players Emitters Wires and Effects · The Default Animate Script · Tools and Inventory Systems · Tower Defense Waves and Placement End to End · Troubleshooting Table · Tycoon Plots and Droppers End to End · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer · Vehicle Ownership and Anti-Exploit - Server-Checked Driving · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Version History and Backups · Weapon Design Rig Builder · Weapon Rig Player · What Is MCP · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile · World-Space UI - BillboardGui and SurfaceGui · Writing Your Own MCP Server

<!-- atlas:generated -->
