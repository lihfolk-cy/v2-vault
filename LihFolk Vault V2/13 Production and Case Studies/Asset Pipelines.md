---
tags: [production, pipeline, blender, import, icons, audio, tooling, case-study, type/case-study, area/production, level/intermediate, api/TextureID]
---
# Asset Pipelines

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hand-fixing imports. The next import needs the same fix; put it in the installer.
> - Avoid: No id map. Ids get lost, invented or confused with someone else's.
> - Avoid: Installing straight into the world. Install to a library, place from the library.
> - Each asset family has a source script, an exporter, an installer, a placer and a verifier.
> - Axis and scale conventions are written down and applied in code.
> - Every upload writes an id map to disk.
>
> Cost: TL;DR ~160 tok · whole note ~5.0k tok. Read more: ## Blender to Roblox: the conventions that bite · ## Install scripts: dry run, idempotent, reversible · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An asset pipeline is the repeatable path from a source file (a Blender scene, a sound take, a design spec) to a finished, wired, budget-checked thing in the game. Without one, every model is a hand job: import, fix the axis, fix the scale, guess the collision, place it, forget to record what you did. With one, adding the 150th weapon costs about the same as adding the 15th, and anybody on the team can do it.

This note describes pipeline design in general and shows the pipelines one production game (the reference project) ended up with: Blender to GLB to install scripts for maps, enemies, armour and weapons; a rendered icon pipeline; and a measured audio pipeline. The animation side of the same pipelines is covered in depth in [[Pipeline - New Animated Weapon]], [[Pipeline - Importing Animated Enemies]] and [[Animation Data from Blender to Roblox]].

## The shape of a good pipeline

Every pipeline in the reference project that survived had the same five stages:

| Stage | Where it runs | Output | Key property |
|---|---|---|---|
| 1. Source | A script or file you own (Blender Python, a spec file) | A `.blend` / design data | Regenerable: the source is code or data, not hand edits |
| 2. Export / upload | Offline tool | GLB or uploaded package / mesh / image ids | Deterministic names, an id map written to disk |
| 3. Install | A Studio script (command bar or plugin) | Instances in a library folder | Idempotent; dry run first; records undo data |
| 4. Place / wire | A Studio script | Instances in the world, config rows, registry entries | Reads the library, never the raw import |
| 5. Verify | A Studio script | A report | Numbers, not screenshots: counts, fit errors, budgets |

The properties in the last column are what make a pipeline cheap to rerun. If stage 1 is hand edits in Blender, you cannot regenerate when the art direction changes. If stage 3 is not idempotent, running it twice duplicates content. If stage 5 is "look at it", nobody notices that 3 of 49 enemies float.

## Blender to Roblox: the conventions that bite

These were measured in the reference project and cost real time before they were written down. Check them in your own setup; importer behaviour changes between Studio versions.

| Fact | Consequence | Fix |
|---|---|---|
| The Studio 3D importer turns a GLB 180 degrees about Y (measured) | A model whose front is Blender -Y ends up facing Roblox `LookVector` | Decide one front axis for all sources; pass the yaw fix explicitly in the installer instead of relying on defaults |
| Blender (x, y, z) maps to Roblox (-x, z, y) for that setup (measured) | Hand-copied coordinates land mirrored | Convert in the exporter, never by hand |
| Imported enemy clips played turned 180 degrees | Enemies walked backwards | A clip axis fix step in the installer. See [[Enemy Import Axis Fix]] |
| Individual meshes cannot exceed 20,000 triangles (Roblox docs) | Big creatures and landmarks must be split | Split by material or part in the exporter; the reference project's enemies ran 10,000 to 42,000 triangles across several meshes |
| `CollisionFidelity` cannot be changed on an already loaded MeshPart (measured) | Collision chosen at import is stuck | Create the part with `AssetService:CreateMeshPartAsync` and the fidelity option, or keep simple invisible collider parts |
| Blender cannot open paths longer than 260 characters on Windows (measured) | Deep temp folders break batch renders | Keep build folders short |
| Opening another `.blend` in the interactive Blender that holds the upload add-on's session logged it out (measured) | Uploads failed silently | Use background Blender (`blender -b`) for builds; keep the interactive one for uploads only |
| Near-black colours (below about 0.06 luminance) hide material textures (measured) | Dark props look flat plastic | Keep painted darks above that floor |
| A MeshPart with a palette `TextureID` ignores Material changes until the TextureID is cleared (measured) | Material passes appear to do nothing | Clear TextureID first, store the old id as an attribute for revert |

See [[Modeling in Blender for Roblox]], [[Importing Models and Rigs]] and [[3D Importer Settings Reference]].

## Source as code

The reference project built nearly every asset family from Python scripts run in background Blender: enemies (one design script per creature plus a shared helper library), armour sets, weapons, map kits, VFX meshes. A shared style module held the palette, the stud texture atlas and seam-line rules, so a style change was a library change.

