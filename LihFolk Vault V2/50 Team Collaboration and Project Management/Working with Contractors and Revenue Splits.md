---
tags: [team, contractors, revenue-share, payouts, groups, intake, security, luau, type/guide, area/production, level/intermediate, area/security]
---
# Working with Contractors and Revenue Splits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Vague acceptance criteria -> Numbered, checkable criteria
> - Avoid: No review window -> Fixed window, then accepted by default
> - Avoid: Unpaid change requests -> Change orders
> - Statement of work with numbered, checkable acceptance criteria and a review window.
> - Change orders for every addition; mirrored in the scope ledger.
> - Least access: file delivery, or a sandbox experience with per-game permissions.
>
> Cost: TL;DR ~150 tok · whole note ~5.6k tok. Read more: ## 5. Intake: scan every delivered model · ## 7. Split designs for several contributors · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **Not advice.** General information for Roblox teams. It is not legal, tax or financial advice. Contract, employment and tax rules differ by country. Anyone under 18 needs a parent or guardian to approve agreements and payments.

The vault already covers the decisions: whether to hire, fixed pay versus revenue share, vesting and exit rules, finding people, paid trials and young developers ([[Hiring Freelancers and Revenue Shares]]); the freelancer's side of pricing and contracts ([[Commissions Pricing and Contracts]]); a contractor brief and payout basics ([[Scoping and Roles for Small Teams]]); and the group permission ladder ([[Groups Roles and Permissions for Studios]]). This note is the operating manual once you have decided to work with someone: the lifecycle of one engagement from statement of work to offboarding, acceptance criteria that cannot be argued about, change orders, a Luau intake scanner for delivered models, the exact mechanics of Roblox group payouts and how splits cascade, split designs for teams with several contributors (including a points system with code), and the operational failure modes that turn good contractors into disputes.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. The lifecycle of one engagement

Every contractor engagement passes through the same eight steps. Teams that have trouble almost always skipped one.

| Step | Output | Owner |
|---|---|---|
| 1. Statement of work | A written scope with acceptance criteria and a payment schedule | Team lead |
| 2. Agreement | Both sides confirm in writing; parent or guardian for minors | Lead and contractor |
| 3. Access | A role with the least access; a sandbox experience if they need Studio | Group admin |
| 4. Kick-off | Reference pack, naming rules, budgets, test location | Lead |
| 5. First small delivery | One asset or one function, integrated within a week | Contractor, then lead |
| 6. Deliveries and acceptance | Each milestone checked against criteria, scanned, integrated | Lead |
| 7. Payment | Promptly after acceptance, recorded | Group admin |
| 8. Offboarding | Access removed, ownership of uploads settled, notes written | Group admin and lead |

Step 5 deserves special mention: **integrate the first delivery fast.** A mismatch in pivot orientation, naming, scale or triangle budget found after one asset costs an hour; found after forty assets it costs the milestone ([[Asset Pipelines]]).

---

## 2. Acceptance criteria that cannot be argued about

Most contractor disputes are about whether something is "done". The fix is criteria that a script or a second person could check without the original author in the room. Compare:

| Vague | Checkable |
|---|---|
| "Optimised for mobile" | "Under 20,000 triangles for the whole zone; no texture over 1024 x 1024; holds 30 fps on the team's reference phone in the test experience" |
| "Clean code" | "Passes StyLua and Selene with the repo config; `--!strict` with no type errors; every remote validates arguments ([[Code Review for Luau Teams]])" |
| "Matches our style" | "Uses only colours from the palette file; outline thickness 0.1 studs; reviewed against the three reference screenshots" |
| "Works" | "The five listed test cases pass in a test server with two players, including leaving mid-round" |
| "Animation set" | "30 clips, named per the naming sheet, priorities set, uploaded to the group, ids listed in a text file" |

Write the criteria into the statement of work and number them. Acceptance then becomes: "criteria 1 to 6 pass, criterion 7 fails because the zone is at 26,000 triangles". Disputes become measurements.

### The review window

Agree how long you have to review each delivery (for example five working days) and what happens if you miss it (rule of thumb: the delivery counts as accepted). Without that clause, an owner who goes quiet for three weeks holds the contractor's payment hostage, which is unfair and is how teams get a bad reputation in the developer community.

