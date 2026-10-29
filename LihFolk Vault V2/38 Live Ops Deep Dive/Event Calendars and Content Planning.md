---
tags: [live-ops, events, calendar, planning, content, production, scheduling, luau, type/guide, area/liveops, level/advanced, api/ConfigService]
---
# Event Calendars and Content Planning

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Calendar drawn before measuring throughput -> Plan from the last six weeks' output
> - Avoid: No slack -> One buffer week per month
> - Avoid: Multiplier every weekend -> Space them; measure weekdays
> - Roadmap, calendar and work plan are separate documents
> - Throughput measured; maintenance share estimated
> - Mostly config, rotation and reskin events; one mechanic or content event per month at most
>
> Cost: TL;DR ~140 tok · whole note ~4.8k tok. Read more: ## 2. Throughput first, calendar second · ## 5. The calendar as data · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

A live game runs on two clocks. The **player clock** is what players see: a weekend boost every other Friday, a holiday event, a new season on the first of the month. The **production clock** is what the team can actually build: how many assets, maps and systems fit into a week once bugs and support are paid for. An event calendar is the document that makes those two clocks agree months in advance. Without one, small teams either promise more than they can ship or go quiet for weeks, and both show up in the retention curve.

[[Live Ops Events and Updates]] gives a sample four-week calendar and the platform tools; [[Update Cadence and Hype Cycles]] covers choosing a release rhythm and building anticipation. This note goes further: planning horizons, sizing content against team throughput, the taxonomy of event types and how they combine, the calendar as data your servers read, validation that catches clashes before players do, and the review loop that makes next quarter's plan better than this one's.

Source labels: **Roblox docs (as of October 2026)**, **rule of thumb**, **measured in the reference project**.

## 1. Three horizons, three documents

A single spreadsheet that mixes "Halloween event" with "fix the pet duplication bug" does not survive contact with a busy week. Split by horizon (rule of thumb):

| Horizon | Document | Granularity | Who reads it | Changes how often |
|---|---|---|---|---|
| Quarter (about 13 weeks) | Roadmap | Seasons, major updates, holiday beats | Whole team, partners, creators you work with | Monthly |
| Month to season | Event calendar | Every player-visible beat with UTC start and end | Team, community managers, the game's own servers | Weekly |
| Week | Work plan | Tasks, owners, done criteria | People doing the work | Daily |

The roadmap answers "what are we becoming". The calendar answers "what does a player see on each day". The work plan answers "what do I do today". Only the calendar should be machine-readable, because the game itself will read it (section 5).

## 2. Throughput first, calendar second

The usual mistake is drawing the calendar from what would be exciting, then discovering the team can deliver about half of it. Measure throughput first.

### Measure your real capacity

Take the last four to six weeks and count shipped, player-visible units, not tasks. Useful units for a Roblox team:

- **Content unit:** one new zone, boss, item set of about 8 to 12 items, or mode.
- **Event unit:** one timed event with its own rewards and some new art.
- **System unit:** one new system (trading, guilds, a pass).
- **Maintenance:** bugs, support, performance work, which always takes a share.

Rule of thumb for a team of one to four: maintenance consumes **30 to 40 percent** of capacity once a game is live, more in the weeks after a big update. If the last six weeks shipped two content units and three event units with maintenance at 35 percent, plan the next quarter for about the same, not double.

### The reuse budget

Events are cheaper than content when they reuse. Classify every planned beat by how much new work it needs:

| Event type | New work | Example |
|---|---|---|
| Multiplier | Config only | 2x XP weekend, luck boost |
| Rotation | Config plus maybe an icon | Weekly shop rotation, featured zone |
| Reskin | Art on existing systems | Snow-themed hub, holiday versions of existing items |
| Mechanic event | New rules on existing systems | A boss rush, a server-wide collection goal |
| Content event | New zone, boss or mode, timed | A haunted map open for two weeks |

A sustainable calendar is mostly the first three rows with one mechanic or content event per month (rule of thumb). Multipliers cost nothing to make but lose effect if they run every weekend: players learn to wait for them and play less on weekdays. Space them out, and measure weekday play before and after.

### Buffer

Every plan needs a slack week per month, or its equivalent in capacity. Something will break: a Roblox platform change, a viral moment you want to ride, an exploit. One production game shipped fast on a daily build log but had no release cadence, and the result was that player-facing beats were decided day by day ([[Release Process and Rollbacks]]). A calendar with slack lets you absorb a bad week without cancelling a promised event.

## 3. What goes on the calendar

