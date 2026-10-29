---
tags: [audio, ambience, soundscape, zones, audio-api, crossfade, performance, type/guide, area/audio, level/advanced, api/AudioPlayer, api/AudioFader, api/Sound]
---
# Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: New player per bed per transition -> One player per asset, volume targets
> - Avoid: No hysteresis -> Dwell time and larger exit bounds
> - Avoid: `Instance.new` per one-shot -> Fixed voice pool with stealing
> - Soundscapes defined as data: beds and one-shot sets with conditions.
> - Overlap resolution by priority with hysteresis; polled at 4 to 10 Hz.
> - One player per bed asset; equal-power crossfades; random start offsets.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 3. Bed crossfading without duplicates · ## 4. One-shots and the voice pool · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Music and Adaptive Audio]] already covers what ambience should sound like (zone beds, spot sounds, indoor muffling) with one reference project's values. This note is the engine underneath: a data model where a soundscape is a stack of conditional layers, a resolver that handles overlapping zones without flicker, a crossfader that never stacks duplicates, and a voice pool so random one-shots cannot leak instances. It is written for the Audio API (`AudioPlayer` into an ambience `AudioFader`), with notes for legacy `Sound`.

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Data model: soundscapes are data

```lua
--!strict
export type Bed = {
	asset: string,             -- an id you uploaded; never invented
	volume: number,
	when: { [string]: any }?,  -- conditions, e.g. { night = true, weather = "Rain" }
}
export type OneShot = {
	assets: { string },
	gap: NumberRange,           -- seconds between plays
	radius: NumberRange,        -- studs from the listener
	height: NumberRange,
	volume: NumberRange,
	pitch: NumberRange,
	when: { [string]: any }?,
}
export type Soundscape = {
	id: string,
	priority: number,          -- higher wins when zones overlap
	fade: number,              -- crossfade seconds into this scape
	beds: { Bed },
	oneShots: { OneShot },
	reverb: string?,           -- named reverb preset on the ambience bus
}
```

Conditions come from one shared context table the client keeps current: `night`, `weather`, `indoor`, `underwater`, `combat`. The same context drives lighting and weather, so sound changes at the same moment as the sky ([[Lighting Mood and Time of Day]]). Designers add a "night crickets" layer by data, not code.

## 2. Resolving which soundscape is active

Use the **listener position** (camera or character, matching your `SoundService.DefaultListenerLocation` choice, see [[The Audio API - Players Emitters Wires and Effects]]) and your zone query, not `Touched` ([[Raycasts Shapecasts and Spatial Queries]]).

Overlaps are normal: a cave inside a forest, a shop inside a city. Rules that avoid flicker:
1. **Highest priority wins**; ties break by smallest zone volume (the more specific zone).
2. **Hysteresis**: require the new winner for 0.3 to 0.5 s before switching, and use slightly larger exit bounds than entry bounds (1 to 3 studs). Without this, walking along a border toggles every frame.
3. **Poll at 4 to 10 Hz**, not every frame. Ambience transitions are seconds long; a 100 ms decision delay is inaudible.
4. **Teleports and respawns** switch instantly with a short fade-in, not a long crossfade from the old place.

```lua
--!strict
local current: string? = nil
local candidate: string? = nil
local candidateSince = 0

local function resolve(winner: string?, now: number, switchTo: (string?) -> ())
	if winner == current then
		candidate = nil
		return
	end
	if winner ~= candidate then
		candidate, candidateSince = winner, now
		return
	end
	if now - candidateSince >= 0.4 then
		current, candidate = winner, nil
		switchTo(winner)
	end
end
```

## 3. Bed crossfading without duplicates

Each bed asset gets **one** player for its lifetime. Switching scapes changes target volumes; it does not create new players.

- Keep a map `asset -> { player, fader/volume, target }`. Entering a scape sets targets for its active beds; every other bed's target becomes 0.
- A single update loop moves each volume toward its target with the destination scape's fade time. When a bed has sat at 0 for a while (for example 10 s), stop it; when it gets a target above 0, start it **at a random `TimePosition`** so two players entering together, or a re-entry, do not always start the loop at the same seam.
- Shared beds survive transitions. Forest to forest-at-night keeps the wind bed playing and only crossfades the bird and cricket layers. This is the biggest quality win of the layer model.
- Equal-power curves for crossfades (`sin`/`cos` of the progress) avoid the volume dip in the middle that linear fades produce on uncorrelated material.

With the Audio API, each bed is `AudioPlayer` (with `Looping = true`) wired into a per-bed `AudioFader`, which is wired into the ambience bus fader; with legacy `Sound`, put beds in an ambience `SoundGroup` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/AudioPlayer, https://create.roblox.com/docs/reference/engine/classes/SoundGroup).

