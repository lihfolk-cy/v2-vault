---
tags: [atlas, concept, type/atlas, area/monetization, area/platform]
---
# Subscriptions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Subscriptions have their own APIs (Subscriptions and Premium Payouts).
> - Subscription benefits distinct from passes; same on every platform.
> - Subscription perks check `HasRobloxSubscription`; the Plus upsell uses `PromptRobloxSubscriptionPurchase`.
> - Transaction Refunded (and Subscription Refunded if relevant) webhooks configured with a secret.
>
> Cost: TL;DR ~130 tok · whole note ~940 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Subscriptions have their own APIs (Subscriptions and Premium Payouts). (from [[Purchase Data and Receipts]])

A subscription stipend is a faucet that never turns off. (from [[Subscriptions and Recurring Revenue]])

## Key facts

- Subscription benefits distinct from passes; same on every platform. ([[Subscriptions and Premium Payouts]])
- Subscription perks check `HasRobloxSubscription`; the Plus upsell uses `PromptRobloxSubscriptionPurchase`. ([[API Renames and Deprecations 2025-2026]])
- Transaction Refunded (and Subscription Refunded if relevant) webhooks configured with a secret. ([[Refunds Chargebacks and Purchase Support]])
- Avoid: Assuming a later subscription licenses audio made earlier. ([[AI Audio - Voice Music and SFX]])
- Every publish and subscribe in `pcall`, with retry for subscriptions at server start. ([[MessagingService - Engine Reference Card]])

## Mentioned in

62 notes in 22 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Cross-Server Messaging]]

### 04 Data and Persistence
[[Purchase Data and Receipts]]

### 11 Monetization Publishing and Live Ops
[[Community Building]] · [[Discovery and the Algorithm]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Refunds Chargebacks and Purchase Support]] · [[Roblox Policies Ratings and Compliance]] · [[Robux Price Points and Offer Design]] · [[Subscriptions and Premium Payouts]] · [[Thumbnails Icons and Store Page]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 28 Business and Careers
[[DevEx and Cashing Out]] · [[Running a Small Studio as a Business]]

### 41 Multiplayer Services
[[Reserved and Private Servers in Practice]]

### 46 Resource Library
[[Official Docs - Monetization]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Discovery and Monetization Changes 2025-2026]] · [[Friend Invites Referrals and Experience Invites]] · [[Platform Features Start Here]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Subscriptions and Recurring Revenue]]

### 52 Core Concepts
[[Event Bus]]

### 62 Engine Reference Cards
[[MessagingService - Engine Reference Card]]

Also mentioned in (not linked): 00 Start Here · Analytics and Funnels · Business and Careers Start Here · Case Study - Brookhaven RP · Case Study - Pet Simulator 99 · Commerce and Physical Goods · Competitor Analysis Method · Creator Account Security and Takeover Recovery · Debugging Client-Server Desync · Debugging Race Conditions and Yield Order · Engine Limits, Quotas and Defaults - Cheat Sheet · Engine and API Changes 2025-2026 · Evaluating AI Tools - A Practical Rubric · Experience Description and Search Keywords · Game Passes · Global State and Live Config · Glossary · Groups Roles and Permissions for Studios · Interest Management and Per-Player Replication · Limited-Time Offers - Design and Ethics · Local vs Cloud AI - Keeping Unreleased Game Code Private · MarketplaceService - Engine Reference Card · Open Cloud APIs · Open Questions - Whole Vault · Policy and Age Rules 2026 · Publishing an Experience · Roblox Studio Assistant · Session Length · Shop with Game Passes and Developer Products End to End · Short-Form Video Marketing · Skill - Roblox Monetization Compliance · Sponsored Ads and Campaign Math · Substance Painter and Texturing Tools · Teardown - PLS DONATE · Template Reskin Checklist - One Codebase, New Game · Threat Modeling a Roblox Game · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
