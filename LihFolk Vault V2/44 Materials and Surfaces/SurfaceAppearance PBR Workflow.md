---
tags: [materials, surfaceappearance, pbr, workflow, pipeline, textures, meshpart, type/guide, area/materials, level/intermediate, api/SurfaceAppearance, area/modeling]
---
# SurfaceAppearance PBR Workflow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Re-importing a mesh per scene -> Import once; copy MeshParts; clone templates
> - Avoid: Mesh exported without tangents -> Re-export with tangents
> - Avoid: Judging assets in an unlit or default room -> Look-dev room with game lighting
> - Texel budget and map list decided per asset class before painting.
> - One suffix scheme; normal maps OpenGL; meshes exported with tangents.
> - Import checked: every SurfaceAppearance has the expected maps.
>
> Cost: TL;DR ~150 tok · whole note ~5.2k tok. Read more: ## 4. Import: let the importer do the wiring · ## 7. Runtime cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The map-by-map facts about `SurfaceAppearance` (what each map means, colour spaces, AlphaMode, baking in Blender) are already in [[Texturing and PBR Baking]] and [[Materials MaterialVariants and SurfaceAppearance]]. This note is about the **workflow around them**: how to size a texture set before you paint it, how assets travel from the texturing tool into Studio without hand-pasting ids, how to keep one source of truth so instancing works, how to build a look-development room that tells the truth, how to audit a place full of PBR meshes, and how to handle the runtime cases (generated looks, [[pixel art]], tint-driven variants). It is written for a small team that will import hundreds of assets, not one hero prop.

## 1. The shape of the pipeline

```
Plan (texel budget, map list)  ->  Author (Blender / Substance / CC0 source)
   ->  Export (named files, correct convention)  ->  Import (3D Importer or manual)
   ->  Template (one SurfaceAppearance per look, stored once)
   ->  Place (clone templates onto MeshParts)  ->  Audit (script)  ->  Look-dev check
```

Every step has one job. The two that teams skip are **Template** and **Audit**, and they are the two that decide whether your place batches well and whether a re-upload six months later takes ten minutes or two days.

## 2. Plan: budget before you paint

### Texel budget from the docs

Roblox docs (as of October 2026, texture specifications) give a PBR budget of "256x256 for every 2x2x2 unit space", stepping up to the next size when larger:

| Object bounding size (studs) | Docs guideline |
|---|---|
| 1 x 1 x 1 | 64 x 64 to 128 x 128 |
| 2 x 2 x 2 | 256 x 256 (also the maximum for non-albedo maps on rigid accessories) |
| 4 x 4 x 4 | 512 x 512 |
| 8 x 8 x 8 | 1024 x 1024 (listed as the maximum for this budget) |

The same page says Roblox supports texture resolutions up to 4096 x 4096 and, in its UV section, "up to 1024x1024 pixel spaces for texture maps". Read these together as: **the uploader accepts 4K, the guidance for in-world PBR maps tops out at 1024.** If you believe a 2048 map is justified (a huge hero statue the camera circles), test it on a low-memory phone first; the docs do not promise how such a map is downsampled on low-end devices.

### Map list per asset class

Decide which maps an asset class gets before anyone paints. Every map you skip is a texture nobody downloads.

| Asset class | Colour | Normal | Roughness | Metalness | Emissive |
|---|---|---|---|---|---|
| Stylised prop, flat paint | yes | no | no (leave the slot blank) | no | no |
| Stylised prop with bevels | yes | yes | no | no | no |
| Realistic prop, non-metal | yes | yes | yes | no | no |
| Weapon or armour with metal parts | yes | yes | yes | yes | optional |
| Sign, screen, lantern | yes | optional | optional | no | yes |
| Foliage card | yes (alpha) | optional | no | no | no |

Rule of thumb: roughness and metalness can usually be half the resolution of colour with no visible loss; normal maps lose detail fastest when downscaled, so keep them at colour resolution when they carry the asset's identity.

## 3. Author and export: conventions that save hours

### File naming

Pick one suffix scheme and enforce it in tools. Roblox's own character import guide uses `_ALB`, `_MTL`, `_NOR`, `_RGH` (Roblox docs). Poly Haven's CC0 sets use `_diff`, `_nor_gl`, `_rough`, `_metal`. Either works; mixing them across a project does not.

