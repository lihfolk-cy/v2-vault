---
tags: [systems, abilities, stance, charge, iai, state-machine]
---
# Stance and Charge Moves

A stance move has the player hold a pose to build power, then release into a strike: the iaido quick-draw, a charged overhead, a bow draw, a sprinter's crouch. Animation-wise it is two or three clips stitched by a state machine whose timing is partly authored (the release) and partly player-driven (how long they hold). This note uses the shared "iai strike" of one live action game (the reference project) as the worked example: one ability on every weapon kit, with a stance, a charge, a release clip and a lightning dash through the target.

## The state machine

```
            press                      Full marker / charge cap
  READY  ---------->  STANCE (charging)  --------------------->  STANCE (full, holding)
    ^                   |        |                                   |
    |                   | press  | cancel (hit, dash, death)         | press / auto at cap
    |                   v        v                                   v
    |               RELEASE    CANCELLED --(refund part of cd)--> READY
    |                   |
    |                   v
    |                 DASH (root moved by code, hits per segment)
    |                   |
    +--- RECOVER <------+
```

Design rules that came out of building it:

- **The cooldown starts at press**, not at release. Otherwise a player can enter the stance, cancel, and re-enter freely.
- **Cancels refund part of the cooldown** (25%, minimum 1.5 s remaining in the reference). Full refunds invite stance-cancel spam; no refund makes getting hit during the stance feel doubly punishing.
- **The player is anchored and input-locked during the stance, facing the target.** A charging stance that can walk is a different move (and needs a lower-body locomotion layer under an upper-body stance clip).
- **Press again releases early** with less damage. The reference scaled damage from 60% at minimum charge to 100% at full, with a per-weapon full-charge multiplier (1.2 to 4, default 2.3).
- **Short charges win.** The first version charged over 0.25 to 1.2 s; the third settled on **0.15 to 0.7 s**. A 1.2 s hold in a fast action game is a long time to stand still in front of enemies, and players rarely waited for it. Cooldown went the other way, 8 s to 12 s, so the move stays special.

## The clips

| Clip | Length | Markers | Arm QA score |
|---|---|---|---|
| QuickdrawStance | 1.2 s | Charge, Full | 90.7 |
| QuickdrawDraw (release from a sheath) | 0.45 s | Draw, Cut at 0.15, End | 84.4 |
| GripStance (two-handed, no sheath) | | | 92.2 |
| GripRise (two-handed release) | 0.45 s | Cut at 0.20 | 82.5 |
| StaffStance / StaffRise | | | |
| DashStance (older generic stance) | 1.25 s | Charge, Release | 93.5 |

All had zero arm "criticals" (see [[Arm QA Metrics Reference]]). Pose targets for the stance: hips about 41% lower than standing, torso twist under 8 degrees, head up, a lean of about 40 degrees. A low, coiled, still pose with the head up is what reads as "about to explode"; a twisting or bobbing stance reads as idle.

### Authored length versus gameplay length

The stance clip is authored at 1.2 s (plenty of frames for the settle into the crouch) but gameplay wanted a full charge at 0.7 s. Rather than re-author, the clip plays at about **1.71x** (1.2 / 0.7). Every marker moves in step with the speed: a `Full` marker placed at the end of the authored clip fires at exactly the 0.7 s full-charge time, so the marker can stay the single source of truth for "fully charged". (The project notes give the ratio, not the exact marker time; the code below assumes `Full` at the end.) General rule: **author for the pose, play at the gameplay speed, and keep the meaningful markers at the authored positions** so speed changes move them in step.

The reverse direction has a floor: release clips are **never played slower than 0.6x**, so the dash still fits between `Draw` and `Cut`. Slowing a release clip stretches its anticipation until the strike looks hesitant.

## Release: who moves the root

**Release clips do not move the root.** The ability code moves the `HumanoidRootPart`; the clip only poses the body around it. The reason: the release dash in the reference is very fast (**450 studs/s**, 10 to 40 studs through the target, as 2 or 3 snapped micro-blinks with up to 1.5 studs of side offset), with hits per segment on the server. Root motion baked into a clip would fight the scripted movement, and its distance would be wrong whenever the target is nearer or further.

The dash is timed from a **data table of marker times**, not from listening to markers at runtime:

| Release | Draw | Cut | End |
|---|---|---|---|
| Sheath draw | 0.05 | 0.15 | 0.45 |
| Two-handed rise | 0 | 0.20 | 0.45 |

The table lets the server time its hits without loading clips, and lets the client schedule the dash before the first frame plays. The cost: **if the clips are re-timed, the table must be updated**, or the dash fires off the visual cut. Generate the table from the clips in your build step if you can.

## Fitting the stance to the weapon

Different weapon shapes need different stances and releases. The reference assigned one of four sheath styles per weapon:

| Style | Count | Who | Release |
|---|---|---|---|
| saya | 16 | katanas and curved blades | draw from a fitted sheath at the left hip, horizontal flash cut |
| energy | 20 | energy blades | glowing energy sheath |
| sword | 69 | straight blades | sheath |
| none (grip) | 15 | heavy, scythe, floating or unheld weapons, very wide or bulky ones | two hands on the handle, rising slash low right to high left |

