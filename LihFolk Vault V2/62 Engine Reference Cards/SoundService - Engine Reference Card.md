---
tags: [reference, engine, soundservice, api/SoundService, type/reference, area/scripting, level/intermediate, api/Sound, api/AudioPlayer, area/audio, api/AudioEmitter]
---

# SoundService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: reading `Sound.TimeLength` right after setting `SoundId`.
> - Avoid: setting `MinDistance`, `MaxDistance` or `Pitch` in new code.
> - Avoid: `AudioPlayer.AssetId` in new code.
> - Global mood set once: `AmbientReverb`, `RolloffScale`, `RespectFilteringEnabled` left on.
> - UI clicks through `PlayLocalSound`; world sounds parented to parts or attachments.
> - Every `AudioPlayer` wired to an `AudioEmitter` or `AudioDeviceOutput`, and listeners placed deliberately.
>
> Cost: TL;DR ~160 tok · whole note ~1.5k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The service that sets global listener, reverb and replication rules for audio, plus the `Sound` object and the newer Audio API chain (`AudioPlayer` -> `Wire` -> `AudioEmitter` / `AudioListener`). Topic notes: [[Sound Fundamentals]], [[The Audio API - Players Emitters Wires and Effects]], [[Spatial Audio and Mixing]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| SoundService.RespectFilteringEnabled | prop | boolean | true per docs | When true, a `Sound:Play()` from a LocalScript stays on that client | no |
| SoundService.AmbientReverb | prop | `Enum.ReverbType` | `NoReverb` | Global preset applied to every `Sound` | no |
| SoundService.RolloffScale | prop | number | 1 | Higher = 3D sounds fade faster past their min distance | no |
| SoundService:PlayLocalSound | method | `(sound: Sound)` | - | Client; plays a local copy (keeps Volume, [[TimePosition]], PlaybackSpeed, SoundGroup effects) | no |
| SoundService:SetListener / GetListener | method | `(Enum.ListenerType, ...)` / `() -> Tuple` | `Camera` | Client; affects `Sound` only, not the Audio API | no |
| SoundService:GetMixerTime | method | `() -> number` | - | Clock for scheduled `AudioPlayer:Play(atTime)` | no |
| Sound.SoundId | prop | ContentId | "" | Asset to play; check `IsLoaded` before reading `TimeLength` | no |
| Sound.Volume | prop | number | 0.5 | Range 0-10 | no |
| Sound.PlaybackSpeed | prop | number | 1 | Replaces deprecated `Sound.Pitch` | no |
| Sound.RollOffMinDistance / RollOffMaxDistance | prop | number (studs) | 10 / 10000 | Only when parented to a BasePart or Attachment; replace `MinDistance`/`MaxDistance`/`EmitterSize` | no |
| Sound.RollOffMode | prop | `Enum.RollOffMode` | `Inverse` | Also `Linear`, `LinearSquare`, `InverseTapered` | no |
| Sound.Looped / Playing | prop | boolean | false / false | `Playing` always replicates | no |
| Sound:Play / Pause / Resume / Stop | method | `()` | - | Server call replicates to everyone | no |
| Sound.Ended / Loaded / DidLoop | event | `(soundId: string)` / ... `(soundId, numOfTimesLooped)` | - | `Ended` skips looped sounds and early stops (use `Stopped`) | - |
| AudioPlayer.Asset | prop | ContentId | "" | Replaces deprecated `AudioPlayer.AssetId` | no |
| AudioPlayer.Volume / PlaybackSpeed | prop | number | 1 / 1 | Ranges 0-10 and 0-20 | no |
| AudioPlayer:Play / Stop | method | `(atTime: number?) -> int64?` | - | Replicates server to client; `atTime` schedules against mixer time; `Cancel(id)` undoes | no |
| AudioPlayer.IsReady / IsPlaying | prop | boolean | false | Read-only for scripts; use `Play`/`Stop` | no |
| AudioPlayer:GetWaveformAsync | method | `(timeRange: NumberRange, samples: int) -> {number}` | - | Values -1 to 1 | yes |
| AudioEmitter.DistanceAttenuationBounds | prop | NumberRange (studs) | 4 to 10000 | Used by the preset `DistanceAttenuationMode` | no |
| [[AudioEmitter]] / AudioListener.AudioInteractionGroup | prop | string | "" | Only matching groups hear each other | no |
| Wire.SourceInstance / TargetInstance | prop | Instance | nil | Pins `SourceName` "Output", `TargetName` "Input"; `Connected` is read-only | no |

## Limits and defaults

- `Sound.Volume` 0.5 default, range 0-10; `AudioPlayer.Volume` 1 default, range 0-10; `AudioPlayer.PlaybackSpeed` range 0-20.
- `Sound.PlaybackLoudness` reports 0-1000; it is read-only and not replicated, so read it on the client.
- Legacy rolloff defaults: 10 studs min, 10000 studs max; `AudioEmitter.DistanceAttenuationBounds` 4-10000 studs.
- Audio uploads: under 20 MB and 7 minutes (see [[Engine Limits, Quotas and Defaults - Cheat Sheet]]).

## Replication and authority

- A server `Sound:Play()` is heard by every client; a LocalScript `Play()` stays local while `RespectFilteringEnabled` is true.
- `PlayLocalSound`, `SetListener` and `PlaybackLoudness` are client concerns.
- `AudioPlayer:Play()` and `Stop()` replicate from server to client.
- The Audio API ignores `SoundService:SetListener`; place an `AudioListener` (for example on the camera) instead.

## Common mistakes

- Avoid: reading `Sound.TimeLength` right after setting `SoundId`. Symptom: it reads 0; wait for `IsLoaded` or `Loaded` first.
- Avoid: setting `MinDistance`, `MaxDistance` or `Pitch` in new code. Symptom: deprecated names; use `RollOffMinDistance`, `RollOffMaxDistance` and `PlaybackSpeed`.
- Avoid: `AudioPlayer.AssetId` in new code. Symptom: deprecated property; assign `AudioPlayer.Asset`.
- Avoid: an `AudioPlayer` with no `Wire` to an output or emitter. Symptom: playback runs but nothing is heard.
- Avoid: parenting a 3D `Sound` to a Model or folder. Symptom: it plays at full volume everywhere; parent it to a BasePart or Attachment.

## Checklist

- Global mood set once: `AmbientReverb`, `RolloffScale`, `RespectFilteringEnabled` left on.
- UI clicks through `PlayLocalSound`; world sounds parented to parts or attachments.
- Every `AudioPlayer` wired to an `AudioEmitter` or `AudioDeviceOutput`, and listeners placed deliberately.

Source: https://create.roblox.com/docs/reference/engine/classes/SoundService, https://create.roblox.com/docs/reference/engine/classes/Sound, https://create.roblox.com/docs/reference/engine/classes/AudioPlayer, https://create.roblox.com/docs/reference/engine/classes/AudioEmitter, https://create.roblox.com/docs/reference/engine/classes/AudioListener and https://create.roblox.com/docs/reference/engine/classes/Wire - verified 2026-10-29

<!-- related:start -->
## Related
[[ParticleEmitter - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[BillboardGui - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[Players - Engine Reference Card]] · [[Instance - Engine Reference Card]]
<!-- related:end -->
