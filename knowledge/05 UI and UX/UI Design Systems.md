---
tags: [ui, design-system, tokens, theming, styling, components, audit]
---
# UI Design Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Colours picked per screen instead of by role.
> - Avoid: A design rule naming a removed font (Gotham).
> - Avoid: Per-panel skins fighting the theme.
> - Tokens for colour roles, type, spacing, radius, stroke, motion.
> - Component builders or style rules; screens never hard-code values.
> - Exceptions are attributes that every pass respects.
>
> Cost: TL;DR ~130 tok · whole note ~4.4k tok. Read more: ## 3. Theme module: one source of truth in code · ## 4. The engine option: UI styling · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A design system is the set of decisions that make forty screens look like one game: a palette with roles, a type scale, spacing and radius steps, a handful of components with defined states, and motion rules. On Roblox it can live in a theme ModuleScript, in the engine's own UI styling system (`StyleSheet`, tokens, themes, queries), or both. This note covers what to put in a system, how to enforce it, the cartoon "simulator" style in concrete numbers, and the tooling that took one production game's 92 screens to a measured 10/10 for positioning and sizing.

Sources: **Docs** ("UI styling", "UI appearance modifiers", `UIStroke`, `UICorner`, `UIGradient`, `CanvasGroup`; October 2026), the **reference project** (one production game), LihFolk's own [[LihFolk UI Spec]], and **rule of thumb**.

---

## 1. What belongs in the system

| Layer | Contents | Example values |
|---|---|---|
| Colour tokens | Surfaces, text, strokes, and **roles** (primary, secondary, premium, danger, gift, disabled) | `surface`, `stroke`, `primary`, `premium` (one named token per role) |
| Type scale | Families, weights, sizes per role | title 38, section 24, button 26, body 15 |
| Spacing | A step scale for padding and gaps | 4, 8, 12, 16, 24, 32 |
| Radii | Corner steps | 4 (cards), 12 (buttons), 18 (cards in a softer look), 0.5 scale (pills) |
| Strokes | Thickness per role and per text size | 3 to 3.5 px panel outlines; text strokes 8 to 15% of size |
| Components | Button, close button, tab, card, header, progress bar, toggle, pill, toast | each with all states |
| States | Default, hover, pressed, selected (gamepad), disabled, claimed, locked | colours, scale, sounds |
| Motion | Durations, easings, scale factors, reduced-motion rules | hover 1.05 in 0.08 s |
| Sound | Click, hover, page turn, purchase, error | one sound per meaning |

The rule that makes it a system rather than a style guide: **screens never hard-code these values.** They call a component builder or reference a token.

---

## 2. A cartoon simulator style, in numbers

The "chunky cartoon" look common in top simulator games only works when it is specified this concretely. LihFolk's own version is in [[LihFolk UI Spec]] (palette, button roles, header themes, type scale, motion, scaling). Whatever kit you use, it must pin down:

- **Window:** one opaque surface colour, a small corner radius, and a dark outer `UIStroke` (`ApplyStrokeMode.Border`). No semi-transparent windows over busy gameplay.
- **Header:** a fixed height, its own colour identity per menu type, and a clear divider so the content area reads as separate.
- **Close button:** one shared component with its own centred `UIScale`, sized for thumbs (see the 72 px lesson below).
- **Buttons:** a role per meaning (go, neutral, premium, danger, done or claimed, locked), each with a face, a darker lip for depth, and every state defined.
- **Type:** one heavy display face for titles and buttons with an outline, plus a readable body face; a fixed size per role.
- **Motion:** centre-anchored elements (`AnchorPoint (0.5, 0.5)`) with a child `UIScale` for hover and press, short ease-outs, and decorative loops that pause when hidden.
- **Responsive:** one `UIScale` per window from a baseline resolution, clamped, with a minimum drawn text size.

Two corrections that apply to many older kits:

- Kits that specify `Enum.Font.GothamBlack` need updating. Gotham has been removed from Roblox and maps to Montserrat (Docs). Use `Font.fromName("Montserrat", Enum.FontWeight.Heavy)` or another explicit heavy face. See [[Text Fonts and Rich Text]].
- A low scale floor (around 0.5) draws 14 px subtitles at about 7 px on small phones. Pair scaling with phone layouts and a 12 px drawn minimum ([[Responsive UI for Phone Tablet Console and PC]]).
### How the reference project adapted it

