---
tags: [platform-features, notifications, retention, open-cloud, events, memorystore, live-ops, luau, strict]
---
# Experience Notifications and Return Prompts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Opt-in prompt on join -> Prompt after a delayed-payoff action
> - Avoid: Generic "come back" notifications -> Personal and actionable only
> - Avoid: Several notifications queued per user per day -> One slot per user, keep the best
> - Game meets eligibility (100 visits); strings created per use case, under 99 characters
> - Opt-in prompt only after a delayed-payoff action, with a context line first
> - At most one queued notification per user; priority rules decide which
>
> Read more (22 KB note): ## 2. Experience notifications · ## 5. The scheduling problem · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

A player who closes your game is unreachable unless they gave you a way back in. Roblox offers three on-platform channels for that: **experience notifications** (personal, one per player per day), **update announcements** (broadcast to everyone who follows the game) and **event notifications** (for players who tapped "Notify Me" on an event). Each has its own eligibility, limits and failure modes. This note covers all three, the scheduling problem nobody mentions (the event you want to notify about usually happens while no server is running for that player), and copy that survives the spam filter. [[Retention and Return Hooks]] lists notifications as one hook among many; this note is the implementation.

Platform facts are labelled **Roblox docs (as of October 2026)** and were checked against the Experience notifications guide, the Open Cloud User notifications guide, the ExperienceNotificationService and SocialService references, the Open Cloud API reference and the Experience events and updates guide on create.roblox.com. Strategy is rule of thumb.

## 1. The three channels

| | Experience notifications | Update announcements | Event notifications |
|---|---|---|---|
| Content | Your personalised string with parameters | 60 characters, free text | Generated from your event |
| Audience | Opted-in users **13 and over** | Everyone who enabled notifications, **including under 13** | Players who chose Notify Me / RSVP |
| Frequency | **1 per user per day** per experience, plus an aggregate daily cap across experiences | **Once every 3 days** | When the event starts |
| Sent by | Your server code (Luau package) or Open Cloud | You, from the Creator Dashboard | Roblox, automatically |
| Join routing | Launch data (200 bytes) | Joins the experience | Event place; `EventId` in join context |

All Roblox docs (as of October 2026). The analytics summary notes that the opted-in user count includes under-13 users, who can receive update announcements but not personalised notifications. Design consequence: for your youngest players, the only out-of-game channels are update announcements and events. A retention plan that depends on personalised notifications quietly excludes them.

## 2. Experience notifications

### Eligibility (Roblox docs, as of October 2026)
- At least **100 visits** since launch.
- The game is not under moderation.
- You have permission to manage the game.

### The notification string
Create strings in the Creator Dashboard (game, Engagement, Notifications). There is **no default string**; you must create one. The text is limited to **99 characters**, can contain any number of `{parameters}`, automatically uses your game title as the notification title, and can reference `{experienceName}` in the body. Copy the asset id and send it as `messageId`. There is no Open Cloud API to create strings; it is a dashboard step (Roblox docs).

Parameters come in two flavours in the samples: `stringValue` (or `string_value` over REST) for text and numbers, and `int64Value` for user ids, which render as mentions. A `{userId-friend}` style parameter shows another user's name. Mentions are **not delivered** unless the receiver and the mentioned user are friends, and the mentioned user allows "Update friends about my activity" in their privacy settings (Roblox docs). Write a fallback string without a mention for rivals who are not friends.

### Sending
Two paths (Roblox docs):
1. **From game servers** with the **Open Cloud** package from the Creator Store (Packages category), placed in `ServerScriptService`. You call `createUserNotification(userId, userNotification)`, where `userNotification.payload` has `messageId`, `type = "MOMENT"` (the only type supported), and optional `parameters`, `joinExperience = { launchData = ... }` and `analyticsData = { category = ... }`. The result has `statusCode`, `error` (`code`, `message`) and `response` (`id`, `path`). The documented Luau samples pass no API key.
2. **From outside Roblox** with `POST https://apis.roblox.com/cloud/v2/users/{userId}/notifications`, an API key with the `user.user-notification:write` scope, and `source.universe` set to `universes/{universeId}`. The Open Cloud reference lists a rate limit of 4,000 requests per second per API key owner. Note that the REST guide's example puts `join_experience` and `analytics_data` at the top level of the body, while the Luau package nests `joinExperience` and `analyticsData` inside `payload`. Follow the shape each doc shows for its path.

