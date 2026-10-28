---
tags: [2d, editableimage, pixel-buffer, procedural, buffers, rendering, performance, memory, permissions, luau]
---
# EditableImage for Pixel Buffers and Procedural 2D

<!-- tldr:start -->
> [!tldr] TL;DR
> - Creation returns nil. Budget exhausted on this device.
> - Creation errors in the live game but worked in Studio.
> - Image shows briefly then stops updating.
> - Allow Mesh / Image APIs enabled for the published experience; Terms of Use reviewed.
> - Creation wrapped in `pcall`, `nil` handled, and a fallback path exists.
> - Framebuffers at native pixel resolution (well under 1024), scaled up with `Pixelated`.
>
> Read more (23 KB note): ## 1. The API as documented · ## 4. A framebuffer you can build on · ## 6. Fallbacks and failure modes · ## 9. Checklist
<!-- tldr:end -->

`EditableImage` lets a script create an image at runtime and write pixels into it. For 2D games that opens doors that ImageLabels alone cannot: a real framebuffer you draw into, destructible terrain masks, fog of war, paint and drawing tools, procedural backgrounds and effects, runtime palette swaps, and minimaps drawn from data. It also has sharp edges: a client memory budget that makes creation return `nil`, a permission toggle that is off by default in published games, a display path that only refreshes one image per frame, and policy questions as soon as players can draw things other players see. This note covers the current API as documented, the budgets, a working framebuffer, and when to avoid the whole thing.

Related: [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] for sharp display, [[Buffers and Binary Data]] for the `buffer` library, [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] for the ImageLabel approach this competes with.

---

## 1. The API as documented

Everything in this section is from the EditableImage and AssetService reference pages (Roblox docs (as of October 2026)).

**Creating.**

- `AssetService:CreateEditableImage(options: Dictionary?): EditableImage` creates a blank image. The default resolution is 512 by 512; pass `{ Size = Vector2.new(w, h) }` for another size. It does not yield. It returns `nil` "if the device-specific editable memory budget is exhausted".
- `AssetService:CreateEditableImageAsync(content: Content, options: Dictionary?): EditableImage` creates an image populated from an existing texture. It yields. Resizing through options is not supported. It also returns `nil` when the budget is exhausted, and throws if the asset fails the permission rules below.
- The maximum size is 1024 by 1024, and an EditableImage cannot be resized after creation.

**Reading and writing pixels.**

- `ReadPixelsBuffer(position: Vector2, size: Vector2): buffer` and `WritePixelsBuffer(position: Vector2, size: Vector2, buffer: buffer)`. Each pixel is four bytes in the order red, green, blue, alpha, one byte each, so a full image buffer is `Size.X * Size.Y * 4` bytes. These buffer methods use alpha, not transparency (255 is opaque).
- Coordinates start at the top left: (0, 0) is the top left pixel and (Size.X - 1, Size.Y - 1) the bottom right.

**Drawing primitives.**

- `DrawRectangle(position, size, color, transparency, combineType)`
- `DrawCircle(center, radius, color, transparency, combineType, antiAliasing)` and `DrawLine(p1, p2, color, transparency, combineType, antiAliasing)`; `antiAliasing` defaults to enabled, which you will want to turn off for pixel art.
- `DrawImage(position, image, combineType)` copies another EditableImage in.
- `DrawImageTransformed(position, scale, rotation, image, options?)` with options including `CombineType` (default AlphaBlend), `SamplingMode` (`Default` is bilinear, `Pixelated` is nearest neighbour) and `PivotPoint`.
- `DrawImageProjected` and `SampleImageProjected` project images onto meshes; they are aimed at 3D painting rather than 2D games.
- `Enum.ImageCombineType` values used in the docs include `AlphaBlend` and `Overwrite`. Note that the primitive draw calls take a transparency (0 is opaque), the opposite convention from the buffer's alpha.

**Displaying.** Assign it to any image Content property, for example `ImageLabel.ImageContent = Content.fromObject(editableImage)`. One EditableImage can be referenced by several Content properties at once ("multi-referencing"), which the docs suggest as a memory saving.

