---
tags: [rigging, weapons, props, motor6d, hinge-rigs]
---
# Custom Rigs: Weapons and Props

Animated weapons (blades that unfold, rings that orbit, energy that ignites, chains that swing), pets, bosses built from static meshes, and moving world props are all rigs of their own. Most of them do not need a skeleton from Blender at all: they need the right **joint frames**, the right **writer** for each joint, and a rig that survives being cloned onto every player's hand. This note covers the patterns one live action game used across roughly 150 animated weapons, a pet roster, two bosses and its hub props, with the measured pitfalls.

## 1. Pick the rig type for the job

| Need | Rig | Who writes the joints |
|---|---|---|
| Keyed hinge motion (unfolding blade, swinging pendulum, idle sway) | **Design rig**: root part + one Motor6D per moving piece + AnimationController/Animator | A clip player (Animator with a published id, or a Lua rig player) |
| Continuous spin (orbiting shards, rotor, halo) | Motor6D or weld per spinning group | Code each frame (`Transform` or weld `C0`), no clip |
| Spin, toss, catch of the whole weapon in the hand | The hand-to-weapon joint itself | Code on every client (grip `C0` or a hand Motor6D) |
| Big creature from a static mesh | Motor6Ds inserted into a static import with body-aligned frames | Lua writing `Motor6D.Transform` |
| World props (lids, waterfalls, gate rings) | No rig: a pivot + axis per moving sub-model | One client script with tweens or CFrame maths |

The project's quality rule for weapons: "Legendary and above = animated", meaning either an AnimationController with clips on **jointed** parts, or a procedural FX rig (one weapon drove 8 shard groups and 6 halo rings through weld `C0`). A weapon with an AnimationController and clips but **no Motor6Ds** was rated one tier down, because joints that do not exist are never animated: the Animator matches clip poses to joints by name, and keys for missing joints are inert. That is a silent failure: the clip "plays", nothing moves.

## 2. The weapon Design rig

```
WeaponModel                      (attributes: Scale, FXModule, IdleId, SpecialId, BladeColor)
├─ Handle                        root part, the grip; PrimaryPart; BladeFrame attachment
├─ AnimationController
│   └─ Animator
├─ Seg1 ── Motor6D "Seg1"        Part0 = Handle, Part1 = Seg1
├─ Seg2 ── Motor6D "Seg2"        Part0 = Seg1 (chained hinge), Part1 = Seg2
├─ Ring ── Motor6D "Ring"        Part0 = Handle, Part1 = Ring
├─ ChainLink1..n                 WeldConstraint (rigid)
└─ Animations
    ├─ Idle     KeyframeSequence, Loop, Idle priority (8 s in the project)
    └─ Special  KeyframeSequence, Action priority (4.4 s or 2.4 s)
```

How the project's builder made it from an imported GLB (Rig Type "No Rig", Merge Meshes off) and a setup script describing hinges:

1. Destroy every joint, weld and constraint that came with the import.
2. Unanchor all parts; `CanCollide`, `CanTouch`, `CanQuery` false; `Massless` true. A held weapon must not add mass or collisions to the character.
3. `Handle` becomes the PrimaryPart (anchored only in the stored template), with a `Scale` attribute and a `BladeFrame` attachment marking the blade's base frame.
4. **One Motor6D per hinge**, named after the moving part. Everything else is welded with `WeldConstraint`.
5. **Hanging chain links are welded rigid.** A held rig is massless and replicated; a physics chain on it jitters, replicates badly and fights the character. Animate chains as hinges or fake them.
6. Build `Idle` and `Special` KeyframeSequences from the setup's key data, thinned per joint (rotation tolerance 0.004 rad checked with nlerp, position 0.003 design units, at most 0.5 s between kept keys, static joints dropped).
7. Add `AnimationController` + `Animator`, attributes (`FXModule`, `IdleId`, `SpecialId`, `BladeColor`), and keep the pristine import and previous rig in a work folder for rollback.

