---
tags: [pipelines, release, testing, qa, publishing, rollback, environments]
---
# Build Test and Release Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Debug flag live in production: test flags in the live place -> environments; pre-build state check
> - Live data corrupted by testing: staging writes to live DataStores -> separate universe or test keys
> - Release broke an untested feature: status not tracked -> change list with honest statuses
> - Dev, test and live separated; test data isolated
> - Change list with tags, owners and honest statuses
> - Shipping state checked: previews off, test flags cleared
>
> Cost: TL;DR ~160 tok · whole note ~3.6k tok. Read more: ## Stage 3: static checks · ## Stage 8: publish · ## Failure modes · ## Checklist
<!-- tldr:end -->

Every other pipeline in this section ends with content in a place. This one takes the place to players: assembling a build, proving it works, publishing it, watching it, and rolling it back if it does not. On Roblox the moment of release is brutally simple (Publish, and new servers run the new version) which is exactly why the process around it matters. This note is a release pipeline for a small team, with the gates one production game used and the honesty rules it learned. Related: [[Release Process and Rollbacks]] (production view), [[QA Checklists Before Release]], [[Testing Strategies and Frameworks]], [[Multi-Client and Live Testing]], [[Server Lifecycle and Shutdown]], [[Publishing an Experience]].

## Environments

Use at least two places, ideally three, in the same universe or in separate test universes:

| Environment | What it is | Who uses it | Data |
|---|---|---|---|
| **Dev** | the place people and tools edit (Team Create) | developers, agents | test profiles only |
| **Test / staging** | a separate place that receives builds | QA, CI cloud tests, trusted testers | separate DataStore keys or a separate universe |
| **Live** | the published game | players | real data |

Why separate: editing and testing in the live place means every tool run, half-finished pass and debug flag is one Publish away from players. The reference project worked in a single place for most of its life and therefore needed many compensating rules (kill switches, `Pre*` attributes, test flags on ServerStorage, a long list of changes marked "publish to ship"). It also had test flags accidentally left on: a "force intro" flag stayed set for days.

Data isolation is the part people skip. A test server writing to the live DataStore can corrupt real players' data. Use a separate universe for staging, or key test data separately (the reference project had a `TestProfileKey` attribute that switched to an isolated save key `TEST_<name>_<uid>`; its rule was never to set it before Play had actually started). See [[Data Loss Prevention and Recovery]].

## The stages

| # | Stage | Gate to pass | Owner |
|---|---|---|---|
| 1 | Freeze | list of changes in this build, each with status | lead |
| 2 | Build | place assembled (Rojo build or the dev place) | tool |
| 3 | Static checks | all scripts compile, scans clean, size caps, config validates | tool |
| 4 | Content audits | UI audits, id checks, budgets | tool |
| 5 | Automated tests | unit and cloud tests pass | CI |
| 6 | Staging play test | checklist passes on desktop and phone, multi-client | humans |
| 7 | Release notes | player notes and internal changelog | lead |
| 8 | Publish | version number recorded | lead |
| 9 | Watch | errors, analytics, reports for the first hours | everyone |
| 10 | Roll back or patch | if a gate in stage 9 fails | lead |

## Stage 1: freeze and the change list

A release is a list of changes, not "whatever is in the place now". For each change record: tag, owner, what it touches, and its **verification status**. The reference project's status vocabulary is worth adopting verbatim:

| Status | Meaning |
|---|---|
| **Edit only, not play-tested** | data and code checks passed in Edit; nobody has played it |
| **Play-tested** | someone played the feature in Studio Play or a test server |
| **Publish to ship** | done and verified in the dev place, waiting for the next publish |
| **Not done / weak** | known gaps, listed |

Most of that project's changelog entries carried "Edit only, not play-tested". That honesty is the point: it tells the release lead exactly which features need eyes before publish. A changelog that says "done" for everything is worthless at release time.

## Stage 2: build

- **Rojo projects**: `rojo build -o build.rbxl` in CI, or `rojo build` against a template place that holds the world (see [[Code Pipeline - Rojo Git and CI]]).
- **Studio-first projects**: the build is the dev place at a moment in time. Record the Studio version history number you are releasing from, so "what shipped" has an answer.

Before building, make sure the global state the dev place is left in is the shipping state: previews off, test flags cleared, debug UI hidden, `StarterGui.ShowDevelopmentGui` as intended, lighting not left in a preview.

