---
tags: [game-design, genre, rng, rolling, luck, odds, rarity, collection, pity, type/guide, area/design, level/intermediate]
---
# Genre Playbook - RNG and Collection Games

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hand-typed "1 in N" that do not match the algorithm -> Derive displayed odds from the rolling code
> - Avoid: Luck semantics undefined -> Document which tiers luck affects and how
> - Avoid: No cap on rollable tier -> Progress-scaled caps
> - Rolling algorithm chosen; real probabilities computed from it.
> - Luck defined, stacked, capped and tested at maximum.
> - Expected minutes per tier and p99 checked by simulation.
>
> Cost: TL;DR ~150 tok · whole note ~5.1k tok. Read more: ## 3. Odds maths: two implementations, two sets of real odds · ## 4. Code: a roll table that can also report its true odds · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

In an **RNG game** the core verb is a roll: press a button, watch a reveal, get an item whose rarity is shown as "1 in N". Luck multipliers, auto-rolling, rarity tiers with colours and banners, a collection index and server-wide announcements turn that one verb into a long loop. Collection games (pets, cards, auras, weapons) share the structure with different presentation. This playbook covers why the genre works, the anatomy of a roll, the odds maths (including two common implementations that give **different** real probabilities for the same "1 in N" labels), luck, pity, presentation, duplicates, and the disclosure rules Roblox applies to anything random that money touches. Most production numbers come from one RNG sword game built around rolling weapons.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. Why RNG games work, and the responsibility that comes with it

| Pull | Why |
|---|---|
| Anticipation | Every roll is a tiny suspense moment |
| Big numbers | "1 in 5 billion" is a story by itself |
| Collection | Tiers and an index to complete |
| Status | Rare items displayed above heads and announced to the server |
| Clips | A rare pull with a big reveal is the genre's best advertisement |
| Simple input | One button, auto-roll; perfect for phones |

The same mechanics that make RNG compelling are borrowed from gambling: variable rewards, near-misses, celebrations for rare outcomes. On a platform full of children that creates obligations: honest odds, no paid gambling loops, and compliance with Roblox's paid-random-item rules (section 9). See [[Ethical Design and Player Trust]].

---

## 2. Anatomy of a roll

| Part | Reference project example |
|---|---|
| Roll button | Giant central button plus an AUTO toggle |
| Reveal | A reel of item cards that slows and lands; 3.2 s base spin (raised from 2.4 s because rolls felt too fast), auto-roll 2.56 s; speed upgrades and a Fast Roll pass (x0.5) shorten it, with a floor of 0.38x |
| Manual versus auto presentation | Manual roll: full roll screen (world dimmed, HUD hidden). Auto roll: a small reel over the player's head |
| Rarity tiers | Nine: Common, Uncommon, Rare, Epic, Legendary, Mythic, Celestial, Divine, Eternal |
| Odds label | "1 in N" on every card |
| Tier banners | "ASCENDED / GODLY / TRANSCENDENT PULL!"; a world burst for Rare and above |
| Golden roll | 20% chance per press of a golden roll with 2x luck, shown by the reel landing on a golden tile first |
| Luck readout | Standing luck shown top-left ("1.00x") |
| Progress cap | The best tier you can roll is capped by the furthest zone reached (Legendary in region 1, Mythic in region 2...); Robux purchases are never capped |
| Broadcast | Rare pulls announced to the server |
| Equip and display | The held item's name shown above the player, animated by rarity |

### The reveal is the product
Players roll thousands of times. The reveal must be:
- **fast enough** not to annoy (auto-roll compresses it);
- **readable** (colour and banner per tier before the name);
- **escalating** (higher tiers get longer, louder reveals, so a rare pull is unmistakable);
- **skippable** for low tiers in auto mode.

The reveal plays the server's result; it never decides anything. See [[UI and GUI Animation]] and [[Game Feel and Juice]].

---

## 3. Odds maths: two implementations, two sets of real odds

"1 in N" labels can be implemented in more than one way, and the **real** probability of each item depends on which.

