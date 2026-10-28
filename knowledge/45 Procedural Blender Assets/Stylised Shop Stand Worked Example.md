---
tags: [blender, python, props, stylised, low-poly, environment, awning, export]
---
# Stylised Shop Stand Worked Example

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hand-typed awning angle. Symptom: the awning floats or cuts through posts when a post height changes.
> - Avoid: Diagonal braces sized by eye. Symptom: ends poke through the side panels.
> - Avoid: Hex colours used as linear values. Symptom: washed-out wood and fabric.
> - Seed set; all sizes in studs; faces -Y
> - Every hard part bevelled with an angle limit
> - Repeats varied in width and tone; small tilts everywhere
>
> Read more (13 KB note): ## The awning: the focal feature · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

![[p45_shop_stand.png]]

A cartoon market stand built from one Python script: a wooden counter with varied planks and crossed braces, four posts, a red and cream striped awning with a scalloped edge, a hanging sign with extruded text, and goods on the counter (an apple crate, potions, coin stacks, a price tag), plus a lantern and a barrel. It comes out at about 10k triangles in 110 parts, faces -Y, and is built in studs. The script is `scripts/build_shop_stand.py`.

Numbers are measured in this build (Blender 5.2, October 2026) unless marked rule of thumb.

## The style rules it follows

These come from [[Low-Poly and Stylized Modeling]] and [[Modeling Weapons and Props]]:

- **Thick parts.** Nothing thinner than about 0.2 studs. A 0.3 stud plank reads as wood; a 0.05 stud plank reads as paper.
- **Bevel everything,** with widths from 0.03 to 0.12 studs depending on part size. Bevels catch a highlight and make boxes look carved instead of default ([[Bevels Chamfers and Edge Highlights Without Textures]]).
- **Vary the repeats.** Plank widths random between 0.7 and 1.0 studs, two alternating wood tones.
- **Tilt everything a little,** mostly 1 to 3 degrees, never 0. Perfectly straight parts read as a computer model; slightly crooked ones read as built by hand.
- **One focal feature.** The striped awning and sign carry the silhouette; everything else is quieter.
- **Seed the randomness** (`random.seed(7)`) so the stand is identical every rebuild.

## Helpers: three shapes and one wrapper

Almost every part is a box, a cylinder or a squashed icosphere, passed through one wrapper that names it, places it, assigns a material and adds a bevel modifier:

```python
def obj(name, bm, m, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, seg=2, smooth=False):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o)
    o.location = loc; o.rotation_euler = Euler([math.radians(a) for a in rot]); me.materials.append(m)
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL"); b.width = bevel; b.segments = seg; b.limit_method = "ANGLE"
    parts.append(o); return o
```

`limit_method = "ANGLE"` bevels only the sharp edges, so a cylinder's side seams stay untouched and only its rims round off. Two segments give a soft rounded edge that still looks low-poly.

Colours are written as hex and converted to linear before going into the shader:

```python
def lin(h): return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1,)
```

Without this the warm woods and the awning red come out pale (the same washed-out failure noted in [[Low-Poly Creature From a Flat Reference Sheet]]). The power of 2.2 is an approximation of the sRGB curve; it is close enough for flat art.

## The counter

- **Skirt** (8.2 by 3.2 by 0.45, dark wood) at the bottom.
- **Counter top** 8.8 by 3.6, 0.5 thick, top at about 3.9 studs, tilted up to 1 degree. Counter height near 4 studs puts goods at a standard character's chest height, so they read from a normal camera.
- **Front planks** generated left to right, each a random width, alternating tones, and tilted on two axes:

```python
x, i = -3.9, 0
while x < 3.9:
    w = min(random.uniform(0.7, 1.0), 3.9 - x)
    box(f"Plank{i}", (w - 0.06, 0.3, 3.0), WOOD2 if i % 2 else WOOD,
        (x + w / 2, -1.55, 1.9), (jit(1.5), jit(2.5), 0), 0.07)
    x += w; i += 1
```

The `w - 0.06` leaves a small gap between planks so each one gets its own bevel and shadow line. The last plank is clamped so the row ends exactly at the side panel.

- **Crossed braces** across the plank face, 16 degrees each way.
- **Side panels** with a yaw wobble of up to 1 degree.

### The brace length fix

The first braces were sized by eye and poked out through the side panels. A rotated bar's horizontal footprint is its length times the cosine of the angle plus its height times the sine, so size it from the opening instead:

```
footprint = L * cos(a) + h * sin(a)
L = (opening - margin - h * sin(a)) / cos(a)
```

The opening between the side panels is about 7.8 studs. At 16 degrees with a 0.32 stud bar height, a length of 7.4 gives a footprint of about 7.2 studs, leaving roughly 0.3 studs clear at each end. Any diagonal part (braces, ladders, roof rafters) needs the same calculation, and it is worth doing in the script rather than by trial renders.

## The awning: the focal feature

Posts at the front are 7.6 studs tall and at the back 9.0, so the awning slopes down toward the customer, which is how real stalls shed rain and how the eye is led to the counter. The awning is built from two anchor points rather than an angle typed by hand:

```python
back, front = Vector((0, 1.9, 9.35)), Vector((0, -2.8, 7.55))
slope = math.degrees(math.atan2(back.z - front.z, back.y - front.y))
depth = (back - front).length
```

### The slope sign bug

A rotation about X by a positive angle lifts the +Y end of a box. The back of the stand is +Y, so the slope must be positive when the back is higher. The first version had the sign flipped: the awning tilted the wrong way, rising toward the front, floating off the front posts and cutting into the back posts. Deriving the angle with `atan2` from the two anchors, in the same order as the axis it rotates, makes the sign fall out correctly and keeps the awning glued to the post tops when either height changes.

### Stripes, sag and scallops

The awning is eight stripes across 9.6 studs, alternating red and cream, each a thin bevelled box rotated by the slope. A sine sag (0.12 studs at the middle) drops the centre stripes so the canvas looks heavy:

```python
for k in range(N):
    cx = -Wd / 2 + Wd / N * (k + 0.5); sag = -0.12 * math.sin(math.pi * (k + 0.5) / N)
```

Each stripe ends in a half-disc scallop of the same colour at the front edge. The scallop is a 16-segment circle with the upper half deleted, refilled, stood upright and given thickness:

```python
bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, segments=16, radius=Wd / N / 2 - 0.02)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.001], context="VERTS")
bmesh.ops.contextual_create(bm, geom=bm.edges[:])
for v in bm.verts: v.co = Vector((v.co.x, 0, v.co.y))     # stand it up, hanging down
bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.14)
```

The scallops are the single cheapest detail with the biggest effect on the silhouette: a straight awning edge reads as a box, a scalloped one reads as a market stall from across a map. Dark wooden bars run along the front and back edges to hide where stripes meet the posts.

## The sign and its text

A board (4.4 by 1.45) in a darker frame sits on two short poles above the awning, tilted forward 6 degrees so it faces a camera that is usually above head height. The text is a font curve converted to a mesh:

```python
cu = bpy.data.curves.new("SignText", "FONT"); cu.body = "SHOP"
cu.align_x = "CENTER"; cu.align_y = "CENTER"; cu.size = 1.05; cu.extrude = 0.06; cu.bevel_depth = 0.015
to = bpy.data.objects.new("SignText", cu); scene.collection.objects.link(to)
to.rotation_euler = (math.radians(96), 0, 0)              # stand up (90) plus the board tilt (6)
bpy.context.view_layer.objects.active = to; to.select_set(True)
bpy.ops.object.convert(target="MESH")
```

- **Extrude plus a small bevel** gives the letters an edge highlight and makes them read as carved or painted relief.
- **Convert to mesh before export.** Exporters skip or mis-handle curve objects; a conversion makes the text an ordinary mesh part.
- **The default font is used,** so there is no font licence question. If you swap in another font, check its licence covers embedding the outlines in a game asset.
- Two gold coin discs flank the word as an icon of "shop" for players who do not read the language.

## Goods, lantern and barrel

- **Apples:** nine squashed icospheres (subdivision 2) in a spiral in a crate, each with a five-sided stem and a flattened leaf. The spiral pattern (`a = k * 2.4` radians, radius stepping in three rings) avoids the grid look of nested loops.
- **Potions:** three round bottles with emission 0.6 so they glow faintly, varied heights and a staggered depth so they do not line up.
- **Coins:** a stack of six with a little jitter per coin, plus three loose coins tilted up to 8 degrees.
- **Lantern:** iron frame of thin bars around an emissive glass box (emission 6) with a 60 W warm point light just in front. The emission makes it read in any lighting; the point light only matters for the render.
- **Barrel:** a 12-sided cylinder whose radius is bulged with a sine along its height, with two iron hoops and a lid.

