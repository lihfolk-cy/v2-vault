---
tags: [procedural, ik, feet, ground, slopes, stairs, raycast, luau, type/guide, area/animation, level/advanced, api/Humanoid]
---
# Foot Placement and Ground IK

<!-- tldr:start -->
> [!tldr] TL;DR
> - Feet glued to the ground during a jump: no contact weight, or IK not disabled in air -> weight by animated foot height; disable on air states
> - Whole body floats on slopes: hips never lowered -> drop the pelvis by the lowest foot's deficit
> - Body bobs up and down climbing stairs: pelvis offset unsmoothed -> asymmetric rates or a spring
>
> Cost: TL;DR ~130 tok · whole note ~3.6k tok. Read more: ## The algorithm (per frame, after the Animator) · ## Bodies on the ground: the ground-fit clamp · ## Common mistakes
<!-- tldr:end -->

Every walk, idle and attack clip is authored on a flat floor. The world is not flat. On a slope one foot floats and the other sinks; on stairs feet hang in the air over step edges; a corpse on a hillside lies half underground. Ground IK fixes this at runtime: find the real ground under each foot, lower the hips so the low foot can reach, bend the knees, and tilt the feet to the surface. This note covers the live-character version and the "body on the ground" version the reference project used for deaths.

## The model: what the clip assumes

A Humanoid holds its root at `HipHeight` above the floor it detects. On R15 that is the gap between the floor and the bottom of the HumanoidRootPart, so the clip's implied floor is

```
floorY = hrp.Position.Y - hrp.Size.Y / 2 - humanoid.HipHeight
```

In the authored pose, a planted sole sits at `floorY`. Ground IK measures how far the *real* ground under each foot is from `floorY` and corrects only that difference. That keeps the clip's own lifts and steps: a foot raised 0.8 studs in the clip stays 0.8 studs above whatever ground is under it.

(The reference project's characters are 1.6x scale, about 9 studs tall with the hips about 3.5 studs above ground; R15 legs are short, which is why its jog and run need flight phases. Body scale changes these numbers: always read them from the rig.)

## The algorithm (per frame, after the Animator)

Run in `PreSimulation`, with your own FK of this frame's animated pose (part CFrames are still last frame's there; see [[Procedural Animation]]).

1. **Animated sole points.** For each foot, the sole point of the animated pose and its height above `floorY`, `h_anim`.
2. **Contact weight.** Feet that are in the air in the clip must not be pulled down. `w = 1 - smoothstep(0.15, 0.6, h_anim)` (studs at scale 1; rule of thumb) fades the correction out as the clip lifts the foot.
3. **Ground probe.** Cast down from above the foot: origin `sole + up * rayUp`, direction `-up * (rayUp + rayDown)`. `rayUp` must clear a step you might be standing below (about the step height plus a margin); `rayDown` limits how far a foot will reach into a hole (about half the leg length).
4. **Offset per foot.** `delta = hit.Y - floorY` (positive = ground higher than the clip assumed).
5. **Pelvis drop.** The hips can only go *down* to help: `drop = max(0, -min(deltaL * wL, deltaR * wR))`, plus any amount a foot target is out of reach. Raising the hips for a high foot would lift the other foot off the ground; the high leg bends its knee instead. Smooth the drop (a critically damped spring, or rise and fall at different rates).
6. **Foot targets.** `targetSole = animSole + up * (delta * w)`, with the hips lowered by `drop`.
7. **Foot tilt.** Rotate the foot so its up axis follows the surface normal, limited (rule of thumb 25-35 degrees) and weighted by `w`.
8. **Solve each leg** with two-bone IK (see [[Two-Bone IK Math]]) and blend the result over the animated leg by `w`.

### Code

