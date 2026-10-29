---
tags: [narrative, localization, writing, translation, i18n, strings, ui-text]
---
# Localization-Ready Writing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Sentences built from fragments -> One key per sentence, named placeholders
> - Avoid: English plural logic in code -> Label pattern or count-neutral wording
> - Avoid: Gendered player address -> Describe actions, use other subjects
> - Every translatable string is a complete sentence or label, one key each.
> - Placeholders are named and say what they hold.
> - No English plural logic in code; counts use labels or neutral wording.
>
> Cost: TL;DR ~150 tok · whole note ~5.7k tok. Read more: ## 8. A style guide and a glossary · ## 9. Linting the source · ## 12. Common mistakes · ## 13. Checklist
<!-- tldr:end -->

Localization problems are usually blamed on translators or on the translation tool, but most of them are written into the English source long before anyone translates it. A sentence built from three fragments, a label that reuses one word for two meanings, a pun that only works in English, a plural made by adding "s" in code, a line that calls the player "brave hero" in a language where adjectives agree with gender: each of these produces a broken or wrong translation no matter how good the translator is. This note is about writing English that translates well, by human translators and by Roblox's automatic translation alike.

It deliberately does not repeat the platform material. How automatic text capture, automatic translation, the cloud table, format specifiers and `Translator` work is in [[Localization]]. The keys, CSV extraction, placeholder parity checks, pseudo-localization and import process are in [[Localization Pipeline]]. Read those for the plumbing; read this for the words that go through it.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Linguistic facts (how many plural forms Polish has, which languages inflect nouns) are general knowledge about the languages, marked as rule of thumb where they are a simplification.

---

## 1. Why Roblox raises the stakes

- **Translation happens whether you plan for it or not.** Roblox docs state that players with automatic translations on will see game names, descriptions and in-game text translated even if you never enabled it (Roblox docs, as of October 2026; quoted in [[Localization]]). Every line you write is going to be machine-translated for some players. Write for that reader.
- **Machine translation is literal with fragments and idioms.** It handles short, complete, plain sentences well and fails on wordplay, ambiguity and pieces of sentences without context.
- **Players are young and many read in a second language even without translation.** Plain English helps them directly.
- **Rich text tags are stripped when text is localized** (Roblox docs). Formatting inside a sentence is lost in translation unless translators re-add it.
- **The parameter system has no plural or gender logic.** Roblox's dynamic-content guide describes parameters, format specifiers and a `translate` specifier, and says nothing about plural forms or grammatical gender (Roblox docs, as of October 2026). Everything that depends on those has to be solved in how you write.

---

## 2. Complete sentences, one key each

The first rule, and the one every other rule rests on: **a translatable string is a complete thought.** Never build a sentence out of separately translated pieces.

| Source pattern | What happens in translation |
|---|---|
| `T("You found") .. " " .. itemName .. " " .. T("in the") .. " " .. zoneName` | Each fragment is translated alone, in English word order. German puts the verb at the end, Japanese puts the object before the verb, Polish needs the item name in a different grammatical case. The result is word salad |
| `T("loot.found", { Item = itemName, Zone = zoneName })` with source "You found {Item} in {Zone}." | The translator sees the whole sentence and moves `{Item}` and `{Zone}` wherever their grammar needs them |

The [[Localization Pipeline]] note shows the code side of this. The writing side is: **when you write a line with variable parts, write it as one sentence with named holes, and give each hole a name that says what goes in it** (`{Item}`, `{Count}`, `{Zone}`, not `{1}`, `{2}`, `{x}`). Translators cannot see the game; the placeholder name is often their only clue.

**No trailing or leading spaces in strings.** A source string that ends in a space ("Reward: ") is almost always a fragment that something else will be appended to. It is a lint rule in section 9.

**No capital-letter-assumptions.** If a string is inserted at the start of another sentence, the inserted word may need a capital in English but not in German (or vice versa). Avoid inserting translated strings at sentence starts.

---

## 3. Plurals without plural support

English has two plural forms (1 item, 2 items). Many languages have more, and the rules differ (rule of thumb summary of well-known grammar): French treats 0 and 1 as singular; Russian, Polish and Ukrainian have different forms for 1, for 2 to 4, and for 5 and up (with exceptions for numbers ending in 12 to 14); Arabic has six forms; Japanese, Chinese, Korean, Thai and Indonesian usually do not inflect for number at all.

