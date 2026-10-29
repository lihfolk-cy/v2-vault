---
cssclasses: [vault-hub]
tags: [luau, advanced-luau, hub, architecture, types, memory, type/hub, area/scripting, level/beginner, area/performance]
---
# Advanced Luau Start Here

The `02 Luau Scripting` section teaches the language and the engine APIs every Roblox scripter uses: types and strict mode, the task library, events, modules, buffers, performance and native codegen. This section is the next layer. It is for developers who already write working systems and now hit the problems that appear at scale: saves that silently change shape, generic code that fights the type checker, thousands of timers, memory that never comes back, modules that cannot be tested, and event code with ordering bugs.

Each note starts where an older note stops and links back to it.

## The six deep notes

| Note | What it adds | Builds on |
|---|---|---|
| [[Serialization Formats for Saves and Networking]] | What each boundary's serializer does to your data, JSON edge cases, a schema-driven binary codec, versioning when old and new servers read each other's saves, number precision, payload shaping | [[Buffers and Binary Data]], [[Data Schema Design and Migrations]] |
| [[Advanced Types - Generics and Type Functions]] | How generic inference works, variance, generic classes, exhaustive unions with `never`, runtime validators that produce typed values, practical type functions and their limits | [[Luau Type System and Strict Mode]] |
| [[Custom Schedulers and Coroutine Patterns]] | A heap-based timer queue with a pausable, scaled clock, [[fixed timestep]] simulation, budgeted coroutine jobs, structured cancellation scopes, fake clocks for tests | [[Task Library Coroutines and Yielding]], [[Luau Performance Patterns with Benchmarks]] |
| [[Luau Garbage Collection and the Memory Model]] | What allocates and what does not, sticky table capacity, how the incremental collector paces itself, no finalizers and no ephemerons, Instance lifetimes and zombies, honest allocation measurement | [[Luau Performance and Native Codegen]], [[Memory Budgets and Leaks]] |
| [[Module Design and Dependency Injection]] | Why reaching out for dependencies hurts, narrow interface types, injecting time and randomness, a small container that orders services and reports cycles, module surface rules | [[Module Scripts and Requiring]], [[Project Structure and Bootstrapping]] |
| [[Building a Signal Library]] | Every design decision a signal makes, a reused runner thread, copy-on-write storage, deferred mode done correctly, twelve semantic tests, an observable value | [[Events Signals and Connections]] |

## How the notes connect

The six topics share three ideas.

1. **Boundaries change data.** Serialization, validators and signals all deal with values crossing from one context to another: storage, network, VMs, threads. The rule is the same everywhere: convert explicitly at the edge, validate what arrives, and never trust a type annotation on data you did not create.
2. **Every thread, timer and connection needs an owner.** The scheduler note's scopes, the memory note's zombie list and the signal note's cleanup bags are one idea seen from three sides. Luau has no finalizers, so ownership is the only cleanup mechanism you have.
3. **Inject what you cannot control.** Clocks, randomness, DataStores and purchases make code untestable when reached for directly. The dependency injection note shows the pattern; the scheduler note shows the fake clock that makes it pay off.

## Suggested reading order

- **Live game with growing saves:** Serialization, Garbage Collection, Module Design.
- **Shared libraries for a team:** Advanced Types, Signal Library, Module Design.
- **Frame spikes or memory growth:** Garbage Collection, Custom Schedulers, [[Hunting Memory Leaks Step by Step]].
- **Tests without Play mode:** Module Design, Custom Schedulers, [[Automated Testing with TestEZ and Jest-Lua]].

## Sourcing

Collector and type function facts come from luau.org, engine limits from the Roblox docs (both as of October 2026); the rest is labelled rule of thumb. Code is reviewed, not run: test it in a scratch place first, and confirm type behaviour in your own Studio, since the new type solver changes release by release.

## Related older notes

[[Luau Language Essentials]], [[Functions Closures and Upvalues]], [[Tables Metatables and OOP]], [[Metatables and OOP - When and When Not]], [[Error Handling - pcall xpcall and Promise Patterns]], [[Parallel Luau and Actors]], [[Frame Order and RunService Timing]], [[Debugging Race Conditions and Yield Order]], [[Frameworks - Knit Matter and Others]], [[Server Authority and Validation]], [[Luau Cookbook Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Dependency Injection in Luau]] · Official Docs - Scripting and Luau · Event Bus · Data Schema Versioning
<!-- auto-links:end -->
