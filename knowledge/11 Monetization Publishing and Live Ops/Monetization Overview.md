---
tags: [monetization, robux, overview, business, live-ops]
---
# Monetization Overview

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Granting in `PromptProductPurchaseFinished`.
> - Avoid: Hard-coded prices. Break regional pricing, price optimization and Plus discounts (Docs).
> - Avoid: No purchase log. Roblox does not record per-user purchase history for you (Docs).
> - Monetization plan written per the build order above
> - Every product and pass created on the dashboard; no id 0 left visible as purchasable
> - One server script owns `ProcessReceipt`, idempotent and data-store backed
>
> Cost: TL;DR ~160 tok · whole note ~3.8k tok. Read more: ## 1. The money map (October 2026) · ## 4. What the reference project sold · ## 7. Common mistakes · ## 8. Checklist
<!-- tldr:end -->

This note maps every way a Roblox experience can earn, explains how each one actually pays, and gives a decision framework for choosing between them. It is the entry point for the folder. Each mechanism has its own deep note; this one is about the whole system and the trade-offs between parts.

Everything in this folder is time-sensitive. Roblox changed its subscription, payout and publishing rules several times in 2025 and 2026. Facts below were checked against the official Creator Hub docs (create.roblox.com/docs) **as of October 2026**. Where docs and announcements disagree, both are given. When you read this later, re-check anything with a number in it.

Source labels used in this folder:
- **Docs**: the official Creator Hub guides or engine reference.
- **Announcement**: a Roblox newsroom post or official DevForum announcement.
- **Reference project**: one live action game with collectible items whose shop history is used (anonymised) throughout.
- **Rule of thumb**: experience, not a hard rule.

---

## 1. The money map (October 2026)

The Creator Hub monetization overview (Docs, Oct 2026) lists these methods. The table adds how each pays and who it suits.

| Method | What the player pays for | How you earn | Best for |
|---|---|---|---|
| [[Game Passes]] | A one-time permanent perk | Robux share of the sale | Permanent multipliers, VIP, access, cosmetics |
| [[Developer Products and ProcessReceipt]] | A repeatable purchase | Robux share of each sale | Currency packs, boosts, revives, bundles |
| [[Subscriptions and Premium Payouts]] (experience subscriptions) | Monthly recurring benefits | 70% in Robux (Robux priced); 70% then 100% (local currency) (Docs) | Daily stipends, ongoing perks |
| Roblox Plus (platform subscription) | The player's Roblox-wide subscription | Sign-up bonus, private server payout, discounts covered by Roblox (Docs) | Every game; prompt in-game |
| Creator Rewards | Nothing, the player just plays | Daily Engagement and Audience Expansion rewards (Docs) | Every game; replaced Premium Payouts |
| [[Ads and Rewarded Video]] | Watching an ad | Earnings per thousand impressions (EPM) (Docs) | Games with 2,000+ monthly unique visitors |
| Immersive ads | Nothing; ad units in the world | Impression-based earnings (Docs) | Large worlds with natural billboard space |
| Paid access (Robux or local currency) | Entry to the game | One-time fee | Premium, finished, niche games |
| Private servers | A server the owner controls | Monthly Robux fee (free or paid) | Social, grinding and roleplay games |
| Robux transfers | A Plus subscriber sends Robux to another user through your game | 10% of the amount sent, no Roblox fee (Docs) | Social and creator-tipping games |
| Catalog commissions | Avatar items bought via your game's inspect menu or avatar editor | A commission (Docs) | Avatar-heavy and hangout games |
| Creator Store sales | Plugins (min $4.99) and models (min $2.99) sold to creators in USD | Direct USD with a 30-day escrow (Docs) | Tool makers |

Two older items are gone. **Engagement-Based Payouts** ("Premium Payouts") were deprecated on July 24, 2025 and replaced by **Creator Rewards** (Docs). **Premium** stopped accepting new sign-ups when **Roblox Plus** launched on April 30, 2026, and Premium's 10% Robux purchase bonus ended on May 30, 2026 (Announcement). Old tutorials that tell you to "design for Premium playtime" describe a payout that no longer exists. See [[Subscriptions and Premium Payouts]].

Two cross-game features end in 2026: the developer products page and the passes page both state that cross-game developer product and pass sales are disabled starting **May 30, 2026**, and point you to Robux transfers instead (Docs).

---

## 2. How a Robux sale reaches you

For passes and developer products sold in-experience, the Roblox Plus docs give the worked example directly: a 100 Robux item earns the creator 70 Robux, and stays 70 even when a Plus subscriber pays 90 or 80 because Roblox subsidises the discount (Docs, Oct 2026). So plan on **70% of the listed price** for in-experience sales.

