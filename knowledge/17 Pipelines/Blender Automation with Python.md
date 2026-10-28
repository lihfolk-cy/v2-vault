---
tags: [pipelines, blender, python, automation, voxel, export, headless]
---
# Blender Automation with Python

Blender ships with a full Python API (`bpy`) and runs without a window (`blender -b`). That turns it from a modelling app into a **build tool**: a script can create a model from parameters, enforce a style, validate budgets, export a GLB, render previews and icons, and do it again identically for 150 items. One production game built almost every asset this way (weapons, armour, enemies, pets, eggs, hub hero pieces, station kits, wall rebuilds) and could restyle whole sets by editing a palette table and re-running. This note covers the setup, the patterns that make scripts reliable, a working voxel builder, export, batch drivers and the traps. Modelling technique is in [[Blender Workflow for Roblox Creators]]; the art pipeline around these scripts is in [[Art Pipeline - Concept to In-Game Asset]]; interactive AI-driven Blender work is in [[Blender MCP]].

## Why script models at all

| Hand-made `.blend` | Scripted build |
|---|---|
| style lives in the artist's head | style lives in shared helper code |
| a palette change means repainting every file | a palette change is one table edit and a re-run |
| naming and transforms drift | names and transforms are always right |
| hard to review | diffable in Git |
| one-off | parametric: variants, sizes, rarities from one script |

It is not either/or. Sculpted and organic shapes are made by hand; the script then **imports** them, applies materials and naming, validates and exports. The rule is: **everything after the creative shape is scripted**.

## Running Blender headless

```text
blender -b --factory-startup --python build_thing.py -- <args for the script>
```

- `-b` runs without UI (background).
- `--factory-startup` ignores the user's preferences and add-ons, so every machine and CI runner gets the same result.
- `--python <file>` runs the script after loading; put a `.blend` path before `--python` to open one first.
- Everything after `--` is ignored by Blender and left for your script in `sys.argv`.
- Blender's exit code is 0 even when your script raises, unless you exit explicitly: wrap the main body and call `sys.exit(1)` on failure so drivers and CI see it.

```python
import sys, traceback

def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

def main(a):
    ...

if __name__ == "__main__":
    try:
        main(args())
    except Exception:
        traceback.print_exc()
        sys.exit(1)
```

Windows traps measured in one production game:

- **Paths over 260 characters fail** in Blender and other native executables. The project's scratch folders were deep, so every call used the short 8.3 form of the path.
- **Blender writes deprecation warnings to stderr.** A PowerShell driver with `$ErrorActionPreference = "Stop"` aborts on them. Use `Continue`, filter the output for your own markers (`AUTO`, `Error`, `Traceback`), and check that the expected output file exists.
- **Do not `cd` into the long path** from a shell that then launches native tools; stay in a short working directory and pass absolute short paths.

## Project structure

```text
art/
  lib/
    lib.py          # scene reset, primitives, bevel boxes, join by material, apply transforms
    vlib.py         # voxel helpers: grid to mesh, stud UVs, colour groups
    palettes.py     # named palettes: {"marble_gold": {"marble": (..), "gold": (..)}, ...}
    checks.py       # budget and naming validation
    export.py       # GLB export + sidecar JSON
  models/
    b_<id>.py       # one design per item: calls lib, returns objects
  build.py          # builds one or many ids: blender -b -P build.py -- <ids...>
  run.ps1           # batch driver: loops ids, limits parallel processes, collects logs
  out/<id>/         # <id>.blend, <id>.glb, <id>_parts.json, previews
```

Shared helpers carry the style. The reference project's helper libraries encoded rules like "one mesh per colour", "bevel 0.035", "UVs at 8 studs per tile for the stud overlay", "three-tone colour ramps", so every new design inherited them.

## Pattern 1: reset to a known scene

Start every build from an empty scene so leftovers from a previous run never leak into the export.

```python
import bpy

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # read_factory_settings resets units: set yours explicitly
    s = bpy.context.scene
    s.unit_settings.system = "METRIC"
    s.unit_settings.scale_length = 1.0      # 1 Blender unit = 1 stud by project convention
```

The "1 unit = 1 stud" convention is a common choice, not a Roblox rule; whatever you pick, test it once with a cube of known size through the real import path ([[Exporting and Validating Models for Roblox]]).

## Pattern 2: materials from palette tables

```python
import bpy

def material(name, rgb, emission=0.0, roughness=0.6):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)   # "Emission" in Blender 3.x
        bsdf.inputs["Emission Strength"].default_value = emission
    return m
```

Input socket names changed between Blender versions (`Emission` became `Emission Color` in 4.0). Pin the Blender version for the project and note it in the README; scripts written for one major version often need small fixes for the next.

