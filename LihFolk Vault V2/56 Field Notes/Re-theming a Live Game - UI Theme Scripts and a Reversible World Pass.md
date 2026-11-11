---
tags: [field-notes, ui, theming, colour, fonts, world-art, lighting, type/guide, area/ui, level/intermediate, area/lighting]
---
# Re-theming a Live Game - UI Theme Scripts and a Reversible World Pass

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Gradient in the same colour as the background -> White base, colours in the gradient (or a white-to-grey shade)
> - Avoid: Moving a bar across a rotated button -> Animate a gradient's Offset inside a full-size child
> - Avoid: One text cap for every button -> Exempt big buttons
> - Theme scripts per concern (colour, font, button finish, window skin) plus shared helpers.
> - Colour map checked for target-key clashes after every edit.
> - Sweep run for off-palette panels on every screen.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 1. The pattern: theme scripts, not rewrites · ## 2. The six traps · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A finished Roblox game with 30 screens built by about 25 scripts got a complete new look in one day: a new palette, new fonts, a new button and panel style, and a matching lobby and map. Rewriting every screen would have taken weeks and broken things. Instead, a handful of small client scripts restyle every screen as it appears, and one reversible pass recolours the world. This note gives the pattern, the six traps that cost the most time, and the numbers.

Source labels: **Measured** (a social-deduction party game, November 2026: 30 ScreenGuis, about 4,400 world parts), **Roblox docs**, **Rule of thumb**.

---

## 1. The pattern: theme scripts, not rewrites

Each concern is one LocalScript in StarterPlayerScripts that watches `PlayerGui.DescendantAdded` and fixes things as they appear (and again when a script changes them):

| Script | Job |
|---|---|
| Colour map | Old colour (exact RGB) to new palette colour, for `BackgroundColor3`, `TextColor3`, `UIStroke.Color`. Re-applies on property change, so hover and selected states follow. |
| Font map | Old `Enum.Font` to a `Font` (family + weight); headings and body get different families. |
| Button finish | Edge, shading, 3D ledge, Title Case labels, a cap on stretched text. |
| Window skin | Finds menu windows (a title and an X in the top strip) and gives them the window style and a pop-in. |
| Shared helpers (ModuleScript) | The ledge, the darker edge colour and Title Case, so every script draws them the same way. |

Rules that kept it safe:

- **No target may also be a key** in the colour map, or a value keeps changing. Check it in code after every edit (**Measured**: about 90 pairs, 0 clashes).
- **Sweep for colours the map misses.** List every distinct dark background in every screen that isn't in the new family; it found 10 panels the first pass missed (**Measured**).
- **Screens that build before the theme scripts run** (a `ReplicatedFirst` loading screen) must set their own colours and fonts.

## 2. The six traps

**1. Gradients multiply.** A `UIGradient` multiplies with `BackgroundColor3`. A coral gradient on a coral frame came out hot red; a teal-night gradient on a teal-night frame came out almost black. Fix: white `BackgroundColor3` with the colours in the gradient, or a white-to-light-grey gradient over the true colour (**Measured**).

**2. Rotated objects don't clip children.** A shine bar sliding across slightly tilted menu buttons spilled out beside them: `ClipsDescendants` stops working on a rotated object (**Measured**). Fix: a full-size see-through child with a narrow bright band in its `UIGradient.Transparency`, and tween the gradient's `Offset`. It never leaves the button's shape.

**3. The 3D ledge without breaking layouts.** A darker band along a button's bottom edge, drawn as a full-size child frame whose gradient transparency steps from 1 to 0 at `1 - px / height`. It follows rounded corners and never changes the button's size (safe inside list layouts). Squash it on `MouseButton1Down` for a press.

**4. A text cap can shrink the hero.** A `UITextSizeConstraint` (max 22 px) made rows of tabs read evenly, and also shrank the title screen's giant PLAY to a small word in a big box. Fix: exempt buttons taller than about 60 px.

**5. Phones put Roblox's top bar over your UI.** Wide windows and a centred loading screen reached under the Roblox menu and chat buttons on a landscape phone (the game's own overlap check can't see them). Fix: offset by `GuiService:GetGuiInset().Y` (or `TopbarInset`) and size to the height that's left.

