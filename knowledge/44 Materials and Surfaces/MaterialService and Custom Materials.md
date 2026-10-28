---
tags: [materials, materialservice, materialvariant, custom-materials, terrain, pbr, world-building]
---
# MaterialService and Custom Materials

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Script sets `MaterialVariant` without setting `Material` -> Set both (registry `apply`)
> - Avoid: Renaming a variant after use -> Rename via script that also rewrites parts; or never rename
> - Avoid: Variant parked outside `MaterialService` -> Keep live variants under `MaterialService`, themes elsewhere
> - Naming scheme written down; base material first; no zone names.
> - Every variant's base chosen for physics and sound behaviour.
> - Maps downscaled: 1024 for part variants, 512 for terrain; unused maps left blank.
>
> Read more (22 KB note): ## 3. Building a variant from a CC0 set · ## 5. Theme swaps: same names, different maps · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Materials MaterialVariants and SurfaceAppearance]] explains the three layers of surface appearance (built-in `Material`, `MaterialVariant`, `SurfaceAppearance`) and the override-slot trap that hurt one production game. This note assumes you know that and goes one level down: how `MaterialService` actually resolves a custom material, how to build and maintain a library of custom materials as a project asset (with the vault's own CC0 textures in [[CC0 Texture and HDRI Library]] as the raw material), how to swap whole material themes at runtime, what each variant really costs, and the failure modes you only meet once a place has a few hundred thousand parts.

## 1. How resolution really works

A part never points at a `MaterialVariant` instance. It stores two values: `BasePart.Material` (an enum) and `BasePart.MaterialVariant` (a string). The engine resolves the look from those two values every time it needs to. Roblox docs (as of October 2026) state the rules:

- A variant's **identity is its Name plus its BaseMaterial**. "Only one variant with a given name and BaseMaterial can be used." Two variants called `Moss` with base `Grass` collide; a `Moss` with base `Grass` and a `Moss` with base `Rock` are two different materials.
- **"MaterialVariant objects only work as descendants of MaterialService."** Descendants, not children: folders inside `MaterialService` are fine, and that is what makes theme folders possible (section 5).
- `MaterialService:GetMaterialVariant(material, name)` returns the effective variant for that pair, or `nil` if none exists.
- If no match is found, **the built-in material is used**. There is no error and no warning at runtime: the part silently looks like plain Grass or Rock.
- A name assigned to one of the per-material override properties (`GrassName`, `RockName` and 38 others) replaces that built-in material everywhere. Those properties are "Not Scriptable"; from code you use `SetBaseMaterialOverride(material, name)` and `GetBaseMaterialOverride(material)`.

Three consequences that are easy to miss:

1. **A part's `Material` must match the variant's `BaseMaterial`.** If a script sets `part.MaterialVariant = "MossyStone"` on a part whose `Material` is Plastic while `MossyStone` has base Slate, the lookup fails and the part stays Plastic. The Properties window hides this by setting `Material` for you when you pick a variant; scripts do not.
2. **The silent fallback is the main failure mode.** A missing variant does not look broken, it looks plain. Players never report it; your art just gets quietly worse. You need a check that fails loudly (section 6).
3. **Name collisions across imported models are real.** Creator Store material packs and models you insert bring their own variants. If two packs both define `GrassStylized` on base Grass, whichever one the engine picks wins for every part using that name. Prefix names per source.

## 2. Naming: the schema is the API

Because the name is the only link, treat variant names like function names in a public API. The docs suggest PascalCase with the base material first (`GrassWet`, `GrassDry`, `GrassBurned`). A slightly stricter scheme pays off in larger projects (rule of thumb):

`<Base><Surface><Variant>`, for example `SlateCliffMossy`, `WoodPlanksDockWorn`, `ConcreteFloorPainted`.

| Rule | Why |
|---|---|
| Base material first | Sorting in the Material Manager and Explorer groups by base, so collisions are visible |
| No zone or world names (`Forest`, `World3`) | Zones get renamed and reused; surfaces do not |
| Wear or mood as the last word | Theme swaps restyle by keeping the name and changing the maps |
| Never rename after use | Every part using the old name falls back silently; the docs warn you must reapply |
| Keep a written registry | A table in your project docs or a ModuleScript (section 6) lists every legal name |

