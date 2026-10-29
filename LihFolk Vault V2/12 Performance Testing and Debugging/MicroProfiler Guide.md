---
tags: [performance, microprofiler, profiling, debug-profilebegin, frame-time, type/guide, area/performance, level/advanced, api/PreRender, area/data]
---
# MicroProfiler Guide

<!-- tldr:start -->
> [!tldr] TL;DR
> - Studio skews the picture. Server and client share the process in a solo test, and Studio has its own UI cost.
> - The profiler has overhead. Capturing, especially at many frames or with X-Ray, costs time.
> - One frame is an anecdote. Look at 30 to 90 frames; use Timers for totals.
> - Profiled on the device class with the problem, not only in Studio.
> - Captured enough frames to see the pattern (30 to 90), and looked at Timers mode.
> - Identified the family: script, physics, render, network, UI.
>
> Cost: TL;DR ~170 tok · whole note ~4.3k tok. Read more: ## 3. The labels that matter · ## 4. Your own labels · ## 7. Gotchas · ## Checklist
<!-- tldr:end -->

The MicroProfiler is the one tool that shows **where inside a frame** the time goes: which engine job, which script event, which of your own labelled functions. Everything else (fps counters, Script Profiler totals, memory charts) tells you *that* something is slow; the MicroProfiler tells you *what* and *when*. This note covers opening it everywhere (Studio, desktop, phone, live server), reading it, the labels that matter, adding your own labels with `debug.profilebegin`/`debug.profileend`, and the diagnosis recipes that come up again and again.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Opening it

| Where | How (Docs) |
|---|---|
| Studio | Ctrl+F6 (Cmd+F6 on Mac) per the MicroProfiler reference page |
| Desktop client | Ctrl+F6 (Cmd+F6) |
| Phone or tablet | in the in-game Settings menu, set MicroProfiler to On; then on a computer on the same network, open the IP address and port the device shows in a browser (the Docs example uses port 1338) |
| Live server | join on the desktop client with edit permission, open the Developer Console (Ctrl+F9 / F9), choose MicroProfiler, Server tab, set frames (max 60) and start delay (max 4 s), click Begin server recording; the console prints the file path a few seconds later |

**Docs disagree on the shortcut.** The MicroProfiler reference says Ctrl+F6; the "use the MicroProfiler" walkthrough and the "identify performance issues" page say **Ctrl+Alt+F6**. If one does nothing, try the other. The Performance Summary overlay is Ctrl+Shift+F5 in the walkthrough. Tracked for [[Open Questions - Whole Vault]].

### Pausing and dumps
- **Pause** with Ctrl+P (Cmd+P) or the Pause menu item. Pausing switches to the detailed view so you can inspect a frame.
- **Dump** from the Dump menu (Studio and desktop). Files are saved to the Roblox logs folder (`%LOCALAPPDATA%\Roblox\logs` on Windows, `~/Library/Logs/Roblox` on macOS) as an HTML file you can open in any browser.
- A dump contains only the selected number of frames, except Counters mode data, which runs from start-up to the dump.

### The web UI (phones and dumps)
- Shows the 30 most recent frames by default; append `/90` (or another number) to the URL to fetch more (Docs).
- **Re-capture** fetches fresh frames; **Save to file** writes `microprofile-<date>-<time>.html`.
- **X-Ray** colours memory allocation; press **C** to switch between allocation count and total size. Very useful for hunting per-frame garbage.
- **Export** produces CPU or memory flame graphs; drag a second dump in to diff two captures ("Combine & Compare").

---

## 2. Reading the frame graph

The top of the screen is a bar per frame; height is frame time.

| What you see | Meaning |
|---|---|
| Uniformly tall bars | a steady cost every frame: a per-frame loop, physics load, scene density |
| Mostly short bars with occasional tall ones | spikes: bursts of creation, GC, synchronised timers, first-use loads |
| Bars alternating tall and short | something runs every 2nd frame (a cadence scheduler, physics catch-up) |
| Orange bars | jobs (scripts, physics, animation) took longer than render (Docs) |
| Blue bars | the render thread dominated (Docs) |
| Red bars | render dominated **and** GPU wait exceeded 2.5 ms (Docs): GPU-bound, usually scene complexity, textures, effects |

Docs caveat: small tasks at the end of a frame can skew the wall-time comparison, so trust frame time more than colour.

