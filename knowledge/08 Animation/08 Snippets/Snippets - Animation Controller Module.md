---
tags: [snippets, luau, controller, state-machine, architecture]
---
# Snippets: Animation Controller Module

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Several scripts calling `Play`/`Stop` on the same tracks.
> - Avoid: Choosing gaits without hysteresis.
> - Avoid: `AdjustSpeed` every frame on a replicated character (network noise).
>
> Cost: TL;DR ~90 tok · whole note ~6.5k tok. Read more: ## 2. The module · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

A complete, typed animation controller for a character or NPC: locomotion chosen by speed with hysteresis and phase-kept crossfades, playback rate matched to ground speed, idle fidgets that never repeat twice running, fall and land, one-shot actions with priority-based interruption, marker hooks, **step-aside flags** that let other systems take the body without fighting, and full cleanup.

It sits on top of `AnimPlay` from [[Snippets - Playing Animations]] (track cache, marker hooks, crossfades). Design background: [[Locomotion Systems]], [[Custom Locomotion Controller Design]], [[Combat Combo Systems]], [[Playback, Priorities and Blending]].

---

## 1. Why a controller

Without one, every system plays tracks directly: the weapon script plays swings, the ability script plays casts, the emote menu plays emotes, the default Animate plays locomotion. Each is correct alone. Together they produce the classic bugs:
- two systems' clips averaging at the same priority,
- an ability cancelled by a locomotion change,
- an equip flourish cut by a carry layer,
- a cutscene that half-plays because the walk cycle keeps fighting it,
- tracks never stopped when a character dies.

A controller gives each joint set **one owner at a time**, a written-down priority convention, and one place that cleans up.

### Priority convention (one that worked in production)
| Layer | Priority | Notes |
|---|---|---|
| Locomotion (idle, walk, jog, run, fall) | Movement | Over the default Animate, under everything else |
| Weapon carry (right arm only) | Action | An Action2 carry would cancel flourishes and read as an "attack" to other systems |
| Equip flourishes, weapon-part clips | Action2 | Weapon-part clips used a 0.06 s fade |
| Abilities and attacks | Action4 | 0.05 s fade-in |

### Step-aside flags
Some systems need the whole body for a while: a cinematic, an ability that physically moves the character (dash, travel moves), ragdoll, a seat. Rather than having them stop the controller's tracks (which the controller would restart next frame), they set an **attribute on the character**. The controller watches those attributes, fades its own tracks to weight 0 while any is set, refuses new actions, and fades back when all are clear. The reference project used flags like `KitControl` (an ability owns the body), `CutsceneLock` and `BladeUnheld`, and also stood aside while the root was anchored or the Humanoid was in the Physics or PlatformStanding states.

---

## 2. The module