If you must rename, do it with a script that rewrites `BasePart.MaterialVariant` across the place in the same edit, then run the audit from [[Materials MaterialVariants and SurfaceAppearance]].

## 3. Building a variant from a CC0 set

A typical CC0 PBR set (for example from Poly Haven) has `_diff`, `_nor_gl`, `_rough`, sometimes `_metal`, plus `_ao`, `_arm` and `_disp`. The library note gives the basic mapping. Here is the full production procedure, using `mossy_rock` as the example.

### 3.1 Pick the right resolution

Roblox docs (as of October 2026, texture specifications) say parts display "a 1024x1024 on an 8x8 stud face" and terrain displays "512x512 across 8x8 studs". The same page now says Roblox supports textures up to 4096 x 4096. Those statements do not conflict: the engine accepts large images, but the built-in materials are authored at 128 px per stud for parts and 64 px per stud for terrain, and your custom materials should sit next to them without looking sharper or blurrier.

Texel density for a variant is `image pixels / StudsPerTile`. Match it to the built-ins:

| Use | Target density (rule of thumb from the spec above) | 1024 image | 512 image |
|---|---|---|---|
| Part surfaces seen up close | about 128 px per stud | StudsPerTile 8 | StudsPerTile 4 |
| Terrain | about 64 px per stud | StudsPerTile 16 | StudsPerTile 8 |
| Large distant surfaces (cliffs, roofs) | 32 to 64 px per stud | StudsPerTile 16 to 32 | StudsPerTile 8 to 16 |

So downscale the 2K source to 1024 for part variants and 512 for terrain-only variants. Going from 2048 to 1024 cuts memory to a quarter ([[Textures Decals and Texture Memory]]: memory is pixels, not file size).

### 3.2 Pick StudsPerTile from real-world size

Poly Haven pages list each set's real-world dimensions (check the asset page). A common conversion is about 0.28 m per stud, based on a default avatar being roughly 5 studs tall (rule of thumb; Roblox avatars are not to real-world scale, so treat it as a starting point). A set captured at 2 m across becomes `2 / 0.28 = about 7` studs per tile. Then adjust by eye: Roblox characters have big heads and short legs, and real-scale cobbles often look like gravel next to them. Stylised games frequently push StudsPerTile up by 1.5 to 2 times so details read at avatar scale.

That tension is the real decision: matching density to the built-ins (3.1) and matching real-world size (3.2) give different numbers. Pick density for surfaces the camera gets close to, pick scale for anything with recognisable units (bricks, planks, tiles), because players instantly notice a brick that is as tall as their shin.

### 3.3 Convert and check the maps

| Source file | Variant slot | Check |
|---|---|---|
| `mossy_rock_diff_2k.jpg` | ColorMap | Remove baked lighting if the set has strong directional shadows ([[Baking Lighting and Detail into Textures]]) |
| `mossy_rock_nor_gl_2k.jpg` | NormalMap | OpenGL is what Roblox expects; never use `_nor_dx` |
| `mossy_rock_rough_2k.jpg` | RoughnessMap | Already single-channel data; keep it out of any sRGB conversion |
| `_metal_2k.jpg` (metal sets only) | MetalnessMap | Metals only; skip for rock, wood, ground |
| `_arm_2k.jpg` | none directly | Packed AO (R), roughness (G), metalness (B). If a set lacks a separate rough or metal file, split G and B into grayscale files |
| `_ao_2k.jpg` | none | Optional: multiply softly into the colour map before upload |
| `_disp_2k.jpg` | none | Roblox has no displacement. Use for Blender sculpting or to derive a stronger normal map |

Then: Material Manager (Window, 3D, Material), choose the base material first (it supplies physics; if you skip it, the base is Plastic), Create Material Variant, rename it immediately (before applying it anywhere), import each map, set StudsPerTile and Pattern.

### 3.4 Regular or Organic

`Enum.MaterialPattern` has two items (Roblox docs): **Regular**, "a material with an ordered, usually man-made pattern, such as brick or wood planks", and **Organic**, "a material with less repetition in its pattern, such as stone or dirt". The docs describe Organic as randomising output so tiling looks less uniform.

