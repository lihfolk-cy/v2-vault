---
tags: [game-feel, juice, audio, haptics, timing, latency, sync, feedback, luau]
---
# Feedback Timing - Sound Visual and Haptic Sync

An impact is three signals: a picture, a sound and (on some devices) a vibration. When they arrive together the brain fuses them into one event with weight. When they drift apart by more than a few tens of milliseconds the same assets feel cheap, "floaty" or laggy, and nobody can say why. [[Combat Sound Design and Feedback]] covers which sounds play for which outcome and who plays them over the network; [[Captions and Audio Accessibility]] introduces haptics as an accessibility channel. This note is about **time**: how far apart the channels can drift before it shows, where the hidden delays come from on a Roblox client, how to schedule all three from one clock, and how to measure the result.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**, and one broadcast standard where noted.

---

## 1. How much drift is too much

The best-known numbers come from broadcast television. ITU-R BT.1359 puts the **detectability** threshold at about 45 ms with sound **ahead** of the picture and about 125 ms with sound **behind** it, and the wider **acceptability** threshold at about 90 ms ahead and 185 ms behind. The figures come from viewer tests, and sources disagree on the sign convention, so read them as "early sound is noticed about three times sooner than late sound".

The asymmetry has a physical root: in the real world light arrives before sound (sound travels about 343 m/s, so a hit 10 m away is heard about 29 ms after it is seen), and the brain is used to sound being a little late. It is never used to sound being early.

For games, tighten those numbers, because the player **caused** the event and knows exactly when to expect it (rule of thumb):

| Offset (sound relative to the visual impact) | How it reads in a game |
|---|---|
| Sound 20 ms or more **early** | "Something is off", especially on hits; the sound seems to cause the visual |
| 0 to 30 ms late | Fused; the target zone |
| 30 to 80 ms late | Acceptable for big, heavy events (a distant explosion); soft for snappy hits |
| 80 to 150 ms late | Mushy; players describe it as input lag |
| More than 150 ms late | Reads as two separate events |

Haptics are more forgiving in absolute terms (touch is a slower sense and motors take time to spin up), but a vibration clearly after the sound feels like an echo. Aim to have the felt peak of the vibration land within about 30 ms of the visual impact.

The goal is therefore asymmetric: **never early, and late by as little as you can manage**. That shapes everything below. When in doubt, err late.

---

## 2. The hidden delays on a Roblox client

Three delays stack between "the hit happens in your code" and "the player perceives it", and they are different per channel.

### Visual

- Your code changes a property during the frame. It is drawn when that frame renders and appears when the display next refreshes. That is one to two frames in practice: 17 to 33 ms at 60 fps, 33 to 66 ms at 30 fps (rule of thumb).
- Where in the frame you make the change matters. Roblox runs several per-frame events (`PreRender`, `PreAnimation`, `PreSimulation`, `PostSimulation`, `Heartbeat`, per Roblox docs as of October 2026). The docs recommend binding work that must happen after input but before rendering to the render step. A visual change made in a late event of one frame may not be drawn until the next frame, adding up to one frame. For feedback, set the visual in the input handler or in `PreRender`, not in `Heartbeat` (rule of thumb; the docs do not state when a `Heartbeat` change is drawn, so test it if you rely on it).
- With deferred signal behaviour (`Workspace.SignalBehavior`, Roblox docs), event handlers run at the next resumption point instead of immediately. That is still within the frame for most events, but chains of events that each wait for the next can push a visual a frame later than expected.

### Audio

- `Sound:Play()` hands the sound to the audio engine, which mixes in blocks; the block then goes through the device's output path. The engine's own buffering is not documented as a number (unverified); on top of it, device output latency varies enormously by hardware (rule of thumb): wired PC audio is typically tens of ms, many Android phones add more, and **Bluetooth headphones commonly add 100 to 300 ms**.
- **The file itself** is often the biggest delay. Many sound effects start with silence or a soft ramp; the transient that the ear hears as "the hit" may be 20 to 80 ms in. That delay is entirely under your control.
- **Unloaded sounds** play late or not at all the first time. Every `Sound` has `IsLoaded` and a `Loaded` event (Roblox docs); a combat sound that loads on first use is late exactly once, on the first hit the player ever lands, which is the hit that forms their first impression.

### Haptic

