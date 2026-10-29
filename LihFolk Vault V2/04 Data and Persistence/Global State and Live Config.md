---
tags: [data, configs, configservice, feature-flags, live-ops, global-state, messaging]
---
# Global State and Live Config

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Every server polling a data store config key every few seconds (Read budget and per-key throughput wasted; the 4 s cache hides...)
> - Avoid: Relying on MessagingService alone (Servers that miss a message stay wrong forever)
> - Avoid: `SetAsync` for global records several servers write (Lost updates (two boosts bought, one counted))
> - Tuning and flags in configs, with defaults in code and type checks.
> - Kill switches for risky systems.
> - Refresh policy decided per value (immediate vs boundary).
>
> Cost: TL;DR ~170 tok · whole note ~4.6k tok. Read more: ## Experience configs (ConfigService) · ## Game-written global state · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Some state belongs to the whole game rather than to a player: a feature flag, a drop-rate multiplier for a weekend event, the start time of a boss raid, a "server luck" boost someone bought for everyone, a kill switch for a broken system, a global counter ("1,000,000 eggs hatched"). Getting that state to every server quickly, safely, and without hammering a single data store key is its own problem. As of October 2026 Roblox has a first-party answer for read-only tuning (**experience configs** via `ConfigService`), and the classic tools (data stores, MessagingService, memory stores) for state the game itself writes. This note covers each, a combined pattern, and the traps.

## Choose by who writes and how fresh it must be

| State | Written by | Freshness | Best home |
|---|---|---|---|
| Feature flags, tuning numbers, event schedules, A/B values | Developers (dashboard, Studio, CI) | Seconds to minutes | **Experience configs** |
| Per-player-segment values (new players get more armor) | Developers | Minutes | Configs with targeting (`GetConfigForPlayerAsync`) |
| A global event a player triggers (server luck, a world boss summon) | The game | Seconds | MessagingService broadcast + durable record (data store or memory store) |
| Global counters | The game | Minutes | Sharded data store counters or memory store, aggregated |
| Cross-server live lists (servers, lobbies, auctions) | The game | Seconds | [[MemoryStore Service]] |
| Secrets | Developers | Rarely | Secrets store ([[HttpService and External APIs]]) |

The old habit of keeping tuning values in a `GlobalConfig` data store key that every server polls still works, but configs do it better: versioned history, staged testing, gradual rollout, targeting, and no data store budget.

## Experience configs (ConfigService)

From Roblox's configs documentation (October 2026):

- Keys with typed values: **string, number, boolean or JSON object**. Up to **1,000 active configs**. Strings and JSON up to **100,000 characters**; numbers are doubles (exact integers to plus or minus 2^53).
- Edit on Creator Hub (Configs page) or in Studio (**File > Open Configs**). New values are **staged** first: staged values are visible to your team in Studio play sessions, not to live players. Then **Publish now** (live in roughly 15 seconds to 1 minute) or **Publish over 15 min** (gradual rollout). Clients may take a few minutes. (The cloud-services comparison page instead says config changes "deploy over the course of five minutes"; treat a minute as typical and five as the worst case.)
- **History** shows every change with author, time, message and before/after values, with one-click **Restore** (which stages the old value; then publish).
- **Targeting**: conditions on country, language, new vs returning, acquisition source, first-played window, in-experience payer status, activity status, engagement, platform spender status, platform activity. Up to **100 conditions per game**, **20 per key**; rules are ordered globally and the first match wins. Conditional values must match the key's type. Experiments use the same machinery ([[Analytics and Funnels]]).
- Studio can **Publish As** to another experience, overwriting its configs: handy for promoting a staging experience's configs to live.
- `ConfigService` is **server only**. Calling it from a client errors.

### Reading configs

- `ConfigService:GetConfigAsync()` returns a `ConfigSnapshot` of global values (no targeting).
- `ConfigService:GetConfigForPlayerAsync(player)` returns a snapshot with that player's targeted values.
- `snapshot:GetValue(key)` returns the value, or `nil` if the key does not exist.
- Snapshots are **frozen points in time**. Updates do not apply automatically; `snapshot.UpdateAvailable` fires when newer values exist, and `snapshot:Refresh()` pulls them. After refreshing, `snapshot:GetValueChangedSignal(key)` fires for keys that changed.
- Errors: if configs never loaded, `GetConfigAsync` throws (rare); if the connection drops after a successful load, it returns the latest known values and reconnects, firing `UpdateAvailable` when it recovers.
- Testing: `ConfigService:SetTestingValue(key, value)` overrides a value on the current server only (or the current Studio session), triggering `UpdateAvailable`; `ClearTestingValue(key)` removes it. It can be called from the server Developer Console on a live server, which is a precise way to test a change on one server.

