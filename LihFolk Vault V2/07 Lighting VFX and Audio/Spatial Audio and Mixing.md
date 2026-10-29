---
tags: [audio, spatial, mixing, attenuation, loudness, buses, performance, type/guide, area/vfx, level/intermediate, area/audio, api/Sound]
---
# Spatial Audio and Mixing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Distant fights audible everywhere: Default 10,000-stud max distance -> Per-category distances.
> - Sound cuts off abruptly: Inverse/Linear with a low max distance -> InverseTapered or a custom curve.
> - Own footsteps sound far away: Listener at the third-person camera -> 2D own sounds or a closer listener.
> - Attenuation set per category; no defaults left on positional sounds.
> - Listener position chosen deliberately for the camera style.
> - Every sound measured and levelled to a category target.
>
> Cost: TL;DR ~170 tok · whole note ~3.5k tok. Read more: ## 1. Attenuation · ## 5. Voice limits and throttles · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Spatial audio decides **where** a sound seems to be and **how loud it is from here**. Mixing decides **how loud each sound is relative to everything else**, and what gets dropped when too much happens at once. In a multiplayer game these two problems meet: thirty players casting abilities in one plaza is a spatial problem (who is close?) and a mixing problem (which of these 200 sounds matter?).

This note covers attenuation in both audio systems, the listener's position, Doppler and volumetric sounds, acoustic simulation, then mixing: loudness targets, buses, ducking, voice caps and throttles, onlooker rules and testing.

Source labels: **Docs**, **API dump**, **Reference project** (one production combat game that levelled about 1,200 sounds), **Rule of thumb**.

---

## 1. Attenuation

### Classic `Sound`
Positional when parented to a `BasePart` or `Attachment` (Docs). Controlled by:
- `RollOffMinDistance` (default 10 studs): full volume inside.
- `RollOffMaxDistance` (default 10000): silent beyond.
- `RollOffMode` (default `Inverse`): `Inverse`, `Linear`, `LinearSquare`, `InverseTapered`.

Docs warning: with `Inverse` and `Linear` modes, low `RollOffMaxDistance` values make the sound cut off abruptly when the listener reaches the max distance. `InverseTapered` behaves like inverse close up and tapers to zero at the max, which avoids the cliff.

**Defaults are almost never right.** A 10-stud minimum with a 10,000-stud maximum means an explosion is audible across the whole map at low volume, and every footstep in the server mixes into a constant murmur. Set distances per sound category:

| Category | Min | Max | Mode (rule of thumb) |
|---|---|---|---|
| Footsteps | 4 to 6 | 40 to 60 | InverseTapered |
| Melee swings and hits | 6 to 10 | 80 to 120 | InverseTapered |
| Abilities, spells | 10 to 15 | 150 to 250 | InverseTapered |
| Explosions, boss roars | 20 to 40 | 300 to 600 | InverseTapered |
| Ambience spots (waterfall, machine) | size of the source | 60 to 120 | Linear or tapered |

The reference project's waterfall spots used a 90-stud maximum; its gold-enemy chime was audible within 80 studs.

### Audio API
`AudioEmitter.DistanceAttenuationMode` (default `Custom`) with a curve set by `SetDistanceAttenuation`, or a preset (`Inverse`, `InverseTapered`, `Linear`, `LinearSquared`) bounded by `DistanceAttenuationBounds` (default 4 to 10000) (Docs). Curves take up to 400 points. The docs' example halves volume at 50 studs and reaches zero at 70.

Custom curves let you design falloff the way a sound designer thinks: flat close up, a shoulder, a fast drop, zero.

```lua
--!strict
-- Build a smooth distance curve: full volume to `near`, then a cosine fall to 0 at `far`.
local function falloffCurve(near: number, far: number, steps: number?): { [number]: number }
	local curve: { [number]: number } = { [0] = 1, [near] = 1 }
	local n = steps or 8
	for i = 1, n do
		local t = i / n
		local d = near + (far - near) * t
		curve[d] = 0.5 + 0.5 * math.cos(math.pi * t) -- 1 -> 0, eased at both ends
	end
	return curve
end

-- emitter:SetDistanceAttenuation(falloffCurve(8, 120))
```

