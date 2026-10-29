---
tags: [ai, agents, ai-skill, debugging, testing, type/guide, area/ai, level/intermediate, area/debugging]
---
# Skill - Roblox Debugging

**Skill file:** [skills/roblox-debugging/SKILL.md](../skills/roblox-debugging/SKILL.md) (folder name `roblox-debugging`)

## What it does

AI agents love to "fix" bugs by adding a `task.wait` or wrapping something in `pcall`. This skill forbids that and makes the agent follow the method from the Debugging Deep Dives section:

1. **Classify** the symptom with the quick finder in [[Debugging Start Here]].
2. **Reproduce** and write it down: start state, steps, expected, actual and a failure rate, using Studio-gated cheat tools, test profiles and seeded RNG.
3. **Read the error properly**: the whole message, the first error in Output, and the frame below the top of the stack.
4. **Answer server or client** by inspecting both sides.
5. **Find the first wrong value**, not the visible one.
6. **Bisect** on a copy of the place, by system, recording each step.
7. **Explain** the cause in one sentence before changing code.
8. **Fix by family**, with specific patterns for desync (attributes for state, remotes for moments, server time for timers), races (connect then iterate existing, busy flags, no yielding module top levels), physics ownership, UI input, DataStores and live servers.
9. **Verify** at twice the original run count under stress.
10. **Leave a guard**: an assertion, test, counter or debug tool.

The final report states the repro, the one-sentence cause, the fix, the verification and the guard.

## When to use it

Any bug report, error in Output, "works in Studio but not live", rubber-banding, random failures, or UI that ignores taps. For lag and memory growth, use [[Skill - Roblox Performance Audit]] instead.

## Notes behind it

[[Debugging Start Here]], [[The Debugging Method - Reproduce Isolate Bisect]], [[Reading Luau Errors and Stack Traces]], [[Debugging Client-Server Desync]], [[Debugging Race Conditions and Yield Order]], [[Debugging Physics and Network Ownership]], [[Debugging UI Layout and Input]], [[Debugging DataStore Problems]], [[Debugging Live Servers]], [[Debugger Breakpoints and Logging]], [[Crash and Error Telemetry]], [[Live Incident Response and Post-Mortems]].

## Related

- [[AI Skills Start Here]]
- [[MCP Workflows for Scripting and Debugging]] for running the method through a Studio connection
- [[Agent Review Loops and Guardrails in Practice]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Secure Remotes]] · [[Skill - Roblox Anti-Exploit Review]] · [[Skill - Roblox Vault Research]] · [[Skill - Roblox DataStore Safety]] · [[Official Docs - Scripting and Luau]] · Telemetry Events
<!-- auto-links:end -->
