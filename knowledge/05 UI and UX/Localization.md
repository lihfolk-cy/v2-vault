---
tags: [ui, localization, translation, localizationservice, translator, i18n]
---
# Localization

Roblox players speak many languages, and Roblox will translate your game's text for some of them even if you do nothing: every user has an **Automatic Translations** account setting, and Docs state that if it is on, "all game names, game descriptions, and in-game text will be translated for them, even if you have not explicitly enabled translation". That is a free audience boost and a source of layout bugs at the same time. This note covers how automatic translation and capture work, what you must keep out of translation, scripted localization with `LocalizationService` and `Translator`, parameters and formatting, layout for text expansion, and the interactions with rich text and fonts.

Sources: **Docs** (the "Localization", "Automatic translation", "Translate dynamic content", "Localize with scripting" guides; `LocalizationService`, `LocalizationTable`, `Translator`, `GuiBase2d.AutoLocalize`; October 2026), the **reference project** (one production game, mostly English, with UI conventions that affect localization), and **rule of thumb**. Policies and quotas change: everything here is as of October 2026.

---

## 1. How Roblox translation works

### The pieces

| Piece | Role |
|---|---|
| Source language | The one language your game is written in (one at a time; defaults to your account language) |
| Supported languages | Languages you intend to provide translations for |
| Cloud localization table | Entries (source string, optional key, context, example) plus a translation per language, managed in the Creator Dashboard (Audience, Localization) |
| Automatic Text Capture (ATC) | Collects strings from UI that players (or Studio testers) encounter |
| Automatic translation | Machine-translates entries that have no translation |
| Manual translations | Yours or your translators'; always shown in preference to automatic ones (Docs) |
| `LocalizationTable` instances | Local tables for scripted lookups and testing |

### Automatic Text Capture

ATC adds text from UI elements players encounter to your table. Facts from Docs:

- It only captures objects with `AutoLocalize` enabled.
- For `TextBox`es only `PlaceholderText` is captured; `Text` is assumed to be player input.
- It can take **up to a few days** for strings to appear; Studio's own text capture (Window, Localization, Localization Tools, Automatic Text Capture) adds strings within 1 to 2 minutes while you play-test, and must be re-enabled each Studio session.
- It cannot capture: default leaderboards and chat, player-owned items and tools, images with embedded text, badge names and descriptions, pass names and descriptions pulled from the platform.
- It cleans up stale auto-captured strings by default (usernames, old events); manual entries and manually translated entries are kept.

### Automatic translation

- Translates only blank entries; never overrides manual translations (Docs).
- Has an **initial** and a **monthly quota**, counted **per character per language**: translating "hello" into 10 languages costs 5 x 10 = 50 characters (Docs).
- Automatic translations are refreshed when the translator improves. **Locking** an entry turns it into a manual entry that will not be updated, including by safety updates, and you remain responsible if it later violates policy (Docs).
- Supported automatic languages include Arabic, Chinese (Simplified and Traditional), English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese and more (Docs list; check the current table).

Turn it on in localization settings: enable **Use Translated Content**, then enable languages and choose whether experience information and/or in-game strings are translated.

---

## 2. What must not be translated

Disable `AutoLocalize` on objects whose text should never be translated (Docs): proper names (NPCs, bosses, weapons with invented names), player names, numbers, codes, and anything a script fills with dynamic data.

Why the dynamic case matters: ATC captures whatever string a label happens to show. A label showing "Gems: 1,240" captures "Gems: 1,240", then "Gems: 1,255", and so on, filling your table with junk and burning quota. Either:

- split the label into a translatable word ("Gems") and an `AutoLocalize = false` number, or
- use a parameterised entry and format it from a script (section 4).

`AutoLocalize` is inherited: setting it false on a container disables it for descendants unless they override.

Invented item names are a judgement call. A sword called "Moonsilver Edge" is flavour that can be translated; a sword named after a real-world historical type ("cinquedea", "kopis") usually should not be. Decide per category and set `AutoLocalize` from the item config, not by hand.

---

## 3. Layout for other languages

### Text expansion

Translations are rarely the same length. Rules of thumb used in the games industry: German and French run 20 to 35% longer than English on average and much longer for short strings (a 4-letter English button can become 12 letters); CJK languages are shorter in characters but need more height to stay legible.

