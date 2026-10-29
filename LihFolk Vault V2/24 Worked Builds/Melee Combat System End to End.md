---
tags: [worked-build, combat, melee, hitboxes, server-authority, anti-exploit, luau, animation]
---
# Melee Combat System End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Damage in a `Touched` handler on the blade.
> - Avoid: Sending damage from the client. `Attack:FireServer(target, 50)` is an invitation.
> - Avoid: Scripts inside the Tool. Every player gets a copy; fixes need to touch every copy; checks get duplicated and drift.
> - Tool has no scripts; Tool name matches a `CombatConfig.Weapons` key
> - Animations are owned by you or your group and set to Action priority
> - Client sends only "attack" and "block(bool)"
>
> Cost: TL;DR ~160 tok · whole note ~8.0k tok. Read more: ## 5. CombatService (server) · ## 6. CombatClient (client) · ## 10. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

This note builds a server-authoritative sword combat system from an empty place: a `Tool` with no scripts inside it, a three-hit combo with a windup, server-side box hitboxes with line-of-sight checks, blocking that only works from the front, hit stun, knockback that respects network ownership, kill credit for quests, and client feedback (animations, hit sound, damage numbers). It is deliberately the simplest design that is safe; section 9 explains where and how to go further.

Background reading: [[Combat Systems Architecture]] (the big picture), [[Hitboxes and Hit Detection]] (every hitbox technique), [[Client Prediction and Reconciliation for Combat]] (the latency problem), [[Combat Combo Systems]] and [[Weapon Swing Design]] (feel), and [[Detecting Combat Exploits - Reach Rate and Aim]] (what cheaters try). Other builds: [[Worked Builds Start Here]].

> **All code in this note is reviewed, not run.** Written against Roblox docs (as of October 2026) and checked by reading. Use section 8 to test it, ideally with simulated latency.

Labels: **Roblox docs (as of October 2026)**, **rule of thumb**.

---

## 1. Design decisions

| Question | Choice here | Why, and the trade-off |
|---|---|---|
| Who decides a hit | The server, with its own hitbox query | Cheaters cannot invent hits. Cost: on high ping, hits that looked good on screen can miss |
| What the client sends | "I swung" (no targets, no positions, no damage) | Nothing to validate except timing and state |
| Who plays the swing animation | The attacker's client, immediately | Instant feel; animations played on the owner's `Animator` replicate to others (Roblox docs) |
| Where combat logic lives | One server Script and one LocalScript, not scripts inside the Tool | One place to secure, one place to tune, no per-player script copies |
| How knockback moves players | The server asks the target's client to apply it | The target's client owns its character physics, so a server impulse on it is unreliable (see [[Network Ownership]]) |
| How state is shared | Attributes on the character (`Blocking`, `StunnedUntil`) | Visible to every client for UI and VFX, written only by the server |

When **not** to use pure server hitboxes: fast competitive PvP where players expect what they see to count (fighting games, battlegrounds). There you want client-detected hits with server validation; section 9 shows the shape of it. For PvE and casual PvP, server hitboxes plus a slightly generous box are the better trade (rule of thumb).

---

## 2. Folder layout

```
ReplicatedStorage
  Shared (Folder)
    CombatConfig (ModuleScript)
  CombatRemotes (Folder, created by the server)
    Attack (RemoteEvent, client to server)
    Block (RemoteEvent, client to server)
    HitConfirm (RemoteEvent, server to attacker)
    Knockback (RemoteEvent, server to target)
  CombatAssets (Folder)
    Swing1, Swing2, Swing3, Block (Animation objects)
    HitSound (Sound)

ServerScriptService
  Modules (Folder)
    RateLimit (ModuleScript)
  CombatService (Script)

StarterPack
  Sword (Tool, RequiresHandle = true, CanBeDropped = false)
    Handle (Part or MeshPart)

Workspace
  Dummy (R15 rig from the Rig Builder, attribute TrainingDummy = true)

StarterPlayer
  StarterPlayerScripts
    CombatClient (LocalScript)
```

