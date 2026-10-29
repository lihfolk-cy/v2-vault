---
tags: [team, collaboration, team-create, permissions, drafts, workflow, groups, studio, type/guide, area/production, level/intermediate, area/studio]
---
# Team Create Permissions and Workflows

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Contractor given Edit on the live universe "for the sandbox place" -> Separate sandbox experience
> - Avoid: Private meshes granted to a sandbox experience -> Grants are permanent; use placeholders in sandboxes from now on
> - Avoid: Drafts held for days -> Commit at end of task and end of day
> - Game owned by a group once more than two friends or any contractor is involved.
> - Age-check compatibility confirmed for every collaborator before they are promised Team Create access.
> - Access matches the project stage table; Publish limited to two leads.
>
> Cost: TL;DR ~180 tok · whole note ~6.0k tok. Read more: ## 3. Live scripting or drafts: choosing per team, not per person · ## 4. Claiming areas of a place · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Team Create and Collaboration]] explains the features: permission levels, age checks, live scripting, drafts, comments, Script History, and the incidents that taught the reference project its shared-place rules. [[Safe Changes in a Shared Place]] is the playbook for one risky edit. [[Groups Roles and Permissions for Studios]] covers group roles and the permission list. This note sits between them and answers the operational questions a team lead faces every week: who gets which kind of access at which stage of a project, how to give a contractor somewhere to work without handing them the live game, how a team of four chooses and runs live scripting or drafts day to day, how to claim an area of a place so nobody deletes your work, and how to run the access audit that most teams never do.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. The access model in one table

Roblox has two ownership shapes and they behave differently. The facts below are from the collaboration and groups pages (Roblox docs, as of October 2026).

| Question | User-owned experience | Group-owned experience |
|---|---|---|
| Who can get Edit? | Only the owner's Roblox friends | Members whose group role has "Edit experiences" (group-wide, or per game for roles where that permission is offered per game) |
| Can an individual outside the roles get Edit? | Yes, if a friend | No. Individual users can only be added for Play on a group game |
| Who can revert other people's changes? | The owner | The owner (the docs say only the game owner can revert changes made by other editors) |
| Is Publish separate from Edit? | Not described as separate for user-owned games (unconfirmed, see section 8) | Yes: "Publish experiences" is its own role permission |
| Payouts to helpers | Not available | Group payouts (see [[Working with Contractors and Revenue Splits]]) |
| What happens when the person who owns it leaves | The game leaves with them | The group keeps it |

Two further rules cut across both shapes (Roblox docs):

- **Age checks.** Collaborating in Team Create with other people needs an age check (ID verification or facial age estimation), and owners must complete one for collaborators to join. By default only compatible age groups can collaborate (the age table is in [[Team Create and Collaboration]]). Trusted friend connections with every existing collaborator, or a linked parent's permission, lift the restriction.
- **Blocked collaborators keep some Edit power.** A collaborator blocked from Team Create by age rules still has Edit for Save As copies, Open Cloud APIs and Creator Hub metadata. That matters for offboarding: blocking someone from the session is not the same as removing their access.

The practical consequence is simple and most teams learn it late: **anything beyond two friends belongs in a group from day one**, because group roles are the only way to give non-friends Edit, the only way to separate editing from publishing, and the only way the game survives a member leaving.

---

## 2. Access by project stage

Teams over-grant early ("everyone is an admin, we are friends") and never pull it back. A staged model avoids that. Each stage below lists who holds which permission. Permission names are the exact group permission names from the docs; the stages are rule of thumb.

| Stage | Team shape | Recommended access |
|---|---|---|
| Prototype | One or two friends | User-owned is fine. Both have Edit. Nothing to protect yet |
| Pre-production | Two to four core members, maybe one contractor | Move to a group before the first contractor. Core: Edit experiences, Playtest. One or two leads: Publish experiences. Contractor: per-game access on a separate sandbox experience only |
| Production | Core plus several contractors and testers | Add a Tester role with Playtest on the test experience only. Publish limited to two leads. "Manage secrets" and "Edit Data Stores" only for the lead who owns data |
| Live | Core, contractors, moderators, testers | Live game edits by leads only; everyone else works in a staging experience and changes are moved over by a lead. Quarterly access audit |

### The universe trap: why a contractor sandbox must be a separate experience

