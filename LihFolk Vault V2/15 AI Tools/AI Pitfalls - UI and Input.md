---
tags: [ai-pitfalls, ui, input, responsive, scale, safe-area, input-action-system, gamepad, touch, styling, fonts, type/guide]
verified: 2026-10-28
---
# AI Pitfalls - UI and Input

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Testing only in the default Studio viewport.
> - Avoid: UIScale applied twice (parent and child), so phones get double shrink.
> - Avoid: `ClipsDescendants` on a frame with `UICorner` and expecting rounded clipping (use `CanvasGroup`, which costs memory).
> - Checked at 844 x 390, 667 x 375, 1920 x 1080 and a notched phone.
> - Drawn text 12 px or more, taps 44 px or more, gaps 8 px or more.
> - Safe-area insets set on interactive HUDs.
>
> Cost: TL;DR ~150 tok · whole note ~1.6k tok. Read more: ## 1. Offset sizes, or Scale with no aspect control · ## 5. Keyboard-only input on the old stack · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Generated UI usually looks right on the one desktop viewport the model imagines and breaks on a phone, a console or a notched screen. Input code is keyboard-first and built on APIs Roblox is moving away from. Hub: [[What AI Models Get Wrong in Roblox]].

## 1. Offset sizes, or Scale with no aspect control

- **Wrong:** `UDim2.fromOffset(400, 300)` panels (overflow on phones), or `UDim2.fromScale(0.4, 0.3)` panels with nothing else (stretch into slivers on ultrawide and squash on phones).
- **Why:** the model picks one system and never checks other viewports.
- **Right:** Scale for position and size, `UIAspectRatioConstraint` for shape, `UISizeConstraint` for caps, and one `UIScale` per screen computed from the viewport. **Measured** pattern from the reference project: lay phone panels out at `W x 430` design units and scale by `0.97 * screenHeight / 430` (0.880 at 844 x 390, 0.846 at 667 x 375).
- **Detect:** `fromOffset` on top-level panels; screens with no `UIAspectRatioConstraint`. See [[Layout - Scale Offset and Constraints]].

## 2. `TextScaled` with no bounds

- **Wrong:** `TextScaled = true` alone. Text shrinks to unreadable on phones or balloons on TVs, and mixed lengths in a list render at different sizes.
- **Right:** `TextScaled` plus `UITextSizeConstraint` (MinTextSize and MaxTextSize), or fixed `TextSize` multiplied by your `UIScale`. **Measured** pass bar: drawn text at least 12 px, taps at least 44 px (48 for HUD buttons), gaps at least 8 px, zero overlaps, checked at 844 x 390 and 667 x 375 (see [[Responsive UI for Phone Tablet Console and PC]]).

## 3. Ignoring safe areas and the top bar

- **Wrong:** HUD at the screen corners with `IgnoreGuiInset = true` and no inset handling; buttons under notches or the Roblox top bar.
- **Right:** `ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets` for interactive HUDs, `CoreUISafeInsets` where the top bar matters, and full-bleed only for backgrounds. See [[Safe Areas and Insets]].

## 4. Detecting the device the wrong way

- **Wrong:** `if UserInputService.TouchEnabled then -- phone` (touch laptops, tablets), or `GuiService:IsTenFootInterface()` alone for console.
- **Right:** `UserInputService.PreferredInput` (`KeyboardAndMouse`, `Gamepad`, `Touch`) for input prompts, re-evaluated on `GetPropertyChangedSignal("PreferredInput")`; viewport size for layout. **Measured:** a "phone" rule of `TouchEnabled and shortSide < 520` replaced a scale-based rule that misclassified a touch laptop.

## 5. Keyboard-only input on the old stack

