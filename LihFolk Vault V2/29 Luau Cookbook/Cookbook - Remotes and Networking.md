---
tags: [luau, cookbook, remotes, networking, security, recipes, type/reference, area/scripting, level/intermediate, api/RemoteEvent, area/security, api/UnreliableRemoteEvent]
---
# Cookbook - Remotes and Networking

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Typing remote parameters as concrete types and skipping runtime checks.
> - Avoid: Sending prices, damage, rewards or durations from the client.
> - Avoid: Using `InvokeClient` for gameplay.
> - All remotes listed in one server script.
> - Every handler: rate limit, type checks, range checks, then logic.
> - No client-supplied numbers that change economy or combat outcomes.
>
> Cost: TL;DR ~140 tok · whole note ~5.6k tok. Read more: ## 3. Rate limit per player with a token bucket · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Recipes for talking between server and client without opening holes. The rule behind all of them: the client is a request, never a fact. Every value that arrives at `OnServerEvent` or `OnServerInvoke` is typed `unknown` here on purpose, because an exploiter can send any type, any size, at any rate. Code is `--!strict` Luau, reviewed, not run. The why lives in [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]] and [[How Exploits Work - The Client Boundary]].

---

## 1. Create every remote in one place on the server

**Problem.** Remotes scattered through Explorer, created by different scripts, lead to "infinite yield possible" warnings and duplicate names.

```lua
--!strict
-- ServerScriptService/Remotes.server.lua (runs first)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local EVENTS = { "BuyItem", "EquipItem", "Notify" }
for _, name in EVENTS do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
end

local cosmetic = Instance.new("UnreliableRemoteEvent")
cosmetic.Name = "LookDirection"
cosmetic.Parent = folder

folder.Parent = ReplicatedStorage -- parent last: clients see a complete folder
```

```lua
--!strict
-- Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyItem = remotes:WaitForChild("BuyItem") :: RemoteEvent
```

**Why it works.** One list is the whole network surface of the game, which makes it easy to audit. Parenting the folder last means clients either see nothing or everything.

**Pitfall.** Creating remotes from client code does nothing useful: they never replicate to the server. Server scripts that need a remote created by another server script should `WaitForChild` too, since script start order is not guaranteed ([[Script Types and Run Context]]).

---

## 2. Validate argument types before using them

**Problem.** `buyItem:FireServer(itemId)` is what your client sends. An exploiter sends a table, `nil`, `NaN`, a 1 MB string or a negative number.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local buyItem = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyItem") :: RemoteEvent

local ITEMS: { [string]: { price: number } } = {
	Sword = { price = 100 },
	Shield = { price = 75 },
}

buyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown, quantity: unknown)
	if typeof(itemId) ~= "string" or #itemId > 32 then
		return
	end
	if typeof(quantity) ~= "number" or quantity ~= quantity -- NaN check
		or quantity < 1 or quantity > 99 or quantity % 1 ~= 0 then
		return
	end
	local item = ITEMS[itemId]
	if not item then
		return
	end
	print(player.Name, "wants", quantity, itemId, "for", item.price * quantity)
end)
```

**Why it works.** `typeof` checks the real runtime type. `quantity ~= quantity` is true only for NaN. The `% 1` check rejects fractions, and the range check rejects negatives (a classic "buy -100 items to gain coins" exploit). Looking the item up in a server table means the client never sends a price.

**Pitfall.** Do not annotate the handler's parameters as `string` and `number`: strict mode would then trust them, but the type checker cannot see what the network delivers. Keep them `unknown` and narrow.

---

## 3. Rate limit per player with a token bucket

**Problem.** A client fires a remote 500 times a second, flooding your handlers and DataStore calls.

```lua
--!strict
local Players = game:GetService("Players")

type Bucket = { tokens: number, last: number }

local function makeLimiter(capacity: number, refillPerSecond: number)
	local buckets: { [Player]: Bucket } = {}
	Players.PlayerRemoving:Connect(function(player: Player)
		buckets[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = capacity, last = now }
			buckets[player] = bucket
		end
		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.last) * refillPerSecond)
		bucket.last = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end
end

local allowBuy = makeLimiter(5, 2) -- burst of 5, then 2 per second
-- in a handler: if not allowBuy(player) then return end
```

**Why it works.** The bucket allows short bursts (a player clicking quickly) but caps the long-run rate. One limiter per remote keeps limits independent.

**Pitfall.** Check the limit before any expensive work, including type validation that walks tables. Decide what to do with repeat offenders separately (log, ignore, kick): see [[Rate Limiting and Abuse Prevention]] and [[False Positives Lag and Fair Enforcement]] before kicking anyone, since lag spikes deliver legitimate bursts.

---

## 4. Stop a player from running the same request twice at once

**Problem.** A handler yields (DataStore, `MarketplaceService`), and a second request from the same player starts before the first finishes. Both pass the "has enough coins" check: a duplication bug.

```lua
--!strict
local busy: { [Player]: boolean } = {}

