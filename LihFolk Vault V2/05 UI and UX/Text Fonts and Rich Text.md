---
tags: [ui, text, fonts, fontface, richtext, textservice, uistroke]
---
# Text Fonts and Rich Text

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `GothamBlack` in new code (renders Montserrat).
> - Avoid: `TextScaled` everywhere: inconsistent sizes and no response to the player's text size setting.
> - Avoid: Untrusted text in rich text strings without escaping.
> - All text uses `FontFace` with explicit family and weight.
> - A written type scale with roles; two families at most.
> - Variable-length text uses `AutomaticSize`; any `TextScaled` has a `UITextSizeConstraint`.
>
> Cost: TL;DR ~150 tok · whole note ~4.5k tok. Read more: ## 1. Font versus Enum.Font · ## 2. Three ways to size text · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Text is the UI element players read most and the one most likely to break on another device or in another language. This note covers the `Font` data type and why the old `Enum.Font` names are a trap (Gotham is gone), the three ways to size text and which to choose, measuring text with `TextService`, rich text tags and their limits, text outlines with `UIStroke`, and the lessons from a production font sweep that had to be partly reverted.

Sources: **Docs** (TextLabel, TextService, `Font` data type, `Enum.Font`, "Rich text markup", "UI appearance modifiers"; October 2026), the **reference project** (one production game), and **rule of thumb**.

---

## 1. Font versus Enum.Font

Text objects have two font properties:

- `Font` (`Enum.Font`): the legacy enum, one value per family-and-weight (`SourceSansBold`, `GothamBlack`, ...).
- `FontFace` (`Font` data type): a family asset plus `Weight` (`Enum.FontWeight`) and `Style` (`Normal` or `Italic`). This is the modern property and supports far more families and all nine weights.

Constructors (Docs):

```lua
--!strict
-- From a family asset (rbxasset:// built-ins or rbxassetid:// uploaded families)
local a = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
-- From a built-in family name (letters, digits, _ and - only; no spaces)
local b = Font.fromName("FredokaOne")
local c = Font.fromName("Montserrat", Enum.FontWeight.Heavy)
-- From an old enum value
local d = Font.fromEnum(Enum.Font.SourceSansBold)
-- From a numeric asset id of an uploaded family
local e = Font.fromId(0000000000)
```

Weights by name map to numbers 100 to 900: `Thin`, `ExtraLight`, `Light`, `Regular`, `Medium`, `SemiBold`, `Bold`, `ExtraBold`, `Heavy` (Docs, rich text weights). Not every family ships every weight; a missing weight falls back to the nearest one the family has.

### The Gotham trap

Docs for `Enum.Font` now say that `Gotham`, `GothamMedium`, `GothamBold` and `GothamBlack` "[have] been removed. Using [them] will map to the `Montserrat` font family". Many UI kits and tutorials, including a popular cartoon-simulator design standard, still specify "GothamBlack everywhere". In current Roblox that renders Montserrat. That is not a disaster (Montserrat Black is a close geometric sans), but:

- Text measured or hand-fitted for Gotham's metrics may now wrap or truncate differently.
- A "Gotham-only" design rule enforced by a lint checks for an enum value that no longer means what the rule's author intended.

**Recommendation:** write `FontFace = Font.fromName("Montserrat", Enum.FontWeight.Heavy)` explicitly if that is the look you want, so the code says what renders.

### Pick a small type palette

The reference project went through three type standards: everything in Builder Sans (with a runtime enforcer converting any other font), then a cartoon "check" look with a heavy display face for headers and Fredoka One for button captions, then Fredoka One for titles across new popups. What stayed constant was the structure:

| Role | Example choice | Size at 1080p design |
|---|---|---|
| Display (panel titles) | Heavy geometric sans or rounded display | 38 to 54 px |
| Section headers | Same family, bold | 24 px |
| Button captions | Rounded bold (Fredoka One) | about half the button height (20 to 36 px) |
| Body and stats | Builder Sans regular or bold | 15 to 18 px |
| Small print | Builder Sans | 13 to 14 px on desktop, never under 12 px drawn on phones |

Two families plus weights is plenty. Each extra family is another download on join and another set of metrics to test.

### Preload fonts that appear early

Fonts not built into the client load on first use; text can flash in a fallback face for a moment. `TextService:GetTextBoundsAsync` yields for this reason (Docs). For the main menu and HUD, preload by putting a label with that `FontFace` through `ContentProvider:PreloadAsync` during loading.

