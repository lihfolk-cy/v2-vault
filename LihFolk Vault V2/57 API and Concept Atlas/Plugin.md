---
tags: [atlas, api, type/atlas, area/studio, area/scripting, api/Plugin]
---
# Plugin

<!-- tldr:start -->
> [!tldr] TL;DR
> - A plugin is Luau that runs inside Studio with access to the editor: the selection, the undo history, script sources, file...
> - Avoid: Editing the original script after Save as Local Plugin -> Delete it, edit in `PluginDebugService` (Plugins - Using and...
> - Plugin debugging on; dev loop through `PluginDebugService`.
> - Plugin runner runs suites sequentially and checks `EditModeActive`.
>
> Cost: TL;DR ~140 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A plugin is Luau that runs inside Studio with access to the editor: the selection, the undo history, script sources, file pickers and docked widgets (from [[Plugins - Using and Writing]]).

API snapshot: class, inherits `Instance`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Editing the original script after Save as Local Plugin -> Delete it, edit in `PluginDebugService` ([[Plugins - Using and Writing]])
- Plugin debugging on; dev loop through `PluginDebugService`. ([[Plugins - Using and Writing]])
- Plugin runner runs suites sequentially and checks `EditModeActive`. ([[UI Automation with VirtualInput and StudioTestService]])

## Mentioned in

12 notes in 9 sections. The 12 most relevant are linked:

### 01 Studio and Workflow
[[Plugins - Using and Writing]] · [[Testing Modes - Play Run and Multi-Client]] · [[Version History and Backups]]

### 02 Luau Scripting
[[Script Types and Run Context]]

### 12 Performance Testing and Debugging
[[UI Automation with VirtualInput and StudioTestService]]

### 15 AI Tools
[[Windows Tooling Pitfalls for Agent Pipelines]]

### 16 MCP and Agents
[[Writing Your Own MCP Server]]

### 17 Pipelines
[[Batch Processing Tools in Studio]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Selection Editing and Bulk Tools]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
