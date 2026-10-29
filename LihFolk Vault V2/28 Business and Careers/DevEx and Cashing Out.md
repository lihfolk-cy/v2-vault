---
tags: [business, devex, payouts, robux, earnings, taxes, careers, minors, type/guide, area/business, level/intermediate, area/monetization]
---
# DevEx and Cashing Out

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Counting purchased Robux as income. Robux you bought is not exchangeable.
> - Avoid: Assuming one rate. Standard is 0.0038 USD per Earned Robux; 0.0054 applies only to spend by age-checked US 18+ buyers in R15...
> - Avoid: Misreading Creator Rewards. Daily Engagement: 5 Robux/day per Active Spender; Audience Expansion: 35% of new users' first $100.
> - Read the current DevEx Terms of Use and the DevEx page on the Creator Hub.
> - Verified email; legal name matches what you will use on the form.
> - Tax form type known (W-9 or W-8); a tax professional consulted where needed.
>
> Cost: TL;DR ~190 tok · whole note ~4.5k tok. Read more: ## 2. The numbers (Roblox docs, as of October 2026) · ## 4. Eligibility and the request flow · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

> **Not advice.** This note is general information about how the Developer Exchange works and how developers usually plan around it. It is not tax, legal or financial advice. Tax and contract rules differ by country (and often by state or province). The only binding rules are Roblox's own **Developer Exchange Terms of Use** and the DevEx page on the Creator Hub (Creator Hub, Docs, Monetization, Developer Exchange). Read them on the day you cash out; rates and requirements change.

[[Monetization Overview]] explains where Robux comes from. [[Subscriptions and Premium Payouts]] covers subscription and engagement income. This note covers the last step: turning Earned Robux into money in a bank account, what the numbers really are, what slows or blocks a payout, and how to plan a team's money around the program's rules.

---

## 1. The model in one paragraph

Players buy Robux with real money. When they spend it in your experience, Roblox keeps a share and credits the rest to the owner (you or your group) as **Earned Robux**. Earned Robux can be spent on Roblox like any Robux, paid out to group members, or exchanged for real currency through **DevEx**, at a fixed rate per Earned Robux that Roblox sets. Robux you bought yourself is not Earned Robux and cannot be exchanged. Roblox decides, at its own discretion, what counts as Earned Robux (Roblox docs, as of October 2026).

---

## 2. The numbers (Roblox docs, as of October 2026)

| Item | Value |
|---|---|
| Standard rate | **0.0038 USD per Earned Robux** (30,000 Earned Robux = 114 USD) |
| U.S. 18+ rate | **0.0054 USD per Earned Robux**, for qualifying Earned Robux only (section 3) |
| Legacy rate | 0.0035 USD per Earned Robux for balances earned before September 5, 2025, 10 am PT |
| Minimum to request | 30,000 Earned Robux |
| Minimum age | 13 |
| Request frequency | One request per calendar month; a submitted request cannot be cancelled |
| Processing estimate | About 10 business days for a first-time participant after portal registration; about 5 for returning participants; bank transfer time is extra |
| Portal registration deadline | One week after the invitation email, or the request is declined and the Robux refunded |

Two points the table hides:

1. **Legacy balances go first.** If you held Earned Robux before the September 2025 rate change, that older balance is exchanged at 0.0035 before any balance at the current rate, and spending Robux does not reduce the legacy amount (Roblox docs). A long-running group with an old balance will see a lower effective rate than the headline number until the legacy portion is used up. Do not promise a team member "0.0038" if your group has a legacy balance.
2. **The dashboard is an estimate.** The Creator Hub balance can lag by up to 24 hours and does not guarantee a payout (Roblox docs). Plan with a margin.

### From a sale to dollars

For in-experience passes and developer products, plan on 70% of the listed price reaching you as Earned Robux (Roblox docs, quoted in [[Monetization Overview]]). Regional pricing can lower what a player pays, so always read real amounts from receipts and reports, never from your config ([[Pricing and Store Design]]).

Worked example at the standard rate:

```
Developer product listed at 100 Robux
  creator share (70%)            = 70 Earned Robux
  exchange at 0.0038             = 0.266 USD per sale
  sales needed for 30,000 Earned = 30,000 / 70 = about 429 sales
  value of 30,000 Earned         = 114 USD
```

