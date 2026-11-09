---
tags: [ui, video, videoplayer, videodisplay, videoframe, surfacegui, audio, memory, upload, type/guide, area/ui, level/intermediate, api/VideoPlayer, api/VideoFrame, area/audio]
---
# Video in Experiences - VideoPlayer, VideoDisplay and VideoFrame

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `VideoFrame` not inside a ScreenGui, SurfaceGui or BillboardGui -> Parent it to a GUI container
> - Avoid: No `Wire` from `VideoPlayer` to a `VideoDisplay` -> Wire `SourceInstance` = player, `TargetInstance` = display
> - Avoid: Soundtrack wired to an emitter with no listener -> Set up an `AudioListener` (Audio API)
> - Video meets the upload rules (format, 5 minutes, resolution, size) and you hold the rights, music included.
> - Right object chosen: `VideoFrame` for flat UI, `VideoPlayer` + `VideoDisplay` for world screens with sound.
> - `PlayFailed` handled; `LoadAsync()` used before showing a screen that must start cleanly.
>
> Cost: TL;DR ~200 tok · whole note ~2.5k tok. Read more: ## 1. Getting a video in · ## 3. Option B: VideoPlayer + VideoDisplay (wired) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox can play uploaded video on a screen in the world or in your UI: a cinema in a hangout, a looping trailer on a lobby billboard, a short clip in a tutorial, an animated main-menu background. There are two ways to do it. `VideoFrame` is a single GUI object that plays a video. The newer `VideoPlayer` follows the Audio API's wiring model: a player instance sends its picture to a `VideoDisplay` and its soundtrack to audio instances through `Wire`s. This note covers both, the upload rules, the memory cost, and keeping a shared screen in sync.

Source labels: **Roblox docs** (the `VideoPlayer` reference and the video frames guide, checked as of November 2026), **Rule of thumb**, **Unverified**. References:
- https://create.roblox.com/docs/reference/engine/classes/VideoPlayer
- https://create.roblox.com/docs/ui/video-frames

---

## 1. Getting a video in

From the video frames guide (**Roblox docs**, as of November 2026):

| Rule | Value |
|---|---|
| Who can upload | 13+ and ID-verified |
| Formats | `.mp4` or `.mov`; alpha channels are ignored |
| Length | 5 minutes or less |
| Resolution | up to 4096 by 2160 |
| File size | under 3.75 GB |
| Cost | 2,000 Robux per upload |
| Daily cap | 20 uploads per day |
| Simultaneous playback | at most two videos at once |

- Uploads go through the Asset Manager, the Creator Dashboard or Open Cloud ([[Asset Upload Automation with Open Cloud]]). The guide describes enabling **Video Uploads** under File ⟩ Beta Features; check whether that is still needed in your Studio version.
- You must hold the rights to the video, and it must meet the Community Standards and Terms of Use. Music inside a video is still music: see [[Music Licensing and Audio Upload Rules for 2026]].
- **Rule of thumb:** at 2,000 Robux an upload, cut, encode and review the file before uploading. Keep one master clip and loop it rather than uploading variants.

## 2. Option A: VideoFrame (simplest)

Insert a video from the Toolbox or Asset Manager and Studio creates a `VideoFrame`. It only plays inside a `ScreenGui`, `SurfaceGui` or `BillboardGui`. Set `Looped` and `Playing` in Properties, or from code set `Video`, `Looped`, `Volume` and call `Play()`. **Roblox docs.**

Use it for a menu background or a single tutorial clip in 2D UI. Its sound is not positioned in the world.

## 3. Option B: VideoPlayer + VideoDisplay (wired)

`VideoPlayer` is "an instance for playing video assets." It has one output pin, `Output`. Wire it to a `VideoDisplay` (a GUI object, so it goes in a `SurfaceGui`, `ScreenGui` or `BillboardGui`) to show the picture, and to an audio instance such as an `AudioEmitter` to play the soundtrack. **Roblox docs.**

Key members (**Roblox docs**):
- **Source and state:** `VideoContent` (the asset), `IsLoaded`, `IsPlaying` (replicates), `TimeLength` (0 until loaded), `TimePosition` (settable before or during playback), `Resolution`.
- **Playback:** `Looping`, `PlaybackSpeed` (also shifts audio pitch), `Volume` (0 to 3).
- **Methods:** `Play()` and `Pause()`, which replicate from server to client; `LoadAsync()` preloads so `Play()` starts without buffering and returns an `AssetFetchStatus`; `Unload()` frees the video and resets `TimePosition` to 0.
- **Events:** `DidEnd` (not fired when looping or stopped early), `DidLoop`, `PlayFailed(status)`.
- **Studio:** `AutoLoadInStudio` is off by default, so the display stays blank in Edit mode to save memory; `AutoPlayInStudio` needs it on.

```lua
--!strict
-- A cinema screen on one face of a part, with the soundtrack coming from the screen.
local function makeScreen(screenPart: BasePart, videoUri: string): VideoPlayer
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = screenPart

	local display = Instance.new("VideoDisplay")
	display.Size = UDim2.fromScale(1, 1)
	display.Parent = surface

	local video = Instance.new("VideoPlayer")
	video.VideoContent = Content.fromUri(videoUri)
	video.Looping = true
	video.Parent = screenPart

	local emitter = Instance.new("AudioEmitter")
	emitter.Parent = screenPart

	local toDisplay = Instance.new("Wire")
	toDisplay.SourceInstance = video
	toDisplay.TargetInstance = display
	toDisplay.Parent = video

	local toSound = Instance.new("Wire")
	toSound.SourceInstance = video
	toSound.TargetInstance = emitter
	toSound.Parent = video

	video.PlayFailed:Connect(function(status)
		warn("Video failed to play:", status)
	end)
	return video
end
```

