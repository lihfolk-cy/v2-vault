---
tags: [game-design, combat, bosses, encounters, phases, telegraphs, multiplayer, rewards, type/guide, area/design, level/intermediate, area/networking]
---
# Boss Fight Design Patterns

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Fixed boss health -> Scale to group damage; target TTK
> - Avoid: Tracking attacks that never lock -> Commit at least 0.45 s before the hit
> - Avoid: Burst skips phases -> Health floors at each threshold
> - One sentence each: what the fight tests, teaches and gates.
> - Every attack has a tell, a commit point and a punish window meeting minimums.
> - Attacks drawn from phase pattern bags, filtered by range and cooldown, no repeats.
>
> Cost: TL;DR ~150 tok · whole note ~5.3k tok. Read more: ## 2. Attack vocabulary: tell, commit, punish · ## 3. Phases · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

A boss is a test the game has been preparing the player for. On Roblox it is also a test taken by a random group of strangers, many on phones, with no voice chat, joining and leaving mid-fight, holding wildly different gear. Patterns that work in a single-player action game (precise dodges, long learning by death, a fixed health pool) break here unless they are adapted. This note is the design side: how to structure a fight, how to time and teach attacks, how to scale health and damage to groups, how to reward losers as well as winners, and how to test a fight before players do.

The animation side (intros, clip sets, telegraph clips, dodge windows, rigs for large creatures) is in [[Boss Animation and Phases]]. The brain side is in [[NPC AI and Behaviour]] section 8 and [[Behaviour Trees Utility AI and State Machines for NPCs]].

Related: [[Genre Playbook - Combat and RPG]], [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[Status Effects Buffs and Stacking Rules]], [[Social Design and Multiplayer Play]], [[Progression and Pacing Design]], [[Live Ops Events and Updates]].

Source labels: **Docs** (Roblox docs as of October 2026), **Measured** (the reference project: a zone boss with phases and a cutscene, and a pop-up group boss event), **Rule of thumb**.

---

## 1. What a boss fight is for

Before any attack list, answer three questions in one sentence each:

| Question | Bad answer | Good answer |
|---|---|---|
| What does it test? | "Whether you are strong enough" | "Whether you watch the ground and move, which the zone's enemies taught" |
| What does it teach? | Nothing new | "Phase 3 introduces safe circles; the next region uses them everywhere" |
| What does it gate? | Everything after it | "A free portal to the next region, plus materials for a new tier" |

A boss that only tests stats is a damage sponge, and players feel it immediately. A boss that tests a skill the game never taught is unfair. The best Roblox bosses test **one** skill clearly per phase, because the audience skews young and casual and a group of strangers cannot coordinate anything subtle.

**Measured:** the reference project's first region ended with a boss whose defeat opened a free portal to region 2. That made the boss the region's long-loop goal, not an optional extra, which raised the stakes for fairness: a gate boss that a solo phone player cannot beat stops progression for exactly the players most likely to churn. If a boss gates progress, it needs a solo-viable path (section 5).

---

## 2. Attack vocabulary: tell, commit, punish

Every boss attack has three parts. Designing them explicitly is the difference between "hard" and "cheap".

| Part | What it is | Design numbers (rule of thumb unless marked) |
|---|---|---|
| Tell | The warning: a wind-up pose, a ground marker, a sound, a flash | At least 0.5 s for single-target attacks (**Measured** minimum); 1 to 3 s for room-wide attacks (**Measured**: about 3 s for big room attacks) |
| Commit | The moment the attack's aim and shape are fixed | Tracking attacks lock aim at least 0.45 s before the hit (**Measured**) |
| Punish | A window after the attack where the boss is open | 0.6 to 1.5 s; longer after bigger attacks |

The **commit** rule is the one most often missed. An attack that tracks the player until the instant it lands cannot be dodged by movement, only by luck or latency. With typical round trips of 100 to 250 ms on mobile networks (rule of thumb), a player needs the target locked well before impact to see it and react. See [[Hitboxes and Hit Detection]] for showing the real hit shape as the telegraph.

