---
tags: [mcp, blender, ai, agents, modeling, pipeline]
---
# Blender MCP

<!-- tldr:start -->
> [!tldr] TL;DR
> - Every tool fails to connect: Add-on server not started, wrong port, Blender closed -> Start the server in add-on preferences; restart the client
> - Call times out: Blender busy (render, modal operator, dialog) -> Wait; cancel the modal; move heavy work to `blender -b`
> - Code "failed" but the scene changed: Non-dict result reported as error after running -> Re-inspect; return dicts
> - Official server, Blender 5.1+, add-on enabled, server started.
> - Working on a copy of the .blend, or the file is under version control.
> - The agent inspects before editing and returns dicts.
>
> Cost: TL;DR ~190 tok · whole note ~3.9k tok. Read more: ## 2. Architecture and why it matters · ## 3. The tools (official server) · ## 7. Failure modes · ## 8. Checklist
<!-- tldr:end -->

A Blender MCP server lets an AI agent inspect and change a running Blender: list collections and objects, read mesh and material details, run `bpy` Python, take screenshots of the window, render thumbnails and viewport images, and search the Blender API and manual. Combined with the [[Roblox Studio MCP Server]] in the same host, one agent can model a prop, render its icon, export it, and wire it into the game, with a human only doing the steps the tools cannot (importing a file into Studio, approving uploads).

This note covers the official Blender Lab server, the older community server, the tools, how to use them well for Roblox assets, and the rules the reference project used. Facts are **as of October 2026**.

Source labels: **Blender Lab** (blender.org/lab/mcp-server and its repository on projects.blender.org), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Two different "Blender MCP" projects

Search results mix two unrelated projects with the same name.

