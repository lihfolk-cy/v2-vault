---
tags: [atlas, api, type/atlas, area/ai, area/studio, api/ChangeHistoryService]
---
# ChangeHistoryService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ChangeHistoryService` is the API behind that test.
> - `ChangeHistoryService` does nothing in a running experience.
> - Every write runs inside a ChangeHistoryService recording that is cancelled on failure, so a failed operation reverts itself.
> - One recording per drag (pattern A in Undo and ChangeHistoryService Done Right): begin on `MouseButton1Down`, commit on...
>
> Cost: TL;DR ~130 tok · whole note ~540 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ChangeHistoryService` is the API behind that test. (from [[Undo and ChangeHistoryService Done Right]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ChangeHistoryService` does nothing in a running experience. ([[Plugins - Using and Writing]])
- Every write runs inside a ChangeHistoryService recording that is cancelled on failure, so a failed operation reverts itself. ([[Building a Studio Plugin End to End]])
- One recording per drag (pattern A in Undo and ChangeHistoryService Done Right): begin on `MouseButton1Down`, commit on `MouseButton1Up`. ([[Selection Editing and Bulk Tools]])
- Undo history. Changes made by a plugin go into Studio's undo stack only if the plugin records them with ChangeHistoryService. ([[Writing Your Own MCP Server]])

## Mentioned in

20 notes in 11 sections. The 20 most relevant are linked:

### 01 Studio and Workflow
[[Command Bar and Studio Scripting]] · [[Plugins - Using and Writing]]

### 06 World Building and Art
[[Roads, Rivers and Paths Carved Along Curves in Terrain]]

### 13 Production and Case Studies
[[Safe Changes in a Shared Place]]

### 16 MCP and Agents
[[Agent Review Loops and Guardrails in Practice]] · [[Safety Rules for AI Agents in Studio]] · [[Studio Plugins and Local HTTP Bridges]] · [[Writing Your Own MCP Server]]

### 17 Pipelines
[[Batch Processing Tools in Studio]] · [[Pipeline Design Principles]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Plugin Development Start Here]] · [[Selection Editing and Bulk Tools]] · [[Undo and ChangeHistoryService Done Right]]

### 44 Materials and Surfaces
[[SurfaceAppearance PBR Workflow]]

### 46 Resource Library
[[Links - Plugins and custom tools]]

### 53 Voxel Modelling Deep Dive
[[Voxel Palettes - Ramps Hue Shifting and Limits]]

### 54 Untextured Stylised Modelling
[[Keeping a Mixed Asset Library Consistent]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