### Fixed external beats

Some dates are given. Plan them a quarter ahead because they need art and featuring lead time:

- **Major holidays** for your main regions: Halloween, the December holidays, Lunar New Year, Easter, summer break. School holidays drive Roblox traffic strongly; check the countries that make up most of your players in your analytics, because "summer" starts at different times in different hemispheres and school systems.
- **Platform-wide moments.** Roblox runs its own campaigns some years; they are announced with varying lead time, so leave room rather than planning around one.
- **Your own anniversaries.** Launch anniversary and "1 billion visits" style milestones are cheap, honest reasons for an event.

### Your own rhythm

Layer your repeating beats on top, from the cadence you chose: weekly rotations, a fortnightly weekend event, a monthly update or season start. Repeating beats are what players can learn; one-off beats are what they talk about.

### Overlap rules

Write down how beats may combine, so the calendar can be validated. A typical rule set (rule of thumb):

1. **At most one headline event live at a time.** Two headline events split attention and dilute both events' metrics.
2. **Multipliers may stack with a headline event only if stacking is designed**, with a cap on the combined multiplier ([[Economy Inflation Sinks and Faucets Math]]).
3. **No major publish during a headline event's first 48 hours.** Bugs found then are fixed by config or kill switch, not by a new build ([[Feature Flags and Staged Rollouts]]).
4. **A season end and a season start never share a day**: the docs recommend a rest week between seasons ([[Battle Pass and Season Design]]).
5. **Store offers tied to an event end when the event ends**, and never re-run under a different name ([[Limited-Time Offers - Design and Ethics]]).

## 4. Platform constraints that shape the calendar

From the Creator Hub (Roblox docs, as of October 2026; details in [[Live Ops Events and Updates]]):

- **Experience Events:** up to **10 ongoing or upcoming events** at once. A calendar that schedules every weekly rotation as a public event will hit this cap; reserve public events for beats worth an RSVP.
- **Off-platform featuring** needs submission **at least 7 days** before start, and the event must not be edited after submitting. Treat "submit for featuring" as its own calendar line one to two weeks before each headline event.
- **Trending Events sort** needs at least **1,000 RSVPs** and a start within the last 7 days. RSVPs come from "Notify Me" on upcoming events, so publish headline events early enough to collect them; a week ahead is a sensible minimum.
- **Update announcements:** 60 characters, at most one every three days. Two headline beats three days apart are fine; a daily drip is not possible through this channel.
- **Experience notifications** must be personalised to the player's own activity and are capped at one per user per day; they cannot be used to advertise an event generically.

These limits are another reason to keep the calendar as data: you can check "more than 10 public events scheduled" or "two announcements within 72 hours" automatically.

## 5. The calendar as data

The servers should read the same calendar the team plans with. Then "the event starts Friday 18:00 UTC" is one fact, not three (the spreadsheet, the code constant, the update note). Store it as a JSON value in experience configs, so it can be fixed without a publish and has history and restore ([[Global State and Live Config]], [[Live Content Pipeline]]).

A minimal schema:

```json
{
  "version": 7,
  "events": [
    { "id": "winter26", "kind": "headline", "startsAt": 1766167200, "endsAt": 1767376800, "multipliers": { "xp": 1.5 } },
    { "id": "wkd-2026-12-12", "kind": "multiplier", "startsAt": 1765562400, "endsAt": 1765735200, "multipliers": { "luck": 2 } }
  ]
}
```

Times are UTC seconds. Ids are permanent and never reused, because reward claims and analytics key on them.

### Resolving and validating in Luau