```lua
--!strict
-- Ground IK for an R15 character. Uses TwoBone from the Two-Bone IK Math note.
-- Call from RunService.PreSimulation (after the Animator has written this frame's pose).
local TwoBone = require(script.Parent.TwoBone)

local RAY_UP, RAY_DOWN = 2.5, 2.5      -- studs at scale 1; multiply by body scale
local MAX_TILT = math.rad(30)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

type Leg = { chain: TwoBone.Chain, foot: BasePart, hip: Instance, knee: Instance, ankle: Instance, plant: Vector3? }

local function smoothstep(a: number, b: number, x: number): number
	local u = math.clamp((x - a) / (b - a), 0, 1)
	return u * u * (3 - 2 * u)
end

local function probe(char: Model, at: Vector3, scale: number): RaycastResult?
	params.FilterDescendantsInstances = { char }
	local up = Vector3.yAxis
	return workspace:Raycast(at + up * RAY_UP * scale, -up * (RAY_UP + RAY_DOWN) * scale, params)
end

-- frames: this frame's FK (part -> CFrame) of the animated pose, root joint included.
-- dropState: { value: number } smoothed pelvis drop. Returns nothing; writes Transforms.
local function groundLegs(char: Model, hum: Humanoid, hrp: BasePart, rootJoint: Instance,
	legs: { Leg }, frames: { [BasePart]: CFrame }, dropState: { value: number }, dt: number, scale: number)
	local floorY = hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
	local up = Vector3.yAxis
	local want = 0
	local plan = {}
	for i, leg in legs do
		local footCF = frames[leg.foot]
		local sole = footCF.Position - footCF.UpVector * (leg.foot.Size.Y / 2)
		local hAnim = sole.Y - floorY
		local w = 1 - smoothstep(0.15 * scale, 0.6 * scale, hAnim)
		local hit = if w > 0.001 then probe(char, sole, scale) else nil
		local delta = if hit then hit.Position.Y - floorY else 0
		plan[i] = { footCF = footCF, w = if hit then w else 0, delta = delta, normal = if hit then hit.Normal else up }
		want = math.max(want, -delta * plan[i].w)     -- only lower the hips for a low foot
	end
	-- pelvis: drop fast, recover slower (no bob when stepping onto a ledge)
	local rate = if want > dropState.value then 12 else 5
	dropState.value += (want - dropState.value) * (1 - math.exp(-rate * dt))
	local drop = dropState.value

	-- lower the root joint in world-vertical terms
	local c0 = if rootJoint:IsA("Motor6D") then rootJoint.C0 else (rootJoint :: AnimationConstraint).Attachment0.CFrame
	local J = hrp.CFrame * c0
	local rj = rootJoint :: any
	rj.Transform = CFrame.new(J.Rotation:Inverse() * Vector3.new(0, -drop, 0)) * rj.Transform
	local lowered = CFrame.new(0, -drop, 0)               -- world-space shift of everything below the root

	for i, leg in legs do
		local p = plan[i]
		if p.w > 0.001 then
			-- tilt the foot toward the surface normal, limited
			local n = p.normal
			local ang = math.min(math.acos(math.clamp(n:Dot(up), -1, 1)), MAX_TILT) * p.w
			local axis = up:Cross(n)
			local tilt = if axis.Magnitude > 1e-4 then CFrame.fromAxisAngle(axis.Unit, ang) else CFrame.identity
			local target = (lowered * p.footCF) + up * (p.delta * p.w + drop)   -- undo the drop for the foot itself
			target = CFrame.new(target.Position) * tilt * target.Rotation
			local hipParent = lowered * frames[(leg.hip :: any).Part0]            -- the solved (lowered) pelvis
			local Th, Tk, Ta = TwoBone.solve(leg.chain, hipParent, target, hrp.CFrame.LookVector, 0)
			local hj, kj, aj = leg.hip :: any, leg.knee :: any, leg.ankle :: any
			hj.Transform = hj.Transform:Lerp(Th, p.w)
			kj.Transform = kj.Transform:Lerp(Tk, p.w)
			aj.Transform = aj.Transform:Lerp(Ta, p.w)
		end
	end
end
```

Notes on the code:

- `lowered * p.footCF` moves the animated foot down with the hips; adding `drop` back (plus the ground delta) puts it on the real ground. The low foot ends exactly on the ground; the high foot's knee bends.
- The knee's swivel reference is the character's forward direction, so knees point forward. For bow-legged creatures use a per-leg reference.
- Build each leg's chain with `TwoBone.chain(hip, knee, ankle, -1, 0.02, 2.6)` (knees bend with negative X on standard R15; verify on your rig) and rebuild it when body scale changes. The project re-read leg geometry every second because scaling lands after spawn.
- Blending with `Lerp` toward the solved Transforms is safe for weights; the clip's leg motion returns smoothly as `w` drops in the swing phase.

## Slopes

| Slope | Behaviour | Rule |
|---|---|---|
| Under about 10 degrees | barely visible | tilt only, no drop needed |
| 10-35 degrees | the textbook case | drop + tilt; the uphill knee bends |
| Over about 40 degrees | it is a wall or a prop edge, not a floor | ignore it (the reference project treated a fitted plane steeper than 40 degrees as flat) |

Uphill walking looks better with a forward lean and shorter strides; downhill with a back lean. That is a locomotion concern, not IK: see [[Procedural Gait and Footstep Planning]].

## Stairs and edges

Stairs break the one-ray-per-foot model:

- **Half on, half off.** A ray at the foot centre misses a step the toe is standing on. Cast two rays (heel and toe) and use the higher hit, or use `workspace:Spherecast(origin, radius, direction, params)` with a radius near the foot's half-width (the API limits radius to 256 and distance to 1,024 studs) so the probe cannot fall through cracks.
- **The root pops up each step.** The Humanoid snaps its root up as it climbs. A fast drop rate and a slower recovery (the code above uses 12 and 5 per second, rule of thumb) hides it; a spring on the pelvis offset is better still.
- **Feet slide up step edges.** Re-probing every frame while the foot is planted lets it creep along a step's nosing. **Latch the plant**: when a foot's weight first rises above about 0.9, store the hit point and keep using it until the foot lifts again. The reference project's foot-plant layer latched the planted sweep "per step" for exactly this reason (see [[Procedural Gait and Footstep Planning]]).
- **Moving platforms.** Store the latched point in the platform part's local space (`part.CFrame:PointToObjectSpace(hit)`) and convert back each frame.

