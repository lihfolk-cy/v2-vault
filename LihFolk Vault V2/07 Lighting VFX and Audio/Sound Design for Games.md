---
tags: [audio, sound-design, combat, layering, variation, ui-sounds, type/guide, area/vfx, level/intermediate, area/audio, api/Sound]
---
# Sound Design for Games

<!-- tldr:start -->
> [!tldr] TL;DR
> - Hits feel late: Sound started on the beat, peak later -> Start at beat minus peak.
> - Machine-gun repetition: One take, no variation -> Bags, pitch variance, layer recombination.
> - Big creature roar sounds slow and blurry: Pitched down with PlaybackSpeed -> Pitch shifter or a lower take.
> - Each core action layered (transient, body, air, sweetener).
> - Peaks aligned to visual beats from measured data.
> - Variation by bags, pitch and recombination; choke on rapid repeats.
>
> Cost: TL;DR ~160 tok · whole note ~3.5k tok. Read more: ## 2. Timing: the peak lands on the beat · ## 5. Physics-driven and state-driven sounds · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Sound design is deciding what every action sounds like, then making it sound like that every time without becoming repetitive, without arriving late, and without drowning everything else. On Roblox you rarely record your own foley; you assemble sounds from licensed library takes and your own uploads, slice them, layer them, pitch them, level them and trigger them precisely. This note is the craft side: layering, timing to the visual beat, variation, character and weapon voices, enemy sound profiles, physics-driven sounds, UI kits, cues as gameplay information, and the governance that keeps a sound library sane.

Mechanics are in [[Sound Fundamentals]], [[The Audio API - Players Emitters Wires and Effects]] and [[Spatial Audio and Mixing]].

Source labels: **Docs**, **Reference project** (one live action game with hundreds of weapons and enemies), **Rule of thumb**.

---

## 1. Layering

A single file rarely carries an action. Build sounds from layers with distinct jobs:

| Layer | Job | Example for a sword swing |
|---|---|---|
| Transient (crack) | The instant of action, sharp attack | A short whip crack |
| Body | Weight and character | A metallic swish or a spin |
| Air / tail | Size and space | A breathy wind whoosh |
| Sweetener (optional) | Identity | An element sting (fire, ice, lightning) |

The reference project's swing system played **crack + body/spin + air** from sliced wind takes, with kinds per move (light, heavy-light, finisher, heavy, dash, rev, whoosh). Its enemy kit added an element sting on every hit (fire, ice, lightning, void, glitch, rock, magic). Each layer was levelled separately, so the layer balance stayed the same whatever file was drawn.

Rules of thumb:
- Layers should differ in frequency content (a low body, a mid crack, a high air) or they mask each other.
- Bigger action = more layers, not just louder ones. A finisher earns a sub-layer and a longer tail.
- Keep each layer short; long tails from many layers smear into mush in combos.

---

## 2. Timing: the peak lands on the beat

The loudest moment of a whoosh is rarely at time 0. If a sound starts on the hit frame, its peak arrives 0.1 to 0.4 s later and the hit feels late.

The reference project **measured onset and peak for every sound** and scheduled it to start at `beat - peak` so the peak landed on the visual beat. Examples from its notes: a draw scrape peaking at 0.37 s, a quick swish at 0.13 s. Swing sounds were cut so the crack's peak landed on the hit. Enemy takes were trimmed to their onset so the marker time equalled heard time, and playback started 15 ms before the measured onset. One equip sound had been about 0.43 s late until it was aligned.

```lua
--!strict
-- Play a classic Sound so that its measured peak lands at `beatAt` (os.clock time).
local function playPeakAt(sound: Sound, peak: number, beatAt: number)
	local startIn = beatAt - peak - os.clock()
	if startIn <= 0 then
		-- Late: skip into the file so the peak is as close to the beat as possible.
		sound.TimePosition = math.min(-startIn, peak)
		sound:Play()
	else
		task.delay(startIn, function()
			sound.TimePosition = 0
			sound:Play()
		end)
	end
end
```

`task.delay` is frame-quantised (about 16 ms at 60 fps), which is fine for most effects. For music-locked sounds use `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`.

Tie sound triggers to the same markers that drive damage and VFX ([[Markers and Events]], [[VFX Timing with Animation]]). If a sound is scheduled at input time and the move is cancelled, it still plays: carry a cancellation token like the VFX code does.

Even an animation can be timed from sound: the reference project derived the growth time of an energy-blade ignition (0.18 to 0.40 s per take) from where each ignition sound spent its energy, divided by the voice's pitch.

---

## 3. Variation without chaos

Hearing the identical file 200 times in a fight is the "machine gun effect". Countermeasures:

| Technique | Detail |
|---|---|
| Round-robin bags | Shuffle a set of takes; draw without replacement until empty; reshuffle (never the same take twice in a row) |
| Pitch variance | ±3 to 6% per play for small sounds; less for tonal sounds |
| Volume variance | ±1 to 2 dB |
| Layer recombination | 3 cracks x 3 bodies x 3 airs = 27 combinations from 9 files |
| Choke | A new instance stops the previous one of the same layer (fast swings) |

```lua
--!strict
-- Bag: round-robin random without immediate repeats.
local Bag = {}
Bag.__index = Bag

export type Bag = typeof(setmetatable({} :: { items: { string }, queue: { string }, last: string? }, Bag))

function Bag.new(items: { string }): Bag
	return setmetatable({ items = items, queue = {}, last = nil }, Bag)
end

function Bag.next(self: Bag): string
	if #self.queue == 0 then
		local q = table.clone(self.items)
		for i = #q, 2, -1 do -- Fisher-Yates shuffle
			local j = math.random(i)
			q[i], q[j] = q[j], q[i]
		end
		if #q > 1 and q[#q] == self.last then
			q[1], q[#q] = q[#q], q[1] -- avoid repeating across the reshuffle
		end
		self.queue = q
	end
	local item = table.remove(self.queue) :: string
	self.last = item
	return item
end

return Bag
```

Variation must stay inside the identity. Random pitch on a character's signature sound makes it sound like a different character.

---

## 4. Voices: identity per weapon, character and enemy

### Weapon voices
The reference project gave **every weapon a voice**: a pitch plus its own sound group, on top of a shared "sound font" (a family of takes: ignition, hum, swing accents, clash, retract, lock). Several weapons could share a font while sounding distinct through pitch, and a weapon's voice was documented in its design note. Rules it learned:
- Keep the voice table in one place; two tables that must stay in sync will drift.
- A weapon the designer loved kept its own sounds outside the font system ("keep its own sounds" was an explicit rule).
- Fonts were assembled from upload batches by naming conventions (swing, clash, blast, lock...), and roles a font lacked fell back sensibly (a font without lock-begin/end reused its lock).

### Enemy profiles
Its enemy sound kit described each enemy by **voice family** (beast, crab, hiss, bird, insect, ghost, glitch, ethereal, treant, rock, knight), **element**, **body weight** and **pitch**, and read animation markers by name (Roar, Charge, Breath, Slam, Claw). About 195 library takes were levelled by measured loudness and started at their onset, with per-family footsteps and crowd caps. A new enemy then needed a profile row, not new code.

Profiles scale: size and pitch should correlate (bigger is lower and slower), but avoid pure `PlaybackSpeed` scaling for big creatures because it stretches time; use a pitch shifter or pick a lower take.

---

## 5. Physics-driven and state-driven sounds

Some sounds follow continuous state instead of events:
- **Speed-driven beds.** Chain weapons in the reference project had a looped jingle that swelled with the handle's speed, a second heavy drag bed underneath, a little constant chain sound while held, a louder peak (bed max 0.62), lashes when the handle exceeded about 38 studs/s, and quiet clinks when still. Per-weapon pitch (0.72 to 0.98) and volume lived in a table.
- **Crackle beds.** Weapons with animated lightning had a crackle bed that stirred and built while active, quieter on some weapons.
- **Wind and spin.** Swing whooshes scale with angular speed.

```lua
--!strict
-- Speed-driven loop: volume and pitch follow a part's speed relative to the character root.
local RunService = game:GetService("RunService")

local function speedBed(handle: BasePart, root: BasePart, loop: Sound, base: number, maxVol: number, fullSpeed: number)
	loop.Looped = true
	loop.Volume = base
	loop:Play()
	local smoothed = 0
	return RunService.Heartbeat:Connect(function(dt: number)
		local rel = (handle.AssemblyLinearVelocity - root.AssemblyLinearVelocity).Magnitude
		local target = math.clamp(rel / fullSpeed, 0, 1)
		smoothed += (target - smoothed) * math.min(1, dt * 8) -- smooth to avoid zipper noise
		loop.Volume = base + (maxVol - base) * smoothed
		loop.PlaybackSpeed = 0.9 + 0.2 * smoothed
	end)
end
```

Measuring the handle's velocity **relative to the root** matters: otherwise walking or riding a moving platform triggers the "fast swing" sound.

---

## 6. Sound as gameplay information

Sound is the fastest channel to the player and works off-screen. Use it for:

| Cue | Reference project example |
|---|---|
| Enemy noticed you | A "spotted" burst, at most once per second |
| Boss arrives | A boom with the boss bar slide-in, at most once per 8 s, 2D |
| Incoming hazard | A meteor whoosh 0.75 s before impact, then the explosion |
| Rare thing nearby | A bright chime every 2.5 to 4.5 s within 80 studs of a golden enemy |
| Action failed | A bass glissando down when swinging with no stamina |
| Reward claimed | Coins plus sparkle |

Rules:
- **Every warning sound needs a visual twin**, for deaf and muted players ([[Accessibility]]).
- **Consistency**: the same danger always sounds the same.
- **Rate-limit cues** so they stay meaningful.
- **Do not add sound where it does not belong.** The reference project removed "random sounds for random things": footsteps no longer triggered swing accents, idle animations made no motion hum, and the player's weapon went silent while a full-screen menu was open.

---

## 7. UI sound kits

UI sounds should form one family: same timbre, consistent pitch ladder (higher for positive, lower for negative), very short, levelled far below combat. A kit worth having (the set the reference project synthesised to match a reference clip): pop click, pop note, soft tick, air whoosh, open bloop, reward run. Map them:

| Event | Sound |
|---|---|
| Hover | soft tick (or none on touch devices) |
| Press | pop click |
| Panel open / close | open bloop / air whoosh |
| Confirm, claim | pop note, reward run for big rewards |
| Error, locked | a short low note |
| Tab switch | soft tick |

Throttle hover sounds; a mouse dragged over a grid of 40 buttons should not play 40 ticks.

---

## 8. Sourcing and governance

- **Library first, uploads second.** Licensed library takes are safe and moderated; your uploads must be yours.
- **Name and catalogue.** Keep a table of every id with role, measured loudness, onset, length and where it is used. The reference project's loudness table was the single source of truth: no row, no levelling.
- **Forbidden list.** When the team rejects a set of recordings, keep them listed as forbidden so they are not reintroduced by a later pass.
- **Detect duplicates** by waveform correlation before treating two ids as variations.
- **Record gaps honestly.** If no fitting sound exists (an ice creak, a freeze one-shot), note it rather than using something that does not fit.
- **Safety copies before sound passes.** A sound pass touches many scripts; back them up so a "revert the new swing sounds" request is one switch (the reference project's layered swing system had a single flag to revert to the previous behaviour).

---

## 9. Review process

1. Watch the action muted. Does the visual read? Then with sound only, eyes closed. Does the sound read?
2. Slow the action down (0.25x) with sound on and check the peak lands on the frame.
3. Repeat the action 50 times. Does it get annoying? Add variation or cut a layer.
4. Do it in a crowd: 8 players, 20 enemies.
5. Listen on phone speakers.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Hits feel late | Sound started on the beat, peak later | Start at beat minus peak. |
| Machine-gun repetition | One take, no variation | Bags, pitch variance, layer recombination. |
| Big creature roar sounds slow and blurry | Pitched down with PlaybackSpeed | Pitch shifter or a lower take. |
| Walking triggers swing sounds | Speed measured in world space | Relative to the root. |
| Sounds fire for cancelled moves | Scheduled without a token | Cancellation token. |
| Players miss danger | Cue is audio-only | Visual twin. |
| A rejected sound returns | No forbidden list | Keep one. |
| UI feels noisy | Hover sounds unthrottled, levels too high | Throttle, level UI low. |

## Checklist

- [ ] Each core action layered (transient, body, air, sweetener).
- [ ] Peaks aligned to visual beats from measured data.
- [ ] Variation by bags, pitch and recombination; choke on rapid repeats.
- [ ] Voices and profiles defined in data tables, one source of truth.
- [ ] State-driven sounds measured relative to the character.
- [ ] Cues rate-limited, consistent and doubled visually.
- [ ] UI kit coherent and quiet.
- [ ] Catalogue with measurements, forbidden list, duplicate check, safety copies.

See also: [[Sound Fundamentals]], [[Spatial Audio and Mixing]], [[Music and Adaptive Audio]], [[The Audio API - Players Emitters Wires and Effects]], [[Game Feel and Juice]], [[VFX Timing with Animation]], [[Equip Draw and Flourish Systems]], [[Enemy and NPC Animation]], [[Combat Systems Architecture]].

## Connected notes
<!-- auto-links:start -->
[[Combat Sound Design and Feedback]] · [[Audio Pipeline]] · Feedback Timing - Sound Visual and Haptic Sync · AI Audio - Voice Music and SFX · Captions and Audio Accessibility · Links - Sounds and the Audio API
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[VFX Design Playbook]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Music Licensing and Audio Upload Rules for 2026]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]
<!-- related:end -->
