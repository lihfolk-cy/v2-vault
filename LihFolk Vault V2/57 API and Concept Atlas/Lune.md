---
tags: [atlas, concept, type/atlas, area/pipelines, area/performance]
---
# Lune

<!-- tldr:start -->
> [!tldr] TL;DR
> - Lune runs Luau outside Roblox with filesystem, process, network and a `roblox` library that can read and write place and model...
> - Pure suite runs on every push (Lune or equivalent).
> - Pure modules under Lune (a standalone Luau runtime): fastest, no Roblox needed, but only for code that touches no engine APIs.
> - Automated Testing with TestEZ and Jest-Lua, Code Pipeline - Rojo Git and CI, Lune.
>
> Cost: TL;DR ~140 tok · whole note ~380 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Lune runs Luau outside Roblox with filesystem, process, network and a `roblox` library that can read and write place and model files. (from [[External Tooling - Rojo Wally Selene StyLua]])

## Key facts

- Pure suite runs on every push (Lune or equivalent). ([[Automated Testing with TestEZ and Jest-Lua]])
- Pure modules under Lune (a standalone Luau runtime): fastest, no Roblox needed, but only for code that touches no engine APIs. ([[Testing Strategies and Frameworks]])
- Automated Testing with TestEZ and Jest-Lua, Code Pipeline - Rojo Git and CI, Lune. ([[Save Migration Tests - Fixture Saves and Golden Files]])
- Pure logic (damage formulas, odds, economy maths, data migrations) as unit tests, runnable outside Roblox with Lune or inside with a test runner. ([[Build Test and Release Pipeline]])

## Mentioned in

9 notes in 4 sections. The 9 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]]

### 12 Performance Testing and Debugging
[[Automated Testing with TestEZ and Jest-Lua]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[Testing Strategies and Frameworks]]

### 17 Pipelines
[[Batch Processing Tools in Studio]] · [[Build Test and Release Pipeline]] · [[Code Pipeline - Rojo Git and CI]] · [[Pipeline Design Principles]]

### 28 Business and Careers
[[Open-Source Licenses for Roblox Libraries - Quick Reference]]

<!-- atlas:generated -->
