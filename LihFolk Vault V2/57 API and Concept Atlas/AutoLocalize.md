---
tags: [atlas, api, type/atlas, area/narrative, area/ui, api/AutoLocalize]
---
# AutoLocalize

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AutoLocalize` is inherited: setting it false on a container disables it for descendants unless they override.
> - Avoid: Dynamic labels with `AutoLocalize` on: tables full of "Gems: 1,240".
> - `AutoLocalize = false` on names, numbers and script-filled labels.
> - set `AutoLocalize = false` on labels that show player names, numbers, timers and other dynamic values, and format those...
>
> Cost: TL;DR ~140 tok · whole note ~300 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AutoLocalize` is inherited: setting it false on a container disables it for descendants unless they override. (from [[Localization]])

API snapshot: member of `AudioTextToSpeech`, `Decal`, `GuiBase2d`, `ProximityPrompt` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Dynamic labels with `AutoLocalize` on: tables full of "Gems: 1,240". ([[Localization]])
- `AutoLocalize = false` on names, numbers and script-filled labels. ([[Localization]])
- set `AutoLocalize = false` on labels that show player names, numbers, timers and other dynamic values, and format those through your own helpers;. ([[Localization Pipeline]])
- Set `AutoLocalize` from the glossary. Labels that show kept names should not be auto-translated (Localization). ([[Localization-Ready Writing]])

## Mentioned in

4 notes in 3 sections. The 4 most relevant are linked:

### 05 UI and UX
[[Localization]]

### 17 Pipelines
[[Localization Pipeline]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Localization-Ready Writing]]

<!-- atlas:generated -->
