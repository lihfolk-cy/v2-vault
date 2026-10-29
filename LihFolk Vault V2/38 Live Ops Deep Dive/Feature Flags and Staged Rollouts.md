---
tags: [live-ops, feature-flags, rollout, configservice, release, kill-switch, luau, type/guide, area/liveops, level/advanced, api/ConfigService, area/scripting]
---
# Feature Flags and Staged Rollouts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `math.random` to decide inclusion -> Deterministic hash with per-flag salt
> - Avoid: Same salt for every flag -> Flag name in the hash input
> - Avoid: Release flag defaults on -> Default off, in code
> - Every flag has a kind, an owner, a safe default and (for release flags) a removal date
> - Release flags default off; kill switches default on
> - Sticky bucketing with a per-flag salt; uniformity checked once
>
> Cost: TL;DR ~150 tok · whole note ~4.6k tok. Read more: ## 4. Stable percentage rollouts · ## 5. Planning a staged rollout · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

A feature flag is a value, read at runtime, that decides whether a piece of code runs. A staged rollout uses flags to turn a feature on for a small group first, watch it, and widen it step by step. Together they separate **deploying** code (publishing a place) from **releasing** a feature (players getting it), which is the most useful idea in live operations: a publish becomes routine, and a release becomes a dial you can turn back.

[[Global State and Live Config]] explains experience configs (`ConfigService`), a typed wrapper with defaults, refresh policy and kill switches. [[Release Process and Rollbacks]] covers publishing and the rollback ladder. This note goes deeper into the flag system itself: the kinds of flags and their lifecycles, percentage and allowlist targeting with stable bucketing, rollout plans with abort criteria, the parts of a feature a flag cannot roll back (data), the small-game statistics problem, and flag debt.

Source labels: **Roblox docs (as of October 2026)**, **rule of thumb**, **measured in the reference project**.

## 1. What Roblox gives you

From the configs documentation (Roblox docs, as of October 2026; full detail in [[Global State and Live Config]]):

- Typed config keys (string, number, boolean, JSON), up to **1,000 active configs**, edited in Creator Hub or in Studio.
- New values are **staged** (visible in Studio play sessions for your team) and then published: **Publish now** (about 15 seconds to 1 minute) or **Publish over 15 min** (gradual). The docs do not list other durations or percentages.
- **Targeting** by country, language, new vs returning, acquisition source, first-played window, payer and activity statuses, engagement and platform spender status; up to **100 conditions per game and 20 per key**, first match wins.
- **Experiments** use the same machinery through `GetConfigForPlayerAsync` ([[A-B Testing and Experiments on Roblox]]).
- **History and Restore** for every change, and `ConfigService:SetTestingValue` to override a value on one server (or one Studio session).

What the platform does not give you out of the box, as far as the docs describe: an arbitrary "5 percent of players" rollout dial, allowlists by user id, or a "minimum build version" condition. Those you build on top, and they are the subject of most of this note.

## 2. Four kinds of flags

Flags are not one thing. Mixing them in one flat list is how flag systems rot (rule of thumb taxonomy, common across the industry):

| Kind | Purpose | Default when unreadable | Lifetime | Example |
|---|---|---|---|---|
| Release flag | Hide unfinished or unreleased work; staged rollout | Off | Weeks; removed after full release | `newTradingUi` |
| Ops flag (kill switch) | Turn off a risky system in an incident | On (system works) | Permanent for risky systems | `tradingEnabled` |
| Experiment flag | Choose a variant for measurement | Control variant | Length of the experiment | `onboardingVariant` |
| Permission flag | Give a feature to specific people (testers, admins) | Off | Long-lived | `betaTesters` |

The default column matters most. A release flag that defaults **on** ships unfinished work to everyone the moment configs fail to load. A kill switch that defaults **off** turns off trading for the whole game during a config outage. Write the default into the flag's definition and review it like code.

## 3. Naming and definition

A flag definition should answer, in one place: what it controls, its kind, its default, its owner, and when it should be deleted. Keeping it as structured data in a JSON config (one key for all release flags) lets you validate it and keeps the 1,000-key limit far away. Booleans that operators flip during incidents are better as their own keys, so the dashboard shows them plainly and history is per switch.

