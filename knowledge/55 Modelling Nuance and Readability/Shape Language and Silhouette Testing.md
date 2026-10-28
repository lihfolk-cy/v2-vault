---
tags: [modeling, shape-language, silhouette, readability, art-direction, blender, studio, critique]
---
# Shape Language and Silhouette Testing

[[Low-Poly and Stylized Modeling]] gives the one-line version of shape language (circles friendly, squares stable, triangles dangerous) and [[Modeling Fundamentals for Games]] gives the black silhouette test. This note goes past both. It covers how to build a shape hierarchy that survives a phone screen, how negative space and tangents make or break a silhouette, why one silhouette test is not enough on Roblox (the camera looks down, not across), how to test a whole roster at once instead of one model at a time, and how to run the test inside Studio under the game's real lighting. The focus is non-hand-painted art, where the silhouette and the big colour shapes are almost the whole look, because there is no painted detail to rescue a weak shape.

## Why shape matters more on Roblox than in most engines

Three things push Roblox art toward shape-first design.

1. **Small screens and far cameras.** A large share of Roblox play is on phones (rule of thumb; Roblox does not publish an exact current split by device). A 5-stud character seen from the default follow camera fills only a fraction of a 6-inch screen, and enemies 40 studs away are a few dozen pixels tall. The pixel maths is in [[Modelling to the Roblox Camera and Player Scale]].
2. **Lighting that varies by player.** Graphics quality settings change shadow and post-processing detail on the client (Roblox docs describe the quality slider; exact per-level behaviour is not fully documented). Surface shading that reads at quality 10 can flatten at quality 1. The outline never changes.
3. **Mixed avatars beside your art.** Every player brings their own avatar style, colours and accessories. Your models must stay recognisable next to a neon-pink layered-clothing avatar. Shape and value contrast do that; texture detail does not.

So the order of priorities for every model is: silhouette, then big value groups, then colour, then surface detail. A model that fails the first step is not fixed by any later one.

## The shape hierarchy: primary, secondary, tertiary

Every readable model has three levels of shape. Concept artists call them big, medium and small (rule of thumb, used widely in game art training).

- **Primary shape**: the one mass you would draw with a single stroke. A mushroom house is a dome on a cylinder. A golem is a wide wedge. It decides the read at 30 studs and beyond.
- **Secondary shapes**: the 2 to 5 masses attached to the primary: arms, a chimney, a door, a shoulder plate. They decide what kind of thing it is at 10 to 30 studs.
- **Tertiary shapes**: trims, bolts, rivets, small ridges, eyes. They only read up close, and on Roblox they are often invisible in play.

A useful ratio (rule of thumb) is about 60 to 70 percent of the silhouette area in the primary, 20 to 30 percent in secondaries, and under 10 percent in tertiaries. When tertiaries creep past about 15 percent, the model looks noisy at distance: the small bumps alias into a fuzzy edge and the primary shape stops reading.

### Size contrast between levels

Each level should be clearly smaller than the one above, by about a factor of 2 to 3 in its longest dimension (rule of thumb). Equal-sized parts are the most common reason a model looks "designed by committee". If a robot's head, chest and fists are all the same size, nothing leads the eye. Make the chest 3 times the head, the fists 1.5 times the head, and the robot gets a character instantly.

### Big, medium, small applied to non-hand-painted art

Without painted texture, the tertiary level carries less information than in a hand-painted game. That changes the budget:

- Move detail **up** a level. A painted game draws a belt buckle; an untextured game models it as a thick secondary block in a contrasting colour.
- Put the detail into **colour blocks**, not modelled bumps. A flat-coloured stripe costs no triangles and reads further than a 0.05-stud ridge.
- Keep tertiaries where the camera gets close: the player's own tool, a shop counter, a pet in an inspect view. See [[Spending Triangles Where the Camera Looks]].

## Beyond circles, squares and triangles

The basic emotional mapping is a starting point, not a rule set. Professional shape design adds four ideas.

### 1. Dominant shape plus a contrasting accent

