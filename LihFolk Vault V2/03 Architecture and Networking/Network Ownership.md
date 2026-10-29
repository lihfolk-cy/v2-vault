---
tags: [architecture, networking, physics, ownership, security, type/guide, area/networking, level/intermediate, api/SetNetworkOwner, area/security, api/Humanoid, api/Model]
---
# Network Ownership

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Leaving boss NPCs on automatic ownership -> `SetNetworkOwner(nil)` after spawn
> - Avoid: Prompts and ClickDetectors on unanchored parts -> Anchor them or server-own them; server distance check
> - Avoid: `SetNetworkOwner` on anchored parts, or no way back to automatic -> Anchored parts are always server-owned...
> - Every gameplay-critical unanchored object has a deliberate owner.
> - No valuable interaction relies on client-owned Touched or prompt position alone.
> - Vehicles assign the driver on sit and reset on exit, and ownership changes nowhere else (switches cause jitter).
>
> Cost: TL;DR ~190 tok · whole note ~4.6k tok. Read more: ## When to set ownership manually · ## Security: what owned physics lets an exploiter do · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox physics is **distributed**: each unanchored assembly is simulated by one machine, its **network owner**, and that machine's results are replicated to everyone else. Owner can be the server or any one client. Ownership is why your character feels instant, why a ball you kick responds immediately, and also why exploiters can fly, teleport, fling other players and fire Touched events from across the map. This note covers the documented rules, how automatic ownership behaves in practice, when and how to set ownership yourself, the security model, and the diagnosis tools.

Related: [[Physics Assemblies and Constraints]] (what an assembly is), [[Replication and Ownership]] (animation and ownership), [[Exploits and Anti-Cheat]] (movement validation).

## The documented rules

From Roblox docs, "Network ownership":

1. By default the server retains ownership of any BasePart, and the engine **automatically** assigns ownership of unanchored parts to clients based on the client's hardware capacity and the player character's proximity. Parts near a character are more likely to become that player's.
2. The server **always owns anchored parts**, and you cannot change that.
3. Ownership applies per **assembly** (a set of parts rigidly connected). If a mechanism has no anchored parts, setting ownership on one assembly sets it for every assembly in the mechanism.
4. Anchoring a lone assembly gives it to the server; unanchoring it loses its previous ownership setting and returns to automatic handling. Anchoring one assembly inside a larger mechanism moves only that assembly to the server.
5. `BasePart:SetNetworkOwner(player)` assigns ownership from the server; `SetNetworkOwner(nil)` assigns the server. `SetNetworkOwnershipAuto()` returns to automatic. `GetNetworkOwner()` returns the owning player or `nil` for the server. `CanSetNetworkOwnership()` tells you whether a call would succeed (it fails for anchored assemblies, for example).
6. Roblox cannot verify physics calculations from a client owner. A client can teleport parts it owns, move them through walls, and fire Touched events on them even if the server sees no touch.

And from "Network ownership, movement validation, and physics": a client that owns parts (including its character) can teleport to any position, set any WalkSpeed locally without firing events, play arbitrary animations, bypass collisions, and **replicate `inf` or `NaN` CFrame components and extreme velocities** that disturb other unanchored assemblies, even ones it does not own. That is the fling exploit.

## The player character is always client-owned

A player's character root is owned by that player's client in the classic model. This is non-negotiable unless you adopt the server authority model (a beta as of October 2026). Everything about anti-cheat for movement follows from it: you cannot prevent a client from putting its character anywhere; you can only detect, correct and make it worthless. See [[Exploits and Anti-Cheat]].

Consequences people miss:

- **Anything welded to the character is part of the character's assembly**, so the client owns it too. A carried crate, a weapon with an unanchored hitbox part, a pet welded to the root: all client-controlled.
- **Humanoid state is decided by the owner.** `Humanoid:ChangeState` only works on the owner, and `SetStateEnabled` does not replicate. See [[Humanoid States and Animation]].
- **Setting the character's CFrame from the server works** (the server can always write), but the client may immediately write its own position back. Server teleports of characters are usually respected because honest clients accept them; exploit clients may not. That is why server-initiated teleports need to be part of your movement validator (whitelisted, not flagged).