### Implementation A: normalised weighted table
Each item gets weight `w = 1 / N`. Roll a number in `[0, total)` and pick the item whose cumulative range contains it.

```
P(item i) = (1 / N_i) / sum over j of (1 / N_j)
```

If the weights of all items sum to exactly 1 (the "1 in N" values were derived from real shares), the label is exact. If they sum to more or less than 1 (common when designers type odds by hand), every real probability is scaled by the same factor and the labels are wrong.

### Implementation B: rarest-first independent checks
Go from the rarest item down; for each, succeed with chance `1 / N`; the first success wins; if nothing succeeds, give the fallback Common.

```
P(item i) = (1 / N_i) * product over rarer items j of (1 - 1 / N_j)
```

For rare items the product is almost exactly 1, so the label is very close to the truth. For common items it is not: an item labelled "1 in 2" checked after many others can come out well below 50%, and the fallback item has no meaningful label at all.

| Item | Label | A: weights sum to 1.25 | B: rarest-first |
|---|---|---|---|
| Rare | 1 in 4 | 20% | 25% |
| Uncommon | 1 in 2 | 40% | 50% x 0.75 = 37.5% |
| Common | 1 in 2 | 40% | fallback: 37.5% |

Both are legitimate designs. What is **not** acceptable when money is involved is showing labels that differ from the real probabilities. Compute the real percentages from the actual algorithm and show those (section 9).

### Luck
"2x luck" also has several meanings:

| Meaning | Implementation | Effect |
|---|---|---|
| Divide N for affected items | A: multiply their weights by luck, renormalise. B: check with `min(1, luck / N)` | Rare items become luck-times more likely (approximately); commons absorb the difference |
| Roll twice, keep the best | Two independent rolls | For rare items about 2x; different shape for common ones |
| Shift tiers | Bump the result up a tier with some chance | Easy to explain, coarse |

Decide which tiers luck affects. In the reference project's ladder, luck from many sources stacked into one standing value (a pass, friends in the server, potions, rare weather, a server-wide product, a permanent bundle bonus, a golden roll's 2x for one press). With implementation B and very high luck, `luck / N` reaches 1 for the "rarest" items that remain in range, and the roll always lands at the cap: check what your maximum stacked luck does at every tier.

### Expected rolls and the long tail
From [[Balancing with Spreadsheets and Data]]: at "1 in N", about 63% of players have one after N rolls, a 99% chance needs about 4.6 N rolls. Combine with rolls per minute to get **minutes** to each tier:

```
minutes to first T-or-better = 1 / (P(T or better) * rolls per minute)    (expected)
```

At 3.2 s per manual roll (about 19 rolls a minute) and no luck, a 1 in 2,000 Epic takes about 105 minutes on average, and the unlucky 1% wait about 8 hours. That is why the genre leans on auto-roll, luck, and progress-scaled caps.

---

## 4. Code: a roll table that can also report its true odds

