---
tags: [worked-build, codes, live-ops, rate-limiting, datastore, remotes, ui, luau, strict]
---
# Codes Redemption System End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Codes in `ReplicatedStorage`.
> - Avoid: Case-sensitive matching: half the support tickets about codes are "it says invalid" for `Welcome`.
> - Avoid: Telling the player "not active yet": it confirms an unreleased code.
> - Code list server-only; live list validated
> - Input normalised (case, whitespace, length, characters)
> - Rate limit plus failure lockout
>
> Read more (27 KB note): ## 4. Server · ## 5. Client and UI · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A codes box from an empty place: the player types a code, the server normalises it, checks it against a server-only list plus live codes you can add without a shutdown, enforces expiry, eligibility, per-player single use and an optional global use limit, grants the reward, and answers with a clear message. Wrong guesses are rate-limited and locked out so the box cannot be used to brute-force unreleased codes. It sits on the foundation from [[Saved Inventory End to End]] (`PlayerData`, `Net`, `RateLimiter`, `InventoryService`); the profile already has a `RedeemedCodes` map.

All code is **reviewed, not run**: strict Luau written against the documented APIs (Roblox docs, as of October 2026), not executed in this exact form. Test it as section 7 describes.

UI anatomy of a codes panel is covered in [[Menu Archetypes - Shop Settings Codes Rewards]]; codes as a live-ops tool in [[Live Ops Events and Updates]] and [[Global State and Live Config]].

---

## 1. What codes are for, and what they cost

Codes are a cheap marketing hook: a creator video, a launch, a milestone ("50k likes: code LIKES50"). They are also an economy faucet with no gameplay attached, and every code you publish leaks to code-list sites within hours (rule of thumb). Two consequences:

- **Size rewards as if every player will redeem every code.** A code worth an hour of play is a nice thank-you. A code worth a week of play devalues the progression you spent months tuning ([[Economy Inflation Sinks and Faucets Math]]).
- **Never put a secret in a code that only "insiders" should know.** Tester or creator codes must also check *who* is redeeming (user id or group rank), not just *what* they typed.

---

## 2. Folder layout (additions)

```
ServerStorage
  CodeList (ModuleScript)               -- new; server-only, clients cannot read it
ServerScriptService
  Server
    Services
      CodeService (ModuleScript)        -- new
StarterPlayer
  StarterPlayerScripts
    Client
      CodesController (LocalScript)     -- new
```

The code list is in `ServerStorage` on purpose. Anything in `ReplicatedStorage` (or anywhere a client can see) is readable by exploiters, and a code list there is a public code list ([[How Exploits Work - The Client Boundary]]).

---

## 3. The code list

```lua
--!strict
-- ServerStorage/CodeList (ModuleScript). Reviewed, not run.
export type CodeReward = { Coins: number, Items: { { ItemId: string, Count: number } }? }
export type CodeDef = {
	Code: string, -- uppercase letters and digits only
	Reward: CodeReward,
	ExpiresAt: number?, -- unix seconds (UTC); nil = never
	StartsAt: number?, -- unix seconds (UTC); nil = immediately
	GlobalLimit: number?, -- total redemptions across all servers; nil = unlimited
	NewPlayersOnly: boolean?, -- only accounts that had no RedeemedCodes before (example rule)
	AllowedUserIds: { number }?, -- tester or creator codes
	StudioOnly: boolean?,
}

local function utc(y: number, mo: number, d: number, h: number?): number
	return DateTime.fromUniversalTime(y, mo, d, h or 0, 0, 0).UnixTimestamp
end

return {
	{ Code = "WELCOME", Reward = { Coins = 250 } },
	{ Code = "LAUNCH2026", Reward = { Coins = 500, Items = { { ItemId = "Apple", Count = 10 } } }, ExpiresAt = utc(2026, 12, 31, 23) },
	{ Code = "FIRST1000", Reward = { Coins = 1000 }, GlobalLimit = 1000 },
	{ Code = "TESTCODE", Reward = { Coins = 1 }, StudioOnly = true },
} :: { CodeDef }
```

`DateTime.fromUniversalTime` builds the timestamp from a UTC date, so "expires end of December" is written as a date instead of a magic number (Roblox docs). Code expiry is evaluated against the server's `os.time()`, which is UTC.

### Live codes

