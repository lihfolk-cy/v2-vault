---
tags: [audio, music, adaptive-audio, ambience, crossfade, licensing, type/guide, area/vfx, level/intermediate, api/AudioPlayer, area/audio, api/TweenService]
---
# Music and Adaptive Audio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Hard cut between tracks: One player, swap asset -> Two decks, crossfade before the end.
> - Background restarts after every shop visit: Stop resets / new track each time -> Pause at silence and resume.
> - Stems drift out of sync: Started one by one -> `Play(atTime)` on mixer time.
> - Every track licensed or owned; uploads within limits.
> - Two-deck crossfades; fade-in on join; silences between tracks.
> - Context switches with priorities; pause and resume where sensible.
>
> Cost: TL;DR ~160 tok · whole note ~4.5k tok. Read more: ## 2. Playlists and crossfades · ## 5. Ambience · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Music tells players how to feel; ambience tells them where they are. Both run for the whole session, so mistakes in them are heard for an hour: a track that loops with a click every 90 seconds, shop music that cuts in at full volume, a zone bed that masks the cue you need to hear. Adaptive audio means the soundtrack responds to the game: context switches (shop, combat, boss), intensity layers, stingers on events, and ambience that follows the player through zones.

This note covers playlists and crossfades, context switching, layered and resequenced music, stingers, ambience beds and spot sounds, levels, licensing, and settings. Mechanics of the two audio systems are in [[Sound Fundamentals]] and [[The Audio API - Players Emitters Wires and Effects]].

