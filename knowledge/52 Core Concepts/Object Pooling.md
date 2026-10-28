---
tags: [core-concept, performance, memory, vfx, scripting]
---
# Object Pooling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Creating an instance, parenting it into the world and later destroying it costs CPU, memory churn and, on the server...
> - Pool on the client for visuals. Most pooled things (tracers, hit sparks, damage numbers) should exist only on the client.
> - Reset everything on reuse. A pooled part keeps its old Transparency, Color, attached emitters' state and attributes.
>
> Read more (4 KB note): ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Object pooling** keeps a supply of pre-made instances (bullets, damage numbers, effect parts, list rows) and reuses them instead of creating and destroying new ones each time. "Spawn" takes one from the pool and positions it; "despawn" hides it and returns it.

## Why it matters on Roblox

Creating an instance, parenting it into the world and later destroying it costs CPU, memory churn and, on the server, replication to every client. In a fast weapon or a big particle moment that churn becomes a frame spike. Pooling turns it into a cheap property change.

## The nuance most people miss

1. **Pool on the client for visuals.** Most pooled things (tracers, hit sparks, damage numbers) should exist only on the client. Pooling server-created visuals still replicates every move to every player.
2. **Hiding is a choice with costs.** Moving pooled parts far away (for example `CFrame` to a point thousands of studs below the map) is cheap and avoids reparenting; setting `Parent = nil` costs more but removes the part from physics and rendering completely. Moving many parts at once is cheapest through `workspace:BulkMoveTo` (Roblox docs, as of October 2026).
3. **Reset everything on reuse.** A pooled part keeps its old Transparency, Color, attached emitters' state and attributes. Forgetting one reset gives "ghost" bugs that appear only on the second use.
4. **Bound the pool.** An unbounded pool that grows to the peak and never shrinks is a memory leak with good intentions. Cap the size and, when empty, either create a temporary item or skip the effect (decoration may drop; information may not).
5. **Do not pool what you rarely use.** For something spawned twice a minute, pooling adds bugs for no gain. Measure the churn first.

## Tiny example

```lua
local Pool = {}
Pool.__index = Pool

function Pool.new(template: BasePart, size: number)
	local self = setmetatable({ free = {}, template = template }, Pool)
	for i = 1, size do
		local p = template:Clone()
		p.Anchored = true
		p.CFrame = CFrame.new(0, -10000, 0)
		p.Parent = workspace.Pooled
		table.insert(self.free, p)
	end
	return self
end

function Pool:take(): BasePart?
	return table.remove(self.free) -- nil when empty: caller skips the effect
end

function Pool:give(p: BasePart)
	p.CFrame = CFrame.new(0, -10000, 0)
	p.Transparency = self.template.Transparency -- reset what callers change
	table.insert(self.free, p)
end
```

## Where this shows up

- [[Projectiles and Ballistics]]: pooled bullets and tracers.
- [[VFX Performance Budgets and Culling]]: bounded pools for effects.
- [[Juice on a Budget - Mobile and Low-End]]: pools with spawn budgets.
- [[Hunting Memory Leaks Step by Step]]: pools that never shrink.
- [[Virtualized Lists and Large Inventories]]: pooled UI rows.
- [[Notification and Toast Systems]]: reused toast frames.
- [[Particle Emitters In Depth]]: reusing emitters with Emit.
- [[Tycoon Plots and Droppers End to End]]: dropped item churn.
- [[Script Performance]]: allocation cost in hot paths.
- [[Luau Garbage Collection and the Memory Model]]: why churn hurts.
- [[Destruction and Fracture]]: debris from a pool.
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]: pooled sprite frames.

Related concepts: [[Instance Count]], [[Frame Budget]], [[Draw Calls]].

## Connected notes
<!-- auto-links:start -->
[[Memory Budgets and Leaks]] · [[Links - Memory leaks and cleanup]] · [[Core Concepts Start Here]] · [[Instances Attributes and Tags]] · [[Game Feel and Juice]] · [[Game Feel Start Here]]
<!-- auto-links:end -->