- **Wrong:** `UserInputService.InputBegan` with `KeyCode.E` and nothing else; `ContextActionService` bindings created per use and never unbound; forked `PlayerModule` calls like `GetControls():Disable()`.
- **Why:** 2015-2024 tutorials.
- **Right:** the **Input Action System** (full release June 11, 2026): one `InputAction` per verb with keyboard, gamepad and touch `InputBinding`s inside an `InputContext` you enable and disable with game state. The default player scripts move to IAS by default in early 2027 (planned), which can break `PlayerModule` internals. Under Server Authority, IAS is required for simulation input. See [[Server Authority and Input Migration 2026]].
- Keep `gameProcessedEvent` checks if you stay on `UserInputService`, or typing in chat fires your hotkeys.
- **Detect:** `rg -n "InputBegan|BindAction|GetControls\(\)"` in new code.

## 6. Gamepad and hover

- **Wrong:** hover-only reveals (`MouseEnter`), no `Selectable`/`NextSelection*` setup, no `GuiService.SelectedObject` on menu open.
- **Right:** every interactive element reachable by gamepad selection; set the first selection when a menu opens; show button glyphs only while `PreferredInput` is `Gamepad`. See [[Gamepad and Console UX]].

## 7. Building UI in the wrong place

- **Wrong:** server Scripts editing `StarterGui` at runtime (only affects future spawns) or a player's `PlayerGui` as the main UI path; HUDs with `ResetOnSpawn = true` that rebuild and lose state each death.
- **Right:** UI lives on the client (LocalScript or client modules). The server sends state through attributes or remotes. Persistent HUDs set `ResetOnSpawn = false`.

## 8. Hand-copied styles instead of UI Styling

- **Wrong:** a helper that sets `BackgroundColor3`, `Font`, `UICorner` radius on every button.
- **Right:** **UI Styling** is released (early 2026): `StyleSheet` with `StyleRule`s (`Selector`, `SetProperties`), applied with a `StyleLink` on the ScreenGui, theme values as `$token` attributes. StyleQuery and transitions were still betas as of 2026-10-28. See [[Engine and API Changes 2025-2026]].

## 9. Fonts and text

- **Wrong:** `Enum.Font.Gotham*` (removed, renders as Montserrat), `Font` property instead of `FontFace`, unfiltered player text in labels.
- **Right:** `FontFace = Font.fromName(...)`; filter any text another player wrote with `TextService:FilterStringAsync`, and since October 2026 rate-limit non-chat text inputs to one per minute.

## 10. Chat UI

- **Wrong:** custom chat windows that read message text, or legacy chat modules.
- **Right:** `TextChannelWindow` (can sit on a SurfaceGui) with `Target` set to a `TextChannel`; required for custom chat by May 2027 (see [[Policy and Age Rules 2026]]).

## Common mistakes

- Testing only in the default Studio viewport.
- UIScale applied twice (parent and child), so phones get double shrink.
- `ClipsDescendants` on a frame with `UICorner` and expecting rounded clipping (use `CanvasGroup`, which costs memory).
- Tweening `Size` of layout children every frame, causing list relayout.

## Checklist

- [ ] Checked at 844 x 390, 667 x 375, 1920 x 1080 and a notched phone.
- [ ] Drawn text 12 px or more, taps 44 px or more, gaps 8 px or more.
- [ ] Safe-area insets set on interactive HUDs.
- [ ] Every action has keyboard, gamepad and touch input.
- [ ] Menus navigable by gamepad.
- [ ] `FontFace` used; player text filtered.

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Responsive UI for Phone Tablet Console and PC]]
- [[Input - UserInputService and ContextActionService]]
- [[Case Study - Phone UI Overhaul]]
- [[HUD Design]]
- [[Text Fonts and Rich Text]]

<!-- related:start -->
## Related
[[Debugging UI Layout and Input]] · [[Cookbook - UI]] · [[UI Design Systems]] · [[ScreenGui Fundamentals]] · [[Safe Area]] · [[AI Pitfalls - Stale APIs and Luau]]
<!-- related:end -->
