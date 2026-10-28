---
tags: [pipelines, localization, translation, text, ui, csv]
---
# Localization Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Concatenating translated fragments. Symptom: grammatically broken sentences in other languages.
> - Avoid: Images with baked-in text. Symptom: English text remains on banners and buttons in every language.
> - Avoid: Translating ids and keys. Symptom: lookups break when a key is translated along with display text.
> - No player-facing literals in code; keys with named placeholders
> - Context on ambiguous strings; plural variants as keys
> - Source CSV generated from code and data, kept in Git
>
> Cost: TL;DR ~170 tok · whole note ~4.8k tok. Read more: ## Stage 1: write text for translation · ## Nuances and edge cases · ## Checklist · ## Common mistakes
<!-- tldr:end -->

Roblox has a large non-English audience, and the platform does a lot of translation work for you: it can capture in-game text automatically, translate it automatically for supported languages, and swap it at runtime. That makes it tempting to treat localization as "turn it on and forget it". In practice the automatic layer only works well when the game's text is **built for it**: stable keys, no text glued together in code, placeholders instead of concatenation, UI that survives longer strings, and a review loop for the strings that matter. This note is the pipeline that gets there. Concepts and APIs are introduced in [[Localization]]; text rendering in [[Text Fonts and Rich Text]]; UI sizing in [[UI Asset Pipeline]] and [[Responsive UI for Phone Tablet Console and PC]].

## The moving parts on Roblox

| Part | What it does |
|---|---|
| **LocalizationTable** | holds entries: `Key`, `Source`, `Context`, `Example`, and `Values` (a dictionary of locale code to translated text). Edited in Studio, on the Creator Hub, or via CSV |
| **Automatic text capture** | records text that appears in the running game into the experience's cloud table, so you do not have to list it by hand |
| **Automatic translation** | Roblox machine-translates captured or uploaded strings for supported languages; manual translations take priority (check the current language list and behaviour in the docs, as of October 2026) |
| **AutoLocalize** | a property on GUI objects; when on, the engine replaces matching source text with the player's translation at runtime |
| **Translator** | `LocalizationService:GetTranslatorForPlayerAsync(player)` returns a Translator; `Translator:FormatByKey(key, args)` formats a keyed string with arguments |
| **Translator Portal / Creator Hub** | where humans review and edit translations; CSV download and upload for bulk work |

Roblox's docs describe the CSV round trip (download, edit, upload) through Studio or the Creator Hub's table management, and note that the CSV exposes Key, Context and Example fields the Translator Portal does not. A user report on the Developer Forum describes large CSV uploads failing on the web dashboard while Studio's localization tools handled the same file; if a web upload fails, try Studio (user-reported, not an official limit).

## The stages

| # | Stage | Output | Gate |
|---|---|---|---|
| 1 | Write text with keys | a strings module or keyed table, no hard-coded player text | lint: no literal player text in code |
| 2 | Extract | source CSV (Key, Source, Context, Example) | unique keys, placeholders well-formed |
| 3 | Translate | target columns filled (machine, then human for key strings) | placeholder parity, length budget |
| 4 | Import | localization table in the experience | row count matches |
| 5 | Test | pseudo-locale and real locales in Studio | no clipped or overflowing text |
| 6 | Capture and review | captured strings reviewed, junk removed | no player names or numbers captured as entries |
| 7 | Record | changelog, CSV in Git | |

## Stage 1: write text for translation

Most localization bugs are written into the code months before anyone translates anything.

| Do | Do not | Why |
|---|---|---|
| `T("quest.slay", { count = 3, zone = zoneName })` | `"Slay " .. n .. " enemies in " .. zone .. "!"` | word order differs by language; concatenation cannot be translated as one sentence |
| one key per full sentence | building sentences from fragments | fragments translate without context and come out wrong |
| plural variants as separate keys (`items.one`, `items.many`) | `n .. " item" .. (n > 1 and "s" or "")` | plural rules differ; some languages have several plural forms |
| context on ambiguous words (`Context = "button: start a roll"`) | a bare "Roll" | "Roll" as a verb, a noun, a bread... |
| numbers formatted by one helper | `string.format("%d", n)` everywhere | thousands separators, decimal commas, your K/M/B suffixes |
| short, plain sentences | jokes and idioms in core UI | plain text translates reliably |

The reference project's player-text rule was "plain, short, no em dashes", enforced in its pipelines. That rule happens to be a good localization rule too.