---

## 3. Change orders

New ideas during a job are normal. Paying for them is what keeps them from becoming resentment. A change order is a short written addition:

```
Change order 2 (to statement of work "Forest zone")
Requested by: lead, 2026-10-14
Change: add a river crossing with two bridges in the north-east area
Effect on scope: +1 landmark, about +1,500 triangles (budget raised to 21,500)
Effect on price: +<amount>, paid with milestone 2
Effect on schedule: milestone 2 moves from 2026-10-20 to 2026-10-23
Agreed by: lead, contractor (both confirm in the thread)
```

Rules of thumb:

- **Anything that adds work is a change order**, including "small" tweaks after acceptance.
- **Feedback that brings a delivery up to the agreed criteria is not** a change order; it is the review round included in the price.
- **Two included review rounds** per milestone is a common, fair default; the third is billed.

The scope ledger in [[Roadmaps Milestones and Scope Control]] is the internal mirror of this: every change order should appear there, so the team sees what contractor changes cost.

---

## 4. Access: the minimum that works

Access decisions are covered in depth in [[Team Create Permissions and Workflows]]. The short version for contractors:

- **Deliver files where possible.** A `.rbxm` model or source files in a repository branch need no access to your place at all.
- **If they need Studio, use a separate sandbox experience** owned by the group, with per-game Edit and Playtest for the contractor role on that experience only. The docs list Edit, Playtest, Publish, monetization, secrets, analytics and the Data Stores permissions as optionally per game (Roblox docs, as of October 2026). Do not add a sandbox place inside the live universe; permissions attach to the experience.
- **Keep private assets out of sandboxes.** Grants of restricted assets to an experience are permanent (Roblox docs, asset privacy).
- **Uploads go to the group.** Animations, meshes and images uploaded to a contractor's personal account may not work in the group's game and cannot be reclaimed later ([[Animation Asset Permissions and Groups]]). If they must upload, give them a role allowed to create development items for the group, and remove it at the end.
- **Code contractors get a branch, not the main line.** If you use Git, they open pull requests; a team member merges ([[Code Review for Luau Teams]]).

---

## 5. Intake: scan every delivered model

Delivered models are the classic route for backdoors: a script hidden deep inside a prop that `require`s an outside module or calls `loadstring` ([[Creator Store and Toolbox Safety]], [[Links - Backdoors and malicious assets]]). Most contractors are honest; some reuse kits they downloaded without checking them, which is how the backdoor gets in. Scan before inserting into anything that matters.

Insert the delivery into a **scratch place** first, put it under `ServerStorage.Intake`, and run this from the Command Bar. Reading `Source` works in the Command Bar and in plugins, not in game scripts.

