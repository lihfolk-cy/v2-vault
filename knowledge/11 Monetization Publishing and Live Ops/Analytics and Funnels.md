---
tags: [analytics, analyticsservice, funnels, economy, custom-events, live-ops, luau]
---
# Analytics and Funnels

Creator Analytics gives every game standard dashboards (retention, engagement, monetization, acquisition) for free. `AnalyticsService` adds your own data: **economy events** (currency sources and sinks), **funnel events** (where players drop out of a sequence), **progression events** and **custom events** (anything else). This note covers what each dashboard tells you, how to instrument a game correctly in Luau, the limits that silently break instrumentation, and how to turn charts into decisions. Verified against the Creator Hub analytics pages and the `AnalyticsService` reference **as of October 2026**.

---

## 1. The built-in dashboards (Docs)

Creator Hub, Analytics: a game overview with benchmark comparisons, plus Retention, Engagement, Monetization and Acquisition pages, an Insights panel that flags large moves in DAU, new users and revenue, Funnel analytics, Benchmark scorecards, an Explore page for custom events, and Economy dashboards for economy events.

Key metrics named in the docs: **Day 1, Day 7, Day 30 retention**, average session time, **payer conversion rate**, **ARPPU** (average revenue per paying user), DAU and new users, daily Robux revenue, play-through rate, share link visits. For games you cannot see analytics for, like ratio and concurrent users.

Thresholds and limits (Docs): benchmark scorecards need **100+ DAU** and update daily; watchlists hold up to nine games.

Separate dashboards elsewhere in the Creator Hub: Ads analytics ([[Ads and Rewarded Video]]), Creator Rewards and Roblox Plus earnings ([[Subscriptions and Premium Payouts]]), notification analytics ([[Live Ops Events and Updates]]), thumbnail personalisation ([[Thumbnails Icons and Store Page]]), the error report and performance dashboards ([[Crash and Error Telemetry]]).

### Reading the core four (rule of thumb)
- **D1 retention** is the health of your first session. If it is low, nothing else matters yet.
- **D7 / D30** show whether there is a mid and long game.
- **Session time** with the 60-minute cap of the recommendation playtime signal in mind ([[Discovery and the Algorithm]]).
- **Payer conversion x ARPPU** = revenue per user. Raising conversion (more people buy something) usually beats raising ARPPU (whales spend more) for long-term health.

Always segment before concluding: new versus returning, platform (phone versus PC behave differently), country, and update date.

---

## 2. AnalyticsService API (Docs, Oct 2026)

Current methods:
- `LogEconomyEvent(player, flowType: Enum.AnalyticsEconomyFlowType, currencyType: string, amount: number, endingBalance: number, transactionType: string, itemSku: string?, customFields: {}?)`
- `LogFunnelStepEvent(player, funnelName: string, funnelSessionId: string?, step: number?, stepName: string?, customFields: {}?)`
- `LogOnboardingFunnelStepEvent(player, step: number, stepName: string?, customFields: {}?)`
- `LogProgressionEvent(player, progressionPathName, status: Enum.AnalyticsProgressionType, level, levelName?, customFields?)` and the shortcuts `LogProgressionStartEvent`, `LogProgressionCompleteEvent`, `LogProgressionFailEvent`
- `LogCustomEvent(player, eventName: string, value: number = 1, customFields: {}?)`
- `GetPlayerSegmentsAsync(player)` for in-game segment data

Deprecated: `FireEvent`, `FireCustomEvent`, `FireInGameEconomyEvent`, `FireLogEvent`, `FirePlayerProgressionEvent`, the `ApiKey` property. Older tutorials use these; they belong to the retired PlayFab-era API.

### Rules that apply to all events (Docs)
- **Server only, published games only.** "Events can't be sent from the client or Studio." Testing in Studio produces nothing on the dashboard; that is expected.
- **Rate limits exist** (numbers not published). Batch: one event for "killed 10" instead of ten events.
- **Custom fields:** up to **three** per event, keys `Enum.AnalyticsCustomFieldKeys.CustomField01.Name` to `CustomField03.Name`; other keys are ignored; values must be strings; up to **8,000 unique combinations** of values across the three fields.
- Custom events: up to **100 custom event names** per game; event names have a much tighter cardinality limit than fields. Use one event name with a field, not many names.
- Custom event charts aggregate daily; allow up to 24 hours.

The cardinality limits are the silent killer: putting a user id, a timestamp or a free-text value in a custom field explodes combinations and your breakdowns stop being useful. Field values must come from small fixed sets ("Zone - 3", "Rarity - Mythic").

