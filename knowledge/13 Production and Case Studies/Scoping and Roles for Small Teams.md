---
tags: [production, scope, team, capacity, payouts, contractors, permissions, planning]
---
# Scoping and Roles for Small Teams

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Planning with raw hours instead of productive hours.
> - Avoid: Estimating the first unit of a content type like the hundredth.
> - Avoid: No hours for integration, testing or data safety.
> - Productive hours per week written down, per person.
> - Every feature estimated as a range; integration and testing added.
> - Total compared with capacity; cuts decided and recorded.
>
> Read more (16 KB note): ## 1. Capacity: the number nobody writes down · ## 5. Money and access on Roblox · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Planning and Scoping a Roblox Game]] covers counting content, phase gates and scope reversals. [[Team Roles and Workflows]] covers the role table, ownership maps and the daily loop. This note covers what sits between them for teams of one to six people: turning available hours into a scope that fits, the team shapes that work at each size, who decides what, how money and access are handled on Roblox, and how to work with contractors without losing control of your game.

The core idea: on a small team, **scope is a function of capacity, and capacity is smaller than everyone thinks**.

---

## 1. Capacity: the number nobody writes down

Write down hours, not intentions.

```
weekly capacity = sum over people of (hours available per week x focus factor)
```

The focus factor is the share of hours that become finished work after meetings, context switching, bug fixing, reviews, tooling and "where did the afternoon go". Rule of thumb values:

| Situation | Focus factor |
|---|---|
| Solo, full-time, no live game | 0.6 to 0.7 |
| Team of 3 to 5, pre-launch | 0.5 to 0.6 |
| Any team with a live game | 0.3 to 0.5 (live ops eats the rest) |
| Part-time hobby hours (evenings) | 0.4 to 0.5 (start-up cost per session is high) |

Worked example, a three-person team before launch:

| Person | Hours per week | Focus | Productive hours |
|---|---|---|---|
| Scripter (part-time) | 15 | 0.5 | 7.5 |
| Builder and modeller | 20 | 0.55 | 11 |
| Owner (design, UI, testing, community) | 10 | 0.5 | 5 |
| **Total** | 45 | | **23.5** |

Twenty-three and a half productive hours a week, from a team that "works 45 hours a week". Over 12 weeks, about 280 hours. Every plan should be checked against that number.

### Estimate the work in ranges

For each feature, estimate a low and a high in hours, then plan with roughly the average of the two plus a share for integration. Integration (wiring the system into UI, data, analytics, testing, fixing what it broke) is the part small teams forget. Rule of thumb: add 30 to 50% to the sum of feature estimates for integration and testing.

Measured reference point from one production game: a finished, animated weapon through a mature pipeline took about 1 to 1.5 hours of work. That speed came *after* weeks of building the pipeline. The first weapon took far longer. Estimate the first unit of any content type separately from the rest ([[Asset Pipelines]]).

### Compare and cut

If the plan needs 450 hours and you have 280, something goes. The cut is a decision, made now, not a hope that "we will be faster". Section 4 shows how to cut.

---

## 2. Team shapes that work

### Solo

You hold every role. The danger is not lack of skill; it is spending the week on the role you enjoy. Fix it with a weekly rotation: name which role each day belongs to (for example: two days systems, two days content, one day testing and community). Scope rule of thumb: one core loop, one environment, a content set you can build in a month, and a launch within three months. Anything larger needs a pipeline first.

### Two people

The common split is **systems** (scripting, data, monetisation) and **content** (building, modelling, UI art). One of the two must also own design decisions and the release. Write that down: "B decides design questions, A has the final say on anything touching saves and purchases" ([[Team Roles and Workflows]]).

Failure mode: both people do content because it is visible progress, and the systems work (saves, security, analytics) is left until launch week.

### Three to four people

Add a dedicated UI person or a second builder. At this size you need an **integrator**: someone who merges work into the place, keeps shared modules consistent, and runs the release ([[Safe Changes in a Shared Place]]). Without one, the place drifts into folders that nobody owns.

### Five to six people

Two workstreams can run in parallel (for example, a new world and a new system). You now need written briefs for each workstream, an ownership map, and a weekly planning meeting. The overhead is real: at this size the focus factor drops, and one person's time becomes mostly coordination.

### Beyond six

Most of this note still applies, but you are now running a studio. Specialist roles (producer, community manager, QA) start to pay for themselves.

---

## 3. Decision rights

Small teams lose more time to unclear decisions than to slow work. For each kind of decision, name who decides, who must be asked, and who is told.

| Decision | Decides | Asked first | Told |
|---|---|---|---|
| Game direction, what to build next | Owner | Everyone | |
| Prices, products, odds | Owner | Systems | Everyone |
| Data schema changes | Systems | Owner | Everyone |
| Art style and UI look | Owner or art lead | Content | |
| When to publish, restart servers | Release owner | Integrator | Everyone |
| Turning off a live feature during an incident | Anyone on the incident list | | Everyone, immediately |
| Hiring a contractor, spending money | Owner | | Everyone |