```lua
--!strict
-- AnimController: locomotion + actions + stand-aside, one per rig.
-- Client: create for the local character (tracks replicate from the owner).
-- Server: create for NPCs (tracks must be played on the server to replicate, Docs).
local RunService = game:GetService("RunService")
local AnimPlay = require(script.Parent.AnimPlay)

export type ClipDef = {
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	fade: number?,            -- fade in/out seconds
	speed: number?,
	groundSpeed: number?,     -- locomotion clips: studs/s covered at speed 1
	upperId: string?,         -- optional upper-body copy (hips and legs unkeyed) for casting while moving
}

export type LocoConfig = {
	idle: string,
	walk: string?, jog: string?, run: string?,
	fall: string?, land: string?,
	fidgets: { string }?,
	walkAt: number?, jogAt: number?, runAt: number?,   -- speed thresholds, studs/s
	hysteresis: number?,                               -- studs/s band to avoid gait flicker
	rateMin: number?, rateMax: number?,                -- clamp on speed / groundSpeed
	fade: number?,
}

export type Config = {
	clips: { [string]: ClipDef },
	loco: LocoConfig,
	standAside: { string }?,  -- attribute names; any truthy value makes the controller stand aside
}

export type ActionOptions = {
	markers: { [string]: (string) -> () }?,
	duration: number?,        -- fit the clip to this many seconds
	interruptible: boolean?,  -- may a request of the same or lower priority replace this one?
	onDone: ((completed: boolean) -> ())?,
}

type ActionState = {
	name: string,
	track: AnimationTrack,
	rank: number,
	interruptible: boolean,
	cancel: (number?) -> (),
	onDone: ((boolean) -> ())?,
	done: boolean,
}

local AnimController = {}
AnimController.__index = AnimController

type Fields = {
	model: Model,
	animator: Animator,
	humanoid: Humanoid?,
	root: BasePart?,
	config: Config,
	locoName: string?,
	locoTrack: AnimationTrack?,
	action: ActionState?,
	aside: boolean,
	stillTime: number,
	nextFidget: number,
	lastFidget: string?,
	fidgetTrack: AnimationTrack?,
	airTime: number,
	lastRate: number,
	conns: { RBXScriptConnection },
	destroyed: boolean,
}
export type AnimController = typeof(setmetatable({} :: Fields, AnimController))

local GAITS = { "idle", "walk", "jog", "run" }

function AnimController.new(model: Model, config: Config): AnimController?
	local animator = AnimPlay.getAnimator(model, 10)
	if not animator then
		warn("[AnimController] no Animator under", model:GetFullName())
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local self = setmetatable({
		model = model,
		animator = animator,
		humanoid = humanoid,
		root = (humanoid and humanoid.RootPart) or model.PrimaryPart,
		config = config,
		locoName = nil,
		locoTrack = nil,
		action = nil,
		aside = false,
		stillTime = 0,
		nextFidget = 10,          -- first fidget after 10 s standing still
		lastFidget = nil,
		fidgetTrack = nil,
		airTime = 0,
		lastRate = 1,
		conns = {},
		destroyed = false,
	} :: Fields, AnimController)

	-- Preload everything in the background so first uses are not late.
	local ids = {}
	for _, def in config.clips do
		table.insert(ids, def.id)
		if def.upperId then table.insert(ids, def.upperId) end
	end
	task.spawn(AnimPlay.preload, animator, ids)

	-- PreAnimation runs right before the engine steps animations (Docs): the right place to choose
	-- tracks, weights and speeds for this frame.
	table.insert(self.conns, RunService.PreAnimation:Connect(function(dt: number)
		self:_step(dt)
	end))
	for _, attr in config.standAside or {} do
		table.insert(self.conns, model:GetAttributeChangedSignal(attr):Connect(function()
			self:_refreshAside()
		end))
	end
	table.insert(self.conns, model.Destroying:Connect(function()
		self:Destroy()
	end))
	self:_refreshAside()
	return self
end

-- ---------------------------------------------------------------- helpers
function AnimController._track(self: AnimController, name: string): (AnimationTrack, ClipDef)
	local def = self.config.clips[name]
	assert(def, "unknown clip " .. name)
	local tr = AnimPlay.track(self.animator, def.id)
	tr.Priority = def.priority
	tr.Looped = def.looped == true
	return tr, def
end

function AnimController._speed(self: AnimController): number
	local root = self.root
	if not root then return 0 end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

function AnimController._wantsAside(self: AnimController): boolean
	for _, attr in self.config.standAside or {} do
		if self.model:GetAttribute(attr) then return true end
	end
	local root = self.root
	if root and root.Anchored then return true end
	local h = self.humanoid
	if h then
		local s = h:GetState()
		if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.PlatformStanding
			or s == Enum.HumanoidStateType.Dead then
			return true
		end
	end
	return false
end

function AnimController._refreshAside(self: AnimController)
	local want = self:_wantsAside()
	if want == self.aside then return end
	self.aside = want
	local fade = self.config.loco.fade or 0.2
	if want then
		-- Fade our loops to 0 but keep them playing, so they resume in phase.
		-- (AdjustWeight works on playing tracks; after Stop it would need Play again, Docs.)
		if self.locoTrack then self.locoTrack:AdjustWeight(0, fade) end
		if self.fidgetTrack and self.fidgetTrack.IsPlaying then self.fidgetTrack:Stop(fade) end
		self:stopAction(fade)
	else
		if self.locoTrack then self.locoTrack:AdjustWeight(1, fade) end
	end
end

-- ---------------------------------------------------------------- locomotion
function AnimController._chooseGait(self: AnimController, speed: number): string
	local L = self.config.loco
	local h = L.hysteresis or 1.5
	local thresholds = { 0, L.walkAt or 1, L.jogAt or 16, L.runAt or 38 }
	local names: { string? } = { L.idle, L.walk, L.jog, L.run }
	local cur = 1                                       -- index of the current gait (idle if falling)
	for i = 1, #GAITS do
		if names[i] and names[i] == self.locoName then cur = i end
	end
	local best = 1
	for i = 2, 4 do
		if names[i] then
			-- moving UP into a faster gait needs threshold + h; staying in it needs only threshold - h
			local th = thresholds[i] + (i > cur and h or -h)
			if speed >= th then best = i end
		end
	end
	return names[best] :: string
end

function AnimController._setLoco(self: AnimController, name: string, speed: number)
	if name == self.locoName then return end
	local L = self.config.loco
	local fade = L.fade or 0.2
	local newTrack = self:_track(name)
	local old = self.locoTrack
	local function isGait(n: string?): boolean
		return n ~= nil and (n == L.walk or n == L.jog or n == L.run)
	end
	-- keep stride phase only between cycles that share foot timing (walk <-> jog <-> run)
	AnimPlay.crossfade(old, newTrack, fade, isGait(name) and isGait(self.locoName))
	self.locoName = name
	self.locoTrack = newTrack
	self.lastRate = 1
end

function AnimController._updateRate(self: AnimController, speed: number)
	local tr, name = self.locoTrack, self.locoName
	if not (tr and name) then return end
	local def = self.config.clips[name]
	local rate = 1
	if def.groundSpeed and def.groundSpeed > 0 then
		local L = self.config.loco
		rate = math.clamp(speed / def.groundSpeed, L.rateMin or 0.6, L.rateMax or 1.8)
	end
	-- Avoid AdjustSpeed every frame: owner-played tracks replicate, so only send real changes.
	if math.abs(rate - self.lastRate) / math.max(self.lastRate, 1e-3) > 0.03 then
		tr:AdjustSpeed(rate)
		self.lastRate = rate
	end
end

function AnimController._updateFidget(self: AnimController, dt: number, speed: number)
	local L = self.config.loco
	local fidgets = L.fidgets
	local idleTrack = self.locoTrack
	if not fidgets or #fidgets == 0 or self.locoName ~= L.idle or not idleTrack then return end
	if speed > 1 or self.action then
		self.stillTime = 0
		if self.fidgetTrack and self.fidgetTrack.IsPlaying then
			self.fidgetTrack:Stop(0.2)
			idleTrack:AdjustWeight(1, 0.2)
		end
		return
	end
	self.stillTime += dt
	if self.stillTime < self.nextFidget or (self.fidgetTrack and self.fidgetTrack.IsPlaying) then return end
	-- pick a fidget that is not the last one
	local pick = fidgets[math.random(1, #fidgets)]
	if #fidgets > 1 then
		while pick == self.lastFidget do pick = fidgets[math.random(1, #fidgets)] end
	end
	self.lastFidget = pick
	self.stillTime = 0
	self.nextFidget = 16 + math.random() * 10          -- then every 16 to 26 s
	local def = self.config.clips[pick]
	local track = AnimPlay.play(self.animator, def.id, {
		fade = 0.3, priority = def.priority, looped = false,
		onStopped = function() idleTrack:AdjustWeight(1, 0.3) end,
	})
	idleTrack:AdjustWeight(0, 0.3)                     -- same priority: hand the weight to the fidget
	self.fidgetTrack = track
end

-- ---------------------------------------------------------------- frame step
function AnimController._step(self: AnimController, dt: number)
	if self.destroyed then return end
	self:_refreshAside()                               -- catches anchoring and state changes too
	if self.aside then return end

	local speed = self:_speed()
	local L = self.config.loco
	local h = self.humanoid
	local airborne = h ~= nil and h.FloorMaterial == Enum.Material.Air

	if airborne then
		self.airTime += dt
		if L.fall and self.airTime > 0.15 then self:_setLoco(L.fall, speed) end
	else
		if self.airTime > 0.3 and L.land and not self.action then
			self:play(L.land, { interruptible = true })   -- land only after a real fall (0.3 s used)
		end
		self.airTime = 0
		self:_setLoco(self:_chooseGait(speed), speed)
		self:_updateRate(speed)
		self:_updateFidget(dt, speed)
	end
end

-- ---------------------------------------------------------------- actions
-- Returns true if the action started. A running action is replaced only if the new one has a higher
-- priority, or the running one was marked interruptible.
function AnimController.play(self: AnimController, name: string, opts: ActionOptions?): boolean
	if self.destroyed or self.aside then return false end
	local def = self.config.clips[name]
	assert(def, "unknown clip " .. name)
	local rank = AnimPlay.rank(def.priority)
	local cur = self.action
	if cur and not cur.done then
		if not cur.interruptible and rank <= cur.rank then return false end
		cur.done = true                                   -- before cancel: its onStopped must not report completion
		cur.cancel(def.fade or 0.08)
		if cur.onDone then cur.onDone(false) end
	end

	-- casting while moving: prefer the upper-body copy so the legs keep walking
	local id = def.id
	if def.upperId and self:_speed() > 1 then id = def.upperId end

	local state: ActionState? = nil      -- assigned right after play(); the callback only runs later
	local track, cancel = AnimPlay.play(self.animator, id, {
		fade = def.fade or 0.08,
		priority = def.priority,
		looped = def.looped == true,
		speed = def.speed,
		duration = opts and opts.duration,
		markers = opts and opts.markers,
		onStopped = function()
			local s = state
			if s == nil or s.done then return end
			s.done = true
			if self.action == s then self.action = nil end
			if s.onDone then s.onDone(true) end
		end,
	})
	local newState: ActionState = {
		name = name, track = track, rank = rank,
		interruptible = (opts and opts.interruptible) == true,
		cancel = cancel, onDone = opts and opts.onDone, done = false,
	}
	state = newState
	self.action = newState
	return true
end

function AnimController.stopAction(self: AnimController, fade: number?)
	local cur = self.action
	if not cur or cur.done then return end
	cur.done = true
	cur.cancel(fade or 0.1)
	self.action = nil
	if cur.onDone then cur.onDone(false) end
end

function AnimController.busy(self: AnimController): boolean
	return self.action ~= nil and not (self.action :: ActionState).done
end

-- ---------------------------------------------------------------- cleanup
function AnimController.Destroy(self: AnimController)
	if self.destroyed then return end
	self.destroyed = true
	for _, c in self.conns do c:Disconnect() end
	table.clear(self.conns)
	self:stopAction(0.1)
	if self.fidgetTrack and self.fidgetTrack.IsPlaying then self.fidgetTrack:Stop(0.1) end
	if self.locoTrack and self.locoTrack.IsPlaying then self.locoTrack:Stop(0.2) end
	self.locoTrack, self.fidgetTrack = nil, nil
end

return AnimController
```