A small strings module that works with or without the localization table:

```lua
--!strict
-- Strings: keyed text with named placeholders. English source lives here (and in the CSV);
-- translations come from the cloud table via the player's Translator.
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local SOURCE: { [string]: string } = {
	["quest.slay"] = "Slay {count} enemies in {zone}!",
	["shop.buy"] = "Buy",
	["reward.claimed"] = "Claimed {amount} gems",
}

local translator: Translator? = nil
task.spawn(function()
	local ok, t = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(Players.LocalPlayer)
	end)
	if ok then translator = t end
end)

local function fallback(key: string, args: { [string]: any }?): string
	local text = SOURCE[key] or key
	if args then
		text = string.gsub(text, "{(%w+)}", function(name)
			local v = args[name]
			return if v ~= nil then tostring(v) else "{" .. name .. "}"
		end)
	end
	return text
end

local function T(key: string, args: { [string]: any }?): string
	if translator then
		local ok, out = pcall(function()
			return translator:FormatByKey(key, args or {})
		end)
		if ok then return out end -- key missing in the table: fall through to source
	end
	return fallback(key, args)
end

return T
```

This sketch is client-side (it uses `LocalPlayer`). Server-generated text that players see (system messages, notifications) should send a **key and arguments** to the client, not a finished English string, so each client formats it in its own language.

## Stage 2: extract to CSV

Generate the source CSV from the strings module (and from any data tables with player text: item names, lore lines, quest descriptions), rather than from what automatic capture happened to see. Columns follow the table format: `Key, Source, Context, Example`, then one column per locale.

```python
# tools/extract_strings.py : strings + item names -> localization CSV (UTF-8)
import csv, json, re, sys

src = json.load(open("data/strings_en.json", encoding="utf-8"))          # key -> source
items = json.load(open("data/items.json", encoding="utf-8"))              # id -> {name, lore}
locales = ["es", "pt", "fr", "de"]

rows = []
for key, text in sorted(src.items()):
    example = re.sub(r"\{(\w+)\}", lambda m: {"count": "3", "zone": "Green Valley", "amount": "250"}.get(m.group(1), "X"), text)
    rows.append({"Key": key, "Source": text, "Context": "", "Example": example})
for item_id, it in sorted(items.items()):
    rows.append({"Key": f"item.{item_id}.name", "Source": it["name"], "Context": "item name, short", "Example": ""})
    if it.get("lore"):
        rows.append({"Key": f"item.{item_id}.lore", "Source": it["lore"], "Context": "item flavour text, one line", "Example": ""})

with open(sys.argv[1], "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["Key", "Source", "Context", "Example"] + locales)
    w.writeheader()
    for r in rows:
        w.writerow(r)
print(len(rows), "rows")
```

Keep this CSV in Git. Every text change becomes a diff that a translator can see.

## Stage 3: translate and validate

A practical policy (rule of thumb):

- let automatic translation cover the long tail (item lore, minor UI);
- have a human (community translator or paid) review **the first five minutes of text**: onboarding, the main HUD, the shop, purchase prompts and any text near Robux. Those strings drive retention and refunds;
- never machine-translate legal or policy text you wrote yourself without review.

Validate translations offline before import:

```python
# tools/check_translations.py : placeholder parity and length budget
import csv, re, sys

PH = re.compile(r"\{(\w+)\}")
MAX_GROWTH = 1.6     # flag translations more than 60% longer than the source (rule of thumb)
bad = 0
with open(sys.argv[1], newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    locales = [c for c in reader.fieldnames if c not in ("Key", "Source", "Context", "Example")]
    for row in reader:
        src_ph = sorted(PH.findall(row["Source"]))
        for loc in locales:
            t = (row.get(loc) or "").strip()
            if not t:
                continue
            if sorted(PH.findall(t)) != src_ph:
                print(f"{row['Key']} [{loc}]: placeholders {PH.findall(t)} != {src_ph}"); bad += 1
            if len(t) > MAX_GROWTH * max(len(row["Source"]), 8):
                print(f"{row['Key']} [{loc}]: {len(t)} chars vs {len(row['Source'])} source"); bad += 1
sys.exit(1 if bad else 0)
```

A placeholder dropped or renamed in a translation is the most common runtime localization bug: the player sees `{count}` or loses the number entirely.

## Stage 4: import

