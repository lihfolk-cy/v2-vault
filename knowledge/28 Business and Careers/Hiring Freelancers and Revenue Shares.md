---
tags: [business, hiring, freelancers, revenue-share, payouts, groups, contracts, minors]
---
# Hiring Freelancers and Revenue Shares

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Revenue shares for bounded work.
> - Avoid: Shares with no vesting, contribution rule or exit.
> - Avoid: Giving away more total share than the game can carry after costs.
> - Work is bounded and briefable; review time budgeted.
> - Fixed pay for contractors; shares only for core members, from a set pool.
> - Paid trial task.
>
> Read more (15 KB note): ## 2. Finding people · ## 5. Revenue shares in depth · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **Not advice.** General information for game owners who hire help. It is not legal, tax or financial advice, and rules differ by country (employment status, contractor rules, tax reporting, consumer and contract law). Ask a qualified professional before committing to large payments or long revenue shares. **Minors** (anyone under 18) need a parent or guardian to approve any agreement and to handle payment; plan for that when you hire young developers, and when you are young yourself.

[[Scoping and Roles for Small Teams]] introduced group payouts, contractor briefs and access rules. [[Commissions Pricing and Contracts]] is the freelancer's side. This note is the owner's side in depth: deciding whether to hire, finding and testing people, choosing between fixed pay and revenue shares, the maths of shares, and how to protect the game while outsiders work on it.

The core idea: **hiring adds capacity and adds risk at the same time.** Every rule below exists to keep the capacity and limit the risk.

---

## 1. Should you hire at all?

Hire when the work is:

- **clearly bounded** (a map, a set of icons, 30 animations, a known system);
- **outside your skills** and would take you several times longer to learn;
- **not core to the game's identity** (the core loop's feel is hard to outsource; content around it is easier).

Do not hire (yet) when:

- you cannot write the brief, because you do not know what you want (prototype first, [[Planning and Scoping a Roblox Game]]);
- you have no time to review: rule of thumb, budget 20 to 30% of the freelancer's hours as your own time for briefs and review ([[Scoping and Roles for Small Teams]]);
- the money would be better spent finding out whether players want the game at all.

### Fixed pay versus revenue share: the decision

| Question | Fixed pay | Revenue share |
|---|---|---|
| Is the work bounded? | Yes | Usually no (ongoing role) |
| Do you have money now? | Needed | Not needed |
| Will the person be around in six months? | Not important | Essential |
| Do you want to keep full control? | Easy | Shares create expectations of a say |
| Will the game earn? | Irrelevant to them | Everything to them |

Rule of thumb: **pay contractors fixed; give shares only to core team members**, and even then, prefer a small share plus some fixed pay over a large share alone.

---

## 2. Finding people

Channels developers commonly use (as of October 2026): the Roblox DevForum's collaboration and hiring areas, Roblox's Talent Hub (its current state and features were **not confirmed** for this note; check the Creator Hub), developer Discord servers ([[Discord Servers for Roblox Games]]), and social media portfolios. Referrals from people you have worked with beat all of them.

### What to look for in a portfolio

- **Work like yours.** A beautiful realistic map says little about low-poly phone-friendly maps.
- **Shipped work.** Systems in live games have faced real players and exploiters. Ask what broke after release and how they fixed it.
- **Process, not only results.** Wireframes, iterations, budgets, before and after.
- **Their part.** In team projects, ask exactly what they did.

[[Building a Portfolio as a Roblox Developer]] explains the same thing from the candidate's side.

### Paid trial tasks

A short paid trial (2 to 4 hours of real but non-critical work) tells you more than any interview. Rules:

- Pay for it. Unpaid "tests" that look like real work push good people away and are how scams against freelancers work.
- Make it representative: a small system in a test place, one prop in your style at your budget.
- Judge communication as much as output: did they ask good questions, report progress, meet the time?

---

## 3. The brief and the agreement

The brief template in [[Scoping and Roles for Small Teams]] is the starting point: task, style, budgets in numbers, must include, must not include, delivery format, review rule, price and schedule. Add the items an owner cares about most:

| Item | Why the owner cares |
|---|---|
| **Ownership after payment** | You need to own or have a permanent licence to everything in your game ([[Legal Basics - IP Licenses and Assets]]) |
| **Asset upload ownership** | Assets uploaded to the freelancer's account can stop working in your group's game or be revoked ([[Animation Asset Permissions and Groups]]) |
| **No third-party content without a licence list** | A model with copied meshes or music exposes your game to takedowns |
| **No scripts in art deliveries** | Hidden scripts are a classic backdoor ([[Creator Store and Toolbox Safety]]) |
| **Confidentiality** | Unreleased content leaking hurts launches |
| **Portfolio rights after release** | Fair to the freelancer; costs you little |
| **Who signs** | A parent or guardian, if the freelancer is under 18 |

