---
tags: [genre-system, tycoon, worked-build, plots, economy, server-authority, datastore, luau]
---
# Tycoon Plots and Droppers End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Fire `TycoonBuy` with another plot's button id (Ids are global, purchase only affects the caller's own data and plot)
> - Avoid: Fire `TycoonBuy` 1,000 times per second (Rate limited to a burst of 6; each call is cheap anyway)
> - Avoid: Teleport onto another player's collector (`toucher ~= player` check)
> - Solo Play: plot assigned, character moved, first pad free, buy it, income starts, collector pays.
> - Two clients: each gets a different plot; neither can collect or buy on the other's plot.
> - Leave and rejoin: base rebuilt in one frame, offline earnings shown, cash and pending intact.
>
> Read more (33 KB note): ## 4. The server: TycoonService · ## 6. The client: TycoonController · ## 5. Edge cases and failure modes · ## 9. Test checklist
<!-- tldr:end -->

This note builds the core of a tycoon from an empty place: a row of plots, automatic plot assignment, a button chain defined as data, purchases validated on the server, income that ticks on the server without a single physics part, droppers that are pure client-side decoration, a collector, offline earnings, saving by purchase id, and a rebuild that puts a returning player's whole base back in one frame. It is the code companion to [[Genre Playbook - Tycoons]], which explains why tycoons work, the payback maths and the "dropper trap". This note does not repeat those arguments; it implements them and then deals with the edge cases the playbook only names.

> **All code is reviewed, not run.** It is strict Luau written against Roblox docs (as of October 2026) and checked by reading. Run the test checklist in section 9 before you trust it with players.

Labels used: **Roblox docs (as of October 2026)**, **rule of thumb**, **measured in the reference project**.

---

## 1. What you are building, and the decisions behind it

| Decision | Choice | Why |
|---|---|---|
| Source of truth for money | `profile.Data.Tycoon` inside the session-locked profile | One place, saved by the existing autosave; nothing to copy back on leave |
| Income | A server tick once per second, `income * dt` | No physics parts on the server; money cannot depend on a lag spike |
| Drops on conveyors | Client-only parts, pooled, only for plots near the camera | Visual cost scales with what one player sees, not with the server |
| Saved shape | Owned button ids, cash, pending cash, last-seen time | Plots are rebuilt from ids into whatever plot is free |
| Plot assignment | Automatic on profile load | No "all plots claimed by AFK players" problem |
| Purchases | A touch pad on the server, plus a validated remote for a "Buy" UI button | Pads feel classic; the remote serves phone players and gamepads |

The foundation comes from [[Saved Inventory End to End]]: the `Net` remote helper, `RateLimiter`, `DataTemplate`, the lease-locked `PlayerData` module and the `Main` bootstrap. This note adds one service and one controller on top. If you have not built that note, build it first; every system in this folder assumes it (see [[Genre Systems Start Here]]).

### When not to use this design
- **Physics is the game.** If players build ore sorters, ramps and Rube Goldberg machines and the fun is watching parts move, a pure income tick throws away the fantasy. Keep money independent of physics anyway (pay by a server tick that reads which machines exist), but let the parts be real, capped per plot, and owned by the plot owner's client so the server does not simulate them ([[Network Ownership]], [[Physics Performance]]).
- **Plots that must persist in place.** A "your house in a shared town" game where neighbours see your build at a fixed address needs a fixed plot per player, which means one server per neighbourhood or a reserved-server model. That is a different system.
- **Freeform building.** Placing walls anywhere on a grid is [[Grid Placement and Player Building Systems]], not a button chain.

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    Net (ModuleScript)                 -- from Saved Inventory End to End
    TycoonCatalog (ModuleScript)       -- the button chain, shared with the client
ServerScriptService
  Server (Folder)
    Main (Script)                      -- add "TycoonService" to ORDER
    PlayerData, DataTemplate, RateLimiter (ModuleScripts)
    Services (Folder)
      TycoonService (ModuleScript)
ServerStorage
  TycoonModels (Folder)
    Dropper1 (Model)   -- authored on a template plot whose Origin sits at the world origin
    Wall1 (Model)
    ...
