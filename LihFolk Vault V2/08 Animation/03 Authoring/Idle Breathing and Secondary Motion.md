---
tags: [authoring, craft, idle, breathing, secondary-motion, overlap, type/guide, area/animation, level/intermediate, api/Animator, api/Motor6D, api/AnimationConstraint]
---
# Idle Breathing and Secondary Motion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Statue idle -> breathing and weight shift; no dead holds over 0.3 s
> - Avoid: Panting idle -> 1 to 3 degrees, 3 to 5 s cycle
> - Avoid: Idle pose far from attack start poses -> keep the idle near the class rest; re-check clip entries if the...
>
> Cost: TL;DR ~100 tok · whole note ~3.6k tok. Read more: ## 4. Fidgets and variety · ## 7. Adding procedural layers without fighting the Animator · ## Common mistakes
<!-- tldr:end -->

The idle is the animation players look at the longest. It plays in menus, between fights, while chatting, and under every upper-body clip. Secondary motion (overlap, drag, small reactions of parts that are not the main action) is what separates "moving" from "alive". This note covers idle design, breathing and weight shifts, fidget systems, overlap and successive breaking, secondary motion on attachments, and how to add these procedurally on Roblox without fighting the Animator.

Labels: "reference project" = one live action game; "Roblox docs" = official API pages; "rule of thumb" = practice.

## 1. What an idle must do

1. **Show the character's state**: relaxed, alert, injured, carrying a heavy weapon.
2. **Loop invisibly** for minutes.
3. **Hand over cleanly** to every other clip. Every attack, emote and locomotion clip starts from and returns to it.
4. **Stay out of the way**: an upper-body attack layers over it, and a busy idle shows through as noise in the legs.
5. **Be cheap**: it is playing on every character in the server.

### Idle as the "neutral" pose
Because so many clips start and end on the idle, its pose is a design decision, not just an animation. The reference project's QA required every attack's first frame to be within **90 degrees** per arm joint of the idle, and its last frame within **75 degrees**, because short combat fades (0.05 s) make any mismatch a visible snap. If you change the idle pose later, every clip's entry and exit must be re-checked.

Carry poses complicate this. With a weapon held, the visible "idle" is the base idle plus a carry layer (in the reference project, a right-arm-only clip at Action priority). The carry pose was set **equal to the swings' end pose** so the forearm does not turn when a swing hands over to the carry.

## 2. Breathing

Breathing is the minimum motion that stops a character reading as a statue.
- **Rate**: a relaxed adult breathes about 12 to 20 times a minute, so a 3 to 5 s cycle. After exertion, 1.5 to 2.5 s. (Rule of thumb from physiology.)
- **Where**: the chest rises and expands on the inhale; the shoulders lift slightly; the head follows a little later; the belly moves in a relaxed idle. On R15 you only have the waist (UpperTorso), the neck and the shoulders, so: a small waist pitch back, a small lift of both upper arms, a delayed neck counter-rotation.
- **Amplitude** (rule of thumb): 1 to 3 degrees of waist pitch, 1 to 2 degrees on the shoulders, under 1 degree counter on the neck. Anything bigger reads as panting.
- **Asymmetry**: breathe slightly more into one side, and offset the shoulders by a few frames, so it is not a mechanical pump.
- **Inhale faster than exhale** (roughly 40:60), with a tiny pause at the bottom.

The reference project's idle loop was **4 s** long, a comfortable breathing rate.

## 3. Weight shifts and life

A real person standing still constantly shifts weight between the feet, adjusts posture and looks around.
- **Weight shift**: hips drift 0.05 to 0.15 studs side to side over several seconds, with the hip on the loaded side rising and the shoulders counter-tilting (contrapposto). Keep the feet planted.
- **Postural sway**: a very slow, small oscillation of the whole body (a few tenths of a degree), out of phase with breathing.
- **Head**: occasional small looks; the eyes would lead, but on R15 the head leads.
- **Hands**: a slight change in grip or finger tension is not available on R15; use small wrist rolls and the weapon's own idle instead.

Avoid **dead holds**: the reference project's QA flags every joint moving under about 4 degrees/s for more than 0.3 s (except at a clip's end) as a "dead hold" that reads as a mannequin.

## 4. Fidgets and variety

One loop repeated for minutes becomes noticeable. Add variants:
- **Fidget clips** (look around, shift weight, adjust the weapon, stretch), played occasionally on top of or instead of the base idle.
- Reference project (the set that shipped): an idle plus an idle fidget played after **10 s** standing still and then every **16 to 26 s**; a later locomotion system used IdleLook and IdleShift variants from a fidget timer that **never repeats the same variant twice running**.
- **Stop fidgets the moment the player acts.** A fidget playing over an attack start ruins the attack's first frames. Fade it out over the attack's fade-in.
- **Per-weapon idles**: the reference project let a blade carry its own standing idle (looked up by id), which replaced the free-arm relax and the fidget. Weapon-specific idles are cheap personality.

