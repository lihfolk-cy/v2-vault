---
tags: [pipelines, icons, thumbnails, blender, rendering, post-processing, ui]
---
# Icon and Thumbnail Rendering Pipeline

Item icons are the most-viewed art in most Roblox games: every inventory slot, shop card, drop popup and trade window shows them. A collection game with 150 items needs 150 icons that look like one set, and needs to re-render all of them when the style changes. Hand-made screenshots do not survive that. This note is the recipe for a rendered icon pipeline (Blender, background mode, two passes, scripted post-processing, upload, ids written into config), based on the one a production game used to render and reinstall well over a hundred weapon icons several times. The second half covers experience thumbnails and the store icon, which are a different job. Store page strategy is in [[Thumbnails Icons and Store Page]]; AI-generated art is in [[AI Image Generation for Icons Thumbnails and Concepts]].

## Why render, not screenshot

| Approach | Consistency | Re-render cost | Quality | Use for |
|---|---|---|---|---|
| Studio screenshot or ViewportFrame capture | depends on the person | manual per item | engine lighting, aliasing | prototypes |
| Live ViewportFrame in the UI | perfect (it is the model) | none | engine quality, costs memory and draw calls per slot | a few hero previews (a shop card, a detail panel) |
| Blender render from the source model | scripted, identical framing | minutes for the whole set | best: AA, glow, outline control | every inventory icon |
| Hand-painted | artist-dependent | very high | can be best | small sets, logos |

The reference project used live ViewportFrames only where motion mattered (a rotating character preview on one shop card, with the icon as a fallback) and rendered icons for everything else. A ViewportFrame per inventory slot is a common performance mistake: 60 slots means 60 extra scene renders.

## The stages

