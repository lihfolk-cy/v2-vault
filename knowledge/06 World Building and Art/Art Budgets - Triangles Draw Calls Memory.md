---
tags: [world-building, art, performance, budgets, draw-calls, triangles, memory, instances]
---
# Art Budgets - Triangles Draw Calls Memory

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Optimising triangles while draw calls explode -> Reduce unique meshes/materials first
> - Avoid: Unique textures per prop -> Trim sheets, atlases, tints
> - Avoid: Everything casts shadows -> Small parts and neon off
> - Target device chosen and tested regularly.
> - Budgets written per prop, zone and hub.
> - Unique mesh count tracked; copies are clones.
>
> Read more (16 KB note): ## Measuring: an art audit script · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An art budget is a limit you set before building, so the game runs on the weakest device you care about. Roblox does not publish hard per-scene budgets; it publishes **mechanisms** (instancing rules, texture memory rules, shadow costs) and leaves the numbers to you. This note explains what actually costs frame time and memory for world art, gives starting budgets (marked as rules of thumb), and shows how to measure. Deep profiling technique lives in [[Rendering Performance]], [[MicroProfiler Guide]] and [[Memory Budgets and Leaks]].

## What costs what

| Cost | Driven by | Typical symptom |
|---|---|---|
| **Draw calls** | Number of distinct mesh + material/texture combinations visible; decals, textures, particles | CPU-side render time high, low FPS in busy views even with few triangles |
| **Triangles** | Visible geometry detail | GPU time high on phones with many complex meshes |
| **Overdraw / fill rate** | Transparent layers, particles, big neon/glass surfaces, alpha cards | FPS drops when looking at foliage, water, effects |
| **Shadows** | Shadow-casting lights and many small shadow casters | GPU time high; worse with Future lighting |
| **Texture memory** | Pixel count of unique images | Crashes or blurry textures on low-memory phones |
| **Instance count** | Every Instance, especially BaseParts | Load time, memory, replication, place size |
| **Physics** | Unanchored parts, complex collision | Physics step time ([[Physics Performance]]) |

The docs are explicit that "triangle count matters less than draw calls" (Roblox performance docs). Most Roblox worlds are draw-call or instance bound before they are triangle bound.

## Draw calls and instancing

Draw calls have "significant overhead" (Roblox docs). The engine merges identical meshes into one instanced draw when (Roblox docs):
- they share the same **MeshContent**, and
- their **SurfaceAppearances are identical**, or without SurfaceAppearances their **TextureContent** is identical, and
- their **materials** are identical when neither SurfaceAppearance nor TextureID exists.

Practical consequences:
- **Fewer unique meshes, more copies.** Ten tree meshes copied 500 times beat 100 unique trees.
- **Clone, do not re-import.** Re-imported copies get new ids and stop instancing. Import scenes piece by piece, not as one file (docs).
- **Share SurfaceAppearances and trim sheets** across kits.
- **Decals, Textures and particles batch poorly** (docs). A wall with 30 decals is 30 extra draws.
- **One mesh per colour** (for flat-coloured kits) instances across a kit because the same mesh with the same material and colour data batches; many unique per-object atlases do not.

Check the current count in Studio's render stats (Render Stats > Timing) or the client's Shift+F2 overlay (Roblox docs).

## Triangles

There is no published scene triangle budget. The only hard limit is **20,000 triangles per mesh** (modeling specs), and unions above 20,000 are simplified (solid modeling docs). Starting budgets (rules of thumb for a game targeting mid-range phones):

| Scope | Budget | Notes |
|---|---|---|
| Visible scene, phone | 300k to 600k triangles | Varies hugely by device and shader load |
| Visible scene, desktop | 1M+ | |
| Hero prop / centrepiece | 5k to 10k | One production game: 7k to 9k per hub hero piece |
| Repeated prop (lamp, crate) | 200 to 2k | Multiplied by every copy in view |
| Tree | 1k to 5k | Multiplied by the forest |
| Gate / landmark | 6k to 12k + LOD | One production game's gates |
| Enemy | 5k to 20k typical | That project's restyled enemies reached 10k to 42k, spread across 30 or so parts; acceptable for a few on screen, heavy for crowds |