**Freeing.** `Destroy()` "destroys the contents of the image, immediately reclaiming used memory."

**Display refresh limit.** The docs state: "Only a single `EditableImage` can be updated per frame on the display side." Design around this (section 4.3).

**Permissions.**

- In published experiences the APIs fail by default. Enable **Allow Mesh / Image APIs** under Security in Studio's Experience Settings (or **Enable Mesh / Image APIs** in the Creator Dashboard). The docs advise reading the Terms of Use before enabling it.
- `CreateEditableImageAsync` only loads an asset that is owned by or explicitly shared with the experience owner, the logged in Studio user, the logged in player (for client-side images), or a group where one of those has permission to edit the group's assets.

Earlier beta versions of these APIs had additional creator eligibility requirements. The current reference pages list only the toggle and the asset permission rules above; if your toggle is greyed out, check the Creator Dashboard for any eligibility message (unverified as of October 2026 whether any extra requirement remains).

**Budgets.** The docs say editable assets are expensive for memory and that EditableImage "has strict client-side memory budgets", while the server, Studio and plugins have no such limit. The exact budget is device specific and not published. Community reports describe hitting it quickly when creating many images, for example one per material.

---

## 2. What it costs

Raw pixel memory is `width x height x 4` bytes:

| Size | Bytes per image | Full upload per frame at 60 FPS |
|---|---|---|
| 128 x 128 | 64 KB | 3.8 MB/s of copying |
| 160 x 144 | 90 KB | 5.4 MB/s |
| 320 x 180 | 225 KB | 13.5 MB/s |
| 512 x 512 | 1 MB | 60 MB/s |
| 1024 x 1024 | 4 MB | 240 MB/s |

(Rule of thumb arithmetic. The engine also keeps a GPU copy; real memory is higher than the raw number.)

Two lessons fall out of this table:

1. **Work at the native pixel resolution and let the ImageLabel scale it.** A 320 by 180 framebuffer displayed with `ResampleMode = Pixelated` at scale 6 fills 1080p and costs 225 KB. Rendering at screen resolution would cost 8 MB and fail the budget on many phones.
2. **Do not rewrite the whole image every frame unless it is small.** Track a dirty rectangle and upload only that.

Script cost matters as much as memory. Writing 57,600 pixels (320 x 180) one at a time in Luau is tens of thousands of `buffer.writeu32` calls per frame. That is fine with native code generation for simple fills, and too slow for complex per-pixel shading on low end phones (rule of thumb; measure with the MicroProfiler, see [[MicroProfiler Guide]]). Use `--!native` on the hot module and keep per-pixel work to integer arithmetic (see [[Luau Performance and Native Codegen]]).

---

## 3. Where it fits in a 2D game

| Use | Why EditableImage | Cheaper alternative to consider first |
|---|---|---|
| Destructible terrain (craters, digging) | Per-pixel mask, collision read from the same data | Tile-based destruction with ImageLabels |
| Fog of war | One small image (one pixel per tile), scaled up | A grid of Frames with transparency |
| Paint and drawing games | Strokes are pixels | Line segments as rotated Frames (fine for few strokes) |
| Procedural backgrounds, fire, water, plasma | Per-pixel effects | Pre-rendered sprite animations |
| Runtime palette swaps | Exact colour remap of a sprite sheet | Greyscale overlay tinted with `ImageColor3` |
| Minimap from level data | Drawn once, updated rarely | UIGridLayout of tiny frames |
| Falling sand, cellular automata | Thousands of cells changing per frame | None really |
| Whole-game software renderer | Full control, retro look | The ImageLabel entity approach scales better for sprites |

The pattern that works is **data in a Luau buffer, image as the display**. Your simulation reads and writes plain buffers (fast, budget free, testable); once per frame you copy the changed rectangle into the EditableImage. Never read pixels back from the EditableImage to make game decisions; `ReadPixelsBuffer` is for loading source art, not for game logic.

---

## 4. A framebuffer you can build on

