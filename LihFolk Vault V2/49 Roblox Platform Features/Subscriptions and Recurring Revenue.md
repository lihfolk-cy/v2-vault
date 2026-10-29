---
tags: [platform-features, subscriptions, monetization, recurring-revenue, marketplaceservice, webhooks, retention, luau, strict]
---
# Subscriptions and Recurring Revenue

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Granting the monthly bundle on `IsSubscribed` -> Grant on a paid cycle from payment history
> - Avoid: Revoking perks during renewal processing -> Access follows `IsSubscribed`, which stays true in grace
> - Avoid: Granting on `PromptSubscriptionPurchaseFinished` -> Wait for status change or recheck later
> - Access gate (`IsSubscribed`) and delivery gate (paid cycle) are separate
> - Cycle grant keyed on `CycleStartTime`, saved with the profile
> - Refresh on join, on `UserSubscriptionStatusChanged` and every 15 minutes
>
> Cost: TL;DR ~170 tok · whole note ~5.7k tok. Read more: ## 1. The state machine · ## 2. Per-cycle grants instead of per-day guesses · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

[[Subscriptions and Premium Payouts]] covers what experience subscriptions are, how they pay, the platform rules, the basic status check and Roblox Plus. This note goes underneath: the subscription **state machine** and its grace period, granting benefits per **paid cycle** rather than per day, the arithmetic of churn and lifetime value, benefit design that does not trap you on a content treadmill, honest cancellation, webhooks, and the edge cases (refunds, lapses, region and platform eligibility, price changes, replacing a pass) that decide whether a subscription earns trust or support tickets.

Platform facts are labelled **Roblox docs (as of October 2026)** and were checked against the Subscriptions guide, the Subscription design guide, the MarketplaceService, PolicyService and enum references, and the Webhook notifications guide on create.roblox.com. Revenue arithmetic uses documented payout rules with **hypothetical** retention numbers; label them as such when you reuse them.

## 1. The state machine

`GetUserSubscriptionStatusAsync` gives two booleans, `IsSubscribed` and `IsRenewing`. That is enough for "show the perks", but not for "deliver this month's bundle". For that you need `MarketplaceService:GetUserSubscriptionDetailsAsync(player, subscriptionId)`, server-only, which returns (Roblox docs, as of October 2026):

| Field | Meaning |
|---|---|
| `SubscriptionState` | `Enum.SubscriptionState`: `NeverSubscribed`, `SubscribedWillRenew`, `SubscribedWillNotRenew`, `SubscribedRenewalPaymentPending`, `Expired` |
| `NextRenewTime` | `DateTime`; may be **in the past** while renewal payment is pending; `nil` if it will not renew, is expired, or never subscribed |
| `ExpireTime` | `DateTime`; `nil` unless cancelled |
| `ExpirationDetails` | Only when `Expired`: `ExpirationReason` from `Enum.SubscriptionExpirationReason`: `ProductInactive`, `ProductDeleted`, `SubscriberCancelled`, `SubscriberRefunded`, `Lapsed` |

And `MarketplaceService:GetUserSubscriptionPaymentHistoryAsync(player, subscriptionId)`, also server-only, returns up to **one year** of cycles, most recent first, each with `CycleStartTime`, `CycleEndTime` (both `DateTime`) and `PaymentStatus` (`Paid` or `Refunded`). Only creators affiliated with the subscription get the full year; others see only the current status (Roblox docs).

Drawn as transitions:

```
NeverSubscribed --purchase paid--> SubscribedWillRenew
SubscribedWillRenew --player cancels--> SubscribedWillNotRenew --cycle ends--> Expired (SubscriberCancelled)
SubscribedWillRenew --renewal due--> SubscribedRenewalPaymentPending --paid--> SubscribedWillRenew
SubscribedRenewalPaymentPending --payment fails--> Expired (Lapsed)
any active state --refund--> Expired (SubscriberRefunded)
any active state --you deactivate or delete--> Expired (ProductInactive / ProductDeleted)
Expired --buys again--> SubscribedWillRenew  ("Resurrected" in analytics)
```

### The grace period
Renewal payments take time to process. During that window (Roblox docs, as of October 2026):
- `GetUserSubscriptionStatusAsync` keeps returning `IsSubscribed = true` and `IsRenewing = true`, so the player keeps their experience.
- The payment history **does not contain** the new cycle until payment is processed.
- The docs say explicitly: **do not grant durable items or currency-type benefits until payment for the current cycle is confirmed.**

