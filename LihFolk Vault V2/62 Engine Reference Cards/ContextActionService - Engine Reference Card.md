---
tags: [reference, engine, contextactionservice, api/ContextActionService, type/reference, area/scripting, level/intermediate, api/InputAction]
---

# ContextActionService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: handlers that end without a return value when other systems share the key.
> - Avoid: naming actions after keys ("KeyH").
> - Avoid: binding without a matching `UnbindAction` on context exit.
> - Bind on context enter, unbind on context exit (LocalToolEquipped / LocalToolUnequipped pair).
> - Explicit `Sink` or `Pass` returned from every handler.
> - Touch buttons customised through GetButton, SetTitle, SetImage, SetPosition.
>
> Cost: TL;DR ~150 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Binds named actions to keys, gamepad buttons and auto-made touch buttons while a context (a tool, a seat, a nearby door) is active. Topic notes: [[Input - UserInputService and ContextActionService]], [[ContextActionService]]. For new work the docs point to the Input Action System: [[Rebinding Controls with the Input Action System]], [[InputAction]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| BindAction | method | `(actionName: string, handler: (name, Enum.UserInputState, InputObject) -> Enum.ContextActionResult?, createTouchButton: boolean, ...inputTypes)` | priority = ContextActionPriority.Default (2000) | Client only; planned for deprecation | no |
| BindActionAtPriority | method | `(actionName, handler, createTouchButton, priorityLevel: number, ...inputTypes)` | - | Higher priority runs first, ignoring bind order | no |
| UnbindAction | method | `(actionName: string)` | - | Silent if the name is not bound | no |
| UnbindAllActions | method | `()` | - | Removes every binding and touch button | no |
| GetButton | method | `(actionName: string) -> ImageButton?` | - | nil if no button was made or device is not touch | yes |
| SetTitle | method | `(actionName: string, title: string)` | - | Text on the touch button | no |
| SetImage | method | `(actionName: string, image: string)` | - | Image on the touch button | no |
| SetPosition | method | `(actionName: string, position: UDim2)` | - | Moves the touch button | no |
| SetDescription | method | `(actionName: string, description: string)` | - | Text description only; no button effect | no |
| GetBoundActionInfo | method | `(actionName: string) -> Dictionary` | - | stackOrder, priorityLevel, inputTypes and more | no |
| GetAllBoundActionInfo | method | `() -> {[string]: Dictionary}` | - | Debug the action stack | no |
| BindActivate | method | `(userInputType: Enum.UserInputType, ...keyCodes)` | - | Keyboard or Gamepad1 to activate tools/buttons | no |
| UnbindActivate | method | `(userInputType: Enum.UserInputType, keyCode: Enum.KeyCode = None)` | KeyCode None | Undo BindActivate | no |
| GetCurrentLocalToolIcon | method | `() -> string?` | - | TextureId of the equipped Tool | no |
| LocalToolEquipped | event | `(toolEquipped: Tool)` | - | Good place to bind tool actions | - |
| LocalToolUnequipped | event | `(toolUnequipped: Tool)` | - | Good place to unbind | - |

Superseded: `BindActionToInputTypes` -> `BindAction`. Whole-service direction: `InputContext`, `InputAction` and `InputBinding` instances (Input Action System).

## Limits and defaults

- Default priority from `BindAction`: 2000, the value of `Enum.ContextActionPriority.Medium`.
- Without priorities, bindings form a stack: the most recently bound handler for an input runs first.
- Returning `Enum.ContextActionResult.Pass` hands the input to the next handler; returning `nil` or `Sink` consumes it.
- A `Cancel` state arrives when another action binds over an in-progress input or the action is unbound; its InputObject reads `KeyCode.Unknown` / `UserInputType.None`.
- First touch button creates a ScreenGui "ContextActionGui" with a Frame "ContextButtonFrame" in PlayerGui.

## Replication and authority

- Client-only: the service runs in LocalScripts (or client RunContext). The server never sees bindings.
- Actions that matter to gameplay send a request through a RemoteEvent; the server validates it.

## Common mistakes

- Avoid: handlers that end without a return value when other systems share the key. Symptom: the input is sunk and default controls (jump, camera) stop responding; return `Pass` when you do not consume it.
- Avoid: naming actions after keys ("KeyH"). Symptom: confusing code once the same action has gamepad and touch bindings; name the action ("CarHorn").
- Avoid: binding without a matching `UnbindAction` on context exit. Symptom: a horn or ability still fires after leaving the seat.
- Avoid: reacting to every state. Symptom: actions fire twice (Begin and End); check `inputState == Enum.UserInputState.Begin`.
- Avoid: building a new control scheme on BindAction. Symptom: future migration work, since the binding methods are planned for deprecation.

## Checklist

- Bind on context enter, unbind on context exit (LocalToolEquipped / LocalToolUnequipped pair).
- Explicit `Sink` or `Pass` returned from every handler.
- Touch buttons customised through GetButton, SetTitle, SetImage, SetPosition.
- New input systems sketched on InputContext / InputAction / InputBinding.

Source: https://create.roblox.com/docs/reference/engine/classes/ContextActionService - verified 2026-10-29

<!-- related:start -->
## Related
[[UserInputService - Engine Reference Card]] · [[Input Remapping and One-Handed Play]] · [[BadgeService - Engine Reference Card]] · [[RunService - Engine Reference Card]] · [[ProximityPrompt - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Players - Engine Reference Card]] · [[RemoteEvent - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]]
<!-- related:end -->
