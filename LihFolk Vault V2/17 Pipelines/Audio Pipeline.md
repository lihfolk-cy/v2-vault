---
tags: [pipelines, audio, sound, loudness, mixing, automation, type/guide, area/pipelines, level/intermediate, area/audio]
---
# Audio Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - One sound far louder than the rest: not in the loudness table -> gate: unlevelled ids
> - Sounds feel late: silence before the onset -> trim offline or start before the measured onset
> - Levels jump after a re-measure: different measuring method -> one method per table, conversion factor documented
> - Source and rights recorded per id
> - Offline prep: trimmed, faded, normalised, named by role
> - Id map JSON per upload batch
>
> Cost: TL;DR ~150 tok · whole note ~4.3k tok. Read more: ## Stage 2: prepare offline · ## Stage 4: measure loudness in Studio · ## Failure modes · ## Checklist
<!-- tldr:end -->

Audio is the asset type where "it worked on my machine" is most literally true. Sounds come from many sources at wildly different loudness, they are uploaded one by one, players hear them through phone speakers and headphones, and nobody notices a badly levelled sound until fifty of them play at once. A good audio pipeline makes loudness a **measured number** rather than a slider somebody nudged, keeps a single table of every sound the game may play, and makes it impossible to ship a sound that is banned, unlevelled or missing.

The craft of sound design is in [[Sound Design for Games]], the engine in [[Sound Fundamentals]] and [[The Audio API - Players Emitters Wires and Effects]], mixing in [[Spatial Audio and Mixing]], music in [[Music and Adaptive Audio]], and AI audio tools in [[AI Audio - Voice Music and SFX]]. This note is the production path.

## The stages

| # | Stage | Input | Output | Tool |
|---|---|---|---|---|
| 1 | Source | licensed library, own recordings, synthesis | candidate files or library asset ids | Creator Store, DAW, Python |
| 2 | Prepare (offline) | raw files | trimmed, faded, mono or stereo, normalised WAV/OGG | DAW or a Python script |
| 3 | Upload | prepared files | asset ids + id map JSON | Studio, Open Cloud |
| 4 | Measure (in Studio) | asset ids | loudness rows: RMS, peak, onset, length | Edit-mode measuring script |
| 5 | Register | rows | generated loudness module, sound catalogue | generator + one-insert edit |
| 6 | Route | catalogue | SoundGroups / buses with effects, category sliders | Studio |
| 7 | Gate | everything | no unlevelled ids, no banned ids, duplicates flagged | checker |
| 8 | Listen | game | approval, notes | human, in Play |

## Stage 1: sources and their rules

| Source | Pros | Cons | Notes |
|---|---|---|---|
| Roblox's licensed library (sound effects and music distributed through the Creator Store) | free to use in experiences, huge, already uploaded | loudness varies a lot; some categories missing | the reference project used it for ambience beds, UI, impacts and its music |
| Your own uploads | exactly what you want | upload quotas, moderation, your responsibility for rights | Audio: `.mp3`, `.ogg`, `.wav`, `.flac`, up to 7 minutes; 100 uploads per month if ID-verified, 10 if not (Roblox docs, as of October 2026) |
| Synthesised in code | unlimited variations, consistent style, no rights questions | sounds synthetic unless done well | the reference project synthesised whole per-weapon banks in Python (one bank of 83 takes for 10 weapons, another of 11 takes for one weapon) |
| AI-generated | fast ideation | policy and quality questions | see [[AI Audio - Voice Music and SFX]] and [[Roblox Policies on AI-Generated Content]] |

Two library rules from the reference project: when the library has no good match, **say so and leave the gap** (its notes list "frost has no ice-creak bed, no licensed freeze one-shot exists" rather than a wrong sound); and keep a **forbidden list** of ids the owner removed, checked by the gate in stage 7, so an agent or a new team member cannot re-add them from an old note.

## Stage 2: prepare offline

Everything that can be done to a file before upload should be, because after upload you can only change Volume, PlaybackSpeed, regions and effects.

