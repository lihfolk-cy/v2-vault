---
tags: [accessibility, captions, subtitles, audio, deaf, hard-of-hearing, haptics, volume, localization, type/guide, area/accessibility, level/intermediate]
---
# Captions and Audio Accessibility

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Subtitles without speaker names.
> - Avoid: Sound captions for noise, none for threats.
> - Avoid: Captions that cover touch controls or the hotbar on phones.
> - Subtitles with speaker names; sound captions for information-bearing sounds only.
> - Two to three lines at most; reading time at least 1.5 s; merged repeats; priorities.
> - Captions sized by player setting, on a plate that respects `PreferredTransparency`.
>
> Cost: TL;DR ~150 tok · whole note ~5.3k tok. Read more: ## 4. A caption service · ## 7. Haptics as a third channel · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Accessibility]] states the rule: every important sound needs a visual. This note builds the systems behind it: a caption service that handles dialogue subtitles and sound captions with speaker labels, timing, queueing and direction; a directional sound indicator for threats you hear but cannot see; volume categories that actually separate speech from music; haptics as a third channel; and the places where Roblox gives you nothing and you have to build it yourself.

Sources: **Roblox docs (as of October 2026)** for `HapticEffect`, `HapticService`, `AudioTextToSpeech`, `AudioAnalyzer` and the accessibility guidelines; common subtitling practice (**rule of thumb**) for timing and layout; **measured in the reference project** where noted.

---

## 1. Who this serves and what they miss

- **Deaf and hard-of-hearing players.** They miss dialogue, off-screen threats, timing cues (a wind-up sound before an attack), and feedback (a "ready" chime).
- **Players with sound off.** On Roblox this is a large group: phones on silent, players in class or on public transport, players listening to their own music. Rule of thumb: assume a large share of mobile sessions are muted and design as if every session might be.
- **Players with auditory processing difficulties.** They hear the sound but struggle to separate speech from music and effects. Volume categories and clear mixing help them more than captions.
- **Players in noisy places** and players who do not speak the voice-over language.

Roblox docs (as of October 2026) recommend pairing in-game events conveyed by sound with visual cues, and giving players separate volume controls for groups such as sound effects, music and speech. Docs do not describe a built-in captioning system for in-experience audio that I could find, so captions are yours to build.

---

## 2. Two kinds of caption

| Kind | What it shows | Example |
|---|---|---|
| Subtitle | Spoken words, with the speaker | **Captain:** The gate opens at dawn. |
| Sound caption (closed caption) | A meaningful non-speech sound, described | [Explosion behind you] [Boss roars] [Door unlocks] |

Most games ship subtitles only. For deaf players, sound captions are often more important for play: dialogue is story, but "[Footsteps, left]" is survival. Caption only sounds that carry information. Ambient birds, UI clicks and every footstep of every NPC should not be captioned; a caption track full of noise is as useless as none.

### Choosing what to caption

A practical filter (rule of thumb): caption a sound if a hearing player would **change what they do** because of it, or would **learn something** from it that is not visible on screen. That includes:

- Off-screen threats and enemy wind-ups
- Story beats and speech
- State changes that are mostly audible (a generator starting, a timer about to end, a door unlocking elsewhere)
- Music changes that signal something (boss music starting means a boss spawned)

---

## 3. Caption style and timing

Common subtitling practice (rule of thumb) translated to Roblox screens:

| Rule | Value |
|---|---|
| Lines on screen at once | 2, at most 3 |
| Characters per line | About 40 on phones, up to about 60 on desktop |
| Minimum display time | 1.5 s even for short lines |
| Reading time | About 0.06 s per character plus 0.5 s, clamped between 1.5 s and 7 s |
| Position | Bottom centre, above the mobile thumb zones and the hotbar; never under touch controls |
| Background | A plate behind the text, opacity adjustable, respecting `PreferredTransparency` ([[Accessibility]]) |
| Speaker | Name prefix, optionally a speaker colour (never colour alone, see [[Colour-Blind Safe Design]]) |
| Sound captions | In square brackets, short, present tense |
| Size | Player-adjustable, with a default at or above body text ([[Readable Text and UI Scale]]) |

