---
tags: [modeling, proportion, exaggeration, readability, scale, stylised, distance, props, characters, type/guide, area/modeling, level/intermediate]
---
# Proportion Exaggeration and Gameplay Distance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Trims vanish or flicker at distance: Real-world thickness -> Size from the distance table; at least `d / 170` studs
> - World looks inconsistent: Different multipliers per artist -> Write multipliers into the style bible; use a scale reference set
> - Big avatars stuck in doors: Door sized for the classic 5-stud figure -> Size for the largest allowed avatar plus margin
> - Asset assigned to a distance band; band written in the brief.
> - Smallest feature checked against the distance table.
> - Exaggeration done in pairs (one feature up, a neighbour down).
>
> Cost: TL;DR ~180 tok · whole note ~3.7k tok. Read more: ## Exaggeration is a function of distance · ## What to exaggerate, and by how much · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Stylised Roblox art exaggerates: big heads, thick rims, oversized doors, chunky weapons. [[Low-Poly and Stylized Modeling]] says "exaggerate scale contrast" and "thick everything". This note answers the harder questions: exaggerate by how much, for which distance, and where exaggeration breaks gameplay (a door the player cannot fit through, a weapon that clips the camera, a prop so big it hides a path). The core idea is that the right proportions are not fixed. They depend on the distance the object is usually seen from, its gameplay role, and the scale of the avatar standing next to it.

## Exaggeration is a function of distance

Real-world proportions are designed to be seen at arm's length. A game camera sees most objects from much further away, through a small screen. Features shrink in screen size linearly with distance, so a feature that is "correct" up close becomes too small to read far away. Exaggeration is compensation.

A simple way to set it (rule of thumb, derived from screen-space maths in [[Modelling to the Roblox Camera and Player Scale]]):

- Decide the **typical viewing distance** `d` in studs for the object.
- Decide the **smallest feature that must read**, such as a rim, handle or eye.
- That feature should be at least about 2 to 3 pixels on the target screen at `d`. With the default vertical field of view of 70 degrees (Roblox docs) and a phone rendering about 700 to 800 pixels tall (rule of thumb; Roblox scales render resolution on some devices and does not document the exact values), one pixel at distance `d` is roughly `d / 520` studs. So 3 pixels is about `d / 170` studs.

| Typical distance | 1 pixel is about | Smallest feature that reads (about 3 px) |
|---|---|---|
| 8 studs (held tool, inspect, shop counter) | 0.015 studs | 0.05 studs |
| 15 studs (default follow camera to character) | 0.03 studs | 0.09 studs |
| 40 studs (enemies at range, nearby buildings) | 0.08 studs | 0.25 studs |
| 100 studs (landmarks across a zone) | 0.19 studs | 0.6 studs |
| 300 studs (skyline, far mountains) | 0.6 studs | 1.8 studs |

Read the table as a floor, not a target. A rim 0.1 studs thick on a building seen from 40 studs is under 2 pixels and will flicker or vanish. Make it 0.3 to 0.4 studs. That is the "thick everything" rule in numbers.

### Gameplay distance categories

Sort every asset into one of these bands before modelling it, and write the band into the asset brief.

1. **Hand band (0 to 10 studs)**: the player's own tool, pets that follow closely, interactables like shop counters and chests during the open animation. Closest to real proportions; tertiary detail allowed.
2. **Character band (10 to 25 studs)**: other players, NPCs you talk to, enemies in melee. The main band for characters.
3. **Engagement band (25 to 80 studs)**: enemies at range, nearby buildings, path props, collectables. The band where most exaggeration pays off.
4. **Landmark band (80 to 400 studs)**: gates, towers, boss arenas, hub centrepieces seen from across the map. Shapes and big colour blocks only.
5. **Skyline band (400 studs and beyond)**: often streamed out or replaced with low-detail meshes. See [[Level of Detail and Model Streaming]].

An object that lives in two bands (a hub fountain seen up close and from afar) is designed for the farther band first, then gets close-band detail added without breaking the silhouette.

## What to exaggerate, and by how much

These ranges are rules of thumb from stylised game art practice, given as multiples of real proportion. Use them as starting points and test in game.

### Characters and creatures

| Feature | Exaggeration | Why |
|---|---|---|
| Head size | 1.3 to 2 times real (chibi styles 2.5 to 3 times) | Face and identity read from further; matches many Roblox avatar styles |
| Hands and feet | 1.3 to 1.6 times | Gestures and footsteps read; weapons look gripped |
| Eyes | 1.5 to 3 times | Facing direction and mood read at 20 to 40 studs |
| Weapon or signature item | 1.3 to 2 times | Role reads instantly (healer staff, brute club) |
| Waist and neck | 0.7 to 0.9 times (thinner) | Creates contrast that makes the big parts look bigger |
| Shoulders on heavy types | 1.4 to 2 times | Threat and mass read in silhouette |

