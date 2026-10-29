---
tags: [audio, audio-api, audioplayer, audioemitter, wire, effects, mixing, type/reference, area/vfx, level/intermediate, api/AudioPlayer, area/audio]
---
# The Audio API - Players Emitters Wires and Effects

<!-- tldr:start -->
> [!tldr] TL;DR
> - 3D sound silent: No listener (default location `None` or no voice), or listener not... -> Create and wire a listener.
> - Emitter silent for one listener only: Different `AudioInteractionGroup` -> Match groups.
> - Wire does nothing: Pin name wrong, missing instance or a cycle (`Connected` false) -> Check `Wire.Connected`.
> - Graph drawn before code: producers, buses, master chain, output.
> - Listener strategy chosen (default or custom per category).
> - Interaction groups consistent between emitters and listeners.
>
> Cost: TL;DR ~170 tok · whole note ~4.5k tok. Read more: ## 5. Effects reference · ## 6. Building real buses · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The modular audio API models audio like real equipment: a player makes a signal, wires carry it, effects shape it, an emitter is a speaker in the world, a listener is a microphone in the world, and a device output is the player's headphones. It is more verbose than a `Sound`, and in exchange it gives you explicit routing (real buses), effects you can share across many sources, sample-accurate scheduling, analysis, voice chat and speech in the same graph. As of October 2026 the docs recommend it over `Sound`/`SoundGroup`/`SoundEffect`.

Basics shared with classic sounds (assets, permissions, loudness measurement) are in [[Sound Fundamentals]]. Attenuation design and mix targets are in [[Spatial Audio and Mixing]].

Source labels: **Docs**, **API dump** (defaults), **Reference project**, **Rule of thumb**.

---

## 1. The four roles