The sheath is **fitted to the stance pose**, not the idle: mouth at the guard, outside the left hip, clearing the body by at least 0.68 studs. Fitting to the idle put the sheath inside the thigh once the hips dropped 41%. Weapons too wide to sheath, or with orbiting parts, get style "none" and the two-handed grip stance.

## Preload or it plays late

The iai strike once played **about 5 seconds late** on first use in live servers. The ability's data timing was instant; the stance clip simply had not loaded, and the state machine waited for it. A direct "press equals strike" path was tried as a workaround and reverted; the real fix was **preloading**: load the tracks and call `ContentProvider:PreloadAsync` when the kit loads. And when a stance clip has no id at all, the move **casts immediately** instead of waiting. See [[Ability Kits Architecture]].

## The older generic stance (and why it was removed)

Before the shared iai strike, a generic `DashStance` (1.25 s, Action3, markers Charge and Release) was inserted in front of 75 dash moves: cooldown at press, anchored, input locked, facing the target, cast at 1.2 s, cancels refunded down to 1.5 s, with dust, arcs, a hilt glow and a release shockwave. It was turned off when the iai strike arrived. Lessons:
- A 1.2 s stance in front of every dash move made 75 different moves feel the same and slowed combat.
- One strong, dedicated stance move beats a stance tax on many moves.
- It was switched off by a data flag (`StanceEnabled = false`), not deleted, which made the rollback a one-line change.

## Feedback during the charge

What the player needs to see while holding:
1. **Progress**: a hilt glow or charge VFX that intensifies, ideally stepped (light at `Charge`, strong at `Full`) so "full" is unmistakable.
2. **A full-charge cue**: a flash and a sound at `Full`. Players release on the cue, not on the animation.
3. **Stillness**: the stance pose itself should barely move after the settle. Motion during the hold reads as "not ready yet".

On release the caster gets a camera kick, a flash, a hit-stop and a shake, all skipped while an ultimate camera owns the screen. See [[Camera Shake and Camera FX]].

## A charge move controller

```lua
--!strict
-- A stance-and-release move. stance and release are preloaded AnimationTracks.
local CHARGE_MIN, CHARGE_FULL = 0.15, 0.7   -- seconds (reference iai v3)
local DMG_MIN, DMG_MAX = 0.6, 1.0           -- damage fraction at min and full charge
local AUTHORED_STANCE = 1.2                 -- s, the stance clip's authored length

type State = "Ready" | "Charging" | "Releasing"

local Charge = {}
Charge.__index = Charge

function Charge.new(stance: AnimationTrack, release: AnimationTrack, onRelease: (frac: number) -> ())
	stance.Priority = Enum.AnimationPriority.Action4
	release.Priority = Enum.AnimationPriority.Action4
	stance.Looped = false
	return setmetatable({
		stance = stance, release = release, onRelease = onRelease,
		state = "Ready" :: State, t0 = 0, full = false, conns = {} :: { RBXScriptConnection },
	}, Charge)
end

function Charge:press()
	if self.state == "Ready" then
		self.state = "Charging"
		self.t0 = os.clock()
		self.full = false
		-- Play the 1.2 s clip so that its end (the Full marker) lands at CHARGE_FULL.
		self.stance:Play(0.05, 1, AUTHORED_STANCE / CHARGE_FULL)
		table.insert(self.conns, self.stance:GetMarkerReachedSignal("Full"):Connect(function()
			self.full = true -- cue VFX / sound here; hold the last pose
		end))
	elseif self.state == "Charging" then
		self:releaseNow()
	end
end

function Charge:releaseNow()
	if self.state ~= "Charging" then return end
	local held = os.clock() - self.t0
	if held < CHARGE_MIN then return end -- too early: ignore (or buffer) the release
	local u = math.clamp((held - CHARGE_MIN) / (CHARGE_FULL - CHARGE_MIN), 0, 1)
	local frac = DMG_MIN + (DMG_MAX - DMG_MIN) * u
	self.state = "Releasing"
	for _, c in self.conns do c:Disconnect() end
	table.clear(self.conns)
	self.stance:Stop(0.04)
	self.release:Play(0.03, 1, 1) -- never below 0.6x: the dash must fit Draw -> Cut
	self.onRelease(frac)           -- code moves the root; server times hits from its own table
	task.delay(self.release.Length, function() self.state = "Ready" end)
end

function Charge:cancel()
	if self.state ~= "Charging" then return end
	for _, c in self.conns do c:Disconnect() end
	table.clear(self.conns)
	self.stance:Stop(0.15)
	self.state = "Ready" -- refund part of the cooldown in the caller
end

return Charge
```

