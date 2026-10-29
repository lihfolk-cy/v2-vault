---
tags: [modeling, style-bible, style-guide, art-direction, consistency, pipeline, team, validation, luau, blender, type/guide, area/modeling]
---
# Style Bibles for Consistent Models

<!-- tldr:start -->
> [!tldr] TL;DR
> - Bible exists, assets still drift: Rules are adjectives, not numbers -> Rewrite each rule with a number or range
> - Nobody reads it: 30-plus pages of prose -> 4 to 8 pages, tables and do/don't pairs
> - Reviews turn into taste arguments: No golden assets -> Pick 3 to 5 golden assets; review side by side
>
> Cost: TL;DR ~120 tok · whole note ~4.1k tok. Read more: ## What a modelling style bible contains · ## Enforcing the bible automatically · ## 12. A checklist the reviewer runs · ## Common mistakes
<!-- tldr:end -->

[[Environment Art Styles]] explains how to write a style down in ten sections (core rules, anatomy, shape grammar, materials, palette, tiers, motion, build steps, QA, mistakes). That is the art-direction view. This note is the modeller's view: what a style bible needs so that a new modeller, a contractor, a procedural script or an AI generator produces models that sit next to existing ones without anyone noticing a seam. The difference is precision. "Chunky with soft edges" is a mood. "Outer bevel 0.08 studs, 2 segments, on props under 3 studs" is a rule someone can follow and someone else can check.

## Why models drift

A library becomes inconsistent through small, reasonable decisions made by different people at different times. The common drift sources, roughly in order of how visible they are:

1. **Scale.** One door at 7 studs, another at 9. Crates at three slightly different sizes.
2. **Edge treatment.** Sharp corners on one kit, soft bevels on another, inflated toy bevels on a third.
3. **Segment density.** A 6-sided barrel beside a 24-sided bucket.
4. **Colour and value.** Colours picked by eye, so the same "wood" exists in eight browns with different values.
5. **Material choice.** SmoothPlastic beside Plastic beside a MaterialVariant, all meant to be the same surface.
6. **Shading style.** Flat-shaded facets on rocks, smooth-shaded rocks from a different pack.
7. **Detail density.** A heavily detailed hero prop beside plain kit pieces with no in-between.
8. **Proportions.** Thick rims on one set, real-world thin rims on another.

Untextured and non-hand-painted styles are more sensitive to all of these, because there is no painted texture layer to unify assets. Every difference in geometry and colour shows directly.

## What a modelling style bible contains

Think of it as a short document plus a small set of files. The document should fit in 4 to 8 pages; nobody reads 40. Each rule should be **measurable**, **illustrated** and **checkable**.

### 1. One-paragraph intent and three reference images

What the style is for, in one paragraph, plus three images: one that is on target, one that is "too far" one way (too detailed, too realistic) and one that is "too far" the other way (too plain). Boundaries communicate better than a single target. Public references are fine for this. A classic one for readability is Valve's 2007 paper "Illustrative Rendering in Team Fortress 2", which explains how that game kept silhouettes, value and colour readable at distance; many stylised game studios have given similar public talks.

### 2. Scale sheet

A single image and table with the avatar proxies and the approved sizes of standard elements: door, window, crate, barrel, fence post, step, table, tree trunk. Give each a number in studs, using the avatar-unit approach in [[Modelling to the Roblox Camera and Player Scale]]. Include the exaggeration multipliers from [[Proportion Exaggeration and Gameplay Distance]] as numbers: "small props 1.5 to 2 times real size, buildings 1.2 times".

### 3. Grid and pivot rules

- The snapping grid in studs (for example 1 stud for props, 4 studs for building kits). See [[Modular Environment Kits]].
- Pivot location by category: ground props at the bottom centre, wall pieces at the bottom corner or bottom centre of the back face, held items at the grip.
- Forward direction convention for anything that faces a way.
- Export orientation and unit mapping, pointing to [[Exporting and Validating Models for Roblox]].

### 4. Edge treatment table