- **Trim silence at the head.** A sound with 120 ms of silence before the hit feels laggy. If you cannot trim (library sounds), measure the onset in stage 4 and start playback just before it.
- **Short fades** (2 to 5 ms) at cut points to avoid clicks.
- **Mono for 3D one-shots**, stereo for music and 2D UI and ambience (rule of thumb).
- **Normalise to a target**, so the in-game Volume values stay in a sane range. Integrated loudness (LUFS, ITU-R BS.1770) is the industry measure; the Python package `pyloudnorm` implements it. For short one-shots, peak or short-term RMS is more meaningful than integrated loudness.
- **Name files by role**: `<bank>_<role>_<nn>.wav` (`chain_lash_03.wav`). Roles drive playback code later (the reference project parsed library names like `swing (3)`, `clsh01`, `blst01` into roles: hum, swing, clash, blaster, lock).

A tiny synthesiser for UI blips and sweeps, the kind of thing worth having in the toolbox:

```python
# synth.py  (py -I synth.py out_dir) : writes 16-bit mono WAVs with numpy only
import sys, wave, pathlib, numpy as np

SR = 44100
out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)

def env(n, attack=0.004, release=0.08):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    r = np.exp(-np.maximum(t - attack, 0) / release)
    return a * r

def write(name, x, peak_db=-3.0):
    x = x / max(np.max(np.abs(x)), 1e-9) * 10 ** (peak_db / 20)   # peak-normalise
    fade = min(len(x), int(0.003 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)                           # click-free tail
    with wave.open(str(out / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

def blip(f0, dur=0.12):
    n = int(dur * SR); t = np.arange(n) / SR
    return np.sin(2 * np.pi * f0 * t) * env(n, release=dur / 3)

def sweep(f0, f1, dur=0.35, noise=0.15, seed=1):
    n = int(dur * SR); t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)                  # exponential glide
    phase = 2 * np.pi * np.cumsum(f) / SR
    rng = np.random.default_rng(seed)
    return (np.sin(phase) + noise * rng.standard_normal(n)) * env(n, release=dur / 2)

write("ui_click_01", blip(1800, 0.05))
write("ui_reward_01", blip(660) + 0.6 * np.pad(blip(990), (int(0.07 * SR), 0))[: int(0.12 * SR)])
write("whoosh_up_01", sweep(200, 1400))
print("wrote", len(list(out.glob('*.wav'))), "files")
```

## Stage 3: upload and keep the id map

Upload through Studio (Asset Manager or bulk import) or the Open Cloud Assets API with `assetType` Audio ([[Asset Upload Automation with Open Cloud]]). Either way, write a JSON map `file name -> asset id` per batch. The upload quota (100 per month for ID-verified accounts) is the real constraint on synthesised banks: plan banks so one take can serve several roles through pitch and regions.

Record where each id came from (library, own upload, synth bank and its generator version). When a sound must be replaced for rights reasons, the record tells you every place it came from.

## Stage 4: measure loudness in Studio

Uploaded and library sounds still differ in loudness, sometimes by 20 dB. The reference project measured every id **inside Studio** with `AudioPlayer:GetWaveformAsync(timeRange: NumberRange, samples: number)` (Roblox API reference; the reference page types the return as `{any}`; in practice it returned a list of per-bucket amplitude values, as used in the reference project). It measured 1,192 loadable ids in one pass (measured in one production game).

```lua
--!strict
-- Edit-mode loudness probe for one asset. Returns rms, peak, onset (s) and length (s).
-- Run in short slices (a few ids per call) to stay under the Studio call budget.
local function measure(assetId: number, samples: number?): { rms: number, peak: number, onset: number, len: number }?
	local n = samples or 200
	local p = Instance.new("AudioPlayer")
	p.Asset = "rbxassetid://" .. tostring(assetId)
	p.Parent = game:GetService("SoundService")
	local t0 = os.clock()
	while not p.IsReady and os.clock() - t0 < 5 do
		task.wait(0.05)
	end
	if not p.IsReady or p.TimeLength <= 0 then
		p:Destroy()
		return nil -- will not load: moderated, private or deleted; report it
	end
	local len = p.TimeLength
	local ok, wave = pcall(function()
		return p:GetWaveformAsync(NumberRange.new(0, len), n)
	end)
	p:Destroy()
	if not ok or type(wave) ~= "table" or #wave == 0 then
		return nil
	end
	local sumSq, peak = 0, 0
	for _, v in wave do
		local a = math.abs(tonumber(v) or 0)
		sumSq += a * a
		peak = math.max(peak, a)
	end
	local rms = math.sqrt(sumSq / #wave)
	local onset = 0
	for i, v in wave do
		if math.abs(tonumber(v) or 0) >= 0.1 * peak then
			onset = (i - 1) / #wave * len
			break
		end
	end
	return { rms = rms, peak = peak, onset = onset, len = len }
end

return measure
```

