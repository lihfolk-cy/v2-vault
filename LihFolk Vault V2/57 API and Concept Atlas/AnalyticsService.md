---
tags: [atlas, api, type/atlas, area/design, area/monetization, api/AnalyticsService]
---
# AnalyticsService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AnalyticsService` adds your own data: economy events (currency sources and sinks), funnel events (where players drop out of a...
> - Roblox gives you built-in channels: `AnalyticsService` has methods for economy events, progression events, funnel steps and...
> - Funnel logged with `AnalyticsService` onboarding steps.
>
> Cost: TL;DR ~120 tok · whole note ~660 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AnalyticsService` adds your own data: economy events (currency sources and sinks), funnel events (where players drop out of a sequence), progression events and custom events (anything else). (from [[Analytics and Funnels]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Roblox gives you built-in channels: `AnalyticsService` has methods for economy events, progression events, funnel steps and... ([[Telemetry Events]])
- Funnel logged with `AnalyticsService` onboarding steps. ([[First-Time User Experience and Onboarding]])
- The exact `AnalyticsService` funnel method signature was not verified for this note; check the current API reference. ([[Quest Chain System End to End]])
- `AnalyticsService:LogCustomEvent` per step name works, or a server log line you aggregate (Analytics and Funnels). ([[Schema Migrations - Worked Case Studies]])

## Mentioned in

27 notes in 15 sections. The 25 most relevant are linked:

### 04 Data and Persistence
[[Data Loss Prevention and Recovery]] · [[Schema Migrations - Worked Case Studies]]

### 09 Gameplay Systems
[[Economies and Currencies]]

### 10 Game Design and Genres
[[Balancing with Spreadsheets and Data]] · [[Core Loops and Session Design]] · [[First-Time User Experience and Onboarding]] · [[Genre Playbook - Obbies and Platformers]] · [[Progression and Pacing Design]]

### 11 Monetization Publishing and Live Ops
[[Analytics and Funnels]] · [[Developer Products and ProcessReceipt]] · [[Economy Inflation Sinks and Faucets Math]] · [[Robux Price Points and Offer Design]]

### 12 Performance Testing and Debugging
[[Crash and Error Telemetry]]

### 13 Production and Case Studies
[[Case Study - Fast Join and Deferred Loading]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 24 Worked Builds
[[Quest Chain System End to End]]

### 26 Community and Moderation
[[Working with Content Creators]]

### 27 Marketing and Growth
[[Launch Strategy - The First Two Weeks]]

### 33 Level Design
[[Teaching Through Level Design]]

### 48 Economy Design Deep Dive
[[Currency Architecture - Soft Hard and Event Currencies]] · [[Economy Design Start Here]] · [[Economy Telemetry and Balancing Live]]

### 49 Roblox Platform Features
[[Friend Invites Referrals and Experience Invites]]

### 52 Core Concepts
[[Onboarding Funnel]] · [[Telemetry Events]]

Also mentioned in (not linked): Links - Analytics · Marketing and Growth Start Here

<!-- atlas:generated -->
