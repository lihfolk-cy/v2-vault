---
tags: [performance, fundamentals, profiling, budgets, frame-time]
---
# Performance Fundamentals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Optimising in Studio and declaring victory.
> - Avoid: Reading fps instead of milliseconds, and averages instead of worst frames.
> - Avoid: Ignoring the server because "my fps is fine".
> - The problem is named: compute, memory, or load time; client, server, or both.
> - A reproducible scenario exists with production-like load.
> - Baseline numbers recorded (frame ms, memory MB by category, join seconds) on a real low-end device.
>
> Read more (17 KB note): ## 2. What a frame is · ## 6. Budgets · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Performance work on Roblox fails in two predictable ways. Either people optimise by superstition ("unions are slow", "never use `FindFirstChild`") without measuring, or they measure the wrong machine (a fast PC in Studio) and ship a game that runs at 20 fps on a three-year-old phone. This note gives the mental model the rest of the section builds on: what a frame is, where its time goes, what the three kinds of performance problem are, which tool answers which question, and the discipline that keeps a large game fast for its whole life.

Source labels:
- **Docs**: the official Roblox Creator Hub (guides and engine reference), as of October 2026.
- **Measured**: measured in the reference project (one live action game with a large hub world, hundreds of enemies, and more than a hundred weapon kits).
- **Rule of thumb**: experience, not a hard limit.

---

## 1. The three problems

Docs split performance issues into three families, and the split matters because each has different tools and different fixes.

| Family | What players notice | Main tools | Typical causes |
|---|---|---|---|
| **Compute (frame rate)** | low fps, stutter, input lag; on the server, rubber-banding and delayed hits | MicroProfiler, Script Profiler, Performance Stats bar | per-frame scripts, physics, rendering load, replication processing |
| **Memory** | crashes on phones, "out of memory" exits, long GC pauses, server restarts | Developer Console Memory tab, Luau heap snapshots | instance counts, textures, meshes, sounds, leaked connections and tables |
| **Load time** | long black or loading screen, players leaving before they play | stopwatch, a join timer in ReplicatedFirst, Studio's join size breakdown | huge ReplicatedStorage, no streaming, heavy start-up scripts, preloading everything |

They interact. A memory leak eventually becomes a compute problem (the garbage collector works harder as the heap grows). A big ReplicatedStorage is both a memory and a load-time problem. But always name which family you are fighting first; otherwise you will profile frames while the real complaint is a 40-second join.

---

## 2. What a frame is

Roblox runs a loop each frame on the client and (with a different set of jobs) on the server. Simplified, a client frame does input, scripts bound to frame events, animation, physics, replication, then rendering. The exact order of `RunService` events is covered in [[Frame Order and RunService Timing]]; here, what matters is the budget.

| Target | Frame budget | Where it applies |
|---|---|---|
| 30 fps | 33.33 ms | low-end phones under load (a floor, not a target) |
| 60 fps | 16.67 ms | default client cap; server heartbeat cap |
| 120 fps | 8.33 ms | high-refresh clients |
| 240 fps | 4.17 ms | maximum client cap on Windows if the player raises it |

Docs: the default client frame rate cap is 60 fps; Windows players can raise it up to 240. The server's heartbeat is capped at 60 Hz, and "lower values suggest a problem". The Performance dashboard states the same budget the other way round: 60 fps needs client CPU time below 16 ms per frame, and the same for server CPU time.

### Frame time, not fps

Always think in milliseconds. "We lost 10 fps" means nothing on its own: going from 60 to 50 fps costs 3.3 ms per frame, going from 30 to 20 costs 16.7 ms. A feature that costs 2 ms is 12% of a 60 fps frame and is the same 2 ms whether the game is running at 60 or 25.

### Two threads you care about

The MicroProfiler reference (Docs) describes:
- **Main thread** ("RBX Main"): CPU rendering preparation, input, Humanoids, animation, physics ownership, sound, and your scripts (unless you use Parallel Luau).
- **Worker threads** ("RBX Worker"): networking, physics, pathfinding and parallel script work. Most are asleep most of the time.
- **Render thread** ("GPU"): prepare, perform and present stages.

