---
tags: [monetization, subscriptions, roblox-plus, creator-rewards, premium, luau, type/guide, area/monetization, level/intermediate, area/scripting, api/Player]
---
# Subscriptions and Premium Payouts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `PromptPremiumPurchase` or `MembershipType` checks in new code -> `PromptRobloxSubscriptionPurchase(player)` and...
> - Avoid: Planning revenue around Premium playtime payouts (gone since July 2025).
> - Avoid: Granting a Plus thank-you reward on `PromptRobloxSubscriptionPurchaseFinished` (it only says they tried).
> - Subscription benefits distinct from passes; same on every platform
> - Status cached server-side; `UserSubscriptionStatusChanged` handled
> - Daily stipend idempotent per UTC day
>
> Cost: TL;DR ~170 tok · whole note ~4.3k tok. Read more: ## 1. Experience subscriptions · ## 2. Roblox Plus (the platform subscription) · ## 5. Common mistakes · ## 6. Checklist
<!-- tldr:end -->

Recurring revenue on Roblox now comes from three different places, and their names are easy to confuse:

1. **Experience subscriptions**: *your* monthly product, sold inside your game.
2. **Roblox Plus**: Roblox's own platform subscription (launched April 30, 2026), which pays creators when players subscribe through their game, discounts purchases at Roblox's expense, and pays for paid private server use.
3. **[[Creator Rewards]]**: platform payouts for engaging and bringing in spending users, which **replaced Engagement-Based Payouts ("Premium Payouts") on July 24, 2025**.

Premium itself stopped taking new sign-ups when Plus launched; existing members keep it. This note explains all three plus the Premium legacy APIs you will still find in older code. Everything was checked against the Creator Hub (Subscriptions, Roblox Plus, Creator Rewards and Engagement-Based Payouts pages) and the Roblox newsroom **as of October 2026**. These programs changed twice in 12 months; verify before you plan around a number.

---

## 1. Experience subscriptions

### What they are
A monthly, auto-renewing product you define. Unlike a pass, the benefit lasts only while the player keeps paying (Docs).

### Prices and payouts (Docs, Oct 2026)

| | Robux-priced | Local-currency priced |
|---|---|---|
| Who can offer | All creators | ID- or phone-verified accounts |
| Price | Any amount, minimum 49 Robux | Five tiers: $2.99, $4.99, $7.99, $9.99, $14.99 |
| Platforms | All | Web, App Store, Google Play only; not available in several countries (Docs list includes Argentina, China, Colombia, India, Indonesia, Japan, Russia, Taiwan, Türkiye, UAE, Ukraine, Vietnam) |
| Your share | 70% every month, in Robux | 70% first month, 100% later months, in Robux, based on the base platform price after platform fees |
| Hold | About 5 days, like passes and products | 30 days; credited after the full term is delivered |
| Refunds | Non-refundable | Refund in the hold window cancels that payout; later refunds are deducted from your balance |
| Price changes | Once every 60 days; increases need 30 days' notice to subscribers | Cannot edit; delete and recreate |
| Managed pricing | Regional pricing on by default and cannot be turned off | Not available |

Docs give the worked example: a $5 monthly subscription earns 350 Robux in the first month and 500 Robux per month after that.

### Limits and rules (Docs)
- Up to **50 subscriptions per game** (active and inactive combined).
- A player can own all of a game's subscriptions at once. **Mutually exclusive tiers (Bronze/Silver/Gold) are not supported.** Design distinct benefit sets, not tiers of the same benefit.
- Product type: **Durable** (permanent items), **Consumable** (temporary, re-purchasable, expire) or **Currency**.
- Before first activation you confirm a **permanent shortened game name** shown on billing.
- Subscriptions cannot be cross-sold by other games and are not eligible for affiliate fees.
- Guidelines: clear names that state price and duration; **same benefits on every platform**; honour benefits for the full term and never revoke them behind the scenes; no directing users to buy elsewhere; no extra tasks (such as social posts) to unlock already-paid benefits (battle passes are exempt).
- Taking one off sale: choose whether existing subscribers keep renewing. **Deleting an active subscription refunds all active subscribers in full and you receive nothing** (Docs). Take it off sale, cancel renewals, wait out the period, then delete.
- Cancelled subscriptions stay active until the end of the paid cycle.
- Analytics: appear after first activation; four webhook events (purchased, renewed, cancelled, refunded) give real-time updates (Docs).

