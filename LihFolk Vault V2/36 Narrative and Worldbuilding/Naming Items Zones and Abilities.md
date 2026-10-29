---
tags: [narrative, naming, items, zones, abilities, rarity, worldbuilding, content-pipeline, type/guide, area/narrative, level/intermediate, area/world]
---
# Naming Items Zones and Abilities

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Names that do not signal tier -> Name shape per tier band
> - Avoid: Near-duplicate names -> Edit distance check, different first syllables
> - Avoid: Saves keyed by display name -> Ids in saves; names from config
> - Naming pattern chosen per category and tier band.
> - Rarity tiers ordered and visible in UI; invented tier names tested on players.
> - Zones have a name, a short form, a number if progression is linear, and matching art.
>
> Cost: TL;DR ~150 tok · whole note ~5.6k tok. Read more: ## 3. Names as a rarity ladder · ## 10. A name validator · ## 12. Common mistakes · ## 13. Checklist
<!-- tldr:end -->

Names are the narrative text every player reads. A player who skips every line of dialogue still reads the name of the sword they just rolled, the zone they just entered and the button they press forty times a minute. Names carry tone, rarity, lore and function in two or three words, they become the vocabulary players use in chat, trades, videos and wikis, and once players have learned them they are expensive to change. This note covers what a name has to do, naming patterns that scale to catalogues of hundreds of items, rarity ladders expressed through names, zone and ability naming, length and distinctness budgets, the technical side (display names versus ids versus instance names), real-world names and legal risk, and a validator that catches problems before they ship.

Lore beyond names is in [[Lore Delivery Without Walls of Text]]. The translate-or-keep decision for names is in [[Localization-Ready Writing]] and [[Localization]]. Rarity design itself is in [[Rarity Ladders and Drop Pacing Math]] and [[Rarity Ladders and Drop Pacing Math]].

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. What a name has to do

| Job | Question to ask | Example of failure |
|---|---|---|
| Identify | Can players tell it apart from everything else? | "Shadow Blade" and "Shadow Edge" in the same catalogue |
| Signal | Does it hint at rarity, element, role or danger? | A top-tier item called "Iron Sword 2" |
| Fit | Does it belong to this world's tone? | "xX_DeathSlayer_Xx" in a cosy farming game |
| Be said | Can players say it in voice chat and type it in trade chat? | "Ægiswyrðr" |
| Be searched | Can players find it on a wiki, in a codex, in a filter box? | Names that differ only by an accent or a symbol |
| Survive | Will it still work in six months, in other languages, on a phone? | Meme names, puns that only work in English, 30-character names |

A good name does most of these at once. "Drowned Quarry" identifies a place, signals danger and water, fits a dark-fantasy tone, is easy to say and search, and survives translation (it can be translated literally). "Zone 4" identifies and survives but signals nothing. "The Abyssal Netherrealm of Eternal Torment" signals hard but fails length, fit and saying.

---

## 2. Patterns that scale

When a catalogue grows to hundreds of items, naming by inspiration stops working: names start to collide, tone drifts, and every new item takes a long discussion. Pick patterns per category and rarity, and generate candidates from them.

| Pattern | Shape | Example | Best for |
|---|---|---|---|
| Material plus type | [Material] [Type] | Iron Sword, Oak Staff | Low tiers; teaches the item types |
| Descriptor plus type | [Adjective] [Type] | Jagged Cleaver, Hollow Bow | Low to mid tiers |
| Origin plus type | [Place or faction] [Type] | Quarry Pick, Warden's Lantern | Ties items to zones; good for lore |
| Evocative compound | [Image][Noun] | Emberfang, Tidebreaker | Mid to high tiers |
| Proper name | A name with no type word | Hollowmourn, The Last Bell | Top tiers; feels unique |
| Real type name | A real historical or cultural item type | Gladius, Kopis, Claymore | Grounded settings; teaches history |
| Themed set | Names sharing a motif | A set named after constellations | Collections, events, seasons |

**Rules of thumb for compounds.** Two short words fused ("Ember" plus "fang") read well when each part is a common English word and the join does not create a new word by accident. Read the joined name aloud and look for unintended words inside it; this also matters for the chat filter (section 9).

