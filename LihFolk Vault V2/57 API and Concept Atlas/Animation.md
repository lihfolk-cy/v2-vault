---
tags: [atlas, api, type/atlas, area/animation, area/performance, api/Animation]
---
# Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Animation is not listed among the types "not available for updating", so the Update Asset endpoint can push a new version to...
> - Avoid: Loading the same Animation every time you play it -> Cache one track per Animator per clip.
> - Preload with `ContentProvider:PreloadAsync` on the `Animation` objects during the loading screen, and fit `duration` only...
> - Saved clips (Animation Editor Save) are `KeyframeSequence`s in ServerStorage: no id at all.
>
> Cost: TL;DR ~150 tok · whole note ~650 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Animation is not listed among the types "not available for updating", so the Update Asset endpoint can push a new version to an existing id (verify before relying on it). (from [[Publishing Animations]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Loading the same Animation every time you play it -> Cache one track per Animator per clip. ([[Animation Objects]])
- Preload with `ContentProvider:PreloadAsync` on the `Animation` objects during the loading screen, and fit `duration` only after `Length > 0`. ([[Snippets - Playing Animations]])
- Saved clips (Animation Editor Save) are `KeyframeSequence`s in ServerStorage: no id at all. ([[Publishing Animations]])
- Put a `Hit` marker on that frame (a `KeyframeMarker` added with the editor's Animation Events, or in code). ([[Combat Animation Craft]])

## Mentioned in

40 notes in 4 sections. The 25 most relevant are linked:

### 08 Animation
[[Animation Asset Permissions and Groups]] · [[Animation Editor Advanced]] · [[Animation Glossary]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Case Study - Abilities That Only Worked in Studio]] · [[Combat Animation Craft]] · [[Custom Locomotion Controller Design]] · [[Debugging Animation Problems]] · [[Emotes and Social Animation]] · [[Engine Gotchas]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Lua Keyframe Player]] · [[Moon Animator and Third-Party Tools]] · [[Performance and Memory]] · [[Publishing Animations]] · [[Replication and Ownership]] · [[Snippets - Building and Sampling Clips]] · [[Snippets - Playing Animations]] · [[Testing Animations in Studio]] · [[The Default Animate Script]]

### 12 Performance Testing and Debugging
[[Developer Console and Stats]] · [[Hunting Memory Leaks Step by Step]]

### 37 Avatars and UGC
[[Bundles Animation Packs and Emotes for Sale]]

Also mentioned in (not linked): Ability Kits Architecture · Authoring Clips in Code · Combat Combo Systems · Custom Characters and StarterCharacter · Frame Order and RunService Timing · Idle Breathing and Secondary Motion · Locomotion Systems · Lua Keyframe Player Internals · Melee Combat System End to End · Memory Budgets and Leaks · Multi-Bone IK - FABRIK and CCD · Snippets - Enemy Client Animator · Snippets - Lua Keyframe Player Core · Studio Tooling Architecture · Troubleshooting Table

<!-- atlas:generated -->