```lua
--!strict
-- ReplicatedStorage/RollTable (ModuleScript)
-- Implementation A (normalised weights). The same function that rolls also reports
-- exact percentages for disclosure, so the display can never drift from the logic.
export type Entry = { id: string, tier: number, oneIn: number }

local RollTable = {}

-- Build cumulative weights. Luck multiplies weights of tiers >= luckFromTier.
-- capTier: tiers above it are excluded (progress cap); pass math.huge for none.
local function weights(entries: { Entry }, luck: number, luckFromTier: number, capTier: number): ({ number }, number)
	local w: { number } = table.create(#entries, 0)
	local total = 0
	for i, e in entries do
		if e.tier <= capTier then
			local x = 1 / e.oneIn
			if e.tier >= luckFromTier then
				x *= luck
			end
			w[i] = x
			total += x
		end
	end
	return w, total
end

-- Server only: roll with a server-side Random.
function RollTable.roll(rng: Random, entries: { Entry }, luck: number, luckFromTier: number, capTier: number): Entry
	local w, total = weights(entries, luck, luckFromTier, capTier)
	local x = rng:NextNumber() * total
	for i, e in entries do
		x -= w[i]
		if x < 0 then
			return e
		end
	end
	-- Floating-point edge: return the last eligible entry.
	for i = #entries, 1, -1 do
		if w[i] > 0 then return entries[i] end
	end
	return entries[1]
end

-- Exact probabilities (0..1) for the CURRENT luck and cap: use these for the odds panel.
function RollTable.probabilities(entries: { Entry }, luck: number, luckFromTier: number, capTier: number): { [string]: number }
	local w, total = weights(entries, luck, luckFromTier, capTier)
	local out: { [string]: number } = {}
	for i, e in entries do
		out[e.id] = if total > 0 then w[i] / total else 0
	end
	return out
end

-- Format for display: percentage, rounded to 4 significant digits after the first non-zero
-- digit, plus a "1 in N" hint. Show the rounding disclaimer near the list.
function RollTable.formatPercent(p: number): string
	if p <= 0 then return "0%" end
	local pct = p * 100
	local digits = math.max(0, 3 - math.floor(math.log10(pct))) -- keeps 4 significant figures
	return string.format("%." .. digits .. "f%% (1 in %s)", pct, tostring(math.floor(1 / p + 0.5)))
end

return RollTable
```

Notes:
- `probabilities` uses the **same** weights as `roll`, so disclosure matches reality, including luck and caps. Recompute it whenever luck changes (paid luck must update the displayed odds while active; section 9).
- Roll on the **server** with a `Random` object; never accept a result or a seed from the client. Rate-limit the roll remote even if the client animation paces rolls. See [[Server Authority and Validation]] and [[Rate Limiting and Abuse Prevention]].
- For implementation B, write the matching `probabilities` function from its formula; do not reuse labels.

---

## 5. Pity and bad-luck protection

The long tail (1% of players needing 4.6x the expected rolls) creates the angriest players. Pity systems cap it.

| System | How | Effect on real odds |
|---|---|---|
| Hard pity | Guarantee tier T or better after K rolls without one | Bounds the worst case at K |
| Soft pity | Luck for tier T rises after a threshold, for example +10% per roll past K/2 | Smooths the tail |
| Spark / tokens | Each roll gives a token; spend tokens on a chosen item | Converts bad luck into progress |
| Duplicate protection | Remove owned unique items from the pool | Common in card sets |

Pity changes the real probabilities, so if the item is a paid random item, the disclosed odds must reflect it (Docs list pity systems as probability modifiers). A simple hard pity counter on the server:

```lua
--!strict
-- Pity: guarantee tier >= PITY_TIER within PITY_ROLLS rolls. Stored per player in the profile.
local PITY_TIER = 4    -- Epic or better
local PITY_ROLLS = 500

local function rollWithPity(profile: { pity: number }, doRoll: () -> { tier: number }, forceTier: () -> { tier: number })
	profile.pity += 1
	local result = if profile.pity >= PITY_ROLLS then forceTier() else doRoll()
	if result.tier >= PITY_TIER then
		profile.pity = 0
	end
	return result
end
```

Show the pity counter to players ("Epic guaranteed in 137 rolls"). A visible pity turns frustration into anticipation.

---

## 6. Rarity presentation

- **One colour per tier**, used everywhere: card borders, banners, item names, beams on drops. Players learn the ladder from colour alone.
- **Escalating effects** per tier: the reference project scaled reveal length, banners, world bursts and title animations by tier.
- **Rarer must look better.** The reference project re-tiered its top items with a rule that every Legendary or higher item must be animated, and ranked items within tiers by a mix of measured presentation quality and odds. A 1 in 300M item that looks plainer than a 1 in 5M one undermines the whole ladder.
- **Stats follow odds** within a tier, from a fitted curve (see [[Balancing with Spreadsheets and Data]]).
- **Show the next tier's odds** before the player reaches it, so the ladder above them is visible.

