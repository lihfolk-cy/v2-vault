---
tags: [case-study, top-games, pet-care, roleplay, trading, live-ops, monetization, thumbnails, type/case-study, area/design, level/intermediate, area/monetization]
---
# Case Study - Adopt Me

<!-- tldr:start -->
> [!tldr] TL;DR
> - First need scripted to succeed within 20 seconds, with the required item handed over.
> - First random roll has only good outcomes.
> - Duplicates feed a fusion or upgrade ladder.
> - Progress is visible on the item itself (age, stage, glow).
> - Event currency is event-only; any multiplier pass is cheap and expires with the event.
> - Retired items or passes are announced before they leave.
>
> Cost: TL;DR ~140 tok · whole note ~5.2k tok. Read more: ## 1. Snapshot · ## 6. What to copy and what not to copy · ## Checklist
<!-- tldr:end -->

Adopt Me is the clearest example on Roblox of a game that turned a light roleplay toy (adopt a baby, decorate a house) into a collection and trading economy, then kept that economy alive for years with a strict event calendar. It is not a game you should clone. It is a game you should study for three things: how a care loop makes cute objects feel earned, how a trade layer turns a single player collection into a social status system, and how a studio ships a seasonal event almost every few weeks without breaking the economy that pays for everything.

Source labels used below: **Observed in the live game (October 2026)** means the public Roblox store page and the public Roblox web API (games, votes, game passes, media, thumbnails endpoints) read on 27 October 2026, with no login and no play session. **Public stats site** means third party trackers. **Studio statement** means the studio's own press release or store text. **Press** means named outlets. Roblox does not publish click-through rate (CTR) or revenue for other people's games, so anything about clicks below is reasoning from what is visible, not measured data.

---

## 1. Snapshot

| Field | Value | Source |
|---|---|---|
| Title on 27 Oct 2026 | "[🎃] Adopt Me!" | Observed in the live game (October 2026) |
| Studio | Uplift Games (group, verified badge) | Observed in the live game (October 2026) |
| Created | 14 July 2017 (store record); Wikipedia lists release as 13 July 2017 | Observed in the live game (October 2026); Press (Wikipedia, citing VentureBeat) |
| Genre tags | Roleplay & Avatar Sim, subgenre Pet Care | Observed in the live game (October 2026) |
| Total visits | 45,234,016,262 | Observed in the live game (27 October 2026) |
| Favourites | 29,812,835 | Observed in the live game (27 October 2026) |
| Likes / dislikes | 9,596,690 / 1,515,290 (about 86.4% positive) | Observed in the live game (27 October 2026) |
| Server size | 35 players | Observed in the live game (October 2026) |
| Players at the moment of reading | 207,396 (one snapshot, afternoon US time, during a Halloween event) | Observed in the live game (27 October 2026) |
| All-time peak | 1.92 million concurrent, April 2021, Ocean Egg update | Studio statement (Uplift Games press release, 11 May 2021); also cited by Press (GameSpot, April 2021, via Wikipedia) |
| Earlier spike | About 680,000 concurrent, April Fools 2020 "Pet Rock" update | Press (PC Gamer, 2 April 2020, via Wikipedia) |
| Monthly users | Rose from 30 million to 60+ million between January 2020 and January 2021 | Studio statement (press release, 11 May 2021) |
| Team size | About 40 staff, remote first, self funded (May 2021) | Studio statement (press release, 11 May 2021) |

Things we could not verify: a current typical daily concurrent figure from a reliable tracker (RoMonitor's page did not render for a text fetch, and RoWatcher lists a 1.9M peak dated April 2026 that conflicts with the studio's own April 2021 record, so I treat that tracker date as an error). Revenue: Wikipedia repeats a "US$60 million a year" figure from 2020 era coverage; the studio itself only said revenue grew over 400% year on year in 2020. Treat any dollar figure as unverified.

### The history that matters for design

The short version, from Press (Wikipedia, citing Vice, Gamepur, Entertainment Focus):