Permissions in Roblox attach to an **experience** (a universe), not to a single place. If you add a second place inside the live universe and tell a contractor "work in the sandbox place", the Edit permission you granted for that universe also opens the start place and every other place in it (rule of thumb, following from permissions being granted per experience in the docs; confirm by opening the universe with a test account that holds only that role). The safe pattern:

1. Create a **separate experience** owned by the group, named clearly (for example `Sandbox - Zone Contractor`).
2. Save a trimmed copy of the relevant place into it (remove monetization scripts, DataStore keys, secrets, admin tools).
3. Give the contractor's role per-game Edit and Playtest on **that experience only**.
4. A lead moves approved work into the live place by `.rbxm` export and import, reviewed on the way in (the intake scan is in [[Working with Contractors and Revenue Splits]]).

The same reasoning applies to testers: a Playtest permission scoped to the live game lets them play private builds of the live game. Give it on the test experience.

### Assets follow a different rule

Meshes, images and decals uploaded under Asset Privacy are restricted to the experiences that have been granted access, and **a grant to an experience is permanent and cannot be revoked** (Roblox docs). Inserting a restricted asset into a collaborator's game also grants that game's owner permission. So when a contractor works in a sandbox experience and you later grant that sandbox experience your private mesh library, you cannot take it back. Keep sandboxes on placeholder or open assets, and grant private assets only to experiences you will own forever. More in [[Packages and Shared Assets Across Places]].

---

## 3. Live scripting or drafts: choosing per team, not per person

The setting is per experience ("Enable Drafts Mode" in File, Experience Settings), and every collaborator must leave the session before a change applies (Roblox docs). You cannot have half the team on drafts. The decision is therefore a team decision, and it is worth making on the basis of how your team actually works.

| Signal | Points to live scripting | Points to drafts |
|---|---|---|
| Team size actively scripting | One or two | Three or more |
| How often two people touch one script | Rarely | Weekly or more |
| Do you need to test a change before others see it? | No, small changes | Yes, systems that break the game when half-done |
| Is code also on disk (Rojo or Script Sync)? | Either | Drafts add little if Git already gives you branches |
| Do people switch machines? | Live scripting is safer | Drafts live on one machine only |

Facts that shape the decision (Roblox docs, as of October 2026):

- The collaborative session saves to the cloud every **four minutes**; live-scripting edits autosave every **five minutes**, and Ctrl S saves a script at once.
- Drafts are stored locally and persist across sessions **on the same machine**. They are invisible to everyone else until committed.
- Collaborative testing uses committed versions, not your draft.
- When the server copy changed under your draft, **Compare With Server** shows the differences and **Merge From Server** lets you pick Draft, Server or Other for each change, then **Merge All**.
- A script deleted by someone else while you draft it shows a red icon; **Restore Script** brings it back under Workspace, and you must re-parent it.

### A drafts protocol that works

Drafts fail in two predictable ways: a draft held for days drifts far from the server copy and the merge becomes guesswork, and a draft on a home PC is lost when the person works from a laptop. The protocol below is rule of thumb, shaped by those failure modes:

1. **Commit at the end of every task, and always before you log off.** A draft older than a day is a warning sign.
2. **Before starting a script, commit or discard any draft of it.** Starting on top of a stale draft is the most common source of "my fix undid your fix".
3. **Merge from server before committing** when Studio marks the server copy as changed. Read the comparison; do not accept "Draft" for every hunk by reflex.
4. **Announce commits that change contracts** (remote names, attribute names, module return shapes) in the team channel. Other people's drafts compile against the old contract until they merge.
5. **Never draft a script someone else owns** without asking. Ownership is in the ownership table ([[Team Roles and Workflows]]).

### A live-scripting protocol that works

Live scripting is excellent for pairing and terrible for two people independently editing one long script. Rules of thumb:

- **One editor per script at a time** unless you are deliberately pairing. The coloured cursor shows who is in it; leave if someone is.
- **Save before testing** (Ctrl S) so you do not test a version that differs from what the session has.
- **Small scripts help.** A 2,000-line module is a script two people will inevitably be inside at once. Splitting code into modules by responsibility ([[Module Scripts and Requiring]]) is partly a collaboration decision.
- **Script History is your undo.** Right-click, View Script History, compare versions. Never use Studio undo to roll back a script in a shared session ([[Safe Changes in a Shared Place]]).

