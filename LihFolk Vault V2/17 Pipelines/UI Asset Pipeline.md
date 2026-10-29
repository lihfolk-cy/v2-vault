---
tags: [pipelines, ui, design-system, automation, audits, mobile, type/guide, area/pipelines, level/intermediate, area/ui]
---
# UI Asset Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Edit and Play look different: runtime restyling, stale bake -> builders bake; controllers only bind; version attribute
> - Restyle breaks phones: desktop-only builders -> device arrangements from the same builder, round-trip check
> - Two looks fight on one panel: per-panel skins over the theme -> painters only; opt-out attributes for deliberate exceptions
> - Tokens module; no colours, fonts or radii in screens
> - Painters idempotent (reuse their own children)
> - Builders bake the static StarterGui copy; layout version attribute
>
> Cost: TL;DR ~170 tok · whole note ~3.6k tok. Read more: ## Stage 1: tokens · ## Stage 5: automated audits · ## Failure modes · ## Checklist
<!-- tldr:end -->

Roblox UI is built from instances: ScreenGuis, Frames, ImageLabels, UIStrokes, UIGradients, layout objects. In most games those instances are edited by hand in StarterGui, restyled by hand, and then patched at runtime by scripts that "fix" them. After a few months the saved copy in StarterGui, the runtime copy on a player's screen and the designer's intent are three different things, and every restyle breaks something on phones.

This note is a pipeline that keeps them the same: **tokens and builders in code, a baked static copy, scripted repaint passes with backups, and automated audits on desktop and phone sizes**. It is drawn from one production game that restyled every menu several times in a week and kept a 10/10 audit score across 80 to 97 screen-views (measured in one production game). Design system theory is in [[UI Design Systems]], layout in [[Layout - Scale Offset and Constraints]], phones in [[Responsive UI for Phone Tablet Console and PC]] and [[Safe Areas and Insets]], menu patterns in [[Menu Archetypes - Shop Settings Codes Rewards]], declarative frameworks in [[Declarative UI - React-Lua and Fusion]].

## The pieces

| Piece | What it is | Source of truth |
|---|---|---|
| **Tokens** | colours, gradients, fonts, sizes, radii, stroke widths, spacing | a `Theme` ModuleScript |
| **Painters** | functions that apply a role to an instance (`header`, `closeButton`, `plate(frame, "primary")`) | the `Theme` module |
| **Builders** | per-screen modules that create or lay out a whole screen (`ShopUI.build(gui)`) | one ModuleScript per screen |
| **Static copy** | the ScreenGui saved in StarterGui | **generated** by the builder ("baked") |
| **Controller** | runtime script that binds data and input to the static copy | one LocalScript or module per screen |
| **Image assets** | icons, 9-slice frames, checker and sunburst textures, gradients | files + id map ([[Icon and Thumbnail Rendering Pipeline]]) |
| **Audits** | scripts that measure every screen at several viewport sizes | DevTools modules |

The key rule: **controllers bind, they do not restyle.** If a controller has to repaint the screen at runtime to make it look right, the static copy is wrong; fix the builder and re-bake.

## Stage 1: tokens

A token module is boring on purpose. Everything visual that appears twice belongs in it.

```lua
--!strict
-- Theme.lua : tokens + painters. Screens never hard-code colours, fonts or radii.
local Theme = {}

Theme.Color = {
	ink = Color3.fromHex("0A0B17"),          -- every text stroke and outline
	bodyTop = Color3.fromHex("2B8CFF"), bodyBottom = Color3.fromHex("1048C8"),
	primary = Color3.fromHex("7ED321"), secondary = Color3.fromHex("00CDFF"),
	premium = Color3.fromHex("FFB300"), danger = Color3.fromHex("E53935"),
	disabled = Color3.fromHex("9AA3AD"),
}
Theme.Font = {
	title = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}
Theme.Size = { headerH = 60, closeBtn = 52, minTap = 44, minText = 12, gap = 8, radius = 10, stroke = 3 }

-- Painter: a role-coloured, outlined button. Idempotent: reuses children it made before.
function Theme.button(btn: GuiButton, role: string)
	local base = Theme.Color[role] or Theme.Color.primary
	btn.BackgroundColor3 = base
	btn.AutoButtonColor = false
	local corner = btn:FindFirstChild("ThemeCorner") :: UICorner? or Instance.new("UICorner")
	corner.Name = "ThemeCorner"
	corner.CornerRadius = UDim.new(0, Theme.Size.radius)
	corner.Parent = btn
	local stroke = btn:FindFirstChild("ThemeStroke") :: UIStroke? or Instance.new("UIStroke")
	stroke.Name = "ThemeStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Color.ink
	stroke.Thickness = Theme.Size.stroke
	stroke.Parent = btn
	btn:SetAttribute("ThemeRole", role)
end

return Theme
```

