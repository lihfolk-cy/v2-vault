---
tags: [modeling, low-poly, stylized, palette, vertex-colors, blender, art-style]
---
# Low-Poly and Stylized Modeling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Timid proportions -> Exaggerate scale contrast and one feature
> - Avoid: Straight parallel lines everywhere -> Tapers, bulges, tilts
> - Avoid: Too many segments "to be safe" -> Segment by on-screen size
> - Dominant shape language chosen per asset (round, square, triangle).
> - One focal feature; exaggerated proportions; tapers and tilts.
> - Segment counts chosen by on-screen size.
>
> Read more (13 KB note): ## 4. Colouring without unique textures · ## 5. Building common stylised assets · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most successful Roblox games are stylised: chunky shapes, saturated colours, simple materials, readable at a glance on a phone. That is not only taste. Stylised art ages slowly, survives low graphics settings, keeps texture memory tiny, and lets one artist (or one script) build a whole world. This note covers the two related styles, **faceted low-poly** and **smooth stylised**, how to design shapes for them, how to colour them without per-asset textures (palette atlases and vertex colours), segment counts that look right at Roblox camera distances, and the production tricks that let one geometry serve ten zones.

For hard edges and bevels see [[Hard-Surface Modeling]]; for blocky and voxel looks see [[Voxel and Blocky Modeling]]; for hand-painted textures see [[Hand-Painted and Stylized Texturing]].

---

## 1. Two styles that are often confused

| | Faceted low-poly | Smooth stylised |
|---|---|---|
| Look | Visible flat triangles, gem-like, origami | Soft chunky forms, cartoon proportions, smooth shading |
| Shading | Flat (each face its own normal) | Smooth with weighted normals; bevels |
| Colour | Flat colour per face or per region, often gradients by face | Flat or hand-painted, gradients across forms |
| Triangle count | Very low (100-2,000 per prop) | Low to medium (500-8,000 per prop) |
| GPU vertex cost | Higher than it looks: flat shading splits every vertex (about 3 GPU vertices per triangle) | Lower per triangle (shared vertices) |
| Famous risk | Looks cheap if the shapes are random | Looks like "mobile asset pack" if proportions are timid |

Both live or die on **shape design**, not technique.

---

## 2. Shape design for stylised art

### Shape language

- **Circles and soft curves** read friendly (pets, shops, healers).
- **Squares and blocks** read stable, strong, trustworthy (forges, banks, tanks, golems).
- **Triangles and spikes** read dangerous, fast, aggressive (enemies, thorns, crystals, villain architecture).

Mix with a dominant shape: a friendly shop is mostly round with a few square elements; an enemy fortress is mostly triangles on a square base.

### Proportion rules that make stylised art read

- **Exaggerate scale contrast.** Big things bigger, small things smaller. A lantern on a stylised shop is twice the "real" size.
- **Thick everything.** Rims, trims, handles, roof edges. Thin parts flicker and vanish on a phone screen.
- **Tapers and bulges.** Pillars bulge in the middle or flare at the base; roofs sag; tree trunks flare into roots. Straight parallel lines look like untextured programmer art.
- **Tilts and imperfection.** Rotate stacked objects 2-6 degrees, lean posts, vary plank widths. The reference project tilted its forest trees up to 4 degrees and jittered every crown.
- **One focal feature per object.** A gem, a sign, a glowing core. The rest supports it.

### Readability tests

- Black silhouette test (see [[Modeling Fundamentals for Games]]).
- **Squint test**: blur your eyes at the Blender viewport; you should still see 2-3 value groups (dark, mid, light).
- **Thumbnail test**: render at 128 px. If it reads there, it reads in game.

---

## 3. Segment counts that look right

The question beginners ask most: how many sides should this cylinder have? Answer by on-screen size, not by object type.

| On-screen role | Sides around a cylinder or sphere ring | Example |
|---|---|---|
| Tiny detail (bolt, button, rivet) | 4-6 | A rivet is a 6-sided cylinder or a bevelled cube |
| Small held or worn part | 6-8 | Sword grip, potion neck, handle |
| Medium prop | 8-12 | Barrel, lamp post, pipe |
| Large visible curve | 12-24 | Tower, fountain basin, wheel rim |
| Hero silhouette curve seen up close | 24-48 | A giant halo ring, a dome in the hub |

Stylised trick: an **octagon** (8 sides) bevelled with one segment reads as round at most game distances and catches light on 16 edges. The reference project's hub fountain basin and roll altar were octagonal (`r 19` basin, 3 octagonal marble tiers), which also matched its "8 rarity gems" and "8 gold jet spouts" design.

