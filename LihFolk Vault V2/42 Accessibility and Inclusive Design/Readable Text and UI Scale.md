---
tags: [accessibility, text, typography, ui-scale, readability, ui, localization, testing, type/guide, area/accessibility, level/intermediate, api/UIScale]
---
# Readable Text and UI Scale

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `TextScaled` for content, so the player's text size does nothing.
> - Avoid: Fixed-height text boxes that clip at `Largest`.
> - Avoid: Tight `MaxTextSize` constraints on body text.
> - Rendered body text meets the minimums for each device class, measured, not assumed.
> - One `UIScale` controller combines device base and player preference, clamped to fit.
> - No content text uses `TextScaled`; constraints on body text are generous.
>
> Cost: TL;DR ~150 tok · whole note ~5.2k tok. Read more: ## 2. Three scales that multiply · ## 6. An automated text audit · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Accessibility]] explains how `GuiService.PreferredTextSize` changes text and which text setups ignore it. [[Responsive UI for Phone Tablet Console and PC]] covers device classes and the shipped phone rules. This note sits between them: how big text actually needs to be on each device in physical terms, how the engine's text scaling, your device `UIScale` and a player "UI size" slider stack (and where they fight), layouts that grow instead of clipping, type choices that help low-vision and dyslexic players, world-space text, and an automated audit that finds clipped labels before players do.

Sources: **Roblox docs (as of October 2026)** for engine behaviour (`GuiService`, `TextLabel`, `TextService`, `UIScale`), **measured in the reference project** where noted (anonymised), and **rule of thumb** for sizes and thresholds.

---

## 1. Readability is physical, not pixels

A 14 px label is comfortable on a laptop at arm's length, tiny on a 6 inch phone held at 30 cm, and unreadable on a TV across a room. What matters is the angle the text covers in the player's eye, which depends on the physical screen size, its pixel density, the viewing distance, and the scale factor between your authored pixels and real pixels.

Roblox gives you two useful signals here (Roblox docs, as of October 2026):

- `GuiService.ViewportDisplaySize` returns `Small`, `Medium` or `Large`, described as the physical rendering size of the viewport. It is the closest thing the engine gives you to "is this a phone?".
- `UserInputService.PreferredInput` returns the primary input the player is likely using (`Touch`, `Gamepad`, `KeyboardAndMouse`). A gamepad on a large display usually means a TV at couch distance.

Neither tells you the viewing distance. That is why a player-facing UI size setting matters even after you have a good device-based scale: you cannot measure the sofa.

### Working minimums

These are the sizes that the reference project converged on and that match common platform guidance (measured in the reference project for phones; rule of thumb elsewhere). They are **rendered** sizes after every scale has been applied, which is what you must measure.

| Context | Body text minimum | Small labels (captions, counters) | Titles |
|---|---|---|---|
| Phone (Small) | 14 px | 12 px (hard floor) | 20 px or more |
| Tablet (Medium) | 15 px | 12 px | 22 px or more |
| Desktop at arm's length | 14 px | 11 px | 20 px or more |
| TV / console (Large plus gamepad) | 24 px | 18 px | 32 px or more |

Docs set `MinTextSize` floors at 9 in their own guidance, which is a technical floor rather than a reading target. For players who raise their Roblox text size, these minimums grow automatically if your layout lets them.

---

## 2. Three scales that multiply

Most games end up with three independent sources of scale. Knowing how they combine prevents both "my text is enormous" and "my slider does nothing" bugs.

| Scale | Who sets it | What it affects | Notes |
|---|---|---|---|
| Engine preferred text size | Player, in Roblox settings | Text only, for fixed `TextSize` labels | Ignored by `TextScaled`; respects `UITextSizeConstraint` bounds (Roblox docs, as of October 2026) |
| Device `UIScale` | You, from viewport and device | Everything under the `UIScale` | Usually one `UIScale` per `ScreenGui` |
| Player UI size | Player, in your settings | Everything, multiplied into the device `UIScale` | Clamp it |

The interactions to know:

1. **`UIScale` multiplies text, including enlarged text.** A label authored at 14 px, enlarged by the player's `Largest` preference, under a `UIScale` of 1.2, renders larger than either alone. That is usually what you want, but it means a big player UI size plus `Largest` can push long text out of fixed containers. Test the corner case, not just each setting alone.
2. **`TextScaled` defeats both text preferences.** The engine scales `TextScaled` text to fit its box, up to a maximum font size of 100 (Roblox docs, as of October 2026), regardless of the preferred text size. A `UIScale` still changes the box, so it still changes the text, but the player's text size setting does nothing. Use `TextScaled` only for decorative display text, never for content.
3. **`UITextSizeConstraint` clamps the preference.** The engine keeps the constraint's `MinTextSize` and `MaxTextSize` regardless of the preferred text size (Roblox docs, as of October 2026). A tight `MaxTextSize` on body text silently disables the accessibility setting for that label.
4. **Offsets do not scale unless a `UIScale` is above them.** Fixed pixel paddings, strokes and corner radii authored in offsets stay the same unless they live under the `UIScale`. Put every `UIScale` at the top of the tree so all offsets scale together.