The reference project's later standards (header bar heights, close-button size and position, button bevel, caption font and size ratio, the role colours) all lived in its theme module, and **new menus got the look by calling painters**. Its note to future work was: "use the Theme painters and they get the look automatically. Don't add per-panel skins that fight it."

## Stage 2: builders bake the static copy

A builder module builds a screen from tokens. It runs in two places:

1. **In Edit**, from the command bar or a plugin, to bake the ScreenGui saved in StarterGui.
2. **Never at runtime for layout**, except for device-specific arrangements (phone layouts) that the same builder produces from the same code.

Why bake instead of building at runtime: the saved copy is what designers see in Studio, what audits measure, and what players see in the first frames before scripts run. A runtime-only build means Edit shows something different from Play, and audits test the wrong thing.

The reference project hit exactly that. A card layout was upgraded in its modules (new size, no tilt), but the saved StarterGui copy was still the old version; the controller rebuilt it at runtime, so the game looked right while the phone audit's "desktop round trip" check reported **137 differences** between saved and restored layouts. The fix was to re-bake the static copy with the builder, and a rule: **after changing a builder's layout table or version, re-run the build on the StarterGui copy**. Version the layout (`InfoLayout = 6` as an attribute) so a controller can detect a stale bake and warn instead of silently patching.

## Stage 3: device arrangements from the same builder

Phones need different arrangements, not just smaller ones. The reference project's phone framework (measured in one production game):