Faceted styles go lower on purpose: a 5-sided tree trunk and a 20-triangle icosphere canopy are the style.

---

## 4. Colouring without unique textures

Stylised assets rarely need a unique texture each. Three cheap methods:

### A. Palette (gradient) atlas

One small texture (for example 256 x 256 or even 64 x 64) contains swatches of every colour in the game's palette, sometimes as gradients (dark to light). Each face's UVs are scaled down to a point or a tiny area inside the right swatch. Every asset in the world shares the one texture.

Advantages:
- One texture for hundreds of assets: tiny memory, consistent palette.
- Recolouring a whole zone is a texture swap.
- Works with smooth and flat shading.

The reference project built its second realm's hand-modelled map this way: a Python library with "palette-strip UVs + bmesh primitives", and wall pieces shipped with "one geometry, zone palette = TextureID swap" so one canyon wall served ten zones with ten palettes (Measured).

```python
# Blender: snap each face's UVs into a palette swatch chosen by its material index.
# Palette image: a horizontal strip of N equal swatches. Material slot i -> swatch i.
import bpy, bmesh

N_SWATCHES = 16
obj = bpy.context.active_object
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(obj.data)
uv = bm.loops.layers.uv.verify()                     # get or create the active UV layer
for face in bm.faces:
    i = face.material_index % N_SWATCHES
    u = (i + 0.5) / N_SWATCHES                        # centre of swatch i
    for loop in face.loops:
        loop[uv].uv = (u, 0.5)                        # whole face samples one texel area
bmesh.update_edit_mesh(obj.data)
bpy.ops.object.mode_set(mode='OBJECT')
```

Use material slots in Blender only as "colour IDs" while modelling, then assign one material with the palette texture to everything and delete the extra slots before export (Roblox wants one surface per MeshPart; see [[Modeling Fundamentals for Games]]).

Gotchas:
- **Texture filtering bleeds neighbours.** Put UVs at swatch centres and leave padding (swatches at least 4-8 px wide even on a small strip). Mip levels blur further, so the farther the asset, the more swatches blend: use few, distinct swatches.
- **Gradients by height**: for a "dark at the bottom, light at the top" look, map each vertex's U or V to its height within a gradient swatch instead of a single point.

### B. Vertex colours

Store colour per vertex (Blender: *Color Attributes*). Roblox's importer reads vertex colours from FBX and glTF (Docs; the importer has an *Ignore Vertex Colors* option). Free in memory, no UVs needed.

Limits: colour changes need geometry (a colour boundary needs an edge), and the GLB exporter only writes vertex colours when told to (the default "Material" mode only exports them if the material uses them; see [[Exporting FBX vs GLB]]). How Roblox combines vertex colour with `Color`, `TextureID` and `SurfaceAppearance` differs by setup; test one asset before committing a whole pipeline. Details in [[Trim Sheets Atlases and Vertex Colors]].

### C. Part colour plus a shared greyscale texture

Roblox MeshParts have a `Color`. With a SurfaceAppearance using a tint mask (see [[Materials MaterialVariants and SurfaceAppearance]]), one greyscale texture serves every colour variant. The reference project's armour used one shared trim texture with a tint mask for all 6 sets, colour per set. Its studded voxel stations used one stud overlay texture on every mesh with `Color` per mesh.

---

## 5. Building common stylised assets

### Rocks

1. Cube, subdivide twice (Simple), add Displace with a Voronoi or Clouds texture, strength about 20 percent of the size.
2. Decimate *Collapse* to about 100-300 triangles, then *Planar* to merge near-flat faces into bigger facets.
3. Flat-shade (faceted) or bevel lightly + weighted normals (chunky).
4. Squash it: rocks wider than tall sit better on the ground.

Make 4-6 variants and scatter them with random rotation and scale; nobody notices repetition in rocks.

### Trees

- Trunk: 5-8 sided, tapered, with a root flare (extrude the bottom loop outward) and one or two branches.
- Canopy: 3-5 overlapping blobs (icospheres subdivided once, displaced, decimated) in two or three greens. Darker blobs underneath, lighter on top: fake lighting that survives any sky.
- Budget: 200-1,500 triangles for a stylised tree. The forest is many trees; see [[Foliage Props and Scatter]].

### Buildings

- Start with a blockout from cubes at real stud sizes (doors at least 1.5x player height wide and tall: a 9-stud player needs about 12-14 stud doorways to feel comfortable in third person; rule of thumb).
- Thick walls (1-2 studs), visible roof overhang, chunky window frames.
- Bevel the big edges, sag the roof line, lean the chimney.

