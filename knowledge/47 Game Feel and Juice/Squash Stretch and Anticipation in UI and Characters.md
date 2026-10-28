---
tags: [game-feel, juice, squash-stretch, anticipation, ui, animation, springs, luau]
---
# Squash Stretch and Anticipation in UI and Characters

[[Principles of Animation for Games]] explains squash, stretch and anticipation as animation principles, and notes that rigid R15 parts cannot squash. [[UI Motion Language and Timing]] gives UI motion verbs and durations, including a press squash. This note is the engineering layer between them: how to get real non-uniform squash on Roblox UI and props when `UIScale` is uniform and CFrames carry no scale, how to keep volume so squash looks elastic rather than broken, how to stretch along velocity, and how to use anticipation to **hide latency** instead of adding it. It ends with the cases where both principles make a game feel worse.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Why squash reads as life

Squash and stretch tell the eye two things: the object has **mass** (it deforms under force) and it is **elastic** (it recovers). Remove the recovery and it looks broken; remove the volume preservation and it looks like it is inflating. Three rules decide whether it reads:

1. **Preserve volume (or area in 2D).** If an object squashes to 80% height, it must widen. In 2D, width x height stays constant: width = 1 / 0.8 = 1.25. In 3D with uniform horizontal axes, each horizontal axis scales by `1 / sqrt(0.8)`, about 1.118.
2. **Deform along the force.** Landing squashes along gravity; flying stretches along the velocity; a press squashes along the press direction (into the screen, which on a flat button means "smaller and wider" or simply "smaller").
3. **Recover with overshoot.** A spring with a damping ratio around 0.4 to 0.6 gives one visible overshoot and a small second one; critically damped (1.0) looks like a soft cushion; below 0.3 wobbles like jelly ([[Springs Damping and Smoothing]]).

Amount by context (rule of thumb):

| Context | Squash depth | Recovery |
|---|---|---|
| Professional or minimal UI | 3 to 5% (or none, colour only) | Tween, 0.15 s |
| Cartoon simulator UI | 8 to 15% | Spring, damping 0.5, about 0.3 s to settle |
| Collectible props (coins, gems, chests) | 15 to 30% | Spring, damping 0.4 |
| Slimes, blobs, mascots | 30 to 50% | Spring, damping 0.3 |
| Player characters | Pose only (see section 5) | Animation |

Above about 50% the object stops reading as itself. Keep big squash for short moments: under 0.1 s at the extreme.

---

## 2. Non-uniform squash on UI

`UIScale` scales a whole subtree uniformly: perfect for pops, useless for squash. You have three ways to deform one axis, each with a cost:

| Technique | How | Cost and side effects |
|---|---|---|
| Tween `Size` of an inner frame | Outer frame holds the layout slot; an inner frame with `AnchorPoint` at the pivot changes `Size` scale on X and Y | Re-lays out the inner subtree each frame; `TextScaled` text re-wraps and jitters |
| Separate art and text layers | The squash applies only to the art layer (background image, icon); text sits above in a sibling that only pops uniformly with `UIScale` | Slightly more instances; text stays crisp and readable |
| Sprite frames | Bake squash poses into an image strip and step `ImageRectOffset` | No layout cost; fixed number of poses; more texture memory |

The second technique is the one that holds up. Squashing text looks cheap (the glyphs distort and re-wrap), and players read button labels while pressing them. Squash the **body** of a button, keep the **label** steady (or pop it uniformly by a smaller amount).

The pivot matters as much as the amount:

- **Press**: pivot at the centre (`AnchorPoint` 0.5, 0.5). The button compresses into itself.
- **Land** (an item dropping into a slot, a card arriving on a table): pivot at the bottom (`AnchorPoint` 0.5, 1). It squashes onto the floor rather than shrinking toward the middle, which reads as weight.
- **Bounce from a side** (a panel hitting the edge of the screen): pivot on the touching edge.

Never change the outer frame's size. If the element sits in a `UIListLayout` or `UIGridLayout`, the layout owns the outer frame's position and the siblings would jitter as the slot changes size. The inner frame is free.

---

## 3. A volume-preserving squash spring

One spring per element, stepped by a single shared loop that runs only while something is moving (the same "one on-demand frame loop" rule the reference project used for its button motion, described in [[Game Feel and Juice]]).

