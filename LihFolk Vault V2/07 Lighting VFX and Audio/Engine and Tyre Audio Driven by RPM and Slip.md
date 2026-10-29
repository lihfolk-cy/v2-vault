---
tags: [audio, vehicles, engine-sound, tyres, skid, rpm, audio-api, type/guide, area/audio, level/advanced, api/AudioPlayer, api/Sound, api/VehicleSeat]
---
# Engine and Tyre Audio Driven by RPM and Slip

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One loop pitched over the whole RPM range -> 3 to 4 loops with windowed crossfades
> - Avoid: RPM proportional to speed -> Gear model or banded sawtooth
> - Avoid: Ignoring load -> On-load and off-load sets
> - Vehicle model exposes rpm, load, slip, grounded and surface per frame.
> - Engine uses windowed RPM layers with on/off-load sets and an idle loop.
> - Tyre skid, rolling-by-surface, landing and wind layers in place.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 1. Inputs: what the audio needs from the car · ## 2. Engine: layered loops, not one loop · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Car audio is the cheapest way to make a Roblox car feel fast and the easiest to get embarrassingly wrong: one looped engine sample with `PlaybackSpeed` mapped to speed sounds like a sewing machine at the top end and drops to silence at a stop. This note builds car audio from a small vehicle model (RPM, throttle, load, slip), maps it to layered loops with crossfades, and covers replication: the driver hears a rich local mix; everyone else hears a cheaper version driven from replicated state. Chassis physics is in [[Cars with Constraints - Suspension Steering and Drive]]; mixing and attenuation in [[Spatial Audio and Mixing]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Inputs: what the audio needs from the car

| Signal | Source | Range |
|---|---|---|
| `rpm` | Your gear/torque model, or derived from wheel angular speed times gear ratio | idle to redline |
| `throttle` | `VehicleSeat.ThrottleFloat` or your input action, smoothed | -1..1 |
| `load` | Throttle while accelerating vs coasting; high when climbing | 0..1 |
| `slip` | Per-wheel lateral and longitudinal slip from velocity at the contact point | 0..1 normalised |
| `grounded` | Per-wheel suspension raycast or contact | bool |
| `surface` | Material under each wheel (raycast `Material`) | enum |

**No gearbox yet?** Fake RPM with a sawtooth over speed bands: `rpm = idle + (redline - idle) * frac(speed / bandWidth)` with a short dip at each "shift". It sounds far better than RPM proportional to speed, because real engines spend most time in the middle of their range.

`VehicleSeat` exposes `ThrottleFloat`, `SteerFloat` and the read-only `Torque`/`MaxSpeed` settings (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/VehicleSeat).

## 2. Engine: layered loops, not one loop

Record or source 3 to 4 steady loops at known RPMs (for example idle, low, mid, high), ideally in two flavours: **on-load** (accelerating) and **off-load** (engine braking). Then:

- Each loop has an RPM it was recorded at, `rpmRef`. Play it at `PlaybackSpeed = rpm / rpmRef`, clamped to about 0.5 to 2.0. Pitching a loop beyond that range sounds synthetic (**Rule of thumb**).
- Each loop's **volume** is a triangular or bell window around its `rpmRef`, overlapping its neighbours, so as RPM rises the low loop fades out while the mid loop fades in. Use equal-power curves to avoid a dip.
- **Load** crossfades between on-load and off-load sets. Lifting off the throttle at high RPM should immediately sound different, even though RPM barely changes. This is the single cue players notice most.
- **Idle** is its own loop, gated by RPM near idle; never let the engine go silent while the car is on.
- Add a quiet **intake/turbo** layer keyed to throttle, and one-shots for **shifts** (a short dip and a "chirp") and **backfires** on lift-off above high RPM (randomised, rare).

```lua
--!strict
type Layer = { player: AudioPlayer, rpmRef: number, lo: number, hi: number, onLoad: boolean }

local function window(rpm: number, lo: number, mid: number, hi: number): number
	if rpm <= lo or rpm >= hi then return 0 end
	local t = if rpm < mid then (rpm - lo) / (mid - lo) else (hi - rpm) / (hi - mid)
	return math.sin(t * math.pi / 2) -- equal-power edge
end

local function updateEngine(layers: { Layer }, rpm: number, load: number, master: number)
	for _, l in layers do
		local w = window(rpm, l.lo, l.rpmRef, l.hi)
		local loadGain = if l.onLoad then math.sqrt(load) else math.sqrt(1 - load)
		l.player.Volume = master * w * loadGain
		l.player.PlaybackSpeed = math.clamp(rpm / l.rpmRef, 0.5, 2)
	end
end
```

All loops start together, looping, at volume 0, when the car spawns or enters audio range; only volumes and speeds change per frame. Starting and stopping loops on the fly causes clicks and load delays.

**Smoothing.** Smooth `rpm` and `load` with dt-correct exponential smoothing (time constant 50 to 120 ms) before they reach audio, or input jitter becomes audible warble.

