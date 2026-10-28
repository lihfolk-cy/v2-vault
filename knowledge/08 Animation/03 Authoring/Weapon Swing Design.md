---
tags: [authoring, craft, weapons, swords, two-handed, arcs]
---
# Weapon Swing Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Wrist aims the blade -> aim with the arm; wrist within 70/30/85
> - Avoid: Flat leads the cut -> edge = plane axis x blade direction
> - Avoid: Overhead straight to drive -> add a chop key over the front
>
> Read more (16 KB note): ## 1. Conventions you must fix before animating · ## 9. Long pommels · ## 14. Common mistakes
<!-- tldr:end -->

A sword swing is a body motion that happens to end in a blade. This note covers how to design swings that read and feel right on a Roblox character: cut planes and edge alignment, the kinetic chain, why the arm and not the wrist aims the blade, one-handed vs two-handed mechanics, long pommels, thrusts, overheads, spins, staffs and scythes, and the specific failures that automatic QA caught in one production game.

Labels: "reference project" = measured or standardised in one live action game (R15 scaled 1.6x, about 9 studs tall, held blade 9.5 studs long); "rule of thumb" = practice.

## 1. Conventions you must fix before animating

Decide and document these once per game, or every clip and every tool will disagree.

### Hand space
Reference project convention (used by every tool and clip):
- **Blade along the hand's -Z** (the hand's LookVector).
- **Cutting edge toward the hand's -X.** (Some weapon families said "edge faces the hand's -Y"; the double-edged ones may lead with either edge.)
- **Grip point**: 20% of the blade length up from the pommel. On a 9.5-stud blade that leaves **1.9 studs of pommel** behind the hand.

A helper that builds a hand rotation from a desired blade direction and edge direction:

```lua
--!strict
-- Hand rotation (world or chest space) such that the blade points along `dir`
-- and the cutting edge faces `edge`, under the convention blade = -Z, edge = -X.
local function handRot(dir: Vector3, edge: Vector3): CFrame
	local z = -dir.Unit                                   -- LookVector is -Z, so Z axis = -dir
	local x = -(edge - z * edge:Dot(z)).Unit              -- remove the part of edge along the blade, then flip: edge = -X
	local y = z:Cross(x)                                  -- right-handed frame: y = z x x
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end
```

### The weapon joint
Attach the weapon with a `Motor6D` from the hand so clips can key it when needed. Reference project: Part0 = RightHand, Part1 = the weapon handle, `C0` = the hand's `RightGripAttachment`, `C1` = the tool's grip, and the default `RightGrip` weld destroyed. See [[Custom Rigs - Weapons and Props]] and [[Accessories and Armor That Follow Animation]].

## 2. Cut planes and edge alignment

A cut happens in a **plane**. The blade sweeps through it, and the edge must lead (face the direction of travel), or the swing reads as a slap with the flat.

Design each cut as:
1. A **start direction** of the blade (where it is wound) and an **end direction** (where it finishes).
2. The **plane** containing both: its normal is `axis = start:Cross(end)`.
3. The **edge** at any moment: perpendicular to the blade, inside the plane, facing the direction of travel. In the reference project's pose library: `edge = axis:Cross(dir)`.

Typical planes:

| Cut | Plane | Reads well from behind? |
|---|---|---|
| Flat horizontal (R to L, L to R) | horizontal | moderately; tilt it 10 to 20 degrees |
| Falling diagonal (high right to low left) | diagonal | yes |
| Rising diagonal (low right to high left) | diagonal | yes |
| Vertical overhead | vertical, through the body's centre line | poorly from directly behind (the body hides it) |
| Thrust | a line, not a plane | poorly; needs a lunge and an effect |

Rule of thumb: vary planes across a combo (flat, then diagonal, then vertical finisher), both for readability and so a fixed hitbox shape covers different areas.

## 3. The arm aims; the wrist refines

