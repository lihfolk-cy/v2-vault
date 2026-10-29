---
tags: [community, groups, social, invites, live-ops, luau, type/guide, area/monetization, level/intermediate, api/SocialService, area/scripting, api/TextChatService]
---
# Community Building

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Group join prompts on join, repeated every few minutes, during the tutorial.
> - Avoid: Rewarding likes, favourites or social posts.
> - Avoid: External social handles in game text (no longer allowed).
> - Friend boost and at least one co-op reason to play together
> - Invite button using `CanSendGameInviteAsync` and launch data; reward after real play
> - Group perk, re-checkable mid-session; prompt gated and capped
>
> Cost: TL;DR ~150 tok · whole note ~3.5k tok. Read more: ## 2. Friends and co-play in-game · ## 3. Groups · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

A community is the set of players who care about your game beyond one session: group members, friends who play together, people who read your update notes, report bugs and suggest features. On Roblox the community is also measurable value: co-play days are a recommendation signal, share links feed [[Creator Rewards]]' Audience Expansion, and group members are reachable on your group page. This note covers the in-game social features that grow a community, groups, invites and share links, the 2026 limits on external links, and how to run feedback without letting the loudest voices drive the game. Platform facts are marked with their source and were checked **as of October 2026**; strategy is rule of thumb.

---

## 1. Why community is not optional

From the discovery docs ([[Discovery and the Algorithm]]):
- **Intentional co-play days per user** (days players return to play with friends, via joins, invites or private servers) is a ranking signal.
- **Play days per user** across days 2 to 7 and 8 to 28 is a ranking signal. Players with friends in the game return more (rule of thumb, widely observed).

From Creator Rewards ([[Subscriptions and Premium Payouts]]):
- **Audience Expansion** pays a revenue share for new and reactivated users attributed to you; share links have their own attribution and analytics tab.

So the social layer is a growth system, not decoration.

---

## 2. Friends and co-play in-game

