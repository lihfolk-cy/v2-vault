---
tags: [worked-build, pets, eggs, rng, inventory, datastore, ui, luau, simulators]
---
# Pet Hatching and Following End to End

This note builds the pet system that most simulators and collection games share, from an empty place: eggs in the world with odds shown above them, server-side hatching with weighted random rolls, a saved pet inventory with unique ids, equip and unequip with a cap, an "equip best" button, a passive income boost from equipped pets, and pets that follow every player smoothly, rendered on each client so the server never simulates them.

Theory lives elsewhere: [[RNG Drops and Luck Systems]] and [[Rarity Ladders and Drop Pacing Math]] for the odds, [[Genre Playbook - Simulators]] and [[Simulator and RNG Genre Teardown]] for why pets matter, [[Tools and Inventory Systems]] for inventory design. This note is the wiring. See [[Worked Builds Start Here]] for the rest of the folder, and [[Saved Inventory End to End]] for a general item inventory.

> **All code in this note is reviewed, not run.** It follows Roblox docs (as of October 2026) and was checked by reading. Run the tests in section 8 before shipping.

Labels: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. Design decisions

| Question | Choice | Why |
|---|---|---|
| Who rolls the pet | Server, with `Random.new()` | A client roll is a client choice. Never let the client pick, seed or "confirm" a result |
| How a hatch is requested | A `ProximityPrompt` on the egg, handled in `Triggered` on the server | No custom remote to secure for the most valuable action; the server still re-checks distance |
| How pets are stored | Dictionary `Pets[uid] = { Kind = "Dog" }`, uids are strings like `"p17"` | Unique ids make equip, delete and later trading unambiguous; string keys survive JSON |
| How other clients learn what you equipped | One attribute on the Player: `EquippedPets = "Dog,Cat"` | Replicates to everyone, late joiners get it free, tiny bandwidth |
| How pets move | Each client renders all pets locally, anchored, moved every frame | Zero physics, zero network ownership issues, smooth at any ping |
| Where odds live | `PetConfig` in `ReplicatedStorage` | The odds shown on screen come from the same table the server rolls from, so they cannot drift |

**When not to client-render:** pets that must physically interact on the server (blocking doors, being hit) need server-owned models. Cosmetic followers do not (rule of thumb).

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    PetConfig (ModuleScript)
  PetModels (Folder)
    Dog, Cat, Bunny, Dragon (Models, each with a PrimaryPart)
  PetRemotes (Folder, created by the server)
    Equip, EquipBest, Delete (RemoteEvents, client to server)
    Inventory, HatchResult (RemoteEvents, server to client)

ServerScriptService
  Modules (Folder)
    PlayerStore (ModuleScript)
    RateLimit (ModuleScript)
  PetService (Script)