### Delivery is not guaranteed
The docs are blunt: a spam prevention system protects the shared channel, delivery is not guaranteed, and **reach is informed by engagement**: the more users engage with your notifications, the more reach you get. Non-delivery reasons include eligibility, the user not opted in, the per-experience daily throttle, the user's aggregate daily throttle, invalid parameters, a moderated string, and mention rules (Roblox docs). The feedback loop is the important part: low click-through and high turn-off rates shrink your future reach. Every bad notification costs you good ones later.

### Analytics
The Notifications page has an Analytics tab: opted-in users, impressions, clicks, CTR, **Turn Off** rate and **Dismiss** rate, with stats shown only after **100 aggregate impressions**, and per-notification rows after 100 impressions each. The row name defaults to the string's identifier, but the `category` field you send overrides it. To A/B test copy, the docs recommend separate strings with similar names (for example `EggHatchA` and `EggHatchB`) (Roblox docs). Watch Turn Off rate above all: it is the number that measures annoyance.

## 3. The opt-in prompt is a once-a-month resource

`ExperienceNotificationService:PromptOptIn()` shows a standard in-experience modal asking the player to enable notifications. Rules (Roblox docs, as of October 2026):
- Client only (LocalScript or client RunContext); it always targets the local player.
- Call `CanPromptOptInAsync()` first, in `pcall`.
- The text **cannot be customised**.
- The modal does **not** appear if the user is under 13, has already enabled notifications for your game, or **has already seen the prompt for your game in the past 30 days**.
- `OptInPromptClosed` fires when it closes. It does not tell you whether they accepted.

The 30-day rule changes timing decisions. If you fire the prompt on join, every new player burns their one chance this month on a moment when they have no reason to care. Fire it right after the player starts something whose payoff comes later (rule of thumb):
- They planted a crop, started a 6-hour egg, queued a long craft.
- They set a personal best that friends can beat.
- They joined a guild or crew whose activity they will miss.

Show your own one-line context **before** the standard modal ("Want a ping when your egg hatches?") so the player understands why the modal appeared. Because the modal text is fixed, your context line is the only persuasion you get. And never gate anything behind enabling notifications: the guidelines forbid requiring notifications to participate or advance (Roblox docs).

```lua
--!strict
-- StarterPlayerScripts/NotificationOptIn (LocalScript)
-- Call NotificationOptIn.Offer() after the player starts a long timer.
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")

local offeredThisSession = false

local function canPrompt(): boolean
	local ok, can = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	return ok and can == true
end

local NotificationOptIn = {}

function NotificationOptIn.Offer(showContext: (onContinue: () -> ()) -> ())
	if offeredThisSession then
		return
	end
	offeredThisSession = true
	task.spawn(function()
		if not canPrompt() then
			return -- under 13, already enabled, or prompted in the last 30 days
		end
		-- Your own small panel: "Get a ping when your egg hatches?" with Continue / Not now.
		showContext(function()
			pcall(function()
				ExperienceNotificationService:PromptOptIn()
			end)
		end)
	end)
end

ExperienceNotificationService.OptInPromptClosed:Connect(function()
	-- Log that the prompt closed; acceptance is not reported here.
end)

return NotificationOptIn
```

## 4. What to notify about

The guidelines ask for notifications that are **personalised** and **actionable**, and give examples on both sides: "You're 2 races away from completing the weekly challenge!" is good; "A new line of race cars just dropped" is generic advertising and discouraged (Roblox docs). They forbid dark patterns: disguised ads, false time pressure, bait-and-switch free items, and notifications that lead straight into a pre-loaded purchase. All text passes platform text filtering and the platform-wide Community Standards, even if your game is rated 17+.

A practical taxonomy (rule of thumb), ranked by typical click-through:

| Type | Example string | Why it works |
|---|---|---|
| Completion of the player's own timer | "Your {eggName} hatched! Come meet your new pet." | They started it; the payoff is waiting |
| Social rivalry (friends only) | "{userId-friend} beat your record on {trackName}. Time for revenge?" | Personal, social, actionable |
| Near-goal progress | "You're {n} quests away from this week's reward!" | Concrete and close |
| Something happening to their stuff | "Your shop sold {count} items while you were away." | Ownership |
| Expiring personal reward | "Your daily streak resets in 3 hours." | Real, not false, urgency; use sparingly |

Avoid: "We miss you!", sale announcements, "new update!" (use update announcements for that), and anything the player cannot act on.

Because a player gets at most one notification a day from you, each send competes with every other reason you might notify them. Pick the **single most valuable** message per player per day and drop the rest.

## 5. The scheduling problem

Most good notifications are about something that becomes true **while the player is away**: the egg hatches at 3 a.m., the crop is ready, the auction ends. At that moment, no server is running for that player. Three ways to handle it:

| Approach | How | Good for | Weakness |
|---|---|---|---|
| Send from the server where the event happens | A friend beats the record; that friend's server sends the rivalry notification | Social events | Only works when someone else is online |
| Shared due-time queue in MemoryStore | Schedule a job with a due time; any running server polls and sends | Timers that end later | Needs at least one live server; 45-day max lifetime |
| External backend with Open Cloud | Your own server stores jobs and calls the REST API | Games with quiet hours, very large scale | You run and secure infrastructure |

For most games the MemoryStore queue is enough, because some server is almost always running. Its design:
- **One key per user** (`u<userId>`). The 1-per-day throttle means a second pending job for the same user is a waste, so scheduling replaces the existing job only if the new one has higher priority or the same priority and an earlier due time.
- **Sort key = due time** (Unix seconds), so `GetRangeAsync` with an upper bound returns due jobs first.
- **Claim before send** with `UpdateAsync`, so two servers polling at once do not both send.
- **Suppress if the player is online.** Notifying someone who is in your game right now wastes their daily slot. Check a presence record (a short-TTL MemoryStore entry each server refreshes for its players) before sending.
- **Expiry.** MemoryStore items live at most 45 days (3,888,000 seconds) (Roblox docs). Set each job's expiration to its due time plus a margin.