### Readability by category
Give each attack category a consistent look so players learn the language once:

| Category | Telegraph convention |
|---|---|
| Standard melee | Wind-up pose plus a red ground shape |
| Unblockable or special | A different colour (the reference project used gold telegraph tokens for special attacks) |
| Room-wide | Screen-edge warning, a voice line or roar, the whole floor tinted except safe zones |
| Projectile | A line or cone marker; fast projectiles need longer tells because the travel time is short |

### Variety without chaos
- A boss needs fewer attacks than designers think: **Measured**, the reference project's bosses carried 6 to 11 attacks, and its event boss had six (three per phase added progressively).
- Never the same attack twice in a row (**Measured** rule for bosses), and weight attacks by distance so melee bosses do not fire their ranged attack at point-blank range.
- **Pattern bags** rather than pure random: shuffle the current phase's attacks into a bag and draw without replacement, refilling when empty. Players see every attack regularly and can learn the fight, but cannot memorise an exact order.

```lua
--!strict
-- Pattern bag: draw each attack once per cycle, never repeating the last one across refills.
local rng = Random.new()

export type Bag = { items: { string }, pool: { string }, last: string? }

local function newBag(pool: { string }): Bag
	return { items = {}, pool = table.clone(pool), last = nil }
end

local function refill(b: Bag)
	b.items = table.clone(b.pool)
	rng:Shuffle(b.items)
	-- Avoid a repeat across the refill boundary.
	if #b.items > 1 and b.items[#b.items] == b.last then
		local j = rng:NextInteger(1, #b.items - 1)
		b.items[#b.items], b.items[j] = b.items[j], b.items[#b.items]
	end
end

-- `valid` filters by range and cooldown; invalid draws go back into the bag.
local function draw(b: Bag, valid: (string) -> boolean): string?
	if #b.items == 0 then
		refill(b)
	end
	for i = #b.items, 1, -1 do
		local id = b.items[i]
		if valid(id) then
			table.remove(b.items, i)
			b.last = id
			return id
		end
	end
	return nil -- nothing valid right now: reposition instead
end

local function setPool(b: Bag, pool: { string })
	b.pool = table.clone(pool) -- new phase: new attacks
	b.items = {}
end

return { new = newBag, draw = draw, setPool = setPool }
```

The draw takes from the end of the shuffled list, which is why the refill guard checks the last element. `Random:Shuffle` is a documented method (Docs).

---

## 3. Phases

Phases make a long fight feel like a story. Typical structure: three phases at roughly 100 to 66%, 66 to 33% and below 33% (**Measured** for the event boss), or two shifts at 50% and 20% (**Measured** for the zone boss: Enrage at 50%, Desperation at 20%).

What a phase change should do, in order of value:
1. **Add one new mechanic** (a hazard, a new attack, safe circles). This is the teaching beat.
2. **Change tempo** (shorter wind-ups, shorter recovery). **Measured:** phase shifts raised speed and damage multipliers from data.
3. **Change the look** (armour breaking off, colour shift, arena lighting) so players know without reading a bar.
4. **Give a breath**: the transition itself is a short safe moment.

### Transition rules
- **The transition is untouchable.** **Measured:** the reference project made its phase-shift clip untouchable while its own hits still land; damage dealt during it is ignored, so a group cannot burst through a phase.
- **Hazards start after the transition ends.** **Measured:** a flood hazard only began to burn after the shift clip finished. A hazard that starts during an animation the player is watching is a cheap hit.
- **Never skip a phase.** A burst of damage that crosses two thresholds must still play both phase entries in order, or the fight's teaching beat vanishes. Clamp health at each threshold until its transition has started.
- **Knock players back** at the start of a transition (**Measured**: each event-boss phase opened with a roar that pushed everyone back). It resets positioning so the new mechanic is seen from a fair distance.