So the common code fix, `if n == 1 then "item" else "items"`, is wrong for half your languages: it encodes the English rule. And since Roblox's parameters have no plural selector (as of October 2026), you cannot hand the choice to the translator through a format specifier.

Patterns that work, in order of preference:

| Pattern | Source example | Why it works |
|---|---|---|
| Label plus number | "Enemies defeated: {Count:int}" | No noun-number agreement anywhere; every language can phrase a label |
| Noun as a heading, number alone | "Iron Ore" heading with "3/5" under it | No sentence at all |
| Count-neutral rewording | "Defeat the Quarry Beetles ({Count:int} left)" | The plural noun does not depend on the number |
| Fixed numbers in fixed strings | "Defeat 10 Quarry Beetles" when the count is always 10 | Translator sees and handles the exact number |
| Separate keys per English form, chosen in code | `beetles.one` / `beetles.other` | Works for English and languages like it; still wrong for Slavic and Arabic. Last resort |

For a game whose biggest audiences include Slavic or Arabic speakers, the last pattern produces visibly wrong grammar. The label pattern is ugly in a story line but perfect on a tracker, and the tracker is where most counted text lives ([[Quest Writing and Hooks]]).

---

## 4. Gender and the player

Roblox games do not know the player's gender, and should not ask. English hides this: "You are brave" has no gender. Many languages do not: in Spanish, French, Italian, Portuguese, Polish, Russian and Arabic (among others), adjectives, past participles and sometimes verbs agree with the gender of the person described (rule of thumb summary). "You are brave" becomes "eres valiente" (neutral in Spanish, luckily) but "you were chosen" becomes "fuiste elegido" or "fuiste elegida".

Write so the player is described by actions and nouns, not by adjectives and participles:

| Avoid | Prefer | Why |
|---|---|---|
| "You are the chosen one." | "The bell chose you." | The bell is the subject; nothing agrees with the player |
| "Welcome back, brave hero!" | "Welcome back!" or "Welcome back, {Player}!" | No gendered noun or adjective |
| "You are ready." | "You have what it takes." / "Time to go." | Avoids a participle that agrees |
| "Are you lost?" | "Need directions?" | Avoids "perdido/perdida" |
| "You were defeated." | "Defeated!" as a status, or "The Warden won this round." | Status words and other subjects are safer |

The same applies to NPCs referring to other players ("{Player} is the strongest"), where the other player's gender is also unknown. And to NPCs themselves: give translators the NPC's gender in the context column, so "Hedda said she was tired" translates with the right forms.

**Formal versus informal "you".** French, German, Spanish, Portuguese, Polish, Russian, Japanese and others distinguish a formal and an informal "you" (rule of thumb). Decide once, per game or per character, and tell translators: most Roblox games use informal address for UI, and character-specific choices for NPCs (a royal guard might use the formal form). Put it in the style guide (section 8).

---

## 5. Names inside sentences

Inserting a name into a sentence is risky in languages that inflect nouns. In Polish, Russian, Finnish, Hungarian, Turkish and others, a noun changes form depending on its role in the sentence (rule of thumb). "You found the {Item}" may need the item name in a different case from "{Item} was destroyed", and an inserted name cannot change form.

Patterns:

- **Label pattern for system messages.** "New item: {Item}" or "Added to inventory: {Item}". The name sits after a colon, in its dictionary form, in any language.
- **Restructure so the name is the subject.** "{Item} is now yours." is usually safer than "You received {Item}." because subjects tend to keep the base form.
- **For story lines, write the name into the string.** If an NPC says "Bring me the Warden's Lantern", and the lantern is always the same item, write it literally into the key. The translator then translates the whole sentence, with the name in the right form.
- **Never insert a translated common noun into a sentence.** "Defeat 10 {EnemyType}" with `EnemyType = "beetles"` is a fragment in disguise.

Item and zone names that are proper names (invented, untranslated) are less of a problem: languages usually leave foreign proper names uninflected or use a regular pattern. Translated names ("the Drowned Quarry" becoming a native phrase) behave like common nouns and inflect. This is one reason to decide translate-or-keep for each name category, which brings us to the glossary.

---

## 6. Words with two meanings

