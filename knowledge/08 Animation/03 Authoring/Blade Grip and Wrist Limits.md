---
tags: [animation, weapons, sword, grip, wrist, authoring, r15, blender, tool-grip]
---
# Blade Grip and Wrist Limits

A sword clip looks wrong long before anyone can say why. The blade comes out of the fist at an odd angle, the crossguard points the wrong way, the wrist snaps 120 degrees between two frames, or the forearm passes through the chest. Almost always the cause is the same: the animator (or the AI) keyed **where the blade should point** and let a solver turn the hand by whatever amount got it there. This note gives the real grip geometry, the Roblox numbers that reproduce it, the wrist ranges, and the solve the LihFolk pipeline uses. Sources are in `D:\LihFolk Build\research\animation-references.md`.

## 1. How a one-handed sword actually sits in the fist

- **Grips.** *Hammer grip*: the whole fist closes, the thumb wraps over the index finger. *Handshake grip*: the thumb lies along the back of the grip, so the point projects further forward (**Expert practice**, HEMA and messer teaching).
- **Handle angle.** The handle crosses the palm diagonally, from the base of the index finger to the heel of the hand. Measured from the forearm's distal axis (elbow to wrist and on) to the blade, a neutral fist holds the blade at about **65 +- 7 degrees** (**Source-backed**, Young et al. 2013, 31 people; handgun grips are 18-22 degrees off perpendicular, the same geometry). A handshake grip sits lower. LihFolk uses **60 degrees**, between the two.
- **Edge.** The true edge faces the same way as the **middle knuckles** (the second row); the false edge faces the thumb web (**Expert practice**). With the arm hanging, the blade points forward and slightly down and the true edge faces down.
- **Crossguard.** The quillons lie in the blade's plane, so they point the same way as the edges, not across the flat. A guard that looks "rotated 90 degrees" in a preview usually means the edge, not the guard, is wrong.

## 2. The Roblox numbers

| Item | Value | Label |
|---|---|---|
| `RightGripAttachment` on the R15 RightHand | Position (0, -0.162, 0), Orientation (-90, 0, 0) | **Measured** (block R15, scale 1; DevForum confirms -90,0,0 is standard) |
| Weld | `Handle.CFrame = RightHand.CFrame * RightGripAttachment.CFrame * Tool.Grip:Inverse()` | **DevForum** (community-confirmed) |
| Default `Tool.Grip` | Identity: a blade modelled along Handle +Y sticks out of the fist at 90 degrees to the forearm | **Roblox docs** (API dump defaults) |
| LihFolk `Tool.Grip` | `CFrame.Angles(math.rad(30), 0, 0)`: blade 60 degrees from the forearm, true edge on Handle -Z | **Rule of thumb** (derived; check once in Studio) |
| UGC packages with grip (90, 178.6, 0) | Hold weapons backwards; reset the attachment on load | **DevForum** |

Model the sword with the **blade along Handle +Y** and the **true edge along Handle -Z**. The pipeline's preview sword uses exactly that frame, so a clip that looks right in the preview looks right in game with that `Tool.Grip`.

## 3. What a wrist can do

| Motion | Clinical normal | Functional | LihFolk solver limit |
|---|---|---|---|
| Flexion / extension | 80 / 70 (AAOS) | 54 / 60 (Ryu 1991) | 65 / 60 |
| Radial / ulnar deviation | 20 / 30-35 | 17 / 40 | 20 / 38 |
| Pronation / supination | ~80 / ~80 | 50 / 50 (Morrey 1981) | 80 / 85 |

What each motion does to a held blade (hammer-type grip):
- **Deviation tilts the blade toward or away from the forearm line.** Ulnar deviation brings it toward in-line, radial deviation stands it up. From the 60-degree grip the blade can sit about **22 to 80 degrees from the forearm axis**. It can never continue the forearm in a straight line, and it can't point back past perpendicular.
- **Forearm twist swings the blade around the forearm**, which is how a cut changes plane.
- **Flexion and extension mostly roll the edge**, because the blade lies close to the flexion axis.
- Cuts follow the "dart-thrower" arc: radial deviation plus extension in the raise, ulnar deviation plus slight flexion through and after contact (**Source-backed** for hammering and throwing; **Rule of thumb** for swords).

