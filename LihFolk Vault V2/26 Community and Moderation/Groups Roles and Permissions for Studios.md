---
tags: [community, groups, permissions, studio, team, security, moderation, luau, type/guide, area/community, level/intermediate, area/security]
---
# Groups Roles and Permissions for Studios

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Founders' daily accounts as group owner.
> - Avoid: "Edit experiences" granted group-wide to a contractor for one game.
> - Avoid: Moderators under 18 given "Moderate experiences" (not allowed, and chat access is sensitive).
> - Game and assets owned by the group
> - Dedicated owner account with 2SV and offline backup codes
> - Role ladder written down; each role's permissions reviewed against the risk table
>
> Cost: TL;DR ~140 tok · whole note ~4.2k tok. Read more: ## 5. A role ladder for a small studio · ## 6. Using ranks inside the game · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

A Roblox group (shown as a "community" in parts of the 2025 and 2026 interface) is three things at once: the legal-ish container that owns your games, assets and revenue; the permission system for your team; and the public home of your players. Most small studios set it up once in an afternoon and then live with an owner account that holds every key, five people with "edit everything", and contractors who still have access a year later. This note is about doing it deliberately: a role ladder that matches how a studio actually works, the exact permissions to give each role, the ones that need two-step verification, moderators and the 18+ chat permission, revenue splits, audit logs, and the failure cases (lost owner, rogue member, leaked API key). For player-facing group features (perks, join prompts) see [[Community Building]]; for Team Create mechanics see [[Team Create and Collaboration]].

Facts are labelled "Roblox docs (as of October 2026)" or "rule of thumb".

---

## 1. Safety first

Groups are where adults and minors meet as colleagues and where players meet staff. Before structure:

- **Minors on the team.** Many Roblox developers are under 18. Team Create collaboration is limited to compatible age groups unless lifted by trusted friend status or parental permission ([[Team Create and Collaboration]] has the table). Plan around it: do not pressure anyone to change settings or verify to join your project, and keep studio communication in places a parent could see ([[Discord Servers for Roblox Games]]).
- **No private one-to-one channels between adult staff and minor players.** Moderators and developers talk to players in public spaces (group wall, public channels) only. This rule protects players and protects your staff from accusations.
- **The "Moderate experiences" permission lets members view all in-game chat read-only and ban users across all group games, and the member must be 18+** (Roblox docs). Treat it as the most sensitive permission in the group, more than revenue.
- **Payouts and contracts with minors** need a parent or guardian involved ([[Hiring Freelancers and Revenue Shares]], [[Commissions Pricing and Contracts]]).
- **Group content follows the Community Standards**: name, logo, wall posts, announcements, ally lists. The group page is often a child's first contact with your studio.

---

## 2. Why a group should own the game

| Concern | User-owned game | Group-owned game |
|---|---|---|
| Edit access | Only to Roblox friends (Roblox docs) | By role, across all games or per game |
| Revenue | Goes to one person | Group balance, recurring percentage splits, one-time payouts |
| Assets | Owned by uploader; group games need group-owned or shared assets | Upload to the group; survives people leaving |
| One person leaves | Game and assets leave with them | Game stays |
| Audit | None | Audit log of group changes |

Rule of thumb: any game with more than one editor, or any intent to pay anyone, should be group-owned from the first publish. Moving later is painful because assets (especially animations and packages) are owned by the uploader ([[Animation Asset Permissions and Groups]], [[Packages and Asset Reuse]]). Creating a group costs 100 Robux (Roblox docs).

---

## 3. How roles work (Roblox docs)