| Pattern | Use | Do not use for |
|---|---|---|
| Regular | Bricks, planks, tiles, panels, anything with straight lines or grout | Natural ground (the tile grid shows from a height) |
| Organic | Rock, dirt, sand, moss, gravel, bark | Anything with lines: Organic breaks grout lines and plank seams into a mess |

Nuance: Organic hides repetition but also blurs any feature larger than a fraction of a tile. A rock set with one big distinctive crack per tile will show cut-off cracks. Choose sets whose detail is evenly spread for Organic, and keep sets with hero features for Regular on small areas.

## 4. Physics and sound belong to the base material

The base material is not only a fallback. It supplies physics, and anything in your game that reads `Enum.Material` (footsteps through `Humanoid.FloorMaterial`, vehicle grip tables, particle puffs) sees the base, never the variant name.

Physics precedence (Roblox docs): the part's own `CustomPhysicalProperties`, then the custom material's, then the override material's, then the base material defaults. A variant's `CustomPhysicalProperties` defaults to "no explicit values", meaning it inherits the base.

Practical rules:

- **Choose the base for behaviour, not looks.** A "frozen wood" floor that should be slippery wants base Ice with a wood colour map, not base Wood with friction overrides you will forget about.
- **Footsteps follow the base.** If your sound table keys off `FloorMaterial`, a variant `SlateCliffMossy` sounds like Slate. That is usually right. When it is not, add an attribute on the part (`Surface = "Moss"`) and read it before falling back to the material.
- **Reference default values** for planning are on the docs page: Plastic density 0.7, friction 0.3; Ice friction 0.02 with friction weight 3; Rubber friction 1.5; Metal density 7.85 (Roblox docs, as of October 2026).

## 5. Theme swaps: same names, different maps

The docs call this "adaptive materials": parts store a name, so changing which variant answers to that name restyles everything at once. Two approaches are documented: keep collections of same-named variants and swap which collection sits under `MaterialService`, or create a variant with the same name as the one a model uses.

A theme layout that works:

```
MaterialService
  Active            (Folder: the only theme the engine sees)
ReplicatedStorage
  MaterialThemes
    Summer          (Folder of variants: GrassMeadow, SlateCliffMossy, WoodPlanksDock ...)
    Autumn          (same names, different maps)
    Winter          (same names, different maps)
```

```lua
--!strict
-- ThemeSwitcher (ModuleScript). Moves one theme folder's variants into MaterialService.
-- Every theme must define exactly the same Name + BaseMaterial pairs.
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThemeSwitcher = {}

local themes = ReplicatedStorage:WaitForChild("MaterialThemes")
local active = MaterialService:WaitForChild("Active")

local function key(v: MaterialVariant): string
	return v.BaseMaterial.Name .. "/" .. v.Name
end

-- Returns the set of keys a theme defines, for validation.
local function keysOf(folder: Instance): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("MaterialVariant") then
			out[key(d)] = true
		end
	end
	return out
end

-- Fails loudly if two themes do not define the same keys.
function ThemeSwitcher.validate(): boolean
	local reference: { [string]: boolean }? = nil
	local ok = true
	for _, theme in themes:GetChildren() do
		local k = keysOf(theme)
		if reference == nil then
			reference = k
		else
			for name in reference do
				if not k[name] then
					warn(("theme %s is missing %s"):format(theme.Name, name))
					ok = false
				end
			end
			for name in k do
				if not reference[name] then
					warn(("theme %s has extra %s"):format(theme.Name, name))
					ok = false
				end
			end
		end
	end
	return ok
end

function ThemeSwitcher.apply(themeName: string)
	local theme = themes:FindFirstChild(themeName)
	if not theme then
		warn("unknown material theme", themeName)
		return
	end
	-- Add the new variants first, then remove the old ones, so no frame resolves to nothing.
	local incoming = theme:Clone()
	local old = active:GetChildren()
	for _, v in incoming:GetChildren() do
		v.Parent = active
	end
	incoming:Destroy()
	for _, v in old do
		v:Destroy()
	end
end

return ThemeSwitcher
```

The order matters. If you destroy the old variants first, there is a moment where every themed part resolves to its base material, and on a slow device that can be a visible flash. Adding first, though, briefly puts two variants with the same key under `MaterialService`. The docs say only one can be used but do not say which wins during the overlap; in practice the swap completes inside one script resumption, so no frame should render the duplicate state, but test it in your place (unverified in the docs).