local function withPlayerLock(player: Player, fn: () -> ())
	if busy[player] then
		return
	end
	busy[player] = true
	local ok, err = pcall(fn)
	busy[player] = nil
	if not ok then
		warn("handler failed for", player.Name, err)
	end
end

-- remote.OnServerEvent:Connect(function(player, ...)
--     withPlayerLock(player, function() ... end)
-- end)
```

**Why it works.** The flag is set before the first yield, so a second call sees it and returns. `pcall` guarantees the flag is cleared even if the handler errors.

**Pitfall.** Without the `pcall`, one error leaves the player locked out until they rejoin. Also clear `busy[player]` on `PlayerRemoving` if handlers can yield for long. Deeper cases are in [[Economy Exploits - Dupes Races and Purchase Abuse]] and [[Debugging Race Conditions and Yield Order]].

---

## 5. Validate positions and distances

**Problem.** The client says "I opened chest X" from across the map.

```lua
--!strict
local MAX_REACH = 12 -- studs; generous for lag (rule of thumb)

local function isNear(player: Player, target: BasePart, maxDistance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - target.Position).Magnitude <= maxDistance
end

-- if not isNear(player, chest, MAX_REACH) then return end
```

**Why it works.** The server compares its own view of the character's position to the target. The client's claim about where it is never enters the check.

**Pitfall.** The server's copy of a character lags the client by roughly the player's ping, so a tight limit punishes fast-moving players. Add a margin and log near misses instead of kicking. A teleporting exploiter moves their character on the server too (they own its physics), so distance checks must be paired with movement checks ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

---

## 6. Reject NaN, infinity and huge vectors

**Problem.** A client sends `Vector3.new(0/0, 0, 0)` as an aim direction. NaN poisons every calculation it touches, and a `CFrame` built from it can make parts vanish.

```lua
--!strict
local function isFiniteNumber(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

local function readDirection(value: unknown): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	if not (isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)) then
		return nil
	end
	if value.Magnitude < 1e-3 then
		return nil
	end
	return value.Unit
end
```

**Why it works.** NaN is the only value not equal to itself; the bounds reject infinities. Normalising on the server means the client cannot send a 1e30-length "direction" that becomes a 1e30 velocity.

**Pitfall.** `typeof(value) == "Vector3"` narrows `value` for strict mode only inside that branch. Write the guard as an early return, as above, so the rest of the function sees the narrowed type.

---

## 7. Use RemoteFunctions only from client to server, with a timeout mindset

**Problem.** You need a reply, such as "can I afford this?" or "give me my inventory".

```lua
--!strict
-- Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getInventory = Instance.new("RemoteFunction")
getInventory.Name = "GetInventory"
getInventory.Parent = ReplicatedStorage

getInventory.OnServerInvoke = function(player: Player): { string }
	return { "Sword", "Shield" } -- read from the player's loaded profile
end
```

```lua
--!strict
-- Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getInventory = ReplicatedStorage:WaitForChild("GetInventory") :: RemoteFunction

local ok, result = pcall(function()
	return getInventory:InvokeServer()
end)
if ok and typeof(result) == "table" then
	print("items:", #result)
end
```

**Why it works.** The client waits for the server's answer; `pcall` catches the error raised if the server callback errors.

**Pitfall.** Never use `InvokeClient` (server asking client) for anything that matters. If the client never returns, the server thread hangs forever, and a client can return anything (Roblox docs (as of October 2026) warn about both). Use a `RemoteEvent` from server to client instead. Also assign `OnServerInvoke` only once; a second assignment replaces the first silently.

---

## 8. Send cosmetic, high-frequency data unreliably

**Problem.** Where each player is looking, or a weapon's aim, updates many times a second. Reliable events queue up and add latency when packets are lost.

```lua
--!strict
-- Client: send at most 10 times a second, only when it changed
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local look = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LookDirection") :: UnreliableRemoteEvent

local camera = workspace.CurrentCamera
local SEND_INTERVAL = 0.1
local elapsed = 0
local lastSent = Vector3.zero

RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < SEND_INTERVAL then
		return
	end
	elapsed = 0
	local dir = camera.CFrame.LookVector
	if (dir - lastSent).Magnitude > 0.02 then
		lastSent = dir
		look:FireServer(dir)
	end
end)
```

**Why it works.** An `UnreliableRemoteEvent` may drop or reorder messages, so a lost update is simply replaced by the next one. Sending only on change and at a fixed interval keeps bandwidth flat whatever the frame rate.

**Pitfall.** Payloads over 1,000 bytes are dropped, and excess traffic is dropped rather than delayed (Roblox docs (as of October 2026)). Never send anything that must arrive (purchases, damage, state changes) unreliably. Validate the server side exactly as in recipe 6.

---

## 9. Replicate state with attributes instead of events

**Problem.** Every client needs to know a door's state, a player's team colour or a round timer, including players who join late.

```lua
--!strict
-- Server
local door = workspace:WaitForChild("Door") :: BasePart
door:SetAttribute("Open", true)
workspace:SetAttribute("RoundEndsAt", workspace:GetServerTimeNow() + 120)
```

```lua
--!strict
-- Client
local door = workspace:WaitForChild("Door") :: BasePart
local function render()
	door.Transparency = if door:GetAttribute("Open") == true then 0.8 else 0
