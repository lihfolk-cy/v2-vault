---
tags: [modeling, untextured, stylised, flat-colour, gradient-atlas, vertex-colour, meshpart, surfaceappearance, decision, type/guide, area/modeling, level/intermediate]
---
# Flat Colour vs Gradient Atlas vs Vertex Colour

<!-- tldr:start -->
> [!tldr] TL;DR
> - Vertex-coloured kit looks dark and muddy in Studio: `Color` left at default grey, which multiplies -> Set `Color` to white on import
> - Imported mesh is plain grey though it was coloured in Blender: glTF exporter did not write the colour attribute -> Set the exporter's vertex colour option to write...
> - Patchy triangle streaks that no `Color` or `Material` change removes: Unwanted generator vertex colours multiplying -> Ignore Vertex Colors on import, or paint white...
> - One colouring method chosen per kit, written in the style sheet, with the reason.
> - Colour regions per prop counted and instance totals estimated before modelling.
> - Recolour needs (zones, seasons, teams) known, and the method supports them.
>
> Cost: TL;DR ~220 tok · whole note ~4.6k tok. Read more: ## How each method reaches the screen in Roblox · ## Costs in numbers · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Low-Poly and Stylized Modeling]] lists three ways to colour a stylised mesh without a unique texture, and [[Trim Sheets Atlases and Vertex Colors]] explains each one technically. This note is the decision layer on top of them: how each method actually reaches the screen in Roblox, what it costs, which Roblox properties it collides with, and how to pick one per kit instead of per asset. It assumes the art is "non-hand-painted": the look comes from geometry, flat or gradient colour, vertex colour and lighting, never from painted texture detail.

The short version: **flat colour** (one `MeshPart.Color` per mesh, no texture) is the most flexible and the most instance-hungry; a **gradient atlas** (one small shared texture, UVs snapped into colour strips) is the most consistent and the best for whole kits; **vertex colour** (colour stored in the mesh) is the cheapest in memory and the hardest to change later. Most good projects use two of the three, on purpose, with a written rule for which asset gets which.

## How each method reaches the screen in Roblox

Understanding the multiplication chain is the whole game here, because every Roblox colour path is a multiply, and multiplies only darken.

### Flat colour (MeshPart.Color or Part.Color)

The mesh has no `TextureID` and no `SurfaceAppearance`. The surface colour is `Color`, shaded by the built-in `Material` (SmoothPlastic, Plastic, Neon and so on) and by lighting. To get two colours on one object you need two MeshParts (or two Parts), because one MeshPart has one `Color`.

- Change at runtime: trivial, set `Color` from a script.
- Memory: zero texture memory.
- Cost: one instance per colour region. A stylised lamp post with a dark pole, a gold cap and a yellow glass is three MeshParts, not one.
- Material: the built-in material's own texture and normal pattern applies through the mesh UVs, so a mesh with sensible UVs can show Plastic or Wood grain under a flat colour. A mesh with collapsed or missing UVs shows the material stretched or as a smear; use SmoothPlastic on those (rule of thumb, consistent with [[Trim Sheets Atlases and Vertex Colors]]).

### Gradient or palette atlas (TextureID or SurfaceAppearance.ColorMap)

The mesh's UVs are snapped into swatches or gradient strips of one small shared image. Many colours live on one MeshPart.

- With `MeshPart.TextureID`: the texture shows as it is. Community reports on the DevForum say transparent texels in a `TextureID` do not reveal `MeshPart.Color` behind them, and in practice `Color` does not usefully tint an opaque `TextureID` either (community reported; test it in your Studio version, Roblox does not document the combination on the MeshPart reference page as of October 2026).
- With a `SurfaceAppearance`: Roblox docs (as of October 2026) say `AlphaMode = Overlay` (the default) layers the colour map over the mesh and reveals `MeshPart.Color` where alpha is transparent; `TintMask` applies `SurfaceAppearance.Color` where alpha is opaque; `SurfaceAppearance.Color` is a multiplier on the colour map and "tinting does not affect performance". So a SurfaceAppearance is the route when you want a shared atlas and per-instance recolouring.
- Memory: one small texture for a whole kit. A 256 x 256 RGBA image is about 256 KB uncompressed before GPU compression and mips (rule of thumb arithmetic: 256 x 256 x 4 bytes); a 64 x 64 one is about 16 KB.
- Cost: one instance per mesh, regardless of how many colours it shows.

### Vertex colour