Workspace
  Eggs (Folder)
    BasicEgg (Model, name must match a PetConfig.Eggs key)
      ProximityPrompt (inside the egg's PrimaryPart)

StarterGui
  PetGui (ScreenGui, ResetOnSpawn = false)
    Inventory (Frame)
      Grid (ScrollingFrame with UIGridLayout)
      Template (TextButton, Visible = false)
      EquipBest (TextButton)
      DeleteMode (TextButton)
    Reveal (Frame, Visible = false)
      PetName (TextLabel)
      Rarity (TextLabel)
    Notice (TextLabel)

StarterPlayer
  StarterPlayerScripts
    PetFollowClient (LocalScript)
    PetUIClient (LocalScript)
```

Pet model rules: a few parts or one MeshPart, a `PrimaryPart`, pivot at the bottom centre. Part count matters: 30 players with 3 pets is 90 models moved every frame on every client (see [[Art Budgets - Triangles Draw Calls Memory]]).

Enable **Game Settings > Security > Enable Studio Access to API Services** for save tests.

---

## 3. Shared config

```lua
--!strict
-- ReplicatedStorage/Shared/PetConfig (ModuleScript). Reviewed, not run.
export type PetDef = {
	Name: string,
	Rarity: string,
	Power: number,   -- % income boost while equipped
	Flying: boolean, -- flying pets bob in the air, walking pets snap to the ground
}

export type OddsEntry = { Pet: string, Weight: number }

export type EggDef = {
	Name: string,
	Price: number,
	Odds: { OddsEntry },
}

local Pets: { [string]: PetDef } = {
	Dog = { Name = "Dog", Rarity = "Common", Power = 5, Flying = false },
	Cat = { Name = "Cat", Rarity = "Uncommon", Power = 10, Flying = false },
	Bunny = { Name = "Bunny", Rarity = "Rare", Power = 25, Flying = false },
	Dragon = { Name = "Dragon", Rarity = "Legendary", Power = 100, Flying = true },
}

local Eggs: { [string]: EggDef } = {
	BasicEgg = {
		Name = "Basic Egg",
		Price = 100,
		Odds = {
			{ Pet = "Dog", Weight = 60 },
			{ Pet = "Cat", Weight = 30 },
			{ Pet = "Bunny", Weight = 9 },
			{ Pet = "Dragon", Weight = 1 },
		},
	},
}

local RarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(70, 140, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
}

local PetConfig = {
	Pets = Pets,
	Eggs = Eggs,
	RarityColors = RarityColors,
	MaxEquipped = 3,
	MaxInventory = 60,
	HatchCooldown = 0.6, -- seconds between hatches per player
	HatchRange = 14,     -- studs from the egg pivot
	StartingCoins = 500,
}

-- Odds as percentages, for display. Same table the server rolls from.
function PetConfig.OddsPercent(egg: EggDef): { { pet: string, percent: number } }
	local total = 0
	for _, entry in egg.Odds do
		total += entry.Weight
	end
	local out = {}
	for _, entry in egg.Odds do
		table.insert(out, { pet = entry.Pet, percent = entry.Weight / total * 100 })
	end
	return out
end

return PetConfig
```

Weights rather than percentages: adding a pet is one line, not a rebalance to 100. Always display the derived percentages, never hand-typed ones.

---

## 4. Server modules: PlayerStore and RateLimit

`PlayerStore` is the same module used by every saving build in this folder: load with a session lock, reconcile with a template, autosave, save on leave and shutdown, kick on load failure. The reasoning is in [[Round-Based Minigame Loop End to End]] section 4 and in [[Saving Correctly - Autosave and BindToClose]].

```lua
--!strict
-- ServerScriptService/Modules/PlayerStore (ModuleScript). Reviewed, not run.
-- One record per player, simple session lock, autosave, save on leave and shutdown.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Data = { [string]: any }

-- A separate store in Studio so tests never touch live player data.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio_v1" else "PlayerData_v1"
local AUTOSAVE_SECONDS = 120
local LOCK_STALE_SECONDS = 300 -- a lock older than this is treated as abandoned (crashed server)

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Data } = {}
local template: Data = {}
local started = false
local loadedCallbacks: { (Player) -> () } = {}

local PlayerStore = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function keyFor(player: Player): string
	return "u_" .. tostring(player.UserId)
end

-- Reads the record and claims the lock in one UpdateAsync.
local function loadAsync(player: Player): Data?
	for attempt = 1, 5 do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(old: any)
				lockedElsewhere = false
				local record = if type(old) == "table" then old else {}
				local lock = record._lock
				if type(lock) == "table" and lock.job ~= game.JobId
					and os.time() - (tonumber(lock.time) or 0) < LOCK_STALE_SECONDS then
					lockedElsewhere = true
					return nil -- cancel the write: another live server still owns this record
				end
				record._lock = { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and not lockedElsewhere and type(result) == "table" then
			return result :: Data
		end
		if not ok then
			warn(`PlayerStore load failed for {player.UserId} (attempt {attempt}): {result}`)
		end
		if not player.Parent then
			return nil
		end
		task.wait(attempt * 3)
	end
	return nil
end

local function saveAsync(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data then
		return true
	end
	local snapshot = deepCopy(data)
	snapshot._lock = if release then nil else { job = game.JobId, time = os.time() }
	for attempt = 1, 4 do
		local stolen = false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old: any)
				stolen = false
				if type(old) == "table" and type(old._lock) == "table" and old._lock.job ~= game.JobId then
					stolen = true
					return nil -- another server took over; never overwrite its newer data
				end
				return snapshot
			end)
		end)
		if ok then
			if stolen then
				warn(`PlayerStore: record for {player.UserId} is locked elsewhere, save skipped`)
			end
			return not stolen
		end
		warn(`PlayerStore save failed for {player.UserId} (attempt {attempt}): {err}`)
		task.wait(attempt * 2)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local record = loadAsync(player)
	if not record then
		if player.Parent then
			player:Kick("Your data could not be loaded. Please rejoin in a minute.")
		end
		return
	end
	for key, value in template do
		if record[key] == nil then
			record[key] = deepCopy(value)
		end
	end
	profiles[player] = record
	if not player.Parent then
		-- Left while we were loading: release the lock we just took.
		saveAsync(player, true)
		profiles[player] = nil
		return
	end
	player:SetAttribute("DataLoaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveAsync(player, true)
		profiles[player] = nil
	end
end

function PlayerStore.Start(newTemplate: Data)
	assert(not started, "PlayerStore.Start called twice")
	started = true
	template = newTemplate
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveAsync(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25 -- BindToClose gets about 30 s in total (Roblox docs)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(saveAsync, player, false)
				task.wait(1) -- spread requests so one autosave tick does not burst the budget
			end
		end
	end)
end

-- Callbacks get the Player only; read the live table with Get.
function PlayerStore.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

function PlayerStore.Get(player: Player): Data?
	return profiles[player]
end

-- For high-value moments (a rebirth, a rare hatch). Do not call every frame.
function PlayerStore.SaveNow(player: Player)
	task.spawn(saveAsync, player, false)
end

return PlayerStore
```

`RateLimit` is a token bucket per player. Use it on every client-to-server remote that changes state.

```lua
--!strict
-- ServerScriptService/Modules/RateLimit (ModuleScript). Reviewed, not run.
-- newLimiter(capacity, refillPerSecond) returns allow(player) -> boolean.
local Players = game:GetService("Players")

local function newLimiter(capacity: number, refillPerSecond: number): (Player) -> boolean
	local buckets: { [Player]: { tokens: number, at: number } } = {}
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player] or { tokens = capacity, at = now }
		buckets[player] = bucket
		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.at) * refillPerSecond)
		bucket.at = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end
