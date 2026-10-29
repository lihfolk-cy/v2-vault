---
tags: [atlas, api, type/atlas, area/platform, api/GetUserBadgesAsync]
---
# GetUserBadgesAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetUserBadgesAsync` checks up to 100 badge ids in one call and returns the award date, so you can backfill earned times as well.
> - The backfill uses `#ids <= 100` because `GetUserBadgesAsync` takes at most 100 ids.
> - `CheckUserBadgesAsync` and `GetUserBadgesAsync`: 10 + 5 x players per minute in each server; batches of 10 and 100 ids...
>
> Cost: TL;DR ~130 tok · whole note ~260 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetUserBadgesAsync` checks up to 100 badge ids in one call and returns the award date, so you can backfill earned times as well. (from [[Badges and Achievement Design]])

API snapshot: member of `BadgeService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- The backfill uses `#ids <= 100` because `GetUserBadgesAsync` takes at most 100 ids. ([[Badges and Achievement Design]])
- `CheckUserBadgesAsync` and `GetUserBadgesAsync`: 10 + 5 x players per minute in each server; batches of 10 and 100 ids respectively. ([[BadgeService - Engine Reference Card]])

## Mentioned in

4 notes in 2 sections. The 4 most relevant are linked:

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]] · [[Badges and Achievement Design]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 62 Engine Reference Cards
[[BadgeService - Engine Reference Card]]

<!-- atlas:generated -->
