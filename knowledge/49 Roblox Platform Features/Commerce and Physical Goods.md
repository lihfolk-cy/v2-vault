---
tags: [platform-features, commerce, merchandise, shopify, commerceservice, policyservice, avatar-items, monetization, luau, strict]
---
# Commerce and Physical Goods

Roblox now lets eligible creators sell **real-world products** (shirts, plushies, posters) inside their games, paid in real money and fulfilled through a Shopify store, optionally bundled with a digital item. It is a narrow feature with strict eligibility, a US-only buyer base and real-world obligations (shipping, returns, product claims) that do not exist for Robux products. This note explains the system end to end, where it fits and where it does not, and the "digital merch" route most creators actually use: selling avatar items in game for a commission. For Robux products see [[Developer Products and ProcessReceipt]] and [[Game Passes]]; for UGC pricing see [[UGC Pricing Limiteds and Marketplace Rules]].

Platform facts are labelled **Roblox docs (as of October 2026)** and were checked against the Commerce products guide, the CommerceService and PolicyService references, the Webhook notifications guide, the Avatar items guide and the Marketplace fees and commissions page on create.roblox.com. The docs state that commerce eligibility requirements are subject to change; check them before planning. Business and legal points are rule of thumb, not legal advice.

## 1. How commerce products work

The flow (Roblox docs, as of October 2026):
1. **Import catalog items from Shopify.** In the Creator Dashboard (game, Monetization Products, Commerce) you connect your Roblox account to your Shopify store by installing the Roblox sales channel, optionally connect a Roblox group so its members can use the imported items, and pick which products to import.
2. **Create commerce products** from imported items. A commerce product is either a catalog item alone or a catalog item **bundled with a digital benefit** (if you qualify). Products go through **moderation** and, for bundles, a **bundling fee** you must accept. Status moves from Pending to Approved (or Moderated, with an appeal path).
3. **Put products on sale** and prompt purchases in game with `CommerceService`.

Limits and behaviours (Roblox docs):
- Up to **500 commerce products per game**, and up to **100 on sale at a time**.
- **Two products containing the same catalog item cannot be on sale at once**; take one off sale before putting the other on.
- **Changing a price in Shopify** takes every bundle containing that item off sale and resubmits it for bundling fee processing.
- **Changing content in Shopify** (name, description, images, variants) keeps products on sale but resubmits them to moderation; Roblox keeps showing the previously approved content until the new content is approved.
- **Deleting an imported item** deletes every commerce product that contains it.
- A Roblox **group that owns any commerce items cannot be transferred** to a new owner, because the Shopify link is tied to an account.
- Bundles have an **inventory type**: fixed quantity, merch on demand, or pre-order.

The practical meaning of the Shopify rules: Shopify is the source of truth, and edits there have side effects in Roblox. A price tweak during a sale takes your bundles off sale until the fee is re-processed. Freeze Shopify edits during campaigns (rule of thumb).

## 2. Who can sell, where, and to whom

### Creators (Roblox docs, as of October 2026)
- 18 or older, **ID-verified and email-verified**, with **2-step verification** on.
- The registered account holder of the linked Shopify store, or holding written permission from that holder.
- Business information submitted (Account Information, Core Account and Legal tabs); group submissions need the permission to configure and spend group revenue, and group commerce access needs the permission to create and edit community experiences.
- In good standing with the Community Standards, on an ongoing basis.

### Games
- **Public**, with **content maturity labels** from the questionnaire.
- Compliant with the Community Standards, **Advertising Standards** and **Commerce Standards**, on an ongoing basis.

### Buyers
- **US-based users only**, at the time of writing.
- **13 or older**, except **18 or older in Texas**.
- Check with `PolicyService:GetPolicyInfoForPlayerAsync(player)`, field `IsEligibleToPurchaseCommerceProduct` (Roblox docs).

That buyer rule is the single biggest design constraint. If most of your audience is under 13 or outside the US, most players will never see your merch. Size the opportunity from your own analytics (age and country breakdowns) before you invest in it.

### Digital benefits: a much higher bar
To bundle a digital item with a physical product you must meet **one** of two conditions (Roblox docs, as of October 2026):
- The hosting game averages more than **100,000 DAU** over the last 90 days **and** more than **1,000,000 Robux** in average monthly earnings over the last 90 days, **and** sells at least one bundle within three months of approval; or
- A written agreement with Roblox for at least **$50,000 USD** of ad spend in one year.

