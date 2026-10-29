---
tags: [avatars, scale, body-types, collision, hitboxes, avatar-settings, gameplay, fairness, type/guide, area/avatars, level/intermediate, api/Humanoid]
---
# Avatar Body Types and Scale in Gameplay

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hardcoding 5-stud heights -> Measure; cache per character
> - Avoid: Using `GetExtentsSize` for body height -> Use head and hip maths
> - Avoid: Raycasts hitting accessories -> Filter accessories or use hurtbox parts
> - Policy chosen per game type; Avatar Settings set and written down.
> - Collision mode chosen; touch detection target decided for Single Collider.
> - Character metrics measured on spawn, cached, used by camera and UI.
>
> Cost: TL;DR ~150 tok · whole note ~4.5k tok. Read more: ## 2. Avatar Settings: the engine-level controls · ## 4. Hitboxes: separate gameplay from visuals · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players arrive in your game with very different bodies: a classic blocky avatar about 5 studs tall, a realistic-proportion body about 6 to 6.5 studs (docs), slender and wide builds, tiny heads, huge heads, layered coats that double their visual width, and wings that fill a doorway. For a hangout that variety is the point. For a shooter, an obby or a fighting game it is a fairness and level-design problem: small avatars are harder to hit, tall avatars see over cover, and a 6-stud doorway built for a 5-stud avatar feels cramped for some and roomy for others.

This note covers the tools for handling that: Avatar Settings (the engine-level controls), measuring a character's real size in code, separating gameplay hitboxes from visuals, and level and camera design that tolerates variety. How scale affects animation playback is in [[Scale and Animation]]; the custom-character route is in [[Custom Characters and StarterCharacter]]. Facts marked "docs" are **Roblox docs (as of October 2026)**.

## 1. Where the variety comes from

| Source | Effect | Controlled by |
|---|---|---|
| Body scale values (`BodyHeightScale`, `BodyWidthScale`, `BodyDepthScale`, `HeadScale`, `BodyTypeScale`, `BodyProportionScale` NumberValues in the Humanoid) | Body part sizes; accessories rescale too when `AutomaticScalingEnabled` is true (docs) | Player avatar settings, `HumanoidDescription` scales, Avatar Settings |
| Body part assets (bundles) | Different meshes, proportions, hip height | Player choice, Avatar Settings Custom Parts |
| Rig type R6 versus R15 | R6 ignores body scale entirely (docs) | Avatar Settings avatar type |
| Rigid accessories | Visual size; can occlude | Avatar Settings accessory limits |
| Layered clothing | Visual bulk | Avatar Settings clothing limits |
| `Model:ScaleTo` | Uniform scale of the whole model, also scales animation root translation (measured in the reference project) | Your code |

The platform limits on avatar scales are commonly quoted as height 90 to 105 percent, width 70 to 100 percent, head 95 to 100 percent, with body type and proportion 0 to 1. Those height, width and head numbers come from a community wiki and were **not confirmed** against current docs; the docs only confirm that `BodyTypeScale` and `ProportionScale` clamp to 0 to 1. Whatever the platform range, **your game can apply values outside it** through descriptions or the scale values, so never assume player bodies are inside a range unless you enforce one.

## 2. Avatar Settings: the engine-level controls

Studio's Avatar Settings (File menu) set character rules for the whole experience (docs). The options that matter for gameplay:

| Area | Options (docs) | Gameplay use |
|---|---|---|
| Preset | Player Choice (avatars unmodified); Consistent Gameplay (all avatars one height with the same box collider) | Start from Consistent Gameplay for competitive games |
| Avatar type | R6, R15, or R15 and R6 | Lock to one rig if your animations need it |
| Body Scale | Player Choice, or Custom Scale: an absolute height in studs with minimum and maximum, keeping proportions | Normalises height without erasing identity |
| Body Build | Player Choice, or Custom Build limiting body type, height, width, head and proportions | Tighter control of silhouette |
| Body Appearance | Player Choice, or Custom Parts overriding body parts | Uniform bodies |
| Clothing Scale | Player Choice, or Custom Limit removing clothing beyond limit bounds | Stops giant costumes |
| Accessory Scale | Player Choice, or Custom Limit; limit method scales accessories to fit or removes them | Keeps hats and wings readable |
| Limit Bounds | Padding beyond the body's bounding box, 0 to 100 percent; 0 means inside the body box, 100 allows up to three times body size | Tuning knob for both clothing and accessories |
| Accessory Behaviors | Toggles for accessory VFX, sound and emissives | Turn off in horror or stealth games where glowing hats give players away |
| Collision | Default (OuterBox, from part bounding boxes); Single Collider (one fixed box with set length, width, depth, and a choice of whether hit and touch detection use avatar parts or the collider); Legacy (InnerBox, for backward compatibility) | The key fairness switch |
| Animation | Packs: Player Choice, Standard R15, Standard R6; Custom Clips per animation | Uniform movement readability |
| Abilities | Legacy Humanoid, or Character Controller Library with runtime-toggleable default abilities | Newer controller route; evaluate before switching |

The docs carry an important warning: these settings change game defaults that are not visible in the interface or accessible through scripts, which can make bugs hard to trace. Practical consequence: **write down your Avatar Settings in your project docs**, and when a character bug appears that you cannot reproduce in code, check them first. Use the Preview (it creates sample avatars under `Workspace.Camera`, removed during playtests and not saved) before committing.

### Single Collider in detail

Single Collider is the cleanest fairness tool: every player physically occupies the same box, whatever they look like. The option to route **hit and touch detection** to the collider rather than to avatar parts decides whether `Touched`-based systems (kill bricks, pickups, lava) see the uniform box or the visible body. For obbies, choose the collider: a player with a long tail should not die to lava their tail brushed. For games with visual hit feedback (a sword visibly passing through a hat), you may prefer avatar parts for touch and do your own hit detection anyway (section 4).

The collision enum names in the API are `AvatarSettingsCollisionMode` (Default, SingleCollider, Legacy) and, for legacy mode, `AvatarSettingsLegacyCollisionMode` with inner-box and R6-style colliders (docs). How the older "Inner Box / Outer Box" labels map exactly onto these was not fully spelled out in the docs read for this note.

## 3. Measuring the character in code

Never hardcode "the player is 5 studs tall". Measure.

```lua
--!strict
-- Shared: real size of a character, independent of how it was scaled.
export type CharacterMetrics = {
	height: number,     -- feet to top of head, studs
	eyeHeight: number,  -- feet to head centre, studs
	hipHeight: number,
	scale: number,      -- relative to a 5-stud classic baseline
}

local BASELINE_HEIGHT = 5 -- classic avatar, rule of thumb

local function measure(character: Model): CharacterMetrics?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not (humanoid and root and head) then
		return nil
	end

	-- For R15, the bottom of the root part sits HipHeight above the floor.
	local feetY: number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		feetY = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	else
		-- R6: legs are 2 studs tall below the torso (classic rig).
		feetY = root.Position.Y - root.Size.Y / 2 - 2
	end

	local headTop = head.Position.Y + head.Size.Y / 2
	local height = headTop - feetY
	return {
		height = height,
		eyeHeight = head.Position.Y - feetY,
		hipHeight = humanoid.HipHeight,
		scale = height / BASELINE_HEIGHT,
	}
end

return measure
```

Notes:

- **Measure in a neutral pose.** Positions come from the current animated pose; a crouch or emote changes them. Measure on spawn after `CharacterAppearanceLoaded`, cache the result, and re-measure when the description changes.
- **Do not use `GetExtentsSize` for height.** It includes accessories: a tall hat or a halo makes the player "taller" by two studs. That is right for doorway checks and wrong for camera and hit logic.
- **Body scale values versus model scale.** If you scale players with `Model:ScaleTo`, `Model:GetScale()` reports it; body scale values do not. The reference project scaled players about 1.6x through body scales (characters about 9 studs tall), where `GetScale()` stayed 1, so its systems had to read the body scale values instead (measured in the reference project; details in [[Custom Characters and StarterCharacter]]).

## 4. Hitboxes: separate gameplay from visuals

Visible body size varies; gameplay hit volume should usually not. The standard approach is a **gameplay hurtbox** derived from the root, independent of the avatar mesh.

