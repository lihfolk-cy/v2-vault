---
tags: [architecture, security, validation, server-authority, combat, type/guide, area/networking, level/intermediate, api/ProcessReceipt, area/security, api/Player, api/Model]
---
# Server Authority and Validation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Validating only type, not value -> Add finiteness, range, integrality, length
> - Avoid: Trusting Tool attributes or names from the client's copy -> Look up by id in server state
> - Avoid: Yield between check and write -> Mark first; plan-then-apply; busy flags
> - Every remote handler starts with rate limit and `Guard.args`.
> - Every numeric argument is checked for NaN, infinity, range and integrality.
> - Every Instance argument is checked for type, location, ownership and distance.
>
> Cost: TL;DR ~160 tok · whole note ~5.1k tok. Read more: ## A reusable validation module · ## Pattern: KitGuard-style ability validation · ## Common mistakes · ## Checklist
<!-- tldr:end -->

**Server authority** means the server holds the true game state and decides every outcome that matters; clients render, predict and request. **Validation** is how the server turns untrusted requests into safe decisions. Together they are the only real security a Roblox game has: client-side checks can always be removed by an exploiter (Roblox docs, "Security and cheat mitigation tactics").

This note gives the layered validation model, a reusable validation module, the race conditions that cause most duplication bugs, a production-style ability validator ("KitGuard" pattern), data-driven hit validation, idempotent purchases and claims, and where the new server authority engine model fits. Exploit-specific defences are in [[Exploits and Anti-Cheat]]; rate limiting in [[Rate Limiting and Abuse Prevention]].

## What the server must own

| State | Owner | Client gets |
|---|---|---|
| Currency, inventory, unlocks, progression | Server (saved profile) | Mirrors for UI (attributes or remotes) |
| Cooldowns that gate power | Server | Copies for UI sweeps, which may be wrong |
| Health, damage, kills, rewards | Server | Replicated results |
| Prices, odds, drop tables | Server | Display copies; the server never reads them back |
| Match state, timers, round results | Server | Attributes with server timestamps |
| Character position | **Client** (owner) in the classic model | Cannot be owned by the server without the server authority model; validate it instead |

The last row is the gap. Everything else can be fully server-owned with ordinary code.

## The validation layers

Validate in this order and return early, silently, on any failure. The Roblox docs describe the same layers (type and structure, value, context and permission) plus rate limiting.

| Layer | Question | Examples of failures |
|---|---|---|
| 0. Rate | Is this player sending too often? | 300 casts per second |
| 1. Type | Is each argument the expected type? | Table instead of string; table shaped like an Instance |
| 2. Structure and size | Is it within size limits? | 100,000 character string; deep nested table |
| 3. Value | Is the number finite, integral, in range? Is the id known? | `NaN`, `inf`, `-5` quantity, unknown item id |
| 4. Permission | May this player do this at all? | Using a weapon they do not own; admin action by a non-admin |
| 5. Context | Is it possible right now? | Dead, stunned, out of range, on cooldown, shop closed |
| 6. Plausibility | Could a legitimate player have produced this? | Hit 80 studs away; three hits in 0.1 s |

### NaN and infinity

`NaN` is of type `"number"` and fails every comparison: `NaN < 0` is false and `NaN > max` is false, so a range check lets it through, and it then poisons every value it touches (Roblox docs show a trade exploit built on exactly this). `math.huge` passes type checks too. The docs recommend `math.isfinite()`; the portable check is:

```lua
local function isFinite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end
```

Vectors and CFrames can contain NaN components too; check `v.X == v.X` (or the magnitude) before using them.

## A reusable validation module

Write validators once and use them declaratively at the top of each handler. A tiny combinator module covers most needs without a dependency (the community library `t` does the same with more features).