And each bundled digital benefit must (Roblox docs):
- comply with the Community and Advertising Standards, alone and in the context of the bundle;
- **not have been available for purchase before**, or separately for Robux;
- **not be Robux or in-game currency**;
- be disclosed clearly in the listing, with no uncertainty for the buyer;
- **not be random** or require a chance-based mechanic;
- need **no extra steps** after payment.

Benefit types are an **avatar item** (must never have been on sale; you or your group must own it; create it before the bundle) or a **developer product** (owned by the game, never on sale, **no price**; names unique within the game). A developer product used as a benefit is created when you submit the commerce product; to reuse it across bundles, submit one first, then select it in later bundles (Roblox docs).

So for nearly every creator, commerce means **physical goods only**. The bundle mechanics matter mainly to the largest games.

## 3. The in-game API

`CommerceService` (Roblox docs, as of October 2026):

| Member | Use |
|---|---|
| `GetCommerceProductInfoAsync(commerceProductId)` | Yields. Returns `IsForSale`, an `Item` table (`Name`, `Description`, `IconImageAssetId`, `DisplayPrice` as a localised string such as "$4.99", `IsPurchasable` meaning in stock or backorderable) and `Benefits` |
| `PromptCommerceProductPurchase(player, commerceProductId)` | Opens a webview with the purchase flow. From a client script, `player` must be the local player |
| `PromptCommerceProductPurchaseFinished(player, productId)` | Fires when the webview closes. **Not** a success signal |
| `PromptRealWorldCommerceBrowser`, `UserEligibleForRealWorldCommerceAsync` | Legacy, "not meant for use"; use the prompt above and `PolicyService` |

Product ids can be passed as the numeric id or the full `COM-` prefixed form (Roblox docs).

Two details from the docs worth building around:
- The purchase webview **forces Android devices into portrait mode**. The docs recommend using the finished event to reorient players. If your game is landscape, restore it in that handler.
- The Product detail page (PDP) that the webview shows is built from your Shopify data: images in Shopify order (the first, "featured", image is the thumbnail), title, variants, price, your store name as seller, the description (HTML allowed, but links, images and scripts are stripped), up to **five** "Additional information" accordions from Shopify product metafields in a `Roblox.pdp_info_` namespace (multi-line text only), the bundled benefit if any, and "More from this game" (Roblox docs). Descriptions must accurately cover functionality, specifications, features, **return or exchange policy** and **origin**; incomplete descriptions are not approved (Roblox docs, referencing the Commerce Standards).

### Code: an eligibility-gated merch panel

```lua
--!strict
-- ServerScriptService/MerchEligibility (Script)
-- Answers one question for the client: may this player see the merch shop?
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteFunction")
remote.Name = "MerchEligibility"
remote.Parent = ReplicatedStorage

local cache: { [Player]: boolean } = {}

remote.OnServerInvoke = function(player: Player): boolean
	local cached = cache[player]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok then
		return false -- do not cache failures; the client may ask again later
	end
	local eligible = info.IsEligibleToPurchaseCommerceProduct == true
	cache[player] = eligible
	return eligible
end

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)
```

```lua
--!strict
-- StarterPlayerScripts/MerchPanel (LocalScript)
local CommerceService = game:GetService("CommerceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PRODUCT_IDS = { "COM-0000000000", "COM-0000000001" } -- from the Commerce page
local PREFERRED_ORIENTATION = Enum.ScreenOrientation.LandscapeSensor

local eligibilityRemote = ReplicatedStorage:WaitForChild("MerchEligibility") :: RemoteFunction

local function isEligible(): boolean
	local ok, result = pcall(function()
		return eligibilityRemote:InvokeServer()
	end)
	return ok and result == true
end

type Card = { id: string, name: string, price: string, canBuy: boolean, iconId: number }

local function loadCards(): { Card }
	local cards: { Card } = {}
	for _, id in PRODUCT_IDS do
		local ok, info = pcall(CommerceService.GetCommerceProductInfoAsync, CommerceService, id)
		if ok and info and info.IsForSale and info.Item then
			table.insert(cards, {
				id = id,
				name = info.Item.Name,
				price = info.Item.DisplayPrice, -- already localised, includes the currency symbol
				canBuy = info.Item.IsPurchasable == true,
				iconId = info.Item.IconImageAssetId,
			})
		end
	end
	return cards
end

local function buy(id: string)
	CommerceService:PromptCommerceProductPurchase(player, id)
end

CommerceService.PromptCommerceProductPurchaseFinished:Connect(function(_user: Player, _productId: string)
	-- Closing the webview is not a purchase. Only restore the screen.
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		playerGui.ScreenOrientation = PREFERRED_ORIENTATION
	end
end)

if isEligible() then
	local cards = loadCards()
	-- Build your UI from `cards`; wire each card's button to buy(card.id).
	-- Disable the button and show "Out of stock" when canBuy is false.
	print("[Merch] showing", #cards, "products")
else
	-- Hide the merch tab entirely; ineligible players should not see a shop they cannot use.
end
```

