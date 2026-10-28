---
tags: [live-ops, battle-pass, season-pass, seasons, progression, monetization, luau]
---
# Battle Pass and Season Design

A battle pass (Roblox's docs call it a **season pass**) is a time-limited progression track: players earn season XP from missions, climb tiers, and claim rewards before the season ends. A free track is open to everyone; a paid premium track adds more missions and better rewards. Done well it gives every session a goal, gives your content team a fixed rhythm, and earns money from engaged players rather than from pressure. Done badly it becomes a second job that players resent, a source of refund requests, and a data model you cannot change once money has gone through it.

[[Live Ops Events and Updates]] lists "battle pass season" as one row of a cadence table. This note is the deep version: the numbers that decide whether a season is completable, the free and premium split, mission design, the server model and its edge cases (purchases near the deadline, mid-season upgrades, seasons that slip), and when not to build one at all. Price ladders in general are in [[Robux Price Points and Offer Design]]; the ethics of time pressure are in [[Limited-Time Offers - Design and Ethics]].

Source labels: **Roblox docs (as of October 2026)** for anything from the Creator Hub, chiefly the "Season pass design" page; **rule of thumb** for practice; **measured in the reference project** where that applies.

## 1. What Roblox's own guidance says

The Creator Hub has a dedicated season pass design page (Roblox docs, as of October 2026). Its main recommendations:

- **Season length:** about one month is a good starting point, with **at least one week of rest** between seasons, both for players and for the team building the next one.
- **Tiers:** start with about **ten tiers**, so progress feels frequent and the season does not look daunting.
- **Enrolment:** every player is enrolled in the free pass automatically, and a prominent season UI shows progress, rewards and time left.
- **Missions:** new missions unlock daily and reset daily (unfinished progress is lost at day end), vary by category and difficulty, rarely repeat, are achievable in a day, and **never require spending hard currency**. At least three mission categories across the experience.
- **Free vs premium:** free players cannot complete premium missions or earn premium tier rewards. Premium offers extra missions (bonus daily missions visible to everyone but completable only by holders) and better rewards.
- **Mid-season upgrades:** a player who buys premium late receives premium rewards for every tier already reached, so waiting is not punished.
- **Claiming:** rewards are claimed with a button in the season UI, with a badge when something is waiting; **unclaimed rewards are granted automatically at season end**.
- **Final reward:** a new asset made for the season and retired afterwards, ideally shown as a 3D model in the world, not only in a menu.
- **Catch-up:** double XP in the final week is suggested, along with weekly high-reward missions.
- **Price:** no number is given; the price should honestly reflect the value of the rewards.

The general monetization page frames battle passes as purchases with long-term benefits that appeal to dedicated players, and warns that timers and appointment mechanics are unpopular with Roblox players when they cut fun short. That tension is the core design problem: a season is a timer by definition.

## 2. Is a season pass right for this game?

A season pass multiplies whatever retention you already have. It does not create retention from nothing. Rule of thumb, before building one:

| Condition | Why it matters |
|---|---|
| Players already return on several days a week | Daily missions only work for players who come back daily |
| You can ship new rewards every month without stalling updates | A pass with recycled rewards reads as a cash grab by season 3 |
| The core loop has at least three distinct activities | Missions need variety; "kill 50 enemies" every day is a chore |
| The economy can absorb a burst of currency and items per season | Pass rewards are a faucet; see [[Economy Inflation Sinks and Faucets Math]] |
| Sessions are long enough to finish a day's missions (15 minutes or more) | Otherwise every day ends with lost progress |

When not to build one:

- **Pre-launch or first month.** You do not know your retention curve yet, and the pass will be tuned to guesses. Ship daily rewards and quests first ([[Daily Rewards System End to End]], [[Quest Chain System End to End]]).
- **Very small player counts.** Under a few hundred daily players, the premium track earns little and the reward production cost is the same as for a big game.
- **Session games with no persistent identity** (some party and minigame collections) where players do not care about cosmetics. Use events instead.
- **A team that already misses its update dates.** A season is a public promise with a fixed end. Missing a season start is worse than missing an ordinary update ([[Update Cadence and Hype Cycles]]).

## 3. The arithmetic of a completable season

The most common failure is a season that only no-lifers can finish. Players who realise on day 20 that they cannot reach the final tier stop playing the pass entirely, and premium buyers who cannot finish feel cheated. Design backwards from a target player.

### Pick the target player

Define the player the season is tuned for, for example: plays 5 days a week, 25 minutes per session, does daily missions but not every weekly. Everything else follows from their XP per day.

### XP budget

Let:

- `D` = season length in days (30 by the docs' default)
- `p` = fraction of days the target player plays (5/7 is about 0.71)
- `m` = average XP per play day from missions and passive play
- `T` = total XP needed for the last tier

Then the target player's expected season XP is `D * p * m`. To have them finish with slack, set `T` to about **80 to 85 percent** of that (rule of thumb). The slack covers sick days, holidays and an off week.

Worked example (rule of thumb numbers):

- 30 days, `p` = 0.71, so about 21 play days.
- Free track: three daily missions (easy 100, medium 150, hard 250 XP) = 500 XP per play day, plus about 100 XP passive from playing. `m` = 600.
- Expected free XP: 21 x 600 = 12,600.
- Free track total `T` = 0.82 x 12,600, about 10,300. With ten tiers that is roughly 1,000 XP per tier, about 1.7 play days per tier.
- Premium adds two bonus daily missions (150 + 200). Premium `m` = 950, expected 19,950 XP. If premium shares the same tier ladder, the premium player finishes around day 17 to 18 of play, about 25 calendar days.

That last line exposes a real choice. If premium players earn XP faster on the **same** ladder, premium is partly a speed-up, which feels like paying to progress. Two cleaner structures:

| Structure | How it works | Trade-off |
|---|---|---|
| Shared ladder, premium extra missions | One XP bar; premium earns more per day | Simple; premium finishes early and runs out of goals in the last week |
| Shared ladder, premium extra tiers | Free has tiers 1 to 10, premium has 1 to 10 plus bonus tiers 11 to 15 | Premium players keep a goal to the end; more reward assets to make |
| Separate ladders | Free and premium XP tracked separately | Hardest to explain in one UI; avoid on Roblox's young audience |

Most small teams should pick the second: one bar, premium missions, and a few premium-only bonus tiers that soak up the extra XP so neither group is idle in week four.

### Curve shape

Flat tier costs (every tier 1,000 XP) are easy to read and fine for ten tiers. With 30 or more tiers, a gentle ramp (early tiers cheaper so the first session claims something) helps onboarding: for example tiers 1 to 3 at 50 percent cost, the rest flat. Avoid steep late tiers; the end of the season is when time is shortest, which is why the docs suggest a final-week catch-up instead.

### Catch-up and late joiners

A player who starts on day 20 cannot finish a 30-day season tuned to 82 percent of a full month. Options, cheapest first:

1. **Final-week double XP** (the docs' suggestion). Visible, fair, cheap.
2. **Banked missions:** missed daily missions stay available for a few days. Contradicts the docs' "reset daily" advice but helps players with irregular schedules; cap the bank (for example 3 days) so it does not become a backlog chore.
3. **Weekly missions** that reward large XP for a week's play, completable in any two or three sessions.
4. **Tier skips for Robux.** Common elsewhere and allowed on Roblox, but they turn the pass into a "pay because the deadline is close" product. If you sell them, price them modestly, cap them, and never pair them with a countdown that pressures the purchase ([[Limited-Time Offers - Design and Ethics]]). Many teams are better off without them.

## 4. Rewards: what goes where

The docs' rule is that tier rewards should be wanted but not too valuable (consumables, small currency, temporary buffs, small cosmetics) and the final reward is the exclusive capstone. In practice:

| Slot | Good contents | Avoid |
|---|---|---|
| Early free tiers | A currency bundle, a potion, a small cosmetic: proves the pass works on day one | Nothing on tier 1; players need an instant claim |
| Mid free tiers | Cosmetics, boosts, a mid-value item | Power items that make free players weaker than a non-pass player last season |
| Premium tiers | Cosmetics with visible flair (trails, auras, titles), premium currency that partially refunds the pass | Exclusive stat power; it becomes pay to win the moment PvP exists |
| Final premium reward | A unique cosmetic shown in the world, retired after the season | Something you will need to re-release later |
| Final free reward | A smaller unique item so free players also "finish" | Nothing; a free track with no capstone feels like an ad |

**Premium currency payback.** A common pattern is premium tiers returning part of the pass price in premium currency, so a player who finishes can afford the next pass. It rewards completion and feels generous. Do the math: if the pass costs 400 Robux and premium currency is sold at 100 per 100 Robux, returning 300 premium currency means the effective price for a finisher is 100 Robux plus their time. That is fine if intended; it is a disaster if your premium currency is also the main sink in the economy.

**Retired rewards are a promise.** The docs suggest retiring the final reward to keep it exclusive. Once a player has paid for an item described as season-exclusive, re-releasing it later breaks trust and may be reported as misleading. If you might ever sell it again, do not call it exclusive; call it "season 3 reward" and leave the future open.

**Paid random items in the pass.** If any premium tier grants a crate, egg or roll, that is a paid random item: odds disclosure and the `PolicyService` restriction apply to the premium pass as a whole ([[Paid Random Items and Odds Disclosure in Practice]]). Simplest rule: premium tiers grant fixed items only.

## 5. Selling premium: game pass or developer product?

Roblox game passes are one-time permanent ownership; developer products can be bought many times and are fulfilled through `ProcessReceipt` ([[Game Passes]], [[Developer Products and ProcessReceipt]]). For a pass that changes every season:

| Option | Pros | Cons |
|---|---|---|
| New game pass per season | Ownership is checked by Roblox; shows on the game page store | A new pass asset each season; old passes linger on the store page unless taken off sale; you must still map pass id to season |
| One developer product, recorded per season in the profile | One product id forever; the receipt handler writes `premium[seasonId] = true` | You own the record entirely; must be durable and idempotent |

Rule of thumb: use a **developer product**, recorded against the season id inside the player profile with the receipt id, because the season id is what all the logic keys on anyway, and a product can be priced per season through managed pricing. Whichever you pick, the receipt handler must decide **which season** a purchase belongs to, and that is where the edge cases live.

### Purchases near the boundary

A player opens the purchase prompt at 23:59:50 UTC on the last day and confirms at 00:00:05. The receipt arrives after the season ended. Possible rules:

- **Grant to the season that was live when the prompt opened.** Requires the client to send its season id with the prompt request and the server to remember a short-lived "prompted for season X" record. Fair, slightly complex.
- **Grant to the season live at receipt time, and if none, refuse to show the prompt in the last N minutes.** Simple. Close the shop button 10 minutes before the end and show "Season ends soon" instead of a buy button.
- **Grant to the ended season and immediately auto-claim everything.** The player gets all premium rewards for tiers they reached. Honest, and matches the docs' "unclaimed rewards granted at season end" rule.

Never return `NotProcessedYet` forever because a season ended: the player was charged, Roblox will keep retrying, and support gets the ticket ([[Refunds Chargebacks and Purchase Support]]). Every receipt must resolve to a grant.

## 6. The server model

Key the entire pass on a season id. Store per-season state in the profile; never reuse field names across seasons.

```lua
--!strict
-- ReplicatedStorage/Shared/SeasonTypes (ModuleScript)
export type Tier = {
	xp: number, -- cumulative XP needed to reach this tier
	free: string?, -- reward id, nil if none
	premium: string?,
}

export type SeasonDef = {
	id: string, -- "S3"; never reuse
	startsAt: number, -- UTC seconds
	endsAt: number,
	tiers: { Tier },
	catchUpFrom: number?, -- UTC seconds when double XP starts
}

export type SeasonState = {
	xp: number,
	premium: boolean,
	premiumReceipt: string?,
	claimedFree: { [string]: boolean }, -- keyed by tostring(tierIndex)
	claimedPremium: { [string]: boolean },
	finalized: boolean, -- end-of-season auto grant done
}

return {} -- a ModuleScript must return one non-nil value; this one only exports types
```

String keys for claimed tiers avoid the sparse-array trap: a table like `{[1]=true,[5]=true}` can change shape when serialised, which one production game hit in its saves ([[Data Schema Design and Migrations]]).

```lua
--!strict
-- ServerScriptService/Season/SeasonService (ModuleScript)
-- Assumes a profile layer that gives exclusive, session-locked access to profile.Data
-- and a Rewards module that applies reward ids. See Session Locking and Profile Libraries.
local SeasonTypes = require(game.ReplicatedStorage.Shared.SeasonTypes)
type SeasonDef = SeasonTypes.SeasonDef
type SeasonState = SeasonTypes.SeasonState

local Rewards = require(script.Parent.Rewards)

local SeasonService = {}

local function newState(): SeasonState
	return { xp = 0, premium = false, claimedFree = {}, claimedPremium = {}, finalized = false }
end

function SeasonService.state(data: any, seasonId: string): SeasonState
	data.Seasons = data.Seasons or {}
	local s = data.Seasons[seasonId]
	if not s then
		s = newState()
		data.Seasons[seasonId] = s
	end
	return s
end

function SeasonService.tierFor(def: SeasonDef, xp: number): number
	local reached = 0
	for i, tier in def.tiers do
		if xp >= tier.xp then
			reached = i
		else
			break
		end
	end
	return reached
end

-- All XP enters here, so the multiplier and the deadline live in one place.
function SeasonService.addXp(data: any, def: SeasonDef, amount: number, now: number)
	if now < def.startsAt or now >= def.endsAt or amount <= 0 then
		return
	end
	local mult = if def.catchUpFrom and now >= def.catchUpFrom then 2 else 1
	local s = SeasonService.state(data, def.id)
	s.xp += math.floor(amount * mult)
end

-- Claim one tier on one track. Mark first, then grant, with no yield in between.
function SeasonService.claim(data: any, def: SeasonDef, tierIndex: number, premiumTrack: boolean): boolean
	local s = SeasonService.state(data, def.id)
	local tier = def.tiers[tierIndex]
	if not tier or SeasonService.tierFor(def, s.xp) < tierIndex then
		return false
	end
	local key = tostring(tierIndex)
	if premiumTrack then
		if not s.premium or not tier.premium or s.claimedPremium[key] then
			return false
		end
		s.claimedPremium[key] = true
		Rewards.apply(data, tier.premium)
	else
		if not tier.free or s.claimedFree[key] then
			return false
		end
		s.claimedFree[key] = true
		Rewards.apply(data, tier.free)
	end
	return true
end

-- Called from ProcessReceipt after the season for this purchase is decided.
-- Idempotent on the receipt id. Retroactive: earlier tiers simply become claimable.
function SeasonService.grantPremium(data: any, def: SeasonDef, receiptId: string, now: number)
	local s = SeasonService.state(data, def.id)
	if s.premiumReceipt == receiptId then
		return
	end
	s.premium = true
	s.premiumReceipt = receiptId
	if now >= def.endsAt then
		SeasonService.finalize(data, def) -- bought at the boundary: pay out at once
	end
end

-- Grant everything reached but unclaimed. Run on the first load after the season ends.
function SeasonService.finalize(data: any, def: SeasonDef)
	local s = SeasonService.state(data, def.id)
	local reached = SeasonService.tierFor(def, s.xp)
	for i = 1, reached do
		SeasonService.claim(data, def, i, false)
		if s.premium then
			SeasonService.claim(data, def, i, true)
		end
	end
	s.finalized = true
end

return SeasonService
```

Notes on the model:

- **Finalisation is lazy.** Most players are offline when a season ends; you cannot grant to them then. On profile load, loop over past seasons in the profile whose `finalized` is false and whose end has passed, and finalise them. This is the same lazy pattern as seasonal resets ([[Economy Resets and Seasonal Wipes]]). Note that `finalize` calls `claim` again even when `grantPremium` already ran it; that is safe because claims are idempotent.
- **Season definitions live in config, not code**, so a slipped date or a typo in a tier cost can be fixed without a publish ([[Global State and Live Config]]). But **never change tier costs downward or upward after a season starts** without thinking it through: lowering is fine (players reach more), raising takes tiers away from players who reached them, which they will notice.
- **Mission progress is a separate system** that calls `addXp`. Keep daily mission state keyed by UTC day number so every server agrees when the day rolls (see the schedule module in [[Live Ops Events and Updates]]).
- **Replicate a compact view** (season id, xp, tier, premium, claimable count) to the client through attributes or a remote; the client renders, the server decides.
- **Prune** old season states after a few seasons, keeping a one-line summary (`{ tier = 8, premium = true }`) for "veteran" badges and support lookups.

## 7. Operating a season

A season has more moving parts than an event: assets, missions, a pass UI theme, a final reward, a store entry, marketing. A planning template (rule of thumb):

| Week before start | Work |
|---|---|
| -6 | Theme and final reward concept locked; XP budget sheet updated from last season's data |
| -4 | Reward assets in production; mission list drafted; tier sheet reviewed |
| -2 | Season config staged; QA on a test place with `SetTestingValue` and faked clocks |
| -1 | Experience Event created and submitted for featuring (7+ days ahead per Roblox docs); notes drafted |
| 0 | Season live at a fixed UTC time; watch claims, receipts, errors |
| +3 | Mid-season check: completion forecast vs target |
| last week | Catch-up XP live; next season teaser in the rest week |

Metrics that tell you whether the season worked:

- **Completion rate by track**, measured against the target player. If fewer than about half of target-profile players finish the free track, the season was too long or too grindy (rule of thumb).
- **Premium conversion** among players who reached tier 2 or 3 (they understand the pass).
- **Day-of-season curve** of active pass players: a cliff around day 10 to 15 means players gave up.
- **Refund and support tickets** mentioning the pass.
- **Retention of non-pass players**, to check the pass did not make the rest of the game feel like a lobby for missions.

Use [[Analytics and Funnels]] custom events for tier reached and claim, and [[A-B Testing and Experiments on Roblox]] only for reversible things (mission XP values), never for the price of a pass already on sale.

## 8. Edge cases and failure modes

| Symptom | Cause | Fix |
|---|---|---|
| "I bought premium and got nothing" at season end | Receipt arrived after `endsAt` and was refused or parked | Every receipt resolves; boundary rule decided in advance |
| Rewards for tiers 1 to 7 missing after a mid-season upgrade | Premium only enabled future claims | Retroactive by design: claimability depends on reached tier, not on purchase time |
| XP counted twice for one mission | Mission completion granted on two servers or replayed after a teleport | Mission completion keyed by `dayNumber:missionId` in the profile, checked before granting |
| Season ended on some servers early | `endsAt` read from a cached copy with a different value, or a server using local time | One config value in UTC; refresh at boundaries |
| Players feel forced to log in daily | Daily missions only, no banking, no weeklies | Weeklies plus a small bank; catch-up week |
| Season 4 rewards look like season 1 recolours | Production could not keep up | Longer seasons, or skip the pass and run events |
| Free players "cannot keep up" in PvP | Pass rewards with stat power | Cosmetic premium track |

## 9. Checklist

- [ ] Retention and content capacity justify a pass (section 2)
- [ ] Target player defined; XP budget sheet with 15 to 20 percent slack
- [ ] Free track has an instant tier 1 claim and its own capstone
- [ ] Premium is mostly cosmetic; no exclusive stat power
- [ ] No paid random items in premium, or full odds disclosure and `PolicyService` gating
- [ ] Season id keys every field; season definitions in config
- [ ] Claims idempotent; premium idempotent on receipt id; retroactive upgrades
- [ ] Boundary purchase rule decided; every receipt resolves to a grant
- [ ] Lazy finalisation of ended seasons on load
- [ ] Catch-up in the final week; rest week between seasons
- [ ] Final reward truly retired, or not called exclusive
- [ ] Completion, conversion and refund metrics on a dashboard

## See also
[[Live Ops Deep Dive Start Here]] · [[Live Ops Events and Updates]] · [[Event Calendars and Content Planning]] · [[Limited-Time Offers - Design and Ethics]] · [[Economy Resets and Seasonal Wipes]] · [[Robux Price Points and Offer Design]] · [[Developer Products and ProcessReceipt]] · [[Quest Chain System End to End]] · [[Progression and Pacing Design]] · [[Retention and Return Hooks]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Monetization Overview]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Subscriptions and Recurring Revenue]] · [[Shop with Game Passes and Developer Products End to End]] · [[Skill - Roblox Monetization Compliance]] · [[Idempotency]]
<!-- auto-links:end -->