```lua
--!strict
-- ServerScriptService/Services/NotificationQueue (ModuleScript)
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local OCUserNotification = require(ServerScriptService.OpenCloud.V2.UserNotification)

local QUEUE = MemoryStoreService:GetSortedMap("NotifyQueue_v1")
local PRESENCE = MemoryStoreService:GetHashMap("Presence_v1")
local SERVER = HttpService:GenerateGUID(false)
local MAX_TTL = 3_888_000
local CLAIM_SECONDS = 120

export type Job = {
	userId: number,
	messageId: string,
	priority: number, -- higher wins the daily slot
	category: string, -- analytics row name
	launchData: string?, -- 200 bytes max; a route, never a reward
	params: { [string]: { stringValue: string? , int64Value: number? } }?,
	claimedBy: string?,
	claimedAt: number?,
}

local NotificationQueue = {}

function NotificationQueue.Schedule(job: Job, dueAt: number)
	local ttl = math.clamp(dueAt - os.time() + 6 * 3600, 60, MAX_TTL)
	pcall(function()
		QUEUE:UpdateAsync("u" .. job.userId, function(old: Job?, oldDue: number?)
			if old and oldDue then
				local keepOld = old.priority > job.priority or (old.priority == job.priority and oldDue <= dueAt)
				if keepOld then
					return nil -- cancel: the existing job is better
				end
			end
			return job, dueAt
		end, ttl)
	end)
end

local function isOnline(userId: number): boolean
	if Players:GetPlayerByUserId(userId) then
		return true
	end
	local ok, value = pcall(PRESENCE.GetAsync, PRESENCE, "u" .. userId)
	return ok and value ~= nil
end

local function claim(key: string): Job?
	local claimed: Job? = nil
	pcall(function()
		claimed = QUEUE:UpdateAsync(key, function(old: Job?, oldDue: number?)
			if not old then
				return nil
			end
			local now = os.time()
			if old.claimedBy and old.claimedAt and now - old.claimedAt < CLAIM_SECONDS then
				return nil -- another server is on it
			end
			old.claimedBy = SERVER
			old.claimedAt = now
			return old, oldDue
		end, 3600)
	end)
	if claimed and claimed.claimedBy == SERVER then
		return claimed
	end
	return nil
end

local function send(job: Job): boolean
	local payload: { [string]: any } = {
		messageId = job.messageId,
		type = "MOMENT",
		analyticsData = { category = job.category },
	}
	if job.params then
		payload.parameters = job.params
	end
	if job.launchData then
		payload.joinExperience = { launchData = job.launchData }
	end
	local ok, result = pcall(OCUserNotification.createUserNotification, job.userId, { payload = payload })
	if not ok then
		warn("[Notify] call failed", result)
		return false
	end
	if result.statusCode ~= 200 then
		-- Throttled, not opted in, invalid params: log and drop, do not retry forever.
		warn("[Notify]", result.statusCode, result.error and result.error.code, result.error and result.error.message)
	end
	return true -- delivered or permanently rejected; either way the job is done
end

task.spawn(function()
	while true do
		task.wait(15 + math.random() * 5) -- jitter so servers do not poll in lockstep
		local ok, items = pcall(function()
			return QUEUE:GetRangeAsync(Enum.SortDirection.Ascending, 25, nil, { sortKey = os.time() + 1 })
		end)
		if ok and items then
			for _, item in items do
				local job = claim(item.key)
				if job then
					if isOnline(job.userId) then
						pcall(QUEUE.RemoveAsync, QUEUE, item.key) -- they are here; no need
					elseif send(job) then
						pcall(QUEUE.RemoveAsync, QUEUE, item.key)
					end
				end
			end
		end
	end
end)

-- Presence heartbeat for this server's players.
task.spawn(function()
	while true do
		for _, player in Players:GetPlayers() do
			pcall(PRESENCE.SetAsync, PRESENCE, "u" .. player.UserId, true, 120)
		end
		task.wait(60)
	end
end)

return NotificationQueue
```

Notes:
- The `RemoveAsync` after send can, in a rare race, delete a job that was rescheduled for the same user a moment earlier. With one job per user per day that is an acceptable loss; if not, store a job id and compare it in an `UpdateAsync` that returns nil when it changed.
- Every poll and presence write costs MemoryStore requests. The quota scales with concurrent users; check the current numbers in [[MemoryStore Service]] before you shorten the poll interval.
- The send step treats non-200 results as done. The docs promise "transparent feedback" when the throttle is reached but do not list the exact error codes; log them and build your own table from what you see.
- Only schedule for players who plausibly opted in. You cannot query opt-in status from the server, so you will send some notifications that are rejected; that is expected, but do not spray every player every day.

### Routing the arrival
When the player taps **Join**, your launch data arrives in `GetJoinData().LaunchData` (read it with a short retry loop, as with invites; see [[Friend Invites Referrals and Experience Invites]]). Route them straight to the thing the notification promised: the hatched egg, the rival's track. A notification that says "your egg hatched" followed by a 20-second walk from spawn trains players to ignore the next one.

## 6. Update announcements

The older broadcast system (Roblox docs, as of October 2026):
- Creator Dashboard, Engagement, Events & Updates, then the link to the old updates page. The docs say events and updates are being combined and the form may change.
- **60 characters**, **once every 3 days**, sent to everyone who enabled notifications, including under-13 users.
- Stats per update: views, visit rate, unfollow rate.

Because it hits your whole opted-in audience, an update announcement is the bluntest instrument you have. Rules of thumb: announce only updates that change what players can do ("New volcano zone and 12 pets"), never "bug fixes"; time it for when your players are awake; and watch unfollow rate, since every unfollow removes a player from all future announcements. Patch notes belong in game and on your group page ([[Patch Notes and Player Communication]]).