## Stage 3: static checks

Run on every script and config module in the build:

```lua
--!strict
-- Release gate: compile every script and report size problems. Command bar or plugin.
local CAP = 200000
local results = { scripts = 0, compileErrors = {}, oversize = {} }
for _, s in game:GetDescendants() do
	if s:IsA("LuaSourceContainer") then
		local ok, src = pcall(function() return (s :: any).Source :: string end)
		if ok and src then
			results.scripts += 1
			if #src >= CAP * 0.975 then
				table.insert(results.oversize, ("%s (%d chars)"):format(s:GetFullName(), #src))
			end
			local fn, err = loadstring(src)
			if not fn then
				table.insert(results.compileErrors, s:GetFullName() .. ": " .. tostring(err))
			end
		end
	end
end
print(("%d scripts, %d compile errors, %d near the size cap"):format(
	results.scripts, #results.compileErrors, #results.oversize))
for _, e in results.compileErrors do warn(e) end
for _, e in results.oversize do warn("near cap: " .. e) end
```

`loadstring` checks syntax, not types. Add your use-before-definition scanner (it caught real crashes in the reference project), the type checker in CI if you use Rojo, and config validation ([[Data and Config Pipeline - Spreadsheets to Game]]). One reverting change in that project touched 47 scripts; the gate line in its changelog read "47 changed scripts compile, use-before-definition 0", plus the UI checks below.

## Stage 4: content audits

Automated checks over content, each with a clear pass number:

| Audit | Pass condition (reference project) |
|---|---|
| UI layout audit, every screen at 1920 x 1080 | score 10/10 per screen (pockets, double strokes, bleeds, uneven rows, off-centre captions) |
| Phone check, every screen at 844 x 390 and 667 x 375 | text at least 12 px, taps at least 44 px, gaps at least 8 px, 0 overlaps, 0 outside, desktop round trip 0 |
| HUD overlap check per game state at 5 viewports | 0 overlaps |
| Tutorial dry run | every onboarding step's target resolves at desktop and phone sizes |
| Audio | no unlevelled or banned ids |
| Asset ids | every referenced id is in an id map; no orphans |
| Instance budgets | kit folders under their budget (2,500 instances in that project), place totals tracked |

These are described in [[UI Asset Pipeline]] and [[Audio Pipeline]]. A tutorial dry run deserves special mention: the reference project's onboarding pointed a hand at buttons, and every UI redesign risked moving a target. A simulator that built the screens off-screen and ran the tutorial's own target finder at three viewport sizes found broken targets before players did.

## Stage 5: automated tests

- **Pure logic** (damage formulas, odds, economy maths, data migrations) as unit tests, runnable outside Roblox with Lune or inside with a test runner.
- **Engine logic** in the cloud through Open Cloud Luau Execution against the test place (scripts up to 4 MB, 5-minute runs, at most 10 incomplete tasks per place, data model changes not persisted; Roblox docs). Recipe in [[Code Pipeline - Rojo Git and CI]].
- **Data migrations**: load saved fixtures of old profile versions and check they migrate ([[Data Schema Design and Migrations]]).

What automation cannot tell you: whether it is fun, whether it feels responsive, whether a new player understands it. That is stage 6.

## Stage 6: staging play test

Publish the build to the **test place** (save, or publish to a private test universe) and play it with a checklist. Include:

- the first five minutes as a brand-new player (fresh profile);
- the changed features from the change list, especially every "not play-tested" item;
- one phone (touch, small screen), one desktop, a gamepad if supported;
- **two or more clients** for anything multiplayer (trading, PvP, parties, shared events) with Studio's multi-client test or a test server;
- purchases in the test place (Studio tests developer product prompts without charging);
- a server restart mid-session if data saving changed.

Write down what was **not** tested. The reference project's practice was to end every change with "what to check in Play", because its tools never started Play themselves (others might be testing in the same place).

## Stage 7: release notes

Two audiences, two documents:

- **Players**: short, plain, what is new and what is fixed. In-game update panels work well (the reference project had an Updates screen with a version changelog).
- **Team**: the change list with tags, owners, statuses, backups, kill switches and the release's version number. This is the document you will read at 2 a.m. during a rollback.

## Stage 8: publish