Workspace
  Plots (Folder)
    Plot1 (Model)
      Origin (Part, anchored, the plot's reference frame)
      Collector (Part, anchored)
      Sign (Part with a SurfaceGui and TextLabel named Owner)
    Plot2 ... Plot8
StarterPlayer
  StarterPlayerScripts
    Client (Folder)
      TycoonController (LocalScript)
```

**Authoring rule (rule of thumb, and the one that saves the most time):** build every purchasable model once on a template plot whose `Origin` part sits at `CFrame.identity`, then move the models into `ServerStorage.TycoonModels`. At runtime the server places a model with `plotOrigin.CFrame * model:GetPivot()`. Because the model was authored relative to the identity frame, its pivot already is its offset from the plot origin, and the same model fits every plot, even plots that are rotated. Teams that author on Plot1 and "subtract Plot1's position" lose a day to rotated plots.

Dropper models carry three things the client needs: an attribute `DropRate` (drops per second, visual only), an `Attachment` named `DropPoint`, and a folder `Path` of attachments named `1`, `2`, `3`... that trace the conveyor to the collector. The server never reads them.

Set **Game Settings, Places, Max Players** to the plot count (8 here) plus at most two (Roblox docs (as of October 2026): the server size is a place setting). A visitor slot or two is fine because a player without a plot is handled; twenty visitors on eight plots is not.

---

## 3. Data: the catalog and the profile fields

### 3.1 TycoonCatalog

```lua
--!strict
-- ReplicatedStorage/Shared/TycoonCatalog (ModuleScript). Reviewed, not run.
export type Button = {
	Id: string,
	Name: string,
	Cost: number,
	Requires: string?,   -- button that must be owned first, nil for the chain root
	Income: number,      -- cash per second this purchase adds
	Model: string,       -- child of ServerStorage.TycoonModels
	PadOffset: CFrame,   -- where the buy pad sits, relative to the plot Origin
}

local TycoonCatalog = {}

-- Bump when ids change; old saves are migrated by Renamed and refunds (section 5.3).
TycoonCatalog.ChainVersion = 2

TycoonCatalog.Buttons = {
	{ Id = "dropper1", Name = "Dropper", Cost = 0, Requires = nil, Income = 2, Model = "Dropper1", PadOffset = CFrame.new(0, 0.5, 10) },
	{ Id = "dropper2", Name = "Dropper II", Cost = 60, Requires = "dropper1", Income = 4, Model = "Dropper2", PadOffset = CFrame.new(6, 0.5, 10) },
	{ Id = "wall1", Name = "Walls", Cost = 150, Requires = "dropper2", Income = 0, Model = "Wall1", PadOffset = CFrame.new(12, 0.5, 10) },
	{ Id = "upgrader1", Name = "Upgrader", Cost = 400, Requires = "dropper2", Income = 10, Model = "Upgrader1", PadOffset = CFrame.new(-6, 0.5, 10) },
} :: { Button }

-- Old id -> new id. A save that owns "dropper_basic" now owns "dropper1".
TycoonCatalog.Renamed = {
	dropper_basic = "dropper1",
} :: { [string]: string }

TycoonCatalog.ById = {} :: { [string]: Button }
for _, button in TycoonCatalog.Buttons do
	assert(TycoonCatalog.ById[button.Id] == nil, `duplicate button id {button.Id}`)
	TycoonCatalog.ById[button.Id] = button
end
for _, button in TycoonCatalog.Buttons do
	assert(button.Requires == nil or TycoonCatalog.ById[button.Requires] ~= nil, `{button.Id} requires an unknown id`)
end

-- Rebirth multiplier: one place, used by the server tick and shown by the client.
function TycoonCatalog.multiplier(rebirths: number): number
	return 1 + 0.5 * rebirths
end

return TycoonCatalog
```

The asserts at load time are cheap insurance. A chain with a typo in `Requires` produces a button that can never appear, and that bug survives every playtest where nobody reaches that far. In a real chain of 150 buttons, generate this table from your balance sheet ([[Data and Config Pipeline - Spreadsheets to Game]], [[Balancing with Spreadsheets and Data]]).

### 3.2 Profile fields

Add one field to `DataTemplate.Data` and to `DataTemplate.new()` in [[Saved Inventory End to End]]. `reconcile` fills it for existing players without a migration.

```lua
-- In DataTemplate: add to the Data type
	Tycoon: {
		Cash: number,
		Pending: number,              -- earned but not yet collected
		Owned: { [string]: boolean },
		ChainVersion: number,
		LastSeen: number,             -- os.time() written every tick while playing
		Rebirths: number,
	},

-- and to DataTemplate.new()
		Tycoon = { Cash = 0, Pending = 0, Owned = {}, ChainVersion = 2, LastSeen = 0, Rebirths = 0 },
```

`Owned` is an empty table in the template, so `reconcile` treats it as a map of player content and does not recurse into it. That is the behaviour you want.

**Why tycoon cash is not the shared `Coins` field.** Tycoon cash inflates by design: a late-game plot earns millions per minute and a rebirth wipes it. If cash and the meta currency are the same number, a rebirth either wipes something it should not, or your shop prices become meaningless. Keep the inflating currency separate and convert at rebirth ([[Rebirth and Prestige System End to End]], [[Economy Inflation Sinks and Faucets Math]]).

---

## 4. The server: TycoonService

```lua
--!strict
-- ServerScriptService/Server/Services/TycoonService (ModuleScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local TycoonCatalog = require(ReplicatedStorage.Shared.TycoonCatalog)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local OFFLINE_CAP_SECONDS = 2 * 60 * 60 -- rule of thumb: two hours
local OFFLINE_RATE = 0.5                -- offline earns half
local TICK_SECONDS = 1
local MAX_ID_LENGTH = 40

type Plot = {
	Model: Model,
	Origin: BasePart,
	Collector: BasePart,
	Owner: Player?,
	Built: Folder,
	Pads: { [string]: BasePart },
	Income: number,
	Connections: { RBXScriptConnection },
}

local TycoonService = {}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}
local touchCooldown: { [Player]: number } = {}
local allowBuy = RateLimiter.new(6, 3)

-- Helpers ------------------------------------------------------------------

local function tycoonOf(player: Player)
	local profile = PlayerData.Get(player)
	return if profile then profile.Data.Tycoon else nil
end

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not player or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return player
end

local function touchAllowed(player: Player): boolean
	local now = os.clock()
	if (touchCooldown[player] or 0) > now then
		return false
	end
	touchCooldown[player] = now + 0.4
	return true
end

local function publish(player: Player)
	local data = tycoonOf(player)
	if not data then
		return
	end
	-- Attributes replicate to every client; the HUD and the drop visuals read them.
	player:SetAttribute("Cash", math.floor(data.Cash))
	player:SetAttribute("Pending", math.floor(data.Pending))
end

-- Building -------------------------------------------------------------------

local function recomputeIncome(plot: Plot, owned: { [string]: boolean }, rebirths: number)
	local total = 0
	for id in owned do
		local button = TycoonCatalog.ById[id]
		if button then
			total += button.Income
		end
	end
	plot.Income = total * TycoonCatalog.multiplier(rebirths)
	plot.Model:SetAttribute("Income", plot.Income)
end

local function build(plot: Plot, button: TycoonCatalog.Button)
	local models = ServerStorage:FindFirstChild("TycoonModels")
	local template = if models then models:FindFirstChild(button.Model) else nil
	if not template or not template:IsA("Model") then
		warn(`[Tycoon] missing model {button.Model}`)
		return
	end
	local clone = template:Clone()
	clone.Name = button.Id
	clone:PivotTo(plot.Origin.CFrame * template:GetPivot())
	clone.Parent = plot.Built
end

local buyAsync: (Player, string) -> (boolean, string)

local function refreshPads(plot: Plot, owned: { [string]: boolean })
	for id, pad in plot.Pads do
		if owned[id] then
			pad:Destroy()
			plot.Pads[id] = nil
		end
	end
	for _, button in TycoonCatalog.Buttons do
		local unlocked = button.Requires == nil or owned[button.Requires] == true
		if unlocked and not owned[button.Id] and not plot.Pads[button.Id] then
			local pad = Instance.new("Part")
			pad.Name = `Pad_{button.Id}`
			pad.Anchored = true
			pad.CanCollide = false
			pad.Size = Vector3.new(4, 1, 4)
			pad.Color = Color3.fromRGB(80, 200, 120)
			pad.CFrame = plot.Origin.CFrame * button.PadOffset
			pad:SetAttribute("ButtonId", button.Id)
			pad:SetAttribute("Cost", button.Cost)
			pad.Parent = plot.Model
			plot.Pads[button.Id] = pad
			table.insert(plot.Connections, pad.Touched:Connect(function(hit: BasePart)
				local player = playerFromHit(hit)
				if player and plotOf[player] == plot and touchAllowed(player) then
					buyAsync(player, button.Id)
				end
			end))
		end
	end
end

-- Migration: renamed ids are mapped, removed ids are refunded.
local function migrateOwned(data: any)
	if data.ChainVersion == TycoonCatalog.ChainVersion then
		return
	end
	local fresh: { [string]: boolean } = {}
	for id in data.Owned do
		local mapped = TycoonCatalog.Renamed[id] or id
		if TycoonCatalog.ById[mapped] then
			fresh[mapped] = true
		else
			-- The button no longer exists. Refunding is cheaper than a support ticket.
			-- Without the old cost table, refund a flat amount; keep old costs around if you can.
			data.Cash += 100
		end
	end
	data.Owned = fresh
	data.ChainVersion = TycoonCatalog.ChainVersion
end

-- Plot lifecycle ----------------------------------------------------------------

local function releasePlot(plot: Plot)
	for _, connection in plot.Connections do
		connection:Disconnect()
	end
	table.clear(plot.Connections)
	for _, pad in plot.Pads do
		pad:Destroy()
	end
	table.clear(plot.Pads)
	plot.Built:ClearAllChildren()
	plot.Owner = nil
	plot.Income = 0
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Model:SetAttribute("Income", 0)
	local sign = plot.Model:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Owner", true)
	if label and label:IsA("TextLabel") then
		label.Text = "Free plot"
	end
end

local function assignPlot(player: Player)
	local data = tycoonOf(player)
	if not data or plotOf[player] then
		return
	end
	local plot: Plot? = nil
	for _, candidate in plots do
		if candidate.Owner == nil then
			plot = candidate
			break
		end
	end
	if not plot then
		-- Server full of plots. Visitors can walk around; tell them, do not kick.
		player:SetAttribute("TycoonStatus", "NoPlot")
		return
	end

	migrateOwned(data)

	-- Offline earnings, computed from the saved last-seen time and the saved income.
	local now = os.time()
	if data.LastSeen > 0 then
		local away = math.clamp(now - data.LastSeen, 0, OFFLINE_CAP_SECONDS)
		local owned = data.Owned
		local base = 0
		for id in owned do
			local button = TycoonCatalog.ById[id]
			base += if button then button.Income else 0
		end
		local earned = math.floor(base * TycoonCatalog.multiplier(data.Rebirths) * away * OFFLINE_RATE)
		if earned > 0 then
			data.Pending += earned
			player:SetAttribute("OfflineEarned", earned)
		end
	end
	data.LastSeen = now

	plot.Owner = player
	plotOf[player] = plot
	plot.Model:SetAttribute("OwnerUserId", player.UserId)
	local sign = plot.Model:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Owner", true)
	if label and label:IsA("TextLabel") then
		label.Text = `{player.DisplayName}'s Tycoon`
	end

	-- Silent rebuild: every owned model in one pass, no animations.
	for id in data.Owned do
		local button = TycoonCatalog.ById[id]
		if button then
			build(plot, button)
		end
	end
	recomputeIncome(plot, data.Owned, data.Rebirths)
	refreshPads(plot, data.Owned)

	table.insert(plot.Connections, plot.Collector.Touched:Connect(function(hit: BasePart)
		local toucher = playerFromHit(hit)
		if toucher ~= player or not touchAllowed(player) then
			return
		end
		local current = tycoonOf(player)
		if current and current.Pending > 0 then
			current.Cash += current.Pending
			current.Pending = 0
			publish(player)
		end
	end))

	player:SetAttribute("TycoonStatus", "Ready")
	player:SetAttribute("PlotName", plot.Model.Name)
	publish(player)

	-- Move the character to its plot once it exists.
	local function toPlot(character: Model)
		task.defer(function()
			if plotOf[player] == plot then
				character:PivotTo(plot.Origin.CFrame * CFrame.new(0, 4, 0))
			end
		end)
	end
	if player.Character then
		toPlot(player.Character)
	end
	table.insert(plot.Connections, player.CharacterAdded:Connect(toPlot))
end

-- Purchases ----------------------------------------------------------------------

buyAsync = function(player: Player, id: string): (boolean, string)
	local plot = plotOf[player]
	local data = tycoonOf(player)
	if not plot or not data then
		return false, "no plot"
	end
	local button = TycoonCatalog.ById[id]
	if not button then
		return false, "unknown"
	end
	if data.Owned[id] then
		return false, "owned"
	end
	if button.Requires and not data.Owned[button.Requires] then
		return false, "locked"
	end
	if data.Cash < button.Cost then
		return false, "poor"
	end
	data.Cash -= button.Cost
	data.Owned[id] = true
	build(plot, button)
	recomputeIncome(plot, data.Owned, data.Rebirths)
	refreshPads(plot, data.Owned)
	publish(player)
	return true, "ok"
end

-- Public API -------------------------------------------------------------------------

-- For a rebirth service: wipe the plot and rebuild from the new (empty) Owned table.
function TycoonService.Rebuild(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	releasePlot(plot)
	assignPlot(player)
end

function TycoonService.Start()
	for _, model in workspace:WaitForChild("Plots"):GetChildren() do
		local origin = model:FindFirstChild("Origin")
		local collector = model:FindFirstChild("Collector")
		if model:IsA("Model") and origin and origin:IsA("BasePart") and collector and collector:IsA("BasePart") then
			local built = Instance.new("Folder")
			built.Name = "Built"
			built.Parent = model
			table.insert(plots, {
				Model = model, Origin = origin, Collector = collector, Owner = nil,
				Built = built, Pads = {}, Income = 0, Connections = {},
			})
		end
	end

	local buyRemote = Net.Event("TycoonBuy")
	buyRemote.OnServerEvent:Connect(function(player: Player, id: unknown)
		if type(id) ~= "string" or #id > MAX_ID_LENGTH then
			return
		end
		if not allowBuy(player) then
			return
		end
		buyAsync(player, id)
	end)

	PlayerData.OnLoaded(function(profile)
		assignPlot(profile.Player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local plot = plotOf[player]
		plotOf[player] = nil
		touchCooldown[player] = nil
		if plot then
			releasePlot(plot)
		end
	end)

	-- The income tick. Writes straight into the profile, so autosave and leave-save see it.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_SECONDS)
			local now = os.clock()
			local dt = math.min(now - last, 5) -- a long server stall does not mint a windfall
			last = now
			local unix = os.time()
			for player, plot in plotOf do
				local data = tycoonOf(player)
				if data then
					data.Pending += plot.Income * dt
					data.LastSeen = unix
					player:SetAttribute("Pending", math.floor(data.Pending))
				end
			end
		end
	end)
end

return TycoonService
```

### 4.1 Why the code looks like this

- **No copy-back on leave.** The tick writes `Pending` and `LastSeen` straight into `profile.Data`. If instead the service kept cash in its own table and wrote it to the profile in its own `PlayerRemoving` handler, it would race the profile module's own `PlayerRemoving` save: the engine does not promise which connection runs first, and the save can capture the old value. Writing into the profile at the moment of change removes the race entirely. This is the single most common data-loss bug in tycoons built on top of a profile library.
- **`dt` is clamped to 5 seconds.** `task.wait(1)` can return late on a struggling server. Paying the true elapsed time is fair; paying a 40-second stall in one tick after a server hitch can double-trigger income-based achievements and looks like a dupe in your analytics.
- **Pads are created by the server and destroyed on purchase**, so a pad's existence on the client is never trusted, and a player cannot touch a pad that belongs to another plot (the `plotOf[player] == plot` check).
- **The remote takes only an id.** Never a cost, a plot, or a position. The server derives all of them. See [[Server Authority and Validation]].
- **Offline earnings are computed from saved income**, not from what the client last saw, and are capped. Because `LastSeen` is refreshed every tick and saved by the regular autosave, hopping servers does not farm offline time: a player who leaves and rejoins 30 seconds later gets 30 seconds at half rate.
- **Plot release clears everything the plot connected**, including the `CharacterAdded` connection on the old owner. Without that, a player who leaves and rejoins the same server (a new `Player` object) leaves behind a dead connection per visit ([[Hunting Memory Leaks Step by Step]]).

---

## 5. Edge cases and failure modes

### 5.1 The profile never loads
`PlayerData` kicks a player whose data fails to load (see [[Saved Inventory End to End]]), so `assignPlot` is never called and no plot is held. Do not assign a plot on `PlayerAdded` and fill it later: a plot held by a player whose load then fails stays locked until they are kicked, and if your kick path is ever skipped, it stays locked for the life of the server.

### 5.2 More players than plots
Late in a server's life, social joins (following a friend) can exceed the plot count if Max Players is higher. The code marks the visitor with `TycoonStatus = "NoPlot"`. The client shows "All plots are taken: you are visiting. Your progress is safe." A better fix is to offer a teleport to a fresh server with your friends via [[Teleporting and Multi-Place Games]]. Never evict another player's plot.

### 5.3 Changing the chain after launch
Renaming an id without a `Renamed` entry silently deletes that purchase for every player on next load. Removing a button needs a refund (the flat refund above is a placeholder; keep an `OldCosts` table for removed ids so you can refund exactly). Reordering `Requires` can strand a player who owns a child but not its new parent: the pad for the parent appears, they buy it, nothing is lost. That is acceptable. Inserting a new required step in the middle of the chain is not: players past that point own buttons "above" an unowned requirement, which looks broken. Insert new content at the end or as side branches. See [[Schema Migrations - Worked Case Studies]].

### 5.4 Rebirth
A rebirth service sets `Tycoon.Owned = {}`, `Cash = 0`, `Pending = 0`, increments `Rebirths`, grants the meta reward, then calls `TycoonService.Rebuild(player)`. Do all the data changes in one function without yields, before the rebuild, so an autosave in between cannot capture half a rebirth. The closed-form costs and the two-layer reset are in [[Rebirth and Prestige System End to End]].

### 5.5 Exploits this build resists, and one it does not
| Attack | Result |
|---|---|
| Fire `TycoonBuy` with another plot's button id | Ids are global, purchase only affects the caller's own data and plot |
| Fire `TycoonBuy` 1,000 times per second | Rate limited to a burst of 6; each call is cheap anyway |
| Teleport onto another player's collector | `toucher ~= player` check |
| Teleport onto pads out of order | Requirements and cost are checked on the server |
| Spoof `Cash` attribute on the client | Attributes set by the client do not replicate to the server |
| **Collect while AFK forever** | Not prevented. Idle earning is the genre. Cap `Pending` if your economy needs it |

---

## 6. The client: TycoonController

The controller does three things: shows cash, offers a "Buy next" button for touch and gamepad players, and draws drops on conveyors for plots near the camera.

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/TycoonController (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local player = Players.LocalPlayer
local buyRemote = Net.Event("TycoonBuy")
local plotsFolder = workspace:WaitForChild("Plots")

local VIEW_DISTANCE = 160      -- studs; plots further away draw no drops (rule of thumb)
local MAX_DROPS_PER_PLOT = 40
local DROP_SPEED = 12          -- studs per second along the conveyor

-- HUD ------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.fromScale(0.3, 0.06)
cashLabel.Position = UDim2.fromScale(0.35, 0.02)
cashLabel.BackgroundTransparency = 0.3
cashLabel.TextScaled = true
cashLabel.Parent = gui

local buyButton = Instance.new("TextButton")
buyButton.Size = UDim2.fromScale(0.18, 0.07)
buyButton.Position = UDim2.fromScale(0.8, 0.85)
buyButton.TextScaled = true
buyButton.Text = "Buy next"
buyButton.Parent = gui

local function refreshHud()
	local cash = (player:GetAttribute("Cash") :: number?) or 0
	local pending = (player:GetAttribute("Pending") :: number?) or 0
	cashLabel.Text = `${cash}  (+{pending} to collect)`
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshHud)
player:GetAttributeChangedSignal("Pending"):Connect(refreshHud)
refreshHud()

-- "Buy next": the cheapest pad visible on my plot. The server re-checks everything.
buyButton.Activated:Connect(function()
	local plotName = player:GetAttribute("PlotName")
	local plot = if type(plotName) == "string" then plotsFolder:FindFirstChild(plotName) else nil
	if not plot then
		return
	end
	local bestId: string? = nil
	local bestCost = math.huge
	for _, child in plot:GetChildren() do
		local id = child:GetAttribute("ButtonId")
		local cost = child:GetAttribute("Cost")
		if type(id) == "string" and type(cost) == "number" and cost < bestCost then
			bestId, bestCost = id, cost
		end
	end
	if bestId then
		buyRemote:FireServer(bestId)
	end
end)

-- Drops ---------------------------------------------------------------------------
type Drop = { Part: BasePart, Points: { Vector3 }, Index: number, Position: Vector3 }

local pool: { BasePart } = {}
local active: { [Model]: { Drop } } = {}
local spawnAccumulator: { [Model]: number } = {}

local function takePart(): BasePart
	local part = table.remove(pool)
	if part then
		return part
	end
	local newPart = Instance.new("Part")
	newPart.Size = Vector3.new(0.8, 0.8, 0.8)
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = false
	newPart.CastShadow = false
	return newPart
end

local function givePart(part: BasePart)
	part.Parent = nil
	table.insert(pool, part)
end

local function pathPoints(dropper: Model): { Vector3 }?
	local dropPoint = dropper:FindFirstChild("DropPoint", true)
	local pathFolder = dropper:FindFirstChild("Path")
	if not dropPoint or not dropPoint:IsA("Attachment") or not pathFolder then
		return nil
	end
	local points = { dropPoint.WorldPosition }
	local i = 1
	while true do
		local node = pathFolder:FindFirstChild(tostring(i))
		if not node or not node:IsA("Attachment") then
			break
		end
		table.insert(points, node.WorldPosition)
		i += 1
	end
	return if #points >= 2 then points else nil
end

RunService.PreRender:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position

	for _, plot in plotsFolder:GetChildren() do
		local origin = plot:FindFirstChild("Origin")
		local built = plot:FindFirstChild("Built")
		if not origin or not origin:IsA("BasePart") or not built then
			continue
		end
		local near = (origin.Position - eye).Magnitude < VIEW_DISTANCE
		for _, dropper in built:GetChildren() do
			if not dropper:IsA("Model") then
				continue
			end
			local list = active[dropper]
			if not list then
				list = {}
				active[dropper] = list
				dropper.Destroying:Connect(function()
					for _, d in active[dropper] or {} do
						givePart(d.Part)
					end
					active[dropper] = nil
					spawnAccumulator[dropper] = nil
				end)
			end
			-- Spawn while near; existing drops finish their trip either way.
			local rate = dropper:GetAttribute("DropRate")
			if near and type(rate) == "number" and rate > 0 and #list < MAX_DROPS_PER_PLOT then
				local acc = (spawnAccumulator[dropper] or 0) + dt * rate
				while acc >= 1 do
					acc -= 1
					local points = pathPoints(dropper)
					if points then
						local part = takePart()
						part.Position = points[1]
						part.Parent = workspace
						table.insert(list, { Part = part, Points = points, Index = 2, Position = points[1] })
					end
				end
				spawnAccumulator[dropper] = acc
			end
			-- Move drops along the polyline; recycle at the end.
			for i = #list, 1, -1 do
				local d = list[i]
				local step = DROP_SPEED * dt
				while step > 0 and d.Index <= #d.Points do
					local target = d.Points[d.Index]
					local offset = target - d.Position
					local distance = offset.Magnitude
					if distance <= step then
						d.Position = target
						d.Index += 1
						step -= distance
					else
						d.Position += offset.Unit * step
						step = 0
					end
				end
				d.Part.Position = d.Position
				if d.Index > #d.Points then
					givePart(d.Part)
					table.remove(list, i)
				end
			end
		end
	end
end)
```

### 6.1 Notes on the client
- `pathPoints` is recomputed per spawn so a rotated plot or a model that streamed in late still works. With 10 droppers at 2 drops per second that is 20 cheap lookups per second; cache per dropper if your chain is huge.
- `CanQuery`, `CanTouch` and `CanCollide` are all off, and `CastShadow` too. A visual drop must cost the physics and shadow systems nothing.
- With [[Instance Streaming]] on, other plots' `Built` children may not exist on this client. The loop simply skips missing pieces, which is also the correct visual behaviour.
- The cosmetic "+$" pop at the collector belongs here too. It must read `Income` from the plot attribute and never claim a number the server did not pay.

---

## 7. Numbers worth knowing

| Quantity | Value | Source |
|---|---|---|
| Server work per tick | One loop over at most 8 plots, a few additions each | Negligible; measure with the [[MicroProfiler Guide]] |
| Replication per tick | Two attributes per player per second | Tiny compared with replicating physical drops |
| Visual drops on one client | At most 40 per nearby plot, pooled | Rule of thumb; on low-end phones lower it to 15 |
| Offline cap | 2 hours at 50% | Rule of thumb; long caps devalue playing, short caps feel stingy |
| Physical dropper parts the old way | 8 plots x 15 droppers x 1/s, each living 8 s = about 960 live parts | Arithmetic; this is the "dropper trap" from the playbook |

---

## 8. Extending it

- **Upgraders that multiply drops.** Model them as income multipliers on the server (`Income` of the upgrader button can be a percentage applied in `recomputeIncome`) and as a colour change on the client drops passing through. The client never decides value.
- **Game pass "2x cash".** Multiply in `recomputeIncome` using a cached ownership check, refreshed on `PromptGamePassPurchaseFinished` ([[Shop with Game Passes and Developer Products End to End]], [[Game Passes]]).
- **Build animations for new purchases only.** The rebuild is silent; animate in `buyAsync` by tweening parts up from below with a client effect ([[Tween and CFrame Animation of Objects]]).
- **Visiting and locked doors.** A door that only lets the owner and friends in is a server collision group plus a client check for feel. Remember griefing is mostly about blocking pads; pads only react to the owner, so open plots are safer than they look.

---

## 9. Test checklist

- [ ] Solo Play: plot assigned, character moved, first pad free, buy it, income starts, collector pays.
- [ ] Two clients: each gets a different plot; neither can collect or buy on the other's plot.
- [ ] Leave and rejoin: base rebuilt in one frame, offline earnings shown, cash and pending intact.
- [ ] Set `Max Players` above plot count in a local server test with more clients than plots: extra player is a visitor, nothing errors.
- [ ] Rename an id and add it to `Renamed`; load an old save: the purchase survives. Remove an id: refund applied.
- [ ] Fire `TycoonBuy` with a number, a 10 KB string, an unknown id and a locked id from the command bar of a client: nothing happens, no errors in the server output ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]]).
- [ ] MicroProfiler on a full server at max chain: no physics spikes from drops; client frame time stable on a phone emulator.
- [ ] Shutdown test: `BindToClose` saves `Pending` written by the last tick.

## See also
- [[Genre Playbook - Tycoons]], [[Genre Systems Start Here]], [[Worked Builds Start Here]]
- [[Saved Inventory End to End]], [[Rebirth and Prestige System End to End]], [[Session Locking and Profile Libraries]]
- [[Economy Inflation Sinks and Faucets Math]], [[Progression and Pacing Design]], [[Physics Performance]]

## Connected notes
<!-- auto-links:start -->
[[Core Loop]] · [[Power Curve]] · [[Genre Playbook - Survival and Crafting]] · [[Pricing Curves and Upgrade Costs]] · [[Economies and Currencies]] · [[Case Study - Steal a Brainrot]]
<!-- auto-links:end -->