The Animation objects need real animation ids that your account or group owns; the placeholders in this note (`rbxassetid://0000000000`) will not play. See [[Animation Asset Permissions and Groups]] and [[Publishing Animations]]. Set their priority to `Action` (see [[Playback, Priorities and Blending]]).

---

## 3. Shared config

```lua
--!strict
-- ReplicatedStorage/Shared/CombatConfig (ModuleScript). Reviewed, not run.
export type WeaponDef = {
	Damage: { number },     -- one entry per combo step
	Cooldown: number,       -- min seconds between swings inside a combo
	ComboWindow: number,    -- swing again within this many seconds to continue the combo
	FinisherRecovery: number, -- extra lockout after the last combo step
	Windup: number,         -- seconds from swing start to the hit check
	HitboxSize: Vector3,
	HitboxForward: number,  -- studs in front of the root where the box is centred
	Knockback: number,      -- studs per second given to the target
	StunTime: number,       -- seconds the target cannot attack
	Animations: { string }, -- names in ReplicatedStorage.CombatAssets, one per step
}

local Weapons: { [string]: WeaponDef } = {
	Sword = {
		Damage = { 10, 10, 18 },
		Cooldown = 0.35,
		ComboWindow = 0.9,
		FinisherRecovery = 0.6,
		Windup = 0.15,
		HitboxSize = Vector3.new(6, 5, 6),
		HitboxForward = 3.5,
		Knockback = 30,
		StunTime = 0.4,
		Animations = { "Swing1", "Swing2", "Swing3" },
	},
}

local CombatConfig = {
	Weapons = Weapons,
	Block = {
		DamageMultiplier = 0.3, -- blocked hits deal 30%
		FrontDot = 0.2,         -- attacker must be in front of the blocker (dot of look vectors)
		WalkSpeed = 8,
		MinHold = 0.3,          -- a block lasts at least this long once raised
	},
	FriendlyFire = false,
	CooldownTolerance = 0.06, -- seconds; absorbs network jitter between swings
	DefaultWalkSpeed = 16,
}

return CombatConfig
```

The numbers are starting points, not truth. Windup of 0.1 to 0.2 seconds gives the animation time to read and gives the server a little time to see the target where the attacker saw it (rule of thumb). Combo pacing and finisher weight are covered in [[Combat Combo Systems]].

---

## 4. RateLimit

The same per-player token bucket as the other builds:

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

Combat does not save anything, so there is no `PlayerStore` here. If you add saved kills or XP, use the module from [[Round-Based Minigame Loop End to End]] section 4.

---

## 5. CombatService (server)