## Automatic ownership in practice

The engine hands ownership of loose parts to nearby clients. In practice this means:

| Situation | What happens | Risk |
|---|---|---|
| Physics props (balls, crates) in a hub | Ownership hops between nearby players as they approach | Jitter at hand-off; any nearby exploiter can grab and fling them |
| An unanchored NPC near players | NPC may become client-owned | The client controls the NPC's position: kiting, pinning, flinging into the void |
| A ProximityPrompt on an unanchored part | Client may own the part | An exploiter moves the part to themselves and triggers it, defeating distance checks (Roblox docs) |
| A vehicle with driver and passenger seats | The first player to sit can own the whole vehicle | The driver's input lags (docs example) |

The hand-off itself takes several network cycles, and the old and new owner briefly disagree, which shows as a stutter. "Ownership ping-pong" (two players standing near the same prop) causes repeated stutters.

## When to set ownership manually

| Object | Recommended owner | Why |
|---|---|---|
| Gameplay-critical NPCs and bosses | Server: `SetNetworkOwner(nil)` on the root after spawn | No client can move them; stable server hit detection |
| Vehicles | The driver while seated; automatic when empty | Responsive driving (docs example) |
| Loose parts riding on a vehicle | The vehicle's driver too | Avoid two owners fighting (docs warning) |
| Projectiles with gameplay effect | Server, or no physics at all (server raycasts/math, client visuals) | Client-owned projectiles can be steered |
| Thrown objects the player throws | The thrower for feel, with server validation of results | Trade-off: responsiveness vs trust |
| Interactable objects with prompts | Anchored, or server-owned | Prompts on client-owned parts can be moved |
| Cosmetic debris, ragdoll limbs of dead NPCs | Leave automatic, or create them on clients only | Not worth server bandwidth |

The docs caution that server ownership "may result in jittery physics interactions for clients": a server-owned object near a player reacts to that player's pushes only after a round trip. For an NPC that is fine; for a ball players dribble, it feels bad.

### Locking an NPC to the server

```lua
--!strict
-- Server: spawn an NPC and keep it server-owned for its whole life.
local function lockToServer(model: Model)
	local root = model.PrimaryPart
	if not root then
		warn("NPC has no PrimaryPart: " .. model:GetFullName())
		return
	end
	local ok, reason = root:CanSetNetworkOwnership()
	if ok then
		root:SetNetworkOwner(nil)
	else
		warn(("Cannot set ownership on %s: %s"):format(model:GetFullName(), tostring(reason)))
	end
end

local function spawnNpc(template: Model, cframe: CFrame): Model
	local npc = template:Clone()
	npc:PivotTo(cframe)
	npc.Parent = workspace
	-- Ownership is per assembly; set it after the model is in the world and assembled.
	lockToServer(npc)
	return npc
end

return spawnNpc
```

Notes:

- Call it **after** parenting into Workspace; the assembly must exist.
- If a part of the NPC is anchored, the call fails for that assembly (`CanSetNetworkOwnership` returns false with a reason). Anchored NPCs are already server-owned.
- Welding the NPC to something else, or a constraint that joins it to a player's assembly, can merge mechanisms and change ownership. Re-assert after big structural changes (ragdoll on death, carrying).

### Vehicle seat ownership

```lua
--!strict
-- ServerScriptService/VehicleOwnership: hand each tagged vehicle to its driver, back to the server when empty.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local function driverOf(seat: VehicleSeat): Player?
	local humanoid = seat.Occupant
	return if humanoid then Players:GetPlayerFromCharacter(humanoid.Parent) else nil
end

local function refreshOwner(seat: VehicleSeat)
	local ok, reason = seat:CanSetNetworkOwnership()
	if not ok then
		warn(`{seat:GetFullName()}: {reason}`) -- usually an anchored part in the vehicle
		return
	end
	local driver = driverOf(seat)
	if driver then
		seat:SetNetworkOwner(driver) -- applies to the whole assembly
	else
		seat:SetNetworkOwner(nil) -- empty vehicles stay with the server
	end
end

local function watch(instance: Instance)
	if not instance:IsA("VehicleSeat") then return end
	instance:GetPropertyChangedSignal("Occupant"):Connect(function()
		refreshOwner(instance)
	end)
	refreshOwner(instance)
end

CollectionService:GetInstanceAddedSignal("DrivableSeat"):Connect(watch)
for _, seat in CollectionService:GetTagged("DrivableSeat") do
	watch(seat)
end
```