Server or client? `MaterialService` contents replicate like other services' contents (rule of thumb; confirm in your place by checking a client's Explorer during a test). Calling `apply` on the server changes the theme for everyone. Calling it from a LocalScript changes it only for that player, which is how you would do a per-player seasonal or accessibility theme. Do not do both: a client-side swap that the server later overwrites causes a confusing double flip.

Cost: the textures of every theme folder sitting in `ReplicatedStorage` are not necessarily loaded until something renders them, but the instances still replicate. Keep themes you will not show this session in `ServerStorage` and move them across when needed (rule of thumb).

## 6. A registry that fails loudly

Because a wrong name falls back silently, put the legal names in one ModuleScript and route every runtime material change through it.

```lua
--!strict
-- MaterialRegistry (ModuleScript in ReplicatedStorage).
local MaterialService = game:GetService("MaterialService")

export type Entry = { base: Enum.Material, name: string }

local Registry = {}

-- The only legal custom materials. Keep in sync with the Material Manager.
Registry.Entries = {
	SlateCliffMossy = { base = Enum.Material.Slate, name = "SlateCliffMossy" },
	WoodPlanksDockWorn = { base = Enum.Material.WoodPlanks, name = "WoodPlanksDockWorn" },
	GrassMeadow = { base = Enum.Material.Grass, name = "GrassMeadow" },
} :: { [string]: Entry }

-- Run once at startup on server and client. Returns the list of missing entries.
function Registry.check(): { string }
	local missing: { string } = {}
	for id, e in Registry.Entries do
		if MaterialService:GetMaterialVariant(e.base, e.name) == nil then
			table.insert(missing, id)
		end
	end
	if #missing > 0 then
		warn("MaterialRegistry: missing variants: " .. table.concat(missing, ", "))
	end
	return missing
end

-- Sets Material and MaterialVariant together so the lookup can succeed.
function Registry.apply(part: BasePart, id: string): boolean
	local e = Registry.Entries[id]
	if not e then
		warn("MaterialRegistry: unknown id", id)
		return false
	end
	part.Material = e.base
	part.MaterialVariant = e.name
	return true
end

function Registry.clear(part: BasePart, fallback: Enum.Material?)
	part.MaterialVariant = ""
	if fallback then
		part.Material = fallback
	end
end

return Registry
```

Call `Registry.check()` in your server bootstrap and in your client bootstrap. On the client it catches variants that failed to replicate or were left in `ServerStorage` by mistake. Hook the result into your error telemetry ([[Crash and Error Telemetry]]) so a broken publish shows up the same day.

## 7. What a variant costs

Each variant can reference four maps (colour, normal, roughness, metalness) plus an emissive mask. Each `TerrainDetail` child can reference its own four maps too, and a variant can have up to three (top, side, bottom), per the `TerrainDetail` docs. A fully detailed terrain override can therefore pull in twelve or more textures on its own.

