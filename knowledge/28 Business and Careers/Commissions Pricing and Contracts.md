---
tags: [business, commissions, freelancing, pricing, contracts, careers, minors]
---
# Commissions Pricing and Contracts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Starting work on a message like "make me a combat system" with no written scope.
> - Avoid: No "excludes" list.
> - Avoid: Quoting Robux without computing its real-money value after DevEx.
> - Rate computed from your own target and billable hours.
> - Scope with includes, excludes, testing bar and revisions.
> - Price, currency and milestone schedule written.
>
> Read more (17 KB note): ## 1. Pricing: three models and when each fails · ## 3. The contract: short, written, agreed · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **Not advice.** General information for developers who take paid work. It is not legal, tax or financial advice. Contract law, consumer law and tax rules differ by country. For anything large, or anything you are unsure about, ask a qualified professional where you live. Anyone under 18 needs a parent or guardian to agree to contracts and handle payment; in many places a contract with a minor can be cancelled by the minor, so clients should expect the parent or guardian to sign or approve.

This note is for the **seller**: a scripter, builder, modeller, UI artist, animator or VFX artist taking commissions. The other side of the same deal (finding and managing freelancers, revenue shares) is in [[Hiring Freelancers and Revenue Shares]]. Owning and running a team is in [[Running a Small Studio as a Business]].

The core idea: **most commission disputes are not about quality or money; they are about a scope nobody wrote down.** Pricing, contracts and payment terms all exist to pin the scope.

---

## 1. Pricing: three models and when each fails

| Model | How it works | Works well for | Fails when |
|---|---|---|---|
| **Fixed price per deliverable** | "Forest zone, 600 x 600 studs, 400 USD" | Clear, repeatable work: icons, maps, a set of animations, a known system | Scope is vague; the client adds "small things" |
| **Hourly or daily rate** | "40 USD an hour, invoice weekly, cap 20 hours" | Bug fixing, consulting, work in someone else's codebase | No cap; client cannot predict cost and stops trusting the invoice |
| **Retainer** | "20 hours a month for 600 USD, unused hours do not roll over" | Ongoing live ops support for a game with revenue | Either side stops needing it but nobody ends it |

Revenue shares are not pricing; they are partnership. They belong in [[Hiring Freelancers and Revenue Shares]], and a freelancer should treat them as speculative (most games do not earn much).

### Finding your number

Rule of thumb method, which works for any skill:

```
target yearly income (before tax) / realistic billable hours per year = minimum hourly rate

realistic billable hours: 40 to 60% of hours worked
  (the rest goes to finding clients, messages, revisions, admin, learning)
```

Example: a target of 20,000 a year in your currency, 25 working hours a week, 45 working weeks, 50% billable: 20,000 / (25 x 45 x 0.5) = about 36 per hour. Then convert fixed-price jobs from your hourly rate:

```
fixed price = estimated hours x hourly rate x risk factor
risk factor: 1.2 for work you have done many times, 1.5 for new kinds of work,
             2.0 for work in someone else's unfamiliar codebase
```

Nuance: freelancers who price by "what others charge" on a forum often price below what their own time is worth, because the cheapest visible prices come from people who are not counting unbilled hours. Price from your own numbers, then check the market.

### Robux or money?

| Paid in | Pros | Cons |
|---|---|---|
| **Robux** (group one-time payout) | Easy for Roblox clients; no bank fees; works for many minors | Needs 30,000 Earned Robux before you can DevEx; exchange rate set by Roblox; value per hour is low after the conversion ([[DevEx and Cashing Out]]) |
| **Money** (bank or a payment service) | Value is clear; no minimum | Needs a bank account and the client's trust; fees; for minors, a parent or guardian's account and approval |

When quoting in Robux, compute the real value first. At the standard DevEx rate of 0.0038 USD per Earned Robux (Roblox docs, as of October 2026), 10,000 Robux is 38 USD *if you are able to exchange it*. A quote of 10,000 Robux for 20 hours of work is under 2 USD an hour. Many new freelancers do not run this number.

