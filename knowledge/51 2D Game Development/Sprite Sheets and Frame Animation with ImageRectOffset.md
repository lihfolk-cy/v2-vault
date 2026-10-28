---
tags: [2d, sprites, sprite-sheet, animation, imagelabel, imagerectoffset, pixel-art, flipbook, luau]
---
# Sprite Sheets and Frame Animation with ImageRectOffset

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Per-frame `Image` swaps. Symptom: blank or flickering frames the first time each animation plays.
> - Avoid: Sheets over the size limit. Symptom: every frame is offset or shows parts of its neighbours after upload, though the source...
> - Avoid: Rectangles in GUI pixels instead of image pixels.
> - One sheet per character (or per animation group), at or below 1024 x 1024, tightly packed.
> - 1 to 2 pixels of padding or extrusion between frames.
> - Frame data imported from the art tool, converted to a committed Luau module, validated (no zero sizes).
>
> Read more (22 KB note): ## 6. Importing frame data · ## 7. The animation player · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

A 2D character is a sequence of drawings shown one after another. On Roblox, the efficient way to show them is one uploaded image that contains every frame (a **sprite sheet** or **atlas**), displayed through an `ImageLabel` that shows only one rectangle of it at a time. Changing the rectangle changes the frame. This note covers how the rectangle properties really behave, how to lay out sheets so frames do not bleed or blur, mirroring, importing frame data from an art tool, a frame-accurate animation player driven by the game loop, gameplay events on frames, and the mistakes that cost the most time.

It plugs into the renderer in [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] (the `Sprites.apply` call there is defined below). Getting the art itself out of an editor cleanly is in [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]; general UI animation with tweens is in [[UI and GUI Animation]].

Source labels: **Roblox docs (as of October 2026)**, **DevForum community technique** (not in official docs; test it), **rule of thumb**.

---

## 1. The three properties that matter

Roblox docs (as of October 2026), `ImageLabel`:

- `ImageRectOffset` (`Vector2`): "the pixel offset (from the top-left) of the image area to be displayed."
- `ImageRectSize` (`Vector2`): "the pixel size of the image area to be displayed. If either dimension is set to `0`, the entire image is displayed instead."
- `ResampleMode` (`Enum.ResamplerMode`, items `Default` and `Pixelated`): by default "the image smooths out texturing when displayed on the screen larger or smaller than its size in texture memory. When set to Enum.ResamplerMode.Pixelated, the image preserves the sharp edges of pixels."

Consequences that are easy to miss:

1. **Units are image pixels, not GUI pixels.** The rectangle is measured on the image as stored, independent of the label's on-screen size. A 32 x 32 frame stays `Vector2.new(32, 32)` whether the label is 32 or 256 pixels wide on screen. Using the label's own size here is a classic mistake (reported on the DevForum as "my flip or crop does nothing").
2. **"As stored" means after upload processing.** If the uploaded sheet is larger than the size Roblox keeps, it is downscaled, and every offset you computed from your source file now points at the wrong place. The ceiling is widely reported on the DevForum as 1024 pixels on the longest side, and the vault's existing art notes treat 1024 as the practical ceiling ([[Textures Decals and Texture Memory]]). I could not find the exact upload cap stated on a current official docs page in October 2026, so keep sheets at or below 1024 x 1024 and you never have to care.
3. **Zero means "whole image".** A frame table with a missing size (nil becomes `Vector2.zero` in some data paths) shows the entire sheet for a frame: the "my character turned into a grid of tiny copies" bug.
4. **`ScaleType` should be `Stretch`.** The cropped rectangle is then stretched to the label size. `Fit` and `Crop` change the effective area and are rarely what you want for sprites; `Tile` and `Slice` have their own semantics (see [[ScreenGui Fundamentals]]).
5. **Resampling applies to the cropped area.** With `Default`, a 16 x 16 frame shown at 64 x 64 is bilinear-smoothed and looks blurry; with `Pixelated` it is crisp. For pixel art, `Pixelated` is mandatory.

---

## 2. Why sheets instead of one image per frame

| | One image per frame (swap `Image`) | Sprite sheet (move the rectangle) |
|---|---|---|
| Uploads and moderation | One asset per frame; a 40-frame character is 40 uploads, each moderated separately | One upload per sheet |
| First display | Each new frame may be blank until it downloads, so animations "flicker in" the first time | Whole sheet loads once; every frame is ready |
| Memory | Many small textures, each with overhead | One texture shared by every label that uses it |
| Changing frames at runtime | Changing a content id | Changing a `Vector2`, cheap |
| Moderation risk | One rejected frame breaks one animation silently | One rejection breaks the whole sheet, but you see it at once |