A scheme that sorts well: `<AssetName>_<Map>_<Size>.png`, for example `CrateOak_Color_512.png`, `CrateOak_Normal_512.png`, `CrateOak_Rough_256.png`.

### Export checks

- **Normal maps: OpenGL, tangent space.** The docs are explicit that world-space and object-space normal maps are not supported, and the `SurfaceAppearance` reference adds that **meshes must include tangent data**. If a mesh arrives without tangents (some generators and older exporters drop them), the normal map shades wrongly in ways that look like a bad bake. Re-export with tangents before you re-bake anything ([[Normal Maps and Detail Baking]]).
- **One UV set.** Bake everything to the UV channel you export as the first set (rule of thumb; Roblox MeshParts render one UV set for textures, and a second channel exported from Blender is not used for SurfaceAppearance as far as the docs describe).
- **Straight alpha** for any colour map whose alpha matters (TintMask, Transparency).
- **Grayscale data maps as single-channel 8-bit**, which matches the spec's "Single Channel Grayscale (8-bit)". RGB copies work but waste upload bandwidth and invite channel mistakes.

## 4. Import: let the importer do the wiring

The 3D Importer's full-release announcement lists automatic SurfaceAppearance setup when PBR textures are present in the file, and the docs say `.fbx` and `.gltf` carry PBR textures while `.obj` does not. In practice:

| Source | What you get |
|---|---|
| `.glb` / `.gltf` with PBR materials linked | MeshParts with SurfaceAppearances created and maps uploaded |
| `.fbx` with textures linked in the material | Usually the same; check the importer's warnings |
| `.obj`, or textures not linked | MeshParts only; add SurfaceAppearances manually |

The docs do not list exactly when auto-setup fails, so make "open one imported SurfaceAppearance and check all four map slots" part of every import. See [[3D Importer Settings Reference]] for the importer options and [[Exporting and Validating Models for Roblox]] for pre-flight checks.

### Assigning maps in bulk

Map properties (`ColorMap`, `NormalMap`, ...) carry Plugin security: game scripts cannot write them. The command bar and plugins can (rule of thumb: the command bar runs with plugin-level permissions in Studio). That makes a bulk assignment script possible when you uploaded textures separately, for example through Open Cloud ([[Asset Upload Automation with Open Cloud]]).

```lua
--!strict
-- Command bar: build SurfaceAppearance templates from a table of uploaded ids.
-- Paste the table from your upload tool's output. Ids here are placeholders.
local ServerStorage = game:GetService("ServerStorage")

type MapSet = {
	color: string?,
	normal: string?,
	rough: string?,
	metal: string?,
	alpha: Enum.AlphaMode?,
}

local SETS: { [string]: MapSet } = {
	CrateOak = {
		color = "rbxassetid://0000000000",
		normal = "rbxassetid://0000000000",
		rough = "rbxassetid://0000000000",
	},
	LanternIron = {
		color = "rbxassetid://0000000000",
		normal = "rbxassetid://0000000000",
		rough = "rbxassetid://0000000000",
		metal = "rbxassetid://0000000000",
	},
}

local folder = ServerStorage:FindFirstChild("SurfaceLooks") or Instance.new("Folder")
folder.Name = "SurfaceLooks"
folder.Parent = ServerStorage

for name, set in SETS do
	local sa = folder:FindFirstChild(name) :: SurfaceAppearance?
	if not sa then
		local created = Instance.new("SurfaceAppearance")
		created.Name = name
		created.Parent = folder
		sa = created
	end
	assert(sa)
	if set.color then sa.ColorMapContent = Content.fromUri(set.color) end
	if set.normal then sa.NormalMapContent = Content.fromUri(set.normal) end
	if set.rough then sa.RoughnessMapContent = Content.fromUri(set.rough) end
	if set.metal then sa.MetalnessMapContent = Content.fromUri(set.metal) end
	sa.AlphaMode = set.alpha or Enum.AlphaMode.Overlay
end
print("templates:", #folder:GetChildren())
```

The script writes the `*Content` properties with `Content.fromUri`, which the reference lists as the current form; the older string properties (`ColorMap`, `NormalMap`) address the same slots and are what the audit below reads. Both carry Plugin security for writing (Roblox docs, as of October 2026). Wrap command bar edits in a `ChangeHistoryService` recording if your team relies on undo ([[Command Bar and Studio Scripting]]).