Also confirm *how* the client pays Robux. Group one-time payouts send Earned Robux from a group's funds ([[Scoping and Roles for Small Teams]]). Robux handed over by other means may not be Earned Robux, and may not be exchangeable at all. Ask before you start.

### Price signals clients read

- A single number with no breakdown looks like a guess. A short breakdown ("system 12 h, UI wiring 4 h, testing 3 h") looks like a plan.
- Offer two or three options with different scope, not different quality: "basic leaderboard (one stat, top 50)", "full (three stats, weekly reset, your UI)".
- Discounts for "exposure" or "future revenue" rarely pay. If you accept one, write down what you get in return.

---

## 2. Scope: the part that protects you

Every quote should include a scope written in the client's terms and in testable terms.

```
Deliverable: Daily rewards system
Includes:
  - 7-day reward cycle, resets if a day is missed (configurable)
  - Server-side claim with validation and saving through the client's
    existing data module
  - UI wired to the client's existing menu frame (no new art)
  - Tested in Studio with 2 clients; short handover note
Excludes:
  - New UI art or icons
  - Changes to the client's data module
  - Any other feature
Revisions: 2 rounds of changes within the scope above
Out-of-scope work: quoted separately at <hourly rate>
```

What makes it work:

- **Excludes** is as important as includes. Most scope creep arrives through what you did not exclude.
- **"Tested in Studio with 2 clients"** sets the testing bar, so "it did not work in my live game with 40 players" becomes a new, paid discussion instead of a free rework. Good engineering still asks you to build it right ([[Server Authority and Validation]], [[Saving Correctly - Autosave and BindToClose]]); the scope just defines what was promised.
- **Revisions** are counted and bounded.

### Scope edge cases that cause disputes

| Situation | What to agree in advance |
|---|---|
| Client's existing code is broken | Fixing it is out of scope unless quoted; tell them what you found |
| Client changes the design mid-job | Pause, re-quote the difference, continue only after agreement |
| Work depends on assets the client has not delivered | Your deadline moves by the delay |
| The client wants the source files (Blender files, project files) | Say whether the price includes them; many artists charge more |
| Third-party code or assets in the deliverable | List them with their licences ([[Legal Basics - IP Licenses and Assets]]) |

---

## 3. The contract: short, written, agreed

For most Roblox commissions, the "contract" is a short written agreement both sides accept in writing (a shared document or a message both confirm). It is far better than nothing. For large jobs, real money, or ongoing work, a proper contract reviewed by a professional is worth its cost.

A minimal agreement covers:

1. **Parties.** Who is paying (a person or a group, with a contact), who is working. If either is under 18, the parent or guardian who approves.
2. **Scope.** As in section 2.
3. **Price, currency and schedule.** Amount, Robux or which currency, milestones.
4. **Deadlines.** Including what happens to the deadline if the client is late with input.
5. **Revisions.** Number and what counts as one.
6. **Ownership and licence.** Who owns the result after payment (section 5).
7. **Portfolio rights.** Whether you may show the work, and when (section 6).
8. **Cancellation.** What happens if either side stops.
9. **Confidentiality.** Whether you may talk about the project.
10. **Delivery format.** File types, where delivered, how handed over.

### Payment schedule

| Job size | Common schedule (rule of thumb) |
|---|---|
| Small (a few hours) | 100% upfront from new clients; on delivery from trusted repeat clients |
| Medium | 50% upfront, 50% on delivery |
| Large | Milestones: for example 30% to start, 40% at first playable or draft, 30% on final |

Upfront payment is not greed: it filters out clients who were never going to pay. Never deliver final files before the final payment for a new client; deliver previews (a video, screenshots, a test place you control) instead.

### Cancellation

Write down both directions:

- **Client cancels:** you keep payments for completed milestones and get paid for work done since, at your hourly rate, up to the next milestone's amount.
- **You cancel:** you refund payments for work not delivered, and hand over what is done.

### Disputes

Most disputes can be settled by pointing at the written scope. If the scope is silent, split the difference or walk away early. Public call-outs on social media rarely recover money and often cost reputation for both sides. Keep messages, files and payment records; if the amount is large, a professional can tell you what remedies exist locally.

---

## 4. Delivery and handover on Roblox

How you deliver affects how safely the client can use the work and how well you are protected.

| Method | Good for | Watch out for |
|---|---|---|
| **.rbxm file** (model or scripts) | Most builds, systems, UI | Uploaded assets inside (meshes, images, animations) belong to whoever uploaded them; see below |
| **Package** shared to the client's group | Reusable kits, ongoing updates | Permission settings; [[Packages and Asset Reuse]] |
| **Working in the client's place via Team Create** | Integration work in their codebase | Ask for a copy of the place, not the live one ([[Team Create and Collaboration]], [[Safe Changes in a Shared Place]]) |
| **Git repository** (Rojo projects) | Code-heavy work | Agree who owns the repository; [[Git and Source Control for Roblox]] |

### The asset ownership trap

On Roblox, uploaded assets (meshes, images, audio, animations) belong to the account or group that uploaded them, and permission settings decide who can use them. An animation you uploaded to your own account may not play in the client's group game ([[Animation Asset Permissions and Groups]]). A Restricted asset loads only where its owner has granted permission (Roblox docs, Creator Store, as of October 2026).

Clean handover options:

1. **Deliver source files** (FBX, GLB, PNG, animation files) and let the client upload them to their group. Simplest ownership story.
2. **Upload to the client's group** if they give you an upload role in it. Remove the role afterwards.
3. **Upload to your account and grant permission** to the client's game or group. Only if both sides understand you could later revoke it, which is a reason clients dislike this option.

Pick one in the contract.

### Before you hand over code

- Remove debug prints, test cheats and any admin backdoor. A backdoor in delivered code is a serious breach of trust and can break Roblox rules ([[Exploits and Anti-Cheat]]).
- Include a short handover note: what the system does, where the files go, config values, how to test, known limits.
- Do not include code you copied without a licence that allows it.

---

## 5. Ownership and licence wording

There are two common shapes:

- **Assignment (work for hire style):** after full payment, the client owns the deliverable. You keep the right to show it in your portfolio (if agreed) and to reuse your general skills and your pre-existing tools.
- **Licence:** you keep ownership, the client gets a right to use it (for example "in their Roblox experiences, forever, not for resale"). Common for asset packs, plugins and reusable systems sold to several clients.

Sample wording for an assignment:

```
After full payment, the client owns the delivered work. The developer keeps
ownership of their pre-existing code and tools used in it, and grants the
client a permanent licence to use those parts as part of the delivered work.
The developer may show the work in their portfolio after the client's game
update containing it is public.
```

The "pre-existing code" line matters. If you built a reusable module before this job, an unqualified "client owns everything" clause can be read as giving that module away. Whether such wording is enforceable, and how "work for hire" is treated, depends on local law ([[Legal Basics - IP Licenses and Assets]]).

---

## 6. Portfolio rights and NDAs

- Many clients do not want work shown before release. Agree "after release" by default.
- Some clients want silence forever (a non-disclosure agreement). Price that in: work you cannot show does not help you win the next job ([[Building a Portfolio as a Roblox Developer]]).
- Showing a short video of your system in your own test place, with no client branding, is often acceptable when showing the client's game is not. Ask.

---

## 7. Safety for young and new freelancers

Roblox's community includes many young developers, and scams target them.