### A combined scale controller

```lua
--!strict
-- UiScaleController: one place that computes the UIScale for every ScreenGui.
-- final = deviceBase * playerPreference, clamped so a reference panel still fits on screen.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiScaleController = {}

local REF_PANEL = Vector2.new(720, 520) -- the largest panel that must always fit, in authored px
local MARGIN = 0.92 -- leave 8% of the viewport free around it
local PLAYER_MIN, PLAYER_MAX = 0.8, 1.4

local playerPref = 1
local scales: { UIScale } = {}

local function deviceBase(viewport: Vector2): number
	local size = GuiService.ViewportDisplaySize
	local onTv = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
		and size == Enum.DisplaySize.Large
	-- Rule-of-thumb bases; tune against measured rendered sizes on real devices.
	if size == Enum.DisplaySize.Small then
		return 0.85
	elseif onTv then
		return 1.5
	end
	return math.clamp(viewport.Y / 900, 0.9, 1.25)
end

local function compute(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local usable = Vector2.new(viewport.X, viewport.Y - inset.Y)
	local wanted = deviceBase(viewport) * playerPref
	local fit = math.min(usable.X * MARGIN / REF_PANEL.X, usable.Y * MARGIN / REF_PANEL.Y)
	return math.min(wanted, fit)
end

local function applyAll()
	local s = compute()
	for _, scale in scales do
		scale.Scale = s
	end
end

function UiScaleController.register(gui: ScreenGui): UIScale
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	table.insert(scales, scale)
	scale.Scale = compute()
	return scale
end

function UiScaleController.setPlayerPreference(value: number)
	playerPref = math.clamp(value, PLAYER_MIN, PLAYER_MAX)
	applyAll()
end

function UiScaleController.start()
	local function hookCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyAll)
		end
		applyAll()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
	GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(applyAll)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(applyAll)
	hookCamera()
end

return UiScaleController
```

Notes on the design:

- **The fit clamp wins over the player.** If a player picks 140% on a small phone, the controller gives them the largest scale that still fits the reference panel. Without the clamp, a UI size slider is a way to lock yourself out of the close button. Show the effective value next to the slider ("140% (limited to 118% on this screen)") so the player understands.
- **`ViewportDisplaySize` can change at runtime**: docs suggest listening with `GetPropertyChangedSignal` to adapt UI, without saying what triggers a change (Roblox docs, as of October 2026). The listener costs nothing.
- **Reacting to `PreferredInput`** handles the player who plugs a controller into a laptop connected to a TV. Debounce it if your UI animates on scale changes.

---

## 3. Layouts that grow

Text that can get bigger needs containers that can get bigger. Every fixed-height text box is a future clipping bug.

### 3.1 The growing stack

The pattern that survives every text size: a vertical `UIListLayout` inside a container with `AutomaticSize = Y`, children that are labels with `AutomaticSize = Y`, `TextWrapped = true`, and width set by scale (for example `UDim2.new(1, 0, 0, 0)`). Each label's height follows its text, the container's height follows its children, and the container sits inside a `ScrollingFrame` with `AutomaticCanvasSize = Y` so long content scrolls instead of clipping. [[UI Layout Objects - Lists Grids and Pages]] covers the layout objects; the accessibility point is that **height is never authored for text**.

### 3.2 Where you cannot grow

Buttons in a fixed toolbar, HUD counters, tab headers. For these:

- Keep labels short (one or two words). Long labels belong in tooltips or a details panel.
- Use `TextTruncate = AtEnd` as a last resort and make the full text reachable (long-press or select shows it). Truncation hides information; never truncate prices, counts or names that differ only at the end.
- Allow icons to carry meaning so that truncated text is not the only signal.
- Give the label a `UITextSizeConstraint` with a generous `MaxTextSize`, so it can grow until it hits the layout limit, rather than none (it overflows) or a tight one (it ignores the preference).

### 3.3 Localisation compounds it

Translations grow text. German, French and Portuguese routinely run 20 to 35% longer than English for UI strings, and some short labels double (rule of thumb). A layout that just fits English at `Medium` will clip in German at `Large`. Test the worst language at the largest size together. [[Localization]] and [[Localization-Ready Writing]] cover the string side.

### 3.4 Line spacing and line length

