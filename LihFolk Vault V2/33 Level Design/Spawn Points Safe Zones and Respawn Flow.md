---
tags: [level-design, spawning, respawn, safe-zones, fall-recovery, streaming, server-authority, type/guide, area/world, level/intermediate, api/ForceField, area/design]
---
# Spawn Points Safe Zones and Respawn Flow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Auto-load plus a move -> Own loading, or hide the first frame
> - Avoid: Context read at load time -> Record the context at death
> - Avoid: Spawns in the killer's view -> Occupancy check at respawn; alcoves
> - Respawn pipeline written down with a time budget per step.
> - Respawn time chosen for the genre, not left at the default by accident.
> - Contexts defined; context recorded at death on the server.
>
> Cost: TL;DR ~140 tok · whole note ~6.8k tok. Read more: ## 6. Fall recovery · ## 8. A complete respawn service · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

[[Spawning Teams and Rounds]] covers the building blocks: `SpawnLocation` properties, teams, moving a character in `CharacterAdded`, the different respawn contexts in one production game, and round loops. This note treats spawning as a **flow** the player lives through, from the moment of death to the moment they can act again, and as a set of **places** a level designer has to build: spawn spots that make sense, safe zones that cannot be abused, and fall recovery that catches every way out of the map. It ends with a complete server-side respawn service.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (a live action game with a lobby, several areas and a couple of arena modes), **rule of thumb**.

## 1. Respawn is a pipeline

What feels like "you died, you came back" is a chain of steps. Each one can fail, and each one has a time budget.

| Step | What happens | Typical budget (rule of thumb) |
|---|---|---|
| 1. Death detected | Health reaches 0, or your own knock-out state | Instant |
| 2. Death presentation | Animation, "you died" card, killer info | 1 to 3 s |
| 3. Choose the respawn spot | Context rules, occupancy, danger | Instant (server) |
| 4. Stream the destination | Ask the client to load around the spot | 0 to 2 s, overlapped with step 2 |
| 5. Load the character | New character built | Part of the engine's respawn |
| 6. Place and face | Pivot onto the floor, facing something useful | One frame |
| 7. Protect | Shield for a short time | 1.5 to 5 s |
| 8. Reveal | Camera returns, UI returns | 0.5 to 1 s |

The default engine flow does steps 1, 5 and a crude 6 and 7: when `Players.CharacterAutoLoads` is true (the default), characters respawn automatically after `Players.RespawnTime`, which defaults to 5 seconds (Roblox docs, as of October 2026), at a random eligible `SpawnLocation`, with that spawn's [[ForceField]] for `SpawnLocation.Duration` seconds (default 10). Everything else is yours.

Measured in the reference project, a realm death went: topple animation (0.55 s), a white "fizzle" fade-out (0.8 s), a scripted camera glide to a point in front of the respawn spot (1.4 s), then a fizzle back in when the server revived the player (a knock-out of about 4 s), with a 2-second ForceField. PvP deaths used a shorter 3-second knock-out and their own card. The whole flow sat inside the knock-out time, so the presentation hid the wait. That is the main trick: **steps 2 and 4 overlap**, and the presentation is the loading screen.

### Five seconds is long

The default 5-second respawn time is long for an action game and short for a hardcore one. Choose deliberately:

| Game type | Typical respawn (rule of thumb) |
|---|---|
| Obby, platformer | Under 1 s; death is part of play |
| Arena PvP | 2 to 5 s; long enough to break a fight, short enough to rejoin |
| PvE action | 3 to 6 s, covered by a presentation |
| Round-based elimination | Until the round ends (spectate meanwhile) |

For obbies, the respawn wait is the dominant cost of failure, and every extra second multiplies with the expected attempts per stage (see [[Obby and Platforming Level Design]]).

## 2. Owning the respawn: CharacterAutoLoads off