- Gamepad rumble motors (eccentric rotating masses) need time to spin up; very short pulses may never reach a feelable intensity (rule of thumb: pulses under about 30 to 40 ms are weak or lost on rumble motors; phone linear actuators respond faster).
- Roblox's newer `HapticEffect` instance has preset types (`UIHover`, `UIClick`, `UINotification`, `GameplayExplosion`, `GameplayCollision`) and custom waveforms set with `SetWaveformKeys` (times in milliseconds, intensities 0 to 1), plus `Play`, `Stop` and an `Ended` event (Roblox docs, as of October 2026). The older `HapticService` (`SetMotor`, `IsVibrationSupported`, `IsMotorSupported`) is marked deprecated in the docs. The docs pages do not list which devices support `HapticEffect`, so treat it as best effort and test on a real controller and a real phone.

### What this adds up to

On a typical 60 fps client with wired audio, an untreated sound effect with a 40 ms soft start lands roughly 40 to 80 ms after the visual: inside "acceptable" but already in "soft for snappy hits". On a phone with Bluetooth earbuds, the same sound is 150 to 350 ms late and the hit feels disconnected. You cannot fix Bluetooth, but you can remove every delay you own, which pulls the typical case into the target zone and makes the bad case less bad.

---

## 3. Fixing the file: onset and peak

Two numbers per sound effect, measured once in an audio editor (rule of thumb):

- **Onset**: the time from the start of the file to the first audible energy (for example, the first sample above -40 dBFS).
- **Peak**: the time from the start of the file to the loudest transient, the moment the ear hears as "now".

Then handle them by sound class:

| Class | Example | Treatment |
|---|---|---|
| Scheduled | Sword impact on a known animation marker, footsteps, combo hits | Start the sound early by `peak` so the peak lands on the visual frame |
| Reactive | Server-confirmed kill, crit sting, pickup | Cannot start early; trim the file so `onset` is under 5 ms and `peak` under 15 ms, or skip the lead-in at play time |
| Bed and tail | Low-health heartbeat, reverb tails | Timing is loose; ignore |

The reference project used the scheduled approach for combat: every sound was keyed to the swing's hit time and started early by its measured onset and peak, so the "crack" of the strike landed on the hit frame (measured in the reference project; the details are in [[Combat Sound Design and Feedback]]).

For reactive sounds where you cannot re-export the file, set `Sound.TimePosition` to the onset before calling `Play()`. That skips the silent lead-in at runtime. It works for one-shot sounds you own; test it on your target devices, because the precision of seeking is not documented (unverified).

### Peaks need a schedule, and a schedule needs a known future

Starting a sound early requires knowing when the impact will happen. Animation markers give you that: the marker's time in the clip is known at cast time, so the impact moment is `castTime + markerTime / speed`. That is why feedback should hang off markers, not off the hit detection event, for your own attacks: hit detection tells you that a hit happened, too late to schedule anything, while the marker tells you ahead of time when it will happen. The hit result then decides which **outcome layers** to add, as reactive sounds ([[VFX Timing with Animation]], [[Combat Sound Design and Feedback]]).

---

## 4. One clock for all channels

The most robust structure is a single **beat**: an event with a timestamp (the moment the impact should be perceived) and a strength, from which every channel schedules itself with its own lead time.

```
beat time T
  visual:  apply at T (flash, hit-stop start, kick)
  audio:   start at T - peak            (scheduled sounds)
  haptic:  start at T - motorLead       (about 20 to 40 ms on rumble motors)
  shake:   start at T + hitStopLength   (after the freeze, see the shake tuning note)
```

If a channel's lead time is already in the past (the beat was announced late), that channel starts **now** with its lead-in skipped rather than late by the full lead. The registry below stores per-sound timing so nobody hard-codes delays at call sites.