```json
{
  "newTradingUi": { "kind": "release", "percent": 10, "allow": [1234567], "minBuild": 412, "owner": "ui", "removeBy": "2026-12-01" },
  "bossRushMode": { "kind": "release", "percent": 0, "allow": [], "minBuild": 415, "owner": "gameplay", "removeBy": "2027-01-15" }
}
```

(User ids in examples are placeholders.)

Naming rules of thumb: positive names (`tradingEnabled`, not `disableTrading`, so `true` always means "the thing happens"), a prefix or kind field to tell flags apart, no version numbers in names (the rollout percentage is the version).

## 4. Stable percentage rollouts

A percentage rollout must be **sticky**: a player in the 10 percent stays in it on every server, every session, and when the percentage rises to 25 they remain included. That rules out `math.random` per session. Use a deterministic hash of the user id and a per-flag salt into a bucket from 0 to 9,999, and include the player if `bucket < percent * 100`. Raising the percentage only adds players; lowering it removes the most recently added first.

The per-flag salt matters: without it, the same 10 percent of players get every new feature first, and they become a permanently unrepresentative test group.

```lua
--!strict
-- ServerScriptService/Live/Flags (ModuleScript)
-- Release flags with sticky percentage rollout, allowlist and minimum build.
local ConfigService = game:GetService("ConfigService")
local HttpService = game:GetService("HttpService")

local BUILD = 415 -- bump on every publish; also shown in the in-game version label

export type FlagDef = {
	kind: string,
	percent: number, -- 0 to 100, may have decimals (0.5 = 0.5 percent)
	allow: { number },
	minBuild: number,
}

local Flags = {}
local defs: { [string]: FlagDef } = {}

-- djb2 string hash kept inside 32 bits. Products stay below 2^38, well within
-- exact double range, so the result is identical on every server.
local function hash(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	return h
end

function Flags.bucket(flagName: string, userId: number): number
	return hash(`{flagName}:{userId}`) % 10000 -- 0..9999
end

local function parse(raw: any)
	local value = raw
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		value = if ok then decoded else nil
	end
	if type(value) ~= "table" then
		warn("[Flags] unreadable flag config; keeping previous")
		return
	end
	local out: { [string]: FlagDef } = {}
	for name, d in value do
		if type(name) == "string" and type(d) == "table" then
			out[name] = {
				kind = if type(d.kind) == "string" then d.kind else "release",
				percent = math.clamp(tonumber(d.percent) or 0, 0, 100),
				allow = if type(d.allow) == "table" then d.allow else {},
				minBuild = tonumber(d.minBuild) or 0,
			}
		end
	end
	defs = out
end

-- Release flags default OFF: unknown flag, missing config, old build => false.
function Flags.isOn(flagName: string, player: Player): boolean
	local d = defs[flagName]
	if not d or BUILD < d.minBuild then
		return false
	end
	if table.find(d.allow, player.UserId) then
		return true
	end
	return Flags.bucket(flagName, player.UserId) < d.percent * 100
end

task.spawn(function()
	local ok, snap = pcall(function()
		return ConfigService:GetConfigAsync()
	end)
	if not ok then
		warn("[Flags] configs unavailable; all release flags off")
		return
	end
	parse(snap:GetValue("releaseFlags"))
	snap:GetValueChangedSignal("releaseFlags"):Connect(parse)
	snap.UpdateAvailable:Connect(function()
		pcall(function()
			snap:Refresh()
		end)
	end)
end)

return Flags
```

Design notes:

- **Evaluate once per player per session for anything visible.** A player who sees the new trading UI should not lose it mid-session because the percentage was lowered; cache the result on join (an attribute on the player works) unless the change is an emergency. Kill switches are the exception: they apply immediately.
- **Server decides, client renders.** Send the client only the evaluated booleans it needs, never the whole flag config: the config names unreleased features and is a gift to dataminers ([[Global State and Live Config]] lists this as a common mistake).
- **`minBuild` handles old servers.** After a publish, servers on the old build keep running until restarted or emptied ([[Server Lifecycle and Shutdown]]). A flag turned on at 100 percent for a feature that only exists in build 415 must not tell build 412 servers to call code they do not have. With the build check, old servers simply see the flag as off.
- **The hash is not cryptographic** and does not need to be; it needs to be stable and roughly uniform. Test the uniformity once: bucket 100,000 sequential ids and check each 10 percent band holds about 10,000.
- **Combine with platform targeting where it fits.** If you want "new players only" or "only in Brazil", use a config condition rather than reimplementing it. Use the custom percentage for the rollout dial itself.