Colour is stored per face corner in the mesh file. Roblox docs (as of October 2026) confirm the 3D Importer reads vertex colours from FBX and glTF and offers a per-child **Ignore Vertex Colors** option. A widely used DevForum tutorial ("Vertex Colored Meshes using Blender and Studio") states the vertex colour is multiplied against the MeshPart's `Color`, and that new meshes default to Medium Stone Grey (163, 162, 165), which darkens them; set `Color` to pure white (255, 255, 255) to see the authored colours. The same tutorial reports vertex colours working with built-in materials (a Fabric example coloured entirely by vertex colour), and that in a SurfaceAppearance `Overlay` setup the vertex colours modulate the masked pixels.

- Memory: a few bytes per vertex, no texture.
- Cost: one instance per mesh.
- Resolution: colour exists only where vertices exist. A hard colour edge needs an edge in the mesh; a gradient needs vertices along it.
- Change at runtime: only through `Color` (which multiplies, so only darker or tinted). You cannot repaint vertex colours from Luau on a normal MeshPart (EditableMesh is a separate, budgeted system; see [[Mesh Optimization for Mobile]] and treat it as out of scope for kit colouring).
- UGC: the vault's UGC notes record that marketplace accessories must have vertex colour 1, 1, 1, so this method is not available for avatar items ([[UGC Avatar Items and Accessories]]).

## The decision table

| Question | Flat colour | Gradient atlas | Vertex colour |
|---|---|---|---|
| Colours per mesh | 1 | Unlimited (within swatch count) | Unlimited (within vertex count) |
| Instances for a 3-colour prop | 3 | 1 | 1 |
| Texture memory | 0 | One small shared image | 0 |
| Recolour one instance at runtime | Yes, freely | Yes with SurfaceAppearance (TintMask or Overlay), not with plain TextureID | Only by multiplying `Color` |
| Recolour a whole zone | Script over instances | Swap one image | Re-export meshes, or multiply `Color` |
| Smooth gradients | No (one colour per part) | Yes, along the strip | Yes, interpolated between vertices |
| Hard edges between colours | Free (separate parts) | Free (face boundary in UV) | Needs a mesh edge |
| Works with built-in materials | Yes | Material is replaced by the texture look | Yes (tutorial reported) |
| Survives mesh simplification | Yes | Mostly (UVs can drift when decimated) | Poorly (colours smear as vertices merge) |
| Editable later in Studio | Fully | Partly (tint, swap image) | Barely |
| Safe for UGC | Yes | Yes | No |
| Risk | Instance count and draw calls | Bleed between swatches at distance | Locked-in, noisy colours you cannot fix |

## Costs in numbers

Rule of thumb figures, for planning; measure your own place with the tools in [[Rendering Performance]].

**Instances.** A dressed stylised zone of 400 props where each prop averages three colour regions is 1,200 MeshParts with flat colour, and 400 with an atlas or vertex colour. [[Art Budgets - Triangles Draw Calls Memory]] puts a fully dressed zone at roughly 3k to 10k instances, so the flat-colour version eats a big slice of that budget on props alone.

