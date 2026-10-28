---
tags: [art-direction, untextured, stylised, asset-library, consistency, pipeline, audit, palette, luau]
---
# Keeping a Mixed Asset Library Consistent

<!-- tldr:start -->
> [!tldr] TL;DR
> - Scene looks like an asset flip: Mixed shading, bevel widths and palettes across sources -> Normalise in priority order: scale, shading, edges, palette, material
> - Store assets never fit: Textures with baked lighting -> Strip and recolour, or skip
> - Studio-built parts look harsher than meshes: Sharp Part edges next to bevelled meshes -> Bevelled mesh primitives for visible architecture
> - House rules written as numbers: scale, bevel, shading, facet size, colour method, palette, material, detail minimum.
> - Shared Blender template with palette, modifier presets, measuring cube and export preset.
> - Per-source normalisation steps applied (Parts, Blender, CC0, store, voxel, AI).
>
> Read more (16 KB note): ## Normalising each source · ## Auditing a place with Luau · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Very few Roblox games are built from one source. A typical library mixes Parts and unions built in Studio, meshes modelled in Blender by two or three people, a CC0 pack (Kenney and Quaternius publish large free low-poly kits), a few Creator Store models, voxel props exported from MagicaVoxel, and lately AI-generated meshes. Each source arrives with its own scale, palette, shading, bevel size and material habits. Textured games can hide some of the mismatch under a shared texture style; untextured games cannot, because the mismatch is in the geometry and the flat colours themselves. Put a gently bevelled Blender barrel next to a sharp-edged Studio crate and a faceted store rock, and the scene reads as an asset flip even if every piece is good on its own.

This note is the practical side of consistency: the handful of measurable properties that make untextured assets match, a normalisation pass for each source, a Luau audit that finds outliers in a place, a palette remap script, and how to keep the library from drifting over months. The written style document itself (what goes in it and how to run reviews) is the subject of [[Style Bibles for Consistent Models]]; this note assumes you have one, even a one-page version, and shows how to enforce it.

## What actually makes untextured assets match

Rule of thumb from art direction practice: viewers notice mismatch in this order, so normalise in this order.

1. **Scale and proportion.** A door that is 1.5 times the "house style" door, or a crate that is tiny next to a barrel. Relative to the player is what matters ([[Modelling to the Roblox Camera and Player Scale]]).
2. **Shading mode.** Faceted next to smooth, hard edges next to soft bevels.
3. **Edge treatment.** Bevel width in studs, segment count, outline or no outline.
4. **Palette and value.** Colours outside the zone palette, or the right hues at the wrong values.
5. **Material response.** SmoothPlastic next to Plastic next to Neon-ish bright, or a textured store asset among flat ones.
6. **Detail density.** One prop with 20 small pieces next to props with 3 big shapes.
7. **Silhouette language.** Round friendly props next to spiky ones in the same zone, without intent ([[Shape Language and Silhouette Testing]]).

Each of these can be written as a number or a rule. That is what makes consistency enforceable instead of a matter of taste.

## The house rules as numbers

A one-page table, kept with the style document. Example values for a generic chunky flat stylised game (rule of thumb starting points, not standards):

| Property | House rule |
|---|---|
| Player reference | Default avatar height; doors 8 to 10 studs tall, 6 studs wide |
| Bevel width | 3 to 5 percent of the object's smallest large dimension; minimum 0.08 studs; 1 segment, 2 on hero props |
| Shading | Smooth with weighted normals for props and architecture; faceted only for rocks, crystals, canopies |
| Facet size (faceted assets) | About 12 px on a 720 px tall render at the usual viewing distance ([[Faceted Low-Poly - Flat Normals and Facet Size]]) |
| Colour method | Gradient atlas `zone_L1` for props; flat `Color` for surfaces over 50 studs; Neon for glows; no vertex colour except grey AO |
| Palette | Base 16 colours plus zone 12; props use 2 to 4 |
| Material | SmoothPlastic; Neon by budget; nothing patterned |
| Outlines | None (or: inverted hull on characters only) |
| Detail | Minimum detail size 0.4 studs; no part thinner than 0.2 studs |
| Tilt and imperfection | Stacked items rotated 2 to 6 degrees; posts lean up to 3 degrees |
| Triangle budgets | Per class, from [[Art Budgets - Triangles Draw Calls Memory]] |
| Pivot | Bottom centre, facing -Z (or your engine convention) |