- From Studio: File > Publish to Roblox.
- From CI: the Place Publishing API (`POST /universes/v1/{universeId}/places/{placeId}/versions?versionType=Published`, key with `universe-places` Write; Roblox docs). It does not update EditableImage, EditableMesh, PartOperation, SurfaceAppearance or BaseWrap instances; the docs say to publish from Studio after modifying those. See [[Asset Upload Automation with Open Cloud]].

Record the new version number with the release notes. Existing servers keep running the old version until they close; Roblox lets you restart or migrate servers to the latest update from the Creator Dashboard (check the current options and their behaviour, as of October 2026). Choose by risk:

| Option | Player impact | Use when |
|---|---|---|
| Let old servers drain | none, but two versions coexist for hours | cosmetic changes, no data format change |
| Migrate to the latest update | players are moved to new servers | most releases |
| Shut down all servers | everyone is disconnected | security fixes, data format changes that old servers would corrupt |

**Data format changes need special care**: if the new version writes a profile shape the old version cannot read, an old server can load and save a player in the old shape and lose data. Make readers tolerant of newer fields, or force-migrate all servers. See [[Server Lifecycle and Shutdown]] and [[Saving Correctly - Autosave and BindToClose]].

## Stage 9: watch

For the first hours after a release:

- **Errors**: server and client error rates from your telemetry ([[Crash and Error Telemetry]]); compare to the previous version.
- **Analytics**: session length, day-1 retention for new users, purchase funnel ([[Analytics and Funnels]]).
- **Performance**: server heartbeat, memory, client frame time on low-end devices ([[Performance Fundamentals]]).
- **Players**: community channels and in-game reports.

Agree beforehand what number triggers a rollback (for example, error rate doubles or purchases drop by half in the first hour; rule of thumb).

## Stage 10: roll back or patch

Fastest first:

| Mechanism | Speed | Scope |
|---|---|---|
| **Kill switch** (config flag, live-overridable) | seconds with live config, one publish otherwise | one feature |
| **Revert to a previous place version** (version history) and publish | minutes | whole place |
| **Hotfix** a small change and publish | depends on the fix | targeted |

Every new system should ship with a kill switch (the reference project kept a table of them: cutscene off, a shared move off, a stance system off, weapon classes back on, a boss swap, a mutations flag, a rarity-locks flag). With live config ([[Global State and Live Config]]) switches work on running servers without a publish.

A version revert also reverts everything else in that release, so the change list (stage 1) is what tells you what else will be lost.

## Release cadence

Small, frequent releases are safer than big ones: fewer changes per release, easier rollbacks, clearer cause when metrics move. Weekly is a common rhythm for live games; big content drops still go out as one release but should be behind flags so the risky parts can be switched off independently. See [[Live Content Pipeline]] and [[Live Ops Events and Updates]].

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Debug flag live in production | test flags in the live place | environments; pre-build state check |
| Live data corrupted by testing | staging writes to live DataStores | separate universe or test keys |
| Release broke an untested feature | status not tracked | change list with honest statuses |
| Tutorial points at nothing after a UI change | targets moved | tutorial dry run gate |
| Old servers save players in the new format wrong | mixed versions | tolerant readers or migrate servers |
| Rollback removed unrelated fixes | revert restores the whole place | small releases; kill switches for big features |
| Place lost unions after CI publish | API limitation | publish such places from Studio |

## Checklist

- [ ] Dev, test and live separated; test data isolated
- [ ] Change list with tags, owners and honest statuses
- [ ] Shipping state checked: previews off, test flags cleared
- [ ] Static checks: compile, scans, size caps, config validation
- [ ] Content audits: UI, phone, HUD, tutorial, audio, ids, budgets
- [ ] Automated tests including data migrations
- [ ] Staging play test with fresh profile, phone, multi-client
- [ ] Player notes and team changelog with version number
- [ ] Server update strategy chosen for this release
- [ ] Watch metrics and rollback triggers agreed

## See also

[[Release Process and Rollbacks]] · [[QA Checklists Before Release]] · [[Code Pipeline - Rojo Git and CI]] · [[Version History and Backups]] · [[Global State and Live Config]] · [[Crash and Error Telemetry]] · [[Live Content Pipeline]] · [[Safe Changes in a Shared Place]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Places Universes and Experience Settings]] · [[Git and Source Control for Roblox]] · [[Server Shutdowns Soft Updates and Migration]] · [[Feature Flags]] · [[Feature Flags and Staged Rollouts]] · [[Packages and Shared Assets Across Places]]
<!-- auto-links:end -->