**Do not mix patterns randomly within a tier.** If Rare items are "Descriptor plus type" and one Rare is a proper name, players will assume it is better than its tier.

---

## 3. Names as a rarity ladder

Players read names as rarity signals before they read the colour or the tag. Use that on purpose: the further up the ladder, the less "item type" and the more "identity" the name carries.

| Tier band | Name shape (rule of thumb) | Why |
|---|---|---|
| Common to Uncommon | Plain, descriptive, includes the type word | Teaches what things are; low emotional weight |
| Rare to Epic | Descriptor or origin plus type | Starts to feel specific; still readable as a category |
| Legendary to Mythic | Evocative compounds, origin names | Feels special; players start using the name, not the type |
| Top tiers and exclusives | Proper names, titles with "The" | Feels unique; becomes a status symbol |

The reference project ran a long rarity ladder from Common upward (measured in the reference project; see [[Rarity Ladders and Drop Pacing Math]]). Its catalogue showed both ends of the naming spectrum: one batch of weapons used real historical weapon types spread across every tier, from familiar ones at Common to rare, exotic ones at the top, while other batches used invented proper names and themed concepts at Mythic and above, plus a few purchase-only exclusives (measured in the reference project). Two lessons from that:

- **Real type names do not signal rarity on their own.** Most players do not know that a shotel is rarer than a kukri. If you use real names, the tier colour, the frame and the item card must carry the rarity, and the lore line can carry the history.
- **Top-tier names must be unmistakable.** At the top of a ladder, players trade and show off. A name that sounds like a mid-tier item undercuts the moment of rolling it.

**Rarity names themselves are names.** The tier labels (Common, Rare, Mythic, and so on) are a ladder of words players must be able to order without looking it up. Common, Uncommon, Rare, Epic and Legendary are widely understood from other games. Past Legendary there is no shared convention, so invented tier names (Mythic, Celestial, Divine, Eternal, and the like) need colour, effects and an always-visible order on the item card or the index screen. Two tiers whose names feel equivalent ("Divine" vs "Divine") will be misordered by players. Words with religious meaning can also land badly with some audiences; choose with that in mind.

---

## 4. Zone names

Zones are named once and read often: title cards, teleport buttons, quest objectives, the map, the player's conversation with friends ("meet me in the Quarry").

- **Name the feeling and the feature.** "Drowned Quarry", "Ashfields", "Lantern Market". One concrete feature (quarry, field, market) plus one mood word (drowned, ash, lantern).
- **Short form for UI.** Every zone needs a short form players will actually use ("the Quarry"). Put it on teleport buttons and the tracker if the full name is long.
- **Numbers alongside names, not instead.** Progression games benefit from a visible order ("Zone 4: Drowned Quarry"). The reference project replaced a "worlds" structure with a single zone number driving progression (measured in the reference project; see [[Progression and Pacing Design]]). A number gives order and makes balance maths simple; a name gives identity. Use both.
- **Match the art.** If the name says "Drowned", there must be water. Name and biome art should be decided together ([[Zone and Biome Art Direction]]).
- **Leave room in the sequence.** If zones 1 to 5 are named after a theme (seasons, elements), know what zones 6 to 10 will be before you ship 5. Themes that run out force awkward names later.
- **Hub names are the most said.** The lobby or hub name is in every "where are you?" message. Keep it to one or two words.

---

## 5. Ability and move names

Ability names live on buttons and in fast decisions. Their job is mostly functional.

| Rule | Why |
|---|---|
| Verb or effect first ("Dash", "Ground Slam", "Frost Nova") | Players learn by function; the name is a reminder of what happens |
| 1 to 2 words, under about 12 characters on buttons | Button labels on phones are tiny; long names truncate (rule of thumb) |
| Consistent vocabulary across kits | If "Slam" means an area hit in one kit, it should not mean a single-target hit in another |
| Ultimates can be grander | One evocative name per kit is affordable; everything else stays plain |
| Themed kits only when the theme reads instantly | A themed name must still suggest the effect |

