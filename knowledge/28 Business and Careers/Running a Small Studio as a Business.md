---
tags: [business, studio, finance, budgeting, groups, operations, careers, minors]
---
# Running a Small Studio as a Business

> **Not advice.** General information on running a small Roblox team as a business. It is not tax, legal or financial advice. Whether you need to register a business, what structure fits, how income is taxed and what records the law requires all depend on your country (and often your state or province). Speak to a qualified accountant or lawyer before registering anything, signing long agreements or paying people outside Roblox. **Minors** cannot usually own or sign for a business alone; a parent or guardian must be involved in contracts, bank accounts and payouts.

A "studio" on Roblox can be one person with a group and two contractors, or twenty people with several live games. This note is for the small end: one to about ten people, one or two games, revenue that is starting to matter. It covers the business layer around the game: structure, money, budgets, risk and the habits that separate studios that last from teams that break up after one hit or one flop.

Related: [[Scoping and Roles for Small Teams]] (capacity, team shapes, decision rights), [[Team Roles and Workflows]], [[Hiring Freelancers and Revenue Shares]], [[DevEx and Cashing Out]].

---

## 1. Two layers: the Roblox group and the legal business

A studio exists in two places at once.

| Layer | What it is | What it controls |
|---|---|---|
| **Roblox group** | The account that owns experiences and assets | Who can edit, publish, upload, see analytics, manage revenue and payouts ([[Groups Roles and Permissions for Studios]]) |
| **Legal business** (optional at first) | A sole trader, partnership or company where you live | Contracts, bank accounts, tax, liability, paying people in money |

Most small teams start with only the group. That is fine while everyone is paid in Robux and handles their own DevEx. The legal layer starts to matter when:

- the studio pays people in money rather than Robux;
- revenue is large enough that how it is taxed matters (ask a professional what "large enough" means where you live);
- you sign agreements with brands, publishers or IP holders;
- partners want clear ownership of the studio itself, not just of revenue shares.

What a business structure changes (in general terms, varying by country): who owns the games and IP, who is liable if something goes wrong, how income is taxed, and how easy it is to bring in or buy out partners. This vault does not recommend a structure.

### Who owns the group

The group's owner account is the single point of failure. If it is lost, stolen or belongs to someone who leaves angry, the studio can lose everything.

- The owner account should belong to the person or entity that legally owns the studio, with strong unique password and two-step verification.
- Keep a written record of who owns the group and what happens if they become unavailable.
- Never share the owner account's login. Use roles for everyone else.

---

## 2. Revenue sources and their timing

Revenue on Roblox comes from several programs ([[Monetization Overview]]):

| Source | Notes |
|---|---|
| Passes, developer products, private servers | Plan on 70% of listed price as Earned Robux for in-experience sales (Roblox docs, as of October 2026) |
| Experience subscriptions | Different shares by pricing type ([[Subscriptions and Premium Payouts]]) |
| Engagement-based payouts | Held 60 days ([[Subscriptions and Premium Payouts]]) |
| Rewarded video ads | Eligibility rules apply ([[Ads and Rewarded Video]]) |
| UGC avatar items | Separate program and rules ([[UGC Avatar Items and Accessories]]) |
| Creator Store sales (models, plugins) | Paid in USD through a separate seller program; group-owned assets cannot be sold (Roblox docs, as of October 2026; see [[Legal Basics - IP Licenses and Assets]]) |
| Commissions and contract work | Studio staff's time sold to others ([[Commissions Pricing and Contracts]]) |
| Licensed IP and brand deals | Agreements with rights holders; revenue shares may go to them |

Two facts drive cash flow:

1. **Money arrives late.** Sale, Earned Robux, any holds, the monthly DevEx window, review, bank transfer. Plan four to eight weeks from sale to bank (rule of thumb; [[DevEx and Cashing Out]]).
2. **Revenue is volatile.** A game's earnings swing with updates, events, the algorithm and competitors ([[Discovery and the Algorithm]], [[Live Ops Events and Updates]]). One big month is not a salary.

---

## 3. Budgeting

### The monthly budget

Even a three-person team benefits from a one-page monthly budget. Keep it in Robux and in money, separately.

```
REVENUE (Earned Robux, last 3 months average)       120,000
  Recurring payouts to team (shares)                -36,000
  Contractor payouts (Robux)                        -15,000
  Ads and sponsored campaigns                        -25,000
  Asset purchases, plugins                            -4,000
  Left in group                                      40,000

MONEY (after DevEx)
  DevEx by owner (40,000 x 0.0038)                    152 USD
  Software and tools                                  -30
  Contractors paid in money                           -80
  Tax reserve (share set by your accountant)          -?
```