---

## 3. Using it

```lua
-- LocalScript in StarterCharacterScripts (the local character: tracks replicate from the owner)
local AnimController = require(game.ReplicatedStorage.AnimController)
local char = script.Parent

local ctrl = AnimController.new(char, {
	clips = {
		Idle    = { id = "rbxassetid://0000000001", priority = Enum.AnimationPriority.Movement, looped = true },
		IdleLook  = { id = "rbxassetid://0000000002", priority = Enum.AnimationPriority.Movement },
		IdleShift = { id = "rbxassetid://0000000003", priority = Enum.AnimationPriority.Movement },
		Walk    = { id = "rbxassetid://0000000004", priority = Enum.AnimationPriority.Movement, looped = true, groundSpeed = 11 },
		Jog     = { id = "rbxassetid://0000000005", priority = Enum.AnimationPriority.Movement, looped = true, groundSpeed = 22 },
		Run     = { id = "rbxassetid://0000000006", priority = Enum.AnimationPriority.Movement, looped = true, groundSpeed = 64 },
		Fall    = { id = "rbxassetid://0000000007", priority = Enum.AnimationPriority.Movement, looped = true },
		Land    = { id = "rbxassetid://0000000008", priority = Enum.AnimationPriority.Action, fade = 0.05 },
		Slash1  = { id = "rbxassetid://0000000009", priority = Enum.AnimationPriority.Action4, fade = 0.05,
		            upperId = "rbxassetid://0000000010" },
	},
	loco = {
		idle = "Idle", walk = "Walk", jog = "Jog", run = "Run", fall = "Fall", land = "Land",
		fidgets = { "IdleLook", "IdleShift" },
		walkAt = 1, jogAt = 16, runAt = 38, hysteresis = 1.5,
		rateMin = 0.6, rateMax = 1.8, fade = 0.2,
	},
	standAside = { "KitControl", "CutsceneLock", "Ragdoll" },
}) :: any

-- attack input
local function onAttack()
	ctrl:play("Slash1", {
		duration = 0.42,
		markers = {
			Hit = function()
				-- client FX only; the server owns damage
			end,
		},
		onDone = function(completed)
			-- open the combo window, or reset it if cancelled
		end,
	})
end
```