Swapping `Image` per frame is the most common beginner flipbook and the most common reason a 2D game "stutters the first time each animation plays". Use sheets. If one sheet is not enough for a character, split by animation group (movement sheet, combat sheet), not by frame.

**Memory arithmetic (rule of thumb).** A 1024 x 1024 image at 4 bytes per pixel is 4 MB before any GPU compression. Roblox transcodes uploads to its own GPU formats, and the docs state that memory follows pixel count, not file size ([[Textures Decals and Texture Memory]]), so a mostly empty 1024 sheet costs as much as a full one. Pack tightly, and do not upload 1024 sheets for an enemy with six 16 x 16 frames.

---

## 3. Sheet layout: grids, padding and bleeding

### Uniform grids

The simplest sheet is a grid: every cell the same size, frames left to right, animations in rows. The frame rectangle is pure arithmetic:

```lua
local function gridRect(index: number, cellW: number, cellH: number, columns: number): (Vector2, Vector2)
	local i = index - 1 -- 0-based
	local col = i % columns
	local row = i // columns
	return Vector2.new(col * cellW, row * cellH), Vector2.new(cellW, cellH)
end
```

Use grids when frames are similar in size. They waste space for characters whose attack frames are much wider than their idle frames.

### Packed atlases

Tools such as Aseprite (sheet export with JSON data) or texture packers place frames of different sizes tightly and write a data file with each frame's rectangle. You import that data (section 6) rather than computing rectangles.

### Bleeding and the one-pixel gutter

When a cropped frame is resampled, the GPU may sample texels just outside the rectangle, so a thin line of the neighbouring frame appears at the edge of the sprite. It shows up most with `ResampleMode.Default`, non-integer scales, and sub-pixel positions. Pixelated sampling at integer scales and whole-pixel positions largely avoids it, but not reliably on every device and scale (rule of thumb).

The fix every 2D engine uses: **leave transparent padding between frames** (1 to 2 pixels), or **extrude** each frame's edge pixels outward into the padding so any bleed samples the same colour. Aseprite's sheet export has border padding, shape padding and inner padding options for this. Padding costs a little sheet space and removes a whole class of "random lines on my character" bug reports.

### Pivot and trimming

Packers often **trim** transparent borders to save space, which means frame 3 might be 14 x 20 while frame 4 is 18 x 22. If you draw every frame at the same label position, the character visibly jumps between frames. The data file records where the trimmed frame sat in the original canvas (Aseprite calls it `spriteSourceSize`; the untrimmed canvas is `sourceSize`). Store that offset per frame and add it when positioning the label. Rule: **every frame shares one pivot in canvas space**, usually the feet centre, and the renderer places the trimmed rectangle relative to it.

---

## 4. Mirroring (facing left and right)

There is no flip property on `ImageLabel` in the docs as of October 2026, and requests for one are still open on the DevForum. Three ways exist:

1. **Negative rectangle size (DevForum community technique).** Set `ImageRectSize` to a negative width and move `ImageRectOffset` to the right edge of the frame. For a frame at `(x, y)` of size `(w, h)`, horizontal mirror is offset `(x + w, y)` and size `(-w, h)`. This is widely used and works in current builds per community reports, but it is not documented behaviour, Studio may show an out-of-bounds warning for it, and an engine change could break it. Test on every platform you ship to.
2. **Mirrored frames in the sheet.** Export left-facing frames as well. Doubles sheet area, zero risk, and lets artists fix asymmetric details (a sword in the right hand should stay in the right hand, which a mirror cannot do).
3. **Negative-scale tricks with layout objects** do not work: `UDim2` sizes cannot be negative in a way that mirrors, and `UIScale` is uniform and positive.

Decide by art: symmetric characters use technique 1 behind a single function (so you can swap to technique 2 in one place if it ever breaks); asymmetric characters use technique 2.

---

## 5. The sprite registry

All sprite data lives in one module. The renderer asks it to configure a label for `(sprite, frame, flip)`. Nothing else in the game knows about rectangles.

