---
tags: [snippets, luau, enemies, npc, replication, client, type/reference, area/animation, level/intermediate, api/AnimationPriority, area/networking, api/Animator]
---
# Snippets: Enemy Client Animator

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: The server also playing tracks on the same enemy (double playback, server cost).
> - Avoid: Using `os.clock()` instead of `workspace:GetServerTimeNow()` for start times.
> - Avoid: Writing the serial before the other attributes (the client reads a half-updated state).
>
> Cost: TL;DR ~110 tok · whole note ~6.1k tok. Read more: ## 4. The client animator · ## 5. Notes and nuance · ## Common mistakes
<!-- tldr:end -->

A client-side animator for enemies and NPCs driven entirely by **server attributes**. The server never plays a clip: it decides what the enemy is doing and when it started, writes a few attributes, and uses marker times from data for gameplay. Every client plays the clips locally from those attributes, which gives late joining, streaming, LOD and lag tolerance almost for free.

This is the pattern one live action game used for 20+ enemy kits and its bosses. The protocol is described in [[Enemy Animation State Protocol]]; the wider system in [[Enemy and NPC Animation]] and [[Boss Animation and Phases]].

---

## 1. Why the server does not play enemy clips

The obvious design is "the server plays the NPC's tracks, and they replicate" (Docs: for non-player models, tracks must be played on the server to replicate). It works, but:
- Every track start, stop, speed and weight change is network traffic, per enemy.
- The server needs the clips loaded and stepping, per enemy, even if nobody is near.
- Late joiners and streamed-in enemies get whatever the replication system reconstructs.
- Gameplay that waits for a server-side marker depends on the server's frame timing.

Attribute-driven playback flips it:
- The server writes **what** (clip name), **when** (server start time), **how fast** (speed), and a serial number. A few bytes per state change.
- The server gets its timing from **data**: marker times exported from the clips into the enemy definition (telegraph start, hit, end). It never needs the clip at all.
- Each client computes `elapsed = (GetServerTimeNow() - t0) * speed` and starts the clip there. A late joiner, a re-streamed enemy, or a client waking an enemy from LOD sleep lands on the right frame.
- Combo links can join the next clip part-way by setting `t0` in the past.

The reference project's rules worth copying:
- Enemy clips never play below 1x speed, except a stagger hit at 0.5x.
- A "caught" clip always plays in full (a longer hold extends the state instead).
- No turning while caught or knocked up; hit flinches are skipped during caught, knock-up and stun clips.
- Boss-class dodge windows: i-frames 0.40 s, warnings and combo links at least 0.5 s, markers locked at least 0.45 s before the blow.

---

## 2. The protocol

Attributes on the enemy model (names are an example convention):

| Attribute | Type | Meaning |
|---|---|---|
| `Kind` | string | Which clip set (enemy definition) to use |
| `AnimClip` | string | Current one-shot or state clip; `""` = locomotion |
| `AnimT0` | number | `workspace:GetServerTimeNow()` when it started (minus any join offset) |
| `AnimSpeed` | number | Playback speed |
| `AnimLoop` | boolean | Loop it until changed |
| `AnimSerial` | number | Incremented on every start, so the same clip can restart; **written last** |
| `AnimLayer` | string | Optional overlay clip (a glowing charge, a limp) |
| `AnimLayerT0` | number | Its start time |
| `Hurt` | string | Directional flinch name (`HitFront`, `HitLeft`, `HeavyHit`) |
| `HurtSerial` | number | Incremented per flinch |
| `DeadT0` | number | Server time of death; **written before** `Dead` |
| `Dead` | boolean | Death clip plays from `DeadT0` and holds its last frame |

Server helper:

