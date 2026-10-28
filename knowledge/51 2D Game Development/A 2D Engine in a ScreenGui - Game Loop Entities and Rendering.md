---
tags: [2d, screengui, game-loop, fixed-timestep, entities, rendering, object-pooling, performance, luau]
---
# A 2D Engine in a ScreenGui - Game Loop Entities and Rendering

If you chose the GUI route in [[Choosing GUI 2D or Locked-Camera 2.5D]], you are building a small engine. This note is the skeleton of that engine: a fixed-timestep loop with interpolation, entities stored as plain data, a renderer that maps data onto pooled `ImageLabel`s, a camera, layers, culling and pixel snapping. Collision and movement are in [[2D Collision Physics and Platformer Movement]], sprite animation in [[Sprite Sheets and Frame Animation with ImageRectOffset]], levels and parallax in [[Tilemaps Cameras and Parallax for 2D Levels]].

The single idea behind everything here: **the simulation never touches Instances, and the renderer never makes gameplay decisions.** Data in, pixels out.

Source labels: **Roblox docs (as of October 2026)**, **rule of thumb**. I have not benchmarked these numbers on a fixed device set, so frame budgets below are rules of thumb; measure your own game with [[MicroProfiler Guide]].

---

## 1. Why not just move Frames around?

The naive GUI game puts gameplay into the GUI objects: a `Frame` is the player, its `Position` is the player's position, collision reads `AbsolutePosition`. It works for a prototype and then fails in predictable ways:

| Naive approach | What goes wrong |
|---|---|
| Position stored in `Frame.Position` | Reading and writing Instance properties is far slower than table fields; logic is tied to layout; `AbsolutePosition` depends on screen size, so physics differs per device |
| Movement scaled by frame `dt` with no fixed step | Jump height and collision results change with frame rate; a 30 fps phone tunnels through thin floors that a 120 fps PC never misses |
| A new `ImageLabel` per bullet, destroyed on hit | Instance churn, garbage, frame spikes, and `Destroy` work on the main thread |
| Every object updated every frame, even off screen | Cost grows with level size rather than screen content |
| Logic in GUI events (`Touched` does not exist; people poll overlap of `AbsolutePosition`) | Precision depends on the screen, and nothing is testable |

Moving the truth into tables fixes all five at once: the simulation runs at a fixed rate in logical pixels, the renderer is free to skip, pool and cull, and the whole simulation can run headless in a test or on the server (useful for replay validation in [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]).

---

## 2. The fixed-timestep loop

Roblox gives you per-frame events, not a fixed tick. Roblox docs (as of October 2026): `RunService.PreRender` "fires every frame, prior to the frame being rendered" and passes `deltaTimeRender`; `RenderStepped` is deprecated and superseded by `PreRender`. For a GUI game, `PreRender` is the right hook: input for the frame has been processed, and whatever you write to the GUI shows on this frame. The order of these events is covered in [[Frame Order and RunService Timing]].

A fixed timestep means the simulation always advances by the same `dt` (for example 1/60 s), as many times as needed to catch up with real time. Leftover time carries over in an **accumulator**, and the renderer draws an **interpolated** state between the previous and the current step so motion stays smooth at any frame rate.

```lua
--!strict
-- FixedLoop: runs step(dt) at a fixed rate and render(alpha) once per frame.
local RunService = game:GetService("RunService")

local FixedLoop = {}

export type Config = {
	stepHz: number, -- simulation rate, e.g. 60
	maxStepsPerFrame: number, -- spiral-of-death guard, e.g. 5
	step: (dt: number) -> (),
	render: (alpha: number) -> (),
}

export type Handle = {
	stop: () -> (),
	setPaused: (paused: boolean) -> (),
}

function FixedLoop.start(config: Config): Handle
	local fixedDt = 1 / config.stepHz
	local accumulator = 0
	local paused = false

	local connection = RunService.PreRender:Connect(function(frameDt: number)
		if paused then
			config.render(1)
			return
		end
		-- Clamp huge frames (window unfocused, a hitch) so we never try to
		-- simulate seconds of game in one frame.
		accumulator += math.min(frameDt, fixedDt * config.maxStepsPerFrame)

		local steps = 0
		while accumulator >= fixedDt and steps < config.maxStepsPerFrame do
			config.step(fixedDt)
			accumulator -= fixedDt
			steps += 1
		end
		if steps >= config.maxStepsPerFrame then
			-- We are falling behind: drop the backlog instead of compounding it.
			accumulator = math.min(accumulator, fixedDt)
		end

		config.render(accumulator / fixedDt)
	end)

	return {
		stop = function()
			connection:Disconnect()
		end,
		setPaused = function(p: boolean)
			paused = p
			accumulator = 0
		end,
	}
end

return FixedLoop
```