Shipping a new code by editing `CodeList` means publishing an update and, for running servers, a shutdown or migration. Live codes avoid that: the server also reads a list from a data store key and refreshes it every five minutes. You add a code by writing that key (Studio command bar, or Open Cloud from a small tool: [[Open Cloud APIs]]).

Important nuance: Studio's data store calls go to the **same** stores as the live game of that universe (Roblox docs). Writing `LiveCodes_v1` from Studio publishes the code to live servers within five minutes. That is the feature, and also the trap: a test code written this way is a real code. Use `StudioOnly = true` for anything experimental.

---

## 4. Server

### 4.1 Normalisation

Players type codes on phones with autocorrect, capitals and trailing spaces. Normalise before anything else:

```lua
local function normalise(raw: any): string?
	if type(raw) ~= "string" or #raw > 64 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if #code < 3 or #code > 24 or not string.match(code, "^%w+$") then
		return nil
	end
	return code
end
```

`%w` matches letters and digits only, so emoji, punctuation and lookalike characters are rejected rather than half-matched. Length is checked on the raw string **before** `gsub` so a megabyte of whitespace costs nothing.

### 4.2 CodeService

```lua
--!strict
-- ServerScriptService/Server/Services/CodeService (ModuleScript). Reviewed, not run.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local CodeList = require(ServerStorage.CodeList)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)

type CodeDef = CodeList.CodeDef

local LIVE_REFRESH_SECONDS = 300
local MAX_FAILURES = 8 -- wrong codes per lockout window
local LOCKOUT_SECONDS = 300
local IS_STUDIO = RunService:IsStudio()

local liveStore = DataStoreService:GetDataStore("LiveCodes_v1")
local usesStore = DataStoreService:GetDataStore("CodeUses_v1")

local CodeService = {}

local staticCodes: { [string]: CodeDef } = {}
local liveCodes: { [string]: CodeDef } = {}
local allowAttempt = RateLimiter.new(5, 5 / 60) -- burst 5, then 5 per minute
local failures: { [Player]: { Count: number, WindowStart: number } } = {}
local redeeming: { [Player]: boolean } = {}

for _, def in CodeList do
	staticCodes[def.Code] = def
end

local function normalise(raw: any): string?
	if type(raw) ~= "string" or #raw > 64 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if #code < 3 or #code > 24 or not string.match(code, "^%w+$") then
		return nil
	end
	return code
end

-- Validate a live entry: data store content is input too.
local function parseLive(entry: any): CodeDef?
	if type(entry) ~= "table" or type(entry.Reward) ~= "table" then
		return nil
	end
	local code = normalise(entry.Code)
	local coins = entry.Reward.Coins
	if not code or type(coins) ~= "number" or coins < 0 or coins > 1_000_000 or math.floor(coins) ~= coins then
		return nil
	end
	return {
		Code = code,
		Reward = { Coins = coins }, -- live codes grant coins only: items need catalog validation
		ExpiresAt = if type(entry.ExpiresAt) == "number" then entry.ExpiresAt else nil,
		StartsAt = if type(entry.StartsAt) == "number" then entry.StartsAt else nil,
		GlobalLimit = if type(entry.GlobalLimit) == "number" then entry.GlobalLimit else nil,
	}
end

local function refreshLiveCodes()
	local ok, value = pcall(function()
		return liveStore:GetAsync("codes")
	end)
	if not ok then
		warn(`[Codes] live refresh failed: {value}`) -- keep the previous list
		return
	end
	local fresh: { [string]: CodeDef } = {}
	if type(value) == "table" then
		for _, entry in value do
			local def = parseLive(entry)
			if def then
				fresh[def.Code] = def
			end
		end
	end
	liveCodes = fresh
end

local function lookup(code: string): CodeDef?
	return staticCodes[code] or liveCodes[code]
end

local function isLockedOut(player: Player): boolean
	local f = failures[player]
	if not f then
		return false
	end
	if os.clock() - f.WindowStart > LOCKOUT_SECONDS then
		failures[player] = nil
		return false
	end
	return f.Count >= MAX_FAILURES
end

local function recordFailure(player: Player)
	local f = failures[player]
	if not f then
		failures[player] = { Count = 1, WindowStart = os.clock() }
	else
		f.Count += 1
	end
end

-- Global limit: reserve one use. Yields. Returns true if a slot was reserved.
local function reserveGlobalUse(def: CodeDef): boolean?
	local limit = def.GlobalLimit
	if not limit then
		return true
	end
	local reserved = false
	local ok, err = pcall(function()
		usesStore:UpdateAsync(def.Code, function(old: any): any
			local uses = if type(old) == "number" then old else 0
			if uses >= limit then
				reserved = false
				return nil -- cancel: limit reached
			end
			reserved = true
			return uses + 1
		end)
	end)
	if not ok then
		warn(`[Codes] reserve {def.Code} failed: {err}`)
		return nil -- unknown
	end
	return reserved
end

local function releaseGlobalUse(def: CodeDef)
	if not def.GlobalLimit then
		return
	end
	task.spawn(pcall, function()
		usesStore:UpdateAsync(def.Code, function(old: any): any
			if type(old) == "number" and old > 0 then
				return old - 1
			end
			return nil
		end)
	end)
end

local function grant(player: Player, reward: CodeList.CodeReward): (boolean, string?)
	-- Items first (they can fail); coins last (they cannot, once the profile is active).
	local added: { { ItemId: string, Count: number } } = {}
	if reward.Items then
		for _, entry in reward.Items do
			local ok, err = InventoryService.Add(player, entry.ItemId, entry.Count)
			if not ok then
				-- Roll back items added so far (synchronous, so nothing else interleaved).
				-- This rollback handles stack items only: keep code rewards to stackables,
				-- or put a unique item last in the list so it is never rolled back.
				local profile = PlayerData.Get(player)
				if profile then
					for _, done in added do
						local stacks = profile.Data.Inventory.Stacks
						local left = (stacks[done.ItemId] or 0) - done.Count
						stacks[done.ItemId] = if left > 0 then left else nil
					end
				end
				return false, err
			end
			table.insert(added, entry)
		end
	end
	if reward.Coins > 0 then
		InventoryService.AddCoins(player, reward.Coins)
	end
	return true, nil
end

type Result = { Ok: boolean, Message: string }

local function redeem(player: Player, raw: any): Result
	if not allowAttempt(player) then
		return { Ok = false, Message = "Slow down and try again in a moment." }
	end
	if isLockedOut(player) then
		return { Ok = false, Message = "Too many wrong codes. Try again in a few minutes." }
	end
	local code = normalise(raw)
	local def = if code then lookup(code) else nil
	if not code or not def or (def.StudioOnly and not IS_STUDIO) then
		recordFailure(player)
		return { Ok = false, Message = "That code does not exist." }
	end

	local profile = PlayerData.Get(player)
	if not profile then
		return { Ok = false, Message = "Your data is still loading." }
	end
	local now = os.time()
	if def.StartsAt and now < def.StartsAt then
		recordFailure(player) -- an unreleased code behaves exactly like an unknown one
		return { Ok = false, Message = "That code does not exist." }
	end
	if def.ExpiresAt and now > def.ExpiresAt then
		return { Ok = false, Message = "That code has expired." }
	end
	if profile.Data.RedeemedCodes[code] then
		return { Ok = false, Message = "You already used that code." }
	end
	if def.AllowedUserIds and not table.find(def.AllowedUserIds, player.UserId) then
		return { Ok = false, Message = "That code does not exist." }
	end
	if def.NewPlayersOnly and next(profile.Data.RedeemedCodes) ~= nil then
		return { Ok = false, Message = "That code is for new players only." }
	end

	-- Global limit: the only yield in this function. Re-check everything after it.
	local reserved = reserveGlobalUse(def)
	if reserved == nil then
		return { Ok = false, Message = "Could not check that code right now. Try again soon." }
	elseif reserved == false then
		return { Ok = false, Message = "That code has run out." }
	end
	profile = PlayerData.Get(player)
	if not profile or profile.Data.RedeemedCodes[code] then
		releaseGlobalUse(def)
		return { Ok = false, Message = "You already used that code." }
	end

	-- Grant and mark in one synchronous block.
	local ok, err = grant(player, def.Reward)
	if not ok then
		releaseGlobalUse(def)
		return { Ok = false, Message = if err == "StackFull" or err == "InventoryFull"
			then "Your bag is full. Make space and try again."
			else "Something went wrong. Try again." }
	end
	profile.Data.RedeemedCodes[code] = now
	return { Ok = true, Message = `Code redeemed! +{def.Reward.Coins} coins` }
end

function CodeService.Start()
	local redeemFunction = Net.Function("RedeemCode")
	redeemFunction.OnServerInvoke = function(player: Player, raw: any): Result
		if redeeming[player] then
			return { Ok = false, Message = "Already redeeming..." }
		end
		redeeming[player] = true
		local ok, result = pcall(redeem, player, raw)
		redeeming[player] = nil
		if not ok then
			warn(`[Codes] error for {player.UserId}: {result}`)
			return { Ok = false, Message = "Something went wrong. Try again." }
		end
		return result
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		failures[player] = nil
		redeeming[player] = nil
	end)

	task.spawn(function()
		while true do
			refreshLiveCodes()
			task.wait(LIVE_REFRESH_SECONDS)
		end
	end)
end

return CodeService
```

