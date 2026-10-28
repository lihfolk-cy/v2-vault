---
tags: [blender, python, bpy, bmesh, headless, gotchas]
---
# Blender 5 Python Gotchas for Headless Builds

Traps hit while building assets with `blender -b --factory-startup --python build.py` on Blender 5.2 (October 2026). Each cost a render or a crash; most are one-line fixes.

## Rendering and compositing

| Trap | Fix |
|---|---|
| `scene.node_tree` for the compositor no longer exists | Create a `CompositorNodeTree` node group, assign it to `scene.compositing_node_group`, add a Group Output socket with `ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")` |
| Glare settings are not node properties any more | They are inputs: `gl.inputs["Type"]`, `["Threshold"]`, `["Strength"]`, `["Size"]`, `["Quality"]`; set them in a try block |
| Glare defaulted to Streaks | Set `Type` to "Bloom" explicitly |
| Engine name differs between versions | Pick `BLENDER_EEVEE` if it is in the engine enum, else `BLENDER_EEVEE_NEXT` |
| Light reflections show as glowing blobs on a glossy floor | Set `light.specular_factor = 0` on fill lights |
| Workbench silhouette render | `display.shading.light = "FLAT"`, `color_type = "SINGLE"`, black colour, white viewport background, and clear the compositor group |
| `file_format = "FFMPEG"` is rejected when rendering a video | Set `scene.render.image_settings.media_type = "VIDEO"` first (in a try block for older versions), then FFMPEG, container and codec |
| Glowing FX meshes (ribbons, ghosts, sparkles) throw dark shadows on the floor | Set `obj.visible_shadow = False` on every effect object |
| Objects from an opened .blend (for example a rig file) exist in `bpy.data` but neither render nor deform | Their collection loads excluded or unlinked: link orphan collections to `scene.collection`, then clear `exclude` and `hide_viewport` recursively on the view layer's layer collections |

## Geometry

| Trap | Fix |
|---|---|
| `create_icosphere(subdivisions=1)` is only 20 faces | Use 2 for a rounded faceted blob |
| `bm.faces.new` raises ValueError on duplicate or degenerate outlines | Wrap in try/except and skip that shape |
| `bmesh.ops.bevel` overlapping on thin parts | Pass `clamp_overlap=True` |
| `uv.sphere_project` needs a 3D view context (fails headless) | Compute UVs yourself from the vertex position |
| Separate objects with one vertex group each, joined | Joining merges vertex groups by name; this is the easiest way to build rigid skinning |
| A bmesh float layer becomes a mesh attribute of the same name | Read it in the shader with an Attribute node |
| Object coordinates are in mesh space, before object rotation | A disk built in XY and rotated to face the camera still has its pattern in X and Y |
| After a dissolve or delete, `bm.from_mesh()` puts new faces into freed slots, so `bm.faces[n0:]` is not the new faces | Tag the existing faces first (`f.tag = True`), join, then treat the untagged faces as new |

## Materials

- Emission is `Emission Color` plus `Emission Strength` on the Principled BSDF; `Coat Weight`, `Sheen Weight`, `Specular IOR Level`, `Transmission Weight` are the new names. Check `name in b.inputs` before setting.
- The Mix node with `data_type = "RGBA"` uses inputs 6 and 7 for A and B and output 2 for the result.
- Light Path "Is Camera Ray" in the world lets an HDRI light the scene while the camera sees a plain backdrop.

## Process

- **Keep the build script the source of truth.** Every change is a small edit followed by a rerun; that makes undoing a single change trivial.
- **Edit tools may refuse to overwrite a file you changed with a shell command.** Re-read it first, or write the new version under a new name.
- **Never run `read_factory_settings` through a live Blender connection** to someone's open session: it wipes their scene. Build headless, then append the result into their file as a new scene.
- **Long paths with spaces:** quote them; keep build folders on short paths.

Related: [[Blender Workflow for Roblox Creators]], [[Modeling in Blender for Roblox]], [[Procedural Blender Assets Start Here]].

## Nuances and edge cases

