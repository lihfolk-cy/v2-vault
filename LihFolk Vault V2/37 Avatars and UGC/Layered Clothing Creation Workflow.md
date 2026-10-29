---
tags: [avatars, ugc, layered-clothing, cages, blender, skinning, wraplayer, workflow]
---
# Layered Clothing Creation Workflow

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Rebuilding cages from scratch -> Start from official templates
> - Avoid: Outer cage identical to inner -> Move outer cage where the garment is
> - Avoid: Decimate or merge on cage -> Only move vertices
> - Template cages and mannequin from the official resources.
> - Outer cage duplicated from inner at the start; inner locked.
> - Garment under 4,000 triangles, watertight, clear of the body.
>
> Cost: TL;DR ~140 tok · whole note ~4.7k tok. Read more: ## 4. Edit the outer cage · ## 7. Debug the fit in Studio before any upload · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[UGC Avatar Items and Accessories]] lists the layered clothing specification (one mesh, 4,000 triangles, inner and outer cages, R15 skinning, 2048 textures) and [[Layered Clothing Cages and Animation]] explains how garments deform in motion. This note is the production workflow between those two: the order of operations in Blender, how to edit the outer cage without breaking it, the two skinning routes and when each wins, how to debug a bad fit in Studio with the WrapLayer debug modes, and garment-specific problems (hoods, skirts, shoes, bulky coats). The goal is to get a garment that passes validation the first time, because every re-upload of a published item costs the upload fee again.

Facts marked "docs" are **Roblox docs (as of October 2026)**. Blender steps are **rule of thumb** from common practice; menu names drift between Blender versions.

## 1. How the system actually fits a garment

Understanding the mechanism makes every rule below obvious.

1. The **body** has an outer cage, a low-poly shell with a fixed topology and UV layout shared by every Roblox body.
2. Your garment's **inner cage** is that same template shell (same vertex count, same UVs), positioned where the body sits in your file.
3. At runtime the engine **binds** your inner cage to the body's outer cage by matching UVs. The `BoundCage` debug mode literally describes binding as relying on matching UV layouts between cages (docs). That is why changing cage UVs is forbidden.
4. The difference between your inner and outer cage tells the engine how "thick" your garment is. Your render mesh is carried along between them by a radial basis function (RBF) solver (there is an `Rbf` debug mode for it, docs).
5. The **next layer** on top binds its inner cage to **your outer cage**. Your outer cage is therefore the surface every garment above you will hug.

Consequences:

- An **outer cage too tight** (inside your garment) means the jacket above crushes your hood into the body.
- An **outer cage too loose** means the jacket above floats off your shirt like a balloon.
- A **wavy outer cage** looks fine alone and produces ripples only when something is layered on top (docs call this out). You will not see it unless you test stacks.
- A **garment partly outside the outer cage** does not deform there and behaves like a rigid piece (docs). Sometimes that is what you want (a stiff hood rim); usually it is a bug.
- **Identical inner and outer cages** leave the system unable to identify the accessory and may deform it incorrectly (docs). The outer cage must be moved at least where the garment is.

## 2. File setup before modelling anything

Start from Roblox's official caging templates and mannequins (Creator Hub avatar resources). Do not rebuild a cage from a tutorial file of unknown origin; a single changed UV seam fails binding.

A clean Blender scene for one garment:

| Object | Name | Purpose |
|---|---|---|
| Armature | Template R15 armature | Skinning target; do not rename bones |
| Mannequin body | Template body (hidden on export) | Reference for modelling and weight transfer |
| Garment | `Jacket` (your accessory name) | The render mesh |
| Inner cage | `Jacket_InnerCage` | Template cage, untouched |
| Outer cage | `Jacket_OuterCage` | Template cage, edited outward |
| Attachment marker | `BodyFrontAttachment_Att` for tops, `WaistCenterAttachment_Att` for bottoms | Read as an attachment point by the Importer for caged meshes (docs) |

Rules of thumb that save hours:

- **Freeze transforms** (apply location, rotation, scale) on garment and cages before you start editing, and again before export. Unapplied scale on a cage is a classic "cage does not match body" failure.
- **Duplicate the inner cage to make the outer cage** at the very start, so both are guaranteed identical in topology and UVs. The spec says the outer cage starts identical to the inner and is the only one you adjust (docs).
- **Lock the inner cage** (hide it, disable selection) so you cannot nudge it by accident.
- **Model on the Normal-scale mannequin** and check the Slender and Classic variants early. Layered clothing stretches to fit, but extreme proportions expose thin areas (armpits, crotch, collar).

## 3. Model the garment