end

return newLimiter
```

---

## 5. PetService (server)

```lua
--!strict
-- ServerScriptService/PetService (Script). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PetConfig = require(ReplicatedStorage.Shared.PetConfig)
local PlayerStore = require(ServerScriptService.Modules.PlayerStore)
local newLimiter = require(ServerScriptService.Modules.RateLimit)

local rng = Random.new()

type Pet = { Kind: string }

PlayerStore.Start({
	Coins = PetConfig.StartingCoins,
	Pets = {},       -- [uid] = { Kind = "Dog" }
	Equipped = {},   -- array of uids, at most MaxEquipped
	NextPetId = 1,   -- never reused, so a deleted uid can never come back
})

---------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "PetRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local equipRemote = remote("Equip")
local equipBestRemote = remote("EquipBest")
local deleteRemote = remote("Delete")
local inventoryRemote = remote("Inventory")
local hatchResultRemote = remote("HatchResult")
remotes.Parent = ReplicatedStorage

local equipAllowed = newLimiter(8, 4)   -- bursts of 8, then 4 per second
local deleteAllowed = newLimiter(10, 5)

---------------------------------------------------------------- helpers
local function countPets(data: PlayerStore.Data): number
	local n = 0
	for _ in data.Pets do
		n += 1
	end
	return n
end

local function sendInventory(player: Player)
	local data = PlayerStore.Get(player)
	if data then
		-- Remotes copy the tables, so the client can never touch the server's copy.
		inventoryRemote:FireClient(player, data.Pets, data.Equipped)
	end
end

local function equippedPower(data: PlayerStore.Data): number
	local power = 0
	for _, uid in data.Equipped do
		local pet = data.Pets[uid] :: Pet?
		local def = pet and PetConfig.Pets[pet.Kind]
		if def then
			power += def.Power
		end
	end
	return power
end

local function publishEquipped(player: Player, data: PlayerStore.Data)
	local kinds: { string } = {}
	for _, uid in data.Equipped do
		local pet = data.Pets[uid] :: Pet?
		if pet and PetConfig.Pets[pet.Kind] then
			table.insert(kinds, pet.Kind)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(kinds, ","))
	player:SetAttribute("PetPower", equippedPower(data))
end

local function setCoins(player: Player, data: PlayerStore.Data)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value = data.Coins
	end
end

local function rollPet(egg: PetConfig.EggDef): string
	local total = 0
	for _, entry in egg.Odds do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in egg.Odds do
		roll -= entry.Weight
		if roll < 0 then
			return entry.Pet
		end
	end
	return egg.Odds[#egg.Odds].Pet -- floating point safety net
end

---------------------------------------------------------------- join
PlayerStore.OnLoaded(function(player: Player)
	local data = PlayerStore.Get(player)
	if not data then
		return
	end
	-- Hygiene: drop equipped uids that no longer exist and duplicates.
	-- Never delete a pet whose Kind is missing from config: a config typo would wipe inventories.
	local clean: { string } = {}
	for _, uid in data.Equipped do
		if typeof(uid) == "string" and data.Pets[uid] and not table.find(clean, uid)
			and #clean < PetConfig.MaxEquipped then
			table.insert(clean, uid)
		end
	end
	data.Equipped = clean

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats
	leaderstats.Parent = player

	publishEquipped(player, data)
	sendInventory(player)
end)

---------------------------------------------------------------- hatching
local lastHatch: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	lastHatch[player] = nil
end)

local function notice(player: Player, message: string)
	hatchResultRemote:FireClient(player, nil, message)
end

