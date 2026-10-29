---
tags: [audio, sound, soundgroup, assets, loudness, type/guide, area/vfx, level/beginner, api/AudioPlayer, area/audio, api/Sound, api/SoundGroup]
---
# Sound Fundamentals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Sound silent in the live game only: Experience lacks permission to the asset -> Upload under the experience owner; test live.
> - First impact sound late: Not preloaded -> Preload with the owner.
> - Mix wildly uneven: Volumes set by ear per file -> Measure and level.
> - Assets uploaded under the experience owner and verified in a live server.
> - Forbidden or removed ids listed.
> - Bus tree with settings sliders wired to buses.
>
> Cost: TL;DR ~150 tok · whole note ~3.7k tok. Read more: ## 2. The `Sound` object · ## 6. Measuring loudness · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has two audio systems side by side. The classic one is the `Sound` object (with `SoundGroup` mixers and `SoundEffect` children), which every tutorial and most existing games use. The newer one is the modular audio API (`AudioPlayer`, `AudioEmitter`, `AudioListener`, `AudioDeviceOutput`, `Wire` and effect objects), which the docs now recommend: "`Sound`, `SoundGroup`, and `SoundEffect` objects are now discouraged in favor of the more robust functionality of audio objects" (Docs, October 2026). Both work today, and you will meet both.

This note covers what is common to both: audio assets (formats, limits, permissions, moderation), the classic `Sound` object in depth, `SoundGroup` mixing, replication, preloading and first-play delay, and measuring loudness so sounds can be levelled. The new API is in [[The Audio API - Players Emitters Wires and Effects]]; 3D behaviour and mixing in [[Spatial Audio and Mixing]].

Source labels: **Docs**, **API dump**, **Reference project** (one production game that levelled about 1,200 sound ids), **Rule of thumb**.

---

## 1. Audio assets

### Import requirements (Docs, as of October 2026)
- You have the legal rights to the audio; it follows Community Rules and Terms of Use.
- A single track in `.mp3`, `.ogg`, `.wav` or `.flac`.
- Under 20 MB and under 7 minutes.
- Sample rate at most 48 kHz.
- Channels: mono, stereo 2.0, 3.0 or 5.1 surround.
- Import quota: 2,000 free audio assets per 30 days if ID-verified, 100 per 30 days if not.
- Studio transcodes imports; old tools that write invalid headers can cause rejections.

Uploads enter **moderation** and are private to you until they pass. The **asset privacy** system means an experience can only play audio its owner may use: your own uploads, assets shared with the experience, or public library audio (Docs). The Creator Store has a large licensed library (Docs: more than 100,000 professionally produced sound effects and music tracks from audio partners).

### "Not approved for the requester"
When an experience lacks permission for an audio asset, it simply does not play in that experience and Studio's output logs a failed load. In the reference project, a measurement pass over all sound ids found 55 that would not load for exactly this reason, including a looping hum that left a family of weapons silent until it was replaced. Lessons:
- **Upload under the experience owner** (the group, if the game is a group game).
- **Check every id loads in the real experience** (not only in your personal test place).
- Keep a list of removed and forbidden ids so nobody reintroduces them; the reference project kept such ids as inert rows in its loudness table so tools still recognised them.

### Songs vs sound effects
Uploads are auto-classified as sound effect or song. Songs can show on the game's details page if they pass moderation and copyright checks, meet duration and play-count requirements, have a meaningful title, and the uploader is ID-verified and has accepted the audio terms (Docs). Visibility can be toggled on the asset's Configure page.

---

## 2. The `Sound` object

### Where it plays from (Docs)
- **Parented to a `BasePart` or `Attachment`:** positional. Emits from the part's position or the attachment's world position, attenuates with distance from the listener (the camera by default), and exhibits the Doppler effect.
- **Anywhere else** (SoundService, Workspace, a GUI): "global", same volume everywhere.
- **Volumetric**: with `SoundService.VolumetricAudio` enabled, a sound on a large part plays around the listener when inside the part and fades directionally outside. Good for rain zones and concert stages.

### Properties

| Property | Default (API dump) | Notes |
|---|---|---|
| `SoundId` | empty | `rbxassetid://...`. Also `AudioContent` (Content type). |
| `Volume` | 0.5 | 0 to 10, multiplicative; 4 is four times as loud as 1. Docs: if the source is already loud you rarely need more than 2. |
| `PlaybackSpeed` | 1 | Speed and pitch together: 2 = twice as fast and an octave up. Not replicated as a property. |
| `Looped` | false | |
| `TimePosition` | 0 | Seconds; jump around a track. |
| `PlaybackRegionsEnabled`, `PlaybackRegion`, `LoopRegion` | false, 0 to 60000 | Play or loop a slice of a file. |
| `RollOffMode` | `Inverse` | `Inverse`, `Linear`, `LinearSquare`, `InverseTapered`. |
| `RollOffMinDistance`, `RollOffMaxDistance` | 10, 10000 | Studs. See [[Spatial Audio and Mixing]]. |
| `SoundGroup` | nil | Assign (not parent) to a group. |
| `PlayOnRemove` | false | Plays when the sound or an ancestor is removed (`Destroy`, `Parent = nil`). |
| `IsLoaded` / `Loaded` | | Ready to play. |
| `IsPlaying` | | |
| `TimeLength` | | 0 until loaded. |
| `PlaybackLoudness` | | 0 to 1000, current amplitude (client). |

