---
tags: [atlas, api, type/atlas, area/platform, area/scripting, api/SetCore]
---
# SetCore

<!-- tldr:start -->
> [!tldr] TL;DR
> - `SetCore` calls can fail if the core scripts that register an option have not loaded yet, which is most likely in the first...
> - `SetCore` and `GetCore` calls wrapped with retries.
> - Edge case: `SetCore` can error if called very early, before the CoreScripts have registered the callback.
> - Your game can open Roblox's own prompts: `StarterGui:SetCore("PromptBlockPlayer", player)` and `"PromptUnblockPlayer"` (Roblox...
>
> Cost: TL;DR ~150 tok · whole note ~430 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`SetCore` calls can fail if the core scripts that register an option have not loaded yet, which is most likely in the first moments of a session (rule of thumb from common experience; the reference does not document a registration event for these options). (from [[Avatar Context Menus Profiles and Social Surfaces]])

API snapshot: member of `StarterGui` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `SetCore` and `GetCore` calls wrapped with retries. ([[Avatar Context Menus Profiles and Social Surfaces]])
- Edge case: `SetCore` can error if called very early, before the CoreScripts have registered the callback. ([[Notification and Toast Systems]])
- Your game can open Roblox's own prompts: `StarterGui:SetCore("PromptBlockPlayer", player)` and `"PromptUnblockPlayer"` (Roblox docs, client only). ([[Block and Mute Respecting Platform Rules]])
- Everything that can fail is wrapped. Web calls, DataStores and `SetCore` go through `pcall` with a bounded retry. ([[Luau Cookbook Start Here]])

## Mentioned in

9 notes in 6 sections. The 9 most relevant are linked:

### 05 UI and UX
[[Notification and Toast Systems]]

### 09 Gameplay Systems
[[Downed, Revive and Bleed-Out States]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]] · [[Luau Cookbook Start Here]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]] · [[Badges and Achievement Design]] · [[Platform Features Start Here]]

### 58 Player QoL and Game Tweaks
[[Block and Mute Respecting Platform Rules]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