## 7. Events and RSVPs

Experience events are the third channel, and the only one where Roblox does the sending (Roblox docs, as of October 2026):
- Create in Events & Updates; at most **10 ongoing or upcoming** events published; public or private; choose a place (players joining from event surfaces spawn there).
- Players see events on the game page and the event details page, can **Notify Me**, and get a stream notification (and optionally push) when the event starts.
- The **Trending Events in Experiences** chart sort needs an active event that started within the last 7 days, at least **1,000 RSVPs**, and public visibility.
- Joining from an event surface adds `EventId` to `GetJoinData().GameJoinContext`.
- In game, `SocialService:GetUpcomingExperienceEventsAsync()` returns active and upcoming events (soonest first) and `SocialService:PromptRsvpToEventAsync(eventId)` prompts the local player to RSVP, returning an `Enum.RsvpStatus` (`None`, `Going`, `NotGoing`). Event ids are strings. The reference warns that hard-coded ids go stale when events end; discover them at runtime.
- An Off-Platform Featuring program can show selected events on app stores and Roblox marketing channels; submissions need to be in at least 7 days before the event starts.

The in-game RSVP prompt is the return prompt to use for scheduled content: "Boss raid Saturday 18:00 UTC. Remind me?" It works for players of all ages, it does not use your daily notification slot, and RSVP counts feed the trending sort. Place it on the event board in your hub and after the current event ends ("Next one is Saturday"). See [[Live Ops Events and Updates]] and [[Event Calendars and Content Planning]] for cadence.

## 8. Return prompts inside the game

"Return prompts" are also what the player sees **before** leaving: the reasons to come back tomorrow. These cost nothing and reach every player:
- A visible timer for the next free reward or the egg in progress.
- "Tomorrow" previews on the daily reward calendar ([[Daily Rewards System End to End]]).
- An event board with the next scheduled event and an RSVP button.
- A gentle opt-in offer after starting a long timer (section 3).

Keep them honest: the guidelines' bans on false time pressure apply in spirit to in-game prompts too ([[Ethical Design and Player Trust]], [[Limited-Time Offers - Design and Ethics]]).

## 9. Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Opt-in prompt on join | Burns the 30-day chance | Prompt after a delayed-payoff action |
| Generic "come back" notifications | Low CTR, high turn-off, shrinking reach | Personal and actionable only |
| Several notifications queued per user per day | All but one throttled | One slot per user, keep the best |
| Notifying players who are online | Wasted daily slot | Presence check |
| Mentions of non-friends | Silently not delivered | Fallback string without mention |
| Launch data that grants a reward | Exploitable links | Route only; server validates |
| Retention plan built on notifications | Excludes under-13 players | Pair with updates, events and in-game hooks |
| Hard-coded event ids | RSVP prompts fail after events end | `GetUpcomingExperienceEventsAsync` at runtime |

## 10. Checklist
- [ ] Game meets eligibility (100 visits); strings created per use case, under 99 characters
- [ ] Opt-in prompt only after a delayed-payoff action, with a context line first
- [ ] At most one queued notification per user; priority rules decide which
- [ ] Presence check before sending; launch data routes to the promised thing
- [ ] Turn Off and Dismiss rates reviewed weekly; copy A/B tested with separate strings
- [ ] Update announcements reserved for real content changes
- [ ] Events created ahead, RSVP prompt in the hub, ids discovered at runtime
- [ ] Nothing gated behind enabling notifications

## See also
[[Platform Features Start Here]] · [[Retention and Return Hooks]] · [[Open Cloud APIs]] · [[MemoryStore Service]] · [[Live Ops Events and Updates]] · [[Event Calendars and Content Planning]] · [[Patch Notes and Player Communication]] · [[Analytics and Funnels]] · [[Notification and Toast Systems]]

## Connected notes
<!-- auto-links:start -->
[[Discovery and the Algorithm]] · [[Update Cadence and Hype Cycles]] · [[Links - Community and social]] · [[Cross-Server Messaging]] · [[Community Building]] · [[Click-Through Rate]]
<!-- auto-links:end -->
