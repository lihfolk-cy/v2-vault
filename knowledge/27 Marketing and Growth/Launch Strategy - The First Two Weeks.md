---
tags: [marketing, growth, launch, soft-launch, retention, discovery, live-ops]
---
# Launch Strategy - The First Two Weeks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Launching on a Friday evening with nobody around on Saturday.
> - Avoid: Treating day 1 CCU as the verdict instead of the funnel.
> - Avoid: Shipping new content in week 1 while the onboarding leak is still open.
> - First session played by outsiders on a phone; join time measured
> - Onboarding funnel to minute 10, shop funnel, economy events live
> - 2 to 5 distinct thumbnails, icon tested small, honest title and description
>
> Cost: TL;DR ~150 tok · whole note ~4.1k tok. Read more: ## 2. Pre-launch: T minus 14 to T minus 1 · ## 3. Day by day · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

A Roblox launch is not one moment. It is a two-week window in which the recommendation system, the Kids and Select evaluation, your error budget and your own team's stamina are all tested at once. Most games that "flop" did not fail on launch day; they failed on days 2 to 5, when the first wave of players met a broken first session, nobody was watching the funnel, and the team spent the window adding content instead of fixing the leak.

This note is a day-by-day plan for those two weeks: what to have ready before you open the doors, what to watch each day, when to spend money, when to patch, and when to admit the game needs a rework rather than a push. It builds on [[Discovery and the Algorithm]] (how traffic is allocated), [[Publishing an Experience]] (the release gates) and [[Analytics and Funnels]] (the instruments). Platform facts are labelled "Roblox docs (as of October 2026)"; everything else is rule of thumb from shipping games and should be adapted to your genre.

---

## 1. What the first two weeks actually decide

Three systems are forming an opinion of your game at the same time.

| System | What it reads | Why the first two weeks matter |
|---|---|---|
| Recommended for You | Per-user averages from players who joined organically from Recommended: play-through rate, first-play bounce (under 60 s, 61 to 180 s), play days, playtime (capped at 60 min per user per day), co-play days, spend days (Roblox docs, as of October 2026) | Early per-user numbers decide how much retrieval shows you. A bad first week is not permanent, but it is slow to undo |
| Kids and Select evaluation | Highly engaged, age-checked players over a 60-day window (Roblox docs, as of October 2026; the threshold has changed several times in 2026, see [[Publishing an Experience]]) | A brand-new all-ages game starts as 16+ only. Your first players are also your eligibility players |
| Your players' memory | First impressions, word of mouth, group membership, favourites | A player who bounced on a broken tutorial rarely comes back, even after you fix it |

The key consequence: **the launch is a measurement exercise first and a growth exercise second.** You want a small, honest audience that tells you where the leaks are, then a fix, then more traffic. Pouring traffic into a leaky first session wastes the players who would have become your regulars, and (if you paid for them) your money.

### When not to "launch" at all
- The first session has not been played start to finish by someone outside the team on a mid-range phone.
- Join time on a phone is unknown. (Measure it; see [[Case Study - Fast Join and Deferred Loading]].)
- You do not have an onboarding funnel logging from join to minute 10.
- Your save system has not survived a forced server shutdown test ([[Saving Correctly - Autosave and BindToClose]]).

Any one of these makes a launch a gamble with your only first impression. Delay a week instead.

---

## 2. Pre-launch: T minus 14 to T minus 1

### The launch kit (have all of it before day 0)

