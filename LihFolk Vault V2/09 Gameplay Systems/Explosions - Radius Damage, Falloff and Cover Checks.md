---
tags: [gameplay, combat, explosions, aoe, falloff, cover, knockback, spatial-queries, type/guide, area/gameplay, level/advanced, api/Explosion, api/WorldRoot]
---
# Explosions - Radius Damage, Falloff and Cover Checks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Default `Explosion` on characters -> `DestroyJointRadiusPercent = 0`, own damage
> - Avoid: Damage per `Hit` event -> Group by model, deduplicate
> - Avoid: No cover check -> Raycasts to sample points, exposure fraction
> - Built-in `Explosion` used, if at all, only for push, with joint breaking off.
> - Custom pipeline: validate, query, group, distance, cover, falloff, damage core.
> - Falloff curve and inner radius chosen; VFX matches the radius.
>
> Cost: TL;DR ~160 tok · whole note ~2.6k tok. Read more: ## 1. The built-in `Explosion` and its traps · ## 2. Custom explosion pipeline (server) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox's `Explosion` instance is a 2008-era tool: it kills characters by breaking joints, pushes every unanchored part with the same pressure, ignores walls for damage, and its `Hit` event fires once per part, not per character. For a modern game you almost always want a **custom explosion**: a server function that finds targets in a radius, applies a falloff curve, checks cover with raycasts, routes damage through the damage core and applies knockback on the right machine. This note covers both the built-in instance's gotchas and the custom pipeline. Damage maths is in [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. The built-in `Explosion` and its traps

Reference: https://create.roblox.com/docs/reference/engine/classes/Explosion

| Property / event | Default behaviour | Trap |
|---|---|---|
| `BlastRadius` | Radius in studs | Damage is not distance-scaled; anything inside the joint radius dies |
| `DestroyJointRadiusPercent` | Fraction of the radius in which joints are broken | At the default, characters inside lose joints and die instantly, regardless of your health system |
| `BlastPressure` | Force applied to parts | Flings players, vehicles and loose props; can launch whole builds |
| `ExplosionType` | Whether terrain is cratered | Craters permanently change terrain |
| `Visible` | Shows the classic effect | Looks dated next to custom VFX |
| `Hit(part, distance)` | Fires for every part in range | Many events per character; no line-of-sight check |

If you use the instance at all, use it as a **physics push only**: `DestroyJointRadiusPercent = 0`, a modest `BlastPressure`, `Visible = false`, `ExplosionType = NoCraters` unless you want craters, and do damage yourself. Create it on the server; the server-created explosion's `Hit` fires on the server.

## 2. Custom explosion pipeline (server)

1. **Validate the source.** Who caused it (a grenade the server spawned, a rocket the server simulated, an exploder enemy dying)? Never accept a client's "explosion at P" without checking the client owns a weapon that could produce it, had ammo, and P is plausible ([[Server Authority and Validation]]).
2. **Query** candidates with `Workspace:GetPartBoundsInRadius(center, radius, overlapParams)` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius). Bounds-based is cheaper than exact geometry and good enough at explosion scale.
3. **Group by target**: map each part to its character or damageable model (`FindFirstAncestorOfClass("Model")` plus your own "Damageable" tag) and deduplicate.
4. **Distance per target**: from the centre to the closest of a few sample points (root, head, torso), not to the model pivot, or big targets take less damage than small ones.
5. **Cover check**: raycast from the centre (lifted slightly off the surface) to each sample point with an exclude filter (the target itself excluded so the ray reaches it, other characters excluded so players do not shield each other unless you want that). Exposure = fraction of sample points with a clear line.
6. **Falloff**: `damage = maxDamage * falloff(d / radius) * exposure`.
7. **Damage** through the single damage core with type `Explosion`, attacker = source owner, so armour, resistances, team rules, friendly fire and kill credit all apply ([[Combat Systems Architecture]]).
8. **Knockback** and **effects** (section 4 and 5).

