---
tags: [atlas, api, type/atlas, area/data, area/gameplay, api/UpdateAsync]
---
# UpdateAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UpdateAsync` is the workhorse. (from DataStore Fundamentals)
> - Avoid: `GetAsync` then `SetAsync` for player data -> `UpdateAsync` plus session locking.
> - Player data is written only through one module, with `UpdateAsync` and a session lock.
> - Saves use `UpdateAsync` and respect ownership.
>
> Cost: TL;DR ~110 tok · whole note ~880 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UpdateAsync` is the workhorse. (from [[DataStore Fundamentals]])

API snapshot: member of `GlobalDataStore`, `MemoryStoreHashMap`, `MemoryStoreSortedMap`, `PackageService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `GetAsync` then `SetAsync` for player data -> `UpdateAsync` plus session locking. ([[DataStore Fundamentals]])
- Player data is written only through one module, with `UpdateAsync` and a session lock. ([[DataStore Fundamentals]])
- Saves use `UpdateAsync` and respect ownership. ([[Cookbook - Data and Saving]])
- Items duplicated after teleports: No lease, or saves not fenced -> Search for `SetAsync` / unfenced `UpdateAsync` on player keys. ([[Session Locking and Profile Libraries]])
- Lease written and checked inside the same `UpdateAsync` as the data. ([[Session Locking and Profile Libraries]])

## Mentioned in

54 notes in 19 sections. The 25 most relevant are linked:

### 04 Data and Persistence
[[Data Loss Prevention and Recovery]] · [[DataStore Fundamentals]] · [[MemoryStore Service]] · [[OrderedDataStores and Leaderboards]] · [[Saving Correctly - Autosave and BindToClose]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[Session Locking and Profile Libraries]]

### 11 Monetization Publishing and Live Ops
[[Developer Products and ProcessReceipt]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Global Leaderboards End to End]] · [[Saved Inventory End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 33 Level Design
[[Playtest Heatmaps - Position and Death Maps]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Session State Across Places]]

### 48 Economy Design Deep Dive
[[Economy Telemetry and Balancing Live]] · [[Player-Driven Trading Economies]]

### 49 Roblox Platform Features
[[Data and Cloud Changes 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Experience Notifications and Return Prompts]] · [[Friend Invites Referrals and Experience Invites]]

### 52 Core Concepts
[[Session Lock]]

### 62 Engine Reference Cards
[[DataStoreService - Engine Reference Card]]

Also mentioned in (not linked): A Stuck Player Watchdog That Logs the Cause · Cross-Server Messaging · Data Schema Design and Migrations · Debugging DataStore Problems · Error Handling and Retries · Global State and Live Config · LihFolk Systems - Data and Purchase Guarantees · LihFolk Systems Library · Limited-Time Offers - Design and Ethics · Logging Bans and Appeals · Luau Cookbook Start Here · MarketplaceService - Engine Reference Card · MemoryStoreService - Engine Reference Card · Multiplayer Services Start Here · Open Cloud APIs · Open Questions - Whole Vault · Parties and Group Teleports · Pet Hatching and Following End to End · Purchase Data and Receipts · Quest Chain System End to End · Rebirth and Prestige System End to End · Reserved and Private Servers in Practice · Round-Based Minigame Loop End to End · Server Browsers and Server Lists · Skill - Roblox DataStore Safety · Skill - Roblox Vault Research · Tower Defense Waves and Placement End to End · Trading Systems Without Duplication · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
