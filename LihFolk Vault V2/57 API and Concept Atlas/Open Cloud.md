---
tags: [atlas, concept, type/atlas, area/data, area/pipelines]
---
# Open Cloud

<!-- tldr:start -->
> [!tldr] TL;DR
> - Open Cloud is Roblox's public web API: the same data stores, memory stores, messaging, configs, bans, products and places your...
> - Avoid: Running a bulk Open Cloud migration at peak CCU without throttling.
> - Create secrets in Creator Dashboard > your experience > Secrets (game or group owner only), or through Open Cloud.
> - Universe id everywhere: Open Cloud is stateless.
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Open Cloud is Roblox's public web API: the same data stores, memory stores, messaging, configs, bans, products and places your game uses, reachable from any program that can send HTTPS requests. (from [[Open Cloud APIs]])

Open Cloud is Roblox's set of HTTP APIs authenticated with API keys or OAuth; its Assets API uploads files and returns asset ids, and its Place Publishing API pushes place files. (from [[Asset Upload Automation with Open Cloud]])

## Key facts

- Avoid: Running a bulk Open Cloud migration at peak CCU without throttling. ([[Data and Cloud Changes 2025-2026]])
- Create secrets in Creator Dashboard > your experience > Secrets (game or group owner only), or through Open Cloud. ([[HttpService and External APIs]])
- Universe id everywhere: Open Cloud is stateless. ([[Open Cloud APIs]])
- On Open Cloud you cannot set fast flags, so whether Jest-Lua runs there is unverified; TestEZ, which needs no flag, or a small runner of your own, is the safer choice for Open Cloud jobs. ([[Automated Testing with TestEZ and Jest-Lua]])

## Mentioned in

97 notes in 30 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Git and Source Control for Roblox]] · [[Places Universes and Experience Settings]]

### 04 Data and Persistence
[[Data Loss Prevention and Recovery]] · [[Data Schema Design and Migrations]] · [[DataStore Fundamentals]] · [[HttpService and External APIs]] · [[Open Cloud APIs]] · [[Player Privacy and Data Deletion]]

### 08 Animation
[[Animation Asset Permissions and Groups]]

### 11 Monetization Publishing and Live Ops
[[Refunds Chargebacks and Purchase Support]]

### 12 Performance Testing and Debugging
[[Automated Testing with TestEZ and Jest-Lua]] · [[Testing Strategies and Frameworks]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]]

### 17 Pipelines
[[Art Pipeline - Concept to In-Game Asset]] · [[Asset Upload Automation with Open Cloud]] · [[Audio Pipeline]] · [[Code Pipeline - Rojo Git and CI]]

### 22 Anti-Exploit and Security
[[Creator Account Security and Takeover Recovery]] · [[Logging Bans and Appeals]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]] · [[Debugging Live Servers]]

### 49 Roblox Platform Features
[[Badges and Achievement Design]] · [[Data and Cloud Changes 2025-2026]] · [[Experience Notifications and Return Prompts]]

### Root notes
[[Open Questions - Whole Vault]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · 3D Importer Settings Reference · AI Pitfalls - Data and Monetization · Animation Objects · Blender 5 Python Gotchas for Headless Builds · Blender Armature and Bone Roll Conventions · Blender Automation with Python · Blender MCP · Blender Workflow for Roblox Creators · Build Test and Release Pipeline · Character and Creature Pipeline · Codes Redemption System End to End · Commerce and Physical Goods · Cross-Server Messaging · Debugging Start Here · Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts · Economy Resets and Seasonal Wipes · Economy Telemetry and Balancing Live · Evaluating AI Tools - A Practical Rubric · Exporting FBX vs GLB · Global State and Live Config · Glossary · Groups Roles and Permissions for Studios · Icon and Thumbnail Rendering Pipeline · Importing Models and Rigs · In-Game Bug Report Button with Automatic Context · Live Content Pipeline · Live Ops Events and Updates · Local vs Cloud AI - Keeping Unreleased Game Code Private · Localization Pipeline · Materials and Surfaces Start Here · MemoryStore Service · Modeling Fundamentals for Games · Notification and Toast Systems · Open Questions · OrderedDataStores and Leaderboards · Pipeline Design Principles · Pixel Art Pipeline - Aseprite to Roblox Without Blur · Player Reports and In-Game Moderation · Plugin Security and Permissions · Plugins - Using and Writing · Publishing Animations · Publishing Selling and Updating Plugins · Purchase Data and Receipts · Resource Library - Scripting · Retention and Return Hooks · Rigging in Blender · Roadmaps Milestones and Scope Control · Roblox Changes 2025-2026 · Roblox Communities as Your On-Platform Hub · Safety Rules for AI Agents in Studio · Save Migration Tests - Fixture Saves and Golden Files · Schema Migrations - Worked Case Studies · Serial-Numbered Limited Items - Atomic Counters · Serialization Formats for Saves and Networking · Server Lifecycle and Shutdown · Server Shutdowns Soft Updates and Migration · Studio Plugins and Local HTTP Bridges · Subscriptions and Recurring Revenue · SurfaceAppearance PBR Workflow · Team Collaboration Start Here · Team Create Permissions and Workflows · Team Create and Collaboration · Template Reskin Checklist - One Codebase, New Game · Testing Modes - Play Run and Multi-Client · Trading Systems Without Duplication · Version History and Backups · Weapon Design Rig Builder · What Is MCP · Working with Contractors and Revenue Splits · Writing Your Own MCP Server

<!-- atlas:generated -->
