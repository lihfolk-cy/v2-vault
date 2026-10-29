---
tags: [modeling, voxel, blocky, studs, outlines, palette, art-style, blender, luau, type/guide, area/modeling, level/intermediate]
---
# Voxel and Blocky Modeling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Mixed grains -> One grid per model
> - Avoid: Smooth primitives in a voxel model -> Voxelise every curve
> - Avoid: Too much neon -> Respect the glow band for the tier
> - Style chosen (glow-trim showpiece, outlined studded, soft pastel) for what the object means to the player.
> - One grid; cell size set; smallest details 1/40-1/60 of the longest dimension.
> - Three tones per material; one main hue; one glow colour.
>
> Cost: TL;DR ~150 tok · whole note ~5.6k tok. Read more: ## 3. Style B: outlined studded voxels ("toy-box heroes") · ## 5. Building voxels: Parts in Studio or meshes from Blender · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Blocky art is Roblox's native language: the platform grew up on studded bricks, and players read cubes as "made for this world". A modern voxel style is not lazy art, though. The good ones follow strict rules (one grid, three tones per material, one glow colour, studs or outlines applied everywhere) and those rules are what make ten unrelated models look like one game. This note sets out three voxel style archetypes that cover most needs (glow-trim showpieces, outlined studded "toy-box" enemies, and soft pastel companions), the shared grammar behind them, how to build voxels as Parts in Studio or as meshes from Blender, and what they really cost. The reference project rebuilt all 49 of its first-realm enemies in the outlined studded style, so the numbers here are real.

