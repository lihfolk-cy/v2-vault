---
tags: [marketing, growth, competitor-analysis, research, game-design, benchmarks]
---
# Competitor Analysis Method

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Studying only the genre leader and copying its scale.
> - Avoid: Reading a competitor's success into one feature while ignoring their years of content and audience.
> - Avoid: Using an old account with progress or personalisation, so the first session is not representative.
> - Three tiers chosen: 1 to 2 leaders, 2 to 4 peers, 1 to 2 adjacent
> - Watchlist set up in Creator Hub (up to nine games)
> - Teardown template filled in live, on phone and PC, fresh account
>
> Read more (14 KB note): ## 3. Data sources and how far to trust them · ## 4. The play-through teardown · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

Every Roblox genre has a few games that set what players expect: how fast the first reward comes, what the shop looks like, how often updates land, what the thumbnail promises. Studying them is how a small team avoids building a game that is already behind on day one. Studying them badly is how teams end up cloning a top game's surface, missing why it works, and competing head-on with a game that has years of content.

This note gives a repeatable method: choosing who to study, what data you can get (official and unofficial, and how far to trust each), a structured play-through teardown with a stopwatch, a store and economy teardown, tracking a competitor's updates over time, and turning all of it into decisions. It ends with the ethical and legal lines, because "study" and "copy" are different things under both Roblox's Community Standards and copyright law. Platform facts are labelled "Roblox docs (as of October 2026)"; the rest is rule of thumb.

---

## 1. Why, and when not to

Good reasons:
- **Calibrate expectations.** If every top game in your genre gives a reward within 20 seconds and yours takes 90, you know where your bounce comes from.
- **Find the gap.** What do players of these games complain about? What does none of them do?
- **Price sanity.** What do players in this genre expect to pay for a 2x pass or a starter pack ([[Robux Price Points and Offer Design]])?
- **Pacing the market.** When do competitors update? Releasing your big update on the same weekend as the genre leader is avoidable.

Bad reasons:
- **To copy the feature list.** Features are the visible part; the reasons they work (tuning, timing, audience) are not visible, and copying the list gets you a worse version of a game players already have.
- **To chase the current trend late.** By the time a trend is obvious in the charts, the leaders have months of content. Unless you have a real twist, entering late is a weak position.
- **As a substitute for your own data.** Once your game has players, your funnel tells you more about your game than any competitor ([[Analytics and Funnels]]).

---

## 2. Choosing who to study

Pick three tiers, five to eight games in total:

| Tier | Who | What you learn |
|---|---|---|
| **Leaders** (1 to 2) | The top games in your genre | Player expectations, polish bar, monetisation norms |
| **Peers** (2 to 4) | Games of similar size and age to yours, ideally launched in the last few months | What is achievable at your scale; what a fresh launch in this genre looks like now |
| **Adjacent** (1 to 2) | A game from a neighbouring genre with a mechanic you are considering | How the mechanic works outside its usual context |

Peers are the most useful tier and the one teams skip. Leaders tell you where the ceiling is; peers tell you what works for a team like yours, now.

---

## 3. Data sources and how far to trust them

### Official (Roblox docs, as of October 2026)
- **Benchmarks and watchlists in Creator Hub Analytics.** Benchmark scorecards compare your game with similar games (they need **100+ DAU** and update daily). Watchlists hold up to **nine** games; for games whose analytics you cannot see, you get like ratio and concurrent users. Benchmarks are for your information only and do not affect the algorithm. See [[Analytics and Funnels]].
- **Public game pages.** Title, description, thumbnails, icon, passes and subscriptions with prices, badges (with how many players earned each), events, groups, and visit and favourite counts as displayed.
- **Charts and sorts** on Discover.

### Unofficial
Third-party sites track concurrent players over time for public games. They are useful for trends and timing (when did this game spike? does it spike on Saturdays?). Treat them as approximate: they sample at intervals, may miss private servers, and their methods are not documented by Roblox. Never enter your account credentials into any third-party stats or "analytics boost" site.

### Inferences you can make from public data
- **Badge percentages as a funnel.** Badges show how many players earned each. If a game has a badge for finishing the tutorial and one for reaching zone 3, the ratio is a rough funnel. It is biased (badges added later only count players since then) but often revealing.
- **Pass prices as a price ladder.** The full list of passes and their prices shows the competitor's ladder ([[Pricing and Store Design]]). You cannot see sales.
- **Update rhythm from page history.** Note the "updated" date and event history weekly. A table over two months gives you their cadence.
- **Thumbnail rotation.** Screenshot the page weekly. If a thumbnail stays for months, it is probably winning in their personalisation pool.

