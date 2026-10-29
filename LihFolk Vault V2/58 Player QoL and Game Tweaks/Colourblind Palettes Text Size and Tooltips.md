---
tags: [qol, colourblind, palette, text-size, tooltips, readability, preferredtextsize, ui, type/guide, area/ui, level/intermediate, api/GuiService]
---
# Colourblind Palettes Text Size and Tooltips

<!-- tldr:start -->
> [!tldr] TL;DR
> - Colour-blind mode misses half the UI: Hard-coded colours -> Role tokens resolved at runtime
> - Teams still confusable: Only colour differs -> Add icons/shapes
> - Large text clipped: Fixed container size -> `AutomaticSize`, wrapping
> - Colours named by role; palettes swap live, including world-space cues.
> - Every colour signal has a non-colour partner.
> - Text size follows `PreferredTextSize` with a game override; containers grow.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 1. Palettes as tokens, not hard-coded colours · ## 3. Tooltips that work on every device · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Three interface options that cost little and are noticed: a **colour palette** choice for colour-blind players, a **text size** option, and **tooltips** that explain icons. Section 42 covers the accessibility theory in depth ([[Colour-Blind Safe Design]], [[Readable Text and UI Scale]]); this note is the QoL implementation: how to make palettes swappable at runtime, how to respect Roblox's own text size preference, and how to build tooltips that work on touch and gamepad, not just mouse hover.