The numbers above are from one production game: ground speeds 11 / 22 / 64 studs/s for walk / jog / run, gait switches at about 16 and 38 studs/s, rate clamped to stay believable, a 0.42 s first swing. With the default Animate script still present, set your locomotion at Movement so it wins over Animate's clips, or disable Animate and let this controller own locomotion entirely (cleaner). Climbing, swimming and sitting can be handed back to Animate by standing aside in those Humanoid states.

---

## 4. Design notes and nuance

**Choose tracks in `PreAnimation`.** The engine steps animations right after it (Docs). Changing weights, speeds and which track plays there means the change shows this frame. Joint writes from procedural code still belong in `PreSimulation`.

**Hysteresis is not optional.** A character accelerating through 16 studs/s with noise in its velocity would swap walk and jog every few frames without it. 1.5 studs/s each side was enough in practice.

**Keep stride phase across gait swaps.** Walk, jog and run loops authored with the same foot-contact phase (left contact at 0, right at 0.5) crossfade cleanly when the new loop starts at the old one's normalised time. Without it, feet scissor for the length of the fade.

**Rate from ground speed, clamped.** `rate = speed / groundSpeed` keeps feet planted. The clamp keeps a walk from looking like a sprint in slow motion or vice versa. When the clamp is hit, feet slide: that is the signal you need another gait, not a wider clamp. (A sprint capped at 1.5x of its clip slid visibly at 64 studs/s in the reference project.)

