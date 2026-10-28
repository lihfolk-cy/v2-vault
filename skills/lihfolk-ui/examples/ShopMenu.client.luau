--!strict
--[[
	LihFolk UI example: SHOP (game passes + developer products)
	LocalScript in StarterPlayer > StarterPlayerScripts.
	Needs ReplicatedStorage > LihFolkUI with the four LihFolk UI modules.

	Purchases here are PROMPTS only. Grant developer products on the server in
	ProcessReceipt and game-pass perks after a server ownership check (see the
	roblox-monetization-compliance skill). Replace every `id = 0` with your ids and
	keep the shown prices equal to the real ones (MarketplaceService:GetProductInfo).
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("LihFolkUI")
local Theme = require(UI:WaitForChild("LihFolkUITheme"))
local Icons = require(UI:WaitForChild("LihFolkUIIcons"))
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

local player = Players.LocalPlayer
local SP = Theme.Space

type Pass = { key: string, name: string, perk: string, icon: string, price: number, id: number }
type Product = { key: string, name: string, amount: number, icon: string, price: number, id: number, featured: boolean? }

local PASSES: { Pass } = {
	{ key = "vip", name = "VIP", perk = "+25% Cash forever and a VIP chat tag", icon = "crown", price = 199, id = 0 },
	{ key = "speed", name = "Fast Feet", perk = "Walk 1.5x faster in every zone", icon = "boost", price = 79, id = 0 },
	{ key = "slots", name = "+3 Pet Slots", perk = "Equip three more pets at once", icon = "pet", price = 149, id = 0 },
}

local PRODUCTS: { Product } = {
	{ key = "coins_s", name = "Coin Pouch", amount = 1000, icon = "coin", price = 25, id = 0 },
	{ key = "coins_m", name = "Coin Chest", amount = 6000, icon = "coin", price = 99, id = 0 },
	{ key = "coins_l", name = "Coin Vault", amount = 40000, icon = "coin", price = 499, id = 0, featured = true },
}

local CARD = Vector2.new(220, 236)

Controller.start()

local helpLabel: TextLabel
local window = C.Window({
	name = "Shop",
	title = "Shop",
	theme = "shop",
	icon = "shop",
	headerAction = {
		icon = "info",
		onActivated = function()
			helpLabel.Visible = not helpLabel.Visible
		end,
	},
})

helpLabel = C.Text("caption", "Passes are permanent. Coins arrive as soon as the purchase goes through.", {
	color = Theme.Palette.textMid,
	wrap = true,
	size = UDim2.new(1, 0, 0, 40),
	layoutOrder = 0,
	parent = window.body,
})
helpLabel.Visible = false

local function grid(order: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Grid" .. order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.LayoutOrder = order
	C.Grid(holder, CARD, SP.md)
	holder.Parent = window.body
	return holder
end

-- One shop card: icon, name, one-line benefit, price button.
local function itemCard(parent: Instance, order: number, iconName: string, title: string, detail: string, featured: boolean): any
	local card = C.Card({
		name = title,
		featured = featured,
		gap = SP.xs,
		layoutOrder = order,
		parent = parent,
	})

	local iconSlot = Instance.new("Frame")
	iconSlot.Name = "IconSlot"
	iconSlot.BackgroundTransparency = 1
	iconSlot.Size = UDim2.new(1, 0, 0, 68)
	iconSlot.LayoutOrder = 1
	iconSlot.Parent = card.content
	if featured then
		C.Sunburst({ size = UDim2.fromScale(1.7, 1.7), zIndex = 0, window = window, parent = iconSlot })
		C.Pill("BEST VALUE", {
			role = "premium",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 0, 2),
			rotation = -4,
			zIndex = 6,
			parent = card.root,
		})
	end
	local icon = Icons.make(iconName, UDim2.fromScale(1, 1))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 2
	icon.Parent = iconSlot

	C.Text("title", title, { scaled = true, size = UDim2.new(1, 0, 0, 30), layoutOrder = 2, parent = card.content })
	C.Text("caption", detail, {
		color = Theme.Palette.textMid,
		wrap = true,
		size = UDim2.new(1, 0, 0, 38),
		layoutOrder = 3,
		parent = card.content,
	})
	return card
end

-- GAME PASSES -----------------------------------------------------------
C.SectionHeader("Game Passes", "shop", 1, window.body)
local passGrid = grid(2)
local passButtons: { [number]: any } = {}

local function markOwned(button: any)
	button.button.setRole("done")
	button.button.setText("OWNED")
	button.button.setIcon("check")
	button.button.setEnabled(false)
end

for index, pass in PASSES do
	local card = itemCard(passGrid, index, pass.icon, pass.name, pass.perk, false)
	local price = C.CurrencyButton({
		price = pass.price,
		currency = "robux",
		size = UDim2.new(1, 0, 0, Theme.Size.buttonH),
		layoutOrder = 4,
		parent = card.content,
		onActivated = function()
			if pass.id == 0 then
				warn(`[Shop] Set the game pass id for "{pass.key}" in ShopMenu`)
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end,
	})
	if pass.id ~= 0 then
		passButtons[pass.id] = price
	end
	if index == 1 then
		window.defaultSelection = price.button.hit
	end
end

-- Display-only ownership. Perks are granted by the server after its own check.
local function refreshOwnership()
	for passId, button in passButtons do
		task.spawn(function()
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
			if ok and owns then
				markOwned(button)
			end
		end)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who: Player, passId: number, purchased: boolean)
	if who == player and purchased and passButtons[passId] then
		refreshOwnership()
	end
end)

-- COINS -----------------------------------------------------------------
C.SectionHeader("Coins", "shop", 3, window.body)
local productGrid = grid(4)

for index, product in PRODUCTS do
	local card = itemCard(productGrid, index, product.icon, product.name, "x" .. Theme.formatComma(product.amount) .. " Coins", product.featured == true)
	C.CurrencyButton({
		price = product.price,
		currency = "robux",
		size = UDim2.new(1, 0, 0, Theme.Size.buttonH),
		layoutOrder = 4,
		parent = card.content,
		onActivated = function()
			if product.id == 0 then
				warn(`[Shop] Set the developer product id for "{product.key}" in ShopMenu`)
				return
			end
			MarketplaceService:PromptProductPurchase(player, product.id)
		end,
	})
end

-- REGISTER --------------------------------------------------------------
Controller.register(window)
Controller.addHudButton({ window = "Shop", label = "Shop", icon = "shop", theme = "shop", layoutOrder = 1 })

Controller.onChanged(function(name: string, isOpen: boolean)
	if name == "Shop" and isOpen then
		refreshOwnership()
	end
end)