end
door:GetAttributeChangedSignal("Open"):Connect(render)
render()
```

**Why it works.** Attributes set on the server replicate to every client that can see the instance, including late joiners, with no extra code. Sending an end time instead of a ticking counter means one replication per round, not one per second ([[Spawning Teams and Rounds]]).

**Pitfall.** Attributes set by a client stay on that client. Never read a client-settable attribute on the server as truth. And call `render()` once after connecting, or the client shows the wrong state until the first change.

---

## 10. Fire to everyone except one player, or to nearby players only

**Problem.** The attacker already played their own effect locally; everyone else needs it. Or only players within 200 studs care.

```lua
--!strict
local Players = game:GetService("Players")

local function fireOthers(remote: RemoteEvent, except: Player, ...: any)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

local function fireNear(remote: RemoteEvent, position: Vector3, radius: number, ...: any)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and (character:GetPivot().Position - position).Magnitude <= radius then
			remote:FireClient(player, ...)
		end
	end
end
```

**Why it works.** There is no built-in "fire all except", so a loop over `GetPlayers` does it. Filtering by distance is a simple form of interest management that cuts bandwidth for effects nobody can see.

**Pitfall.** `FireClient` serialises arguments once per call, so a large payload sent to 50 players costs 50 times. Keep payloads small (ids, not instances or long strings). See [[Interest Management and Per-Player Replication]] and [[Network Bandwidth Budgets and Measuring Them]].

---

## 11. Batch many small server-to-client messages into one per frame

**Problem.** An area attack damages 30 enemies and fires 30 "show damage number" events in one frame.

```lua
--!strict
local RunService = game:GetService("RunService")

type Hit = { id: number, amount: number }

local pending: { [Player]: { Hit } } = {}

local function queueHit(player: Player, id: number, amount: number)
	local list = pending[player]
	if not list then
		list = {}
		pending[player] = list
	end
	table.insert(list, { id = id, amount = amount })
end

local function startFlushing(remote: RemoteEvent)
	RunService.Heartbeat:Connect(function()
		for player, list in pending do
			if player.Parent then
				remote:FireClient(player, list)
			end
		end
		table.clear(pending)
	end)
end
```

**Why it works.** One event with a 30-entry array has far less overhead than 30 events, and the client can render them together.

**Pitfall.** Keep the batch bounded (cap the list length) so a burst cannot build a huge single message. `table.clear` keeps the table but empties it; fine here because nothing else holds references to the inner lists.

---

## 12. Never let the client choose who or what it affects without checks

**Problem.** `damage:FireServer(targetHumanoid, 50)` lets an exploiter kill anyone for any amount.

```lua
--!strict
-- Client sends only intent: "I swung at this target".
-- Server decides the damage from its own data.
local SWORD_DAMAGE = 25
local SWING_COOLDOWN = 0.5
local lastSwing: { [Player]: number } = {}

