---
tags: [ai, audio, tts, music, sfx, licensing, type/guide, area/ai, level/intermediate, area/audio]
---
# AI Audio - Voice Music and SFX

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Free-tier generated music in a monetised game.
> - Avoid: Assuming a later subscription licenses audio made earlier.
> - Avoid: Asking an AI for sound ids.
> - Terms checked for the plan used at generation time; copy saved.
> - Every uploaded id recorded by script; none invented.
> - Loudness measured; every id has a levelling entry.
>
> Cost: TL;DR ~130 tok · whole note ~3.6k tok. Read more: ## 1. Roblox's own speech APIs · ## 2. External AI audio tools · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI audio covers three different jobs: speech (text-to-speech and voice conversion), music, and sound effects. Roblox now has its own runtime speech APIs, and a large market of external tools generates all three. The technical part is easy. The hard parts are licensing, loudness consistency, and fitting generated sound into a mix. This note covers Roblox's speech APIs, external tools and their licensing traps, Roblox's upload rules, and how the reference project got 22 new weapon sound banks without any generative model at all.

Engine background: [[Sound Fundamentals]], [[The Audio API - Players Emitters Wires and Effects]], [[Sound Design for Games]], [[Audio Pipeline]]. Products and terms as of October 2026; they change often.

---

## 1. Roblox's own speech APIs

### Text-to-speech

Announced as a beta on the DevForum on 30 June 2025 ("Text-to-Speech API: From text to voice content instantly"). Two forms:

| API | What it does | Saved? |
|---|---|---|
| `AudioTextToSpeech` (instance) | Generates speech in real time and plays it through the audio graph | No, plays and is gone |
| `GenerateSpeechAsset` | Generates speech and saves it to the experience owner's audio inventory | Yes, reusable in the owner's experiences |

From the announcement:
- **300 characters per request** for both. Split longer text.
- **10 preset English voices**, chosen with `VoiceId` strings "1" to "10" (British, US, Australian male and female voices and two "retro" voices). Pitch and speed can be adjusted.
- **English only** at launch; more languages planned.
- **Rate limit**: maximum requests per second = 1 + 0.05 x (concurrent users in thousands). `GenerateSpeechAsset` also counts against your audio upload quota.
- **Moderation**: all text is filtered before processing and generated audio is moderated. Violating text returns an error and no audio. For `AudioTextToSpeech`, creators are not held responsible for rare violating outputs unless they deliberately program them. For `GenerateSpeechAsset`, moderation applies to the account that owns the asset, and Roblox advises against letting players enter text for asset generation.
- **Cost**: baseline use free during the beta, with paid extra usage planned through Roblox's extended services.

A later DevForum post titled "Text-to-Speech API Full Release" exists; its details were not verified for this note. Check it for changes to limits and languages.

The `AudioTextToSpeech` class (reference, October 2026) has `Text`, `VoiceId`, `Pitch`, `Speed`, `PlaybackSpeed`, `Volume`, `Looping`, `TimePosition`, read-only `TimeLength` and `IsLoaded`, methods `LoadAsync()` (yields, returns `Enum.AssetFetchStatus`), `Play()`, `Pause()`, `Unload()`, `GetWaveformAsync`, and the `Ended` event. It is part of the wire-based audio API, so it must be wired to an output.

```lua
--!strict
-- Client: speak a short line from an NPC's head, spatialised.
-- Needs an AudioListener for the local player (the default listener setup covers this;
-- see the Audio API note).
local function speak(head: BasePart, text: string, voiceId: string)
	local tts = Instance.new("AudioTextToSpeech")
	tts.Text = string.sub(text, 1, 300) -- documented per-request limit
	tts.VoiceId = voiceId -- "1".."10"

	local emitter = head:FindFirstChildOfClass("AudioEmitter") or Instance.new("AudioEmitter")
	emitter.Parent = head

	local wire = Instance.new("Wire")
	wire.SourceInstance = tts
	wire.TargetInstance = emitter
	wire.Parent = tts
	tts.Parent = head

	local status = tts:LoadAsync()
	if status ~= Enum.AssetFetchStatus.Success then
		warn("TTS failed:", status)
		tts:Destroy()
		return
	end
	tts.Ended:Once(function()
		tts:Destroy()
	end)
	tts:Play()
end
```

Design notes:
- Real-time TTS adds latency (generation plus loading). Start it as soon as you know the line, not when the subtitle appears.
- Always show subtitles. TTS clarity varies, players may have audio off, and accessibility matters ([[Accessibility]]).
- Preset voices are recognisable across many games. For a signature character, record or license a real voice and keep TTS for dynamic lines.

