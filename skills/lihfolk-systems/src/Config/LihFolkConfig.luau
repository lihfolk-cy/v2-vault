--!strict
-- LihFolk Systems: shared game config (EXAMPLE VALUES - replace with yours)
-- Install: ReplicatedStorage/LihFolkConfig (ModuleScript)
--
-- Everything here is display-safe: names, prices, odds, quests. The client
-- reads it to draw UI; the server reads its OWN copy to decide outcomes, so
-- editing the client copy changes nothing. Secrets (codes) live in
-- ServerStorage/LihFolkSecrets instead.
-- Every module asserts its part of this config at startup.

local Config = {}

Config.PlayerData = {
	storeName = "PlayerData_v1", -- never rename after launch
	schemaVersion = 1,
	migrations = {
		-- [2] = function(data) data.Currency.Balances.Gems = data.Currency.Balances.Diamonds or 0 end,
	},
}

Config.Currency = {
	currencies = {
		Coins = { start = 0, paid = false, leaderstat = true },
		-- Gems can be bought with Robux (see products), so anything random
		-- priced in Gems is a PAID random item.
		Gems = { start = 0, paid = true },
	},
	maxMultiplier = 1000,
}

Config.Inventory = {
	uniqueCapacity = 200,
	maxEquipped = 3,
	items = {
		SpeedPotion = { name = "Speed Potion", stackable = true, maxStack = 99 },
		Dog = { name = "Dog", stackable = false, equippable = true, tradable = true },
		Cat = { name = "Cat", stackable = false, equippable = true, tradable = true },
		Bunny = { name = "Bunny", stackable = false, equippable = true, tradable = true },
		Fox = { name = "Fox", stackable = false, equippable = true, tradable = true },
		Dragon = { name = "Dragon", stackable = false, equippable = true, tradable = true },
		GoldenDragon = { name = "Golden Dragon", stackable = false, equippable = true, tradable = false },
	},
}

Config.Eggs = {
	maxLuck = 8,
	eggs = {
		Basic = {
			name = "Basic Egg",
			price = { currency = "Coins", amount = 100 },
			hatchCounts = { 1, 3 },
			tiers = {
				{ name = "Common", weight = 75, items = { { id = "Dog", weight = 1 }, { id = "Cat", weight = 1 } } },
				{ name = "Rare", weight = 22, lucky = true, items = { { id = "Bunny", weight = 1 } } },
				{ name = "Legendary", weight = 3, lucky = true, items = { { id = "Fox", weight = 1 } } },
			},
			pity = { tier = "Legendary", rolls = 60 },
		},
		Royal = {
			name = "Royal Egg",
			price = { currency = "Gems", amount = 50 }, -- Gems are paid: PolicyService gated
			hatchCounts = { 1 },
			restrictedNote = "Royal Egg pets can be earned from quests instead.",
			tiers = {
				{ name = "Rare", weight = 80, items = { { id = "Bunny", weight = 1 } } },
				{ name = "Legendary", weight = 19.5, lucky = true, items = { { id = "Fox", weight = 2 }, { id = "Dragon", weight = 1 } } },
				{ name = "Mythic", weight = 0.5, lucky = true, items = { { id = "GoldenDragon", weight = 1, once = true } } },
			},
			pity = { tier = "Legendary", rolls = 20 },
		},
	},
}

Config.Shop = {
	items = {
		SpeedPotion = {
			price = { currency = "Coins", amount = 250 },
			reward = { kind = "item", item = "SpeedPotion", count = 1 },
			maxQuantity = 10,
		},
	},
	passes = {
		-- Replace 0 with real Game Pass ids from the Creator Dashboard.
		DoubleCoins = { id = 0 },
		LuckyPass = { id = 0, paidModifier = true }, -- paid luck: a probability modifier
	},
}

Config.Receipts = {
	products = {
		-- Replace 0 with real Developer Product ids. Prices are NOT stored here:
		-- the client shows GetProductInfoAsync's PriceInRobux (regional pricing).
		Gems100 = { id = 0, reward = { kind = "currency", currency = "Gems", amount = 100 } },
		StarterPack = {
			id = 0,
			limit = 1,
			reward = { kind = "bundle", rewards = {
				{ kind = "currency", currency = "Coins", amount = 5000 },
				{ kind = "item", item = "SpeedPotion", count = 3 },
			} },
		},
		LuckBoost2x = { id = 0, paidRandom = true, custom = "LuckBoost2x" },
		RoyalHatch = { id = 0, paidRandom = true, custom = "RoyalHatch" },
	},
}

Config.Daily = {
	resetOffsetHours = 0,
	graceDays = 0,
	track = {
		{ kind = "currency", currency = "Coins", amount = 100 },
		{ kind = "currency", currency = "Coins", amount = 200 },
		{ kind = "currency", currency = "Coins", amount = 300 },
		{ kind = "item", item = "SpeedPotion", count = 1 },
		{ kind = "currency", currency = "Coins", amount = 500 },
		{ kind = "currency", currency = "Coins", amount = 750 },
		{ kind = "bundle", rewards = {
			{ kind = "currency", currency = "Coins", amount = 1500 },
			{ kind = "item", item = "SpeedPotion", count = 2 },
		} },
	},
}

Config.Rebirth = {
	currency = "Coins",
	baseCost = 10000,
	growth = 1.5,
	bonusPerRebirth = 0.25,
	maxBulk = 1000,
}

Config.Quests = {
	quests = {
		{
			id = "FirstCoins",
			title = "Pocket Money",
			objectives = { { kind = "Collect", target = "Coin", amount = 50, text = "Collect 50 coins" } },
			reward = { kind = "currency", currency = "Coins", amount = 250 },
		},
		{
			id = "FirstHatch",
			title = "Egg Curious",
			requires = { "FirstCoins" },
			objectives = { { kind = "Hatch", target = "*", amount = 3, text = "Hatch 3 eggs" } },
			reward = { kind = "item", item = "SpeedPotion", count = 2 },
		},
		{
			id = "RoyalFriend",
			title = "Royal Friend",
			requires = { "FirstHatch" },
			objectives = { { kind = "Hatch", target = "Basic", amount = 100, text = "Hatch 100 Basic Eggs" } },
			-- Free earnable path to a Royal Egg pet for players who cannot buy paid random items.
			reward = { kind = "item", item = "Dragon", count = 1 },
		},
	},
}

Config.Leaderboard = {
	writeSeconds = 120,
	refreshSeconds = 120,
	boards = {
		-- Source boards read the profile; counter boards are fed with Leaderboard.Add.
		CoinsEarned = { storeName = "LB_CoinsEarned_v1", period = "all" }, -- source set in Main
		WeeklyHatches = { storeName = "LB_WeeklyHatches_v1", period = "weekly" },
	},
}

return Config
