---
tags: [modeling, voxel, blocky, studs, outlines, palette, art-style, blender, luau]
---
# Voxel and Blocky Modeling

Blocky art is Roblox's native language: the platform grew up on studded bricks, and players read cubes as "made for this world". A modern voxel style is not lazy art, though. The good ones follow strict rules (one grid, three tones per material, one glow colour, studs or outlines applied everywhere) and those rules are what make ten unrelated models look like one game. This note teaches three production voxel styles studied for the reference project (dark-and-neon tiered showpieces, outlined studded "toy-box" enemies, and cute pastel companions), the shared grammar behind them, how to build voxels as Parts in Studio or as meshes from Blender, and what they really cost. The reference project rebuilt all 49 of its first-realm enemies in the outlined studded style, so the numbers here are real.

The three styles were studied frame by frame from short public showcase videos of other Roblox developers' work, with colours sampled from the video pixels; they are presented here as style systems, not as anyone's assets.

---

## 1. Voxel grammar: rules shared by every good blocky style

1. **One grid per model.** Every cube is the same cell size, and every edge lands on the grid. Mixing grains (a 0.5-stud body with 0.2-stud details) reads as two art styles glued together.
2. **Visible steps.** Curves are stepped, spheres are voxelised. One smooth cylinder in a voxel model breaks the whole read ("a smooth sphere or cylinder slipped in" is listed as a top mistake in all three style guides).
3. **One main hue per model, one glow colour**, plus set-wide accents (white, gold, a shared pink). Never two competing glow hues.
4. **Three tones per material**: shadow, body, lit top. More than three steps reads muddy at this resolution.
5. **Eyes or the hero glow are the brightest pixels.**
6. **Silhouette first**: identifiable as a filled black shape at 30-40 px tall.
7. **Merge after building**: runs of same-colour cells become one part or one mesh.

### Choosing the grain

| Model | Cells across the main body | Cell size (studs) | Source |
|---|---|---|---|
| Small companion (3-4 studs) | 10-18 | 0.25-0.3 | Pastel style, estimated from the video |
| Showpiece prop (about 20 studs) | 40-60 | 0.3-0.5 | Neon style |
| Large character (13+ studs) | 40-50 tall | 0.5 | Outlined style; the project's boss rebuild used 0.5 studs, 58 cells tall |
| Vehicle | 60-80 long | 0.3-0.5 | Outlined style |

Rule from the project: keep cells at or above about **0.3 studs** if you build with Parts, or part counts explode. Smallest details (glyph pixels, specks) are about 1/40 to 1/60 of the object's longest dimension.

### The three-tone ramp

For each material colour C, build:

- **Shadow** = a dark colour mixed 45 percent toward C (under faces, crevices).
- **Body** = C.
- **Lit top** = C mixed 40 percent toward a light colour (top faces, upper edges).

The project's boss rebuild found that the original 5-step ramps "made yellow read olive and muddy"; three tones with no random jitter read cleanly.

```lua
--!strict
-- Three-tone ramp for a voxel material (the reference project's mix factors).
local DARK = Color3.fromRGB(12, 10, 24)
local LIGHT = Color3.fromRGB(255, 250, 235)

local function ramp(body: Color3): (Color3, Color3, Color3)
	local shadow = DARK:Lerp(body, 0.45)     -- dark mixed 45% toward the body colour
	local lit = body:Lerp(LIGHT, 0.40)       -- body mixed 40% toward light
	return shadow, body, lit
end
```

---

## 2. Style A: tiered voxel neon (dark bodies, light lines)

For premium, themed or tiered objects: rarity pedestals, stations, gates, top-tier showpieces.

**Core rules (condensed from the study):**
1. One fixed base silhouette per object; tiers bolt onto the same slots, never change the base.
2. Dark body (near-black, tinted to the theme hue, brightness 10-20 percent), theme colour in **Neon**.
3. **Neon is drawn, not filled**: it traces edges, frames panels, draws glyphs. One big neon area allowed: the hero shape (moon disc, orb).
4. One hero **crown** on top, 0.5-1x the body height, so each theme reads from its silhouette alone.
5. Corners are framed light boxes (dark cube with an inset neon square on its outward faces).
6. One glyph per theme repeated on the main faces (chevrons, star, spiral, bolt, X, runes).
7. Higher tiers sink into a **rubble skirt** of small dark cubes with single neon "specks" (5-10 percent density), spreading 15-30 percent of the footprint width.
8. 3-10 small **floaters** break the outline (crystals, rings, rocks), each bobbing on its own phase.