Remember: **outline hulls double triangles** (an inverted hull duplicates the mesh). The same project kept outlines out of game meshes for exactly that reason.

`RenderFidelity = Automatic` lets distant meshes use lower detail (Highest under 250 studs, Medium to 500, Lowest beyond, per the docs). Setting many meshes to `Precise` is a common performance problem named in the docs.

SLIM (see [[Level of Detail and Model Streaming]]) can cut distant triangles dramatically; Roblox's SLIM doc quotes about 170,000 versus 2,600,000 triangles at far distance for an avatar crowd test.

## Overdraw

Transparent pixels are drawn once per layer. Budget them:
- Partially transparent objects near each other force overlapping pixels to render several times (docs). Remove layered transparencies.
- Alpha-card foliage, stacked water planes, glass walls, big particle systems and ForceField surfaces all add layers.
- Neon surfaces are not transparent, but large neon areas plus bloom raise post-processing cost and wash shapes out; one style study capped glow coverage at about 16 percent of an object's pixels for readability alone.

## Shadows and lights

From the docs: shadows are expensive with many shadow-casting lights or many small shadowed parts; quality drops at lower graphics levels and **shadows turn off entirely below quality level 4**. Mitigations: `CastShadow = false` on small parts (especially distant ones) and moving objects, `Light.Shadows = false` where not needed, limit range and angle, fewer lights, disable lights out of range.

Practice in one production game:
- Decor convention: tiny parts never cast shadows; Neon parts never cast shadows.
- A hub with 44 PointLights had **no shadows on any of them**.
- Lights were thinned with a tag (`ThinnedForPerf`) and disabled, not deleted, so they could be restored.
- Effects that only matter nearby (waterfalls, station effects) slept beyond a distance (650 studs).

Rule of thumb: at most a handful of shadow-casting local lights visible at once on phones; the sun does most of the shadow work.

## Texture memory

Covered in detail in [[Textures Decals and Texture Memory]]. The essentials: memory scales with pixels (1024 = 4x 512); file compression does not help; keep most images at 512 or below and minor ones under 256 (docs); share trim sheets; use tints.

## Instance count and place size

Instances cost memory on server and client, replication on join, and load time. One production game's history:
- The place reached about **2.36 million instances**, mostly archived imports, animation saves and old backups. Archiving them to files cut it to about 955k; removing dead weight (duplicated animation copies, unused models, dated backups) brought it to about 599k. A later cleanup deleted another 191k. See [[Case Study - Instance Cleanup and Place Size]] and [[Case Study - Cutting a Million Instances]].
- A per-feature budget kept ability kits under 2,500 instances each; the three that exceeded it (3,000 to 5,400) were flagged.
- A rebuilt hub came in at about 2,000 instances (1,231 parts, of which trees were about 970), versus 4,531 for the hand-built hub it replaced.

Starting budgets (rule of thumb):

| Scope | Instances |
|---|---|
| Hub | 2k to 10k |
| One zone fully dressed | 3k to 10k |
| One prop | under 50 (ideally a handful of meshes) |
| A voxel showcase piece | under 1,000 parts after merging |
| Whole place | a few hundred thousand at most; investigate anything in the millions |

Parts in voxel builds explode fastest. One style study's showcase objects held 1,000 to 3,000 cells that merged to 400 to 1,000 parts; anything repeated in the world should be far smaller, or baked into a few MeshParts. See [[Voxel Art - Studs Outlines and Style Kits]].

## Measuring: an art audit script

Run in the command bar (Edit or Play) to see where the budget goes in a folder:

```lua
--!strict
-- Art audit: instance counts, parts, unique meshes, shadow casters, transparency,
-- decals/textures and unique images under a root.
local function audit(root: Instance)
	local stats = {
		instances = 0, parts = 0, meshParts = 0, unions = 0,
		shadowCasters = 0, transparent = 0, decals = 0, lights = 0, shadowLights = 0,
	}
	local meshes: { [string]: number } = {}
	local images: { [string]: boolean } = {}

	for _, d in root:GetDescendants() do
		stats.instances += 1
		if d:IsA("BasePart") then
			stats.parts += 1
			if d.CastShadow and d.Transparency < 1 then stats.shadowCasters += 1 end
			if d.Transparency > 0 and d.Transparency < 1 then stats.transparent += 1 end
			if d:IsA("MeshPart") then
				stats.meshParts += 1
				meshes[d.MeshId] = (meshes[d.MeshId] or 0) + 1
				if d.TextureID ~= "" then images[d.TextureID] = true end
			elseif d:IsA("PartOperation") then
				stats.unions += 1
			end
		elseif d:IsA("Decal") then -- Texture inherits from Decal
			stats.decals += 1
			images[d.Texture] = true
		elseif d:IsA("SurfaceAppearance") then
			if d.ColorMap ~= "" then images[d.ColorMap] = true end
			if d.NormalMap ~= "" then images[d.NormalMap] = true end
		elseif d:IsA("Light") then
			stats.lights += 1
			if d.Shadows then stats.shadowLights += 1 end
		end
	end

	local uniqueMeshes, imageCount = 0, 0
	for _ in meshes do uniqueMeshes += 1 end
	for _ in images do imageCount += 1 end

	print(("[%s] instances %d | parts %d (meshes %d, unique %d, unions %d)"):format(
		root:GetFullName(), stats.instances, stats.parts, stats.meshParts, uniqueMeshes, stats.unions))
	print(("shadow casters %d | semi-transparent %d | decals/textures %d | unique images %d | lights %d (shadowed %d)"):format(
		stats.shadowCasters, stats.transparent, stats.decals, imageCount, stats.lights, stats.shadowLights))
end

audit(workspace)
```

Reading SurfaceAppearance map properties requires plugin-level access; run this from the command bar, not a game script. Use the numbers as trends between passes, then confirm with the MicroProfiler and render stats on a real phone.

## Setting budgets in a project

1. **Pick a target device** (a mid-range phone two or three years old) and test on it weekly.
2. **Measure an empty baseplate** on that device, then a representative scene, and derive how much headroom you have.
3. **Split the budget** between hub, zone, characters, VFX and UI. VFX is often the hidden overspender ([[VFX Design Playbook]]).
4. **Write budgets into the style guide** (per prop, per zone) and into review checklists.
5. **Audit after every art pass** with a script like the one above and compare to the last pass.
6. **Profile the worst views**, not the average: the hub at peak population, a boss fight with full VFX, the view across the widest zone.

## Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Optimising triangles while draw calls explode | No FPS gain | Reduce unique meshes/materials first |
| Unique textures per prop | Memory and draws | Trim sheets, atlases, tints |
| Everything casts shadows | GPU cost on phones | Small parts and neon off |
| Shadowed point lights everywhere | Big GPU cost | Shadows off on local lights |
| Re-importing copies | Instancing broken | Clone |
| Precise RenderFidelity | Heavy far geometry | Automatic |
| Backups left in the place | Load time, memory | Export to file, delete |
| Testing only on a desktop | Phone players suffer | Weekly phone tests |

## Checklist

- [ ] Target device chosen and tested regularly.
- [ ] Budgets written per prop, zone and hub.
- [ ] Unique mesh count tracked; copies are clones.
- [ ] Shadows only where they matter; local lights unshadowed by default.
- [ ] Texture sizes justified; trim sheets shared.
- [ ] Instance counts audited after each pass; backups out of the place.
- [ ] Worst-case views profiled.

## See also