| Approach | Fair? | Feels right? | Notes |
|---|---|---|---|
| Hit the visible body parts (raycasts against the character) | No: small avatars win | Yes, matches what you see | Fine for casual games |
| Single Collider with hit detection on the collider | Yes | Mostly; edges may not match a wide coat | Engine-level, zero code |
| Fixed hurtbox from the root (your own query) | Yes | Mostly; tune size to the average body | Full control, works with any rig |
| Scaled hurtbox (fixed shape times measured height) | Partly | Yes | Tall players are bigger targets: choose consciously |

A fixed server-side hurtbox query:

```lua
--!strict
-- Server: is a point (for example a sword tip or projectile) inside any player's hurtbox?
local Players = game:GetService("Players")

local HURTBOX_SIZE = Vector3.new(3, 5.5, 2) -- studs; same for everyone (rule of thumb sizes)
local HURTBOX_OFFSET = CFrame.new(0, -0.25, 0) -- relative to HumanoidRootPart

local function hurtboxCFrame(character: Model): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	-- Use only the yaw of the root so leaning animations do not tilt the box.
	local _, yaw, _ = root.CFrame:ToOrientation()
	return CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) * HURTBOX_OFFSET
end

local function pointInBox(point: Vector3, boxCFrame: CFrame, size: Vector3): boolean
	local localPoint = boxCFrame:PointToObjectSpace(point)
	local half = size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function playersHitAt(point: Vector3, ignore: Player?): { Player }
	local hits = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player ~= ignore and character then
			local cf = hurtboxCFrame(character)
			if cf and pointInBox(point, cf, HURTBOX_SIZE) then
				table.insert(hits, player)
			end
		end
	end
	return hits
end

return playersHitAt
```

For raycast-based weapons, keep using raycasts but **filter accessories out**. Accessory handles are parts; a raycast can hit a tall hat and count it as a headshot. Exclude them with a `RaycastParams` filter list or a collision group for accessory handles, or ray against invisible hurtbox parts welded to the root instead of the avatar. Whether accessory handles are queryable by default was **not verified** for this note; test with a large hat. See [[Hitboxes and Hit Detection]] and [[Raycasts Shapecasts and Spatial Queries]].

## 5. Level design for variable bodies

| Element | Classic 5-stud assumption | Robust rule (rule of thumb) |
|---|---|---|
| Door height | 6 studs | 8 to 9 studs, or the maximum height you allow plus 1.5 |
| Corridor width | 4 studs | 6 studs plus clothing bounds if not limited |
| Crawl spaces | 3 studs | Only with Single Collider or enforced height |
| Cover height | 4 studs hides a crouching player | Measure against the tallest allowed eye height |
| Ledge grabs and step heights | Fixed | Fixed by the Humanoid, not the body: a jump is the same height in studs for everyone |
| Kill bricks | Touch any part | Touch the collider (Single Collider) or the root only |

**Jumping does not scale with the body.** Jump height comes from `JumpHeight` or `JumpPower`, not body size, so a 1-stud-taller avatar has no jump advantage but does have a longer reach and a higher eye line. In obbies that means tall avatars see the next platform earlier and can sometimes clip a ledge with their head. Keep platform gaps and ceilings tested at the extremes ([[Obby and Platforming Level Design]]).

**Eye height is an advantage.** The default camera follows the head, so a tall avatar sees over cover a short one cannot. Competitive games either enforce height (Avatar Settings Custom Scale) or fix the camera subject at a standard height above the root.

## 6. Camera, tools and effects

- **Camera offsets scale with the character.** Over-the-shoulder offsets tuned on a 5-stud avatar sit inside the head of a 9-stud one. Multiply offsets by the measured `scale` (the reference project scaled camera offsets and shot framing by character scale, measured in the reference project). See [[Camera Systems]].
- **Tools and held items.** A Tool's grip is relative to the hand. A sword sized for classic avatars looks like a toothpick on a tall body and like a greatsword on a short one. Either accept it, or scale held models by the measured scale when equipped.
- **Melee ranges.** Arm length scales with the body; a fixed melee range feels short for tall players. Decide whether reach should be equal (fairness) or proportional (feel).
- **Animation fit.** Clips authored on one body clip through others. The reference project's arm-quality metrics were measured on a blocky dummy, and slimmer avatars cleared the body more easily than the metric said (measured in the reference project). Test combat animations on the widest body you allow.
- **Physics constants at scale.** If you scale everything up, physics should feel scaled too: the reference project computed a gravity of about 47.6 studs/s squared as the equivalent of 9.81 m/s squared for its roughly 8.7-stud avatar when tossing ragdolls, instead of using `workspace.Gravity` (measured in the reference project).