To control timing, spot and presentation precisely, turn off automatic loading and call `Player:LoadCharacterAsync()` yourself. The docs (as of October 2026) say that with `CharacterAutoLoads` false, characters do not spawn until `LoadCharacterAsync` is called for each player, including on join. They also mark `LoadCharacter` as deprecated in favour of `LoadCharacterAsync`, which yields, creates the new character, removes the old one, and clears the player's Backpack and PlayerGui. (ScreenGuis with `ResetOnSpawn` set to false are kept when the character respawns; set that on any HUD that should persist.)

| Approach | For | Against |
|---|---|---|
| Auto-load plus move in `CharacterAdded` | Little code; engine handles timing | The character appears at the default spawn for a moment; timing fixed to `RespawnTime` |
| Auto-load off, `LoadCharacterAsync` yourself | Full control of timing, spot and presentation | You must handle join, death, errors and leaving; a bug means nobody spawns |

The second approach is the one most action games end up with. Its main risk is a player who never spawns, so build a watchdog in from the start (section 6). Measured in the reference project: a respawn watchdog and a safer respawn spot were added specifically to fix players reporting being "stuck on respawn".

## 3. Choosing the spot

### Context first

Decide the context from where and how the player died, then pick within that context. A typical table (the reference project used one like it):

| Context | Respawn at |
|---|---|
| First join, tutorial not done | Tutorial landing |
| First join, returning player | Hub spawn, facing the return portal |
| Death in a realm or zone | The realm's return point or the zone's checkpoint |
| Death in PvP | An arena alcove away from other fighters |
| Death in an event arena | The event's own respawn, or out to the hub if the event ended |
| Fell out of the map | The last safe grounded spot (no death at all, section 5) |

Store the context on the server when the death happens (an attribute or a table entry), not when the character loads. By the time the new character exists, the old one and its position are gone.

### Then safety

Within the context, pick among candidate spots:

- **Not occupied.** Measured in the reference project: a PvP alcove was picked at the moment of death and kept unless another player stood within 24 studs when the respawn happened, in which case another was chosen. Without this, the killer can wait at the spawn.
- **Not threatened.** No enemy within its aggro range of the spot; no hazard in the spawn's first view.
- **Floor present.** Raycast down from above the spot; if nothing solid is found (a map edit removed the floor, or the floor has not streamed), fall back to the context's default.
- **Facing.** Face a global landmark or the next objective, never a wall. The first frame after respawn is when players rebuild their mental map (see [[Level Design Principles - Flow Sightlines and Landmarks]]).

### Spawn placement as level design

Spawn spots are places, so build them like places:

- A small open area (rule of thumb: 12 to 20 studs across per expected simultaneous spawn) with no colliding clutter.
- Out of any combat zone's walk box, and out of PvP sightlines.
- Visible signage or a landmark in the facing direction.
- No ceiling lower than about 3 character heights directly above, so the camera does not start pressed against something.
- Not on a moving part. Characters placed on moving geometry often slide off or spawn into it.

## 4. Protection after spawn

### ForceField

A `ForceField` parented to the character protects from damage dealt through `Humanoid:TakeDamage` (as described in [[Spawning Teams and Rounds]]); damage that sets `Health` directly ignores it. Its `Visible` property hides the bubble effect while keeping the protection. Measured in the reference project:

| Situation | Protection |
|---|---|
| Realm respawn | 2 s ForceField |
| PvP respawn | 2 s ForceField |
| Tutorial knock-out | 3 s ForceField |
| Fall recovery | 1.5 s invisible ForceField |

### Abuse rules

Spawn protection is abused in two ways: players attack from inside it, and players hide in it. Rules of thumb:

- **Attacking ends protection.** When the protected player deals damage, remove their ForceField immediately.
- **Leaving the spawn area ends protection,** if your spawn is a defined area.
- **Your damage pipeline checks protection in one place.** If some abilities call `TakeDamage` and others write `Health`, some ignore the shield. Route all damage through one server function that checks for a ForceField (or your own `Protected` attribute) first. See [[Combat Systems Architecture]] and [[Combat Systems Architecture]].

