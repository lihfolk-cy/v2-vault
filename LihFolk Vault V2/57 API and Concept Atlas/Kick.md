---
tags: [atlas, api, type/atlas, area/gameplay, area/networking, api/Kick]
---
# Kick

<!-- tldr:start -->
> [!tldr] TL;DR
> - Kick messages should be friendly and say how to come back.
> - Reset did nothing: Player was online; session save wrote the old data back -> Kick, wait for lock release, then remove.
> - At 15 minutes: `player:Kick("Disconnected for inactivity.
> - Banned players currently in a server are removed (rule of thumb: confirm in your game; many developers also call `Kick`...
>
> Cost: TL;DR ~130 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Kick messages should be friendly and say how to come back. (from [[AFK Detection Idle Kicks and AFK Reward Rules]])

API snapshot: member of `Player` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Reset did nothing: Player was online; session save wrote the old data back -> Kick, wait for lock release, then remove. ([[Resetting One Player's Data Safely]])
- At 15 minutes: `player:Kick("Disconnected for inactivity. ([[AFK Detection Idle Kicks and AFK Reward Rules]])
- Banned players currently in a server are removed (rule of thumb: confirm in your game; many developers also call `Kick` explicitly with the same message so the timing is under their control). ([[Logging Bans and Appeals]])
- Kick on `locked` and `failed`. This is the conservative choice. ([[Saving Correctly - Autosave and BindToClose]])

## Mentioned in

21 notes in 12 sections. The 21 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Error Handling and Retries]]

### 03 Architecture and Networking
[[Exploits and Anti-Cheat]] · [[Teleporting and Multi-Place Games]]

### 04 Data and Persistence
[[Saving Correctly - Autosave and BindToClose]]

### 08 Animation
[[Snippets - Procedural Motion]]

### 22 Anti-Exploit and Security
[[Logging Bans and Appeals]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]]

### 26 Community and Moderation
[[Player Reports and In-Game Moderation]] · [[Text Chat Customization with TextChatService]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 41 Multiplayer Services
[[Parties and Group Teleports]] · [[Reserved and Private Servers in Practice]] · [[Session State Across Places]]

### 50 Team Collaboration and Project Management
[[Working with Contractors and Revenue Splits]]

### 56 Field Notes
[[Resetting One Player's Data Safely]]

### 58 Player QoL and Game Tweaks
[[AFK Detection Idle Kicks and AFK Reward Rules]]

<!-- atlas:generated -->