[[Commissions Pricing and Contracts]] has the minimal agreement checklist and sample ownership wording.

---

## 4. Protecting the game during the work

- **No access to the live place.** Deliver files, or give Team Create access to a copy ([[Team Create and Collaboration]], [[Safe Changes in a Shared Place]]).
- **Least privilege in the group.** A role that can upload assets does not need publish or revenue rights. Remove roles when the job ends ([[Groups Roles and Permissions for Studios]]).
- **Review every delivered model** for scripts, `require` calls with ids, and odd objects before inserting it ([[Exploits and Anti-Cheat]]).
- **Review code** for backdoors, debug remotes, and validation gaps before it reaches players ([[Server Authority and Validation]]).
- **Keep version history and backups** before integrating outside work ([[Version History and Backups]]).

Nuance: trust grows with history, but access should grow with need, not with trust. A long-time contractor who now does only icons does not need the editor role they had when they built the map.

---

## 5. Revenue shares in depth

On Roblox, revenue shares usually run through **group recurring payouts**: each member gets a set percentage of an experience's earnings (or of group revenue), and the remainder stays in the group (Roblox docs, as of October 2026; details in [[Scoping and Roles for Small Teams]]). Each member then cashes out on their own through DevEx, with their own minimum, tax form and schedule ([[DevEx and Cashing Out]]).

### The maths most people skip

**Shares are of revenue, not profit.** If the group must also pay for ads, contractors and assets, every percentage given away comes out of the money you use to grow the game.

```
Monthly Earned Robux:            100,000
Shares (two members, 20% each):  -40,000
Left in the group:                60,000
Planned ad spend:                -30,000  (see [[Sponsored Ads and Campaign Math]])
Contractor payouts:              -20,000
Owner's effective share:          10,000  (10%)
```

The owner, who "kept 60%", has 10% after costs. That is fine if it was planned; it is a crisis if it was not.

**Dilution.** Every new core member needs a share. If early members hold large shares, there is nothing left to attract the next person. Rule of thumb: decide a total "team pool" (for example 30 to 40% of revenue) up front, and allocate from it.

**Value of a share.** Most games earn little. A 25% share of a game that never earns is worth nothing, and the person who worked for it knows that only after months. Be honest about this when offering shares. Do not oversell.

### Vesting and exit rules

Revenue shares cause the bitterest disputes when someone leaves. Agree in advance:

- **Earn-in (vesting).** The share grows over time: for example 0% for the first month (trial), then rising to the full share over six months of active work.
- **Contribution requirement.** "Active" defined in hours or deliverables per month.
- **Exit.** When someone stops contributing, their share continues for a set time (for example three to six months) or reduces to a smaller permanent share, then ends.
- **Removal for cause.** What counts (abuse, leaks, sabotage, breaking Roblox rules) and that the share ends at once.
- **Game sale or transfer.** What happens to shares if the game is sold or moved to another group.

Sample wording:

```
Share: 15% of the experience's monthly Earned Robux, via group recurring
payouts, vesting from 0% to 15% evenly over the first six months of active
contribution (at least 40 hours or the agreed deliverables per month).
If the member stops contributing, the share continues for three months,
then reduces to 3% for twelve months, then ends.
The owner may change payout settings to apply these terms.
```

Whether wording like this is enforceable outside Roblox's own settings depends on local law. In practice, the group's payout settings are what actually move Robux; the written agreement is what everyone points at when changing them.

### Fixed pay plus a small share

For key people who accept below-market pay:

```
Fixed: <amount> per milestone (paid in full regardless of revenue)
Share: 5% of Earned Robux for 12 months after launch, then ends
```

This rewards the risk they took without tying the game's future revenue to them forever.

---

## 6. Paying in Robux or in money

| | Robux (group payouts) | Money |
|---|---|---|
| Owner's admin | Low | High: you must DevEx first, then pay from a bank or payment service |
| Rate risk | Freelancer's (they choose when to cash out) | Owner's |
| Minimums | Freelancer needs 30,000 Earned Robux to DevEx | None from Roblox |
| Young freelancers | Often simpler, but a parent or guardian should still approve | A parent or guardian's account and approval |
| Tax | Each person handles their own (as general practice; check locally) | Depends on country; the owner may have reporting duties |

Practical points:

- **Small one-off jobs paid in Robux** leave the freelancer below the DevEx minimum for months. Tell them, or round up payouts.
- **Group payout eligibility** may involve member requirements and waiting periods for new members; community sources mention them but the details are **unverified** ([[Scoping and Roles for Small Teams]]). Check before promising a date.
- **Records.** Keep who, what for, when, how much, in Robux or money ([[Running a Small Studio as a Business]]).

---

## 7. Hiring young developers

Many talented Roblox developers are under 18. Hiring them is normal, and it brings duties:

- **Child safety first.** Keep communication in channels with safety tools and in groups, not private one-to-one apps. Never ask for personal information, photos or video calls. Adults working with minors should keep conversations professional, task-focused and visible to others on the team. Roblox's Community Standards apply ([[Roblox Policies Ratings and Compliance]]).
- **Parent or guardian approval** of the agreement and payment arrangements. A short message to the parent or guardian with the scope, price and schedule is the minimum.
- **Reasonable hours.** Do not set deadlines that only work if a student skips school or sleep.
- **Payments** to minors through outside payment services usually need an adult's account; Robux payouts are simpler but DevEx still needs an adult's help for the portal and tax setup ([[DevEx and Cashing Out]]).

---

## 8. Managing the work

- **One owner for each freelancer**, who answers questions within a day.
- **Weekly check-in** with something to see (a video, a test place link, screenshots).
- **Review against the brief**, not against new ideas. New ideas are new scope; pay for them.
- **Integrate early.** The first deliverable from a new freelancer should be small and integrated within a week, so mismatches (naming, budgets, style) show up before they repeat across 40 assets ([[Asset Pipelines]]).
- **Document their work** in your knowledge base so it outlives them ([[Documentation and Knowledge Bases]]).

### Ending well

- Pay promptly.
- Remove access.
- Give honest feedback and a reference if deserved; good freelancers talk to each other.
- Credit them in the game (a credits board or page) if agreed; it costs nothing and earns goodwill.

---

## 9. Worked example: one hire, two ways

A solo owner needs a 30-animation combat set.

**Option A, fixed:** quoted 30 animations at a per-animation price, three milestones (10 each), delivered as files the owner uploads to the group, style reference and timing chart in the brief ([[Combat Animation Craft]], [[Publishing Animations]]). Total cost known in advance; the animator has no stake in the game; owner owns the files after payment.

**Option B, share:** animator offered 10% of revenue for "all animation work". Six months later the game earns 50,000 Robux a month; the animator has done 30 animations and wants to stop. Without an exit rule, they keep 5,000 Robux a month forever while the owner pays someone else for new animations. Both feel cheated.

Option A was right for bounded work. Option B needed vesting, a contribution requirement and an exit rule to be fair.

---

## When not to do all this

- Game jams and friends' hobby projects: still write down who owns what and that nobody is paid. A three-line note avoids "I thought I owned half" later.
- Buying assets from the Creator Store: that is a licence, not a hire ([[Legal Basics - IP Licenses and Assets]]).

## Common mistakes

- Revenue shares for bounded work.
- Shares with no vesting, contribution rule or exit.
- Giving away more total share than the game can carry after costs.
- Unpaid "test" tasks.
- Freelancers working in the live place, or keeping roles after the job.
- Assets uploaded to freelancers' accounts with no plan.
- Inserting delivered models without checking for scripts.
- Promising payout dates without checking group payout rules.
- Hiring minors without involving a parent or guardian; private one-to-one chats with minors.
- No records of who was paid what.

## Checklist

- [ ] Work is bounded and briefable; review time budgeted.
- [ ] Fixed pay for contractors; shares only for core members, from a set pool.
- [ ] Paid trial task.
- [ ] Agreement covers ownership, asset uploads, licences, confidentiality, portfolio rights.
- [ ] Vesting, contribution and exit rules for every share.
- [ ] Least-privilege group roles; access removed at the end.
- [ ] Delivered models and code reviewed before use.
- [ ] Parent or guardian approval for any minor; communication in safe, visible channels.
- [ ] Payment records kept.

## See also

[[Business and Careers Start Here]], [[Commissions Pricing and Contracts]], [[DevEx and Cashing Out]], [[Running a Small Studio as a Business]], [[Legal Basics - IP Licenses and Assets]], [[Scoping and Roles for Small Teams]], [[Team Roles and Workflows]], [[Groups Roles and Permissions for Studios]], [[Creator Store and Toolbox Safety]], [[Animation Asset Permissions and Groups]]

## Connected notes
<!-- auto-links:start -->
[[Working with Contractors and Revenue Splits]] · [[Team Collaboration Start Here]] · [[Working with Content Creators]] · [[Documentation and Onboarding New Developers]] · [[Community and Moderation Start Here]] · [[Publishing Selling and Updating Plugins]]
<!-- auto-links:end -->