local function hatch(player: Player, eggModel: Model)
	local egg = PetConfig.Eggs[eggModel.Name]
	local data = PlayerStore.Get(player)
	if not egg or not data then
		return
	end

	local now = os.clock()
	if now - (lastHatch[player] or 0) < PetConfig.HatchCooldown then
		return
	end

	-- Re-check distance on the server; do not trust the prompt alone.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - eggModel:GetPivot().Position).Magnitude > PetConfig.HatchRange then
		return
	end

	if countPets(data) >= PetConfig.MaxInventory then
		notice(player, "Your pet inventory is full")
		return
	end
	if data.Coins < egg.Price then
		notice(player, `You need {egg.Price - data.Coins} more coins`)
		return
	end

	-- From the checks above to the end of the write there is no yield,
	-- so two hatch requests in the same frame cannot both pass the coin check.
	lastHatch[player] = now
	data.Coins -= egg.Price
	local kind = rollPet(egg)
	local uid = "p" .. tostring(data.NextPetId)
	data.NextPetId += 1
	data.Pets[uid] = { Kind = kind }

	setCoins(player, data)
	sendInventory(player)
	hatchResultRemote:FireClient(player, kind, nil)

	local def = PetConfig.Pets[kind]
	if def and def.Rarity == "Legendary" then
		PlayerStore.SaveNow(player) -- a rare result is worth an early save
	end
end

local eggsFolder = workspace:WaitForChild("Eggs")
local function hookEgg(eggModel: Instance)
	if not eggModel:IsA("Model") then
		return
	end
	local prompt = eggModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		warn(`Egg {eggModel.Name} has no ProximityPrompt`)
		return
	end
	local egg = PetConfig.Eggs[eggModel.Name]
	if egg then
		prompt.ActionText = "Hatch"
		prompt.ObjectText = `{egg.Name} ({egg.Price} coins)`
	end
	prompt.Triggered:Connect(function(player: Player)
		hatch(player, eggModel)
	end)
end
for _, eggModel in eggsFolder:GetChildren() do
	hookEgg(eggModel)
end
eggsFolder.ChildAdded:Connect(hookEgg)

---------------------------------------------------------------- equip, equip best, delete
equipRemote.OnServerEvent:Connect(function(player: Player, uid: unknown, equip: unknown)
	if not equipAllowed(player) then
		return
	end
	if typeof(uid) ~= "string" or #uid > 24 or typeof(equip) ~= "boolean" then
		return
	end
	local data = PlayerStore.Get(player)
	if not data then
		return
	end
	local pet = data.Pets[uid] :: Pet?
	if not pet then
		return -- not yours, or already deleted
	end
	local index = table.find(data.Equipped, uid)
	if equip then
		if index or #data.Equipped >= PetConfig.MaxEquipped or not PetConfig.Pets[pet.Kind] then
			return
		end
		table.insert(data.Equipped, uid)
	else
		if not index then
			return
		end
		table.remove(data.Equipped, index)
	end
	publishEquipped(player, data)
	sendInventory(player)
end)