The reference project adopted this look, then changed the numbers where its own screens demanded:

- **Close button 72 px.** Players on phones missed the 38 to 52 px X. The standard became a 72 px X, which is 1.2 times the 60 px header, pushed 13 px over the header's top and right edges so it reads as a corner badge, with a 52 px glyph. Containers that clipped the X were un-clipped (with the old `ClipsDescendants` stored in an attribute; one attribute opts a screen out).
- **Bigger titles.** Header titles grew to 54 px with a 4.5 px stroke and 74 px side margins.
- **Bevel as the button.** Instead of a separate bevel frame, the button itself is the bevel colour and a "face" child lifted 5 px carries the gradient, a 12 px checker and gloss lines. Pressing sinks the face; this reads well on touch.
- **Roles, not colours.** Buttons take a role (`primary` lime, `secondary` cyan, `premium` amber, `danger` red, `gift` pink, `disabled` silver, `tab` navy). Screens never pick colours.

---

## 3. Theme module: one source of truth in code

```lua
--!strict
-- ReplicatedStorage/UITheme (ModuleScript)
local Theme = {}

Theme.Color = {
	canvas = Color3.fromRGB(59, 88, 102),
	outline = Color3.fromRGB(24, 30, 34),
	card = Color3.fromRGB(26, 44, 52),
	text = Color3.fromRGB(255, 255, 255),
	textMuted = Color3.fromRGB(225, 235, 245),
	ink = Color3.fromRGB(17, 23, 26),
}

export type Role = "primary" | "secondary" | "premium" | "danger" | "gift" | "disabled"

Theme.Roles = {
	primary = { top = Color3.fromRGB(180, 255, 25), bottom = Color3.fromRGB(105, 225, 0), bevel = Color3.fromRGB(15, 120, 15) },
	secondary = { top = Color3.fromRGB(0, 210, 255), bottom = Color3.fromRGB(0, 120, 255), bevel = Color3.fromRGB(0, 60, 130) },
	premium = { top = Color3.fromRGB(255, 208, 0), bottom = Color3.fromRGB(255, 140, 0), bevel = Color3.fromRGB(153, 76, 0) },
	danger = { top = Color3.fromRGB(255, 32, 80), bottom = Color3.fromRGB(208, 0, 32), bevel = Color3.fromRGB(112, 0, 16) },
	gift = { top = Color3.fromRGB(255, 20, 128), bottom = Color3.fromRGB(212, 0, 85), bevel = Color3.fromRGB(120, 10, 45) },
	disabled = { top = Color3.fromRGB(216, 222, 228), bottom = Color3.fromRGB(148, 160, 176), bevel = Color3.fromRGB(72, 82, 96) },
}

Theme.Font = {
	display = Font.fromName("Montserrat", Enum.FontWeight.Heavy),
	button = Font.fromName("FredokaOne"),
	body = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
	bodyBold = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
}

Theme.Size = { title = 38, section = 24, button = 26, body = 16, small = 14 }
Theme.Space = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32 }
Theme.Radius = { card = 4, button = 10, soft = 18 }

Theme.Motion = {
	hover = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	press = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	hoverScale = 1.05,
	pressScale = 0.94,
}

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

-- Builds a role-coloured button: the root is the bevel, the Face is lifted.
function Theme.button(text: string, role: Role, size: Vector2): ImageButton
	local r = Theme.Roles[role]
	local btn = Instance.new("ImageButton")
	btn.Name = text .. "Button"
	btn.Size = UDim2.fromOffset(size.X, size.Y)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = r.bevel
	btn.AutoButtonColor = false
	btn:SetAttribute("Role", role)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.button)
	corner.Parent = btn

	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = Theme.Color.outline
	outline.Thickness = 3
	outline.Parent = btn

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -5) -- 5 px of bevel shows underneath
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Parent = btn
	gradient(face, r.top, r.bottom)
	local faceCorner = corner:Clone()
	faceCorner.Parent = face

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.FontFace = Theme.Font.button
	label.TextSize = math.floor(size.Y * 0.5)
	label.TextColor3 = Theme.Color.text
	label.Parent = face
	local ink = Instance.new("UIStroke")
	ink.Color = Theme.Color.ink
	ink.Thickness = math.max(2, math.floor(label.TextSize * 0.11 + 0.5))
	ink.Parent = label

	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = btn
	return btn
end

return Theme
```

