---
tags: [marketing, ccu, ctr, discovery, recommendations, impressions, retention, session-length, growth, analytics, type/guide, area/marketing, level/intermediate]
---
# From CTR to CCU - Impressions, Play-Through and the Discovery Loop

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: chasing peak CCU screenshots. Symptom: decisions based on one Saturday evening.
> - Avoid: buying ads to "boost ranking". Symptom: CCU drops back the day the budget ends.
> - Avoid: fixing qPTR while bounce is high.
> - CCU model in a spreadsheet with your own impressions, qPTR, retention, sessions and session length.
> - Sensitivity run: which single input moves CCU most for your game right now.
> - Organic Home metrics read separately from ads and other sources.
>
> Cost: TL;DR ~160 tok · whole note ~3.0k tok. Read more: ## 2. What Roblox documents about the loop · ## 3. Worked example: a mid-size game · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Concurrent users are not a goal you can work on directly; they are the output of a chain: impressions, play-through, session length and return visits. This note writes that chain as arithmetic you can run on your own dashboard numbers, shows how Roblox's recommendation signals turn good per-user numbers into more impressions, separates paid from organic traffic, and ranks what to fix once your thumbnail is no longer the bottleneck. It builds on the documented ranking model in [[Discovery and the Algorithm]], the funnel triage in [[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]], the cohort concepts in [[Retention Cohorts]] and [[Session Length]], and the ad payback maths in [[Sponsored Ads and Campaign Math]]. Hub: [[Thumbnails and CTR Start Here]].

Labels: **Roblox docs** (read 2026-10-29), **Measured**, **Rule of thumb**, **Unverified**. All worked numbers below are illustrative arithmetic, not benchmarks.

---

## 1. The core identity

Average CCU over a day is total minutes played that day divided by the minutes in a day:

```
average CCU = (sessions per day × average session minutes) / 1,440
```

This is Little's law: concurrency equals arrival rate times time spent. Peak CCU is higher than average because play clusters by time zone and after school; rule of thumb, **peak is 1.5 to 2.5 times the daily average** for games with one dominant region, lower for globally spread audiences. Weekends commonly run above weekdays (Rule of thumb; check your own Engagement dashboard).

Sessions come from two places:

```
sessions per day = new-user sessions + returning-user sessions
new users per day ≈ Σ over sources (impressions × qualified play-through rate)
returning users per day ≈ Σ over past cohorts (cohort size × retention on that day)
```

So CCU rises when **any** of these rise: impressions, qPTR, session length, retention, sessions per user.

---

## 2. What Roblox documents about the loop

