---
tags: [procedural, hit-reaction, death, knockdown, springs, combat, enemies, luau, type/guide, area/animation, level/intermediate, api/LocalTransparencyModifier]
---
# Procedural Death Knockdown and Hit Reactions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Hits feel weightless: no hit-stop, no flash -> 40-90 ms freeze and a 0.1 s flash
> - Every hit looks identical: one flinch clip -> directional clips, or springs with noise
> - Reactions stack into jitter: flinches during stuns and knockups -> skip the flinch while a stronger reaction owns the body
>
> Cost: TL;DR ~120 tok · whole note ~3.7k tok. Read more: ## 1. Hit reactions · ## 2. Knockdowns and deaths · ## Common mistakes
<!-- tldr:end -->

Reactions are where combat feels fair or cheap. A hit with no visible effect on the target reads as a miss; a death that clips into a hill reads as a bug; a knockback that ignores where the blow came from reads as canned. Reactions are also where clips struggle most, because they depend on things a clip cannot know: the direction of the hit, how hard, what the target was doing, the slope under it, the moment another player's ultimate peaks. This note covers three families and the numbers one live action game (the reference project) used for each:

1. **Hit reactions** that layer over whatever the target is doing.
2. **Knockdowns and deaths** that take the body over.
3. **"Caught" sequences**: a body pulled, held and blasted in sync with someone else's attack.

## 1. Hit reactions

### Options

| Method | Reads as | Cost | Use |
|---|---|---|---|
| Directional flinch clips (front / back / left / right) | authored, consistent | 4+ clips per rig | players, important enemies |
| Spring impulses on the joints | physical, never repeats, layers over any clip | code only | crowds of enemies, every rig family |
| Hit-stop (a freeze of 40-90 ms on attacker and target) | weight | trivial | every meaningful hit |
| Flash (white or red overlay) | "registered" | trivial | always, as confirmation |
| Active ragdoll (limited joint torque) | physical | physics cost, ownership issues | special cases (see [[Ragdolls and Physics-Based Animation]]) |

The best results combine them: a short flash, a hit-stop, and either a directional clip or a spring kick.

### Choosing a direction

Bring the attacker's position (or the hit's velocity) into the target's root frame and pick by angle:

```lua
--!strict
-- "Front" / "Back" / "Left" / "Right" from where the hit came from, in the target's frame (-Z forward).
local function hitSide(targetRoot: BasePart, from: Vector3): string
	local d = targetRoot.CFrame:PointToObjectSpace(from)
	local yaw = math.deg(math.atan2(-d.X, -d.Z))        -- 0 = in front, +90 = on the left
	if math.abs(yaw) <= 45 then return "Front" end
	if math.abs(yaw) >= 135 then return "Back" end
	return if yaw > 0 then "Left" else "Right"
end
```

Name the clips by the side the hit came *from* and keep that convention everywhere; "HitLeft" meaning "recoil to the left" in one rig and "hit from the left" in another is a classic mix-up. The reference project's server wrote a replicated hurt attribute naming a directional clip (`Hit*`) or a heavy hit, and each client played it.

### Spring impulses (the reference project's enemy layer)

Its enemy reaction module gave every joint a damped spring holding a rotation vector, layered over the clip (see [[Springs Damping and Smoothing]] for the per-role frequencies). A heavy hit is a velocity impulse into those springs:

- **Direction**: the push direction (from the attacker, flattened to horizontal) in the body's frame; the impulse axis is `up x push`, so the top of the body tips along the push.
- **Strength**: `k = clamp(multiplier / 2, 0.5, 2)`.
- **Per-role amplitude** (rad/s, times `k`): head 5.5, arms 4, spine 3.2, dangling parts 4, tail 3, legs 0.8, plus 25% random noise per joint, so no two hits look the same.
- **Root**: an extra 55 degrees/s about the same axis on the root spring (6 Hz, damping 0.5), pivoting about the feet.

Smaller "jolts" (hits while held) use random directions with head 4, arms 5, spine 2.6, legs 2 rad/s and a root kick of 40 degrees/s in pitch.

The springs carry the motion: stiff spines snap back in about 0.13 s, loose arms and tails wobble on, giving overlap and follow-through for free. The layer writes `joint.Transform = (B^-1 * rot(x) * B) * animated`, where `B` is the joint's rest rotation, so the spring rotation is expressed in the joint's rest frame and applied over the clip. It restores the Animator's values in `PreAnimation` so the overlay never compounds, and switches itself off once every spring has settled (so idle enemies cost nothing).

