---
tags: [live-ops, economy, seasons, wipes, datastore, leaderboards, trust, luau]
---
# Economy Resets and Seasonal Wipes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Some players rolled over twice, lost new-season progress: Rollover keyed on a timestamp or flag that was reset, not season id -> Idempotent on season id
> - Players wiped a day early: Season config mistyped; no "never roll early" guard -> Guard on `startsAt`; validate configs
> - Old-season servers keep granting old-season currency after the...: Cached season id; outdated build -> Refresh at boundary; restart servers
> - Reset type chosen from the least damaging that solves the problem
> - Problem measured, not felt
> - Profile split into permanent and seasonal parts
>
> Cost: TL;DR ~180 tok · whole note ~4.2k tok. Read more: ## 4. Data design: make resets cheap before you need them · ## 6. Currency resets and compensation · ## 8. Edge cases and failure modes · ## 10. Checklist
<!-- tldr:end -->

Sooner or later a live economy needs a reset. Currency has inflated so far that new players can never catch up, a leaderboard has been frozen for months by the same ten names, a dupe exploit flooded the market, or a rebalance makes old progress meaningless. A reset can renew a game, or it can be the update that loses your most loyal players in a week. The difference is almost entirely in what you keep, what you give back, and how you say it.

[[Economy Inflation Sinks and Faucets Math]] covers measuring inflation and fixing it gently, with a short section on fixing a live inflated economy. [[Data Schema Design and Migrations]] tells the story of development-time wipes in one production game. This note is about **deliberate, player-facing resets in a live game**: the kinds of reset, choosing one, the data mechanics (season-scoped data, lazy rollover, leaderboards), the boundary problems, compensation, and when a reset is the wrong tool.

Source labels: **Roblox docs (as of October 2026)**, **rule of thumb**, **measured in the reference project**.

## 1. Kinds of reset

| Kind | What resets | What stays | Typical reason | Trust cost |
|---|---|---|---|---|
| Leaderboard season | Ranking stats on a board | Everything else | Fresh competition | Very low |
| Ranked soft reset | Rating pulled toward the middle | Rank history, rewards | New competitive season | Low |
| Seasonal realm | A separate season character or save | The permanent account, untouched | ARPG-style fresh start, opt-in | Low if opt-in |
| Currency reset | Soft currency (and maybe items bought with it) | Cosmetics, Robux purchases, collection | Runaway inflation | Medium to high |
| Progress wipe | Levels, zones, most items | Robux purchases, settings, cosmetics | Major rebalance, relaunch | High |
| Full wipe | Everything except what money bought | Purchases (always) | Beta to launch only | Very high after launch |

The first three are design features players can enjoy. The last three are interventions players endure. Prefer the top of the table, and treat a progress or full wipe after launch as a last resort.

## 2. Reasons that justify a reset (and ones that do not)

Good reasons:

- **Competition needs a fresh start.** Leaderboards and ranks that never reset stop motivating anyone outside the top. A weekly or monthly leaderboard season fixes this with no loss to anyone.
- **Opt-in seasonal play.** Some players love starting over with new rules (a new modifier, a new map) while their main save waits. This is the ARPG season model.
- **Beta to launch.** Players in a test period generally accept that progress was provisional, if you said so at the start.
- **An exploit that can be cleanly reversed.** If dupes can be identified (item ids, receipts, logs), a targeted removal is better than any reset ([[Economy Exploits - Dupes Races and Purchase Abuse]]).

Weak reasons:

- **"Inflation"** without measuring it. Many economies that feel inflated are just in healthy growth; check with the measures in [[Economy Inflation Sinks and Faucets Math]] first.
- **A rebalance you could migrate instead.** If the new zone ladder is harder, convert old progress into the new ladder rather than erasing it ([[Schema Migrations - Worked Case Studies]]).
- **A dead game you want to relaunch.** A wipe will not bring back players who left; it will mostly push away the ones who stayed.

## 3. The non-negotiables

