---
tags: [game-design, genre, simulator, rng, teardown, analysis, pacing, monetisation, case-study, type/case-study, area/design, level/intermediate]
---
# Simulator and RNG Genre Teardown

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Copying features without measuring clocks -> Stopwatch log first, feature list second
> - Avoid: Tearing down only on PC -> Phone first; most of the audience is there
> - Avoid: Judging monetisation by price alone -> Map where each prompt sits in the loop and whether it interrupts
>
> Cost: TL;DR ~110 tok · whole note ~5.0k tok. Read more: ## 4. Number architecture · ## 5. Worked teardown: a combat-RNG hybrid · ## 8. Common mistakes
<!-- tldr:end -->

The playbooks ([[Genre Playbook - Simulators]], [[Genre Playbook - RNG and Collection Games]]) say what the parts of these genres are. This note is about **taking them apart**: how to tear down a competitor (or your own game) with a stopwatch and a spreadsheet, what the loops' clocks look like when they work, how the number architecture holds together or fails, and a worked teardown of one production hybrid (combat plus rolling plus simulator structure) with what changed after real feedback. The aim is to replace "this game is popular, let's copy it" with "this game pays out a reward every 22 seconds, an upgrade every 3 minutes and a new zone every 25, and its prices grow 2.6x per zone against income growing 2.4x" (illustrative numbers).

Related: [[Core Loops and Session Design]], [[Progression and Pacing Design]], [[Rarity Ladders and Drop Pacing Math]], [[Balancing with Spreadsheets and Data]], [[Retention and Return Hooks]], [[Monetization Overview]], [[Ethical Design and Player Trust]].

Source labels: **Docs** (Roblox docs as of October 2026), **Measured** (the reference project, anonymised), **Rule of thumb**. Teardown numbers for other games are not given here: they change weekly, and you should measure them yourself with the method below.

---

## 1. Teardown method

A teardown is a structured play session with instruments. Do it on a phone first (most of the audience), then on PC.

### The kit
| Instrument | What you record |
|---|---|
| Stopwatch log | Timestamp of every reward, upgrade, unlock, purchase prompt, pop-up, tutorial step, social prompt |
| Numbers sheet | Every price, income rate, multiplier, odds label, cooldown, capacity, at each stage |
| Screen census | Every screen and button reachable from the HUD, how many taps deep, whether it is a shop |
| Prompt log | Every monetisation touchpoint: where, when, what was offered, price, whether it interrupted play |
| Social log | Other players visible, chat prompts, trading, broadcasts, group or friend boosts |
| Return hooks | Timers, dailies, streaks, [[offline earnings]], scheduled events, notifications offered |

Play three sessions: **minutes 0 to 15** (onboarding), **one focused hour**, and **a return session the next day** (what pulls you back and what greets you). For a deeper teardown, buy the obvious starter purchase in a separate test account to see the paid path.

### The output
One timeline and one table per game:

| Clock | Question | Typical healthy band (rule of thumb) |
|---|---|---|
| Inner loop | Seconds between small rewards (a coin, a hit, a roll result) | 1 to 5 s |
| Upgrade loop | Minutes between purchasable upgrades | 1 to 5 min early, 5 to 15 later |
| Zone loop | Minutes between new areas or tiers | 10 to 30 min early, hours later |
| Long loop | Hours to a reset or a new region (rebirth, prestige, region boss) | 1 to 3 h for the first, growing |
| Meta loop | Days: collections, events, seasons | Weekly content beats |

When you compare games, these clocks explain more of their retention differences than any feature list. Two simulators with identical features but a zone loop of 12 versus 45 minutes are different games.

---

## 2. Four archetypes and their clocks

| Archetype | Inner verb | Main multiplier | Long loop | Collection | Where it breaks |
|---|---|---|---|---|---|
| Collect and sell simulator | Swing or click, fill capacity, sell | Tools and capacity | Rebirth | Light (tools, titles) | Verb too shallow once numbers stop surprising |
| Pet simulator | Collect currency, hatch eggs | Pets (equipped multipliers) | Rebirth, new worlds | Heavy (pet index, fusions) | Inventory flood; late-game number fatigue |
| Pure RNG roller | Press roll (or auto) | Luck | Higher roll tiers, crafting | Heavy (item index) | Luck inflation collapses the ladder ([[Rarity Ladders and Drop Pacing Math]]) |
| Hybrid (action plus RNG plus simulator) | Fight, then roll | Rolled gear plus upgrades | Zones, region bosses | Heavy | Production cost per item; combat balance across tiers |

