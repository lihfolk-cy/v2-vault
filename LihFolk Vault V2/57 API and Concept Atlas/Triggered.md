---
tags: [atlas, api, type/atlas, area/networking, area/gameplay, api/Triggered]
---
# Triggered

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Triggered` fires on the server with the player, so the server knows who pressed it.
> - Avoid: trusting `Triggered` or `MouseClick` without a server distance and state check.
> - Avoid: granting items straight from `Triggered` with no checks.
>
> Cost: TL;DR ~100 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Triggered` fires on the server with the player, so the server knows who pressed it. (from [[Vehicle Damage, Repair and Wreck States]])

API snapshot: member of `PluginAction`, `ProximityPrompt`, `StudioActionOverride`, `TextChatCommand` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: trusting `Triggered` or `MouseClick` without a server distance and state check. ([[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])
- Avoid: granting items straight from `Triggered` with no checks. ([[ProximityPrompt - Engine Reference Card]])

## Mentioned in

11 notes in 10 sections. The 11 most relevant are linked:

### 03 Architecture and Networking
[[Network Ownership]] · [[Replication Rules]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 12 Performance Testing and Debugging
[[Gated Tester Commands and Debug Panels]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]]

### 25 Physics and Vehicles
[[Vehicle Damage, Repair and Wreck States]]

### 26 Community and Moderation
[[Text Chat Customization with TextChatService]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]]

### 62 Engine Reference Cards
[[ProximityPrompt - Engine Reference Card]]

<!-- atlas:generated -->