## 5. Template: one source per look

This is the step that decides batching. Roblox docs (summarised in [[Materials MaterialVariants and SurfaceAppearance]]) say identical MeshParts instance only when their SurfaceAppearances are identical. Re-importing the same crate ten times creates ten uploads with ten sets of asset ids: pixel-identical, but not identical to the engine.

Rules:

1. **Every look exists once**, as a template `SurfaceAppearance` in a `SurfaceLooks` folder (`ServerStorage` for edit-time use; `ReplicatedStorage` if clients clone them at runtime).
2. **MeshParts receive clones** of the template, never fresh imports.
3. **Re-uploads update the template**, then a script re-clones it onto every user. Because every user was a clone, you can find them by comparing map ids.
4. **Meshes share too.** Instancing needs the same mesh and the same appearance. Import a crate mesh once and copy the MeshPart, rather than importing the crate per scene.

```lua
--!strict
-- Command bar: re-apply a template to every MeshPart whose SurfaceAppearance
-- matches the template's old colour map id. Run after re-uploading a texture.
local ServerStorage = game:GetService("ServerStorage")

local TEMPLATE_NAME = "CrateOak"
local OLD_COLOR_ID = "rbxassetid://0000000000" -- the id being replaced

local template = ServerStorage.SurfaceLooks:FindFirstChild(TEMPLATE_NAME) :: SurfaceAppearance
local count = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("SurfaceAppearance") and d.ColorMap == OLD_COLOR_ID then
		local parent = d.Parent
		local tint = d.Color
		local fresh = template:Clone()
		fresh.Name = "SurfaceAppearance"
		fresh.Color = tint -- keep per-instance tint
		fresh.Parent = parent
		d:Destroy()
		count += 1
	end
end
print(("re-applied %s to %d meshes"):format(TEMPLATE_NAME, count))
```

The tint question: whether two otherwise identical SurfaceAppearances with different `Color` values still instance together is not documented. If you rely on tint variety at scale (a forest of tinted rocks), measure draw calls in the MicroProfiler with tints equal and with tints varied ([[MicroProfiler Guide]], [[Rendering Performance]]).

## 6. Look-dev: a room that tells the truth

The docs warn that SurfaceAppearance appearance "depends on the user's device and graphics quality level" and that brightness and reflectivity differ between Studio and authoring tools such as Substance Painter. You need a place to judge assets that matches the game, not the authoring tool.

Build a **look-dev room** in a separate place (or a far corner of the game, streamed out):

