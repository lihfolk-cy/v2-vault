---
tags: [2d, 2.5d, tilemap, level-design, camera, parallax, chunks, tiled, rendering, luau, type/guide, area/2d]
---
# Tilemaps Cameras and Parallax for 2D Levels

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Collision derived from visual tiles. Symptom: an artist adds a decorative tile and players get stuck on it.
> - Avoid: One ImageLabel per tile moved every frame.
> - Avoid: Chunks positioned from an unsnapped camera.
> - Collision layer separate from visual layers; objects as a separate list.
> - Levels converted at build time to Luau data; versioned; tile ids append-only.
> - Tiled GID flags cleared; flipped variants pre-baked.
>
> Cost: TL;DR ~150 tok · whole note ~7.2k tok. Read more: ## 3. Rendering tiles in a GUI: three strategies · ## 4. Cameras that frame the level · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Most 2D levels are grids. A [[Tilemaps|tilemap]] stores a level as a few arrays of small numbers, which makes it cheap to save, cheap to collide against, cheap to send to the server, and easy to author in a dedicated editor. The hard parts are elsewhere: drawing thousands of tiles without thousands of property writes, hiding seams between tiles, a camera that frames the level well instead of just following the player, and [[parallax]] backgrounds that stay crisp. This note covers all four for the GUI route, and how the same data builds a level in the 2.5D route.

It builds on [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] (loop, renderer, coordinates) and uses the `TileMap` shape from [[2D Collision Physics and Platformer Movement]], so collision and drawing read the same data. Tile art and atlas padding come from [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]; baking tiles into a single texture uses [[EditableImage for Pixel Buffers and Procedural 2D]]. For the craft of laying out the level itself, see [[Obby and Platforming Level Design]] and [[Level Design for Roblox]].

Source labels: **Roblox docs (as of October 2026)**, **Tiled documentation (as of October 2026)**, **rule of thumb**.

---

## 1. The data model

A level is a set of **layers**, each a grid of tile ids, plus a list of **objects** (spawns, enemies, doors, triggers) placed by position rather than by cell.

| Layer | Contents | Who reads it |
|---|---|---|
| Collision | 0 empty, 1 solid, 2 one-way, 3 hazard ... | Simulation only; never drawn |
| Background tiles | Visual ids into a tileset atlas | Renderer |
| Foreground tiles | Visual ids drawn in front of entities | Renderer |
| Objects | `{ kind, x, y, w, h, properties }` | Level loader spawns entities |

Keeping collision separate from visuals is the single most useful decision here. Artists can redraw a wall with ten decorative variants without touching gameplay, a decorative tile can never accidentally become solid, and the server (which needs collision for validation, see [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]) never loads visual data.

### Storage size

A 300 by 40 tile level is 12,000 cells per layer. As a Luau array of numbers that is roughly 16 bytes per element in memory (rule of thumb for Luau array slots), so about 190 KB per layer: fine. As a `buffer` of `u16` it is 24 KB. For saving in a `ModuleScript`, sending to clients or keeping many levels resident, the buffer or a compact string is better; for a dozen hand-made levels, plain arrays in a module are simpler and perfectly fast. Do not optimise this until you have a level count that matters.

A compact authoring-friendly format for small levels is one string per row:

```lua
--!strict
-- A tiny hand-written level. Legend: "." empty, "#" solid, "=" one-way, "^" hazard, "P" player spawn.
return {
	tileSize = 16,
	rows = {
		"........................",
		"........==......#####...",
		"..P..............#......",
		"#######....^^^...#....##",
		"########################",
	},
}
```

It is readable in a diff and editable without tools. Past about 50 by 20 it stops being pleasant; move to an editor.

---

## 2. Authoring with an external editor

Roblox has no tile editor. The two common choices are Tiled and LDtk; both export JSON, and both are free. The workflow that holds up:

1. Author levels in the editor with a collision layer, one or more visual layers, and an object layer.
2. Export JSON.
3. A build step (a script in your Rojo pipeline, or a Studio plugin, see [[Data and Config Pipeline - Spreadsheets to Game]]) converts the JSON into a Luau `ModuleScript` or a buffer string. Do not ship the raw editor JSON and parse it at runtime; it contains data you do not need and fields that change between editor versions.

