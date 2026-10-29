---
tags: [discovery, recommendations, algorithm, growth, publishing, type/guide, area/monetization, level/intermediate, area/marketing]
---
# Discovery and the Algorithm

<!-- tldr:start -->
> [!tldr] TL;DR
> - First 60 seconds: player acts and gets rewarded without reading
> - Join time measured on phone
> - No pop-ups in the first minutes of a first session
> - Onboarding funnel logged and reviewed weekly
> - Day 2 to 7 return reasons exist (dailies, streaks, events)
> - Social co-play rewards
>
> Cost: TL;DR ~110 tok · whole note ~3.2k tok. Read more: ## 2. Recommended for You: the two-stage model (Docs) · ## 5. What else drives traffic · ## 9. Checklist
<!-- tldr:end -->

Most Roblox games are found through the Home page, and most of Home is **Recommended for You**, a personalised feed ranked by an algorithm Roblox now documents in some detail. This note explains how that algorithm works according to the Creator Hub "Discovery" page **as of October 2026**, what it measures and what it ignores, and how to turn that into decisions about your first session, your thumbnails, your updates and your marketing. Where the docs are silent, advice is marked rule of thumb.

---

## 1. Where players find games (Docs)

| Surface | What is there | What you control |
|---|---|---|
| **Home** | Recommended for You, Continue Playing, Friends list, Sponsored, curated sorts, Standout Games, Live Events | Thumbnails, title, retention (which drives Continue Playing), events, ads |
| **Game Details page** | Events, groups, passes and subscriptions, similar games | Description, media, events, community, store items |
| **Search** | Semantic, natural-language search in officially supported languages | Accurate title and description |
| **Discover** | Top charts and trending sorts | Indirectly: growth and engagement |
| **Notifications** | Experience notifications, in-game opt-in prompts, event reminders | Notification strings, events ([[Live Ops Events and Updates]]) |

Search being **semantic** matters: keyword stuffing ("SIMULATOR RNG TYCOON OBBY FREE") does not help and the docs ask for accurate, relevant metadata. Describe what the player does in plain words.

---

## 2. Recommended for You: the two-stage model (Docs)

1. **Retrieval** picks a subset of games a given user might enjoy, based on signals like engagement, retention and monetization.
2. **Ranking** orders that subset for the individual user and chooses what to show.

Distribution is described in terms of **impressions** (your tile shown) and **plays** (someone clicks and plays).

### The signals, in the docs' listed priority

| Signal | Definition (Docs) | Practical lever |
|---|---|---|
| **Play-through rate** | Plays after impressions in Recommended for You. Called "most important" | Thumbnail, title, icon ([[Thumbnails Icons and Store Page]]) |
| **First-play bounce rate** | Negative signal, measured at under 60 seconds and at 61 to 180 seconds | Join time, first 3 minutes ([[First-Time User Experience and Onboarding]]) |
| **Play days per user** | Day 1, Days 2 to 7, Days 8 to 28 | Return hooks ([[Retention and Return Hooks]]) |
| **Playtime per user** | Capped at 60 minutes per user per game per day | Session design ([[Core Loops and Session Design]]) |
| **Intentional co-play days per user** | Days users return to play with friends (joins, invites, private servers) | Social features ([[Social Design and Multiplayer Play]]) |
| **Qualified play sessions per user** | Meaningful sessions that filter out accidental clicks and quick bounces (no numeric threshold published) | Same as bounce rate |
| **Spend days per user** and **Robux spent per user** | Monetization per user | Store ([[Pricing and Store Design]]) |

Two facts from the docs that change strategy:
- **Signals are calculated only from users who joined organically from Recommended for You.** Players from ads, curation, friends, search or social media do not count in ranking, though those sources "can still accelerate a game's consideration" for recommendations.
- **Signals are per-user averages, not totals.** A big game is not favoured for being big. A small game with excellent per-user numbers can be recommended.

And: benchmark games and benchmark metrics do not affect the algorithm (Docs). They are for your information only.

