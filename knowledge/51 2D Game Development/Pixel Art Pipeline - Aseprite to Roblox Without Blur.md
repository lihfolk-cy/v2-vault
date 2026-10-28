---
tags: [2d, pixel-art, aseprite, sprites, atlas, textures, ui, resampling, moderation, pipeline, luau]
---
# Pixel Art Pipeline - Aseprite to Roblox Without Blur

<!-- tldr:start -->
> [!tldr] TL;DR
> - Sprite soft everywhere: `ResampleMode` left at Default -> Property on the ImageLabel itself, not a parent
> - Uneven pixel columns, wobble while walking: Non-integer scale or Scale-based sizing -> Every size is `fromOffset(w * scale, ...)`, no UIScale above
> - One-pixel line from the next frame: No spacing or extrusion -> Re-export with `--shape-padding 2 --extrude`
> - One base pixel size and one virtual resolution decided and written down.
> - Hard alpha, exact palette, tags and frame durations in the Aseprite source.
> - Export with spacing and extrusion; JSON converted to a typed Luau module; no pre-scaling for GUI art.
>
> Cost: TL;DR ~200 tok · whole note ~5.6k tok. Read more: ## 4. Atlas packing without bleeding · ## 5. Integer scaling on every screen · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

Pixel art fails on Roblox in a predictable way: you draw a crisp 16 by 16 sprite, upload it, put it in an ImageLabel, and it shows up as a soft smudge with a faint halo, or it looks sharp in Studio and shimmers on a phone. None of this is mysterious. Blur comes from four places: the resampling filter, non-integer scale, sub-pixel placement, and the engine choosing a lower quality version of the texture. Halos and bleeding come from the atlas layout. This note walks the whole path from the Aseprite file to a sharp sprite on every device, and covers the parts people forget: upload limits, moderation, atlas metadata, and 3D surfaces that have no pixel filter at all.

Related: [[Sprite Sheets and Frame Animation with ImageRectOffset]] for animation playback, [[Textures Decals and Texture Memory]] for memory, [[UI Asset Pipeline]] for the general UI art workflow, and [[EditableImage for Pixel Buffers and Procedural 2D]] for drawing pixels at runtime.

---

## 1. Where the blur comes from

| Source | What you see | Fix |
|---|---|---|
| Bilinear resampling (the default) | Soft edges, colours mixing between neighbouring pixels | `ResampleMode = Enum.ResamplerMode.Pixelated` on ImageLabel and ImageButton |
| Non-integer scale (for example 16 px drawn at 37 px) | Uneven pixel widths: some columns 2 wide, some 3 wide; "wobbling" when moving | Scale by whole numbers only; size in offset, not scale |
| Sub-pixel position | Sprites shimmer or a column flickers while moving | Round positions to the integer pixel grid of your scaled world |
| Engine quality ramping and downsampling | Sharp on PC, soft on low end phones, or soft for the first seconds | Keep source textures small; pixel art needs very little memory anyway |
| Atlas bleeding | A thin line of the neighbouring frame along one edge | Spacing plus extrusion in the export |
| Semi-transparent edge pixels | Grey or dark fringes around sprites | Hard alpha: every pixel fully opaque or fully transparent |

The ImageLabel docs describe the default resampling as smoothing the image when it is scaled, and say that with `Enum.ResamplerMode.Pixelated` "the image preserves the sharp edges of pixels" (Roblox docs (as of October 2026)). That single property removes the worst blur, but only the first row of the table. The rest is your job.

---

## 2. Authoring in Aseprite

### 2.1 Canvas and palette decisions

- **Pick one base pixel size for the whole game** and stick to it: 16 by 16 tiles with 16 to 32 pixel characters is the common choice. Mixed pixel densities (a 32 px character next to 16 px tiles drawn at the same size) look wrong even when every image is sharp.
- **Pick a virtual resolution**: the size of the world you design in, in source pixels. 320 by 180 and 384 by 216 both scale to 1920 by 1080 by whole numbers (6 and 5). 256 by 144 scales by 5 to 1280 by 720. Your on-screen scale factor is decided at runtime, but the design resolution decides how much level fits on screen.
- **Use an indexed palette** if you plan palette swaps. Roblox cannot read Aseprite's palette, but keeping colours exact (no near duplicates) makes runtime recolouring with [[EditableImage for Pixel Buffers and Procedural 2D]] reliable, because you can match colours by exact RGB.
- **Hard alpha only.** Anti-aliased edges against transparency produce fringes as soon as the image is drawn over a different background. If you want soft edges, draw them in-game with a separate effect layer.

### 2.2 Frames, tags and slices

