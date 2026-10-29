---
tags: [architecture, project-structure, bootstrapping, modules, workflow, type/guide, area/networking, level/intermediate, area/scripting, api/Player]
---
# Project Structure and Bootstrapping

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Many loose Scripts -> One entry point, modules
> - Avoid: `PlayerAdded` without the existing-players loop -> Handle both
> - Avoid: Systems yield in `init` -> Yield only in `start`
> - One server entry, one client entry, everything else modules.
> - Deterministic two-phase bootstrap with error isolation and timing.
> - Remotes created by the server and published after all systems registered.
>
> Cost: TL;DR ~140 tok · whole note ~5.2k tok. Read more: ## Server bootstrap: two phases · ## Production lessons that shape structure · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Roblox game that survives a year of development has a small number of entry points, one obvious home for every piece of code, a deterministic start-up order, and remotes treated as a typed API. A game without those has hundreds of loose Scripts racing each other at join, systems that only work if another script happened to run first, and a 200,000 character file nobody dares to touch. This note gives the layout, the two-phase bootstrap for server and client, how to register remotes and config, how to load fast, and the production lessons (source size limits, require caching, reserved names, test flags, sandboxed checks) that shape structure in practice.

Related: [[Module Scripts and Requiring]], [[Script Types and Run Context]], [[External Tooling - Rojo Wally Selene StyLua]], [[Frameworks - Knit Matter and Others]].

## The layout

```text
ReplicatedFirst/
  Boot.client.luau            loading screen + client bootstrap kick-off
ReplicatedStorage/
  Shared/
    Types.luau                types that cross the boundary
    Config/                   tunables safe for clients to read
    Util/                     pure functions (maths, formatting, curves)
    Net.luau                  client-side remote access (waits for Remotes)
  Assets/                     models, VFX and sounds clients clone
  Remotes/                    created by the server at start (not in the place file)
ServerScriptService/
  Main.server.luau            THE server entry point
  Systems/                    one ModuleScript per system (PlayerData, Shop, Combat...)
  Shared/                     server-only helpers (Guard, RateLimiter, Net)
ServerStorage/
  Templates/                  NPCs, drops, server-spawned models
  Secret/                     server-only config (admin list, codes, odds)
StarterPlayer/StarterPlayerScripts/
  Main.client.luau            THE client entry point
  Controllers/                one ModuleScript per client concern (HUD, Input, CombatFX)
```

Principles:

- **Exactly one server Script and one client LocalScript** (plus a tiny boot script in ReplicatedFirst if you have a loading screen). Everything else is a ModuleScript. Many loose Scripts mean uncontrolled execution order, duplicated service lookups and hidden coupling.
- **Server logic never lives in replicated containers.** ReplicatedStorage is readable and decompilable (Roblox docs, "Access control and confidentiality"); server modules there leak your rules.
- **Shared code is pure.** A module required by both sides should be functions and data, not state. If it holds state, each side has its own copy anyway.
- **Assets live where their spawner lives.** Client-cloned VFX in ReplicatedStorage; server-spawned NPC templates in ServerStorage (they replicate when the server parents them into Workspace).
- **Per-instance data in attributes, behaviour in a manager.** No Script inside each chest; one Chest system that handles every tagged chest ([[CollectionService Patterns]]).

With Rojo, this maps to `src/shared`, `src/server`, `src/client` folders; see [[External Tooling - Rojo Wally Selene StyLua]].

## Server bootstrap: two phases

```lua
--!strict
-- ServerScriptService/Main.server.luau
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Shared.Net)

type System = {
	init: ((self: System) -> ())?,
	start: ((self: System) -> ())?,
	[string]: any,
}

-- Explicit order where it matters; the rest alphabetical for determinism.
local ORDER = { "PlayerData", "Inventory", "Shop", "Combat" }

local systems: { [string]: System } = {}
local names: { string } = {}

for _, module in ServerScriptService.Systems:GetChildren() do
	if module:IsA("ModuleScript") then
		local t0 = os.clock()
		local ok, result = pcall(require, module)
		if ok then
			systems[module.Name] = result
			table.insert(names, module.Name)
		else
			warn(("[Boot] require %s failed: %s"):format(module.Name, tostring(result)))
		end
		local ms = (os.clock() - t0) * 1000
		if ms > 50 then warn(("[Boot] require %s took %.0f ms"):format(module.Name, ms)) end
	end
end

local rank: { [string]: number } = {}
for i, n in ORDER do rank[n] = i end
table.sort(names, function(a, b)
	local ra, rb = rank[a] or math.huge, rank[b] or math.huge
	if ra ~= rb then return ra < rb end
	return a < b
end)

-- Phase 1: init. Synchronous: create remotes, wire dependencies, read config. No yielding.
for _, n in names do
	local s = systems[n]
	if s.init then
		local ok, err = pcall(s.init, s)
		if not ok then warn(("[Boot] %s.init failed: %s"):format(n, tostring(err))) end
	end
end

-- All remotes exist now; publish them to clients in one go.
Net.publish()

-- Phase 2: start. Long-running work in its own thread, so one slow system does not block others.
for _, n in names do
	local s = systems[n]
	if s.start then
		task.spawn(function()
			local ok, err = pcall(s.start, s)
			if not ok then warn(("[Boot] %s.start failed: %s"):format(n, tostring(err))) end
		end)
	end
end
```