Reading time matters more on Roblox than in films because many players are young readers. The formula above is deliberately slow. When a line comes from audio with a known length, show the caption for the longer of the audio length and the reading time.

### Speaker colours and names

Give recurring speakers a consistent name and, if you want, a consistent colour. Name first: a colour-only speaker cue fails colour-blind players. Unnamed speakers should still be labelled ("Guard:", "Voice on radio:"). For player-voiced lines you do not caption (voice chat), see section 8.

---

## 4. A caption service

The service below is client-side, because captions are presentation. The server tells clients what happened (a boss roared, an NPC spoke a line by key) through the events your game already sends; the client decides whether and how to caption. Keeping captions client-side avoids extra remotes and lets each player's settings apply.

```lua
--!strict
-- Captions: client-side caption queue for subtitles and sound captions.
local Workspace = game:GetService("Workspace")

export type Kind = "Speech" | "Sound"
export type Cue = {
	kind: Kind,
	text: string, -- already localised
	speaker: string?, -- Speech only
	worldPos: Vector3?, -- Sound only; enables direction text
	priority: number, -- higher shows first; 0 ambient, 5 normal, 10 critical
	minTime: number?, -- override for known audio length
}

type Active = { cue: Cue, label: TextLabel, expires: number, count: number, key: string }

local Captions = {}

local MAX_LINES = 3
local settings = { enabled = true, sounds = true, directions = true, textSize = 20 }

local container: Frame -- set in Captions.mount
local active: { Active } = {}

local function readTime(text: string): number
	return math.clamp(0.5 + #text * 0.06, 1.5, 7)
end

local function directionWord(worldPos: Vector3): string?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local rel = camera.CFrame:PointToObjectSpace(worldPos)
	local flat = Vector3.new(rel.X, 0, rel.Z)
	if flat.Magnitude < 4 then
		return nil -- too close for direction to matter
	end
	local angle = math.deg(math.atan2(rel.X, -rel.Z)) -- 0 = ahead, +90 = right
	if math.abs(angle) <= 35 then
		return "ahead"
	elseif math.abs(angle) >= 145 then
		return "behind"
	end
	return if angle > 0 then "right" else "left"
end

local function format(cue: Cue, count: number): string
	if cue.kind == "Speech" then
		local who = cue.speaker or "Unknown"
		return `<b>{who}:</b> {cue.text}`
	end
	local text = cue.text
	if settings.directions and cue.worldPos then
		local dir = directionWord(cue.worldPos)
		if dir then
			text ..= `, {dir}`
		end
	end
	if count > 1 then
		text ..= ` x{count}`
	end
	return `[{text}]`
end

local function layout()
	table.sort(active, function(a, b)
		if a.cue.priority ~= b.cue.priority then
			return a.cue.priority > b.cue.priority
		end
		return a.expires < b.expires
	end)
	for i, entry in active do
		entry.label.LayoutOrder = i
		entry.label.Visible = i <= MAX_LINES
	end
end

local function makeLabel(): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.RichText = true
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.TextSize = settings.textSize
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(640, math.huge)
	maxWidth.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = label
	label.Parent = container
	return label
end

function Captions.show(cue: Cue)
	if not settings.enabled or (cue.kind == "Sound" and not settings.sounds) then
		return
	end
	local now = os.clock()
	local duration = math.max(readTime(cue.text), cue.minTime or 0)
	local key = `{cue.kind}|{cue.speaker or ""}|{cue.text}`

	-- Merge repeats of the same sound caption instead of stacking lines.
	for _, entry in active do
		if entry.key == key and cue.kind == "Sound" then
			entry.count += 1
			entry.expires = now + duration
			entry.cue = cue -- refresh position for direction
			entry.label.Text = format(cue, entry.count)
			layout()
			return
		end
	end

	-- Drop the lowest-priority line if full and the new cue outranks it.
	if #active >= MAX_LINES * 2 then
		local lowest = active[#active]
		if lowest.cue.priority > cue.priority then
			return
		end
		lowest.label:Destroy()
		table.remove(active)
	end

	local label = makeLabel()
	label.Text = format(cue, 1)
	table.insert(active, { cue = cue, label = label, expires = now + duration, count = 1, key = key })
	layout()
end

function Captions.configure(new: { enabled: boolean?, sounds: boolean?, directions: boolean?, textSize: number? })
	if new.enabled ~= nil then settings.enabled = new.enabled end
	if new.sounds ~= nil then settings.sounds = new.sounds end
	if new.directions ~= nil then settings.directions = new.directions end
	if new.textSize then
		settings.textSize = math.clamp(new.textSize, 14, 40)
		for _, entry in active do
			entry.label.TextSize = settings.textSize
		end
	end
end

function Captions.mount(parent: Frame)
	container = parent
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0, 4)
	list.Parent = parent

	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local changed = false
			for i = #active, 1, -1 do
				if active[i].expires <= now then
					active[i].label:Destroy()
					table.remove(active, i)
					changed = true
				end
			end
			if changed then
				layout()
			end
		end
	end)
end

return Captions
```

