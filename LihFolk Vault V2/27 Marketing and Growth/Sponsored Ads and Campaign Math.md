---
tags: [marketing, growth, ads-manager, sponsored-ads, user-acquisition, roas, math, type/guide, area/marketing, level/intermediate, api/HttpService, area/math]
---
# Sponsored Ads and Campaign Math

<!-- tldr:start -->
> [!tldr] TL;DR
> - CPP far higher than expected: Weak creative; narrow targeting; Engagement objective (higher by... -> Test new concepts; widen audience; separate budgets per objective
> - Low CPP, terrible D1 for ad players: Creative over-promises, or the ad audience is broad and casual -> Change creative to show the real loop; check onboarding for ad...
> - Organic traffic fell during a campaign: Coincidence, or the campaign attracted players whose bad... -> Ads do not affect ranking (docs); look for a release or funnel...
> - Clear goal per campaign: measurement, thumbnail test, reactivation, eligibility, or profit
> - Objective, audience and budget type chosen deliberately (they cannot change later)
> - Launch data tags whitelisted and logged as an analytics field
>
> Cost: TL;DR ~230 tok · whole note ~4.3k tok. Read more: ## 1. The platform, as documented (Roblox docs, as of October 2026) · ## 7. Measuring ad cohorts in your own analytics · ## 8. Failure modes · ## 11. Checklist
<!-- tldr:end -->

Paid user acquisition on Roblox means Ads Manager: your game's tile shown as a sponsored placement on Home and in search, with Roblox's auto-bidder spending a budget you set. The interface is simple. The decisions are not: who to target, how much a player is worth to you, how long to wait before judging, and what the ads can and cannot do for organic ranking.

This note covers the platform mechanics (Roblox docs, as of October 2026), the maths of cost per play, payback and return on ad spend, a worked campaign plan, and the failure modes that make most first campaigns lose money. [[Ads and Rewarded Video]] covers the other direction (earning from ads in your game) and gives a short introduction to buying; this note is the deep version of the buying side.

---

## 1. The platform, as documented (Roblox docs, as of October 2026)

### Placements and objectives
- Campaigns promote a game as a **sponsored tile on Home and in search results**. A user can see both the sponsored tile and your organic Recommended for You tile. **Running ads does not affect Recommended for You ranking.**
- Objectives:
  - **Plays**: targets players most likely to start a session.
  - **Earnings** (limited availability): targets players most likely to spend Robux. Reports ROAS (attributed USD earnings divided by spend).
  - **Engagement**: targets highly engaged, age-checked players who count toward the Kids and Select threshold. Docs warn of a higher cost per play, suggest a dedicated budget and 3 to 5 days for results, and note the campaign **does not auto-pause** when the threshold is reached.

### Budget and bidding
- **Auto-bidding only**: you set a budget and a schedule; Roblox calculates bids. No manual CPM or CPC bids are documented.
- Budget is **daily** (cap per day) or **lifetime** (cap for the campaign).
- Pay with a card (18+) or **ad credits** converted from Robux (13+). Conversion is permanent; credits can only be spent in Ads Manager; Robux earned at the US 18+ rate converts first. Unused credits are returned after the campaign ends. The page does not state a Robux to credit conversion ratio that I could confirm; check the conversion screen.
- First-time card users see a $5 USD charge on first submission, applied to the first bill.
- **Invalid traffic**: campaigns are analysed 14 days after they end; refunds for invalid traffic are applied at 16 days.

### Targeting
- Audiences: **All Players**, **New Players** (never played or not in 180+ days), **Recent Players** (played in the last 30 days; needs 10,000+ recent players), **Lapsed Players** (30 to 180 days inactive; needs 20,000+ lapsed players).
- Advanced: location, age, gender, genre, device type.

### Creatives
- Up to **10 thumbnails** per campaign, distributed evenly and individually toggleable. Shown at 16:9; other sizes are resized.
- Asset uploads are moderated (typically within 48 hours); campaigns are reviewed (typically within 24 hours).

### Reporting
- Spend, impressions, clicks, plays, **CPP (cost per play)**, playtime, earnings.
- Impressions and clicks are near real time. **Plays and earnings use attribution windows of up to 30 days and can take up to 48 hours to appear.**
- Views by All, New (30-day attribution), Recent and Resurrected users.

### What you can change after publishing
Name, budget amount, schedule and creatives can change. **Goal, audience and budget type are fixed.** Decide those carefully; a wrong audience means a new campaign.

### Join options
Advanced join options let ad players land in a chosen start place and carry **launch data**, readable with `Player:GetJoinData()`. Use it to tag ad cohorts in your own analytics.

---

## 2. What ads can and cannot do

| Ads can | Ads cannot |
|---|---|
| Buy a predictable cohort for measuring onboarding changes | Raise your Recommended ranking directly (ad players are excluded from ranking signals) |
| Speed up a game's *consideration* for recommendations (Roblox docs, discovery page) | Fix a leaky first session |
| Bring highly engaged players toward the Kids and Select threshold (Engagement objective) | Turn a weak promise into a strong one; the creative is still your thumbnail |
| Reactivate lapsed players (Lapsed audience, if you have 20,000+) | Guarantee that ad players spend |
| Test thumbnails with controlled spend | Replace word of mouth, which brings friends who co-play (a ranking signal) |

The most common wrong belief is "ads kickstart the algorithm". The docs say ad-acquired players do not count in ranking. The indirect effect is real but second order: ad players who enjoy the game may return organically, bring friends, and favourite the game, and those later behaviours can feed signals. If the game does not retain, none of that happens.

---

## 3. The core maths

### Definitions
- **CPP**: spend / plays. Reported by Ads Manager.
- **D1, D7**: share of a cohort that returns on day 1 / day 7.
- **ARPU_N**: average Robux spent per acquired player in the first N days (all players, including non-payers).
- **s**: your share of Robux spent on passes and developer products. Commonly documented as 70% for the creator (Roblox docs on passes and products; confirm the current figure in your dashboard).
- **V**: USD value of one Robux to you. If you cash out through DevEx, use the rate in the official DevEx terms; if you reinvest Robux as ad credits, use what that Robux would otherwise be worth to you. This note does not quote a DevEx rate; check the official terms.

### Value of an acquired player
```
Value_N (USD) = ARPU_N (Robux) x s x V
```
Plus any value from things you cannot easily measure (friends they bring, [[Creator Rewards]] payouts, see below). Treat those as upside, not as the case for the campaign.

### Payback and ROAS
```
ROAS_N = Value_N / CPP          (per acquired play, roughly)
Break-even CPP_N = Value_N
```
If CPP is above Value_30, the campaign loses money over 30 days. Many games accept ROAS below 1 at 30 days if 90-day value is higher, but only if they have the retention data to show that tail exists.

### Plays are not players
Ads Manager counts **plays**. One person can generate several plays. For cohort maths, use your own join data: tag ad players with launch data, count unique users, and compute ARPU per unique user. Otherwise your ARPU denominator and Ads Manager's denominator disagree and ROAS looks better or worse than it is.

---

## 4. Worked example

A collection game wants to know whether a Plays campaign can pay for itself. All numbers are illustrative.

**Inputs from a small test (daily budget, 5 days):**

| Metric | Value |
|---|---|
| Spend | $250 |
| Plays | 2,500 (CPP $0.10) |
| Unique users (launch data tag) | 2,000 |
| Ad cohort D1 | 14% (organic cohort: 22%) |
| Ad cohort ARPU at day 7 | 2.0 Robux per unique user |
| Organic ARPU at day 7 | 3.5 Robux |

**Projecting to 30 days.** The game's organic cohorts show ARPU at day 30 is roughly 2x ARPU at day 7. Applying the same multiplier to the ad cohort (an assumption; check it after 30 days): ARPU_30 = 4.0 Robux per unique user.

**Value per unique user** = 4.0 x 0.7 x V. With a placeholder V of $0.0035 per Robux (substitute the real figure from the DevEx terms or your own valuation), Value_30 = about $0.0098.

**Cost per unique user** = $250 / 2,000 = $0.125.

**ROAS_30** = 0.0098 / 0.125 = about 0.08.

The campaign returns about 8 cents per dollar over 30 days. That is typical for small games: paid acquisition on Roblox rarely pays back on purchases alone unless ARPU is high. The decision is then not "is this profitable?" but "what is this buying?":
- If the goal is a measured onboarding test, $250 for 2,000 controlled players is cheap.
- If the goal is Kids and Select eligibility, compare the cost per highly engaged player with the expedited review fee and the time saved.
- If the goal is profit, the game needs a higher ARPU or a cheaper CPP before scaling.

**Sensitivity.** Change one input at a time to see what matters:

| Change | ROAS_30 |
|---|---|
| Baseline | 0.08 |
| CPP halves (better thumbnail) | 0.16 |
| Ad cohort D1 rises to organic level, ARPU rises proportionally (about +57%) | 0.12 |
| ARPU 10x (a game with strong monetisation) | 0.8 |

The lesson: creative quality (CPP) and monetisation depth (ARPU) dominate. Bid tactics barely exist (auto-bidding), so your levers are the thumbnail, the audience, and the game.

---

## 5. Creator Rewards and acquisition value

Creator Rewards add a second, separate income line that ads might touch (Roblox docs, as of October 2026):
- **Daily Engagement**: 5 Robux per qualifying active spender (spent $9.99+ in the past 60 days) per day, for players who spend 10+ minutes in your game and whose day's first three launched games include yours.
- **Audience Expansion**: 35% revenue share on a new or reactivated user's first $100 of qualifying purchases (Robux, Premium, UGC subscriptions) anywhere on Roblox in their first 60 days, when they arrive by your Share Link, direct link or name search and play 10+ minutes that day; the game must average 100+ DAU for the 60 days after. Reactivated means inactive for 60 consecutive days. The definition excludes users who joined "through a Roblox promotional or marketing campaign".

I could not confirm whether a player who first arrives from a sponsored ad tile counts as joining through a "Roblox promotional or marketing campaign" for Audience Expansion. **Assume ad-acquired users do not earn Audience Expansion rewards** until you see otherwise in your own dashboard. Share links from your own off-platform channels are the documented route ([[Short-Form Video Marketing]]).

---

## 6. Campaign design patterns

### The measurement campaign
- Objective: Plays. Audience: New Players. Daily budget small enough to run 5 to 7 days.
- Launch data: tag `{"src":"ads","v":"onb2"}` so your funnel can split ad players by test.
- Run while the game is excluded from Recommended (soft launch) or while organic traffic is low, so ad cohorts are not drowned.
- Success: a clean onboarding funnel read, not ROAS.

### The thumbnail test campaign
- Up to 10 creatives, evenly distributed. Toggle off clear losers after enough impressions.
- Compare CPP by creative and, crucially, the **D1 of players each creative brought** (launch data cannot tell creatives apart, so run separate short campaigns per concept if you need that read). A creative with low CPP and poor D1 is over-promising.
- Feed winners into the organic thumbnail pool ([[Thumbnails Icons and Store Page]]).

### The reactivation campaign
- Audience: Lapsed Players (needs 20,000+). Time it to a real update with an event, so returning players find something new on the day they come back ([[Update Cadence and Hype Cycles]]).
- Measure with the Resurrected Users view and your own "returning after 30+ days" segment.

### The eligibility campaign
- Objective: Engagement. Dedicated budget, 3 to 5 days, **pause manually** at the threshold. Track progress on the Audience Reach dashboard ([[Publishing an Experience]]).

### Reading lag correctly
Plays and earnings can take up to 48 hours to appear and use up to 30-day attribution windows. Do not judge a campaign on its first evening. Rule of thumb: decide on CPP after 2 to 3 days, on D1 after 3 to 4 days, on 7-day ARPU after 9 to 10 days.

---

## 7. Measuring ad cohorts in your own analytics

```lua
--!strict
-- ServerScriptService/Services/AcquisitionTag (ModuleScript)
-- Reads launch data from ad or share-link joins and stores a small, fixed tag.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local AcquisitionTag = {}

-- Only these values are accepted, to keep analytics field cardinality small.
local ALLOWED_SOURCES = { ads = true, share = true, event = true }
local MAX_VARIANT_LEN = 16

local tags: { [Player]: string } = {}

local function parse(player: Player): string
	local joinData = player:GetJoinData()
	local raw = joinData.LaunchData
	if typeof(raw) ~= "string" or #raw == 0 or #raw > 200 then
		return "organic"
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(decoded) ~= "table" then
		return "organic"
	end
	local src = (decoded :: any).src
	local v = (decoded :: any).v
	if typeof(src) ~= "string" or not ALLOWED_SOURCES[src] then
		return "organic"
	end
	if typeof(v) == "string" and #v <= MAX_VARIANT_LEN and v:match("^[%w_]+$") then
		return src .. "_" .. v
	end
	return src
end

function AcquisitionTag.Get(player: Player): string
	return tags[player] or "organic"
end

Players.PlayerAdded:Connect(function(player)
	tags[player] = parse(player)
end)

Players.PlayerRemoving:Connect(function(player)
	tags[player] = nil
end)

return AcquisitionTag
```

Reviewed, not run. Notes:
- Launch data is **player-controlled** (anyone can craft a link with any launch data). Never grant valuable rewards based on it without limits, and whitelist values so a crafted link cannot explode your analytics field cardinality ([[Analytics and Funnels]]).
- "organic" here means "no recognised launch data", which also covers Recommended, search and friends. That is fine for ad-versus-rest comparisons.
- Pass `AcquisitionTag.Get(player)` as a custom field on onboarding and shop funnel steps. Keep the set of possible values small (under a few dozen).
- If you also persist the first-seen tag in the player's profile, you can compute ARPU at day 30 for ad cohorts from your own data rather than estimating.

---

## 8. Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| CPP far higher than expected | Weak creative; narrow targeting; Engagement objective (higher by design) | Test new concepts; widen audience; separate budgets per objective |
| Low CPP, terrible D1 for ad players | Creative over-promises, or the ad audience is broad and casual | Change creative to show the real loop; check onboarding for ad players specifically |
| Organic traffic fell during a campaign | Coincidence, or the campaign attracted players whose bad experience you also served organically | Ads do not affect ranking (docs); look for a release or funnel change on the same date |
| Engagement campaign kept spending after eligibility | No auto-pause (docs) | Pause manually; set a lifetime budget |
| "Plays" do not match your join counts | Plays are not unique users; attribution lag | Use unique users from launch data; wait 48 hours |
| Credits trapped | Robux converted to credits cannot be converted back (docs) | Convert only what you will spend |
| Invalid traffic suspected | Bot-like plays from the network | Refund analysis runs after the campaign; keep your own logs |

---

## 9. When not to buy ads
- D1 is unmeasured or clearly below your genre benchmark.
- Your first minute has an open leak.
- You cannot answer "what is this campaign buying?" in one sentence (a test result, eligibility, reactivation for an update).
- You would convert Robux you need for payroll or commissions into irreversible credits.
- The game is about to change substantially (results will describe a game that no longer exists).

## 10. Never do this
- **Buying traffic from outside services** (bot plays, "visit boosts", paid likes). Disruptive bots and alt accounts break Community Standards; fake visits do not count toward ranking and pollute your own analytics so badly that you can no longer read your real funnel.
- **Creatives that misrepresent the game.** Moderated, and the CPP you save is paid back in bounce.
- **"Free Robux" in ad creatives.** Scam territory under Community Standards.

## 11. Checklist
- [ ] Clear goal per campaign: measurement, thumbnail test, reactivation, eligibility, or profit
- [ ] Objective, audience and budget type chosen deliberately (they cannot change later)
- [ ] Launch data tags whitelisted and logged as an analytics field
- [ ] Separate budgets per objective; Engagement campaigns paused manually
- [ ] Decisions wait for attribution lag (48 h) and D1
- [ ] ROAS computed on unique users with your real share and Robux value
- [ ] Creatives show real gameplay only
- [ ] Only convert Robux to credits that will be spent

## See also
[[Marketing and Growth Start Here]] · [[Ads and Rewarded Video]] · [[Discovery and the Algorithm]] · [[Launch Strategy - The First Two Weeks]] · [[A-B Testing and Experiments on Roblox]] · [[Analytics and Funnels]] · [[Thumbnails Icons and Store Page]] · [[Subscriptions and Premium Payouts]] · [[Robux Price Points and Offer Design]]

## Connected notes
<!-- auto-links:start -->
[[Click-Through Rate]] · Retention Cohorts · Monetization Overview · Working with Content Creators · Running a Small Studio as a Business · DevEx and Cashing Out
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]] · [[Discovery and Monetization Changes 2025-2026]] · [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]] · [[Experience Description and Search Keywords]] · [[Competitor Analysis Method]]
<!-- related:end -->
