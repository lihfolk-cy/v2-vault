---
tags: [production, scoping, solo-dev, planning, launch, milestones, cut-list, qa, fast-ship, type/guide, area/production, level/intermediate]
---
# Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Building systems before the loop is fun.
> - Avoid: Leaving data and receipts to week 4. These are the bugs that lose players' purchases.
> - Avoid: Store page made on launch night. The icon and thumbnails are your conversion; give them a week.
> - Core loop passed a stranger playtest; first reward under 60 seconds.
> - Save, rejoin, shutdown and purchase tests passed in a live test place.
> - All remotes validated server-side; no client-trusted currency.
>
> Cost: TL;DR ~160 tok · whole note ~1.9k tok. Read more: ## Week 2 (days 8 to 14): systems that must not break · ## Week 3 (days 15 to 21): content, art pass and store prep · ## Common mistakes · ## Launch checklist
<!-- tldr:end -->

A first shippable Roblox game in 30 days is realistic if you treat it as a scope problem, not a speed problem. The plan below assumes one developer working most days, a small genre-appropriate loop, and reuse of proven systems (saving, purchases, leaderboards). It is opinionated: fixed gates every week, a written cut list, and launch prep that starts on day 15, not day 29. Numbers are rules of thumb from LihFolk practice unless labelled otherwise.

## Day 0: pick something that fits

A 30-day game has **one core verb, one progression axis and one reason to come back.** Examples: click-collect-upgrade (simulator), jump-checkpoint-cosmetic (obby), place-defend-unlock (small TD). Genres that do not fit 30 days solo: open-world RP, battle royale, anything needing many hand-built levels or custom vehicles. See [[Planning and Scoping a Roblox Game]].

Write a one-page spec before opening Studio:

- Core loop in one sentence and the first 60 seconds shot by shot ([[First-Time User Experience and Onboarding]]).
- Three monetisation items maximum (one pass, one consumable product, one cosmetic or convenience).
- What "done" means: the launch checklist at the bottom of this note.
- The cut list (below), written now, while you are calm.

## Week 1 (days 1 to 7): the loop, ugly

Goal: the core loop is fun with grey boxes.

- Day 1: project skeleton, source control or at least a version history habit ([[Version History and Backups]]), folder structure, one server bootstrap and one client bootstrap.
- Days 2 to 4: the core verb and its feedback. Juice the input immediately (sound and pop); it changes how you judge fun.
- Days 5 to 6: progression axis (currency, upgrade, unlock) with placeholder numbers.
- Day 7, **gate 1**: three people who are not you play for 10 minutes. If nobody wants a second session, change the loop now. This is the cheapest pivot you will ever get.

## Week 2 (days 8 to 14): systems that must not break

Goal: nothing the player earns can be lost or duplicated.

- Saving with session locking and retry; test leave-and-rejoin and server shutdown ([[DataStore Fundamentals]], [[Saved Inventory End to End]]).
- Purchases through a single `ProcessReceipt` handler with idempotency ([[Developer Products and ProcessReceipt]]).
- Every remote validated on the server: types, rate, ownership ([[Server Authority and Validation]]).
- Analytics: onboarding funnel steps and economy events, server-side ([[Analytics and Funnels]]).
- Day 14, **gate 2**: kill the server mid-session in a test place, rejoin, verify data. Buy every product in Studio test purchases. If either fails, week 3 starts with the fix.

Reuse is the whole trick here. A tested drop-in library (see [[LihFolk Systems Library]]) turns week 2 from "build" into "wire and verify".

## Week 3 (days 15 to 21): content, art pass and store prep

Goal: it looks like a game and has 30 to 60 minutes of content.

