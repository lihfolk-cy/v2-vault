---
tags: [monetization, analytics, arpdau, arppu, conversion, ltv, payback, ads, creator-rewards, metrics, type/guide, area/monetization, area/growth]
---
# Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating CPP as cost per new player.
> - Avoid: Ignoring Creator Rewards in LTV, or counting them for users who were not attributed.
> - Avoid: Comparing Robux revenue to dollar ad spend without converting at your real DevEx rate.
> - Dashboard metrics read with the docs' definitions.
> - First-seen day and acquisition source saved per player.
> - Purchases logged server-side with cohort-day bucket and source.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## Revenue sources that belong in LTV · ## Cohort LTV from your own analytics · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Unit economics answers one question: is a player worth more than it costs to get them? On Roblox the inputs are Robux earned per player (from passes, products, subscriptions, commissions and [[Creator Rewards]]) and the cost of acquisition (mostly sponsored ads). This note defines the metrics as the Roblox dashboard does, shows how to compute cohort LTV from your own analytics where the dashboard stops, and gives the payback arithmetic with worked numbers that are clearly illustrative. Campaign mechanics are in [[Sponsored Ads and Campaign Math]]; this note is the model underneath.

Source labels: **Roblox docs** (create.roblox.com, read October 2026), **Rule of thumb**, **Illustrative** (made-up numbers to show the method; not benchmarks).

## Definitions (Roblox docs)

The Monetization dashboard defines:

- **Paying users**: daily active users who purchased a game-related item.
- **Conversion rate** (payer conversion): percent of daily active users who are also paying users.
- **ARPPU**: average revenue per paying user.
- **ARPDAU**: average revenue per daily active user, described as a combination of payer conversion and ARPPU.
- Revenue is shown split by developer products, passes and commissions.

The docs give no formulas or benchmarks. The standard relationships, which you should verify against your own exports:

```
ARPDAU = revenue_day / DAU
conversion = payers_day / DAU
ARPPU = revenue_day / payers_day
ARPDAU = conversion * ARPPU
```

The dashboard's own guidance: high ARPPU with low ARPDAU means revenue comes from a small subset of users.

## Revenue sources that belong in LTV

- Pass, product and subscription Robux (dashboard revenue).
- **Creator Rewards** (Roblox docs, started 24 July 2025, replacing Engagement-Based Payouts):
  - *Daily Engagement*: 5 Robux per day for each Active Spender (at least $9.99 in qualifying purchases in the past 60 days) who plays 10+ minutes, if yours is among the first three experiences they launch that day.
  - *Audience Expansion*: 35 % of the first $100 of a new or reactivated user's qualifying purchases during their first 60 days, when that user was attributed to you via a share link, direct link or search, played 10+ minutes on the join day, and your experience averages 100+ DAU over the following 60 days. Requires an ID-verified owner (or a group member with revenue permission).
- Ad revenue from rewarded video, if used ([[Ads and Rewarded Video]]).

Audience Expansion counts purchases across the platform, not only in your game, which is why traffic you bring in through share links can be worth more than its in-game spend. It is also why your share-link attribution matters for unit economics.

## Cohort LTV from your own analytics

The dashboard gives daily averages; LTV needs cohorts. Log on the server, per player:

- `first_seen` day (stored in their save on first join).
- Acquisition source (share link or launch data tag, ad campaign tag, or "organic").
- Every purchase with Robux amount and product id (in your `ProcessReceipt` success path and pass purchase handler).

```lua
--!strict
-- Server: called after a purchase is granted. Analytics wrapper is your own (see Analytics and Funnels).
local function recordPurchase(player: Player, productKey: string, robux: number, profile: any)
	local daysSinceFirst = math.floor((os.time() - profile.firstSeen) / 86400)
	Analytics.logEconomy(player, "Robux", robux, productKey, {
		cohortDay = tostring(math.min(daysSinceFirst, 60)), -- bucket to keep cardinality low
		source = profile.source or "organic",
	})
end
```

Then per acquisition cohort (for example, everyone first seen in week 12 from campaign A):

```
LTV_d = (total Robux spent by the cohort up to day d) / (cohort size)
```