```lua
--!strict
-- Phase gate: health cannot drop below the next threshold until that phase has begun.
export type Phase = { at: number, name: string } -- `at` = health fraction where it starts, descending

local function applyDamage(boss: { health: number, maxHealth: number, phaseIndex: number, transitioning: boolean },
	phases: { Phase }, amount: number, startTransition: (Phase) -> ())
	if boss.transitioning then
		return -- untouchable during the shift
	end
	local nextPhase = phases[boss.phaseIndex + 1]
	local floor = if nextPhase then nextPhase.at * boss.maxHealth else 0
	boss.health = math.max(boss.health - amount, floor)
	if nextPhase and boss.health <= floor then
		boss.phaseIndex += 1
		boss.transitioning = true
		startTransition(nextPhase) -- sets transitioning = false when the clip ends
	end
end

return { applyDamage = applyDamage }
```

### Enrage and timers
An **enrage** in the classic sense (the boss kills everyone after N minutes) is a damage check. On Roblox, where group strength varies by an order of magnitude, a hard enrage tuned for an average group wipes weak groups for reasons they cannot see. Prefer a **soft timer**: the fight ends at a time limit with partial rewards (section 6). **Measured:** the event boss fight had a 240-second limit, ending in a win, a loss (everyone knocked out) or a timeout.

---

## 4. Scaling to the group

### Health
Fixed boss health fails in both directions: a solo player faces a wall and a full server deletes the boss before phase 2. Scale health to the **actual damage the group can do**, measured from their gear, not to player count alone.

**Measured** formula from the reference project's event boss:

```
boss health = (sum of each participant's blade damage) x 2.2 x 95 seconds x size bonus
size bonus = 1.00 / 1.12 / 1.24 / 1.36 for 1 / 2 / 3 / 4 players
```

Read it as: "the fight should last about 95 seconds of the group's sustained damage (with a factor for abilities and uptime), plus a bit extra per additional player because groups also have more uptime and revives". The size bonus exists because damage does not scale linearly with headcount in practice: more players means more targets for the boss, more ability overlap and more uptime.

Design the **target time to kill** first (rule of thumb: 60 to 120 s for a pop-up event, 2 to 4 minutes for a region boss), then derive health. Put the TTK, not the health number, in the config, and log actual TTK per fight to compare ([[Analytics and Funnels]]).

### Damage
Boss damage scaled to player gear is the other half. If players' health varies by 100x between a new and a veteran player, a fixed hit is either trivial or lethal. **Measured:** the event boss's hits took a **share of each player's own fight health**, so a hit means the same thing to everyone whatever they hold. Trade-off: gear then stops mattering for survival in that fight; keep gear relevant through damage output (shorter fight, more rewards).

### Late joiners and leavers
- **Joining late.** If health was set at the start, a late joiner makes the fight easier (fine) but gets less reward contribution (handle in section 6). If you rescale on join, never raise current health above the fraction the boss was at; rescale `maxHealth` and keep the fraction.
- **Leaving.** Do not lower health when someone leaves mid-fight; the remaining group was already committed. Optionally lower *outgoing damage* slightly so a 4-player fight that becomes solo is still survivable.
- **Measured:** the event used a 60-second join window, dealt joined players into groups of up to four in join order, and gave each group its own copy of the arena. Instancing the arena per group removes most late-join problems entirely.

### Target selection in groups
A boss that always targets the nearest player punishes melee and rewards hiding. Patterns:
- **Rotate targets** per attack, weighted toward whoever dealt the most damage recently (a simple threat table).
- **Per-player attacks**: **Measured**, the event boss's Grave Ring spawned a circle under each player, which tests everyone equally.
- **Shared attacks** that need everyone to move (whole-floor attacks with a few safe circles) create the cooperative moment without voice chat.

---

## 5. Failure, knockouts and the solo player

Failure is where Roblox bosses lose most players.