Colours exported in materials are a hint; in Roblox you usually set `Color` and `Material` per MeshPart at install, from the same palette table exported as JSON. One table, two consumers.

## Pattern 3: a voxel builder

Voxel art is the clearest case for scripting: the model is a grid of coloured cells, and the mesh should contain only the faces you can see, grouped by colour. This builder turns a dictionary of cells into one mesh per colour with hidden faces culled:

```python
# vlib.py : voxel grid -> one mesh object per colour, interior faces removed
import bpy, bmesh
from collections import defaultdict

FACES = {  # direction -> 4 corner offsets (counter-clockwise seen from outside)
    ( 1, 0, 0): [(1,0,0),(1,1,0),(1,1,1),(1,0,1)],
    (-1, 0, 0): [(0,0,0),(0,0,1),(0,1,1),(0,1,0)],
    ( 0, 1, 0): [(0,1,0),(0,1,1),(1,1,1),(1,1,0)],
    ( 0,-1, 0): [(0,0,0),(1,0,0),(1,0,1),(0,0,1)],
    ( 0, 0, 1): [(0,0,1),(1,0,1),(1,1,1),(0,1,1)],
    ( 0, 0,-1): [(0,0,0),(0,1,0),(1,1,0),(1,0,0)],
}

def build(cells, cell=0.25, name="Vox", materials=None):
    """cells: {(x, y, z): colour_key}. Returns {colour_key: object}."""
    by_colour = defaultdict(list)
    for pos, key in cells.items():
        by_colour[key].append(pos)
    out = {}
    for key, positions in by_colour.items():
        bm = bmesh.new()
        verts = {}
        def v(p):
            if p not in verts:
                verts[p] = bm.verts.new((p[0] * cell, p[1] * cell, p[2] * cell))
            return verts[p]
        for (x, y, z) in positions:
            for d, corners in FACES.items():
                if (x + d[0], y + d[1], z + d[2]) in cells:
                    continue                          # neighbour exists: face is hidden
                bm.faces.new([v((x + cx, y + cy, z + cz)) for cx, cy, cz in corners])
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        mesh = bpy.data.meshes.new(f"{name}_{key}")
        bm.to_mesh(mesh); bm.free()
        obj = bpy.data.objects.new(f"{name}_{key}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        if materials and key in materials:
            obj.data.materials.append(materials[key])
        out[key] = obj
    return out
```

Notes:

- Faces between two **different** colours are culled too (the neighbour test ignores colour), which is right for opaque voxels and wrong if one colour is glass; handle transparent colours separately.
- This emits two triangles per visible cell face. Large flat areas waste triangles; merge coplanar faces of the same colour (a greedy mesher, or `bmesh.ops.dissolve_limit` on flat regions) when budgets matter. The reference project's stations used one mesh per colour plus a stud overlay texture rather than modelled studs, because modelled studs cost about 20 triangles per face (see [[Voxel and Blocky Modeling]]).
- Keep the cell size a clean fraction of a stud so models line up with each other and with the stud texture.

## Pattern 4: validate inside the build

Fail the build, not the upload:

```python
import bpy

def report_budget(max_tris_per_mesh=20000, name_re=r"^[A-Za-z0-9_]+$"):
    import re
    problems, total = [], 0
    dg = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        mesh = obj.evaluated_get(dg).to_mesh()
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        obj.evaluated_get(dg).to_mesh_clear()
        total += tris
        if tris == 0:
            problems.append(f"{obj.name}: 0 triangles")
        if tris > max_tris_per_mesh:
            problems.append(f"{obj.name}: {tris} tris > {max_tris_per_mesh}")
        if not re.match(name_re, obj.name):
            problems.append(f"{obj.name}: bad name (letters, digits, underscore only)")
        if any(abs(s - 1.0) > 1e-4 for s in obj.scale):
            problems.append(f"{obj.name}: unapplied scale {tuple(obj.scale)}")
        if len(obj.data.materials) > 1:
            problems.append(f"{obj.name}: {len(obj.data.materials)} materials (Roblox uses one per MeshPart)")
    print(f"BUDGET total {total} tris")
    if problems:
        raise RuntimeError("validation failed:\n" + "\n".join(problems))
```

The 20,000 limit is from the Roblox docs ("Individual meshes can not exceed 20,000 triangles"). The 0-triangle check exists because the reference project once shipped three meshes that were empty (a spine band never built), which only showed up as missing parts in game.

