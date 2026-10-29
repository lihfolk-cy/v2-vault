---
tags: [atlas, api, type/atlas, area/studio, api/PluginGui]
---
# PluginGui

<!-- tldr:start -->
> [!tldr] TL;DR
> - `PluginGui` adds `Title`, `BindToClose`, `GetRelativeMousePosition`, the four `PluginDrag*` events, `WindowFocused` and...
> - Drag and drop. `plugin:StartDrag(info)` and `PluginGui.PluginDragDropped` move data between widgets (Docs).
> - The widget is a `LayerCollector` (it inherits from `PluginGui`), so you parent `GuiObject`s directly to it, exactly as you...
>
> Cost: TL;DR ~130 tok · whole note ~270 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`PluginGui` adds `Title`, `BindToClose`, `GetRelativeMousePosition`, the four `PluginDrag*` events, `WindowFocused` and `WindowFocusReleased`. (from [[Plugin UI with DockWidgets]])

API snapshot: class, inherits `LayerCollector`, not creatable with `Instance.new` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Drag and drop. `plugin:StartDrag(info)` and `PluginGui.PluginDragDropped` move data between widgets (Docs). ([[Plugins - Using and Writing]])
- The widget is a `LayerCollector` (it inherits from `PluginGui`), so you parent `GuiObject`s directly to it, exactly as you would to a `ScreenGui` (Roblox docs). ([[Plugin UI with DockWidgets]])

## Mentioned in

4 notes in 3 sections. The 4 most relevant are linked:

### 01 Studio and Workflow
[[Plugins - Using and Writing]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Plugin UI with DockWidgets]]

### 46 Resource Library
[[Official Docs - Asset Creation]]

<!-- atlas:generated -->
