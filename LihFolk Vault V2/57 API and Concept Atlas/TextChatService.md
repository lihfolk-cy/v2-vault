---
tags: [atlas, api, type/atlas, area/design, area/community, api/TextChatService]
---
# TextChatService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TextChatService` is the root. (from Text Chat Customization with TextChatService)
> - No player text travels through remotes; all chat via `TextChatService` (Text Chat Customization with TextChatService)
> - All player-to-player text through `TextChatService` channels.
> - No chat code outside TextChatService. (AI Pitfalls - Stale APIs and Luau)
>
> Cost: TL;DR ~130 tok · whole note ~680 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TextChatService` is the root. (from [[Text Chat Customization with TextChatService]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- No player text travels through remotes; all chat via `TextChatService` ([[Text Chat Customization with TextChatService]])
- All player-to-player text through `TextChatService` channels. ([[Age Checks and Safety Features]])
- No chat code outside TextChatService. ([[AI Pitfalls - Stale APIs and Luau]])

## Mentioned in

38 notes in 21 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Strings Patterns and Formatting]]

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]]

### 09 Gameplay Systems
[[Kill Credit, Assists, Kill Feed and Death Recaps]]

### 10 Game Design and Genres
[[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Racing and Driving]] · [[Genre Playbook - Social Deduction and Murder Mystery]]

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]] · [[Community Building]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]] · [[In-Game AI - LLM NPCs and Text Generation]]

### 17 Pipelines
[[Localization Pipeline]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]]

### 26 Community and Moderation
[[Player Reports and In-Game Moderation]] · [[Text Chat Customization with TextChatService]] · [[Voice Chat and Safety Features]]

### 29 Luau Cookbook
[[Cookbook - Tables Strings and Time]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Writing Dialogue for Roblox Players]]

### 42 Accessibility and Inclusive Design
[[Captions and Audio Accessibility]]

### 46 Resource Library
[[Links - Chat and text filtering]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]] · [[Policy and Age Rules 2026]] · [[Roblox Changes 2025-2026]]

### 58 Player QoL and Game Tweaks
[[Block and Mute Respecting Platform Rules]]

### Root notes
[[Open Questions - Whole Vault]]

Also mentioned in (not linked): 00 Start Here · Accessibility Start Here · Community and Moderation Start Here · Narrative Start Here · Notification and Toast Systems · Player-Driven Trading Economies · Procedural Loot and Item Generation · Rate Limiting · Roblox Policies Ratings and Compliance · Social Design and Multiplayer Play · Trading Systems Without Duplication · Weekend Build - Roleplay Town with Jobs and Paychecks · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
