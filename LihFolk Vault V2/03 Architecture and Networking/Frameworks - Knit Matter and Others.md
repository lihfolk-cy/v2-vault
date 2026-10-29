---
tags: [architecture, frameworks, libraries, knit, ecs, networking, type/guide, area/networking, level/advanced, api/CollectionService]
---
# Frameworks - Knit Matter and Others

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Starting a new game on an archived framework -> Plain modules or a maintained option
> - Avoid: Treating framework client methods as safe -> Middleware: validation and rate limits on every exposed method
> - Avoid: Mixing frameworks and loose scripts -> Pick one structure and migrate fully
> - The project has a written structure convention and one exemplar system.
> - Every dependency is pinned, reviewed and actively maintained (or small enough to own).
> - The client-server boundary is visible in names, and every exposed method passes middleware.
>
> Cost: TL;DR ~180 tok · whole note ~3.6k tok. Read more: ## Small utility libraries worth knowing · ## A framework-free core in one page · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has no official game framework. The community has produced several, plus many small libraries that solve one problem well (signals, promises, cleanup, networking, state, UI). Choosing among them is mostly a question of what problem you have, how big the team is, and how long you will maintain the game. This note explains what frameworks actually give you, the main options and their status as of October 2026, when a framework hurts, and how to get the same benefits with plain modules.

Library status changes quickly. Facts marked "verified" were checked against the project's public repository in October 2026; everything else is a description of the library's purpose, and you should check its repository before adopting it.

## What a framework is for

Strip away the branding and Roblox frameworks provide some subset of:

| Concern | What it means | Without a framework |
|---|---|---|
| Lifecycle | Every system gets `init` then `start`, in a known order | The two-phase bootstrap in [[Project Structure and Bootstrapping]] |
| Service location | Systems find each other by name | `require` the module |
| Networking | Declare server methods, call them from the client as if local | A `Net` module over RemoteEvents ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]) |
| Middleware | Validation and rate limiting on every remote | Middleware list in `Net` |
| Component binding | Behaviour attached to tagged instances | CollectionService managers ([[CollectionService Patterns]]) |
| State management | Reactive or immutable state stores | Signals, attributes |
| Data model | Entities and components instead of objects | Tables, or an [[Entity Component System\|ECS]] library ([[Entity Component Systems]]) |

If you already have a clean bootstrap, a remote wrapper with middleware and a tag-manager pattern, you have most of a framework. The remaining value of a framework is **shared convention**: new team members know where things go.

## Knit

**What it was:** a lightweight framework by Stephen Leitnick (Sleitnick): server **Services** and client **Controllers**, each with `KnitInit` and `KnitStart`; services expose a `Client` table whose functions and signals become remotes automatically; middleware on remote calls.

**Status (verified):** the repository was **archived on July 31, 2024**, and its README states it is no longer maintained and will receive no updates.

What that means in practice:

- Existing Knit games keep working; Knit is small and has no runtime dependency on its repository.
- New projects should not start on it. You inherit any bug yourself, and newer engine features (UnreliableRemoteEvent, typed Luau improvements) are not integrated.
- Its **ideas** are still good: two phases, one place per system, client-facing API declared next to server code, middleware.

Migrating off Knit is mechanical: each Service becomes a ModuleScript with `init` and `start`; `Knit.GetService("X")` becomes `require(Systems.X)`; the `Client` table becomes explicit `Net.on` / `Net.handle` registrations; Controllers likewise. Do it system by system, keeping remote names stable so clients and servers of mixed versions still talk during the rollout.

## Matter and jecs (ECS libraries)

**Matter** is "a modern ECS library for Roblox" (verified, README). It was pioneered by evaera and is now maintained under the `matter-ecs` organisation (verified). It pairs an ECS world with **systems** run each frame by a scheduler, "topologically aware" hooks (`useEvent`, `useThrottle` style helpers that keep per-system state) and a debugger.

