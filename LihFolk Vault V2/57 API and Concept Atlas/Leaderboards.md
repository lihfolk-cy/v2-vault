---
tags: [atlas, concept, type/atlas, area/data, area/design]
---
# Leaderboards

<!-- tldr:start -->
> [!tldr] TL;DR
> - Leaderboards are public data about players.
> - Autosaves staggered; leaderboards and counters batched.
> - Avoid: Templates for the main store only (Leaderboards, settings, old `_vN` stores still hold the data) (Player Privacy and...
> - A leaderboard is two systems. The OrderedDataStore holds the ranking; the player's real data (in their profile) holds the truth.
>
> Cost: TL;DR ~130 tok · whole note ~1.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Leaderboards are public data about players. Show only names Roblox gives you, remove users who ask for deletion, and remove flagged cheaters (Player Privacy and Data Deletion, Logging Bans and Appeals). (from [[Global Leaderboards End to End]])

A leaderboard is two systems. The OrderedDataStore holds the ranking; the player's real data (in their profile) holds the truth. (from [[OrderedDataStores and Leaderboards]])

## Key facts

- Autosaves staggered; leaderboards and counters batched. ([[Debugging DataStore Problems]])
- Avoid: Templates for the main store only (Leaderboards, settings, old `_vN` stores still hold the data) ([[Player Privacy and Data Deletion]])
- A leaderboard is two systems. The OrderedDataStore holds the ranking; the player's real data (in their profile) holds the truth. ([[OrderedDataStores and Leaderboards]])

## Mentioned in

98 notes in 32 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Cross-Server Messaging]]

### 04 Data and Persistence
[[DataStore Fundamentals]] · [[OrderedDataStores and Leaderboards]] · [[Saving Correctly - Autosave and BindToClose]] · [[Schema Migrations - Worked Case Studies]]

### 10 Game Design and Genres
[[Core Loops and Session Design]] · [[Genre Playbook - Obbies and Platformers]] · [[Genre Playbook - Racing and Driving]] · [[Genre Playbook - Sports]] · [[Social Design and Multiplayer Play]]

### 22 Anti-Exploit and Security
[[Autoclicker and Macro Detection for Combat Remotes]] · [[False Positives Lag and Fair Enforcement]] · [[Threat Modeling a Roblox Game]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]]

### 24 Worked Builds
[[Global Leaderboards End to End]] · [[Rebirth and Prestige System End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 33 Level Design
[[Lobby and Hub Design]]

### 38 Live Ops Deep Dive
[[Economy Resets and Seasonal Wipes]]

### 40 Game Math
[[Big Numbers Precision and Formatting]]

### 42 Accessibility and Inclusive Design
[[Difficulty Options and Cognitive Load]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]] · [[Racing Laps and Checkpoints End to End]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]]

Also mentioned in (not linked): 00 Start Here · 2D Multiplayer - Server Authority and Replicating GUI Worlds · AI Pitfalls - Data and Monetization · Accessibility Start Here · Arena Rounds with Teams and Spectating End to End · Case Study - Building a Game with AI Agents · Case Study - Rivals · Commissions Pricing and Contracts · Cookbook - UI · Data Loss Prevention and Recovery · Data Schema Design and Migrations · Data and Cloud Changes 2025-2026 · Detecting Movement Exploits - Speed Fly Noclip Teleport · Dot and Cross Products in Gameplay · Economies and Currencies · Error Handling - pcall xpcall and Promise Patterns · Error Handling and Retries · Ethical Design and Player Trust · Evaluating AI Tools - A Practical Rubric · Exploits and Anti-Cheat · First-Time User Experience and Onboarding · Game Math Start Here · Game Trailers and Clean Footage - Capture, Freecam and Editing · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Puzzle and Escape Rooms · Genre Playbook - Tower Defense · Genre Playbook - Tycoons · Genre Systems Start Here · HttpService and External APIs · Interest Management and Per-Player Replication · Kill Credit, Assists, Kill Feed and Death Recaps · Level Design for Roblox · LihFolk Systems - Data and Purchase Guarantees · LihFolk Systems Library · Live Ops Deep Dive Start Here · Localization · Logging Bans and Appeals · Luau Cookbook Start Here · Luau Performance and Native Codegen · MemoryStore Service · Multiple Agents in One Studio · Obby and Platforming Level Design · Open Cloud APIs · Player Privacy and Data Deletion · Player Reports and In-Game Moderation · Progression Levels and Unlocks · ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab · Purchase Data and Receipts · Race HUD - Position, Laps, Splits, Speedometer and Minimap · Release Process and Rollbacks · Remote Abuse Patterns and Rate Limiting in Practice · Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics · Reserved and Private Servers in Practice · Resetting One Player's Data Safely · Resource Library - Data and Persistence · Retention and Return Hooks · Round-Based Minigame Loop End to End · Saved Inventory End to End · Scoping and Roles for Small Teams · Script Performance · Session Locking and Profile Libraries · Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev · Skill - Roblox Anti-Exploit Review · Skill - Roblox System Builder · Tables Metatables and OOP · Team Roles and Workflows · Testing Modes - Play Run and Multi-Client · Testing Time-Based Features with a Controllable Clock · UI Layout Objects - Lists Grids and Pages · Vehicle Ownership and Anti-Exploit - Server-Checked Driving · Weekend Build - Arena Shooter with Server-Checked Hits · Worked Builds Start Here · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