Why two phases: every system's `init` (create remotes, connect to other systems' signals, read config) completes before any system's `start` (loops, `PlayerAdded` handling, spawning). That removes the "system A used system B before B was ready" class of bugs without a framework. It is what frameworks like Knit formalised (`KnitInit`, `KnitStart`).

A system module:

```lua
--!strict
-- ServerScriptService/Systems/Shop.luau
local ServerScriptService = game:GetService("ServerScriptService")
local Net = require(ServerScriptService.Shared.Net)
local Guard = require(ServerScriptService.Shared.Guard)
local RateLimiter = require(ServerScriptService.Shared.RateLimiter)

local Shop = {}
local PlayerData -- resolved in init, avoids a require cycle at load time

local limiter = RateLimiter.new(2, 4)
local ITEM = Guard.string(32)

function Shop:init()
	PlayerData = require(script.Parent.PlayerData)
	Net.func("Buy")
end

function Shop:start()
	Net.handle("Buy", function(player: Player, itemId: unknown)
		if not limiter:allow(player) then return false end
		if not ITEM(itemId) then return false end
		return PlayerData.tryBuy(player, itemId :: string)
	end)
end

return Shop
```

### Players who join before your code is ready

`Players.PlayerAdded` only fires for players who join after you connect. In Studio the first player often joins before your server scripts finish requiring. Always handle both:

```lua
local Players = game:GetService("Players")

local function onPlayer(player: Player) end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
```

## Client bootstrap

The client runs the same two phases over `Controllers/`, with three differences:

1. **Wait for what you need, once.** The client waits for `ReplicatedStorage.Remotes` (published by the server only after all remotes exist) and for its character if a controller needs it, with timeouts.
2. **Never block the loading screen on optional content.** Load the HUD first; load the shop, codex, settings panels and their images lazily the first time they open.
3. **Streaming:** do not wait for Workspace content in the bootstrap; controllers attach to tags as content streams ([[Instance Streaming]]).

```lua
--!strict
-- StarterPlayerScripts/Main.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if not remotes then
	warn("[Boot] Remotes never arrived; server bootstrap failed?")
	return
end

local controllers: { [string]: any } = {}
for _, module in script.Parent:WaitForChild("Controllers"):GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then controllers[module.Name] = result else warn(result) end
	end
end
for name, c in controllers do
	if type(c) == "table" and c.init then
		local ok, err = pcall(c.init, c)
		if not ok then warn(("[Boot] %s.init: %s"):format(name, tostring(err))) end
	end
end
for name, c in controllers do
	if type(c) == "table" and c.start then
		task.spawn(c.start, c)
	end
end
```

A loading screen in ReplicatedFirst can call `ReplicatedFirst:RemoveDefaultLoadingScreen()` and hide itself when the HUD controller reports ready. See [[Case Study - Fast Join and Deferred Loading]].

## Config: one source of numbers

- **Client-safe config** (display prices, cooldown lengths for UI sweeps, item names) in `ReplicatedStorage/Shared/Config`.
- **Server-only config** (drop odds if secret, admin allowlist, promo codes, anti-cheat thresholds) in ServerStorage or ServerScriptService.
- The server **never reads values back from the client copy**, and authoritative checks use the server's copy.
- Effective values (a cooldown after upgrades, a price after discounts) come from one server function. One production game multiplied cooldown upgrades separately in five places (client bar, server validator, a universal abilities module, a move list UI, a support system); every new modifier had to be added to all five.

Live-tunable config (change values without republishing) is covered in [[Global State and Live Config]].

## Production lessons that shape structure

### The 200,000 character source limit

A Script's `Source` has a hard limit of 200,000 characters (observed in one production game when edits started failing; treat as measured). That game's original combat script reached about 199,000 characters and became effectively frozen: any edit risked crossing the limit. The fix was structural: a ModuleScript API next to it (`CombatAPI`), with new work going into modules that call the API. Long comments moved into a separate notes module. Lesson: split by responsibility long before a file is large; a module over a few thousand lines is a refactor signal.

### Hidden initialisation chains