Lining a blade up with the forearm needs about **90 degrees of wrist deviation**; a human wrist has about 20 radial and 30 ulnar. On R15 the wrist joint will rotate any amount, so it is easy to aim a blade by bending the wrist to absurd angles. It looks broken.

- **Aim the blade with the shoulder and elbow.** The wrist adds the last 10 to 30 degrees and the edge roll.
- Reference project limits: the bake clamped the wrist to **flex 70, deviation 30, twist 85 degrees**; QA flagged beyond **75 / 40 / 95**.
- On the R15 hand, wrist flexion mostly rolls the blade's edge, deviation tilts the blade toward the forearm, and twist swings it around the forearm (reference project analysis).
- Forearm roll does not exist as a joint on R15: big edge rolls must come partly from shoulder rotation, or the hand twists like a doorknob.

## 4. The kinetic chain

Power starts at the ground and travels outward:

**hips > chest > shoulder > elbow > wrist > blade**

- About **1 frame per link at 30 fps; 2 to 4 frames from hips to hand** (reference standard, from biomechanics of throwing and striking: pelvis to trunk 18 to 40 ms, trunk to elbow 55 to 65 ms, each link 1.3 to 1.5x faster than the previous).
- **Heavier blades are driven from more proximal joints.** Sabres and light blades cut from the elbow and wrist; longswords and heavy weapons cut from the shoulders and hips (reference standard, from historical fencing analysis).
- **At contact the arms extend in order** (shoulders, elbows, wrists), elbows stay closed rather than flared, and wrists are slightly flexed, not locked (reference standard, from kendo practice).
- In a horizontal slice the sweep comes mostly from the **waist twist plus shoulder rotation**, with one consistent arm shape (arm forward, blade in line). The reference project rebuilt its basic combo exactly this way.

Successive breaking in code: delay the waist, neck and off arm relative to the root. The reference project's baker used lags of **waist 0.015 s, neck 0.035 s, free arm 0.05 s**. See [[Spec-Driven Move Authoring]].

## 5. Phases of a swing

The reference project's re-animated basic swings were built in explicit phases:

**rest > windup > coil (in) > strike (out) > follow-through > settle > rest**

- **Windup**: turn the torso away, blade back on the cut's start side, weight back.
- **Coil**: the deepest point; the body is loaded. Easing *leaving* the coil key: CubicV2 **In** (slow start, accelerating into the strike).
- **Strike**: the blade crosses the target zone at peak speed. The `Hit` marker sits on the strike key.
- **Follow-through**: the blade carries past the body. Easing leaving the strike key: CubicV2 **Out** (fast then decelerating).
- **Settle**: CubicV2 InOut back toward the class rest.

Later the same project replaced its basic combo with **three horizontal slices** (right to left, left to right backhand, right to left high-to-low) and a **360-degree spin finisher**: durations **0.42 / 0.42 / 0.47 / 0.62 s**, hits at **0.20 / 0.20 / 0.23 / 0.30 s**, checked at 60 fps for zero body clipping.

## 6. One-handed swings

- **The off hand is part of the strike.** It counter-rotates for balance on cross-body cuts, pulls back to the hip (a chamber, "push-pull") on downward cuts and thrusts, reaches forward on casts, or guards in front of the chest. Pinning it to the side measurably weakens real throws (reference standard).
- Reference project off-hand anchors (chest frame, 1.6x rig) used by its arm baker when the authored off hand was dead or buried:

| Context | Anchor (x, y, z) |
|---|---|
| Counter-swing on a cross-body cut | (-3.5, 0.05, 0.85) |
| Chamber to the hip on downward cuts / thrusts | (-1.95, -1.75, 0.25) |
| Open reach on casts | (-0.85, 0.45, -2.75) |
| Ready guard otherwise | (-0.7, -0.7, -1.9) |