### Choosing the step rate

| Rate | Use when | Cost and caveat |
|---|---|---|
| 60 Hz | Default for platformers, shmups, most action | 1 step per frame at 60 fps, 2 per frame on a 30 fps phone |
| 120 Hz | Very fast objects or thin collision; precise fighting-game timing | Double the simulation cost; on a 30 fps phone that is 4 steps per frame |
| 30 Hz | Slow puzzle or tactics games, or when the simulation is heavy | Visible input latency of up to 33 ms; interpolation becomes essential |

Rule of thumb: keep a single step under about 1 ms on a mid phone, so even 4 catch-up steps fit inside a 33 ms frame with room for rendering.

### Nuances of the loop

- **The clamp changes game time.** When the window loses focus or the device hitches, the clamp throws away time, so game time runs slower than wall time for a moment. That is what you want for gameplay; it is wrong for anything measured against the server clock (a speedrun timer). Keep timers that matter in step counts (frames simulated), and let the server compare them against its own elapsed time with a tolerance.
- **Pause must reset the accumulator.** Otherwise unpausing replays the leftover fraction and a step fires instantly; with large leftovers it fires several.
- **Interpolation needs previous state.** Each entity stores `prevX, prevY` at the start of every step. Teleports (respawn, door transitions) must set both previous and current, or the renderer draws a streak across the screen for one frame.
- **Do not yield inside `step`.** No `task.wait`, no remote calls with `InvokeServer`. A yield inside an event handler does not pause the loop: the next frame calls `step` again while the first is still suspended, and state gets corrupted.
- **Input is sampled per frame, consumed per step.** If a jump press arrives and two steps run this frame, only the first step should see "pressed this step". Store presses as edges with a counter or a buffer window ([[Input Responsiveness Buffering and Coyote Time]]).

---

## 3. Coordinates

Pick one convention and never mix it:

- **World units are logical pixels**, matching the logical resolution of the playfield (for example 320 x 180 visible).
- **X grows right, Y grows down**, the same as GUI offsets. Fighting the GUI convention with Y-up math means a sign flip in every render call and every collision normal, and somebody will forget one.
- **Positions are the top-left of the entity's box**, or the bottom-centre for characters (feet). Bottom-centre is friendlier for platformers (standing on a floor is `y = floorTop`), top-left is simpler for tiles. Whichever you choose, document it in the entity type.
- **The camera is a world position** (top-left of the view). Screen position of an entity is `world - camera`.

**Pixel snapping.** For pixel art, the rendered position must be a whole logical pixel, otherwise sprites shimmer as subpixel positions round differently from frame to frame. Snap **at render time only** (`math.round(x - camX)`), never in the simulation. Snapping the simulation breaks slow movement: an entity moving 0.4 pixels per step would never move at all. Snap the **camera** first and derive entity screen positions from the snapped camera; snapping entities and camera independently makes a followed player jitter one pixel back and forth.

---

## 4. Entities as data

Most GUI 2D games do not need a full [[Entity Component Systems]] library. A typed record per entity plus a few arrays per kind is enough, fast, and easy to read.

```lua
--!strict
-- World: plain-data entities with stable ids and O(1) removal.
local World = {}

export type Entity = {
	id: number,
	kind: string, -- "player", "enemy", "bullet", "pickup"...
	x: number, -- left edge, logical pixels
	y: number, -- top edge, logical pixels
	prevX: number,
	prevY: number,
	vx: number,
	vy: number,
	w: number,
	h: number,
	sprite: string, -- key into the sprite registry
	frame: number, -- current animation frame (1-based)
	flipX: boolean,
	layer: number, -- which render layer
	alive: boolean,
}

export type WorldState = {
	entities: { Entity },
	byId: { [number]: Entity },
	nextId: number,
}

function World.new(): WorldState
	return { entities = {}, byId = {}, nextId = 1 }
end

function World.spawn(world: WorldState, kind: string, x: number, y: number, w: number, h: number, sprite: string): Entity
	local e: Entity = {
		id = world.nextId,
		kind = kind,
		x = x,
		y = y,
		prevX = x,
		prevY = y,
		vx = 0,
		vy = 0,
		w = w,
		h = h,
		sprite = sprite,
		frame = 1,
		flipX = false,
		layer = 2,
		alive = true,
	}
	world.nextId += 1
	table.insert(world.entities, e)
	world.byId[e.id] = e
	return e
end

-- Mark dead during the step; sweep once at the end of the step.
function World.sweep(world: WorldState)
	local list = world.entities
	local i = 1
	while i <= #list do
		local e = list[i]
		if e.alive then
			i += 1
		else
			world.byId[e.id] = nil
			list[i] = list[#list] -- swap-remove: order is not preserved
			list[#list] = nil
		end
	end
end

function World.teleport(e: Entity, x: number, y: number)
	e.x, e.y = x, y
	e.prevX, e.prevY = x, y -- no interpolation streak
end

return World
```