The incident row is deliberate: in an emergency, anyone with access must be allowed to pull a kill switch without waiting for approval ([[Live Incident Response and Post-Mortems]]).

The reference project worked with a single owner who held the "approved" decision on taste and priorities, and builders who proposed. That worked when the owner reviewed often, and stalled when review was slow: finished work queued behind a single reviewer. If one person must approve everything, schedule their review time like any other task.

---

## 4. Cutting scope without killing the game

### Cut by layer, not by feature

Every feature has layers: the core rule, the UI, the polish, the content volume. Cutting a whole feature is painful; cutting layers is often invisible to players.

| Feature | Core (keep) | First cut | Second cut |
|---|---|---|---|
| Pets | Pets follow and boost | Fewer pets at launch (12, not 40) | No pet animations beyond idle and walk |
| Trading | Two-player trade with confirmation | No trade history UI | No trade-in-world, menu only |
| Quests | Daily quests with three types | Fewer quest types | No quest chains |
| Worlds | One world, polished | Three zones instead of six | Reuse zone layouts with new themes |

### Cut by asking "does launch need this?"

For every item on the list: if it is missing at launch, does a player notice in the first session? Things players notice in the first session: the core loop, the first ten minutes, the shop, saving, performance on their phone. Things they do not: the fifth world, trading (for a while), leaderboards beyond one, settings beyond the basics ([[Core Loops and Session Design]], [[First-Time User Experience and Onboarding]]).

### Protect the boring work

The items most often cut by accident are the ones that are not visible: data safety, security validation, analytics, testing time, and the release process. These are cheap before launch and very expensive after an incident. Put them in the plan as named items with hours, not as "we will do it along the way". The reference project's first month shows the cost: testing time was never scheduled, and nearly every system ended the month as "not play-tested" ([[Planning and Scoping a Roblox Game]]).

### Scope creep has a signature

Watch for: new features entering the plan without an estimate, an item's estimate quietly tripling, and "while I am in there" additions. A cheap defence: any new item must name what it replaces, or must come with its hours added to the total in the open.

---

## 5. Money and access on Roblox

### Own the game through a group

Put the experience under a Roblox **group**, not a personal account (rule of thumb, near universal advice). Then:
- Roles in the group decide who can edit, publish, see revenue and manage payouts.
- Assets (models, images, audio, animations) uploaded to the group are usable by the group's experiences; assets uploaded to a personal account may need permission changes to work in the group's game ([[Animation Asset Permissions and Groups]]).
- If a member leaves, the game stays.

Give each member the least access they need. A builder does not need permission to publish or manage revenue. Keep at least two trusted people able to publish and change live flags, so an incident at 2 a.m. does not depend on one person being awake. Turn on two-step verification for everyone with edit or revenue access.

### Paying people

Roblox docs (as of October 2026) describe two group payout types:
- **One-time payouts**: the group owner (or a role allowed to manage group revenue) sends set amounts of Robux to members, individually or in a batch (the docs mention a CSV upload with a user id and amount per row). Safety checks include two-step verification challenges and member eligibility checks.
- **Recurring payouts**: each member gets a fixed percentage of an experience's earnings (or of group revenue), with the remainder going to the group's balance.

Details the docs leave open or that come only from community sources: DevForum posts say recurring percentages must be whole numbers and that rounding sends small remainders to the group; third-party guides mention a waiting period before new members can be paid. Treat both as **unverified** and check the Creator Hub before you promise anyone a schedule.

| Model | Good for | Risk |
|---|---|---|
| Fixed price per task (one-time payout) | Contractors, clear deliverables (a map, 20 icons, a system) | You pay even if the game fails; quality must be checked before paying |
| Revenue share (recurring percentage) | Core team members committed for the long run | Hard to unwind; a member who leaves keeps their share unless you change it, which causes disputes |
| Mix: fixed plus small share | Key contributors who take a pay cut | More to agree and write down |

Rules of thumb that prevent the usual fallouts:
- **Write it down** before work starts: deliverables, price, deadline, who owns the result, what happens if the work is late or the member leaves. A message thread is better than nothing; a short shared document both people agree to is better.
- **Pay in milestones** for large jobs (for example a third on approval of the plan, a third on first playable, a third on delivery).
- **Revenue shares need an exit rule.** "Your share continues for N months after you stop contributing, then ends" avoids the most bitter disputes.
- **Keep payout records** separate from Roblox's own (who, what for, when, how much).

Real-money pay outside Roblox and Developer Exchange rules are outside this note; check Roblox's current terms, and local law where you live.

---

## 6. Working with contractors

Contractors extend a small team's capacity, but every contractor costs the team time in briefing, review and integration. Rule of thumb: budget about 20 to 30% of the contractor's hours as your own time for briefing and review.

