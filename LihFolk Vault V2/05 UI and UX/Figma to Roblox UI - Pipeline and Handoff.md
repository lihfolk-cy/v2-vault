---
tags: [ui, figma, pipeline, handoff, design-to-code, mcp, ai-workflow, type/guide, area/ui, level/intermediate, api/UIScale, area/ai]
---
# Figma to Roblox UI - Pipeline and Handoff

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Pasting web code from `get_design_context` into Luau instead of mapping it.
> - Avoid: Copying hex values into builders instead of mapping Figma variables to tokens.
> - Avoid: Hand-editing a generated builder, then losing the edits on the next export.
> - Frame read with `get_metadata` and `get_screenshot`, or exported with `geometry=paths`.
> - Figma variables mapped into one theme token module.
> - Builder generated: Offset at the reference resolution, one `Fit` `UIScale`, layout objects for auto layout.
>
> Cost: TL;DR ~170 tok · whole note ~2.9k tok. Read more: ## 2. The house pipeline in six steps · ## 5. The REST path in practice · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Figma frame is a picture of one moment of a menu, drawn at one screen size. A Roblox menu is a tree of instances that has to fit a 667 x 375 phone and a 4K TV, answer touch, mouse and gamepad, and move. This note is the pipeline that gets from the first to the second without losing the design or faking the rest.

There are two ways in:
- through the official Figma MCP tools;
- through a JSON export and the LihFolk converter (`skills/lihfolk-figma/tools/figma_to_roblox.py`).

The note also covers the handoff rules that keep designers and scripters from overwriting each other.

How to draw frames that convert well is in [[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]]. The exact property table is in [[Figma Property Mapping for Roblox UI]]. Layout fundamentals are in [[Layout - Scale Offset and Constraints]] and [[Responsive UI for Phone Tablet Console and PC]]. The tokens and builders this pipeline produces follow [[UI Asset Pipeline]] and [[UI Design Systems]]. A full settings menu worked through control by control is in [[Settings Menu Design for Roblox - Layout, Controls and Motion]].

Sources:
- **Docs:**
  - Figma REST API reference (developers.figma.com, node and property types, file endpoints, personal access tokens; checked October 2026);
  - Roblox engine reference (October 2026).
- **LihFolk:** the converter and its tests in the `lihfolk-figma` skill.
- **Rule of thumb**, where marked.

---

## 1. What Figma gives you and what it cannot

| Figma has | Roblox needs as well |
|---|---|
| Positions and sizes at one resolution | A scaling rule for every other screen |
| Auto layout (Hug, Fill, spacing, padding) | `UIListLayout`, `UIPadding`, `UIFlexItem`, `AutomaticSize` |
| Fills, strokes, radii, one drop shadow | `UIGradient`, `UIStroke`, `UICorner`, and a shadow image |
| Component variants (Default, Hover, Pressed) | One component function with a state machine and gamepad focus |
| Prototype transitions | Tweens with interruption rules and reduced-motion fallbacks |
| Any font on your computer | The families Roblox ships, or an uploaded font asset |

Treat the Figma frame as the **visual spec**: colour, type, spacing, hierarchy. Treat states, scaling, input and motion as **engineering work that the design does not contain**. The purple settings reference note shows the failure mode: a design that looks finished but has no hover, pressed, disabled or gamepad-selected states.

---

## 2. The house pipeline in six steps

1. **Read the frame.**
   - MCP path: `get_metadata` gives the tree and sizes, `get_screenshot` gives the target image, and `get_variable_defs` gives the tokens.
   - REST path: the user exports `GET /v1/files/:key/nodes?ids=<id>&geometry=paths` with their own `X-Figma-Token` header.
