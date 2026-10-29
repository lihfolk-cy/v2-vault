---
name: lihfolk-assets
description: 'Find and import assets from the local LihFolk Asset Pack (models, materials, skies, animations, VFX). Use for "LihFolk asset", "what assets do we have".'
---

# LihFolk Assets: use the local asset pack

The LihFolk Asset Pack is a separate download (GitHub Release zips) of original assets made for Roblox. This skill finds the right asset from the catalogues instead of browsing folders or guessing.

## 1. Locate the pack

Check in this order and use the first folder that contains `INDEX.md`:

1. The env var `LIHFOLK_ASSETS`
2. `~/LihFolk-Assets`
3. Ask the user for the path, and suggest setting `LIHFOLK_ASSETS` so it is found next time

If the pack isn't installed, say so and point to the Releases page of `lihfolk-cy/v2-vault` (the full pack is split into Models, Materials, Skies and Animations-VFX zips that extract into one folder; `LihFolk-Asset-Pack-Sample.zip` is a small taster with the same layout). Don't substitute Toolbox or web assets.

## 2. Search the catalogue, not the folders

Read `INDEX.md` first (a few lines), then grep only the catalogue you need:

| Need | Catalogue | Key columns | Preview |
|---|---|---|---|
| Props and kit pieces | `Models/Kits/CATALOG.csv` | kit, type, tags, tris, budget_class, dims_studs, score | `preview` jpg, `turntable` mp4 |
| Surface materials | `Materials/CATALOG.csv` | family, theme, tags, colors, roblox_base_material | `Materials/_sheets/` |
| Skyboxes | `Skies/CATALOG.csv` | family, theme, colors, celestial_bodies_shown | `Skies/_sheets/` |
| Animations | `Animations/CATALOG.csv` (+ `Animations/PIPELINE.md`) | category, frames, fps, loop, priority, markers, status | `<Clip>_sheet.png` |
| VFX looks | `VFX/CATALOG.csv`, textures in `VFX/Textures/_textures.json` | preset, variant, status | `VFX/Previews/*.mp4` and `_strip.png` |

Grep by tag or theme (for example `grep -i "crimson" Models/Kits/CATALOG.csv`), keep the matches to a short list and **look at the preview image** before choosing. Don't read whole catalogues into context. `examples/<Section>.CATALOG.sample.csv` in this skill shows each catalogue's header and two real rows.

## 3. Only use shippable rows

- Models: `gate` = `A1-A18 pass`. Materials and skies: `family_status` = `pass`.
- Animations and VFX: `status` = `shipped` or `approved`. A `draft` row is work in progress: offer it as a starting point only if the user agrees, and say it's a draft.
- `Dataset/` holds scored attempts for learning. Never put them in a game.

## 4. Import rules

- **Models:** import the GLB in Studio (Asset Manager or 3D Importer) at 1 stud per unit. Keep `MeshPart.Color` white so the baked colours show, anchor static props and place on the ground with a raycast (see `roblox-asset-import`).
- **Materials:** create a `MaterialVariant` on the listed `roblox_base_material` with the colour, normal, roughness and metalness maps from the folder.
- **Skies:** set the six `Sky` faces from the folder; turn off the default sun or moon if `celestial_bodies_shown` is `True`.
- **Animations:** the `.rbxmx` holds a KeyframeSequence for R15. Load it into the Animation Editor, publish it, then use the uploaded id. Keep its `priority`, `loop` and marker names; wire VFX to the markers.
- **VFX:** the Luau module lives in the `lihfolk-vfx` skill; the pack holds textures and previews. Upload textures and paste their ids into the module config.
- Uploading to Roblox is the user's step. **Never invent asset ids**: leave `rbxassetid://REPLACE_ME` and list what to upload.

## 5. After use

If you change or combine assets, score the result with `quality-score` (minimum 8.5) before calling it done.

## See also

`lihfolk-vfx` · `roblox-asset-import` · `roblox-blender-modeling` · `quality-score`
