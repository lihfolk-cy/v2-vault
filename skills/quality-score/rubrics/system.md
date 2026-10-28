# Rubric: game system / Luau code

Sources: skills `roblox-secure-remotes`, `roblox-datastore-safety`, `roblox-performance-audit`, `roblox-monetization-compliance`; notes found via the index.

## Hard gates
- Runs without errors in Studio (output checked) or tests pass
- Server-authoritative: every remote validates type, range and rate on the server; the client is never trusted for currency, damage or ownership
- Data: saves use `pcall` plus retry, session lock or profile library, `BindToClose`; purchases are idempotent (`ProcessReceipt` returns correctly)
- Paid random items: odds shown, `PolicyService` gated (fail closed)
- No deprecated APIs (`wait`, `spawn`, `delay`) and no unbounded loops

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| S1 | Correctness on edge cases (rejoin, leave mid-action, double click, lag) | 3 | breaks | some handled | all handled |
| S2 | Security beyond the gates (rate limits, sanity checks, exploit paths reviewed) | 3 | none | partial | reviewed |
| S3 | Performance (no per-frame allocations, connections cleaned up, mobile-safe) | 2 | leaks or spikes | ok | lean |
| S4 | Structure (config separate, modules, clear names, typed where useful) | 2 | tangled | ok | clean |
| S5 | Player-facing feedback (UI and VFX on every action, errors shown kindly) | 1 | silent | some | complete |
| S6 | Testability (a way to test without publishing) | 1 | none | manual | scripted |
