---
tags: [platform-features, badges, achievements, badgeservice, progression, retention, luau, strict, type/guide, area/platform, level/intermediate, area/scripting]
---
# Badges and Achievement Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Awarding from a LocalScript -> Award on the server
> - Avoid: Awarding as the player teleports out -> Ledger first, pending retries on next join
> - Avoid: `UserHasBadgeAsync` per badge on every join -> One `GetUserBadgesAsync` batch, then trust the ledger
> - Ledger in saved data is the source of truth; badges are a mirror
> - Every award is server-side and preceded by validation of the feat
> - Pending awards retried with backoff and on next join
>
> Cost: TL;DR ~160 tok · whole note ~5.8k tok. Read more: ## 1. What the platform gives you · ## 4. An award pipeline that does not lose badges · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Badges are the one piece of your progression that leaves your game. A badge lands in the player's Roblox inventory, shows on their profile and stays there after they stop playing. That makes badges powerful (they are a public trophy and a reason to come back) and awkward (they cost money past a daily allowance, you cannot take them back, and the API that awards them has rules that bite at the worst moment). This note covers the platform facts, a two-layer model that separates badges from in-game achievements, rarity design, an award pipeline that never loses or double-awards a badge, and the failure modes that show up in live games.

Platform facts below are labelled **Roblox docs (as of October 2026)** and were checked against the BadgeService reference and the Badges guide on create.roblox.com. Design advice is labelled rule of thumb.

## 1. What the platform gives you

### Creating badges
- Each game gets **5 free badges per 24-hour period (GMT)**; each additional badge in that period costs **100 Robux** (Roblox docs, as of October 2026).
- Upload art on a **512 x 512** template. The upload trims the image into a **circle**, so keep the subject inside the circle (Roblox docs).
- A badge has a name, a description ("what the player must do") and an **Enabled** toggle. Disabled badges do not appear on the game page and **cannot be earned** (Roblox docs).
- Badges appear on the game page in creation order; you can reorder up to **50 at a time** by drag and drop (Roblox docs).
- Badge creation and localization are also exposed through Open Cloud: the API reference lists a create-badge endpoint under the legacy badges API (it needs the `legacy-universe.badge:manage-and-spend-robux` scope, because a sixth badge spends Robux), a free badge quota endpoint, and per-language name, description and icon endpoints, each rate limited to 100 requests per minute per API key owner (Roblox docs, Open Cloud reference). That matters if you ship many badges per season or localize them; see [[Open Cloud APIs]] and [[Asset Upload Automation with Open Cloud]].

### Awarding and checking (BadgeService)
`BadgeService:AwardBadgeAsync(userId, badgeId)` returns `true` on success. For an award to work (Roblox docs, as of October 2026):
- The player must be **connected to the experience right now**.
- The player must **not already own** the badge. Players can delete a badge from their profile and earn it again.
- The call must come from a **server script** (or a ModuleScript a server script requires), never the client.
- The place must be **part of the experience** that owns the badge.
- The badge must be **enabled**; check `IsEnabled` from `GetBadgeInfoAsync`.
- Rate limit: **50 + 35 x (number of users) per minute**.

Checking ownership:

| Method | Batch size | Rate limit (per minute) | Notes |
|---|---|---|---|
| `UserHasBadgeAsync(userId, badgeId)` | 1 | 50 + 35 x players | Server: any user. Client: local user only |
| `CheckUserBadgesAsync(userId, badgeIds)` | up to 10 | 10 + 5 x players, per server | Returns the owned subset, order not guaranteed |
| `GetUserBadgesAsync(userId, badgeIds)` | up to 100 | 10 + 5 x players, per server | Returns `BadgeId` and `AwardedDate` (a `DateTime`) for each owned badge |