The script editor autocompletes config keys and, under `--!strict`, knows their types.

### A config wrapper with safe defaults

```lua
--!strict
-- ServerScriptService/Live/LiveConfig (ModuleScript)
local ConfigService = game:GetService("ConfigService")

-- Code-side defaults: the game must run correctly if configs are unreachable or a key is deleted.
local DEFAULTS = {
	dropRateMultiplier = 1,
	eventActive = false,
	eventEndsAt = 0,
	tradingEnabled = true,
	maxPartySize = 4,
}
export type Key = "dropRateMultiplier" | "eventActive" | "eventEndsAt" | "tradingEnabled" | "maxPartySize"

local LiveConfig = {}
local snapshot: ConfigSnapshot? = nil
local changed = Instance.new("BindableEvent")
LiveConfig.Changed = changed.Event -- (key, value)

local function load()
	local ok, result = pcall(function()
		return ConfigService:GetConfigAsync()
	end)
	if not ok then
		warn(`[LiveConfig] configs unavailable, using defaults: {result}`)
		return
	end
	local snap = result :: ConfigSnapshot
	snapshot = snap
	snap.UpdateAvailable:Connect(function()
		-- Apply immediately here. For values that must not change mid-round, defer the
		-- Refresh to a round boundary instead (see "when to refresh").
		pcall(function()
			snap:Refresh()
		end)
	end)
	for key in DEFAULTS do
		snap:GetValueChangedSignal(key):Connect(function(value)
			changed:Fire(key, value)
		end)
	end
end

function LiveConfig.get(key: Key): any
	local snap = snapshot
	if snap then
		local value = snap:GetValue(key)
		local fallback = DEFAULTS[key]
		-- type guard: a mistyped dashboard edit must not crash gameplay code
		if value ~= nil and type(value) == type(fallback) then
			return value
		end
	end
	return DEFAULTS[key]
end

task.spawn(load)
return LiveConfig
```

`ConfigSnapshot` is the engine's class name (see the engine reference); `GetValueChangedSignal` passes the new value per the docs' example.

### When to refresh

The docs give a good example: in a competitive game, refresh between rounds so weapon stats do not change mid-match. Generally:

- **Kill switches and flags**: refresh immediately.
- **Combat and economy numbers**: refresh at a boundary (round end, respawn, shop reopen).
- **Prices shown to players**: refresh, then re-render the shop; validate purchases against the value the player saw or the current one, consistently ([[Pricing and Store Design]]).
- **Per-player targeted values**: fetched on join; decide whether a player keeps their join-time value for the session (usually yes, for fairness and for clean experiment data).

### Kill switches

Every risky new system ships with a boolean config (`tradingEnabled`, `newDungeonEnabled`) checked at the entry points. When something breaks in production, flip it off in seconds instead of publishing a fix and migrating servers. This is the cheapest insurance in live ops ([[Live Ops Events and Updates]], [[Release Process and Rollbacks]]).

## Game-written global state

Configs are read-only to the game. When gameplay itself creates global state, combine a **durable record** with a **broadcast**.

### Example: a purchasable global boost ("server luck for everyone")

