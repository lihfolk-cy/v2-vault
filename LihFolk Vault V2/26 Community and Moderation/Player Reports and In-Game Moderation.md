---
tags: [community, moderation, safety, reports, ban-api, luau, live-ops, type/guide, area/community, level/intermediate, api/DataStoreService, area/scripting]
---
# Player Reports and In-Game Moderation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Report spam -> Weight by distinct reporters and servers; cap per target
> - Avoid: Moderator abuse -> Weekly log review; remove first, investigate second
> - Avoid: Kicking for safety issues instead of escalating -> Moderator script: platform report first
> - Platform report reachable; players told where it is
> - Rule-report flow with categories, no free text, server-attached context
> - Reports rate-limited, retained for a fixed window, user ids only
>
> Cost: TL;DR ~160 tok · whole note ~4.8k tok. Read more: ## 3. An in-game report flow for your rules · ## 4. Moderating what players create · ## 8. Failure modes · ## 10. Checklist
<!-- tldr:end -->

Roblox moderates its platform; you moderate your game. The two overlap but are not the same job. Roblox handles anything that breaks the Community Standards (harassment, sexual content, grooming, hate, scams, real-world threats) through its report system and moderators. You handle your own game's rules (griefing, spawn-camping, exploiting, trade scams in your economy, abusing a mechanic) and you are responsible for the safety of what your game lets players create and show each other. This note covers where the line sits, the Safety Dashboard, building an in-game report flow that does not collect personal data, moderating user-generated content, staffing moderators, and the tools that act (kick, ban, mute, restrict). For the Ban API itself, evidence and appeals, read [[Logging Bans and Appeals]]; for cheat detection, [[False Positives Lag and Fair Enforcement]].

Facts are labelled "Roblox docs (as of October 2026)", "Help Center", "measured in the reference project" or "rule of thumb".

---

## 1. Safety first: the split of responsibilities

| Problem | Who acts | Your job |
|---|---|---|
| Child endangerment, grooming, sexual content, threats, self-harm | Roblox, through the platform report | Make the platform report easy to find; remove the player from your server; never investigate yourself |
| Harassment, hate, bullying in chat or voice | Roblox, plus you for your server | Kick or mute in your game; the player reports to Roblox |
| Scams for Robux or accounts | Roblox | Anti-scam messages; no free-text in trades |
| Breaking your game's rules (griefing, exploiting, AFK farming in ranked) | You | Your report flow, your enforcement, your appeals |
| Unsafe things your game displays (unfiltered text, inappropriate builds or images) | You, and Roblox may moderate the game | Filter and design so it cannot happen |

The Help Center says custom experience-rule violations may not be reported through Roblox's Report Abuse, and Roblox does not handle appeals for them; creators handle those themselves (Help Center, as summarized in search results; the page itself blocked direct fetching, so re-read it). Two consequences:

1. Your report button is for **your** rules. Label it that way ("Report rule-breaking in this game") and also point to the platform report for safety issues.
2. Never set up a process where a child tells your volunteer moderator about abuse and the moderator handles it privately. Anything about a player's safety goes to Roblox. A moderator's script for that case is short: "Thank you. Please use Roblox's Report button on that player now; I am removing them from this server."

Also from the docs (Safety guide): the Maturity & Compliance Questionnaire must be truthful and kept current; repeated incorrect answers can lead to moderation of the game and account ([[Roblox Policies Ratings and Compliance]]). Moderation starts with honest labelling.

---

## 2. The Safety Dashboard (Roblox docs)

Creator Dashboard, your game, **Safety**, **Overview**:
- **Abuse report submitters per 1,000 playtime hours**: unique users who reported, normalized. Visible only with 1,000+ daily playtime hours in the past week.
- **Total abuse reports per category**: categories are chosen by reporters and can be wrong; Roblox moderators confirm before acting.
- **Channels**: Avatar, Chat, Voice, Experience, Audio. Filter both charts by channel; the benchmark follows.
- **Automated insights** appear when your submitter rate is above the 90th percentile benchmark, overall or per channel.

Reading it (rule of thumb):
- Look at **changes**, not levels. A spike the week a feature shipped points at the feature.
- **Avatar** spikes: avatar editor, outfit loading, or accessories in your game are being used for inappropriate looks. The docs suggest restricting editors if abuse rises.
- **Chat** spikes: a social area or mechanic invites harassment (lobbies where people wait with nothing to do, PvP losers with time to type).
- **Experience** spikes: players are reporting the game itself. Check the content, thumbnails and anything players can build.
- The "Romance or sexual" category climbing is the docs' own example of a reason to review avatar editors and chat. Act on it the same week.

