---
tags: [game-design, retention, daily-rewards, streaks, quests, live-ops]
---
# Retention and Return Hooks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting the client clock -> Server `os.time()` only
> - Avoid: Paying before marking the claim -> Mark, save, then pay
> - Avoid: Fixed rewards that ignore progress -> Scale soft rewards to the player's stage
> - At least one "ready" thing on every join, never more than one automatic pop-up at a time.
> - Daily reward: server-timed, mark-then-pay, saved at once, throttled, grace considered.
> - Timers capped per day; AFK policy decided.
>
> Cost: TL;DR ~150 tok · whole note ~5.0k tok. Read more: ## 3. Daily rewards and streaks · ## 4. Free gifts and playtime timers · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

Retention is the share of players who come back. A **return hook** is a designed reason to come back at a particular time: a daily reward, a gift timer, a quest reset, a vault that fills while you are away, an event that starts at 6 pm. Hooks multiply a good loop; they cannot rescue a bad one. This note covers how Roblox measures retention, the main hook families with production numbers, how to implement daily rewards and timers correctly (time zones, streaks, exploits), and where hooks turn into chores or pressure.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. How retention is measured

Roblox's analytics define three standard windows (Docs, "Retention"):

| Metric | Definition (Docs) | Docs' main lever |
|---|---|---|
| D1 | Share of new users who return the day after their first visit | Core loop clarity, FTUE, performance |
| D7 | Share who return on the 8th day ("Day 7") | Progression system: short and long goals, variety, balanced difficulty |
| D30 | Share who return on the 31st day ("Day 30") | Content cadence and social mechanics |

Cohorts are grouped by first-play date. Recent cohorts are incomplete (D7 for a date appears a week later), and the docs note that a dip in all retention charts after a big influx of new players is "typical and temporary". The docs give **no benchmark values**; numbers that circulate in the community vary by genre and audience and are not official.

Discovery uses a related signal, **play days per user** averaged over Day 1, Days 2 to 7 and Days 8 to 28, as one of its most important ranking inputs (Docs, "Discovery"). So a player who returns on many days helps the game's visibility as well as its revenue.

For content cadence the docs suggest **smaller updates every 2 to 4 weeks and larger feature updates every 2 to 3 months** (Docs, "Retention"). See [[Live Ops Events and Updates]].

### Which hook for which window

| Window | Strongest hooks |
|---|---|
| D1 | A great first session, an unfinished goal, a timer that resolves tomorrow, "come back for Day 2 of the calendar" |
| D7 | Weekly quests, progression walls with visible next steps, collections, daily calendar day 7 |
| D30 | Updates, live events, social ties (friends, guilds, trading), leaderboards, seasons |

---

## 2. The hook families

| Family | Examples | Pulls players back by | Cost to build | Main risk |
|---|---|---|---|---|
| Calendar | Daily login reward, 7-day calendar | "Today's reward is waiting" | Low | Feels like a chore; streak loss anger |
| Timer | Free gifts by playtime, spin wheel cooldown | "Something is ready" | Low | Pushes AFK; timer fatigue |
| Goal | Daily/weekly quests, next-goal chain, achievements | "I am almost there" | Medium | Chore quests that do not teach the loop |
| Accumulation | Offline earnings, brewing, crop growth | "My stuff piled up" | Medium | Inflation if too generous |
| Social | Friends online, group perks, trading, events | "My friends are here" | Medium to high | Needs critical mass |
| Content | Updates, limited events, seasons | "Something new" | High (ongoing) | Team burnout |
| Collection | Index, set bonuses, rarity ladders | "One more to complete the set" | Medium | Endless grind if sets are too big |

Good games combine 3 or 4 families so that a player always has **at least one ready thing** on joining. Too many and the join screen becomes a stack of claim buttons (see the pop-up gate rule in [[Core Loops and Session Design]]).

---

## 3. Daily rewards and streaks

