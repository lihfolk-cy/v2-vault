---
tags: [core-concept, architecture, luau, signals, type/reference, area/scripting, level/beginner, area/liveops]
---
# Event Bus

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox games grow by adding systems that react to the same moments: a kill updates quests, achievements, analytics, a kill...
> - Use a pure-Luau signal, not BindableEvents, inside one context.
> - A bus is not a network. A server-side bus does not reach clients.
> - Too much indirection hides flow. If everything is an event, nobody can follow what happens when a player buys an item.
>
> Cost: TL;DR ~140 tok · whole note ~990 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

An **event bus** is a shared channel where systems publish named events ("PlayerLevelledUp", "EnemyKilled") and other systems subscribe to them, without either side knowing about the other. The quest system hears "EnemyKilled" without the combat system ever calling the quest system.

## Why it matters on Roblox

Roblox games grow by adding systems that react to the same moments: a kill updates quests, achievements, analytics, a kill feed and a sound. Without a bus, the combat code ends up calling six modules directly, every new feature edits combat, and require cycles appear. A bus keeps the dependency pointing one way.

## The nuance most people miss

1. **Use a pure-Luau signal, not BindableEvents, inside one context.** `BindableEvent` copies table arguments (losing metatables and identity, Roblox docs, "Argument limitations for bindables and remotes") and adds overhead. A small Luau signal passes references and is faster. Keep bindables for crossing script environments where needed.
2. **A bus is not a network.** A server-side bus does not reach clients. Crossing the [[Replication Boundary]] still needs explicit remotes, chosen per event.
3. **Too much indirection hides flow.** If everything is an event, nobody can follow what happens when a player buys an item. Use the bus for broadcast facts ("this happened"), and direct calls for commands that expect a result ("give this item").
4. **Order between subscribers is not a contract.** If the achievement handler must run after the stats handler, that is a hidden dependency; make it explicit.
5. **Errors in one subscriber must not stop others.** Wrap each handler call or spawn handlers with `task.spawn` so one bug does not break the whole event.
6. **Disconnect on cleanup.** Per-player subscriptions that are never disconnected leak memory and fire for players who have left.

## Tiny example

```lua
local Bus = {}
local handlers: { [string]: { (...any) -> () } } = {}

function Bus.on(name: string, fn: (...any) -> ())
	handlers[name] = handlers[name] or {}
	table.insert(handlers[name], fn)
	return function() -- disconnect
		local list = handlers[name]
		local i = table.find(list, fn)
		if i then table.remove(list, i) end
	end
end

function Bus.emit(name: string, ...: any)
	for _, fn in table.clone(handlers[name] or {}) do
		task.spawn(fn, ...)
	end
end

return Bus
```

## Where this shows up

- [[Events Signals and Connections]]: connection basics.
- [[Building a Signal Library]]: a robust signal to put behind the bus.
- [[Module Design and Dependency Injection]]: alternatives and companions to a bus.
- [[Project Structure and Bootstrapping]]: where the bus lives.
- [[Frameworks - Knit Matter and Others]]: how frameworks handle events.
- [[Quests and Objectives]]: quests listening to game events.
- [[Badges and Achievement Design]]: achievements as subscribers.
- [[Economy Telemetry and Balancing Live]]: analytics as a subscriber.
- [[Hunting Memory Leaks Step by Step]]: leaked subscriptions.
- [[Debugging Race Conditions and Yield Order]]: subscriber ordering bugs.
- [[Code Review for Luau Teams]]: reviewing event-heavy code.
- [[Quest Chain System End to End]]: a worked build driven by events.

Related concepts: [[Dependency Injection in Luau]], [[Telemetry Events]], [[Replication Boundary]].

## Connected notes
<!-- auto-links:start -->
[[Advanced Luau Start Here]] · Official Docs - Game Systems · [[Core Concepts Start Here]] · Error Handling - pcall xpcall and Promise Patterns · Module Scripts and Requiring · Subscriptions and Premium Payouts
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Feature Flags]] · [[Server Authority]] · [[Onboarding Funnel]] · [[Streaming Radius]] · [[Faucets and Sinks]] · [[Rate Limiting]] · [[Session Length]] · [[Instance Count]]
<!-- related:end -->
