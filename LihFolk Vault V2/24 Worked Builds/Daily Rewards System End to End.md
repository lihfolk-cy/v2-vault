---
tags: [worked-build, daily-rewards, retention, time, remotes, ui, luau, strict, type/guide, area/gameplay, level/intermediate, area/ui]
---
# Daily Rewards System End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Comparing timestamps instead of day indexes, then debugging "claimed 23 hours 59 minutes ago".
> - Avoid: Using the client's `os.time()` or `DateTime.now()` for anything except display.
> - Avoid: Marking the day claimed before the grant can fail.
> - Day boundary is a server-side integer from UTC time with an explicit offset
> - Missed-day policy decided and written down
> - Claim takes no arguments, is rate-limited, never yields between check and mark
>
> Cost: TL;DR ~160 tok · whole note ~6.0k tok. Read more: ## 4. Server · ## 5. Client and UI · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A seven-day reward track with a streak: the player claims once per UTC day, consecutive days advance the track, a missed day resets it, and day 7 pays a bigger prize before the track loops. The server decides everything from its own clock; the client only displays state and asks to claim. This note builds it from an empty place on top of the foundation in [[Saved Inventory End to End]] (the `PlayerData`, `Net`, `RateLimiter` and `InventoryService` modules), and shows the UI, the tests, the attacks and the extensions.

All code is **reviewed, not run**: strict Luau written against the documented APIs (Roblox docs, as of October 2026) but not executed in this exact form. Test it as described in section 7 before release.

Design background lives in [[Retention and Return Hooks]] and [[Menu Archetypes - Shop Settings Codes Rewards]]. Ethics of streak pressure: [[Ethical Design and Player Trust]].

---

## 1. Decisions before code

Daily rewards look trivial and generate a surprising share of support tickets. Make these four decisions explicitly.

| Decision | Options | This build |
|---|---|---|
| What is a "day"? | Rolling 24 h from last claim; fixed reset time | Fixed reset at 00:00 UTC (configurable offset) |
| What happens on a missed day? | Reset to day 1; pause (no reset); grace of one day | Reset to day 1, with an optional grace setting |
| Calendar or streak? | Calendar (day N of the month, claim any order); streak track | Streak track of 7, loops |
| What if the bag is full? | Drop the reward; claim anyway and mail it; refuse the claim | Refuse the claim with a clear message, nothing is marked |

