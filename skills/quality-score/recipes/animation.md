# Recipes: animation (shipped defaults; the project ledger refines these)

## First-pass defaults
- Pose **key poses first** (windup, contact, follow-through), each with a clear silhouette in three-quarter **and** side view, before adding in-betweens.
- Mix eases: `launch` into the action, `snap` on contact, `flat` on holds, `smooth` on recoveries. Never all `smooth`, never linear.
- Overlap: head and off-arm +2 frames, forearm and hand +1 frame behind the upper arm.
- Feet on `FootTrack` with IK; plant feet, never FK-animate them.
- Weapon clips: rotate the **torso** into the swing so the arm never crosses the chest.

## Pre-empt (measured first-draft misses)
- Blade targets beyond the wrist cone (40-140 degrees from the forearm): SwordSlash draft 1 hit 33 degrees over at the guard and follow-through. Pick blade directions from the table in `Blade Grip and Wrist Limits`.
- Vertical guard blade in front of the face clips the head: angle it outward to the weapon side.
- Follow-through blade ending behind the body disappears from camera: end it low and in front.
- Arms crossing the chest on the far-side cut (the 3-hit combo, draft 1).
- Handle at the hand centre instead of the grip attachment (bottom of the hand).
- Run reads as a jog: short stride, weak knee drive, arms tucked into the chest.

## Proven fixes
| Miss | Fix |
|---|---|
| Wrist flips or blade through the head | Anatomical blade solve (twist + clamp at +-50 degrees), retarget until clamps are under 5 |
| Floaty | Lower the hips on contact, add a 2-3 frame hold, snap the ease into contact |
| Stiff | Add offsets (head and off-arm +2) and arcs on the hands |