```lua
--!strict
-- ServerScriptService/Shared/Guard.luau
local Guard = {}

export type Check = (value: unknown) -> boolean

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

function Guard.string(maxLen: number): Check
	return function(v)
		return typeof(v) == "string" and #v <= maxLen
	end
end

function Guard.int(min: number, max: number): Check
	return function(v)
		if typeof(v) ~= "number" then return false end
		local n = v :: number
		return finite(n) and n % 1 == 0 and n >= min and n <= max
	end
end

function Guard.number(min: number, max: number): Check
	return function(v)
		if typeof(v) ~= "number" then return false end
		local n = v :: number
		return finite(n) and n >= min and n <= max
	end
end

function Guard.unitVector(): Check
	return function(v)
		if typeof(v) ~= "Vector3" then return false end
		local m = (v :: Vector3).Magnitude
		return m == m and m > 0.95 and m < 1.05
	end
end

function Guard.position(maxAbs: number): Check
	return function(v)
		if typeof(v) ~= "Vector3" then return false end
		local p = v :: Vector3
		return finite(p.X) and finite(p.Y) and finite(p.Z)
			and math.abs(p.X) <= maxAbs and math.abs(p.Y) <= maxAbs and math.abs(p.Z) <= maxAbs
	end
end

function Guard.oneOf(set: { [string]: any }): Check
	return function(v)
		return typeof(v) == "string" and set[v :: string] ~= nil
	end
end

-- An Instance that really is inside `root` and of class `className`.
function Guard.instanceIn(root: Instance, className: string): Check
	return function(v)
		return typeof(v) == "Instance" and (v :: Instance):IsA(className) and (v :: Instance):IsDescendantOf(root)
	end
end

-- Validate a full argument list: Guard.args({checkA, checkB}, ...)
function Guard.args(checks: { Check }, ...: unknown): boolean
	if select("#", ...) > #checks then return false end -- extra arguments: reject
	for i, check in checks do
		if not check((select(i, ...))) then return false end
	end
	return true
end

return Guard
```

Usage at the top of a handler:

```lua
local SLOT = Guard.int(1, 6)
local AIM = Guard.unitVector()

castRemote.OnServerEvent:Connect(function(player, slot, aim)
	if not Guard.args({ SLOT, AIM }, slot, aim) then return end
	-- slot and aim are now safe to use
end)
```

Rejecting extra arguments is cheap insurance: legitimate clients never send them, and probing tools often do.

### Instances as arguments

An Instance argument is a pointer into the world the client chose. Check, in order: that it is an Instance (not a lookalike table), its class, that it lives where you expect (`IsDescendantOf` a known folder), that this player may act on it (their plot, their pet, a public chest), and the distance to it. The Roblox docs show a shop exploit where a fake table imitates a `Folder` with a `Price` child of value 0; the `typeof(item) == "Instance"` and `IsDescendantOf(itemDataFolder)` checks stop it. Prefer sending an id string and looking the object up on the server.

## Races: why validated code still duplicates items

Remote handlers run concurrently. If a handler yields between checking and writing, a second request from the same player can pass the same check:

```lua
-- VULNERABLE: two fast requests both see "not claimed" while the first is saving.
if not profile.claimed[questId] then
	saveAsync(player)                -- yields
	profile.claimed[questId] = true
	grantReward(player, questId)
end
```

Production rules that close this class of bug:

1. **Mark before you pay, and before you yield.** Set the claimed flag (or deduct the price) first, then do slow work. One production game's hub activities (a lucky spin, a daily chest, fishing) all marked the claim before paying.
2. **Plan, then apply with no yield.** Compute the full outcome into a plan table (which items to remove, which to add, the new balance), validate the plan, then apply it in one synchronous block. A crafting system in the same game used exactly this: "plan-then-apply with no yield", so no other request could observe a half-applied state.
3. **Per-player busy flags** for multi-step flows that must yield (trading, DataStore-backed purchases).
4. **Idempotency tokens** for anything the client might retry: the client generates a token per action; the server remembers recent tokens and returns the previous result for a repeat instead of doing the work twice. The crafting system above used token receipts so a retried "fuse" never fused twice.
5. **Exclusive locks across systems**: items in an active trade are untouchable by salvage, sell or fuse (the same game had a `TradeBusy` state that every consuming system respected).

```lua
--!strict
-- Idempotent action helper: same token, same result, work done once.
local Idempotency = {}

type Entry = { result: { any }, expires: number }
local seen: { [Player]: { [string]: Entry } } = {}
local TTL = 120 -- seconds a token is remembered

function Idempotency.run(player: Player, token: unknown, work: () -> ...any): ...any
	if typeof(token) ~= "string" or #token < 8 or #token > 64 then
		return nil
	end
	local now = os.clock()
	local mine = seen[player]
	if not mine then
		mine = {}
		seen[player] = mine
	end
	local prior = mine[token :: string]
	if prior and prior.expires > now then
		return table.unpack(prior.result) -- replay: do not repeat the work
	end
	-- Record a placeholder BEFORE doing work so a concurrent duplicate cannot start it again.
	local entry: Entry = { result = {}, expires = now + TTL }
	mine[token :: string] = entry
	entry.result = table.pack(work())
	return table.unpack(entry.result)
end

function Idempotency.forget(player: Player)
	seen[player] = nil
end

return Idempotency
```

(A concurrent duplicate that arrives while `work()` is still running gets an empty result; for flows that yield, combine this with a busy flag.)

## Pattern: KitGuard-style ability validation

In one production combat game every weapon "kit" (a set of abilities) had a server script, and every cast passed through a shared server validator. Its responsibilities, generalised:

| Check | Detail from production |
|---|---|
| The move exists on the weapon the player **currently holds** | Held weapon read from server state (the Tool is named consistently and carries a server-set id attribute), never from client arguments |
| The move is allowed for this item | Ultimates were refused below a rarity threshold, in the server validator as well as the client UI |
| Cooldown | Enforced at **0.95x** the authored cooldown, so normal latency jitter never rejects an honest cast while spam is still blocked |
| Character state | Alive, not stunned, not already casting |
| Cast in flight | The validator exposed "the current cast" so downstream damage code could attribute and scale hits to the move being cast |
| Damage clamps | Ability damage multipliers were clamped to a maximum before any per-move adjustments |

```lua
--!strict
-- ServerScriptService/Systems/AbilityGuard.luau
local Workspace = game:GetService("Workspace")

local Catalog = require(script.Parent.AbilityCatalog) -- server truth: weapons -> moves -> cooldowns
local Loadout = require(script.Parent.Loadout)         -- server truth: what each player holds

local COOLDOWN_TOLERANCE = 0.95 -- accept casts slightly early to absorb latency jitter

export type Cast = { player: Player, weaponId: string, moveId: string, startedAt: number }

local AbilityGuard = {}
local lastCast: { [Player]: { [string]: number } } = {}
local current: { [Player]: Cast } = {}

function AbilityGuard.tryCast(player: Player, moveId: unknown): Cast?
	if typeof(moveId) ~= "string" or #moveId > 40 then return nil end

	local weaponId = Loadout.heldWeapon(player)
	if not weaponId then return nil end
	local move = Catalog.move(weaponId, moveId :: string)
	if not move then return nil end -- not a move of the held weapon
	if move.isUltimate and not Catalog.allowsUltimate(weaponId) then return nil end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	if character and character:GetAttribute("Stunned") then return nil end
	if current[player] then return nil end -- one cast at a time

	local now = Workspace:GetServerTimeNow()
	local times = lastCast[player]
	if not times then
		times = {}
		lastCast[player] = times
	end
	local key = weaponId .. "/" .. (moveId :: string)
	local last = times[key]
	if last and now - last < move.cooldown * COOLDOWN_TOLERANCE then return nil end

	times[key] = now -- commit the cooldown BEFORE any yielding work
	local cast: Cast = { player = player, weaponId = weaponId, moveId = moveId :: string, startedAt = now }
	current[player] = cast
	return cast
end

function AbilityGuard.finish(cast: Cast)
	if current[cast.player] == cast then
		current[cast.player] = nil
	end
end

function AbilityGuard.current(player: Player): Cast?
	return current[player]
end

function AbilityGuard.clear(player: Player)
	lastCast[player] = nil
	current[player] = nil
end

return AbilityGuard
```

The same game had a gap worth learning from: cooldown scaling existed in several places (the client bar, the server validator, a universal abilities module, the move list UI). When a cooldown upgrade was added, every one of them had to multiply by it. Keep the **effective** cooldown in one server function and have UI ask for it.

## Data-driven hit validation

The server must decide hits without trusting the client's "I hit X". Two approaches:

**Server computes the hit.** The client sends "cast move M aimed at direction D". The server knows when M's hits land (from data: marker times exported at build time, or a table of hit frames), and at each hit time it runs its own query (a shape cast or distance and angle check) from the character's server position. One production game computed ability hits per segment on the server from shared timing data, so caster animation and server damage stayed in step without any client hit messages. See [[Markers and Events]] and [[Hitboxes and Hit Detection]].

**Client proposes, server verifies.** The client sends "I hit enemy E at time T". The server checks: E exists and is alive; the attacker had a swing in progress whose hit window contains T (with latency tolerance); distance from the attacker's server position to E is within reach plus tolerance; the angle is within the swing arc; the rate is plausible (swing pacing). The same game's swing pacing kept a per-player "bank" on the server that never refused honest clicks but capped sustained hits at the weapon's pace.

```lua
--!strict
-- Server: verify a client-proposed melee hit.
local Workspace = game:GetService("Workspace")

local REACH = 17        -- studs, includes latency margin (production value for 1.6x scaled characters)
local ARC_DOT = 0.2     -- cos of the half-angle of the accepted arc (about 78 degrees)
local LATE_GRACE = 0.25 -- seconds a hit may arrive after its window closed

type Swing = { startedAt: number, windowStart: number, windowEnd: number, hitTargets: { [Model]: boolean } }

local function verifyHit(player: Player, swing: Swing?, target: unknown): boolean
	if not swing then return false end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then return false end
	local enemy = target :: Model
	if not enemy:IsDescendantOf(Workspace.Enemies) then return false end
	if swing.hitTargets[enemy] then return false end -- one hit per target per swing

	local now = Workspace:GetServerTimeNow()
	local t = now - swing.startedAt
	if t < swing.windowStart or t > swing.windowEnd + LATE_GRACE then return false end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local enemyRoot = enemy.PrimaryPart
	if not root or not enemyRoot then return false end

	local offset = enemyRoot.Position - root.Position
	local dist = offset.Magnitude
	if dist > REACH then return false end
	if dist > 2 then
		local facing = root.CFrame.LookVector
		if facing:Dot(offset.Unit) < ARC_DOT then return false end
	end

	swing.hitTargets[enemy] = true
	return true
end

return verifyHit
```