### Calendar shapes

| Shape | How it works | Pros | Cons |
|---|---|---|---|
| Strict streak | Day N reward only if you claimed on day N-1; a miss resets to day 1 | Strong daily pull | Harsh; one missed day erases a week; angry players |
| Streak with grace | A miss within a grace window keeps the streak (or one free "freeze" per week) | Most of the pull, much less anger | Slightly more code |
| Cumulative ("login count") | Each claim advances the calendar; no reset on misses | Kind; never punishes | Weaker daily pull |
| Cycle | 7-day cycle that repeats, day 7 the big one | Predictable | Players learn to only care about day 7 |
| Ladder plus cycle | 28-day ladder with a weekly highlight | Long-term goal and weekly beat | Bigger reward table to balance |

The reference project's daily chest: **once per UTC day, 7-day streak, a missed day resets the streak**, claimed at a chest model in the hub, saved immediately on claim. That is the classic strict streak. It works, but it is the shape most likely to feel punishing to a child who missed a day for reasons outside their control. A grace day costs almost nothing and removes most of the sting. See [[Ethical Design and Player Trust]].

### Day boundaries and time zones
"Once per day" has three possible meanings:

| Boundary | Behaviour | Problem |
|---|---|---|
| Fixed UTC midnight | Everyone resets at the same moment | For players in the Americas the reset falls in the afternoon or evening; a player can claim at 23:50 UTC and again at 00:10 UTC |
| Rolling 24 h from last claim | Claim time drifts later every day | Players who claim at 9 pm one day cannot claim at 8 pm the next |
| Rolling window with slack (e.g. 20 h minimum, 48 h maximum for streak) | Claim any time after 20 h; streak survives up to 48 h | Slightly harder to explain |

UTC calendar days are the simplest to implement and to show ("Resets in 4h 12m"), and they are what the reference project used. The 20 h / 48 h window is kinder to players who play at different times each day. Either is fine; **never trust the client's clock**, compute everything from `os.time()` on the server.

### Implementation: a UTC-day streak with one grace day

```lua
--!strict
-- ServerScriptService/DailyReward (ModuleScript)
-- Profile fields: lastClaimDay (UTC day number), streak (1..7), graceUsedDay (UTC day number or nil)

local DAY = 86400
local CYCLE = 7

export type DailyData = { lastClaimDay: number?, streak: number, graceUsedDay: number? }

local DailyReward = {}

local function utcDay(t: number?): number
	return (t or os.time()) // DAY -- integer UTC day number
end

-- Returns whether the player may claim now, and which calendar day they would get.
function DailyReward.preview(d: DailyData): (boolean, number)
	local today = utcDay()
	local last = d.lastClaimDay
	if last == nil then
		return true, 1
	end
	if last == today then
		return false, d.streak -- already claimed today
	end
	local gap = today - last
	local nextDay: number
	if gap == 1 then
		nextDay = d.streak % CYCLE + 1
	elseif gap == 2 and (d.graceUsedDay == nil or today - d.graceUsedDay >= CYCLE) then
		nextDay = d.streak % CYCLE + 1 -- missed one day: grace keeps the streak (once per week)
	else
		nextDay = 1
	end
	return true, nextDay
end

-- Call only from the server's claim handler, then save at once.
function DailyReward.claim(d: DailyData): number?
	local ok, day = DailyReward.preview(d)
	if not ok then
		return nil
	end
	local today = utcDay()
	if d.lastClaimDay and today - d.lastClaimDay == 2 and day ~= 1 then
		d.graceUsedDay = today
	end
	d.lastClaimDay = today
	d.streak = day
	return day -- caller grants REWARDS[day]
end

function DailyReward.secondsToReset(): number
	return DAY - os.time() % DAY
end

return DailyReward
```