2. **Map tokens first.** Turn Figma variables (colours, radii, spacing, type) into one theme ModuleScript. Builders reference tokens; a hex value copied into a builder is a future inconsistency.
3. **Generate the builder.** The converter (or a hand build that follows the same mapping) writes a ModuleScript whose `build(parent)` creates the tree:
   - Offset sizes at the reference resolution;
   - one `UIScale` named `Fit` on the root;
   - layout objects for auto layout;
   - `Image = ""` placeholders for every image.
4. **Export and upload images.** Use the asset manifest from the converter: one PNG per image node, at 2x unless that would pass 1024 px. Upload through your own account and paste the ids. Never invent ids.
5. **Write the controller.** States, data binding, remotes and motion go in a separate LocalScript or module that reads `refs` from the builder. The builder stays regenerable.
6. **Verify.** Compare a Studio screenshot at the reference resolution with the Figma screenshot. Then test the phone, tablet, PC and gamepad viewports and score with the UI rubric.

```lua
--!strict
-- Client: mount a generated panel, fit it, and hand its buttons to a controller.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsBuilder = require(ReplicatedStorage.UI.Generated.SettingsPanel)

local gui = Instance.new("ScreenGui")
gui.Name = "Settings"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local root, refs = SettingsBuilder.build(gui)
local unbindFit = SettingsBuilder.bindFit(root, { maxScale = 1.4 })

local save = refs["btn_save"]
if save and save:IsA("GuiButton") then
	save.Activated:Connect(function()
		-- send an intent to the server; the server validates and saves
	end)
end

gui.Destroying:Connect(unbindFit)
```

---

## 3. Sizing: why Offset plus one Fit scale

The converter copies Figma pixels as Offset and puts one `UIScale` on the root. The scale is:

```
scale = clamp(min(area.X / 1920, area.Y / 1080), 12 / smallestText, 1.4)
scale = min(scale, fitInsideSafeArea)
```

This is the "design resolution plus UIScale" pattern from [[Layout - Scale Offset and Constraints]], and the `lihfolk-ui` kit uses the same pattern:
- Everything keeps its proportions, including `UIStroke` thickness and `UICorner` radius.
- Square icons stay square.
- Text never draws under 12 px until the panel physically cannot fit. At that point the screen needs a phone arrangement (pages instead of panes), not a smaller scale.

Scale appears only where Figma says "proportional": the `SCALE` constraint, and stretch constraints (`LEFT_RIGHT`, `TOP_BOTTOM`) written as Scale 1 with a negative Offset.

For full-screen HUD frames, the converter's `--screen` mode fills the screen and pins each top-level part to its own edge, each with its own `Fit` scale. A `UIScale` grows an element from its `AnchorPoint`, so a bottom-right part stays bottom-right.

---

## 4. The MCP path in practice

- **Authorise first.** If the Figma MCP server reports that it needs authorisation, the user runs `/mcp` and signs in. Nobody pastes tokens into chat.
- **Work frame by frame.** Large frames produce large `get_design_context` responses. Fetch the panel, then each big child, rather than the whole page.
- **Translate, do not paste.** `get_design_context` often returns web-flavoured code (flexbox, CSS colours). Read it as a description and map it with the property table. CSS `gap` is `UIListLayout.Padding`; `justify-content: space-between` is `HorizontalFlex` or `VerticalFlex` `SpaceBetween`.
- **Keep the screenshot.** The `get_screenshot` image is your acceptance test: when the Studio capture matches it at 1920 x 1080, layout is done.
- **Writing to Figma is opt-in.** Mocking a Roblox screen in Figma (frames at the reference size with safe-area guides) is useful for review. Do it only when the user asks, in a file they name.

---

## 5. The REST path in practice

```
curl -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/<fileKey>/nodes?ids=12:34&geometry=paths" -o frame.json
py -I figma_to_roblox.py frame.json --node "Settings" -o SettingsPanel.luau --manifest SettingsPanel.assets.json
py -I figma_to_roblox.py frame.json --node "Settings" --report
```

