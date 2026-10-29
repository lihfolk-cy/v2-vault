---
tags: [ui, figma, design, safe-area, tokens, components, mobile, type/guide, area/ui, level/beginner, area/design, api/Frame]
---
# Designing Roblox UI in Figma - Frames, Safe Areas and Tokens

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Designing only at 1920 x 1080 and never pasting the panel into a 667 x 375 frame.
> - Avoid: Buttons under the top bar band or in the bottom-left thumb zone on phones.
> - Avoid: Text smaller than 15 design px, which draws under 12 px on phones.
> - Every frame at 1920 x 1080, with a `skip_safe_area` guide layer.
> - Each panel pasted into a 667 x 375 frame; still readable, or a phone arrangement planned.
> - Text at least 15 design px; taps at least 52 design px; gaps at least 10.
>
> Cost: TL;DR ~160 tok · whole note ~2.6k tok. Read more: ## 3. Auto layout habits that convert cleanly · ## 5. Variables and styles become theme tokens · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Figma file that is easy to turn into Roblox UI is drawn with the engine in mind:
- one reference resolution;
- the Roblox top bar and phone cut-outs marked;
- auto layout wherever something is a list;
- variables for every repeated value;
- one component set per control, with all its states;
- layer names that tell the converter what each layer becomes.

This note is the designer's half of the pipeline. The build half is [[Figma to Roblox UI - Pipeline and Handoff]], and every property's exact translation is in [[Figma Property Mapping for Roblox UI]].

The engine rules behind these habits are in:
- [[Safe Areas and Insets]];
- [[Responsive UI for Phone Tablet Console and PC]];
- [[Layout - Scale Offset and Constraints]];
- [[Text Fonts and Rich Text]];
- [[Accessibility]].

The LihFolk house look, if you are matching it, is [[LihFolk UI Spec]].

Sources: **Docs** (Roblox engine reference and the Figma REST field reference; October 2026), the **reference project** numbers already in the linked vault notes, and **rule of thumb** where marked.

---

## 1. Frames and the reference resolution

| Frame | Size | Use |
|---|---|---|
| Desktop reference | 1920 x 1080 | Design every screen here; it is the converter's default `--reference` |
| Phone check | 667 x 375 | The smallest common landscape phone; panels must still read here |
| Phone, common | 844 x 390 | The main phone target, with a notch on one side |
| Tablet | 1024 x 768 | Touch, mid-size |

Draw panels at the 1920 x 1080 size. In game, one `UIScale` scales them by `min(width / 1920, height / 1080)`. That scale is clamped so the smallest text still draws at 12 px. So:
- **Smallest text 15 design px.** At the 0.8 scale floor that keeps it at 12 px drawn. Text at 12 design px needs a scale of 1.0, which no phone reaches.
- **Smallest tap target 52 design px.** It stays at or above 44 px drawn at a 0.85 scale.
- **Gaps between taps at least 10 design px.**

Paste each panel into the 667 x 375 frame at about 0.35 scale (667 / 1920). If it becomes unreadable there, plan a phone arrangement: pages instead of side-by-side panes, horizontal tab strips, fewer columns. Shrinking further is not the answer. See [[Responsive UI for Phone Tablet Console and PC]].

---

## 2. Safe areas: mark them on every frame

Make a locked guide layer named `skip_safe_area` in each frame. The converter ignores `skip_` layers.

| Zone | Size on the frame | Source |
|---|---|---|
| Roblox top bar | A band about 60 px tall across the top | Read live in game from `GuiService.TopbarInset`; around 58 px on desktop is the commonly reported value (unverified) |
| Notch side (phones) | About 60 px on the left or right in landscape | The Roblox docs' `GetInsetArea` example on a phone reports a 59 px left inset |
| Home indicator | About 20 px at the bottom (rule of thumb) | Device safe area |
| Movement thumb zone | The bottom-left quarter of the phone frame (rule of thumb) | Default touch thumbstick |
| Jump and action zone | The bottom-right quarter (rule of thumb) | Default jump button and combat buttons |
| TV overscan | About 5% of each edge (rule of thumb) | Older TVs |

