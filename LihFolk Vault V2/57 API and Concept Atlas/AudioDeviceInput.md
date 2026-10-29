---
tags: [atlas, api, type/atlas, area/vfx, area/ai, api/AudioDeviceInput]
---
# AudioDeviceInput

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AudioDeviceInput` has an access list: set `AccessType` to `Allow` and call `SetUserIdAccessList` with the user ids allowed to...
> - `AudioAnalyzer` exposes levels on the client, never audio data to keep, and its spectrum is empty when any input is an...
> - `AudioDeviceInput` represents a player's microphone (`Player`, `Muted`, `Active`, `Volume`, access lists).
>
> Cost: TL;DR ~130 tok · whole note ~270 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AudioDeviceInput` has an access list: set `AccessType` to `Allow` and call `SetUserIdAccessList` with the user ids allowed to hear. (from [[Voice Chat and Safety Features]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `AudioAnalyzer` exposes levels on the client, never audio data to keep, and its spectrum is empty when any input is an `AudioDeviceInput` (Roblox docs). ([[Voice Chat and Safety Features]])
- `AudioDeviceInput` represents a player's microphone (`Player`, `Muted`, `Active`, `Volume`, access lists). ([[The Audio API - Players Emitters Wires and Effects]])

## Mentioned in

3 notes in 3 sections. The 3 most relevant are linked:

### 07 Lighting VFX and Audio
[[The Audio API - Players Emitters Wires and Effects]]

### 15 AI Tools
[[AI Audio - Voice Music and SFX]]

### 26 Community and Moderation
[[Voice Chat and Safety Features]]

<!-- atlas:generated -->
