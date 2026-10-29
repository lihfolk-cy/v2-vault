---
tags: [ui, art-direction, style, theming, references, ai, prompting, design-system, type/guide, area/ui, level/beginner, area/design, api/UIStroke, api/UICorner, api/UIGradient]
verified: 2026-10-29
---
# UI Style Directions - A Visual Vocabulary for Briefs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Briefing a UI with adjectives only ("clean, modern, fun").
> - Avoid: Shipping or tracing art from reference screenshots.
> - Avoid: Judging a style from one screen.
> - Name one style direction, then attach 3 to 5 reference pictures.
> - Say what to take (palette, shape, hierarchy) and what to leave (logos, characters, exact art).
> - Turn the style into theme tokens and test it on the same set of screens.
>
> Cost: TL;DR ~140 tok · whole note ~3.5k tok. Read more: ## 2. Style directions at a glance · ## 3. From a direction to tokens · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A UI brief written only in adjectives gives a person or an AI assistant almost nothing to aim at: "clean and fun" fits a hundred different games. A brief that names a **style direction** (for example "chunky candy" or "parchment fantasy") and attaches a few pictures pins down palette, corner shape, stroke weight, texture and motion in one go. This note gives a shared vocabulary of common Roblox UI directions, how to turn each into theme tokens, and a fixed set of screens to test a style on before committing to it.

Trust labels: **Roblox docs** (class and licence facts), **Rule of thumb** (style descriptions and numbers, which are starting points to tune), **Unverified** where marked.

