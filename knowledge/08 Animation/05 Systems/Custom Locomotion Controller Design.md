---
tags: [systems, locomotion, architecture, state-machine, code]
---
# Custom Locomotion Controller Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Legs reset to frame 0 after every ability: Controller stopped locomotion for an overrider instead of keeping...
> - Gait flickers on slopes: Raw speed, no smoothing or hysteresis
> - Brief T-pose on seat: `decide` returns Idle for `Seated` instead of handing back
> - `decide` is pure and unit tested with a speed/state table.
> - Gait data lives with the clips; load-time validation of bands vs clamps.
> - Speed smoothed, hysteresis on downshift.
>
> Cost: TL;DR ~150 tok · whole note ~4.7k tok. Read more: ## Arbitration: who owns the body · ## A working controller · ## Failure modes and how they look · ## Checklist
<!-- tldr:end -->

This note is the design document for a client-side locomotion controller: the module that decides, every frame, which idle, gait or air clip the local character plays, at what rate, with what layers, and when it must get out of the way. The numbers and behaviours it encodes are explained in [[Locomotion Systems]]; this note is about structure, state, arbitration and networking. Code is typed Luau using `Animator:LoadAnimation`, `task.*` and attributes.

## Goals and non-goals

Goals:
- One controller per local character, created on `CharacterAdded`, destroyed with the character.
- Data-driven gaits (ground speed, speed band, rate clamp, fade) so tuning never touches code.
- No foot slide inside each gait's band; stride phase kept across gait swaps.
- Clear arbitration with every other system that wants the body (attacks, abilities, flourishes, guard, dash, cutscenes).
- Hands climbing, swimming, seats and ragdoll back to the default `Animate`.

Non-goals:
- Driving other players' characters. Tracks played on the local character's `Animator` replicate to other clients by themselves (see [[Replication and Ownership]]), so each client only animates its own character. If you play clips through a Lua keyframe player instead, you need a relay (see "Networking" below).
- Root motion. The Humanoid moves the root; locomotion clips are in place.

## Architecture

```
            +--------------------+
inputs ---> |  sense()           |  velocity, FloorMaterial, Humanoid state,
            |                    |  attributes (who owns the body), tool
            +---------+----------+
                      |
            +---------v----------+
            |  decide()          |  pure function: state -> {base, rate, carry, air}
            +---------+----------+
                      |
            +---------v----------+
            |  apply()           |  play / stop / AdjustSpeed with fades,
            |                    |  phase-preserving swaps, carry and overlays
            +--------------------+
```

Keeping `decide` pure (no side effects, no instance writes) is the single best structural choice. It lets you unit-test the chooser with a table of speeds and states (see [[Testing Animations in Studio]]), and it makes "why is the character playing X" answerable by logging one table per frame.

### Layer stack

| Layer | Priority | Keys | Owner |
|---|---|---|---|
| Default Animate (climb, swim, sit, tool-hold) | Core / Idle | full body | Roblox |
| Base locomotion (idle, gaits, air) | Movement | full body | this controller |
| Carry (weapon class arm pose) | Action | right arm only | this controller |
| Idle fidget one-shot | Action2 in one project; Action is safer | upper body | this controller |
| Swings, guard | Action / Action2 | upper or full | combat controller |
| Equip flourish | Action2 | upper body (+ optional Legs layer) | flourish controller |
| Abilities | Action4 | full or upper copy | ability controller |

The point of putting locomotion at Movement (not Core) is that it must beat `Animate`, and the point of keeping it below Action is that every gameplay clip must beat it. See [[Playback, Priorities and Blending]] for how the Animator splits weight across priorities.

## The state machine

Locomotion has few states but subtle transitions. Model it explicitly:

```
              speed >= 1                 speed crosses band edge
   IDLE  ------------------>  GAIT(walk|jog|run)  <------------------> GAIT(other)
    ^  \                         |    ^                 (phase kept)
    |   \ still 10 s,            |    |
    |    v then 16-26 s          | FloorMaterial == Air
  VARIANT (look|shift|fidget)    v    |
                               AIR (jump for <= 0.42 s after Jumping and vy > -4, else fall)
                                 |
                                 | lands: airFor > 0.3 and speed < 6
                                 v
                               LAND (0.5 s window)  ----> IDLE or GAIT

   any state ---- Humanoid in Climbing/Swimming/Seated/Ragdoll/FallingDown/PlatformStanding ----> HANDBACK (play nothing)
   any state ---- dead / dashing / downed / a "replaces locomotion" owner -------------------------> HANDBACK
```

### Hysteresis

With a hard threshold (`speed < 16` is walk), a player whose speed hovers at 15.9 to 16.1 (slopes, analog sticks, physics jitter) flips gait every few frames. Phase-preserving swaps hide most of that, but the 0.15 s cross-fades stack and the body looks muddy. Two cheap fixes:

1. **Smooth the measured speed** with an exponential filter: `smooth += (speed - smooth) * min(1, dt * 10)`. One enemy client in the reference project used exactly this before computing playback rate. Time constant about 0.1 s.
2. **Hysteresis bands**: switch up at 16, down at 15. One stud/s is invisible but kills flicker.

The reference player controller used raw thresholds; this is a rule-of-thumb improvement, not a measured one.

## Arbitration: who owns the body

Many systems want the character. The reference project settled on **character attributes as ownership flags**, each set by the system that owns the moment and read by every other system before it plays anything:

| Attribute | Set by | Meaning for locomotion |
|---|---|---|
| `KitControl` | ability controller | an ability has full-body control |
| `FlourishLocal` | equip flourish controller | upper body is taken; carry off |
| `GuardingLocal` | guard controller | carry off, speed halved |
| `Dashing` | dash client | play nothing; the dash owns the legs |
| `CutsceneLock` | cutscene / ult cinema | play nothing new, input locked |
| `PremiumMotionLocal` | a per-weapon motion system | it owns idle/walk/run |
| `BladeUnheld` | weapon hold code | treat as unarmed |
| `CinematicWeather` | weather | other systems step aside |

Why attributes instead of a shared Lua module with a lock table:
- Attributes are visible in the Properties panel during a play test, which makes "who is holding the body" a glance instead of a debugger session.
- They survive script reloads and do not need every controller to require the same module.
- `GetAttributeChangedSignal` lets a controller react on the frame the owner changes.

The cost is that nothing enforces them. A new system that forgets to check `CutsceneLock` will happily play a swing in the middle of an ultimate cutscene. Keep the list in one place (a constants module) and grep for it in review.

### "Stop" versus "keep running underneath"

Not every owner should stop locomotion. There are two kinds:

- **Replacers** (dash, premium per-weapon motion, ragdoll): they animate the legs themselves. Locomotion must stop, or its Movement-priority tracks keep weight where the replacer leaves gaps.
- **Overriders** (abilities at Action4, a full-body swing): they play above locomotion and cover it completely while at full weight. **Keep locomotion running underneath.** When the override fades out, the gait is already playing in the right phase at the right rate, so the fade lands on live walking instead of on rest pose or on a gait restarting from frame 0.

Getting this wrong is a classic pop: an ability ends, the controller sees "I was told to stop", restarts the jog at time 0 with a 0.2 s fade, and the legs visibly reset.

## Data layout

Keep gait data next to the clips (attributes on the KeyframeSequence or Animation) with a code fallback:

```lua
export type GaitDef = {
	key: string,          -- clip name in the loco folder
	groundSpeed: number,  -- studs/s the planted foot moves back at 1x
	enter: number,        -- choose this gait when smoothed speed >= enter
	minRate: number,
	maxRate: number,
}

local GAITS: { GaitDef } = {
	{ key = "Walk", groundSpeed = 11, enter = 1, minRate = 0.4, maxRate = 1.7 },
	{ key = "Jog", groundSpeed = 22, enter = 16, minRate = 0.6, maxRate = 1.8 },
	{ key = "Run", groundSpeed = 64, enter = 38, minRate = 0.55, maxRate = 1.45 },
}
```

