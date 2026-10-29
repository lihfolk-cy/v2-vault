---
tags: [atlas, concept, type/atlas, area/scripting, area/performance]
---
# Coroutines

<!-- tldr:start -->
> [!tldr] TL;DR
> - A coroutine is a thread with its own stack that you resume manually.
> - Errors vanish: `coroutine.resume` result ignored -> Use `task.spawn`, or check `ok, err` (Task Library Coroutines and Yielding)
> - Avoid: Using `wait()` and `spawn()`. Deprecated and throttled; the code uses `task.wait`, `task.spawn` (see Task Library...
> - New thread per handler (`task.spawn(fn, ...)`): isolation for errors and yields, but a new coroutine per handler per fire.
>
> Cost: TL;DR ~150 tok · whole note ~650 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A coroutine is a thread with its own stack that you resume manually. (from [[Task Library Coroutines and Yielding]])

## Key facts

- Errors vanish: `coroutine.resume` result ignored -> Use `task.spawn`, or check `ok, err` ([[Task Library Coroutines and Yielding]])
- Avoid: Using `wait()` and `spawn()`. Deprecated and throttled; the code uses `task.wait`, `task.spawn` (see Task Library Coroutines... ([[Round-Based Minigame Loop End to End]])
- New thread per handler (`task.spawn(fn, ...)`): isolation for errors and yields, but a new coroutine per handler per fire. ([[Building a Signal Library]])
- `coroutine.wrap` and `task.spawn` give a callback its own thread if you need to yield without blocking the caller. ([[Functions Closures and Upvalues]])

## Mentioned in

34 notes in 17 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Error Handling and Retries]] · [[Events Signals and Connections]] · [[Functions Closures and Upvalues]] · [[Luau Language Essentials]] · [[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking
[[Frameworks - Knit Matter and Others]]

### 08 Animation
[[AnimationTrack Reference]] · [[Frame Order and RunService Timing]]

### 12 Performance Testing and Debugging
[[Automated Luau Checks - LihFolk Hook and Audit]] · [[Debugger Breakpoints and Logging]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]]

### 23 Debugging Deep Dives
[[Debugging Race Conditions and Yield Order]] · [[Reading Luau Errors and Stack Traces]]

### 25 Physics and Vehicles
[[Aircraft and Flight Models]]

### 29 Luau Cookbook
[[Cookbook - Tables Strings and Time]]

### 34 Procedural Generation
[[Dungeon and Room Generation]]

### 35 Advanced Luau
[[Advanced Luau Start Here]] · [[Building a Signal Library]] · [[Custom Schedulers and Coroutine Patterns]] · [[Luau Garbage Collection and the Memory Model]] · [[Module Design and Dependency Injection]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### 52 Core Concepts
[[Frame Budget]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): Hunting Memory Leaks Step by Step · Luau Cookbook Start Here · Parallel Luau and Actors · Procedural World Generation · Round-Based Minigame Loop End to End · Saving Correctly - Autosave and BindToClose · Script Performance · Trading Systems Without Duplication · Undo and ChangeHistoryService Done Right

<!-- atlas:generated -->
