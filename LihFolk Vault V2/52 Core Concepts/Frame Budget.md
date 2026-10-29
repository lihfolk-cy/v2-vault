---
tags: [core-concept, performance, rendering, scripting]
---
# Frame Budget

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox clients run on everything from gaming PCs to old phones that are already hot.
> - Your share is far smaller than the whole budget.
> - Spikes matter more than averages. A game averaging 10 ms with a 60 ms hitch every second feels worse than a steady 20 ms.
> - Frame rate is not fixed at 60. Players can raise the frame cap in settings, so a PC may run at 120 or 240 fps (4 to 8 ms per...
>
> Cost: TL;DR ~140 tok · whole note ~890 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

The **frame budget** is the time available to produce one frame: 1000 ms divided by the target frame rate. At 60 fps it is about 16.7 ms; at 30 fps, 33.3 ms. Everything that happens in a frame (your scripts, physics, animation, rendering, UI layout) shares that budget. Go over it and the frame rate drops.

## Why it matters on Roblox

Roblox clients run on everything from gaming PCs to old phones that are already hot. The same code that costs 2 ms on a desktop can cost 8 to 10 ms on a low-end phone (rule of thumb: a 3x to 5x slowdown is common). The server has a budget too: it simulates at about 60 Hz, so server scripts share roughly 16.7 ms per step with physics and replication, for every player in the server.

## The nuance most people miss

1. **Your share is far smaller than the whole budget.** Rendering, physics and the engine take most of it. A useful rule of thumb is that gameplay scripts on the client should stay under 2 to 4 ms per frame on a mid-range phone.
2. **Spikes matter more than averages.** A game averaging 10 ms with a 60 ms hitch every second feels worse than a steady 20 ms. Look at the worst frames in the [[MicroProfiler Guide]], not the average fps counter.
3. **Frame rate is not fixed at 60.** Players can raise the frame cap in settings, so a PC may run at 120 or 240 fps (4 to 8 ms per frame). Anything written as "per frame" without `dt` runs at different speeds on different machines.
4. **Budgets are per system, by agreement.** Decide in advance how many milliseconds VFX, UI, AI and animation may each use, then measure. Without a split, every system assumes it can have "a little more".
5. **Time-slicing is the main tool.** Work that does not need to finish this frame (pathfinding for 30 NPCs, rebuilding a list) can be spread across frames with a fixed per-frame budget.

## Tiny example

```lua
-- Process a queue for at most 1 ms per frame.
local queue = {}
RunService.Heartbeat:Connect(function()
	local deadline = os.clock() + 0.001
	while queue[1] and os.clock() < deadline do
		local job = table.remove(queue, 1)
		job()
	end
end)
```

(For long queues, use a head index instead of `table.remove(queue, 1)`, which shifts the array.)

## Where this shows up

- [[Performance Fundamentals]]: budgets for client and server.
- [[MicroProfiler Guide]]: seeing where the milliseconds go.
- [[Frame Order and RunService Timing]]: which events run in which part of the frame.
- [[Script Performance]]: cutting per-frame script cost.
- [[Mobile and Low-End Optimization]]: the slowest devices set the real budget.
- [[Juice on a Budget - Mobile and Low-End]]: a frame-time governor for effects.
- [[Hit-Stop and Screen Shake Tuning by Numbers]]: how frame length changes feel.
- [[Custom Schedulers and Coroutine Patterns]]: time-slicing work.
- [[Parallel Luau and Actors]]: moving work off the main thread.
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]: a game loop inside the budget.
- [[Animation LOD]]: spending less on far-away characters.
- [[VFX Performance Budgets and Culling]]: a per-system budget in practice.

Related concepts: [[Draw Calls]], [[Instance Count]], [[Object Pooling]], [[Deterministic Simulation]].

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Performance Audit]] · [[Game Feel Start Here]] · [[Triangle Budget]] · [[Core Concepts Start Here]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Luau Performance Patterns with Benchmarks]]
<!-- auto-links:end -->
