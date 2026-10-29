---
tags: [snippets, luau, playback, animator, type/reference, area/animation, level/intermediate, api/AnimationTrack, area/scripting, api/Animator, api/AnimationPriority, api/Animation]
---
# Snippets: Playing Animations

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `animator:LoadAnimation(anim):Play()` per click (new track each time; 256-track warning).
> - Avoid: Setting `Priority` after `Play`.
> - Avoid: Computing speed from `Length` before the clip has loaded (speed 0, frozen clip).
>
> Cost: TL;DR ~100 tok · whole note ~6.3k tok. Read more: ## 1. The module · ## 3. Swapping the default Animate clips · ## Common mistakes
<!-- tldr:end -->

Production patterns for playing clips through the engine `Animator`: finding the Animator, caching tracks, preloading, waiting for a clip to load, marker hooks that do not leak, fitting a clip to a gameplay window, hit-stop that survives overlapping hits, swapping the default Animate clips, phase-synced locomotion crossfades, and resolving a published id with a fallback.

Everything here uses documented API (`Animator:LoadAnimation`, `AnimationTrack:Play(fadeTime, weight, speed)`, `GetMarkerReachedSignal`, `ContentProvider:PreloadAsync`). Why each pattern exists is in [[Engine Gotchas]] and [[AnimationTrack Reference]].

---

## 1. The module

Drop this in `ReplicatedStorage` as `AnimPlay`. Each function is explained after the code.