- Members can hold **one or more roles**. Roles are ordered by **hierarchy**; some permissions only act on roles below the member's highest role (you cannot kick or demote someone above you).
- Each role is **public** or **private**; visibility affects where it appears, not what it grants.
- Only the owner, or members with role-management permissions, can manage roles.
- Roles can be managed programmatically through Open Cloud Groups endpoints (and from game servers through `HttpService` calling Open Cloud, as the docs note).
- Roles made on the old Groups pages keep running on the legacy system and are managed through the legacy workflow.
- In-game, `Player:GetRankInGroup(groupId)` returns a rank number and `Player:GetRoleInGroup(groupId)` a role name. Ranks run 0 (not a member) to 255 (owner) (long-standing behaviour; the 2026 groups page does not restate the numbers, so verify in your group settings).

Multiple roles per member are new compared with the single-rank system many tutorials describe. In code, the rank you read is the member's primary rank; if your game logic depends on "is this person a Tester", read it from a dedicated mechanism (a rank threshold you control, or a list in live config), not from assumptions about which role is primary (rule of thumb; check behaviour with a test account holding two roles).

---

## 4. The permission list, grouped by risk

The docs list permissions in three groups. This table regroups them by what goes wrong if the wrong person has them.

| Risk | Permissions (exact names, Roblox docs) | What can go wrong |
|---|---|---|
| **Critical** (needs 2SV for several) | Manage roles; Assign or remove roles from members; Manage access to this group's resources (legacy); Manage and spend group revenue; Delete Data Stores for experiences; Manage API keys; Manage secrets for experiences | Takeover, theft, data wipe, leaked keys |
| **High** | Publish experiences; Edit experiences; Edit Data Stores for experiences; Manage monetization for experiences; Moderate experiences (18+); Ban members; Manage webhooks for experiences | Broken live game, price changes, wrongful bans, chat access |
| **Medium** | Create avatar items; Configure avatar items; Manage development items; Manage development item permissions; Create ad campaigns for the group; Manage experience events; Manage share links; Manage alerts; Manage support tickets for experiences | Spend, brand damage, confusing players |
| **Low** | Playtest experiences; View analytics for experiences; View Data Stores for experiences; View group revenue; View development items; View audit logs | Information leaks (revenue, player data) |
| **Community** | View/Create community announcements; Manage categories; Create/Remove/Lock/Pin posts; Create/Remove comments; View/Manage content moderation; Bypass slow mode; View community analytics; Invite or approve members; Kick members; Configure group profile; Manage allies and enemies | Public embarrassment, harassment of members |

**2SV is required to grant** Manage roles, Assign or remove roles, Manage access to this group's resources, Manage and spend group revenue, and Delete Data Stores for experiences (Roblox docs). Treat the requirement as a minimum: insist on 2SV for every member with anything above "Low".

Note "View Data Stores": data stores hold player data. Viewing them is a privacy-relevant permission, not a harmless one ([[Player Privacy and Data Deletion]]).

---

## 5. A role ladder for a small studio

A template (rule of thumb) for a studio with two founders, a few developers, contractors, testers and moderators. Rank numbers are examples.

| Role (rank) | Who | Permissions |
|---|---|---|
| Owner (255) | A dedicated owner account, not anyone's daily account | Everything |
| Director (250) | Founders' daily accounts | All except Manage roles and Delete Data Stores; Manage and spend revenue only if both founders agree |
| Lead Developer (230) | Trusted senior | Edit, Publish, Edit Data Stores, Manage monetization, Manage secrets, View analytics, Manage webhooks |
| Developer (200) | Core team | Edit experiences, Playtest, View analytics, Manage development items |
| Contractor (180) | Short-term freelancers | Per-experience Edit and Playtest on the one game they work on; nothing group-wide |
| Community Lead (170) | Runs announcements and moderators | Announcements, posts, content moderation, Kick members, Manage experience events |
| Moderator (150) | Trusted adults (18+) | Moderate experiences (only if 18+), Remove posts and comments |
| Helper (120) | Community volunteers, any age | Community posting and Bypass slow mode only; in-game helper badge via rank |
| Tester (100) | Playtest group | Playtest experiences on the test place |
| Member (1) | Players | Default |