```lua
--!strict
-- Server: start a clip on every client. offset = seconds into the clip (combo links join part-way).
local function playEnemyClip(model: Model, clip: string, speed: number?, loop: boolean?, offset: number?)
	local s = speed or 1
	model:SetAttribute("AnimClip", clip)
	model:SetAttribute("AnimT0", workspace:GetServerTimeNow() - (offset or 0) / s)
	model:SetAttribute("AnimSpeed", s)
	model:SetAttribute("AnimLoop", loop == true)
	model:SetAttribute("AnimSerial", ((model:GetAttribute("AnimSerial") :: number?) or 0) + 1)   -- last
end

local function killEnemy(model: Model)
	model:SetAttribute("DeadT0", workspace:GetServerTimeNow())
	model:SetAttribute("Dead", true)                    -- last: clients read DeadT0 when this changes
end

local function hurtEnemy(model: Model, kind: string)
	model:SetAttribute("Hurt", kind)
	model:SetAttribute("HurtSerial", ((model:GetAttribute("HurtSerial") :: number?) or 0) + 1)
end
```

The server's attack timing comes from the definition: for example `{ clip = "Slam", tele = 0.35, hit = 0.82, length = 1.4 }`, with `hit` exported from the clip's `Hit` marker by the import tool. When clips are retimed, re-export the times. See [[Pipeline - Importing Animated Enemies]].

---

## 3. Clip definitions (shared data)

```lua
--!strict
-- ReplicatedStorage.EnemyClipDefs: per Kind, the clips and how to play them.
export type EnemyClip = {
	id: string,
	priority: Enum.AnimationPriority?,
	looped: boolean?,
	hold: boolean?,          -- freeze on the last frame instead of ending (death)
	groundSpeed: number?,    -- locomotion clips: studs/s at speed 1 (for a scale-1 model)
	noFlinch: boolean?,      -- hit flinches are skipped while this clip plays
}
export type EnemyDef = {
	clips: { [string]: EnemyClip },
	idle: string, walk: string?, run: string?,
	runAt: number?,          -- studs/s
	flinches: { [string]: string }?,  -- Hurt value -> clip name
	death: string?,
	fx: { [string]: (model: Model, value: string) -> () }?,   -- marker name -> client effect
}

return {
	Golem = {
		idle = "Idle", walk = "Walk", run = "Run", runAt = 14, death = "Death",
		clips = {
			Idle  = { id = "rbxassetid://0000000101", priority = Enum.AnimationPriority.Idle, looped = true },
			Walk  = { id = "rbxassetid://0000000102", priority = Enum.AnimationPriority.Movement, looped = true, groundSpeed = 8 },
			Run   = { id = "rbxassetid://0000000103", priority = Enum.AnimationPriority.Movement, looped = true, groundSpeed = 16 },
			Slam  = { id = "rbxassetid://0000000104", priority = Enum.AnimationPriority.Action },
			Caught = { id = "rbxassetid://0000000105", priority = Enum.AnimationPriority.Action2, noFlinch = true },
			HitFront = { id = "rbxassetid://0000000106", priority = Enum.AnimationPriority.Action3 },
			Death = { id = "rbxassetid://0000000107", priority = Enum.AnimationPriority.Action4, hold = true },
		},
		flinches = { HitFront = "HitFront", HeavyHit = "HitFront" },
		fx = {
			Step = function(model, _)
				-- dust puff + footstep sound at the foot
			end,
			FX_Slam = function(model, _)
				-- shockwave ring
			end,
		},
	},
} :: { [string]: EnemyDef }
```

A model attribute `ClipId_<Name>` overrides the id, so one definition can serve variants. In the reference project the lookup order was: model `ClipId_*` attribute, then the definition's id, then a Studio-only mirror, and if nothing played, a procedural pose on the root bone so the enemy never stood in a T-pose.

---

## 4. The client animator