- Recommended for You uses **retrieval** (choose candidate games) then **ranking** (order them per user) (**Roblox docs**, https://create.roblox.com/docs/production/promotion/discovery).
- Most important signals: **play-through rate**, **first-play bounce rate** (under 60 s and 61 to 180 s), **play days per user** (Day 1, Days 2 to 7, Days 8 to 28) and **playtime per user**, capped at **60 minutes per user per game per day**. Also important: intentional co-play days, qualified play sessions, spend days and Robux spent per user (**Roblox docs**).
- Signals are **per-user averages**, not totals, and only from users who **joined organically from Recommended for You** (**Roblox docs**).
- Impression drops typically follow declines in play-through rate, play days and playtime, and rises in first-play bounce (**Roblox docs**).
- A custom thumbnail is required for Home recommendation impressions (**Roblox docs**).
- The Home Recommendations source is reported in Analytics, Acquisition, with charts for new and returning users' impressions and plays per source, play-through rate, and a cumulative new-users funnel; conversion rate is the percent of new users who played after an impression (**Roblox docs**, https://create.roblox.com/docs/production/analytics/acquisition).

Reading: the thumbnail decides how many of your impressions become plays; the first three minutes and the return visits decide how many impressions you get next week. **CTR fills the funnel; retention widens it.**

How strongly ranking responds to a given improvement is not published (**Unverified**); treat any "doubling" claims as anecdote.

---

## 3. Worked example: a mid-size game

Inputs (illustrative):

| Input | Value |
|---|---|
| Home recommendation impressions per day | 150,000 |
| qPTR on Home | 5 % → 7,500 new qualified players per day |
| Other new-user sources (search, friends, charts, share links) | 2,500 per day |
| D1 retention | 22 % |
| Average daily return rate, days 2 to 7 | 12 % |
| Average daily return rate, days 8 to 30 | 5 % |
| Sessions per active user per day | 1.4 |
| Average session length | 16 minutes |

**Step 1, expected active days per new user over 30 days:**
`1 + 0.22 + (6 × 0.12) + (23 × 0.05) = 1 + 0.22 + 0.72 + 1.15 ≈ 3.1`

**Step 2, steady-state DAU** (once 30 days of cohorts have stacked up, ignoring players beyond day 30):
`10,000 new per day × 3.1 ≈ 31,000 DAU`

**Step 3, minutes played per day:**
`31,000 × 1.4 × 16 ≈ 694,000 minutes`

**Step 4, average CCU:**
`694,000 / 1,440 ≈ 480`; with a peak factor of about 1.8, **peak ≈ 870**.

### Sensitivity: which lever moves CCU most?

Each row changes one input from the example (before any ranking feedback):

| Change | New avg CCU | Change |
|---|---|---|
| qPTR 5 % → 6 % (+20 % relative) | ≈ 555 | +15 % |
| Session length 16 → 20 min | ≈ 600 | +25 % |
| D1 22 % → 30 % and days 2 to 7 avg 12 % → 16 % | ≈ 530 | +10 % |
| Days 8 to 30 avg 5 % → 8 % | ≈ 590 | +22 % |
| Sessions per user 1.4 → 1.7 | ≈ 585 | +21 % |
| Impressions +50 % (better ranking) | ≈ 660 | +37 % |

What the table says:
- A good thumbnail improvement is worth roughly what a good retention improvement is worth, in the short run.
- **The biggest single row is impressions**, which you cannot buy organically; you earn them with play-through, low bounce, play days and playtime. That is why retention work pays twice: once directly, once through ranking.
- Long-term return (days 8 to 30) matters as much as D1 because it stacks over many days.

To run your own numbers, put these steps in a spreadsheet with your dashboard values and change one input at a time.

---

## 4. Organic, paid and other traffic

| Source | Counts toward ranking signals? | What it is good for | Label |
|---|---|---|---|
| Home Recommended for You | **Yes** (the only one that does) | Sustained growth | Roblox docs, discovery |
| Sponsored ads (Home and Search) | No; can speed up consideration | Measuring your funnel, launch reach, creative tests | Roblox docs, discovery and ads manager |
| Friends, search, charts, Continue, social media | No | Volume, retention (Continue is returning players) | Roblox docs, discovery |

- In the docs' example, a game with 10 thousand daily players from recommendations added 5 thousand from Sponsored, and its recommendation traffic stayed steady as long as the recommended users' behaviour held (**Roblox docs**, discovery page).
- Ads run on Home and in search results, and "running ads does not affect how your game ranks in Recommended For You" (**Roblox docs**, https://create.roblox.com/docs/production/promotion/ads-manager).
- Ads report impressions and clicks in real time; plays and earnings are attributed over up to 30 days and can take up to 48 hours to appear (**Roblox docs**, ads manager).

Practical use (Rule of thumb): paid traffic adds CCU for as long as you pay. To keep it, the organic numbers of those weeks have to justify more impressions. Use ads to prove the funnel and to test thumbnails before launch ([[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]]), not as a substitute for retention.

---

## 5. Spikes: updates, seasons and events

- **Update spikes** come mostly from returning players (Continue row, notifications, community posts). They lift CCU for 1 to 3 days (Rule of thumb). Whether they lift ranking depends on whether new players arriving that week behave better.
- **Seasonal and platform events** raise overall Roblox traffic; your share depends on whether your thumbnail and content fit the moment. Add an event thumbnail at the start and remove it at the end ([[Live Ops Events and Updates]], [[Event Calendars and Content Planning]]).
- **School holidays and weekends** raise both impressions and session length. Compare like with like: weekday to weekday, holiday to holiday.
- **A thumbnail refresh with a real update** is the cleanest moment to test new art (Roblox's own advice on the thumbnails page). See [[Update Cadence and Hype Cycles]].

When reading a spike, split it: did impressions rise (ranking or ads), did qPTR rise (art), or did returning sessions rise (update)? Each has a different follow-up.

---

## 6. After CTR is fixed: what moves CCU most

Order of attack once your qPTR is no longer clearly below your genre's peers (Rule of thumb):

1. **First-play bounce (0 to 180 s).** A documented negative signal and the usual culprit. Fast join, action and reward in the first minute, no pop-ups ([[First-Time User Experience and Onboarding]]).
2. **Promise delivery.** The first minutes must show what the thumbnail showed. If the tile shows a giant monster chase, the chase should start within a minute or two.
3. **Return reasons for days 2 to 7 and 8 to 28.** Daily goals, collections, streaks, friends ([[Retention and Return Hooks]]).
4. **Session depth up to about 60 minutes per day.** Ranking caps playtime at 60 minutes per user per day, so content that keeps players 30 to 60 focused minutes is worth more than AFK hours (**Roblox docs** for the cap; rule of thumb for the design reading). AFK time still adds to raw CCU, but not to ranking beyond the cap.
5. **Co-play.** Intentional co-play days are a documented signal; party joins and friend rewards help ranking and sessions per user.
6. **Monetisation done kindly.** Spend days and Robux spent are ranking signals; small, repeatable purchases fit better than one large paywall ([[Pricing and Store Design]]).
7. **Server fill at low CCU.** At small scale, emptier servers make games feel dead; see the server-size advice in the rescue note.

---

## 7. A weekly CCU review (Rule of thumb)

```
1. Home impressions (7-day avg)         ___  vs last week ___
2. Home qPTR / play-through rate        ___  vs ___
3. New users per day, all sources       ___  vs ___
4. First-play bounce (<60s, 61-180s)    ___  vs ___
5. D1 / D7 for last week's cohorts      ___  vs ___
6. Avg session minutes, sessions/user   ___  vs ___
7. Avg CCU and peak CCU                 ___  vs ___
8. Changes shipped (art, update, price, event) with dates
```

If CCU moved, find the earliest line that moved too; that is where the cause is.

---

## Common mistakes

- Avoid: chasing peak CCU screenshots. Symptom: decisions based on one Saturday evening.
- Avoid: buying ads to "boost ranking". Symptom: CCU drops back the day the budget ends.
- Avoid: fixing qPTR while bounce is high. Symptom: plays up, impressions down two weeks later.
- Avoid: AFK farming to inflate concurrency. Symptom: CCU up, ranking flat, because playtime is capped at 60 minutes per user per day for ranking.
- Avoid: comparing a holiday week with a school week. Symptom: phantom wins and losses.
- Avoid: treating CCU as the diagnosis. Symptom: art, title and game all changed at once with no idea which mattered.

## Checklist

- [ ] CCU model in a spreadsheet with your own impressions, qPTR, retention, sessions and session length.
- [ ] Sensitivity run: which single input moves CCU most for your game right now.
- [ ] Organic Home metrics read separately from ads and other sources.
- [ ] First-play bounce and D1 checked whenever qPTR changes.
- [ ] Weekly review filled in, with every change dated.
- [ ] Spikes split into impressions, qPTR and returning sessions before celebrating.

<!-- related:start -->
## Related
[[Launch Strategy - The First Two Weeks]] · [[Click-Through Rate]] · [[Discovery and Monetization Changes 2025-2026]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Thumbnail Review Checklist and Scoring Rubric]] · [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]]
<!-- related:end -->
