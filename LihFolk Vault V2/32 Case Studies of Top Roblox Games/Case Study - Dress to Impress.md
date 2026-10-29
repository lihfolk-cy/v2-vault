---
tags: [case-study, top-games, dress-up, rounds, voting, collaborations, live-ops, monetization, thumbnails, type/case-study, area/design, level/intermediate]
---
# Case Study - Dress to Impress

<!-- tldr:start -->
> [!tldr] TL;DR
> - Every round has a theme and a visible timer.
> - The full loop is shown within the first round (under 8 minutes).
> - Every participant gets a payout; the top three get a podium.
> - Votes are validated, weighted and rate limited on the server.
> - A no-timer Freeplay mode exists.
> - Item browsing is virtualised and fast on phones.
>
> Cost: TL;DR ~120 tok · whole note ~4.7k tok. Read more: ## 1. Snapshot · ## 6. What to copy and what not to copy · ## Checklist
<!-- tldr:end -->

Dress to Impress (DTI) took a very old game format (a themed dress-up contest judged by other players) and made it one of the most played experiences on Roblox within a year of launch. It is the best recent proof that a **short, round-based social loop with player voting** can beat bigger, more complex games, and that **story events and brand collaborations** can keep a simple loop fresh. It is also a lesson in volatility: its player count rose fast and fell a long way, so study both halves.

Source labels used below: **Observed in the live game (October 2026)** means the public Roblox store page and public web API (games, votes, game passes, media, thumbnails) read on 27 October 2026, with no login and no play session. **Public stats site** means third party trackers. **Studio statement** means the group's own store text. **Press** means named outlets and guides. Roblox does not publish click-through rate or revenue for other creators' games; anything about clicks is reasoning from visible assets.

---

## 1. Snapshot

| Field | Value | Source |
|---|---|---|
| Title on 27 Oct 2026 | "[🎃 NEW QUEST] Dress To Impress" | Observed in the live game (October 2026) |
| Studio | Dress To Impress Group (verified badge), led by a teenage developer who began the project at 14 | Observed in the live game (October 2026); Press (Kotaku, 14 August 2024; Daily Dot, 3 October 2024) |
| Created / released | Store record created 18 October 2023; public release 11 November 2023 | Observed in the live game (October 2026); Press (Wikipedia) |
| Genre tags | Roleplay & Avatar Sim, subgenre Dress Up | Observed in the live game (October 2026) |
| Total visits | 11,252,576,208 | Observed in the live game (27 October 2026) |
| Favourites | 7,687,764 | Observed in the live game (27 October 2026) |
| Likes / dislikes | 4,047,276 / 421,395 (about 90.6% positive) | Observed in the live game (27 October 2026) |
| Server size | 13 players | Observed in the live game (October 2026) |
| Players at the moment of reading | 97,684 (one snapshot, afternoon US time, during a Halloween update) | Observed in the live game (27 October 2026) |
| Peak (as of mid 2024) | Over 651,000 concurrent, soon after the Charli XCX "Brat" collaboration in August 2024 | Press (New York Times, 15 September 2024, via Wikipedia) |
| All-time peak | About 1.7 million concurrent, December 2024 (one source gives 1.73 million) | Public stats site (RoWatcher and a games aggregator; Lootbar blog). Not confirmed by the studio or major press |
| Plays by September 2024 | Over 2.7 billion (Roblox spokesperson) | Press (Eurogamer and New York Times, September 2024) |
| Routine position in 2024 | Often the most played game on Roblox in September 2024, usually averaging over 250,000 concurrent | Press (Eurogamer, 1 September 2024; New York Times) |
| Later level | About 75,000 to 100,000 concurrent in May 2026 | Press (Lootbar blog; weak source) and consistent with the 97,684 snapshot above |
| Awards | 2024 Roblox Innovation Awards: Builderman Choice of Excellence, Best Creative Direction, Best New Experience | Press (New York Times, via Wikipedia) |

Things we could not verify: the exact all-time peak and its date from a strong source (trackers agree on about 1.7M in December 2024 but we could not open a tracker page that renders the number). Any revenue figure. Whether the monthly VIP option guides describe (299 Robux for 30 days) is still sold; the public pass list only shows the permanent VIP Pass.

### The shape of the curve

Launch November 2023, viral spread on TikTok in spring 2024 (Press: Distractify, May 2024, on the "Pose 28" meme), record after the Brat collaboration in August 2024, an even larger peak around the Christmas 2024 update (Press: IGN and Beebom, 14 December 2024, report a limited code item that mass redemption briefly crashed the game), then a long decline to roughly a sixth of the peak by 2026. The game is still large, but the drop shows that a single round format, however good, depends on fresh themes, items and events to hold a mass audience.