**Draw calls.** Roblox does not document its batching rules in detail. Rule of thumb: identical meshes with identical materials and textures instance well; each distinct mesh plus surface combination is more work. Flat colour on a shared mesh still instances (colour is a per-instance value in most engines; Roblox's exact behaviour is not documented, so treat this as likely, not certain). Fifty meshes each with their own texture batch worse than fifty meshes sharing one atlas.

**Triangles.** Vertex colour and flat colour cost no extra triangles unless you add edges to hold colour boundaries. Vertex colour often does: a hard stripe across a smooth cylinder needs two extra edge loops, and a rock with a lighter top needs enough vertices along its height for the gradient to read. Budget 5 to 20 percent extra triangles on vertex-coloured kits for colour edges (rule of thumb). A gradient atlas puts the gradient in the texture, so it needs no extra geometry.

**Texture size.** Roblox docs (as of October 2026) say "individual meshes can not exceed 20,000 triangles" and give texture sizing guidance of 256 x 256 for objects around 5 studs, 512 x 512 for 10 studs and 1024 x 1024 for 20 studs. The same texture specifications page says both that Roblox supports up to 4096 x 4096 textures and that texture maps are limited to 1024 x 1024; treat 1024 as the safe ceiling for an uploaded map. A palette atlas never needs that size: 64 x 64 to 256 x 256 covers almost every kit.

## Phone vs PC

- **Low texture quality.** Rule of thumb: devices under memory pressure may load lower texture mip levels. A palette atlas with 16 px swatches survives several halvings; a gradient strip only 4 px wide merges with its neighbours after two. Flat colour and vertex colour do not care.
- **Low graphics levels.** On lower quality levels shadows and some lighting detail are reduced (rule of thumb; Roblox describes the trade in the `PrioritizeLightingQuality` property but does not list per-level features). Art that relies on lighting for form loses more than art with gradients baked in. A gradient atlas or vertex-colour gradient survives a phone on level 1 almost unchanged; a flat-colour world can turn into flat cut-outs. See [[Lighting Untextured Art in Roblox]].
- **Instance count** hurts phones more than PCs (load, memory, physics). Flat colour is the method that scales worst here.

## Edge cases and failure modes

**The grey default.** A vertex-coloured or Overlay mesh imported with the default grey `Color` looks about 36 percent darker than intended (163 of 255 per channel). Every import script should set `Color` to white on vertex-coloured meshes. If a kit "looks muddy in Studio but fine in Blender", check this first.

**glTF drops vertex colour.** The vault's export notes record that Blender's glTF exporter only writes vertex colours when told to (its vertex colour option defaults to writing them only when the material uses them, and the option name has changed across 4.x versions). The symptom is an all-grey import. See [[Exporting FBX vs GLB]].

**OBJ drops vertex colour.** OBJ does not carry them. Occasionally useful: exporting OBJ is a quick way to strip unwanted vertex colours from a generator's output (community tip).

**Generator noise.** Meshes from procedural tools, sculpt programs, photogrammetry and AI mesh generators often arrive with vertex colours you did not author. They multiply with everything and show as patchy triangle-shaped streaks. Either tick Ignore Vertex Colors at import or clean them in Blender (paint the whole Color Attribute white, or delete it).

**Atlas plus vertex colour.** If a mesh has both a palette texture and leftover vertex colours, the result is texture times vertex colour times (for some setups) `Color`. Swatches look subtly wrong per object and nobody can find why. Pick one per mesh; if both are intentional (vertex AO over an atlas), document it.

**Material on collapsed UVs.** A palette mesh with all UVs collapsed to swatch centres shows a built-in material as one stretched texel. If a later art pass wants Wood or Slate on it, it cannot tile. Keep a second UV-unwrapped copy of the source if you might ever want tiling materials.

**Decimation.** Decimating a vertex-coloured mesh merges vertices and averages their colours; crisp stripes turn into blurry bands. Decimate before colouring, or colour with an atlas.

## When not to use each

- **Not flat colour** when a prop has more than three colour regions and appears more than about twenty times in view: the instance count adds up. Also not when you want gradients.
- **Not a gradient atlas** for tiny palettes on huge flat surfaces (a 200-stud floor does not need a texture, give it `Color`), or when you need runtime per-instance tints and cannot use SurfaceAppearance.
- **Not vertex colour** on UGC, on meshes you will decimate, on meshes that will be recoloured per zone, or when the team includes people who will only ever edit in Studio. Also not on high-poly meshes from generators unless you authored the colours.

## Combining methods on purpose

| Combination | Why it works |
|---|---|
| Gradient atlas on the kit, flat-colour Neon parts for glows | Glows need the Neon material, which cannot come from a texture |
| Flat colour on large architecture, atlas on props | Big surfaces have one colour anyway; props need several |
| Atlas for colour, vertex colour for soft ambient occlusion only | Vertex AO in greys (never tinted) multiplies the atlas into corner darkening for free |
| Vertex colour on voxel or blocky meshes, flat colour on everything round | Voxel faces are one colour each by nature ([[Voxel and Blocky Modeling]]) |
| SurfaceAppearance TintMask atlas for "team colour" regions | One mesh, one atlas, per-instance colour on marked regions |

## Worked example: picking a method for a forest kit

A generic forest zone needs 24 props: 6 trees, 6 rocks, 4 bushes, 3 stumps, 2 fences, a signpost, a bridge, a campfire and a mushroom ring. The zone will reuse the kit in a later autumn version.

1. **List colour regions per prop.** Trees: trunk, two leaf greens. Rocks: stone, moss top. Fence: wood, dark nails. Campfire: stones, logs, fire (glow). Average about 2.5 regions per prop.
2. **Estimate instance counts.** The scatter places about 300 props in the zone. Flat colour: about 750 MeshParts. Atlas or vertex colour: about 300.
3. **Ask about recolouring.** The autumn version needs orange leaves. An atlas swap does it for every tree at once; flat colour needs a script pass; vertex colour needs a re-export.
4. **Ask about gradients.** Leaves look better darker at the bottom and lighter at the top. Atlas or vertex colour can do that; flat colour cannot.
5. **Decide.** Gradient atlas (one 128 x 128 image, 16 strips of 8 x 128 px) for trees, bushes, rocks, stumps, fences and signpost. Flat colour Neon parts for the campfire glow. A separate autumn atlas with the same layout, swapped in by changing one asset id per template.
6. **Write the rule down** in the style sheet: "Forest kit: atlas `forest_v1`, swatch layout fixed; glows are Neon parts; no vertex colours except grey AO." See [[Keeping a Mixed Asset Library Consistent]].
7. **Test one asset end to end** (Blender, export, import, Studio lighting, phone emulator) before building the other 23.

## A small Luau helper: report how each MeshPart is coloured

Run in the Command Bar to see which method each mesh in a model uses. It cannot read vertex colours (Luau does not expose them on MeshParts), so it reports meshes with neither texture nor appearance as "flat or vertex".

```lua
--!strict
-- Classify how each MeshPart under a model gets its colour.
local root: Instance = workspace:FindFirstChild("ForestKit") or workspace

local counts: {[string]: number} = {}
for _, d in root:GetDescendants() do
	if d:IsA("MeshPart") then
		local sa = d:FindFirstChildWhichIsA("SurfaceAppearance")
		local method: string
		if sa then
			method = "SurfaceAppearance/" .. sa.AlphaMode.Name
		elseif d.TextureID ~= "" then
			method = "TextureID"
		else
			-- Could be flat colour or vertex colour; check Color for the grey default trap.
			local c = d.Color
			local isDefaultGrey = math.abs(c.R - 163/255) < 0.01 and math.abs(c.G - 162/255) < 0.01
			method = if isDefaultGrey then "flat or vertex (DEFAULT GREY)" else "flat or vertex"
		end
		counts[method] = (counts[method] or 0) + 1
	end
end
for method, n in counts do
	print(string.format("%-36s %d", method, n))
end
```

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Vertex-coloured kit looks dark and muddy in Studio | `Color` left at default grey, which multiplies | Set `Color` to white on import |
| Imported mesh is plain grey though it was coloured in Blender | glTF exporter did not write the colour attribute | Set the exporter's vertex colour option to write the active attribute, or use FBX |
| Patchy triangle streaks that no `Color` or `Material` change removes | Unwanted generator vertex colours multiplying | Ignore Vertex Colors on import, or paint white in Blender |
| Zone recolour needs hundreds of edits | Flat colour chosen for a kit that changes per zone | Atlas with a swappable image, or SurfaceAppearance tint |
| Gradient atlas colours mix on distant props | Strips too narrow for mips | Wider strips (8 to 16 px), padding, fewer swatches |
| Prop counts explode the instance budget | Flat colour on multi-colour props | Atlas or vertex colour for props with 3 or more regions |
| UGC item rejected | Vertex colours on an accessory | Use a texture; vertex colour must be 1, 1, 1 |

## Checklist

- [ ] One colouring method chosen per kit, written in the style sheet, with the reason.
- [ ] Colour regions per prop counted and instance totals estimated before modelling.
- [ ] Recolour needs (zones, seasons, teams) known, and the method supports them.
- [ ] Vertex-coloured meshes get `Color` white on import; Ignore Vertex Colors ticked for meshes that should not have them.
- [ ] Atlas swatches wide enough for phones (8 px minimum, 16 px for distant props).
- [ ] UVs kept on a source copy even for collapsed palette meshes.
- [ ] One asset tested end to end in Studio under the game's lighting and on a phone before the kit is built.

## Related

- [[Low-Poly and Stylized Modeling]]
- [[Trim Sheets Atlases and Vertex Colors]]
- [[The Gradient Palette Texture Workflow]]
- [[Lighting Untextured Art in Roblox]]
- [[Keeping a Mixed Asset Library Consistent]]
- [[Exporting FBX vs GLB]]
- [[SurfaceAppearance PBR Workflow]]
- [[Stylised vs Realistic Material Pipelines]]
- [[Art Budgets - Triangles Draw Calls Memory]]
- [[Voxel and Blocky Modeling]]
- [[UGC Avatar Items and Accessories]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Bevels Chamfers and Edge Highlights Without Textures]] · Modeling in Blender for Roblox · MagicaVoxel Goxel and Blockbench Workflows Compared · Materials MaterialVariants and SurfaceAppearance · Baking Lighting and Detail into Textures · Voxel Modelling Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Modeling in Blender for Roblox]] · [[Texturing and PBR Baking]] · [[Colour Scripts and Value Structure for Untextured Art]]
<!-- related:end -->
