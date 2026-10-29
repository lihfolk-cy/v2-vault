---
tags: [reference, engine, physicsservice, api/PhysicsService, type/reference, area/scripting, level/intermediate, area/physics]
---

# PhysicsService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: calling `CollisionGroupSetCollidable` before the group exists.
> - Avoid: unregistering a group that still has parts.
> - Avoid: renaming a group and expecting parts to follow.
> - Groups defined in the Studio editor, with names kept in one shared constants module.
> - New scripts call the `workspace:` (WorldRoot) versions.
> - Collision rules set from server Scripts only.
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The home of collision groups: named sets of parts whose pairwise collisions you switch on or off. The engine now hosts the same API on `WorldRoot` (call it on `workspace`), and the PhysicsService versions point there. Topic note: [[Collision and Physics Geometry]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| workspace:RegisterCollisionGroup | method | `(name: string)` | - | Current home (WorldRoot); name cannot be "Default" | no |
| workspace:CollisionGroupSetCollidable | method | `(name1: string, name2: string, collidable: boolean)` | groups collide by default | Errors if either group is unregistered | no |
| workspace:CollisionGroupsAreCollidable | method | `(name1: string, name2: string) -> boolean` | - | Returns true if either group is unregistered | no |
| workspace:IsCollisionGroupRegistered | method | `(name: string) -> boolean` | - | Guard before SetCollidable | no |
| workspace:GetRegisteredCollisionGroups | method | `() -> {{name: string, mask: number}}` | - | mask is internal | no |
| workspace:GetMaxCollisionGroups | method | `() -> number` | 32 | Per world | no |
| workspace:RenameCollisionGroup | method | `(from: string, to: string)` | - | Parts keep the old name in their property | no |
| workspace:UnregisterCollisionGroup | method | `(name: string)` | - | Invalid name does nothing; "Default" errors | no |
| BasePart.CollisionGroup | prop | string | - | Assign parts by group name | - |
| PhysicsService:RegisterCollisionGroup | method | `(name: string)` | - | Superseded by WorldRoot:RegisterCollisionGroup | no |
| PhysicsService:CollisionGroupSetCollidable | method | `(name1, name2, collidable: boolean)` | - | Superseded by the WorldRoot method | no |
| PhysicsService:CollisionGroupsAreCollidable | method | `(name1, name2) -> boolean` | - | Superseded by the WorldRoot method | no |
| PhysicsService:IsCollisionGroupRegistered | method | `(name) -> boolean` | - | Superseded by the WorldRoot method | no |
| PhysicsService:GetRegisteredCollisionGroups | method | `() -> {any}` | - | Superseded by the WorldRoot method | no |
| PhysicsService:GetMaxCollisionGroups | method | `() -> number` | 32 | Superseded by the WorldRoot method | no |
| PhysicsService:RenameCollisionGroup / UnregisterCollisionGroup | method | `(from, to)` / `(name)` | - | Superseded by the WorldRoot methods; server only | no |

Fully deprecated names and their replacements:
- `CreateCollisionGroup` -> `RegisterCollisionGroup`.
- `RemoveCollisionGroup` -> `UnregisterCollisionGroup`.
- `GetCollisionGroups` -> `GetRegisteredCollisionGroups`.
- `SetPartCollisionGroup`, `CollisionGroupContainsPart`, `GetCollisionGroupId`, `GetCollisionGroupName` -> read or write `BasePart.CollisionGroup` by name.

## Limits and defaults

- Maximum 32 collision groups per world.
- Legacy numeric group IDs ran 0 to 31.
- "Default" is reserved: it cannot be registered, and unregistering it throws.
- Register, rename and unregister cost time in proportion to the number of BaseParts in the world. Set groups up at edit time in the Studio Collision Groups editor and change them rarely.

## Replication and authority

- Creating, deleting and changing collision relationships is limited to server Scripts. `RenameCollisionGroup` and `UnregisterCollisionGroup` throw when called from a client.
- Part membership is a normal `CollisionGroup` property, so a server change replicates to clients like any other property.

## Common mistakes

- Avoid: calling `CollisionGroupSetCollidable` before the group exists. Symptom: a runtime error; check `IsCollisionGroupRegistered` or register first.
- Avoid: unregistering a group that still has parts. Symptom: undefined physics for those parts; move them to "Default" first.
- Avoid: renaming a group and expecting parts to follow. Symptom: parts still carry the old name and fall out of the rule.
- Avoid: registering groups every round at runtime. Symptom: hitches on busy maps, since the cost scales with part count.
- Avoid: new code on `SetPartCollisionGroup` or numeric IDs. Symptom: deprecated calls; set `part.CollisionGroup = "Name"`.
- Avoid: using `CollisionGroupsAreCollidable` to confirm a typo-free setup. Symptom: it returns true for unregistered names, hiding the typo.

## Checklist

- Groups defined in the Studio editor, with names kept in one shared constants module.
- New scripts call the `workspace:` (WorldRoot) versions.
- Collision rules set from server Scripts only.
- Group count kept under 32, with headroom.

Source: https://create.roblox.com/docs/reference/engine/classes/PhysicsService and https://create.roblox.com/docs/reference/engine/classes/WorldRoot - verified 2026-10-29

<!-- related:start -->
## Related
[[BasePart - Engine Reference Card]] · [[Workspace - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[RunService - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[CollectionService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]]
<!-- related:end -->