Why it is shaped like this:

- **The `redeeming` guard.** `reserveGlobalUse` yields. Without the guard, two quick requests for the same code could both pass the "already used" check before either marks it, and both consume a global slot. The guard serialises one player's redemptions; the re-check after the yield covers anything else.
- **Unreleased, unknown and not-allowed codes give the same message.** Different messages ("not yet active", "not for you") confirm that a guessed code exists. Expired and already-used codes can say so, because the player clearly knew the code.
- **Failure lockout on top of the rate limit.** The bucket allows 5 attempts per minute; the lockout caps wrong guesses at 8 per five minutes per session. Server hopping resets in-memory counters, so keep codes long enough that guessing is hopeless anyway: a random 8-character code from 36 symbols has about 2.8 x 10^12 possibilities (arithmetic). Short, memorable codes are fine for public codes, which are not secret.
- **Global limits reserve, then grant, then release on failure.** A crash between reserve and save loses one slot. That under-delivers by one, which is acceptable; over-delivering a "first 1000" code is not. The release is best-effort. If exact counts matter for a prize, see [[MemoryStore Service]] for a stricter design, and note that `UpdateAsync` on one key across many servers is bounded by the per-key throughput limits ([[DataStore Fundamentals]]): a code that thousands redeem in the same minute will throttle. For big launches, prefer unlimited codes with an expiry.
- **Live codes grant coins only.** Item rewards from a data store would need full catalog validation, and a typo in a live entry should not be able to grant something that does not exist. Put item codes in `CodeList`.
- **Rollback in `grant`.** Items are added one by one; if the third does not fit, the first two are removed again before returning. All of it is synchronous, so no other request can observe the half state.