### Reading the list as a designer
- **Play-through rate is about promise.** Your tile promises something; players click if it looks fun and clear.
- **Bounce rate is about delivering the promise fast.** If the thumbnail shows a giant sword fight and the first minute is a loading screen and a menu, the 0 to 60 second bounce kills you.
- **Play days and co-play days are about return.** One great session is not enough; the algorithm looks at days 2 to 7 and 8 to 28.
- **Playtime is capped at 60 minutes.** Beyond an hour per day, more time does not help ranking. A game that holds players for 45 focused minutes and brings them back tomorrow beats one that holds them for 4 hours once. AFK farming adds nothing here.
- **Monetization is a signal, not just income.** Spend *days* rewards repeated small purchases over one big one.

---

## 3. The playtime cap and AFK design

A common simulator pattern is rewarding AFK time (offline vaults, AFK zones, auto-farming). Since ranking counts playtime only up to 60 minutes per user per day, AFK hours do not help ranking beyond that cap. They can still help retention (a reason to return) and [[Creator Rewards]] (the 10-minute daily engagement bar; see [[Subscriptions and Premium Payouts]]). The reference project's offline "vault" banked a share of income while players were away, capped at 8 hours (12 for VIP), and paid it out in a welcome-back card after the player pressed Play. That design brings players back *into* the game daily, which hits play days; it does not try to inflate playtime. Rule of thumb: design AFK rewards to create a return, not to keep a client idling.

---

## 4. First-play bounce: the most controllable signal

Every second before the player does something fun counts against you. Measured levers:

| Lever | Typical problem | Fix |
|---|---|---|
| Join time | Huge place, everything loaded up front | Streaming, deferred loading ([[Case Study - Fast Join and Deferred Loading]], [[Instance Streaming]]) |
| Main menu | "Press Play" screen before any gameplay | Put the player in the world; menu as overlay, or skip for new players |
| First action | Tutorial text walls | One clear action in the first 10 seconds |
| First reward | Reward after minutes | Reward in the first 30 seconds |
| Pop-ups | Daily reward, group prompt, starter pack on join | Gate all pop-ups away from the first session's first minutes |

**Reference project.** Players reported feeling "thrown in the game without knowing what to do". The team cut the tutorial to three locked steps (roll, equip, enter the first portal), blocked every input outside the current step, guaranteed a common result on the first roll, hid unneeded HUD, and then added a "next goal" tracker with a trail to the target after the tutorial. All auto pop-ups (community prompt, favourite prompt, daily reward) were held until well after onboarding. Those changes target exactly the 0 to 180 second bounce windows.

Track this yourself with an onboarding funnel ([[Analytics and Funnels]]): log a step at join, at first action, at first reward, at tutorial end. The step where most players vanish is your bounce problem.

---

## 5. What else drives traffic

- **Continue Playing** is the cheapest traffic you have: it is retention made visible. Anything that brings players back daily also earns you this slot.
- **Friends.** Co-play is a ranking signal and friend joins are an acquisition channel. Make joining a friend fast and rewarding (friend luck boosts, party rewards). The reference project gave a luck bonus for playing with friends and a group-member luck bonus.
- **Share links.** Creator Hub share links carry attribution into Creator Rewards' Audience Expansion and have their own analytics tab (Docs). Put a share or invite button where players feel proud (a rare drop).
- **Events.** Experience events appear on your details page, in a Trending Events sort (event started in the last 7 days, 1,000+ RSVPs, public) and can trigger notifications (Docs). See [[Live Ops Events and Updates]].
- **Ads.** Paid traffic gives data and can accelerate consideration, but does not count in ranking signals (Docs). See [[Ads and Rewarded Video]].
- **Curation and Standout Games.** Not something you can apply for directly in general (unverified); events can be submitted for off-platform featuring at least 7 days ahead (Docs).

### Audience gates limit discovery
Maturity labels decide which age groups see you on Home and Charts (Docs). A game that is 16+ only (Content May Vary, or still in the Kids and Select trial) is not recommended to younger users at all. See [[Publishing an Experience]] and [[Roblox Policies Ratings and Compliance]].

---

## 6. A launch playbook (rule of thumb)