| Role (Docs) | Classes |
|---|---|
| **Produce** a stream | `AudioPlayer` (asset files), `AudioDeviceInput` (a player's microphone), `AudioTextToSpeech` |
| **Consume** a stream | `AudioEmitter` (speaker in 3D), `AudioDeviceOutput` (real speakers or headphones), `AudioSpeechToText`, `AudioAnalyzer` (measures) |
| **Modify** a stream | `AudioFader`, `AudioEqualizer`, `AudioCompressor`, `AudioLimiter`, `AudioGate`, `AudioReverb`, `AudioEcho`, `AudioChorus`, `AudioFlanger`, `AudioDistortion`, `AudioPitchShifter`, `AudioTremolo`, `AudioFilter`, `AudioChannelSplitter`, `AudioChannelMixer` |
| **Carry** a stream | `Wire` |

`AudioListener` is the bridge from 3D back to a stream: it picks up emitters in the world and produces a stream you wire to an output.

### Pins and wires

Every audio object exposes named pins (`GetInputPins()`, `GetOutputPins()`). A `Wire` has `SourceInstance` + `SourceName` (default `"Output"`) and `TargetInstance` + `TargetName` (default `"Input"`). `AudioCompressor` has an extra `"Sidechain"` input pin (Docs). `Wire.Connected` is true only when both instances and pins exist and the connection does not create a cycle (Docs). Many wires can feed one input (they mix), and one output can feed many wires (it splits).

`WiringChanged(connected, pin, wire, instance)` fires on every audio object when its connections change.

---

## 2. Two canonical graphs

**2D (UI, music):**
```
AudioPlayer --Wire--> AudioDeviceOutput
```

**3D (world sounds):**
```
AudioPlayer --Wire--> AudioEmitter   (on a part/attachment in the world)
AudioListener (on camera or character) --Wire--> AudioDeviceOutput
```

### The default listener
`SoundService.DefaultListenerLocation` (`ListenerLocation` enum: `Default`, `None`, `Character`, `Camera`) decides whether the engine creates a listener for each player (Docs):
- `Default`: a listener on the camera **in experiences that enable voice chat**.
- `Character`: on the local character. `Camera`: on the current camera.
- `None`: no listener; create your own.

With `Character` or `Camera`, the engine also creates an `AudioDeviceOutput` under `SoundService` and wires the listener to it (Docs). If you want custom routing (buses per category, see section 6), choose `None` and build the graph yourself.

`AudioDeviceOutput.Player`: if set, only that player hears what is wired into it; if nil, everyone does (Docs). For per-client graphs built in LocalScripts this does not matter (local instances only exist on that client).

---

## 3. AudioPlayer

| Property | Default (API dump) | Notes (Docs) |
|---|---|---|
| `Asset` | empty | Asset to load. With `AutoLoad`, loading starts when assigned. Also `AudioContent`. |
| `AutoLoad` | true | False defers loading to the first play attempt. |
| `AutoPlay` | false | Starts when it enters the DataModel the first time; only for locally created or deserialised players, not ones arriving by replication. Mostly for Studio setups. |
| `IsReady` | false | Loaded and buffered. Can become false again under extreme memory pressure. |
| `IsPlaying` | false | Read-only; replicates. |
| `Looping` | false | |
| `PlaybackRegion` | 0 to 60000 | Start and stop within the file. |
| `LoopRegion` | 0 to 60000 | Loop section inside the playback region. |
| `PlaybackSpeed` | 1 | 0 to 20; changes pitch. |
| `Volume` | 1 | 0 to 10. Note the default differs from `Sound.Volume` (0.5). |
| `TimeLength`, `TimePosition` | | Seconds. |

Methods: `Play(atTime?)`, `Stop(atTime?)`, `Cancel(actionId)`, `GetWaveformAsync(range, samples)`, `GetPlaybackState()`. Events: `Ended` (not for looping players, and not when stopped early: watch `IsPlaying` for that), `Looped`.

### Sample-accurate scheduling
`Play` and `Stop` accept an optional `atTime` measured on `SoundService:GetMixerTime()`, a clock derived from samples mixed: "stable, sample-accurate, and monotonically increasing" (Docs). Scheduled calls return an action id that `Cancel` can revoke if it has not happened yet. This is what music stems, rhythm games and beat-locked stingers need; `task.delay` is frame-quantised and jittery by comparison.

```lua
--!strict
local SoundService = game:GetService("SoundService")

-- Start several stems on exactly the same sample, 0.1 s from now.
local function startTogether(players: { AudioPlayer }, lead: number?)
	local at = SoundService:GetMixerTime() + (lead or 0.1)
	for _, p in players do
		p:Play(at)
	end
end
```

### Replication
`Play` and `Stop` called on the server replicate to clients (Docs). As with `Sound`, prefer building feedback graphs on the client.

---

## 4. AudioEmitter and AudioListener

| Property | Default (API dump) | Notes (Docs) |
|---|---|---|
| `PositionType` | `Parent` | Position from the parent (part, attachment, model). `Instance` uses `PositionInstance`. With no valid position, nothing is heard. |
| `AudioInteractionGroup` | "" | An emitter is heard only by listeners in the same group. |
| `DistanceAttenuationMode` (emitter) | `Custom` | `Custom` uses the curve; presets `Inverse`, `InverseTapered`, `Linear`, `LinearSquared` use `DistanceAttenuationBounds`. |
| `DistanceAttenuationBounds` (emitter) | 4 to 10000 | Full volume inside min, silent beyond max (preset modes only). |
| `AcousticSimulationEnabled` | true | Occlusion, diffraction, reverberation; both emitter and listener must enable it, and `SoundService.AcousticSimulationEnabled` (default false in the API dump) gates it globally. |
| `OcclusionEnabled`, `DiffractionEnabled`, `ReverbEnabled` | `Default` | `SimulationMode`: `Default`, `Enabled`, `Disabled`. |

Curves: `SetDistanceAttenuation({[distance] = volume})` and `SetAngleAttenuation({[angle] = volume})` accept up to 400 points, linearly interpolated, angles 0 to 180 relative to the emitter's (or listener's) look vector, volumes 0 to 1 (Docs). Listeners have their own distance curve (a character with enhanced hearing) applied on top. `GetAudibilityFor(other)` returns 0 to 1 combining distance and angle on both ends, useful for gameplay ("can the monster hear you?").