An `AudioEmitter` is only heard through an `AudioListener`; if the Audio API is new to you, read [[The Audio API - Players Emitters Wires and Effects]] first. Routing the soundtrack through your own fader lets the player's music or ambience volume setting apply to it ([[Audio Mixer Settings with SoundGroups]]).

### Which one?

| Need | Pick |
|---|---|
| A clip in 2D UI, no world audio | `VideoFrame` |
| A screen in the world with positional sound | `VideoPlayer` + `VideoDisplay` + `AudioEmitter` |
| One video shown on several screens | `VideoPlayer` wired to several displays (**Unverified** that one player drives multiple displays; test it) |
| Effects on the soundtrack (reverb in a hall, muffling) | `VideoPlayer`, wired through Audio API effects |

## 4. Memory and device limits

- Loading a video "uses significant memory." Call `Unload()` when a screen is out of use (player left the cinema, menu closed). **Roblox docs.**
- `VideoPlayer.MaximumResolution` (hidden, enum `VideoSampleSize`) caps the decoded resolution to save memory on constrained devices; the default applies no cap. **Roblox docs.**
- Only **two videos play at once** (guide figure for video frames; **Unverified** whether the same cap applies to `VideoPlayer`). Design lobbies with one active screen and posters elsewhere.
- **Rule of thumb:** load a world screen only when the player is near it (proximity or zone entry, [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]) and unload when they leave. Never autoplay video on the first screen a new player sees on a phone: it competes with the first-session loading budget ([[Case Study - Fast Join and Deferred Loading]]).

## 5. Keeping a shared screen in sync

`Play()`, `Pause()` and `IsPlaying` replicate from the server, so a server-owned `VideoPlayer` gives everyone the same play state. Position drift between clients and late joiners is the usual problem. **Rule of thumb** pattern:

1. The server stores `startedAt = workspace:GetServerTimeNow()` when the show starts.
2. Each client, on join or when the screen streams in, sets `TimePosition = (workspace:GetServerTimeNow() - startedAt) % TimeLength` after `LoadAsync()` succeeds, then plays.
3. Re-check every 30 seconds or so and correct only when drift exceeds about half a second, so corrections do not cause visible jumps.

The same server-clock approach is used for cutscenes in [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]].

## 6. Player experience and accessibility

- Video has no caption track. If speech matters, show subtitles in a `TextLabel` timed to `TimePosition` ([[Captions and Audio Accessibility]]).
- Give players a mute or "hide screens" option in settings, and respect it on every screen ([[Settings Menu Essentials and Persistence]]).
- Avoid fast flashing content on large screens ([[Motion Sensitivity and Camera Comfort]]).
- Keep video out of places where it blocks gameplay information. A screen is decoration or content, never the only way to learn a rule.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `VideoFrame` not inside a ScreenGui, SurfaceGui or BillboardGui | Nothing plays | Parent it to a GUI container |
| No `Wire` from `VideoPlayer` to a `VideoDisplay` | Sound plays, screen is blank | Wire `SourceInstance` = player, `TargetInstance` = display |
| Soundtrack wired to an emitter with no listener | Picture plays silently | Set up an `AudioListener` (Audio API) |
| Blank display in Studio Edit mode | Looks broken while building | Expected: `AutoLoadInStudio` is off by default |
| Three or more screens playing | Some screens never start | Two videos at most; load by proximity |
| Videos left loaded after use | Memory climbs on phones | `Unload()` when out of view |
| Late joiners see the video from the start | Screens out of sync | Server start time + `GetServerTimeNow()` offset |
| Uploading many test variants | Thousands of Robux spent | Review the file locally; one master clip |
| Reading `TimeLength` before load | Value is 0; maths breaks | `LoadAsync()` first, then read it |

## Checklist
- [ ] Video meets the upload rules (format, 5 minutes, resolution, size) and you hold the rights, music included.
- [ ] Right object chosen: `VideoFrame` for flat UI, `VideoPlayer` + `VideoDisplay` for world screens with sound.
- [ ] `PlayFailed` handled; `LoadAsync()` used before showing a screen that must start cleanly.
- [ ] At most two videos playing; screens load by proximity and `Unload()` when left.
- [ ] Shared screens synced from a server start time; late joiners seek correctly.
- [ ] Mute or hide-screens setting respected; subtitles where speech matters.
- [ ] Tested on a low-memory phone with the video playing.

## See also
[[World-Space UI - BillboardGui and SurfaceGui]] · [[The Audio API - Players Emitters Wires and Effects]] · [[Lobby and Hub Design]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Memory Budgets and Leaks]] · [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]] · [[Captions and Audio Accessibility]]

<!-- related:start -->
## Related
[[Off-Screen Objective Markers and Waypoint Arrows]] · [[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Safe Areas and Insets]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[HUD Design]] · [[ScreenGui Fundamentals]]
<!-- related:end -->