Other checks worth adding: bounds versus the brief, intrusion tests for wearables (the project's armour build tested every piece against every R15 part box at rest, gate 0 intrusions), and vertex colour sanity (all white unless intended).

## Pattern 5: export plus a sidecar

```python
import bpy, json
from mathutils import Vector

def export_glb(path, collection_name="UPLOAD"):
    bpy.ops.object.select_all(action="DESELECT")
    col = bpy.data.collections[collection_name]
    for o in col.all_objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,       # apply modifiers
        export_yup=True,         # glTF convention: +Y up
    )
    parts = []
    for o in col.all_objects:
        if o.type == "MESH":
            bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
            lo = [min(v[i] for v in bb) for i in range(3)]
            hi = [max(v[i] for v in bb) for i in range(3)]
            mat = o.data.materials[0].name if o.data.materials else None
            parts.append({"name": o.name, "min": lo, "max": hi, "material": mat})
    json.dump({"parts": parts}, open(path.replace(".glb", "_parts.json"), "w"), indent=1)
```

The sidecar (`<id>_parts.json`) feeds the installer and the icon renderer, so nothing downstream re-measures the model. Keep an `UPLOAD` collection for exportable objects; helper objects (preview outlines, reference planes, cameras) live elsewhere and never ship. The reference project rendered previews with an inverted-hull outline about 0.16 studs thick that was deliberately **not** exported, since it would have doubled triangle counts.

## Pattern 6: previews and contact sheets

Every build renders a small set of previews (three-quarter, front, side) with a fixed camera and lights, and a batch builds a contact sheet. Reviewers approve from the sheet; nobody opens 40 `.blend` files. Rendering code is in [[Icon and Thumbnail Rendering Pipeline]]; the contact-sheet script is in [[Character and Creature Pipeline]].

## Pattern 7: batch drivers

A driver loops item ids, runs one Blender process per item (or a few items per process to save start-up time), limits parallelism, and collects logs and a summary.

```powershell
# run.ps1 -ids a,b,c [-parallel 2]
param([string[]]$ids, [int]$parallel = 2)
$ErrorActionPreference = "Continue"           # Blender warns on stderr; never Stop on it
$blender = $env:BLENDER_EXE                  # pin the Blender version per project
$env:OMP_NUM_THREADS = "1"
$jobs = @()
foreach ($id in $ids) {
  while (($jobs | Where-Object { $_.State -eq "Running" }).Count -ge $parallel) { Start-Sleep -Milliseconds 300 }
  $jobs += Start-Job -ArgumentList $blender, $id, $PWD.Path -ScriptBlock {
    param($b, $id, $cwd)
    Set-Location $cwd                         # background jobs start in another folder
    & $b -b --factory-startup --python build.py -- $id 2>&1 |
      Select-String -Pattern "BUDGET|ERROR|Traceback|validation failed" | ForEach-Object { "${id}: $($_.Line)" }
    if (-not (Test-Path "out\$id\$id.glb")) { "${id}: FAILED (no glb)" }
  }
}
$jobs | Wait-Job | Receive-Job
```

Measured parallelism rule from the reference project: at most two heavy offline processes per worker (agent or person), with numeric libraries limited to one thread each. More than that starved Studio and contributed to a long freeze.

## The interactive Blender: uploads and MCP

Two jobs need an interactive Blender session:

1. **Uploading through Roblox's Blender add-on**, which signs in inside Blender. The reference project kept one interactive Blender open for uploads only, driven by a queue script, and learned two rules: **never open another `.blend` in that window** (it logged the uploader out mid-queue), and **never print the add-on's tokens**. All other work ran headless. Open Cloud removes the need for the interactive session ([[Asset Upload Automation with Open Cloud]]).
2. **AI-assisted modelling through Blender MCP**, where an agent inspects the scene and runs `bpy` code. The same discipline applies: inspect before changing, set mode and selection explicitly before operators, return structured data, and keep the real build in scripts so the agent's work is reproducible ([[Blender MCP]]).

## Gotchas

| Trap | Effect | Fix |
|---|---|---|
| Operators depend on context (mode, active object, selection) | silent no-ops or wrong object changed | set mode, active and selection before each operator; prefer the data API and `bmesh` |
| Shared mesh data between objects | editing one changes all | `obj.data = obj.data.copy()` before editing |
| Depsgraph not updated | stale world matrices and bounds | `bpy.context.view_layer.update()` after transforms |
| Edit-mode mesh access through `obj.data` | edits lost | use `bmesh.from_edit_mesh` and `update_edit_mesh`, or work in Object mode |
| Orphan data piling up in long sessions | memory growth | build in fresh processes; purge orphans |
| API changes between Blender versions | broken scripts after upgrade | pin the version; small compatibility helpers |
| Names with dots (`Part.001`) | dots mangled on upload, lookups fail | rename to `Part_001` in the build |

## Checklist

- [ ] Headless runs with `-b --factory-startup`; scripts exit non-zero on failure
- [ ] Short paths on Windows; drivers do not stop on stderr
- [ ] Shared helpers and palette tables carry the style
- [ ] Every build starts from an empty scene with explicit units
- [ ] Validation inside the build: tris, empties, names, scale, materials
- [ ] GLB from an `UPLOAD` collection plus a parts sidecar JSON
- [ ] Previews and contact sheets for review
- [ ] Parallelism capped; numeric threads limited
- [ ] Interactive Blender only for uploads or MCP work; tokens never printed
- [ ] Blender version pinned and recorded

## See also

[[Blender Workflow for Roblox Creators]] · [[Modeling in Blender for Roblox]] · [[Voxel and Blocky Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Exporting FBX vs GLB]] · [[Exporting and Validating Models for Roblox]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Blender MCP]] · [[Pipeline Design Principles]]

