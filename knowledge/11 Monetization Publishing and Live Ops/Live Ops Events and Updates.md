---
tags: [live-ops, events, notifications, updates, scheduling, luau]
---
# Live Ops Events and Updates

<!-- tldr:start -->
> [!tldr] TL;DR
> - Event live on some servers, not others: Schedule derived from server start or local state -> Derive from UTC time
> - Countdown shows wrong time: Client clock -> Use server time
> - Players claim twice: Claim flag not in profile, or grant before flag -> Flag first, same profile, no yield
> - All schedules derived from UTC time in one shared module
> - Event claims idempotent per event id
> - Event created in Creator Hub with unique thumbnail; event place set if needed
>
> Cost: TL;DR ~160 tok · whole note ~3.3k tok. Read more: ## 1. Platform tools · ## 2. Timed content in code · ## 5. Failure modes · ## 6. Checklist
<!-- tldr:end -->

Live ops is everything you do after launch to keep a game fresh: content updates, timed events, rotating offers, codes, notifications. On Roblox it is also how you feed the recommendation signals that care about players returning on days 2 to 7 and 8 to 28 ([[Discovery and the Algorithm]]). This note covers the platform tools (Experience Events, update announcements, experience notifications), how to build timed content in code so it is correct across every server, and an operating rhythm. Platform facts verified against the Creator Hub "Experience events" and "Experience notifications" pages **as of October 2026**.

---

## 1. Platform tools

### Experience Events (Docs)
Time-based events created in the Creator Hub.
- Shown on the event details page (shareable; persists after the event, without a join button), on your Game Details page (Join Event for active, **Notify Me** for upcoming), in the **Trending Events in Experiences** sort, and on your group page.
- Up to **10 ongoing or upcoming events** at once. You set start and end; events can be private until you are ready.
- One category per event. Optional unique thumbnail (otherwise your primary thumbnail is used; a unique one is recommended).
- **Notify Me**: players get an inbox notification when the event starts and can opt into push notifications; inbox items stay for the event's duration.
- **Event place:** you can send event joiners to a place other than the start place.
- **Attribution:** players who join from an event surface get the event id in their join data (`player:GetJoinData()`, `GameJoinContext.EventId`).
- **Trending Events sort:** event started within the last 7 days, at least **1,000 RSVPs**, public.
- **Off-platform featuring:** submit at least **7 days** before start; creator 13+ with a linked email; the event must be time-limited or a significant update, public, compliant. Do not edit it after submitting. No feedback on rejections; a performance report afterwards.
- Permissions: "Manage experience events" (or legacy edit) in a group game, or sole owner.
- Discovery docs: up to 5 event thumbnails and a primary event type feed into Home's Live Events.

### Update announcements (Docs)
- **60 characters**, at most **one every three days**, sent to players who enabled notifications for your game.
- Be specific ("New realm: Frost Peaks + 6 bosses"), not "bug fixes"; avoid many updates in a short period.
- Docs say events and updates are being merged and the update form is subject to change.

### Experience notifications (Docs)
Personalised notifications to opted-in users about something that happened to *them* in your game.
- Recipients: **13+** and opted in. Under-13s cannot be prompted (they can still receive experience updates).
- Game must have **100+ visits** and not be under moderation.
- Opt-in prompt: `ExperienceNotificationService:CanPromptOptInAsync()` (wrap in `pcall`), `PromptOptIn()`, and the `OptInPromptClosed` event. The prompt does not show to under-13s, users already opted in, or users shown it in the **last 30 days**.
- Sending: create a **notification string** (up to **99 characters**, with `{parameters}`; `{experienceName}` available) in the Creator Dashboard, then call the Open Cloud user notification API from a server (the docs use an Open Cloud package from the Creator Store) or from outside Roblox. `launchData` up to **200 bytes**.
- Limits: **one notification per user per day** from your game, plus an aggregate daily throttle across games; delivery not guaranteed and tied to engagement.
- Content rules: personalised and based on relevant in-game activity, a clear action, Community Standards and filtering apply, **no dark patterns** (disguised ads, false time pressure, bait-and-switch, purchase tricks), and **gameplay must not require notifications**.
- Analytics: opted-in users, impressions, clicks, CTR, turn-off and dismiss rates (after 100 impressions). To A/B test, create a new string rather than editing.