Compute LTV_7, LTV_30 and LTV_60. Keep cohort size large enough to trust (rule of thumb: hundreds of players minimum). Do not put user ids or timestamps into custom fields; use buckets ([[Analytics and Funnels]]).

## From Robux to money

Robux earned is not cash. To compare with ad spend, convert at the DevEx rate that applies to you (see [[DevEx and Cashing Out]]; rates and eligibility are in the DevEx terms and change). If you buy ads with Robux-converted ad credits, compare Robux to Robux instead and skip the conversion.

## Payback arithmetic

```
CPP = ad spend / plays                         (Roblox reports this)
new players = plays * share who are actually new (ads also bring returning players)
value per new player = LTV_d (own revenue) + expected Creator Rewards per player
payback at day d = value per new player at d / (CPP / new-player share)
```

Payback above 1.0 by your chosen horizon means the campaign earned back its cost.

**Illustrative example** (numbers invented to show the method):

- Spend 100 units for 2,000 plays: CPP 0.05.
- 80 % of plays are new players: cost per new player 0.0625.
- Cohort LTV_30 converted to the same units: 0.04. Creator Rewards estimate per player: 0.01.
- Payback at day 30: 0.05 / 0.0625 = 0.8. Not paid back; check LTV_60 or improve the funnel before scaling.

The common error is using CPP directly as cost per new player. Engagement-objective campaigns have higher CPP and smaller audiences (Roblox docs, Ads Manager), but may produce cohorts with higher LTV; compare on payback, not CPP.

## What moves each lever

| Lever | Raised by | Hurt by |
|---|---|---|
| Conversion | A cheap, obviously valuable first offer at the right moment; starter packs | Store hidden in menus; aggressive prompts that cause refunds |
| ARPPU | Depth of useful items; subscriptions; fair repeatable consumables | Pay-to-win that drives non-payers away |
| Retention (multiplies everything) | Long-term goals, social play | Exhausting content in one session |
| CPP | Strong thumbnails, honest creative | Over-promising creative (cheap clicks, poor cohorts) |

Ethics constrain all of this. Paid random items must disclose odds and be restricted where policy requires ([[Paid Random Items and Odds Disclosure in Practice]]); spend levers that target children's impulses produce refunds, complaints and press risk ([[Ethical Design and Player Trust]]).

## Common mistakes

- **Treating CPP as cost per new player.**
- **Ignoring Creator Rewards** in LTV, or counting them for users who were not attributed.
- **Comparing Robux revenue to dollar ad spend** without converting at your real DevEx rate.
- **Daily averages instead of cohorts.** A sale day inflates ARPDAU and tells you nothing about LTV.
- **Tiny cohorts.** Ten payers is not a signal.
- **High-cardinality analytics fields** (user ids, exact timestamps).

## Checklist

- [ ] Dashboard metrics read with the docs' definitions.
- [ ] First-seen day and acquisition source saved per player.
- [ ] Purchases logged server-side with cohort-day bucket and source.
- [ ] LTV_7, LTV_30, LTV_60 per cohort; cohort sizes recorded.
- [ ] Creator Rewards estimated and attributed correctly.
- [ ] Payback computed with new-player share, in consistent units.
- [ ] Scale ads only on payback above 1.0 at your chosen horizon.

## See also

- [[Sponsored Ads and Campaign Math]]
- [[Analytics and Funnels]]
- [[DevEx and Cashing Out]]
- [[Monetization Overview]]
- [[Economy Telemetry and Balancing Live]]

## Connected notes

[[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]] · Subscriptions and Recurring Revenue · Retention Cohorts · [[Robux Price Points and Offer Design]]

Sources: https://create.roblox.com/docs/production/analytics/monetization ; https://create.roblox.com/docs/creator-rewards ; https://create.roblox.com/docs/production/promotion/ads-manager (read 28 October 2026).

<!-- related:start -->
## Related
[[Experience Description and Search Keywords]] · [[Discovery and Monetization Changes 2025-2026]] · [[Subscriptions and Premium Payouts]] · [[Discovery and the Algorithm]] · [[Pricing and Store Design]] · [[Economy Inflation Sinks and Faucets Math]] · [[Community Building]] · [[Publishing an Experience]] · [[Roblox Policies Ratings and Compliance]] · [[Refunds Chargebacks and Purchase Support]]
<!-- related:end -->