## 5. Safe zones

A safe zone is an area where players cannot be harmed: the hub, a trading plaza, a shop interior. It sounds like a volume and a flag. In practice it has four edge cases.

1. **Combat logging into the zone.** A player losing a fight runs into the safe zone. Rule: players who dealt or took combat damage in the last N seconds (5 to 10 is common, rule of thumb) do not get protection when entering until the timer runs out.
2. **Attacking out of the zone.** A protected player fires projectiles at players outside. Rule: players inside a safe zone cannot deal damage, or lose protection the moment they do.
3. **Flicker at the edge.** A player standing on the boundary toggles in and out every frame. Rule: hysteresis. Enter when inside the volume; leave only when outside a slightly larger volume (2 to 4 studs bigger).
4. **Enemies at the edge.** Enemies chase a player to the boundary and stand there. Rule: enemies leash and reset when their target enters a safe zone, and enemy walk boxes never overlap safe zones.

Everything about safe zones is decided on the server. The client can draw the boundary and show a "safe" badge, but the damage function must ask the server's view of membership.

```lua
--!strict
-- Server: safe-zone membership with hysteresis and a combat tag.
-- Zones are Parts tagged "SafeZone" (any shape is treated as its bounding box).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local EXIT_MARGIN = 3 -- studs: leave only when this far outside the box
local COMBAT_TAG_SECONDS = 8
local POLL = 0.25

local SafeZones = {}

local inside: { [Player]: boolean } = {}
local lastCombat: { [Player]: number } = {}

local function inBox(part: BasePart, point: Vector3, margin: number): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- Call from your damage pipeline whenever a player deals or takes combat damage.
function SafeZones.markCombat(player: Player)
	lastCombat[player] = os.clock()
end

-- The only question the damage pipeline asks.
function SafeZones.isProtected(player: Player): boolean
	if not inside[player] then return false end
	local t = lastCombat[player]
	return t == nil or os.clock() - t >= COMBAT_TAG_SECONDS
end

local function update(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		inside[player] = false
		return
	end
	local was = inside[player] == true
	local now = false
	for _, zone in CollectionService:GetTagged("SafeZone") do
		if zone:IsA("BasePart") and inBox(zone, root.Position, if was then EXIT_MARGIN else 0) then
			now = true
			break
		end
	end
	if now ~= was then
		inside[player] = now
		player:SetAttribute("InSafeZone", now) -- for client UI only; never trusted
	end
end

task.spawn(function()
	while true do
		task.wait(POLL)
		for _, player in Players:GetPlayers() do
			update(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	inside[player] = nil
	lastCombat[player] = nil
end)

return SafeZones
```

In the damage function: if the attacker is protected, refuse (attacking out of the zone); if the victim is protected, refuse; otherwise apply damage and call `markCombat` on both. Polling at 0.25 s is cheap and accurate enough for zones measured in tens of studs; a player can be at most a few studs past the edge before the server notices, which the exit margin already allows for.

## 6. Fall recovery

Players leave maps downwards more than any other way: gaps between meshes, knockback over edges, physics glitches, exploiters. Three layers, from coarse to fine:

### Layer 1: the engine's destroy height

`Workspace.FallenPartsDestroyHeight` removes parts that fall below it (Roblox docs: parts are removed by parenting to nil, models whose last part is removed go too; the value is clamped between -50,000 and 50,000 and can only be set from Studio, plugins or the command bar). A character falling that far dies in practice. It is a last resort, not a design: falling for several seconds into nothing is a bad experience. Note also that if your map sits far below zero (some floating worlds do), the default height may be above parts of it; check it.

### Layer 2: catch volumes

Big invisible volumes under areas where falls are possible (under floating hubs, beside cliffs, below arenas). When a player enters one, return them to a safe spot. Measured in the reference project: the void arena template shipped with its own `FallCatch` below the floor.

