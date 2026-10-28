---
tags: [pipeline, weapons, rigging, motor6d, import]
---
# Weapon Design Rig Builder

How one live action game turned an imported weapon model into an animatable "Design rig": a Handle-rooted Model with one Motor6D per hinge, everything else welded, and its own Idle and Special clips. Two routes are covered: the **setup-script route** (a GLB plus a script describing hinges, materials and per-frame animation) and the **own-Blender-model route** (meshes uploaded individually, placed from a parts JSON). The surrounding workflow is [[Pipeline - New Animated Weapon]]; the player that animates the result is [[Weapon Rig Player]]; general weapon rigging is in [[Custom Rigs - Weapons and Props]].

## The target structure

```
Model "<weaponId>"                     PrimaryPart = Handle
├── Handle (BasePart)                  Anchored while stored; attrs Scale; child Attachment "BladeFrame"
│   ├── Motor6D "<HingeA>"  Part0 = Handle,  Part1 = HingeA part
│   ├── Motor6D "<HingeB>"  Part0 = Handle,  Part1 = HingeB part
│   └── ...
├── HingeA part (+ its welded detail parts via WeldConstraint)
├── ... every other part (WeldConstraint to its owner part or the Handle)
├── Animations (Folder)
│   ├── Idle     (KeyframeSequence, Loop, Priority Idle)
│   └── Special  (KeyframeSequence, Priority Action)
├── AnimationController
│   └── Animator
└── attributes: FXModule, IdleId = "", SpecialId = "", BladeColor, setup provenance
```

Rules the structure encodes:

- **Every part is unanchored, `CanCollide`/`CanTouch`/`CanQuery` false, `Massless` true**, except the Handle. A held weapon must not push the player, block raycasts, or add mass to the arm.
- **Only hinges get Motor6Ds.** A Motor6D is what an animation (or `Transform`) can move. Anything that only needs to follow uses a `WeldConstraint`, which is cheaper and cannot be disturbed by a stray clip key.
- **Clips key hinges by their moving part's name.** A clip key for a part with no Motor6D is inert; the Animator (and the Lua players) match joints the same way, so a missing joint is silent, not an error. One weapon shipped with eight ribbon segments and two scale pieces keyed in its clips but never jointed: they simply never moved.
- **`IdleId` / `SpecialId` start empty.** If you publish the clips, the asset ids go here and the player prefers them. If you do not, the Lua rig player plays the KeyframeSequences directly.

## Route 1: the setup-script import

### Step 1: recover the design frame from three reference parts