Methods: `Play()` (restarts from `TimePosition`), `Stop()` (resets position), `Pause()`, `Resume()`. Events: `Played`, `Ended`, `Stopped`, `Paused`, `Resumed`, `DidLoop`, `Loaded`. The API dump also lists `Sound:GetUnderlyingAudioPlayer()`, which bridges a `Sound` to the new API (check its reference page before relying on it).

### Pitch and speed are coupled
`PlaybackSpeed` changes both. That is useful (a smaller creature squeaks higher and faster) and limiting (you cannot make a long roar lower without making it longer). For pitch without time change, use a pitch-shift effect (`PitchShiftSoundEffect`, or `AudioPitchShifter` with range 0.5 to 2 in the new API).

---

## 3. SoundGroups

A `SoundGroup` is a mixer bus (Docs):
- Sounds are **assigned** with `Sound.SoundGroup`, not parented. Where the sound lives decides where it plays from; the group decides how loud and how processed.
- `SoundGroup.Volume` (default 0.5, range 0 to 10) multiplies its members' volume: a 0.5 sound in a 0.5 group plays at 0.25.
- Groups nest: put groups inside groups to build a mix tree (Master > SFX > Weapons).
- `SoundEffect` children on a group (reverb, EQ, compressor) process every member.
- **Ducking:** a `CompressorSoundEffect` on a low-priority group with its `SideChain` pointed at a high-priority sound or group lowers the low group whenever the high one plays (Docs).

### A practical bus layout

| Bus | Contents | Settings slider |
|---|---|---|
| Music | Background tracks, shop music | Music |
| Ambience | Zone beds, spot sounds | Music or Ambience |
| SFX | Combat, abilities, enemies, pickups | Effects |
| UI | Clicks, opens, rewards | UI |
| Voice | Dialogue, announcer | Effects or Voice |

The reference project wired its player settings directly to group volumes (separate groups for settings-controlled SFX, music and UI), with additional processing buses for weapon sounds (EQ, compressor and a short reverb) and enemy sounds. The settings menu then needs no knowledge of individual sounds.

---

## 4. Replication and who plays what

- A `Sound` played by a server script replicates to all clients. Use that for a few world events (a bell everyone hears).
- **Feedback sounds should play on the client** that needs them: UI clicks, your own swing, your own hits. Playing them on the server adds latency and sends them to everyone.
- Sounds for other players' actions: play locally on each client from the same event that drives their VFX, at reduced volume for onlookers (the reference project played other players' ability sounds at about 0.7x).
- `SoundService:PlayLocalSound(sound)` plays a local copy of a sound regardless of parent, carrying its volume, speed, position and group effects (Docs).

---

## 5. Loading and first-play delay

The first time an audio asset is used, it has to be fetched. A sound triggered at the moment of impact that is not loaded plays late or not at all.

- `ContentProvider:PreloadAsync({sound1, sound2})` yields until the content is fetched (Docs); failures are logged but do not error.
- Preload sounds **when their owner loads** (weapon equipped, zone entered, menu built), not when first needed.
- Check `IsLoaded` before timing-critical playback; if not loaded, either skip (better a missing whoosh than one 0.4 s late) or play anyway for non-timed sounds.
- Reuse `Sound` instances for repeated one-shots (a pool per id) rather than creating one per hit; creation churns instances and each new one may wait on loading state.

```lua
--!strict
-- OneShotPool: reuse Sound instances per id; preload once.
local ContentProvider = game:GetService("ContentProvider")

local OneShotPool = {}
local pools: { [string]: { Sound } } = {}

local function make(id: string, group: SoundGroup?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.SoundGroup = group
	return s
end

function OneShotPool.preload(ids: { string }, group: SoundGroup?)
	local list = {}
	for _, id in ids do
		local s = make(id, group)
		pools[id] = pools[id] or {}
		table.insert(pools[id], s)
		table.insert(list, s)
	end
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, list)
end

-- Play at a parent (part/attachment for 3D, or SoundService for 2D).
function OneShotPool.play(id: string, parent: Instance, volume: number, speed: number, group: SoundGroup?)
	local pool = pools[id]
	if not pool then
		pool = {}
		pools[id] = pool
	end
	local s = table.remove(pool) or make(id, group)
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.Parent = parent
	s.TimePosition = 0
	s:Play()
	s.Ended:Once(function()
		s.Parent = nil
		table.insert(pool, s)
	end)
end

return OneShotPool
```

