---
tags: [narrative, quests, writing, hooks, objectives, retention, ui-text]
---
# Quest Writing and Hooks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Witty objective lines -> Verb, count, target, place
> - Avoid: Names that do not match the world -> Same name on tracker, nameplate and sign
> - Avoid: Verb mismatch -> Verb matches the counting rule
> - Every quest has a distinct 2 to 4 word title.
> - Hook names one primary motivation and matches the task.
> - Objective line follows verb, count, target, place, under 40 characters.
>
> Read more (19 KB note): ## 3. Objective lines · ## 4. The three-beat quest · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

A quest is a mechanic (a counter, a condition, a reward) wrapped in words. The machinery is covered in [[Quests and Objectives]] and built in full in [[Quest Chain System End to End]]. This note is about the words: the hook that makes a player accept, the objective line that tells them exactly what to do, the tracker text they glance at mid-fight, the turn-in that pays off, and the cliffhanger that brings them back tomorrow. Quest text is the most-read narrative text in most Roblox games, because players need it to play. That makes it the best place to put story and the worst place to put a wall of text.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. The anatomy of quest text

Every quest has up to seven pieces of text, read in very different situations:

| Piece | Read when | Budget (rule of thumb) | Job |
|---|---|---|---|
| Title | Scanning a quest board or log | 2 to 4 words | Recognisable, distinct from other quests |
| Hook (giver line) | Talking to the giver, once | 1 to 3 dialogue screens | Make the player want to do it |
| Objective line | Accepting, then on the tracker | Under 40 characters | Exactly what to do |
| Progress text | Mid-action, glancing | Numbers only, "3/5" | How far along |
| Location hint | When lost | 3 to 6 words, plus a waypoint | Where |
| Turn-in line | Claiming, once | 1 screen | Payoff and acknowledgement |
| Follow-up tease | After claiming | 1 line | Why come back |

The objective line and progress text are read dozens of times; the hook and turn-in are read once, if at all. Spend your voice on the hook and turn-in, and spend your clarity on the objective. A witty objective line ("Show those beetles who is boss!") is charming the first time and useless by the fifth glance, when the player just wants to know what number they are on.

---

## 2. Hooks: why should I care, in five words

A hook answers the player's real question: "why would I do this instead of what I was already doing?" Hooks come in a small number of kinds. Knowing which one you are using makes them easier to write and easier to vary.

| Hook | Pulls on | Example (giver line) |
|---|---|---|
| Reward | Wanting stuff | "Bring me 5 ore. I'll forge you something good." |
| Threat | Danger to something the player values | "Beetles are heading for the market. Stop them." |
| Mystery | Curiosity | "The bell tower rang last night. It has no bell." |
| Character | Liking or pitying someone | "My brother went to the quarry. He hasn't come back." |
| Access | Wanting to go somewhere | "The east gate opens for anyone who clears the road." |
| Mastery | Wanting to get better | "Hit the dummy three times without getting hit." |
| Status | Being seen | "Nobody has beaten the Warden this season." |

Rules of thumb:

- **One primary hook per quest.** A quest that is a reward and a threat and a mystery is unfocused; pick the strongest and let the others be texture.
- **Reward hooks are the default on Roblox, and that is fine.** Most players are motivated by progression. But a game where every quest is "bring X, get Y" feels like a vending machine. Mix in mystery and character hooks on story quests and keep reward hooks for repeatables.
- **Make the hook visible before the conversation.** A "!" marker over the giver, the quest title on the board, a bark ("Has anyone seen my brother?") pulls players toward the hook. The reference project's quest giver showed "!" when something was available and "?" when something was ready to turn in (measured in the reference project; see [[Quests and Objectives]]).
- **The hook must match the task.** If the hook is "my brother is missing" and the task is "collect 10 mushrooms", the player feels lied to. Either the mushrooms lead to the brother, or the hook is wrong.

---

## 3. Objective lines

The objective line is the most important sentence in the quest. It is shown in the quest log, on the tracker, and in toasts. It must be unambiguous at a glance.

**The formula:** verb, count, target, place (rule of thumb). Leave out what is obvious.

| Weak | Problem | Strong |
|---|---|---|
| "Help Hedda" | No action, no target | "Bring 5 Iron Ore to Hedda" |
| "Defeat some enemies" | No count, no target | "Defeat 10 Quarry Beetles" |
| "Go to the place Hedda mentioned" | Requires memory of a skipped line | "Go to the Drowned Quarry" |
| "Defeat 10 beetles in the quarry east of the market past the gate" | Too long for the tracker | "Defeat 10 Quarry Beetles" plus a waypoint |
| "Collect ore (0/5)" with ore from any source counting | Ambiguous: is shop ore fine? | Say it if it matters: "Mine 5 Iron Ore" |

