---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/Tool]
---
# Tool

<!-- tldr:start -->
> [!tldr] TL;DR
> - Tool has no scripts; Tool name matches a `CombatConfig.Weapons` key.
> - Tool sees old module code: `require` cache in Edit -> clone-require.
> - Avoid: Inventory as Tools in Backpack -> Data inventory, Tool only for equipped.
> - Tool used only for holding; inventory lives in the profile.
>
> Cost: TL;DR ~110 tok · whole note ~570 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Tool has no scripts; Tool name matches a `CombatConfig.Weapons` key. (from [[Melee Combat System End to End]])

API snapshot: class, inherits `BackpackItem` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Tool sees old module code: `require` cache in Edit -> clone-require. ([[Batch Processing Tools in Studio]])
- Avoid: Inventory as Tools in Backpack -> Data inventory, Tool only for equipped. ([[Tools and Inventory Systems]])
- Tool used only for holding; inventory lives in the profile. ([[Tools and Inventory Systems]])
- Avoid: Scripts inside the Tool. Every player gets a copy; fixes need to touch every copy; checks get duplicated and drift. ([[Melee Combat System End to End]])

## Mentioned in

28 notes in 10 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]]

### 08 Animation
[[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]] · [[Blade Grip and Wrist Limits]] · [[Custom Rigs - Weapons and Props]] · [[Engine Gotchas]] · [[Equip Draw and Flourish Systems]] · [[LihFolk R15 Keyframe Pipeline]] · [[Locomotion Systems]] · [[Procedural Weapon Motion]] · [[Rigs and Joints]] · [[Snippets - Playing Animations]] · [[The Default Animate Script]] · [[Weapon and Combat Animation]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Tools and Inventory Systems]]

### 13 Production and Case Studies
[[Documentation and Knowledge Bases]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]] · [[Modeling Weapons and Props]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 17 Pipelines
[[Batch Processing Tools in Studio]]

### 24 Worked Builds
[[Melee Combat System End to End]] · [[Saved Inventory End to End]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]]

### 58 Player QoL and Game Tweaks
[[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]

### 62 Engine Reference Cards
[[ContextActionService - Engine Reference Card]]

Also mentioned in (not linked): R15 Rig Anatomy and Attachments · R15 Run Cycle Key Poses · RemoteEvent - Engine Reference Card

<!-- atlas:generated -->