```lua
--!strict
-- ServerScriptService/CombatService (Script). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local newLimiter = require(ServerScriptService.Modules.RateLimit)

---------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "CombatRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local attackRemote = remote("Attack")
local blockRemote = remote("Block")
local hitConfirmRemote = remote("HitConfirm")
local knockbackRemote = remote("Knockback")
remotes.Parent = ReplicatedStorage

-- Generous enough for a fast legit clicker, far below an exploit loop.
local attackAllowed = newLimiter(4, 6)
local blockAllowed = newLimiter(4, 4)

---------------------------------------------------------------- per-player state
type CombatState = {
	combo: number,
	lastSwing: number,
	nextAllowed: number,
	blocking: boolean,
	blockStartedAt: number,
	blockReleaseQueued: boolean,
}

local states: { [Player]: CombatState } = {}

local function freshState(): CombatState
	return {
		combo = 0,
		lastSwing = -math.huge,
		nextAllowed = 0,
		blocking = false,
		blockStartedAt = 0,
		blockReleaseQueued = false,
	}
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
-- Per-player wiring (creating states, resets on respawn) is at the end of the script,
-- after setBlocking exists.

---------------------------------------------------------------- helpers
type Living = { model: Model, humanoid: Humanoid, root: BasePart }

local function living(model: Instance?): Living?
	if not model or not model:IsA("Model") then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return { model = model, humanoid = humanoid, root = root }
end

local function equippedWeapon(character: Model): (string?, CombatConfig.WeaponDef?)
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, nil
	end
	local def = CombatConfig.Weapons[tool.Name]
	if not def then
		return nil, nil
	end
	return tool.Name, def
end

local function isStunned(model: Model): boolean
	local untilTime = model:GetAttribute("StunnedUntil")
	return typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function sameTeam(a: Player, b: Player): boolean
	return not a.Neutral and not b.Neutral and a.Team ~= nil and a.Team == b.Team
end

local function setBlocking(player: Player, character: Model, on: boolean)
	local state = states[player]
	if not state then
		return
	end
	state.blocking = on
	state.blockReleaseQueued = false
	character:SetAttribute("Blocking", on)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Note: the owning client controls its own movement, so an exploiter can
		-- ignore this slowdown. It is a feel rule, not a security rule.
		humanoid.WalkSpeed = if on then CombatConfig.Block.WalkSpeed else CombatConfig.DefaultWalkSpeed
	end
	if on then
		state.blockStartedAt = os.clock()
	end
end

-- Walls between attacker and target cancel the hit.
local function hasLineOfSight(from: BasePart, to: BasePart, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local direction = to.Position - from.Position
	local result = workspace:Raycast(from.Position, direction, params)
	return result == nil
end

local function applyKnockback(attackerRoot: BasePart, target: Living, speed: number)
	local flat = target.root.Position - attackerRoot.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	if flat.Magnitude < 0.01 then
		flat = attackerRoot.CFrame.LookVector
	end
	local velocity = flat.Unit * speed + Vector3.new(0, speed * 0.3, 0)
	local targetPlayer = Players:GetPlayerFromCharacter(target.model)
	if targetPlayer then
		-- The target's client owns its character physics, so ask it to apply the push.
		knockbackRemote:FireClient(targetPlayer, velocity)
	elseif target.root:GetNetworkOwner() == nil then
		-- Server-owned NPC: we can push it directly.
		target.root:ApplyImpulse(velocity * target.root.AssemblyMass)
	end
end

---------------------------------------------------------------- the hit
local function resolveHit(attacker: Player, weaponName: string, def: CombatConfig.WeaponDef, step: number)
	-- Re-validate after the windup: the attacker may have died, been stunned or unequipped.
	local self = living(attacker.Character)
	if not self or isStunned(self.model) then
		return
	end
	local currentName = equippedWeapon(self.model)
	if currentName ~= weaponName then
		return
	end

	local boxCFrame = self.root.CFrame * CFrame.new(0, 0, -def.HitboxForward)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { self.model }
	local parts = workspace:GetPartBoundsInBox(boxCFrame, def.HitboxSize, overlap)

	local hitModels: { [Model]: boolean } = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not hitModels[model] then
			hitModels[model] = true
			local target = living(model)
			if not target then
				continue
			end
			local targetPlayer = Players:GetPlayerFromCharacter(target.model)
			if targetPlayer and not CombatConfig.FriendlyFire and sameTeam(attacker, targetPlayer) then
				continue
			end
			if not hasLineOfSight(self.root, target.root, { self.model, target.model }) then
				continue
			end

			local damage = def.Damage[step]
			local blocked = false
			if target.model:GetAttribute("Blocking") == true then
				-- Block only works if the attacker is in front of the blocker.
				local toAttacker = (self.root.Position - target.root.Position).Unit
				if target.root.CFrame.LookVector:Dot(toAttacker) > CombatConfig.Block.FrontDot then
					blocked = true
					damage *= CombatConfig.Block.DamageMultiplier
				end
			end

			-- TakeDamage respects ForceFields (Roblox docs), so spawn protection just works.
			target.humanoid:TakeDamage(damage)
			target.model:SetAttribute("LastAttackerId", attacker.UserId)
			target.model:SetAttribute("LastAttackedAt", os.clock())

			if not blocked then
				target.model:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + def.StunTime)
				applyKnockback(self.root, target, def.Knockback * (if step == #def.Damage then 1.6 else 1))
			end

			hitConfirmRemote:FireClient(attacker, target.model, damage, blocked)
		end
	end
end

---------------------------------------------------------------- attack request
attackRemote.OnServerEvent:Connect(function(player: Player)
	if not attackAllowed(player) then
		return
	end
	local state = states[player]
	local self = living(player.Character)
	if not state or not self then
		return
	end
	if state.blocking or isStunned(self.model) then
		return
	end
	local weaponName, def = equippedWeapon(self.model)
	if not weaponName or not def then
		return
	end

	local now = os.clock()
	if now < state.nextAllowed - CombatConfig.CooldownTolerance then
		return -- too early: autoclicker or exploit; drop silently
	end

	-- Continue the combo if inside the window, otherwise start over.
	if now - state.lastSwing <= def.ComboWindow and state.combo < #def.Damage then
		state.combo += 1
	else
		state.combo = 1
	end
	state.lastSwing = now
	state.nextAllowed = now + def.Cooldown
		+ (if state.combo == #def.Damage then def.FinisherRecovery else 0)

	local step = state.combo
	self.model:SetAttribute("ComboStep", step) -- other clients can use this for trails or VFX
	task.delay(def.Windup, resolveHit, player, weaponName, def, step)
end)

---------------------------------------------------------------- block request
blockRemote.OnServerEvent:Connect(function(player: Player, wantBlock: unknown)
	if not blockAllowed(player) or typeof(wantBlock) ~= "boolean" then
		return
	end
	local state = states[player]
	local self = living(player.Character)
	if not state or not self then
		return
	end
	if wantBlock then
		local weaponName = equippedWeapon(self.model)
		if weaponName and not isStunned(self.model) and not state.blocking then
			setBlocking(player, self.model, true)
		end
		return
	end
	if not state.blocking or state.blockReleaseQueued then
		return
	end
	-- Enforce a minimum hold so tapping block exactly on each hit is not free.
	local held = os.clock() - state.blockStartedAt
	local remaining = CombatConfig.Block.MinHold - held
	if remaining <= 0 then
		setBlocking(player, self.model, false)
	else
		state.blockReleaseQueued = true
		local character = self.model
		task.delay(remaining, function()
			if states[player] == state and state.blocking and character.Parent then
				setBlocking(player, character, false)
			end
		end)
	end
end)

---------------------------------------------------------------- per-player wiring
local function onPlayer(player: Player)
	states[player] = freshState()
	local function onCharacter(character: Model)
		states[player] = freshState() -- a new life resets combos and blocks
		-- Unequipping the weapon drops the block.
		character.ChildRemoved:Connect(function(child)
			local state = states[player]
			if child:IsA("Tool") and state and state.blocking then
				setBlocking(player, character, false)
			end
		end)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

---------------------------------------------------------------- training dummies heal
task.spawn(function()
	while true do
		task.wait(3)
		for _, model in workspace:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("TrainingDummy") then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				local lastHit = model:GetAttribute("LastAttackedAt")
				if humanoid and humanoid.Health > 0
					and (typeof(lastHit) ~= "number" or os.clock() - lastHit > 3) then
					humanoid.Health = humanoid.MaxHealth
				end
			end
		end
	end
end)
```

