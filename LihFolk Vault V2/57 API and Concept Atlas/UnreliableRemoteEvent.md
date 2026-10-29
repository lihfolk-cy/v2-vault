---
tags: [atlas, api, type/atlas, area/networking, area/animation, api/UnreliableRemoteEvent]
---
# UnreliableRemoteEvent

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UnreliableRemoteEvent` (Docs) can drop or reorder messages.
> - `RemoteEvent` and `UnreliableRemoteEvent` client-to-server calls are throttled at roughly 500 requests per second per client...
> - Never send a state change that must arrive (a hit, a purchase, an equip) over an UnreliableRemoteEvent.
> - Use `UnreliableRemoteEvent` for corrections and reliable remotes for spawn and death.
>
> Cost: TL;DR ~140 tok · whole note ~790 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UnreliableRemoteEvent` (Docs) can drop or reorder messages. (from [[Debugging Client-Server Desync]])

API snapshot: class, inherits `BaseRemoteEvent` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `RemoteEvent` and `UnreliableRemoteEvent` client-to-server calls are throttled at roughly 500 requests per second per client, shared across all remotes of the same type. ([[Network Bandwidth Budgets and Measuring Them]])
- Never send a state change that must arrive (a hit, a purchase, an equip) over an UnreliableRemoteEvent. ([[Cookbook - Remotes and Networking]])
- Use `UnreliableRemoteEvent` for corrections and reliable remotes for spawn and death. ([[Genre Playbook - Tower Defense]])
- Floating numbers for cosmetic effects can go over an `UnreliableRemoteEvent` because losing one is harmless (RemoteEvents RemoteFunctions and Unreliable Remotes). ([[Notification and Toast Systems]])

## Mentioned in

35 notes in 21 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]]

### 03 Architecture and Networking
[[Frameworks - Knit Matter and Others]] · [[Interest Management and Per-Player Replication]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Replication Rules]] · [[Snapshot Interpolation for Custom Replication]]

### 05 UI and UX
[[Notification and Toast Systems]]

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
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Projectiles and Ballistics]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 43 Genre Systems End to End
[[Tower Defense Waves and Placement End to End]]

### 47 Game Feel and Juice
[[Feedback Timing - Sound Visual and Haptic Sync]]

### 50 Team Collaboration and Project Management
[[Documentation and Onboarding New Developers]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]]

Also mentioned in (not linked): Glossary · Links - Remote events and functions · Luau Cookbook Start Here · Open Questions - Whole Vault · Rate Limiting and Abuse Prevention · Replication Boundary · Replication and Ownership · Serialization Formats for Saves and Networking · Testing Modes - Play Run and Multi-Client · Threat Modeling a Roblox Game

<!-- atlas:generated -->