1. **Before launch:** measure join time on a mid-range phone. Make the first 60 seconds fun without reading.
2. **Soft launch:** public but excluded from Recommended for You (a setting under Audience, Advanced) (Docs), or driven by a small ad campaign. Measure D1 retention, bounce windows and session length from these players.
3. **Fix the funnel** until D1 is acceptable for your genre.
4. **Thumbnails:** activate 2 to 5 thumbnails so personalisation can pick per audience ([[Thumbnails Icons and Store Page]]).
5. **Open recommendations.** Watch impressions and play-through rate in the Acquisition dashboard.
6. **Update rhythm:** an update with an event every 1 to 2 weeks keeps play days up and gives notifications a reason to fire.

Never optimise only play-through rate. A misleading thumbnail raises clicks and bounce rate together; the second cancels the first and harms your standing with players who feel tricked. The thumbnail rules forbid misrepresentation anyway.

---

## 7. Diagnosing a traffic change

When DAU moves, find which stage moved before changing anything (rule of thumb):

| What changed | Look at | Likely cause |
|---|---|---|
| Impressions fell | Acquisition: impressions by source | Per-user signals dropped (retention, bounce) so retrieval shows you less; maturity label or audience changed; a sort or event ended |
| Impressions steady, play-through fell | Thumbnail personalisation metrics | Thumbnail fatigue; a competitor's tile next to yours; a seasonal mismatch |
| Plays steady, D1 fell | Retention by join date, onboarding funnel | A bug or slowdown in the first session; a new pop-up; an update that broke the tutorial |
| D1 steady, D7 fell | Retention cohorts, progression funnel | Mid-game wall; a nerf; the end of content |
| Everything fell on one date | Error report, server logs, release history | A broken release; a platform incident |
| Everything rose on one date | Share link and source analytics | A video creator, an event, a featured placement |

Annotate every release, price test, thumbnail change and event with its date so you can read these charts later ([[Analytics and Funnels]]). Without dates, a traffic drop becomes guesswork.

### The update test
After every update, compare the first three days of players who joined after it with the three days before: bounce windows, D1, session time, spend days. If the update helped existing players but hurt new ones (common with added complexity), the algorithm will notice the second part first.

---

## 8. Common misconceptions

| Belief | Reality (Docs, Oct 2026) |
|---|---|
| "Bigger games get boosted" | Signals are per-user averages |
| "Ads buy ranking" | Ad-acquired players are excluded from ranking signals; ads only speed consideration |
| "More hours played = more recommendations" | Playtime capped at 60 min per user per day |
| "Keywords in the title help search" | Search is semantic; docs ask for accurate metadata |
| "Benchmarks affect ranking" | They do not |
| "Premium playtime matters" | Premium payouts are gone; Premium was closed to new sign-ups in 2026 |

## 9. Checklist
- [ ] First 60 seconds: player acts and gets rewarded without reading
- [ ] Join time measured on phone
- [ ] No pop-ups in the first minutes of a first session
- [ ] Onboarding funnel logged and reviewed weekly
- [ ] Day 2 to 7 return reasons exist (dailies, streaks, events)
- [ ] Social co-play rewards
- [ ] 2 to 5 thumbnails active
- [ ] Title and description accurate and specific

## See also
[[Thumbnails Icons and Store Page]] · [[Analytics and Funnels]] · [[Live Ops Events and Updates]] · [[First-Time User Experience and Onboarding]] · [[Retention and Return Hooks]] · [[Core Loops and Session Design]] · [[Community Building]] · [[Monetization Overview]]

## Connected notes
<!-- auto-links:start -->
[[Launch Strategy - The First Two Weeks]] · Sponsored Ads and Campaign Math · Marketing and Growth Start Here · Click-Through Rate · Retention Cohorts · Session Length
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Sponsored Ads and Campaign Math]] · [[Discovery and Monetization Changes 2025-2026]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Robux Price Points and Offer Design]] · [[Economy Inflation Sinks and Faucets Math]] · [[Age Checks and Safety Features]]
<!-- related:end -->
