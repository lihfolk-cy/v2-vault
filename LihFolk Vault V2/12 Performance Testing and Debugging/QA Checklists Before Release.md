---
tags: [qa, release, checklist, testing, performance, live-ops, type/checklist, area/performance, level/intermediate, api/ProcessReceipt, area/liveops]
---
# QA Checklists Before Release

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One checklist for every change, so people skip it for small ones and then skip it for big ones.
> - Avoid: Ticks without evidence.
> - Avoid: Testing only on the developer's PC.
>
> Cost: TL;DR ~90 tok · whole note ~3.3k tok. Read more: ## 8. G. Performance budgets ([[Performance Fundamentals]]) · ## 11. The "not play-tested" discipline · ## 12. One-page release checklist · ## Common mistakes
<!-- tldr:end -->

A release checklist is not bureaucracy; it is the memory of every bug that already shipped once. This note gives a tiered release process (hotfix, regular update, big launch), the gates each tier must pass, and the full checklists: code health, gameplay, multiplayer, data, monetisation, UI and devices, performance budgets, content hygiene, and the first hour after publishing. It ends with the "not play-tested" discipline that makes the checklists honest.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

Process context: [[Release Process and Rollbacks]], [[Publishing an Experience]], [[Live Ops Events and Updates]].

---

## 1. Tiers

Not every change needs every check. Match the gate to the risk.

| Tier | Examples | Required sections below |
|---|---|---|
| **Hotfix** | one-line fix, config value, text | A (code health), the affected area's play test, H (post-release) |
| **Regular update** | new item set, a new menu, balance pass | A, B, C, D (if data touched), E (if monetisation touched), F, G, H |
| **Big launch** | new world, new core system, event, monetisation changes | everything, plus a live test session with mixed devices and an agreed rollback plan |

Two rules apply at every tier:
1. **Everything that runs at runtime has been play-tested**, or the release notes say plainly which items were not (see section 9).
2. **A rollback path exists** before you publish: the previous version in Version History, and a feature flag for any risky new system ([[Global State and Live Config]]).

---

## 2. A. Code health (every release)

- [ ] Every changed script compiles and passes the type checker and linter ([[Testing Strategies and Frameworks]]).
- [ ] Project scans pass: use-before-definition, missing `WaitForChild`/`require` targets, remotes referenced but not created.
- [ ] Grep for Studio-only or temporary APIs and debug leftovers: temporary animation ids registered for local playback ([[Engine Gotchas]] 1.1), `print` spam in hot paths, test cheat ids, hard-coded "if my UserId" shortcuts.
- [ ] Unit specs pass (money math, drops, curves, migrations, validation).
- [ ] No script near the 200,000-character `Source` limit (Measured hard limit).
- [ ] Cheat tooling is server-gated and its allowlist contains only current team members.
- [ ] Feature flags for new systems default to the intended state.

---

## 3. B. Gameplay (per changed feature)

- [ ] The feature's written play-test script passes in a solo play test.
- [ ] Edge cases: zero, max, negative, empty inventory, full inventory, rapid repeated input (double-click, button mash), input during transitions.
- [ ] Respawn during the feature; leave during the feature.
- [ ] Death, teleport or zone change mid-action leaves no stuck state (effects, UI, movement locks).
- [ ] New content reachable through normal play, not only through cheats.
- [ ] First-time experience unchanged or deliberately updated ([[First-Time User Experience and Onboarding]]).
- [ ] Balance numbers match the design sheet ([[Balancing with Spreadsheets and Data]]).

---

## 4. C. Multiplayer ([[Multi-Client and Live Testing]])

- [ ] Two clients, join order both ways; late joiner sees correct state.
- [ ] Leave and rejoin mid-interaction (trade, party, shop, dungeon).
- [ ] Simultaneous actions (two players claiming one reward).
- [ ] UI isolation: no player sees another's private data.
- [ ] Streaming: walk away and back; teleport within the place.
- [ ] Network Simulator at 150 to 250 ms for timing-sensitive features.

---

## 5. D. Data and persistence ([[Data Loss Prevention and Recovery]])