### Tiled global ids and flip flags

In Tiled's format each cell holds a **global tile id (GID)**. Tiled documentation (as of October 2026): the highest bits store flips, `0x80000000` horizontal, `0x40000000` vertical, `0x20000000` diagonal, and `0x10000000` is used for hexagonal rotation. Clear all four before using the id, even in non-hexagonal maps. A GID of 0 means empty. Each tileset has a `firstgid`; the tileset owning a GID is the one with the highest `firstgid` not greater than it, and the local id is `gid - firstgid`.

```lua
--!strict
-- Decode a Tiled GID into tileset index, local id and flip flags.
local FLIP_H = 0x80000000
local FLIP_V = 0x40000000
local FLIP_D = 0x20000000
local ALL_FLAGS = 0xF0000000

export type TileRef = { tileset: number, localId: number, flipH: boolean, flipV: boolean, flipD: boolean }

local function decodeGid(gid: number, firstGids: { number }): TileRef?
	local id = bit32.band(gid, bit32.bnot(ALL_FLAGS))
	if id == 0 then
		return nil
	end
	-- firstGids must be sorted ascending; pick the last one that is <= id.
	local tileset = 1
	for i, first in firstGids do
		if first <= id then
			tileset = i
		else
			break
		end
	end
	return {
		tileset = tileset,
		localId = id - firstGids[tileset],
		flipH = bit32.btest(gid, FLIP_H),
		flipV = bit32.btest(gid, FLIP_V),
		flipD = bit32.btest(gid, FLIP_D),
	}
end

return decodeGid
```

GUI images can mirror (negative size tricks, or flipped rectangles as shown in [[Sprite Sheets and Frame Animation with ImageRectOffset]]) but a diagonal flip is a 90 degree rotation plus mirror. `ImageLabel.Rotation` exists, but rotating a pixel-art tile in the GUI can introduce resampling at the edges. The robust answer is to bake flipped and rotated variants into the atlas at build time and map each `(localId, flags)` pair to a pre-baked cell. Tell artists which flips are allowed.

### Tile ids are a contract

Once levels are authored, the tileset's layout is frozen: inserting a column in the middle of the atlas renumbers every tile after it and silently corrupts every level. Only append. Keep a version number in each exported level and fail loudly when a level refers to an atlas version that does not exist.

---

## 3. Rendering tiles in a GUI: three strategies

At 16 pixel tiles and a 320 by 180 logical view, the screen shows 20 by 11.25 tiles, so up to 21 by 13 = 273 tiles are partly visible on each layer. Two visual layers is about 550 tile labels on screen. That is in the comfortable to moderate range from the engine note's rule of thumb table, but only if they are not rewritten every frame.

| Strategy | How | Per-frame work while scrolling | Memory and instance count | Good for |
|---|---|---|---|---|
| **Chunk frames** | Group tiles into chunks of 16 by 16; each chunk is a Frame of ImageLabels at fixed offsets; scroll by moving the chunk Frames | One `Position` write per visible chunk (usually 2 to 6) | 256 labels per chunk per layer; only nearby chunks built | The default for most GUI platformers |
| **Visible window pool** | Exactly enough labels to cover the view plus one tile; when the camera crosses a tile boundary, reassign images | Rewrite one row or column of tiles per boundary crossing; move the whole window by the sub-tile remainder | About 300 labels per layer, constant | Huge or endless levels; procedural worlds |
| **Baked chunks** | Draw each chunk into one image once (an `EditableImage`, or a pre-rendered uploaded image) | One write per chunk, like chunk frames | One ImageLabel per chunk; image memory instead of instances | Static detailed backgrounds; very large tile counts |

Rules of thumb for picking: chunk frames first. Move to baked chunks when the instance count or memory of labels becomes the problem (for example four visual layers of dense detail). Move to a window pool when the level is unbounded. Baked chunks need the EditableImage permission setting and live under a client memory budget that can make creation fail, as described in [[EditableImage for Pixel Buffers and Procedural 2D]]; always keep the chunk frame path as a fallback.

