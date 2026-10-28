---
tags: [team, onboarding, documentation, knowledge-base, docs-as-code, luau, workflow]
---
# Documentation and Onboarding New Developers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Access requested on day one -> Start access a week early
> - Avoid: Setup guide never re-run -> One-command setup, tested on a clean machine
> - Avoid: Shared-place rules buried -> Rules on page one
> - Days-to-first-merged-change tracked for every hire.
> - Access (age check, group role, 2SV, sandbox, repo, chat) requested a week before day one.
> - One-command setup, tested on a clean machine recently.
>
> Cost: TL;DR ~140 tok · whole note ~4.7k tok. Read more: ## 6. Documentation that lives next to the code · ## 7. A generated index of remotes and modules · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Documentation and Knowledge Bases]] explains the four documents a team needs (project map, running changelog, decisions log, systems notes), how documentation rots, honest verification labels, and generated docs, using the reference project's real files. This note uses those documents for one specific job: getting a new person productive and safe in a Roblox project quickly. It covers what to prepare before their first day, a day-one document that fits on two screens, a first-two-weeks plan with a measurable goal, how to pick starter tasks, code-level documentation that lives next to the code (module headers, doc comments, architecture decision records), a generated index of remotes and modules, onboarding builders and artists who never open a script, and how to keep the onboarding path from rotting between hires.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Measure onboarding, or it will not improve

Pick one number and track it per hire: **days from first access to first change merged into the live game** (or, for builders, first asset accepted into the live place). For a small Roblox team, a well-prepared onboarding gets this under five working days; an unprepared one routinely takes three weeks, mostly spent asking where things are (rule of thumb).

Track a second, qualitative signal: the questions the new person asked in their first week. Every question that a document should have answered is a documentation bug. Fix the document the same day, ideally by asking the new person to do it, since they know exactly what was missing.

---

## 2. Before day one

Access problems eat the first days of most onboardings. Many Roblox-specific ones have lead time, so start them a week early.

| Item | Why it has lead time | See |
|---|---|---|
| Age check and age-group compatibility for Team Create | Collaborating requires an age check; incompatible age groups cannot join by default | [[Team Create and Collaboration]] |
| Group membership and role | They must join the group, and you assign the role | [[Groups Roles and Permissions for Studios]] |
| Two-step verification on their account | Required to grant some permissions; insist on it for any edit role | [[Groups Roles and Permissions for Studios]] |
| Sandbox or test experience access | Per-game permissions on the right experience | [[Team Create Permissions and Workflows]] |
| Repository, issue tracker, Discord channels | Off-platform invites | [[Discord Servers for Roblox Games]] |
| Toolchain on their machine | Installing Rokit, Rojo, Wally, Selene, StyLua and editor extensions | [[External Tooling - Rojo Wally Selene StyLua]] |
| Agreement and, for minors, guardian approval | Must exist before any work | [[Working with Contractors and Revenue Splits]] |

### A one-command setup

The fastest path is a repository where setup is one command plus a README. With a toolchain manager the tool versions are pinned in a file in the repo (Rokit uses `rokit.toml`; check the tooling note for tested versions as of October 2026), so setup looks like this:

```bash
# from a fresh clone
rokit install          # installs the pinned versions of rojo, wally, selene, stylua
wally install          # fetches Luau packages into Packages/
rojo sourcemap default.project.json -o sourcemap.json   # for luau-lsp
stylua --check src && selene src                          # proves the toolchain works
rojo serve             # then connect from the Rojo plugin in Studio
```

Write exactly these lines in the README, test them on a clean machine every few months, and ask each new hire to report any step that failed. A setup guide nobody has run since the founder wrote it is the most common onboarding blocker on code-first teams.

Studio-only teams skip the toolchain but still need a written list: which Studio beta features the team uses (for example Script Sync, which is a beta as of October 2026), which plugins are approved ([[Plugin Security and Permissions]]), and which settings matter.

---

## 3. The day-one document

A new person's first document should fit on about two screens. It links to everything else; it does not contain everything else. A template that works (rule of thumb):