**Angle attenuation** (`SetAngleAttenuation`, 0 to 180 degrees from the emitter's look vector) makes directional sources: a megaphone, a creature's roar that is louder in front, a speaker facing a crowd. Listener-side angle curves can model hearing (quieter behind you).

---

## 2. Where is the listener?

By default classic sounds are heard from the **camera** (Docs). The audio API's default listener is on the camera (or the character, depending on `SoundService.DefaultListenerLocation`).

In a third-person game the camera can be 15 to 25 studs behind the character. Consequences:
- Sounds next to the character are attenuated by the camera distance; your own footsteps sound distant.
- Stereo panning follows the camera's orientation, which is usually what players expect.

Options:
- Keep the camera listener, and play **your own** character's sounds 2D (non-positional) or with a large minimum distance.
- Put the listener on the character (`Character` location, or `SoundService:SetListener` for classic sounds with `ListenerType` `ObjectPosition`/`ObjectCFrame`/`CFrame`) and accept that panning follows the character rather than the view.
- Hybrid (rule of thumb): listener on a point between camera and character, updated each frame.

### Doppler
Classic sounds on moving parts exhibit Doppler (Docs). `SoundService.DopplerScale` (default 1) scales it; `DistanceFactor` (default 3.33) and `RolloffScale` (default 1) are global scaling knobs. Fast projectiles and vehicles can pitch-bend wildly; lower `DopplerScale` if it sounds silly.

### Volumetric sounds
With `SoundService.VolumetricAudio` enabled, a `Sound` on a large part surrounds the listener when inside the part and narrows as they leave (Docs). Good for rain zones and large ambience areas; one sound covers a region instead of a grid of point sources.

### Acoustic simulation (audio API)
Occlusion (muffling through walls), diffraction (bending around corners) and reverberation (Docs). Requires `SoundService.AcousticSimulationEnabled` (default false in the API dump) plus `AcousticSimulationEnabled` on both emitter and listener. It is the right tool for stealth and horror; in a busy arena game, occlusion can make fights sound muddy and cost CPU. Test with your densest geometry.

---

## 3. Loudness targets

Before buses and effects, sounds must be **levelled**: each file played at a volume that gives it the intended loudness. The method (measure each asset's RMS and onset with `GetWaveformAsync`, then `Volume = target / measured`) is in [[Sound Fundamentals]].

The reference project defined effective loudness as **robust RMS x Volume x bus volume**, and set targets per category:

| Category | Target effective loudness |
|---|---|
| Blade swing | 0.267 |
| Blade hit | 0.173 |
| Combat and ability sounds | 0.165 |
| Enemy sounds | 0.11 |
| Stingers, ultimates | 0.25 |
| UI reel stings | 0.10 |
| UI reward | 0.07 |
| UI click | 0.025 |
| Music | about 0.017 (later 0.03 for background, 0.045 for shop music) |
| Ambience bed | about 0.008 (beds measured 0.004 to 0.018) |

These are relative numbers in one game's measurement system, not universal constants. What carries over is the **shape**: your own actions loudest, enemies below you, UI far below combat, music and ambience a bed underneath. One-shots in the project's ambient and gameplay cue pass were levelled by **peak** (target peak / measured peak, around 0.1 to 0.25, big events 0.3), and beds by **RMS**: peaks matter for short sounds, average energy for long ones.

A useful sanity check: after levelling, the loudest sound in the game should be something the player caused and wanted (a finisher, an ultimate), not an ambient loop or a UI click.

---

## 4. Buses and ducking

Group sounds into buses so whole categories can be balanced, processed and exposed to players' settings at once ([[Sound Fundamentals]] for `SoundGroup`, [[The Audio API - Players Emitters Wires and Effects]] for faders).

Reference project bus layout:
- A weapon bus with EQ, compressor and a short reverb so every blade sat in the same space.
- An enemy bus.
- Settings-controlled buses for SFX, music and UI wired to the settings menu sliders.
- Ambience beds on the music/ambience slider because they are looped in SoundService.

**Ducking** lowers less important sound while important sound plays: music under dialogue, ambience under combat, UI under a boss intro. Use a sidechained compressor (classic `CompressorSoundEffect.SideChain`, or the audio API's `Sidechain` pin) or script it: tween the bus down 4 to 8 dB when an event starts and back up after (rule of thumb). Scripted ducking is often clearer to tune than compressor settings.

---

## 5. Voice limits and throttles

Without limits, a busy server stacks dozens of identical sounds. Problems: phasing and comb filtering (the same file layered sounds thin and metallic), clipping, CPU cost and pure noise.

Techniques used in the reference project:
- **Global live cap for effect sounds:** at most 24 alive at once.
- **Per-key minimum gaps:** the same cue cannot restart within its gap (an aggro alert at most once per second; a boss-bar boom once per 8 s).
- **Voice caps for swings:** 7 for your own and 28 overall, plus **choke** (a new swing stops the previous swing of the same layer).
- **Crowd caps for enemies:** per-family caps so a pack of 12 enemies does not play 12 identical growls.
- **Onlookers quieter:** other players' ability sounds about 0.7x; strikes "heard quieter" by onlookers.
- **Distance gates:** do not even start sounds beyond the audible range.

```lua
--!strict
-- Throttle: live cap + per-key gaps + oldest-voice stealing. Wraps any start function.
local Throttle = {}

local MAX_LIVE = 24
local live: { { key: string, stop: () -> (), started: number } } = {}
local lastStart: { [string]: number } = {}

local function prune()
	for i = #live, 1, -1 do
		if os.clock() - live[i].started > 10 then -- safety: forget very old voices
			table.remove(live, i)
		end
	end
end

-- start() must begin playback and return a stop function and an "ended" signal hook.
function Throttle.play(key: string, minGap: number, start: () -> (() -> (), (() -> ()) -> ())): boolean
	local now = os.clock()
	if now - (lastStart[key] or -math.huge) < minGap then
		return false -- too soon for this cue
	end
	prune()
	if #live >= MAX_LIVE then
		local oldest = table.remove(live, 1) -- steal the oldest voice
		if oldest then
			oldest.stop()
		end
	end
	lastStart[key] = now
	local stop, onEnded = start()
	local entry = { key = key, stop = stop, started = now }
	table.insert(live, entry)
	onEnded(function()
		local i = table.find(live, entry)
		if i then
			table.remove(live, i)
		end
	end)
	return true
end

return Throttle
```

Usage with a classic sound:
```lua
Throttle.play("aggro", 1, function()
	local s = alertTemplate:Clone()
	s.Parent = enemyRoot
	s:Play()
	return function() s:Destroy() end, function(cb) s.Ended:Once(function() cb(); s:Destroy() end) end
end)
```

Stealing the oldest voice is simple; stealing the quietest (farthest) is better for spatial sounds. Prioritise by category: never steal the player's own hit to make room for a distant ambient chirp.

---

## 6. Quieting rules

Many mix problems are not loudness but **relevance**. The reference project's user feedback was blunt ("random sounds for random things"), and the fixes were rules, not volumes:
- Footsteps do not trigger swing accents.
- Idle and showcase animations do not trigger motion hums.
- Your weapon is silent while a full-screen menu (the move list) is open.
- An ambience bed that masked an important wind sound was removed rather than turned down.
- New sounds go only where they belong: the instruction for a whole ambience pass was "don't put anything where it doesn't belong".

Write such rules down; they are part of the mix.

---

## 7. Testing the mix

- **Phone speakers and cheap earbuds.** Bass-heavy sounds vanish on phones; a sound that only works on headphones does not work.
- **Busy scenarios**: a full server in one place, a boss fight with a party, a shop opening during combat.
- **Settings at extremes**: music off, SFX at 10%, UI muted. Nothing important should depend on a bus the player can mute (a warning needs a visual too).
- **Long sessions**: loops and repeated cues are fine for one minute and grating after twenty.
- **Measure, then listen.** Measurement levels files; ears judge the mix.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Distant fights audible everywhere | Default 10,000-stud max distance | Per-category distances. |
| Sound cuts off abruptly | Inverse/Linear with a low max distance | InverseTapered or a custom curve. |
| Own footsteps sound far away | Listener at the third-person camera | 2D own sounds or a closer listener. |
| Metallic phasing on group attacks | Same file stacked | Voice caps, choke, variations. |
| Constant murmur in hubs | No crowd caps | Per-family caps and distance gates. |
| UI clicks louder than hits | No category targets | Level by category. |
| Important cue lost when music is muted | Cue routed to music bus | Route cues to SFX; add visuals. |
| Fights muddy with occlusion on | Acoustic simulation everywhere | Use it where it serves the design. |

## Checklist

- [ ] Attenuation set per category; no defaults left on positional sounds.
- [ ] Listener position chosen deliberately for the camera style.
- [ ] Every sound measured and levelled to a category target.
- [ ] Buses for SFX, UI, music, ambience wired to settings.
- [ ] Ducking for dialogue and big moments.
- [ ] Live cap, per-key gaps, voice caps and choke; onlookers quieter.
- [ ] Quieting rules written down.
- [ ] Mix tested on phone speakers in a full server.

See also: [[Sound Fundamentals]], [[The Audio API - Players Emitters Wires and Effects]], [[Sound Design for Games]], [[Music and Adaptive Audio]], [[Performance Fundamentals]], [[Network Performance]].

## Connected notes
<!-- auto-links:start -->
[[Audio Pipeline]] · [[Combat Sound Design and Feedback]] · Official Docs - Audio · Captions and Audio Accessibility · AI Audio - Voice Music and SFX
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Audio Mixer Settings with SoundGroups]] · [[SoundService - Engine Reference Card]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Music Licensing and Audio Upload Rules for 2026]]
<!-- related:end -->
