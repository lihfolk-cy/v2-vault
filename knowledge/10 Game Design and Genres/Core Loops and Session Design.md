---
tags: [game-design, core-loop, sessions, retention, roblox-audience]
---
# Core Loops and Session Design

A Roblox game lives or dies on one question a player answers in their first few minutes: "what do I do here, and why do it again?" The **core loop** is the answer. This note explains how to design loops in layers, how to fit them to the Roblox audience (young, mostly on phones, playing with friends, arriving from a recommendation feed), how to shape a single session so it ends with a reason to come back, and how to tell when a loop is broken.

Source labels used in this section:
- **Docs**: official Roblox guidance on create.roblox.com (mainly the Production > Game design and Analytics pages). Checked October 2026.
- **Reference project**: one live action game whose design history is used throughout this folder (anonymised).
- **Rule of thumb**: experience, not a platform rule. Tune it with your own data.

---

## 1. What a core loop is (and is not)

Roblox's own definition splits the core loop into three parts (Docs, "Core loops"):

| Part | Question it answers | Action RPG example (Docs) |
|---|---|---|
| Minute-to-minute interaction | What am I doing right now? | Explore |
| Most repeated set of actions | What do I do most? Usually the defining mechanic | Fight (dodge, strike, guard) |
| Progression engine | Why does doing it again feel different? | Upgrade (levels, skills) |

The docs warn that without the progression engine a game becomes "repetitive, boring, and shallow". That is the most common failure on Roblox: a fun verb with nothing that changes as you repeat it.

A core loop is **not** a feature list. "Pets, trading, rebirths, quests, codes, daily rewards" describes systems, not a loop. Write the loop as one sentence with verbs and a feedback arrow:

> Roll for a weapon, fight enemies with it, earn cash, spend the cash on gates and upgrades so you can fight harder enemies that pay more, and roll again with better luck.

If you cannot write that sentence, players cannot feel it either.

### The loop sentence test
Read your sentence and check each arrow:

| Check | Pass looks like | Fail looks like |
|---|---|---|
| Every verb is something the player does with their hands | "roll", "swing", "jump", "place" | "progress", "engage", "grind" |
| Every output feeds an input | cash buys the gate that leads to richer enemies | cash piles up with nothing worth buying |
| Something visibly grows | bigger numbers, new zone, new weapon on screen | invisible stat changes |
| The loop closes in under a minute at the start | first reward within 30 seconds | first reward after a 3-minute tutorial |

---

## 2. Loops come in layers

Good Roblox games stack loops of different lengths. Each layer feeds the next one up. The reference project wrote its plan as four layers, which is a useful template:

| Layer | Length | Reference project | What it must deliver |
|---|---|---|---|
| Micro | 5 to 30 s | roll a weapon, fight the next 1-2 enemies, earn cash, XP and materials | Feedback every few seconds: hit sparks, damage numbers, coin pops |
| Short | 5 to 10 min | spend on forge, skills and armour so power passes the next wall; open the next gate | A visible step up (new zone, new tier) |
| Session | 15 to 45 min | when stuck: train on dummies, do quests, brew potions, push luck for a better blade | A reason to stay when the short loop stalls |
| Long | days to weeks | rebirth at a boss wall for permanent multipliers; next realm; exclusives, the index, leaderboards | A reason to come back tomorrow |

Two design consequences:

1. **Every layer needs its own reward cadence.** If the micro loop gives cash every 3 seconds but the short loop gives nothing for 20 minutes, players experience the 20 minutes as a grind. Put a visible milestone (gate, tier, new enemy, quest chest) inside every short-loop window.
2. **The long loop must be visible from the micro loop.** A player in minute 2 should be able to see the realm portal, the rebirth button (locked), the rarity ladder on the roll screen, or a leaderboard. The docs' onboarding page asks for short, mid and long-term goals to be "visible in the game world or UI" (Docs, "Onboarding").

