---
tags: [world-building, composition, set-dressing, environment-art, focal-point, clutter, scatter, readability, level-design, type/guide, area/world, level/intermediate]
---
# World Composition and Set Dressing - Designed, Not Scattered

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Dressing before the layout and primary forms read.
> - Avoid: Even scatter over every surface, including paths and plazas.
> - Avoid: Every prop the same scale, or the same mesh repeated in a grid.
> - Passes done in order: layout, primary forms, composition, medium props, small detail.
> - One hero per zone, framed from the spawn and gates, brightest and tallest in view.
> - Focal order clear: hero, primary, secondary, tertiary.
>
> Cost: TL;DR ~150 tok · whole note ~1.8k tok. Read more: ## 1. Build macro to micro, and judge each pass before the next · ## 3. Composition rules · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Generated and quickly built maps share one look: props spread evenly over every surface, everything the same size, random rotations on things people made, no clear path, nothing more important than anything else. This note collects the composition rules that turn a blockout into a place that reads as designed. Layout theory is in [[Level Design Principles - Flow Sightlines and Landmarks]], zone colour and landmarks in [[Zone and Biome Art Direction]], scatter tooling in [[Foliage Props and Scatter]], pipeline passes in [[Environment and Level Pipeline]]. The `lihfolk-worldbuilding` skill applies all of it with a placement and audit toolkit.

Labels: **rule of thumb** (general environment-art and level-design practice, not Roblox-specific) unless a line names another vault note as its source.

## 1. Build macro to micro, and judge each pass before the next

| Pass | Contents | Done when |
|---|---|---|
| 1 Layout | grey blocks: ground, paths, gameplay spaces, spawn, hero stand-in, district blocks | the critical path is walkable and obvious from the spawn with no UI |
| 2 Primary forms | buildings, cliffs, big trees, the hero landmark | the silhouette and the three reads (silhouette, colour, light) work with no small props ([[Zone and Biome Art Direction]]) |
| 3 Composition | camera checks from the spawn, path and overview; move masses, not props | one clear focal point per view; leading lines point at it |
| 4 Medium props | story groups: a stall, a camp, a work site | every group answers "what happened here?" |
| 5 Small detail | grass, flowers, pebbles, litter at seams | it breaks hard edges and tiling; it is invisible as a "layer" |

Dressing before pass 1-3 work is the root of most "AI map" looks: detail cannot rescue a layout with no path or focal point. Each pass gets its own folder so it can be hidden to compare ([[Environment and Level Pipeline]]).

## 2. Focal hierarchy

Every view from the player camera has a ranked set of things to look at:

- **Hero** (one per zone): the tallest, most saturated or brightest thing, at least 1.5x taller than anything else ([[Zone and Biome Art Direction]]). Detail and real lights are spent here first ([[Environment Art Styles]]).
- **Primary** (2-4 per view): buildings, gates, large trees. They frame the hero, never compete with it in value or saturation.
- **Secondary**: story groups and props at path edges and nodes.
- **Tertiary**: ground cover and seam detail. Low contrast, low saturation, no lights.

Brightness and saturation follow the same order. The eye goes to light and contrast first, then motion, then skyline silhouettes, then openings, then text ([[Level Design Principles - Flow Sightlines and Landmarks]]); a bright lamp in a dead end pulls players into the dead end.

## 3. Composition rules

- **Frame the hero.** Spawns, gates and path bends face it. Buildings, trees or arches on both sides of the view make a frame; the path is a leading line into it.
- **Height variation.** A skyline of equal heights reads as flat. Vary masses in steps (low walls, houses, one tower) and let silhouettes break the horizon.
- **Negative space.** Paths, plazas, door fronts and the space around interactables stay clear. Clear ground is what makes the dressed edges read. Keep interactable approaches free (the hub reference kept a 46-stud keep-clear radius per station, measured, [[Foliage Props and Scatter]]).
- **Density gradient, not uniform spread.** Dense at edges, walls and corners; sparse in play spaces; nothing in the path. Clumps with gaps, not a sprinkle of evenly spaced items.
- **Groups of odd numbers with a hierarchy.** One big, a couple of mid, a few small in each group, with 5-15% variation and some asymmetry ([[Art-Direction Nitpicks - The Principles Behind Them]]).
- **Made things align; grown things vary.** Crates, fences, benches and stalls align to walls and paths (yaw in 90-degree steps plus a few degrees). Rocks, plants and debris take random yaw, a small tilt to the slope and sink into the ground.
- **Everything is grounded.** Contact with the ground or a support, sunk slightly where natural; no hovering, no props half inside walls unless deliberate (roots, rubble).
- **Props face their use.** Chairs face tables, stalls face the path, signs face the approach, doors face the square.
- **Environmental storytelling as a question.** A cold fire, one bedroll and an unfinished note beat a sign explaining a camp ([[Lore Delivery Without Walls of Text]]). Two or three such moments per zone, placed on the path or at nodes.
- **One style, one palette.** Mixed asset styles read as "assembled from the toolbox" even when each asset is good ([[Environment Art Styles]]).

## 4. Testing composition

- **Player camera at three distances:** close (about 10 studs, what the character stands next to), mid (about 50 studs, the next node), far (the hero from the spawn and from max zoom). Phone aspect too: the horizontal field of view changes a lot by device ([[Level Design Principles - Flow Sightlines and Landmarks]]).
- **Squint/blur test:** with the image blurred, the hero and path are still the clearest shapes.
- **Greyscale test:** ColorCorrection Saturation -1; the path and interactables still separate from the ground ([[Colour-Blind Safe Design]]).
- **Hide-a-pass test:** hide the detail folder. If the view gets worse only a little, the detail was carrying nothing; if it collapses, the primary forms are weak.
- **Walk it:** spawn to goal along the critical path, timing it at 16 studs/s.

## Common mistakes

- Dressing before the layout and primary forms read.
- Even scatter over every surface, including paths and plazas.
- Every prop the same scale, or the same mesh repeated in a grid.
- Random yaw on made objects; props that face nothing.
- The brightest or most saturated thing is decoration, not the hero or goal.
- Floating, buried or wall-clipping props.
- Mixed asset styles and palettes in one view.
- No negative space around doors, prompts and spawns.

## Checklist

- Passes done in order: layout, primary forms, composition, medium props, small detail.
- One hero per zone, framed from the spawn and gates, brightest and tallest in view.
- Focal order clear: hero, primary, secondary, tertiary.
- Paths, door fronts and interactables clear; density rises toward edges.
- Made objects aligned; natural ones varied, tilted and sunk.
- Story groups placed on the path or at nodes.
- Close, mid and far camera checks; blur, greyscale and hide-a-pass tests done.

<!-- related:start -->
## Related
[[Level Design for Roblox]] · [[Procedural World Generation]] · [[Collision and Physics Geometry]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Modeling in Blender for Roblox]] · [[Level of Detail and Model Streaming]] · [[Water Sky and Atmosphere Art]] · [[Art Budgets - Triangles Draw Calls Memory]]
<!-- related:end -->