Pinning an empty vehicle to the server (rather than leaving it on automatic) stops a nearby player from picking up ownership of a parked car and flinging it.

Driver ownership means the driver controls the car's physics. Validate what matters: speed caps checked on the server, finish lines decided by server-side checkpoints, collisions that damage other players recomputed on the server.

## Security: what owned physics lets an exploiter do

| Exploit | Mechanism | Defence |
|---|---|---|
| Speed hack | Local WalkSpeed or direct CFrame writes on own character | Server displacement checks with tolerance; rubber-band ([[Exploits and Anti-Cheat]]) |
| Fly / noclip | Owner disables gravity or collisions locally | Ground and collision heuristics; make flight worthless with server distance checks on interactions |
| Teleport | Owner writes a far CFrame | Server displacement checks; server-side zone gates (see below) |
| Fling | Owner gives its own parts huge or `NaN` velocity and touches others | Server-owned NPCs; check `AssemblyLinearVelocity` for absurd values; anchor or server-own critical props |
| Touched spoofing | Owner fires Touched on a part it owns anywhere | Never award from client-owned Touched alone; server distance check at the moment of the event |
| Prompt pulling | Owner moves an unanchored part with a prompt to itself | Anchored or server-owned prompt parents; server distance check in `Triggered` |
| NPC control | Client owns a nearby NPC | `SetNetworkOwner(nil)` on NPC roots |

### Validating Touched from a client-owned part

```lua
--!strict
-- Server: a pickup that ignores touches that could not physically have happened.
local Players = game:GetService("Players")

local MAX_TOUCH_DISTANCE = 12 -- studs from part centre; tune to part and character size

local function onTouched(pickup: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	-- The server's view of the root lags the client slightly, so allow a margin.
	if (root.Position - pickup.Position).Magnitude > MAX_TOUCH_DISTANCE then
		return -- touch reported far from where the server sees the character
	end
	if pickup:GetAttribute("Taken") then return end
	pickup:SetAttribute("Taken", true) -- claim before granting
	-- grant reward from server-side data here
end

return onTouched
```

Even better is to not rely on Touched for anything valuable: on the server, check proximity on a timer or with `GetPartBoundsInRadius` against your own pickup list. See [[Raycasts Shapecasts and Spatial Queries]].

### Server-side zone gating (a teleport defence that just works)

One production game had progression-gated worlds. Rather than trying to stop teleport hacks, a server-side guard periodically checked whether each player's character stood inside a world they had not unlocked, and if so moved them to the lobby. A teleport hack then gains nothing: rewards in that zone require server-validated presence, and the player is removed within seconds. This is the "make it worthless" principle, and it costs a few bounding-box checks per player per second.

```lua
--!strict
-- Server: return players standing in zones they have not unlocked.
local Players = game:GetService("Players")

type Zone = { name: string, cframe: CFrame, size: Vector3 }
local ZONES: { Zone } = {} -- filled from map data at startup
local LOBBY = CFrame.new(0, 10, 0)

local function inside(zone: Zone, p: Vector3): boolean
	local localPos = zone.cframe:PointToObjectSpace(p)
	local half = zone.size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function hasUnlocked(player: Player, zoneName: string): boolean
	-- Read from the server-side profile, never from client-writable state.
	local unlocked = player:GetAttribute("Unlocked_" .. zoneName)
	return unlocked == true
end

task.spawn(function()
	while true do
		task.wait(2)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				for _, zone in ZONES do
					if inside(zone, root.Position) and not hasUnlocked(player, zone.name) then
						-- With streaming on, stream the destination first: see Instance Streaming.
						player:RequestStreamAroundAsync(LOBBY.Position, 5)
						character:PivotTo(LOBBY)
						break
					end
				end
			end
		end
	end
end)
```

(Player attributes are server-written here; the client cannot change what the server reads. In a real game the profile table is the source of truth and the attribute is only a mirror.)

## Ownership and hit detection

