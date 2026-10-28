# Recipes: 3D model (shipped defaults; the project ledger refines these)

## First-pass defaults
- `lf.setup_scene()`: 1 Blender unit = 1 stud. Size against an R15 avatar (about 5 studs tall; doors 7-8).
- Block out big, then medium, then small; check `_silhouette.png` **before** any detail.
- Edge treatment `lf.finish(ob, "soft")`: 1-segment bevel, harden normals, weighted normals, bevel width about 2-5% of the object's smallest dimension (crate 3 studs = 0.15).
- Palette: 2-3 colours plus 1 accent, with clear value contrast.
- Origin: `bottom` for floor props, `back` for wall props, `corner` for modular pieces.
- Export only with `lf.export_glb` (applies modifiers, keeps vertex colours, 1:1 scale).

## Pre-empt (most common first-draft misses)
- A6 transforms not applied: `lf.finish` applies them, so call it before the gate.
- V4 inconsistent bevels: one bevel width per kit.
- V1 silhouette reads only from the front: exaggerate depth and side profile.
- Over-bevelling: more than 2 segments on small props multiplies tris 9x or more (Measured).

## Proven fixes
| Miss | Fix |
|---|---|
| Shading gradients on flat faces | Weighted Normal (keep sharp) after the bevel |
| Bevels missing in Studio | `export_apply=True` (the GLB default drops modifiers) |
| Model imports 100x too big | GLB, or FBX with `FBX_SCALE_UNITS` |
| Grey mesh in Studio | Export vertex colours as ACTIVE; MeshPart.Color white |
