---
tags: [atlas, concept, type/atlas, area/gameplay, area/networking]
---
# Cooldowns

<!-- tldr:start -->
> [!tldr] TL;DR
> - A cooldown has two clocks: the client's (starts when the button is pressed) and the server's (starts when the request arrives...
> - Cooldown sweep lags behind: Waits for server reply -> Predict, then correct to server time.
> - Ability used twice on lag: Client-owned cooldown -> Server timestamp gate.
> - Server cooldowns have a small tolerance; cooldown ends are sent in server time.
>
> Cost: TL;DR ~140 tok · whole note ~1.6k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A cooldown has two clocks: the client's (starts when the button is pressed) and the server's (starts when the request arrives, about half a round trip later). (from [[Client Prediction and Reconciliation for Combat]])

## Key facts

- Cooldown sweep lags behind: Waits for server reply -> Predict, then correct to server time. ([[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]])
- Ability used twice on lag: Client-owned cooldown -> Server timestamp gate. ([[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]])
- Server cooldowns have a small tolerance; cooldown ends are sent in server time. ([[Client Prediction and Reconciliation for Combat]])
- Rules (costs, cooldowns, shapes) live in one shared module. ([[Client Prediction and Reconciliation for Combat]])
- Avoid: Client-trusted hits -> Validate range, cooldown, state and target count. ([[Genre Playbook - Battlegrounds and Arena Fighters]])

## Mentioned in

118 notes in 35 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]] · [[Rate Limiting and Abuse Prevention]] · [[Server Authority and Validation]]

### 08 Animation
[[Ability Kits Architecture]] · [[Combat Combo Systems]] · [[Stance and Charge Moves]]

### 09 Gameplay Systems
[[Behaviour Trees Utility AI and State Machines for NPCs]]

### 10 Game Design and Genres
[[Boss Fight Design Patterns]] · [[Genre Playbook - Battlegrounds and Arena Fighters]]

### 12 Performance Testing and Debugging
[[In-Game Bug Report Button with Automatic Context]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[Autoclicker and Macro Detection for Combat Remotes]] · [[Detecting Combat Exploits - Reach Rate and Aim]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]]

### 24 Worked Builds
[[Quest Chain System End to End]]

### 29 Luau Cookbook
[[Cookbook - Tables Strings and Time]]

### 35 Advanced Luau
[[Custom Schedulers and Coroutine Patterns]]

### 42 Accessibility and Inclusive Design
[[Difficulty Options and Cognitive Load]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 48 Economy Design Deep Dive
[[Player-Driven Trading Economies]] · [[Pricing Curves and Upgrade Costs]]

### 52 Core Concepts
[[Rate Limiting]]

### 58 Player QoL and Game Tweaks
[[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Top 25 QoL Wins by Effort]]

Also mentioned in (not linked): 2D Multiplayer - Server Authority and Replicating GUI Worlds · A Stuck Player Watchdog That Logs the Cause · AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses · AI Pitfalls - Stale APIs and Luau · Accessibility Cross-Links for QoL Settings · Aim Assist and Generous Hitboxes · Animation Review Checklist · Avatar Context Menus Profiles and Social Surfaces · Building a Portfolio as a Roblox Developer · Cars with Constraints - Suspension Steering and Drive · Case Study - Adopt Me · Case Study - Enemy Roster Rebuild · Case Study - Murder Mystery 2 · Case Study - Steal a Brainrot · Centre of Mass, Anti-Flip and Self-Righting · Character Select and Class Systems with Different Rigs · Client Hit Prediction for Melee Feedback · Client-Server Model · Combat Animation Craft · Combat Systems Architecture · Cookbook - Players and Characters · Cookbook - Remotes and Networking · Custom Character Controllers · Data and Config Pipeline - Spreadsheets to Game · DataStore Fundamentals · Economies and Currencies · Emotes and Social Animation · Entity Component Systems · Exploits and Anti-Cheat · Feedback - Autosave Indicator Ping Display and Error Toasts · Frame Order and RunService Timing · Functions Closures and Upvalues · Game Feel Start Here · Genre Playbook - Combat and RPG · Genre Playbook - Open-World City and Crime Roleplay · Genre Playbook - Sports · Genre Playbook - Tower Defense · Genre QA Passes - Test Checklists per Game Type · Hitboxes and Hit Detection · Hold-to-Attack Input That Never Sticks · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · HttpService and External APIs · Hunting Memory Leaks Step by Step · In-Game AI - LLM NPCs and Text Generation · Input Buffering · Instances Attributes and Tags · Interest Management and Per-Player Replication · Joining Friends Parties and Private Servers · Live Ops Events and Updates · MCP Workflows for Scripting and Debugging · Melee Combat System End to End · Metatables and OOP - When and When Not · Module Design and Dependency Injection · Mounts and Rideable Creatures · Multi-Client and Live Testing · NPC AI and Behaviour · Open Questions - Whole Vault · Pet Hatching and Following End to End · Physics Assemblies and Constraints · Player QoL Start Here · Player Reports and In-Game Moderation · Policy and Age Rules 2026 · Principles of Animation for Games · Progression Levels and Unlocks · Project Structure and Bootstrapping · Prompting and Verifying AI Output · QoL Audit Checklist · Quick Respawn and Spawn Protection · Rebirth and Prestige System End to End · RemoteEvents RemoteFunctions and Unreliable Remotes · Reserved and Private Servers in Practice · Retention and Return Hooks · Roblox Communities as Your On-Platform Hub · Roblox Generative AI - Cube Mesh and Texture Generation · Roblox Studio Assistant · Robux Price Points and Offer Design · Ropes Chains and Soft Bodies · Server Authority · Server Hop Rejoin and Server Lists with Ping · Session State Across Places · Simulator and RNG Genre Teardown · Spawn Director - Credit Budgets and Player-Count Scaling · Squad AI - Attack Tokens, Flanking and Attacker Limits · Status Effects Buffs and Stacking Rules · Testing Time-Based Features with a Controllable Clock · Threat Modeling a Roblox Game · UI Motion Language and Timing · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer · Vehicle Damage, Repair and Wreck States · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Weekend Build - Arena Shooter with Server-Checked Hits · Writing Dialogue for Roblox Players

<!-- atlas:generated -->