Tolerance numbers are game-specific; measure them. In that game the player reach was raised from 13 to 17 studs and the ability range multiplier set to 1.35 after measuring how often honest hits were rejected under real latency.

## Purchases and grants

- **Developer products are granted only in `MarketplaceService.ProcessReceipt`.** The docs are explicit that `PromptProductPurchaseFinished` does not mean a purchase happened and must not be used to grant. A client remote "I bought product X" is a free-items exploit.
- **Game pass ownership** is checked on the server with `MarketplaceService:UserOwnsGamePassAsync`, cached per session, and refreshed after a purchase prompt closes.
- Receipts are idempotent: store processed `PurchaseId`s with the profile so a re-delivered receipt does not grant twice. See [[Developer Products and ProcessReceipt]] and [[Purchase Data and Receipts]].

## Admin and privileged actions

- An allowlist of UserIds (or group ranks) lives in **one** server module. Every privileged handler checks it on every call; the client UI's own check is decoration.
- Privileged UI code lives in ServerStorage and is cloned to the admin's PlayerGui, so other clients never receive it.
- Admin actions that touch other players (kick, give, teleport) log who did what to whom.

## The server authority model (engine feature)

Roblox now offers an engine-level server authority model (`Workspace.AuthorityMode = Server`): the server is the source of truth for the whole simulation, including characters; clients send inputs through the Input Action System and **predict** ahead, rolling back and resimulating on misprediction. Setup requires `NextGenerationReplication`, the input action system for player scripts, deferred signals, fixed simulation and streaming; core logic runs in `RunService:BindToSimulation()` callbacks on both sides; attributes on predicted instances are compared and mismatches trigger rollback (Roblox docs, "Server authority model"). The security docs call it "currently in beta" and the most reliable fix for movement and physics exploits (as of October 2026).

It changes the trade-offs in this note: movement validation largely disappears, but you must write simulation code that is deterministic enough to resimulate, put inputs through input actions instead of `UserInputService` in simulation code, and keep presentation in `RenderStepped`. Remote validation, economy rules and purchase handling stay exactly the same.

## Common mistakes

| Mistake | Fix |
|---|---|
| Validating only type, not value | Add finiteness, range, integrality, length |
| Trusting Tool attributes or names from the client's copy | Look up by id in server state |
| Yield between check and write | Mark first; plan-then-apply; busy flags |
| Cooldown multipliers scattered in many files | One server function for effective cooldown |
| Client tells server "I killed it, pay me" | Server witnesses the kill |
| Granting from `PromptProductPurchaseFinished` | `ProcessReceipt` only |
| Loud errors on bad input | Silent drop plus a log line; errors teach the exploiter |

## Checklist

- [ ] Every remote handler starts with rate limit and `Guard.args`.
- [ ] Every numeric argument is checked for NaN, infinity, range and integrality.
- [ ] Every Instance argument is checked for type, location, ownership and distance.
- [ ] No yield between a check and the state change it guards.
- [ ] Retried actions are idempotent.
- [ ] Damage and rewards are computed from server data only.
- [ ] Privileged actions check one allowlist on the server.

## See also
[[Client-Server Model]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Exploits and Anti-Cheat]] · [[Rate Limiting and Abuse Prevention]] · [[Hitboxes and Hit Detection]] · [[Combat Systems Architecture]] · [[Ability Kits Architecture]] · [[Developer Products and ProcessReceipt]] · [[Economies and Currencies]]

## Connected notes
<!-- auto-links:start -->
[[Server Authority]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · Cookbook - Remotes and Networking · [[Client Prediction and Reconciliation for Combat]] · Detecting Combat Exploits - Reach Rate and Aim · Idempotency
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cookbook - Remotes and Networking]] · [[Network Ownership]] · [[Project Structure and Bootstrapping]] · [[Replication Rules]] · [[Interest Management and Per-Player Replication]] · [[Frameworks - Knit Matter and Others]] · [[Snapshot Interpolation for Custom Replication]] · [[Teleporting and Multi-Place Games]]
<!-- related:end -->
