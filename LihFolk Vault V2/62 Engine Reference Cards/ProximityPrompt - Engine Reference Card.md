---
tags: [reference, engine, proximityprompt, api/ProximityPrompt, type/reference, area/scripting, level/intermediate, area/ai, api/Player]
---

# ProximityPrompt - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: granting items straight from `Triggered` with no checks.
> - Avoid: parenting a prompt to a Model with no PrimaryPart.
> - Avoid: several AlwaysShow prompts on one key.
> - ActionText and ObjectText read clearly and are localized.
> - Server-side handler validates distance, state and cooldown.
> - HoldDuration used for anything costly or destructive.
>
> Cost: TL;DR ~130 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A ready-made "press or hold a key near this object" interaction for doors, pickups and NPCs; see [[ProximityPrompt]] and [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| ActionText | prop | string | "Interact" | The verb shown to the player | no |
| ObjectText | prop | string | "" | Optional object name above the action | no |
| KeyboardKeyCode | prop | `Enum.KeyCode` | E | Keyboard trigger | no |
| GamepadKeyCode | prop | `Enum.KeyCode` | ButtonX | Gamepad trigger | no |
| HoldDuration | prop | float (s) | - | 0 triggers on press; above 0 shows a hold gauge | no |
| [[MaxActivationDistance]] | prop | float (studs) | - | Character range for the prompt to appear | no |
| MaxIndicatorDistance | prop | float (studs) | 0 | Above 0 shows a lightweight indicator farther out | no |
| [[RequiresLineOfSight]] | prop | boolean | true | Needs a clear line from the camera to the prompt | no |
| Exclusivity | prop | `Enum.ProximityPromptExclusivity` | - | OnePerButton, OneGlobally or AlwaysShow | no |
| ClickablePrompt | prop | boolean | - | Click or tap the prompt UI; touch can always tap | no |
| Enabled | prop | boolean | - | Shows or hides this prompt | no |
| Style | prop | `Enum.ProximityPromptStyle` | - | Custom removes the default UI so you draw your own | no |
| UIOffset | prop | Vector2 | - | Pixel offset for the prompt UI | no |
| Triggered | event | `(playerWhoTriggered: Player)` | - | On press, or after the hold completes | - |
| TriggerEnded | event | `(playerWhoTriggered: Player)` | - | Key or button released | - |
| PromptButtonHoldBegan | event | `(playerWhoTriggered: Player)` | - | Hold started on a prompt with HoldDuration above 0 | - |
| PromptButtonHoldEnded | event | `(playerWhoTriggered: Player)` | - | Hold released | - |
| PromptShown | event | `(inputType: Enum.ProximityPromptInputType)` | - | Client side; build custom UI here | - |
| PromptHidden | event | `()` | - | Client side | - |
| IndicatorShown / IndicatorHidden | event | `()` | - | Client side; only when MaxIndicatorDistance is above 0 | - |
| InputHoldBegin / InputHoldEnd | method | `() -> ()` | - | Client; drive a custom prompt button | no |
| ProximityPromptService.PromptTriggered | event | `(prompt: ProximityPrompt, player: Player)` | - | One handler for every prompt | - |

## Limits and defaults

- Documented defaults: ActionText "Interact", ObjectText empty, KeyboardKeyCode E, GamepadKeyCode ButtonX, RequiresLineOfSight true, MaxIndicatorDistance 0 (indicator off).
- The prompt works when parented to a BasePart, an Attachment, or a Model with a PrimaryPart, inside Workspace.
- With `Enum.ProximityPromptExclusivity.OnePerButton`, only one in-range prompt per key code shows at a time; `OneGlobally` shows one prompt overall; `AlwaysShow` shows all of them, and one key press triggers every visible prompt sharing that key.
- Phones and tablets can always tap the prompt, whatever `ClickablePrompt` says.

## Replication and authority

- Create prompts on the server so every client sees them; the default UI is drawn on each client.
- `Triggered` and the hold events pass the `Player`, so handle rewards in a server Script.
- Exploiters can fire prompts from outside the intended range; re-check the character's distance and any cooldown on the server before granting anything.
- Shown, hidden and indicator events are client-side, which is where custom-style UI belongs.

## Common mistakes

- Avoid: granting items straight from `Triggered` with no checks. Symptom: exploiters loot from across the map; validate distance, state and cooldown on the server.
- Avoid: parenting a prompt to a Model with no PrimaryPart. Symptom: the prompt never appears.
- Avoid: several AlwaysShow prompts on one key. Symptom: a single press opens every nearby door and chest at once.
- Avoid: setting `Style` to Custom without handling `PromptShown`. Symptom: the prompt still works but nothing is drawn.
- Avoid: one Script per prompt across hundreds of objects. Symptom: duplicate code and connections; use `ProximityPromptService.PromptTriggered` or tag-driven setup.

## Checklist

- ActionText and ObjectText read clearly and are localized.
- Server-side handler validates distance, state and cooldown.
- HoldDuration used for anything costly or destructive.
- Gamepad and touch tested alongside keyboard.

Source: https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt and https://create.roblox.com/docs/ui/proximity-prompts - verified 2026-10-29

<!-- related:start -->
## Related
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[UserInputService - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[ContextActionService - Engine Reference Card]] · [[BillboardGui - Engine Reference Card]] · [[Lobby and Hub Design]]
<!-- related:end -->
