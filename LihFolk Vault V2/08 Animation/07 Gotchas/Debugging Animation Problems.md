---
tags: [gotchas, debugging, method, tools, type/guide, area/animation, level/intermediate, api/Animator, area/debugging, api/Part1, api/AnimationConstraint, api/Animation]
---
# Debugging Animation Problems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Observation sentence written with rig, mode, viewer, clip, symptom, time.
> - Track id printed; `Length > 0` confirmed.
> - `GetPlayingAnimationTracks` report captured at the moment of the bug.
> - Clip soloed (other tracks and Animate off).
> - Clip tried on a known-good rig.
> - Owner, other client and server compared.
>
> Cost: TL;DR ~120 tok · whole note ~4.7k tok. Read more: ## Step 2: isolate the track · ## The power tools · ## Checklist
<!-- tldr:end -->

Animation bugs are hard because the evidence is visual and fleeting, and because six different systems sit between "I called Play" and "the arm moved": the asset service, the Animator's mixer, the joints, your own procedural code, replication, and the frame scheduler. This note is a method for narrowing a bug down to one of those quickly, plus the tools that make each step cheap. For known symptoms go straight to the [[Troubleshooting Table]]; for the engine behaviours behind them, see [[Engine Gotchas]].

---

## The six suspects

Every animation bug in the reference project (one live action game) turned out to live in exactly one of these. Name the suspect before you change code.

| Suspect | Question it answers | Typical failure |
|---|---|---|
| **Asset** | Does the clip data exist and load here? | Studio-only id, wrong owner, not loaded yet, stub with no Poses |
| **Track** | Is a track actually playing, at what time, weight and speed? | `LoadAnimation` per use, restarted every frame, `Length` 0, stopped early |
| **Priority / blend** | Who wins each joint? | A higher layer keys the joint; same-priority averaging; weight toward rest |
| **Rig** | Do the clip's pose names match joints, and does the joint type behave? | Renamed part, missing Motor6D, [[AnimationConstraint]] not handled, root pose keyed |
| **Replication** | Who is playing it, and who can see it? | NPC played on a client, Lua writes not mirrored, markers on the wrong machine |
| **Timing** | When does each write happen in the frame? | Procedural write before the Animator, compounding on throttled frames, task.wait drift |

A seventh category, **the data is fine but the motion is ugly**, is a craft problem, not a bug. Use [[Animation Review Checklist]] and [[Arm QA Metrics Reference]] for those.

---

## Step 0: reproduce and write down the observation

Before touching anything, write one sentence in this form:

> On **[rig]** in **[Studio Edit / Play solo / Team test / live]**, as **[owner / other client / server view]**, clip **[name]** shows **[symptom]** at **[time or event]**.

Each bracket is a variable you will flip during isolation. Half the time, filling them in already tells you the answer. "Works in Play solo, broken live" points at the asset (Studio-only id). "Fine for me, wrong for my friend" points at replication. "Only the first time" points at loading.

Then capture the evidence:
- A short screen recording, stepped frame by frame.
- If it is a pose problem, a **filmstrip** (below).
- If it is a timing problem, a log of `os.clock()` with every marker and state change.

---

## Step 1: isolate the asset

Questions, in order:
1. **What id is the track actually using?** Print `track.Animation.AnimationId`. Is it `rbxassetid://...` (published), a hash or `active://` (Studio-only registration), or empty?
2. **Is the clip loaded?** `track.Length > 0` after a second or two. If it stays 0, the asset never loaded: wrong owner, a moderated or deleted asset, or a Studio-only id outside Studio.
3. **Is it the clip you think it is?** Load the `KeyframeSequence` source (if you have it) and compare: length, keyframe count, which joints are keyed. A stubbed clip (Poses removed, data in an attribute; see [[Baked Clip Stubs and Archiving]]) looks empty to the Animation Editor and to the real Animator.
4. **Does the clip contain what you expect?** Dump its poses (snippet below). A clip that keys only weight-0 placeholders on the legs does not move the legs.

```lua
-- Dump a KeyframeSequence: one line per weighted pose. Run in the command bar.
local function dumpKS(ks: KeyframeSequence)
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	print(("%s  loop=%s  priority=%s  keyframes=%d"):format(ks.Name, tostring(ks.Loop), ks.Priority.Name, #kfs))
	for _, kf in kfs do
		local marks = {}
		for _, m in kf:GetMarkers() do table.insert(marks, m.Name .. "=" .. m.Value) end
		print(("  t=%.3f  %s  %s"):format(kf.Time, kf.Name, table.concat(marks, ",")))
		for _, p in kf:GetDescendants() do
			if p:IsA("Pose") and p.Weight > 0 then
				local _, ang = p.CFrame:ToAxisAngle()
				print(("    %-16s %6.1f deg  pos %.3f  %s/%s"):format(
					p.Name, math.deg(ang), p.CFrame.Position.Magnitude, p.EasingStyle.Name, p.EasingDirection.Name))
			end
		end
	end
end
dumpKS(workspace.Dummy.AnimSaves.Slash1)   -- your clip here
```