- **Budget:** 4,000 triangles for the single render mesh (docs). A good T-shirt is 1,200 to 2,000; a detailed coat with hood 3,000 to 3,800 (rule of thumb). Spend triangles on the silhouette (hems, collar, hood edge), not on flat fronts.
- **Watertight** with no backfaces (docs). A shirt is a closed shell with real thickness at the hem and cuffs; an open, single-sided hem fails.
- **Even edge flow around joints.** The garment deforms by skinning plus cage fitting; a shoulder with two edge loops creases badly in arms-up poses. Three to four loops across each elbow and shoulder is a good default ([[Topology and Edge Flow]]).
- **Keep clearance from the body.** The garment surface should sit just outside the body (not intersecting it) everywhere. The engine fits garments to many body shapes; intersections that are invisible on the mannequin show through on a wide body.
- **UVs and texture:** one UV set, texture up to 2048 for Marketplace (docs). Fabric detail usually reads better from a normal map than from extra geometry ([[Normal Maps and Detail Baking]]).

## 4. Edit the outer cage

This is where most failed and ugly garments come from. The docs' rules, with the reasons:

| Rule (docs) | Why |
|---|---|
| Move vertices outward along normals | Keeps cage shape regular; sideways moves create overlaps |
| Work symmetrically where possible | Asymmetric cages make the next layer lopsided |
| Do not stack (collapse) vertices | Validation rejects collapsed vertices; artifacts nearby |
| Keep vertex, edge and face count identical to the template | Binding is by UV and index |
| Keep edge spacing even, especially on the torso | Uneven spacing causes deformation artifacts |
| Align cage break lines with joints (elbow break at LowerArm) | The cage bends where the body bends |
| Do not move vertices in areas the garment does not cover | A T-shirt with an inflated leg cage pushes pants outward for no reason |
| Keep the outer cage close to the garment, no big gaps | Large gaps cause severe deformation of the next layer |

A practical Blender method (rule of thumb):

1. Select the outer cage vertices in the area the garment covers (torso and upper arms for a T-shirt).
2. Add a **Shrinkwrap** modifier targeting the garment, mode "Project" or "Nearest Surface Point", with a small positive offset (a few hundredths of a stud in Roblox units), restricted to a vertex group of those vertices. Shrinkwrap moves vertices; it never changes topology, so the count rule is safe.
3. Add a light **Smooth** or **Corrective Smooth** after it, restricted to the same group, to remove the waviness the shrinkwrap leaves where the garment has folds.
4. Apply the modifiers and inspect: no outer cage vertex should be inside the garment, none should be far outside it.
5. Feather the boundary: vertices at the edge of the covered area should move a little, so there is no step between moved and unmoved regions.

What not to use on a cage: Remesh, Decimate, Subdivide, Merge by Distance, Mirror with clipping and merge, Boolean, "Clean up" tools, anything that triangulates or deletes. Any of these silently changes the index order or count.

A Blender Python check you can run before every export:

```python
# Blender: verify a garment's cages are still valid copies of the template.
import bpy

def cage_report(name):
    inner = bpy.data.objects[f"{name}_InnerCage"].data
    outer = bpy.data.objects[f"{name}_OuterCage"].data
    problems = []
    if len(inner.vertices) != len(outer.vertices):
        problems.append(f"vertex count {len(inner.vertices)} vs {len(outer.vertices)}")
    if len(inner.polygons) != len(outer.polygons):
        problems.append(f"face count {len(inner.polygons)} vs {len(outer.polygons)}")
    uv_in, uv_out = inner.uv_layers.active, outer.uv_layers.active
    if uv_in is None or uv_out is None:
        problems.append("missing UV layer")
    else:
        for i, (a, b) in enumerate(zip(uv_in.data, uv_out.data)):
            if (a.uv - b.uv).length > 1e-5:
                problems.append(f"UV differs at loop {i}")
                break
    moved = sum(1 for a, b in zip(inner.vertices, outer.vertices) if (a.co - b.co).length > 1e-5)
    if moved == 0:
        problems.append("outer cage identical to inner cage")
    # Collapsed vertices in the outer cage
    seen = {}
    for v in outer.vertices:
        key = tuple(round(c, 5) for c in v.co)
        if key in seen:
            problems.append(f"collapsed vertices {seen[key]} and {v.index}")
            break
        seen[key] = v.index
    return problems or ["ok"], moved

print(cage_report("Jacket"))
```

It does not replace Roblox's validator, but it catches the four most common cage mistakes in a second, before you pay anything.

## 5. Skinning: authored weights or automatic transfer

