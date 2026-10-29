---
tags: [team, production, roadmap, milestones, scope, estimation, planning, live-ops, type/guide, area/production, level/intermediate, area/monetization]
---
# Roadmaps Milestones and Scope Control

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Roadmap as a giant task list -> Four layers; outcomes in Next and Later
> - Avoid: Milestones defined by date -> Exit criteria anyone can check
> - Avoid: Single-number estimates -> Three-point estimates and a personal multiplier
> - One-page vision exists and new teammates read it first.
> - Roadmap in Now, Next, Later; only Now has dates.
> - Each milestone has exit criteria someone else can check.
>
> Cost: TL;DR ~140 tok · whole note ~4.6k tok. Read more: ## 2. Milestones with exit criteria · ## 3. Estimating in ranges · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Planning and Scoping a Roblox Game]] covers what a plan has to answer, counting content, phases with gates, scope reversals and budgets, with the reference project's real reversals. [[Scoping and Roles for Small Teams]] covers capacity, team shapes, decision rights and cutting by layer. This note is the machinery that keeps a plan honest over months: the layers of a roadmap and who reads each, milestones with exit criteria you can measure, estimation methods that produce ranges instead of wishes, the arithmetic of buffers, the mechanisms that actually stop scope creep (a change budget, a kill list, freeze dates), the Roblox-specific steps that need to appear on a roadmap, and how the roadmap changes once the game is live.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Four layers, four readers

One document cannot serve the owner deciding direction, the team planning next week, and the community asking "when is the update". Keep four layers and let each change at its own speed (rule of thumb).

| Layer | Horizon | Reader | Changes | Format |
|---|---|---|---|---|
| **Vision** | The game's life | Everyone, new hires first | Rarely; a change here is a new game | One page: player fantasy, core loop, target player and device, what the game is not |
| **Roadmap** | 3 to 9 months | Team, investors, contractors | Monthly review | Now, Next, Later columns of outcomes, not tasks |
| **Milestone plan** | The current milestone (4 to 8 weeks) | Team | Weekly | Deliverables with exit criteria and owners |
| **Week plan** | One week | Each person | Daily | Tasks, in whatever tracker the team uses |

The common failure is collapsing the roadmap into the week plan: a 200-row task list with dates nine months out. Nobody can read it, nobody trusts the far rows, and changing direction means editing 150 rows. Keep far-future items as outcomes ("Players have a reason to come back daily") and turn them into tasks only when they enter the current milestone.

### Now, Next, Later

The roadmap format that survives contact with reality on small teams is three columns without dates beyond the current one:

- **Now:** the current milestone. Dated, committed.
- **Next:** the milestone after. Ordered, roughly sized, not dated.
- **Later:** ideas worth keeping, in rough priority. Not promised.

Dates belong only to Now because estimates further out are wrong by large factors (section 3). When investors or a publisher need a date, give a range with a confidence level and say what it depends on.

---

## 2. Milestones with exit criteria

A milestone is a state of the game, not a date on a calendar. Its exit criteria must be checkable by someone other than the person who built it. The ladder below fits most Roblox games; the criteria are rule of thumb and should be tuned to your genre.

| Milestone | The question it answers | Exit criteria (examples) |
|---|---|---|
| **Prototype** | Is the core loop fun for five minutes? | Five people outside the team play it for 10 minutes; at least three want to keep playing when asked to stop |
| **Vertical slice** | What does one finished piece cost? | One zone or mode at final quality: art, UI, sound, saving, mobile; timed so you can multiply ([[Planning and Scoping a Roblox Game]]) |
| **Alpha** | Is all launch content in? | Every launch feature playable end to end; known bugs listed; no placeholder art in the first 10 minutes |
| **Closed beta** | Does it survive real players? | Playtested by a tester group on a test experience for at least a week; no data loss in that week; phone frame rate within budget ([[Mobile and Low-End Optimization]]) |
| **Soft launch** | Do strangers stay? | Public, little promotion; early retention and session length measured in analytics ([[Analytics and Funnels]]) and compared against your own targets |
| **Launch** | Can we grow it? | Promotion ([[Sponsored Ads and Campaign Math]]), an update queued for week two, incident rota in place |
| **Live** | Can we keep it growing? | Regular update cadence; roadmap reviewed monthly against data |

Three nuances:

- **"Fun" needs an observable proxy.** "We think it's fun" is not an exit criterion. "Three of five strangers kept playing" is crude, but it can fail, which is the point.
- **The vertical slice is also an estimate.** Its true cost multiplied by the content count is the most reliable schedule you will ever have. If the slice took three weeks and the plan has eight zones, the plan says 24 weeks of zone work, whatever the spreadsheet said before.
- **Do not skip closed beta to hit a date.** Data loss and economy exploits found by the public cost far more than a week (see [[Data Schema Design and Migrations]] and [[Economy Exploits - Dupes Races and Purchase Abuse]]).

### Retention targets

Teams like to quote "good" day-1 and day-7 retention numbers. Benchmarks published by third parties vary widely by genre and change with the platform; we could not confirm current official Roblox benchmarks for this note. Set targets from your own soft launch and improve week over week, rather than from a number seen in a video ([[Retention and Return Hooks]]).

---

## 3. Estimating in ranges

Single-number estimates are wrong in a predictable direction: too low. Three habits fix most of it.

### Three-point estimates

For each deliverable, ask for three numbers: optimistic (O), most likely (M) and pessimistic (P), in working days. A common weighted mean is:

```
expected = (O + 4M + P) / 6
spread   = (P - O) / 6
```

This is the classic three-point (PERT) formula; it is a rule of thumb, not a law. Its value is mostly that it forces someone to say the pessimistic number out loud.

Worked example for a milestone of a simulator update (numbers invented for illustration):

| Deliverable | O | M | P | Expected | Spread |
|---|---|---|---|---|---|
| New zone (map, props, lighting) | 6 | 9 | 18 | 10.0 | 2.0 |
| 12 new pets (models, icons, stats) | 4 | 6 | 10 | 6.3 | 1.0 |
| Rebirth system v2 | 3 | 5 | 12 | 5.8 | 1.5 |
| Trading UI fixes | 1 | 2 | 5 | 2.3 | 0.7 |
| Testing and fixes | 3 | 4 | 8 | 4.5 | 0.8 |
| **Total** | | | | **29.0** | |

Spreads combine as the square root of the sum of squares: sqrt(2.0² + 1.0² + 1.5² + 0.7² + 0.8²) ≈ 2.9 days. So roughly 29 days of work, with a plausible range of about 26 to 32 days if the deliverables are independent. They are rarely independent (one sick week hits everything), so treat the upper end as the planning number.

### Reference classes beat intuition

Better than any formula: how long did the **last similar thing** take? Keep a simple log of estimate versus actual for every deliverable. After ten entries, you have your team's personal multiplier. Most teams discover it is between 1.5 and 2.5 (rule of thumb). Multiply new estimates by it until it shrinks.

**Measured in the reference project:** the plan had a clean phase structure, but the map direction changed at least six times in four weeks, and a full staging map built in about a day and a half was deleted ([[Planning and Scoping a Roblox Game]]). No estimate method protects against direction changes; only gates and reusable-first ordering do. Estimates are for the work you have decided to do.

### Capacity, not calendar

Convert people to available days honestly ([[Scoping and Roles for Small Teams]] covers capacity in depth):

```
available days = people x working days x focus factor
focus factor   ≈ 0.6 to 0.7 for small teams (meetings, review, support, bugs)
```

A team of three over four weeks of five-day weeks has 3 x 20 x 0.65 ≈ 39 focus days. The 29-day milestone above fits with a 10-day buffer, about 25%. That buffer is not slack; it is where the bugs, the owner's feedback rounds and the Roblox platform surprises go.

---

## 4. Buffers: where to put them

Padding every task makes every task expand to fill its padding. Put buffer in one visible place instead (rule of thumb):

- **Milestone buffer:** 20 to 30% of capacity left unassigned at the end of the milestone. Visible to everyone.
- **Integration buffer:** a fixed block before each milestone exit for joining work from different people. Integration is where Roblox projects find that the UI expects a remote the server renamed.
- **Platform buffer:** time for things you do not control (section 6).

Track buffer consumption weekly. If half the buffer is gone at the milestone's midpoint, cut scope now, not in the last week.

---

## 5. Scope control mechanisms that work

Scope creep rarely arrives as one big idea. It arrives as twenty "small" additions, each reasonable, together fatal. [[Scoping and Roles for Small Teams]] describes its signature; these are mechanisms to stop it.

