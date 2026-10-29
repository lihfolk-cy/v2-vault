---
tags: [atlas, api, type/atlas, area/gameplay, area/scripting, api/IntValue]
---
# IntValue

<!-- tldr:start -->
> [!tldr] TL;DR
> - `IntValue` holds whole numbers only (64-bit, Roblox docs); fractional coins are truncated.
> - Do not use `IntValue` for display; this build uses attributes and formats them.
> - `leaderstats` (a Folder named `leaderstats` with `IntValue`/`NumberValue`/`StringValue` children under the Player) is still...
>
> Cost: TL;DR ~120 tok · whole note ~380 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`IntValue` holds whole numbers only (64-bit, Roblox docs); fractional coins are truncated. (from [[Pet Hatching and Following End to End]])

API snapshot: class, inherits `ValueBase` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Do not use `IntValue` for display; this build uses attributes and formats them. ([[Rebirth and Prestige System End to End]])
- `leaderstats` (a Folder named `leaderstats` with `IntValue`/`NumberValue`/`StringValue` children under the Player) is still how the default player list shows stats. ([[Instances Attributes and Tags]])

## Mentioned in

12 notes in 7 sections. The 12 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Instances Attributes and Tags]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 24 Worked Builds
[[Global Leaderboards End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 40 Game Math
[[Big Numbers Precision and Formatting]]

### 43 Genre Systems End to End
[[Obby Checkpoints and Stage Saves End to End]]

### 50 Team Collaboration and Project Management
[[Working with Contractors and Revenue Splits]]

<!-- atlas:generated -->