```markdown
# Start here (developers)

## The game in one paragraph
What the player does, who the target player is, which devices matter most.
Link: vision page.

## The place in one picture
Lobby place -> match places; where the map, UI, systems and tools live.
Link: project map (canonical, read first).

## Rules of the shared place (non-negotiable)
1. Never use undo in a shared session; snapshot first.
2. Test objects named test_<initials>_* at the test pad, removed when done.
3. Claim areas before bulk work; never delete what you did not create without asking.
4. One changelog line per change: what, where, how to undo, tested or not.
Link: Safe changes playbook.

## How to run, test and ship
Setup command; how to start a test server with two players; how a change reaches live.
Link: release checklist.

## Who to ask
Ownership table: area -> owner -> how to reach them.

## Your first two weeks
Link: the onboarding plan with your starter tasks.
```

The rules section matters more on Roblox than in most software, because a shared place has no branches and no locks. **Measured in the reference project:** the shared-place rules (no undo, snapshot first, test object prefixes, ownership markers, one heavy operation at a time) were all learned through incidents, and new collaborators who had not read them repeated the same incidents ([[Team Create and Collaboration]], [[Safe Changes in a Shared Place]]). Put them on page one, not page twelve.

---

## 4. The first two weeks

A plan with concrete outcomes beats "look around the codebase" (rule of thumb):

| When | Activity | Outcome |
|---|---|---|
| Day 1 | Setup; read the day-one doc and project map; a 30-minute guided tour using **Join** in Live Collaborators | Toolchain works; can find any system's entry point |
| Day 2 | Play the game for an hour as a player, on a phone; write down five things that confused them | Fresh eyes on onboarding for players too ([[First-Time User Experience and Onboarding]]) |
| Days 2 to 3 | Starter task 1 (section 5), paired with a buddy | First change reviewed |
| Days 4 to 5 | Starter task 2, alone; first change merged and published | The key metric reached |
| Week 2 | A small feature end to end: config, server, client, UI, test | Understands the whole stack once |
| End of week 2 | 30-minute retro: what was missing from the docs? | Docs fixed by the new person |

### The buddy

Assign one buddy who answers questions within hours, not the lead (rule of thumb). The buddy's own work slows by perhaps a fifth during the first week; plan it in the milestone ([[Roadmaps Milestones and Scope Control]]). Pairing through Team Create works well: the buddy joins the new person's editor and watches, rather than taking over.

### Onboarding young developers

Many Roblox developers are teenagers. The professional duties in [[Hiring Freelancers and Revenue Shares]] apply: communication in visible team channels, no private one-to-one apps, guardian involvement in agreements, reasonable hours. Onboarding documents should avoid assuming a workday; "first two weeks" may be first two weekends.

---

## 5. Choosing starter tasks

A good starter task (rule of thumb):

- **Touches one system** and one owner, so the review is short.
- **Ships to players**, so the person sees their work live in the first week.
- **Crosses the client-server boundary once**, so they learn the remote pattern with a reviewer watching.
- **Has a clear done**: a test case or a screenshot.
- **Is not on the critical path**, so a slow first week costs nothing.

Examples: add a new item to an existing shop with its config entry and icon; add rate limiting to one existing remote ([[Remote Abuse Patterns and Rate Limiting in Practice]]); add a setting to the settings menu that persists; fix a known bug with a written reproduction.

Bad starter tasks: anything in the save system, combat netcode, or a refactor across many modules. Keep a short **starter task list** in the tracker, refilled whenever someone notices a candidate; without the list, the lead invents a task on the morning of day one and it is usually too big.

---

## 6. Documentation that lives next to the code

The knowledge base holds maps, decisions and system overviews. Code-level facts belong next to the code, where they change in the same pull request.

### Module headers

Every ModuleScript starts with a header that answers four questions: what it does, who calls it, what it must never do, and where its design is explained.

```lua
--!strict
--[[
	PetInventory (server)
	Owns each player's pet list in memory and validates every change to it.
	Called by: ShopService (grants), TradeService (transfers), PetRemotes (equip/unequip).
	Never: yields while holding a player's list; trusts pet ids from the client without
	checking ownership.
	Design: knowledge base "Systems / Pets"; decision ADR-0007 (why pets are stored as a
	map keyed by uid, not an array).
]]
```

This takes a minute to write and saves the new person an hour of reading call sites. Code review should block new modules without one ([[Code Review for Luau Teams]]).

