---
tags: [atlas, api, type/atlas, area/design, area/community, api/TextChatService]
---
# TextChatService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TextChatService` is the root. (from Text Chat Customization with TextChatService)
> - No player text travels through remotes; all chat via `TextChatService` (Text Chat Customization with TextChatService)
> - Avoid: Pairwise `CanUsersChatAsync` over a whole lobby to build teams -> `TextChatService:GetChatGroupsAsync(players)` once...
> - All player-to-player text through `TextChatService` channels.
>
> Cost: TL;DR ~140 tok · whole note ~810 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TextChatService` is the root. (from [[Text Chat Customization with TextChatService]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- No player text travels through remotes; all chat via `TextChatService` ([[Text Chat Customization with TextChatService]])
- Avoid: Pairwise `CanUsersChatAsync` over a whole lobby to build teams -> `TextChatService:GetChatGroupsAsync(players)` once... ([[Age Checks and Safety Features]])
- All player-to-player text through `TextChatService` channels. ([[Age Checks and Safety Features]])
- Avoid: `Chat` service or `LegacyChatService` fork -> `TextChatService` (legacy retired April 30, 2025; auto-migrated from May... ([[API Renames and Deprecations 2025-2026]])
- No chat code outside TextChatService. ([[AI Pitfalls - Stale APIs and Luau]])

## Mentioned in

42 notes in 22 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Strings Patterns and Formatting]] · [[Text Filtering - TextService for Names, Signs and Messages]]

### 10 Game Design and Genres
[[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Racing and Driving]] · [[Genre Playbook - Social Deduction and Murder Mystery]]

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]] · [[Community Building]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]] · [[In-Game AI - LLM NPCs and Text Generation]]

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
[[Official Docs - Security and Moderation]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Avatar Context Menus Profiles and Social Surfaces]] · [[Policy and Age Rules 2026]] · [[Roblox Changes 2025-2026]]

### 58 Player QoL and Game Tweaks
[[Block and Mute Respecting Platform Rules]]

### 62 Engine Reference Cards
[[TextChatService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

Also mentioned in (not linked): 00 Start Here · Accessibility Start Here · Community and Moderation Start Here · Engine Reference Cards Start Here · Kill Credit, Assists, Kill Feed and Death Recaps · Localization Pipeline · Nametags and Overhead Bars - Cost and Visibility Rules · Narrative Start Here · Notification and Toast Systems · Player-Driven Trading Economies · Procedural Loot and Item Generation · Rate Limiting · Roblox Policies Ratings and Compliance · Social Design and Multiplayer Play · Trading Systems Without Duplication · Weekend Build - Roleplay Town with Jobs and Paychecks · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
