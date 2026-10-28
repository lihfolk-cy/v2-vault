---
name: roblox-debugging
description: Debug Roblox games with a fixed method (reproduce, isolate, bisect, explain, verify, guard) instead of guessing. Covers reading Luau errors, client-server desync, race conditions and yield order, physics ownership, UI input, DataStore problems and live servers. Use when the user says "bug", "broken", "not working", "error in output", "works in Studio but not live", "attempt to index nil", "infinite yield", "rubber-banding", or "random failures".
---
# Roblox Debugging

A fix without a reproduction is a guess. A `task.wait` or a silent `pcall` is not an explanation. Follow the method even when the cause looks obvious.

## Inputs

- `VAULT`: the LihFolk knowledge base at `../../knowledge/` relative to this file (plugin root `knowledge/`). Start with `VAULT/INDEX.md` to find notes fast.
- The symptom, the error text if any, and where it happens (Studio, live, which device, how often).

## Procedure

1. **Classify the symptom** with the quick finder in `23 Debugging Deep Dives/Debugging Start Here.md`:
   - Error text in Output: read errors (step 3).
   - Works in Studio, broken live: live servers, then race conditions.
   - UI shows a wrong number: desync.
   - Progress lost, rolled back or duplicated: DataStore problems.
   - Things vibrate or players get launched: physics and network ownership.
   - Button does nothing on phone or controller: UI layout and input.
   - Lag that grows over hours: memory leaks (use `roblox-performance-audit`).
   - Hitches: MicroProfiler.

2. **Reproduce.** Write the repro down: start state, steps, expected, actual, and a rate ("fails 3 times in 10"). Use Studio-gated tools to reach the state fast: a cheat service, test profiles, seeded RNG. Test with two or more clients when anything is shared, and with simulated latency when timing might matter.

3. **Read the error properly.**
   - Read the whole message and identify which expression was nil or wrong.
   - Scroll to the first error in Output. Later errors are often consequences.
   - Look at the frame below the top of the stack: the caller usually passed the bad value.
   - "Infinite yield possible" is a warning that often follows an earlier error; check before ignoring it.
   - Do not parse `debug.traceback` text; use `debug.info` when you need structured data.
   - Do not raise script timeouts; make long work yield.

4. **Answer server or client first.** Inspect both sides (Studio's Client/Server toggle). Many bugs are one side holding a stale or divergent copy.

5. **Isolate the first wrong value.** Do not fix the visible wrong value; find where it first became wrong. Put a tripwire on the value (an attribute changed signal, a single setter with an assertion) and trace back.

6. **Bisect.** On a copy of the place, never in a shared place others are testing in: disable systems by halves until the bug disappears, recording each step. For "it worked last week", bisect Version History, but not for bugs that live in stored data.

7. **Explain before fixing.** Write one sentence describing the sequence of events that produced the bad value. If you cannot, keep looking.

8. **Apply the right fix pattern by family.**
   - **Desync**: state goes through attributes or snapshots; moments go through remotes. Server-owned state is read-only on the client. Remote-driven state carries versions and can resync. Player-facing timers use `workspace:GetServerTimeNow()` and a server-set end time, never `os.clock()` or `os.time()` compared across machines. Never send state as events (late joiners and re-streamed instances miss them).
   - **Races and yield order**: every "on added" subscription connects first, then iterates existing players or characters, with a double-init guard. After any wait, re-check `player.Character == character`. Server handlers change state before yielding or hold a per-player busy flag. Module top levels never yield; a bootstrap defines init order. Readiness is an explicit flag or signal, never `task.wait(n)`.
   - **Physics and ownership**: answer which assembly and who owns it (watch over time with two clients) before reading code. One mover per assembly. Explicit ownership for NPCs, vehicles and interactive props, re-asserted after welds. Restore Humanoid state on every exit path of an ability, with a time cap. Do not use `TouchEnded` for zone exits.
   - **UI and input**: debug in a play test with the device emulator, not Edit mode. Check ancestors' `ZIndex` and `DisplayOrder`, one `UIScale` per branch, `gameProcessedEvent` respected, decorative full-screen frames not `Active`, and a `SelectedObject` set when a menu opens.
   - **DataStores**: do an uncached read first (`UseCache = false`), check budgets, look for stuck leases and writer identity, check version history for every loss report. Never debug on a real player's key.
   - **Live servers**: match reports to servers with job id and place version in every log line. Use gated admin commands (fetch server log, dump system state, raise log level). Ship logs off-server batched and without personal data. Feature flags let you turn a system off without a release. Open Cloud Luau Execution does not reach running live servers.

9. **Verify.** Run the repro at least twice as many times as it originally took to fail, under stress (latency, a real phone, multiple clients). Three clean runs do not prove a timing bug fixed.

10. **Leave a guard.** An assertion, validation, test, counter or debug tool that would catch this bug or its cousins. Write one line in the bug log. Remove injected delays and debug seeds before publishing.

## Hard rules

- No code changes before a written repro (except adding logging).
- No `task.wait(n)` as a fix for load order.
- No silencing nil errors with `if x then` everywhere; find the missing data.
- No untested fix code run in a production console.
- Debug and admin remotes are Studio-gated or allowlisted on the server and validate input.

## Report format

```
Symptom: ...
Repro: steps, rate
Cause (one sentence): ...
Fix: file and change
Verified: N runs under <conditions>, 0 failures
Guard left: ...
```

## Checks before finishing

- [ ] Repro written with a rate.
- [ ] Server or client answered.
- [ ] First wrong value found.
- [ ] Cause explained in one sentence.
- [ ] Verified at twice the original run count under stress.
- [ ] Guard added; debug-only code removed.

## Read these vault notes

- `23 Debugging Deep Dives/Debugging Start Here.md`
- `23 Debugging Deep Dives/The Debugging Method - Reproduce Isolate Bisect.md`
- `23 Debugging Deep Dives/Reading Luau Errors and Stack Traces.md`
- `23 Debugging Deep Dives/Debugging Client-Server Desync.md`
- `23 Debugging Deep Dives/Debugging Race Conditions and Yield Order.md`
- `23 Debugging Deep Dives/Debugging Physics and Network Ownership.md`
- `23 Debugging Deep Dives/Debugging UI Layout and Input.md`
- `23 Debugging Deep Dives/Debugging DataStore Problems.md`
- `23 Debugging Deep Dives/Debugging Live Servers.md`
- `12 Performance Testing and Debugging/Debugger Breakpoints and Logging.md`
- `12 Performance Testing and Debugging/Crash and Error Telemetry.md`
- `13 Production and Case Studies/Live Incident Response and Post-Mortems.md`
