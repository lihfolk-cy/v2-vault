---
tags: [world-building, art, materials, materialvariant, materialservice, surfaceappearance, pbr, type/guide, area/world, level/intermediate, api/SurfaceAppearance, api/MaterialVariant]
---
# Materials MaterialVariants and SurfaceAppearance

<!-- tldr:start -->
> [!tldr] TL;DR
> - TextureID wins over Material. A MeshPart with a TextureID ignores Material changes until the TextureID is cleared (measured).
> - Overrides are global, and so are terrain colours.
> - Dark colours kill textures. Keep albedo colours above about 0.06 to 0.085 luminance if the texture must read.
> - `Use2022Materials` confirmed for the place; colours matched under that set.
> - Override slots planned and documented; terrain materials chosen with global colours in mind.
> - MaterialVariants live in MaterialService with a stable naming convention.
>
> Cost: TL;DR ~180 tok · whole note ~4.1k tok. Read more: ## MaterialService and MaterialVariant · ## SurfaceAppearance · ## Gotchas collected · ## Checklist
<!-- tldr:end -->

Roblox has three layers of surface appearance, and mixing them up is the cause of most "why won't this change colour / texture" bugs:

1. **`BasePart.Material`**: the built-in material enum (Plastic, Wood, Slate, Neon, Glass...). It sets a tiling texture **and** physical properties (density, friction, elasticity) and footstep sounds.
2. **`MaterialVariant`**: a custom tiling material that lives in `MaterialService` and is selected by **name** on a part (`BasePart.MaterialVariant`). It can also **override** a built-in material place-wide, including Terrain.
3. **`SurfaceAppearance`**: a child of a `MeshPart` holding UV-mapped PBR maps (Color, Normal, Roughness, Metalness, Emissive mask). It replaces the mesh's texture and material look for that mesh.

Roblox's own summary: MaterialVariant is for reusable **tileable** materials; SurfaceAppearance is for **UV-mapped meshes** (Roblox docs). This note explains each layer, how they interact, what can change at runtime, and the global side effects that bit one production game.

## Built-in materials

Every BasePart has a `Material`. Notes that matter for art:

- **Use2022Materials.** `MaterialService.Use2022Materials` switches between the legacy material textures and the 2022 set. It is `Roblox Script Security` (not readable or settable by game scripts) and set in Studio (Material Manager / [[MaterialService]] properties). Check it before matching colours to a reference: the same Color looks different under each set. One production game's notes say both "the place uses legacy materials" and "overrides off, default 2022 textures"; verify in your own place rather than trusting memory.
- **The material texture multiplies with `Color`.** Very dark colours hide the texture completely. One production game measured that colours under about 0.06 luminance hid material textures, and lifted near-black surfaces to about 0.085 so stone and wood still read.
- **SmoothPlastic** is the flat, textureless choice for stylised art. **Plastic** has a faint noise. Stylised games often use SmoothPlastic everywhere and let lighting do the work.
- **Neon** renders self-lit and blooms. It does **not** emit light onto other surfaces; add a `PointLight` if you need spill. Neon parts should have `CastShadow = false`. Neon colour should be set a little darker and more saturated than you want it to look, because bloom lifts it (rule of thumb from studying several stylised games).
- **Glass** is transparent and reflective; behaviour varies with graphics quality. Combine with Transparency around 0.3 to 0.6.
- **[[ForceField]]** is animated and view-dependent; good for shields and holograms, poor for architecture.
- **Material also sets physics.** Ice is slippery, Plastic default. If you change material for looks, check whether walking or driving changes too. `CustomPhysicalProperties` on the part overrides it.

## MaterialService and MaterialVariant

### How a MaterialVariant is found

A part using a custom material stores only the variant's **name** in `BasePart.MaterialVariant`, plus a base `Material`. The engine looks up a `MaterialVariant` with that name (and matching base material) in `MaterialService`. Consequences from the docs:

- Variants used by packages and adaptive materials **must live in `MaterialService`**.
- **Renaming a variant breaks every part using it.** The parts keep the old name and fall back to the base material until you re-apply.
- **Same name, different look = restyle.** Create a variant with the same name (and base material) to restyle every part that uses it. This is the intended way to theme a model per world: "GrassWet", "GrassDry", "GrassBurned" as the docs suggest.