The same sale counted at the U.S. 18+ rate is worth 70 x 0.0054 = 0.378 USD, about 42% more. A rough conversion for planning: **1 USD of payout needs about 263 Earned Robux at the standard rate**, or about 185 at the 18+ rate.

What the example teaches: a hobby game with a few dozen sales a month will not reach the minimum for a long time. That is normal. Budget your time and your team's expectations on that basis, not on headlines about top earners.

---

## 3. The U.S. 18+ rate in detail

Roblox docs (as of October 2026) describe a higher rate of 0.0054 for certain Earned Robux, starting June 8, 2026. All of these must hold:

- **Purchase type:** developer products, passes, subscriptions and private servers.
- **Buyer:** a U.S. player who verified they are at least 18 through facial age estimation or government ID.
- **Game:** an eligible game. Eligibility is about player characters: for 100% of active playtime players must be platform avatars on an R15 rig, a custom human-form character meeting stated articulation criteria (roughly a head, two arms, two legs, a multi-part torso, with 15 or more parts or joints), or a custom nonhuman-form character. Mixing R6 with R15 or custom characters disqualifies the game; if you use platform avatars, set Avatar Settings to R15 only. Animation packs must be R15. NPCs are not evaluated.
- **Compliance:** Roblox runs background compliance checks and can remove eligibility until an issue is fixed.

For group-owned games, one-time payouts and recurring revenue splits respect the split between the two rates, and the cash-out screen shows how much came from each (Roblox docs).

### Nuance: should you chase the 18+ rate?

- **It is a bonus on part of your revenue, not a new revenue line.** If 10% of your Earned Robux comes from verified U.S. adults, the blended rate rises by only about 4% (0.1 x 42%). Measure the share before you redesign anything.
- **An R6 game should not convert just for this.** Converting a combat game from R6 to R15 changes hitboxes, animations, armour and feel ([[Characters and Humanoids]], [[Rigs and Joints]]). That is weeks of work and risk. Do it only if you wanted R15 anyway.
- **Never design content to pressure adults to verify.** Verification is a safety feature ([[Age Checks and Safety Features]]); using it as a sales lever is the kind of design that erodes trust ([[Ethical Design and Player Trust]]).
- **Contracts must say which rate.** If a team member's share is computed in USD, write down whether it uses the blended amount actually received. Section 7 has wording.

---

## 4. Eligibility and the request flow

Roblox docs (as of October 2026) list, among others:

- at least 13 years old;
- at least 30,000 Earned Robux;
- a Roblox-verified email address;
- a valid DevEx Portal account (the portal is run by Tipalti, a payments provider);
- an IRS **W-9** (U.S. taxpayers) or **W-8** (non-U.S. taxpayers) form on file;
- continued compliance with the Terms of Use and Community Standards;
- agreement to the DevEx Terms of Use.

The full list is in the DevEx Terms of Use; the docs page says so itself. Read it rather than relying on a summary, including this one.

### The flow

1. Creator Hub, **Finances**, **Cash Out**.
2. Fill in the DevEx form with your **legal name only**.
3. Submit. The Robux is held while the request is reviewed and refunded immediately if rejected.
4. After a first approval, an email invites you to register on the DevEx Portal. Add a payment method and tax form within one week.
5. Wait for processing, then the bank transfer.

### Why requests get rejected (Roblox docs FAQ, paraphrased)

| Cause | How to avoid it |
|---|---|
| Portal registration not finished | Register the day the email arrives; the one-week clock is strict |
| Missing tax or payment details | Prepare the form before you submit (section 6) |
| Not enough Earned Robux | Keep a buffer over 30,000; the dashboard lags |
| Policy violations (for example scamming or account theft) | Keep the account and its games clean; see [[Roblox Policies Ratings and Compliance]] |
| Name mismatch | Do not resubmit; contact Roblox Support first, ID verification may be needed |

Old moderation actions do not automatically disqualify you, but ongoing compliance matters. Roblox cannot confirm eligibility in advance; each request is reviewed when submitted (Roblox docs).

### Groups

Group funds count as Earned Robux only if they come from legitimate earnings (Roblox docs). DevEx is requested by a **person**, so group revenue reaches a person through group payouts first ([[Scoping and Roles for Small Teams]] covers one-time and recurring payouts). This has consequences:

- Every member who wants to cash out needs their own 30,000 Earned Robux and their own tax form. A member paid 5,000 Robux a month waits six months to reach the minimum.
- A small team splitting income can end up with nobody able to cash out for months. Some teams pay smaller members less often but in larger amounts so each payout clears the minimum. Agree this in writing.

---

## 5. Minors: a parent or guardian is part of the process

DevEx allows requests from age 13. The payment and tax side is a different matter:

- The portal and payment setup involve a legal name, a bank account, a tax form and possibly ID. Community reports on the DevForum say the payments portal expects an adult birth date, and that a parent or guardian is expected to complete the portal setup for a minor. This is **not confirmed in the Roblox docs page** read for this note; treat it as unverified and check the DevEx Terms and Roblox Support.
- Whose name and tax number go on the tax form for a minor's income is a tax question with country-specific answers. Third-party guides disagree. Ask a qualified tax professional in your country with your parent or guardian.
- Contracts with a minor (a revenue share, a commission) generally need a parent or guardian, and in many places a minor can void a contract. See [[Commissions Pricing and Contracts]] and [[Hiring Freelancers and Revenue Shares]].
- Roblox's own Creator Store seller rules (a separate program) require sellers to be 18, or 13 to 17 with a parent or guardian's consent (Roblox docs, as of October 2026). That is a good model for how to think about DevEx too: involve the adult from the start, not after the first big month.

If you are a teen developer: tell a parent or guardian before money arrives, not after. Earnings that surprise a household at tax time are the most common bad outcome, and it is avoidable.

---

## 6. Taxes: what to prepare, not what to file

This is the section where the "not advice" notice matters most. What is safe to say in general:

- **Roblox needs a tax form before paying.** U.S. taxpayers give a W-9; others give a W-8 (Roblox docs). The portal guides you through it.
- **Payouts are income in most countries.** Whether they are business income, self-employment income or something else, which expenses you can deduct, and which thresholds apply, depend on where you live. Do not copy a rule from a forum post written for another country.
- **Keep records from day one.** For each payout: date, Robux amount, rate, USD received, currency conversion, bank fees. For each expense: what, when, how much, receipt. Contractor payments you made: who, what for, amount, in Robux or money.
- **Set money aside.** Rule of thumb many developers use: keep a share of every payout untouched until you know your tax bill. The right share is a question for a tax professional; the habit is free.
- **Beware tax-themed scams.** Roblox warns that official tax emails come only from specific Roblox addresses, and that you should never reply to an email with tax forms or ID attached. Phishing around payouts is common because developers expect payment emails.

Facts deliberately left out of this vault: U.S. information-return thresholds and any country's tax rates. They change, sources conflict, and the right one depends on you.

---

## 7. Planning money as a team

### Write shares in Robux, not dollars

The exchange rate is set by Roblox and has changed before (0.0035 to 0.0038 in 2025, plus the 18+ rate in 2026). A contract that says "you get 20% of revenue" is unclear: 20% of what, in which currency, at which rate?

Clearer wording, for a revenue share paid through group recurring payouts:

```
Share: 20% of the experience's Earned Robux, paid through the group's
recurring payout setting. The member is responsible for their own DevEx
request and tax. The owner does not guarantee any exchange rate.
```

For a fixed USD amount paid outside Roblox, the owner carries the rate risk instead, and must DevEx first and pay from the bank. That means more admin, a tax position for the owner, and a delay of at least one DevEx cycle. See [[Hiring Freelancers and Revenue Shares]].

### Cash flow timing

Sales today do not become money today. Roughly:

```
sale -> Earned Robux (some programs hold earnings, for example engagement
        payouts have a 60-day hold, see [[Subscriptions and Premium Payouts]])
     -> wait for the next monthly request window
     -> review, portal, about 5 to 10 business days
     -> bank transfer
```

Rule of thumb: plan as if money from a given month's sales arrives four to eight weeks later. A studio that pays contractors in cash must hold that much buffer ([[Running a Small Studio as a Business]]).

### Refunds and reversals

Robux from purchases that are later reversed can be removed. [[Refunds Chargebacks and Purchase Support]] covers what happens on the player side. On the business side: do not count a launch-week spike as banked until it has cleared, and never promise a contractor a payout from revenue you have not yet received.

---

## 8. Worked example: a three-person team's first payout

