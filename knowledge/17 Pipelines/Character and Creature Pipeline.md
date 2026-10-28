---
tags: [pipelines, characters, creatures, enemies, pets, armor, voxel, manifests]
---
# Character and Creature Pipeline

<!-- tldr:start -->
> [!tldr] TL;DR
> - Every clip broken after a model update: skeleton re-exported with renamed or re-rolled bones -> keep the manifest; rebuild the look onto it (Blender Armature and...
> - Creature floats after redesign: root height not re-measured -> measure from the new meshes on install
> - Pets face sideways: uploader pivot offsets -> clear `PivotOffset` on install
> - Contract written per character type (skeleton, names, scale)
> - Design scripts share style helpers and palette tables
> - Previews and a contact sheet for review
>
> Cost: TL;DR ~170 tok · whole note ~4.4k tok. Read more: ## The look-swap pipeline (enemies) · ## Armour and wearables: fit without touching joints · ## Failure modes · ## Checklist
<!-- tldr:end -->

Characters are the hardest assets to pipeline because they are three things glued together: a **look** (meshes, materials), a **skeleton** (bones or Motor6Ds, pivots, root height) and **behaviour data** (clips, hitboxes, AI role, stats). Change any one carelessly and the other two break: a new mesh with a different root height floats; a re-exported skeleton breaks every clip; a resized creature keeps its old hitbox.

The single idea that makes character pipelines manageable is: **keep the skeleton and the data stable, and swap the look**. This note shows that idea applied to enemies, pets, eggs and armour in one production game, with manifest-driven installs. Rigging, skinning and animation import are covered in depth in the Animation section: [[Rigging in Blender]], [[Weight Painting and Skinning for Roblox]], [[Creature Rig Conventions]], [[Pipeline - Importing Animated Enemies]], [[Enemy Import Axis Fix]], [[Ground Fitting Pipeline]]. Modelling is in [[Organic and Creature Modeling]] and [[Modeling Characters for R15 and Custom Rigs]]. This note is about the pipeline around them.

## Character content types and what is stable

| Type | Stable contract | What changes per item | Install style |
|---|---|---|---|
| Player avatar (R15) | R15 joints, attachments, Humanoid | accessories, clothing, armour meshes | weld or accessory fit, never touch joints |
| Custom NPC / enemy | skeleton (bone names, pivots, root), clip names | meshes, colours, scale | rig rebuild from manifest, keep clips |
| Pet / companion | follow attachment, scale stages | meshes per species and age | kit format: one model per species-age |
| Egg / container | named halves and roles | meshes, palette per rarity | parts named by role, painted by rarity |
| Armour / wearable | body part reference sizes | meshes per set and slot | per-axis scale + weld to body part |

Write the contract down for each type. It is the thing every new item must satisfy, and the gate checks it.

## The look-swap pipeline (enemies)

The reference project replaced all 49 enemies of its first realm with new, bigger creature designs in one day (measured in one production game). Every slot kept its id, skeleton (bones, pivots, root height), clips, AI role, zone and attacks. Only the look changed. That was possible because the pipeline separated the three layers.

### Stages

| # | Stage | Input | Output | Tool |
|---|---|---|---|---|
| 1 | Design brief | style guide, slot list | one paragraph per creature (concept, role, silhouette) | text |
| 2 | Build | `<slot>.py` design script + shared voxel helpers | `<Slot>.blend`, preview renders (3/4, front, side) | background Blender |
| 3 | Contact sheet | all previews | one image with every creature | Python (Pillow) |
| 4 | Review | contact sheet | approve / redo list | human |
| 5 | Upload | approved `.blend` files | one **model package** per creature, ids in a JSON | Blender uploader queue |
| 6 | Manifest | the live skeleton | `<Slot>_manifest` (bone names, pivots, part to bone map) | Studio export tool |
| 7 | Install | package id + manifest | rebuilt rig with new meshes, root heights re-measured | `Install(id, packageId)` in Studio |
| 8 | Verify | installed rig | clips play, feet on ground, hitbox scale | Studio checks |

### The design scripts

Each creature was a Python file (`<slot>.py`) using shared helpers: three-tone colour ramps, a square-stud texture atlas, part-seam lines. The style guide's rules (one grain per model, one neon colour, gold trim, exaggerate one feature, silhouette first) were coded in the helpers, so every new creature obeyed them automatically. A preview-only outline (an inverted hull, about 0.16 studs) made renders readable for review but was **not** exported, because it would double the triangles; in game the part seams and studs carried the look. See [[Voxel and Blocky Modeling]].

### The contact sheet

Reviewing 49 creatures one file at a time is slow and inconsistent. One image with all of them, same camera, same light, alphabetical by slot, lets a reviewer compare scale, colour and silhouette at a glance. It takes 20 lines of Pillow:

```python
# contact_sheet.py  (py -I contact_sheet.py renders_dir out.png 7)
import sys, pathlib
from PIL import Image, ImageDraw

src, out, cols = pathlib.Path(sys.argv[1]), sys.argv[2], int(sys.argv[3])
files = sorted(src.glob("*_34.png"))          # the 3/4 view of each creature
cell = 320
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell, rows * (cell + 24)), (40, 44, 52))
draw = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    img = Image.open(f).convert("RGB")
    img.thumbnail((cell, cell))
    x, y = (i % cols) * cell, (i // cols) * (cell + 24)
    sheet.paste(img, (x + (cell - img.width) // 2, y))
    draw.text((x + 6, y + cell + 4), f.stem.replace("_34", ""), fill=(230, 230, 230))
sheet.save(out)
print(f"{len(files)} creatures -> {out}")
```

### Packages, not loose meshes

Each creature was uploaded as one **model package** (a Model of MeshParts with one asset id), not 30 loose mesh ids. One id per creature means the install needs one number, the id map is short, and a re-upload swaps everything at once. Package ids went into a dated JSON file. See [[Packages and Asset Reuse]] and [[Asset Upload Automation with Open Cloud]].

### Manifest-driven install

A **manifest** is a small data file that describes the live skeleton the new look must fit: bone or joint names, pivot CFrames relative to the root, which mesh part attaches to which bone, the root height. It is exported from the current rig in Studio, so it is the truth about what clips expect.

The installer reads the manifest and the package, then:

1. loads the package (`InsertService:LoadAsset` in a plugin or command bar, or the package already inserted),
2. builds the new rig: same joint names and pivots as the manifest, new meshes parented to the matching bones,
3. **re-measures the root height** from the new meshes (lowest foot point to root), and the ground root height for walkers or a hover offset for flyers,
4. tags the model (`RailRiot = "2026-10-25"` style attribute with the pass name and date),
5. moves the previous model into one "old models" folder (one copy only) for rollback.

```lua
--!strict
-- Shape of a manifest-driven rig install (simplified). The manifest is a ModuleScript
-- returning { joints = { [name] = { parent: string, pivot: CFrame } }, attach = { [meshName] = jointName } }.
type Joint = { parent: string, pivot: CFrame }
type Manifest = { root: string, joints: { [string]: Joint }, attach: { [string]: string } }

local function lowestPointY(model: Model): number
	local minY = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, size = d.CFrame, d.Size
			-- conservative: bottom of the part's world-space bounding box
			local half = (cf.RightVector * size.X / 2):Abs()
				+ (cf.UpVector * size.Y / 2):Abs()
				+ (cf.LookVector * size.Z / 2):Abs()
			minY = math.min(minY, cf.Position.Y - half.Y)
		end
	end
	return minY
end

local function rebuild(old: Model, look: Model, manifest: Manifest): Model
	local rig = Instance.new("Model")
	rig.Name = old.Name
	local root = old:FindFirstChild(manifest.root, true) :: BasePart
	local newRoot = root:Clone()
	newRoot:ClearAllChildren()
	newRoot.Parent = rig
	rig.PrimaryPart = newRoot
	for meshName, jointName in manifest.attach do
		local mesh = look:FindFirstChild(meshName, true)
		if not (mesh and mesh:IsA("BasePart")) then
			warn("manifest names a mesh the look does not have:", meshName)
			continue
		end
		local m = mesh:Clone()
		m.Anchored = false
		m.Massless = true
		m.CanCollide = false
		m.Parent = rig
		local w = Instance.new("WeldConstraint") -- real rigs use Motor6Ds or bones per the manifest
		w.Part0, w.Part1 = newRoot, m
		w.Parent = m
		m:SetAttribute("Joint", jointName)
	end
	local rootHeight = newRoot.Position.Y - lowestPointY(rig)
	rig:SetAttribute("RootHeight", rootHeight)
	return rig
end

return rebuild
```

The real installer kept Motor6D and bone joints as the manifest described; the point of the sketch is the order: build from the manifest, attach by name, re-measure, mark. Joint math is in [[Motor6D Math and CFrame Composition]], root and ground fitting in [[Ground Fitting Pipeline]].

### Scale is gameplay, not just art

The redesign made creatures bigger on purpose: a size target of about 13 studs for regular enemies (the player is about 9 studs tall at that game's 1.6x character scale), with the smallest slots allowed to grow up to 3.2x. **Hit shapes scaled with them** through a per-enemy size factor; bosses were excluded. If you scale models without scaling hitboxes, attacks visibly pass through bodies; if you scale hitboxes without telling designers, the difficulty curve shifts. Keep scale as data in one place and let both the look and the combat read it. See [[Hitboxes and Hit Detection]].

Measured trivia worth knowing: the new creatures were 12k to 41k triangles each across several meshes (each mesh under 20k). That is fine for a few on screen and costly for swarms; see [[Level of Detail and Model Streaming]].

## Pets: species x stage as a kit

Pets multiply: 8 species x 3 ages is 24 models. The reference project treated each species-age as one kit model with a fixed structure (body, head, glow parts, follow attachment) and a scale per stage (0.55 / 0.8 / 1.1 for one family; another used length targets of 3.1 / 6.1 / 10.7 studs). Two lessons from it:

- **Clear uploader pivot offsets on install.** Meshes that came through the Blender uploader carried `PivotOffset` values that rotated the pivot; the installer reset them, otherwise every pet faced sideways when moved with `PivotTo`.
- **Name glow parts by role, not by accident.** A horn tip that was a bare part named "Glow" collided with a lookup for glow parts on the head; it was renamed to a role name (`Glow2_Head`). Role-based names (`<Part>_<Role>`) make painters and FX scripts simple.

## Eggs and containers: parts named by role

An egg model had a strict naming grammar: `EG__<Egg>__<Bottom|Top|Ring>_<Main|Accent|Dark|Glow>` (32 parts for a set). The installer then needed no table: it split the name, painted by rarity from the role (`Main` gets the rarity colour, `Glow` becomes Neon), set the primary part to `Bottom_Main`, put the pivot at the base, stored the egg height as an attribute, and the hatch animation flew every `Top*` and `Ring*` part. Naming grammars like this are the cheapest automation there is.

```lua
-- Paint an egg from its part names. Grammar: <Half>_<Role>, e.g. "Top_Accent".
local ROLE = {
	Main = function(p: BasePart, c: { [string]: Color3 }) p.Color = c.main end,
	Accent = function(p: BasePart, c: { [string]: Color3 }) p.Color = c.accent end,
	Dark = function(p: BasePart, c: { [string]: Color3 }) p.Color = c.dark end,
	Glow = function(p: BasePart, c: { [string]: Color3 })
		p.Color = c.glow
		p.Material = Enum.Material.Neon
		p.CastShadow = false
	end,
}

local function paintEgg(egg: Model, colors: { [string]: Color3 })
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then
			local role = string.match(d.Name, "_(%a+)$")
			local fn = role and ROLE[role]
			if fn then fn(d, colors) else warn("egg part with no role:", d:GetFullName()) end
		end
	end
end
```

## Armour and wearables: fit without touching joints

Armour is the case where breaking animation is easiest, so the contract is strict: **never touch a joint, Motor6D, AnimationConstraint, Humanoid or scale value**. The reference project's fit (measured in one production game):

1. Meshes are authored in each body part's local space against a measured reference R15 rig at scale 1.
2. At wear time, each mesh is cloned, scaled per axis by `wearer part size / reference size`, and welded to the body part with a stored offset.
3. Parts are `Massless`, no collision, no query, no touch, unanchored, inside a `Character.Armor` folder.
4. Refit after anything changes body size (a scale service, an UpperTorso resize).
5. A helmet hides hat, hair and face accessories by Transparency, storing the original.

The build script checked every armour mesh against its own body-part box and every other R15 part box at rest: **0 intrusions** was a gate. Budgets were about 3.1k-3.3k triangles per piece and 15k-20k per set including glow companions. See [[Accessories and Armor That Follow Animation]] and [[R15 Rig Anatomy and Attachments]].

### Voxel kit packages with a map and an atlas

For a later batch of 39 armour sets (889 MeshParts), the project used a **voxel kit** install:

- the Blender script exported every piece into a few large packages (`VoxKit_1..5`), each a Model of MeshParts;
- a **map** module listed, per live piece name, which package mesh to use and its fit offset;
- an **atlas** texture (one image, many colour swatches) was set as the trim TextureID, so all pieces shared one texture;
- `VoxKitInstall(source, { Map = ..., Atlas = ... })` built the live kit and reported **axis drift** (the difference between the expected and actual orientation after install). Drift 0 was the gate; a non-zero drift meant the export axis or pivot had changed.

A palette change later (an exclusive set recoloured to black and purple) only re-ran the Blender script with a new palette table and uploaded a new atlas; meshes and map were unchanged. That is the payoff of separating geometry, map and colour.

## Clips: keep them, bake them, archive them

Look swaps keep clips, which is why they are cheap. When clips themselves change (new imports, axis fixes, re-keys), the Animation section covers the pipeline: [[Pipeline - Importing Animated Enemies]], [[Baked Clip Stubs and Archiving]], [[Clip Archive Server]]. One rule crosses over: in the reference project enemy clips were baked to compact stubs and the originals archived to disk, so any tool that edits a clip must **restore the original first**, edit, then re-bake. Forgetting the restore edits a stub with no poses.

## Verification gates for characters

| Gate | How | Failure looks like |
|---|---|---|
| Every manifest mesh exists | installer warns on missing names | floating or missing limbs |
| Root height re-measured | attribute present and plausible | creature sinks into or floats above the floor |
| Clips play on the new rig | play each clip in Edit with `Animator` stepping or a Lua player | T-pose, limbs left behind |
| Feet on ground through walk | sample foot height over the walk cycle | sliding, sinking ([[Foot Placement and Ground IK]]) |
| Hitbox scale | compare hit shape to bounds | attacks pass through or hit air |
| Triangles per mesh under 20,000 | build report | upload failure |
| Pivots | `PivotOffset` cleared or intended | models rotate when moved |
| Armour intrusions | box test at rest and posed | clipping through the body |

Edit-mode gotchas from the reference project: `CreateHumanoidModelFromDescription` in Edit gives a rig without Motor6Ds, so pose test dummies from attachment pairs; character rigs may use `AnimationConstraint` joints, so procedural posing must accept both. See [[AnimationConstraint and Physically Simulated Characters]] and [[Testing Animations in Studio]].

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Every clip broken after a model update | skeleton re-exported with renamed or re-rolled bones | keep the manifest; rebuild the look onto it ([[Blender Armature and Bone Roll Conventions]]) |
| Creature floats after redesign | root height not re-measured | measure from the new meshes on install |
| Pets face sideways | uploader pivot offsets | clear `PivotOffset` on install |
| Armour drifts on big players | fit computed once at reference scale | refit on scale change |
| Two creatures share a palette by mistake | colours inline in each script | palette tables in shared helpers |
| Review takes days | one file at a time | contact sheet |
| Re-upload of one mesh means 30 id changes | loose meshes | one package per character |

## Checklist

- [ ] Contract written per character type (skeleton, names, scale)
- [ ] Design scripts share style helpers and palette tables
- [ ] Previews and a contact sheet for review
- [ ] One package per character, ids in a dated JSON
- [ ] Manifest exported from the live rig before the swap
- [ ] Installer rebuilds onto the manifest, re-measures root height, marks the model
- [ ] Previous model kept once for rollback, then removed after verification
- [ ] Hitboxes and scale read from one data source
- [ ] Clips untouched, or restored from archive before edits
- [ ] Gates: missing meshes, clips play, feet on ground, tris, pivots, intrusions

## See also

[[Art Pipeline - Concept to In-Game Asset]] · [[Pipeline - Importing Animated Enemies]] · [[Enemy and NPC Animation]] · [[Custom Characters and StarterCharacter]] · [[Blender Automation with Python]] · [[Case Study - Enemy Roster Rebuild]] · [[UGC Avatar Items and Accessories]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Importing Models and Rigs]] · [[Asset Pipelines]] · [[Bones and Skinned Meshes]] · [[Modeling in Blender for Roblox]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[3D Importer Settings Reference]]
<!-- auto-links:end -->
