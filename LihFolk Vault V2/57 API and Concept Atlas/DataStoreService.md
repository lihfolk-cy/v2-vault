---
tags: [atlas, api, type/atlas, area/data, area/gameplay, api/DataStoreService]
---
# DataStoreService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `DataStoreService` is the only durable, cross-server storage built into the engine.
> - Roblox code tends to reach straight for globals: `DataStoreService:GetDataStore(...)` inside the inventory module, `os.time()`...
> - Budget check. Print `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)` before and after...
> - Call it once per type at server start (Roblox docs, DataStoreService reference, October 2026).
>
> Cost: TL;DR ~150 tok · whole note ~800 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`DataStoreService` is the only durable, cross-server storage built into the engine. (from [[DataStore Fundamentals]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Roblox code tends to reach straight for globals: `DataStoreService:GetDataStore(...)` inside the inventory module, `os.time()`... ([[Dependency Injection in Luau]])
- Budget check. Print `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)` before and after a write cycle to see the budget move (Debugging DataStore Problems). ([[Global Leaderboards End to End]])
- Call it once per type at server start (Roblox docs, DataStoreService reference, October 2026). ([[Data and Cloud Changes 2025-2026]])

## Mentioned in

45 notes in 21 sections. The 25 most relevant are linked:

### 04 Data and Persistence
[[Data Loss Prevention and Recovery]] · [[DataStore Fundamentals]] · [[Global State and Live Config]] · [[OrderedDataStores and Leaderboards]] · [[Session Locking and Profile Libraries]]

### 11 Monetization Publishing and Live Ops
[[Developer Products and ProcessReceipt]]

### 13 Production and Case Studies
[[Live Incident Response and Post-Mortems]] · [[Release Process and Rollbacks]]

### 17 Pipelines
[[Live Content Pipeline]]

### 22 Anti-Exploit and Security
[[Logging Bans and Appeals]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Global Leaderboards End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]]

### 26 Community and Moderation
[[Player Reports and In-Game Moderation]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 41 Multiplayer Services
[[Reserved and Private Servers in Practice]]

### 46 Resource Library
[[Official Docs - Data and Persistence]]

### 48 Economy Design Deep Dive
[[Economy Telemetry and Balancing Live]]

### 49 Roblox Platform Features
[[Data and Cloud Changes 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Friend Invites Referrals and Experience Invites]]

### 62 Engine Reference Cards
[[DataStoreService - Engine Reference Card]]

Also mentioned in (not linked): A Stuck Player Watchdog That Logs the Cause · Automated Testing with TestEZ and Jest-Lua · Dependency Injection in Luau · Engine Reference Cards Start Here · Engine and API Changes 2025-2026 · Error Handling and Retries · HttpService and External APIs · MemoryStoreService - Engine Reference Card · Module Design and Dependency Injection · Reading Luau Errors and Stack Traces · Refunds Chargebacks and Purchase Support · Resetting One Player's Data Safely · Round-Based Minigame Loop End to End · Saved Inventory End to End · Schema Migrations - Worked Case Studies · Serial-Numbered Limited Items - Atomic Counters · Session Lock · Skill - Roblox DataStore Safety · Trading Systems Without Duplication · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
