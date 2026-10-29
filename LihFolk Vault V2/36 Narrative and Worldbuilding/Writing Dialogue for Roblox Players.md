---
tags: [narrative, dialogue, writing, npc, ux, onboarding, voice, type/guide, area/narrative, level/intermediate, api/TextChatService]
---
# Writing Dialogue for Roblox Players

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Wall of text on first meeting -> Split, cut the opener, move backstory to optional choices
> - Avoid: Critical instruction only in dialogue -> Repeat it in the tracker and waypoint
> - Avoid: Every NPC sounds the same -> Voice cards with one trait each
> - Every screen is 18 words or fewer; no more than 3 screens before the player acts.
> - First conversation with any NPC is under about 50 words.
> - Every critical instruction is also in the tracker or world guidance.
>
> Cost: TL;DR ~160 tok · whole note ~5.6k tok. Read more: ## 3. Line craft · ## 7. Barks: the dialogue most players actually hear · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

Most dialogue advice comes from novels, films and long single-player RPGs, where the audience chose to sit down for a story. Roblox dialogue is read by a different audience in a different situation: many players are children or young teens, many are reading in their second language (or reading a machine translation), most are on a phone, often in a noisy room, and almost all of them arrived to play, not to read. Roblox's own onboarding guidance puts it bluntly: players often skip text (Roblox docs, "Onboarding techniques", as of October 2026). This note is about writing lines that survive that: how long a line can be, how to give a character a voice in eight words, how to write choices that are real, how to keep branching affordable, and how to edit a scene down until players actually read it.

The system that displays these lines is built in [[Dialogue System End to End]]. Making the text translate well is in [[Localization-Ready Writing]]. Story outside of dialogue (environment, items, collectibles) is in [[Lore Delivery Without Walls of Text]]. The broader genre view of story games is in [[Genre Playbook - Horror and Story]].

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Writing craft is mostly rule of thumb; where a number is given, treat it as a starting budget to test against, not a law.

---

## 1. Who is reading, and how

Before writing a single line, picture the actual reader:

| Reader trait | What it means for the line |
|---|---|
| Young (a large share under 13) | Short words, concrete nouns, no sarcasm that needs adult context to decode |
| Reading in a second language, or through machine translation | Plain grammar, no idioms, one idea per sentence |
| On a phone in landscape | Two lines of body text is a full screen; long lines wrap into a wall |
| With friends in the same server | They are talking over your NPC; the line competes with voice chat and chat bubbles |
| Wanting to play | Every second spent reading is a second not playing; they will tap through |
| Tapping fast | The first tap often lands before the line is finished |

**Reading speed.** A common rule of thumb for silent reading is roughly 200 to 250 words per minute for adults, and much slower for younger readers and second-language readers (a budget of 100 to 150 words per minute is safer for this audience). At 120 words per minute, a 12-word line takes 6 seconds. A 60-word speech takes 30 seconds, which is longer than most players will give an NPC they have just met. This is the single most useful number in this note: **every word costs about half a second of the player's attention**.

**Skipping is not failure.** Players who skip are telling you the line did not earn their time. Design so that a player who skips every line still knows what to do next (the objective tracker, the waypoint, the highlighted button), and a player who reads gets something extra (character, a joke, a hint). Dialogue that carries the only copy of a critical instruction will be skipped and then the player is lost. The reference project learned the same thing about its intro cutscene: 27 seconds inside the first minute was too long, it was made skippable after 3 seconds, and later disabled (measured in the reference project; see [[First-Time User Experience and Onboarding]]).

---

## 2. Budgets for one screen

Use hard budgets. Writers who have a number write shorter than writers who are told "keep it short".