More rules:

- **Use the exact in-game name** of the enemy, item and place, capitalised as on the nameplate or sign. "Quarry Beetle" on the tracker and "Quarry Beetle" over the enemy's head. A mismatch ("beetles" vs "Ore Crawler") sends players hunting the wrong thing.
- **The verb must match how the game counts.** "Defeat" when the last hit counts, "Damage" when any hit counts, "Mine" when only mining counts, "Collect" when any pickup counts. Wrong verbs cause support complaints that look like bugs ("I killed 10 and it did not count", when the quest counted last hits only).
- **One objective on the tracker at a time** for the main line. If a quest has stages, show the current stage, not the whole list ([[HUD Design]]).
- **Progress as numbers.** "3/5" is universal and needs no translation. Do not write "three of five".
- **Do not hide the count in the hook.** If the giver says "bring me some ore", the objective must still say 5.

### Writing objectives so they translate

Objective lines are built from parameters (count, target name, place name), and that is where translation breaks most often. Write one full key per objective pattern with named placeholders, never a sentence built from fragments. Plural forms are a known trap; Roblox's localization docs describe no plural handling for parameters (as of October 2026), so prefer forms that do not need it, such as a label with a count: "Quarry Beetles defeated: {Count}". See [[Localization-Ready Writing]] for the full set of patterns, and [[Localization Pipeline]] for the keyed strings module that delivers them.

---

## 4. The three-beat quest

A quest that is just "do X, get Y" can still feel like a story if it has three beats. This is the smallest story shape that works, and it costs almost nothing extra to write.

1. **Hook.** Someone wants something, or something is wrong.
2. **Complication.** One line mid-quest that changes the picture. Triggered by progress, not a new conversation: a bark at 3/5 ore ("The ore here is... warm?"), a note found in the quarry, an enemy variant that appears halfway.
3. **Payoff.** The turn-in acknowledges what happened, including the complication, and gives a reason to continue.

The complication is the beat most quests skip, and it is the one that turns a chore into a story. It does not need a new mechanic. A single line triggered at a progress threshold is enough:

```lua
--!strict
-- Quest beats: lines triggered at progress thresholds, delivered as a toast
-- or bark (keys plus English defaults; translated on the client).
export type Beat = { at: number, key: string, default: string }

export type QuestText = {
	titleKey: string, titleDefault: string,
	objectiveKey: string, objectiveDefault: string, -- e.g. "Mine {Count:int} Iron Ore"
	beats: { Beat }, -- ascending by 'at'
	turnInKey: string, turnInDefault: string,
	teaseKey: string?, teaseDefault: string?,
}

-- Returns the beats crossed by a progress change, so the server can send each once.
local function crossedBeats(text: QuestText, before: number, after: number): { Beat }
	local out: { Beat } = {}
	for _, beat in text.beats do
		if before < beat.at and after >= beat.at then
			table.insert(out, beat)
		end
	end
	return out
end

local OreRun: QuestText = {
	titleKey = "quest.orerun.title", titleDefault = "Ore for the Forge",
	objectiveKey = "quest.orerun.objective", objectiveDefault = "Mine {Count:int} Iron Ore in the Drowned Quarry",
	beats = {
		{ at = 3, key = "quest.orerun.beat3", default = "This ore is warm. Something below is still burning." },
	},
	turnInKey = "quest.orerun.turnin", turnInDefault = "Warm ore? Then the old furnace is lit again. That is bad news.",
	teaseKey = "quest.orerun.tease", teaseDefault = "Hedda wants to know who lit the furnace.",
}

return { crossedBeats = crossedBeats, OreRun = OreRun }
```

Call `crossedBeats` in the quest service's progress handler, the same place that sends progress to the client. Because the beat is tied to crossing a threshold, a player who gains several progress at once still sees it once, and a player who rejoins does not see it again unless you choose to replay it.

---

## 5. Turn-ins and payoffs

The turn-in is the most skipped piece of quest text, because the player is already looking at the reward. That is not a reason to skip writing it; it is a reason to make it one screen and make it count.

- **Acknowledge what the player did, specifically.** "That is good ore" is fine. "Warm ore? Then the old furnace is lit again" is better: it refers to the complication, and it turns the payoff into the next hook.
- **Pay off the hook.** If the hook was a missing brother, the turn-in must say what happened to him. Unresolved character hooks feel like bugs.
- **Never make the reward wait on the text.** Grant the reward on claim, show the line alongside. A turn-in that requires three "Continue" taps before the reward appears is a toll booth.
- **One line of tease, if there is a next quest.** "Hedda wants to know who lit the furnace." This is the cheapest return hook there is ([[Retention and Return Hooks]]).