A model built from one shape family only is bland. A model built from all three equally is confused. Pick one dominant family (about 70 percent of the silhouette) and one accent family (most of the rest). A healer NPC: round body, round hat, one small triangular staff tip. A spiky enemy: triangular horns, spikes and claws on a squarish body so it still feels solid and heavy. The accent tells the player what is special about this particular round or spiky thing.

### 2. Straights against curves

Pair a straight edge with a curved edge on the same part. A straight back with a rounded belly. A flat-topped rock with a bulging side. Straight against curve gives direction and tension; curve against curve looks blobby, straight against straight looks like an untextured block. This is the main reason stylised props look better than primitives with the same triangle count.

### 3. Rhythm and spacing

Repeated elements (fence posts, spikes on a back, teeth on a gear) read better with uneven spacing and size: large, small, medium, large, rather than five equal teeth. Equal repetition looks mechanical and also aliases on screen, creating a shimmering comb at distance. Vary spacing by 20 to 40 percent and size by 30 to 50 percent (rule of thumb).

### 4. Line of action and lean

Even a static prop has a line of action: the main curve through the model. A tree with a trunk that curves in a gentle S, a lamp post that leans 3 degrees, a creature whose spine arcs. Straight vertical lines on organic or stylised objects read as stiff. Static, man-made props (walls, crates) can stay straight, but most stylised Roblox art benefits from a lean of 2 to 6 degrees on organic or "lived-in" pieces. [[Posing and Silhouettes]] covers line of action for animated characters.

## Negative space and tangents

### Negative space

Negative space is the background visible through and around the shape: the gap between an arm and the body, the hole in a handle, the space under a mushroom cap. It is often what makes a silhouette identifiable. A teapot without the hole in its handle becomes a lump. A character with arms glued to the sides loses its read; the same character with a gap of one arm-width between arm and torso reads at twice the distance.

Rules of thumb for gaps that read on Roblox:

- A gap needs to be at least about 2 pixels on screen at the farthest distance it matters, or it closes up. At a typical 15-stud phone view that is roughly 0.1 to 0.15 studs; at 60 studs it is roughly 0.5 studs (see the camera note for the formula).
- Prefer one large gap to several small ones. A shield held away from the body with one clear gap reads; a lattice of thin gaps turns to noise.
- On rigged characters, keep negative space in the idle pose, not just in the T-pose. Models designed in T-pose often close every gap when the arms drop.

### Tangents

A tangent is where two edges just touch: a hat brim that exactly meets the shoulder line in silhouette, a sword tip that touches the ground plane, a roof edge that lines up exactly with a background hill. Tangents flatten depth because the eye cannot tell which shape is in front. Fix them by either clearly overlapping (by at least about 10 percent of the smaller shape) or clearly separating. Tangents are hard to see in the modelling viewport and obvious in a silhouette render, which is one reason to do silhouette renders at all.

## Silhouette testing on Roblox: four views, not one

The classic test is one side view, filled black on white. Roblox needs more, because the default camera sits above and behind the character and orbits freely.

| View | Why it matters on Roblox | Pass condition |
|---|---|---|
| Side (90 degrees) | Classic test; enemies seen walking across the screen | Identifiable as a filled shape |
| Front three-quarter (about 45 degrees) | The angle the player sees approaching enemies and NPCs | Identifiable, with at least one secondary breaking the outline |
| High three-quarter (camera about 30 to 40 degrees above horizontal) | The default follow camera looks down at the world | Still identifiable; top surfaces carry a distinct shape |
| Top-down (about 70 to 90 degrees) | Pets, pickups and props on the ground are often seen from almost straight above | Not a featureless blob; a hat, ears, crest or rim shape survives |

The high and top-down views catch the most failures in Roblox art. A character whose identity is all in its face (big eyes, a mouth) disappears from above. A pickup that is a flat disc reads as a coin from the side and as a circle from above, which is fine, but a sword pickup lying flat on the ground reads as a thin line from the side and only reads well from above. Design pickups and pets with something on the top surface: ears, a crest, a gem, a contrasting cap.

### Thumbnail sizes to test at

Test the silhouette at the pixel sizes it will actually appear, not at full viewport size.