All Roblox docs (as of October 2026). One more rule hides in the descriptions: on the server you can check **any** badge (including other games' badges) only for users who have **recently been in the server**; for anyone else, badges from other experiences are silently treated as not owned. Cross-promotion gates ("own the badge from our other game") therefore only work for players currently in your server, which is the normal case, but not for offline lookups.

`GetBadgeInfoAsync(badgeId)` returns `Name`, `Description`, `IconImageId`, `IsEnabled`, `AwardCount`, `PastDayAwardCount` and `Rarity`, where `Rarity` is a 0.0 to 1.0 fraction of players who earned the badge **in the past day** (Roblox docs). Results are cached briefly.

The old synchronous names (`AwardBadge`, `UserHasBadge`, `IsDisabled`, `IsLegal`) are deprecated. Recent reference pages type the user parameter as the new `User` datatype (a domain-scoped identity, available as `Player.User`), while the Badges guide samples still pass `player.UserId`. The samples in this note follow the guide; if your project adopts `Player.User`, check the reference for each call you migrate. This type change is recent and its interaction with older numeric ids was not fully documented when this note was written.

Badge award popups can be turned off from the client with `StarterGui:SetCore("BadgesNotificationsActive", false)` (Roblox docs), useful if you show your own celebration and do not want two popups.

## 2. Badges are not your achievement system

The most common design mistake is treating the badge list as the achievement list. They have different properties:

| Property | Platform badge | In-game achievement (your data) |
|---|---|---|
| Cost | Free up to 5 per day, then 100 Robux each | Free |
| Visible outside the game | Yes, on profile and game page | No |
| Revocable by you | No API to revoke | Yes |
| Player can delete it | Yes, and re-earn it | Only if you allow it |
| Survives a data wipe | Yes | No |
| Can carry tiers, progress bars, counters | No, it is binary | Yes |
| Awarding can fail | Yes (rate limits, player left, disabled) | Only if your save fails |
| Rate limited | Yes | No |

The model that works is two layers. Your **achievement ledger** in the player's profile is the source of truth: it has every achievement, tiers, progress counters and the time each was earned. A **subset** of achievements is mirrored to platform badges as a side effect. The ledger never asks "does the player own the badge?" to decide whether they earned something.

This separation pays off in four places:
1. **Season resets.** If you wipe progress for a new season ([[Economy Resets and Seasonal Wipes]]), badges survive. Players can show "Season 3 Champion" forever while your ledger resets the season counters.
2. **Exploit cleanup.** If an exploiter teleported to the end of an obby and got the completion badge, you cannot remove the badge, but you can remove the ledger entry and anything it unlocked.
3. **Tiers.** "Defeat 10 / 100 / 1,000 enemies" is one ledger achievement with three tiers. You might badge only the 1,000 tier.
4. **Retries.** When an award fails, the ledger already says "earned" and the badge mirror can be retried later, even in a later session.

## 3. What deserves a badge (rule of thumb)

Badges are public and permanent, so they should mean something to someone looking at a profile. A useful filter: "would a player screenshot this?"

| Achievement family | Badge it? | Why |
|---|---|---|
| Welcome / "played the game" | One, at most | Players expect it and some hunt them; more than one cheapens the list |
| Onboarding steps | No | They are chores, not trophies; track them in the ledger and [[Analytics and Funnels]] |
| Major progression milestones (first rebirth, final zone) | Yes | Visible proof of commitment |
| Skill feats (no-hit boss, speedrun under a time) | Yes, a few | High status; make sure the server can verify them |
| Secrets and exploration | Yes | Drives word of mouth and video content |
| Social (played with a friend, won as a party) | Sometimes | Good for co-play, but must be achievable without friends on Roblox (see [[Social Design and Multiplayer Play]]) |
| Collection (all pets in a set) | Yes, for full sets | Not one per item |
| Time-limited events | Yes, then disable | The disabled badge becomes a record of who was there |
| Spending ("bought VIP") | No | Pay-to-badge reads badly and offers nothing to earn |

Keep the badge list short and curated. A list of 200 trivial badges trains players to ignore it; badge-farming games that award dozens of free badges on join exist, and serious players often see a long trivial list as a warning sign (rule of thumb from community sentiment, not a documented ranking effect; nothing in the docs says badge counts affect discovery).

### Rarity design
`Rarity` from `GetBadgeInfoAsync` is the share of **the past day's players** who earned the badge, not the share of all players ever. It is noisy and audience dependent: a feature on the home page floods you with new players, and every hard badge suddenly looks rarer. Use it as a live health signal, not as a fixed label printed in your UI. A rough target ladder (rule of thumb):

| Tier | Past-day rarity target | Example |
|---|---|---|
| Common | 30% to 70% | Reach the second zone |
| Uncommon | 5% to 30% | First rebirth |
| Rare | 1% to 5% | Beat the hardest boss |
| Legendary | under 1% | No-damage clear, full collection |

If a "legendary" badge sits at 15%, it is either too easy or exploitable. If a "common" one sits at 3%, your onboarding is losing people before that point, which is a funnel problem ([[First-Time User Experience and Onboarding]]), not a badge problem. A sudden spike in `PastDayAwardCount` for a hard badge with no update shipped is a classic exploit signal; alert on it ([[Crash and Error Telemetry]]).

If you show rarity in-game, show your own computed figure from your analytics (share of players who reached that stage) or round the platform value into a tier word. Printing "0.3% of players" next to a badge that a content creator just showed to a million viewers will be wrong by next week.

## 4. An award pipeline that does not lose badges

The failure modes are concrete:
- **Player left before the award.** The award requires a connected player. The classic case is a badge awarded at the end of a round while the player is already teleporting out.
- **Rate limit.** A 10-player server can award 50 + 350 = 400 badges a minute. That sounds like plenty until a whole server of 40 finishes an event at once and your code also calls `UserHasBadgeAsync` for every badge on join.
- **Transient errors.** Like every web call, `AwardBadgeAsync` can throw.
- **Disabled badge.** You disabled an event badge but the code still tries.
- **Player deleted the badge.** Your ledger says earned; the platform says not owned.

The pipeline:
1. Gameplay calls `Unlock(player, achievementId)` on the server after validating the feat.
2. `Unlock` writes the ledger entry with `badge = "pending"` if the achievement has a badge. The ledger write is the commit point.
3. A per-server award worker drains a queue, respecting a rate budget, and calls `AwardBadgeAsync`.
4. Success, or a follow-up `UserHasBadgeAsync` that says owned, marks the entry `"confirmed"`.
5. Failure leaves it `"pending"` and retries with backoff; on the player's next join, all pending entries are queued again.
6. `"confirmed"` entries are never re-awarded, even if the player no longer owns the badge. That respects a player who deleted it on purpose.

Point 6 is a judgment call. Without it, a player who deletes a badge sees it come back on every join, which is annoying and looks broken. The ledger knows whether *you* ever confirmed the award, so you can tell "award failed" apart from "player removed it".

### Backfilling an existing game
If you add a ledger to a game that already awarded badges, the first join for each player should import owned badges. `GetUserBadgesAsync` checks up to 100 badge ids in one call and returns the award date, so you can backfill earned times as well. At 10 + 5 x players per minute it is cheap for one call per join. Calling `UserHasBadgeAsync` per badge is not: 40 badges for 30 joining players is 1,200 calls, above the 50 + 35 x 30 = 1,100 per minute budget, and it starves real awards.

### Code: achievement ledger with a badge mirror

```lua
--!strict
-- ServerScriptService/Services/AchievementService (ModuleScript)
-- The ledger lives in the player's saved data (your profile system saves it).
-- Badges are mirrored from the ledger; the ledger never depends on badge ownership.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

type BadgeState = "none" | "pending" | "confirmed" | "skipped"

export type Entry = {
	earnedAt: number, -- os.time() when earned
	tier: number,
	badge: BadgeState,
}

export type AchievementData = { [string]: Entry }

type Def = {
	badgeId: number?, -- nil means ledger-only achievement
	badgeTier: number?, -- which tier triggers the badge (default 1)
}

local DEFS: { [string]: Def } = {
	FirstRebirth = { badgeId = 0000000000 },
	FinalZone = { badgeId = 0000000000 },
	Slayer = { badgeId = 0000000000, badgeTier = 3 }, -- badge only at the top tier
	TutorialDone = {}, -- ledger only
}

local AchievementService = {}

-- Per-player references to the live data tables, set by your data module.
local dataByPlayer: { [Player]: AchievementData } = {}

-- Badge enabled cache, filled lazily.
local enabledCache: { [number]: boolean } = {}

local function isBadgeEnabled(badgeId: number): boolean?
	local cached = enabledCache[badgeId]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(BadgeService.GetBadgeInfoAsync, BadgeService, badgeId)
	if not ok then
		return nil -- unknown, try later
	end
	local enabled = info.IsEnabled == true
	enabledCache[badgeId] = enabled
	return enabled
end

-- Shared rate budget. The docs give 50 + 35 x users per minute for both
-- AwardBadgeAsync and UserHasBadgeAsync; we spend one budget for both to stay safe.
local windowStart = os.clock()
local spent = 0

local function takeBudget(): boolean
	local now = os.clock()
	if now - windowStart >= 60 then
		windowStart = now
		spent = 0
	end
	local limit = 50 + 35 * #Players:GetPlayers()
	if spent >= limit * 0.8 then -- keep 20% headroom for other systems
		return false
	end
	spent += 1
	return true
end

type Job = { player: Player, id: string, attempts: number, notBefore: number }
local queue: { Job } = {}

local function enqueue(player: Player, id: string)
	table.insert(queue, { player = player, id = id, attempts = 0, notBefore = 0 })
end

local function tryAward(job: Job): "done" | "retry" | "drop"
	local data = dataByPlayer[job.player]
	if not data or job.player.Parent ~= Players then
		return "drop" -- player left; the entry stays "pending" for next join
	end
	local entry = data[job.id]
	local def = DEFS[job.id]
	if not entry or not def or not def.badgeId or entry.badge ~= "pending" then
		return "drop"
	end
	local badgeId = def.badgeId :: number

	local enabled = isBadgeEnabled(badgeId)
	if enabled == nil then
		return "retry"
	elseif enabled == false then
		entry.badge = "skipped" -- disabled badges cannot be earned
		return "done"
	end

	if not takeBudget() then
		return "retry"
	end
	local ok, awarded = pcall(BadgeService.AwardBadgeAsync, BadgeService, job.player.UserId, badgeId)
	if ok and awarded then
		entry.badge = "confirmed"
		return "done"
	end

	-- false or error: the player may already own it (earned before the ledger existed).
	if not takeBudget() then
		return "retry"
	end
	local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, job.player.UserId, badgeId)
	if okHas and has then
		entry.badge = "confirmed"
		return "done"
	end
	return "retry"
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local now = os.clock()
		for i = #queue, 1, -1 do
			local job = queue[i]
			if job.notBefore <= now then
				local result = tryAward(job)
				if result == "retry" and job.attempts < 6 then
					job.attempts += 1
					job.notBefore = now + 2 ^ job.attempts -- 2, 4, 8 ... 64 seconds
				else
					table.remove(queue, i)
				end
			end
		end
	end
end)

-- Call after server-side validation of the feat. Returns true if newly earned or upgraded.
function AchievementService.Unlock(player: Player, id: string, tier: number?): boolean
	local data = dataByPlayer[player]
	local def = DEFS[id]
	if not data or not def then
		return false
	end
	local newTier = tier or 1
	local entry = data[id]
	if entry and entry.tier >= newTier then
		return false
	end
	if not entry then
		entry = { earnedAt = os.time(), tier = newTier, badge = "none" }
		data[id] = entry
	else
		entry.tier = newTier
	end
	if def.badgeId and newTier >= (def.badgeTier or 1) and entry.badge == "none" then
		entry.badge = "pending"
		enqueue(player, id)
	end
	return true
end

-- Call from your data module once the profile is loaded and session-locked.
function AchievementService.OnProfileLoaded(player: Player, data: AchievementData)
	dataByPlayer[player] = data

	-- Backfill: import badges the player already owns (one batched call, up to 100 ids).
	local ids: { number } = {}
	local idToKey: { [number]: string } = {}
	for key, def in DEFS do
		if def.badgeId and not data[key] then
			table.insert(ids, def.badgeId)
			idToKey[def.badgeId] = key
		end
	end
	if #ids > 0 and #ids <= 100 then
		local ok, owned = pcall(BadgeService.GetUserBadgesAsync, BadgeService, player.UserId, ids)
		if ok then
			for _, row in owned do
				local key = idToKey[row.BadgeId]
				if key then
					data[key] = {
						earnedAt = row.AwardedDate.UnixTimestamp,
						tier = DEFS[key].badgeTier or 1,
						badge = "confirmed",
					}
				end
			end
		end
	end

	-- Retry anything that never got confirmed in an earlier session.
	for key, entry in data do
		if entry.badge == "pending" then
			enqueue(player, key)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	dataByPlayer[player] = nil
end)

return AchievementService
```

Notes on the code:
- The backfill uses `#ids <= 100` because `GetUserBadgesAsync` takes at most 100 ids. With more than 100 badges, split the list across calls and spend the 10 + 5 x players budget carefully.
- A badge awarded at the moment the player leaves stays `"pending"` in the saved ledger. That is why the ledger write must be saved with the profile, not kept in memory.
- Awards are never triggered by a client message alone. The remote that says "I reached the end" must be validated against server-side state (checkpoints touched in order, minimum elapsed time); see [[Server Authority and Validation]] and [[Remote Abuse Patterns and Rate Limiting in Practice]].

## 5. Event and seasonal badges

Time-limited badges are the strongest use of the "permanent trophy" property: they say "I was there". Design points:
- **Disable the badge when the event ends.** Disabled badges cannot be earned and disappear from the game page (Roblox docs). Owned copies stay on profiles.
- **Do not rely on the toggle alone for timing.** Your server code should also check the event window, because a server started before the toggle may have cached `IsEnabled = true` (the cache in the sample above lives for the server's lifetime). Drive event windows from live config ([[Global State and Live Config]]).
- **Budget the creation cost.** Five free badges per 24 hours means a weekly event with three badges is free; a launch with 30 badges created on one day costs 25 x 100 = 2,500 Robux. Create badges over several days before launch.
- **Re-runs.** If an event returns next year, make a new badge ("Winter 2027") rather than re-enabling the old one, or the old badge stops meaning "was there in 2026".

## 6. Showing achievements in game

The badge list on the game page is not enough; players should see progress where they play.
- Show the ledger, with progress bars for tiered achievements and a "badge" marker on those mirrored to the platform.
- Celebrate the unlock in the moment with your own UI and sound, and consider disabling the platform badge popup so the moment is not interrupted by a second toast ([[Notification and Toast Systems]], [[Game Feel and Juice]]).
- Profile cards can show a player's top badges from your game with `GetUserBadgesAsync`, a good social signal in hubs ([[Avatar Context Menus Profiles and Social Surfaces]]).
- Secret achievements: show a locked silhouette and a vague hint. Listing exact steps in the badge description defeats the point, but the docs ask the description to say what the player must do, so a riddle-style description is a fair compromise.

## 7. When not to use badges
- **Prototype and test places.** Badges in a place outside the experience cannot be awarded. Test in a published test experience with its own badges.
- **Everything players do once.** If every action earns a badge, none matter.
- **Purchases.** Reward the purchase in game; do not badge it.
- **Rewards that need to be taken back.** Anything that might need revocation belongs in the ledger only.

## 8. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Awarding from a LocalScript | Nothing happens, no error you notice | Award on the server |
| Awarding as the player teleports out | Random missing badges, "I beat it but no badge" reports | Ledger first, pending retries on next join |
| `UserHasBadgeAsync` per badge on every join | Award calls fail at peak times | One `GetUserBadgesAsync` batch, then trust the ledger |
| Badge list as the achievement system | Cannot reset seasons or clean up exploits | Two layers: ledger plus badge mirror |
| Re-awarding confirmed badges | Deleted badges keep coming back | Never re-award a confirmed entry |
| 30 badges created on launch day | Unexpected Robux spend | Spread creation over several days |
| Rarity printed as a fixed fact | Numbers wrong after a traffic spike | Use tiers or your own analytics |
| Cross-game badge gates for offline lookups | Players reported as not owning badges they own | Only check while the player is in the server |

## 9. Checklist
- [ ] Ledger in saved data is the source of truth; badges are a mirror
- [ ] Every award is server-side and preceded by validation of the feat
- [ ] Pending awards retried with backoff and on next join
- [ ] Confirmed awards never re-awarded
- [ ] One batched `GetUserBadgesAsync` call per join at most; budget for 50 + 35 x users per minute on awards
- [ ] Disabled event badges also gated by live config
- [ ] Badge creation spread across days (5 free per 24 hours)
- [ ] Rarity monitored per day; spikes on hard badges alerted
- [ ] Badge art readable inside a circle at small sizes

## See also
[[Platform Features Start Here]] · [[Progression Levels and Unlocks]] · [[Quests and Objectives]] · [[Retention and Return Hooks]] · [[Economy Resets and Seasonal Wipes]] · [[Session Locking and Profile Libraries]] · [[Server Authority and Validation]] · [[Analytics and Funnels]] · [[Links - Badges]]

## Connected notes
<!-- auto-links:start -->
[[Links - Quests and progression]] · Event Bus · Purchase Data and Receipts · Battle Pass and Season Design · OrderedDataStores and Leaderboards · Player Privacy and Data Deletion
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Friend Invites Referrals and Experience Invites]] · [[Experience Notifications and Return Prompts]] · [[Subscriptions and Recurring Revenue]] · [[Engine and API Changes 2025-2026]] · [[Commerce and Physical Goods]] · [[Roblox Changes 2025-2026]] · [[Data and Cloud Changes 2025-2026]] · [[Discovery and Monetization Changes 2025-2026]]
<!-- related:end -->