### A chunk renderer

```lua
--!strict
-- TileChunks: builds chunk frames of tiles near the camera, moves them, unloads far ones.
local TileChunks = {}

local CHUNK = 16 -- tiles per chunk side

export type Tileset = {
	image: string, -- rbxassetid://0000000000
	tilePx: number, -- source pixels per tile in the atlas, e.g. 16
	columns: number, -- tiles per atlas row
	padding: number, -- extruded border around each cell in the atlas, e.g. 1
}

export type Layer = {
	width: number,
	height: number,
	tiles: { number }, -- 0 = empty, otherwise 1-based visual id; row-major
}

export type State = {
	parent: Frame,
	layer: Layer,
	tileset: Tileset,
	tileSize: number, -- logical pixels per tile on screen
	chunks: { [number]: Frame }, -- key = cy * 65536 + cx
	lastPos: { [number]: Vector2 },
}

function TileChunks.new(parent: Frame, layer: Layer, tileset: Tileset, tileSize: number): State
	return { parent = parent, layer = layer, tileset = tileset, tileSize = tileSize, chunks = {}, lastPos = {} }
end

local function buildChunk(s: State, cx: number, cy: number): Frame
	local f = Instance.new("Frame")
	f.Name = `Chunk_{cx}_{cy}`
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(CHUNK * s.tileSize, CHUNK * s.tileSize)
	local ts = s.tileset
	local cell = ts.tilePx + ts.padding * 2
	for ty = cy * CHUNK, math.min((cy + 1) * CHUNK, s.layer.height) - 1 do
		for tx = cx * CHUNK, math.min((cx + 1) * CHUNK, s.layer.width) - 1 do
			local id = s.layer.tiles[ty * s.layer.width + tx + 1]
			if id and id > 0 then
				local col = (id - 1) % ts.columns
				local row = (id - 1) // ts.columns
				local label = Instance.new("ImageLabel")
				label.BackgroundTransparency = 1
				label.BorderSizePixel = 0
				label.Image = ts.image
				label.ImageRectOffset = Vector2.new(col * cell + ts.padding, row * cell + ts.padding)
				label.ImageRectSize = Vector2.new(ts.tilePx, ts.tilePx)
				label.ResampleMode = Enum.ResamplerMode.Pixelated
				label.Size = UDim2.fromOffset(s.tileSize, s.tileSize)
				label.Position = UDim2.fromOffset((tx - cx * CHUNK) * s.tileSize, (ty - cy * CHUNK) * s.tileSize)
				label.Parent = f
			end
		end
	end
	f.Parent = s.parent
	return f
end

-- camX, camY: snapped integer camera position in logical pixels.
function TileChunks.update(s: State, camX: number, camY: number, viewW: number, viewH: number)
	local span = CHUNK * s.tileSize
	local minCx = math.max(0, (camX - span) // span)
	local minCy = math.max(0, (camY - span) // span)
	local maxCx = (camX + viewW + span) // span
	local maxCy = (camY + viewH + span) // span
	local keep: { [number]: boolean } = {}

	for cy = minCy, maxCy do
		for cx = minCx, maxCx do
			if cx * CHUNK < s.layer.width and cy * CHUNK < s.layer.height then
				local key = cy * 65536 + cx
				keep[key] = true
				local f = s.chunks[key]
				if not f then
					f = buildChunk(s, cx, cy)
					s.chunks[key] = f
				end
				local pos = Vector2.new(cx * span - camX, cy * span - camY)
				if s.lastPos[key] ~= pos then
					f.Position = UDim2.fromOffset(pos.X, pos.Y)
					s.lastPos[key] = pos
				end
			end
		end
	end
	-- Unload chunks more than one ring away (the ring of margin above prevents thrash).
	for key, f in s.chunks do
		if not keep[key] then
			f:Destroy()
			s.chunks[key] = nil
			s.lastPos[key] = nil
		end
	end
end

return TileChunks
```

Nuances of this design:

- **The margin ring prevents thrash.** Without it, a player standing on a chunk border and wiggling builds and destroys a chunk every few frames. Building 256 labels is a visible spike on a phone (rule of thumb: a few milliseconds). If you still see spikes, build at most one chunk per frame from a queue and accept a frame of lateness at the screen edge, which the margin hides.
- **Empty tiles create nothing.** Sparse layers (foreground decoration) cost only what they contain.
- **Destroying versus pooling chunks.** Chunk creation is rare relative to frames, so destroying is acceptable. For fast scrolling games (auto-runners), keep a pool of chunk frames and reassign label properties instead.
- **Clipping.** The playfield frame needs `ClipsDescendants = true`, or chunks outside the view draw over your HUD. Clipping is by the parent's rectangle and does not apply to rotated frames, so do not rotate the playfield.
- **Animated tiles** (water, torches, conveyor belts) should not live inside static chunks. Keep them in a separate small list, render them with the sprite renderer, and advance their frames from one shared clock so every waterfall on screen is in sync.

### Seams and the one pixel gap

The most reported tilemap bug in any engine is a hairline gap or a line of the wrong colour between tiles while the camera moves. On Roblox the causes are:

1. **Fractional positions.** A chunk at x = 103.5 is drawn with its edge between pixels. Snap the camera to integers first, then compute chunk positions from the snapped camera, as the code does.
2. **Non-integer scale.** If the world's `UIScale` is 2.37, a 16 pixel tile is 37.92 screen pixels. Neighbouring tiles round differently, and the gap moves as you scroll. Use an integer scale (the setup in [[Choosing GUI 2D or Locked-Camera 2.5D]] and [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] explains how to choose it and letterbox the rest).
3. **Atlas bleeding.** Even with `Pixelated` resampling, sampling at the very edge of a cell can pick up a neighbour. Pad every atlas cell with a 1 pixel extruded border (copy the edge pixels outward) and point `ImageRectOffset` at the inner tile, as the `padding` field does.
4. **Downsampled textures.** If the engine serves a lower resolution version of the atlas, cell boundaries no longer land on whole pixels. Keep atlases at or below 1024 by 1024 and uploaded at native size (the [[pixel art]] note covers why).

If a seam appears only on some devices, it is almost always cause 2.

---

## 4. Cameras that frame the level

The engine note gives the basics: dead zone, look-ahead, vertical lock until landing, clamp to bounds, update in render. Level design adds three more ideas.

### Camera regions

Instead of one global rectangle, the level defines **camera regions** as objects in the editor: rectangles with their own bounds and rules. A narrow vertical shaft locks the camera horizontally to its centre; a boss room locks both axes so the whole arena is in view; a long corridor allows horizontal follow only. When the player crosses into a new region, the camera eases from its current bounds to the new ones over about 0.3 to 0.5 seconds (rule of thumb) instead of snapping.

