---
tags: [atlas, api, type/atlas, area/community, area/platform, api/GetRolesInGroupAsync]
---
# GetRolesInGroupAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetRolesInGroupAsync` is a web call; wrap it in `pcall` and cache per session.
> - Deprecated `IsInGroup` / `GetRankInGroup` (and now `GetRankInGroupAsync`).
> - Allowlist by stable identity. `UserId` or group rank (`GroupService:GetRolesInGroupAsync(userId, groupId)`; the older...
> - Server-checked rank on every action. Read the rank with `GroupService:GetRolesInGroupAsync` (highest role's `Rank`) on the...
>
> Cost: TL;DR ~140 tok · whole note ~510 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetRolesInGroupAsync` is a web call; wrap it in `pcall` and cache per session. (from [[Gated Tester Commands and Debug Panels]])

API snapshot: member of `GroupService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Deprecated `IsInGroup` / `GetRankInGroup` (and now `GetRankInGroupAsync`). Use `IsInGroupAsync` and `GroupService:GetRolesInGroupAsync` in `pcall`. ([[Roblox Communities as Your On-Platform Hub]])
- Allowlist by stable identity. `UserId` or group rank (`GroupService:GetRolesInGroupAsync(userId, groupId)`; the older `Player:GetRankInGroup` is deprecated). ([[Gated Tester Commands and Debug Panels]])
- Server-checked rank on every action. Read the rank with `GroupService:GetRolesInGroupAsync` (highest role's `Rank`) on the server; the panel UI is cosmetic (Groups Roles and Permissions for Studios). ([[Player Reports and In-Game Moderation]])
- Avoid: `Player:GetRankInGroup` or `GetRankInGroupAsync` -> `GroupService:GetRolesInGroupAsync` and read the highest role's `Rank`. ([[API Renames and Deprecations 2025-2026]])

## Mentioned in

11 notes in 8 sections. The 11 most relevant are linked:

### 11 Monetization Publishing and Live Ops
[[Community Building]]

### 12 Performance Testing and Debugging
[[Gated Tester Commands and Debug Panels]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]]

### 26 Community and Moderation
[[Groups Roles and Permissions for Studios]] · [[Player Reports and In-Game Moderation]] · [[Text Chat Customization with TextChatService]]

### 27 Marketing and Growth
[[Roblox Communities as Your On-Platform Hub]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine and API Changes 2025-2026]]

### 62 Engine Reference Cards
[[Player - Engine Reference Card]]

<!-- atlas:generated -->