---

## 2. Click-through: icon, thumbnails and title

No CTR data is public. This is reasoning from assets downloaded from the public thumbnails API on 27 October 2026.

### What is on the store page now (Observed in the live game, October 2026)

- **Icon:** a close-up of one stylised female avatar (pale blonde twin tails, glossy lips, lace choker, finger to lips), with a purple-pink glow behind, inside a red dripping horror-style frame topped with "The Hollow" logo. The Hollow is Roblox's platform-wide Halloween 2026 event (Press: several guides, October 2026), so the icon is advertising DTI's participation in a platform event.
- **Thumbnails:** 10 images and 1 video. The four I pulled: "Halloween UPDATE" in script lettering with the same doll-like avatar under a full moon, with The Hollow frame; the same image without the frame; a pastel "10B" visits celebration image with a pink outfit and a heart wand; a "Summer in Brazil" image with a carnival outfit.
- **Avatars in thumbnails are not plain Roblox avatars.** They are stylised, high detail fashion renders with realistic faces, makeup and hair, closer to a fashion doll or a beauty ad than to classic blocky Roblox.
- **Title:** "[🎃 NEW QUEST] Dress To Impress". Emoji plus a short ALL CAPS tag in brackets announcing what changed.
- **Description:** short, emoji-heavy, with "Are you ready to be the TOP MODEL?" and bullet lines for new items, voting and runway poses (Studio statement, store text).

### Why this probably works

1. **The thumbnail is the fantasy, not the gameplay.** DTI sells "look amazing". A close-up face with makeup and a styled outfit is that promise in one image; showing a crowded runway would read as noise.
2. **Tag the reason to return.** "[NEW QUEST]" tells lapsed players exactly why to come back now. DTI's quests are story chapters (the Lana storyline, below), so the tag points at the part players talk about.
3. **Platform event tie-in.** The Hollow frame on the icon links DTI to a Roblox-wide event, which plausibly earns placement in event sorts and catches players browsing for that event. We could not confirm DTI's chart placement from the event; this is inference from the frame.
4. **Milestone art.** A "10B" visits image is social proof: "this is the big one". Cheap to make, and it doubles as a celebration post.
5. **Theme-specific scenes.** "Summer in Brazil" shows that each themed update gets its own hero image with a location and outfit, which keeps the gallery from going stale.

