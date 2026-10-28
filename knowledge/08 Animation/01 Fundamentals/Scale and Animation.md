---
tags: [fundamentals, scale, locomotion, rigs]
---
# Scale and Animation

Rotations do not care about size: a 90 degree elbow bend is 90 degrees on a tiny pet and on a 30-stud boss. Everything else does: root offsets, stride lengths, playback rates, IK lengths, camera distances, toss arcs, ground clearance. Roblox has two different ways to scale a character, and the Animator treats them differently, which is the source of the most confusing scale bugs ("the crouch works on the dummy and floats on players"). This note explains both mechanisms, what the Animator scales and what it does not, and how to keep motion believable at any size.

## Two ways to scale a character

| | Humanoid body scales | `Model:ScaleTo(factor)` |
|---|---|---|
| How | `NumberValue`s under the Humanoid: `BodyHeightScale`, `BodyWidthScale`, `BodyDepthScale`, `HeadScale`, `BodyTypeScale`, `BodyProportionScale` (or the matching `HumanoidDescription` fields) | One uniform factor on the whole model, around its pivot |
| Requires | `Humanoid.AutomaticScalingEnabled = true` for changes to resize parts and accessories | Any model |
| Non-uniform | Yes (height, width, depth separately) | No |
| `Model:GetScale()` afterwards | **1** | the factor |
| What the Animator does with clip translations | **Nothing**: applied literally | **Multiplied by the factor** |
| `HipHeight` | Recomputed by automatic scaling | Expected to scale with the model (verify on your rig) |

The docs for `Model` say the scale factor "is applied to joint offsets of animations played on an AnimationController under the model". One production project measured the same on its rigs: clip translation offsets are multiplied by `Model:GetScale()`, and on body-scaled characters (GetScale 1) they are applied literally.

### The trap this creates
That project's players were scaled to 1.6x through body scales (about 9 studs tall), so `GetScale()` was 1. Its offline baker authored at scale 1 and had to write every root offset **multiplied by 1.6**: "the Animator does not scale clip translations for characters sized through their body scales". A crouch baked at scale 1 dropped the hips 1/1.6 as far as it should and left the feet hovering. Meanwhile a QA tool that played clips on a dummy scaled with `ScaleTo(1.6)` saw offsets multiplied by 1.6 and had to divide them back.

**Rule:** know which mechanism your characters use, and author or convert translations accordingly:
- Body-scaled characters: store translations at the in-game size.
- `ScaleTo`-scaled models: store translations at scale 1; the Animator multiplies.
- Mixed fleets (NPCs scaled by `ScaleTo`, players by body scales): keep separate clip sets or convert at load.

## What scale does to each kind of motion

| Motion | Scales? | How to handle |
|---|---|---|
| Joint rotations | No | Nothing to do |
| Root (hip) translation: crouch, bob, jump lift | Yes, with size | See the rule above |
| Limb translations (should be none) | n/a | Keep limb joints rotation-only |
| Stride length | Yes, with leg length | Playback rate = speed / (authored ground speed x scale) |
| Cadence (steps per second) | Down with size, roughly `1 / sqrt(scale)` | See "Big things move slower" |
| Toss and jump arcs | Gravity must scale with the character, not the world | See "Gravity for animation" |
| IK lengths, reach | Yes | Read bone lengths from the rig every time; never hard-code |
| Camera offsets, ranges, hit radii | Yes | Multiply by character scale |
| Timing of attacks | Usually no (gameplay) | Keep combat timing in data, independent of size |

## Locomotion at scale

### Stride and rate
A walk authored so its feet move at `groundSpeed` studs/s at rate 1 on a scale-1 rig moves them at `groundSpeed * scale` on a scaled rig. The playback rate that keeps feet planted is:

```lua
local rate = currentSpeed / (groundSpeed * characterScale)
```

The default Animate script does a version of this: it divides by a height scale derived from `HipHeight / 2` (or `Character:GetScale()` when automatic scaling is off), so taller avatars play walk/run slower at the same speed (see [[The Default Animate Script]]).

### Measured: when strides do not match
In the same 1.6x game, authored gait clips had stride lengths of 9.6 / 15.2 / 22.4 studs per cycle (walk / jog / run after scaling), but the legs only actually planted about 5 to 8 studs per cycle; at the game's speeds the feet slid by 50 to 95% by design. Two fixes were built:
- A **procedural gait**: cadence `clamp(1.45 + 0.0105 * v, 1.55, 2.75)` steps per second, stance length = sweep / speed, two-leg IK on the joints' own attachments, bent-knee drop, bob and lean. Slide was about 0 from 12 to 120 studs/s (it had been about 90% of speed).
- A **foot-plant layer** over the authored clips: each foot follows the authored path, only the stance phase is pinned, the swing is time-stretched, cadence capped at 3 steps/s (faster means longer strides plus more air). Slide 0.00 to 0.01 from 9.6 to 120 studs/s.

