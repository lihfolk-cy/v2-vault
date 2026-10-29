---
tags: [modeling, critique, paintover, feedback, iteration, review, art-direction, workflow, studio, blender, type/guide, area/modeling]
---
# Critiquing a Model - Paintovers and Iteration

<!-- tldr:start -->
> [!tldr] TL;DR
> - Same problems come back every round: Feedback on detail before silhouette -> Critique in the fixed order; stop at the first failing level
> - Modeller unsure what to change: Vague notes ("looks off") -> What, where, why, how much; paintover attached
> - Changes look too timid: Fix applied at half strength -> Exaggerate the paintover slightly
> - Context screenshots: real camera, phone aspect, beside neighbours, real lighting.
> - Critique in order: purpose, silhouette, proportion, value, colour, edges, detail, technical.
> - Three to five must-fix notes, each with what, where, why and how much.
>
> Cost: TL;DR ~190 tok · whole note ~3.7k tok. Read more: ## Paintovers · ## Worked example: critiquing a slime enemy · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most models get better through review, not through the first pass. The difference between a team whose art improves and one whose art goes in circles is usually not talent; it is how feedback is given and used. This note covers a fixed order for critiquing a 3D model (so the biggest problems get fixed first), how to do paintovers on screenshots and in Blender, how to check value structure in Studio, how to write feedback a modeller can act on, how many review rounds to plan, and how to know when to stop. It applies to solo work too: critiquing your own model a day later, with the same method, catches most of what a reviewer would.

## Critique in a fixed order

Feedback on small things before big things wastes work: there is no point polishing a bevel on a shape that will be redesigned. Review in this order and stop at the first level with a real problem.

1. **Purpose and role.** Does the model do its gameplay job? Is it clear what it is and what it does (enemy type, interactable, decoration)? Is it the right size for its role?
2. **Silhouette and primary shape.** Four-view silhouette test at game pixel size, roster comparison. See [[Shape Language and Silhouette Testing]].
3. **Proportions.** Scale against the avatar proxies and golden assets, exaggeration in pairs, readable feature sizes for its distance band. See [[Proportion Exaggeration and Gameplay Distance]].
4. **Value structure.** Two or three clear value groups when desaturated. Does it separate from its background?
5. **Colour.** On palette, right number of colours, accent placed on the focal feature, colour roles consistent with the zone. See [[Zone and Biome Art Direction]].
6. **Edges and surface.** Bevel widths and shading style match the bible; no smoothing errors. See [[Bevels Chamfers and Edge Highlights Without Textures]].
7. **Secondary and tertiary detail.** Detail placed where the camera looks; nothing below pixel size. See [[Spending Triangles Where the Camera Looks]].
8. **Technical.** Triangle ceiling, pivot, scale, naming, UVs, collision, export settings. See [[Exporting and Validating Models for Roblox]].

A reviewer who spots a level 2 problem says so and stops there, adding at most a note like "detail comments next round". The modeller who receives fifteen comments across all levels will fix the easy ones (levels 6 to 8) and leave the hard ones, which is exactly backwards.

## Always critique in context

Judging a model alone in a Blender viewport is the most common source of bad feedback. Before critiquing, get these views:

- **In game, at the real camera.** A screenshot from the player's normal view, at the typical distance, on a phone aspect ratio if the game is phone-heavy. The camera setup in [[Modelling to the Roblox Camera and Player Scale]] gives the numbers.
- **Beside its neighbours.** Golden assets, the existing roster, the props it will stand next to.
- **Under the real lighting**, including the darkest and brightest zones it will appear in, and at a low graphics quality.
- **At thumbnail size.** Shrink the screenshot to the pixel size the asset usually occupies. Many problems only show small, and many non-problems disappear.

## Paintovers

A paintover is a drawing on top of a screenshot that shows the fix instead of describing it. It is usually faster to produce than a paragraph and much less ambiguous. Four kinds, from fastest to slowest:

### 1. Line paintover (2 to 5 minutes)

Draw over the screenshot with a bright, thick line in a contrasting colour: arrows for "lean this", circles for "too small", a new outline where the silhouette should go. Good for silhouette and proportion notes. Keep lines thick; thin lines on a busy screenshot get missed.

### 2. Shape-fill paintover (5 to 10 minutes)

Fill the proposed silhouette with flat grey or black over the screenshot, sometimes beside the original silhouette. Best for primary-shape changes: "make the head this big", "the shoulders should break the outline here".

### 3. Value paintover (10 to 20 minutes)

Desaturate the screenshot, then paint flat greys to show the intended value groups: "top surfaces lighter", "this band darker so the face reads". Untextured art depends on value structure, so this is often the most useful paintover for non-hand-painted styles.