Good notification triggers: "Your crops are ready", "Your vault is full: 8 hours of cash waiting", "{friend} beat your record", "Your egg hatched". Bad: "Come back! New stuff!" (generic advertising; not allowed).

```lua
--!strict
-- LocalScript: ask for notification opt-in at a moment that explains the value
-- (e.g. right after the player starts something that finishes while they are away).
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")

local function offerOptIn()
	local ok, canPrompt = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if ok and canPrompt then
		ExperienceNotificationService:PromptOptIn()
	end
end

return offerOptIn
```

Because the prompt can be shown once per 30 days, spend it at the best moment: when the player has just started an offline timer, not on join. Docs' sample checks `CanPromptOptInAsync` this way.

---

## 2. Timed content in code

Every server must agree on what is live. Rules:
- **Use UTC server time** (`os.time()` / `DateTime.now()`), never the client's clock.
- **Derive schedules from time, not from state.** "Week number since an epoch" gives every server the same rotation with no coordination.
- **Store event definitions in config you can change without a publish** if you need to hotfix (a data store or MemoryStore live config; see [[Global State and Live Config]]), but keep the schedule logic deterministic.
- **Grant with ids.** Every event reward is claimed against an event id in the player profile so claiming twice (or on two servers) is impossible.

```lua
--!strict
-- ReplicatedStorage/LiveOps/Schedule (ModuleScript): deterministic schedules shared by server and client.
local Schedule = {}

local WEEK = 7 * 24 * 3600
-- Anchor: a Monday 00:00 UTC. Any fixed past timestamp works; never change it after launch.
local EPOCH = 1767571200 -- 2026-01-05 00:00:00 UTC (a Monday)

export type Rotation = { index: number, startsAt: number, endsAt: number }

-- Which entry of a list is live this week, and when it ends.
function Schedule.Weekly(count: number, now: number?): Rotation
	local t = now or os.time()
	local week = (t - EPOCH) // WEEK
	return {
		index = (week % count) + 1,
		startsAt = EPOCH + week * WEEK,
		endsAt = EPOCH + (week + 1) * WEEK,
	}
end

export type Window = { id: string, startsAt: number, endsAt: number }

-- A one-off event window, defined in UTC.
function Schedule.IsLive(w: Window, now: number?): boolean
	local t = now or os.time()
	return t >= w.startsAt and t < w.endsAt
end

function Schedule.SecondsLeft(endsAt: number, now: number?): number
	return math.max(0, endsAt - (now or os.time()))
end

return Schedule
```

The client uses the same module for countdowns, but the server decides eligibility. The client's clock can be wrong by minutes; for display, sync an offset from a server-sent time once (`workspace:GetServerTimeNow()` is available on both sides and is the simplest source).

**Reference project.** Its weekly exclusive shop used this kind of rotation (product per week, countdown on the card, off-week products refused). A server-wide "rift" event opened periodically, showed a beacon in the hub only while open, and had a server-side switch to force it for testing. Its daily chest used "once per UTC day" with a 7-day streak (a missed day resets) saved immediately on claim; a lucky spin used a 1-hour cooldown. All are time-derived and idempotent per id.

### Claiming event rewards

```lua
--!strict
-- Server: claim an event reward exactly once per player per event id.
local function claimEventReward(player: Player, eventId: string, window: { startsAt: number, endsAt: number }): boolean
	local now = os.time()
	if now < window.startsAt or now >= window.endsAt then
		return false
	end
	local profile = PlayerData.GetProfileAsync(player, 10)
	if not profile then
		return false
	end
	local claimed = profile.Data.EventClaims
	if claimed[eventId] then
		return false
	end
	claimed[eventId] = now -- mark first, then grant, no yield in between
	Rewards.Apply(profile.Data, EventConfig[eventId].Reward)
	return true
end
```

Prune `EventClaims` entries for events that ended long ago (keep ids for at least as long as an event could be re-run).

### Cross-server events
For "server luck"-style or global events triggered by a purchase or an admin, broadcast with `MessagingService` and persist the end time in a MemoryStore or data store so servers that start later also know ([[Cross-Server Messaging]], [[MemoryStore Service]]). Do not rely on messages alone; they are not guaranteed to arrive at servers that start after the message.

---

