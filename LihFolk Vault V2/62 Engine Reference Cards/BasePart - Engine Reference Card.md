---
tags: [reference, engine, basepart, api/BasePart, type/reference, area/scripting, level/intermediate]
---

# BasePart - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: expecting Touched when a script sets CFrame into another part.
> - Avoid: two anchored parts as a trigger pair.
> - Avoid: setting velocity from a LocalScript on a server-owned part.
> - Decide anchored versus simulated, then set network ownership for player-driven assemblies.
> - Use spatial queries (GetPartsInPart) for precise overlap checks.
> - Keep sizes within 0.001-2048 studs.
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The abstract base of every physical part (Part, MeshPart, UnionOperation and more); see [[Part]], [[Network Ownership]], [[Touched]] and [[GetPartsInPart]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Anchored | prop | boolean | - | Immovable by physics; network ownership cannot be set on anchored parts | No |
| CanCollide | prop | boolean | - | Off still allows Touched | No |
| CanTouch | prop | boolean | - | Both parts need it true for touch events | No |
| CanQuery | prop | boolean | - | Excluded from spatial queries when false; only takes effect with CanCollide off | No |
| CFrame | prop | CFrame | - | Setting it does no overlap check | No |
| Position / Orientation | prop | Vector3 | - | Hidden, Not Replicated views of CFrame | No |
| Size | prop | Vector3 | - | Each axis 0.001-2048 | No |
| Transparency | prop | number | - | [[LocalTransparencyModifier]] multiplies it locally | No |
| CollisionGroup | prop | string | "Default" | Max 100 characters; engine replicates it internally | No |
| Massless | prop | boolean | - | Ignored when the part is the assembly root | No |
| CustomPhysicalProperties | prop | PhysicalProperties | - | Overrides material density, friction, elasticity | No |
| AssemblyLinearVelocity | prop | Vector3 (studs/s) | - | Owner rules apply; replaces deprecated Velocity | No |
| AssemblyAngularVelocity | prop | Vector3 | - | Not Replicated tag; owner rules apply | No |
| AssemblyMass | prop | number | - | Read only; infinite if any part is anchored | No |
| AssemblyRootPart | prop | BasePart | - | Read only | No |
| [[ApplyImpulse]] | method | (impulse: Vector3) -> () | - | At center of mass; call where the owner runs | No |
| ApplyImpulseAtPosition | method | (impulse: Vector3, position: Vector3) -> () | - | Adds spin too | No |
| SetNetworkOwner | method | (playerInstance: Player = nil) -> () | - | Server; nil means server owns; applies to connected parts | No |
| GetNetworkOwner | method | () -> Instance | - | nil means the server | No |
| SetNetworkOwnershipAuto | method | () -> () | - | Engine chooses owner | No |
| GetConnectedParts | method | (recursive: boolean = false) -> {BasePart} | - | Joined parts | No |
| GetVelocityAtPosition | method | (position: Vector3) -> Vector3 | - | Velocity away from center of mass | No |
| SubtractAsync / UnionAsync / IntersectAsync | method | (parts, collisionfidelity = Default, renderFidelity = Automatic) -> Instance | - | Runtime solid modelling | Yes |
| Touched | event | (otherPart: BasePart) | - | Physical movement only; one part must be unanchored | - |
| TouchEnded | event | (otherPart: BasePart) | - | Pairs with Touched | - |

## Limits and defaults

- Size: each dimension from 0.001 to 2048 studs.
- CollisionGroup name: up to 100 characters; parts start in "Default".
- Velocity units: studs per second; Workspace.Gravity default 196.2 studs/s².
- Default character walk speed for scale: 16 studs/s.

## Replication and authority

- For a server-owned part, change AssemblyLinearVelocity or call ApplyImpulse from a server Script; a client call has no effect.
- For a part a client owns through automatic ownership, either side may change its velocity or apply impulses.
- Changing Anchored on the server affects that part's network ownership.
- Position, Orientation, Size, Color and BrickColor carry Not Replicated tags on the page; set them from the server as usual and read CFrame as the source of truth.

## Common mistakes

- Avoid: expecting Touched when a script sets CFrame into another part. Symptom: no event; Touched needs physical movement.
- Avoid: two anchored parts as a trigger pair. Symptom: Touched never fires between them.
- Avoid: setting velocity from a LocalScript on a server-owned part. Symptom: nothing moves.
- Avoid: the deprecated Velocity property. Symptom: deprecation warnings; AssemblyLinearVelocity is current.
- Avoid: unanchored parts with CanCollide off and no support. Symptom: they fall and are destroyed at FallenPartsDestroyHeight.
- Avoid: making a massless part the assembly root. Symptom: Massless is ignored for it.

## Checklist

- [ ] Decide anchored versus simulated, then set network ownership for player-driven assemblies.
- [ ] Use spatial queries (GetPartsInPart) for precise overlap checks.
- [ ] Keep sizes within 0.001-2048 studs.
- [ ] Name collision groups under 100 characters.

Source: https://create.roblox.com/docs/reference/engine/classes/BasePart (verified 2026-10-29)

<!-- related:start -->
## Related
[[Workspace - Engine Reference Card]] · [[Physics Assemblies and Constraints]] · [[Model - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]] · [[PhysicsService - Engine Reference Card]] · [[Camera - Engine Reference Card]]
<!-- related:end -->