Principles behind it:
- **Separate the owner account.** If a founder's daily account is phished, the attacker should not own the group. The owner account has a unique password, 2SV with an authenticator, and is used only for role changes and ownership tasks.
- **Per-experience permissions for contractors.** The docs let you scope Playtest, Edit, Publish, Manage monetization, Manage secrets, View analytics and the three Data Stores permissions to individual games. A contractor working on a side project should not be able to open your flagship.
- **Publishing is separate from editing.** Developers edit; leads publish through a release checklist ([[Release Process and Rollbacks]]).
- **No one gets Delete Data Stores day to day.** Grant it temporarily for a planned cleanup, then remove it.

---

## 6. Using ranks inside the game

```lua
--!strict
-- Server ModuleScript: StaffRanks. Cached rank with an explicit refresh and a live-config deny list.
-- Reviewed, not run.
local Players = game:GetService("Players")

local GROUP_ID = 0
local cache: { [number]: number } = {}
local denied: { [number]: boolean } = {} -- filled from live config (removed staff)

local StaffRanks = {}

function StaffRanks.refresh(player: Player): number
	local ok, rank = pcall(function()
		-- highest public role; Roles is ordered highest first (GetRankInGroupAsync is deprecated)
		local info = game:GetService("GroupService"):GetRolesInGroupAsync(player.UserId, GROUP_ID)
		return if info.IsMember and info.Roles[1] then info.Roles[1].Rank else 0
	end)
	local value = if ok and not denied[player.UserId] then rank else 0
	cache[player.UserId] = value
	player:SetAttribute("StaffRank", value) -- for UI only; never trusted by the server
	return value
end

function StaffRanks.get(player: Player): number
	return cache[player.UserId] or StaffRanks.refresh(player)
end

function StaffRanks.atLeast(player: Player, rank: number): boolean
	return StaffRanks.get(player) >= rank
end

function StaffRanks.setDenied(list: { number })
	table.clear(denied)
	for _, id in list do
		denied[id] = true
	end
	for _, p in Players:GetPlayers() do
		StaffRanks.refresh(p)
	end
end

Players.PlayerAdded:Connect(StaffRanks.refresh)
Players.PlayerRemoving:Connect(function(p)
	cache[p.UserId] = nil
end)

return StaffRanks
```

Why the deny list: rank lookups are cached by the engine per session (rule of thumb, widely observed), so a demoted moderator keeps old powers in servers they are already in. Pushing their id through live config ([[Global State and Live Config]]) removes powers everywhere within your config refresh time. For a fresh membership lookup, `GroupService:GetGroupsAsync(userId)` returns current groups and ranks (the reference project used it for a "check again" button; measured in the reference project).

The attribute is for the client to show or hide the panel. The server checks `StaffRanks.atLeast` on every remote ([[Server Authority and Validation]]). Never put staff powers behind a client check, a hidden button, or a secret command alias.

---

## 7. Revenue, payouts and money between members (Roblox docs)

- **One-time payouts**: Send Robux to chosen members, or upload a CSV with `userId` and `payoutInRobux` columns.
- **Recurring payouts**: percentage splits for the whole group or per game. A game's split pays its members first; the remainder flows into the group split; anything left stays in the group balance. Private server subscriptions keep the percentages in force at purchase time, even if you change them later.
- Games charging paid access in local currency cannot share payouts across members.
- Some groups do not see Payouts at first (group age, insufficient funds).

Rules of thumb:
- Put every split in a written agreement before money flows ([[Hiring Freelancers and Revenue Shares]]). A percentage set in the dashboard is not a contract.
- Splits to minors involve their parent or guardian, and DevEx eligibility has its own rules ([[DevEx and Cashing Out]]).
- Changing a percentage is visible to the recipient; do it with a conversation first.
- Avoid "revenue share forever" for small contributions; prefer a fixed fee or a time-limited share.

---