| Unit | Budget (rule of thumb) | Why |
|---|---|---|
| One dialogue screen | 12 to 18 words, about 90 English characters | Two lines at readable size on a phone, with room for German or Portuguese growth |
| One sentence | Under 12 words | Machine translation and young readers both handle short sentences better |
| Screens before the player gets to act (choose, move, fight) | 3 | After three "Continue" taps, players start mashing |
| Total first conversation with a new NPC | 30 to 50 words | Roughly 15 to 25 seconds at the reading budget above |
| A choice | 2 to 6 words | It is a button; it must be scannable at a glance |
| Number of choices | 2 to 4 | More than 4 does not fit under the body text on a phone and slows decisions |
| A bark (ambient one-liner) | 3 to 8 words | Read in passing while moving |

The 90-character screen budget leaves headroom: translations into German, French and Portuguese commonly run 20 to 35 percent longer (rule of thumb, see [[Localization]]), so an English line that already fills two lines will overflow into three in German. Write to the budget in English so the translations still fit.

**Check the longest line, not the average.** The UI must fit the worst line in the game. Keep a script that prints the five longest lines and reads them on a phone emulator, in English and in your biggest second language.

---

## 3. Line craft

### One idea per screen

The most common long line packs three ideas: who I am, what is happening, what you should do. Split them, then cut the ones the world already shows.

Before (64 words, one screen):

> "Greetings, traveller! I am Hedda, the finest blacksmith in all of the Ashfield Reaches, and I have been working this forge for nearly forty years. Lately the quarry to the east has been overrun by beetles, which means I cannot get any iron, and without iron I cannot make blades. If you could bring me five iron ore from the quarry, I would reward you handsomely!"

After (three screens, 34 words, with the job given as a choice):

> HEDDA: "New face. You look like you could use a better blade."
> HEDDA: "Problem is, beetles took the quarry. No ore, no blades."
> HEDDA: "Bring me 5 iron ore and I will pay you."
> [Deal.] [Maybe later.]

What was cut and why:

- "Greetings, traveller!" Generic openers waste the most-read words of the conversation. Start with something only this character would say.
- "I am Hedda, the finest blacksmith..." The name is in the speaker label. The forge behind her says blacksmith. The forty years can go into a later optional line if anyone asks.
- "which means I cannot get any iron, and without iron I cannot make blades" became "No ore, no blades", which is shorter, has a voice, and survives translation.
- "reward you handsomely" is vague. "Pay you" is concrete; the reward amount shows on the quest card.

### Front-load the useful words

Players skim the start of a line. Put the verb or the key noun first. "The quarry is east, past the gate" reads faster than "If you are looking for the quarry, you will find it east of here, past the gate". Instructions especially should start with the action: "Bring", "Find", "Talk to".

### Concrete over abstract

"Beetles took the quarry" beats "There is a problem at the quarry". "Bring 5 iron ore" beats "Gather some materials". Concrete lines are easier to read, easier to translate and easier to remember.

### Numbers and names as digits and capitals

Write "5 iron ore", not "five pieces of iron ore". Digits are faster to read and carry through translation as parameters ([[Localization-Ready Writing]]). Capitalise names of places the player will see on signs, so the line and the sign match.

### Avoid typed sound effects and long ellipses

"Hmmmmm... well... I suppose..." costs screen space and typewriter time and reads as stalling. One "Hm." is a character beat. Three is padding.

---

## 4. Voice in eight words

Players remember NPCs by one trait. A character with a clear voice can be recognised from a single line without the speaker label, and that is the test.

**Give each speaking character a voice card** (one line each):

| Field | Example (the blacksmith) |
|---|---|
| One trait | Blunt, busy, secretly kind |
| Sentence shape | Short. Drops subjects. "Forge is hot." |
| Vocabulary | Metal, heat, work words. Never "awesome" |
| Verbal habit | Prices everything. "That is a two-coin question." |
| What they want | The quarry back |
| What they never do | Gush, explain herself, use the player's name twice |

Contrast is what makes a cast. If the blacksmith is terse, the merchant next door should be chatty (within budget: chatty means more lines the player can opt into, not longer lines). If everyone speaks in the same polite, neutral register, nobody is memorable.