### Layer 3: last-safe-spot tracking

The server remembers each player's last grounded position and puts them back if they fall too far below it. Measured in the reference project's fall guard:

- Sampled every 0.25 s; a position counted as safe only when the character was on the ground.
- Falling more than 55 studs below the last safe spot, or below y = -60 anywhere, returned the player to it: 4 studs up, velocity cleared, 1.5 s invisible ForceField.
- A sideways jump of more than 400 studs between samples counted as a teleport (portals, respawns) and reset the safe spot instead of triggering.
- The 55-stud rule caused false triggers in the realms, which had legitimate drops of more than 55 studs, boss knock-ups and void teleports. It was narrowed to apply only when the last safe spot was in the hub, with the y = -60 rule everywhere else.

That last point is the general lesson: **a fall threshold is a level design parameter.** It must be larger than the biggest legitimate drop in the area it covers. Store it per zone, not globally.

```lua
--!strict
-- Server: per-zone fall guard. Each zone part (tagged "FallZone") may set an attribute
-- MaxDrop (studs). Outside any zone only the absolute floor applies.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local SAMPLE = 0.25
local ABSOLUTE_FLOOR = -60
local TELEPORT_JUMP = 400
local SHIELD_SECONDS = 1.5

local safeSpot: { [Player]: Vector3 } = {}

local function zoneMaxDrop(point: Vector3): number?
	for _, zone in CollectionService:GetTagged("FallZone") do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(point)
			local h = zone.Size / 2
			if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
				local drop = zone:GetAttribute("MaxDrop")
				return if typeof(drop) == "number" then drop else nil
			end
		end
	end
	return nil
end

local function rescue(player: Player, character: Model, spot: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.new(spot + Vector3.new(0, 4, 0)) * character:GetPivot().Rotation)
	local shield = Instance.new("ForceField")
	shield.Visible = false
	shield.Parent = character
	task.delay(SHIELD_SECONDS, function() shield:Destroy() end)
end

task.spawn(function()
	while true do
		task.wait(SAMPLE)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (character and humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
				continue
			end
			local pos = root.Position
			local spot = safeSpot[player]

			if spot and (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude > TELEPORT_JUMP then
				spot = nil -- a teleport or respawn: forget the old spot
				safeSpot[player] = nil
			end

			if humanoid.FloorMaterial ~= Enum.Material.Air then
				safeSpot[player] = pos
			elseif spot then
				local maxDrop = zoneMaxDrop(spot)
				local fellTooFar = (maxDrop ~= nil and spot.Y - pos.Y > maxDrop) or pos.Y < ABSOLUTE_FLOOR
				if fellTooFar then
					rescue(player, character, spot)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player) safeSpot[player] = nil end)
```

Notes: `Humanoid.FloorMaterial` is `Air` when the character is not standing on anything (Roblox docs), which makes a cheap grounded test. A grounded spot on a moving platform or a part that is later removed can be a bad rescue target; tag such parts and skip them when recording safe spots. Characters are simulated by their own client, so a rescue issued by the server may arrive a moment after the client has fallen further; the generous absolute floor keeps that harmless.

### Edge walls derived from geometry

Invisible walls at the edges of floating spaces are part of fall prevention. Measured in the reference project: the first automatic pass on a floating hub placed 761 walls from a raycast grid along every edge of the walkable floor; players then complained they could not jump between the hub's own terraces. It was rebuilt to wall only the **outer outline** of the hub (248 walls), and falls into inner gaps were left to the fall guard. Derive edge walls from the floor by script and rerun them after any geometry change; see [[Lobby and Hub Design]].

## 7. Streaming and the respawn

With streaming on, the respawn spot may not be loaded on the client. Two tools (Roblox docs, as of October 2026):