### 4. Colour paintover (15 to 30 minutes)

Paint the proposed colours over the screenshot. Use the palette's exact values (eyedropper from the bible's swatch image) so the modeller is not guessing hex codes from a painted blur.

### Tools

Any 2D painting tool with layers works (Krita is free and widely used; many other tools work as well). Keep the screenshot on the bottom layer, paintover on a layer above, notes on a third. Export a side-by-side image: original on the left, paintover on the right, a short numbered list of changes underneath.

In Blender, two built-in options let you draw directly over the 3D view (Blender manual): the **Annotate** tool in the viewport toolbar, which draws strokes in screen or 3D space without changing the model, and a **Grease Pencil** object, which can be kept in the file as a persistent set of notes. Annotate is quicker for a live review session; a Grease Pencil layer survives in the file for the modeller to see later. Neither changes the mesh, so the modeller keeps control.

### Rules for useful paintovers

- **Paint only the top-priority level.** A paintover that fixes silhouette, colour and detail at once is hard to read.
- **Exaggerate the fix.** Modellers tend to apply about half of a suggested change. A paintover that pushes a little further than needed often lands on the right result.
- **Do not paint detail the model cannot carry.** A paintover full of painted texture detail is useless for an untextured style; show the change as shapes and flat colours only.
- **Number each change** and refer to the numbers in the written notes.

## Value checks in Studio

A desaturated view in the real game is the fastest value test. Studio's `ColorCorrectionEffect` has a `Saturation` property where `-1` gives full desaturation (Roblox docs, as of October 2026). For a review session, add one to `Lighting` in a test place or local copy:

```lua
-- Command bar (Edit mode, review copy only): toggle a greyscale value check.
local Lighting = game:GetService("Lighting")
local NAME = "ValueCheck"

local existing = Lighting:FindFirstChild(NAME)
if existing then
	existing:Destroy()
	print("Value check off")
else
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = NAME
	cc.Saturation = -1 -- full greyscale
	cc.Contrast = 0
	cc.Parent = Lighting
	print("Value check on")
end
```

With the view grey, look for three things:

- **Value groups.** Two or three clear value areas per model. Five similar mid-greys means the model will read as mush.
- **Separation from background.** The model's main value should differ clearly from the ground or sky behind it. If an enemy and the forest floor are the same grey, players will lose track of it in fights.
- **Focal feature contrast.** The focal feature should carry the strongest local contrast: the brightest value next to the darkest, usually.

Remember to remove the effect before publishing. A forgotten greyscale filter in a live place is an embarrassing bug.

## Writing feedback that gets used

A good critique note has four parts: **what**, **where**, **why**, **how much**.

- Weak: "The tree looks off."
- Strong: "1. Crown silhouette (top-down view) is a near-perfect circle and reads as a blob from the follow camera. Split it into 3 overlapping lobes of different sizes, the largest about twice the smallest. See paintover 1."

More rules:

- **Name the level.** "Silhouette note" or "detail note" tells the modeller how big the change is.
- **Separate must-fix from nice-to-have.** Two lists. Nice-to-haves never block a merge.
- **Point to the bible rule** when there is one: "Rule 4 (bevel width 0.15 for medium props); this one has 0.04." This turns taste into fact. See [[Style Bibles for Consistent Models]].
- **Say what works.** Not as padding: if something is right, the modeller needs to know to keep it, or it may get lost in the revision.
- **Limit the count.** Three to five must-fix notes per round. If there are more, the asset needs a bigger rethink, which is a conversation, not a list.

### Receiving feedback

- **Ask for the problem, not only the fix.** A reviewer's fix may not be the best one; the problem they saw is real. "The head looks too small" might be fixed by shrinking the body instead.
- **Do not argue in the first five minutes.** Write the notes down, try the biggest one, then discuss with a new screenshot.
- **Show versions side by side.** Old and new from the same camera, same lighting. Changes are surprisingly hard to judge from memory.

## Planning iteration rounds

A typical prop or character goes through three review checkpoints (rule of thumb):

| Checkpoint | What exists | Review focus | Typical time spent before review |
|---|---|---|---|
| Blockout | Primitives at final scale, grey | Purpose, silhouette, proportions | 15 to 60 minutes |
| Mid pass | Final shapes, rough colour, no bevels | Value, colour, shape grammar | 1 to 4 hours |
| Final | Bevels, detail, export-ready | Edges, detail placement, technical | Rest of the task |

The blockout review is the one teams skip and the one that saves the most time. Changing a silhouette at blockout takes minutes; changing it after bevels, colour and rigging can take a day. Import the blockout into the game and review it there; it takes a few minutes and shows scale and camera problems no Blender view can.