Design notes:

- **Kill, then sweep.** Removing from an array while iterating it skips elements. Mark `alive = false` during the step and sweep once at the end.
- **Swap-remove reorders.** Fine for simulation; not fine if draw order depends on array order. Draw order comes from `layer` and an explicit sort key, not from the array.
- **Ids, not references, across systems.** A homing missile stores its target id and looks it up through `byId` each step, so a dead target is simply `nil` instead of a stale table that still "exists".
- **Strings as kinds are fine** at this scale. If profiling shows kind checks are hot, switch to numeric constants. For simulation-heavy modules, `--!native` is available (see [[Luau Performance and Native Codegen]]), but only after measuring.
- **Broad phase.** With more than a few dozen colliders, testing every pair is wasteful. A uniform grid (spatial hash) with a cell size about twice the typical entity size is the usual answer; the math is in [[Intersection and Collision Math]] and the tile-specific version in [[2D Collision Physics and Platformer Movement]].

---

## 5. Rendering: pooled views with dirty checks

The renderer owns every GuiObject. For each visible entity it borrows an `ImageLabel` from a pool, writes only the properties that changed, and returns labels for entities that left the screen or died.

Why dirty checks matter: every property write on an Instance crosses from Luau into the engine and may invalidate layout for that object. Writing `Position` 500 times a frame with the same value still costs. Cache the last written values in the view record and compare first (rule of thumb: in GUI-heavy games, skipping redundant writes is often the largest single win after pooling).

```lua
--!strict
-- Renderer: maps entities to pooled ImageLabels in layered frames.
local World = require(script.Parent.World)
local Sprites = require(script.Parent.Sprites) -- see the sprite sheet note

type Entity = World.Entity
type WorldState = World.WorldState

type View = {
	label: ImageLabel,
	lastX: number,
	lastY: number,
	lastSprite: string,
	lastFrame: number,
	lastFlip: boolean,
	lastLayer: number,
}

export type RendererState = {
	layers: { Frame },
	views: { [number]: View }, -- entity id -> view
	pool: { ImageLabel },
	viewW: number,
	viewH: number,
	camX: number,
	camY: number,
}

local Renderer = {}

local function makeLabel(): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Visible = false
	return label
end

function Renderer.new(world: Frame, viewW: number, viewH: number, layerCount: number, prewarm: number): RendererState
	local layers: { Frame } = {}
	for i = 1, layerCount do
		local layer = Instance.new("Frame")
		layer.Name = "Layer" .. i
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundTransparency = 1
		layer.ZIndex = i -- with ZIndexBehavior.Sibling, layer order is ZIndex order
		layer.Parent = world
		layers[i] = layer
	end
	local pool: { ImageLabel } = {}
	for _ = 1, prewarm do
		local label = makeLabel()
		label.Parent = layers[1]
		table.insert(pool, label)
	end
	return { layers = layers, views = {}, pool = pool, viewW = viewW, viewH = viewH, camX = 0, camY = 0 }
end

local function acquire(r: RendererState): View
	local label = table.remove(r.pool) or makeLabel()
	return {
		label = label,
		lastX = math.huge,
		lastY = math.huge,
		lastSprite = "",
		lastFrame = -1,
		lastFlip = false,
		lastLayer = -1,
	}
end

local function release(r: RendererState, view: View)
	view.label.Visible = false
	table.insert(r.pool, view.label)
end

function Renderer.draw(r: RendererState, world: WorldState, alpha: number)
	local camX = math.round(r.camX)
	local camY = math.round(r.camY)
	local seen: { [number]: boolean } = {}

	for _, e in world.entities do
		if not e.alive then
			continue
		end
		local ix = e.prevX + (e.x - e.prevX) * alpha
		local iy = e.prevY + (e.y - e.prevY) * alpha
		local sx = math.round(ix) - camX
		local sy = math.round(iy) - camY

		-- Cull with a margin so sprites do not pop at the edge.
		if sx + e.w < -8 or sy + e.h < -8 or sx > r.viewW + 8 or sy > r.viewH + 8 then
			continue
		end
		seen[e.id] = true

		local view = r.views[e.id]
		if not view then
			view = acquire(r)
			r.views[e.id] = view
		end
		local label = view.label

		if view.lastLayer ~= e.layer then
			label.Parent = r.layers[e.layer]
			view.lastLayer = e.layer
		end
		if view.lastSprite ~= e.sprite or view.lastFrame ~= e.frame or view.lastFlip ~= e.flipX then
			Sprites.apply(label, e.sprite, e.frame, e.flipX)
			label.Size = UDim2.fromOffset(e.w, e.h)
			view.lastSprite, view.lastFrame, view.lastFlip = e.sprite, e.frame, e.flipX
		end
		if view.lastX ~= sx or view.lastY ~= sy then
			label.Position = UDim2.fromOffset(sx, sy)
			view.lastX, view.lastY = sx, sy
		end
		if not label.Visible then
			label.Visible = true
		end
	end

	-- Return views for entities that died or left the screen.
	for id, view in r.views do
		if not seen[id] then
			release(r, view)
			r.views[id] = nil
		end
	end
end

return Renderer
```