`TextLabel.LineHeight` takes values from 1.0 to 3.0, default 1.0 (Roblox docs, as of October 2026). For body text of more than two lines, 1.15 to 1.3 reads noticeably easier, especially for dyslexic readers (rule of thumb). Keep body lines to about 40 to 60 characters on phones and up to about 75 on desktop by capping the width of text containers with a `UISizeConstraint`, rather than letting a paragraph span a 2560 px monitor.

---

## 4. Type choices that help

### 4.1 Font

For content text, choose a font with a large x-height, open counters (the holes in a, e, o), distinct letter shapes for I, l and 1, and medium or semibold weight. Heavy display fonts (black weights) are fine for short titles and numbers but tire the eye in paragraphs. With `Font.new(family, weight, style)` you can keep one family and change weight per role, which keeps a design system coherent ([[Text Fonts and Rich Text]]).

Rules of thumb that help dyslexic readers and everyone else:

- Avoid italics for more than a few words; use weight for emphasis instead.
- Avoid ALL CAPS for anything longer than a short label. Capitals remove word shape. The reference project kept Title Case for headers for this reason (measured in the reference project).
- Avoid justified text (`TextXAlignment` is left or centre; keep paragraphs left aligned). Centred multi-line paragraphs make it hard to find the start of the next line.
- Avoid very thin fonts at small sizes; hairlines alias badly on low-density phones.

### 4.2 Outlines and plates

Text over the 3D world needs separation from an unpredictable background. The two tools:

| Tool | Best for | Watch out |
|---|---|---|
| `UIStroke` on text | Short labels, numbers, titles over art | At small sizes a thick stroke fills the counters of letters; keep stroke around 8 to 12% of the rendered size and never thicker than 2 px below about 16 px text (rule of thumb) |
| Plate (a panel behind the text) | Paragraphs, subtitles, tooltips | Respect `PreferredTransparency` so players who want opaque plates get them ([[Accessibility]]) |

A subtle drop shadow (a duplicated label offset by 1 to 2 px in a dark colour) is a middle ground that keeps counters open at small sizes.

### 4.3 Numbers

Numbers are often the most important text on a Roblox screen (currency, damage, timers). Make them readable at a glance:

- Abbreviate consistently ("12.4K", "3.1M"), with the suffix in the same size as the digits. [[Big Numbers Precision and Formatting]] has the formatting code.
- Use tabular (fixed-width) digits for counters that tick, so the number does not jitter horizontally. `TextLabel.OpenTypeFeatures` accepts a comma-separated list of OpenType feature tags (Roblox docs, as of October 2026); `tnum` is the standard tabular-figures tag, but whether a given Roblox font supports it is font-dependent and not something we could confirm per font. Check `OpenTypeFeaturesError` after setting it.
- Do not animate a counter so fast that the player cannot read the final value. Under reduced motion, show the final value at once.

---

## 5. World-space text

`BillboardGui` nameplates, damage numbers, interaction prompts and `SurfaceGui` signs are text too, and they suffer most.

