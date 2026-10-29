---
tags: [rigging, accessories, armor, welds, attachments]
---
# Accessories and Armor That Follow Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Re-rigging the character to add gear (new joints, moved attachments) -> Weld gear; never touch joints
> - Avoid: A rigid plate spanning a joint -> Split at the joint; overlap shapes
> - Avoid: Gear with mass or collision -> Massless, no collide, query or touch
>
> Cost: TL;DR ~110 tok · whole note ~3.4k tok. Read more: ## 1. Joint options for attached things · ## 3. The animation-safe armour fit (reference project) · ## Common mistakes
<!-- tldr:end -->

Anything rigidly attached to a body part follows that part's animation for free: the Animator moves the parts, and welded pieces ride along. So the real questions are which part to attach to, which joint type to use, how to fit pieces to bodies of different sizes, and how to do it **without touching anything the animation system owns**. This note covers Roblox's accessory mechanism, the joint options, and the animation-safe armour fit one production game shipped (dozens of armour sets on arbitrary player avatars, with no animation changes).

## 1. Joint options for attached things

| Joint | Defined by | Animatable? | Typical use |
|---|---|---|---|
| `Weld` | `Part0`, `Part1`, `C0`, `C1` | You can change `C0`/`C1` from code (moves the rest offset) | Armour plates, accessories, held items with code-driven offsets |
| `WeldConstraint` | `Part0`, `Part1`; snapshot of their current relative position | No offset properties | Welding parts already placed correctly (props, static rig pieces) |
| `RigidConstraint` | `Attachment0`, `Attachment1` | Move the attachments | Attaching to **Bones** (Bones are Attachments), sockets on skinned rigs |
| `Motor6D` | `Part0`, `Part1`, `C0`, `C1`, plus `Transform` | Yes: clips and code write `Transform` | Weapons that animate in the hand, hinged gear |
| Accessory weld | Created when an Accessory is added to a character | Rest offset from matching attachments | Hats, hair, back items, rigid accessories |

Choosing:

- **Static cosmetic on a part rig:** `Weld` if you will compute the offset; `WeldConstraint` if you placed it by hand.
- **Socket on a skinned rig:** `RigidConstraint` to a Bone. The reference project mounted every enemy prop (weapons, shields, back-mounted props) this way, and breakable props were released at runtime by disabling the constraint.
- **Anything that must animate relative to its parent:** `Motor6D`. See [[Custom Rigs - Weapons and Props]].

## 2. How Roblox accessories attach

A rigid `Accessory` contains a `Handle` part with an Attachment named like a body attachment (`HatAttachment`, `HairAttachment`, `FaceFrontAttachment`, `NeckAttachment`, `BodyBackAttachment`, `WaistBackAttachment`, `LeftShoulderAttachment`, `RightGripAttachment`, ...). When the accessory is added to a character (`Humanoid:AddAccessory`, or by the avatar loader), a weld joins the Handle to the body part that owns the matching attachment, with both attachments coinciding. The full list of body attachments and their measured offsets is in [[R15 Rig Anatomy and Attachments]].

Consequences for animation:

- An accessory follows **exactly one** body part. A hat follows the head; a cape on `BodyBackAttachment` follows the upper torso rigidly and does not swing.
- Accessory offsets scale with the body's attachment positions (attachments move when body scale values change), but the accessory mesh itself is scaled by the avatar system's accessory scaling, not by your code.
- Long rigid accessories collide visually with animated limbs (swords on the back vs arm swings, tails vs legs). Check them against your clips.

## 3. The animation-safe armour fit (reference project)

### Requirements

The user brief was "build every set and piece in Blender, and ensure you can apply it without breaking the current animations". The armour had to work on any player avatar (blocky, Rthro, slim), at the game's 1.6x player scale, with a live Lua animator, a first-person mode, and an in-menu preview.

### The rule

> No joint, Motor6D, AnimationConstraint, Humanoid property or scale value is touched. Armour is only **welded** to body parts.

Because the skeleton is untouched, every clip, every procedural layer, IK and the ragdoll behave identically with or without armour. This is the main reason to prefer welds over re-rigging a character for gear.

### The algorithm (ArmorFit)

For each armour mesh in the kit:

1. **Clone** the kit mesh.
2. **Scale per axis** by `wearer part size / reference part size`. The reference is an R15 rig at scale 1, measured once (`REF` sizes per part). A wider torso gives a wider breastplate.
3. **Weld** it with `Part0` = the body part it belongs to, `C0` = the piece's fit offset (its bounding-box centre in reference part space, scaled by the same per-axis factor) and its fit rotation.
4. Make it **non-physical**: `Massless`, `CanCollide`, `CanQuery`, `CanTouch` false, unanchored.
5. Parent everything into one folder, `Character.Armor`, so removal is one `Destroy`.
6. **Refit** when the body changes: after the game's scale service applies its body scale (`BodyHeightScale` 1.5 or more for the 1.6x players) and whenever `UpperTorso` resizes.

```lua
--!strict
-- Reference R15 part sizes at scale 1 (measure your own reference rig once).
local REF: { [string]: Vector3 } = {
	UpperTorso = Vector3.new(2, 1.6, 1),
	-- ... one entry per body part armour can sit on
}

local function fitPiece(character: Model, template: BasePart, folder: Folder): BasePart?
	local partName = template:GetAttribute("FitPart")
	local body = if typeof(partName) == "string" then character:FindFirstChild(partName) else nil
	if not (body and body:IsA("BasePart")) then
		return nil
	end
	local ref = REF[body.Name]
	if not ref then
		return nil
	end
	local k = body.Size / ref                                  -- per-axis fit factor
	local offset = (template:GetAttribute("FitOffset") :: Vector3?) or Vector3.zero
	local rot = (template:GetAttribute("FitRot") :: Vector3?) or Vector3.zero

	local piece = template:Clone()
	piece.Size = template.Size * k                             -- a MeshPart's mesh scales with Size
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false

	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = piece
	w.C0 = CFrame.new(offset * k)
		* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	w.Parent = piece
	piece.Parent = folder
	return piece
end
```

Per-axis scaling assumes the piece's axes line up with the body part's (the project authored with fit rotation 0). A piece rotated relative to its part would be sheared by non-uniform scaling; author pieces in part-aligned space instead.

### Authoring the pieces so they never clip

The pieces were built procedurally in Blender **in each body part's local space for the reference rig** (a measured rig description), and the build checked every mesh against its own part box and **every other R15 part box at rest**: 0 intrusions allowed. The fit envelope rules that made animation safe:

| Piece | Rule | Why |
|---|---|---|
| Limb plates | Inner sides open (toward the torso and the other leg) | Arms swing past the torso; legs pass each other |
| Pauldrons | Stay above the lower-arm box | Elbow bends would push the forearm into them |
| Bracers | Between y -0.45 and -0.03 of the forearm | Clear of the elbow and the wrist pivots |
| Thigh plates | Stop above the knee | The shin rotates at the knee |
| Shin plates | Start below the knee, with a knee cop in front | A cop covers the gap and moves with the shin |
| Boots | Leave the ankle free | Feet rotate at the ankle |

The general principle: **a rigid piece belongs to exactly one part and must not cross a joint.** Where coverage across a joint is needed, design overlapping shapes (cops, lames, flared cuffs) that each ride one side.

Budgets used: about 3,100-3,300 triangles maximum per mesh and 15,000-20,000 per full set including glow companions (each piece had a Neon `_Glow` twin welded the same way).

### Edit-mode verification

The fit was checked in Edit with the real `ArmorFit` on R15 dummies in several poses: rest, arms out 85 degrees, a walk stride, and 1.6x scale. Every set followed the limbs, pauldrons cleared the torso, and pieces on the 1.6x dummy scaled by exactly 1.6. Test rigs were removed afterwards. (Poses in Edit were set by forward kinematics on the RigAttachment pairs, since Edit has no simulation; see [[R15 Rig Anatomy and Attachments]].)

### Interplay with the avatar's own accessories

- **Helmets hide head accessories** (hats, hair, face items) by setting their `Transparency` to 1 and storing the original value in an attribute to restore later. Trying to fit a helmet over arbitrary hair is a losing battle.
- Layered clothing stays underneath; rigid armour simply overlaps it ([[Layered Clothing Cages and Animation]]).

### First person

Roblox fades the local character's parts in first person through `LocalTransparencyModifier`. Welded armour does not inherit that, so the project's client copied each body part's modifier to its armour pieces every frame for the local player:

```lua
--!strict
local RunService = game:GetService("RunService")

-- fades: armour piece -> the body part it is welded to (local player only)
local fades: { [BasePart]: BasePart } = {}

RunService.PreRender:Connect(function()
	for piece, body in fades do
		piece.LocalTransparencyModifier = body.LocalTransparencyModifier
	end
end)
```

### Preview

The menu preview copied the live character into a ViewportFrame and posed the copy every frame, either by copying joint transforms (so real animations and the held blade appeared) or by FK on the RigAttachment pairs for a scripted showcase stance. The selected armour piece was fitted onto the copy with the same `fitPiece`, so the preview could never disagree with the game.

## 4. Unjointed pieces: the silent bug

Procedural head and waist turning (for example rotating `Neck` and `Waist` joints toward the cursor) moves the head and torso parts. Accessory parts that were **not jointed** to those parts (a hood placed by hand, a skull ornament, an arm piece parented in the model but not welded) stay behind. The reference project hit this: such pieces must first be welded to the body part they sit on. The same applies to any cosmetic part you add to characters or NPCs. Rule: every part in a character is either the root or connected to it by a joint chain.

## 5. Mass, physics and networking

- **Massless** removes a part's contribution to its assembly's mass, which keeps Humanoid movement and knockback identical with and without armour. Massless is ignored for an assembly's root part, which is never the case for welded armour.
- **No collisions, queries or touches:** armour that collides snags on doorways and stairs; armour that queries breaks raycast hit detection (rays hit the plate, not the character); armour that touches fires `Touched` on hitboxes.
- **Where to weld:** welds made on the server replicate to everyone. The project fitted armour on the server so all players see it, while purely local effects (first-person fades, previews) ran on the client.
- **Instance count:** each piece is a part plus a weld; a full set with glows is a few dozen instances per player. Fine for players, worth watching for crowds of armoured NPCs ([[Performance and Memory]]).

## 6. Attachments on skinned rigs

On a skinned creature there are no limb parts to weld to; attach to Bones:

```lua
--!strict
-- Mount a prop on a bone socket of a skinned rig.
local function mountOnBone(bone: Bone, prop: BasePart, gripOffset: CFrame): RigidConstraint
	local att = Instance.new("Attachment")
	att.Name = "Mount"
	att.CFrame = gripOffset                 -- prop's grip frame in prop space
	att.Parent = prop
	prop.Massless = true
	prop.CanCollide = false
	local rc = Instance.new("RigidConstraint")
	rc.Attachment0 = bone                    -- Bones are Attachments
	rc.Attachment1 = att
	rc.Parent = prop
	return rc
end
```

Make sure the socket bone survived import (enable "Keep Zero Influence Bones" if it carries no weights; [[3D Importer Settings Reference]]). To drop the prop (a shield knocked away), set `rc.Enabled = false` and let it fall, or clone it at the bone's **animated** pose and hide the original, which is what the project's enemy client did for detachable parts.

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Re-rigging the character to add gear (new joints, moved attachments) | Clips subtly wrong, IK off, emotes broken | Weld gear; never touch joints |
| A rigid plate spanning a joint | Plate clips into the limb on every bend | Split at the joint; overlap shapes |
| Gear with mass or collision | Slower movement, snagging, raycasts hitting armour | Massless, no collide, query or touch |
| Unwelded cosmetic parts | Pieces left behind when the head or torso turns | Weld every piece to its part |
| Fitting once at spawn only | Gear floats after a body-scale change | Refit on scale changes and part resizes |
| First-person fade not copied | Armour blocks the first-person view | Copy `LocalTransparencyModifier` |
| Prop welded with `Weld` to a Bone | Error or nothing happens | `RigidConstraint` with the Bone as an attachment |

## See also

[[R15 Rig Anatomy and Attachments]] · [[Custom Rigs - Weapons and Props]] · [[Layered Clothing Cages and Animation]] · [[Custom Characters and StarterCharacter]] · [[Rigs and Joints]] · [[Weight Painting and Skinning for Roblox]] · [[Ragdolls and Physics-Based Animation]] · [[Performance and Memory]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · [[UGC Avatar Items and Accessories]] · [[Character and Creature Pipeline]] · [[Bones and Skinned Meshes]] · [[Physics Assemblies and Constraints]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Animation Start Here]]
<!-- auto-links:end -->
