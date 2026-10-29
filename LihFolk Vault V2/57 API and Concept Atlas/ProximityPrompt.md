---
tags: [atlas, api, type/atlas, area/networking, area/gameplay, api/ProximityPrompt]
---
# ProximityPrompt

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ProximityPrompt.GamepadKeyCode` defaults to `Enum.KeyCode.ButtonX` and `KeyboardKeyCode` to `E` (Roblox docs).
> - Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart.
> - Avoid: Client-reported revives -> `ProximityPrompt.Triggered` with server checks.
> - Run it in its own thread if the caller should not yield (a ProximityPrompt handler can spawn it).
>
> Cost: TL;DR ~140 tok · whole note ~770 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ProximityPrompt.GamepadKeyCode` defaults to `Enum.KeyCode.ButtonX` and `KeyboardKeyCode` to `E` (Roblox docs). (from [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart. ([[Pet Hatching and Following End to End]])
- Avoid: Client-reported revives -> `ProximityPrompt.Triggered` with server checks. ([[Downed, Revive and Bleed-Out States]])
- Run it in its own thread if the caller should not yield (a ProximityPrompt handler can spawn it). ([[Instance Streaming]])
- The pickup is a server-side `ProximityPrompt.Triggered` handler with a distance check, so there is no "I found entry X" remote to abuse (the same rule as Quest Chain System End to End). ([[Lore Delivery Without Walls of Text]])

## Mentioned in

35 notes in 17 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Exploits and Anti-Cheat]] · [[Instance Streaming]]

### 05 UI and UX
[[Input - UserInputService and ContextActionService]]

### 08 Animation
[[Enemy and NPC Animation]]

### 09 Gameplay Systems
[[Downed, Revive and Bleed-Out States]]

### 10 Game Design and Genres
[[Genre Playbook - Naval and Open-Sea Adventure]] · [[Genre Playbook - Puzzle and Escape Rooms]]

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

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]] · [[Horror Monster Chase AI End to End]] · [[Racing Laps and Checkpoints End to End]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

### 56 Field Notes
[[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]]

Also mentioned in (not linked): Field Notes Start Here · Instanced Interiors - Pooled House and Room Copies for Many Players · Lobby and Hub Design · Mounts and Rideable Creatures · Network Ownership · Open Questions - Whole Vault · Remote Abuse Patterns and Rate Limiting in Practice · Replication Rules · Skill - Roblox Secure Remotes · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