Small games under the 1,000-hour threshold see little. Use your own report counts until then.

---

## 3. An in-game report flow for your rules

Goals: fast for the reporter, useless to abusers, no personal data, enough context to act.

Design rules (rule of thumb):
- **No free-text box.** Free text collects personal data, gets used to harass ("report: you're ugly") and cannot be shown to moderators without filtering. Use fixed categories: Griefing, Exploiting or cheating, Teaming or boosting, Scamming in trades, Offensive build or name, Other game rule.
- **The server attaches the context**, not the client: positions of both players, recent damage events, trade ids, the build id. The client sends only target and category.
- **Rate-limit per reporter** and cap reports per target per server so one angry player cannot flood the queue.
- **Tell the reporter what happens** and offer immediate self-help: block, mute, leave, change server.
- **Pair it with Block.** A report does nothing for the next five minutes; blocking does.

```lua
--!strict
-- Server: in-game rule report. Client fires (targetUserId: number, categoryIndex: number).
-- Reviewed, not run.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReportPlayer") :: RemoteEvent
local reportStore = DataStoreService:GetDataStore("RuleReports_v1")

local CATEGORIES = { "Griefing", "Exploiting", "Teaming", "TradeScam", "OffensiveBuild", "OtherRule" }
local REPORT_COOLDOWN = 60 -- seconds per reporter
local MAX_PER_TARGET = 5 -- per server

local lastReport: { [number]: number } = {}
local perTarget: { [number]: number } = {}

local function positionOf(p: Player): { number }?
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local v = root.Position
	return { math.floor(v.X), math.floor(v.Y), math.floor(v.Z) }
end

ReportRemote.OnServerEvent:Connect(function(reporter: Player, targetId: unknown, categoryIndex: unknown)
	if typeof(targetId) ~= "number" or typeof(categoryIndex) ~= "number" then
		return
	end
	local category = CATEGORIES[categoryIndex]
	local target = Players:GetPlayerByUserId(targetId)
	if not category or not target or target == reporter then
		return
	end
	local now = os.time()
	if now - (lastReport[reporter.UserId] or 0) < REPORT_COOLDOWN then
		return
	end
	if (perTarget[targetId] or 0) >= MAX_PER_TARGET then
		return
	end
	lastReport[reporter.UserId] = now
	perTarget[targetId] = (perTarget[targetId] or 0) + 1

	local record = {
		v = 1,
		t = now,
		jobId = game.JobId,
		placeVersion = game.PlaceVersion,
		reporter = reporter.UserId,
		target = targetId,
		category = category,
		reporterPos = positionOf(reporter),
		targetPos = positionOf(target),
		-- add server-side context here: recent kills by target, trade ids, build id
	}
	local key = `{os.date("!%Y%m%d", now)}_{HttpService:GenerateGUID(false)}`
	task.spawn(function()
		pcall(function()
			reportStore:SetAsync(key, record)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastReport[p.UserId] = nil
end)
```

Notes on the sketch:
- **Storage choice.** A data store keyed by date and GUID is simple and durable; moderators list keys by date prefix with `ListKeysAsync` from a tool or Open Cloud ([[Open Cloud APIs]]). A `MemoryStore` sorted map is better for a live queue in a busy game but expires ([[MemoryStore Service]]). Do not post reports to an external webhook with usernames; user ids only, and the destination becomes a place you must secure and eventually purge ([[Player Privacy and Data Deletion]]).
- **Retention.** Delete reports after a fixed window (30 to 90 days, rule of thumb), and honour right-to-erasure requests for user ids in them.
- **Data store budget.** One `SetAsync` per report is far under the per-server write limits, but a raid where 30 players report each other at once is 30 writes in a second. The cooldown and per-target cap keep this bounded ([[DataStore Fundamentals]]).
- **Reports are signals, not verdicts.** Friends report enemies; losers report winners. Weight by distinct reporters across distinct servers, and look for server-side evidence before acting ([[False Positives Lag and Fair Enforcement]]).

---

## 4. Moderating what players create

Anything a player authors that others see is your responsibility: names (pets, guilds, plots), signs and boards, drawings, builds, outfits made in your editor, uploaded or chosen images, music choices.

