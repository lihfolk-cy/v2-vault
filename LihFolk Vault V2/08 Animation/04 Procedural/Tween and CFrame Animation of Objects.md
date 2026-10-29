---
tags: [procedural, tweenservice, cframe, props, bulkmoveto, pivots, performance, luau, type/guide, area/animation, level/intermediate, api/BulkMoveTo]
---
# Tween and CFrame Animation of Objects

<!-- tldr:start -->
> [!tldr] TL;DR
> - Model's parts fly apart during a tween: tweening `Position` on a welded root -> tween `CFrame`
> - Door stops halfway: a second tween on the same property cancelled the first -> one controller per property; check `Completed` state
> - Lid clips into the base on close: Back / Elastic overshoot not checked -> sample `GetValue` over the curve, check the range against geometry
>
> Cost: TL;DR ~130 tok · whole note ~4.9k tok. Read more: ## TweenService essentials · ## The Anim_ pattern: decorative animation as data · ## Common mistakes
<!-- tldr:end -->

Most moving things in a Roblox world are not characters: doors, chests, lids, spinning crystals, floating rocks, rotating rings, swaying foliage, gates and portals. They do not need rigs, Animators or clips. They need a pivot, a formula or a tween, and a sensible update budget. This note covers TweenService properly, moving whole models, a worked hinge example with the overshoot checked, a data-driven pattern for hundreds of decorative animations, and `BulkMoveTo` for mass movement.

## Choosing the tool

| Motion | Tool | Why |
|---|---|---|
| One-shot, fixed duration (a door opens, a chest pops) | TweenService | built-in easing, fire and forget |
| Endless and periodic (spin, bob, sway, pulse) | a formula of time in one update loop | no tween restarts, perfect loops, phase control |
| Hundreds of objects moving | formula + `workspace:BulkMoveTo` | one engine call instead of hundreds of property sets |
| Articulated prop with authored motion (a mechanical arm, a creature-like trap) | Motor6D rig + clip, or a Lua clip player | the motion is designed, not computed |
| Platforms players stand on | physics constraints, or velocity on the moving part | characters ride velocity, not teleporting CFrames |

## TweenService essentials

From the official reference:

- Tweenable property types: number, boolean, `CFrame`, `Rect`, `Color3`, `UDim`, `UDim2`, `Vector2`, `Vector2int16`, `Vector3` and `EnumItem`.
- A tween belongs to one instance: `TweenService:Create(instance, tweenInfo, goals)`.
- **Two tweens on the same property: the newer one cancels the older.** Useful (retargeting a door mid-swing just works) and dangerous (a "close" fired a frame after "open" silently kills the open).
- `TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)`.
- `TweenService:GetValue(alpha, easingStyle, easingDirection)` returns the eased value for `alpha` (clamped to 0..1). It errors for the `Bezier` and `Spring` styles. This is the key to driving many objects with TweenService's curves from your own loop, and to *checking* a curve's range before shipping it.

Remember that Roblox's *animation* easing (on keyframe poses) has measured quirks, including a legacy Cubic that plays reversed; TweenService easing follows its documented directions. See [[Keyframes, Easing and Interpolation]].

### Tweening a model

A `Model` has no tweenable pivot property. Three working approaches:

1. **Tween a proxy value.** Tween a `CFrameValue` (or a `NumberValue` angle) and call `model:PivotTo(...)` in its `Changed` handler. Simple; one event per change.
2. **Tween the anchored root part.** Weld the other parts to an anchored root with `WeldConstraint`s and tween the root's `CFrame`. The `WeldConstraint` docs state that setting a part's `CFrame` moves all connected parts with it (setting `Position` does not: the welded parts stay and the weld re-measures). Tweening `CFrame` is therefore safe; tweening `Position` breaks the model apart visually.
3. **Drive it yourself** with `TweenService:GetValue` in an update loop. Best when many objects share one loop.

### Server or client?