R15 proportions matter too: legs are short (hip about 3.5 studs above ground at that 1.6x scale), so a fast jog and run need flight phases (both feet off the ground) and a walk needs double support. See [[Locomotion Systems]] and [[Procedural Gait and Footstep Planning]].

### Big things move slower: dynamic similarity
Animals of different sizes moving "the same way" keep a similar Froude number, `v^2 / (g * L)` with L the leg length. For the same gait, speed grows with `sqrt(L)`, stride grows with `L`, so **cadence falls as `1 / sqrt(L)`**. That is why giants look right with slow, heavy steps and why a scaled-up creature playing its normal-size walk at normal rate looks like a toy. One enemy system slowed a scaled enemy's walk to `0.85 / sqrt(scale)`. The same project found its enemy definitions' move speeds were 2 to 4 times faster than the clips' measured strides; syncing playback rate to them would have looked frantic, so they deliberately did not.

## Gravity for animation

`workspace.Gravity` defaults to 196.2 studs/s^2, which treats a stud as 5 cm. A default avatar of about 5 studs would then be 25 cm tall, so arcs computed with world gravity look floaty and toy-like. For **animated** arcs (a sword tossed and caught, a hop in a flourish), use gravity scaled to the character:

```
G_anim = 9.81 m/s^2 * (character height in studs / real height in metres)
```

One game used **47.6 studs/s^2**: 9.81 m/s^2 at an 8.7-stud avatar treated as a person of about 1.8 m. Its flourish tosses then read as real throws. Gameplay physics can keep world gravity; this is only for authored or procedural arcs.

## Model:ScaleTo details

- `ScaleTo(factor)` resizes and repositions all descendants around the pivot. It scales part sizes, `WeldConstraint` and `RopeConstraint` lengths, `HingeConstraint` velocities and forces, `ParticleEmitter` sizes and `Sound.RollOffMinDistance`, among others.
- The first call caches the original configuration for the session, so `ScaleTo(x)` then `ScaleTo(1)` restores it exactly with no drift.
- `GetScale()` returns the current factor (1 for new models). The Studio-only `Scale` property cannot be read or written from scripts.
- Factor must be positive and non-zero; no documented min or max.
- On characters under the Avatar Joint Upgrade, developers reported `Character:ScaleTo` broken in the Phase 2 rollout thread. Test it on upgraded characters before relying on it for players.

## Enemies, bosses and props

- Size multipliers for enemies and bosses are a gameplay tool; make sure clip root offsets, ground fitting and hit radii follow. One game applied size multipliers to enemies and bosses separately (bosses were not scaled along with regulars).
- Skinned creatures scaled with `ScaleTo` get their clip offsets scaled automatically; part-built ones too. Procedural offsets you add are **not** scaled for you: multiply by `GetScale()` yourself.
- Weapon rigs: one weapon pipeline gave each held weapon a `Scale` attribute on its root (Handle) and authored hinge clips at design scale.

## Cameras and effects

Everything framed around the character scales with it:
- One cinematic camera used an offset of (14, 9, 12) and a look point of (0, 3.5, -6) with FOV 42, all multiplied by character scale.
- Shot framing used body scale and real clip lengths.
- Hit-stop shakes, trail widths and VFX sizes usually scale with weapon size rather than character size; decide per effect.

## Reading the character's scale in code

```lua
--!strict
-- Returns a single "how big is this character" factor that works for both mechanisms.
local function characterScale(character: Model): number
	local s = character:GetScale() -- ScaleTo factor (1 if never scaled that way)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.AutomaticScalingEnabled then
		local h = humanoid:FindFirstChild("BodyHeightScale")
		if h and h:IsA("NumberValue") then
			s *= h.Value -- body-scaled characters report GetScale() == 1
		end
	end
	return s
end

-- Whether the Animator will scale this rig's clip translations for you.
local function animatorScalesOffsets(character: Model): boolean
	return math.abs(character:GetScale() - 1) > 1e-4
end
```

`BodyHeightScale` alone ignores `BodyProportionScale` and `BodyTypeScale`, which also change leg length; for precise stride maths measure the actual leg length from the rig (hip joint to ankle joint distance in the rest pose).