### 4.1 The module

```lua
--!strict
--!native
-- ModuleScript: ReplicatedStorage.Framebuffer
-- A CPU-side RGBA buffer mirrored into one EditableImage, with dirty-rect uploads.
local AssetService = game:GetService("AssetService")

export type Framebuffer = {
	width: number,
	height: number,
	pixels: buffer, -- width * height * 4 bytes, RGBA
	image: EditableImage,
	-- Dirty rectangle, inclusive min, exclusive max. Empty when minX >= maxX.
	minX: number, minY: number, maxX: number, maxY: number,
}

local Framebuffer = {}

-- Pack RGBA bytes into one little-endian u32 (byte 0 = red).
function Framebuffer.rgba(r: number, g: number, b: number, a: number): number
	return bit32.bor(r, bit32.lshift(g, 8), bit32.lshift(b, 16), bit32.lshift(a, 24))
end

-- Returns nil when the device budget is exhausted or the APIs are disabled.
function Framebuffer.new(width: number, height: number): Framebuffer?
	assert(width >= 1 and height >= 1 and width <= 1024 and height <= 1024, "size must be 1..1024")
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
	end)
	if not ok or image == nil then
		return nil
	end
	return {
		width = width,
		height = height,
		pixels = buffer.create(width * height * 4),
		image = image,
		minX = 0, minY = 0, maxX = width, maxY = height, -- first present uploads everything
	}
end

local function markDirty(fb: Framebuffer, x0: number, y0: number, x1: number, y1: number)
	if fb.minX >= fb.maxX then
		fb.minX, fb.minY, fb.maxX, fb.maxY = x0, y0, x1, y1
	else
		fb.minX = math.min(fb.minX, x0)
		fb.minY = math.min(fb.minY, y0)
		fb.maxX = math.max(fb.maxX, x1)
		fb.maxY = math.max(fb.maxY, y1)
	end
end

function Framebuffer.setPixel(fb: Framebuffer, x: number, y: number, color: number)
	if x < 0 or y < 0 or x >= fb.width or y >= fb.height then
		return
	end
	buffer.writeu32(fb.pixels, (y * fb.width + x) * 4, color)
	markDirty(fb, x, y, x + 1, y + 1)
end

function Framebuffer.getPixel(fb: Framebuffer, x: number, y: number): number
	if x < 0 or y < 0 or x >= fb.width or y >= fb.height then
		return 0
	end
	return buffer.readu32(fb.pixels, (y * fb.width + x) * 4)
end

function Framebuffer.fillRect(fb: Framebuffer, x: number, y: number, w: number, h: number, color: number)
	local x0 = math.max(0, x)
	local y0 = math.max(0, y)
	local x1 = math.min(fb.width, x + w)
	local y1 = math.min(fb.height, y + h)
	if x0 >= x1 or y0 >= y1 then
		return
	end
	local stride = fb.width * 4
	-- Write the first row, then copy it down: far fewer calls than per-pixel writes.
	local rowStart = y0 * stride + x0 * 4
	for px = 0, (x1 - x0) - 1 do
		buffer.writeu32(fb.pixels, rowStart + px * 4, color)
	end
	local rowBytes = (x1 - x0) * 4
	for row = y0 + 1, y1 - 1 do
		buffer.copy(fb.pixels, row * stride + x0 * 4, fb.pixels, rowStart, rowBytes)
	end
	markDirty(fb, x0, y0, x1, y1)
end

function Framebuffer.clear(fb: Framebuffer, color: number)
	Framebuffer.fillRect(fb, 0, 0, fb.width, fb.height, color)
end

-- Copy the dirty rectangle into the EditableImage. Call once per frame.
function Framebuffer.present(fb: Framebuffer)
	if fb.minX >= fb.maxX or fb.minY >= fb.maxY then
		return
	end
	local w = fb.maxX - fb.minX
	local h = fb.maxY - fb.minY
	if w == fb.width and h == fb.height then
		fb.image:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), fb.pixels)
	else
		-- WritePixelsBuffer takes w * h * 4 bytes for a w x h region,
		-- so pack the rectangle's rows tightly into a right-sized buffer.
		local stride = fb.width * 4
		local rowBytes = w * 4
		local packed = buffer.create(w * h * 4)
		for row = 0, h - 1 do
			buffer.copy(packed, row * rowBytes, fb.pixels, (fb.minY + row) * stride + fb.minX * 4, rowBytes)
		end
		fb.image:WritePixelsBuffer(Vector2.new(fb.minX, fb.minY), Vector2.new(w, h), packed)
	end
	fb.minX, fb.minY, fb.maxX, fb.maxY = 0, 0, 0, 0
end

-- Show the framebuffer in an ImageLabel, crisp, at a whole-number scale.
function Framebuffer.attach(fb: Framebuffer, label: ImageLabel, scale: number)
	label.ImageContent = Content.fromObject(fb.image)
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Size = UDim2.fromOffset(fb.width * scale, fb.height * scale)
	label.BackgroundTransparency = 1
end

function Framebuffer.destroy(fb: Framebuffer)
	fb.image:Destroy()
end

return Framebuffer
```