**Slots.** Split any object into slots before building: frame edges, main face, corners, emblem panel, supports, crown, flanks, skirt, air. Every theme fills the same slots, so all variants share one silhouette. A sword maps blade edges to frame edges, the blade flat to the main face, the guard centre to the emblem.

**Glow budget** (share of the object's pixels that are bright and saturated, measured per theme): from 0.6 percent (clean tech look) to 16.1 percent (fire theme fully outlined in neon). Rule: tier 1 at 1-5 percent, mid tiers 5-10, top tiers 10-16. **Above about 16 percent the shape is lost in bloom.** Set Neon part colours slightly darker and more saturated than they should look, because bloom lifts them.

**Palette derivation** from one hue H: sky at saturation about 60 percent, brightness 40; body at saturation 30-50, brightness 10-20; neon main at saturation 80-90, brightness 85-95; a second neon ±10-20 degrees of hue for gradients; neutral or gold trim; one small off-hue accent.

**Tier ladder:**

| Rank | Adds | Approx. cells (20-stud object, 0.4-stud grain) |
|---|---|---|
| 1 | Base only, neon as lines | 300-500 |
| 2 | Theme colour, main-face glyph, corner caps, small crown | 600-900 |
| 3 | Big crown, flank pieces, skirt, floaters | 1,000-1,500 |
| 4 | Dense speck skirt, chains, floating rocks or crystals | 1,500-2,500 |
| 5 | Biggest crown silhouette, props, most specks and floaters | 2,000-3,000 |

Each tier must be identifiable from its crown silhouette alone; neighbouring tiers differ by at least 40 degrees of hue or by value.

---

## 3. Style B: outlined studded voxels ("toy-box heroes")

For enemies, armour sets, vehicles and turrets. The reference project's enemy roster used this style.

**Core rules:**
1. Voxel grid; large characters 40-50 cells tall, vehicles 60-80 long.
2. **A raised square stud on every cell face**, top, side and front: about 40-50 percent of the cell width, 10-15 percent of the cell high, a lit edge 10-20 percent lighter, a shadow side 15-25 percent darker. A 2x2-cell brick shows 4 studs: the stud grid is the cell grid.
3. **A near-black outline** (about one cell, colours like `#060808` to `#0a0b17`) round every part and the silhouette.
4. Two body colours (main hue and its shadow) plus **gold trim** on edges, rims and rivets.
5. **One neon colour per model** (eyes, lamps, bands, weapon), 3-8 percent of the model's pixels.
6. Eyes always neon.
7. One exaggerated feature, 1.5-2x realistic size.
8. Neon, glass and special metal stay **smooth** (no studs): the contrast makes them read as special.

**Archetypes** (proportions that worked):

| Archetype | Proportions |
|---|---|
| Heavy brute | Head below the shoulder line, head about 1/6 of height, shoulders 2.2-2.5x head width, arms to the knees, forearms thicker than upper arms, legs about 30 percent of height |
| Armoured knight | Gunmetal plates, gold on every edge, 3-5-cell gold horns, neon visor slit and bands (5-8 percent), a contrasting cloth cape or plume |
| Creature | One hue in 4-5 values, neon eyes only, tapered tentacles that hook 3-4 cells at the tip, cube heads read better than spheres |
| Robot | Boxy limbs, repeated 2x2 window panels, one oversized neon eye |

**Palette system:** main hue at saturation 60-80 percent and value 35-55, a shadow at value 15-25, gold trim, one neon hue far from the main (cyan on navy, green on gunmetal, red on teal, lime on purple).

### Studs: geometry or texture?

Do **not** model studs as geometry for game meshes: one stud per cell face adds about 20 triangles per face. Options, cheapest first:

| Option | How | Trade-off |
|---|---|---|
| Shared overlay texture | One stud image on every mesh, UVs scaled so one tile = one cell, part `Color` tints it | Cheapest; lighting on the studs is painted, not real. The project's stations used one stud overlay texture via SurfaceAppearance with "UV 8 studs/tile" on per-colour meshes |
| Tiling stud normal map | SurfaceAppearance normal map, colour map white so `Color` tints | Real light response, small memory |
| Atlas with studs painted per tone | A square-stud atlas whose swatches already include the stud highlight and shadow | What the project's enemy pipeline used ("3-tone ramps, square-stud atlas") |
| Real geometry | Inset + extrude each face | Only for renders, or bake to a normal map |

The project's tuned stud for its boss rebuild: one per cell, 44 percent of the cell, lit top/left rim x1.32, shaded bottom/right rim x0.62, a soft drop shadow, cap brightness x1.07; neon cells smooth.

### Outlines: three ways

| Method | Cost | Use |
|---|---|---|
| **Inverted hull** baked into the mesh: Solidify (the project used 0.16 studs), Flip Normals, near-black back-face-culled material | **Doubles the triangle count** | Bosses, showcase renders |
| **Roblox `Highlight`** with `FillTransparency = 1`, near-black `OutlineColor` | No triangles; limited number of simultaneously active Highlights (255 as of October 2026, 31 in older docs; see [[Highlights and Selection Effects]]) | The local player's gear, one boss |
| **Part-seam lines in the texture** | Free | Crowds. The project dropped the outline from in-game enemy meshes ("it would double the triangles") and let "part-seam lines and studs carry the look" |

Lines only where parts or materials meet: the project found that lines on every block step made curved parts "go dark and noisy".

---

## 4. Style C: cute pastel voxel companions

For pets, mascots and friendly NPCs: things the player owns or likes.

1. One cosmic or themed object plus **one shared face**; no limbs, no neck.
2. One hue per model in 2-3 values (light at brightness 95-100, saturation 15-30), plus set-wide white and a shared pink for cheeks and accents. The pink is what ties a blue planet and a yellow sun into one family.
3. **Big forehead, low face**: eyes below the middle of the head.
4. Eyes are the brightest pixels (white-hot catchlights); the white-hot share of the model is 15-25 percent, much more glow than style A, acceptable because the shapes are simple.
5. One **orbit element** (ring, disc, sparkles, rays) roughly doubling the silhouette width, tilted 20-30 degrees.
6. Float and spin; no rig needed.

**The face recipe** (cells): eyes 2 wide x 3 tall (top 2x2 white neon catchlight, bottom row tinted), eye centres about 4 cells apart, eye tops at about 45 percent of head height from the top; mouth a 2-3 x 1 "u" with a pink tongue cell, one cell below the eyes; cheeks 2x1 pink under the outer half of each eye. Face height (eye top to mouth) 35-40 percent of the head; width 55-65 percent. The face is identical on every model in the set: a shared face makes a collection.

**Body archetypes:** a 5-point star extruded about a third of its width with tips stepping down to one cell; a terraced sphere of 6-8 slabs each one cell narrower; a rounded cube with 1-2-step chamfers; a cloud of 3-4 overlapping voxel balls; rays as 1-2-cell pillars with a different-colour tip; a ring at about 2x body width.

Budget: about 300-900 cells, merged to 80-250 parts.

---

## 5. Building voxels: Parts in Studio or meshes from Blender

### Route 1: Parts built by code in Studio

Fast iteration, no import step, colours and materials editable live. Cost: one Part per merged run. The project's VoxKit (Luau) stores cells in a table keyed by `x,y,z`, offers `box`, `sphere`, `ring`, `curve` (stepped tapering tubes) and `skirt` (seeded rubble) helpers, and on `build()` merges runs of same-colour, same-material cells along X into single Parts. A test pedestal of **1,216 cells built as 459 Parts** (Measured); a top-tier showpiece of 1-3k cells lands at 400-1,000 Parts.

The core of such a builder:

```lua
--!strict
-- Minimal voxel builder: set cells, then merge X-runs of equal colour/material into Parts.
type Cell = { x: number, y: number, z: number, color: Color3, neon: boolean }

local Vox = {}
Vox.__index = Vox

export type Vox = typeof(setmetatable({} :: { origin: CFrame, size: number, cells: { [string]: Cell } }, Vox))

local function key(x: number, y: number, z: number): string
	return `{x},{y},{z}`
end

function Vox.new(origin: CFrame, size: number): Vox
	return setmetatable({ origin = origin, size = size, cells = {} }, Vox)
end

function Vox.set(self: Vox, x: number, y: number, z: number, color: Color3, neon: boolean?)
	self.cells[key(x, y, z)] = { x = x, y = y, z = z, color = color, neon = neon == true }
end

function Vox.box(self: Vox, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, neon: boolean?)
	for x = math.min(x0, x1), math.max(x0, x1) do
		for y = math.min(y0, y1), math.max(y0, y1) do
			for z = math.min(z0, z1), math.max(z0, z1) do
				self:set(x, y, z, color, neon)
			end
		end
	end
end

function Vox.build(self: Vox, parent: Instance): (Model, number)
	local model = Instance.new("Model")
	local done: { [string]: boolean } = {}
	local count = 0
	for k, c in self.cells do
		if done[k] then continue end
		-- walk back to the start of this run so each run is emitted once, from its left end
		local sx = c.x
		while true do
			local prev = self.cells[key(sx - 1, c.y, c.z)]
			if prev and prev.color == c.color and prev.neon == c.neon and not done[key(sx - 1, c.y, c.z)] then
				sx -= 1
			else
				break
			end
		end
		local len = 0
		while true do
			local nk = key(sx + len, c.y, c.z)
			local o = self.cells[nk]
			if o and not done[nk] and o.color == c.color and o.neon == c.neon then
				done[nk] = true
				len += 1
			else
				break
			end
		end
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = Vector3.new(self.size * len, self.size, self.size)
		p.CFrame = self.origin * CFrame.new((sx + (len - 1) / 2) * self.size, (c.y + 0.5) * self.size, c.z * self.size)
		p.Color = c.color
		p.Material = if c.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.CastShadow = not c.neon                       -- neon never casts shadows
		p.Parent = model
		count += 1
	end
	model.Parent = parent
	return model, count
end

return Vox
```

Notes: merging is along X only; a second pass merging equal X-runs along Z roughly halves part counts on slabs. Build big models in chunks across several calls (Studio freezes on huge loops), off-world, then `PivotTo` into place. Collision is off: give voxel art separate simple colliders (see [[Collision and Physics Geometry]]).

### Route 2: meshes from Blender

For anything repeated (enemies, armour, kit pieces), meshes win: hidden faces between cells are removed, so a solid 10x10x10 block is 600 faces, not 6,000; and the whole model is a handful of MeshParts instead of hundreds of Parts. The reference project's approach: **one mesh per colour group**, `Color` set per MeshPart, a shared stud overlay texture. Its enemies (outlined studded style) shipped at 10,268 to 42,240 triangles each over many parts; its first-realm armour as 889 voxel MeshParts across 39 sets; its lobby stations as studded voxel meshes "one mesh per colour" (Measured).

```python
# Blender: build voxel cells into one mesh per colour, emitting only exposed faces.
import bpy, bmesh
from collections import defaultdict

CELL = 0.5                                     # studs per cell (1 Blender unit = 1 stud)

def build_voxels(cells, name="Vox"):
    """cells: dict {(x, y, z): colour_name}. Returns the created objects."""
    groups = defaultdict(list)
    for pos, col in cells.items():
        groups[col].append(pos)
    objs = []
    for col, positions in groups.items():
        bm = bmesh.new()
        vcache = {}
        def vert(p):
            if p not in vcache:
                vcache[p] = bm.verts.new((p[0] * CELL, p[1] * CELL, p[2] * CELL))
            return vcache[p]
        for (x, y, z) in positions:
            for axis in range(3):
                u, v = (axis + 1) % 3, (axis + 2) % 3        # e_u x e_v = +axis (cyclic order)
                for sign in (1, -1):
                    n = [x, y, z]; n[axis] += sign
                    if tuple(n) in cells:                       # neighbour exists (any colour): face hidden
                        continue
                    base = [x, y, z]
                    if sign > 0: base[axis] += 1
                    quad = []
                    for du, dv in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        p = list(base); p[u] += du; p[v] += dv
                        quad.append(vert(tuple(p)))
                    if sign < 0:
                        quad.reverse()                          # keep normals pointing outward
                    bm.faces.new(quad)
        mesh = bpy.data.meshes.new(f"{name}_{col}")
        bm.to_mesh(mesh); bm.free()
        obj = bpy.data.objects.new(f"{name}_{col}", mesh)
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
    return objs

# Example: a 6x4x3 body with a gold rim and neon eyes.
cells = {}
for x in range(6):
    for y in range(4):
        for z in range(3):
            cells[(x, y, z)] = "Body"
for x in range(6):
    cells[(x, -1, 2)] = "Gold"                 # a rim along the front top edge
cells[(1, -1, 1)] = cells[(4, -1, 1)] = "Neon"  # eyes on the front (front = -Y)
build_voxels(cells, "Crate")
```

Faces between two different colours are culled too (any neighbour hides the face), which is right for solid models. Each colour group becomes its own object, ready to export as separate MeshParts; set `Color` and material per MeshPart in Studio (Neon for the glow group, `CastShadow` off). Further reduce triangles by merging coplanar same-colour faces (*Limited Dissolve* on each object, then triangulate), but only if you are **not** using a per-cell stud texture: the stud UVs need one quad per cell. For the per-cell UV layout, map each face's corners to (0,0)-(1,1) of the stud tile.

### Route 3: a voxel editor

MagicaVoxel and similar editors are faster than code for hand-designed voxel art. See [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] for its limits and export path into Blender for cleanup.

---

## 6. Lighting, materials and VFX for voxel art

- Bodies in **SmoothPlastic** (or Plastic with the stud texture), CastShadow on. Neon parts CastShadow off.
- **Bloom** does the glow: the neon style used Intensity about 0.8-1, Size about 24, Threshold 1.2-1.5 so Neon blooms and white trim does not.
- **One PointLight** in the crown or core (Range 10-16, Brightness 1-2), not dozens.
- **Particles are voxels too**: tiny real cubes (0.05-0.3 studs) that tumble, shrink and fade, about 20-40 alive per object, capped and paused beyond about 150 studs. A pooled-Part emitter held about 35 cubes alive in a Studio test (Measured). For whole zones, swap to a ParticleEmitter with a square texture. See [[VFX Design Playbook]].

---

## 7. Production lessons from the enemy rebuild

- **Keep bones and pivots identical** between the old and new model, and every existing clip still fits. The rebuild of 49 enemies kept "id, skeleton (bones, pivots), clips, AI role" and installed with fit error 0.000 on every rig (Measured).
- **Exaggerate around pivots** (fists 1.4x, forearms 1.25x, weapon heads 1.3x).
- **Flat colour fields read better than tiny patterns** at a 0.5-stud grain: plaid and tiny rivets were dropped.
- **The outline is a preview luxury**: renders used an inverted hull; game meshes did not.
- **Budget honestly**: 15k-40k triangles per enemy is the real cost of studded geometry and seams. If you need 30 enemies on screen on low-end phones, use a coarser grain or texture-only studs on simpler meshes.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Mixed grains | Looks kitbashed | One grid per model |
| Smooth primitives in a voxel model | Breaks the style | Voxelise every curve |
| Too much neon | Shape dissolves in bloom | Respect the glow band for the tier |
| Grey body on a dark theme | Unfinished look | Tint the body toward the theme hue |
| Studs as real geometry in game | Triangle count explodes | Texture or normal map |
| Outline hull on crowds | Double triangles everywhere | Seam lines in texture; hull or Highlight only on heroes |
| Cells under 0.3 studs with Parts | Thousands of parts | Larger grain or meshes |
| Floaters with no motion | Reads as clutter | Bob and spin, each on its own phase |

## Checklist

- [ ] Style chosen (neon tiered, outlined studded, pastel companion) for what the object means to the player.
- [ ] One grid; cell size set; smallest details 1/40-1/60 of the longest dimension.
- [ ] Three tones per material; one main hue; one glow colour.
- [ ] Glow share within the style's band.
- [ ] Studs and outlines done the cheap way for anything repeated.
- [ ] Merged: Parts per run (Studio) or one mesh per colour (Blender).
- [ ] Pivots and bones unchanged when restyling an existing rig.
- [ ] Reads at 30-40 px as a filled silhouette.

## See also

[[Low-Poly and Stylized Modeling]] · [[Modeling Fundamentals for Games]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Environment Art Styles]] · [[Highlights and Selection Effects]] · [[VFX Design Playbook]] · [[Creature Rig Conventions]] · [[Case Study - Enemy Roster Rebuild]] · [[Parts Unions and MeshParts]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Art - Studs Outlines and Style Kits]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Voxel Modelling Start Here]] · [[Voxel Scale Grids and Stud Alignment]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Voxel Characters - Proportions Joints and Rigging]]
<!-- auto-links:end -->