Exaggeration only reads with contrast. A big head on a thick neck just looks like a fat character; the same head on a thin neck looks deliberately stylised. Exaggerate in pairs: one feature up, its neighbour down. [[Chibi Character Rules in Practice]] covers a full head-heavy ruleset.

### Props and architecture

| Feature | Exaggeration | Why |
|---|---|---|
| Door height | 1.3 to 1.6 times avatar height | Leaves room for big avatars and the camera; reads as an entrance at range |
| Door width | 1.5 to 2.5 times avatar width | Groups walk through together; camera follows without clipping |
| Window frames, rims, trims | 2 to 4 times real thickness | Survive the distance table above |
| Handles, knobs, lamps | 1.5 to 2.5 times | Interactables must read as interactable |
| Roof overhang | 1.5 to 2 times | Strong shadow line, clear silhouette from the high camera |
| Steps and stairs | 1 to 2 studs rise, 2 to 3 studs tread | Avatar walking feels right; see below |
| Fences and railings | posts 0.4 to 0.8 studs thick, gaps at least 0.6 studs | Thin railings alias and vanish |
| Signs and text on models | letter height at least `d / 25` studs | Text becomes unreadable fastest of all |

### The "lantern rule"

Small props carry the most exaggeration. A real lantern is about one fifth of a person's height; a stylised Roblox lantern on a shop is often half the avatar's height and still looks right. Small objects at true size read as noise. Big objects at true size read correctly because they are already large on screen. So exaggeration shrinks as size grows: a 2-stud prop may be twice real size, a 20-stud building may be only 1.2 times real, and a mountain needs none.

## Where exaggeration breaks gameplay

### Collision and navigation

Visual size and collision size are separate decisions on Roblox (see [[Collision and Physics Geometry]]). Oversized props often carry oversized collision by default, and that is where problems start.

- **Doorways and gaps.** The largest avatars a player can bring are much bigger than the classic 5-stud figure. [[Avatar Body Types and Scale in Gameplay]] gives the ranges from the docs. If your game does not force a body scale, size passable openings for the largest allowed avatar plus at least 1 stud of margin each side.
- **Path props.** A 2-times barrel on the edge of a 6-stud path takes a real bite out of it. Exaggerate the visual mesh and keep collision tight, or move the prop off the path.
- **Pathfinding.** Agents use the collision geometry. Oversized decorative props with default collision block NPC routes that look open to players. Set `CanCollide` off on decoration or give it a simple box that hugs the base.

### Camera and occlusion

Big foreground props block the follow camera. The default camera zooms in when something is between it and the character (the `Zoom` occlusion mode, Roblox docs). A field of exaggerated mushrooms 8 studs tall around a path makes the camera jump in and out constantly. Rule of thumb: decorative props within about 15 studs of a main path should stay under about 1.5 times avatar height, or be set so the camera ignores them (for example `CanQuery` off, if your camera code respects it; test with your camera mode).

### Weapons and held items

An oversized weapon reads beautifully in third person and causes three problems:

1. It clips into the avatar's own body during animations made for normal-size items.
2. It clips through walls and the camera in tight spaces.
3. Its hitbox, if derived from its size, gives an unfair reach advantage.

Keep the visual exaggeration and decouple the hitbox (see [[Hitboxes and Hit Detection]]). Test the item with a large and a small avatar, because the grip offset that looks right on one floats on the other.

### Scale consistency between assets

Exaggeration must be consistent across the whole asset library. If one artist makes doors 1.3 times and another 2 times, the world looks like it was built by two teams. Write the multipliers into the style bible ([[Style Bibles for Consistent Models]]) as hard numbers, and keep a **scale reference set**: an avatar proxy, a door, a crate and a tree at approved sizes that every new asset is compared against.

## Exaggeration and non-hand-painted art

Without painted texture, two extra effects push exaggeration further.

- **No painted edge highlights.** Hand-painted art paints a light line on edges to define them. Untextured art relies on real bevels catching light, and bevels need real width to catch it at distance. See [[Bevels Chamfers and Edge Highlights Without Textures]].
- **Colour blocks must be big.** A painted texture can carry a 2-pixel-wide pattern. A flat-colour model carries its pattern in geometry or in separate material regions, which each need to be at least the "smallest feature" size from the table above. Tiny colour regions also cost extra vertices along their borders.

The result is that untextured styles typically exaggerate trims and rims about 1.5 times more than hand-painted styles for the same distance (rule of thumb).

## Worked example: sizing a stylised market stall

Goal: a stall for a hub plaza, seen from 15 to 60 studs, with an interactable counter.

