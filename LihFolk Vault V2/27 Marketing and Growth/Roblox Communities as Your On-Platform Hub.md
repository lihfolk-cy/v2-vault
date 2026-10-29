---
tags: [type/guide, area/marketing, level/intermediate, api/Player, api/GetRolesInGroupAsync]
---
<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One group for games, funds and fans. A compromised moderator becomes a game and payout risk.
> - Avoid: Deprecated `IsInGroup` / `GetRankInGroup` (and now `GetRankInGroupAsync`).
> - Avoid: Client-granted member perks. Re-check on the server.
> - Owning group and fan Community decided (separate once you have staff).
> - Stable rank numbers; few roles with clear permissions.
> - Membership checked server-side with async APIs, cached, re-checkable.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## The naming split (Roblox announcement) · ## In-game: perks and prompts · ## Common mistakes · ## Checklist
<!-- tldr:end -->

---
tags: [marketing, community, communities, groups, announcements, roles, forums, group-perks, retention, type/guide, area/growth, area/community]
---
# Roblox Communities as Your On-Platform Hub

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One group for games, funds and fans. A compromised moderator becomes a game and payout risk.
> - Avoid: Deprecated `IsInGroup` / `GetRankInGroup`.
> - Avoid: Client-granted member perks. Re-check on the server.
> - Owning group and fan Community decided (separate once you have staff).
> - Stable rank numbers; few roles with clear permissions.
> - Membership checked server-side with async APIs, cached, re-checkable.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## The naming split (Roblox announcement) · ## In-game: perks and prompts · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox Groups were renamed **Communities** on the player-facing side in November 2024. A Community is the only fan hub that lives entirely on Roblox: players can join from inside your game, see announcements, take part in forums, and carry roles that your game can read. With external links and social handles restricted by age and policy in 2026, the Community has become the default home for announcements and codes. This note covers using it as a hub: structure, roles, in-game perks, join prompts and moderation. The broader strategy (why community matters, Discord, creators) is in [[Community Building]] and [[Discord Servers for Roblox Games]]; permissions for a studio's working group are in [[Groups Roles and Permissions for Studios]].

Source labels: **Roblox docs**, **Roblox announcement** (official DevForum), **Reported** (DevForum community thread), **Rule of thumb**.

## The naming split (Roblox announcement)