```lua
--!strict
-- Camera2D: dead zone follow, look-ahead, region bounds with eased transitions.
local Camera2D = {}

export type Rect = { x: number, y: number, w: number, h: number }

export type State = {
	x: number,
	y: number,
	viewW: number,
	viewH: number,
	bounds: Rect, -- current (eased) bounds
	targetBounds: Rect,
	lookAhead: number, -- current eased look-ahead in pixels
	shakeX: number,
	shakeY: number,
}

local DEAD_W, DEAD_H = 32, 48
local LOOK_AHEAD = 40
local FOLLOW_K = 8 -- damping strength
local BOUNDS_K = 6

local function damp(a: number, b: number, k: number, dt: number): number
	return a + (b - a) * (1 - math.exp(-k * dt))
end

function Camera2D.setRegion(cam: State, region: Rect)
	cam.targetBounds = region
end

-- px, py: interpolated player centre; facing: -1 or 1; dt: frame time.
function Camera2D.update(cam: State, px: number, py: number, facing: number, grounded: boolean, dt: number)
	-- Ease the bounds themselves, so region changes glide.
	local b, t = cam.bounds, cam.targetBounds
	b.x, b.y = damp(b.x, t.x, BOUNDS_K, dt), damp(b.y, t.y, BOUNDS_K, dt)
	b.w, b.h = damp(b.w, t.w, BOUNDS_K, dt), damp(b.h, t.h, BOUNDS_K, dt)

	cam.lookAhead = damp(cam.lookAhead, facing * LOOK_AHEAD, 3, dt)

	-- Dead zone around the view centre.
	local cx = cam.x + cam.viewW / 2
	local cy = cam.y + cam.viewH / 2
	local goalX, goalY = cam.x, cam.y
	local tx = px + cam.lookAhead
	if tx > cx + DEAD_W / 2 then
		goalX = cam.x + (tx - (cx + DEAD_W / 2))
	elseif tx < cx - DEAD_W / 2 then
		goalX = cam.x + (tx - (cx - DEAD_W / 2))
	end
	-- Vertical: follow only when grounded, or when the player leaves the dead zone by a lot.
	if grounded or math.abs(py - cy) > cam.viewH * 0.35 then
		if py > cy + DEAD_H / 2 or py < cy - DEAD_H / 2 or grounded then
			goalY = py - cam.viewH / 2
		end
	end

	cam.x = damp(cam.x, goalX, FOLLOW_K, dt)
	cam.y = damp(cam.y, goalY, FOLLOW_K, dt)

	-- Clamp to bounds; a region smaller than the view centres on it.
	if b.w <= cam.viewW then
		cam.x = b.x + (b.w - cam.viewW) / 2
	else
		cam.x = math.clamp(cam.x, b.x, b.x + b.w - cam.viewW)
	end
	if b.h <= cam.viewH then
		cam.y = b.y + (b.h - cam.viewH) / 2
	else
		cam.y = math.clamp(cam.y, b.y, b.y + b.h - cam.viewH)
	end
end

-- The position renderers should use: snapped, with shake added after snapping.
function Camera2D.renderPos(cam: State): (number, number)
	return math.round(cam.x) + math.round(cam.shakeX), math.round(cam.y) + math.round(cam.shakeY)
end

return Camera2D
```

### Room-by-room cameras

Some games (exploration games in the style of classic adventure titles) show one screen at a time and slide to the next when the player exits. This is a camera region per room with an instant lock plus a scripted slide: freeze the simulation for the 0.4 to 0.6 seconds the slide takes (rule of thumb), tween the camera, then resume. It is easier to design for (every room is fully visible, no surprise enemies off screen) and much easier to optimise, because only one room's tiles and entities need to exist at a time.

### Shake and comfort

Apply screen shake **after** snapping and as whole pixels, otherwise shake makes the whole world shimmer. Keep amplitudes small (2 to 4 logical pixels for hits, rule of thumb), make shake decay quickly, and provide a setting to turn it off ([[Motion Sensitivity and Camera Comfort]]). The same setting should reduce parallax intensity, below.

---

## 5. Parallax

Parallax layers move at a fraction of the camera's speed to fake depth. A layer with factor 0 is fixed to the screen (a sky), factor 1 moves with the world, and factors between are distant scenery. Factors above 1 (near foreground leaves) move faster than the world and sell depth strongly but can be uncomfortable; use them sparingly.

### Repeating backgrounds with ScaleType Tile

For an endless repeating strip, one `ImageLabel` is enough. Roblox docs (as of October 2026): `ScaleType` controls how the image is rendered, and `TileSize` sets the size of each repetition when `ScaleType` is `Tile`. Make the label one tile wider than the view, set `TileSize` to the image's on-screen size in offsets, and move the label left by `(camX * factor) mod tileWidth`. It never runs out, and the whole layer costs one property write per frame.