## 7. Choosing a policy

| Game type | Recommended policy (rule of thumb) |
|---|---|
| Hangout, roleplay, fashion | Player Choice everywhere; accessory limits only for extreme sizes |
| Obby | Player Choice visuals; Single Collider with touch on collider; generous doorways |
| Casual combat (PvE) | Player Choice; fixed hurtboxes; scale camera |
| Competitive PvP | Consistent Gameplay preset or Custom Scale with tight range; Single Collider; accessory VFX off; standard animations |
| Horror and stealth | Accessory VFX, sound and emissives off; limit bounds on huge items |
| Story games with fixed heroes | StarterCharacter or Custom Parts ([[Custom Characters and StarterCharacter]]) |

Whatever you choose, **tell players**. A short line in the settings or loading screen ("avatars are resized for fair play") avoids "my avatar is broken" reports, which is a real support cost.

## 8. When not to normalise

- **Identity-first games.** Shrinking everyone to one height in a fashion game removes the reason people came.
- **When the gameplay does not care.** A tycoon does not need fair hitboxes. Every limit you add is a visible change players notice.
- **Late in a live game.** Changing Avatar Settings after launch changes how existing players look and move; announce it like a balance change.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Hardcoding 5-stud heights | Cramped doors, wrong camera, broken UI anchors | Measure; cache per character |
| Using `GetExtentsSize` for body height | Hats count as height | Use head and hip maths |
| Raycasts hitting accessories | Hat headshots, unfair hits | Filter accessories or use hurtbox parts |
| Assuming body scale only within platform limits | Game code breaks on scaled NPCs or descriptions | Clamp or handle any value |
| Changing Avatar Settings without notes | Hidden default changes, untraceable bugs | Document settings |
| Kill bricks on avatar parts | Deaths from tails and capes | Collider touch or root-only checks |
| Camera offsets fixed | Camera inside large heads | Scale offsets |
| Testing only on a blocky dummy | Clipping and reach issues on real bodies | Test widest, tallest, smallest |

## Checklist

- [ ] Policy chosen per game type; Avatar Settings set and written down.
- [ ] Collision mode chosen; touch detection target decided for Single Collider.
- [ ] Character metrics measured on spawn, cached, used by camera and UI.
- [ ] Gameplay hit volume independent of accessories.
- [ ] Doors, corridors and cover tested at the tallest and widest allowed bodies.
- [ ] Camera offsets, melee reach and held items scaled or deliberately fixed.
- [ ] Combat animations checked on wide and slender bodies.
- [ ] Players told about any normalisation.

## See also

[[Avatars and UGC Start Here]] · [[Scale and Animation]] · [[Custom Characters and StarterCharacter]] · [[Characters and Humanoids]] · [[HumanoidDescription and Outfit Systems]] · [[Hitboxes and Hit Detection]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Collision and Physics Geometry]] · [[Camera Systems]] · [[Level Design for Roblox]] · [[Obby and Platforming Level Design]] · [[R15 Rig Anatomy and Attachments]] · [[Accessories and Armor That Follow Animation]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Characters for R15 and Custom Rigs]] · Official Docs - Characters and Animation · UGC Avatar Items and Accessories · Official Docs - Asset Creation · Proportion Exaggeration and Gameplay Distance · Layered Clothing Cages and Animation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Bundles Animation Packs and Emotes for Sale]] · [[Character Select and Class Systems with Different Rigs]] · [[Aim Assist and Generous Hitboxes]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[Layered Clothing Creation Workflow]] · [[UGC Pricing Limiteds and Marketplace Rules]]
<!-- related:end -->