### Speech-to-text

`AudioSpeechToText` converts audio (typically a player's microphone through `AudioDeviceInput`) into text. It was released as a beta with usage dashboards; use cases listed include voice commands, subtitles and voice-driven NPC conversations. You must enable the microphone under Game Settings > Communication, which by default also turns on voice chat; if you do not want the speech broadcast to other players, disconnect the player's `AudioDeviceInput` from its emitter or turn off `VoiceChatService.EnableDefaultVoice`. A rate formula based on concurrent users was reported in search results (1 + 5 x concurrent users per minute) but not confirmed on the official page; check the class reference. Any recognised text you display or feed into other systems should be treated as player text: filter it. Voice-driven AI interactions count as players triggering AI responses for the maturity questionnaire ([[Roblox Policies on AI-Generated Content]]).

---

## 2. External AI audio tools

| Kind | Examples (October 2026) | Use | Main risk |
|---|---|---|---|
| Text-to-speech and voice design | ElevenLabs and many others | Narration, NPC barks, trailers | Plan terms; cloning real voices |
| Music generators | Suno, Udio and others | Placeholder and ambient music | Commercial rights, ongoing litigation, ownership terms |
| SFX generators | ElevenLabs sound effects and others | Quick sound ideas, ambience | Consistency, licence |
| Stem separation and cleanup | Various | Cleaning recordings | Rights to the source |

### Licensing: the part that decides everything

Summaries below come from vendor pages and third-party summaries found in October 2026. They are a reason to check, not a substitute for reading the current terms.

- **ElevenLabs**: third-party summaries consistently report that free-plan output may not be used commercially and that commercial rights start at the first paid tier. Whether rights persist for audio made after a subscription ends is described differently by different sources. Check the current terms.
- **Suno**: free-plan songs are restricted to non-commercial use, and a later subscription does not retroactively license them; songs made during an active paid subscription come with commercial use rights. After Warner Music Group settled with and partnered with Suno (25 November 2025), sources describe the terms as moving from "ownership" towards a granted licence; other major labels were reported as still litigating. Check the current terms.
- **Music in general**: generated music sits in an area with active lawsuits. For a monetised game, prefer tracks with clear commercial terms, or Roblox's licensed library through the Creator Store ([[Music and Adaptive Audio]]).

Questions to answer for every tool:
1. Is commercial use allowed on the plan you used when generating (not the plan you have now)?
2. Does it require attribution, and where?
3. Do you own the output, or hold a licence? Can the vendor reuse it?
4. Are there restrictions on voice cloning or on using output to train other models?

### Voices of real people

Do not clone or imitate a real person's voice without their written consent. Beyond the vendor's own rules and the law in many places, impersonation breaks Roblox's Community Standards. For a voice actor you hire, put AI use (cloning, generating new lines from their voice) explicitly in the contract.

---

## 3. Roblox upload rules for audio (any origin)

From the Roblox audio assets documentation, October 2026:

| Rule | Value |
|---|---|
| Import limit | 2,000 audio assets per 30 days for ID-verified accounts; 100 for unverified |
| Max duration | 7 minutes |
| Max file size | 20 MB |
| Formats | `.mp3`, `.ogg`, `.wav`, `.flac`; one track or stream per file |
| Sample rate | 48 kHz or lower |
| Channels | Mono, stereo, 3.0 or 5.1 |
| Privacy | Private by default; grant use to specific experiences |
| Rights | The uploader must have the legal rights to the audio |

Uploads are moderated and classified as sound effects or songs. AI origin changes none of this: you need the rights, and the audio must follow the rules.

**Never invent sound ids.** An AI asked for "a sword swoosh sound id" will happily produce a number. It is either nothing, someone else's private asset, or something unexpected. The reference project's rule: only ids already uploaded by the project, and a list of forbidden ids (removed takes) checked by its build tools.

---

## 4. The reference project: procedural sound, not generative AI

For 22 new weapons the reference project needed new sound banks (swings, impacts, charge-ups, ultimates). Instead of generating them with an AI audio model, an AI agent wrote a small Python synthesiser and per-weapon "bank" scripts: layered oscillators, noise bursts, filtered sweeps and envelopes, rendered to files. The agent then uploaded them with a script, recorded the returned ids in a JSON file per batch, and measured each sound's loudness into a per-sound levelling table the game reads at runtime.

Why this worked:
- **No licensing question.** The project wrote the synth; it owns the output.
- **Consistency.** Every bank came from the same building blocks, so they sat together in the mix.
- **Repeatable.** Change a parameter and re-render the whole bank in seconds.
- **Verifiable.** Loudness is a number. A sound without a levelling row played unlevelled, so "every new id has a loudness row" became a checked rule.

The limitation is taste: synthesised sounds suit energy, magic and sci-fi weapons better than realistic steel or voices. Realistic sounds still came from existing licensed banks already in the game.

### Levelling at runtime

```lua
--!strict
-- A per-sound loudness table measured offline (dB relative to the house target).
-- Keys are sound asset ids (placeholders here).
local LOUDNESS_DB: { [string]: number } = {
	["rbxassetid://0000000000"] = -3.5, -- measured 3.5 dB hotter than target: turn down
	["rbxassetid://0000000001"] = 2.0,  -- quieter than target: turn up
}

local function dbToGain(db: number): number
	return 10 ^ (db / 20)
end

local function levelledVolume(soundId: string, baseVolume: number): number
	local offset = LOUDNESS_DB[soundId]
	if offset == nil then
		warn("no loudness row for", soundId) -- surfaces unlevelled sounds in testing
		return baseVolume
	end
	return baseVolume * dbToGain(-offset)
end
```

Measure offline with a loudness meter (integrated LUFS for longer sounds, short-term or peak for one-shots); pick one house target and stick to it. See [[Spatial Audio and Mixing]].

---

## 5. Making generated audio fit

1. **Trim and fade.** Generated SFX often have silence or tails. Trim to the transient; fade out tails.
2. **Normalise to your house target**, then record the offset as above.
3. **Mono for 3D sounds.** Spatial emitters work best with mono sources; keep stereo for UI and music.
4. **Sample rate 48 kHz or lower**; `.ogg` keeps size down.
5. **Variations.** Generate or render three to five takes of frequent sounds (footsteps, hits) and randomise between them, with small pitch variation, to avoid the "machine gun" effect.
6. **Loop points.** Generated music and ambience rarely loop cleanly. Cut on a beat or a zero crossing and crossfade.
7. **Check in the mix**, with music and combat at once, on phone speakers.

## 6. Prompting audio generators

Rules of thumb:
- **Describe the sound physically**, not emotionally: "short metallic scrape, bright, 0.4 seconds, fast attack, no reverb" beats "an epic sword sound".
- **Ask for dry sounds.** Generators like to add reverb and tails; Roblox adds space with its own effects and emitters, and baked reverb clashes with your environment ([[Spatial Audio and Mixing]]).
- **One sound per file.** Ask for a single hit, not a sequence; layer and sequence in game.
- **Music: specify loopable, instrumental, tempo and length**, and generate stems or sections if the tool allows, so adaptive music can switch layers ([[Music and Adaptive Audio]]).
- **Voice: write for the voice.** Short sentences, phonetic spelling for invented names, punctuation for pauses. Test the same line with two or three voices before committing.

---

## Common mistakes

- Free-tier generated music in a monetised game.
- Assuming a later subscription licenses audio made earlier.
- Asking an AI for sound ids.
- Cloning a real voice without written consent.
- TTS lines without subtitles.
- Letting players type text that becomes a saved speech asset on your account.
- Generated sounds at random loudness with no levelling table.

## Checklist

- [ ] Terms checked for the plan used at generation time; copy saved.
- [ ] Every uploaded id recorded by script; none invented.
- [ ] Loudness measured; every id has a levelling entry.
- [ ] TTS: 300 characters per request, subtitles shown, failure handled.
- [ ] Speech-to-text: microphone and voice chat settings understood; recognised text filtered; questionnaire updated.
- [ ] Realistic or signature sounds from licensed or recorded sources.

## See also
[[Sound Fundamentals]] · [[The Audio API - Players Emitters Wires and Effects]] · [[Spatial Audio and Mixing]] · [[Music and Adaptive Audio]] · [[Sound Design for Games]] · [[Audio Pipeline]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[Roblox Policies on AI-Generated Content]]

## Connected notes
<!-- auto-links:start -->
[[AI in Roblox Development Overview]] · [[Captions and Audio Accessibility]] · Resource Library - Audio · Voice Chat and Safety Features · Links - Audio creation and uploading · Combat Sound Design and Feedback
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Music Licensing and Audio Upload Rules for 2026]] · [[Evaluating AI Tools - A Practical Rubric]] · [[Who Owns AI-Generated Code and Assets]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[AI 3D Model Generation Outside Roblox]] · [[Roblox Studio Assistant]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]]
<!-- related:end -->
