# Trend Games on Roblox (2025-2026): Design, Production, Discovery, Monetization, Rules

Research module for a Claude Code plugin for Roblox developers. Compiled 2026-10-28.

## How to read this module

Every claim is labeled:

- **[Roblox docs]**: Roblox Creator Hub docs, DevForum staff announcements, Roblox newsroom, Community Standards, or SEC filings / shareholder letters.
- **[Reported (source, date)]**: press, tracker sites, analysts, developer interviews. Third-party trackers (Rolimon's, RoMonitor, RoWatcher, RBLXSTAT, profitable.app and similar) **estimate**. Roblox does not publish per-game revenue.
- **[Expert practice (source)]**: what experienced developers or analysts recommend or do.
- **[Unverified]**: a single low-authority source, a self-reported claim, or conflicting figures.
- **[Derived]**: arithmetic done here from labeled inputs.

If a number is not public, the module says so instead of estimating it. Several important numbers (per-game revenue, payer conversion, "good" retention) **are not published by Roblox**. Treat every third-party figure as a range, not a fact.

The platform changed a lot between mid-2025 and late 2026: age checks for chat, Roblox Kids/Select accounts, a new-game evaluation gate for under-16 audiences, two discovery algorithm rewrites, and stricter paid-random-item rules. **A playbook copied from the summer-2025 boom will not work unchanged in late 2026.** Section 0 explains why.

---

## Executive summary (the 12 things that matter most)

1. **The template is repeatable. Winning is not.** The 2025-2026 megahits share one skeleton: collect units that earn passive income, upgrade a personal base or plot, add rarity, mutations and luck, put everything on a shared server where others can see (and often steal or trade) your stuff, and run weekly timed events. Grow a Garden (Mar 2025), Steal a Brainrot (May 2025), Escape Tsunami for Brainrots (Dec 2025) and Steal An Egg (Jul 2026) all fit it. [Reported, see §1]
2. **Hits came from tiny teams, then got scaled by operators.** Grow a Garden's first version was built in "a few days" by a 16-year-old. Splitting Point Studios partnered when it had ~500-1,000 CCU, put ~12 staff on it, and shipped weekly updates. It reached ~100k CCU in about two weeks and ~1M CCU in about a month. [Reported (GamesBeat, 2025-09-07; GameDiscoverCo, 2025-05-27)]
3. **Peaks are spectacular and decay is brutal.** Steal a Brainrot peaked at ~25.4-25.8M CCU (Oct 2025) and was later reported ~99% below peak. Escape Tsunami went from ~5M peak (Jan 2026) to ~164k. [Reported (RoWatcher, ~Mar 2026)] The audience is loyal to the *genre loop*, not to any one game.
4. **Discovery now rewards long-term retention plus spend, not clicks.** In June 2026, Recommended For You (RFY) moved from 7-day to 28-day signals (D1, D2-7, D8-28) and added first-play bounce rate as a top signal. In August 2026, Home was tuned to reward games strong in *both* retention and monetization. Playtime benefit is capped at 60 min per user per game per day. [Roblox docs]
5. **New games no longer reach kids on day one.** Since the June 2026 global rollout, a new game reaches only age-checked 16+ users until it passes evaluation: 250 unique plays by "highly engaged" age-checked users within 60 days, plus verified creator, 2-Step Verification, a maturity label, and a refundable fee or subscription. [Roblox docs] For a genre whose core audience is 9-15, **this is the biggest change to the 2025 playbook.**
6. **Paid luck is regulated.** Since 2026-05-26, luck boosts, pity systems, eggs, crates, spins and bundles containing randomness must show numerical odds that sum to 100% before purchase. Boosted odds must update live, every outcome must give value, and players must be gated with `PolicyService` (`ArePaidRandomItemsRestricted`, `IsPaidItemTradingAllowed`). Violations can mean game removal and account suspension. [Roblox docs]
7. **Copying a game wholesale is both deprioritized and litigated.** Roblox deprioritizes games whose "metadata and place files closely resemble existing games." [Roblox docs] Steal a Brainrot's owners filed at least four lawsuits against imitators from Nov 2025, claiming copyright in UI layout, art and overall aesthetic, but not in the meme characters. [Reported (Bloomberg, 2026-03-24)] Mechanics are generally not copyrightable. Copying UI and art is the risk.
8. **Meme characters carry IP risk.** Steal a Brainrot pulled Tung Tung Tung Sahur in Sept 2025 during a licensing dispute and restored it in Nov 2025. [Reported (Wikipedia, 2025-26)]
9. **Revenue is real but opaque.** Bloomberg/RoMonitor estimated Steal a Brainrot at ~$64M in player spend from May 2025 to Mar 2026. Other trackers put developer take at $1.4M-$4.4M per month in late 2026. [Reported] No official per-game revenue exists. Roblox paid creators $1.5B in 2025. [Reported (Bloomberg/Naavik)]
10. **AI is mainstream in production, and the bar moved up.** 44% of the top 1,000 creators used Roblox Assistant or third-party AI via MCP (Mar-Apr 2026). [Roblox docs (newsroom)] Studio has a built-in MCP server that works with Claude. Unguided AI output looks generic: gray baseplate, corner text UI, unstyled shop button. Players spot it fast. [Reported (Altitude DP, 2026-09-04)]
11. **Live ops is the moat.** Weekly Saturday updates, "admin abuse" events, countdowns, rotating shop stock and limited units drive repeat visits and record spikes. The Aug 23, 2025 "admin war" helped push the platform to 47.4M concurrent users. [Reported]
12. **The macro tailwind faded.** DAU went from 151.5M (Q3 2025) to 123M (Q2 2026). Q3 2026 bookings were guided down 14-18% YoY. Roblox attributed this partly to engagement shifting away from the high-monetizing 2025 viral games and to the retention-weighted algorithm. [Roblox docs (shareholder letters) / Reported (Investing.com transcript)] A short-seller report estimates safety changes cut social game spread ~50% YoY. [Unverified (Bleecker Street Research, short position, 2026-10-27)]

---

## 0. Platform context you must account for (2025 to late 2026)

| Date | Change | Impact on trend games | Label |
|---|---|---|---|
| 2025-03-31 | RFY uses qPTR + 7-day playtime, play days, spend days, Robux spent, intentional co-play days; playtime benefit capped at first 60 min/day/user/game | Session length past 60 min stops helping discovery; returning daily matters more | Roblox docs |
| 2025-07-24 | Creator Rewards: 5 Robux per Active Spender who plays 10+ min and whose first-three games that day include yours; 35% share of first $100 spend of new/reactivated users you bring (60 days) | Bringing new users via share links pays | Roblox docs |
| 2025-08-23 | Grow a Garden vs Steal a Brainrot "admin war"; platform record 47.4M CCU | Proof of event-driven spikes | Reported (Wikipedia; Naavik) |
| 2025-09-05 | DevEx $0.0035 → $0.0038 per Robux | | Reported (multiple) |
| 2025-09-30 | Unrated experiences (no Maturity & Compliance questionnaire) became unplayable | Questionnaire is mandatory | Reported (DevForum/press) |
| 2025-10-30 | Q3 2025: 151.5M DAU (+70% YoY), bookings $1.92B (+70%) | Peak of the boom | Roblox docs (shareholder letter) |
| Jan 2026 | Facial age check required to chat, globally; chat limited to similar age bands | Weaker word-of-mouth inside servers; trading/social coordination harder | Roblox docs (newsroom) |
| 2026-03-17 / 03-31 | Paid random items disallowed for Brazilian users under 18, then for unverified 18+ | Region gating via PolicyService is mandatory | Reported (Bloxy News on X) |
| 2026-04-15 | Studio "goes agentic": Planning Mode, playtest agent, built-in MCP server (Claude, Cursor, Codex) | AI-assisted builds are the norm | Roblox docs (newsroom) |
| 2026-05-26 | Paid Random Items clarification: numerical odds summing to 100%, luck boosts are probability modifiers, bundles count, PolicyService for trading | Every egg/luck monetization must be redone to spec | Roblox docs |
| 2026-06 (global) | Roblox Kids (5-8) / Select (9-15) accounts; new games evaluated before reaching under-16s | Trend games can't instantly reach their core audience | Roblox docs |
| 2026-06-08 | 18+ spend in "novel" R15 games pays $0.005396/Robux DevEx | Roblox is steering money toward novel, older-skewing games, not trend clones | Reported (Tubefilter, 2026-05-01) |
| 2026-06-15 | RFY switches to 28-day windows; qPTR replaced by play-through rate + first-play bounce rate | Hook in the first 60-180 s; retention to D28 matters | Roblox docs |
| 2026-08-06 → 08-20 | Home recommendations reward games strong in retention **and** monetization | Fair, progression-tied monetization helps reach | Roblox docs |
| 2026-08-19 | Bot account enforcement wave; known bot engagement excluded from RFY | Botted CCU buys nothing in discovery | Roblox docs |

Macro numbers:
- DAU: 151.5M (Q3 2025) → 144M (Q4 2025) → 132M (Q1 2026) → 123M (Q2 2026, +10% YoY). [Roblox docs (shareholder letters) / Reported]
- Q2 2026: hours engaged 29B (+5% YoY), bookings ~$1.6B (+8%). Q3 2026 bookings guided $1.58-1.65B (−14% to −18% YoY). Management cited engagement shifting "from high-monetizing 2025 viral games toward newer and evergreen games" plus the retention-weighted algorithm. [Reported (Investing.com transcript, 2026-07-30); Roblox docs (Q2 2026 letter)]
- Top 10 games ≈ 20% of hours, versus 30% three years earlier. [Roblox docs (Q2 2026 letter, via search summary)]
- New Roblox experiences: ~2,000 launched per day, and ~1 in 50,000 reached the Top 10 by spend for at least a day over the year. [Reported (GameDiscoverCo, 2025-05-27)] Roblox said in 2022 that creators published 60,000+ experiences daily. "Published" and "launched publicly" differ, which explains the gap. [Reported (Altitude DP citing Roblox 2022)]

---

## 1. Anatomy of the top trend games

### 1.1 Case files

**Grow a Garden** (released 2025-03-26)
- Origin: built in "a few days" by a 16-year-old (BMWLux). Splitting Point Studios (Janzen "Jandel" Madsen, NZ, ~19 devs) partnered at ~500-1,000 CCU and 10-20k DAU. ~12 staff were assigned, with weekly updates. Do Big Studios is a minority partner. [Reported (GamesBeat 2025-09-07; GameDiscoverCo 2025-05-27; Wikipedia)]
- Growth: ~100k CCU in ~2 weeks, ~1M CCU in ~1 month. Then 5M (May 18), 11.7M (May 31), 16M (Jun 14), 21.3M (Jun 21; fell to 7.6M within an hour), 22.3M (Aug 23, admin war). Average ~2.7M CCU (Jun 25). [Reported (Wikipedia; Calcalist 2025-07-13)]
- Loop: buy seeds with soft currency (Sheckles) → plant → crops **grow while offline** → harvest/sell → buy rarer seeds. Rotating shop stock, mutations (weather-driven, server-synced), pets from eggs, weekly exclusive items you must be online to claim. Robux buys speed-ups, perks and stealing crops. [Reported (Wikipedia; Calcalist; guides)]
- Why it spread: universal theme, offline growth (a reason to come back), non-competitive loop, near-zero tutorial, shared world where players chat and gift fruit to newcomers. [Reported (GameDiscoverCo; GamesBeat)]
- Trading: before Aug 2025 only gifting existed, which enabled scams. Patch 1.17.0 (2025-08-02) added a Trading Ticket system. [Reported (Sportskeeda/ginx guides)]
- Monetization examples: Season Pass premium 749 Robux; skip 49 Robux/level or 1,699 all; Exotic Cosmetic Crate 199/575/1,699 Robux for 1/3/10. [Reported (Sportskeeda/Beebom guides; prices change)]
- Revenue: "an estimated $12M" in May 2025 alone. [Unverified (Calcalist 2025-07-13; original source unclear)] "At least $148M profit in eight months." [Unverified (LinkedIn post cited by Tubefilter 2026-03-09)] Late-2026 trackers: ~$0.5-1.75M/month. [Reported (bloxprices, rowatcher; model-based)]
- Underground economy: rare pets resold for real money on Discord/eBay (one polar bear pet reportedly >$200). This violates Roblox rules. [Reported (Calcalist)]
- Bot allegation: TD Cowen alleged bot inflation (account spikes in PH/ID), then retracted the manipulation claim. Roblox said popularity was genuine. [Reported (Wikipedia)]

**Steal a Brainrot** (released 2025-05-16)
- Origin: SpyderSammy (Sam Brakta) acquired the rights to *Steal a Character* and improved it. Owned/operated with DoBig Studios / Spyder Games. [Reported (Bloomberg 2026-03-24; Wikipedia)] Analyst Jacob Navok said Steal a Brainrot and Grow a Garden "were made by teams of three people" and cited "$50m+" revenue in Steal a Brainrot's first month. [Unverified (X post, ~2025-11)]
- CCU: 5M (Jul 2025), 20M (Aug 2025, above Fortnite's 15.3M record), 24M (Sep 13 "Extinct Event"), 25.4M or 25.8M (Oct 11 2025, sources differ), 12.8M (Jan 2026 Bruno Mars concert). ~90-215k by 2026. [Reported (Wikipedia; RoWatcher; greyjournal)]
- Loop: brainrot units walk a conveyor ("red carpet"). Buy them with cash, place them in base slots, and they generate cash per second. **Steal** from other players' bases (carrying slows you, disables items, alerts the owner, and one hit returns the unit). Defend with a timed base lock (~60 s, +10 s per rebirth per guides). Rebirth resets cash and units for a multiplier, more slots, a longer lock and shop unlocks. Traits/mutations (Gold, Diamond, Rainbow, Galactic) multiply income massively. Lucky blocks. Multi-player "rituals" summon secret units. [Reported (Wikipedia; Beebom 2025-12-31; allthings.how/Deltia guides)]
- Why it spread: legible rules, visible permanent stakes (losing a unit), chaos that produces clips, admin events. Lead dev built community via Discord, YouTube and admin abuse. [Reported (Beebom; Naavik 2026)]
- Monetization: gear for soft currency or Robux. Reported passes: 2x Money (119-299 Robux across sources), VIP (199-499), Admin Panel (1,999-4,999). Polygon called it pay-to-win, "best items only available for cash." [Reported (guides, conflicting); Wikipedia citing Polygon]
- Revenue: ~$64M player spend May 2025-Mar 2026. [Reported (Bloomberg/RoMonitor 2026-03-24)] Late 2026 developer take ~$1.43M/month (RoWatcher) to $4.4M/month (profitable.app). The $11M/month Aug 2025 figure has no disclosed method. [Reported (greyjournal 2026-10-18)]
- Legal: Tung Tung Tung Sahur removed Sept 2025 during a licensing dispute with the meme's creator/agent, restored 2025-11-29. Spyder sued a Fortnite copycat (Oct 2025). At least four suits against imitators since Nov 2025, including a claim of ≥$1.8M statutory damages against a site hosting 12 near-identical versions. [Reported (Wikipedia; Bloomberg)]
- Cheating: widespread automation scripts for cash collection and stealing. [Reported (GameRant via Wikipedia)]

**99 Nights in the Forest** (Grandma's Favourite Games, 3 people, Auckland)
- Survival-horror co-op, not a "steal" loop. 14.15M all-time peak CCU (2025-10-04). 29.5B visits by Sept 2026. Film adaptation at 20th Century Studios. [Reported (Rolimon's; PCGamesN 2026-09-12; Variety)]
- The team says it uses human artists and "will continue to avoid AI." [Reported (PCGamesN 2026-09-12)] This shows a trend-scale hit does not require the brainrot template.

**Escape Tsunami for Brainrots** (created 2025-12-15, dev listed as sc7ry, who also made Steal a Character)
- Brainrot collection + "escape the wave" hazard (inspired by Steal a Brainrot and Be Crushed by a Speeding Wall). 40M+ visits Sat-Mon within its first month. Peak ~4.996M CCU (2026-01-24). Briefly #1 over Steal a Brainrot in Jan 2026. Later ~164k (Mar 2026) and down 65% over 30 days on another tracker. [Reported (Rolimon's; Sherwood 2026-01-13; RoWatcher)]
- Reached ~5M CCU about six weeks after creation. [Derived]

**Plants vs Brainrots** (released ~2025-08-01, Yo Gurt Studio)
- Grow-a-Garden-style planting fused with brainrot tower-defense units. Reported ~9M CCU weekend spike, 0.5M weekday / 1M+ update-day typical. [Reported (games.gg; Sportskeeda), conflicting]

**Steal An Egg** (released 2026-07-25)
- Steal and hatch eggs, pets earn money, upgrade base/treadmill, others can steal from you. Peak ~14.3M CCU (2026-09-19). 6B visits in Q3 2026. Avg session ~16 min. ~0.7-1.25M CCU late Oct 2026. Misfits Gaming portfolio. [Reported (RoStats; Adellion 2026-10-02; Misfits on X 2026-08-21)]
- It drew ~20 percentage points fewer *new* accounts than 2025 hits and decayed faster than the median hit. [Unverified (Bleecker Street Research, short seller, 2026-10-27)]

**Other 2026 trend data points** [Reported (Adellion 2026-10-02 snapshot)]
- Ride A Pet (2026-04-14): pet-as-mount, radar finds eggs, hatch, mutations, rebirths. 1.42M 30-day peak, 15-min avg session.
- Karinderya!: ~295k peak in late Sept 2026, under 10k days later.
- +1 Loot To Forge: ~104k peak at 7 weeks old.
- The Forge: 1.05M (Dec 2025) → 3.2k (Oct 2026).
- Fisch (solo dev, ~4 months build, Oct 2024): still ~439k 30-day peak, 29-min sessions. A longer-lived "trend-adjacent" hit.

**"+1 [stat] every second"**: the format (+1 speed/jump/strength per second, often obby-shaped) dates back to at least 2022-2024 per tracker listings and was amplified by YouTubers. [Reported (rotrends listings); Unverified (Gistly 2025-03)]

### 1.2 The common skeleton

| Layer | Pattern | Seen in |
|---|---|---|
| Core verb | One verb a 7-year-old understands in <10 s: grow, steal, dig, fish, run, hatch | All |
| Economy | Soft currency per second from owned units/plants → buy better units | GaG, SaB, Steal An Egg, PvB |
| Rarity | 6-9 tiers (Common → Secret/Godly), plus multiplicative **mutations/traits** (Gold, Diamond, Rainbow, Galactic) | SaB, GaG, Ride A Pet |
| Luck | Server or event "luck" raising mutation/rare odds; paid luck boosts | GaG weather, SaB events |
| Scarcity clock | Shop restock timers (GaG seed/gear shop ~5 min per guides), limited-time units, weekly exclusives | GaG, SaB |
| Base/plot | Personal visible plot on a shared server; slots expand with rebirth | All |
| Social pressure | Others can see, **steal**, gift or trade your stuff; base lock creates defense tension | SaB, Steal An Egg, GaG (Robux steal) |
| Prestige | Rebirth: reset for multiplier, slots, unlocks | SaB, Ride A Pet |
| Offline/return hook | Offline growth or earnings; timed restocks | GaG, Restaurant Tycoon 3 |
| Events | Weekly update + admin abuse, weather, cross-game crossovers, concerts | GaG, SaB |

[Derived from the case files above]

**Session design.** Reported average sessions for current trend hits are short: 15-16 min (Ride A Pet, Steal An Egg), versus 25-31 min for longer-lived sims (Fisch, Restaurant Tycoon 3, Bee Swarm) and 111 min for Pet Simulator 99. [Reported (Adellion 2026-10-02)] RFY only credits the first 60 min/user/day [Roblox docs], so the goal is **several short daily returns** (restock timers, offline earnings, daily rewards), not marathon sessions. [Derived]

**Why they spread.**
- Word of mouth via YouTube/TikTok is the main engine of mega-hits, and "a single video can catapult an experience to millions of CCU." [Expert practice (Naavik, State of UGC 2026)]
- Clip-able chaos (steals, admin abuse, black holes) becomes content. [Reported (Beebom 2025-12-31)]
- YouTubers profit too: KreekCraft said Steal a Brainrot content earned him >$1M through ads, sponsors and donations. [Reported (Dexerto 2026-01-20; self-reported)]
- Shared servers enable gifting and newcomer help. [Reported (GameDiscoverCo)]
- Rivalry and crossover events. [Reported]
- Since Jan 2026, chat age bands reduce in-game social spread. [Roblox docs (newsroom)] A short seller estimates ~50% lower social spread, and one developer reportedly said chat limits changed their "intro path." [Unverified (BSR 2026-10-27)]

**Meme IP.** "Italian brainrot" characters are AI-generated meme creatures from early 2025. Google interest in "brainrot memes" peaked May 2025, and the Italian Brainrot creators declared it "dead" in Dec 2025. [Reported (Bloomberg; RoWatcher)] Bloomberg reports the Steal a Brainrot complaints describe the characters as AI-generated memes not protected by copyright, while a licensing agency (Mementum Lab) asserted rights to Tung Tung Sahur. **Ownership of individual meme characters is legally contested. Design original characters "in the style of" instead of copying named ones.** [Reported + Expert practice (Odin Law quote in Bloomberg)]

---

## 2. Trend cycle

### 2.1 Timeline of the cycle (2025-2026)

| Launch | Game | Peak CCU (date) | Time to peak | Label |
|---|---|---|---|---|
| 2024-10 | Fisch | 1.27M (2025-10) | long tail | Reported |
| 2025-03-04 (approx.) | 99 Nights in the Forest | 14.15M (2025-10-04) | ~7 months | Reported |
| 2025-03-26 | Grow a Garden | 22.3M (2025-08-23) | ~5 months; 1M in ~1 month | Reported |
| 2025-05-16 | Steal a Brainrot | 25.4-25.8M (2025-10-11) | ~5 months; 5M by July | Reported |
| 2025-08-01 | Plants vs Brainrots | ~9M spike (claimed) | weeks | Unverified |
| 2025-12-15 | Escape Tsunami for Brainrots | 4.996M (2026-01-24) | ~6 weeks | Reported |
| 2026-02-18 | Swing Obby for Brainrots | ~87k | weeks | Reported |
| 2026-04-14 | Ride A Pet | 1.42M (late Sep 2026) | ~5 months | Reported |
| 2026-07-25 | Steal An Egg | ~14.3M (2026-09-19) | ~8 weeks | Reported |

### 2.2 How fast clones appear and how long a trend lives

- Clone volume: "hundreds of competing titles" (Cut Grass for Brainrots, Survive LAVA for Brainrots, Grow a Beanstalk for Brainrots), "with more released daily," plus knockoffs on Fortnite and Horizon Worlds. [Reported (Bloomberg 2026-03-24)]
- Speed: one team self-reports making 1,000,000+ Robux in <72 h with an AI-built "modded version of an already popular game," and says the market was saturated, with players split across many brainrot games so none hit 1M CCU. [Unverified (developer post on X, 2026)] Sail For Brainrots (KreekCraft + team of 6) soft-launched 2026-02-05 and earned "tens of thousands of dollars within a few weeks." [Reported (Bloomberg; Roblox wiki)]
- Typical shape: viral launch → sharp decline → stabilization at a few percent of peak. Each new peak is lower, and new entrants pull players from older titles. "Games that stop updating decline within weeks." [Reported (RoWatcher ~2026-03)]
- Decline data: Grow a Garden fell out of the Newzoo top 10 by Dec 2025. Steal a Brainrot lost ~30% of monthly visits from its Aug peak by Dec. The largest title's share of top-10 visits rose from 22% (Q1'25) to 43% (Q4'25), so winners take more. [Reported (Newzoo via GameDev Reports; Naavik)] Escape Tsunami "left Roblox's charts within seven months." [Unverified (BSR)]
- In some subgenres, the top two games control >80% of revenue. [Reported (RoWatcher, Q1 2026; method not disclosed)]
- Time-to-market window: **no source publishes a measured window.** From the data: (a) the originals took 5-8 weeks to go from launch to multi-million CCU; (b) derivative "X for Brainrots" games launched within weeks to months of the originals and kept appearing 9+ months later; (c) single follower titles that weren't #1 or #2 had peaks one to two orders of magnitude lower. A fast-follow therefore makes sense **in the first ~2-6 weeks of a trend's visible rise, and only with a clear twist.** After the original's peak, compete on a *new verb* inside the genre, not a reskin. [Derived; treat as an inference]

### 2.3 How to spot the next trend

| Signal | Where | Notes | Label |
|---|---|---|---|
| Hourly CCU surges | rblxdb updates tracker (flags ≥3σ above peers and ≥15% own growth), RoMonitor, Rolimon's game pages, RTrack, RBLXSTAT, RoWatcher, profitable.app | Third-party; cross-check | Reported (lensblox 2026; rblxdb) |
| Visits spikes over a weekend | RoMonitor | Escape Tsunami was flagged at 40M+ visits Sat-Mon in its first month | Reported (Sherwood 2026-01-13) |
| Big YouTubers/TikTokers covering a game | YouTube, TikTok, Instagram Reels | Main virality engine per Naavik | Expert practice (Naavik) |
| Meme velocity | Google Trends, TikTok sounds | Brainrot meme interest peaked May 2025, before the game peaks | Reported (RoWatcher) |
| Sell-side analysts naming a game | BMO, Morgan Stanley, JPMorgan notes | Lagging but confirms scale | Reported (Sherwood) |
| Approval + avg session in tracker | Adellion-style snapshots | High approval (≥90%) with 25-30 min sessions predicts longevity better than spike size | Expert practice (Adellion 2026-10-02) |
| Your own Similar Experiences list | Creator Analytics > Acquisition > Home Recommendations shows similar experiences | Shows what the algorithm groups you with | Roblox docs |

**"Is it dead?" heuristics** [Derived from the data above; not a published rule]
- The original's 30-day peak is below ~10% of its all-time peak, and new entrants peak lower each time.
- The meme source has been declared over or Google Trends is in long decline.
- Clones with no twist can't clear a few thousand CCU.
- Even then, the **genre loop often survives as a stable genre** (RoWatcher's "normalizing, not dying"). Steal → Steal An Egg (Jul 2026) shows the loop being re-skinned successfully a year later.

---

## 3. Production playbook

### 3.1 Team sizes and timelines (reported)

| Game | Initial build | Team | Label |
|---|---|---|---|
| Grow a Garden v1 | "a few days" | 1 (teen) → ~12 staff after partnering | Reported (GamesBeat, Calcalist) |
| Steal a Brainrot | derived from acquired Steal a Character | "team of three" | Unverified (Navok on X) |
| 99 Nights in the Forest | not disclosed | 3 | Reported (PCGamesN) |
| Fisch | ~4 months | solo | Reported (Adellion) |
| Sail For Brainrots | not disclosed | KreekCraft + 6 | Reported (Roblox wiki) |
| AI-remix brainrot game | not disclosed, "made with AI" | small | Unverified (X post) |

Roblox's CEO said the next Grow a Garden will be "developed within a weekend." [Reported (Naavik quoting Baszucki)] Bloomberg notes Roblox games "can take just a few months to develop." [Reported (Bloomberg 2026-03-24)]

The operator model: studios (Splitting Point, DoBig, Misfits) acquire or partner with early viral games at ~500-1,000 CCU, then add live ops, scaling and monetization. [Reported (GameDiscoverCo; Wikipedia)] **A solo dev's realistic path is to launch, prove retention, then iterate fast or partner.**

### 3.2 Minimum launchable feature set (MVP for a 2026 trend game)

Must-have at launch [Derived from the case files plus Roblox docs requirements]:
1. **One core verb with juice.** Readable in 10 s, with feedback on every action: sound, particle, number pop, camera nudge.
2. **Passive income units + base/plot** with visible slots and per-second earnings text.
3. **Rarity ladder** (6-9 tiers) + **1-3 mutation multipliers**, data-driven from one config module.
4. **Shop with restock timer** (visible countdown) and a weighted stock table.
5. **Social interaction on a shared server**: steal (with lock/defense), gift, or trade. Trade must be server-authoritative and PolicyService-gated if paid items are tradable.
6. **Rebirth** (reset for multiplier and slots).
7. **Saving**: session-locked DataStore with retries, autosave, BindToClose. Duped or lost units kill trust and invite exploiters.
8. **Onboarding in <60 s**: arrow/beam to first action, first purchase within ~30 s. RFY's first-play bounce windows are <60 s and 61-180 s. [Roblox docs]
9. **Monetization set** (§5): 2-4 gamepasses, 3-6 developer products, a paid-luck item **with odds UI**, all PolicyService-gated.
10. **Daily return hooks**: offline earnings, daily reward, timed restock, next-event countdown.
11. **Mobile-first UI**: big thumb-reachable buttons, safe-area aware. ~80% of DAU played on mobile in 2024. [Reported (Roblox annual report via PocketGamer.biz)]
12. **Anti-exploit basics**: server-owned currency, rate-limited remotes, server-validated steal distance and timing. Automation scripts were endemic in Steal a Brainrot. [Reported]
13. **Metadata**: original title and art, a custom thumbnail (required for Home eligibility), 3-5 thumbnails for personalization, a 512×512 icon readable at ~150 px. [Roblox docs]
14. **Compliance**: Maturity & Compliance questionnaire (required to be playable), odds disclosure, Kids/Select readiness (§8).

Can wait until week 2+: trading UI polish, leaderboards beyond one, quests, codes system, seasonal pass, cosmetics crates, friends bonuses, cross-server events via MessagingService.

### 3.3 What to template (build once, reskin per trend)

| Module | Templatable? | Notes |
|---|---|---|
| Data layer (profile/session lock, migrations, receipts) | Yes, 100% | Never regenerate per game |
| Economy config (units, rarities, mutation multipliers, prices) | Yes, as data | One ModuleScript/table; balance via spreadsheet |
| Weighted random + luck system with **live odds display** | Yes | Must emit disclosure text from the same table it rolls from |
| Shop + restock scheduler (server clock, global seed via MessagingService or time-sliced deterministic seed) | Yes | All servers show the same stock at the same time, which makes it a shared event |
| Base/plot assignment, slots, per-second income | Yes | |
| Steal/lock/carry state machine | Yes | Server-authoritative |
| Rebirth | Yes | |
| Monetization (passes, products, ProcessReceipt idempotency, PolicyService gating) | Yes | |
| UI kit (HUD, shop, inventory, odds panel, rebirth, daily, codes, settings) | Yes, reskin | Cartoon/simulator style |
| Event framework (timed events, admin commands, server luck multipliers, countdown) | Yes | |
| Analytics events (funnel, economy sources/sinks, custom events) | Yes | |
| Theme: characters, map, VFX, audio, names, thumbnails | **No: this is the twist** | Where AI helps most and where originality is required |

**Do not take kits from the Toolbox blindly.** A Dec 2025 DevForum tutorial series sells a "complete Steal a Brainrot kit." [Reported (DevForum 2025-12-09)] Free models are the most common source of backdoors (look for `require(` with asset IDs and obfuscated code). [Reported (DevForum; Roblox wiki)] Roblox also deprioritizes place files that closely resemble existing games. [Roblox docs]

### 3.4 How developers use AI today

- **Code/agentic building**: Studio has a built-in MCP server, and Roblox names Claude, Cursor and Codex as compatible. The Assistant has a Planning Mode (analyzes code and data model, asks questions, produces an editable plan) and a Playtest Agent beta (drives the character as automated QA and feeds results back). 44% of the top 1,000 creators used Assistant or MCP tools (Mar 6-Apr 7, 2026). [Roblox docs (newsroom 2026-04-15)] BYOK lets Assistant connect to external LLMs. [Reported (Baszucki on X, 2026-02-21)]
- **3D**: Cube-based text-to-mesh generation in Studio; "4D" (interactive objects) open beta Feb 2026; procedural models "coming soon." [Roblox docs (newsroom); Reported (TNW)]
- **Text-to-game for players**: "Build" in the mobile app (public alpha 2026-07-28, NZ first). Roblox says its discovery "is designed to highlight games with long-term retention, which doesn't include AI slop." [Reported (TechCrunch 2026-07-16)]
- **Thumbnails/icons**: many creators use ChatGPT or Midjourney then fix text by hand, and vendors sell AI thumbnail services. **No independent evidence that AI thumbnails raise CTR.** [Reported (vendor sites); Unverified CTR claims]
- **Meme characters themselves** were AI-generated imagery (Italian brainrot). [Reported (Bloomberg)]
- **Counter-example**: the 99 Nights team avoids AI and uses human artists. [Reported]
- Estimate that ~30% of upcoming Roblox games are "AI slop." [Unverified (author's own estimate, Altitude DP 2026-09-04)]

### 3.5 What AI does badly (and where the human must stay in the loop)

| Failure | Evidence | Mitigation |
|---|---|---|
| Generic defaults: gray baseplate, floating corner text UI, unstyled shop button, generic particles; players spot it "within seconds" | Reported (Altitude DP) | Give the AI a style guide, UI kit and VFX library; review screenshots every iteration |
| Weak overall architecture and insecure multiplayer logic | Reported (SoonLab guide) | Templated server-authoritative modules; security review of every RemoteEvent |
| Economy tuning (it can write the code, not feel the curve) | Expert practice (Altitude DP: "a tuned economy" is what slop lacks) | Spreadsheet model: time-to-next-unit, income doubling time, rebirth cadence; playtest |
| Small design decisions (custom health bar, near-death sound cue) | Reported (Altitude DP) | A juice checklist (§7) |
| Compliance blind spots (odds disclosure, PolicyService, receipt idempotency) | Derived | Compliance module/checklist; never let generated code roll paid randomness without the disclosure path |
| IP contamination (asked for "Tung Tung Sahur" it will copy a contested character) | Reported (IP disputes) | Original characters only |
| Data loss and dupes in generated DataStore code | Expert practice | Use a vetted profile/session-lock library |

---

## 4. Metrics that matter

### 4.1 Recommended For You (Home) signals: current state

Per Roblox's discovery docs (current) and the 2026-06-15 announcement [Roblox docs]:

| Weight | Signal | Window |
|---|---|---|
| Most important | **Play-through rate** (plays after seeing the game in RFY) | n/a |
| Most important | **First-play bounce rate** (negative; <60 s and 61-180 s) | first play |
| Most important | **Play days per user** | D1, D2-7, D8-28 |
| Most important | **Playtime per user** (capped at 60 min/user/game/day) | D1, D2-7, D8-28 |
| Important | Intentional co-play days per user (invites, joins, private/reserved servers, not matchmaking) | D1, D2-7, D8-28 |
| Important | Qualified play sessions per user | D1, D2-7, D8-28 |
| Important | Spend days per user | D1, D2-7, D8-28 |
| Important | Robux spent per user | D1, D2-7, D8-28 |

Notes:
- Signals count **only users who joined organically from RFY**, and are averages per user, not totals. [Roblox docs]
- From 2026-08-20, Home rewards games strong in both retention and monetization. Games strong in one keep impressions but may see changes. [Roblox docs (DevForum, Ciancutti)]
- Over 90% of traffic begins on Home. Signals update within ~24 h, and impressions react a few days later. [Roblox docs (2025-03-31)]
- Traffic peaks on Saturdays. [Roblox docs (discovery)]
- **Ineligible without a custom thumbnail.** Deprioritized: titles leading with giveaways or Robux, mismatched metadata (misleading thumbnails), and place files or metadata closely resembling existing games. A Creator Dashboard banner shows reduced exposure, updated daily. [Roblox docs (discovery)]
- Known bot engagement is excluded from RFY. [Roblox docs (2026-08-19)]
- Other surfaces: Continue Playing, Friends, Sponsored, Curated sorts, **Standout Games** (hand-curated novel games), Live Events, Search (semantic), Discover charts, Notifications. [Roblox docs]

**Practical translation** [Derived]:
1. Thumbnail and first 60 s decide play-through and bounce.
2. D1 → D28 return reasons decide play days.
3. Short daily sessions beat long ones past 60 min.
4. Co-op/invite features count, so build "invite a friend for +X" or friend-boost mechanics (reserved servers count as co-play).
5. A spend day matters as much as spend amount, so small, frequent, fair purchases help.

### 4.2 Benchmarks for "good" numbers

**Roblox does not publish retention or monetization cutoffs.** The Creator Hub shows your percentile against similar experiences, and you can choose the benchmark set and see D1/D7/D30 by acquisition source (since 2025-10-16). [Roblox docs (DevForum)] Third-party figures:

| Metric | Figure | Label |
|---|---|---|
| D1 / D7 / D30, simulator average | 32% / 14% / 6.2% (sample: 850+ promoted games) | Unverified (BLOXG 2026) |
| D1 / D7 simulator average / top 10% | 25% / 11%; top 10% 45% / 23% | Unverified (Devmaxx) |
| Generic thresholds | D1 20% good / 30% great / 40% excellent; D7 8 / 15 / 20% | Unverified (guides) |
| Platform-wide median D7 (all projects, 2025) | 3.42-3.94%; top quartile 7-8% | Reported (GameDev Reports recap, 2025-02) |
| A creator's D7 of 0.73% = 23rd percentile | shows the skew | Reported (DevForum bug thread) |
| Avg session, current trend hits | 15-16 min; longer-lived sims 25-31 min | Reported (Adellion 2026-10-02) |
| Thumbnail personalization lift | +8.5% avg qPTR, some +50% | Roblox docs (DevForum 2024-11-13) |

Use them as sanity ranges: if D1 is under ~20% or first-play bounce dominates, fix onboarding before adding content. [Expert practice (guides); Derived]

### 4.3 Thumbnails and icons

- Specs: thumbnails 16:9, ideal 1920×1080, <3 MB; icon square ≥512×512, preview at ~150 px; all images moderated. [Roblox docs]
- **Thumbnail personalization** (live since 2024-11-13): 2-5 active Home thumbnails. Impressions start evenly split, then each hour shift toward thumbnails with higher play-through for each user group (multi-armed bandit, not a fixed A/B). Stats appear after a few hours. Experiences under ~1,000 DAU "may not see meaningful results." Roblox advises keeping several active, refreshing a set with each major update, and waiting a few days before removing losers. [Roblox docs]
- Since June 2026, thumbnail personalization is tested with play-through rate (PTR). [Roblox docs]
- Icons: **no native icon A/B testing**. Workaround: test the icon's art as a thumbnail. [Reported (DevForum)]
- Open Cloud added Experiments and Thumbnail Personalization APIs (2026-08-24). [Reported (DevForum/third-party summary)]
- Rules: metadata must match content. Misleading thumbnails reduce exposure and violate the "Repetitive and Misleading Content" standard. [Roblox docs]

### 4.4 Sponsored ads (Ads Manager)

- Placements: Home sponsored tile and search results. Metric: cost per play (CPP = spend / plays). Fund with ad credits (Robux → credits is irreversible; unused credits refunded at campaign end) or card (card needs 18+; Ads Manager needs 13+). Minimum purchase is 1 ad credit. Targeting: All / New / Recent (needs 10k+ recent players) / Lapsed (needs 20k+), plus advanced location, age, gender, genre and device. Up to 10 thumbnails, displayed at 16:9. [Roblox docs (Ads Manager page)]
- Mar 2025 update: "Maximize Plays" goal, auto bid adjustment toward lowest CPP, 16:9 creatives (up to 40% PTR improvement claimed). Reports include 7-day playtime and 30-day Robux earned. [Roblox docs (DevForum 2025-03-31)]
- Benchmarks: late-2025 updates cut CPP ~40% vs 2024. Average CPP: Maximize plays $0.008, Drive retention $0.007, Reactivate $0.011. 45k creators use Ads Manager (+70% YoY). [Reported (Naavik State of UGC 2026)]
- **Expert practice**: most developers use paid ads to trigger organic recommendations rather than as continuous spend. [Expert practice (Naavik)] Ads buy samples of players, and RFY then judges those samples on retention. Ads cannot rescue a game with poor D1. Note that RFY signals count only organic RFY joiners. [Roblox docs + Derived]
- Ads may not make deceptive claims (including free Robux). Developers may not reward under-13s for engaging with ads. [Roblox docs (Advertising Standards)]

### 4.5 Under-16 reach gate (new in 2026)

For under-16 players (Roblox Kids 5-8, Select 9-15) [Roblox docs (Kids and Select page)]:
- Owner account age-checked, verified (facial estimate if <18, ID if 18+), 2-Step Verification, account in good standing.
- Maturity questionnaire → Minimal/Mild (Kids) or up to Moderate (Select).
- Fee or subscription: one-time refundable fee (1,000 Robux per game per DevForum), refunded 90 days after eligibility (or 90 days after payment if never eligible), **or** Plus/Premium for 2 consecutive months. Expedited review is a refundable 50,000 Robux.
- **Evaluation**: trial with age-checked 16+ users only. "Highly engaged" players (account tenure, playtime in your game, any platform purchase in the last 60 days) are checked hourly. **Threshold: 250 unique plays by highly engaged age-checked users within 60 days** (official docs). The May 2026 DevForum rollout used 500 highly engaged players to auto-grandfather existing games, with possible loss of eligibility below 100. [Roblox docs (both); figures differ by context]
- Parents can manually approve a specific game for a child. [Roblox docs]
- Roblox acknowledged this "can lengthen the time it takes for new games without an existing audience to grow." [Reported (BSR quoting Roblox)]

**Implication**: a trend game's first days now run on a 16+ audience. Seed with ads targeted 16+ and with creator or community audiences, and complete verification, 2SV and the fee **before** launch day. [Derived]

---

## 5. Monetization

### 5.1 What trend games sell

| Product type | Examples | Typical reported price | Compliance notes | Label |
|---|---|---|---|---|
| Income multiplier pass | 2x Money | 119-299 Robux (SaB, sources differ) | none special | Reported (guides) |
| VIP pass | VIP tag, +income, longer base lock | 199-499 Robux (SaB) | | Reported |
| Admin/command pass | Admin Panel | 1,999-4,999 Robux (SaB) | Selling admin powers drew "pay-to-win" criticism | Reported (Polygon via Wikipedia) |
| Season/battle pass | GaG Season Pass | 749 premium; 49/level skip; 1,699 full skip | | Reported |
| Cosmetic crates | GaG Exotic Cosmetic Crate | 199 / 575 / 1,699 for 1/3/10 | **Paid random item: odds disclosure + PolicyService** | Reported |
| Eggs / lucky blocks with Robux | SaB lucky blocks | not verified | Paid random item; some regions have them disabled | Reported |
| Luck boosts (personal or server) | "2x luck" | not verified | **Probability modifier**: disclose numerically before purchase; displayed odds must update while active | Roblox docs |
| Restock / skip timer | GaG seed restock with Robux | not verified | none special unless output is random | Reported |
| Steal/raid tools | GaG steal with Robux, SaB gear | not verified | | Reported |
| Limited units | event-only brainrots/pets | n/a | scarcity drives trading; off-platform resale violates rules | Reported |
| Private servers | | varies | | Roblox docs |

Price points are not standardized and change often. Treat the ranges above as anchors, not recommendations. [Derived]

### 5.2 Revenue math (how to estimate your own)

- Developer take: Roblox keeps roughly 70% of Robux revenue players generate in the Bloomberg framing. Per greyjournal, developers net about **$0.21-0.27 per real dollar** spent, depending on web vs mobile Robux pricing. [Reported (Bloomberg 2026-03-24; greyjournal 2026-10-18)]
- DevEx: $0.0038 per earned Robux (from 2025-09-05). $0.005396 for 18+ spend in qualifying "novel" R15 games (from 2026-06-08), which trend clones are unlikely to qualify for. [Reported (Tubefilter)]
- Robux retail: 1,000 Robux = $9.99 on web, 800 Robux = $9.99 via mobile stores. [Reported (greyjournal)]
- Tracker method example (profitable.app): engaged sessions = 2% of visits × 150 Robux each × 70% share × $0.0038. Halve either input and the output halves. **These are models, not measurements.** [Reported (greyjournal)]
- Creator Rewards: +5 Robux per qualifying Active Spender per day (10+ min, among their first three games that day). 35% of the first $100 spend of new or reactivated users you bring via share link, direct link or name search (game must average 100+ DAU for 60 days). [Roblox docs]

### 5.3 ARPDAU / payer conversion

**Not published by Roblox.** Creator Analytics shows ARPDAU, payer conversion and ARPPU with percentile benchmarks for similar experiences, though benchmark display bugs have been reported. [Roblox docs; Reported (DevForum)]

Third-party and anecdotal figures:
- Platform-average ARPDAU $0.05-0.15; average conversion 1-3%, top titles ~8%. [Unverified (studio blog)]
- Tycoon conversion 2-5%, ARPPU 100-300 Robux. [Unverified (Medium 2026)]
- A cosmetics-only game at ~0.12% conversion; another dev reports rarely above 0.05%. [Reported (DevForum anecdotes)]
- Geography dominates: ~$1.00 ARPDAU on a US-heavy game vs ~$0.05 on a similar SEA/LatAm-heavy game. [Reported (DevForum anecdote)]
- Bookings per payer fell in Q3 2025 due to geographic mix. U.S. 18-34 users monetize >50% higher than under-18s. [Roblox docs (Q3 2025 call) / Reported (Tubefilter)]
- Adopt Me's ARPU is estimated ~5× Brookhaven's, so **CCU ≠ revenue**. [Reported (Offpath's Tim Elliott via GameDiscoverCo)]

### 5.4 Monetization design rules that work with the 2026 algorithm

- Roblox's advice: "Add optional, fair monetization tied to progression." Low retention means fix the core first. [Roblox docs (Aug 2026 post)]
- Spend days per user is its own signal, so cheap, frequent, clearly-valued offers (starter pack, small boosts) matter alongside big passes. [Roblox docs + Derived]
- Every paid random outcome must give value. No "nothing" results. [Roblox docs]
- Avoid "pay to steal everything." Polygon's pay-to-win criticism and kids' viral distress clips are reputational risk, and low approval correlates with lower longevity (sub-90% approval games in the Adellion snapshot). [Reported; Derived]

---

## 6. Live ops

- **Cadence**: Grow a Garden shipped weekly, every Saturday, with limited-time events, powerups, new plants and pets. Two event teams were formed in July 2025 to sustain weekly events. [Reported (GameDiscoverCo; Wikipedia)] Restaurant Tycoon 3 patched weekly through Sept 2026. Pet Simulator 99 shipped four numbered updates in Sept 2026. [Reported (Adellion)]
- **Admin abuse**: the owner uses admin powers live to spawn special weather, restock shops, give exclusive seeds and pets, and broadcast messages. Typically Saturdays, around the weekly update (exact times reported inconsistently). Other team members hosted a separate Wednesday event. [Reported (fan wikis/guides; low authority)] Naavik describes admin abuse as altering configs, boosting stats and gifting content. [Expert practice (Naavik)]
- **Crossovers and spectacles**: GaG × SaB "admin war" (2025-08-23) → 22.3M / 20M+ and a 47.4M platform record. SaB "Extinct Event" (24M). Bruno Mars concert (12.8M). [Reported]
- **Countdowns**: put the next update/event time on the icon, thumbnail and in-game HUD. Some top games edit the icon countdown by hand. [Reported (DevForum anecdote)] Use **Experience Events** (Live Events on Home; events support up to 5 thumbnails). [Roblox docs (discovery)]
- **Server-wide synchronization**: use a deterministic schedule from `os.time()`/`workspace:GetServerTimeNow()` so every server runs the same restock and event at the same time. Use MessagingService for live admin triggers. [Expert practice (DevForum answers)]
- **Seasonality**: Home traffic peaks Saturdays. [Roblox docs]
- **What keeps CCU**: regular updates ("games that stop updating decline within weeks") [Reported (RoWatcher)]; new units and mutations each week; limited-time scarcity; trading economies; and reasons to log in daily (offline growth, restocks). [Derived]
- **Post-peak**: expect 90%+ decline from a viral peak. The aim is a stable floor with weekly bumps. Steal a Brainrot still drew ~1.7M 30-day peak CCU in Oct 2026, a year after launch. [Reported (Adellion)]

---

## 7. What separates hits from failed clones

1. **A twist on the verb, not a reskin.** Escape Tsunami added a hazard-run to brainrot collection. Plants vs Brainrots added tower defense to planting. Steal An Egg moved stealing to eggs and pets. Ride A Pet made the pet the mount. Roblox's own advice is "Add your own spin to trends," and it deprioritizes near-duplicates. [Roblox docs; Reported]
2. **A first session that lands.** First-play bounce under 60 s and 61-180 s is a "Most Important" signal. [Roblox docs] Get a new game to hook players within ~30 s. "Evolution beats revolution." [Expert practice (Dubit 2026-09-16)]
3. **Operational excellence after launch.** Weekly updates, scaling, acting on feedback (Splitting Point's approach). [Reported]
4. **Juice and readability.** Big numbers, rarity colors, mutation VFX, satisfying sounds. AI-default games are recognized "within seconds." [Reported (Altitude DP)] Steal a Brainrot's readable rules and visible stakes. [Reported (Beebom)]
5. **Mobile performance.** ~80% of users on mobile (2024). [Reported] Shared servers full of bases, units and VFX must hold frame rate on low-end phones. Steal a Brainrot's players reportedly tolerated "severe lag," but you can't count on that for a clone. [Reported (Beebom); Derived]
6. **Approval rating and session depth.** Games that held their ranking had ~90%+ approval and 25-30 min sessions. Spikes with 15-min sessions faded fastest. [Reported (Adellion 2026-10-02)]
7. **Community and creators.** Discord, YouTube relationships, clip-able moments. [Expert practice (Naavik)]
8. **Trust**: no dupes, no lost data, a fair trade system (GaG fixed gift-scams with trade tickets), visible anti-exploit enforcement. [Reported; Derived]
9. **Legal hygiene**: original art, UI and characters. Imitators faced lawsuits and removal from Fortnite. [Reported (Bloomberg)]

Juice checklist for the plugin [Expert practice, general game-feel]: number pop-ups with rarity color, tweened UI open/close (0.15-0.25 s), purchase confirmation burst, mutation shimmer, steal alarm and siren, rebirth full-screen moment, restock bell + countdown, rare-drop server-wide announcement, haptics on mobile where available.

---

## 8. Risks and rules (precise)

### 8.1 Paid random items (eggs, crates, spins, luck, pity, bundles)
[Roblox docs: Creator Hub "Paid random items policy guidelines"; Community Standards "Paid Random Items"; DevForum 2026-05-26]
- Scope: random items bought directly or indirectly (keys, tickets, paid in-game currency) with Robux. Types: capsule, enhancement, combination, and probability-modifier (luck boosts, pity, enhanced drops, rate-up).
- Disclosure: "all possible outcomes and the actual numerical odds," as percentages summing to exactly 100% (rounding allowed with a disclaimer). Shown before purchase. A "Details/Info" pop-up is OK, but a standalone (i) icon is not.
- Odds modifiers: explain the impact numerically before purchase. Displayed odds must update dynamically while active. Luck gamepasses count.
- Unique-win outcomes: remaining odds must update per user.
- Bundles containing any random item make the whole bundle a paid random item.
- Every outcome must provide some benefit.
- Earned-only randomness (no direct or indirect Robux) is not covered.
- `PolicyService:GetPolicyInfoForPlayerAsync(player)` → `ArePaidRandomItemsRestricted`: give a compliant alternative (earnable path, predetermined disclosed order, direct sale at expected value, hide, block with message, or keep the player out of those areas). `IsPaidItemTradingAllowed` gates trading of paid items **separately**. The region list is set centrally and changes, so **don't hardcode countries**. Brazil restrictions were reported from Mar 2026. Third-party sources name Australia, Belgium, the Netherlands, the UK and Brazil. [Unverified list]
- Enforcement: moderation notice; "the game will be removed and your account will be suspended" for policy violations; fix and appeal. **Not addressed**: "server luck" events and admin abuse luck. If server luck is ever sold or triggered by purchase, treat it as a probability modifier and disclose. [Derived; conservative reading]

Minimal compliant gate (fail closed):
```lua
local PolicyService = game:GetService("PolicyService")

local function getPolicy(player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or type(info) ~= "table" then
		-- Fail closed: treat as restricted until we know otherwise
		return { randomRestricted = true, tradeAllowed = false }
	end
	return {
		randomRestricted = info.ArePaidRandomItemsRestricted == true,
		tradeAllowed = info.IsPaidItemTradingAllowed == true,
	}
end
```
Check this on the **server** before showing or processing any paid random purchase or trade, and cache it per session.

### 8.2 Gambling
"We prohibit both simulated and actual gambling." No Robux or items of value in connection with gambling. Content maturity allows only *unplayable* gambling content. [Roblox docs (Community Standards; Content Maturity)] Coin flips or wagers of units between players are high risk. [Derived]

### 8.3 Misleading and duplicative content, metadata, thumbnails
- Prohibited: "Deceptive, sensational, duplicative, or otherwise misleading content or metadata" used to drive discoverability, monetization or engagement, and repeated uploads of content that is the same as, or almost the same as, something already on the platform. [Roblox docs (Community Standards)]
- Discovery deprioritizes giveaway-led titles, mismatched metadata, and near-duplicate metadata or place files. [Roblox docs (discovery)]
- Ads: no deceptive claims, no "free Robux." [Roblox docs (Advertising Standards)]

### 8.4 IP and copyright (meme characters)
- Roblox removes content on valid takedowns and "may also proactively delete or archive assets" suspected of infringement. [Roblox docs (Community Standards)]
- Brainrot characters: ownership is contested (Tung Tung Sahur dispute; Spyder v. Mementum). Steal a Brainrot's owners claim copyright in UI layout, art, objects and aesthetic, and sue near-identical copies. [Reported (Bloomberg 2026-03-24; Wikipedia)]
- Game mechanics are "typically not protected by copyright." [Expert practice (Connor Richards, Odin Law, via Bloomberg)] **This module is not legal advice.**
- Practice: original characters, names, UI and art. No ripped models or audio. Don't reuse a hit's thumbnail composition or trade dress. [Derived]

### 8.5 Botting and fake CCU
- Bots and automation for disruption violate Community Standards. Roblox ran a bot enforcement wave from 2026-08-19, kicks bots in real time, rolls back their follows, votes and joins, and excludes known bot engagement from RFY. [Roblox docs]
- The announcement does not state creator penalties for buying bots. [Roblox docs] Account suspension is the general consequence under the Terms. Botted CCU doesn't improve per-user RFY signals and dilutes them. [Derived]

### 8.6 Age, maturity, chat, under-16 audience
- Maturity & Compliance questionnaire is required. Unrated games are unplayable. Inaccurate answers can mean an unrated label and further moderation. [Roblox docs]
- Crude humor (common in brainrot) rates Mild (burps, farts, unrealistic poop) or Moderate (pee). Moderate excludes Kids (5-8). [Roblox docs (Content Maturity)]
- Kids/Select evaluation (§4.5). Chat age checks (Jan 2026) limit cross-age chat. Plan social features (trading, co-op) that work without chat: emotes, quick-chat presets, trade UI. [Roblox docs + Derived]
- Ads: developers must not reward under-13s for engaging with ads, and must not misuse PolicyService to show ads to ineligible users. [Roblox docs]

### 8.7 Economy fraud and off-platform trading
Prohibited: off-platform secondary-market transactions for virtual content, third-party Robux sales, circumventing payments. **Removing purchased functionality without proper notice** is also listed under Fraud, which matters when you rebalance or remove paid items. [Roblox docs (Community Standards)] Rare items from trend games are widely resold off-platform. [Reported (Calcalist; Wikipedia)] Don't encourage it, and make the in-game trade system the safe path.

### 8.8 Security and exploits
Free-model backdoors (`require(` with asset IDs, obfuscation). [Reported] Automation scripts plague steal games. [Reported] Make the server authoritative for currency, ownership, stealing, trades and receipts. [Expert practice]

### 8.9 Recent enforcement examples (public)
- Unrated games made unplayable (2025-09-30). [Reported]
- PRI moderation notices with appeals (2026-05 onward). No specific named game takedown was found in public sources. [Roblox docs / not public]
- Bot wave (2026-08). [Roblox docs]
- Platform-level actions against imitators are mostly private lawsuits and Epic removals on Fortnite, not Roblox moderation. [Reported]

---

## 9. "Trend game in 7 days with Claude Code": step-by-step plan

Assumptions: solo developer or a team of 2-3, Claude Code connected to Roblox Studio via the built-in Studio MCP server, a pre-built template library (§3.3), and verification steps done in advance. Each day ends with a playable build and a checklist. Related plugin modules, if present, are referenced in brackets.

### Day 0 (before the clock starts, ~2 h)
- Owner account: age check, ID or facial verification, **2-Step Verification**, DevEx/ID verification for Creator Rewards. Decide the fee or Plus/Premium route for Kids/Select. [Roblox docs]
- Install and pin the template modules (data, economy config, weighted random + odds UI, shop/restock, base/slots, steal/trade, rebirth, monetization, events, analytics, UI kit).
- **Deliverable**: `TEMPLATE_VERSION`, empty place with the template running, test DataStore.

### Day 1: Trend pick and twist (research + design)
- Pull 7-14 days of CCU/visits for the trend's top 20 games (Rolimon's, RoMonitor, rblxdb, RoWatcher). Watch the top 10 YouTube/TikTok videos about them.
- Write a one-page **design brief**: core verb, *one* twist, unit list (24-40 units across 6-9 rarities), 2-3 mutations, base layout, steal/trade rule, rebirth curve, monetization list, first-60-seconds script, 3 event ideas.
- **Economy sheet**: per-unit income, price, expected time-to-next-unit (target: first upgrade <30 s, first rebirth ~20-40 min of play) [Expert practice: hook within ~30 s (Dubit); the rest is a design target, not a published benchmark].
- Originality check: names, art direction, UI layout must not mirror the hit.
- **Deliverables**: `design-brief.md`, `economy.csv`, `units.lua` config, twist statement in one sentence.

### Day 2: Core loop playable (Claude Code builds; human tunes)
- Generate from config: plot assignment, conveyor/spawner or equivalent, buy → place → earn-per-second, save/load with session lock, offline earnings.
- Server-authoritative remotes with rate limits [roblox-secure-remotes]. DataStore review [roblox-datastore-safety].
- Playtest agent pass + 3 human sessions on phone.
- **Deliverables**: core loop in a published private place; no data loss across rejoin; remote audit list.

### Day 3: Social mechanic + rarity/mutations + rebirth
- Steal (carry slow, alert, one-hit return, base lock + timer) **or** gifting/trading via server-validated trade tickets.
- Rarity colors, mutation rolls (earned randomness first), rebirth with slots and multiplier.
- PolicyService wrapper in place even before monetization (§8.1).
- **Deliverables**: 2-player test video (clip-able moment), mutation table with probabilities in config, exploit checklist pass.

### Day 4: Theme, art, juice, UI (where AI and taste meet)
- Characters and props: Cube mesh generation or Blender pipeline → import at the right scale and triangle budget [roblox-asset-import]. Original meme-style characters only.
- UI kit reskin: HUD (cash/s, rebirth, event timer), shop with restock countdown, inventory, **odds panel**, daily reward, codes, settings [roblox-ui-builder].
- Juice pass (§7 checklist), VFX for rarity and mutations [roblox-vfx], SFX.
- **Deliverables**: screenshot set at phone resolution, before/after juice clip, art bible (palette, fonts, rarity colors).

### Day 5: Monetization + compliance + live-ops framework
- Passes: 2x income, VIP, auto-collect or extra slots. Products: cash packs, restock skip, starter pack, **luck boost with live odds update**, egg/crate with full odds. ProcessReceipt idempotency [roblox-monetization-compliance].
- Restricted-user alternatives (earnable path or hide/block message). Trade gating by `IsPaidItemTradingAllowed`.
- Event framework: scheduled weekly event, server luck multiplier (if purchasable, disclose as modifier), admin command set (server-validated, owner-only), global countdown.
- Analytics: funnel events (spawn → first buy → first steal/trade → first rebirth), economy source/sink events.
- **Deliverables**: compliance checklist signed off, product ID list, event calendar for 4 weeks.

### Day 6: Performance, QA, metadata, questionnaire
- Mobile perf audit (instance counts, StreamingEnabled, VFX budgets, memory) on a low-end phone [roblox-performance-audit]. Full server stress with bots in Studio local server (not live bots).
- Exploit review [roblox-anti-exploit-review].
- Maturity & Compliance questionnaire (answer for the most extreme content). Aim for Minimal/Mild if you want Kids reach; crude humor beyond Mild locks you out of Kids.
- Metadata: original title (no Robux/giveaway lead), description, genre. **5 thumbnails** (1920×1080, distinct hooks: steal moment, rarity reveal, base, event, mutation) + 512 px icon tested at 150 px. Event listing for the launch update.
- **Deliverables**: perf report, exploit report, questionnaire done, thumbnail set, launch checklist.

### Day 7: Launch (Saturday, if possible)
- Publish public. Pay the Kids/Select fee or confirm subscription. Expect a **16+-only trial** until 250 highly-engaged unique plays (60-day window). [Roblox docs]
- Small Ads Manager test: "Maximize Plays," 16:9 creatives = your thumbnail set, budget sized to buy a few thousand plays (CPP benchmarks ~$0.007-0.011) [Reported (Naavik)]. The goal is samples for RFY, not sustained buying.
- Seed with community: Discord, short clips, friend-invite reward (co-play days are a signal).
- Monitor first 24-72 h: play-through rate, bounce <60 s / 61-180 s, D1, playtime, spend days. Fix the biggest funnel drop **before** adding content.
- **Deliverables**: live game, launch-day dashboard snapshot, week-2 update plan.

### Week 2+: Operate
- Weekly Saturday update + event + countdown. Refresh thumbnail set each major update. Watch thumbnail personalization stats once DAU passes ~1,000.
- Decide by D7/D28 numbers whether to double down, pivot the twist, or move on. A good outcome may also attract a partner or acquirer (the GaG/Fisch pattern). [Reported]

**Honest expectation setting** [Derived from §0-2]: AI makes a launchable trend game in 7 days realistic. It does not make a hit likely. ~1 in 50,000 new experiences reached top-10 spend in a year (2025 data), and 2026 platform changes slowed viral spread. Budget for many launches, measure, and keep the template improving.

---

## 10. Quick-reference numbers

| Item | Value | Label |
|---|---|---|
| RFY playtime cap | 60 min / user / game / day | Roblox docs |
| RFY windows | D1, D2-7, D8-28 | Roblox docs |
| First-play bounce windows | <60 s, 61-180 s | Roblox docs |
| Home thumbnails for personalization | 2-5 active | Roblox docs |
| Thumbnail spec | 16:9, 1920×1080, <3 MB | Roblox docs |
| Icon | square, ≥512×512 | Roblox docs |
| Kids/Select eval threshold | 250 unique highly-engaged plays / 60 days | Roblox docs |
| Kids/Select fee | 1,000 Robux, refundable (90 d) | Roblox docs (DevForum) |
| Expedited review | 50,000 Robux, refundable | Roblox docs |
| DevEx | $0.0038/Robux; $0.005396 for 18+ spend in qualifying novel games | Reported |
| Daily Engagement Reward | 5 Robux / qualifying Active Spender / day | Roblox docs |
| Audience Expansion | 35% of first $100 spend, 60 days | Roblox docs |
| Ads CPP benchmarks | $0.007-0.011 | Reported (Naavik) |
| Ads targeting thresholds | Recent 10k+, Lapsed 20k+ | Roblox docs |
| Mobile share of DAU (2024) | ~80% | Reported |
| Thumbnail personalization lift | +8.5% avg qPTR | Roblox docs |

---

## 11. Gaps and conflicting data (do not cite as fact)

- Per-game revenue: none official. Estimates vary 3-8× (SaB $1.4M-$11M/month).
- Exact CCU records differ by tracker (SaB 25.4M vs 25.8M; Steal An Egg 12.4M vs 14.3M).
- Retention "good" thresholds are vendor-sourced only.
- ARPDAU / conversion: anecdotal only.
- Kids/Select threshold: 250 (current docs) vs 500/100 (May 2026 rollout grandfathering).
- Admin abuse timing details come from fan wikis.
- Restricted PRI region list is not officially enumerated.
- "Server luck" and admin-event luck are not explicitly addressed by the PRI policy.
- Short-seller (BSR) figures on social spread and new-user decay are unverified and come from a party with a financial position.
- The platform's mobile share is a 2024 official figure. No 2025-26 official update was found.
- Time-to-market windows for fast-follows are inferred, not measured.

---

## 12. Sources

Roblox official (docs, DevForum staff posts, newsroom, filings)
- Paid random items policy: https://create.roblox.com/docs/production/monetization/paid-random-items
- Clarifying Requirements for Paid Random Items (2026-05-26): https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622
- Community Standards: https://about.roblox.com/community-standards
- Discovery docs: https://create.roblox.com/docs/discovery
- RFY 28-day update (2026-06-15): https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- Optimizing Discovery newsroom (2026-06-15): https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- Boost Your Discovery... (2025-03-31): https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441
- Boost Your Discovery by Building Games People Want to Play (2026-08-06/20): https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042
- Thumbnail personalization (2024-11-13): https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233
- Thumbnails / Icons docs: https://create.roblox.com/docs/production/publishing/thumbnails , https://create.roblox.com/docs/production/publishing/experience-icons
- Ads Manager docs: https://create.roblox.com/docs/production/promotion/ads-manager
- Leveling Up Ads Manager (2025-03-31): https://devforum.roblox.com/t/leveling-up-ads-manager-with-new-features/3587640
- Advertising Standards: https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards
- Creator Rewards: https://create.roblox.com/docs/creator-rewards
- Content Maturity: https://create.roblox.com/docs/production/promotion/content-maturity
- Roblox Kids and Select: https://create.roblox.com/docs/production/publishing/kids-and-select
- Alternate Publishing Requirements (2026-05): https://devforum.roblox.com/t/alternate-publishing-requirements-for-roblox-kids-and-select/4630944
- Strengthening Our Safety Policies (2025-08-15, updated 2026-05-12): https://devforum.roblox.com/t/strengthening-our-safety-policies-and-tools/3882864
- Age checks to chat (2026-01): https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat , https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101
- Actioning Against Bot Accounts (2026-08-19): https://devforum.roblox.com/t/actioning-against-bot-accounts-on-roblox/4820656
- Roblox Studio is Going Agentic (2026-04-15): https://about.roblox.com/newsroom/2026/04/roblox-studio-going-agentic
- Q3 2025 shareholder letter: https://www.sec.gov/Archives/edgar/data/1315098/000131509825000326/ex991-q32025shareholderl.htm
- Q2 2026 shareholder letter: https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf
- Retention by acquisition source (2025-10-16): https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157

Press, analysts, trackers, interviews
- GamesBeat, Janzen Madsen interview (2025-09-07): https://gamesbeat.com/janzen-madsen-interview/
- GameDiscoverCo on Grow a Garden (2025-05-27): https://newsletter.gamediscover.co/p/what-grow-a-gardens-89-million-ccu
- Calcalist on Grow a Garden (2025-07-13): https://www.calcalistech.com/ctechnews/article/dj4lxef8r
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- Wikipedia, Steal a Brainrot: https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Bloomberg via The Star, "Steal A Brainrot battles its many imitators" (2026-03-24/25): https://www.thestar.com.my/tech/tech-news/2026/03/25/robloxs-hit-game-steal-a-brainrot-battles-its-many-imitators (original: https://www.bloomberg.com/news/articles/2026-03-24/roblox-s-hit-game-steal-a-brainrot-battles-its-many-imitators)
- Grey Journal revenue comparison (2026-10-18): https://greyjournal.net/hustle/how-much-does-steal-a-brainrot-make/
- RoWatcher, "Is the Brainrot Trend Dying?" (~2026-03): https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals
- RoWatcher top-earning games Q1 2026: https://rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026-and-what-they-mean-for-the-platform
- Beebom on Steal a Brainrot design (2025-12-31): https://beebom.com/robloxs-steal-a-brainrot-delivered-a-2025-masterclass-in-player-engagement-and-gave-uefn-a-second-wind/
- PCGamesN, 99 Nights interview (2026-09-12): https://www.pcgamesn.com/roblox/99-nights-in-the-forest-interview
- Rolimon's, 99 Nights: https://www.rolimons.com/game/79546208627805 ; Escape Tsunami: https://www.rolimons.com/game/131623223084840
- Sherwood News on Escape Tsunami (2026-01-13): https://sherwood.news/markets/roblox-surges-as-a-new-brainrot-game-climbs-the-engagement-charts/
- Adellion simulator snapshot (2026-10-02): https://adellion.com/roblox-simulator-games
- RoStats records: https://rostats.io/records ; Misfits on X (2026-08-21): https://x.com/MisfitsGG/status/2090785862632038706
- Naavik, State of UGC Games 2026: https://naavik.co/deep-dives/the-state-of-ugc-games-2026/
- Bleecker Street Research (short seller, 2026-10-27): https://www.bleeckerstreetresearch.com/research/rblx
- Dubit, What makes a new Roblox game take off (2026-09-16): https://dubit.io/library/what-makes-a-new-roblox-game-take-off
- TechCrunch, Roblox "Build" (2026-07-16): https://techcrunch.com/2026/07/16/roblox-launches-an-ai-powered-game-creation-feature-in-its-mobile-app/
- Altitude DP, "AI Slop Is Flooding Roblox" (2026-09-04): https://altitudedp.com/research/ai-slop-is-flooding-roblox-and-thats-fine
- Tubefilter, DevEx for 18+ novel games (2026-05-01): https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/
- Tubefilter, KreekCraft/ROI (2026-03-09): https://www.tubefilter.com/2026/03/09/kreekcraft-has-spent-over-100000-making-a-roblox-game-whats-the-roi-for-developers/
- Dexerto, KreekCraft $1M (2026-01-20): https://www.dexerto.com/youtube/roblox-youtuber-kreekcraft-says-steal-a-brainrot-has-earned-him-over-1-million-3306950/
- Investing.com Q3 2025 and Q2 2026 call transcripts: https://www.investing.com/news/transcripts/earnings-call-transcript-roblox-q3-2025-shows-strong-growth-but-stock-dips-93CH-4320285 , https://www.investing.com/news/transcripts/earnings-call-transcript-roblox-q2-2026-beats-eps-but-shares-sink-on-bookings-93CH-4826338
- PocketGamer.biz, 80% mobile: https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue
- DevForum Steal a Brainrot kit tutorial (2025-12-09): https://devforum.roblox.com/t/how-to-make-roblox-steal-a-brainrot-game-tutorial-series/4137672
- Developer X post on AI remix (2026, self-reported): https://x.com/imcyrian/status/2038885620366618839
- Jacob Navok on X (~2025-11): https://x.com/JNavok/status/1986966365782036507
- Bloxy News on Brazil PRI restriction (2026-03): https://x.com/Bloxy_News/status/2034153291899408514
- ZehnStudio PRI summary (2026-06-02): https://zehn-studio26.com/news/paid-random-items-odds-disclosure/
- Retention vendor figures: https://bloxg.com/statistics/roblox-retention-benchmarks , https://www.devmaxx.app/retention-calculator
- Grow a Garden admin abuse (fan wiki, low authority): https://growagarden.fandom.com/wiki/Admin_Abuse
- Steal a Brainrot guides (prices/mechanics, low authority): https://deltiasgaming.com/roblox-steal-a-brainrot-all-gear-and-game-passes , https://allthings.how/steal-a-brainrot-roblox-efficient-stealing-events-and-rebirths
- Grow a Garden Season Pass prices: https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price