```lua
--!strict
-- AnimPlay: track cache, preload, markers, fitting, hit-stop, crossfades.
local ContentProvider = game:GetService("ContentProvider")

local AnimPlay = {}

export type PlayOptions = {
	fade: number?,                        -- fade-in seconds (engine default 0.1)
	weight: number?,                      -- target weight (default 1)
	speed: number?,                       -- playback speed (default 1); ignored if duration is set
	duration: number?,                    -- stretch the clip to last this many seconds
	priority: Enum.AnimationPriority?,    -- set BEFORE Play
	looped: boolean?,
	markers: { [string]: (value: string) -> () }?,  -- marker name -> handler
	onStopped: (() -> ())?,               -- gameplay "move over" (may still be fading)
	onEnded: (() -> ())?,                 -- visual "fully gone": cleanup here
}

-- ---------------------------------------------------------------- Animator lookup
-- Waits for a Humanoid or AnimationController with an Animator. The server creates Animators;
-- an Animator created on a client does not replicate its tracks (Docs).
function AnimPlay.getAnimator(model: Model, timeout: number?): Animator?
	local deadline = os.clock() + (timeout or 5)
	repeat
		local host: Instance? = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
		local animator = host and host:FindFirstChildOfClass("Animator")
		if animator then return animator end
		task.wait()
	until os.clock() > deadline
	return nil
end

-- ---------------------------------------------------------------- Animation objects
-- One Animation instance per id, shared by every Animator that loads it.
local animations: { [string]: Animation } = {}
local function animationFor(id: string): Animation
	local a = animations[id]
	if not a then
		a = Instance.new("Animation")
		a.AnimationId = id
		a.Name = id
		animations[id] = a
	end
	return a
end

-- ---------------------------------------------------------------- track cache
-- LoadAnimation returns a NEW track on every call (Docs), so load once per Animator per id.
-- Weak keys + Destroying cleanup: a dead character's tracks do not keep the cache alive.
local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

function AnimPlay.track(animator: Animator, id: string): AnimationTrack
	local byId = cache[animator]
	if not byId then
		byId = {}
		cache[animator] = byId
		animator.Destroying:Once(function()
			cache[animator] = nil
		end)
	end
	local tr = byId[id]
	if not tr then
		tr = animator:LoadAnimation(animationFor(id))    -- Animator must be under Workspace
		byId[id] = tr
	end
	return tr
end

-- ---------------------------------------------------------------- preload
-- Fetch clip assets before first use (otherwise the first play starts late and Length is 0).
-- Yields. Call when a kit/weapon is equipped, not when the move is pressed.
function AnimPlay.preload(animator: Animator?, ids: { string })
	local list = {}
	for _, id in ids do table.insert(list, animationFor(id)) end
	ContentProvider:PreloadAsync(list)
	if animator then
		for _, id in ids do AnimPlay.track(animator, id) end   -- create tracks now, not mid-combat
	end
end

-- Wait until the track has content. Length is 0 until the clip has loaded (Docs).
function AnimPlay.waitLoaded(track: AnimationTrack, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 3)
	while track.Length <= 0 and os.clock() < deadline do task.wait() end
	return track.Length > 0
end

-- ---------------------------------------------------------------- markers without leaks
-- One connection per (track, marker name), made once. Each play swaps in its own handler table.
type MarkerState = { handlers: { [string]: (string) -> () }, conns: { [string]: RBXScriptConnection } }
local markerState: { [AnimationTrack]: MarkerState } = setmetatable({}, { __mode = "k" }) :: any

local function setMarkerHandlers(track: AnimationTrack, handlers: { [string]: (string) -> () })
	local st = markerState[track]
	if not st then
		st = { handlers = {}, conns = {} }
		markerState[track] = st
	end
	local state = st :: MarkerState
	state.handlers = handlers
	for name in handlers do
		if not state.conns[name] then
			state.conns[name] = track:GetMarkerReachedSignal(name):Connect(function(value: string)
				local h = state.handlers[name]
				if h then h(value) end
			end)
		end
	end
end

-- ---------------------------------------------------------------- play
-- Returns the track and a cancel function. Each call gets a token; handlers from an older play of
-- the same track are dropped, so a re-pressed move never runs the previous press's Hit handler.
local playToken: { [AnimationTrack]: number } = setmetatable({}, { __mode = "k" }) :: any
local playConns: { [AnimationTrack]: { RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any

function AnimPlay.play(animator: Animator, id: string, opts: PlayOptions?): (AnimationTrack, (fade: number?) -> ())
	local o: PlayOptions = opts or {}
	local track = AnimPlay.track(animator, id)
	local token = (playToken[track] or 0) + 1
	playToken[track] = token

	if o.priority then track.Priority = o.priority end
	if o.looped ~= nil then track.Looped = o.looped end
	setMarkerHandlers(track, o.markers or {})

	track:Play(o.fade or 0.1, o.weight or 1, o.speed or 1)    -- Play on a playing track restarts it

	if o.duration then
		-- Speed from Length needs a loaded clip; otherwise fix it up as soon as it loads.
		local function fit()
			if playToken[track] == token and track.Length > 0 then
				track:AdjustSpeed(track.Length / math.max(o.duration :: number, 1e-3))
			end
		end
		if track.Length > 0 then fit() else task.spawn(function() AnimPlay.waitLoaded(track); fit() end) end
	end

	-- A re-play supersedes the previous play of this track: drop its lifecycle connections so rapid
	-- re-presses (which may restart the track before Stopped/Ended ever fire) cannot pile them up.
	local old = playConns[track]
	if old then for _, c in old do c:Disconnect() end end
	local conns: { RBXScriptConnection } = {}
	playConns[track] = conns

	table.insert(conns, track.Stopped:Connect(function()
		if playToken[track] ~= token then return end
		if track.IsPlaying then return end   -- a restart, not a stop (defensive: undocumented edge)
		-- Time keeps running while a stopped track fades (measured), so a cancelled swing could still
		-- reach its Hit marker during the fade. Drop this play's handlers now.
		setMarkerHandlers(track, {})
		if o.onStopped then o.onStopped() end
	end))
	table.insert(conns, track.Ended:Connect(function()
		for _, c in conns do c:Disconnect() end
		if playConns[track] == conns then playConns[track] = nil end
		if playToken[track] == token and o.onEnded then o.onEnded() end
	end))

	local function cancel(fade: number?)
		if playToken[track] == token and track.IsPlaying then track:Stop(fade or 0.1) end
	end
	return track, cancel
end

-- ---------------------------------------------------------------- hit-stop
-- Freeze tracks for a few hundredths of a second on impact. Overlapping hit-stops are safe: each
-- track remembers its pre-freeze speed once, and only the LATEST hit-stop restores it.
type Frozen = { speed: number, token: number }
local frozen: { [AnimationTrack]: Frozen } = {}
local hitStopSerial = 0

function AnimPlay.hitStop(tracks: { AnimationTrack }, seconds: number)
	hitStopSerial += 1
	local mine = hitStopSerial
	for _, t in tracks do
		local f = frozen[t]
		if f then
			f.token = mine                                  -- already frozen: keep its ORIGINAL speed
		else
			frozen[t] = { speed = t.Speed, token = mine }
		end
		t:AdjustSpeed(0)
	end
	task.delay(seconds, function()
		for t, f in frozen do
			if f.token == mine then
				frozen[t] = nil                 -- clearing fields during traversal is allowed
				if t.IsPlaying then t:AdjustSpeed(f.speed) end
			end
		end
	end)
end

-- ---------------------------------------------------------------- loops and crossfades
-- Crossfade between looping clips (walk -> run), optionally keeping the stride phase.
-- TimePosition can only be set while the track is playing (Docs), so Play first.
function AnimPlay.crossfade(from: AnimationTrack?, to: AnimationTrack, fade: number, keepPhase: boolean?)
	if from == to then return end
	local phase: number? = nil
	if keepPhase and from and from.IsPlaying and from.Length > 0 then
		phase = from.TimePosition / from.Length
	end
	if not to.IsPlaying then to:Play(fade) end
	if phase and to.Length > 0 then to.TimePosition = phase * to.Length end
	if from and from.IsPlaying then from:Stop(fade) end
end

-- Blend order of a priority. Enum values are Idle 0 .. Action4 5, but Core is 1000 even though it is
-- the LOWEST layer, so never compare .Value directly.
function AnimPlay.rank(p: Enum.AnimationPriority): number
	if p == Enum.AnimationPriority.Core then return -1 end
	return p.Value
end

-- Stop every track at or below a priority (e.g. clear locomotion before a cutscene clip).
function AnimPlay.stopAtOrBelow(animator: Animator, priority: Enum.AnimationPriority, fade: number?)
	local limit = AnimPlay.rank(priority)
	for _, t in animator:GetPlayingAnimationTracks() do
		if AnimPlay.rank(t.Priority) <= limit then t:Stop(fade or 0.1) end
	end
end

return AnimPlay
```