Interactive things stay inside the safe area. Full-bleed art (backgrounds, vignettes, letterbox bars) goes in its own frame. It becomes a separate ScreenGui with `ScreenInsets.None` and must not contain buttons.

---

## 3. Auto layout habits that convert cleanly

- **Lists are auto layout.** Rows, tab bars, button groups and card grids all use auto layout. Hand-placed rows turn into hand-maintained Luau.
- **Spacing and padding come from the token steps:** 4, 8, 12, 16, 24, 32. `itemSpacing` becomes `UIListLayout.Padding` and the paddings become `UIPadding`.
- **Hug and Fill mean what they say.**
  - Hug text and buttons that should grow with translations; they become `AutomaticSize`.
  - Fill the one flexible child in a row; it becomes a `UIFlexItem` set to `Fill`.
  - Fixed is for art.
- **Space between** becomes flex `SpaceBetween`; Figma ignores the spacing value in that mode, and so does the converter.
- **Wrap** becomes `UIListLayout.Wraps`. Keep the row gap equal to the column gap, because Roblox lists have one `Padding`.
- **Avoid in auto layout frames:**
  - absolutely positioned children (they force an extra wrapper frame);
  - `GRID` auto layout (rebuild grids with `UIGridLayout`);
  - baseline alignment (it becomes centre).
- **Constraints on non-auto-layout children:**
  - `Left` and `Right` pin to an edge.
  - `Left and right` stretches.
  - `Center` stays centred.
  - `Scale` stays proportional.

  Pick them on purpose: they become the `AnchorPoint` and Position.

---

## 4. Layer names the converter reads

| Prefix | Becomes | Example |
|---|---|---|
| `btn_` | `TextButton` (or `ImageButton` with an image fill) | `btn_save`, `btn_close` |
| `img_` | One exported PNG for the whole layer and its children | `img_coin_icon` |
| `9s_` | A 9-slice `ImageLabel`. `__24` sets a 24 px slice inset | `9s_panel_frame__24` |
| `scroll_` | `ScrollingFrame` with automatic canvas size | `scroll_items` |
| `skip_` | Nothing (guides, notes, redlines) | `skip_safe_area` |

Other names become `Instance.Name` as written. Use plain, stable names (`header`, `row_music`, `title`), because scripts find objects by these names. A layer called "Frame 427" produces a `Frame 427` instance that nobody can find.

---

## 5. Variables and styles become theme tokens

Every value used twice is a Figma variable or style:

| Figma | Example names | Roblox token |
|---|---|---|
| Colour variables | `color/ink`, `color/surface`, `color/surface-raised`, `color/text-hi`, `role/go/top` | `Tokens.Color.ink` (a `Color3`) |
| Number variables | `radius/panel` 22, `radius/button` 12 | `UICorner` radius |
| Number variables | `space/m` 12, `space/l` 16 | Padding and spacing |
| Number variables | `stroke/card` 3 | `UIStroke.Thickness` |
| Text styles | `type/title` (Fredoka One 26), `type/body` (Builder Sans Bold 18) | `FontFace` + `TextSize` + outline |
| Modes | `light` / `dark`, or one accent per menu | One token table per mode |

With the Figma MCP, `get_variable_defs` reads these directly. The `lihfolk-figma` skill's `examples/FigmaThemeTokens.luau` shows the module shape. Builders and components read tokens; screens never contain raw colours. See [[UI Design Systems]].

**Fonts.** Choose from the families Roblox ships so nothing is substituted:
- Builder Sans: the Roblox interface face, many languages;
- Montserrat: weights 100 to 900;
- Fredoka One: round display;
- Nunito;
- Roboto;
- Source Sans Pro;
- Oswald;
- Luckiest Guy;
- and others listed in the mapping note.