Each archetype is a set of rules you can hand to a builder or a generator script. Treat the numbers as **Rule of thumb** starting points unless they are marked **Measured** (from the reference project's own rebuild), and tune them on your own models under your own lighting.

---

## 1. Voxel grammar: rules shared by every good blocky style

1. **One grid per model.** Every cube is the same cell size, and every edge lands on the grid. Mixing grains (a 0.5-stud body with 0.2-stud details) reads as two art styles glued together.
2. **Visible steps.** Curves are stepped, spheres are voxelised. A single smooth cylinder or sphere in a voxel model breaks the whole read, so it is the first thing to check in review.
3. **One main hue per model, one glow colour**, plus set-wide accents (white, gold, a shared pink). Never two competing glow hues.
4. **Three tones per material**: shadow, body, lit top. More than three steps reads muddy at this resolution.
5. **Eyes or the hero glow are the brightest pixels.**
6. **Silhouette first**: identifiable as a filled black shape at 30-40 px tall.
7. **Merge after building**: runs of same-colour cells become one part or one mesh.

### Choosing the grain

| Model | Cells across the main body | Cell size (studs) | Label |
|---|---|---|---|
| Small companion (3-4 studs) | about 12-16 | 0.25-0.3 | Rule of thumb |
| Showpiece prop (about 20 studs) | about 40-60 | 0.3-0.5 | Rule of thumb |
| Large character (13+ studs) | about 40-60 tall | 0.5 | Measured: the project's boss rebuild used 0.5 studs, 58 cells tall |
| Vehicle | about 50-80 long | 0.3-0.5 | Rule of thumb |

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

## 2. Style A: glow-trim showpieces (dark bodies, light lines)

For premium, themed or tiered objects: rarity pedestals, stations, gates, top-tier showpieces. The idea: a dark, quiet body lets a small amount of Neon do the talking, and rank is shown by adding pieces, not by changing the base.

**Rules (Rule of thumb):**
1. **Keep the base shape fixed across ranks.** Higher ranks add pieces to the same base, so players compare like with like.
2. **Dark body, tinted.** Use a very dark version of the theme hue for the body rather than grey; grey on a coloured theme looks unfinished.
3. **Outline with light, do not fill with it.** Neon runs along edges, panel borders and symbols. Allow one larger glowing focal shape at most.
4. **One symbol per theme**, repeated on the main faces, so a theme can be named from any side.
5. **Give the top a distinct shape per theme**, so themes are told apart by outline before colour is seen.
6. **Add detail outward with rank.** Low ranks stay clean; high ranks gain extra pieces around and above the base. Anything that hovers should move gently, each piece on its own timing.

**Plan in regions first.** Before placing cells, name the regions every variant must fill (edges, main face, corners, symbol panel, supports, top, sides, surroundings). Every theme fills the same regions, so variants stay one family. The habit maps onto weapons too: blade edges are the frame, the flat is the main face, the guard is the symbol panel.

**Glow budget (Rule of thumb).** Keep bright, saturated pixels to a small share of the object: a few percent at the lowest rank, growing to roughly a tenth to a sixth at the top. Past that the shape melts into bloom. Pick Neon colours a little darker and more saturated than the look you want, because bloom lifts them.

**Palette from one hue (Rule of thumb):** a mid-dark sky, a very dark low-saturation body, a bright high-saturation Neon, a second Neon a few degrees of hue away for gradients, a neutral or gold trim, and one small contrasting accent.

**Rank ladder (Rule of thumb):**

| Rank | What it adds | Rough cell count (20-stud object, 0.4-stud grain) |
|---|---|---|
| 1 | Base shape, Neon as thin lines | a few hundred |
| 2 | Theme colour, symbol, corner details | under 1,000 |
| 3 | Larger top shape, side pieces | about 1,000-1,500 |
| 4 | Surrounding detail and hovering pieces | about 1,500-2,500 |
| 5 | The boldest top shape and the most detail | up to about 3,000 |

Neighbouring ranks should differ clearly in hue or value, and each rank should be recognisable from its outline alone.

---

## 3. Style B: outlined studded voxels ("toy-box heroes")

For enemies, armour sets, vehicles and turrets. The reference project's enemy roster used this style.

**Core rules:**
1. Voxel grid; large characters 40-50 cells tall, vehicles 60-80 long.
2. **A raised square stud on every cell face**, top, side and front, so the stud grid is the cell grid (a 2x2-cell brick shows 4 studs). The project's tuned stud values are listed under "Studs: geometry or texture?" below (Measured).
3. **A near-black outline** round every part and the silhouette, tinted very slightly toward the palette rather than pure black (Rule of thumb).
4. Two body colours (main hue and its shadow) plus **gold trim** on edges, rims and rivets.
5. **One neon colour per model** (eyes, lamps, bands, weapon), kept to a small share of the model (Rule of thumb: well under a tenth).
6. Eyes always neon.
7. One exaggerated feature, 1.5-2x realistic size.
8. Neon, glass and special metal stay **smooth** (no studs): the contrast makes them read as special.

**Archetypes (Rule of thumb):**

| Archetype | What sells it |
|---|---|
| Heavy brute | Small head set low between big shoulders, long heavy arms, short legs |
| Armoured knight | Metal plates with a bright trim on the edges, a glowing visor slit, one soft contrasting element such as a cape |
| Creature | One hue in a few values, glowing eyes only, limbs that taper in steps; boxy heads read better than round ones |
| Robot | Boxy limbs, repeated panel patterns, one oversized glowing eye |

**Palette (Rule of thumb):** a saturated mid-value main hue, a darker shadow of it, a gold or metal trim, and one Neon hue well away from the main hue on the colour wheel so it pops.

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

## 4. Style C: soft pastel companions

For pets, mascots and friendly NPCs: things the player owns or likes. The goal is warmth and collectability, so simplicity wins over detail.

1. **Simple body, expressive face.** A rounded or iconic shape (a blob, a fruit, a planet, a cloud) carries a face; limbs are optional and small.
2. **Soft colour.** One light, low-saturation hue per model in two or three values, plus one or two accent colours shared by the whole set. The shared accents are what make different shapes read as one family.
3. **Cute proportions.** A large head area, eyes set low and wide, a small mouth.
4. **Eyes are the brightest pixels.** A white highlight in each eye does more for charm than any other detail.
5. **One accessory that extends the silhouette** (a halo, a leaf, a tail, a small orbiting object) so the pet reads at a distance.
6. **Idle motion instead of a rig.** A gentle bob and slow turn is enough for most companions.

**One face for the whole set (Rule of thumb).** Design a single face layout in cells (eye size, spacing, mouth, blush) and reuse it on every companion. Shapes can vary widely; the shared face is what turns them into a collection. Test it at the smallest size the pet appears on screen and simplify until it still reads.

Budget (Rule of thumb): a few hundred cells, merged to a few hundred Parts at most, or one small mesh per colour.

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

[[MagicaVoxel]] and similar editors are faster than code for hand-designed voxel art. See [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] for its limits and export path into Blender for cleanup.

---

## 6. Lighting, materials and VFX for voxel art

- Bodies in **SmoothPlastic** (or Plastic with the stud texture), CastShadow on. Neon parts CastShadow off.
- **Bloom** does the glow (Rule of thumb: a moderate Intensity and a Threshold a little above 1, so Neon blooms and white trim does not; tune under your own lighting).
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
| Hovering pieces with no motion | Reads as clutter | Bob and spin, each on its own timing |

## Checklist

- [ ] Style chosen (glow-trim showpiece, outlined studded, soft pastel) for what the object means to the player.
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
[[Voxel Art - Studs Outlines and Style Kits]] · Voxel Shading - Baked AO Edges and Lighting · Voxel Modelling Start Here · Voxel Scale Grids and Stud Alignment · Meshing Voxels for Roblox - Greedy Meshing and Export · Voxel Characters - Proportions Joints and Rigging
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Voxel Scale Grids and Stud Alignment]] · [[Hand-Painted and Stylized Texturing]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Organic and Creature Modeling]] · [[Hard-Surface Modeling]] · [[Modular Environment Kits]] · [[Mesh Optimization for Mobile]] · [[UV Unwrapping]] · [[Texturing and PBR Baking]] · [[Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs]]
<!-- related:end -->