Setting `MaterialVariant` in the Properties window also sets the part's `Material` to the variant's base material automatically.

### MaterialVariant properties

From the API reference (October 2026):

| Property | Type | Script access | What it does |
|---|---|---|---|
| `BaseMaterial` | Enum.Material | Plugin security | Material it inherits physics and fallback from |
| `ColorMap`, `NormalMap`, `MetalnessMap`, `RoughnessMap` (+ `*Content`) | ContentId / Content | Plugin security | The texture maps; blank map stays blank |
| `EmissiveMaskContent` | Content | Plugin security | Emissive mask |
| `EmissiveStrength`, `EmissiveTint` | number, Color3 | Scriptable | Emissive intensity and colour |
| `StudsPerTile` | number | Scriptable | Tiling size in studs |
| `MaterialPattern` | Enum.MaterialPattern | Scriptable | `Regular` (plain tiling) or `Organic` (breaks up visible repetition) |
| `CustomPhysicalProperties` | PhysicalProperties | Scriptable | Physics of the material |
| `AlphaMode` | Enum.AlphaMode | Not browsable | Alpha handling (beta-gated at the time of writing) |

"Plugin security" means the **maps cannot be assigned by game scripts at runtime**. You author variants in Studio (Material Manager) and switch between them by name at runtime.

### Material overrides (place-wide)

"Material overrides apply one custom material to every instance of a base material in a place, including terrain that uses that base material" (Roblox docs). The per-material name properties (`GrassName`, `RockName`, `BrickName` and so on, 40 of them) are not scriptable; you set overrides in Studio. Scripts can call `MaterialService:SetBaseMaterialOverride(material, name)` and `GetBaseMaterialOverride(material)`.