| Variant shape | Textures (worst case) | At 1024 | At 512 |
|---|---|---|---|
| Part variant, colour + normal + roughness | 3 | 3 x 1024 | 3 x 512 |
| Part variant with metalness | 4 | 4 x 1024 | 4 x 512 |
| Terrain override with 3 TerrainDetails, 4 maps each | 12 (plus the variant's own maps if set) | 12 x 1024 | 12 x 512 |

Rules of thumb that follow:

- **Skip maps that carry nothing.** No metalness on rock. Many terrain side faces need only colour and normal.
- **Share maps between faces.** A top and side detail can reuse the same normal map; an unchanged asset id is one texture in memory.
- **Count your variants per zone, not per place.** Memory grows with what is in view and streamed in; a forest zone with eight variants and a desert zone with eight others rarely coexist on screen ([[Memory Budgets and Leaks]]).
- **Legacy materials plus variants is slower.** The `MaterialService` docs warn that mixing legacy terrain materials with MaterialVariants carries a performance penalty and recommend migrating to the 2022 materials. If an old place still uses the legacy set, budget for that or migrate before adding many variants.
- **Metalness needs environment specular.** Variant and SurfaceAppearance docs both note metalness "has no effect when `Lighting.EnvironmentSpecularScale` is 0" (and its default is 0). If your metal variants look like grey plastic, check that property before re-authoring maps.

## 8. Shipping variants with models and packages

The docs give the rules for reuse:

- Models distributed through the Creator Store should include their `MaterialVariant` instances; after inserting such a model, copy its variants into `MaterialService` yourself.
- For packages, place the package itself in `MaterialService`.
- The Creator Store's **Materials** category holds "material packs" that contain only `MaterialVariant`, `TerrainDetail`, `Folder` and `Model` instances.

The nuance: a material pack is a dependency like any library. Inserting a pack can bring variants whose names collide with yours (section 1), and updating a pack can change the look of every part using its names. Copy third-party variants, rename them with your prefix, and point your parts at your copies. Also check toolbox safety rules in [[Creator Store and Toolbox Safety]]: a "material pack" model should contain no scripts at all; if it does, delete it.

## 9. Generated materials

Studio's Material Generator creates variants from a text prompt, with a Studs Per Tile slider that previews on selected parts and an Organic toggle (Roblox docs). It is fast for prototypes. For production, generated variants have the same costs as any other, and their maps are usually 1024 colour plus derived normal and roughness. See [[AI Material and Texture Generation]] for when generated materials are good enough and how to clean them up.

## When not to use custom materials

- **Stylised flat-shaded games.** SmoothPlastic plus colour is free and consistent. A custom variant on a few hero surfaces is fine; a variant on everything is a texture budget you do not need ([[Stylised vs Realistic Material Pipelines]]).
- **Unique props.** Anything that needs UV-mapped detail belongs in a `SurfaceAppearance` ([[SurfaceAppearance PBR Workflow]]).
- **When the built-in material is close enough.** The docs note that custom materials "can't look exactly like base materials" because base materials use a different shader. If you only want a slightly different stone, try `Color` on the built-in first.
- **Per-instance runtime looks.** Map properties are Plugin security; game scripts can only switch names or swap theme folders.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Script sets `MaterialVariant` without setting `Material` | Part stays plain | Set both (registry `apply`) |
| Renaming a variant after use | Parts quietly revert to base | Rename via script that also rewrites parts; or never rename |
| Variant parked outside `MaterialService` | Never resolves | Keep live variants under `MaterialService`, themes elsewhere |
| 2K maps uploaded as-is | Four times the memory for no visible gain | 1024 for parts, 512 for terrain |
| Organic pattern on bricks or planks | Broken grout lines | Regular for anything with lines |
| Metal variant looks like plastic | `EnvironmentSpecularScale` is 0 | Raise it, or accept non-metal look |
| Two packs define the same name and base | One silently restyles the other's parts | Prefix names per source |
| Theme swap destroys old variants first | One-frame flash of base materials | Add new, then remove old |

## Checklist

- [ ] Naming scheme written down; base material first; no zone names.
- [ ] Every variant's base chosen for physics and sound behaviour.
- [ ] Maps downscaled: 1024 for part variants, 512 for terrain; unused maps left blank.
- [ ] StudsPerTile set from density or real-world size, checked next to an avatar.
- [ ] Regular for patterned, Organic for natural surfaces.
- [ ] Registry ModuleScript lists every legal variant; `check()` runs on server and client.
- [ ] Theme folders define identical name and base pairs; `validate()` passes.
- [ ] Third-party variants copied and renamed; no scripts inside material packs.
- [ ] `EnvironmentSpecularScale` checked before judging metal variants.

## See also

[[Materials and Surfaces Start Here]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[CC0 Texture and HDRI Library]] · [[Textures Decals and Texture Memory]] · [[Terrain Materials and Painting]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Tiling Trim Sheets and Decal Tricks]] · [[SurfaceAppearance PBR Workflow]] · [[Stylised vs Realistic Material Pipelines]] · [[AI Material and Texture Generation]] · [[Lighting Technologies and Settings]] · [[Memory Budgets and Leaks]]

## Connected notes
<!-- auto-links:start -->
[[Links - Materials and MaterialVariants]] · [[Texturing and PBR Baking]] · [[The Gradient Palette Texture Workflow]] · [[Hand-Painted and Stylized Texturing]] · [[Substance Painter and Texturing Tools]] · [[Texel Density]]
<!-- auto-links:end -->