### A brief a contractor can deliver against

```
Task: Forest zone, playable area about 600 x 600 studs
Style: matches the reference screenshots in the brief folder (low-poly, flat colours)
Budgets: under 25,000 parts and meshes total; no part under 0.2 studs;
         no unions; textures from the shared palette only
Must include: spawn, three enemy areas marked with tagged parts, one boss arena
Must not include: scripts, free models from the toolbox, lights with shadows enabled
Deliver: a .rbxm of one Model named "Zone_Forest", plus a list of assets uploaded
Review: one round of changes included
Price and schedule: <amount> in two milestones; draft in 10 days, final 5 days later
```

What makes it work: budgets in numbers ([[Art Budgets - Triangles Draw Calls Memory]]), explicit exclusions (toolbox models are a security risk: [[Creator Store and Toolbox Safety]]), a single deliverable format, and a review rule.

### Access for contractors

- Prefer delivery as a model file over giving edit access to the live place. If they need Team Create, give access to a **separate copy** of the place, not the live one ([[Team Create and Collaboration]]).
- Remove access when the job ends.
- Check every delivered model for scripts before inserting it.

---

## 7. A 12-week plan for a team of three

Putting the numbers together for the team in section 1 (about 23.5 productive hours a week, about 280 hours over 12 weeks):

| Weeks | Goal | Hours (approx.) | Gate |
|---|---|---|---|
| 1 to 2 | Core loop prototype, grey boxes | 45 | Is the loop fun for 10 minutes? If not, change it now |
| 3 to 5 | Systems: data, shop, one currency, security, analytics | 70 | Saves survive leave, rejoin and server shutdown |
| 4 to 8 | Content: one world, three zones, first 10 items | 110 | Zone budgets met on a low phone |
| 9 to 10 | UI pass, onboarding, phone layouts | 35 | New players reach the core loop in under 2 minutes |
| 11 | Playtest sessions, fixes | 15 | All blocker cards pass ([[Multi-Client and Device Playtesting Protocols]]) |
| 12 | Release, watch, fix | 5 plus live time | Kill switches tested; runbook written |
| **Total** | | **about 280** | |

Note what is not there: trading, a second world, pets, a battle pass. Those come after launch, informed by real player data ([[Analytics and Funnels]], [[Live Ops Events and Updates]]). Note also what is there: data safety, analytics and testing have their own hours.

If, at the end of week 5, systems took 100 hours instead of 70, the plan must change that week: cut content (two zones instead of three) or move the date. Re-plan at every gate; a plan that is not updated becomes fiction within a month.

---

## When not to do all this

- A weekend game jam: skip capacity maths, keep decision rights (one person decides).
- A solo hobby project with no deadline: capacity maths still helps you choose what to finish, but payouts and contractor rules do not apply.
- Very early prototypes: do not form a revenue share around a prototype. Agree to revisit once the game has players.

---

## Common mistakes

- Planning with raw hours instead of productive hours.
- Estimating the first unit of a content type like the hundredth.
- No hours for integration, testing or data safety.
- Owning the game on a personal account.
- Everyone having publish and revenue access "to be simple".
- A single person who must approve everything, without scheduled review time.
- Revenue shares without an exit rule.
- Contractors working in the live place.
- Cutting whole features when cutting layers would do.
- Not re-planning when a gate is missed.

## Checklist

- [ ] Productive hours per week written down, per person.
- [ ] Every feature estimated as a range; integration and testing added.
- [ ] Total compared with capacity; cuts decided and recorded.
- [ ] Team shape chosen; integrator and release owner named.
- [ ] Decision rights table agreed.
- [ ] Experience owned by a group; least-privilege roles; two-step verification on.
- [ ] At least two people able to publish and pull kill switches.
- [ ] Payment terms written down, with milestones and an exit rule.
- [ ] Contractor briefs with budgets, exclusions and a delivery format.
- [ ] Plan re-checked at every gate.

## See also

[[Planning and Scoping a Roblox Game]], [[Team Roles and Workflows]], [[Team Create and Collaboration]], [[Safe Changes in a Shared Place]], [[Asset Pipelines]], [[Documentation and Knowledge Bases]], [[Release Process and Rollbacks]], [[Live Incident Response and Post-Mortems]], [[Core Loops and Session Design]], [[Art Budgets - Triangles Draw Calls Memory]], [[Creator Store and Toolbox Safety]], [[Monetization Overview]]

## Connected notes
<!-- auto-links:start -->
[[Hiring Freelancers and Revenue Shares]] · [[Working with Contractors and Revenue Splits]] · [[Roadmaps Milestones and Scope Control]] · [[Team Collaboration Start Here]] · [[Groups Roles and Permissions for Studios]] · [[Running a Small Studio as a Business]]
<!-- auto-links:end -->