## 5. Planning a staged rollout

A rollout is a plan written before the flag moves, with numbers that trigger an abort. Template (rule of thumb):

| Stage | Who | Duration | Proceed if | Abort if |
|---|---|---|---|---|
| 0. Dark launch | Code shipped, flag 0 percent | Until next stage is ready | Build healthy; no new errors from the dormant code | New errors referencing the feature's modules |
| 1. Internal | Allowlist (team, testers) | 1 to 3 days | No blockers in play | Any data-affecting bug |
| 2. Canary | 1 to 5 percent | 1 to 2 days, including a weekend evening | Error rate, purchase rate, session length within noise of control | Error rate up clearly, support tickets mentioning it |
| 3. Wide | 25 to 50 percent | 2 to 4 days | Guardrails hold | Guardrail moves against you |
| 4. Full | 100 percent | Keep the flag for one more release | Stable for a week | Late-surfacing bugs: back to stage 3 |
| 5. Cleanup | Flag and old path deleted from code | Next publish | | |

What to watch at each stage: server error counts from the feature's modules ([[Crash and Error Telemetry]]), the feature's own funnel events, purchase and refund rates if it touches money, memory and frame time if it touches rendering, and player reports. Compare the flagged group with the unflagged group at the same time, not with last week, so school holidays and other updates hit both.

### The small-game problem

Percentages are meaningless when the numbers are small. At 1,000 daily players, a 2 percent canary is 20 players a day; you will not see a 10 percent change in anything except a crash. Rules of thumb for small games:

- Use the canary for **catastrophic failures** (errors, broken purchases, data problems), not for measuring improvement. Those show up in a handful of sessions.
- Use **time** instead of **percentage** to gather exposure: 10 percent for a week tells you more than 2 percent for a day.
- Measure improvement with a proper experiment at 50/50, with the sample size worked out in advance ([[A-B Testing and Experiments on Roblox]]), or accept that you are making a judgement call and say so.

### Rollout of server-wide features

Some features cannot be per player: a new map, a physics change, a matchmaking rule. Bucket by **server** instead: hash `game.JobId` and enable the feature on a percentage of servers. Players then see the feature depending on which server they join, which is acceptable for most things and confusing for some (a player who rejoins and loses a map). Prefer per-player flags where the feature allows it.

## 6. What a flag cannot roll back

Flags turn code paths off. They do not undo what the code already wrote. This is the most common false sense of safety in flag systems.

- **Data written in a new shape.** If the new inventory code writes `data.Items` as a dictionary instead of a list, flipping the flag off sends players back to old code that cannot read their save. The fix is **expand and contract**: first ship code that reads both shapes (flag-independent), then turn on writing the new shape, then, much later, remove reading the old shape. See [[Data Schema Design and Migrations]] and [[Schema Migrations - Worked Case Studies]].
- **Currency and items granted.** A new reward system that over-granted during a 10 percent canary has already inflated those players' wallets. Turning the flag off stops new grants; cleaning up is a separate, careful operation ([[Economy Resets and Seasonal Wipes]] discusses when targeted corrections are worth the trust cost).
- **Purchases.** A new shop that sold something cannot unsell it. Purchased items must keep working when the flag is off, or the flag must never be turned off once purchases happened.
- **Messages sent.** Notifications and announcements cannot be recalled.

Rule of thumb: for every flag, write one line in its plan: "If turned off after N days, what state is left behind, and does old code handle it?" If the answer is "old code breaks", the flag is not a safety net and the rollout must be slower.

## 7. Testing flagged code

- **Studio:** staged config values are visible in Studio play sessions for your team, so you can stage a flag at 100 percent and test without touching live players.
- **One live server:** `ConfigService:SetTestingValue(key, value)` from the server Developer Console overrides a value for that server only, then `ClearTestingValue` to remove it. It is precise, but it affects everyone on that server, so use a private server or a quiet one.
- **Both paths:** every release flag doubles the code paths. Test with the flag on and off before each publish while the flag exists; the "off" path is the one that runs when configs fail, and it is the one nobody tests.
- **Automated tests** can inject flag values directly into the module (expose a setter guarded by `RunService:IsStudio()`), so unit tests cover both branches ([[Automated Testing with TestEZ and Jest-Lua]]).

