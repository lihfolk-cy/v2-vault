---
tags: [teardown, viral-trend, plus-one, incremental, obby, simulator, cosmetics, live-ops, type/case-study, area/design, level/intermediate, area/liveops]
verified: 2026-10-29
---

# Teardown - +1 Speed Keyboard Escape

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client reports its own speed -> credit speed on the server from movement
> - Avoid: Thin parts at high speed -> thicker collision, simpler geometry
> - Avoid: Every cosmetic is expensive -> a ladder from tiny to premium
> - Does the speed counter visibly grow in the first five seconds?
> - Does higher speed change how the course plays?
> - Is speed credited by the server from real movement?
>
> Cost: TL;DR ~140 tok · whole note ~3.1k tok. Read more: ## Snapshot · ## Monetization and 2026 compliance · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **In one line:** every step you take adds +1 speed, and you use that ever-growing speed to cross a giant obstacle course built from keyboard keys, where one slip sends you back to the start.

This is the biggest "+1 per second" game so far. The +1 format (a stat that grows by itself every second or every step, usually wrapped in an obby) existed since at least 2022 (research module, 2026-10-28). This game paired it with a recognisable object (a keyboard), a sensory theme (key clicks, candy visuals) and an enormous cosmetic catalogue. It is the clearest proof in this section that *cosmetics-first* monetization can sit on a multi-million CCU hit.

Labels: **Measured**, **Roblox docs**, **Rule of thumb**, **Unverified** ([[Viral and Trend Teardowns Start Here]]).

## Snapshot

| Fact | Value | Label | Source and date |
|---|---|---|---|
| Created | 2026-01-18 | Measured | Roblox game API, 2026-10-29 |
| Current full title | "+1 Speed Keyboard Escape \| Candy & Chocolate" (theme suffix changes per world) | Measured | Roblox game API, 2026-10-29 |
| Owner group | SecretVerse Studio | Measured | Roblox game API, 2026-10-29 |
| Genre on Roblox | Simulation / Incremental Simulator | Measured | Roblox game API, 2026-10-29 |
| Server size | 22 players | Measured | Roblox game API, 2026-10-29 |
| Playing now | 24,955 (08:06 UTC Thursday) | Measured | Roblox game API, 2026-10-29 |
| Visits | 6,609,674,343 | Measured | Roblox game API, 2026-10-29 |
| Favourites | 7,216,968 | Measured | Roblox game API, 2026-10-29 |
| Votes | 10,072,796 up / 340,320 down, about 96.7% positive | Measured (computed) | Roblox votes API, 2026-10-29 |
| All-time peak CCU | 7,263,327 on 2026-07-18 | Measured (tracker) | Rolimons listing, seen via search 2026-10-29 |
| Other peak reports | 5.62M on 2026-06-28 ("5th biggest by peak" at the time); about 6.2M "in August 2026" | Measured (tracker post) / Unverified (conflicting date) | RblxTracker on X; The Bloxline, 2026-08-12 |
| Concert peak | 6,355,764 during a bbno$ virtual concert, 2026-07-25 | Unverified | Roblox Fandom wiki, 2026 |
| Average playtime | about 9 minutes | Measured (tracker, as reported) | Rolimons via The Bloxline, 2026-08-12 |
| Recent level | 68.9k players, 15th on Roblox | Measured (tracker) | RoCodes, 2026-10-20 |
| Public game passes | 64 listed: treadmills (Gold 79 to ADMIN 1,199), trails and auras (19 to 2,999), Wins Multiplier x2 95, More Equipped Items 299, Premium Trade Booth 159, Unlock Soundpacks 85; tiered Speed Multiplier passes and event passes currently off sale | Measured | Roblox game-pass API, 2026-10-29 |

## Core loop

```text
 move ──► +1 speed per step ──► attempt keyboard course
   ▲                                   │
   │                         fall ─────┤──── finish ──► win (+wins, unlock next world)
   │                           │              │
   │                     back to start        ▼
   │                                  wins buy multipliers / treadmills
   └──── faster gain ◄──── multipliers, treadmills, equipped items
```