A risk worth naming: the thumbnail faces are much more detailed than what players see in game. It works because the outfits and makeup are real in game items, but it raises expectations. See [[Thumbnails Icons and Store Page]] and [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

---

## 3. The first five minutes

Sources: Wikipedia (citing Game Rant, Eurogamer, Kotaku, The Escapist), beginner guides (Press, 2024 to 2026). Not played first-hand.

1. **Lobby with a timer.** You join a small server (13 players) already cycling rounds. During lobby intermission, the next theme is announced.
2. **Theme and countdown.** The theme stays on screen with a timer during dressing. Press (Game Rant, October 2024) reported 360 seconds to build an outfit; current timing may differ.
3. **Dress.** Players walk to racks and stations in a shared dressing area to equip up to 18 clothing items and adjust makeup, skin tone and nails (Press: Eurogamer, Kotaku, 2024). Many items are free from the start.
4. **Runway and vote.** When the timer ends, each player walks the runway with a pose while everyone else rates 1 to 5 stars.
5. **Podium and payout.** The top three appear on a podium. Every player receives Stars (rank progress) and Cash (soft currency) based on placement (guides).

So within about seven minutes a brand new player has seen the full loop, been judged by real people, and received a reward. The first reward is social as much as material: other players voted on your look. There is also a **Freeplay** mode with no timer, theme or voting, which is a low-pressure place to learn the items.

What is clever: the theme gives a creative constraint so nobody faces a blank page, the timer forces "finish something", and judging is distributed so every round produces winners and stories. See [[First-Time User Experience and Onboarding]] and [[Spawning Teams and Rounds]].

---

## 4. Core loop and retention

### Session loop

Round: theme, dress (timed), runway, vote, podium, payout. Repeat every few minutes. Short rounds mean a session can be 10 minutes or 2 hours.

### Long-term goals

- **Rank ladder from Stars.** Total Stars set your rank, starting from entry ranks for new players (guides list early tiers such as 0 to 49 and 50 to 199 Stars; the top tier and total count differ between guides, so I do not repeat them). Ranks unlock items (Press: Wikipedia).
- **Cash for items.** Cash buys more clothing and accessories.
- **Codes and limited items.** Limited-time codes unlock items (Press: Kotaku, PC Gamer, 2024). The December 2024 update famously had a code item available for three hours.
- **Story and lore.** Starting with April 2024 and especially Halloween 2024, DTI added limited-time story quests centred on Lana, the in-game nail technician, mixing mystery and Greek myth elements (Press: IGN, 19 October 2024). Players theorise about the story between updates, which keeps the game in conversation even when they are not playing.

### Daily and timed systems

- An advent calendar rewarded daily play in December 2024 (Press: IGN, 14 December 2024).
- Halloween 2026: guides (Press, October 2026) describe an update live on 17 October with a 40-tier Halloween pass, minigames, and a story quest that arrived about a week after launch. The store title tag "[🎃 NEW QUEST]" matches that. Details are guide-reported, not confirmed by the studio.
- A Style Showdown mode entered beta in early 2025 (Press: IGN, February 2025).

### Collaborations

- **Charli XCX "Brat"** (August 2024): items, emotes, patterns, eight new themes; followed by the record of over 651,000 concurrent (Press: Billboard Philippines, NME, Polygon, New York Times).
- **Lady Gaga "Mayhem"** (16 to 23 August 2025): a themed mode and live judging. Some players criticised the live event format (Press: GameSpot, Billboard Philippines, Vice).
- **Wicked: For Good** (8 to 29 November 2025): themes, items and a pose pack (Press: GMA Network).

Collaborations bring press coverage and new audiences, but they do not by themselves fix a declining base; the 2025 collaborations happened during the long decline.

### Social hooks

Voting is the core social hook: you play for other people's approval and you judge them back. Duo mode lets two friends compete together. Poses became memes (Pose 28), and streamers with large audiences played it in 2024 (Press: Polygon, New York Times), which drove discovery from outside Roblox.

See [[Core Loops and Session Design]], [[Retention and Return Hooks]], [[Live Ops Events and Updates]].

---

## 5. Monetization (public store page)

Observed in the live game (27 October 2026), from the public game passes endpoint. 14 passes on sale:

| Pass | Price |
|---|---|
| Increased Item Limit | 129 |
| Run Faster | 149 |
| French Luxury Set | 279 |
| Materials+ | 299 |
| Moongazer Set | 299 |
| Denim Set | 299 |
| Rich Girl Set | 299 |
| Custom Makeup | 349 |
| Sweet Berry Set | 349 |
| Moonlight Butterfly | 379 |
| x2 Money | 399 |
| Queen Of Hearts | 399 |
| Haunting Beauty | 449 |
| VIP Pass | 799 |

One more ("Futuristic Suit") is off sale.

What the list shows:

1. **Outfit sets are the main product.** Eight of fourteen passes are named clothing sets in the 279 to 449 band. They are the in-game equivalent of a fashion collection drop, and each is a direct, visible advantage in a game judged on looks, but only in style, not in mechanics.
2. **Creative tools.** Custom Makeup, Materials+ and Increased Item Limit (more items per outfit) give more options rather than better stats.
3. **One currency multiplier.** x2 Money at 399.
4. **VIP at 799.** Guides (Press, 2025 and 2026) list a VIP room with more private dressing rooms and salon seats, exclusive items, a tag, and VIP-only modes, and mention a monthly option at 299 Robux that we could not see in the public pass list. Unverified.
5. **Run Faster at 149.** In a timed dressing round, getting between racks faster is a small real advantage. It is the one pass here that changes the competition, and the price is low.
6. **Robux items and codes.** Press (Wikipedia, citing Kotaku and PC Gamer) notes items can be bought with Cash or Robux, plus code items.

Pricing note: there are no random boxes in the pass list and no stat power. Everything is either a look or a convenience. That keeps a judged game fair in feel even though paying players do look different.

---

## 6. What to copy and what not to copy

### Copy

1. **A short, timed, judged round.** Theme, timed creation, show, vote, podium. It works for building, drawing, cooking, decorating, not only fashion. Teach: [[Spawning Teams and Rounds]], [[Genre Playbook - Party and Minigame Collections]].
2. **Constraints as onboarding.** A theme plus a timer removes the blank-page problem for new players. Teach: [[First-Time User Experience and Onboarding]].
3. **Pay everyone, reward the top three.** Placement-based payouts for every participant keep losers in the game; the podium gives winners a moment. Teach: [[Economies and Currencies]], [[Progression and Pacing Design]].
4. **A rank ladder from peer votes.** Ranks from accumulated stars, with item unlocks, give a long goal to a loop with no levels. Teach: [[Progression Levels and Unlocks]].
5. **A Freeplay mode.** A no-pressure sandbox where players learn items without being judged. Cheap to build, big for shy players.
6. **Story as a live-ops layer.** A mystery character with chapters released over events gives players something to discuss between sessions. Teach: [[Live Ops Events and Updates]], [[Quests and Objectives]].
7. **Tag the title with the reason to return.** "[🎃 NEW QUEST]" is specific. Teach: [[Thumbnails Icons and Store Page]].
8. **Join platform events.** Wear the platform event frame on your icon when you participate. Teach: [[Discovery and the Algorithm]].
9. **Sell sets, not stats.** Themed item sets at mid prices fit a creative game perfectly. Teach: [[Game Passes]], [[Robux Price Points and Offer Design]].

### Do not copy

1. **Voting without anti-abuse.** Peer voting invites friend-boosting, revenge low votes, and bots. Weight votes, ignore outliers, and rate limit. Teach: [[Server Authority and Validation]], [[Rate Limiting and Abuse Prevention]].
2. **Limited code drops with no load plan.** The December 2024 three-hour code item crashed the game in its first minutes as everyone redeemed at once (Press). Spread redemptions, use a queue, and test the remote under load. Teach: [[MemoryStore Service]], [[Live Incident Response and Post-Mortems]].
3. **Thousands of items without a virtualised inventory.** A dress-up game lives or dies on item browsing speed. Do not create one frame per item. Teach: [[Virtualized Lists and Large Inventories]].
4. **Clothing that clips through bodies.** If your game is about looks, invest in layered clothing and cages early. Teach: [[Layered Clothing Cages and Animation]], [[UGC Avatar Items and Accessories]].
5. **Relying on virality.** DTI's peak came from TikTok memes, streamers and a pop collaboration in the same year. That is not a plan. The decline after it shows that a viral hit needs a content pipeline ready before the wave. Teach: [[Update Cadence and Hype Cycles]], [[Launch Strategy - The First Two Weeks]].
6. **Live events that promise more than they deliver.** The 2025 celebrity live event drew criticism for being less personal than fans expected (Press: Vice). Set expectations precisely in your announcements.
7. **Forgetting safety in a social judging game.** Comments on looks and bodies need filters, reporting, and clear rules. Teach: [[Age Checks and Safety Features]], [[Ethical Design and Player Trust]].

### A buildable mini version

A round manager (lobby 20 s, create 180 s, show 8 s per player, vote, podium), one creation activity (outfits, rooms or cakes), 60 starter items, a 5-tier rank ladder from stars, a Freeplay mode, and one themed item set as a pass. Add one story chapter as your first event. Six to eight weeks for a small team.

---

## Checklist

- [ ] Every round has a theme and a visible timer.
- [ ] The full loop is shown within the first round (under 8 minutes).
- [ ] Every participant gets a payout; the top three get a podium.
- [ ] Votes are validated, weighted and rate limited on the server.
- [ ] A no-timer Freeplay mode exists.
- [ ] Item browsing is virtualised and fast on phones.
- [ ] Passes sell looks and tools, not stats; any speed pass is cheap.
- [ ] Limited drops are load tested and spread over time.
- [ ] Title tag names the specific new thing.
- [ ] A story or event layer is ready before any viral spike.

## Sources

- Observed in the live game (October 2026): Roblox public web API (games, votes, game passes, media and thumbnails endpoints) for the experience, read 27 October 2026, no login.
- Press: Wikipedia "Dress to Impress (video game)" (read October 2026), citing New York Times (15 September 2024), Eurogamer (1 September 2024), Kotaku (14 August 2024), Game Rant (8 October 2024), IGN (19 October 2024, 14 December 2024, February 2025), Polygon, NME, Billboard Philippines, GameSpot (13 August 2025), Vice, GMA Network, Distractify, Daily Dot.
- Public stats site: RoWatcher, a games aggregator and the Lootbar blog for the December 2024 peak and 2026 levels (weak, unconfirmed).
- Press: beginner, VIP and Halloween 2026 guides (esports.gg, Pixel Twelve, Dungeonpath, Pro Game Guides, All Things How, Of Zen and Computing) for round flow, ranks, VIP perks and the 2026 event. Mixed quality; flagged in text.

## Connected notes
<!-- auto-links:start -->
[[Case Study - Steal a Brainrot]] · [[Case Study - Adopt Me]] · [[Case Study - Blox Fruits]] · [[Case Study - Grow a Garden]] · [[Round-Based Minigame Loop End to End]] · Working with Content Creators · [[Top Games Case Studies Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Brookhaven RP]] · [[Case Study - Doors]] · [[Case Study - Pet Simulator 99]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Fisch]] · [[Case Study - Murder Mystery 2]] · [[Case Study - Forsaken]] · [[Case Study - Tower Defense Simulator]]
<!-- related:end -->
