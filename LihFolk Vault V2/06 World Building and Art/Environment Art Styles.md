---
tags: [world-building, art-direction, style, palette, stylised, voxel, pbr, type/guide, area/world, level/intermediate, area/modeling]
---
# Environment Art Styles

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Mixing Toolbox assets of different styles -> One style guide, own kit
> - Avoid: Picking colours in a picker -> Sample under game lighting
> - Avoid: Too much glow -> Keep glow coverage in budget
> - Style guide written (core rules, slots, palette, ladder, QA).
> - Palette derived systematically; sampled under game lighting.
> - Silhouette test passed for key assets at 30 to 40 px.
>
> Cost: TL;DR ~140 tok · whole note ~3.3k tok. Read more: ## Writing a style down · ## Palettes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An art style is a set of rules that every asset obeys: shape language, palette, materials, texture density, lighting, and how much detail goes where. On Roblox the style must also survive a phone screen, the default camera distance, low graphics settings and dozens of assets from different hands. This note describes the common Roblox style families, how to write a style down so a team (or a script) can reproduce it, how to derive palettes, and the style lessons from one production game whose owner rejected several "technically fine" versions of its hub before landing on one that worked.

## Why style consistency beats fidelity

Players forgive low detail; they do not forgive inconsistency. A photoreal rock next to a flat-shaded cartoon tree reads as "assets from the Toolbox". The cheapest way to look professional is **one style, applied everywhere**, which is why the strongest Roblox games often look simple.

Observed in one production game:
- A procedurally generated hub (sci-fi trim sheets, then a fantasy stone restyle) was technically clean but judged "cheap" and "pixelated" next to the old hand-painted hub; it was reverted.
- Textured cliff meshes with baked vertex-colour strata looked "patchy" and "like paper". The final answer was **two flat SmoothPlastic tones** per cliff (top 55 percent one shade, bottom 45 percent a slightly darker one), plus a grass lip. The owner's words: "should just be 2 slightly different solid colors".
- The owner set a rule that maps are hand-built in Blender ("should not be voxel art"), while enemies can stay voxel. Two styles can coexist **if each asset class is consistent** and they meet at a clear boundary (characters versus world).

## Style families on Roblox

| Family | Look | Strengths | Costs and risks | Typical genres |
|---|---|---|---|---|
| Classic brick / stud | Parts, studs, bright primaries | Instantly "Roblox", cheap, buildable in Studio | Part counts; can look dated without care | Obbies, tycoons, nostalgia games |
| Flat stylised (pet-sim look) | SmoothPlastic, saturated flat colours, chunky rounded shapes, soft shadows | Reads on phones, cheap textures, ages well | Needs strong shapes and lighting; empty if under-dressed | Simulators, RNG, collection games |
| Low-poly faceted | Visible facets, flat or gradient colours | Fast to model, clear silhouettes | Faceting reads as cheap if inconsistent | Adventure, survival |
| Voxel | Everything on a cube grid | Coherent, scriptable, toy-like | Part counts or mesh baking needed; smooth shapes break it | RNG showcases, stylised combat |
| Hand-painted | Painted albedo textures, soft light baked into colour | Rich detail at low poly | Texture memory; lighting mismatch with baked shadows | Fantasy RPG, cosy games |
| PBR semi-real | SurfaceAppearance PBR, realistic proportions | High fidelity on desktop | Texture memory, phone performance, uncanny next to avatars | Horror, shooters, showcases |
| Neon / sci-fi | Dark bodies, emissive lines, bloom | Dramatic, cheap geometry | Bloom dependence; low graphics loses the glow | Sci-fi, cyber, void themes |

## Writing a style down

A style guide that a builder (or a generator script) can follow has the same sections whatever the style. The reference project wrote one per voxel style in this structure, and it is the most reusable format we have used.

