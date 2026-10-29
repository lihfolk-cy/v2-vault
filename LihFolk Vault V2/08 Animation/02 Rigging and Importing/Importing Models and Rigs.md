---
tags: [import, rigging, studio, pipeline, prepare, type/guide, area/animation, level/intermediate, api/Animator, area/studio, api/AnimationController, api/Motor6D]
---
# Importing Models and Rigs into Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Import preset chosen for the asset kind; Upload off while testing.
> - Import found by content, not by name or selection.
> - Validation table passes (names, hierarchy, scale, facing, pivot, colours, clips).
> - Prepare run; Status shows nothing missing; run it twice to prove idempotency.
> - Imported clips renamed, moved, axis-fixed, markers added.
> - Pristine import kept somewhere outside the live hierarchy until verified, then removed.
>
> Cost: TL;DR ~150 tok · whole note ~4.4k tok. Read more: ## 1. Three routes into Studio · ## 4. The prepare step · ## 7. Checklist
<!-- tldr:end -->

Getting a model into Studio takes one click. Getting it into a state where it animates, faces the right way, sits on the ground, survives being cloned by a spawner and can be rebuilt next week takes a pipeline. This note is that pipeline: the routes in, how to find what you imported, how to validate it, and the idempotent "prepare" step that turns a raw import into a game-ready rig. Option-by-option importer details are in [[3D Importer Settings Reference]].

## 1. Three routes into Studio

