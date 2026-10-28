--!strict
--[[
	LihFolk UI example: REBIRTH (current -> next tier, progress, confirm, paid skip)
	LocalScript in StarterPlayer > StarterPlayerScripts.

	Reads (display only):
	  player attribute "Rebirths" (number) and leaderstats.Cash (IntValue / NumberValue)
	Server contract (you write it; the server re-checks everything):
	  ReplicatedStorage > Remotes > Rebirth (RemoteEvent) FireServer()
	  SKIP_PRODUCT_ID: a developer product granted in ProcessReceipt
	Rule: anything that resets progress gets a confirm step that says what resets.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("LihFolkUI")
local Theme = require(UI:WaitForChild("LihFolkUITheme"))
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

local player = Players.LocalPlayer

local SKIP_PRODUCT_ID = 0 -- your developer product id
local SKIP_PRICE = 49 -- must match the product's real price
local CONFIRM_WINDOW = 3 -- seconds the "tap again" state lasts

-- Keep these in ONE shared config module in a real game, read by server and client.
local function requirement(rebirths: number): number
	return 1e6 * 2 ^ rebirths
end
local function multiplier(rebirths: number): number
	return 1 + 0.5 * rebirths
end

Controller.start()

local window = C.Window({
	name = "Rebirth",
	title = "Rebirth",
	theme = "rebirth",
	icon = "rebirth",
	size = Vector2.new(720, 540),
})

local compare = C.TierCompare({
	current = { title = "Rebirth 0", value = "x1", caption = "Cash multiplier" },
	nextTier = { title = "Rebirth 1", value = "x1.5", caption = "Cash multiplier" },
	theme = "rebirth",
	layoutOrder = 1,
	window = window,
	parent = window.body,
})

local progress = C.ProgressBar({
	role = "premium",
	size = UDim2.new(1, -16, 0, 34),
	layoutOrder = 2,
	parent = window.body,
})

C.Text("caption", "Rebirthing resets your Cash and Upgrades. You keep Pets and Gems.", {
	color = Theme.Palette.textMid,
	wrap = true,
	size = UDim2.new(1, 0, 0, 36),
	layoutOrder = 3,
	parent = window.body,
})

local actions = C.Row({ height = Theme.Size.buttonH + 12, gap = Theme.Space.lg, layoutOrder = 4, parent = window.body })

local confirming = false
local confirmToken = 0
local rebirthButton: any

local function findRemote(): RemoteEvent?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild("Rebirth")
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

local function cash(): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Cash")
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		return (value :: any).Value
	end
	return 0
end

local function refresh()
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0
	local have = cash()
	local need = requirement(rebirths)
	compare.setTiers(
		{ title = `Rebirth {rebirths}`, value = "x" .. tostring(multiplier(rebirths)), caption = "Cash multiplier" },
		{ title = `Rebirth {rebirths + 1}`, value = "x" .. tostring(multiplier(rebirths + 1)), caption = "Cash multiplier" }
	)
	progress.setValue(have / need, Controller.isOpen("Rebirth"))
	progress.setText(`{Theme.formatShort(have)} / {Theme.formatShort(need)} Cash`)
	if not confirming then
		rebirthButton.setState(if have >= need then "claim" else "locked")
	end
end

local function endConfirm()
	confirming = false
	rebirthButton.button.setRole("go")
	refresh()
end

rebirthButton = C.StateButton({
	state = "locked",
	texts = { claim = "REBIRTH", locked = "NEED CASH", pending = "..." },
	size = UDim2.fromOffset(250, Theme.Size.buttonH),
	layoutOrder = 1,
	window = window,
	parent = actions,
	onActivated = function(state)
		if state ~= "claim" then
			return
		end
		if not confirming then
			-- Step 1: ask. Same button, danger colour, explicit words.
			confirming = true
			confirmToken += 1
			local token = confirmToken
			rebirthButton.button.setRole("danger")
			rebirthButton.button.setText("TAP TO CONFIRM")
			task.delay(CONFIRM_WINDOW, function()
				if confirming and token == confirmToken then
					endConfirm()
				end
			end)
			return
		end
		-- Step 2: do it. The server validates and resets; we just wait for new stats.
		confirming = false
		confirmToken += 1
		local remote = findRemote()
		if not remote then
			warn("[Rebirth] Add ReplicatedStorage.Remotes.Rebirth (RemoteEvent)")
			endConfirm()
			return
		end
		rebirthButton.setState("pending")
		remote:FireServer()
		task.delay(1.5, refresh)
	end,
})

C.CurrencyButton({
	price = SKIP_PRICE,
	currency = "robux",
	role = "premium",
	size = UDim2.fromOffset(180, Theme.Size.buttonH),
	layoutOrder = 2,
	parent = actions,
	onActivated = function()
		if SKIP_PRODUCT_ID == 0 then
			warn("[Rebirth] Set SKIP_PRODUCT_ID in RebirthMenu")
			return
		end
		MarketplaceService:PromptProductPurchase(player, SKIP_PRODUCT_ID)
	end,
})
C.Text("caption", "Skip: rebirth now without the Cash", {
	color = Theme.Palette.textLow,
	layoutOrder = 5,
	parent = window.body,
})

-- Live updates while open; one refresh on open covers changes made while closed.
player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 30)
	local value = stats and stats:WaitForChild("Cash", 30)
	if value and value:IsA("ValueBase") then
		value.Changed:Connect(function()
			if Controller.isOpen("Rebirth") then
				refresh()
			end
		end)
	end
end)

Controller.register(window)
Controller.addHudButton({ window = "Rebirth", label = "Rebirth", icon = "rebirth", theme = "rebirth", layoutOrder = 2 })
Controller.onChanged(function(name: string, isOpen: boolean)
	if name == "Rebirth" and isOpen then
		refresh()
	end
end)
window.defaultSelection = rebirthButton.button.hit
refresh()