Ownership decides whose view of a moving object is "true". For combat:

- **Player attacks:** the attacker's character is client-owned, so the server sees it late. Server hit checks need a latency tolerance (one production game raised its player reach from 13 to 17 studs and used a range multiplier of 1.35 for abilities, on characters scaled to 1.6x, after measuring missed hits).
- **NPC attacks:** server-owned NPCs give the server an exact position, so the server can decide hits precisely; the victim's client sees the NPC late, so dodge windows need generosity on the victim's side (the same game used a 0.40 s dodge window against boss attacks, and a 0.26 s parry window).
- **Client-animated NPCs:** if NPC animation runs only on clients (see [[Replication and Ownership]]), the server's parts do not move with the animation, so hits must be data-driven (distance, arc, marker times) rather than part-touch based.

See [[Hitboxes and Hit Detection]] and [[Combat Systems Architecture]].

## Diagnosing ownership

- Studio: viewport **visualization options** (top right) and toggle **Network owners** during a playtest. Green: your client owns and simulates it. Red: in a buffer zone, your client simulates it but something else owns it. White or grey: server or another client. Black: nobody owns it and physics will not apply. In multi-client tests each client gets its own colour (Roblox docs).
- Server-side audit: print owners of everything moving.

```lua
--!strict
-- Command bar (server view during a playtest): list unanchored assemblies by owner.
local counts: { [string]: number } = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d.Anchored and d.AssemblyRootPart == d then
		local owner = d:GetNetworkOwner()
		local key = if owner then owner.Name else "server"
		counts[key] = (counts[key] or 0) + 1
	end
end
for k, n in counts do print(k, n) end
```

Symptoms:

| Symptom | Likely cause |
|---|---|
| NPC stutters when players approach | Automatic ownership hand-off; set server ownership |
| Vehicle input lags for the driver | Passenger owns the vehicle; set driver ownership |
| Prop jitters between two players | Ownership ping-pong; server-own it or anchor it |
| Object frozen in the air, no physics | Black outline: no owner; check anchoring and constraints |
| `SetNetworkOwner` errors | Part is anchored or welded to an anchored part; use `CanSetNetworkOwnership` |
| Players flung by another player | Owned fling; validate velocities, protect characters with collision groups if needed |

## Common mistakes

| Mistake | Fix |
|---|---|
| Leaving boss NPCs on automatic ownership | `SetNetworkOwner(nil)` after spawn |
| Prompts and ClickDetectors on unanchored parts | Anchor them or server-own them; server distance check |
| `SetNetworkOwner` on anchored parts, or no way back to automatic | Anchored parts are always server-owned; `SetNetworkOwnershipAuto()` restores automatic |
| Awarding from client-owned Touched | Server proximity check or server queries |
| Calling `SetNetworkOwner` before parenting | Call after the assembly exists in Workspace |
| Treating server ownership as free | It adds latency for nearby players; use it for critical objects only |
| Flagging server-initiated teleports as cheats | Tell the movement validator about every server move |

## Checklist

- [ ] Every gameplay-critical unanchored object has a deliberate owner.
- [ ] No valuable interaction relies on client-owned Touched or prompt position alone.
- [ ] Vehicles assign the driver on sit and reset on exit, and ownership changes nowhere else (switches cause jitter).
- [ ] Movement validation accounts for latency and whitelists server teleports.
- [ ] Ownership visualised once in a multi-client test.

## See also
[[Client-Server Model]] · [[Replication Rules]] · [[Physics Assemblies and Constraints]] · [[Exploits and Anti-Cheat]] · [[Server Authority and Validation]] · [[Hitboxes and Hit Detection]] · [[Characters and Humanoids]] · [[Replication and Ownership]] · [[Physics Performance]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Physics and Network Ownership]] · Detecting Movement Exploits - Speed Fly Noclip Teleport · Official Docs - Physics · Cars with Constraints - Suspension Steering and Drive · Racing Laps and Checkpoints End to End · How Exploits Work - The Client Boundary
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Client Prediction and Reconciliation for Combat]] · [[Rate Limiting and Abuse Prevention]] · [[Instance Streaming]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Teleporting and Multi-Place Games]]
<!-- related:end -->
