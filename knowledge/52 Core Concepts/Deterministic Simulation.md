---
tags: [core-concept, networking, procedural, math, testing]
---
# Deterministic Simulation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Determinism lets you send *seeds and inputs* instead of *state*: generate a whole dungeon on every client from one number...
> - Use a fixed timestep. Stepping a simulation with the frame's `dt` gives different results at 30 and 60 fps.
> - One `Random` object per stream. If combat and loot draw from the same generator, adding one extra combat roll shifts every...
> - Sort before iterating. When iterating a dictionary matters for the result, collect keys into an array and sort them first.
>
> Cost: TL;DR ~160 tok · whole note ~970 tok. Read more: ## What is and is not deterministic on Roblox · ## The nuance most people miss
<!-- tldr:end -->

A simulation is **deterministic** when the same starting state and the same inputs always produce exactly the same result. If two machines run a deterministic simulation from the same seed with the same inputs, they stay in sync without sending the results to each other.

## Why it matters on Roblox

Determinism lets you send *seeds and inputs* instead of *state*: generate a whole dungeon on every client from one number, replay a bug from a recorded input log, or run a 2D minigame on the client and verify it on the server by replaying it. It saves bandwidth and makes tests reproducible. It also has hard limits on Roblox, and assuming determinism where it does not exist causes desync bugs.

## What is and is not deterministic on Roblox

| Deterministic (in practice) | Not deterministic |
|---|---|
| `Random.new(seed)` sequences (Roblox docs: same seed, same sequence) | The physics engine across machines and frames |
| Pure Luau arithmetic on the same inputs | Anything depending on frame time `dt` |
| `math.noise` for the same inputs | Iteration order of `pairs` over dictionaries (do not rely on it) |
| Your own fixed-step code | Event and remote arrival order across clients, `os.clock`, `tick` |

## The nuance most people miss

1. **Use a fixed timestep.** Stepping a simulation with the frame's `dt` gives different results at 30 and 60 fps. Accumulate time and step in fixed increments (for example 1/60 s).
2. **One `Random` object per stream.** If combat and loot draw from the same generator, adding one extra combat roll shifts every later loot roll. Give each system its own seeded `Random`.
3. **Sort before iterating.** When iterating a dictionary matters for the result, collect keys into an array and sort them first.
4. **Never trust the client's result.** Determinism lets the server *check* a client's claimed result by replaying inputs; it does not make the claim trustworthy.
5. **Do not try to make Roblox physics deterministic.** For anything that must match exactly, write your own simple simulation (kinematic movement, grid logic) instead of using constraints and collisions.

## Tiny example

```lua
-- Same seed on server and every client: identical layouts, one number sent.
local function generateRooms(seed: number, count: number)
	local rng = Random.new(seed)
	local rooms = {}
	for i = 1, count do
		rooms[i] = { w = rng:NextInteger(4, 10), h = rng:NextInteger(4, 10) }
	end
	return rooms
end
```

## Where this shows up

- [[Seeds Determinism and Reproducible Worlds]]: the deep dive for generation.
- [[Dungeon and Room Generation]]: seeded dungeons.
- [[Noise Functions and Terrain Generation]]: deterministic noise.
- [[Client Prediction and Reconciliation for Combat]]: replaying inputs.
- [[2D Collision Physics and Platformer Movement]]: fixed-step simulation.
- [[Debugging Physics and Network Ownership]]: why physics differs between machines.
- [[Automated Testing with TestEZ and Jest-Lua]]: reproducible tests with fixed seeds.
- [[Simulating an Economy Before Launch]]: repeatable simulations.
- [[Frame Order and RunService Timing]]: where to step a fixed loop.
- [[Wave Function Collapse on Roblox]]: seeded constraint solving.
- [[Debugging Race Conditions and Yield Order]]: ordering that is not deterministic.
- [[Entity Component Systems]]: systems stepped in a fixed order.

Related concepts: [[Variance]], [[Frame Budget]], [[Server Authority]], [[Telemetry Events]].

## Connected notes
<!-- auto-links:start -->
[[Procedural Generation Start Here]] · [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[Procedural World Generation]] · [[Infinite and Streamed Worlds]] · [[Procedural Loot and Item Generation]] · [[Debugging Start Here]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