How it is meant to be used:

- **Mount once** into a `Frame` in a `ScreenGui` positioned bottom centre, above your HUD's bottom row and clear of touch controls ([[Safe Areas and Insets]]).
- **Text is localised before it reaches the service.** Store caption strings as localisation keys next to the dialogue and sound definitions, translate with your translator (see [[Localization]]), then call `show`. Sound caption strings are short and translate well; keep them in the same table as the sound so they cannot drift apart.
- **Speech captions come from your dialogue system.** If you use the one in [[Dialogue System End to End]], call `Captions.show` from the same place that plays the voice line, with `minTime` set to the audio length.
- **Sound captions come from your sound play helper.** Every gameplay sound should already go through one function (for throttling and pooling, see [[Spatial Audio and Mixing]]). Add an optional `caption` field to the sound definition and let the helper call `Captions.show`. Sounds with no caption field are not captioned, which is the right default.
- **Merging** turns ten gunshots into "[Gunfire, left] x10" rather than ten lines.
- **Priority** keeps "[Boss roars, behind]" visible when ambient captions pile up.

Rich text is used for the speaker name in bold. If a caption text can contain player-written content (a player's name in a line), escape it for rich text first or the markup breaks ([[Text Fonts and Rich Text]]).

---

## 5. Directional sound indicators

Direction words in captions help, but in fast combat a visual indicator around the screen centre is faster to read: a short arc or arrow pointing toward the source, fading over a second. Shooters have popularised this for footsteps and gunfire (rule of thumb: many players with full hearing turn it on too, because stereo on phone speakers is poor).

The angle calculation is the same as `directionWord` above: transform the source into camera space with `PointToObjectSpace`, then `atan2(rel.X, -rel.Z)` gives the angle from straight ahead, positive to the right. Place an arrow image on a ring around the screen centre at that angle, rotate it to point outward, and fade it by distance and age. Key choices:

- **What triggers it:** only sounds that matter for play (enemy footsteps within a radius, gunfire, wind-ups). Not friendly footsteps, not ambient.
- **Distance encoding:** opacity or size, never colour alone.
- **Vertical sources:** for sounds well above or below, add a small up or down chevron; a ring indicator alone is ambiguous in multi-floor maps.
- **Competitive fairness:** if the game is competitive, a sound indicator is information. Either give it to everyone as a setting (fair) or make it reveal only what a hearing player could hear at the same distance with the same occlusion. Do not make it reveal more than the audio does, or it becomes a wallhack that everyone turns on.

---

## 6. Volume categories that work

Docs recommend separate volume controls for groups such as sound effects, music and speech (Roblox docs, as of October 2026). For players with auditory processing difficulties the most valuable control is turning music down while keeping speech and important effects up.

Implementation depends on which audio system you use ([[The Audio API - Players Emitters Wires and Effects]]):

- **Classic `Sound` objects:** route every sound to one of a few `SoundGroup`s (Music, Effects, Speech, UI, Ambient) and set each group's `Volume` from the player's setting.
- **Audio API:** route each category's wires through its own fader on a bus, and set that fader's volume from the setting.

Design notes:

- **Five categories is the useful maximum.** Music, effects, speech, UI, ambient. Fewer is fine; more becomes noise in the settings menu.
- **Ducking is an accessibility feature.** Automatically lowering music and ambient while speech plays (see [[Spatial Audio and Mixing]]) helps everyone parse dialogue. Make the duck stronger for speech than for effects.
- **A "speech clarity" preset** (music 30%, ambient 40%, speech 100%) is a one-tap option for players who do not want to tune five sliders.
- **Mono audio.** Players with hearing loss in one ear miss sounds panned to the other side. Some platforms provide a system-level mono switch. I could not confirm an engine setting on Roblox that downmixes game audio to mono, so the in-game fallback is the directional indicator and captions, which carry the left/right information visually.
- **Save the values** with the player's other settings so they follow them across devices.

---

## 7. Haptics as a third channel

Vibration carries timing and impact information without sound or sight. On Roblox (as of October 2026), docs say `HapticService` has been superseded by `HapticEffect`, which supports waveform-based effects, looping, spatial attenuation and preset effect types. `Enum.HapticEffectType` lists `Custom`, `UIHover`, `UIClick`, `UINotification`, `GameplayExplosion` and `GameplayCollision`. A `HapticEffect` has `Type`, `Looped`, `Position` and `Radius`, methods `Play`, `Stop` and `SetWaveformKeys`, and an `Ended` event (Roblox docs, as of October 2026). Which devices support it was not stated on the reference page I checked.

```lua
--!strict
-- A pooled haptic cue for "attack incoming", used alongside a caption and a visual telegraph.
local hapticFolder = Instance.new("Folder")
hapticFolder.Name = "Haptics"
hapticFolder.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local windUp = Instance.new("HapticEffect")
windUp.Type = Enum.HapticEffectType.Custom
-- Times in milliseconds, intensities 0..1 (Roblox docs, as of October 2026).
windUp:SetWaveformKeys({
	FloatCurveKey.new(0, 0, Enum.KeyInterpolationMode.Linear),
	FloatCurveKey.new(250, 0.6, Enum.KeyInterpolationMode.Linear),
	FloatCurveKey.new(400, 0, Enum.KeyInterpolationMode.Linear),
})
windUp.Parent = hapticFolder

local Haptics = {}

local enabled = true

function Haptics.setEnabled(on: boolean)
	enabled = on
end

function Haptics.attackIncoming()
	if enabled then
		windUp:Play()
	end
end

return Haptics
```

Parenting the effect somewhere it can play on the client matters; I could not confirm from the reference page which parents are valid, so test this on a real controller and a real phone before relying on it. Treat haptics as optional reinforcement: many players have no haptic device, and some find vibration uncomfortable, so it must have its own on/off and intensity setting.

---

## 8. Other audio surfaces

### Voice chat

Players who are deaf or who cannot use a microphone are excluded from voice-heavy social play. Keep text chat available alongside voice, and never put gameplay coordination only in voice (for example, a puzzle that requires spoken callouts). Roblox's text chat features, including translation for players who enable it, are covered in [[Text Chat Customization with TextChatService]].

### Music that carries information

Rhythm sections, music-cue puzzles and "the music changes when the monster is near" mechanics all depend on hearing. Add a visual equivalent: a beat indicator, a tension meter, a vignette that tightens. `AudioAnalyzer` exposes `RmsLevel`, `PeakLevel` and a spectrum through `GetSpectrum` in the Audio API (Roblox docs, as of October 2026), which you can use to drive a simple visual pulse from the music actually playing, rather than authoring a separate beat track. For gameplay-critical timing, author the beats as data instead; analysis is good for decoration, not for rules.

### Text to speech for the reverse case

Players with low vision or reading difficulties benefit from hearing text read aloud. `AudioTextToSpeech` exists in the Audio API with `Text`, `VoiceId`, `Speed`, `Pitch` and `Volume`, a yielding `LoadAsync`, and `Play` (Roblox docs, as of October 2026). The reference page did not state text length limits, rate limits, filtering requirements or beta status, so check those before building on it. A reasonable first use is an optional "read quest text aloud" button, not automatic narration of everything.

---

## 9. When not to do this

- **Do not caption everything.** Captioning ambient and UI sounds buries the important captions.
- **Do not put captions where they cover the action.** Bottom centre is the convention because it is usually the least important area of a third-person view; in a game where the bottom of the screen matters (a platformer looking down), move them up.
- **Do not make captions the only fix.** Sound-only mechanics (a monster that is only audible) still need visual design changes, not just a caption.
- **Do not auto-enable sound captions for everyone.** Subtitles on by default is reasonable (many players read along); sound captions are better as an opt-in with a clear prompt in the first session.

---

## 10. Testing

- Play a full session muted. List every moment you were surprised, confused or killed by something you would have heard.
- Turn captions on and check that each item on that list now has a caption or a visual.
- Check a busy fight: are there more than three caption lines? Are repeats merging?
- Check captions at the largest text size on a phone ([[Readable Text and UI Scale]]).
- Check the volume categories: music at 0, speech at 100, and confirm no dialogue is mixed into the music channel.

---

## Common mistakes

- Subtitles without speaker names.
- Sound captions for noise, none for threats.
- Captions that cover touch controls or the hotbar on phones.
- A caption per gunshot instead of a merged count.
- Captions that disappear before a young reader can finish them.
- Dialogue routed into the music group, so turning music down removes speech.
- A sound indicator that reveals more than the audio would.
- Haptics with no off switch.

## Checklist

- [ ] Subtitles with speaker names; sound captions for information-bearing sounds only.
- [ ] Two to three lines at most; reading time at least 1.5 s; merged repeats; priorities.
- [ ] Captions sized by player setting, on a plate that respects `PreferredTransparency`.
- [ ] Caption strings localised alongside the sounds and lines they describe.
- [ ] Optional directional indicator, fair in competitive modes.
- [ ] Separate volume for music, effects, speech (and optionally UI and ambient), saved.
- [ ] Haptics through `HapticEffect`, with an on/off and tested on real devices.
- [ ] A muted playthrough leaves no surprise deaths.

See also: [[Accessibility Start Here]], [[Accessibility]], [[Sound Design for Games]], [[Spatial Audio and Mixing]], [[The Audio API - Players Emitters Wires and Effects]], [[Combat Sound Design and Feedback]], [[Music and Adaptive Audio]], [[Dialogue System End to End]], [[Localization]], [[Motion Sensitivity and Camera Comfort]].

## Connected notes
<!-- auto-links:start -->
[[AI Audio - Voice Music and SFX]] · Voice Chat and Safety Features · Feedback Timing - Sound Visual and Haptic Sync · Audio Pipeline · Sound Fundamentals · Resource Library - Audio
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Voice Chat and Safety Features]] · [[Feedback Timing - Sound Visual and Haptic Sync]] · [[Audio Mixer Settings with SoundGroups]] · [[Audio Pipeline]] · [[Difficulty Options and Cognitive Load]] · [[Input Remapping and One-Handed Play]]
<!-- related:end -->