Why code over hand modelling, for a team that iterates fast:

- **Variants are cheap.** Armour went from 6 hard-surface sets to a toon restyle to 18 sets (3 per zone pair plus event and boss sets, 422 MeshParts) in a few days because each set was parameters on a shared builder (measured).
- **Recolours are cheap.** "This armour should be black and purple" changed one palette; the meshes and UV maps were untouched, only the atlas and icons were re-rendered.
- **Regeneration is safe.** When a mesh came out with zero triangles (a band that was never built), the fix was in the source, and a rebuild produced every dependent file again.

The cost: code-built assets can look procedural. A procedurally generated hub kit was rejected as "low-detail, pixelated" next to a hand-painted one (measured). The pipeline is not the style; you still need a style gate. See [[Planning and Scoping a Roblox Game]].

### One style for everything

The reference project's owner set a single rule: one style for all assets (flat colours, modelled leaf geometry, chunky stylised shapes, SmoothPlastic, no alpha cards on props, no flags or banners anywhere). Later a voxel-and-stud style was adopted for enemies while maps stayed hand-modelled. A written style bible per family (palette, proportions, seam lines, triangle budget) is part of the pipeline: the design scripts read it, and reviewers check against it. See [[Environment Art Styles]].

## Upload and the id map

Every upload must write an id map to disk: source name to asset id, per batch, with the date. The reference project kept one JSON file per upload tag (a weapon batch, a hub kit, an armour pack). Without the map:

- you cannot reinstall after a revert;
- you cannot tell which ids are yours when cleaning up;
- you are tempted to type ids from memory, which is how invented ids reach the game.

Two hard rules from the project: **never invent asset ids** (use only ids you uploaded or that already exist in the game), and **insert only your own uploaded ids**, never store or third-party meshes. Generated meshes from in-Studio AI tools were banned for the same reason as store assets: the style and quality are not under your control. See [[Creator Store and Toolbox Safety]] and [[Packages and Asset Reuse]].

Uploaded content was often grouped as a package so that one id brought in a whole kit (149 hub meshes, 156 armour meshes). The Studio-side installer then loaded the package into a library folder in ServerStorage and placed copies from there.

## Install scripts: dry run, idempotent, reversible

An install script turns library meshes into game content. The reference project's swap tools all had the same interface: `Run`, `DryRun`, `Undo`, `Status`, `Verify`. A minimal version of a mesh swap with those properties:

```lua
--!strict
-- Swap blockout parts for library meshes, keeping each part's CFrame and size.
-- Records exact undo data on the new part; safe to run twice.
local ServerStorage = game:GetService("ServerStorage")

local Swap = {}

local function libraryMesh(name: string): MeshPart?
	local lib = ServerStorage:FindFirstChild("MeshLibrary")
	local m = lib and lib:FindFirstChild(name)
	return if m and m:IsA("MeshPart") then m else nil
end

function Swap.Run(root: Instance, dryRun: boolean): { swapped: number, missing: { string } }
	local result = { swapped = 0, missing = {} }
	for _, part in root:GetDescendants() do
		if not part:IsA("BasePart") then continue end
		local meshName = part:GetAttribute("SwapMesh")
		if typeof(meshName) ~= "string" then continue end
		if part:GetAttribute("Swapped") then continue end -- idempotent: already done

		local template = libraryMesh(meshName)
		if not template then
			table.insert(result.missing, meshName)
			continue
		end
		result.swapped += 1
		if dryRun then continue end

		local mesh = template:Clone()
		mesh.Name = part.Name
		mesh.CFrame = part.CFrame
		mesh.Size = part.Size
		mesh.Anchored = true
		mesh.CanTouch = false
		mesh:SetAttribute("SwapMesh", nil) -- the clone must not look like a blockout
		mesh:SetAttribute("SwapClone", true)
		mesh.Parent = part.Parent

		-- keep the blockout as an invisible collider so collision is unchanged
		part:SetAttribute("PreSwap_Transparency", part.Transparency)
		part.Transparency = 1
		part.CastShadow = false
		part:SetAttribute("Swapped", true)
	end
	return result
end

function Swap.Undo(root: Instance)
	for _, inst in root:GetDescendants() do
		if inst:GetAttribute("SwapClone") then
			inst:Destroy() -- remove every placed mesh
		elseif inst:IsA("BasePart") and inst:GetAttribute("Swapped") then
			local t = inst:GetAttribute("PreSwap_Transparency") -- restore every blockout
			if typeof(t) == "number" then inst.Transparency = t end
			inst.CastShadow = true -- assumes blockouts cast shadows; store it too if not
			inst:SetAttribute("PreSwap_Transparency", nil)
			inst:SetAttribute("Swapped", nil)
		end
	end
end

return Swap
```

