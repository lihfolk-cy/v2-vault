---
tags: [atlas, concept, type/atlas, area/gameplay, area/security]
---
# Item Duplication

<!-- tldr:start -->
> [!tldr] TL;DR
> - A dupe shows as a spike in a source that should be flat (often "trade" or an obscure reward).
> - "Sell, buy, undo" dupes coins: Undo ignores spent proceeds -> Refuse undo when balance is short.
> - Testing only success paths; dupes live in failure and latency.
> - Cheap, and losing an item is recoverable from logs, while a dupe spreads.
>
> Cost: TL;DR ~130 tok · whole note ~1.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A dupe shows as a spike in a source that should be flat (often "trade" or an obscure reward). (from [[Economy Exploits - Dupes Races and Purchase Abuse]])

## Key facts

- "Sell, buy, undo" dupes coins: Undo ignores spent proceeds -> Refuse undo when balance is short. ([[Confirmation and Undo Patterns for Destructive and Paid Actions]])
- Testing only success paths; dupes live in failure and latency. ([[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]])
- Cheap, and losing an item is recoverable from logs, while a dupe spreads. ([[Economy Exploits - Dupes Races and Purchase Abuse]])
- Unique ids make dupes visible. Two items with the same `uid` in different inventories is proof of a duplication bug. ([[Procedural Loot and Item Generation]])

## Mentioned in

76 notes in 31 sections. The 25 most relevant are linked:

### 04 Data and Persistence
[[Schema Migrations - Worked Case Studies]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[Session Locking and Profile Libraries]] · [[Trading Systems Without Duplication]]

### 09 Gameplay Systems
[[Economies and Currencies]] · [[Police Chases and Wanted Levels]]

### 10 Game Design and Genres
[[Genre Playbook - Survival and Crafting]]

### 12 Performance Testing and Debugging
[[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Genre QA Passes - Test Checklists per Game Type]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Logging Bans and Appeals]] · [[Threat Modeling a Roblox Game]]

### 24 Worked Builds
[[Global Leaderboards End to End]] · [[Pet Hatching and Following End to End]] · [[Saved Inventory End to End]] · [[Weekend Build - Survival Gather, Craft and Place]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 34 Procedural Generation
[[Procedural Loot and Item Generation]]

### 38 Live Ops Deep Dive
[[Economy Resets and Seasonal Wipes]]

### 48 Economy Design Deep Dive
[[Economy Telemetry and Balancing Live]] · [[Player-Driven Trading Economies]]

### 52 Core Concepts
[[Session Lock]]

### 58 Player QoL and Game Tweaks
[[Confirmation and Undo Patterns for Destructive and Paid Actions]]

Also mentioned in (not linked): 00 Start Here · Anti-Exploit Start Here · Big Numbers Precision and Formatting · Case Study - Adopt Me · Case Study - Blox Fruits · Case Study - Jailbreak · Codes Redemption System End to End · Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop · Currency Architecture - Soft Hard and Event Currencies · Debugging Race Conditions and Yield Order · Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts · Drag-and-Drop Inventories and Sliders with UIDragDetector · Economy Design Start Here · Economy Inflation Sinks and Faucets Math · Event Calendars and Content Planning · Exploits and Anti-Cheat · False Positives Lag and Fair Enforcement · Friend Invites Referrals and Experience Invites · Functions Closures and Upvalues · Gated Tester Commands and Debug Panels · Genre Playbook - Tower Defense · How Exploits Work - The Client Boundary · HttpService and External APIs · Idempotency · Inventory QoL - Sort Filter Search Stack and Lock · Launch Strategy - The First Two Weeks · LihFolk Systems - Data and Purchase Guarantees · OrderedDataStores and Leaderboards · Pricing Curves and Upgrade Costs · Procedural Generation Start Here · QoL Audit Checklist · Quest Chain System End to End · Rate Limiting and Abuse Prevention · Rebirth and Prestige System End to End · Remote Abuse Patterns and Rate Limiting in Practice · Roadmaps Milestones and Scope Control · Running a Small Studio as a Business · Save Migration Tests - Fixture Saves and Golden Files · Server Authority · Server Authority and Validation · Shop with Game Passes and Developer Products End to End · Simulating an Economy Before Launch · Skill - Roblox Anti-Exploit Review · Teardown - Apocalypse Rising 2 · Teardown - Piggy · Testing Your Own Remotes - Fuzzing and Abuse Tests · Tools and Inventory Systems · Tycoon Plots and Droppers End to End · UI Automation with VirtualInput and StudioTestService · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Viral Game Anatomy - Hooks, Loops and Timing

<!-- atlas:generated -->