### Reward playing together
- **Friend boost:** a small multiplier per friend in the server (capped). The reference project had a friend luck boost with its own HUD chip.
- **Party goals:** quests that need two players, shared bosses where everyone in range gets credit.
- **Social visibility:** server-wide announcements for rare drops (the reference game's roll feed announced high-rarity pulls and server luck purchases). Seeing others succeed is a reason to stay in a populated server and a reason to show friends.
- **Trading** (if your economy allows it) creates relationships; gate paid items by policy and price level ([[Pricing and Store Design]], [[Roblox Policies Ratings and Compliance]]).

### Invites
`SocialService` provides the platform invite prompt. Check `SocialService:CanSendGameInviteAsync(player)` (in `pcall`) and then `SocialService:PromptGameInvite(player, options?)`, where an `ExperienceInviteOptions` instance can carry launch data so the invited friend arrives somewhere specific. Players can only invite people they are allowed to communicate with under platform rules.

```lua
--!strict
-- LocalScript: an invite button that only shows when inviting is possible.
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local button = script.Parent :: TextButton

local ok, canInvite = pcall(function()
	return SocialService:CanSendGameInviteAsync(player)
end)
button.Visible = ok and canInvite == true

button.Activated:Connect(function()
	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = "Roll with me!"
	options.LaunchData = "invite:hub" -- read on join via player:GetJoinData()
	SocialService:PromptGameInvite(player, options)
end)
```

Read `LaunchData` on the server from `player:GetJoinData()` to reward the inviter after the friend actually plays (for example 10 minutes), never on click. Rewarding clicks invites spam.

### Share links
Creator Hub share links have an Analytics tab with clicks, signups, reactivations and estimated payout (Docs, Creator Rewards). Put sharing where players feel proud: after a rare drop, a personal best, a completed event. Keep it one tap and never required.

---

## 3. Groups

A group (community) is the home of your game's audience on Roblox: wall, events tab, roles for testers and moderators, group-owned games and group revenue.

### Group-owned games
Owning the game through a group makes team access, revenue splits and permissions manageable, and survives one person leaving. Asset permissions matter: assets used by a group game (animations especially) must be owned by the group or shared to it ([[Animation Asset Permissions and Groups]]). For Creator Rewards' Audience Expansion in a group game, a group member who can configure group revenue must meet the ID-verification requirement (Docs).

### Group membership rewards
A perk for joining your group (luck, cash, a title) is a common and effective growth tool.

```lua
--!strict
-- Server: grant a group member perk. IsInGroup results are cached per session by the engine
-- (rule of thumb), so offer a "check again" path after the player joins mid-session.
local Players = game:GetService("Players")
local GROUP_ID = 0 -- your group id

local function refreshGroupPerk(player: Player)
	if GROUP_ID == 0 then
		return
	end
	local ok, isMember = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)
	if ok then
		player:SetAttribute("GroupMember", isMember)
	end
end

Players.PlayerAdded:Connect(refreshGroupPerk)
```

**Reference project.** Group members got a 1.5x luck multiplier. Membership was checked on join and re-checked through a "check" remote that used `GroupService:GetGroupsAsync` (a fresh lookup) because the cached check would not see a player who joined the group mid-session. A community prompt asked non-members to join: first after 90 seconds, then every 15 minutes, at most 4 times per session, and only after the tutorial and when no other panel was up. A "like the game" reminder appeared once at 10 minutes with no reward (rewarding likes is the kind of incentive that platforms often prohibit; a reminder is safe). A favourite prompt waited 25 seconds after the tutorial for new players and 180 seconds for returning players.

Rule of thumb: the perk should be noticeable but not mandatory. A 1.5x luck in a luck-driven game is strong; make sure non-members are not locked out of anything.

### Group roles and access
Use group roles for testers (Playtest access), moderators (an in-game admin panel checking rank with `GroupService:GetRolesInGroupAsync(userId, groupId)` on the server) and contributors. Never trust a client claim of rank. See [[Server Authority and Validation]].

---

## 4. External links and off-platform communities (2026 rules)

Announcements in 2026 changed what you can do:
- **January 2026:** creators can no longer share external social links in-game; `PolicyService`'s external link reference list is sunset and returns empty. Do not put "Follow us on X @handle" in game text. Reference social accounts through game pages or community links only (Announcement, age check to chat).
- **February 23, 2026:** social media links on game details pages, communities and profiles visible only to age-checked 13+ users (Announcement).
- **June 30, 2026:** raised to **age-checked 16+**, covering profiles, game details pages, community pages and the Creator Hub (Announcement, Kids and Select launch).

Practical consequences:
- Your Discord or video channel is no longer reachable for most young players from Roblox. Your **group page, events, update announcements and notifications** are the on-platform channels that reach everyone.
- Codes announced only on Discord reach a small, older slice of your players. Put codes in update notes, event descriptions and the group wall too.
- Moderators and testers recruited off-platform should still be organised through group roles.

---

## 5. Listening to the community

### Feedback channels
- **In-game feedback or bug report button** that writes to a data store or an external endpoint (with no personal data beyond user id; see [[Player Privacy and Data Deletion]]). The reference project had an in-game "stuck" report stored in its own data store.
- **Group wall and events** for announcements.
- **Off-platform** (Discord, forums) for the older core.

### Weighting feedback (rule of thumb)
- The loudest players are your most engaged, not your typical players. Their requests (harder content, more grind, trading features) often conflict with what new players need (clarity, faster rewards).
- Pair every request with data: is the complaint about a funnel step that analytics shows is weak ([[Analytics and Funnels]])?
- Separate **bugs** (fix), **pain** (investigate; the player is right that something is wrong, often wrong about the fix) and **wishes** (backlog).
- Close the loop publicly: "You asked, we changed" lines in update notes build trust.

### Moderation and safety
- All player-to-player text must go through `TextChatService` (Announcement, 2026) and be filtered. Custom chat UIs must still use it ([[Age Checks and Safety Features]]).
- Any user-generated text you display (pet names, sign text, trade notes) must be filtered with `TextService` for the right audience.
- Give moderators in-game tools (kick, mute through `TextChatService` permissions, report review) and log their actions.

---

## 6. Creators, influencers and video

- Video creators bring large bursts of traffic. Make the game easy to film: a clean HUD toggle, a photo or camera mode, readable rare-drop moments.
- Private servers (free or paid) let creators host fans. With Roblox Plus, paid private servers also pay you when Plus subscribers use them ([[Subscriptions and Premium Payouts]]).
- Do not pay or reward for posts in ways that violate subscription or notification rules ("post about us to unlock" is explicitly disallowed for subscription benefits; Docs).

---

## 7. Testers, moderators and contributors

A small trusted group makes every update safer.

**Tester program (rule of thumb):**
- A group role "Tester" with Playtest access to a private test copy of the game (same universe as a separate place, or a separate universe with copied data stores disabled).
- A written test script per update: the three or four flows that changed, plus the onboarding and purchase flows every time.
- A reward that is cosmetic and visible (a title or nametag effect), never power, so testers are not accused of advantage.
- A rule that test builds use test profiles. The reference project kept a "test profile key" attribute so QA sessions loaded a separate profile and ignored owned passes; the same switch must be cleared before release ([[Publishing an Experience]]).

**Moderators:**
- Clear written rules; actions logged with who, what and why.
- Tools limited to what they need (mute, kick, view reports). Bans that persist across servers need a data store and an appeal path.
- Rotate and review; a moderator abusing tools destroys trust faster than any bug.

**Contributors (builders, artists, translators):**
- Group-owned assets, clear credit in the game's credits screen and description.
- For localisation contributors, use the platform localisation tables so text stays filterable and reviewable ([[Localization]]).

---

## 8. When things go wrong

Communities form their opinion of a game in its bad weeks.

| Situation | What to do (rule of thumb) |
|---|---|
| Data loss after an update | Roll back fast ([[Release Process and Rollbacks]]); state what happened and what you will restore; restore from logs, including purchases ([[Data Loss Prevention and Recovery]]) |
| A purchase did not grant | Check your purchase log; re-grant generously; fix the receipt path ([[Developer Products and ProcessReceipt]]) |
| An exploit flooded the economy | Patch first, then decide on rollback versus targeted removal; explain the decision |
| A disliked balance change | Acknowledge, show the data you used, commit to a review date |
| Roblox outage | Say it is a platform issue; avoid compensation promises you cannot keep |

Write the message where players will see it: the group wall, an update announcement (60 characters, once every three days), an in-game banner via live config ([[Global State and Live Config]]). Compensation codes are effective when they are timely and scaled to the harm.

---

## 9. Common mistakes
- Group join prompts on join, repeated every few minutes, during the tutorial.
- Rewarding likes, favourites or social posts.
- External social handles in game text (no longer allowed).
- Invite rewards on click rather than on the friend actually playing.
- Admin tools gated on client-side rank checks.
- Treating Discord as the whole community.
- Unfiltered user text.

## 10. Checklist
- [ ] Friend boost and at least one co-op reason to play together
- [ ] Invite button using `CanSendGameInviteAsync` and launch data; reward after real play
- [ ] Group perk, re-checkable mid-session; prompt gated and capped
- [ ] No external links or handles in game text
- [ ] Codes and news posted on-platform (group, events, announcements)
- [ ] In-game feedback / report path
- [ ] All chat via `TextChatService`; user text filtered
- [ ] Group roles for testers and moderators; server-side rank checks

## See also
[[Social Design and Multiplayer Play]] · [[Live Ops Events and Updates]] · [[Discovery and the Algorithm]] · [[Age Checks and Safety Features]] · [[Roblox Policies Ratings and Compliance]] · [[Team Create and Collaboration]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Friend Invites Referrals and Experience Invites]] · Community and Moderation Start Here · Discord Servers for Roblox Games · Groups Roles and Permissions for Studios · Links - Community and social · Working with Content Creators
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Roblox Communities as Your On-Platform Hub]] · [[Groups Roles and Permissions for Studios]] · [[Monetization Overview]] · [[Robux Price Points and Offer Design]] · [[Ads and Rewarded Video]] · [[Refunds Chargebacks and Purchase Support]] · [[Game Passes]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]]
<!-- related:end -->