- `Player:RequestStreamAroundAsync(position, timeOut?)` asks the server to stream around a location you are about to move the player to. It is a request, with no guarantee, and is abandoned when the client is low on memory. Call it at the start of the death presentation, not at the moment of respawn, so the presentation covers the load.
- With predictive streaming enabled, the engine itself creates temporary streaming foci at possible spawn locations when a player dies. That helps `SpawnLocation`-based respawns; it cannot know about spots your script chooses, so still request those.

Measured in the reference project: the death flow stored the chosen respawn CFrame on the player and requested streaming around it at the moment of death, then pivoted the new character to exactly that spot.

## 8. A complete respawn service

Putting it together: auto-loading off, contexts, spot choice, streaming during the presentation, placement, protection and a watchdog.

```lua
--!strict
-- Server: owns all character loading. Requires Players.CharacterAutoLoads = false.
local Players = game:GetService("Players")

local RESPAWN_DELAY = 4 -- seconds the death presentation lasts
local SHIELD_SECONDS = 2
local WATCHDOG_SECONDS = 10
local OCCUPIED_RADIUS = 24

Players.CharacterAutoLoads = false

type Context = "Hub" | "Tutorial" | "Realm" | "Arena"

-- Level designers place spawn parts in folders named after the context.
local function candidates(context: Context): { BasePart }
	local folder = workspace:FindFirstChild("Spawns")
	local sub = folder and folder:FindFirstChild(context)
	local out = {}
	if sub then
		for _, p in sub:GetChildren() do
			if p:IsA("BasePart") then table.insert(out, p) end
		end
	end
	return out
end

local function occupied(position: Vector3, except: Player): boolean
	for _, other in Players:GetPlayers() do
		if other ~= except then
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - position).Magnitude < OCCUPIED_RADIUS then
				return true
			end
		end
	end
	return false
end

local function chooseSpot(player: Player, context: Context): CFrame?
	local list = candidates(context)
	if #list == 0 and context ~= "Hub" then
		list = candidates("Hub")
	end
	local free = {}
	for _, p in list do
		if not occupied(p.Position, player) then table.insert(free, p) end
	end
	local pool = if #free > 0 then free else list
	if #pool == 0 then return nil end
	local spawn = pool[math.random(1, #pool)]
	-- The spawn part's own orientation is the facing the level designer chose.
	return spawn.CFrame
end

local function floorAt(cf: CFrame): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local y = if hit then hit.Position.Y else cf.Position.Y
	return CFrame.new(cf.Position.X, y + 4, cf.Position.Z) * cf.Rotation
end

local pending: { [Player]: CFrame } = {}

local function spawnPlayer(player: Player, context: Context)
	local spot = chooseSpot(player, context)
	if spot then
		pending[player] = floorAt(spot)
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn("LoadCharacterAsync failed for", player.Name, err)
	end
end

local function contextFor(player: Player): Context
	local c = player:GetAttribute("RespawnContext")
	if c == "Tutorial" or c == "Realm" or c == "Arena" then
		return c
	end
	return "Hub"
end

local function onCharacter(player: Player, character: Model)
	local cf = pending[player]
	pending[player] = nil
	if cf then
		character:PivotTo(cf)
	end
	local shield = Instance.new("ForceField")
	shield.Parent = character
	task.delay(SHIELD_SECONDS, function()
		if shield.Parent then shield:Destroy() end
	end)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Once(function()
		local context = contextFor(player)
		-- Choose the spot now and start streaming while the death presentation plays.
		local spot = chooseSpot(player, context)
		if spot then
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(spot.Position, RESPAWN_DELAY)
				end)
			end)
		end
		task.wait(RESPAWN_DELAY)
		if player.Parent then
			spawnPlayer(player, context)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	-- Initial spawn: tutorial or hub, decided by your data layer.
	spawnPlayer(player, contextFor(player))
end)

-- Watchdog: anyone without a living character for too long gets a hub spawn.
local deadSince: { [Player]: number } = {}
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				deadSince[player] = nil
			else
				deadSince[player] = deadSince[player] or os.clock()
				if os.clock() - (deadSince[player] :: number) > WATCHDOG_SECONDS then
					deadSince[player] = nil
					warn("Respawn watchdog fired for", player.Name)
					spawnPlayer(player, "Hub")
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
	deadSince[player] = nil
end)
```