Reference lines: 16.67 ms is 60 fps, 33.33 ms is 30 fps. On a 60 fps target anything over the first line is a dropped frame.

### Navigation (desktop, Docs)
- Left-drag to pan, scroll to zoom.
- Labels directly below a label are its children.
- **Right-click a label to zoom to exactly its duration.**
- Left-click a frame bar to jump to it.
- Left-click a label to add its per-frame time to the line graph at the bottom right; right-click the graph to hide it.
- Ctrl+F searches task names (case-insensitive); F3 or Enter for next, Shift+F3 for previous. In a dump, Ctrl+F jumps to the most expensive task.
- The **Groups** and **Threads** menus filter what is drawn.

### Modes (Docs)
| Mode | Use it for |
|---|---|
| Frame / Detailed | the normal timeline; detailed is what you get when paused |
| **Timers** | a table of labels with time and call counts; sort to find the biggest total, not just the biggest single call |
| **Counters** | instance counts and memory by category over time (the Developer Console is recommended for memory work) |
| Groups (web only) | average, max and total per group, by thread |
| Threads (web only) | per thread, by group: is work spread or piled on one thread |
| Hidden (desktop only) | hides the bars but keeps the menu and the line graph; good for watching one label over time |

Timers mode is underused. A label that costs 0.05 ms but is called 2,000 times per frame will not stand out in the timeline; in Timers it is at the top.

---

## 3. The labels that matter

From the Docs tag reference. You do not need all of them; you need to recognise which family a wide bar belongs to.

### Scripts
| Label | Meaning |
|---|---|
| `Heartbeat` / `RunService.Heartbeat` | your Heartbeat handlers (`PostSimulation` lands here too) |
| `Simulation/gameStepped/RunService.Stepped` | Stepped / `PreSimulation` handlers |
| `Render/PreRender/RunService.RenderStepped` | RenderStepped / `PreRender` handlers |
| `fireBindToRenderSteppedCallbacks` | functions bound with `BindToRenderStep` |
| `WaitingHybridScriptJob` | resuming threads waiting on `WaitForChild` or waits; has a time budget and is throttled if scripts run too long |
| `GC` | Luau garbage collection; reduce temporary allocations, reuse tables |

Under these you see the individual script and, if you added them, your own labels.

### Physics and simulation
| Label | Meaning |
|---|---|
| `physicsStepped` | the physics step overall |
| `worldStep`, `stepContacts`, `stepWorld` | discrete physics steps, contact updates, constraint solving |
| **`stepWorldThrottled`** | the engine is overloaded and is only simulating real-time assemblies such as Humanoids (Docs). Seeing this is an alarm. |
| `stepHumanoid` | Humanoid state and movement |
| `stepAnimation` | Animators advancing tracks |
| `interpolateNetworkedAssemblies` | smoothing parts owned by someone else |
| `Distributed Physics Ownership` | deciding network owners; frequent ownership changes add cost |
| `handleFallenParts` | removing parts below the fallen-parts height |

### Rendering
| Label | Meaning |
|---|---|
| `Prepare` / `updateInvalidParts` | parts whose properties changed or were added |
| `updateInvalidatedFastClusters` | rebuilding Humanoid and skinned mesh geometry; Docs: over 4 ms suggests excessive avatar invalidations |
| `updateDynamicParts` | Beams, ParticleEmitters, Humanoids |
| `Perform` / `queryFrustumOrdered` | culling |
| `computeLightingPerform`, `LightGridCPU` | lighting near the camera, voxel light grid |
| `ShadowMapSystem`, `Scene/Shadows` | shadow maps, only at quality level 4 and above |
| `Id_Opaque`, `Id_Transparent`, `Id_Decals` | the draw passes |
| `fillGuiVertices` | UI vertex buffers |
| `Present/waitUntilCompleted` | **GPU wait**: the CPU is waiting for the GPU to finish the previous frame; frequent long waits mean you are drawing too much |

### UI
| Label | Meaning |
|---|---|
| `UpdateUILayouts` | recomputing UI positions and sizes |
| `Rebuild Z-order list` | draw-order rebuild after adding, removing or reordering UI |
| `Render/PreRender/TweenService` | client tweens (on the server, TweenService runs inside Heartbeat) |