Details worth knowing:

- **Layers are Frames.** With `ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling`, children draw above their parent and siblings are ordered by `ZIndex`. A fixed set of layer frames (background, tiles, entities, effects, foreground) gives stable ordering without touching `ZIndex` per sprite. Changing a label's `Parent` is more expensive than changing a property, so it is also dirty-checked.
- **Y-sorting** (top-down games where lower characters draw in front) needs a per-sprite `ZIndex` derived from `y`. Only write it when the integer value changes, and quantise it (for example `y // 4`) so small movements do not rewrite it constantly.
- **Hide, do not unparent.** Pooled labels stay parented and get `Visible = false`. Re-parenting a whole pool every frame costs more than visibility toggles.
- **Prewarm the pool** at level load with the expected peak count (bullets in the busiest wave plus margin), so the first boss phase does not allocate 200 instances in one frame.
- **Size in logical pixels.** The world frame has a `UIScale` (see the setup in [[Choosing GUI 2D or Locked-Camera 2.5D]]); every label uses offsets in logical pixels. Never mix scale-based sizes into the world.
- **Images must be loaded before they are needed.** The first time a label shows an asset that has not downloaded, it is blank for some frames. Preload sprite sheets during a loading screen with `ContentProvider:PreloadAsync`. Roblox docs (as of October 2026) note that `ImageLabel.IsLoaded` tells you when the image has loaded, and that "Images declined by moderation will never load", which is the failure mode to watch after uploading new sheets.

### How many objects can you draw?

There is no documented number; it depends on device, image sizes and how many properties change per frame. Rules of thumb that hold up across GUI-heavy games:

| Visible GuiObjects changing every frame | Typical outcome on a mid phone (rule of thumb) |
|---|---|
| Under 200 | Comfortable |
| 200 to 600 | Fine with pooling and dirty checks; watch spikes |
| Over 1,000 | Risky; reduce with tile chunks, static layers, and fewer moving parts |

Static content (tiles that do not move relative to each other) should not be 1,000 separate labels moving with the camera. Group static tiles into chunk frames and move the chunk, which is one write instead of hundreds. Better still, bake a chunk into one image or draw it into an `EditableImage` ([[EditableImage for Pixel Buffers and Procedural 2D]]). The tile approach is in [[Tilemaps Cameras and Parallax for 2D Levels]].

---

## 6. The camera

The camera is a position plus rules. Minimal useful behaviour for a side-scroller:

- **Dead zone**: the camera does not move while the player is inside a central box.
- **Look-ahead**: offset the target in the facing direction, eased so turning around does not snap.
- **Vertical lock until landing**: do not follow every jump; re-centre vertically when the player lands on a new height. This is the single biggest comfort fix for platformers, and it reduces motion for sensitive players ([[Motion Sensitivity and Camera Comfort]]).
- **Clamp to level bounds** so the view never shows outside the map.
- **Update the camera in render, not in step**, using the interpolated player position. Updating it in step makes it move in 60 Hz jumps on a 120 Hz screen.

Smooth following uses frame-rate independent damping (`1 - math.exp(-k * dt)`), never a fixed lerp factor per frame; the math is in [[Springs Damping and Smoothing]].

---

## 7. Putting it together

