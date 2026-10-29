---
tags: [ugc, marketplace, pricing, limiteds, monetization, economy, policy, type/guide, area/avatars, level/intermediate, api/PromptPurchaseFinished, area/monetization]
---
# UGC Pricing Limiteds and Marketplace Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Pricing at the floor by default -> Start at 1.5x to 2x
> - Avoid: No Do Not Price Below -> Set a minimum
> - Avoid: Enabling resale casually -> Decide before publishing
> - Price set as floor offset plus a Do Not Price Below minimum.
> - Revenue-share tier chosen deliberately (1.5x to 2x for unknown items).
> - Advance break-even sales count written down and believable.
>
> Cost: TL;DR ~140 tok · whole note ~4.4k tok. Read more: ## 4. Limiteds: when they are the right product · ## 5. Selling UGC inside your experience · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[UGC Avatar Items and Accessories]] records the fee schedule: upload fees, publishing advances by item type, the revenue-share curve, Limited splits and publishing limits. This note is about using those numbers: how price-floor pricing really works, the arithmetic of advances and rebates, when a Limited is the right product and when it is a trap, what the irreversible switches are, how a game developer should sell UGC inside an experience, and the policy lines that cost creators their items. Numbers repeated from the older note are there only where a calculation needs them.

Everything here is **time-sensitive**. Facts are **Roblox docs (as of October 2026)** unless marked otherwise; re-read the Creator Hub fees and publishing pages on the day you publish. Worked examples use hypothetical price floors because the real floors are shown per item type in the Creator Dashboard, not in the docs.

## 1. How a price is set now

Avatar item prices are relative to a **dynamic price floor** per asset type. When publishing you set (docs):

| Field | Meaning |
|---|---|
| Amount Above Price Floor (required) | Robux above the current floor. Floor 50 plus 5 above = 55. Zero means "always at the floor" |
| Do Not Price Below (optional) | Your hard minimum. It "will always be respected": a 200 minimum stays 200 even if the floor falls |
| Regional Pricing | On by default; Roblox derives regional prices from your global price using purchasing power, exchange rates and local spending. You can opt out |

Your price must also sit inside a dynamic price range for the type (docs; the range values are not published on the page).

The subtle part: **because the price is "floor plus offset", your price moves when the floor moves.** A creator who set "0 above floor" in a month with a low floor and then sees the floor rise has had a price increase they did not choose. Conversely a floor drop drags you down, unless you set Do Not Price Below.

| Strategy | Settings | Behaviour |
|---|---|---|
| Track the floor | Offset 0 or small, no minimum | Always cheapest in category; revenue share stays at the bottom tier |
| Premium positioning | Offset large, minimum set | Stable perceived price; better share per sale |
| Price anchor for a collection | Same offset across a set, same minimum | Items in a set keep the same relationship as floors move |

Legacy items listed before dynamic pricing default to 0 above floor with Do Not Price Below set to their old price (docs). If you own older items, check them: many are now pinned at their historical price by that minimum.

## 2. The revenue-share curve, worked

