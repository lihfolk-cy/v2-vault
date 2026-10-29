---
tags: [marketing, thumbnails, icons, ab-testing, personalization, experiments, statistics, ctr, analytics, type/guide, area/marketing, level/intermediate]
---
# Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: five near-identical variants. Symptom: no detectable difference, nothing learned.
> - Avoid: picking a winner after two days. Symptom: the novelty lead disappears in week two.
> - Avoid: deleting all "losers". Symptom: overall qPTR drops because segments lost their best match.
> - Hypothesis, variable, metric, guardrail and stop rule written before upload.
> - Control kept active; challengers differ in one variable or one idea.
> - Run at least 7 days, ideally 10 to 14, outside update days.
>
> Cost: TL;DR ~170 tok · whole note ~3.3k tok. Read more: ## 1. What tools exist (verified 2026-10-29) · ## 3. How many impressions you need · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox gives you one built-in tool aimed squarely at storefront art, **thumbnail personalisation**, and several indirect ways to test what it does not cover, such as icons. This note explains what each tool actually measures (as documented on 2026-10-29), how to design a thumbnail test that teaches you something, how many impressions you need before trusting a difference, and how to read results when clicks and retention disagree. The general experiment system (Configs, in-game experiments, statistics) is covered in [[A-B Testing and Experiments on Roblox]]; onboarding tests in [[Measuring Onboarding - Funnels, Drop-off and A-B Tests]]; specs in [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]]. Hub: [[Thumbnails and CTR Start Here]].

Labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**.

---

## 1. What tools exist (verified 2026-10-29)

| Tool | Tests | Metric | Label and source |
|---|---|---|---|
| **Thumbnail personalisation** (Home Page tab) | 2 to 5 active 16:9 thumbnails on Home recommendations | qPTR per thumbnail, per user group | Roblox docs https://create.roblox.com/docs/production/promotion/thumbnails |
| **Experiments on Configs** (Creator Hub) | In-game config values and matchmaking | D1, D7 retention, playtime, ARPU, ARPPU, payer conversion, session time | Roblox docs https://create.roblox.com/docs/production/experiments |
| **Sponsored ads creatives** | Up to 10 thumbnails per campaign, "evenly distributed across players" | Impressions, clicks, plays, cost per play, playtime | Roblox docs https://create.roblox.com/docs/production/promotion/ads-manager |
| **Icon testing** | No built-in icon test or icon personalisation is documented on the icon, thumbnails or experiments pages | n/a | Roblox docs (absence), https://create.roblox.com/docs/production/promotion/game-icons |

Whether the ads report breaks results down **per creative** is **Unverified** from the docs page; check your campaign report before relying on it.

### Thumbnail personalisation in detail
- Starts when **2 or more** thumbnails are active; set **2 to 5** with the Active checkbox; upload under 3 MB at 1920 x 1080 (**Roblox docs**).
- It is a **multi-armed bandit**, not a fixed split: impressions start evenly split, and **each hour** thumbnails with higher qPTR for a user group get more of that group's impressions while the others keep a small share (**Roblox docs**, staff announcement November 2024: https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233).
- **Thumbnail Performance** table, data after "a few hours" (**Roblox docs**):
  - **Status**: active for personalisation or not.
  - **Impressions**: Home recommendation impressions.
  - **Qualified Plays**: qualified plays from Home recommendations.
  - **Average Playtime**: average session minutes per qualified play.
  - **Qualified Play Through Rate**: qualified plays divided by impressions.
  - **Winning Segment**: the thumbnail with the highest play-through rate in the current process.
  - Graphs of impressions and qPTR by thumbnail.
