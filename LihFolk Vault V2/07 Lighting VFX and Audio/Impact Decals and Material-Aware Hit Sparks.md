---
tags: [vfx, impacts, decals, materials, raycast, pooling, shooters, sparks, performance, type/guide, area/vfx, level/intermediate]
---
# Impact Decals and Material-Aware Hit Sparks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Expecting `MaterialVariant` names from `RaycastResult.Material`.
> - Avoid: Creating a part and decal per shot, never cleaning up.
> - Avoid: Decals on unanchored parts left in world space.
> - Resolution order: attribute, variant, material, default.
> - Profile table in config; every common map material covered.
> - Sparks oriented by normal plus reflection; one pooled emitter per profile.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## The lookup table · ## Decals: the pooled ring buffer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

When a bullet, arrow or fist hits the world, players expect the world to answer in its own voice: sparks off metal, splinters off wood, dust off concrete, splashes off water, plus a mark that lingers. This note is a client-side system for both: a per-material lookup table driving sparks, sound and decals, and a pooled decal ring buffer that never grows the instance count. It covers world hits; hits on characters are covered in [[Gore Policy and Kid-Friendly Hit Feedback]].

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## Where the hit data comes from

A `RaycastResult` gives `Position`, `Normal`, `Instance` and `Material` (Roblox docs). That is everything this system needs.

Gotchas with `Material`:

- **It returns the base `Enum.Material`, not your custom `MaterialVariant` name** (Roblox docs describe `RaycastResult.Material` as the material at the hit point; variant names are not included). If your game has "MetalGrate" and "MetalShiny" variants of `Metal`, both look the same to the lookup. If you need the difference, read `hit.Instance.MaterialVariant` for parts, or tag parts with an attribute such as `ImpactKind`.
- **Terrain hits report the terrain voxel material** (`Grass`, `Sand`, `Water`...), and `Instance` is the `Terrain` object.
- **Meshes with textures** still report their part `Material`. A brick-textured `MeshPart` set to `Plastic` will spark like plastic. Fix the material, or tag it.

Resolution order (rule of thumb): attribute `ImpactKind` on the instance or an ancestor, then `MaterialVariant`, then `Material`, then a default.

## The lookup table

```lua
--!strict
export type ImpactProfile = {
	sparks: string,        -- name of a pooled emitter template
	sparkCount: number,
	sound: string,         -- name of a pooled sound template
	decal: string?,        -- texture key, nil for no mark (water, glass break handled elsewhere)
	decalSize: number,     -- studs
	decalLife: number,     -- seconds before fade
}

local DEFAULT: ImpactProfile = { sparks = "Dust", sparkCount = 6, sound = "ImpactGeneric", decal = "HoleGeneric", decalSize = 0.6, decalLife = 8 }

local byMaterial: {[Enum.Material]: ImpactProfile} = {
	[Enum.Material.Metal] = { sparks = "Sparks", sparkCount = 10, sound = "ImpactMetal", decal = "HoleMetal", decalSize = 0.45, decalLife = 10 },
	[Enum.Material.DiamondPlate] = { sparks = "Sparks", sparkCount = 10, sound = "ImpactMetal", decal = "HoleMetal", decalSize = 0.45, decalLife = 10 },
	[Enum.Material.Wood] = { sparks = "Splinters", sparkCount = 7, sound = "ImpactWood", decal = "HoleWood", decalSize = 0.55, decalLife = 10 },
	[Enum.Material.WoodPlanks] = { sparks = "Splinters", sparkCount = 7, sound = "ImpactWood", decal = "HoleWood", decalSize = 0.55, decalLife = 10 },
	[Enum.Material.Concrete] = { sparks = "Dust", sparkCount = 8, sound = "ImpactStone", decal = "HoleStone", decalSize = 0.6, decalLife = 10 },
	[Enum.Material.Grass] = { sparks = "Dirt", sparkCount = 6, sound = "ImpactDirt", decal = nil, decalSize = 0, decalLife = 0 },
	[Enum.Material.Water] = { sparks = "Splash", sparkCount = 12, sound = "ImpactWater", decal = nil, decalSize = 0, decalLife = 0 },
}

local function profileFor(result: RaycastResult): ImpactProfile
	local inst: Instance? = result.Instance
	while inst and inst ~= workspace do
		local kind = inst:GetAttribute("ImpactKind")
		if typeof(kind) == "string" and byKind[kind] then
			return byKind[kind]
		end
		inst = inst.Parent
	end
	return byMaterial[result.Material] or DEFAULT
end
```