The November 2024 announcement "Introducing Roblox Communities" (https://devforum.roblox.com/t/introducing-roblox-communities/3268307) renamed Groups to Communities for players, added a **Ban User** feature, renamed Exile to **Kick User**, and updated Open Cloud to make automated membership and role assignment easier. Roblox staff have said the creator-side product (Creator Hub, DevEx, group-owned experiences) is still called **Groups** (Reported, DevForum documentation thread). Engine APIs still use "Group" names: `GroupService`, `Player:IsInGroupAsync`, `GroupService:GetRolesInGroupAsync`.

A related update limited Wall access to users 13 and over and said Forums will eventually replace Walls as the discussion space (Reported via the DevForum announcement thread; check your Community's current settings).

Practical consequence: one group can be both your studio's owning group and your player Community, or you can separate them. Rule of thumb: **separate them** once you have staff and revenue. The owning group holds games, funds and Team Create permissions; the fan Community holds players, announcements and perks. A compromised fan-community moderator then cannot touch your games or funds ([[Creator Account Security and Takeover Recovery]]).

## Structure that works

| Element | Use it for | Rule of thumb |
|---|---|---|
| Name and emblem | Same brand as the game icon | Recognisable at small size |
| Description | What the game is, how to get codes, rules | Short; no external handles |
| Announcements / shout | Updates, codes, event start times | One per update; never spam |
| Forums (where available) | Feedback, bug reports, suggestions | Pinned categories; moderated |
| Roles | Member, Tester, Contributor, Moderator, Staff | Few roles; clear permissions |

Keep rank numbers stable (for example Member 1, Tester 50, Moderator 200) because your game code will read ranks, not role names.

## In-game: perks and prompts

### Member perks
A small, cosmetic or convenience perk for Community members (a chat tag, a title, a modest currency bonus) is common and allowed. Do not reward likes, favourites or off-platform social actions ([[Community Building]]).

```lua
--!strict
-- Server: check membership with the non-deprecated async API, fail closed, cache per session.
local GROUP_ID = 0 -- your Community id
local memberCache: {[Player]: boolean} = {}

local function isMember(player: Player): boolean
	local cached = memberCache[player]
	if cached ~= nil then return cached end
	local ok, result = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)
	local member = ok and result == true
	memberCache[player] = member
	return member
end

local function recheck(player: Player)
	memberCache[player] = nil
	return isMember(player)
end
```

Membership results can be cached by the engine for a while, so a player who joins mid-session may not register immediately. Offer a "Claim member perk" button that calls `recheck` with a cooldown, rather than re-querying constantly.

### Join prompts
`GroupService:PromptJoinAsync(groupId)` shows the join prompt from the client and returns an `Enum.GroupMembershipStatus` such as `Joined`, `JoinRequestPending` or `AlreadyMember` (Roblox docs). Wrap it in `pcall`. Treat anything other than `Joined` and `AlreadyMember` as "not joined" and do not grant perks client-side; tell the server to re-check.

Prompt rules of thumb: never on join, never during onboarding, at most once per session, and only after a positive moment (a first win, a boss kill), with a clear "no thanks".

### Ranks in game
Moderators and testers can get in-game tools by rank. In the current API dump `Player:GetRankInGroupAsync` is marked deprecated in favour of `GroupService:GetRolesInGroupAsync(userId, groupId)`, which returns membership and a list of roles, each with `Name` and `Rank` (Roblox docs, GroupService page, read 29 October 2026). A user can hold more than one role, so take the highest rank:

```lua
local GroupService = game:GetService("GroupService")

local function rankOf(player: Player): number
	local ok, info = pcall(function()
		return GroupService:GetRolesInGroupAsync(player.UserId, GROUP_ID)
	end)
	if not ok or typeof(info) ~= "table" or not info.IsMember then
		return 0
	end
	local best = 0
	for _, role in info.Roles or {} do
		if typeof(role.Rank) == "number" and role.Rank > best then
			best = role.Rank
		end
	end
	return best
end
```

Gate admin commands on the **server** by rank, and keep the most powerful tools for your owning group, not the fan Community. Log every moderator action ([[Logging Bans and Appeals]]).

## Automation

Open Cloud can assign memberships and roles programmatically (Roblox announcement, November 2024). Common uses: grant a Tester role to everyone who completes a sign-up, or a Contributor role after a merged community translation. Keep API keys scoped to the one group and operation, with expiry and IP restrictions where possible ([[Open Cloud APIs]]).

## Moderation and safety

- Use **Ban User** for repeat offenders in the Community; it is distinct from your in-game ban system ([[Logging Bans and Appeals]]).
- Moderators should be adults you trust with clear written rules, 2-step verification on, and no access to funds or games.
- Do not ask for or collect personal information in Community posts or forums.
- Announcements reach children; follow the creative rules in [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]].

## Using it as a retention channel

- Post codes in announcements on update day, and mention in-game that "codes are posted in our Community" (without external links).
- Pair announcements with Experience Notifications for players who opted in ([[Experience Notifications and Return Prompts]]).
- Read forums weekly; tag recurring complaints into your backlog. Reply to a few posts publicly so players see the loop closing.

## Common mistakes

- **One group for games, funds and fans.** A compromised moderator becomes a game and payout risk.
- **Deprecated `IsInGroup` / `GetRankInGroup` (and now `GetRankInGroupAsync`).** Use `IsInGroupAsync` and `GroupService:GetRolesInGroupAsync` in `pcall`.
- **Client-granted member perks.** Re-check on the server.
- **Join prompt on join or during the tutorial.**
- **Rewarding social actions.** Not allowed; reward membership modestly instead.
- **Rank-gated admin tools checked on the client.**

## Checklist

- [ ] Owning group and fan Community decided (separate once you have staff).
- [ ] Stable rank numbers; few roles with clear permissions.
- [ ] Membership checked server-side with async APIs, cached, re-checkable.
- [ ] Join prompt after a positive moment, at most once per session.
- [ ] Announcements per update with codes; no external handles.
- [ ] Moderators adult, trusted, 2SV on, no fund access.
- [ ] Open Cloud keys scoped and expiring.

## See also

- [[Community Building]]
- [[Groups Roles and Permissions for Studios]]
- [[Discord Servers for Roblox Games]]
- [[Codes Redemption System End to End]]
- [[Experience Notifications and Return Prompts]]

## Connected notes

[[Creator Account Security and Takeover Recovery]] · Logging Bans and Appeals · Community and Moderation Start Here · [[Marketing and Growth Start Here]]

<!-- related:start -->
## Related
[[Short-Form Video Marketing]] · [[Launch Strategy - The First Two Weeks]] · [[Update Cadence and Hype Cycles]] · [[Experience Description and Search Keywords]] · [[Competitor Analysis Method]] · [[Sponsored Ads and Campaign Math]]
<!-- related:end -->
