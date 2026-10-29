---
tags: [atlas, api, type/atlas, area/networking, area/performance, api/PlayerRemoving]
---
# PlayerRemoving

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PlayerRemoving` fires while the `Player` object is still valid, so you can read its state and save it before dropping the...
> - Avoid: Not waiting for `PlayerRemoving` saves in `BindToClose` (Last player in an emptying server loses progress) (Saving...
> - Avoid: `BindToClose` and `PlayerRemoving` saving the same profile... -> Per-player save serialisation; idempotent saves.
> - Avoid: Per-player tables with no `PlayerRemoving` cleanup.
>
> Cost: TL;DR ~150 tok · whole note ~910 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PlayerRemoving` fires while the `Player` object is still valid, so you can read its state and save it before dropping the reference. (from [[Cookbook - Players and Characters]])

API snapshot: member of `Players` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Not waiting for `PlayerRemoving` saves in `BindToClose` (Last player in an emptying server loses progress) ([[Saving Correctly - Autosave and BindToClose]])
- Avoid: `BindToClose` and `PlayerRemoving` saving the same profile... -> Per-player save serialisation; idempotent saves. ([[Server Lifecycle and Shutdown]])
- Avoid: Per-player tables with no `PlayerRemoving` cleanup. ([[Memory Budgets and Leaks]])
- Every system with connections has a cleanup owner and uses `Destroying`/`PlayerRemoving`. ([[Memory Budgets and Leaks]])
- Avoid: Rewarding in the wave loop and in `PlayerRemoving` without a guard. ([[Tower Defense Waves and Placement End to End]])

## Mentioned in

48 notes in 19 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Functions Closures and Upvalues]] · [[Metatables and OOP - When and When Not]]

### 03 Architecture and Networking
[[Interest Management and Per-Player Replication]] · [[Rate Limiting and Abuse Prevention]] · [[Server Lifecycle and Shutdown]]

### 04 Data and Persistence
[[Saving Correctly - Autosave and BindToClose]]

### 12 Performance Testing and Debugging
[[Developer Console and Stats]] · [[Hunting Memory Leaks Step by Step]] · [[Memory Budgets and Leaks]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[Autoclicker and Macro Detection for Combat Remotes]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]] · [[Debugging Race Conditions and Yield Order]]

### 24 Worked Builds
[[Global Leaderboards End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]] · [[Cookbook - Players and Characters]] · [[Cookbook - Remotes and Networking]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Steal a Brainrot]]

### 41 Multiplayer Services
[[Session State Across Places]]

### 43 Genre Systems End to End
[[Tower Defense Waves and Placement End to End]] · [[Tycoon Plots and Droppers End to End]]

### 46 Resource Library
[[Links - DataStoreService]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

Also mentioned in (not linked): Developer Products and ProcessReceipt · Genre Systems Start Here · Horror Monster Chase AI End to End · In-Game Bug Report Button with Automatic Context · Instanced Interiors - Pooled House and Room Copies for Many Players · LihFolk Systems - Data and Purchase Guarantees · Load and Soak Testing Servers - Long Sessions and Many Clients · Luau Cookbook Start Here · Luau Garbage Collection and the Memory Model · Luau Performance and Native Codegen · Map Voting and Rotation for Round Games · Matchmaking Queues with MemoryStore · Physics Performance · Rate Limiting · Remote Abuse Patterns and Rate Limiting in Practice · RemoteEvents RemoteFunctions and Unreliable Remotes · Round-Based Minigame Loop End to End · Session Locking and Profile Libraries · Squad AI - Attack Tokens, Flanking and Attacker Limits · Teleporting and Multi-Place Games · Testing Your Own Remotes - Fuzzing and Abuse Tests · Trading Systems Without Duplication · Weekend Build - Roleplay Town with Jobs and Paychecks

<!-- atlas:generated -->