| Route | How | Good for | Watch out for |
|---|---|---|---|
| **A. 3D Importer** | File > Import 3D, a person clicks through | Rigs with bones, clips, cages, avatar parts | Cannot be automated for a local file (the reference project's tooling could not import local files); every import lands as a model named after the file or `Scene` |
| **B. Upload from Blender** | An Open Cloud "upload to Roblox" Blender add-on uploads selected objects; Studio code inserts them by asset id (`InsertService:LoadAsset`) | Large static kits, armour, props, pet parts: hundreds of meshes without clicking | MeshParts arrived with a **rotated `PivotOffset`** (measured): reset it. Never print the add-on's token in logs. Upload failures ("Operation Timed Out") happen: retry those one at a time |
| **C. Mesh asset + code** | Upload meshes, then `AssetService:CreateMeshPartAsync(Content.fromUri(id), options)` in Studio | Parts whose `CollisionFidelity` or `RenderFidelity` you must choose (precise colliders on level art, box colliders on props) | `CollisionFidelity` cannot be changed on an already-loaded MeshPart (measured); it is set at creation |

Packages sit on top of any route: the reference project uploaded its armour and level kits as packages, then an install script in each place read the package and placed parts from a manifest (a JSON of names, offsets and attributes written by the Blender build).

### Route C in code

```lua
--!strict
local AssetService = game:GetService("AssetService")

-- Build a MeshPart with chosen fidelities. Falls back to cloning a template on failure.
local function meshPart(meshId: string, template: MeshPart?): MeshPart?
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,     -- props: cheap box collider
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if ok then
		return result
	end
	warn("CreateMeshPartAsync failed for", meshId, result)
	return if template then template:Clone() else nil
end

local part = meshPart("rbxassetid://0000000000")
```

### After an upload (route B): reset pivots

```lua
-- Uploaded MeshParts came in with a rotated PivotOffset, which breaks
-- GetBoundingBox, ScaleTo and PivotTo on the model. Reset before anything else.
local function resetPivots(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.PivotOffset = CFrame.new()
		end
	end
end
```

Record each object's bounding-box centre and size in Blender before upload (converted with Blender `(x, y, z)` to Roblox `(-x, z, y)`), so the install script can place parts exactly instead of trusting inserted positions.

## 2. Find what you imported (never by luck)

Rules learned the hard way in the reference project:

- **Never use `Selection`.** A batch can leave several imports in Workspace; the selected one is whatever the person clicked last.
- **Never use `FindFirstChild("Scene")`.** Every GLB import is a top-level model named `Scene` unless renamed, and at one point two unrelated `Scene` models existed at once (one belonged to someone else's batch). A builder that grabbed the wrong one renamed another team's parts before an assertion caught it.
- **Identify by content:** look for a marker part the exporter adds (the project's weapon exports carried a part named `RbxRefA`), or for a set of expected names.
- **Search top-level children first.** `workspace:GetDescendants()` takes seconds in a big place; imports are always top-level.

```lua
--!strict
-- Return the top-level import that contains every expected name.
local function findImport(expected: {string}): Model?
	for _, m in workspace:GetChildren() do
		if not m:IsA("Model") then continue end
		local all = true
		for _, name in expected do
			if not m:FindFirstChild(name, true) then
				all = false
				break
			end
		end
		if all then
			return m
		end
	end
	return nil
end

local boss = findImport({ "Root", "Body", "Head", "Jaw" })
assert(boss, "import not found: did the import step run?")
```

Write an `IMPORT_STEPS.txt` next to every batch: file names, the preset to use, and what the person should see afterwards. Imports are manual; the checklist makes them repeatable by anyone.

## 3. Validate before you build anything

"Never assume import success" was a standing rule in the project's import tooling. Check, in this order:

| Check | How | Typical failure |
|---|---|---|
| The model exists and is the right one | content match (above) | wrong `Scene` picked |
| Names survived | expected parts and bones present, no `.001`, no `__exp` suffix | kit meshes arrive as `<Name>__exp` (measured); rename |
| Hierarchy | bones parented as authored; one root | bones flattened, leaf `_end` bones present (FBX leaf bones left on) |
| Scale | model height vs the design height | 100x (FBX units) or 3.6x (metres vs studs) |
| Orientation | bind pose faces `LookVector`; feet down | backwards model; the project auto-detected facing from the bind pose as a sanity check |
| Pivot | `GetPivot()` at the root / ground point | pivot at the file origin far from the model |
| Colours | parts not grey | flat base colours dropped (measured with GLB); re-apply from the manifest |
| Animation data | clips exist where expected and actually move the rig | clips in `RBX_ANIMSAVES`, root pose at top level, whole body turned 180 degrees |

Distinguish three things people call "the animation": embedded animation data in the file, KeyframeSequence objects in Studio, and published Animation assets with ids. Only the last plays in a live server through the Animator ([[Publishing Animations]]); the project's Lua keyframe player removed that requirement for its own clips ([[Lua Keyframe Player]]).

## 4. The prepare step

One function per asset kind turns a raw import into a rig. It must be **idempotent** (safe to run twice: it reuses what exists and only adds what is missing) and end with a status report. The reference project's enemy prepare did, in order:

1. Add a `HumanoidRootPart`: an invisible, non-colliding box at the hips, sized to the body (radius x height), oriented by an explicit `YawFix` (0 for Blender -Y-forward GLBs), with `RootHeight` measured from the `Root` bone.
2. Weld or joint everything to it; add `AnimationController` + `Animator` (no Humanoid for server-moved creatures).
3. Create `KeyframeMarker`s from the exported marker JSON.
4. Assign clip references (`ClipId_*` attributes) and patch the enemy definition's clip durations and marker times, so the server never needs the clip ([[Enemy Animation State Protocol]]).
5. Move the model and clip sources to storage.

### Skeleton of a prepare function

```lua
--!strict
type PrepareOpts = {
	YawFix: number,                                  -- degrees; pass explicitly, never rely on a default
	RootHeight: number,                              -- HRP centre above the Root bone, studs
	BodySize: Vector3,                               -- HRP box size
	Marks: { [string]: { [string]: number } }?,      -- clip -> marker -> seconds
	Clips: Folder?,
}

local function prepare(model: Model, opts: PrepareOpts): { string }
	local report = {}

	-- 1. Root part (reuse if present)
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		local p = Instance.new("Part")
		p.Name = "HumanoidRootPart"
		p.Size = opts.BodySize
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = model:GetPivot()
			* CFrame.Angles(0, math.rad(opts.YawFix), 0)
			* CFrame.new(0, opts.RootHeight, 0)
		p.Parent = model
		hrp = p
		table.insert(report, "added HumanoidRootPart")
	end
	assert(hrp)
	model.PrimaryPart = hrp

	-- 2. Everything else follows the root; nothing inside an animated rig is anchored.
	-- Parts already driven by a joint (Part1 of a Motor6D) must NOT also be welded.
	local jointed: { [BasePart]: boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			jointed[d.Part1] = true
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= hrp then
			d.Anchored = false
			d.Massless = true
			if not jointed[d] and not d:FindFirstChild("RootWeld") then
				local w = Instance.new("WeldConstraint")
				w.Name = "RootWeld"
				w.Part0 = hrp
				w.Part1 = d
				w.Parent = d
			end
		end
	end

	-- 3. Controller + one Animator
	local ac = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
	ac.Parent = model
	if not ac:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = ac
		table.insert(report, "added Animator")
	end

	-- 4. Markers (idempotent: skip names already present at that time)
	if opts.Marks and opts.Clips then
		for clipName, marks in opts.Marks do
			local ks = opts.Clips:FindFirstChild(clipName)
			if not (ks and ks:IsA("KeyframeSequence")) then
				table.insert(report, "missing clip " .. clipName)
				continue
			end
			for markName, t in marks do
				local found: Keyframe? = nil
				for _, kf in ks:GetKeyframes() do
					if math.abs((kf :: Keyframe).Time - t) < 1e-3 then
						found = kf :: Keyframe
					end
				end
				local target: Keyframe
				if found then
					target = found
				else
					target = Instance.new("Keyframe")
					target.Time = t
					ks:AddKeyframe(target)          -- see the note below about spacing
				end
				local exists = false
				for _, m in target:GetMarkers() do
					if m.Name == markName then exists = true end
				end
				if not exists then
					local m = Instance.new("KeyframeMarker")
					m.Name = markName
					m.Value = markName
					target:AddMarker(m)
				end
			end
		end
	end

	table.insert(report, "ok")
	return report
end
```

A subtlety in step 4: adding a **marker-only keyframe** at a time that is not on the clip's existing key grid makes the keyframes unevenly spaced. The reference project measured that the Animator interpolates rotations by [[Quaternions|quaternion]] nlerp only when all keyframes are evenly spaced (marker-only keyframes count) and every key is Linear; otherwise it blends rotation vectors. On big turns far from rest the two differ by up to about 10 degrees. Prefer putting markers on existing keyframe times, or accept and verify the change. See [[How the Animator Really Behaves]].

### Part rigs: build joints from a manifest

For weapons, pets and props the project imported plain named parts (Rig Type: No Rig, Merge Meshes off) and built joints in code from a parts JSON written by the Blender build: bounding-box centre per part in the model frame, and for each hinge a world joint point and an optional `motorTo` parent for chained hinges.

```lua
-- o = { part = "Seg2", joint = {x, y, z}, motorTo = "Seg1" }   (from the manifest)
local function hinge(P: { [string]: BasePart }, handle: BasePart, o)
	local p = P[o.part]
	local jcf = CFrame.new(o.joint[1], o.joint[2], o.joint[3])   -- world-aligned joint frame
	local p0 = (o.motorTo and P[o.motorTo]) or handle               -- chained hinges hang off their parent
	local m = Instance.new("Motor6D")
	m.Name = o.part                                                  -- name the hinge after the moving piece
	m.Part0 = p0
	m.Part1 = p
	m.C0 = p0.CFrame:ToObjectSpace(jcf)
	m.C1 = p.CFrame:ToObjectSpace(jcf)
	m.Parent = p0
	return m
end
```

Because the joint frame is world-aligned at rest, clip rotations are in world axes and bone roll from Blender does not matter ([[Blender Armature and Bone Roll Conventions]]). The project's weapon rig builder additionally destroyed every joint, weld and constraint that came with the import, set all parts unanchored, `CanCollide`, `CanTouch` and `CanQuery` false and `Massless` true, made `Handle` the anchored PrimaryPart of the stored design rig, and kept the pristine import in a work-in-progress folder for rollback. See [[Custom Rigs - Weapons and Props]] and [[Weapon Design Rig Builder]].

Pet rigs used the same idea with an automatic fit: imported parts were matched to a rig description of part centres, and the install reported its fit error (for example "fit err 0.002, 11 motors, 27 welded pieces"). A fit error above a few thousandths of a stud means the wrong file or a moved part.

### Status reports

Every prepare and install tool in the project had a `Status()` that printed a table: which parts, joints, Animators, clips, markers and ids exist, and what is missing. Run it before and after. It is the cheapest debugging tool you will write.

## 5. Clips that came with the import

- They land in `ServerStorage.RBX_ANIMSAVES.<model name>`; with GLBs that is `Scene` (measured). Since 2026, Roblox says importer animations are also saved automatically to the rig's AnimSaves.
- Rename them and move them to your clip-source folders immediately; a second import overwrites or duplicates `Scene`.
- **Every imported clip needed an axis fix** in the reference project: the importer put the root pose at the keyframe top level (never applied) and conjugated it by a 180 degree turn, so bodies played turned around ("enemies attacked from behind" while server logic using `LookVector` was correct). The data fix is self-inverse and lives in [[Enemy Import Axis Fix]].
- `Turn*` clips additionally had root yaw stripped, because the server turns the root.
- After any re-import, check root motion (spawn rise, intro drop, leaps) actually plays.
- Unused importer `AnimSaves` copies on models are dead weight (the project archived and removed them; enemy models also carried 207k instances of clip copies that the spawner destroyed anyway). See [[Case Study - Cutting a Million Instances]].

## 6. Common import problems

| Symptom | Cause | Fix |
|---|---|---|
| Model huge or tiny | Unapplied scale in Blender, FBX unit chain, or Scale Unit mismatch | Apply transforms; fix export scaling; never scale in Studio to compensate |
| Faces backwards | Axis convention; a yaw fix applied twice | Author facing -Y for GLB; pass `YawFix` explicitly |
| Parts missing | Merge Meshes on, or zero-area parts dropped | Merge Meshes off; check the hierarchy panel before importing |
| Colours lost | GLB base-colour factors dropped (measured) | Textures or vertex colours; or re-apply part colours from the manifest |
| Socket bones missing | Zero-influence bones removed | Keep Zero Influence Bones on |
| Pivot rotated after upload | Uploader `PivotOffset` | `resetPivots(model)` |
| Clip plays but body floats or sinks | `HipHeight` or root height wrong for this model, or clips not ground-fitted | Re-measure root height; ground-fit clips ([[Ground Fitting Pipeline]]) |
| Clip plays turned 180 degrees | Importer root conjugation | [[Enemy Import Axis Fix]] |
| Rig "explodes" or jitters in Play | Parts welded **and** jointed, anchored parts inside the rig, colliding parts | One joint per part; only the root may be anchored, and only for static displays; non-colliding rig parts |
| Joints missing on a free-model R6 | Shoulders or hips never had Motor6Ds | Add the missing Motor6Ds with correct C0/C1 |
| Part of a rig does not follow animation | Unjointed accessory pieces (hood, skull) | Weld them to the body part they sit on ([[Accessories and Armor That Follow Animation]]) |
| Two Animators on one rig | Prepare step not idempotent | One Animator; check before creating |

## 7. Checklist

- [ ] Import preset chosen for the asset kind; Upload off while testing.
- [ ] Import found by content, not by name or selection.
- [ ] Validation table passes (names, hierarchy, scale, facing, pivot, colours, clips).
- [ ] Prepare run; Status shows nothing missing; run it twice to prove idempotency.
- [ ] Imported clips renamed, moved, axis-fixed, markers added.
- [ ] Pristine import kept somewhere outside the live hierarchy until verified, then removed.

## See also

[[3D Importer Settings Reference]] · [[Exporting FBX vs GLB]] · [[Rigging in Blender]] · [[Custom Rigs - Weapons and Props]] · [[Creature Rig Conventions]] · [[Pipeline - Importing Animated Enemies]] · [[Enemy Import Axis Fix]] · [[Publishing Animations]] · [[Troubleshooting Table]]

## Connected notes
<!-- auto-links:start -->
[[Animation Data from Blender to Roblox]] · [[Exporting and Validating Models for Roblox]] · Character and Creature Pipeline · Links - Importing into Studio · Skill - Roblox Asset Import · Modeling Characters for R15 and Custom Rigs · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Character and Creature Pipeline]] · [[Pipeline - New Animated Weapon]] · [[Retargeting Animations Between Rigs]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Custom Characters and StarterCharacter]] · [[Bones and Skinned Meshes]] · [[Weight Painting and Skinning for Roblox]] · [[Engine Gotchas]] · [[Moon Animator and Third-Party Tools]] · [[Baked Clip Stubs and Archiving]]
<!-- related:end -->