### A change budget

Each milestone gets a change budget: a number of focus days (for example 10% of capacity) reserved for changes that arrive after the milestone started. Any new request is sized and charged against it. When the budget is empty, a new request must **replace** something of equal size. "Swap, don't add" becomes a rule with a number behind it.

### The scope ledger

Keep a small table, in the same place as the milestone plan:

| Date | Request | Asked by | Size (days) | Decision | Paid for by |
|---|---|---|---|---|---|
| Week 2 | Add sound to every button | Owner | 1 | Accepted | Change budget (9 left) |
| Week 2 | Second boss for new zone | Designer | 6 | Deferred to Next | n/a |
| Week 3 | Pet trading animations | Owner | 3 | Accepted | Removed "pet rename" (3) |

The ledger makes trade-offs visible to the person who asked. Owners who see that their request removed something else start making the trade-off themselves.

### A kill list

At the start of each milestone, write down what you will cut first if you fall behind, in order. Decided calmly at the start, it is a plan; decided in the last week, it is panic. Cut candidates are usually: polish on rarely seen screens, a second variant of anything, cosmetic animation, features that serve under 10% of players (rule of thumb).

### Freeze dates

- **Feature freeze:** after this date, only bug fixes and content inside existing systems. For a four-week milestone, about one week before the end.
- **Content freeze:** after this date, no new assets; only fixes. A few days before release, so asset moderation and testing have time.
- **Code freeze before a live event:** only fixes that a lead approves ([[Release Process and Rollbacks]]).

Freezes only work if the owner agrees to them in advance. Put them in the milestone plan and have the owner sign off on that page.

### Sunk cost checks

At each milestone review, ask of every in-progress item: "If we had not started this, would we start it now?" Items that fail go on the kill list, however much has been spent. The reference project's deleted staging map was a costly lesson, but continuing to build on a direction the owner had rejected would have cost more.

---

## 6. Roblox-specific roadmap items

Some steps take time you cannot compress and are easy to forget until launch week. Put them on the roadmap as explicit items with owners (the durations are rule of thumb; check current requirements on the Creator Hub):

| Item | Why it needs roadmap time | See |
|---|---|---|
| Maturity and compliance questionnaire, content descriptors | Required before public release; answers must match the content | [[Roblox Policies Ratings and Compliance]] |
| Age and safety features you depend on | Some social features are gated by age checks or settings | [[Age Checks and Safety Features]] |
| Asset uploads and moderation | Large batches of meshes, images and audio take time to upload and review; a rejected asset blocks a feature | [[Asset Upload Automation with Open Cloud]] |
| Game passes, developer products, prices | Created and tested in a test experience first; receipts verified | [[Developer Products and ProcessReceipt]] |
| Paid random items and odds disclosure | Policy and PolicyService gating must be built, not bolted on | [[Paid Random Items and Odds Disclosure in Practice]] |
| Localization | Translation and review of strings | [[Localization Pipeline]] |
| Thumbnails, icon, store page | Usually forgotten until the day before | [[Thumbnails Icons and Store Page]] |
| Analytics events | Must exist before soft launch, or soft launch teaches nothing | [[Analytics and Funnels]] |
| Phone and low-end testing | The majority device class on Roblox needs its own test pass | [[Multi-Client and Device Playtesting Protocols]] |
| Promotion budget and campaigns | Lead time to create and review campaigns | [[Sponsored Ads and Campaign Math]] |

A useful habit: a "platform readiness" milestone that runs in parallel with alpha, owned by one person, containing only these items.

---

## 7. A small burn-up forecast

A burn-up chart (total scope and completed work over time) shows scope creep as a rising top line, which a burn-down chart hides. You do not need a tool. This short Python script reads a weekly log and forecasts the finish week as a range, using the slowest and fastest recent weekly rates.

