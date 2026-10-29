---
tags: [game-design, onboarding, ftue, tutorial, genres, first-session, retention, simulator, tycoon, obby, combat, horror, roleplay, tower-defense, trend-games, type/guide, area/design, level/intermediate]
verified: 2026-10-29
---
# Onboarding by Genre - The First Five Minutes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Same tutorial template for every genre -> Start from the genre row above
> - Avoid: Tutorial gate in a roleplay game -> Props and friends from second one
> - Avoid: First combat at full strength -> A weak, owned first enemy
> - The five-minute script table is written for this game.
> - The genre's first-30-seconds action happens on time.
> - The genre-specific risk has a named counter-measure.
>
> Cost: TL;DR ~140 tok · whole note ~2.2k tok. Read more: ## 1. The genre table · ## 2. Genre by genre · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The principles in [[Onboarding and FTUE - Tutorials That Keep Players]] hold everywhere, but the **shape** of a good first five minutes depends on the genre. A simulator lives on numbers rising every few seconds; a horror game lives on dread that builds; a roleplay town has nothing to teach before play. This note gives the target feel of the first five minutes per genre, what to teach and what to leave, the genre-specific failure, and which case study or teardown shows it done well.

Trust labels: **Rule of thumb** for timings (tune them with your funnel), **Observed** for descriptions drawn from the case studies and teardowns (sections 32, 59, 60; those notes give their own sources), **Unverified** where the source note says so.

---

## 1. The genre table

| Genre | First 30 s | By 5 minutes | Teach later | Genre-specific risk |
|---|---|---|---|---|
| Simulator / idle | First collect | Collect, sell, upgrade, first pet or egg; loop closed 3+ times | Rebirth, trading, zones beyond the first | Long walk to the first pad; shop before the first sale |
| Tycoon | First dropper or plot claimed | First upgrade bought from income; the next purchase visible with a price | Rebirth, automation | Empty plot with nothing affordable |
| Trend / viral (steal, escape, grab) | The title verb | First risk event survived or lost with a clear lesson; first stash secured | Defence upgrades, rarer variants | Robbed by a far richer player in minute one |
| Obby / platformer | Moving and jumping | Several checkpoints; first new mechanic shown, tried, tested | Skips, speedrun routes | A hard jump before the first checkpoint |
| Combat / RPG / battlegrounds | First hit lands | First kill of a weak owned enemy; one ability used; one upgrade | Combos, builds, PvP | Full-strength enemies; five abilities at once |
| Horror / story | Atmosphere, no threat | First threat met with a long warning and a visible counter; first death explained | Rare entities, lore | An unfair first death with no lesson |
| Social / roleplay | Owning something | House, car or outfit; a role picked; first interaction with another player | Jobs, premium items | Any gate before the props and friends |
| Tower defense | First tower placed | First waves won with a pointer to a good spot; one upgrade | Tower synergy, modes | Losing wave 1 or reading every stat first |
| Survival / co-op | First resource gathered | Shelter or fire; first night or threat survived with friends | Crafting trees | A lonely, dark start with no direction |

## 2. Genre by genre

**Simulator and idle.** The tutorial is the loop itself. Point to the first collectable within a step or two of spawn; make the first sale pay enough for the first upgrade; let the first pet or egg arrive inside the first few minutes as the big reward. Grow a Garden teaches buy, plant, harvest, sell and upgrade without a tutorial screen (**Observed**, [[Case Study - Grow a Garden]]); Pet Simulator 99 fits verb, reward, gate, goal and premium currency inside five minutes (**Observed**, [[Case Study - Pet Simulator 99]]). See [[Genre Playbook - Simulators]].

**Tycoon.** Claiming a plot is the first action; the first dropper should produce income the player can see within seconds. Always show the next purchase with its price so the player knows what they are saving for. See [[Genre Playbook - Tycoons]].

**Trend and viral games.** These live or die in the first 30 seconds because players arrive from a trend and expect the verb from the title right away. Plants vs Brainrots closes its loop inside the first minute; Steal An Egg's first chase teaches the risk with no text; Escape Tsunami for Brainrots uses the first wave to teach "carried is at risk, placed is safe" (**Observed**, [[Teardown - Plants vs Brainrots]], [[Teardown - Steal An Egg]], [[Teardown - Escape Tsunami for Brainrots]]). Protect newcomers from much richer players with a grace window or theft limits (**Rule of thumb**, [[Case Study - Steal a Brainrot]]).

