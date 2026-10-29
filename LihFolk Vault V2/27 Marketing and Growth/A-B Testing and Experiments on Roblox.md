---
tags: [marketing, growth, experiments, ab-testing, configservice, analytics, statistics, luau, type/guide, area/marketing, level/intermediate, api/ConfigService]
---
# A-B Testing and Experiments on Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Groups not the expected size (SRM warning): Enrolment depends on something the variant changes (for example... -> Enrol before the difference starts; restart the...
> - Everything "not significant": Test underpowered; effect smaller than MDE -> Bolder change, larger rollout, longer duration, or accept that it...
> - Big early win that fades: Novelty effect or peeking -> Run the full duration; judge at the end
> - Hypothesis, key, enrolment point, goal and guardrails written down
> - MDE checked on the dashboard before starting; change bold enough to detect
> - `GetConfigForPlayerAsync` + `GetValue` only at the moment of exposure
>
> Cost: TL;DR ~200 tok · whole note ~4.6k tok. Read more: ## 2. Configs and experiments: how they work (Roblox docs, as of October 2026) · ## 3. Wiring an experiment in strict Luau · ## 8. Failure modes · ## 9. Checklist
<!-- tldr:end -->

An A-B test shows two versions of something to two random groups of players and measures which one does better. It is the only reliable way to know whether a change caused an effect, because everything else (school holidays, a competitor's update, a viral clip) hits both groups equally. Roblox now has a built-in experiments system tied to Configs, plus several narrower tools that run their own tests (thumbnail personalisation, price optimisation, ad placement experiments). This note covers how the built-in system works, how to wire it in strict Luau, the statistics that decide whether a small game can test at all, how to build your own split when the built-in one does not fit, and the mistakes that produce confident wrong answers.

Platform facts are labelled "Roblox docs (as of October 2026)"; the experiments feature is new and the docs pages have been revised during 2026, so check them before building. Statistics and practice are rule of thumb unless noted.

---

## 1. What you can test, and with which tool

| Question | Tool | Notes |
|---|---|---|
| Which thumbnail gets more qualified plays? | Thumbnail personalisation (Roblox docs) | Runs automatically with 2+ thumbnails; see [[Thumbnails Icons and Store Page]] |
| Which price for a product? | Price optimisation (Roblox docs) | Covered in [[Pricing and Store Design]] |
| Does a rewarded ad placement hurt playtime? | Ads experiments (Roblox docs) | See [[Ads and Rewarded Video]] |
| Which onboarding flow, shop layout, reward size, difficulty? | **Experiments on Configs** | This note |
| Which matchmaking setup? | Matchmaking experiments | Only one at a time; no code changes (Roblox docs) |
| Something the built-in tool cannot express | Your own split | Section 6 |

Do not run overlapping tests that touch the same players and the same metric without thinking about interference: a price test and a shop layout test both change revenue, and their effects mix.

---

## 2. Configs and experiments: how they work (Roblox docs, as of October 2026)

### Configs
- Key-value pairs you change in Creator Hub **without publishing**. Types: string, number, boolean, JSON object. Up to **1,000 active configs**; string and JSON values up to **100,000 characters**.
- Edits are **staged** first and can be tested in Studio play sessions before players see them. "Publish now" reaches players in about **15 seconds to a minute**; a gradual option rolls out over 15 minutes.
- **`ConfigService` is server-only.** Calling it from a client script errors.
- `ConfigService:GetConfigAsync()` returns a snapshot of global values (no targeting, **no experiments**). `ConfigService:GetConfigForPlayerAsync(player)` returns a per-player snapshot with targeting and experiments applied.
- A `ConfigSnapshot` is frozen at the time requested. `UpdateAvailable` fires when new values exist; `Refresh()` fetches them; `GetValueChangedSignal(key)` fires for a key after a refresh. `GetValue(key)` returns nil for a missing key.
- `SetTestingValue(key, value)` and `ClearTestingValue()` set test values for the current server only (in Studio, the current play session only).
- Conditional targeting by attributes such as country, language, new vs returning, source, platform and payer or activity status. Limits: **100 conditions per game, 20 per key**; first matching rule wins.

### Experiments
- **In-game experiments** test config values: **up to two variants plus a control**, one active experiment **per config key**. A rollout percentage decides who is in the test; players outside get the control value and do not affect results.
- **Duration 14 to 60 days.** After scheduling you cannot change duration, rollout or variants, only reschedule.
- **Enrolment** happens on the first `GetValue()` call for that key on a per-player snapshot. That first call is random; later calls return the same value for the experiment's duration. Targeting attributes are evaluated per session; a player's data stays attributed to the group they were enrolled in. The docs suggest saving the assignment yourself if you need continuity in your own systems.
- **Metrics** tracked for every experiment: D1 retention, D7 retention, playtime, ARPU, ARPPU, payer conversion, session time. You pick one as the goal.
- **Significance** is shown with confidence intervals on percent change: a result is significant when the interval does not include 0%. Daily results update every 24 hours.
- **Early harm** checks in the first 24 hours (playtime at -10%, ARPU and payer conversion at -20%), flagged only when the whole interval is below the threshold, and only with **10,000+ players** across variant and control.
- **Sample ratio mismatch** (groups not the size they should be) is checked; the docs recommend stopping and restarting if detected.
- A **minimum detectable effect** is shown when you create the experiment. The docs warn that games under about **1,000 DAU** may struggle to get useful data.
- While running, the config key and its conditions are **locked**. Ending: you choose a winner (it becomes the new default) or keep the control.

---

## 3. Wiring an experiment in strict Luau

The key rule from the docs: **call `GetValue` only when the player reaches the part of the game being tested.** Enrolling everyone at join dilutes the result with players who never saw the feature.

```lua
--!strict
-- ServerScriptService/Services/Experiments (ModuleScript)
-- Wraps ConfigService so gameplay code asks for a value at the moment it matters.
-- Reviewed, not run.
local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")

local Experiments = {}

local snapshots: { [Player]: ConfigSnapshot } = {}
local loading: { [Player]: boolean } = {}

local function getSnapshot(player: Player): ConfigSnapshot?
	local existing = snapshots[player]
	if existing then
		return existing
	end
	if loading[player] then
		-- Another thread is fetching; wait briefly rather than double-fetching.
		local t0 = os.clock()
		while loading[player] and os.clock() - t0 < 5 do
			task.wait(0.1)
		end
		return snapshots[player]
	end
	loading[player] = true
	local ok, result = pcall(function()
		return ConfigService:GetConfigForPlayerAsync(player)
	end)
	loading[player] = nil
	if ok and player.Parent then
		snapshots[player] = result
		return result
	end
	if not ok then
		warn("[Experiments] snapshot failed", result)
	end
	return nil
end

-- Returns the value for this player, or the default if anything fails.
-- Calling this ENROLS the player if the key has a running experiment.
function Experiments.Get<T>(player: Player, key: string, default: T): T
	local snap = getSnapshot(player)
	if not snap then
		return default
	end
	local ok, value = pcall(function()
		return snap:GetValue(key)
	end)
	if ok and value ~= nil and typeof(value) == typeof(default) then
		return value :: any
	end
	return default
end

Players.PlayerRemoving:Connect(function(player)
	snapshots[player] = nil
	loading[player] = nil
end)

return Experiments
```

Notes:
- **Type check against the default.** A config edited to the wrong type should not crash gameplay.
- **Always have a code default** equal to the control. If [[ConfigService]] is unavailable, players get the control, which keeps the game playable (they may still be counted in a group by Roblox if enrolment happened; that is a reason to keep defaults identical to control).
- Snapshots are not refreshed here on purpose: during an experiment the enrolled value is stable, and for live tuning you may want a separate global snapshot with `UpdateAvailable` and `Refresh()`.
- The `ConfigSnapshot` type name follows the docs' class name; if the type checker does not know it in your Studio version, annotate as `any` locally.

### Passing a value to the client
The client cannot read ConfigService. When a variant changes UI or client feel, set an attribute from the server at the decision point:

```lua
--!strict
-- Server, when the player first opens the shop.
local Experiments = require(script.Parent.Experiments)

local function onShopOpened(player: Player)
	-- Enrol only now, when the player actually sees the shop.
	local layout = Experiments.Get(player, "shop_layout", "grid")
	if layout ~= "grid" and layout ~= "featured_first" then
		layout = "grid" -- whitelist; never trust a config typo
	end
	player:SetAttribute("ShopLayout", layout)
end
```

The client reads `player:GetAttribute("ShopLayout")` and builds the layout. Only cosmetic or presentation choices should travel this way; anything affecting rewards or prices stays decided on the server.

### Logging your own breakdowns
Roblox's experiment metrics are the main read. Add the variant as a custom field on your funnel steps so you can see *where* in the funnel a variant helps or hurts ([[Analytics and Funnels]]). Keep field values small and fixed ("Shop - grid", "Shop - featured_first").

---

## 4. The statistics a small game cannot escape

### Sample size for a retention test
For a yes/no metric such as D1 retention, a common approximation for the players needed **per group** to detect an absolute difference `d` at about 95% confidence and 80% power is:

```
n per group ~ 16 x p x (1 - p) / d^2
```

where `p` is the baseline rate (rule of thumb formula from standard A-B testing practice; the Roblox docs show an MDE instead of publishing a formula).

Worked example: baseline D1 is 20% (`p = 0.2`), and you want to detect a lift to 21% (`d = 0.01`, a 5% relative lift).

```
n ~ 16 x 0.2 x 0.8 / 0.0001 = 25,600 players per group
```

For a two-group test, about **51,200 new players** must reach the tested feature. If your game gets 400 new players a day and the test sits in onboarding (all new players see it), that is about **128 days**, far beyond the 60-day maximum.

The same game can detect a **larger** effect: `d = 0.03` (20% to 23%) needs about 2,850 per group, 5,700 total, about **15 days**. That fits.

| Baseline D1 | Lift to detect (absolute) | Players per group | Days at 400 new/day (2 groups) |
|---|---|---|---|
| 20% | +1 pt | ~25,600 | ~128 |
| 20% | +2 pt | ~6,400 | ~32 |
| 20% | +3 pt | ~2,850 | ~15 |
| 20% | +5 pt | ~1,020 | ~5 (but run at least the 14-day minimum) |

### What this means in practice
- **Small games should test bold changes.** A completely different first minute, not a button colour.
- **Use the MDE the dashboard shows** when you set up the experiment. If it says the smallest detectable effect is 8% and you expect 2%, do not run that test; you will get "no significant difference" and learn nothing.
- **Revenue metrics are noisier than retention.** A few big spenders dominate ARPU, so revenue tests need much larger samples. Payer conversion (did they buy anything) is less noisy than ARPU.
- **Run the full planned duration.** Stopping the first day a result looks significant ("peeking") inflates false positives. The docs also warn about novelty effects in early results.
- **Weekly cycles.** Roblox traffic differs strongly between weekdays and weekends. The 14-day minimum covers two full weeks, which is good practice anyway.

---

## 5. Designing a good experiment

Write a one-paragraph plan before you start:

```
Hypothesis: Removing the class-select menu for new players (default class, swap later)
            will raise D1 because 30% of new players leave at that menu.
Key:        onboarding_class_select (boolean). Control: true. Variant: false.
Enrol at:   the moment a new player would see the menu.
Goal:       D1 retention. Guardrails: playtime, payer conversion.
MDE check:  dashboard shows detectable effect ~6% relative at 50% rollout, 21 days.
Decision:   ship variant if D1 interval excludes 0% and guardrails do not show harm.
            If inconclusive, keep control and test a bolder version.
Freeze:     no onboarding changes for 21 days.
```

Rules (rule of thumb):
- **One hypothesis, one key.** Changing three things in one variant tells you the bundle worked, not which part.
- **Guardrail metrics.** A variant that lifts D1 but cuts payer conversion may not be a win; decide in advance what trade-off you accept.
- **Freeze related changes.** The docs warn that content changes during a test can invalidate results. Do not patch onboarding mid-test.
- **Decide what "inconclusive" means before you start.** Most tests are inconclusive; that is a result too (the change does not matter much, so pick the cheaper option).

---

## 6. Building your own split

Sometimes the built-in system does not fit: you need more than two variants, a test inside a system with no config key, or a split that must persist forever (an economy change). A deterministic split from the user id gives stable groups without storage:

```lua
--!strict
-- ReplicatedStorage/Shared/Bucket (ModuleScript)
-- Deterministic bucket 1..100 from user id and a per-test salt.
-- Same player + same salt = same bucket on every server, forever.
-- Reviewed, not run.
local Bucket = {}

function Bucket.Of(userId: number, salt: number): number
	-- Random is deterministic for a given seed. Mixing the salt in gives
	-- independent splits per test, so the same players are not always "group B".
	local rng = Random.new(userId * 31 + salt) -- stays well inside exact integer range
	return rng:NextInteger(1, 100)
end

function Bucket.Variant(userId: number, salt: number, splits: { number }): number
	-- splits like {50, 50} or {34, 33, 33}; must sum to 100.
	local b = Bucket.Of(userId, salt)
	local acc = 0
	for i, share in splits do
		acc += share
		if b <= acc then
			return i
		end
	end
	return 1
end

return Bucket
```

Trade-offs of a home-made split:
- **You own the statistics.** The dashboard will not compute intervals; you export funnel and economy data and analyse it (with the sample size limits from section 4).
- **Log the variant everywhere** as an analytics field, from the first exposure.
- **Use the server's result for anything that matters.** The client could compute the same bucket, but it must not decide rewards.
- **Never reuse a salt.** Reusing it puts the same players in the treatment group of every test, which biases results across tests.

---

## 7. Ethics and policy in experiments

Experiments are still your game, under the same rules:
- **Paid random items must disclose numeric odds before purchase** in every variant (Community Standards). Testing different odds without disclosing them is not allowed.
- **Do not test deceptive patterns.** A variant with false urgency, hidden costs or a misleading prompt is not made acceptable by being an experiment. Notification rules already ban dark patterns explicitly ([[Live Ops Events and Updates]]).
- **Price tests and fairness.** Players compare notes. If two players in the same server see different prices for the same item, expect complaints. Prefer testing offer structure or placement over raw price, or use Roblox's price optimisation tool which is designed for it.
- **Economy splits persist.** A variant that gives more currency creates players with more currency after the test ends. Plan how to unify them ([[Economy Inflation Sinks and Faucets Math]]).
- **Under-13 players** are part of most tests by default. Make sure no variant collects data or prompts actions that would be inappropriate for them ([[Age Checks and Safety Features]]).

See [[Ethical Design and Player Trust]].

---

## 8. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Groups not the expected size (SRM warning) | Enrolment depends on something the variant changes (for example, enrolling after a step that the variant makes easier) | Enrol before the difference starts; restart the experiment |
| Everything "not significant" | Test underpowered; effect smaller than MDE | Bolder change, larger rollout, longer duration, or accept that it does not matter |
| Big early win that fades | Novelty effect or peeking | Run the full duration; judge at the end |
| Variant broke for some players | Config typo, wrong type | Type-checked `Get` with defaults; whitelist values |
| Results look odd after a patch | Mid-test change to the tested area | Freeze; restart if needed |
| Two tests interfere | Same players, same metric | Stagger tests or test different areas |
| Client shows variant but server grants control reward | Mixed decision points | Decide on the server once, pass to client by attribute |

## 9. Checklist
- [ ] Hypothesis, key, enrolment point, goal and guardrails written down
- [ ] MDE checked on the dashboard before starting; change bold enough to detect
- [ ] `GetConfigForPlayerAsync` + `GetValue` only at the moment of exposure
- [ ] Server decides; client gets presentation values by attribute
- [ ] Defaults in code equal the control
- [ ] Variant logged as an analytics field on related funnels
- [ ] Freeze on related changes for the full duration (14 to 60 days)
- [ ] Odds disclosure and honesty rules hold in every variant
- [ ] Decision rule (including "inconclusive") agreed before launch

## See also
[[Marketing and Growth Start Here]] · [[Analytics and Funnels]] · [[Global State and Live Config]] · [[Pricing and Store Design]] · [[Thumbnails Icons and Store Page]] · [[First-Time User Experience and Onboarding]] · [[Balancing with Spreadsheets and Data]] · [[Competitor Analysis Method]] · [[Launch Strategy - The First Two Weeks]]

## Connected notes
<!-- auto-links:start -->
[[Economy Telemetry and Balancing Live]] · Feature Flags and Staged Rollouts · Click-Through Rate · Links - Analytics · Economy Design Start Here · Discovery and the Algorithm
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Update Cadence and Hype Cycles]] · [[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]] · [[Sponsored Ads and Campaign Math]] · [[Short-Form Video Marketing]] · [[Game Icon Design - Readable at Small Sizes]] · [[Experience Description and Search Keywords]] · [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]] · [[Game Trailers and Clean Footage - Capture, Freecam and Editing]]
<!-- related:end -->