## When to turn it off

Fade the IK weight to 0 over 0.1-0.2 s when:

- the Humanoid is airborne (`Freefall`, `Jumping`), swimming, climbing, seated, ragdolled or platform-standing;
- a clip that owns the legs is playing (a kick, a kneel, a cinematic), unless it was authored for ground IK;
- the character is far away (LOD: the effect is invisible past 60-100 studs).

The reference project's procedural locomotion handed climbing, swimming, seated, ragdoll and platform-standing states back to the default Animate script entirely, and its foot-plant layer eased out "for any action / air".

## Bodies on the ground: the ground-fit clamp

A different problem with the same tool: a death clip authored on flat ground, played on a slope, buries half the body. The reference project's enemy layer solved it for every enemy family (bipeds, crawlers, floaters, flyers) at runtime:

1. **Sample the ground once per need**, not per frame: a 5 x 5 grid of downward rays over the body's footprint (half-size = 0.75 x the largest body dimension + 1 stud), starting above the body (`centre.Y + max(halfSize * 2, 20)`) and casting 400 studs down. A ray that hits an invisible (transparency 0.9 or more) or non-colliding part is re-cast from the hit, up to 6 times, so water planes and effects do not count as ground. Re-sample only when the body moves more than 0.45 x the half-size from the last sample centre.
2. **Fit a plane** by least squares to the 25 heights. If the fitted normal is steeper than 40 degrees, use flat instead.
3. **Tilt a lying body** onto the plane, scaled by how far the death clip has progressed (0 standing, 1 lying), about the ground point under the body's centre.
4. **Measure clearance**: FK the posed body, take every corner of every visible part, and compare with the ground grid (bilinear interpolation inside the grid, the fitted plane outside it). The most negative value is how deep the body is.
5. **Lift**: `need = max(0, 0.06 - clearance)`; the lift rises instantly to `need` but falls back at most 6 studs/s, so a limb swinging past the ground does not make the body flicker.

Measured effect: 18 death clips ground-fitted offline plus this runtime clamp took the worst penetration from -9.37 studs to 0 or above. A later pass fitted 205 of 304 clips, worst -7.79 to -0.17, with loops kept seamless. `HipHeight` was also wrong on 17 enemy templates, which no IK can fix. Skinned (bone) rigs used a smaller "bone adapter": a 3 x 3 ground grid, lift the Root bone by the deepest bone minus a skin pad.

The offline counterpart (shifting a clip's root so the lowest foot touches the floor at bake time) is in [[Ground Fitting Pipeline]]. The spec baker did the same per key: it shifted the lower torso so the lowest foot rested on the floor unless a key was marked airborne, and kept root drops shallow (root y of -1.0 or above) because deeper drops pushed a foot 1-2.5 studs through the floor.

## Performance

- Two rays per character per frame (four with heel and toe) is cheap; 40 characters with spherecasts is not free. Gate by distance and skip off-screen characters.
- Reuse one `RaycastParams`; update its filter list only when characters spawn or leave.
- The death clamp samples 25 rays once and reuses the grid while the body stays put.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Feet glued to the ground during a jump | no contact weight, or IK not disabled in air | weight by animated foot height; disable on air states |
| Whole body floats on slopes | hips never lowered | drop the pelvis by the lowest foot's deficit |
| Body bobs up and down climbing stairs | pelvis offset unsmoothed | asymmetric rates or a spring |
| Foot creeps along a step edge | re-probing a planted foot | latch the plant point per step |
| Ray hits the character's own leg | filter missing | exclude the character |
| Feet sink on transparent water planes or effects | ray accepted any part | skip invisible / non-colliding hits and re-cast |
| Corpse flickers half underground | lift recomputed instantly both ways | rise at once, settle slowly |
| Correct on small avatars, wrong on big ones | constants in studs not scaled | multiply by body scale; re-read geometry |

Related: [[Two-Bone IK Math]], [[Procedural Gait and Footstep Planning]], [[Procedural Death Knockdown and Hit Reactions]], [[IKControl Reference]], [[Ground Fitting Pipeline]], [[Locomotion Systems]].

## Connected notes
<!-- auto-links:start -->
[[Snippets - IK]] · [[Inverse Kinematics]] · [[Humanoid States and Animation]] · [[Animating Creatures and Monsters]] · [[Raycasts Shapecasts and Spatial Queries]] · Skeleton Library · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[R15 Run Cycle Key Poses]] · [[Ragdolls and Physics-Based Animation]] · [[Locomotion and Melee Reference Numbers]] · [[Scale and Animation]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Enemy and NPC Animation]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[LihFolk R15 Keyframe Pipeline]]
<!-- related:end -->