- **Backhands** wind the blade across the body. On a box torso the forearm sinks into the chest easily; open the elbow forward and out, and keep the hand well in front.

## 7. Two-handed swings

Real two-handed mechanics (longsword, kendo) differ from "one hand plus a passenger":
- **The rear hand at the pommel gives the power; the front hand guides** (reference standard citing kendo).
- **The hands push and pull against each other**: on the raise the rear hand pushes forward; on the strike it pulls back, levering the blade.
- **Elbows down and close**, not flared.
- The reference project placed the second hand **1.15 studs below the first along the blade**, rolled 180 degrees about the blade so both palms wrap the same side (at game scale; one weapon family used 0.42 studs apart at scale 1 for a shorter grip).
- **When two hands bury the arms, let go.** The reference project's baker released the hilt wherever holding it would push an arm into the body, and its "--two-handed" re-solve fixed most of the remaining low-scoring moves.

Transitions between one and two hands need care: the free hand must arrive exactly on the hilt at the grip key. The reference project's baker blended the free pose with the grip solved on the same frame, so the hand landed exactly on the handle when the key said "grip".

## 8. Overheads, chops and drives

The overhead-to-ground blow is the most dramatic swing and the most error-prone.

### The chop key
An overhead (blade back over the head) to a drive (blade down into the ground in front) is a turn of nearly 180 degrees. Interpolation takes the **short way**, which can be **back over the head**, so the impact frame ends with the blade pointing up behind the character. The reference project's fix, written into its pose library: insert a **chop key** between overhead and drive that brings the blade **over the front** (blade up and forward, hands high in front). Each segment is then well under 180 degrees and goes the right way.

General rule: no key-to-key segment of any joint should turn more than **120 degrees**; exactly 180 degrees is a coin flip even in the Animator itself (measured).

### Hips and drives
- **Overhead keeps the hips up; the chop drops the hips first**, then the blade follows (reference project timing rule). Dropping the blade before the hips reads as arm-only.
- **Shallow drives.** Overhead > chop > a deep drive into the floor buried the arms in the legs and floor in many clips; use a shallow drive or a two-handed drive.
- **Root drop limit**: drive and kneel poses keep the root at -1.0 stud or higher (scale 1, before the 1.6x root scale). Deeper pushed a foot 1 to 2.5 studs through the floor.

## 9. Long pommels

Many fantasy blades have long hilts and decorative pommels. With the grip 20% from the butt of a 9.5-stud blade, 1.9 studs of weapon sit **behind** the hand. That butt is invisible in your head while posing, and it goes straight into the torso, hips or thighs.