**Upper-body copies for casting while moving.** An action clip that keys the legs stops the walk. A copy with hips and legs unkeyed lets the legs continue. Beware duplicate markers when both copies can play.

**Interruption rules live in one place.** `play` refuses a same-or-lower priority request unless the running action is interruptible. Gameplay can mark combo windows as interruptible from a marker handler (set `ctrl.action.interruptible = true` in an `Interrupt` marker).

**Stand aside instead of fighting.** Systems that need the body set an attribute; nobody calls `Stop` on tracks they do not own. In the reference project the ability controller kept full body control while a kit had control (Physics state, anchored, PlatformStand, or a `KitControl` attribute), with travel moves taking the full body from frame 0 and releasing 0.25 s after the move.

**Cleanup.** `Destroy` disconnects everything, stops actions first (so their `onDone(false)` runs), and is called automatically on `Destroying`. Characters respawn as new models; create a new controller per character.

**What this module does not do.** Network relaying of Lua-played tracks (engine tracks played by the owner already replicate), foot IK ([[Snippets - IK]]), carry layers that only key the arm (play them as a separate looped action at Action priority with `interruptible = true`, or as a permanent layer managed beside the controller).

## Common mistakes
- Several scripts calling `Play`/`Stop` on the same tracks.
- Choosing gaits without hysteresis.
- `AdjustSpeed` every frame on a replicated character (network noise).
- Restarting loops on every state evaluation (Play restarts).
- Stopping another system's tracks to "make room" instead of standing aside.
- Forgetting the upper-body variant when the character moves while casting.

## See also
[[Snippets - Playing Animations]] · [[Locomotion Systems]] · [[Custom Locomotion Controller Design]] · [[Combat Combo Systems]] · [[Equip Draw and Flourish Systems]] · [[The Default Animate Script]] · [[Humanoid States and Animation]] · [[Snippets - Enemy Client Animator]]

## Nuances and edge cases

