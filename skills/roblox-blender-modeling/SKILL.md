---
name: roblox-blender-modeling
description: 'LihFolk: make Roblox-ready models in Blender with an automatic quality gate (symmetry, caps, budgets, export). Use whenever a prop, weapon, building, rock, tree, creature or kit is modelled, fixed or exported.'
---

# LihFolk Blender Modeling for Roblox

Goal: every model ships at top-tier quality, correctly scaled, within budget, and imports cleanly into Roblox Studio. A model that fails the gate or scores below the rubric is not finished.

Sources: `references/quality-research.md` (sourced, labelled research: Roblox docs, measured Blender 5.2 behaviour, expert practice). Helpers: `scripts/lihfolk_bpy.py` (tested on Blender 5.2), `scripts/lihfolk_curves.py` (curves, sweeps, outlines) and `scripts/lihfolk_house.py` (house and building modules).

## Load the helpers

In Blender MCP `execute_blender_code` or a headless script:
```python
import sys; sys.path.append(r"<this skill dir>/scripts")
import importlib, lihfolk_bpy as lf; importlib.reload(lf)
lf.setup_scene()   # 1 Blender unit = 1 stud
```
Headless: `blender -b --factory-startup --python my_script.py`. Never modify the user's open scene destructively; build in a new collection or a temporary scene and confirm before deleting anything that existed.

## Houses and buildings: `scripts/lihfolk_house.py`

For any house, cabin, cottage, shop, tower or hut, build from the parameterised builders instead of starting from scratch (`import lihfolk_house as lh`). The method, the scale numbers and the style-swap table are in the vault note `House Construction Method - Modular Kit Workflow` (06 World Building and Art).
- Frame: footprint centred on the origin, ridge along Y, eave walls on x = +-hx, gable walls on y = +-hy. `lh.Gable(hx, eave_z, pitch)` is the one roof-underside function that walls, roof, chimney and icicles all read.
- Walls: `lh.log_walls` (interlocking round logs, gable logs cut by the roof) or `lh.coursed_walls` (stone / brick blocks, corner bond, quoins, lintels). Both cut real openings, so interiors work later.
- Openings: plan them first with `lh.opening_footprint` and `lh.check_wall_layout` (frames and shutters must fit between the corners). Then add `lh.window`, `lh.door` and `lh.steps` on a `Face`.
- Roof: `lh.gable_roof` (slab or shingle rows, ridge cap, optional snow with a lip) and `lh.icicle_row(z_at=roof["snow_under"])`. Add `lh.chimney`, `lh.foundation` and `lh.plank_deck` as needed.
- Pipeline: put one module in each `lh.MeshBuilder`. Then run `lh.recentre` (one shared bottom-centre origin), `lh.finish_modules` (adds Triangulate for n-gons after the bevel), `lh.gate_modules`, `lh.floating_shells` (a whole-house scan; it must report 0), `lh.render_preview` and `lh.export_modules`.
- Verified headless on Blender 5.2: a stone cottage (7 modules, every gate passed, 0 of 317 shells floating) and a log cabin (6 modules, every gate passed, 0 of 161 floating).

## Pipeline (do every step)

1. **Brief**: object class (budget key below), style, palette (2-3 colours + 1 accent), real size in studs (R15 avatar ~5 studs tall; door ~7-8 studs), where its origin goes.
2. **Blockout big -> medium -> small**. Check the silhouette before any detail: `lf.render_review(ob, dir)` and look at `_silhouette.png`. If it doesn't read at thumbnail size, fix shapes, not details.
2b. **Symmetry and alignment first.** If the object is symmetric by design (shields, badges, swords, bottles, doors, most props and creatures), model one half and mirror it. Centre every feature (emblems, gems, handles, guards) on the parent's axis with bounding-box maths, never by eye, and seat it on its surface (no floating, no burying). The gate checks this (`symmetric=`); a lopsided shield is an automatic fail, however clean its mesh.
3. **Proportion pass**: exaggerate. Chunky, tapered, confident shapes beat accurate stiff primitives.
4. **Edge treatment**: `lf.finish(ob, style="soft")` (1-segment bevel + harden normals + weighted normals, the stylized default), `"faceted"` (deliberate flat low-poly) or `"smooth"` (organics). More than 2 bevel segments on small props is a mistake (1 seg = 3.7x tris, 2 = 9x on a box, measured).
5. **Colour**: vertex colours or one shared palette atlas for stylized kits; SurfaceAppearance PBR (OpenGL normal, separate grayscale roughness/metalness) for realistic. One material per exported object.
6. **UVs** (if textured): smart_project -> pack_islands, single UV map, all in 0-1.
7. **Origin**: `lf.set_origin(ob, "bottom")` floor props, `"back"` wall props, `"corner"` modular pieces.
8. **Gate**: `passed, fails, report = lf.gate(ob, cls, symmetric="X", align=..., seats=...)`. Any fail = fix and re-run. Never ship a fail. Besides A1-A10 it checks A15 symmetry (`lf.symmetry_error`; author symmetric shapes as half + `lc.mirror_outline`), A16 centring/seating (`lf.alignment_report`, `lf.seated`, computed on the parts before joining), A17 self-intersecting shells and A18 overlapping cap triangles / flipped faces.
9. **Visual rubric**: render with `lf.render_review(ob, dir, features=[(name, centre, radius), ...])` (adds studio + flat close-ups of each child feature, where small cap artifacts show), LOOK at every image, then have a blind reviewer score V1-V9 (rubric review order: correctness, then artifacts, then style). Accept only >= 14/18 with no zero. Otherwise iterate. Colour stylised kits with `lc.paint` + `lc.vertex_color_material` (one white material, vertex colours).
10. **Export**: `lf.export_glb(ob, path)` (preferred; modifiers applied, vertex colours kept, 1 unit = 1 stud). FBX only via `lf.export_fbx` (prevents the 100x scale bug).
11. **Studio setup** (tell the user or do it via Studio MCP): MeshPart.Color = white when using vertex colours; CollisionFidelity Box/Hull (Precise only when needed); CanCollide/CanTouch/CanQuery off for decoration; CastShadow off on tiny props; DoubleSided only for foliage cards; Anchored for static.