The TweenService reference does not discuss replication. In practice (rule of thumb): a tween run on the server changes properties on the server, which replicate to clients at network rate, so fast or long tweens look stepped and late on clients. For anything visual, tween on each client and synchronise the start with `workspace:GetServerTimeNow()` (send the start time, start each client's tween at `alpha = (now - start) / duration`). Keep server-side state for gameplay (is the door open?) separate from the visual tween.

## Worked example: a hinged lid

From the reference project (one live action game): a chest lid driven by one tweened angle.

```lua
--!strict
-- A lid hinged on an Attachment "Hinge" in the base. One NumberValue angle drives it.
local TweenService = game:GetService("TweenService")

local function makeLid(base: BasePart, lid: BasePart)
	local hinge = base:WaitForChild("Hinge") :: Attachment
	-- the lid's pose relative to the hinge, captured closed: Lid = Hinge * Rx(angle) * rest
	local rest = hinge.WorldCFrame:Inverse() * lid.CFrame
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(deg: number)
		lid.CFrame = hinge.WorldCFrame * CFrame.Angles(-math.rad(deg), 0, 0) * rest
	end)
	local function open()
		TweenService:Create(angle, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 72 }):Play()
	end
	local function close(onShut: (() -> ())?)
		local t = TweenService:Create(angle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0 })
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and onShut then onShut() end   -- thud sound + a small bounce
		end)
		t:Play()
	end
	return open, close
end
```

The project's numbers: open with `Back` / `Out` over 0.6 s to 72 degrees, close with `Quad` / `In` over about 0.4 s followed by a thud bounce. `Back` overshoots its goal and `In`-side styles can dip below the start, so the project **checked the full range** the angle could sweep (from -2 to 115.5 degrees across its curves) against the plinth geometry so the lid never passes through it. Do the same with `GetValue`:

```lua
-- The min and max an eased tween from a to b can reach.
local function easedRange(a: number, b: number, style: Enum.EasingStyle, dir: Enum.EasingDirection): (number, number)
	local lo, hi = math.huge, -math.huge
	for i = 0, 200 do
		local v = a + (b - a) * TweenService:GetValue(i / 200, style, dir)
		lo, hi = math.min(lo, v), math.max(hi, v)
	end
	return lo, hi
end
```

The `Completed` check matters: a tween that was cancelled (by a newer tween on the same property) fires `Completed` with a different state, and the thud must not play then.

## The Anim_ pattern: decorative animation as data

The reference project animated hundreds of decorative pieces (crystal shards, rune rings, gate frames, rotating gears, floating stones) with one client system and no per-object scripts. The convention:

- A sub-model named `Anim_<name>` groups the parts that move together.
- Its pivot is an `Attachment` named `AnimPivot` (or a small invisible anchored `PrimaryPart` with that name). Attachments let level designers move the pivot in Studio without touching code.
- Attributes on the group describe the motion: `Anim` (`spin`, `sway`, `bob`), `Axis`, `Speed`, `Amp`, `Phase`.
- Per-part attributes add non-transform effects: `Pulse` (a colour to pulse toward), `PulseSpeed`, `PulsePhase`; `Blink` (a period), `BlinkDuty`, `BlinkPhase`.
- **Groups nest**: a bob inside a sway inside a spin; a child group follows its parent's motion.
- **Range-gated**: animate only near the camera (the project used 900 studs for large gate frames and 280-650 studs for hub effects; a per-model range attribute overrides).

### The maths of nested pivots

For a group with rest pivot `P` (a world CFrame) and a motion `M(t)` (rotation or translation in the pivot's frame), its world delta is

```
D(t) = P * M(t) * P^-1
```

A part with rest CFrame `X` moves to `D(t) * X`. A nested group's delta is applied on top of its parent's:

```
Dtotal(child) = Dtotal(parent) * D(child)
```

This works because `D(parent)` also carries the child's rest pivot along with it. Evaluate parents before children and every level follows correctly.

**Gotcha recorded in the project:** when a whole station was moved by a rigid transform (rotated 144 degrees and shifted), the `AnimPivot` attachments moved with it, but an `Axis` attribute stored as a world-space vector did not, so spins ran about the old axis. Store axes in the pivot's local space, or rotate the attributes with the move (the project rotated `AnimPivot` and `AnimAxis` together and kept the old values in backup attributes).

### A runner with BulkMoveTo

```lua
--!strict
-- Client: animate every Anim_ group under `root` near the camera, in one loop, with one BulkMoveTo.
local RunService = game:GetService("RunService")

type Group = { model: Model, parent: Group?, P: CFrame, kind: string, axis: Vector3, speed: number,
	amp: number, phase: number, parts: { BasePart }, rest: { CFrame }, range: number,
	D: CFrame, moving: boolean }

local groups: { Group } = {}

local function isGroup(x: Instance?): boolean
	return x ~= nil and x:IsA("Model") and string.sub(x.Name, 1, 5) == "Anim_"
end
-- the nearest Anim_ group above x (x itself excluded)
local function ownerOf(x: Instance): Instance?
	local p = x.Parent
	while p and not isGroup(p) do p = p.Parent end
	return p
end

local function collect(m: Model, parent: Group?)
	local g: Group = {
		model = m, parent = parent, P = m:GetPivot(), kind = m:GetAttribute("Anim") or "spin",
		axis = ((m:GetAttribute("Axis") :: Vector3?) or Vector3.yAxis).Unit,   -- in the pivot's local space
		speed = m:GetAttribute("Speed") or 1, amp = m:GetAttribute("Amp") or 0.1,
		phase = m:GetAttribute("Phase") or 0, parts = {}, rest = {},
		range = m:GetAttribute("Range") or 600, D = CFrame.identity, moving = false,
	}
	local children = {}
	for _, d in m:GetDescendants() do
		if ownerOf(d) ~= m then continue end                 -- belongs to a nested group
		if d.Name == "AnimPivot" and d:IsA("Attachment") then
			g.P = d.WorldCFrame
		elseif d.Name == "AnimPivot" and d:IsA("BasePart") then
			g.P = d.CFrame
		elseif d:IsA("BasePart") then
			table.insert(g.parts, d); table.insert(g.rest, d.CFrame)
		elseif isGroup(d) then
			table.insert(children, d)
		end
	end
	table.insert(groups, g)                                   -- parents always before their children
	for _, c in children do collect(c :: Model, g) end
end

local function motion(g: Group, t: number): CFrame
	local x = g.speed * t + g.phase
	if g.kind == "spin" then return CFrame.fromAxisAngle(g.axis, x) end
	if g.kind == "sway" then return CFrame.fromAxisAngle(g.axis, g.amp * math.sin(x)) end
	return CFrame.new(g.axis * (g.amp * math.sin(x)))                     -- bob
end

local partList: { BasePart } = {}
local cfList: { CFrame } = {}
local acc = 0
RunService.PreRender:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then return end                                    -- 30 Hz is plenty for decor
	acc = 0
	local cam = workspace.CurrentCamera.CFrame.Position
	local t = workspace:GetServerTimeNow()                             -- same phase on every client
	table.clear(partList); table.clear(cfList)
	for _, g in groups do                                              -- parents before children
		local near = (g.P.Position - cam).Magnitude < g.range
		local own = if near then g.P * motion(g, t) * g.P:Inverse() else CFrame.identity
		local parentMoving = g.parent ~= nil and g.parent.moving
		g.D = (if g.parent then g.parent.D else CFrame.identity) * own
		g.moving = near or parentMoving
		if g.moving then
			for i, p in g.parts do
				table.insert(partList, p)
				table.insert(cfList, g.D * g.rest[i])
			end
		end
	end
	workspace:BulkMoveTo(partList, cfList, Enum.BulkMoveMode.FireCFrameChanged)
end)

for _, d in workspace:GetDescendants() do
	if isGroup(d) and ownerOf(d) == nil then                 -- top-level groups; nested ones come via collect
		collect(d :: Model, nil)
	end
end
```

Notes:

- `BulkMoveTo(partList, cframeList, eventMode)` moves parts by index; both arrays must be the same length. `FireCFrameChanged` fires only the `CFrame` changed event instead of `Position`, `Orientation` and `CFrame` (the default `FireAllEvents`). The docs say to reach for it only when part movement is a measured bottleneck, since setting `CFrame` is fast enough in most cases. Hundreds of parts at 30 Hz is the case it exists for.
- Parts should be **anchored**. Moving unanchored parts by CFrame fights the physics solver.
- `workspace:GetServerTimeNow()` as the clock makes every client show the same phase, which matters when players compare ("the ring is at the top for me").
- Out-of-range groups freeze where they are; for perfectly periodic motion nobody can tell.

## Mass movement elsewhere in the project

- **Foliage sway**: leaves near the camera updated at 30 Hz with `BulkMoveTo`, plus pooled falling leaves.
- **Arena floaters**: 78 floating rock meshes animated on `Heartbeat` with `BulkMoveTo`, started when the fight starts, stopped when it ends, gated by the graphics quality level.
- **Flocks**: unparented beyond 900 studs (a model outside the workspace costs no rendering).
- **Spinning weapon FX** (shard groups, halo rings) through weld `C0` instead of CFrame, because they ride on a moving character.

## Synchronised one-off animations

For a one-time animation every client must play together (a prize spin, a gate opening), replicate a *trigger*, not the motion. The project used an attribute whose value is `"<userId>:<index>:<serial>"`: every change of the serial starts the same 4.4 s quartic-eased spin on every client. Add a server timestamp (from `GetServerTimeNow`) if late joiners or slow clients must land on the same frame.

## Things players stand on

A part moved by setting its `CFrame` teleports: it has no velocity, so characters standing on it do not ride along and items on it are left behind. For platforms, elevators and moving floors use physics (an unanchored platform driven by `AlignPosition` / `AlignOrientation` or a `PrismaticConstraint`), or give the moving anchored part a matching `AssemblyLinearVelocity` (the docs note anchored parts can keep nonzero assembly velocities) so the character controller carries players. Test with a player standing on it at the fastest point of the motion.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Model's parts fly apart during a tween | tweening `Position` on a welded root | tween `CFrame` |
| Door stops halfway | a second tween on the same property cancelled the first | one controller per property; check `Completed` state |
| Lid clips into the base on close | Back / Elastic overshoot not checked | sample `GetValue` over the curve, check the range against geometry |
| Movement looks choppy for players | server-side tweens | tween on clients, synchronise start time |
| Spinning decor costs a millisecond | one script and one property set per object | one loop, `BulkMoveTo`, 30 Hz, range gate |
| Decor spins about the wrong axis after a level edit | world-space axis attributes not rotated with the move | store axes in the pivot's local space |
| Players slide off moving platforms | CFrame-driven platform | physics constraints or matching velocity |
| Nested part detaches from its parent ring | child evaluated before parent, or deltas not chained | parents first, `Dtotal = Dparent * Dchild` |

Related: [[UI and GUI Animation]], [[Procedural Animation]], [[Performance and Memory]], [[Animation LOD]], [[Flight Flocks and Path Animation]], [[Snippets - Procedural Motion]].

## Nuances and edge cases

1. **Client-side animation and server collision disagree.** A door tweened only on clients is open visually, but its collision on the server is wherever the server thinks it is. If the server never moves it, players are blocked by an invisible closed door (or, with a client-owned character, walk through on their screen and get corrected). Decide per object: purely cosmetic motion can be client only (set `CanCollide = false` or keep the collision in place); gameplay-relevant motion (doors, gates, traps) needs the server's collision state to change at the right moment, even if clients animate the visuals.
2. **Streaming and late joiners.** A client that streams in a door mid-animation has no tween history. Store state as data (open or closed, start time) so clients can compute where the door is now, as the synced trigger pattern does, instead of replaying the last tween.
3. **Scale of decorative motion.** 78 floaters is fine; a lobby with 2,000 spinning coins is not, even with `BulkMoveTo`, on a low-end phone. Gate by distance and by graphics quality, update at 30 Hz or lower for far objects, and stop entirely when not visible. A client with streaming can also simply not have the far objects.
4. **Physics-owned parts cannot be tweened sensibly.** Tweening the `CFrame` of an unanchored part fights the physics solver and its network owner. Either anchor it, or drive it with a constraint (`AlignPosition`, `AlignOrientation`, hinge servos) and let physics move it.
5. **Long-running server tweens and server load.** A server tween on a property replicates every change. Twenty slowly rotating server-side props add constant replication traffic for every client. Move them to the client with a shared start time, or make them static.
6. **Precision over long sessions.** A formula of time (`angle = t * speed`) with `os.clock()` is fine for hours. Accumulating (`angle += speed * dt`) drifts out of sync between clients and loses precision over very long sessions. Use `workspace:GetServerTimeNow()` and wrap angles modulo a full turn.
7. **Tweens and Parallel Luau.** Tween creation and property writes are serial operations. If a decorative system runs in an Actor for computation, it must still do its writes in a serial phase; `BulkMoveTo` from a serial handler after parallel computation is the usual shape.

## Common mistakes in production

1. **Client-only doors with server collision unchanged.** Symptom: invisible walls or rubber-banding at doorways. Fix: the server changes collision; clients animate visuals.
2. **Accumulated angles instead of time formulas.** Symptom: synced decor drifts apart between players over a long session. Fix: compute from server time.
3. **Tweening unanchored parts.** Symptom: jitter, parts drifting, ownership fights. Fix: anchor, or use constraints.
4. **Decorative loops with no visibility check.** Symptom: frame time cost from objects behind the camera or far away. Fix: distance and frustum gates, quality gates.
5. **Tween created per click without cancelling the old one.** Symptom: stacked `Completed` handlers fire in surprising order. Fix: keep one tween per object and property, cancel before creating a new one.

## Related decisions

- [[Interpolation Easing and Curves Math]]: the easing curves that `GetValue` and tweens use.
- [[Mover Constraints and Physics Controllers]]: moving gameplay objects through physics instead of CFrames.
- [[Network Ownership]]: why tweening unanchored parts fights the owner.
- [[Instance Streaming]]: computing current state for objects that stream in mid-motion.
- [[Level of Detail and Model Streaming]]: cutting far decorative motion.
- [[Parallel Luau and Actors]]: where tween writes must happen when computation is parallel.
- [[Tycoon Plots and Droppers End to End]]: a genre with many moving objects driven this way.
- [[Juice on a Budget - Mobile and Low-End]]: deciding which decorative motion survives on weak devices.

## Connected notes
<!-- auto-links:start -->
[[Links - Tweening and UI animation]] · [[Custom Rigs - Weapons and Props]] · Tween vs Spring · Easing · UI Motion Language and Timing · Links - Forces and movers · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Procedural Weapon Motion]] · [[Weapon Rig Player]] · [[Look-At Aim and Head Tracking]] · [[Springs Damping and Smoothing]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[Authoring Clips in Code]]
<!-- related:end -->
