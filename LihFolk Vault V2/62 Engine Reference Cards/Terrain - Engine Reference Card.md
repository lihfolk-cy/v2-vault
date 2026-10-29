---
tags: [reference, engine, terrain, api/Terrain, type/reference, area/scripting, level/intermediate, api/WriteVoxels, api/FillBlock, area/world]
---

# Terrain - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: passing a resolution other than 4.
> - Avoid: unaligned `Region3` boxes for `ReadVoxels` or `ReplaceMaterial`.
> - Avoid: one giant `WriteVoxels` over a whole map.
> - All voxel work uses resolution 4 and grid-aligned regions.
> - Large generation split into chunks under the voxel limit.
> - Gameplay edits happen on the server; cosmetic client edits are clearly local.
>
> Cost: TL;DR ~130 tok · whole note ~1.5k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The single voxel-based landscape under `Workspace.Terrain`: shape it with Fill methods, bulk-edit it with voxel arrays, and tune water and material colors. Topic notes: [[Terrain Tools and Terrain API]], [[Terrain Deep Dive - Materials Water and Performance]], [[Noise Functions and Terrain Generation]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| FillBlock | method | `(cframe: CFrame, size: Vector3, material: Enum.Material)` | - | Oriented box at full occupancy; any rotation | no |
| FillBall | method | `(center: Vector3, radius: number, material: Enum.Material)` | - | Sphere; overwrites what is inside | no |
| FillCylinder | method | `(cframe: CFrame, height: number, radius: number, material: Enum.Material)` | - | Oriented cylinder | no |
| FillWedge | method | `(cframe: CFrame, size: Vector3, material: Enum.Material)` | - | Ramps and slopes | no |
| FillRegion | method | `(region: Region3, resolution: number, material: Enum.Material)` | - | Grid-aligned region; resolution must be 4 | no |
| ReplaceMaterial | method | `(region: Region3, resolution: number, source: Enum.Material, target: Enum.Material)` | - | Swap one material for another; region aligned to 4 | no |
| ReadVoxels | method | `(region: Region3, resolution: number) -> (materials, occupancies)` | - | 3D arrays plus `Size`; resolution 4 | no |
| WriteVoxels | method | `(region: Region3, resolution: number, materials: {any}, occupancy: {any})` | - | Bulk write; occupancy 0-1 per voxel | no |
| ReadVoxelChannels / WriteVoxelChannels | method | `(region, resolution, channelIds) -> {[string]: any}` / `(region, resolution, channels)` | - | Channels `SolidMaterial`, `SolidOccupancy`, `LiquidOccupancy` (water mixed with solids) | no |
| Clear | method | `()` | - | Removes all terrain | no |
| CountCells | method | `() -> number` | - | Non-empty cell count | no |
| CopyRegion / PasteRegion | method | `(region: Region3int16) -> TerrainRegion` / `(region: TerrainRegion, corner: Vector3int16, pasteEmptyCells: boolean)` | - | Save and stamp chunks; `TerrainRegion` data does not replicate | no |
| WorldToCell / CellCenterToWorld / CellCornerToWorld | method | `(position: Vector3) -> Vector3` / `(x, y, z) -> Vector3` | - | Convert between studs and 4-stud cells | no |
| WorldToCellPreferSolid / PreferEmpty | method | `(position: Vector3) -> Vector3` | - | Break ties on cell edges | no |
| SetMaterialColor / GetMaterialColor | method | `(material: Enum.Material, value: Color3)` / `(material) -> Color3` | - | Some materials reject custom colors and error | no |
| WaterColor | prop | Color3 | teal (0.05, 0.33, 0.36) | Water tint | no |
| WaterTransparency | prop | number | 0.3 | 0-1 | no |
| WaterReflectance | prop | number | 1 | 0-1 | no |
| WaterWaveSize | prop | number (studs) | 0.15 | Constrained to 0-1 | no |
| WaterWaveSpeed | prop | number (waves/min) | 10 | Constrained to 0-100 | no |
| MaxExtents | prop | Region3int16 | -32000 to 32000 cells | Read-only editable bounds | no |

Retired names and their replacements:
- `SetCell`, `SetCells`, `SetWaterCell`, `GetCell`, `GetWaterCell` -> `WriteVoxels` / `ReadVoxels` (or the Fill methods).
- `AutowedgeCell`, `AutowedgeCells`, `ConvertToSmooth`, `IsSmooth` -> nothing needed; every place uses smooth terrain.

## Limits and defaults

- Voxels are 4 x 4 x 4 studs; every `resolution` argument must be exactly 4.
- Region-based calls need grid-aligned regions (corners divisible by 4); `Region3:ExpandToGrid(4)` aligns them.
- `ReadVoxels`, `WriteVoxels` and the channel methods error on regions above 4,194,304 voxels; split big jobs into chunks.
- `MaxExtents` spans -32,000 to 32,000 cells, which is -128,000 to 128,000 studs per axis.
- `Decoration` (animated grass) and `GrassLength` are Studio-only settings, not scriptable.

## Replication and authority

- Terrain edits made on the server replicate to every client; edits from a LocalScript stay on that client.
- `TerrainRegion` objects from `CopyRegion` do not replicate, so copy and paste on the same side.
- Generate procedural terrain on the server in chunks with a `task.wait()` between them to keep the server responsive.

## Common mistakes

- Avoid: passing a resolution other than 4. Symptom: the voxel call errors.
- Avoid: unaligned `Region3` boxes for `ReadVoxels` or `ReplaceMaterial`. Symptom: errors or edits offset from where you aimed; call `ExpandToGrid(4)` first.
- Avoid: one giant `WriteVoxels` over a whole map. Symptom: the region-size error past 4,194,304 voxels.
- Avoid: `SetCell` or `GetCell` from old tutorials. Symptom: deprecated legacy-terrain calls; use voxel arrays.
- Avoid: carving terrain from a LocalScript for gameplay. Symptom: other players still collide with the old terrain.

## Checklist

- All voxel work uses resolution 4 and grid-aligned regions.
- Large generation split into chunks under the voxel limit.
- Gameplay edits happen on the server; cosmetic client edits are clearly local.
- Water look set once through `WaterColor`, `WaterTransparency` and wave properties.

Source: https://create.roblox.com/docs/reference/engine/classes/Terrain and https://create.roblox.com/docs/parts/terrain - verified 2026-10-29

<!-- related:start -->
## Related
[[Roads, Rivers and Paths Carved Along Curves in Terrain]] · [[Terrain Materials and Painting]] · [[BasePart - Engine Reference Card]] · [[Workspace - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[PathfindingService - Engine Reference Card]] · [[Humanoid - Engine Reference Card]]
<!-- related:end -->