1. **Who runs the controller for NPCs.** For a player character the owning client runs it. For NPCs there are three options with very different costs: server-run (simple, replicates, but every `Play` and weight change crosses the network and the server pays CPU per NPC), client-run per viewer (cheap on the server, no replication traffic, but each client sees its own timing), or a hybrid where the server sends a compact state id and each client runs the controller locally. At 5 NPCs any of them works; at 100 or more, only the hybrid stays inside a mobile client's budget. See [[Snippets - Enemy Client Animator]].
2. **Hysteresis thresholds depend on WalkSpeed changes.** If a buff raises `WalkSpeed` from 16 to 24, gait thresholds tuned at 16 now put normal running in the jog band. Express thresholds as fractions of the current max speed, or recompute on the attribute change.
3. **Low-end phones and `PreAnimation`.** At 20 to 30 FPS, a crossfade of 0.15 s is three to five frames. That is still acceptable, but stride-phase matching matters more at low frame rates because the visible scissor frames are fewer and longer. Do not shorten fades for phones; keep phase matching.
4. **Moving platforms and conveyors.** Speed taken from `HumanoidRootPart.AssemblyLinearVelocity` includes the platform's velocity, so a character standing on a moving boat plays a run. Use `Humanoid.MoveDirection` times `WalkSpeed`, or subtract the floor's velocity from `Humanoid.FloorMaterial` detection plus a downward ray to find the floor part.
5. **Swimming, climbing and seats.** The default `Animate` handles these states. A custom controller that only knows ground gaits will play a walk while climbing a ladder. Either cover every `HumanoidStateType` you care about or step aside and let a small fallback play the default clips for the rest.
6. **Interruptible windows and latency.** A combo window opened by a marker on the client is accurate locally, but the server's own window (from data) is offset by ping. Accept a request on the server if it lands within the window plus a tolerance of about half the player's measured round trip, capped (rule of thumb, often 100 to 150 ms).
7. **Step-aside flags as attributes replicate.** Attributes on a character set by the server replicate to every client. That is useful for remote characters (every viewer's controller stands aside) but costs a little bandwidth per change; avoid toggling such flags many times per second.
8. **Version drift with the default Animate.** Roblox updates the default `Animate` script from time to time. If your controller coexists with it rather than replacing it, a platform update can change what clips play at what priority. Replacing `Animate` fully removes that risk at the cost of maintaining every state yourself.

The trade-off a senior developer weighs is breadth against ownership: a controller that owns every state is predictable but large; one that owns only combat and locomotion and stands aside for the rest is small but depends on the platform's defaults staying stable.

## Common mistakes in production

1. **Creating the controller in `StarterPlayerScripts` once.** Symptom: works until the first respawn, then nothing animates. Fix: one controller per character model, created on `CharacterAdded`.
2. **Gait from `AssemblyLinearVelocity` including vertical speed.** Symptom: run plays while falling. Fix: use horizontal speed only (`Vector3.new(v.X, 0, v.Z).Magnitude`).
3. **Idle fidget during combat.** Symptom: a stretch animation interrupts a combat stance. Fix: suppress fidgets while any action or in-combat flag is set, and for several seconds after.
4. **onDone callbacks that yield.** Symptom: the next action starts late or the controller deadlocks. Fix: callbacks must not yield; spawn long work with `task.spawn`.
5. **Two controllers on one rig after a hot reload in Studio.** Symptom: doubled weights, flicker. Fix: tag the rig with an attribute and refuse to create a second controller.

## Related decisions

- [[Behaviour Trees Utility AI and State Machines for NPCs]]: the decision layer that tells this controller what to play.
- [[Custom Character Controllers]]: when the movement itself is custom, gait selection reads from it instead of the Humanoid.
- [[Combat Systems Architecture]]: who owns action priority and interruption across the whole combat stack.
- [[Instances Attributes and Tags]]: how step-aside flags replicate and what they cost.
- [[Events Signals and Connections]]: the cleanup rules that keep `Destroy` complete.
- [[Debugging Race Conditions and Yield Order]]: tracing respawn and callback ordering bugs in the controller.
- [[Entity Component Systems]]: an alternative structure when hundreds of NPCs share one controller loop.
- [[Interest Management and Per-Player Replication]]: deciding which NPCs a client animates at all.

## Connected notes
<!-- auto-links:start -->
[[Procedural Gait and Footstep Planning]] · [[Engine Gotchas]] · [[Scale and Animation]] · [[Weapon and Combat Animation]] · [[Links - Humanoids and character controllers]] · [[Characters and Humanoids]] · [[Animation Start Here]]
<!-- auto-links:end -->