```lua
--!strict
-- FeedbackSync: schedule visual, audio and haptic feedback for one beat from one clock.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local FeedbackSync = {}

export type Cue = {
	soundId: string?,      -- rbxassetid://0000000000
	peak: number,          -- seconds from file start to the audible peak
	onset: number,         -- seconds of lead-in silence (skipped when late)
	volume: number,
	haptic: HapticEffect?, -- a prebuilt effect, or nil
	hapticLead: number,    -- seconds to start the haptic early
	visual: ((strength: number) -> ())?,
}

local cues: { [string]: Cue } = {}
local soundPool: { [string]: { Sound } } = {}
local POOL_SIZE = 4
local hapticsEnabled = true
local bluetoothOffset = 0 -- extra seconds of audio lead, set from a player setting

local function makeSound(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	return s
end

function FeedbackSync.register(name: string, cue: Cue)
	cues[name] = cue
	local id = cue.soundId
	if id then
		local list = {}
		for i = 1, POOL_SIZE do
			list[i] = makeSound(id, cue.volume)
		end
		soundPool[name] = list
		-- Load now, not on the first hit. PreloadAsync yields, so do it in a thread.
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
	end
end

function FeedbackSync.setHapticsEnabled(on: boolean)
	hapticsEnabled = on
end

-- Shifts scheduled sounds earlier for players who say they use wireless audio (0 to 0.25 s).
function FeedbackSync.setAudioLead(seconds: number)
	bluetoothOffset = math.clamp(seconds, 0, 0.25)
end

local function freeSound(name: string): Sound?
	local list = soundPool[name]
	if not list then
		return nil
	end
	for _, s in list do
		if not s.IsPlaying then
			return s
		end
	end
	return list[1] -- steal the first voice rather than skipping the impact
end

local function playSound(name: string, cue: Cue, lateBy: number)
	local s = freeSound(name)
	if not s then
		return
	end
	-- If we are late, skip the silent lead-in (and as much of the ramp as we are late, up to the peak).
	s.TimePosition = math.clamp(cue.onset + lateBy, 0, cue.peak)
	s:Play()
end

-- Schedule a beat whose impact should be perceived at clock time `impactAt` (os.clock based).
function FeedbackSync.beat(name: string, impactAt: number, strength: number)
	local cue = cues[name]
	if not cue then
		return
	end
	local now = os.clock()

	if cue.soundId then
		local startAt = impactAt - (cue.peak - cue.onset) - bluetoothOffset
		local wait = startAt - now
		if wait > 0 then
			task.delay(wait, playSound, name, cue, 0)
		else
			playSound(name, cue, -wait)
		end
	end

	local haptic = cue.haptic
	if haptic and hapticsEnabled then
		local wait = impactAt - cue.hapticLead - now
		if wait > 0 then
			task.delay(wait, function()
				haptic:Play()
			end)
		else
			haptic:Play()
		end
	end

	local visual = cue.visual
	if visual then
		local wait = impactAt - now
		if wait > 0 then
			task.delay(wait, visual, strength)
		else
			visual(strength) -- never later than now; a late visual is the worst case
		end
	end
end

return FeedbackSync
```

Notes on this design:

- **The visual is the anchor**, and it is never delayed beyond its scheduled time. Audio and haptics move relative to it.
- **`task.delay` resolution** is one frame: a delayed callback runs at the next resumption point after the time has passed. That means scheduled audio can be up to a frame late, which is the safe direction. Do not try to correct it by starting earlier; early is worse than late.
- **Pools of four voices per cue** avoid cutting off a sound with its own repeat on fast combos; global voice limits and priority stealing are in [[Combat Sound Design and Feedback]].
- **The audio lead setting** lets players with wireless headphones shift scheduled sounds earlier. It cannot help reactive sounds. Rhythm games offer a calibration screen for this; action games rarely do, but a simple "Wireless audio" toggle that sets 0.15 s is cheap (rule of thumb value; real Bluetooth latency varies widely).

The `HapticEffect` objects passed in should be built once at startup (type, waveform, parent) and reused. The docs' samples parent them to `Workspace` before playing (Roblox docs, as of October 2026); the accessibility note parents them under `PlayerGui`. Which parents are valid is not stated on the reference page, so test the parent you choose on real hardware.

---

## 5. Haptic patterns that carry meaning

Vibration is low bandwidth: players can tell apart only a handful of patterns (rule of thumb: three to five). Spend them on meaning, not decoration.

| Meaning | Pattern (rule of thumb) | Preset that may fit |
|---|---|---|
| UI confirm | One short tick, 20 to 40 ms, light | `UIClick` |
| Hit landed (yours) | One medium pulse, 50 to 80 ms | `GameplayCollision` |
| Heavy hit or explosion near you | Strong attack, 150 to 300 ms decay | `GameplayExplosion` |
| Warning (attack incoming) | Rising ramp, 250 to 400 ms | `Custom` waveform |
| Damage taken | Two quick pulses | `Custom` |
| Reward | A short rising triple | `Custom` or `UINotification` |

Rules (rule of thumb):

- **Rate limit.** No more than about 8 to 10 haptic starts per second; at higher rates pulses smear into a constant buzz and drain batteries.
- **Never haptics on idle loops.** A looping vibration while the player does nothing is the fastest way to get the setting turned off.
- **Scale by strength, but quantise.** Three intensity levels are distinguishable; a continuous scale is not.
- **Own setting.** Haptics need their own on/off (and ideally intensity) setting, separate from camera shake. Some players want shake off and rumble on, or the reverse.