Rules that matter more than the code:
- **Mark the claim before paying** and save at once. The reference project's hub activities did exactly that ("claim marked before paying"), so a crash or a double-click cannot pay twice.
- **Throttle the remote.** A claim remote spammed 50 times in one frame must pay once. See [[Rate Limiting and Abuse Prevention]].
- **Session locking** must be in place or two servers can each pay the claim. See [[Session Locking and Profile Libraries]].
- Show the reward list for the whole week up front. A hidden day 7 is a weaker pull than a visible one.

### What to put in the calendar
- Day 1 to 6: soft currency scaled to the player's progress (a share of the next gate price keeps it relevant at every stage; the reference project priced hub rewards and quest cash this way).
- Day 7: something with a different texture: a guaranteed higher-rarity roll ("Epic or better"), a gem bundle, a cosmetic.
- Name the reward in plain words. The reference project changed "x4" to "4 TEMPERED IRON" and gave headline rolls a sub line ("Epic or better") after testers could not tell what they were getting.

---

## 4. Free gifts and playtime timers

A **playtime gift** unlocks after N minutes of play in the current session or day. It is a session-length hook rather than a return hook, but it also creates an exit hook ("next gift in 4 minutes").

The reference project's "Free Gifts" screen (as of its last notes):

| Gift | Interval | Per day |
|---|---|---|
| Small | every 5 min of play | 9 |
| Medium | every 15 min of play | 4 |
| Large | every 60 min of play | 1 |

- Counted by **play time**, not wall-clock time.
- **Banks one interval**: if you are away from the screen when a gift becomes ready, the next interval does not start counting until you claim, but you never lose more than one interval.
- Daily caps reset at UTC midnight.
- Rewards come from **pools with odds shown on screen, and the odds rolled are the odds shown**.

Design notes:
- The daily caps (9, 4, 1) stop the gift screen from becoming an AFK income engine. Without caps, an idle player collects gifts all night.
- The caps also line up with the discovery cap: playtime per user only counts up to 60 minutes a day (Docs, "Discovery"), and the largest gift arrives at exactly one hour.
- Free gifts are not bought with Robux, so Roblox's paid-random-item disclosure rules do not apply to them (Docs, "Paid random items": rewards from actions that do not involve Robux or Robux-bought currency do not need disclosure). Showing odds anyway is good practice and costs nothing.
- If you ever sell a "skip timer" or "extra gift" for Robux, the gift becomes a paid random item and **must** disclose odds as percentages. See [[Genre Playbook - RNG and Collection Games]].

### Implementation sketch: playtime gifts

```lua
--!strict
-- Server: per-player playtime gift timers. Tick from one Heartbeat loop or a 1 s task loop.
type Gift = { interval: number, perDay: number }
local GIFTS: { [string]: Gift } = {
	Small  = { interval = 5 * 60,  perDay = 9 },
	Medium = { interval = 15 * 60, perDay = 4 },
	Large  = { interval = 60 * 60, perDay = 1 },
}

export type GiftState = { day: number, played: { [string]: number }, claimed: { [string]: number } }

local function today(): number
	return os.time() // 86400
end

local function resetIfNewDay(s: GiftState)
	if s.day ~= today() then
		s.day = today()
		s.played = {}
		s.claimed = {}
	end
end

-- Call every second while the player is in game (and, if you want, only when not AFK).
local function tick(s: GiftState, dt: number)
	resetIfNewDay(s)
	for name, g in GIFTS do
		local claimed = s.claimed[name] or 0
		if claimed < g.perDay then
			-- Banks at most one interval: the timer stops when a gift is ready.
			s.played[name] = math.min((s.played[name] or 0) + dt, g.interval)
		end
	end
end

local function tryClaim(s: GiftState, name: string): boolean
	resetIfNewDay(s)
	local g = GIFTS[name]
	if not g then return false end
	if (s.claimed[name] or 0) >= g.perDay then return false end
	if (s.played[name] or 0) < g.interval then return false end
	s.claimed[name] = (s.claimed[name] or 0) + 1
	s.played[name] = 0
	return true -- caller rolls the pool on the server and pays
end
```