```lua
--!strict
-- Command Bar: scan everything under ServerStorage.Intake for risky content.
-- Read-only. Prints findings by severity. Run in a scratch place, not the live place.
local ServerStorage = game:GetService("ServerStorage")

local intake = ServerStorage:FindFirstChild("Intake")
assert(intake, "put the delivered model under ServerStorage.Intake")

type Finding = { severity: string, path: string, why: string }
local findings: { Finding } = {}

local function add(severity: string, inst: Instance, why: string)
	table.insert(findings, { severity = severity, path = inst:GetFullName(), why = why })
end

-- Source patterns worth a human look. Plain-text find, case-sensitive.
local HIGH_PATTERNS = { "require(", "loadstring", "getfenv", "setfenv", "HttpService", "InsertService",
	"TeleportService", "MarketplaceService", "MessagingService", "DataStoreService" }
local MEDIUM_PATTERNS = { "string.char", "string.reverse", "\\x", "\\u{", "Players:Ban", ":Kick(" }

local counts = { scripts = 0, instances = 0 }

for _, inst in intake:GetDescendants() do
	counts.instances += 1
	if inst:IsA("LuaSourceContainer") then
		counts.scripts += 1
		add("HIGH", inst, `{inst.ClassName} present (art deliveries should contain none)`)
		local ok, source = pcall(function()
			return (inst :: any).Source :: string
		end)
		if ok and source then
			for _, p in HIGH_PATTERNS do
				if string.find(source, p, 1, true) then
					add("HIGH", inst, `source contains "{p}"`)
				end
			end
			for _, p in MEDIUM_PATTERNS do
				if string.find(source, p, 1, true) then
					add("MEDIUM", inst, `source contains "{p}" (possible obfuscation or moderation code)`)
				end
			end
			if #source > 20000 and not string.find(source, "\n", 1, true) then
				add("HIGH", inst, "very long single-line source (typical of obfuscated code)")
			end
		end
	elseif inst:IsA("BasePart") and inst.Transparency >= 1 and #inst:GetChildren() > 0 then
		add("LOW", inst, "invisible part with children; check what it holds")
	elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("BindableEvent") then
		add("MEDIUM", inst, `{inst.ClassName} inside a delivered model`)
	end
	if inst:IsA("IntValue") and inst.Value > 1000000 then
		add("LOW", inst, "large IntValue; could be an asset id used by a loader")
	end
end

local ORDER: { [string]: number } = { HIGH = 1, MEDIUM = 2, LOW = 3 }
table.sort(findings, function(a: Finding, b: Finding)
	return ORDER[a.severity] < ORDER[b.severity]
end)
for _, f in findings do
	print(`[{f.severity}] {f.path}: {f.why}`)
end
print(`{counts.instances} instances, {counts.scripts} scripts, {#findings} findings`)
```

How to use the result (rule of thumb):

- **Art deliveries with any script** go back to the contractor, unless the statement of work asked for scripts. "It came with the kit" is not a reason.
- **Code deliveries** will trigger many HIGH lines legitimately (a shop module uses `MarketplaceService`). The scan then becomes a reading list: open each flagged script and check the use is the one you asked for.
- **A clean scan is not proof of safety.** Obfuscation can avoid every literal pattern. The scanner catches carelessness and lazy malware; review catches the rest.
- **Never run the delivery's scripts before reading them.** Do not press Play in a place containing an unreviewed delivery.

**Measured in the reference project:** the team's rule was that delivered models contain no scripts, and every insert was checked before it went into the shared place; toolbox models were banned from contractor briefs outright ([[Scoping and Roles for Small Teams]]). The scanner above automates the first check.

---

## 6. How Roblox group payouts actually move Robux

Roblox docs (as of October 2026) describe the mechanics:

- **Who:** the group owner, or members whose role has the group revenue permission, see **Payouts** under Finances. "Manage and spend group revenue" requires two-step verification to grant. Some groups do not see Payouts at first, for example because of group age or insufficient funds.
- **One-time payouts:** **Send Robux** to chosen members with a fixed amount each, or upload a CSV with two columns, `userId` and `payoutInRobux`.
- **Recurring payouts:** percentage splits, set for the whole group or per experience.
- **Cascade:** an experience's split pays its listed members first; **the remainder flows into the group split**; what remains after that goes to the group balance.
- **Private servers:** the percentages in force when a private server subscription was bought keep applying to that subscription until it is cancelled (the docs say this policy may change).
- **Exclusion:** experiences that charge paid access in local currency cannot share payouts across members.
- **Safety:** two-step challenges, confirmations and member eligibility checks. The docs do not spell out the eligibility rules; community sources mention membership waiting periods and whole-number percentages, both **unconfirmed**.

### The cascade, worked

The docs' own example uses an experience split of 40%, 30% and 10% with a 20% remainder, and a group split of 20%, 20% and 10%. On 1,000 Robux:

```
Experience split (per game):
  member A 40%  ->  400
  member B 30%  ->  300
  member C 10%  ->  100
  remainder 20% ->  200  flows to the group split

Group split (applies to the 200):
  member D 20%  ->   40
  member E 20%  ->   40
  member F 10%  ->   20
  remainder 50% ->  100  stays in the group balance
```

The trap: a member on the **group** split at 20% does not get 20% of the game's earnings; they get 20% of what is left after the game split. In this example D receives 4% of the game's revenue. Teams that put core members on the group split and contractors on a game split often discover that their core members earn less than intended. Write the effective percentage of game revenue next to every split in the agreement.

### Paying contractors with one-time payouts

For fixed-price contractors, one-time payouts are cleaner than any recurring split. Keep a payouts sheet with one row per accepted milestone (contractor, user id, statement of work, milestone, amount, acceptance date, paid date). The CSV for a batch is then a filtered export:

```
userId,payoutInRobux
0000000001,15000
0000000002,8000
```

Check every user id against the agreement before uploading. A mistyped id sends Robux to a stranger, and there is no documented reversal.

Remember that Robux paid to a contractor only becomes money through their own DevEx, with its own minimum and rate rules ([[DevEx and Cashing Out]]). Small payouts can leave them below the cash-out minimum for months; tell them up front.

---

## 7. Split designs for several contributors

[[Hiring Freelancers and Revenue Shares]] explains vesting, exit rules and why shares are of revenue, not profit. Teams with four or more long-term contributors need a structure for the whole table, not one negotiation per person. Four designs, with their trade-offs (rule of thumb):

| Design | How it works | Good for | Breaks when |
|---|---|---|---|
| **Fixed percentages** | Each person's share agreed once | Two or three founders | Contribution changes; someone stops working |
| **Capped share** | A percentage until a total amount has been paid, then it ends | Early helpers paid in hope | The game earns slowly; the cap feels endless |
| **Sunset share** | A percentage for a fixed period after launch | Contractors who took a pay cut | Rarely; simple and fair |
| **Points pool** | A fixed pool (say 40%) shared by points earned for contribution, recalculated monthly or quarterly | Teams whose membership changes | Points rules are vague or gamed |

### A points pool with code

A points pool turns "who deserves what" into a monthly, mechanical calculation, as long as everyone agrees on how points are earned (for example per accepted milestone, weighted by size). The calculation then converts points to payout percentages, which must sum to the pool. Integer percentages need care: rounding each share independently can over-allocate. The largest remainder method fixes that.

```lua
--!strict
-- Points pool to integer payout percentages, using the largest remainder method.
-- pool: the total percentage given to contributors (for example 40).
-- points: map from user id to points earned this period.
-- Returns a map from user id to whole-number percentage; the values sum exactly to pool
-- (or to 0 if nobody has points).

type Shares = { [number]: number }

local function allocate(pool: number, points: { [number]: number }): Shares
	assert(pool >= 0 and pool <= 100 and pool == math.floor(pool), "pool must be a whole percentage")
	local total = 0
	for _, p in points do
		assert(p >= 0, "points cannot be negative")
		total += p
	end
	local result: Shares = {}
	if total == 0 then
		return result
	end

	type Row = { id: number, floorPct: number, remainder: number }
	local rows: { Row } = {}
	local assigned = 0
	for id, p in points do
		local exact = pool * p / total
		local f = math.floor(exact)
		table.insert(rows, { id = id, floorPct = f, remainder = exact - f })
		assigned += f
	end

	-- Hand out the leftover whole percents to the largest remainders; ties go to the lower id
	-- so the result is deterministic.
	table.sort(rows, function(a: Row, b: Row)
		if a.remainder ~= b.remainder then
			return a.remainder > b.remainder
		end
		return a.id < b.id
	end)
	local leftover = pool - assigned
	for i, row in rows do
		result[row.id] = row.floorPct + (if i <= leftover then 1 else 0)
	end
	return result
end

-- Example: a 40% pool and one quarter's points.
local shares = allocate(40, {
	[1001] = 120, -- programmer
	[1002] = 95, -- builder
	[1003] = 60, -- animator
	[1004] = 25, -- UI artist
})
for id, pct in shares do
	print(id, pct .. "%")
end
-- Exact shares are 16.0, 12.67, 8.0, 3.33; floors 16, 12, 8, 3 = 39;
-- the one leftover percent goes to the largest remainder (12.67), giving 16, 13, 8, 3.
```

Run it outside the game (in Studio's Command Bar or a Luau runtime); it is a calculator, not game code. Rules that make a points pool fair (rule of thumb):

- **Points are earned only on acceptance**, never on effort claimed.
- **Publish the points table** to the whole team every period.
- **Points decay.** Use a rolling window (the last two quarters), so people who stop contributing fade out without a confrontation.
- **The pool is fixed in advance.** New members dilute everyone in proportion, not the founder alone.
- **The dashboard follows the calculation**, changed by one admin on a fixed day, and the change is posted with the table. Changing a percentage is visible to the recipient; never surprise them ([[Groups Roles and Permissions for Studios]]).

Whether percentages must be whole numbers is not stated in the docs; the function produces whole numbers because that is the safe assumption.

---

## 8. Offboarding

When an engagement ends, well or badly, run the same list the same day (rule of thumb, extending the offboarding list in [[Groups Roles and Permissions for Studios]]):

1. Remove group roles and per-game permissions; remove them from any sandbox experience.
2. Remove repository, Discord, drive and tracker access.
3. List assets they uploaded. Anything under their personal account that the game uses needs a plan: re-upload under the group if the agreement allows, and replace ids ([[Packages and Shared Assets Across Places]] has the package version of this problem).
4. Rotate secrets and API keys they could see ([[Open Cloud APIs]]).
5. Update recurring splits according to the agreement's exit rule, with a message first.
6. Write a handover note in the knowledge base: what they built, where it lives, known issues ([[Documentation and Onboarding New Developers]]).
7. Credit them if agreed, and pay any outstanding amount promptly.

---

## 9. When things go wrong

| Situation | First moves |
|---|---|
| Contractor goes silent mid-milestone | Message on the agreed channel with a date; after the agreed silence period, end per the agreement; pay for accepted work only |
| Delivery fails acceptance twice | Point to numbered criteria; offer one more round or end with payment for accepted milestones |
| A backdoor found in a delivery | Do not insert it anywhere; keep a copy as evidence; end the engagement; check every previous delivery from the same person |
| Disagreement about a revenue share | Return to the written agreement; if there is none, agree one now for the future and do not change past payouts unilaterally |
| A core member leaves angry | Remove access first, then talk; rotate secrets; apply the exit rule |

Roblox does not arbitrate disagreements between group members; the group owner's settings decide where Robux goes ([[Groups Roles and Permissions for Studios]] cites the docs on this). That is why the written agreement matters: it is the only thing anyone can point to.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Vague acceptance criteria | "It's done" versus "it isn't" | Numbered, checkable criteria |
| No review window | Payments delayed for weeks | Fixed window, then accepted by default |
| Unpaid change requests | Resentment, slipping dates | Change orders |
| Contractors in the live universe | Accidental edits to the start place | Separate sandbox experience |
| Art deliveries inserted unscanned | Hidden scripts in the live game | Intake scan in a scratch place |
| Core members on the group split | They earn a share of the remainder only | Compute effective percentages; use per-game splits |
| Rounded percentages over 100% of the pool | Dashboard rejects or someone is short | Largest remainder allocation |
| No offboarding | Ex-contractors still hold roles and keys | Same-day offboarding list |

## Checklist

- [ ] Statement of work with numbered, checkable acceptance criteria and a review window.
- [ ] Change orders for every addition; mirrored in the scope ledger.
- [ ] Least access: file delivery, or a sandbox experience with per-game permissions.
- [ ] Uploads go to the group.
- [ ] Every delivery scanned in a scratch place before use.
- [ ] Effective percentage of game revenue written next to every split.
- [ ] One-time payouts for fixed-price work; user ids checked against the agreement.
- [ ] Multi-contributor teams use a declared split design; points pools use deterministic allocation.
- [ ] Same-day offboarding, including uploads, secrets and splits.
- [ ] Parent or guardian involved for anyone under 18.

## Connected notes
<!-- auto-links:start -->
[[Team Collaboration Start Here]] · [[Running a Small Studio as a Business]] · Business and Careers Start Here · Legal Basics - IP Licenses and Assets · Working with Content Creators · Subscriptions and Recurring Revenue
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Legal Basics - IP Licenses and Assets]] · [[Creator Account Security and Takeover Recovery]] · [[Working with Content Creators]] · [[Community Building]] · [[Building a Portfolio as a Roblox Developer]] · [[Plugin Security and Permissions]]
<!-- related:end -->