If the parent part is destroyed while the sound plays, the sound is destroyed with it and never returns to the pool; that is fine, the pool refills on demand.

---

## 6. Measuring loudness

Two files with `Volume = 1` can differ in perceived loudness by 10x. Setting volumes by ear, one sound at a time, produces a mix where some swings are deafening and some hits inaudible. The reference project levelled every sound by measurement.

### The tool
`AudioPlayer:GetWaveformAsync(timeRange, samples)` returns `samples` numbers between -1 and 1 sampling the asset's waveform, without playing it (Docs). From that you can estimate:
- **Peak**: largest absolute sample.
- **RMS**: root mean square, a better proxy for perceived loudness.
- **Onset**: the time of the first sample above a fraction of peak (most files start with silence).

### The trap: aliasing
These are point samples. A request for 60 samples across a 2-second file reads 60 instantaneous values from a signal that oscillates hundreds of times per second. The reference project found 60-sample reads off by up to ±48%. Its robust method used many more samples (reading in windows) and calibrated: the loudness used for levelling was a fixed multiple of the robust RMS (one table used 1.39 x RMS, another 0.825 x RMS, each consistent within its own system).

```lua
--!strict
-- Measure an audio asset: peak, rms, onset (seconds). Run in Studio (command bar or plugin).
local SoundService = game:GetService("SoundService")

export type Measure = { peak: number, rms: number, onset: number, length: number }

local function measure(assetId: string, samplesPerSecond: number?): Measure?
	local player = Instance.new("AudioPlayer")
	player.Asset = assetId
	player.Parent = SoundService
	local deadline = os.clock() + 10
	while not player.IsReady and os.clock() < deadline do
		task.wait(0.1)
	end
	if not player.IsReady then
		player:Destroy()
		return nil -- not loadable here: check permissions
	end
	local length = player.TimeLength
	local sps = samplesPerSecond or 2000
	local n = math.clamp(math.floor(length * sps), 64, 200000)
	local wave = player:GetWaveformAsync(NumberRange.new(0, length), n)
	player:Destroy()
	if #wave == 0 then
		return nil
	end
	local peak, sumSq = 0, 0
	for _, v in wave do
		local a = math.abs(v)
		if a > peak then
			peak = a
		end
		sumSq += v * v
	end
	local onset = 0
	for i, v in wave do
		if math.abs(v) >= peak * 0.1 then
			onset = (i - 1) / #wave * length
			break
		end
	end
	return { peak = peak, rms = math.sqrt(sumSq / #wave), onset = onset, length = length }
end

return measure
```

With measurements stored in a table (id to rms, onset, length), playback sets `Volume = target / measured`, and starts each sound shortly before its onset (the reference project started 15 ms before the measured onset) so the audible start lands on the beat. Targets and buses are in [[Spatial Audio and Mixing]].

Rule enforced in the reference project: **any new sound id goes into the measured table, or it plays unlevelled.** Make your sound player warn when it meets an unmeasured id.

### Duplicates
The same project detected duplicate uploads by correlating waveforms of candidate pairs in Edit. Cheap to run, and it stops two "different" sounds that are the same take from being used as variations.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Sound silent in the live game only | Experience lacks permission to the asset | Upload under the experience owner; test live. |
| First impact sound late | Not preloaded | Preload with the owner. |
| Mix wildly uneven | Volumes set by ear per file | Measure and level. |
| Measured loudness inconsistent | Too few waveform samples (aliasing) | Many samples, windowed RMS. |
| Sounds heard by everyone | Played from the server | Play feedback on clients. |
| Pitching a sound makes it long | `PlaybackSpeed` couples speed and pitch | Use a pitch shifter. |
| SoundGroup has no effect | Sound parented under the group but not assigned | Set `Sound.SoundGroup`. |

## Checklist

- [ ] Assets uploaded under the experience owner and verified in a live server.
- [ ] Forbidden or removed ids listed.
- [ ] Bus tree with settings sliders wired to buses.
- [ ] Feedback sounds client-side; world events sparse on the server.
- [ ] Preload per owner; pooled one-shots.
- [ ] Every id measured (rms, onset); unmeasured ids flagged.
- [ ] New work considers the audio API (see the next note).

See also: [[The Audio API - Players Emitters Wires and Effects]], [[Spatial Audio and Mixing]], [[Sound Design for Games]], [[Music and Adaptive Audio]], [[Asset Pipelines]], [[Creator Store and Toolbox Safety]].

## Connected notes
<!-- auto-links:start -->
[[Audio Pipeline]] · [[Combat Sound Design and Feedback]] · AI Audio - Voice Music and SFX · Links - Sounds and the Audio API · Resource Library - Audio · Feedback Timing - Sound Visual and Haptic Sync
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Audio Mixer Settings with SoundGroups]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[AI Audio - Voice Music and SFX]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Music Licensing and Audio Upload Rules for 2026]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]]
<!-- related:end -->