1. **Band.** Primarily engagement band (25 to 80 studs) because players see it across the plaza; the counter is in the hand band when used.
2. **Reference set.** In Blender, import or build a 5-stud avatar proxy and a 6.5-stud tall-avatar proxy (see [[Avatar Body Types and Scale in Gameplay]] for current heights). Place them beside the stall area.
3. **Overall size.** Real stalls are about 2.2 metres tall. At 0.28 metres per stud (Roblox docs, units page) that is about 8 studs. Stylise up 1.2 times for the building scale: about 9.5 to 10 studs to the roof peak.
4. **Counter.** Height about 0.6 times avatar height (about 3 studs) so the counter top is visible from the high camera. Depth 2 studs. Front lip 0.3 studs thick: from the distance table, 60 studs needs at least about 0.35 studs to read, so round up to 0.4.
5. **Awning.** Overhang 2 studs past the counter (about 1.8 times real), with a scalloped edge of 4 to 5 large scallops, not 12 small ones. Large scallops read at 60 studs; small ones become a fuzzy line. Vary the scallop widths by about 20 percent.
6. **Props on the counter.** Fruit and jars at about 2 times real size: a 0.8-stud apple, a 1.2-stud jar. Use 3 to 5 props, not 15, and group them so they form one secondary shape.
7. **Sign.** Letter height at least 60 / 25, so about 2.4 studs. If that does not fit, use an icon shape (a fish, a potion) instead of text; icons read further than letters.
8. **Collision.** Box collider hugging the counter and posts. Awning and props non-colliding so the camera and players are not blocked.
9. **Test.** Export, import, place in the plaza. Walk past at 15 studs, then stand at 60 studs. Check the counter lip, scallops and sign. Run the silhouette check from [[Shape Language and Silhouette Testing]] from the high camera.

## When not to exaggerate

- **Realistic art direction.** If the game uses realistic avatars and PBR materials ([[Stylised vs Realistic Material Pipelines]]), heavy exaggeration looks cartoonish and clashes. Use the distance table only to set minimum feature sizes, and accept less readability at range.
- **Gameplay-critical measurements.** Obby jump gaps, platform widths, and stair heights in parkour games must stay exactly as designed. The visual mesh can flare, but the walkable top must match the gameplay grid.
- **Avatar accessories and UGC.** UGC items follow Roblox bounding and fit rules (see [[UGC Avatar Items and Accessories]]). You cannot freely scale them.
- **Mechanical parts that must line up.** A modular wall kit snaps on a grid; exaggerate its trims inside the grid, never its outer dimensions. See [[Modular Environment Kits]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Trims vanish or flicker at distance | Real-world thickness | Size from the distance table; at least `d / 170` studs |
| World looks inconsistent | Different multipliers per artist | Write multipliers into the style bible; use a scale reference set |
| Big avatars stuck in doors | Door sized for the classic 5-stud figure | Size for the largest allowed avatar plus margin |
| Camera jumps in and out along paths | Tall decorative props near the path block the camera | Keep them under about 1.5 times avatar height or out of the camera's queries |
| Exaggerated weapon gives unfair reach | Hitbox derived from visual size | Separate hitbox from mesh |
| Stylised model looks just "fat" | Everything exaggerated up, nothing down | Exaggerate in pairs: big hands with thin wrists |
| Tiny clutter reads as noise | Many small props at true size | Fewer props at 1.5 to 2.5 times size, grouped |

## Checklist

- [ ] Asset assigned to a distance band; band written in the brief.
- [ ] Smallest feature checked against the distance table.
- [ ] Exaggeration done in pairs (one feature up, a neighbour down).
- [ ] Multipliers match the style bible.
- [ ] Compared with the scale reference set (avatar proxies, door, crate).
- [ ] Openings sized for the largest allowed avatar.
- [ ] Collision hugs gameplay shape, not visual exaggeration.
- [ ] Camera tested along paths near tall props.
- [ ] Held items tested with large and small avatars.

## Related

- [[Low-Poly and Stylized Modeling]]
- [[Chibi Character Rules in Practice]]
- [[Avatar Body Types and Scale in Gameplay]]
- [[Collision and Physics Geometry]]
- [[Hitboxes and Hit Detection]]
- [[Camera Systems]]
- [[Modular Environment Kits]]
- [[Level Design for Roblox]]
- [[Shape Language and Silhouette Testing]]
- [[Modelling to the Roblox Camera and Player Scale]]
- [[Style Bibles for Consistent Models]]
- [[Modelling Nuance Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Stylised Shop Stand Worked Example]] · [[Critiquing a Model - Paintovers and Iteration]] · [[Spending Triangles Where the Camera Looks]] · Untextured Stylised Modelling Start Here · Faceted Low-Poly - Flat Normals and Facet Size · Keeping a Mixed Asset Library Consistent
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Keeping a Mixed Asset Library Consistent]] · [[Modeling Fundamentals for Games]] · [[House Construction Method - Modular Kit Workflow]] · [[Hard-Surface Modeling]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Art-Direction Nitpicks - The Principles Behind Them]]
<!-- related:end -->
