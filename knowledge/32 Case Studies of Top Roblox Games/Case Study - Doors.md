---
tags: [case-study, top-games, horror, roguelite, co-op, lobby, matchmaking, live-ops, thumbnails, monetization]
---

# Case Study - Doors

<!-- tldr:start -->
> [!tldr] TL;DR
> - Every death shows a one-line cause and counter.
> - Lobby place with parties, separate small run servers.
> - Runs have fixed anchors and randomised filler.
> - Each threat has one tell and one counter, testable on a ten-year-old.
> - Store has at most a handful of products, each tied to one moment.
> - Free revives exist and are easy to get.
>
> Cost: TL;DR ~130 tok · whole note ~4.0k tok. Read more: ## Snapshot · ## Click-through: thumbnail, icon and title · ## Checklist
<!-- tldr:end -->

Doors is a first-person co-op horror run: you and a few friends ride an elevator into a hotel, open numbered doors one at a time, and try to reach door 100 while entities hunt you. It is the clearest example on Roblox of a small team building a premium-feeling horror game with short, replayable runs, a tiny monetization surface and a brand strong enough that Roblox picks it for platform events. This note is a teardown for developers: what is visible from outside, what it teaches, and which parts are dangerous to copy.

Source labels used below: **Public stats** (Roblox's public games API or a stats site, with the date checked), **Observed on the store page** (the public experience page, thumbnails and pass list, October 2026; nothing was played or logged into), **Press** (news or guide sites, with their date), **Community wiki** (fan wikis, lower confidence).

## Snapshot

| Field | Value | Source |
|---|---|---|
| Genre | Survival horror, escape; Roblox lists it as "Survival / Escape" | Public stats, Roblox games API, checked 27 October 2026 |
| Creator | LSPLASH (group, verified badge) | Public stats, Roblox games API, 27 October 2026 |
| Developers named in press | LSPLASH and Red; based on the earlier Roblox game *Rooms* | Press, Wikipedia "List of Roblox games" (the Doors article redirects there), read October 2026 |
| Place created | 14 March 2021 | Public stats, Roblox games API |
| Public release | 10 August 2022, one floor ("The Hotel") | Press, Wikipedia |
| Visits | 7,963,279,204 | Public stats, Roblox games API, 27 October 2026 |
| Favourites | 8,335,328 | Public stats, Roblox games API, 27 October 2026 |
| Votes | 4,752,179 up, 355,981 down (about 93% positive) | Public stats, Roblox votes API, 27 October 2026 |
| Playing at check time | 44,980 | Public stats, Roblox games API, 27 October 2026 (one moment, during a platform event) |
| Typical concurrency | 7-day average about 59,100, 14-day average about 48,600 | Public stats site, RoTrends, read October 2026 |
| Peak concurrency | 272.7K (no date shown) on RoTrends; 274K labelled October 2026 on RoWatcher | Public stats sites, read October 2026 |
| Server size (lobby place) | 50 | Public stats, Roblox games API |

Two cautions about the numbers. First, tracker "all-time peaks" only cover the period that tracker has been recording, so a 2026 peak on a site that started tracking in 2024 says nothing about 2022. The peak during the original 2022 launch is not verified here. Second, the October 2026 figures are inflated by The Hollow, a Roblox platform Halloween event that started 22 or 23 October 2026 (time zone dependent) and featured Doors among nine horror games (Press, Katadata, 21 October 2026). Treat 45K to 60K as the event-week level, not a baseline.

Major content dates, all from Press (Wikipedia, citing update coverage): Hotel+ update 28 or 29 January 2023 (sources differ by a day, probably time zone); Modifiers 26 August 2023; Floor 2 "The Mines" 30 August 2024, confirmed by the developers on the game's official X account; "The Content Update" 19 or 20 December 2024, which added an admin panel and stream integration called Chat Control. A Roonby article from 3 September 2024 reported that The Mines, about a year in development, was not well received by many players. Two years between the Hotel launch (August 2022) and Floor 2 (August 2024) is the most important number in this note, and it comes back in the lessons.

## Click-through: thumbnail, icon and title

Roblox does not publish click-through rate for other people's games, so everything here is reasoned from what is visible. The platform does tell you what it measures for your own game: thumbnail personalization shows each of 2 to 5 active thumbnails to random users, measures qualified play-through rate (qualified plays divided by impressions) and shifts impressions to the winner per user group; Roblox reported an average +8.5% QPTR in testing, with some games up 50% (Roblox docs, "Experience thumbnails", as of October 2026).

**Title.** At check time the title was `DOORS 🍬🍭`: the brand in capitals plus two candy emoji for the Halloween event. RoWatcher's archived page names show it previously ran as `DOORS [ rush mode ]` while a mode was being promoted (Public stats site, RoWatcher, read October 2026). The pattern is restrained compared with simulators: no "[UPDATE]" spam, no "x2", one seasonal emoji pair, and the word DOORS always first. A horror brand has to look confident; a title that shouts "FREE" would cheapen it.

**Icon** (Observed on the store page, October 2026). A square render of a top-hatted entity holding a knife-like prop in front of a door marked "CANDY VAULT", a static-filled TV and carved pumpkins, the DOORS wordmark in red across the bottom, and The Hollow event logo at the top. The wordmark replaces the two Os with door-shaped glyphs, so the logo is recognisable even at 50 pixels.

**Thumbnails** (Observed, three returned by the public thumbnails API on 27 October 2026; personalization may show you a different set):

1. Event art: the same top-hatted entity in a purple-lit doorway, DOORS wordmark left, The Hollow logo bottom right, all inside the red, dripping frame Roblox's event uses across participating games.
2. Mines art: a dark green corridor, an exit sign, a fire alarm, a rocky entity with one glowing eye peeking round a doorframe, the wordmark in mossy green at bottom left.
3. A tonal change: a pink-carpeted office corridor full of silhouettes with sticky-note faces and a monitor-headed figure; wordmark bottom left in white.

What earns the click:

- **One creature, one door, one light source.** Every thumbnail frames a monster in or next to a doorway. The door is the brand promise. The single bright point (an eye, a monocle, a lamp) gives the eye somewhere to land on a small card.
- **Colour per floor.** Purple for the event, green for the Mines, pink and grey for the newer content. A returning player can tell which content a thumbnail advertises before reading anything.
- **Wordmark always on.** The logo sits away from the bottom edge on the event card, which matters because Roblox overlays metadata at the bottom (Roblox docs advise against essential text there). On the other two it sits bottom left, a small risk.
- **Platform event framing.** During The Hollow, Doors wore the shared red frame. That frame was also visible on several non-horror games' art the same week, so its value is "this game is part of the event" rather than horror specifically. See [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

Chart placement and paid ads: no reliable public record of Doors' sponsored ad spend was found. Its platform event inclusion (The Hunt and The Hollow) is public and is a form of placement money cannot buy directly.

## First five minutes

What a new player sees, reconstructed from the store description and guide coverage (not played for this note):

1. **Lobby.** The 50-player lobby place has elevators. You join an elevator with friends or strangers, and the run starts in a separate place. Private servers allow up to 12 people in one elevator (Community wiki, via search summary, October 2026); the public elevator cap was not verified. The store description recommends entering "without a guide" and to "use each death as a lesson" (Observed on the store page, October 2026).
2. **Pre-run shop.** Before the run you spend Knobs, the soft currency, on tools such as a flashlight, lockpick, lighter and vitamins (Press, Dexerto codes guide; prices vary by version). This is the first decision, and it is made in seconds.
3. **First rooms.** You open door after door. Within the first minute or two you meet the cheap scares (lights flicker, something knocks) and within a few minutes a lethal entity: Rush flickers the lights before it arrives, and the answer is to hide in a closet (Press, GameWith and Pocket Tactics guides).
4. **First death.** Most new players die early. The death screen is the tutorial: the Guiding Light, a friendly presence, explains what killed you and how to survive it next time, and also highlights the path during Seek chases and hidden keys when players are stuck (Press, ProGameGuides walkthrough).
5. **Back in the lobby** with Knobs earned from the run, and a reason to try again.

The lesson is that Doors teaches through failure, not through a tutorial. The first reward is not an item; it is the knowledge "closets save you from Rush". That costs nothing to build and is impossible to skip. It also creates the screams that make Doors good on video, which feeds acquisition (see [[Short-Form Video Marketing]]).

## Core loop and retention

**Session loop.** One Hotel run is 100 doors. Fixed set pieces anchor the run: Seek chases appear around doors 35 and 75 and Figure appears at door 50 (the library) and door 100 (Press, GameWith and Pocket Tactics guides). Between those anchors the rooms, items and entity spawns vary, which is what makes it a roguelite. A run is long enough to tell a story and short enough to repeat in an evening.

**Long-term goals.** Achievements (you can display one, plus your death count, per Press, Wikipedia), modifiers that change difficulty (added August 2023), floors (Hotel, Mines, and sub-floors such as the Backdoor added through a Roblox event), and Knobs to spend on loadouts. There is no stat grind: your character does not get stronger, you do. That keeps the game fair for new players joining veterans.

**Social hooks.** The elevator is a party system that needs no friends list UI: you walk in. Co-op revives and shared panic are the social glue. The Content Update's Chat Control lets streamers' audiences interfere with runs, an acquisition feature dressed as a gameplay feature.

**Update cadence.** Slow and big: one floor per two years, with mid-sized updates (Hotel+, Modifiers, Content Update) and platform events between them. Doors survives this cadence because the base loop is replayable and because event participation brings players back without new floors. The cost was visible in 2024: a long-anticipated floor that disappointed part of the audience (Press, Roonby, September 2024).

## Monetization

Observed on the store page and the public game pass API (27 October 2026), the whole pass list is three items:

| Pass | Price (Robux) |
|---|---|
| BUSTER PASS (HALLOWEEN '26) | 99 |
| KITTY BUNDLE | 299 |
| ADMIN PANEL | 499 |

Developer products are not listed by the public API without logging in, so these come from guides and are lower confidence: Revives are Robux-only (Press, Dexerto codes guide); Knob packs in several tiers, with a hidden extra shop tier that appears after a player has spent a certain amount, topping out at 1,000,000 Knobs for 100,000 Robux (Community wiki, prices not verified for October 2026); Boosts that multiply Gold-to-Knobs conversion for three runs (five with Roblox Premium) (Community wiki).

Off-platform and platform-adjacent revenue is visible in the description: "Join the LSPLASH group for a free Revive" and "Buy (and wear) our UGC for some Knobs and a Revive" (Observed on the store page). That is a group-join reward and a UGC-ownership reward, both driving revenue and reach outside game passes. Merchandise exists too: Makeship plushies of entities (Press, Wikipedia).

What is notable is what is absent: no paid power, no gacha, no paid luck. Revives are the one pay-to-continue item, and they sit at the moment of maximum emotion (you died at door 93), which is effective and worth handling carefully.

## What to copy

1. **Teach by dying, then explain.** After every death, show one sentence about what killed you and the counterplay. Build it as a lookup table keyed by cause of death. Cheap, effective, and it turns frustration into intent. See [[First-Time User Experience and Onboarding]] and [[Teaching Through Level Design]].
2. **Lobby place plus run places.** A social lobby (high server size) that teleports parties into small run servers. This keeps the lobby lively and each run small. Build with [[Lobby and Hub Design]], [[Parties and Group Teleports]] and [[Teleporting and Multi-Place Games]].
3. **Fixed anchors inside random runs.** Doors puts set pieces at fixed door numbers and randomises between them. Players learn the rhythm ("Seek soon") while each run stays fresh. [[Dungeon and Room Generation]] and [[Seeds Determinism and Reproducible Worlds]] cover the generator; [[Horror Monster Chase AI End to End]] covers the chasers.
4. **Readable entity rules.** Every entity has one tell (flicker, sound, eye contact) and one counter (hide, look away, crouch). A rule a ten-year-old can repeat to a friend is a rule that spreads. [[Genre Playbook - Horror and Story]], [[Sound Design for Games]].
5. **Tiny, honest store.** A soft currency for loadouts, revives, a few cosmetic or event passes. Fewer products, each with a clear moment. See [[Developer Products and ProcessReceipt]] and [[Robux Price Points and Offer Design]].
6. **Group and UGC rewards.** A free revive for joining the group grows your notification audience; a reward for wearing your UGC turns players into walking ads. See [[Community Building]].
7. **A wordmark that survives 50 pixels.** Custom letterforms (door-shaped Os) beat a generic font. Recolour it per content era. See [[Thumbnails Icons and Store Page]] and [[Icon and Thumbnail Rendering Pipeline]].
8. **Make the game streamable on purpose.** Audience-interaction features (Chat Control) and death moments that read well on camera are acquisition systems. See [[Short-Form Video Marketing]].

## What not to copy

- **The cadence without the base.** A two-year gap between floors works only because the Hotel is replayable for hundreds of runs. A horror game with one linear chapter and no replay will be dead long before the second chapter. If you are small, ship smaller chunks; see [[Update Cadence and Hype Cycles]].
- **Hype without scope control.** A floor teased for about a year and then received coolly is the classic risk of announcing early. Announce when you can date it. See [[Patch Notes and Player Communication]].
- **Pay-to-continue pressure on children.** Revives at the moment of death convert well and also generate refunds and angry parents. Give free revives generously (codes, group join), cap how often the prompt appears, and never interrupt a chase with a purchase prompt. See [[Refunds Chargebacks and Purchase Support]].
- **Hidden spend tiers.** A shop tier that only appears after spending is a whale lever. It may be legal, but it is the kind of design that ages badly in press and with parents. Do not build it.
- **Copying the fear without the safety notes.** Doors warns about loud sounds and flashing lights in its description. If you copy the scares, copy the warnings and add settings (reduced flashing, volume caps); see [[Accessibility]].
- **Copying the IP.** Doors itself grew from *Rooms*, with its creator involved. Cloning Doors' entities and naming is what dozens of "Doors but bad" games did; none of them matter. Copy the structure, invent your own monsters.

## Checklist

- [ ] Every death shows a one-line cause and counter.
- [ ] Lobby place with parties, separate small run servers.
- [ ] Runs have fixed anchors and randomised filler.
- [ ] Each threat has one tell and one counter, testable on a ten-year-old.
- [ ] Store has at most a handful of products, each tied to one moment.
- [ ] Free revives exist and are easy to get.
- [ ] Wordmark readable at icon size; key text away from the thumbnail's bottom edge.
- [ ] Safety warnings and settings for loud and flashing content.
- [ ] Content cadence matches how replayable the base loop really is.

## Connected notes
<!-- auto-links:start -->
[[Case Study - Fisch]] · [[Case Study - Pet Simulator 99]] · [[Case Study - Adopt Me]] · [[Case Study - Dress to Impress]] · [[Links - Horror game mechanics]] · [[Marketing and Growth Start Here]] · [[Top Games Case Studies Start Here]]
<!-- auto-links:end -->
