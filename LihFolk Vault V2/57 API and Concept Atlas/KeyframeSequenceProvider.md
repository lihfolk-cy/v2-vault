---
tags: [atlas, api, type/atlas, area/animation, area/ai, api/KeyframeSequenceProvider]
---
# KeyframeSequenceProvider

<!-- tldr:start -->
> [!tldr] TL;DR
> - AnimationClipProvider: The documented replacement for KeyframeSequenceProvider.
> - Roblox docs (`KeyframeSequenceProvider:RegisterActiveKeyframeSequence`, same for `RegisterKeyframeSequence`): the generated id...
> - Code can register it with `KeyframeSequenceProvider` or `AnimationClipProvider` to get a temporary id.
> - A Studio-only token scheme (`ksp://<n>`) so code written for `KeyframeSequenceProvider` ids keeps working.
>
> Cost: TL;DR ~150 tok · whole note ~620 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

AnimationClipProvider: The documented replacement for KeyframeSequenceProvider. (from [[Animation Glossary]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Roblox docs (`KeyframeSequenceProvider:RegisterActiveKeyframeSequence`, same for `RegisterKeyframeSequence`): the generated id "is temporary and cannot be used outside of Studio. ([[Publishing Animations]])
- Code can register it with `KeyframeSequenceProvider` or `AnimationClipProvider` to get a temporary id. ([[Animation Objects]])
- A Studio-only token scheme (`ksp://<n>`) so code written for `KeyframeSequenceProvider` ids keeps working. ([[Snippets - Lua Keyframe Player Core]])
- Measured: `KeyframeSequenceProvider:RegisterKeyframeSequence` ids and EditableMesh or EditableImage effects worked in Studio and failed in the published game. ([[AI Pitfalls - Assets and Import]])

## Mentioned in

35 notes in 5 sections. The 25 most relevant are linked:

### 08 Animation
[[Ability Kits Architecture]] · [[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Animation Glossary]] · [[Animation Objects]] · [[Animator Deep Dive]] · [[Authoring Clips in Code]] · [[Case Study - Abilities That Only Worked in Studio]] · [[Custom Rigs - Weapons and Props]] · [[Enemy Animation State Protocol]] · [[Engine Gotchas]] · [[How the Animator Really Behaves]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Lua Keyframe Player]] · [[Moon Animator and Third-Party Tools]] · [[Pipeline - Importing Animated Enemies]] · [[Pipeline - New Animated Weapon]] · [[Publishing Animations]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Playing Animations]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Assets and Import]] · [[AI Pitfalls - Physics and Animation]] · [[Prompting and Verifying AI Output]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]]

Also mentioned in (not linked): Open Questions - Whole Vault · Replication and Ownership · Snippets - Building and Sampling Clips · Studio Tooling Architecture · Testing Animations in Studio · Testing Modes - Play Run and Multi-Client · Troubleshooting Table · Weapon Rig Player · Weapon and Combat Animation · What AI Models Get Wrong in Roblox

<!-- atlas:generated -->