1. **Headless is not the same as "no context".** Many operators (`bpy.ops.*`) check for an area, region or active object and fail with a poll error when run from `-b`. The bmesh and data APIs (`bpy.data`, `bmesh.ops`) do not need a screen, so a headless build should prefer them. When an operator is unavoidable, a `bpy.context.temp_override(...)` with an explicit object and selection usually works, but anything that needs a 3D viewport (view-dependent UV projections, viewport screenshots) will not. Plan the script around data APIs from the start.
2. **Version drift is the main long-term cost.** Every major Blender release renames something: socket names on the Principled BSDF, the compositor setup, engine identifiers. A script that works on 5.2 can fail on 5.3 with a KeyError in a material block. Two defences: guard every socket set with `if name in node.inputs`, and pin the Blender version a build was made with in a comment or a small manifest next to the output. Rebuilding old assets on a newer Blender is a deliberate step, not something that happens silently.
3. **`--factory-startup` hides user add-ons on purpose.** It makes builds reproducible across machines, but it also disables any exporter or add-on the artist relies on interactively. If the script needs an add-on, enable it explicitly in the script with `addon_utils.enable(...)` so the build does not depend on someone's preferences.
4. **Random numbers must be seeded per asset, not per run.** If one script builds ten props from one `random.seed`, adding an eleventh prop in the middle shifts every prop after it. Seed per asset (for example from a hash of the asset name) so adding a prop changes only that prop.
5. **Units and scale on export.** Blender works in metres; Roblox thinks in studs. A script that builds at "1 unit = 1 stud" must export with a scale that matches the importer's expectation, and that pairing should be tested once with a known 4 by 4 by 4 cube. If the cube arrives at 0.04 or 400 studs, fix the exporter setting in the script, not by scaling in Studio.
6. **Memory on large batches.** A single headless process that builds 200 assets in a loop accumulates orphan data blocks (meshes, materials, images) unless you remove them. Either purge orphans between assets, or run one Blender process per asset from a driver script. One process per asset is slower to start (a few seconds each) but cannot leak between assets and isolates crashes.
7. **Rendering on machines without a GPU.** Eevee needs a GPU context; on a headless server or CI runner without one, it may fail or fall back. Cycles on CPU works anywhere but is much slower. For preview renders in automation, decide which machine renders and test it there, not on the artist's desktop.
8. **Live connections are shared state.** When an agent or a tool drives Blender through a live socket (for example an MCP bridge), every call runs inside the artist's open file. Anything that resets settings, deletes objects or changes the active scene affects their work immediately. Build in a headless process, then append the finished scene.

## Common mistakes

1. **Setting a socket that no longer exists.** Symptom: `KeyError: 'bpy_prop_collection[key]: key "Emission" not found'`. Fix: use the new names (`Emission Color`, `Emission Strength`) and guard with a membership test.
2. **Relying on operator context in `-b` mode.** Symptom: `RuntimeError: Operator bpy.ops.uv.sphere_project.poll() failed, context is incorrect`. Fix: compute the data directly (UVs from vertex positions) or use the bmesh equivalent.
3. **Leaving a bmesh unflushed.** Symptom: the script runs but the mesh is empty or unchanged on export. Fix: call `bm.to_mesh(mesh)` and `bm.free()` before exporting or rendering.
4. **Not checking the engine enum.** Symptom: the render engine assignment raises a TypeError on a different version. Fix: read the enum items and pick the one that exists.
5. **Writing outputs next to the script with relative paths.** Symptom: files appear in Blender's install folder or the current working directory of whoever launched it. Fix: build every output path from `os.path.dirname(os.path.abspath(__file__))` or an explicit argument.
6. **Swallowing every exception.** Symptom: a build "succeeds" but half the shapes are missing because each `bm.faces.new` failure was skipped silently. Fix: catch only ValueError on that call, and count and print skips so a rise is visible.
7. **Exporting without applying transforms.** Symptom: assets arrive rotated 90 degrees or scaled in Studio. Fix: apply rotation and scale before export and check the up axis setting once.

## Related decisions

- [[Blender Automation with Python]]: the wider pipeline this list of traps belongs to.
- [[Pipeline Design Principles]]: why the build script should stay the single source of truth.
- [[Exporting FBX vs GLB]]: which format a headless build should target.
- [[Exporting and Validating Models for Roblox]]: the checks to run on every output before upload.
- [[Asset Upload Automation with Open Cloud]]: the step after a headless build, uploading without opening Studio.
- [[Icon and Thumbnail Rendering Pipeline]]: reusing the same headless renders for icons.
- [[Blender MCP]]: when a live connection is used instead, and its risks.
- [[Safety Rules for AI Agents in Studio]]: the same "never wipe someone's open session" rule on the Roblox side.
- [[Code Pipeline - Rojo Git and CI]]: putting build scripts under source control and running them in CI.

## Connected notes
<!-- auto-links:start -->
[[Dash VFX Presentation on an R15 Rig]] · [[Dramatic Showcase Renders in Eevee]] · [[Texturing and PBR Baking]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Rigging in Blender]]
<!-- auto-links:end -->
