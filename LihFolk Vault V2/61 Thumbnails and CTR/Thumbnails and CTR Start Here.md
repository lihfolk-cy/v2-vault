---
tags: [marketing, thumbnails, icons, ctr, ccu, discovery, store-page, hub, type/guide, area/marketing, level/beginner]
---
# Thumbnails and CTR Start Here

This section is about the images that sit between a player's thumb and your game: the 16:9 thumbnails on Home, the square icon everywhere else, and the title beside them. Get those right and the same number of impressions turns into more plays; turn those plays into good sessions and Roblox shows you to more people, which is what concurrent users (CCU) actually are. The section builds on the specs and store-page advice in [[Thumbnails Icons and Store Page]], the icon craft in [[Game Icon Design - Readable at Small Sizes]], the cross-game snapshot in [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]], the ranking signals in [[Discovery and the Algorithm]] and the testing method in [[A-B Testing and Experiments on Roblox]]. It adds composition rules, genre recipes, a thumbnail-specific test method, the CTR-to-CCU arithmetic, a production pipeline and a scoring rubric.

Labels: **Roblox docs** (create.roblox.com, read 2026-10-29), **Measured** (a figure Roblox or a named source published), **Rule of thumb** (LihFolk practice), **Unverified**.

---

## 1. What each storefront piece does

| Piece | Where players see it | Job | Note |
|---|---|---|---|
| **16:9 thumbnail** | Home "Recommended for You" tiles, top of the game details page, Sponsored ad tiles | Sell the moment: what you do and why it is exciting | [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]] |
| **Square icon** | Continue, Favorites and Sponsored rows on Home, Search, Discover charts | Be recognised: one face or symbol that means "this game" | [[Game Icon Design - Readable at Small Sizes]] |
| **Title** | Under every tile | Name the verb and the noun ("Steal An Egg") | [[Experience Description and Search Keywords]] |
| **Description, video, extra images** | Details page | Confirm the promise for the player who is curious but not sure | [[Thumbnails Icons and Store Page]] |

