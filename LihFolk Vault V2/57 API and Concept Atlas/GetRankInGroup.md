---
tags: [atlas, api, type/atlas, area/community, area/ai, api/GetRankInGroup]
---
# GetRankInGroup

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetRankInGroup` is a web call; wrap it in `pcall` and cache per session.
> - `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(...
> - Admin command works in Studio, fails live: Rank check against the wrong group id, or `GetRankInGroup` failing...
> - Avoid: Deprecated `IsInGroup` / `GetRankInGroup`.
>
> Cost: TL;DR ~140 tok · whole note ~390 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetRankInGroup` is a web call; wrap it in `pcall` and cache per session. (from [[Gated Tester Commands and Debug Panels]])

API snapshot: member of `Player`; flagged deprecated (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(... ([[Engine and API Changes 2025-2026]])
- Admin command works in Studio, fails live: Rank check against the wrong group id, or `GetRankInGroup` failing... ([[Text Chat Customization with TextChatService]])
- Avoid: Deprecated `IsInGroup` / `GetRankInGroup`. ([[Roblox Communities as Your On-Platform Hub]])

## Mentioned in

10 notes in 7 sections. The 10 most relevant are linked:

### 11 Monetization Publishing and Live Ops
[[Community Building]]

### 12 Performance Testing and Debugging
[[Gated Tester Commands and Debug Panels]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]] · [[What AI Models Get Wrong in Roblox]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]]

### 26 Community and Moderation
[[Groups Roles and Permissions for Studios]] · [[Player Reports and In-Game Moderation]] · [[Text Chat Customization with TextChatService]]

### 27 Marketing and Growth
[[Roblox Communities as Your On-Platform Hub]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

<!-- atlas:generated -->