### Secondary loops
Most hit games have 2 to 4 secondary loops that hang off the core: crafting, brewing, fishing, collection indexes, trading. They exist to give **a different verb when the main verb stalls**. In the reference project, players blocked by a zone gate could brew a luck potion, fish in the hub (an AFK activity), or work a daily quest. Rule of thumb: a secondary loop must feed back into the core (potions raise luck for rolls; fishing pays cash), or it becomes a distraction players skip.

---

## 3. Fit the loop to the Roblox audience

Roblox players are not a generic "gamer" audience. The docs page "Design for Roblox" is qualitative but clear:

| Audience fact (Docs) | Design consequence |
|---|---|
| "Most users play Roblox on mobile devices." | One-thumb verbs, big buttons, short loops that survive interruptions. See [[Responsive UI for Phone Tablet Console and PC]] |
| Users move between games, often with friends; long tutorials lose them | First reward inside 30 to 60 s, teach by doing ([[First-Time User Experience and Onboarding]]) |
| Social play drives retention; single-player games often struggle | Make other players visible and useful to you ([[Social Design and Multiplayer Play]]) |
| Younger users prefer exploration, experimentation and socialising over competition | Low-stakes failure, collection, self-expression |
| "Tourists" sample many games; "locals" focus on a few and are almost the whole engaged base | The first session converts tourists; the long loop keeps locals |
| The audience is ageing; older users invest more in engagement and spending | Depth (builds, trading, mastery) for the long loop |
| Players follow YouTubers into games | Moments worth recording: rare pulls, boss kills, big reveals |

### How discovery rewards loops
The Home "Recommended for You" sort ranks games on per-user averages (Docs, "Discovery", October 2026). The signals it lists as most important are:

- **Play through rate**: how often users who see your game in the sort actually play it.
- **First play bounce rate** (negative), measured for sessions under 60 seconds and 61 to 180 seconds.
- **Play days per user** for Day 1, Days 2-7 and Days 8-28.
- **Playtime per user**, capped at 60 minutes per user, per game, per day.

Then, as "important": intentional co-play days, qualified play sessions, spend days and Robux spent per user.