```lua
--!strict
-- Parallax: horizontally repeating layers driven by the snapped camera.
local Parallax = {}

export type ParallaxLayer = {
	label: ImageLabel,
	factorX: number, -- 0 = fixed sky, 1 = moves with world
	factorY: number, -- usually much smaller than factorX
	tileW: number, -- on-screen width of one repetition, logical pixels
	baseY: number, -- vertical placement in logical pixels
	lastX: number,
	lastY: number,
}

function Parallax.make(parent: Frame, image: string, tileW: number, tileH: number, viewW: number, baseY: number, factorX: number, factorY: number, z: number): ParallaxLayer
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Tile
	label.TileSize = UDim2.fromOffset(tileW, tileH)
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Size = UDim2.fromOffset(viewW + tileW, tileH) -- one extra repetition to cover the wrap
	label.ZIndex = z
	label.Parent = parent
	return { label = label, factorX = factorX, factorY = factorY, tileW = tileW, baseY = baseY, lastX = math.huge, lastY = math.huge }
end

function Parallax.update(layers: { ParallaxLayer }, camX: number, camY: number, intensity: number)
	for _, l in layers do
		local fx = l.factorX * intensity
		local fy = l.factorY * intensity
		-- Round before the modulo so every layer moves in whole pixels.
		local x = -(math.round(camX * fx) % l.tileW)
		local y = l.baseY - math.round(camY * fy)
		if x ~= l.lastX or y ~= l.lastY then
			l.label.Position = UDim2.fromOffset(x, y)
			l.lastX, l.lastY = x, y
		end
	end
end

return Parallax
```

`intensity` is the comfort setting: 1 for full parallax, 0.5 for reduced, 0 to make every layer static.

### The stair-step problem

A layer with factor 0.1 moves one pixel for every ten pixels of camera movement. At a slow walk that is a visible "tick... tick" instead of smooth motion. It is inherent to pixel snapping; the options are:

- **Accept it.** Many classic pixel games do; at small factors and low contrast it reads as fine.
- **Render distant layers at screen resolution** rather than logical resolution: put them outside the scaled world frame, at native screen pixels, so one logical pixel step becomes several screen pixel steps. This breaks the strict pixel grid for those layers only, which is usually invisible on blurry, low contrast backgrounds.
- **Use larger factors for textured layers** and keep tiny factors for flat shapes like a gradient sky, where steps are invisible.

Vertical parallax is often much smaller than horizontal (factorY around a quarter of factorX, rule of thumb), because players jump constantly and strong vertical parallax makes backgrounds bob.

---

## 6. Tilemaps and parallax in the 2.5D route