## Normalising each source

### Studio Parts and unions

- **Edges:** Parts have perfectly sharp edges. Next to bevelled meshes they look harsher. Either keep Parts for large architecture where bevels do not show (and keep meshes bevelled lightly), or replace key Parts with bevelled mesh equivalents from a small kit (a bevelled block, wedge, cylinder in a few standard sizes).
- **Material:** Studio's default part material is Plastic; imported meshes often end up SmoothPlastic. Pick one.
- **Colour:** Part colours picked by hand drift off-palette fastest. Run the palette remap below regularly.

### Blender meshes from several artists

- **Template file.** A shared `.blend` with the units, a player-height reference, the palette image, standard modifier stacks (Bevel with house values, Weighted Normal) saved as presets or a geometry node group, and export presets. New assets start from it.
- **Measure bevels in studs**, not "looks right": add a measuring reference cube with the house bevel next to every new model.
- **Same export preset** for everyone ([[Exporting and Validating Models for Roblox]]).

### CC0 packs

- **Scale.** Packs use their own units; most need a uniform scale factor. Find it once per pack against the player reference and record it.
- **Palette.** Many low-poly packs colour with one material per colour or with a shared colormap texture. Remap to your palette in Blender (reassign materials, or remap UVs into your atlas) before import; remapping after import is harder.
- **Shading.** Packs vary between flat and smooth. Convert to your house shading in Blender.
- **Licence:** CC0 means no attribution requirement, but record the source anyway for your own tracking ([[Legal Basics - IP Licenses and Assets]]).

### Creator Store models

- **Safety first:** scripts inside free models are a known risk; strip them and check before use ([[Creator Store and Toolbox Safety]]).
- **Textures and baked lighting.** Many store models carry textures with painted or baked shadows. In an untextured game these never match. Remove the texture and recolour with flat colour or your atlas, or skip the asset.
- **Hidden vertex colours** and odd materials: check with the audit below.

### Voxel exports

- **Voxel size in studs** must match the game's voxel grid if voxel art appears in several places; a 0.5 stud voxel prop next to a 1 stud voxel prop reads as two styles. The voxel section covers grids in depth.
- **Voxel art next to smooth stylised art** is a style decision, not a mistake, only if it is consistent: for example "all collectibles are voxel, the world is smooth".

### AI-generated meshes

- **Topology and normals** are usually messy: retopologise or decimate, then reapply house shading ([[Retopology and Decimation]]).
- **Vertex colours and textures** from generators carry painted lighting and noise. Strip them (Ignore Vertex Colors at import, or delete the colour attribute) and recolour from the palette.
- **Shape language** tends toward generic detail. Simplify to the house detail minimum before anything else.

## Auditing a place with Luau

Run in the Command Bar. It reports, for every BasePart under a root: colours not close to any palette entry, materials outside the allowed set, MeshParts with textures or appearances in a game that should be untextured, and parts thinner than the detail minimum. It prints the worst offenders by name so you can select them.

