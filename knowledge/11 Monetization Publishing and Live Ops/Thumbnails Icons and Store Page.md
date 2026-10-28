---
tags: [publishing, thumbnails, icons, store-page, marketing, discovery]
---
# Thumbnails Icons and Store Page

The icon, thumbnails, title and description are your game's storefront. They decide **play-through rate**, which the Creator Hub calls the most important signal for Recommended for You ([[Discovery and the Algorithm]]). This note gives the specs, the moderation rules, thumbnail personalisation, and how to make and test art that earns clicks without misleading anyone. Specs and rules verified against the Creator Hub "Thumbnails" and "Experience icons" pages **as of October 2026**; design guidance is rule of thumb.

---

## 1. Specs (Docs, Oct 2026)

### Icon
- **Square, at least 512x512.** Docs provide a 512x512 template.
- Some site and app locations shrink it to about **150x150**: preview it at that size.
- Upload: Creator Dashboard, the game, Configurations, Places, the start place (starred), Icon; media type Image (Docs).
- **One icon per locale** is supported, so you can localise the icon (Docs).
- Every icon passes moderation before others see it. Without an upload, Roblox generates one from default images.

### Thumbnails
- **16:9.** Non-16:9 images are stretched (not cropped) to 16:9.
- **Recommended 1920x1080.**
- Formats: `.jpg`, `.gif`, `.png`, `.tga`, `.bmp`.
- **Up to 10 images or videos** on the details page.
- Personalisation uploads: under **3 MB** and 1920x1080.
- **Video thumbnails:** free, **3 uploads per month**; rejected videos still count. Not supported on Xbox, PlayStation and VR headsets (Docs).
- **A custom thumbnail is required for Home recommendations** (Docs, discovery page). The auto-generated image (from Studio's camera at your last publish) is not enough.

### Moderation rules for media (Docs)
Allowed in video: varied camera angles, minor post-processing (brightness, contrast, light effects), logo overlays, curated highlight sequences, in-game UI text, catalogue music.

Not allowed:
- gameplay, UI or interactions that are not actually in the game, or a misrepresented theme;
- graphics enhanced beyond what players will see;
- real-life footage or external content;
- voice-overs, narration, voice chat, or music with lyrics;
- ads, promotions or subjective claims (the docs' example: "50% off").

The same spirit applies to stills: show the game players will get. "Enhanced beyond what players will see" rules out offline renders with lighting your game does not have, unless they faithfully represent it.

---

## 2. Thumbnail personalisation (Docs)

- Activates when **2 or more** thumbnails are active; setup suggests **2 to 5**.
- Each thumbnail is shown to random users; the winner for each user group gets more impressions while others get minimal traffic.
- Metrics: status, impressions, qualified plays, average playtime, qualified play-through rate, winning segment. Data appears after a few hours.
- Docs report an average **+8.5%** in qualified play-through rate for games using it, and some games up to **+50%**.
- Docs advice: keep several thumbnails active rather than picking one winner; test new thumbnails with major updates, then hold steady.

Note the metric is **qualified** play-through: plays that lead to meaningful engagement. A clickbait thumbnail that wins clicks but loses players fast scores badly here too.

---

## 3. What makes a thumbnail work (rule of thumb)

Roblox thumbnails are seen small, on phones, next to dozens of others, by young players. They are read in under a second.

1. **One subject, big.** A character, a creature, a giant item. Fill 40 to 60% of the frame. Small scenes read as noise at tile size.
2. **One idea.** "You roll for legendary swords." "You run from a monster." Not a collage of every feature.
3. **Contrast and saturation** matched to genre. Docs: bright saturated colours for fantasy, muted for sombre, high contrast for horror.
4. **Faces and emotion.** Avatars reacting (shock at a rare drop) outperform static poses in most casual genres.
5. **Text sparingly**, only to describe gameplay (Docs). Three words maximum, huge, outlined. Never "FREE", "50% OFF", "UPDATE!!!" style claims (moderation and the no-promotions rule).
6. **Keep the bottom clear.** Metadata such as player counts can cover the bottom of the tile (Docs). Rule of thumb: keep critical content out of the bottom 15% and away from corners.
7. **Consistency with the icon.** The icon is the brand (a single bold symbol or character face); thumbnails show the action.
8. **Real game, best angle.** Stage a scene in Studio: hand-placed characters, posed rigs, best lighting your game actually uses, then capture at high resolution. Posing rigs is covered in [[Posing and Silhouettes]] and [[Cameras and Cutscenes]].

### Making them in Studio
- Build a "photo booth" place (a copy of the game) with posing rigs and lighting presets so thumbnails can be re-shot after each update.
- Set the viewport to an exact 16:9 size and hide the UI; capture larger than 1920x1080 and downscale for crisp edges.
- Use the game's real VFX at a frozen frame for energy ([[VFX Design Playbook]]).
- For the icon, render a single character or item on a flat or gradient background with a thick outline; test at 150 px.

### Seasonal and event refreshes
Holiday art (snow on the hub, a pumpkin on the icon) can lift play-through for the weeks it is relevant, but it is easy to leave stale art up in February. Treat seasonal variants as events: add them to the personalisation pool when the event starts, remove them when it ends, and keep the evergreen winners active underneath. If the season changes the game itself (a winter map), the art must show that real content; a festive thumbnail over an unchanged game is a small misrepresentation players notice. Event thumbnails on Experience Events are separate from the main pool and are the cleaner place for limited-time art ([[Live Ops Events and Updates]]).

### Video thumbnails
- Open on action in the first second; tiles autoplay briefly.
- Show the core loop in order: action, reward, rarity reveal.
- Only catalogue music without lyrics; no narration (Docs).
- Three per month, rejections included: get a moderation-safe cut right the first time.

---

## 4. Title and description

- **Title:** short, specific, the genre word players search with, and the hook. Search is semantic (Docs), so accuracy beats keyword lists. Rule of thumb: avoid stuffing "[UPDATE]" and emoji into the title; if you use an update tag, keep it truthful and remove it when stale.
- **Description:** first two lines say what the player does and why it is fun. Then current update, then controls, then community links (links are visible only to age-checked 16+ users since June 30, 2026, per the announcement; see [[Age Checks and Safety Features]]).
- **Honesty requirements:** do not promise Robux or rewards you do not control; describe subscription and pass benefits accurately (Docs, payouts and subscriptions pages).
- **Localise** the title, description and icon for your top non-English regions ([[Localization]]).

---

## 5. The rest of the store page

The Game Details page shows events, groups, passes and subscriptions, and similar games (Docs). Use it:
- **Events:** always have one upcoming or active event so the page looks alive ([[Live Ops Events and Updates]]).
- **Passes and subscriptions:** they are listed with icons; custom icons matter (Docs recommend them for passes).
- **Group:** a linked community gives players a place to go ([[Community Building]]).
- **Badges:** players browse them; they hint at content depth.

---

## 6. Testing loop

1. Make 4 to 5 variants that differ in one major idea each (subject, colour mood, character emotion), not five near-copies.
2. Activate them together; wait for enough impressions (the dashboard shows impressions per thumbnail).
3. Compare **qualified play-through rate** and **average playtime**, not raw clicks.
4. Keep the winners active (personalisation uses all of them per segment), retire clear losers, add a new challenger with each major update.
5. Check the winning segment: if one thumbnail wins only with older users, that tells you something about your audience.

Pair this with the Acquisition dashboard: if impressions are high but play-through is low, the tile is the problem; if play-through is fine but bounce is high, the first minute is.

---

## 7. Diagnosing the storefront with data

The Acquisition dashboard and thumbnail personalisation give you enough to tell which part of the storefront is failing (rule of thumb readings):

| Pattern | Meaning | Action |
|---|---|---|
| Low impressions, normal play-through | The algorithm is not showing you much yet; per-user signals or audience gates limit retrieval | Work on retention and bounce; check the maturity label and audience ([[Publishing an Experience]]) |
| High impressions, low play-through on every thumbnail | The tile does not promise anything people want, or the icon/title is unclear | New concepts, not new versions of the same concept |
| One thumbnail wins clearly, others near zero | Personalisation working; losers are weak | Replace the weakest with a new idea |
| Play-through rose, playtime per play fell | The new thumbnail over-promises | Retire it; the qualified metric will punish it anyway |
| Good play-through, high 0 to 60 s bounce | Storefront fine; first minute broken | [[First-Time User Experience and Onboarding]] |
| Winning segment is mostly one age group or platform | Your art speaks to that group | Decide whether that is your target; localise or retarget |

Look at at least a week of data per variant; daily traffic swings (weekends, school holidays, time zones) are large on Roblox.

---

## 8. A shoot brief template

Writing a brief before capturing keeps variants meaningfully different. One brief per variant:

```
Variant: B "Rare drop shock"
Promise: you can pull a legendary sword any second
Subject: avatar at 50% frame height, mouth open, looking at a glowing blade
Secondary: rarity banner text from the real UI ("MYTHIC!"), real VFX burst
Background: hub at golden hour, defocused
Colour: gold and violet on dark blue; nothing grey
Text overlay: none (the in-game banner is the text)
Safe zone: nothing important in the bottom 15% or the right-hand corner
Camera: low angle, 35 mm equivalent, avatar left third
Checks: matches real lighting preset; readable at 320x180; no fake UI
```

Variants should differ in the promise line, not just colour: "rare drop shock", "huge boss fight", "friends rolling together", "collection wall". That is how personalisation finds different winners for different audiences.

For the icon, brief one symbol (a single blade, a single creature face, a single die) with a thick outline and two dominant colours, tested at 150x150 against the Home page's background in both light and dark themes.

---

## 9. Description template

```
Roll for legendary swords and fight your way through 10 worlds!

NEW: <update name> - <one concrete line about what is new>

- Roll blades from Common to Mythic and beyond
- Forge, fuse and upgrade your favourites
- Defeat bosses to unlock new worlds
- Trade with friends

Controls: Click/tap to roll, WASD to move, E to interact.
Join our community for codes and events!
```

First line: the core verb and the fantasy. Second line: the freshest reason to play now. Then features as short verb-led lines, controls, and the community pointer. Update the "NEW" line with every update and remove stale claims. Keep claims factual: "10 worlds" must be true for every player who reads it.

---

## 10. Common mistakes
- Shipping with the auto-generated thumbnail (not eligible for Home recommendations).
- Collage thumbnails with ten features at tile size.
- Renders that look better than the game (moderation risk, bounce risk).
- Text near the bottom edge, covered by metadata.
- Burning all three monthly video uploads on cuts with lyric music.
- One thumbnail only (personalisation off).
- Icon unreadable at 150 px.

## 11. Checklist
- [ ] Icon 512x512, tested at 150x150, localised for main locales
- [ ] 2 to 5 custom 16:9 thumbnails at 1920x1080, under 3 MB
- [ ] Nothing critical in the bottom area
- [ ] All media shows real gameplay and real graphics
- [ ] Video (if any) without narration or lyrics
- [ ] Title and description accurate and specific; benefits described honestly
- [ ] Active or upcoming event on the page

## See also
[[Discovery and the Algorithm]] · [[Publishing an Experience]] · [[Live Ops Events and Updates]] · [[Environment Art Styles]] · [[Lighting Mood and Time of Day]] · [[Posing and Silhouettes]] · [[Localization]]

## Connected notes
<!-- auto-links:start -->
[[Click-Through Rate]] · [[Launch Strategy - The First Two Weeks]] · [[Thumbnail Contrast]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[Marketing and Growth Start Here]] · [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]
<!-- auto-links:end -->