```lua
--!strict
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

export type Blast = { center: Vector3, radius: number, maxDamage: number, innerRadius: number, owner: Player?, force: number }

local overlap = OverlapParams.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function falloff(t: number, inner: number): number
	if t <= inner then return 1 end
	local x = math.clamp((t - inner) / (1 - inner), 0, 1)
	return (1 - x) * (1 - x) -- quadratic: punchy centre, soft edge
end

local function samplePoints(model: Model): { Vector3 }
	local pts = {}
	for _, name in { "HumanoidRootPart", "Head", "UpperTorso", "Torso" } do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then table.insert(pts, p.Position) end
	end
	if #pts == 0 then table.insert(pts, model:GetPivot().Position) end
	return pts
end

local function explode(b: Blast, apply: (Model, number, Vector3) -> ())
	local seen: { [Model]: boolean } = {}
	local origin = b.center + Vector3.new(0, 0.5, 0)
	local characters = CollectionService:GetTagged("Damageable")
	for _, part in Workspace:GetPartBoundsInRadius(b.center, b.radius, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and CollectionService:HasTag(model, "Damageable") then
			seen[model] = true
			local pts = samplePoints(model)
			rayParams.FilterDescendantsInstances = characters -- other bodies do not block
			local clearCount, nearest = 0, math.huge
			for _, p in pts do
				nearest = math.min(nearest, (p - b.center).Magnitude)
				if not Workspace:Raycast(origin, p - origin, rayParams) then
					clearCount += 1
				end
			end
			local exposure = clearCount / #pts
			if exposure > 0 and nearest <= b.radius then
				local dmg = b.maxDamage * falloff(nearest / b.radius, b.innerRadius / b.radius) * exposure
				apply(model, dmg, (pts[1] - b.center))
			end
		end
	end
end

return explode
```

Tag damageable models (`Damageable`) when characters spawn and NPCs are created; the exclude list in rays means a body standing between a target and the blast does not block, which most games prefer. If you want "human shields", remove characters from the filter and handle the target itself.

## 3. Falloff curves

| Curve | Formula (t = d / r) | Feel |
|---|---|---|
| Linear | `1 - t` | Predictable, slightly mushy |
| Quadratic | `(1 - t)^2` | Strong centre, forgiving edges (good default) |
| Inner radius plateau | 1 inside `inner`, then a curve | Guarantees full damage on direct hits |
| Minimum edge | `max(curve, 0.2)` inside radius | Edge still matters (chip on grenades) |

**Rule of thumb.** Show the actual radius in VFX: the visual blast should cover the damage radius closely, or players feel cheated by "invisible" damage. Telegraph thrown and timed explosives (beeps, ground decal of the radius on harder enemies' attacks).

Self-damage: decide explicitly. Rocket jumping is fun in some games; in others, reduce self-damage to 25 to 50% or zero.

## 4. Knockback on the right machine

Players own their characters, so the server **decides** knockback and the **owner applies** it ([[Combat Systems Architecture]] section 4, [[Network Ownership]]):
- Direction from the centre to the target, with an upward component; strength scaled by the same falloff.
- Players: `FireClient` with the velocity, client sets `AssemblyLinearVelocity` after switching out of grounded states.
- Server-owned NPCs and props: `BasePart:ApplyImpulse(dir * strength * assemblyMass)` on the server.
- Vehicles: impulse to the driver's client, or on the server if server-owned.
- Cap vertical launch; long uncontrolled flights out of the map become exploits and grief.

## 5. Effects, destruction and networking

- Send one **unreliable** effect event to nearby clients (position, radius, type), not per-target messages; clients play VFX, sound, camera shake scaled by their distance ([[Hit-Stop and Screen Shake Tuning by Numbers]], [[VFX Performance Budgets and Culling]]).
- Damage numbers and hit confirmations go reliably, per affected player.
- Destructible props: hand the blast to the destruction system ([[Destruction and Fracture]]); cap how many pieces one explosion can spawn.
- Chain reactions (barrels, exploder enemies): queue them with a short delay (0.05 to 0.15 s) per step instead of recursing in the same frame, which both looks better and prevents stack and frame spikes.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Default `Explosion` on characters | Instant deaths ignoring health and shields | `DestroyJointRadiusPercent = 0`, own damage |
| Damage per `Hit` event | Characters take 10 to 20x damage | Group by model, deduplicate |
| No cover check | Damage through walls | Raycasts to sample points, exposure fraction |
| Distance to pivot | Large enemies under-damaged | Nearest sample point |
| Server applies player knockback | Late, jittery launches | Owner applies |
| Client-reported explosions trusted | Remote nukes | Server-side source validation |
| Recursive chain reactions | Frame spikes | Queued with small delays |

## Checklist
- [ ] Built-in `Explosion` used, if at all, only for push, with joint breaking off.
- [ ] Custom pipeline: validate, query, group, distance, cover, falloff, damage core.
- [ ] Falloff curve and inner radius chosen; VFX matches the radius.
- [ ] Self-damage and friendly fire rules explicit.
- [ ] Knockback decided on the server, applied by owners; vertical cap.
- [ ] One unreliable effect event; chain reactions queued.

## See also
[[Combat Systems Architecture]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Destruction and Fracture]] · [[Hitboxes and Hit Detection]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]]

## Connected notes
<!-- auto-links:start -->
[[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]] · [[Physics Assemblies and Constraints]] · [[Particle Emitters In Depth]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Downed, Revive and Bleed-Out States]] · [[Grabs, Carries and Throws - Moving Players Safely]] · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Characters and Humanoids]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[NPC AI and Behaviour]]
<!-- related:end -->