- **Keep conversations where safety tools exist.** Moving to private apps to "talk business" is how many scams and grooming attempts start. If a client insists on private channels, video calls or personal information, stop. Roblox's Community Standards apply to how people treat each other on and around the platform; report problems ([[Roblox Policies Ratings and Compliance]]).
- **Do not share personal data** (home address, school, ID documents) with clients. A real client does not need them; payments go through Roblox or a payment service.
- **Under 18: involve a parent or guardian** before accepting paid work, especially for money outside Roblox. They approve the agreement and handle accounts.
- **Common scams:** "do a free test task" that is the real job; "I will pay after it is in the game"; overpayment followed by a refund request; payment in items or limited accessories with no real value; fake group payout screenshots. Check that payouts actually arrived in your Robux history or bank before releasing files.

---

## 8. Worked example: quoting a mid-size job

A client asks: "Can you make a pet system for my simulator?"

Questions to ask first: how many pets, how they are obtained (eggs, shop), equip limit, following behaviour, boosts, trading (yes or no), saving (existing data module?), UI (is art provided?).

Answers: 20 pets, eggs bought with in-game currency, equip 3, follow and float, boosts to currency gain, no trading, their existing data module, art provided.

Estimate in ranges (rule of thumb hours for an experienced scripter):

| Part | Low | High |
|---|---|---|
| Server: egg rolls, inventory, equip, boosts, validation | 8 | 12 |
| Saving through their module | 2 | 4 |
| Following and floating (client-side) | 3 | 6 |
| UI wiring: inventory grid, equip buttons, hatch animation | 6 | 10 |
| Testing, handover note | 3 | 4 |
| **Total** | **22** | **36** |

Quote: midpoint 29 hours x hourly rate x 1.2 risk factor, as a fixed price, in three milestones, scope with excludes ("no trading, no new art, no changes to the data module"), two revision rounds, delivery as .rbxm plus a handover note, portfolio rights after release. For the system itself, see [[Pet Hatching and Following End to End]] and [[RNG Drops and Luck Systems]]; for the odds disclosure rules that paid eggs must follow, see [[Paid Random Items and Odds Disclosure in Practice]] (and tell the client if their eggs are paid).

---

## Common mistakes

- Starting work on a message like "make me a combat system" with no written scope.
- No "excludes" list.
- Quoting Robux without computing its real-money value after DevEx.
- Delivering final files before final payment to a new client.
- Uploading assets to your own account without agreeing ownership.
- Unbounded revisions.
- Signing away your pre-existing modules by accident.
- Accepting NDAs without pricing in the lost portfolio value.
- Moving client chats to private channels; sharing personal data.
- Taking paid work as a minor without a parent or guardian.

## Checklist

- [ ] Rate computed from your own target and billable hours.
- [ ] Scope with includes, excludes, testing bar and revisions.
- [ ] Price, currency and milestone schedule written.
- [ ] Deadlines tied to client inputs.
- [ ] Ownership, licence and pre-existing code wording agreed.
- [ ] Portfolio rights and confidentiality agreed.
- [ ] Delivery method and asset upload ownership agreed.
- [ ] Cancellation terms both ways.
- [ ] Parent or guardian involved if you are under 18.
- [ ] Payment confirmed in your history before handing over final files.

## See also

[[Business and Careers Start Here]], [[Hiring Freelancers and Revenue Shares]], [[DevEx and Cashing Out]], [[Legal Basics - IP Licenses and Assets]], [[Building a Portfolio as a Roblox Developer]], [[Running a Small Studio as a Business]], [[Scoping and Roles for Small Teams]], [[Animation Asset Permissions and Groups]], [[Packages and Asset Reuse]], [[Team Create and Collaboration]]

## Connected notes
<!-- auto-links:start -->
[[Working with Contractors and Revenue Splits]] · [[Working with Content Creators]] · [[Team Collaboration Start Here]] · [[Publishing Selling and Updating Plugins]] · [[Groups Roles and Permissions for Studios]] · [[Subscriptions and Premium Payouts]]
<!-- auto-links:end -->