Design notes:

- **Why a packed buffer for partial uploads?** The docs give the full-image buffer length as `Size.X * Size.Y * 4`; for a partial write, passing a buffer sized exactly to the rectangle is the safe reading. Creating a small buffer per partial upload is cheap relative to the copy itself; if profiling says otherwise, keep a cache of packed buffers keyed by size.
- **Why `pcall` around creation?** The docs promise `nil` on budget exhaustion, but disabled APIs in a published game produce an error. Treat both as "feature unavailable" and fall back (section 6).
- **Why a dirty rectangle and not a list?** One union rectangle is simple and usually good enough. If you update two far corners each frame (a HUD in one corner, an effect in another), use two framebuffers instead, mindful of the one-update-per-frame display limit.

### 4.2 A procedural effect: classic fire

The well known "fire" effect (each pixel takes the heat of the pixel below it, minus a random decay, shifted sideways) shows the data-then-display pattern in about 40 lines:

```lua
--!strict
--!native
-- LocalScript: a procedural fire background drawn into a Framebuffer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Framebuffer = require(ReplicatedStorage:WaitForChild("Framebuffer") :: ModuleScript)

local W, H, SCALE = 160, 90, 6
local fb = Framebuffer.new(W, H)
if not fb then
	warn("[Fire] EditableImage unavailable; skipping effect")
	return
end
local frameBuffer = fb :: Framebuffer.Framebuffer

local gui = Instance.new("ScreenGui")
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
local label = Instance.new("ImageLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.fromScale(0.5, 1)
Framebuffer.attach(frameBuffer, label, SCALE)
label.Parent = gui
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Heat grid in its own u8 buffer; the image is only the display.
local heat = buffer.create(W * H)
for x = 0, W - 1 do
	buffer.writeu8(heat, (H - 1) * W + x, 36) -- bottom row burns at max heat
end

-- 37-entry palette from transparent black through red and yellow to white.
local palette: { number } = table.create(37, 0)
for i = 0, 36 do
	local t = i / 36
	local r = math.floor(math.clamp(t * 3, 0, 1) * 255)
	local g = math.floor(math.clamp(t * 3 - 1, 0, 1) * 255)
	local b = math.floor(math.clamp(t * 3 - 2, 0, 1) * 255)
	local a = if i == 0 then 0 else 255
	palette[i + 1] = Framebuffer.rgba(r, g, b, a)
end

local rng = Random.new()
local STEP = 1 / 30 -- simulate at 30 Hz regardless of frame rate
local accumulator = 0

RunService.RenderStepped:Connect(function(dt: number)
	accumulator += dt
	if accumulator < STEP then
		return
	end
	accumulator = math.min(accumulator - STEP, STEP) -- never spiral after a hitch

	for y = 1, H - 1 do
		for x = 0, W - 1 do
			local below = buffer.readu8(heat, y * W + x)
			local decay = rng:NextInteger(0, 2)
			local dstX = math.clamp(x - decay + 1, 0, W - 1)
			buffer.writeu8(heat, (y - 1) * W + dstX, math.max(below - (decay % 2), 0))
		end
	end

	local pixels = frameBuffer.pixels
	for i = 0, W * H - 1 do
		buffer.writeu32(pixels, i * 4, palette[buffer.readu8(heat, i) + 1])
	end
	frameBuffer.minX, frameBuffer.minY, frameBuffer.maxX, frameBuffer.maxY = 0, 0, W, H
	Framebuffer.present(frameBuffer)
end)
```