equipBestRemote.OnServerEvent:Connect(function(player: Player)
	if not equipAllowed(player) then
		return
	end
	local data = PlayerStore.Get(player)
	if not data then
		return
	end
	local candidates: { { uid: string, power: number } } = {}
	for uid, pet in data.Pets do
		local def = PetConfig.Pets[(pet :: Pet).Kind]
		if def then
			table.insert(candidates, { uid = uid, power = def.Power })
		end
	end
	table.sort(candidates, function(a, b)
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.uid < b.uid -- stable tie-break so repeated clicks do not shuffle pets
	end)
	local best: { string } = {}
	for i = 1, math.min(PetConfig.MaxEquipped, #candidates) do
		table.insert(best, candidates[i].uid)
	end
	data.Equipped = best
	publishEquipped(player, data)
	sendInventory(player)
end)

deleteRemote.OnServerEvent:Connect(function(player: Player, uid: unknown)
	if not deleteAllowed(player) then
		return
	end
	if typeof(uid) ~= "string" or #uid > 24 then
		return
	end
	local data = PlayerStore.Get(player)
	if not data or not data.Pets[uid] then
		return
	end
	local index = table.find(data.Equipped, uid)
	if index then
		table.remove(data.Equipped, index)
	end
	data.Pets[uid] = nil
	publishEquipped(player, data)
	sendInventory(player)
end)

---------------------------------------------------------------- passive income (what pets are for)
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in Players:GetPlayers() do
			local data = PlayerStore.Get(player)
			if data then
				local multiplier = 1 + equippedPower(data) / 100
				data.Coins += math.floor(10 * multiplier)
				setCoins(player, data)
			end
		end
	end
end)
```

Three details that matter more than they look:
- **`NextPetId` never goes down**, so a stale "equip p12" sent after p12 was deleted can never hit a different pet.
- **`IntValue` holds whole numbers only** (64-bit, Roblox docs); fractional coins are truncated. For huge economies see [[Rebirth and Prestige System End to End]] section 3.
- **Remotes copy tables**, so the client can edit its copy of `Pets` freely.

If eggs (or the coins that buy them) can be bought with Robux, you are selling paid random items: odds disclosure and regional restrictions apply. Read [[Paid Random Items and Odds Disclosure in Practice]] and check `PolicyService:GetPolicyInfoForPlayerAsync` (field `ArePaidRandomItemsRestricted`, Roblox docs) before you add a Robux egg.

---

## 6. Following pets (client)

Each client renders every player's pets. The server only publishes `EquippedPets` strings.

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/PetFollowClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetConfig"))
local petModels = ReplicatedStorage:WaitForChild("PetModels")

local RADIUS = 6           -- studs behind the owner
local SPREAD = 0.8         -- radians between pets in the arc
local FOLLOW_SHARPNESS = 10
local SNAP_DISTANCE = 60   -- teleported owner: snap instead of gliding across the map
local CULL_DISTANCE = 220  -- hide pets far from the camera

type Rendered = {
	model: Model,
	flying: boolean,
	halfHeight: number,
	current: CFrame?,
	phase: number,
}

local container = Instance.new("Folder")
container.Name = "ClientPets"
container.Parent = workspace

local rendered: { [Player]: { Rendered } } = {}
local hidden: { [Player]: boolean } = {}

local function prepare(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false -- keeps pets out of everyone's raycasts
			d.CanTouch = false
			d.Massless = true
		end
	end
end

local function clear(player: Player)
	local list = rendered[player]
	if list then
		for _, r in list do
			r.model:Destroy()
		end
	end
	rendered[player] = nil
	hidden[player] = nil
end

local function build(player: Player)
	clear(player)
	local value = player:GetAttribute("EquippedPets")
	if typeof(value) ~= "string" or value == "" then
		return
	end
	local list: { Rendered } = {}
	for i, kind in string.split(value, ",") do
		local def = PetConfig.Pets[kind]
		local source = petModels:FindFirstChild(kind)
		if def and source and source:IsA("Model") then
			local model = source:Clone()
			prepare(model)
			model.Parent = container
			table.insert(list, {
				model = model,
				flying = def.Flying,
				halfHeight = model:GetExtentsSize().Y / 2,
				current = nil,
				phase = i * 1.7, -- desync the bobbing so pets do not move in lockstep
			})
		end
	end
	rendered[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		build(player)
	end)
	build(player)
end

for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)

-- Ground rays ignore pets and characters. Characters change, so refresh once a second.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
task.spawn(function()
	while true do
		local ignore: { Instance } = { container }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		rayParams.FilterDescendantsInstances = ignore
		task.wait(1)
	end
end)

RunService.PreRender:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPos = camera.CFrame.Position
	local alpha = 1 - math.exp(-FOLLOW_SHARPNESS * dt) -- frame-rate independent smoothing
	local t = os.clock()

	for player, list in rendered do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local far = not root or (root.Position - cameraPos).Magnitude > CULL_DISTANCE
		if far ~= (hidden[player] == true) then
			hidden[player] = far
			for _, r in list do
				r.model.Parent = if far then nil else container
				r.current = nil -- snap when shown again
			end
		end
		if far or not root then
			continue
		end

		local count = #list
		for i, r in list do
			local angle = (i - (count + 1) / 2) * SPREAD
			-- +Z in the root's object space is behind the character.
			local offset = Vector3.new(math.sin(angle) * RADIUS, 0, math.cos(angle) * RADIUS)
			local goalPos = root.CFrame:PointToWorldSpace(offset)

			if r.flying then
				goalPos = Vector3.new(goalPos.X, root.Position.Y + 2 + math.sin(t * 2 + r.phase) * 0.6, goalPos.Z)
			else
				local hit = workspace:Raycast(goalPos + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
				local groundY = if hit then hit.Position.Y else root.Position.Y - 3
				goalPos = Vector3.new(goalPos.X, groundY + r.halfHeight, goalPos.Z)
			end

			local look = root.CFrame.LookVector
			local goal = CFrame.lookAt(goalPos, goalPos + Vector3.new(look.X, 0, look.Z))
			local current = r.current
			if not current or (current.Position - goalPos).Magnitude > SNAP_DISTANCE then
				current = goal
			else
				current = current:Lerp(goal, alpha)
			end
			r.current = current
			r.model:PivotTo(current)
		end
	end
end)
```

Why each piece is there:
- **`1 - math.exp(-k * dt)` instead of a fixed lerp factor.** A fixed `0.2` per frame follows twice as fast at 120 FPS as at 60 FPS. The exponential form is frame-rate independent (see [[Springs Damping and Smoothing]]).
- **Snap distance.** Without it, a player who teleports drags their pets across the whole map in a visible streak.
- **Culling by parenting to nil**, done only when the state flips, never every frame. Reparenting is not free.
- **One raycast per walking pet per frame.** For 90 pets that is 90 short rays, cheap in practice (rule of thumb). If profiling says otherwise, raycast every third frame and reuse the last ground height (see [[MicroProfiler Guide]]).
- **`PreRender`** fires every frame before rendering, so pets move at display frame rate rather than physics rate.