- Content: enough zones, levels or upgrades for one hour, with a visible goal beyond it.
- Art pass: one style, consistent palette, lighting preset ([[Stylized Lighting Recipes]]). Do not model everything; kitbash and reuse.
- UI: shop, settings, one HUD, tested on a phone-size emulator ([[Responsive UI for Phone Tablet Console and PC]]).
- **Start the store page on day 15**: icon draft, 3 thumbnail drafts, description draft. Iterating these over a week beats a rushed night ([[Thumbnails Icons and Store Page]]).
- Complete the content maturity questionnaire early; unrated games are restricted (Roblox docs, content maturity page).
- Day 21, **gate 3**: a phone playtest with a stranger, timed: join to first reward under 60 seconds, no blocking bugs in 15 minutes.

## Week 4 (days 22 to 30): polish, QA, launch

- Days 22 to 24: bug bash from a written test list ([[QA Checklists Before Release]]), performance on a low-end phone, memory check over a 30-minute session.
- Days 25 to 26: balance pass using your funnel data from playtests; tune the first 10 minutes only. Later numbers can be patched.
- Day 27: soft launch: public, no ads, invite friends and a small community. Watch errors in the live console and funnel drop-offs.
- Days 28 to 29: fix the top three issues. Nothing else.
- Day 30: launch push on a day you can be online for the next 48 hours ([[Launch Strategy - The First Two Weeks]]). Optional small ad test with a fixed budget only after the funnel looks healthy ([[Sponsored Ads and Campaign Math]]).

## The cut list (write it on day 0)

Order of things to cut when behind, first to last:

1. Second game mode or minigame.
2. Trading, gifting, any player-to-player economy (high exploit risk, high support cost).
3. Custom animations beyond the core verb.
4. Leaderboards beyond one global board.
5. Daily rewards, quests, codes (add in the first update instead).
6. Extra monetisation items beyond three.

Never cut: data safety, receipt handling, server validation, the mobile layout, the maturity questionnaire.

## A daily rhythm that holds for 30 days

- First hour: the riskiest task of the day.
- Commit or publish to a test place at the end of every day with a one-line log entry.
- Playtest your own build on a phone at least every second day.
- If a task overruns by 2x, stop and decide: cut, simplify, or move it to post-launch.

## Common mistakes

- **Building systems before the loop is fun.** Week 1 gate exists to stop this.
- **Leaving data and receipts to week 4.** These are the bugs that lose players' purchases.
- **Store page made on launch night.** The icon and thumbnails are your conversion; give them a week.
- **No soft launch.** Live-only bugs (DataStore throttles, streaming, real latency) appear with real players.
- **Adding features in days 28 to 30.** Fix, do not add.
- **Scope that needs custom vehicles or big hand-built maps.** Not a 30-day solo game.

## Launch checklist

- [ ] Core loop passed a stranger playtest; first reward under 60 seconds.
- [ ] Save, rejoin, shutdown and purchase tests passed in a live test place.
- [ ] All remotes validated server-side; no client-trusted currency.
- [ ] Analytics funnel and economy events firing from the server.
- [ ] Maturity questionnaire complete; odds disclosed for any paid random item.
- [ ] Icon, 3+ thumbnails and description reviewed at real size.
- [ ] Phone and low-end performance checked.
- [ ] You are available for 48 hours after launch.

## See also

- [[Planning and Scoping a Roblox Game]]
- [[Roadmaps Milestones and Scope Control]]
- [[Scoping and Roles for Small Teams]]
- [[Release Process and Rollbacks]]
- [[Launch Strategy - The First Two Weeks]]
- [[Worked Builds Start Here]]

## Connected notes

[[Template Reskin Checklist - One Codebase, New Game]] · [[LihFolk Systems Library]] · QA Checklists Before Release · Analytics and Funnels · Core Loops and Session Design

<!-- related:start -->
## Related
[[Live Incident Response and Post-Mortems]] · [[Lessons Learned Index]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Documentation and Knowledge Bases]] · [[Team Roles and Workflows]] · [[Post-Mortem - Building a Melee Action Game]] · [[Case Study - Fast Join and Deferred Loading]] · [[Case Study - Phone UI Overhaul]]
<!-- related:end -->
