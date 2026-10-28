---
tags: [ai, materials, textures, materialvariant, surfaceappearance]
---
# AI Material and Texture Generation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using Texture Generator for a floor (it targets one mesh) or Material Generator for a character.
> - Avoid: Generating a variant per colour instead of one grayscale variant tinted by `Color`.
> - Avoid: Changing `Material` on palette-textured MeshParts and seeing no change.
> - Style decided before generating.
> - Studs Per Tile checked at close, gameplay and far distance.
> - Variants named for the project and stored where scripts expect them.
>
> Read more (14 KB note): ## 2. Texture Generator · ## 3. Production experience: the reference project · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has two AI surface tools that are easy to confuse:

- **Material Generator** makes a seamless, tiling material from a text prompt and saves it as a `MaterialVariant`. Use it for surfaces that repeat: floors, walls, rock, fabric.
- **Texture Generator** paints one specific mesh from a text or image prompt, taking the mesh's shape into account. Use it for a single prop or character.

Outside Roblox, general image models can also make tiling textures, and many texturing apps now ship AI features. This note explains each route, the settings that matter, how the output lands in Roblox, and the reference project's production experience, which was mostly negative for automated material generation and positive for a deterministic, reversible material pass.

Background on the engine side: [[Materials MaterialVariants and SurfaceAppearance]] and [[Textures Decals and Texture Memory]]. As of October 2026; verified against the Roblox Creator Hub pages for Material Generator and Texture Generator.

---

## 1. Material Generator

### What it does

From the Roblox docs: it is "designed to create material variants from text entries", and results appear within a few seconds of clicking Generate. Roblox's AI overview describes the output as seamless, tiling 2D images that can be saved as MaterialVariants.

### How to use it (Studio)

