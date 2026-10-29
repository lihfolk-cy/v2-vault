---
tags: [atlas, concept, type/atlas, area/design, area/monetization]
---
# Live Ops

<!-- tldr:start -->
> [!tldr] TL;DR
> - Live ops is everything you do after launch to keep a game fresh: content updates, timed events, rotating offers, codes...
> - Platform and schedules: Live Ops Events and Updates, Global State and Live Config, Live Content Pipeline, Cross-Server...
> - Show the diff and confirm. A live-ops tool that writes without a confirmation step will eventually write the wrong thing.
> - Keep daily mission state keyed by UTC day number so every server agrees when the day rolls (see the schedule module in Live...
>
> Cost: TL;DR ~170 tok · whole note ~1.2k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Live ops is everything you do after launch to keep a game fresh: content updates, timed events, rotating offers, codes, notifications. (from [[Live Ops Events and Updates]])

## Key facts

- Platform and schedules: Live Ops Events and Updates, Global State and Live Config, Live Content Pipeline, Cross-Server Messaging, MemoryStore Service. ([[Live Ops Deep Dive Start Here]])
- Show the diff and confirm. A live-ops tool that writes without a confirmation step will eventually write the wrong thing. ([[Live Content Pipeline]])
- Keep daily mission state keyed by UTC day number so every server agrees when the day rolls (see the schedule module in Live Ops Events and Updates). ([[Battle Pass and Season Design]])
- Live Ops Events and Updates: global events built on schedules plus messages. ([[Cross-Server Messaging]])

## Mentioned in

89 notes in 26 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Cross-Server Messaging]]

### 04 Data and Persistence
[[Global State and Live Config]] · [[Open Cloud APIs]]

### 10 Game Design and Genres
[[Boss Fight Design Patterns]] · [[Retention and Return Hooks]]

### 11 Monetization Publishing and Live Ops
[[Analytics and Funnels]] · [[Discovery and the Algorithm]] · [[Live Ops Events and Updates]] · [[Thumbnails Icons and Store Page]]

### 17 Pipelines
[[Live Content Pipeline]]

### 24 Worked Builds
[[Codes Redemption System End to End]]

### 26 Community and Moderation
[[Discord Servers for Roblox Games]]

### 27 Marketing and Growth
[[Update Cadence and Hype Cycles]]

### 28 Business and Careers
[[Running a Small Studio as a Business]]

### 32 Case Studies of Top Roblox Games
[[Case Study - 99 Nights in the Forest]] · [[Case Study - Adopt Me]] · [[Case Study - Dress to Impress]]

### 36 Narrative and Worldbuilding
[[Lore Delivery Without Walls of Text]]

### 38 Live Ops Deep Dive
[[Battle Pass and Season Design]] · [[Event Calendars and Content Planning]] · [[Limited-Time Offers - Design and Ethics]] · [[Live Ops Deep Dive Start Here]] · [[Patch Notes and Player Communication]]

### 49 Roblox Platform Features
[[Experience Notifications and Return Prompts]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): 000 Home · A-B Testing and Experiments on Roblox · Build Test and Release Pipeline · Case Study - Blox Fruits · Case Study - Brookhaven RP · Case Study - Grow a Garden · Case Study - Jailbreak · Case Study - Steal a Brainrot · Case Study - Tower Defense Simulator · Commissions Pricing and Contracts · Community Building · Crash and Error Telemetry · Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks · Currency Architecture - Soft Hard and Event Currencies · Documentation and Knowledge Bases · Economy Design Start Here · Economy Inflation Sinks and Faucets Math · Economy Resets and Seasonal Wipes · Feature Flags · Feature Flags and Staged Rollouts · Gated Tester Commands and Debug Panels · Genre Playbook - Roleplay and Social Hangouts · High-Craft Teardowns Start Here · In-Game Bug Report Button with Automatic Context · Launch Strategy - The First Two Weeks · Lighting Mood and Time of Day · Links - Analytics · Links - Badges · Links - Community and social · Links - Settings and publishing · Links - Store page · Live Incident Response and Post-Mortems · Lobby and Hub Design · Marketing and Growth Start Here · MemoryStore Service · Monetization Overview · Multiplayer Services Start Here · Notification and Toast Systems · OrderedDataStores and Leaderboards · Platform Features Start Here · Publishing an Experience · QA Checklists Before Release · Quest Writing and Hooks · Release Process and Rollbacks · Resource Library Start Here · Roadmaps Milestones and Scope Control · Roblox Policies Ratings and Compliance · Scoping and Roles for Small Teams · Server Lifecycle and Shutdown · Server Shutdowns Soft Updates and Migration · Short-Form Video Marketing · Teardown - BedWars · Teardown - Escape Tsunami for Brainrots · Teardown - Jujutsu Shenanigans · Teardown - Plants vs Brainrots · Teardown - Sol's RNG · Teardown - Tower of Hell · Testing Time-Based Features with a Controllable Clock · Top Games Case Studies Start Here · Viral Game Anatomy - Hooks, Loops and Timing · Viral and Trend Teardowns Start Here · Weather System Architecture - State Machine, Transitions and Replication · What Craft Looks Like on Roblox - Lessons from Top Studios · Working with Content Creators

<!-- atlas:generated -->
