---
tags: [worked-build, monetization, game-passes, developer-products, processreceipt, shop, ui, luau, strict, type/guide, area/gameplay, level/intermediate]
---
# Shop with Game Passes and Developer Products End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Expecting a timed retry after `NotProcessedYet`.
> - Avoid: Two scripts assigning `ProcessReceipt`: one system silently never gets receipts.
> - Avoid: Granting in `PromptProductPurchaseFinished` (the docs say it does not confirm a purchase).
> - Buyer not in this server returns `NotProcessedYet`; Roblox re-sends it on rejoin or the next product purchase.
> - One `ProcessReceipt`, wrapped in `pcall`, returns `NotProcessedYet` on any doubt
> - `PurchaseId` and grant saved together; acknowledged only after save
>
> Cost: TL;DR ~170 tok · whole note ~6.9k tok. Read more: ## 4. Server · ## 5. Client and UI · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A working in-game shop from an empty place: two game passes (VIP and Double Coins) whose benefits are derived from ownership, three coin packs and a starter pack sold as developer products and granted through one idempotent `ProcessReceipt`, prices read live for each player, and a shop window that refuses to sell while the player's data is not loaded. It is built on the foundation from [[Saved Inventory End to End]] (`PlayerData`, `Net`, `InventoryService`) and uses the `Receipts` field already in its `DataTemplate`.

All code is **reviewed, not run**: strict Luau written against the `MarketplaceService` reference and the Passes and Developer Products guides (Roblox docs, as of October 2026). Run the Studio tests in section 7 before shipping. Money code deserves more testing than anything else in your game.

The reasoning behind the receipt pattern is in [[Developer Products and ProcessReceipt]] and [[Purchase Data and Receipts]]; pass mechanics in [[Game Passes]]; store layout and pricing in [[Pricing and Store Design]] and [[Robux Price Points and Offer Design]]. This note assembles them into code you can paste.

---

## 1. The two purchase models, side by side

| | Game pass | Developer product |
|---|---|---|
| Bought | Once, owned forever | Any number of times |
| Server learns about it by | `UserOwnsGamePassAsync` on join, `PromptGamePassPurchaseFinished` during play | `ProcessReceipt` callback, possibly redelivered |
| Can be bought outside the game | Yes, if listed (Roblox docs) | Yes, if listed (Roblox docs) |
| What you save | Nothing required: ownership is the source of truth | The `PurchaseId` and the grant, in one write |
| Typical failure | Benefit missing after a respawn or a slow ownership call | Paid with nothing granted, or granted twice |

The design consequence: **passes are a query, products are a transaction.** Pass code asks "does this player own X?" whenever it needs to. Product code must make "grant once" true across crashes, retries and server hops.

---

## 2. Folder layout (additions)

```
ReplicatedStorage
  Shared
    ShopConfig (ModuleScript)           -- new
ServerScriptService
  Server
    Services
      ShopService (ModuleScript)        -- new; the ONLY script that sets ProcessReceipt
StarterPlayer
  StarterPlayerScripts
    Client
      ShopController (LocalScript)      -- new
```

Create the passes and products on the Creator Dashboard (Monetization, Passes / Developer Products) and paste their ids into `ShopConfig`. The game must be published first (Roblox docs). Until then every id is `0` and the client shows "Unavailable".

---

## 3. Config

```lua
--!strict
-- ReplicatedStorage/Shared/ShopConfig (ModuleScript). Reviewed, not run.
export type Grant = {
	Coins: number,
	Items: { { ItemId: string, Count: number } }?,
}
export type PassDef = { Key: string, Id: number, Title: string, Blurb: string }
export type ProductDef = { Key: string, Id: number, Title: string, Grant: Grant }

local ShopConfig = {}

ShopConfig.Passes = {
	{ Key = "VIP", Id = 0, Title = "VIP", Blurb = "+25% coins from everything you earn" },
	{ Key = "DoubleCoins", Id = 0, Title = "2x Coins", Blurb = "Double coins from everything you earn" },
} :: { PassDef }

ShopConfig.Products = {
	{ Key = "CoinsS", Id = 0, Title = "500 Coins", Grant = { Coins = 500 } },
	{ Key = "CoinsM", Id = 0, Title = "1,500 Coins", Grant = { Coins = 1500 } },
	{ Key = "CoinsL", Id = 0, Title = "5,000 Coins", Grant = { Coins = 5000 } },
	{ Key = "Starter", Id = 0, Title = "Starter Pack", Grant = { Coins = 1000, Items = { { ItemId = "IronSword", Count = 1 }, { ItemId = "Apple", Count = 20 } } } },
} :: { ProductDef }

return ShopConfig
```

