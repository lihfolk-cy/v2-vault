---
tags: [case-study, top-games, thumbnails, icons, titles, marketing, discovery, click-through, live-ops, comparison]
---

# Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Changing the brand part of the title for each update, so returning players no longer recognise the game.
> - Avoid: Long text on art that becomes unreadable at phone size, or sits under the player-count overlay at the bottom.
> - Avoid: Illustrated art that promises a look the game does not have; allowed for images, not for video thumbnails, and costly in...
> - Title has a fixed brand and exactly one changing slot, with a dated change log.
> - Icon is a face, readable at 50 pixels.
> - Thumbnails share one template; key text is clear of the bottom edge.
>
> Cost: TL;DR ~180 tok · whole note ~4.2k tok. Read more: ## The snapshot · ## Pattern 1: the title is a fixed skeleton with one moving part · ## Common mistakes this comparison exposes · ## Checklist
<!-- tldr:end -->

This note compares how the games in this section present themselves on a Roblox card: the title string, the square icon and the 16:9 thumbnails. Everything was captured on the same day, 27 October 2026, from Roblox's public games and thumbnails APIs, which return the current title and the first three active thumbnails for each game. That week was unusual: Roblox's platform Halloween event, The Hollow, had started on 22 or 23 October 2026 depending on time zone (Press, Katadata, 21 October 2026), and most games were in Halloween dress. That makes the snapshot a good look at seasonal habits and a poor look at everyday art. Treat it as one frame of a moving picture.

Ground rules first. **Roblox does not publish click-through rates for other people's games.** No tracker can see impressions. What Roblox does tell you is what it measures for your own game: with 2 to 5 thumbnails active, personalization shows each to random users, measures qualified play-through rate (QPTR: qualified plays divided by home page impressions) per user group, then gives more impressions to the winner in each group; Roblox reported an average +8.5% QPTR in testing, with some games up 50% (Roblox docs, "Experience thumbnails", as of October 2026). So the art you see on a card is the art that is currently winning for someone like you, which also means other players may be seeing different cards. Everything below is reasoning from what is visible, labelled "Observed (27 October 2026)".

For the platform rules and specs (16:9, up to 10 images or videos, video authenticity rules, keep essential text off the bottom edge) see [[Thumbnails Icons and Store Page]]. For producing art see [[Icon and Thumbnail Rendering Pipeline]] and [[AI Image Generation for Icons Thumbnails and Concepts]]. For testing see [[A-B Testing and Experiments on Roblox]].

## The snapshot

Titles are exactly as the API returned them. "Hollow frame" means the red, dripping event border with The Hollow logo that several games wore that week.

| Game | Title on 27 Oct 2026 | Icon | Thumbnails (first returned) | Text on art |
|---|---|---|---|---|
| [[Case Study - Grow a Garden]] | `[🎃] Grow a Garden 🌶️` | Hollow frame; farmer avatar, giant eyeball plants; "GROW OFFLINE" in big white letters | Giant blocky sunflower under a rainbow cash total "$95,643,734,647" inside the Hollow frame; a glowing jack-o'-lantern crop under "GROW OFFLINE" | Yes, feature and number |
| [[Case Study - Steal a Brainrot]] | `[💀] Steal a Brainrot` | Darkened gameplay under a white hourglass and "3 HOURS" | A Halloween "SECRET" character beside "$997,151,167/s"; a "Skull Lucky Block" labelled "HALLOWEEN" with the same income line | Yes, income number and item names |
| [[Case Study - 99 Nights in the Forest]] | `99 Nights in the Forest 🔦` | Hollow frame; close-up of the deer monster's face | Deer looming over a sleeping avatar by a campfire, once with the Hollow frame and once without | No |
| [[Case Study - Adopt Me]] | `[🎃] Adopt Me!` | Cute spooky dragon pet; "ADOPT ME!" wordmark | Three Halloween pets (vampire sloth front) with the wordmark | Wordmark only |
| [[Case Study - Brookhaven RP]] | `Brookhaven 🏡RP` | Witch-hat avatar with a pumpkin framed in an open window; "BROOKHAVEN" banner | The same scene widened: house, avatar, pumpkin, banner, "RP" | Brand banner |
| [[Case Study - Dress to Impress]] | `[🎃 NEW QUEST] Dress To Impress` | Hollow frame; stylised gothic doll avatar | "Halloween UPDATE" script beside the avatar, once with the Hollow frame and once with the game logo instead | Yes, update label |
| [[Case Study - Blox Fruits]] | `Blox Fruits` | Armoured boss with lightning; "BLOX FRUITS" logo | Anime-style hero striking the same boss, logo bottom right | Logo only |
| [[Case Study - Doors]] | `DOORS 🍬🍭` | Hollow logo; top-hatted entity in front of a "CANDY VAULT" door; DOORS wordmark | Entity in a purple doorway with Hollow frame; a green Mines corridor; a pink office corridor of silhouettes | Wordmark only |
| [[Case Study - Pet Simulator 99]] | `🎉 [PSX] Pet Simulator 99! 🐾` | Three mascot pets on blue, no text | Illustrated meadow of pets; one red panda pet in autumn colours | None (tiny studio logo) |
| [[Case Study - Fisch]] | `Fisch 👻 [HORSEMAN]` | Screaming avatar with a glowing rod next to a giant serpent | Giant serpent in a candle-lit cave; birthday party sea dragon | None |

