---
tags: [lighting, mood, day-night, weather, zones, environment, type/guide, area/vfx, level/intermediate, api/Atmosphere, area/lighting, api/Lighting]
---
# Lighting Mood and Time of Day

<!-- tldr:start -->
> [!tldr] TL;DR
> - Time differs between players: Each client ran its own timer from join -> Derive from server time and a published epoch.
> - Night looks like dim day: Only ClockTime changes -> Mood keyframes for ambient, shifts, atmosphere.
> - Night unplayable on phones: Ambient near black -> Tinted ambient, outlines on enemies.
> - Server publishes epoch, cycle and day share; clients compute time.
> - Mood keyframes for at least dawn, noon, dusk, midnight.
> - Night readable on a dim phone screen.
>
> Cost: TL;DR ~160 tok · whole note ~4.9k tok. Read more: ## 1. The clock · ## 2. Mood keyframes across the day · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A day/night cycle looks like a one-liner (`Lighting.ClockTime += dt`) and turns into a system as soon as the game has zones, weather, cutscenes, indoor areas and players on phones. This note covers the clock itself (who owns it and how it reaches clients), mood keyframes across the day, zone and weather overrides, handing control to cutscenes, and the readability rules that keep a beautiful night from becoming an unplayable one.

Property details are in [[Lighting Technologies and Settings]] and [[Atmosphere Sky Clouds and Post-Processing]].

Source labels: **Docs**, **API dump**, **Reference project** (one production game with zones, weather and a day cycle), **Rule of thumb**.

---

## 1. The clock

### Facts (Docs, API dump)
- `ClockTime` (hours, 0 to 24) and `TimeOfDay` ("HH:MM:SS") are the same value; setting one sets the other.
- Neither advances by itself during play. A script must move it.
- `ClockTime` is `NotReplicated` in the API dump. Do not rely on the server's writes reaching clients every frame; derive the time on each client.
- `SetMinutesAfterMidnight(n)` accepts values beyond 24 hours and wraps.
- Sun and moon positions follow the time and `GeographicLatitude`; `GetSunDirection()` returns the direction.

### Server publishes, clients compute

The robust pattern: the server writes the cycle definition once, as attributes, and every client computes the current time from the shared server clock. No per-frame network traffic, every client agrees, late joiners are correct immediately.

The reference project published `DayEpoch` and `DayCycle` attributes from its weather service, with a 360-second cycle where day takes 62% of it. A long day share keeps most play in daylight (readable) while still giving everyone a night.

```lua
--!strict
-- Server: publish the cycle (once, and again only if you change it).
local Workspace = game:GetService("Workspace")

Workspace:SetAttribute("DayEpoch", Workspace:GetServerTimeNow())
Workspace:SetAttribute("DayCycle", 360) -- seconds per full day
Workspace:SetAttribute("DayShare", 0.62) -- fraction of the cycle that is daytime
```

```lua
--!strict
-- Client: derive ClockTime from server time. Day runs 06:00 -> 18:00 over DayShare of the cycle.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function clockAt(now: number, epoch: number, cycle: number, dayShare: number): number
	local phase = ((now - epoch) / cycle) % 1 -- 0..1 through the whole cycle
	if phase < dayShare then
		return 6 + 12 * (phase / dayShare) -- 06:00 to 18:00
	end
	local nightPhase = (phase - dayShare) / (1 - dayShare)
	return (18 + 12 * nightPhase) % 24 -- 18:00 to 06:00 through midnight
end

local forcedClock: number? = nil -- set by tests or cutscenes

RunService.Heartbeat:Connect(function()
	local epoch = Workspace:GetAttribute("DayEpoch")
	local cycle = Workspace:GetAttribute("DayCycle")
	local share = Workspace:GetAttribute("DayShare")
	if type(epoch) ~= "number" or type(cycle) ~= "number" or type(share) ~= "number" then
		return -- server has not published yet
	end
	Lighting.ClockTime = forcedClock or clockAt(Workspace:GetServerTimeNow(), epoch, cycle, share)
end)
```