```lua
--!strict
-- ServerScriptService/Live/Calendar (ModuleScript)
-- Reads the calendar from configs, validates it, and answers "what is live now".
local ConfigService = game:GetService("ConfigService")
local HttpService = game:GetService("HttpService")

export type CalendarEvent = {
	id: string,
	kind: string, -- "headline" | "multiplier" | "rotation" | ...
	startsAt: number,
	endsAt: number,
	multipliers: { [string]: number }?,
}

local MAX_COMBINED = { xp = 3, luck = 3, coins = 3 } -- caps stacking, rule of thumb values

local Calendar = {}
local events: { CalendarEvent } = {}

-- Returns a list of problems; an empty list means the calendar is usable.
function Calendar.validate(list: { CalendarEvent }): { string }
	local problems = {}
	local seen: { [string]: boolean } = {}
	for _, e in list do
		if seen[e.id] then
			table.insert(problems, `duplicate id {e.id}`)
		end
		seen[e.id] = true
		if e.endsAt <= e.startsAt then
			table.insert(problems, `{e.id} ends before it starts`)
		end
	end
	-- At most one headline at a time: compare every pair (lists are small).
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.kind == "headline" and b.kind == "headline" and a.startsAt < b.endsAt and b.startsAt < a.endsAt then
				table.insert(problems, `headlines overlap: {a.id} and {b.id}`)
			end
		end
	end
	return problems
end

local function decode(raw: any): { CalendarEvent }?
	local value = raw
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then
			return nil
		end
		value = decoded
	end
	if type(value) ~= "table" or type(value.events) ~= "table" then
		return nil
	end
	local out: { CalendarEvent } = {}
	for _, e in value.events do
		if type(e) == "table" and type(e.id) == "string" and tonumber(e.startsAt) and tonumber(e.endsAt) then
			table.insert(out, {
				id = e.id,
				kind = if type(e.kind) == "string" then e.kind else "rotation",
				startsAt = tonumber(e.startsAt) :: number,
				endsAt = tonumber(e.endsAt) :: number,
				multipliers = if type(e.multipliers) == "table" then e.multipliers else nil,
			})
		end
	end
	return out
end

function Calendar.live(now: number?): { CalendarEvent }
	local t = now or os.time()
	local out = {}
	for _, e in events do
		if t >= e.startsAt and t < e.endsAt then
			table.insert(out, e)
		end
	end
	return out
end

-- Combined multiplier for a stat from every live event, capped.
function Calendar.multiplier(stat: string, now: number?): number
	local m = 1
	for _, e in Calendar.live(now) do
		local v = e.multipliers and e.multipliers[stat]
		if type(v) == "number" and v > 0 then
			m *= v
		end
	end
	local cap = (MAX_COMBINED :: any)[stat] :: number?
	return if cap then math.min(m, cap) else m
end

local function apply(raw: any)
	local list = decode(raw)
	if not list then
		warn("[Calendar] unreadable calendar; keeping previous")
		return
	end
	local problems = Calendar.validate(list)
	if #problems > 0 then
		-- Refuse a broken calendar rather than run a clash live.
		warn(`[Calendar] rejected: {table.concat(problems, "; ")}`)
		return
	end
	events = list
end

task.spawn(function()
	local ok, snap = pcall(function()
		return ConfigService:GetConfigAsync()
	end)
	if not ok then
		warn("[Calendar] configs unavailable; no events live")
		return
	end
	apply(snap:GetValue("calendar"))
	snap:GetValueChangedSignal("calendar"):Connect(function(value)
		apply(value)
	end)
	snap.UpdateAvailable:Connect(function()
		pcall(function()
			snap:Refresh()
		end)
	end)
end)

return Calendar
```

Design points:

- **A rejected calendar keeps the previous one.** A typo in the dashboard should never wipe every live event. Log the rejection loudly; [[Crash and Error Telemetry]] covers getting server warnings in front of you.
- **Run the same validator offline.** Copy the module into a small test (or run it from the Command Bar against the JSON) before staging. Validation that only runs live tells you about a problem after it shipped.
- **Whether a JSON config arrives as a table or a string** depends on the engine's decoding; the `decode` function accepts both. Confirm the behaviour in your own Studio session.
- **Multipliers combine multiplicatively and are capped.** Additive stacking is also defensible; what matters is that the rule exists in one function and the cap is explicit.
- **Countdowns on the client** read `startsAt` and `endsAt` sent by the server and compare against `workspace:GetServerTimeNow()`, never the device clock.

## 6. Planning the content of one event

A one-page event brief keeps the scope honest. Fields (rule of thumb):

| Field | Example |
|---|---|
| Goal | Lift weekend D7 return among players in zones 3 to 5 |
| Player promise | "Defeat the Frost Titan with your server for a winter aura" |
| Kind and dates | Headline, Fri 18:00 UTC to Sun+1 18:00 UTC (9 days) |
| New assets | Boss reskin, 1 aura, 3 icons, event banner, thumbnail variant |
| Reused systems | Boss framework, server goal bar, rewards module |
| Config keys | `calendar`, `winterBossHp`, `winterDropRate` |
| Kill switch | `winterEventEnabled` |
| Comms | Event page, 60-char update, in-game notes, featuring submission date |
| Success metric and guardrail | D7 return +X percent; refund rate and error rate unchanged |
| Owner | One named person, not "the team" |

The guardrail is the line most often skipped. An event that lifts play time while doubling errors or support tickets is not a success.