None of these show revenue, retention or funnel numbers. Be careful with claims like "this game makes X per month" from outside sources; they are guesses.

---

## 4. The play-through teardown

Play each game as a new player, on a phone and on a PC, with a stopwatch and a template. Use a fresh or test account so their personalisation and your own progress do not distort the first session. Do not use exploits or third-party tools to read their game; it is against Roblox's rules and unnecessary for this.

### The template

```
Game: <name>          Tier: Leader / Peer / Adjacent
Date: <date>          Device: <phone model> / PC
Version cue: <update name in description>

FIRST 5 MINUTES (stopwatch from tapping Play)
- Time to load into a controllable character: __ s
- First thing on screen: menu / world / tutorial / pop-up
- Time to first action: __ s
- Time to first reward: __ s
- Number of pop-ups in first 3 min: __ (list them)
- First purchase prompt at: __ min (what, how much)
- Did I know what to do next at minute 3? Y/N, why

CORE LOOP
- One sentence: "You ___ to get ___ so you can ___."
- Loop length (one cycle): __ s
- What changes on cycle 10 vs cycle 1?

PROGRESSION
- Next goal always visible? Y/N
- First wall (where progress slows sharply): __ min
- How is the wall resolved: grind / social / purchase / skill

MONETISATION
- Passes (name, price): ...
- Products (name, price): ...
- Starter pack or first-purchase offer: Y/N, price
- Paid random items: Y/N; odds shown before purchase? (required by Community Standards)
- Rewarded ads: Y/N, placements

SOCIAL
- Reason to play with friends: ...
- Trading / co-op / competition: ...

RETENTION HOOKS
- Daily reward / streak / timers / offline income: ...
- Notification opt-in prompt: when?

STORE PAGE
- Title, first description line, thumbnail promises (list), icon
- Event active? Notify Me count if shown

FEEL
- Best moment in the session: ...
- Worst moment: ...
- Bugs or friction: ...
```

Fill it in during the session, not afterwards. Memory smooths out friction, which is exactly what you are measuring.

### The stopwatch numbers are the most valuable part
Time to first action, time to first reward, pop-ups in the first three minutes and time to first purchase prompt line up directly with the first-play bounce windows the recommendation system measures (under 60 s and 61 to 180 s; Roblox docs, as of October 2026; see [[Discovery and the Algorithm]]). Compare them in one table:

| Metric | Leader A | Leader B | Peer C | Peer D | **Yours** |
|---|---|---|---|---|---|
| Load to control (phone) | 9 s | 14 s | 11 s | 25 s | **31 s** |
| Time to first reward | 12 s | 20 s | 15 s | 60 s | **75 s** |
| Pop-ups in first 3 min | 0 | 1 | 1 | 4 | **3** |
| First purchase prompt | 6 min | 10 min | 4 min | 1 min | **2 min** |

(Illustrative numbers.) A table like this ends arguments quickly. The gap between your game and the leaders in the first minute is usually larger and cheaper to fix than any content gap.

---

## 5. The store and economy teardown

From the public page and a few sessions:
- **Price ladder**: list every pass and product by price. Where are the anchors? Is there a cheap entry product?
- **What is sold**: convenience (speed, auto), power (damage, luck), cosmetics, access (zones, VIP), randomness (paid random items).
- **Value framing**: "best value" tags, bundles, first-purchase discounts.
- **Where prompts appear**: in context (out of lives, rare moment) or as interruptions.
- **Odds disclosure** for paid random items: shown before purchase, as numbers? Roblox requires numeric odds disclosed before purchase and that every outcome provides some benefit (Community Standards). A competitor not doing this is not a model to follow.

Then compare with your own store: are you asking a higher price for a weaker benefit? Do you have no cheap entry point while all peers do? See [[Pricing and Store Design]] and [[Paid Random Items and Odds Disclosure in Practice]].

---

## 6. Tracking over time

A single teardown is a snapshot. A weekly log over two months is a model of how the game is run.

| Week | CCU trend (approx) | Update? | Event? | New passes/products | Thumbnail change | Notes |
|---|---|---|---|---|---|---|
| 1 | Flat, weekend +30% | No | Weekend 2x | None | No | |
| 2 | Spike Sat | Yes, new zone | Launch event | New 2x luck pass | New variant | Update notes list a nerf |
| 3 | Decay | No | None | None | No | |

From this you learn their cadence, how big their spikes are, whether new content or events drive them, and when they tend to release. Use it to place your own updates where you are not fighting the genre leader's release weekend.

