---
tags: [performance, lod, runtime, design]
---
# Animation LOD

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Skipping the whole update for far rigs, including time and events.
> - Avoid: Updating every Nth frame but advancing by one frame's dt (slow motion at range).
> - Avoid: All rigs re-tiering on the same frame (periodic spike).
> - Time and gameplay events advance for every rig every frame.
> - Skipped frames accumulate dt.
> - Tiers re-evaluated on a staggered schedule, with hysteresis.
>
> Read more (13 KB note): ## 3. LOD for Lua players and procedural rigs · ## 5. A scheduler that respects time and events · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Level of detail for animation means spending evaluation time where the player can see the result, and almost none where they cannot. Done well it is invisible and cuts animation CPU by 3 to 10 times in crowded scenes. Done badly it causes the most confusing bugs in a game: hits that land without a swing, markers that never fire, enemies that teleport into a pose as you approach, and gameplay that differs by distance.

The central rule, learned in one live action game:

> **LOD may skip writing poses. It must never skip time or events.**

---

## 1. What you can reduce, and what you cannot

| Thing | Can LOD it? | Notes |
|---|---|---|
| Writing joint `Transform`s | yes | The main saving. Skip frames, or stop entirely off-screen. |
| Sampling clips | yes | Only needed for frames you write. |
| Procedural layers (IK, look-at, springs, foot plant) | yes | Usually the first to go: they cost more than sampling. |
| Secondary motion (cloth, tails, weapon hinges) | yes | Freeze or simplify at mid range. |
| Advancing track time | **no** | Clips must end on time, loops must stay in phase, so the rig is in the right pose when you look again. |
| Firing markers and events | **no** (gameplay), **yes** (cosmetic FX) | A `Hit` marker that drives damage or a sound must fire. Spawning particles for a hit 300 studs away can be skipped. |
| State machine decisions (which clip plays) | no | Must match what everyone else sees. |
| Network replication of state | separately | Send coarse state at range, not per-frame data. |

The trap is that most simple LOD implementations skip the whole update for far rigs, which skips time and events too. Then a far enemy's attack ends late, its `Hit` never fires, and when the player walks closer the rig is frozen in an old pose until something new plays.

---

## 2. Engine LOD for the real Animator

For clips played by the engine `Animator` (Docs):
- `Animator.PreferLodEnabled` (default true): the engine may reduce evaluation frequency for **remotely simulated** characters based on distance, screen coverage and frame budget.
- `Animator.EvaluationThrottled` (read-only): true when evaluation was skipped this frame and the previous pose is reused.
- `Workspace.ClientAnimatorThrottling`: enables or disables throttling for all Animators.

Consequences:
- Your own character and other locally simulated rigs are not throttled by this.
- Procedural code that adds offsets to `Transform` must check `EvaluationThrottled` (or keep its own base pose), because on a throttled frame the Animator did not rewrite `Transform` and the offset would compound. Docs suggest skipping procedural offsets on throttled frames.
- Turning `PreferLodEnabled` off forces full fidelity. Do it only for a handful of hero rigs (a boss in a cinematic). Docs warn that disabling it on many Animators hurts performance.
- Docs describe a throttled frame as reusing the previous pose. Whether marker signals can fire late on throttled remote characters is not documented (unverified). Do not drive gameplay from markers on remote characters anyway (see [[Markers and Events]]).

---

## 3. LOD for Lua players and procedural rigs

If you animate in Lua (a keyframe player, a weapon-hinge player, procedural creatures), you own LOD. Two production schedules, both measured to be visually clean:

### Characters and enemies (a Lua keyframe player)
| Tier | Range from camera | Update |
|---|---|---|
| Near | within 60 studs, and always your own character | every frame |
| Mid | to 150 studs | every 2nd frame |
| Far | to 300 studs | every 4th frame |
| Beyond | over 300 studs | time only (events still fire, no writes) |
| Off-screen | any range | time only; visibility re-checked every 3 frames |

### Weapon-part rigs (a hinge player)
| Tier | Range | Update |
|---|---|---|
| Own weapon, or within 40 studs | any | every frame |
| Mid | to 120 studs | every 3rd frame |
| Far | to 300 studs | every 10th frame |
| Beyond | over 300 studs | every 30th frame |
| Not under Workspace | n/a | never |