Things to look for in the dump: key-to-key jumps over 120 degrees, any exact 180, legacy `Cubic`, translations on arm joints (over 0.05 studs reads as a detached shoulder), and keys on the top-level root pose (never applied).

---

## Step 2: isolate the track

Ask the Animator what it is actually doing. `Animator:GetPlayingAnimationTracks()` returns every active track, including ones fading out (Docs).

```lua
-- Live track monitor: prints every 0.25 s while the panel is open. LocalScript or command bar in Play.
local function trackReport(animator: Animator): string
	local lines = {}
	for _, tr in animator:GetPlayingAnimationTracks() do
		table.insert(lines, ("%-20s %-8s t=%5.2f/%5.2f w=%.2f->%.2f spd=%.2f %s%s"):format(
			tr.Animation and tr.Animation.Name or tr.Name,   -- the Animation object's name is the useful label
			tr.Priority.Name,
			tr.TimePosition, tr.Length,
			tr.WeightCurrent, tr.WeightTarget,
			tr.Speed,
			tr.IsPlaying and "playing" or "fading",
			tr.Looped and " loop" or ""))
	end
	return table.concat(lines, "\n")
end

local animator = game.Players.LocalPlayer.Character.Humanoid.Animator
task.spawn(function()
	while true do
		print(trackReport(animator))
		task.wait(0.25)
	end
end)
```

And log every `Play` without touching the call sites:

```lua
animator.AnimationPlayed:Connect(function(track: AnimationTrack)
	print(("[anim] %.3f PLAY %s prio=%s"):format(os.clock(), track.Animation.Name, track.Priority.Name))
	track.Stopped:Once(function()
		print(("[anim] %.3f STOP %s at t=%.2f"):format(os.clock(), track.Animation.Name, track.TimePosition))
	end)
end)
```

What the report tells you:
- **Track missing.** It was never played, or it already ended. Check the code path.
- **Many copies of one clip.** `LoadAnimation` per use (see the 256-track warning in [[Engine Gotchas]]).
- **[[TimePosition]] stuck at 0.** Something calls `Play` every frame (restart), or speed is 0 (hit-stop that never restored, or `Length` was 0 when speed was computed).
- **[[WeightCurrent]] stuck below 1.** A fade that was overridden, or `AdjustWeight` after `Stop`.
- **Plays, then "fading" immediately.** Another system stopped it. Search for `:Stop(` and for "stop all tracks" loops (the classic culprit is a helper that stops every playing track when changing the default Animate ids).

If you play clips through a Lua player, it should offer the same report. The reference project's player exposed `PlayingTracks(model)` and an `OnPlayed` hook for exactly this.

---

## Step 3: isolate priority and blending

If the right track plays at full weight and the joint still does not do what the clip says, something else owns the joint.

1. **Solo the track.** Stop every other track (`for _, t in animator:GetPlayingAnimationTracks() do if t ~= mine then t:Stop(0) end end`) and disable the `Animate` script for the test. If the pose is now right, it is a blend problem.
2. **Bisect the others.** Re-enable layers one at a time. The usual suspects: Animate's `toolnone` hold, a carry layer, an idle at a higher priority than you thought, an upper-body copy of the same clip.
3. **Check same-priority averaging.** Two tracks at the same priority with weights summing past 1 are normalised; neither shows fully.
4. **Check partial weights with nothing beneath.** A layer at weight 0.5 with nothing below blends toward the rest pose (measured), which looks like a half-T-pose.
5. **Check your procedural writers.** Temporarily disconnect every `PreSimulation` handler that writes `Transform`. If the problem vanishes, it is yours, not the Animator's.

---

## Step 4: isolate the rig

Play the same clip on a **known-good rig**: a fresh R15 dummy (Avatar tab, Rig Builder) or the rig the clip was authored on.

- **Right on the dummy, wrong on yours.** Rig problem. Compare joint names (`Part1.Name` of every Motor6D/AnimationConstraint/Bone) with the pose names in the dump. A renamed part, a missing joint, or a joint whose `Part0`/`Part1` are swapped all show as "that limb does not animate" or "that limb animates around the wrong pivot".
- **Wrong on both.** Clip problem; go back to Step 1.
- **Translation looks scaled.** Compare `Model:GetScale()` on both rigs and read [[Scale and Animation]].
- **Body turned 180 degrees from the root.** An import axis problem; see [[Enemy Import Axis Fix]].
- **Some joints never move in code you wrote.** Your code only handles `Motor6D`. Print the class of each joint.