**Writing the player.** Roblox avatars are the players themselves, in their own clothes, with their own names. Most Roblox games keep the player character silent or near-silent and let choices stand in for the player's voice. When choices are written in a strong personality ("Ugh, fine, I'll do your chores"), some players feel misrepresented. Keep player choices fairly neutral in tone and let the NPCs carry the personality, unless the game is a comedy where the player persona is part of the joke.

**Using the player's name.** Inserting the display name ("{Player}, is it?") is a strong moment once. Every line is too much. Display names can be long, so test the longest display name in the longest line. Never insert other players' names into an NPC line without care in a shared server: it reads as the game singling someone out.

**Humour.** Jokes are the first thing to die in translation and the first thing to date. Memes from this month will be cringe in six months, and the game lives longer than that. Character humour (the blacksmith prices everything) ages well and survives translation; reference humour does not. If a line only works in English, mark it for translators as "rewrite freely, keep the tone" ([[Localization-Ready Writing]]).

---

## 5. Choices that are real

A choice is a promise that the player's input matters. Each fake choice weakens every later one.

| Choice type | When it is honest | Example |
|---|---|---|
| Information | The answer differs and is optional | "What is this place?" opens one extra line |
| Commitment | Yes or no with different outcomes | "Deal." starts the quest; "Maybe later." does not |
| Flavour | Tone differs, outcome does not, and the response acknowledges it | "Nice forge." / "Smells like smoke." both continue, with a different reply line |
| Exit | Always available | "Goodbye." |

Rules of thumb:

- **Always offer an exit.** A conversation with no way out, on a game where players can be attacked or where friends are waiting, is a trap. The system should also close if the player walks away ([[Dialogue System End to End]] does).
- **Never write two choices that do the same thing with no different reply.** Players notice, and they stop reading choices.
- **Put the expected choice first.** On a phone, the first button is the easiest to hit, and on gamepad it is selected by default. "Deal." goes above "Maybe later."
- **Write choices as what the player says or does, not as a summary of the outcome.** "Deal." is better than "[Accept quest]". The exception is consequential, irreversible choices (spending premium currency, starting a hard mode): there, clarity beats voice, so state the outcome plainly.
- **Hide unavailable choices, or show them disabled with a reason.** Hiding is cleaner for story; showing a disabled "Bring me 5 iron ore (3/5)" is clearer for task progress. Pick one rule per game.
- **Do not put purchases inside dialogue without a clear marker.** A choice that spends Robux or premium currency must look like a purchase, not a line of talk ([[Ethical Design and Player Trust]]).

---

## 6. Branching you can afford

Branching costs grow fast. A full tree where every screen has two choices and every choice leads to new content doubles at each level:

| Depth | Screens in a full binary tree | Screens a single player sees |
|---|---|---|
| 2 | 3 | 2 |
| 3 | 7 | 3 |
| 4 | 15 | 4 |
| 6 | 63 | 6 |

At depth six, you write 63 screens so that each player reads 6. That is about a 10 to 1 ratio of writing to reading, plus translation for every screen, plus testing every path. Nobody ships that for a side NPC.

Shapes that stay affordable:

- **Hub and spokes.** One hub screen with information choices that each lead to one or two lines and return to the hub. Cost grows linearly with topics. This is the shape of the blacksmith tree in [[Dialogue System End to End]].
- **Branch and merge.** A choice changes the next one or two lines, then the paths converge. The player feels heard; the story stays one story.
- **State, not branches.** Instead of branching the conversation, set a flag and let the next conversation start differently ("Back again. Forge is hot."). The ordered greeting list in the dialogue system is designed for this. One flag can change many future lines cheaply.
- **Consequences outside dialogue.** A choice that changes the world (the gate opens, the NPC moves to the quarry) is cheaper to show than to write, and players remember it more.

Reserve deep branching for the few moments the game is about (a story game's ending, a boss's fate).

---

## 7. Barks: the dialogue most players actually hear

Barks are short, one-way lines: a shopkeeper calling out as you pass, an enemy shouting when it spots you, a guard commenting on your new sword. In most Roblox games, players hear far more barks than conversations, and barks do more for a world's personality per word than anything else.