At the **first** purchase it is the other way round: `IsSubscribed` is `false` while the initial payment is processing or if it failed. The official sample rechecks 10 seconds after `PromptSubscriptionPurchaseFinished` reports `didTryPurchasing`, and `Players.UserSubscriptionStatusChanged` fires when status changes (Roblox docs). Never grant on the prompt event.

This gives a clean two-gate rule:

| Benefit kind | Gate |
|---|---|
| Access and status (VIP area, chat tag, cosmetic aura, x2 drop rate while subscribed) | `IsSubscribed` (keeps working during the grace period) |
| Deliveries (monthly bundle, currency, durable items) | A **paid** history entry whose cycle contains now |

## 2. Per-cycle grants instead of per-day guesses

A daily stipend keyed on "UTC day while `IsSubscribed`" (the pattern in the older note) is fine for small amounts. For anything valuable, key deliveries on the **paid cycle**: the `CycleStartTime` of the latest `Paid` entry is a natural idempotency key. One cycle, one bundle, regardless of how many servers the player visits.

```lua
--!strict
-- ServerScriptService/Services/SubscriptionLedger (ModuleScript)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

export type SubData = {
	lastCycleGranted: { [string]: number }, -- subscriptionId -> CycleStartTime (unix)
	lastDailyDay: { [string]: number }, -- subscriptionId -> UTC day of last daily grant
}

type Product = {
	id: string,
	onCycle: ((player: Player, data: SubData) -> ())?, -- monthly bundle
	onDaily: ((player: Player, data: SubData) -> ())?, -- small daily stipend
}

local PRODUCTS: { Product } = {
	{
		id = "EXP-0000000000",
		onCycle = function(player, data)
			-- grant the monthly bundle into your saved data here
		end,
		onDaily = function(player, data)
			-- grant the daily stipend here
		end,
	},
}

type Live = { data: SubData, access: { [string]: boolean }, paidUntil: { [string]: number } }
local live: { [Player]: Live } = {}

local function setAccess(player: Player, subId: string, on: boolean)
	local state = live[player]
	if state then
		state.access[subId] = on
		player:SetAttribute("Sub_" .. subId, on) -- clients read this for cosmetics and UI
	end
end

local function refreshOne(player: Player, product: Product)
	local state = live[player]
	if not state then
		return
	end

	-- Gate 1: access. Keeps perks through the renewal grace period.
	local okStatus, status = pcall(MarketplaceService.GetUserSubscriptionStatusAsync, MarketplaceService, player, product.id)
	if okStatus then
		setAccess(player, product.id, status.IsSubscribed == true)
	end
	-- On failure keep the previous access value: never revoke on an API error.

	-- Gate 2: deliveries. Only a paid cycle that contains now.
	local okHistory, history = pcall(MarketplaceService.GetUserSubscriptionPaymentHistoryAsync, MarketplaceService, player, product.id)
	if not okHistory or type(history) ~= "table" or #history == 0 then
		return
	end
	local latest = history[1]
	local now = os.time()
	local cycleStart = latest.CycleStartTime.UnixTimestamp
	local cycleEnd = latest.CycleEndTime.UnixTimestamp
	if latest.PaymentStatus ~= Enum.SubscriptionPaymentStatus.Paid or now < cycleStart or now >= cycleEnd then
		state.paidUntil[product.id] = 0
		return
	end
	state.paidUntil[product.id] = cycleEnd

	if product.onCycle and (state.data.lastCycleGranted[product.id] or 0) < cycleStart then
		state.data.lastCycleGranted[product.id] = cycleStart
		product.onCycle(player, state.data)
	end
	if product.onDaily then
		local today = now // 86400
		if (state.data.lastDailyDay[product.id] or -1) < today then
			state.data.lastDailyDay[product.id] = today
			product.onDaily(player, state.data)
		end
	end
end

local function refreshAll(player: Player)
	for _, product in PRODUCTS do
		task.spawn(refreshOne, player, product)
	end
end

local SubscriptionLedger = {}

function SubscriptionLedger.OnProfileLoaded(player: Player, data: SubData)
	live[player] = { data = data, access = {}, paidUntil = {} }
	refreshAll(player)
end

function SubscriptionLedger.HasAccess(player: Player, subId: string): boolean
	local state = live[player]
	return state ~= nil and state.access[subId] == true
end

Players.UserSubscriptionStatusChanged:Connect(function(player: Player, subscriptionId: string)
	for _, product in PRODUCTS do
		if product.id == subscriptionId then
			refreshOne(player, product)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	live[player] = nil
end)

-- Long sessions cross renewals and UTC midnight: re-check every 15 minutes.
task.spawn(function()
	while true do
		task.wait(15 * 60)
		for player in live do
			refreshAll(player)
		end
	end
end)

return SubscriptionLedger
```

