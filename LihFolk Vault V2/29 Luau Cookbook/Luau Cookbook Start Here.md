---
cssclasses: [vault-hub]
tags: [luau, cookbook, hub, recipes, type/hub, area/scripting, level/beginner]
---
# Luau Cookbook Start Here

This section is a set of short, copyable recipes for problems every Roblox project solves again and again: setting up players and characters, talking across the network safely, saving data, building UI, doing geometry, and handling tables, text and time. Each recipe follows the same shape:

- **Problem**: the situation in one or two sentences.
- **Code**: a self-contained `--!strict` Luau snippet using modern APIs (the `task` library, `PivotTo`, attributes, `Activated`, `UnreliableRemoteEvent`), never deprecated `wait`, `spawn` or `delay`.
- **Why it works**: the mechanism, briefly.
- **Pitfall**: the mistake that usually bites, and how to spot it.

All code is reviewed, not run. Treat every snippet as a starting point: paste it into a test place, run it, and adapt it before it reaches a live game. Facts about the engine are labelled "Roblox docs (as of October 2026)"; judgement calls are labelled "rule of thumb".

## How this differs from the rest of the vault

The deep notes in `02 Luau Scripting`, `03 Architecture and Networking`, `04 Data and Persistence` and `05 UI and UX` explain the why: trade-offs, limits, failure modes. The [[Worked Builds Start Here]] section builds whole systems end to end. The cookbook sits in between: one problem, one answer, one link to the deep note when you need more. If a recipe surprises you, follow its links before you rely on it.

## The six cookbooks

| Note | Recipes cover | Read with |
|---|---|---|
| [[Cookbook - Players and Characters]] | Player and character lifecycle, per-player state and cleanup, finding the player from a hit part, teleporting, stacking speed modifiers, custom respawn, death handling, collision groups, reset button, outfits | [[Characters and Humanoids]], [[Spawning Teams and Rounds]] |
| [[Cookbook - Remotes and Networking]] | One remote registry, type validation, token bucket rate limits, per-player locks, distance checks, NaN rejection, safe RemoteFunctions, unreliable cosmetic data, attribute replication, targeted and batched firing, intent-only combat remotes | [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Server Authority and Validation]] |
| [[Cookbook - Data and Saving]] | Retries with backoff, templates and reconcile, `UpdateAsync` saves, staggered autosave, shutdown saves, never saving failed loads, request budgets, versioned migrations, size checks, ordered leaderboards, Studio isolation, erasure requests | [[DataStore Fundamentals]], [[Saving Correctly - Autosave and BindToClose]] |
| [[Cookbook - UI]] | Finding your ScreenGui, `Activated` for all inputs, glitch-free panel tweens, attribute-bound labels, template lists, text sizing, aspect ratios, one screen-wide `UIScale`, safe-area insets, one-menu-at-a-time, press feedback, hiding core UI | [[ScreenGui Fundamentals]], [[Responsive UI for Phone Tablet Console and PC]] |
| [[Cookbook - Math CFrame and Vectors]] | Facing and yaw-only facing, angles, view cones, frame-rate independent smoothing, orbits, local and world space, uniform random points, cone spread, projectile launch velocity, grid snapping, closest point on a segment | [[Math Vectors and CFrames]], [[Springs Damping and Smoothing]] |
| [[Cookbook - Tables Strings and Time]] | Shallow and deep copies, deep freeze, Fisher-Yates shuffle, weighted picks, removal while iterating, counting, number abbreviation, thousands separators, durations, split and trim, choosing a clock, daily resets | [[Tables Metatables and OOP]], [[Strings Patterns and Formatting]] |

## Rules every recipe follows

1. **The server decides.** Anything that changes economy, combat or progression runs on the server; the client sends intent ([[How Exploits Work - The Client Boundary]]).
2. **Everything that can fail is wrapped.** Web calls, DataStores and `SetCore` go through `pcall` with a bounded retry.
3. **Nothing waits forever.** `WaitForChild` gets a timeout where the child might never come.
4. **Per-player state is cleaned up** on `PlayerRemoving` ([[Hunting Memory Leaks Step by Step]]).
5. **Strict types meet runtime checks.** Network input is typed `unknown` and narrowed with `typeof` and `IsA` ([[Luau Type System and Strict Mode]]).

## Suggested order for new scripters

Start with Players and Characters and Remotes and Networking (most first-game bugs are lifecycle and trust mistakes), then Data and Saving before real players arrive. Read the rest as needed.

## See also

[[Luau Language Essentials]], [[Task Library Coroutines and Yielding]], [[Events Signals and Connections]], [[Module Scripts and Requiring]], [[Project Structure and Bootstrapping]], [[Daily Rewards System End to End]], [[Saved Inventory End to End]], [[Melee Combat System End to End]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox DataStore Safety]] · Game Math Start Here · Advanced Luau Start Here · Debugging Start Here · Skill - Roblox Secure Remotes · Replication Boundary
<!-- auto-links:end -->
