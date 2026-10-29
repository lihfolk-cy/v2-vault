---
tags: [atlas, api, type/atlas, area/gameplay, area/world, api/RequiresLineOfSight]
---
# RequiresLineOfSight

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RequiresLineOfSight` (default true) hides the prompt unless there is a clear path from the camera to the prompt's parent.
> - Fix by parenting the prompt to an attachment in front of the decoration, setting the decoration's `CanQuery` off if it does...
> - Documented defaults: ActionText "Interact", ObjectText empty, KeyboardKeyCode E, GamepadKeyCode ButtonX, RequiresLineOfSight...
>
> Cost: TL;DR ~140 tok · whole note ~300 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RequiresLineOfSight` (default true) hides the prompt unless there is a clear path from the camera to the prompt's parent. (from [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])

API snapshot: member of `ProximityPrompt` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Fix by parenting the prompt to an attachment in front of the decoration, setting the decoration's `CanQuery` off if it does not need it, or turning off `RequiresLineOfSight` for that prompt. ([[Lobby and Hub Design]])
- Documented defaults: ActionText "Interact", ObjectText empty, KeyboardKeyCode E, GamepadKeyCode ButtonX, RequiresLineOfSight true, MaxIndicatorDistance 0 (indicator off). ([[ProximityPrompt - Engine Reference Card]])

## Mentioned in

3 notes in 3 sections. The 3 most relevant are linked:

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 33 Level Design
[[Lobby and Hub Design]]

### 62 Engine Reference Cards
[[ProximityPrompt - Engine Reference Card]]

<!-- atlas:generated -->