The twist that makes it a game and not an idle screen: **more speed makes the course harder to control.** Progress raises your power and your difficulty at the same time.

## First 60 seconds

1. You spawn and walk. The speed counter ticks up with each step; the feedback is a satisfying key-click sound.
2. The course is right there. You try it within seconds.
3. You fall, you reset, and you notice you are already faster. The failure *is* the progress.
4. A treadmill or multiplier is visible near spawn, the first upgrade decision.

The Bloxline's analysis credits near-zero learning curve, constant progression and the sensory feedback (Unverified as causes; it is an editorial reading).

## Progression and economy

- **Speed** is the core stat and grows from movement. Multipliers and treadmills raise the per-step gain.
- **Wins** come from finishing courses and gate new themed worlds (the title suffix "Candy & Chocolate" is one world theme).
- **Equipped items** (trails, auras, treadmills) add multipliers and status; an equip-slot pass raises the cap to 20.
- **Trading** exists in some form: a "Premium Trade Booth" pass is listed (Measured), so cosmetic items circulate between players.
- **Rarity table:** not public. The catalogue is mostly fixed-price, not random.

## Monetization and 2026 compliance

This is the most interesting store in the section. With 64 passes, almost everything is a **fixed-price cosmetic or self-only multiplier**:

- Trails and auras from 19 to 2,999 Robux create a wide **price ladder** where every budget finds a purchase. Spend *days* per user is a discovery signal in its own right (Roblox docs, 2026-06-15), so many small, clearly valued items help.
- **No random items are visible in the pass list.** Fixed-price cosmetics need no odds disclosure. If eggs or crates exist as developer products, they would need the full paid-random-item treatment ([[Paid Random Items and Odds Disclosure in Practice]]).
- **Trade booths and paid items:** if paid cosmetics are tradable, gate trading with `IsPaidItemTradingAllowed` separately from random-item checks (Roblox docs; [[Regional Compliance - Paid Random Items and Country Rules]]).
- **Group-join gift** in the description is a common, permitted growth tactic; keep the reward modest and never tie it to ads for under-13s (Roblox docs, Advertising Standards; [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]]).

## Retention hooks

- **Themed worlds** refresh the course and the title suffix each major update.
- **Short attempts:** about 9-minute average sessions match RFY's preference for several daily returns over marathons (Roblox docs: playtime credit capped at 60 minutes per user per day).
- **Live spectacle:** a musician concert inside the game in July 2026 (Unverified peak figure).
- **Visible status:** 22-player servers full of trails and auras make cosmetics social proof.

## Multiplayer and social design

The large 22-player server is a stage. Everyone runs the same course, so you see faster players with flashier trails ahead of you. Racing friends is built in ("race against friends" in the description). There is no harmful interaction between players; competition is purely comparative.

## Art, UI, title and thumbnail

- **Title formula:** "+1 [stat] [object] [verb]" plus a theme suffix after a separator. The "+1" prefix became a genre label: on the snapshot day the charts also showed +1 Venom Evolution, +1 Anime Eyes and +1 Upgrade Per Kill (Measured, Roblox explore API, 2026-10-29).
- **Object-as-world:** a keyboard is recognisable in a 150-pixel thumbnail and in a short video, which the Bloxline article points out.
- **Sound as a selling point:** the store description advertises satisfying key sounds. Audio is part of the pitch, unusual and effective.

## Technical notes

- **Speed exploit pressure:** high speeds are legitimate here, so detection must compare against the player's *server-known* speed, not a global cap ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).
- **High-speed physics:** characters moving very fast can tunnel through thin parts. Thicker collision, fewer tiny parts and server-side checkpoint validation help ([[Physics Performance]]).
- **22-player servers with trails and auras:** budget particle counts per player and let players hide others' effects ([[Graphics and Performance Toggles for Low-End Devices]]).

```lua
--!strict
-- Server-side +1 per step: grant speed by distance actually travelled, capped per tick.
local MAX_STEP_PER_TICK = 40 -- studs, rule of thumb for a fast character

local function speedGain(lastPos: Vector3, newPos: Vector3, multiplier: number): number
	local moved = (newPos - lastPos).Magnitude
	local credited = math.min(moved, MAX_STEP_PER_TICK)
	return math.floor(credited / 4) * multiplier -- one "step" per 4 studs
end

return { speedGain = speedGain }
```

