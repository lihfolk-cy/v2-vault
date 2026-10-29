---
tags: [procedural, runservice, motor6d, animationconstraint, transform, timing, hub, type/hub, area/animation, level/intermediate, api/Animator, area/physics]
---
# Procedural Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Procedural head turn does nothing on a character: write happens in `PreRender` or `Heartbeat` -> move it to `PreSimulation`
> - Works on an R6/old rig, does nothing on new avatars: code searches for `Motor6D` -> accept `AnimationConstraint` too
> - Head slowly spins away, worse when far from camera: compounding `Transform = Transform * R` on a joint nothing rewrites -> restore in `PreAnimation`, or compute from...
> - Joint lookup accepts `Motor6D`, `AnimationConstraint` and `Bone`.
> - Writes to animated joints happen in `PreSimulation`.
> - Overlays compose with the animated value (`R * A` or `A * R`) and cannot compound.
>
> Cost: TL;DR ~200 tok · whole note ~4.5k tok. Read more: ## What code can write · ## Composing with the Animator · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Procedural animation is motion computed by code every frame instead of read from a stored clip. In Roblox it is the layer that makes clips react: a head that follows the player, feet that stay planted on a slope, a blade that spins in the hand, a body that recoils from a hit, a dragon that banks into its turn. This note is the hub for the whole `04 Procedural` folder. It covers the part every technique shares and that most bugs come from: **where you write, when you write it, and how your write composes with the Animator's.**

If you only remember one thing: on an animated joint, write `Transform` in `RunService.PreSimulation`, compose it with what the Animator wrote, and never let your own write feed back into next frame's input.

## When to use procedural motion (and when not to)

| Situation | Clip | Procedural | Baked procedural (solve offline, store as clip) |
|---|---|---|---|
| Authored performance (a sword combo, an emote) | best | no | sometimes (IK clean-up) |
| Must react to the world (look at a target, feet on slopes, aim) | cannot | best | cannot |
| Never repeats exactly (bob, sway, flock, spin) | wasteful | best | no |
| Expensive maths that does not need to react (arm IK with clearance search) | n/a | too slow at runtime | best |
| Physics response (ragdoll, hit flinch) | approximates | springs or constraints | no |
| Many identical objects (foliage, floating rocks) | too heavy | best, batched | no |

The reference project (one live action game) used all three. Its player arms were **baked**: an offline solver searched 24 hand rolls x 36 elbow swivels per 60 Hz frame plus a clip-wide Viterbi pass, far too slow for runtime (see [[Elbow Poles Swivel and Joint Limits]] and [[Pipeline - Arm IK Baking and QA]]). Its feet, blade spins, tosses, hit reactions, deaths, props and flying creatures were **procedural at runtime**. It deliberately did not use `IKControl` because the clips were already baked, which is a valid choice, not a verdict on [[IKControl]] (see [[IKControl Reference]]).

Do not reach for procedural motion when an authored clip would read better. A procedural "attack" built from sines looks mechanical next to a keyed one. Procedural motion wins when it is *reacting* or when it is *cheap and endless*.

## What code can write

| Target | Property | Persists? | Overwritten by the Animator? | Typical use |
|---|---|---|---|---|
| `Motor6D` | `.Transform` | until rewritten | yes, every step, for joints a playing track keys | layered motion on animated rigs |
| `Motor6D` | `.C0` / `.C1` | yes (it is the rest offset) | no | grip offsets, rest-pose edits, legacy neck aim |
| `AnimationConstraint` | `.Transform` | until rewritten | yes | same as Motor6D on upgraded R15 avatars |
| `AnimationConstraint` | `C0` / `C1` | read-only aliases of its attachments | n/a | do not use; the docs say not to edit RigAttachment CFrames either |
| `Bone` | `.Transform` | until rewritten | yes | skinned meshes |
| `Weld` / `Motor6D` on a prop | `.C0` | yes | no (unless an Animator drives it) | held weapons, FX rigs, shard rings |
| Anchored `BasePart` / `Model` | `.CFrame`, `:PivotTo()` | yes | no | props, pets, doors, flocks |
| Many anchored parts | `workspace:BulkMoveTo()` | yes | no | foliage, debris fields |
| `IKControl` | `Target`, `Weight`, ... | yes | it overrides the animation on its chain | engine-solved IK |

Two facts from the official `AnimationConstraint` reference matter here:

- On experiences with the Avatar Joint Upgrade (the default for new experiences), R15 player characters spawn with `AnimationConstraint` joints instead of `Motor6D`. `IsA("Motor6D")` is false for them, so code that looks for `Motor6D` silently finds nothing.
- The docs recommend multiplying into `Transform` during `PreSimulation` instead of writing `C0`/`C1`, because it stacks with animation tracks and keeps retargeting intact.

