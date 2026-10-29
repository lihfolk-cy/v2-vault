---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/LoadAnimation]
---
# LoadAnimation

<!-- tldr:start -->
> [!tldr] TL;DR
> - `LoadAnimation` returns immediately; the asset downloads in the background.
> - Avoid: `Humanoid:LoadAnimation` in new code -> `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` (Animation...
> - Avoid: Calling `LoadAnimation` per use. (Engine Gotchas)
> - Avoid: `animator:LoadAnimation(anim):Play()` per click (new track each time; 256-track warning).
>
> Cost: TL;DR ~130 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`LoadAnimation` returns immediately; the asset downloads in the background. (from [[AnimationTrack Reference]])

API snapshot: member of `AnimationController`, `Animator`, `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `Humanoid:LoadAnimation` in new code -> `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim)` ([[Animation Objects]])
- Avoid: Calling `LoadAnimation` per use. ([[Engine Gotchas]])
- Avoid: `animator:LoadAnimation(anim):Play()` per click (new track each time; 256-track warning). ([[Snippets - Playing Animations]])

## Mentioned in

39 notes in 4 sections. The 25 most relevant are linked:

### 08 Animation
[[Ability Kits Architecture]] · [[Animation Asset Permissions and Groups]] · [[Animation Objects]] · [[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Case Study - Abilities That Only Worked in Studio]] · [[Combat Animation Craft]] · [[Combat Combo Systems]] · [[Custom Locomotion Controller Design]] · [[Debugging Animation Problems]] · [[Emotes and Social Animation]] · [[Engine Gotchas]] · [[Idle Breathing and Secondary Motion]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Lua Keyframe Player]] · [[Open Questions]] · [[Performance and Memory]] · [[Snippets - Playing Animations]] · [[Troubleshooting Table]]

### 12 Performance Testing and Debugging
[[Hunting Memory Leaks Step by Step]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Physics and Animation]] · [[AI Pitfalls - Stale APIs and Luau]] · [[What AI Models Get Wrong in Roblox]]

Also mentioned in (not linked): Lua Keyframe Player Internals · Melee Combat System End to End · Memory Budgets and Leaks · Moon Animator and Third-Party Tools · Prompting and Verifying AI Output · Publishing Animations · Replication and Ownership · Roblox Studio Assistant · Snippets - Building and Sampling Clips · Snippets - Enemy Client Animator · Snippets - Lua Keyframe Player Core · Studio Tooling Architecture · Testing Animations in Studio · Weapon Rig Player

<!-- atlas:generated -->
