---
tags: [luau, cookbook, players, characters, humanoid, recipes]
---
# Cookbook - Players and Characters

Short, self-contained recipes for the player and character code every game writes. Each recipe gives the problem, the code, why it works, and the pitfall that bites people. All code is `--!strict` Luau using modern APIs (`task.*`, `PivotTo`, attributes). It is reviewed, not run: paste it into a fresh place and test it before you build on it. For the reasoning behind these patterns read [[Characters and Humanoids]], [[Humanoid States and Animation]], [[Custom Characters and StarterCharacter]] and [[Events Signals and Connections]].

Sourcing labels: "Roblox docs (as of October 2026)" for engine facts, "rule of thumb" for judgement calls.

---

## 1. Run setup for every player, including ones already in the server

**Problem.** `Players.PlayerAdded:Connect(...)` misses players who joined before your script connected. In Studio solo testing this happens often, because the local player can exist before a server script that yields at the top gets to `Connect`.

```lua
--!strict
local Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
	print("setting up", player.Name)
	-- create leaderstats, load data, etc.
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
```

**Why it works.** Connecting first and then looping over `GetPlayers()` covers both cases. `task.spawn` runs each existing player's setup in its own thread so one slow `GetAsync` does not hold up the others.

**Pitfall.** If you loop first and connect second, a player who joins between the two lines is skipped. Connect first. The reverse edge case also exists: a player who joins after `Connect` but before the loop reads `GetPlayers()` gets both the event and the loop. If setup must never run twice, guard it with a `done[player] = true` check (rule of thumb).

---

## 2. Run code every time a character spawns

**Problem.** Characters are destroyed and recreated on every respawn. Code that grabs `player.Character` once stops working after the first death.

```lua
--!strict
local Players = game:GetService("Players")

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		warn("no Humanoid in", character:GetFullName())
		return
	end
	humanoid.WalkSpeed = 20
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
```

**Why it works.** `CharacterAdded` fires for each new character model. The extra `player.Character` check handles a character that already exists. `WaitForChild` with a timeout returns `nil` instead of hanging forever, and the `IsA` check narrows the type for strict mode.

**Pitfall.** `CharacterAdded` fires before every part has replicated or loaded (Roblox docs (as of October 2026) recommend waiting for `Player.CharacterAppearanceLoaded` if you need accessories). Never assume `HumanoidRootPart` exists at the top of the handler: wait for it too.

---

## 3. Keep per-player state and clean it up on leave

**Problem.** Tables keyed by player grow forever if you forget to remove leavers, and connections made per player keep running after they leave.

```lua
--!strict
local Players = game:GetService("Players")

type PlayerState = {
	coins: number,
	connections: { RBXScriptConnection },
}

local states: { [Player]: PlayerState } = {}

Players.PlayerAdded:Connect(function(player: Player)
	local state: PlayerState = { coins = 0, connections = {} }
	states[player] = state
	table.insert(state.connections, player.CharacterAdded:Connect(function(character: Model)
		print(player.Name, "spawned", character.Name)
	end))
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, connection in state.connections do
		connection:Disconnect()
	end
	states[player] = nil
end)
```

**Why it works.** One table owns all per-player data. `PlayerRemoving` fires while the `Player` object is still valid, so you can read its state and save it before dropping the reference.

**Pitfall.** Connections on the `Player` instance itself are disconnected when the instance is destroyed, but connections on other objects (a shared `Heartbeat`, a part in Workspace) are not. Track those explicitly. If you save data here, do the save before setting `states[player] = nil`, and see [[Saving Correctly - Autosave and BindToClose]] for the shutdown case.

---

## 4. Get the local character safely on the client

**Problem.** In a `LocalScript`, `Players.LocalPlayer.Character` can be `nil` when the script starts and changes on every respawn.

```lua
--!strict
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function getRoot(): BasePart?
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local root = getRoot()
if root then
	print("root at", root.Position)
end
```

**Why it works.** `player.Character or player.CharacterAdded:Wait()` returns immediately if a character exists and yields for the next one otherwise.

**Pitfall.** Caching `root` in a module-level variable is the classic respawn bug: after death it points at a destroyed part. Either call `getRoot()` when you need it or refresh it in a `CharacterAdded` handler (recipe 2). With [[Instance Streaming]] on, parts far from the player may not exist on the client at all; the character itself is always streamed to its owner.

---

## 5. Find the player who touched or was hit by something

**Problem.** A `Touched` event or raycast gives you a part (a hand, an accessory handle), not a player.

