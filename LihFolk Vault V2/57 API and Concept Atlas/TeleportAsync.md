---
tags: [atlas, api, type/atlas, area/networking, area/platform, api/TeleportAsync]
---
# TeleportAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TeleportAsync` is server-only; a client call errors with "TeleportAsync called from Client".
> - Avoid: Client-side `Teleport()` -> Remote, validate, `TeleportAsync` on the server.
> - Avoid: calling `TeleportAsync` from a LocalScript.
> - `TeleportAsync` wrapped in `pcall`, plus a `TeleportInitFailed` retry with backoff.
>
> Cost: TL;DR ~120 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TeleportAsync` is server-only; a client call errors with "TeleportAsync called from Client". (from [[TeleportService - Engine Reference Card]])

API snapshot: member of `TeleportService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Client-side `Teleport()` -> Remote, validate, `TeleportAsync` on the server. ([[Teleporting and Multi-Place Games]])
- Avoid: calling `TeleportAsync` from a LocalScript. ([[TeleportService - Engine Reference Card]])
- `TeleportAsync` wrapped in `pcall`, plus a `TeleportInitFailed` retry with backoff. ([[TeleportService - Engine Reference Card]])
- Avoid: Assuming one `TeleportAsync` moves the whole party -> It moves only players in this server; gather the rest. ([[Parties and Group Teleports]])
- Friends split across servers: Teleported one by one -> One `TeleportAsync` with the whole group. ([[Joining Friends Parties and Private Servers]])
- Private match: `ReservedServerId = HttpService:GenerateGUID(false)`, one `TeleportAsync` per party in `pcall`, retry on failure. ([[Joining Friends Parties and Private Servers]])

## Mentioned in

17 notes in 8 sections. The 17 most relevant are linked:

### 03 Architecture and Networking
[[Server Lifecycle and Shutdown]] · [[Teleporting and Multi-Place Games]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 33 Level Design
[[Lobby and Hub Design]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Multiplayer Services Start Here]] · [[Parties and Group Teleports]] · [[Reserved and Private Servers in Practice]] · [[Server Browsers and Server Lists]] · [[Server Shutdowns Soft Updates and Migration]] · [[Session State Across Places]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 58 Player QoL and Game Tweaks
[[Joining Friends Parties and Private Servers]] · [[Server Hop Rejoin and Server Lists with Ping]]

### 62 Engine Reference Cards
[[TeleportService - Engine Reference Card]]

<!-- atlas:generated -->