Also:
- Letter spacing has no `TextLabel` property. Leave it at 0, or bake display lettering into an image.
- Keep line height between 100% and 300% of the font size.

---

## 6. Components and variants become states

Build each control as one component set with a `State` property:

| Variant | Must show | Roblox driver |
|---|---|---|
| `Default` | Resting look | none |
| `Hover` | A small lift or highlight | `MouseEnter` / `MouseLeave` |
| `Pressed` | A sunk face or a darker swatch | `InputBegan` / `InputEnded` |
| `Disabled` | Muted, plus a word or icon (LOCKED, a lock) | `Active = false` |
| `Selected` | A **gamepad focus ring** around the control | `SelectionImageObject` |

Add a second property for role (`Go`, `Neutral`, `Danger`, `Premium`) instead of drawing separate components. The converter writes the placed variant as attributes (`Variant_State`, `Variant_Role`), and one Luau component function draws all of them. Colour is never the only difference between states: pair it with lightness and a word or glyph ([[Accessibility]]).

---

## 7. Effects and images

- **One drop shadow per node.** It becomes a tinted 9-slice image under the node.
- **Bake** inner shadows, layer blur, background blur, blend modes and noise into an `img_` layer. Roblox UI has none of these.
- **Exports:**
  - PNG at 2x. Keep the long side at or under 1024 px, Roblox's upload limit; the converter lowers the scale for large art.
  - Trim empty transparent edges; leave 2 px for soft edges.
  - Export icons white or greyscale when they will be tinted in game with `ImageColor3`.
- **9-slices:** draw the frame art at its smallest sensible size with the corners intact. The inset (the corner size that must not stretch) goes in the name, `9s_frame__24`.
- **Image memory:** every image is a texture. UIGradient, UIStroke and UICorner rebuild most rims, bevels and glows with no images at all ([[Textures Decals and Texture Memory]]).

---

## Common mistakes

- Designing only at 1920 x 1080 and never pasting the panel into a 667 x 375 frame.
- Buttons under the top bar band or in the bottom-left thumb zone on phones.
- Text smaller than 15 design px, which draws under 12 px on phones.
- Hand-placed rows instead of auto layout, and layers named "Frame 427".
- Fonts Roblox does not ship, and letter spacing that cannot be reproduced.
- Only the Default variant drawn; no gamepad focus ring.
- Blurs and inner shadows left live, expecting the engine to draw them.
- Exporting 4x art over 1024 px, or every icon at a different scale.

## Checklist

- [ ] Every frame at 1920 x 1080, with a `skip_safe_area` guide layer.
- [ ] Each panel pasted into a 667 x 375 frame; still readable, or a phone arrangement planned.
- [ ] Text at least 15 design px; taps at least 52 design px; gaps at least 10.
- [ ] Auto layout for every list; spacing from the token steps; Hug and Fill set on purpose.
- [ ] Layer prefixes `btn_`, `img_`, `9s_name__N`, `scroll_`, `skip_` used; other layers named plainly.
- [ ] Colours, radii, spacing, strokes and type are variables or styles.
- [ ] Every control a component set with Default, Hover, Pressed, Disabled and Selected.
- [ ] Effects that Roblox cannot draw baked into `img_` layers; exports at most 1024 px.

<!-- related:start -->
## Related
[[UI Asset Pipeline]] · [[Settings Menu Design for Roblox - Layout, Controls and Motion]] · [[AI Pitfalls - UI and Input]] · [[UI Layout Objects - Lists Grids and Pages]] · [[ScreenGui Fundamentals]] · [[Gamepad and Console UX]] · [[HUD Design]] · [[Virtualized Lists and Large Inventories]] · [[UI Style Directions - A Visual Vocabulary for Briefs]] · [[Menu Archetypes - Shop Settings Codes Rewards]]
<!-- related:end -->
