---
tags: [atlas, api, type/atlas, area/data, area/networking, api/MessagingService]
---
# MessagingService

<!-- tldr:start -->
> [!tldr] TL;DR
> - MessagingService lets servers of the same experience publish and subscribe to messages on named topics, typically delivered...
> - Avoid: Using MessagingService as a database -> Store state; message to notify.
> - Avoid: Relying on MessagingService alone (Servers that miss a message stay wrong forever) (Global State and Live Config)
> - The MessagingService nudge is best effort (Cross-Server Messaging).
>
> Cost: TL;DR ~140 tok · whole note ~710 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

MessagingService lets servers of the same experience publish and subscribe to messages on named topics, typically delivered within one to two seconds (Roblox docs). (from [[Cross-Server Messaging]])

MessagingService: Cross-server publish/subscribe messages. (from [[Glossary]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Using MessagingService as a database -> Store state; message to notify. ([[Cross-Server Messaging]])
- Avoid: Relying on MessagingService alone (Servers that miss a message stay wrong forever) ([[Global State and Live Config]])
- The MessagingService nudge is best effort (Cross-Server Messaging). ([[Friend Invites Referrals and Experience Invites]])
- Either refresh often enough (a few minutes is a common choice, rule of thumb), push an update to all servers with MessagingService when a code is added, or announce codes a few minutes after activating them. ([[Codes Redemption System End to End]])

## Mentioned in

30 notes in 19 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Places Universes and Experience Settings]]

### 03 Architecture and Networking
[[Cross-Server Messaging]] · [[Rate Limiting and Abuse Prevention]]

### 04 Data and Persistence
[[DataStore Fundamentals]] · [[Global State and Live Config]] · [[MemoryStore Service]] · [[Open Cloud APIs]]

### 05 UI and UX
[[Notification and Toast Systems]]

### 11 Monetization Publishing and Live Ops
[[Live Ops Events and Updates]] · [[Refunds Chargebacks and Purchase Support]]

### 13 Production and Case Studies
[[Live Incident Response and Post-Mortems]]

### 17 Pipelines
[[Asset Upload Automation with Open Cloud]] · [[Live Content Pipeline]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]] · [[How Exploits Work - The Client Boundary]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 24 Worked Builds
[[Codes Redemption System End to End]]

### 35 Advanced Luau
[[Serialization Formats for Saves and Networking]]

### 41 Multiplayer Services
[[Matchmaking Queues with MemoryStore]] · [[Parties and Group Teleports]] · [[Server Shutdowns Soft Updates and Migration]]

### 46 Resource Library
[[Links - Cross-server messaging]]

### 49 Roblox Platform Features
[[Friend Invites Referrals and Experience Invites]]

### 52 Core Concepts
[[Rate Limiting]]

### 56 Field Notes
[[Resetting One Player's Data Safely]]

Also mentioned in (not linked): Glossary · Multiplayer Services Start Here · Open Questions - Whole Vault · Viral Game Anatomy - Hooks, Loops and Timing · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