### Text filtering

The typed code is never shown to any other player, so it does not need `TextService` filtering (rule of thumb, consistent with the filtering guidance that applies to text displayed to others). If you ever log codes into a place other players can see (a "recently redeemed" feed), filter first ([[Text Fonts and Rich Text]]).

---

## 5. Client and UI

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/Client/CodesController (LocalScript). Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local redeemFunction = Net.Function("RedeemCode")

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local gui = make("ScreenGui", { Name = "Codes", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local openButton = make("TextButton", { Text = "Codes", Size = UDim2.fromOffset(80, 40), Position = UDim2.new(0, 12, 0.5, 70) }, gui)
local window = make("Frame", {
	Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 180),
}, gui)
local box = make("TextBox", {
	PlaceholderText = "Enter code", Text = "", ClearTextOnFocus = false,
	Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 12),
}, window)
local redeemButton = make("TextButton", { Text = "Redeem", Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 64) }, window)
local message = make("TextLabel", {
	Text = "", BackgroundTransparency = 1, TextWrapped = true,
	Size = UDim2.new(1, -24, 0, 50), Position = UDim2.fromOffset(12, 116),
}, window)

local busy = false

local function submit()
	if busy then
		return
	end
	local text = box.Text
	if #text == 0 then
		return
	end
	busy = true
	redeemButton.Text = "..."
	local ok, result = pcall(function()
		return redeemFunction:InvokeServer(string.sub(text, 1, 64))
	end)
	busy = false
	redeemButton.Text = "Redeem"
	if ok and type(result) == "table" and type(result.Message) == "string" then
		message.Text = result.Message
		message.TextColor3 = if result.Ok then Color3.fromRGB(60, 170, 80) else Color3.fromRGB(210, 70, 70)
		if result.Ok then
			box.Text = ""
		end
	else
		message.Text = "Connection problem. Try again."
	end
end

redeemButton.Activated:Connect(submit)
box.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		submit()
	end