| Size band | Bevel width | Segments | Profile | Shading |
|---|---|---|---|---|
| Small props under 3 studs | 0.06 to 0.08 studs | 2 | Round (0.5) | Smooth, [[Weighted Normals\|Weighted Normal]] |
| Medium props 3 to 10 studs | 0.12 to 0.2 studs | 2 | Round | Smooth, Weighted Normal |
| Buildings and kits | 0.2 to 0.3 studs on outer corners only | 1 | Chamfer | Smooth by Angle 30 degrees |
| Rocks and terrain props | 0.15 studs chamfer | 1 | Chamfer | Flat |

The values above are an example for one soft stylised look. Your numbers will differ; what matters is that they exist. The reasoning for choosing them is in [[Bevels Chamfers and Edge Highlights Without Textures]].

### 5. Segment density table

Segments by radius for cylinders and spheres, as numbers. Example: radius under 0.5 studs: 8 segments; 0.5 to 2 studs: 12; 2 to 6 studs: 16; larger: 24 plus a check. Derive these from the sagitta table in [[Spending Triangles Where the Camera Looks]] and divide by your style's "facet factor".

### 6. Triangle budgets by category

A table with a target and a hard ceiling, for example small prop 300 target and 800 ceiling. Link to [[Art Budgets - Triangles Draw Calls Memory]] for scene totals. The ceiling matters more than the target: it is the line that makes a reviewer send an asset back.

### 7. Palette and value rules

- The palette as exact colour values (hex or RGB), each with a name and a role: `wood_mid`, `wood_dark`, `stone_light`, `accent_gold`.
- **Value ranges per role**, not just colours: "large surfaces between 35 and 65 percent value, accents above 75 percent, shadows-in-colour below 25 percent". Value structure is what keeps the library readable; see [[Environment Art Styles]] for palette derivation.
- The maximum number of colours per asset (for example 4 plus one accent).
- How colour is applied: `MeshPart.Color`, vertex colour, a shared palette atlas, or a SurfaceAppearance. Pick one primary method per asset class, because mixing methods on one mesh makes recolouring painful (see [[Trim Sheets Atlases and Vertex Colors]] for the vertex colour trap).

### 8. Material list

Allowed `Material` values and MaterialVariants, each with its use: "SmoothPlastic for painted wood and props; Slate MaterialVariant `StyleStone` for rock; Neon only for emissive accents, under 5 percent of an asset's visible area". Link to [[Materials and Surfaces Start Here]].

### 9. Shape grammar and do/don't pairs

The core of the bible for modellers. For each asset family, a short list of shape rules with a pair of images: do on the left, don't on the right. Examples:

- "Roofs sag 0.3 to 0.5 studs in the middle of each span. Do not model straight ridges."
- "Posts lean 2 to 4 degrees, alternate directions. Do not place perfectly vertical rows."
- "Every prop has one focal feature at least 1.5 times larger than any other secondary."
- "Gaps between planks at least 0.15 studs. Do not model hairline gaps."
- "Rocks: flat top plane plus 3 to 5 large side facets. No noisy sculpted surfaces."

Do/don't pairs teach faster than paragraphs, and they are the easiest part of the bible to extend when a new mistake appears.

### 10. Golden assets

Three to five finished models that perfectly follow the bible, kept in a shared file and in a Studio place. Every new asset is placed beside them for review. Golden assets resolve most arguments about the rules, because "does it sit next to the golden crate" is easier to judge than "does it follow rule 7".

### 11. Naming and file conventions

Asset names, collection names, material slot names and export file names. These are boring and they are what make automated checks possible.

### 12. A checklist the reviewer runs

The last page is a list of yes or no checks, each tied to a rule above. See the critique workflow in [[Critiquing a Model - Paintovers and Iteration]].

## Writing rules that people follow