## Nuances and edge cases

1. **Scripts pay off after the third asset, not the first.** Writing a builder, palette helpers and validation for one prop takes longer than modelling it by hand. The return comes when the same code builds the tenth variant, restyles a whole set, or re-exports everything after a budget change. For a one-off hero asset with lots of sculpted detail, hand modelling is still the right call; scripting suits families of similar assets (weapons of one class, crates, kits, voxel props).
2. **Procedural does not mean good-looking.** Code makes the shapes that are easy to code: tubes, boxes, spheres, extrusions. Without an art direction pass, scripted sets look generic. Keep a reference sheet and compare renders against it, and expect a few rounds of "it looks bad" before the helpers encode the style properly.
3. **Determinism is a feature you have to build.** Random placement, dictionary iteration order and floating-point formatting in sidecars can all change between runs. If the output changes when the inputs did not, the diff and hash-based skips downstream break. Seed per asset, sort keys when writing sidecars, and round numbers to fixed decimals.
4. **Parallel builds and memory.** Running several Blender processes at once speeds up batches until the machine runs out of memory or GPU time for previews. Two to four parallel processes is a common sweet spot on a typical desktop (rule of thumb); measure on your machine. Keep renders and exports in separate passes if the GPU is the bottleneck.
5. **Validation budgets come from the game, not Blender.** Triangle limits, texture sizes and part counts should be read from a shared config the game team owns, so a budget change updates every build. Roblox's own hard limits (for example 20,000 triangles per mesh, 4 bone influences per vertex, Roblox docs as of October 2026) are ceilings, not targets; the game's budget should sit well below them.
6. **Versioning outputs.** A re-exported mesh uploaded to Roblox gets a new asset id (most types cannot be updated in place). Script builds make it easy to regenerate everything, which can flood the inventory with near-duplicate assets. Only upload when the file hash changes, and archive superseded assets.
7. **Who can run the pipeline.** A pipeline only one person can run is a bottleneck and a bus factor. Keep setup to one documented command, pin the Blender version, and avoid depending on add-ons or paths on one machine.

## Common mistakes

1. **Building in the artist's open session.** Symptom: a teammate's scene is reset or overwritten. Fix: always build headless with factory settings, then append.
2. **Hard-coded absolute paths.** Symptom: the script works on one machine only. Fix: paths relative to the script or passed as arguments.
3. **No validation step.** Symptom: an asset over budget is discovered in Studio after upload. Fix: validate triangles, materials and size inside the build and fail loudly.
4. **Unsorted sidecar output.** Symptom: every rebuild shows a diff even when nothing changed. Fix: sort keys, fix decimal places.
5. **One giant script.** Symptom: changing one asset risks breaking all of them. Fix: shared helper library plus one small script per asset family.
6. **Previews rendered with a different look from the game.** Symptom: approved previews look wrong in Studio. Fix: preview with flat, neutral lighting close to the game, plus a separate marketing render if needed.
7. **Skipping a test import.** Symptom: an export setting is wrong for every asset in a batch. Fix: import the first asset of every new batch into Studio before running the rest.

## Related decisions

- [[Procedural Loot and Item Generation]]: the game-side counterpart to procedurally built item art.
- [[Art Budgets - Triangles Draw Calls Memory]]: where the validation budgets come from.
- [[Modular Environment Kits]]: kit families that suit scripted builds.
- [[Case Study - Cutting a Million Instances]]: what unchecked asset counts do to a place.
- [[Git and Source Control for Roblox]]: versioning the build scripts and sidecars.
- [[Roadmaps Milestones and Scope Control]]: deciding when tooling time is worth spending.
- [[Documentation and Onboarding New Developers]]: making the pipeline runnable by more than one person.
- [[Agent Review Loops and Guardrails in Practice]]: letting agents edit build scripts safely.

## Connected notes
<!-- auto-links:start -->
[[Blender 5 Python Gotchas for Headless Builds]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Asset Pipelines]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Voxel Modelling Start Here]] · [[Procedural Blender Assets Start Here]]
<!-- auto-links:end -->