Two details made these work:
- **The tier is re-evaluated every 15 frames, with a random phase per rig.** Recomputing distance every frame is wasted work, and if all rigs re-tier on the same frame you get a periodic spike.
- **Skipped frames accumulate `dt`.** If your implementation advances time only on update frames, a rig updated every 4th frame must advance by the sum of the 4 frame times, not by one frame's dt. Otherwise far animations run in slow motion. (The scheduler below sidesteps this by advancing time every frame and skipping only the writes.)

Measured cost for scale: about 22 microseconds per 25-bone rig per updated frame. With the schedule above, a scene with 15 near and 40 far enemies costs a fraction of a millisecond.

### Ambient and world animation
| Thing | Range rule used |
|---|---|
| Shopkeeper NPC idle (polish, look, wave) | sleeps beyond 280 studs |
| Spinning gate frames | animate within 900 studs |
| Hub effect pieces | 280 to 650 studs depending on size |
| Bird flocks | unparented beyond 900 studs, off-screen culled |
| Foliage sway | 30 Hz, only near the camera, via `BulkMoveTo` |
| Arena floaters | quality-gated, `BulkMoveTo` |

---

## 4. Choosing the metric

| Metric | Pros | Cons |
|---|---|---|
| Distance to camera | Cheap, predictable | A huge boss at 200 studs fills the screen; a tiny critter at 30 does not |
| Distance to the local character | Matches gameplay relevance | Wrong in cinematics and spectate cameras |
| Screen-space size (radius / distance, scaled by FOV) | Matches what the eye sees; handles scale | Needs a bounding radius per rig |
| On-screen test | Huge saving when the camera faces away | Must be re-checked; pop risk when turning fast |
| Importance flags | Lets design overrule maths | Needs discipline |

A good default: tier by `distance / rigRadius` (effectively screen size), force full rate for the local character, current target, bosses and anything in a cutscene, and drop to time-only when off-screen with a small margin.

```lua
-- Rough screen-size tier. radius = bounding radius of the rig in studs.
local function lodTier(cam: Camera, pos: Vector3, radius: number, important: boolean): number
	if important then return 1 end
	local rel = cam.CFrame:PointToObjectSpace(pos)
	local dist = -rel.Z                                    -- distance along the view direction
	if dist < -radius then return 0 end                    -- behind the camera: time only
	local size = radius / math.max(dist, 1)                -- proportional to on-screen size
	size *= 70 / cam.FieldOfView                           -- zoomed-in cameras see more detail
	if size > 0.05 then return 1 end                       -- every frame
	if size > 0.02 then return 2 end                       -- every 2nd frame
	if size > 0.008 then return 4 end                      -- every 4th frame
	return 0                                               -- time only
end
```
The thresholds are rules of thumb: tune them so the switch from 1 to 2 happens around 60 studs for a 3-stud-radius humanoid, which reproduces the distance table above.

---

## 5. A scheduler that respects time and events

```lua
--!strict
-- Minimal LOD scheduler for Lua-animated rigs. Each rig provides advance(dt) (time + events, always)
-- and write() (sample + set Transforms, only on its update frames).
local RunService = game:GetService("RunService")

export type LodRig = {
	root: BasePart,
	radius: number,
	important: boolean,
	advance: (dt: number) -> (),     -- advances clip time, fires markers; cheap
	write: () -> (),                 -- samples clips and writes joints; expensive
	-- scheduler state
	_rate: number?, _phase: number?, _acc: number?,
}

local rigs: { LodRig } = {}
local frame = 0

local function tierOf(r: LodRig, cam: Camera): number
	if r.important then return 1 end
	local rel = cam.CFrame:PointToObjectSpace(r.root.Position)
	local dist = -rel.Z
	if dist < -r.radius then return 0 end
	local size = r.radius / math.max(dist, 1) * (70 / cam.FieldOfView)
	if size > 0.05 then return 1 elseif size > 0.02 then return 2 elseif size > 0.008 then return 4 end
	return 0
end

RunService.PreSimulation:Connect(function(dt: number)
	frame += 1
	local cam = workspace.CurrentCamera
	for _, r in rigs do
		if not r.root.Parent then continue end
		-- re-tier every 15 frames, each rig on its own phase so re-tiering is spread out
		r._phase = r._phase or math.random(0, 14)
		if r._rate == nil or (frame + (r._phase :: number)) % 15 == 0 then
			r._rate = tierOf(r, cam)
		end
		r.advance(dt)                                   -- ALWAYS: time and gameplay events
		local rate = r._rate :: number
		if rate == 0 then continue end                  -- time only: no writes
		if (frame + (r._phase :: number)) % rate == 0 then
			r.write()                                   -- samples at the current (already advanced) time
		end
	end
end)

return {
	add = function(r: LodRig) table.insert(rigs, r) end,
	remove = function(r: LodRig)
		local i = table.find(rigs, r)
		if i then table.remove(rigs, i) end
	end,
}
```