Whether to count AFK time is a design decision. Counting it helps accessibility and calm play; not counting it (pause the timer when there has been no input for a few minutes, reported by the client and sanity-checked) keeps the gifts tied to active play. Either way, the caps matter more.

---

## 5. Spin wheels and lucky draws

The reference project's hub has a **Lucky Spin** with a 1-hour cooldown and 8 weighted slices. Wheels are cheap, readable on phones, and give the session a small gamble without spending.

- Show every slice's chance on the wheel's info panel.
- Weight the wheel honestly: the slice the pointer lands on must be the slice that was rolled on the server, and the animation is just a replay of that result.
- A wheel whose extra spins are sold for Robux, or for a currency that Robux can buy, is a **paid random item** and must show all outcomes with percentage odds that sum to 100% before purchase (Docs, "Paid random items"). Some players cannot use paid random items at all (`PolicyService` field `ArePaidRandomItemsRestricted`); see [[Ethical Design and Player Trust]].

---

## 6. Quests as return hooks

Daily and weekly quests are the most flexible hook because they can **point the player at any part of the loop**. The docs' quest design page describes dailies as short tasks with modest rewards that refresh every 24 hours and work well as a steady source of soft currency, and recommends dailies be "exclusively short-term" while achievements are long-term (Docs, "Quest design").

The reference project's quest system, after two rewrites:
- **Pool**: 55 daily and 33 weekly quest templates across 30 objective kinds in 8 families (kills, elite kills, boss kills, rolls, rare rolls, dashes, cash earned, salvage, forging, brewing, and so on).
- **Per period**: 3 cards, one Easy, one Medium, one Hard. No two cards share a kind or a family, and only quests the player is **eligible** for are dealt (no boss quest before the boss zone).
- **Rewards are fixed when dealt**: cash as a share of the **next** gate's price (so the reward stays meaningful at every stage), materials of the player's zone tier.
- **Quest points** (Easy 1, Hard 2, Weekly 4) fill a weekly 5-chest track at 4, 10, 18, 28 and 38 points.
- **Rerolls**: one free reroll per day or week, then 15 or 40 gems.
- **Retired chore quests**: "log in", "play 20/45/90 minutes", "claim a gift", "spin the wheel" were all removed in favour of gameplay quests. Login and playtime quests reward being present, not playing, and they double-count other hooks.

That last decision is worth copying. A quest should ask for a verb of the loop. Details of quest systems are in [[Quests and Objectives]].

---

## 7. Accumulation: offline earnings

Offline earnings ("your vault filled while you were away") turn absence into a reward and create a strong reason to rejoin.

The reference project's offline vault (as of its last notes):

| Setting | Value |
|---|---|
| Rate | 15% of active cash per minute at the player's furthest zone |
| Cap | 8 hours (12 with the VIP pass) |
| Rolls | one banked roll per 20 minutes away |
| Minimum absence | 5 minutes (shorter gaps pay nothing) |
| Before tutorial | nothing fills until onboarding is complete |
| Unclaimed | carries over, but never past one full vault |
| Claim x2 | optional Robux product doubles the vault (button hidden if the product id is not set) |

Design notes:
- **Server-side timing.** Store `lastSeen` in the profile on every save and compute the absence on load. A client-reported absence is an exploit.
- **Cap it.** Without a cap, a player away for a month returns to a sum that breaks the economy.
- **Rate as a fraction of active income.** The vault should never beat playing.
- **Show it as a moment.** The reference project's "Welcome Back" card counts the cash up, deals banked weapon cards in one by one, and has a "Keep it for later" option. The claim is a peak in the session arc.
- A paid doubler is fine if the base claim is generous and the doubler is optional; see [[Ethical Design and Player Trust]] for where this tips over.

---