### Text
Filter every string server-side with `TextService:FilterStringAsync` and show the right variant for the audience: `GetNonChatStringForBroadcastAsync` for everyone, `GetNonChatStringForUserAsync` per viewer. The Safety guide is blunt: Roblox may remove a game that does not apply text filtering until filtering is added (Roblox docs). Filter at display time, keep raw text only if you must, never on the client ([[Age Checks and Safety Features]] has the code).

Edge cases (rule of thumb):
- **Concatenation.** Filtering "free" and "robux" separately, then joining them, defeats the filter. Filter the final displayed string.
- **Numbers.** Phone numbers and handles get through as digits spread across fields. Do not offer several adjacent short text fields that a player can use as one message.
- **Per-character art.** Signs made from many one-letter parts spell anything. Grid-based letter blocks need a review or a ban on letter pieces in public areas.
- **Filter failures.** On an error, show nothing (or a placeholder), never the raw text.

### Builds and drawings
Filters do not understand shapes. Options from the Safety guide: pre-moderation, limiting reach, restricting privileges to trusted users, or preset-only customization (Roblox docs). In practice:

| Approach | Cost | Fits |
|---|---|---|
| Preset pieces only, no free placement on public surfaces | Low | Most games |
| Builds visible only to the builder and friends until reviewed | Medium | Building games with showcases |
| Trusted-builder role (time played, verified, no reports) | Medium | Plot-based games |
| Human review queue for featured builds | High | Any "featured" or "front page" spot |
| "Hide this build" per viewer, plus report | Low | Every building game, as a safety net |

`Player:IsVerified()` (identity verified) can gate high-risk creative privileges, and the docs suggest it as a deterrent to cheating, scamming and harassment; explain the benefit clearly to players (Roblox docs). It is not an age check.

### Avatars
If your game lets players change outfits or bodies, bounding boxes and preset options reduce abuse. The docs mention bounding-box limits on items like beds and avoiding primarily private settings in under-18 games.

---

## 5. Tools that act, from mild to severe

| Action | API or method | Use for |
|---|---|---|
| Hide for the reporter | Your own client-side hide (builds, names) plus platform block | Immediate relief |
| Game mute | `TextSource.CanSend = false` ([[Text Chat Customization with TextChatService]]) | Spam, rule-breaking chat in your game |
| Restrict a privilege | Attribute or profile flag (no building, no trading) | Repeat griefing or trade abuse |
| Kick | `Player:Kick(message)` (Roblox docs: the safety guide notes trusted users can be designated to trigger it) | Ongoing disruption in this server |
| Timed or permanent ban | `Players:BanAsync` with duration and reasons ([[Logging Bans and Appeals]]) | Exploiters, repeat offenders |
| Data correction | Your admin tools | Economy damage from exploits |

Choose the mildest action that stops the harm. Kicks escalate tempers; a muted griefer who cannot build is often quieter than a kicked one who rejoins on an alt.

---

## 6. Moderators: who, how many, and with what powers

### Staffing (rule of thumb)
- **One trusted adult per peak hour per 1,000 concurrent players** is a reasonable starting point for a social game; a combat simulator can run with far fewer because its abuse is mostly exploiting, handled by automation.
- Moderators who will see read-only chat need the group permission "Moderate experiences", which requires the member to be **18+** and also allows banning across all group games (Roblox docs, Groups). Younger volunteers can still be helpers (answering questions, reporting), not enforcers.
- Volunteers burn out. Rotate, cap shifts, and never make moderation a condition of a reward that matters.