- phone = touch enabled **and** short side under 520 px;
- reference phone viewports **844 x 390** and **667 x 375**;
- panels scaled so a 430-unit-tall panel fits: `s = 0.97 * H / 430` (0.880 at 844 x 390, 0.846 at 667 x 375);
- minimum tap target 54 units in that framework (the audit's floor was 44 px), gap 10;
- detail views open as full-panel pages with a BACK button on phones; tabs and chips become horizontal strips.

The builder exposes `layout(on, W, H)` per screen, and a **store/set/restore** step keeps the desktop layout exact: before switching to phone it stores the desktop values; switching back restores them byte for byte. The audit's round-trip check (stage 5) proves it.

## Stage 4: repaint passes, with backups

Sometimes you must change many existing screens at once: a new font, a new header standard, a stroke rule. That is a **pass**, and it follows the pass rules from [[Pipeline Design Principles]]:

- store originals in attributes before the first write (`PreBuilderFont`, `PreStd_Font`, `PreStd_Color`, `PreStd_Text`);
- record counts in the changelog (one font sweep touched 238 fonts and 253 stroke colours on static copies);
- keep a runtime enforcer only for content created at runtime, and give it **opt-outs** (`NoInk`, `TextStd = false`, a `TextRole` attribute) so special screens can keep their look;
- skip text that changes more than about five times a second (counters, timers): restyling it every change costs frames.

The cautionary tale: a stroke "standardisation" sweep looked good in isolation and wrong in context, and the owner asked for it to be removed. Because the pass had stored `PreStd_Color` attributes and pre-sweep snapshots, the revert restored 252 stroke colours, removed 26 added strokes and restored 38 thicknesses in one run. The changelog then carried a rule for everyone: "Don't mass-apply strokes again." **Reversible passes make bold changes safe; irreversible ones make teams timid.**

## Stage 5: automated audits

The reference project's UI pipeline was held together by three audit tools, run after every UI change. They measure what humans miss and are worth building early.

### Layout audit (every screen, desktop)

Build each screen at 1920 x 1080 off-screen (the project placed test copies at x = -20000 and always destroyed them), then flag:

| Flag | Meaning |
|---|---|
| pocket | a fill painting past a rounded parent's corners (`ClipsDescendants` does not clip to `UICorner`) |
| stroke2 | two strokes stacked on one element |
| radius | nested rounding that does not match (inner radius should be outer minus padding) |
| bleed | a child extending past its panel |
| uneven | rows of a list with unequal heights |
| centre | a button caption not optically centred (with an attribute for deliberate nudges) |

Each screen gets a score out of 10; the project held a 10.00 average.

### Phone check (every screen, two phone sizes)

| Check | Threshold (reference project) |
|---|---|
| text size | at least 12 px as drawn (TextScaled text measured at the size the engine draws it) |
| tap targets | at least 44 px |
| gaps between targets | at least 8 px |
| overlaps | 0 |
| outside the screen | 0 |
| desktop round trip | 0 differences after phone layout then restore |

### HUD overlap check

HUD elements come from many systems (currency, hotbar, quest tracker, boss bar, popups). A check that places them for several game states (tutorial, combat, boss) at five viewport sizes and reports overlaps caught real collisions such as a hotbar under a quest tracker at 667 x 375.

A minimal overlap checker to start from:

```lua
--!strict
-- Report overlapping visible GuiObjects among a set of HUD roots at the current viewport.
-- Use in Play (Client) or on an off-screen Edit copy sized to a phone viewport.
type Hit = { a: string, b: string, area: number }

local function rectOf(g: GuiObject): (Vector2, Vector2)
	return g.AbsolutePosition, g.AbsolutePosition + g.AbsoluteSize
end

local function overlaps(roots: { GuiObject }, minArea: number?): { Hit }
	local items: { GuiObject } = {}
	for _, r in roots do
		if r.Visible and r:GetAttribute("OverlapIgnore") ~= true then table.insert(items, r) end
	end
	local hits: { Hit } = {}
	for i = 1, #items do
		local a0, a1 = rectOf(items[i])
		for j = i + 1, #items do
			local b0, b1 = rectOf(items[j])
			local w = math.min(a1.X, b1.X) - math.max(a0.X, b0.X)
			local h = math.min(a1.Y, b1.Y) - math.max(a0.Y, b0.Y)
			if w > 0 and h > 0 and w * h >= (minArea or 16) then
				table.insert(hits, { a = items[i]:GetFullName(), b = items[j]:GetFullName(), area = w * h })
			end
		end
	end
	return hits
end

return overlaps
```

Limits to state honestly: runtime-built content can only be audited through static copies or stand-ins that run in Edit; the reference project reviewed a few runtime-only builders by reading code instead, and said so.

## Stage 6: UI image assets

Images in UI are a pipeline of their own:

| Asset | Format and rule |
|---|---|
| Icons | rendered PNGs or sprite sheets ([[Icon and Thumbnail Rendering Pipeline]]) |
| Frames and plates | 9-slice images (`ScaleType = Slice`, `SliceCenter` set from the image's border) so one image fits every size |
| Patterns (checker, studs, sunburst rays) | small tiling images (`ScaleType = Tile`) or one image rotated by a tween |
| Gradients | prefer `UIGradient` over images: no upload, recolourable by token |
| Glows | one soft radial image reused everywhere, tinted by `ImageColor3` |

Keep the id of every UI image in the token module (`Theme.Images.header`, `Theme.Images.rays`), never inline in screens, so a re-upload changes one line.

## Stage 7: motion as a shared module

Animation in UI follows the same rule as styling: one module, used everywhere. The reference project's shared motion module gave every button a hover (scale 1.06, 3 px lift, a white wash on filled faces), a press (0.9 for 0.08 s, Back-eased release over 0.3 s) and panel open and close curves, with **ReducedMotion** support (no scale or lift, fades only), one on-demand render-step connection that disconnects when idle, and idempotent attachment through a weak table so attaching twice does nothing. See [[UI and GUI Animation]] and [[Game Feel and Juice]].

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Edit and Play look different | runtime restyling, stale bake | builders bake; controllers only bind; version attribute |
| Restyle breaks phones | desktop-only builders | device arrangements from the same builder, round-trip check |
| Two looks fight on one panel | per-panel skins over the theme | painters only; opt-out attributes for deliberate exceptions |
| A sweep cannot be undone | no stored originals | `Pre*` attributes and snapshots before every pass |
| Fills poke past rounded corners | `ClipsDescendants` ignores `UICorner` | `CanvasGroup` or matching child corners; audit "pocket" |
| Tiny text on phones | `TextScaled` without limits | `UITextSizeConstraint`, phone check at 12 px |
| Frame drops from UI | per-frame loops for idle animations | tweens; one on-demand loop; stop when hidden |
| HUD elements collide | systems placed independently | HUD slot table plus overlap check per game state |

## Checklist

- [ ] Tokens module; no colours, fonts or radii in screens
- [ ] Painters idempotent (reuse their own children)
- [ ] Builders bake the static StarterGui copy; layout version attribute
- [ ] Controllers bind only
- [ ] Phone arrangements from the same builder; desktop round trip 0
- [ ] Every repaint pass stores originals and is logged with counts
- [ ] Layout audit, phone check and HUD overlap check after every UI change
- [ ] UI image ids in tokens; 9-slice and tiling where possible
- [ ] Shared motion module with ReducedMotion

## See also

[[UI Design Systems]] · [[HUD Design]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Text Fonts and Rich Text]] · [[Accessibility]] · [[Case Study - Phone UI Overhaul]] · [[Batch Processing Tools in Studio]] · [[Localization Pipeline]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[ScreenGui Fundamentals]] · Skill - Roblox UI Builder · Debugging UI Layout and Input · Safe Area · Readable Text and UI Scale · Cookbook - UI
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]] · [[LihFolk UI Design System]] · [[Build Test and Release Pipeline]] · [[Environment and Level Pipeline]] · [[Blender Automation with Python]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Audio Pipeline]] · [[Live Content Pipeline]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Asset Upload Automation with Open Cloud]]
<!-- related:end -->