The garment must be weighted to the R15 armature with at most 4 influences per vertex, or rely on automatic skinning transfer (docs). In Studio, `WrapLayer.AutoSkin` (`Enum.WrapLayerAutoSkin`, docs) has three values:

| Value | Behaviour (docs) |
|---|---|
| `Disabled` (default) | Uses your authored skinning; an unskinned mesh will not deform with the character |
| `EnabledPreserve` | Transfers skinning only if the mesh has none |
| `EnabledOverride` | Always replaces weights with the cage-based transfer |

`AutoSkin` requires `StarterPlayer.LoadCharacterLayeredClothing` to be enabled or Default (docs).

| Choose | When | Why |
|---|---|---|
| Authored weights | Stiff items (collars, armour-like jackets, belts), garments with deliberate rigid zones, anything where you know exactly how it should bend | Full control; predictable |
| Automatic transfer | Soft clothing, long skirts and dresses, quick iteration | Fast; handles skirts between the legs well |
| Authored, then test with `EnabledOverride` | Diagnosing whether a problem is your weights or your cage | If override fixes it, your weights were wrong |

Authoring weights quickly in Blender (rule of thumb):

1. Parent the garment to the armature with empty groups.
2. **Data Transfer** modifier from the mannequin body: Vertex Data, Vertex Groups, "Nearest Face Interpolated". This copies the body's weights to the garment, which is the right starting point for anything close-fitting.
3. Apply, then **Limit Total** to 4 and **Normalize All** (both in Weight Paint > Weights). Skipping Limit Total is a common validation failure; skipping Normalize gives vertices that drift in poses.
4. Hand-fix: smooth weights across the armpit and crotch, and paint stiff zones (a collar weighted 100 percent to UpperTorso does not wobble with the head).

Skirts and dresses: body-transferred weights split the skirt down the middle between legs, which tears the cloth in strides. Blend skirt weights from LowerTorso at the waist toward an even split of both UpperLegs at the hem, so each leg pulls the whole hem a little ([[Weight Painting and Skinning for Roblox]]).

## 6. Export and import

- **FBX** from Blender with the template's recommended export settings (see [[Exporting and Validating Models for Roblox]] and [[3D Importer Settings Reference]]). Include armature, garment, both cages, and the `_Att` marker. Exclude the mannequin body.
- In Studio, import with the 3D Importer and pick the matching rig scale (Rthro = Normal, Rthro Narrow = Slender, Default = Classic, as documented in the older note).
- The Importer sets `ReferenceMeshId`, `ReferenceOrigin` and `CageMeshId` on the `WrapLayer` automatically (docs). If those are empty, the cages were not recognised: check names and that both cages were exported.
- Convert to an Accessory with the **Accessory Fitting Tool** (Avatar tab), which also generates the correct attachments (docs).

## 7. Debug the fit in Studio before any upload

`WrapLayer.DebugMode` (`Enum.WrapLayerDebugMode`, docs, not saved with the place) shows what the solver is doing. The useful ones:

| Mode | Shows | Use it to find |
|---|---|---|
| `BoundCage` | Cage vertices bound to the target | Unbound regions: UV or topology mismatch |
| `BoundCageAndLinks` | Same, plus lines from previous-layer positions | Vertices that travel far: cage too loose or too tight there |
| `Reference` | The inner cage as authored | Inner cage moved or scaled wrongly |
| `OuterCage` | The outer cage as authored | Waviness, gaps, collapsed areas |
| `LayerCageFittedToPrev` | Your outer cage fitted to the layer below | How your garment will look when worn over another |
| `PreWrapDeformerOuterCage` | Outer cage vertices that moved during deformation | Unexpected deformation hot spots |
| `HSRInner` / `HSRInnerReverse` | Inner cage areas hidden or visible under the layer above | Hidden-surface-removal problems (inner garments poking through) |
| `SkinningTransfer` | Lines from vertices to influencing joints | Weights pulled by the wrong bone (a sleeve following the torso) |
| `Rbf` | The RBF solver links | Rarely needed; deep diagnosis |

`WrapLayer.Color` sets the debug draw colour and is also not saved (docs). Use different colours per garment when debugging a stack.

**Hidden surface removal (HSR):** the engine works out which parts of inner layers are covered by outer layers so they do not poke through or waste rendering. `BaseWrap` carries `HSRAssetId` data (docs). The exact HSR algorithm is not documented in detail; treat poke-through under a jacket as a sign that the jacket's outer cage is tight or the shirt's outer cage is loose, and inspect with the HSR modes.

### The test matrix

Before uploading, wear the garment on:

| Axis | Cases |
|---|---|
| Body | Blocky classic, Normal mannequin, Slender, a wide body, a very tall and very short scale |
| Stack | Alone; over a T-shirt; under a jacket; over a bulky hoodie |
| Poses | Idle, walk, run, jump, arms overhead (an emote with raised arms), crouch, sit |
| Hair | Long layered hair over a hood or collar |
| Camera | Close-up and at typical play distance on a phone |

[[Layered Clothing Cages and Animation]] covers which poses break which garments; this matrix is the minimum to run every time.

## 8. Garment-specific problems

| Garment | Typical failure | Fix |
|---|---|---|
| Hoodie with hood up | Next layer crushes the hood | Keep the hood outside the outer cage or route the cage under it (docs advice for protrusions) |
| Puffy jacket | Things under it poke through at elbows | Displace outer cage further, smoothly, with neighbours moving together (docs advice for bulky items) |
| Long dress | Tears between legs in strides | Blended skirt weights; or auto skinning |
| Tight leggings | Look painted-on, inner geometry visible at knees on wide bodies | Small but non-zero offset from body; three loops at the knee |
| Shoes | Two separate accessories `LeftShoeAccessory` and `RightShoeAccessory`, grouped as a Model (older note) | Model and cage each shoe separately |
| Layered hair | Collides with hoods and collars | Test against the hoodie in the matrix |
| Shoulder pads, spikes | Flattened by layers above | Keep protrusions outside the outer cage |

## 9. In-game garments (not for sale)

Not every layered garment needs the Marketplace. A game can ship its own layered uniforms and skins as ordinary assets:

- **Custom cages are allowed for in-game assets** but cannot be published to the Marketplace (docs). That lets you layer clothing onto non-R15 bodies or creatures.
- For non-R15 targets, the layering MeshPart needs a `Weld` to its parent part (with an R15 Humanoid this weld is created automatically, docs).
- In-game garments skip the upload fee and moderation, but they still cost runtime: every layered item on every character re-runs the fit when bodies or layers change. A game uniform of one layered top plus classic pants is cheaper than three stacked layered garments.

## 10. When not to make it layered

- **Rigid things** (helmets, backpacks, swords): a rigid accessory is cheaper, simpler and never deforms wrong.
- **Pixel-art or blocky styles** where classic 2D clothing is the look: classic clothing is cheaper to make and to render.
- **Very bulky costumes** (mascot suits, mech armour): layering stretches them over every body shape and the silhouette collapses. Use a body bundle or in-game rig instead.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Rebuilding cages from scratch | Binding fails, validation rejects | Start from official templates |
| Outer cage identical to inner | Incorrect deformation (docs) | Move outer cage where the garment is |
| Decimate or merge on cage | Count mismatch, rejection | Only move vertices |
| Unapplied object scale | Cage appears at the wrong size | Apply transforms before export |
| More than 4 influences | Validation failure | Limit Total 4, then Normalize |
| Skirt weighted per leg only | Tearing in strides | Blend toward both legs at the hem |
| Testing alone only | Ripples under jackets after release | Test stacks |
| Inflating cage regions the garment does not cover | Other layers float | Leave uncovered regions untouched |

## Checklist

- [ ] Template cages and mannequin from the official resources.
- [ ] Outer cage duplicated from inner at the start; inner locked.
- [ ] Garment under 4,000 triangles, watertight, clear of the body.
- [ ] Outer cage moved along normals, smooth, close, uncovered areas untouched.
- [ ] Cage check script passes (counts, UVs, moved, no collapsed vertices).
- [ ] Weights limited to 4 and normalised, or `AutoSkin` chosen deliberately.
- [ ] Imported with the right rig scale; WrapLayer reference and cage ids set.
- [ ] Debug modes checked; test matrix run on bodies, stacks and poses.
- [ ] Upload only after all of the above: every update costs the upload fee again.

## See also

[[Avatars and UGC Start Here]] · [[UGC Avatar Items and Accessories]] · [[Layered Clothing Cages and Animation]] · [[Weight Painting and Skinning for Roblox]] · [[Exporting and Validating Models for Roblox]] · [[3D Importer Settings Reference]] · [[Topology and Edge Flow]] · [[Normal Maps and Detail Baking]] · [[Blender Workflow for Roblox Creators]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[Avatar Body Types and Scale in Gameplay]]

## Connected notes
<!-- auto-links:start -->
[[Bundles Animation Packs and Emotes for Sale]] · [[Links - Avatars and UGC]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Skinning Weights]] · [[UV Unwrapping]] · [[Rigging in Blender]]
<!-- auto-links:end -->