The 3D importer re-centres, may rotate (it turns GLBs 180 deg about Y, see [[Enemy Import Axis Fix]]) and scales the model. Every position in the setup script is in **design space** (the modelling tool's units and axes). To use them you need the exact transform from design space to the imported world, including uniform scale.

The setup embeds three tiny parts at known design-space positions:

| Part | Design position |
|---|---|
| `RbxRefA` | (0, -0.48, 0) |
| `RbxRefB` | (0, -0.2875, 0) |
| `RbxRefC` | (0.037, -0.48, 0) |

After import, their world positions A, B, C are read and an orthonormal basis is built from each triangle: the first axis along A to B, the second the component of A to C perpendicular to it, the third their cross product. The rotation between the two bases, the length ratio of A to B, and A itself define the mapping:

```lua
local MA, MB, MC = Vector3.new(0, -0.48, 0), Vector3.new(0, -0.2875, 0), Vector3.new(0.037, -0.48, 0)
local A, B, C = P.RbxRefA.Position, P.RbxRefB.Position, P.RbxRefC.Position

local function basis(a: Vector3, b: Vector3, c: Vector3): CFrame
	local u = (b - a).Unit                        -- first axis: a -> b
	local r = c - a
	r = (r - u * r:Dot(u)).Unit                   -- second axis: a -> c made square to the first
	return CFrame.fromMatrix(Vector3.zero, r, u, r:Cross(u))
end

local rot = basis(A, B, C) * basis(MA, MB, MC):Inverse()       -- design axes -> world axes
local sc = (B - A).Magnitude / (MB - MA).Magnitude              -- uniform import scale
local function W(v: Vector3): Vector3                           -- a design-space point -> world
	return A + rot:VectorToWorldSpace((v - MA) * sc)
end
```

Why three points and not the model's pivot: the importer's pivot and bounding box depend on which meshes exist and on import options; reference markers are immune to both. The scale `sc` is stored on the Handle (`Scale` attribute) because every design-unit offset (hinge pivots, position keys, effect offsets) must be multiplied by it. The reference parts are destroyed once measured.

`BladeFrame` is placed at `CFrame.new(W(Vector3.zero)) * rot`: the design origin with design axes. Effects authored in design space attach to it.

### Step 2: materials

The importer drops GLB base colours and may attach `SurfaceAppearance`s. The setup's material table restores the intended look per part: clear `TextureID`, destroy `SurfaceAppearance` children, set `Material`, `Color` (hex), `Reflectance`, `Transparency`, and `CastShadow = false` for Neon parts and for mostly transparent parts.

### Step 3: tear down the importer's joints

Destroy every `JointInstance`, `WeldConstraint` and `Constraint` under every part before building. The importer's welds are not your hierarchy, and leftover welds fight Motor6Ds (a part welded to the Handle and also driven by a Motor6D will not move, or will drag the Handle with it).

### Step 4: hinges

Each hinge row is `{ name, part, pivot (design Vector3), CFrame (design rotation of the hinge axis) }`. The joint frame in the world is the pivot mapped through `W`, with the design rotation carried by `rot`:

```lua
for _, h in HINGES do
	local part = P[h[2]]
	local J = CFrame.new(W(h[3])) * rot * h[4]            -- world joint frame: pivot + hinge axes
	local m = Instance.new("Motor6D")
	m.Name = h[1]
	m.Part0 = handle
	m.Part1 = part
	m.C0 = handle.CFrame:ToObjectSpace(J)                 -- joint frame in Handle space
	m.C1 = part.CFrame:ToObjectSpace(J)                   -- joint frame in the part's space
	m.Parent = handle
	PIVOT[h[2]] = true
end
```

With `C0` and `C1` both describing the same world frame, the Motor6D starts at rest with `Transform = identity` and does not move the part on creation: `Part1 = Part0 * C0 * Transform * C1:Inverse()` reproduces the part's current CFrame exactly ([[Motor6D Math and CFrame Composition]]). Rotations keyed in clips are then about the hinge's own axes, which is what the setup's animation data assumes.

### Step 5: welds

- **Owner table:** detail parts (a clamp's plastic and glow pieces) weld to their owner part (the clamp's metal), so they move with the hinge.
- Everything else that is not a hinge part and not a chain link welds to the Handle.
- **Hanging chains** (`CH` rows: link part and host part) are welded rigid to their host. The designer's preview swings them physically; a held, massless, replicated rig cannot run that physics reliably.

### Step 6: the clips

The setup carries raw per-frame data: for each frame, per animated hinge, a quaternion `x, y, z, w` and, for hinges flagged with position keys, a position in design units. The generator thins it per joint (offline) and the installer writes it:

```lua
-- keys[part] = { { t, qx, qy, qz, qw [, px, py, pz] }, ... }   (thinned, rounded)
for cname, c in CLIPS do
	local ks = Instance.new("KeyframeSequence")
	ks.Name = cname
	ks.Loop = c.loop
	ks.Priority = c.loop and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Action
	local byT = {}
	for part, keys in c.keys do
		for _, k in keys do
			local tk = string.format("%.4f", k[1])                  -- merge joints keyed at the same time
			byT[tk] = byT[tk] or { t = k[1], p = {} }
			byT[tk].p[part] = k[6]
				and CFrame.new(k[6] * sc, k[7] * sc, k[8] * sc, k[2], k[3], k[4], k[5])   -- position keys scale with the import
				or CFrame.new(0, 0, 0, k[2], k[3], k[4], k[5])
		end
	end
	byT["0.0000"] = byT["0.0000"] or { t = 0, p = {} }             -- a first and a last keyframe always exist
	local endKey = string.format("%.4f", c.len)
	byT[endKey] = byT[endKey] or { t = c.len, p = {} }
	for _, e in byT do
		local kf = Instance.new("Keyframe")
		kf.Time = e.t
		local root = Instance.new("Pose")
		root.Name = "Handle"; root.Weight = 0                       -- the top-level pose is never applied: a placeholder
		root.Parent = kf
		for part, cf in e.p do
			local po = Instance.new("Pose")
			po.Name = part; po.CFrame = cf
			po.EasingStyle = Enum.PoseEasingStyle.Linear              -- dense thinned keys: Linear between them
			po.Parent = root
		end
		kf.Parent = ks
	end
	ks.Parent = anims
end
```

Points worth copying:

- `CFrame.new(x, y, z, qx, qy, qz, qw)` builds a CFrame directly from a quaternion; no Euler conversion, no gimbal issues.
- **The top-level Pose is the rig root** (here `Handle`) at weight 0. The Animator never applies the keyframe's top-level pose, so it is only a parent. Hinge poses go under it, named after their moving part.
- **Keyframes are merged by time across joints.** Per-joint thinning produces different key times per hinge; one Keyframe per distinct time, each carrying only the joints keyed then. Joints not keyed at a keyframe are simply absent (not weight 0) and interpolate across it.
- A first and last keyframe always exist so `Length` and looping are right even when no joint keys the very end.

### The thinning algorithm

Greedy forward extension, per joint:

```
keep = [0]; i = 0
while i < n - 1:
    j = i + 1
    while j + 1 < n and t[j+1] - t[i] <= 0.5:                  -- never more than 0.5 s between kept keys
        if every frame k in (i, j+1] is reproduced by nlerp(q[i], q[j+1], u_k) within 0.004 rad
           (and, for position hinges, lerp within 0.003 design units): j += 1
        else: break
    keep.append(j); i = j
```

A looping clip first gets frame 0 appended at time = length, so the last key equals the first and the loop is seamless. Joints that never leave rest (within 1e-3 rad, and no position) are dropped entirely. Typical result: an 8 s idle at 30 fps (240 frames x several hinges) collapses to a few dozen keys per moving hinge.

The 0.5 s cap matters for runtime, not accuracy: the Animator decides between nlerp and rotation-vector interpolation from key spacing ([[How the Animator Really Behaves]]), and long uneven spans are where the two models differ most. Thinned clips are uneven by construction, so the player must use the rotation-vector model for them.

### Step 7: attributes, parking and idempotency

- `FXModule` names the weapon's effects module; `IdleId`/`SpecialId` empty; `BladeColor` (vivid) and `BladeColorRaw`; provenance attributes (setup name, date).
- The previous rig with the same id is renamed and parked in a work folder, the pristine import too (once). The import model is destroyed after its parts move into the rig.
- The rig is pivoted far below the map (y = -500) and parented to the character-models store.
- The whole build runs inside `pcall`; the result string (instance count, child count, or "FAILED: reason") is the report.
- **Reruns are safe:** a rerun finds no import in Workspace, clones the pristine copy back, and rebuilds.

## Route 2: your own Blender model (no setup script)

When the weapon is built in Blender in-house, there is no setup script and no GLB import. Instead:

1. Each mesh is uploaded (an add-on using Open Cloud) and its asset id recorded. After upload, clear any pivot offsets the uploader added, or parts come in rotated.
2. Meshes are loaded as MeshParts with the collision and render fidelity you want. `CollisionFidelity` cannot be changed on an already loaded MeshPart, so the builder creates fresh ones:

```lua
local ok, mp = pcall(function()
	return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
		CollisionFidelity = Enum.CollisionFidelity.Box,          -- cheapest; the weapon never collides anyway
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
end)
if not ok or not mp then mp = template:Clone() end              -- fall back to a pre-loaded copy
```

3. A **parts JSON** exported from Blender gives, per object: part name, mesh name, size, offset (bounding-box centre in the model frame, the Handle centre at the origin), material, colour, transparency, and for hinges `motor = true`, `joint = {x, y, z}` (world pivot), and optionally `motorTo` (the parent hinge's part for chained hinges) or `weldTo`.
4. Hinges are built from the world joint point, with chaining:

```lua
for _, o in J.objects do
	local p = P[o.part]
	if o.motor then
		local jcf = CFrame.new(o.joint[1], o.joint[2], o.joint[3])     -- pivot only: the hinge axes are the model axes
		local p0 = (o.motorTo and P[o.motorTo]) or handle                -- chained hinge: parent is another hinge
		local m = Instance.new("Motor6D")
		m.Name = o.part; m.Part0 = p0; m.Part1 = p
		m.C0 = p0.CFrame:ToObjectSpace(jcf)
		m.C1 = p.CFrame:ToObjectSpace(jcf)
		m.Parent = p0
	elseif p ~= handle then
		local w = Instance.new("WeldConstraint")
		w.Part0 = P[o.weldTo] or handle; w.Part1 = p; w.Parent = p
	end
end
```

5. **Chained hinges nest their poses** under the parent hinge's pose, mirroring the joint tree (a flexible sword of 4 ribbons x 5 segments each, every segment parented to the one before). Intermediate poses with no key at that time are weight-0 placeholders:

```lua
local function pose(part: string): Pose
	if made[part] then return made[part] end
	local po = Instance.new("Pose")
	po.Name = part
	po.CFrame = k.p[part] or CFrame.identity
	if not k.p[part] then po.Weight = 0 end                        -- only a path to a keyed child
	local up = parentOf[part]
	po.Parent = up and pose(up) or root                             -- parents first, recursively
	made[part] = po
	return po
end
```

Why nesting matters: the Lua rig player binds a pose to a motor by the pair (parent pose name, pose name) = (Part0 name, Part1 name). A chained segment's Part0 is the previous segment, so its pose must sit under that segment's pose to bind. The Animator follows the same pose-path convention.

6. Clips go to a server-side store, and the weapon service copies them onto the held tool when equipped, so they do not sit in replicated storage for every weapon at all times.

**Caveat from production:** hinge axes in this route are the model axes at each pivot (`CFrame.new(pivot)` has identity rotation). Where a hinge needs a tilted axis, the clip's rotations must be authored in model axes; in one batch, hinge directions were "guessed from geometry" and flagged for play-testing.

## Grip placement gotchas

Holding is a separate system, but rig builders feed it:

- The grip part is named `Grip` or `Handle`; a long pommel stays behind the hand.
- A default rule placed the grip 28% from the butt; a model attribute `GripExact = true` skips it for weapons whose grip is already exact.
- A name scan for blade "bits" matched `Orbit_*` parts and moved the grip to 18% from the butt on 11 weapons. Name-based scans must exclude known false positives (here, anything containing "orbit").

## Testing a rig in Edit mode

`Motor6D.Transform` written by a script does not move parts in Edit mode on its own (nothing steps the joints). The rig player has hooks for exactly this:

```lua
local PoseDriver = freshRequire(ReplicatedStorage.WeaponFX.PoseDriver)   -- clone-require: Edit caches modules
local rig = storedRig:Clone(); rig.Parent = workspace
PoseDriver.SetManual(rig, true)                 -- off the shared update loop
local idle = PoseDriver.Load(rig, "Idle", { looped = true })
idle:Play(0)
PoseDriver.Step(rig, 0)                          -- apply frame 0
-- record each motor's Transform, then:
PoseDriver.Step(rig, 1.7)                        -- advance 1.7 s and apply
-- compare: how many motors moved? (position change > 1e-4 or axis change > 0.01 rad)
```

A rig where "0 of N joints moved" usually means a naming mismatch between clip poses and motors, a missing Motor6D, or poses at the wrong nesting level.

## Checklist

- [ ] Design frame recovered from reference markers; `Scale` stored.
- [ ] Importer joints destroyed; materials restored.
- [ ] One Motor6D per hinge with C0 and C1 describing the same world frame.
- [ ] Details welded to owners; chain links welded rigid.
- [ ] Parts unanchored, non-colliding, massless (Handle excepted).
- [ ] Clips: weight-0 root pose, hinge poses named after their part, nested for chains, first and last keyframes present, thinned.
- [ ] Animator present; `IdleId`/`SpecialId` attributes present (empty or published).
- [ ] Edit test: every motor moves under the rig player.

## See also

[[Pipeline - New Animated Weapon]], [[Weapon Rig Player]], [[Custom Rigs - Weapons and Props]], [[Rigging in Blender]], [[Importing Models and Rigs]], [[3D Importer Settings Reference]], [[Motor6D Math and CFrame Composition]], [[KeyframeSequence Keyframe and Pose Reference]]

## Connected notes
<!-- auto-links:start -->
[[Rigs and Joints]] · [[Animation Data from Blender to Roblox]] · [[Modeling Weapons and Props]] · [[Authoring Clips in Code]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Skeleton Library]] · [[Animation Start Here]]
<!-- auto-links:end -->
