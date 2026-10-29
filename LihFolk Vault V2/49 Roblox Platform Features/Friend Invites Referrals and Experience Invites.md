---
tags: [platform-features, invites, referrals, share-links, socialservice, growth, launch-data, luau, strict, type/guide, area/platform, level/intermediate]
---
# Friend Invites Referrals and Experience Invites

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Rewarding on prompt open or on `GameInvitePromptClosed` -> Reward on qualified arrival
> - Avoid: Reading `LaunchData` once in `PlayerAdded` -> Poll for a few seconds
> - Avoid: Long `PromptMessage` -> Keep it short; overflowed text is not shown
> - `CanSendGameInviteAsync` checked; button hidden when false
> - Invite placed at moments that benefit from company, behind the pop-up gate
> - Notification string includes `{experienceName}`; prompt message short
>
> Cost: TL;DR ~160 tok · whole note ~5.3k tok. Read more: ## 1. The four mechanisms · ## 4. Designing referral rewards · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Roblox gives you four different ways for one player to bring another into your game, and they behave differently in ways that matter for rewards, attribution and abuse. This note separates them, explains the join data each one produces, and builds a referral reward system that survives the hard parts: the inviter is offline or in another server, launch data arrives late, the invitee may be an alt account, and you cannot see who was invited. The older notes [[Social Design and Multiplayer Play]] and [[Community Building]] cover *why* invites matter and the basic invite button; this note is the system behind it.

Platform facts are labelled **Roblox docs (as of October 2026)** and were checked against the [[SocialService]] and ExperienceInviteOptions references and the Player invite prompts, Friend referral system and Share links guides on create.roblox.com. Strategy is rule of thumb.

## 1. The four mechanisms

| Mechanism | Who starts it | Who can receive | What arrives in join data | Expires |
|---|---|---|---|---|
| **Invite prompt** (`SocialService:PromptGameInvite`) | A player, from your UI | Their Roblox friends (one specific friend or a picker) | `LaunchData` from `ExperienceInviteOptions`, plus `ReferredByPlayerId` | Not documented |
| **Friend referral** (referral link from the invite menu) | A player, from the invite modal | Anyone, including people who are not yet their friends on Roblox | `ReferredByPlayerId` | The link never expires |
| **Share link** (Creator Hub) | You, the creator | Anyone off-platform | `LaunchData` set on the link | You manage it |
| **Generated share link** (`SocialService:PromptLinkSharingAsync`) | Your server, for a player | Anyone the player shares with | `LaunchData` set in options | Default 86,400 seconds |