### Doc comments for public functions

If the team generates API docs, Moonwave is a common choice in the Roblox community: it reads `--[=[ ... ]=]` comment blocks with tags such as `@class`, `@param`, `@return` and `@within`, and builds a website (community tool, not a Roblox product; check its documentation for current syntax). Even without generating anything, the format is readable:

```lua
--[=[
	Moves a pet between two players' inventories. Both players must be in this server.
	Idempotent per trade id: calling it again with the same tradeId does nothing.

	@param tradeId string -- unique id from TradeService
	@param fromPlayer Player
	@param toPlayer Player
	@param petUid string
	@return boolean -- true if the pet moved, false if any check failed
]=]
function PetInventory.transfer(tradeId: string, fromPlayer: Player, toPlayer: Player, petUid: string): boolean
	-- ...
	return false
end
```

Document contracts and guarantees (idempotent, may yield, server only), not what the code obviously does.

### Architecture decision records

The decisions log in [[Documentation and Knowledge Bases]] records the owner's product decisions. Technical decisions need a separate, slower format: an **architecture decision record** (ADR), one short file per decision, numbered, never edited after acceptance (a later ADR supersedes it).

```markdown
# ADR-0007: Pets stored as a map keyed by uid

Status: accepted (supersedes nothing)
Context: Trading needs to move one pet without rewriting indexes; arrays caused
duplicate-pet bugs when two trades raced.
Decision: Save pets as { [uid]: PetData }. uids are generated server-side with
HttpService:GenerateGUID(false).
Consequences: Migration v4 converts arrays to maps on load. Ordering for UI is done
client-side by a sort key. Save size grows slightly per pet.
```

New developers read ADRs to learn why the code is the way it is, which is the question they are most afraid to ask. Ten ADRs explain more about a codebase than a hundred pages of system descriptions (rule of thumb).

---

## 7. A generated index of remotes and modules

Hand-written lists of remotes go stale within a week. Generate one. This Command Bar script prints a Markdown table of every remote under `ReplicatedStorage`, with a description taken from a `Doc` attribute, and lists ModuleScripts whose source does not start with a header comment. Reading `Source` works from the Command Bar and plugins only.