In the same game, one central system required and initialised several others (worlds, hub activities, codes) inside its own start-up. It worked, but the order was invisible: adding a system meant knowing which other system's `init` to put it in. A flat, explicit bootstrap list (like `ORDER` above) makes order a visible decision.

### Reserved child names

Code that finds children by name breaks when content reuses the name. An ability clip named `Origin` shadowed a RemoteEvent named `Origin` in the same folder and silently broke every damage request for one weapon. The project then reserved `Attack`, `Origin`, `FX`, `LocalCast`, `Moves` and `ItemRig` and checked new content against the list at install time. Keep remotes in their own folder, and add a reserved-name check to any pipeline that drops content next to code. See [[RemoteEvents RemoteFunctions and Unreliable Remotes]].

### `require` caches, and the command bar has its own copy

`require` returns the same table for the same ModuleScript within one Luau VM. The Studio command bar and plugins run in a different context, so requiring a game module there gives a **separate** instance: changing it does not affect the running game, and edits to the module source are not seen by a game that already required it. To inspect current module state in Edit, one team required a **clone** of the module (parented beside the original, then destroyed). For live QA, use gated test remotes or ServerStorage flags instead ([[Command Bar and Studio Scripting]], [[Testing Strategies and Frameworks]]).

### Test flags on ServerStorage

QA switches as attributes on ServerStorage are invisible and unreachable to clients:

| Attribute | Effect in the reference project |
|---|---|
| `TestProfileKey` | Load and save an isolated test profile instead of the real one |
| `SimulateLoadFailure` | Make profile load fail, to test the "data failed" path |
| `ForceWeather`, `ForceClock`, `ForceIntro` | Force world state for testing |

The lesson attached: flags must be cleared after testing. One flag (`ForceIntro = true`) was found still set on the live place. Add a start-up warning when any test flag is set in a non-Studio server:

```lua
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	for name, value in ServerStorage:GetAttributes() do
		if string.sub(name, 1, 4) == "Test" or string.sub(name, 1, 5) == "Force" or string.sub(name, 1, 8) == "Simulate" then
			warn(("[Boot] Test flag %s = %s is set on a live server"):format(name, tostring(value)))
		end
	end
end
```

### Pre-save checks and sandboxed runs

The same team ran checks before saving any script: the source compiles (`loadstring` in a tool context), a use-before-definition scan (which caught real crashes such as calling a local function above its definition), the source length limit, and a clone-require of modules. For validation logic it ran the **real module source in a sandbox** (mocked services and players, driven by a test script), for example 26 out of 26 checks for a guard/parry system, without entering Play mode. Pure, dependency-injected modules make this possible: if a system reads `game:GetService` everywhere, it cannot be sandboxed. See [[Testing Strategies and Frameworks]].

## Dependency rules

- **Never use `_G` or `shared` for module communication.** Invisible dependencies, no types, order-dependent.
- **Avoid require cycles.** Luau errors on cyclic requires. Resolve dependencies in `init` (as `Shop` does above), extract a shared piece, or pass callbacks.
- **Expose signals, not internals.** `Inventory.ItemAdded:Connect(...)` instead of other systems reading `Inventory._items`. See [[Events Signals and Connections]].
- **One owner per piece of state.** If two systems write the same profile field, one of them is wrong.

## Where does this code go?

| Code | Home |
|---|---|
| Validates or mutates game state | `ServerScriptService/Systems` |
| Renders, plays effects, reads input | `StarterPlayerScripts/Controllers` |
| Pure logic both sides need | `ReplicatedStorage/Shared/Util` |
| Types crossing the boundary | `ReplicatedStorage/Shared/Types` |
| Client-safe numbers | `ReplicatedStorage/Shared/Config` |
| Secret numbers and lists | ServerStorage or server modules |
| Per-instance parameters | Attributes on the instance |
| Server-spawned templates | ServerStorage |
| Client-cloned assets | ReplicatedStorage |
| Privileged UI (admin) | ServerStorage, cloned into an allowlisted player's PlayerGui |

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Many loose Scripts | Random start-up failures | One entry point, modules |
| `PlayerAdded` without the existing-players loop | First player in Studio gets nothing | Handle both |
| Systems yield in `init` | Boot stalls behind one DataStore call | Yield only in `start` |
| Server modules in ReplicatedStorage | Logic visible to exploiters | Move to ServerScriptService |
| Giant scripts | Hit the source limit, merge conflicts | Split by responsibility early |
| Children found by names content can reuse | Silent breakage | Separate folders, reserved names |
| Test flags left on | Live players get test behaviour | Boot warning, checklist |

## Checklist