## Why it went viral

1. **The +1 promise is the shortest hook on Roblox.** You are always getting stronger, even while failing.
2. **A twist that creates skill.** More speed is harder to steer, so the obby never becomes trivial.
3. **A concrete, sensory theme.** A keyboard you can hear; candy you can almost taste. It stands out from abstract "+1" obbies.
4. **Timing.** Created in January 2026, during the brainrot cool-down, it gave the same young audience a non-meme, non-theft loop.
5. **Events.** A concert during the July 2026 surge (Unverified figures).

## Build it yourself

| System | Notes | Vault notes |
|---|---|---|
| +1 stat from movement | Server credits distance travelled, capped | [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] |
| Course with reset on fall | Kill bricks or fall volume, return to start | [[Obby and Platforming Level Design]] |
| Wins and world unlocks | Server-validated finish line | [[Obby Checkpoints and Stage Saves End to End]] |
| Multipliers, treadmills, equip slots | Data-driven, stacking rules | [[Rebirth and Prestige System End to End]] |
| Cosmetic shop ladder | Fixed prices, many tiers | [[Shop with Game Passes and Developer Products End to End]], [[Robux Price Points and Offer Design]] |
| Trade booth | Server-side atomic swaps | [[Trading Systems Without Duplication]] |
| Leaderboard for fastest | OrderedDataStore | [[Global Leaderboards End to End]] |

## Raise the quality bar

- **Design the course for speed.** Wider platforms at high-speed sections, readable landing zones and a "slow walk" toggle let players control their power.
- **Give falls a soft landing.** Partial checkpoints for younger players, or an optional "practice mode", widen the audience without removing the challenge.
- **Make each world a new idea.** Ice keys, bouncing keys, moving keys: new movement rules beat bigger numbers.
- **Accessibility for sound-led design:** subtitles or visual cues for audio feedback, and a volume slider per sound group.

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Client reports its own speed | speeds far above the server's record | credit speed on the server from movement |
| Thin parts at high speed | players clip through floors | thicker collision, simpler geometry |
| Every cosmetic is expensive | low spend days | a ladder from tiny to premium |
| Paid cosmetics tradable without a policy check | region complaints | gate trading with `IsPaidItemTradingAllowed` |
| Same course, bigger number each update | sessions shrink | new movement rule per world |

## Checklist

- [ ] Does the speed counter visibly grow in the first five seconds?
- [ ] Does higher speed change how the course plays?
- [ ] Is speed credited by the server from real movement?
- [ ] Is there a cosmetic for every budget, with no random item unless disclosed?
- [ ] Can players hide other players' trails and auras for performance?
- [ ] Is each new world built around a new movement idea?

## See also

- [[Viral Game Anatomy - Hooks, Loops and Timing]]
- [[Teardown - Tower of Hell]] (the obby classic it borrows tension from)
- [[Teardown - Tap Simulator REBORN]] (the clicker cousin)
- [[Genre Playbook - Obbies and Platformers]]

## Sources

- Roblox public game, votes, game-pass and explore APIs, read 2026-10-29 08:06 UTC.
- Rolimons listing for place 95082159892680, seen via search 2026-10-29.
- RblxTracker post on X, 2026-06-28.
- The Bloxline, "+1 Speed Keyboard Escape has become one of Roblox's biggest games. Here's why it works", 2026-08-12.
- Roblox Fandom wiki page for the game (concert figure, Unverified), seen 2026-10-29.
- RoCodes, 2026-10-20.

<!-- related:start -->
## Related
[[Teardown - Escape Tsunami for Brainrots]] · [[Teardown - Steal An Egg]] · [[Teardown - Plants vs Brainrots]] · [[Teardown - Fish It]] · [[Teardown - Ride A Pet]] · [[Teardown - Sol's RNG]] · [[Teardown - Build A Boat For Treasure]] · [[Teardown - Fling Things and People]]
<!-- related:end -->
