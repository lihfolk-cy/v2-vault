---
tags: [delta, discovery, algorithm, recommended-for-you, thumbnails, monetization, devex, creator-rewards, roblox-plus, regional-pricing, creator-store]
verified: 2026-10-28
---
# Discovery and Monetization Changes 2025-2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Optimising thumbnails for qPTR, which no longer exists.
> - Avoid: Leaving the default thumbnail on a live game (ineligible for Home since October 19, 2026).
> - Avoid: Quoting $0.0035 per Robux, or one DevEx rate for all revenue.
> - At least one honest custom 16:9 thumbnail uploaded.
> - Analytics watched for first-play bounce and Day 8-28 retention.
> - Prices shown via `GetProductInfoAsync`.
>
> Cost: TL;DR ~140 tok · whole note ~2.5k tok. Read more: ## 1. Recommended For You now values 28-day retention (June 15, 2026) · ## 5. Roblox Plus replaced Premium for new subscribers (April 30, 2026) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

How games get recommended and how creators get paid both changed between mid-2025 and October 2026. Advice built on 2024 rules (optimise qualified play-through rate, design for Premium Payouts, assume one DevEx rate) is now wrong. Labels follow [[Roblox Changes 2025-2026]].

## 1. Recommended For You now values 28-day retention (June 15, 2026)

**Roblox docs** (DevForum, June 15, 2026: https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575; newsroom "Optimizing Discovery", June 2026: https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox).

- Window grew from 7 to **28 days**, measured over Day 1, Day 2-7 and Day 8-28.
- Kept: playtime, play days, qualified play sessions, intentional co-play days, spend days, Robux spent.
- **Removed: qualified play-through rate (qPTR). Added: play-through rate (PTR) and first-play bounce rate.**
- Signals count only users who joined organically from the Recommended For You sort on Home. Ads, search and friend joins do not feed them.
- Data: Creator Analytics, Acquisition, Home Recommendations. Benchmarks are for comparison only.
- Cold start for new games was not addressed in the post.
- **Reported:** the update was live for all players by August 20, 2026; an April 10, 2026 test cut some games' Home impressions by 70-80% (creator reports).

Design consequence: the first session must hook (bounce rate) and the game must give reasons to return in week 2-4 (play days and spend days over 28 days). A burst of day-1 playtime matters less than before. See [[Discovery and the Algorithm]] and [[Retention and Return Hooks]].

## 2. Other discovery changes

| Change | Date | Label and source |
|---|---|---|
| **A custom thumbnail is required** for Home recommendation eligibility (default placeholder does not count; 16:9, ideally 1920x1080; up to 5) | October 19, 2026 | Roblox docs, https://devforum.roblox.com/t/homepage-recommendation-eligibility-now-requires-a-custom-thumbnail/4945086/1 |
| Impressions, clicks and plays from Home, Search and Charts recorded differently; RFY ranking unchanged | October 12, 2026 | Roblox docs, https://devforum.roblox.com/t/improved-discovery-measurement-in-creator-analytics/4930122 |
| A game's Sponsored ad and its RFY tile may both appear on Home | Oct 2026 tests | Roblox docs, https://devforum.roblox.com/t/upcoming-tests-sponsored-experiences-to-appear-within-recommended-for-you-on-home/3938575 |
| Experiments: Early Harm Detection, near-real-time playtime, payer conversion and ARPU for the first 24 h, refreshed every 5 min | Sept 2026 | Roblox docs, https://devforum.roblox.com/t/experiments-catch-experiment-regressions-faster-with-early-harm-detection/4907734 |
| Ads Manager "Earnings" objective open to nearly 30,000 games | Sept 2026 | Roblox docs, weekly recap Sept 28-Oct 2, 2026 |

Analytics comparisons across October 12, 2026 are not like-for-like.

## 3. DevEx rates

| Rate | Per earned Robux | Applies | Label |
|---|---|---|---|
| Standard | **$0.0038** (was $0.0035) | From September 5, 2025 | Reported (rate trackers; consistent across sources) |
| US 18+ | **$0.0054** (+42%) | From June 8, 2026, on spend by age-checked 18+ US players on developer products, passes, subscriptions and private servers, in games meeting the R15 character requirements | Roblox docs, newsroom April 2026: https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42 ; DevForum https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091 |

Payouts are a blend; do not model revenue with one constant. Where the 18+ rate and the Plus incentive overlap, the creator gets the higher (US 18+) rate (Roblox docs, DevForum post). Transferred Robux (a Plus feature) cannot be DevEx'd.

## 4. Creator Rewards replaced Premium Payouts (July 24, 2025)