```lua
--!strict
local Players = game:GetService("Players")

local function playerFromPart(part: BasePart): (Player?, Humanoid?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return Players:GetPlayerFromCharacter(model), humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

local pad = workspace:WaitForChild("Pad") :: BasePart
pad.Touched:Connect(function(hit: BasePart)
	local player, humanoid = playerFromPart(hit)
	if player and humanoid and humanoid.Health > 0 then
		print(player.Name, "stepped on the pad")
	end
end)
```

**Why it works.** Accessory handles sit inside an `Accessory` inside the character, so `hit.Parent` is not always the character. Walking up `Model` ancestors until one has a `Humanoid` finds the character whatever was touched. `GetPlayerFromCharacter` returns `nil` for NPCs, which also tells you what you hit.

**Pitfall.** `Touched` fires many times per contact (each limb, each physics step it re-touches). Add a per-player debounce, and do not use `Touched` for combat hit detection: see [[Hitboxes and Hit Detection]] and [[Raycasts Shapecasts and Spatial Queries]].

---

## 6. Teleport a character inside the place

**Problem.** Setting `HumanoidRootPart.Position` moves only that part and can tear joints; setting it on the client gets overwritten or is exploitable.

```lua
--!strict
local function teleportCharacter(character: Model, target: CFrame)
	-- Lift slightly so feet do not spawn inside the floor.
	character:PivotTo(target + Vector3.new(0, 3, 0))
end

-- Server usage:
local Players = game:GetService("Players")
local spawnPart = workspace:WaitForChild("ArenaSpawn") :: BasePart
for _, player in Players:GetPlayers() do
	local character = player.Character
	if character then
		teleportCharacter(character, spawnPart.CFrame)
	end
end
```

**Why it works.** `Model:PivotTo` moves the whole model rigidly around its pivot (the root part for characters), keeping joints intact (Roblox docs (as of October 2026)). Doing it on the server makes the move authoritative; the owning client picks up the new position.

**Pitfall.** The player's client owns its character's physics ([[Network Ownership]]), so a teleport can be "undone" for a frame or two by a stale client update, which looks like rubber-banding. Teleport, then briefly ignore movement checks for that player in your anti-cheat ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]). Keep the velocity from carrying through by zeroing `AssemblyLinearVelocity` on the root if needed.

---

## 7. Stack speed modifiers without them overwriting each other

**Problem.** A slow debuff sets `WalkSpeed = 8`, a sprint sets `WalkSpeed = 24`, and whichever ends last leaves the wrong value.

```lua
--!strict
local BASE_SPEED = 16

local modifiers: { [Humanoid]: { [string]: number } } = {}

local function recompute(humanoid: Humanoid)
	local multiplier = 1
	for _, value in modifiers[humanoid] or {} do
		multiplier *= value
	end
	humanoid.WalkSpeed = BASE_SPEED * multiplier
end

local function setModifier(humanoid: Humanoid, id: string, value: number?)
	local list = modifiers[humanoid]
	if not list then
		list = {}
		modifiers[humanoid] = list
		humanoid.Destroying:Connect(function()
			modifiers[humanoid] = nil
		end)
	end
	list[id] = value
	recompute(humanoid)
end

-- setModifier(h, "Sprint", 1.5); later setModifier(h, "Sprint", nil)
```

**Why it works.** Every effect writes into its own slot and the final speed is always recomputed from the base. Removing a slot cannot clobber another effect.

**Pitfall.** The client also writes `WalkSpeed` for its own character and those writes do not replicate to the server, so the server cannot rely on its own `WalkSpeed` value as proof of how fast the client moves. Validate actual movement instead. For full rules on stacking see [[Status Effects Buffs and Stacking Rules]].

---

## 8. Control respawning yourself

**Problem.** Round-based games need players to stay dead until the next round, or to respawn at a chosen point.

```lua
--!strict
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false

local function spawnPlayer(player: Player)
	if player.Parent ~= Players then
		return -- left the game
	end
	player:LoadCharacter()
end

Players.PlayerAdded:Connect(function(player: Player)
	spawnPlayer(player)
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Once(function()
				task.delay(5, spawnPlayer, player)
			end)
		end
	end)
end)
```

**Why it works.** With `CharacterAutoLoads` off, nothing spawns until you call `LoadCharacter` on the server. `Died:Once` disconnects itself after the first fire.