### APIs (Docs)
- `MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)`: server-only; returns a dictionary with `IsSubscribed` and `IsRenewing`.
- `Players.UserSubscriptionStatusChanged`: fires when a user's status for a subscription changes.
- `MarketplaceService:PromptSubscriptionPurchase(player, subscriptionId)` and `PromptSubscriptionPurchaseFinished`.
- `GetSubscriptionProductInfoAsync`, `GetUserSubscriptionPaymentHistoryAsync`, `GetUserSubscriptionDetailsAsync`, `PromptCancelSubscription`.
- Subscription ids are strings, not numbers.

### Server code: status cache plus a daily stipend

The classic subscription benefit is a daily delivery ("500 gems a day while subscribed"). The delivery must be idempotent per day and must survive server hops.

```lua
--!strict
-- ServerScriptService/Services/SubscriptionService (ModuleScript)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService.Services.PlayerData)

local SUB_ID = "EXP-0000000000" -- from the Creator Dashboard
local DAILY_GEMS = 500

local active: { [Player]: boolean } = {}

local function utcDay(): number
	return os.time() // 86400
end

local function claimDaily(player: Player)
	if not active[player] then
		return
	end
	local profile = PlayerData.GetProfileAsync(player, 15)
	if not profile then
		return
	end
	local data = profile.Data
	local today = utcDay()
	if (data.SubLastClaimDay or -1) >= today then
		return -- already delivered today (any server)
	end
	data.SubLastClaimDay = today
	data.Gems += DAILY_GEMS
	-- Normal autosave is fine here: a crash loses at most today's stipend
	-- AND its marker together, so the player can claim again.
end

local function refresh(player: Player)
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, SUB_ID)
	end)
	if not ok then
		warn("[Subs] status check failed", status)
		return -- keep the previous value; do not revoke on an error
	end
	active[player] = status.IsSubscribed == true
	player:SetAttribute("Subscribed", active[player])
	claimDaily(player)
end

Players.PlayerAdded:Connect(refresh)
Players.UserSubscriptionStatusChanged:Connect(function(player: Player, subscriptionId: string)
	if subscriptionId == SUB_ID then
		refresh(player)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	active[player] = nil
end)

return {
	IsActive = function(player: Player): boolean
		return active[player] == true
	end,
	ClaimDaily = claimDaily, -- also call from a daily timer for long sessions
}
```

Design notes:
- **Do not revoke on a failed check.** An API hiccup should never take away something the player paid for this month.
- **Stipends are pull, not push.** Deliver on join and on the first check after midnight UTC; do not try to "catch up" missed days unless your copy promises it.
- **Durable-type benefits** (an aura, a title) should be visible state read from `IsActive`, not saved items, so they disappear cleanly when the subscription lapses. Anything *delivered* (gems) is kept.
- A daily delivery is a currency source; log it with `TimedReward` in economy analytics ([[Analytics and Funnels]]).

### When subscriptions make sense (rule of thumb)
- You have a daily loop that players already return to; the stipend rewards that return.
- Your benefit set is distinct from your passes. A subscription that duplicates VIP confuses players and splits buyers.
- You can keep delivering. If the game might be abandoned, a subscription is a promise you might break.
- Price it against your passes: players compare "R$ X per month" with "R$ Y forever".

---

## 2. Roblox Plus (the platform subscription)

### What changed
- **April 30, 2026:** Roblox Plus launched globally at $4.99 USD per month, with optional bundles that add monthly Robux (Announcement).
- **Premium** stopped accepting new sign-ups. Existing members keep their stipend and trading/selling rights and could opt into a free one-month Plus trial (Announcement).
- **May 30, 2026:** Premium's 10% bonus on Robux purchases and the Premium logo ended (Announcement).

### How Plus pays creators (Docs, Oct 2026)