end)
openButton.Activated:Connect(function()
	window.Visible = not window.Visible
	message.Text = ""
end)
```

UI details:

- `ClearTextOnFocus = false`, so a player correcting one letter does not retype the whole code.
- Keep the typed text after a failure, clear it after success.
- Placeholder text is localised automatically; typed text is not captured for translation (Roblox docs, via [[Localization]]). Server messages here are English strings; for a localised game, return a message key and translate on the client.
- On console, the TextBox opens the on-screen keyboard; make sure the box is reachable with gamepad selection ([[Gamepad and Console UX]]).

---

## 6. Adding a live code

From the Studio command bar (this writes to the live store of the universe, see section 3):

```lua
local store = game:GetService("DataStoreService"):GetDataStore("LiveCodes_v1")
store:UpdateAsync("codes", function(old)
	local list = if type(old) == "table" then old else {}
	table.insert(list, {
		Code = "LIKES50",
		Reward = { Coins = 300 },
		ExpiresAt = DateTime.fromUniversalTime(2026, 11, 30, 23, 0, 0).UnixTimestamp,
	})
	return list
end)
```

Use `UpdateAsync`, not `GetAsync` then `SetAsync`, so two people adding codes at once do not erase each other's entries. Remove expired entries now and then; the list is re-read by every server every five minutes, so keep it small (a few dozen entries, rule of thumb).

---

## 7. Testing in Studio

1. Play, open Codes, type `welcome ` (lowercase, trailing space): redeemed, 250 coins.
2. Type it again: "You already used that code."
3. Type `TESTCODE`: works in Studio only. On a live server it says the code does not exist.
4. Type nine random codes quickly: rate limit message first, then the lockout message.
5. Fill the bag (command bar, `InventoryService.Add` Apples to 999) and redeem `LAUNCH2026`: "Your bag is full", no coins added, code not marked. Make space and redeem again.
6. Set a code's `ExpiresAt` to a past date: "expired".
7. **Global limit.** Give `TESTCODE` a `GlobalLimit = 1`, redeem with one Studio test profile, switch `TestProfileKey` and redeem again: "run out". Reset the counter with `CodeUses_v1:RemoveAsync("TESTCODE")`. Note the uses store is shared with live, so test only with Studio-only codes.
8. **Concurrency.** Fire the remote twice in the same frame from a test script: the second returns "Already redeeming...".
9. **Persistence.** Redeem, Stop, Play, redeem again: already used.

---

## 8. Exploits it must resist

| Attack | Defence |
|---|---|
| Read the code list from the client | List lives in `ServerStorage` and a data store |
| Brute-force unreleased codes | Rate limit, lockout, identical messages for unknown and unreleased codes, long random codes for anything secret |
| Redeem twice with parallel requests | Per-player `redeeming` guard and re-check after the yield |
| Redeem on two servers at once | Session lock on the profile ([[Session Locking and Profile Libraries]]) |
| Huge or odd strings | Raw length cap, `%w` only, length 3 to 24 |
| A leaked tester code | `AllowedUserIds` check |
| A malformed live entry | `parseLive` validates; bad entries are skipped |

---

## 9. Extending it

- **Group-only codes.** Cache `IsInGroupAsync` on join into an attribute and check it here; never call it inside `redeem` (it would add a second yield).
- **Codes that unlock cosmetics.** Grant through `InventoryService.Add` with a unique item; the bag-full path already exists.
- **Analytics.** Log each successful redemption with the code name so you can see which creator campaign drove players ([[Analytics and Funnels]], [[Working with Content Creators]]).
- **A code history list in the UI.** Send the keys of `RedeemedCodes` to the client on open.

## Common mistakes

- Codes in `ReplicatedStorage`.
- Case-sensitive matching: half the support tickets about codes are "it says invalid" for `Welcome`.
- Telling the player "not active yet": it confirms an unreleased code.
- `GetAsync` then `SetAsync` to edit live codes.
- Huge rewards on public codes.
- Testing a global limit on a real code in Studio, against the live counter.

## Checklist

- [ ] Code list server-only; live list validated
- [ ] Input normalised (case, whitespace, length, characters)
- [ ] Rate limit plus failure lockout
- [ ] Per-player single use saved in the profile
- [ ] Global limits reserve before grant and release on failure
- [ ] Grant is all-or-nothing and marks the code in the same block
- [ ] Identical messages for unknown, unreleased and not-allowed codes
- [ ] Rewards sized against the economy

## See also

[[Worked Builds Start Here]] | [[Saved Inventory End to End]] | [[Menu Archetypes - Shop Settings Codes Rewards]] | [[Rate Limiting and Abuse Prevention]] | [[Global State and Live Config]] | [[Daily Rewards System End to End]]

## Nuances and edge cases

1. **How fast a new code goes live.** If servers read the live code list from a DataStore on start and then refresh every few minutes, a code announced in a video works on new servers instantly and on old servers only after the next refresh. Players on an old server see "invalid" and flood the comments. Either refresh often enough (a few minutes is a common choice, rule of thumb), push an update to all servers with MessagingService when a code is added, or announce codes a few minutes after activating them.
2. **Global redemption limits are a distributed counter.** "First 10,000 players" requires one shared count across every server. A DataStore counter with UpdateAsync works at low volume but can hit per-key write limits when thousands of players redeem in the first minute after a video. MemoryStore is better for the hot counter, with the DataStore as the record. Expect slight overshoot at the boundary and decide in advance whether that is acceptable (it usually is).
3. **Expiry and time zones.** Store expiry as UTC seconds (`os.time()`) and show a countdown, not a date, so players in every time zone understand it. A code that "expires Sunday" in one time zone expires on Saturday or Monday elsewhere.
4. **Rewards scale with the game.** A code giving 1,000 coins at launch is generous; six months later, when players earn a million coins an hour, it is meaningless, and old codes still active can be farmed by new alts. Express rewards relative to progression (for example "30 minutes of current earnings", or items rather than currency), and expire old codes.
5. **Alts and code farming.** Every new account can redeem every public code. If public codes give tradeable items or currency, alt farms can feed a trading economy. Make code rewards untradeable, or require some playtime or level before redemption.
6. **Creator codes and attribution.** Codes tied to content creators are useful for measuring which campaigns brought players, but only if redemption is logged with the code and the player's join date. A code redeemed mostly by veteran players shows reach to the existing audience, not new players.
7. **Platform rules.** Promoting codes in videos, on social channels and in the game itself is normal. Rules on directing players to off-platform sites and on what rewards can be tied to (for example, not to actions outside Roblox you cannot verify) apply; check the current community rules before running a code campaign tied to external actions (not re-verified this round).
8. **Scale of support.** At small scale, a few "the code does not work" messages are easy to answer. At scale, the same message arrives hundreds of times. Clear feedback in the UI (expired, already redeemed, invalid, requirements not met) cuts support load more than any other change.

## More common mistakes

1. **No refresh of the live list.** Symptom: new codes work only after server restarts. Fix: periodic refresh plus a MessagingService nudge.
2. **A DataStore counter for a hot global limit.** Symptom: throttling and failed redemptions in the first minutes of a campaign. Fix: MemoryStore counter, DataStore record.
3. **Rewards fixed in currency forever.** Symptom: old codes are worthless or, if large, farmed by alts. Fix: relative rewards and expiry.
4. **Tradeable code rewards.** Symptom: alt accounts funnel code rewards into a main account. Fix: bind code rewards to the account.
5. **Expiry dates in local time.** Symptom: complaints that codes expired early. Fix: UTC storage and countdown display.
6. **No logging per code.** Symptom: no way to tell which creator campaign worked. Fix: log code, player and account age.
7. **Codes entered with spaces or lookalike characters.** Symptom: "invalid" for codes copied from video descriptions. Fix: trim, uppercase, and avoid ambiguous characters such as O and 0 in code names.

## Related decisions

- [[MemoryStore Service]]: the right home for hot global counters.
- [[Cross-Server Messaging]]: pushing a new code to every running server.
- [[Working with Content Creators]]: running creator codes as campaigns.
- [[Launch Strategy - The First Two Weeks]]: where codes fit into a launch plan.
- [[Update Cadence and Hype Cycles]]: tying codes to milestones without training players to wait.
- [[Currency Architecture - Soft Hard and Event Currencies]]: which currency a code should grant.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: alts, races and farming around codes.
- [[Feature Flags and Staged Rollouts]]: switching code features on and off without a publish.
- [[Patch Notes and Player Communication]]: announcing codes and expiries clearly.

## Connected notes
<!-- auto-links:start -->
[[Live Content Pipeline]] · [[Global Leaderboards End to End]] · [[Session Lock]] · [[Strings Patterns and Formatting]] · [[Friend Invites Referrals and Experience Invites]] · [[Idempotency]]
<!-- auto-links:end -->