```lua
--!strict
-- Squash: volume-preserving squash and stretch for UI art layers, driven by one shared spring loop.
local RunService = game:GetService("RunService")

local Squash = {}

type State = {
	art: GuiObject,        -- the inner art frame (not the layout slot)
	baseX: number,         -- base Size scale on X (usually 1)
	baseY: number,         -- base Size scale on Y (usually 1)
	value: number,         -- current stretch factor along Y: 1 = rest, 0.85 = squashed
	velocity: number,
	stiffness: number,     -- angular frequency squared
	damping: number,       -- 2 * zeta * omega
}

local active: { [GuiObject]: State } = {}
local connection: RBXScriptConnection? = nil

local function apply(s: State)
	local sy = s.value
	-- 2D area preservation: width scales by the inverse of height.
	local sx = 1 / math.max(sy, 0.2)
	s.art.Size = UDim2.fromScale(s.baseX * sx, s.baseY * sy)
end

local function step(dt: number)
	-- Sub-step large frames so a 30 fps hitch does not explode the spring.
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for art, s in active do
		if art.Parent == nil then
			active[art] = nil
			continue
		end
		for _ = 1, steps do
			local accel = -s.stiffness * (s.value - 1) - s.damping * s.velocity
			s.velocity += accel * h
			s.value += s.velocity * h
		end
		apply(s)
		if math.abs(s.value - 1) < 0.001 and math.abs(s.velocity) < 0.01 then
			s.value = 1
			s.velocity = 0
			apply(s)
			active[art] = nil
		end
	end
	if next(active) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- frequency in Hz (about 3 to 5 for UI), zeta 0.3 jelly .. 1.0 cushion.
function Squash.kick(art: GuiObject, amount: number, frequency: number?, zeta: number?)
	local omega = 2 * math.pi * (frequency or 4)
	local z = zeta or 0.5
	local s = active[art]
	if not s then
		s = {
			art = art,
			baseX = 1,
			baseY = 1,
			value = 1,
			velocity = 0,
			stiffness = omega * omega,
			damping = 2 * z * omega,
		}
		active[art] = s
	end
	assert(s)
	-- Set the deformation directly: a squash that tweens in looks soft. Negative amount squashes.
	s.value = math.clamp(1 + amount, 0.5, 1.6)
	s.velocity = 0
	apply(s)
	if not connection then
		connection = RunService.PreRender:Connect(step)
	end
end

return Squash
```

Usage: on press, `Squash.kick(button.Art, -0.12)`; for a cartoon reward card landing, `Squash.kick(card.Art, -0.25, 3.5, 0.4)` with the art frame's `AnchorPoint` at `(0.5, 1)` and `Position` at `(0.5, 1)`. Under reduced motion, skip the kick and use the colour or brightness feedback from [[UI Motion Language and Timing]].

Two details worth noticing:

- **The deformation is set instantly, then springs back.** The impact frame is the extreme pose. Tweening into the squash adds 50 to 100 ms of mush to the moment that should be sharpest.
- **Sub-stepping.** Springs integrated with one Euler step per frame go unstable at low frame rates with stiff settings. At 4 Hz and 30 fps a single step is fine, but designers will push frequency up to 8 Hz for snappy buttons; sub-stepping to 120 Hz keeps it stable everywhere.

---

## 4. Stretch along velocity

Things that fly (coins to a counter, a card thrown into an inventory, a projectile icon) look faster and smoother when stretched along their motion. This is the 2D equivalent of motion blur, and it is far cheaper.

The rule (rule of thumb): stretch factor `1 + k x speed`, clamped, where speed is in screen heights per second, `k` about 0.08 to 0.15, and the cap about 1.4. Rotate the element to face its velocity, apply the stretch on its local X axis, and squeeze Y by the inverse. As it decelerates into the target the stretch relaxes on its own, and the arrival triggers a squash with the pivot facing the impact.

Pitfalls:

- `Rotation` on a `GuiObject` rotates the subtree but `ClipsDescendants` does not rotate with it (Roblox docs, as of October 2026). Do not use rotated, stretched elements inside clipped containers.
- Text inside a rotated element rotates too. For "+250" labels flying to a counter, rotate only the icon and keep the text upright beside it, or do not stretch the label at all.
- Compute velocity from position deltas in `AbsolutePosition`, not from `UDim2` values, or a parent's resize will look like motion.

---

## 5. Characters and props in 3D

### Rigid characters

R15 characters are rigid parts. A CFrame contains position and rotation only, never scale, so `Motor6D.Transform` and `Bone.Transform` cannot squash anything (Roblox docs, as of October 2026). What you can do:

| Tool | Works for | Notes |
|---|---|---|
| Pose (bent knees, curled spine, lowered root) | Every rig | The standard approach; covered in [[Principles of Animation for Games]] |
| Bone offsets on a skinned mesh | Custom skinned characters | Move bones toward each other to fake squash; pull the side bones out to fake bulge |
| `Model:ScaleTo` | Uniform scale of a whole model | Uniform only; changes physics and joints; do not call per frame on a live character |
| `MeshPart.Size` | Non-uniform scale of a single mesh | Real squash for single-mesh props; changes collision size too |

### Props: real squash for cheap

For anchored, non-colliding props, changing `MeshPart.Size` deforms the mesh non-uniformly, so true volume-preserving squash is easy. A coin that lands, a chest that opens, a slime that hops:

```lua
--!strict
-- PropSquash: 3D volume-preserving squash for anchored single-mesh props.
-- Height factor sy; horizontal axes scale by 1/sqrt(sy) so volume stays constant.
local RunService = game:GetService("RunService")

local function propSquash(part: MeshPart, depth: number, frequency: number, zeta: number)
	local base = part.Size
	local baseCFrame = part.CFrame
	local omega = 2 * math.pi * frequency
	local value = 1 - depth -- start squashed (depth 0.25 -> 75% height)
	local velocity = 0
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function(dt: number)
		if part.Parent == nil then
			conn:Disconnect()
			return
		end
		local accel = -omega * omega * (value - 1) - 2 * zeta * omega * velocity
		velocity += accel * dt
		value += velocity * dt
		local sy = math.max(value, 0.3)
		local sxz = 1 / math.sqrt(sy)
		part.Size = Vector3.new(base.X * sxz, base.Y * sy, base.Z * sxz)
		-- Keep the bottom on the ground: lower the centre by half the height lost.
		part.CFrame = baseCFrame * CFrame.new(0, (base.Y * sy - base.Y) / 2, 0)
		if math.abs(value - 1) < 0.002 and math.abs(velocity) < 0.02 then
			part.Size = base
			part.CFrame = baseCFrame
			conn:Disconnect()
		end
	end)
end

return propSquash
```

This sketch connects one loop per squash for clarity; for dozens of props at once, merge them into a shared loop as in the UI module, and skip props farther than about 60 studs from the camera (rule of thumb), where nobody can see a 25% squash.

Caveats:

- Run it on the **client**. Resizing on the server replicates every frame to every player, which is a waste of bandwidth for pure presentation ([[Network Performance]]).
- `MeshPart.Size` changes collision geometry. For props that players stand on, squash a separate visual mesh welded to an invisible collider instead.
- `SurfaceAppearance` and textures stretch with the mesh. Fine for 20% squash; noticeable at 40% on detailed textures.
- Parts using `SpecialMesh.Scale` (older style) can be squashed through `Scale` instead of `Size` with no collision change, which is a neat trick for legacy props.

---

## 6. Anticipation that hides latency

Anticipation means a preparatory motion before an action. For the player's own actions it is usually framed as a cost: the [[Principles of Animation for Games]] note gives 2 to 6 frames at 30 fps for light attacks (from the reference project's standard) because every frame of wind-up is input delay. The flip side, often missed: **when the action must wait for the server anyway, anticipation is free**, and it turns dead waiting time into suspense.

### The latency mask pattern

A roll, an egg hatch, a purchase confirmation, a chest open: the client sends a request and the result arrives one round trip later (often 80 to 250 ms, more on bad connections). Showing nothing until the reply looks unresponsive; showing a result before the reply is impossible without lying.

The pattern:

1. On press, play the **anticipation** immediately (the egg wobbles, the dice shake, the chest lid rattles). Instant visual response, no wait.
2. The anticipation has a **minimum length** that covers the typical round trip, for example 0.35 s.
3. If the reply arrives before the minimum, the anticipation finishes its minimum, then reveals.
4. If the reply is late, the anticipation enters a **loopable hold** (a continued wobble that builds slightly) until the reply arrives, up to a timeout, after which an error state appears.
5. The **reveal** starts on whichever comes last: minimum elapsed or reply received.

```lua
--!strict
-- LatencyMask: anticipation that starts at once and reveals when both the minimum time and the reply are ready.
local LatencyMask = {}

export type Hooks = {
	startAnticipation: () -> (),
	holdLoop: () -> (),        -- called once if the reply is late; should loop until stopped
	reveal: (result: any) -> (),
	fail: () -> (),
}

-- request runs the remote call (it yields); returns ok and the result.
function LatencyMask.run(minSeconds: number, timeout: number, request: () -> (boolean, any), hooks: Hooks)
	local started = os.clock()
	hooks.startAnticipation()

	local done = false
	local ok = false
	local result: any = nil
	task.spawn(function()
		ok, result = request()
		done = true
	end)

	-- Wait out the minimum first: a fast reply still gets its anticipation.
	task.wait(minSeconds)
	if not done then
		hooks.holdLoop()
		while not done and os.clock() - started < timeout do
			task.wait()
		end
	end

	if done and ok then
		hooks.reveal(result)
	else
		hooks.fail()
	end
end

return LatencyMask
```