Notes:

- Use a three-month average, not the last month.
- The rate used here is the standard DevEx rate (Roblox docs, as of October 2026). Use the blended rate you actually see if you have legacy balances or 18+ rate income ([[DevEx and Cashing Out]]).
- Ad spend is an investment with a measurable return; budget it from your data ([[Sponsored Ads and Campaign Math]], [[Analytics and Funnels]]).

### Runway

Runway is how long the studio can keep paying its fixed costs if revenue stopped tomorrow.

```
runway (months) = reserves / monthly fixed costs
```

Rule of thumb: a studio paying people fixed amounts should hold at least three months of those costs in reserve before adding another fixed commitment. A studio paying only revenue shares has no fixed costs and therefore cannot "run out", but its members can quietly leave when shares shrink.

### Reinvest or pay out?

| Situation | Leaning |
|---|---|
| Game growing, ads profitable by your measurements | Reinvest a large share in ads and content |
| Game stable, team needs income | Pay out, keep a reserve |
| Game declining | Reserve for the next project; cut ad spend that no longer pays |
| New game in development, no revenue | Reserves and personal time only; avoid new fixed costs |

---

## 4. Portfolio thinking: more than one game

A studio with one game is one algorithm change away from no income. Successful small studios often:

- keep the main game in live ops with a predictable update rhythm ([[Live Ops Events and Updates]]);
- prototype small new games cheaply and kill most of them early ([[Planning and Scoping a Roblox Game]]);
- reuse systems across games through packages and shared modules ([[Packages and Asset Reuse]]), so each new game costs less.

Nuance: the second game often fails because it is built by the same people who are keeping the first alive. Name who works on what, and protect the time ([[Scoping and Roles for Small Teams]]).

### Decide kill criteria in advance

Before building a prototype, write what result keeps it alive. For example: "Day 1 retention above our previous game's at the same stage, after a two-week test with a small ad budget." When the test ends, follow the rule. Teams that decide afterwards almost always keep failing projects alive too long ([[Analytics and Funnels]], [[Retention and Return Hooks]]).

---

## 5. People and agreements

- **Founders' agreement.** When two or more people start a studio, write down: who owns what share of the studio (not just revenue), who decides what, what happens if one leaves, how the group and its games are controlled, and what happens to the IP if the studio ends. This is the most important document a small studio will write. A professional review is worth its cost once money is real.
- **Contractors** on written agreements with ownership clauses ([[Hiring Freelancers and Revenue Shares]]).
- **Revenue shares** with vesting, contribution and exit rules ([[Hiring Freelancers and Revenue Shares]]).
- **Credits and recognition.** A visible credits list in the game and on the studio's pages costs nothing and helps everyone's portfolio ([[Building a Portfolio as a Roblox Developer]]).

### Working with minors in the studio

Young developers are common. Studios that include them must:

- put child safety first: professional, task-focused communication in visible team channels, never private one-to-one chats with adults; no requests for personal information; follow Roblox's Community Standards ([[Roblox Policies Ratings and Compliance]]);
- involve a parent or guardian in any agreement, share or payment;
- respect school and sleep; no crunch.

---

## 6. Records and admin

Rule of thumb minimum records, kept monthly:

| Record | Contents |
|---|---|
| Revenue | Earned Robux by source and game (from Creator Hub reports) |
| Payouts | Who, Robux or money, amount, date, for what |
| DevEx | Date, Robux, rate, USD received, conversion, fees |
| Expenses | Tools, assets, ads, contractors, with receipts |
| Agreements | Signed versions, with dates and changes |
| Access | Who has which group role and why ([[Groups Roles and Permissions for Studios]]) |

A shared spreadsheet is enough at first. The point is that, at tax time or in a dispute, you can answer "who was paid what for what" in minutes ([[Documentation and Knowledge Bases]]).

### Tools