## Triangle budgets (`lf.BUDGETS`, target / ceiling)

tiny 150/300 · small 600/1,500 · medium 2,000/4,000 · rock 400/1,000 · tree 2,000/5,000 · weapon 2,500/4,000 · module 800/2,000 · building 6,000/10,000 (split into modules above) · creature 5,000/10,742 · hero 10,000/20,000. Hard Roblox limit: 20,000 per mesh. Over target needs a stated reason. These budgets are proposed defaults inside sourced ranges; tune per game.

## Visual rubric (0-2 each, accept >= 14/18, no zeros)

V1 silhouette reads as solid black at 64 px from every angle · V2 clear big/medium/small hierarchy · V3 confident stylized proportions · V4 consistent bevels catching light · V5 clean shading, no gradients/artifacts on flat faces · V6 2-3 dominant colours with value contrast · V7 geometry only where silhouette/shading needs it (if the wireframe looks solid, too dense) · V8 matches the kit (texel density, bevel size, palette) · V9 Studio-ready (scale, pivot, collision, flags).

Score honestly from the renders. For hero assets, or when your score is borderline (14-15), run a **Quick** `council` (Art Director lens) with the four renders as evidence. Kits: review one representative piece, not every piece.

## Styles

| Style | How |
|---|---|
| Stylized low-poly | Primitives -> exaggerate -> `finish("soft")` or `"faceted"`; organics: Decimate Collapse ~0.1-0.15 for rocks/trees; icosphere foliage clusters; vertex colours |
| Untextured stylized | Split by colour region or vertex colour; MeshPart.Color + Material in Studio |
| Palette atlas | One small palette PNG shared by the whole kit; UVs snapped to cells, closest filtering |
| Hand-painted | Clean UVs, bake AO, paint flat colours plus subtle light/shadow; ColorMap only |
| Realistic PBR | High->low bake, OpenGL normal, separate R/M maps, trim sheets for architecture; Future lighting |
| Voxel | MagicaVoxel -> greedy meshing -> vertex colours; never thousands of Parts |

Kits: build modular pieces on a stud grid (multiples of 1, 2 or 4 studs), shared bevel width, shared palette, origin at the grid corner, so they snap in Studio.

## Known traps (measured or documented)

- glTF `export_apply=False` (the default) silently drops bevels and weighted normals. `lf.export_glb` handles this.
- glTF drops vertex colours unless exported as ACTIVE. Handled.
- FBX default scale imports 100x too big. `lf.export_fbx` uses FBX_SCALE_UNITS.
- `mesh.use_auto_smooth` no longer exists (Blender 4.1+); use `shade_auto_smooth` / `finish("smooth")`.
- AO bakes come out black when other objects occlude the target; hide others from render first.
- Roblox wants separate grayscale roughness/metalness maps, not packed ORM.
- Don't hand-author LODs: Roblox auto-generates them, and RenderFidelity is being removed.
- AI/scan meshes ("triangle soup"): retopo or decimate, then rebake; never ship raw.

## Reusing the LihFolk Asset Pack

If the pack is installed (`LIHFOLK_ASSETS` env var or `~/LihFolk-Assets`), check its original LihFolk models and materials before modelling from scratch; pack assets already passed this gate. See `../../assets/README.md`.

## Open questions (verify in Studio before relying on them)

Whether custom normals survive import, glTF double-sided flag handling, FBX forward axis. See `references/quality-research.md` section 7.