```lua
--!strict
-- StarterPlayerScripts: plays every tagged enemy's clips from its attributes.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Defs = require(game.ReplicatedStorage.EnemyClipDefs)

local FX_RANGE = 150          -- studs: cosmetic marker FX beyond this are skipped
local SLEEP_RANGE = 400       -- studs: beyond this, stop all tracks (resync on wake)

type Rig = {
	model: Model,
	def: Defs.EnemyDef,
	animator: Animator,
	root: BasePart,
	tracks: { [string]: AnimationTrack },
	loco: AnimationTrack?, locoName: string?,
	main: AnimationTrack?, mainName: string?, mainHold: boolean,
	layer: AnimationTrack?,
	conns: { RBXScriptConnection },
	asleep: boolean,
	lodTimer: number,
}

local rigs: { [Model]: Rig } = {}

local function now(): number return workspace:GetServerTimeNow() end

local function getTrack(r: Rig, name: string): AnimationTrack?
	local t = r.tracks[name]
	if t then return t end
	local c = r.def.clips[name]
	if not c then return nil end
	local override = r.model:GetAttribute("ClipId_" .. name)
	local anim = Instance.new("Animation")
	anim.AnimationId = (typeof(override) == "string" and override ~= "") and override or c.id
	local tr = r.animator:LoadAnimation(anim)           -- local-only playback: the server never plays these
	tr.Priority = c.priority or Enum.AnimationPriority.Action
	tr.Looped = c.looped == true
	r.tracks[name] = tr
	return tr
end

-- Start a track at the time the server says it started. Handles clips that have not loaded yet.
local function playSynced(r: Rig, tr: AnimationTrack, t0: number, speed: number, loop: boolean, hold: boolean, fade: number)
	tr.Looped = loop
	tr:Play(fade, 1, speed)
	local function seek()
		if not tr.IsPlaying or tr.Length <= 0 then return end
		local elapsed = math.max(0, (now() - t0) * speed)
		if loop then
			tr.TimePosition = elapsed % tr.Length
		elseif elapsed < tr.Length then
			tr.TimePosition = elapsed                   -- late join: skip ahead
		elseif hold then
			tr.TimePosition = tr.Length - 1e-3          -- already over: show the held end pose
			tr:AdjustSpeed(0)
		else
			tr:Stop(0)                                  -- a one-shot that already finished: do not replay it
		end
	end
	if tr.Length > 0 then
		seek()
	else
		task.spawn(function()                           -- Length is 0 until loaded (Docs)
			local deadline = os.clock() + 5
			while tr.Length <= 0 and os.clock() < deadline do task.wait() end
			seek()                                      -- recomputes elapsed with the current clock
		end)
	end
end

local function applyMain(r: Rig, fade: number)
	local name = r.model:GetAttribute("AnimClip") :: string?
	if r.model:GetAttribute("Dead") and r.def.death then name = r.def.death end
	if r.main and r.main.IsPlaying then r.main:Stop(fade) end
	r.main, r.mainName, r.mainHold = nil, nil, false
	if not name or name == "" then return end
	local tr = getTrack(r, name)
	if not tr then warn("[enemy] no clip", name, "for", r.model.Name); return end
	local c = r.def.clips[name]
	local dead = r.model:GetAttribute("Dead") == true
	local t0 = (r.model:GetAttribute(dead and "DeadT0" or "AnimT0") :: number?) or now()
	local speed = (r.model:GetAttribute("AnimSpeed") :: number?) or 1
	local loop = r.model:GetAttribute("AnimLoop") == true and not dead
	r.main, r.mainName, r.mainHold = tr, name, c.hold == true
	playSynced(r, tr, t0, dead and 1 or speed, loop, c.hold == true, fade)
end

local function applyLayer(r: Rig)
	local name = r.model:GetAttribute("AnimLayer") :: string?
	if r.layer and r.layer.IsPlaying then r.layer:Stop(0.2) end
	r.layer = nil
	if not name or name == "" then return end
	local tr = getTrack(r, name)
	if not tr then return end
	r.layer = tr
	playSynced(r, tr, (r.model:GetAttribute("AnimLayerT0") :: number?) or now(), 1, true, false, 0.2)
end

local function applyHurt(r: Rig)
	local kind = r.model:GetAttribute("Hurt") :: string?
	local flinch = kind and r.def.flinches and r.def.flinches[kind]
	if not flinch or r.model:GetAttribute("Dead") then return end
	local cur = r.mainName and r.def.clips[r.mainName]
	if cur and cur.noFlinch and r.main and r.main.IsPlaying then return end   -- no flinch while caught/stunned
	local tr = getTrack(r, flinch)
	if tr then tr:Play(0.05) end
end

-- markers -> cosmetic FX, only near the camera
local function hookMarkers(r: Rig, name: string, tr: AnimationTrack)
	if not r.def.fx then return end
	for marker, fn in r.def.fx do
		table.insert(r.conns, tr:GetMarkerReachedSignal(marker):Connect(function(value: string)
			local cam = workspace.CurrentCamera
			if (cam.CFrame.Position - r.root.Position).Magnitude <= FX_RANGE then fn(r.model, value) end
		end))
	end
end

local function chooseLoco(r: Rig)
	local v = r.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local def = r.def
	local name = def.idle
	if def.walk and speed > 0.5 then name = def.walk end
	if def.run and speed > (def.runAt or 14) then name = def.run end
	local tr = getTrack(r, name)
	if not tr then return end
	if name ~= r.locoName or not tr.IsPlaying then
		if r.loco and r.loco ~= tr and r.loco.IsPlaying then r.loco:Stop(0.25) end
		tr:Play(0.25)
		r.loco, r.locoName = tr, name
	end
	local c = def.clips[name]
	if c.groundSpeed and speed > 0.5 then
		-- big enemies take longer strides: scale ground speed with model size
		local gs = c.groundSpeed * r.model:GetScale()
		tr:AdjustSpeed(math.clamp(speed / gs, 0.7, 1.6))
	elseif tr.Speed ~= 1 then
		tr:AdjustSpeed(1)
	end
end

local function sleep(r: Rig)
	r.asleep = true
	for _, tr in r.animator:GetPlayingAnimationTracks() do tr:Stop(0) end
	r.loco, r.locoName, r.main, r.mainName, r.layer = nil, nil, nil, nil, nil
end

local function wake(r: Rig)
	r.asleep = false
	applyMain(r, 0)          -- everything is reconstructible from attributes + server time
	applyLayer(r)
end

local function add(model: Instance)
	if not model:IsA("Model") or rigs[model] then return end
	local def = Defs[(model:GetAttribute("Kind") :: string?) or ""]
	if not def then return end
	-- streaming: the model can arrive before its parts and controller do
	local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local ctrl = model:WaitForChild("AnimationController", 10)
	local animator = ctrl and ctrl:WaitForChild("Animator", 10) :: Animator?
	if not (root and animator) or not model.Parent then return end

	local r: Rig = {
		model = model, def = def, animator = animator :: Animator, root = root :: BasePart,
		tracks = {}, loco = nil, locoName = nil, main = nil, mainName = nil, mainHold = false,
		layer = nil, conns = {}, asleep = false, lodTimer = math.random() * 0.5,
	}
	rigs[model] = r

	-- load every clip's track and hook its markers once (connections live as long as the rig)
	for name in def.clips do
		local tr = getTrack(r, name)
		if tr then hookMarkers(r, name, tr) end
	end

	table.insert(r.conns, model:GetAttributeChangedSignal("AnimSerial"):Connect(function()
		if not r.asleep then applyMain(r, 0.1) end
	end))
	table.insert(r.conns, model:GetAttributeChangedSignal("Dead"):Connect(function()
		if not r.asleep then applyMain(r, 0.1) end
	end))
	table.insert(r.conns, model:GetAttributeChangedSignal("AnimLayer"):Connect(function()
		if not r.asleep then applyLayer(r) end
	end))
	table.insert(r.conns, model:GetAttributeChangedSignal("HurtSerial"):Connect(function()
		if not r.asleep then applyHurt(r) end
	end))

	applyMain(r, 0)            -- late join: start whatever is already running, at the right time
	applyLayer(r)
end

local function remove(model: Instance)
	local r = rigs[model :: Model]
	if not r then return end
	rigs[model :: Model] = nil
	for _, c in r.conns do c:Disconnect() end
	for _, tr in r.tracks do
		if tr.IsPlaying then tr:Stop(0) end
		tr:Destroy()
	end
end

-- PreAnimation: choose tracks and speeds right before the engine steps animations (Docs).
RunService.PreAnimation:Connect(function(dt: number)
	local camPos = workspace.CurrentCamera.CFrame.Position
	for _, r in rigs do
		r.lodTimer -= dt
		if r.lodTimer <= 0 then
			r.lodTimer = 0.5                               -- distance checks twice a second
			local far = (r.root.Position - camPos).Magnitude > SLEEP_RANGE
			if far and not r.asleep then sleep(r) elseif not far and r.asleep then wake(r) end
		end
		if r.asleep then continue end
		-- hold clips: freeze just before the end so the one-shot never ends and fades out
		local m = r.main
		if m and r.mainHold and m.IsPlaying and m.Length > 0 and m.Speed > 0
			and m.TimePosition + dt * m.Speed >= m.Length - 1e-3 then
			m.TimePosition = m.Length - 1e-3
			m:AdjustSpeed(0)
		end
		-- locomotion only when no one-shot owns the body (or the one-shot is an upper-body overlay)
		if not (m and m.IsPlaying) and not r.model:GetAttribute("Dead") then chooseLoco(r) end
	end
end)

for _, m in CollectionService:GetTagged("Enemy") do task.spawn(add, m) end
CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(m) task.spawn(add, m) end)
CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(remove)
```