**jecs** is "a fast, portable Entity Component System for Luau" (verified, README), by Ukendio: archetype-based storage, first-class **entity relationships** (pairs like `ChildOf(parent)`), a typed API, no dependencies; the README claims around 800,000 entities at 60 FPS (an author's benchmark, not independently measured here).

Both are covered conceptually in [[Entity Component Systems]], including when an ECS helps and when it is overkill. Their APIs have changed between versions; read the current docs rather than old tutorials.

## Flamework (roblox-ts)

Flamework is a framework for **roblox-ts** (TypeScript compiled to Luau): decorators for services and controllers, dependency injection, generated networking with runtime type guards derived from TypeScript types, and component binding. It is a strong option if your team chooses TypeScript; it is not usable from plain Luau. Adopting roblox-ts is a bigger decision than any framework (toolchain, hiring, debugging compiled output). Check its repository for current status.

## Networking libraries

A family of libraries replaces hand-written remotes with declared, typed, compact packets:

| Kind | What it does | Examples (check status) |
|---|---|---|
| IDL compilers | You write a schema file; a tool generates typed Luau for both sides that serialises into buffers | Zap, Blink |
| Runtime packet libraries | Declare packet structures in Luau; the library packs them into buffers | ByteNet and similar |
| Wrapper libraries | Friendlier APIs over RemoteEvents, batching, middleware | Many; quality varies |

Benefits are real for games with heavy traffic (shooters, physics sims, many NPCs): typed both ends, validation of shape built in, much smaller payloads through buffers ([[Buffers and Binary Data]]), batching per frame. Costs: a build step (for IDL tools), less transparent debugging, and **shape validation is not semantic validation**: a typed `u8` slot still needs "does this player own that slot?". For most games, plain remotes with a `Net` wrapper and sensible batching are enough; reach for these when the Network panel of the Developer Console says bandwidth is your problem ([[Network Performance]]).

## Small utility libraries worth knowing

| Problem | Library type | Notes |
|---|---|---|
| Custom events | Signal implementations (GoodSignal and descendants) | A tiny Signal module is enough for most games; see [[Events Signals and Connections]] |
| Cleanup | Trove, Janitor, Maid | Track connections and instances, clean in one call; essential against leaks ([[Memory Budgets and Leaks]]) |
| Async flows | Promise libraries | Chainable async with cancellation; heavier than `task` + coroutines; see [[Task Library Coroutines and Yielding]] |
| Runtime type checks | `t` | Declarative validators for remote arguments; or the small `Guard` module in [[Server Authority and Validation]] |
| Player data | [[ProfileStore]] (successor of ProfileService) and similar | Session locking and autosave; see [[Session Locking and Profile Libraries]] |
| UI | React-Lua, Fusion, Vide | See [[Declarative UI - React-Lua and Fusion]] |
| State containers | Rodux, Reflex, Charm | Store patterns for UI-heavy games |
| Testing | TestEZ, Jest-Lua | See [[Testing Strategies and Frameworks]] |

Install them through Wally with pinned versions ([[External Tooling - Rojo Wally Selene StyLua]]), and read the code you ship: a dependency in ReplicatedStorage is decompilable, and a dependency with a bug is your bug. Do not pull libraries from random Toolbox models ([[Creator Store and Toolbox Safety]]).

## Decision table

| Situation | Recommendation |
|---|---|
| Solo developer, first or second game | Plain modules, two-phase bootstrap, `Net` wrapper; add utilities (Signal, Trove) as needed |
| Small team, Luau | Same, plus a written convention document and one fully worked exemplar system everyone copies |
| Existing Knit game | Keep it; migrate gradually only if you are changing the systems anyway |
| Team that wants TypeScript | roblox-ts with Flamework |
| Hundreds to thousands of similar simulated things (projectiles, units, crops) | An ECS for that subsystem (jecs or Matter), not necessarily the whole game |
| Very high network traffic | A typed buffer-based networking library, measured before and after |
| UI-heavy game (simulators, tycoons with many menus) | A declarative UI library and a state store |

## When frameworks hurt

- **Magic networking hides cost and trust.** If calling `ShopService:Buy()` from the client looks like a local call, juniors forget it is an untrusted, rate-unlimited network request. Make the boundary visible in names (`Client.RequestBuy`) and require middleware.
- **Global service location becomes global state.** "Any system can get any service" turns into a dependency graph nobody can draw.
- **Lifecycle lock-in.** Framework start-up order replaces yours; debugging "why is this nil" means reading framework code.
- **Abandonment.** Knit is the cautionary example: a popular choice became unmaintained. Small, readable dependencies are easier to own when that happens.
- **Two paradigms in one codebase.** Half the systems in a framework and half in loose scripts is worse than either.

## A framework-free core in one page

The pieces elsewhere in this section already form a framework:

| Piece | Note |
|---|---|
| Two-phase bootstrap for server and client | [[Project Structure and Bootstrapping]] |
| `Net` registry with middleware | [[RemoteEvents RemoteFunctions and Unreliable Remotes]] |
| `Guard` validators | [[Server Authority and Validation]] |
| `RateLimiter` | [[Rate Limiting and Abuse Prevention]] |
| Tag managers | [[CollectionService Patterns]] |
| Attribute-driven presentation | [[Replication Rules]] |

A minimal signal completes it:

```lua
--!strict
-- ReplicatedStorage/Shared/Signal.luau: a small synchronous signal.
export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local conn = { Connected = true }
	function conn.Disconnect(c)
		if not c.Connected then return end
		c.Connected = false
		local i = table.find(handlers, fn)
		if i then table.remove(handlers, i) end
	end
	table.insert(handlers, fn)
	return conn
end

function Signal:Fire(...)
	-- Copy so handlers may disconnect during firing; spawn so one error does not stop the rest.
	for _, fn in table.clone(self._handlers) do
		task.spawn(fn, ...)
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
```

(If the same function is connected twice, `Disconnect` removes one occurrence; for production use a linked-list signal such as the GoodSignal pattern, which also reuses threads for speed.)

## Evaluating a library before adopting it

Run through these questions before a dependency enters the codebase:

| Question | Why it matters |
|---|---|
| When was the last commit or release, and is the repository archived? | Knit shows that popular does not mean maintained |
| Can one person on the team read and fix the whole thing in a day? | If not, you depend on the maintainer for every bug |
| Does it run on both sides, and what ends up in ReplicatedStorage? | Client code is decompilable; server logic must not ship there |
| Does it hide network calls behind local-looking APIs? | Hidden remotes skip validation in reviews |
| Does it support strict typing? | Untyped boundaries spread `any` through your code ([[Luau Type System and Strict Mode]]) |
| What does it allocate per frame? | Signal or ECS libraries in hot paths show up in the MicroProfiler ([[MicroProfiler Guide]]) |
| How do you remove it later? | Wrap it behind your own small interface so a swap touches one module |

The last row is the cheapest insurance: a `Net`, `Signal` or `Store` module of your own that delegates to the library means the rest of the game never imports the library directly.

## Production note

The reference project used no third-party framework. It had a central service that started other systems, a shared remotes folder, per-weapon kit modules with a common server validator, and attribute-driven client presentation. What hurt was not the absence of a framework but the absence of **explicit structure**: implicit start-up chains, values multiplied in several places, a combat script that grew to the source limit, and names shared between content and remotes. A framework would have prevented some of that by convention; a written convention plus the patterns above would have prevented the same things.

## Common mistakes

| Mistake | Fix |
|---|---|
| Starting a new game on an archived framework | Plain modules or a maintained option |
| Treating framework client methods as safe | Middleware: validation and rate limits on every exposed method |
| Mixing frameworks and loose scripts | Pick one structure and migrate fully |
| Copying libraries from the Toolbox | Wally with pinned versions, reviewed source |
| Adopting an ECS for a game with ten objects | Plain tables and instances |

## Checklist

- [ ] The project has a written structure convention and one exemplar system.
- [ ] Every dependency is pinned, reviewed and actively maintained (or small enough to own).
- [ ] The client-server boundary is visible in names, and every exposed method passes middleware.
- [ ] Framework choice revisited when the game's scale or team changes.

## See also
[[Project Structure and Bootstrapping]] · [[Entity Component Systems]] · [[Module Scripts and Requiring]] · [[Events Signals and Connections]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Declarative UI - React-Lua and Fusion]] · [[Session Locking and Profile Libraries]] · [[Network Performance]]

## Connected notes
<!-- auto-links:start -->
[[Links - OOP and module design]] · Dependency Injection in Luau · Links - Remote events and functions · Links - UI frameworks · Module Design and Dependency Injection · Links - Services
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Client-Server Model]] · [[Snapshot Interpolation for Custom Replication]] · [[Interest Management and Per-Player Replication]] · [[Server Lifecycle and Shutdown]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Instance Streaming]] · [[Network Ownership]] · [[Client Prediction and Reconciliation for Combat]]
<!-- related:end -->