- **Numbers over adjectives.** "Chunky" means different things to every modeller. "Rims at least 0.3 studs" does not.
- **Ranges over single values** where taste is involved. "Lean 2 to 4 degrees" leaves room for variety; "lean 3 degrees" produces a mechanical look.
- **One rule per line.** Long paragraphs hide rules.
- **Explain the why in one clause.** "Rims at least 0.3 studs, because thinner rims vanish at 40 studs on phones." People keep rules they understand.
- **Version it.** Date each change and keep a short change log at the end. When rules change, mark which existing assets now break them and decide whether to fix or grandfather them.
- **Write for scripts too.** If a procedural generator or an AI tool produces assets, the same numbers drive its parameters. See [[Procedural Blender Assets Start Here]] and [[AI 3D Model Generation Outside Roblox]].

## Enforcing the bible automatically

Some rules can be checked by code. Automating them stops drift between reviews.

### In Blender: a pre-export check

A short Python script can check triangle count against the category ceiling, dimensions against the grid, material slot names against the allowed list, and the presence of UVs. [[Blender Automation with Python]] covers running such scripts in batch. Keep the check fast enough to run on every export.

### In Studio: a palette and material audit

This command bar script lists MeshParts and Parts under a selected folder whose `Color` is not within a tolerance of any palette colour, or whose `Material` is not allowed. It only reads properties and prints; it changes nothing. Properties used (`Color`, `Material`, `MaterialVariant`) are from the Roblox docs (as of October 2026).

```lua
-- Command bar: audit selected folders/models against the style palette.
local Selection = game:GetService("Selection")

local PALETTE = {
	wood_mid = Color3.fromHex("8A5A3B"),
	wood_dark = Color3.fromHex("5C3A26"),
	stone_light = Color3.fromHex("B8B2A7"),
	stone_dark = Color3.fromHex("6E6A63"),
	leaf_mid = Color3.fromHex("5E9E4A"),
	accent_gold = Color3.fromHex("F2C14E"),
}
local ALLOWED_MATERIALS = {
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Neon] = true,
}
local TOLERANCE = 0.04 -- per channel, 0 to 1 scale

local function nearPalette(c: Color3): string?
	for name, p in PALETTE do
		if math.abs(c.R - p.R) <= TOLERANCE
			and math.abs(c.G - p.G) <= TOLERANCE
			and math.abs(c.B - p.B) <= TOLERANCE then
			return name
		end
	end
	return nil
end

local issues = 0
for _, root in Selection:Get() do
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local problems = {}
			if not nearPalette(part.Color) then
				table.insert(problems, "colour " .. part.Color:ToHex())
			end
			if not ALLOWED_MATERIALS[part.Material] then
				table.insert(problems, "material " .. part.Material.Name)
			end
			if #problems > 0 then
				issues += 1
				print(part:GetFullName(), table.concat(problems, ", "))
			end
		end
	end
end
print(("Style audit done: %d parts off-bible"):format(issues))
```

Limits of this check: vertex colours and texture colours are not visible to scripts through these properties, so assets that carry their colour in vertices or a SurfaceAppearance need a separate review. A MaterialVariant check can be added by testing `part.MaterialVariant` against an allowed set of names.

### What code cannot check

Shape grammar, focal features, lean and rhythm, silhouette distinctness. Those need a human (or a carefully prompted reviewer) comparing against golden assets. Automation clears the mechanical issues so that review time goes to the judgement calls.

## Worked example: a one-page bible for a "soft toy" prop style

A small team is building a cosy village. This is the first page of its bible, written as an example of tone and precision. All numbers are this project's choices, not universal values.