| Item | Why | Link |
|---|---|---|
| 2 to 5 custom thumbnails, each with a different promise | Personalisation needs 2+ active; custom art is required for Home recommendations (Roblox docs, as of October 2026) | [[Thumbnails Icons and Store Page]] |
| Icon tested at about 150 px | It is shown that small in some places | same |
| Title and description that say what the player does | Search is semantic; misleading metadata breaks Community Standards ("Repetitive and Misleading Content") | same |
| Onboarding funnel, shop funnel, economy events | You cannot fix what you cannot see; AnalyticsService events only come from published servers | [[Analytics and Funnels]] |
| Error dashboard checked, logging in place | Day 1 bugs must be found in hours | [[Crash and Error Telemetry]] |
| A live config for tunables | Lets you change drop rates, prices, timers without a publish | [[Global State and Live Config]] |
| Kill switches for risky systems (trading, new shop items) | Turn off a dupe within minutes | [[Release Process and Rollbacks]] |
| One upcoming Experience Event | The page looks alive; Notify Me builds a list | [[Live Ops Events and Updates]] |
| A launch code | A reason to share; tests your code system | [[Codes Redemption System End to End]] |
| Community space ready with moderators | Somewhere for bug reports to land | [[Community Building]], [[Discord Servers for Roblox Games]] |
| Share links, one per channel | Attribution for every off-platform post (Roblox docs, as of October 2026) | [[Short-Form Video Marketing]] |

### Soft launch
The docs allow a game to be public while excluded from Recommended for You (a setting under Audience, Advanced; see [[Discovery and the Algorithm]]). Use that week to bring in a few hundred players you control: your community, friends of testers, a small ad campaign ([[Sponsored Ads and Campaign Math]]). These players do not count toward recommendation signals anyway (only organic Recommended joins do), so they are a free rehearsal from the ranking system's point of view.

What you want from the soft launch, in order:
1. **Crash-free sessions.** Zero data loss, no stuck tutorial states.
2. **The onboarding funnel shape.** Where is the biggest single drop?
3. **First-session length** (median, not mean).
4. **D1 for the soft-launch cohort.** Small samples are noisy; treat it as a direction, not a number.

Rule of thumb on sample size: below about 300 players in a cohort, a D1 difference of a few points is noise. Use the soft launch to find *big* leaks (a step losing 30% of players), not to fine-tune.

### Rule-of-thumb bars before opening recommendations
These vary hugely by genre and audience; they are starting points, not targets published by Roblox.

| Metric (soft-launch cohort) | Fix before opening | Acceptable to open |
|---|---|---|
| Players reaching first reward within 60 s | Under 70% | 85%+ |
| Funnel: biggest single-step drop in first 3 minutes | Over 25% | Under 15% |
| Median first session | Under 5 min | 10+ min |
| D1 retention | Clearly below your genre's benchmark scorecard | Near or above it |

The benchmark scorecards in Creator Hub need 100+ DAU (Roblox docs, as of October 2026), so for a very small soft launch you will be comparing against your own expectations rather than the dashboard.

---

## 3. Day by day

### Day 0: opening
- Publish on a weekday morning in your main region, not a Friday night. You want the team awake for the first 12 hours.
- Turn recommendations on. Post the share links. Activate the event.
- **Do not change three things at once.** Launch day changes are bug fixes only.
- One person watches the error report, one watches the funnel and live player count, one handles community reports. In a solo team, set alarms to check every hour.

### Days 1 to 3: watch the leak, not the player count
Player count on day 1 depends on things you do not control (how much retrieval is testing you, time of day, school holidays). The funnel is the honest signal.

| Observation | Likely cause | Action |
|---|---|---|
| Big drop between Joined and Loaded | Join time on phones | Defer loading, stream, cut the initial asset set |
| Big drop between Loaded and FirstAction | Unclear start, pop-ups, menu before gameplay | Remove the menu for new players, gate pop-ups ([[First-Time User Experience and Onboarding]]) |
| Drop after the tutorial | No next goal | Add a tracked objective |
| Good funnel, low D1 | Nothing to come back for | Daily hooks, streaks ([[Retention and Return Hooks]]) |
| Errors spiking on one platform | A device-specific bug | Hotfix, then retest on that device |

**Hotfix rhythm.** One patch on day 1 or 2 for crashes and stuck states, one on day 3 to 5 for the biggest funnel leak. Each publish creates mixed-version servers; decide whether to restart outdated servers based on whether save data changed ([[Publishing an Experience]]).

