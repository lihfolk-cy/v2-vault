---
tags: [marketing, thumbnails, icons, review, rubric, scoring, checklist, ai-review, ctr, type/reference, area/marketing, level/intermediate]
---
# Thumbnail Review Checklist and Scoring Rubric

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: reviewing only the full-size image.
> - Avoid: skipping the gates because the score is high.
> - Avoid: letting the AI reviewer judge truthfulness without in-game screenshots.
> - Full, small, greyscale versions, icon and in-game screenshots provided.
> - G1 and G2 checked first; any fail blocks upload.
> - Ten criteria scored 0, 0.5 or 1 with the definitions above.
>
> Cost: TL;DR ~130 tok · whole note ~2.3k tok. Read more: ## 3. The ten scored criteria · ## 5. Prompt for an AI reviewer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A fixed rubric makes thumbnail reviews faster and less about taste: ten criteria, each scored 0, 0.5 or 1, with two hard gates for truthfulness and policy. It is written so a human or an AI reviewer can apply it the same way and return a structured result. The criteria condense [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]], [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] and [[Thumbnail Genre Patterns - What Top Games Show]]; icons have their own checks in [[Game Icon Design - Readable at Small Sizes]]. A good score predicts a thumbnail worth testing, not a winner: only live data decides that ([[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]]). Hub: [[Thumbnails and CTR Start Here]].