- [[Rendering Performance]], [[Memory Budgets and Leaks]], [[Mobile and Low-End Optimization]], [[MicroProfiler Guide]], [[Developer Console and Stats]]
- [[Textures Decals and Texture Memory]], [[Level of Detail and Model Streaming]], [[Parts Unions and MeshParts]]
- [[Light Sources and Shadows]], [[Case Study - Instance Cleanup and Place Size]], [[Performance and Memory]]

## Nuances and edge cases

1. **Budgets are per view, not per place.** A place can hold a million triangles if any one view shows a fraction of them. Set budgets for what the camera sees from the busiest viewpoints (spawn, hub, boss arena), and check those views on the target device.
2. **The bottleneck differs by device.** High-end PCs are rarely limited by triangles; phones are often limited by draw calls, overdraw and memory. A change that does nothing on the developer's PC can double phone frame rate. Always measure on the lowest device you support, ideally a real phone several years old.
3. **Avatars are part of the budget.** In a 50-player server, avatars with layered clothing and accessories can cost more triangles, draw calls and texture memory than the environment around them. Reserve budget for avatars, scaled by the expected visible players, and test full servers.
4. **Instance count drives join time and memory more than triangles.** A map of 200,000 parts loads slower and uses more memory than the same look built from 5,000 well-made meshes. Track instance count as a first-class budget alongside triangles.
5. **Effects spend the same budget.** Particles, beams and transparent UI overlays add overdraw and draw calls. A world built exactly to budget leaves no room for combat effects. Leave headroom (rule of thumb: 20 to 30 percent) for gameplay VFX and UI.
6. **Budgets must survive content growth.** Each update adds zones and items; budgets that were met at launch erode quietly. Run an automated audit (instance count, unique meshes, textures, triangle estimates per zone) before every release and compare with the last one.
7. **Lighting technology and quality settings shift costs.** Shadows and lights cost differently across lighting modes and quality levels; a budget measured at one setting does not hold at another. Note the settings used whenever you record a measurement.
8. **Draw calls depend on reuse, not just count.** Many copies of the same mesh and material can be rendered efficiently; many unique meshes cannot. Ten trees made from one mesh are cheaper than ten different trees with the same total triangles.

The senior trade-off: art budgets protect performance and frustrate artists. Make them visible (an audit script, a budget sheet per zone), agree them before production, and allow trades (more triangles in a hero area paid for by simpler background), instead of enforcing one number everywhere.

## Common mistakes (advanced)

1. **Measuring only on a development PC.** Symptom: launch reviews complain about lag on phones. Fix: weekly measurements on a low-end phone.
2. **No headroom for effects and avatars.** Symptom: frame drops only in crowded fights. Fix: reserve budget and test full servers.
3. **Instance count ignored.** Symptom: slow joins although triangle counts are fine. Fix: track instances per zone.
4. **No per-release audit.** Symptom: performance degrades update by update without a clear cause. Fix: an automated audit compared release to release.
5. **One budget for every area.** Symptom: hero areas look poor while backgrounds waste budget. Fix: per-zone budgets with allowed trades.
6. **Unique meshes for small variations.** Symptom: draw calls far above the count of visible objects. Fix: reuse meshes and vary transforms and colours.

## Related decisions

- [[Rendering Performance]]: measuring draw calls and frame time.
- [[Mesh Optimization for Mobile]]: meeting triangle budgets in the modelling stage.
- [[VFX Performance Budgets and Culling]]: the effects share of the budget.
- [[Case Study - Instance Cleanup and Place Size]]: cutting instances in a real project.
- [[Avatar Body Types and Scale in Gameplay]]: avatars as a budget line.
- [[Modular Environment Kits]]: reuse that keeps draw calls low.
- [[QA Checklists Before Release]]: where the per-release audit belongs.
- [[Environment and Level Pipeline]]: building budgets into the art pipeline.

## Connected notes
<!-- auto-links:start -->
[[Draw Calls]] · [[Triangle Budget]] · [[Modeling in Blender for Roblox]] · [[Skill - Roblox Performance Audit]] · [[Materials and Surfaces Start Here]] · [[Texel Density]]
<!-- auto-links:end -->