Why a fixed reset rather than rolling 24 hours: with a rolling window, a player who claims at 21:00 one day and 20:00 the next cannot claim, and their claim time drifts later each day until they miss one. Fixed resets are what players expect from a "daily" and make the countdown honest (rule of thumb, and the pattern used by the reference project's daily and quest resets).

Why UTC: the server has no reliable idea of the player's time zone, and every server must agree. Choose the offset so the reset lands at a quiet hour for your biggest region. A reset at 00:00 UTC is evening in the Americas, which is peak play time, so some games shift it (for example `RESET_OFFSET_HOURS = 8` puts it at 08:00 UTC).

Why refuse on a full bag: if you mark the day claimed and the grant fails, the player lost a reward. If you grant partly, support cannot tell what happened. Refusing keeps the rule "either everything happened or nothing did", and the player can free space and claim.

---

## 2. Folder layout (additions)

```
ReplicatedStorage
  Shared
    DailyRewardConfig (ModuleScript)     -- new
ServerScriptService
  Server
    Services
      DailyRewardService (ModuleScript)  -- new
StarterPlayer
  StarterPlayerScripts
    Client
      DailyRewardController (LocalScript) -- new
```

The profile fields `Daily = { LastClaimDay = -1, Streak = 0 }` already exist in `DataTemplate` from the foundation build. `Main` already lists `DailyRewardService` in its start order, so nothing else changes.

---

## 3. Config

```lua
--!strict
-- ReplicatedStorage/Shared/DailyRewardConfig (ModuleScript). Reviewed, not run.
export type Reward = {
	Kind: "Coins" | "Item",
	Amount: number, -- coins, or item count
	ItemId: string?, -- Item rewards only
	Label: string,
}

local DailyRewardConfig = {}

DailyRewardConfig.ResetOffsetHours = 0 -- 0 = reset at 00:00 UTC
DailyRewardConfig.GraceDays = 0 -- 0 = one missed day resets; 1 = one missed day is forgiven

DailyRewardConfig.Track = {
	{ Kind = "Coins", Amount = 100, Label = "100 Coins" },
	{ Kind = "Coins", Amount = 150, Label = "150 Coins" },
	{ Kind = "Item", Amount = 5, ItemId = "Apple", Label = "5 Apples" },
	{ Kind = "Coins", Amount = 250, Label = "250 Coins" },
	{ Kind = "Item", Amount = 10, ItemId = "IronOre", Label = "10 Iron Ore" },
	{ Kind = "Coins", Amount = 400, Label = "400 Coins" },
	{ Kind = "Item", Amount = 1, ItemId = "IronSword", Label = "Iron Sword" },
} :: { Reward }

return DailyRewardConfig
```

The config is shared because the client draws the track from it. Nothing in it is secret, and the server uses only its own copy to decide what to grant.

Sizing the track is economy work, not UI work: seven days of rewards should be worth roughly one to two days of normal play income for a returning player, enough to notice and not enough to make playing optional. Run the numbers in [[Economy Inflation Sinks and Faucets Math]] before you pick them (rule of thumb).

---

## 4. Server

### 4.1 The day maths

```lua
local SECONDS_PER_DAY = 86_400

local function dayIndex(unixTime: number): number
	return math.floor((unixTime - Config.ResetOffsetHours * 3600) / SECONDS_PER_DAY)
end
```

`os.time()` on a Roblox server returns UTC seconds since the Unix epoch (Roblox docs). `dayIndex` turns that into an integer that changes exactly once per day at the reset time. Storing the integer instead of a timestamp makes every comparison exact: "claimed today" is `LastClaimDay == today`, "claimed yesterday" is `LastClaimDay == today - 1`. No daylight saving, no time zones, no floating point edges.

### 4.2 The streak rule as a pure function

Keeping the rule pure (no data store, no players) makes it testable in isolation and easy to change ([[Automated Testing with TestEZ and Jest-Lua]]).

```lua
-- Given saved state and today, what is the state of the track?
type TrackState = {
	CanClaim: boolean,
	Slot: number, -- 1..7: the slot that is (or would be) claimed today
	StreakIfClaimed: number,
	Streak: number, -- streak as it stands now, for display
}

local function evaluate(lastClaimDay: number, streak: number, today: number): TrackState
	local trackLength = #Config.Track
	if lastClaimDay >= today then
		-- Claimed today. (lastClaimDay > today only happens with clock skew or a test offset:
		-- treat it as claimed rather than granting again.)
		local shown = math.max(streak, 1)
		return { CanClaim = false, Slot = ((shown - 1) % trackLength) + 1, StreakIfClaimed = shown, Streak = shown }
	end
	local gap = today - lastClaimDay -- 1 = consecutive day
	local continues = lastClaimDay >= 0 and gap <= 1 + Config.GraceDays
	local nextStreak = if continues then streak + 1 else 1
	return {
		CanClaim = true,
		Slot = ((nextStreak - 1) % trackLength) + 1,
		StreakIfClaimed = nextStreak,
		Streak = if continues then streak else 0,
	}
end
```

Edge cases this handles:

| Case | Result |
|---|---|
| Brand-new player (`LastClaimDay = -1`) | Can claim slot 1 |
| Claimed yesterday | Can claim the next slot |
| Claimed two days ago, `GraceDays = 0` | Track restarts at slot 1 |
| Claimed two days ago, `GraceDays = 1` | Streak continues |
| Day 7 claimed yesterday | Slot 1 again, streak keeps counting (8, 9...) for badges or stats |
| Server clock behind the one that saved the claim | Treated as already claimed |

### 4.3 DailyRewardService

```lua
--!strict
-- ServerScriptService/Server/Services/DailyRewardService (ModuleScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.DailyRewardConfig)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)

local SECONDS_PER_DAY = 86_400
local IS_STUDIO = RunService:IsStudio()

type TrackState = { CanClaim: boolean, Slot: number, StreakIfClaimed: number, Streak: number }

local DailyRewardService = {}

local stateEvent: RemoteEvent
local claimFunction: RemoteFunction
local allowClaim = RateLimiter.new(3, 0.5)

local function now(): number
	local t = os.time()
	if IS_STUDIO then
		-- Studio-only time travel for testing: ServerStorage attribute DailyDayOffset = 1 is "tomorrow".
		local offset = ServerStorage:GetAttribute("DailyDayOffset")
		if type(offset) == "number" then
			t += math.floor(offset) * SECONDS_PER_DAY
		end
	end
	return t
end

local function dayIndex(unixTime: number): number
	return math.floor((unixTime - Config.ResetOffsetHours * 3600) / SECONDS_PER_DAY)
end

local function nextResetUnix(unixTime: number): number
	return (dayIndex(unixTime) + 1) * SECONDS_PER_DAY + Config.ResetOffsetHours * 3600
end

local function evaluate(lastClaimDay: number, streak: number, today: number): TrackState
	local trackLength = #Config.Track
	if lastClaimDay >= today then
		local shown = math.max(streak, 1)
		return { CanClaim = false, Slot = ((shown - 1) % trackLength) + 1, StreakIfClaimed = shown, Streak = shown }
	end
	local gap = today - lastClaimDay
	local continues = lastClaimDay >= 0 and gap <= 1 + Config.GraceDays
	local nextStreak = if continues then streak + 1 else 1
	return {
		CanClaim = true,
		Slot = ((nextStreak - 1) % trackLength) + 1,
		StreakIfClaimed = nextStreak,
		Streak = if continues then streak else 0,
	}
end
DailyRewardService.Evaluate = evaluate -- exposed for unit tests

local function pushState(player: Player)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local t = now()
	local state = evaluate(profile.Data.Daily.LastClaimDay, profile.Data.Daily.Streak, dayIndex(t))
	stateEvent:FireClient(player, {
		CanClaim = state.CanClaim,
		Slot = state.Slot,
		Streak = state.Streak,
		-- Absolute server time of the next reset; the client counts down with GetServerTimeNow.
		NextReset = nextResetUnix(t) - (t - os.time()), -- undo the Studio offset for the countdown
	})
end

type ClaimResult = { Ok: boolean, Error: string?, Slot: number? }

local function claim(player: Player): ClaimResult
	if not allowClaim(player) then
		return { Ok = false, Error = "TooFast" }
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return { Ok = false, Error = "NotReady" }
	end
	local daily = profile.Data.Daily
	local today = dayIndex(now())
	local state = evaluate(daily.LastClaimDay, daily.Streak, today)
	if not state.CanClaim then
		return { Ok = false, Error = "AlreadyClaimed" }
	end

	local reward = Config.Track[state.Slot]
	-- Grant first: InventoryService calls are synchronous and all-or-nothing.
	-- If the grant fails, nothing has been marked and the player can retry.
	if reward.Kind == "Coins" then
		if not InventoryService.AddCoins(player, reward.Amount) then
			return { Ok = false, Error = "GrantFailed" }
		end
	else
		local itemId = reward.ItemId
		if not itemId then
			return { Ok = false, Error = "BadConfig" }
		end
		local ok, err = InventoryService.Add(player, itemId, reward.Amount)
		if not ok then
			return { Ok = false, Error = if err == "StackFull" or err == "InventoryFull" then "BagFull" else "GrantFailed" }
		end
	end
	-- Same synchronous block as the grant: no yield between grant and mark.
	daily.LastClaimDay = today
	daily.Streak = state.StreakIfClaimed

	pushState(player)
	return { Ok = true, Slot = state.Slot }
end

function DailyRewardService.Start()
	stateEvent = Net.Event("DailyRewardState")
	claimFunction = Net.Function("DailyRewardClaim")

	claimFunction.OnServerInvoke = function(player: Player): ClaimResult
		local ok, result = pcall(claim, player)
		if not ok then
			warn(`[DailyReward] claim error for {player.UserId}: {result}`)
			return { Ok = false, Error = "ServerError" }
		end
		return result
	end

	Net.Event("DailyRewardHello").OnServerEvent:Connect(pushState)
	PlayerData.OnLoaded(function(profile)
		pushState(profile.Player)
	end)

	-- Day rollover: players who stay online past the reset get a fresh state.
	task.spawn(function()
		local lastDay = dayIndex(now())
		while true do
			task.wait(15)
			local today = dayIndex(now())
			if today ~= lastDay then
				lastDay = today
				for _, player in Players:GetPlayers() do
					pushState(player)
				end
			end
		end
	end)
end

return DailyRewardService
```

Why no `SaveNowAsync` after a claim? Grant and mark live in the same profile and are saved by the same write. If the server crashes before the next autosave, both are lost together: the player simply claims again on another server. Consistent loss is acceptable; inconsistent loss (marked but not granted) is not. Forcing a save per claim would also spend write budget on the busiest moment of the day, the minutes after reset ([[Saving Correctly - Autosave and BindToClose]]).

Why the client does not send the slot: if it did, an exploiter could ask for slot 7 every day. The request carries nothing; the server works out what today's reward is.

---

## 5. Client and UI

The countdown uses `workspace:GetServerTimeNow()`, which returns the server's clock as estimated by the client (Roblox docs). The player's own device clock is never used: it can be wrong by hours, and players change it on purpose to cheat single-player games. Here changing it changes nothing but the label.

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/DailyRewardController (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.DailyRewardConfig)

local player = Players.LocalPlayer
local stateEvent = Net.Event("DailyRewardState")
local claimFunction = Net.Function("DailyRewardClaim")

type State = { CanClaim: boolean, Slot: number, Streak: number, NextReset: number }

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local gui = make("ScreenGui", { Name = "DailyRewards", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local openButton = make("TextButton", {
	Text = "Daily", Size = UDim2.fromOffset(80, 40), Position = UDim2.new(0, 12, 0.5, -70),
}, gui)
local badge = make("Frame", {
	Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -7, 0, -7), Visible = false,
	BackgroundColor3 = Color3.fromRGB(230, 60, 60),
}, openButton)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)

local window = make("Frame", {
	Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.7, 0.4),
}, gui)
make("UIAspectRatioConstraint", { AspectRatio = 2.6 }, window)
local row = make("Frame", { Size = UDim2.new(1, -16, 0.6, 0), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1 }, window)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, row)
local claimButton = make("TextButton", { Text = "...", Size = UDim2.new(0.5, 0, 0.25, 0), Position = UDim2.new(0.25, 0, 0.7, 0) }, window)