- A password manager for shared non-Roblox accounts (never for sharing the group owner's login).
- Version control for code ([[Git and Source Control for Roblox]], [[Code Pipeline - Rojo Git and CI]]).
- A task board and a knowledge base ([[Documentation and Knowledge Bases]]).
- A separate bank account for studio money once money flows (ask your bank and accountant what kind).

---

## 7. Risk register

A short list of what could hurt the studio, how likely, and what you do about it. Review it each quarter.

| Risk | Example | Mitigation |
|---|---|---|
| Account loss | Owner account phished | Two-step verification, no shared logins, phishing awareness |
| Moderation action | Game taken down for a policy breach | Know the rules ([[Roblox Policies Ratings and Compliance]]); review content and ads |
| Data loss | Save bug wipes progress | [[Data Loss Prevention and Recovery]], [[Saving Correctly - Autosave and BindToClose]] |
| Exploit economy | Duplication floods the economy | [[Economy Exploits - Dupes Races and Purchase Abuse]] |
| Key person leaves | Only scripter quits | Documentation, code review, shared knowledge |
| IP claim | Asset used without a licence | Licence records ([[Legal Basics - IP Licenses and Assets]]) |
| Platform change | New rules, payout rate, discovery change | Diversify games; keep reserves; follow official announcements |
| Team dispute | Revenue share argument | Written agreements with exit rules |
| Burnout | Constant crunch for updates | Sustainable cadence; [[Live Ops Events and Updates]] |

---

## 8. Platform rules are business rules

Roblox's Terms of Use, Community Standards, monetization policies and DevEx terms are the operating environment of the studio. Breaking them can freeze payouts, remove games or end accounts, which for a Roblox studio is the end of the business. Specific risk areas:

- paid random items and odds disclosure ([[Paid Random Items and Odds Disclosure in Practice]]);
- content maturity and questionnaires ([[Roblox Policies Ratings and Compliance]]);
- advertising and promotion rules ([[Ads and Rewarded Video]]);
- player data and privacy ([[Player Privacy and Data Deletion]]);
- AI-generated content ([[Roblox Policies on AI-Generated Content]]);
- dishonest growth tactics, which backfire ([[Launch Strategy - The First Two Weeks]]).

Assign one person to read Roblox's official announcements and Creator Hub updates each week and summarise what changed.

---

## 9. Worked example: from hobby team to studio

Three friends launch a game under a group. Month 1 earns 20,000 Robux; by month 6, 150,000 Robux a month.

| Stage | What they did right | What they had to fix |
|---|---|---|
| Launch | Game owned by a group; roles least privilege | Revenue shares agreed verbally |
| Month 3 | Started a budget spreadsheet | One member under 18 had no parent or guardian involved; they paused payouts to that member until the parent or guardian approved the agreement |
| Month 4 | Wrote a founders' agreement with vesting and exit | Owner account had no two-step verification; fixed |
| Month 6 | Hired two contractors on fixed price with ownership clauses | Had assets uploaded to a contractor's account; re-uploaded them to the group |
| Month 7 | Kept three months of contractor costs in reserve; spoke to an accountant | Started a second prototype with kill criteria |

None of these fixes was hard. All of them were cheaper before money was large.

---

## When not to do all this

- A one-person hobby game: group ownership, a simple record of earnings, and (if under 18) a parent or guardian's involvement are enough.
- A prototype with no revenue: no budget needed, but write down who owns what.

## Common mistakes

- Treating one good month as a salary.
- No reserve while paying fixed costs.
- Owner account without two-step verification, or shared.
- Verbal founders' agreements.
- No records until tax time.
- Paying minors without a parent or guardian's approval.
- Ignoring platform rule changes.
- All income from one game, no reserve for the next.
- Keeping failing prototypes alive without kill criteria.

## Checklist

- [ ] Games and assets owned by a group; owner account secured; ownership recorded.
- [ ] Monthly budget in Robux and money, from three-month averages.
- [ ] Reserve covering at least three months of fixed costs before adding more.
- [ ] Founders' agreement written; professional advice once revenue is real.
- [ ] Contractor and share agreements with ownership and exit rules.
- [ ] Records: revenue, payouts, DevEx, expenses, agreements, access.
- [ ] Risk register reviewed quarterly.
- [ ] Someone reads Roblox announcements weekly.
- [ ] Parent or guardian involved for every minor; child safety rules in team channels.

## See also

[[Business and Careers Start Here]], [[DevEx and Cashing Out]], [[Hiring Freelancers and Revenue Shares]], [[Commissions Pricing and Contracts]], [[Legal Basics - IP Licenses and Assets]], [[Scoping and Roles for Small Teams]], [[Team Roles and Workflows]], [[Groups Roles and Permissions for Studios]], [[Monetization Overview]], [[Live Incident Response and Post-Mortems]], [[Post-Mortem - Building a Melee Action Game]]

## Connected notes
<!-- auto-links:start -->
[[Working with Contractors and Revenue Splits]] · [[Team Collaboration Start Here]] · [[Working with Content Creators]] · [[Publishing Selling and Updating Plugins]] · [[Documentation and Onboarding New Developers]] · [[Team Create Permissions and Workflows]]
<!-- auto-links:end -->