Overrides are the **only** way to give Terrain a custom texture (besides Expanded Terrain's Terrain Details, below), and they are **global**. This is where one production game got stuck:

- It wanted a painted grass texture on terrain floors. The only free override slot was **Brick** (nothing else used Brick), so it overrode Brick with its grass variant and painted floors with Brick.
- Brick terrain then rendered as **solid 4-stud cubes** (measured; see [[Terrain Tools and Terrain API]]), so every floor showed 3 to 4-stud terraces.
- Every other smooth terrain material already had an override or was used by thousands of parts (Limestone on 2,868 parts, Glacier on 142), so there was no free smooth slot to move the texture to. The painted grass had to go.

Lesson: **plan override slots before you build.** List every built-in material your parts use, reserve a few you will never use on parts for terrain overrides, and keep that list in your project documentation.

### Physical property precedence

Highest to lowest (Roblox docs):
1. The part's own `CustomPhysicalProperties`.
2. The part's custom material's `CustomPhysicalProperties`.
3. The override material's custom physical properties.
4. The base material's defaults.

### Terrain Details and Expanded Terrain

A MaterialVariant can have `TerrainDetail` children for the **top, side and bottom** faces of terrain, each with its own maps, Studs Per Tile and pattern. "Expanded Terrain" is required to paint many distinct custom materials on terrain (Roblox docs). Treat it as newer functionality and test on your target devices before committing a whole map to it.

## SurfaceAppearance

### Maps

A `SurfaceAppearance` under a MeshPart supplies (Roblox docs):

| Map | Format | Notes |
|---|---|---|
| ColorMap (albedo) | RGB, optional alpha | Avoid baked lighting: it looks wrong under other lighting |
| NormalMap | RGB, **OpenGL tangent space** only | Flat = (127, 127, 255). DirectX maps look inverted |
| RoughnessMap | 8-bit grey | 0 glossy, 1 matte; Roblox suggests about +0.1 to offset Fresnel shine |
| MetalnessMap | 8-bit grey | Use 0 or 1 almost always |
| EmissiveMaskContent | 8-bit grey | Driven by `EmissiveStrength` and `EmissiveTint` |

The SurfaceAppearance **overrides the MeshPart's TextureID**. Texture maps "only change visual appearance and don't affect the geometry" (docs), so cut-outs come from alpha, not from the normal map.

### AlphaMode

| Mode | Behaviour (Roblox docs) | Use for |
|---|---|---|
| `Overlay` (default) | The ColorMap is drawn over `MeshPart.Color`; transparent pixels show the part colour | Tintable details on a coloured base: studs, decals, panel lines, skin tones |
| `Transparency` | Alpha cuts holes; does not show MeshPart.Color. With `MeshPart.Transparency = 0` you get hard cut-outs; set it to at least 0.02 for soft semi-transparency (0.01 may still behave opaque) | Foliage cards, fences, nets, lace |
| `TintMask` | Blends the tinted ColorMap over the untinted one, tint strength = alpha. Disable premultiplied alpha when exporting | Masked recolouring: one texture, team colours in the masked area |
| `Opaque` | Ignores alpha (beta at the time of writing) | Maps with junk alpha |

### Color tint

`SurfaceAppearance.Color` **multiplies** the ColorMap (final = texel x Color). Near-white grayscale maps tint the strongest. Tinting has no performance cost, so one map can serve many colours (Roblox docs). Under `Overlay`, the tint only affects the visible map, not the part colour underneath.

### Runtime changes

"In general, you can't modify SurfaceAppearance properties by scripts during a game" (Roblox docs), because the engine pre-processes them. The map properties are plugin-security. What you **can** do at runtime:
- Change `Color` (tint), `EmissiveStrength`, `EmissiveTint` and `AlphaMode`.
- **Swap whole SurfaceAppearances**: keep prepared ones in `ReplicatedStorage` and clone them in.
- `AssetService:CreateSurfaceAppearanceAsync` builds one from content (for example EditableImages); treat that as a specialised path.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Looks = ReplicatedStorage:WaitForChild("SurfaceLooks") -- folder of prepared SurfaceAppearances

-- Swap the PBR look of a MeshPart by cloning a prepared SurfaceAppearance.
local function setLook(part: MeshPart, lookName: string, tint: Color3?)
	local template = Looks:FindFirstChild(lookName)
	if not template or not template:IsA("SurfaceAppearance") then
		warn("missing look", lookName)
		return
	end
	local old = part:FindFirstChildOfClass("SurfaceAppearance")
	local new = template:Clone()
	if tint then
		new.Color = tint -- multiplies the ColorMap; free
	end
	new.Parent = part
	if old then
		old:Destroy()
	end
end
```

### Instancing

Identical MeshParts batch into one draw call only when their **SurfaceAppearances are identical** (Roblox docs). Ten copies of a crate with ten separately imported but pixel-identical SurfaceAppearances may not batch if their asset ids differ. Clone one SurfaceAppearance instead of re-importing. Different `Color` tints on otherwise identical SurfaceAppearances is a nuance the docs do not state; measure in the MicroProfiler if it matters to you.

## The stud overlay technique

A pattern from one production game that gives a classic LEGO-stud look to any surface with almost no cost:

- Author a **tiling stud texture** that is **mostly transparent**: only the stud bump highlights and shadows are opaque, and the rest of the image is clear.
- Put it in a `SurfaceAppearance` with `AlphaMode = Overlay`, so `MeshPart.Color` shows through everywhere except the stud shading.
- UV the meshes so **one texture tile = 8 studs** (in that project the image held 4 x 4 studs per 8 x 8-stud tile). Because the colour comes from `MeshPart.Color`, one stud map serves every colour.
- Build stylised objects as **one mesh per colour**, each with the same SurfaceAppearance. Every station in the lobby was rebuilt this way.
- For Parts (not meshes), the same image went into a `Texture` (`StudsPerTileU/V = 8`) on the **up-facing face only** of the hub ground, paving and bases. Walls, foliage, props, water and effects were left smooth on purpose.

A stronger variant we recommend: put the stud bumps in a **normal map** with a white ColorMap, so the studs respond to real light; only the lit-edge/shadow colour version is "baked". See [[Voxel Art - Studs Outlines and Style Kits]].

## Choosing the right layer

| Need | Use | Why |
|---|---|---|
| Large walls, floors, roads in a consistent material | Built-in Material or a MaterialVariant | Tiles automatically, no UVs |
| A custom stone used on 2,000 parts | MaterialVariant | One definition, restyle by name |
| Restyle every part of a material at once (and terrain) | Material override | Global; plan slots |
| A hand-painted or baked prop | SurfaceAppearance | UV-mapped PBR |
| A stylised kit with one look across many colours | One mesh per colour + one shared Overlay SurfaceAppearance | Recolour freely, instance well |
| Team colours on a detailed mesh | SurfaceAppearance `TintMask` or `Color` | One map, many tints |
| Leaves, fences | SurfaceAppearance `Transparency` (Transparency = 0 on the part) | Hard cut-outs |
| Change look during gameplay | Swap MaterialVariant names or clone SurfaceAppearances | Maps are not script-settable |

## A material audit script

Run in the command bar to find parts referencing variants that do not exist, and to count material usage (useful before choosing override slots):

```lua
--!strict
local MaterialService = game:GetService("MaterialService")

local known: { [string]: boolean } = {}
for _, v in MaterialService:GetDescendants() do
	if v:IsA("MaterialVariant") then
		known[v.Name] = true
	end
end

local missing: { [string]: number } = {}
local byMaterial: { [string]: number } = {}
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") then
		local m = p.Material.Name
		byMaterial[m] = (byMaterial[m] or 0) + 1
		local mv = p.MaterialVariant
		if mv ~= "" and not known[mv] then
			missing[mv] = (missing[mv] or 0) + 1
		end
	end
end

for name, n in missing do
	print(("MISSING variant %q used by %d parts"):format(name, n))
end
for m, n in byMaterial do
	print(("%-16s %d"):format(m, n))
end
```

Materials with a count of zero are candidates for terrain overrides.

## Gotchas collected

- **TextureID wins over Material.** A MeshPart with a TextureID ignores Material changes until the TextureID is cleared (measured).
- **Overrides are global, and so are terrain colours.** Terrain `MaterialColors` are per material for the whole place; to give two realms different grass, use two different terrain materials, not two colours.
- **Dark colours kill textures.** Keep albedo colours above about 0.06 to 0.085 luminance if the texture must read.
- **SurfaceAppearance needs a MeshPart.** It does nothing on a Part or Union.
- **SLIM regenerates UVs**; default material tiling may look slightly different at distance. The SLIM docs suggest SurfaceAppearance for important surfaces ([[Level of Detail and Model Streaming]]).
- **Normal map convention.** DirectX maps (green channel inverted) make dents look like bumps.
- **Premultiplied alpha** darkens TintMask edges; export straight alpha.

## Checklist

- [ ] `Use2022Materials` confirmed for the place; colours matched under that set.
- [ ] Override slots planned and documented; terrain materials chosen with global colours in mind.
- [ ] MaterialVariants live in MaterialService with a stable naming convention.
- [ ] SurfaceAppearances cloned from one source, not re-imported per copy.
- [ ] Normal maps OpenGL; roughness/metalness plausible (metal 0 or 1).
- [ ] Runtime look changes done by name swap or SurfaceAppearance clone.
- [ ] No near-black textured surfaces.

## See also

- [[Textures Decals and Texture Memory]], [[Parts Unions and MeshParts]], [[Modeling in Blender for Roblox]]
- [[Terrain Tools and Terrain API]], [[Voxel Art - Studs Outlines and Style Kits]], [[Environment Art Styles]]
- [[Lighting Technologies and Settings]], [[Art Budgets - Triangles Draw Calls Memory]], [[Rendering Performance]]

## Connected notes
<!-- auto-links:start -->
[[MaterialService and Custom Materials]] · SurfaceAppearance PBR Workflow · Texturing and PBR Baking · AI Material and Texture Generation · Substance Painter and Texturing Tools · Trim Sheets Atlases and Vertex Colors
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[SurfaceAppearance PBR Workflow]] · [[Texturing and PBR Baking]] · [[AI Material and Texture Generation]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Foliage Props and Scatter]]
<!-- related:end -->