Rule of thumb, but very firmly held:

1. **Never take away what players paid Robux for** without equal or better compensation. Purchased passes, products already bought, purchased cosmetics and the records of those purchases survive every reset. If a Robux-bought consumable (a currency pack) is wiped as part of a currency reset, refund its value in a currency that survives, or exempt it. Removing paid value is a fast way to generate refund requests and reports ([[Refunds Chargebacks and Purchase Support]]).
2. **Receipt records are never wiped.** The purchase history store is what stops double grants and what support needs. One production game kept its receipts store, gift intents and settings on separate data stores that were never versioned with progress, while progress stores were wiped by bumping a version suffix (measured in the reference project; see [[Data Schema Design and Migrations]]).
3. **Settings survive.** Nobody wants to re-set graphics and audio after a season.
4. **Announce before, never after.** A reset discovered on login is the worst version of any reset.
5. **Give something permanent for what is lost.** A badge, title, frame or cosmetic that says "Season 2 veteran, reached zone 9" turns lost progress into earned history.

## 4. Data design: make resets cheap before you need them

The cheapest reset is the one your data model already expects. Split the profile into **permanent** and **seasonal** parts from day one, even if you never plan a reset:

```lua
-- Shape of a profile designed for seasons (illustrative).
local profileTemplate = {
	SchemaVersion = 4,
	Permanent = {
		Cosmetics = {},        -- owned forever
		Purchases = {},        -- product grants already applied, by receipt id
		Badges = {},           -- season veteran titles live here
		Settings = {},         -- or a separate store, as in the reference project
		SeasonHistory = {},    -- one summary line per past season
	},
	Season = {
		Id = "S1",
		Coins = 0,
		Level = 1,
		Zones = {},
		Items = {},
	},
}
```

Then a seasonal reset is "replace `Season` with a fresh table and write a summary to `SeasonHistory`", and a design question ("does X survive?") has an obvious answer: it survives if it lives under `Permanent`.

### Lazy rollover on load

Do not try to reset every player's save at the moment the season changes. You cannot enumerate and rewrite millions of keys safely (listing keys is slow and budgeted, and players in active sessions hold session locks). Instead, roll over each profile **the next time it loads**:

```lua
--!strict
-- ServerScriptService/Season/SeasonRollover (ModuleScript)
-- Called right after a profile is loaded and session-locked, before gameplay reads it.
-- Idempotent: running it twice for the same season does nothing the second time.
local SeasonRollover = {}

export type SeasonInfo = { id: string, startsAt: number }

local function freshSeason(id: string): any
	return { Id = id, Coins = 0, Level = 1, Zones = {}, Items = {} }
end

-- Rewards for the season that is ending, based on how far the player got.
local function legacyRewards(old: any): { string }
	local out = {}
	if (old.Level or 1) >= 50 then
		table.insert(out, `title_{old.Id}_veteran`)
	end
	return out
end

function SeasonRollover.apply(data: any, current: SeasonInfo, now: number): boolean
	local season = data.Season
	if season and season.Id == current.id then
		return false -- already in the current season
	end
	if now < current.startsAt then
		return false -- clock or config says the season has not started; never roll early
	end
	if season then
		-- 1. Record history first, so a crash after this point loses nothing important.
		data.Permanent.SeasonHistory[season.Id] = {
			level = season.Level,
			zones = #season.Zones,
			endedAt = now,
		}
		-- 2. Permanent rewards for the old season.
		for _, badgeId in legacyRewards(season) do
			data.Permanent.Badges[badgeId] = true
		end
	end
	-- 3. Replace the seasonal part.
	data.Season = freshSeason(current.id)
	return true
end

return SeasonRollover
```

Properties of this design:

- **Idempotent by season id.** Every server can call it on every load. A player who joins two servers in a row is rolled over once.
- **No mass job, no budget spike.** The cost is spread over the days after the season starts as players return. Players who never return are never touched, which is fine.
- **Ordering inside the function** writes history and rewards before replacing the season table. All three happen in memory with no yield, and the profile layer saves them together.
- **"Never roll early"** guards against a server reading a mistyped season config. A season start in the future must not wipe anyone.
- **Old servers are the boundary risk.** A server on an older build, or with a cached season id, would keep writing into the old season. Read the current season from config with a refresh at boundaries ([[Global State and Live Config]]), and restart servers at the season boundary when the build changed ([[Server Lifecycle and Shutdown]]).

### Session locks and the boundary

A player who is online when the season flips holds a session-locked profile from the old season. Options (rule of thumb):

- **Roll over at the next load.** The player finishes the session in the old season, which is the least surprising for them; their progress after the boundary counts toward the old season.
- **Roll over live at the boundary.** Every server, at `startsAt`, applies the rollover to profiles it holds, and refreshes UI. More dramatic, more code paths, and a player mid-fight loses their items mid-fight. Avoid for anything but leaderboards.
- **Restart servers at the boundary** with a message. Clean, and pairs well with a season update publish.

### Leaderboards per season

Do not clear a leaderboard store; create a new one per season. An `OrderedDataStore` named with the season id (`Coins_S2`, or a weekly name such as `PvP_W<weekNumber>`) starts empty automatically, old boards remain readable for hall-of-fame displays, and there is no deletion job. The reference project used versioned leaderboard stores plus a weekly PvP board named by week (measured in the reference project). Details of the read and write budgets are in [[OrderedDataStores and Leaderboards]] and [[Global Leaderboards End to End]].

## 5. Ranked soft resets: the math

Competitive games usually do not zero ratings each season; they compress them toward the middle so the ladder reshuffles quickly but skilled players start ahead. A common formula (rule of thumb):

`new = anchor + (old - anchor) * k`

where `anchor` is the starting rating (say 1,000) and `k` is between 0 and 1.

| Old rating | k = 0.5 | k = 0.75 |
|---|---|---|
| 2,200 | 1,600 | 1,900 |
| 1,500 | 1,250 | 1,375 |
| 1,000 | 1,000 | 1,000 |
| 700 | 850 | 925 |

Smaller `k` means more reshuffling and more early-season matches between very different skill levels (stomps). Larger `k` keeps matches fair but makes the reset feel like nothing changed. Many games pair a moderate `k` with **placement matches** that move rating faster for the first few games, and a **season reward based on peak rank**, which survives the reset as a permanent cosmetic.

## 6. Currency resets and compensation

If you must reset a currency, convert rather than erase. A conversion table makes the trade explicit:

| Held at reset | Converted to |
|---|---|
| Soft currency | A permanent cosmetic tier based on amount, plus a small starting boost in the new season |
| Items bought with soft currency | Kept if cosmetic; converted to a token if they are stat items being removed |
| Robux-bought currency packs | Credited back in full in a currency that survives (or exempted from the reset) |
| Robux-bought boosts with time left | Time preserved, or extended |
| Collection and bestiary progress | Kept; it is history, not wealth |

Run the conversion as part of the lazy rollover (section 4), keyed by season id, so it happens exactly once per player.

### Simulate the conversion

Before announcing, run the conversion over a sample of real profiles (exported through [[Open Cloud APIs]] or sampled as players load, logged but not applied) and look at the distribution of outcomes: how many players lose the most, what a median player gets, whether any player ends up with more than intended. A conversion that looks fair on paper often hands a few hoarders a huge bonus, or gives casual players nothing.

### Purchases near the boundary

A player who buys a currency pack an hour before a currency reset has been sold something that is about to vanish. Rules of thumb: **turn off sales of resettable currency in advance** (a week is reasonable), say so in the shop, and exempt any packs bought in the final window from the reset. A kill switch per product in configs makes this a dashboard action ([[Feature Flags and Staged Rollouts]]).

## 7. Communication plan

Resets live or die by communication. A timeline that works (rule of thumb):