```lua
--!strict
-- ServerScriptService/Live/GlobalBoost (ModuleScript)
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local store = DataStoreService:GetDataStore("GlobalState_v1")
local KEY = "LuckBoost"
local TOPIC = "GlobalBoost"

local GlobalBoost = {}
local current = { mult = 1, endsAt = 0 }

local function apply(record: any)
	if type(record) == "table" and tonumber(record.endsAt) and tonumber(record.mult) then
		current = { mult = record.mult, endsAt = record.endsAt }
		workspace:SetAttribute("GlobalLuckMult", if os.time() < current.endsAt then current.mult else 1)
		workspace:SetAttribute("GlobalLuckEndsAt", current.endsAt)
	end
end

function GlobalBoost.multiplier(): number
	return if os.time() < current.endsAt then current.mult else 1
end

-- Called from a ProcessReceipt grant AFTER the purchase is durable (see the receipts note).
-- Extends the boost atomically: two purchases on different servers both count.
function GlobalBoost.extend(seconds: number, mult: number): boolean
	local record: any = nil
	local ok = pcall(function()
		record = store:UpdateAsync(KEY, function(old: any)
			local now = os.time()
			local base = if type(old) == "table" and tonumber(old.endsAt) and old.endsAt > now then old.endsAt else now
			return { mult = mult, endsAt = base + seconds, by = HttpService:GenerateGUID(false) }
		end)
	end)
	if not ok or not record then
		return false
	end
	apply(record)
	pcall(function()
		MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode(record)) -- nudge; may be lost
	end)
	return true
end

-- Startup: read the durable record, subscribe for nudges, and poll as a backstop.
task.spawn(function()
	local function poll()
		local ok, value = pcall(function()
			return store:GetAsync(KEY)
		end)
		if ok then
			apply(value)
		end
	end
	poll()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, message.Data)
			if ok then
				apply(decoded)
			end
		end)
	end)
	while true do
		task.wait(60 + math.random() * 30) -- jittered backstop poll: messages are best effort
		poll()
	end
end)

return GlobalBoost
```

Design points:

- **The data store is the truth; the message is a hint.** MessagingService is best effort ("delivery failures" must not be critical, per Roblox) and typically arrives in 1 to 2 seconds. A server that missed the message, or started after it, still converges through the startup read and the poll.
- **`UpdateAsync` to extend**, so concurrent purchases on different servers add up instead of overwriting each other.
- **Poll cost**: one `GetAsync` per server per 60 to 90 s on one key. At 2,000 servers that is roughly 1,500 reads per minute on that key; each read of a small value counts 1 KB against the key's 25 MB/min read throughput, fine. For much larger fleets or bigger values, Roblox's best-practices page recommends **sharding hot read keys** (`Weather_1..3`, each server picks a shard by hashing its `JobId`, writers update all copies).
- **Replicate to clients through attributes** (`workspace:SetAttribute`) so UI can show the boost and its countdown ([[Instances Attributes and Tags]]).
- Messaging limits to respect: 1 KB per message; `600 + 240 x players` sends per server per minute; `40 + 80 x servers` received per topic per minute; `20 + 8 x players` subscriptions per server ([[Cross-Server Messaging]]).

### Global counters

Many servers incrementing one key ("eggs hatched worldwide") hits the per-key write limit and the write budget. Pattern (rule of thumb):

1. Each server counts locally.
2. Every 60 s (jittered), one `IncrementAsync` per server adds its local delta to one of N shard keys (`Hatched_0..Hatched_7`, chosen by `JobId` hash), then resets the local delta. On failure, keep the delta and add it next time.
3. A reader sums the shards every few minutes (or one server does and broadcasts). Display "about" numbers.

`IncrementAsync` is atomic per key; values must be integers.

## Version gating and old servers

Live state often pairs with code changes. During a rollout, old servers run old code. Give configs and global records a `minVersion` where needed, and have code check its own build number before enabling a feature. For breaking data changes, the refusal of newer schemas ([[Data Schema Design and Migrations]]) plus "migrate to latest update" keeps old servers from misreading new data ([[Release Process and Rollbacks]]).

## Admin tools

An in-game admin panel that changes global state should write through the same paths (data store record + broadcast), check permissions on the server for every call, and log who changed what. One production game's owner-only admin panel re-checked the owner on every remote call and only touched player profiles through the profile owner's bridge; global tuning belonged in configs, where history and restore come free ([[Server Authority and Validation]], [[Session Locking and Profile Libraries]]).

## Common mistakes

| Mistake | Consequence |
|---|---|
| Every server polling a data store config key every few seconds | Read budget and per-key throughput wasted; the 4 s cache hides changes anyway |
| Relying on MessagingService alone | Servers that miss a message stay wrong forever |
| `SetAsync` for global records several servers write | Lost updates (two boosts bought, one counted) |
| No code defaults for configs | A deleted key or outage crashes gameplay |
| Refreshing balance values mid-round | Unfair fights, confusing experiment data |
| Config values used client-side by sending the whole snapshot | Leaks unreleased content flags; send only what the client needs |
| Treating staged config values as live | Works in Studio, not for players, until published |

## Checklist