Import the CSV through Studio's localization tools or the Creator Hub table management (Roblox docs). Remember from the docs: **removing a row from the CSV does not delete the entry**; deleting requires clearing the table and re-uploading, or Studio's replace option. Plan deletions deliberately, and keep the previous CSV so you can restore.

For tables built by script (for example a `LocalizationTable` instance shipped inside the place for a specific feature), use `LocalizationTable:SetEntries(entries)` with entries shaped `{ Key = ..., Source = ..., Context = ..., Values = { es = "...", fr = "..." } }`, and the per-field setters (`SetEntryValue`, `SetEntryContext`, `SetEntryExample`) for edits. The older `SetContents`, `SetEntry`, `GetString` and `RemoveKey` are deprecated.

As of October 2026, check the Open Cloud reference for any localization endpoints before building automation on them; this note could not confirm a stable Open Cloud localization table API.

## Stage 5: test

### Pseudo-localization

Before real translations exist, test with a fake locale that makes problems visible: wrap every string in brackets, pad it about 40% longer, and swap letters for accented ones. Clipped brackets show truncation; unaccented text shows hard-coded strings that bypass the pipeline.

```python
def pseudo(text):
    table = str.maketrans("aeiouAEIOUcnsy", "àéîõüÀÉÎÕÜçñšý")
    body = re.sub(r"(\{\w+\})|([^{}]+)", lambda m: m.group(1) or m.group(2).translate(table), text)
    pad = "~" * max(2, int(len(text) * 0.4))
    return f"[{body}{pad}]"
```

Write the pseudo strings into a spare locale column for test builds only.

### Real locales

Studio's Player Emulator lets you test as a different locale. Check, per locale, on desktop and on a phone viewport:

- no clipped text (German and Portuguese often run about 20 to 35% longer than English; rule of thumb);
- `TextScaled` labels do not shrink below readable size (pair them with `UITextSizeConstraint`; see [[UI Asset Pipeline]] for the 12 px floor one production game used);
- buttons with captions grow or wrap gracefully (`AutomaticSize`, `TextWrapped`);
- fonts cover the script: Roblox falls back for glyphs a font lacks, but stylised display fonts may look different in other scripts. Test CJK, Cyrillic, Arabic and Thai if you support them;
- right-to-left languages, if supported, need layout review, not just text.

## Stage 6: automatic capture hygiene

Automatic text capture records what players see. It also records things that should not be translation entries: player names, numbers, timers, generated text, debug strings. Over time the table fills with junk entries, which then get machine-translated.

Prevent it at the source:

- set `AutoLocalize = false` on labels that show player names, numbers, timers and other dynamic values, and format those through your own helpers;
- turn off capture for text that changes every frame;
- review captured entries periodically and delete junk.

Automated text passes can also damage localization. The reference project ran a font and text standardisation pass that re-cased ALL-CAPS words of four or more letters into Title Case (short acronyms kept) and skipped fast-changing text (more than five changes a second). That is a sensible English rule; applied to translated strings it can break languages with different casing rules. Run text transforms **on source strings before translation**, never on translated output at runtime.

## Stage 7: record

Commit the CSV, the strings module and the item data together. Log which locales were reviewed by a human and when. When source text changes, mark the affected keys for re-translation (a `source_hash` column makes stale translations easy to find).

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Sentence in the wrong order in Spanish | concatenation in code | one key per sentence with named placeholders |
| `{count}` shown to players | placeholder lost in translation | placeholder parity gate |
| Text clipped in German | fixed-size labels | auto-size, wrap, length budget, phone tests |
| Player names in the translation table | capture on dynamic labels | `AutoLocalize = false` on dynamic text |
| Deleted text still translated | CSV row removal does not delete | clear and re-upload, or Studio replace |
| Server message always English | server formats the final string | send key + args, format on the client |
| Translations change after a text pass | runtime transforms on translated text | transform sources only |

## Checklist

- [ ] No player-facing literals in code; keys with named placeholders
- [ ] Context on ambiguous strings; plural variants as keys
- [ ] Source CSV generated from code and data, kept in Git
- [ ] Machine translation for the long tail, human review for onboarding, shop and purchases
- [ ] Placeholder parity and length checks before import
- [ ] Pseudo-locale test build; real-locale tests on phone viewports
- [ ] `AutoLocalize = false` on dynamic text; capture reviewed
- [ ] Deletions planned (clear and re-upload)