English reuses short words heavily. Short UI words are the most ambiguous strings in a game and the most likely to be mistranslated.

| Word | Meanings in a game | Possible mistranslation |
|---|---|---|
| Roll | Dice roll, dodge roll, bread roll, roll call | A bakery in your RNG game |
| Spin | Spin the wheel, a spinning attack | Laundry spin cycle |
| Free | Costs nothing, released from a cage | "Liberate" on a price tag |
| Claim | Collect a reward, assert something | A legal claim |
| Boost | Temporary buff, a lift up | A rocket booster |
| Back | Return to previous screen, the body part | Anatomy |
| Rebirth | Prestige reset | Religious meaning |
| Level | Player level, a stage, flat | A carpenter's level |

Two rules:

1. **One key per meaning.** If "Roll" is a button for the RNG and also a dodge move, those are two keys (`button.roll_rng`, `move.dodge_roll`) even though the English is identical. Roblox's localization table supports per-context translations, matched by the instance path in the Context field (Roblox docs), but separate keys are clearer and survive moving UI around.
2. **Always fill the Context column** for short strings: "button: roll the RNG for a new weapon". The translator, and the machine translator for that matter, has no idea what a one-word string means without it. The extraction step in [[Localization Pipeline]] has a Context column; it is only useful if the writer fills it.

---

## 7. Idioms, puns, jokes and tone

- **Idioms translate literally.** "Break a leg", "piece of cake", "hit the road", "on fire" (meaning doing well) all come out as nonsense or alarming in machine translation. Use plain words in UI and system text.
- **Puns are untranslatable by definition.** A pun in an item name or a dialogue line has two options: cut it, or mark it for transcreation, meaning "translator: rewrite freely to make a joke in your language, keep the tone". Mark it in the context field: "PUN: 'dough' = money and bread. Rewrite freely."
- **Character voice survives if you describe it.** "Hedda: blunt, short sentences, drops words" in the context lets a translator reproduce the voice. Without it, every character comes out in the same neutral register.
- **Slang and memes are local.** A meme that is everywhere in the US may mean nothing in Brazil or Indonesia, and slang ages fast in every language. Character humour (a trait, a habit) travels; reference humour does not ([[Writing Dialogue for Roblox Players]]).
- **Shouting in capitals.** All-caps strings are harder to read, carry no meaning in scripts without case (CJK, Arabic, Thai, Hindi), and an automated case transform applied after translation can damage languages where capitalisation is grammatical. The reference project ran a pass that converted all-caps words of four or more letters to Title Case and learned it must be applied to source text only (measured in the reference project; see [[Localization Pipeline]]). Write in sentence case and let styling handle emphasis.
- **Emphasis inside sentences.** Since rich text tags are stripped in translation (Roblox docs), do not rely on a bold word mid-sentence to carry meaning. Style the whole label, or put the important part on its own line.

---

## 8. A style guide and a glossary

Every game that is translated, by humans or machines, benefits from two short documents. They are as much for your own writers as for translators.

### Style guide (one page)

| Section | Example decision |
|---|---|
| Address | Informal "you" in UI; NPC-specific in dialogue |
| Tone | Friendly, short, light humour; no sarcasm in instructions |
| Sentence length | Under 12 words in UI; one idea per sentence |
| Capitalisation | Sentence case for everything; Title Case only for proper names |
| Punctuation | No em dashes; no exclamation marks in errors; one "!" maximum anywhere |
| Numbers | Digits always; thousands separators through format specifiers |
| Abbreviations | Only K, M, B for large numbers (shown in non-localized labels); no "lvl", "pts", "dmg" in text |
| Player | Never described by adjectives; never gendered |
| Forbidden | Idioms, memes, real brands, real people |

The reference project's rule for player-facing text was "plain, short, no em dashes", enforced in its pipelines (measured in the reference project; see [[Localization Pipeline]]). That single line covers a surprising amount of this guide.

### Glossary (termbase)

A table of every game-specific term with its decision:

| Term | Category | Translate? | Context for translators |
|---|---|---|---|
| Drowned Quarry | Zone | Yes, keep meaning | A flooded mine, dark, dangerous |
| Hedda | NPC | No (proper name) | Female blacksmith, blunt |
| Emberfang | Weapon | No (proper name) | Fire sword; "ember" + "fang" |
| Gems | Premium currency | Yes, consistently | Always the same word everywhere |
| Rebirth | Mechanic | Yes, non-religious | Prestige reset of progress for a permanent bonus |
| Mythic | Rarity tier | Yes, or keep: decide per language | One tier in a long ladder; must sort correctly |

Rules of thumb for the translate-or-keep decision:

- **Translate** descriptive names (zones named with real words, item types, currencies, mechanics). Players should understand them.
- **Keep** invented proper names (characters, unique weapons, invented words). They are identity, and translating them breaks community vocabulary across languages.
- **Decide currencies and mechanics once.** A currency called three different things in three menus is the most common consistency bug in translated games.
- **Set `AutoLocalize` from the glossary.** Labels that show kept names should not be auto-translated ([[Localization]]). Drive this from the item config, not by hand.

The glossary is also the lore bible's glossary ([[Lore Delivery Without Walls of Text]]) and the naming list ([[Naming Items Zones and Abilities]]). Keep one table and export it to all three uses.

---

## 9. Linting the source

Most of the rules above can be checked automatically against your strings module or CSV before anything is translated. This Luau lint runs in a test or the command bar against a `{ [key]: source }` table.

```lua
--!strict
-- Lints English source strings for localization hazards.
type Rule = { name: string, test: (key: string, text: string) -> boolean }

local IDIOMS = { "piece of cake", "break a leg", "hit the road", "on fire", "no brainer", "a breeze" }

local LENGTH_BUDGET: { [string]: number } = { -- by key prefix (rule of thumb)
	["button."] = 14,
	["tracker."] = 40,
	["dialogue."] = 90,
	["npc."] = 90,
	["item."] = 100,
}

local function budgetFor(key: string): number?
	for prefix, budget in LENGTH_BUDGET do
		if string.sub(key, 1, #prefix) == prefix then
			return budget
		end
	end
	return nil
end

local RULES: { Rule } = {
	{ name = "leading or trailing space (fragment?)", test = function(_, text)
		return string.match(text, "^%s") ~= nil or string.match(text, "%s$") ~= nil
	end },
	{ name = "positional or unnamed placeholder", test = function(_, text)
		return string.find(text, "{%d") ~= nil or string.find(text, "{}", 1, true) ~= nil
	end },
	{ name = "English plural hack", test = function(_, text)
		return string.find(text, "(s)", 1, true) ~= nil
	end },
	{ name = "rich text tag (stripped in translation)", test = function(_, text)
		return string.match(text, "<%a+[^>]*>") ~= nil
	end },
	{ name = "em or en dash", test = function(_, text)
		return string.find(text, "\u{2014}", 1, true) ~= nil or string.find(text, "\u{2013}", 1, true) ~= nil
	end },
	{ name = "all-caps word", test = function(_, text)
		return string.match(text, "%f[%a]%u%u%u%u+%f[%A]") ~= nil
	end },
	{ name = "idiom", test = function(_, text)
		local lower = string.lower(text)
		for _, idiom in IDIOMS do
			if string.find(lower, idiom, 1, true) then
				return true
			end
		end
		return false
	end },
	{ name = "over length budget", test = function(key, text)
		local budget = budgetFor(key)
		return budget ~= nil and (utf8.len(text) or #text) > budget
	end },
}

local function lintStrings(source: { [string]: string }): { string }
	local problems: { string } = {}
	local byText: { [string]: string } = {}
	for key, text in source do
		for _, rule in RULES do
			if rule.test(key, text) then
				table.insert(problems, `{key}: {rule.name}: "{text}"`)
			end
		end
		-- Same English under two keys is fine (two meanings) but worth a look:
		-- make sure each key has its own Context.
		local other = byText[text]
		if other then
			table.insert(problems, `{key}: same text as {other}; check both have Context`)
		end
		byText[text] = key
	end
	table.sort(problems)
	return problems
end

return lintStrings
```

Notes:

- The all-caps rule flags words of four or more capitals, which mirrors the threshold the reference project used for its re-casing pass (short acronyms like "XP" or "HP" pass).
- The positional placeholder rule is a style choice: Roblox supports indexed parameters (Roblox docs), but named ones give translators context.
- Concatenation in code is a code smell this lint cannot see, because it lives in scripts, not strings. Search scripts for `..` next to calls to your translation function as a separate check ([[Localization Pipeline]] has a "no literal player text in code" gate).

