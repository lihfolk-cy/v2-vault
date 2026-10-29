---
tags: [atlas, api, type/atlas, area/gameplay, area/physics, api/ApplyImpulse]
---
# ApplyImpulse

<!-- tldr:start -->
> [!tldr] TL;DR
> - `BasePart:ApplyImpulse` applies an impulse to the part's whole assembly; on a server-owned part call it from a server Script...
> - Server `ApplyImpulse` on player characters.
> - Server-owned NPCs and props: `BasePart:ApplyImpulse(dir * strength * assemblyMass)` on the server.
>
> Cost: TL;DR ~110 tok · whole note ~300 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`BasePart:ApplyImpulse` applies an impulse to the part's whole assembly; on a server-owned part call it from a server Script, because a client call on a server-owned part does nothing (from [[Physics Assemblies and Constraints]]; Roblox docs).

API snapshot: member of `BasePart` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Server `ApplyImpulse` on player characters. Owned by the client, so it often does nothing; send it to the owner instead. ([[Melee Combat System End to End]])
- Server-owned NPCs and props: `BasePart:ApplyImpulse(dir * strength * assemblyMass)` on the server. ([[Explosions - Radius Damage, Falloff and Cover Checks]])

## Mentioned in

6 notes in 4 sections. The 6 most relevant are linked:

### 09 Gameplay Systems
[[Combat Systems Architecture]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Physics Assemblies and Constraints]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 25 Physics and Vehicles
[[Destruction and Fracture]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
