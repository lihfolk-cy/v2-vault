---
tags: [atlas, api, type/atlas, area/design, area/monetization, api/PolicyService]
---
# PolicyService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PolicyService` checks for paid random items and paid item trading.
> - Do random packs or paid restocks show odds summing to 100%, gated by `PolicyService`?
> - `PolicyService:GetPolicyInfoForPlayerAsync(player)` yields and returns a dictionary of policy flags for that player (Roblox docs).
> - Assuming `PolicyService` succeeded; not failing closed.
>
> Cost: TL;DR ~130 tok · whole note ~830 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PolicyService` checks for paid random items and paid item trading. (from [[Monetization Overview]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Do random packs or paid restocks show odds summing to 100%, gated by `PolicyService`? ([[Teardown - Plants vs Brainrots]])
- `PolicyService:GetPolicyInfoForPlayerAsync(player)` yields and returns a dictionary of policy flags for that player (Roblox docs). ([[Regional Compliance - Paid Random Items and Country Rules]])
- Assuming `PolicyService` succeeded; not failing closed. ([[Roblox Policies Ratings and Compliance]])
- Check with `PolicyService:GetPolicyInfoForPlayerAsync(player)`, field `IsEligibleToPurchaseCommerceProduct` (Roblox docs). ([[Commerce and Physical Goods]])

## Mentioned in

50 notes in 18 sections. The 25 most relevant are linked:

### 04 Data and Persistence
[[Trading Systems Without Duplication]]

### 10 Game Design and Genres
[[Ethical Design and Player Trust]] · [[Genre Playbook - RNG and Collection Games]] · [[Genre Playbook - Tower Defense]] · [[Social Design and Multiplayer Play]]

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]] · [[Roblox Policies Ratings and Compliance]]

### 12 Performance Testing and Debugging
[[Automated Luau Checks - LihFolk Hook and Audit]]

### 24 Worked Builds
[[LihFolk Systems Library]] · [[Pet Hatching and Following End to End]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Tower Defense Simulator]]

### 38 Live Ops Deep Dive
[[Battle Pass and Season Design]] · [[Limited-Time Offers - Design and Ethics]]

### 48 Economy Design Deep Dive
[[Player-Driven Trading Economies]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Commerce and Physical Goods]] · [[Policy and Age Rules 2026]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Subscriptions and Recurring Revenue]]

### 59 Viral and Trend Game Teardowns
[[Teardown - Fish It]] · [[Teardown - Plants vs Brainrots]] · [[Teardown - Sol's RNG]] · [[Teardown - Steal An Egg]] · [[Teardown - Tap Simulator REBORN]] · [[Viral Game Anatomy - Hooks, Loops and Timing]]

Also mentioned in (not linked): AI Skills Start Here · Community Building · Discord Servers for Roblox Games · Economy Design Start Here · Error Handling and Retries · Genre Playbook - Shooters FPS and TPS · Genre Playbook - Simulators · Genre Playbook - Social Deduction and Murder Mystery · Genre Playbook - Zombie and Wave Survival Co-op · Genre QA Passes - Test Checklists per Game Type · Monetization Overview · Official Docs - Security and Moderation · Open Questions - Whole Vault · Paid Random Items and Odds Disclosure in Practice · Retention and Return Hooks · Roadmaps Milestones and Scope Control · Skill - Roblox Monetization Compliance · Teardown - Bee Swarm Simulator · Teardown - Blade Ball · Teardown - Escape Tsunami for Brainrots · Teardown - PLS DONATE · Teardown - Ride A Pet · Template Reskin Checklist - One Codebase, New Game · Testing Modes - Play Run and Multi-Client · Viral and Trend Teardowns Start Here

<!-- atlas:generated -->