---

## 6. Chains as arcs

A quest chain is a short story told in objectives. The same rules as a three-beat quest apply at a larger scale: hook, complications, payoff, with each quest's turn-in serving as the next quest's hook.

| Chain length | Shape (rule of thumb) |
|---|---|
| 3 quests | Hook, complication, payoff |
| 5 to 7 quests | Hook, two complications, a midpoint reveal, a climb, a climax (often a boss), payoff |
| 10+ quests | Split into acts of 3 to 5, each act with its own small payoff, so players who stop mid-way still got a complete piece |

**Vary the verbs.** A chain of "defeat 10, defeat 15, defeat 20" is the same quest three times. Mix kinds the game already has: go somewhere, defeat, collect, talk, escort, survive, use an ability. The variety rules that the reference project used for its daily board (no repeated kind or family within one deal; see [[Quests and Objectives]]) apply to chains too.

**Teach through the chain.** Story chains are a natural place to introduce mechanics one at a time, after onboarding is done: the quest that needs the dash ability is the one that teaches the dash ([[First-Time User Experience and Onboarding]]). Write the hook so the mechanic makes sense in the story ("The bridge is out. You will have to jump the gap.").

**End acts on a cliffhanger, not on a chore.** The last quest of a session-sized act should end with a reveal or a new threat, so the player leaves with a question ([[Core Loops and Session Design]]).

**Gate chains on progress, not on time, unless time is the design.** A story chain that waits a real-world day between quests annoys story players; a daily chain that is meant to bring players back daily should say so clearly ("Come back tomorrow for the next part").

---

## 7. Repeatable quests: writing for the hundredth read

Dailies and weeklies are read every day by your most loyal players. The writing rules flip:

- **No story in the objective.** "Defeat 30 enemies" is the right text on day 40. Flavour wears out; clarity does not.
- **Flavour in the title, varied by pool.** A pool of titles per kind ("Pest Control", "Clearing the Road", "Busy Day at the Quarry") gives variety without hurting the objective's clarity.
- **Parameters for everything that changes.** Count, zone, rarity, enemy type all come in as parameters to one key per pattern, so a pool of 50 daily definitions might need only 10 to 15 objective patterns to translate (rule of thumb).
- **Frame difficulty honestly.** If a quest is hard, the title can say so ("A Long Day"), but the reward must match. Players resent hard quests with easy-quest rewards more than they resent hard quests.
- **Notifications are text too.** Toasts at progress milestones should be short and consistent. The reference project used toasts at 25, 50, 75 and 100 percent progress, and found per-kill toasts to be noise (measured in the reference project).

A minimal title pool that avoids repeats per player within a period:

```lua
--!strict
-- Picks a flavour title for a repeatable quest kind, avoiding the title the
-- player saw for that kind last period. Titles are keys; the client translates.
local TITLES: { [string]: { string } } = {
	Kills = { "quest.title.kills.1", "quest.title.kills.2", "quest.title.kills.3" },
	Mining = { "quest.title.mining.1", "quest.title.mining.2" },
}

local rng = Random.new()

local function pickTitle(kind: string, lastKey: string?): string?
	local pool = TITLES[kind]
	if not pool or #pool == 0 then
		return nil
	end
	if #pool == 1 then
		return pool[1]
	end
	local key = pool[rng:NextInteger(1, #pool)]
	if key == lastKey then
		key = pool[(table.find(pool, key) :: number) % #pool + 1]
	end
	return key
end

return pickTitle
```

Store the chosen title key on the dealt quest state, next to the frozen reward, so the title does not change when the player rejoins ([[Quests and Objectives]]).

---

## 8. Hooks that bring players back

Quest text is one of the main tools for return hooks. The text only works if a real reason backs it, but the right line makes the reason visible.

| Return hook | Text form | Notes |
|---|---|---|
| Cliffhanger | Last line of a session-sized act | Works best with a visible change in the world |
| Next unlock tease | "Finish 2 more quests to open the east gate" | Show the gate on the map, locked |
| Timed reset | "New quests in 4h 12m" | Server UTC time; never trust the client ([[Quests and Objectives]]) |
| Weekly track | "3 more points to the next chest" | Turns many small quests into one goal |
| Character promise | "Come back when the furnace is out. I will have something for you." | Must be honoured |
| Event countdown | "The Warden wakes in 2 days" | Ties quests to live ops ([[Live Ops Events and Updates]]) |