What changes the number you actually receive:
- **Managed pricing.** Regional pricing can lower the price a player pays by up to 70% below your default, never above it (Docs). Price optimization may move the default. `receiptInfo` includes the exact Robux amount paid, even during tests (Docs). Do not compute revenue from your config price.
- **Holds.** Robux subscription earnings and pass and product sales have a hold of about 5 days (Docs, subscriptions page). Creator Rewards and Plus bonuses have a 60-day hold (Docs).
- **DevEx.** Converting Robux to money is governed by the DevEx terms and the rate in effect when you cash out. This vault does not quote the rate; read it from the DevEx page on the day you need it.

Never put payout percentages in your game's UI or marketing. They change, and promising Robux you do not control breaks the rules for Premium-style prompts (Docs).

---

## 3. A model of where money comes from

Revenue in a Roblox game is a product of four things:

```
Revenue = Players reached x Retention x Payer conversion x Spend per payer
```

- **Players reached** comes from discovery: play-through rate on Home, thumbnails, events, ads. See [[Discovery and the Algorithm]] and [[Thumbnails Icons and Store Page]].
- **Retention** comes from the game loop: [[Core Loops and Session Design]], [[Retention and Return Hooks]].
- **Payer conversion** comes from having a good first offer at the right moment: [[Pricing and Store Design]].
- **Spend per payer** comes from depth: repeatable products, subscriptions, higher-tier bundles.

The Recommended for You algorithm uses **spend days per user** and **Robux spent per user** as ranking signals, alongside play-through rate, retention and playtime (Docs, discovery page). Monetization is not only income: it feeds distribution. A store that converts more of your organic players helps the game get shown more. The reverse also holds: aggressive monetization that raises first-play bounce rate hurts you twice.

### The order to build things in (rule of thumb)

1. **Make the loop worth paying for.** No store fixes a game nobody returns to. Check D1 retention first ([[Analytics and Funnels]]).
2. **Two or three permanent passes** that multiply the core loop (2x currency, faster action, extra slot). These are the anchor products most players understand.
3. **A starter pack**: one-time-per-player, high value, cheap. It converts first-time payers.
4. **Currency packs** at three to five price points, then boosts and convenience products.
5. **Rewarded video** for non-payers, once you pass eligibility.
6. **A subscription** once you have a stable daily loop to attach it to.
7. **Live ops**: limited-time offers and events ([[Live Ops Events and Updates]]).

Building in this order means every new product has players already deep enough to want it.

---

## 4. What the reference project sold

The reference project is an RNG game: players roll for blades of rising rarity, fight through zones and rebirth. Its monetization grew over about a month and is a useful example of a typical simulator store. Prices are Robux list prices from its config.

**Passes:** Lucky Rolls 75 (+1 permanent luck), Super Potions 199 (potions last 2x), Fast Roll 299, VIP 399 (cash, XP and luck multipliers, more daily gems, a bigger backpack, a chat tag and a nametag effect), Double Roll 599 (two results per roll).

**Products:** More Cash 79, Server Luck Boost 99 (2x luck for everyone in the server for 15 minutes), Jackpot Roll 499 (next roll guaranteed Legendary or better), a direct-sale weapon at 799, a big bundle at 1,499 (a Mythic item, permanent 2x luck, 500 gems), and later a starter pack, four gem packs (small to huge), two themed packs, four rotating "deal" products, weekly exclusive weapons at 999 each, and an exclusive armour set.

**Free channels:** redeemable codes (a welcome code granting cash and 25 gems, plus codes for specific items, once per player), daily rewards, a group-member luck bonus, a "like the game" reminder.

Lessons from that history, each expanded in the relevant note:

1. **Config prices drifted from real prices.** Prices lived in a config table and were also set on the Creator Dashboard. Once regional pricing and price optimization exist, a hard-coded "R$ 599" on a button is wrong for many players. Show prices from `GetProductInfoAsync`. See [[Pricing and Store Design]].
2. **Product id 0 means "not sold yet".** Every product shipped with `ProductId = 0` until someone created it on the dashboard, and the shop showed "Coming soon" with a dimmed button in that state. That is a good pattern: never show a buy button that cannot work.
3. **A product that charged but granted nothing.** One boost product's grant key was missing from the server's whitelist of grant types, so the receipt handler could not apply it. A later audit found an XP grant with the same problem. Write a startup check that every product's grant is supported. See [[Developer Products and ProcessReceipt]].
4. **Descriptions drifted from behaviour.** A pass description said "1.5x Cash" while the code gave 2x; the server luck card had to be reworded to say it affects *this* server only. Description accuracy is a policy issue, not only a polish issue ([[Roblox Policies Ratings and Compliance]]).
5. **Receipts outlived player data.** The team wiped player data several times during development (store names bumped from v1 to v6) but kept the purchase receipt store. That is correct for preventing double grants, but it means a player who bought something before a wipe loses it with no receipt left to replay. If you wipe data in a live game, re-grant purchases from your own purchase log. See [[Data Loss Prevention and Recovery]].
6. **Reconfiguring a product.** When a re-tier moved the 799 Robux weapon to a different rarity, the product key was kept but the grant was pointed at a different item. Keeping the key stable is right (receipts and "bought" flags key off it). Changing what a product gives after people bought it is a trust and policy question; announce it and honour old purchases.
7. **Off-week products refused at the receipt.** The weekly exclusive rotation refused off-week exclusive products on the server. Refuse at prompt time, never inside the receipt handler: by the time the receipt arrives the player has paid. See [[Developer Products and ProcessReceipt]].
8. **Gems needed a use.** The team noticed premium currency "didn't do much", then added a gem shop, gem-priced materials and a gem-priced server luck boost. A premium currency without sinks is a currency nobody buys twice. See [[Economies and Currencies]].
9. **The tutorial was protected.** The first roll in the tutorial was forced to a common result with no Double Roll pass doubling and no golden result. Monetized perks should not distort onboarding. See [[First-Time User Experience and Onboarding]].