local function onSwing(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < SWING_COOLDOWN then
		return
	end
	lastSwing[player] = now
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = target.PrimaryPart
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	-- distance check from recipe 5 goes here
	humanoid:TakeDamage(SWORD_DAMAGE)
end
```

**Why it works.** The amount comes from the server. The cooldown is enforced on the server clock. The target is checked for type, life and (with recipe 5) range.

**Pitfall.** An `Instance` argument can be any instance the client can see, including other players' characters, the map or your own Remotes folder. Always check what kind of thing it is. Full combat design is in [[Combat Systems Architecture]] and [[Detecting Combat Exploits - Reach Rate and Aim]].

---

## Common mistakes

- Typing remote parameters as concrete types and skipping runtime checks.
- Sending prices, damage, rewards or durations from the client.
- Using `InvokeClient` for gameplay.
- Reliable remotes for 60 Hz cosmetic data.
- Forgetting to clear per-player tables (`buckets`, `busy`, `lastSwing`) on leave.

## Checklist

- [ ] All remotes listed in one server script.
- [ ] Every handler: rate limit, type checks, range checks, then logic.
- [ ] No client-supplied numbers that change economy or combat outcomes.
- [ ] Yielding handlers hold a per-player lock.
- [ ] Unreliable remotes carry only replaceable, small data.
- [ ] Abuse-tested with [[Testing Your Own Remotes - Fuzzing and Abuse Tests]].

## See also

[[Luau Cookbook Start Here]], [[Client-Server Model]], [[Replication Rules]], [[Threat Modeling a Roblox Game]], [[Cookbook - Players and Characters]], [[Cookbook - Data and Saving]]

## Nuances and edge cases

1. **Validation tolerance scales with ping.** A distance check that rejects any hit more than 12 studs away works at 50 ms ping and rejects honest players at 300 ms, where the target has moved several studs since the client saw it. Make tolerances a function of measured ping (with a cap), or rewind target positions to the time the client claims, within a limit. Too strict and you punish players on phones and far regions; too loose and you open reach exploits.
2. **Token buckets need different sizes per remote.** One shared limit for every remote is either too strict for chatty ones (aim updates) or too loose for expensive ones (purchases, saves). Give each remote its own capacity and refill rate, and decide in advance what happens on overflow: drop silently for cosmetic data, log for gameplay, flag for economy actions.
3. **Unreliable remotes drop and reorder.** That is the point: cosmetic, high-frequency data where the next update replaces the last. Never send a state change that must arrive (a hit, a purchase, an equip) over an UnreliableRemoteEvent. Unreliable messages also have a small size limit; keep each one to a few values (exact byte limit not confirmed for this round).
4. **Batching changes latency.** Collecting messages and sending once per frame cuts overhead, but it adds up to a frame of delay. For most UI updates that is invisible; for combat feedback it can matter. Batch bulk updates and send urgent events immediately.
5. **Attributes versus events.** Attributes replicate the latest value and are great for state (health, team, current zone). Events carry moments (a hit landed, a reward granted). A common failure is using attributes for moments: two hits in one frame produce one attribute change, and one is lost. Use events for things that happen, attributes for things that are.
6. **Scale effects.** At 10 players, firing every update to every player is fine. At 50 to 100 players, per-player bandwidth grows with the number of other players, so "fire to all" for movement-like data becomes the main bandwidth cost. Filter by distance or interest before sending, and lower the rate for far players.
7. **Players who leave mid-request.** A handler that yields (a DataStore call, a wait) can resume after the player has left. Check `player.Parent` after every yield before touching their state, and make cleanup on leave idempotent.
8. **Deferred events.** With deferred signal behaviour, handlers run slightly later than the fire call, at a resumption point. Code that fires a remote and then immediately assumes the handler has run (on the same side) breaks. Do not depend on immediate handler execution order.

## More common mistakes

1. **Trusting instance arguments.** Symptom: an exploiter passes another player's tool or a part from a different place and the server acts on it. Fix: check the instance is a descendant of the expected container and belongs to the caller.
2. **Rate limit keyed by remote only.** Symptom: one exploiter fills a global bucket and blocks everyone. Fix: key buckets per player per remote.
3. **Kicking on a single failed check.** Symptom: honest players on bad connections get kicked. Fix: count violations over time and act on patterns, as in the anti-exploit notes.
4. **RemoteFunction with no client-side timeout plan.** Symptom: UI hangs forever when the server handler errors. Fix: keep server handlers fast and wrapped in pcall, and show a retry on the client.
5. **Sending large tables every update.** Symptom: high receive bandwidth and frame spikes on phones. Fix: send deltas or ids, not whole objects.
6. **Creating remotes from clients or at runtime in several scripts.** Symptom: race conditions where a client waits forever for a remote. Fix: create all remotes in one server module before anything fires.

## Related decisions

- [[Remote Abuse Patterns and Rate Limiting in Practice]]: deeper rate limiting design per remote.
- [[False Positives Lag and Fair Enforcement]]: what to do when a validation fails.
- [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]: proving these recipes hold.
- [[Network Bandwidth Budgets and Measuring Them]]: measuring the cost of fire-to-all.
- [[Interest Management and Per-Player Replication]]: sending only to players who need it.
- [[Client Prediction and Reconciliation for Combat]]: handling latency without trusting the client.
- [[Debugging Race Conditions and Yield Order]]: the player-left-mid-request class of bugs.
- [[Building a Signal Library]]: how deferred and immediate signals differ.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: what busy flags and validation protect.

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Secure Remotes]] · Rate Limiting · Anti-Exploit Start Here · Replication Boundary · Debugging Client-Server Desync · Skill - Roblox Anti-Exploit Review
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[RemoteEvent - Engine Reference Card]] · [[AI Pitfalls - Networking and Security]] · [[Rate Limiting]] · [[Cookbook - Math CFrame and Vectors]] · [[Cookbook - Tables Strings and Time]] · [[Cookbook - UI]]
<!-- related:end -->