**Roblox docs** (https://create.roblox.com/docs/creator-rewards; DevForum https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628).

- **Daily Engagement:** 5 Robux per day per **Active Spender** who plays 10+ minutes in a 24-hour period, if your game is one of the first three they launch that day. Active Spender: at least $9.99 of qualifying purchases in the past 60 days and not a new or reactivated user in that period.
- **Audience Expansion:** 35% of the first $100 of qualifying purchases a new or reactivated user makes in their first 60 days, if they joined through your Share Link (or their first session that day was your game via direct link or search) and played 10+ minutes; the game must average 100+ DAU for 60 days. Requires an ID-verified owner. One reward per user; alts excluded.
- Paid as Earned Robux with a **60-day hold**.

Engagement-based payouts and "Premium Payouts" no longer exist. Designing to keep Premium members in-game earns nothing extra.

## 5. Roblox Plus replaced Premium for new subscribers (April 30, 2026)

**Roblox docs** (DevForum, April 10, 2026: https://devforum.roblox.com/t/introducing-roblox-plus/4567894; newsroom https://about.roblox.com/newsroom/2026/04/introducing-roblox-plus-subscription).

- $4.99 per month, global. Premium stopped new sales; the Premium 10% Robux purchase bonus ended May 30, 2026.
- Plus members get 10% off in-game and avatar items (20% from the third month). **Roblox funds the discount**; creator earnings per sale are unchanged.
- Plus members get **free, unlimited paid private servers**. Creators are paid instead: on each Plus renewal, Roblox looks back 30 days and pays up to **100 Robux per subscriber per server** for that subscriber's top 5 paid private servers with 60+ cumulative minutes (free private servers do not count).
- **Sign-up bonus:** 250 Robux per month for the first three paid months (up to 750) for each subscriber who signs up through your game's `MarketplaceService:PromptRobloxSubscriptionPurchase`.
- Use `GetProductInfoAsync` to show prices; hard-coded prices are wrong for discounted Plus members.
- **Unverified:** how `Player.MembershipType` reports Plus members. Do not gate perks on `Enum.MembershipType.Premium` without testing a Plus account.

```lua
-- Client: a "Get Plus" button (creator earns the sign-up bonus)
plusButton.Activated:Connect(function()
	MarketplaceService:PromptRobloxSubscriptionPurchase(Players.LocalPlayer)
end)
-- Shop label: never hard-code; Plus discounts and regional prices change it
local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, passId, Enum.InfoType.GamePass)
if ok then priceLabel.Text = `R$ {info.PriceInRobux}` end
```

The vault's [[Subscriptions and Premium Payouts]] (checked against the reference in October 2026) gives the signature as `PromptRobloxSubscriptionPurchase(player)`, notes `PromptRobloxSubscriptionPurchaseFinished(didTryPurchasing)` means an attempt, not a purchase, and records **`PromptPremiumPurchase` as deprecated**: replace Premium upsells with the Plus prompt. Legacy Premium members still report `Enum.MembershipType.Premium`.

## 6. Regional pricing defaults

**Roblox docs:** regional pricing for passes opened April 2025 (https://devforum.roblox.com/t/introducing-regional-pricing-for-passes/3621382); for developer products October 2025 (https://devforum.roblox.com/t/introducing-regional-pricing-for-developer-products/3971235); **on by default for all passes from March 30, 2026** (announced March 5, 2026: https://devforum.roblox.com/t/enabling-regional-prices-for-all-passes-to-grow-your-global-audience/4471199). Developer products stay opt-in because of gifting and trading arbitrage.

- **Reported:** some creators saw lower revenue; donation games saw cheap regional "donations".
- **Unverified:** a GitHub issue says the web field `isRegionalPricingEnabled` was retired on 2026-07-20 in favour of "managed pricing".

Impact: a pass's price differs by player. Display the price from `GetProductInfoAsync`, and never compare a client-sent price to a constant. Donation boards that rank by "Robux donated" should use the receipt's `CurrencySpent`, not the list price.

## 7. Creator Store sells for USD

**Roblox docs** (DevForum "Buy and Sell Models on the Creator Store": https://devforum.roblox.com/t/buy-and-sell-models-on-the-creator-store/4142112): eligible ID-verified creators can sell Models (and plugins) for **USD only**, keeping 100% minus sales tax and payment processing, with no DevEx fee. Paid models are Restricted assets; collaborators may need explicit permission. Paid models are used for AI training only if the seller opts in. **Unverified:** exact launch dates.

## Common mistakes

- Optimising thumbnails for qPTR, which no longer exists. Optimise PTR, bounce and 28-day return.
- Leaving the default thumbnail on a live game (ineligible for Home since October 19, 2026).
- Quoting $0.0035 per Robux, or one DevEx rate for all revenue.
- Building perks to "earn Premium Payouts".
- Hard-coding Robux prices in UI.
- Treating private server sales from Plus members as lost revenue without counting the Plus server payout.

## Checklist

- [ ] At least one honest custom 16:9 thumbnail uploaded.
- [ ] Analytics watched for first-play bounce and Day 8-28 retention.
- [ ] Prices shown via `GetProductInfoAsync`.
- [ ] Revenue models use blended DevEx (standard plus US 18+ share).
- [ ] Optional: Plus prompt placed where it fits the game, not as a nag.
- [ ] Share Links used for invites (Audience Expansion credit).

## See also

- [[Roblox Changes 2025-2026]]
- [[Discovery and the Algorithm]]
- [[Thumbnails Icons and Store Page]]
- [[Subscriptions and Premium Payouts]]
- [[Subscriptions and Recurring Revenue]]
- [[Pricing and Store Design]]
- [[Robux Price Points and Offer Design]]
- [[Creator Store and Toolbox Safety]]