### Networking
| Label | Meaning |
|---|---|
| `Net PacketReceive`, `deserializePacket` | receiving packets |
| `Replicator/ProcessPackets` | applying incoming motion, events, property changes |
| `Allocate Bandwidth and Run Senders` | outgoing: physics, data (properties, remotes, new instances), streaming |
| `ModelCompleteness Mega Job` | server tracking when models are fully sent |

### Navigation
`rasterizeTile`, `computePath`, `getPrimitivesOverlapping`: pathfinding (see [[Pathfinding]]).

---

## 4. Your own labels

Engine labels stop at "LocalScript X spent 3 ms in Heartbeat". To see *which part* of your code, add labels.

```lua
--!strict
-- debug.profilebegin(label) opens a label; debug.profileend() closes the most recent one (Docs).
local RunService = game:GetService("RunService")

local enemies: { any } = {}

RunService.Heartbeat:Connect(function(dt: number)
	debug.profilebegin("EnemyAI")

	debug.profilebegin("EnemyAI.sense")
	for _, enemy in enemies do
		-- cheap distance checks, target selection
	end
	debug.profileend()

	debug.profilebegin("EnemyAI.move")
	for _, enemy in enemies do
		-- steering, ground snapping
	end
	debug.profileend()

	debug.profileend() -- closes "EnemyAI"
end)
```

Nested labels show as children, exactly like engine labels.

### Rules for labels

1. **Begin and end must pair, on the same thread, without yielding in between** (rule of thumb). A `task.wait()` or a yielding call inside a label leaves it open across frames, and the timeline becomes nonsense.
2. **An error between them leaves the label open.** If the code inside can throw, protect it:

```lua
--!strict
-- Profile a block that might error, keeping begin/end balanced.
local function profiled(label: string, fn: () -> ())
	debug.profilebegin(label)
	local ok, err = pcall(fn)
	debug.profileend()
	if not ok then
		error(err, 0) -- rethrow without adding a new position prefix
	end
end
```

`pcall` has a small cost; use the wrapper at system level (once per system per frame), not per object.

3. **Use constant label strings.** `debug.profilebegin("Enemy_" .. enemy.Id)` allocates a new string every call (more GC) and produces hundreds of distinct labels that are impossible to read. Label the system, and if you need per-object detail, add an attribute counter instead.
4. **Label at the granularity you will act on.** One label per system and one per expensive phase is plenty. Labels on every function make the view unreadable.
5. **Leave the important ones in.** Labels are cheap enough to ship at system granularity (rule of thumb), and they are exactly what you need when a live server misbehaves at 2 a.m. and you capture a server dump.

### Parallel Luau
Work done after `task.desynchronize()` (or in `ConnectParallel` handlers inside an Actor) runs on worker threads, so its labels appear on worker thread rows, not under the main thread's Heartbeat. When checking whether parallelism helped, use the **Threads** view to see whether work is really spread or serialised on one worker (rule of thumb). See [[Parallel Luau and Actors]].

---

## 5. Diagnosis recipes

### Recipe: "fps drops in one area of the map"
1. Stand in the slow area; Ctrl+F6; Ctrl+P on a slow frame.
2. Bar colour blue or red? Rendering. Check `Prepare` vs `Perform` vs `waitUntilCompleted`.
   - Big `Perform` with many draw passes: too many distinct meshes or materials. See [[Rendering Performance]].
   - Big `ShadowMapSystem`: many shadow-casting lights; check at quality level 4+.
   - Long `waitUntilCompleted`: GPU-bound (overdraw from transparency and particles, texture size).
3. Orange? Look under Heartbeat/Stepped for a script that is only active near that area (ambient FX, an NPC group).

### Recipe: "periodic hitch every few seconds"
1. Pause right after a hitch frame (watch the frame graph for the tall bar).
2. Look for `GC` (allocation churn), a burst of `updateInvalidParts` (many parts changed at once), `Rebuild Z-order list` (a big UI was built), or a script spike.
3. If a script spikes on a fixed period, find the timer: something like "every 3 s, recompute all enemy targets" is a classic. Spread it with a random phase per entity.

### Recipe: "server feels laggy for everyone"
1. Record a server dump (Developer Console, MicroProfiler, Server, 60 frames).
2. Frames over 16.67 ms on the server are a problem (Docs).
3. Look for script Heartbeat cost, `stepWorldThrottled`, pathfinding (`computePath`), or `Allocate Bandwidth and Run Senders` dominating.
4. If it is outbound replication, see [[Network Performance]]: something is replicating too much (big attribute writes, per-frame property changes, server tweens).

