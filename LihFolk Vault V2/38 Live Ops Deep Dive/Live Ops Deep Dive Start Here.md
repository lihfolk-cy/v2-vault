---
cssclasses: [vault-hub]
tags: [live-ops, hub, start-here, seasons, events, monetization, communication, type/hub, area/liveops, level/beginner, area/monetization]
---
# Live Ops Deep Dive Start Here

Live operations is everything a game does after launch to stay alive: seasons, events, offers, switches, resets and the messages that explain them. The vault already has two broad notes on the area. [[Live Ops Events and Updates]] covers the Roblox platform tools (Experience Events, update announcements, experience notifications), deterministic schedules in code, codes and a sample update rhythm. [[Global State and Live Config]] covers experience configs (`ConfigService`), game-written global state, kill switches and version gating. Read those first. This section goes one level deeper on six questions those notes only touch.

## The six deep notes

| Note | The question it answers |
|---|---|
| [[Battle Pass and Season Design]] | How to build a season pass that the target player can finish, how to split free and premium, and how to handle purchases at the season boundary |
| [[Event Calendars and Content Planning]] | How to plan events from real team throughput, keep the calendar as validated data the servers read, and review each event |
| [[Limited-Time Offers - Design and Ethics]] | What Roblox says about timers, scarcity and discounts, and how to build offers whose timers cannot lie |
| [[Feature Flags and Staged Rollouts]] | Flag kinds and defaults, sticky percentage rollouts, `minBuild` gating, abort criteria, and what a flag cannot roll back |
| [[Economy Resets and Seasonal Wipes]] | When a reset is justified, how to design data so it is cheap, lazy rollover on load, and compensation |
| [[Patch Notes and Player Communication]] | Which channel carries which message, writing nerfs and apologies, an in-game What's New panel, and incident banners |

## Suggested reading order

1. **Running a live game for the first time:** Event Calendars, then Feature Flags, then Patch Notes. These three are the operating system of live ops: plan, ship safely, explain.
2. **Adding monetized seasons:** Battle Pass, then Limited-Time Offers, then Economy Resets.
3. **Something already went wrong:** Feature Flags (kill switches and what they leave behind), Patch Notes (incident messages), then [[Live Incident Response and Post-Mortems]].

## Shared ideas across the section

- **UTC time and season or event ids key everything.** Claims, rollovers and offers are idempotent on an id, so any server can run them any number of times.
- **Configs over publishes.** Calendars, flags, offers and patch notes live as validated JSON in experience configs with code defaults, so mistakes are fixed in a minute and history records who changed what.
- **Lazy over mass jobs.** Season finalisation and seasonal resets happen when a profile next loads, not in a job that rewrites every save.
- **Receipts always resolve.** A purchase that lands after a season or offer ends is still granted.
- **Truth is the design constraint.** Honest timers, exclusives and discounts; nerfs with numbers.

## Related notes elsewhere in the vault

- Platform and schedules: [[Live Ops Events and Updates]], [[Global State and Live Config]], [[Live Content Pipeline]], [[Cross-Server Messaging]], [[MemoryStore Service]]
- Cadence and growth: [[Update Cadence and Hype Cycles]], [[A-B Testing and Experiments on Roblox]], [[Discovery and the Algorithm]], [[Retention and Return Hooks]], [[Analytics and Funnels]]
- Money: [[Robux Price Points and Offer Design]], [[Pricing and Store Design]], [[Developer Products and ProcessReceipt]], [[Game Passes]], [[Paid Random Items and Odds Disclosure in Practice]], [[Refunds Chargebacks and Purchase Support]], [[Ethical Design and Player Trust]]
- Economy and data: [[Economy Inflation Sinks and Faucets Math]], [[Economies and Currencies]], [[Data Schema Design and Migrations]], [[OrderedDataStores and Leaderboards]], [[Session Locking and Profile Libraries]]
- Releases: [[Release Process and Rollbacks]], [[Server Lifecycle and Shutdown]], [[Live Incident Response and Post-Mortems]]
- Worked builds: [[Daily Rewards System End to End]], [[Quest Chain System End to End]], [[Codes Redemption System End to End]], [[Shop with Game Passes and Developer Products End to End]], [[Global Leaderboards End to End]]
- From a live game: [[Data Schema Design and Migrations]], [[Release Process and Rollbacks]]

## Source labels

Facts are labelled **Roblox docs (as of October 2026)**, **measured in the reference project** (one live production game), or **rule of thumb**. Platform limits change; check the Creator Hub before relying on a number.

## Connected notes
<!-- auto-links:start -->
[[Feature Flags]] · Economy Design Start Here · Marketing and Growth Start Here · Retention Cohorts · Team Collaboration Start Here · Faucets and Sinks
<!-- auto-links:end -->