In a locked-camera 3D side-scroller ([[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]) you can still author levels as tilemaps and build parts from them, which gives you a fast level editor and data you can validate.

**Greedy merging.** One part per solid tile is wasteful: a 300 by 40 level with half its cells solid is 6,000 parts, each with collision and replication cost ([[Rendering Performance]], [[Physics Performance]]). Merge horizontal runs of the same tile into one part, then merge identical runs on consecutive rows into rectangles. Typical platformer levels drop by an order of magnitude (rule of thumb). Visual detail then comes from textures or decorative meshes, not from part count. Community reports put the maximum part size at 2,048 studs per axis; we could not confirm this in the official docs, so cap merged parts well below it.

```lua
--!strict
-- Greedy rectangle merge of a tile grid: returns rectangles of equal tile values.
export type RectTile = { x: number, y: number, w: number, h: number, value: number }

local function greedyRects(width: number, height: number, tiles: { number }, isSolid: (number) -> boolean): { RectTile }
	local used = table.create(width * height, false)
	local out: { RectTile } = {}
	local function at(x: number, y: number): number
		return tiles[y * width + x + 1]
	end
	for y = 0, height - 1 do
		local x = 0
		while x < width do
			local v = at(x, y)
			if used[y * width + x + 1] or not isSolid(v) then
				x += 1
				continue
			end
			-- Extend right.
			local w = 1
			while x + w < width and at(x + w, y) == v and not used[y * width + x + w + 1] do
				w += 1
			end
			-- Extend down while the whole row segment matches.
			local h = 1
			local canGrow = true
			while canGrow and y + h < height do
				for i = 0, w - 1 do
					if at(x + i, y + h) ~= v or used[(y + h) * width + x + i + 1] then
						canGrow = false
						break
					end
				end
				if canGrow then
					h += 1
				end
			end
			for yy = y, y + h - 1 do
				for xx = x, x + w - 1 do
					used[yy * width + xx + 1] = true
				end
			end
			table.insert(out, { x = x, y = y, w = w, h = h, value = v })
			x += w
		end
	end
	return out
end

return greedyRects
```

Each rectangle becomes a part sized `w * tileStuds` by `h * tileStuds` on the gameplay plane, with tile y flipped because 3D Y grows up. Build parts in Studio with a plugin or command bar script and save them into the place; building at runtime on the server works too but costs join time.

**Parallax in 2.5D.** A perspective camera gives parallax for free: distant geometry moves slower on screen. If you lowered the field of view to flatten the look, depth separation shrinks and you may need to push background models much further back, or fake it by moving background models with the camera at a factor in `PreRender` on the client (they are client-only decoration, so moving them locally costs no network). Background art on large parts with `Decal`s or `Texture`s works, but these are 3D surfaces with no `Pixelated` filter, so pixel art on them blurs (see the pixel art note for workarounds).

---

## 7. Level loading and rooms

- **Load by room or chunk, not by level** for anything large. The loader spawns objects for the current room and its neighbours and despawns others; enemies that must persist (a defeated boss) record their state in a per-level table, not in their entity.
- **Object properties from the editor** become typed config. Validate them at build time: an enemy with a misspelt kind should fail the build, not spawn nothing at runtime.
- **Checkpoints** are objects with an id; the save stores the id, never a position, so moving a checkpoint in the editor does not strand players inside a wall.
- **Server copy.** In multiplayer or validated games the server loads collision layers and objects too. Keep visual layers out of server memory.

---

## 8. Common mistakes

- **Collision derived from visual tiles.** Symptom: an artist adds a decorative tile and players get stuck on it.
- **One ImageLabel per tile moved every frame.** Symptom: script time scales with level size, not screen content.
- **Chunks positioned from an unsnapped camera.** Symptom: hairline seams that flicker while scrolling.
- **Non-integer world scale.** Symptom: seams only on some phones or window sizes.
- **No atlas padding.** Symptom: thin lines of a neighbouring tile's colour at tile edges.
- **Reordering the atlas.** Symptom: every level's decoration turns into garbage after an art update.
- **Tiled flip bits not cleared.** Symptom: some tiles render as nothing or as a random far tile id.
- **Shake applied before snapping.** Symptom: the world shimmers during every hit.
- **Strong vertical parallax.** Symptom: backgrounds bob on every jump; players report discomfort.
- **One part per tile in 2.5D.** Symptom: thousands of parts, slow joins, physics cost from static geometry.

---

## 9. Checklist

- [ ] Collision layer separate from visual layers; objects as a separate list.
- [ ] Levels converted at build time to Luau data; versioned; tile ids append-only.
- [ ] Tiled GID flags cleared; flipped variants pre-baked.
- [ ] Chunk renderer with a margin ring; empty tiles create nothing; animated tiles separate.
- [ ] Camera snapped before computing chunk, sprite and parallax positions; integer world scale.
- [ ] Atlas cells padded and extruded; atlas at most 1024 by 1024.
- [ ] Camera regions with eased bound transitions; vertical follow on landing.
- [ ] Shake in whole pixels after snapping; comfort setting reduces shake and parallax.
- [ ] Parallax layers with `ScaleType.Tile`, one write per layer per frame.
- [ ] 2.5D levels greedy merged; part count measured.
- [ ] Rooms or chunks loaded on demand; checkpoints saved by id.

## See also

- [[2D Game Development Start Here]]
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]
- [[2D Collision Physics and Platformer Movement]]
- [[Sprite Sheets and Frame Animation with ImageRectOffset]]
- [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]
- [[EditableImage for Pixel Buffers and Procedural 2D]]
- [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]
- [[Camera Systems]]
- [[Springs Damping and Smoothing]]
- [[Procedural World Generation]]
- [[Level Design Principles - Flow Sightlines and Landmarks]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Scale Grids and Stud Alignment]] · Meshing Voxels for Roblox - Greedy Meshing and Export · Voxel Props Environments and Modular Tiles · Infinite and Streamed Worlds · Textures Decals and Texture Memory · Thumbnail Contrast
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Textures Decals and Texture Memory]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Voxel Props Environments and Modular Tiles]] · [[Dungeon and Room Generation]] · [[Modular Environment Kits]]
<!-- related:end -->