```lua
--!strict
-- Minimal spring hit layer for one rig. joints: { motor, B (rest rotation), amp, f, zeta, x, v }.
local function heavyHit(joints: { any }, root: BasePart, from: Vector3, mult: number)
	local push = (root.Position - from) * Vector3.new(1, 0, 1)
	if push.Magnitude < 0.05 then push = -root.CFrame.LookVector end
	local pl = root.CFrame:VectorToObjectSpace(push.Unit)  -- push in the body frame
	local axis = Vector3.yAxis:Cross(pl)
	if axis.Magnitude < 1e-3 then return end
	axis = axis.Unit
	local k = math.clamp(mult / 2, 0.5, 2)
	for _, j in joints do
		local noise = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		j.v += axis * j.amp * k + noise * j.amp * 0.25 * k  -- velocity impulse, never a position jump
	end
end

-- In PreSimulation, after stepping each spring toward 0 (x, v as Vector3 rotation vectors):
--   local m = j.x.Magnitude
--   local r = if m > 1e-5 then CFrame.fromAxisAngle(j.x / m, m) else CFrame.identity
--   j.motor.Transform = (j.B:Inverse() * r * j.B) * j.motor.Transform
```

### Rules the project enforced on enemies

- Enemy clips never play below 1x speed, with one exception: the stagger hit at 0.5x.
- The hit flinch is skipped while the enemy is Caught, knocked up or stunned (stacking reactions reads as jitter).
- Bosses are not pulled into ultimates; they get the heavy-hit recoil instead.
- No turning while Caught or knocked up.
- Hit flash: pooled white `Highlight`s, at most 8 at once, 0.1 s fade, with the update loop connected only while one is live. Players got a red flash on any health loss, a bigger one for hits of 12% of max health or more, at most one per 0.12 s, skipped during the death effect.

## 2. Knockdowns and deaths

### The anchored topple (cheapest)

The project's fallback player death, with no clip at all:

```lua
--!strict
-- Topple onto the side over 0.55 s, root anchored (no physics, identical everywhere it runs).
local RunService = game:GetService("RunService")

local function topple(hrp: BasePart, hum: Humanoid, onDown: (() -> ())?)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = true
	local from = hrp.CFrame
	local drop = (hum.HipHeight + hrp.Size.Y * 0.5) * 0.7          -- lower the body toward the ground
	local to = from * CFrame.new(0, -drop, 0) * CFrame.Angles(0, 0, math.rad(84))   -- onto its side
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local u = math.clamp((os.clock() - t0) / 0.55, 0, 1)
		hrp.CFrame = from:Lerp(to, 1 - (1 - u) ^ 3)                 -- cubic ease-out: falls fast, settles
		if u >= 1 then
			conn:Disconnect()
			if onDown then onDown() end
		end
	end)
end
```