```lua
--!strict
-- A 3D one-shot through the audio API. Client-side.
local function play3D(parent: Instance, assetId: string, volume: number, curve: { [number]: number }?)
	local player = Instance.new("AudioPlayer")
	player.Asset = assetId
	player.Volume = volume

	local emitter = Instance.new("AudioEmitter")
	if curve then
		emitter:SetDistanceAttenuation(curve) -- e.g. {[0] = 1, [40] = 0.5, [90] = 0}
	end

	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = emitter

	player.Parent = parent
	emitter.Parent = parent -- PositionType Parent: emits from this part/attachment
	wire.Parent = emitter

	player.Ended:Once(function()
		player:Destroy()
		emitter:Destroy() -- the wire goes with the emitter
	end)
	player:Play()
end
```

This assumes a listener exists (default listener or your own). For many one-shots per second, pool the player/emitter pairs instead of creating them.

---

## 5. Effects reference

Defaults from the API dump; ranges from the Docs where stated. All effects have `Bypass` (pass the signal through untouched).

| Effect | Key properties | Use |
|---|---|---|
| `AudioFader` | `Volume` 1 (0 to 10) | Bus volume, settings sliders, fades |
| `AudioEqualizer` | `LowGain`, `MidGain`, `HighGain` 0 dB (-80 to 10), `MidRange` 400 to 4000 Hz | Muffle underwater, thin a radio voice, carve space in a mix |
| `AudioFilter` | `FilterType` (Peak, LowShelf, HighShelf, Lowpass 6/12/24/48 dB, Highpass 12/24/48 dB, Bandpass, Notch), `Frequency` 2000, `Gain` 0, `Q` 0.707 | Precise filtering; muffled-through-walls by hand |
| `AudioCompressor` | `Threshold` -40 dB (-60 to 0), `Ratio` 40, `Attack` 0.1, `Release` 0.1, `MakeupGain` 0, `Sidechain` pin | Even out levels; ducking via sidechain |
| `AudioLimiter` | `MaxLevel` 0 dB (-12 to 0), `Release` 0.01 | Final safety on the master bus |
| `AudioGate` | `Threshold` -36 to -24 dB, `Attack` 0.01, `Release` 0.1 | Cut noise below a level (voice) |
| `AudioReverb` | `DecayTime` 1.5, `WetLevel` -6 dB (-80 to 20), `DryLevel` 0, `Density`, `Diffusion`, delays, filters | Rooms, caves, halls |
| `AudioEcho` | `DelayTime` 1, `Feedback` 0.5, `WetLevel` 0, `DryLevel` 0 | Canyons, stylised voices |
| `AudioChorus` | `Depth` 0.45, `Mix` 0.85, `Rate` 5 | Thickening, robotic voice |
| `AudioFlanger` | `Depth` 0.45, `Mix` 0.85, `Rate` 5 | Sweeping sci-fi colour |
| `AudioDistortion` | `Level` 0.5 | Grit, radios, overdrive |
| `AudioPitchShifter` | `Pitch` 1.25 (0.5 to 2), `WindowSize` | Pitch without changing speed |
| `AudioTremolo` | `Frequency` 5, `Depth` 1, `Duty`, `Shape`, `Skew`, `Square` | Pulsing, alarms, wobble |
| `AudioAnalyzer` | `PeakLevel`, `RmsLevel` (read-only), `SpectrumEnabled`, `WindowSize`, `GetSpectrum()` | Visualisers, music-reactive lights, loudness checks |
| `AudioChannelSplitter` / `AudioChannelMixer` | `Layout` (Mono to 7.1.4) | Per-channel processing |

