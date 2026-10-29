---
tags: [atlas, api, type/atlas, area/animation, area/platform, api/AnimationClipProvider]
---
# AnimationClipProvider

<!-- tldr:start -->
> [!tldr] TL;DR
> - AnimationClipProvider: The documented replacement for KeyframeSequenceProvider.
> - Code can register it with `KeyframeSequenceProvider` or `AnimationClipProvider` to get a temporary id.
> - Symptom: an error because the Animator cannot reach AnimationClipProvider.
>
> Cost: TL;DR ~110 tok · whole note ~280 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

AnimationClipProvider: The documented replacement for KeyframeSequenceProvider. (from [[Animation Glossary]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Code can register it with `KeyframeSequenceProvider` or `AnimationClipProvider` to get a temporary id. ([[Animation Objects]])
- Symptom: an error because the Animator cannot reach AnimationClipProvider. ([[Animator - Engine Reference Card]])

## Mentioned in

9 notes in 4 sections. The 9 most relevant are linked:

### 08 Animation
[[Animation Glossary]] · [[Animation Objects]] · [[CurveAnimation and Curve Channels]] · [[Engine Gotchas]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Replication and Ownership]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]]

### 62 Engine Reference Cards
[[Animator - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