---

## 6. Other players' events: late by design

For your own actions you control the schedule. For other players' actions you learn about them from the server, already one network trip late. Three rules (rule of thumb):

1. **Include a server timestamp** in cosmetic events (`workspace:GetServerTimeNow()` on both sides gives a shared clock, per Roblox docs). The receiver computes how late it is.
2. **Skip what is already in the past.** If an onlooker impact arrives 180 ms after its time, play the impact transient (skipping its lead-in) and the visual now; skip the wind-up whoosh, which would now play after the impact.
3. **Drop what is stale.** Cosmetic events older than about 0.5 s are better dropped than played; a hit sound half a second after the enemy died reads as a bug.

This is also why onlooker impacts are a good fit for `UnreliableRemoteEvent`: an event that arrives late or not at all is equally harmless ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

---

## 7. Measuring sync

You cannot tune what you cannot see. Two methods that work without special tools (rule of thumb):

**The video method.** Record the screen and the device's audio together with a phone or camera filming the device (not screen capture, which bypasses output latency). Import into any video editor, find the frame where the flash appears, and read the audio waveform at that point. Measure the gap between the flash frame and the transient. At 60 fps recording, accuracy is about plus or minus 17 ms; at 240 fps slow motion, about 4 ms.

**The debug beat.** Add a test command that fires a beat every second with a full-screen white flash and a sharp click. Watching and listening for a minute makes drift obvious, and it makes regressions obvious when someone replaces a sound file with one that has a long lead-in.

What to measure:

| Case | Target |
|---|---|
| Own hit, wired audio, 60 fps | Sound 0 to 30 ms after the visual |
| Own hit, phone speaker, 30 fps | Sound 0 to 60 ms after |
| Reactive confirm (server) | Sound within 30 ms of its visual (both are late together; that is fine) |
| Onlooker impact | Visual and sound together; absolute delay irrelevant |
| Haptic | Felt peak within about 30 ms of the visual |

---

## 8. When perfect sync is not the goal

- **Distant events** can deliberately delay sound by distance / 343 seconds for realism. Players accept it for thunder and far explosions, and it helps sell scale. Cap it (about 0.3 s) so it never feels like lag.
- **Wind-ups and telegraphs** should **lead** the danger, not sync with it ([[Combat Sound Design and Feedback]] budgets 0.5 to 0.8 s).
- **Tails** (reverb, debris, echoes) run on after the impact by design; sync only the transient.
- **Reward sequences** often put the sound slightly **before** the visual reveal on purpose (a riser that peaks as the item appears) because anticipation is the point; see [[Reward Moments and Celebrations]].

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Hits feel floaty with good assets | Sound files have 30 to 80 ms lead-ins | Measure onset and peak; schedule early or trim |
| First hit of the session is silent or late | Sound not loaded | Preload combat sounds; pool instances |
| Sound seems to cause the visual | Scheduled too early (over-corrected) | Never early; err late |
| Feedback lags a frame inconsistently | Visual set in a late per-frame event | Set visuals in the input handler or `PreRender` |
| Rumble does nothing on light hits | Pulses shorter than motor spin-up | Minimum 40 ms; start slightly early |
| Onlooker whoosh after the impact | Late event plays its whole sequence | Server timestamp; skip past parts, drop stale |
| Players on earbuds say combat feels laggy | Bluetooth output latency | Optional audio lead setting for scheduled sounds |

## Checklist

- [ ] Every combat sound has measured onset and peak in its registry entry.
- [ ] Scheduled sounds start early by their peak; reactive sounds are trimmed or skip their lead-in.
- [ ] Combat sounds are preloaded and pooled.
- [ ] Visuals are the anchor and are never delayed; audio and haptics move relative to them.
- [ ] Haptics: few distinct patterns, rate-limited, own setting, tested on real hardware.
- [ ] Cosmetic network events carry server time; late parts skipped, stale events dropped.
- [ ] Sync measured with a filmed recording on a phone and a PC.
- [ ] A debug beat exists to catch regressions when assets change.

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · [[Hit-Stop]] · [[Sound Design for Games]] · [[Sound Fundamentals]] · [[Audio Pipeline]] · [[Camera Shake and Camera FX]]
<!-- auto-links:end -->