The `request` function should wrap its remote call in `pcall` and return `false` on error, so a thrown error does not leave `done` unset; if the remote can hang forever (a `RemoteFunction` to a server that never answers), the timeout path takes over.

The minimum must be honest: never stretch it to fake suspense on purchases the player is waiting to use. Rule of thumb: 0.3 to 0.6 s for cheap repeated actions, up to 1.5 s for rare high-value reveals (and see [[Reward Moments and Celebrations]] for how long the reveal itself should take).

### Anticipation in the effect, not the body

For player attacks, where wind-up is pure cost, a useful trick is to let **effects** anticipate while the body does not wait: the weapon glints, a trail starts, a sound rises on the input frame, while the body begins its strike at once. The eye gets the "preparing" read from the glint, and the hit lands as fast as a no-anticipation attack. The first frame of the attack should already move in the attack's direction, even slightly: the [[Input Responsiveness Buffering and Coyote Time]] note explains why a visible response within one or two frames matters more than the total attack length.

### Anticipation for enemies is a contract

Enemy wind-ups are the player's dodge window. [[Combat Sound Design and Feedback]] budgets 0.5 to 0.8 s of lead for a normal attack, and the reference project kept boss warnings at 0.5 s or more (measured in the reference project). The squash principle helps here too: a wind-up that **compresses** (crouch, pull back) and then **stretches** into the strike is readable at a glance, even at a distance where limb motion is a few pixels. A 10 to 15% vertical crouch of the whole silhouette is visible on a phone at 60 studs; a hand drawing back 1 stud is not.

---

## 7. When squash and anticipation hurt

- **Navigation UI.** Anticipation before a panel opens is pure delay. Menus open on press.
- **Locomotion start.** Players hate a wind-up before walking. Lean into motion in the first frame instead.
- **Competitive inputs.** In PvP, a client-visible wind-up the opponent can react to changes balance. Effects that only the attacker sees can anticipate; the body cannot.
- **High-frequency repeats.** A squash on every auto-click at 10 Hz is a vibrating mess. Rate-limit kicks per element (one per 80 ms is a good floor) and let repeated kicks add a little to the current value instead of restarting.
- **Readability of numbers.** Never squash elements that carry numbers the player is reading at that moment (a health bar, a price).
- **Reduced motion.** Squash and stretch is exactly the "motion that carries no information" that reduced-motion players want removed. Swap to colour or brightness changes; keep the anticipation timing (it carries latency masking) but play it as a pulse rather than a wobble.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Button squash looks like inflation | Height scaled without widening | Area-preserving: width = 1 / height |
| Labels jitter during presses | Text inside the squashed frame re-wraps | Separate art and text layers |
| Squash feels soft | Tweening into the deformation | Set the extreme instantly, spring back |
| Siblings twitch in lists | Layout slot resized | Squash an inner frame, never the slot |
| Springs explode on phones | One Euler step per frame with stiff settings | Sub-step at 120 Hz |
| Coin sinks into the floor while squashed | Pivot at the centre | Lower the CFrame by half the height lost |
| Roll button feels slow | Nothing happens until the server replies | Latency mask: anticipation on press, reveal on reply |
| Attacks feel heavy and laggy | Body wind-up on light attacks | Anticipate in effects; body moves on frame one |

## Checklist

- [ ] Squash preserves area (UI) or volume (props); recovery has an overshoot.
- [ ] Text is never squashed; art and labels are separate layers.
- [ ] Pivot chosen by force direction (centre for presses, bottom for landings).
- [ ] One shared, on-demand loop; springs sub-stepped.
- [ ] Prop squash runs on the client, culled by distance, with colliders separate where players stand.
- [ ] Server-bound actions use a latency mask with a minimum, a hold loop and a timeout.
- [ ] Player attacks anticipate in effects, not in body delay.
- [ ] Enemy wind-ups compress the silhouette visibly at gameplay distance.
- [ ] Reduced motion swaps squash for colour and keeps timing.

## Connected notes
<!-- auto-links:start -->
[[Anticipation]] · [[Tween vs Spring]] · [[Game Feel Start Here]] · [[UI and GUI Animation]] · [[Snippets - Procedural Motion]] · [[Ropes Chains and Soft Bodies]]
<!-- auto-links:end -->