Patterns that hold across all four:
- **The inner verb pays something every few seconds**, even if trivial. A floating "+1" counts. Silence for more than about 10 seconds early in a session reads as "nothing is happening".
- **One number is the hero**: cash, power, luck, or rarity. The HUD makes that number the biggest thing on screen. Hybrids that try to make three numbers heroes confuse players.
- **The next goal is always visible**: a gate price, the next rarity tier's odds, an egg with a preview. Teardown signal: count how many times in the first 15 minutes you did not know what to do next. The good games score zero.

---

## 3. The first 15 minutes, beat by beat

What a strong opening looks like when you log it (rule of thumb from teardown practice; your game's beats will differ):

| Time | Beat | Purpose |
|---|---|---|
| 0:00 to 0:20 | Spawn into the action, verb prompt on screen, first reward within seconds | No menus before fun |
| 0:20 to 2:00 | First upgrade affordable and pointed at | Teaches the economy |
| 2:00 to 4:00 | First random reward (egg, roll, drop) with a big reveal | Teaches the collection layer |
| 4:00 to 8:00 | Second and third upgrades; first quest or goal list appears | A visible ladder |
| 8:00 to 12:00 | First gate or new area | The world is bigger than it looked |
| 12:00 to 15:00 | A return hook offered (daily reward, timer, "come back for") and the first soft monetisation prompt | Next-session reason |

**Measured** lessons from the reference project's onboarding:
- The tutorial's first roll was originally guaranteed Rare. After play-testing it became a plain roll with no golden or bonus pulls: a guaranteed great first result teaches false odds and makes the second roll feel like a downgrade.
- The tutorial taught **salvage then forge** in the first minute, so duplicates had a meaning from the start.
- The intro cutscene was put behind a flag and disabled for a while; long intros before the first verb are a common teardown red flag ([[First-Time User Experience and Onboarding]]).

Teardown red flags in the first 15 minutes:
- A purchase prompt before the first upgrade.
- More than one full-screen pop-up on join (daily reward, starter pack, update log, group reward stacked).
- Menus with more than two taps to the main action.
- A first random reward with no reveal moment.

---

## 4. Number architecture

Simulators and RNG games run on exponentials. Teardowns should capture the two growth rates that define the game: **price growth per step** and **income growth per step**.

### The ratio that matters
If gate prices grow by `g` per zone and income grows by `i` per zone (from new resources, tools, pets, luck), the minutes to afford the next gate grow by `g / i` per zone.

| g / i | Result |
|---|---|
| Below 1 | Each zone is faster than the last; the ladder runs out quickly |
| About 1.05 to 1.2 | Each zone a little slower; the classic feel (rule of thumb) |
| Above 1.4 | A wall within a few zones; players stall and quit |

**Measured:** the reference project's first world priced gates at about **8x per zone** (reaching $900M by zone 7). When the design grew to a 30-zone ladder, that rate was judged far too steep and replaced with a single formula, `price(z) = 2,500 * 2.6^(z - 2)`, giving about $5.2M at zone 10 and $72B at zone 20 (and, by the same formula, about 1e15 at zone 30), with the first gate of each region replaced by a free portal after the region boss. Two takeaways for teardowns: price curves are usually one formula with a few overrides, and the free portal after a boss is a deliberate reset of the `g / i` pressure at the moment players are most invested.

### Big numbers on Roblox
- Luau numbers are 64-bit floating point (Docs: Luau has a single number type, a double). Integers are exact only up to 2^53 (about 9.0e15, **Maths**). A currency in the quadrillions starts losing units; increments of 1 vanish. If your curve passes 1e15, either store currency in a mantissa-and-exponent form or accept and design for rounding (display-only precision, no "+1" rewards at that scale).
- Doubles overflow to infinity around 1.8e308. A 2.6x-per-zone curve passes 1e15 (the exactness limit above) around zone 30 and reaches about 3e27 by zone 60: far below overflow, but well past exact integers. Multiplicative stacking of rebirths can still reach overflow; clamp.
- Display needs suffixes past trillions (**Measured**: the reference project's plan noted suffixes beyond T for later zones).

```lua
--!strict
-- Compact number formatting with suffixes. Keeps 3 significant digits.
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function formatNumber(n: number): string
	if n ~= n then
		return "NaN"
	end
	if n == math.huge or n == -math.huge then
		return if n > 0 then "inf" else "-inf"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = if scaled >= 100 then string.format("%d", math.floor(scaled))
		elseif scaled >= 10 then string.format("%.1f", math.floor(scaled * 10) / 10)
		else string.format("%.2f", math.floor(scaled * 100) / 100)
	return sign .. text .. SUFFIXES[tier + 1]
end

return formatNumber
```

Flooring (not rounding) avoids showing "1.00K" for 999.6 and never displays more money than the player has, which matters when a price check fails by a fraction ("it says 5.20M and I have 5.20M").

### Multiplier architecture
Teardowns should reconstruct how the multipliers combine (additive inside categories, multiplicative across is the common compromise: [[Genre Playbook - Simulators]] section 4). Signal of trouble: late-game multipliers displayed with suffixes ("x2.4Qa"). That game has lost control of its economy and is adding zeros to keep up.

---

## 5. Worked teardown: a combat-RNG hybrid

The reference project is a hybrid: real-time sword combat as the inner verb, rolled weapons as the collection, and simulator structure (gates bought with cash, upgrades, rebirths, region bosses) as the outer frame. A teardown of its systems, with what changed after feedback.

### Layers and clocks
| Layer | System | Clock |
|---|---|---|
| Inner | Fighting zone enemies (kills pay cash, XP, materials); rolling weapons | Seconds |
| Upgrade | Rolling better weapons, forging with materials, upgrade board | Minutes |
| Zone | Gates bought with cash, enemy and material tier per zone, rarity cap per region | Tens of minutes |
| Long | Region boss, free portal to the next region, rebirths | Hours |
| Session events | A pop-up group boss every ~30 minutes with a 60 s join window ([[Boss Fight Design Patterns]] section 7) | Half-hourly |
| Meta | Quests, potions brewed in real time, weather with luck bonuses, free gifts, index | Daily |

### What changed after feedback (all measured)
| Change | Before | After | Why |
|---|---|---|---|
| Roll reveal length | 2.4 s | 3.2 s (auto 2.56 s) | Rolls felt too fast to enjoy; the reveal is the product |
| Tutorial first roll | Guaranteed Rare | Plain roll | Taught false odds |
| Rarity caps by world | On | Turned off by a flag | Later worlds were not ready; players were stuck under a cap with nothing to chase |
| Temporary luck charm | 20x to 100x | 3x to 10x | Stacked luck collapsed the ladder |
| Enemy tempo when aggroed | Slow | Faster (cooldown multipliers 0.4 to 0.6) | "Enemies should attack quicker when aggroed" |
| Gate pricing | ~8x per zone | 2.6x per zone formula | A 30-zone ladder needs a gentler curve |
| Enemy scale | 2.3x bigger | 30% smaller again | Readability and arena space |
| Duplicates | Clutter | Fusion stars, tier-up crafting, auto-salvage | "What do players do with swords they don't use?" |
| Top-tier presentation | Mixed | Every Legendary or higher must be animated | Rarer must look better |

Patterns in that list worth generalising:
- **Most changes were pacing and feel, not features.** Reveal length, enemy tempo and gate curves are config numbers. Keep them in config; you will change them.
- **Caps and gates need content behind them.** Two of the changes (caps off, new gate curve) were reactions to content not keeping up with the ladder. A teardown of your own game should ask, per gate, "what is behind it today?"
- **Inflationary items get cut.** Any luck source above about 10x was eventually reduced. Plan maximum stacked luck before launch ([[Rarity Ladders and Drop Pacing Math]] section 5).

### Monetisation map (measured configuration, Robux)
| Touchpoint | Product | Price | Kind |
|---|---|---|---|
| Roll speed | Fast Roll pass | 299 | Friction removal |
| Roll count | Double Roll pass | 599 | Throughput |
| Luck | Lucky Rolls pass | 75 | Probability modifier (disclosure) |
| General | VIP pass (x2 cash, x1.5 XP, x1.1 luck and more) | 399 | Multiplier bundle |
| Potions | Super Potions pass (potions last 2x) | 199 | Duration |
| Server | Server Luck Boost product | 99 | Shared, social |
| Rolls | Jackpot Roll product | 499 | Paid random item (disclosure) |
| Bundle | Top item plus permanent 2x luck plus gems | 1,499 | Anchor |
| Direct | Exclusive weapon | 799 to 999 | No randomness |
| Currency | More Cash | 79 | Time saving |

Teardown reading: speed and throughput passes sit on the inner verb (bought by players who already love rolling); luck products sit directly on the gamble and carry the heaviest disclosure obligations ([[Genre Playbook - RNG and Collection Games]] section 9); the bundle anchors high-value perception; direct exclusives are the cleanest offer. A competitor teardown should fill the same table and note which touchpoints interrupt play.

### The hybrid's structural cost
The hybrid's differentiator (every rolled weapon has its own animated ability kit) is also its biggest cost: each new item needs animation, VFX, sound and balance, where a pet simulator's new pet is mostly a model and a number. Teardown question for any hybrid: **what does one new collectible cost to make, and how many does the ladder consume per month?** If the answer is "a week each" and the ladder needs ten a month, the content cadence will fail before the design does ([[Planning and Scoping a Roblox Game]]).

---

## 6. Where these genres structurally fail

| Failure | Teardown signal | Root cause |
|---|---|---|
| Number fatigue | Prices with long suffixes, players ignore the HUD | Growth with no new mechanic per step |
| The empty server | Players spread over 20 zones; hub empty | Too many zones per region; no shared activities |
| AFK economy | Many players idle on auto | Auto features with no active advantage |
| Top-end collapse | Top tiers common in chat broadcasts | Luck inflation |
| Inventory flood | Phone inventory unusable, constant "full" prompts | No duplicate sink, no filters |
| Update treadmill | Each update is "new zone, bigger numbers" | No meta systems; content cost too high |
| Trust erosion | Odds complaints, refund requests | Unclear odds, near-miss reels on paid rolls, aggressive prompts |

On AFK: auto features are expected in these genres, but an active player should earn noticeably more than an idle one (rule of thumb: 1.5x to 3x), or the optimal strategy is to not play. Roblox disconnects players after a period of inactivity (long-standing behaviour, commonly cited as about 20 minutes; not re-verified for this note), which shapes how "AFK farming" works in practice and is why some games add anti-idle inputs. Do not design around evading the idle disconnect; design so that being present is worth it.

On the empty server: zone ladders spread players out. Shared activities (a hub with stations, server-wide events, the group boss pattern) pull them back together. **Measured:** the reference project's half-hourly pop-up boss and server-visible effects for rebirths and rare pulls were partly aimed at this ([[Social Design and Multiplayer Play]]).

---

## 7. Turning a teardown into decisions

A teardown that ends as a document changes nothing. End it with three lists:

1. **Steal**: mechanics or numbers that clearly work and fit your game (for example "their next-goal panel on every gate").
2. **Avoid**: things that work for them but conflict with your audience or ethics (for example "pop-up offers on every join").
3. **Measure in ours**: the same clocks for your own game, so the comparison is numbers to numbers. Instrument them with analytics events ([[Analytics and Funnels]]): time to first upgrade, first random reward, first gate, first long-loop reset, and D1 return.

Compare clocks, not features. If your zone loop is 45 minutes and the competitor's is 15, adding their feature will not close the gap; changing your price curve might.

---

## 8. Common mistakes

| Mistake | Better |
|---|---|
| Copying features without measuring clocks | Stopwatch log first, feature list second |
| Tearing down only on PC | Phone first; most of the audience is there |
| Judging monetisation by price alone | Map where each prompt sits in the loop and whether it interrupts |
| Assuming a competitor's odds labels are its real odds | Labels depend on the roll algorithm ([[Genre Playbook - RNG and Collection Games]] section 3) |
| Treating big numbers as free | Exactness ends at 2^53; plan representation and display |
| Price curve per zone typed by hand | One formula with overrides, checked against income growth |
| A teardown with no decisions | Steal, avoid, measure-in-ours lists |

## 9. Teardown worksheet (copy per game)
- [ ] Platform and device used; date (as of when the numbers were seen).
- [ ] Clocks: inner, upgrade, zone, long, meta (with timestamps).
- [ ] First 15 minutes beat log; count of "did not know what to do" moments.
- [ ] Price growth per step and income growth per step; their ratio.
- [ ] Multiplier sources and how they combine; maximum observed totals.
- [ ] Rarity ladder: tiers, labelled odds, luck sources, caps, pity.
- [ ] Duplicate handling and inventory UX on phone.
- [ ] Monetisation map: touchpoints, prices, interruptions, disclosure quality.
- [ ] Social hooks: broadcasts, trading, shared events, group or friend boosts.
- [ ] Return hooks seen on the next-day session.
- [ ] Steal, avoid, measure-in-ours lists.

## See also
[[Genre Playbook - Simulators]] · [[Genre Playbook - RNG and Collection Games]] · [[Rarity Ladders and Drop Pacing Math]] · [[Boss Fight Design Patterns]] · [[Core Loops and Session Design]] · [[Progression and Pacing Design]] · [[Balancing with Spreadsheets and Data]] · [[First-Time User Experience and Onboarding]] · [[Retention and Return Hooks]] · [[Monetization Overview]] · [[Pricing and Store Design]] · [[Analytics and Funnels]] · [[Ethical Design and Player Trust]] · [[Post-Mortem - Building a Melee Action Game]]

## Connected notes
<!-- auto-links:start -->
[[Progression Levels and Unlocks]] · Economy Inflation Sinks and Faucets Math · RNG Drops and Luck Systems · Core Loop · Rebirth and Prestige System End to End · Pricing Curves and Upgrade Costs
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[RNG Drops and Luck Systems]] · [[Economy Inflation Sinks and Faucets Math]] · [[Onboarding by Genre - The First Five Minutes]] · [[Genre Playbook - Combat and RPG]] · [[Genre Playbook - Tycoons]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Genre Playbook - Survival and Crafting]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Party and Minigame Collections]]
<!-- related:end -->
