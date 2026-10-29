---
tags: [atlas, api, type/atlas, area/data, area/scripting, api/DataStore]
---
# DataStore

<!-- tldr:start -->
> [!tldr] TL;DR
> - DataStore bugs are the most expensive bugs in a Roblox game: they lose progress, duplicate items, and generate support tickets...
> - Every DataStore call is in `pcall` with bounded retries.
> - Avoid: Rate limit after expensive parsing or DataStore calls -> Rate limit first.
> - Avoid: Quoting per-server DataStore budgets as the limit, or the "6 second" per-key rule.
>
> Cost: TL;DR ~130 tok · whole note ~1.8k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

DataStore bugs are the most expensive bugs in a Roblox game: they lose progress, duplicate items, and generate support tickets you cannot answer. (from [[Debugging DataStore Problems]])

API snapshot: class, inherits `GlobalDataStore`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every DataStore call is in `pcall` with bounded retries. ([[Cookbook - Data and Saving]])
- Avoid: Rate limit after expensive parsing or DataStore calls -> Rate limit first. ([[Rate Limiting and Abuse Prevention]])
- Avoid: Quoting per-server DataStore budgets as the limit, or the "6 second" per-key rule. ([[Data and Cloud Changes 2025-2026]])
- DataStore throttling cascades: Immediate retries in a loop -> Backoff with jitter; attempt cap. ([[Error Handling and Retries]])
- Avoid: Wrapping a DataStore call in `pcall` but ignoring the success flag, then saving over data that failed to load. ([[Automated Luau Checks - LihFolk Hook and Audit]])

## Mentioned in

143 notes in 38 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Error Handling and Retries]]

### 03 Architecture and Networking
[[Cross-Server Messaging]] · [[Rate Limiting and Abuse Prevention]]

### 04 Data and Persistence
[[Data Loss Prevention and Recovery]] · [[Data Schema Design and Migrations]] · [[DataStore Fundamentals]] · [[OrderedDataStores and Leaderboards]] · [[Serial-Numbered Limited Items - Atomic Counters]]

### 12 Performance Testing and Debugging
[[Automated Luau Checks - LihFolk Hook and Audit]] · [[Automated Testing with TestEZ and Jest-Lua]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]]

### 17 Pipelines
[[Live Content Pipeline]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]] · [[Debugging Live Servers]]

### 24 Worked Builds
[[Codes Redemption System End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 33 Level Design
[[Playtest Heatmaps - Position and Death Maps]]

### 35 Advanced Luau
[[Serialization Formats for Saves and Networking]]

### 49 Roblox Platform Features
[[Data and Cloud Changes 2025-2026]] · [[Friend Invites Referrals and Experience Invites]]

### 56 Field Notes
[[A Stuck Player Watchdog That Logs the Cause]]

### Root notes
[[Open Questions - Whole Vault]] · [[Skill - Roblox DataStore Safety]]

Also mentioned in (not linked): 00 Start Here · AI Code Assistants for Luau · AI Pitfalls - Networking and Security · AI Skills Start Here · AI in Roblox Development Overview · AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well · Admin Commands Done Safely - Permissions and Audit Logs · Advanced Types - Generics and Type Functions · Agent Handoff Notes - Project State and Resume Templates · Agent Orchestration - Sub-Agents, Hooks and Skill Costs · Avatar Context Menus Profiles and Social Surfaces · AvatarEditorService and In-Game Avatar Editors · Big Numbers Precision and Formatting · Buffers and Binary Data · Build Test and Release Pipeline · Case Study - Adopt Me · Clip Archive Server · Code Review for Luau Teams · Commerce and Physical Goods · Cookbook - Remotes and Networking · Cookbook - Tables Strings and Time · Crash and Error Telemetry · Custom Schedulers and Coroutine Patterns · Data Schema Versioning · Data and Config Pipeline - Spreadsheets to Game · Debugging Race Conditions and Yield Order · Debugging Start Here · Dependency Injection in Luau · Developer Console and Stats · Developer Products and ProcessReceipt · Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts · Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins · Economies and Currencies · False Positives Lag and Fair Enforcement · Feature Flags · Feedback - Autosave Indicator Ping Display and Error Toasts · Field Notes Start Here · Functions Closures and Upvalues · Genre Playbook - Obbies and Platformers · Genre Playbook - Survival and Crafting · Genre Playbook - Tower Defense · Git and Source Control for Roblox · Global Leaderboards End to End · Global State and Live Config · Glossary · Grid Placement and Player Building Systems · How Exploits Work - The Client Boundary · HumanoidDescription and Outfit Systems · Idempotency · In-Game AI - LLM NPCs and Text Generation · In-Game Bug Report Button with Automatic Context · Infinite and Streamed Worlds · LihFolk Systems - Data and Purchase Guarantees · Links - Session locking and data safety · Live Incident Response and Post-Mortems · Load and Soak Testing Servers - Long Sessions and Many Clients · Logging Bans and Appeals · Luau Cookbook Start Here · MCP Workflows for Scripting and Debugging · MemoryStore Service · Metatables and OOP - When and When Not · Module Design and Dependency Injection · Module Scripts and Requiring · Motion Sensitivity and Camera Comfort · Multiplayer Services Start Here · Music and Adaptive Audio · Network Bandwidth Budgets and Measuring Them · Obby Checkpoints and Stage Saves End to End · Open Cloud APIs · Places Universes and Experience Settings · Player Privacy and Data Deletion · Player Reports and In-Game Moderation · Player-Driven Trading Economies · Progression and Pacing Design · Project Structure and Bootstrapping · Rate Limiting · Reading Luau Errors and Stack Traces · Rebirth and Prestige System End to End · Reference - Purple Anime Settings UI (Claude + Figma) · Release Process and Rollbacks · Remote Abuse Patterns and Rate Limiting in Practice · RemoteEvents RemoteFunctions and Unreliable Remotes · Reserved and Private Servers in Practice · Resetting One Player's Data Safely · Roblox Changes 2025-2026 · Round-Based Minigame Loop End to End · Save Migration Tests - Fixture Saves and Golden Files · Saved Inventory End to End · Saving Correctly - Autosave and BindToClose · Schema Migrations - Worked Case Studies · Seeds Determinism and Reproducible Worlds · Server Authority and Validation · Server Lifecycle and Shutdown · Session Lock · Session Locking and Profile Libraries · Settings Menu Essentials and Persistence · Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev · Skill - Roblox Anti-Exploit Review · Skill - Roblox Debugging · Skill - Roblox Monetization Compliance · Skill - Roblox System Builder · Strings Patterns and Formatting · Tables Metatables and OOP · Task Library Coroutines and Yielding · Team Create Permissions and Workflows · Teleporting and Multi-Place Games · Template Reskin Checklist - One Codebase, New Game · Testing Modes - Play Run and Multi-Client · Testing Your Own Remotes - Fuzzing and Abuse Tests · The Debugging Method - Reproduce Isolate Bisect · Threat Modeling a Roblox Game · Token Cost Benchmarks · Tools and Inventory Systems · Trading Systems Without Duplication · Version History and Backups · Virtualized Lists and Large Inventories · Weekend Build - Survival Gather, Craft and Place · Working with Content Creators

<!-- atlas:generated -->
