---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/GetAttributeChangedSignal]
---
# GetAttributeChangedSignal

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetAttributeChangedSignal` lets a controller react on the frame the owner changes.
> - Either send everything the client needs in the remote's arguments, or have the client react to the property itself...
> - Client code reads attributes and listens with `GetAttributeChangedSignal`.
>
> Cost: TL;DR ~110 tok · whole note ~680 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetAttributeChangedSignal` lets a controller react on the frame the owner changes. (from [[Custom Locomotion Controller Design]])

API snapshot: member of `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Either send everything the client needs in the remote's arguments, or have the client react to the property itself (`ChildAdded`, `GetAttributeChangedSignal`). ([[Replication Rules]])
- Client code reads attributes and listens with `GetAttributeChangedSignal`. ([[Interest Management and Per-Player Replication]])

## Mentioned in

37 notes in 17 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Packages and Asset Reuse]]

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Instances Attributes and Tags]] · [[Luau Performance Patterns with Benchmarks]]

### 03 Architecture and Networking
[[Instance Streaming]] · [[Interest Management and Per-Player Replication]] · [[Replication Rules]]

### 05 UI and UX
[[Declarative UI - React-Lua and Fusion]]

### 08 Animation
[[Custom Locomotion Controller Design]] · [[Enemy Animation State Protocol]] · [[Snippets - Enemy Client Animator]]

### 13 Production and Case Studies
[[Release Process and Rollbacks]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]]

### 25 Physics and Vehicles
[[Destruction and Fracture]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]] · [[Cookbook - UI]]

### 36 Narrative and Worldbuilding
[[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Horror Monster Chase AI End to End]] · [[Obby Checkpoints and Stage Saves End to End]] · [[Tycoon Plots and Droppers End to End]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

Also mentioned in (not linked): Script Performance · Server Authority and Input Migration 2026 · Server-Authoritative Freeze and Stun Timestamps · Shop with Game Passes and Developer Products End to End · Snippets - Animation Controller Module · Snippets - Procedural Motion · Snippets - Ragdoll · Teaching Through Level Design · The Debugging Method - Reproduce Isolate Bisect · Vehicle Damage, Repair and Wreck States · Weather System Architecture - State Machine, Transitions and Replication · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