---

## 7. Inventory and hatch UI (client)

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/PetUIClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetConfig"))
local remotes = ReplicatedStorage:WaitForChild("PetRemotes")
local equipRemote = remotes:WaitForChild("Equip") :: RemoteEvent
local equipBestRemote = remotes:WaitForChild("EquipBest") :: RemoteEvent
local deleteRemote = remotes:WaitForChild("Delete") :: RemoteEvent
local inventoryRemote = remotes:WaitForChild("Inventory") :: RemoteEvent
local hatchResultRemote = remotes:WaitForChild("HatchResult") :: RemoteEvent

local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PetGui") :: ScreenGui
local inventory = gui:WaitForChild("Inventory") :: Frame
local grid = inventory:WaitForChild("Grid") :: ScrollingFrame
local template = inventory:WaitForChild("Template") :: TextButton
local equipBestButton = inventory:WaitForChild("EquipBest") :: TextButton
local deleteModeButton = inventory:WaitForChild("DeleteMode") :: TextButton
local reveal = gui:WaitForChild("Reveal") :: Frame
local revealName = reveal:WaitForChild("PetName") :: TextLabel
local revealRarity = reveal:WaitForChild("Rarity") :: TextLabel
local noticeLabel = gui:WaitForChild("Notice") :: TextLabel

local deleteMode = false

local function render(pets: { [string]: { Kind: string } }, equipped: { string })
	for _, child in grid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	-- Sort: equipped first, then by power, then uid, so the grid does not jump around.
	local uids: { string } = {}
	for uid in pets do
		table.insert(uids, uid)
	end
	local function power(uid: string): number
		local def = PetConfig.Pets[pets[uid].Kind]
		return if def then def.Power else 0
	end
	table.sort(uids, function(a, b)
		local ea, eb = table.find(equipped, a) ~= nil, table.find(equipped, b) ~= nil
		if ea ~= eb then
			return ea
		end
		if power(a) ~= power(b) then
			return power(a) > power(b)
		end
		return a < b
	end)
	for order, uid in uids do
		local kind = pets[uid].Kind
		local def = PetConfig.Pets[kind]
		local isEquipped = table.find(equipped, uid) ~= nil
		local button = template:Clone()
		button.Name = uid
		button.LayoutOrder = order
		button.Visible = true
		button.Text = (if isEquipped then "[E] " else "") .. (if def then def.Name else kind)
		button.BackgroundColor3 = if def then PetConfig.RarityColors[def.Rarity] or Color3.new(1, 1, 1)
			else Color3.new(0.4, 0.4, 0.4)
		button.Activated:Connect(function()
			if deleteMode then
				deleteRemote:FireServer(uid)
			else
				equipRemote:FireServer(uid, not isEquipped)
			end
		end)
		button.Parent = grid
	end
end

inventoryRemote.OnClientEvent:Connect(render)

equipBestButton.Activated:Connect(function()
	equipBestRemote:FireServer()
end)

deleteModeButton.Activated:Connect(function()
	deleteMode = not deleteMode
	deleteModeButton.Text = if deleteMode then "Delete: ON" else "Delete: OFF"
end)

hatchResultRemote.OnClientEvent:Connect(function(kind: string?, message: string?)
	if message then
		noticeLabel.Text = message
		noticeLabel.Visible = true
		task.delay(2, function()
			if noticeLabel.Text == message then
				noticeLabel.Visible = false
			end
		end)
		return
	end
	local def = kind and PetConfig.Pets[kind]
	if not def then
		return
	end
	revealName.Text = def.Name
	revealRarity.Text = def.Rarity
	revealRarity.TextColor3 = PetConfig.RarityColors[def.Rarity] or Color3.new(1, 1, 1)
	reveal.Size = UDim2.fromScale(0, 0)
	reveal.Visible = true
	TweenService:Create(reveal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.3, 0.3) }):Play()
	task.delay(2, function()
		reveal.Visible = false
	end)
end)

-- Odds above each egg, built from the same table the server rolls from.
local eggsFolder = workspace:WaitForChild("Eggs")
local function labelEgg(eggModel: Instance)
	if not eggModel:IsA("Model") then
		return
	end
	local egg = PetConfig.Eggs[eggModel.Name]
	if not egg then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 90)
	board.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 60
	board.Adornee = eggModel.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	local lines: { string } = { egg.Name }
	for _, entry in PetConfig.OddsPercent(egg) do
		table.insert(lines, string.format("%s  %.1f%%", entry.pet, entry.percent))
	end
	label.Text = table.concat(lines, "\n")
	label.Parent = board
	board.Parent = gui -- parented to PlayerGui so it stays client-side; Adornee places it