| # | Stage | Input | Output | Tool |
|---|---|---|---|---|
| 1 | Collect the look | source `.glb`, plus the in-game look (colours, materials, which parts are visible) | `parts_<id>.json` | Studio exporter posting to a local receiver |
| 2 | Build tables | GLB + look JSON | per-item config: which parts are solid, which glow, which hide | Python in background Blender |
| 3 | Render | config + GLB | `<id>_beauty.exr`, `<id>_emit.exr` | `blender -b --python render.py` |
| 4 | Post-process | the two passes | `<id>.png` (final) and `<id>_prev.png` (preview) | numpy (in Blender's Python or standalone) |
| 5 | Review | PNGs | approved list | contact sheet, human |
| 6 | Upload | approved PNGs | image asset ids, id map JSON | Studio image upload or Open Cloud |
| 7 | Install | id map | config rows updated (`Art = "rbxassetid://..."`) | one-insert config edit |
| 8 | Record | | changelog, id map committed | |

One driver script (`icons.ps1 -id <id>` in the reference project) chained stages 1 to 4 for a single item in about 20 seconds per item in batch, or 2 to 3 minutes including Blender start-up for a single icon (measured in one production game).

## Stage 1: icons must match the game, not the source file

The first version of the pipeline rendered straight from the GLB. Icons then disagreed with the game wherever the game changed something after import: a recoloured blade, a part hidden in game, a material swapped. The fix was to **export the in-game look** from Studio (each part's colour, material, transparency, and whether it is visible) and merge it over the GLB's data. A Studio stage serialised that to JSON and posted it to a small local HTTP receiver on the artist's machine ([[Studio Plugins and Local HTTP Bridges]]).

Two later fixes in the same project are worth copying:

- **Hide what the game hides.** A glow fix hid parts the game keeps invisible (Transparency 0.85 or more hidden; Neon parts between 0 and 0.85 rendered see-through), read from an export of the live models' transparency.
- **Decide what belongs in an icon by rule, not by eye.** The icon rule became: the whole weapon (every part touching the blade, hilt, guard or pommel chain within 0.05 studs that does not circle the blade, so guard rings, gears and armillaries show) plus a hint of particles, but **never** orbiting or floating extras (orbiting gems, halos, loose chains, portal rings). A script decided this per rigid group from an export of the live rigs. One icon had been missing its clock-ring guard because an earlier name-based rule hid it; the group-based rule fixed 21 icons at once.

## Stage 2 and 3: render two passes in background Blender

Render the item twice in one go: the normal **beauty** pass (lit, with transparency) and an **emission** pass (only what glows). Keeping glow separate is what lets post-processing add bloom in the item's own colour without blowing the whole image out to white.

Framing rules the reference project standardised (measured in one production game): **82% fill, 45-degree diagonal, centred**, transparent background, the same camera and lights for every item. Fill is computed from the item's bounds, so a dagger and a greatsword both fill the frame.

```python
# render.py  (blender -b --factory-startup --python render.py -- <glb> <out_dir> <id> [size])
# Renders <id>_beauty.exr and <id>_emit.exr. Written against the Blender 4.x Python API;
# Blender 5 moved compositor trees to node groups, so check the API changelog for your version.
import sys, math, os, bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, out_dir, item_id = argv[0], argv[1], argv[2]
size = int(argv[3]) if len(argv) > 3 else 512
FILL = 0.82

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

# Hide parts the game hides (list produced in stage 2)
hide_path = os.path.join(out_dir, f"{item_id}_hide.txt")
if os.path.exists(hide_path):
    hidden = set(open(hide_path, encoding="utf-8").read().split())
    for o in meshes:
        if o.name in hidden:
            o.hide_render = True
meshes = [o for o in meshes if not o.hide_render]

# Group under one empty and lay the item on a 45 degree diagonal
root = bpy.data.objects.new("IconRoot", None)
bpy.context.scene.collection.objects.link(root)
for o in meshes:
    if o.parent is None:
        o.parent = root
root.rotation_euler = (0.0, math.radians(45.0), 0.0)  # adjust to your model's long axis
bpy.context.view_layer.update()

# World-space bounds of the visible meshes
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
centre = (lo + hi) / 2

# Orthographic camera looking down -Y at the centre; ortho_scale sets the fill
cam_data = bpy.data.cameras.new("IconCam")
cam_data.type = "ORTHO"
extent = max(hi.x - lo.x, hi.z - lo.z)
cam_data.ortho_scale = extent / FILL
cam = bpy.data.objects.new("IconCam", cam_data)
cam.location = (centre.x, centre.y - 100.0, centre.z)
cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

# Simple three-point light rig, identical for every item
def sun(name, energy, rot):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy
    o = bpy.data.objects.new(name, d); o.rotation_euler = [math.radians(a) for a in rot]
    bpy.context.scene.collection.objects.link(o)
sun("Key", 3.0, (50, 0, 30)); sun("Fill", 1.0, (60, 0, -120)); sun("Rim", 2.0, (-30, 0, 180))

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = size * 2   # render 2x, downsample in post
scene.render.film_transparent = True
scene.view_layers[0].use_pass_emit = True

# Compositor: write the combined image and the emission pass as separate EXRs
scene.use_nodes = True
tree = scene.node_tree
tree.nodes.clear()
rl = tree.nodes.new("CompositorNodeRLayers")
fo = tree.nodes.new("CompositorNodeOutputFile")
fo.base_path = out_dir
fo.format.file_format = "OPEN_EXR"
fo.format.color_depth = "16"
fo.file_slots.clear()
fo.file_slots.new(f"{item_id}_beauty")
fo.file_slots.new(f"{item_id}_emit")
tree.links.new(rl.outputs["Image"], fo.inputs[0])
tree.links.new(rl.outputs["Emit"], fo.inputs[1])
bpy.ops.render.render(write_still=False)
print("RENDERED", item_id)
```

Notes on the script:

- The File Output node appends a frame number to file names (`<id>_beauty0001.exr`); the post script should glob for it.
- Render at twice the final size and downsample in post: cheap anti-aliasing and crisper outlines.
- Use `--factory-startup` so the artist's own preferences and add-ons never change the result.
- On Windows, keep every path under 260 characters (use the short 8.3 form of deep folders): Blender failed to open longer paths in the reference project.
- Blender prints deprecation warnings to stderr. A PowerShell driver with `$ErrorActionPreference = "Stop"` will abort on them; use `Continue` and check for the output file instead.

## Stage 4: post-process (outline, bloom, sparkles)

Post-processing is what makes rendered icons read at 64 px in a busy grid. Three effects, in order:

1. **Outline**: dilate the alpha by a few pixels and fill the ring with a dark ink colour. Outlines separate the icon from any card colour.
2. **Bloom**: blur the emission pass and add it back **in its own hue**. The reference project's rule was "glow keeps its hue (no blown-out white)": tone-map the bloom so a cyan blade stays cyan.
3. **Sparkles**: a few small four-point stars on the brightest emissive pixels, from a seeded random generator so re-renders are identical.

```python
# post.py  (blender -b --factory-startup --python post.py -- <dir> <id> <final_px>)
# Pure numpy on images loaded through bpy, so it needs no extra Python packages.
import sys, glob, os, zlib, bpy, numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
d, item_id, final_px = argv[0], argv[1], int(argv[2])

def load(pattern):
    path = sorted(glob.glob(os.path.join(d, pattern)))[-1]
    img = bpy.data.images.load(path)
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    return buf.reshape(h, w, 4)

beauty = load(f"{item_id}_beauty*.exr")
emit = load(f"{item_id}_emit*.exr")[..., :3]

def blur(a, r):
    # separable box blur, applied 3 times = close to a gaussian
    for _ in range(3):
        k = 2 * r + 1
        p = np.pad(a, ((r, r), (0, 0)) + ((0, 0),) * (a.ndim - 2), mode="edge")
        c = np.cumsum(p, axis=0); a = (c[k - 1:] - np.concatenate([np.zeros_like(c[:1]), c[:-k]])) / k
        p = np.pad(a, ((0, 0), (r, r)) + ((0, 0),) * (a.ndim - 2), mode="edge")
        c = np.cumsum(p, axis=1); a = (c[:, k - 1:] - np.concatenate([np.zeros_like(c[:, :1]), c[:, :-k]], axis=1)) / k
    return a

def dilate(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out = np.maximum(out, np.roll(np.roll(mask, dy, 0), dx, 1))
    return out

rgb, alpha = beauty[..., :3], beauty[..., 3]
H, W = alpha.shape
s = W / 512.0                                   # effects scale with render size

# 1. outline
ink = np.array([0.04, 0.05, 0.09], np.float32)
ring = np.clip(dilate((alpha > 0.5).astype(np.float32), int(6 * s)) - alpha, 0, 1)
out_rgb = rgb * alpha[..., None] + ink * ring[..., None]
out_a = np.clip(alpha + ring, 0, 1)

# 2. bloom in the emission's own hue: normalise colour, keep brightness soft
glow = blur(emit, int(10 * s))
lum = glow.max(axis=2, keepdims=True)
hue = glow / np.maximum(lum, 1e-6)
bloom = hue * (1.0 - np.exp(-1.6 * lum))          # soft knee, never exceeds the hue
out_rgb = out_rgb + bloom * (1.0 - out_rgb)       # screen blend
out_a = np.maximum(out_a, np.clip(lum[..., 0] * 1.2, 0, 1))

# 3. sparkles on the brightest emissive pixels, seeded by id
rng = np.random.default_rng(zlib.crc32(item_id.encode()))  # stable across runs
ys, xs = np.nonzero(emit.max(axis=2) > np.percentile(emit.max(axis=2), 99.5))
for i in rng.choice(len(ys), size=min(4, len(ys)), replace=False) if len(ys) else []:
    y, x, L = ys[i], xs[i], int(rng.integers(8, 16) * s)
    col = hue[y, x]
    for t in range(-L, L + 1):
        f = 1.0 - abs(t) / (L + 1)
        for yy, xx in ((y + t, x), (y, x + t)):
            if 0 <= yy < H and 0 <= xx < W:
                out_rgb[yy, xx] = np.maximum(out_rgb[yy, xx], col * f + (1 - f) * out_rgb[yy, xx])
                out_a[yy, xx] = max(out_a[yy, xx], f)

# downsample 2x (box) and save PNG
def half(a): return (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4
final = np.dstack([half(np.clip(out_rgb, 0, 1)), half(out_a)])
img = bpy.data.images.new(f"{item_id}_final", final.shape[1], final.shape[0], alpha=True)
img.pixels.foreach_set(final.astype(np.float32).ravel())
img.filepath_raw = os.path.join(d, f"{item_id}.png")
img.file_format = "PNG"
img.save()
print("ICON", img.filepath_raw)
```

x is salted per process, so for truly stable sparkles use a fixed hash such as `zlib.crc32(item_id.encode())` instead; the reference project seeded by id.

The numbers (outline 6 px at 512, bloom radius 10 px, 4 sparkles) are starting points (rule of thumb); tune them once on a contact sheet of very different items (dark, bright, thin, wide), then never per item.

## Stage 5: review on a contact sheet

Look at icons the way players do: small, many at once, on the real card background. A contact sheet of every icon at 96 px on the inventory card colour exposes outliers in seconds (one too dark, one too small, one with a stray floating part). The reference project also kept a comparison tool (`compare` and `glow` modes) that flagged icons whose glow differed from the previous render, so a re-render of 140 icons only needed eyes on the handful that changed.

## Stage 6 and 7: upload, then write ids into config

Upload routes for images:

| Route | Notes |
|---|---|
| Studio (Asset Manager, or a plugin / MCP image upload that takes a URL) | needs the PNG reachable; the reference project served its scratch folder on a localhost HTTP server so Studio-side upload could fetch `http://127.0.0.1:<port>/out/<id>/icon.png` |
| Open Cloud Assets API, `assetType` Decal | fully scriptable from CI; images must be smaller than 8000 x 8000 (Roblox docs); see [[Asset Upload Automation with Open Cloud]] |

Gotcha: a freshly uploaded image may fail `ContentProvider:PreloadAsync` for 20 to 60 seconds while it is processed (measured in one production game). Do not mark an install failed on the first preload error; retry after a minute.

Writing the ids back is a config edit, so it follows the config rules in [[Data and Config Pipeline - Spreadsheets to Game]]: re-read the module right before the edit, make **one** insert or one batch of replacements, keep a backup, compile, scan and clone-require. The reference project's install stage took `{ art = "rbxassetid://..." }` and did all of that itself. For batches, it uploaded all icons first, then made **one** config edit for the whole batch.

Store the id map (`id -> image asset id`) as JSON alongside the batch (`up_<batch>.json`). If icons are ever re-rendered, the installer compares and only rewrites changed rows, and the old ids remain on record for rollback.

## Icon sheets: many icons, one image

Small icons (materials, armour pieces, quest kinds) can share one image: a **sprite sheet** with a fixed grid, shown through `ImageRectOffset` and `ImageRectSize`. One upload, one texture in memory, instant display. The reference project used icon sheets for armour sets (an `IconSheets` list plus an `IconOrder` table per batch). Rules:

- fixed cell size (for example 128 px) and padding (2 to 4 px of transparent gutter) so filtering does not bleed neighbours;
- a generated order table, never hand-counted offsets;
- keep each sheet at or under 1024 x 1024 (rule of thumb; Roblox's texture docs mention both 1024 x 1024 texture-map spaces and up to 4096 x 4096 support, so test the target devices).

```lua
-- Show cell `index` (1-based) of a sheet laid out `cols` wide with `cell` px cells.
local function setSheetIcon(img: ImageLabel, sheetId: string, index: number, cols: number, cell: number)
	local i = index - 1
	img.Image = sheetId
	img.ImageRectSize = Vector2.new(cell, cell)
	img.ImageRectOffset = Vector2.new((i % cols) * cell, math.floor(i / cols) * cell)
end
```

## Experience icon and thumbnails

These are marketing images, not inventory icons. Specs (Roblox docs, as of October 2026):

| Image | Spec |
|---|---|
| Experience icon | square, at least 512 x 512 |
| Thumbnails | 1920 x 1080 (16:9), under 3 MB; other ratios are stretched |
| Thumbnail personalization | activates when 2 or more thumbnails are marked active; the setup describes 2 to 5 |

A pipeline for them:

1. **Stage the scene in Studio**: a dedicated thumbnail place or a hidden staging area, with posed characters, hero items and a lighting preset saved as a script (so you can re-stage after updates).
2. **Capture high-resolution frames** (Studio screenshot at a large window size, or render the exported scene in Blender for full control).
3. **Composite** in an image editor: title, readable at phone size, one focal point, high contrast.
4. **Version them** with dates and track which variant was active when ([[Analytics and Funnels]]).

When you use AI tools for thumbnails, follow [[Roblox Policies on AI-Generated Content]] and show what is actually in the game.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Icon colour differs from the game | rendered from the source file only | merge the exported in-game look |
| Glow is a white blob | bloom added in white or clipped | separate emission pass, bloom in hue, soft knee |
| Icons look different sizes | framing by hand | fill computed from bounds, fixed 82% |
| Floating extras in icons | name-based hide rules | rule by rigid group and contact distance |
| A part missing from one icon | hide rule too greedy | regression compare against the previous render |
| Blender script aborts in PowerShell | stderr warnings treated as errors | do not stop on stderr; check outputs |
| "File not found" for deep paths | Windows path length | short (8.3) paths |
| Icon blank right after upload | asset still processing | retry preload after 20-60 s |
| Inventory lags | one ViewportFrame per slot | rendered PNGs, sheets for small icons |

## Checklist

- [ ] Icon rule written (what is in, what is out) and coded
- [ ] In-game look exported and merged before rendering
- [ ] Two passes: beauty and emission; render 2x and downsample
- [ ] Fixed camera, lights and fill for every item
- [ ] Outline, hue-preserving bloom, seeded sparkles
- [ ] Contact sheet review on the real card colour
- [ ] Upload batch first, then one config edit with the full id map
- [ ] Id map JSON kept per batch
- [ ] Store icon and thumbnails staged from a saved scene, dated

## See also

[[Art Pipeline - Concept to In-Game Asset]] · [[UI Asset Pipeline]] · [[Blender Automation with Python]] · [[Asset Upload Automation with Open Cloud]] · [[Textures Decals and Texture Memory]] · [[UI Design Systems]] · [[Thumbnails Icons and Store Page]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Asset Pipelines]] · [[Blender MCP]] · [[Dramatic Showcase Renders in Eevee]] · [[Thumbnail Contrast]] · [[Blender 5 Python Gotchas for Headless Builds]] · [[Dash VFX Presentation on an R15 Rig]]
<!-- auto-links:end -->