Props use smaller bevels and more tilt than the structure, because small objects look most "placed by a person" when they are visibly uneven.

## Render and export

A soft sun at 50 degrees elevation, a pale blue sky, a grass disc and the Standard view transform (so the flat colours match what Roblox shows; see [[Dramatic Showcase Renders in Eevee]]). The hero shot is a 45 mm lens from front-left at about 25 studs, looking at the middle of the stand.

Export is GLB with `export_apply=True`, so the bevel modifiers are baked into the exported meshes.

## Nuances and edge cases

1. **The triangle count depends on where you count.** The script prints a count from each object's base mesh, which is before the bevel modifier. With `export_apply=True` the exported file carries the bevelled geometry, which is noticeably larger: a two-segment bevel turns a 12-triangle box into well over 100 triangles. Count triangles on the exported file, or on the evaluated mesh, before quoting a budget ([[Triangle Budget]]).
2. **110 parts is 110 MeshParts if imported as is.** That is fine for a hero prop near spawn and wasteful for a market of twenty stalls. For repeated use, join parts by material into a handful of meshes (structure, awning, goods, glowing bits) before export, and keep separate only what must move or collide differently ([[Art Budgets - Triangles Draw Calls Memory]]).
3. **One material per colour becomes one surface per colour.** Fourteen materials here. For a kit of many stalls, a palette texture as in [[The Gradient Palette Texture Workflow]] collapses them into one.
4. **Collision:** the awning, sign, scallops and goods should not collide; the counter and posts should, with Box fidelity. See [[Collision and Physics Geometry]].
5. **Emission does not light the world in Roblox.** The glowing lantern needs a real PointLight in the game, and the potions need Neon or a bright texture to keep their glow.
6. **Tilts accumulate.** A 2 degree tilt on a post plus a 1 degree tilt on the counter can open visible gaps at joints. Tilt leaf parts freely; keep parts that touch each other within a degree of each other.
7. **Seeded randomness is order dependent.** Adding a new random call early in the script (for example a new jitter on the skirt) shifts every plank after it. Add new random parts at the end, or seed per section.
8. **Readable at game distance.** Details smaller than about 0.3 studs (the stems, the price tag) vanish beyond 30 studs. That is fine for flavour; the silhouette must work without them.

## Common mistakes

1. **Hand-typed awning angle.** Symptom: the awning floats or cuts through posts when a post height changes. Fix: derive the angle from anchor points with `atan2`.
2. **Diagonal braces sized by eye.** Symptom: ends poke through the side panels. Fix: compute length from the opening, angle and bar height.
3. **Hex colours used as linear values.** Symptom: washed-out wood and fabric. Fix: convert with the power 2.2 helper or use an sRGB texture.
4. **Text left as a curve.** Symptom: the sign is missing in the export. Fix: convert to mesh first.
5. **No bevels.** Symptom: the stand reads as grey-boxed blockout even with good colours. Fix: angle-limited bevels on every hard part.
6. **Every plank the same width.** Symptom: a fence-like, machine look. Fix: random widths in a narrow range and two tones.

## Checklist

- [ ] Seed set; all sizes in studs; faces -Y
- [ ] Every hard part bevelled with an angle limit
- [ ] Repeats varied in width and tone; small tilts everywhere
- [ ] Diagonals sized from the opening they span
- [ ] Sloped parts derived from anchor points
- [ ] One focal feature that reads in silhouette
- [ ] Text converted to mesh
- [ ] Triangles counted on the exported, bevelled meshes
- [ ] Parts joined by material for reuse; collision only on structure

## Related decisions

- [[Modular Environment Kits]]: turning one stall into a kit of interchangeable parts.
- [[Low-Poly Tree Set Worked Example]]: the same script-first approach for scatter props.
- [[Colour Scripts and Value Structure for Untextured Art]]: choosing the palette so the focal feature wins.
- [[Exporting and Validating Models for Roblox]]: checks to run on the GLB.
- [[Blender 5 Python Gotchas for Headless Builds]]: API traps hit in builds like this.
- [[Procedural Blender Assets Start Here]]: the other builds in this section.

## Connected notes
<!-- auto-links:start -->
[[Proportion Exaggeration and Gameplay Distance]] · [[Style Bibles for Consistent Models]] · [[Mesh Optimization for Mobile]] · [[Spending Triangles Where the Camera Looks]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Hard-Surface Modeling]]
<!-- auto-links:end -->