Rules of thumb:

- **3 to 8 words.** The player is moving.
- **3 to 5 variants per trigger.** One variant repeated becomes a joke in a minute. Pick randomly without repeating the last one.
- **Cooldown per NPC and per trigger.** For ambient barks, 20 to 40 seconds per NPC is a reasonable start; for combat barks, gate them on events (spotted, low health, ally down) and never more than one bark per few seconds in a fight, or the screen fills with text.
- **Proximity, not broadcast.** Show barks to players near the NPC. A bark in a bubble over the NPC's head is the natural form; `TextChatService:DisplayBubble` works from client-side scripts only (Roblox docs, as of October 2026), so trigger it locally ([[Text Chat Customization with TextChatService]]).
- **Barks react to state.** "Nice blade" when the player equips a rare one, "Quarry still overrun?" before the quest is done and "Ore is flowing again" after. Reactive barks make a world feel aware with very little text.
- **Never put instructions only in a bark.** Barks are missed by design.

```lua
--!strict
-- Picks a bark variant without repeating the previous one, with a per-key cooldown.
-- Client-side: the bubble is local, so each player gets their own timing.
local TextChatService = game:GetService("TextChatService")

local COOLDOWN = 30 -- seconds per NPC and trigger (rule of thumb)
local lastIndex: { [string]: number } = {}
local lastTime: { [string]: number } = {}
local rng = Random.new()

local function bark(npcHead: BasePart, npcId: string, trigger: string, variants: { string })
	local key = npcId .. "/" .. trigger
	local now = os.clock()
	if now - (lastTime[key] or -math.huge) < COOLDOWN or #variants == 0 then
		return
	end
	local index = rng:NextInteger(1, #variants)
	if #variants > 1 and index == lastIndex[key] then
		index = index % #variants + 1 -- step to the next one instead of repeating
	end
	lastIndex[key], lastTime[key] = index, now
	TextChatService:DisplayBubble(npcHead, variants[index])
end

return bark
```

In a real game, `variants` would be already-translated strings resolved from keys on the client, the same way dialogue lines are ([[Dialogue System End to End]], section 7).

---

## 8. Dialogue in a shared server

Roblox is multiplayer by default, and that changes dialogue in ways single-player writing never meets:

- **Private panels for conversations.** Each player's conversation is theirs; others see the player standing near the NPC, not the text. Do not broadcast one player's conversation to the server.
- **Group moments need a rule.** If a story beat involves the whole party, decide who chooses (leader, majority vote with a timer, first press) and show who picked what. The social moment is part of the fun ([[Genre Playbook - Horror and Story]], [[Social Design and Multiplayer Play]]).
- **Do not freeze the player.** Locking movement during dialogue in a server with enemies or other players is risky. Keep players able to move; end the conversation if they walk off.
- **Friends talk over you.** Assume voice chat and text chat are running. Short lines that can be re-read at a glance work; long monologues get lost.
- **Late joiners.** If a world event has a spoken intro, players who join late need a one-line recap or an NPC who will repeat the gist ("Previously..." lines, [[Genre Playbook - Horror and Story]]).

---

## 9. Safety, tone and audience