Source for every cell: Observed (27 October 2026) via the Roblox public games API (titles) and thumbnails API (icons, first three thumbnails per game). The section covers ten games, and all ten are compared here.

## Pattern 1: the title is a fixed skeleton with one moving part

Every title keeps the brand name in the same place and changes at most one token.

- **Bracket tag before the name** (Grow a Garden, Steal a Brainrot, Adopt Me, Dress to Impress): `[🎃]`, `[💀]`, `[🎃 NEW QUEST]`. The bracket holds an emoji or a short phrase, and in October it holds the season.
- **Bracket tag after the name** (Fisch): `Fisch 👻 [HORSEMAN]`. The tag names the update itself. RoWatcher's archived page names for Fisch show two years of this: `[FISCHFRIGHT]`, `[SKYCREST]`, `[MARIANA]`, `[BIRTHDAY]`, and a teaser pair `[SOON]` then `[NOW]` (Public stats site, RoWatcher URLs, read October 2026).
- **Emoji sandwich with a tag** (Pet Simulator 99): `🎉 [PSX] Pet Simulator 99! 🐾`. RoWatcher's archive shows `[DIAMOND]`, `[WORLD CUP]`, `[MINE]`, `[ARCADE]`, `[TAP HEROES]` and others over time, in step with a weekly Saturday update (Public stats site, RoWatcher, read October 2026).
- **Brand plus one emoji, no tag** (Doors `DOORS 🍬🍭`, 99 Nights `🔦`, Brookhaven `🏡RP`). Doors has used a mode tag at times (`DOORS [ rush mode ]`, RoWatcher archive), but mostly lets one seasonal emoji pair do the work.
- **No decoration at all** (Blox Fruits). The biggest action RPG on the list uses its plain name.

Why this pattern wins, reasoned: a returning player scans the Continue row by shape. A stable skeleton keeps the game recognisable; a changed token says "something is new" without forcing a re-read. Games for older or more brand-conscious audiences (horror, action RPG) decorate less; games for younger audiences and fast update cycles decorate more. Nobody on this list uses "x2", "FREE", "OP" or all-caps hype in the title; the platform's top games look calm. Roblox's brand rules also bar "Roblox" or "Blox" style names for experiences created on or after 22 June 2022 (Roblox brand guidelines, via search summary, October 2026), so a title like Blox Fruits (created 2019) cannot be imitated by a new game.

**Copy this:** write your title as `Brand` plus a slot, decide where the slot sits, and keep a log of every value it takes and the date. Pair the log with your analytics so you can see whether `[NEW QUEST]` beats `[🎃]`. See [[Update Cadence and Hype Cycles]] and [[Patch Notes and Player Communication]].

## Pattern 2: icons are faces

Eight of ten icons are built around a face looking at the viewer: the PS99 grey cat, the Adopt Me dragon, the 99 Nights deer, the Doors entity, the Brookhaven witch, the Dress to Impress doll, the Fisch screaming avatar, the Grow a Garden farmer. The exceptions are revealing: Steal a Brainrot used its icon as a countdown ("3 HOURS" over an hourglass), and Blox Fruits shows a boss whose face is a helmet with glowing eyes, which still reads as a face.