1. **Intent.** Props look like painted wooden toys: soft, chunky, readable from the high follow camera on a phone. Three references: on target, too realistic, too blocky.
2. **Scale.** Avatar proxies at 5 and 6.5 studs. Door 7.5 by 5 studs. Crate 2.5 studs. Barrel 3 studs tall, radius 1. Fence post 0.6 studs square, 3 studs tall.
3. **Grid.** Props snap to 0.5 studs; buildings to 2 studs. Pivot bottom centre. Forward is negative Z in Studio.
4. **Edges.** Every outer edge bevelled: 0.08 studs on props under 3 studs, 0.15 on 3 to 10 studs, 2 segments, round profile, Weighted Normal with Keep Sharp. Inner corners not bevelled.
5. **Segments.** Radius under 0.5: 8. Radius 0.5 to 2: 12. Larger: 16.
6. **Budgets.** Small prop 300 target, 700 ceiling. Medium prop 1,000 target, 2,500 ceiling. Building 3,000 target, 6,000 ceiling.
7. **Colour.** Ten named palette colours, values listed. Large surfaces 35 to 65 percent value. One accent per prop. Colour by `MeshPart.Color` per piece; no vertex colour except baked ambient occlusion in the range 0.8 to 1.0.
8. **Materials.** SmoothPlastic default. Neon for lantern glass only.
9. **Shape rules.** Roofs sag. Posts lean 2 to 4 degrees. Planks vary in width by 15 to 30 percent. One focal feature per prop. Nothing thinner than 0.3 studs.
10. **Golden assets.** Crate, barrel, lantern post, market stall, cottage. Stored in the `StyleGolden` folder of the art test place.

That page is enough for a new modeller to produce a matching barrel on their first try, and enough for a reviewer to reject one that does not match, with a reason.

## When a style bible is overkill

- **Solo game jams and prototypes.** A golden asset or two and a palette are enough. Write the bible when a second person joins or when the asset count passes about 50.
- **Purely procedural worlds.** The generator's parameters are the bible. Document them in code comments and a short page, not a separate long document.
- **Mixed-style games by design.** Some games deliberately mix styles (a collection game with items from many worlds). The bible then defines what stays shared (scale, value range, edge treatment) and what each sub-style may vary.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Bible exists, assets still drift | Rules are adjectives, not numbers | Rewrite each rule with a number or range |
| Nobody reads it | 30-plus pages of prose | 4 to 8 pages, tables and do/don't pairs |
| Reviews turn into taste arguments | No golden assets | Pick 3 to 5 golden assets; review side by side |
| Old assets break new rules silently | Unversioned changes | Change log plus a list of affected assets |
| Colours wander over months | Palette applied by eye | Named palette values plus the Studio audit |
| Generated assets look off-style | Generator uses different numbers | Drive generator parameters from the bible |
| Bible blocks a quick prototype | Written too early | Start with a palette and golden assets; formalise later |

## Checklist

- [ ] Intent paragraph and three boundary reference images.
- [ ] Scale sheet with avatar proxies and standard element sizes.
- [ ] Grid, pivot and forward-direction rules.
- [ ] Edge treatment table by size band.
- [ ] Segment density table.
- [ ] Triangle targets and hard ceilings by category.
- [ ] Named palette with value ranges and one colouring method per asset class.
- [ ] Allowed materials list.
- [ ] Shape grammar with do/don't image pairs.
- [ ] 3 to 5 golden assets in a shared file and a Studio place.
- [ ] Automated checks in Blender and Studio for mechanical rules.
- [ ] Versioned with a change log.

## Related

- [[Environment Art Styles]]
- [[UI Design Systems]]
- [[Modular Environment Kits]]
- [[Art Budgets - Triangles Draw Calls Memory]]
- [[Trim Sheets Atlases and Vertex Colors]]
- [[Blender Automation with Python]]
- [[Asset Pipelines]]
- [[Procedural Blender Assets Start Here]]
- [[Bevels Chamfers and Edge Highlights Without Textures]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Critiquing a Model - Paintovers and Iteration]]
- [[Modelling Nuance Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Keeping a Mixed Asset Library Consistent]] · Untextured Stylised Modelling Start Here · Low-Poly and Stylized Modeling · Clean Stylised Shading - Weighted and Custom Normals · Stylised Shop Stand Worked Example · Flat Colour vs Gradient Atlas vs Vertex Colour
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Low-Poly and Stylized Modeling]] · [[Shape Language and Silhouette Testing]] · [[Stylised Shop Stand Worked Example]] · [[Hard-Surface Modeling]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Modeling in Blender for Roblox]]
<!-- related:end -->
