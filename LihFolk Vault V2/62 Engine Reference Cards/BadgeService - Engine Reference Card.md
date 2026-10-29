---
tags: [reference, engine, badgeservice, api/BadgeService, type/reference, area/scripting, level/intermediate, api/GetUserBadgesAsync]
---

# BadgeService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: awarding from a LocalScript. Symptom: the award fails; fire a validated remote and award on the server.
> - Avoid: calling `UserHasBadgeAsync` once per badge for a big achievement list.
> - Avoid: awarding without `pcall`. Symptom: a network failure errors the script and the reward logic after it never runs.
> - Awards happen on the server, after the triggering action is validated, inside `pcall` with a retry.
> - Ownership read once per player join in a batch call, then cached for the session.
> - Achievement progress saved in a data store; badges mirror it.
>
> Cost: TL;DR ~180 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Awards badges, checks who owns them and reads badge details such as enabled state and rarity. Topic notes: [[Badges and Achievement Design]], [[DataStore Fundamentals]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| AwardBadgeAsync | method | `(userId: number, badgeId: int64) -> boolean` | - | Server scripts only; `true` when the badge was awarded | yes |
| UserHasBadgeAsync | method | `(userId: number, badgeId: int64) -> boolean` | - | Server: any user; client: the local user only | yes |
| CheckUserBadgesAsync | method | `(userId: number, badgeIds: {int64}) -> {int64}` | - | Up to 10 ids; returns the owned subset | yes |
| [[GetUserBadgesAsync]] | method | `(userId: number, badgeIds: {int64}) -> {{BadgeId: int64, AwardedDate}}` | - | Up to 100 ids; includes when each was awarded | yes |
| GetBadgeInfoAsync | method | `(badgeId: int64) -> Dictionary` | - | Briefly cached between repeated calls | yes |
| info `Name` | field | string | - | Badge name | - |
| info `Description` | field | string | - | Badge description | - |
| info `IconImageId` | field | int64 | - | Asset id of the icon image | - |
| info `IsEnabled` | field | boolean | - | Whether it can be awarded right now | - |
| info `AwardCount` | field | int64 | - | Total times awarded | - |
| info `PastDayAwardCount` | field | int64 | - | Times awarded in the past day | - |
| info `Rarity` | field | number | - | 0.0 to 1.0: share of players who earned it in the past day | - |

Retired names and their replacements:
- `AwardBadge` -> `AwardBadgeAsync`.
- `UserHasBadge` -> `UserHasBadgeAsync`.
- `IsDisabled` -> `GetBadgeInfoAsync` and read `IsEnabled`.
- `IsLegal` always returns true; drop it.

## Limits and defaults

- `AwardBadgeAsync`: 50 + 35 x users per minute.
- `UserHasBadgeAsync`: 50 + 35 x players per minute.
- `CheckUserBadgesAsync` and `GetUserBadgesAsync`: 10 + 5 x players per minute in each server; batches of 10 and 100 ids respectively.
- Creating badges: 5 free per game in each 24-hour period (GMT), then 100 Robux for each extra badge.
- The badge icon is cropped to a circle on upload, so keep details inside the circle.

## Replication and authority

- Award only from the server: a `Script` with `RunContext` `Enum.RunContext.Server` or `Enum.RunContext.Legacy`, or a `ModuleScript` required by one.
- An award succeeds only when the player is connected, does not already own the badge, the badge is enabled, and the call runs in a place of the experience the badge belongs to.
- Players can delete a badge from their profile and earn it again.
- On the server, ownership checks for users who have not recently been in the server only cover this experience's badges; other badges read as not owned. Users who recently were in the server can be checked for any badge.
- Client scripts (`Enum.RunContext.Client` or a `LocalScript`) can only check the local user.

## Common mistakes

- Avoid: awarding from a LocalScript. Symptom: the award fails; fire a validated remote and award on the server.
- Avoid: calling `UserHasBadgeAsync` once per badge for a big achievement list. Symptom: the per-minute limit runs out; batch with `CheckUserBadgesAsync` or `GetUserBadgesAsync`.
- Avoid: awarding without `pcall`. Symptom: a network failure errors the script and the reward logic after it never runs.
- Avoid: using badge ownership as your only save. Symptom: progress returns when a player deletes the badge; record unlocks in a data store too.
- Avoid: awarding a disabled badge. Symptom: nothing happens; check `IsEnabled` from `GetBadgeInfoAsync` during setup.

## Checklist

- Awards happen on the server, after the triggering action is validated, inside `pcall` with a retry.
- Ownership read once per player join in a batch call, then cached for the session.
- Achievement progress saved in a data store; badges mirror it.
- Badge ids kept in one config module.

Source: https://create.roblox.com/docs/reference/engine/classes/BadgeService and https://create.roblox.com/docs/production/publishing/badges - verified 2026-10-29

<!-- related:start -->
## Related
[[MarketplaceService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[Players - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[RunService - Engine Reference Card]]
<!-- related:end -->
