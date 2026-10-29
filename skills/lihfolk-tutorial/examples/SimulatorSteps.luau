--!strict
-- LihFolk Tutorial example: the step list for a pet-simulator onboarding.
-- Install: ReplicatedStorage/TutorialSteps (ModuleScript). Shared by server and client.
--
-- Teaching order = list order. Objectives stay at 8 words or fewer; hints appear only when stuck.
-- World targets are found by CollectionService tag, so tag your map parts: Coin, SellPad, StarterEgg.
-- Server-only hooks (trigger / isComplete) are attached in Tutorial.server.luau, not here.

return {
	{
		id = "collect",
		objective = "Collect 10 coins",
		signal = "Collected",
		goal = 10,
		target = { tag = "Coin", highlight = false }, -- many coins: a path to the nearest, no outline spam
		hint = { any = "Walk into the shiny coins" },
		hintAfter = 6,
		reveal = { "Coins" },
	},
	{
		id = "sell",
		objective = "Sell your coins at the green pad",
		signal = "Sold",
		requires = { "collect" },
		target = { tag = "SellPad" },
		hint = { any = "Follow the gold path" },
		reward = "SellBonus", -- server tops cash up to exactly one upgrade
		reveal = { "Cash" },
	},
	{
		id = "upgrade",
		objective = "{OPEN} UPGRADE to collect faster",
		signal = "Upgraded",
		requires = { "sell" },
		guide = "none", -- HUD target: the client's own button pulse does the pointing
		hint = { Keyboard = "The orange button on the left", Touch = "Tap the orange button on the left", Gamepad = "Press Select, then UPGRADE" },
		reveal = { "UpgradeButton" },
	},
	{
		id = "egg",
		objective = "Hatch your first pet",
		signal = "Hatched",
		requires = { "upgrade" },
		target = { tag = "StarterEgg", prompt = true },
		hint = { Keyboard = "Walk to the egg and press E", Touch = "Walk to the egg and tap Hatch", Gamepad = "Walk to the egg and press X" },
		reward = "FirstPet",
		reveal = { "PetsButton" },
	},
	{
		id = "friends",
		objective = "Bring a friend: +10% coins together",
		clientSignal = "InviteOpened", -- UI-only; pays nothing
		requires = { "egg" },
		optional = true, -- never blocks "finished"; social play is never gated behind it
		guide = "none",
		reveal = { "InviteButton" },
	},
}