Notes on the less obvious lines:
- **`animator.Destroying:Once`** clears the cache when a character is removed. The weak-key table is a second safety net.
- **`setMarkerHandlers(track, {})` on `Stopped`.** A track stopped with `Stop(fade)` keeps advancing its time during the fade (measured). Without this, cancelling a swing 0.05 s before its `Hit` marker still deals the hit during the fade-out.
- **`AnimPlay.rank`.** `Enum.AnimationPriority` values run Idle 0, Movement 1, Action 2, Action2 3, Action3 4, Action4 5, but `Core` is 1000 although it blends as the lowest layer. Comparing `.Value` directly makes Core look like the highest priority.
- **Hit-stop restore by token.** Two hits 0.03 s apart would otherwise have the first restore unfreeze the second, or restore speed 0 as the "original".

---

## 2. Usage: a melee swing

```lua
local AnimPlay = require(game.ReplicatedStorage.AnimPlay)

local SLASH = "rbxassetid://0000000000"      -- placeholder id
local animator = AnimPlay.getAnimator(character) :: Animator

-- on equip
task.spawn(AnimPlay.preload, animator, { SLASH })

-- on click
local track, cancel = AnimPlay.play(animator, SLASH, {
	fade = 0.05,
	priority = Enum.AnimationPriority.Action4,
	looped = false,
	duration = 0.42,                                  -- fit the clip to the combo window
	markers = {
		TrailOn = function() trail.Enabled = true end,
		TrailOff = function() trail.Enabled = false end,
		Hit = function()
			spawnSlashFX()
			-- (the local `track` below is not in scope inside its own initializer, so fetch it from the cache)
			AnimPlay.hitStop({ AnimPlay.track(animator, SLASH) }, 0.06)   -- rule of thumb: 0.04 to 0.1 s
		end,
	},
	onStopped = function() trail.Enabled = false end, -- also covers a cancel before TrailOff
})

-- on dodge pressed mid-swing
cancel(0.08)
```