```lua
--!strict
-- Edit-time consistency audit for an untextured stylised library.
local ROOT = workspace:FindFirstChild("Zones") or workspace

local PALETTE: {Color3} = {
	Color3.fromRGB(122, 164, 74), Color3.fromRGB(86, 120, 60), Color3.fromRGB(140, 102, 70),
	Color3.fromRGB(176, 170, 160), Color3.fromRGB(230, 200, 90), Color3.fromRGB(90, 140, 200),
	Color3.fromRGB(240, 236, 228), Color3.fromRGB(52, 48, 60),
}
local ALLOWED_MATERIALS: {[Enum.Material]: boolean} = {
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
}
local MAX_DISTANCE = 30     -- in redmean units (roughly 0 to 765); about 30 = visibly different
local MIN_THICKNESS = 0.2   -- studs

-- "Redmean" weighted RGB distance: a cheap perceptual approximation.
local function distance(a: Color3, b: Color3): number
	local r1, g1, b1 = a.R * 255, a.G * 255, a.B * 255
	local r2, g2, b2 = b.R * 255, b.G * 255, b.B * 255
	local rm = (r1 + r2) / 2
	local dr, dg, db = r1 - r2, g1 - g2, b1 - b2
	return math.sqrt((2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db)
end

local function nearest(c: Color3): (Color3, number)
	local best, bestD = PALETTE[1], math.huge
	for _, p in PALETTE do
		local d = distance(c, p)
		if d < bestD then best, bestD = p, d end
	end
	return best, bestD
end

local offPalette: {string}, badMaterial: {string}, textured: {string}, thin: {string} = {}, {}, {}, {}
for _, d in ROOT:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local _, dist = nearest(d.Color)
		if dist > MAX_DISTANCE then table.insert(offPalette, d:GetFullName()) end
		if not ALLOWED_MATERIALS[d.Material] then table.insert(badMaterial, d:GetFullName() .. " (" .. d.Material.Name .. ")") end
		if d:IsA("MeshPart") and (d.TextureID ~= "" or d:FindFirstChildWhichIsA("SurfaceAppearance")) then
			table.insert(textured, d:GetFullName())
		end
		local s = d.Size
		if math.min(s.X, s.Y, s.Z) < MIN_THICKNESS then table.insert(thin, d:GetFullName()) end
	end
end

local function report(title: string, list: {string})
	print(string.format("%s: %d", title, #list))
	for i = 1, math.min(#list, 10) do print("   ", list[i]) end
end
report("Off-palette colours", offPalette)
report("Materials outside the rule", badMaterial)
report("Textured meshes (check against the style sheet)", textured)
report("Thinner than the detail minimum", thin)
```

Notes on reading it:

- A gradient atlas mesh's `Color` is usually white and its real colours are in the texture, so it will not flag off-palette; review atlas meshes by eye or by checking which atlas id they use. Likewise vertex-coloured meshes cannot be inspected from Luau.
- Bounding-box thickness is crude for meshes (a thin rim on a big mesh is not detected); it catches thin Parts, which are the common offender.
- Some textured meshes may be allowed (a sign, a decal-like emblem); keep an allow-list attribute such as `StyleException = true` and skip those.

## Remapping colours to the palette

When the audit finds off-palette Parts, snap them. This keeps the old colour in an attribute so the change can be reverted.

```lua
--!strict
-- Edit-time: snap off-palette Part colours to the nearest palette entry.
-- Reuses PALETTE, distance and nearest from the audit script (paste them above this).
local ROOT = workspace:FindFirstChild("Zones") or workspace
local SNAP_ABOVE = 12   -- only snap colours that are not already near a palette entry

local changed = 0
for _, d in ROOT:GetDescendants() do
	if d:IsA("BasePart") and not d:GetAttribute("StyleException") then
		local isPlainMesh = d:IsA("MeshPart") and d.TextureID == "" and not d:FindFirstChildWhichIsA("SurfaceAppearance")
		if d:IsA("Part") or isPlainMesh then
			local target, dist = nearest(d.Color)
			if dist > SNAP_ABOVE then
				if d:GetAttribute("OriginalColor") == nil then
					d:SetAttribute("OriginalColor", d.Color)
				end
				d.Color = target
				changed += 1
			end
		end
	end
end
print("snapped", changed, "parts")
```

Wrap bulk edits so Studio undo works as one step if your team relies on undo (see [[Command Bar and Studio Scripting]] for ChangeHistoryService recordings). Note that `d:IsA("Part")` covers Part, but WedgeParts and CornerWedgeParts are separate classes; add them if your builds use them.

