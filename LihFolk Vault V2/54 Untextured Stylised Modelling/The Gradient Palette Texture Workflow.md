---
tags: [modeling, untextured, stylised, gradient-atlas, palette, uv, blender, texture, workflow, type/reference, area/modeling, level/intermediate]
---
# The Gradient Palette Texture Workflow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Faint lines of a neighbour's colour on distant faces: Strips too narrow for the mip in use -> 16 px strips for far assets; order strips so neighbours are similar
> - Hard colour seam on one face: UVs placed on a strip border -> Keep UVs 2 px inside the strip
> - Every mesh broke after a palette update: A strip was moved or resized -> Fixed layout, reserved strips, version the layout
> - One strip direction for the whole image; strips 8 px minimum, 16 px for distant assets.
> - Each strip has contact shadow, body ramp and highlight, with hue shift.
> - Flat accent strips, a grey ramp and reserved empty strips included.
>
> Cost: TL;DR ~200 tok · whole note ~4.6k tok. Read more: ## Designing the layout · ## The UV moves in Blender · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A gradient palette texture is one small image made of colour strips, each strip running from a dark to a light version of one colour (or from one hue into another). Every mesh in a kit maps its faces onto those strips: a tree trunk samples the brown strip from its dark end at the root to its lighter end near the crown, a leaf blob samples the green strip so its underside is darker than its top. The result looks shaded and designed, costs one tiny texture for a whole world, and needs no painting at all. This is the workflow behind a large share of mobile low-poly games, Synty-style asset packs (which share one palette texture across hundreds of meshes) and many popular Blender tutorials.

[[Trim Sheets Atlases and Vertex Colors]] introduces palette and gradient atlases in a few paragraphs. This note is the full workflow: designing the layout, the UV moves that make it fast, the filtering and mip traps that decide how wide your strips must be, swapping palettes per zone in Roblox, and how to keep a layout stable across a team for a year.

## Why a gradient, not a flat swatch

A flat swatch atlas gives one colour per face. Under Roblox lighting that reads like SmoothPlastic: clean, but flat on large forms. A gradient strip lets each face pick a position along a ramp, so the mesh carries its own fake lighting:

- **Top-lit forms.** Darker at the bottom, lighter at the top. Survives any sky, any time of day, and the lowest graphics level ([[Lighting Untextured Art in Roblox]]).
- **Ground contact.** The bottom 10 to 20 percent of a rock or wall darkens toward the ground colour, which seats it in the terrain without ambient occlusion.
- **Hue shift along the ramp.** Shadows shift toward blue or purple, highlights toward yellow. That is the single biggest step from "programmer colours" to "art" (see [[Colour Scripts and Value Structure for Untextured Art]]).
- **Depth on foliage.** Inner leaf blobs map to the darker half, outer blobs to the lighter half.

The cost is UV discipline: faces must be mapped along the gradient deliberately, not unwrapped.

## Designing the layout

### Strip direction and size

Pick one direction for every gradient in the image (vertical strips, dark at the bottom, is the most common; it matches "darker at the bottom of the mesh" so the UV move is a simple vertical squash). Then choose sizes:

| Image | Strips | Strip size | Good for |
|---|---|---|---|
| 64 x 64 | 8 | 8 x 64 px | A single prop family, prototypes |
| 128 x 128 | 16 | 8 x 128 px | A zone kit (forest, desert) |
| 256 x 256 | 16 | 16 x 256 px | A whole game's base palette, distant props safe |
| 256 x 256 | 32 | 8 x 256 px | Large palettes, close-up props only |
| 512 x 256 | 32 | 16 x 256 px | Large palettes that must survive phones |

Rule of thumb: **8 px strips** for props the camera sees within about 40 studs, **16 px strips** for anything seen far away or on low-memory phones. Why is explained in the filtering section below.

### What goes in a strip

Each strip is one "material idea": bark, leaf, stone, moss, roof tile, painted wood, metal trim, skin, cloth. Inside it:

1. **Bottom 15 percent: contact shadow.** Darkest value, shifted toward the zone's shadow hue.
2. **Middle 70 percent: the body ramp.** A smooth ramp across about 3 value steps.
3. **Top 15 percent: highlight.** Lighter, warmer (or cooler in a moonlit zone), slightly less saturated.

Keep the ramp gentle. If the darkest and lightest ends differ by more than about 40 points of HSV value (on 0 to 100), meshes look striped rather than lit (rule of thumb). A second, steeper copy of key strips (a "contrast" variant) is useful for hero props.

### Special strips