Design notes:
- Fade-ins for attacks are short (0.05 s used for abilities, 0.06 s for weapon-part clips in the reference project). Longer fades make the first frames mushy and late.
- Fitting a clip to a window with `duration` changes its speed, which also moves its markers in time. If gameplay timing comes from data (as it should for the server), keep the data and the clip speed consistent. See [[Combat Combo Systems]].
- The client plays the clip and shows FX; the server decides the hit from its own data, not from this marker. See [[Markers and Events]].

---

## 3. Swapping the default Animate clips

The default `Animate` LocalScript reads its clip ids from child `StringValue` folders, each holding `Animation` objects. The documented pattern is a **server** script that edits them on `CharacterAdded` (they replicate to the owner) and stops the playing tracks so the new ids load on the next state change.

```lua
--!strict
-- ServerScriptService: replace default character animations for every player.
local Players = game:GetService("Players")

-- folder name inside Animate -> { Animation child name -> id }. Placeholder ids.
local IDS: { [string]: { [string]: string } } = {
	idle  = { Animation1 = "rbxassetid://0000000001", Animation2 = "rbxassetid://0000000002" },
	walk  = { WalkAnim = "rbxassetid://0000000003" },
	run   = { RunAnim = "rbxassetid://0000000004" },
	jump  = { JumpAnim = "rbxassetid://0000000005" },
	fall  = { FallAnim = "rbxassetid://0000000006" },
	climb = { ClimbAnim = "rbxassetid://0000000007" },
	swim  = { Swim = "rbxassetid://0000000008" },
	swimidle = { SwimIdle = "rbxassetid://0000000009" },
}

local function apply(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local animate = character:WaitForChild("Animate", 10)
	if not animate then return end
	for folderName, children in IDS do
		local folder = animate:FindFirstChild(folderName)
		if not folder then continue end                 -- R6 Animate has fewer folders
		for childName, id in children do
			local anim = folder:FindFirstChild(childName)
			if anim and anim:IsA("Animation") then anim.AnimationId = id end
		end
	end
	-- stop what is playing so Animate reloads with the new ids on its next state change
	for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(apply)
end)
```

Notes:
- `CharacterAppearanceLoaded` fires after the avatar's own animation package has been applied, so your ids are not overwritten by it. Using `CharacterAdded` can race with the package on some avatars.
- Idle `Animation1`/`Animation2` each have a `Weight` NumberValue child that sets how often each idle is picked.
- To change only some clips, leave the others out of the table.
- If you replace `Animate` entirely with your own script in `StarterCharacterScripts`, edit that instead. See [[The Default Animate Script]].

### Hiding the Tool hold
With a `Tool` equipped, Animate plays `toolnone` (right arm straight out). A weapon system that holds the weapon itself fades it to nearly zero instead of fighting it:

```lua
-- LocalScript in the character
local animator = (script.Parent :: Model):WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator
animator.AnimationPlayed:Connect(function(track: AnimationTrack)
	if track.Animation and track.Animation.Name == "ToolNoneAnim" then
		track:AdjustWeight(0.001, 0)    -- the reference project used 0.001 rather than stopping it
	end
end)
```
Matching by the `Animation` object's name works because Animate plays its own child objects. If your build swaps that Animation object, match by `AnimationId` instead.

---

## 4. Resolving a clip id with fallbacks

A pattern for projects that keep source `KeyframeSequence`s and publish over time:

```lua
--!strict
-- Resolution order: published id attribute -> Lua player (no id needed) -> Studio-only registration.
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

export type ClipSource =
	{ kind: "asset", id: string }
	| { kind: "lua", ks: KeyframeSequence }
	| { kind: "studio", id: string }
	| { kind: "missing" }

local function resolveClip(folder: Instance, name: string, luaPlayerAvailable: boolean): ClipSource
	local id = folder:GetAttribute(name .. "Id")
	if typeof(id) == "string" and id ~= "" then
		return { kind = "asset", id = id }                    -- a published id always wins
	end
	local ks = folder:FindFirstChild(name)
	if ks and ks:IsA("KeyframeSequence") then
		if luaPlayerAvailable then
			return { kind = "lua", ks = ks }                  -- works live, no publishing needed
		end
		if RunService:IsStudio() then
			-- Studio-only id (Docs: "cannot be used outside of Studio"). Never ship this path.
			warn(("[clips] %s/%s is unpublished: Studio-only playback"):format(folder.Name, name))
			return { kind = "studio", id = KeyframeSequenceProvider:RegisterKeyframeSequence(ks) }
		end
	end
	warn(("[clips] %s/%s has no playable source"):format(folder.Name, name))
	return { kind = "missing" }
end
```

Why the order matters:
- A published id wins so that publishing a clip never requires a code change.
- The Lua player path keeps Studio and live identical; the Studio-only path is a convenience that hides bugs, so it warns every time.
- In the reference project the Studio-only path shipped by accident in dozens of weapon kits; see [[Case Study - Abilities That Only Worked in Studio]].

**Upper-body variants.** For "cast while walking", publish a second copy of a move with hips and legs at weight 0 (named `<Clip>Upper`, attribute `<Clip>UpperId`). Resolve the upper variant first when the character is moving, and fall back to the full clip only deliberately: a missing upper id should be a warning, because the full-body clip stops the legs.

---

## 5. Listening without touching call sites