```lua
--!strict
-- Command Bar: print a Markdown index of remotes and flag modules without headers.
-- Read-only. Paste the output into the knowledge base page "Generated / Remotes".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local lines: { string } = {
	"| Remote | Class | Doc |",
	"|---|---|---|",
}
local undocumented = 0
for _, inst in ReplicatedStorage:GetDescendants() do
	if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") or inst:IsA("RemoteFunction") then
		local doc = inst:GetAttribute("Doc")
		if typeof(doc) ~= "string" or doc == "" then
			undocumented += 1
			doc = "**missing**"
		end
		local path = string.gsub(inst:GetFullName(), "^ReplicatedStorage%.", "")
		table.insert(lines, `| {path} | {inst.ClassName} | {doc} |`)
	end
end
print(table.concat(lines, "\n"))
print(`{#lines - 2} remotes, {undocumented} without a Doc attribute`)

local function hasHeader(source: string): boolean
	-- Accept "--!strict" (or another directive) followed by a block or line comment.
	local body = string.gsub(source, "^%s*%-%-![^\n]*\n", "")
	return string.match(body, "^%s*%-%-") ~= nil
end

local missing: { string } = {}
for _, root in { ReplicatedStorage, ServerScriptService } do
	for _, inst in root:GetDescendants() do
		if inst:IsA("ModuleScript") then
			local ok, source = pcall(function()
				return (inst :: any).Source :: string
			end)
			if ok and source and not hasHeader(source) then
				table.insert(missing, inst:GetFullName())
			end
		end
	end
end
table.sort(missing)
print(`{#missing} modules without a header comment:`)
for _, path in missing do
	print("  " .. path)
end
```

Notes:

- The `Doc` attribute travels with the remote, so it cannot drift from it. Set it when creating the remote; review checks it.
- Skip `Packages` (Wally) folders if your vendored libraries lack headers; add a path filter.
- Teams on Rojo can run the same idea in CI over the source files instead, which keeps the generated page always current ([[Code Pipeline - Rojo Git and CI]]).

**Measured in the reference project:** generated documentation from the place (scans of systems, counts and paths) stayed accurate where hand-written lists did not ([[Documentation and Knowledge Bases]] describes the generated docs it relied on).

---

## 8. Onboarding builders, artists and designers

Non-programmers need different documents. What they need on day one (rule of thumb):

| Role | Must have | See |
|---|---|---|
| Builder | Budgets in numbers (parts, triangles, instance counts per zone), grid and scale rules, where to build test pieces, the claim system, how to hand over an area | [[Art Budgets - Triangles Draw Calls Memory]], [[Team Create Permissions and Workflows]] |
| 3D artist | Export settings, pivot and scale rules, naming, upload ownership (group, not personal), texture size limits | [[Exporting and Validating Models for Roblox]], [[Asset Pipelines]] |
| Animator | Rig conventions, naming sheet, priorities, upload to the group | [[Animation Asset Permissions and Groups]] |
| UI designer | The design system, screen sizes to test, which screens are built by code versus by hand | [[UI Design Systems]] |
| Game designer | Where config lives, how to change a value safely, how to read analytics | [[Data and Config Pipeline - Spreadsheets to Game]], [[Analytics and Funnels]] |

The single most valuable artifact for builders and artists is a **reference scene**: a small, approved area in the test place that shows the target style, scale and budget, with a sign listing its counts. New builders copy its standards by eye far better than they absorb a written spec.

---

## 9. Keeping onboarding docs alive

Onboarding documents rot fastest because the people who maintain them already know everything in them. Habits that work (rule of thumb):

- **Every new hire edits the onboarding docs** in their first two weeks. Make it a starter task.
- **Front matter with an owner and a last-checked date** on the day-one document and setup guide; anything unchecked for 90 days gets a warning line at the top.
- **The code review checklist includes docs:** a change that renames a remote, adds a system or changes setup must update the matching page in the same pull request.
- **Offboarding produces docs:** when someone leaves, a 30-minute handover interview recorded as a note ("what do you know that nobody else does?") is the cheapest insurance a team can buy ([[Working with Contractors and Revenue Splits]]).
- **Keep it small.** A two-screen day-one document gets read. A 40-page handbook does not.

---

## 10. When not to do all this

- **A solo developer** still benefits from module headers and ADRs, because six months later they are a new developer on their own code. Skip the onboarding plan.
- **A two-week game jam**: a one-paragraph README and the shared-place rules.
- **A contractor delivering files** does not need the full onboarding, only the brief, budgets and naming rules.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Access requested on day one | First days lost to invites and age checks | Start access a week early |
| Setup guide never re-run | New hire stuck on a missing tool | One-command setup, tested on a clean machine |
| Shared-place rules buried | New people repeat old incidents | Rules on page one |
| "Look around the codebase" as a plan | Weeks with nothing shipped | Starter tasks and a first-merge target |
| Lead as the only person to ask | Lead's work stalls, new hire waits | A buddy |
| Hand-written remote lists | Stale within a week | Generated index from `Doc` attributes |
| Same docs for artists and programmers | Builders ignore them | Role-specific day-one pages and a reference scene |
| Docs nobody owns | Rot | Owner and last-checked date; new hires fix them |

## Checklist

- [ ] Days-to-first-merged-change tracked for every hire.
- [ ] Access (age check, group role, 2SV, sandbox, repo, chat) requested a week before day one.
- [ ] One-command setup, tested on a clean machine recently.
- [ ] Two-screen day-one document with the shared-place rules on it.
- [ ] Two-week plan with starter tasks and a buddy.
- [ ] Module headers on every ModuleScript; ADRs for technical decisions.
- [ ] Generated remote and module index; `Doc` attributes on remotes.
- [ ] Role-specific pages and a reference scene for builders and artists.
- [ ] Each new hire improves the onboarding docs; handover interview on every departure.

## Connected notes
<!-- auto-links:start -->
[[Team Collaboration Start Here]] · [[Git and Source Control for Roblox]] · [[Scoping and Roles for Small Teams]] · [[Running a Small Studio as a Business]] · [[Business and Careers Start Here]] · [[Team Roles and Workflows]]
<!-- auto-links:end -->