**Obby and platformer.** No text about jumping. The first jumps are shaped so failing is cheap and the first checkpoint arrives within about 20 seconds (**Rule of thumb**). Each new mechanic gets a show, try, test sequence ([[Teaching Through Level Design]], [[Genre Playbook - Obbies and Platformers]]).

**Combat, RPG and battlegrounds.** The first enemy is weak and belongs to this player alone; one ability is taught at a time. The Reference project in [[First-Time User Experience and Onboarding]] saw its biggest funnel losses at combat steps and moved economy teaching onto safe ground first (**Reference project**). The Strongest Battlegrounds shows the other end: no grind before fun, a combo possible in minute one (**Observed**, [[Case Study - The Strongest Battlegrounds]]). See [[Genre Playbook - Combat and RPG]].

**Horror.** Quiet first rooms; the first threat arrives with a long, readable sound and light warning and a counter visible nearby. When the player dies, one sentence explains what killed them and how to survive (**Observed**, [[Case Study - Doors]], [[Teardown - Pressure]], [[Teardown - Grace]], [[Teardown - Dandy's World]]). Teach the cost of a mistake before the threat appears. See [[Genre Playbook - Horror and Story]].

**Social and roleplay.** Zero gate. Brookhaven gives a house or car within about 30 seconds and teaches nothing up front, because the props are the game (**Observed**, [[Case Study - Brookhaven RP]]). Adopt Me uses a scripted first success: the first task cannot fail and pays immediately (**Observed**, [[Case Study - Adopt Me]]). Dress to Impress uses a theme and a timer as onboarding, so nobody faces a blank page (**Observed**, [[Case Study - Dress to Impress]]). See [[Genre Playbook - Roleplay and Social Hangouts]].

**Tower defense.** Pointer to a strong first placement, a first wave that cannot be lost, one upgrade before wave 3 (**Rule of thumb**). Stats and synergies come later as contextual tips. See [[Case Study - Tower Defense Simulator]] and [[Genre Playbook - Tower Defense]].

**Survival and co-op.** The first night or threat should arrive inside the first few minutes and be survivable with friends; light and sound teach what matters (**Observed**, [[Case Study - 99 Nights in the Forest]]). See [[Genre Playbook - Survival and Crafting]].

## 3. A five-minute script template

Write this table before building any tutorial. If a row is empty, that is the gap.

| Time | Player does | Player gets | On screen |
|---|---|---|---|
| 0 to 10 s | Spawns facing the target | Control | One objective |
| 10 to 30 s | First verb | First small reward | Pointer to the target |
| 30 to 60 s | Repeats the verb, then spends | First big reward | Counter, then a reveal |
| 1 to 3 min | Closes the core loop | A new capability | The next HUD button |
| 3 to 5 min | Chooses something | Their first "build" | The next goal with a price |

## Common mistakes

| Mistake | Better |
|---|---|
| Same tutorial template for every genre | Start from the genre row above |
| Tutorial gate in a roleplay game | Props and friends from second one |
| First combat at full strength | A weak, owned first enemy |
| First horror death with no explanation | One sentence: what killed you, how to survive |
| New player robbed by a veteran | Grace window or income-gap limits |
| Tower defense wave 1 can be lost | A guaranteed first win with a placement pointer |

## Checklist

- [ ] The five-minute script table is written for this game.
- [ ] The genre's first-30-seconds action happens on time.
- [ ] The genre-specific risk has a named counter-measure.
- [ ] Depth is listed under "teach later" and arrives as contextual steps.
- [ ] One case study or teardown of the same genre has been read and compared.

## See also

[[Onboarding and FTUE - Tutorials That Keep Players]] · [[First-Time User Experience and Onboarding]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[Measuring Onboarding - Funnels, Drop-off and A-B Tests]] · [[Core Loops and Session Design]] · [[Simulator and RNG Genre Teardown]] · [[Social Design and Multiplayer Play]] · [[Top Games Case Studies Start Here]]

<!-- related:start -->
## Related
[[Genre QA Passes - Test Checklists per Game Type]] · [[Viral Game Anatomy - Hooks, Loops and Timing]] · [[Retention and Return Hooks]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Genre Playbook - Open-World City and Crime Roleplay]] · [[Progression and Pacing Design]] · [[Boss Fight Design Patterns]] · [[Genre Playbook - Social Deduction and Murder Mystery]] · [[Genre Playbook - Party and Minigame Collections]]
<!-- related:end -->
