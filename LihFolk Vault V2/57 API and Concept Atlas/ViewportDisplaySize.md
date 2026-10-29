---
tags: [atlas, api, type/atlas, area/ui, area/accessibility, api/ViewportDisplaySize]
---
# ViewportDisplaySize

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ViewportDisplaySize` can change at runtime: docs suggest listening with `GetPropertyChangedSignal` to adapt UI, without...
> - Treat `ViewportDisplaySize.Large` plus gamepad as "ten-foot UI": players sit 2 to 3 m away.
> - `IsTenFootInterface` -> `ViewportDisplaySize`.
>
> Cost: TL;DR ~110 tok · whole note ~260 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ViewportDisplaySize` can change at runtime: docs suggest listening with `GetPropertyChangedSignal` to adapt UI, without saying what triggers a change (Roblox docs, as of October 2026). (from [[Readable Text and UI Scale]])

API snapshot: member of `GuiService`, `StyleQuery` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Treat `ViewportDisplaySize.Large` plus gamepad as "ten-foot UI": players sit 2 to 3 m away. ([[Responsive UI for Phone Tablet Console and PC]])
- `IsTenFootInterface` -> `ViewportDisplaySize`. ([[GuiService - Engine Reference Card]])

## Mentioned in

3 notes in 3 sections. The 3 most relevant are linked:

### 05 UI and UX
[[Responsive UI for Phone Tablet Console and PC]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 62 Engine Reference Cards
[[GuiService - Engine Reference Card]]

<!-- atlas:generated -->