The face is a `Frame` inside the button, so the face's corners are rounded by its own `UICorner` (clipping does not respect corners, see [[ScreenGui Fundamentals]]).

---

## 4. The engine option: UI styling

Roblox has an engine-level styling system "similar to CSS" (Docs):

- A **`StyleSheet`** holds **`StyleRule`s**. A rule has a `Selector` and property overrides set with `SetProperties`.
- **Selectors** match class names (`Frame`), tags (from `CollectionService`), instance names, phantom modifiers (a `UICorner` or `UIStroke` applied by the rule), `GuiState` pseudo-classes such as hover, and **queries** prefixed `@`.
- **Tokens** are attributes on a token `StyleSheet` (for example `Magenta = Color3`), referenced as `"$Magenta"`.
- **Themes** are sheets of tokens with the same names that can be swapped (light and dark, or seasonal).
- A **`StyleDerive`** makes one sheet inherit another; a **`StyleLink`** applies a sheet to a `ScreenGui` tree. Only one sheet applies to a given tree.
- **`StyleQuery`** instances set conditions such as `"MaxSize"` and `"PreferredInput"`, so rules can change with screen size, input type or accessibility settings (Docs). Intrinsic queries like `@ViewportDisplaySizeSmall` and `@PreferredInputTouch` are documented in the cross-platform guide.
- The **Style Editor** in Studio edits all of this visually. It is marked beta in the docs (as of October 2026); the underlying classes are documented as regular engine API.

```lua
--!strict
-- Tag-based rule: every object tagged "PrimaryButton" gets the primary look.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tokens = Instance.new("StyleSheet")
tokens.Name = "Tokens"
tokens:SetAttribute("Primary", Color3.fromRGB(105, 225, 0))
tokens:SetAttribute("Outline", Color3.fromRGB(24, 30, 34))
tokens.Parent = ReplicatedStorage

local sheet = Instance.new("StyleSheet")
sheet.Name = "GameStyle"
local derive = Instance.new("StyleDerive")
derive.StyleSheet = tokens
derive.Parent = sheet
sheet.Parent = ReplicatedStorage

local rule = Instance.new("StyleRule")
rule.Selector = ".PrimaryButton" -- tag selector
rule:SetProperties({
	BackgroundColor3 = "$Primary",
})
rule.Parent = sheet
```

Then link the sheet to each screen with a `StyleLink` whose `StyleSheet` is `sheet`. (Check the selector syntax for tags, names and states against the current `StyleRule.Selector` reference before relying on it; it is the most version-sensitive part.)

### Code theme or engine styling?

| | Theme module | Engine styling |
|---|---|---|
| Works with hand-authored Studio UI | Only through builder passes | Yes, rules apply to existing instances |
| Swappable themes at runtime | You write it | Built in |
| Responds to device and input | You write it | Style queries |
| Complex components (bevel plus face plus gloss) | Natural | Possible but verbose; better built by code and then styled |
| Tooling maturity (Oct 2026) | Yours | Editor in beta |

A reasonable split: components built by code (structure), colours, fonts and sizes from tokens (engine styling or a theme module), never both setting the same property.

---

## 5. Enforcement: why systems decay

Every production UI decays the same way: a new screen is built quickly with hand-picked colours, then a theme pass "fixes" it, then a third person adds a per-panel skin that fights the theme. The reference project's notes record exactly this cycle across a "classic" theme, a "brickline" variant, a blue shop exception, and the cartoon "check" look, with a standing instruction at the top: "New menus: use the Theme painters and they get the look automatically. Don't add per-panel skins that fight it."

What kept it under control:

1. **Painters, not paint.** `Theme.checkHeader(panel, title)`, `Theme.checkClose(panel)`, `Theme.checkPlate(frame, role)`. Screens call painters; painters own every number.
2. **Exceptions are attributes.** A screen that must differ (the shop stayed blue) carries an attribute, and every theme pass checks it before repainting. Opt-outs like `ThemeClaimOff` or `XCornerKeepClip` are explicit and searchable.
3. **Old values in attributes** (`Pre*`) for every automated change, so any pass can be undone.
4. **Saved copies refit.** Painters are run on saved Studio copies too, so Edit mode matches Play mode.
5. **An audit with a score.** See next section.

---

## 6. Auditing a design system automatically