| Pattern | Effect |
|---|---|
| Knocked-out players become ghosts and spectate a teammate (**Measured**) | Nobody leaves to the lobby mid-fight; the group stays together |
| Revive by standing near a downed ally for a few seconds | Cooperation without voice; risk of camping |
| Respawn at the arena entrance after a delay | Simple; makes the fight a war of attrition |
| Wipe resets the boss to full | Classic; brutal for strangers |

For **gate bosses** (progression blockers), add a solo-viable path: scaled health (section 4), a mercy mechanic (a small damage bonus per failed attempt today, shown openly), or an alternative requirement after a few defeats. Hidden difficulty reduction works too, but visible help builds trust. See [[Ethical Design and Player Trust]].

**Mini-boss reset:** **Measured**, the reference project's mini-boss walked home and reset after 20 seconds with no player in its area, and could not be damaged from outside its arena. Both rules stop the two classic exploits: kiting a boss out of its area to cheese it, and sniping from a spot it cannot reach.

**Crowd control against bosses** needs its own rules or groups lock the boss for whole phases ([[Status Effects Buffs and Stacking Rules]] section 5). **Measured:** freezes lasted 2 s on enemies and 0.5 s on bosses; bosses were excluded from pull ultimates and took heavy-hit recoils instead of being dragged.

---

## 6. Rewards that keep groups together

Rewards decide whether players stay to the end, help strangers, and come back.

**Measured** event boss rewards from the reference project:

| Outcome | Reward |
|---|---|
| Win | Cash worth 6% of the player's next gate price (minimum floor), gems 40 + 4 per zone reached, 4 materials of the zone tier with a 35% chance of one tier above |
| Loss | Cash worth 1.5% of the next gate price (lower floor) |
| Knocked out before a win | 60% of the win reward |
| Cooldown | 25 minutes per player |
| Never | Weapons (the game's main rolled item) |

Lessons in those numbers:
- **Scale rewards to the player's own progress** (a percentage of their next goal), not to a fixed amount. A fixed reward is meaningless to veterans and game-breaking for new players in the same group.
- **Losers get something.** A small loss reward makes trying worthwhile and stops "this group is bad, I am leaving" behaviour.
- **Knocked-out players still get most of the win.** Otherwise the first player to fall leaves, and the fight gets harder for everyone else.
- **Keep the main chase item out of event drops** if the core loop sells it (rolls in this case). The boss rewards feed the side economies (materials, gems) instead of competing with the core loop.
- **A cooldown** stops farming one boss forever and spreads players across content.
- **Per-player drops**, never shared loot that one player can take ([[RNG Drops and Luck Systems]] section 5). **Measured** zone boss drops: one material always, a rarer one at 25% (35% for a later boss).

Contribution thresholds: require a minimum contribution (some damage dealt, or time present in the arena) so AFK players standing in the arena do not collect full rewards. Make the threshold low; the goal is excluding AFK players, not ranking.

---

## 7. The pop-up event pattern

A recurring server-wide boss event is one of the strongest retention and social tools a combat game has ([[Retention and Return Hooks]], [[Live Ops Events and Updates]]). **Measured** structure:

1. Every 30 minutes (plus or minus 2; first one 8 minutes into a new server) every player sees a JOIN banner for 60 seconds.
2. Joined players are grouped (up to 4) and teleported to private copies of the arena inside the same place, avoiding a cross-place teleport.
3. Arena transition with its own lighting, a 4-second boss entrance, then up to 240 s of fight.
4. Results card for 7 s, then everyone returns to where they stood.

Why it works: the timer gives a reason to stay ("next boss in 6 minutes"), the banner turns a solo session into a group one, the short length fits a phone session, and returning players to their spot makes it a detour, not a disruption. The risk: players who are mid-task (a long brew, a quest) feel interrupted. Always make joining optional and never penalise skipping.

Implementation notes: copies of an arena placed far from the map need their own lighting and streaming considerations ([[Instance Streaming]]); clean up every copy and every connection on exit ([[Memory Budgets and Leaks]]); and protect against players leaving mid-fight by restoring their state on rejoin.

---

## 8. Testing a boss before players do

- **Time-to-kill simulation.** Feed the health formula with the damage of real player profiles at the boss's intended progress point (a weak, median and strong build) and compute TTK. If the weak build needs more than twice the target time, the fight is a wall for them.
- **Damage taken simulation.** For each attack, the share of health it takes; check that no combination within one pattern bag cycle kills a full-health player who dodges nothing but one attack. One unavoidable hit should never kill.
- **Bot runs.** A test mode where scripted dummy players stand still, walk in circles or sit at the arena edge exposes broken targeting, unreachable spots and exploit positions fast ([[Multi-Client and Live Testing]]).
- **Telegraph audit.** Record every attack and check tell length, commit time and punish window against the table in section 2. **Measured:** the reference project enforced minimum warnings and aim-lock times as rules after testers found attacks that could not be dodged.
- **Phone test.** Play the whole fight on a small phone. Ground telegraphs under a large boss are often hidden by the boss model and by the thumb on the joystick; raise their height or add an edge glow.
- **Exploit sweep.** Can the boss be damaged from outside the arena? Kited out? Pinned on geometry? Does it reset correctly when everyone leaves?

---

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Fixed boss health | Solo players hit a wall; full servers skip phases | Scale to group damage; target TTK |
| Tracking attacks that never lock | "Undodgeable" complaints, worse on mobile | Commit at least 0.45 s before the hit |
| Burst skips phases | Phase mechanics never seen | Health floors at each threshold |
| Hazards during transitions | Cheap hits | Start hazards after the transition clip |
| Unlimited CC on bosses | Boss locked for whole phases | Boss CC scaling or poise bars |
| Nothing for losers or the knocked out | Groups dissolve mid-fight | Loss rewards and ghost spectate |
| Fixed rewards | Meaningless to veterans, inflationary for beginners | Rewards scaled to each player's progress |
| Gate boss with no solo path | Progression stalls for the most fragile players | Scaling, mercy mechanic, alternative route |
| Ground telegraphs hidden under the model | Deaths that feel random | Raised markers, edge glows, phone testing |

## Checklist
- [ ] One sentence each: what the fight tests, teaches and gates.
- [ ] Every attack has a tell, a commit point and a punish window meeting minimums.
- [ ] Attacks drawn from phase pattern bags, filtered by range and cooldown, no repeats.
- [ ] Phase transitions untouchable, never skipped, open with a knock-back and add one mechanic.
- [ ] Health derived from target time to kill and the group's real damage.
- [ ] Damage meaningful to every gear level; one unavoidable hit never kills.
- [ ] Knockouts keep players in the fight; losers and knocked-out players are rewarded.
- [ ] Rewards scale with each player's progress; cooldown prevents farming.
- [ ] TTK and damage simulations, bot runs, telegraph audit and phone test done.

## See also
[[Boss Animation and Phases]] · [[NPC AI and Behaviour]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Status Effects Buffs and Stacking Rules]] · [[Genre Playbook - Combat and RPG]] · [[Combat Systems Architecture]] · [[Hitboxes and Hit Detection]] · [[Cameras and Cutscenes]] · [[Social Design and Multiplayer Play]] · [[Retention and Return Hooks]] · [[Live Ops Events and Updates]] · [[Case Study - Enemy Roster Rebuild]]

## Connected notes
<!-- auto-links:start -->
[[Anticipation]] · [[Core Loops and Session Design]] · Combat Arena and Encounter Layout · Enemy and NPC Animation · Teaching Through Level Design · Animating Creatures and Monsters
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Time-to-Kill Math and a Weapon Balance Sheet]] · [[Genre Playbook - Simulators]] · [[Genre Playbook - Party and Minigame Collections]] · [[Simulator and RNG Genre Teardown]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[First-Time User Experience and Onboarding]] · [[Genre Playbook - Battle Royale]]
<!-- related:end -->