1. **2017 to 2018:** a family roleplay game about adopting children and owning a house. Moderate success.
2. **Summer 2019:** adoptable pets added. This is the change that made it a giant. Pets hatch from eggs, grow through six stages (newborn to full grown), and four full grown copies combine into a Neon pet, four Neons into a Mega Neon.
3. **2020:** trading becomes the centre of the community. In November 2020 the studio added trade licences for rare-and-above pets, trade history, and unfair-trade warnings, and raised trade slots from 4 to 9, later 18.
4. **April 2021:** the Ocean Egg update sets the then Roblox record of 1.92M concurrent players.
5. **2021 onward:** licensed partnerships (Scoob! in May 2020, Sing 2 in November 2021, Minions in June 2022), toys with Jazwares, and a rolling event calendar.

The lesson in the history: the roleplay shell came first and was fine; the collection plus trade layer is what scaled it. Adding a single strong meta system to an existing social sandbox can be worth more than a new game.

---

## 2. Click-through: icon, thumbnails and title

Roblox does not publish CTR for other creators' experiences. Everything here is reasoning from the visible store assets, which I downloaded from the public thumbnails API on 27 October 2026.

### What is on the store page right now (Observed in the live game, October 2026)

- **Icon:** a single close-up pet (a dark purple dragon-like Halloween pet with orange highlights) filling the frame, huge glossy eyes looking at the viewer, and the white "ADOPT ME!" wordmark across the bottom. One character, one face, one wordmark. No text tag, no number, no arrow.
- **Thumbnails:** 6 images plus 1 video in the gallery. The four I pulled all share a template: one or two oversized pets in the foreground, rendered in a soft, rounded, high-saturation style (far more polished than in-game Roblox lighting), with the same white "ADOPT ME!" wordmark bottom left. The first slot is Halloween themed (a vampire-caped sloth and a ghostly bear on a dark red background); the rest are evergreen (a sleeping golden dog with "Zzz" on a bright green field, a group shot of a girl avatar with a dog, cat and dragon in a garden, a dog with a group of pets).
- **Title:** "[🎃] Adopt Me!". The seasonal tag is an emoji only, in square brackets, in front of a stable name. No "UPDATE" word, no countdown.

### Why this probably works

1. **Faces sell to this audience.** Every thumbnail is built around a pet's face with big eyes looking at the viewer. On a discovery grid full of busy action art, a single cute face reads at icon size on a phone.
2. **Brand consistency beats novelty.** The wordmark sits in the same place on every image. Returning players recognise the tile instantly; the game has nearly 30M favourites, so recognition is worth more than curiosity.
3. **Seasonal swap of the first slot only.** Only the first thumbnail and the icon go seasonal. The rest stay evergreen, so a new player who swipes the gallery still learns what the game is (pets, house, family) rather than just "Halloween".
4. **Minimal title churn.** The bracket emoji is the only part that changes per event. That keeps search and word of mouth stable ("Adopt Me") while still signalling "something new" in the chart row.
5. **Render quality as a promise.** The thumbnails are clearly offline renders of the in-game pet models. That is allowed and common, but note the gap: the store art promises a softer, richer look than the live game. Players accept it because the pets themselves are the same models.