### Sizing by duration

Event length interacts with session frequency. A three-day event reaches mostly daily players; a nine-day event spanning two weekends reaches weekly players too. Rule of thumb: headline events of 7 to 14 days, multipliers of 2 to 3 days, seasons of about a month (the Roblox docs' starting point for season passes). Very long events lose urgency in the middle; give long events a mid-point beat (a second boss phase, a new reward unlocking on day 5) rather than more days.

### Reruns

Running last year's winter event again is cheap and often good, but decide in advance what returns. Returning event-exclusive rewards that were described as exclusive damages trust; returning the event mechanics with new rewards does not. Mark rewards in the brief as "exclusive, never returns" or "may return" from the start.

## 7. Time zones and start times

UTC is the source of truth in code. The start time is a product decision:

- Pick a start that lands in the **afternoon or early evening** for your largest region, so players can join the opening.
- Avoid starting during school hours for your main region on weekdays.
- If your audience is split across hemispheres or continents, a start that is evening in one is morning in another; prefer longer events over trying to serve each region with its own start.
- Daylight saving shifts local times twice a year. A calendar entered in local time and converted by hand will be off by an hour for some events; enter UTC.

Daily resets (missions, daily rewards) should all roll at the same UTC hour across systems. Mixing a 00:00 UTC daily reset with an event that ends at 18:00 UTC is fine; mixing two daily resets at different hours confuses everyone.

## 8. The review loop

After each headline event and each season, write a short review while the data is fresh:

1. **Did it ship on the planned date?** If not, what slipped, and was the buffer enough?
2. **Did it hit the goal metric and hold the guardrails?**
3. **What did it cost** in person-days, versus the estimate?
4. **What did players say** (community channels, dislikes, support)?
5. **One change** to the next plan.

Feed point 3 back into the throughput numbers in section 2. After two or three cycles, the estimates stop being guesses. Impressions from play sessions and community channels fade within days; a written review is what turns them into decisions the whole team can see later ([[Live Incident Response and Post-Mortems]] uses the same discipline for outages).

## 9. Common mistakes

| Mistake | What it looks like | Fix |
|---|---|---|
| Calendar drawn before measuring throughput | Events announced and quietly cancelled | Plan from the last six weeks' output |
| No slack | One bad week cascades into every later event | One buffer week per month |
| Multiplier every weekend | Weekday play drops; multipliers stop moving numbers | Space them; measure weekdays |
| Local times in the plan | Events start an hour off after a clock change | UTC everywhere |
| Event dates hard-coded in scripts | A slipped event needs a publish and a server restart | Calendar in configs, validated |
| Two headline events overlap | Split attention, muddy metrics | Overlap rules enforced by validation |
| No featuring line on the calendar | Submission missed the 7-day window | Featuring submission as its own dated task |
| Exclusive rewards rerun | Players who earned them feel cheated | Decide "exclusive" vs "may return" in the brief |

## 10. Checklist

- [ ] Roadmap, calendar and work plan are separate documents
- [ ] Throughput measured; maintenance share estimated
- [ ] Mostly config, rotation and reskin events; one mechanic or content event per month at most
- [ ] One buffer week per month
- [ ] Overlap rules written and enforced by a validator
- [ ] Calendar stored as validated JSON in configs, with code defaults
- [ ] All times UTC; daily resets aligned
- [ ] Featuring submissions and public events within platform limits
- [ ] One-page brief per headline event, with a guardrail metric and a kill switch
- [ ] Review written after every headline event and season

## See also
[[Live Ops Deep Dive Start Here]] · [[Live Ops Events and Updates]] · [[Update Cadence and Hype Cycles]] · [[Live Content Pipeline]] · [[Global State and Live Config]] · [[Battle Pass and Season Design]] · [[Feature Flags and Staged Rollouts]] · [[Patch Notes and Player Communication]] · [[Planning and Scoping a Roblox Game]] · [[Scoping and Roles for Small Teams]] · [[Analytics and Funnels]]

## Connected notes
<!-- auto-links:start -->
[[Roadmaps Milestones and Scope Control]] · Retention and Return Hooks · Experience Notifications and Return Prompts · Daily Rewards System End to End · Launch Strategy - The First Two Weeks · Retention Cohorts
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Experience Notifications and Return Prompts]] · [[Economy Resets and Seasonal Wipes]] · [[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Launch Strategy - The First Two Weeks]] · [[Retention Cohorts]] · [[Retention and Return Hooks]]
<!-- related:end -->
