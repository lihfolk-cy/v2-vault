---
name: roblox-performance-audit
description: 'LihFolk: Find and fix performance problems in a Roblox game with measurements instead of guesses: MicroProfiler, memory leaks, network bandwidth, instance counts and mobile budgets. Use when the user says "lag", "low fps", "frame spikes", "memory keeps growing", "phones crash", "slow join", "place is too big", "optimize this", or asks for a performance review.'
---
# LihFolk Performance Audit

Performance work is a loop: name the problem, measure on the right device, fix the biggest item, measure again, leave a guard. Never optimise a suspected cause without a profile; the MicroProfiler usually disagrees with intuition.

## Inputs

- `VAULT`: LihFolk Vault V2, the knowledge base at `../../knowledge/` relative to this file (plugin root `knowledge/`). Start with `VAULT/INDEX.md` to find notes fast.
- The symptom, where it happens (client, server, both; which device), and access to the place or scripts.

## Procedure

1. **Name the problem.** Exactly one of: compute (frame time), memory (growth or crashes), or load time (join, zone load). Then client, server or both. Read frame time in milliseconds and worst frames, not average fps.

2. **Reproduce with production-like load.** Two clients in Studio are not a 30-player server. Studio numbers include Studio itself: measure client memory and frame time on the device class the players use (a low-end Android phone and an older iPhone are the usual baselines). Record baseline numbers before touching code: frame ms, memory MB by category, join seconds.

3. **Profile compute with the MicroProfiler.**
   - Open with Ctrl+F6, or Ctrl+Alt+F6 (docs disagree; try both). Pause with Ctrl+P to inspect a frame. Capture 30 to 90 frames and use Timers mode to sort labels by total time and call count.
   - For the server: Developer Console, MicroProfiler, Server tab, up to 60 frames.
   - Identify the family first: script, physics, render, network, UI.
   - Add your own labels with `debug.profilebegin("ConstantName")` and `debug.profileend()` around suspect systems. Use constant strings, keep begin and end balanced, and never span a yield.

4. **Compare against budgets** (rules of thumb for a 60 fps phone target, from the vault):
   - Rendering 8 to 10 ms, engine simulation 2 to 3 ms, your client scripts 2 ms total, headroom 2 to 3 ms.
   - Server scripts under about 5 ms average per heartbeat at full player count.
   - Measured content budgets from the reference project: a weapon kit folder under 2,500 instances; a sword swing's VFX at most 140 beams and 30 emitters (44 and 10 on low quality); at most 3 Highlights per effect, pooled; ambient effects asleep beyond 300 studs.

5. **Hunt memory leaks by slope, not by snapshot.**
   - Hold the workload constant, take at least three samples after warm-up, express growth as MB per hour or KB per repetition, and estimate time to the ceiling.
   - Find the growing category with the Developer Console memory view or `Stats:GetMemoryUsageMbForTag`. Use `debug.setmemorycategory` in large scripts so the heap view is readable.
   - Build a loop that multiplies the leak (respawn, zone change, menu open and close, equip and unequip), bisect systems by disabling them cleanly, then take heap snapshots before and after N repetitions to find the holder.
   - Usual causes: connections to other objects that `Destroy()` does not clean, per-player tables never cleared on `PlayerRemoving`, infinite loops spawned per object, uncapped caches and pools, menus cloned on every open.
   - Server memory that does not drop after players leave is not proof of a leak.
   - Targets: server about 6.25 GiB plus 100 MiB per player at peak, kept under 50% (Roblox docs; another docs page says stay under about 3 GB). Client: stay well under 1 GB on low-end phones in the heaviest area (rule of thumb). Investigate when the crash rate exceeds 2 to 3% (Roblox docs).

6. **Measure bandwidth.**
   - Write a per-player budget per category with an owner. A worked example for a 20-player action game is about 30 kbps per player server to client (rule of thumb, not a standard).
   - Do the fan-out arithmetic for every broadcast at full server size: one `FireAllClients` per hit is multiplied by every player.
   - The Developer Console Network tab shows web calls, not replication. Measure top talkers by A/B toggling or by instrumenting remotes.
   - Position-like streams go on unreliable remotes, batched under 1,000 bytes. Use interest tiers by distance. Anchor physics props unless they must move. Check the join payload with Print Join Size Breakdown.
   - Clients have about 500 remote requests per second; a per-frame reliable remote spends 60 of them.

7. **Audit instance counts and place size.**
   - Record per-folder instance counts, with client-replicated folders (ReplicatedStorage, Workspace, StarterGui) separate.
   - No backups, archives or imported sources inside the place; export to `.rbxm` on disk and rely on Version History. The reference project reached about 1.07 million instances, where Studio ran at about 15 fps with about 18 GB of memory and cloud saves timed out (measured).
   - Split scripts before they reach about 200,000 characters (measured cap; undocumented).
   - Delete only what is proven unreferenced, never on a name grep alone.

8. **Mobile pass.**
   - 15-minute soak on a real phone each release; thermal throttling does not show in 60 seconds.
   - An in-game graphics preset with live switching. Every effect has a low tier; onlooker effects are halved; ambient effects sleep with distance. Gameplay information (telegraphs) is identical on every tier.
   - Textures sized to on-screen use, mostly 512 or below.
   - Do not trust the Device Simulator for performance.

9. **Fix one thing at a time**, re-measure in the same scenario, and leave a guard: a label, a budget assertion, a soak test or a regression check.

## Hard rules

- No fix without a profile or measurement that points at it.
- One change per measurement.
- Never declare victory from Studio numbers alone.
- Never add a periodic "clear everything" to hide a leak.

## Report format

A table: symptom, measurement (before), cause, fix, measurement (after), guard left behind. Then any budgets that are missing.

## Checks before finishing

- [ ] Problem named (compute, memory, load; client or server).
- [ ] Baseline on a real target device recorded.
- [ ] Biggest item in the profile is the one fixed.
- [ ] Before and after numbers written down.
- [ ] Per-player tables cleared on leave; effects pooled with caps.
- [ ] A regression guard added.

## Read these vault notes

- `12 Performance Testing and Debugging/Performance Fundamentals.md`
- `12 Performance Testing and Debugging/MicroProfiler Guide.md`
- `12 Performance Testing and Debugging/Developer Console and Stats.md`
- `12 Performance Testing and Debugging/Memory Budgets and Leaks.md`
- `12 Performance Testing and Debugging/Hunting Memory Leaks Step by Step.md`
- `12 Performance Testing and Debugging/Network Bandwidth Budgets and Measuring Them.md`
- `12 Performance Testing and Debugging/Mobile and Low-End Optimization.md`
- `12 Performance Testing and Debugging/Script Performance.md`
- `12 Performance Testing and Debugging/Rendering Performance.md`
- `07 Lighting VFX and Audio/VFX Performance Budgets and Culling.md`
- `06 World Building and Art/Art Budgets - Triangles Draw Calls Memory.md`
- `13 Production and Case Studies/Case Study - Instance Cleanup and Place Size.md`
- `13 Production and Case Studies/Case Study - Fast Join and Deferred Loading.md`