---

## 5. Notes and nuance

**Late joining.** `applyMain` on add starts whatever the server says is running, at `(now - t0) * speed`. One-shots that have already finished are not replayed (a player joining mid-fight should not see an old slam). A death that already happened shows its held last frame.

**Streaming.** Tag-based discovery fires when the model streams in; `remove` fires when it streams out or is destroyed. Because state is in attributes, a streamed-in enemy is correct on its first frame. The `WaitForChild` calls cover a model whose parts arrive after the model itself.

**Sleeping is LOD.** Far enemies stop all tracks; on wake, everything is rebuilt from attributes. This only works because nothing depends on the client having seen past events. Cosmetic marker FX are skipped beyond 150 studs. Engine LOD (`Animator.PreferLodEnabled`, default true) also reduces evaluation for these rigs; you do not need to manage that. See [[Animation LOD]].

**Hold clips.** A non-looped track that reaches its end holds and then fades out over 0.3 s (measured). For death, that would make the corpse fade back to the idle. Freezing at `Length - 1e-3` in `PreAnimation` keeps the last pose. Ground-fit death clips, or the corpse will sink into slopes (the reference project fitted 205 of 304 clips and added a runtime slope clamp; see [[Ground Fitting Pipeline]]).

**Markers on the client are cosmetic.** Damage comes from the server's data times. Client markers drive sounds, dust, sparks, trails and screen shake. Marker names used in the reference project: `Tele`, `Hit`, `Hit2`..., `Proj`, `Summon`, `MoveStart`/`MoveEnd`, `Step`, `FX_<name>`.