Effect order matters: chorus then distortion sounds different from distortion then chorus (Docs). One effect can process many sources wired into it, so a single reverb per room serves every sound in that room.

`AudioAnalyzer` caveats (Docs): `PeakLevel` and `RmsLevel` are always 0 on the server; `GetSpectrum` returns an empty array on the server and when any input comes from an `AudioDeviceInput`; turning off `SpectrumEnabled` greatly reduces CPU if you only need levels. Its values change faster than the frame rate and do not fire `Changed`; poll them.

---

## 6. Building real buses

The classic `SoundGroup` tree maps onto faders. A complete client mix graph:

```
category players --> [Fader: SFX]   --\
                 --> [Fader: UI]    ---> [Fader: Master] -> [Compressor] -> [Limiter] -> AudioDeviceOutput
                 --> [Fader: Music] --/
                 --> [Fader: Ambience]/
```

For 3D sounds, the trick is **one listener per category**, separated by `AudioInteractionGroup`: emitters for SFX use group "SFX" and are heard only by the SFX listener, whose output wires into the SFX fader. Set `SoundService.DefaultListenerLocation = None` so the engine does not add an extra unrouted listener.

```lua
--!strict
-- AudioBus (client): faders per category -> master chain -> output, plus per-category 3D listeners.
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioBus = {}
local buses: { [string]: AudioFader } = {}

local function wire(source: Instance, target: Instance, targetPin: string?): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	if targetPin then
		w.TargetName = targetPin
	end
	w.Parent = target
	return w
end

local root = Instance.new("Folder")
root.Name = "AudioBus"
root.Parent = SoundService

local output = Instance.new("AudioDeviceOutput")
output.Parent = root

local limiter = Instance.new("AudioLimiter")
limiter.MaxLevel = -1
limiter.Parent = root
wire(limiter, output)

local compressor = Instance.new("AudioCompressor")
compressor.Threshold = -18
compressor.Ratio = 3
compressor.Attack = 0.01
compressor.Release = 0.15
compressor.Parent = root
wire(compressor, limiter)

local master = Instance.new("AudioFader")
master.Name = "Master"
master.Parent = root
wire(master, compressor)

for _, name in { "SFX", "UI", "Music", "Ambience" } do
	local f = Instance.new("AudioFader")
	f.Name = name
	f.Parent = root
	wire(f, master)
	buses[name] = f
end

-- 3D categories: a listener on the camera per interaction group.
local function addListener(group: string)
	local listener = Instance.new("AudioListener")
	listener.Name = group .. "Listener"
	listener.AudioInteractionGroup = group
	listener.Parent = Workspace.CurrentCamera
	wire(listener, buses[group])
end
addListener("SFX")
addListener("Ambience")

function AudioBus.bus(name: string): AudioFader
	return buses[name]
end

function AudioBus.setVolume(name: string, volume: number)
	buses[name].Volume = math.clamp(volume, 0, 10)
end

-- Duck music while a source plays: wire the source into the music compressor's sidechain.
function AudioBus.makeDucker(): AudioCompressor
	local duck = Instance.new("AudioCompressor")
	duck.Name = "MusicDuck"
	duck.Threshold = -30
	duck.Ratio = 6
	duck.Attack = 0.02
	duck.Release = 0.4
	duck.Parent = root
	-- Reroute: Music fader -> duck -> master
	for _, w in buses.Music:GetConnectedWires("Output") do
		w:Destroy()
	end
	wire(buses.Music, duck)
	wire(duck, master)
	return duck -- wire important sources to it with targetPin "Sidechain"
end

return AudioBus
```

Notes:
- The listener is parented to the current camera; if your game replaces `CurrentCamera`, re-parent listeners on `Workspace:GetPropertyChangedSignal("CurrentCamera")`.
- Emitters must set `AudioInteractionGroup = "SFX"` (or "Ambience") to be heard by those listeners. An emitter with an empty group is only heard by listeners with an empty group.
- Compressor and limiter values are starting points (rule of thumb), not a mastered chain.