Why the important lines are there:
- **`nextAllowed` with a tolerance.** Two swings sent 0.35 s apart can arrive 0.30 s apart after network jitter. Without the 0.06 s tolerance, legitimate players on wobbly connections have swings eaten, which reads as "the game is laggy". With a huge tolerance you hand cheaters free speed. 50 to 80 ms is a reasonable band (rule of thumb; see [[False Positives Lag and Fair Enforcement]]).
- **Re-validation after the windup.** Between the swing and the hit, the attacker can die, be stunned, or swap weapons. Not re-checking is how "dead players still deal damage" bugs happen.
- **Dedup by model.** A character has 15 or more parts in the box; without `hitModels` one swing deals damage 15 times.
- **Line of sight.** Box hitboxes pass through walls. One raycast per target is cheap and closes "hit through the door" complaints.
- **Kill-credit attributes** (`LastAttackerId`, `LastAttackedAt`) are what [[Quest Chain System End to End]] reads to credit kills.

---

## 6. CombatClient (client)

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/CombatClient (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))
local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local attackRemote = remotes:WaitForChild("Attack") :: RemoteEvent
local blockRemote = remotes:WaitForChild("Block") :: RemoteEvent
local hitConfirmRemote = remotes:WaitForChild("HitConfirm") :: RemoteEvent
local knockbackRemote = remotes:WaitForChild("Knockback") :: RemoteEvent
local assets = ReplicatedStorage:WaitForChild("CombatAssets")

