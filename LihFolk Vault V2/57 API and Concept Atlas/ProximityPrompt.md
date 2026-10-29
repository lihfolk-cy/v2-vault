---
tags: [atlas, api, type/atlas, area/networking, area/ui, api/ProximityPrompt]
---
# ProximityPrompt

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ProximityPrompt` shows the right key glyph per device and can be tapped on mobile.
> - Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries.
> - Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart.
> - Avoid: Client-reported revives -> `ProximityPrompt.Triggered` with server checks.
>
> Cost: TL;DR ~140 tok · whole note ~820 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ProximityPrompt` shows the right key glyph per device and can be tapped on mobile. (from [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries. ([[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])
- Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart. ([[Pet Hatching and Following End to End]])
- Avoid: Client-reported revives -> `ProximityPrompt.Triggered` with server checks. ([[Downed, Revive and Bleed-Out States]])

## Mentioned in

41 notes in 19 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Exploits and Anti-Cheat]] · [[Instance Streaming]]

### 08 Animation
[[Enemy and NPC Animation]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[Downed, Revive and Bleed-Out States]]

### 12 Performance Testing and Debugging
[[Client Zone Culling for Interiors and Cities]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Weekend Build - Roleplay Town with Jobs and Paychecks]]

### 25 Physics and Vehicles
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars]] · [[Vehicle Damage, Repair and Wreck States]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Lore Delivery Without Walls of Text]]

### 42 Accessibility and Inclusive Design
[[Onboarding Accessibility and Cross-Device Prompts]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Horror Monster Chase AI End to End]] · [[Racing Laps and Checkpoints End to End]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

### 56 Field Notes
[[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]]

### 62 Engine Reference Cards
[[ProximityPrompt - Engine Reference Card]]

Also mentioned in (not linked): Engine Limits, Quotas and Defaults - Cheat Sheet · Engine Reference Cards Start Here · Field Notes Start Here · Genre Playbook - Naval and Open-Sea Adventure · Genre Playbook - Puzzle and Escape Rooms · Input - UserInputService and ContextActionService · Instanced Interiors - Pooled House and Room Copies for Many Players · Lobby and Hub Design · Mounts and Rideable Creatures · Network Ownership · Open Questions - Whole Vault · Remote Abuse Patterns and Rate Limiting in Practice · Replication Rules · Skill - Roblox Secure Remotes · Tutorial Step Design Patterns - Teach by Doing · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