Sources: **Roblox docs** for `GuiService.PreferredTextSize` (https://create.roblox.com/docs/reference/engine/classes/GuiService) and `GuiObject.SelectionGained` (https://create.roblox.com/docs/reference/engine/classes/GuiObject). Colour pairs are **Rule of thumb** informed by the Game Accessibility Guidelines (https://gameaccessibilityguidelines.com/).

## 1. Palettes as tokens, not hard-coded colours

You cannot add a colour-blind mode to a UI where 300 frames have hard-coded `Color3` values. Name colours by role (`team.ally`, `team.enemy`, `rarity.epic`, `state.danger`, `state.ok`) and resolve them through a palette module.

```lua
--!strict
-- ReplicatedStorage/Shared/Palette
type Palette = { [string]: Color3 }

local PALETTES: { [string]: Palette } = {
	default = {
		["team.ally"] = Color3.fromRGB(70, 170, 255),
		["team.enemy"] = Color3.fromRGB(235, 70, 70),
		["state.ok"] = Color3.fromRGB(80, 200, 120),
		["state.danger"] = Color3.fromRGB(235, 70, 70),
	},
	-- Red/green confusion: move "bad" toward orange, "good" toward blue.
	deutan = {
		["team.ally"] = Color3.fromRGB(60, 140, 255),
		["team.enemy"] = Color3.fromRGB(255, 150, 30),
		["state.ok"] = Color3.fromRGB(60, 140, 255),
		["state.danger"] = Color3.fromRGB(255, 150, 30),
	},
	-- Blue/yellow confusion: rely on red vs teal.
	tritan = {
		["team.ally"] = Color3.fromRGB(0, 170, 170),
		["team.enemy"] = Color3.fromRGB(220, 50, 90),
		["state.ok"] = Color3.fromRGB(0, 170, 170),
		["state.danger"] = Color3.fromRGB(220, 50, 90),
	},
}

local M = {}
function M.get(paletteName: string, role: string): Color3
	local p = PALETTES[paletteName] or PALETTES.default
	return p[role] or PALETTES.default[role] or Color3.new(1, 0, 1) -- magenta = missing token
end
return M
```

Apply by tagging UI elements with an attribute such as `ColorRole = "state.danger"` and re-colouring all tagged elements when the setting changes. Also apply to world-space cues: enemy outlines (`Highlight.OutlineColor`), damage numbers, minimap dots.

Gotchas:
- **Colour is never the only signal.** Rarity needs a label or shape, team needs an icon, danger needs an icon or pattern. A palette helps; redundancy is what makes the game playable ([[Colour-Blind Safe Design]]).
- **Name choices by effect, not diagnosis** if you prefer: "Red-green friendly", "Blue-yellow friendly". Players do not always know their type.
- **Test with a simulator** on screenshots; do not trust your eyes.
- Magenta fallback makes missing tokens obvious in testing.

## 2. Text size

Roblox exposes the player's preferred text size as `GuiService.PreferredTextSize` (an `Enum.PreferredTextSize`: `Medium`, `Large`, `Larger`, `Largest`) (**Roblox docs**). Read it as the starting point and add a game override.

```lua
--!strict
local GuiService = game:GetService("GuiService")
local ClientSettings = require(script.Parent.ClientSettings)

local PLATFORM_FACTOR: { [Enum.PreferredTextSize]: number } = {
	[Enum.PreferredTextSize.Medium] = 1,
	[Enum.PreferredTextSize.Large] = 1.15,
	[Enum.PreferredTextSize.Larger] = 1.3,
	[Enum.PreferredTextSize.Largest] = 1.5,
}

local function textFactor(): number
	local choice = ClientSettings.get("textSize") :: string -- "follow" | "small" | "normal" | "large"
	if choice == "small" then return 0.9 end
	if choice == "normal" then return 1 end
	if choice == "large" then return 1.25 end
	return PLATFORM_FACTOR[GuiService.PreferredTextSize] or 1
end
```

The factors are **Rule of thumb**, not Roblox values. Apply to `TextSize` on labels with fixed sizes, or to a `UITextSizeConstraint.MaxTextSize` on `TextScaled` labels. Containers must grow (`AutomaticSize`) or wrap, or large text gets clipped. Listen to `GuiService:GetPropertyChangedSignal("PreferredTextSize")` in case the player changes it mid-session.

## 3. Tooltips that work on every device

Hover tooltips are invisible on touch and gamepad. Design for three triggers:

| Device | Trigger | Dismiss |
|---|---|---|
| Mouse | Hover for about 0.4 s | Mouse leaves |
| Gamepad | `SelectionGained` on the selected button | `SelectionLost` |
| Touch | Long-press (`TouchLongPress`) or an "i" button | Tap elsewhere or after a few seconds |

```lua
--!strict
local function attachTooltip(button: GuiObject, text: string, show: (GuiObject, string) -> (), hide: () -> ())
	local hoverToken = 0
	button.MouseEnter:Connect(function()
		hoverToken += 1
		local mine = hoverToken
		task.delay(0.4, function() if mine == hoverToken then show(button, text) end end)
	end)
	button.MouseLeave:Connect(function() hoverToken += 1; hide() end)
	button.SelectionGained:Connect(function() show(button, text) end)
	button.SelectionLost:Connect(hide)
	button.TouchLongPress:Connect(function(_, state)
		if state == Enum.UserInputState.Begin then show(button, text) end
	end)
end
```

Keep one tooltip instance on its own high-`DisplayOrder` `ScreenGui`, positioned next to the button and clamped inside the viewport. Offer a "Tooltips: On/Off" setting for experienced players. Tooltips should say what something **does**, with the bound key shown via the input glyph helpers in [[Input - UserInputService and ContextActionService]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Colour-blind mode misses half the UI | Hard-coded colours | Role tokens resolved at runtime |
| Teams still confusable | Only colour differs | Add icons/shapes |
| Large text clipped | Fixed container size | `AutomaticSize`, wrapping |
| Platform text size ignored | Only a game slider | Start from `PreferredTextSize` |
| Tooltips never seen on mobile | Hover-only | Long-press and "i" button |
| Tooltip off screen | Not clamped | Clamp to viewport |

## Checklist

- [ ] Colours named by role; palettes swap live, including world-space cues.
- [ ] Every colour signal has a non-colour partner.
- [ ] Text size follows `PreferredTextSize` with a game override; containers grow.
- [ ] Tooltips on hover, gamepad selection and long-press; can be turned off.

## See also

- [[Colour-Blind Safe Design]]
- [[Readable Text and UI Scale]]
- [[Text Fonts and Rich Text]]
- [[Accessibility Cross-Links for QoL Settings]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[UI Scale HUD Hide and Compact Mode]] · [[Gamepad and Console UX]] · Accessibility
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Accessibility]] · [[QoL Audit Checklist]] · [[Controller Support QoL]] · [[Rebinding Controls with the Input Action System]] · [[Mobile Button Layout Editor]] · [[Settings Menu Essentials and Persistence]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Aim Assist and Generous Hitboxes]]
<!-- related:end -->