| Payout | Amount | Conditions |
|---|---|---|
| Discounts | Subscribers pay 10% less (first two months), 20% less from the third consecutive month; **you still earn the full share** | Roblox subsidises it. Eligible: developer products, passes, developer subscriptions, paid access, avatar items. Excludes items above 1,000,000 Robux |
| Sign-up bonus | 250 Robux per month for each of a new subscriber's first three consecutive months (up to 750) | Only when they subscribe **through your game via `PromptRobloxSubscriptionPurchase`**; trials do not count; 60-day hold |
| Paid private servers | Up to 100 Robux per subscriber per month | Plus subscribers get paid private servers free; you earn 70% of your server price, capped at 100 Robux, if the owner spent 60+ cumulative minutes in it over 30 days and it is in their top five paid servers. Only the owner's time counts. Free trial subscribers count |
| Robux transfers | 10% of each transfer sent through your game | Sender must be a Plus subscriber; 10 to 500 Robux per transfer; DevEx-eligible for you |

Docs' discount example: a 100 Robux item earns the creator 70 Robux whether the buyer pays 100, 90 or 80.

**The discount breaks hard-coded prices.** A subscriber's price is lower than your label. The Plus page says to use `GetProductInfoAsync` and `GetDeveloperProductsAsync` for real-time prices. See [[Pricing and Store Design]].

### Plus APIs (Docs)
- `MarketplaceService:PromptRobloxSubscriptionPurchase(player)` shows the Plus prompt.
- `MarketplaceService.PromptRobloxSubscriptionPurchaseFinished` fires when it closes; its `didTryPurchasing` argument says the user attempted to subscribe (not that they did).
- `Player.HasRobloxSubscription` is the current status; listen with `GetPropertyChangedSignal("HasRobloxSubscription")`.
- `MarketplaceService:GetRobloxSubscriptionDetailsAsync(player)` returns `IsSubscribed`, `StartTime`, `IsOriginExperience` (whether they subscribed through this game).

The documented flow is: at the offer point, check `HasRobloxSubscription`; if already subscribed, give your in-game thank-you reward; otherwise prompt, and **grant only after the server sees `HasRobloxSubscription` change to true**, not on the prompt-finished event.

```lua
--!strict
-- Server: reward players who subscribe to Plus from this game (once per player).
local Players = game:GetService("Players")

local function watchPlus(player: Player)
	local function check()
		if player.HasRobloxSubscription then
			RewardService.GrantOnce(player, "PlusThanks") -- your own idempotent grant (profile flag)
		end
	end
	player:GetPropertyChangedSignal("HasRobloxSubscription"):Connect(check)
	check()
end
Players.PlayerAdded:Connect(watchPlus)
```

### How to prompt Plus without damaging your game
The bonus (up to 750 Robux per sign-up) is large compared to typical product prices, which creates an obvious temptation to spam the prompt. Press coverage criticised exactly this. Docs' own sample throttles the prompt and the old Premium guidance (still on the payouts page) is a sound standard:
- Describe benefits honestly; never promise Robux or rewards you do not control.
- Do not present the prompt as a paywall.
- Exclusive cosmetics for subscribers are fine; a tactical gameplay advantage is not.
- Prompt at a natural moment the player chose (a "Plus perks" button, a private server menu), not on join or mid-combat. Use the same pop-up gate as your other prompts ([[Pricing and Store Design]]).

---

## 3. Creator Rewards (what replaced Premium Payouts)

Docs (Oct 2026): Engagement-Based Payouts and the Creator Affiliate program are discontinued and replaced by Creator Rewards. Creators began earning on July 24, 2025.

| Component | Rate | Conditions |
|---|---|---|
| **Daily Engagement** | 5 Robux per qualifying user per day | User is an **Active Spender**; spends at least **10 minutes** in your game in a 24-hour period; your game is one of the **first three** they launch that day. No enrollment |
| **Audience Expansion** | 35% revenue share on the first $100 of the user's Qualifying Purchases during their first 60 days | For New and Reactivated users attributed to you. Requires an ID-verified creator account in good standing (for group games, a member who can configure group revenue). User plays 10+ minutes on the day they join or return; your game averages 100+ DAU for the following 60 days. Share links, direct links and name search have their own attribution rules |