### Near-miss reels
Reels that slow down past a rare item and stop one card short are a classic slot-machine technique. The reference project's reel had a near-miss effect capped by the player's progress tier. Two honest rules:
- The reel's content must be drawn from the **real** table (or clearly decorative) and must never imply the player almost won something they could not have won (for example items above their cap).
- Do not use near-miss presentation on any roll bought with Robux. A near-miss sells the next purchase; with real money that crosses from excitement into manipulation. See [[Ethical Design and Player Trust]].

---

## 7. Collection, duplicates and crafting

Rolling produces thousands of items. A collection layer gives them meaning:

| System | Purpose |
|---|---|
| Index | Every item discovered, by tier; completion rewards per tier or set |
| Favourites and filters | Phones need search, filters by tier, "hide duplicates", sort by rarest or newest (the reference project's backpack had all of these) |
| Salvage | Turn unwanted items into materials |
| Forge / upgrade | Spend materials to raise an item's level |
| Fusion | Combine duplicates into stars or the next tier |
| Auto-salvage / auto-delete | Player-controlled rules by tier |

The reference project's answer to "what should players do with the swords they don't use" was fusion stars, tier-up crafting and auto-salvage, and its tutorial taught salvage-then-forge in the first minute. Duplicates are a resource only if the game says so clearly.

---

## 8. Progress caps and the RNG ladder

A pure RNG game with no cap lets a lucky new player roll the best item in the game on day one, which flattens the long loop and makes everyone else's progress feel pointless. Caps tie the roll to progression:
- **Zone or level cap** on the rollable tier (the reference project: furthest zone reached sets the cap).
- **Luck from progression** (upgrades, rebirths) so long-term players roll better.
- **Tier-specific rolls** unlocked by progress (a "Mythic roll" in region 2).

Be careful how caps interact with purchases: the reference project never capped rolls bought with Robux. That keeps purchases simple, but it also means a payer can skip the ladder; make sure your disclosure shows the odds the purchased roll actually uses.

---

## 9. Disclosure and policy (as of October 2026)

Roblox's paid random items policy (Docs, "Paid random items") covers random items bought **directly or indirectly** with Robux, including with in-game currency that can be bought with Robux. It explicitly includes capsules (wheel spins, eggs, chests), enhancement items (random-duration potions, chance-based upgrades), combination items (consuming items for a chance at better) and **probability modifiers** (luck boosts, pity systems, enhanced drops, rate-up items).

Requirements in summary:
- Show **all possible outcomes and their actual numerical odds**, as **percentages** that total exactly 100%. For long decimals, round to four or more digits past the first non-zero digit and show the docs' disclaimer that rounded values may not total 100%.
- For indirect purchases (keys, tokens, tickets, Robux-bought currency), disclose before the currency is spent.
- If outcomes do not fit, use a clearly labelled "Info" or "Details" button visible before purchase; a bare (i) icon is not enough.
- Items that improve odds must explain the improvement numerically before purchase, and the displayed odds must **update while the boost is active**.
- If a player can only get one copy of an outcome, update their remaining odds.
- Rewards from actions that involve no Robux or Robux-bought currency do not need disclosure (showing odds anyway is good practice).

`PolicyService:GetPolicyInfoForPlayerAsync(player)` returns, among other fields:
- `ArePaidRandomItemsRestricted`: when true, the player must not be able to use paid random items; the docs list acceptable treatments (an earnable free path, a predetermined disclosed order, direct purchase at [[expected value]], hiding the item, blocking with a message, or keeping the player out of those areas).
- `IsPaidItemTradingAllowed`: when false, the player must not trade paid items or outcomes of paid random items.

A "1 in N" label alone is not the required format for paid items: show the percentage (you can show "1 in N" next to it). For an RNG game whose shop sells luck passes, server luck boosts, jackpot rolls or bundles, this affects **the main roll button** whenever a paid luck effect is active. Plan the odds panel as a core screen, not an afterthought. Policy details are in [[Roblox Policies Ratings and Compliance]].

```lua
--!strict
-- Server: check paid-random-item eligibility once per player (fail closed on error).
local PolicyService = game:GetService("PolicyService")

local function paidRandomAllowed(player: Player): boolean
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or type(info) ~= "table" then
		return false -- unknown: treat as restricted
	end
	return info.ArePaidRandomItemsRestricted ~= true
end
```

---

## 10. Monetisation patterns

Reference project examples (Robux prices as configured in its notes):

| Product | Type | Price | Note |
|---|---|---|---|
| Fast Roll | Pass | 299 | Speed, not odds |
| Double Roll | Pass | 599 | Two results per roll |
| Lucky Rolls | Pass | 75 | Probability modifier: odds disclosure |
| VIP | Pass | 399 | Includes x1.1 luck: probability modifier |
| Server Luck Boost | Product | 99 | Benefits everyone; odds update for all |
| Jackpot Roll | Product | 499 | A paid random item |
| Bundle | Product | 1,499 | A top item, permanent 2x luck, gems |
| Exclusive weapons | Product | 999 | Never rollable; weekly rotation; direct purchase |

Direct-purchase exclusives (no randomness) are the cleanest monetisation in an RNG game. Speed passes are second. Luck products are allowed with disclosure, but they put the money directly on the gamble, so keep them modest and transparent. See [[Pricing and Store Design]] and [[Game Passes]].

---

## 11. Common mistakes

| Mistake | Better |
|---|---|
| Hand-typed "1 in N" that do not match the algorithm | Derive displayed odds from the rolling code |
| Luck semantics undefined | Document which tiers luck affects and how |
| No cap on rollable tier | Progress-scaled caps |
| Uncapped stacked luck | Check maximum luck against every tier |
| Paid odds shown only as "1 in N" | Percentages totalling 100%, updated while boosts are active |
| Near-miss on paid rolls | No near-miss presentation where money is involved |
| Inventory flooding | Salvage, fusion, auto-delete, filters |
| Rare items that look ordinary | Presentation scales with rarity |
| Client-side rolls or seeds | Server `Random`, rate-limited remote |

## 12. Checklist

- [ ] Rolling algorithm chosen; real probabilities computed from it.
- [ ] Luck defined, stacked, capped and tested at maximum.
- [ ] Expected minutes per tier and p99 checked by simulation.
- [ ] Pity or token system for the long tail, shown to players.
- [ ] Reveal escalates with tier and is skippable in auto mode.
- [ ] Duplicates have uses; inventory usable on phones.
- [ ] Progress cap on rollable tier; purchases' odds disclosed.
- [ ] Paid random items: percentage odds, Info button, boost-aware odds, policy-restricted players handled.

## See also
- [[RNG Drops and Luck Systems]], [[Balancing with Spreadsheets and Data]], [[Progression and Pacing Design]]
- [[Genre Playbook - Simulators]], [[Genre Playbook - Combat and RPG]], [[Tools and Inventory Systems]]
- [[Developer Products and ProcessReceipt]], [[Pricing and Store Design]], [[Roblox Policies Ratings and Compliance]]
- [[Ethical Design and Player Trust]], [[UI and GUI Animation]], [[Game Feel and Juice]]

## Connected notes
<!-- auto-links:start -->
[[Paid Random Items and Odds Disclosure in Practice]] · [[Rarity Ladders and Drop Pacing Math]] · Pity Timer · Drop Tables Rarity and Pity Systems · Expected Value · Reward Moments and Celebrations
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Pity Timer]] · [[Simulator and RNG Genre Teardown]] · [[Drop Tables Rarity and Pity Systems]] · [[Retention and Return Hooks]] · [[Social Design and Multiplayer Play]] · [[Genre Playbook - Tower Defense]] · [[Core Loops and Session Design]] · [[Genre Playbook - Tycoons]] · [[First-Time User Experience and Onboarding]] · [[Genre Playbook - Zombie and Wave Survival Co-op]]
<!-- related:end -->