No prices in config. Prices are set on the dashboard, can be changed without an update, and with regional pricing the price a player sees can differ from your default (Roblox docs). The client reads the price for its own player at runtime. Hard-coding "99 R$" on a button is wrong for some players the day you ship it.

---

## 4. Server

### 4.1 Pass ownership

On join, the server asks once per pass, with retries, and publishes the answer as a player attribute (`Pass_VIP = true`). Attributes set by the server replicate to the client, and a client changing its local copy affects only its own display ([[Instances Attributes and Tags]]). Gameplay code on the server reads the attribute through `ShopService.OwnsPass`, which never yields.

If the ownership call fails three times, the attribute stays unset and the server tries again a minute later. The alternative, "treat unknown as not owned forever", is how players end up paying for a pass and not getting it until they rejoin.

### 4.2 The receipt handler

The rules (from [[Developer Products and ProcessReceipt]]):

1. Exactly one script sets `MarketplaceService.ProcessReceipt` (Roblox docs: a second assignment replaces the first).
2. Return `PurchaseGranted` only after the grant **and** the record of the `PurchaseId` are saved, in the same write.
3. Never grant twice for one `PurchaseId`, even if the callback runs twice at once.
4. When in doubt, return `NotProcessedYet`. Roblox redelivers the receipt later (Roblox docs give no published retry schedule; design as if it waits for the player's next visit).

Grants must not be able to fail half-way. If the item part of a pack does not fit (bag full), this build pays the item's sell value as coins instead and tells the player, rather than refusing a purchase the player has already paid for.

### 4.3 ShopService

```lua
--!strict
-- ServerScriptService/Server/Services/ShopService (ModuleScript). Reviewed, not run.
-- The only script in the game that assigns MarketplaceService.ProcessReceipt.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local PlayerData = require(script.Parent.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)

local MAX_RECEIPTS_KEPT = 100
local PROFILE_WAIT_SECONDS = 20

local ShopService = {}

local passesById: { [number]: ShopConfig.PassDef } = {}
local passesByKey: { [string]: ShopConfig.PassDef } = {}
local productsById: { [number]: ShopConfig.ProductDef } = {}
local processing: { [string]: boolean } = {}
local noticeEvent: RemoteEvent

for _, pass in ShopConfig.Passes do
	passesByKey[pass.Key] = pass
	if pass.Id ~= 0 then
		passesById[pass.Id] = pass
	end
end
for _, product in ShopConfig.Products do
	if product.Id ~= 0 then
		productsById[product.Id] = product
	end
end

-- Passes --------------------------------------------------------------------

local function attributeName(pass: ShopConfig.PassDef): string
	return `Pass_{pass.Key}`
end

function ShopService.OwnsPass(player: Player, key: string): boolean
	local pass = passesByKey[key]
	return pass ~= nil and player:GetAttribute(attributeName(pass)) == true
end

-- Multiplier for earned coins. Gameplay calls this; purchases and codes do not use it.
function ShopService.CoinMultiplier(player: Player): number
	local m = 1
	if ShopService.OwnsPass(player, "VIP") then
		m += 0.25
	end
	if ShopService.OwnsPass(player, "DoubleCoins") then
		m *= 2
	end
	return m
end

local function checkPassAsync(player: Player, pass: ShopConfig.PassDef): boolean?
	if pass.Id == 0 then
		return false
	end
	for attempt = 1, 3 do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
		if ok then
			return owns
		end
		task.wait(attempt * 2)
	end
	return nil -- unknown, try again later
end

local function refreshPasses(player: Player)
	local unknown = false
	for _, pass in ShopConfig.Passes do
		if player:GetAttribute(attributeName(pass)) ~= true then
			local owns = checkPassAsync(player, pass)
			if player.Parent ~= Players then
				return
			end
			if owns == nil then
				unknown = true
			elseif owns then
				player:SetAttribute(attributeName(pass), true)
			end
		end
	end
	if unknown then
		task.delay(60, function()
			if player.Parent == Players then
				refreshPasses(player)
			end
		end)
	end
end

-- Products ------------------------------------------------------------------

local function notify(player: Player, text: string)
	noticeEvent:FireClient(player, text)
end

-- Synchronous, cannot fail half-way. Returns false only if the profile is gone.
local function applyGrant(player: Player, grant: ShopConfig.Grant): boolean
	local bonusCoins = grant.Coins
	if grant.Items then
		for _, entry in grant.Items do
			local ok = InventoryService.Add(player, entry.ItemId, entry.Count)
			if not ok then
				local def = ItemCatalog.Get(entry.ItemId)
				local value = if def then def.SellPrice * entry.Count else 0
				bonusCoins += value
				notify(player, `Your bag was full, so you received {value} coins instead of {entry.ItemId}.`)
			end
		end
	end
	if bonusCoins > 0 then
		return InventoryService.AddCoins(player, bonusCoins)
	end
	return true
end

local function pruneReceipts(receipts: { [string]: number })
	local count = 0
	for _ in receipts do
		count += 1
	end
	while count > MAX_RECEIPTS_KEPT do
		local oldestId, oldestTime = nil :: string?, math.huge
		for id, t in receipts do
			if t < oldestTime then
				oldestId, oldestTime = id, t
			end
		end
		if not oldestId then
			break
		end
		receipts[oldestId] = nil
		count -= 1
	end
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local productId = receiptInfo.ProductId
	local product = if type(productId) == "number" then productsById[productId] else nil
	if not product then
		-- Unknown product (removed from config, or a test id). Never grant, never acknowledge.
		warn(`[Shop] unknown product {productId} in receipt {receiptInfo.PurchaseId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- redelivered when they are in a server
	end
	local profile = PlayerData.WaitForProfile(player, PROFILE_WAIT_SECONDS)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if processing[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- a concurrent call is handling it
	end
	processing[purchaseId] = true

	local receipts = profile.Data.Receipts
	if receipts[purchaseId] == nil then
		-- Grant and record in one synchronous block, in the same profile document.
		if not applyGrant(player, product.Grant) then
			processing[purchaseId] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		receipts[purchaseId] = os.time()
		pruneReceipts(receipts)
		notify(player, `Thanks! {product.Title} delivered.`)
	end
	-- Whether we just granted or a previous call did, acknowledge only once it is on disk.
	local saved = PlayerData.SaveNowAsync(player)
	processing[purchaseId] = nil
	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
ShopService.ProcessReceiptForTest = processReceipt -- callbacks cannot be read back; tests call this

function ShopService.Start()
	noticeEvent = Net.Event("ShopNotice")

	MarketplaceService.ProcessReceipt = function(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
		local ok, decision = pcall(processReceipt, receiptInfo)
		if not ok then
			warn(`[Shop] ProcessReceipt error: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		local pass = passesById[passId]
		if not pass then
			return
		end
		if wasPurchased then
			player:SetAttribute(attributeName(pass), true)
			notify(player, `{pass.Title} unlocked!`)
		end
	end)

	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
end

return ShopService
```

Details that matter:

- **The `processing` guard.** `SaveNowAsync` yields. Without the guard, a second delivery of the same receipt arriving during that yield would see the receipt already recorded (good, no double grant) and also try to save (harmless). The guard mostly saves a redundant write, but it also protects you if you later move the record after a yield by mistake.
- **Acknowledging an already-recorded receipt still saves.** If the first call recorded the grant in memory but the save failed, the second call must not return `PurchaseGranted` until a save succeeds. Skipping the save on "already recorded" is the subtle bug in many handlers.
- **Receipts are pruned to 100.** A receipt is only redelivered while you keep returning `NotProcessedYet`; once acknowledged it does not come back. Keeping the last 100 ids bounds profile growth. A player making more than 100 purchases while one old receipt stays unacknowledged is not a realistic case (rule of thumb).
- **Unknown products are not acknowledged.** If you delete a product from config while receipts for it are pending, those players are not silently charged for nothing: the receipt waits, and the warning in your logs tells you to restore the entry.
- **Wiping data keeps the receipt problem honest.** Receipts live inside the profile, so a data wipe also forgets which purchases were granted. That is correct here: the grant was wiped too. The separate-store pattern gets this wrong ([[Developer Products and ProcessReceipt]] has the production story).

### 4.4 Earning coins with the multiplier

Purchased and code coins are never multiplied. Earned coins are:

```lua
-- Anywhere in gameplay (server):
local ShopService = require(ServerScriptService.Server.Services.ShopService)
local InventoryService = require(ServerScriptService.Server.Services.InventoryService)

local function rewardKill(player: Player, baseCoins: number)
	local amount = math.floor(baseCoins * ShopService.CoinMultiplier(player))
	InventoryService.AddCoins(player, amount)
end
```

If you multiply purchased coins, a "5,000 coins" pack silently becomes 12,500 for some players, the store copy is wrong, and your economy model breaks ([[Economy Inflation Sinks and Faucets Math]]).

---

A receipt left as `NotProcessedYet` is not retried on a timer: Roblox calls `ProcessReceipt` again when that player joins a server of the experience or buys another developer product. Returning `NotProcessedYet` when the buyer is not in this server (`Players:GetPlayerByUserId` is nil) is therefore safe; the grant happens wherever they play next.

## 5. Client and UI

The client prompts purchases directly: `PromptGamePassPurchase` and `PromptProductPurchase` can be called from a LocalScript (Roblox docs). There is no "buy" remote, because the client never needs to tell the server anything about a purchase. Note: as of October 2026 the `MarketplaceService` reference page marks `PromptProductPurchase` as deprecated without naming a replacement on that page, while the Developer Products guide still uses it. This note follows the guide; check the reference for a successor before you ship.

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/ShopController (LocalScript). Reviewed, not run.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)

local player = Players.LocalPlayer
local noticeEvent = Net.Event("ShopNotice")

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local gui = make("ScreenGui", { Name = "Shop", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local openButton = make("TextButton", { Text = "Shop", Size = UDim2.fromOffset(80, 40), Position = UDim2.new(0, 12, 0.5, -120) }, gui)
local window = make("Frame", {
	Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.7),
}, gui)
local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6,
}, window)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local toast = make("TextLabel", {
	Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(420, 40), TextWrapped = true,
}, gui)

-- Prices: one cached lookup per id; failures are not cached.
local priceCache: { [string]: number } = {}
local function getPriceAsync(id: number, infoType: Enum.InfoType): number?
	if id == 0 then
		return nil
	end
	local cacheKey = `{infoType.Name}_{id}`
	local cached = priceCache[cacheKey]
	if cached then
		return cached
	end
	local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, infoType)
	if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
		if infoType == Enum.InfoType.GamePass and info.IsForSale == false then
			return nil
		end
		priceCache[cacheKey] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

local function canBuy(): boolean
	-- Never prompt while the profile is not loaded: the receipt could not be saved.
	return player:GetAttribute("DataReady") == true
end

local function row(order: number, title: string, blurb: string): (TextLabel, TextButton)
	local frame = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 64) }, list)
	local label = make("TextLabel", {
		Size = UDim2.new(0.7, 0, 1, 0), BackgroundTransparency = 1, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Text = `{title}\n{blurb}`,
	}, frame)
	local button = make("TextButton", { Size = UDim2.new(0.28, 0, 0.8, 0), Position = UDim2.new(0.71, 0, 0.1, 0), Text = "..." }, frame)
	return label, button