---

## 3. A typed analytics module

One server module wraps every call: it enforces server-only, string fields, positive amounts and batching, and never lets analytics errors break gameplay.

```lua
--!strict
-- ServerScriptService/Services/Analytics (ModuleScript)
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

assert(RunService:IsServer(), "Analytics is server-only")

local Analytics = {}

type Fields = { string } -- up to three short values from fixed sets

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function toFields(values: Fields?): { [string]: string }?
	if not values then
		return nil
	end
	local out = {}
	for i = 1, math.min(#values, 3) do
		out[FIELD_KEYS[i]] = tostring(values[i])
	end
	return out
end

local function safe(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Analytics]", err) -- never propagate
	end
end

-- Economy ---------------------------------------------------------------
function Analytics.Source(player: Player, currency: string, amount: number, balance: number, txType: string, sku: string?, fields: Fields?)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, currency, amount, balance, txType, sku or "", toFields(fields))
	end)
end

function Analytics.Sink(player: Player, currency: string, amount: number, balance: number, txType: string, sku: string?, fields: Fields?)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, balance, txType, sku or "", toFields(fields))
	end)
end

-- Onboarding (one-time funnel) -------------------------------------------
local onboardingMax: { [Player]: number } = {}

function Analytics.Onboarding(player: Player, step: number, stepName: string)
	-- Only log forward progress; repeated or skipped-back steps are noise.
	if step <= (onboardingMax[player] or 0) then
		return
	end
	onboardingMax[player] = step
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- Recurring funnels (shop checkout, crafting...) -------------------------
function Analytics.NewFunnelSession(): string
	return HttpService:GenerateGUID(false)
end

function Analytics.FunnelStep(player: Player, funnel: string, sessionId: string, step: number, stepName: string, fields: Fields?)
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, stepName, toFields(fields))
	end)
end

-- Batched custom events ---------------------------------------------------
-- Counts accumulate per player/event/field-set and flush every FLUSH seconds.
local FLUSH = 60
local pending: { [Player]: { [string]: { name: string, value: number, fields: Fields? } } } = {}

function Analytics.Count(player: Player, eventName: string, amount: number?, fields: Fields?)
	local byKey = pending[player]
	if not byKey then
		byKey = {}
		pending[player] = byKey
	end
	local key = eventName .. "|" .. table.concat(fields or {}, "|")
	local entry = byKey[key]
	if entry then
		entry.value += amount or 1
	else
		byKey[key] = { name = eventName, value = amount or 1, fields = fields }
	end
end

local function flush(player: Player)
	local byKey = pending[player]
	pending[player] = nil
	if not byKey then
		return
	end
	for _, e in byKey do
		safe(function()
			AnalyticsService:LogCustomEvent(player, e.name, e.value, toFields(e.fields))
		end)
	end
end

task.spawn(function()
	while true do
		task.wait(FLUSH)
		for player in pending do
			flush(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	flush(player)
	onboardingMax[player] = nil
end)

return Analytics
```

On `BindToClose` call `flush` for every player too, inside the shutdown budget ([[Saving Correctly - Autosave and BindToClose]]).

**Reference project.** Its blade fusion system logged custom events for fuse (with star count), craft (with rarity rank) and auto-salvage, and logged auto-salvage as a **count per minute** rather than one event per blade, because auto-salvage can fire dozens of times a minute. That is exactly the batching rule above.

---

## 4. Economy events done right

Economy dashboards show total sources and sinks by category, average wallet balance, top sources and sinks, and all sources and sinks (Docs). Up to **five currencies** can be tracked (Docs).

Transaction types (`Enum.AnalyticsEconomyTransactionType`, use `.Name`): **IAP** (source; Robux purchases), **TimedReward** (source), **Onboarding** (source), **Shop** (source or sink), **Gameplay** (source or sink), **ContextualPurchase** (sink). Custom names are allowed (Docs).

Rules:
- **Amounts are always positive**; the flow type sets direction (Docs).
- **Ending balance** is the balance after the transaction; it powers the average-wallet chart. Read it from the same data you just changed.
- **SKU** names the item ("GemsSmall", "ForgeMaterial_Mythic"); without it the tables show "N/A" (Docs).
- **Log at the single place currency changes.** If every system calls `data.Gems += x` directly, you will miss sources. Route all changes through one `Currency.Add(player, kind, amount, txType, sku)` function that updates data, replicates and logs. See [[Economies and Currencies]].
- **Large incomes:** if passive income ticks every second, aggregate per minute per source before logging.

