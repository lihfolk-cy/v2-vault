---
tags: [live-ops, monetization, offers, ethics, dark-patterns, pricing, luau]
---
# Limited-Time Offers - Design and Ethics

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Countdown from the client clock or GUI open time -> Server-stored `endsAt`, shown with server time
> - Avoid: Personal timer started on join for every offer -> Start on first actual view
> - Avoid: Profile save failed, timer re-armed -> Reliable saving; check in QA
> - Every time limit is literally true; every "never returns" claim is a promise you will keep
> - End times stored on the server; personal timers fixed on first view; never re-armed
> - Client countdowns use server time and never restart themselves
>
> Cost: TL;DR ~170 tok · whole note ~4.6k tok. Read more: ## 3. Kinds of LTO and their specific traps · ## 4. Building timers that cannot lie · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

A limited-time offer (LTO) is anything sold with a time or quantity limit: a holiday bundle, a weekly rotating item, a starter pack that disappears after three days, a flash discount. LTOs work because scarcity is real information ("this will not be sold again") and because events give players a reason to buy now. They are also the single easiest place in a Roblox game to cross from good design into manipulation of children, and Roblox's own monetization guidance draws specific lines around them.

[[Robux Price Points and Offer Design]] covers price ladders, offer types and an offer engine; [[Ethical Design and Player Trust]] covers dark patterns across the whole game. This note is narrower and deeper: what makes a time limit honest, the exact rules Roblox states, how to build timers and discounts that cannot lie by accident, how to measure LTOs without fooling yourself, and when not to use them.

Source labels: **Roblox docs (as of October 2026)**, mainly the Creator Hub "Monetization" overview; **rule of thumb**; **measured in the reference project**. Consumer-law context is general background, not legal advice.

## 1. What Roblox says, paraphrased

The Creator Hub monetization overview (Roblox docs, as of October 2026) treats limited availability as a legitimate social feature: items and events available only for a limited time create excitement. It then sets out what is not acceptable. In paraphrase:

- **Do not claim scarcity that is not true.** Saying an item or subscription is almost sold out, or only available briefly, when it is not, is misleading.
- **Countdown timers must be accurate**, and must not restart automatically for the same item.
- **A discount is unfair if it is offered only for a very short time** in order to pressure a fast purchase.
- **A discount is not genuine if the item is always "on sale"** at the same price.
- More generally, players must never be misled, confused or pressured into purchases they did not intend.
- Timers and appointment mechanics in general are described as unpopular with Roblox players, and players may downvote a game whose monetization they dislike.
- If Robux buys a random reward, `PolicyService` must be used to block it for players who cannot access paid random items, and chance-based monetization must be transparent ([[Paid Random Items and Odds Disclosure in Practice]]).

These are stated as guidance on the docs page; how strictly each is enforced is not spelled out there. Treat them as the floor, not the ceiling. The audience is young, and practices that are legal elsewhere can still get a game reported, downvoted, or reviewed.

### Consumer-law background

Several jurisdictions regulate the same patterns for all sellers. As general context (not legal advice; check for your own situation): EU rules require a price-reduction claim to show the lowest price applied in a prior period (typically 30 days), and regulators in the EU, UK and US have published guidance against fake countdowns and false scarcity under unfair-practice laws. A Roblox developer selling to a global audience is safest following the strictest common rule: **a time limit or discount claim must be literally true and verifiable from your own records.**

## 2. What makes a limit honest

A limit is honest when three things hold:

1. **It is true.** The item really stops being sold at the stated time, or the stated quantity really runs out.
2. **It is stable.** The time shown is the same for this player every time they look, and it does not reset for the same item.
3. **It is not the main reason to buy.** The player would want the item anyway; the limit tells them when, not whether.

Test each LTO against these questions (rule of thumb):