**Scale.** For scaled enemies, scale the clip's ground speed with `Model:GetScale()` (the snippet does), or follow the reference project's rule of slowing walks by about `0.85 / sqrt(scale)`. Do not speed clips up to match fast move speeds: measured strides were 2 to 4 times slower than the definitions' move speeds, and syncing them made enemies look frantic. Slow the movement or re-author the walk instead.

**Root motion.** Clips here should not move the root (the server moves the `HumanoidRootPart`). Turn clips get their root yaw stripped because the server turns the root. Import-time axis problems (whole body turned 180 degrees) are fixed in the data: [[Enemy Import Axis Fix]].

**When there is no clip.** Hold a simple procedural pose on the root bone rather than showing the bind pose. Bosses in the reference project "joined late": their clip data streamed in during the intro, and the intro started once it arrived.

## Common mistakes
- The server also playing tracks on the same enemy (double playback, server cost).
- Using `os.clock()` instead of `workspace:GetServerTimeNow()` for start times.
- Writing the serial before the other attributes (the client reads a half-updated state).
- Replaying finished one-shots for late joiners.
- Gameplay damage from client markers.
- Letting death clips end (they fade back to idle).

## See also
[[Enemy Animation State Protocol]] · [[Enemy and NPC Animation]] · [[Boss Animation and Phases]] · [[Replication and Ownership]] · [[Animation LOD]] · [[Markers and Events]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Snippets - Animation Controller Module]]

## Nuances and edge cases

