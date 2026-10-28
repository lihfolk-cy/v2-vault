---
tags: [field-notes, animation, keyframes, euler, interpolation, easing, procedural, luau]
---
# Animation Data Hygiene - Euler Wrap Joint Holes and Easing

<!-- tldr:start -->
> [!tldr] TL;DR
> - One-frame forearm spin mid-swing: Euler lerp across the 180-degree boundary -> Wrapped delta, or convert to CFrame and `Lerp`
> - Torso hitch on certain keys: Joint missing from a key, player falls back to rest -> Fill holes at load
> - Big swing "teleports": Cubic ease-in on a short, large arc -> Gentler curve or a mid key
> - Rotations blended as CFrames, or Euler channels use a wrapped delta.
> - Every key complete after a load-time hole fill.
> - Large short arcs avoid cubic ease-in or have a mid key.
>
> Cost: TL;DR ~170 tok · whole note ~1.6k tok. Read more: ## 1. Euler channels across plus or minus 180 degrees · ## 2. A joint missing from one key snaps to rest · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A custom keyframe player (a Luau module that samples poses and writes `Motor6D.Transform`, or a procedural layer that blends authored keys) inherits every flaw of its data. Three flaws caused most of the visible glitches in a shipped melee game: Euler angles blended the long way round across 180 degrees, joints missing from some keys snapping to rest, and a cubic ease-in that crammed a huge swing into two frames. None of them throws an error; all of them look like "the animation is broken". Player internals are in [[Lua Keyframe Player Internals]]; interpolation theory in [[Keyframes, Easing and Interpolation]] and [[Rotations Angles and Quaternions]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Euler channels across plus or minus 180 degrees

If poses are stored as Euler angles per channel (common when data comes from a spreadsheet, a JSON export or a hand-written table), blending channel by channel takes the numerically shortest path, not the rotationally shortest. From 170 degrees to -170 degrees is a 20-degree turn, but a naive lerp goes through 0: a 340-degree spin in the opposite direction.

**Measured.** Channels that crossed the 180-degree boundary produced a near-full spin of the limb for a frame or two mid-blend. Glitches like this are easy to miss at full speed and obvious at 0.25 speed.

Fix per channel with a wrapped difference:

```lua
local TAU = 2 * math.pi

-- Shortest signed difference from a to b, in (-pi, pi].
local function angleDelta(a: number, b: number): number
	return (b - a + math.pi) % TAU - math.pi
end

local function lerpAngle(a: number, b: number, t: number): number
	return a + angleDelta(a, b) * t
end
```

Luau's `%` returns a result with the sign of the divisor (floored modulo), so this works for negative inputs without extra branches.

Better still, **convert to CFrames once at load** and blend with `CFrame:Lerp`, which interpolates rotation along the shortest arc (Roblox docs). Euler-per-channel blending also suffers from gimbal effects on large multi-axis rotations; CFrame blending avoids both problems. Keep Euler only for authoring and storage.

## 2. A joint missing from one key snaps to rest

Keyframe formats let a key omit joints that "did not change". A player that builds each frame by looking up only the two surrounding keys will find the joint missing in one of them and fall back to the rest pose (identity), producing a one-key snap.

**Measured.** Clips with keys that set only some joints made the unset joints snap to rest and back on those keys: a visible one-key hitch.

Fix the data, not the player: at load, fill every hole by interpolating between the nearest earlier and later keys that do have the joint.

```lua
-- keys: array sorted by time; each key = { time = number, poses = { [jointName]: CFrame } }
local function fillHoles(keys, jointNames: { string })
	for _, joint in jointNames do
		for i, key in keys do
			if key.poses[joint] == nil then
				local before, after
				for j = i - 1, 1, -1 do
					if keys[j].poses[joint] then before = keys[j] break end
				end
				for j = i + 1, #keys do
					if keys[j].poses[joint] then after = keys[j] break end
				end
				if before and after then
					local t = (key.time - before.time) / (after.time - before.time)
					key.poses[joint] = before.poses[joint]:Lerp(after.poses[joint], t)
				elseif before or after then
					key.poses[joint] = (before or after).poses[joint] -- hold the nearest value
				end -- a joint absent from every key genuinely stays at rest
			end
		end
	end
end
```

Run it once per clip at load and cache the result. After filling, every key is complete and the sampler can stay simple and fast.

## 3. Cubic ease-in on a big swing

A cubic ease-in (`t^3`) keeps the start slow and puts most of the motion at the end. On a short, large swing at a low frame rate, that concentrates the visible motion into the last frame or two.

Worked example: a 0.2 s segment at 30 fps is six frames. Sampled at frames 1 to 6, cubic ease-in gives progress 0.005, 0.037, 0.125, 0.296, 0.579 and 1.0. **The last two frames carry 70% of the swing.** On a 150-degree slash that is about 105 degrees across two frames: the eye sees a pop, not an arc, and motion blur or a trail is the only thing hinting at the path.

Rules of thumb:

- For large arcs under about 0.25 s, use quadratic ease-in or a custom curve whose last frame carries under 35% of the motion.
- Add a key in the middle of a big swing rather than relying on easing to shape it.
- Check spacing at 30 fps, the frame rate many phones run, not only at 60 ([[Timing Spacing and Frame Charts]]).

## A load-time validator

Catch all three at load in Studio, not in playtests:

- Any Euler channel jump over 180 degrees between adjacent keys: warn with clip, joint and key time.
- Any key missing a joint that appears in other keys: log, then fill.
- Any segment where one frame at 30 fps carries over 40% of a rotation larger than 90 degrees: warn.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| One-frame forearm spin mid-swing | Euler lerp across the 180-degree boundary | Wrapped delta, or convert to CFrame and `Lerp` |
| Torso hitch on certain keys | Joint missing from a key, player falls back to rest | Fill holes at load |
| Big swing "teleports" | Cubic ease-in on a short, large arc | Gentler curve or a mid key |
| Looks fine at 60 fps, broken on phones | Spacing checked only at high frame rate | Review spacing at 30 fps |

## Checklist

- [ ] Rotations blended as CFrames, or Euler channels use a wrapped delta.
- [ ] Every key complete after a load-time hole fill.
- [ ] Large short arcs avoid cubic ease-in or have a mid key.
- [ ] Validator runs on every clip at load in Studio.
- [ ] Clips reviewed at 0.25 speed and at 30 fps.

## Connected notes
<!-- auto-links:start -->
[[Lua Keyframe Player Internals]] · [[Keyframes, Easing and Interpolation]] · [[Rotations Angles and Quaternions]] · [[Timing Spacing and Frame Charts]] · [[Weapon Swing Design]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