---

## 4. Claiming areas of a place

A shared place has no locks: Studio does not stop anyone deleting a folder you are working in. The reference project lost a 1,200-part wall set and 40 grass clones to other people's clean-ups before it adopted ownership markers (measured in the reference project; details in [[Team Create and Collaboration]]). Comments mark areas for humans; attributes mark them for tools. The module below makes claims explicit and machine-checkable so clean-up scripts and bulk tools can refuse to touch claimed work.

Put it in a `ModuleScript` under `ServerStorage.DevTools` (it is a development tool, not game code) and call it from the Command Bar.

```lua
--!strict
-- ServerStorage.DevTools.Claims
-- Lightweight claim markers for a shared Team Create place.
-- A claim is three attributes on a top-level folder or model:
--   ClaimedBy (string), ClaimNote (string), ClaimUntil (number, os.time() seconds)
-- Tools call Claims.assertFree(inst, me) before bulk edits or deletes.
-- Development use only; nothing here runs in live servers.

local Claims = {}

local DEFAULT_HOURS = 8

local function claimRoot(inst: Instance): Instance?
	-- Walk up to the nearest ancestor (or self) that carries a claim.
	local current: Instance? = inst
	while current and current ~= game do
		if current:GetAttribute("ClaimedBy") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Claims.claim(inst: Instance, who: string, note: string, hours: number?)
	local h = hours or DEFAULT_HOURS
	assert(h > 0 and h <= 72, "claims are for working sessions, keep them under 72 hours")
	local existing = claimRoot(inst)
	if existing and existing ~= inst then
		local owner = existing:GetAttribute("ClaimedBy")
		error(`{inst:GetFullName()} is inside {existing:GetFullName()}, claimed by {owner}`)
	end
	inst:SetAttribute("ClaimedBy", who)
	inst:SetAttribute("ClaimNote", note)
	inst:SetAttribute("ClaimUntil", os.time() + math.floor(h * 3600))
	print(`claimed {inst:GetFullName()} for {who} ({h} h): {note}`)
end

function Claims.release(inst: Instance, who: string)
	local owner = inst:GetAttribute("ClaimedBy")
	if owner ~= who then
		warn(`not releasing {inst:GetFullName()}: claimed by {tostring(owner)}, not {who}`)
		return
	end
	inst:SetAttribute("ClaimedBy", nil)
	inst:SetAttribute("ClaimNote", nil)
	inst:SetAttribute("ClaimUntil", nil)
	print(`released {inst:GetFullName()}`)
end

-- Returns true if `me` may bulk-edit or delete `inst`. Expired claims count as free
-- but are reported, so someone asks before acting on them.
function Claims.isFreeFor(inst: Instance, me: string): (boolean, string?)
	local root = claimRoot(inst)
	if not root then
		return true, nil
	end
	local owner = root:GetAttribute("ClaimedBy") :: string?
	local untilTime = (root:GetAttribute("ClaimUntil") :: number?) or 0
	if owner == me then
		return true, nil
	end
	if os.time() > untilTime then
		return true, `expired claim by {owner} on {root:GetFullName()}; ask before deleting`
	end
	return false, `{root:GetFullName()} is claimed by {owner}: {root:GetAttribute("ClaimNote")}`
end

function Claims.assertFree(inst: Instance, me: string)
	local ok, why = Claims.isFreeFor(inst, me)
	if not ok then
		error(why :: string)
	elseif why then
		warn(why)
	end
end

-- Prints every claim in the place, oldest expiry first.
function Claims.report()
	type Row = { path: string, who: string, note: string, untilTime: number }
	local rows: { Row } = {}
	for _, inst in game:GetDescendants() do
		local who = inst:GetAttribute("ClaimedBy")
		if typeof(who) == "string" then
			table.insert(rows, {
				path = inst:GetFullName(),
				who = who,
				note = tostring(inst:GetAttribute("ClaimNote")),
				untilTime = (inst:GetAttribute("ClaimUntil") :: number?) or 0,
			})
		end
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.untilTime < b.untilTime
	end)
	local now = os.time()
	for _, r in rows do
		local left = math.floor((r.untilTime - now) / 60)
		local state = if left < 0 then `EXPIRED {-left} min ago` else `{left} min left`
		print(`{r.who}  {state}  {r.path}  ({r.note})`)
	end
	print(`{#rows} claims`)
end

return Claims
```

Usage from the Command Bar:

```lua
local Claims = require(game.ServerStorage.DevTools.Claims)
Claims.claim(workspace.Map.Zone3, "level-design", "rebuilding cliffs, do not clean up", 6)
Claims.report()
```

Design notes:

- **The claim lives on the instance, so it syncs to everyone** through the normal session save. A note in a chat channel does not reach a bulk tool; an attribute does.
- **Claims expire.** Permanent claims become noise, and everyone learns to ignore them. Expired claims are reported, not silently ignored, so the next person asks.
- **`game:GetDescendants()` on a big place is slow.** In the reference project a full-place scan of several hundred thousand instances froze every collaborator's Studio for seconds (measured in the reference project: long synchronous commands stall the whole session). Run `report` rarely, or scan only `workspace.Map` and the folders you know hold claims.
- **Attributes are visible in live servers too.** They are harmless, but strip them in your release checklist if you prefer a clean live place ([[Release Process and Rollbacks]]).
- **The Command Bar runs with your identity in the session**: `os.time()` is your machine's clock. Clocks that are minutes off do not matter for claims measured in hours.

---

## 5. The daily rhythm of a shared session

Teams that use Team Create well have a rhythm, even if nobody wrote it down. A version that fits a team of three to six (rule of thumb):

| When | What | Why |
|---|---|---|
| Opening Studio | Read the team changelog since yesterday; run the claim report for your area; check Live Collaborators | You find out a module was renamed before you build on it |
| Before a heavy operation | Announce it with an expected duration; Save to Roblox with notes | Long synchronous commands freeze everyone's Studio (measured in the reference project) |
| Before Play testing | Check who else is testing; set only your own test flags | Another tester's flags cause "impossible" bugs |
| End of task | Commit drafts; remove test objects; one changelog line (what, where, how to undo, tested or not) | The next person can trust the place |
| End of day | Release claims you no longer need; close Studio | An idle Studio left open hours later can save stale state over a revert |

The last row deserves emphasis. The docs warn that during a revert, a collaborator still in the session can overwrite it with their autosave. The less obvious version is the **forgotten session**: a teammate's Studio left open overnight on a home PC, reconnecting after sleep. Before any revert, disable collaboration (Live Collaborators, the ⋯ button, Disable Team Create) rather than asking people to close Studio, because you cannot see a laptop asleep in someone's bag.

### Pairing through Team Create

Team Create is also a very good pairing tool. **Join** in the Live Collaborators window moves your camera or editor to where the other person works (Roblox docs). For onboarding and for debugging, a 30-minute pairing session where the senior person joins and narrates beats a written explanation (see [[Documentation and Onboarding New Developers]]). Agree who "drives" (types) so you do not fight over the same script.

---

## 6. Rojo, Script Sync and Team Create together

Many teams use files on disk for code and Team Create for the world. That works if you decide which side owns which tree.

| Tree | Owned by | Collaboration |
|---|---|---|
| `ServerScriptService`, `ReplicatedStorage.Shared`, client controllers | Files on disk (Rojo or Script Sync) and Git | Pull requests ([[Code Review for Luau Teams]]) |
| `Workspace.Map`, lighting, terrain | The place | Team Create plus claims |
| UI layouts | Either; pick one per screen | If designers edit in Studio, keep UI out of Rojo trees |
| Packages | Roblox package versions | Keep out of Rojo trees ([[Packages and Asset Reuse]]) |

Two facts to plan around. Script Sync is a Studio beta that the docs describe as working with Roblox's collaboration tools, which third-party tools often do not (Roblox docs, as of October 2026). Rojo offers a Team Create sync lock in recent versions so that only one person syncs at a time ([[Team Create and Collaboration]] cites Rojo 7.3 and later). In both cases **only one person should sync a given tree at a time**; two people syncing the same files into one session reproduces the last-write-wins problem with extra steps.

---

## 7. The access audit

Access accumulates. A contractor from last spring still has Edit; a moderator who left still has a role. The audit below takes about 20 minutes per experience per quarter (rule of thumb), and it is the single most neglected collaboration task.

1. **List every role with Edit, Publish, Manage secrets, the Data Stores permissions and Manage and spend group revenue**, group-wide and per game. Write down who holds each.
2. **For user-owned side projects, list collaborators** in the Collaborate panel.
3. **Read Activity History** for the period: publishes, permission changes, settings changes, draft commits (Roblox docs describe it as the log of these events). Anything you cannot explain is an incident until explained.
4. **Remove anyone without a current task.** Access should follow need, not trust ([[Hiring Freelancers and Revenue Shares]] makes the same point).
5. **Rotate secrets and API keys** the removed people could have seen ([[Open Cloud APIs]]).
6. **Check Place Copying is off** on every game that holds private assets ([[Groups Roles and Permissions for Studios]]).
7. **Record the audit** in the decisions log with the date ([[Documentation and Knowledge Bases]]).

Remember the blocked-collaborator rule from section 1: removing someone from the session by age rules does not remove their Edit for Open Cloud and Save As. Remove the role.

---

## 8. What is announced, and what is unconfirmed

- **Native branching and merging** for collaborative editing was reported from the Roblox Developers Conference in September 2026 as planned for early 2027, along with package overrides. That report comes from a third-party summary of the keynote; we could not find the official announcement post. Treat it as **unconfirmed** and design today's workflow without it. If it ships, the sandbox-experience pattern in section 2 becomes less necessary for code but stays necessary for access control.
- **Whether Edit on a user-owned experience includes publishing** is not stated on the collaboration page. Test with a friend account before relying on either answer.
- **Maximum number of simultaneous collaborators** is not stated on the collaboration page. Very large sessions are rare on Roblox; if you plan more than about ten simultaneous editors, test the place's responsiveness first (rule of thumb).
- The universe-wide reach of Edit in section 2 follows from the docs granting permissions per experience; verify with a test account before you rely on it as a security boundary.

---

## 9. When not to do all this

- **Two friends on a prototype**: user-owned, live scripting, a shared note. Claims, audits and staged access are overhead with nothing to protect.
- **A solo developer with occasional helpers**: skip drafts, use file delivery from helpers instead of Team Create at all.
- **Teams with all code in Git**: drafts add little; keep live scripting for the few Studio-side scripts and do code review in pull requests.

---

## Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Contractor given Edit on the live universe "for the sandbox place" | Contractor's role has per-game Edit on the live game | Separate sandbox experience |
| Private meshes granted to a sandbox experience | Asset permissions list shows a sandbox universe | Grants are permanent; use placeholders in sandboxes from now on |
| Drafts held for days | Large merges, "my fix vanished" | Commit at end of task and end of day |
| Half the team expects drafts, half live scripting | Confusion after someone toggles the setting | Team decision, announced; everyone leaves the session when it changes |
| Revert while someone's Studio is open somewhere | Reverted content reappears minutes later | Disable Team Create before reverting |
| Bulk clean-up tool deletes claimed work | Missing folders, angry teammate | Tools call `Claims.assertFree` before acting |
| Access never removed | Quarterly audit finds ex-members with Edit | Audit, remove, rotate secrets |
| Everyone can publish | A half-finished build goes live | Publish experiences for two leads only |

## Checklist

- [ ] Game owned by a group once more than two friends or any contractor is involved.
- [ ] Age-check compatibility confirmed for every collaborator before they are promised Team Create access.
- [ ] Access matches the project stage table; Publish limited to two leads.
- [ ] Contractors and testers work in separate sandbox or test experiences, not extra places in the live universe.
- [ ] Sandboxes use placeholder or open assets; private asset grants only to permanent experiences.
- [ ] Live scripting or drafts chosen as a team; protocol written in the onboarding doc.
- [ ] Claims on in-progress areas; bulk tools check claims.
- [ ] Revert procedure starts with Disable Team Create.
- [ ] Quarterly access audit with Activity History, recorded in the decisions log.

## Connected notes
<!-- auto-links:start -->
[[Team Collaboration Start Here]] · [[Links - Team Create]] · Animation Asset Permissions and Groups · Scoping and Roles for Small Teams · Version History and Backups · Git and Source Control for Roblox
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Asset Permissions and Groups]] · [[Scoping and Roles for Small Teams]] · [[Version History and Backups]] · [[Creator Account Security and Takeover Recovery]] · [[Multiple Agents in One Studio]] · [[Roadmaps Milestones and Scope Control]]
<!-- related:end -->