### The aliasing trap

A waveform read with few samples is a coarse summary, and the reference project found that **60-sample reads aliased by up to plus or minus 48%** (measured in one production game): two reads of the same sound with slightly different ranges disagreed wildly, especially for short, spiky sounds. Its "robust" method took more samples (200) and combined several reads, and calibrated the result with fixed factors per table (one table stored 1.39 x the robust RMS, another 0.825 x, because they had been tuned against different earlier measures). Lessons:

- use at least 200 samples for one-shots under a few seconds;
- read twice with a small offset; if the two disagree by more than about 15%, read more (rule of thumb);
- **never mix numbers from two measuring methods in one table** without a conversion factor written next to the table.

## Stage 5: register in a generated loudness module

Measurements become a **generated** ModuleScript, never hand-edited:

```lua
-- AudioLoudness (GENERATED by measure_robust; do not edit by hand)
-- id -> { rms, onset (s), len (s) }. Effective loudness = rms * Volume * bus gain.
return {
	[1000000001] = { rms = 0.142, onset = 0.012, len = 0.84 }, -- placeholder ids
	[1000000002] = { rms = 0.051, onset = 0.000, len = 12.30 },
}
```

Playback code then sets Volume so every sound in a category lands at that category's target, and starts slightly before the onset:

```lua
--!strict
local Loudness = require(script.Parent.AudioLoudness)

local TARGET = { -- effective RMS targets per category (measured in one production game)
	swing = 0.267, hit = 0.173, combat = 0.165, enemy = 0.11,
	uiClick = 0.025, uiReward = 0.07, stinger = 0.25, music = 0.017, ambience = 0.008,
}
local PRE_ONSET = 0.015 -- start 15 ms before the measured onset

local function levelled(sound: Sound, assetId: number, category: string, level: number?)
	local row = Loudness[assetId]
	if not row then
		warn("unlevelled sound", assetId, "(add it to AudioLoudness)")
		return
	end
	sound.SoundId = "rbxassetid://" .. tostring(assetId)
	sound.Volume = math.clamp(TARGET[category] * (level or 1) / math.max(row.rms, 1e-4), 0, 10)
	sound.TimePosition = math.max(row.onset - PRE_ONSET, 0)
end

return levelled
```

The 0 to 10 clamp matches `Sound.Volume`'s documented range. If a quiet library take needs a Volume above about 3 to reach its target, it is probably a bad take; pick another rather than amplifying its noise floor (rule of thumb).

Two different targets for two kinds of sound (measured in one production game):

- **Beds and loops** (ambience, music): `Volume = target RMS / measured RMS`, because they are heard continuously.
- **One-shots** (zaps, UI, impacts): `Volume = target peak / measured peak`, because the transient is what you hear.

The project's targets put ambience beds at about 0.004 to 0.018 effective RMS, just under the wind, music at about 0.017 to 0.03, UI clicks at 0.025, rewards at 0.07, and big events at 0.25 to 0.3. Your numbers will differ; the point is to have them written down per category.

## Stage 6: route through buses

Every sound plays through a `SoundGroup` (or an Audio API bus) per category, with effects on the group rather than per sound:

| Bus | Effects (reference project) | Player slider |
|---|---|---|
| Weapon SFX | EQ, compressor, short reverb | SFX |
| Enemy SFX | own bus with crowd caps | SFX |
| Ability / settings SFX | | SFX |
| Music | fades handled by the music controller | Music |
| Ambience beds | 2.5 s cross-fades between zones | Music / ambience |
| UI | 2D, no rolloff | UI or SFX |