- **Flat accents.** A few strips that are one solid colour top to bottom: gold, white, black, a UI-matching brand colour. Faces that must not shade (signs, eyes, gems) go here.
- **Two-hue strips.** Sunset sky fading orange to purple, water deep blue to cyan. Useful on big shapes.
- **A grey ramp.** For neutral stone and for "tint me later" regions under a SurfaceAppearance TintMask.
- **A reserved empty strip.** Leave one or two strips unused so a new material can be added without moving any existing strip. Moving strips breaks every mesh already mapped.

### Padding

Leave at least 1 to 2 px of the same colour bleeding past each strip edge (extend each strip's edge pixels outward), and never place UVs within 2 px of a strip border. Bilinear filtering samples a 2 x 2 texel neighbourhood, so a UV exactly on a border mixes two strips at full resolution.

## Filtering and mips: why strip width matters

This is the nuance most guides skip.

Graphics hardware chooses a mip level from how fast the UVs change across the screen. Three cases:

- **UVs collapsed to a point** (a flat swatch atlas): the UVs do not change across the face, so the derivatives are near zero and the GPU samples the full-resolution mip. Swatches do not bleed with distance from mipping, only from bilinear filtering at the edges (rule of thumb from how GPU mip selection works; Roblox does not document its sampler settings).
- **UVs collapsed to a line along the strip** (the gradient case): UVs change along the strip but not across it. With trilinear filtering, mip selection follows the larger rate, so a long face far away picks a small mip, and at that mip the strip may be one texel wide, mixing its neighbours. Anisotropic filtering helps, but you cannot rely on it on every phone.
- **Faces with real UV area** (stretched across the strip width by mistake): they sample across the strip, mixing colours at every distance.

So the strip must stay at least a couple of texels wide at the mip level a distant face will use. An 8 px strip is 4 px wide at mip 1, 2 px at mip 2 and 1 px at mip 3. A 16 px strip reaches 1 px only at mip 4. For props seen at a few dozen studs this does not matter; for mountains, distant cliffs and skyline buildings it does. Practical rules:

- Distant scenery uses 16 px or wider strips, or flat swatches.
- Keep neighbouring strips **similar in value** where you can (order strips by family: greens next to greens), so a bleed is a slight shift, not a visible seam colour.
- Test by viewing a prop at its furthest realistic distance in Studio and on a phone emulator, not only up close.

**[[ResampleMode]].** Roblox docs (as of October 2026) list a `ResampleMode` property on `SurfaceAppearance` using `Enum.ResamplerMode` with two items, `Default` and `Pixelated`. The reference page does not describe the behaviour. Pixelated presumably means nearest-neighbour magnification, which removes bilinear bleed up close and suits pixel-art palettes. Whether it changes mip selection at distance is unverified; test before relying on it. Plain `MeshPart.TextureID` has no such property.

**Texture quality reduction.** Rule of thumb: low-memory devices may load reduced texture resolutions. If a 128 x 128 atlas is effectively loaded at 64 x 64, every 8 px strip becomes 4 px. Another reason to keep strips at 8 px minimum.

## Colour space and export

- **Paint in sRGB, save as 8-bit PNG.** In Blender, the image texture node for the palette stays on the sRGB colour space (the default for colour images).
- **Avoid compression artefacts.** Upload PNG, not JPG; JPG blocks smear adjacent strips. Roblox recompresses uploads for the GPU (format not documented), so very similar adjacent colours may shift slightly; check after upload.
- **No alpha unless you need it.** If you will use `SurfaceAppearance` with `TintMask`, alpha marks tinted regions; otherwise save RGB only so nothing accidentally becomes transparent under `Overlay` or `Transparency` modes.

## The UV moves in Blender

Blender manual terms. Assumes the palette image is loaded in the UV editor and the mesh has a material using it.

### Method 1: gradient by face selection (manual, fast for props)

1. In Edit Mode, select the faces that should use one strip (for example all bark faces). `L` over linked geometry or Select Similar by material helps.
2. Front view (`Numpad 1`), then **UV > Project from View**. The UVs now mirror the mesh's height.
3. In the UV editor, **scale X to zero** (`S X 0`) so the island becomes a vertical line. Horizontal colour sampling is now fixed.
4. Scale Y to fit the strip's usable height (for example from the 15 percent mark to the 95 percent mark, so the bottom of the mesh hits the contact shadow only if you want it to).
5. Move the line to the strip's centre column (`G X`, snap to pixels with UV snapping set to the pixel grid).
6. Repeat per material group.

The vertical squash means the gradient follows object height: whatever is lower in the mesh is darker. For curved forms like a leaf blob, project from the front and the top-to-bottom ramp follows the blob naturally.

### Method 2: flat swatch faces

For faces that should be one colour (eyes, gold trim, a sign face), select them and **scale UVs to zero** (`S 0`), then move the point to the swatch centre. Use flat accent strips for these.

### Method 3: by script, using world height

For kits with dozens of meshes, script it. This Blender Python maps each face group to a strip by material slot and sets V from each vertex's world height within the object's bounds. It uses bmesh as the Blender API documents (edit mesh access, then `update_edit_mesh`).

```python
# Blender: map faces onto vertical gradient strips by material slot.
# Strip i is a vertical column; V follows world Z inside the object's bounds.
import bpy, bmesh
from mathutils import Vector

STRIPS = 16                 # columns in the palette image
V_MIN, V_MAX = 0.12, 0.95   # usable ramp: skip most of the contact shadow, keep a little highlight
SLOT_TO_STRIP = {0: 3, 1: 5, 2: 9}   # material slot index -> strip index (your layout)

obj = bpy.context.active_object
mw = obj.matrix_world
zs = [(mw @ Vector(c)).z for c in obj.bound_box]
zmin, zmax = min(zs), max(zs)
height = max(zmax - zmin, 1e-6)

bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(obj.data)
uv = bm.loops.layers.uv.verify()
for face in bm.faces:
    strip = SLOT_TO_STRIP.get(face.material_index, 0)
    u = (strip + 0.5) / STRIPS                    # centre of the column
    for loop in face.loops:
        z = (mw @ loop.vert.co).z
        t = (z - zmin) / height                   # 0 at the bottom, 1 at the top
        loop[uv].uv = (u, V_MIN + t * (V_MAX - V_MIN))
bmesh.update_edit_mesh(obj.data)
bpy.ops.object.mode_set(mode='OBJECT')
```

After running it, assign the single palette material to every face and remove the extra material slots before export, so the mesh imports as one MeshPart with one surface.

Variations worth scripting:

- **Per-face jitter.** Add a small random offset (0.02 to 0.05 in V) per face so neighbouring facets differ slightly. Great on faceted rocks ([[Faceted Low-Poly - Flat Normals and Facet Size]]).
- **Normal-based ramp.** Use the face normal's Z instead of height: upward faces light, downward faces dark. This mimics sky light and works well on canopy blobs.
- **Ground fade.** Clamp the bottom 1 stud of every rock into the contact shadow regardless of the object's height.

## Getting it into Roblox

1. Export FBX or GLB with UVs (see [[Exporting FBX vs GLB]]). Vertex colours are not needed; make sure none are left over, or tick Ignore Vertex Colors at import.
2. Upload the palette PNG once. Keep its asset id in one shared config module or on a template object, never typed into dozens of places.
3. Choose how meshes reference it:
   - **`MeshPart.TextureID`**: simplest. No per-instance tint.
   - **`SurfaceAppearance` with ColorMap = the palette**: allows `Color` tinting (TintMask) or base-colour reveal (Overlay with alpha), and exposes `ResampleMode`. One SurfaceAppearance template cloned onto each mesh; see [[SurfaceAppearance PBR Workflow]] for the template pattern.
4. Set the built-in `Material` to SmoothPlastic (or Plastic) so the engine's own material pattern does not show through and compete. With collapsed UVs a patterned material would smear anyway.

### Swapping palettes per zone

Keep the **layout** fixed and paint a new image per zone: autumn forest, snow forest, haunted forest. A script swaps the id. Because SurfaceAppearance map properties cannot be set by game scripts at runtime (they are plugin or edit-time only, per the vault's SurfaceAppearance note), runtime swaps use `TextureID` meshes or pre-built SurfaceAppearance variants cloned in. Edit-time swaps can use either.

```lua
--!strict
-- Edit-time (Command Bar): swap every MeshPart under a zone from one palette to another.
local OLD = "rbxassetid://0000000000"   -- summer palette
local NEW = "rbxassetid://0000000001"   -- autumn palette
local zone = workspace:FindFirstChild("ForestZoneAutumn")
assert(zone, "zone not found")

local swapped = 0
for _, d in zone:GetDescendants() do
	if d:IsA("MeshPart") and d.TextureID == OLD then
		d.TextureID = NEW
		swapped += 1
	end
end
print("swapped", swapped)
```

## Keeping the layout stable

A gradient atlas is a contract between the image and every mesh. Treat it like an API.

- **Version the layout**, not just the image: a small table (strip index, name, purpose, which kits use it) in the style sheet.
- **Never move a strip** once meshes use it. Add new strips in reserved slots; deprecate old ones in place.
- **Name palettes by layout and variant**: `forest_L1_summer.png`, `forest_L1_autumn.png`. Same `L1` means same layout.
- **Keep a test chart mesh**: a row of cubes, one per strip, mapped with the script. Re-import it whenever the image changes and look at it under the game's lighting before touching real assets.

## When not to use a gradient atlas

- **Huge flat surfaces** (floors, walls longer than about 50 studs): a single `Color` is cheaper and has no mip worries.
- **Hero assets with painted detail**: this is a non-painted method; if a boss needs painted scars, it needs its own texture.
- **Meshes that will be decimated or remeshed later**: UVs drift; map after the final topology.
- **Assets that must tile a built-in material** (Wood, Slate): collapsed UVs cannot tile.
- **Team members who only work in Studio** and need to recolour freely: flat colour parts may serve them better.

## Worked example: a 16-strip forest palette

1. Create a 128 x 128 image. Divide into 16 columns of 8 px.
2. Columns 0 to 3: bark (dark brown to warm tan), bark variant, leaf dark green, leaf light green. Columns 4 to 7: moss, grass tuft, stone grey-blue, stone warm. Columns 8 to 11: mushroom red, mushroom cap white, painted wood, rope. Columns 12 and 13: flat gold, flat black. Columns 14 and 15: reserved.
3. In each ramp column, paint the bottom 20 px about 25 percent darker and shifted 10 to 15 degrees toward blue; the top 20 px about 10 percent lighter and shifted toward yellow.
4. Extend each column's edge pixels outward by 1 px on each side (the column stays 8 px, its colour is uniform across the width, so this mostly protects the image borders).
5. Build the test chart: 16 cubes, scripted UVs. Import into Studio under the zone's lighting. Check every column reads as intended and neighbouring columns do not bleed at 100 studs.
6. Map the tree trunks with Method 1, the leaf blobs with the normal-based script variant, the rocks with height plus jitter.
7. Paint `forest_L1_autumn.png`: only the leaf, grass and moss columns change. Swap on a duplicate zone and compare.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Faint lines of a neighbour's colour on distant faces | Strips too narrow for the mip in use | 16 px strips for far assets; order strips so neighbours are similar |
| Hard colour seam on one face | UVs placed on a strip border | Keep UVs 2 px inside the strip |
| Every mesh broke after a palette update | A strip was moved or resized | Fixed layout, reserved strips, version the layout |
| Gradient runs sideways on some props | Projected from the wrong view, or rotated in the UV editor | Project from front; check the test chart |
| Meshes look striped, not lit | Ramp too steep | Under about 40 points of value from dark to light |
| JPG blocks bleeding colours | Uploaded as JPG | Upload PNG |
| Built-in material pattern smeared over the palette | Patterned Material on collapsed UVs | SmoothPlastic or Plastic |
| Unexpected darkening on some meshes | Leftover vertex colours multiplying | Ignore Vertex Colors on import |

## Checklist

- [ ] One strip direction for the whole image; strips 8 px minimum, 16 px for distant assets.
- [ ] Each strip has contact shadow, body ramp and highlight, with hue shift.
- [ ] Flat accent strips, a grey ramp and reserved empty strips included.
- [ ] Layout table written and versioned; palettes named by layout and variant.
- [ ] UVs 2 px inside strips; script or manual method applied consistently.
- [ ] Uploaded as PNG; id stored in one place.
- [ ] Test chart checked under the game's lighting, up close and at maximum distance, on a phone emulator.

## Related

- [[Trim Sheets Atlases and Vertex Colors]]
- [[Flat Colour vs Gradient Atlas vs Vertex Colour]]
- [[Faceted Low-Poly - Flat Normals and Facet Size]]
- [[Colour Scripts and Value Structure for Untextured Art]]
- [[Lighting Untextured Art in Roblox]]
- [[UV Unwrapping]]
- [[SurfaceAppearance PBR Workflow]]
- [[Low-Poly Tree Set Worked Example]]
- [[Blender Automation with Python]]
- [[Textures Decals and Texture Memory]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Bevels Chamfers and Edge Highlights Without Textures]] · Voxel Palettes - Ramps Hue Shifting and Limits · MagicaVoxel Goxel and Blockbench Workflows Compared · Low-Poly and Stylized Modeling · Voxel Shading - Baked AO Edges and Lighting · Hand-Painted and Stylized Texturing
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Low-Poly and Stylized Modeling]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Keeping a Mixed Asset Library Consistent]] · [[Texturing and PBR Baking]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]]
<!-- related:end -->