## 8. Social and live hooks

- **Friends.** The discovery signal "intentional co-play days" rewards games people play together (Docs). Friend boosts (the reference project gives a luck bonus per friend in the server) turn "my friend is online" into a reason to join. See [[Social Design and Multiplayer Play]].
- **Scheduled server events.** The reference project runs a periodic boss event: a rift opens in the hub for a 45 s join window, a board counts down to the next one, and everyone online can join. Countdowns create appointment play inside a session.
- **Group membership perks.** A small bonus for joining the game's community group converts players into a reachable audience for updates. See [[Community Building]].
- **Leaderboards** (rebirths, time played, Robux spent in the reference project) give long-term players a status goal. Consider carefully whether a "Robux spent" board is a good idea; see [[Ethical Design and Player Trust]].
- **Updates and events** are the D30 hook. See [[Live Ops Events and Updates]].
- **Experience notifications.** Roblox offers opt-in notifications that experiences can send to players (through Open Cloud). Check the current docs for eligibility, limits and wording rules before designing around them; see [[Open Cloud APIs]].

---

## 9. When hooks become chores

Signs your hooks are hurting:
- Players join, claim three things, and leave (high play days, low playtime and low progression).
- Reviews and comments mention "grind", "homework", "lost my streak".
- The first minute of every session is closing pop-ups.
- Quest completion is high but the core loop's numbers (kills, rolls, gates) do not move.

Fixes:
- Merge claim screens (one rewards hub with tabs, not five pop-ups).
- Replace presence quests with verb quests.
- Add grace to streaks.
- Make hooks feed the loop (rewards that raise power or open content, not just a bigger number).

---

## 10. Common mistakes

| Mistake | Consequence | Better |
|---|---|---|
| Trusting the client clock | Timer and daily exploits | Server `os.time()` only |
| Paying before marking the claim | Double payouts on lag or spam | Mark, save, then pay |
| Fixed rewards that ignore progress | Day 3 reward is meaningless by zone 10 | Scale soft rewards to the player's stage |
| Strict streaks with no grace | Anger, quitting after one missed day | Grace day or streak freeze |
| Unlimited AFK timers | Idle farms, inflation | Daily caps; AFK pays less than play |
| Login and playtime quests | Chores that do not teach the loop | Quests for loop verbs |
| Selling timer skips without odds | Policy breach if the reward is random | Percent odds before purchase |
| Every hook as its own pop-up | First minute wasted | One rewards hub, one pop-up gate |

---

## 11. Checklist

- [ ] At least one "ready" thing on every join, never more than one automatic pop-up at a time.
- [ ] Daily reward: server-timed, mark-then-pay, saved at once, throttled, grace considered.
- [ ] Timers capped per day; AFK policy decided.
- [ ] Quests ask for loop verbs, scale rewards to progress, never deal ineligible tasks.
- [ ] Offline earnings capped, a fraction of active income, only after onboarding.
- [ ] Any paid path to a random reward shows percentage odds before purchase.
- [ ] D1, D7, D30 tracked per cohort; play days per user watched.
- [ ] Content cadence planned (small updates every few weeks).

## See also
- [[Core Loops and Session Design]], [[First-Time User Experience and Onboarding]], [[Progression and Pacing Design]]
- [[Quests and Objectives]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[Economies and Currencies]]
- [[Live Ops Events and Updates]], [[Analytics and Funnels]], [[Discovery and the Algorithm]], [[Community Building]]
- [[Ethical Design and Player Trust]], [[Session Locking and Profile Libraries]], [[Rate Limiting and Abuse Prevention]]

## Connected notes
<!-- auto-links:start -->
[[Daily Rewards System End to End]] · [[Retention Cohorts]] · [[Battle Pass and Season Design]] · [[Genre Playbook - Simulators]] · [[Quest Writing and Hooks]] · [[Session Length]]
<!-- auto-links:end -->
