---
tags: [atlas, api, type/atlas, area/networking, area/vfx, api/UnreliableRemoteEvent]
---
# UnreliableRemoteEvent

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UnreliableRemoteEvent` (Docs) can drop or reorder messages.
> - Avoid: Budgeting remote traffic per remote instead of per client -> Loss-tolerant streams on an UnreliableRemoteEvent (its own...
> - Avoid: sending full state over an `UnreliableRemoteEvent`.
> - `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only...
>
> Cost: TL;DR ~140 tok · whole note ~790 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UnreliableRemoteEvent` (Docs) can drop or reorder messages. (from [[Debugging Client-Server Desync]])

API snapshot: class, inherits `BaseRemoteEvent` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Budgeting remote traffic per remote instead of per client -> Loss-tolerant streams on an UnreliableRemoteEvent (its own pool)... ([[RemoteEvents RemoteFunctions and Unreliable Remotes]])
- Avoid: sending full state over an `UnreliableRemoteEvent`. ([[Engine Limits, Quotas and Defaults - Cheat Sheet]])
- `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only... ([[RemoteEvent - Engine Reference Card]])

## Mentioned in

39 notes in 23 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]]

### 03 Architecture and Networking
[[Frameworks - Knit Matter and Others]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Replication Rules]] · [[Snapshot Interpolation for Custom Replication]]

### 07 Lighting VFX and Audio
[[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]]

### 08 Animation
[[AnimationConstraint and Physically Simulated Characters]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]]

### 09 Gameplay Systems
[[Combat Systems Architecture]] · [[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]

### 10 Game Design and Genres
[[Genre Playbook - Tower Defense]]

### 12 Performance Testing and Debugging
[[Network Bandwidth Budgets and Measuring Them]] · [[Network Performance]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]]

### 25 Physics and Vehicles
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 43 Genre Systems End to End
[[Tower Defense Waves and Placement End to End]]

### 47 Game Feel and Juice
[[Feedback Timing - Sound Visual and Haptic Sync]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 50 Team Collaboration and Project Management
[[Documentation and Onboarding New Developers]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]]

### 62 Engine Reference Cards
[[RemoteEvent - Engine Reference Card]]

Also mentioned in (not linked): Glossary · Interest Management and Per-Player Replication · Luau Cookbook Start Here · Notification and Toast Systems · Official Docs - Scripting and Luau · Open Questions - Whole Vault · Projectiles and Ballistics · Rate Limiting and Abuse Prevention · Replicating VFX - Server Validates, Clients Render · Replication Boundary · Replication and Ownership · Serialization Formats for Saves and Networking · Testing Modes - Play Run and Multi-Client · Threat Modeling a Roblox Game

<!-- atlas:generated -->