| Question | Honest answer | Red flag |
|---|---|---|
| What happens at the end of the timer? | The item leaves the store for a stated reason (event ended, season rotated) | Nothing; a new identical timer starts |
| Will it come back? | "Never" is promised only if you are certain; otherwise "rotates back later" | "Never again!" for an item that returns in a month |
| What is the discount relative to? | A price charged for a real, meaningful period before | A reference price nobody ever paid |
| Who sees the timer? | Everyone sees the same end time, or each player's own timer is fixed once shown | Each visit or rejoin shows a fresh 10-minute timer |
| How long is the window? | Days, matching an event or rotation | Minutes, timed to a moment of frustration |
| Does the UI pressure? | Calm countdown in the shop | Flashing red timer, popup on death, "only 3 left!" without a real stock |

## 3. Kinds of LTO and their specific traps

### Event bundles

Sold for the duration of an event, retired after. The honest version is easy: the end time is the event's end time from the calendar ([[Event Calendars and Content Planning]]), and the item is marked as event-exclusive only if it truly will not return. The trap is the rerun: next year you want the winter event back, and the bundle with it. Decide at creation whether the bundle is "exclusive" (never returns) or "seasonal" (may return with the event), and label it that way.

### Rotating shops

A weekly or daily rotation shows a subset of a catalogue, with a countdown to the next rotation. This is the most common Roblox LTO, and usually honest because the rotation is deterministic and everyone sees the same items. One production game ran a weekly exclusive shop: one product per week, a countdown on the card, and the server refused off-week products (measured in the reference project; the schedule logic is in [[Live Ops Events and Updates]]). The trap: calling rotated items "limited" or "exclusive" when they return every few weeks. Call them "this week's item" instead.

### Starter packs and first-purchase offers

A cheap, high-value bundle for new players, often shown for the first few days. Value-wise these are often the best deal in a game, and that is fine. The traps:

- **Showing it in the first minutes**, before the player knows whether they like the game. Wait until the player has finished onboarding or played a few sessions ([[First-Time User Experience and Onboarding]]).
- **A personal timer that restarts.** If the pack lasts 72 hours from first sight, record first sight once in the profile and never re-arm it.
- **Re-offering the "one-time" pack** under a new name a week later.

### Flash discounts

A discount for a short window. These are where Roblox's "very short time" guidance bites. A weekend sale tied to an event is fine. A 15-minute discount that appears right after the player loses a fight is the textbook pattern the guidance describes. Rule of thumb: no discount window shorter than 24 hours, never triggered by a failure moment, and the reference price must have been the actual price for at least the preceding 30 days.

### Returning-player offers

An offer for players who come back after an absence. Can be generous and kind ("welcome back, here is a bundle"). The trap is notifications: experience notifications must be personalised to the player's own activity and must not be disguised ads or use false time pressure (Roblox docs, as of October 2026; see [[Live Ops Events and Updates]]). "Your 50 percent offer expires in 1 hour!" as a push notification breaks both rules.

### Quantity-limited items

"Only 500 will ever be sold." Real stock limits are hard to implement correctly across servers (you need an atomic global counter) and easy to fake. If you do one, the counter must be server-authoritative, global and visible, and the number must be the real remaining stock, not a display that never goes below 3. See section 5.

## 4. Building timers that cannot lie

Most dishonest timers in Roblox games are not malicious; they are bugs. A countdown computed from the client clock, from server start, or from "time since this GUI opened" resets on rejoin, differs between devices, and looks exactly like a manipulative restarting timer. The fix is structural: every offer end time is a server fact, stored once.