| | Official (Blender Lab) | Community (`ahujasid/blender-mcp` on GitHub) |
|---|---|---|
| Publisher | Blender Lab (Blender Foundation's experimental projects) | An independent developer; popular in 2025 |
| Requirements | Blender **5.1 or newer**, the MCP add-on (v1.0.3 on the page), an MCP client, the MCP server | Older Blender versions; Python `uv` to run the server |
| Architecture | MCP client <-> stdio <-> `blender-mcp` server process <-> **TCP socket** <-> Blender add-on | Same shape: stdio server plus a socket add-on |
| Typical tools | Object and collection summaries, object detail, blend-file summaries, window and area screenshots, viewport and thumbnail renders, jump-to navigation, API and manual search, `execute_blender_code` | Scene info, object info, viewport screenshot, `execute_blender_code`, plus optional asset integrations (check its README) |
| Docs bundled | Blender Python API reference and user manual as plain-text RST files shipped with the server | No |

This note describes the official one in detail because it is the one the reference project's tool list matches. If you use the community server, the workflow advice still applies; the tool names differ.

---

## 2. Architecture and why it matters

```
 MCP host (Claude Code, Claude Desktop, Cursor ...)
     |  stdio (JSON-RPC, one message per line)
 blender-mcp server process (launched by the client)
     |  TCP socket on loopback (host and port set in the add-on preferences)
 Blender add-on (runs inside Blender, executes requests on Blender's side)
```

Consequences you will notice:

- **Blender must be running with the add-on server started** before tools work. If the agent reports "cannot connect", the add-on's server is stopped or on a different port. The add-on has start and stop operators and an optional auto-start in its preferences (Blender Lab).
- The add-on **polls** for requests at configurable active and idle intervals, and evicts stalled clients after a timeout (Blender Lab). A Blender that is busy (a long render, a modal operator, a blocking dialog) cannot answer.
- **Deferred responses only work in the interactive add-on server.** In background mode, requests must complete synchronously (Blender Lab). In practice: renders and heavy operations behave differently when Blender runs headless.
- The server sends **instructions to the model at connection time** (a `prompts.yml` in the server). These include rules worth knowing: prefer specific tools over `execute_blender_code`, inspect the scene before changing it, do not assume missing values, do not destructively modify objects without confirmation, return structured data (dicts) from executed code rather than print output.

### Installing (official)

From the Blender Lab page: install the add-on by dragging the zip into Blender (twice: the first drop adds the Blender Lab extension repository for update notifications, the second installs the add-on) or with Install from Disk in the extension preferences. Install the MCP server: clients that support MCP Bundles (`.mcpb` files) can use the bundle from the releases page; otherwise follow the setup guide on the project wiki. Then add the server to your client (see [[Setting Up MCP Clients]]).

The safety note on the page is blunt: the server **executes model-generated code in Blender without guards** against data deletion or sending data to remote locations, and recommends a virtual machine or a system without access to sensitive information (Blender Lab). Read that as "Python in Blender can do anything your user account can do": delete files, read your home folder, open network connections.

---

## 3. The tools (official server)

Grouped by purpose. Names are as they appeared in the reference project's tool list; descriptions are general. Several tools have `_for_cli` variants in that build, which appear to target a command-line (background) Blender rather than the interactive one; that pairing is **unverified** against Blender Lab docs.

### 3.1 Understanding a scene

| Tool | Use |
|---|---|
| `get_objects_summary` | The collection hierarchy and the objects in it. Always the first call on an unfamiliar file |
| `get_object_detail_summary` | One object in depth: type, transforms, modifiers, materials, mesh stats |
| `get_blendfile_summary_datablocks` | What datablocks exist (meshes, materials, images, actions). Finds orphans and duplicates |
| `get_blendfile_summary_missing_files` | Missing textures and linked files. Run before exporting |
| `get_blendfile_summary_of_linked_libraries` | Linked libraries and what comes from them |
| `get_blendfile_summary_path_info` | File paths, relative vs absolute |
| `get_blendfile_summary_usage_guess` | A guess at what the file is for (useful on a downloaded or inherited file) |

### 3.2 Seeing

| Tool | Use |
|---|---|
| `get_screenshot_of_window_as_image` | The whole Blender window as an image |
| `get_screenshot_of_area_as_image` | One editor area (the 3D viewport, the shader editor) |
| `get_screenshot_of_window_as_json` | The window layout as structured data rather than pixels |
| `render_viewport_to_path` | Renders the viewport to an image file on disk |
| `render_thumbnail_to_path` | Renders a thumbnail to a file. The basis of icon pipelines |

### 3.3 Navigating the UI

| Tool | Use |
|---|---|
| `jump_to_tab_by_name`, `jump_to_tab_by_space_type` | Switch workspace tabs or editor types so the human sees what the agent is talking about |
| `jump_to_view3d_object_by_name`, `jump_to_view3d_object_data_by_name` | Frame an object in the viewport, or open its data properties |

### 3.4 Documentation

| Tool | Use |
|---|---|
| `search_api_docs`, `get_python_api_docs` | Search and read the bundled Blender Python API reference. Use before writing `bpy` code for an operator you are unsure of |
| `search_manual_docs` | Search the bundled user manual for concepts and workflows |

### 3.5 Doing

| Tool | Use |
|---|---|
| `execute_blender_code` | Runs Python with `bpy` in the connected Blender. The escape hatch: modelling, modifiers, materials, export. The server's own instructions call it a last resort |

One measured detail worth knowing: the code's result should be a **dict**. A Blender Lab skill note says other result types are reported as an error even though the code already ran, so a "failed" call may have changed the scene. Always re-inspect after an error.

---

## 4. Writing good `execute_blender_code` calls

Blender's Python API has traps that models fall into constantly. The server's own instructions list several; these are the ones that matter most for Roblox assets.

- **Mode.** Many operators only work in Object or Edit mode. Set the mode explicitly. A wrong mode either errors or silently does nothing.
- **Active vs selected.** Operators often need both an active object and a selection, and change them as a side effect. Set both before every operator call on a different object.
- **bmesh in Edit mode.** In Edit mode, read and write geometry through `bmesh` and flush back with `bmesh.update_edit_mesh`; changes made to `mesh.vertices` in Edit mode are lost.
- **Shared data.** Two objects can share one mesh. Editing it changes both. Check `mesh.users` and make single-user first.
- **Depsgraph.** Update the dependency graph before reading evaluated values (world matrices, modifier results).
- **Units.** Blender defaults to metres; Roblox uses studs. Decide a convention (the reference project modelled in Blender units and scaled on import) and check `scene.unit_settings` before building dimensioned parts.

A small, safe pattern: inspect, act on named objects only, return a dict that proves the result.

```python
import bpy

def tri_count(obj):
    # Evaluated mesh = after modifiers, which is what gets exported.
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    ev.to_mesh_clear()
    return tris

result = {}
for name in ("Blade", "Guard", "Grip"):
    obj = bpy.data.objects.get(name)
    if obj is None:
        result[name] = "missing"
        continue
    result[name] = {
        "tris": tri_count(obj),
        "dims": [round(v, 3) for v in obj.dimensions],
        "materials": [s.material.name if s.material else None for s in obj.material_slots],
    }
result  # the last expression or an assigned dict is what the agent reads back
```

How the result is returned depends on the server version (some read a variable, some the last expression); check the tool description.

---

## 5. Blender to Roblox: what the agent must know

These are engine and importer facts the agent will not guess, all measured in the reference project and consistent with [[Exporting and Validating Models for Roblox]]:

| Fact | Consequence |
|---|---|
| Studio's 3D importer turns a GLB 180 degrees about Y | A model facing Blender's -Y arrives with its front along Roblox `LookVector`. Pass the yaw fix explicitly in your installer rather than relying on a default |
| Axis mapping Blender (x, y, z) to Roblox (-x, z, y) | Any coordinate the agent computes in Blender must be converted before it is used in Luau |
| Animated imports can come in turned 180 degrees | The reference project ran every imported enemy clip through an axis-fix step ([[Enemy Import Axis Fix]]) |
| The MCP cannot import local files into Studio | The human imports the GLB (File > Import 3D, with the options your pipeline expects); the agent continues from there |
| CollisionFidelity cannot be changed on a loaded MeshPart | Decide collision before import, or recreate with `AssetService:CreateMeshPartAsync` |
| Native tools (Blender, Python) failed on Windows paths over 260 characters | Use short (8.3) paths or a short working folder for anything Blender opens |

### Uploading meshes

The reference project uploaded meshes with a Blender "Upload to Roblox" add-on inside the **interactive** Blender, driven by a script that wrote the returned asset ids to a JSON file per batch. Rules that came out of it:

- **Never open a different .blend in the window that holds the upload add-on's login.** Doing so logged the add-on out. Other Blender work ran in separate background instances (`blender -b`).
- **Never print the add-on's tokens** in tool output. Tool output lands in the model context and in logs.
- Insert only your own uploaded ids. Never let an agent invent an asset id; use `rbxassetid://0000000000` placeholders until the real id exists.

For bulk uploads outside Blender, see [[Asset Upload Automation with Open Cloud]].

---

## 6. Workflows that worked

### 6.1 Inspect, then build in small steps
1. `get_objects_summary` to learn the scene's structure and naming.
2. Build or edit with short `execute_blender_code` calls, each returning a dict.
3. Check with `get_object_detail_summary` (tri counts, materials, transforms).
4. Look with `get_screenshot_of_area_as_image` or a viewport render only when shape and silhouette matter.

### 6.2 Batch work headless
Long jobs (rendering 140 icons, rebuilding a library of trees, decimating LODs) ran as `blender -b file.blend --python script.py` processes, not through the interactive MCP connection. The MCP connection was used to design and test the script on one asset; the batch ran headless. This keeps the interactive Blender responsive and avoids timeouts. See [[Blender Automation with Python]].

### 6.3 Icons
The reference project rendered weapon icons in Blender with a fixed framing standard (the weapon fills about 82 percent of the frame on a 45 degree diagonal, centred), separate beauty and emission passes, then post-processing for outline and glow, then upload through Studio's `upload_image` from a localhost URL. Parts the game hides (fully transparent parts, orbiting extras) were hidden in the render too, driven by a list exported from Studio. See [[Icon and Thumbnail Rendering Pipeline]].

### 6.4 One style, enforced in code
A single art style was written down (flat colours, chunky stylised shapes, modelled leaf geometry instead of alpha cards, SmoothPlastic, no textures on props) and every generated asset was checked against it. An agent with a style guide and tri-count checks produces consistent assets; an agent asked to "make it look good" does not. See [[Environment Art Styles]] and [[Low-Poly and Stylized Modeling]].

---

## 7. Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Every tool fails to connect | Add-on server not started, wrong port, Blender closed | Start the server in add-on preferences; restart the client |
| Call times out | Blender busy (render, modal operator, dialog) | Wait; cancel the modal; move heavy work to `blender -b` |
| Code "failed" but the scene changed | Non-dict result reported as error after running | Re-inspect; return dicts |
| Operator did nothing | Wrong mode, wrong active object or empty selection | Set mode, active and selection explicitly |
| Edits vanished | Edited mesh data in Edit mode without bmesh flush | Use bmesh and `update_edit_mesh` |
| Screenshot shows the wrong thing | Wrong area or tab | Jump to the tab and object first |
| Model arrives in Studio backwards | Importer yaw | Apply the explicit yaw fix |

## 8. Checklist

- [ ] Official server, Blender 5.1+, add-on enabled, server started.
- [ ] Working on a copy of the .blend, or the file is under version control.
- [ ] The agent inspects before editing and returns dicts.
- [ ] Heavy batches run headless.
- [ ] Upload credentials never printed; uploads only from the dedicated interactive instance.
- [ ] Exported asset checked for tri count, materials, missing files and scale before import.

## See also

- [[What Is MCP]], [[Setting Up MCP Clients]], [[Roblox Studio MCP Server]]
- [[Blender Workflow for Roblox Creators]], [[Modeling in Blender for Roblox]], [[Exporting and Validating Models for Roblox]]
- [[Blender Automation with Python]], [[Icon and Thumbnail Rendering Pipeline]], [[Art Pipeline - Concept to In-Game Asset]]
- [[AI 3D Model Generation Outside Roblox]], [[MCP Workflows for Building Worlds]]

## Connected notes
<!-- auto-links:start -->
[[Blender 5 Python Gotchas for Headless Builds]] · [[Links - Blender fundamentals for Roblox]] · [[Writing Your Own MCP Server]] · [[Case Study - Building a Game with AI Agents]] · [[AI Agents and Autonomous Workflows]] · [[Asset Pipelines]]
<!-- auto-links:end -->