**Never write a promise the game will not keep.** "Come back tomorrow for a surprise" with no surprise is the fastest way to teach players to ignore your text. The same goes for "limited time" on things that are not limited ([[Ethical Design and Player Trust]]).

---

## 9. Pop-ups, trackers and where quest text appears

Quest text competes with every other piece of UI. A few placement rules, several of them measured in the reference project:

- **One line at the top of the screen** for the current main objective, with a progress bar. The reference project replaced a quest bubble that stayed on screen (players found it annoying) with a compact tracker plus a "next up" goal card (measured in the reference project).
- **Onboarding bubbles get out of the way.** The reference project's onboarding bubble docked to the right edge after 4 seconds (measured in the reference project). A tip that sits over the play area for long gets closed and forgotten.
- **Quest board with a speaking giver.** The reference project's quest board showed the giver's portrait and typed out a short line above the quest cards (measured in the reference project). A portrait and one line give a menu a voice at almost no cost.
- **Global pop-up gate.** Never pop quest text during combat, a cutscene, a purchase prompt or another pop-up ([[Quests and Objectives]], [[Notification and Toast Systems]]).
- **Waypoints carry the "where".** Do not write directions into the objective when a waypoint can show them ([[World-Space UI - BillboardGui and SurfaceGui]]).

---

## 10. A worked rewrite

A real-shaped quest before editing:

> **Title:** Quest 7
> **Giver:** "Hello adventurer! As you may know, our village has been suffering greatly because the beetles from the quarry keep attacking travellers on the road. Could you please go and defeat some of them? I will give you a reward if you do!"
> **Objective:** Defeat beetles (0/10)
> **Turn-in:** "Thank you so much! Here is your reward!"

Problems: no title identity; generic opener; vague count in the hook; "beetles" does not match the enemy name; no complication; the turn-in could belong to any quest; no reason to continue.

After:

> **Title:** Clear the Road
> **Giver:** "Beetles are hitting carts on the east road. Clear them out."
> **Objective:** Defeat 10 Quarry Beetles
> **Beat at 5/10 (toast):** "These beetles are carrying ore. They are coming from the quarry."
> **Turn-in:** "Ore-eating beetles? Then the quarry is worse than we thought."
> **Tease:** "Hedda at the forge wants to hear about the ore."

Word count went from 62 to 49 across all pieces, the objective names the exact enemy, the complication turns a cull into a clue, and the tease points at the next quest's giver.

---

## 11. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Witty objective lines | Tracker text that does not say what to do | Verb, count, target, place |
| Names that do not match the world | Players ask "where are the beetles?" when enemies are called something else | Same name on tracker, nameplate and sign |
| Verb mismatch | Support reports "kills not counting" | Verb matches the counting rule |
| Hook does not match task | Players feel tricked | Change the task or the hook |
| No complication | Every quest is a chore | One mid-quest line at a threshold |
| Generic turn-ins | Turn-in could belong to any quest | Refer to what happened; tease the next |
| Story in daily objectives | Dailies feel wordy by week two | Plain objectives, flavour titles |
| Sentences built from fragments | Broken grammar in translation | One key per pattern with placeholders |
| Broken promises | "Come back tomorrow" with nothing new | Only tease what exists |

## 12. Checklist

- [ ] Every quest has a distinct 2 to 4 word title.
- [ ] Hook names one primary motivation and matches the task.
- [ ] Objective line follows verb, count, target, place, under 40 characters.
- [ ] Names on the tracker match nameplates and signs exactly.
- [ ] The verb matches what counts.
- [ ] Story quests have a mid-quest complication beat.
- [ ] Turn-ins are one screen, specific, never delay the reward.
- [ ] Chains vary verbs and end acts on a reveal.
- [ ] Repeatables use plain objectives and pooled flavour titles.
- [ ] Every tease and promise is backed by real content.
- [ ] All quest text keyed with named placeholders.

## See also

[[Narrative Start Here]] · [[Quests and Objectives]] · [[Quest Chain System End to End]] · [[Writing Dialogue for Roblox Players]] · [[Dialogue System End to End]] · [[Lore Delivery Without Walls of Text]] · [[Naming Items Zones and Abilities]] · [[Localization-Ready Writing]] · [[Retention and Return Hooks]] · [[Progression and Pacing Design]] · [[First-Time User Experience and Onboarding]] · [[HUD Design]] · [[Notification and Toast Systems]]

## Connected notes
<!-- auto-links:start -->
[[Links - Quests and progression]] · [[Core Loop]] · [[Teaching Through Level Design]] · [[Links - Menus, HUDs, inventories and shops]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Experience Notifications and Return Prompts]]
<!-- auto-links:end -->