Two notes on this code. The reference does not say whether `GetCommerceProductInfoAsync` is meant for client or server scripts; the localised `DisplayPrice` suggests the client, which is what the sample assumes, but verify in your own test. And the eligibility answer is cached per session on the server; a player's policy does not change mid-session in normal play.

## 4. Granting and revoking digital benefits

If you qualify for bundles (Roblox docs, as of October 2026):
- **Avatar item benefits** are granted by Roblox automatically after purchase, and **revoked automatically** if Roblox detects a cancellation or refund of the physical item. If the avatar item is later moderated, linked commerce products are taken off sale and, **after 7 days**, the item is revoked from all buyers; a successful appeal regrants it.
- **Developer product benefits** generate a normal developer product receipt sent to the server where the user is, handled by your existing `ProcessReceipt` ([[Developer Products and ProcessReceipt]], [[Purchase Data and Receipts]]). **Roblox does not revoke them** on refund or cancellation.

For developer product benefits, revocation is your job, through **webhooks**: `CommerceProductOrderPaid` and `CommerceProductOrderRefunded` (refunded or cancelled). The payload's `CommerceProductOrder` has a `path` of the form `universes/{universe_id}/commerce-products/{commerce_product_id}/orders/{order_id}`, `createTime`, `updateTime`, `state` (`STATE_PAID`, `STATE_REFUNDED`), `merchantOrderId`, `merchant` (`SHOPIFY`) and `user` (`users/{id}`). The docs warn that **duplicate Paid events are possible; deduplicate on the order id** (Roblox docs).

A working revocation path (rule of thumb):
1. Your webhook endpoint verifies the `roblox-signature`, deduplicates, and on a refund writes a record for that user into a DataStore through the Open Cloud DataStore API ([[Open Cloud APIs]]): commerce product id, order id, time.
2. On join, the game reads that record and removes the benefit granted for that commerce product, if it is still removable, then marks the record handled.

The docs do not describe a field that links the developer product receipt (`PurchaseId`) to the commerce order id, so match on user and commerce product and keep at most one benefit per order. Treat that mapping as **unverified** until you see both payloads side by side in testing.

Webhook delivery rules are the same as for other triggers: HTTPS POST, 2XX within 5 seconds, 5 retries, `NotificationId` for duplicate detection (Roblox docs). See [[Subscriptions and Recurring Revenue]] for signature checking.

## 5. The route most creators use: avatar items sold in game

For creators without a Shopify business, "merch" usually means **avatar items tied to the game**. The economics (Roblox docs, as of October 2026, Marketplace fees and commissions):
- When an avatar item sells **inside a game** (through the Avatar Inspect Menu, `AvatarEditorService` or `MarketplaceService`), the **item creator gets 30% and the game owner gets 40%**. On the Marketplace itself, the creator gets 30% (with a progressive share for prices above the floor, which applies only to Marketplace purchases).
- Commissions are held for **30 days** in escrow.
- Uploading avatar items needs ID verification (own or linked parent account) and an upload fee of **80 Robux** per submission (500 for items with an emissive mask), plus a publishing advance that depends on asset type.

That 40% in-game share is why hangout and avatar games add try-on booths: you earn on other creators' items sold in your game too. The **Merch Booth** developer module sells avatar assets, passes and developer products in game; to sell third-party UGC through it, enable **Allow Third Party Sales** in the Security section of Experience Settings (Roblox docs). The inspect menu is on by default and is itself a sales surface ([[Avatar Context Menus Profiles and Social Surfaces]]). For making the items, see [[UGC Avatar Items and Accessories]] and [[Bundles Animation Packs and Emotes for Sale]].