**Pitfall.** `LoadCharacter` yields and must run on the server. After `task.delay`, the player may have left: the `player.Parent` check stops an error. If you leave `CharacterAutoLoads` on, `Players.RespawnTime` controls the default delay instead. Round structure is covered in [[Spawning Teams and Rounds]].

---

## 9. React to death exactly once

**Problem.** Checking `Health <= 0` in `HealthChanged` fires repeatedly, and damage dealt after death can trigger rewards twice.

```lua
--!strict
local function watchDeath(humanoid: Humanoid, onDeath: () -> ())
	local fired = false
	humanoid.Died:Connect(function()
		if fired then
			return
		end
		fired = true
		onDeath()
	end)
end
```

**Why it works.** `Died` fires when the humanoid enters the `Dead` state. The flag protects against your own code calling `ChangeState(Enum.HumanoidStateType.Dead)` on an already dead humanoid.

**Pitfall.** Grant kill credit in your damage function, not in `Died`: by the time `Died` fires you no longer know who dealt the last hit unless you stored it. Store the last attacker (and a timestamp) as you apply damage, then read it in the death handler. Also note `Humanoid.BreakJointsOnDeath` (default true) makes the body fall apart; set it false if you ragdoll ([[Ragdolls and Physics-Based Animation]]).

---

## 10. Turn off player-player collisions

**Problem.** Players block doorways and push each other off ledges.

```lua
--!strict
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP = "Players"
PhysicsService:RegisterCollisionGroup(GROUP)
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

local function setGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = GROUP
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		for _, d in character:GetDescendants() do
			setGroup(d)
		end
		character.DescendantAdded:Connect(setGroup)
	end)
end)
```

**Why it works.** Parts in the same collision group that is set non-collidable with itself pass through each other but still collide with the world. `DescendantAdded` catches accessories and tools that arrive after spawn.

**Pitfall.** Registering collision groups at runtime is supported, but there is a limit on the number of groups (Roblox docs (as of October 2026) state 32; check the current value). Register groups once at server start, never per player.

---

## 11. Disable the reset button

**Problem.** Players reset to escape a trap or skip a cooldown.

```lua
--!strict
-- LocalScript in StarterPlayerScripts
local StarterGui = game:GetService("StarterGui")

for _ = 1, 10 do
	local ok = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	if ok then
		break
	end
	task.wait(0.5)
end
```

**Why it works.** `SetCore("ResetButtonCallback", false)` disables the menu's reset option. The retry loop exists because `SetCore` errors if the core scripts have not registered that setting yet, which is common in the first frames.

**Pitfall.** This is a client setting: an exploiter can still kill their own character. Never treat "they cannot reset" as a security guarantee; the server must handle any death at any time.

---

## 12. Apply an outfit to a character

**Problem.** You want a uniform for a team or to load a player's own avatar onto an NPC.

```lua
--!strict
local Players = game:GetService("Players")

local function dressAsUser(humanoid: Humanoid, userId: number): boolean
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not ok or not description then
		return false
	end
	local applied = pcall(function()
		humanoid:ApplyDescription(description)
	end)
	return applied
end
```

**Why it works.** A `HumanoidDescription` is the data form of an outfit. `GetHumanoidDescriptionFromUserId` is a web call, so it yields and can fail: hence `pcall`. `ApplyDescription` then loads the assets onto the rig.

**Pitfall.** `ApplyDescription` must be called on the server for player characters, and it yields while assets load. Calling it on many NPCs at once spikes memory and bandwidth; stagger it. For outfit editing at scale, change one field on a cloned description rather than building a new one from scratch.

---

## Common mistakes across these recipes

- Assuming a character, humanoid or root part exists without waiting for it.
- Caching character parts across respawns.
- Trusting client-side character properties (`WalkSpeed`, `Health` set locally) as server truth.
- Forgetting cleanup in `PlayerRemoving`, which leaks memory over long servers ([[Hunting Memory Leaks Step by Step]]).

## Checklist

- [ ] Every `PlayerAdded` handler also loops `GetPlayers()`.
- [ ] Every `CharacterAdded` handler also handles an existing character.
- [ ] Every `WaitForChild` that may never resolve has a timeout.
- [ ] Per-player tables are cleared on `PlayerRemoving`.
- [ ] Teleports use `PivotTo` on the server.
- [ ] Rewards come from the damage function, not from `Died` alone.

## See also

[[Luau Cookbook Start Here]], [[Characters and Humanoids]], [[Custom Character Controllers]], [[Spawning Teams and Rounds]], [[Network Ownership]], [[Server Authority and Validation]], [[Cookbook - Remotes and Networking]], [[Cookbook - Math CFrame and Vectors]]