| When | What |
|---|---|
| 3 to 4 weeks before | Announce the reset, the reason, and the "what stays, what goes" table. Pin it everywhere you communicate ([[Patch Notes and Player Communication]]) |
| 2 weeks before | Show legacy rewards: what players will earn by reaching certain points before the reset. Gives a goal to the end |
| 1 week before | Stop selling anything that will be reset. In-game banner with the date in the player's local time computed from UTC |
| Reset day | Season update, event page, 60-character update announcement, a welcome screen in game explaining what happened to this player's save specifically |
| 1 week after | Answer the top questions publicly; fix any conversion mistakes generously |

The **personal welcome screen** matters more than any public post. Show the player their own numbers: "Season 2 ended. You reached zone 9 (earned the Zone Walker title). Your 1.2M coins became the Gold Vault frame and a 2x XP boost for 3 days." Abstract rules read as loss; personal numbers read as a trade.

Do not:

- Announce on the day.
- Call a progress wipe a "fresh start" in marketing and avoid the word "reset" in game; players will say it plainly in comments.
- Change the plan after announcing without saying so.

## 8. Edge cases and failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Some players rolled over twice, lost new-season progress | Rollover keyed on a timestamp or flag that was reset, not season id | Idempotent on season id |
| Players wiped a day early | Season config mistyped; no "never roll early" guard | Guard on `startsAt`; validate configs |
| Old-season servers keep granting old-season currency after the boundary | Cached season id; outdated build | Refresh at boundary; restart servers |
| Leaderboard still shows last season | Same store reused, cache | New store name per season |
| Robux packs lost in a currency reset | Paid value not exempted | Exempt or credit back; stop sales in advance |
| Support flooded with "where did my stuff go" | No personal explanation in game | Welcome screen with the player's own numbers |
| Hoarders profit hugely from the conversion | Linear conversion of a skewed distribution | Simulate on real data; tier and cap the conversion |
| Session-locked profile rolled over mid-fight | Live rollover at the boundary | Roll over on next load or restart servers |

## 9. When not to reset

- **When a migration would do.** Converting old progress into a new structure keeps players and their sense of ownership ([[Data Schema Design and Migrations]]).
- **When the problem is a single exploit.** Targeted removal using logs and item ids is narrower and fairer.
- **When the team cannot support the aftermath.** A reset week generates more support questions than any update. Do not schedule one during a holiday break.
- **When your audience is mostly casual collectors.** Players who come for collection and cosmetics value persistence more than competition; offer an opt-in seasonal mode instead.

## 10. Checklist

- [ ] Reset type chosen from the least damaging that solves the problem
- [ ] Problem measured, not felt
- [ ] Profile split into permanent and seasonal parts
- [ ] Rollover is lazy, idempotent on season id, and never runs early
- [ ] Receipts, purchases, settings and cosmetics untouched
- [ ] Robux-bought resettable items exempted or credited; sales stopped in advance
- [ ] Leaderboards use a new store per season
- [ ] Soft reset formula chosen and tested on real rating data
- [ ] Conversion simulated on real profiles
- [ ] Announced 3 to 4 weeks ahead with a "what stays, what goes" table
- [ ] Personal welcome screen shows each player what happened to their save
- [ ] Permanent veteran reward for every season

## See also
[[Live Ops Deep Dive Start Here]] · [[Economy Inflation Sinks and Faucets Math]] · [[Economies and Currencies]] · [[Data Schema Design and Migrations]] · [[Data Schema Design and Migrations]] · [[OrderedDataStores and Leaderboards]] · [[Session Locking and Profile Libraries]] · [[Rebirth and Prestige System End to End]] · [[Battle Pass and Season Design]] · [[Patch Notes and Player Communication]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Currency Architecture - Soft Hard and Event Currencies]] · [[Faucets and Sinks]] · [[Economy Design Start Here]] · [[Release Process and Rollbacks]] · [[Data Schema Versioning]] · [[Links - Leaderboards]]
<!-- auto-links:end -->