1. Open it from Window > 3D, or from Generate in the Material widget's picker.
2. Type keywords and click Generate. Every click gives different results, even for the same words.
3. Click a tile to see options and preview it on selected parts.
4. **Studs Per Tile** sets how large the pattern appears. **Organic** reduces visible repetition.
5. Pick a **Base Material** (it copies that material's physical properties: friction, density, footstep sounds), then **Save & Apply Variant**. The variant goes to the Material Manager.

It is also reachable as Assistant "quick styling" and as the Studio MCP tool `generate_material`, which external agents can call.

### Prompt tips from the docs

| Goal | Words to include |
|---|---|
| Close-up surface detail | "close up", "top down", "texture" |
| Simple repeating patterns | "simple", "pattern", "symmetrical", "flat" |
| Style | "photorealistic", "cartoon", "hand-drawn" |
| Tint later with part Color | "grayscale" |

The "grayscale" tip is the most useful one in practice. A grayscale variant can serve many colours, because a part's `Color` tints the material. One stone variant then covers sandstone, slate and basalt across your map, instead of one variant per colour.

### Choosing Studs Per Tile

Rule of thumb: match the real-world scale of the pattern to your character scale. A Roblox character is about 5 studs tall at default scale (the reference project scaled characters to 1.6x, about 9 studs, and had to scale tile sizes up with them).

| Surface | Starting Studs Per Tile (rule of thumb, at default character scale) |
|---|---|
| Fine fabric, sand | 2-4 |
| Bricks, cobbles | 4-8 |
| Rock faces, planks | 8-16 |
| Large terrain-like ground | 16-32 |

Check at three distances (close, gameplay, far). Repetition shows at far distance first; Organic helps, as does breaking the surface with props and decals.

---

## 2. Texture Generator

### What it does

From the Roblox docs (October 2026): it creates custom textures for a selected mesh from text or image prompts. It only works with a mesh selected.

| Mode | Output | Speed | How it is applied |
|---|---|---|---|
| Fast | 1K diffuse (colour only) | Under 30 seconds | A new texture id on the MeshPart |
| Quality | 4K PBR | Can take a couple of minutes | A `SurfaceAppearance` parented to the MeshPart |

Preview gives three images in about 10 seconds before you commit to a full generation. Reach it from the Model tab > Texture, from Assistant with `/generate_texture`, or through the Studio MCP server.

Early beta coverage (2024) quoted 1024x1024 textures and five full generations per day; the current docs describe Fast 1K and Quality 4K and do not publish a daily quota. Treat the old numbers as history.

### Settings and rules from the docs

- **View:** Manual (you orbit to choose the angle the model prioritises) or Automatic (the tool chooses; the docs say it "can fail"). For objects with a clear front (characters, animals, clothing), set a front view so the face gets the detail.
- **Multi-mesh models:** arrange the meshes as one body. Avoid scattered groups and avoid more than one identical mesh in one operation. Each MeshPart gets its own texture (and its own SurfaceAppearance in Quality mode).
- **Do not edit the asset while it generates.** The docs: editing before completion can make the process fail.
- **Undo** is Ctrl/Cmd+Z, but it gets complicated if you changed other things during generation. Back up first.
- **Prompting:** describe materials, colours, patterns and distinctive features. Image prompts act as a "style guide rather than an exact template". Do not describe geometry changes, the current texture, other scene objects, or reflectivity and transparency.
- **Best for** textures tied to the asset (a worn treasure chest). For tiled surfaces (floors, cobblestone) the docs point to Material Generator instead.

### Memory cost

A Quality result is a 4K PBR set on a `SurfaceAppearance`. Roblox downsamples textures on lower-end devices, but every unique 4K set still costs download and memory ([[Textures Decals and Texture Memory]]). Rule of thumb: Quality for hero props players see up close; Fast for background props; neither for things smaller than a hand on screen.

---

## 3. Production experience: the reference project

### Automated material generation failed

The reference project's agents called `generate_material` through the Studio MCP server during a map texture pass. Its notes record, more than once: "`generate_material` is unreliable (fails almost every job)". The project stopped using it. Two lessons:

- A generator that works when a person clicks it in the UI can behave differently when called as an automated job in bulk. If you plan to automate, run a pilot of 20 jobs and count successes before you build a pipeline on it.
- A material that succeeds once is not a pipeline. The team needed dozens of consistent materials; a source that fails most of the time cannot be scheduled.

### What worked instead: a deterministic, reversible material pass

The project gave every flat Plastic or SmoothPlastic surface a built-in Roblox material by category (stone to Slate or Rock, wood to Wood or WoodPlanks, metal to Metal or DiamondPlate, cloth to Fabric, ice to Glacier, charred surfaces to Basalt) plus one custom bone-white `MaterialVariant` based on Limestone. Every change stored the original values in attributes so the whole pass could be reverted with one call.

```lua
--!strict
-- Reversible material pass: store originals in attributes, apply by category.
local CATEGORY_MATERIAL: { [string]: Enum.Material } = {
	stone = Enum.Material.Slate,
	wood = Enum.Material.WoodPlanks,
	metal = Enum.Material.Metal,
	cloth = Enum.Material.Fabric,
	ice = Enum.Material.Glacier,
}

local MIN_LUMINANCE = 0.085 -- near-black colours hide material detail (measured in the reference project)

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function liftColor(c: Color3): Color3
	local l = luminance(c)
	if l >= MIN_LUMINANCE then
		return c
	end
	if l <= 0 then
		return Color3.new(MIN_LUMINANCE, MIN_LUMINANCE, MIN_LUMINANCE)
	end
	local k = MIN_LUMINANCE / l
	return Color3.new(math.min(c.R * k, 1), math.min(c.G * k, 1), math.min(c.B * k, 1))
end

local function apply(part: BasePart, category: string)
	local mat = CATEGORY_MATERIAL[category]
	if not mat or part:GetAttribute("PreTex_Material") ~= nil then
		return -- unknown category, or already processed (idempotent)
	end
	part:SetAttribute("PreTex_Material", part.Material.Name)
	part:SetAttribute("PreTex_Color", part.Color)
	if part:IsA("MeshPart") and part.TextureID ~= "" then
		-- A palette TextureID overrides the material look: clear it, remember it.
		part:SetAttribute("PreTex_TextureID", part.TextureID)
		part.TextureID = ""
	end
	part.Material = mat
	part.Color = liftColor(part.Color)
end

local function revert(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PreTex_Material") ~= nil then
			local name = d:GetAttribute("PreTex_Material") :: string
			d.Material = (Enum.Material :: any)[name]
			d.Color = d:GetAttribute("PreTex_Color") :: Color3
			local tex = d:GetAttribute("PreTex_TextureID")
			if d:IsA("MeshPart") and typeof(tex) == "string" then
				d.TextureID = tex
			end
			d:SetAttribute("PreTex_Material", nil)
			d:SetAttribute("PreTex_Color", nil)
			d:SetAttribute("PreTex_TextureID", nil)
		end
	end
end
```

Two measured gotchas from that pass:
- **MeshParts with a palette `TextureID` ignore Material changes** until the TextureID is cleared. Many low-poly kits colour meshes by UV-mapping faces onto a small palette image. The pass cleared the TextureID and set `Color` to the sampled swatch colour instead.
- **Near-black colours hide material textures** (below about 0.06 luminance, measured). The pass lifted them to about 0.085 so the material read.

Small foliage, flowers and mushrooms were deliberately left flat; materials on tiny objects only add noise.

### Where Assistant-saved materials go

In the reference project, variants created through Assistant landed in a folder named `AssistantMaterials` under `MaterialService`. Check where yours land before you script against them, and give them project-specific names so they never collide with built-in names.

### Legacy materials

The reference place had `MaterialService.Use2022Materials` off (legacy look). Generated variants are built on a base material; if your place uses legacy materials, preview generated results with the same setting your players will see.

---

## 4. External AI texture routes

General image generators can produce tiling textures when asked ("seamless tileable"), but most do not guarantee a true seam-free tile. Always check:

1. **Offset test.** Shift the image by half its width and height (wrap around). Seams appear as a cross in the middle. Fix with a clone or healing brush, or a "make tileable" filter in your image editor.
2. **Lighting baked in.** Generated textures often contain shadows and highlights from an imaginary light. On a PBR surface that double-lights. Flatten the albedo (reduce contrast in large shapes, keep small detail).
3. **Maps.** A colour image alone is not a PBR set. You need normal, roughness and (if used) metalness maps. Derive them in a texturing tool, or bake from geometry ([[Normal Maps and Detail Baking]]).
4. **Licence.** Check the generator's terms for commercial use on your plan (see [[Roblox Policies on AI-Generated Content]]).

Then build a `MaterialVariant` (ColorMap, NormalMap, RoughnessMap, MetalnessMap, StudsPerTile) or a `SurfaceAppearance` for a specific mesh. See [[Substance Painter and Texturing Tools]] and [[Hand-Painted and Stylized Texturing]].

### Style consistency beats realism

A stylised Roblox game with photoreal generated rock looks broken. The reference project's style rule was one look for all assets: flat colours, chunky shapes, SmoothPlastic on props, no textures or alpha cards on props, built-in materials for big surfaces. Generated materials that did not fit that look were rejected regardless of quality. Decide the style first ([[Environment Art Styles]]), then decide whether AI materials can serve it. For a flat-colour style the answer is often "only for ground and rock".

---

## 5. Decision table

| You need | Use | Notes |
|---|---|---|
| A tiling ground or wall material | Material Generator, grayscale, then tint | Save as a variant on a sensible base material |
| A unique look for one prop | Texture Generator, Fast for background, Quality for hero | Front view for faces |
| Hundreds of consistent surfaces | A scripted pass with built-in materials and a few hand-made variants | Reversible attributes |
| A painted stylised character | Hand-painted or texturing tool | AI as reference only |
| A PBR set from an external image | Image editor + texturing tool | Check tiling, flatten lighting, build all maps |
| Automated generation in an agent pipeline | Pilot first; expect failures | The reference project's MCP material jobs mostly failed |

## Common mistakes

- Using Texture Generator for a floor (it targets one mesh) or Material Generator for a character.
- Generating a variant per colour instead of one grayscale variant tinted by `Color`.
- Changing `Material` on palette-textured MeshParts and seeing no change.
- Very dark part colours that hide the material.
- Quality-mode 4K on dozens of small props.
- Editing a mesh while its texture generates.
- Bulk-automating a generator before measuring its success rate.

## Checklist

- [ ] Style decided before generating.
- [ ] Studs Per Tile checked at close, gameplay and far distance.
- [ ] Variants named for the project and stored where scripts expect them.
- [ ] Every scripted material change reversible through attributes.
- [ ] External textures offset-tested, lighting flattened, full map set built.
- [ ] Texture memory budget respected.

## See also
[[Materials MaterialVariants and SurfaceAppearance]] · [[Textures Decals and Texture Memory]] · [[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[Roblox Studio Assistant]] · [[Environment Art Styles]]

## Connected notes
<!-- auto-links:start -->
[[MaterialService and Custom Materials]] · [[Materials and Surfaces Start Here]] · [[Stylised vs Realistic Material Pipelines]] · [[SurfaceAppearance PBR Workflow]] · [[Studio Assistant and AI Tools]] · [[Terrain Materials and Painting]]
<!-- auto-links:end -->