---

## 10. Worked rewrites

| Source as written | Problems | Localization-ready source |
|---|---|---|
| "You have " .. n .. " gem" .. (n == 1 and "" or "s") .. " left!" | Fragments, English plural, exclamation | "Gems left: {Count:int}" |
| "Welcome back, brave warrior! Ready for more?" | Gendered noun and adjective, gendered "ready" | "Welcome back! The arena is open." |
| "ROLL NOW for a chance at MYTHIC loot!!" | All caps, ambiguous "roll", double "!" | key `button.roll_rng`, "Roll for a new weapon", context "button: RNG roll" |
| "That boss was a piece of cake, huh?" | Idiom | "That boss did not stand a chance." |
| "Defeat {Count} {Enemy}" with Enemy = "beetles" | Inserted common noun, plural | "Defeat {Count:int} Quarry Beetles" (enemy fixed per key) or "Quarry Beetles defeated: {Count:int}" |
| "You found the <b>Lantern</b> in {Zone}." | Rich text mid-sentence, inflected noun | "New item: Warden's Lantern" with the whole label styled |
| "Spin to win! " | Rhyme, trailing space fragment | "Spin the wheel" (context: "button: daily reward wheel") |

---

## 11. When not to bother

- **Prototype and jam games.** Writing rules cost little, but a glossary and lint are overhead. Follow the sentence and plural rules (they are free) and skip the rest until the game has players.
- **Text you will never translate on purpose** (an English-only competitive event, a tester tool) still gets machine-translated for players with automatic translation on, unless `AutoLocalize` is off. If it must stay English, turn capture and translation off for it ([[Localization]]).
- **Proper-noun-heavy lore.** A codex entry full of invented names will translate oddly no matter what. Keep it, give translators the glossary, and accept some roughness in the obsessed layer ([[Lore Delivery Without Walls of Text]]).

---

## 12. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Sentences built from fragments | Strings with trailing spaces; `..` around translation calls | One key per sentence, named placeholders |
| English plural logic in code | `n == 1` checks near text | Label pattern or count-neutral wording |
| Gendered player address | Adjectives and participles describing "you" | Describe actions, use other subjects |
| Inserted translated nouns | Placeholders filled with common nouns | Write the noun into the string, or use labels |
| One key for two meanings | Same short word on unrelated buttons | Separate keys, Context column filled |
| Idioms and puns unmarked | Lint hits; translators ask questions | Plain words; mark puns for transcreation |
| Mid-sentence formatting | Rich text tags in source | Style whole labels |
| No glossary | Currency named three ways in one language | One termbase shared with lore and naming |
| No formality decision | Mixed formal and informal "you" in one language | Style guide decision per game or character |

## 13. Checklist

- [ ] Every translatable string is a complete sentence or label, one key each.
- [ ] Placeholders are named and say what they hold.
- [ ] No English plural logic in code; counts use labels or neutral wording.
- [ ] The player is never described with gendered words; NPC gender given in context.
- [ ] Names inserted only in label positions or as subjects; fixed names written into strings.
- [ ] Short and ambiguous strings have their own keys and a Context.
- [ ] No idioms; puns marked for transcreation; character voice described for translators.
- [ ] Sentence case; no formatting inside sentences.
- [ ] One-page style guide and a shared glossary with translate-or-keep decisions.
- [ ] Source lint passes before each export.

## See also

[[Narrative Start Here]] · [[Localization]] · [[Localization Pipeline]] · [[Writing Dialogue for Roblox Players]] · [[Dialogue System End to End]] · [[Quest Writing and Hooks]] · [[Naming Items Zones and Abilities]] · [[Lore Delivery Without Walls of Text]] · [[Text Fonts and Rich Text]] · [[Strings Patterns and Formatting]] · [[Accessibility]]

## Connected notes
<!-- auto-links:start -->
[[Readable Text and UI Scale]] · [[Captions and Audio Accessibility]] · [[Cookbook - Tables Strings and Time]] · [[Prompting and Verifying AI Output]] · [[Notification and Toast Systems]] · [[Patch Notes and Player Communication]]
<!-- auto-links:end -->