Systems like screen shake, VFX "juice" or a flourish canceller often need to know when any clip plays. Use `Animator.AnimationPlayed` (fires for every `Play` on that Animator's tracks, Docs) instead of adding hooks to every call site:

```lua
animator.AnimationPlayed:Connect(function(track: AnimationTrack)
	-- cancel an equip flourish when anything at Action2 or above starts
	if flourishTrack and track ~= flourishTrack
		and AnimPlay.rank(track.Priority) >= AnimPlay.rank(Enum.AnimationPriority.Action2) then
		flourishTrack:Stop(0.1)
	end
end)
```

Beware duplicates: if a full-body clip and its upper-body copy can both play, listeners that react to markers will fire twice. Tag copies (an attribute on the `Animation`, for example `IsUpperCopy = true`) and skip them.

---

## Common mistakes
- `animator:LoadAnimation(anim):Play()` per click (new track each time; 256-track warning).
- Setting `Priority` after `Play`.
- Computing speed from `Length` before the clip has loaded (speed 0, frozen clip).
- Connecting `GetMarkerReachedSignal` on every play without disconnecting.
- Doing cleanup on `Stopped` while the track is still visibly fading; use `Ended`.
- Calling `Play` every frame "to be sure" (restarts the clip).
- Setting `TimePosition` before `Play`.
- Hit-stop that restores a speed of 0 when two hits overlap.

## See also
[[AnimationTrack Reference]] · [[Animator Deep Dive]] · [[Markers and Events]] · [[Playback, Priorities and Blending]] · [[The Default Animate Script]] · [[Publishing Animations]] · [[Snippets - Animation Controller Module]] · [[Hit Reactions Stagger and Hit-Stop]]

## Nuances and edge cases

1. **Where you load decides who sees it.** For a player character, tracks loaded and played on the owning client through the character's `Animator` replicate to other players; tracks played from a LocalScript on an NPC or on another player's character are seen only by that client (rule of thumb widely confirmed on the DevForum; the Animator reference page does not spell it out, so treat it as unverified against docs). This is the single biggest source of "it works for me but my friend sees nothing" reports.
2. **Server-played clips on player characters.** They replicate, but they arrive with network latency on the owner's own screen, so an attack the server starts feels 80 to 200 ms late to the attacker. Play on the owner's client for feel, and let the server only validate.
3. **Clip loading is asynchronous.** `Length` is 0 until the asset is fetched. On a cold join over mobile data, the first swing can play nothing for several hundred milliseconds. Preload with `ContentProvider:PreloadAsync` on the `Animation` objects during the loading screen, and fit `duration` only after `Length > 0`.
4. **Scale of the track cache.** One cached track per (animator, id) is cheap for one character. A 50-player server where every client caches 40 clips for every visible character means each client holds about 2,000 tracks. That is still fine, but caching tracks for characters that have left the stream radius is a slow leak; clear on `Destroying` (as the module does) and on streaming out.
5. **Speed and fade interact.** `AdjustSpeed(2)` does not halve the fade time passed to `Play`; fades are in real seconds. A 0.1 s fade on a clip sped up to a 0.25 s duration blends away 40 percent of the motion. Shorten fades proportionally for fast clips.
6. **`Ended` vs `Stopped`.** Roblox docs (as of October 2026) mark `Stopped` as deprecated and describe `Ended` as firing once the animation has finished affecting the world, after the fade. New code should use `Ended` for cleanup and only keep `Stopped` where old code depends on it.
7. **Default fade times.** Roblox docs (as of October 2026): `Play`, `Stop` and `AdjustWeight` all default `fadeTime` to 0.1 s. A bare `track:Stop()` on a looping idle is therefore never instant; pass `0` when you need a hard cut, for example on death.
8. **Mobile frame drops and markers.** On a phone dropping to 20 FPS, one frame spans 50 ms; two markers 30 ms apart can fire in the same frame, in order. Handlers must not assume a frame passes between them.
9. **Animation throttling.** Roblox docs list `Animator.EvaluationThrottled` as a read-only flag; distant or off-screen characters can be evaluated less often. Do not read limb positions from far characters for gameplay; read them only from the server's data.

## Common mistakes in production

1. **Loading on the server and the client for the same character.** Symptom: double-speed or jittery blends, clips that stop and restart. Fix: pick one owner per character; for players, the client.
2. **Playing other players' attacks from your own LocalScript and expecting others to see them.** Symptom: only you see the effect. Fix: replicate a "play" event and let each client play it, or let the owner play it.
3. **Using a stale `Animator` after respawn.** Symptom: no animation after the first death, no errors. Fix: re-resolve the animator on `CharacterAdded` and clear the cache.
4. **Fade on death.** Symptom: the ragdoll starts with the last attack still blending out, limbs snap. Fix: `Stop(0)` all tracks before enabling ragdoll.
5. **Preloading by id string only.** Symptom: preload completes but the first play still hitches. Fix: preload the `Animation` instances you will actually load.
6. **Fitting `duration` to a server window that changed.** Symptom: visuals and hits drift apart after a balance patch. Fix: derive both from one config value.

## Related decisions

- [[Client-Server Model]]: the ownership model that makes client-played character clips replicate.
- [[Network Ownership]]: why the owner's client is the right place to drive its own character.
- [[Melee Combat System End to End]]: a full build that uses this play path with server validation.
- [[Client Prediction and Reconciliation for Combat]]: hiding latency when the client plays first and the server confirms.
- [[Case Study - Fast Join and Deferred Loading]]: where preloading clips fits in a fast join.
- [[Hunting Memory Leaks Step by Step]]: finding track caches that never clear.
- [[Input Responsiveness Buffering and Coyote Time]]: buffering presses so clips start on the first eligible frame.
- [[Mobile and Low-End Optimization]]: frame rates under which marker timing gets coarse.

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Characters and Animation]] · [[Animation Objects]] · [[Troubleshooting Table]] · [[Lua Keyframe Player]] · Input Buffering · Hitboxes and Hit Detection · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animator - Engine Reference Card]] · [[Snippets - Lua Keyframe Player Core]] · [[Snippets - Enemy Client Animator]] · [[Replication and Ownership]] · [[Combat Animation Craft]] · [[Custom Locomotion Controller Design]] · [[Snippets - Ragdoll]] · [[Debugging Animation Problems]] · [[Ability Kits Architecture]]
<!-- related:end -->
