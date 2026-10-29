---
tags: [architecture, networking, remotes, security, performance, type/guide, area/networking, level/intermediate, api/RemoteEvent, area/security, api/RemoteFunction, api/UnreliableRemoteEvent]
---
# RemoteEvents RemoteFunctions and Unreliable Remotes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Budgeting remote traffic per remote instead of per client -> Loss-tolerant streams on an UnreliableRemoteEvent (its own pool)...
> - Avoid: `InvokeClient` for anything -> Event plus reply event with timeout
> - Avoid: Identity, price or balance taken from the payload -> The caller is `OnServerEvent`'s first argument; the server reads...
> - Client send rates budgeted per client: about 500 calls per second shared by all remotes of one type (reliable and unreliable...
> - All remotes created by the server, in one folder, from one list.
> - No `InvokeClient` anywhere.
>
> Cost: TL;DR ~180 tok · whole note ~5.8k tok. Read more: ## The three types · ## Organising remotes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Remotes are the explicit messages you send across the client-server boundary. Roblox has three kinds, each with different delivery promises, limits and failure modes. Choosing the wrong one gives you either lag (reliable traffic for data nobody needs), lost events (unreliable traffic for things that must happen), or a server thread that hangs forever (`InvokeClient`). This note covers the guarantees exactly as documented, the argument rules, the throttling and size limits, the RemoteFunction pitfalls, how to organise remotes in a project, and the production patterns that hold up: server-validated relays, request/response with timeouts, sequenced unreliable streams and [[honeypots]].

Validation of what arrives is covered in [[Server Authority and Validation]] and rate limits in [[Rate Limiting and Abuse Prevention]]. This note focuses on the transport.

## The three types

| Type | Direction | Yields the sender? | Delivery | Order | Use for |
|---|---|---|---|---|---|
| `RemoteEvent` | Client to server, server to one client, server to all | No | Reliable: lost packets are resent while connected | Ordered per direction, **including across different RemoteEvent instances** | Requests, state changes, anything that must arrive |
| `UnreliableRemoteEvent` | Same | No | Best effort; may be dropped | **Not** ordered | Continuous or ephemeral data: aim, cosmetic effects, positions |
| `RemoteFunction` | Client to server (`InvokeServer`), server to client (`InvokeClient`) | **Yes**, until the other side returns | Reliable | Not ordered relative to RemoteEvents | Client asking the server a question and needing an answer |

All facts in this table are from the Roblox docs pages for these classes and "Remote events and callbacks" (as of October 2026).

### Delivery details worth memorising

From the docs:

- **RemoteEvent with no handler connected:** messages queue and are delivered in order when a handler connects. The queue is limited in count and memory; when full, further messages are discarded and Output logs a "Remote event invocation" error. Undelivered messages are lost if the recipient disconnects.
- **Handler ordering is about start, not finish.** If a handler yields (`task.wait`, `WaitForChild`, a DataStore call), the next message's handler can start before the earlier one resumes. Two requests from the same player can interleave in your code. This is the root of most "duplicate item" bugs.
- **RemoteFunction callbacks that yield** can return responses out of order.
- **UnreliableRemoteEvent** messages can be dropped because of transit loss, congestion, payloads over 1,000 bytes, exceeding the throttle (excess is **dropped**, not delayed), or no connected handler (discarded immediately, not queued). Later messages can arrive before earlier ones.
- Only one invocation can be in flight per calling thread, and if several callbacks are assigned to the same RemoteFunction, only the last assignment runs.

### Limits

| Limit | Value | Source |
|---|---|---|
| Client-to-server rate | About **500 requests per second per client**, shared among all remotes **of the same type** | Roblox docs, `RemoteEvent` and `UnreliableRemoteEvent` "Throttling" |
| RemoteEvent over the rate | Excess is processed later (delayed), order kept | Roblox docs |
| UnreliableRemoteEvent over the rate | Excess is dropped | Roblox docs |
| UnreliableRemoteEvent payload | Events with payloads **larger than 1,000 bytes are dropped**; Studio's Output reports by how many bytes | Roblox docs |
| Payload size of reliable remotes | No small documented hard cap, but large payloads cost bandwidth and delay every message behind them | Rule of thumb: keep per-message payloads small; send large data rarely |

Payloads are encoded and compressed (buffers in particular), which makes it hard to know your unreliable payload size before firing (Roblox docs). Design unreliable messages to be obviously small: a few numbers, an id, a short string.

The 500/s throttle is per client and shared per remote type. One noisy system (a per-frame `FireServer` from a LocalScript) can consume the budget and delay every other RemoteEvent that client sends, including your purchase confirmation. Never fire reliable remotes per frame. RemoteEvent and UnreliableRemoteEvent are different types, so each draws on its own pool: moving a high-rate stream (aim, look direction) to an UnreliableRemoteEvent frees the reliable budget for hits and purchases.

## Argument rules

What survives the trip (Roblox docs, "Argument limitations"):

| You send | Receiver gets |
|---|---|
| Numbers, strings, booleans, `nil` | Same values. **`NaN` and `inf` are valid numbers and pass through** |
| Roblox datatypes (`Vector3`, `CFrame`, `Color3`, `EnumItem`...) | Same values |
| An `Instance` the receiver can see | A reference to its copy |
| An `Instance` the receiver cannot see (ServerStorage item to a client; client-created part to the server) | `nil` |
| A table | A **copy**: no identity, no metatable, functions removed |
| A table with non-string keys | Keys converted to strings |
| A mixed table (array part plus string keys) | Undefined; do not send |
| A table with `nil` holes | Do not send; elements may be lost |
| A function | `nil` |
| A `buffer` | A copy; compact and efficient (see [[Buffers and Binary Data]]) |

Server-side, the **first parameter of `OnServerEvent` is always the real sending `Player`**, supplied by the engine. It is the only argument you can trust. Every other argument is attacker-controlled: a client can send a table shaped like an Instance (`{Name = "Sword", ClassName = "Folder", Price = {Value = 0}}`), a `NaN`, a 10 MB string, an Instance from a part of the game it should not touch. The docs show exactly the fake-Instance-table attack against a shop.

### Payload design

- **Send ids, not objects.** `"blade_ember"` and look it up in a server catalog, rather than the Tool Instance (whose attributes the client may have edited locally).
- **Send scalars, not tables**, where possible. Each table field is another thing to validate.
- **Send intent, not outcome.** "Cast slot 2 aimed at this direction" rather than "deal 400 damage to this enemy".
- **Send small.** Quantise positions, use enums or short ids, batch several updates into one message at a fixed rate.

## RemoteFunction pitfalls

`InvokeServer` (client asks, server answers) is fine and convenient for request/response UIs (shop "can I afford this?", "load my inventory page"). Its pitfalls are manageable:

- The client thread yields until the server returns; if the server handler yields for a DataStore call, the UI waits. Show a spinner and guard against double clicks.
- If the server callback errors, the error propagates to the client caller. Do not leak internal error strings; wrap the handler and return a clean result.
- The return value is an information channel: never return state the client should not know.

`InvokeClient` (server asks a client) is the dangerous one. The docs list the failure modes:

- If the client throws an error, **the server throws too**.
- If the client disconnects during the call, `InvokeClient` errors.
- If the client never returns a value, **the server yields forever**.

An exploiter can simply set `OnClientInvoke` to a function that never returns, and your server thread leaks. If that thread held a lock (a trade in progress, a save in progress), the lock is held forever. **Do not use `InvokeClient`** for anything. If the server needs an answer from a client, send a RemoteEvent and wait for a reply RemoteEvent with a timeout:

```lua
--!strict
-- Server: ask one client a question and wait at most `timeout` seconds for the answer.
local HttpService = game:GetService("HttpService")

local askRemote = game.ReplicatedStorage.Remotes.Ask :: RemoteEvent
local replyRemote = game.ReplicatedStorage.Remotes.Reply :: RemoteEvent

type Pending = { player: Player, thread: thread }
local pending: { [string]: Pending } = {}

replyRemote.OnServerEvent:Connect(function(player: Player, requestId: unknown, answer: unknown)
	if typeof(requestId) ~= "string" then return end
	local entry = pending[requestId]
	if not entry or entry.player ~= player then return end -- only the asked player may answer
	pending[requestId] = nil
	task.spawn(entry.thread, true, answer) -- answer is still untrusted: validate at the call site
end)

local function ask(player: Player, question: string, timeout: number): (boolean, unknown)
	local requestId = HttpService:GenerateGUID(false)
	local thread = coroutine.running()
	pending[requestId] = { player = player, thread = thread }

	task.delay(timeout, function()
		if pending[requestId] then
			pending[requestId] = nil
			task.spawn(thread, false, "timeout")
		end
	end)

	askRemote:FireClient(player, requestId, question)
	return coroutine.yield()
end

return ask
```

The server thread always resumes: either with the answer or with a timeout. Clean up `pending` entries for a player on `PlayerRemoving` in a real implementation.

## UnreliableRemoteEvent in practice

Good fits:

- Aim direction, look direction, cursor position (sent 10 to 20 times a second; a lost update is replaced by the next one).
- Cosmetic one-shots where missing one is harmless (a footstep puff, a muzzle flash for distant players).
- Server-to-client positions of many cheap objects (projectile visuals) when the authoritative state lives elsewhere.

Bad fits: anything that changes state permanently, anything the player paid for, the start or end of an ability (a lost "stop" message leaves an effect running forever), anything larger than about 1 KB.

Because order is not guaranteed, **sequence your messages** and ignore stale ones:

```lua
--!strict
-- Client: stream aim direction at 15 Hz through an UnreliableRemoteEvent.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local aimRemote = game.ReplicatedStorage.Remotes.Aim :: UnreliableRemoteEvent
local SEND_INTERVAL = 1 / 15

local seq = 0
local accumulator = 0
local lastSent: Vector3? = nil

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < SEND_INTERVAL then return end
	accumulator = 0

	local camera = Workspace.CurrentCamera
	if not camera then return end
	local look = camera.CFrame.LookVector
	-- Skip if the change is too small to matter (saves the budget).
	if lastSent and lastSent:Dot(look) > 0.9995 then return end
	lastSent = look

	seq = (seq + 1) % 65536 -- small number, wraps
	aimRemote:FireServer(seq, look)
end)
```

```lua
--!strict
-- Server: accept only newer, finite, unit-length directions.
local aimRemote = game.ReplicatedStorage.Remotes.Aim :: UnreliableRemoteEvent
local lastSeq: { [Player]: number } = {}

local function isNewer(a: number, b: number): boolean
	-- wrap-around aware comparison for a 16-bit sequence
	local diff = (a - b) % 65536
	return diff > 0 and diff < 32768
end

aimRemote.OnServerEvent:Connect(function(player: Player, seq: unknown, look: unknown)
	if typeof(seq) ~= "number" or typeof(look) ~= "Vector3" then return end
	if seq ~= seq or seq < 0 or seq >= 65536 or seq % 1 ~= 0 then return end
	local m = look.Magnitude
	if m ~= m or m < 0.9 or m > 1.1 then return end -- rejects NaN and absurd vectors
	local prev = lastSeq[player]
	if prev and not isNewer(seq, prev) then return end -- stale or duplicate
	lastSeq[player] = seq
	player:SetAttribute("Aim", look.Unit) -- other clients read it; or relay at a fixed rate
end)

game:GetService("Players").PlayerRemoving:Connect(function(p) lastSeq[p] = nil end)
```

## Pattern: the server-validated relay

Many remotes exist only so one client can trigger an effect on others: a spell, an emote, an equip flourish. The naive relay ("receive, `FireAllClients` the same arguments") lets an exploiter spam effects, send malformed data that errors every client, or use abilities they do not own. The docs' wording: **the server must be a gatekeeper, not a relay.**

The pattern used in one production combat game for ability effects and equip flourishes:

1. The caster's client plays the animation and effects immediately (instant feedback).
2. It fires one RemoteEvent with a small id: the move or flourish name.
3. The server validates: rate limit (one flourish per second per player in that game), the id exists, it belongs to the weapon the player actually holds (read from server state, not from the client's Tool), the player is alive and not stunned, the ability is off cooldown.
4. The server relays **its own validated values** (player, id, server start time) to every other client, never the raw arguments.
5. Other clients play the effect, offset by the start time so they stay in sync.

```lua
--!strict
-- Server: validated relay for cosmetic ability effects.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local fxRequest = game.ReplicatedStorage.Remotes.FxRequest :: RemoteEvent
local fxPlay = game.ReplicatedStorage.Remotes.FxPlay :: RemoteEvent

local RateLimiter = require(game.ServerScriptService.Shared.RateLimiter)
local Loadout = require(game.ServerScriptService.Systems.Loadout) -- server truth for held weapon

local limiter = RateLimiter.new(1, 1) -- 1 per second, burst 1

fxRequest.OnServerEvent:Connect(function(player: Player, moveId: unknown)
	if typeof(moveId) ~= "string" or #moveId > 32 then return end
	if not limiter:allow(player) then return end
	local weapon = Loadout.getWeapon(player)
	if not weapon or not weapon.moves[moveId] then return end -- move must belong to held weapon
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local t0 = Workspace:GetServerTimeNow()
	for _, other in Players:GetPlayers() do
		if other ~= player then
			fxPlay:FireClient(other, player, moveId, t0) -- server-built values only
		end
	end
end)
```

A relayed custom animation system in the same game went further: speed changes were relayed immediately only when they changed by 6% or more, otherwise at most every 0.25 s, and weight changes at most 4 times a second. Late joiners asked once for the currently active tracks. Those numbers are a good starting budget for any relayed continuous state.

## Organising remotes

Rules that pay off as a project grows (see [[Project Structure and Bootstrapping]]):

- **The server creates all remotes at startup**, in one folder, from one list. Clients only `WaitForChild` the folder. Never let a client create a remote, and never scatter `Instance.new("RemoteEvent")` through systems.
- **One remote per purpose**, or a small number of multiplexed remotes with an action field. Either is fine; per-purpose remotes are easier to rate-limit and to honeypot.
- **Wrap access in a module** so every server handler passes through the same validation and rate-limit middleware.
- **Never look up remotes by a name that data can also use.**

That last rule comes from a real incident. In one production game, each weapon kit kept its remotes as children of the kit folder (`Origin`, `FX`, `LocalCast`) next to animation clips named after moves. An ultimate's clip was named `Origin`. `kit:FindFirstChild("Origin")` returned the clip instead of the RemoteEvent, and every damage request for that weapon silently failed. The fix was a list of **reserved child names** (`Attack`, `Origin`, `FX`, `LocalCast`, `Moves`, `ItemRig`) that content may never use, checked by the install tooling, plus keeping remotes in their own folder. Generalise it: wherever code finds a child by name in a folder that also holds content, either separate the folders or enforce reserved names with a check.

```lua
--!strict
-- ServerScriptService/Net.luau: server-side remote registry with middleware.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local unreliable: { [string]: UnreliableRemoteEvent } = {}

type Handler = (player: Player, ...any) -> ...any
type Middleware = (player: Player, name: string, ...any) -> boolean
local middleware: { Middleware } = {}

function Net.use(m: Middleware)
	table.insert(middleware, m)
end

local function passes(player: Player, name: string, ...: any): boolean
	for _, m in middleware do
		if not m(player, name, ...) then return false end
	end
	return true
end

function Net.event(name: string): RemoteEvent
	assert(not events[name], "duplicate remote " .. name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	events[name] = r
	return r
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	assert(not unreliable[name], "duplicate remote " .. name)
	local r = Instance.new("UnreliableRemoteEvent")
	r.Name = name
	r.Parent = folder
	unreliable[name] = r
	return r
end

function Net.func(name: string): RemoteFunction
	assert(not functions[name], "duplicate remote " .. name)
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = folder
	functions[name] = r
	return r
end

function Net.on(name: string, handler: Handler)
	local r: any = events[name] or unreliable[name]
	assert(r, "unknown remote " .. name)
	local signal: RBXScriptSignal = r.OnServerEvent
	signal:Connect(function(player: Player, ...)
		if not passes(player, name, ...) then return end
		local ok, err = pcall(handler, player, ...)
		if not ok then warn(("[Net] %s handler error: %s"):format(name, tostring(err))) end
	end)
end

function Net.handle(name: string, handler: Handler)
	local r = functions[name]
	assert(r, "unknown function " .. name)
	r.OnServerInvoke = function(player: Player, ...)
		if not passes(player, name, ...) then return nil end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(("[Net] %s invoke error: %s"):format(name, tostring(results[2])))
			return nil -- never leak the error text to the client
		end
		return table.unpack(results, 2, results.n)
	end
end

-- Call once after all systems registered their remotes.
function Net.publish()
	folder.Parent = ReplicatedStorage
end

return Net
```

Parenting the folder only after every system has registered means clients never see a half-built remote set, and the `assert` on duplicates catches two systems claiming one name.

## Honeypots and direction checks

The Roblox docs suggest two cheap detection tricks:

- **Honeypot remotes:** a remote with a tempting name that no legitimate client script ever fires. Any traffic on it is a near-certain exploiter. Log and kick.
- **Direction tracking:** remotes meant only for server-to-client use should never receive `OnServerEvent`. Connect a handler that flags any client that fires one.

Both are high-confidence signals with almost no false positives, unlike movement heuristics. See [[Exploits and Anti-Cheat]].

## Studio-only and test remotes

Every remote shipped in a live game is callable by every player. Debug remotes (`GiveCoins`, `SetLevel`, `SpawnBoss`) must either not exist in live servers or be gated by a server-side UserId allowlist on every call. One production game kept QA switches as **attributes on ServerStorage** (an isolated test save key, a simulated load failure flag) instead of remotes, so there was nothing for a client to call; its admin panel used a single RemoteFunction whose server handler re-checked an allowlist and throttled to one call per 0.08 s. Keep the allowlist in **one** module: the same game had the list in three places and had to remember to keep them in sync. See [[Rate Limiting and Abuse Prevention]].

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Budgeting remote traffic per remote instead of per client | About 500 client-to-server calls per second per client are shared by every remote of one type; a 30 Hz aim stream on a RemoteEvent delays that client's hit reports and purchases | Loss-tolerant streams on an UnreliableRemoteEvent (its own pool); hits, purchases and state on reliable RemoteEvents |
| `InvokeClient` for anything | Server threads hang forever on a malicious or crashed client | Event plus reply event with timeout |
| Identity, price or balance taken from the payload | Anyone pays as, or harms, another player; items for free | The caller is `OnServerEvent`'s first argument; the server reads price and balance |
| Relaying raw client arguments with `FireAllClients` | Spam, client crashes, unowned abilities | Validate, rate-limit, relay server-built values |
| Reliable remote fired per frame | Uses the 500/s budget, delays everything else, bandwidth | Unreliable at 10 to 20 Hz, or send on change |
| Unreliable remote for state changes | Lost "stop" messages, stuck effects | Reliable remote or attribute |
| Unreliable payload over 1,000 bytes | Silently dropped | Smaller payloads or reliable remote |
| Trusting an Instance argument | Fake tables, wrong objects, objects out of reach | Type check, `IsDescendantOf` the expected folder, ownership and distance checks |
| Yield in a handler between check and write | Two requests both pass the check: duplication | Mark state before yielding; per-player busy flag |
| Remote found by a name content can reuse | Wrong object returned, silent breakage | Separate folders, reserved names, install-time checks |

## Checklist

- [ ] Client send rates budgeted per client: about 500 calls per second shared by all remotes of one type (reliable and unreliable pools are separate).
- [ ] All remotes created by the server, in one folder, from one list.
- [ ] No `InvokeClient` anywhere.
- [ ] Every argument after the automatic `Player` is attacker-controlled: check type, value (NaN, inf, length), context and rate, then act.
- [ ] Unreliable remotes carry small, sequenced, loss-tolerant data only.
- [ ] Relays send server-built values to other clients, never the caller's raw arguments.
- [ ] Debug remotes absent from live servers or allowlisted on the server.
- [ ] A honeypot remote and direction checks log suspicious clients.

## See also
[[Client-Server Model]] · [[Replication Rules]] · [[Server Authority and Validation]] · [[Rate Limiting and Abuse Prevention]] · [[Exploits and Anti-Cheat]] · [[Buffers and Binary Data]] · [[Network Performance]] · [[Replication and Ownership]] · [[Frameworks - Knit Matter and Others]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Secure Remotes]] · Cookbook - Remotes and Networking · [[Remote Abuse Patterns and Rate Limiting in Practice]] · Network Bandwidth Budgets and Measuring Them · How Exploits Work - The Client Boundary · Official Docs - Scripting and Luau
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[RemoteEvent - Engine Reference Card]] · [[Cookbook - Remotes and Networking]] · [[AI Pitfalls - Networking and Security]] · [[Interest Management and Per-Player Replication]] · [[Cross-Server Messaging]] · [[Snapshot Interpolation for Custom Replication]]
<!-- related:end -->