A joint-listing helper:

```lua
local function listJoints(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local j = d :: any   -- both expose Part0/Part1 (read-only aliases on AnimationConstraint)
			print(("%-20s %-20s %s -> %s"):format(d.ClassName, d.Name,
				j.Part0 and j.Part0.Name or "nil", j.Part1 and j.Part1.Name or "nil"))
		elseif d:IsA("Bone") then
			print(("%-20s %-20s parent %s"):format("Bone", d.Name, d.Parent and d.Parent.Name or "nil"))
		end
	end
end
```

---

## Step 5: isolate replication

Run a **local server with two clients** (Test tab, Clients and Servers). Watch the same character from three views: the owner, the other client, and the server.

| Owner | Other client | Server | Diagnosis |
|---|---|---|---|
| ok | ok | ok | Not a replication bug |
| ok | missing | missing | Played on a client for an NPC, or a Lua-driven joint not mirrored, or an Animator created on the client |
| ok | missing | ok | Rare; usually the asset failed to load on that client (ownership, network). Check its output. |
| missing | ok | ok | The owner's own local code stops or overrides it (a LocalScript only on the owner) |
| ok | late or jumpy | ok | Expected network delay; check that markers driving FX run on each client, not relayed from the owner |

For Lua-played clips, also check the relay: is the start time sent, does a late joiner get the active tracks, do speed changes reach others? The reference project sent speed changes at once when they changed by 6% or more, otherwise at most every 0.25 s.

To feel network latency in Studio, use Studio's network simulation setting for incoming replication lag (in Studio Settings, Network) before a multi-client test.

---

## Step 6: isolate timing

Timing bugs show up as "one frame late", "jitter", "drifts over time" or "only at low frame rates".

1. **Frame order.** Writes in `PreRender` or `Heartbeat` lose to the next animation step. Procedural joint writes belong in `PreSimulation`. Camera work belongs in `PreRender`/`BindToRenderStep`. See [[Frame Order and RunService Timing]].
2. **Compounding.** If a procedural offset slowly winds up, you are multiplying onto `Transform` on frames where the Animator did not rewrite it (throttled, or no track keys that joint). Keep your own base.
3. **Wall clock versus track clock.** `task.wait(0.2)` after `Play` is not "0.2 s into the clip": the track may start late (loading), run at another speed, or be hit-stopped. Drive events from markers or from `track.TimePosition`.
4. **Frame-rate dependence.** Smoothing like `x += (target - x) * 0.2` per frame behaves differently at 30 and 240 fps. Use `1 - math.exp(-k * dt)`. Test with the frame-rate cap changed.
5. **Late joiners.** Anything that relies on having seen the `Play` event is wrong for a player who joined after it. State must be reconstructible from attributes and a start time.

---

## The power tools

### `Animator:StepAnimations` (Edit, command bar or plugin)
Docs: plugin-level security; it advances every playing track on the Animator and applies the pose. It is the closest thing to a debugger for the Animator:
- Freeze the world, load a clip, `Play(0)`, then step `1/60` at a time and read every joint's `Transform`. You get ground truth for exactly what the engine does.
- Measured requirements: `dt` must be greater than 0 to advance; a just-registered clip needs `Length > 0` first; reset joints yourself afterwards.

See [[Testing Animations in Studio]] for a full stepping harness.

### A/B against a Lua model
Write (or reuse) a Lua sampler that reproduces the Animator ([[Lua Keyframe Player Internals]], [[Snippets - Lua Keyframe Player Core]]). Then step the real Animator and the Lua model side by side and diff joint rotations per frame. This answers "is the Animator doing something weird, or is my data weird?" with numbers.

What the reference project got out of this:
- The discovery that rotations blend as rotation vectors, not [[slerp]], came from exactly this diff (a slerp model was up to 178 degrees off; a rotation-vector model 0.24 degrees).
- The Lua player was accepted only after matching within 0.084 degrees on 10 R15 clips, 0.056 degrees and 0.002 studs on 60 enemy clips, 0.04 degrees on a five-track blend, and 319 of 319 markers.
- A residual of three clips turned out to be exact 180-degree keys, where the Animator itself is ambiguous.