---

## 2. Three ways to size text

| Approach | How | Strength | Weakness |
|---|---|---|---|
| Fixed `TextSize` | Pixels, scaled by any `UIScale` | Consistent type scale; honours `PreferredTextSize` | Overflows if text is longer than designed |
| `TextScaled` | Engine fits text to the box | Never overflows | Sizes vary wildly between labels; ignores `PreferredTextSize`; tiny on long strings |
| `AutomaticSize` | Box grows to fit text at a fixed size | Consistent size, handles any length | Layout must tolerate growth |

Docs recommend avoiding `TextScaled` and using `AutomaticSize`, and say not to combine them on one label. With `TextScaled`, `TextSize` is ignored and wrapping is forced on (Docs). Note also `TextSize` is "line height in offsets", not points (Docs).

When you do use `TextScaled` (billboards, giant one-word captions), always add a `UITextSizeConstraint`. A row of five buttons with `TextScaled` and different word lengths ("Equip", "Salvage", "Upgrade All") renders five different sizes; a shared `MaxTextSize` makes them uniform in the common case.

### The text properties you will actually use

| Property | Use |
|---|---|
| `TextWrapped` | Wrap at the box edge |
| `TextTruncate` | `AtEnd` adds an ellipsis instead of overflowing; `SplitWord` options exist |
| `TextXAlignment`, `TextYAlignment` | Alignment inside the box |
| `LineHeight` | Multiplier on line spacing (tight headers at 0.9, body at 1.1) |
| `MaxVisibleGraphemes` | Reveal text gradually (typewriter) without rebuilding the string |
| `TextBounds` | Drawn size of the text (read-only) |
| `TextFits` | Whether the text fits the box |
| `ContentText` | The string actually rendered (rich text tags removed) |
| `LocalizedText` | The auto-translated string being shown |
| `OpenTypeFeatures` | Comma-separated OpenType feature tags such as `zero` or `ss03`; unsupported features are rejected with a reason in `OpenTypeFeaturesError` (Docs) |
| `TextDirection` | Rendering direction, relevant for right-to-left languages |

### Typewriter without garbage

```lua
--!strict
local GuiService = game:GetService("GuiService")

-- Reveals a label's text over time using MaxVisibleGraphemes (no string rebuilds).
local function typewrite(label: TextLabel, text: string, charsPerSecond: number): () -> ()
	label.Text = text
	if GuiService.ReducedMotionEnabled then
		label.MaxVisibleGraphemes = -1
		return function() end
	end
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(label.ContentText) or #label.ContentText
	local cancelled = false
	task.spawn(function()
		local shown = 0
		while not cancelled and shown < total do
			shown = math.min(total, shown + math.max(1, math.floor(charsPerSecond * task.wait())))
			label.MaxVisibleGraphemes = shown
		end
		if not cancelled then
			label.MaxVisibleGraphemes = -1 -- -1 shows everything
		end
	end)
	return function()
		cancelled = true
		label.MaxVisibleGraphemes = -1
	end
end
```

`ContentText` is used for the count because rich text tags do not count as visible graphemes. `utf8.len` counts code points, which is close to graphemes for most game text; emoji with modifiers may count higher, which only makes the reveal end a little later.

---

## 3. Measuring text before you draw it

`TextService:GetTextBoundsAsync(params)` measures text with a `GetTextBoundsParams` object (`Text`, `Font`, `Size`, `Width`, `RichText`) and returns a `Vector2` (Docs). It yields if the font must load, so wrap it in `pcall`. It honours the player's `PreferredTextSize` (Docs), which is what you want.

The older `TextService:GetTextSize(text, size, enumFont, frameSize)` takes an `Enum.Font` and does not yield.

```lua
--!strict
local TextService = game:GetService("TextService")

local params = Instance.new("GetTextBoundsParams")

-- Width a one-line label needs for this text; nil if measuring failed.
local function measureWidth(text: string, font: Font, size: number): number?
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = math.huge
	params.RichText = false
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	if ok then
		return math.ceil(bounds.X)
	end
	return nil
end
```