All rows are Roblox docs (as of October 2026). Details that change designs:
- `ReferredByPlayerId` in `Player:GetJoinData()` is documented to populate "for all types of invitations" and holds the inviter's user id. It is the field your reward logic keys on.
- Referral links are not restricted to Roblox friends: the FAQ says players can invite people they are not connected with yet, and the link never expires.
- A game must have been live for at least one day and not violate the Community Standards to use the referral system (Roblox docs).
- `PromptLinkSharingAsync` is **server-only**. It generates an expiring link and opens the platform share sheet, or copies the link to the clipboard where a share sheet is not available. Options: `ExpirationSeconds` (default 86,400), `FallbackLinkId` (where an expired link sends people, default the game's join link), `PreviewTitle`, `PreviewDescription`, `PreviewAssetId` and `LaunchData`. `SocialService.ShareSheetClosed` fires on the server when the sheet closes. The older `PromptLinkSharing` is deprecated (Roblox docs).
- Creator Hub share links have no limit per game and feed the Acquisition analytics; use one per channel (video description, Discord, a creator's video) to compare them. For group-owned games only members with the share links permission can create them, from the group account (Roblox docs). Also note the 2026 external link rules in [[Community Building]]: off-platform links reach fewer young players than they used to.

There is also a phone book call prompt (`SocialService:PromptPhoneBook` with `CanSendCallInviteAsync`), which invites friends to a call rather than to a server. It is out of scope here.

## 2. The invite prompt in detail

### Facts (Roblox docs, as of October 2026)
- Always call `SocialService:CanSendGameInviteAsync(player, recipientId?)` first, in `pcall`. The optional second argument checks a **specific** recipient. The ability varies by platform and player.
- `ExperienceInviteOptions` has four properties:
  - `PromptMessage`: text shown to the sender. **If it is long enough to overflow the prompt UI, it is not shown at all.**
  - `InviteUser`: one friend's user id. Without it, the player picks from a list.
  - `InviteMessageId`: the asset id of a **Notification string** you create in the Creator Dashboard (Engagement, Notifications). The string **must include `{experienceName}`** and may include `{displayName}` for the sender.
  - `LaunchData`: up to **200 characters**, readable from `GetJoinData().LaunchData` when the friend joins from the notification.
- `SocialService.GameInvitePromptClosed(player, recipientIds)` fires when the prompt closes, but `recipientIds` is **no longer populated** and is always an empty array.

That last point removes a whole class of designs. You **cannot** know whether the player invited anyone, or whom. Any reward "for inviting" is either a reward for opening a menu (exploitable and pointless) or a reward for an **arrival**. Only arrivals are rewardable.

### Placement (rule of thumb)
Invite prompts convert when the player has a reason to want company at that moment:
- Before content that is better with others: a co-op boss, a party minigame, a trading hub.
- After a proud moment: a rare drop, a new personal best. Pair it with a share link offer instead if most of your players' friends are not on Roblox.
- When a friend-specific benefit is visible: "Friend boost: +10% while a friend is in your server".

Avoid prompting on join (no context), mid-combat (interrupts), or repeatedly. Use the same pop-up gate as purchase prompts so a player never sees two platform prompts in a row ([[Pricing and Store Design]]).

### Targeted invites
`InviteUser` plus `CanSendGameInviteAsync(player, friendId)` lets you build "invite this friend" buttons. A natural list is `Player:GetFriendsWhoPlayedAsync()` (friends who have played this game before, Roblox docs), which makes a "bring back your squad" panel: the prompt targets lapsed friends who already know the game. Lapsed returning users also count toward [[Creator Rewards]]' Audience Expansion as reactivated users; see [[Subscriptions and Premium Payouts]] for that program's rules rather than repeating them here.

## 3. Launch data: a hint, not a command

Launch data is how you send the arriving friend somewhere useful: the sender's location, a party code, a specific minigame. Three properties shape how you use it:

1. **It arrives late.** The docs say launch data can take a few seconds to appear after the friend joins, and the sample polls `GetJoinData()` up to 10 times at 1 second intervals. Code that reads it once in `PlayerAdded` will miss it.
2. **It is small.** 200 characters for invites and 200 bytes for notification launch data. JSON with long key names fills that quickly.
3. **It is not trustworthy.** Anyone can craft a share link or invite with arbitrary launch data. Treat it as a request: "this player would like to start at the sender's location". The server decides whether that is allowed.

A compact, versioned format avoids both the size and the trust problems:

```
v1|follow|<senderUserId>
v1|zone|<zoneKey>
v1|party|<shortCode>
```

The server parses it in `pcall`, rejects unknown versions and verbs, checks that `zoneKey` is in a whitelist and that the player has unlocked it, and only then acts. Never put amounts ("gems=500") or item ids to grant in launch data. A player who copies a launch string from a creator's video and edits it should get, at worst, a normal spawn.

`GetJoinData()` also carries `GameJoinContext`, which includes an `EventId` when a player joins from an event surface ([[Experience Notifications and Return Prompts]] covers events), and `TeleportData` for teleports. Each source has a different trust level; [[Teleporting and Multi-Place Games]] covers teleport data.

## 4. Designing referral rewards

### Who gets what
Two-sided rewards work better than inviter-only rewards (rule of thumb): the invitee gets a welcome gift that makes the first session better, and the inviter gets a reward that is visible to others. Good inviter rewards are cosmetic or status items: a title, a trail, a referral badge ([[Badges and Achievement Design]]). Currency works but is the riskiest, for the reasons in the abuse section.

The Creator Dashboard lets you publish a **reward banner** at the top of the friend invite modal (Engagement, Referral Rewards): icon, reward name, start and end dates, an optional description and an optional reward limit such as "up to 3 rewards per inviter". Only one banner can be published at a time, and the docs ask that it accurately describes the system you implemented (Roblox docs). The banner is a promise: your code must enforce the same cap the banner shows.

### When to pay
Pay on **qualification**, not on arrival. A qualified referral is an invitee who:
- is new to your game (no saved profile before this join), and
- has played for a meaningful time, for example 10 cumulative minutes, or finished the tutorial.

Ten minutes is not arbitrary: it matches the session bar Roblox uses for Creator Rewards attribution (see [[Subscriptions and Premium Payouts]]), and it makes alt farming slow. Tutorial completion is better if your tutorial is shorter than that.

### The offline inviter problem
The inviter is usually not in the invitee's server. They may be in another server, or offline. With session-locked profiles ([[Session Locking and Profile Libraries]]) one server cannot write into another player's profile. The pattern is a **mailbox**: a separate DataStore key per inviter that any server can append to with `UpdateAsync`, and that the inviter's own server reads and applies to their profile.

The mailbox must be:
- **Idempotent.** The same invitee must never be credited twice. Key entries by invitee user id.
- **Capped.** Lifetime and daily caps enforced at append time, so the mailbox cannot grow without bound and the banner's limit holds.
- **Append-only.** The inviter's server marks entries as applied in the inviter's own profile instead of deleting them from the mailbox. If the server crashes between granting and saving, the next session re-applies only what the profile does not yet record. No entry is lost and none is applied twice.

### Code: referral service

```lua
--!strict
-- ServerScriptService/Services/ReferralService (ModuleScript)
-- Requires: your profile module calls OnProfileLoaded(player, data, isNewProfile).
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local MAILBOX = DataStoreService:GetDataStore("ReferralMailbox_v1")
local CLAIMS = DataStoreService:GetDataStore("ReferralClaims_v1")
local TOPIC = "ReferralCredit"

local QUALIFY_SECONDS = 10 * 60
local LIFETIME_CAP = 20
local DAILY_CAP = 3

type MailEntry = { invitee: number, at: number }
type Mailbox = { entries: { MailEntry } }

export type ReferralData = {
	referredBy: number?, -- set once, only on a brand-new profile
	playSeconds: number,
	qualified: boolean,
	applied: { [string]: boolean }, -- invitee ids (as strings) already credited to me
	credits: number,
}

local ReferralService = {}
local live: { [Player]: ReferralData } = {}

local function utcDay(t: number): number
	return t // 86400
end

-- Launch data and ReferredByPlayerId can arrive a few seconds after join.
local function readJoinData(player: Player): { [string]: any }
	for _ = 1, 10 do
		if player.Parent ~= Players then
			break
		end
		local joinData = player:GetJoinData()
		if (joinData.ReferredByPlayerId and joinData.ReferredByPlayerId ~= 0) or (joinData.LaunchData and joinData.LaunchData ~= "") then
			return joinData
		end
		task.wait(1)
	end
	return player:GetJoinData()
end

local function grant(player: Player, data: ReferralData, inviteeId: number)
	-- Your reward: cosmetic, title, modest currency. Keep it in the profile.
	data.credits += 1
	data.applied[tostring(inviteeId)] = true
end

-- Apply any mailbox entries not yet applied to this profile.
local function drainMailbox(player: Player)
	local data = live[player]
	if not data then
		return
	end
	local ok, box = pcall(MAILBOX.GetAsync, MAILBOX, "inbox_" .. player.UserId)
	if not ok or type(box) ~= "table" then
		return
	end
	for _, entry in (box :: Mailbox).entries do
		if not data.applied[tostring(entry.invitee)] then
			grant(player, data, entry.invitee)
		end
	end
end

-- Called once when an invitee qualifies. Safe to call more than once.
local function creditInviter(inviteeId: number, inviterId: number)
	-- 1. One credit per invitee, ever, across all servers.
	local claimed = false
	local okClaim = pcall(function()
		CLAIMS:UpdateAsync("invitee_" .. inviteeId, function(old: any)
			if old ~= nil then
				return nil -- already claimed; cancel the write
			end
			claimed = true
			return { by = inviterId, at = os.time() }
		end)
	end)
	if not okClaim or not claimed then
		return
	end

	-- 2. Append to the inviter's mailbox, enforcing caps.
	local appended = false
	pcall(function()
		MAILBOX:UpdateAsync("inbox_" .. inviterId, function(old: any)
			local box: Mailbox = if type(old) == "table" then old else { entries = {} }
			if #box.entries >= LIFETIME_CAP then
				return nil
			end
			local today = utcDay(os.time())
			local todayCount = 0
			for _, e in box.entries do
				if e.invitee == inviteeId then
					return nil
				end
				if utcDay(e.at) == today then
					todayCount += 1
				end
			end
			if todayCount >= DAILY_CAP then
				return nil
			end
			table.insert(box.entries, { invitee = inviteeId, at = os.time() })
			appended = true
			return box
		end)
	end)
	-- If the caps rejected it, the claim stays used: that invitee cannot be
	-- re-credited later. This is deliberate and matches a "max N" banner.

	-- 3. Nudge the inviter's server if they are online somewhere (best effort).
	if appended then
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, inviterId)
	end
end

function ReferralService.OnProfileLoaded(player: Player, data: ReferralData, isNewProfile: boolean)
	live[player] = data
	drainMailbox(player)

	if isNewProfile and data.referredBy == nil then
		task.spawn(function()
			local joinData = readJoinData(player)
			local by = joinData.ReferredByPlayerId
			if typeof(by) == "number" and by > 0 and by ~= player.UserId and live[player] == data then
				data.referredBy = by
				-- Invitee welcome gift goes here (small, one time).
			end
		end)
	end
end

-- Call from your playtime tick (for example every 30 seconds).
function ReferralService.AddPlaytime(player: Player, seconds: number)
	local data = live[player]
	if not data or data.qualified or not data.referredBy then
		return
	end
	data.playSeconds += seconds
	if data.playSeconds >= QUALIFY_SECONDS then
		data.qualified = true
		task.spawn(creditInviter, player.UserId, data.referredBy :: number)
	end
end

Players.PlayerRemoving:Connect(function(player)
	live[player] = nil
end)

task.spawn(function()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local inviter = Players:GetPlayerByUserId(message.Data)
			if inviter then
				drainMailbox(inviter)
			end
		end)
	end)
	if not ok then
		warn("[Referral] subscribe failed", err)
	end
end)

return ReferralService
```

Notes:
- `qualified = true` is set in the invitee's profile before the cross-server write. If `creditInviter` fails (DataStore outage), the inviter loses that credit. To make it bulletproof, store `creditPending = true` and retry on the invitee's next session until the claim succeeds; the claim key makes the retry safe.
- The MessagingService nudge is best effort ([[Cross-Server Messaging]]). The guaranteed path is the drain on the inviter's next join. Add a periodic drain (every few minutes) for long sessions.
- Write budgets: each qualification costs two `UpdateAsync` calls. Even a viral day of 10,000 qualified referrals is spread across many servers and well inside per-server DataStore limits ([[DataStore Fundamentals]]).

## 5. Abuse and alt accounts

Referral rewards pay for new accounts, and new accounts are free to make. Expect farming the day a valuable reward ships. Mitigations, from strongest to weakest (rule of thumb):

| Mitigation | Effect | Cost |
|---|---|---|
| Qualification by playtime or progress | Each alt costs 10+ minutes of real play | Some honest referrals never qualify |
| Lifetime and daily caps per inviter | Bounds the total payout per account | Popular creators hit the cap |
| Cosmetic, untradeable rewards | Nothing to funnel into a main account | Weaker incentive |
| No tradeable currency or items to invitees | Stops alts feeding trades to the main | Weaker welcome gift |
| Watching outliers | Inviters with many qualified invitees who all stop playing after 10 minutes | Manual review time |

Two traps:
- **Do not reject low `AccountAge` invitees outright.** Brand-new Roblox accounts brought in by a friend are exactly the players the platform rewards you for (Audience Expansion counts new users). Gate the *reward* on qualification, not the invitee's account age.
- **Tradeable rewards connect referrals to your trading economy.** An alt that receives a tradeable welcome pet can trade it to the main account. If you have trading, keep referral rewards untradeable ([[Trading Systems Without Duplication]], [[Economy Exploits - Dupes Races and Purchase Abuse]]).

## 6. Policy and fairness
- **Never require an invite to progress.** Players without friends on Roblox, players on restricted accounts, and players for whom `CanSendGameInviteAsync` returns false must be able to get everything important. A referral badge or title is fine as a bonus; a zone unlock is not ([[Ethical Design and Player Trust]]).
- Hide the invite button when `CanSendGameInviteAsync` returns false rather than showing a button that fails.
- Do not promise rewards in the invite notification text that the invitee will not actually get. The notification string is a message to someone who has not played yet; "{displayName} wants you to join their adventure in {experienceName}!" is the safe template.

## 7. Measuring the funnel

Because you cannot see sends, the funnel is:

| Step | Source |
|---|---|
| Invite prompt opened | Your own log at the moment you call `PromptGameInvite` |
| Share sheet opened | Your log when `PromptLinkSharingAsync` succeeds; `ShareSheetClosed` |
| Arrival with `ReferredByPlayerId` | Server log on join |
| Arrival with your launch data verb | Server log on join |
| Qualified referral | Your qualification event |
| Day 7 retention of referred players | Compare cohorts in [[Analytics and Funnels]] |

`AnalyticsService:LogCustomEvent(player, eventName, value?, customFields?)` is enough for the in-game steps. Creator Hub share link analytics cover off-platform links. The metric that matters is the last row: referred players usually retain better than strangers because they arrive with a friend (rule of thumb); if yours do not, your first session is not built for two.

## 8. Common mistakes

| Mistake | Fix |
|---|---|
| Rewarding on prompt open or on `GameInvitePromptClosed` | Reward on qualified arrival |
| Reading `LaunchData` once in `PlayerAdded` | Poll for a few seconds |
| Long `PromptMessage` | Keep it short; overflowed text is not shown |
| Writing rewards into the inviter's profile from the invitee's server | Mailbox key with `UpdateAsync` |
| Launch data that grants items | Launch data only routes; the server validates |
| Banner says "max 3" but code has no cap | Enforce the cap at append time |
| Rejecting new accounts | Gate rewards on qualification instead |

## 9. Checklist
- [ ] `CanSendGameInviteAsync` checked; button hidden when false
- [ ] Invite placed at moments that benefit from company, behind the pop-up gate
- [ ] Notification string includes `{experienceName}`; prompt message short
- [ ] Launch data versioned, whitelisted, under 200 characters, read with retries
- [ ] Referral credited on qualification; one claim per invitee
- [ ] Mailbox is append-only, capped, applied idempotently
- [ ] Rewards cosmetic or untradeable; caps match the published banner
- [ ] Funnel logged from prompt to day 7 retention
- [ ] Nothing important gated behind inviting

## See also
[[Platform Features Start Here]] · [[Social Design and Multiplayer Play]] · [[Community Building]] · [[Parties and Group Teleports]] · [[Cross-Server Messaging]] · [[Session Locking and Profile Libraries]] · [[Launch Strategy - The First Two Weeks]] · [[Working with Content Creators]] · [[Official Docs - Publishing and Live Ops]]

## Connected notes
<!-- auto-links:start -->
[[Discovery and the Algorithm]] · Live Ops Events and Updates · [[Avatar Context Menus Profiles and Social Surfaces]] · Short-Form Video Marketing · Sponsored Ads and Campaign Math · Codes Redemption System End to End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Photo Mode and In-Game Screenshots with CaptureService]] · [[Subscriptions and Recurring Revenue]] · [[Discovery and Monetization Changes 2025-2026]] · [[Commerce and Physical Goods]] · [[Roblox Changes 2025-2026]] · [[API Renames and Deprecations 2025-2026]] · [[Regional Compliance - Paid Random Items and Country Rules]]
<!-- related:end -->
