---
tags: [atlas, api, type/atlas, area/ui, api/TopbarInset]
---
# TopbarInset

<!-- tldr:start -->
> [!tldr] TL;DR
> - `TopbarInset` changes at runtime: Docs list health changes, `SetCoreGuiEnabled` calls and changes to Roblox controls, and...
> - Avoid: Reading `TopbarInset` once at startup.
> - HUD layout respects `TopbarInset` or `ScreenInsets`.
>
> Cost: TL;DR ~100 tok · whole note ~220 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`TopbarInset` changes at runtime: Docs list health changes, `SetCoreGuiEnabled` calls and changes to Roblox controls, and recommend listening with `GetPropertyChangedSignal`. (from [[Safe Areas and Insets]])

API snapshot: member of `GuiService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Reading `TopbarInset` once at startup. ([[Safe Areas and Insets]])
- HUD layout respects `TopbarInset` or `ScreenInsets`. ([[GuiService - Engine Reference Card]])

## Mentioned in

3 notes in 3 sections. The 3 most relevant are linked:

### 05 UI and UX
[[Safe Areas and Insets]]

### 56 Field Notes
[[Centre-Screen Announcements That Stay Centred]]

### 62 Engine Reference Cards
[[GuiService - Engine Reference Card]]

<!-- atlas:generated -->
