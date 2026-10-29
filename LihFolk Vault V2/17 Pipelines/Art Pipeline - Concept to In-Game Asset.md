---
tags: [pipelines, art, blender, meshes, assets, import, type/guide, area/pipelines, level/intermediate, api/TextureID, area/modeling, api/SurfaceAppearance]
---
# Art Pipeline - Concept to In-Game Asset

<!-- tldr:start -->
> [!tldr] TL;DR
> - Asset imports 100x too big or rotated 90 degrees: unit or axis mismatch -> test cube, fix exporter settings once, encode in script
> - Upload fails or mesh is split: over 20,000 tris in one mesh -> split by material or decimate (Retopology and Decimation)
> - Part invisible in game: 0-tri mesh, flipped normals, or fully transparent material -> validation gate in stage 4
> - Brief with budget, size in studs and style rules
> - Blockout measured in place, numbers written down
> - Built by a script from a shared helper library
>
> Cost: TL;DR ~170 tok · whole note ~4.6k tok. Read more: ## Stage 3: build from a script, not by hand · ## Stage 7: install with an idempotent script · ## Failure modes · ## Checklist
<!-- tldr:end -->

This is the end-to-end recipe for a static 3D asset (a prop, a weapon mesh, a station, a hero piece of scenery) from the first idea to a MeshPart in a published place that you can rebuild, re-texture or roll back. It assumes Blender, because that is what most Roblox creators use, but every stage maps to Maya or other tools. The principles behind it are in [[Pipeline Design Principles]]; the overview of production asset pipelines is [[Asset Pipelines]]; modelling technique is in [[Blender Workflow for Roblox Creators]] and [[Modeling Weapons and Props]]. Animated assets branch off at stage 6: see [[Character and Creature Pipeline]] and the Animation section's [[Pipeline - New Animated Weapon]].

## The stages at a glance

| # | Stage | Input | Output | Tool | Gate |
|---|---|---|---|---|---|
| 1 | Brief and reference | idea, style guide | one-page brief + refs | text, images | silhouette and budget agreed |
| 2 | Blockout | brief | rough Parts in Studio or primitives in Blender | Studio / Blender | scale and gameplay read in place |
| 3 | Source build | blockout | `.blend` from a build script | Blender + Python | builds from scratch with one command |
| 4 | Budget and validation | `.blend` | report | Blender script | tris, materials, names, scale |
| 5 | Export | `.blend` | `.glb` or `.fbx` | Blender exporter | file opens, axis and scale right |
| 6 | Upload / import | export | MeshPart(s) and asset ids | 3D Importer, Blender add-on or Open Cloud | id map written |
| 7 | Install | id map | placed, configured instances | idempotent Luau installer | probe passes |
| 8 | Look pass | installed asset | materials, lighting fit | Studio | screenshot review |
| 9 | Record | everything | changelog, notes, id map committed | text | done |

The rest of the note walks the stages with the decisions and failure modes for each.

## Stage 1: brief and reference

A brief is short. It answers: what is it, where does it sit, how big is it in studs, how close will the camera get, how many will be on screen, what style rules apply, and what is the triangle and material budget.

The reference project kept three written style guides for its voxel models (pastel pets, saturated outlined enemies with raised studs, dark bodies with neon lines for premium pieces), each with sampled palettes, proportions and a QA checklist. A brief then said "enemy, outlined voxel style, one neon colour, under 8k triangles" and everything else followed. See [[Environment Art Styles]] and [[Voxel and Blocky Modeling]].

Budgets to start from (rule of thumb, adjust with [[Art Budgets - Triangles Draw Calls Memory]]):

| Asset | Triangles | Meshes | Notes |
|---|---|---|---|
| Small prop seen in crowds | 50-500 | 1 | merge per material |
| Hero prop (fountain, altar) | 5k-10k | 5-10 | measured: hub hero pieces were 7.2k-9.2k tris in 7-9 meshes |
| Held weapon | 5k-30k | 10-35 | measured: custom swords 26.8k-29.5k tris in about 32 parts |
| Shop kiosk with NPC | up to ~45k | ~20 | measured: one kiosk was 43.5k tris in 20 meshes |
| Any single mesh | under 20,000 | | Roblox docs: "Individual meshes can not exceed 20,000 triangles" |

AI concept images are fine for stage 1 (see [[AI Image Generation for Icons Thumbnails and Concepts]]); the reference project's owner banned AI-generated meshes in the game itself, and built everything in Blender instead, so the topology and style stayed consistent.

## Stage 2: blockout in place