## 4. One-shots and the voice pool

Random one-shots (bird calls, distant thunder, creaks, drips) are what make a bed sound alive, and what leak if you `Instance.new` per play.

- Pre-create a pool of N emitter rigs (an `Attachment` on an anchored, non-colliding, non-querying helper part, with an `AudioEmitter` and an `AudioPlayer` wired to it; or a `Sound` parented to the attachment). **Rule of thumb:** 6 to 12 voices for ambience total.
- To play: take a free voice (or steal the oldest), move its attachment to `listener + random offset` within the layer's radius and height, set asset, volume and pitch from the ranges, play, mark busy until `TimeLength / pitch` elapses.
- Every one-shot layer has its own scheduler using `task.delay` with a fresh random gap; the scheduler only fires while its layer's conditions are true and the bed's volume is above a threshold, so one-shots fade with their scape.
- **Avoid repetition**: never pick the same asset twice in a row from a set; keep at least 3 variants per set.
- Positional one-shots give direction; ultra-distant ones (thunder) can be non-positional with a low-pass for distance.

```lua
--!strict
type Voice = { attach: Attachment, player: AudioPlayer, busyUntil: number }
local pool: { Voice } = {}

local function acquire(now: number): Voice
	local oldest = pool[1]
	for _, v in pool do
		if v.busyUntil <= now then return v end
		if v.busyUntil < oldest.busyUntil then oldest = v end
	end
	oldest.player:Stop()
	return oldest -- steal
end

local rng = Random.new()
local function playOneShot(asset: string, at: Vector3, volume: number, pitch: number)
	local now = os.clock()
	local v = acquire(now)
	v.attach.WorldPosition = at
	v.player.Asset = asset
	v.player.Volume = volume
	v.player.PlaybackSpeed = pitch
	v.player.TimePosition = 0
	v.player:Play()
	v.busyUntil = now + math.max(v.player.TimeLength, 0.5) / pitch + 0.1
end
```

Assets must be preloaded or `AutoLoad`-ed, otherwise the first play of each variant is silent or late; check `IsReady` before relying on `TimeLength` (**Roblox docs**, [[AudioPlayer]] page above).

## 5. Reverb and interiors

Keep one reverb on the ambience bus (and optionally the SFX bus) and switch its preset or wet level by scape: dry outdoors, short and bright in wooden rooms, long and dark in caves. Interpolate parameters over the same fade time as the beds. Indoors, keep the outdoor bed audible through a low-pass instead of muting it ([[Music and Adaptive Audio]] section 5).

## 6. Budget and testing

- Beds: at most 3 to 5 audible at once (**Rule of thumb**). If a scape needs more, premix layers offline.
- Server never plays ambience. It is client-only; nothing replicates; no remotes.
- Mute or duck ambience in cutscenes and menus through the bus, not by stopping beds (restarting loses the random offset and costs loads).
- Test: walk every border slowly back and forth; stand on a border for a minute; teleport between scapes; toggle weather and time of day while standing still; leave the game running 30 minutes and check the instance count of your pool stays flat ([[Hunting Memory Leaks Step by Step]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| New player per bed per transition | Doubled beds, phasing, leaks | One player per asset, volume targets |
| No hysteresis | Ambience flickers on borders | Dwell time and larger exit bounds |
| `Instance.new` per one-shot | Instance count climbs | Fixed voice pool with stealing |
| Same loop start every entry | Audible seam, robotic repeats | Random `TimePosition` on start |
| Separate zone lookups for sound and lighting | Sky and sound change at different spots | One context table |
| One-shots firing in silent scapes | Birds in a cave | Schedulers gated by layer conditions and bed volume |

## Checklist
- [ ] Soundscapes defined as data: beds and one-shot sets with conditions.
- [ ] Overlap resolution by priority with hysteresis; polled at 4 to 10 Hz.
- [ ] One player per bed asset; equal-power crossfades; random start offsets.
- [ ] Voice pool for one-shots, sized and stealing oldest.
- [ ] Reverb follows scape; interiors low-pass, not mute, the outside.
- [ ] Border, teleport, weather and 30-minute leak tests done.

## See also
[[Music and Adaptive Audio]] · [[The Audio API - Players Emitters Wires and Effects]] · [[Spatial Audio and Mixing]] · [[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]] · [[Audio Pipeline]] · [[Zone and Biome Art Direction]]

## Connected notes
<!-- auto-links:start -->
[[Sound Fundamentals]] · [[Sound Design for Games]] · [[Lighting Mood and Time of Day]] · [[Captions and Audio Accessibility]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Combat Sound Design and Feedback]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]
<!-- related:end -->