Use it for: shrinking a caption until it fits a fixed button (the reference project's hotbar shrinks move names to fit, with a 12 px floor and an ellipsis when a single word cannot fit), sizing tooltips, and deciding whether a name needs two lines.

---

## 4. Rich text

Set `RichText = true` on a `TextLabel`, `TextButton` or `TextBox` and use tags (Docs):

| Tag | Example |
|---|---|
| Colour | `<font color="#FF7800">orange</font>` or `color="rgb(255,125,0)"` |
| Size | `<font size="40">big</font>` |
| Face | `<font face="Michroma">...</font>` |
| Family | `<font family="rbxasset://fonts/families/Michroma.json">...</font>` |
| Weight | `<font weight="heavy">` or `weight="900"` |
| Transparency | `<font transparency="0.5">` |
| Stroke | `<stroke color="#00A2FF" thickness="2" transparency="0.25" joins="miter">25 gems</stroke>`; also `th`, `tr`, `sizing="fixed"` or `"scaled"` |
| Bold, italic, underline, strikethrough | `<b>`, `<i>`, `<u>`, `<s>` |
| Line break | `<br/>` |
| Upper case | `<uppercase>` or `<uc>` |
| Small caps | `<smallcaps>` or `<sc>` |
| Highlight | `<mark color="#009966" transparency="0">` |
| Comment | `<!-- not shown -->` |

Tags must be closed in reverse order of opening. Escape `<`, `>`, `"`, `'` and `&` as `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&amp;`.

### Escape anything players can type

A player name or a chat-derived string containing `<` breaks the markup, or worse injects formatting. Always escape untrusted text before inserting it into a rich text string:

```lua
--!strict
local ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }

local function escapeRichText(s: string): string
	return (string.gsub(s, "[&<>\"']", ESCAPES))
end

local function rarityLine(playerName: string, itemName: string, hex: string): string
	return string.format(
		'%s rolled <font color="#%s"><b>%s</b></font>!',
		escapeRichText(playerName),
		hex,
		escapeRichText(itemName)
	)
end
```

(Text from players that other players see must also go through Roblox text filtering, `TextService:FilterStringAsync`, on the server; escaping is not filtering. See [[Roblox Policies Ratings and Compliance]].)

### Rich text limits that matter

- **Localization strips tags.** Docs: localizing a game "removes rich text formatting tags"; you must re-apply tags in translated strings. Keep markup out of translatable strings where you can (colour a whole label instead of one word), or put the tags in the translation table entries themselves. See [[Localization]].
- **Mixed sizes and AutomaticSize.** `AutomaticSize` accounts for rich text sizes (Docs), but `TextScaled` and per-span sizes interact unpredictably. Do not combine.
- **Animating colour per letter** by rewriting rich text every frame invalidates the gui every frame and allocates strings. For effects like a rainbow wave, use a `UIGradient` with animated `Offset` on the label instead.

---

## 5. Outlines: UIStroke on text

A `UIStroke` parented to a text object outlines the glyphs (`ApplyStrokeMode = Contextual`, the default) or the box (`Border`). Two strokes on one label can do both (Docs). Properties worth knowing:

- `Thickness` in pixels by default; `StrokeSizingMode = ScaledSize` makes it relative to font size on text (Docs), so the outline stays proportional when text sizes vary.
- `LineJoinMode` (`Round`, `Bevel`, `Miter`): round looks friendliest on heavy cartoon text; miter gives sharp corners.
- A child `UIGradient` on the stroke gives gradient outlines independently of the fill's gradient.
- Docs warning: **do not tween `Thickness` on text strokes**; it "renders and stores many glyph sizes each frame", causing performance issues or flicker. Pulse the label's `UIScale` instead.

The legacy `TextStrokeTransparency` / `TextStrokeColor3` give a thin 1 px outline only. Use `UIStroke` for anything designed.

### How thick?

Rules of thumb from production cartoon UI:

- A cartoon kit standard specifies 2.0 to 3.5 px black strokes for 13 to 38 px text (about 8 to 15% of the text size). Rounded heavy fonts such as Fredoka One need less: above about 7% the stroke fills the holes in 0, a and e ([[UIStroke on Text - Glyph Counters and the Stroke Ratio]]).
- Another style guide used by the reference project specifies navy strokes at about 11% of the text size.
- Headers used heavier ratios (a 4.5 px stroke on a 54 px title, 8%).

Too thick a stroke fills in the counters of digits (the holes in 6, 8, 9, 0). The reference project reduced shop price strokes from 5 px to 3 px because "digit holes" closed up and prices became unreadable.

---

## 6. Case study: the font sweep and the stroke revert

**Goal (reference project).** Make all text consistent: one family, white captions on coloured buttons, Title Case on headers, consistent outlines.

**The sweep.** A runtime "font enforcer" ran on every text object as it appeared, plus a static pass over saved UI:

- Assigned a **role** to every label (button caption, tab, header, body on light card, body on dark backdrop) from its class, its parents' names (`TabBar`, `*Tabs`) and its background.
- Changed dark fills to white only on buttons, tabs, headers and coloured or dark backdrops; left dark body text on light cards alone.
- Applied Title Case only to ALL-CAPS words of four or more letters, so short acronyms (`HP`, `XP`, `VIP`) stayed.
- Skipped fast-changing text (more than 5 changes a second, such as timers) because re-styling them cost frames.
- Detected "drop shadow" copies (a darker duplicate label under a lighter one with the same text) so they were not whitened.
- Had opt-outs per object (`NoInk`, `TextStd = false`, a forced `TextRole`).
- Stored every old value: 238 fonts and 253 stroke colours were mirrored with `Pre*` attributes.

**What went wrong.** The stroke part of the sweep (making every text outline the same colour and thickness) changed the look of screens that had been hand-tuned, and headers got heavier outlines than the art direction wanted. The user's request was simply to "remove any of the weird stroke fixes".

**The revert.** Because old values were stored, 252 stroke colours were restored exactly, 26 strokes the sweep had added were removed, and 38 thicknesses and enables were restored from snapshots (headers went from 5 px back to 3 px). The enforcer stopped touching strokes at all. Fonts and Title Case stayed.

**Lessons:**

1. Fonts and case can be standardised by rule; outlines are art direction and depend on the background behind each label.
2. Any mass pass must be reversible per property, not just per object.
3. Write down "don't mass-apply X again" where every future contributor will read it. The project's notes say exactly that.

---

## 7. Numbers that read well

Formatting numbers is part of text design:

- Abbreviate large numbers (`1.2K`, `4.62M`, `1.15B`) with 3 significant figures in bars ("4.62K / 7.40K"), and full numbers with thousands separators for small amounts ("$9,840").
- Strip trailing zeros only after a decimal point. A production bug in the reference project's quest board abbreviated 160M as "16M" because the zero-stripping did not check for a decimal point first; a tiny epsilon was also needed so that values like 1.15M did not round to 1.14M through floating point.
- Use tabular (fixed-width) digits for counters that tick, or the label width jitters as numbers change. If the family lacks tabular figures, give the counter a fixed width and right-align it.

```lua
--!strict
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 3 significant figures, no misleading trailing zeros: 1234 -> 1.23K, 160e6 -> 160M
local function short(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.min(#SUFFIXES, math.floor(math.log10(n) / 3) + 1)
	local scaled = n / 10 ^ ((tier - 1) * 3)
	local decimals = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
	local s = string.format("%." .. decimals .. "f", scaled + 1e-9)
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s .. SUFFIXES[tier]
end
```

Note `string.format("%.2f")` already rounds, so values like 999,950 become "1000K"; add a re-check that bumps the tier if `scaled` rounds to 1000 in a real implementation. For localised separators use the localization format specifiers instead ([[Localization]]).

---

## Common mistakes

- `GothamBlack` in new code (renders Montserrat).
- `TextScaled` everywhere: inconsistent sizes and no response to the player's text size setting.
- Untrusted text in rich text strings without escaping.
- Rich text colour tags in strings that get auto-translated.
- Tweening `UIStroke.Thickness` on text.
- Strokes so thick that digits fill in.
- A mass style pass with no stored old values.
- Number formatting that turns 160M into 16M.

## Checklist

- [ ] All text uses `FontFace` with explicit family and weight.
- [ ] A written type scale with roles; two families at most.
- [ ] Variable-length text uses `AutomaticSize`; any `TextScaled` has a `UITextSizeConstraint`.
- [ ] 12 px drawn minimum on phones.
- [ ] Rich text inputs are escaped; player text is filtered server-side.
- [ ] Outlines chosen per background, not by a global rule.
- [ ] Number formatting tested at 999, 1,000, 160M, 1.15M.

See also: [[UI Design Systems]], [[Localization]], [[Accessibility]], [[Layout - Scale Offset and Constraints]], [[UI and GUI Animation]], [[World-Space UI - BillboardGui and SurfaceGui]].

## Connected notes
<!-- auto-links:start -->
[[Readable Text and UI Scale]] · [[LihFolk UI Design System]] · [[UI Asset Pipeline]] · [[Strings Patterns and Formatting]] · [[Links - UI elements]] · [[Accessibility Contrast]]
<!-- auto-links:end -->