- [ ] Schema migrations tested against fixture profiles from every previous version ([[Data Schema Design and Migrations]]).
- [ ] New fields have defaults; old profiles load without error.
- [ ] Save on leave and on server shutdown verified ([[Saving Correctly - Autosave and BindToClose]]); when verifying saves directly, read with caching disabled (Measured: reads served from cache for about 4 s otherwise; `DataStoreGetOptions.UseCache = false`).
- [ ] Session locking: fast rejoin to another server does not duplicate or lose data.
- [ ] No test data or cheat grants persisted in the live data store.
- [ ] Reset paths (profile reset, wipes) disabled or gated.

---

## 6. E. Monetisation ([[Developer Products and ProcessReceipt]], [[Game Passes]])

- [ ] Every new product and pass id points at the right live asset (not a test-place id).
- [ ] Prices and descriptions match the store page; odds shown equal odds rolled for any random reward (Measured practice: the config that drives the roll also drives the displayed odds).
- [ ] `ProcessReceipt` grants exactly once, idempotent on retry, and records the purchase before returning success ([[Purchase Data and Receipts]]).
- [ ] Purchase while the inventory is full, while dying, while teleporting.
- [ ] Pass ownership checked on join and on purchase during the session.
- [ ] Compliance: paid random items and disclosures follow current policy ([[Roblox Policies Ratings and Compliance]]).

---

## 7. F. UI and devices ([[Responsive UI for Phone Tablet Console and PC]])

- [ ] Every changed screen checked at desktop resolutions (for example 1920x1080, 1366x768, 1280x720) and phone landscape (for example 844x390 and 667x375).
- [ ] Measured phone rules from the reference project: text at least 12 px as drawn, taps at least 44 px, gaps at least 8 px, no overlaps, nothing off-screen, switching layouts and back restores the original exactly.
- [ ] Safe areas and the top bar inset respected ([[Safe Areas and Insets]]).
- [ ] Gamepad navigation reaches every button; selection visible ([[Gamepad and Console UX]]).
- [ ] Reduced motion setting respected where the game offers one ([[Accessibility]]).
- [ ] Text fits in other languages if localised ([[Localization]]).
- [ ] Device Simulator for layout; at least one **real phone** for feel.

---

## 8. G. Performance budgets ([[Performance Fundamentals]])

Measure on the baseline devices and compare with the previous release.

| Check | Target (rule of thumb unless noted) |
|---|---|
| Client fps, heaviest area, mid phone | steady 30+, ideally 60; no new hitches over 100 ms |
| Client memory, heaviest area with the largest menu open | not above the previous release by more than a few percent without a reason |
| Server heartbeat at full player count | 60 Hz average; worst frame under about 50 ms |
| Server memory | under 50% of the Docs budget (6.25 GiB + 100 MiB per player) |
| Join time on a phone | not regressed; Print Join Size Breakdown reviewed if ReplicatedStorage changed |
| New effects | within their caps (Measured examples: swing 140 beams / 30 emitters, element layer 12 meshes / 20 emitters, portal 6 emitters / 7 beams), with a low-quality variant |
| Highlights | grouped and pooled; count within the engine cap ([[Rendering Performance]]) |
| New per-frame loops | gated by visibility and distance; disconnect when idle ([[Script Performance]]) |
| Network | no large or frequent attributes on broadly replicated objects; cosmetic events distance-filtered ([[Network Performance]]) |
| Leaks | soak test of the new feature (open/close or enter/leave 100+ times) flat on LuaHeap and Instances ([[Memory Budgets and Leaks]]) |

---

## 9. Content hygiene

