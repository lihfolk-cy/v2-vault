---
name: lihfolk-figma
description: 'Figma frame to Roblox ScreenGui (Figma MCP or exported JSON), variables to theme tokens. Use for "Figma", "turn this design into Roblox UI".'
---

# LihFolk Figma: Figma frames to working Roblox UI

Goal: a Figma frame becomes a Roblox GUI that matches the design at the reference resolution, fits every device, has every interaction state, and scores at least **8.5** on `../quality-score/rubrics/ui.md`. The design is the visual spec. Behaviour, states and motion are added here.

Not this skill:
- House cartoon menus with no Figma file go to `lihfolk-ui`.
- General layout and responsive rules are in `roblox-ui-builder`; this skill follows them.
- Effect textures are covered by `lihfolk-vfx`, plus the vault note on Figma VFX textures.

## Inputs

- `VAULT`: `<base directory>/../../LihFolk Vault V2`, resolved to an absolute path. Read these notes:
  - `05 UI and UX/Figma to Roblox UI - Pipeline and Handoff.md`
  - `Designing Roblox UI in Figma - Frames, Safe Areas and Tokens.md`
  - `Figma Property Mapping for Roblox UI.md`
- The mapping contract: `references/property-mapping.md`. Read it before building by hand.
- The converter: `tools/figma_to_roblox.py` (stdlib Python). The sample is `tools/sample/settings_panel.json` and its output is `SettingsPanel.luau`. Tests: `py -I tools/test_figma_to_roblox.py`.
- Token shape and the component-state pattern: `examples/FigmaThemeTokens.luau`.
- From the user: a Figma link (file key plus `node-id`) or an exported JSON; the target devices; and whether the game uses the LihFolk house kit.

## Path A: Figma MCP (primary)

Use this path when the official Figma MCP tools are loaded (`get_metadata`, `get_screenshot`, `get_design_context`, `get_variable_defs`).
- If the Figma server shows as needing authorisation, tell the user to authorise it with `/mcp`.
- Never ask for a token, password or callback URL in chat.

1. **Find the frame.** From a link `.../design/<fileKey>/...?node-id=12-34`, the node id is `12:34`. Run `get_metadata` on it: it lists names, types, sizes and the child tree. Confirm that it is one frame and note its size, which sets the reference resolution.
2. **Look at it.** Run `get_screenshot` on the frame and keep the image as the visual target.
3. **Read the tokens.** Run `get_variable_defs`. Map every colour, radius, spacing and type variable into a theme module shaped like `examples/FigmaThemeTokens.luau`. Builders read tokens; they never copy hex values.
4. **Read the structure.** Run `get_design_context` for the frame, or for its big children one at a time. It returns layout and style data, often as web code. Treat that code as a description: translate it with `references/property-mapping.md`, never paste it into Luau.
5. **Build.** Write a builder ModuleScript in the same shape the converter emits:
   - Offset at the reference resolution;
   - one `Fit` `UIScale` on the root;
   - `UIListLayout`, `UIPadding` and `UIFlexItem` for auto layout;
   - `UICorner`, `UIStroke` and `UIGradient` for styling;
   - `Image = ""` placeholders with `-- REPLACE_ME: upload <name>.png`.

   Put states and motion in a separate controller.
6. **Writing to Figma** with `use_figma` (mocking a Roblox screen in Figma) happens only when the user asks for it, on a file they name. Follow the frame rules in step 4 of Design rules below.

## Path B: REST JSON (deterministic)

1. **The user exports the JSON.** Claude never handles the token value. The token lives in the user's `FIGMA_TOKEN` environment variable:
   ```
   curl -H "X-Figma-Token: $FIGMA_TOKEN" "https://api.figma.com/v1/files/<fileKey>/nodes?ids=12:34&geometry=paths" -o frame.json
   ```
   `geometry=paths` adds `size` and `relativeTransform`, which rotated nodes need.
2. **Convert:**
   ```
   py -I tools/figma_to_roblox.py frame.json --node "Settings" -o SettingsUI.luau --manifest SettingsUI.assets.json
   ```
   - `--reference 1920x1080` sets the design resolution.
   - `--screen` is for full-screen HUD frames: children are pinned to their own edges.
   - `--per-corner` emits mixed corner radii (beta engine properties).
   - `--rotation-units deg` is for exports whose `rotation` is in degrees.
3. **Read the report.** `--report` prints the unsupported features and every warning. Fix each one in Figma (rename layers, flatten effects) and re-run, or fix it in the controller. Do not hand-edit the generated layout; regenerate it.
4. **Compile:**
   ```
   luau-compile --null SettingsUI.luau
   ```