local player = Players.LocalPlayer
local BLOCK_ACTION = "CombatBlock"

-- Local mirror of the server's timing, only to avoid sending requests the server will drop.
local combo = 0
local lastSwing = -math.huge
local nextAllowed = 0
local blocking = false

local tracks: { [string]: AnimationTrack } = {}

local function loadTracks(character: Model)
	table.clear(tracks)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	for _, child in assets:GetChildren() do
		if child:IsA("Animation") then
			tracks[child.Name] = animator:LoadAnimation(child)
		end
	end
end

local function isStunned(character: Model): boolean
	local untilTime = character:GetAttribute("StunnedUntil")
	return typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function onActivated(tool: Tool)
	local def = CombatConfig.Weapons[tool.Name]
	local character = player.Character
	if not def or not character or blocking or isStunned(character) then
		return
	end
	local now = os.clock()
	if now < nextAllowed then
		return
	end
	if now - lastSwing <= def.ComboWindow and combo < #def.Damage then
		combo += 1
	else
		combo = 1
	end
	lastSwing = now
	nextAllowed = now + def.Cooldown + (if combo == #def.Damage then def.FinisherRecovery else 0)

	-- Predict the animation now; the server decides damage. If the server's combo
	-- step differs (rare, after lag), only the animation choice is off for one swing.
	local track = tracks[def.Animations[combo]]
	if track then
		track:Play(0.05)
	end
	attackRemote:FireServer()
end

local function setBlock(on: boolean)
	if blocking == on then
		return
	end
	blocking = on
	blockRemote:FireServer(on)
	local track = tracks.Block
	if track then
		if on then
			track:Play(0.1)
		else
			track:Stop(0.1)
		end
	end
end

local function blockAction(_name: string, inputState: Enum.UserInputState, _input: InputObject)
	if inputState == Enum.UserInputState.Begin then
		setBlock(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setBlock(false)
	end
	return Enum.ContextActionResult.Sink
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or not CombatConfig.Weapons[tool.Name] then
		return
	end
	tool.Activated:Connect(function()
		onActivated(tool)
	end)
	tool.Equipped:Connect(function()
		-- true = create an on-screen button for touch devices.
		ContextActionService:BindAction(BLOCK_ACTION, blockAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
		ContextActionService:SetTitle(BLOCK_ACTION, "Block")
	end)
	tool.Unequipped:Connect(function()
		ContextActionService:UnbindAction(BLOCK_ACTION)
		setBlock(false)
	end)
end

local function onCharacter(character: Model)
	combo, lastSwing, nextAllowed, blocking = 0, -math.huge, 0, false
	loadTracks(character)
	local backpack = player:WaitForChild("Backpack")
	for _, tool in backpack:GetChildren() do
		hookTool(tool)
	end
	backpack.ChildAdded:Connect(hookTool)
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

---------------------------------------------------------------- feedback
local hitSound = assets:WaitForChild("HitSound") :: Sound

local function damageNumber(target: Model, amount: number, blocked: boolean)
	local adornee = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
	if not adornee or not adornee:IsA("BasePart") then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(80, 40)
	board.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 2, 0)
	board.AlwaysOnTop = true
	board.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = if blocked then `{math.floor(amount)} (blocked)` else tostring(math.floor(amount))
	label.TextColor3 = if blocked then Color3.fromRGB(150, 180, 255) else Color3.fromRGB(255, 230, 90)
	label.Parent = board
	board.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(board, TweenInfo.new(0.6), { StudsOffsetWorldSpace = board.StudsOffsetWorldSpace + Vector3.new(0, 2, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	task.delay(0.7, function()
		board:Destroy()
	end)
end

hitConfirmRemote.OnClientEvent:Connect(function(target: Model?, amount: number, blocked: boolean)
	if not target then
		return -- streamed out
	end
	local sound = hitSound:Clone()
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1 -- slight variation so repeats do not drone
	sound.Parent = target:FindFirstChild("HumanoidRootPart") or workspace
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	damageNumber(target, amount, blocked)
end)

knockbackRemote.OnClientEvent:Connect(function(velocity: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and typeof(velocity) == "Vector3" then
		root:ApplyImpulse(velocity * root.AssemblyMass)
	end
end)
```

UI and input notes:
- **`Tool.Activated`** handles mouse, touch tap and gamepad trigger for you; that is the main reason to use a Tool even with all logic outside it (see [[Tools and Inventory Systems]]).
- **The block action** uses `ContextActionService` with an on-screen touch button. Check its default position on phones against your HUD (see [[Input - UserInputService and ContextActionService]] and [[Responsive UI for Phone Tablet Console and PC]]).
- **Hit feedback** here is a sound and a number. For real weight add hit-stop, camera shake and a flash: [[Hit Reactions Stagger and Hit-Stop]], [[Camera Shake and Camera FX]], [[Combat Sound Design and Feedback]], [[Game Feel and Juice]].

---

## 7. What players on high ping experience

The server checks the box against where it currently believes the target is. That position is the target client's report, already a little old, and the attacker aimed at an interpolated picture that is older still. On a 200 ms connection a strafing target can be several studs from where the attacker saw it (rule of thumb; measure it in your game with [[Network Bandwidth Budgets and Measuring Them]] tools and the Studio network simulation settings).

Mitigations in this build, in order of cost:
1. A box slightly bigger than the sword (6 x 5 x 6 studs for a 4-stud blade).
2. A short windup, which gives the target's position time to catch up.
3. If that is not enough, switch to client-reported hits (section 9). Do not keep enlarging the box: past a point, players get hit by swings that visibly missed, which feels worse than missing.

---

## 8. Testing in Studio

1. **Dummy.** Play, equip the sword, click the dummy three times quickly. Expect numbers 10, 10, 18, a stronger push on the third hit, then a short lockout. The dummy heals 3 seconds after the last hit.
2. **Combo window.** Click, wait one second, click: both hits show 10 (combo restarted).
3. **Walls.** Stand the dummy behind a thin wall and swing into the wall: no damage.
4. **Two players.** Clients and Servers, 2 players. Hit each other, block (F or the touch button) facing the attacker: damage drops to 3, 3, 5.4 (shown floored). Turn your back while blocking: full damage.
5. **Latency.** Studio settings > Network > Incoming Replication Lag, set to 0.2 s (the exact setting name has moved between Studio versions; it is under Studio Settings > Network as of this writing, unverified). Repeat step 4 while strafing. Note how often hits miss, then tune box size.
6. **Abuse** (client command bar, sword equipped):
   - `for i = 1, 100 do game.ReplicatedStorage.CombatRemotes.Attack:FireServer() end` deals at most one or two hits, not a hundred.
   - `game.ReplicatedStorage.CombatRemotes.Block:FireServer("yes")` is ignored.
   - Unequip the sword, fire `Attack`: nothing.
   - Die, then fire `Attack` while dead: nothing.
7. **Kill credit.** With the quest build installed, kill a slime and check the quest count increases.

Profile with many players swinging using [[MicroProfiler Guide]]; `GetPartBoundsInBox` is cheap per call, but 30 players at 3 swings per second is 90 queries plus raycasts per second, which is still small (rule of thumb).

---

## 9. Exploits it must resist, and where it stops

| Attack | Status in this build |
|---|---|
| Inventing hits on far targets (reach) | Blocked: the server computes the box from the server's positions |
| Attack speed hacks | Blocked: server cooldown, combo lockout and rate limiter |
| Hitting through walls | Blocked: line-of-sight raycast |
| Attacking while dead, stunned, blocking or unarmed | Blocked: checked on request and again after windup |
| Teleporting next to a target then swinging ("kill aura") | **Partly.** Each swing is legit-rate, but the teleport is not. You need movement checks: [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] |
| Ignoring the block slowdown | **Not enforceable here.** The client owns its movement; treat block speed as feel, or add speed checks |
| Ignoring knockback | **Not enforceable here** for the same reason. Cosmetic in PvP; if knockback matters to balance, apply it with server-owned constraints or accept it |
| Godmode via client health edits | Blocked: health is server-side; `TakeDamage` runs on the server |
| Spoofed `Blocking` attribute | Blocked: client attribute writes do not replicate |

**Client-reported hits, the next step.** For competitive PvP, let the client run the box query on its own view and send `Attack(targets)`. The server then checks for each target: it exists, is alive, distance between roots is under `HitboxForward + HitboxSize.Z / 2 + latencyAllowance` (for example 4 studs plus target speed times attacker ping), line of sight, and the same timing rules as above. Keep everything else from this build. Details and trade-offs: [[Client Prediction and Reconciliation for Combat]] and [[Detecting Combat Exploits - Reach Rate and Aim]].

---

## 10. Common mistakes

- **Damage in a `Touched` handler on the blade.** Touched depends on physics contacts, fires many times per swing, fires when idle, and runs on the server with whatever position the client reported. It is the source of most "random damage" bugs (see [[Hitboxes and Hit Detection]]).
- **Sending damage from the client.** `Attack:FireServer(target, 50)` is an invitation.
- **Scripts inside the Tool.** Every player gets a copy; fixes need to touch every copy; checks get duplicated and drift.
- **Server `ApplyImpulse` on player characters.** Owned by the client, so it often does nothing; send it to the owner instead.
- **No re-check after windup.** Dead players deal damage; swapped weapons deal the old weapon's damage.
- **Animations on the server.** They replicate, but the attacker sees their own swing a full round trip late.

---

## 11. Extending it

- **More weapons.** Add entries to `CombatConfig.Weapons` with matching Tool names and animations; no code changes.
- **Parry.** If a block started within 0.15 s before the hit landed, reflect stun onto the attacker. Needs the server to judge timing with a tolerance (rule of thumb).
- **Hit markers from animation events.** Fire the hit at a named keyframe marker instead of a fixed windup so timing follows the animation (see [[Markers and Events]] and [[VFX Timing with Animation]]).
- **Status effects** (bleed, slow) on hit: [[Status Effects Buffs and Stacking Rules]].
- **Enemy AI** that uses the same `resolveHit` path: [[NPC AI and Behaviour]].
- **Arenas and rounds.** Combine with [[Round-Based Minigame Loop End to End]] as a "last one standing" minigame.
- **Saved stats.** Kills and XP through the PlayerStore module, levels in [[Rebirth and Prestige System End to End]] style progressions.

---

## 12. Checklist

- [ ] Tool has no scripts; Tool name matches a `CombatConfig.Weapons` key
- [ ] Animations are owned by you or your group and set to Action priority
- [ ] Client sends only "attack" and "block(bool)"
- [ ] Server checks rate, state, weapon, cooldown with tolerance, and re-checks after windup
- [ ] Hits deduplicated by model and gated by line of sight
- [ ] Knockback for players sent to the owner client
- [ ] Kill-credit attributes set on every hit
- [ ] Spam, wall, latency and two-player block tests pass

## See also
[[Worked Builds Start Here]] · [[Combat Systems Architecture]] · [[Hitboxes and Hit Detection]] · [[Client Prediction and Reconciliation for Combat]] · [[Detecting Combat Exploits - Reach Rate and Aim]] · [[Weapon and Combat Animation]] · [[Quest Chain System End to End]]

## Connected notes
<!-- auto-links:start -->
[[Links - Combat]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Hit-Stop]] · [[Anti-Exploit Start Here]] · [[Combat Animation Craft]] · [[Server Authority]]
<!-- auto-links:end -->