Big eyes dominate for the young-audience games (PS99, Adopt Me, Dress to Impress); horror games use the same trick inverted (the 99 Nights deer's huge white eyes, the Doors entity's single glowing monocle). At icon size, eyes are what the visual system finds first.

Text on icons is rare and short: a wordmark (Adopt Me, Brookhaven, Doors, Blox Fruits), a feature ("GROW OFFLINE"), or a countdown ("3 HOURS"). Nobody writes a sentence on an icon.

**Copy this:** your icon is a character's face, cropped tight, with one bright point near the eyes. Add a wordmark only if your brand already means something. See [[Zone and Biome Art Direction]] for palette choices.

## Pattern 3: two art strategies, picked by audience

Looking at the thumbnails, the ten games split into two camps.

**Mood art** (no headline text, character and atmosphere carry it): 99 Nights, Adopt Me, Brookhaven, Doors, Pet Simulator 99, Fisch, Blox Fruits. Brand style is consistent across years; seasonal versions recolour the same idea. PS99 uses flat illustration rather than in-game renders; the others use posed in-engine renders with heavy lighting or painted overpaint (Blox Fruits).

**Number art** (a giant number is the headline): Grow a Garden (`$95,643,734,647`), Steal a Brainrot (`$997,151,167/s`). These are the two biggest games of 2025 by peak concurrency (Grow a Garden over 16 million on 21 June 2025 and at least 22.3 million on 23 August 2025; Steal a Brainrot the only game past 25 million, per Press coverage collected on Wikipedia's list of Roblox games, read October 2026). The number sells the fantasy of the genre, "your income can be this big", and it is the same fantasy the HUD sells in game. Steal a Brainrot also names the featured item and its rarity in rainbow text ("SECRET", "HALLOWEEN"), which is the RNG genre's way of showing a jackpot.

Neither camp is right. Number art suits incremental and tycoon games where the number is the dream; mood art suits games where the dream is a place, a creature or a person. Mixing them (a horror game with a big number on it) usually confuses: Roblox's docs warn that "ambiguous imagery or graphics may lead to unnecessary confusion" (Roblox docs, as of October 2026).

**Copy this:** decide what the player is dreaming about in your genre, and put exactly that on the card. If it is a number, make the number huge and readable at phone size and keep it away from the bottom edge. If it is a creature or a place, show one of it with scale contrast (Fisch's small avatar next to a huge serpent is the cleanest example). See [[Genre Playbook - Simulators]] and [[Genre Playbook - Horror and Story]].

## Pattern 4: the platform event frame

Doors, Grow a Garden, 99 Nights and Dress to Impress all wore The Hollow's red event frame on at least one icon or thumbnail. Press listed nine core horror games in the event, including Doors and 99 Nights (Press, Katadata, 21 October 2026); Grow a Garden and Dress to Impress are not on that list but used the frame too. Their exact role in the event (quest partner or similar) was not verified.

Two games show something more useful: 99 Nights and Dress to Impress had **the same artwork with and without the frame** in their active set. With personalization on, that is an experiment: does the event badge earn more qualified plays than clean art? Roblox will route impressions to whichever wins per user group. That is the cheapest A/B test anyone can run on a card.

Adopt Me, Brookhaven, PS99, Fisch and Blox Fruits ran their own Halloween or seasonal art without the platform frame. Big brands do not need borrowed branding.

**Copy this:** when your game is in a platform event, upload a framed and an unframed version of your best art and let personalization pick. Remove the framed one the day the event ends. See [[Live Ops Events and Updates]] and [[Event Calendars and Content Planning]].

## Pattern 5: seasonal art is mandatory, and it is a recolour

Nine of ten games had Halloween content in their title or art in late October. The tenth, PS99, went autumn (maple leaf, orange trees) rather than spooky. What they mostly did not do is change composition: Brookhaven kept the open-window frame and banner and swapped the avatar's outfit and a pumpkin in; Adopt Me kept "pets plus wordmark" with spooky pets; Doors kept "entity in a doorway". The format is the brand; the season is a costume.

There is a cost, visible in the capture: Fisch still had a birthday thumbnail active in late October. Stale event art in rotation tells players the page is not maintained.

**Copy this:** design your thumbnail as a template (composition, logo position, character slot) so a seasonal version is an afternoon of work, not a new commission. Keep a calendar of which art is live and when it expires. See [[Limited-Time Offers - Design and Ethics]] for the same discipline applied to offers.

## Pattern 6: the icon as a notice board

Steal a Brainrot's icon was a countdown: an hourglass and "3 HOURS". Grow a Garden's icon advertised a feature: "GROW OFFLINE". Both are using the most visible pixel space they own as a news channel, which only works for a game players already know, because a new player learns nothing about the game from an hourglass.

This is a high-traffic game's move. For a new game, the icon must explain the game; for a giant, the icon can explain this week. If you try it, watch new-player QPTR, not just total plays, and swap back fast.

## Pattern 7: the description does onboarding

Not a card element, but it lives one click away. Fisch's description is a four-line how-to-play (hold to cast, shake, follow the blue line). Doors' description tells you to enter "without a guide" and to "use each death as a lesson", lists loud sound and flashing warnings, and offers a free revive for joining the group. PS99's is two lines and a pet count. Long descriptions are not read by everyone, but the people who read them are the ones deciding whether to play. See [[First-Time User Experience and Onboarding]].

## What the numbers can and cannot tell you

- Concurrent players on the day (from the same API call, 27 October 2026): Brookhaven 330,140; Steal a Brainrot 232,279; Adopt Me 208,461; 99 Nights 156,953; Blox Fruits 127,198; Dress to Impress 98,205; PS99 79,861; Fisch 57,943; Doors 44,980; Grow a Garden 13,784. These are single readings at one moment and say nothing about which card art is better.
- You cannot infer CTR from player counts. A game with a weaker card can have more players because of retention, friends, events or ads. Use these games as a menu of patterns, then test on your own audience with personalization and [[Analytics and Funnels]].
- Paid placement is invisible from outside. Roblox sponsored ads exist (see [[Sponsored Ads and Campaign Math]]) but nobody publishes who bought what, so none is claimed here.

## A working method for your own game

1. **Write a title skeleton.** `Brand` plus one slot. Decide the slot's position and vocabulary (season emoji, update name, short phrase). Keep a dated log.
2. **Pick your camp.** Number art or mood art, by what the player dreams about. Do not mix.
3. **Make the icon a face.** Tight crop, big eyes or one bright point, wordmark only if earned.
4. **Make three thumbnails from one template.** Same composition, different hook (character, scale contrast, feature). Keep key text away from the bottom edge.
5. **Turn on personalization with 2 to 5 active.** Leave several active; Roblox recommends testing new thumbnails with major updates and then not changing them until the next update (Roblox docs, as of October 2026).
6. **Seasonal swap by template.** Recolour and recostume, do not recompose.
7. **Retire event art on time.** Calendar it.
8. **Judge by QPTR and session length**, not by impressions. Art that wins clicks and loses players is a bad trade. See [[Discovery and the Algorithm]].

## Common mistakes this comparison exposes

- Changing the brand part of the title for each update, so returning players no longer recognise the game.
- Long text on art that becomes unreadable at phone size, or sits under the player-count overlay at the bottom.
- Illustrated art that promises a look the game does not have; allowed for images, not for video thumbnails, and costly in first-session bounce.
- Borrowed event frames left on after the event.
- A notice-board icon on a game nobody knows yet.
- Copying the top games' hype numbers onto a genre where numbers are not the fantasy.

## Checklist

- [ ] Title has a fixed brand and exactly one changing slot, with a dated change log.
- [ ] Icon is a face, readable at 50 pixels.
- [ ] Thumbnails share one template; key text is clear of the bottom edge.
- [ ] Art style matches what the first session looks like.
- [ ] 2 to 5 thumbnails active for personalization.
- [ ] Event and seasonal art have expiry dates.
- [ ] Decisions are made on QPTR and session time, not impressions.

## Connected notes
<!-- auto-links:start -->
[[Top Games Case Studies Start Here]] · [[Click-Through Rate]] · [[Core Loop]] · [[Thumbnail Contrast]] · [[Launch Strategy - The First Two Weeks]] · [[Marketing and Growth Start Here]]
<!-- auto-links:end -->