84 degrees rather than 90 keeps the body from looking perfectly flat and lets the lower shoulder appear to rest on the ground. A thud sound at 0.42 s (just before the end of the ease) sells the impact. Anchoring the root removes physics from the equation entirely, which also means the body ignores slopes: pair it with the ground clamp below if your arenas are not flat. (It writes the root's `CFrame`, which is why it can run in `PreRender`; joint `Transform` writes cannot.)

### The death clip version

The shipped version replaced the topple with an authored death clip: a hit recoil, down onto both knees, then back onto the ground, held. The sequence around it:

| Time (s) | Event |
|---|---|
| 0 | root stopped and anchored, stood upright facing the same way (the clip lowers and lays the body itself); death clip triggered by a character attribute |
| 0.48 | knees-hit-the-ground thud |
| 1.3 | back-hits-the-ground thud |
| 1.55 | **fizzle-out** begins (0.6 s in the topple version) |
| 2.45 | camera moves to the respawn point (fizzle + 0.9) |

The fizzle: a white `Highlight` on the character (fill and outline transparency 1 to 0 over 0.35 s, depth mode Occluded), a burst of 60 white sparks, and every body part except the root faded with `LocalTransparencyModifier` from 0 to 1 over 0.8 s. The respawn reverses it: parts start invisible, the highlight full white, 70 sparks converging inward, transparency back to 0 over 0.75 s, then the highlight fades over 0.4 s and the root is unanchored.

`LocalTransparencyModifier` is local to each client, which is exactly why every client runs the effect for every dying player (within 260 studs) from the server's replicated death attribute. The clip itself replicated through the game's normal clip relay.

### Never leave a body stuck

Deaths change state (anchored root, held poses, Scriptable cameras, transparency), and respawns race them. The project shipped two safety nets after "players get stuck on respawn":

- 1.6 s after the re-form starts, unanchor the root if it is still anchored and nothing else claims it.
- For the first 4 s after respawn, every 0.25 s: unanchor, clear the death-pose attribute, clear `PlatformStand` and `Sit`, push any `Physics` / `Ragdoll` / `FallingDown` state to `GettingUp`, restore the camera to `Custom` on the Humanoid, and after 2 s reset any leftover `LocalTransparencyModifier`.

### Enemy deaths on uneven ground

Enemies play their own death clips, with a runtime clamp that keeps every visible part above the visible ground and tilts a lying body to the slope (the 5 x 5 ray grid, plane fit and "rise at once, settle at 6 studs/s" lift described in [[Foot Placement and Ground IK]]). Measured: worst penetration from -9.37 studs to 0 or above.

## 3. Caught: pulled into someone else's attack

The project's ultimates pull enemies in, hold them, and blast them on the cinematic's climax. The first version was a clip (lift, held, slam at 2.42 s, back up by 3.4 s). It could not match different climax times, rig shapes or flying enemies, so it was replaced with procedural motion that runs on any rig.

### One definition per rig family

Joint roles come from each rig's own joint names and rest pose (spine, head, jaw, arm, leg, tail, wing, dangle, prop; arm and leg segments numbered from the body outward). The family is decided from the counts:

| Family | Rule | Feel multipliers (spine, root, arc, step, flail, roll) |
|---|---|---|
| flyer | 2 or more wings | 0.7, 1.0, 1.3, 0.4, 1.2, 0.8 |
| floater | no legs | 0.8, 1.2, 1.2, 0.0, 1.3, 1.0 |
| crawler | 4+ legs, or legs with a low wide body or 2+ claws | 0.45, 0.7, 0.6, 0.6, 1.15, 0.6 |
| biped | everything else | 1.0, 1.0, 1.0, 1.0, 1.0, 0.4 |

So the same sequence drives a biped, a six-legged beast, a crab or a ghost: a crawler's spine bends less, a floater never steps, a flyer arcs higher.

### The timeline (seconds after the catch)

| Phase | When | What the body does |
|---|---|---|
| Yank | 0 to about 0.22 | startle (head and spine snap back, arms up and curled, tremor), turns to face the pull within 0.2 s |
| Drag | 0.06 to `glide` (0.15-1.2, default 0.7) | leans back against the pull, heels dug in, arms thrown back, stumbling hops (4 Hz bounce, legs alternating at 3.2 Hz) |
| Held | `glide` to `climax - 0.3` | pinned at its slot, or hanging in the air for aerial catches: struggling (0.9 Hz sway, 1.6 Hz head shakes, limb flail at 2.4 Hz), a jolt on every hit |
| Squeeze | last 0.3 s before the climax | anticipation: curls in on itself, accelerating (quadratic ease-in) |
| Impact | the climax | arched back, limbs thrown wide, jaw open, held for the hit-stop (default 0.07 s; 0.04-0.16 from the attack's tier) |
| Survive | after the hit-stop | blown back (flight 0.36 s), heavy landing (0.6), two stagger steps back to its spot (0.62 and 0.9), settles (1.18), hands back to its own idle by 1.5 s |
| Die | after the hit-stop (or at once if killed before it) | thrown further and limp (0.46 s flight after an impact, 0.3 otherwise), lands, and its own Death clip shows through over 0.32 s |

Details that made it read well:

- **Synchronised to the camera, not the network.** For the player casting the ultimate, the climax time came from their local cinematic (the same frame as the camera's cut and [[impact frames]]), if it was within 0.6 s of the server's; onlookers used the server's time. Otherwise the caster saw the blast one network trip early or late.
- **Re-caught while held:** a second pull just moves the climax and extends the hold instead of restarting the sequence.
- **Joints follow targets through the springs**, so overlap and follow-through come for free and a jolt is just another impulse.
- **AI is locked** until 1.65 s after the climax; the full Caught behaviour always plays out (a longer hold extends it).
- **The ground clamp runs throughout**, so a body thrown down a slope lands on it.

All parameters are fractions of the rig's height or degrees, so the same numbers work for a 5-stud imp and a 40-stud brute.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Hits feel weightless | no hit-stop, no flash | 40-90 ms freeze and a 0.1 s flash |
| Every hit looks identical | one flinch clip | directional clips, or springs with noise |
| Reactions stack into jitter | flinches during stuns and knockups | skip the flinch while a stronger reaction owns the body |
| Knockback ignores where the hit came from | fixed clip | push direction into the body frame |
| Corpse half underground on slopes | clip authored on flat ground | runtime ground clamp |
| Players stuck after respawn | anchored root or state left from the death | watchdog for the first seconds after respawn |
| Ultimate blast lands before the camera's impact frame | server time used on the caster's screen | take the climax from the local cinematic |
| Spring layer slowly drifts the pose | overlay compounding | restore the Animator's values in `PreAnimation` |

Related: [[Hit Reactions Stagger and Hit-Stop]], [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Cinematic Ultimates]], [[Ragdolls and Physics-Based Animation]], [[Springs Damping and Smoothing]].

## Connected notes
<!-- auto-links:start -->
[[Animating Creatures and Monsters]] · [[Ground Fitting Pipeline]] · [[Procedural Animation]] · [[Creature Rig Conventions]] · [[Skeleton Library]] · Tween vs Spring · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Multi-Bone IK - FABRIK and CCD]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Procedural Motion]] · [[Boss Animation and Phases]] · [[Snippets - Ragdoll]] · [[Combat Animation Craft]] · [[Inverse Kinematics]] · [[Procedural Weapon Motion]]
<!-- related:end -->