```python
# burnup.py: weekly log -> finish forecast range.
# log.csv columns: week,done_days,scope_days   (cumulative values)
import csv, math, sys

rows = [(int(r["week"]), float(r["done_days"]), float(r["scope_days"]))
        for r in csv.DictReader(open(sys.argv[1], encoding="utf-8"))]
rates = [b[1] - a[1] for a, b in zip(rows, rows[1:])][-4:]  # last four weekly deltas
if not rates or max(rates) <= 0:
    sys.exit("not enough progress data")

week, done, scope = rows[-1]
remaining = scope - done
growth = (rows[-1][2] - rows[0][2]) / max(1, rows[-1][0] - rows[0][0])  # scope added per week

def finish(rate: float) -> str:
    net = rate - growth
    return "never at this rate" if net <= 0 else f"week {week + math.ceil(remaining / net)}"

print(f"remaining {remaining:.1f} days, scope growing {growth:.1f} days/week")
print(f"fast case: {finish(max(rates))}   slow case: {finish(min(rates))}")
```

Two lessons the script makes concrete: if scope grows as fast as work gets done, the finish date is "never", however hard people work; and a range from real weekly rates is more honest than any date someone picked.

---

## 8. Roadmaps for a live game

Once the game is live, the roadmap changes character. It becomes a sequence of update slots fed by data ([[Update Cadence and Hype Cycles]], [[Event Calendars and Content Planning]]).

- **Fix the cadence first, then fill it.** A weekly or fortnightly slot that always ships something small beats an irregular big update (rule of thumb; the vault's live ops notes go further).
- **Split capacity explicitly.** A common rule of thumb is roughly 60 to 70% new content and features, 20 to 30% fixes and technical debt, and about 10% experiments ([[A-B Testing and Experiments on Roblox]]). Without an explicit split, debt never gets time until it causes an incident.
- **Data reorders Next.** Monthly, look at funnels and retention and reorder the Next column. Keep the vision fixed; change the order of outcomes.
- **Incidents eat roadmap.** Reserve capacity for them. A week with a live incident is a week with less content ([[Live Incident Response and Post-Mortems]]).

**Measured in the reference project:** for about a month the team ran with no task tracker or fixed release schedule, driven by a daily changelog and the owner's requests ([[Release Process and Rollbacks]]). It produced a lot of change very fast, and also the six direction reversals above. A light roadmap with gates would have kept the speed and reduced the rework.

### Talking to players about the roadmap

Public roadmaps create promises. Share themes and "coming soon" items that are already in the current milestone; never share dates for Next or Later. When something slips, say so early and plainly ([[Patch Notes and Player Communication]]).

---

## 9. When not to do all this

- **Game jams and prototypes:** a vision paragraph and a list. Estimation and ledgers are overhead.
- **A solo developer:** keep the vision, the Now column and a kill list. Skip the ledger; you are the only requester.
- **Pure live tuning work** (price changes, event config): runs on the live ops calendar, not the roadmap.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Roadmap as a giant task list | Nobody reads it; far rows always wrong | Four layers; outcomes in Next and Later |
| Milestones defined by date | "Alpha" ships with half the features | Exit criteria anyone can check |
| Single-number estimates | Every milestone late | Three-point estimates and a personal multiplier |
| Buffer hidden in every task | Tasks expand; buffer invisible | One visible milestone buffer |
| Accepting requests without trade-offs | Scope line rises every week | Change budget and scope ledger |
| Platform steps forgotten | Launch blocked by questionnaire or moderation | Platform readiness milestone |
| Public dates for Later items | Broken promises | Share only Now |

## Checklist

- [ ] One-page vision exists and new teammates read it first.
- [ ] Roadmap in Now, Next, Later; only Now has dates.
- [ ] Each milestone has exit criteria someone else can check.
- [ ] Estimates are three-point; estimate versus actual logged.
- [ ] Capacity uses a focus factor; 20 to 30% buffer visible.
- [ ] Change budget, scope ledger and kill list for the current milestone.
- [ ] Feature and content freeze dates agreed with the owner in advance.
- [ ] Platform readiness items on the roadmap with an owner.
- [ ] Live game: fixed cadence and an explicit content, debt and experiment split.

## Connected notes
<!-- auto-links:start -->
[[Team Collaboration Start Here]] · [[Working with Contractors and Revenue Splits]] · [[Marketing and Growth Start Here]] · Resource Library Start Here · Retention Cohorts · Launch Strategy - The First Two Weeks
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Documentation and Onboarding New Developers]] · [[Running a Small Studio as a Business]] · [[Retention Cohorts]] · [[Feature Flags and Staged Rollouts]] · [[Team Create Permissions and Workflows]]
<!-- related:end -->