Values are the reference project's universal set. Validate at load time that each gait's band fits its clamp (its `enter` speed is at least `minRate * groundSpeed`, and the next gait's `enter` is at most `maxRate * groundSpeed`; see the band table in [[Locomotion Systems]]) and `warn` if not; this catches a designer raising a sprint speed without a matching clip.

## A working controller

```lua
--!strict
-- LocoController: client-side locomotion for the LocalPlayer's character.
-- Clips: a Folder of Animation objects named Idle, Walk, Jog, Run, Jump, Fall, Land,
-- each gait with a numeric "GroundSpeed" attribute.
local RunService = game:GetService("RunService")

export type GaitDef = { key: string, groundSpeed: number, enter: number, minRate: number, maxRate: number }

local GAITS: { GaitDef } = {
	{ key = "Walk", groundSpeed = 11, enter = 1, minRate = 0.4, maxRate = 1.7 },
	{ key = "Jog", groundSpeed = 22, enter = 16, minRate = 0.6, maxRate = 1.8 },
	{ key = "Run", groundSpeed = 64, enter = 38, minRate = 0.55, maxRate = 1.45 },
}
local HYSTERESIS = 1 -- studs/s: switch down one stud below the up threshold

local HANDBACK_STATES: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
}
local REPLACERS = { "Dashing", "PremiumMotionLocal", "CutsceneLock" }

local LocoController = {}
LocoController.__index = LocoController

function LocoController.new(char: Model, clips: Folder)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local animator = hum:WaitForChild("Animator") :: Animator
	local root = char:WaitForChild("HumanoidRootPart") :: BasePart
	local self = setmetatable({
		char = char, hum = hum, root = root,
		tracks = {} :: { [string]: AnimationTrack },
		groundSpeed = {} :: { [string]: number },
		current = nil :: string?,
		smooth = 0,
		jumpAt = -10, landAt = -10, airStart = nil :: number?, airFor = 0,
		conns = {} :: { RBXScriptConnection },
	}, LocoController)

	for _, anim in clips:GetChildren() do
		if anim:IsA("Animation") then
			local t = animator:LoadAnimation(anim)
			t.Priority = Enum.AnimationPriority.Movement
			t.Looped = anim.Name ~= "Jump" and anim.Name ~= "Land"
			self.tracks[anim.Name] = t
			local gs = anim:GetAttribute("GroundSpeed")
			if typeof(gs) == "number" then self.groundSpeed[anim.Name] = gs end
		end
	end

	table.insert(self.conns, hum.StateChanged:Connect(function(_, new)
		local now = os.clock()
		if new == Enum.HumanoidStateType.Jumping then
			self.jumpAt = now
		elseif new == Enum.HumanoidStateType.Freefall then
			self.airStart = self.airStart or now
		elseif new == Enum.HumanoidStateType.Landed then
			self.airFor = self.airStart and (now - self.airStart) or 0
			self.airStart = nil
			self.landAt = now
		end
	end))
	-- Heartbeat runs after physics, so velocity and FloorMaterial are this frame's values.
	table.insert(self.conns, RunService.Heartbeat:Connect(function(dt) self:step(dt) end))
	return self
end

-- Pure decision: returns the clip key to play (nil = hand back) and its rate.
function LocoController:decide(): (string?, number)
	local hum, char = self.hum, self.char
	if hum.Health <= 0 or HANDBACK_STATES[hum:GetState()] then return nil, 1 end
	for _, attr in REPLACERS do
		if char:GetAttribute(attr) then return nil, 1 end
	end
	local now = os.clock()
	local v = self.root.AssemblyLinearVelocity
	if hum.FloorMaterial == Enum.Material.Air then
		if now - self.jumpAt < 0.42 and v.Y > -4 then return "Jump", 1 end
		return "Fall", 1
	end
	if now - self.landAt < 0.5 and self.airFor > 0.3 and self.smooth < 6 then
		return "Land", 1
	end
	if self.smooth < 1 then return "Idle", 1 end
	-- The highest gait whose threshold the smoothed speed passes...
	local pick = GAITS[1]
	for _, g in GAITS do
		if self.smooth >= g.enter then pick = g end
	end
	-- ...but keep a faster current gait until speed is HYSTERESIS below its threshold.
	for _, g in GAITS do
		if g.key == self.current and g.enter > pick.enter and self.smooth >= g.enter - HYSTERESIS then
			pick = g
		end
	end
	local gs = self.groundSpeed[pick.key] or pick.groundSpeed
	return pick.key, math.clamp(self.smooth / gs, pick.minRate, pick.maxRate)
end

local GAIT_SET = { Walk = true, Jog = true, Run = true }
local function fadeFor(from: string?, to: string?): number
	if to == "Jump" or to == "Land" then return 0.08 end
	if from == "Land" then return 0.25 end
	if from and to and GAIT_SET[from] and GAIT_SET[to] then return 0.15 end
	if to == "Fall" then return 0.2 end
	return 0.2
end

function LocoController:step(dt: number)
	local v = self.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	self.smooth += (speed - self.smooth) * math.min(1, dt * 10) -- ~0.1 s time constant
	local want, rate = self:decide()
	local cur = self.current
	if want ~= cur then
		local fade = fadeFor(cur, want)
		local prev = cur and self.tracks[cur]
		local nextT = want and self.tracks[want]
		local phase: number? = nil
		if prev and nextT and cur and want and GAIT_SET[cur] and GAIT_SET[want] and prev.Length > 0 then
			phase = prev.TimePosition / prev.Length
		end
		if nextT then
			nextT:Play(fade, 1, rate)
			if phase and nextT.Length > 0 then nextT.TimePosition = phase * nextT.Length end
		end
		if prev then prev:Stop(fade) end
		self.current = want
	elseif want then
		local t = self.tracks[want]
		if t and math.abs(t.Speed - rate) > 0.01 then t:AdjustSpeed(rate) end
	end
end

function LocoController:Destroy()
	for _, c in self.conns do c:Disconnect() end
	for _, t in self.tracks do t:Stop(0) end
	table.clear(self.tracks)
end

return LocoController
```

Notes on the non-obvious lines:
- `Landed` is a real `HumanoidStateType`; it fires for a frame on touchdown, so the controller latches `landAt` instead of polling for it.
- `TimePosition` is set **after** `Play`, because `Play` restarts the track at 0 (measured behaviour; see [[AnimationTrack Reference]]).
- `AdjustSpeed` is skipped when the change is under 0.01, which matters if you replicate rate changes yourself (below). Native Animator tracks do not need it, but it costs nothing.
- The hysteresis block keeps the current faster gait until speed falls one stud/s under its threshold.

## Variants, carry and overlays

Extend `apply` rather than `decide` for these, because they are layers, not base states:

- **Idle variants**: an `idleFor` accumulator while `current == "Idle"`. When it passes `nextFidget` (10 s first, then `16 + math.random() * 10`), pick from the pool excluding the last pick. Variants that are full idles (look, shift) temporarily replace `"Idle"` in `decide`'s answer; one-shot fidgets play as an overlay.
- **Carry**: one track per weapon class, played at `Action` over the base, keyed on the right arm only. Off when any swing is playing (except during the swing's last 0.22 s, where it blends back), while `GuardingLocal`, `Dashing`, `FlourishLocal`, when the root is anchored, or when the class has its own idle and the character stands still.
- **Tool-hold suppression**: each frame a tool is held, find Animate's `ToolNoneAnim` track among `Animator:GetPlayingAnimationTracks()` and `AdjustWeight(0.001, 0.15)` when you own the arm.

## Composing with a Lua keyframe player

If your clips play through a Lua keyframe player instead of the Animator (the reference project did this so unpublished clips work live; see [[Lua Keyframe Player]]), the controller changes shape:

- The procedural animator **owns the joints**. It computes the base pose each frame, then asks the player to compose clip tracks over it (a `Compose(char, base, out)` style call).
- Clips at Movement priority or lower are left to the procedural animator; **Action and above play over its pose**.
- The procedural animator yields the **whole body** to Action+ game clips (abilities, inspect, iai) and only the **upper body** to upper-body copy clips.
- Everything that used to listen to Animator signals (VFX juice, stance FX, staff spin, flourish controller, ult camera) must listen to the player's own `OnPlayed` / `PlayingTracks` instead. Missing one listener is the typical regression: the effect silently never fires.

## Networking

| Playback path | How others see it | What you must do |
|---|---|---|
| `Animator` on the local character | Animator replicates the local player's tracks | Nothing; avoid unnecessary `AdjustSpeed` spam |
| Lua keyframe player | Not replicated | Batch track events to the server, relay to others |
| Procedural (writes `Motor6D.Transform`) | Not replicated | Send inputs (speed, state), every client simulates |

The reference relay batches and throttles local track events through a RemoteEvent; speed changes are sent at once when they change by **6% or more**, otherwise at most every **0.25 s**. Metadata rides as attributes on the Animation (`KitMove`, `KitUpper`, `QuickdrawClip`, `StanceClip`) so receivers know what a track is without extra messages. Locomotion is the noisiest source of rate changes, which is why the 6% / 0.25 s gate exists: an analog stick produces a new rate every frame.

## Failure modes and how they look

| On screen | Likely cause |
|---|---|
| Legs reset to frame 0 after every ability | Controller stopped locomotion for an overrider instead of keeping it underneath |
| Gait flickers on slopes | Raw speed, no smoothing or hysteresis |
| Brief T-pose on seat | `decide` returns Idle for `Seated` instead of handing back |
| Jump clip plays when walking off a ledge | Jump not gated on `vy > -4` or on the Jumping event |
| Other players see you sliding | Lua-played loco without rate replication |
| Carry arm snaps during flourish | Carry not checking `FlourishLocal` |

## Checklist

- [ ] `decide` is pure and unit tested with a speed/state table.
- [ ] Gait data lives with the clips; load-time validation of bands vs clamps.
- [ ] Speed smoothed, hysteresis on downshift.
- [ ] Replacers stop locomotion; overriders leave it running.
- [ ] Ownership attributes in one constants module.
- [ ] Hand-back states play nothing.
- [ ] If clips are Lua-played: relay with a change threshold, and every listener moved to the player's own signals.

See also: [[Locomotion Systems]], [[Snippets - Animation Controller Module]], [[Humanoid States and Animation]], [[Frame Order and RunService Timing]], [[Lua Keyframe Player Internals]].

## Connected notes
<!-- auto-links:start -->
[[Ability Kits Architecture]] · [[Weapon and Combat Animation]] · [[Snippets - Playing Animations]] · [[The Default Animate Script]] · [[Custom Character Controllers]] · [[Characters and Humanoids]] · [[Animation Start Here]]
<!-- auto-links:end -->