## See also

[[Localization]] · [[Text Fonts and Rich Text]] · [[UI Asset Pipeline]] · [[Accessibility]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[First-Time User Experience and Onboarding]] · [[Strings Patterns and Formatting]] · [[Pipeline Design Principles]]

## Nuances and edge cases

1. **Automatic translation is good enough for most UI and bad for jokes, names and tone.** Short labels ("Play", "Shop", "Equip") translate well. Puns, item names with wordplay, lore and anything with personality often come out flat or wrong. Spend human review on the strings players see most (first-time flow, shop, main HUD) and the ones that carry the game's voice, and let automatic translation cover the long tail.
2. **Which languages first.** Translation effort should follow the audience. Check the analytics breakdown of players by language and fix the top few languages properly before adding more. A small game may find that one or two non-English languages make up a large share of players; those deserve review first.
3. **Length growth.** Translated text is often longer than English; German and some Romance languages commonly run 20 to 35 percent longer for UI strings (rule of thumb from localization practice). Very short English labels can double. Some languages are shorter but need taller lines. Budget space accordingly and test with pseudo-localization before real translations exist.
4. **Right-to-left and scripts.** Arabic and Hebrew read right to left; some scripts need fonts with full glyph coverage. Check which languages Roblox supports for automatic translation and whether your chosen fonts render them; a custom display font that lacks the glyphs falls back or shows boxes. Mirroring a whole UI for right-to-left is a big job; at minimum, make sure text alignment and number placement do not break.
5. **Numbers, dates and plurals.** "1 coins" is wrong in English and plural rules vary much more in other languages (some have several plural forms). Prefer phrasing that avoids plural agreement ("Coins: 5"), or keep separate keys per plural case where it matters. Dates and times should use formats players recognise or avoid absolute dates in favour of countdowns.
6. **Server-generated text.** Text built on the server reaches the client already formatted in the server's language. Send keys and arguments and format on the client, where the player's locale is known. This also keeps translations working for system messages and notifications.
7. **Text filtering and translation.** User-generated text (pet names, signs, chat) must go through the text filter and should not be auto-localized. Mark those labels so automatic capture skips them; otherwise the translation table fills with player names.
8. **Updates and stale translations.** Changing the English source of a key leaves old translations that may no longer match. Track changed sources and mark their translations for review, or the German text will describe last season's event.

## Common mistakes

1. **Concatenating translated fragments.** Symptom: grammatically broken sentences in other languages. Fix: whole sentences with named placeholders.
2. **Images with baked-in text.** Symptom: English text remains on banners and buttons in every language. Fix: keep text as labels over images, or make per-language images for key art.
3. **Translating ids and keys.** Symptom: lookups break when a key is translated along with display text. Fix: keep ids and display names separate.
4. **Fixed-size buttons sized for English.** Symptom: clipped or tiny text in other languages. Fix: auto-size with a minimum text size, test with long pseudo-locale strings.
5. **No in-game language test.** Symptom: issues found by players, not the team. Fix: switch the test account's language and play the first ten minutes.
6. **Auto-capture on dynamic text.** Symptom: player names and numbers flood the translation table. Fix: turn off auto-localize on dynamic labels.
7. **Store page left English only.** Symptom: good in-game translation but low click-through from other regions. Fix: localize the experience name, description and thumbnails where supported.

## Related decisions

- [[Localization-Ready Writing]]: writing source text that translates cleanly.
- [[Naming Items Zones and Abilities]]: names that survive translation.
- [[Readable Text and UI Scale]]: keeping longer translations readable.
- [[Analytics and Funnels]]: deciding which languages to prioritise.
- [[Discovery and the Algorithm]]: how a localized store page affects reach.
- [[Text Chat Customization with TextChatService]]: user text that must be filtered, not translated.
- [[Notification and Toast Systems]]: sending keys and arguments rather than final strings.
- [[Difficulty Options and Cognitive Load]]: plain language helps both translation and accessibility.
- [[Patch Notes and Player Communication]]: keeping update text in sync across languages.

## Connected notes
<!-- auto-links:start -->
[[Dialogue System End to End]] · [[Narrative Start Here]] · [[Writing Dialogue for Roblox Players]] · [[Cookbook - Tables Strings and Time]] · [[Quest Writing and Hooks]] · [[Lore Delivery Without Walls of Text]]
<!-- auto-links:end -->