The frame bar colour in the MicroProfiler tells you which side is the bottleneck: orange when job wall time exceeds render wall time (scripts, physics, animation), blue when render wall time dominates, red when render dominates and GPU wait exceeds 2.5 ms (Docs). Details in [[MicroProfiler Guide]].

### Average versus spike

A game averaging 12 ms per frame with one 120 ms frame every two seconds feels worse than a steady 20 ms. Players perceive **hitches** much more than a lower steady rate. Spikes usually come from:
- bursts of instance creation (opening a big menu that clones 400 frames, spawning a wave of enemies on one frame),
- garbage collection after a lot of short-lived allocation (the `GC` label in the MicroProfiler),
- a synchronised timer (every enemy re-pathing on the same frame),
- asset loads on first use (first ability use in a session).

The cure for spikes is usually **spreading work over frames** (budgeted queues, random phase offsets), not making the work cheaper.

---

## 3. Client versus server

Every problem lives on one side or both, and the server is invisible from your own screen.

| Symptom | Likely side | How to confirm |
|---|---|---|
| Your own fps drops, other players are fine | client (your device or what you are looking at) | client MicroProfiler, Shift+F5 overlay |
| Everyone's hits land late, NPCs stutter, ping climbs for all players at once | server | Developer Console server tabs, server MicroProfiler recording |
| Only phones crash | client memory | Performance dashboard by device, client Memory tab on a phone |
| Server restarts or "server memory" warnings | server memory | Performance dashboard server memory chart |

Docs give the server memory budget as a formula: about **6.25 GiB plus 100 MiB times the largest number of connected players** (30 players gives about 9.18 GiB), and recommend staying below 50% of it. Server memory rises as players join and does not fall when they leave, so a long-running server is your worst case. See [[Developer Console and Stats]].

A server at 60 Hz is not the same as a healthy server. Docs note that degraded heartbeat raises ping; data ping (through the replication system) is always at least network ping, and if it is much higher, the server is queueing. See [[Network Performance]].

---

## 4. The tool map

| Question | Tool | Note |
|---|---|---|
| Which part of the frame is slow? | [[MicroProfiler Guide]] | Ctrl+F6 in Studio and the desktop client (the reference page; another Docs page gives Ctrl+Alt+F6) |
| Which script function costs the most CPU over a minute? | Script Profiler in the Developer Console | sampling profiler, 1 kHz or 10 kHz |
| How much memory, and in which category? | Developer Console, Memory tool | client and server views |
| What is holding this Luau memory? | Luau heap snapshots | compare two snapshots to find growth |
| Live numbers on screen | Performance Stats bar (Ctrl+Alt+F7 per Docs), debug overlays (Shift+F1 to F5 family) | Studio numbers are skewed; use the client |
| Live game health across all players | Creator Dashboard Performance page | needs 100+ DAU for charts |
| Live script errors across all servers | Creator Dashboard Error Report | see [[Crash and Error Telemetry]] |
| Where does my join time go? | Studio Settings, Network, Print Join Size Breakdown | Docs |

The Script Profiler and Luau heap tools are covered in [[Script Performance]] and [[Memory Budgets and Leaks]]; the console itself in [[Developer Console and Stats]].

---

## 5. Studio lies (a little)

Docs say plainly that Studio's numbers are skewed and you should use the client for accurate readings. Reasons:
- Studio runs the server and the client in one process during a solo Test, so both sets of work share the machine.
- Studio has its own overhead: Explorer, Properties, plugins, the script editor and its analysis.
- Your development machine is much faster than a median player's phone.

**Measured.** In the reference project, the place grew to about 2.36 million instances (mostly archived animation data and dated backup folders in ServerStorage), and Studio dropped to about **15 fps in Edit mode**. Players never loaded most of that (ServerStorage does not replicate), so the live game was fine; the developers were the ones suffering. Deleting the backup folders (about 1.07M down to about 600k instances in one pass) restored Studio. Two lessons:

1. Studio performance is its own problem with its own budget. Instances in ServerStorage cost every server and every Studio session, even if no client ever sees them.
2. A slow Studio poisons measurement. Profile the game on a client build, not in a Studio that is fighting a million-instance Explorer.

See [[Case Study - Instance Cleanup and Place Size]] and [[Case Study - Cutting a Million Instances]].

---

## 6. Budgets

A budget is a number per system that someone owns. Without budgets, every feature is "only 1 ms" and the game dies of a thousand features.

### Frame budget split (rule of thumb, for a 60 fps client target on a mid phone)

| Slice | Budget | Notes |
|---|---|---|
| Rendering (prepare, perform, GPU) | 8 to 10 ms | biggest and least controllable; scene density, lights, particles, UI |
| Engine simulation (physics, humanoids, animation) | 2 to 3 ms | grows with moving assemblies and Humanoids |
| Your client scripts total | 2 ms | every `PreRender`/`Heartbeat` handler, UI updates |
| Headroom | 2 to 3 ms | for spikes, GC, bad devices |

On the server (rule of thumb): keep your scripts under about 5 ms average per heartbeat at full player count, leaving room for physics and replication.

### Content budgets that worked (Measured)

| Content | Budget used in the reference project |
|---|---|
| One weapon kit folder | under 2,500 instances (three kits over budget at 3,000 to 5,400 were flagged) |
| A sword swing's VFX | at most 140 beams and 30 emitters live (measured max 128 and 28); finisher 210 and 44; low-quality mode 44 and 10 |
| One element VFX layer | 12 meshes and 20 emitters |
| An open portal | 6 emitters, 7 beams, 6 meshes, 2 lights, 5 sounds; asleep beyond 300 studs |
| A forge celebration | about 3,200 particles over 2 s for the caster (5,600 for the ultimate tier), half for onlookers |
| Tier highlights | at most 3 Highlights per effect, pooled |
| Kill feedback | at most 3 full blood splats per second; loot from kills within 0.25 s merged into one burst; on-screen loot icons capped (60 lowered to 24) |

Notice the shape of these: a hard cap, a measured actual value under it, and a degraded mode. That is what a useful budget looks like. See [[Rendering Performance]].

---

## 7. The optimisation loop

1. **Reproduce with production-like load.** One player and 30 enemies in Studio tells you nothing about 30 players and 600 enemies. Use multi-client tests, bots, or a live private server ([[Multi-Client and Live Testing]]).
2. **Measure.** Capture a MicroProfiler dump or Script Profiler session, a memory snapshot, a fps number on a real low-end device.
3. **Find the single biggest item.** Fix the top of the list, not the thing you suspected.
4. **Change one thing.** Then measure again in the same scenario.
5. **Lock it in.** Add a budget, a debug label, an assertion, or a test so the win cannot silently regress.

"Measure, change one thing, measure" sounds obvious; it is the step people skip most. Two changes at once and you will never know which helped, or whether one made things worse.

### What to optimise first (rule of thumb)

1. Things that run **every frame for every object** (per-enemy loops, per-part updates, per-button UI animations).
2. Things that **scale with player count** on the server (broadcasts, per-player loops over all players).
3. **Instance counts** in replicated containers.
4. **Spikes** on common actions (opening menus, first ability use, enemy waves).
5. Everything else.

---

## 8. The patterns that win most often

These recur across every note in this section. Each links to the note with the details.

| Pattern | Why it works | Detail |
|---|---|---|
| **Gate per-frame loops by visibility** | a loop that animates a hidden UI or an off-screen object is pure waste | [[Script Performance]] |
| **One loop for many objects** | one `PreRender` iterating 200 entries beats 200 connections | [[Script Performance]] |
| **Distance LOD tiers** | far objects update every Nth frame or not at all | [[Animation LOD]] |
| **Lower cadence** | quest timers at 4 Hz, healthbars at 10 Hz, sway at 30 Hz | [[Script Performance]] |
| **Write only on change** | setting a property or text to the same value still costs | [[Script Performance]] |
| **Pool instead of create/destroy** | hit flashes, damage numbers, projectiles, emitters | [[Memory Budgets and Leaks]] |
| **`BulkMoveTo` for many anchored parts** | one call instead of N `CFrame` sets | [[Physics Performance]] |
| **Anchor, de-collide, de-query** | most world parts need neither physics nor queries | [[Physics Performance]] |
| **Client-side VFX from one small event** | the server sends the result, clients draw it | [[Network Performance]] |
| **Owner-only replication of private state** | do not replicate one player's inventory to everyone | [[Network Performance]] |
| **Streaming** | clients load only nearby world | [[Instance Streaming]] |