Lessons from the reference project:
- A blade **pointing away from the body with the hand close to the body** drives the pommel into the torso. Keep the **hand further out** (its pose library's "2" variants moved the hand roughly 0.3 to 0.45 studs further from the body at scale 1, mostly forward, and opened the blade direction more to the side).
- Make **overhead, drive and kneel one-handed**, with the off hand out to the side, for long-pommel weapons.
- **Chop** carries the blade over the front before every drive.
- In flurries, **halve the root yaw** and turn the waist more; big root swaps every 0.1 s popped.
- The **last key should be rest** (arms hanging like the game idle). A "ready" end pose put the pommel into the hip; re-keying end frames brought 22 of 22 moves to 0.08 s or less of blade-through-body.
- Its arm QA modelled about **20% of the blade behind the grip**; its baker pushed the grip out wherever the butt would enter the torso or hips.
- A per-blade **grip slide** (moving the grip point along the handle) helped weapons with extreme pommels during draws.

## 10. Thrusts

- **Chamber first**: blade drawn back at the hip, point forward, off hand reaching forward.
- **Thrust**: the body drives behind the arm (lunge), the blade goes straight out, the off hand pulls back.
- Reference project: **thrust hand about 0.7 studs out** (scale 1) and a **shallower load** (root y about -0.55) worked better than deep lunges.
- **Flat wind-up before thrusts.** A sprint pose leading into a thrust drove the forearm into the torso in many clips.
- Thrusts are a line, not an arc; they read poorly from behind. Add a forward lunge, a stab effect at the tip, and a short hit-stop.

## 11. Spins and finishers

- A 360-degree spin is the body turning, not the arm. Rotate the root (and let the waist lag) while the arm keeps a constant shape.
- Split a full turn into at least four keys (90 degrees each). Two 180-degree keys are ambiguous.
- Keep the blade outside the body circle at all times. On spins the blade often passes through the legs when the hand drops.
- Players lose track of facing during spins; finish facing the target.

## 12. Staffs, scythes and hinged weapons

### Staffs (double-ended)
- Held at the centre of their grip parts; both ends can hit. The reference project checked both blade ends, spins, splits, flips and throws at **120 Hz** against the body, the free arm and the ground.
- A welded weapon cannot spin itself in the hand. The reference project drove staff tricks with **markers** read on every client, for example `StaffSpin` with value `turns,dur,dir,axis,up,down`, plus `StaffSplit` / `StaffJoin`, `StaffFlip` and `StaffThrow` / `StaffCatch`. The clip carried the timing; code rotated the weapon.

### Scythes
- Reference convention: held by its handle 1.1 studs from the butt, shaft along the hand's -Z, the head on the hand's **+Y** side, the second hand forward on the shaft.
- The first scythe set failed because the heads were rotated 90 degrees and the left hand gripped about 1 stud off the shaft. Verify grips on the real model before animating a set.

### Weapons with moving parts
Hinged guards, orbiting pieces and chains are animated with their own small clips on the weapon's joints (the reference project called these "ItemRig" clips) or procedurally. See [[Weapon Rig Player]] and [[Procedural Weapon Motion]].

## 13. Blade clearance checks

The reference project's QA treated the held blade as a capsule of radius 0.12 along its 9.5-stud length and flagged it entering the torso, hips, head, legs or the free arm by more than **0.25 studs**. At its first audit, **about 82%** of attack clips failed this. The fixes were mostly pose changes listed above (hand further out, chop key, rest end pose, one-handed overheads for long pommels) plus an automatic blade-clearance turn: blades through the body were turned by the least angle that clears them, up to 70 degrees (30% strength where the blade direction mattered).

Check by hand:
- Step the clip at 60 Hz with the real weapon attached.
- Watch the pommel, not only the tip.
- Look from above: the blade's path around the body is clearest from the top view.

## 14. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Wrist aims the blade | broken wrist, edge wrong | aim with the arm; wrist within 70/30/85 |
| Flat leads the cut | slapping, not cutting | edge = plane axis x blade direction |
| Overhead straight to drive | blade ends pointing up behind the head | add a chop key over the front |
| Arm-only swing | weak, robotic | hips lead, 2 to 4 frames to the hand |
| Long pommel ignored | pommel through the torso or hip | hand further out; rest end pose |
| Deep drives and kneels | arms and feet buried | root drop no lower than -1.0 (scale 1) |
| Dead off hand | amateurish | counter-swing, chamber, reach or guard |
| Two hands forced on the hilt | arms through the chest | let go where the grip buries the arm |
| Spin in two 180-degree keys | random wrong-way spins | four or more keys |

## See also
[[Combat Animation Craft]], [[Posing and Silhouettes]], [[Animation Quality Standard]], [[Spec-Driven Move Authoring]], [[Pipeline - Arm IK Baking and QA]], [[Weapon and Combat Animation]], [[Custom Rigs - Weapons and Props]], [[Two-Bone IK Math]].

## Connected notes
<!-- auto-links:start -->
[[Elbow Poles Swivel and Joint Limits]] · [[Animation Review Checklist]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[Modeling Weapons and Props]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[AI Animation and Motion from Video]] · [[Animation Start Here]]
<!-- auto-links:end -->
