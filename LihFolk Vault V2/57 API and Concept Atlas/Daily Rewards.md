---
tags: [atlas, concept, type/atlas, area/gameplay, area/design]
---
# Daily Rewards

<!-- tldr:start -->
> [!tldr] TL;DR
> - Daily rewards look trivial and generate a surprising share of support tickets.
> - Daily reward: server-timed, mark-then-pay, saved at once, throttled, grace considered.
> - Daily reward bugs only appear at midnight: `os.time()` called directly -> Inject `now` (Module Design and Dependency Injection)
> - Saving `tick()` or `os.clock()`. Symptom: daily rewards unlock instantly or never after a server change.
>
> Cost: TL;DR ~140 tok · whole note ~850 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Daily rewards look trivial and generate a surprising share of support tickets. (from [[Daily Rewards System End to End]])

## Key facts

- Daily reward: server-timed, mark-then-pay, saved at once, throttled, grace considered. ([[Retention and Return Hooks]])
- Daily reward bugs only appear at midnight: `os.time()` called directly -> Inject `now` ([[Module Design and Dependency Injection]])
- Saving `tick()` or `os.clock()`. Symptom: daily rewards unlock instantly or never after a server change. ([[Cookbook - Tables Strings and Time]])
- Daily reward: claim, `+1d`, claim; `+2d`, claim (streak rule); rejoin between claims (Daily Rewards System End to End). ([[Testing Time-Based Features with a Controllable Clock]])

## Mentioned in

52 notes in 29 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Client-Server Model]]

### 09 Gameplay Systems
[[Economies and Currencies]]

### 10 Game Design and Genres
[[Core Loops and Session Design]] · [[Retention and Return Hooks]] · [[Simulator and RNG Genre Teardown]]

### 11 Monetization Publishing and Live Ops
[[Discovery and the Algorithm]]

### 12 Performance Testing and Debugging
[[Testing Time-Based Features with a Controllable Clock]]

### 13 Production and Case Studies
[[Case Study - Phone UI Overhaul]]

### 15 AI Tools
[[Evaluating AI Tools - A Practical Rubric]]

### 16 MCP and Agents
[[Case Study - Building a Game with AI Agents]]

### 21 LihFolk UI Design System
[[LihFolk UI Design System]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Daily Rewards System End to End]] · [[Saved Inventory End to End]]

### 27 Marketing and Growth
[[Competitor Analysis Method]] · [[Launch Strategy - The First Two Weeks]]

### 28 Business and Careers
[[Building a Portfolio as a Roblox Developer]]

### 29 Luau Cookbook
[[Cookbook - Tables Strings and Time]]

### 35 Advanced Luau
[[Module Design and Dependency Injection]]

### 38 Live Ops Deep Dive
[[Battle Pass and Season Design]]

### 49 Roblox Platform Features
[[Experience Notifications and Return Prompts]]

### 52 Core Concepts
[[Dependency Injection in Luau]] · [[Idempotency]]

### 59 Viral and Trend Game Teardowns
[[Teardown - Tap Simulator REBORN]]

Also mentioned in (not linked): 00 Start Here · Debugging UI Layout and Input · Difficulty Options and Cognitive Load · Event Calendars and Content Planning · First-Time User Experience and Onboarding · Genre Playbook - Roleplay and Social Hangouts · Hard-Surface Modeling · LihFolk Systems Library · Live Content Pipeline · Live Ops Deep Dive Start Here · Live Ops Events and Updates · Loading Screen Skip and First-Session Goals · Localization-Ready Writing · Luau Cookbook Start Here · Modeling Weapons and Props · Modeling in Blender for Roblox · Monetization Overview · Multi-Client and Live Testing · Notification and Toast Systems · Pricing and Store Design · Quest Chain System End to End · Seeds Determinism and Reproducible Worlds · Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev · Skill - Roblox System Builder · Skill - Roblox UI Builder · Testing Your Own Remotes - Fuzzing and Abuse Tests · Worked Builds Start Here

<!-- atlas:generated -->