After a player-facing complaint about "a weird extra grey line / box", the reference project built a GUI audit that renders every screen off-screen at 1920 x 1080 and every phone state at 844 x 390 and 667 x 375, and flags:

| Flag | Defect |
|---|---|
| `pocket` | A fill painting past a rounded parent's corners (clipping ignores `UICorner`) |
| `stroke2` | Double outlines (a contextual text stroke plus a border stroke stacking, or a child and parent both outlined) |
| `radius` | Nested rounding mismatches (a child rounded more or less than its parent so edges do not run parallel) |
| `bleed` | Content painting outside its panel (an allow-list covers deliberate cases like slider knobs) |
| `uneven` | Rows in one list with different heights (pop animations excluded) |
| `centre` | Button captions off-centre by more than a pixel (a deliberate `OpticalOffset` attribute is accepted) |

Each screen gets a score out of 10. The average went from defects on most screens to **10.00 over 84 screen-views**, later 92 and 97 as screens were added, and stayed there because every later UI change re-ran the audit. Typical fixes it drove: a header highlight inset by 4 px and the checker tile rounded, an X glyph that had drifted 31% off its face, rarity chips with double fills, a "Clear" button shorter than its "Salvage" neighbour, legacy headers shifted by their panel's `UIPadding`.

The cheapest flags to implement first are `centre` and `uneven` (pure `AbsolutePosition` / `AbsoluteSize` maths) and `pocket` (a rounded ancestor with `UICorner` and a descendant whose rectangle touches its corners with a non-transparent fill).

---

## 7. Components and their states

Specify every state up front; most visual bugs are missing states.

| Component | States |
|---|---|
| Button | default, hover, pressed, gamepad-selected, disabled (`Interactable = false`), loading |
| Claim button | claim, claimed, locked, skip (and "ready" pulse) |
| Tab | idle, active, has-badge, disabled |
| Card | default, selected, equipped, locked, new |
| Toggle | on, off, disabled |
| Progress bar | empty, filling, full, complete-celebration |
| Toast | entering, holding, leaving, merged (same kind within a window) |

Gamepad selection must look like hover at minimum. The reference project mapped selection to the same visual as hover in its motion system and added a gold selection ring to every button for console ([[Gamepad and Console UX]]).

---

## 8. Motion as part of the system

Durations and easings are tokens too. Values that held up in the reference project:

| Interaction | Values |
|---|---|
| Hover | scale 1.06 plus a 3 px lift, plus a faint white wash on filled faces |
| Press | scale 0.9 in 0.08 s; release Back Out 0.3 s |
| HUD tile spring | stiffness about 600, damping ratio about 0.42 (bouncy) |
| Panel open | 0.92 to 1 in 0.14 s (Back Out); some popups 0.82 to 1 in 0.26 s |
| Panel close | 0.12 to 0.14 s Back In to 0.9 |
| Reduced motion | no scale or lift; fades only |

Implementation rule: one on-demand `RenderStepped` connection for springs, connected only while something is moving, zero while idle. More in [[UI and GUI Animation]] and [[Game Feel and Juice]].

---

## Common mistakes

- Colours picked per screen instead of by role.
- A design rule naming a removed font (Gotham).
- Per-panel skins fighting the theme.
- Theme passes with no stored old values.
- Components without disabled, selected or locked states.
- Saved Studio copies left in the old look while code repaints at runtime.
- No automated audit, so drift is found by players.

## Checklist

- [ ] Tokens for colour roles, type, spacing, radius, stroke, motion.
- [ ] Component builders or style rules; screens never hard-code values.
- [ ] Exceptions are attributes that every pass respects.
- [ ] Every automated change stores the previous value.
- [ ] An audit (pocket, double stroke, radius, bleed, uneven, centre) runs after UI changes.
- [ ] Every component has all its states, including gamepad selection.

See also: [[Menu Archetypes - Shop Settings Codes Rewards]], [[HUD Design]], [[Text Fonts and Rich Text]], [[ScreenGui Fundamentals]], [[UI and GUI Animation]], [[Accessibility]], [[Declarative UI - React-Lua and Fusion]].

## Connected notes
<!-- auto-links:start -->
[[UI Asset Pipeline]] · [[LihFolk UI Spec]] · [[Reference - Purple Anime Settings UI (Claude + Figma)]] · [[LihFolk UI Design System]]
<!-- auto-links:end -->