- Since the 2024 Home change, Recommendations show the **first active 16:9 thumbnail** as a large tile, while the **1:1 icon** stays in Continue, Sponsored and Favorites rows and in Search and Discover (**Roblox docs**, staff announcement, March 2024, rollout to new mobile and tablet users updated February 2025: https://devforum.roblox.com/t/169-experience-thumbnails-are-coming-to-home-in-april-%E2%80%93-update-yours-now/2875237). In testing, the larger tiles gave **+7.2 %** unique plays from recommendations on web and desktop (**Measured**, same post).
- A **custom thumbnail is required** to receive impressions from Home recommendations; default thumbnails are ineligible (**Roblox docs**, https://create.roblox.com/docs/production/promotion/discovery).

So for a new game, the thumbnail does most of the work of being discovered; the icon does most of the work of being found again.

---

## 2. Three rates people confuse

| Term | Definition | Who reports it |
|---|---|---|
| **CTR (click-through rate)** | Clicks on a tile divided by impressions of that tile. The generic web-marketing term; see [[Click-Through Rate]]. | Sponsored ads report impressions and clicks (**Roblox docs**, https://create.roblox.com/docs/production/promotion/ads-manager) |
| **Play-through rate (PTR)** | The rate at which users play your game after seeing it in Recommended for You. Listed first among the "most important" ranking signals. | Acquisition dashboard, "Play through rate" chart (**Roblox docs**, discovery and https://create.roblox.com/docs/production/analytics/acquisition) |
| **Qualified play-through rate (qPTR)** | Qualified plays divided by Home recommendation impressions. A qualified play filters out accidental clicks and quick bounces. | Thumbnail personalisation's Thumbnail Performance table (**Roblox docs**, https://create.roblox.com/docs/production/promotion/thumbnails) |

Why the difference matters:
- A click is not a play. Players can tap a tile, read the details page and leave.
- A play is not a qualified play. A player who joins and leaves inside a few seconds counts as a play but not a qualified one.
- **qPTR is the number to optimise.** It rewards thumbnails that attract the players who then stay, which is exactly what the ranking also rewards. In this section "CTR" means "the share of people who saw the tile and went on to play properly" unless a table says otherwise.

---

## 3. The metric chain from tile to CCU

```
Impressions (Home, Search, Sponsored, ...)
  x qPTR                      <- thumbnail, icon, title
  = qualified plays
  x session length            <- first 3 minutes, core loop
  + returning sessions        <- D1, D7, D28 retention
  = total playtime per day
  / 1,440 minutes per day
  = average CCU
```

And the loop that makes it grow: Recommended for You ranks you on **per-user averages** of play-through rate, first-play bounce rate (under 60 s and 61 to 180 s), play days per user and playtime per user (capped at 60 minutes per user per game per day), measured only on users who joined **organically** from Recommended for You (**Roblox docs**, discovery page). Better numbers on those players earn more impressions, which feed the top of the chain again. The full arithmetic, with worked examples, is in [[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]].

Two consequences:
1. **A thumbnail alone cannot carry a game.** Doubling qPTR doubles plays at the same impressions, but if those players bounce, the bounce signal pulls impressions back down.
2. **A thumbnail can sink a good game.** With a weak tile, good per-user numbers never get enough organic players to prove themselves.

---

## 4. Where to start, by situation

| Situation | Read first | Then |
|---|---|---|
| Not launched yet | [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] | Composition, then production |
| Launched, few impressions | [[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]] | [[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]] |
| Impressions fine, low qPTR | [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]] | [[Thumbnail Genre Patterns - What Top Games Show]] |
| Have variants, unsure which wins | [[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]] | [[A-B Testing and Experiments on Roblox]] |
| Need to make the images | [[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]] | [[Icon and Thumbnail Rendering Pipeline]] |
| Want a second opinion or an AI review | [[Thumbnail Review Checklist and Scoring Rubric]] | [[Thumbnail Contrast]] |
| Planning launch timing | [[Launch Strategy - The First Two Weeks]] | [[Update Cadence and Hype Cycles]] |

---

## 5. The five ideas that matter most (Rule of thumb)

1. **One promise per thumbnail.** Each image sells one thing: a rare drop, a giant monster, a friend group, a huge number. Different thumbnails sell different promises, so personalisation can match each to a different audience.
2. **Readable at phone size.** If the promise does not read at about 320 x 180 px, it does not exist for most of your players.
3. **True to the game.** Roblox's docs ask for imagery that shows what players will find; misleading metadata is against the Community Standards and gets less exposure. Truthful art also protects your bounce rate.
4. **Measure qPTR and playtime together.** A thumbnail that raises qPTR while average playtime per qualified play falls is over-promising.
5. **Refresh with real updates.** Roblox's own advice is to test new thumbnails with major updates and then leave them until the next one (**Roblox docs**, thumbnails page).

---

## 6. Notes in this section

1. [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]]: exact sizes, counts, video rules, policy, localisation.
2. [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]]: design rules that survive small sizes.
3. [[Thumbnail Genre Patterns - What Top Games Show]]: recurring patterns per genre and how to stand out inside them.
4. [[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]]: personalisation, sample sizes, reading uplift.
5. [[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]]: the arithmetic and what to fix next.
6. [[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]]: the production pipeline.
7. [[Thumbnail Review Checklist and Scoring Rubric]]: a 10-point rubric for humans and AI reviewers.

---

## Common mistakes

- Avoid: optimising raw clicks. Symptom: impressions rise for a week, then fall as bounce rate climbs.
- Avoid: treating the icon and the thumbnail as the same image. Symptom: a cropped 16:9 scene as the icon, unreadable in the Continue row.
- Avoid: one thumbnail only. Symptom: personalisation never starts; every user sees the same image.
- Avoid: judging art on a desktop monitor. Symptom: details and text that vanish on a phone.
- Avoid: blaming the thumbnail for everything. Symptom: repeated art changes while D1 retention stays flat.

## Checklist

- [ ] Custom 16:9 thumbnails uploaded; 2 to 5 active on the Home Page tab.
- [ ] Icon readable at 150 px and consistent with the thumbnails.
- [ ] Each thumbnail sells one distinct, true promise.
- [ ] qPTR, average playtime and first-play bounce read together, weekly.
- [ ] Thumbnail changes dated in a change log next to releases.
- [ ] Next step chosen from the table in section 4.