Themed kits are memorable when the theme is obvious and each name still says what the move does. The reference project had a weapon modelled as a 3D transform gizmo whose three moves were named after the gizmo's three tools (move, rotate, scale), and another programming-themed weapon whose moves were named after familiar software failures, with the biggest failure as the ultimate (measured in the reference project). Both work because the player already knows the vocabulary and can guess the effect (a "scale" move that crushes, a "crash" ultimate that wipes the area). A theme the audience does not know (obscure mythology, specialist jargon) is just noise on a button.

**Icons carry more than names.** On ability buttons the icon is read first and the name second ([[Ability Kits Architecture]]). Name and icon must agree.

---

## 6. Length and distinctness budgets

| Name type | English length budget (rule of thumb) | Hard limit to test |
|---|---|---|
| Item name on a card | 6 to 18 characters | The longest name, translated, on the smallest card |
| Item name in a trade or chat line | Under 20 characters | Players will abbreviate anything longer |
| Zone name | 6 to 16 characters, plus a short form | Title card and teleport button |
| Ability on a button | 4 to 12 characters | The button at phone size |
| Rarity tier | 4 to 12 characters | The tag on the card frame |
| NPC name | 3 to 10 characters | The speaker label and nameplate |
| Quest title | 2 to 4 words | The quest log row |

Translations can grow 20 to 35 percent in European languages (rule of thumb, [[Localization]]), and names that are translated grow too. Test the longest name in the longest language.

**Distinctness rules:**

- **Different first syllable within a category.** Players scan the start of a name. "Emberfang" and "Embercall" in the same tier will be confused in trades.
- **No near-duplicates.** Names within an edit distance of 2 or 3 of each other in the same category are a trap (section 10's validator checks this).
- **No names that differ only by a symbol, number or accent.** "Ruin" and "Ruïn" are the same name to a player typing in a search box.
- **Avoid a shared suffix on everything.** If thirty items end in "-fang", the suffix stops meaning anything and the names blur.
- **Sequels are fine for upgrades, bad for distinct items.** "Iron Sword II" says "upgrade of Iron Sword". Use it only when that is true.

---

## 7. Display names, ids and instance names

Three different strings, and confusing them causes real bugs:

| String | Who sees it | Can it change? |
|---|---|---|
| **Id** (`"emberfang"`, `"zone_4"`) | Code and saves only | Never, once any save holds it |
| **Display name** ("Emberfang") | Players, through the localization table | Yes, freely |
| **Instance name** (the `Name` of a Model, Folder, clip or remote) | Code, Explorer | Yes, but code that finds it by name breaks |

Rules:

- **Saves store ids, never display names.** Renaming an item must not touch a single save. If your inventory saves `"Emberfang"` as the key, a rename becomes a migration ([[Data Schema Design and Migrations]], [[Saved Inventory End to End]]).
- **Display names come from config or the localization table, keyed by id.** Never from an instance's `Name`. Instance names are restricted by what code expects, and they are not translated.
- **Ids are lowercase, ASCII, no spaces, and never reused.** A retired item's id stays retired, so an old save never resolves to a new item.
- **Watch for instance-name collisions.** Code that finds children by name can pick up the wrong thing when a content name matches a system name. The reference project had a kit where a move clip named "Origin" sat in the same folder as the kit's `Origin` RemoteEvent, replaced it in name lookups, and the whole kit stopped dealing damage (measured in the reference project). After that, a short list of move names was reserved (Attack, Origin, FX, LocalCast, Moves and the rig folder's name). Keep a reserved-names list for any folder where content and systems share a parent, and check it in the validator.
- **Renames are cheap only if the above is true.** Then a rename is a one-line change in config plus a translation update.

---

## 8. Real-world names, culture and legal risk

