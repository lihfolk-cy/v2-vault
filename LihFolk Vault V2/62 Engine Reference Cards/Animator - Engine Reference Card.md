---
tags: [reference, engine, animator, api/Animator, type/reference, area/scripting, level/intermediate, api/AnimationTrack, area/animation, api/LoadAnimation]
---

# Animator - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: calling `LoadAnimation` every time an attack plays.
> - Avoid: loading before the rig is in Workspace.
> - Avoid: reading `Length` right after loading.
> - One Animator per rig, created on the server, under the Humanoid or AnimationController.
> - Tracks loaded once and reused; cleanup hooked to `Ended`.
> - Priorities set deliberately so attacks override locomotion.
>
> Cost: TL;DR ~130 tok · whole note ~1.4k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The object that loads, plays and replicates animations, plus the `AnimationTrack` it hands back; see [[Animator]], [[AnimationTrack]], [[Animator Deep Dive]], [[AnimationTrack Reference]] and [[Playback, Priorities and Blending]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Animator:LoadAnimation | method | `(animation: Animation) -> AnimationTrack` | - | Animator must be in Workspace; always creates a new track | no |
| Animator:GetTrackByAnimationId | method | `(animationId: ContentId) -> AnimationTrack?` | - | Finds an already loaded track; nil if none | no |
| Animator:GetPlayingAnimationTracks | method | `() -> {AnimationTrack}` | - | Both | no |
| Animator.AnimationPlayed | event | `(animationTrack: AnimationTrack)` | - | Fires when any track starts | - |
| Animator.PreferLodEnabled | prop | boolean | true | false keeps an important NPC at full fidelity | no |
| Animator.EvaluationThrottled | prop | boolean | - | Read-only; true when this frame reused the last pose | no |
| Animator:StepAnimations | method | `(deltaTime: float) -> ()` | - | Plugin or command bar only | no |
| AnimationTrack:Play | method | `(fadeTime: float?, weight: float?, speed: float?) -> ()` | 0.1, 1, 1 | Both | no |
| AnimationTrack:Stop | method | `(fadeTime: float?) -> ()` | 0.1 | Fades weight to 0 over fadeTime | no |
| AnimationTrack:AdjustSpeed | method | `(speed: float?) -> ()` | 1 | Negative plays in reverse | no |
| AnimationTrack:AdjustWeight | method | `(weight: float?, fadeTime: float?) -> ()` | 1, 0.1 | Blends tracks of equal priority | no |
| AnimationTrack:GetMarkerReachedSignal | method | `(name: string) -> RBXScriptSignal` | - | Fires on named animation events | no |
| AnimationTrack.Priority | prop | `Enum.AnimationPriority` | from the asset | Core < Idle < Movement < Action < Action2 < Action3 < Action4 | no |
| AnimationTrack.Looped | prop | boolean | from the asset | Change applies after the current loop | no |
| AnimationTrack.Length | prop | float (s) | 0 until loaded | Read-only | no |
| AnimationTrack.Speed | prop | float | 1 | Read-only; set through AdjustSpeed | no |
| AnimationTrack.TimePosition | prop | float (s) | - | Seek within the clip | no |
| AnimationTrack.IsPlaying | prop | boolean | - | Read-only | no |
| AnimationTrack.WeightTarget / [[WeightCurrent]] | prop | float | - | Read-only blend state | no |
| AnimationTrack.Stopped | event | `()` | - | Playback finished; may still be fading out | - |
| AnimationTrack.Ended | event | `()` | - | Fully done and back to neutral; safe cleanup point | - |
| AnimationTrack.DidLoop | event | `()` | - | Each completed loop of a looped track | - |

Retired names and their replacements:
- `Humanoid:LoadAnimation` and `AnimationController:LoadAnimation` -> `Animator:LoadAnimation`.
- `AnimationTrack.KeyframeReached` -> `AnimationTrack:GetMarkerReachedSignal(name)`.

## Limits and defaults

- Default fade time for `Play`, `Stop` and `AdjustWeight` is 0.1 s; default weight and speed are 1.
- A track takes `Length / Speed` seconds; `Length` reads 0 until the asset finishes loading.
- `Enum.AnimationPriority` has 7 levels; the higher priority wins on a shared joint, and equal priorities blend by weight.
- After `Stop`, call `Play` again before adjusting weight; a fading track ignores further `Stop` and `AdjustWeight` calls.
- `PreferLodEnabled` defaults to true, letting the engine evaluate distant remote characters less often.

## Replication and authority

- Create the Animator on the server; tracks loaded on a locally created Animator never replicate.
- For a player's own character, play animations on that client and they replicate to the server and others.
- For NPCs and other non-character rigs, load and play on the server.
- Calling `LoadAnimation` on a client-owned model also loads the animation on the server.

## Common mistakes

- Avoid: calling `LoadAnimation` every time an attack plays. Symptom: track count and memory climb; load once and cache, or use `GetTrackByAnimationId`.
- Avoid: loading before the rig is in Workspace. Symptom: an error because the Animator cannot reach [[AnimationClipProvider]].
- Avoid: reading `Length` right after loading. Symptom: 0 breaks timing math; wait until it is above 0.
- Avoid: `Stop(0)` on rigs whose Motor6D `MaxVelocity` is 0. Symptom: joints freeze in place instead of snapping back.
- Avoid: building new timing on `KeyframeReached`. Symptom: superseded event; animation markers with `GetMarkerReachedSignal` are the supported path.

## Checklist

- One Animator per rig, created on the server, under the Humanoid or AnimationController.
- Tracks loaded once and reused; cleanup hooked to `Ended`.
- Priorities set deliberately so attacks override locomotion.
- Gameplay hits timed by markers, with damage decided on the server.

Source: https://create.roblox.com/docs/reference/engine/classes/Animator and https://create.roblox.com/docs/reference/engine/classes/AnimationTrack - verified 2026-10-29

<!-- related:start -->
## Related
[[Engine Gotchas]] · [[Snippets - Playing Animations]] · [[Humanoid - Engine Reference Card]] · [[RunService - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[CollectionService - Engine Reference Card]] · [[SoundService - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Player - Engine Reference Card]]
<!-- related:end -->