### Powers (rule of thumb)
- Give the smallest set: kick, game mute, restrict, view rule reports. Bans by senior staff only.
- **Server-checked rank on every action.** Read the rank with `GroupService:GetRolesInGroupAsync` (highest role's `Rank`) on the server; the panel UI is cosmetic ([[Groups Roles and Permissions for Studios]]).
- **Log every action**: moderator id, target id, action, reason code, server job id, time. Review weekly. A moderator abusing power destroys trust faster than any exploiter ([[Community Building]]).
- **Two-person rule** for permanent bans and data changes in bigger teams.

### Moderator conduct
A one-page written policy, read and accepted before access: do not moderate friends or rivals; no private messaging of players off-platform; do not ask any player for personal information; never promise outcomes; escalate safety issues to Roblox; do not discuss cases publicly. This matters more than any tool.

---

## 7. Moderator panel sketch

```lua
--!strict
-- Server: moderator actions over one remote, rank-checked and logged.
-- Reviewed, not run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GROUP_ID = 0
local RANKS = { kick = 150, mute = 150, ban = 230 }
local ModAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ModAction") :: RemoteEvent

local function rankOf(p: Player): number
	local ok, rank = pcall(function()
		-- highest public role; Roles is ordered highest first (GetRankInGroupAsync is deprecated)
		local info = game:GetService("GroupService"):GetRolesInGroupAsync(p.UserId, GROUP_ID)
		return if info.IsMember and info.Roles[1] then info.Roles[1].Rank else 0
	end)
	return if ok then rank else 0
end

local function log(entry: { [string]: any })
	-- write to your moderation log store (append-only); see Logging Bans and Appeals
end

ModAction.OnServerEvent:Connect(function(mod: Player, action: unknown, targetId: unknown, reasonCode: unknown)
	if typeof(action) ~= "string" or typeof(targetId) ~= "number" or typeof(reasonCode) ~= "number" then
		return
	end
	local needed = RANKS[action]
	if not needed or rankOf(mod) < needed then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or rankOf(target) >= rankOf(mod) then
		return -- cannot act on peers or seniors
	end
	if action == "kick" then
		target:Kick("Removed by a moderator for breaking this game's rules.")
	elseif action == "mute" then
		-- muteFor(target.UserId, 600) from the chat note
	elseif action == "ban" then
		-- call your enforcement module (Logging Bans and Appeals)
	end
	log({ mod = mod.UserId, target = targetId, action = action, reason = reasonCode, job = game.JobId, t = os.time() })
end)
```

Group rank lookups are cached per session by the engine (rule of thumb, widely observed for the older `GetRankInGroup`; cache your own result from `GetRolesInGroupAsync` the same way). A moderator demoted mid-session keeps old powers until rejoin; for removals, also keep a server-side deny list in live config ([[Global State and Live Config]]).

---

## 8. Failure modes

| Failure | What it looks like | Fix |
|---|---|---|
| Report spam | Hundreds of reports against a top player | Weight by distinct reporters and servers; cap per target |
| Moderator abuse | Players claim unfair kicks from one name | Weekly log review; remove first, investigate second |
| Kicking for safety issues instead of escalating | Abuse continues on the platform | Moderator script: platform report first |
| Unfiltered UGC | Inappropriate names on leaderboards | Filter at display; leaderboards too |
| Report button that asks for details | Harassment through reports; personal data stored | Categories only |
| Safety Dashboard ignored | Automated insight sits for weeks | Weekly review in the release checklist ([[QA Checklists Before Release]]) |

---

## 9. When not to build all this

A small obby with no chat-adjacent features, no UGC and no trading needs: default chat, filtered names if any, Kick and Ban for the owner, and a weekly look at the dashboard. Build the report flow and moderator team when you have player-made content, trading, social spaces, or more than a few hundred concurrent players.

---

## 10. Checklist

- [ ] Platform report reachable; players told where it is
- [ ] Rule-report flow with categories, no free text, server-attached context
- [ ] Reports rate-limited, retained for a fixed window, user ids only
- [ ] All player text filtered at display; builds and drawings have a review or reach limit
- [ ] Moderators with written conduct rules; safety issues escalated to Roblox
- [ ] Every action server-rank-checked and logged
- [ ] Safety Dashboard reviewed weekly, especially after releases
- [ ] Questionnaire answers updated when features change

## See also
[[Community and Moderation Start Here]] · [[Logging Bans and Appeals]] · [[False Positives Lag and Fair Enforcement]] · [[Text Chat Customization with TextChatService]] · [[Voice Chat and Safety Features]] · [[Groups Roles and Permissions for Studios]] · [[Age Checks and Safety Features]] · [[Community Building]] · [[Social Design and Multiplayer Play]] · [[Server Authority and Validation]] · [[Rate Limiting and Abuse Prevention]]

## Connected notes
<!-- auto-links:start -->
[[Discord Servers for Roblox Games]] · [[Anti-Exploit Start Here]] · Skill - Roblox Anti-Exploit Review · Links - Chat and text filtering · Genre Playbook - Roleplay and Social Hangouts · Avatar Context Menus Profiles and Social Surfaces
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Admin Commands Done Safely - Permissions and Audit Logs]] · [[Working with Content Creators]] · [[Roblox Communities as Your On-Platform Hub]] · [[Block and Mute Respecting Platform Rules]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[Genre Playbook - Roleplay and Social Hangouts]]
<!-- related:end -->