The joints are built from **world-aligned joint frames** (`C0 = Part0.CFrame:ToObjectSpace(CFrame.new(jointPoint))`, same for `C1`), so clip rotations are in the weapon's model axes and do not depend on any mesh's orientation. Code is in [[Importing Models and Rigs]] section 4. Hinge directions on one flexible sword (4 ribbons x 5 chained segments) were "guessed from geometry" by the builder and flagged for playtest: if the hinge axis matters (a door, a jaw), put it in the manifest explicitly.

### Hinge clip format

A weapon clip is an ordinary KeyframeSequence with a weight-0 root Pose named `Handle` and child Poses named after each hinge's **Part1**, nested to match chained hinges:

```
Keyframe (Time = t)
└─ Pose "Handle"   (Weight 0: placeholder, never applied)
    ├─ Pose "Ring"     CFrame = CFrame.Angles(...)
    └─ Pose "Seg1"
        └─ Pose "Seg2"
```

The project wrote these with Priority Action2, Loop false, default easing Linear for specials. A Lua rig player binds each Pose to a motor by the key `Part0.Name .. "\0" .. Part1.Name`, which is unique even when two hinges share a Part1 name in different sub-assemblies. See [[Weapon Rig Player]].

### Playing weapon clips live: the trap

`KeyframeSequenceProvider:RegisterKeyframeSequence` returns a temporary id that **only loads in Studio**. In the reference project dozens of weapon kits played their hinge clips that way, so in live servers their blade parts never moved, and nobody noticed in Studio testing. Two working options:

- Publish each clip as an Animation asset and store the id (`IdleId`, `SpecialId`, `<Clip>Id` attributes). A published id always wins in the project's players.
- Play the KeyframeSequence data in Lua (a rig player writing `Motor6D.Transform`). This needs no ids and behaves identically in Studio and live.

Templated kit code is a regression risk: a later weapon copied an old template and reintroduced the Studio-only path. Grep for `RegisterKeyframeSequence` before shipping. Full story: [[Case Study - Abilities That Only Worked in Studio]].

## 3. Holding the weapon

### The joint between hand and weapon

The default Tool system welds the Tool's `Handle` to the hand with a Weld named `RightGrip`: `C0` = the hand's `RightGripAttachment.CFrame`, `C1` = `Tool.Grip`. A weld is fine for a static hold. For motion of the weapon relative to the hand (spins, tosses, regrips), the project used two approaches over time:

| Approach | How | Trade-off |
|---|---|---|
| Drive `RightGrip.C0` on every client | Each client computes the blade offset from shared data (flourish name and start time) and writes `C0`; snaps back to the hand on swing, guard or ability | No new joint; but `C0` changes the rest of a weld every frame, which is easy to leave dirty |
| Replace the weld with a Motor6D | `SwordMotor`: `Part0` = RightHand, `Part1` = Handle, `C0` = `RightGripAttachment.CFrame`, `C1` = `tool.Grip`; destroy `RightGrip` | Procedural code writes `Transform` and leaves `C0` alone; clips could also key it |

```lua
--!strict
-- Replace the Tool's RightGrip weld with a Motor6D so the blade can be animated in the hand.
local function attachBlade(character: Model, tool: Tool)
	local hand = character:FindFirstChild("RightHand") :: BasePart
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment
	local function killWeld(child: Instance)
		if child.Name == "RightGrip" and child:IsA("JointInstance") then
			child:Destroy()
		end
	end
	for _, c in hand:GetChildren() do killWeld(c) end
	hand.ChildAdded:Connect(killWeld)   -- the Tool re-creates RightGrip on every equip
	local m = (hand:FindFirstChild("SwordMotor") :: Motor6D?) or Instance.new("Motor6D")
	m.Name = "SwordMotor"
	m.Part0 = hand
	m.Part1 = handle
	m.C0 = grip.CFrame
	m.C1 = tool.Grip
	m.Parent = hand
end
```

