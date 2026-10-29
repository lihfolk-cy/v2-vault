---
tags: [marketing, thumbnails, composition, contrast, readability, colour, art-direction, ctr, type/guide, area/marketing, level/intermediate, area/gameplay]
---
# Thumbnail Composition for High CTR - Focal Point, Contrast and Readability

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: a wide establishing shot of the map.
> - Avoid: five characters in a line. Symptom: no face is big enough to read an emotion.
> - Avoid: saturated everything. Symptom: subject and background have the same intensity; nothing pops.
> - One focal subject at roughly 30 to 45 % of the frame, on a thirds point.
> - Readable face with an emotion that matches the promise.
> - Greyscale test passes; subject separated by value, then colour, then rim light.
>
> Cost: TL;DR ~150 tok · whole note ~2.9k tok. Read more: ## 2. One focal subject · ## 4. Separation: value first, then colour, then light · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Roblox thumbnail is judged in well under a second, on a phone, in a scrolling row of other bright tiles, mostly by young players. This note is a set of composition rules that survive those conditions: one focal subject, a face with an emotion, strong value contrast, a hard limit on elements, sparing text and a safe area. It assumes the specs in [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] and complements the icon-specific craft in [[Game Icon Design - Readable at Small Sizes]], the contrast concept in [[Thumbnail Contrast]] and the value-planning method in [[Colour Scripts and Value Structure for Untextured Art]]. Posing and silhouettes are in [[Posing and Silhouettes]] and [[Shape Language and Silhouette Testing]]. Hub: [[Thumbnails and CTR Start Here]].

Labels: **Roblox docs**, **Rule of thumb** (all numbers in this note are LihFolk practice unless marked otherwise), **Unverified**.

---

## 1. The one-second read

At tile size a player's eye does three things in order:
1. **Finds the brightest, most contrasted shape** (usually a face, a glow or a big number).
2. **Reads its emotion or action** (scared, triumphant, running, holding something).
3. **Guesses the genre and the promise** from colour mood and the second element.

Design for that order. If step 1 lands on a background prop, the thumbnail has failed before the player knows what the game is.

Roblox's own guidance points the same way: use unique, relevant imagery of what players will find, and let colour express the theme, for example bright and saturated for fantasy, muted for sombre settings, heavy contrast for horror (**Roblox docs**, https://create.roblox.com/docs/production/promotion/thumbnails and https://create.roblox.com/docs/production/promotion/game-icons).

---

## 2. One focal subject