- The token stays in the user's `FIGMA_TOKEN` environment variable. The converter reads only the saved file, so the same JSON always gives the same Luau, which makes generated UI reviewable in diffs.
- `--report` lists every approximation, for example:
  - letter spacing dropped;
  - a line height clamped to Roblox's 1.0 to 3.0;
  - mixed corner radii;
  - inner shadows and blurs that must be baked;
  - fonts substituted.

  Fix each one in Figma (rename, flatten, swap a font) and re-run, rather than patching generated code.
- The sample in the skill (`tools/sample/settings_panel.json`) is a 640 x 640 settings panel. It has a gradient header, three auto-layout rows with label, slider and toggle, two buttons (one a component instance with variants), an image and a drop shadow. Its generated `SettingsPanel.luau` compiles with `luau-compile`.

---

## 6. Handoff rules between design and code

| Rule | Why |
|---|---|
| Generated builders are never hand-edited | The next design change regenerates them and silently drops the edits |
| Controllers find objects through `refs`, by layer name | Renaming a layer in Figma is a code change: keep `btn_` names stable |
| Every image id lives in the token or asset module | One re-upload changes one line |
| Variant names are a contract (`State` = `Default`, `Hover`, `Pressed`, `Disabled`, `Selected`) | The controller's state machine uses the same words |
| The designer draws the gamepad focus ring and the disabled state | The rubric's hard gates need them; nobody can invent them well later |
| Motion is specified in the vault's tokens, not in Figma prototypes | Prototype easing does not map onto `TweenInfo`, so use [[UI Motion Language and Timing]] |

---

## 7. Bringing the result to life

The generated tree is static. Add motion from the vault, not from guesses:
- Open: a `Motion` `UIScale` from 0.86 to 1 in 0.22 s Back Out. Close is faster, with In easing.
- Hover and gamepad focus: 1.04 in 0.1 s. Press: 0.96 and sink the face.
- Idle loops pause while hidden, and reduced motion swaps movement for colour and fade.

See [[UI and GUI Animation]] for patterns and [[UI Motion Language and Timing]] for tokens.

Keep the `Motion` scale separate from the `Fit` scale: one `UIScale` per object, and the fit owns the root.

---

## Common mistakes

- Pasting web code from `get_design_context` into Luau instead of mapping it.
- Copying hex values into builders instead of mapping Figma variables to tokens.
- Hand-editing a generated builder, then losing the edits on the next export.
- Shipping only the Default variant: no hover, pressed, disabled or gamepad focus.
- Using pure Scale sizes from Figma percentages: stretched icons and hairlines.
- Tweening the `Fit` `UIScale` for a pop, which fights the device scale.
- Pasting asset ids that were never uploaded, or putting a Figma token in chat or code.
- Signing off at 1920 x 1080 without the 667 x 375 phone and a gamepad.

## Checklist

- [ ] Frame read with `get_metadata` and `get_screenshot`, or exported with `geometry=paths`.
- [ ] Figma variables mapped into one theme token module.
- [ ] Builder generated: Offset at the reference resolution, one `Fit` `UIScale`, layout objects for auto layout.
- [ ] `--report` warnings fixed in Figma or handled in the controller.
- [ ] Images exported at 2x or less with the long side at most 1024 px, uploaded, ids pasted.
- [ ] Controller adds every state (Hover, Pressed, Disabled, gamepad Selected) and motion from vault tokens.
- [ ] Studio screenshot matches the Figma screenshot at the reference resolution.
- [ ] Phone, tablet, PC and gamepad tested; UI rubric at 8.5 or above.

<!-- related:start -->
## Related
[[UI Layout Objects - Lists Grids and Pages]] · [[ScreenGui Fundamentals]] · [[Text Fonts and Rich Text]] · [[Accessibility]] · [[UI Style Directions - A Visual Vocabulary for Briefs]] · [[Gamepad and Console UX]] · [[Virtualized Lists and Large Inventories]] · [[HUD Design]]
<!-- related:end -->