Authored dialogue does not go through the text filter (it is your text, not a player's), which means you carry full responsibility for it.

- **Write to the game's maturity label.** Violence, fear and crude humour all have to match the content maturity questionnaire you filled in ([[Roblox Policies Ratings and Compliance]]). A single line can push a game into a different label.
- **No romance or relationship talk directed at the player.** On a platform with many children, NPCs flirting with players reads badly to parents and moderators alike (rule of thumb).
- **No real-world politics, religion, or real people.** They date, they divide, and they can break platform rules.
- **Player text inside NPC lines must be filtered.** If a line inserts something a player typed (a pet name, a guild name, a sign another player wrote), it must go through `TextService:FilterStringAsync` and the right `TextFilterResult` method for who sees it, before it is shown. Display names are already filtered by Roblox.
- **Do not use dialogue to pressure purchases.** "Only real heroes buy the Gold Pass" in an NPC's mouth is still manipulation ([[Ethical Design and Player Trust]]).
- **Accessibility.** Text must be readable at the player's preferred size; respect reduced motion for typewriters; never put essential information only in audio ([[Accessibility]]).

---

## 10. The editing pass

Write the scene, then edit it in this order. Each pass usually cuts 20 to 40 percent (rule of thumb).

1. **Read it aloud in the character's voice.** Anything you stumble over, players will skip.
2. **Cut the opener.** Delete the first sentence of each screen and see if anything is lost. Often nothing is.
3. **Delete what the world shows.** Names in the speaker label, professions shown by the set, directions shown by the waypoint.
4. **Count words per screen.** Anything over 18 gets split or cut.
5. **Count screens before action.** More than 3 "Continue" taps in a row: add a choice or cut screens.
6. **Check every choice.** Does each one produce a different reply or outcome? Is there an exit? Is the likely choice first?
7. **Check the skip path.** Tap through every line without reading. Do you still know what to do next?
8. **Check for idioms and puns.** Mark them for translators or rewrite them ([[Localization-Ready Writing]]).
9. **Test on a phone at the longest line.** In English and in your biggest second language.
10. **Playtest with someone young or reading in a second language.** Watch where they tap through. Those lines are your next cuts.

---

## 11. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Wall of text on first meeting | First conversation over 50 words | Split, cut the opener, move backstory to optional choices |
| Critical instruction only in dialogue | Skip-path test leaves you lost | Repeat it in the tracker and waypoint |
| Every NPC sounds the same | Remove speaker labels; you cannot tell who is speaking | Voice cards with one trait each |
| Fake choices | Two buttons, same reply | Merge them or give each a different reply |
| Choice text that summarises | "[Accept quest]" everywhere | Write what the player says; reserve summaries for costly choices |
| Deep full branching | Screen count far above what one player sees | Hub and spokes, branch and merge, state flags |
| One bark variant | Players quote it mockingly | 3 to 5 variants, no repeats, cooldown |
| Memes and slang | Lines that need this month's internet to make sense | Character humour instead |
| Player name in every line | Name appears more than once per conversation | Once, at a meaningful moment |
| Purchase hidden in dialogue | A talk choice that spends currency | Make purchases look like purchases |

## 12. Checklist

- [ ] Every screen is 18 words or fewer; no more than 3 screens before the player acts.
- [ ] First conversation with any NPC is under about 50 words.
- [ ] Every critical instruction is also in the tracker or world guidance.
- [ ] Each speaking character has a voice card; lines pass the "no speaker label" test.
- [ ] Every conversation has an exit; likely choice first; no fake choices.
- [ ] Branching shape chosen per NPC (hub, merge or state), with a screen count.
- [ ] Barks have 3 to 5 variants, cooldowns and proximity.
- [ ] Lines match the maturity label; no romance at players; player text filtered.
- [ ] Idioms and jokes marked for translators.
- [ ] Longest line tested on a phone in English and the top second language.

## See also

[[Narrative Start Here]] · [[Dialogue System End to End]] · [[Lore Delivery Without Walls of Text]] · [[Quest Writing and Hooks]] · [[Naming Items Zones and Abilities]] · [[Localization-Ready Writing]] · [[Genre Playbook - Horror and Story]] · [[First-Time User Experience and Onboarding]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[Text Chat Customization with TextChatService]] · [[Accessibility]] · [[Ethical Design and Player Trust]] · [[Social Design and Multiplayer Play]]

## Connected notes
<!-- auto-links:start -->
[[Localization Pipeline]] · Captions and Audio Accessibility · Notification and Toast Systems · Readable Text and UI Scale · Voice Chat and Safety Features · Official Docs - Security and Moderation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Captions and Audio Accessibility]] · [[Story State Flags and Chapter Saves]] · [[Notification and Toast Systems]] · [[Voice Chat and Safety Features]] · [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]] · [[Puzzle Dependency Charts and Hint Systems]]
<!-- related:end -->