end
for _, eggModel in eggsFolder:GetChildren() do
	labelEgg(eggModel)
end
eggsFolder.ChildAdded:Connect(labelEgg)
```

UI notes: `Grid` uses a `UIGridLayout` sorted by `LayoutOrder`. Past roughly 200 entries, rebuilding every button hitches on phones; use [[Virtualized Lists and Large Inventories]]. Delete mode is a toggle because per-pet delete buttons get pressed by accident on phones.

---

## 8. Testing in Studio

1. **First join.** Play. Coins show 500. Walk to the egg, hold the prompt. A reveal pops up, coins drop by 100, the inventory shows one pet.
2. **Odds sanity.** Copy `rollPet` into the server command bar, call it 10,000 times on `BasicEgg` and count the results: expect roughly Dog 6,000, Cat 3,000, Bunny 900, Dragon 100. A big deviation means a bug in the loop, not bad luck.
3. **Following.** Equip three pets. Walk, jump, climb stairs. Walking pets hug the ground, the Dragon floats. Move your character far away with the Move tool in the server view: pets snap, not streak.
4. **Two clients.** Test > Clients and Servers, 2 players. Each must see the other's pets. Have player 2 join after player 1 equipped: player 2 must still see them.
5. **Abuse from the command bar** (client view):
   - `game.ReplicatedStorage.PetRemotes.Equip:FireServer("p999", true)` (not owned): no change.
   - `...Equip:FireServer({}, "yes")`: ignored.
   - Equip the same uid 10 times in a loop: equipped count never exceeds 3, no duplicates.
   - `...Delete:FireServer(string.rep("a", 1e5))`: ignored.
   - Fire `Equip` 500 times in one loop: the rate limiter drops most; the server stays responsive.
6. **Range check.** Exploit tools can trigger prompts from far away, which you cannot reproduce exactly in Studio. Simulate it: temporarily set `MaxActivationDistance = 500` on the prompt and press it from 50 studs away. The server must refuse (no coins spent). Put the value back afterwards.
7. **Persistence.** Hatch a few pets, equip two, stop, play again. Same pets, same equipped set.

---

## 9. Exploits it must resist

| Attack | Defence here |
|---|---|
| Choosing the hatch result | Roll happens only on the server |
| Hatching from across the map | Server distance check, independent of the prompt's own range |
| Hatch spam / double spend in one frame | Cooldown plus no yield between check and spend |
| Equipping pets you do not own | Lookup in the server's `data.Pets` by uid |
| Equipping more than the cap, or the same pet twice | `#Equipped` check and `table.find` |
| Equipping a pet by Kind name to "spawn" it | The client only ever sends uids; kinds come from server data |
| Remote spam, bad types, giant strings | Token bucket per remote; `typeof` and length checks first |
| Duplication by server hopping | PlayerStore session lock (and for trading, see [[Trading Systems Without Duplication]]) |

More in [[Economy Exploits - Dupes Races and Purchase Abuse]] and [[Threat Modeling a Roblox Game]].

---

## 10. Common mistakes

- **Server-side pet models with `AlignPosition`.** Each pet becomes a physics assembly with ownership churn and visible jitter.
- **Storing pets as an array of kinds.** "Delete the third Dog" is ambiguous. Use uids.
- **Numeric table keys in saved data.** A sparse numeric table (`{[1]=..., [5]=...}`) does not survive JSON the way you expect. String uids avoid it (see [[Data Schema Design and Migrations]]).
- **Hand-typed odds labels** that drift from the table after a rebalance.
- **Deleting data for unknown pet kinds at load.** A renamed pet in config would wipe everyone's copies. Keep the data; just do not render it.

---

## 11. Extending it

- **Triple hatch / auto hatch.** Loop the roll server-side with the same checks, and gate it behind a game pass (see [[Shop with Game Passes and Developer Products End to End]]).
- **Pet levels and fusing.** Add `Level` and `Xp` to each pet record; fusing deletes N uids and creates one, all in one synchronous server function.
- **Shiny variants.** A second roll after the pet roll (`Shiny = rng:NextNumber() < 0.01`); render with a `Highlight` or a material swap on the client.
- **Pity timers.** Track hatches since last Rare per egg in data; force a Rare at N. Explain it in the odds UI (see [[Rarity Ladders and Drop Pacing Math]]).
- **Bulk moving.** For huge pet counts, move all pet parts with `workspace:BulkMoveTo` (Roblox docs).

---

## 12. Checklist

- [ ] Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart
- [ ] Every pet Kind in odds tables has a model in `ReplicatedStorage.PetModels`
- [ ] Odds labels come from `PetConfig.OddsPercent`
- [ ] Rolls only on the server; no yields between coin check and spend
- [ ] Equip, delete and equip-best are rate limited and type checked
- [ ] Pets render on clients, culled by distance, smoothing is frame-rate independent
- [ ] Robux-purchasable eggs reviewed against the paid random items policy
- [ ] Persistence, two-client and abuse tests pass