A group owns a game. Monthly Earned Robux: 120,000. Agreed split through recurring payouts: owner 50%, scripter 30%, builder 20%. None has a legacy balance.

| Person | Robux per month | Months to reach 30,000 | Value per month at 0.0038 |
|---|---|---|---|
| Owner | 60,000 | 1 | 228 USD |
| Scripter | 36,000 | 1 | 136.80 USD |
| Builder | 24,000 | 2 | 91.20 USD |

Points to notice:

- The builder can cash out only every second month. That is fine if everyone knew it in advance; it causes a dispute if nobody did.
- If 15% of the Earned Robux comes from verified U.S. adults in an eligible game, each figure rises by about 6% (0.15 x 42%). Nobody should plan on that until it shows up in the cash-out screen.
- Each person files their own tax form and handles their own tax. If one is under 18, a parent or guardian is involved in the portal and the agreement.

---

## 9. Common mistakes

- **Counting purchased Robux as income.** Robux you bought is not exchangeable.
- **Assuming one rate.** Standard is 0.0038 USD per Earned Robux; 0.0054 applies only to spend by age-checked US 18+ buyers in R15 games. Legacy balances, mixed rates and dashboard lag also change the figure.
- **Misreading Creator Rewards.** Daily Engagement: 5 Robux/day per Active Spender; Audience Expansion: 35% of new users' first $100. Details: [[Subscriptions and Premium Payouts]].
- **Submitting with the minimum exactly.** A late adjustment or lag drops you below 30,000 and the request fails.
- **Missing the one-week portal window.** The request is declined; you wait for next month.
- **Using a nickname or a parent's name inconsistently.** Name mismatches block payouts; fix them with Support before resubmitting.
- **Promising USD figures to teammates.** Promise shares of Earned Robux; let each person cash out.
- **No records.** Rebuilding a year of payouts at tax time from emails is painful and error-prone.
- **Spending the whole payout.** Set tax money aside first.
- **Treating any payout email as genuine.** Check the sender; never send ID or tax forms by email reply.
- **Hiding earnings from a parent or guardian as a minor.** It goes wrong at the worst moment.

---

## 10. When not to worry about DevEx yet

- Your game has not launched or earns a few thousand Robux a month. Spend that time on the game ([[Planning and Scoping a Roblox Game]]); reinvesting Robux in ads or assets may be worth more than a small payout ([[Ads and Rewarded Video]]).
- You are a solo hobbyist with no team: the only steps that matter early are using a group, keeping records, and telling a parent or guardian if you are under 18.

---

## Checklist

- [ ] Read the current DevEx Terms of Use and the DevEx page on the Creator Hub.
- [ ] Verified email; legal name matches what you will use on the form.
- [ ] Tax form type known (W-9 or W-8); a tax professional consulted where needed.
- [ ] Parent or guardian involved if you are under 18.
- [ ] Balance above 30,000 Earned Robux with a buffer; legacy balance noted.
- [ ] One request per month planned; portal registration done within one week.
- [ ] Team shares written in Earned Robux, with who handles their own DevEx and tax.
- [ ] Payout and expense records kept from the first month.
- [ ] Tax share set aside from every payout.
- [ ] Payout emails checked against official Roblox senders.

## See also

[[Business and Careers Start Here]], [[Monetization Overview]], [[Subscriptions and Premium Payouts]], [[Game Passes]], [[Developer Products and ProcessReceipt]], [[Refunds Chargebacks and Purchase Support]], [[Scoping and Roles for Small Teams]], [[Hiring Freelancers and Revenue Shares]], [[Running a Small Studio as a Business]], [[Commissions Pricing and Contracts]], [[Age Checks and Safety Features]], [[Roblox Policies Ratings and Compliance]]

## Connected notes
<!-- auto-links:start -->
[[Working with Contractors and Revenue Splits]] · [[Legal Basics - IP Licenses and Assets]] · Groups Roles and Permissions for Studios · Publishing Selling and Updating Plugins · Working with Content Creators · Team Collaboration Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Discovery and Monetization Changes 2025-2026]] · [[Publishing Selling and Updating Plugins]] · [[Building a Portfolio as a Roblox Developer]] · [[Groups Roles and Permissions for Studios]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Commerce and Physical Goods]]
<!-- related:end -->