Before modelling, block the asset out at real size in the real place. A fountain that looks right in Blender can block a spawn, cover a prompt or sit two studs inside a cliff. The reference project measured everything in place before building: the plaza circle centre and radius were measured from the paving rings, the fountain was placed so its nearest surface was 10 studs from the SpawnLocation, the chest was set 5 studs behind the jump-pad landing.

Record the blockout as numbers, not as "looks about right":

```text
asset: hub_fountain
anchor: plaza centre, measured (0, floor, -11785) in place units
footprint: radius 19 studs, rim top +3.0
keep clear: spawn at >= 10 studs, prompt radius 14
collision: rim walls 3.0 tall (blocking), basin floor +1.7 (wading)
```

Those numbers go straight into the build script (stage 3) and the installer (stage 7).

## Stage 3: build from a script, not by hand

The single biggest improvement the reference project made to its art pipeline was building every mesh from a Python script (`build_<thing>.py`) run in background Blender, instead of hand-editing `.blend` files. A script:

- rebuilds the whole asset in seconds when the style changes (one project changed a whole armour set's palette from one colour scheme to black and purple by editing a `PALETTE` table and re-running);
- encodes the style rules once, in a shared helper library (`lib.py`, `vlib.py` for voxel pieces);
- names every object correctly every time;
- is diffable in Git.

Hand modelling still happens (sculpts, organic shapes), but the export, naming, material assignment and validation are always scripted. Details and code are in [[Blender Automation with Python]].

The shape of a build script:

```python
# build_fountain.py  (run: blender -b --factory-startup --python build_fountain.py -- out.blend)
import sys, bpy
sys.path.append(".")            # shared helpers live beside the script
import lib                      # project helpers: clear_scene, octagon, bevel_box, mat, join_by_material

argv = sys.argv[sys.argv.index("--") + 1:]
out_blend = argv[0]

lib.clear_scene()
P = lib.palette("marble_gold")  # one palette per style, never inline colours

basin = lib.octagon("Basin", radius=19.0, height=3.0, mat=P.marble)
trim  = lib.ring("BasinTrim", radius=19.2, width=0.4, height=0.3, z=3.0, mat=P.gold)
col   = lib.fluted_column("Column", radius=2.0, height=9.0, flutes=12, mat=P.marble)
# ... bowls, spouts, gem ...

lib.join_by_material(prefix="HeroFountain")  # one mesh per material: fewer draw calls
lib.apply_all_transforms()
lib.report_budget(max_tris_per_mesh=20000)   # stage 4 gate, fails loudly
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
```

`lib.*` here stands for your own helpers; the point is the structure: inputs on the command line, palette from a table, merge by material, gate, save.

## Stage 4: validate before export

Validation in Blender is cheap and catches problems that are expensive after upload (an upload uses quota and creates an asset you cannot delete easily). Check:

| Check | Limit or rule | Why |
|---|---|---|
| Triangles per mesh | under 20,000 (Roblox docs) | import fails or splits the mesh |
| Zero-triangle meshes | none | the reference project shipped three 0-tri meshes ("spine band never built") and had to drop those parts later |
| Object names | `[A-Za-z0-9_]`, unique, no dots | dots and spaces were mangled on upload; names drive install mapping |
| Transforms applied | scale 1, rotation 0 | otherwise pivots and sizes come in wrong |
| Units | 1 Blender unit = 1 stud is the common convention (rule of thumb; see [[Exporting and Validating Models for Roblox]]) | scale surprises are the number one import complaint |
| Materials per mesh | 1 | Roblox gives one material per MeshPart |
| Vertex colours | intended or white | the reference project found walls with 400-900 noisy baked vertex shades that no Color or Material change could fix, because vertex colour multiplies with Color |
| UVs | present if textured | meshes without UVs cannot take a texture or SurfaceAppearance |
| Normals | outward, smooth groups set | flipped faces render invisible from outside |

The full validation list is in [[Exporting and Validating Models for Roblox]].

## Stage 5: export

GLB is the reference project's default for static and hinged assets; FBX remains the safer choice for skinned characters with animation. The trade-offs are in [[Exporting FBX vs GLB]]. Export settings that matter:

- Apply modifiers on export (or apply them in the script before).
- Export selected or a named collection only (`UPLOAD` collection), never the whole scene with helper objects.
- Keep "+Y up" behaviour consistent with what the importer expects, and verify once with a test cube with labelled faces. Axis errors are covered in [[Enemy Import Axis Fix]].

Write a sidecar JSON next to the export with each part's name, bounds and intended material. The installer and the icon renderer both read it, so nobody re-measures.

## Stage 6: get it into Roblox

There are three routes, and the choice decides how automatable the pipeline is.

| Route | How | Automatable | Result | Use when |
|---|---|---|---|---|
| **3D Importer** | File > Import 3D in Studio | no (manual file pick) | Model of MeshParts in Workspace, assets uploaded on publish/save | one-off assets, rigs, anything that needs importer options |
| **Blender add-on upload** | Roblox's Blender add-on uploads meshes from an open Blender session after you sign in | partly (drive it with a queue script) | asset ids per object | many meshes, ids needed before install |
| **Open Cloud Assets API** | `POST /assets/v1/assets` with an API key | fully | asset id per file, after an async operation | CI, batch uploads, no Studio needed ([[Asset Upload Automation with Open Cloud]]) |

The reference project used the importer for weapons with hinges (Merge Meshes OFF so each part stays separate, Rig none, insert into Workspace) and the Blender add-on for everything else. A Python queue script fed the add-on mesh by mesh and wrote `upq_ids_<tag>.json` (part name to asset id) per batch. Two rules came from failures there:

- **Never open another `.blend` in the uploader's Blender window** (it logged the add-on out mid-queue). All other Blender work ran headless with `blender -b`.
- **Never print the add-on's tokens** in logs or chat.

Importer settings are documented in [[3D Importer Settings Reference]] and [[Importing Models and Rigs]].

## Stage 7: install with an idempotent script

The installer turns ids into placed, configured instances. When meshes were uploaded separately (route 2 or 3), Studio needs MeshParts made from those ids. `MeshPart.MeshId` is not writable from scripts, so a plugin or command-bar script builds a MeshPart with `AssetService:CreateMeshPartAsync` and copies its geometry onto the live part with `MeshPart:ApplyMesh`, or simply parents the new MeshPart in place.

```lua
--!strict
-- Edit-mode installer: build MeshParts from an id map and place them under a model.
-- Run from the command bar or a plugin. Idempotent: existing parts are updated, not duplicated.
local AssetService = game:GetService("AssetService")

type Row = { name: string, id: number, cframe: CFrame?, color: Color3?, material: Enum.Material? }

local function install(parent: Instance, rows: { Row }, dryRun: boolean): { string }
	local log = {}
	for _, row in rows do
		local existing = parent:FindFirstChild(row.name)
		if dryRun then
			table.insert(log, (existing and "update " or "create ") .. row.name)
			continue
		end
		local ok, fresh = pcall(function()
			return AssetService:CreateMeshPartAsync(
				Content.fromUri("rbxassetid://" .. tostring(row.id)),
				{ CollisionFidelity = Enum.CollisionFidelity.Box } -- visuals; real collision is separate
			)
		end)
		if not ok then
			table.insert(log, "FAILED " .. row.name .. ": " .. tostring(fresh))
			continue
		end
		local part: MeshPart
		if existing and existing:IsA("MeshPart") then
			existing:ApplyMesh(fresh) -- keeps the live part, its attributes and references
			fresh:Destroy()
			part = existing
		else
			part = fresh
			part.Name = row.name
			part.Parent = parent
		end
		part.Anchored = true
		part.CanTouch = false
		part.CastShadow = part.Size.Magnitude > 4 -- tiny decor casts no shadow
		if row.cframe then part.CFrame = row.cframe end
		if row.color then part.Color = row.color end
		if row.material then part.Material = row.material end
		part:SetAttribute("InstalledBy", "ArtPipeline")
		table.insert(log, "ok " .. row.name)
	end
	return log
end

return install
```

Conventions the reference project applied to every installed decor mesh (measured in one production game): anchored, `CanTouch = false`, tiny parts `CastShadow = false`, `RenderFidelity = Automatic`, and **separate invisible collider parts** for anything players touch (rim walls, tiers, pedestals), with the visual meshes `CanCollide = false`. Collision from a detailed mesh is expensive and bumpy; boxes are cheap and predictable. See [[Collision and Physics Geometry]].

When the asset replaces an older one, the installer **hides** the old parts reversibly (stores `PreHero_*` attributes for Transparency, CFrame, Enabled) instead of deleting them, until the new piece is verified. Then a cleanup step deletes them and exports a JSON backup.

Re-seat dependants. A new fountain moved the splash emitters, the waterfall script's fallback positions and a station's ray beacon; the reference project kept small "align" tools (`HubRays.Align()` re-seats beacon beams from the station's visible parts) and re-ran them after every move.

## Stage 8: look pass

Now judge it in the real lighting, at the real camera distance, on the low graphics setting and on a phone-sized viewport. Things that commonly need fixing here:

- **Near-black colours hide material textures** (below about 0.06 luminance in the reference project). Lift the darkest colour slightly.
- **Palette textures override materials.** MeshParts that carry a TextureID ignored Material changes until the TextureID was cleared (measured in one production game).
- **Glow blowout.** Neon on top of bloom turns everything white; the reference project set a "no glare" rule for VFX meshes (EmissiveStrength 2, no stacked white flares).
- **Studs and textures at the wrong scale.** The voxel style used a SurfaceAppearance stud overlay with UVs at 8 studs per tile; get the tile size wrong and studs look like noise.

Materials and textures are covered in [[Materials MaterialVariants and SurfaceAppearance]] and [[Texturing and PBR Baking]].

## Stage 9: record

Commit the build script, the `.blend` (or at least the script and its inputs), the export sidecar and the id map. Write a changelog line with a tag, the backup location and the test status. If the asset needs an icon, hand it to [[Icon and Thumbnail Rendering Pipeline]] now, while the source is fresh.

## Worked example: a hub hero piece (measured in one production game)

| Step | What happened |
|---|---|
| Brief | "Make a way better central piece for the hub", style: marble tiers, gold trim, floating dice, rune ring |
| Blockout | measured the old altar spot; kept the HUD roll button as the interaction (no new prompt), tutorial untouched |
| Build | `build_roll.py`: 3 octagonal tiers (1-stud steps, radius 25), pedestal, bowl, claws, floating dice, halo, rune ring, 4 swords, 8 crystal posts; 7.3k tris in 9 meshes |
| Upload | Blender add-on via the queue script, ids in a JSON map |
| Install | visuals `CanCollide = false`, a Colliders folder for tiers, pedestal, swords and posts; old meshes and emitters hidden with `PreHero_*` attributes |
| FX | a client script animates dice bob and tumble, halo orbit, rune ring spin, with a sleep distance (520 studs) and low-graphics trims |
| Record | changelog tag, "Edit only, not play-tested" |

Total wall clock was under an hour for the piece; the same scripted approach then built a fountain (9.2k tris), a spinner wheel (7.2k tris) and a treasure chest (8k tris) the same day.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Asset imports 100x too big or rotated 90 degrees | unit or axis mismatch | test cube, fix exporter settings once, encode in script |
| Upload fails or mesh is split | over 20,000 tris in one mesh | split by material or decimate ([[Retopology and Decimation]]) |
| Part invisible in game | 0-tri mesh, flipped normals, or fully transparent material | validation gate in stage 4 |
| Colour change does nothing | vertex colours or TextureID override | white vertex colours; clear TextureID |
| Players snag on the asset | mesh collision | invisible box colliders, visual `CanCollide = false` |
| Duplicate parts after a re-run | installer creates instead of find-or-create | idempotent installer |
| Uploader stops halfway | uploader session logged out or rate limited | queue with resume; one batch file per tag |
| Ids lost | ids copied by hand into chat | ids only via JSON maps |

## Checklist

- [ ] Brief with budget, size in studs and style rules
- [ ] Blockout measured in place, numbers written down
- [ ] Built by a script from a shared helper library
- [ ] Validation gate: tris, names, transforms, UVs, vertex colours
- [ ] Export from an `UPLOAD` collection with a sidecar JSON
- [ ] Upload route chosen; id map written automatically
- [ ] Installer idempotent, dry run first, old parts hidden reversibly
- [ ] Separate invisible colliders; decor anchored, `CanTouch` off
- [ ] Look pass at real distance, low graphics and phone size
- [ ] Recorded: script, id map, changelog tag, test status

## See also

[[Pipeline Design Principles]] · [[Blender Automation with Python]] · [[Asset Upload Automation with Open Cloud]] · [[Exporting and Validating Models for Roblox]] · [[Modular Environment Kits]] · [[Environment and Level Pipeline]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Packages and Asset Reuse]] · [[Creator Store and Toolbox Safety]]

## Connected notes
<!-- auto-links:start -->
[[Modeling in Blender for Roblox]] · Parts Unions and MeshParts · Modeling Fundamentals for Games · Meshing Voxels for Roblox - Greedy Meshing and Export · Low-Poly and Stylized Modeling · Skill - Roblox Asset Import
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Modeling Fundamentals for Games]] · [[AI Pitfalls - Assets and Import]] · [[Build Test and Release Pipeline]] · [[Batch Processing Tools in Studio]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Audio Pipeline]] · [[Code Pipeline - Rojo Git and CI]] · [[UI Asset Pipeline]] · [[Live Content Pipeline]]
<!-- related:end -->
