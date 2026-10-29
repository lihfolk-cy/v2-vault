---
tags: [atlas, api, type/atlas, area/studio, area/gameplay, api/AssemblyAngularVelocity]
---
# AssemblyAngularVelocity

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AssemblyAngularVelocity` is in world space, radians per second, which matches this function.
> - Setting `AssemblyLinearVelocity` and `AssemblyAngularVelocity` is supported on the assembly (Roblox docs, BasePart).
> - Filter with `Ctrl Shift P`: typing "velo" shows AssemblyLinearVelocity and AssemblyAngularVelocity (Docs).
>
> Cost: TL;DR ~120 tok · whole note ~300 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AssemblyAngularVelocity` is in world space, radians per second, which matches this function. (from [[Rotations Angles and Quaternions]])

API snapshot: member of `BasePart` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Setting `AssemblyLinearVelocity` and `AssemblyAngularVelocity` is supported on the assembly (Roblox docs, BasePart). ([[Centre of Mass, Anti-Flip and Self-Righting]])
- Filter with `Ctrl Shift P`: typing "velo" shows AssemblyLinearVelocity and AssemblyAngularVelocity (Docs). ([[Explorer Properties and Selection]])

## Mentioned in

6 notes in 6 sections. The 6 most relevant are linked:

### 01 Studio and Workflow
[[Explorer Properties and Selection]]

### 09 Gameplay Systems
[[Physics Assemblies and Constraints]]

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]]

### 22 Anti-Exploit and Security
[[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 25 Physics and Vehicles
[[Centre of Mass, Anti-Flip and Self-Righting]]

### 40 Game Math
[[Rotations Angles and Quaternions]]

<!-- atlas:generated -->