Source idea: the practice of curating a large, folder-per-style library of UI, VFX and thumbnail references specifically to hand to AI coding assistants, and of mocking up the same set of screens in every style, comes from the public collection [izzyfrm/roblox-ai](https://github.com/izzyfrm/roblox-ai). The wording, tables and code here are LihFolk's own.

---

## 1. Briefing with pictures

A good visual brief has four parts:

1. **One named direction.** Pick a single row from section 2. Mixing two ("cyberpunk kawaii") is fine only when you say which one owns the palette and which one owns the shapes.
2. **Three to five references.** Fewer gives the model nothing to average; more and the brief turns into noise. Your own screenshots and mockups are the strongest references, because they already match your camera, scale and avatar style.
3. **Take and leave lists.** For each picture, say what to borrow and what to ignore:
   - Take: palette, corner shape, stroke weight, layout hierarchy, icon framing, motion feel.
   - Leave: logos, game names, characters, mascots, exact illustrations, exact layouts of a recognisable game.
4. **Constraints the picture cannot show.** Target devices, minimum drawn text size, safe areas, gamepad selection, and your existing theme module if there is one ([[UI Design Systems]], [[Responsive UI for Phone Tablet Console and PC]]).

Then iterate: ask for a first screen, look at it at phone size, and give one round of notes against the references ("stroke too thin compared with picture 2", "panel colour drifts from the palette"). Ask for three directions first when you are unsure, as [[Prompting and Verifying AI Output]] recommends for creative work.

A brief skeleton you can reuse:

```text
Style: <direction from the vocabulary>. Palette owner: <direction>. Shape owner: <direction>.
References attached: 1) <what to take>  2) <what to take>  3) <what to take>
Do not reuse: logos, names, characters or exact artwork from the references.
Targets: phone first, 12 px minimum drawn text, gamepad selection visible, safe areas respected.
Use our theme tokens (ReplicatedStorage.UITheme); add new tokens instead of hard-coding colours.
Deliver: the HUD and the shop screen, then stop for review.
```

---

## 2. Style directions at a glance

All rows are **Rule of thumb** descriptions. Palettes are directions, not exact values; build exact values into tokens (section 3).

| Direction | Palette cue | Shape and stroke | Texture or motif | Fits |
|---|---|---|---|---|
| Studs classic | Saturated blue base, yellow and red accents | Thick dark outline, medium corners | Round stud pattern tiled in panels | Obbies, classic, all-ages |
| Chunky cartoon simulator | Sky blue or slate canvas, lime/cyan/amber role colours | Heavy outline, bevelled buttons, small window radius | Checker or sunburst behind headers | Simulators, pet games ([[LihFolk UI Spec]]) |
| Candy | Hot pink, orange, mint on near-white panels | Very round, fat strokes | Sprinkles, glossy highlights | Food, obby, kid-friendly |
| Kawaii pastel | Soft pink and mint, cream text panels | Pill shapes, near-full radius, thin soft strokes | Bubbles, hearts | Dress-up, cafe, roleplay |
| Tycoon business | Bright green and yellow, blue secondary | Square-ish cards, clear strokes | Hex or grid pattern | Tycoons, idle |
| Parchment fantasy | Tan paper, wax red, gold trim | Ornate frames, small radius | Paper grain, scroll ends | RPG, kingdom, quests |
| Gothic horror | Desaturated darks, one blood or sickly accent | Sharp corners, thin strokes | Fog, grain, vignette | Horror, mystery |
| Survival muted | Forest green, ochre, off-white | Plain rectangles, thin strokes | Fog, scuffed edges | Survival, crafting |
| Pirate | Parchment over deep-sea teal, brick red | Rope or plank frames | Wave lines, map marks | Ocean, adventure |
| Western | Sun-baked tan, rust red, cactus green | Wood-board panels | Wanted-poster type | Western, frontier |
| Anime battle | Magenta and gold on deep purple | Slanted, sharp corners | Burst rays, speed lines | Battlegrounds, fighters |
| Cyberpunk neon | Magenta and cyan on near-black | Thin bright strokes, clipped corners | Faint grid, scanlines | Sci-fi, racing, shooters |
| Space | Starfield navy, violet strokes, gold accents | Rounded, glowing outlines | Stars, planets | Space, exploration |
| Speed and racing | Neon cyan and orange on dark | Skewed panels, italic type | Speed lines, gauge arcs | Racing ([[Race HUD - Position, Laps, Splits, Speedometer and Minimap]]) |
| Sports scoreboard | Team colours, white, black | Angled ribbons, bold blocks | Scoreboard bars | Sports |
| Tower defense | Olive and moss, amber highlights | Sturdy squares | Hex grid | TD, strategy |
| Winter holiday | Icy blue, white panels, red accents | Rounded, soft strokes | Snowflakes, frost edges | Seasonal events |
| Retro pixel | Red and yellow on navy | Square corners, stepped pixel borders | Pixel icons, nearest-neighbour scaling | Arcade, 2D ([[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]) |
| Glass | Soft violet or blue gradient | Rounded, white hairline strokes | Frosted light panels | Menus, lobbies (see the caution below) |
| Dark pro | Flat dark greys, one blue and one green accent | Small radius, thin strokes | None | Competitive, tools, settings |

Cautions that apply across rows:

- **Dark and neon styles fail contrast first.** Check body text against its panel and keep the accent for highlights, not paragraphs ([[Accessibility]]).
- **Glass over gameplay.** Roblox has no background blur behind a `Frame`, so "frosted" is faked with a light, mostly opaque panel and a soft gradient. Keep panels nearly opaque over busy scenes (Rule of thumb: background transparency at or below about 0.15), or text becomes unreadable.
- **Pixel styles need crisp scaling.** Set `ResampleMode` to `Pixelated` on pixel images and scale by whole numbers where you can.
- **Horror darkness belongs to the world, not the menus.** A dim world with a clear, readable menu is easier to play than a dim menu.

---

## 3. From a direction to tokens

A direction becomes real when it fills the same token slots as every other style. Keeping one shape for all presets lets you swap a game's look, or A/B two looks, without touching screens.

```lua
--!strict
-- ReplicatedStorage/UIStylePresets (ModuleScript)
-- Each preset fills the same slots; screens read tokens, never preset names.
export type Preset = {
	canvas: Color3,
	panel: Color3,
	stroke: Color3,
	text: Color3,
	accent: Color3,
	cornerRadius: UDim,
	strokeThickness: number,
	titleFont: Font,
	bodyFont: Font,
	pressScale: number, -- child UIScale value while pressed
}

local Presets: { [string]: Preset } = {
	candy = {
		canvas = Color3.fromRGB(255, 236, 244),
		panel = Color3.fromRGB(255, 255, 255),
		stroke = Color3.fromRGB(196, 52, 120),
		text = Color3.fromRGB(70, 20, 50),
		accent = Color3.fromRGB(255, 140, 40),
		cornerRadius = UDim.new(0, 18),
		strokeThickness = 4,
		titleFont = Font.fromEnum(Enum.Font.LuckiestGuy),
		bodyFont = Font.fromEnum(Enum.Font.FredokaOne),
		pressScale = 0.92,
	},
	parchment = {
		canvas = Color3.fromRGB(58, 40, 28),
		panel = Color3.fromRGB(232, 214, 176),
		stroke = Color3.fromRGB(120, 78, 36),
		text = Color3.fromRGB(52, 34, 20),
		accent = Color3.fromRGB(158, 36, 36),
		cornerRadius = UDim.new(0, 4),
		strokeThickness = 3,
		titleFont = Font.fromEnum(Enum.Font.Fondamento),
		bodyFont = Font.fromEnum(Enum.Font.Merriweather),
		pressScale = 0.96,
	},
	neon = {
		canvas = Color3.fromRGB(10, 8, 18),
		panel = Color3.fromRGB(22, 18, 36),
		stroke = Color3.fromRGB(0, 230, 255),
		text = Color3.fromRGB(235, 240, 255),
		accent = Color3.fromRGB(255, 40, 200),
		cornerRadius = UDim.new(0, 2),
		strokeThickness = 1.5,
		titleFont = Font.fromEnum(Enum.Font.Michroma),
		bodyFont = Font.fromEnum(Enum.Font.TitilliumWeb),
		pressScale = 0.97,
	},
}

local UIStylePresets = {}

-- Apply the panel part of a preset to one frame (corner + stroke + colour).
function UIStylePresets.stylePanel(frame: Frame, preset: Preset)
	frame.BackgroundColor3 = preset.panel
	frame.BackgroundTransparency = 0

	local corner = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = preset.cornerRadius
	corner.Parent = frame

	local stroke = frame:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = preset.stroke
	stroke.Thickness = preset.strokeThickness
	stroke.Parent = frame
end

function UIStylePresets.get(name: string): Preset
	local preset = Presets[name]
	assert(preset, "unknown UI style preset: " .. name)
	return preset
end

return UIStylePresets
```

Notes on the example:

- Fonts are built with `Font.fromEnum`, which returns a `Font` for the `FontFace` property (Roblox docs). Gotham-based kits need a different heavy face; see [[Text Fonts and Rich Text]].
- `ApplyStrokeMode.Border` outlines the frame rather than its text (Roblox docs).
- The engine's own UI styling system (`StyleSheet` and tokens) can hold the same slots instead of a module; [[UI Design Systems]] compares the two.

---

## 4. The nine-screen style test

One screen flatters almost any style. Mock up the **same nine screens** for each candidate direction and compare them side by side at phone size:

| # | Screen | What it exposes |
|---|---|---|
| 1 | HUD | Readability over gameplay, currency pill, small icons |
| 2 | Shop | Card density, price emphasis, premium role colour |
| 3 | Inventory | Grid at 30+ items, rarity colours against the panel |
| 4 | Settings | Toggles, sliders, long text rows |
| 5 | Loading screen | Logo-free identity, progress bar |
| 6 | Reward popup | Celebration without losing the palette ([[Game Feel and Juice]]) |
| 7 | Leaderboard | Numbers, rank colours, tight rows |
| 8 | Dialogue box | Long text, name tag, choice buttons |
| 9 | Palette card | All tokens on one sheet: roles, strokes, type scale |

Rule of thumb: a direction that survives screens 3, 4 and 7 (the dense ones) is a direction you can ship; the showcase screens (5 and 6) rarely decide it. Menu layouts for 2, 4 and 6 are in [[Menu Archetypes - Shop Settings Codes Rewards]].

Source idea: testing every style on one fixed screen set comes from the style mockups in [izzyfrm/roblox-ai](https://github.com/izzyfrm/roblox-ai).

---

## 5. Where references come from, and what you may do with them

| Source | Use as a reference for yourself or an AI | Ship or upload |
|---|---|---|
| Your own screenshots and mockups | Yes, the best kind | Yes, they are yours |
| Roblox creator documentation images | Yes | The Roblox/creator-docs repository is licensed CC BY 4.0 (checked 2026-10-29), so reuse needs attribution |
| CC0 UI kits (for example Kenney's UI packs) | Yes | Yes; credit is optional under CC0 but appreciated ([[Links - Free and CC0 asset libraries]]) |
| Public thumbnails and gameplay screenshots of other games | Yes, for study | No: rights stay with their creators; do not upload, trace or recreate their artwork |
| Community art posts and packs | Yes, for study | Only under the licence the creator states |

Feeding a picture to an AI assistant as a reference is not the same as having a licence to its contents. Keep the final art original and log any third-party pieces you do ship ([[Legal Basics - IP Licenses and Assets]]).

---

## Common mistakes

- Briefing a UI with adjectives only ("clean, modern, fun").
- Shipping or tracing art from reference screenshots.
- Judging a style from one screen.
- Mixing two directions without saying which one owns the palette.
- Picking a dark or neon direction without a contrast check on body text.
- Building a style per screen instead of filling the same token slots.

## Checklist

- [ ] Name one style direction, then attach 3 to 5 reference pictures.
- [ ] Say what to take (palette, shape, hierarchy) and what to leave (logos, characters, exact art).
- [ ] Turn the style into theme tokens and test it on the same set of screens.
- [ ] Body text passes a contrast check on its panel colour.
- [ ] Glass panels stay nearly opaque over gameplay; pixel images use `Pixelated` resampling.
- [ ] Every shipped third-party image is in the licence log.

## See also

[[UI Design Systems]] · [[LihFolk UI Spec]] · [[LihFolk UI Design System]] · [[HUD Design]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Text Fonts and Rich Text]] · [[Accessibility]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Prompting and Verifying AI Output]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[Environment Art Styles]] · [[Style Bibles for Consistent Models]] · [[Legal Basics - IP Licenses and Assets]] · [[Links - Free and CC0 asset libraries]]

<!-- related:start -->
## Related
[[Layout - Scale Offset and Constraints]] · [[UI Motion Language and Timing]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Gamepad and Console UX]] · [[ScreenGui Fundamentals]] · [[Virtualized Lists and Large Inventories]] · [[UI Layout Objects - Lists Grids and Pages]] · [[World-Space UI - BillboardGui and SurfaceGui]]
<!-- related:end -->
