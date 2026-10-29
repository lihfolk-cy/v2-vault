---
tags: [modeling, critique, art-direction, feedback, readability, silhouette, shape-language, value, hierarchy, transitions, iteration, voxel, low-poly]
---
# Art-Direction Nitpicks - The Principles Behind Them

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Fixing the named spot only, instead of the principle across the whole model.
> - Avoid: Decorating a borrowed primary mass instead of rebuilding it in the identity's shape vocabulary.
> - Avoid: A count or placement of protrusions near a face that reads as ears or a mohawk.
> - Each nitpick mapped to a principle and fixed model-wide.
> - The primary mass alone reads as the intended identity.
> - Protrusions near a face read as the intended features (or as one ring, not as features).
>
> Cost: TL;DR ~160 tok · whole note ~3.1k tok. Read more: ## 12. Briefs describe symptoms; the image they liked is the truth · ## Worked example: the voxel flower boss · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A reviewer's nitpicks are symptoms. "It looks like a dragon head on a stick", "the petals are paddles", "the teeth look like a cage": each names something the eye noticed, not the rule that was broken. Fixing only the named symptom tends to bring the next nitpick. This note studies one long series of nitpicks (six briefs on a voxel boss model, with blind-review panels) and extracts the **perception principles** underneath them. The principles apply to models in general: creatures, characters, props and buildings, in any style. The original case is the worked example at the end.

Label: **Field notes + rule of thumb** (one project studied in depth; the principles agree with standard art-direction practice, see [[Shape Language and Silhouette Testing]]).

## How to use this note

1. When feedback arrives, map each nitpick to the principle below that explains it.
2. Fix the principle across the **whole model**, not just the one named spot, because the same violation usually exists elsewhere.
3. Check the fix doesn't break what the reviewer already liked (principle 12).

## 1. The primary mass decides what the thing is

*Nitpick it explains:* "a dragon head mounted on a stem", "a demon head with petals attached".

The eye classifies an object by its largest mass and, if there is one, its face. Decoration added afterwards cannot override that first read. A strongly recognisable shape (a snout plus a heavy brow, a generic sword blade, a plain box house) carries its own category with it.

- Decide which part carries the identity, and build **that part** out of the identity's own shape vocabulary. A flower monster's head is a blossom; a magic sword's blade shape is itself magical; a haunted house's roofline sags.
- Remove borrowed cues from the primary mass (an animal snout on a plant, a realistic blade on a toy weapon) before adding anything.
- Test: cover the secondary parts. What does the remaining mass read as?

## 2. Anything near a face becomes a facial feature

*Nitpicks:* "a single vertical mohawk petal and two symmetrical ears".

People read faces into everything (pareidolia). Protrusions near a face get read as face parts by **count and placement**. One on the centreline reads as a crest or mohawk; a symmetric pair reads as ears or horns; a ring of five or more reads as one system (a mane, petals, a frill).

- The problem is not symmetry itself. It is a count and placement that matches a known face layout.
- Want a frame, not features? Use a ring of 5-7 parts, layered and overlapping so they read as one shape.
- Want ears or horns? Then use exactly the pair, on purpose.

## 3. Taper says "grown"; uniform width says "made"

*Nitpicks:* "petals are blunt paddles", "teeth are columns", "thin horizontal leaves".

A shape that is broad at its base and tapers steadily to a point reads as grown, sharp and directional. A shape of constant width with rounded ends reads as manufactured, soft and inert.

- Organic parts (petals, leaves, flames, hair clumps, claws, spikes, tails, capes): put the widest point at about 30-40% of the length and taper to a point.
- Hard-surface parts may be uniform on purpose, but the taper still tells the eye which end is the root and which is the business end.
- In voxels the taper has to survive the grid. Keep the tip at least 1 voxel and check that it doesn't break into loose cubes.

## 4. Quality comes from decisions, not density

*Nitpicks:* "do not interpret higher quality as adding more cubes", "a noisy cluster", "looks procedurally assembled from random cubes".

