---
tags: [procedural, locomotion, gait, feet, cadence, foot-slide, luau]
---
# Procedural Gait and Footstep Planning

<!-- tldr:start -->
> [!tldr] TL;DR
> - Feet slide at top speed: rate clamp on the run clip -> foot-plant layer, or a faster clip, or accept and hide with dust
> - Feet pedal frantically: cadence tied linearly to speed -> cap the cadence; lengthen the stride instead
> - Legs pop when walk blends to run: clips out of phase -> shared phase, same contact timing in all cycles
>
> Read more (16 KB note): ## The shipped procedural gait · ## The foot-plant layer: authored style, planted feet · ## Common mistakes
<!-- tldr:end -->

Foot slide is the most visible locomotion bug in Roblox games: the character runs at 64 studs/s while its feet pedal at the speed the clip was authored for. Rate-matching the clip helps until the rate is clamped; authoring more clips helps until the character changes size. A procedural gait solves it from first principles: decide when each foot is on the ground, keep it exactly still in the world while it is, and swing it to the next spot while it is not. This note derives the maths, gives the formulas one production game shipped (the reference project), and shows the middle path that keeps authored style: a legs-only foot-plant layer over authored clips.

## Gait vocabulary

| Term | Meaning |
|---|---|
| **Cycle** | one full repeat: left step + right step |
| **Cadence `f`** | cycles per second |
| **Stride per cycle `L`** | ground covered in one cycle: `L = v / f` |
| **Duty factor `beta`** | fraction of the cycle a foot is planted (stance) |
| **Sweep** | how far a planted foot travels backward relative to the hips during its stance |
| **Double support** | both feet planted: happens when `beta > 0.5` (walking) |
| **Flight** | neither foot planted: happens when `beta < 0.5` (running) |

## The no-slide condition

During stance the foot must be still in the world, so relative to the hips it moves backward at exactly the ground speed `v`. It covers `sweep` in `beta / f` seconds:

```
sweep / (beta / f) = v
=> sweep = beta * v / f = beta * L
```

So you can choose any two of cadence, sweep and duty factor, and the third follows. The constraint that forces the choice is the leg itself: the sweep cannot exceed what the leg can reach. With the hip `hy` above the sole and usable leg length `Rr` (slightly less than full length, so the knee never locks), the foot can be at most `sqrt(Rr^2 - hy^2)` in front of or behind the hip:

```
sweepMax = 2 * sqrt(Rr^2 - hy^2)
```

Two consequences:

- **Lowering the hips lengthens the possible sweep.** A bent-knee run is not just style; it buys reach.
- **At high speed with a capped cadence, `L` grows, `sweep` hits `sweepMax`, and `beta = sweep / L` falls below 0.5.** The gait gains a flight phase: a run. You never need a separate "run mode"; it emerges.

R15 legs are short relative to the body (in the reference project, hips about 3.5 studs above ground at 1.6x scale), so jogs and runs need flight phases and walks need double support.

## The shipped procedural gait

The reference project's player animator replaced its locomotion legs with this gait for a period. Every number below is from it.

**Cadence rises with speed, clamped:**

```
f(v) = clamp(1.45 + 0.0105 v, 1.55, 2.75)   cycles/s
```

| Speed (studs/s) | Cadence | Stride per cycle `L = v / f` |
|---|---|---|
| 11 | 1.566 | 7.0 |
| 22 | 1.681 | 13.1 |
| 64 | 2.122 | 30.2 |
| 120 | 2.71 | 44.3 |

(The cap of 2.75 is reached near 124 studs/s.)

**Hips, sweep and duty factor:**

```
mv      = clamp(v / 10, 0, 1)                                 -- 0 standing, 1 moving
drop    = legLen * (0.12 + 0.06 * clamp(v / 60, 0, 1)) * mv  -- bent knees: lower hips, longer reach
Rr      = 0.975 * legLen
hy      = hip height above the sole at rest - drop
sweep   = min(0.62 * L, 2 * sqrt(Rr^2 - hy^2))
beta    = clamp(sweep / L, 0.02, 0.62)
```

`0.62` caps the duty factor so even a slow walk has a swing long enough to read.

**Bob:** two dips per cycle (one per step), lowest at mid-stance:

```
bobAmp = legLen * (0.025 + 0.02 * clamp(v / 60, 0, 1)) * mv
rootY  = -drop - bobAmp * cos(4 pi (phase - beta / 2))
```

At `phase = beta/2` (the left foot's mid-stance) the cosine is 1 and the body is at its lowest; the right foot's mid-stance half a cycle later is another minimum. That is the correct "compress on the planted leg" read. (Some styles want the opposite for walks, highest at mid-stance like an inverted pendulum. Choose by eye.)

**Each foot**, with the right foot half a cycle behind (`q = phase + 0.5` for the right):

- **Stance** (`q < beta`): `z = zc - sweep/2 + sweep * (q / beta)`, `y = 0`, foot flat. With `-Z` forward, the foot lands in front and is carried back at exactly `v`.
- **Swing** (`q >= beta`), with `u = (q - beta) / (1 - beta)`:
  - forward: `z = zc + sweep/2 - sweep * smoothstep(u) + kick * sin(pi u) * (1 - u) * 1.6`, where `kick = 0.45 * legLen * clamp(v/60, 0, 1)` throws the heel back early in the swing at speed
  - height: `y = lift * sqrt(sin(pi u))`, `lift = legLen * (0.12 + 0.38 * clamp(v/70, 0, 1)) * mv`. The square root leaves the ground with a vertical tangent, so there is no toe scuff at lift-off or touchdown
  - toe: pitched down by `toe * sin(pi u)`, `toe = rad(20 + 30 * clamp(v/80, 0, 1)) * mv`

**Carriage on top:** a forward lean of 4 degrees at the root plus 3 at the waist for a run (5 + 4 for a sprint: the "+7 / +9 degrees" in the notes), the neck tilted back 4-5 degrees to keep the eyes level, and the free arm swinging opposite the same-side leg about a forward centre (30 degrees for run, 36 sprint, amplitude 14 / 10, elbow bent 80 / 88, abducted 10).

Each leg was then solved with 3D two-bone IK on the character's own joint attachments (so it worked on Motor6D and AnimationConstraint rigs at any body scale) with the hip split into pitch and roll so the foot could land under the hip even when the pelvis swayed.

**Measured result:** foot slide about 0 from 12 to 120 studs/s, where it had been about 90% of speed. That gait was later removed when the owner switched to authored clips; the foot-plant layer below replaced it.

### Minimal Luau gait

```lua
--!strict
-- Foot targets for a procedural gait, in the root's frame (-Z forward). Feed them to a two-bone leg solver.
local function smoothstep(u: number): number return u * u * (3 - 2 * u) end

export type GaitOut = { rootY: number, left: { z: number, y: number, pitch: number }, right: { z: number, y: number, pitch: number } }

local function gait(v: number, phase: number, legLen: number, hipAboveSole: number, zc: number, out: GaitOut)
	local mv = math.clamp(v / 10, 0, 1)
	local f = math.clamp(1.45 + 0.0105 * v, 1.55, 2.75)
	local L = v / f                                          -- studs per cycle
	local drop = legLen * (0.12 + 0.06 * math.clamp(v / 60, 0, 1)) * mv
	local Rr = legLen * 0.975
	local hy = hipAboveSole - drop
	local smax = if hy < Rr then 2 * math.sqrt(Rr * Rr - hy * hy) else 0
	local sweep = math.min(L * 0.62, smax)
	local beta = if L > 1e-3 then math.clamp(sweep / L, 0.02, 0.62) else 0.62
	local bobAmp = legLen * (0.025 + 0.02 * math.clamp(v / 60, 0, 1)) * mv
	out.rootY = -drop - bobAmp * math.cos(4 * math.pi * (phase - beta / 2))
	local kick = legLen * 0.45 * math.clamp(v / 60, 0, 1)
	local lift = legLen * (0.12 + 0.38 * math.clamp(v / 70, 0, 1)) * mv
	local toe = math.rad(20 + 30 * math.clamp(v / 80, 0, 1)) * mv
	for side, foot in { left = out.left, right = out.right } do
		local q = (phase + (if side == "right" then 0.5 else 0)) % 1
		if q < beta then
			foot.z, foot.y, foot.pitch = zc - sweep / 2 + sweep * (q / beta), 0, 0
		else
			local u = (q - beta) / (1 - beta)
			local sn = math.sin(math.pi * u)
			foot.z = zc + sweep / 2 - sweep * smoothstep(u) + kick * sn * (1 - u) * 1.6
			foot.y = lift * math.sqrt(sn)
			foot.pitch = -toe * sn
		end
	end
end

-- The phase accumulator: advance by cadence, never reset on gait changes.
-- phase += f(v) * dt; phase %= 1
```

## Rate-matched clips: why they slide anyway

A clip has a `GroundSpeed`: the speed at which its planted feet move backward. Playing it at `rate = v / GroundSpeed` removes slide exactly, as long as the rate is not clamped. Every real system clamps it, because a clip played at 3x looks frantic and at 0.3x looks like a moonwalk.

The reference project's two locomotion sets show both sides:

| Set | Clips (GroundSpeed) | Chooser | Measured slide |
|---|---|---|---|
| Universal set | Walk 11, Jog 22 (= base walk speed), Run 64 (= sprint) | `< 1` idle, `< 16` walk, `< 38` jog, else run; `rate = speed / GroundSpeed` clamped; stride phase kept across swaps | at most 1.8 studs/s at 11, under 1 at 22 and 64 |
| Original set | Walk, Run | Walk at `clamp(speed / 16, 0.6, 1.8)`, Run above base walk speed + 6 at `clamp(speed / 26, 0.7, 1.5)`, 0.2 s fades | known to slide at sprint (about 64 studs/s) because the run rate caps at 1.5x |

The slide of a clamped clip is simply `|v - rate * GroundSpeed|`. If the run's ground speed is the 26 its rate formula implies, the cap gives 1.5 x 26 = 39 studs/s of foot travel; at 64 studs/s the feet slide about 25 studs/s: unmissable.

Size makes it worse. Authored clips at a 1.6x character scale planted only about 5-8 studs per cycle against strides of 9.6 / 15.2 / 22.4 studs in the movement model, so feet slid 50-75% by design, about 95% at 22-120 studs/s, and matching cadence to speed would have meant 1.45 cycles/s at 22 up to 5.4 at 120: frantic.

### Keep the phase across gait changes

Crossfading Walk to Jog only looks right if both clips are at the same point of the cycle (left foot down in both). Author every cycle with the same contact timing (left touchdown at 0), track one normalised phase `phase` in [0, 1), and when a clip starts, set its `TimePosition = phase * Length`. The reference project crossfaded its walk, jog and run at about 16 and 38 studs/s "on one shared phase".

### Bigger creatures step slower

For geometrically similar animals, the natural speed of a gait scales with the square root of leg length (the Froude number `v^2 / (g * legLength)` stays constant), so cadence scales with `1 / sqrt(size)`. The reference project slowed scaled enemies' walk clips to `0.85 / sqrt(scale)`. It deliberately did not sync enemy gaits to their movement speeds per zone: measured strides were 2-4x slower than the defined move speeds, and syncing would "play frantic". Sometimes a little slide on a monster is the better trade.

## The foot-plant layer: authored style, planted feet

The middle path the reference project built: keep the authored clips for everything (upper body, root, arms, the *shape* of the leg motion) and fix only the stance. A legs-only layer (hips, knees, ankles) over the authored Walk / Run / Sprint blend, on the ground and moving, outside actions:

1. **Read the authored foot path.** For the current blend of the three clips, sample 64 points through the cycle: each sole's forward position, height and pitch, in the root frame. Cache it until the blend weights move by 0.05.
2. **Find the authored stance.** The longest run of samples within `0.12 x scale` of the foot's lowest point is its contact. Its start is the touchdown phase `a0`; its length is the authored duty factor (capped at 0.7).
3. **Latch the plant per step.** At each touchdown, compute this step's sweep: the authored duty factor times the stride `L = v / cadence`, but no more than 0.9 x the leg's reachable span, where reach allows the heel to lift up to 40 degrees about the toe (more reach when the authored hips ride high). The stance centre is moved toward the hip only as far as that sweep needs. These values are **latched** until the next touchdown, so the planted foot moves at exactly ground speed even while the authored hips twist and bob.
4. **Stance:** the toe moves back at ground speed. If the leg cannot reach with the foot flat, bisect (10 steps) for the smallest heel lift, up to 40 degrees, that it can reach.
5. **Swing:** the authored swing, **time-stretched** over the rest of the cycle, with its start and end moved onto the latched lift-off and touchdown points. Height is kept at least `footHalfLength x 0.8 x sqrt(sin(pi u))` above the floor, plus whatever the foot's pitch needs, so the toe never scuffs.
6. **Cadence cap:** the shared gait phase advances at `min(v / authoredStride, 3)` cycles/s. Faster than 3 cycles/s, the stride lengthens and the flight grows instead.
7. **Solve** each leg with two-bone IK and blend over the authored legs by the layer weight; the weight eases out for any action or when airborne.

**Measured:** slide 0.00-0.01 (mean, whole-sole and toe contact) from 9.6 to 120 studs/s, against 51-90% for the authored clips alone. When the universal clip set was played with the original set's rate clamps, slide without the layer was 2-6% of speed up to 80 studs/s and 24% at 120 (from the run rate clamp); with the layer, 0.

The layer was shipped as a toggle and was off at the time of writing, which is itself a lesson: a technically perfect fix still needs the owner to like how it reads.

## Footsteps and other events

- **Step sounds** from the gait, not from timers: the reference project fires a step when the planted foot swaps sides, with a cadence-based fallback so a step is never skipped when contact detection is ambiguous; volume and pitch scale with speed.
- **Dust and prints** at the latched plant point, not the animated foot (which may be mid-correction).
- **Clip markers** (`Step`) are fine for enemies that play clips at fixed rates.

## Footstep planning for NPCs

Player gaits react to input every frame. NPC gaits can plan:

- **Predict the plant.** The next foot lands where the hips will be at touchdown plus the lateral offset: `plant = root + velocity * timeToTouchdown + side * stanceWidth`. Raycast there in advance; if it is a hole or a wall, shorten or lengthen the step (change the cadence for that step only).
- **Turning on the spot.** Rotate the root, keep both feet latched, and trigger a step when a foot's yaw relative to the root exceeds a threshold (rule of thumb 35-50 degrees) or its distance from its rest spot exceeds about a third of the leg length.
- **Stopping.** When speed falls below about 1 stud/s, finish the current swing and plant both feet under the hips rather than freezing mid-stride.

## Lean, turn and acceleration

The body leans into acceleration and into turns. A rule-of-thumb model: `leanForward = k1 * accelForward`, `leanSide = k2 * speed * yawRate` (the centripetal acceleration), both clamped and spring-smoothed (see [[Springs Damping and Smoothing]]). Apply at the root joint with the neck counter-rotating about half as much, so the head stays level. The same physics drives banking in flight ([[Flight Flocks and Path Animation]]).

One related engine gotcha from the project: a dash from standstill needed `RunService:BindToRenderStep` after the control script for the dash's duration, calling `humanoid:Move(dir)`, so the Humanoid controller stopped braking against the dash's `LinearVelocity`.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Feet slide at top speed | rate clamp on the run clip | foot-plant layer, or a faster clip, or accept and hide with dust |
| Feet pedal frantically | cadence tied linearly to speed | cap the cadence; lengthen the stride instead |
| Legs pop when walk blends to run | clips out of phase | shared phase, same contact timing in all cycles |
| Toe drags at lift-off | swing height linear in time | `sqrt(sin(pi u))` or any curve with a vertical start |
| Planted foot jitters as hips twist | stance recomputed every frame from the animated hips | latch the sweep at touchdown |
| Knee locks straight at full stride | sweep beyond reach | limit the sweep, drop the hips, allow heel lift |
| Big monster scuttles | cadence not scaled with size | `1 / sqrt(scale)` |

Related: [[Locomotion Systems]], [[Custom Locomotion Controller Design]], [[Foot Placement and Ground IK]], [[Two-Bone IK Math]], [[Timing Spacing and Frame Charts]].

## Connected notes
<!-- auto-links:start -->
[[Scale and Animation]] · [[Snippets - IK]] · [[Snippets - Animation Controller Module]] · [[Animating Creatures and Monsters]] · [[Low-Poly Creature From a Flat Reference Sheet]] · [[Custom Character Controllers]] · [[Animation Start Here]]
<!-- auto-links:end -->