Keep an A/B switch in your Lua player permanently (the reference project's was a single config flag). Note that A/B needs real Poses: restore stubbed clips before testing them.

### Filmstrips
A filmstrip is a row of snapshots of the rig at fixed times (for example every 0.05 s through the clip), side by side or overlaid as ghosts. It turns a motion bug into a static picture you can study and attach to a report.

How to make one in Edit, where `Motor6D.Transform` does not move parts:
1. Sample the clip yourself at time t (Lua sampler) or step the Animator and read `Transform`s.
2. Compute every part's world CFrame by forward kinematics (`Part1 = Part0 * C0 * Transform * C1:Inverse()`).
3. Clone the rig's parts as anchored copies at those CFrames, offset sideways per frame, and capture.

The reference project posed the rig straight from the `KeyframeSequence` with the real held weapon attached, because ViewportFrames do not advance in Edit. The same filmstrips were attached to every QA report. See [[Snippets - Building and Sampling Clips]] for the FK code.

### Visual probes
- Parent a small neon sphere to an `Attachment` on the hand to see the grip path.
- Draw a `Beam` along the blade, or between shoulder and target, to see IK goals.
- `Highlight` a part that is being written by your procedural code.
- Print or draw `Animator.EvaluationThrottled` on remote characters to see engine LOD.

### MicroProfiler and Developer Console
- MicroProfiler (Ctrl+F6 in Play) shows the animation step and your `PreSimulation` handlers. A Lua player should show as a narrow, flat bar; spikes mean allocation or per-frame `GetDescendants`.
- The Developer Console Memory tab has an `Animation` category (`Enum.DeveloperMemoryTag.Animation`, Docs). Watch it while equipping and unequipping weapons to catch track leaks.

---

## Worked examples from the reference project

**"Abilities do nothing on the live server."** Asset suspect. Every clip came from `RegisterKeyframeSequence`. Step 0 alone pointed at it: works in Play solo, broken live. Fixed by a Lua clip player plus published-id override. See [[Case Study - Abilities That Only Worked in Studio]].

**"Enemies attack from behind."** Rig/asset suspect. Server logic used the root's LookVector correctly; the animation played the whole body turned 180 degrees from the root. Found by playing a clip on the rig and comparing the head direction with the root's LookVector. The importer had put a 180-degree correction on the top-level root pose, which is never applied. See [[Enemy Import Axis Fix]].

**"The stance ability is 5 seconds late the first time."** Asset/timing suspect. The `AnimationPlayed` log showed `Play` on time; the track's `Length` was 0 for seconds. Preloading fixed it.

**"The whole kit stopped doing damage."** Not an animation bug at all, but it looked like one: a clip named `Origin` shadowed a RemoteEvent of the same name. Found by printing `ClassName` of what the lookup returned.

**"Hit sparks fire twice."** Track suspect. Both a full-body clip and its upper-body copy were playing and both carried the `Hit` marker. The FX module now ignores upper-body duplicates.

**"The off-hand shoulder misses its key by 10 degrees overhead."** Not a bug in the clip: the offline preview tool slerped while the Animator blends rotation vectors. Found with an Animator A/B diff.

**"Arms flash to a T-pose mid-move."** Clip suspect. A solver had written identity keys for joints it did not solve. QA now flags "rest flash": both arm joints passing within 8 degrees of rest between poses at least 40 degrees away, within 0.2 s.

---

## Checklist
- [ ] Observation sentence written with rig, mode, viewer, clip, symptom, time.
- [ ] Track id printed; `Length > 0` confirmed.
- [ ] `GetPlayingAnimationTracks` report captured at the moment of the bug.
- [ ] Clip soloed (other tracks and Animate off).
- [ ] Clip tried on a known-good rig.
- [ ] Owner, other client and server compared.
- [ ] Procedural writers disconnected once to rule them out.
- [ ] Frame-rate cap changed once to rule out frame-rate dependence.
- [ ] Fix verified with the same observation sentence, in the mode where it failed (for live-only bugs, a live or Team test server, not Play solo).

## See also
[[Troubleshooting Table]] · [[Engine Gotchas]] · [[Testing Animations in Studio]] · [[How the Animator Really Behaves]] · [[Replication and Ownership]] · [[Frame Order and RunService Timing]] · [[Lua Keyframe Player]] · [[Animation Quality Standard]]

## Connected notes
<!-- auto-links:start -->
[[Animator Deep Dive]] · [[Performance and Memory]] · [[Animation Objects]] · [[Animation Glossary]] · [[The Debugging Method - Reproduce Isolate Bisect]] · AI Animation and Motion from Video · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Open Questions]] · [[Authoring Clips in Code]] · [[Weapon Rig Player]] · [[Animation Data from Blender to Roblox]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Procedural Animation]] · [[Motor6D Math and CFrame Composition]] · [[Playback, Priorities and Blending]]
<!-- related:end -->