The effect simulates at a fixed 30 Hz and uploads 57.6 KB per step. That is light. The same code at 1024 by 1024 would upload 4 MB per step and process a million cells in Luau, which is not viable on a phone; keep procedural effects at low resolution and let `Pixelated` scaling sell the retro look.

### 4.3 Living with "one update per frame"

Because only one EditableImage is updated per frame on the display side, ten small animated EditableImages will not all refresh every frame. Design rules that follow (rule of thumb, derived from the documented limit):

- **One animated EditableImage per screen.** Composite everything that changes every frame into a single framebuffer.
- **Static images are free of the limit after creation.** Palette-swapped sprite sheets, baked minimaps and baked tile chunks update once and are then displayed like any image.
- **Spread rare updates.** If you have several images that update occasionally (fog of war, minimap), stagger them across frames instead of updating all at once.

---

## 5. Recipes

### 5.1 Destructible terrain mask

Keep a one byte per pixel solidity mask in a buffer (1 = solid). Draw the terrain colour from the mask into the framebuffer once at load. A crater clears a circle in the mask and paints the same circle transparent in the framebuffer (via `fillRect` row spans or `DrawCircle` with `Overwrite` and transparency 1). Collision reads the mask, never the image. On the server, keep the same mask and apply the same craters; send only "crater at x, y, radius r" events to clients so their masks stay identical (see [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]). Determinism matters here: use integer coordinates and integer radii so every client rasterises the identical circle.

### 5.2 Fog of war

Use one pixel per tile, not per screen pixel. A 128 by 128 tile map becomes a 64 KB image; display it over the map scaled by the tile size with `ResampleMode = Default` if you want soft fog edges for free (bilinear scaling of a low resolution mask is exactly a soft fog), or `Pixelated` for hard tile fog. The server decides visibility; the client only draws what the server told it (section 7).

### 5.3 Runtime palette swap

```lua
--!strict
-- Remap exact colours in a sprite sheet. Returns nil if unavailable.
local AssetService = game:GetService("AssetService")

local function paletteSwap(assetUri: string, map: { [number]: number }): EditableImage?
	local ok, img = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(assetUri))
	end)
	if not ok or img == nil then
		return nil
	end
	local image = img :: EditableImage
	local size = image.Size
	local pixels = image:ReadPixelsBuffer(Vector2.zero, size)
	for i = 0, size.X * size.Y - 1 do
		-- Compare RGB only (mask off alpha); keep the original alpha.
		local c = buffer.readu32(pixels, i * 4)
		local rgb = bit32.band(c, 0x00FFFFFF)
		local swapped = map[rgb]
		if swapped then
			buffer.writeu32(pixels, i * 4, bit32.bor(swapped, bit32.band(c, 0xFF000000)))
		end
	end
	image:WritePixelsBuffer(Vector2.zero, size, pixels)
	return image
end
```

Keys and values in `map` are `0xBBGGRR` (little-endian packing puts red in the lowest byte). Writing a tiny helper that takes `Color3` and packs it avoids a whole class of "red and blue swapped" bugs. Each swapped sheet costs a full image of budget; cache swaps by palette key and share one EditableImage across all labels that use it (multi-referencing).

---

## 6. Fallbacks and failure modes

