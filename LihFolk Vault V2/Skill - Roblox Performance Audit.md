---
tags: [ai, agents, ai-skill, performance, profiling]
---
# Skill - Roblox Performance Audit

**Skill file:** [skills/roblox-performance-audit/SKILL.md](../skills/roblox-performance-audit/SKILL.md) (folder name `roblox-performance-audit`)

## What it does

This skill stops an agent from "optimising" by guesswork. It runs the measurement loop from the Performance section: name the problem, measure on the right device, fix the biggest item, measure again, leave a guard.

Its steps:

1. **Name the problem**: compute, memory or load time; client, server or both. Read milliseconds and worst frames, not average fps.
2. **Reproduce under real load** and record baselines on a real low-end device, because Studio numbers include Studio.
3. **Profile with the MicroProfiler**: capture 30 to 90 frames, sort Timers, find the family (script, physics, render, network, UI), add `debug.profilebegin` labels around suspects.
4. **Compare with budgets**: for a 60 fps phone target, about 8 to 10 ms rendering, 2 to 3 ms simulation, 2 ms for your client scripts and 2 to 3 ms headroom; server scripts under about 5 ms per heartbeat (rules of thumb). Measured content budgets from the reference project, such as a weapon kit under 2,500 instances.
5. **Hunt leaks by slope**: constant workload, three samples after warm-up, MB per hour, then bisect systems and use heap snapshots.
6. **Measure bandwidth**: per-player budgets with owners, fan-out arithmetic for broadcasts, unreliable batches under 1,000 bytes, Print Join Size Breakdown for the join payload.
7. **Audit instance counts and place size**: no backups or imported sources in the place; split scripts before about 200,000 characters.
8. **Mobile pass**: a 15-minute soak on a real phone, a graphics preset, low tiers for every effect, identical gameplay information on every tier.

It reports a table of symptom, before, cause, fix, after and the guard left behind.

## When to use it

Lag, frame spikes, growing memory, phone crashes, slow joins, a huge place file, or a pre-release performance pass.

## Disputed facts it flags

The MicroProfiler shortcut (Ctrl+F6 or Ctrl+Alt+F6) and the server memory guidance (6.25 GiB plus 100 MiB per player under 50%, or about 3 GB) differ between docs pages; see [[Open Questions - Whole Vault]].

## Notes behind it

[[Performance Fundamentals]], [[MicroProfiler Guide]], [[Developer Console and Stats]], [[Memory Budgets and Leaks]], [[Hunting Memory Leaks Step by Step]], [[Network Bandwidth Budgets and Measuring Them]], [[Mobile and Low-End Optimization]], [[Script Performance]], [[Rendering Performance]], [[VFX Performance Budgets and Culling]], [[Art Budgets - Triangles Draw Calls Memory]], [[Case Study - Instance Cleanup and Place Size]], [[Case Study - Fast Join and Deferred Loading]].

## Related

- [[AI Skills Start Here]]
- [[Skill - Roblox Debugging]]
- [[Skill - Roblox Asset Import]]

## Connected notes
<!-- auto-links:start -->
[[Frame Budget]] · [[Skill - Roblox Vault Research]] · [[Skill - Roblox DataStore Safety]] · [[Skill - Roblox UI Builder]] · [[Debugging Start Here]] · [[Network Performance]]
<!-- auto-links:end -->