### When to stop

- The model passes every must-fix check and sits next to the golden assets without standing out.
- The remaining notes are nice-to-haves at levels 6 to 8.
- A further round would cost more than the asset's visibility deserves. A background crate gets one round; a hub centrepiece or a boss gets four or five.

"Noodling" (endless small adjustments) usually means the asset has no clear target. Go back to the bible and golden assets, or add a reference image, rather than adding another round.

## Worked example: critiquing a slime enemy

A modeller delivers a mid-pass slime enemy for a swamp zone: a green dome with eyes, about 4 studs tall, 1,800 triangles, flat colour.

1. **Context screenshots.** Place it in the swamp test area. Take screenshots from the follow camera at 15 and 40 studs, on a 2.17 aspect, plus one beside the two other swamp enemies.
2. **Purpose.** It is a basic melee enemy. Clear enough.
3. **Silhouette.** From the high three-quarter view the dome is a smooth semicircle, nearly identical in outline to the swamp's mushroom props. From top-down it is a featureless green circle. **Must-fix 1**: break the outline with a forward lean and a lopsided top lobe so it reads as alive and not as a mushroom cap; add a top feature (a leaf or a drip) for the top-down view. Shape-fill paintover attached.
4. **Proportions.** Eyes are 0.3 studs wide; at 40 studs that is under 4 pixels on a phone, so the facing direction is unreadable. **Must-fix 2**: eyes about 0.7 studs and set wider apart, following the exaggeration table for creature eyes. Line paintover attached.
5. **Value.** Run the Studio value check. The slime's green and the swamp floor's green land at the same grey. **Must-fix 3**: lighten the slime's top half by about 20 percent value and darken the base band so it separates from the ground in fights. Value paintover attached.
6. **Stop there.** Colour accent, bevels and triangle placement get comments next round. One nice-to-have is noted: "a slightly translucent rim would be nice but optional".
7. **Next round.** The modeller sends a side-by-side from the same camera. The silhouette is distinct from the mushrooms, the eyes read at 40 studs, and the greyscale shows clear separation. The review moves on to levels 5 to 8.

Three must-fix notes, three paintovers, about 25 minutes of review. The same feedback as an unordered list of twelve comments would likely have produced a polished slime that still looked like a mushroom.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Same problems come back every round | Feedback on detail before silhouette | Critique in the fixed order; stop at the first failing level |
| Modeller unsure what to change | Vague notes ("looks off") | What, where, why, how much; paintover attached |
| Changes look too timid | Fix applied at half strength | Exaggerate the paintover slightly |
| Asset looks great in review, bad in game | Reviewed in Blender only | Review in-game screenshots at real camera and lighting |
| Endless rounds | No clear target or stop rule | Golden assets, must-fix vs nice-to-have, round limit by visibility |
| Silhouette changes late and expensively | No blockout review | Review and import the blockout before detail work |
| Greyscale filter left in the place | Value check not removed | Run the toggle again; check `Lighting` before publishing |

## Checklist

- [ ] Context screenshots: real camera, phone aspect, beside neighbours, real lighting.
- [ ] Critique in order: purpose, silhouette, proportion, value, colour, edges, detail, technical.
- [ ] Three to five must-fix notes, each with what, where, why and how much.
- [ ] Paintover for each must-fix, at its level only.
- [ ] Value check in Studio; removed afterwards.
- [ ] Bible rules cited where they apply.
- [ ] Side-by-side old and new from the same camera.
- [ ] Round count matched to the asset's visibility.

## Related

- [[Modeling Fundamentals for Games]]
- [[Matching a Concept Sheet - Boss Creature Case Study]]
- [[Zone and Biome Art Direction]]
- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Art Pipeline - Concept to In-Game Asset]]
- [[Exporting and Validating Models for Roblox]]
- [[Shape Language and Silhouette Testing]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Bevels Chamfers and Edge Highlights Without Textures]]
- [[Spending Triangles Where the Camera Looks]]
- [[Style Bibles for Consistent Models]]
- [[Modelling Nuance Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Colour Scripts and Value Structure for Untextured Art]] · Untextured Stylised Modelling Start Here · Low-Poly and Stylized Modeling · Keeping a Mixed Asset Library Consistent · Colour-Blind Safe Design · Voxel Palettes - Ramps Hue Shifting and Limits
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Art-Direction Nitpicks - The Principles Behind Them]] · [[Low-Poly and Stylized Modeling]] · [[Keeping a Mixed Asset Library Consistent]] · [[The Gradient Palette Texture Workflow]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]]
<!-- related:end -->
