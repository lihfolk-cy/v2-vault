---
tags: [atlas, api, type/atlas, area/networking, area/platform, api/TeleportService]
---
# TeleportService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TeleportService` moves players between places, between servers of the same place, and into reserved servers that only your...
> - Avoid: `TeleportService:ReserveServerAsync` + `ReservedServerAccessCode` or `ShouldReserveServer` ->...
> - TeleportService does not work in Studio playtests; publish and test in the Roblox client.
> - `TeleportService` does not work in Studio, so test on a live private experience.
>
> Cost: TL;DR ~140 tok · whole note ~650 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TeleportService` moves players between places, between servers of the same place, and into reserved servers that only your code can send people to. (from [[Teleporting and Multi-Place Games]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `TeleportService:ReserveServerAsync` + `ReservedServerAccessCode` or `ShouldReserveServer` ->... ([[API Renames and Deprecations 2025-2026]])
- TeleportService does not work in Studio playtests; publish and test in the Roblox client. ([[Teleporting and Multi-Place Games]])
- `TeleportService` does not work in Studio, so test on a live private experience. ([[Server Lifecycle and Shutdown]])
- Teleports: `TeleportService:SetTeleportGui` shows a screen during place teleports; keep it visually consistent with the loading screen (Teleporting and Multi-Place Games). ([[Loading Screen Skip and First-Session Goals]])

## Mentioned in

25 notes in 13 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]]

### 02 Luau Scripting
[[Error Handling and Retries]] · [[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking
[[Server Lifecycle and Shutdown]] · [[Teleporting and Multi-Place Games]]

### 09 Gameplay Systems
[[Map Voting and Rotation for Round Games]]

### 10 Game Design and Genres
[[Genre Playbook - Tower Defense]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 33 Level Design
[[Lobby and Hub Design]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Parties and Group Teleports]] · [[Reserved and Private Servers in Practice]] · [[Server Browsers and Server Lists]] · [[Server Shutdowns Soft Updates and Migration]] · [[Session State Across Places]]

### 46 Resource Library
[[Official Docs - Networking and Multiplayer]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Engine and API Changes 2025-2026]]

### 50 Team Collaboration and Project Management
[[Working with Contractors and Revenue Splits]]

### 58 Player QoL and Game Tweaks
[[Joining Friends Parties and Private Servers]] · [[Loading Screen Skip and First-Session Goals]] · [[Server Hop Rejoin and Server Lists with Ping]]

### 62 Engine Reference Cards
[[Engine Reference Cards Start Here]] · [[TeleportService - Engine Reference Card]]

<!-- atlas:generated -->