---

## 7. Voice and speech

- `AudioDeviceInput` represents a player's microphone (`Player`, `Muted`, `Active`, `Volume`, access lists). With voice chat on the audio API (`VoiceChatService.UseAudioApi`), voices are just more streams: wire them through emitters on the character, add effects (radio EQ, cave reverb), or analyse them.
- `AudioTextToSpeech`: `Text` (Docs: up to 300 characters per request), `VoiceId`, `Pitch`, `Speed`, auto-localisation. Text must follow Community Standards. Reused lines can be baked to assets with `AssetService:CreateAssetAsync()` (Docs).
- `AudioSpeechToText`: wire a device input into it, set `Enabled`; it writes `Text`. Docs list 17 supported languages. Fuzzy-match recognised words against expected phrases.

Voice features have their own policy and age requirements; see [[Age Checks and Safety Features]] and [[Roblox Policies Ratings and Compliance]].

---

## 8. Migrating from Sound

| Classic | Audio API |
|---|---|
| `Sound` in SoundService (2D) | `AudioPlayer` wired to a fader to `AudioDeviceOutput` |
| `Sound` in a part (3D) | `AudioPlayer` wired to an `AudioEmitter` in the part; a listener wired to output |
| `SoundGroup` | `AudioFader` (plus effects) in the chain |
| `SoundEffect` children | Effect objects wired in series |
| `CompressorSoundEffect.SideChain` | `AudioCompressor` with a wire into its `Sidechain` pin |
| `RollOffMin/MaxDistance`, `RollOffMode` | `DistanceAttenuationMode` with bounds, or a custom curve |
| `Sound.PlaybackLoudness` | `AudioAnalyzer.RmsLevel`/`PeakLevel` |
| `Sound.Volume` default 0.5 | `AudioPlayer.Volume` default 1 |

Character sounds: `SoundService.CharacterSoundsUseNewApi` decides whether the default character sounds use the new instances (Docs). Migrate incrementally: new systems on the audio API, old `Sound` code until touched. Remember the volume default changed when porting tuned values.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| 3D sound silent | No listener (default location `None` or no voice), or listener not wired to output | Create and wire a listener. |
| Emitter silent for one listener only | Different `AudioInteractionGroup` | Match groups. |
| Wire does nothing | Pin name wrong, missing instance or a cycle (`Connected` false) | Check `Wire.Connected`. |
| Ported sound twice as loud | `AudioPlayer.Volume` default 1 vs `Sound` 0.5 | Re-level. |
| `Ended` never fires | Looping, or stopped early | Watch `IsPlaying`. |
| Analyzer reads 0 | Running on the server | Analyse on the client. |
| Stems drift | Started with `task.delay` | `Play(atTime)` on mixer time. |
| No occlusion | Global acoustic simulation off | Enable on SoundService, emitter and listener. |

## Checklist

- [ ] Graph drawn before code: producers, buses, master chain, output.
- [ ] Listener strategy chosen (default or custom per category).
- [ ] Interaction groups consistent between emitters and listeners.
- [ ] Settings sliders drive faders.
- [ ] Master compressor and limiter as safety.
- [ ] Scheduled starts for anything beat-locked.
- [ ] Old `Sound` volumes re-levelled when ported.

See also: [[Sound Fundamentals]], [[Spatial Audio and Mixing]], [[Music and Adaptive Audio]], [[Sound Design for Games]], [[Client-Server Model]], [[Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Voice Chat and Safety Features]] · Official Docs - Audio · AI Audio - Voice Music and SFX · Captions and Audio Accessibility · Audio Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[SoundService - Engine Reference Card]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[Audio Mixer Settings with SoundGroups]] · [[AI Audio - Voice Music and SFX]] · [[Engine and Tyre Audio Driven by RPM and Slip]]
<!-- related:end -->