---

## 5. Decision table: pass, product or subscription?

| Question | If yes | If no |
|---|---|---|
| Does the benefit last forever once bought? | Pass | Product or subscription |
| Will a player want to buy it again? | Product | Pass |
| Is the benefit a recurring delivery (daily gems, monthly cosmetic)? | Subscription | Pass or product |
| Does it change odds of a random outcome? | It is a paid random item modifier: disclose numerical odds ([[Roblox Policies Ratings and Compliance]]) | |
| Does it affect other players (server luck, global events)? | Product, with careful copy ("this server") | |
| Is it a gameplay advantage in PvP? | Think twice: it hurts retention of free players | |
| Can it be bought by players under a paid-random-items restriction? | Must offer a compliant alternative | |

A common mistake is selling a permanent multiplier as a product (players feel cheated when it ends) or a consumable as a pass (you cap your revenue at one sale).

---

## 6. Ethics, trust and the long game

Roblox players are mostly young. The platform's rules on random items, subscription honesty, notification dark patterns and ad prompts all point the same way: be clear about what the player gets. Beyond policy, trust is a retention tool. Players who feel tricked leave and post about it. See [[Ethical Design and Player Trust]].

Concrete rules of thumb:
- Every price shown must be the real price (scripted, not hard-coded).
- Every random purchase shows odds before purchase, summing to 100% (Docs).
- Every boost says exactly what it does, for how long, and to whom.
- Never interrupt combat, onboarding or a death screen with a purchase prompt. The reference project used a single "pop-up gate" rule: no auto pop-up during onboarding, during a panel, roll, cutscene, death or combat, or within 8 seconds of another pop-up.
- Make the free path real. Paid players need free players to play with.

---

## 7. Common mistakes

- **Granting in `PromptProductPurchaseFinished`.** It does not prove a purchase (Docs). Use `ProcessReceipt`.
- **Hard-coded prices.** Break regional pricing, price optimization and Plus discounts (Docs).
- **No purchase log.** Roblox does not record per-user purchase history for you (Docs). Without your own log you cannot answer support tickets or recover after data loss.
- **Designing for Premium payouts.** Gone since July 2025.
- **Ignoring policy until moderation arrives.** Odds disclosure, maturity questionnaire and age requirements gate ads eligibility and audience reach.
- **One giant launch store.** Ship a small store, measure, add. See [[Analytics and Funnels]].

---

## 8. Checklist

- [ ] Monetization plan written per the build order above
- [ ] Every product and pass created on the dashboard; no id 0 left visible as purchasable
- [ ] One server script owns `ProcessReceipt`, idempotent and data-store backed
- [ ] Prices displayed from `GetProductInfoAsync` / `GetDeveloperProductsAsync`
- [ ] Purchase log kept per player
- [ ] Odds disclosed for every paid random outcome and paid luck modifier
- [ ] `PolicyService` checks for paid random items and paid item trading
- [ ] Maturity & Compliance Questionnaire complete and accurate
- [ ] Economy and funnel events logged ([[Analytics and Funnels]])
- [ ] Re-checked every number in this folder against the live docs

## See also
[[Game Passes]] · [[Developer Products and ProcessReceipt]] · [[Subscriptions and Premium Payouts]] · [[Ads and Rewarded Video]] · [[Pricing and Store Design]] · [[Purchase Data and Receipts]] · [[Economies and Currencies]] · [[Genre Playbook - RNG and Collection Games]] · [[Ethical Design and Player Trust]] · [[Server Authority and Validation]]

## Connected notes
<!-- auto-links:start -->
[[Robux Price Points and Offer Design]] · [[Skill - Roblox Monetization Compliance]] · [[Links - Subscriptions and payouts]] · [[Shop with Game Passes and Developer Products End to End]] · [[Subscriptions and Recurring Revenue]] · [[Limited-Time Offers - Design and Ethics]]
<!-- auto-links:end -->