`Workspace:GetServerTimeNow()` is synchronised across clients to within network jitter, so two players side by side see the sun in the same place.

**Why non-linear time:** a linear 24-hour mapping gives night exactly half the cycle. Most games want short nights. Mapping day and night segments separately (as above) keeps the sun's motion smooth inside each segment; there is a speed change at 06:00 and 18:00, which nobody notices because the sun is at the horizon.

### Testing hooks
The reference project used server-side attributes `ForceWeather` and `ForceClock` to pin weather and hour for QA, cleared afterwards. Make that a documented debug feature, gated to developers ([[Multi-Client and Live Testing]]).

---

## 2. Mood keyframes across the day

Setting only `ClockTime` moves the sun, but the ambient, colour shifts, atmosphere and grade stay the same, so midnight looks like a dim noon. A mood table with keyframes per hour fixes this.

```lua
--!strict
-- MoodCurve: interpolate a bundle of lighting values by hour.
local Lighting = game:GetService("Lighting")

export type Mood = {
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	shiftTop: Color3,
	exposure: number,
	atmoDensity: number,
	atmoHaze: number,
	atmoColor: Color3,
}

type Key = { hour: number, mood: Mood }

local KEYS: { Key } = {
	{ hour = 0, mood = { ambient = Color3.fromRGB(20, 24, 45), outdoor = Color3.fromRGB(40, 48, 85), brightness = 0.6,
		shiftTop = Color3.fromRGB(60, 70, 120), exposure = -0.2, atmoDensity = 0.35, atmoHaze = 1.2, atmoColor = Color3.fromRGB(70, 80, 130) } },
	{ hour = 6, mood = { ambient = Color3.fromRGB(70, 55, 60), outdoor = Color3.fromRGB(140, 110, 110), brightness = 1.6,
		shiftTop = Color3.fromRGB(255, 150, 90), exposure = 0, atmoDensity = 0.4, atmoHaze = 2, atmoColor = Color3.fromRGB(255, 180, 140) } },
	{ hour = 12, mood = { ambient = Color3.fromRGB(90, 90, 100), outdoor = Color3.fromRGB(150, 150, 160), brightness = 2.5,
		shiftTop = Color3.fromRGB(255, 245, 230), exposure = 0, atmoDensity = 0.3, atmoHaze = 1, atmoColor = Color3.fromRGB(200, 215, 235) } },
	{ hour = 18, mood = { ambient = Color3.fromRGB(80, 55, 60), outdoor = Color3.fromRGB(150, 100, 95), brightness = 1.5,
		shiftTop = Color3.fromRGB(255, 120, 70), exposure = 0, atmoDensity = 0.42, atmoHaze = 2.2, atmoColor = Color3.fromRGB(255, 150, 110) } },
	{ hour = 24, mood = nil :: any }, -- filled below: wraps to hour 0
}
KEYS[#KEYS].mood = KEYS[1].mood

local function lerpMood(a: Mood, b: Mood, t: number): Mood
	return {
		ambient = a.ambient:Lerp(b.ambient, t),
		outdoor = a.outdoor:Lerp(b.outdoor, t),
		brightness = a.brightness + (b.brightness - a.brightness) * t,
		shiftTop = a.shiftTop:Lerp(b.shiftTop, t),
		exposure = a.exposure + (b.exposure - a.exposure) * t,
		atmoDensity = a.atmoDensity + (b.atmoDensity - a.atmoDensity) * t,
		atmoHaze = a.atmoHaze + (b.atmoHaze - a.atmoHaze) * t,
		atmoColor = a.atmoColor:Lerp(b.atmoColor, t),
	}
end

local MoodCurve = {}

function MoodCurve.at(hour: number): Mood
	hour %= 24
	for i = 1, #KEYS - 1 do
		local k0, k1 = KEYS[i], KEYS[i + 1]
		if hour >= k0.hour and hour <= k1.hour then
			local t = (hour - k0.hour) / (k1.hour - k0.hour)
			-- Smoothstep so dawn and dusk ease instead of changing linearly.
			t = t * t * (3 - 2 * t)
			return lerpMood(k0.mood, k1.mood, t)
		end
	end
	return KEYS[1].mood
end

function MoodCurve.apply(m: Mood)
	Lighting.Ambient = m.ambient
	Lighting.OutdoorAmbient = m.outdoor
	Lighting.Brightness = m.brightness
	Lighting.ColorShift_Top = m.shiftTop
	Lighting.ExposureCompensation = m.exposure
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = m.atmoDensity
		atmo.Haze = m.atmoHaze
		atmo.Color = m.atmoColor
	end
end

return MoodCurve
```