- **Billboards that scale with distance** (sized in studs) become unreadable when far; billboards sized in offset pixels stay readable but crowd the screen. A hybrid works: scale size with distance, but clamp the rendered height to a minimum (for example 14 px) and fade out beyond a distance using `MaxDistance`.
- **Damage numbers** should be big enough to read during motion: 20 px or more rendered on phones for normal hits, larger for crits, and short-lived. Offer a setting to turn them off for players who find them noisy, and a setting to make them larger for players who rely on them.
- **`SurfaceGui` signs** depend on `PixelsPerStud` and viewing angle. Text on a sign the player passes at speed must be short. Put essential information (a door's requirement) on screen when the player is near, not only on the surface.
- **Proximity prompts** inherit some of this. Their action text should be one verb and their object text a short noun.

---

## 6. An automated text audit

Clipping bugs are easy to miss by eye because they appear only at certain sizes, languages and devices. The engine helps: `TextLabel.TextFits` reports whether the text fits within the label's bounds, and `TextBounds` gives the rendered size. A client-side audit walks every visible text object and reports problems. Run it in Studio after switching the Roblox text size to `Largest`, and with your UI size slider at the maximum.

```lua
--!strict
-- TextAudit: run on the client (for example from a debug command) after opening each screen.
local Players = game:GetService("Players")

type TextObject = TextLabel | TextButton | TextBox

export type Issue = { path: string, kind: string, detail: string }

local MIN_RENDERED_PX = 12

local function isVisible(obj: GuiObject): boolean
	local node: Instance? = obj
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	return gui ~= nil and gui.Enabled
end

local function check(obj: TextObject, issues: { Issue })
	if not isVisible(obj) or obj.Text == "" then
		return
	end
	local path = obj:GetFullName()
	if obj.TextScaled then
		table.insert(issues, { path = path, kind = "TextScaled", detail = "ignores PreferredTextSize" })
	end
	if not obj.TextFits then
		table.insert(issues, { path = path, kind = "Clipped", detail = `bounds {obj.TextBounds} in box {obj.AbsoluteSize}` })
	end
	-- One line of text renders roughly TextBounds.Y tall per line; approximate the glyph size.
	local lines = math.max(1, select(2, obj.ContentText:gsub("\n", "\n")) + 1)
	local approxPx = obj.TextBounds.Y / lines
	if not obj.TextScaled and approxPx > 0 and approxPx < MIN_RENDERED_PX then
		table.insert(issues, { path = path, kind = "Small", detail = `about {math.floor(approxPx)} px rendered` })
	end
	local constraint = obj:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint and constraint.MaxTextSize < 18 and lines > 1 then
		table.insert(issues, { path = path, kind = "TightMax", detail = `MaxTextSize {constraint.MaxTextSize} on body text` })
	end
end

local function audit(): { Issue }
	local issues: { Issue } = {}
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, inst in playerGui:GetDescendants() do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			check(inst :: TextObject, issues)
		end
	end
	return issues
end

for _, issue in audit() do
	warn(`[TextAudit] {issue.kind}: {issue.path} ({issue.detail})`)
end
```

Points to know about this audit:

- `TextBounds` already includes `UIScale` and the preferred text size, because it is measured in rendered pixels (the `AbsoluteSize` space). That is why the small-text check uses it rather than `TextSize`. The per-line estimate is approximate: line height and wrapped lines make it imperfect, so treat "Small" as a prompt to look.
- `TextFits` reports false for text that overflows the box, including wrapped text that runs out of height. It is the most valuable check here.
- Open each screen before running it; closed screens are skipped by the visibility check, which is deliberate (hidden templates would flood the report).
- Run it at `Medium` and at `Largest`, at minimum and maximum player UI size, and in your longest language. That is eight runs per screen, which is why it is worth scripting into a test pass ([[QA Checklists Before Release]]).

The reference project automated a similar check on phone viewports: every panel measured for rendered text below 12 px, tap targets below 44 px and elements off-screen (measured in the reference project; see [[Responsive UI for Phone Tablet Console and PC]]). Extending it to the largest preferred text size is the step most games skip.

---

## 7. When not to do this

- **Do not make everything huge by default.** Big text everywhere crowds the screen and pushes the 3D world out of view, which hurts gameplay readability. Default to comfortable sizes and let players go bigger.
- **Do not add a UI size slider before fixing the device scale.** A slider on top of a bad base just lets players choose which way it is broken.
- **Do not wrap HUD numbers.** A health value that wraps to two lines is worse than a slightly smaller one. Fixed, short, single-line text belongs in containers sized for its largest expected width.

---

## Common mistakes

- `TextScaled` for content, so the player's text size does nothing.
- Fixed-height text boxes that clip at `Largest`.
- Tight `MaxTextSize` constraints on body text.
- A UI size slider that can push the close button off screen.
- Measuring authored `TextSize` instead of rendered size.
- Thick strokes on small text that fill the letter counters.
- Long centred or justified paragraphs, and ALL CAPS sentences.
- Testing only English at default size.

## Checklist

- [ ] Rendered body text meets the minimums for each device class, measured, not assumed.
- [ ] One `UIScale` controller combines device base and player preference, clamped to fit.
- [ ] No content text uses `TextScaled`; constraints on body text are generous.
- [ ] Text containers grow (`AutomaticSize`, wrapping, scrolling) instead of clipping.
- [ ] `LineHeight` about 1.15 to 1.3 for paragraphs; line length capped.
- [ ] Outlines or plates behind text over the world; plates honour `PreferredTransparency`.
- [ ] Damage numbers and nameplates have size and visibility settings.
- [ ] Text audit run at Medium and Largest, min and max UI size, longest language.

See also: [[Accessibility Start Here]], [[Accessibility]], [[Text Fonts and Rich Text]], [[Responsive UI for Phone Tablet Console and PC]], [[Gamepad and Console UX]], [[Safe Areas and Insets]], [[Layout - Scale Offset and Constraints]], [[World-Space UI - BillboardGui and SurfaceGui]], [[Colour-Blind Safe Design]].

## Connected notes
<!-- auto-links:start -->
[[Debugging UI Layout and Input]] · Cookbook - UI · Skill - Roblox UI Builder · Links - UI elements · Case Study - Phone UI Overhaul · Accessibility Contrast
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[UIStroke on Text - Glyph Counters and the Stroke Ratio]] · [[Colourblind Palettes Text Size and Tooltips]] · [[AI Pitfalls - UI and Input]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Captions and Audio Accessibility]] · [[Input Remapping and One-Handed Play]]
<!-- related:end -->