Compare this with the action-heavy approach in [[Case Study - Blox Fruits]] and the template-frame approach in [[Case Study - Brookhaven RP]]. The general rules live in [[Thumbnails Icons and Store Page]] and the cross-game comparison in [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

Unverified: whether Uplift uses Roblox's thumbnail A/B testing or sponsored ads. We found no public statement either way.

---

## 3. The first five minutes

Sources: the public fan wiki (Starter Egg page, read via a mirror) and beginner guides, plus the store description. Not played first-hand.

1. **Choose a role.** On first join the player picks Parent or Baby. This is a roleplay framing choice, not a class: babies have needs that parents look after, and the game pairs them loosely.
2. **Starter Egg.** Every new player can collect one Starter Egg at the Nursery, from an NPC dog in a suit. It can only hatch a Dog or a Cat, and it can only be claimed once (fan wiki). Per the wiki, the player must be in the Parent role to claim it.
3. **First task is always "Hungry".** The game hands the player a free sandwich and the first need is always hunger, so the first action is guaranteed to succeed (fan wiki).
4. **First reward lands fast.** Completing needs pays Bucks (the soft currency) and progresses the egg toward hatching. The core loop (need appears, walk to the right place, satisfy it, get paid, pet grows) is shown inside the first couple of minutes.
5. **House.** The player has a starter home to go back to, which seeds the decorating loop without asking for anything up front.

What is clever: the first need is scripted to be trivially satisfiable, and the first egg has only two outcomes, both common and both universally liked (dog or cat). There is no disappointment roll on minute one. RNG is introduced only after the player already owns and cares about a pet.

Unverified: the exact current tutorial screens and timings. Guides disagree on whether the house prompt or the egg comes first. If you copy the pattern, copy the shape (scripted first success, safe first roll) rather than the exact order.

See [[First-Time User Experience and Onboarding]] for how to build a guaranteed first success.

---

## 4. Core loop and retention

### Session loop

The minute to minute loop is a **care loop**:

1. A need icon appears over a pet or baby (hungry, thirsty, sleepy, dirty, bored, sick, wants to go somewhere).
2. The player walks or travels to the matching location or uses the matching furniture.
3. The need is satisfied: Bucks paid, pet gains age progress.
4. Repeat until the pet grows a stage.

On top of that sits the **collection loop**: spend Bucks (or Robux) on eggs from the Nursery, hatch, raise to full grown, and combine four full grown copies into a Neon, four Neons into a Mega Neon. That 4x and 16x copy requirement is what turns common pets into long term goals and gives every duplicate a purpose. It is the same idea as a fusion ladder in [[Rarity Ladders and Drop Pacing Math]].

The **trade loop** sits across all of it: rarity tiers (common, uncommon, rare, ultra-rare, legendary), Neon and Mega variants, event-only pets, and retired pets give every item a social value. Players log in to trade, show off, and check the value of what they own even when they have no care tasks left.

### Long-term goals

- Mega Neon versions of favourite pets (16 full grown copies each).
- Event and retired pets that never return in the same form.
- House building and decoration (an expression goal, not a power goal).
- Trade value and "collection status" with friends.

### Daily and timed systems

From guides (Press, weak sources; verify in game): a Task Board that refreshes daily with three quests paying small Bucks rewards and a chance at an egg for completing all three; a Daily Free Egg feature reported live from 14 November 2025; and login rewards. Eggs in the Nursery rotate, with one guide reporting an egg launched 28 February 2026 at 750 Bucks or 5 tasks. We could not confirm these numbers from the studio.

### Events and cadence

Observed in the live game (October 2026): the store description lists the current Halloween content in a short emoji bullet list ("Where Bear? Returns", a pet "finally transforms", "New Sticker Pack with Halloween pets") and a "1.25x Candy Multiplier" pass at 50 Robux that "unlocks 25% bonus Candy for the entire Halloween 2026 event". Halloween at Adopt Me runs in weekly parts, each adding a minigame or pet (guides report weekly parts through about 1 November).

The pattern: one event currency (Candy), weekly drops inside the event, a returning minigame players already know, and a small cheap pass that multiplies the event currency. Wikipedia notes (citing Distractify, October 2020) that major updates have roughly tripled player numbers and caused platform-wide disruption. Big events are the growth engine, not a side activity.

### Social hooks

- Trading (the strongest one, and the riskiest).
- Visiting other players' houses.
- The Parent and Baby roles, which pair strangers or friends into small roleplays.
- The "press NOTIFY" line in the description, which asks players to subscribe to update notifications.

See [[Retention and Return Hooks]], [[Live Ops Events and Updates]] and [[Update Cadence and Hype Cycles]].

---

## 5. Monetization (public store page)

Observed in the live game (27 October 2026), from the public game passes endpoint:

| Pass | Price | On sale |
|---|---|---|
| 1.25x Candy Multiplier (Halloween 2026 only) | 50 | Yes |
| Premium Plots | 285 | Yes |
| +1 Pet Pen Slot | 295 | Yes |
| VIP | 480 | Yes |
| Cozy Home Lure | 765 | Yes |
| Millionaire Pack | 795 | Yes |
| 18 more passes (homes such as Modern Mansion, Celebrity Mansion, Mermaid Mansion, School and Hospital Homes; vehicles such as Supercar Pack, Royal Carriages, Heart Hoverboard; pets such as Pet Griffin, Pet Horse; Starter Pack, Premium Faces, DJ, Glider, Fossil Isle Returns Bundle, Candy Cannon, stands) | not listed | No (off sale) |

So only 6 of 24 passes are currently for sale. The others have been retired, which turns them into status items for players who bought them while they were available. That is a deliberate scarcity lever: passes become "limited" without being Roblox Limited items.

Beyond passes, the game sells Robux-only pets and eggs as developer products (Press: Entertainment Focus, March 2021, says some pets can only be bought with Robux). We could not read developer product prices from a public endpoint; one undated guide lists older Ocean and Royal egg prices in Robux, and another reports a bundle of four event eggs for 99 Robux in 2026. Treat those as unverified.

Price shape: cheap event pass (50) to get almost everyone over the "first purchase" line during an event, mid passes in the 285 to 480 band for permanent quality of life and status (VIP, plots, pet pen slot), and 765 to 795 for big bundles. Compare with [[Robux Price Points and Offer Design]].

Risk notes from Press: rare pets have sold for real money on off-platform sites (Wikipedia, citing 2022 and 2024 coverage), "trust trade" scams are common, and a widely reported case in 2020 involved a child running up an A$8,000 bill. Any game that copies the trade-and-rarity model inherits these problems. See [[Ethical Design and Player Trust]].

---

## 6. What to copy and what not to copy

### Copy

1. **A scripted first success.** Make the first task impossible to fail and pay it immediately. Hand the player the item they need (the sandwich). Build: a first-session state flag that forces the first need to be one the player can satisfy within 20 seconds of spawn. Teach: [[First-Time User Experience and Onboarding]].
2. **A safe first roll.** If your game has RNG, the first roll should have only good outcomes. A two-outcome starter egg removes the "I got the bad one" exit point. Teach: [[RNG Drops and Luck Systems]].
3. **Duplicates that matter.** The 4 to Neon, 4 to Mega fusion ladder means a common pet hatched for the 30th time is still progress. Any collection game should give duplicates a sink: fuse, upgrade, or trade. Teach: [[Rarity Ladders and Drop Pacing Math]], [[Pet Hatching and Following End to End]].
4. **Care loop as a progress clock.** Needs are a cheap, readable way to pace growth: each need is a small walk and a small reward, and the pet's age is the visible progress bar. It works for any "raise something" fantasy (plants, creatures, buildings). Teach: [[Core Loops and Session Design]], [[Progression and Pacing Design]].
5. **Event currency plus a tiny multiplier pass.** One event-only currency, weekly drops inside the event, and a 50 Robux multiplier pass that lasts for that event only. Cheap, honest, and time boxed. Teach: [[Live Ops Events and Updates]], [[Game Passes]].
6. **Retire passes on purpose.** Taking passes off sale creates collectible status without random paid boxes. Announce it in advance so it feels fair.
7. **One stable brand, one seasonal slot.** Keep the wordmark and the name fixed; swap only the icon and the first thumbnail per event; put the event emoji in brackets in the title. Teach: [[Thumbnails Icons and Store Page]].
8. **Anti-scam UI from day one if you have trading.** Trade licences (a short quiz before trading valuable items), trade history, and unfair-trade warnings were all added after the fact in 2020. Build them before launch. Teach: [[Trading Systems Without Duplication]].

### Do not copy

1. **Trading without a duplication-proof backend.** Adopt Me's economy is the product; one dupe exploit would wreck it. If you cannot do atomic, session-locked trades, ship gifting or no trading at all. Teach: [[Trading Systems Without Duplication]], [[Session Locking and Profile Libraries]].
2. **Real-money value of virtual pets.** Once items are worth real dollars off-platform, you inherit scams, account theft and support load. Limit what can be traded, add trade cooldowns for new accounts, and do not sell randomised items for Robux without odds disclosure. Teach: [[Paid Random Items and Odds Disclosure in Practice]], [[Roblox Policies Ratings and Compliance]].
3. **Event-only power.** Adopt Me's event items are cosmetic and collectible. If your game has combat, event-only stats create a pay-or-miss-out problem that cosmetic games avoid.
4. **A thumbnail that overpromises the art style.** It works here because the pets are the same models. If your in-game look is much plainer than your render, players notice and the first session feels like a downgrade.
5. **Massive events without load planning.** Updates that triple players can take down servers and your data layer at the same moment. Test DataStore budgets and joins under event load. Teach: [[Saving Correctly - Autosave and BindToClose]], [[Release Process and Rollbacks]].
6. **Copying the genre at a small scale.** A pet-care game with no trade economy and no event calendar is a much weaker product. The value is in the whole machine (care, collect, fuse, trade, event), and that machine takes a team. Use [[Planning and Scoping a Roblox Game]] before you commit.

### A buildable mini version

If you want the lesson without the risk: one pet type family (5 rarity tiers), a care loop with 4 needs, a fusion ladder (3 copies into an upgraded variant), a daily task board with 3 quests, and a single seasonal event with its own currency. No trading at launch; add gifting between friends first, then trading once your backend is proven. That is a 2 to 3 month scope for a small team and teaches every system above.

---

## Checklist

- [ ] First need scripted to succeed within 20 seconds, with the required item handed over.
- [ ] First random roll has only good outcomes.
- [ ] Duplicates feed a fusion or upgrade ladder.
- [ ] Progress is visible on the item itself (age, stage, glow).
- [ ] Event currency is event-only; any multiplier pass is cheap and expires with the event.
- [ ] Retired items or passes are announced before they leave.
- [ ] Icon and first thumbnail are seasonal; wordmark and name are fixed.
- [ ] Title carries a short bracket tag for events, nothing more.
- [ ] Trading is atomic, logged, and protected by licences or cooldowns, or it does not ship.
- [ ] Load test before big events.

## Sources

- Observed in the live game (October 2026): Roblox public web API (games, votes, game passes, media and thumbnails endpoints) for the experience, read 27 October 2026, no login.
- Studio statement: Uplift Games press release "Developers behind record-breaking Roblox game Adopt Me launch new studio Uplift Games", 11 May 2021 (Mynewsdesk).
- Press: Wikipedia "Adopt Me!" (read October 2026), citing PC Gamer (2 April 2020), GameSpot (April 2021), VentureBeat (11 May 2021), Vice (17 August 2020), Gamepur (23 July 2020), Entertainment Focus (2020 and 2021), Distractify (October 2020).
- Public fan wiki (Starter Egg page via mirror) and beginner guides for onboarding and daily systems: weak sources, flagged in the text.
- Public stats site: RoWatcher (peak date conflicts with the studio record; not relied on).

## Connected notes
<!-- auto-links:start -->
[[Case Study - Dress to Impress]] · [[Case Study - Pet Simulator 99]] · [[Case Study - Grow a Garden]] · [[Top Games Case Studies Start Here]] · [[Genre Playbook - Simulators]] · Genre Playbook - Roleplay and Social Hangouts
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Steal a Brainrot]] · [[Case Study - Doors]] · [[Case Study - Fisch]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Murder Mystery 2]] · [[Case Study - Jailbreak]] · [[Case Study - Tower Defense Simulator]] · [[Case Study - Dead Rails]]
<!-- related:end -->