Notes:
- Keep `ambient` at or below `outdoor` per channel (see [[Lighting Technologies and Settings]]).
- Applying the mood at 10 to 20 Hz is enough; nobody sees ambient change between frames.
- The values above are a starting palette, not a recommendation for every game.

### Night must still be playable

Night is the most common readability failure. Rules of thumb:
- Night ambient is **tinted, not black**: a blue-violet ambient around 15 to 25% brightness with outdoor ambient higher. Players should see silhouettes at 50 studs.
- Moonlight works as a weak directional key light with cool colour shift on top faces.
- Gameplay-relevant objects (enemies, pickups, doors) get their own readability: outlines, emissive accents, a small light. Do not make the whole world brighter to rescue three objects.
- Test night on a phone at low brightness, outdoors if you can. If you cannot see an enemy approaching, neither can your players.

---

## 3. Zones and weather on top of the day

Real games stack layers:

```
final mood = dayCurve(hour)  ->  blended toward zone mood  ->  modified by weather  ->  overridden by cutscene
```

| Layer | Owner | Transition |
|---|---|---|
| Day curve | Client mood controller | Continuous |
| Zone mood | Same controller, from player position | Cross-fade 1.5 to 3 s on entering a zone (rule of thumb; the reference project's ambience used 2.5 s) |
| Weather | Server picks weather; client renders | Fade 5 to 20 s; telegraph rare events |
| Cutscene / ultimate | Cutscene system | Takes over by flag; mood controller pauses |

The reference project ran one client weather controller that replaced three older per-feature controllers (sky, zone mood, storm). Consolidating into one owner removed the flicker of several scripts writing the same properties. Its zone lookup (which zone is the player in) was shared between weather and ambience audio, so the sky and the soundscape changed at the same boundary.

### Blending zone moods

Represent a zone's look as a partial mood (only the fields it overrides) plus a blend weight that eases toward 1 when inside the zone and 0 outside. `final = lerp(dayMood, zoneMood, weight)` field by field. Use the same easing for audio ambience so the player's senses agree ([[Music and Adaptive Audio]]).

### Weather events

- **Telegraph dangerous weather.** The reference project's lightning hazard showed a 1.5 s ring before striking, only in combat zones, never in the lobby. Weather that hurts must be readable before it hurts.
- **Rare weather is an event.** Rare weathers in the reference project (night-only star showers and similar) carried luck multipliers and a banner; the lighting change was part of the announcement. See [[Live Ops Events and Updates]].
- **Precipitation follows the player.** Rain and snow emitters are attached to a part that follows the camera, not spread over the whole map ([[Particle Emitters In Depth]]).

### Indoors
Interiors need their own mood: lower ambient, no sky contribution, local lights. Use invisible zone volumes for interiors as you do for outdoor zones, with a fast transition (0.5 to 1 s) when crossing a door.

---

## 4. Cutscenes and special moments

A cutscene or ultimate wants full control of lighting and grade for a few seconds. The rule that works:

1. The cutscene sets a flag (the reference project used a player attribute) before touching anything.
2. Every ambient lighting system checks the flag each update and does nothing while it is set.
3. The cutscene applies its own look through the same mechanism (or a priority grade stack, see [[Atmosphere Sky Clouds and Post-Processing]]).
4. On exit the cutscene clears the flag; the mood controller resumes and blends back from whatever is on screen to the correct mood over 1 to 2 s.

Without step 4's blend, the end of every cutscene "snaps". Without step 2, the cutscene fights the weather. See [[Cameras and Cutscenes]] and [[Cinematic Ultimates]].

---

## 5. Colour craft

Short principles that cover most mood work:

| Goal | Lever |
|---|---|
| Warm, inviting | Warm `ColorShift_Top`, slightly cool ambient for contrast, low haze |
| Cold, lonely | Desaturated grade, cool ambient, higher atmosphere density, pale sky |
| Danger, heat | Orange-red haze, darker ambient, embers (particles) |
| Mystery | Low brightness, coloured fog-like haze, strong local lights in one accent colour |
| Magic realm | Unnatural sky, coloured atmosphere `Decay`, slowly rotating skybox |

- **Warm key, cool fill** (sun warm, shadows cool) is the most reliable default.
- **Value before hue.** If a scene does not read in greyscale (set `Saturation = -1` temporarily), colour will not save it.
- **One accent colour per zone.** The reference project's art style for themed objects tinted sky, haze and ambient per theme over a neutral floor, so each theme read from colour alone ([[Environment Art Styles]]).

---

## 6. Performance

- Changing `Lighting` properties is cheap. Recomputing the mood every frame is fine; doing it at 10 to 20 Hz is cheaper and indistinguishable.
- Swapping `Sky` objects causes texture loads; preload them.
- Weather particles are the expensive part of weather: keep them near the camera, scale them with quality, and cap rates (400 particles per second per emitter on desktop, 100 on mobile, Docs).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Time differs between players | Each client ran its own timer from join | Derive from server time and a published epoch. |
| Night looks like dim day | Only ClockTime changes | Mood keyframes for ambient, shifts, atmosphere. |
| Night unplayable on phones | Ambient near black | Tinted ambient, outlines on enemies. |
| Flicker at zone borders | Two systems write Lighting | One owner, blend weights. |
| Cutscene ends with a pop | Mood resumes instantly | Blend back over 1 to 2 s. |
| Weather damage feels unfair | No telegraph | Visible warning before every hazard. |
| Studio preview changed the shipped look | Preview not restored | Snapshot and restore (see Lighting Technologies note). |

## Checklist

- [ ] Server publishes epoch, cycle and day share; clients compute time.
- [ ] Mood keyframes for at least dawn, noon, dusk, midnight.
- [ ] Night readable on a dim phone screen.
- [ ] Zones and interiors blend; one owner per property.
- [ ] Cutscenes pause the mood controller by flag and hand back with a blend.
- [ ] Dangerous weather is telegraphed; rare weather is announced.
- [ ] Debug hooks to force hour and weather, gated to developers.

See also: [[Lighting Technologies and Settings]], [[Atmosphere Sky Clouds and Post-Processing]], [[Light Sources and Shadows]], [[Music and Adaptive Audio]], [[Water Sky and Atmosphere Art]], [[Environment Art Styles]], [[Cameras and Cutscenes]], [[Live Ops Events and Updates]].

## Nuances and edge cases

1. **Server Lighting writes replicate, but per-frame clock writes are wasteful.** A server setting `ClockTime` every frame sends a stream of property updates for something every client can compute. Publish one shared start time instead (the server's, replicated once) and let each client derive the time, which gives every player the same sky. Clients computing time from their own join moment drift apart by however long they have been in the server. A single server-published start time plus a fixed day length is enough; clients derive the rest.
2. **Device quality changes the look.** Lower graphics quality levels disable or simplify shadows and some post-processing, so a night scene that relies on point lights and soft shadows reads as flat dark on a phone at low quality. Check every mood keyframe at the lowest quality level a meaningful share of players uses, not just at maximum.
3. **Lighting technology choice locks in some moods.** Shadow detail and how local lights behave differ between lighting technologies (see [[Lighting Technologies and Settings]]). A cave that looks right with one technology can be pitch black or washed out with another. Pick the technology before tuning moods, and re-tune after any switch.
4. **Gameplay readability beats realism at night.** Enemies, pickups and paths must be readable at the darkest point of the cycle. Rule of thumb: never let ambient drop to the point where an enemy silhouette disappears against the ground; use rim lights, highlights or emissive accents instead of brighter ambient where you want night to feel dark.
5. **Long sessions see every phase; short sessions see one.** With a 20-minute day, a player in a 10-minute session may only ever see dusk. Make each phase of the cycle a good place to play, not just midday, and avoid gating content to a phase unless it recurs often.
6. **Server size and events.** With 50 players in one server, a weather event or a forced night (for a boss) affects everyone, including players who are not involved. Prefer zone-local mood changes for local events and reserve global changes for server-wide moments.
7. **Accessibility.** Rapid lighting changes, strobing lightning and very dark scenes are uncomfortable or unplayable for some players. Offer a reduced-flashing option and keep lightning flashes short and infrequent (see [[Motion Sensitivity and Camera Comfort]]).
8. **Tweening lighting properties every frame costs little but adds up with many writers.** One controller blending all lighting properties per frame is cheap. Several systems (zone, weather, cutscene, time of day) each tweening the same properties produce flicker and wasted work. One owner computes the final values from weighted inputs.

The senior trade-off: a living day cycle adds atmosphere and makes screenshots varied, but it multiplies the art direction work (every zone in every phase). A fixed, well-tuned mood per zone is often the better choice for small teams.

## Common mistakes (advanced)

1. **Tuning lighting only at maximum graphics quality.** Symptom: phone players report the game is too dark. Fix: review at low quality on a real device.
2. **Gating a quest to night with a long day cycle.** Symptom: players wait 15 minutes for night. Fix: shorter cycles or allow the content at all times with a night bonus.
3. **Lightning flashes as full-screen white.** Symptom: discomfort complaints. Fix: brief, dimmer flashes and a setting to reduce them.
4. **Separate time per zone.** Symptom: walking between zones jumps the sky. Fix: one clock; zones adjust colour, not time.
5. **Changing lighting technology late.** Symptom: every interior must be re-lit. Fix: decide early and lock it.
6. **Using `ClockTime` for gameplay timing on the client.** Symptom: day-dependent logic disagrees between players. Fix: gameplay reads the shared server time, not the client's lighting value.

## Related decisions

- [[Stylized Lighting Recipes]]: concrete mood recipes to keyframe.
- [[Zone and Biome Art Direction]]: zone colour palettes layered on the cycle.
- [[Colour-Blind Safe Design]]: night tints that keep colour cues readable.
- [[Motion Sensitivity and Camera Comfort]]: flashing and sudden brightness changes.
- [[Event Calendars and Content Planning]]: timed events that interact with the day cycle.
- [[Rendering Performance]]: the cost of shadows and lights by quality level.
- [[Genre Playbook - Horror and Story]]: darkness as a design tool, with readability limits.
- [[Cameras and Cutscenes]]: overriding mood during cinematics.

## Connected notes
<!-- auto-links:start -->
[[Lighting Untextured Art in Roblox]] · Official Docs - Building and World · Colour Scripts and Value Structure for Untextured Art · Official Docs - Audio · Baking Lighting and Detail into Textures · Voxel Palettes - Ramps Hue Shifting and Limits
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weather System Architecture - State Machine, Transitions and Replication]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[VFX Design Playbook]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[VFX Readability and Value - Lessons from Blind Reviews]]
<!-- related:end -->