Keep it lightweight: 15 minutes a week across all tracked games. If it takes longer, track fewer games.

---

## 7. Turning analysis into decisions

The output of competitor analysis is not a report. It is three to five decisions:

1. **Table stakes**: things every game in the genre does that you do not, and that players will expect (a codes button, a daily reward, an auto mode). These go into the backlog.
2. **Gaps you can own**: things players complain about in the leaders, or that no game does. These are your positioning ([[Planning and Scoping a Roblox Game]]).
3. **First-minute fixes** from the stopwatch table.
4. **Price and store adjustments** within your own economy maths, not copied prices ([[Economy Inflation Sinks and Faucets Math]]).
5. **Timing**: release days to avoid or use.

Test the risky ones rather than adopting them blindly ([[A-B Testing and Experiments on Roblox]]). A leader's feature may work because of its audience, and fail in yours.

### Worked example
A small team building a tower-defence game ([[Genre Playbook - Tower Defense]]) studies two leaders and three peers. Findings:
- All leaders let players place a tower within 15 seconds; theirs requires a 90-second lobby and loadout screen. **Decision:** new players drop straight into a short first match with a default loadout.
- Peers that launched recently all have a cheap entry product; theirs starts at a high price. **Decision:** add a low-price starter offer shown after the first win.
- Players of both leaders complain that co-op matchmaking leaves them with strangers who quit. **Gap:** a party-first design with rewards for finishing with friends ([[Social Design and Multiplayer Play]]).
- The genre leader releases on the first Saturday of the month. **Timing:** ship on mid-month weekends.

None of these copies a feature, an asset or a name. They are expectations, gaps and timing.

---

## 8. The lines you do not cross

| Action | Status | Why it backfires |
|---|---|---|
| Copying another game's assets, maps, UI art, music or code | Copyright infringement; takedowns; Roblox may remove infringing content | Removal, account risk, and your game is a weaker copy anyway |
| A title, icon or thumbnail confusingly similar to another game | "Repetitive and Misleading Content" covers misleading metadata and content confusingly similar to other creators' work (Community Standards) | Players who wanted the original feel tricked and bounce; reports |
| Using another game's name in your title or description for search | Misleading metadata; search is semantic and favours accurate descriptions | Wrong audience, high bounce |
| Mass-reporting or review-bombing a competitor | False reports and "flooding games or groups to harm their reputation" are prohibited under Misusing Roblox Systems (Community Standards) | Moderation action against your accounts; it is also simply wrong |
| Exploiting or decompiling a competitor's game | Against Roblox Terms of Use | Account bans; legal risk |
| Recruiting a competitor's staff to bring their code or assets | IP and contract issues | Legal risk; see [[Legal Basics - IP Licenses and Assets]] |
| Impersonating a competitor's team or community | Impersonation that may damage reputation is prohibited (Community Standards) | Bans; community backlash |

Mechanics and genre conventions (a tower placement grid, rolling for rarities, a daily reward) are not owned by anyone and are fair to use. Specific expression (art, code, music, a distinctive name and logo) is.

---

## 9. Common mistakes
- Studying only the genre leader and copying its scale.
- Reading a competitor's success into one feature while ignoring their years of content and audience.
- Using an old account with progress or personalisation, so the first session is not representative.
- Filling in the template from memory after playing.
- Treating third-party revenue estimates as facts.
- Producing a long report with no decisions.
- Copying prices without your own economy maths.

## 10. Checklist
- [ ] Three tiers chosen: 1 to 2 leaders, 2 to 4 peers, 1 to 2 adjacent
- [ ] Watchlist set up in Creator Hub (up to nine games)
- [ ] Teardown template filled in live, on phone and PC, fresh account
- [ ] Stopwatch table comparing the first minute with your game
- [ ] Store teardown: price ladder, what is sold, prompt placement, odds disclosure
- [ ] Weekly tracking log, 15 minutes
- [ ] Three to five decisions out, risky ones queued as experiments
- [ ] No copied assets, names, art or code; no misleading similarity

## See also
[[Marketing and Growth Start Here]] · [[Planning and Scoping a Roblox Game]] · [[Discovery and the Algorithm]] · [[Pricing and Store Design]] · [[Simulator and RNG Genre Teardown]] · [[First-Time User Experience and Onboarding]] · [[Analytics and Funnels]] · [[A-B Testing and Experiments on Roblox]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Launch Strategy - The First Two Weeks]] · [[Click-Through Rate]] · [[Update Cadence and Hype Cycles]] · [[Monetization Overview]] · [[Top Games Case Studies Start Here]] · [[Core Loop]]
<!-- auto-links:end -->