- **Real item types** (gladius, katana, kopis, claymore) are generic words and fine to use. They come from real cultures; describe them respectfully in lore and avoid caricature.
- **Real people, brands, trademarks and other games' names are not yours.** Naming an item after a brand, a celebrity, a sports team or another game's character invites takedowns and moderation trouble (rule of thumb; see [[Roblox Policies Ratings and Compliance]] and Roblox's Terms of Use on intellectual property).
- **Religious and sacred names.** Names of deities, saints, sacred texts and holy places can offend and can create moderation problems. Fantasy-flavoured invented names are safer than borrowed sacred ones.
- **Real places.** A zone called after a real city or country can read as a statement about that place. Prefer invented places.
- **Historical violence.** Names referencing real wars, atrocities or extremist symbols are off-limits.
- **Check other languages.** An invented name can be a rude or unfortunate word in another language. Search each new invented name, and ask translators to flag problems ([[Localization-Ready Writing]]).

---

## 9. The chat filter and player-typed names

Your authored names are not filtered when you show them. But players will type them: in chat, in trade notes, in pet names, in guild names. Roblox's text filter does not know your invented words, and it is designed to be cautious with unknown strings and some patterns (rule of thumb; the filter's behaviour is not documented in detail).

- **Names that contain substrings resembling unsafe words** can be hashed out when players type them, which makes trading painful.
- **Names that contain numbers** can be hashed in some contexts, because number sequences can look like personal information to a filter (rule of thumb, observed by many developers, not documented as a rule).
- **Test in chat.** Before shipping a batch of names, type each one in a live test server's chat with a normal account and see what survives.
- **Give players structured ways to reference items** (trade UIs with item slots, link buttons) instead of making them type names.

---

## 10. A name validator

Run this in a test or the command bar against your item, zone and ability configs. It checks lengths, duplicates (case- and accent-insensitive in the simple ASCII sense), near-duplicates by edit distance, reserved names and id hygiene.

```lua
--!strict
-- NameLint: run against config tables of { id = displayName } per category.
type Category = {
	name: string,
	maxLength: number,
	minDistance: number, -- names closer than this (edit distance) are flagged
	entries: { [string]: string }, -- id -> English display name
}

local RESERVED: { [string]: boolean } = {
	attack = true, origin = true, fx = true, localcast = true, moves = true,
}

local function normalize(s: string): string
	-- Lowercase and strip everything that is not a letter or digit.
	return (string.gsub(string.lower(s), "[^%w]", ""))
end

local function editDistance(a: string, b: string): number
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end
	local prev: { number } = table.create(lb + 1, 0)
	for j = 0, lb do
		prev[j + 1] = j
	end
	for i = 1, la do
		local cur: { number } = table.create(lb + 1, 0)
		cur[1] = i
		local ca = string.byte(a, i)
		for j = 1, lb do
			local cost = if ca == string.byte(b, j) then 0 else 1
			cur[j + 1] = math.min(prev[j + 1] + 1, cur[j] + 1, prev[j] + cost)
		end
		prev = cur
	end
	return prev[lb + 1]
end

local function lint(categories: { Category }): { string }
	local problems: { string } = {}
	local allIds: { [string]: string } = {}
	for _, cat in categories do
		local seen: { [string]: string } = {}
		local list: { { id: string, norm: string } } = {}
		for id, display in cat.entries do
			if not string.match(id, "^[a-z0-9_]+$") then
				table.insert(problems, `{cat.name}/{id}: id must be lowercase a-z, 0-9, _`)
			end
			if allIds[id] then
				table.insert(problems, `{cat.name}/{id}: id also used in {allIds[id]}`)
			end
			allIds[id] = cat.name
			local length = utf8.len(display) or #display
			if length > cat.maxLength then
				table.insert(problems, `{cat.name}/{id}: "{display}" is {length} chars (max {cat.maxLength})`)
			end
			local norm = normalize(display)
			if RESERVED[norm] then
				table.insert(problems, `{cat.name}/{id}: "{display}" is a reserved name`)
			end
			if seen[norm] then
				table.insert(problems, `{cat.name}/{id}: "{display}" duplicates {seen[norm]}`)
			end
			seen[norm] = id
			table.insert(list, { id = id, norm = norm })
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				if a.norm ~= b.norm and editDistance(a.norm, b.norm) < cat.minDistance then
					table.insert(problems, `{cat.name}: "{cat.entries[a.id]}" and "{cat.entries[b.id]}" are too similar`)
				end
			end
		end
	end
	return problems
end

-- Example
local problems = lint({
	{ name = "Weapons", maxLength = 18, minDistance = 3, entries = {
		emberfang = "Emberfang", embercall = "Embercall", iron_sword = "Iron Sword",
	} },
	{ name = "Abilities", maxLength = 12, minDistance = 2, entries = {
		dash = "Dash", ground_slam = "Ground Slam", origin_strike = "Origin",
	} },
})
for _, p in problems do
	warn(p)
end
```