- [ ] Tuning and flags in configs, with defaults in code and type checks.
- [ ] Kill switches for risky systems.
- [ ] Refresh policy decided per value (immediate vs boundary).
- [ ] Game-written global state: durable record via `UpdateAsync` + broadcast + jittered backstop poll.
- [ ] Hot read keys sharded; counters aggregated per server.
- [ ] Changes logged and reversible.

## See also
[[Cross-Server Messaging]] · [[MemoryStore Service]] · [[DataStore Fundamentals]] · [[Open Cloud APIs]] · [[Live Ops Events and Updates]] · [[Release Process and Rollbacks]] · [[Analytics and Funnels]] · [[Purchase Data and Receipts]] · [[Server Lifecycle and Shutdown]]

## Nuances and edge cases

1. **Old servers keep old code.** After you publish, existing servers keep running the previous build until they shut down. A config value that a new build understands (a new item id, a new event type) can reach old servers that do not. Every config read must tolerate unknown values, and config that depends on new code should carry a minimum build version that old servers check before applying.
2. **Freshness is a trade against cost.** Polling every few seconds gives near-instant changes and burns read budgets that scale with server count; polling every few minutes is cheap but slow. A common pattern is a slow poll (one to five minutes) plus a cross-server message as a hint to refresh early. The poll is the guarantee, the message is the optimisation.
3. **Balance values mid-session are a fairness issue.** Changing damage numbers while a round is running gives some players an advantage and confuses analytics. Apply balance changes at safe points (round start, zone change, respawn), and log the config version on every analytics event so experiments stay clean.
4. **Kill switches must default safe.** If config cannot be read at all (an outage), the system behind a kill switch should fall back to the code default you chose deliberately: off for risky new features, on for core gameplay. Write the default next to every flag, with the reason.
5. **Global counters conflict at scale.** With 5 servers, an update per purchase to a global counter is fine. With 500 servers during a promotion, the same key receives more writes than one key can handle, so writes throttle and fail. Batch per server (sum locally, flush every 30 to 60 seconds) and shard hot counters across several keys.
6. **Client-visible config leaks plans.** Sending the whole config snapshot to clients exposes unreleased items, prices and event dates to anyone who reads replicated data. Send clients only what they need, and keep secret or future values server-only.
7. **Rollback must be one action.** When a config change causes problems at peak, the fix should be reverting one value, not editing several keys under pressure. Keep config changes small and versioned, and record who changed what (see [[Feature Flags and Staged Rollouts]]).

The senior trade-off: live config turns deploys into data edits, which is faster and riskier. The more you can change without publishing, the more you need validation, versioning and an audit log of config changes.

## Common mistakes (advanced)

1. **Applying config without a version check.** Symptom: old servers error on new values right after an update. Fix: minimum build version per config section.
2. **One hot global key for a popular counter.** Symptom: throttling errors during events. Fix: per-server batching and sharded keys.
3. **No code defaults.** Symptom: an outage of the config source breaks gameplay. Fix: defaults in code for every value.
4. **Changing balance mid-round.** Symptom: unfair matches and noisy data. Fix: apply at safe points.
5. **Config edits with no record.** Symptom: nobody knows why a value changed. Fix: change log with author and reason.
6. **Unvalidated config.** Symptom: a typo (a price of 0, a drop rate of 50 instead of 0.5) ships instantly to every server. Fix: range checks on load, with fallback to the last good value.

## Related decisions

- [[Feature Flags and Staged Rollouts]]: flags built on live config.
- [[A-B Testing and Experiments on Roblox]]: config versions as experiment variants.
- [[Live Ops Events and Updates]]: scheduled events driven by config.
- [[Server Shutdowns Soft Updates and Migration]]: getting old servers off old code.
- [[Economy Resets and Seasonal Wipes]]: high-impact config changes that need care.
- [[Data and Config Pipeline - Spreadsheets to Game]]: generating validated config.
- [[Live Incident Response and Post-Mortems]]: one-step rollback during incidents.
- [[Cross-Server Messaging]]: messages as refresh hints, not truth.

## Connected notes
<!-- auto-links:start -->
[[Feature Flags]] · [[Economy Telemetry and Balancing Live]] · [[Live Ops Deep Dive Start Here]] · [[Live Content Pipeline]] · [[Links - Cross-server messaging]] · [[Codes Redemption System End to End]]
<!-- auto-links:end -->