(Store and disconnect the `ChildAdded` connection on unequip in real code.) Blade-in-hand motion was **computed on every client from shared data**, never replicated as CFrames: the server only relays "flourish X started at time T".

### Hand-space conventions

Write these down once; every IK solver, QA tool and grip script depends on them.

| Convention (project) | Value |
|---|---|
| Blade direction | along the hand's **-Z** (LookVector) |
| Edge direction | the hand's **-X** (some kits used -Y; pick one) |
| Grip point | 0.19 x hand width below the hand along its Y |
| Default grip | 28% from the pommel, unless the model sets `GripExact = true` |
| Scythe | held by its Handle 1.1 studs from the butt, shaft along -Z, head on the hand's +Y side |
| Staff | held at the centre of its grip parts; trail attachments at both ends; halves tagged `StaffHalf` "A" / "B" for split moves |
| Pommel modelled in QA | about 20% of the blade length behind the grip |

The first scythe set failed QA because heads were rotated 90 degrees and the left hand gripped about 1 stud off the shaft. Long pommels matter: the arm QA flagged pommels buried in the hip and torso, and the fix was moving hands further from the body in the clips, not shortening the model. See [[Weapon Swing Design]] and [[Arm QA Metrics Reference]].

### Name scans are fragile

A grip finder that searched part names for "bit" (as in a blade bit) also matched `Orbit_*` parts and moved the grip to 18% from the butt on 11 blades. Skip names containing "orbit", match whole names, or better, mark grip parts with an attribute or tag.

## 4. Procedural joints: spins, orbits and FX rigs

Continuous motion is cheaper and loops perfectly when done in code:

```lua
--!strict
local RunService = game:GetService("RunService")

type Spin = { motor: Motor6D, axis: Vector3, rate: number }   -- rate in rad/s
local spins: { Spin } = {}

-- PreSimulation runs after the Animator has written this frame's Transforms,
-- so this write wins for these joints. Never key the same joints in a clip.
RunService.PreSimulation:Connect(function()
	local t = os.clock()
	for _, s in spins do
		s.motor.Transform = CFrame.fromAxisAngle(s.axis, (t * s.rate) % (2 * math.pi))
	end
end)
```

Rules:

- **One writer per joint.** Clips and procedural spins both write `Transform`. A joint keyed by a clip and spun by code flickers between the two. Spin-only setups in the project authored Idle and Special on the orbit motors themselves, or left clips empty and listed the spins in FX data.
- **Weld `C0` rigs** suit groups that never need clips: the project's shard and halo rigs rotated weld `C0`s.
- **A welded weapon cannot spin itself in sync with the body.** The project drove staff hand work from `KeyframeMarker`s in the body clips (`StaffSpin "turns,dur,dir,axis,up,down"`, `StaffSplit`, `StaffFlip`, `StaffThrow` / `StaffCatch`), read on every client on the track's own clock.
- **Distance-gate everything.** The project's rig player updated every frame within 40 studs of the camera (or your own blade), every 3rd frame to 120, every 10th to 300 and every 30th beyond, re-evaluated every 15 frames with a random phase. See [[Animation LOD]].
- **Edit mode does not simulate.** `Motor6D.Transform` does not move parts in Edit, so test rig motion by stepping a player manually (the project's `SetManual` + `Step(rig, 1/30)` hooks) or by computing CFrames. See [[Testing Animations in Studio]].

## 5. Bosses from static meshes

The first boss in the reference project was a user-supplied static GLB with no rig: scaled to 30, with **19 Motor6Ds inserted** at chosen joint points using **body-aligned frames**, animated client-side through `Motor6D.Transform`. "Body-aligned" means each joint frame's axes are the creature's right, up and back, not the mesh's arbitrary local axes, so "pitch forward" is the same rotation on every joint and procedural code can be generic. The second boss was rebuilt in Blender properly (6 flat meshes, 42 bones, 23 clips), with lift on bone `Body` because the top-level root pose is never applied, and orbiting pieces (orbit, hem, lanterns) stripped from clips and spun client-side.

Lesson: inserting joints into a static mesh works for stiff, segmented creatures. For anything organic, rebuild with a skeleton.

## 6. Pets

Pet rigs were Motor6D part rigs built by an auto-fit installer from a rig description: part centres and roles per species and growth stage. A healthy install reported, for example, "fit err 0.002, 11 motors, 27 welded pieces". Clips were not needed for most pet motion (follow, bob, flap, idle) because a pet client animated joints procedurally. Wing flap sounds played on fast flight only, every 3rd beat. See [[Procedural Animation]].

## 7. World props and stations

Hub props rarely need rigs:

- **Sub-models named `Anim_<name>`** with an `AnimPivot` attachment (or PrimaryPart) and an `AnimAxis` attribute, and a mode (spin, sway, bob, pulse, blink). One client script animates them all.
- When moving a whole station by a rigid transform, **rotate `AnimPivot` and `AnimAxis` too**, or the spins wobble about the old axis.
- **Range-gate**: the project animated gate frames within 900 studs and hub FX within 280-650. Nested groups follow their parent.
- A **hinged lid**: one tweened NumberValue angle, `Lid.CFrame = Base.Hinge * CFrame.Angles(-deg, 0, 0) * rest`. Open: Back easing out over 0.6 s to 72 degrees. Close: Quad in over about 0.4 s plus a thud bounce. The overshoot range was checked so the lid never dips into the plinth (-2 to 115.5 degrees with Back).

See [[Tween and CFrame Animation of Objects]].

## 8. Budgets

| Budget | Value | Source |
|---|---|---|
| Kit folder (moves + weapon clips + scripts) | 2,500 instances | Project rule |
| Weapon hinge clips | under about 80 instances per weapon | Project typical |
| Hinge clips sampled every 0.05 s | blew the cap | Measured; thinning to 0.12 and 0.19 s spacing fixed one weapon |
| Script `Source` | 200,000 characters hard limit | Engine (saving fails with "Unable to assign property Source"); ribbon data over about 195k was split into child modules |

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Clips on a weapon with no Motor6Ds | Clip "plays", nothing moves | Build hinges; check every keyed Part1 has a joint |
| `RegisterKeyframeSequence` ids in shipped code | Works in Studio, frozen in live servers | Publish ids or play in Lua |
| Weapon parts with mass or collision | Character slides, trips, or flings | `Massless`, no collisions, no queries |
| Physics chains on a held weapon | Jitter, network noise | Weld rigid or animate as hinges |
| Clip and code writing the same joint | Flicker | One writer per joint |
| Grip found by substring | Grip jumps on some models | Attributes or tags; whole-name match |
| Static mesh scaled in Studio after joints exist | Hinges in the wrong places | Scale first, then build joints (or rebuild) |

## Checklist

- [ ] Every moving piece has a Motor6D named after it; static pieces welded.
- [ ] Joint frames from a manifest (world- or body-aligned), not from mesh orientation.
- [ ] Weapon parts massless, non-colliding, unanchored (template root anchored only in storage).
- [ ] Clips play through published ids or a Lua player; no Studio-only ids.
- [ ] Hand-space convention documented; grip by attribute.
- [ ] Spins and orbits in code, distance-gated; clips do not key them.
- [ ] Instance counts within budget after thinning.

## See also

[[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[Importing Models and Rigs]] · [[Weapon Design Rig Builder]] · [[Weapon Rig Player]] · [[Pipeline - New Animated Weapon]] · [[Procedural Weapon Motion]] · [[Equip Draw and Flourish Systems]] · [[Weapon and Combat Animation]] · [[Accessories and Armor That Follow Animation]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Weapons and Props]] · [[Animation Data from Blender to Roblox]] · [[Rigging in Blender]] · [[Snippets - Procedural Motion]] · [[Character and Creature Pipeline]] · [[Skeleton Library]] · [[Animation Start Here]]
<!-- auto-links:end -->
