---
tags: [atlas, api, type/atlas, area/animation, area/avatars, api/HumanoidDescription]
---
# HumanoidDescription

<!-- tldr:start -->
> [!tldr] TL;DR
> - `HumanoidDescription` is the declarative recipe for how a Humanoid character looks: body part ids, colours, scales...
> - Avoid: Starting from `Instance.new("HumanoidDescription")` -> Start from `GetAppliedDescription()` (HumanoidDescription and...
> - Avoid: Sending a `HumanoidDescription` through a remote -> Send ids; build on server.
> - Custom emotes go into the character's `HumanoidDescription`: `SetEmotes(table)` maps emote names to arrays of asset ids...
>
> Cost: TL;DR ~160 tok · whole note ~570 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`HumanoidDescription` is the declarative recipe for how a Humanoid character looks: body part ids, colours, scales, accessories, classic clothing, animations and emotes. (from [[HumanoidDescription and Outfit Systems]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Starting from `Instance.new("HumanoidDescription")` -> Start from `GetAppliedDescription()` ([[HumanoidDescription and Outfit Systems]])
- Avoid: Sending a `HumanoidDescription` through a remote -> Send ids; build on server. ([[AvatarEditorService and In-Game Avatar Editors]])
- Custom emotes go into the character's `HumanoidDescription`: `SetEmotes(table)` maps emote names to arrays of asset ids; `SetEquippedEmotes(list)` equips names to the wheel. ([[Emotes and Social Animation]])
- Override individual clips through the `StringValue` / `Animation` children it reads, or through `HumanoidDescription` animation ids. ([[Custom Characters and StarterCharacter]])

## Mentioned in

21 notes in 8 sections. The 21 most relevant are linked:

### 08 Animation
[[Animation Objects]] · [[Custom Characters and StarterCharacter]] · [[Emotes and Social Animation]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Layered Clothing Cages and Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Scale and Animation]] · [[The Default Animate Script]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]] · [[Characters and Humanoids]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[Avatars and UGC Start Here]] · [[Bundles Animation Packs and Emotes for Sale]] · [[HumanoidDescription and Outfit Systems]]

### 46 Resource Library
[[Official Docs - Characters and Animation]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

### 62 Engine Reference Cards
[[Players - Engine Reference Card]]

### Root notes
[[00 Start Here]] · [[Open Questions - Whole Vault]]

<!-- atlas:generated -->
