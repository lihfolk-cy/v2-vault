---
tags: [atlas, api, type/atlas, area/gameplay, area/networking, api/MaxActivationDistance]
---
# MaxActivationDistance

<!-- tldr:start -->
> [!tldr] TL;DR
> - `MaxActivationDistance` is how close the character must be for the prompt to appear.
> - Simulate it: temporarily set `MaxActivationDistance = 500` on the prompt and press it from 50 studs away.
> - Prompt range. Set a crystal's prompt `MaxActivationDistance` to 200 temporarily and trigger it from far away: no progress...
>
> Cost: TL;DR ~120 tok · whole note ~340 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`MaxActivationDistance` is how close the character must be for the prompt to appear. (from [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])

API snapshot: member of `ClickDetector`, `ProximityPrompt` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Simulate it: temporarily set `MaxActivationDistance = 500` on the prompt and press it from 50 studs away. ([[Pet Hatching and Following End to End]])
- Prompt range. Set a crystal's prompt `MaxActivationDistance` to 200 temporarily and trigger it from far away: no progress (server range check). ([[Quest Chain System End to End]])

## Mentioned in

7 notes in 6 sections. The 7 most relevant are linked:

### 03 Architecture and Networking
[[Exploits and Anti-Cheat]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]]

### 33 Level Design
[[Lobby and Hub Design]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 62 Engine Reference Cards
[[ProximityPrompt - Engine Reference Card]]

<!-- atlas:generated -->