Points worth defending in review:
- The **cycle grant writes its marker before calling the grant**, inside the same profile table, so both save together. A crash loses both and the next session grants again, which is correct. This depends on the profile being session-locked ([[Session Locking and Profile Libraries]]).
- The daily stipend is gated on a **paid** cycle, so a player in the grace period keeps their perks but does not collect stipends until payment clears. They collect today's stipend the moment it does (the 15-minute refresh or the status event catches it).
- Refunded cycles: the latest entry becomes `Refunded`, deliveries stop, and access ends when status flips. Things already delivered stay delivered unless your policy says otherwise; see section 7.

## 3. The arithmetic of recurring revenue

The payout rules (Roblox docs, as of October 2026, repeated here only as inputs): Robux-priced subscriptions pay **70%** every month; local-currency subscriptions pay **70% in the first month and 100% from the second month**, and the docs' example is a $5 subscription earning 350 Robux in month one and 500 per month after.

Let `r` be the monthly renewal rate (the share of subscribers who renew each month). With a constant rate, the expected number of paid months per subscriber is `1 / (1 - r)`. For the $5 local-currency example:

| Monthly renewal rate (hypothetical) | Expected paid months | Robux per subscriber (350 + 500 x (months - 1)) |
|---|---|---|
| 40% | 1.67 | 683 |
| 60% | 2.5 | 1,100 |
| 75% | 4.0 | 1,850 |
| 85% | 6.67 | 3,183 |

A Robux-priced subscription at 500 Robux pays 350 every month, so at 75% renewal it earns 350 x 4 = 1,400 per subscriber. The local-currency version earns more per subscriber the longer people stay, because months two onward pay 100%. Two conclusions follow:
1. **Month one is the expensive month.** Almost all the difference between a weak and a strong subscription is whether people renew the first time. Design the first renewal: the second month should deliver something the first did not.
2. **Compare against your passes honestly.** If your best pass nets 700 Robux once, a subscription with 40% renewal earns about the same per buyer, with ongoing delivery obligations. Below roughly 50% first-renewal, a pass or a developer product bundle is usually the better product (rule of thumb from the arithmetic above).

Hold periods also shape cash flow: local-currency earnings arrive after a **30-day** hold, once the full term is delivered, and refunds inside the hold cancel that payout; Robux-priced earnings follow the roughly 5-day hold of passes and products (Roblox docs). A launch month therefore shows less Robux than the subscription count suggests. Use the dashboard's projection, not your balance, to judge it.

What to track (the dashboard shows new, renewed, resurrected and cancellations; Roblox docs):
- **First renewal rate** of each monthly cohort.
- **Active subscribers / DAU**, to see whether growth comes from new players or deeper conversion.
- **Cancellations by reason**, from webhooks (section 6).
- **Resurrections** after content drops: proof that new content brings lapsed subscribers back.

## 4. Benefit design

The Subscription design guide frames success around **value** and **trust**, and lists bundles, memberships/VIP and season passes as the main shapes (Roblox docs). The traps are in the details.

### Durable items create a treadmill
Product types are Durable, Consumable or Currency; a bundle with any durable item must be marked Durable (Roblox docs). The guide warns that over-relying on durable items forces you into constantly designing new ones (Roblox docs). Each month's exclusive pet is a promise of next month's exclusive pet. Budget it: if a monthly durable item costs your team two days, that is 24 days a year owed to subscribers before you build anything else. A sustainable mix (rule of thumb): one modest durable cosmetic per cycle, the rest consumables, currency and access.

### Currency stipends and your economy
A subscription stipend is a faucet that never turns off. Size it against your economy ([[Economy Inflation Sinks and Faucets Math]]). The design guide's method is to convert the subscription's Robux value into your soft currency at the same rate as your existing currency packs, then check it against those packs (Roblox docs). Rule of thumb: a month of stipends should be worth more than the same Robux spent on a one-time pack (otherwise why subscribe), but not so much that subscribers trivialise progression for everyone they trade with.