### Water and effects shapes

Stylised water is often a mesh with a few big waves, a flat colour and a lighter foam edge mesh. The reference project's hub waterfalls were "stepped sheet + core" meshes with side streams, pools and foam, animated by scrolling beams and particles, at 3-5k triangles per tier. See [[Water Sky and Atmosphere Art]].

---

## 6. Flat vs smooth shading in Roblox

- **Flat-shaded meshes** look faceted at any distance. Each face carries its own normals, so GPU vertices roughly triple. For low triangle counts this is fine; for a 15,000-triangle model it is noticeable memory.
- **Smooth-shaded low poly** can look blobby: fix with weighted normals and Smooth by Angle (30-40 degrees). See [[Hard-Surface Modeling]].
- **Mixed**: smooth shade organic parts, flat shade crystals and gems. Mark sharp edges between them.

Roblox's lighting (sun, shadows, ambient, bloom) does most of the shading work in stylised games. Test under the game's actual `Lighting` settings (see [[Lighting Technologies and Settings]]).

---

## 7. Meshes or Studio Parts?

Stylised art can also be built directly in Studio from Parts, WedgeParts and unions. It is the fastest route for blockouts and simple architecture, and needs no import step. Its limits:

- **Every Part is an instance.** A detailed stylised building from Parts can be hundreds of instances where one mesh would be a handful. The reference project once replaced its hub's cliff visuals with 1,231 anchored Parts and WedgeParts, workable for one hub, not for a whole world.
- **Unions** reduce instance counts but can carry heavy collision and rendering data; see [[Parts Unions and MeshParts]].
- **Curves are expensive** in Parts (many small wedges) and cheap in meshes.

A common professional split: greybox in Parts, ship in meshes. The reference project's rule for its later realms was exactly that: "Greybox = Terrain + temporary Blockout_<Name> Parts only, replaced 1:1 by Blender assets", each blockout carrying the pivot and footprint the final mesh must match.

---

## 8. Budgets for stylised assets

Rules of thumb, compared with the reference project's shipped numbers:

| Asset | Stylised budget (rule of thumb) | Reference project |
|---|---|---|
| Small prop (crate, barrel, lamp) | 100-800 | |
| Medium prop (cart, stall, statue) | 1,000-4,000 | Daily chest 8k (hero, one in the world) |
| Hero landmark | 5,000-10,000, LOD on | Altar 7.3k, fountain 9.2k, spinner 7.2k |
| Tree | 200-1,500 | |
| Modular wall | 500-4,000 | Canyon wall about 3.5k |
| Regular enemy (smooth stylised, painted atlas) | 3,000-6,000 | Plan: 3-6k |
| Boss | 10,000-15,000 | Plan: 10-15k |

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Timid proportions | Looks like a cheap asset pack | Exaggerate scale contrast and one feature |
| Straight parallel lines everywhere | Programmer art | Tapers, bulges, tilts |
| Too many segments "to be safe" | Wasted triangles | Segment by on-screen size |
| Per-asset textures for flat-colour art | Texture memory waste | Palette atlas, vertex colours or Color + tint mask |
| Palette UVs on swatch edges | Colour bleeding, worse at distance | Centre UVs, pad swatches |
| Thin details | Flicker, vanish on phones | Thicken; drop them |
| Judging in Blender's lighting only | Washed out or muddy in game | Check in Studio's real lighting |

## Checklist

- [ ] Dominant shape language chosen per asset (round, square, triangle).
- [ ] One focal feature; exaggerated proportions; tapers and tilts.
- [ ] Segment counts chosen by on-screen size.
- [ ] Colour via palette atlas, vertex colours or Color + shared texture, not a unique texture.
- [ ] Shading: flat on purpose, or smooth with weighted normals.
- [ ] Passed silhouette, squint and 128 px thumbnail tests.
- [ ] Within the stylised budget for its class.

## See also

[[Modeling Fundamentals for Games]] · [[Hard-Surface Modeling]] · [[Voxel and Blocky Modeling]] · [[Environment Art Styles]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Hand-Painted and Stylized Texturing]] · [[Foliage Props and Scatter]] · [[Modular Environment Kits]] · [[Parts Unions and MeshParts]]

## Connected notes
<!-- auto-links:start -->
[[Untextured Stylised Modelling Start Here]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Low-Poly Tree Set Worked Example]]
<!-- auto-links:end -->