- Reported impact: average **+8.5 %** qPTR for games using it, some up to **+50 %** (**Measured**, Roblox's own figure).
- Games under **1,000 DAU** may not see meaningful results (**Roblox docs**, staff post).
- Roblox's advice: keep several thumbnails active instead of picking one winner; wait a few days before removing a clear winner; test new thumbnails with major updates, then leave them until the next update.

Two consequences of the bandit design:
1. **"Losing" thumbnails can still be winners for a segment.** Removing them can lower overall qPTR because some user group lost its best match.
2. **Impression counts are unequal by design.** A thumbnail with few impressions is not under-tested by accident; the bandit has decided it is weaker for most groups. Its qPTR estimate is noisy.

---

## 2. Designing a thumbnail test

### One variable, one hypothesis
Write before uploading:

```
Hypothesis: showing the pursuer behind the thief (danger + goal)
            beats the thief alone, for new players on phones.
Variable:   presence of the pursuer. Same pose, palette, camera, text.
Metric:     qPTR. Guardrail: average playtime per qualified play.
Stop:       10+ days, or 20,000+ impressions on the smaller variant.
```

- **One variable per pair** (subject, emotion, palette, text yes or no, camera distance). If two thumbnails differ in five ways, a winner tells you nothing you can reuse.
- **Separate idea tests from polish tests.** Early on, test big ideas (four different promises). Once you know the winning promise, test single variables inside it.
- **Keep a control.** Leave your best current thumbnail active as the baseline in every round.
- Personalisation is a pool, not a duel: with 5 slots, a good round is "1 control + 2 idea challengers + 2 single-variable tweaks of the control".

### Run length
- **At least 7 days, ideally 10 to 14**, so every weekday and a weekend are covered (Rule of thumb). Roblox traffic swings strongly by weekday, school holidays and time zones.
- Do not start a round on the day of a big update; the update changes who arrives and how they behave. Start a day or two after, or treat the update day as noise.
- Note every change in a dated log so you can match traffic shifts to art changes later ([[Analytics and Funnels]]).

---

## 3. How many impressions you need

qPTR is a small proportion, so differences need large samples. A quick estimate for a two-variant comparison (80 % power, 5 % two-sided significance) is Lehr's rule:

```
impressions per variant  ≈  16 × p × (1 − p) / d²
p = baseline qPTR (as a fraction), d = absolute difference you want to detect
```

Worked examples (Rule of thumb arithmetic):

| Baseline qPTR | Lift to detect | d | Impressions per variant |
|---|---|---|---|
| 4 % | +25 % relative (to 5 %) | 0.010 | about 6,100 |
| 4 % | +15 % relative (to 4.6 %) | 0.006 | about 17,000 |
| 4 % | +8 % relative (to 4.32 %) | 0.0032 | about 60,000 |
| 8 % | +15 % relative (to 9.2 %) | 0.012 | about 8,200 |

Read it this way:
- At low traffic, only **bold** changes (new promise, new subject) produce differences you can detect. Fine-tuning a font is invisible below tens of thousands of impressions per variant.
- The bandit gives losers fewer impressions, so the weakest thumbnail's estimate stays uncertain. That is fine: you only need to be confident that the winner beats the control.
- The baseline qPTR in the examples is illustrative; your own dashboard number is the one to use. Roblox does not publish genre qPTR benchmarks on the pages read for this note.

### A quick confidence check
For each thumbnail compute a rough 95 % interval: `qPTR ± 1.96 × sqrt(qPTR × (1 − qPTR) / impressions)`. If the winner's interval does not overlap the control's, the difference is probably real. If they overlap, keep running or accept "no detectable difference" and test a bolder idea.

---

## 4. Reading results

### Uplift
`uplift = (qPTR_variant − qPTR_control) / qPTR_control`. Report it with the impressions behind it: "+18 % on 22k vs 31k impressions" is useful; "+18 %" alone is not.

### Watch for the novelty effect
A fresh thumbnail can win for the first days simply because returning browsers have not seen it. Signs: the variant's lead shrinks day over day. Defences: run at least 10 days and compare the second week alone; look at whether the lead holds among the bandit's segments.

### When qPTR goes up but retention goes down
This is the most important reading in the note.

| qPTR | Avg playtime per qualified play | First-play bounce / D1 | Verdict |
|---|---|---|---|
| Up | Up or flat | Flat or better | Keep: the tile attracts players who like the game |
| Up | Down | Worse | **Over-promise.** Retire it or change the game's first minutes to deliver the promise |
| Flat | Up | Better | Keep: it attracts better-fitting players even without more clicks |
| Down | Up | Better | Usually keep alongside others; it may suit a niche segment |
| Down | Down | Worse | Retire |

Ranking uses first-play bounce, play days and playtime per user as well as play-through rate (**Roblox docs**, https://create.roblox.com/docs/production/promotion/discovery), so a thumbnail that buys clicks with bounce can cost impressions later ([[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]]).

Average playtime per qualified play is shown in the Thumbnail Performance table. For bounce and D1 per thumbnail, Roblox's dashboards do not split retention by thumbnail on the pages read (**Unverified** that any such split exists); compare cohorts by date instead (weeks with vs without the new thumbnail) in the retention dashboard ([[Retention Cohorts]]).

### Winning segment
If one thumbnail wins only for one group (an age band, a platform, a region), that tells you who your art speaks to. Decide whether that is your target audience, and design the next challenger for the group you are losing.

---

## 5. Testing icons

There is no documented icon personalisation, so use one of these (Rule of thumb):

1. **Time-sliced before/after.** Run icon A for 14 days, icon B for 14 days, compare impressions and plays from icon-led sources (Continue, Search, Charts, Home other) in the Acquisition dashboard (https://create.roblox.com/docs/production/analytics/acquisition). Weak evidence because everything else changes over time; only trust large differences (30 %+) and avoid update weeks.
2. **Hold thumbnails constant** during an icon test, and avoid icon tests in the same weeks as a personalisation round.
3. **Pre-test the idea with thumbnails.** The icon's hero (face, creature, symbol) can be tested first as a 16:9 thumbnail variant; a subject that wins on Home usually makes a good icon subject.
4. **Qualitative pre-test.** The size, row and stranger tests in [[Game Icon Design - Readable at Small Sizes]] catch most bad icons before they go live.
5. **Change one thing.** Keep silhouette or palette stable so returning players still recognise the game.

---

## 6. Using Sponsored ads as a test bench

Ads can include up to 10 thumbnails distributed evenly across players and report impressions, clicks, plays and playtime (**Roblox docs**, ads manager page). That makes a small, fixed-budget campaign useful as a **pre-launch creative test** when organic traffic is too small for personalisation. Caveats:
- Ad audiences differ from organic Home audiences; a winner in ads is a strong candidate, not a proven organic winner.
- Ad-acquired users do not count toward ranking signals (**Roblox docs**, discovery page).
- Budgeting and cost per play maths are in [[Sponsored Ads and Campaign Math]].

---

## 7. A testing calendar (Rule of thumb)

| When | Round |
|---|---|
| Pre-launch | Ads creative test: 4 to 6 different promises, small budget |
| Launch week | Top 3 promises from the ads test + control in personalisation |
| Week 2 to 3 | Retire clear over-promisers; add 2 single-variable tweaks of the best |
| Each major update | 1 to 2 thumbnails showing the update's real content; keep evergreen winners |
| Events | Event variant added at start, removed at end ([[Live Ops Events and Updates]]) |
| Every quarter | One bold new idea challenger, even if the pool is performing |

---

## Common mistakes

- Avoid: five near-identical variants. Symptom: no detectable difference, nothing learned.
- Avoid: picking a winner after two days. Symptom: the novelty lead disappears in week two.
- Avoid: deleting all "losers". Symptom: overall qPTR drops because segments lost their best match.
- Avoid: judging on qPTR alone. Symptom: plays up, playtime per play down, impressions fall a week later.
- Avoid: changing icon, thumbnails and title in the same week. Symptom: a traffic change you cannot attribute.
- Avoid: expecting precise answers under 1,000 DAU. Symptom: rankings of thumbnails flip daily.

## Checklist

- [ ] Hypothesis, variable, metric, guardrail and stop rule written before upload.
- [ ] Control kept active; challengers differ in one variable or one idea.
- [ ] Run at least 7 days, ideally 10 to 14, outside update days.
- [ ] Impressions per variant compared with the Lehr estimate for the lift you hoped for.
- [ ] Rough confidence intervals compared before declaring a winner.
- [ ] Average playtime per qualified play and cohort retention checked alongside qPTR.
- [ ] Icon tests run time-sliced with thumbnails held constant.
- [ ] Every change logged with a date.

<!-- related:start -->
## Related
[[Thumbnail Review Checklist and Scoring Rubric]] · [[Click-Through Rate]] · [[Thumbnails Icons and Store Page]] · [[Launch Strategy - The First Two Weeks]] · [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]] · [[Thumbnail Genre Patterns - What Top Games Show]]
<!-- related:end -->