```lua
--!strict
-- ServerScriptService/Shop/OfferService (ModuleScript)
-- Per-player and global offers whose end times are fixed and never re-armed.
local MarketplaceService = game:GetService("MarketplaceService")

export type OfferDef = {
	id: string, -- permanent; never reuse for a different offer
	productId: number,
	scope: "global" | "personal",
	-- global offers: fixed UTC window
	startsAt: number?,
	endsAt: number?,
	-- personal offers: duration from first sight, shown at most once ever
	durationSeconds: number?,
	referencePrice: number?, -- the real, prior price used for any "was" display
}

export type OfferView = { id: string, productId: number, endsAt: number, referencePrice: number? }

local OfferService = {}

-- data.Offers[id] = { firstSeenAt = number, endsAt = number, bought = boolean }
local function record(data: any, id: string): any
	data.Offers = data.Offers or {}
	return data.Offers[id]
end

-- Returns the view if the offer is visible to this player now, else nil.
-- Calling it does not extend anything: a personal timer is fixed on first call.
function OfferService.view(data: any, def: OfferDef, now: number): OfferView?
	if def.scope == "global" then
		local s, e = def.startsAt, def.endsAt
		if not s or not e or now < s or now >= e then
			return nil
		end
		return { id = def.id, productId = def.productId, endsAt = e, referencePrice = def.referencePrice }
	end
	local duration = def.durationSeconds
	if not duration then
		return nil
	end
	local r = record(data, def.id)
	if not r then
		-- First sight: fix the end time now and save it with the profile.
		r = { firstSeenAt = now, endsAt = now + duration, bought = false }
		data.Offers[def.id] = r
	end
	if r.bought or now >= r.endsAt then
		return nil -- expired or used: never re-armed
	end
	return { id = def.id, productId = def.productId, endsAt = r.endsAt, referencePrice = def.referencePrice }
end

-- Prompt only for offers the server currently considers visible.
function OfferService.prompt(player: Player, data: any, def: OfferDef, now: number): boolean
	if not OfferService.view(data, def, now) then
		return false
	end
	MarketplaceService:PromptProductPurchase(player, def.productId)
	return true
end

-- Called from ProcessReceipt. A receipt is always honoured, even if the window
-- closed while the prompt was open: the player saw a valid offer and paid.
function OfferService.markBought(data: any, def: OfferDef, now: number)
	if def.scope == "personal" then
		local r = record(data, def.id)
		if not r then
			r = { firstSeenAt = now, endsAt = now, bought = true }
			data.Offers[def.id] = r
		end
		r.bought = true
	end
end

return OfferService
```

Points that matter:

- **First sight is recorded only when the offer is actually shown.** Call `view` when rendering the shop the player opened, not on join for every offer in the catalogue, or every personal timer starts silently before the player ever sees it.
- **The record is saved with the profile.** If the profile fails to save, a rejoin would show a fresh timer. Profile saving correctness ([[Saving Correctly - Autosave and BindToClose]]) is part of LTO honesty.
- **Global windows come from the calendar config**, the same values the event uses, so the offer cannot outlive or underlive its event.
- **Receipts are honoured after expiry.** Refusing a receipt because the timer ran out while the purchase dialog was open charges the player for nothing. Return `PurchaseGranted` after granting ([[Developer Products and ProcessReceipt]]).
- **Client countdowns** use the `endsAt` the server sent and `workspace:GetServerTimeNow()`. When the countdown hits zero, the client hides the offer and asks the server for a fresh view; it never starts a new countdown itself.

### Showing a discount truthfully

A "was 400, now 250" display needs `referencePrice` to be a price you actually charged. Keep a price history (a simple dated list in your design docs or config history is enough: experience config history records every change with time and author). Rules of thumb:

- The reference price must have been the live price for at least 30 days before the sale.
- An item cannot be "on sale" most of the time. If a bundle has been discounted for three of the last four weeks, the discount price is the real price.
- With **managed pricing** (regional pricing and price optimisation), the price a player sees may differ by region or experiment arm. Read live prices with `MarketplaceService:GetProductInfo` rather than hard-coding Robux numbers; the developer products doc says scripts showing prices under price optimisation should run on the client so players see their personalised price. A hard-coded "was 400" next to a regionally priced current price can show a fake discount, or a negative one. Safest: show the discount as a percentage computed from the same source, or do not show a "was" price at all for regionally priced products ([[Pricing and Store Design]]).

## 5. Quantity limits done properly

A real "500 total" limit needs a global, atomic counter and a reservation that survives purchase latency:

1. Before prompting, reserve one unit: `UpdateAsync` on a stock key that decrements only if above zero, writing the player's reservation with a short expiry. A [[MemoryStore Service]] sorted map or hash map with expiry is a good fit for reservations; the durable sold count belongs in a data store.
2. Prompt the purchase.
3. On receipt, convert the reservation to a sale. On prompt close without purchase (`PromptProductPurchaseFinished` with `isPurchased` false), release it; expired reservations release themselves.
4. Display remaining stock from the durable count, refreshed every minute or so, and say "about" if it can lag.