```lua
--!strict
-- Sprites: central registry of sheets, frame rectangles and clips.
local Sprites = {}

export type Frame = {
	offset: Vector2, -- top-left of the frame in sheet pixels
	size: Vector2, -- frame size in sheet pixels (never zero)
	pivot: Vector2, -- canvas offset of this (possibly trimmed) frame; 0,0 if untrimmed
	duration: number, -- seconds this frame is shown
}

export type Clip = {
	name: string,
	frames: { number }, -- indices into the sprite's frame list
	loop: boolean,
	events: { [number]: string }?, -- clip frame position -> event name
}

export type Sprite = {
	image: string, -- "rbxassetid://0000000000"
	frames: { Frame },
	clips: { [string]: Clip },
	canMirror: boolean, -- false: sheet contains its own left-facing frames
}

local registry: { [string]: Sprite } = {}

function Sprites.define(key: string, sprite: Sprite)
	assert(registry[key] == nil, "duplicate sprite " .. key)
	for i, f in sprite.frames do
		assert(f.size.X > 0 and f.size.Y > 0, `sprite {key} frame {i} has zero size`)
	end
	registry[key] = sprite
end

function Sprites.get(key: string): Sprite
	local s = registry[key]
	assert(s, "unknown sprite " .. key)
	return s
end

-- Configure a pooled label to show one frame. Called only when something changed.
function Sprites.apply(label: ImageLabel, key: string, frameIndex: number, flipX: boolean)
	local sprite = Sprites.get(key)
	local f = sprite.frames[frameIndex] or sprite.frames[1]
	if label.Image ~= sprite.image then
		label.Image = sprite.image
	end
	if flipX and sprite.canMirror then
		-- Community technique: negative width mirrors horizontally.
		label.ImageRectOffset = Vector2.new(f.offset.X + f.size.X, f.offset.Y)
		label.ImageRectSize = Vector2.new(-f.size.X, f.size.Y)
	else
		label.ImageRectOffset = f.offset
		label.ImageRectSize = f.size
	end
	label.ScaleType = Enum.ScaleType.Stretch
	label.ResampleMode = Enum.ResamplerMode.Pixelated
end

return Sprites
```

Why validate in `define`: a zero-size frame does not error at runtime, it displays the whole sheet. Catching it at load time with the sprite name and frame number turns a confusing visual bug into a one-line error.

Why the registry owns `image`: when an art update re-uploads the sheet, exactly one string changes. Spreading asset ids across scripts is how half a game ends up on the old sheet.

---

## 6. Importing frame data

Typing rectangles by hand works for ten frames and fails at a hundred. Export data from the art tool and convert it to a Luau table once, in Studio or in your build pipeline ([[Data and Config Pipeline - Spreadsheets to Game]]).

Aseprite's JSON sheet export (array mode) gives, per frame, a `frame` rectangle (`x, y, w, h`), a `duration` in milliseconds, and, when trimming is on, `spriteSourceSize` and `sourceSize`. Animations are `meta.frameTags`, each with `name`, `from`, `to` (0-based frame numbers) and `direction` (`forward`, `reverse`, `pingpong`, and newer versions add more). Check the exact fields against the version of Aseprite you export from; the format has gained fields over time.

A converter you can run in the Studio command bar (paste the JSON into a StringValue first; `HttpService:JSONDecode` parses it):

```lua
--!strict
-- Converts an Aseprite array-mode JSON export into Sprites.define data.
local HttpService = game:GetService("HttpService")

type AseRect = { x: number, y: number, w: number, h: number }
type AseFrame = { frame: AseRect, spriteSourceSize: AseRect?, duration: number }
type AseTag = { name: string, from: number, to: number, direction: string }
type AseJson = { frames: { AseFrame }, meta: { frameTags: { AseTag }? } }

local function convert(json: string, image: string)
	local data = HttpService:JSONDecode(json) :: AseJson
	local frames = {}
	for i, f in data.frames do
		local src = f.spriteSourceSize
		frames[i] = {
			offset = Vector2.new(f.frame.x, f.frame.y),
			size = Vector2.new(f.frame.w, f.frame.h),
			pivot = if src then Vector2.new(src.x, src.y) else Vector2.zero,
			duration = f.duration / 1000,
		}
	end
	local clips = {}
	for _, tag in data.meta.frameTags or {} do
		local list = {}
		for n = tag.from, tag.to do
			table.insert(list, n + 1) -- Aseprite is 0-based, Luau arrays are 1-based
		end
		if tag.direction == "reverse" then
			local reversed = {}
			for i = #list, 1, -1 do
				table.insert(reversed, list[i])
			end
			list = reversed
		elseif tag.direction == "pingpong" then
			for i = #list - 1, 2, -1 do
				table.insert(list, list[i]) -- 1 2 3 4 3 2, then loops to 1
			end
		end
		clips[tag.name] = { name = tag.name, frames = list, loop = true }
	end
	return { image = image, frames = frames, clips = clips, canMirror = true }
end

return convert
```