1. **The cost moves, it does not vanish.** The server saves work, but every client now animates every enemy it can see. With 10 enemies on screen that is trivial; a wave mode with 150 enemies streamed in can cost a low-end phone more than the rest of the game combined. Sleep radius and LOD distances must be set from the device's measured budget, not from the desktop's. A common split is a shorter sleep radius on touch devices (rule of thumb: about 60 percent of the desktop radius).
2. **Clock sync is approximate.** `GetServerTimeNow()` is synchronised but not exact; on a freshly joined client or a bad connection it can be off by tens of milliseconds and correct itself in small jumps. For cosmetic clips this is invisible. Do not compare client-computed clip time to server data for gameplay; the server stays the only judge.
3. **Attribute write order and batching.** Attributes set in the same server frame arrive together, but there is no documented guarantee of order between them (unverified against docs; the reference project treated the serial as the commit flag and wrote it last). Keep that convention, and have the client re-read all attributes when the serial changes rather than reacting to each attribute separately.
4. **High state churn.** An enemy that changes state 10 times a second (jittery AI flipping between chase and attack) sends 10 small updates per second per enemy to every client that has it streamed. At 100 enemies that is a real bandwidth cost. Add hysteresis to the AI so state changes are meaningful, not noisy.
5. **Exploiters can read the future.** Because clip names and start times are public attributes, a modified client can read an attack's name the instant the server sets it and show a perfect dodge timer. That is acceptable for most PvE games (the telegraph is meant to be visible), but do not encode hidden information, such as which player a boss is about to target, in attributes before you want players to know it.
6. **Speed below 1x and stagger.** Rules like "never below 1x except stagger at 0.5x" protect readability. On high-ping clients a slow clip hides latency better than a fast one, so if you must break the rule, break it towards slower clips, not faster.
7. **Version skew during updates.** When you ship a new enemy definition, old servers still running the old version send clip names that new clients may not know (or the reverse, during soft shutdowns). Fall back to an idle or a generic attack when a clip name is unknown instead of erroring.

## Common mistakes in production

1. **Keeping a LOD-sleeping enemy's tracks loaded forever.** Symptom: memory grows as players explore. Fix: release tracks after an enemy has been asleep or streamed out for some seconds.
2. **Client-side hit reactions that move the root.** Symptom: enemy position differs between clients and the server. Fix: hit reactions animate limbs only; root movement comes from the server.
3. **Every client spawning the same projectile from the `Proj` marker and also the server spawning it.** Symptom: double projectiles on screen. Fix: the server spawns the gameplay projectile; client markers spawn only cosmetic muzzle FX.
4. **Using the enemy model's name to pick clips.** Symptom: renamed models in a hot fix lose their animations. Fix: a `Kit` attribute that names the definition.
5. **Boss intro waiting on clips that never arrive.** Symptom: soft-locked fight on slow devices. Fix: a timeout that starts the intro with a fallback pose.

## Related decisions

- [[NPC AI and Behaviour]]: where the state that this animator plays is decided.
- [[Boss Fight Design Patterns]]: telegraph lengths and dodge windows that these clips have to respect.
- [[Instance Streaming]]: the stream in and out behaviour this design depends on.
- [[Interest Management and Per-Player Replication]]: limiting which enemies each client hears about.
- [[Network Bandwidth Budgets and Measuring Them]]: measuring attribute traffic per enemy.
- [[Server Shutdowns Soft Updates and Migration]]: handling definition changes across server versions.
- [[Projectiles and Ballistics]]: separating the gameplay projectile from cosmetic marker FX.
- [[Genre Playbook - Tower Defense]]: the genre with the highest enemy counts on screen.
- [[Mobile and Low-End Optimization]]: setting sleep and LOD radii per device.

## Connected notes
<!-- auto-links:start -->
[[Animating Creatures and Monsters]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Creature Rig Conventions]] · [[Snippets - Lua Keyframe Player Core]] · [[Replication Rules]] · Case Study - Enemy Roster Rebuild · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Snippets - Playing Animations]] · [[Snippets - Ragdoll]] · [[Combat Animation Craft]] · [[Snippets - Procedural Motion]] · [[Snippets - IK]] · [[Bones and Skinned Meshes]] · [[Procedural Animation]] · [[Snippets - Building and Sampling Clips]]
<!-- related:end -->
