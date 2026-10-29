---
tags: [atlas, api, type/atlas, area/data, area/performance, api/HttpService]
---
# HttpService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `HttpService` lets game servers talk to the outside world: your own backend, analytics and error trackers, Discord-style...
> - One POST per batch; HttpService budget respected.
> - `HttpService` errors on the client: Requests are server-only -> Remote to the server, server posts.
> - For an unpublished place, set `game:GetService("HttpService").HttpEnabled = true` in the command bar.
>
> Cost: TL;DR ~140 tok · whole note ~1.5k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`HttpService` lets game servers talk to the outside world: your own backend, analytics and error trackers, Discord-style webhooks for moderation alerts, and a growing set of Roblox Open Cloud endpoints. (from [[HttpService and External APIs]])

`HttpService` has no streaming to the client in a useful form for this, so design for the wait: a thinking animation, an "Hmm..." bark, short replies. (from [[In-Game AI - LLM NPCs and Text Generation]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- One POST per batch; HttpService budget respected. ([[Studio Tooling Architecture]])
- `HttpService` errors on the client: Requests are server-only -> Remote to the server, server posts. ([[Moving Data Out of a Play Session]])
- For an unpublished place, set `game:GetService("HttpService").HttpEnabled = true` in the command bar. ([[HttpService and External APIs]])
- `HttpService` works only on the server, after you enable Allow HTTP Requests (File > Experience Settings > Security). ([[In-Game AI - LLM NPCs and Text Generation]])

## Mentioned in

110 notes in 34 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Command Bar and Studio Scripting]] · [[Version History and Backups]]

### 04 Data and Persistence
[[Data Schema Design and Migrations]] · [[Global State and Live Config]] · [[HttpService and External APIs]]

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Clip Archive Server]] · [[Studio Tooling Architecture]]

### 12 Performance Testing and Debugging
[[Crash and Error Telemetry]] · [[In-Game Bug Report Button with Automatic Context]]

### 15 AI Tools
[[AI Agents and Autonomous Workflows]] · [[In-Game AI - LLM NPCs and Text Generation]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]] · [[Studio Plugins and Local HTTP Bridges]] · [[Writing Your Own MCP Server]]

### 17 Pipelines
[[Batch Processing Tools in Studio]] · [[Data and Config Pipeline - Spreadsheets to Game]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 24 Worked Builds
[[Saved Inventory End to End]]

### 39 Studio Plugins and Tooling
[[Plugin Security and Permissions]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Server Browsers and Server Lists]] · [[Session State Across Places]]

### 46 Resource Library
[[Links - Open Cloud and external APIs]]

### 56 Field Notes
[[Moving Data Out of a Play Session]]

Also mentioned in (not linked): 00 Start Here · AI Code Assistants for Luau · AI Pitfalls - Assets and Import · AI Pitfalls - Networking and Security · AI in Roblox Development Overview · Admin Commands Done Safely - Permissions and Audit Logs · Analytics and Funnels · Asset Upload Automation with Open Cloud · Baked Clip Stubs and Archiving · Buffers and Binary Data · Client-Server Model · Code Pipeline - Rojo Git and CI · Confirmation and Undo Patterns for Destructive and Paid Actions · Cookbook - Data and Saving · Creator Account Security and Takeover Recovery · Cross-Server Messaging · Data Loss Prevention and Recovery · DataStore Fundamentals · Debugger Breakpoints and Logging · Debugging DataStore Problems · Debugging Live Servers · Debugging Race Conditions and Yield Order · Developer Console and Stats · Discord Servers for Roblox Games · Documentation and Knowledge Bases · Documentation and Onboarding New Developers · Economy Telemetry and Balancing Live · Engine Gotchas · Error Handling and Retries · Event Calendars and Content Planning · Experience Notifications and Return Prompts · External Tooling - Rojo Wally Selene StyLua · Feature Flags and Staged Rollouts · First-Time User Experience and Onboarding · Groups Roles and Permissions for Studios · How Exploits Work - The Client Boundary · Input Remapping and One-Handed Play · Live Content Pipeline · Load and Soak Testing Servers - Long Sessions and Many Clients · Local vs Cloud AI - Keeping Unreleased Game Code Private · Logging Bans and Appeals · MCP Workflows for Scripting and Debugging · MemoryStore Service · Multi-Client and Device Playtesting Protocols · Multiple Agents in One Studio · Network Bandwidth Budgets and Measuring Them · Network Performance · Open Cloud APIs · Open Questions - Whole Vault · Packages and Shared Assets Across Places · Parties and Group Teleports · Patch Notes and Player Communication · Performance and Memory · Pipeline Design Principles · Places Universes and Experience Settings · Player Privacy and Data Deletion · Player Reports and In-Game Moderation · Player-Driven Trading Economies · Plugin UI with DockWidgets · Procedural Loot and Item Generation · Prompting and Verifying AI Output · Rate Limiting · Rate Limiting and Abuse Prevention · Reading Luau Errors and Stack Traces · Refunds Chargebacks and Purchase Support · RemoteEvents RemoteFunctions and Unreliable Remotes · Roblox Policies on AI-Generated Content · Roblox Studio MCP Server · Schema Migrations - Worked Case Studies · Serialization Formats for Saves and Networking · Server Hop Rejoin and Server Lists with Ping · Session Locking and Profile Libraries · Sponsored Ads and Campaign Math · Sprite Sheets and Frame Animation with ImageRectOffset · Strings Patterns and Formatting · Studio Settings and Shortcuts · Tables Metatables and OOP · Task Library Coroutines and Yielding · Telemetry Events · Teleporting and Multi-Place Games · Threat Modeling a Roblox Game · Tools and Inventory Systems · UI Automation with VirtualInput and StudioTestService · Working with AI Assistants in Studio · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