5. **Use it:**
   ```lua
   local root, refs = Builder.build(screenGui)
   Builder.bindFit(root)
   ```
   - `screenGui` uses `ScreenInsets.CoreUISafeInsets`, `ResetOnSpawn = false` and `ZIndexBehavior.Sibling`.
   - `refs` holds the root, every `btn_` and `scroll_` node, and (in screen mode) the top-level parts.

## Design rules for Figma files that convert cleanly

1. **Frames.**
   - Design at **1920 x 1080**, or set `--reference` to the frame size. One frame is one screen or panel.
   - Check every screen against a **667 x 375** phone frame. If a panel only fits at a scale below `12 / smallest text`, it needs a phone arrangement.
2. **Safe areas.** Keep interactive layers out of:
   - the Roblox top bar: read it live in game from `GuiService.TopbarInset`; in Figma, reserve a band about 60 px tall across the top (58 px is the commonly reported desktop height, unverified);
   - the phone notch side: about 60 px (the Roblox docs' `GetInsetArea` phone example reports 59 px);
   - the thumb zones: bottom-left stick, bottom-right jump.

   Draw these as `skip_` guide layers.
3. **Auto layout everywhere it means "list".** Use spacing and padding from the token steps (4, 8, 12, 16, 24, 32). Use Hug and Fill rather than hand-sized children. Avoid `GRID` auto layout and absolute children inside auto layout frames.
4. **Layer names the converter reads:**
   - `btn_` makes a button;
   - `img_` flattens the layer into one PNG;
   - `9s_name__24` makes a 9-slice with a 24 px inset;
   - `scroll_` makes a ScrollingFrame;
   - `skip_` marks annotations that are not built.

   Name everything else for what it is (`header`, `row_music`); the names become `Instance.Name`.
5. **Fonts.** Use the families Roblox ships (Builder Sans, Montserrat, Fredoka One, Nunito and the others in the mapping). The smallest text is 15 design px or more. Do not use letter spacing; Roblox has no tracking.
6. **Effects.** Use one drop shadow per node. Bake blurs, inner shadows, blend modes and noise into `img_` layers.
7. **Components.** Use one component set per control, with a `State` variant: `Default`, `Hover`, `Pressed`, `Disabled`, `Selected` (the gamepad focus ring, drawn on purpose). Add role variants (go, neutral, danger) as a second property.

## Assets

- Export PNG at 2x (1x for very large art). Keep the long side at or under **1024 px**, Roblox's upload cap; the manifest lowers the scale for you.
- Trim transparent edges; leave 2 px of padding for anti-aliasing.
- For 9-slices, export a small source (2 x inset + 8 px). For shadows, export one white soft-shadow 9-slice per radius and blur, tinted in engine with `ImageColor3`.
- Upload through the user's own account, then paste each id over its `REPLACE_ME`. Never invent ids.

## Bring it to life

Figma has no Roblox motion. Take timings from the vault:
- `UI Motion Language and Timing`;
- `08 Animation/05 Systems/UI and GUI Animation`;
- `lihfolk-ui` Motion rules.

The rules:
- Opens use a `Motion` `UIScale` from 0.86 to 1 in 0.22 s Back Out. Closes are faster, with In easing.
- Hover and gamepad focus scale to 1.04 in 0.1 s. Press scales to 0.96 and sinks the face.
- Idle loops stop when hidden. Under `GuiService.ReducedMotionEnabled`, motion becomes colour and fade.

The purple settings reference note maps every widget (tabs, slider, toggle, segmented control) to a motion.

## Quality and checks

1. Pre-flight (quality-score): read `../quality-score/recipes/ui.md` and the ledger if present. Write a 3-6 line plan.
2. Compare a Studio screenshot at 1920 x 1080 with the `get_screenshot` image side by side. Check position, size, colour, type and corner radius element by element. Fix differences above 2 px or one font weight.
3. Test 1920 x 1080, 1366 x 768, 1024 x 600, 844 x 390, 667 x 375, a notched phone and a gamepad. The numbers to hold: text at least 12 px drawn, taps at least 44 px, gaps at least 8 px, no overlaps.
4. Score with `../quality-score/rubrics/ui.md` (minimum 8.5) and log the result.

## Hard rules

- No tokens in chat, files, code or logs. The REST path uses the user's own `FIGMA_TOKEN`.
- Do not create or modify Figma files unless the user explicitly asks, on a file they name.
- No invented asset ids; `REPLACE_ME` placeholders only.
- One `Fit` `UIScale` per branch. Motion uses its own `Motion` `UIScale`. No `TextScaled`.
- Buttons use `Activated`. Every state carries a word or icon as well as colour.
