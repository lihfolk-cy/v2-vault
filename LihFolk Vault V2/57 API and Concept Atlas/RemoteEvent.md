---
tags: [atlas, api, type/atlas, area/animation, area/networking, api/RemoteEvent]
---
# RemoteEvent

<!-- tldr:start -->
> [!tldr] TL;DR
> - RemoteEvent / RemoteFunction: Client-server messages; UnreliableRemoteEvent drops instead of queueing.
> - `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only...
> - Server owns every teleport; clients only request through a validated RemoteEvent.
> - Each RemoteEvent handler validated against AI Pitfalls - Networking and Security.
>
> Cost: TL;DR ~140 tok · whole note ~1.7k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

RemoteEvent / RemoteFunction: Client-server messages; UnreliableRemoteEvent drops instead of queueing. (from [[Glossary]])

API snapshot: class, inherits `BaseRemoteEvent` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only... ([[RemoteEvent - Engine Reference Card]])
- Server owns every teleport; clients only request through a validated RemoteEvent. ([[TeleportService - Engine Reference Card]])
- Each RemoteEvent handler validated against AI Pitfalls - Networking and Security. ([[What AI Models Get Wrong in Roblox]])

## Mentioned in

134 notes in 37 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Explorer Properties and Selection]]

### 02 Luau Scripting
[[Instances Attributes and Tags]] · [[Text Filtering - TextService for Names, Signs and Messages]]

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]] · [[Client-Server Model]] · [[Interest Management and Per-Player Replication]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Replication Rules]]

### 08 Animation
[[Ability Kits Architecture]]

### 09 Gameplay Systems
[[Combat Systems Architecture]]

### 11 Monetization Publishing and Live Ops
[[Ads and Rewarded Video]]

### 12 Performance Testing and Debugging
[[Network Bandwidth Budgets and Measuring Them]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]]

### 24 Worked Builds
[[Melee Combat System End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Saved Inventory End to End]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]]

### 62 Engine Reference Cards
[[RemoteEvent - Engine Reference Card]]

Also mentioned in (not linked): A Stuck Player Watchdog That Logs the Cause · AI Code Assistants for Luau · API Renames and Deprecations 2025-2026 · Admin Commands Done Safely - Permissions and Audit Logs · Age Checks and Safety Features · Agent Review Loops and Guardrails in Practice · Authoring Clips in Code · AvatarEditorService and In-Game Avatar Editors · Blender Armature and Bone Roll Conventions · Block and Mute Respecting Platform Rules · Camera Systems · Case Study - Building a Game with AI Agents · Case Study - Fast Join and Deferred Loading · Centre of Mass, Anti-Flip and Self-Righting · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Clip Buffer Format · Code Review for Luau Teams · ContextActionService - Engine Reference Card · Cookbook - UI · Crash and Error Telemetry · Custom Locomotion Controller Design · Daily Rewards System End to End · Debugging Animation Problems · Developer Products and ProcessReceipt · Difficulty Options and Cognitive Load · Documentation and Onboarding New Developers · Enemy Animation State Protocol · Engine Gotchas · Engine Reference Cards Start Here · Equip Draw and Flourish Systems · Events Signals and Connections · Exploits and Anti-Cheat · External Tooling - Rojo Wally Selene StyLua · Feedback - Autosave Indicator Ping Display and Error Toasts · Genre Playbook - Social Deduction and Murder Mystery · Global Leaderboards End to End · Glossary · GuiService - Engine Reference Card · Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · In-Game AI - LLM NPCs and Text Generation · In-Game Bug Report Button with Automatic Context · Input Remapping and One-Handed Play · Inventory QoL - Sort Filter Search Stack and Lock · Joining Friends Parties and Private Servers · Lessons Learned Index · Live Incident Response and Post-Mortems · Lore Delivery Without Walls of Text · Lua Keyframe Player · MCP Workflows for Scripting and Debugging · Moving Data Out of a Play Session · Multi-Client and Device Playtesting Protocols · Multi-Client and Live Testing · Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes · Naming Items Zones and Abilities · Notification Queues and Limits · Notification and Toast Systems · Official Docs - Scripting and Luau · Patch Notes and Player Communication · Pipeline - New Animated Weapon · Pipeline Design Principles · Places Universes and Experience Settings · Player - Engine Reference Card · Player Reports and In-Game Moderation · Plugin Security and Permissions · Policy and Age Rules 2026 · Post-Mortem - Building a Melee Action Game · Project Structure and Bootstrapping · Purchase Receipts and Purchase History in UI · Quick Respawn and Spawn Protection · Rate Limiting and Abuse Prevention · Rebirth and Prestige System End to End · Remote Abuse Patterns and Rate Limiting in Practice · Replicating VFX - Server Validates, Clients Render · Replication Boundary · Replication and Ownership · Reserved and Private Servers in Practice · Roblox Generative AI - Cube Mesh and Texture Generation · Round-Based Minigame Loop End to End · Safety Rules for AI Agents in Studio · Serialization Formats for Saves and Networking · Server Authority · Server Authority and Input Migration 2026 · Server Browsers and Server Lists · Server Hop Rejoin and Server Lists with Ping · Settings Menu Essentials and Persistence · Shop with Game Passes and Developer Products End to End · Skippable Tutorials and Replayable Tips · Snapshot Interpolation for Custom Replication · Status Effects Buffs and Stacking Rules · Studio Assistant and AI Tools · Team Roles and Workflows · TeleportService - Engine Reference Card · Teleporting and Multi-Place Games · Testing Your Own Remotes - Fuzzing and Abuse Tests · Text Chat Customization with TextChatService · Threat Modeling a Roblox Game · Token Cost Benchmarks · Tools and Inventory Systems · Tower Defense Waves and Placement End to End · UI Automation with VirtualInput and StudioTestService · UserInputService - Engine Reference Card · Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits · Virtualized Lists and Large Inventories · Weekend Build - Survival Gather, Craft and Place · What AI Models Get Wrong in Roblox · What Is MCP · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