Notes: a one-shot that reaches its end holds its last pose and then fades out over 0.3 s (measured Animator behaviour, see [[How the Animator Really Behaves]]). If players may hold past full charge, either loop a short "hold" clip after `Full` or auto-release at the cap; do not rely on the end-of-clip hold, because the 0.3 s fade-out drops the character out of the stance. `self.release.Length` is 0 until the asset loads, which is one more reason to preload.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Strike plays seconds late the first time | Clip not loaded | Preload on kit load; cast at once without a clip |
| Dash fires off the visual cut | Clips retimed, marker table stale | Regenerate the table from clips |
| Sheath inside the thigh | Sheath fitted to the idle | Fit to the stance pose |
| Character pops out of the stance while holding | End-of-clip hold then 0.3 s fade | Hold loop or auto-release |
| Release looks hesitant | Release clip slowed below 0.6x | Keep the floor; shorten the dash instead |
| Stance cancel spam | Cooldown starts at release, or full refund | Cooldown at press, partial refund |

See also: [[Ability Kits Architecture]], [[Combat Combo Systems]], [[Markers and Events]], [[Weapon and Combat Animation]], [[Posing and Silhouettes]].

## Nuances and edge cases

1. **Charge time is measured where?** If the client measures hold duration and tells the server "I charged 0.7 s", an exploiter sends 0.7 every time. The server must measure from its own receipt of press and release, then allow for latency. A practical rule: the server's charge = server release time minus server press time, clamped to the legal range. Ping cancels out because both messages travel the same path, but jitter does not, so accept a small tolerance (rule of thumb: 50 ms) near the full-charge threshold.
2. **High ping makes the full cue lie.** On 250 ms ping, the client's full-charge cue is local and on time, but the release arrives at the server 125 ms after the player pressed. If the server also requires "full" at receipt time, players feel cheated rarely; if the server measures as above, it is consistent. Never let the server re-time the release to the cue on the client's word.
3. **Mobile input.** Hold-to-charge on touch needs a button that tolerates the thumb sliding. If the thumb slides off the button, does the charge cancel or release? Releasing is friendlier; cancelling punishes imprecise touches. Pick release, and make the button's hit area large.
4. **Gamepad triggers.** Analog triggers allow a partial press. Use a threshold with hysteresis (press above 0.6, release below 0.4, rule of thumb) so trigger noise does not release the charge early.
5. **Accessibility of holds.** Long holds are hard for some players. A "toggle charge" option (press once to start, again to release) costs almost nothing and removes the issue. Keep the same server timing rules.
6. **Scale and readability in crowds.** In a 2-player duel, opponents read the stance and respond; in a 30-player fight, the stance pose is lost in the crowd. The full-charge flash and sound do more work than the pose at that scale; make them distinct per move class so a charged attack is readable from across an arena.
7. **Anchoring and physics.** Anchoring the root during the stance is simple but has side effects: anchored characters cannot be knocked back, ignore moving platforms, and can freeze in mid-air if the stance starts during a jump. Refuse stance starts while airborne, or use a strong `AlignPosition` instead of anchoring if you want knockback to interrupt.
8. **Balance.** A stance that cannot move must be worth it. The reference numbers (60 to 100 percent damage across 0.15 to 0.7 s) are tuned for a fast game; slower PvE games can afford longer holds and bigger multipliers because enemies are telegraphed and predictable.

## Common mistakes in production

1. **Client-reported charge time.** Symptom: some players always hit full charge instantly. Fix: measure on the server.
2. **Stance allowed in the air.** Symptom: players hang anchored mid-jump. Fix: require grounded state, or end the stance on leaving ground.
3. **No timeout on a held stance.** Symptom: an AFK player holds a stance forever, or a dropped release message locks the character. Fix: auto-release at the cap plus a server timeout.
4. **Cancel paths that skip the refund logic.** Symptom: cooldowns inconsistent after death or stun. Fix: all exits go through one cancel function.
5. **Charge VFX replicated per frame.** Symptom: bandwidth spikes when many players charge. Fix: replicate state changes (start, charge level step, full, release) and let clients animate between them.

## Related decisions

- [[Server Authority and Validation]]: why charge timing must be measured on the server.
- [[Detecting Combat Exploits - Reach Rate and Aim]]: spotting impossible charge and release patterns.
- [[Input Responsiveness Buffering and Coyote Time]]: buffering a release that lands a frame early.
- [[Input Remapping and One-Handed Play]]: toggle-to-charge and remappable holds.
- [[Input - UserInputService and ContextActionService]]: reading holds and analog triggers.
- [[Combat Systems Architecture]]: where the stance state machine sits among other abilities.
- [[Balancing with Spreadsheets and Data]]: tuning charge ranges and multipliers.
- [[Feedback Timing - Sound Visual and Haptic Sync]]: making the full-charge cue land on one frame.
- [[Mover Constraints and Physics Controllers]]: holding a character in place without anchoring.

## Connected notes
<!-- auto-links:start -->
[[Equip Draw and Flourish Systems]] · [[Spec-Driven Move Authoring]] · [[Pipeline - New Animated Weapon]] · [[Combat Animation Craft]] · [[Anticipation]] · [[Input Buffering]] · [[Animation Start Here]]
<!-- auto-links:end -->