Things to adapt: the spot is chosen twice (at death for streaming, at respawn for occupancy), which is intended, since occupancy can change during the presentation; if you want the streamed spot to be used, store it and only re-pick when it became occupied, as the reference project did. The `floorAt` raycast should exclude characters and decoration in a real game. Your death presentation runs on the client, triggered by `Humanoid.Died` or by an attribute, and should last about `RESPAWN_DELAY`. The watchdog's 10 seconds must be longer than the longest legitimate death presentation plus load time.

## 9. When not to do this

- **Pure obbies** usually keep `SpawnLocation` checkpoints and auto-loading with a short `RespawnTime`: the engine's flow is exactly right there, and checkpoints are covered in [[Genre Playbook - Obbies and Platformers]].
- **Round-based elimination** does not respawn during the round; dead players spectate, and the round system loads everyone at the next round (see [[Round-Based Minigame Loop End to End]]).
- **Safe zones in games without PvP** may be unnecessary; enemy leashing alone keeps the hub safe.

## 10. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Auto-load plus a move | A flash at the default spawn | Own loading, or hide the first frame |
| Context read at load time | Wrong respawn place | Record the context at death |
| Spawns in the killer's view | Spawn camping | Occupancy check at respawn; alcoves |
| ForceField checked by some damage only | "I died during spawn protection" | One damage function checks protection |
| Safe zone without combat tag | Players escape fights into the hub | Combat tag blocks protection for N seconds |
| Zone edge flicker | Protection toggles every frame | Exit margin (hysteresis) |
| One global fall threshold | Rescues during legitimate drops | Per-zone `MaxDrop` |
| No watchdog | "Stuck on respawn" reports | Respawn anyone dead too long |
| Streaming requested at respawn | Arrive into a void | Request at death, during the presentation |

## 11. Checklist

- [ ] Respawn pipeline written down with a time budget per step.
- [ ] Respawn time chosen for the genre, not left at the default by accident.
- [ ] Contexts defined; context recorded at death on the server.
- [ ] Spots: unoccupied, unthreatened, floor checked by raycast, facing a landmark.
- [ ] Protection ends when the player attacks; all damage goes through one function.
- [ ] Safe zones: server-side membership, hysteresis, combat tag, enemy leash.
- [ ] Fall recovery: catch volumes, per-zone drop thresholds, absolute floor, destroy height checked.
- [ ] Edge walls derived from geometry and rerun after map edits.
- [ ] Streaming requested at death for scripted spots.
- [ ] A watchdog respawns anyone without a living character for too long.

## See also

- [[Level Design Start Here]], [[Spawning Teams and Rounds]], [[Level Design for Roblox]].
- [[Characters and Humanoids]], [[Instance Streaming]], [[Server Authority and Validation]].
- [[Combat Arena and Encounter Layout]], [[Lobby and Hub Design]], [[Obby and Platforming Level Design]].
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]], [[Lobby and Hub Design]], [[Debugging Physics and Network Ownership]].

## Connected notes
<!-- auto-links:start -->
[[Links - Checkpoints and spawning]] · Obby Checkpoints and Stage Saves End to End · Cookbook - Players and Characters · Arena Rounds with Teams and Spectating End to End · Genre Playbook - Combat and RPG · Streaming Radius
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Quick Respawn and Spawn Protection]] · [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]] · [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · [[Playtest Heatmaps - Position and Death Maps]] · [[Teaching Through Level Design]] · [[Instanced Interiors - Pooled House and Room Copies for Many Players]]
<!-- related:end -->