For Marketplace purchases, the creator share rises with the price relative to the floor (from the older note's docs table): 30 percent at the floor, 37 at 1.3x, 41 at 1.5x, 50 at 2x, 57 at 2.5x, 62 at 3x, 65 at 3.5x, 67 at 4x, 69 at 5x, and 70 at 6x and above.

Worked example with a hypothetical floor of 100 Robux:

| Price | Multiple | Share | Creator Robux per sale | Sales needed to earn 10,000 |
|---|---|---|---|---|
| 100 | 1.0x | 30% | 30 | 334 |
| 150 | 1.5x | 41% | 61.5 | 163 |
| 200 | 2.0x | 50% | 100 | 100 |
| 300 | 3.0x | 62% | 186 | 54 |
| 600 | 6.0x | 70% | 420 | 24 |

Doubling the price from 100 to 200 more than triples creator Robux per sale. You only lose by doubling if doubling cuts sales by **more than 70 percent**. For most items with any brand pull, it does not. This is the strongest number in UGC pricing: the floor tier is the worst place to be unless you are chasing volume for ranking.

Two caveats:

- **The curve applies to Marketplace purchases.** In-experience purchases use the fixed split (30 percent creator, 40 percent experience owner, 30 percent Roblox, per the older note). The table above does not apply there.
- **Earnings sit in a 30-day escrow** (older note). Plan cash flow; a launch weekend pays a month later.

Rule of thumb: price unknown items at 1.5x to 2x the floor; drop to 1.3x only if conversion data says so; go to 3x and above for items with real demand (collaborations, a known creator, a set that completes a popular look).

## 3. Advances and how fast they come back

Publishing charges an **advance** by item type (for example 1,500 for a non-limited hat, 600 for most layered clothing, 13,000 for a paid-limited hat; older note). Rebates repay it out of the platform's commission on your sales. The docs' example: a 1,000 Robux advance is fully rebated after 9 sales at 400 Robux, which works out to rebates of about 30 percent of each sale price.

Break-even sales for the advance, using that 30 percent rate:

| Item | Advance | Price | Rebate per sale | Sales to repay |
|---|---|---|---|---|
| Layered jacket, non-limited | 600 | 150 | 45 | 14 |
| Hat, non-limited | 1,500 | 100 | 30 | 50 |
| Hat, non-limited | 1,500 | 200 | 60 | 25 |
| Hat, paid limited | 13,000 | 300 | 90 | 145 |
| Body, paid limited | 20,000 | 500 | 150 | 134 |

Read it this way: the advance is a bet that the item sells at least that many units. Most UGC items sell very few copies (rule of thumb: the median item sells a handful). A cheap non-limited jacket is a small bet; a paid-limited hat is a large one. The upload fee (80 Robux, 500 with emissive) is never refunded, so it is pure cost.

Repeat costs to plan for:

- Every **update** to a published item charges the upload fee again and goes through moderation (older note).
- Taking an item **off sale and back on** does not charge the advance again (docs).
- Only the **first** time an asset goes on sale counts against publishing limits (docs).

## 4. Limiteds: when they are the right product

| Feature | Non-Limited | Limited (docs) |
|---|---|---|
| Copies | Unlimited | Fixed quantity; paid Limiteds max 3,000; free Limiteds no maximum |
| Per-user cap | None | Optional, from the original listing only |
| Free option | No | Yes, with a per-unit fee instead of an advance |
| Resale | No | Optional "Resellable" switch |
| Restock | n/a | Free Limiteds can be restocked; enabling resale permanently disables restocking |

### The irreversible switches

These are the decisions that cannot be undone, so make them on paper first:

1. **Resellable.** You can turn it on after publishing, but once enabled it **cannot be disabled**, and enabling it **permanently disables restocking** (docs). It is also not available for accounts based in Japan (docs).
2. **Limited versus non-limited.** Re-publishing an existing item as a Limited is treated as overly similar to the original under the Marketplace policy (older note). Decide at the start.
3. **Per-user limit.** The publishing page is inconsistent: one place says you can only increase it after publishing, a callout says you cannot change it after publishing (docs, as of October 2026). Treat it as fixed.

### Limited economics

- **Primary sale split** is 30 percent creator, 40 percent seller or affiliate, 30 percent Roblox; on **resale** the original creator gets 10 percent (older note).
- A resellable Limited turns your item into a tradable asset whose secondary price you do not control. If supply is too large, the resale price collapses below your primary price and nobody buys from you again. If supply is tiny, early buyers profit and later players resent it.
- Rule of thumb for supply: set quantity below the number of people you can realistically reach in launch week, so it sells out, and accept that the resale market will set the "real" price after that.
- **Per-user limits** protect against one buyer cornering supply, but only on the original listing; resellers can still accumulate (docs). Limits are based on current ownership, so selling a copy lets the user buy again (docs).

### Free Limiteds

Free Limiteds pay a per-unit fee instead of an advance (the docs' example is 100 Robux per unit, market-based), with a 50-per-day publishing limit (docs). They are mostly used as experience rewards and promotions. Failure modes:

- **Bot farming.** Anything free and scarce attracts automated accounts. Platform purchase limits help (9 purchases per minute per user, 3 per user per item, and 60 seconds in the experience before an in-game Limited purchase, per the older note), but design your reward gate too: real play time, not just "join and click".
- **Engagement-bait rewards.** Requiring players to do arbitrary things purely to farm a free item can conflict with Marketplace and experience guidelines. The exact rules for free UGC rewards were **not confirmed** for this note; read the current Marketplace policy and experience guidelines before running a free-Limited event.
- **Cost scales with success.** A per-unit fee means a viral reward costs you per copy. Cap quantity.

## 5. Selling UGC inside your experience

For game developers, avatar items are a revenue line with no development cost if you sell other creators' items, and a big one if you make your own.

| Model | Earnings | Notes |
|---|---|---|
| Sell any catalog item in your shop | 40 percent of each in-experience purchase (older note) | `MarketplaceService:PromptPurchase`; try-on first ([[AvatarEditorService and In-Game Avatar Editors]]) |
| Sell your own items | Creator share plus experience share | The same owner gets both splits |
| Experience-exclusive items | As above | Sale location "Experience By Place ID" (API only): only original stock, only in linked games; the game owner must enable the item after setting the place id (docs) |
| Timed options (rentals) | Rental price | Some items offer 3, 7 or 14-day ownership at lower prices (reported January 2026 rollout; docs examples show durations in seconds and prices; check live status) |

### A purchase flow that does not lie

`PromptPurchaseFinished` tells you the dialog closed and whether the player clicked buy; it is not a receipt. Grant anything game-side (a badge, a matching in-game effect) only after the server confirms ownership, and retry because ownership can lag the purchase by a few seconds (rule of thumb).

```lua
--!strict
-- Server: confirm a Marketplace avatar item purchase before granting a game-side bonus.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local BONUS_ITEMS: { [number]: string } = {
	-- [assetId] = bonus key; ids are placeholders
	[0000000000] = "GoldTrail",
}

local function ownsWithRetry(player: Player, assetId: number): boolean
	for attempt = 1, 4 do
		local ok, owns = pcall(function()
			return MarketplaceService:PlayerOwnsAssetAsync(player, assetId)
		end)
		if ok and owns then
			return true
		end
		task.wait(attempt) -- 1, 2, 3 s backoff
		if player.Parent == nil then
			return false
		end
	end
	return false
end

MarketplaceService.PromptPurchaseFinished:Connect(function(player: Player, assetId: number, isPurchased: boolean)
	local bonus = BONUS_ITEMS[assetId]
	if not bonus or not isPurchased then
		return
	end
	if ownsWithRetry(player, assetId) then
		player:SetAttribute("Bonus_" .. bonus, true) -- replace with your profile grant
	end
end)

-- Re-check on join: purchases made on the website or while offline also count.
Players.PlayerAdded:Connect(function(player)
	for assetId, bonus in BONUS_ITEMS do
		task.spawn(function()
			local ok, owns = pcall(function()
				return MarketplaceService:PlayerOwnsAssetAsync(player, assetId)
			end)
			if ok and owns then
				player:SetAttribute("Bonus_" .. bonus, true)
			end
		end)
	end
end)
```

Note on naming: `MarketplaceService:PlayerOwnsAsset` is deprecated in the current reference and superseded by `PlayerOwnsAssetAsync` with the same arguments; bundles have `PlayerOwnsBundleAsync` (docs, as of October 2026). `PromptPurchaseFinished` does not fire for developer product or pass prompts (docs), so it is only the right event for asset purchases like these.

Design rules:

- **Ownership is not permanent.** Items can be resold (Limiteds), refunded, or expire (rentals). Check ownership on join, not once forever.
- **Do not sell power through avatar items.** A hat that gives +20 percent damage turns cosmetics into pay-to-win and makes item resale prices part of your game balance. Cosmetic perks (a trail, a title) are fine.
- **Do not use avatar items as loot box prizes for Robux** unless you follow the paid random items rules ([[Paid Random Items and Odds Disclosure in Practice]]).

## 6. Marketplace rules that kill items

The Marketplace policy points that most often catch creators (summarised in the older note, docs): no political, religious, gory, violent, drug, sexual, wedding or dating themes; no Roblox branding or Roblox-created assets; not overly similar to existing items; minimal text; nothing that hides most of the avatar, the game UI or makes the avatar disappear; head attachments on the visible head surface; correct category.

The ones with commercial consequences:

| Rule | How it bites |
|---|---|
| Overly similar items | A recolour range of the same hat as ten items can be judged similar; bundle variants or price them as one item with care |
| IP | Fan items of a show or game without a licence are removed, and repeated strikes risk the account. Collaborations need written rights |
| Updates are for fixes | A "seasonal refresh" of a best-seller is a new item, not an update |
| Text | A slogan T-shirt is "minimal text" territory; logos of real brands are IP |
| Misleading titles and descriptions | "Free robux hat", fake "limited" claims in non-limited items, keyword stuffing |

Moderation also applies to everything inside the item: textures and meshes must be uploaded by the same creator (user or group) that uploads the item, or validation reports ids not owned (older note).

## 7. Launch mechanics

- **Schedule sales** up to 30 days ahead, with optional end dates, for Limited and non-Limited items (docs). Scheduled drops let you announce a time.
- **Group versus personal creator.** The creator chosen at upload controls pricing and sale (older note). Teams should upload as a group from day one; moving an item between creators later is not something the publishing page offers.
- **Account requirements** (ID verification, 2-step verification, Plus or Premium membership for publishing and keeping items on sale) are in the older note; a lapsed membership takes items off sale.
- **Pricing tests.** You cannot A/B price the same item. Test price sensitivity across similar items over time, and use in-experience sales data where you control the shop ([[Analytics and Funnels]]).

## 8. When not to make it Limited

- **First item from an unknown creator.** Scarcity without demand is just an expensive advance. Build an audience with non-limited items first.
- **Items tied to your game's progression.** A resellable Limited that unlocks content lets players buy progression from resellers at prices you do not see.
- **Anything you may need to fix.** Updates cost fees and must stay minor; a Limited with a visible flaw is stuck that way in thousands of inventories.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Pricing at the floor by default | 30 percent share; needs 3.3x the sales of a 2x price | Start at 1.5x to 2x |
| No Do Not Price Below | Price drops with the floor | Set a minimum |
| Enabling resale casually | No restocks ever again | Decide before publishing |
| Huge Limited supply | Resale below primary price; no sales | Supply under launch reach |
| Free Limited with an easy gate | Bots take the stock; per-unit fees pile up | Real play gates, low quantity |
| Granting perks on `PromptPurchaseFinished` alone | Free perks for cancelled or delayed purchases | Server ownership check with retry |
| Perks bound to purchase moment | Resold items keep perks | Check ownership on join |
| Fan merchandise without rights | Removal and strikes | Licence in writing |

## Checklist

- [ ] Price set as floor offset plus a Do Not Price Below minimum.
- [ ] Revenue-share tier chosen deliberately (1.5x to 2x for unknown items).
- [ ] Advance break-even sales count written down and believable.
- [ ] Limited, resale and per-user cap decided before publishing; irreversibility understood.
- [ ] Free Limited events gated against bots, quantity capped, policy re-read.
- [ ] In-experience sales verified server-side with retries; ownership re-checked on join.
- [ ] No gameplay power tied to avatar items.
- [ ] IP rights and category checked; group creator used for team items.
- [ ] Fees and floors re-checked on the Creator Hub on publish day.

## See also

[[Avatars and UGC Start Here]] · [[UGC Avatar Items and Accessories]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[Bundles Animation Packs and Emotes for Sale]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Robux Price Points and Offer Design]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Trading Systems Without Duplication]] · [[Economy Inflation Sinks and Faucets Math]] · [[Roblox Policies Ratings and Compliance]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Commerce and Physical Goods]] · Player-Driven Trading Economies · Official Docs - Asset Creation · Limited-Time Offers - Design and Ethics · Subscriptions and Premium Payouts · Game Passes
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Limited-Time Offers - Design and Ethics]] · [[Player-Driven Trading Economies]] · [[Subscriptions and Premium Payouts]] · [[HumanoidDescription and Outfit Systems]] · [[Layered Clothing Creation Workflow]] · [[Avatar Body Types and Scale in Gameplay]]
<!-- related:end -->
