---
tags: [reference, engine, userinputservice, api/UserInputService, type/reference, area/scripting, level/intermediate]
---

# UserInputService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: ignoring `gameProcessedEvent`. Symptom: typing in chat or a TextBox triggers gameplay actions.
> - Avoid: choosing UI from `TouchEnabled` alone.
> - Avoid: hard-coding key labels like "E". Symptom: wrong glyphs on gamepad or other keyboard layouts; use `GetStringForKeyCode`...
> - Every input handler returns early when `gameProcessedEvent` is true.
> - Button prompts update on `LastInputTypeChanged` or `PreferredInput` changes.
> - Rebindable actions use the Input Action System where available.
>
> Cost: TL;DR ~170 tok · whole note ~1.4k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The client-side service for raw device input and device detection; see [[UserInputService]], [[Input - UserInputService and ContextActionService]] and, for rebindable actions, [[Rebinding Controls with the Input Action System]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| InputBegan | event | `(input: InputObject, gameProcessedEvent: boolean)` | - | Client; only while the window has focus | - |
| InputChanged | event | `(input: InputObject, gameProcessedEvent: boolean)` | - | Client; mouse movement, wheel, thumbsticks | - |
| InputEnded | event | `(input: InputObject, gameProcessedEvent: boolean)` | - | Client | - |
| PreferredInput | prop | `Enum.PreferredInput` | - | Read-only; best signal for which UI to show | no |
| TouchEnabled / KeyboardEnabled / MouseEnabled / GamepadEnabled | prop | boolean | - | Read-only; describes hardware present, not what the player is using | no |
| GetLastInputType | method | `() -> Enum.UserInputType` | - | Client | no |
| LastInputTypeChanged | event | `(lastInputType: Enum.UserInputType)` | - | Client; swap button prompts | - |
| IsKeyDown | method | `(keyCode: Enum.KeyCode) -> boolean` | - | Client | no |
| IsMouseButtonPressed | method | `(mouseButton: Enum.UserInputType) -> boolean` | - | Client | no |
| IsGamepadButtonDown | method | `(gamepadNum: Enum.UserInputType, gamepadKeyCode: Enum.KeyCode) -> boolean` | - | Client | no |
| GetMouseLocation | method | `() -> Vector2` | - | Client; screen pixels | no |
| GetMouseDelta | method | `() -> Vector2` | - | Client; useful while the mouse is locked | no |
| MouseBehavior | prop | `Enum.MouseBehavior` | - | Client; Default, LockCenter, LockCurrentPosition | no |
| MouseDeltaSensitivity | prop | float | - | Client; 0 to 10, scales reported deltas only | no |
| MouseIconEnabled | prop | boolean | - | Client | no |
| GetConnectedGamepads | method | `() -> {Enum.UserInputType}` | - | Client | no |
| GetStringForKeyCode | method | `(keyCode: Enum.KeyCode, format: Enum.KeyCodeStringFormat?) -> string` | format = Default | Client; respects the player's keyboard layout | no |
| [[GetImageForKeyCode]] | method | `(keyCode: Enum.KeyCode) -> ContentId` | - | Client; gamepad glyphs | no |
| JumpRequest | event | `()` | - | Client; fires several times per jump, so debounce | - |
| TouchTap / TouchSwipe / TouchPinch | event | gesture-specific, each ends with `gameProcessedEvent` | - | Client; touch screens | - |
| GetFocusedTextBox | method | `() -> TextBox` | - | Client | no |

Retired names and their replacements:
- `ModalEnabled` -> `GuiService.TouchControlsEnabled`.
- `UserHeadCFrame`, `GetUserCFrame` and `UserCFrameChanged` -> `VRService:GetUserCFrame()` and `VRService.UserCFrameChanged`; `VREnabled` -> `VRService.VREnabled`.
- The reference pages point button and key bindings toward `InputAction` plus `InputBinding` (the Input Action System), and on-screen key labels toward `InputActionLabel`.

## Limits and defaults

- `MouseDeltaSensitivity` is clamped to 0-10; at 0, movement events still fire but report zero change.
- `InputBegan` does not capture mouse wheel movement; read the wheel through `InputChanged`.
- Input events fire only while the Roblox window is focused.
- A visible `GuiButton` with `Modal` enabled overrides `MouseBehavior` unless the right mouse button is held.

## Replication and authority

- Client only: use it from a LocalScript, a module required by one, or a Script with `RunContext = Enum.RunContext.Client`.
- Nothing here replicates; send intent (for example "attack pressed") to the server through a validated RemoteEvent, never raw results.
- The server must re-check every request, since any client can fire remotes without pressing a key.

## Common mistakes

- Avoid: ignoring `gameProcessedEvent`. Symptom: typing in chat or a TextBox triggers gameplay actions.
- Avoid: choosing UI from `TouchEnabled` alone. Symptom: laptops with touch screens or phones with controllers get the wrong layout; read `PreferredInput` instead.
- Avoid: hard-coding key labels like "E". Symptom: wrong glyphs on gamepad or other keyboard layouts; use `GetStringForKeyCode` or `GetImageForKeyCode`.
- Avoid: leaving a `Modal` GuiButton visible during first-person aiming. Symptom: the mouse lock from `MouseBehavior` stops applying until the button hides.
- Avoid: trusting client input on the server. Symptom: exploiters fire remotes at impossible rates; rate-limit and validate server side.

## Checklist

- Every input handler returns early when `gameProcessedEvent` is true.
- Button prompts update on `LastInputTypeChanged` or `PreferredInput` changes.
- Rebindable actions use the Input Action System where available.
- Gameplay effects are decided on the server from validated intent.

Source: https://create.roblox.com/docs/reference/engine/classes/UserInputService and https://create.roblox.com/docs/reference/engine/classes/InputAction - verified 2026-10-29

<!-- related:start -->
## Related
[[ContextActionService - Engine Reference Card]] · [[GuiService - Engine Reference Card]] · [[ProximityPrompt - Engine Reference Card]] · [[ScrollingFrame - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[BasePart - Engine Reference Card]]
<!-- related:end -->