Labels: the rubric itself is **Rule of thumb**; platform rules referenced are **Roblox docs** (https://create.roblox.com/docs/production/promotion/thumbnails, https://create.roblox.com/docs/production/promotion/discovery) and the Community Standards (https://about.roblox.com/community-standards).

---

## 1. Inputs the reviewer needs

1. The thumbnail at full size (1920 x 1080).
2. The same image downscaled to **320 x 180** and **160 x 90**.
3. A greyscale version.
4. The current icon.
5. Two or three raw in-game screenshots of the content shown.
6. One line: genre and the promise the thumbnail is meant to sell.
7. Optional: a row of 6 to 10 current competitor tiles at 320 x 180 (for criterion 9).

Without input 5, criterion G1 cannot be judged; the reviewer must say so rather than guess.

---

## 2. Hard gates (pass or fail)

| Gate | Pass when | Fail examples |
|---|---|---|
| **G1 Truthful** | Every character, item, place, effect, number and UI element exists in the game; art style matches the game | Monster not in game; painted art for a low-poly game; fake rarity banner |
| **G2 Policy-safe** | No off-platform links, handles or QR codes; no Robux or discount claims; no promotional or subjective claims; fits the maturity label; no other game's characters or branding | "FREE ROBUX"; Discord tag; "50% OFF"; meme characters owned by others |

Any gate failure means **do not upload**, whatever the score. Basis: imagery should show what players will find (Roblox docs); misleading, deceptive or duplicative metadata and directing users off-platform are prohibited (Community Standards); promotional claims are not allowed in video thumbnails and should be avoided in stills (Roblox docs).

---

## 3. The ten scored criteria

Score each 0 (fails), 0.5 (partly) or 1 (clearly meets). Total out of 10.

| # | Criterion | 1 point when | 0.5 when | 0 when |
|---|---|---|---|---|
| 1 | **Focal subject** | One clear hero, about 30 to 45 % of frame, on a thirds point or deliberate centre | Hero clear but too small or too large | No clear hero; scene or collage |
| 2 | **Small-size readability** | At 320 x 180 the hero and the promise read; at 160 x 90 the hero still reads | Readable at 320 x 180 only | Unreadable at 320 x 180 |
| 3 | **Value contrast** | Greyscale: hero clearly separates from background; edges darker or lighter than centre as planned | Separation weak in one area | Hero merges with background in greyscale |
| 4 | **Genre clarity** | A player of the genre would name it in one second from palette, subject and situation | Genre guessable but ambiguous | Wrong or no genre signal |
| 5 | **Emotion and action** | A readable face with an emotion matching the promise, or a clear action in progress | Emotion or action present but small | Neutral idle pose, no action |
| 6 | **Text discipline** | No text, or two to three large outlined words that are the payoff | Text readable but redundant or slightly long | Long or thin text, update spam, or text that is unreadable small |
| 7 | **Safe area** | Nothing essential in the bottom 15 to 20 % or corners | Minor element near an edge | Hook or text in the bottom strip or a corner |
| 8 | **Brand consistency** | Shares hero, palette or logo with the icon and other thumbnails | Loosely related | Looks like a different game |
| 9 | **Novelty in the row** | Stands out among competitor tiles (palette, subject or situation) while keeping genre cues | Blends in but is clean | Indistinguishable from or a near-copy of a competitor |
| 10 | **Clutter control** | Three elements or fewer; background softened; no stickers, arrows or emojis | Four or five elements, still legible | Busy; eye has nowhere to land |

### Score bands

| Total | Verdict |
|---|---|
| 8.5 to 10 | Upload as a challenger |
| 7 to 8 | Fix the lowest-scoring criterion, then upload |
| 5 to 6.5 | Re-shoot: usually camera distance, lighting or subject choice |
| Below 5 | New concept |

The bands match LihFolk's 8.5 quality bar for shipped work.

---

## 4. Fix guide by criterion

| Low score on | Usual fix |
|---|---|
| 1 Focal subject | Move the camera closer; remove secondary characters |
| 2 Readability | Bigger hero, simpler background, depth of field |
| 3 Contrast | Rim light, darker or brighter background, vignette |
| 4 Genre clarity | Add one genre cue (palette, situation, signature object) |
| 5 Emotion | Expressive face, stronger pose, closer crop on the face |
| 6 Text | Delete it, or cut to two words at 8 to 10 % of image height |
| 7 Safe area | Shift the composition up; move text to the top third |
| 8 Brand | Reuse the icon's hero or the two brand colours |
| 9 Novelty | Change palette or show the game's unique twist object |
| 10 Clutter | Subtraction pass: extras, stickers, competing props, particles over faces |

Production fixes are in [[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]].

---

## 5. Prompt for an AI reviewer

Use with an image-capable model. Supply the inputs from section 1.

```
You are reviewing a Roblox experience thumbnail for a 16:9 Home tile.
Genre and promise: <one line>.
You have: full-size image, 320x180 and 160x90 versions, greyscale version,
the icon, and in-game screenshots of the content shown.

1. Hard gates. G1 Truthful: does every element exist in the in-game screenshots,
   in the same art style? G2 Policy-safe: any off-platform links or handles,
   Robux or discount claims, promotional claims, content above the maturity
   label, or other games' characters or branding? If you cannot verify G1
   from the screenshots provided, answer "unknown" and say what is missing.
2. Score criteria 1-10 with 0, 0.5 or 1 each, using the rubric definitions.
   Judge readability only from the small versions.
3. For each criterion below 1, give one concrete fix.
Return JSON only, in this shape.
```

```json
{
  "gates": { "G1_truthful": "pass|fail|unknown", "G2_policy": "pass|fail", "gate_notes": "" },
  "scores": {
    "focal_subject": 1, "small_size_readability": 0.5, "value_contrast": 1,
    "genre_clarity": 1, "emotion_action": 0.5, "text_discipline": 1,
    "safe_area": 1, "brand_consistency": 0.5, "novelty": 0.5, "clutter_control": 1
  },
  "total": 8.0,
  "verdict": "upload|fix_then_upload|reshoot|new_concept|blocked_by_gate",
  "fixes": [ { "criterion": "small_size_readability", "fix": "" } ]
}
```

Reviewer rules: the verdict is `blocked_by_gate` if any gate fails; if G1 is `unknown`, the verdict cannot be `upload`. Scores describe the image, not the game's quality.

---

## 6. Using scores over time

- Log each uploaded thumbnail's score next to its live qPTR and average playtime per qualified play.
- After 10 to 20 thumbnails, check which criteria actually track your qPTR. Weight those higher for your game.
- A high-scoring thumbnail that loses live is still information: it usually means the promise, not the craft, was wrong. Change the idea, not the polish.

---

## Common mistakes

- Avoid: reviewing only the full-size image. Symptom: high scores for detail no player can see.
- Avoid: skipping the gates because the score is high. Symptom: rejected uploads or a misleading tile that raises bounce.
- Avoid: letting the AI reviewer judge truthfulness without in-game screenshots. Symptom: confident passes on invented content.
- Avoid: treating the score as a prediction of qPTR. Symptom: surprise when a 9 loses to a 7 with a better promise.
- Avoid: averaging reviewers' opinions without the rubric. Symptom: endless taste debates.

## Checklist

- [ ] Full, small, greyscale versions, icon and in-game screenshots provided.
- [ ] G1 and G2 checked first; any fail blocks upload.
- [ ] Ten criteria scored 0, 0.5 or 1 with the definitions above.
- [ ] Verdict taken from the score bands.
- [ ] Fixes listed for every criterion under 1.
- [ ] Score logged next to live qPTR and playtime after upload.

<!-- related:start -->
## Related
[[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]] · [[Blind Review Scores - Noise, Panels and Shipping the Best Version]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Thumbnails Icons and Store Page]] · [[Thumbnail Contrast]] · [[Case Study - Building LihFolk V2 with AI Agents]]
<!-- related:end -->