This is real engineering with failure modes (oversell when a receipt arrives after its reservation expired; you must still honour it). If you are not willing to build it, do not claim a quantity limit. A time limit is far easier to make honest.

## 6. Measuring LTOs without fooling yourself

LTOs almost always "work" on the day they run: revenue spikes. The question is what they did to the following weeks.

- **Pull-forward.** A weekend sale may move purchases that would have happened next week. Compare revenue over the sale plus the two following weeks against a baseline, not the sale days alone.
- **Training.** Frequent sales teach players to wait for sales. Watch full-price conversion over months.
- **Guardrail metrics.** Refund requests, support tickets about purchases, dislikes after the event, and D7 retention of players who saw the offer vs did not ([[Refunds Chargebacks and Purchase Support]], [[Analytics and Funnels]]).
- **Who bought.** If a large share of LTO revenue comes from a small number of very high spenders, look at whether the design is pressuring them. A healthy LTO has a broad base of buyers.
- **Experiments.** Test offer content, placement and value with [[A-B Testing and Experiments on Roblox]], but do not test timer lengths that are shorter than your ethical floor. "Does a 10-minute timer convert better than a 3-day one?" is a question you should not need answered.

## 7. When not to use an LTO

- **On anything that affects power in PvP.** A time-limited stat item creates a permanent gap between players who happened to be online and buying that week. Keep LTOs to cosmetics, convenience and value bundles.
- **On paid random items.** Time pressure plus randomness plus a young audience is the combination regulators focus on. If you must run a limited crate, disclose odds, gate with `PolicyService`, and keep the window long.
- **In the first sessions.** New players have no basis for judging value.
- **As a fix for a weak economy.** If revenue depends on a constant stream of LTOs, the base store has a value problem ([[Robux Price Points and Offer Design]]).
- **When you cannot keep the promise.** If the team might rerun it, do not call it exclusive.

## 8. Common mistakes

| Mistake | How players experience it | Fix |
|---|---|---|
| Countdown from the client clock or GUI open time | Timer resets on rejoin; looks like a fake | Server-stored `endsAt`, shown with server time |
| Personal timer started on join for every offer | "My offer expired before I saw it" | Start on first actual view |
| Profile save failed, timer re-armed | Same offer with a fresh timer | Reliable saving; check in QA |
| "Was" price never charged | Fake discount | Reference price with real history |
| Exclusive item rerun | Trust loss, reports | Label honestly from creation |
| Discount popup on failure | Pressure at a vulnerable moment | Offers only in the shop or at neutral moments |
| Receipt refused after expiry | Charged for nothing | Always honour receipts |
| "Only 3 left!" with no real stock | False scarcity | Real atomic stock or no claim |

## 9. Checklist

- [ ] Every time limit is literally true; every "never returns" claim is a promise you will keep
- [ ] End times stored on the server; personal timers fixed on first view; never re-armed
- [ ] Client countdowns use server time and never restart themselves
- [ ] Discount windows at least 24 hours; reference price real for 30 days
- [ ] Prices read from the platform under managed pricing; no hard-coded "was" prices for regional products
- [ ] No LTO triggered by failure or frustration moments
- [ ] No time-limited power items in competitive modes
- [ ] Paid random items: odds shown, `PolicyService` gating, long windows
- [ ] Receipts always honoured, including after expiry
- [ ] Measured over the sale plus two weeks, with refund and retention guardrails

## See also
[[Live Ops Deep Dive Start Here]] · [[Robux Price Points and Offer Design]] · [[Ethical Design and Player Trust]] · [[Pricing and Store Design]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Battle Pass and Season Design]] · [[Event Calendars and Content Planning]] · [[Shop with Game Passes and Developer Products End to End]] · [[Roblox Policies Ratings and Compliance]] · [[Developer Products and ProcessReceipt]]

## Connected notes
<!-- auto-links:start -->
[[Monetization Overview]] · [[Skill - Roblox Monetization Compliance]] · [[Commerce and Physical Goods]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[Subscriptions and Premium Payouts]] · [[Purchase Data and Receipts]]
<!-- auto-links:end -->
