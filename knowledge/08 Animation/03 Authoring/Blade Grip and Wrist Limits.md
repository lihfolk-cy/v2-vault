---
tags: [animation, weapons, sword, grip, wrist, authoring, r15, blender]
---
# Blade Grip and Wrist Limits

A sword clip looks wrong long before anyone can say why: the blade passes through the head, points back along the forearm, or snaps 120 degrees between two frames. Almost always the cause is the same. The animator (or the AI) keyed **where the blade should point** and let a solver rotate the hand by whatever amount got it there. Real wrists can't do that. This note gives the grip point, the wrist range, and a solve that respects both.

## 1. Where the weapon sits

- **Grip point.** Roblox welds a Tool's `Handle` to the hand at `RightGripAttachment`, which sits on the **bottom face of the hand**. On the default R15 rig at scale 1 that is the hand centre minus half the hand height: y = 2.3265 - 0.3158/2 = 2.1686 studs in rig space (**Measured**, block R15, scale 1). Put the handle's centre there, not at the hand's centre. A handle at the hand centre floats about 0.16 studs above the fist and reads as "pasted on".
- **Rest direction.** With the arm hanging, the blade points **forward** (character -Z) and lies roughly perpendicular to the forearm. That is the standard Roblox tool grip (**Roblox docs**, Tool grip convention) and the frame every wrist rotation below is measured from.
- **Guard placement.** The guard should sit just in front of the knuckles; the fist covers the handle. If the guard clips into the fist, slide the mesh along the blade axis, never move the grip attachment.

## 2. What a wrist can actually do

In a fist grip the blade is about 90 degrees from the forearm. The hand reaches every blade direction with two motions:

| Motion | Anatomy | Range to allow | Label |
|---|---|---|---|
| Forearm twist | Pronation / supination | Large: about 160-180 degrees total | Rule of thumb (anatomy references) |
| Wrist bend | Flexion / extension / radial-ulnar deviation | About **+-50 degrees** from perpendicular | Rule of thumb (stylised: real deviation is smaller, flexion larger) |

So a held blade can point anywhere **inside a cone 40-140 degrees from the forearm axis**, at any angle around it. A blade pointing back along the forearm (angle under 40 degrees) or straight out of the fist like a lance (over 140 degrees) needs a different **arm** pose, not more wrist.

## 3. The solve (twist, then bend, then clamp)

For each blade key:
1. Read the forearm axis `fa` (elbow to wrist) and the current blade direction `v` with no hand rotation.
2. **Clamp** the target `d` into the cone: if the angle between `fa` and `d` is outside [40, 140] degrees, rotate `d` toward the nearest edge of the cone, keeping its direction around `fa`. Record how many degrees were clamped.
3. **Twist** `v` about `fa` until its azimuth matches `d` (that's pronation, done by the forearm).
4. **Bend** the twisted blade onto `d` (the remaining small rotation, done by the wrist).
5. Key the hand with `bend x twist`, Bezier-eased like every other joint.

The LihFolk pipeline implements this in `lihanim/clip.py` (`Clip.blade_aim` + `_blade_pass`) and writes the clamped degrees per key into the clip's JSON (`qa.wrist_clamped_deg`). **Measured:** the first SwordSlash draft asked for up to 33 degrees beyond the cone in its guard and follow-through poses. Those were exactly the frames that looked broken. After retargeting, the worst key clamps 1.7 degrees.

**A clamp is a bug report, not a fix.** Anything above about 5 degrees means the key pose asks the wrist to do the arm's job. Change the shoulder or elbow (or rotate the torso into the swing) and re-run until clamps are near zero.

## 4. Choosing blade directions per key

| Key | Blade should | Why |
|---|---|---|
| Guard / ready | Point forward and up, angled **outward** to the weapon side (e.g. character-space (0.45, 0.45, -0.77) for a right-hand blade) | Vertical blades in front of the face clip the head in three-quarter view |
| Windup | Cocked high behind the weapon shoulder, tip up and back | Long silhouette = readable anticipation |
| Mid-swing (1-2 frames) | Pass through vertical or horizontal on a clean arc | Breaking the arc reads as a teleport |
| Contact | Along the cut, slightly ahead of the hand | Edge leads the swing |
| Follow-through | Low and across, still **in front** of the body (e.g. (-0.6, -0.5, -0.6)) | A blade that ends behind the body vanishes from camera and kills the read |

Rotate the **torso** into the swing so the arm never has to cross the chest. In the SwordSlash clip the chest turns about 46 degrees left at follow-through, so the arm stays forward in torso space and nothing interpenetrates.

## Common mistakes

- Solving the hand with the minimal rotation from rest to target. It ignores anatomy and produces wrist flips and blades through the head.
- Placing the handle at the hand's centre instead of the grip attachment.
- Keying a vertical guard blade in front of the face.
- Letting the follow-through blade end behind the body, where the camera can't see it.
- Treating clamped degrees as solved. Fix the arm pose instead.
- Making the arm cross the chest to reach the far side instead of turning the torso.

## Checklist

- [ ] Handle centre at `RightGripAttachment` (bottom face of the hand)
- [ ] Blade keys stay 40-140 degrees from the forearm; `qa.wrist_clamped_deg` under 5 on every key
- [ ] Guard blade angled outward, clear of the head in three-quarter view
- [ ] Torso rotates into the swing; arms never pass through the chest
- [ ] Follow-through blade visible in front of the body
- [ ] `Hit`, `TrailOn`, `TrailOff` markers on the contact and swing frames

## See also

- [[Weapon Swing Design]]
- [[Custom Rigs - Weapons and Props]]
- [[LihFolk R15 Keyframe Pipeline]]

## Connected notes

[[Animation Start Here]] · [[Weapon Swing Design]] · [[Custom Rigs - Weapons and Props]]