## Nuances and edge cases

1. **Characters load in pieces.** `CharacterAdded` fires when the model exists, not when every part, accessory and the Animator are ready. Accessories and layered clothing can arrive later, especially on slower devices. Wait for the specific child you need, with a timeout, and treat "not found in time" as a handled case, not an error.
2. **Respawn timing and old references.** A respawn creates a completely new character. Any connection or reference to the old Humanoid keeps the old model in memory until disconnected. Store per-character state in a table keyed by the character, and clean it up on `Humanoid.Died` or when the character is removed.
3. **Network ownership of the character.** Each player's client simulates its own character. The server's view of position lags by the player's ping. Teleporting a character from the server works, but the client may briefly fight it if it has already moved. Use `PivotTo` on the character from the server and accept a tiny correction; for frequent moves, ask the client to do it and validate.
4. **Speed stacking with many sources.** The modifier pattern prevents overwrites, but with many systems (buffs, zones, equipment, slows), the order of multiply versus add changes results. Define one formula (for example: base, then additive bonuses, then multipliers, then caps) and apply it in one place. Clamp to a maximum so stacking cannot break movement validation.
5. **Death exactly once, at scale.** In crowded fights, several damage sources can bring health to zero in the same frame, each one thinking it caused the kill. Award kills from the Died handler (once), using the last recorded attacker, not from inside each damage call.
6. **Player-player collisions and physics.** Collision groups stop players from pushing each other, but players can still stand on each other's heads unless the groups exclude that too. Test the ways players will abuse being able to stand or not stand on each other.
7. **Avatar diversity.** Players have different body heights, proportions and scales. A doorway, seat, hitbox or camera offset tuned on the default avatar can fail for very tall or very small avatars. Either constrain avatar scales for gameplay, or test with the extreme sizes.
8. **R6 versus R15.** Some experiences allow both. Code that looks for `UpperTorso` breaks on R6, and code that looks for `Torso` breaks on R15. Use `HumanoidRootPart` and `Humanoid` where possible, and pick one rig type unless you truly need both.
9. **700-player servers.** Large servers multiply every per-character cost: a script per character, a Heartbeat loop per character, or a remote per character per frame. Prefer one manager that loops over characters to one script inside each.

## More common mistakes

1. **`player.Character` used before it exists.** Symptom: errors on join for fast-loading scripts. Fix: `player.Character or player.CharacterAdded:Wait()`.
2. **Setting WalkSpeed directly from several systems.** Symptom: a slow ends and the player keeps a sprint speed, or the reverse. Fix: the modifier stack, one writer.
3. **Kill credit inside the damage function.** Symptom: double kill awards in crowded fights. Fix: award once from Died.
4. **Not handling `LoadCharacter` with auto-respawn on.** Symptom: double characters or skipped respawn logic. Fix: disable auto-respawn when you control respawning.
5. **Hard-coded part names for both rigs.** Symptom: features work on R15 only. Fix: one rig type, or rig-neutral code.
6. **Teleporting without unseating.** Symptom: a teleported player drags a vehicle or seat with them. Fix: unseat (set `Sit` false or remove the weld) before moving.
7. **Applying outfits on the client.** Symptom: other players see the default outfit. Fix: apply HumanoidDescription on the server.

## Related decisions

- [[Spawn Points Safe Zones and Respawn Flow]]: the design side of controlled respawns.
- [[HumanoidDescription and Outfit Systems]]: outfits beyond the basic recipe.
- [[Avatar Body Types and Scale in Gameplay]]: why tuning on one avatar size fails.
- [[Status Effects Buffs and Stacking Rules]]: the formula behind speed modifiers.
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]: why speed caps and server checks matter.
- [[Humanoid States and Animation]]: how states interact with death and seating.
- [[Debugging Physics and Network Ownership]]: diagnosing character jitter after server moves.
- [[Memory Budgets and Leaks]]: per-character references that leak across respawns.
- [[Combat Systems Architecture]]: where kill credit and damage sources are recorded.

## Connected notes
<!-- auto-links:start -->
[[Debugging Race Conditions and Yield Order]] · [[Links - Humanoids and character controllers]] · [[Cookbook - Data and Saving]] · [[Obby Checkpoints and Stage Saves End to End]] · [[Links - Checkpoints and spawning]] · [[Round-Based Minigame Loop End to End]]
<!-- auto-links:end -->