| Technique | Use |
|---|---|
| `AutomaticSize` on labels and buttons | Let containers grow ([[Layout - Scale Offset and Constraints]]) |
| `TextWrapped` with room for two lines | Descriptions |
| A `UITextSizeConstraint` with a sensible `MinTextSize` | Single-line buttons that must not grow |
| `TextTruncate = AtEnd` | Last resort for lists |
| Flex layouts | Tabs that redistribute width ([[UI Layout Objects - Lists Grids and Pages]]) |
| Icons with short labels | Reduce text overall |

Test with a pseudo-localisation pass: temporarily wrap every string in brackets and pad it by 40% (for example "[Ŝĥöp ẋẋẋẋ]") through a script, then walk through every screen looking for clipping.

### Fonts

Not every family covers every script. Docs list the built-in families; many are Latin-only, and Roblox falls back to a font that covers the characters, which changes weight and style mid-sentence. Prefer families with broad coverage for body text (Builder Sans is Roblox's own UI family), and test Japanese, Korean, Chinese, Arabic and Hindi screens visually.

### Right-to-left

Arabic is in the automatic language list. `TextLabel.TextDirection` controls rendering direction. Mirroring whole layouts for RTL is rarely done in Roblox games; at minimum make sure Arabic labels have room and are not forced left-aligned in a way that clips.

### Case transforms

Code that changes case breaks translations. The reference project's font standard converted ALL-CAPS English words to Title Case; applied to a translated string, such a rule mangles languages where capitalisation carries meaning (German nouns) or has no meaning (CJK). Run case transforms on the source string before it reaches the label, or limit them to the source language. Rich text `<uppercase>` tags are subject to the stripping rule below.

### Rich text

Docs: localizing a game **removes rich text formatting tags**; to keep formatting in other languages, re-apply tags in the localized strings. Prefer styling whole labels (colour, weight via `FontFace`) instead of tagging words inside a sentence, or include the tags inside the translation entries.

### Images with text

ATC cannot read text in images (Docs). Either avoid text in images (use a label over the art), or localise the image asset itself through a keyed table entry (section 5).

---

## 4. Parameters and formatting

Entries can contain **parameters** in braces, so only the fixed part is translated (Docs): source `Hello {Player_Name}!`, Spanish `Hola {Player_Name}!`. Translators can reorder parameters to fit their grammar, which is why string concatenation in code is wrong for localised text ("You won " .. n .. " gems" cannot be reordered).

Format specifiers control number and time formatting per locale (Docs):

| Specifier | Output example |
|---|---|
| `int` | `1234` (no separators) |
| `fixed` | `1234.50` / `1234,50` (two decimals, no separators) |
| `num` | `1,234.50` / `1.234,50` (separators) |
| `HEX`, `hex` | `3FF`, `3ff` |
| `datetime` | `2017-10-10 13:38:10` (UTC timestamp to readable) |
| `iso8601` | `2017-10-12T22:02:38Z` |
| `shorttime` | `1:45 PM` / `13:45` (local hour:minute) |
| `shortdatetime` | `10/10/2017 1:45 PM` |

Example entry: key `QuestReward`, source `You earned {Amount:num} gems!`, filled with `translator:FormatByKey("QuestReward", { Amount = 1240 })`.

Abbreviated numbers ("1.2K", "4.6M") are a game convention, not a locale format; suffixes like K and M are widely understood in games but not universal. Keep them consistent and test that they are not captured as strings (render them in `AutoLocalize = false` labels).

---

## 5. Scripted localization

Use scripts when the text is built at runtime, for images and sounds per locale, or to fetch strings by key.

| API | Purpose (Docs) |
|---|---|
| `LocalizationService:GetTranslatorForPlayerAsync(player)` | Yields until the cloud table for the player's locale is loaded; returns a `Translator` |
| `LocalizationService:GetTranslatorForLocaleAsync(locale)` | Same for a specific locale |
| `Translator:FormatByKey(key, args)` | Translation by key, with parameters |
| `Translator:Translate(context, source)` | Translation by source string lookup |
| `Translator.LocaleId` | The translator's locale; changes when the player switches language |
| `LocalizationService.RobloxLocaleId`, `SystemLocaleId` | Locale for core features, and the OS locale |
| `LocalizationService:GetCountryRegionForPlayerAsync(player)` | Country or region code from IP geolocation |

Both `Get...Async` calls can fail on poor connectivity; wrap them in `pcall` and fall back (Docs recommend a helper module). When the player changes language in-game, auto-localised UI updates itself, but **text you set from scripts does not**; listen to the translator's `LocaleId` (Docs).

```lua
--!strict
-- Client TranslationHelper: player translator with a source-language fallback.
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local Helper = {}
Helper.changed = Instance.new("BindableEvent") -- fire to re-translate scripted text

local translator: Translator? = nil
local fallback: Translator? = nil

local function load()
	local ok, t = pcall(LocalizationService.GetTranslatorForPlayerAsync, LocalizationService, Players.LocalPlayer)
	if ok then
		translator = t
		t:GetPropertyChangedSignal("LocaleId"):Connect(function()
			Helper.changed:Fire()
		end)
	else
		warn("Translator unavailable:", t)
	end
	local okF, f = pcall(LocalizationService.GetTranslatorForLocaleAsync, LocalizationService, "en-us")
	if okF then
		fallback = f
	end
end
task.spawn(load)

-- Returns translated text by key, or the provided English default.
function Helper.format(key: string, args: { [string]: any }?, default: string): string
	for _, t in { translator, fallback } do
		if t then
			local ok, result = pcall(t.FormatByKey, t, key, args or {})
			if ok and type(result) == "string" then
				return result
			end
		end
	end
	-- last resort: naive {Param} replacement on the default text
	local text = default
	if args then
		for name, value in args do
			text = string.gsub(text, "{" .. name .. "[^}]*}", tostring(value))
		end
	end
	return text
end

return Helper
```

Usage: `label.Text = Helper.format("QuestReward", { Amount = 1240 }, "You earned {Amount:num} gems!")` with `label.AutoLocalize = false` (the script already translated it, and you do not want ATC capturing the result). Re-run such assignments on `Helper.changed`.

### Localising images and sounds

Add a keyed entry whose source and translations are **asset ids** (Docs example: a key such as `Key_JewelsImage` with one id per language), then `image.Image = "rbxassetid://" .. translator:FormatByKey("Key_JewelsImage")`.

---

## 6. Server-side text

The server can use translators too (for example to localise messages it sends), but most games translate on the client, where the player's locale is known and changes are visible. Messages the server sends should be **keys plus parameters**, not finished English sentences, so each client formats them in its own language. This is also cleaner for analytics and for changing wording later.

Player-generated text (chat, pet names, trade notes) is never translated by your tables. `TextService:FilterAndTranslateStringAsync` exists for filtered, translated user text (Docs); filtering itself is mandatory for any user text shown to others ([[Roblox Policies Ratings and Compliance]]).

---

## 7. Workflow that works

1. Write UI text in the source language with localisation in mind: no concatenation, no text in images, parameters for numbers and names.
2. Set `AutoLocalize = false` on names, numbers and script-filled labels from day one.
3. Turn on ATC and play-test in Studio with capture enabled to seed the table.
4. Review the table: delete junk entries (dynamic strings), add context and examples for ambiguous words ("Roll" as dice roll, not bread roll).
5. Enable automatic translation for your biggest audiences; watch quota.
6. Manually translate or review the strings that matter most (tutorial, shop, purchase descriptions) for your top languages.
7. Pseudo-localise and test every screen for clipping; test CJK and Arabic visually.
8. Use translation analytics in the localization page to decide where to invest next.

---

## Common mistakes

- Dynamic labels with `AutoLocalize` on: tables full of "Gems: 1,240".
- String concatenation for sentences with numbers.
- Rich text tags in translatable strings (stripped in translation).
- Text baked into images.
- Fixed-width buttons sized for English.
- Case transforms applied after translation.
- Scripted text that does not update when the player switches language.
- Locking machine translations without reviewing them.

## Checklist

- [ ] Source and supported languages set; translated content enabled.
- [ ] `AutoLocalize = false` on names, numbers and script-filled labels.
- [ ] Parameters and format specifiers instead of concatenation.
- [ ] Containers grow (`AutomaticSize`, flex, wrapping); pseudo-localisation pass done.
- [ ] Fonts tested with CJK, Arabic and Hindi.
- [ ] Scripted text uses a helper with fallback and re-translates on `LocaleId` change.
- [ ] Shop and tutorial strings reviewed by a human for top languages.

See also: [[Text Fonts and Rich Text]], [[Layout - Scale Offset and Constraints]], [[Accessibility]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[Publishing an Experience]], [[Discovery and the Algorithm]], [[Analytics and Funnels]].

## Connected notes
<!-- auto-links:start -->
[[Localization Pipeline]] · [[Localization-Ready Writing]] · [[Dialogue System End to End]] · [[Strings Patterns and Formatting]] · [[Readable Text and UI Scale]] · [[Naming Items Zones and Abilities]]
<!-- auto-links:end -->