**Active Spender** (Docs): a user with Qualifying Purchases (Robux, Premium or UGC subscriptions) of at least $9.99 USD in the past 60 days, who was not a New or Reactivated user in the past 60 days. Payouts are credited as Earned Robux with a **60-day hold**, and converting them requires the DevEx terms. Find them in Creator Dashboard, the game, Monetization, Creator Rewards; share link data in Analytics, Share Links. Roblox's announcement said payouts are not capped and the program may change.

### What this means for design
- **"First three experiences of the day"** rewards games players open *first*: daily login rewards, streaks, notifications that bring players in early, and a fast join ([[Retention and Return Hooks]]). Rule of thumb, not a documented strategy.
- **Ten minutes** is the bar. A game that bounces players in two minutes earns nothing from them. Fix first-play bounce rate ([[First-Time User Experience and Onboarding]]).
- **Audience Expansion** rewards bringing *new and lapsed* users, especially through share links. Invite and share features now pay directly ([[Community Building]]).
- Premium-only content no longer earns a payout. Do not build Premium gates for revenue.

---

## 4. Premium legacy APIs

You will find these in older games and tutorials:
- `player.MembershipType == Enum.MembershipType.Premium` still identifies legacy Premium members, but `Player.MembershipType` is **deprecated** (reference page since April 2026). Check the Roblox subscription with `player.HasRobloxSubscription`; keep the `MembershipType` read only for perks already promised to legacy Premium members.
- `Players.PlayerMembershipChanged` still exists (referenced on the payouts page).
- `MarketplaceService:PromptPremiumPurchase` is **marked deprecated** on the reference page (Oct 2026). With Premium closed to new sign-ups, replace Premium upsells with `PromptRobloxSubscriptionPurchase`.
- "Premium Playtime Score" and "Engagement Payouts" dashboards describe the deprecated program.

If your game gave Premium players perks, decide whether Plus subscribers get the same. Mapping "Premium or Plus" to one `IsMember` helper keeps the rule in one place.

---

## 5. Common mistakes
- Avoid: `PromptPremiumPurchase` or `MembershipType` checks in new code -> `PromptRobloxSubscriptionPurchase(player)` and `player.HasRobloxSubscription` (both older names deprecated, still work).
- Planning revenue around Premium playtime payouts (gone since July 2025).
- Granting a Plus thank-you reward on `PromptRobloxSubscriptionPurchaseFinished` (it only says they tried).
- Bronze/Silver/Gold experience subscriptions (not supported; all can be owned at once).
- Revoking subscription perks on a failed status check.
- Deleting an active subscription (full refunds, no revenue).
- Different benefits on mobile and desktop (against guidelines).
- Hard-coded prices that show Plus subscribers the wrong amount.

## 6. Checklist
- [ ] Subscription benefits distinct from passes; same on every platform
- [ ] Status cached server-side; `UserSubscriptionStatusChanged` handled
- [ ] Daily stipend idempotent per UTC day
- [ ] Plus prompt placed at a chosen moment, throttled, gated like other pop-ups
- [ ] Plus reward granted on `HasRobloxSubscription` change only
- [ ] Old `PromptPremiumPurchase` calls replaced
- [ ] Creator Rewards dashboard checked; first-session length above 10 minutes for most players

## See also
[[Monetization Overview]] · [[Game Passes]] · [[Developer Products and ProcessReceipt]] · [[Pricing and Store Design]] · [[Retention and Return Hooks]] · [[Analytics and Funnels]] · [[Community Building]]

## Connected notes
<!-- auto-links:start -->
[[Subscriptions and Recurring Revenue]] · Official Docs - Monetization · DevEx and Cashing Out · Skill - Roblox Monetization Compliance · Platform Features Start Here · Sponsored Ads and Campaign Math
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Discovery and Monetization Changes 2025-2026]] · [[Robux Price Points and Offer Design]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Discovery and the Algorithm]] · [[Publishing an Experience]] · [[Refunds Chargebacks and Purchase Support]] · [[Ads and Rewarded Video]] · [[Roblox Policies Ratings and Compliance]]
<!-- related:end -->