Caution: nearest-colour snapping preserves hue families but can collapse two intentionally different shades onto one entry. Review the zone in greyscale after snapping ([[Colour Scripts and Value Structure for Untextured Art]]).

## The neighbour test

Numbers catch most mismatch; the eye catches the rest. Before an asset enters the library:

1. Place it in the look-dev room ([[Lighting Untextured Art in Roblox]]) between two approved assets of a similar class (a new barrel between an approved crate and an approved sack).
2. View at the usual gameplay distance and at close range, in colour and greyscale.
3. Ask one question: "If I did not know which one was new, could I tell?" If yes, find which of the seven properties differs and fix that.

Keep a shelf of 10 to 20 "golden" approved assets in the look-dev place specifically for this test. They are the style in physical form, more useful than any written rule.

## Keeping it from drifting

- **One owner for the library** (or for each kit) who approves additions. Consistency fails by a thousand small "just this once" additions.
- **Library in Packages** (or a dedicated asset place) so approved assets are reused by reference and fixes propagate ([[Packages and Asset Reuse]]).
- **Audit on a schedule**, for example before every update, not only when someone complains.
- **Version the palette and atlas layout** together; never edit the palette image without checking every kit that uses it ([[The Gradient Palette Texture Workflow]]).
- **Record exceptions** with an attribute and a reason, so the next person does not "fix" an intentional exception or copy it as precedent.
- **Retire assets** that no longer match after a style update instead of leaving them in the library, or they will be reused.

## When not to chase consistency

- **Deliberate contrast:** a special event zone, a "glitch world" or a boss arena may break the house style on purpose. Write the exception down.
- **Player creations** in building games will never match; design the default material and colour set players build with instead.
- **Prototypes:** do not normalise assets that might be cut. Normalise on the way into the shipping library.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Scene looks like an asset flip | Mixed shading, bevel widths and palettes across sources | Normalise in priority order: scale, shading, edges, palette, material |
| Store assets never fit | Textures with baked lighting | Strip and recolour, or skip |
| Studio-built parts look harsher than meshes | Sharp Part edges next to bevelled meshes | Bevelled mesh primitives for visible architecture |
| Colours drift over months | Hand-picked Part colours | Audit and snap to palette on a schedule |
| Two shades collapsed after snapping | Palette too small for the zone | Add the missing shade to the palette, then re-run |
| Every artist's bevels differ | "Looks right" instead of a number | House bevel in studs, measuring cube in the template |
| Exceptions copied as precedent | Undocumented exceptions | `StyleException` attribute plus a reason in the style sheet |

## Checklist

- [ ] House rules written as numbers: scale, bevel, shading, facet size, colour method, palette, material, detail minimum.
- [ ] Shared Blender template with palette, modifier presets, measuring cube and export preset.
- [ ] Per-source normalisation steps applied (Parts, Blender, CC0, store, voxel, AI).
- [ ] Audit script run before each update; off-palette colours snapped with originals stored.
- [ ] Neighbour test against golden assets in the look-dev room.
- [ ] Library owner, Packages or asset place, exceptions recorded with attributes.

## Related

- [[Style Bibles for Consistent Models]]
- [[Stylised vs Realistic Material Pipelines]]
- [[Environment Art Styles]]
- [[Flat Colour vs Gradient Atlas vs Vertex Colour]]
- [[The Gradient Palette Texture Workflow]]
- [[Colour Scripts and Value Structure for Untextured Art]]
- [[Lighting Untextured Art in Roblox]]
- [[Creator Store and Toolbox Safety]]
- [[Packages and Asset Reuse]]
- [[Modular Environment Kits]]
- [[Retopology and Decimation]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Bevels Chamfers and Edge Highlights Without Textures]] · [[Clean Stylised Shading - Weighted and Custom Normals]] · [[Low-Poly and Stylized Modeling]] · [[Modelling Nuance Start Here]] · [[Modeling Fundamentals for Games]] · [[Hard-Surface Modeling]]
<!-- auto-links:end -->