Design notes:

- **Blockouts stay as colliders.** The reference project kept blockout parts as invisible collision for several swaps, so walkable space, enemy walk areas and raycasts were unchanged by an art swap. A 1,620-ray grid before and after confirmed identical collision on one hub art pass (measured).
- **Attributes carry undo.** The `Pre<Tag>_<Property>` convention appears throughout the project; see [[Safe Changes in a Shared Place]].
- **Dry run first, always.** A dry run on landmarks reported missing meshes and placement problems before anything changed.
- **Name the undo in the notes.** "Undo = `Swap.Undo(root)`" in the changelog line saves the next person from reading the code.

## Placing on the ground

Generated props float or sink unless the placer grounds them. Rules learned in the reference project:

- Ground props with a **terrain-only** raycast when they belong on terrain; a raycast that hits other props stacks them.
- Terrain renders its surface about 2 studs above what the voxel occupancy formula suggests in some cases, and the formula surface sat 0.8 to 1.6 studs below the rendered one in another (measured). Re-ground by raycast, not by formula.
- Invisible slabs used as enemy floors block ground raycasts; set `RespectCanCollide = true` in `RaycastParams` or filter them.
- A later pass found 276 floating props and snapped them down, storing the amount lowered as an attribute (measured). Run a "float scan" as part of Verify.

See [[Raycasts Shapecasts and Spatial Queries]] and [[Foliage Props and Scatter]].

## Weapons: a pipeline with numbers

The weapon pipeline is the clearest example of a mature pipeline in the reference project. The owner dropped a setup file and a GLB; the pipeline produced a registered weapon with rig, effects, icon, voice, sheath, config row, lore and a full attack kit.

| Step | What | Time (measured) |
|---|---|---|
| 0 | GLB import (manual: the automation could not import local files) | 1 min |
| 1 | Parse setup, generate rig / FX / item / lore / voice / sheath data offline | 0.1 s |
| 2 | Build rig and FX in Studio | about 1 min |
| 3 | Render and upload the icon | about 3 min |
| 4 | Config row, voice, sheath | about 1 min |
| 5 | Design the move kit (the creative part) | 30 to 45 min |
| 6 | Build the kit and its move icons | 2 s |
| 7 | Bake and install the kit | about 5 min |
| 8 | Register everywhere it must appear | about 1 min |
| 9 | Dev test and arm bake with QA | 15 to 25 min |
| 10 | Verify, captures, cleanup | about 2 min |
| 11 | Notes | about 5 min |

Total about 1 to 1.5 hours, and the creative step dominates. That is the goal of a pipeline: machines do everything that is not a decision. The full animation side is in [[Pipeline - New Animated Weapon]] and [[Pipeline - Arm IK Baking and QA]].

Note the "manual leftovers" list the pipeline kept: the GLB import, publishing animation ids, and the play-test. Writing the manual steps down is as important as automating the rest; an unlisted manual step is a step that gets skipped. Publishing in particular was skipped for weeks, leaving hundreds of clips Studio-only ([[Case Study - Abilities That Only Worked in Studio]]).

## Enemies: keep the skeleton, swap the look

The reference project rebuilt its whole enemy roster look in one day: 49 new creature models, each installed onto an existing slot that kept its id, skeleton (bones and pivots), clips, AI role, zone and attacks (measured). That was possible because the pipeline separated **identity** (slot id, data, clips) from **appearance** (mesh). The installer rebuilt the rig from a manifest, re-measured root and ground heights, and stamped each model with the redesign date. Fit error was 0.000 on every rig (measured). See [[Case Study - Enemy Roster Rebuild]].

## Icons: a rendered pipeline

Inventory icons were rendered in Blender from the same source models the game used, not drawn by hand:

1. **Render** a beauty pass plus an emission pass (so glowing parts can be treated separately).
2. **Post-process**: outline, bloom on emission only, a hint of sparkle, transparent background.
3. **Frame by rule**: about 82% fill, a 45-degree diagonal for blades, centred.
4. **Hide what is not the item**: orbiting extras, floating rings, halos, loose chains and particles are hidden; mechanical parts touching the item chain stay. The rule was codified as a hide list per item, regenerated from the live rigs.
5. **Keep glow hue**: an early version blew glows out to white; the tone step was fixed so glow keeps its colour.
6. **Upload** and record the image id in the item's config row.

Parts the game keeps invisible must also be hidden in the render, or the icon shows things the player never sees. The project read each model's transparency from the live game and fed it to the renderer. A framing helper in Blender Python:

```python
import bpy
from mathutils import Vector

def frame_ortho(cam_obj, objs, fill=0.82):
    """Centre an orthographic camera on objs and size it so they fill `fill` of the frame.
    Assumes a square render; the camera's rotation is kept."""
    inv = cam_obj.matrix_world.inverted()
    pts = [inv @ (o.matrix_world @ Vector(c)) for o in objs for c in o.bound_box]
    min_x = min(p.x for p in pts); max_x = max(p.x for p in pts)
    min_y = min(p.y for p in pts); max_y = max(p.y for p in pts)
    cx, cy = (min_x + max_x) / 2, (min_y + max_y) / 2
    # move the camera in its own XY plane so the bounds are centred
    cam_obj.location = cam_obj.matrix_world @ Vector((cx, cy, 0.0))
    cam_obj.data.type = 'ORTHO'
    cam_obj.data.ortho_scale = max(max_x - min_x, max_y - min_y) / fill
```

Bounding boxes overestimate diagonal shapes slightly; for exact framing, project mesh vertices instead of `bound_box` corners. Re-render all icons whenever the source model changes (the reference project reinstalled 93 icons after the glow fix, measured).

## Audio: measure, level, ban

Sound needs a pipeline too, even when you only use library sounds:

- **A loudness table.** Every sound id the game plays has a measured loudness entry; the player scales volume from it. New ids added without measuring play unlevelled next to measured ones. In the reference project 479 new energy-blade sound ids sat unmeasured because measuring required one waveform query per id, too slow to do in a single pass; it had to be chunked (measured).
- **A forbidden list.** Sounds the owner rejected (an 18-take sword foley bank) and one id removed by Roblox moderation are listed so no script reintroduces them. A removed id fails to load silently; list it and grep for it.
- **Onset trimming.** Library takes often start with silence; the enemy sound bank started each of 195 takes at its measured onset so hits land on the frame.
- **Buses.** Weapon sounds, enemy sounds and UI sounds each go through their own `SoundGroup` so settings sliders work per category.

See [[Sound Fundamentals]] and [[Sound Design for Games]].

## Where pipelines broke

| Break | Cause | Prevention |
|---|---|---|
| Three weapons had zero-triangle meshes | A band never built in the source; uploaded anyway | Verify triangle count > 0 per mesh before upload |
| Re-uploaded meshes came back as `name.001` | Duplicate names in the Blender scene | Unique names enforced in the exporter; a name map back |
| A weapon's grip moved down a chain | The server's head-scan counted orbiting parts the client already skipped | One shared module for "which parts are the item", used by client and server |
| Generated material jobs failed almost every time (measured) | Tool reliability | Do not put unreliable generators in the critical path |
| Freshly uploaded images failed to preload for 20 to 60 seconds (measured) | Asset processing delay | Retry with backoff in verify; do not conclude "broken" immediately |

## Common mistakes

- **Hand-fixing imports.** The next import needs the same fix; put it in the installer.
- **No id map.** Ids get lost, invented or confused with someone else's.
- **Installing straight into the world.** Install to a library, place from the library.
- **No dry run.** The first real run is the test.
- **Collision from render meshes.** Keep simple colliders; render meshes are for looks.
- **Icons drawn by hand.** They drift from the models; render them.
- **Unlevelled sounds.** Measure everything that plays.

## Checklist

- [ ] Each asset family has a source script, an exporter, an installer, a placer and a verifier.
- [ ] Axis and scale conventions are written down and applied in code.
- [ ] Every upload writes an id map to disk.
- [ ] Installers support dry run, are idempotent and record undo data.
- [ ] Verify reports numbers: counts, fit errors, triangles, floaters, budgets.
- [ ] Manual steps are listed per pipeline.
- [ ] Icons render from the game models with a framing rule and a hide list.
- [ ] Every sound id is in the loudness table; forbidden ids are listed and grepped.

## See also

- [[Modeling in Blender for Roblox]], [[Packages and Asset Reuse]], [[Art Budgets - Triangles Draw Calls Memory]]
- [[Pipeline - New Animated Weapon]], [[Pipeline - Importing Animated Enemies]], [[Studio Tooling Architecture]]
- [[Weapon Design Rig Builder]], [[Ground Fitting Pipeline]]
- [[Safe Changes in a Shared Place]], [[Documentation and Knowledge Bases]]
- [[Case Study - Enemy Roster Rebuild]], [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Art Pipeline - Concept to In-Game Asset]] · Case Study - Building a Game with AI Agents · Character and Creature Pipeline · Pipeline Design Principles · Icon and Thumbnail Rendering Pipeline · Audio Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Building a Game with AI Agents]] · [[Pipeline Design Principles]] · [[Post-Mortem - Building a Melee Action Game]] · [[Team Roles and Workflows]] · [[Working with AI Assistants in Studio]] · [[Case Study - Instance Cleanup and Place Size]] · [[Case Study - Building LihFolk V2 with AI Agents]] · [[Release Process and Rollbacks]] · [[Case Study - Fast Join and Deferred Loading]]
<!-- related:end -->
