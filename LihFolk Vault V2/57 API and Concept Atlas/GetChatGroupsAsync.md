---
tags: [atlas, api, type/atlas, area/community, area/platform, api/GetChatGroupsAsync]
---
# GetChatGroupsAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetChatGroupsAsync` replaces N^2 pairwise `CanUsersChatAsync` checks; chat group IDs are per universe, can change, and must...
> - Avoid: Pairwise `CanUsersChatAsync` over a whole lobby to build teams -> `TextChatService:GetChatGroupsAsync(players)` once...
> - Avoid: Pairwise chat checks across a lobby -> `TextChatService:GetChatGroupsAsync(players)` once.
>
> Cost: TL;DR ~130 tok · whole note ~320 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetChatGroupsAsync` replaces N^2 pairwise `CanUsersChatAsync` checks; chat group IDs are per universe, can change, and must not be stored after the user leaves. (from [[TextChatService - Engine Reference Card]])

API snapshot: member of `TextChatService`, `VoiceChatService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Pairwise `CanUsersChatAsync` over a whole lobby to build teams -> `TextChatService:GetChatGroupsAsync(players)` once... ([[Age Checks and Safety Features]])
- Avoid: Pairwise chat checks across a lobby -> `TextChatService:GetChatGroupsAsync(players)` once. ([[API Renames and Deprecations 2025-2026]])

## Mentioned in

6 notes in 4 sections. The 6 most relevant are linked:

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]]

### 26 Community and Moderation
[[Text Chat Customization with TextChatService]] · [[Voice Chat and Safety Features]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Policy and Age Rules 2026]]

### 62 Engine Reference Cards
[[TextChatService - Engine Reference Card]]

<!-- atlas:generated -->
