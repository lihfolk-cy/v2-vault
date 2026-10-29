---
tags: [reference, engine, billboardgui, api/BillboardGui, type/reference, area/scripting, level/intermediate, api/SurfaceGui, api/MaxDistance, area/ui, api/LightInfluence]
---

# BillboardGui - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: sizing a nametag with Offset only.
> - Avoid: leaving `MaxDistance` infinite on hundreds of labels.
> - Avoid: buttons on a SurfaceGui parented in Workspace.
> - `Adornee`, `Size` (scale for stud size), and `StudsOffset` chosen deliberately.
> - Finite `MaxDistance` on every repeated world label.
> - Interactive world UI lives in StarterGui with `Adornee`, `Active` true and `CanQuery` true on the part.
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

World-space UI: `BillboardGui` floats over a part or attachment and always faces the camera, while `SurfaceGui` paints UI onto one face of a part. Topic notes: [[World-Space UI - BillboardGui and SurfaceGui]], [[Nametags and Overhead Bars - Cost and Visibility Rules]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| BillboardGui.Adornee | prop | Instance? | nil | BasePart or Attachment to follow; nil = parent | no |
| BillboardGui.Size | prop | UDim2 | `{0, 0}, {0, 0}` | Scale = studs in the world, Offset = fixed pixels | no |
| BillboardGui.StudsOffset | prop | Vector3 (studs) | `0, 0, 0` | Camera-relative offset; use `StudsOffsetWorldSpace` for world axes | no |
| BillboardGui.ExtentsOffset | prop | Vector3 | `0, 0, 0` | Offset in half-extents of the adornee's camera-aligned bounds | no |
| BillboardGui.MaxDistance | prop | number (studs) | inf | 0 or inf = always render; set a finite value to cull | no |
| BillboardGui.AlwaysOnTop | prop | boolean | false | true renders over 3D content with ScreenGui-like colors | no |
| BillboardGui.LightInfluence | prop | number 0-1 | 0 | 1 = lit by the scene; 0 = full brightness | no |
| BillboardGui.Brightness | prop | number 0-1000 | 1 | Scales light while `LightInfluence` is 0 | no |
| BillboardGui.PlayerToHideFrom | prop | Player? | nil | Hides it from one player (for example the owner's own nametag) | no |
| BillboardGui.CurrentDistance | prop | number | - | Read-only distance to the camera | no |
| BillboardGui.Active | prop | boolean | false | Must be true on the gui and the button for clicks | no |
| SurfaceGui.Adornee / Face | prop | Instance? / `Enum.NormalId` | nil / - | Part and face to draw on | no |
| SurfaceGui.SizingMode | prop | `Enum.SurfaceGuiSizingMode` | `PixelsPerStud` per docs | `PixelsPerStud` scales with part size; `FixedSize` uses `CanvasSize` | no |
| SurfaceGui.PixelsPerStud | prop | number | 50 | Higher = sharper and smaller-looking content | no |
| SurfaceGui.CanvasSize | prop | Vector2 (virtual pixels) | `800, 600` | Used by `FixedSize` mode | no |
| SurfaceGui.MaxDistance | prop | number (studs) | 1000 per docs | 0 = no limit | no |
| SurfaceGui.ZOffset | prop | number | 0 | Orders guis on the same face; does not lift them off the surface | no |
| SurfaceGui.ToolPunchThroughDistance | prop | number | 0 | Within this range, clicks go to the gui instead of the held Tool | no |
| Enabled / ClipsDescendants | prop (LayerCollector) | boolean | true / false | Toggle visibility per client | no |

Retired names: `BillboardGui.DistanceLowerLimit` and `DistanceUpperLimit` are deprecated; size billboards with scale (studs) or offset (pixels) in `Size`, and cull with `MaxDistance`.

## Limits and defaults

- `BillboardGui.MaxDistance` inf by default; `SurfaceGui.MaxDistance` 1000 studs per the docs.
- `Brightness` accepts 0-1000; `LightInfluence` 0-1.
- `SurfaceGui.PixelsPerStud` 50 and `CanvasSize` 800 x 600.
- Engine defaults for `Instance.new("SurfaceGui")` report `MaxDistance` 0 and `SizingMode` `FixedSize`, while the docs list 1000 and `PixelsPerStud`; set both explicitly in scripts.
- Clicks need the gui under PlayerGui (usually via StarterGui with `Adornee` set) and, for SurfaceGui, the part's `CanQuery` true.

## Replication and authority

- A BillboardGui or SurfaceGui parented under a part in Workspace replicates like any instance, so the server can create nametags everyone sees.
- Interactive world UI belongs in StarterGui with `Adornee` pointing at the world part, so each client owns its copy; button actions still go through validated remotes.

## Common mistakes

- Avoid: sizing a nametag with Offset only. Symptom: it stays the same pixel size and covers the screen at range; use scale for stud-sized labels.
- Avoid: leaving `MaxDistance` infinite on hundreds of labels. Symptom: clutter and draw cost from far-away guis.
- Avoid: buttons on a SurfaceGui parented in Workspace. Symptom: clicks never register; move it to StarterGui and set `Adornee`.
- Avoid: `AlwaysOnTop` on world signs. Symptom: signs show through walls.
- Avoid: relying on `Instance.new` defaults for SurfaceGui. Symptom: crisp in Studio, blurry or oversized from script.

## Checklist

- `Adornee`, `Size` (scale for stud size), and `StudsOffset` chosen deliberately.
- Finite `MaxDistance` on every repeated world label.
- Interactive world UI lives in StarterGui with `Adornee`, `Active` true and `CanQuery` true on the part.
- SurfaceGui `SizingMode`, `PixelsPerStud` and `LightInfluence` set in code, not assumed.

Source: https://create.roblox.com/docs/reference/engine/classes/BillboardGui and https://create.roblox.com/docs/reference/engine/classes/SurfaceGui - verified 2026-10-29

<!-- related:start -->
## Related
[[ScrollingFrame - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[SoundService - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[GuiService - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[Player - Engine Reference Card]]
<!-- related:end -->
