---
tags: [atlas, api, type/atlas, area/animation, area/studio, api/ServerStorage]
---
# ServerStorage

<!-- tldr:start -->
> [!tldr] TL;DR
> - ServerStorage does not replicate. Roblox docs warn that clients cannot see this data; move the `KeyframeSequence` (or...
> - Trees in `ServerStorage`; only `DialogueShared` replicates.
> - `ServerStorage.Maps` children match `RoundConfig.MapNames` exactly.
> - Avoid: Templates in ReplicatedStorage -> ServerStorage, clone on spawn.
>
> Cost: TL;DR ~120 tok · whole note ~1.4k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

ServerStorage does not replicate. Roblox docs warn that clients cannot see this data; move the `KeyframeSequence` (or `CurveAnimation`) to ReplicatedStorage if clients must read it (for example a custom Lua player, see Lua Keyframe Player). (from [[Animation Editor Workflow]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Trees in `ServerStorage`; only `DialogueShared` replicates. ([[Dialogue System End to End]])
- `ServerStorage.Maps` children match `RoundConfig.MapNames` exactly. ([[Round-Based Minigame Loop End to End]])
- Avoid: Templates in ReplicatedStorage -> ServerStorage, clone on spawn. ([[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]])
- Avoid: Treating replicated data as private -> Secrets in ServerStorage; display copies only on the client. ([[How Exploits Work - The Client Boundary]])

## Mentioned in

107 notes in 29 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]] · [[Version History and Backups]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Project Structure and Bootstrapping]]

### 04 Data and Persistence
[[Session Locking and Profile Libraries]]

### 06 World Building and Art
[[Terrain Tools and Terrain API]]

### 08 Animation
[[Animation Editor Workflow]] · [[Case Study - Cutting a Million Instances]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 13 Production and Case Studies
[[Asset Pipelines]] · [[Case Study - Fast Join and Deferred Loading]] · [[Case Study - Instance Cleanup and Place Size]]

### 17 Pipelines
[[Batch Processing Tools in Studio]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Daily Rewards System End to End]] · [[Global Leaderboards End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]]

### 25 Physics and Vehicles
[[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Lore Delivery Without Walls of Text]]

### 43 Genre Systems End to End
[[Tycoon Plots and Droppers End to End]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 50 Team Collaboration and Project Management
[[Packages and Shared Assets Across Places]] · [[Working with Contractors and Revenue Splits]]

Also mentioned in (not linked): 3D Importer Settings Reference · Agent Handoff Notes - Project State and Resume Templates · Agent Review Loops and Guardrails in Practice · Animation Data from Blender to Roblox · Animation Objects · Arena Rounds with Teams and Spectating End to End · Baked Clip Stubs and Archiving · Build Test and Release Pipeline · Code Pipeline - Rojo Git and CI · Combat Arena and Encounter Layout · Command Bar and Studio Scripting · Creator Store and Toolbox Safety · Custom Characters and StarterCharacter · Data Loss Prevention and Recovery · Data and Config Pipeline - Spreadsheets to Game · Debugging Race Conditions and Yield Order · Destruction and Fracture · Documentation and Knowledge Bases · Engine Gotchas · Environment and Level Pipeline · Exploits and Anti-Cheat · Exporting FBX vs GLB · External Tooling - Rojo Wally Selene StyLua · Foliage Props and Scatter · Genre Playbook - Party and Minigame Collections · Genre Playbook - Puzzle and Escape Rooms · Genre Playbook - Social Deduction and Murder Mystery · Genre Playbook - Tycoons · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · HumanoidDescription and Outfit Systems · Importing Models and Rigs · Instanced Interiors - Pooled House and Room Copies for Many Players · Interest Management and Per-Player Replication · KeyframeSequence Keyframe and Pose Reference · Level Design for Roblox · Lighting Untextured Art in Roblox · LihFolk Systems Library · Links - Services · MCP Workflows for Building Worlds · MCP Workflows for Scripting and Debugging · Map Voting and Rotation for Round Games · MaterialService and Custom Materials · Memory Budgets and Leaks · Modular Environment Kits · Module Scripts and Requiring · Mounts and Rideable Creatures · Multiple Agents in One Studio · Network Performance · Open Questions · Packages and Asset Reuse · Parts Unions and MeshParts · Performance Fundamentals · Performance and Memory · Pipeline - Importing Animated Enemies · Pipeline Design Principles · Plugin Security and Permissions · Plugins - Using and Writing · Publishing Animations · Puzzle Dependency Charts and Hint Systems · Quest Chain System End to End · Racing Laps and Checkpoints End to End · Reading Luau Errors and Stack Traces · Release Process and Rollbacks · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Boundary · Replication Rules · Rigging in Blender · Running Many AI Agents on One Roblox Place · Safe Changes in a Shared Place · Script Types and Run Context · Server Authority and Validation · Server Lifecycle and Shutdown · Skill - Roblox System Builder · Snippets - Building and Sampling Clips · Studio Interface Tour · Team Create Permissions and Workflows · Terrain Deep Dive - Materials Water and Performance · Testing Your Own Remotes - Fuzzing and Abuse Tests · Threat Modeling a Roblox Game · Vehicle Damage, Repair and Wreck States · Writing Your Own MCP Server

<!-- atlas:generated -->
