---
tags: [atlas, api, type/atlas, area/community, area/monetization, api/GetRolesInGroupAsync]
---
# GetRolesInGroupAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetRolesInGroupAsync` is a web call; wrap it in `pcall` and cache per session.
> - Deprecated `IsInGroup` / `GetRankInGroup` (and now `GetRankInGroupAsync`).
> - Allowlist by stable identity. `UserId` or group rank (`GroupService:GetRolesInGroupAsync(userId, groupId)`; the older...
> - Server-checked rank on every action. Read the rank with `GroupService:GetRolesInGroupAsync` (highest role's `Rank`) on the...
>
> Cost: TL;DR ~140 tok · whole note ~470 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetRolesInGroupAsync` is a web call; wrap it in `pcall` and cache per session. (from [[Gated Tester Commands and Debug Panels]])

API snapshot: member of `GroupService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Deprecated `IsInGroup` / `GetRankInGroup` (and now `GetRankInGroupAsync`). Use `IsInGroupAsync` and `GroupService:GetRolesInGroupAsync` in `pcall`. ([[Roblox Communities as Your On-Platform Hub]])
- Allowlist by stable identity. `UserId` or group rank (`GroupService:GetRolesInGroupAsync(userId, groupId)`; the older `Player:GetRankInGroup` is deprecated). ([[Gated Tester Commands and Debug Panels]])
- Server-checked rank on every action. Read the rank with `GroupService:GetRolesInGroupAsync` (highest role's `Rank`) on the server; the panel UI is cosmetic (Groups Roles and Permissions for Studios). ([[Player Reports and In-Game Moderation]])
- In-game, `GroupService:GetRolesInGroupAsync(userId, groupId)` returns membership and the user's roles (each with a `Rank` and name); the older `Player:GetRankInGroup` and `GetRoleInGroup` are deprecated. ([[Groups Roles and Permissions for Studios]])

## Mentioned in

7 notes in 5 sections. The 7 most relevant are linked:

### 11 Monetization Publishing and Live Ops
[[Community Building]]

### 12 Performance Testing and Debugging
[[Gated Tester Commands and Debug Panels]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]]

### 26 Community and Moderation
[[Groups Roles and Permissions for Studios]] · [[Player Reports and In-Game Moderation]] · [[Text Chat Customization with TextChatService]]

### 27 Marketing and Growth
[[Roblox Communities as Your On-Platform Hub]]

<!-- atlas:generated -->