### Orthogonal, not tiered
Players can own all of a game's subscriptions at once, and mutually exclusive tiers are not supported (Roblox docs; also in the older note). Design subscriptions as **add-ons that do different things**: a "Builder" subscription with extra plot space and a "Collector" subscription with a monthly pet, not "Silver" and "Gold" of the same perk. If two subscriptions share a perk, a player holding both must not get it twice; your access check should treat it as a set.

### Season pass premium tracks
A subscription that unlocks a premium track lets players who subscribe mid-season claim premium rewards they already earned (Roblox docs, design guide). That retroactive claim is a strong conversion moment: show "12 premium rewards waiting" to non-subscribers. See [[Battle Pass and Season Design]].

### Pricing and the price tiers
Local-currency prices come in fixed tiers. The Subscriptions guide lists $2.99, $4.99, $7.99, $9.99 and $14.99, while the Subscription design guide's currency example lists only four of them without $9.99 (both Roblox docs, as of October 2026); trust the product page in the dashboard. Robux prices start at 49 and can change **once every 60 days**, with price increases taking effect only after subscribers get at least 30 days' notice; local-currency subscriptions cannot be edited (delete and recreate). Payment method changes affect only new subscribers (Roblox docs). Price carefully at launch: you get few corrections.

## 5. Eligibility and display

Not every player can buy every subscription:
- Local-currency subscriptions are web, App Store and Google Play only, and unavailable in a list of countries (Roblox docs; the older note has the list).
- `PolicyService:GetPolicyInfoForPlayerAsync` returns `IsEligibleToPurchaseSubscription` (Roblox docs, as of October 2026).
- The guide warns that players in unsupported regions and platforms **can see the offering but cannot complete the purchase** (Roblox docs).

So: check eligibility on the server, send a flag to the client, and either hide the subscription or show it with an explanation. `GetSubscriptionProductInfoAsync` is **client-only** because it returns a localised `DisplayPrice` (unsupported countries get a string without a price), plus `DisplaySubscriptionPeriod`, `IsForSale`, `PriceTier` (for comparing products, not a price) and `PriceInRobux` (0 if not purchasable in Robux) (Roblox docs). Never hard-code "$4.99" in your UI; render `DisplayPrice .. DisplaySubscriptionPeriod`. Roblox Plus discounts also change what subscribers pay, which is another reason to read prices at runtime ([[Pricing and Store Design]]).

Rules from the guidelines that affect UI (summarised in the older note): same benefits on every platform, name and copy state price and duration, no extra tasks to unlock paid benefits.

## 6. Cancellation, webhooks and support

### Honest cancellation
`MarketplaceService:PromptCancelSubscription(player, subscriptionId)` prompts the player to cancel, and `UserSubscriptionStatusChanged` fires once they do (Roblox docs). A "Manage subscription" button that opens it costs you little and earns trust: players who know they can leave easily subscribe more readily (rule of thumb). Show what they keep (delivered items, progress) and when access ends (`ExpireTime` from the details call). Do not stack guilt screens in front of the prompt; that is exactly the kind of manipulation the platform's ethics guidance targets ([[Ethical Design and Player Trust]]).

### Webhooks
The Webhook notifications guide lists subscription triggers for **purchased, renewed, resubscribed, cancelled** (with the reason given) and **refunded**; the Subscriptions guide still says "four events" without resubscribed (both Roblox docs, as of October 2026). Delivery facts that matter for a backend (Roblox docs):
- Your endpoint must accept HTTPS POST and answer **2XX within 5 seconds**.
- Failed deliveries are retried **5 times**, then Roblox treats the URL as invalid until you update it.
- Every payload has `NotificationId` (deduplicate on it), `EventType`, `EventTime` and an `EventPayload`.
- With a secret configured, a `roblox-signature` header carries `t=<timestamp>,v1=<signature>`, an HMAC-SHA256 (base64) you verify with your secret; the docs suggest rejecting stale timestamps to prevent replay (their sample uses a 300-second window).

Use webhooks for analytics and support (cancellation reasons, refund alerts), not for in-game entitlement. The game should always decide access from the in-engine APIs, which work even if your backend is down. An Open Cloud endpoint to read a subscription also exists (rate limited to 500 requests per minute per API key owner in the reference), useful for a support tool that looks up a player's status.