**6. Picking the "title" by size.** The window skin took a big dice icon starting inside the top strip for the window's title. Fix: a title must contain letters, sit wholly in the strip and be heading-sized.

Two small ones: `Enum.FontWeight.Black` does not exist (it errored and stopped the font script); `Font.fromEnum(Enum.Font.DenkOne).Family` gives the family path to use with a weight.

## 3. The world pass: by colour family, reversible, with meaning kept

Matching the 3D world to the UI by hand would mean touching thousands of parts. A colour-family pass did it in one run:

- Classify each part's colour by hue, saturation and value; map families (gold trims, navy, periwinkle, salmon/red, near-black) to palette roles. Leave whites, grass, foliage, water, wood and sand alone (**Measured**: 1,084 of about 4,400 parts changed).
- **Store the old colour on the part** (an attribute) before changing it, so the whole pass can be undone or reviewed.
- **Then review by object name.** A family rule can't know that a golden egg must stay gold. List the changes grouped by the owning model and put back anything whose colour carries meaning: collectibles, straw and rope, warning yellow, barn red, fire-extinguisher and emergency red (**Measured**: 73 parts in 15 kinds of object). Mark them with the reason so a later pass skips them.
- Do the hero last: the goal of the space (here a PLAY gate) gets the brightest highlight colour so the eye goes there from spawn ([[Level Design Principles - Flow Sightlines and Landmarks]]).
- Re-grade the lighting to the new palette: warm light on top, cool ambient in the palette's hue, so contrast survives on phones without shadows ([[Stylized Lighting Recipes]]).

## Numbers (Measured)

| Item | Count |
|---|---:|
| Screens restyled without rewriting their scripts | 30 |
| Colour pairs in the map / target-key clashes | about 90 / 0 |
| Off-palette panels found by the sweep | 10 |
| Player-facing em dashes rewritten by hand | 69 |
| World parts recoloured / put back for meaning | 1,084 / 73 |
| Lobby overlaps on a landscape phone after the fixes | 0 |

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Gradient in the same colour as the background | Colours come out hotter or almost black | White base, colours in the gradient (or a white-to-grey shade) |
| Moving a bar across a rotated button | The shine spills outside the button | Animate a gradient's Offset inside a full-size child |
| One text cap for every button | Hero buttons show tiny text | Exempt big buttons |
| Ignoring Roblox's top bar | Windows tucked under the menu and chat buttons on phones | Offset by the gui inset |
| Recolouring the world by family only | Golden eggs turn green, emergency buttons turn orange | Review by object name; keep colours that carry meaning |
| No record of old colours | A bad pass can't be undone | Store the old colour on each part first |

## Checklist

- [ ] Theme scripts per concern (colour, font, button finish, window skin) plus shared helpers.
- [ ] Colour map checked for target-key clashes after every edit.
- [ ] Sweep run for off-palette panels on every screen.
- [ ] Gradients white-based; no same-colour gradients.
- [ ] No moving children on rotated objects; gradient sweeps instead.
- [ ] Big buttons exempt from text caps.
- [ ] Every full-screen layout offset below the gui inset on phones.
- [ ] World pass stores old colours; meaningful colours reviewed and kept.
- [ ] Hero of each space gets the brightest highlight; lighting re-graded to the palette.

## See also

[[Settings Menu Design for Roblox - Layout, Controls and Motion]] · [[Responsive UI for Phone Tablet Console and PC]] · [[World Composition and Set Dressing - Designed, Not Scattered]] · [[Zone and Biome Art Direction]] · [[Stylized Lighting Recipes]] · [[Field Notes Start Here]]

<!-- related:start -->
## Related
[[UIStroke on Text - Glyph Counters and the Stroke Ratio]] · [[Centre-Screen Announcements That Stay Centred]] · [[Shared Close Buttons and Headers Across Many Screens]] · [[3D Text Signs in Blender - Passing the Mesh Gates]] · [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]] · [[Shift-Lock Sprint and Gamepad B for Menus]] · [[Moving Data Out of a Play Session]] · [[Springs That Survive Long Frames - dt Clamps and NaN Guards]]
<!-- related:end -->