- **One hero.** One character, creature, item or number carries the image. Everything else supports it.
- **Size:** the focal subject should cover roughly **30 to 45 % of the frame area** in a 16:9 thumbnail (Rule of thumb). Below about 20 % it becomes a detail; above about 60 % you lose the context that tells the genre. Icons use more fill (60 to 80 %, see the icon note).
- **Placement:** put the subject's face or key point on a **rule-of-thirds intersection**, usually the left or right third, upper half. Dead centre works for symmetrical "boss" shots.
- **Look direction:** have the subject look or move **into** the frame, toward the secondary element. A character looking off the edge pulls the eye out of the tile.
- **Crop for scale.** Let a big subject break the frame edge (a monster's head cut by the top edge reads as "too big to fit"). Never crop through a face's eyes.

### Faces and emotion
- A readable face is the fastest signal on Roblox. Avatars' default faces are small; use an **expressive face asset, a dynamic head, or a camera close enough that the face is at least about 8 to 10 % of frame height**.
- Pick the emotion that matches the promise: shock or awe (rare drop, giant reveal), fear (horror, chase), determination (combat), joy (social, pets), mischief (troll, steal games).
- **Eyes toward the viewer or toward the prize.** Both work; eyes toward nothing do not.

---

## 3. Scale contrast

The cheapest way to sell spectacle is a **small thing next to a big thing**: a tiny avatar in front of a towering wave, a boss, a mountain of coins, a huge fish. The size ratio carries the message "this game has something enormous".

- Aim for a ratio of **at least 1:4** between the small and big subject's heights (Rule of thumb).
- Keep the small subject readable: if the avatar is tiny, give it a strong silhouette, a bright outfit colour or a rim light.
- The big subject can be partly out of frame; the eye fills in the rest.

---

## 4. Separation: value first, then colour, then light

### Value contrast
- Convert the thumbnail to greyscale. The focal subject should separate from its surroundings by **at least about 30 to 40 points on a 0 to 100 lightness scale** (Rule of thumb). If it does not, no amount of saturation will save it.
- Plan values as three groups: **light subject, mid background, dark frame edges** (or the inverse for horror: bright eyes in a dark frame).
- A gentle **vignette** (edges 10 to 20 % darker) pushes attention to the centre.

### Colour
- **Saturated subject, calmer background.** The subject owns the most saturated colour in the image.
- Use a **complementary pair** for subject and background (orange on blue, magenta on green, gold on violet).
- Check the genre crowd: if every competitor tile is green and yellow, a cool palette stands out in the row ([[Competitor Analysis Method]], [[Thumbnail Genre Patterns - What Top Games Show]]).

### Rim light and outline
- A **rim light** in a contrasting colour behind the subject cuts it out of any background. In Studio this is a bright light behind and above the subject, or the subject placed against a bright sky (see [[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]]).
- A soft dark **contact shadow** or ground glow anchors the subject so it does not look pasted on.
- Thick graphic outlines suit flat or toon styles; if the game is realistic, prefer light-based separation so the art still matches the game.

---

## 5. The three-element limit

At tile size a thumbnail can carry about **three readable elements** (Rule of thumb):

1. **Focal subject** (hero, 30 to 45 % of the frame).
2. **Secondary element** that explains the promise (the prize, the threat, the place).
3. **Optional brand or text** (logo or two to three words).

Everything else becomes background texture: blurred, darker, less saturated. A collage of six features turns into noise at 320 x 180. If you want to sell six features, make six thumbnails and let personalisation decide.

---

## 6. Text: when and how

Docs guidance for video overlays is that text should be sparing and describe gameplay only, with no promotional or subjective claims (**Roblox docs**, thumbnails page). Treat stills the same way.

| Use text when | Skip text when |
|---|---|
| The number *is* the dream (income per second, a level, a multiplier) | The image already says it |
| A real in-game label is the payoff ("MYTHIC" rarity banner from your UI) | You are tempted to write "UPDATE", "NEW!!", "FREE", "OP" |
| A two- or three-word verb phrase clarifies an unusual mechanic | The text would sit in the bottom 20 % |

How (Rule of thumb):
- **Two to three words**, heavy font, cap height **at least 8 to 10 % of image height** (about 90 to 110 px at 1080 p).
- **Outline or drop shadow** in the darkest value of the image, 6 to 10 px at 1080 p.
- **Top third or side third**, away from the bottom edge where metadata can cover it (**Roblox docs**).
- Prefer showing your **real in-game UI text** at a large scale over inventing a headline; it is truthful and on-brand.
- Text needs localising; a text-free image works everywhere ([[Localization]]).

---

## 7. Safe areas for every surface

| Zone | Rule (Rule of thumb unless marked) |
|---|---|
| Bottom 15 to 20 % | Nothing essential; player count and metadata can cover it (**Roblox docs**) |
| Corners (about 5 % inset) | Nothing essential; rounding and badges differ by platform |
| Centre 80 % width x 70 % height | All three elements live here |
| Whole frame | Must still make sense if displayed slightly smaller or with a different corner radius |

Make a 1920 x 1080 overlay template with these guides as a separate layer in your image editor and turn it on for every export.

---

## 8. Readability testing

- **Test sizes:** view every candidate at **320 x 180** (a typical phone tile, roughly) and **160 x 90** (worst case), plus the icon at 150, 100, 64 and 48 px (Rule of thumb). On desktop, a 150 to 200 px-wide preview is the honest test.
- **Greyscale test:** subject still pops in black and white.
- **Squint or blur test:** blur the image by about 1 % of its width; the focal subject and the promise should still read.
- **Row test:** paste the candidate into a mock row of current top tiles in your genre at the same size. It should be the one your eye lands on, or at least not the one it skips.
- **Stranger test:** show it for one second to someone who has not seen the game and ask "what do you do in this game?". Two different correct answers is fine; "I don't know" is a fail.
- Real phone, real brightness. Thumbnails viewed at night on low brightness lose dark detail; keep the hero above mid-grey.

---

## 9. Consistency with the icon and the game

- **Shared anchors:** same hero character or creature, same dominant two colours, same logo shape. A player who saw the thumbnail on Home should recognise the icon in Search.
- **Same art style as the game.** If the game is low-poly toon, the thumbnail is low-poly toon, staged and lit well. A painted illustration of a low-poly game raises clicks and bounce together ([[Thumbnails Icons and Store Page]]).
- **A template, not a one-off.** Fix composition, logo position and hero slot so seasonal or update versions are quick variations ([[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]).

---

## 10. Avoiding clutter: a subtraction pass

Before export, remove in this order until the image reads at 320 x 180:
1. Extra characters beyond two.
2. Floating icons, arrows, emojis and stickers.
3. Background props competing in brightness with the hero.
4. Particles that cross the face.
5. Any text that is not the payoff.

If it still does not read, the shot is wrong, not the decoration: move the camera closer.

---

## Common mistakes

- Avoid: a wide establishing shot of the map. Symptom: at tile size it is green-and-grey noise with no subject.
- Avoid: five characters in a line. Symptom: no face is big enough to read an emotion.
- Avoid: saturated everything. Symptom: subject and background have the same intensity; nothing pops.
- Avoid: thin fonts or long sentences. Symptom: text turns into a smudge on phones.
- Avoid: red arrows and circles pointing at things. Symptom: clutter, and a cheap look that does not match the game.
- Avoid: thumbnail style far beyond the game. Symptom: higher qPTR, lower average playtime per qualified play.
- Avoid: the hook in the bottom strip. Symptom: covered by the player count.

## Checklist

- [ ] One focal subject at roughly 30 to 45 % of the frame, on a thirds point.
- [ ] Readable face with an emotion that matches the promise.
- [ ] Greyscale test passes; subject separated by value, then colour, then rim light.
- [ ] Three elements or fewer; background softened.
- [ ] Text two to three words, large, outlined, in the top or side third, or none.
- [ ] Safe-area overlay checked: bottom 15 to 20 % and corners clear.
- [ ] Tested at 320 x 180 and 160 x 90, in a competitor row, by a stranger.
- [ ] Hero, palette and style consistent with the icon and the real game.

<!-- related:start -->
## Related
[[Thumbnail Review Checklist and Scoring Rubric]] · [[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]] · [[Click-Through Rate]] · [[World Composition and Set Dressing - Designed, Not Scattered]] · [[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]] · [[Stylized Lighting Recipes]]
<!-- related:end -->