---

## 9. When not to optimise

- **Before the feature is fun.** Prototype honestly slow; optimise once the design is stable. Profiling a mechanic that will be cut is waste.
- **Below the noise floor.** A function that takes 0.02 ms per frame is not worth rewriting for readability loss. The MicroProfiler and Script Profiler tell you what is noise.
- **By reflex.** Docs explicitly say plain `CFrame` setting is fast enough in most cases and `BulkMoveTo` is for confirmed bottlenecks. Many "slow" APIs are fine at the call counts you actually have.
- **With micro-tricks that defeat the compiler.** Caching `math.floor` into a local was a real win in old Lua; in modern Luau with fastcalls and native codegen it can be neutral. See [[Luau Performance and Native Codegen]].

---

## 10. Studio and tooling health

Your tools also have a performance budget.

**Measured.** In the reference project, Studio froze for about **25 minutes at 100% CPU** when about 18 heavy offline baking processes (each multi-threaded by its numeric library) ran in parallel alongside long simulations inside Studio. It recovered without a restart, but nothing could be saved or checked during that time. The rule adopted afterwards:
- at most 2 heavy offline processes at a time per person, with numeric libraries pinned to a single thread,
- no long background simulations inside the Studio process,
- each scripted call into Studio (plugin or command bar automation) short (under about 1.5 s) and run one at a time.

Other Studio health rules that came from that project:
- Do not keep backups as folders inside the place. Back up to disk (`.rbxm` exports) and rely on Version History ([[Version History and Backups]]).
- Expect Edit-mode tools to misreport some runtime behaviour (particles only step while rendering; rate-based emission does not run in Edit, only `:Emit()` bursts). Edit-mode dry runs prove code paths, not frame rates. See [[Testing Strategies and Frameworks]].

---

## Common mistakes

- Optimising in Studio and declaring victory. Measure on the device class your players use.
- Reading fps instead of milliseconds, and averages instead of worst frames.
- Ignoring the server because "my fps is fine".
- Adding a feature with no budget, then discovering the budget was spent three features ago.
- Fixing the suspected cause without a profile. The MicroProfiler usually disagrees with your intuition.
- Treating memory as free on PC because it is plentiful there; phones crash.
- Keeping archives in the place "just in case". They slow every Studio session and every server start.

## Checklist

- [ ] The problem is named: compute, memory, or load time; client, server, or both.
- [ ] A reproducible scenario exists with production-like load.
- [ ] Baseline numbers recorded (frame ms, memory MB by category, join seconds) on a real low-end device.
- [ ] The biggest item in the profile is the one being fixed.
- [ ] One change at a time, measured before and after.
- [ ] Each system has a written budget and a degraded mode.
- [ ] Per-frame loops are gated by visibility and distance.
- [ ] A regression guard (label, test, assertion, budget check) is added with the fix.

## See also

[[MicroProfiler Guide]] · [[Developer Console and Stats]] · [[Memory Budgets and Leaks]] · [[Script Performance]] · [[Physics Performance]] · [[Rendering Performance]] · [[Network Performance]] · [[Mobile and Low-End Optimization]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Luau Performance and Native Codegen]] · [[Performance and Memory]] · [[Animation LOD]] · [[Case Study - Instance Cleanup and Place Size]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Performance Audit]] · [[Frame Budget]] · [[Links - Profiling]] · [[Hunting Memory Leaks Step by Step]] · [[Juice on a Budget - Mobile and Low-End]] · [[Luau Performance Patterns with Benchmarks]]
<!-- auto-links:end -->