Name animations with tags (`idle`, `run`, `jump`) and keep durations on the frames. Aseprite stores per-frame durations and exports them in the JSON metadata, so animators can tune timing without a programmer. Use slices for nine-slice UI panels: the slice's centre rectangle becomes `SliceCenter` later.

### 2.3 Exporting the sheet

Aseprite's command line interface does everything needed in one call (flags verified against the Aseprite CLI documentation, as of October 2026):

```
aseprite -b hero.aseprite --sheet hero.png --data hero.json --format json-array --sheet-type packed --shape-padding 2 --extrude --list-tags --ignore-empty --merge-duplicates
```

- `--format json-array` gives a stable ordered frame list; `json-hash` (the default) keys frames by filename.
- `--sheet-type packed` uses a packing algorithm to reduce wasted space; `rows` or `columns` keep a predictable grid, which is easier to debug and needed if you compute frame rectangles by arithmetic instead of from JSON.
- `--shape-padding N` adds empty space between frames, and `--extrude` duplicates each edge pixel outward by one pixel. Together they stop bleeding (section 4).
- `--merge-duplicates` reuses identical frames, which matters in long idle animations.
- Do not use `--scale`. Upscaling before upload multiplies memory by the square of the factor and gains nothing in a GUI where `Pixelated` handles scaling. The exception is 3D surfaces (section 6).
- `--trim` saves space but changes each frame's size and offset; your runtime must then apply the `spriteSourceSize` offsets from the JSON or the character will jitter between frames. Skip trimming for characters unless memory is tight; it is safe for icons.

---

## 3. Size limits and how big a sheet should be

The texture specifications page currently states both "Roblox supports up to 4096×4096 pixel texture resolutions (4K)" and, in the UV mapping section, "up to 1024×1024 pixel spaces for texture maps"; it also says the engine "starts with lower quality versions of the texture and ramps up quality" and that Roblox "may downsample textures to optimize for performance" when many textures render at once (Roblox docs (as of October 2026)). The page does not say how image uploads used in GUIs are handled above 1024. Treat **1024 by 1024 as the safe ceiling for any sheet** (rule of thumb) and check the uploaded result in-game if you go larger.

For pixel art this ceiling is generous:

| Sheet size | 16 x 16 tiles it holds | 32 x 32 frames it holds | Uncompressed RGBA in memory |
|---|---|---|---|
| 256 x 256 | 256 | 64 | 256 KB |
| 512 x 512 | 1,024 | 256 | 1 MB |
| 1024 x 1024 | 4,096 | 1,024 | 4 MB |

(Memory column is width x height x 4 bytes, rule of thumb; GPU formats and mip levels change the real number.)

Downsampling is the hidden enemy. Bilinear downsampling of a 1024 sheet to 512 on a low end device destroys pixel art completely, and `Pixelated` cannot recover pixels that were averaged away. Small sheets are less likely to be the target of memory driven downsampling (rule of thumb, not documented), and they load faster. So the guidance is the opposite of most texture advice: **upload pixel art at its native size, never pre-scaled**, and group it into a few 256 to 1024 sheets by what is on screen together (one for the player, one per tileset, one for UI).

---

## 4. Atlas packing without bleeding

### 4.1 Why bleeding happens

`ImageRectOffset` and `ImageRectSize` choose a rectangle of the image to display (Roblox docs (as of October 2026)). When that rectangle is drawn at a scale that is not a whole number, or at a position that is not on a whole pixel, the sampler can read a texel just outside the rectangle at the edges. With bilinear filtering the result is a faint line of the neighbouring frame; with `Pixelated` it is usually a full one pixel line of it, which is worse because it is crisp. Integer scale and pixel snapping remove most of it. Padding and extrusion remove the rest:

- **Spacing (shape padding)** of 2 pixels between frames means a stray sample hits empty transparent pixels instead of a neighbour.
- **Extrusion** copies each frame's edge pixels outward, so a stray sample at the edge reads the same colour. This matters most for tiles, which must touch edge to edge without a visible seam.

For tiles, use both. For characters with transparent borders, spacing alone is enough.

### 4.2 Turning the JSON into a Luau module

Do not parse JSON at runtime. Convert the Aseprite JSON into a Luau ModuleScript in your build step (or once by hand for small projects), so frame data is typed and loads instantly. The converter can be any tool your pipeline uses; what matters is the output shape. A generated module looks like this:

```lua
--!strict
-- ModuleScript: ReplicatedStorage.Atlases.Hero (generated, do not edit by hand)
export type Frame = {
	x: number,
	y: number,
	w: number,
	h: number,
	durationMs: number,
	-- Offset of the trimmed frame inside the untrimmed cell (0, 0 if untrimmed).
	ox: number,
	oy: number,
}

export type Atlas = {
	image: string,
	sheetW: number,
	sheetH: number,
	cellW: number,
	cellH: number,
	frames: { Frame },
	tags: { [string]: { from: number, to: number } },
}

local atlas: Atlas = {
	image = "rbxassetid://0000000000",
	sheetW = 256,
	sheetH = 128,
	cellW = 32,
	cellH = 32,
	frames = {
		{ x = 1, y = 1, w = 32, h = 32, durationMs = 120, ox = 0, oy = 0 },
		{ x = 36, y = 1, w = 32, h = 32, durationMs = 120, ox = 0, oy = 0 },
		{ x = 71, y = 1, w = 32, h = 32, durationMs = 90, ox = 0, oy = 0 },
	},
	-- Aseprite tag ranges are 0 based; the converter adds 1 for Luau arrays.
	tags = {
		idle = { from = 1, to = 2 },
		run = { from = 3, to = 3 },
	},
}

return table.freeze(atlas)
```

Note the `x = 1, y = 1`: with `--extrude` and padding, frames do not start at zero, which is exactly why reading rectangles from metadata is safer than multiplying cell indices. Keep the asset id in the module, not scattered through scripts, so re-uploading a sheet is a one line change (see [[Asset Upload Automation with Open Cloud]] if you automate uploads).

### 4.3 Applying a frame crisply

```lua
--!strict
-- ModuleScript: ReplicatedStorage.PixelSprite
local PixelSprite = {}

export type Frame = {
	x: number, y: number, w: number, h: number,
	durationMs: number, ox: number, oy: number,
}
export type Atlas = {
	image: string, sheetW: number, sheetH: number,
	cellW: number, cellH: number,
	frames: { Frame },
	tags: { [string]: { from: number, to: number } },
}

-- Prepare an ImageLabel for pixel art. Call once.
function PixelSprite.setup(label: ImageLabel, atlas: Atlas)
	label.Image = atlas.image
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.ScaleType = Enum.ScaleType.Stretch
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	-- AnchorPoint 0, 0 keeps the top-left corner on whole pixels.
	label.AnchorPoint = Vector2.zero
end

-- Show one frame at an integer scale, at a position in source pixels.
-- `scale` must be a whole number; `px`, `py` are world pixels already
-- relative to the camera.
function PixelSprite.show(label: ImageLabel, atlas: Atlas, frameIndex: number, px: number, py: number, scale: number, flipX: boolean?)
	local f = atlas.frames[frameIndex]
	if not f then
		return
	end
	assert(scale == math.floor(scale) and scale >= 1, "pixel scale must be a whole number")

	label.ImageRectSize = Vector2.new(f.w, f.h)
	if flipX then
		-- Negative size flips the image horizontally; offset moves to the right edge.
		label.ImageRectOffset = Vector2.new(f.x + f.w, f.y)
		label.ImageRectSize = Vector2.new(-f.w, f.h)
	else
		label.ImageRectOffset = Vector2.new(f.x, f.y)
	end

	-- Snap to the source pixel grid first, then scale: every sprite pixel
	-- lands on exactly `scale` screen units.
	local sx = math.round(px + f.ox) * scale
	local sy = math.round(py + f.oy) * scale
	label.Position = UDim2.fromOffset(sx, sy)
	label.Size = UDim2.fromOffset(f.w * scale, f.h * scale)
end

return PixelSprite
```

The horizontal flip with a negative `ImageRectSize` is a long standing community technique, not something the ImageLabel page documents (unverified as of October 2026). If it misbehaves on a device you care about, export mirrored frames instead; it costs sheet space but no risk.

---

## 5. Integer scaling on every screen

### 5.1 Choosing the scale

Put the whole playfield inside one Frame (the "screen") sized in offset pixels. Compute the largest whole number scale that fits the virtual resolution into the usable viewport, and centre the result with letterbox bars:

```lua
--!strict
-- ModuleScript: ReplicatedStorage.PixelViewport
local PixelViewport = {}

export type Fit = { scale: number, width: number, height: number, offsetX: number, offsetY: number }

-- virtualW/H: design resolution in source pixels (for example 320 x 180).
-- available: usable size in GUI offset units (AbsoluteSize of a full-screen frame
-- that already respects safe areas).
function PixelViewport.fit(virtualW: number, virtualH: number, available: Vector2): Fit
	local scale = math.max(1, math.floor(math.min(available.X / virtualW, available.Y / virtualH)))
	local width = virtualW * scale
	local height = virtualH * scale
	return {
		scale = scale,
		width = width,
		height = height,
		offsetX = math.floor((available.X - width) / 2),
		offsetY = math.floor((available.Y - height) / 2),
	}
end

-- Keep `screen` letterboxed inside `container`, refitting when the window changes.
function PixelViewport.bind(container: GuiObject, screen: Frame, virtualW: number, virtualH: number, onScale: (number) -> ()): RBXScriptConnection
	local function refit()
		local fit = PixelViewport.fit(virtualW, virtualH, container.AbsoluteSize)
		screen.AnchorPoint = Vector2.zero
		screen.Position = UDim2.fromOffset(fit.offsetX, fit.offsetY)
		screen.Size = UDim2.fromOffset(fit.width, fit.height)
		screen.ClipsDescendants = true
		onScale(fit.scale)
	end
	refit()
	return container:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
end

return PixelViewport
```

Letterboxing feels wasteful on wide phones. Two alternatives: let the extra width show more level (compute an integer scale from the height only and widen the virtual width to fill), or fill bars with a dark pattern so they read as a frame. Showing more level on wide screens is the usual choice; keep gameplay threats inside the base width so it stays fair.

### 5.2 Never put a UIScale on the playfield

`UIScale` and Scale-based `UDim2` sizes produce fractional sizes. A HUD can use them; the pixel playfield must not, or every sprite becomes a non-integer multiple again. Keep the playfield in its own ScreenGui with nothing scaling it (see [[ScreenGui Fundamentals]]).

### 5.3 The device pixel caveat

GUI offset units on Roblox are not guaranteed to equal physical screen pixels: on high density phones the engine scales the GUI coordinate space (rule of thumb; the exact mapping is not documented as of October 2026). That means "integer scale in GUI units" can still be a fractional scale in physical pixels. In practice this matters less as the scale grows: at scale 4 or more a stray physical pixel is hard to see, while at scale 1 or 2 it is obvious. If you see uneven pixel columns on a particular phone, raise the minimum scale (design at a smaller virtual resolution) rather than chasing the device ratio. Test on a real phone, not only the Studio device emulator.

### 5.4 Pixel snapping the camera

A camera that moves by fractional pixels makes the whole world shimmer as different columns round differently each frame. Keep the camera position as a float for smoothing, but round it to whole source pixels when you compute sprite positions, exactly as `PixelSprite.show` rounds before multiplying. Snapping before scaling, never after, is the key detail. More on camera behaviour in [[Tilemaps Cameras and Parallax for 2D Levels]].

---

## 6. Pixel art on 3D surfaces

`Decal` and `Texture` have no resampling property; the Decal page lists colour, content, PBR maps, UV offset and scale, but nothing for filtering (Roblox docs (as of October 2026)). Meshes with a texture are filtered the same way. Three working options for a 2.5D game:

1. **SurfaceGui with a Pixelated ImageLabel.** A SurfaceGui on a part renders GUI objects on the surface, and ImageLabel keeps its `ResampleMode`. This is the cleanest way to show crisp sprites in a 3D world: signs, billboards of sprites, flat characters. Set `PixelsPerStud` so one sprite pixel maps to a whole number of GUI pixels. See [[World-Space UI - BillboardGui and SurfaceGui]].
2. **Pre-scale the texture by nearest neighbour.** Export the sprite at 8x or 16x with nearest neighbour scaling. The engine still filters, but the blur is now confined to the edge between two big blocks, which reads as slightly soft rather than smeared. Memory cost grows with the square of the factor: a 64 x 64 texture at 16x is 1024 x 1024, 4 MB uncompressed. Use this for a few hero textures only.
3. **Build with geometry.** Voxel style parts or meshes with per-face colours avoid textures entirely. See [[Voxel and Blocky Modeling]] and [[Trim Sheets Atlases and Vertex Colors]].

Lighting also softens pixel art in 3D: specular highlights and shadows across a sprite flat break the look. For sprite flats set the material to something matte, consider `Lighting` that is mostly ambient, and turn off `CastShadow` on the flats.

---

## 7. Uploading and moderation

Every image you upload is reviewed by Roblox moderation, and the ImageLabel docs note that "Images declined by moderation will never load" (`IsLoaded` stays false) (Roblox docs (as of October 2026)). Pixel art meets some specific failure modes:

- **Tiny sprites are ambiguous.** A 16 pixel character in a skin tone palette with a few dark pixels can be read as something it is not, especially on a sheet of hundreds. If one sheet is rejected, every frame on it is gone; that is a reason to keep sheets grouped by feature (a rejected effects sheet should not take the player character down with it).
- **Text in images.** Bitmap fonts and signs with words are reviewed like any text. Avoid usernames, contact details, real brands and real people.
- **Real IP.** Recognisable characters from other games are a moderation and a copyright problem; see [[Legal Basics - IP Licenses and Assets]].
- **Keep the sources.** Moderation outcomes on resubmission vary; keep the Aseprite source so you can adjust colours or split the sheet and re-upload.
- **Detect failures in-game.** In development builds, check `IsLoaded` on a timer after setup and log any sheet that never loads, so a rejected upload shows up as a clear warning instead of an invisible character.

Bulk uploading is available through Studio's Asset Manager and through Open Cloud; see [[Asset Upload Automation with Open Cloud]] and [[Links - Image uploading and moderation]]. Upload into the same owner (user or group) that owns the experience; ownership matters for runtime loading through EditableImage (section 8) even when plain display works.

---

## 8. Recolouring and palette swaps

- **`ImageColor3` multiplies.** It tints the whole image. It works for white or greyscale sprites (team colours on a white shirt) but cannot map one specific colour to another.
- **Separate layers.** Export the recolourable parts as a separate greyscale layer sheet and stack two ImageLabels: the base, and the tinted overlay. Two draws per sprite, no runtime image work.
- **Runtime palette swap.** Load the sheet into an `EditableImage` with `AssetService:CreateEditableImageAsync`, remap exact colours, and display it. This requires the Mesh / Image APIs to be enabled for the experience and the asset to be owned by or shared with the experience owner (Roblox docs (as of October 2026)). Full details in [[EditableImage for Pixel Buffers and Procedural 2D]].

---

## 9. When not to do this

- **Your art is not pixel art.** Painted or vector-style art should stay on the default resampling; `Pixelated` makes smooth art look jagged when scaled.
- **HUD and menus.** A pixel art game can still use smooth, standard UI for menus, settings and purchase prompts. Players read standard UI faster, and pixel fonts at small sizes hurt accessibility (see [[Accessibility]]).
- **Very high scale on small screens.** If a phone only fits scale 2, a 16 px character is 32 GUI units tall, which may be too small to see. Choose a smaller virtual resolution for phones rather than shrinking art.

---

## 10. Common mistakes

| Symptom | Likely cause | Check |
|---|---|---|
| Sprite soft everywhere | `ResampleMode` left at Default | Property on the ImageLabel itself, not a parent |
| Uneven pixel columns, wobble while walking | Non-integer scale or Scale-based sizing | Every size is `fromOffset(w * scale, ...)`, no UIScale above |
| One-pixel line from the next frame | No spacing or extrusion | Re-export with `--shape-padding 2 --extrude` |
| Character jitters between frames | Trimmed export without offsets | Apply `ox`, `oy` or export untrimmed |
| Dark fringe around sprites | Semi-transparent edge pixels | Remove partial alpha in Aseprite |
| Sharp on PC, mush on a phone | Engine downsampled a big sheet | Upload native size, split large sheets |
| Invisible sprite only in live game | Upload declined by moderation | `IsLoaded` check, review the sheet |
| Seams between tiles while scrolling | Camera not snapped to whole pixels | Round camera before multiplying by scale |

---

## 11. Checklist

- [ ] One base pixel size and one virtual resolution decided and written down.
- [ ] Hard alpha, exact palette, tags and frame durations in the Aseprite source.
- [ ] Export with spacing and extrusion; JSON converted to a typed Luau module; no pre-scaling for GUI art.
- [ ] Sheets at most 1024 x 1024, grouped by feature, uploaded at native size to the experience owner.
- [ ] Every sprite ImageLabel uses `Pixelated`, AnchorPoint zero, offset sizes, integer scale.
- [ ] Positions and the camera snapped to whole source pixels before scaling.
- [ ] Playfield in its own ScreenGui with no UIScale; letterbox or extended width decided.
- [ ] 3D sprites use SurfaceGui or nearest neighbour pre-scaled textures, matte and shadowless.
- [ ] `IsLoaded` watchdog in development to catch rejected uploads.
- [ ] Tested on at least one real high density phone.

## See also

[[Choosing GUI 2D or Locked-Camera 2.5D]], [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]], [[Art Pipeline - Concept to In-Game Asset]], [[Rendering Performance]], [[Mobile and Low-End Optimization]].

## Connected notes
<!-- auto-links:start -->
[[2D Game Development Start Here]] · [[The Gradient Palette Texture Workflow]] · [[Texel Density]] · [[SurfaceAppearance PBR Workflow]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[UV Unwrapping]]
<!-- auto-links:end -->