A fidget scheduler sketch:

```lua
--!strict
local Players = game:GetService("Players")

-- Plays a random fidget (never the same twice running) after the character has been still for a while.
local function runFidgets(humanoid: Humanoid, animator: Animator, fidgets: { Animation })
	local tracks: { AnimationTrack } = {}
	for i, anim in fidgets do
		local t = animator:LoadAnimation(anim)
		t.Priority = Enum.AnimationPriority.Idle -- same layer as the idle; it wins while playing at weight 1
		t.Looped = false
		tracks[i] = t
	end

	local lastIndex = 0
	local stillSince = os.clock()
	local nextAt = 10 -- first fidget after 10 s still (reference project value)

	humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			stillSince = os.clock()
			nextAt = 10
			for _, t in tracks do
				if t.IsPlaying then t:Stop(0.2) end -- moving cancels fidgets
			end
		end
	end)

	task.spawn(function()
		while humanoid.Parent do
			task.wait(0.5)
			if os.clock() - stillSince >= nextAt and #tracks > 0 then
				local i = math.random(1, #tracks)
				if #tracks > 1 and i == lastIndex then
					i = i % #tracks + 1 -- never repeat the previous variant
				end
				lastIndex = i
				tracks[i]:Play(0.3)
				stillSince = os.clock()
				nextAt = 16 + math.random() * 10 -- then every 16 to 26 s
			end
		end
	end)
end
```

In a real game also cancel fidgets when any Action-priority track starts, and skip them for players who are typing or in menus if you want.

## 5. Overlap and successive breaking

Overlapping action: parts of a body start and stop at different times. Successive breaking of joints: a motion propagates along a chain one joint after another (the tip moves last).

- In attacks: hips > chest > shoulder > elbow > wrist > weapon, about one frame per link at 30 fps (see [[Weapon Swing Design]]).
- In idles and settles: when the body stops, the head, arms and anything dangling continue a little and settle.
- **Implementation by delay**: sample each joint's channel slightly in the past. The reference project's baker used **waist 0.015 s, neck 0.035 s, free arm 0.05 s** lags behind the root. In a hand-keyed clip, the same effect is offsetting keys: shift the neck's keys 1 frame later than the waist's.
- **Too much overlap reads as rubber.** Keep lags small on stiff characters and large on loose ones (a robot vs a ragged spirit).

## 6. Secondary motion on attachments

Capes, hair, tails, chains, tassels, ears and weapon trinkets.

| Approach | Good for | Cost | Notes |
|---|---|---|---|
| Keyed in the clip | hero moments, cinematics | instances per key; hand work | exact, but must be redone per clip |
| Physics (constraints, unanchored parts) | loose props, chains | physics cost; network ownership | can jitter, can clip; hard to art-direct |
| Layered clothing / cloth | outfits | engine-managed | see [[Layered Clothing Cages and Animation]] |
| Procedural springs on joints | tails, ears, hair bones, trinkets | small CPU per joint | art-directable, stable, cheap |
| Additive loops | wings, tentacles, flags | one extra track | the reference project used an additive flap loop for flyers |

The reference project's choices:
- Hanging **chain links on weapon rigs were welded rigid** (a held rig is massless and replicated; simulating it was not worth it).
- **Orbiting and floating pieces** (halos, orbiting stones, lanterns) were stripped from clips and spun procedurally on the client.
- Weapon "rig" idles ran **8 s** loops on the weapon's own joints.

## 7. Adding procedural layers without fighting the Animator

The Animator writes each joint's `Transform` every frame. Roblox docs (`Motor6D.Transform`): the Animator overwrites it "after RunService.PreAnimation and before RunService.PreSimulation", and transforms are applied "as a batch in a parallel job after RunService.PreSimulation". So:
- Writing `Transform` in **PreAnimation** is pointless: the Animator overwrites it.
- Writing in **PreSimulation** sees the Animator's result for this frame and can **modify** it. Multiply your offset onto the existing value.
- Alternatively, change `C0` (or the attachment frames for `AnimationConstraint` joints), which the Animator never touches. The reference project turned the head and waist toward the cursor by setting Neck and Waist `C0`.

A breathing layer, additive on top of whatever is playing:

```lua
--!strict
local RunService = game:GetService("RunService")

-- Adds breathing on top of the animated pose. Works with Motor6D; for AnimationConstraint joints
-- the same multiply works on AnimationConstraint.Transform.
local function addBreathing(waist: Motor6D, neck: Motor6D, period: number, amplitudeDeg: number)
	local phase = math.random() * period -- desynchronise characters
	return RunService.PreSimulation:Connect(function()
		local t = (os.clock() + phase) % period / period -- 0..1 through the breath
		-- inhale 40% of the cycle, exhale 60%: a smooth asymmetric wave
		local s = if t < 0.4 then math.sin(t / 0.4 * math.pi / 2) else math.cos((t - 0.4) / 0.6 * math.pi / 2)
		local a = math.rad(amplitudeDeg) * s
		waist.Transform = waist.Transform * CFrame.Angles(-a, 0, 0)        -- chest rises (pitch back; sign depends on rig axes)
		neck.Transform = neck.Transform * CFrame.Angles(a * 0.6, 0, 0)      -- head counters to stay level
	end)
end
```

Notes:
- The sign of "pitch back" depends on the joint's axes; test on your rig.
- This runs on every client for every visible character. Gate it by distance (see below) and stop it when the character is far, dead or in a cutscene.
- If a high-priority clip should not breathe (a held aim, a cinematic pose), scale the amplitude by a "procedural weight" you fade with that clip.
- Additive layers must not accumulate: always start from the Animator's value for this frame (multiplying onto `Transform` in PreSimulation does that, because the Animator rewrote it this frame). If no Animator drives that joint, your writes **do** accumulate; use `C0` or store the base instead.

A damped spring for a dangling part (tail, trinket) uses the same pattern: compute the parent's angular velocity, run a spring per joint, and multiply the spring's rotation onto `Transform`. See [[Springs Damping and Smoothing]] and [[Snippets - Procedural Motion]].

## 8. NPC idles

NPCs stand around in view for a long time and deserve richer idles, but there may be dozens.
- The reference project's shopkeeper ran polish, look and coin idles, waved at players within **15 studs**, turned its head toward players within **26 studs**, all through `Motor6D.Transform`, and **slept beyond 280 studs**.
- Distance gating saves the most: animate nothing beyond the point where a player could notice. The reference project's Lua clip player updated every frame within 60 studs, every 2nd frame within 150, every 4th within 300, and only advanced time beyond that. See [[Animation LOD]].
- Desynchronise identical NPCs (random start phase, random speed within 0.9 to 1.1x) or crowds pulse together.

## 9. Idles under upper-body clips

Upper-body attacks and casts play over the idle's legs. If the idle has big hip motion, the legs drift while the upper body is locked by the attack, and the waist twists oddly between them. Keep idle hip motion small, or have upper-body clips key LowerTorso at a neutral value (accepting that they then override the idle's hip motion).

## 10. Loops that do not seam

- Duplicate the first pose as the last (the editor does not interpolate last to first; see [[Animation Editor Workflow]]).
- Match velocities across the seam, not only poses: a breathing curve that is still rising at the end and starting from rest at the beginning will hitch.
- Make cycles of different channels **divide the loop length**: if the loop is 4 s, breathing at 4 s and sway at 8 s will not fit; use 2 s and 4 s, or make sway procedural.
- Check the seam at 60 Hz by scrubbing across it.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Statue idle | mannequin | breathing and weight shift; no dead holds over 0.3 s |
| Panting idle | nervous, distracting | 1 to 3 degrees, 3 to 5 s cycle |
| Idle pose far from attack start poses | snaps on every attack | keep the idle near the class rest; re-check clip entries if the idle changes |
| Fidget during attack start | broken first frames | cancel fidgets on any action |
| Procedural layer accumulating | joint spins away over time | multiply onto the Animator's fresh value, or use C0 |
| Everyone breathing in sync | crowds pulse | random phase per character |
| Physics on every dangling part | jitter, network cost | springs or welds; physics only where it matters |

## See also
[[Principles of Animation for Games]], [[Procedural Animation]], [[Springs Damping and Smoothing]], [[Look-At Aim and Head Tracking]], [[Frame Order and RunService Timing]], [[Animation LOD]], [[Locomotion Systems]], [[Enemy and NPC Animation]].

## Connected notes
<!-- auto-links:start -->
[[Animation Review Checklist]] · [[Posing and Silhouettes]] · [[Playback, Priorities and Blending]] · [[Retargeting Animations Between Rigs]] · [[AI Animation and Motion from Video]] · Modeling Characters for R15 and Custom Rigs · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Timing Spacing and Frame Charts]] · [[R15 Run Cycle Key Poses]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Spec-Driven Move Authoring]] · [[Locomotion Clip Lessons - Jump, Sprint, Idle]] · [[Combat Animation Craft]] · [[Animating Creatures and Monsters]] · [[Animation Quality Standard]]
<!-- related:end -->