Detail without hierarchy reads as noise. A model looks expensive when it has a few large, confident shapes, some medium shapes that explain the large ones, and small detail only where it means something.

- Before adding detail, ask: which big shape is unclear? Fix that shape instead.
- Ten small blades read as a ragged fringe; five large ones read as design.
- One consistent detail scale (voxel size, bevel width) across the model. Mixed scales look kitbashed.

## 5. Value decides where the eye goes

*Nitpicks:* "keep the mouth dark enough for strong contrast", "bright eyes as the primary focal point", "horns and teeth as secondary accents".

The eye goes first to the highest contrast, then the next. Every bright accent competes with the focal point.

- Pick the order: focal point (usually the eyes or the weapon's business end), secondary accents, then everything else.
- Put the darkest dark next to the brightest bright at the focal point (a deep cavity behind teeth, a dark socket around a glowing eye).
- Shade within one hue family (crimson -> burgundy -> near-black) for depth. More hues just add competing accents.
- If a secondary accent (ivory, gold, neon) has more area than the focal point, shrink it.

## 6. Even repetition reads as manufactured

*Nitpicks:* "the teeth look like a rectangular cage", "vary the lengths and angles", "introduce subtle asymmetry to make it feel alive".

Equal parts at equal spacing read as a fence, a grille or a comb. Perfect mirror symmetry reads as dead or placeholder.

- Vary repeated parts in a **hierarchy**: a few big ones at the important positions (fangs at the corners), many smaller uneven ones between. That is not random noise.
- Keep asymmetry subtle (roughly 5-15% in size, angle or position): one brow steeper, one fang longer. Heavy asymmetry reads as broken.

## 7. Models look assembled at the joints

*Nitpicks:* "cheek blob", "head into stem should be a natural transition", "roots should grow from the stem and grip the stone", "leaves attach naturally".

Where two parts meet is where viewers see "parts". Every junction needs a transition device:

- a **collar** (sepals, fur ruff, armour plate, a sword's guard);
- a **flare or fillet** (a trunk widening into roots, a limb thickening into the body);
- an **overlap or wrap** (roots gripping a rock, a strap wrapping a handle).

Test: list every junction and name its device. A junction without one is a seam.

## 8. Support must look able to carry the load

*Nitpicks:* "thicker stem", "increase the leaves' volume to balance the massive head", "the stone must anchor the character".

The eye judges weight. A heavy top on a thin support looks fragile or toy-like; an object without a heavy enough base looks like it floats.

- Thicken supports toward the load (a stem thickest under the head, a tower thickest at the base).
- Balance a heavy mass with secondary volumes (leaves, arms, a cape) so the silhouette doesn't feel top-heavy.
- Ground it: a base, roots or feet with visible weight and contact.

## 9. Each part type needs its own shape signature

*Nitpick:* thin roots were read as "extra leaves".

If two part types share thickness, colour and direction, viewers confuse them. Give each type a distinct signature, such as thick vs thin, pointed vs blunt, light vs dark, or up vs down. Roots should be thicker and darker than leaves; trim should be different in profile from the wall.

## 10. It must read from every angle

*Nitpicks:* "petals are radial from the front but a flat fan from the side", "evaluate front, three-quarter, side and rear".

Most problems show from only one angle: a fan that is flat from the side, a head on a stick from the side, a hollow back from the rear. Render front, 3/4, side and rear every round, and judge the silhouette in each.

## 11. Artifacts the user sees are real

*Nitpick:* "the strokes are bad, you haven't noticed?"

Heavy outline or part lines read as cracks or seams. If the preview shows an artifact, either fix it or prove it is absent in the game. Don't explain it away. Users lose trust faster over an ignored artifact than over a weak shape.

## 12. Briefs describe symptoms; the image they liked is the truth

*Lesson from the case:* the brief said "remove the vertical mohawk petal". The version the user later picked as good **had** a top petal, but a broad, rounded one that was part of a ring. A full recomposition that literally followed every brief item was rejected, and the model was reverted.

- Read each brief item as "reduce this symptom", not "delete this element". The mohawk complaint was about a thin, isolated spike, not about having a top petal at all.
- When the user marks a version as good, **lock it**. Later nitpicks are refinements to that version, not a licence to redesign.
- Save every version as a file, and show the before and after.
- Rubric scores and user taste can disagree (the liked version scored 7.7 against its brief). When they conflict, the user's choice wins; record why.
- Nitpicks that get smaller and more specific each round mean the base is close. Make small, targeted edits.

## When not to apply a principle

- The game's style bible or the brief deliberately wants the opposite (a cute pet with rounded stubby teeth, a perfectly symmetric emblem, a deliberately dragon-like dragon).
- Hard-surface and architectural pieces use principles 3 and 6 lightly: uniform repetition can be correct for a fence or a brick course.
- Tiny props seen at a distance: principles 4, 5 and 10 still apply; the fine points of 6-7 rarely show.

## Worked example: the voxel flower boss

| Nitpick (user's words, paraphrased) | Principle | Fix that worked |
|---|---|---|
| Dragon or demon head on a plant stem | 1 | Shorter snout, cheeks blended in, petals built around the head |
| Mohawk petal and two ears | 2, 12 | 7 layered petals in a ring; kept a broad top petal |
| Petals as paddles; noisy cluster | 3, 4 | Fewer, larger petals, broad base tapering to a point |
| Teeth as a rectangular cage | 6, 5 | Varied tapered fangs, small teeth between, deeper dark cavity |
| Eyes must stay the focal point | 5 | Recessed sockets, glow, ivory kept secondary |
| Head to stem transition | 7 | A collar of dark-green sepals |
| Thin stem and leaves vs a massive head | 8 | Thicker upper stem, broader leaves |
| Roots read as leaves | 9 | Thick dark roots that grip the stone |
| Flat fan from the side | 10 | Checked the side and rear views every round |
| "The strokes are bad" | 11 | Part lines removed from the render |
| A recomposition was rejected | 12 | Reverted to the liked version and locked it |

## Common mistakes

- Fixing the named spot only, instead of the principle across the whole model.
- Decorating a borrowed primary mass instead of rebuilding it in the identity's shape vocabulary.
- A count or placement of protrusions near a face that reads as ears or a mohawk.
- Uniform-width, round-ended organic parts; evenly repeated identical parts.
- Adding detail or cubes to "raise quality".
- Bright accents competing with the focal point.
- Junctions without a transition device; supports too thin for the load.
- Checking only the front view; explaining away visible artifacts.
- Following brief wording literally and redesigning a version the user already liked.

## Checklist

- Each nitpick mapped to a principle and fixed model-wide.
- The primary mass alone reads as the intended identity.
- Protrusions near a face read as the intended features (or as one ring, not as features).
- Organic parts taper from a broad base; repeated parts vary in a hierarchy; subtle asymmetry.
- Few large shapes, one detail scale, no noise clusters.
- Value order set: focal point darkest-dark against brightest-bright, accents secondary.
- Every junction has a collar, flare or wrap; supports carry the load; the model is grounded.
- Part types have distinct signatures.
- Front, 3/4, side and rear checked; no visible artifacts.
- The liked version locked and every version saved.

## Related

- [[Critiquing a Model - Paintovers and Iteration]]
- [[Shape Language and Silhouette Testing]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Style Bibles for Consistent Models]]
- [[Organic and Creature Modeling]]
- [[Voxel Shading - Baked AO Edges and Lighting]]

<!-- related:start -->
## Related
[[Spending Triangles Where the Camera Looks]] · [[Matching a Concept Sheet - Boss Creature Case Study]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Chibi Character Rules in Practice]] · [[Voxel and Blocky Modeling]] · [[Modelling to the Roblox Camera and Player Scale]]
<!-- related:end -->