- **Creation returns nil.** Budget exhausted on this device. Fall back to a static image or skip the effect; never retry in a tight loop.
- **Creation errors in the live game but worked in Studio.** The Allow Mesh / Image APIs toggle is off for the published experience, or a loaded asset fails the ownership rules for that player. Studio uses the Studio user's permissions; live clients use the player's and the owner's.
- **Image shows briefly then stops updating.** Another EditableImage is being updated every frame and winning the display slot. Merge into one framebuffer.
- **Memory grows over a session.** Images not destroyed when a level or menu closes. Pair every `Framebuffer.new` with `destroy` in your cleanup (see [[Hunting Memory Leaks Step by Step]]).
- **Colours look wrong.** Byte order (red is byte 0) or mixing the alpha convention (buffers) with the transparency convention (Draw calls).

Every feature built on EditableImage should have a "unavailable" path that still lets the game run. A fog of war that silently fails should fall back to Frames, not to a fully revealed map.

---

## 7. Server, client, and policy

**Server.** The server has no budget, so it can build images (for example, a procedural texture). The reference pages do not describe EditableImages replicating to clients; treat them as local to the machine that created them (rule of thumb). To share an image, replicate the data that produced it (a seed, a list of strokes, a mask diff) and let each client rebuild it.

**Never trust the client's pixels.** Anything the server sends to a client can be read by an exploiter, so fog of war only works if the server never sends hidden entity positions in the first place. Rendering fog over data the client already has is cosmetic. See [[Server Authority and Validation]] and [[Interest Management and Per-Player Replication]].

**Player drawings are user-generated content.** If players can draw and other players can see the drawing, you are distributing unmoderated imagery. The docs advise reviewing the Terms of Use before enabling these APIs, and Roblox's community rules apply to what players show each other. Practical safeguards (rule of thumb): keep drawings private by default, show them only to the author or to friends, offer hide and report on any shared drawing, limit canvas size and colour count, and log stroke data so reports can be reviewed. If you want players to publish creations as real assets, the docs mention `AssetService:PromptCreatePlatformContentAsync()` converting an EditableImage into a published image asset, which goes through normal moderation. See [[Roblox Policies Ratings and Compliance]] and [[Player Reports and In-Game Moderation]].

---

## 8. When not to use EditableImage

- **Sprites that only move and animate.** ImageLabels with sprite sheets are cheaper, need no permission toggle, never hit the budget, and the engine composites them on the GPU. See [[Sprite Sheets and Frame Animation with ImageRectOffset]].
- **High resolution effects.** If the effect only looks good at screen resolution, it is the wrong tool; use particles, beams or pre-rendered sprites.
- **Anything that must work on every device with no fallback.** The budget is device specific and undocumented.
- **Game state.** The image is the display. State lives in buffers and tables.

---

## 9. Checklist

- [ ] Allow Mesh / Image APIs enabled for the published experience; Terms of Use reviewed.
- [ ] Creation wrapped in `pcall`, `nil` handled, and a fallback path exists.
- [ ] Framebuffers at native pixel resolution (well under 1024), scaled up with `Pixelated`.
- [ ] Simulation in Luau buffers; the image only receives `WritePixelsBuffer` uploads.
- [ ] Dirty rectangle uploads; at most one EditableImage animated per frame.
- [ ] Byte order and alpha versus transparency conventions handled in one helper.
- [ ] Every image destroyed when its screen or level closes.
- [ ] Loaded assets owned by or shared with the experience owner.
- [ ] Hidden information filtered on the server, not by drawing over it.
- [ ] Shared player drawings have privacy defaults, hide and report.
- [ ] Hot loops in `--!native` modules and measured in the MicroProfiler on a phone.

## See also

[[Memory Budgets and Leaks]], [[Procedural World Generation]], [[Noise Functions and Terrain Generation]], [[Tilemaps Cameras and Parallax for 2D Levels]], [[Rendering Performance]].

## Connected notes
<!-- auto-links:start -->
[[2D Game Development Start Here]] · [[SurfaceAppearance PBR Workflow]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Textures Decals and Texture Memory]] · [[The Gradient Palette Texture Workflow]] · [[Texturing and PBR Baking]]
<!-- auto-links:end -->
