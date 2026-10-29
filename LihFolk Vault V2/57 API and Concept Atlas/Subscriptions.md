---
tags: [atlas, concept, type/atlas, area/monetization, area/platform]
---
# Subscriptions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Subscriptions have their own APIs (Subscriptions and Premium Payouts).
> - Avoid: Bronze/Silver/Gold experience subscriptions (not supported; all can be owned at once).
> - Subscription benefits distinct from passes; same on every platform.
> - Transaction Refunded (and Subscription Refunded if relevant) webhooks configured with a secret.
>
> Cost: TL;DR ~130 tok · whole note ~870 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Subscriptions have their own APIs (Subscriptions and Premium Payouts). (from [[Purchase Data and Receipts]])

A subscription stipend is a faucet that never turns off. (from [[Subscriptions and Recurring Revenue]])

## Key facts

- Avoid: Bronze/Silver/Gold experience subscriptions (not supported; all can be owned at once). ([[Subscriptions and Premium Payouts]])
- Subscription benefits distinct from passes; same on every platform. ([[Subscriptions and Premium Payouts]])
- Transaction Refunded (and Subscription Refunded if relevant) webhooks configured with a secret. ([[Refunds Chargebacks and Purchase Support]])
- Avoid: Assuming a later subscription licenses audio made earlier. ([[AI Audio - Voice Music and SFX]])
- Every "on added" subscription uses connect, then iterate existing, with a double-init guard. ([[Debugging Race Conditions and Yield Order]])

## Mentioned in

56 notes in 20 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Cross-Server Messaging]]

### 04 Data and Persistence
[[Purchase Data and Receipts]]

### 11 Monetization Publishing and Live Ops
[[Community Building]] · [[Discovery and the Algorithm]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Publishing an Experience]] · [[Refunds Chargebacks and Purchase Support]] · [[Roblox Policies Ratings and Compliance]] · [[Robux Price Points and Offer Design]] · [[Subscriptions and Premium Payouts]] · [[Thumbnails Icons and Store Page]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 24 Worked Builds
[[Shop with Game Passes and Developer Products End to End]]

### 27 Marketing and Growth
[[Short-Form Video Marketing]]

### 28 Business and Careers
[[DevEx and Cashing Out]] · [[Running a Small Studio as a Business]]

### 41 Multiplayer Services
[[Reserved and Private Servers in Practice]]

### 49 Roblox Platform Features
[[Discovery and Monetization Changes 2025-2026]] · [[Friend Invites Referrals and Experience Invites]] · [[Platform Features Start Here]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Subscriptions and Recurring Revenue]]

### 52 Core Concepts
[[Event Bus]]

Also mentioned in (not linked): 00 Start Here · Analytics and Funnels · Business and Careers Start Here · Case Study - Brookhaven RP · Case Study - Pet Simulator 99 · Commerce and Physical Goods · Competitor Analysis Method · Creator Account Security and Takeover Recovery · Debugging Client-Server Desync · Debugging Race Conditions and Yield Order · Evaluating AI Tools - A Practical Rubric · Experience Description and Search Keywords · Game Passes · Global State and Live Config · Glossary · Groups Roles and Permissions for Studios · Interest Management and Per-Player Replication · Limited-Time Offers - Design and Ethics · Local vs Cloud AI - Keeping Unreleased Game Code Private · Open Cloud APIs · Open Questions - Whole Vault · Policy and Age Rules 2026 · Resource Library - Monetization · Roblox Studio Assistant · Session Length · Skill - Roblox Monetization Compliance · Sponsored Ads and Campaign Math · Substance Painter and Texturing Tools · Template Reskin Checklist - One Codebase, New Game · Threat Modeling a Roblox Game · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