The JSON decode is untyped, so the cast to `AseJson` is a promise, not a check; a malformed export fails at the field access. That is acceptable in an editor-time tool, never in live game code. Generate a `.luau` data module from the result and commit it, so the game never parses JSON at runtime.

The `+ 1` on frame numbers is the bug every importer has once: Aseprite counts from 0, Luau arrays from 1. Symptom: every animation is one frame late and the last clip borrows the first frame of the next.

---

## 7. The animation player

Two timing models exist and mixing them is the main source of subtle bugs:

| Driven by | Use for | Why |
|---|---|---|
| The fixed simulation step | Anything gameplay reads: attack active frames, invulnerability frames, "the hitbox appears on frame 3" | Same result at every frame rate; replayable; testable |
| Render time | Pure decoration: idle blinks, background fans, flickering torches | Smoother on high refresh rates; nobody depends on it |

The player below runs in the step. It handles per-frame durations, looping and one-shot clips, and returns events crossed during the step (so a footstep or a hitbox spawn fires exactly once, even if a slow frame skipped over it).

```lua
--!strict
-- SpriteAnimator: frame-accurate clip playback in the simulation step.
local Sprites = require(script.Parent.Sprites)

export type AnimState = {
	sprite: string,
	clip: string,
	position: number, -- index into clip.frames (1-based)
	timeInFrame: number, -- seconds spent on the current frame
	speed: number, -- 1 = authored speed
	finished: boolean,
}

local SpriteAnimator = {}

function SpriteAnimator.new(sprite: string, clip: string): AnimState
	return { sprite = sprite, clip = clip, position = 1, timeInFrame = 0, speed = 1, finished = false }
end

-- Switch clip. restart=false keeps playing if already on that clip (run -> run).
function SpriteAnimator.play(state: AnimState, clip: string, restart: boolean?)
	if state.clip == clip and not restart then
		return
	end
	state.clip = clip
	state.position = 1
	state.timeInFrame = 0
	state.finished = false
end

-- Advance by dt. Appends crossed event names to outEvents. Returns the sheet frame index.
function SpriteAnimator.step(state: AnimState, dt: number, outEvents: { string }): number
	local sprite = Sprites.get(state.sprite)
	local clip = sprite.clips[state.clip]
	assert(clip, `sprite {state.sprite} has no clip {state.clip}`)

	if not state.finished then
		state.timeInFrame += dt * state.speed
		local guard = 0
		while guard < 64 do -- bounded: a zero-duration frame must not hang the game
			guard += 1
			local frameIndex = clip.frames[state.position]
			local duration = math.max(sprite.frames[frameIndex].duration, 1 / 240)
			if state.timeInFrame < duration then
				break
			end
			state.timeInFrame -= duration
			if state.position < #clip.frames then
				state.position += 1
			elseif clip.loop then
				state.position = 1
			else
				state.finished = true
				state.timeInFrame = 0
				break
			end
			local events = clip.events
			if events then
				local name = events[state.position]
				if name then
					table.insert(outEvents, name)
				end
			end
		end
	end
	return clip.frames[state.position]
end

return SpriteAnimator
```

How the game uses it, in the step after movement: choose the clip from state (`if not grounded then "jump" elseif math.abs(vx) > 1 then "run" else "idle"`), call `play` without restart, call `step`, write the returned frame into `entity.frame`, and handle events (`"footstep"` plays a sound, `"hit"` spawns the hitbox for this step). The renderer then sees `entity.frame` change and calls `Sprites.apply`.

Nuances:

- **Event on the first frame.** Events fire when a frame is entered by advancing. The first frame of a clip is entered by `play` the first time and by `step` on every loop, so an event on position 1 fires on every loop except the first: a footstep that is silent on the first stride. Either fire position-1 events inside `play` too, or never author events on the first frame (simpler, and the convention in many engines).
- **Restart rules.** Attack clips restart on every press (`restart = true`); locomotion clips never do. Restarting "run" every step freezes the character on frame 1, a bug that looks like "the run animation is broken".
- **Speed from velocity.** Setting `state.speed = math.abs(vx) / runSpeed` makes walking feet match ground speed and stops "moonwalking". Clamp it (for example 0.5 to 1.5) so a slow push does not create a slow-motion run.
- **Frame time units.** Store durations in seconds in the data and keep them per frame. Hand-authored pixel animation almost never uses equal frame times: anticipation frames hold longer, impact frames are short. The timing language for that is in [[Timing Spacing and Frame Charts]].
- **Hit-stop.** Freezing a character on impact means `speed = 0` for a few steps, not pausing the global loop. See [[Hit-Stop and Screen Shake Tuning by Numbers]].

