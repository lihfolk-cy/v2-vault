---
tags: [core-concept, analytics, retention, live-ops]
---
# Retention Cohorts

A **cohort** is a group of players who share a starting point, usually the day they first joined. **Retention** is the share of a cohort that comes back after a given time: day-1 (D1) retention is the percentage who return the day after their first play, D7 a week later, D30 a month later. The Creator Dashboard reports these (Roblox docs, "Retention" analytics, as of October 2026).

## Why it matters on Roblox

Retention is the clearest signal of whether players like a game, and it compounds: a game that keeps more of each day's new players grows even with the same traffic. Many developers treat D1 as the headline number because it reacts fastest to changes in onboarding and the first session.

## The nuance most people miss

1. **Compare cohorts, not totals.** Total daily players mixes new and returning players and moves with traffic. Retention by join-date cohort tells you whether last Tuesday's update changed how new players behave.
2. **Traffic source changes the cohort.** Players from a sponsored ad, a viral video or a front-page placement behave differently. A retention drop the week a video went viral may be a different audience, not a worse game.
3. **D1 measures the first session; D7 and D30 measure the game.** Onboarding fixes move D1. Long-term goals, social ties and update cadence move D30.
4. **Small cohorts lie.** A cohort of 80 players swings several percentage points by chance. Wait for enough players, or pool several days, before deciding.
5. **Benchmarks are rough.** Public numbers vary widely by genre. Treat outside benchmarks as rumour and your own trend over time as the truth.
6. **Retention is the outcome, not the lever.** You cannot raise it directly; you change onboarding, goals or return hooks and watch the next cohorts.

## Tiny example

| Join week | New players | D1 | D7 |
|---|---|---|---|
| Week 1 (before new tutorial) | 12,000 | 22% | 6% |
| Week 2 (after new tutorial) | 11,500 | 27% | 7% |

D1 rose five points with similar traffic: the tutorial helped the first session. D7 barely moved: the mid-game still needs work.

## Where this shows up

- [[Retention and Return Hooks]]: the levers that move retention.
- [[Analytics and Funnels]]: where to read cohort data.
- [[A-B Testing and Experiments on Roblox]]: testing changes on cohorts.
- [[Launch Strategy - The First Two Weeks]]: early cohorts after launch.
- [[Sponsored Ads and Campaign Math]]: paid traffic as its own cohort.
- [[Probability and Statistics for Designers]]: why small cohorts are noisy.
- [[Experience Notifications and Return Prompts]]: platform return tools.
- [[Update Cadence and Hype Cycles]]: updates and returning players.
- [[Battle Pass and Season Design]]: long-term retention structures.
- [[Live Incident Response and Post-Mortems]]: retention dips after bad releases.
- [[Case Study - Adopt Me]]: long-term retention through updates.

Related concepts: [[Session Length]], [[Onboarding Funnel]], [[Telemetry Events]], [[Variance]].

## Connected notes
<!-- auto-links:start -->
[[Marketing and Growth Start Here]] · [[Discovery and the Algorithm]] · [[Click-Through Rate]] · [[Live Ops Deep Dive Start Here]] · [[Working with Content Creators]] · [[Roadmaps Milestones and Scope Control]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