end

local passButtons: { [string]: TextButton } = {}

local function refreshPassButton(pass: ShopConfig.PassDef)
	local button = passButtons[pass.Key]
	if not button then
		return
	end
	if player:GetAttribute(`Pass_{pass.Key}`) == true then
		button.Text = "Owned"
		button.Active = false
		button.AutoButtonColor = false
		return
	end
	local price = getPriceAsync(pass.Id, Enum.InfoType.GamePass)
	button.Text = if price then `R$ {price}` else "Unavailable"
end

local function build()
	local order = 0
	for _, pass in ShopConfig.Passes do
		order += 1
		local _, button = row(order, pass.Title, pass.Blurb)
		passButtons[pass.Key] = button
		button.Activated:Connect(function()
			if pass.Id ~= 0 and canBuy() and player:GetAttribute(`Pass_{pass.Key}`) ~= true then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
		task.spawn(refreshPassButton, pass)
		player:GetAttributeChangedSignal(`Pass_{pass.Key}`):Connect(function()
			refreshPassButton(pass)
		end)
	end
	for _, product in ShopConfig.Products do
		order += 1
		local _, button = row(order, product.Title, "")
		button.Activated:Connect(function()
			if product.Id ~= 0 and canBuy() then
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end
		end)
		task.spawn(function()
			local price = getPriceAsync(product.Id, Enum.InfoType.Product)
			button.Text = if price then `R$ {price}` else "Unavailable"
		end)
	end
end

build()

openButton.Activated:Connect(function()
	window.Visible = not window.Visible
end)

local toastToken = 0
noticeEvent.OnClientEvent:Connect(function(text: string)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(4, function()
		if toastToken == mine then
			toast.Visible = false
		end
	end)
end)
```

UI rules that come from production experience:

- **Show "Owned" for passes.** Players who own a pass and see a buy button assume the purchase failed and open support tickets.
- **Show the real price or nothing.** If the lookup fails, "Unavailable" (or a plain "Buy") is honest; the Roblox prompt always shows the true price.
- **Disable buttons while data loads.** `DataReady` is set by `PlayerData` when the profile is active ([[Saved Inventory End to End]]). A purchase before that is safe (the receipt waits), but the player sees nothing happen and buys again.
- **Paid random items** (crates, eggs) need odds shown before purchase and other disclosure rules: do not add them to this shop without reading [[Paid Random Items and Odds Disclosure in Practice]].

---

## 6. Where to apply pass benefits

| Benefit type | Where to apply | Pitfall |
|---|---|---|
| Multipliers (coins, XP) | At the earn site, via `CoinMultiplier` | Applying to purchased amounts |
| Character stats (speed, health) | `CharacterAdded`, and when the attribute flips to true | Lost on respawn if set only once |
| Access (VIP area) | Server check on the zone's entry (teleport out, or a server-side door) | Client-only doors: exploiters walk through |
| Cosmetic (trail, tag) | Server creates it so everyone sees it | Creating it on the client: only the owner sees it |
| Extra slots (bag size) | Read on each `Add` | Shrinking when ownership check fails; never remove items because a check timed out |

The last row is a general rule: an ownership check that **fails** must never be treated as **not owned** for anything destructive.

---

## 7. Testing in Studio

Studio purchases are test purchases: the prompt says so and no Robux are charged (Roblox docs). `ProcessReceipt` runs normally.

1. **Products.** Publish, create a product, paste its id, Play. Buy "500 Coins": the toast appears, coins rise by exactly 500.
2. **Idempotency.** Callback properties cannot be read back from `MarketplaceService`, so the module exposes the handler as `ShopService.ProcessReceiptForTest`. In the command bar (server view):
   `local f = require(game.ServerScriptService.Server.Services.ShopService).ProcessReceiptForTest; local r = {PurchaseId = "test-1", PlayerId = game.Players:GetPlayers()[1].UserId, ProductId = <id>, CurrencySpent = 0}; print(f(r)); print(f(r))`. Coins rise once; both calls return `PurchaseGranted` (each after its save, so the second takes about six seconds because of the save spacing).
3. **Save failure.** Turn off Studio API access, buy again: the handler must return `NotProcessedYet` (the grant is in memory and recorded, but not acknowledged). Turn access back on: the next delivery or your manual call acknowledges without granting again.
4. **Profile not ready.** Set `SimulateLoadFailure`, Play: you are kicked, and a fake receipt for your id returns `NotProcessedYet`.
5. **Passes.** Buy a pass in Studio: the attribute flips and the button shows Owned. Stop and Play: in Studio the test purchase does not create real ownership, so the pass is gone again. That is expected; test join-time ownership with an account that really owns the pass, in a live test server.
6. **Full bag.** Fill uniques to 200, buy the Starter Pack: coins replace the sword, and the toast explains.
7. **Multiplier.** Give yourself the attributes in the command bar (`player:SetAttribute("Pass_DoubleCoins", true)`) and earn coins through gameplay; purchased coins stay unmultiplied.

---

## 8. Exploits and abuse

| Threat | Defence |
|---|---|
| Client fires a fake "I bought it" remote | There is no such remote. Grants come only from `ProcessReceipt` and the pass event, both server-side |
| Client sets `Pass_VIP` locally | Changes only its own display; the server reads its own attribute |
| Duplicate grant from redelivery or server crash | `PurchaseId` recorded in the same document as the grant; acknowledge only after a successful save |
| Buy, then crash the server before the save | Receipt not acknowledged; redelivered later; the record makes the replay safe |
| Buy on server A while the profile is owned by server B | `WaitForProfile` returns nil on A; `NotProcessedYet`; the receipt is processed where the profile lives |
| Chargeback after use | Not preventable in code. Logging the `PurchaseId` lets support match it ([[Refunds Chargebacks and Purchase Support]]) |
| Regional price arbitrage via gifts or trades | Follow the regional pricing rules before enabling it for products ([[Pricing and Store Design]]) |

---

## 9. Extending it

- **Purchase log.** Append a compact entry (`PurchaseId`, product key, time) to an analytics event so support can answer "did I get it?" ([[Purchase Data and Receipts]], [[Analytics and Funnels]]).
- **Limited-time offers.** Gate the button on server time and a live-config flag ([[Global State and Live Config]]); the product stays purchasable, so the grant must still be valid after the offer ends.
- **Gifting.** Requires a recipient id in the grant and a profile you do not own: write to a mailbox store the recipient's server reads on join, never directly into another player's profile.
- **Subscriptions.** A different API and payout model: [[Subscriptions and Premium Payouts]].
- **Rewarded video.** [[Ads and Rewarded Video]].

## Common mistakes

- Avoid: Expecting a timed retry after `NotProcessedYet`. Symptom: grant waits until the buyer rejoins or buys another product.
- Two scripts assigning `ProcessReceipt`: one system silently never gets receipts.
- Granting in `PromptProductPurchaseFinished` (the docs say it does not confirm a purchase).
- Returning `PurchaseGranted` before the save.
- A separate receipts store written in a different request from the profile.
- Hard-coded prices.
- Treating a failed ownership call as "not owned" and removing a benefit.

## Checklist

- [ ] Buyer not in this server returns `NotProcessedYet`; Roblox re-sends it on rejoin or the next product purchase.
- [ ] One `ProcessReceipt`, wrapped in `pcall`, returns `NotProcessedYet` on any doubt
- [ ] `PurchaseId` and grant saved together; acknowledged only after save
- [ ] Grants cannot fail half-way (fallback to coins)
- [ ] Unknown product ids are logged and not acknowledged
- [ ] Pass ownership checked on join with retries, updated on purchase, re-checked when unknown
- [ ] Prices read live per player; Owned state shown
- [ ] Purchases blocked until `DataReady`
- [ ] Tested: idempotent replay, save failure, profile not ready, full bag

## See also

[[Worked Builds Start Here]] | [[Developer Products and ProcessReceipt]] | [[Game Passes]] | [[Purchase Data and Receipts]] | [[Economy Exploits - Dupes Races and Purchase Abuse]] | [[Monetization Overview]] | [[Saved Inventory End to End]]

## Connected notes
<!-- auto-links:start -->
[[Idempotency]] · Skill - Roblox Monetization Compliance · Official Docs - Monetization · Limited-Time Offers - Design and Ethics · Currency Architecture - Soft Hard and Event Currencies
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Purchase Receipts and Purchase History in UI]] · [[AI Pitfalls - Data and Monetization]] · [[LihFolk Systems - Data and Purchase Guarantees]] · [[LihFolk Systems Library]] · [[Daily Rewards System End to End]] · [[Codes Redemption System End to End]] · [[Global Leaderboards End to End]]
<!-- related:end -->