### Days 3 to 7: the first real decision
By day 5 to 7 you have a few cohorts with D1 and the early part of D2 to D7. Now decide which branch you are on.

| Branch | Signs | What to do in week 2 |
|---|---|---|
| **Healthy** | Funnel fixed, D1 near benchmark, impressions rising | Ship the first content drop, consider ads to accelerate, start the update rhythm ([[Update Cadence and Hype Cycles]]) |
| **Leaky start** | Play-through fine, bounce high | Keep fixing onboarding; do not buy traffic; do not add content |
| **Weak promise** | Impressions fine, play-through low on every thumbnail | New thumbnail *concepts*, not variants; check the title says what the game is |
| **No pull** | Low impressions, low play-through, low D1 | The concept may not land. Run a short competitor teardown ([[Competitor Analysis Method]]) before spending more |

### Days 7 to 14: first content and first event
The first content drop should target **existing players** (a new goal, a new zone tier, a new collection page) and be paired with an event so returning players have a reason to come back on a specific day. Add one new thumbnail variant that shows the new content. Send one update announcement (60 characters, at most one every three days; Roblox docs, as of October 2026).

This is also when you should run your first controlled experiment if your traffic supports it. See [[A-B Testing and Experiments on Roblox]] for the sample size maths; most games under about 1,000 DAU cannot detect small effects and should test only bold changes.

---

## 4. Spending money in the window

Sponsored campaigns show your tile on Home and in search, priced through auto-bidding against a daily or lifetime budget, reported as cost per play (Roblox docs, as of October 2026). Players acquired this way **do not count in ranking signals** but can "accelerate consideration" (Roblox docs). In launch terms that means:

- **Before the funnel is fixed:** a small campaign is a measurement tool. It buys you a predictable, repeatable cohort to test onboarding changes against.
- **After the funnel is fixed:** a larger campaign brings in players who may then return, invite friends (co-play joins later can be organic), and help reach the Kids and Select threshold. The Engagement objective targets highly engaged players for that threshold and does not auto-pause when the goal is met (Roblox docs, as of October 2026).
- **Never:** a large campaign on day 0 to "get the algorithm going". It does not feed ranking directly, and it burns your budget on a first session you have not yet seen real players struggle with.

Full maths in [[Sponsored Ads and Campaign Math]].

---

## 5. Worked example: a two-week launch log

A small team ships a collection game. Numbers below are illustrative, not from a real game.

| Day | Event | Funnel / metric | Decision |
|---|---|---|---|
| T-7 | Soft launch, excluded from Recommended; 400 players from community + small campaign | 31% lost between Loaded and FirstAction | Cause: a "choose your starter" menu before gameplay. Replace with a default starter and a later swap |
| T-3 | Patch, second small cohort of 350 | Drop now 12% | Open recommendations on day 0 |
| 0 | Launch, event live, code posted | Peak 180 CCU, D0 median session 11 min | Error report: a nil index in the daily reward on phones |
| 1 | Hotfix | Errors near zero | Hold content |
| 3 | D1 for day 0 cohort known | Below hoped, 30% of players leave after the tutorial | Add a tracked "next goal" arrow |
| 5 | Patch | Post-tutorial drop halves | Decide "healthy enough" |
| 8 | First content: second zone tier + weekend event, new thumbnail variant | Returning players spike Saturday | Start a modest Plays campaign with a daily budget |
| 12 | Campaign CPP and D1 of ad cohort compared with organic | Ad cohort D1 lower than organic, as expected | Keep budget small; payback check in [[Sponsored Ads and Campaign Math]] |
| 14 | Retro | | Set a 2-week update cadence |

Note what did not happen: no one added a new system in week 1. Every change was aimed at the largest measured leak.

---

## 6. What dishonest launches look like, and why they backfire

Every shortcut below is either against Roblox rules or fights the way ranking works.

