---
tags: [core-concept, streaming, performance, networking, world-building, type/reference, area/performance, level/beginner, api/CollectionService, area/networking]
---
# Streaming Radius

<!-- tldr:start -->
> [!tldr] TL;DR
> - Streaming lets big worlds run on phones and makes joins faster, because a client never holds the whole map.
> - The radius is a target, not a guarantee.
> - Bigger radius is not "safer". It raises memory and network cost on every device.
> - Model streaming modes change the unit of streaming.
>
> Cost: TL;DR ~110 tok · whole note ~1.1k tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

With **instance streaming** (`Workspace.StreamingEnabled`), the client only receives the parts of the world near its focus point. The **streaming radius** settings decide how near: `StreamingTargetRadius` is how far the engine tries to keep content loaded, and `StreamingMinRadius` is the area it treats as most important to load first (Roblox docs, "Instance streaming", as of October 2026; defaults are 1024 and 64 studs).

## Why it matters on Roblox

Streaming lets big worlds run on phones and makes joins faster, because a client never holds the whole map. It also means any client code that assumes a part exists can break: the part may not have arrived, or may have been streamed out when the player walked away.

## The nuance most people miss

1. **The radius is a target, not a guarantee.** On low memory the engine streams out sooner and may not reach the target radius. Code must handle missing instances at any distance.
2. **Bigger radius is not "safer".** It raises memory and network cost on every device. Pick the smallest radius that keeps your horizon looking right, and use low-detail stand-ins (`ModelStreamingMode` and level of detail) for far landmarks.
3. **Model streaming modes change the unit of streaming.** `Atomic` models arrive whole; `Persistent` models are always present for everyone; `PersistentPerPlayer` lets the server mark a model persistent for specific players. Use persistent sparingly, since it defeats streaming for that content.
4. **The server can pre-stream.** `Player:RequestStreamAroundAsync(position)` asks the engine to load an area before you teleport the player there, so they do not land in an empty world.
5. **WaitForChild without a timeout is a trap.** A child that is streamed out may never arrive, leaving a script waiting forever. Prefer `CollectionService` tag signals or attributes that react when instances stream in.

## Tiny example

```lua
-- Client: react to tagged coins as they stream in and out, never WaitForChild.
local CollectionService = game:GetService("CollectionService")
CollectionService:GetInstanceAddedSignal("Coin"):Connect(function(coin)
	startSpin(coin)
end)
CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(coin)
	stopSpin(coin)
end)
for _, coin in CollectionService:GetTagged("Coin") do startSpin(coin) end
```

## Where this shows up

- [[Instance Streaming]]: the full reference.
- [[Level of Detail and Model Streaming]]: far stand-ins and model modes.
- [[Infinite and Streamed Worlds]]: designing a world around streaming.
- [[CollectionService Patterns]]: the stream-safe way to find instances.
- [[Case Study - Fast Join and Deferred Loading]]: faster joins by loading less.
- [[Teleporting and Multi-Place Games]]: pre-streaming the destination.
- [[Spawn Points Safe Zones and Respawn Flow]]: spawning into loaded ground.
- [[Debugging Client-Server Desync]]: missing-on-client bugs.
- [[Memory Budgets and Leaks]]: the memory the radius buys.
- [[Zone and Biome Art Direction]]: designing horizons that survive streaming.
- [[Links - StreamingEnabled]]: external references.
- [[Racing Laps and Checkpoints End to End]]: fast movement outrunning streaming.
- [[Interest Management and Per-Player Replication]]: deciding what each player receives.

Related concepts: [[Replication Boundary]], [[Instance Count]], [[Frame Budget]].

## Connected notes
<!-- auto-links:start -->
[[Replication Rules]] · Debugging Race Conditions and Yield Order · Instances Attributes and Tags · Obby Checkpoints and Stage Saves End to End · Links - Checkpoints and spawning · Network Performance · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Server Authority]] · [[Object Pooling]] · [[Triangle Budget]] · [[Deterministic Simulation]] · [[Event Bus]] · [[Texel Density]] · [[Draw Calls]] · [[Onboarding Funnel]]
<!-- related:end -->