The reference project measured this in practice: its live character rigs used `AnimationConstraint`, and "all procedural posing code must accept both joint types". Its tools read joint frames like this:

```lua
-- Returns the two joint frames for either joint type, in Part0 space and Part1 space.
-- Motor6D: Part1 = Part0 * C0 * Transform * C1:Inverse()
-- AnimationConstraint: the same formula with its attachments' CFrames in place of C0 / C1.
local function jointFrames(j: Instance): (CFrame, CFrame)
	if j:IsA("Motor6D") then
		return j.C0, j.C1
	end
	local c = j :: AnimationConstraint
	local a0, a1 = c.Attachment0, c.Attachment1
	return a0 and a0.CFrame or CFrame.identity, a1 and a1.CFrame or CFrame.identity
end
```

## Frame order: why PreSimulation

The official `RunService` reference gives this order per frame:

1. `PreRender` (client only; replaces the legacy `RenderStepped`)
2. rendering
3. `PreAnimation`
4. **the Animator steps every playing track and writes joint transforms**
5. `PreSimulation` (replaces the legacy `Stepped`)
6. physics simulation (may run several substeps)
7. `PostSimulation` / `Heartbeat`
8. replication

Now follow a `Transform` write through that loop:

| You write in | What happens to it | Verdict for an animated joint |
|---|---|---|
| `PreRender` | Rendered this frame? No: the parts were placed by the last physics step. Then the Animator overwrites it in step 4. | lost |
| `PreAnimation` | The Animator overwrites it in step 4. | lost (but useful for *restoring*, see below) |
| `PreSimulation` | Physics uses it to place the parts in step 6; rendered next frame. | **correct** |
| `Heartbeat` | Survives until the next Animator step overwrites it, so the next physics step never sees it. | lost |

For a joint no playing track keys, every slot "works" because nothing overwrites it, which is exactly why code that worked on a static NPC breaks the day someone plays an idle on it.

`C0` is different: the Animator never writes it, so a `C0` write in any slot persists. That is its strength (it does not need re-writing) and its weakness (it is never cleaned up, it fights retargeting, and it does not exist on `AnimationConstraint`).

Camera work belongs in `PreRender` or `RunService:BindToRenderStep` (priorities such as `Enum.RenderPriority.Camera.Value + 1`). Do not put character posing there.

## Composing with the Animator

In `PreSimulation`, `joint.Transform` already holds this frame's animated value `A`. You choose how your rotation `R` combines with it:

| Formula | Meaning | Use for |
|---|---|---|
| `Transform = R * A` | `R` is applied in the joint's parent frame (the `Part0 * C0` frame), *outside* the animation | aiming, look-at, lean, recoil: "turn the head toward the target, whatever the clip is doing" |
| `Transform = A * R` | `R` is applied in the animated child frame, *inside* the animation | twist along the bone, "add roll to this hand as it moves" |
| `Transform = R` | ignore the clip on this joint | full procedural control (IK legs, ragdoll blend) |
| `Transform = A:Lerp(R, w)` | blend toward a procedural pose by weight `w` | fading a procedural layer in and out |

`CFrame:Lerp` interpolates rotation along the shortest arc and position linearly, so a `w` fade is safe. It is *not* how the Animator blends clips (it blends rotation vectors in most cases, see [[How the Animator Really Behaves]]), but for a procedural overlay that difference does not matter.

### The compounding trap

```lua
-- WRONG on any joint the Animator might not rewrite this frame
RunService.PreSimulation:Connect(function()
	neck.Transform = neck.Transform * CFrame.Angles(0, 0.01, 0)
end)
```

When a track keys the neck, the Animator resets `Transform` every frame and this adds 0.01 rad once per frame, which is fine. The moment no track keys the neck (the idle stopped, a clip that omits the head is playing, the rig is far away and its player only advances time), `Transform` keeps last frame's value and the head spins forever.

Whether the real Animator resets joints that no track keys is not documented. The reference project's own Lua clip player resets them to identity, and its enemy reaction layer guards against both cases: it saves the Animator's value before overlaying, then gives it back in `PreAnimation`, so its overlay is never in the input:

```lua
--!strict
-- A procedural overlay that never compounds, whatever the Animator does this frame.
local RunService = game:GetService("RunService")

type Overlay = (joint: Instance, animated: CFrame, dt: number) -> CFrame

local Layer = {}
Layer.__index = Layer

function Layer.new()
	local self = setmetatable({
		overlays = {} :: { [Instance]: Overlay },
		saved = {} :: { [Instance]: CFrame },   -- what the Animator wrote, before our overlay
	}, Layer)

	-- 1. Before the Animator steps: put back the value it wrote last frame.
	--    If a track keys this joint, the Animator overwrites it anyway.
	--    If nothing keys it, the joint shows the clean animated pose, not last frame's overlay.
	self.preAnim = RunService.PreAnimation:Connect(function()
		for joint, cf in self.saved do
			(joint :: any).Transform = cf
		end
		table.clear(self.saved)
	end)

	-- 2. After the Animator steps: read the animated value, save it, write ours.
	self.preSim = RunService.PreSimulation:Connect(function(dt)
		dt = math.min(dt, 1 / 20)                      -- clamp hitches so springs do not explode
		for joint, fn in self.overlays do
			if joint.Parent then
				local animated = (joint :: any).Transform :: CFrame
				self.saved[joint] = animated
				;(joint :: any).Transform = fn(joint, animated, dt)
			end
		end
	end)
	return self
end

function Layer:set(joint: Instance, fn: Overlay?)
	self.overlays[joint] = fn
end

function Layer:destroy()
	self.preAnim:Disconnect()
	self.preSim:Disconnect()
	for joint, cf in self.saved do (joint :: any).Transform = cf end
end

return Layer
```

Usage: `layer:set(neck, function(_, a) return CFrame.Angles(0, yaw, 0) * a end)`.

## Reading positions during PreSimulation

A subtle one-frame lag: in `PreSimulation` the joint `Transform`s are new but the parts have not moved yet, because physics places them in step 6. Reading `head.CFrame` or `upperTorso.CFrame` there gives last frame's pose. For slow look-ats nobody notices. For anything that must line up exactly (a hand on a moving handle, a foot on a step, a blade path), compute forward kinematics yourself from the root:

```lua
-- Forward kinematics from the root through the joints' current Transforms.
-- order: joints sorted parents first (breadth-first from the root part).
local function fk(rootPart: BasePart, order: { Instance }): { [BasePart]: CFrame }
	local frames: { [BasePart]: CFrame } = { [rootPart] = rootPart.CFrame }
	for _, j in order do
		local jj = j :: any
		local c0, c1 = jointFrames(j)
		local p0 = frames[jj.Part0]
		if p0 then
			frames[jj.Part1] = p0 * c0 * jj.Transform * c1:Inverse()
		end
	end
	return frames
end
```

The reference project's enemy reaction layer does exactly this before its ground check. Treat the lag itself as observed behaviour rather than a documented guarantee, and test it on your rig.

## Edit mode is different

Edit mode has no physics, so `Transform` writes do not move parts there at all (measured in the reference project, whose weapon-rig player has a manual `Step` hook for Edit tests). `Animator:StepAnimations(dt)` does work in Edit with `dt > 0`. For Edit previews, pose parts directly with your own FK, or test procedural code in Play. See [[Testing Animations in Studio]].

## Time, dt and determinism

| Clock | Use | Watch out |
|---|---|---|
| `dt` from the event | integrators (springs, velocities) | spikes after a hitch: clamp, e.g. `math.min(dt, 1/20)`, or substep |
| `os.clock()` | local timelines (a 3 s flourish, a bob) | differs per client |
| `workspace:GetServerTimeNow()` | anything several clients must show in sync | network clock, slight drift corrections |
| a seed (`Random.new(seed)`) | per-object variation (phase, speed) | without it, every copy moves in lockstep |

Pure, stateless functions of time (`angle = f(t)`) are the easiest to synchronise and to test offline. The reference project wrote its flight paths and flourish blade maths as pure modules with no instances, so they could be simulated outside Studio and run identically on every client.

## Replication

Procedural motion is local to the machine that computes it. `Transform` writes on a client are not replicated. `C0` writes on a client are not replicated either. Writes on the server do replicate, but at network rate, so they stutter.

The pattern that works: **replicate inputs, compute on every client.** The reference project:

- Moved the held blade through the grip weld's `C0` on *every* client from shared data (flourish name + start time), never by replicating CFrames.
- Ran enemy animation entirely on clients from replicated attributes (clip name, start time, speed); the server never played a clip.
- Synchronised a one-off prop spin by setting an attribute `"<userId>:<index>:<serial>"`; every client then played the same 4.4 s quartic-eased spin.

See [[Replication and Ownership]].

## Performance

Numbers measured in the reference project:

| Item | Cost or rule |
|---|---|
| Lua keyframe player (KeyframePlayer) | about 22 microseconds per 25-bone rig-frame; 39-60 on the largest boss |
| KeyframePlayer LOD | every frame within 60 studs, every 2nd within 150, every 4th within 300, beyond that only time advances |
| Weapon rig player LOD | every frame for your own blade or within 40 studs; every 3rd to 120, every 10th to 300, every 30th beyond; rate re-chosen every 15 frames with a random phase |
| Shopkeeper procedural idle | sleeps beyond 280 studs |
| Enemy reaction layer | nothing runs for an enemy that is not reacting; nothing is created per frame |
| Foliage sway | 30 Hz with `BulkMoveTo`, near the camera only |

General rules:

- One `PreSimulation` connection iterating a list beats one connection per object.
- Allocate nothing per frame in hot loops: reuse tables, avoid closures.
- Stagger LOD phases (random offset) so 50 rigs do not all update on the same frame.
- Skip rigs that are off-screen or outside workspace.
- See [[Performance and Memory]] and [[Animation LOD]].

## The toolbox (where each technique lives)

| Technique | Note |
|---|---|
| Engine IK component | [[IKControl Reference]] |
| Analytic arm and leg IK | [[Two-Bone IK Math]] |
| Chains: tails, tentacles, spines | [[Multi-Bone IK - FABRIK and CCD]] |
| Making arms look human | [[Elbow Poles Swivel and Joint Limits]] |
| Feet on slopes and stairs | [[Foot Placement and Ground IK]] |
| Walking and running from code | [[Procedural Gait and Footstep Planning]] |
| Springs, damping, smoothing | [[Springs Damping and Smoothing]] |
| Heads, eyes, turrets, aim | [[Look-At Aim and Head Tracking]] |
| Physics bodies | [[Ragdolls and Physics-Based Animation]] |
| Spins, tosses, regrips in the hand | [[Procedural Weapon Motion]] |
| Topple, fizzle, recoil, caught | [[Procedural Death Knockdown and Hit Reactions]] |
| Doors, lids, spinning props | [[Tween and CFrame Animation of Objects]] |
| Flying creatures and flocks | [[Flight Flocks and Path Animation]] |
| Overview of solver families | [[Inverse Kinematics]] |

## Common mistakes

| Symptom on screen | Cause | Fix |
|---|---|---|
| Procedural head turn does nothing on a character | write happens in `PreRender` or `Heartbeat` | move it to `PreSimulation` |
| Works on an R6/old rig, does nothing on new avatars | code searches for `Motor6D` | accept `AnimationConstraint` too |
| Head slowly spins away, worse when far from camera | compounding `Transform = Transform * R` on a joint nothing rewrites | restore in `PreAnimation`, or compute from a stored base |
| Aim lags the body by one frame during fast turns | reading part CFrames in `PreSimulation` | compute FK from joint Transforms |
| Motion is smooth for you, stutters for others | server-side writes or replicated CFrames | replicate inputs, compute on every client |
| Everything explodes after a lag spike | unclamped `dt` in an integrator | clamp or substep |
| Rest pose permanently wrong after a cutscene | `C0` edits never restored | store and restore, or use `Transform` |
| Works in Play, nothing moves in Edit preview | no physics in Edit | pose parts directly or use `Animator:StepAnimations` |
| 200 bobbing pickups cost a millisecond | one connection and one `PivotTo` each | single loop, `BulkMoveTo`, distance gate |

## Checklist

- [ ] Joint lookup accepts `Motor6D`, `AnimationConstraint` and `Bone`.
- [ ] Writes to animated joints happen in `PreSimulation`.
- [ ] Overlays compose with the animated value (`R * A` or `A * R`) and cannot compound.
- [ ] `dt` is clamped or the integrator is substepped.
- [ ] Anything others must see is driven by replicated inputs, computed per client.
- [ ] Distance and visibility gating; no per-frame allocations.
- [ ] The layer has a weight and fades in and out (no pops when it starts or stops).
- [ ] Tested on the real avatar type (scaled, [[AnimationConstraint]]) and in a live server.

Related: [[Frame Order and RunService Timing]], [[Motor6D Math and CFrame Composition]], [[Snippets - Procedural Motion]], [[Engine Gotchas]].

## Connected notes
<!-- auto-links:start -->
[[Animation Start Here]] · [[Animation Glossary]] · [[Snippets - IK]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Official Docs - Characters and Animation]] · Script Performance
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Held Weapons on Motor6D - Locking the Grip During Attacks]] · [[Rigs and Joints]] · [[AI Pitfalls - Physics and Animation]] · [[Animator Deep Dive]] · [[Idle Breathing and Secondary Motion]] · [[Troubleshooting Table]] · [[Debugging Animation Problems]] · [[Custom Rigs - Weapons and Props]] · [[Open Questions]] · [[Snippets - Lua Keyframe Player Core]]
<!-- related:end -->
