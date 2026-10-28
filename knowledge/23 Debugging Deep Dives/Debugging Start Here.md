---
cssclasses: [vault-hub]
tags: [debugging, hub, start-here]
---
# Debugging Start Here

This section goes deeper than the debugging notes in [[Debugger Breakpoints and Logging]], [[Crash and Error Telemetry]] and [[Developer Console and Stats]]. Those cover the tools. These notes cover **methods for specific kinds of bug**: how to get from a vague report to a cause you can explain, for the bug families that cost Roblox developers the most time.

## How to use this section

1. Start with the method. Every other note assumes it.
2. Pick the note that matches the symptom, using the table below.
3. Each note ends with common mistakes and a checklist; use the checklist as your exit test.

## The notes

| Note | Read it when |
|---|---|
| [[The Debugging Method - Reproduce Isolate Bisect]] | always first: repro scripts, seeded RNG, finding the first wrong value, bisecting scripts and versions, minimal repro places |
| [[Reading Luau Errors and Stack Traces]] | you have an error message or a warning and want to know what it really means; `debug.traceback` and `debug.info` as tools |
| [[Debugging Client-Server Desync]] | client and server disagree: missing, stale, divergent or out-of-order state; attributes vs remotes |
| [[Debugging Race Conditions and Yield Order]] | it works sometimes, on some devices, or only with latency; `task.spawn` vs `task.defer`, `WaitForChild`, `PlayerAdded` and character load order |
| [[Debugging DataStore Problems]] | throttling, stuck session locks, rollbacks, reading real saved data, Studio API access |
| [[Debugging Live Servers]] | the bug only happens in live servers: finding the server, admin log viewers, state dumps, log shipping, flags, Open Cloud Luau Execution |
| [[Debugging Physics and Network Ownership]] | jitter, flinging, ownership flips, Humanoid physics, Touched problems |
| [[Debugging UI Layout and Input]] | draw order, clipping, AutomaticSize loops, UIScale vs TextScaled, input sinking, gamepad selection |

## Symptom quick finder

| Symptom | Go to |
|---|---|
| "attempt to index nil", "Infinite yield possible", script timeout | [[Reading Luau Errors and Stack Traces]] |
| Works in Studio, broken live | [[Debugging Live Servers]], then [[Debugging Race Conditions and Yield Order]] |
| UI shows a wrong number | [[Debugging Client-Server Desync]] |
| Progress lost or rolled back | [[Debugging DataStore Problems]] |
| Items duplicated | [[Debugging DataStore Problems]], [[Trading Systems Without Duplication]] |
| Things vibrate or players get launched | [[Debugging Physics and Network Ownership]] |
| Button does nothing on phone or controller | [[Debugging UI Layout and Input]] |
| Lag that grows over hours | [[Hunting Memory Leaks Step by Step]], [[Debugging Live Servers]] |
| Hitches and frame spikes | [[MicroProfiler Guide]] |
| Animation-specific problems | [[Troubleshooting Table]] |

## Related notes elsewhere

- Tools: [[Debugger Breakpoints and Logging]], [[Developer Console and Stats]], [[MicroProfiler Guide]], [[Crash and Error Telemetry]].
- Error handling: [[Error Handling and Retries]], [[Error Handling - pcall xpcall and Promise Patterns]].
- Testing: [[Testing Modes - Play Run and Multi-Client]], [[Multi-Client and Live Testing]], [[Automated Testing with TestEZ and Jest-Lua]], [[Multi-Client and Device Playtesting Protocols]].
- Networking and security: [[Replication Rules]], [[Network Ownership]], [[Server Authority and Validation]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Remote Abuse Patterns and Rate Limiting in Practice]], [[Anti-Exploit Start Here]].
- Data: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]].
- Performance: [[Hunting Memory Leaks Step by Step]], [[Network Bandwidth Budgets and Measuring Them]].
- Incidents: [[Live Incident Response and Post-Mortems]].

## Three rules that apply everywhere

1. **Reproduce before you change code.** A fix without a repro is a guess.
2. **Explain before you fix.** If you cannot say in one sentence what sequence of events caused the bad value, keep looking. A `task.wait` or a silent `pcall` is not an explanation.
3. **Leave a guard.** Every fixed bug should leave behind an assertion, a validation, a test, a counter or a debug tool that would catch it, or its cousins, next time.

Source labels used throughout: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Debugging]] · [[Links - Error handling and debugging]] · [[Telemetry Events]] · [[Skill - Roblox Performance Audit]] · [[Cookbook - Remotes and Networking]] · [[Deterministic Simulation]]
<!-- auto-links:end -->
