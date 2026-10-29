---
tags: [atlas, concept, type/atlas, area/design, area/ui]
---
# Quests

<!-- tldr:start -->
> [!tldr] TL;DR
> - A quest is a mechanic (a counter, a condition, a reward) wrapped in words.
> - Avoid: Saving the quest index. It breaks on the first content update.
> - Avoid: One giant `if kind == ... elseif` per quest.
> - Every quest has a distinct 2 to 4 word title.
>
> Cost: TL;DR ~100 tok · whole note ~1.7k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A quest is a mechanic (a counter, a condition, a reward) wrapped in words. (from [[Quest Writing and Hooks]])

Quests are saved state; changing definitions breaks saves unless planned. (from [[Quests and Objectives]])

## Key facts

- Avoid: Saving the quest index. It breaks on the first content update. ([[Quest Chain System End to End]])
- Avoid: One giant `if kind == ... elseif` per quest. ([[Quest Chain System End to End]])
- Every quest has a distinct 2 to 4 word title. ([[Quest Writing and Hooks]])
- Avoid: Quest code inside combat code -> Signal bus. ([[Quests and Objectives]])
- First quest and first level up within two minutes. ([[Case Study - Blox Fruits]])
- Each island has a level band, quests and a boss. ([[Case Study - Blox Fruits]])

## Mentioned in

145 notes in 38 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Instance Streaming]]

### 05 UI and UX
[[HUD Design]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Notification and Toast Systems]]

### 09 Gameplay Systems
[[Combat Systems Architecture]] · [[Economies and Currencies]] · [[Quests and Objectives]]

### 10 Game Design and Genres
[[Core Loops and Session Design]] · [[First-Time User Experience and Onboarding]] · [[Progression and Pacing Design]] · [[Retention and Return Hooks]]

### 24 Worked Builds
[[LihFolk Systems Library]] · [[Melee Combat System End to End]] · [[Quest Chain System End to End]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Blox Fruits]] · [[Case Study - Dress to Impress]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Naming Items Zones and Abilities]] · [[Narrative Start Here]] · [[Quest Writing and Hooks]] · [[Story State Flags and Chapter Saves]] · [[Writing Dialogue for Roblox Players]]

### 49 Roblox Platform Features
[[Console and VR Release Checklists]]

### 52 Core Concepts
[[Event Bus]]

### 59 Viral and Trend Game Teardowns
[[Teardown - Bee Swarm Simulator]]

Also mentioned in (not linked): 00 Start Here · Advanced Types - Generics and Type Functions · Badges and Achievement Design · Balancing with Spreadsheets and Data · Battle Pass and Season Design · Big Numbers Precision and Formatting · Boss Fight Design Patterns · Building a Signal Library · Captions and Audio Accessibility · Case Study - Adopt Me · Case Study - Building a Game with AI Agents · Case Study - Enemy Roster Rebuild · Case Study - Fisch · Case Study - Pet Simulator 99 · Case Study - Phone UI Overhaul · Case Study - Rivals · Centre-Screen Announcements That Stay Centred · Code Review for Luau Teams · CollectionService Patterns · Colour-Blind Safe Design · Community Building · Core Loop · Crash and Error Telemetry · Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks · Currency Architecture - Soft Hard and Event Currencies · Daily Rewards System End to End · Data Schema Design and Migrations · Data and Config Pipeline - Spreadsheets to Game · Debugger Breakpoints and Logging · Difficulty Options and Cognitive Load · Economy Inflation Sinks and Faucets Math · Emotes and Social Animation · Enemy and NPC Animation · Ethical Design and Player Trust · Experience Notifications and Return Prompts · Faucets and Sinks · Genre Playbook - Combat and RPG · Genre Playbook - Horror and Story · Genre Playbook - Naval and Open-Sea Adventure · Genre Playbook - Obbies and Platformers · Genre Playbook - Puzzle and Escape Rooms · Genre Playbook - Simulators · Horror Monster Chase AI End to End · Icon and Thumbnail Rendering Pipeline · Idempotency · In-Game AI - LLM NPCs and Text Generation · In-Game Bug Report Button with Automatic Context · Input - UserInputService and ContextActionService · Instances Attributes and Tags · Interest Management and Per-Player Replication · Lighting Mood and Time of Day · Live Incident Response and Post-Mortems · Live Ops Deep Dive Start Here · Live Ops Events and Updates · Loading Screen Skip and First-Session Goals · Localization Pipeline · Localization-Ready Writing · Lore Delivery Without Walls of Text · MCP Workflows for Scripting and Debugging · Measuring Onboarding - Funnels, Drop-off and A-B Tests · MicroProfiler Guide · Network Bandwidth Budgets and Measuring Them · Network Performance · Notification Queues and Limits · Obby Checkpoints and Stage Saves End to End · Off-Screen Objective Markers and Waypoint Arrows · Onboarding Funnel · Open Cloud APIs · Paid Random Items and Odds Disclosure in Practice · Parties and Group Teleports · Pathfinding Edge Cases and Fallbacks · Performance Fundamentals · Player-Driven Trading Economies · Post-Mortem - Building a Melee Action Game · Pricing Curves and Upgrade Costs · Probability and Statistics for Designers · Progression Levels and Unlocks · Puzzle Dependency Charts and Hint Systems · Rebirth and Prestige System End to End · Replication Rules · Resource Library - Game Systems · Responsive UI for Phone Tablet Console and PC · Reward Moments and Celebrations · Round-Based Minigame Loop End to End · Scoping and Roles for Small Teams · ScreenGui Fundamentals · Script Performance · Session Length · Session State Across Places · Shape Language and Silhouette Testing · Shift-Lock Sprint and Gamepad B for Menus · Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev · Simulator and RNG Genre Teardown · Skill - Roblox System Builder · Skippable Tutorials and Replayable Tips · Social Design and Multiplayer Play · Spending Triangles Where the Camera Looks · Status Effects Buffs and Stacking Rules · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Strings Patterns and Formatting · Teaching Through Level Design · Teardown - Build A Boat For Treasure · Teardown - Fish It · Teardown - Sol's RNG · Testing Strategies and Frameworks · Testing Your Own Remotes - Fuzzing and Abuse Tests · Text Fonts and Rich Text · Tools and Inventory Systems · Tutorial Step Design Patterns - Teach by Doing · UI Asset Pipeline · UI Motion Language and Timing · UI Scale HUD Hide and Compact Mode · UI Style Directions - A Visual Vocabulary for Briefs · Update Cadence and Hype Cycles · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Viral Game Anatomy - Hooks, Loops and Timing · Virtualized Lists and Large Inventories · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile · Worked Builds Start Here · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience

<!-- atlas:generated -->