The pairwise comparison is quadratic: 500 names is about 125,000 comparisons of short strings, which runs in well under a second in Studio (rule of thumb; measure on your own machine). Run it in tests, not at runtime. The "similar first syllable" rule from section 6 is easier to check by eye on a sorted list than in code: sort display names alphabetically and read the list.

---

## 11. Changing names in a live game

- **Players learn names fast and resist renames.** A renamed item breaks wiki pages, videos, trade-value lists and players' memory. Rename only for a real reason (confusion, a policy problem, a collision).
- **Announce renames in patch notes** with old and new names side by side.
- **Keep the id.** With ids in saves, a rename is just a display change.
- **Search for the old name everywhere.** Quest text, dialogue, lore lines and codex entries reference names. A rename that misses one leaves a broken reference ([[Quest Writing and Hooks]]).
- **Update the localization table**, or the old name will keep appearing in other languages. A source text change without a translation update is a common source of mixed-language UI ([[Localization Pipeline]]).

---

## 12. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Names that do not signal tier | Players misjudge rarity in trades | Name shape per tier band |
| Near-duplicate names | Trade disputes, wrong-item support tickets | Edit distance check, different first syllables |
| Saves keyed by display name | Renames need migrations | Ids in saves; names from config |
| Content names colliding with system instance names | A system silently breaks after content is added | Reserved-names list in the validator |
| Theme names that hide the effect | Players do not know what a button does | Function first; theme only when it reads instantly |
| Brand, celebrity or sacred names | Moderation or takedown | Invented names; check meanings |
| Untested in chat | Item names hashed in trade chat | Type each name in a live server |
| Zone names without a short form | Players invent inconsistent abbreviations | Ship the short form |
| Running out of a naming theme | Awkward names in later zones | Plan the full sequence before launch |

## 13. Checklist

- [ ] Naming pattern chosen per category and tier band.
- [ ] Rarity tiers ordered and visible in UI; invented tier names tested on players.
- [ ] Zones have a name, a short form, a number if progression is linear, and matching art.
- [ ] Abilities named by function; themed names only when the theme reads instantly.
- [ ] Length budgets met in English and the longest supported language.
- [ ] Validator passes: ids, lengths, duplicates, near-duplicates, reserved names.
- [ ] Saves use ids; display names come from config or the localization table.
- [ ] No brands, real people, sacred or real-place names; invented names searched in other languages.
- [ ] Names typed in a live server's chat to check filtering.
- [ ] Renames announced, ids kept, all references and translations updated.

## See also

[[Narrative Start Here]] · [[Lore Delivery Without Walls of Text]] · [[Localization-Ready Writing]] · [[Quest Writing and Hooks]] · [[Rarity Ladders and Drop Pacing Math]] · [[Rarity Ladders and Drop Pacing Math]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Progression and Pacing Design]] · [[Zone and Biome Art Direction]] · [[Ability Kits Architecture]] · [[Data Schema Design and Migrations]] · [[Localization]] · [[Roblox Policies Ratings and Compliance]]

## Connected notes
<!-- auto-links:start -->
[[Writing Dialogue for Roblox Players]] · [[Dialogue System End to End]] · [[Genre Playbook - RNG and Collection Games]] · Balancing with Spreadsheets and Data · Procedural Loot and Item Generation · Notification and Toast Systems
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Story State Flags and Chapter Saves]] · [[Procedural Loot and Item Generation]] · [[Balancing with Spreadsheets and Data]] · [[Drop Tables Rarity and Pity Systems]] · [[Puzzle Dependency Charts and Hint Systems]] · [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]
<!-- related:end -->