## See also
[[Worked Builds Start Here]] · [[RNG Drops and Luck Systems]] · [[Rarity Ladders and Drop Pacing Math]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Genre Playbook - Simulators]] · [[Saved Inventory End to End]] · [[Rebirth and Prestige System End to End]] · [[Springs Damping and Smoothing]]

## Nuances and edge cases

1. **Follower cost grows with players times pets.** With 3 equipped pets each, 50 players is 150 pets that every client moves every frame; with 6 each and 100 players it is 600. Moving anchored parts is cheap, but per-pet raycasts for ground height, per-pet tweens and per-pet animation add up on phones. Update only pets within a radius every frame, update far pets at a lower rate or hide them, and batch moves with `workspace:BulkMoveTo` (Roblox docs, as of October 2026).
2. **Streaming and other players' pets.** With instance streaming on, a far player's character may not exist on your client. Pet code that waits for that character, or errors when it is missing, either leaks waiting threads or spams errors. Treat a missing character as "do not render this player's pets" and react when it streams in.
3. **Paid eggs are paid random items.** If an egg can be opened with Robux, directly or through a currency bought with Robux, it falls under Roblox's paid random items rules: odds must be shown before purchase, and some players are restricted from buying them, which `PolicyService:GetPolicyInfoForPlayerAsync` reports via `ArePaidRandomItemsRestricted` (Roblox docs, as of October 2026). Design the egg flow so restricted players have a non-random path or see the paid egg disabled.
4. **Inventory size and save size.** A pet record is small, but heavy players hatch thousands. Without a cap or a bulk-delete option, saves grow without bound and the inventory UI struggles. Set a storage cap (with paid or earned expansions if you like) and virtualize the list.
5. **Odds changes are player-visible events.** Lowering a rare pet's odds after launch is noticed and resented, and may need to be disclosed. Treat odds as a versioned part of the config; changing them should be a deliberate decision with patch notes.
6. **Rolling many at once.** Triple or auto hatch multiplies the server work per request and the reward rate. Auto hatch that runs while a player is away turns hatching into an idle faucet; check its effect on the economy, and keep the same rate limits per roll as manual hatching.
7. **Pity timers and per-egg state.** A pity counter per egg per player is extra saved state. If eggs are replaced each season, decide whether pity carries over; players notice when progress toward a guaranteed rare disappears.
8. **Trading changes everything.** The moment pets are tradeable, the uid design, session locking and server-side ownership checks stop being nice-to-have. Duplication bugs in tradeable pets damage the whole economy, not one player.

## More common mistakes

1. **Pets visible only to their owner.** Symptom: other players never see pets, removing the social reason to hatch. Fix: the replicated `EquippedPets` attribute and rendering for everyone, as built here.
2. **Per-pet `RenderStepped` connections.** Symptom: connection count grows with every pet and leaks when pets are unequipped. Fix: one loop for all pets, a table of active pets.
3. **No odds disclosure for paid eggs.** Symptom: policy risk and player distrust. Fix: show odds from the roll table before purchase and gate via PolicyService.
4. **Pets that clip into walls and floors.** Symptom: pets vanish into terrain on slopes. Fix: a cheap downward raycast at a lower rate, or a fixed height offset from the owner.
5. **Huge pet models.** Symptom: frame drops in busy hubs. Fix: a triangle budget per pet and a lower-detail version for far pets.
6. **Hatch animation blocks input.** Symptom: players cannot cancel or skip and stop hatching in bulk. Fix: a skippable animation and a fast mode.

## Related decisions

- [[Drop Tables Rarity and Pity Systems]]: designing the odds and pity rules for eggs.
- [[Paid Random Items and Odds Disclosure in Practice]]: the rules when eggs cost Robux.
- [[Player-Driven Trading Economies]]: what changes once pets can be traded.
- [[Instance Streaming]]: handling pets of players who are streamed out.
- [[Reward Moments and Celebrations]]: making the hatch reveal feel good.
- [[Chibi Character Rules in Practice]]: designing pets that read as cute in the follow camera.
- [[Virtualized Lists and Large Inventories]]: inventory UI for thousands of pets.
- [[Case Study - Pet Simulator 99]]: how a top pet game structures hatching and rarities.
- [[Ethical Design and Player Trust]]: keeping random rewards fair and transparent.

## Connected notes
<!-- auto-links:start -->
[[Pity Timer]] · [[Case Study - Adopt Me]] · [[Roblox Policies Ratings and Compliance]] · [[Expected Value]] · [[Genre Playbook - RNG and Collection Games]] · [[Economy Design Start Here]]
<!-- auto-links:end -->
