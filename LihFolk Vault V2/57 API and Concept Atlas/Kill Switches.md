---
tags: [atlas, concept, type/atlas, area/production, area/liveops]
---
# Kill Switches

<!-- tldr:start -->
> [!tldr] TL;DR
> - Kill switches are the exception: they apply immediately.
> - Release flags default off; kill switches default on.
> - Kill switches for risky systems. (Global State and Live Config)
> - Avoid: No kill switches, so the only containment is a full rollback.
>
> Cost: TL;DR ~100 tok · whole note ~580 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Kill switches are the exception: they apply immediately. (from [[Feature Flags and Staged Rollouts]])

A kill switch is the most valuable flag. Every risky system (trading, purchases of new items, new drop tables) benefits from an off switch that has been tested. (from [[Feature Flags]])

## Key facts

- Release flags default off; kill switches default on. ([[Feature Flags and Staged Rollouts]])
- Kill switches for risky systems. ([[Global State and Live Config]])
- Avoid: No kill switches, so the only containment is a full rollback. ([[Live Incident Response and Post-Mortems]])
- Avoid: No kill switch on a feature that replaces old behaviour. ([[Release Process and Rollbacks]])

## Mentioned in

28 notes in 12 sections. The 25 most relevant are linked:

### 04 Data and Persistence
[[Global State and Live Config]]

### 08 Animation
[[Cinematic Ultimates]]

### 12 Performance Testing and Debugging
[[Crash and Error Telemetry]] · [[Gated Tester Commands and Debug Panels]] · [[Multi-Client and Device Playtesting Protocols]] · [[Multi-Client and Live Testing]]

### 13 Production and Case Studies
[[Documentation and Knowledge Bases]] · [[Lessons Learned Index]] · [[Live Incident Response and Post-Mortems]] · [[Release Process and Rollbacks]] · [[Scoping and Roles for Small Teams]]

### 17 Pipelines
[[Build Test and Release Pipeline]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Live Content Pipeline]] · [[Pipeline Design Principles]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 26 Community and Moderation
[[Working with Content Creators]]

### 27 Marketing and Growth
[[Launch Strategy - The First Two Weeks]]

### 38 Live Ops Deep Dive
[[Economy Resets and Seasonal Wipes]] · [[Event Calendars and Content Planning]] · [[Feature Flags and Staged Rollouts]] · [[Patch Notes and Player Communication]]

### 41 Multiplayer Services
[[Server Shutdowns Soft Updates and Migration]]

### 52 Core Concepts
[[Feature Flags]]

Also mentioned in (not linked): Core Concepts Start Here · Live Ops Deep Dive Start Here · Multiplayer Services Start Here

<!-- atlas:generated -->