- **Hero or player-scale model at play distance**: about 150 to 250 pixels tall (phone, default camera, rule of thumb).
- **Enemies at engagement distance**: about 40 to 80 pixels.
- **Landmarks seen from across a zone**: about 30 to 60 pixels.
- **Inventory icon**: whatever your UI uses, often 64 to 128 pixels on screen.

[[Environment Art Styles]] quotes 30 to 40 pixels tall as the identification threshold for important assets; that is a good hard floor.

## The roster test: silhouettes side by side

Testing one model alone tells you if it reads. Testing it beside its siblings tells you if it is **distinct**, which matters more for gameplay. Players must tell a ranged enemy from a melee enemy, a common chest from a rare chest, a shop NPC from a quest NPC, at a glance.

Lay out every model of one category on a line, filled black, at the same scale and at the same pixel height they appear in game. Then check:

- **Each role has a unique primary shape.** If two enemy types share a primary (both a wedge), they must differ hugely in a secondary (one has a long tail, one has a raised arm cannon).
- **Size bands are distinct.** Small, medium and large enemies should differ in height by at least about 1.5 times step to step, or they blur into one "normal" size (rule of thumb).
- **Threat reads in shape.** More dangerous variants get more triangles in the shape-language sense (spikes, points, forward lean), not just a different colour. Colour-only variants fail for colour-blind players and in dim zones. See [[Zone and Biome Art Direction]] for colour roles.
- **Upgrade tiers add silhouette, not just trim.** If a rare chest only differs from a common chest by a thin gold trim, players will not see the difference at 30 studs. Add a raised lid, a crest, a floating gem. [[Environment Art Styles]] covers tier ladders.

A common way to see this quickly: take a public game with a large enemy roster, screenshot its enemies, fill them black, and compare. Well-known Roblox games with big combat rosters lean heavily on distinct primary shapes and size bands for this reason.

## Worked example: a silhouette sheet in Blender

This builds a reusable silhouette check that renders any collection of models as black shapes from the four views. All steps are in Blender (Blender manual: Workbench render engine, Flat lighting, Single colour).

1. **Put each model in a collection** called `Roster`. Place them in a row with 1 unit of space between bounding boxes, all with their origin at the ground. Use real Roblox scale (one Blender unit set to match your studs; see [[Exporting and Validating Models for Roblox]]).
2. **Set the render engine to Workbench.** Render Properties: Lighting **Flat**, Colour **Single**, set the single colour to pure black (0, 0, 0). Turn off Outline, Cavity, Shadow and Depth of Field. Set the World viewport colour or Film background to white. Flat lighting with a single colour fills every face with the same value, which is exactly a silhouette.
3. **Add four cameras**: side (rotation 90, 0, 90 for a model facing negative Y), front three-quarter (rotate the side camera 45 degrees around Z), high three-quarter (pitch it down 35 degrees from horizontal), and top-down (pitch down 80 degrees, not 90, so very flat things still have a little depth). Use orthographic cameras for the roster sheet so sizes compare fairly.
4. **Set the output resolution low.** For enemies, 512 by 128 for a row of 6 or so models gives each model about 60 to 100 pixels of height, close to game size. Rendering big hides problems.
5. **Render each camera** (F12 with each camera active, or bind cameras to markers and render the frames 1 to 4 as an animation).
6. **Read the sheet** using the roster checks above. Note failures per model and per view. A failure on the top-down view only is common and is often fixed with one secondary shape on top.
7. **Flip it.** Mirror the render horizontally in any image viewer. A fresh view exposes lopsided shapes and tangents your eye stopped seeing (an old drawing trick that works just as well on renders).

This setup takes about ten minutes once and then runs in seconds for every new model. Save it as a template .blend.

## Worked example: a silhouette mode inside Studio

The Blender test lacks Roblox lighting, the real camera and the real background. A quick Studio check uses `Highlight` objects to fill models black. The script below is for the command bar in Edit mode or a local test place; it creates one highlight per selected model and removes them on a second run. Highlight properties (FillColor, FillTransparency, OutlineTransparency, DepthMode) are from the Roblox docs (as of October 2026).