What to look for:
- **Inflation:** sources growing faster than sinks; average wallet balance rising without bound. Players stop valuing currency; prices feel arbitrary.
- **Dead sinks:** a shop item nobody buys.
- **IAP share of sources:** if purchased currency is a tiny share, the gem shop is not compelling (the reference team's "gems don't do much" moment).
- **Onboarding sources** that are too generous compress the early game.

---

## 5. Funnels

Docs distinguish **one-time funnels** (onboarding: once per user) and **recurring funnels** (shop checkout: many times per user).

Rules (Docs):
- A funnel starts when step 1 is logged; to start on join, log step 1 in `PlayerAdded`.
- Only the first instance of a repeated step counts. If a step is skipped, earlier steps count as complete.
- **One-time funnels need no session id.** Recurring funnels use a GUID per attempt; long-running ones can use a stable key like `<playerId>-<itemId>`.
- Only the **10 most recent unique session ids per user per funnel** are tracked. A step not seen for **180 days** expires and the user counts as new.
- The dashboard shows up to **ten funnels** as tabs; filters apply to step 1 only; funnels are cohorted by entry date.
- Changing step names shows a warning in ranges that span the change; set the date range after the update.
- **Validate client-reported steps on the server** (do not let a client log step 9 directly).

### An onboarding funnel that finds your bounce

| Step | Name | When |
|---|---|---|
| 1 | Joined | `PlayerAdded` |
| 2 | Loaded | Client reports first frame of gameplay (validated) |
| 3 | FirstAction | First roll / first jump / first hit |
| 4 | FirstReward | First item or currency |
| 5 | TutorialDone | Tutorial complete |
| 6 | FirstGoal | First zone / level / boss |
| 7 | Minute10 | 10 minutes in session (the Creator Rewards daily engagement bar) |

Large drop between 1 and 2 is load time. Between 2 and 3, the start is confusing. Between 5 and 6, there is no next goal; the reference project's "players feel thrown in" complaint led to a "next goal" tracker for exactly this gap.

### A shop funnel

| Step | Name |
|---|---|
| 1 | ShopOpened |
| 2 | ItemViewed (custom field: category) |
| 3 | PromptShown |
| 4 | PurchaseGranted (log from `ProcessReceipt` after success) |

Use a new session id per shop open. If 3 to 4 is weak, price or prompt timing is off; if 1 to 2 is weak, the store layout hides value ([[Pricing and Store Design]]). Log a separate funnel for the starter-shop view shown to non-payers so you can compare it with the full catalogue.

---

## 6. Experiments and decisions

- **Change one thing at a time** and annotate the date. A thumbnail change, a price change and a new zone in the same week cannot be untangled.
- **Use cohorts by join date.** Compare players who joined after the change with those who joined before.
- **Look at medians**, not only averages, for session time and spend; a few whales distort averages.
- **Small games:** with low DAU, daily noise is large. Use weekly views and avoid conclusions from fewer than a few hundred players per variant (rule of thumb).
- **Roblox's own tools:** price optimization ([[Pricing and Store Design]]), thumbnail personalisation, ad placement experiments ([[Ads and Rewarded Video]]) run their own tests; do not overlap your own changes with them.

---

## 7. Common mistakes
- Logging from the client or testing in Studio and concluding "analytics is broken".
- User ids, timestamps or free text in custom fields (cardinality).
- One event name per item instead of one name with a field.
- Logging the price from config instead of `receiptInfo.CurrencySpent`.
- Missing currency sources because changes are scattered.
- Unbatched high-frequency events hitting rate limits.
- Changing funnel step names mid-analysis.

## 8. Checklist
- [ ] One analytics module, server-only, all calls in `pcall`
- [ ] All currency changes through one function that logs economy events
- [ ] Onboarding funnel from join to 10 minutes
- [ ] Shop funnel with per-open session ids
- [ ] Custom events batched; fields from fixed small sets
- [ ] Weekly review: D1/D7, funnel drops, economy balance, payer conversion
- [ ] Every release date annotated

## See also
[[Discovery and the Algorithm]] · [[Economies and Currencies]] · [[Balancing with Spreadsheets and Data]] · [[First-Time User Experience and Onboarding]] · [[Retention and Return Hooks]] · [[Pricing and Store Design]] · [[Crash and Error Telemetry]] · [[Live Ops Events and Updates]]

## Connected notes
<!-- auto-links:start -->
[[Economy Telemetry and Balancing Live]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Telemetry Events]] · [[Onboarding Funnel]] · [[Links - Analytics]] · [[A-B Testing and Experiments on Roblox]]
<!-- auto-links:end -->