## 8. Audit, offboarding and incidents

**Audit logs.** Members with "View audit logs" see Activity History in the Creator Dashboard or the Audit Log on the community page (Roblox docs). Review weekly: role changes, payouts, publishes, data store deletions.

**Offboarding checklist (rule of thumb):**
- Remove group roles (or move to Member).
- Remove per-experience permissions on each game.
- Rotate any API keys and experience secrets they could see ([[Open Cloud APIs]], [[HttpService and External APIs]]).
- Remove them from Team Create collaborators on user-owned side projects.
- Update the live-config deny list if they were staff in-game.
- Remove off-platform access (Discord roles, repositories, shared drives).

**Incidents:**
| Incident | First hour |
|---|---|
| A member account is compromised | Remove its roles from the owner account; rotate keys and secrets; check audit log for publishes and payouts; roll back the place if needed ([[Release Process and Rollbacks]]) |
| Owner account lost | Recovery through Roblox Support only; this is why the owner account has 2SV backup codes stored offline |
| A moderator abused bans | Remove the role; list their bans from logs; unban wrongful ones ([[Logging Bans and Appeals]]); tell affected players |
| Rogue member published a broken build | Revert to the previous version; move Publish to leads only |

Roblox does not arbitrate internal group conflicts (Roblox docs). If founders fall out, the owner account decides everything. Agree in writing who holds it and what happens if a founder leaves ([[Running a Small Studio as a Business]], [[Legal Basics - IP Licenses and Assets]]).

**Place Copying.** Members who can edit all group games can enable Place Copying, which lets anyone copy the game and its assets. The docs recommend disabling it before adding private assets. Check it on every game during the weekly audit.

---

## 9. Testers and private test places

Use a Tester role with "Playtest experiences" scoped to a separate test place or test universe, not the live game. Keep test data separate from live data ([[Community Building]] section 7 has a tester program). A tester role needs no edit rights; testers who also build should hold a second role, which the multiple-roles model now allows.

---

## 10. Common mistakes

- Founders' daily accounts as group owner.
- "Edit experiences" granted group-wide to a contractor for one game.
- Moderators under 18 given "Moderate experiences" (not allowed, and chat access is sensitive).
- In-game staff checks on the client or by username.
- Contractors never offboarded; API keys never rotated.
- Place Copying left on after private assets were added.
- Revenue splits with no written agreement.

## 11. Checklist

- [ ] Game and assets owned by the group
- [ ] Dedicated owner account with 2SV and offline backup codes
- [ ] Role ladder written down; each role's permissions reviewed against the risk table
- [ ] 2SV required for all roles above Low risk
- [ ] Contractors on per-experience permissions only
- [ ] "Moderate experiences" only for vetted adults; actions logged
- [ ] In-game staff checks server-side with a deny list in live config
- [ ] Weekly audit log review; offboarding checklist used
- [ ] Place Copying off on games with private assets

## See also
[[Community and Moderation Start Here]] · [[Community Building]] · [[Team Create and Collaboration]] · [[Player Reports and In-Game Moderation]] · [[Discord Servers for Roblox Games]] · [[Animation Asset Permissions and Groups]] · [[Scoping and Roles for Small Teams]] · [[Team Roles and Workflows]] · [[Open Cloud APIs]] · [[Release Process and Rollbacks]]

## Connected notes
<!-- auto-links:start -->
[[Working with Contractors and Revenue Splits]] · Team Create Permissions and Workflows · Team Collaboration Start Here · Business and Careers Start Here · Documentation and Onboarding New Developers · Building a Portfolio as a Roblox Developer
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Team Create Permissions and Workflows]] · [[Roblox Communities as Your On-Platform Hub]] · [[Creator Account Security and Takeover Recovery]] · [[Working with Content Creators]] · [[Voice Chat and Safety Features]] · [[Text Chat Customization with TextChatService]]
<!-- related:end -->
