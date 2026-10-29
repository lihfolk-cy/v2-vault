---
tags: [qol, ui, ui-scale, hud, declutter, compact-mode, uiscale, settings, mobile, console, type/guide, area/ui, level/intermediate, api/UIScale, api/GuiService, api/StarterGui]
---
# UI Scale HUD Hide and Compact Mode

<!-- tldr:start -->
> [!tldr] TL;DR
> - Slider makes UI overflow on phones: Range too wide or no clamp -> 0.8-1.3, clamp final scale
> - UI scale lost after respawn: Tag applied after cloning -> Tag inside the template
> - Corner widgets drift off screen: Wrong `AnchorPoint` -> Anchor at the corner they hug
> - One `UIScale` per root, product of responsive and player values.
> - Live preview, clamped range, safe areas rechecked.
> - Hide HUD with critical elements exempt and a restore path on every device.
>
> Cost: TL;DR ~160 tok · whole note ~1.9k tok. Read more: ## 1. UI scale slider · ## 2. Hide HUD · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The same HUD has to work on a 6-inch phone held at arm's length, a 27-inch monitor and a TV across the room. Responsive layout ([[Responsive UI for Phone Tablet Console and PC]]) gets you most of the way; a player-controlled **UI scale**, a **hide HUD** option and a **compact mode** cover the rest. This note covers those three controls and the gotchas of retrofitting them onto an existing UI. Text sizing for readability is in [[Readable Text and UI Scale]].

Sources: **Roblox docs** for `UIScale` (https://create.roblox.com/docs/reference/engine/classes/UIScale), `GuiService` (https://create.roblox.com/docs/reference/engine/classes/GuiService) and `StarterGui:SetCoreGuiEnabled` (https://create.roblox.com/docs/reference/engine/classes/StarterGui). Ranges are **Rule of thumb**.

## 1. UI scale slider

Put one `UIScale` per `ScreenGui` root frame and drive all of them from the setting. Range 0.8 to 1.3 with default 1.0 (**Rule of thumb**: below 0.8 touch targets get too small; above 1.3 most layouts overflow phone screens).

```lua
--!strict
-- StarterPlayerScripts/UiScaleController
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ClientSettings = require(script.Parent.ClientSettings)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function baseScale(): number
	-- Your automatic responsive factor, e.g. from viewport height.
	local camera = workspace.CurrentCamera
	local h = camera.ViewportSize.Y
	return math.clamp(h / 900, 0.6, 1.4)
end

local function apply()
	local user = ClientSettings.get("uiScale") :: number
	local s = baseScale() * user
	for _, scaler in CollectionService:GetTagged("PlayerUIScale") do
		if scaler:IsA("UIScale") and scaler:IsDescendantOf(playerGui) then
			scaler.Scale = s
		end
	end
end

CollectionService:GetInstanceAddedSignal("PlayerUIScale"):Connect(apply)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
ClientSettings.Changed:Connect(function(key) if key == "uiScale" then apply() end end)
apply()
```

Gotchas:
- **Multiply, do not replace.** If your UI already uses a responsive `UIScale`, the player value is a multiplier on top. Nested `UIScale`s on different levels compound, which is easy to lose track of; keep one per root and compute the product yourself so there is one number to debug.
- **`UIScale` scales offsets and scale-sized children together**, but it does not move an anchored element away from screen edges. Anchor corner widgets at their corner (`AnchorPoint` 1,1 for bottom-right) so growth goes inward.
- **Safe areas**: after scaling, re-check that nothing slides under the notch or top bar ([[Safe Areas and Insets]]).
- **Preview live**: apply while dragging, not on release, so players see the result.
- `ScreenGui`s cloned from `StarterGui` on respawn (`ResetOnSpawn`) need the tag again; tag inside the template, not after cloning.

## 2. Hide HUD

Two use cases: screenshots/content creation, and players who just want a clean screen. Offer a key/button toggle and a settings checkbox.

```lua
--!strict
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local hidden = false
local function setHudHidden(h: boolean)
	hidden = h
	for _, gui in CollectionService:GetTagged("HudLayer") do
		if gui:IsA("ScreenGui") then gui.Enabled = not h end
	end
	-- Optional: hide Roblox core UI too for screenshots (player list, backpack).
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, not h)
end
```

Rules (**Rule of thumb**):
- **Never hide critical state**: low-health warnings, incoming-attack indicators and modal prompts stay. Tag them `HudCritical` and skip them.
- **Always leave a way back**: on touch there is no keyboard, so a small faded "show HUD" button stays in a corner. On gamepad, bind a button (see [[Controller Support QoL]]).
- Roblox's own toggle for hiding its UI exists in the client; do not assume yours is the only one. Your settings menu must still be reachable when your HUD is hidden.

## 3. Compact mode

Compact mode removes decoration, not information: smaller icons, no labels under icon buttons, merged currency rows, fewer side buttons (collapsed into a "more" drawer). It matters most on phones in landscape, where the HUD can cover a third of the screen.

| Element | Normal | Compact |
|---|---|---|
| Side buttons | 6-8 labelled icons | 3-4 icons + "More" drawer |
| Currency | One row per currency with icon and label | Single row, top two currencies |
| Quest tracker | Full text | Title and progress only |
| Chat bubble space | Default | Default (do not shrink platform UI) |
| Minimap | Large | Small or toggle |

Implement compact mode as a layout variant, not a scale change: switch a `UIListLayout` padding, hide label `TextLabel`s, and move overflow buttons into a drawer frame. A simple pattern is an attribute on the root (`root:SetAttribute("Compact", true)`) that each widget reads and listens to.

**Auto-suggest compact** on small viewports: if `ViewportSize.Y < 500` (logical pixels) on first launch, start in compact and show a one-time note saying so (**Rule of thumb** threshold).

## 4. Declutter defaults

Most HUD complaints are about too much on screen by default. Before adding toggles, cut: does each button need to be visible all the time? Unlock menus progressively ([[Menu Archetypes - Shop Settings Codes Rewards]] section 9), and group rarely used actions. See [[HUD Design]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Slider makes UI overflow on phones | Range too wide or no clamp | 0.8-1.3, clamp final scale |
| UI scale lost after respawn | Tag applied after cloning | Tag inside the template |
| Corner widgets drift off screen | Wrong `AnchorPoint` | Anchor at the corner they hug |
| Hidden HUD hides boss warning | Everything toggled | `HudCritical` exempt |
| Mobile player stuck with no HUD | No touch way back | Persistent faded restore button |
| Compact mode is just "smaller" | Implemented as scale | Layout variant with fewer elements |

## Checklist

- [ ] One `UIScale` per root, product of responsive and player values.
- [ ] Live preview, clamped range, safe areas rechecked.
- [ ] Hide HUD with critical elements exempt and a restore path on every device.
- [ ] Compact mode as a layout variant; auto-suggested on small screens.
- [ ] HUD decluttered by default before toggles are added.

## See also

- [[Responsive UI for Phone Tablet Console and PC]]
- [[Readable Text and UI Scale]]
- [[HUD Design]]
- [[Layout - Scale Offset and Constraints]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Colourblind Palettes Text Size and Tooltips]] · [[Notification Queues and Limits]] · [[Settings Menu Essentials and Persistence]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Mobile Button Layout Editor]] · [[Safe Area]] · [[Cookbook - UI]] · [[Accessibility Cross-Links for QoL Settings]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[QoL Audit Checklist]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Top 25 QoL Wins by Effort]] · [[Loading Screen Skip and First-Session Goals]] · [[Quick Respawn and Spawn Protection]]
<!-- related:end -->