## Checklist
- [ ] Know whether your characters are body-scaled or `ScaleTo`-scaled; author translations to match.
- [ ] Root drops and lifts tested at the real in-game size.
- [ ] Locomotion rate divides by authored ground speed times scale.
- [ ] Big creatures slow their cadence (about `1 / sqrt(scale)`).
- [ ] Animated arcs use character-scaled gravity.
- [ ] IK reads bone lengths from the rig.
- [ ] Camera offsets and ranges multiplied by scale.
- [ ] Procedural offsets multiplied by `GetScale()` where the Animator would scale clip offsets.

## See also
[[How the Animator Really Behaves]] · [[The Default Animate Script]] · [[Locomotion Systems]] · [[Procedural Gait and Footstep Planning]] · [[Custom Characters and StarterCharacter]] · [[Humanoid States and Animation]] · [[Cameras and Cutscenes]]

## Nuances and edge cases

1. **Players bring their own scale.** Unless the experience forces body scales, every player's avatar arrives with its own height, width and proportion settings, and newer body types vary widely. A clip authored on one rig height plays on avatars from roughly child-sized to very tall. Rotations survive; root offsets, ground contact, weapon grips and hit radii do not automatically. Decide early whether to force scales in the experience's avatar settings (consistent gameplay, less self-expression) or support the range (more work, happier players).
2. **Scale is gameplay, not just looks.** A taller avatar with a bigger hitbox is easier to hit; a tiny one may fit through gaps. In competitive games, normalise hitboxes (a fixed-size collision box independent of avatar scale) even if the visual scale varies. Roblox's avatar settings can also constrain collision; check the current options in experience settings.
3. **Scale changes mid-session.** Growth mechanics (simulators that make the character bigger as it levels) rescale live. Cached values computed at spawn (ground speed times scale, camera distances, IK lengths) go stale. Listen for scale changes (the body scale values' `Changed` events, or your own attribute for `ScaleTo`) and recompute.
4. **Very large scales hit physics and camera limits.** At very large scales (a 50-stud character), default camera zoom limits, collision with map geometry, and network smoothing all behave worse. Raise `CameraMaxZoomDistance` for that player and test streaming radius, since a huge character can see past what is streamed in.
5. **Very small scales hit precision limits.** At tiny scales (pets at 0.2), root offsets in the clip become fractions of a stud and quantisation in compact clip formats becomes visible. Author tiny creatures at a larger scale and `ScaleTo` them down so the Animator scales their offsets.
6. **Phones and readability.** On a small screen, the difference between a 1x and a 1.2x character is barely visible; between a normal player and a 3x boss it is the whole read. Use scale contrast for importance (bosses, elites) and do not rely on subtle scale differences to convey information.
7. **Layered clothing at scale.** Layered clothing follows body scales, but extreme proportions can expose cage limits, especially with strong `BodyProportionScale` values. Test your clothing catalogue at the extremes you allow.

## Common mistakes in production

1. **Hard-coded hip height.** Symptom: custom avatars float or sink after a ground-fit or IK pass. Fix: read hip height from the Humanoid each time.
2. **Camera offsets tuned on one avatar.** Symptom: tall avatars get the camera inside their head in cinematics. Fix: multiply offsets by measured character height.
3. **Growth mechanic with cached locomotion rate.** Symptom: grown characters moonwalk. Fix: recompute on scale change.
4. **Hitbox from limb sizes.** Symptom: players with tiny avatars are hard to hit, complaints of unfairness. Fix: a fixed gameplay hitbox.
5. **Scaling a model with `ScaleTo` and also adjusting its clips' offsets.** Symptom: double-scaled crouches and jumps. Fix: pick one; the Animator already scales offsets under `ScaleTo`.

## Related decisions

- [[Avatar Body Types and Scale in Gameplay]]: the gameplay side of avatar scale and how to constrain it.
- [[HumanoidDescription and Outfit Systems]]: where body scale values come from and how to set them.
- [[Places Universes and Experience Settings]]: experience-level avatar settings that force or allow scales.
- [[Hitboxes and Hit Detection]]: fixed hitboxes independent of visual size.
- [[Genre Playbook - Simulators]]: growth mechanics that rescale characters live.
- [[Camera Systems]]: zoom limits and offsets for very large or small characters.
- [[Layered Clothing Creation Workflow]]: testing clothing at extreme proportions.
- [[Big Numbers Precision and Formatting]]: precision issues when values get very large or very small.

## Connected notes
<!-- auto-links:start -->
[[Retargeting Animations Between Rigs]] · [[Snippets - IK]] · [[R15 Rig Anatomy and Attachments]] · [[Foot Placement and Ground IK]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Animation Start Here]]
<!-- auto-links:end -->
