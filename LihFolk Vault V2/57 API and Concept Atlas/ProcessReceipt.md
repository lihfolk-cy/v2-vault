---
tags: [atlas, api, type/atlas, area/monetization, area/performance, api/ProcessReceipt]
---
# ProcessReceipt

<!-- tldr:start -->
> [!tldr] TL;DR
> - ProcessReceipt: The callback that grants Developer Product purchases.
> - Avoid: Granting in `PromptProductPurchaseFinished` -> Grant in `ProcessReceipt` only.
> - Exactly one `ProcessReceipt` assignment in the codebase (grep it) (Developer Products and ProcessReceipt)
> - Avoid: Two scripts assigning `ProcessReceipt`: one system silently never gets receipts.
>
> Cost: TL;DR ~130 tok · whole note ~1.1k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

ProcessReceipt: The callback that grants Developer Product purchases. (from [[Glossary]])

API snapshot: member of `MarketplaceService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Granting in `PromptProductPurchaseFinished` -> Grant in `ProcessReceipt` only. ([[Developer Products and ProcessReceipt]])
- Exactly one `ProcessReceipt` assignment in the codebase (grep it) ([[Developer Products and ProcessReceipt]])
- Avoid: Two scripts assigning `ProcessReceipt`: one system silently never gets receipts. ([[Shop with Game Passes and Developer Products End to End]])
- One `ProcessReceipt`, wrapped in `pcall`, returns `NotProcessedYet` on any doubt. ([[Shop with Game Passes and Developer Products End to End]])
- Exactly one `ProcessReceipt`, covering every product id. ([[Purchase Data and Receipts]])

## Mentioned in

76 notes in 28 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Exploits and Anti-Cheat]]

### 04 Data and Persistence
[[Purchase Data and Receipts]]

### 05 UI and UX
[[Menu Archetypes - Shop Settings Codes Rewards]]

### 09 Gameplay Systems
[[Economies and Currencies]]

### 10 Game Design and Genres
[[Ethical Design and Player Trust]]

### 11 Monetization Publishing and Live Ops
[[Ads and Rewarded Video]] · [[Developer Products and ProcessReceipt]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Refunds Chargebacks and Purchase Support]]

### 12 Performance Testing and Debugging
[[QA Checklists Before Release]]

### 13 Production and Case Studies
[[Live Incident Response and Post-Mortems]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 24 Worked Builds
[[LihFolk Systems - Data and Purchase Guarantees]] · [[LihFolk Systems Library]] · [[Shop with Game Passes and Developer Products End to End]]

### 38 Live Ops Deep Dive
[[Battle Pass and Season Design]] · [[Limited-Time Offers - Design and Ethics]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]]

### 46 Resource Library
[[Links - Developer products]]

### 49 Roblox Platform Features
[[Commerce and Physical Goods]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### 58 Player QoL and Game Tweaks
[[Purchase Receipts and Purchase History in UI]]

### Root notes
[[Glossary]]

Also mentioned in (not linked): 00 Start Here · AI Skills Start Here · AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well · Analytics and Funnels · Anti-Exploit Start Here · Automated Luau Checks - LihFolk Hook and Audit · Automated Testing with TestEZ and Jest-Lua · Bundles Animation Packs and Emotes for Sale · Business and Careers Start Here · Case Study - 99 Nights in the Forest · Case Study - Blox Fruits · Case Study - Building a Game with AI Agents · Case Study - Doors · Case Study - Grow a Garden · Community Building · Confirmation and Undo Patterns for Destructive and Paid Actions · Crash and Error Telemetry · Currency Architecture - Soft Hard and Event Currencies · Debugging Live Servers · DevEx and Cashing Out · Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins · Error Handling and Retries · Evaluating AI Tools - A Practical Rubric · Game Passes · Genre Playbook - RNG and Collection Games · Genre Playbook - Simulators · Global State and Live Config · Idempotency · Live Ops Deep Dive Start Here · Open Questions - Whole Vault · Paid Random Items and Odds Disclosure in Practice · Publishing an Experience · RNG Drops and Luck Systems · Regional Compliance - Paid Random Items and Country Rules · Resetting One Player's Data Safely · Roadmaps Milestones and Scope Control · Roblox Policies Ratings and Compliance · Robux Price Points and Offer Design · Server Authority and Validation · Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev · Skill - Roblox DataStore Safety · Skill - Roblox Monetization Compliance · Skill - Roblox Vault Research · Subscriptions and Premium Payouts · Template Reskin Checklist - One Codebase, New Game · Testing Modes - Play Run and Multi-Client · Threat Modeling a Roblox Game · Token Cost Benchmarks · Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback · What AI Models Get Wrong in Roblox · Worked Builds Start Here

<!-- atlas:generated -->