## 4. The solve (lihanim/sword.py)

Keys are written as `Clip.skey(frame, ease, lt_p, lt_r, ut, head, rh or rhl, blade, edge, lh or lhl, ...)`: torso pose, wrist target, blade direction and (optionally) edge direction. For each key the solver:
1. Searches the **elbow swivel** (24 positions around the shoulder-wrist line) and small **wrist-target nudges** (up to 0.45 studs).
2. For each candidate, solves the **wrist** (twist, deviation, flexion) inside the limits above. The cost puts blade direction first, edge second, a neutral wrist third.
3. Rejects arms whose upper arm, forearm, hand, blade or pommel enter the chest, belly or head (oriented-box test), or whose elbow rises above the shoulder.
4. Points the **edge along the blade's direction of travel** (taken from the neighbouring keys) unless an edge is given. Hold keys keep the edge they arrived with.
5. Checks every gap at 1/3, 1/2 and 2/3. Where the in-between would pass through the body, it inserts a **breakdown key** with the hand pushed clear.

The QA block reports `wrist.blade_err_max_deg`: the gap between the authored blade direction and the one the anatomical wrist reaches. The wrist itself is never forced past its limits, so that number replaces the old `wrist_clamped_deg`. Keep it **under 5** on authored keys.

## 5. Choosing blade directions per key

The blade must sit **25 to 75 degrees off the shoulder-to-hand line, on the thumb side**. Most bad keys break this rule.

| Key | Hand (torso space) | Blade | Why |
|---|---|---|---|
| Guard | In front of the hip, arm about 45 degrees bent | Forward, 35 degrees up, slightly inward | Blade above the arm line: neutral wrist |
| Wind-up over the shoulder | Out to the side at ear height, 1.2+ studs from the shoulder | Up and back | A hand closer than ~1 stud folds the elbow and the R15 hand box hits the upper arm |
| Contact, falling diagonal | Arm extended forward-left (the torso has turned) | Straight at the target, *right of and above* the arm line | Hand leads, blade lags, ulnar deviation snaps it in |
| Follow-through | Low and forward-left, 1.4+ studs out | Forward-low, not along the arm | A blade in line with the arm is unreachable |
| Backhand contact | Arm forward-right | Forward-right, left of the arm line | Edge leading needs supination; accept the false edge if it can't |

**The torso aims the cut and the arm keeps its shape.** A backhand wind-up turns the chest ~58 degrees left, so the hand stays in front of the right chest instead of crossing it.

## Common mistakes

- Solving the hand as the minimal rotation from rest to target: wrist flips, blades through the head.
- Using a fixed "+-50 degree cone from perpendicular" (the old LihFolk rule). It allows blades pointing back at the elbow, which no grip can do, and it ignores the 20-30 degree handle lean.
- Asking for a blade in line with the forearm (thrust or contact keys). The hammer grip can't do it, so lower the arm instead.
- Hands closer than about 1 stud to their own shoulder. The 1-stud R15 boxes fold into each other.
- Head yaw beyond ~40 degrees relative to the chest. The block head's corner enters the shoulder cap.
- Leaving `Tool.Grip` at identity. The blade then stands at 90 degrees, 25 degrees stiffer than the preview.

## Checklist

- [ ] Sword modelled with the blade on Handle +Y and the true edge on Handle -Z; `Tool.Grip = CFrame.Angles(math.rad(30), 0, 0)`
- [ ] Keys authored with `skey` (hand target + blade), never a raw hand rotation
- [ ] `qa.wrist.blade_err_max_deg` under 5; breakdown keys reviewed
- [ ] Wind-up hands 1.2+ studs from the shoulder; follow-through hands 1.4+ studs out
- [ ] `qa.body_overlap.blade_max_studs` and `body_max_studs` under 0.05
- [ ] Edge leads the cut on contact keys (watch `edge_err` on the contact key)

## See also

- [[Weapon Swing Design]]
- [[Custom Rigs - Weapons and Props]]
- [[LihFolk R15 Keyframe Pipeline]]
- [[Locomotion and Melee Reference Numbers]]

## Connected notes

[[Animation Start Here]] · [[Weapon Swing Design]] · [[Custom Rigs - Weapons and Props]] · [[Locomotion and Melee Reference Numbers]]
