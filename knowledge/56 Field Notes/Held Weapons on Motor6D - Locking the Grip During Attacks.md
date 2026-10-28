---
tags: [field-notes, animation, motor6d, weapons, grip, procedural, combat]
---
# Held Weapons on Motor6D - Locking the Grip During Attacks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Blade twists inside the hand during swings: Correction spring active on the grip joint during attacks -> Lock the grip during attack clips
> - Blade keeps a slight tilt after an attack: Last correction value left in `Transform` -> Write identity explicitly while locked; reset the spring
> - Snap of a few degrees when attacking from idle: Different hold tilt per state -> One constant hold tilt in `C0`
> - Exactly one controller writes the grip joint.
> - Clearance and sway corrections disabled from attack accept to recovery end.
> - Locked frames write identity, or deliberately defer to clips that key the grip.
>
> Cost: TL;DR ~190 tok · whole note ~1.6k tok. Read more: ## What went wrong · ## The rule · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A weapon held by a `Motor6D` between the hand and the handle is usually animated by two things at once: the attack clip and some procedural correction (sway, a "blade clearance" spring that tilts the blade away from the body or the ground, a look-at). During idle and walking that layering looks great. During attacks it makes the blade twist inside the hand, because the correction fights the clip on the one joint where the player is looking hardest. This note covers why, and the rule that fixed it: lock the grip during attack clips and keep the hold tilt constant. Grip angles are covered in [[Blade Grip and Wrist Limits]]; joint maths in [[Motor6D Math and CFrame Composition]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## How the joint is composed

A `Motor6D` places `Part1` relative to `Part0` as `Part0.CFrame * C0 * Transform == Part1.CFrame * C1` (Roblox docs). The Animator writes `Transform` every frame from the playing tracks. `C0` and `C1` are the rest offsets. Anything else that touches the joint, either by rewriting `Transform` after the Animator or by changing `C0`, stacks on top of the animation. Roblox docs recommend setting `Transform` from `RunService.PreSimulation` (formerly `Stepped`) if you override it, because that runs after animations have been applied for the frame ([[Frame Order and RunService Timing]]).

## What went wrong

**Measured.** The reference project ran a clearance spring on the sword grip joint: when the blade got close to the character's body or legs, the spring rotated the grip a few degrees to push it away. During attack clips the blade passes close to the body by design, many times a second, so the spring was constantly active and constantly behind. The blade visibly **rotated inside the closed hand** on wind-ups and follow-throughs.

Two knock-on effects follow from that (rule of thumb): the edge stops lining up with the swing arc, so a slash trail and the blade disagree, and the blade tends to tilt away at contact, exactly when the body is closest and the player is watching.

A second issue made it worse. The idle pose used one hold tilt in `C0` and the attack clips assumed another, so switching idle to attack snapped the blade by a few degrees on the first frame and the spring then chased the difference.

## The rule

1. **During attack clips, no procedural correction on the grip joint.** The clip owns the weapon. Freeze or reset the clearance spring when an attack starts; resume it from rest when the attack ends.
2. **Write the locked value explicitly each frame** while locked. `Transform` persists until something writes it, so if your correction last wrote a tilt and then stops writing, the tilt stays. Either write identity (when the clip does not key the grip joint) or write nothing and let the clip's own value stand (when it does). Know which case each clip is.
3. **Keep the hold tilt constant across idle and attack.** Put the hold angle in `C0` once and never change it per state. If an attack needs a different blade angle, animate the wrist in the clip, not the grip offset.
4. **Corrections go up the chain, not on the grip.** If the blade clips through the body in an idle, rotate the arm or wrist joint slightly, which keeps the weapon rigid in the hand.

```lua
-- Client: grip owner. One place decides what the grip joint does each frame.
local RunService = game:GetService("RunService")

local HOLD_TILT = CFrame.Angles(math.rad(-10), 0, 0) -- one constant for every state
gripMotor.C0 = gripAttachmentCFrame * HOLD_TILT       -- set once at equip

local attackLocked = false
local clipKeysGrip = false -- true for clips that animate the grip joint themselves

function GripController.setAttacking(isAttacking: boolean, keysGrip: boolean)
	attackLocked = isAttacking
	clipKeysGrip = keysGrip
	clearanceSpring:reset() -- start from rest, never from a stale offset
end

RunService.PreSimulation:Connect(function(dt)
	if attackLocked then
		if not clipKeysGrip then
			gripMotor.Transform = CFrame.identity
		end -- else: leave the clip's Transform untouched
		return
	end
	local angle = clearanceSpring:step(dt) -- radians, idle and locomotion only
	gripMotor.Transform = CFrame.Angles(angle, 0, 0)
end)
```

Lock from the moment the attack request is accepted (not the first animation marker) until the clip's recovery ends, so the wind-up is clean too.

## Testing

- Slow the attack track to 0.1 speed with `AnimationTrack:AdjustSpeed` and watch the hand. The blade should never rotate relative to the knuckles unless the clip says so.
- Toggle idle and attack rapidly for ten seconds. The blade angle at the first frame of attack must match the last frame of idle.
- Compare the slash trail plane with the blade's flat. If they diverge mid-swing, something is still writing the grip.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Blade twists inside the hand during swings | Correction spring active on the grip joint during attacks | Lock the grip during attack clips |
| Blade keeps a slight tilt after an attack | Last correction value left in `Transform` | Write identity explicitly while locked; reset the spring |
| Snap of a few degrees when attacking from idle | Different hold tilt per state | One constant hold tilt in `C0` |
| Slash trail and blade edge disagree | Grip rotating independently of the clip | Same lock; corrections only up the arm |
| Override has no effect or flickers | `Transform` written before animations apply | Write in `PreSimulation` |

## Checklist

- [ ] Exactly one controller writes the grip joint.
- [ ] Clearance and sway corrections disabled from attack accept to recovery end.
- [ ] Locked frames write identity, or deliberately defer to clips that key the grip.
- [ ] Hold tilt lives once in `C0` and never changes per state.
- [ ] Clipping fixed by arm or wrist adjustments, not grip rotation.
- [ ] Checked at 0.1 speed and with rapid idle-attack toggling.

## Connected notes
<!-- auto-links:start -->
[[Blade Grip and Wrist Limits]] · [[Motor6D Math and CFrame Composition]] · [[Procedural Weapon Motion]] · [[Weapon Swing Design]] · [[Custom Rigs - Weapons and Props]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