What that means for loop design (interpretation, not Roblox's words):
- The **first 60 and 180 seconds** are measured directly. The micro loop must close inside the first minute. See [[First-Time User Experience and Onboarding]].
- **Play days** beat marathon sessions. A loop that brings a player back on 5 separate days does more than one 5-hour binge. See [[Retention and Return Hooks]].
- **Playtime is capped at 60 minutes a day per user**, so stretching sessions past an hour (for example with AFK farming) earns nothing for ranking. Designing for 20 to 45 good minutes and a clean exit hook is the better trade.
- **Co-play days** are an explicit signal. Loops that are better with a friend help discovery as well as retention.

Full detail lives in [[Discovery and the Algorithm]] and [[Analytics and Funnels]].

---

## 4. Designing a loop step by step

### Step 1: pick the verb and make it feel good alone
Before economy or progression, the verb must be satisfying with no rewards attached. Prototype the swing, the jump, the roll animation, the dropper. Rules of thumb for "feel":
- Input to visible response in under 100 ms (client-side prediction or a local effect, with the server confirming). See [[Server Authority and Validation]] for how to keep that secure.
- Every action gets three kinds of feedback: visual (flash, particles), audio (a short sound), and numeric (a number that pops). See [[Game Feel and Juice]].
- Variation: randomise pitch, pick from 3 or more animation variants, vary particle size.

### Step 2: attach a reward with a clear unit
Decide the unit the verb produces: cash per kill, coins per tile, studs climbed, items rolled. One verb, one primary unit. Secondary units (XP, materials, gems) can drop from the same verb but at a lower cadence.

### Step 3: give the reward somewhere to go
List every sink. A loop without sinks ends the moment the player notices the number is meaningless. Sinks that also raise power close the loop; cosmetic sinks extend it. See [[Economies and Currencies]].

### Step 4: make the spend change the verb
The spend must change how the verb feels or what it can reach: a bigger sword, a faster roll, a new zone with new enemies. A +3% stat upgrade the player cannot perceive does not close the loop. Rule of thumb: every 5 to 10 minutes of play should buy at least one change the player can **see**.

### Step 5: add a wall and a way around it
Walls (a gate price, a boss, a recommended-power number) give the short loop its shape. Every wall needs at least two ways past it: grind the core verb, use a secondary loop, or reset for a multiplier (rebirth). The reference project learned this the hard way (section 7).

### Step 6: connect the long loop
Rebirth/prestige, new realms, collections, leaderboards and social status. See [[Progression and Pacing Design]].

---

## 5. Session design

A **session** is one visit, from join to leave. Loop design decides what players do; session design decides how a visit **feels from start to end**.

### The session arc

| Phase | Typical length (rule of thumb) | What to give the player |
|---|---|---|
| Arrival | 0 to 30 s | Fast join, spawn facing the main action, no pop-up stack |
| Re-orientation | 30 s to 2 min | "Here is where you were": a goal card, offline earnings, daily reward |
| Warm-up | 2 to 5 min | An easy, guaranteed win (a quest that is almost done, a free gift) |
| Main push | 5 to 30 min | The short loop: next gate, next tier, next boss |
| Peak | anywhere | One memorable moment: rare pull, boss kill, rebirth burst |
| Exit hook | last 2 min | A timer or unfinished goal that resolves next visit |

The arrival phase is mostly engineering: see [[Case Study - Fast Join and Deferred Loading]]. The reference project capped its loading screen at 12 s, allowed a skip after 5 s, and let new players in at 8 s, because every second before the first input counts against the bounce-rate signal.

### Pop-up discipline
Return visits tempt designers to stack daily reward, offline earnings, an update log, a sale and a "favourite this game" prompt. The reference project ended up with one rule (a "pop-up gate") for every automatic pop-up:
- never during onboarding (if onboarding state is missing, treat the first 180 s as onboarding);
- never over another panel, a roll reveal, a cutscene or a death screen;
- never in combat;
- never within 8 s of another automatic pop-up;
- the favourite prompt asks new players 25 s after they finish the tutorial, returning players after 180 s.

That rule is a good default for any game. See [[HUD Design]].

### Designing for mobile interruptions
Phone sessions end without warning (a notification, a parent, a dying battery). Rules of thumb:
- **Save state continuously** (progress counters, not just currency). See [[Saving Correctly - Autosave and BindToClose]].
- **No progress that only pays at the end** of a 10-minute run unless the run is the genre (obby stages and round games instead checkpoint).
- **Rejoin lands you near where you left**, or one tap away (fast travel to the furthest unlocked zone).
- Respawn in seconds. The reference project's death flow respawns in 3 s plus a 2 s shield in its PvP arena.

### The exit hook
End every session with something unfinished and time-bound: a free gift ready in 4 minutes, a daily quest at 2/3, a potion brewing, an offline vault filling. These are covered in [[Retention and Return Hooks]]. Avoid hooks that **punish** absence (losing a streak with no recovery, decaying items). They work in the short term and damage trust; see [[Ethical Design and Player Trust]].

---

## 6. AFK loops: when to allow them

Roblox has a strong AFK culture (auto-roll, auto-farm, idle fishing). There are real reasons: children leave devices running, players want progress while they do homework, and auto-modes help players with motor difficulties. There are also costs.

| Pro | Con |
|---|---|
| Accessibility; progress without fine motor control | Servers fill with idle avatars, so the game feels dead to new players |
| Rewards loyal players | Playtime beyond 60 min/day does not count for discovery (Docs) |
| Lets players keep a slow resource ticking | AFK income inflates the economy if it rivals active play |

Guidelines (rule of thumb, matching the reference project):
- **AFK yields less than active play.** The reference project's offline vault pays 15% of active cash per minute, caps at 8 hours (12 with VIP), and pays nothing for absences under 5 minutes.
- **AFK activities live in social spaces.** Put the AFK fishing pond or training dummies in the hub, where idle players at least make the hub look alive.
- **Auto-actions keep the verb visible.** An auto-roll that still plays a small reel over the head is a moving billboard for the roll mechanic.
- **No AFK before onboarding is done.** The reference project's offline vault fills only after the tutorial is complete, so the first session is about active play.

---

## 7. When the loop breaks: symptoms and fixes

| Symptom in data or playtests | Likely cause | Fix |
|---|---|---|
| Large drop at one funnel step | A wall without a way around it | Add a second path past the wall (quest, alt activity, catch-up mechanic) |
| Currency balance climbs, spend events flat | Nothing worth buying | Add sinks that change the verb; reprice in "minutes of income" |
| High D1, collapsing D7 | Micro and short loops fine, no long loop | Rebirth, realms, collections, social goals |
| Long first session, low return | No exit hook | Timed rewards, quests, unfinished goals |
| Players ask "what do I do?" | Loop not visible | A single next-goal tracker; see [[First-Time User Experience and Onboarding]] |
| Players progress "too fast", then quit | Content consumed before the long loop opens | Slow the early curve or open the long loop earlier |

### Case: the boss wall (reference project)
A 7-day funnel in the reference project showed drops of 31% at the first fight step, 34% at the forge step, and **82% at the boss step**. The boss was a hard gate on the short loop: players could not pass it by grinding or by switching activity, so they left. The team's responses, in order:
1. Turned mini-boss arenas into **open fights** (no locked doors, walk away and the fight resets after 20 s), so a failed attempt costs nothing.
2. Planned a "Recommended Power" number on every stage sign, with the rule that a boss wall should take **one forge level or one better weapon** to pass.
3. Added a **Next Goal tracker** with a trail to the target and a small reward per goal, because players "feel like they are thrown in the game without knowing what to do".
4. Linked **rebirth** to the wall, so a stuck player always has a long-loop action available.

The lesson generalises: every hard wall needs a visible counter (a power number), a cheap retry, and at least one alternative action.

### Case: progression that was too fast
The same project later found players "progressing way too fast". The fix was not a harder enemy but a **slower reward schedule at the very start**: new profiles roll only Commons for their first 60 to 240 seconds of play, and the tutorial's first roll was changed from a guaranteed Rare to a plain Common. Whether that helped retention was not measured in the sources; it is included as an example of tuning the micro loop's reward size rather than its difficulty.

---

## 8. Instrumenting the loop

You cannot fix a loop you cannot see. Roblox's `AnalyticsService` has purpose-built events for this (Docs, engine API, October 2026): `LogOnboardingFunnelStepEvent`, `LogFunnelStepEvent`, `LogProgressionEvent` (plus `...StartEvent`, `...CompleteEvent`, `...FailEvent`), `LogEconomyEvent` and `LogCustomEvent`. The older `Fire*` methods are deprecated.

A minimal loop-telemetry module that logs each loop step on the server:

```lua
--!strict
-- ServerScriptService/LoopTelemetry (ModuleScript)
-- Logs core-loop events so the Analytics dashboard can show where the loop breaks.
local AnalyticsService = game:GetService("AnalyticsService")

local LoopTelemetry = {}

-- Economy: every source (earn) and sink (spend) of the main currency.
-- endingBalance must be the balance AFTER the change.
function LoopTelemetry.earn(player: Player, currency: string, amount: number, balance: number, how: string)
	AnalyticsService:LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		currency,
		amount,
		balance,
		Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		how -- itemSku: what produced it, e.g. "EnemyKill"
	)
end

function LoopTelemetry.spend(player: Player, currency: string, amount: number, balance: number, sku: string)
	AnalyticsService:LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		currency,
		amount,
		balance,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		sku -- e.g. "Gate_7" or "Upgrade_LuckI"
	)
end

-- Progression: one path per ladder (zones, rebirths, stages).
function LoopTelemetry.reached(player: Player, path: string, level: number, levelName: string)
	AnalyticsService:LogProgressionCompleteEvent(player, path, level, levelName)
end

-- Free-form: one-off moments you want to count (boss attempts, rare pulls).
function LoopTelemetry.moment(player: Player, eventName: string, value: number?)
	AnalyticsService:LogCustomEvent(player, eventName, value or 1)
end

return LoopTelemetry
```

Notes:
- Keep event names stable. Renaming "BossAttempt" to "BossTry" splits your history in two.
- Log on the **server**, where the numbers are authoritative.
- Analytics events have budgets and the dashboard aggregates with a delay; check current limits in the docs before logging per-hit events. Log loop **steps**, not every frame or every swing.
- Pair the numbers with watching real players. A funnel tells you **where** players leave; only a playtest tells you **why**. See [[Analytics and Funnels]] and [[Multi-Client and Live Testing]].

---

## 9. Common mistakes

| Mistake | Why it hurts | Instead |
|---|---|---|
| Designing systems before the verb feels good | Players judge the verb in seconds; systems come later | Prototype the verb alone first |
| Long intro cutscene | Counts against the 60-second bounce window | The reference project disabled its 27 s intro; start with the verb |
| One currency for everything | Every sink competes; balancing becomes impossible | One primary currency per loop layer (cash, gems, materials) |
| Rewards only at the end of long runs | Mobile sessions get cut off | Pay continuously, checkpoint progress |
| Walls with one exit | Funnel cliffs (82% at the boss in the reference project) | Two or more ways past every wall |
| AFK income close to active income | Dead servers and inflation | AFK at a fraction of active (15% in the reference project) |
| Hidden long loop | Players do not know there is more | Show the rebirth button, the realm portal, the rarity ladder early |
| Daily chores as quests ("log in", "play 20 min") | Feels like homework, does not teach the loop | Quests that ask for the loop's verbs (see [[Quests and Objectives]]) |

---

## 10. Checklist

- [ ] The loop fits in one sentence with real verbs.
- [ ] The first reward lands within 30 seconds of control.
- [ ] Every output has at least one sink that changes the verb.
- [ ] Short-loop milestone at least every 5 to 10 minutes.
- [ ] Every wall has a power number, a cheap retry and an alternative.
- [ ] Long loop visible in minute one.
- [ ] Session arc: fast arrival, one re-orientation card, warm-up win, exit hook.
- [ ] Automatic pop-ups go through one gate rule.
- [ ] AFK yields clearly less than active play.
- [ ] Economy sources, sinks and progression steps are logged on the server.

## See also
- [[First-Time User Experience and Onboarding]], [[Retention and Return Hooks]], [[Progression and Pacing Design]]
- [[Balancing with Spreadsheets and Data]], [[Social Design and Multiplayer Play]], [[Ethical Design and Player Trust]]
- Genre playbooks: [[Genre Playbook - Simulators]], [[Genre Playbook - Tycoons]], [[Genre Playbook - Obbies and Platformers]], [[Genre Playbook - Combat and RPG]], [[Genre Playbook - Horror and Story]], [[Genre Playbook - Roleplay and Social Hangouts]], [[Genre Playbook - RNG and Collection Games]]
- Systems: [[Economies and Currencies]], [[Progression Levels and Unlocks]], [[Quests and Objectives]], [[RNG Drops and Luck Systems]]
- Platform: [[Discovery and the Algorithm]], [[Analytics and Funnels]], [[Planning and Scoping a Roblox Game]]

## Connected notes
<!-- auto-links:start -->
[[Core Loop]] · [[Simulator and RNG Genre Teardown]] · [[Session Length]] · [[Onboarding Funnel]] · [[Quest Writing and Hooks]] · [[Faucets and Sinks]]
<!-- auto-links:end -->