| Tactic | Rule | Why it backfires even if unpunished |
|---|---|---|
| Bot visits or alt-account joins to inflate player counts | Community Standards prohibit disruptive bots and alt accounts used to evade systems | Ranking uses per-user averages from organic Recommended joins; fake visits add nothing there and can drag averages down. Risk: moderation of the game and account |
| Paying for likes or favourites from outside services | Misleading metadata and platform manipulation; accounts and game at risk | Votes from people who never play do not change retention, the signals that matter |
| A thumbnail showing content that is not in the game | Thumbnail rules forbid gameplay not in the game and graphics enhanced beyond reality (Roblox docs) | Play-through up, bounce up; the *qualified* play-through metric punishes it |
| "Free Robux" or fake giveaway claims | Scams and misleading content are prohibited; Robux contests cannot be promoted independently (Community Standards) | Destroys trust with the exact young audience you need; reports pile up |
| Title stuffed with genre keywords or another game's name | "Deceptive, sensational, duplicative, or otherwise misleading content or metadata" is prohibited (Community Standards) | Search is semantic; you attract the wrong players and they bounce |

The pattern: dishonest tactics move vanity numbers (visits, likes) and damage the numbers the system actually reads (bounce, D1, qualified play-through). See also [[Ethical Design and Player Trust]].

---

## 7. Relaunching a game that missed

If week 2 lands on "no pull", you have options short of abandoning the game:
1. **Repositioning:** new title, icon and thumbnails around the strongest moment players already enjoy. This is cheap and tests whether the problem is the promise.
2. **A first-session rebuild:** if play-through was fine and bounce killed you, the game may be good after minute 5. Move that moment to minute 1.
3. **A new place in the same universe** is rarely needed; the signals are per-user averages over recent windows, so improved numbers eventually show up (rule of thumb; the docs do not publish a decay window).
4. **Archive and reuse:** keep the systems, change the theme. Many solid games are the third attempt at the same core loop.

Be honest in your update notes about what changed. Returning players notice silent rebrands and read them as a different game.

---

## 8. Common mistakes
- Launching on a Friday evening with nobody around on Saturday.
- Treating day 1 CCU as the verdict instead of the funnel.
- Shipping new content in week 1 while the onboarding leak is still open.
- Turning on every auto pop-up (daily reward, group prompt, favourite prompt, starter pack) in the first minute.
- Buying traffic before D1 is measured.
- Changing thumbnails, prices and the tutorial in the same patch, then not knowing which one moved the numbers.
- No release log, so traffic changes cannot be tied to dates ([[Analytics and Funnels]]).

## 9. Checklist
- [ ] First session played by outsiders on a phone; join time measured
- [ ] Onboarding funnel to minute 10, shop funnel, economy events live
- [ ] 2 to 5 distinct thumbnails, icon tested small, honest title and description
- [ ] Live config and kill switches for risky systems
- [ ] Soft launch excluded from Recommended; biggest leaks fixed
- [ ] Day 0 on a weekday morning with the team on watch
- [ ] Hotfix on days 1 to 2, leak fix on days 3 to 5
- [ ] Branch decision by day 7: healthy, leaky, weak promise, or no pull
- [ ] First content drop plus event in week 2, one new thumbnail variant
- [ ] Ads only after D1 is measured
- [ ] Release log with dates for every change

## See also
[[Marketing and Growth Start Here]] · [[Discovery and the Algorithm]] · [[Publishing an Experience]] · [[Analytics and Funnels]] · [[First-Time User Experience and Onboarding]] · [[Sponsored Ads and Campaign Math]] · [[Update Cadence and Hype Cycles]] · [[Release Process and Rollbacks]] · [[QA Checklists Before Release]]

## Connected notes
<!-- auto-links:start -->
[[Retention Cohorts]] · [[Click-Through Rate]] · [[Ads and Rewarded Video]] · [[Onboarding Funnel]] · [[Working with Content Creators]] · [[Economy Telemetry and Balancing Live]]
<!-- auto-links:end -->