- [ ] No backup or WIP folders added to the place (Measured: they pushed one place past a million instances and Studio to about 15 fps). Backups go to disk and Version History.
- [ ] New models imported per piece, not as whole scenes (instancing and memory).
- [ ] Visual-only parts have `CanCollide`, `CanTouch`, `CanQuery` off; static parts anchored ([[Physics Performance]]).
- [ ] Collision on walkable changes verified (Measured practice: re-run a fixed ray grid and compare).
- [ ] Engine defaults you depend on pinned and recorded (for example `Model.LevelOfDetail`).
- [ ] Previews and debug toggles in Edit (lighting previews, moved covers, debug parts) switched off or restored before publishing (Measured: a lighting preview left on became the weather system's base atmosphere at play start).
- [ ] Asset permissions: animations, audio and images owned by the experience owner so they load live ([[Animation Asset Permissions and Groups]]).

---

## 10. H. Publish and the first hour

1. Note the version number you are replacing (for rollback).
2. Publish. Optionally migrate servers gradually if the update is risky ([[Server Lifecycle and Shutdown]]).
3. Join a live server yourself on PC and a phone. Smoke test: join, spawn, core loop once, open shop, buy something cheap if monetisation changed, change zone.
4. Developer Console, server log: no new errors ([[Developer Console and Stats]]).
5. Error Report: filter new errors since this version ([[Crash and Error Telemetry]]).
6. Performance dashboard by place version: crash rate, OOM exits.
7. Watch community channels.
8. Decide within the hour: keep, hotfix, flag off, or roll back. Write the decision down.

---

## 11. The "not play-tested" discipline

The checklists only work if their ticks are true. In the reference project, every change log line ended with how it had been verified, and a large number of entries honestly said **"Edit only, not play-tested"**: UI rebuilds, new enemy attacks, ambient effects, portal redesigns, performance fixes. Those entries were proven at the Edit level (compiled, scanned, dry-run on clones, layout-checked at phone sizes) but had not been seen running in a real session.

How to use that well:
- **Tag at the source.** The person (or tool) making a change writes the proof level in the same note as the change. Nobody reconstructs it later.
- **The tag is a queue.** Before release, every "not play-tested" item for this version goes into one play session with its test script. An untested item either gets tested or gets flagged off.
- **Edit proof is real but narrow.** It proves structure and code paths. It does not prove timing, replication, feel, effects (particles do not step normally in Edit), or player input.
- **Performance fixes need play proof too.** A server performance fix tagged "Edit only, not play-tested" is a hypothesis until a loaded server shows the heartbeat improve.
- **Never let "done" mean "written".** In reports and stand-ups, "done" means play-tested, or the sentence says otherwise.

---

## 12. One-page release checklist

Copy into each release note:

```
Release vX (date)          Tier: hotfix / update / launch
Rollback target: vY        Feature flags: [list] default [on/off]

A Code     [ ] compile/type/lint  [ ] scans  [ ] specs  [ ] no debug leftovers
B Play     [ ] test scripts pass  [ ] edge cases  [ ] respawn/leave mid-action
C Multi    [ ] join order x2  [ ] leave/rejoin  [ ] latency  [ ] streaming
D Data     [ ] migrations on fixtures  [ ] save on leave/shutdown  [ ] fast rejoin
E Money    [ ] live ids  [ ] grant once  [ ] odds shown = odds rolled
F UI       [ ] desktop sizes  [ ] phone 844x390 + 667x375  [ ] gamepad  [ ] real phone
G Perf     [ ] fps/memory vs last  [ ] server Hz at load  [ ] effect caps  [ ] soak
Hygiene    [ ] no backups in place  [ ] previews off  [ ] asset permissions
Not play-tested items: [list or "none"]
After publish: [ ] smoke PC  [ ] smoke phone  [ ] server log  [ ] Error Report  [ ] dashboard
Decision at +1h: keep / hotfix / flag off / rollback
```

---

## Common mistakes

- One checklist for every change, so people skip it for small ones and then skip it for big ones.
- Ticks without evidence.
- Testing only on the developer's PC.
- No rollback target noted before publishing.
- Monetisation ids left pointing at a test place.
- Shipping "Edit-tested" as "tested".

## See also

[[Release Process and Rollbacks]] · [[Testing Strategies and Frameworks]] · [[Multi-Client and Live Testing]] · [[Crash and Error Telemetry]] · [[Performance Fundamentals]] · [[Publishing an Experience]] · [[Live Ops Events and Updates]] · [[Data Loss Prevention and Recovery]] · [[Animation Review Checklist]] · [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Build Test and Release Pipeline]] · [[Mobile and Low-End Optimization]] · [[Multi-Client and Device Playtesting Protocols]] · Skill - Roblox Performance Audit · Live Incident Response and Post-Mortems · Data Schema Versioning
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre QA Passes - Test Checklists per Game Type]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[Hunting Memory Leaks Step by Step]] · [[In-Game Bug Report Button with Automatic Context]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[Gated Tester Commands and Debug Panels]] · [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]]
<!-- related:end -->
