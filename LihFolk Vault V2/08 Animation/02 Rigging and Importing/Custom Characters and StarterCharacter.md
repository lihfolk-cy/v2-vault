---
tags: [rigging, characters, startercharacter, humanoid, r15, type/guide, area/animation, level/intermediate, api/HipHeight, api/Humanoid, api/HumanoidDescription]
---
# Custom Characters and StarterCharacter

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Non-R15 StarterCharacter with the default Animate -> Own `Animate` in StarterCharacterScripts
> - Avoid: Wrong HipHeight -> Compute from the rest model
> - Avoid: Anchored or unjoined parts -> Joint everything to the root; nothing anchored
>
> Cost: TL;DR ~100 tok · whole note ~3.2k tok. Read more: ## 1. Five ways to customise a character · ## 4. HipHeight · ## Common mistakes
<!-- tldr:end -->

"Give the player a custom character" covers five very different jobs, from swapping a hat to replacing the whole skeleton. Each choice decides which built-in systems keep working (the default Animate script, emotes, layered clothing, avatar accessories, the Animation Editor's R15 tools) and which ones you must rebuild. This note maps the options, then covers the mechanics that trip people up: Humanoid requirements, `HipHeight`, scale, the Animate script and testing.

## 1. Five ways to customise a character

| Approach | What changes | Keeps working | You must rebuild |
|---|---|---|---|
| **A. Dress the avatar** (weld meshes onto R15 parts) | Look only | Everything: avatar, Animate, emotes, layered clothing, all R15 clips | Fitting per body size |
| **B. Apply a HumanoidDescription** | Body parts, scales, clothing, animation ids | Everything R15 | Nothing, if you stay within R15 |
| **C. R15-compatible custom body** (imported, 15 parts or a skinned R15 skeleton) | Mesh and proportions | R15 clips, Animate, most emotes; layered clothing if caged | Avatar appearance (the player's own look) |
| **D. StarterCharacter with a non-R15 skeleton** | Everything | Humanoid physics and movement | Animation set, Animate script, tools, emotes, clothing |
| **E. Fully custom spawn** (`CharacterAutoLoads = false`) | Everything, including when and how characters spawn | Whatever you keep | Spawning, respawn, reset, possibly camera |

The reference project (a live action game) used A and B: players kept their own R15 avatars, scaled 1.6x through body scale values (about 9 studs tall), with armour welded on (see [[Accessories and Armor That Follow Animation]]) and weapons held by a hand Motor6D. An NPC shopkeeper was a default R15 body at scale 1.7 plus a modelled outfit. Enemies used AnimationController rigs instead of Humanoids. Rule of thumb from that project: **stay R15 for anything a player controls** unless the game's identity needs a non-human body; every built-in animation system assumes R15.

## 2. StarterCharacter basics

Put a Model named **`StarterCharacter`** in `StarterPlayer`. Every player then spawns as a copy of it instead of their avatar. Requirements in practice:

| Requirement | Why |
|---|---|
| A `Humanoid` | Movement, states, health, the character contract |
| An `Animator` under the Humanoid | Clip playback; create it rather than relying on lazy creation |
| A `HumanoidRootPart`, set as `PrimaryPart` | The part the Humanoid moves; root of the joint tree |
| Every other part joined to it by joints (Motor6D or [[AnimationConstraint]]), no anchored parts | Anything unjoined falls off; anything anchored freezes the character |
| `Humanoid.RigType` matching the skeleton (R15 for R15 names) | Selects the default animation set and some physics behaviour |
| A correct `HipHeight` (section 4) | Otherwise the character floats or sinks |
| Visual parts non-colliding except what you mean to collide | Extra colliding parts snag on geometry |

What you lose: the player's avatar appearance (accessories, clothing, body). If the StarterCharacter is R15-compatible you can re-apply a `HumanoidDescription` (for example the player's own, from `Players:GetHumanoidDescriptionFromUserIdAsync`) to restore parts of it.

A community guide warns that swapping `StarterCharacter` at runtime causes odd bugs; if different players or modes need different bodies, use a custom spawn (approach E) and set `player.Character` yourself.

## 3. The Animate script on custom characters

Roblox inserts a default `Animate` LocalScript into spawned characters; it loads the R15 (or R6) default clips by id and switches them on Humanoid state changes ([[The Default Animate Script]]). On a non-R15 skeleton those clips key joints that do not exist, so they do nothing, silently.

Options:

- **R15-compatible body:** keep Animate. Override individual clips through the `StringValue` / `Animation` children it reads, or through `HumanoidDescription` animation ids.
- **Different skeleton:** put your own LocalScript named `Animate` in `StarterCharacterScripts` (a widely used convention to replace the default), and drive your clips from Humanoid state and speed. Reuse the structure of the default script; it handles state edge cases you will otherwise rediscover.
- **Hybrid** (what the reference project did for its procedural locomotion): a custom animator drives locomotion layers and hands back to the default Animate for states it does not cover. In that project, Climbing, Swimming, Seated, Ragdoll and PlatformStanding returned to Animate; its own clips ran at Movement priority, above Animate's clips and its tool-hold pose but below everything else. The default "tool none" hold (arm straight out) had to be faded to about weight 0 whenever a blade was not truly held. See [[Locomotion Systems]] and [[Custom Locomotion Controller Design]].

## 4. HipHeight

For R15-type Humanoids the root part is held at `HipHeight + HumanoidRootPart.Size.Y / 2` above the ground. Get it wrong and the character floats (feet visibly above ground, shadows detached) or sinks (feet through the floor, legs clipping on slopes). On a default R15 the Humanoid computes it (measured 2.19 on the blocky body). On custom rigs, compute it from the model at rest:

```lua
--!strict
-- Distance from the bottom of the HumanoidRootPart down to the lowest point of the body at rest.
local function computeHipHeight(character: Model): number
	local hrp = character.PrimaryPart :: BasePart
	local lowest = math.huge
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d ~= hrp and d.Transparency < 1 then
			local cf, half = d.CFrame, d.Size / 2
			-- world-Y half extent of an oriented box
			local ext = math.abs(cf.RightVector.Y) * half.X
				+ math.abs(cf.UpVector.Y) * half.Y
				+ math.abs(cf.LookVector.Y) * half.Z
			lowest = math.min(lowest, cf.Position.Y - ext)
		end
	end
	return (hrp.Position.Y - hrp.Size.Y / 2) - lowest
end
```

Box extents overestimate rounded meshes slightly; subtract a skin pad (a few hundredths of a stud) if feet visibly hover. Re-measure whenever proportions change. The reference project fixed `HipHeight` on 17 NPC templates after a re-model, and ground-fitted death clips separately (a different problem: clips that dip below the floor). See [[Ground Fitting Pipeline]].

Clips assume a hip height too. A crouch authored on a 12-stud creature lowers the hips by a fixed number of studs; on a 6-stud copy that is twice as deep relative to its legs. Scale root translations with the character (section 5).

## 5. Scale: body scale values or model scale?

| Method | How | Clip root translations | Works with |
|---|---|---|---|
| Body scale values | `BodyHeightScale` and friends on the Humanoid (or `HumanoidDescription`) | Applied literally (measured): author them at game scale | R15 only |
| Model scale | `Model:ScaleTo(k)` | Scaled by `Model:GetScale()` by the Animator (measured) | Any rig |

The reference project's players were 1.6x via body scales, so its clips had to store root offsets multiplied by 1.6; a crouch baked at scale 1 left the feet hovering. Ranges, camera offsets and hitboxes also had to account for 1.6x. A Lua keyframe player must reproduce the same rule to match the Animator. Pick one method per project and write it in your conventions. See [[Scale and Animation]].

## 6. Skinned custom bodies

A single skinned mesh can be a Humanoid character:

- Follow the R15 skeleton names to keep R15 clips (`LowerTorso`, `UpperTorso`, `LeftUpperArm`, ...). Roblox's body specification describes `Root > HumanoidRootNode > LowerTorso > ...`, 15 `_Geo` meshes for Marketplace bodies, and up to 37 optional extra bones (spine, chest, clavicles, fingers, toes) with `HumanoidRigDescription` / `DigitsRigDescription` added after import. See [[R15 Rig Anatomy and Attachments]].
- **Avatar Setup** (Studio) can test, cage and prepare a body; the importer's "Validate UGC Body" opens it.
- Extra bones beyond R15 (tails, capes, ears) only move if clips key them or code drives them. Default clips will leave them at rest; add a secondary-motion layer in code ([[Idle Breathing and Secondary Motion]]).
- If you rename R15 bones, every R15 clip, emote and the Animate script stop driving them. Add bones; do not rename.

## 7. Fully custom spawning

```lua
--!strict
local Players = game:GetService("Players")
local template = game:GetService("ServerStorage"):WaitForChild("CharacterTemplate") :: Model

Players.CharacterAutoLoads = false

local function spawnCharacter(player: Player, at: CFrame)
	local old = player.Character
	local char = template:Clone()
	char.Name = player.Name
	char:PivotTo(at)
	player.Character = char          -- set before parenting so client scripts see the right character
	char.Parent = workspace
	if old then old:Destroy() end
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.Died:Once(function()
		task.wait(3)
		if player.Parent then spawnCharacter(player, at) end
	end)
end

Players.PlayerAdded:Connect(function(player)
	spawnCharacter(player, CFrame.new(0, 10, 0))
end)
```

With auto-loading off you own respawn, reset and the moment `CharacterAdded` fires. Do not assume the engine's spawn extras happen for a model you assign yourself: the copying of `StarterCharacterScripts` and the default Animate insertion belong to the normal spawn path (`LoadCharacter`). Put the scripts you need (your `Animate`, health, camera hooks) into the template, and verify on the spawned model that each exists exactly once.

## 8. Ownership and replication

The client owns its character's physics and its Animator: clips the client plays on its own Humanoid's Animator replicate to other players automatically. Clips played by a Lua keyframe player do not; the reference project relayed them through a server remote with attribute metadata. Weapon offsets were computed on each client from shared data rather than replicated. See [[Replication and Ownership]].

## 9. Testing custom characters in Studio

- `Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)` builds test dummies in Edit. In October 2026 its joints were AnimationConstraints, not Motor6Ds (measured); tooling that expects Motor6Ds needs to accept both.
- Edit mode has no physics: `HipHeight` and floor contact can only be checked in Play, or by computing positions.
- `Animator:StepAnimations(dt)` steps clips in Edit (dt must be greater than 0). See [[Testing Animations in Studio]].
- Test with **several avatar bodies**, not just the blocky dummy. The reference project's arm QA was calibrated on a blocky dummy and noted that slimmer avatars clear the body more easily than the QA predicted; armour fitting had to scale per part size.

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Non-R15 StarterCharacter with the default Animate | Character slides around in rest pose | Own `Animate` in StarterCharacterScripts |
| Wrong [[HipHeight]] | Floating or sinking; feet clip on slopes | Compute from the rest model |
| Anchored or unjoined parts | Character frozen, or parts left behind at spawn | Joint everything to the root; nothing anchored |
| Body scaled with `ScaleTo` but clips authored for body-scale values (or the reverse) | Crouches hover or sink; lunges too short or long | One scaling method; author root offsets accordingly |
| Renamed R15 bones on a custom skinned body | R15 clips and emotes do nothing | Keep names; add extra bones |
| StarterCharacter swapped at runtime | Odd spawn bugs | Custom spawn with `CharacterAutoLoads = false` |

## See also

[[R15 Rig Anatomy and Attachments]] · [[The Default Animate Script]] · [[Humanoid States and Animation]] · [[Scale and Animation]] · [[Locomotion Systems]] · [[Accessories and Armor That Follow Animation]] · [[Layered Clothing Cages and Animation]] · [[Retargeting Animations Between Rigs]] · [[Replication and Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · Characters and Humanoids · [[Rigging in Blender]] · HumanoidDescription and Outfit Systems · Avatar Body Types and Scale in Gameplay · Avatars and UGC Start Here · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Voxel Characters - Proportions Joints and Rigging]] · [[Characters and Humanoids]] · [[3D Importer Settings Reference]] · [[Rigs and Joints]] · [[Importing Models and Rigs]] · [[Bones and Skinned Meshes]] · [[Creature Rig Conventions]] · [[Blender Armature and Bone Roll Conventions]] · [[Enemy and NPC Animation]] · [[Animation Data from Blender to Roblox]]
<!-- related:end -->