`byKind` is a second table keyed by your attribute strings. Walking ancestors every hit is cheap for shallow models; cache per instance if your hierarchy is deep. Data like this belongs in a config module so designers can edit it ([[Data and Config Pipeline - Spreadsheets to Game]]).

## Sparks: orientation matters

- Emit along the **surface normal blended with the reflected shot direction**, not straight up. `reflect = dir - 2 * dir:Dot(normal) * normal`; aim the burst along `(normal + reflect).Unit`. Sparks that ignore the incoming direction look pasted on.
- Use one pooled emitter part per profile. Move it to the hit point, orient it, then `Emit(count)`. Do not create emitters per hit.
- Metal: bright, additive, fast, with gravity and short life. Stone and concrete: grey dust puff plus a few chips. Wood: brown splinters with tumble (`RotSpeed`). Water: upward splash column plus a ring.
- Melee impacts on the world follow the same table. For directional swings, bias the burst along the swing direction inside the attacker's frontal arc, consistent with the slash rule in [[VFX Design Playbook]].

## Decals: the pooled ring buffer

A bullet hole is a small anchored, non-colliding part (or attachment-carrying part) with a `Decal` on its front face, placed at `Position + Normal * 0.02` and oriented to the normal.

- **Ring buffer, fixed size.** Pre-create N hole parts (rule of thumb: 64 to 150 on desktop, fewer on phones). Each new impact takes the oldest slot. Instance count never grows, so a long firefight cannot leak.
- **Fade, then recycle.** Tween `Decal.Transparency` to 1 over the last second of `decalLife`.
- **Parenting to moving parts.** If the hit instance is unanchored (doors, vehicles), weld the hole part to it or skip the decal. A floating bullet hole where a car used to be is the most visible bug in this system.
- **Small surfaces.** Skip decals when the hit part's smallest dimension is smaller than the decal; it will overhang edges.
- **Glass and destructibles.** Route to their own handler (crack, shatter) and skip the generic decal.
- **Random rotation and slight size variance** (plus or minus 15 %) per hole stops visible tiling.
- **Z-fighting**: keep the offset along the normal (0.01 to 0.05 studs). See [[Tiling Trim Sheets and Decal Tricks]].

## Who renders what

Impact presentation is client-side. The shooter's client renders its own impacts immediately from its local ray (feel). Other clients render impacts from the server's validated shot broadcast, at reduced fidelity beyond a distance. The server never creates decals or sparks; it only validates and broadcasts ([[Genre Playbook - Shooters FPS and TPS]]).

Throttle: if more than a set number of impacts arrive in one frame (shotguns, miniguns), render sparks for all but decals for only some.

## Common mistakes

- **Expecting `MaterialVariant` names from `RaycastResult.Material`.** You get the base enum; tag or read the instance.
- **Creating a part and decal per shot, never cleaning up.** Memory grows until the server or phone struggles.
- **Decals on unanchored parts left in world space.** Floating holes.
- **Sparks pointing straight up regardless of shot direction.**
- **Server-side impact effects.** Replication cost for pure decoration.
- **Same profile for textured meshes with wrong materials.** Fix materials as part of art QA.

## Checklist

- [ ] Resolution order: attribute, variant, material, default.
- [ ] Profile table in config; every common map material covered.
- [ ] Sparks oriented by normal plus reflection; one pooled emitter per profile.
- [ ] Fixed-size decal ring buffer with fade; skips small, moving, glass and water surfaces.
- [ ] Shooter renders locally; others render from server broadcast with distance LOD.
- [ ] Per-frame impact throttle for high fire-rate weapons.

## See also

- [[Raycasts Shapecasts and Spatial Queries]]
- [[Projectiles and Ballistics]]
- [[Textures Decals and Texture Memory]]
- [[Particle Emitters In Depth]]
- [[VFX Performance Budgets and Culling]]
- [[Sound Design for Games]]

## Connected notes

[[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · Genre Playbook - Shooters FPS and TPS · [[Combat Sound Design and Feedback]]

<!-- related:start -->
## Related
[[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Readability and Value - Lessons from Blind Reviews]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Light Sources and Shadows]]
<!-- related:end -->