Source labels: **Docs**, **Reference project** (one production game's music and ambience passes), **Rule of thumb**.

---

## 1. Where music comes from

- **Licensed library.** The Creator Store has a large library of professionally produced music and effects free to use in Roblox experiences (Docs). The reference project used licensed library tracks for background and shop music.
- **Your own or commissioned music.** You must hold the rights. Uploads go through moderation and copyright checks; songs can appear on the game details page if they meet the visibility requirements (Docs; see [[Sound Fundamentals]]).
- **Never upload commercial music you do not own.** It will be moderated, and it risks your account.
- Limits per upload: 7 minutes and 20 MB (Docs). Long ambient pieces need to loop well or be split.

---

## 2. Playlists and crossfades

### The two-deck pattern
A DJ uses two decks so one track can fade into the next. The reference project's background music:
- A playlist on **two decks**, cross-fading **4 s** before the current track ends.
- A **2.5 s fade-in** on join, so the first sound of the game is not a full-volume downbeat.
- All music through one settings-controlled music bus.

```lua
--!strict
-- MusicDecks (client): two AudioPlayers through two faders into a music bus, crossfading.
local TweenService = game:GetService("TweenService")

export type Deck = { player: AudioPlayer, fader: AudioFader }

local MusicDecks = {}
MusicDecks.__index = MusicDecks

local function makeDeck(parent: Instance, bus: Instance): Deck
	local player = Instance.new("AudioPlayer")
	player.Parent = parent
	local fader = Instance.new("AudioFader")
	fader.Volume = 0
	fader.Parent = parent
	local w1 = Instance.new("Wire")
	w1.SourceInstance = player
	w1.TargetInstance = fader
	w1.Parent = fader
	local w2 = Instance.new("Wire")
	w2.SourceInstance = fader
	w2.TargetInstance = bus
	w2.Parent = fader
	return { player = player, fader = fader }
end

function MusicDecks.new(parent: Instance, bus: Instance)
	local self = setmetatable({}, MusicDecks)
	self.decks = { makeDeck(parent, bus), makeDeck(parent, bus) }
	self.active = 1
	return self
end

-- Crossfade to a new asset. `level` is the levelled volume for this track (from measurements).
function MusicDecks:play(assetId: string, level: number, fade: number)
	local nextIndex = 3 - self.active
	local incoming: Deck = self.decks[nextIndex]
	local outgoing: Deck = self.decks[self.active]

	incoming.player:Stop()
	incoming.player.Asset = assetId
	incoming.player.Volume = level
	incoming.player.TimePosition = 0
	incoming.fader.Volume = 0
	incoming.player:Play()

	local info = TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(incoming.fader, info, { Volume = 1 }):Play()
	local out = TweenService:Create(outgoing.fader, info, { Volume = 0 })
	out.Completed:Once(function()
		if self.active == nextIndex then
			outgoing.player:Stop()
		end
	end)
	out:Play()
	self.active = nextIndex
end

return MusicDecks
```

Equal-power curves (Sine InOut) keep the perceived loudness steadier through a crossfade than linear ones. Watch for the end of the track yourself (`TimeLength - TimePosition <= fadeTime`) to start the next one early; `Ended` fires too late for a crossfade.

### Loops
- A looping track must be edited to loop seamlessly (cut on a bar line, matched tails). If it clicks, it is the file, not Roblox.
- `LoopRegion` (audio API) or `LoopRegion` with `PlaybackRegionsEnabled` (classic) lets you loop a section after an intro.

### Fatigue
Rule of thumb: background music that repeats every 2 minutes for a 30-minute session is a frequent player complaint about game audio. Use a playlist of several tracks, insert silences of 30 to 90 seconds between them, and keep the mix low (the reference project's background music sat only a little above the zone ambience).

---

## 3. Context switching

The reference project switched to an upbeat shop track whenever the shop interface was open:
- On open: background fades out in **1 s**, shop music fades in in **1 s**.
- On close: shop music fades out and background returns in **1.4 s**.
- Both tracks **pause at silence and resume where they were**, so the background does not restart from the top every time someone checks the shop.
- Music goes quiet during cutscenes and when the player turns music off in settings.

```lua
--!strict
-- Pause a deck at silence and resume it later from the same point.
local TweenService = game:GetService("TweenService")

local function fadeAndPause(player: AudioPlayer, fader: AudioFader, fade: number)
	local t = TweenService:Create(fader, TweenInfo.new(fade), { Volume = 0 })
	t.Completed:Once(function()
		if fader.Volume <= 0.001 then
			player:Stop() -- AudioPlayer:Stop keeps TimePosition where it stopped
		end
	end)
	t:Play()
end

local function resumeAndFade(player: AudioPlayer, fader: AudioFader, fade: number)
	player:Play() -- resumes from TimePosition
	TweenService:Create(fader, TweenInfo.new(fade), { Volume = 1 }):Play()
end
```

Docs: `AudioPlayer:Stop()` stops "wherever its [[TimePosition]] is" and `Play()` plays from wherever `TimePosition` is, so stop-and-play acts as pause-and-resume.

### Context priority
When several contexts can claim the music (shop, boss, cutscene, victory), resolve them with a priority stack exactly like the grade stack in [[Atmosphere Sky Clouds and Post-Processing]]: cutscene above boss above shop above zone above default.

---

## 4. Adaptive structures

### Vertical layering (stems)
One piece split into synchronised stems (pads, percussion, melody, brass). All play from the same sample; intensity fades stems in and out.
- Start all stems together with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`, so they are sample-aligned (Docs). Starting with `task.delay` or sequential `Play()` calls can drift by frames.
- Intensity from game state: number of enemies aggroed, boss phase, health. Smooth the intensity value (a few seconds) so music does not flicker with every hit.

### Horizontal resequencing
Segments chosen at musical boundaries (bar or phrase). Calculate the next boundary from the track's tempo and the mixer time, and schedule the next segment's `Play(atTime)` and the current one's `Stop(atTime)` at that boundary. `Cancel(actionId)` revokes a scheduled change if the game state flips back before it happens.

```lua
--!strict
local SoundService = game:GetService("SoundService")

-- Next bar boundary after `startedAt` (mixer time when the segment began), for a given tempo and meter.
local function nextBar(startedAt: number, bpm: number, beatsPerBar: number): number
	local barLen = 60 / bpm * beatsPerBar
	local now = SoundService:GetMixerTime()
	local barsElapsed = math.floor((now - startedAt) / barLen) + 1
	return startedAt + barsElapsed * barLen
end
```

### Stingers
Short musical hits on events: level up, rare drop, boss appear, victory. Levelled louder than background music (the reference project's stingers and ultimate sounds sat at the top of the loudness targets) and usually duck the music for their duration. Quantise to the next beat if the music has a strong pulse; otherwise play immediately (a late stinger is worse than an off-beat one).

Rule of thumb: adaptive music is expensive to compose. A small game gets most of the value from context switching plus stingers.

---

## 5. Ambience

### Zone beds
The reference project's ambience pass gave each zone a looped bed chosen to match it (birds for a meadow, jungle birds for a grove, crickets and cicadas for a thorn wood, cave drips plus a ringing tone for a crystal cave, lava rumbles for furnace zones, winter air for a frost zone, city ambience plus electrical buzz for a neon district). Rules it followed:
- **Same zone lookup as the weather and lighting**, so sound and sky change at the same border.
- **2.5 s crossfade** between beds.
- **Muted during cutscenes.**
- **Levelled by RMS** so beds sit under everything (effective loudness around 0.004 to 0.018, under the wind).
- **No bed where one would mask something important.** The hub's bed was removed the same day it was added because it masked the hub's strong wind, which was then restored at a lower level.
- Some zones deliberately had no bed (one zone's weather loop was already its bed; an arena had no crowd because it was an empty ruin).
- Where no fitting licensed sound existed (ice creaks), the gap was noted rather than filled with something wrong.

### Spot sounds
Point sources that make a place feel alive: waterfalls (3D, max 90 studs), glass tinkles in a crystal cave every 4 to 9 s at random positions, flame licks near furnaces, a chime on a special enemy every 2.5 to 4.5 s within 80 studs.

```lua
--!strict
-- Random spot sounds around the listener within a zone. Client-side.
local Workspace = game:GetService("Workspace")

type Spot = { assetId: string, minGap: number, maxGap: number, radius: number, volume: number }

local function runSpots(spot: Spot, isActive: () -> boolean, play3D: (Vector3, string, number) -> ())
	task.spawn(function()
		while true do
			task.wait(spot.minGap + math.random() * (spot.maxGap - spot.minGap))
			if isActive() then
				local cam = Workspace.CurrentCamera
				if cam then
					local angle = math.random() * math.pi * 2
					local dist = spot.radius * (0.4 + 0.6 * math.random())
					local pos = cam.CFrame.Position + Vector3.new(math.cos(angle) * dist, math.random() * 6, math.sin(angle) * dist)
					play3D(pos, spot.assetId, spot.volume * (0.8 + 0.4 * math.random()))
				end
			end
		end
	end)
end
```

`play3D` creates a temporary attachment at `pos` (on Terrain or an anchored helper part) and plays through it. Vary volume and pitch slightly per play.

### Indoor and outdoor
Crossing into a building should change the bed and add a room reverb (an `AudioReverb` on the ambience bus, or a `ReverbSoundEffect` on a group). Do not forget to fade the outdoor bed down to a muffled version rather than to silence: hearing the storm outside is part of being indoors.

---

## 6. Levels and settings

- Music low: the reference project's background music targeted about 0.017 effective loudness (later 0.03), shop music about 0.045, ambience beds about 0.008, compared with 0.17 to 0.27 for combat.
- Separate sliders for music and effects at minimum; many players keep effects and mute music.
- The reference project's legacy "music off" toggle only controlled one old disabled sound, a classic bug: when you replace a music system, re-wire the old settings to the new bus.
- Respect the player's choice across sessions (save the setting with player data, [[DataStore Fundamentals]]).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Hard cut between tracks | One player, swap asset | Two decks, crossfade before the end. |
| Background restarts after every shop visit | Stop resets / new track each time | Pause at silence and resume. |
| Stems drift out of sync | Started one by one | `Play(atTime)` on mixer time. |
| Music unbearable after 20 minutes | One short loop | Playlist, silences, lower level. |
| Zone change sounds abrupt | No crossfade, or sound and sky change at different borders | Shared zone lookup, 2 to 3 s fade. |
| A bed hides a gameplay cue | Bed added without checking masking | Remove or EQ it; cues win. |
| Music toggle does nothing | Toggle wired to the old system | Wire settings to the bus. |
| First second of the game is a blast of music | No fade-in on join | 2 to 3 s fade-in. |

## Checklist

- [ ] Every track licensed or owned; uploads within limits.
- [ ] Two-deck crossfades; fade-in on join; silences between tracks.
- [ ] Context switches with priorities; pause and resume where sensible.
- [ ] Beat-locked starts use mixer time.
- [ ] Zone beds share the zone lookup with lighting; crossfaded; levelled under SFX.
- [ ] No ambience masks gameplay cues.
- [ ] Music and effects sliders wired to buses and saved.

See also: [[Sound Fundamentals]], [[The Audio API - Players Emitters Wires and Effects]], [[Spatial Audio and Mixing]], [[Sound Design for Games]], [[Lighting Mood and Time of Day]], [[Genre Playbook - Horror and Story]].

## Nuances and edge cases

1. **Music is client-side by nature.** Each player hears their own mix, so music logic belongs on the client, driven by state the server replicates (zone, combat, boss phase). Playing music from the server to everyone makes per-player context impossible: one player's boss fight should not change the music for someone fishing across the map.
2. **Phones play through tiny speakers.** Bass-heavy stems disappear on phone speakers, while mid-range melodies cover gameplay sounds. Mix for the small speaker as well as headphones: check that combat cues stay audible over the loudest music state on a phone (rule of thumb: music sits several decibels under the key gameplay cues).
3. **Asset loading delays transitions.** The first time a track plays, it may need to download; on a slow phone connection that can be seconds. Preload the next likely tracks (the boss track when a player reaches the boss door) instead of loading at the moment of transition.
4. **Licensing and asset privacy.** Audio you upload must be yours or licensed, and audio privacy rules mean some assets only play in experiences with permission (Roblox docs, as of October 2026, describe audio asset privacy and permissions; check the current rules before using audio from another creator). Missing permission shows as silence, not an error a player reports.
5. **Volume settings players expect.** Many players mute music to play their own. Give separate music and effects sliders, persist them, and apply them to every music source, including stingers and menus. A music slider that does not affect the shop jingle reads as a bug.
6. **Fatigue scales with session length.** A 3-minute loop is fine in a 10-minute session and grating in a 2-hour grind. Long-session genres need more total music, more silence between tracks, and lower default levels.
7. **Adaptive layers cost memory.** Four stems per state across five states is twenty long audio assets in memory if all are loaded. On low-end devices, keep only the current and next state's stems loaded.
8. **Server size does not change music cost, but events do.** With 50 players, a server event (a world boss spawning) that switches everyone's music at once is fine because each client does its own mixing. The risk is design, not performance: a global music change interrupts players who are not involved.

The senior trade-off: adaptive music raises immersion but takes composition time, implementation time and memory. A small game often gets more from two good tracks, clean crossfades and good silence than from a complex stem system.

## Common mistakes (advanced)

1. **Server-played music.** Symptom: everyone hears the boss track. Fix: client music driven by replicated state.
2. **Transition on the first frame of a new state.** Symptom: music flips back and forth when a player stands on a zone border. Fix: hysteresis or a minimum time in a state before switching.
3. **No preloading.** Symptom: silence for a few seconds at the boss. Fix: preload on approach.
4. **Stingers that ignore the music's volume setting.** Symptom: players with music muted still hear jingles. Fix: route all music-like sounds through the same group or bus.
5. **Mixing only on headphones.** Symptom: phone players cannot hear footsteps over music. Fix: test on a phone speaker.
6. **Audio from other creators without permission.** Symptom: silent tracks in the live game. Fix: own or license the audio and confirm it plays in a published test.

## Related decisions

- [[Audio Pipeline]]: preparing and uploading music assets.
- [[AI Audio - Voice Music and SFX]]: generated music and its licensing questions.
- [[Captions and Audio Accessibility]]: music settings and players who rely on captions.
- [[Zone and Biome Art Direction]]: matching music zones to visual zones.
- [[Boss Fight Design Patterns]]: phase changes that drive music changes.
- [[Combat Sound Design and Feedback]]: keeping combat cues above music.
- [[Legal Basics - IP Licenses and Assets]]: music licensing rules.
- [[Mobile and Low-End Optimization]]: memory budgets for audio.

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Audio]] · Official Docs - Asset Creation · Feedback Timing - Sound Visual and Haptic Sync · Voice Chat and Safety Features
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Music Licensing and Audio Upload Rules for 2026]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Audio Mixer Settings with SoundGroups]] · [[SoundService - Engine Reference Card]] · [[Engine and Tyre Audio Driven by RPM and Slip]]
<!-- related:end -->