local tiles: { TextLabel } = {}
for i, reward in Config.Track do
	tiles[i] = make("TextLabel", {
		LayoutOrder = i,
		Size = UDim2.new(1 / #Config.Track, -6, 1, 0),
		Text = `Day {i}\n{reward.Label}`,
		TextWrapped = true,
	}, row)
end

local state: State? = nil
local claiming = false

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function render()
	local s = state
	if not s then
		return
	end
	-- The three tile states: claimed (done), today (claimable or just claimed), locked (future).
	for i, tile in tiles do
		local claimedEarlier = i < s.Slot or (i == s.Slot and not s.CanClaim)
		tile.BackgroundColor3 = if claimedEarlier
			then Color3.fromRGB(90, 160, 90)
			elseif i == s.Slot then Color3.fromRGB(240, 200, 60)
			else Color3.fromRGB(120, 120, 120)
	end
	badge.Visible = s.CanClaim
	claimButton.Active = s.CanClaim and not claiming
	claimButton.AutoButtonColor = s.CanClaim
	if s.CanClaim then
		claimButton.Text = if claiming then "Claiming..." else "Claim"
	end
end

claimButton.Activated:Connect(function()
	local s = state
	if not s or not s.CanClaim or claiming then
		return
	end
	claiming = true
	render()
	local ok, result = pcall(function()
		return claimFunction:InvokeServer()
	end)
	claiming = false
	if not ok or type(result) ~= "table" or not result.Ok then
		local err = if ok and type(result) == "table" then result.Error else "Network"
		claimButton.Text = if err == "BagFull" then "Bag full: make space" else "Try again"
		task.delay(2, render)
	end
	-- On success the server pushes a new state.
end)

openButton.Activated:Connect(function()
	window.Visible = not window.Visible
end)

stateEvent.OnClientEvent:Connect(function(newState: State)
	state = newState
	render()
	if newState.CanClaim then
		window.Visible = true -- open once per claimable day, on join or at reset
	end
end)

-- Countdown text when nothing is claimable.
task.spawn(function()
	while true do
		local s = state
		if s and not s.CanClaim then
			claimButton.Text = `Next reward in {formatDuration(s.NextReset - workspace:GetServerTimeNow())}`
		end
		task.wait(1)
	end
end)

Net.Event("DailyRewardHello"):FireServer()
```

UI notes:

- **Auto-open once.** Popping the window on join when a claim is ready is the single largest factor in whether players claim at all (rule of thumb, and consistent with the reference project's experience of rewards nobody found). Do not auto-open again on every respawn; `ResetOnSpawn = false` plus opening only on a state push does this.
- **Countdown hits zero before the push arrives.** The rollover loop checks every 15 seconds, so the label can sit at 00:00:00 for a few seconds. Clamp to zero (done) and accept it, or shorten the loop.
- **Mobile.** Seven tiles across a phone is cramped. On narrow screens show three tiles (yesterday, today, tomorrow) or let the row scroll ([[Responsive UI for Phone Tablet Console and PC]]).

---

## 6. Variants

| Variant | Change |
|---|---|
| Monthly calendar | Store a `ClaimedDays` bitmask per month instead of a streak; slot = number of claims this month + 1 |
| Playtime gifts (claim after 5, 15, 30 min in this session) | Server stores session start in memory, not in the profile; validate elapsed time on the server ([[Menu Archetypes - Shop Settings Codes Rewards]]) |
| Streak repair for Robux | Technically easy via a developer product; ethically delicate. If you sell it, keep it cheap, optional and never advertise the loss aggressively ([[Ethical Design and Player Trust]]) |
| Pass doubles rewards | Multiply `Amount` in `claim` when the player owns the pass ([[Shop with Game Passes and Developer Products End to End]]) |
| Group bonus | `player:IsInGroupAsync` yields: call it on join, cache the result in an attribute, read the attribute in `claim` so the claim never yields |

The last row is a pattern worth generalising: anything that requires a web call (group membership, pass ownership, badges) is fetched before the claim and cached. A claim path that yields is a claim path that can interleave with itself.

---

## 7. Testing in Studio

1. Play. The window opens with day 1 highlighted. Claim: coins rise, the tile turns green, the countdown starts.
2. Click Claim again quickly or fire the remote from a test script: `AlreadyClaimed` and `TooFast`, no extra coins.
3. **Time travel.** With the game running, set `ServerStorage` attribute `DailyDayOffset` to `1` (server view). Within 15 seconds the state flips to claimable, day 2. Claim. Set it to `2`: day 3, claim it. Now set it to `4`, skipping offset 3: the gap since the last claim is two days, so the track resets to day 1 (or continues, if `GraceDays = 1`).
4. **Backwards clock.** Claim at offset 5, then set the offset to 3. The state must show claimed, never claimable. This simulates a server whose clock is behind the server that saved your claim.
5. **Full bag.** Use the command bar to fill `Apple` to 999, move to the Apple day and claim: "Bag full", day not marked, coins unchanged.
6. **Persistence.** Claim, Stop, Play: still claimed today. Remember Studio saves are on `STUDIO_` keys ([[Saved Inventory End to End]]).
7. **Unit tests.** Call `DailyRewardService.Evaluate(-1, 0, 100)` and friends from a test runner and assert the table above.

Clear `DailyDayOffset` when done. It is read only in Studio, so a forgotten value cannot reach live servers, but it will confuse your next test.

---

## 8. Exploits it must resist

| Attack | Defence |
|---|---|
| Change device clock to claim again | Server time only; the client clock is not read |
| Ask for a better slot | The request has no arguments |
| Spam the remote around reset to claim twice | Rate limit, and the claim is synchronous: the second call sees `LastClaimDay == today` |
| Claim on two servers at once | Session lock: only one server owns the profile ([[Session Locking and Profile Libraries]]) |
| Rejoin repeatedly to reroll a random reward | No randomness here. If you add random rewards, roll and store the result when the day begins, not at claim time |
| Claim with a full bag, then sell to make space mid-claim | Claim never yields, so the inventory cannot change between check and grant |

---

## 9. Extending it

- **Notifications.** Pair the auto-open with a toast when a reward becomes available mid-session ([[Notification and Toast Systems]]).
- **Analytics.** Log claim day, slot and streak as custom events so you can see where streaks break ([[Analytics and Funnels]]).
- **Live tuning.** Move `Track` into live config so rewards can change without a shutdown ([[Global State and Live Config]]).
- **Return pushes.** Experience notifications can remind opted-in players that a reward is waiting; check the current eligibility and opt-in rules first (Roblox docs, as of October 2026, unverified in detail here).

## Common mistakes

- Comparing timestamps instead of day indexes, then debugging "claimed 23 hours 59 minutes ago".
- Using the client's `os.time()` or `DateTime.now()` for anything except display.
- Marking the day claimed before the grant can fail.
- Re-opening the window on every respawn: players learn to close it without reading.
- Forgetting players who are online across the reset: they see "claimed" until they rejoin.

## Checklist

- [ ] Day boundary is a server-side integer from UTC time with an explicit offset
- [ ] Missed-day policy decided and written down
- [ ] Claim takes no arguments, is rate-limited, never yields between check and mark
- [ ] Grant failure leaves the day unclaimed
- [ ] Countdown uses `GetServerTimeNow`
- [ ] Rollover pushes state to online players
- [ ] Tested with `DailyDayOffset` forwards, backwards and across a gap

## See also

[[Worked Builds Start Here]] | [[Saved Inventory End to End]] | [[Retention and Return Hooks]] | [[Menu Archetypes - Shop Settings Codes Rewards]] | [[Codes Redemption System End to End]] | [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Live Ops Events and Updates]] · Skill - Roblox System Builder · Cookbook - Tables Strings and Time · Battle Pass and Season Design · Event Calendars and Content Planning · Idempotency
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Testing Time-Based Features with a Controllable Clock]] · [[Global Leaderboards End to End]] · [[LihFolk Systems Library]] · [[Rebirth and Prestige System End to End]] · [[Quest Chain System End to End]] · [[Round-Based Minigame Loop End to End]] · [[LihFolk Systems - Data and Purchase Guarantees]] · [[Pet Hatching and Following End to End]]
<!-- related:end -->