- **Reference objects:** a matte grey sphere (colour 128, roughness 1), a chrome sphere (metal 1, roughness 0.05), a white card (sRGB 240), a black card (sRGB 30). If the grey sphere does not look mid-grey, the lighting is lying to you, not the texture.
- **Every lighting setup the asset will live in**, as switchable presets (store them as data: [[Stylized Lighting Recipes]] shows how). Lighting is selected with `Lighting.LightingStyle` (Realistic or Soft) and `PrioritizeLightingQuality` in current Studio; the older `Technology` property is deprecated and superseded by those (Roblox docs, as of October 2026). Check both styles if your game might change.
- **Matching skies.** Metals and glossy surfaces reflect the sky. CC0 HDRIs can be converted to six cube faces for a `Sky`; using the same HDRI as the Blender world and the Studio sky makes authoring-tool and Studio reflections far closer. Example: a partly cloudy daylight HDRI such as `kloofendal_38d_partly_cloudy_puresky` for an outdoor game.
- **Environment lighting values.** `Lighting.EnvironmentSpecularScale` and `EnvironmentDiffuseScale` both default to 0 (Roblox docs). At 0 specular, metalness has no effect. Set them to the game's real values in the look-dev room.
- **Quality levels.** Check at the lowest and highest graphics quality (Studio's rendering settings), and on one real phone.

A ten-minute look-dev pass catches the three most common PBR complaints: "metal looks like plastic" (environment specular 0 or dark albedo), "everything is shiny" (roughness through sRGB), and "it looked better in Substance" (authoring-tool lighting).

## 7. Runtime cases

### Changing looks during play

Game scripts can write `Color`, `AlphaMode`, `EmissiveStrength`, `EmissiveTint` and `ResampleMode`; the map properties are Plugin security (Roblox docs, `SurfaceAppearance` reference). So:

| Want | Do |
|---|---|
| Team or rarity colour | Write `Color` on a near-white or TintMask map |
| Glow pulse | Tween `EmissiveStrength` (large values clamp to white, per the docs) |
| Completely different texture | Clone a prepared template from `ReplicatedStorage` and destroy the old one |
| Damage states | Prepared templates per state (`Clean`, `Cracked`, `Broken`) swapped at thresholds |

### Generated looks: CreateSurfaceAppearanceAsync

`AssetService:CreateSurfaceAppearanceAsync(content)` builds a new SurfaceAppearance from `EditableImage` content for the keys `ColorMap`, `MetalnessMap`, `NormalMap`, `RoughnessMap` and `EmissiveMask` (Roblox docs, as of October 2026). Facts that shape its use:

- It yields and is not thread-safe.
- It currently accepts **only EditableImage content**, not asset ids.
- Maps **cannot be swapped** after creation.
- For metalness, roughness and emissive, only the red channel is read.
- `CreateEditableImage` returns `nil` if the device's editable memory budget is exhausted, so every caller needs a fallback.

That makes it a specialised tool: player-painted items, procedural patterns, previews in a customiser. It is not a way to stream normal content.

```lua
--!strict
-- Client: make a flat-colour SurfaceAppearance from a generated image, with a fallback.
local AssetService = game:GetService("AssetService")

local function makeSolidLook(color: Color3): SurfaceAppearance?
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(4, 4) })
	end)
	if not ok or image == nil then
		return nil -- budget exhausted or unsupported: caller keeps the old look
	end
	local img = image :: EditableImage
	img:DrawRectangle(Vector2.zero, img.Size, color, 0, Enum.ImageCombineType.Overwrite)
	local created, sa = pcall(function()
		return AssetService:CreateSurfaceAppearanceAsync({
			ColorMap = Content.fromObject(img),
		})
	end)
	if not created then
		warn("CreateSurfaceAppearanceAsync failed:", sa)
		return nil
	end
	return sa
end
```

Check the current `EditableImage` method signatures in the docs before shipping; this API family has changed during its beta and the exact `DrawRectangle` parameters are worth re-reading (flagged as not re-verified for this note).

### Pixel art: ResampleMode

`ResampleMode` has `Default` (bilinear filtering) and `Pixelated` (nearest-neighbour, "keeps sharp pixel edges") per the docs. Pixel-art or voxel-textured games should set `Pixelated` on their templates; otherwise a 32 x 32 texture becomes a blur. It is script-writable, so it can also be a settings toggle.

## 8. Audit: find the problems before players do

Run this in the command bar before every release. It reports duplicate looks that should be clones, metalness without environment specular, transparency mode with zero part transparency on soft-alpha assets (you have to judge which those are), and MeshParts that still carry a `TextureID` under a SurfaceAppearance.

```lua
--!strict
local Lighting = game:GetService("Lighting")

type Info = { count: number, example: Instance }
local looks: { [string]: Info } = {}
local metalUsers = 0
local transparencyZero = 0
local leftoverTextureId = 0

for _, d in workspace:GetDescendants() do
	if d:IsA("SurfaceAppearance") then
		local key = table.concat({ d.ColorMap, d.NormalMap, d.RoughnessMap, d.MetalnessMap }, "|")
		local info = looks[key]
		if info then
			info.count += 1
		else
			looks[key] = { count = 1, example = d }
		end
		if d.MetalnessMap ~= "" then
			metalUsers += 1
		end
		local part = d.Parent
		if part and part:IsA("MeshPart") then
			if d.AlphaMode == Enum.AlphaMode.Transparency and part.Transparency == 0 then
				transparencyZero += 1
			end
			if part.TextureID ~= "" then
				leftoverTextureId += 1
			end
		end
	end
end

local unique = 0
for _, info in looks do
	unique += 1
end
print(("unique looks: %d"):format(unique))
print(("metal looks in use: %d, EnvironmentSpecularScale = %.2f"):format(metalUsers, Lighting.EnvironmentSpecularScale))
print(("Transparency-mode meshes at part Transparency 0 (hard cut-outs): %d"):format(transparencyZero))
print(("MeshParts with a TextureID hidden under a SurfaceAppearance: %d"):format(leftoverTextureId))
```

How to read it: if "unique looks" is close to the number of meshes, you are not sharing; group the near-duplicates by name and template them. A leftover `TextureID` is harmless to the look (the SurfaceAppearance overrides it, per the docs) but it is an extra image download for nothing; clear it.

## 9. SurfaceAppearance or something else?

| Need | Best tool | Note |
|---|---|---|
| UV-mapped unique prop | SurfaceAppearance | This note |
| Large tiling surfaces on parts | MaterialVariant | [[MaterialService and Custom Materials]] |
| A kit of many meshes | One SurfaceAppearance on a trim sheet | [[Trim Sheets Atlases and Vertex Colors]], [[Tiling Trim Sheets and Decal Tricks]] |
| Flat stylised colour | `MeshPart.Color`, no texture | Zero texture memory |
| Detail on a flat Part face | Decal or Texture (now with PBR map properties) | [[Tiling Trim Sheets and Decal Tricks]] |
| Terrain | MaterialVariant override or Expanded Terrain | [[Terrain Materials and Painting]] |

Nuance: a SurfaceAppearance on a mesh that only needs flat colour is the most common waste in imported kits. Generators and marketplace kits ship a 1024 colour map that is one flat swatch per island. Bake those swatches into `MeshPart.Color` (or vertex colours) and delete the texture.

## When not to use this workflow

- **One-off prototypes.** Hand-assigning ids is fine for ten assets. The template and audit steps earn their keep past about fifty assets or a second artist (rule of thumb).
- **Avatar items.** UGC has its own validation rules, texture limits and fees; follow [[UGC Avatar Items and Accessories]] instead.
- **Purely flat stylised games.** No PBR maps at all may be the right answer ([[Stylised vs Realistic Material Pipelines]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Re-importing a mesh per scene | Draw calls scale with prop count | Import once; copy MeshParts; clone templates |
| Mesh exported without tangents | Normal map shading looks wrong at every angle | Re-export with tangents |
| Judging assets in an unlit or default room | "Looked fine in Studio", wrong in game | Look-dev room with game lighting |
| `EnvironmentSpecularScale` left at 0 | Metal reads as plastic | Set real value; check in look-dev |
| 1024 maps on a 1-stud prop | Memory for detail nobody sees | Follow the docs' size table |
| Runtime generated looks without a fallback | Blank meshes on low-memory phones | Handle `nil` from `CreateEditableImage` |
| Pixel art with `Default` resampling | Blurry pixels | `ResampleMode = Pixelated` |

## Checklist

- [ ] Texel budget and map list decided per asset class before painting.
- [ ] One suffix scheme; normal maps OpenGL; meshes exported with tangents.
- [ ] Import checked: every SurfaceAppearance has the expected maps.
- [ ] Templates in a `SurfaceLooks` folder; meshes receive clones only.
- [ ] Re-upload procedure tested (script re-applies a template by old id).
- [ ] Look-dev room with reference spheres, game lighting presets and matching sky.
- [ ] Audit script run: unique looks, metal versus environment specular, leftover TextureIDs.
- [ ] Runtime look changes limited to writable properties or template swaps.

## See also

[[Materials and Surfaces Start Here]] · [[Texturing and PBR Baking]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Normal Maps and Detail Baking]] · [[Substance Painter and Texturing Tools]] · [[3D Importer Settings Reference]] · [[Exporting and Validating Models for Roblox]] · [[Asset Upload Automation with Open Cloud]] · [[Stylized Lighting Recipes]] · [[Rendering Performance]] · [[Baking Lighting and Detail into Textures]]

## Connected notes
<!-- auto-links:start -->
[[AI Material and Texture Generation]] · Hand-Painted and Stylized Texturing · Textures Decals and Texture Memory · Official Docs - Asset Creation · Skill - Roblox Asset Import · Texel Density
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Hand-Painted and Stylized Texturing]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Textures Decals and Texture Memory]] · [[Procedural Materials and Skies - Lessons]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Texel Density]]
<!-- related:end -->
