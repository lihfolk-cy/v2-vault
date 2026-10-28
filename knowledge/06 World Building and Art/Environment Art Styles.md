---
tags: [world-building, art-direction, style, palette, stylised, voxel, pbr]
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
> Read more (13 KB note): ## Writing a style down · ## Palettes · ## Common mistakes · ## Checklist
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

A style guide that a builder (or a generator script) can follow has the same sections whatever the style. One production game studied three stylised voxel looks from short devlog videos frame by frame and wrote each up in this structure; it is the most reusable format found.

1. **Core rules in ten lines.** The non-negotiables. Example from a "dark body, neon line" voxel style: one fixed base silhouette per object; everything on one cube grid; dark body tinted to the theme hue; neon traces edges and glyphs but never fills; one hero crown on top taller than the body is wide; higher tiers sink into a rubble skirt; floaters break the outline; the sky takes the theme colour.
2. **Anatomy (slots).** Split any object into named slots (frame edges, main face, corners, emblem, supports, crown, flanks, skirt, air) so every theme or tier fills the same slots and variants share a silhouette.
3. **Shape grammar.** How each shape is built: stepped curves, voxelised spheres, rings, spires, chains, crystals.
4. **Materials and ratios.** Which materials, and how much of the image is glow. Measured glow coverage in that study ranged from about 1 percent (clean tier) to 16 percent (most lit theme); above about 16 percent the shape dissolved into bloom.
5. **Palette system.** How colours are derived (below).
6. **Tier or rarity ladder.** What each step up adds (see the ladder table below).
7. **Motion and VFX.** Ambient motion that belongs to the style.
8. **Build procedure.** Steps in order, with code if the style is generated.
9. **QA checklist.** Testable checks, such as "the crown silhouette names the theme from 30 studs away as a black shape against the sky".
10. **Common mistakes.** What breaks the style.

## Palettes

### Deriving a palette from one hue

A practical system from that style study, in HSV:

| Role | Saturation | Value | Notes |
|---|---|---|---|
| Sky / haze | about 60 % | about 40 % | Tints the world; floor stays neutral |
| Body (dark) | 30 to 50 % | 10 to 20 % | Tint toward the hue; grey looks unfinished |
| Glow main | 80 to 90 % | 85 to 95 % | Set a little darker and more saturated than wanted; bloom lifts it |
| Glow 2 | hue +-10 to 20 degrees, a little lighter | | For gradients |
| Trim | neutral grey / white, or gold for holy, royal, storm themes | | |
| Accent | one small off-hue touch | | Candle yellow, horn tips |

A second study (outlined "toy" voxel enemies) used: main hue saturation 60 to 80 percent and value 35 to 55 percent, a shadow at value 15 to 25 percent, gold trim, and **one neon hue far from the main hue** (cyan on navy, green on gunmetal, red on teal, lime on purple).

A third (cute companions) used light pastel bodies (value 95 to 100 percent, saturation 15 to 30 percent), one hue per creature in two or three values, and **shared set accents** (white and one pink) that tied very different creatures into one family.

```lua
--!strict
-- Derive a themed palette from one hue (0..1), following the dark-body/neon-line rules above.
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

Many Roblox games tie visuals to rarity (pedestals, stations, gates, pets, chests). A ladder that worked across objects in one style study:

| Rank | Adds | Glow coverage |
|---|---|---|
| 1 | Base only; neon as lines | about 1 % |
| 2 | Full theme colour, main-face glyph, corner caps, small crown, embers | 5 to 16 % |
| 3 | Big crown (halo, portal), flank pieces, skirt (clouds or rubble), floaters | 1 to 8 % |
| 4 | Dense speck skirt, chains, floating planets or rocks, side spires | 4 to 10 % |
| 5 | Biggest crown silhouette, props (skulls, candles), most specks and floaters | 10 to 15 % |

Rules: each tier identifiable from its crown silhouette alone; neighbouring tiers differ in hue by at least 40 degrees or clearly in value; complexity keeps rising even where glow drops. Budget: showcase pieces (one in view) can carry the top tier; anything repeated per player or per zone should stop at rank 2 or 3, or be baked into a few MeshParts.

## Lighting is part of the style

The same assets look like different games under different lighting. Decide lighting with the style, not after:
- **Flat stylised:** bright, low-contrast, soft or no shadows, mild bloom.
- **Neon:** dark ambient, strong bloom (threshold high enough that white trim does not bloom), coloured haze.
- **PBR:** Future lighting, environment specular and diffuse scales tuned so metals do not look plastic.

One production game's "game-ready" material pass also tuned `EnvironmentSpecularScale` 0.75, `EnvironmentDiffuseScale` 0.85, `OutdoorAmbient` (124, 130, 142), haze 0.7 and a light colour-grade tint so the new materials sat together. Details live in [[Lighting Technologies and Settings]] and [[Lighting Mood and Time of Day]].

## Using references

- **Study frames, not impressions.** Step through a reference video frame by frame; sample colours from pixels; estimate sizes against the baseplate stud grid.
- **Write the study down** in the style-guide structure above, with frames saved next to it.
- **Separate what transfers from what is incidental.** One study's video dressed a treadmill in nine themes; the treadmill was irrelevant, the slot system was the lesson.
- **Do not copy assets.** Learn the rules, build your own.

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
[[Voxel and Blocky Modeling]] · [[Stylized Lighting Recipes]] · [[Colour Scripts and Value Structure for Untextured Art]] · [[Lighting Untextured Art in Roblox]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Untextured Stylised Modelling Start Here]]
<!-- auto-links:end -->