## 3. Codes

Codes are a live-ops staple: free rewards announced on social channels and update logs.
- Validate on the server; normalise case and whitespace.
- Store redeemed code ids in the profile (once per player).
- Give codes an expiry (a window) and keep expired codes answering "expired" instead of "invalid".
- Rewards should be welcome but not economy-breaking.

The reference project's code service granted cash plus 25 gems for a welcome code and specific weapons for two others, once per player, through the same grant function used by other rewards. Its codes button sat in the HUD and later also inside settings. See [[Menu Archetypes - Shop Settings Codes Rewards]].

Note: since 2026 you cannot point players to external social links from in-game text (Announcement); announce codes in your update notes, event descriptions, group and game page instead ([[Age Checks and Safety Features]]).

---

## 4. Update rhythm (rule of thumb)

| Cadence | Content | Platform tool |
|---|---|---|
| Daily | Daily rewards, streaks, daily quests | Notifications for completed timers |
| Weekly | Rotating shop item, weekly quests, a weekend boost | Experience event for weekend boosts |
| Every 2 to 4 weeks | Content update: zone, items, boss, system | Update announcement + event + new thumbnail test |
| Seasonal | Holiday event, limited cosmetics, battle pass season | Event submitted for featuring 7+ days ahead |

A typical update weekend:
1. Publish on a low-traffic weekday, restart outdated servers with bleed-off ([[Publishing an Experience]]).
2. Event goes live at a fixed UTC time (Friday evening for your main region).
3. 60-character update announcement.
4. New thumbnail variant added for personalisation.
5. Code for the update.
6. Watch the error report and economy dashboards for the first hours.

### What updates should contain
- **New goals for existing players** (new zone, higher tier) to lift D7/D30.
- **Fixes to the first session** to lift D1 (often worth more than content).
- **Something visible on the page** (event, thumbnail) to lift play-through rate.
- **A reason to bring a friend** (co-op event, group bonus) for co-play days.

---

### A four-week calendar (example)

| Week | Mon | Wed | Fri (event start, UTC evening for main region) | Sun |
|---|---|---|---|---|
| 1 | Publish content update; restart outdated servers | Hotfix window | Launch event + announcement + new thumbnail variant + code | Review event funnel |
| 2 | Weekly shop rotation | | Weekend 2x boost event | Review economy dashboards |
| 3 | Weekly shop rotation | Submit next big event for featuring (7+ days ahead) | Community challenge (server feed goal) | |
| 4 | Weekly shop rotation; feature freeze | QA in test place | Weekend boost | Write next update notes |

The point is predictability: players learn that Friday means something new, and the team learns that Monday is the only big publish day.

---

## 5. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Event live on some servers, not others | Schedule derived from server start or local state | Derive from UTC time |
| Countdown shows wrong time | Client clock | Use server time |
| Players claim twice | Claim flag not in profile, or grant before flag | Flag first, same profile, no yield |
| Event ended but rewards still claimable | Client decides eligibility | Server checks the window |
| Notifications not delivered | Under 13, not opted in, daily cap, generic string | Personalised strings, opt-in at the right moment |
| Update announcement rejected or ignored | Vague text, too frequent | Specific, once per 3+ days |

## 6. Checklist
- [ ] All schedules derived from UTC time in one shared module
- [ ] Event claims idempotent per event id
- [ ] Event created in Creator Hub with unique thumbnail; event place set if needed
- [ ] Featuring submission 7+ days ahead for big events
- [ ] Notification opt-in prompt at a value moment; strings personalised
- [ ] Update announcement specific, under 60 characters
- [ ] Codes with expiry; once per player
- [ ] Release follows the update routine

## See also
[[Publishing an Experience]] · [[Discovery and the Algorithm]] · [[Retention and Return Hooks]] · [[Global State and Live Config]] · [[Cross-Server Messaging]] · [[Community Building]] · [[Analytics and Funnels]] · [[Release Process and Rollbacks]]

## Connected notes
<!-- auto-links:start -->
[[Experience Notifications and Return Prompts]] · [[Update Cadence and Hype Cycles]] · [[Event Calendars and Content Planning]] · [[Daily Rewards System End to End]] · [[Notification and Toast Systems]] · [[Patch Notes and Player Communication]]
<!-- auto-links:end -->