1. **Core rules in ten lines.** The non-negotiables. Example for a glow-trim voxel style: the base shape never changes between ranks; everything sits on one cube grid; bodies are a dark tint of the theme hue; Neon outlines edges and symbols but never fills large areas; each theme has its own top shape; the sky carries the theme colour.
2. **Anatomy (regions).** Split any object into named regions (edges, main face, corners, symbol panel, supports, top, sides, surroundings) so every theme or rank fills the same regions and variants share a silhouette.
3. **Shape grammar.** How each shape is built: stepped curves, voxelised spheres, rings, spires, chains, crystals.
4. **Materials and ratios.** Which materials, and how much of the image is glow (Rule of thumb: a few percent for clean pieces, up to roughly a sixth for the most lit; beyond that the shape dissolves into bloom).
5. **Palette system.** How colours are derived (below).
6. **Tier or rarity ladder.** What each step up adds (see the ladder table below).
7. **Motion and VFX.** Ambient motion that belongs to the style.
8. **Build procedure.** Steps in order, with code if the style is generated.
9. **QA checklist.** Testable checks, such as "the top shape names the theme from 30 studs away as a black shape against the sky".
10. **Common mistakes.** What breaks the style.

## Palettes

### Deriving a palette from one hue

A practical starting system for a dark, glowing theme, in HSV (Rule of thumb; tune under your lighting):

| Role | Saturation | Value | Notes |
|---|---|---|---|
| Sky / haze | mid | low-mid | Tints the world; the floor stays neutral |
| Body (dark) | low-mid | very low | Tint toward the hue; grey looks unfinished |
| Glow main | high | high | Set a little darker and more saturated than wanted; bloom lifts it |
| Glow 2 | a few degrees of hue away, a little lighter | | For gradients |
| Trim | neutral grey or white, or gold for royal or holy themes | | |
| Accent | one small off-hue touch | | Draws the eye to one detail |

The same idea adapts to other styles. Bright studded enemies want a saturated mid-value body, a darker shadow, a metal trim and **one glow hue far from the body hue** so it pops. Soft companions want light, low-saturation bodies and **shared set accents** that tie different creatures into one family.

```lua
--!strict
-- Derive a themed palette from one hue (0..1), following the dark-body, glow-trim rules above.
export type Palette = { sky: Color3, body: Color3, trim: Color3, glow: Color3, glow2: Color3 }

local function derivePalette(hue: number, gold: boolean?): Palette
	local function hsv(h: number, s: number, v: number): Color3
		return Color3.fromHSV(h % 1, math.clamp(s, 0, 1), math.clamp(v, 0, 1))
	end
	return {
		sky = hsv(hue, 0.6, 0.4),
		body = hsv(hue, 0.4, 0.15),
		trim = if gold then Color3.fromRGB(224, 165, 48) else hsv(hue, 0.08, 0.7),
		glow = hsv(hue, 0.85, 0.9),
		glow2 = hsv(hue + 0.04, 0.75, 0.97),
	}
end

-- Example: a violet "void" theme
local void = derivePalette(270 / 360)
```

### Palette rules that apply to every style

- **Value structure first.** Squint or desaturate a screenshot: the playable path, interactables and enemies should be distinguishable by value alone.
- **Limit hues per area.** One dominant hue per zone plus neutrals and one accent. Zones become recognisable from a thumbnail.
- **Shared accents across a set** (gold trim, a set pink, white) make different assets read as one game.
- **Avoid near-black textured surfaces.** Material textures disappear below about 0.06 luminance (measured).
- **Sample colours under the game's lighting.** One production game matched a reference screenshot's grass and cliff colours by rendering SmoothPlastic swatches under the hub's actual lighting (with its exposure and colour grading) and solving for the base colour that rendered to the target. Colours picked in a colour picker never match after lighting, bloom and tone mapping.

## Shape language

- **Chunky and readable beats thin and detailed.** Roblox cameras are far away; thin railings, small text and fine trim vanish. Exaggerate thickness.
- **One exaggerated feature per object** gives personality: oversized fists on a brute, a long barrel on a cannon, a huge crown on a showpiece.
- **Silhouette test.** Every important asset should be identifiable as a filled black shape at 30 to 40 pixels tall.
- **Edges catch light.** A small bevel on outer edges (modelled or in the normal map) makes surfaces look finished.

## Detail density and where to spend it

Spend detail where the camera spends time:
1. **The hub centrepiece and stations**: seen every session, up close.
2. **Gates and landmarks**: seen from far and on thumbnails.
3. **The walkable path edges**: the player's peripheral vision while moving.
4. **Backgrounds**: silhouettes and colour only; no small detail.