```lua
--!strict
-- Client bootstrap for the GUI 2D game.
local FixedLoop = require(script.Parent.FixedLoop)
local World = require(script.Parent.World)
local Renderer = require(script.Parent.Renderer)
-- Your gameplay systems (movement, collision, enemies). The platformer
-- controller in the collision note is one of them.
local Gameplay = require(script.Parent.Gameplay)

local VIEW_W, VIEW_H = 320, 180

local function boot(worldFrame: Frame)
	local world = World.new()
	local renderer = Renderer.new(worldFrame, VIEW_W, VIEW_H, 5, 64)
	local player = World.spawn(world, "player", 32, 100, 12, 16, "hero")
	player.layer = 3

	local function step(dt: number)
		for _, e in world.entities do
			e.prevX, e.prevY = e.x, e.y
		end
		Gameplay.step(world, dt)
		World.sweep(world)
	end

	local function render(alpha: number)
		local px = player.prevX + (player.x - player.prevX) * alpha
		renderer.camX = math.max(0, px - VIEW_W * 0.4)
		Renderer.draw(renderer, world, alpha)
	end

	return FixedLoop.start({ stepHz = 60, maxStepsPerFrame = 5, step = step, render = render })
end

return boot
```

Notice what the step function does first: copy current positions into previous ones. Every entity, every step, before anything moves. Forgetting a newly spawned entity is harmless because `spawn` sets both; forgetting this line for everyone makes interpolation draw the wrong thing.

---

## 8. Lifecycle and cleanup

- **One owner.** The loop handle, renderer and world live in one session object. Leaving the minigame calls `stop()`, destroys the layer frames (which destroys every pooled label) and drops the tables. See [[Memory Budgets and Leaks]] for the patterns that leak: connections never disconnected, views held in a module-level table after the session ends.
- **Respawn and `ResetOnSpawn`.** A `ScreenGui` with `ResetOnSpawn = true` is destroyed and recreated when the character respawns, silently deleting your playfield mid-game. GUI 2D games set it to `false`.
- **Focus loss.** On mobile, backgrounding the app pauses rendering; the clamp in the loop handles the resume, but you may also want to auto-pause the game itself (`UserInputService.WindowFocusReleased`).
- **Testing.** Because `step` is pure data, a test can create a world, call `step(1/60)` 600 times with scripted input, and assert the player reached a position. This is the cheapest regression test in game development; use it ([[Testing Strategies and Frameworks]]).

---

## 9. Common mistakes

- **Game logic reading `AbsolutePosition`.** Results differ per screen. Symptom: a bug only some phones can reproduce.
- **Variable-step physics.** Symptom: jump height or speed differs between a 60 fps PC and a 30 fps phone; players on fast machines report "floaty" or "too fast".
- **No clamp on frame time.** Symptom: after alt-tabbing back, the player has fallen through the floor or enemies teleport.
- **Snapping the simulation to whole pixels.** Symptom: slow walkers and slow platforms never move.
- **Camera snapped separately from sprites.** Symptom: the followed character jitters by one pixel.
- **Writing every property every frame.** Symptom: high script time in the MicroProfiler with few entities.
- **Creating labels on demand without prewarming.** Symptom: a spike the first time a big wave or explosion happens, then smooth afterwards.
- **`ResetOnSpawn` left on.** Symptom: the game vanishes when the (invisible, irrelevant) 3D character dies or resets.

---

## 10. Checklist

- [ ] Simulation state lives in tables; no gameplay reads Instance properties.
- [ ] Fixed timestep with accumulator, frame clamp, max steps per frame, and interpolation alpha.
- [ ] `prevX/prevY` copied at the start of every step; teleports set both.
- [ ] Logical-pixel coordinates, Y down, documented anchor (top-left or feet).
- [ ] Render-time snapping only; camera snapped first.
- [ ] Pooled, prewarmed `ImageLabel`s; hidden not destroyed; dirty-checked writes.
- [ ] Off-screen culling with a margin; static tiles grouped into chunks.
- [ ] Layer frames with `ZIndexBehavior.Sibling`; per-sprite ZIndex only for Y-sorting, quantised.
- [ ] Sprite sheets preloaded; moderation failures detected (`IsLoaded` stays false).
- [ ] `ResetOnSpawn = false`; session object owns and cleans everything.
- [ ] A headless test steps the simulation and asserts outcomes.

## See also

- [[2D Game Development Start Here]]
- [[Sprite Sheets and Frame Animation with ImageRectOffset]]
- [[2D Collision Physics and Platformer Movement]]
- [[Tilemaps Cameras and Parallax for 2D Levels]]
- [[Frame Order and RunService Timing]]
- [[Script Performance]]
- [[Rendering Performance]]
- [[Virtualized Lists and Large Inventories]] (the same pooling idea for menus)
- [[ScreenGui Fundamentals]]

## Connected notes
<!-- auto-links:start -->
[[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] · [[Object Pooling]] · [[Links - Containers]] · [[Frame Budget]] · [[Debugging UI Layout and Input]]
<!-- auto-links:end -->