### Support questions you will get
- "I paid but have no perks": usually the initial payment is still processing (`IsSubscribed` false). Ask them to rejoin after a few minutes; your refresh on `UserSubscriptionStatusChanged` should catch it live.
- "I cancelled and lost my stuff": explain the access/delivery split in your UI up front.
- "I want a refund": the docs say cancelled or lapsed subscribers do not get automatic refunds and must request them; refunds are case by case. Subscriptions bought with Robux are not eligible for refunds. For local-currency subscriptions, a refund after the hold window is deducted from your balance, and for a group-owned game any shortfall comes out of the group owner's balance (all Roblox docs, as of October 2026). Point players to Roblox support; you cannot refund from your game. See [[Refunds Chargebacks and Purchase Support]].

## 7. Lapses, refunds and what to take back

When a subscription ends, decide per benefit what happens. A defensible policy (rule of thumb):

| Benefit | On cancel or lapse | On refund |
|---|---|---|
| Access perks (zones, multipliers, tags) | End with access | End with access |
| Cosmetics granted as "while subscribed" | Go dormant (kept, unusable) and return on resubscribe | Same |
| Delivered currency and consumables | Kept | Kept, unless clearly abused (many refunds); handle case by case |
| Delivered durable items | Kept | Consider removing the item from the refunded cycle |
| Progress made while subscribed | Always kept | Always kept |

Two rules make this safe: **never wipe progress**, and **make the policy visible before purchase**. The official pass-replacement sample includes a `revokeAwardIfGranted` hook for exactly this decision (Roblox docs). Dormant cosmetics are also a resurrection lever: "Your 4 VIP auras are waiting" on the subscription panel.

## 8. Replacing a pass with a subscription

The Subscriptions guide covers this case (Roblox docs): existing pass holders keep their benefit forever, the pass goes off sale, and code checks the pass first and the subscription second. Practical additions (rule of thumb):
- Tell pass holders loudly that nothing changes for them; they are your most vocal players.
- Give the subscription something the pass never had, or it reads as a price increase disguised as a subscription.
- Keep the pass id in config forever. Deleting the check is how lifetime buyers lose their perk two years later.

## 9. Testing
Test the state machine, not just the happy path. Useful cases: first purchase with delayed payment (access false, then true via the event), renewal in grace (access true, no stipend), cancellation (`SubscribedWillNotRenew`, perks until `ExpireTime`), refund (`Expired`, `SubscriberRefunded`), and you taking the product off sale. How purchases behave in Studio test sessions was not documented on the pages checked for this note; verify in a published test experience before launch ([[Multi-Client and Live Testing]]).

## 10. Common mistakes

| Mistake | Fix |
|---|---|
| Granting the monthly bundle on `IsSubscribed` | Grant on a paid cycle from payment history |
| Revoking perks during renewal processing | Access follows `IsSubscribed`, which stays true in grace |
| Granting on `PromptSubscriptionPurchaseFinished` | Wait for status change or recheck later |
| Hard-coded local prices | `GetSubscriptionProductInfoAsync` on the client |
| Showing subscriptions to ineligible players with no explanation | `IsEligibleToPurchaseSubscription` gate |
| Monthly durable items with no content plan | Mostly consumables and access; budget the durable item |
| Silver and Gold tiers | Orthogonal add-ons |
| Entitlement driven by your webhook backend | In-engine APIs decide; webhooks feed analytics |

## 11. Checklist
- [ ] Access gate (`IsSubscribed`) and delivery gate (paid cycle) are separate
- [ ] Cycle grant keyed on `CycleStartTime`, saved with the profile
- [ ] Refresh on join, on `UserSubscriptionStatusChanged` and every 15 minutes
- [ ] First-renewal rate tracked per cohort; month two has new value
- [ ] Stipend sized against the economy and existing currency packs
- [ ] Eligibility checked; prices rendered from product info
- [ ] Manage-subscription button using `PromptCancelSubscription`
- [ ] Webhooks verified, deduplicated on `NotificationId`, used for analytics
- [ ] Lapse and refund policy written and shown before purchase

## See also
[[Platform Features Start Here]] · [[Subscriptions and Premium Payouts]] · [[Monetization Overview]] · [[Game Passes]] · [[Battle Pass and Season Design]] · [[Economy Inflation Sinks and Faucets Math]] · [[Purchase Data and Receipts]] · [[Refunds Chargebacks and Purchase Support]] · [[Links - Subscriptions and payouts]]

## Connected notes
<!-- auto-links:start -->
[[Commerce and Physical Goods]] · [[Robux Price Points and Offer Design]] · [[Skill - Roblox Monetization Compliance]] · [[DevEx and Cashing Out]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Working with Contractors and Revenue Splits]]
<!-- auto-links:end -->