- [ ] One server entry, one client entry, everything else modules.
- [ ] Deterministic two-phase bootstrap with error isolation and timing.
- [ ] Remotes created by the server and published after all systems registered.
- [ ] No server logic or secrets in replicated containers.
- [ ] No `_G`, no require cycles.
- [ ] Boot warns about test flags on live servers.

## See also
[[Module Scripts and Requiring]] · [[Script Types and Run Context]] · [[Frameworks - Knit Matter and Others]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Case Study - Fast Join and Deferred Loading]] · [[Safe Changes in a Shared Place]] · [[Studio Tooling Architecture]] · [[Client-Server Model]]

## Nuances and edge cases

1. **Structure is for the team you will have, not the one you have.** A solo developer can keep everything in their head; a team of five cannot. The cost of a clear structure is small early and very large to retrofit. At minimum: one server entry point, one client entry point, modules by system, shared config in one place.
2. **Boot order is a dependency graph that grows.** Two-phase boot (create all systems, then start all systems) works until a system needs another's data during its own init. Keep init free of cross-system calls, and if a system genuinely needs another to be started first, express that explicitly in one ordered list, with a comment explaining why.
3. **Client boot competes with join time.** Every module required at client start delays when the player can act. Large UI trees, asset preloads and data requests in the client boot path are the main cause of slow joins on phones. Split client boot into "needed to play now" and "deferred" (see [[Case Study - Fast Join and Deferred Loading]]).
4. **Rojo and Studio-first projects structure differently.** With Rojo, the file system is the source of truth and Studio edits to scripts get overwritten. Studio-first teams keep scripts in the place and use packages for reuse. Mixing the two without rules leads to lost edits. Decide which one owns scripts and say so in the project's documentation.
5. **ReplicatedStorage is public.** Everything there is downloaded by every client and readable by exploiters. Shared modules should hold only what clients need: types, constants that are not secret, pure helpers. Server logic, drop tables with hidden odds and admin tools stay in server-only containers.
6. **Scale effects on structure.** A game with 5 systems can wire them with direct requires. At 40 systems, cycles and hidden dependencies appear; a lightweight dependency injection or a service registry helps, but full frameworks add their own learning cost (see [[Frameworks - Knit Matter and Others]]).
7. **Places in a universe share code poorly by default.** Multi-place games need a way to keep shared modules identical across places: packages, Rojo builds per place, or a build step. Without it, places drift and bugs fixed in one remain in another.
8. **Studio test settings leak into live.** Flags, test currencies and debug UIs toggled for testing are part of the place. A boot-time warning when any test flag is on, plus a release checklist, stops them from shipping.

The senior trade-off: structure has a cost in ceremony (more files, more indirection). Add structure when a real pain appears twice (merge conflicts in one big file, boot-order bugs, cycles), not in advance for its own sake.

## Common mistakes (advanced)

1. **Cross-system calls inside `init`.** Symptom: random boot failures depending on require order. Fix: init creates state only; cross-system work happens in `start`.
2. **Everything required at client start.** Symptom: slow joins on phones. Fix: defer non-essential modules until after the first playable frame.
3. **Secret data in ReplicatedStorage.** Symptom: exploiters know hidden odds or upcoming items. Fix: server-only containers and per-player data on request.
4. **Two sources of truth for scripts.** Symptom: edits disappear after a sync. Fix: one owner (files or Studio), documented.
5. **Copy-pasted shared code across places.** Symptom: bug fixed in the lobby but not in the arena place. Fix: packages or a build step.
6. **No single place for constants.** Symptom: the same number differs in three scripts after a balance change. Fix: one config module per domain.

## Related decisions

- [[Module Design and Dependency Injection]]: dependency patterns that keep boot order sane.
- [[Code Pipeline - Rojo Git and CI]]: file-based structure and builds.
- [[Packages and Asset Reuse]]: sharing code across places.
- [[Case Study - Fast Join and Deferred Loading]]: deferred client boot.
- [[How Exploits Work - The Client Boundary]]: what clients can read.
- [[Documentation and Knowledge Bases]]: writing down structure decisions.
- [[Scoping and Roles for Small Teams]]: who owns which system.
- [[Build Test and Release Pipeline]]: test flag checks in release.

## Connected notes
<!-- auto-links:start -->
[[Dependency Injection in Luau]] · Event Bus · Debugging Race Conditions and Yield Order · MCP Workflows for Scripting and Debugging · Advanced Luau Start Here · Error Handling - pcall xpcall and Promise Patterns
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Replication Rules]] · [[Server Authority and Validation]] · [[Entity Component Systems]] · [[Teleporting and Multi-Place Games]] · [[Server Lifecycle and Shutdown]] · [[Interest Management and Per-Player Replication]] · [[Cross-Server Messaging]] · [[Exploits and Anti-Cheat]]
<!-- related:end -->