Voice management belongs here too: a shared 3D one-shot helper with a cap on live voices (24 in the reference project), per-key minimum gaps (a "spotted" alert at most once per second, a boss bar slam at most once per 8 seconds) and quieter playback for onlookers (0.7x for other players' abilities). Without caps, a crowd fight plays 80 copies of one hit and clips.

## Stage 7: gates

Run these on every change to sound code or tables:

| Gate | Check |
|---|---|
| No unlevelled ids | every literal id in sound code and config exists in the loudness module |
| No banned ids | none of the forbidden list appears anywhere (code, config, attributes) |
| All ids load | the measure pass reports ids that do not load (the reference project found 55 ids that would not load in one font bank) |
| Duplicates | waveform correlation between new and existing ids; the same take uploaded twice wastes quota and confuses the table |
| Volume range | no computed Volume above a ceiling per category (one table kept a per-take ceiling of 1.6) |
| Caps present | every looping sound has a stop path; every frequent cue has a throttle |

```lua
-- Gate: scan script sources for asset ids that are banned or missing from the loudness table.
-- Run from the command bar or a plugin (Script.Source is readable there).
local Loudness = require(game.ReplicatedStorage.AudioLoudness:Clone())
local FORBIDDEN: { [number]: boolean } = {} -- fill from your banned list

local problems = {}
for _, s in game:GetDescendants() do
	if s:IsA("LuaSourceContainer") then
		local ok, src = pcall(function() return (s :: any).Source end)
		if ok and type(src) == "string" then
			for id in string.gmatch(src, "rbxassetid://(%d+)") do
				local n = tonumber(id) :: number
				if FORBIDDEN[n] then table.insert(problems, "BANNED " .. id .. " in " .. s:GetFullName()) end
			end
			for id in string.gmatch(src, "[Ss]ound[%w_]*%s*=%s*(%d%d%d%d%d%d+)") do
				local n = tonumber(id) :: number
				if not Loudness[n] then table.insert(problems, "UNLEVELLED " .. id .. " in " .. s:GetFullName()) end
			end
		end
	end
end
print(#problems == 0 and "audio gate: clean" or table.concat(problems, "\n"))
```

The clone-require at the top matters: in Edit mode `require` returns a cached copy, so after regenerating the table you would otherwise check against the old one.

## Stage 8: listen in Play

Numbers make sounds consistent; only ears make them right. Listen on phone speakers and headphones, in a crowded fight and alone, and apply the reference project's quieting rules: footsteps should not trigger swing accents, idle weapons should not hum over menus, your own weapon goes silent while a full-screen menu is up. Its owner's instruction for a sound pass was "don't put anything where it doesn't belong", and the resulting pass removed a hub ambience bed the same day because it masked the wind.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| One sound far louder than the rest | not in the loudness table | gate: unlevelled ids |
| Sounds feel late | silence before the onset | trim offline or start before the measured onset |
| Levels jump after a re-measure | different measuring method | one method per table, conversion factor documented |
| Removed sound comes back | old notes or code reused | forbidden list checked by the gate |
| Crackling in big fights | too many voices, clipping on the bus | voice caps, throttles, compressor on the bus |
| Zone ambience fights the weather | two beds on one area | one owner per bed, cross-fades |
| Upload quota gone mid-month | one take per role | banks designed for reuse via pitch and regions |

## Checklist

- [ ] Source and rights recorded per id
- [ ] Offline prep: trimmed, faded, normalised, named by role
- [ ] Id map JSON per upload batch
- [ ] Every id measured in Studio with a robust method
- [ ] Loudness module generated, never hand-edited
- [ ] Targets per category written down; beds by RMS, one-shots by peak
- [ ] Buses per category with effects and player sliders
- [ ] Voice caps and per-cue throttles
- [ ] Gates: unlevelled, banned, not loading, duplicates, volume range
- [ ] Listened to in Play on phone and headphones

## See also

[[Sound Fundamentals]] · [[Spatial Audio and Mixing]] · [[Sound Design for Games]] · [[Music and Adaptive Audio]] · [[Asset Upload Automation with Open Cloud]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Batch Processing Tools in Studio]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Combat Sound Design and Feedback]] · Official Docs - Audio · Asset Pipelines · Official Docs - Asset Creation · Captions and Audio Accessibility
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Build Test and Release Pipeline]] · [[Art Pipeline - Concept to In-Game Asset]] · [[UI Asset Pipeline]] · [[Blender Automation with Python]] · [[Character and Creature Pipeline]] · [[Environment and Level Pipeline]] · [[Code Pipeline - Rojo Git and CI]]
<!-- related:end -->