## 8. Flag debt

Every flag that outlives its purpose is a branch nobody tests and a config key that confuses the next person. Industry experience is consistent: flag systems without a removal habit accumulate dozens of dead flags within a year. Habits that work (rule of thumb):

- **`removeBy` date on every release flag**, checked by a script or a weekly glance at the config.
- **Remove the flag in the release after reaching 100 percent**, not "someday". Removing means deleting the old code path too.
- **Kill switches are reviewed, not removed.** Once a quarter, flip each one on a test server to prove it still works. A kill switch that has never been tested is a hope.
- **Count flags.** If live release flags exceed about ten for a small team, stop adding new ones until some are removed.

### Incident use

In an incident, the flag dashboard is the fastest tool: turn off the switch, confirm the effect, then investigate ([[Live Incident Response and Post-Mortems]]). Two practices make this reliable:

1. **A runbook line per kill switch**: what it turns off, what players see instead (a "temporarily unavailable" message is better than a silently missing button), and what to tell players ([[Patch Notes and Player Communication]]).
2. **Publish messages on every config change**, even in a hurry. Config history records author and time; the message is the only place the reason lives.

The reference project's admin tooling had a server-side switch to force a periodic event open for testing, and gated a dangerous admin grant behind an explicit attribute that defaulted to off after it had silently modified a real save (measured in the reference project; see [[Data Schema Design and Migrations]]). The lesson generalises: any switch that changes real player data defaults to off and is visible.

## 9. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| `math.random` to decide inclusion | Players flicker in and out between sessions | Deterministic hash with per-flag salt |
| Same salt for every flag | The same players test everything | Flag name in the hash input |
| Release flag defaults on | Config outage ships unfinished work | Default off, in code |
| Kill switch defaults off | Config outage disables a working system | Default on |
| No build check | Old servers try to run new features | `minBuild` per flag |
| Flag config sent to clients | Leaks unreleased features | Send evaluated booleans only |
| Flag used to "roll back" a data shape change | Saves unreadable by old code | Expand and contract migrations |
| Canary judged on improvement at tiny samples | False wins and false losses | Canary for breakage; experiments for improvement |
| Flags never removed | Dead branches, untested paths | `removeBy` dates; delete after full release |

## 10. Checklist

- [ ] Every flag has a kind, an owner, a safe default and (for release flags) a removal date
- [ ] Release flags default off; kill switches default on
- [ ] Sticky bucketing with a per-flag salt; uniformity checked once
- [ ] `minBuild` on release flags; build number bumped every publish
- [ ] Clients receive evaluated results only
- [ ] Rollout plan with stages, watch metrics and abort criteria written before stage 1
- [ ] "What is left behind if turned off" answered for each flag; data changes use expand and contract
- [ ] Both flag paths tested before publish
- [ ] Kill switches tested quarterly; runbook line for each
- [ ] Config changes published with a reason in the message

## See also
[[Live Ops Deep Dive Start Here]] · [[Global State and Live Config]] · [[Release Process and Rollbacks]] · [[A-B Testing and Experiments on Roblox]] · [[Live Content Pipeline]] · [[Data Schema Design and Migrations]] · [[Live Incident Response and Post-Mortems]] · [[Server Lifecycle and Shutdown]] · [[Crash and Error Telemetry]] · [[Event Calendars and Content Planning]]

## Connected notes
<!-- auto-links:start -->
[[Feature Flags]] · Build Test and Release Pipeline · Economy Telemetry and Balancing Live · Server Shutdowns Soft Updates and Migration · Debugging Live Servers · Scoping and Roles for Small Teams
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Server Shutdowns Soft Updates and Migration]] · [[Economy Telemetry and Balancing Live]] · [[Build Test and Release Pipeline]] · [[Roadmaps Milestones and Scope Control]] · [[Battle Pass and Season Design]] · [[Limited-Time Offers - Design and Ethics]]
<!-- related:end -->