The owner's feedback in one production game kept asking for "more detail" on the hub stations specifically; the zone backdrops never drew complaints.

## Tier and rarity ladders in the environment

Many Roblox games tie visuals to rarity (pedestals, stations, gates, pets, chests). A ladder shape that works across object types (Rule of thumb):

| Rank | What it adds |
|---|---|
| 1 | The base shape only; glow as thin lines |
| 2 | Full theme colour, a symbol on the main face, corner details |
| 3 | A larger top shape and side pieces |
| 4 | Detail around the base and a few hovering pieces |
| 5 | The boldest top shape and the most detail and motion |

Rules: each rank identifiable from its outline alone; neighbouring ranks differ clearly in hue or value; complexity keeps rising with rank even if the glow share does not. Budget: showcase pieces (one in view) can carry the top tier; anything repeated per player or per zone should stop at rank 2 or 3, or be baked into a few MeshParts.

## Lighting is part of the style

The same assets look like different games under different lighting. Decide lighting with the style, not after:
- **Flat stylised:** bright, low-contrast, soft or no shadows, mild bloom.
- **Neon:** dark ambient, strong bloom (threshold high enough that white trim does not bloom), coloured haze.
- **PBR:** Future lighting, environment specular and diffuse scales tuned so metals do not look plastic.

One production game's "game-ready" material pass also tuned `EnvironmentSpecularScale` 0.75, `EnvironmentDiffuseScale` 0.85, `OutdoorAmbient` (124, 130, 142), haze 0.7 and a light colour-grade tint so the new materials sat together. Details live in [[Lighting Technologies and Settings]] and [[Lighting Mood and Time of Day]].

## Using references

- **Study frames, not impressions.** Step through a reference video frame by frame; sample colours from pixels; estimate sizes against the baseplate stud grid.
- **Write your findings down** in the style-guide structure above, in your own words, with your own frames saved next to it.
- **Separate what transfers from what is incidental.** Look for the system (how variants share regions, how glow scales with rank), not the specific object in the clip.
- **Keep the result your own.** Learn general principles, then design and build your own style and assets.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Mixing Toolbox assets of different styles | "Free model" look | One style guide, own kit |
| Picking colours in a picker | Colours shift after lighting and bloom | Sample under game lighting |
| Too much glow | Shapes lost in bloom | Keep glow coverage in budget |
| Grey bodies on dark themes | Unfinished look | Tint dark colours toward the hue |
| Fine detail on backgrounds | Noise at distance, wasted budget | Silhouettes only |
| Restyling by adding texture to everything | Patchy, busy | Fewer, flatter, cleaner surfaces |
| Lighting decided last | Assets look wrong together | Lock lighting with the style |

## Checklist

- [ ] Style guide written (core rules, slots, palette, ladder, QA).
- [ ] Palette derived systematically; sampled under game lighting.
- [ ] Silhouette test passed for key assets at 30 to 40 px.
- [ ] Detail concentrated on hub, gates, landmarks.
- [ ] Lighting preset locked with the style.
- [ ] Glow coverage within budget per tier.

## See also

- [[Voxel Art - Studs Outlines and Style Kits]], [[Modeling in Blender for Roblox]], [[Materials MaterialVariants and SurfaceAppearance]]
- [[Level Design for Roblox]], [[Foliage Props and Scatter]], [[Water Sky and Atmosphere Art]]
- [[Lighting Technologies and Settings]], [[Atmosphere Sky Clouds and Post-Processing]], [[VFX Design Playbook]]
- [[Genre Playbook - Simulators]], [[Genre Playbook - RNG and Collection Games]], [[Thumbnails Icons and Store Page]]

## Connected notes
<!-- auto-links:start -->
[[Voxel and Blocky Modeling]] · Stylized Lighting Recipes · Colour Scripts and Value Structure for Untextured Art · Lighting Untextured Art in Roblox · Voxel Palettes - Ramps Hue Shifting and Limits · Untextured Stylised Modelling Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Stylized Lighting Recipes]] · [[Lighting Untextured Art in Roblox]] · [[Zone and Biome Art Direction]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Parts Unions and MeshParts]] · [[Textures Decals and Texture Memory]] · [[World Composition and Set Dressing - Designed, Not Scattered]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[House Construction Method - Modular Kit Workflow]]
<!-- related:end -->