## 3. Tyres: slip, surface and landings

- **Skid** layer: a looped screech whose volume follows the maximum lateral slip of the grounded wheels above a threshold (screech only after real sliding; a little noise at low slip reads as grip). Pitch rises slightly with slip and speed.
- **Rolling** layer: road noise per surface, volume from speed, crossfaded by the dominant material under the wheels (asphalt hum, gravel crunch, grass swish). Gravel and dirt also deserve a light spray of one-shot stones.
- **Landings and bumps**: one-shot thumps from a sudden compression of the suspension (suspension length velocity above a threshold), volume from impact speed.
- **Wind**: a speed-driven layer that dominates at top speed; it carries the sense of speed when the engine sits near redline ([[Chase Cameras and Speed Effects for Vehicles]]).
- **Collisions**: impact one-shots chosen by impulse; rate-limit to about 6 per second per car, or a car scraping a wall machine-guns sounds.

## 4. Routing with the Audio API

For the local driver, a 2D (non-positional) mix is usually better: the camera is behind the car and positional panning around the listener is unstable. For other cars, positional.

| Car | Routing |
|---|---|
| Local driver | `AudioPlayer`s wired straight to a Vehicle bus fader, then to the output; no emitter |
| Other cars | `AudioPlayer`s into an `AudioEmitter` on the chassis; heard via the listener; Vehicle bus via its listener group |

See [[The Audio API - Players Emitters Wires and Effects]] for bus and listener wiring (**Roblox docs**: https://create.roblox.com/docs/audio/api). With legacy `Sound`, parent sounds to the chassis for other cars and to a non-positional parent (a `Sound` not under a `BasePart` or `Attachment` plays without position) for the local driver, all in a `Vehicles` `SoundGroup`.

Doppler: do not rely on engine Doppler; if you want it, compute radial velocity relative to the listener and nudge `PlaybackSpeed` by a small factor (clamp to a few percent) on other cars only.

## 5. Replication: who computes what

Audio runs on every client from replicated state. Never send per-frame audio remotes.

- The driver owns the car, so its physics replicates. Other clients can derive speed and approximate slip from the chassis' replicated `AssemblyLinearVelocity` and orientation.
- RPM, gear and throttle are not physics. Publish them as **attributes on the car** written by the server from validated driver input at low frequency (5 to 10 Hz), or have the driver send them on an `UnreliableRemoteEvent` that the server relays with distance filtering. Smooth on receipt.
- **LOD**: within 30 to 60 studs, full layer set; beyond, a single mid loop plus wind; beyond about 200 studs, nothing. Limit simultaneously audible remote cars to the nearest 4 to 6 (**Rule of thumb**; voice limits in [[Spatial Audio and Mixing]]).

## 6. Tuning order

1. Idle and a slow rev up and down with no movement (revving in neutral). If this sounds wrong, nothing else will save it.
2. Full-throttle acceleration through all gears, then lift-off.
3. Cruise at constant speed (load around 0.3).
4. Drift: slip layer and engine load change at once.
5. Top speed: wind versus engine balance.
6. Ten cars in a pack: remote LOD and voice limits.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| One loop pitched over the whole RPM range | Chipmunk top end, mud at idle | 3 to 4 loops with windowed crossfades |
| RPM proportional to speed | Endless rising whine | Gear model or banded sawtooth |
| Ignoring load | Lift-off sounds identical | On-load and off-load sets |
| Starting/stopping loops per frame | Clicks, delays | Start all once; change volumes |
| Raw input to pitch | Warbling engine | Smooth rpm and load |
| Per-frame audio remotes | Bandwidth spikes | Attributes at 5 to 10 Hz or relayed unreliable events |
| Full mix for every remote car | CPU and voice exhaustion | Distance LOD and a car cap |

## Checklist
- [ ] Vehicle model exposes rpm, load, slip, grounded and surface per frame.
- [ ] Engine uses windowed RPM layers with on/off-load sets and an idle loop.
- [ ] Tyre skid, rolling-by-surface, landing and wind layers in place.
- [ ] Local driver mix 2D; remote cars positional with LOD.
- [ ] Non-physics state replicated at low rate and smoothed.
- [ ] Tuned in the six-step order; pack test with 10 cars.

## See also
[[Cars with Constraints - Suspension Steering and Drive]] · [[Genre Playbook - Racing and Driving]] · [[Sound Design for Games]] · [[Spatial Audio and Mixing]] · [[The Audio API - Players Emitters Wires and Effects]] · [[Audio Pipeline]]

## Connected notes
<!-- auto-links:start -->
[[Chase Cameras and Speed Effects for Vehicles]] · Sound Design Pitfalls - Reused Ids Onsets and Layered Loops · Physics and Vehicles Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Sound Fundamentals]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Combat Sound Design and Feedback]]
<!-- related:end -->