Notice that `advance` runs every frame for every rig. That is the cheap part (a few float adds and an event scan). The expensive `write` is what LOD skips. If even `advance` is too expensive for thousands of rigs, advance far rigs in batches with accumulated dt, but fire their gameplay events at the correct time by checking event times against the accumulated window.

---

## 6. Layered LOD: degrade gracefully

Rather than one switch from "full" to "nothing", drop the expensive layers first:

| Tier | Clips | Procedural layers | Secondary motion | FX from markers |
|---|---|---|---|---|
| 1 (near) | every frame | foot IK, look-at, springs | full | all |
| 2 (mid) | every 2nd frame | look-at only | hinges every 2nd frame | all |
| 3 (far) | every 4th frame | none | frozen | gameplay-critical only |
| 0 (beyond, off-screen) | time only | none | none | sounds within range only |

Procedural layers often cost more than the clip sampling itself (an IK solve with raycasts per foot, per frame). Dropping foot IK at 60 studs is invisible; dropping clip sampling at 60 studs is not.

---

## 7. Avoiding visible pops

- **Hysteresis.** Use slightly different thresholds going up and down (for example promote at 55 studs, demote at 65) so a rig at the boundary does not flicker between tiers.
- **Catch-up write on promotion.** When a rig moves from time-only to a writing tier, write immediately that frame rather than waiting for its phase, so it does not show a stale pose.
- **Turn off IK with a fade, not a cut.** A foot IK layer that switches off snaps the foot by the IK correction. Fade its weight over 0.2 s.
- **Do not LOD the rig the player is fighting**, even if it is far (a ranged duel at 100 studs). Mark the current target as important.
- **Physics-driven joints** (ragdolls, `AnimationConstraint` with `IsKinematic` false) are simulated by physics; LOD on your writes changes their targets, not their simulation.

---

## 8. Network LOD

Animation state replicated to clients should be coarse:
- Send "clip X started at server time T at speed S" once, not poses. Every client reconstructs the pose at any time from that, which also makes LOD and late joining free. See [[Enemy Animation State Protocol]].
- For Lua-played character clips relayed through the server, the reference project batched updates and sent speed changes at once only when they changed by 6% or more, otherwise at most every 0.25 s.
- Clip data streams once per client and is cached; never resend it per spawn.

---

## Common mistakes
- Skipping the whole update for far rigs, including time and events.
- Updating every Nth frame but advancing by one frame's dt (slow motion at range).
- All rigs re-tiering on the same frame (periodic spike).
- Disabling engine `PreferLodEnabled` globally "to fix jitter".
- Compounding procedural offsets on throttled frames.
- Spawning full hit FX for every far enemy marker.
- LOD that changes gameplay: damage, hitboxes and telegraphs must not depend on the viewer's distance.

## Checklist
- [ ] Time and gameplay events advance for every rig every frame.
- [ ] Skipped frames accumulate dt.
- [ ] Tiers re-evaluated on a staggered schedule, with hysteresis.
- [ ] Own character, current target, bosses and cutscene rigs forced to full rate.
- [ ] Off-screen rigs write nothing.
- [ ] Procedural layers degrade before clip sampling does.
- [ ] Engine LOD left on for crowds; procedural code checks `EvaluationThrottled`.

## See also
[[Performance and Memory]] · [[Lua Keyframe Player Internals]] · [[Weapon Rig Player]] · [[Snippets - Enemy Client Animator]] · [[Snippets - Lua Keyframe Player Core]] · [[Frame Order and RunService Timing]]

## Connected notes
<!-- auto-links:start -->
[[Animator Deep Dive]] · [[Replication and Ownership]] · [[Procedural Animation]] · [[Animation Start Here]] · [[AI Animation and Motion from Video]] · [[Interest Management and Per-Player Replication]]
<!-- auto-links:end -->