### Recipe: "UI is slow when a menu is open"
1. Open the menu, profile.
2. `UpdateUILayouts` large every frame means layouts are being invalidated every frame: something writes `Size`, `Position` or `Text` every frame even when unchanged, or a `UIListLayout` with hundreds of children is re-flowing.
3. Under PreRender, look for your UI scripts. The fix is almost always "update only on change" plus "stop the loop while hidden".

### Recipe: "first use of an ability stutters"
Check for asset loading and instance cloning on that frame. Preload the clip and the VFX template when the kit is equipped, not when the button is pressed. See [[Engine Gotchas]] (first use of a clip is late).

---

## 6. Worked examples

### Docs walkthrough (Docs)
The official walkthrough plants a `RunService.Stepped` handler that casts 1,500 rays per second in random directions. In the MicroProfiler the stacked bars show the LocalScript and a Raycast child; wrapping the function in `debug.profilebegin("Raycast Spam")` confirms it. Removing it takes the frame rate from 45 to 60 fps.

### Idle UI loops (Measured)
In the reference project, a tutorial tips controller kept a `RenderStepped` handler running every frame to animate a pointing hand and highlight ring, **even when no tip was showing**. It was cheap per frame, but it was one of many such idle loops. The fix was an idle gate: when nothing is visible, the loop does nothing (and better, disconnects). In the same pass, a quest tracker's countdown timer that rewrote its text every frame was moved to 4 Hz and to write only when the displayed value changed. Neither showed up as a single big bar; both showed up in **Timers mode** as steady per-frame costs under PreRender.

### One driver for many animated cards (Measured)
An inventory screen gave each rare item card its own animation loop (glow pulse, sparkles). With a full grid that was dozens of loops. It was rebuilt as **one** `RenderStepped` driver that iterates only on-screen entries, with a pool of at most 60 sparkle frames shared by all cards. The MicroProfiler went from a forest of small script entries to one label.

---

## 7. Gotchas

- **Studio skews the picture.** Server and client share the process in a solo test, and Studio has its own UI cost. Confirm on the desktop client or a phone ([[Performance Fundamentals]]).
- **The profiler has overhead.** Capturing, especially at many frames or with X-Ray, costs time. Compare captures taken the same way.
- **One frame is an anecdote.** Look at 30 to 90 frames; use Timers for totals.
- **A frozen client cannot be profiled.** If a script never yields (an infinite `while` loop), the frame never ends and the profiler UI freezes with it. That is a debugging job ([[Debugger Breakpoints and Logging]]). In the reference project, a UI helper looped `while true` until a child parented successfully; when the parent had been destroyed by a card rebuild, it looped forever and froze the client on click. The fix capped retries at 4 and returned nil.
- **Labels in modules required by the command bar** run in a separate module instance; they will not show the live game's work.

## Checklist

- [ ] Profiled on the device class with the problem, not only in Studio.
- [ ] Captured enough frames to see the pattern (30 to 90), and looked at Timers mode.
- [ ] Identified the family: script, physics, render, network, UI.
- [ ] Added constant-string labels around suspect systems; begin/end balanced and never across a yield.
- [ ] For server issues, recorded a server dump from the Developer Console.
- [ ] Re-profiled after the fix in the same scenario and kept the useful labels.

## See also

[[Performance Fundamentals]] · [[Developer Console and Stats]] · [[Script Performance]] · [[Rendering Performance]] · [[Physics Performance]] · [[Network Performance]] · [[Frame Order and RunService Timing]] · [[Parallel Luau and Actors]] · [[Debugging Animation Problems]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Performance Audit]] · Frame Budget · Luau Performance and Native Codegen · Task Library Coroutines and Yielding · Luau Garbage Collection and the Memory Model · Links - Profiling
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Network Bandwidth Budgets and Measuring Them]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Weather Performance Budgets and Quality Tiers]] · [[Mobile and Low-End Optimization]] · [[QA Checklists Before Release]] · [[Client Zone Culling for Interiors and Cities]] · [[Memory Budgets and Leaks]] · [[Hunting Memory Leaks Step by Step]]
<!-- related:end -->
