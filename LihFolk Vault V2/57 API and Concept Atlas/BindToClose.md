---
tags: [atlas, api, type/atlas, area/data, area/gameplay, api/BindToClose]
---
# BindToClose

<!-- tldr:start -->
> [!tldr] TL;DR
> - `BindToClose` runs a function on close, but per the docs "the widget closes and its Enabled property becomes false even when a...
> - Avoid: No `BindToClose` (Every update or shutdown loses up to one autosave interval for...) (Saving Correctly - Autosave and...
> - Avoid: Saving players one by one in `BindToClose` (Large servers time out; the last players lose data) (Saving Correctly...
> - Avoid: One sequential save loop in `BindToClose` -> Parallel saves with a deadline.
>
> Cost: TL;DR ~160 tok · whole note ~1.4k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`BindToClose` runs a function on close, but per the docs "the widget closes and its Enabled property becomes false even when a function is bound, so the function can't prevent or delay closing." It is a hook for saving, not a confirmation dialog. (from [[Plugin UI with DockWidgets]])

BindToClose: Server shutdown callback; up to 30 s to save. (from [[Glossary]])

API snapshot: member of `DataModel`, `PluginGui` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: No `BindToClose` (Every update or shutdown loses up to one autosave interval for...) ([[Saving Correctly - Autosave and BindToClose]])
- Avoid: Saving players one by one in `BindToClose` (Large servers time out; the last players lose data) ([[Saving Correctly - Autosave and BindToClose]])
- Avoid: One sequential save loop in `BindToClose` -> Parallel saves with a deadline. ([[Server Lifecycle and Shutdown]])
- Avoid: `BindToClose` and `PlayerRemoving` saving the same profile... -> Per-player save serialisation; idempotent saves. ([[Server Lifecycle and Shutdown]])
- Player data saved with `UpdateAsync` plus a session lock, on leave and in `game:BindToClose`. ([[DataStoreService - Engine Reference Card]])

## Mentioned in

92 notes in 38 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling and Retries]]

### 03 Architecture and Networking
[[Server Lifecycle and Shutdown]]

### 04 Data and Persistence
[[Data Loss Prevention and Recovery]] · [[DataStore Fundamentals]] · [[HttpService and External APIs]] · [[Saving Correctly - Autosave and BindToClose]] · [[Session Locking and Profile Libraries]]

### 11 Monetization Publishing and Live Ops
[[Analytics and Funnels]]

### 12 Performance Testing and Debugging
[[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]] · [[Debugging Race Conditions and Yield Order]]

### 24 Worked Builds
[[LihFolk Systems - Data and Purchase Guarantees]] · [[Pet Hatching and Following End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 39 Studio Plugins and Tooling
[[Plugin UI with DockWidgets]]

### 41 Multiplayer Services
[[Reserved and Private Servers in Practice]] · [[Server Shutdowns Soft Updates and Migration]]

### 46 Resource Library
[[Official Docs - Data and Persistence]]

### 48 Economy Design Deep Dive
[[Economy Telemetry and Balancing Live]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

Also mentioned in (not linked): 00 Start Here · AI Skills Start Here · Accessibility Start Here · Automated Luau Checks - LihFolk Hook and Audit · Big Numbers Precision and Formatting · Build Test and Release Pipeline · Case Study - Adopt Me · Client-Server Model · Commissions Pricing and Contracts · Cookbook - Players and Characters · Core Loops and Session Design · Crash and Error Telemetry · Custom Schedulers and Coroutine Patterns · Daily Rewards System End to End · Data Schema Design and Migrations · Data and Cloud Changes 2025-2026 · DataStoreService - Engine Reference Card · Debugging Live Servers · Developer Products and ProcessReceipt · Difficulty Options and Cognitive Load · Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts · Events Signals and Connections · Feedback - Autosave Indicator Ping Display and Error Toasts · Genre Playbook - Survival and Crafting · Genre QA Passes - Test Checklists per Game Type · Glossary · Idempotency · In-Game Bug Report Button with Automatic Context · Infinite and Streamed Worlds · Launch Strategy - The First Two Weeks · LihFolk Systems Library · Limited-Time Offers - Design and Ethics · Live Incident Response and Post-Mortems · Load and Soak Testing Servers - Long Sessions and Many Clients · Luau Cookbook Start Here · MemoryStore Service · MessagingService - Engine Reference Card · Mobile and Low-End Optimization · Multiplayer Services Start Here · Obby Checkpoints and Stage Saves End to End · OrderedDataStores and Leaderboards · Places Universes and Experience Settings · Players - Engine Reference Card · Playtest Heatmaps - Position and Death Maps · Purchase Data and Receipts · QA Checklists Before Release · Quest Chain System End to End · Rate Limiting and Abuse Prevention · Release Process and Rollbacks · Resetting One Player's Data Safely · Running a Small Studio as a Business · Schema Migrations - Worked Case Studies · Server Browsers and Server Lists · Server Hop Rejoin and Server Lists with Ping · Session Lock · Session State Across Places · Settings Menu Design for Roblox - Layout, Controls and Motion · Settings Menu Essentials and Persistence · Skill - Roblox DataStore Safety · Story State Flags and Chapter Saves · Testing Your Own Remotes - Fuzzing and Abuse Tests · Trading Systems Without Duplication · Tycoon Plots and Droppers End to End · Undo and ChangeHistoryService Done Right · Weekend Build - Survival Gather, Craft and Place · Worked Builds Start Here · Working with Content Creators

<!-- atlas:generated -->