| Route | Who can use it | Buyer pays | You earn | Your obligations |
|---|---|---|---|---|
| Commerce product (physical) | Eligible 18+ creators with Shopify | Real money, US buyers 13+ (18+ in Texas) | Shopify sale proceeds, minus fees not documented on the pages checked | Shipping, returns, product claims, customer service |
| Commerce bundle with digital benefit | Very large games or $50,000 ad partners | Real money | As above | As above, plus benefit revocation for developer products |
| Game-linked avatar item | Verified UGC creators | Robux | 30% as creator, plus 40% as game owner when sold in your game | Moderation, upload costs |
| Third-party items in your booth | Any game with third-party sales on | Robux | 40% as game owner | None beyond your UI |

How Roblox's own fees or revenue share apply to commerce sales was not stated on the pages checked for this note; the dashboard and the bundling fee are where you will see it.

## 6. Designing a merch shop that players trust

Rules of thumb, aligned with the docs' standards:
- **Separate real money from Robux.** A merch tab with prices like "$24.99" must never sit inside the Robux shop grid. Mixing them confuses young players and parents and invites complaints.
- **No pressure tactics.** Countdown timers and "only 3 left!" claims must be true; false scarcity violates the spirit of the advertising rules and erodes trust ([[Limited-Time Offers - Design and Ethics]], [[Ethical Design and Player Trust]]).
- **No gameplay advantage from physical purchases.** Bundled benefits cannot be currency or random anyway; keep them cosmetic.
- **Show it only to eligible players.** Ineligible players see nothing, not a locked shop.
- **Answer the real-world questions in the PDP:** sizes, materials, shipping region, returns. Use the five accordion slots.
- **Expect support load.** Shipping delays and sizing returns go to your Shopify support, not to Roblox. Players will ask in your game's community channels; prepare answers ([[Community Building]]).
- **Advertising and age gating.** Your game must stay compliant with the Advertising Standards on an ongoing basis; a commerce game is a commercial surface and gets judged as one ([[Roblox Policies Ratings and Compliance]], [[Age Checks and Safety Features]]).

## 7. When not to do this
- Most of your audience is under 13 or outside the US.
- You do not already run (or want to run) a real merchandise business with fulfilment and returns.
- Your game is small: the effort is fixed, the buyer pool is a fraction of your players, and in-game avatar items reach everyone.
- You want a revenue line for next month. Moderation, bundling fees and Shopify setup take time.

## 8. Common mistakes

| Mistake | Fix |
|---|---|
| Granting anything on `PromptCommerceProductPurchaseFinished` | It only means the webview closed; benefits arrive by receipt or automatically |
| Showing the merch tab to every player | Gate on `IsEligibleToPurchaseCommerceProduct` |
| Editing Shopify prices during a campaign | Bundles go off sale until the bundling fee is processed again |
| Leaving Android players in portrait after checkout | Restore orientation in the finished handler |
| Expecting Roblox to revoke developer product benefits on refund | Webhooks plus your own revocation |
| Not deduplicating Paid webhooks | Deduplicate on the order id |
| Mixing $ prices into the Robux shop | Separate tab, clear real-money labelling |
| Transferring a group that owns commerce items | Not allowed; plan ownership first |

## 9. Checklist
- [ ] Eligibility confirmed for creator, game (public, maturity labels) and audience size
- [ ] Shopify products complete: description, returns, origin, metafield accordions
- [ ] Merch tab visible only to eligible players; prices from `DisplayPrice`
- [ ] Orientation restored after checkout on Android
- [ ] Developer product benefits granted through `ProcessReceipt`; revocation path via webhooks
- [ ] Webhook endpoint verified, deduplicated, answering within 5 seconds
- [ ] Shopify edits frozen during campaigns
- [ ] Considered in-game avatar items (40% game owner share) as the simpler alternative

## See also
[[Platform Features Start Here]] · [[Monetization Overview]] · [[Developer Products and ProcessReceipt]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[UGC Avatar Items and Accessories]] · [[Pricing and Store Design]] · [[Roblox Policies Ratings and Compliance]] · [[Working with Content Creators]]

## Connected notes
<!-- auto-links:start -->
[[Refunds Chargebacks and Purchase Support]] · [[Avatars and UGC Start Here]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[DevEx and Cashing Out]] · [[Robux Price Points and Offer Design]] · [[Publishing an Experience]]
<!-- auto-links:end -->