---

## 8. Gameplay data on frames

Fighting games and action platformers put hitboxes and hurtboxes on specific frames. Keep them in the same data as the sprite frames, in canvas coordinates relative to the pivot:

- **Hurtbox**: the area that can be hit. Usually stable per clip; often one box for the whole body is enough.
- **Hitbox**: the attack area, present only on active frames, often growing over two or three frames.

Authoring in canvas space (relative to the pivot) is what makes mirroring work: when facing left, negate the box's x offset around the pivot. Authoring boxes in sheet space, or relative to the trimmed rectangle, makes boxes drift as frames change size.

Simple tools beat clever ones: a debug overlay that draws hitboxes as translucent red frames and hurtboxes as green, toggled with a key in Studio, finds more problems than any amount of reading data files.

---

## 9. Effects, palettes and tinting

- **Tint with `ImageColor3`.** A white flash on hit is easiest as a dedicated white-silhouette frame set; `ImageColor3` only multiplies, so it can darken or colour a sprite but cannot make it brighter than the source. Multiplying a white sprite by a colour gives you palette variants of one-colour enemies for free.
- **Fade with `ImageTransparency`**, not by toggling `Visible` quickly; blinking invulnerability at 10 to 15 Hz reads clearly (rule of thumb), but offer a reduced-flashing option ([[Accessibility]]).
- **Palette swaps** (alternate costume colours) are not possible on GPU in GUI. Either export each palette as its own sheet (memory cost per variant) or recolour at load time into an `EditableImage` ([[EditableImage for Pixel Buffers and Procedural 2D]]), which has its own budget and permission rules.

---

## 10. Common mistakes

- **Per-frame `Image` swaps.** Symptom: blank or flickering frames the first time each animation plays.
- **Sheets over the size limit.** Symptom: every frame is offset or shows parts of its neighbours after upload, though the source file looks right.
- **Rectangles in GUI pixels instead of image pixels.** Symptom: wrong crop when the label is scaled.
- **No padding.** Symptom: thin lines from adjacent frames at some zoom levels or on some devices.
- **Trimmed frames without pivots.** Symptom: the character jitters or hops between frames while standing still.
- **0-based frame numbers.** Symptom: everything plays one frame late; last frame of one clip leaks into the next.
- **Gameplay events driven by render time.** Symptom: attacks hit on different frames at 30 and 144 fps; replays desync.
- **Locomotion clips restarting every step.** Symptom: frozen on frame 1 while moving.
- **Asymmetric sprites mirrored.** Symptom: the weapon swaps hands when the character turns.

---

## 11. Checklist

- [ ] One sheet per character (or per animation group), at or below 1024 x 1024, tightly packed.
- [ ] 1 to 2 pixels of padding or extrusion between frames.
- [ ] Frame data imported from the art tool, converted to a committed Luau module, validated (no zero sizes).
- [ ] Every frame has a pivot; trimmed frames are offset correctly.
- [ ] `ResampleMode = Pixelated` and `ScaleType = Stretch` on sprite labels.
- [ ] Mirroring behind one function; negative-size trick tested on every platform, or mirrored frames in the sheet.
- [ ] Gameplay-relevant animation stepped in the fixed simulation step; decoration may use render time.
- [ ] Clip events fire once per crossing, never on the first frame unless `play` handles it.
- [ ] Hitboxes and hurtboxes authored relative to the pivot, mirrored with the sprite, visible in a debug overlay.
- [ ] Sheets preloaded before gameplay; a moderation rejection shows up as a clear error, not a blank character.

## See also

- [[2D Game Development Start Here]]
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]
- [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]
- [[2D Collision Physics and Platformer Movement]]
- [[UI and GUI Animation]]
- [[Textures Decals and Texture Memory]]
- [[Principles of Animation for Games]]

## Connected notes
<!-- auto-links:start -->
[[Tilemaps Cameras and Parallax for 2D Levels]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Texel Density]] · [[UV Unwrapping]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Tiling Trim Sheets and Decal Tricks]]
<!-- auto-links:end -->
