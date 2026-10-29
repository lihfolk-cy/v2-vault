---
tags: [atlas, api, type/atlas, area/design, area/monetization, api/PolicyService]
---
# PolicyService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PolicyService` checks for paid random items and paid item trading.
> - `PolicyService:GetPolicyInfoForPlayerAsync(player)` yields and returns a dictionary of policy flags for that player (Roblox docs).
> - Assuming `PolicyService` succeeded; not failing closed.
> - Check with `PolicyService:GetPolicyInfoForPlayerAsync(player)`, field `IsEligibleToPurchaseCommerceProduct` (Roblox docs).
>
> Cost: TL;DR ~140 tok · whole note ~730 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PolicyService` checks for paid random items and paid item trading. (from [[Monetization Overview]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `PolicyService:GetPolicyInfoForPlayerAsync(player)` yields and returns a dictionary of policy flags for that player (Roblox docs). ([[Regional Compliance - Paid Random Items and Country Rules]])
- Assuming `PolicyService` succeeded; not failing closed. ([[Roblox Policies Ratings and Compliance]])
- Check with `PolicyService:GetPolicyInfoForPlayerAsync(player)`, field `IsEligibleToPurchaseCommerceProduct` (Roblox docs). ([[Commerce and Physical Goods]])
- If you must run a limited crate, disclose odds, gate with `PolicyService`, and keep the window long. ([[Limited-Time Offers - Design and Ethics]])

## Mentioned in

37 notes in 16 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling and Retries]]

### 04 Data and Persistence
[[Trading Systems Without Duplication]]

### 10 Game Design and Genres
[[Ethical Design and Player Trust]] · [[Genre Playbook - RNG and Collection Games]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Genre Playbook - Simulators]] · [[Genre Playbook - Social Deduction and Murder Mystery]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Social Design and Multiplayer Play]]

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]] · [[Community Building]] · [[Roblox Policies Ratings and Compliance]]

### 12 Performance Testing and Debugging
[[Automated Luau Checks - LihFolk Hook and Audit]]

### 24 Worked Builds
[[LihFolk Systems Library]] · [[Pet Hatching and Following End to End]]

### 26 Community and Moderation
[[Discord Servers for Roblox Games]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Tower Defense Simulator]]

### 38 Live Ops Deep Dive
[[Battle Pass and Season Design]] · [[Limited-Time Offers - Design and Ethics]]

### 48 Economy Design Deep Dive
[[Player-Driven Trading Economies]]

### 49 Roblox Platform Features
[[Commerce and Physical Goods]] · [[Policy and Age Rules 2026]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Subscriptions and Recurring Revenue]]

Also mentioned in (not linked): AI Skills Start Here · Economy Design Start Here · Genre QA Passes - Test Checklists per Game Type · Links - Moderation compliance · Monetization Overview · Open Questions - Whole Vault · Paid Random Items and Odds Disclosure in Practice · Retention and Return Hooks · Roadmaps Milestones and Scope Control · Skill - Roblox Monetization Compliance · Template Reskin Checklist - One Codebase, New Game · Testing Modes - Play Run and Multi-Client

<!-- atlas:generated -->