```lua
-- Command bar: toggle a black silhouette on every selected Model or BasePart.
local Selection = game:GetService("Selection")
local TAG = "SilhouetteCheck"

local removed = 0
for _, h in workspace:GetDescendants() do
	if h:IsA("Highlight") and h.Name == TAG then
		h:Destroy()
		removed += 1
	end
end

if removed == 0 then
	for _, target in Selection:Get() do
		if target:IsA("Model") or target:IsA("BasePart") then
			local h = Instance.new("Highlight")
			h.Name = TAG
			h.FillColor = Color3.new(0, 0, 0)
			h.FillTransparency = 0 -- solid fill hides all shading
			h.OutlineTransparency = 1 -- no outline, we want the raw shape
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = target
			h.Parent = target
		end
	end
end
```

Then fly the Studio camera to the real play angle and distance, or press Play and view from the character. Check the four views against the real sky and ground. Two things this catches that Blender cannot:

- **Silhouettes against the actual background.** A dark model against a dark forest floor fails even when its outline is good. The fix is value contrast (a lighter top surface, a rim of contrasting colour) rather than shape. See [[Lighting Technologies and Settings]] for how the sky and ambient settings change the background value.
- **Overlap with other assets.** A tree trunk passing behind an enemy can merge with its outline at certain angles. Level design solves this with spacing and value, not modelling.

Remove the highlights before publishing. Highlights are cheap individually, but the docs limit how many render at once (255 as of October 2026, per [[Highlights and Selection Effects]]), and a forgotten one is a bug.

## When not to chase a perfect silhouette

- **Background and filler art.** Distant cliffs, crowds of trees and wall kits should read as masses, not as individual silhouettes. Give them a strong group silhouette (a skyline) and stop.
- **Modular kit pieces.** A wall segment has no silhouette on its own; test the assembled building instead. See [[Modular Environment Kits]].
- **Items seen only in UI.** An item that only ever appears as an icon needs an icon silhouette, which is a 2D design task with its own framing. Model it to look good from the icon camera.
- **First-person or very close views.** A first-person weapon is judged by its shape from behind the hand, not by a side silhouette.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Model reads in Blender, vanishes in game | Tested at full viewport size and side view only | Test at real pixel height and from the high three-quarter view |
| Two enemy types get confused by players | Same primary shape, different colour only | Change one primary or one large secondary; keep colour as a second cue |
| Character looks like a lump in idle | Arms close all negative space when lowered | Widen the stance, add a gap at the waist, test in the idle pose |
| Rare and common versions look the same | Upgrade adds only thin trim or colour | Add a silhouette-changing element (crest, raised lid, floating piece) |
| Outline looks fuzzy at distance | Too many small tertiary bumps on the edge | Merge bumps into fewer, larger secondaries; move detail into colour blocks |
| Pets and pickups unreadable from above | All identity in the front face | Add a top feature: ears, crest, cap, gem |
| Shapes feel flat and stacked | Tangents where edges just touch | Overlap clearly or separate clearly |

## Checklist

- [ ] Primary, secondary and tertiary shapes identified; tertiaries under about 10 to 15 percent of the silhouette.
- [ ] One dominant shape family plus one accent family.
- [ ] Straight against curve on the main masses.
- [ ] At least one clear negative space gap in the play pose.
- [ ] No tangents in the four standard views.
- [ ] Silhouette passes side, front three-quarter, high three-quarter and top-down at game pixel size.
- [ ] Roster test done: each gameplay role has a unique primary or large secondary.
- [ ] Size bands step by at least about 1.5 times.
- [ ] Studio silhouette check under real lighting and background; highlights removed afterwards.

## Related

- [[Low-Poly and Stylized Modeling]]
- [[Modeling Fundamentals for Games]]
- [[Posing and Silhouettes]]
- [[Environment Art Styles]]
- [[Zone and Biome Art Direction]]
- [[Highlights and Selection Effects]]
- [[Lighting Technologies and Settings]]
- [[Modular Environment Kits]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Modelling to the Roblox Camera and Player Scale]]
- [[Critiquing a Model - Paintovers and Iteration]]
- [[Modelling Nuance Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Colour Scripts and Value Structure for Untextured Art]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Voxel and Blocky Modeling]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Thumbnail Contrast]]
<!-- auto-links:end -->
