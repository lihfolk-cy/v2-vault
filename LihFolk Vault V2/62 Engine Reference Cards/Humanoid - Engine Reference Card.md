---
tags: [reference, engine, humanoid, api/Humanoid, type/reference, area/scripting, level/intermediate, api/WalkSpeed, api/LoadAnimation]
---

# Humanoid - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: freezing players with WalkSpeed = 0 as a security gate.
> - Avoid: TakeDamage when you mean to bypass shields.
> - Avoid: Humanoid:LoadAnimation in new code.
> - Apply damage and health changes on the server.
> - Use Animator:LoadAnimation and ApplyDescriptionAsync.
> - Set BreakJointsOnDeath false for ragdolls.
>
> Cost: TL;DR ~120 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The controller that gives a character health, walking, jumping and states; see [[Humanoid]] and [[Humanoid States and Animation]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Health | prop | number | - | 0 to MaxHealth; Not Replicated tag | No |
| MaxHealth | prop | number | - | Sizes the default health bar | No |
| WalkSpeed | prop | number (studs/s) | 16 (StarterPlayer) | Client-replicated: not a security check | No |
| UseJumpPower | prop | boolean | true (StarterPlayer) | Chooses JumpPower or JumpHeight | No |
| JumpPower | prop | number | 50 | Range 0-1000 | No |
| JumpHeight | prop | number (studs) | 7.2 | Used when UseJumpPower is false | No |
| HipHeight | prop | number (studs) | - | R15 height = 0.5 * RootPart.Size.Y + HipHeight | No |
| MaxSlopeAngle | prop | number (degrees) | 89 | Range 0-89 | No |
| AutoRotate | prop | boolean | - | Turn to face movement | No |
| DisplayName | prop | string | "" | Empty shows the parent's Name | No |
| BreakJointsOnDeath | prop | boolean | true | Keep false for ragdolls | No |
| RequiresNeck | prop | boolean | true | Neck break kills when true | No |
| RootPart / FloorMaterial / MoveDirection | prop | BasePart / Enum.Material / Vector3 | - | Read only, Not Replicated | No |
| EvaluateStateMachine | prop | boolean | - | Off: no automatic states or state replication | No |
| TakeDamage | method | (amount: number) -> () | - | Blocked by a ForceField | No |
| MoveTo | method | (location: Vector3, part: Instance = nil) -> () | - | Times out after 8 s | No |
| ChangeState | method | (state: Enum.HumanoidStateType) -> () | - | Call on the network owner's side | No |
| [[SetStateEnabled]] | method | (state, enabled: boolean) -> () | - | Does not replicate either way | No |
| GetState | method | () -> Enum.HumanoidStateType | - | Current state | No |
| EquipTool / UnequipTools | method | (tool) -> () / () -> () | - | Backpack tools | No |
| [[ApplyDescriptionAsync]] | method | (description, assetTypeVerification = Default) -> () | - | Replaces deprecated ApplyDescription | Yes |
| LoadAnimation | method | (animation) -> AnimationTrack | - | Deprecated: use Animator:LoadAnimation() | No |
| Died | event | () | - | Needs the Humanoid in Workspace and the Dead state enabled | - |
| HealthChanged / StateChanged | event | (health) / (old, new) | - | Reactive UI and logic | - |
| MoveToFinished | event | (reached: boolean) | - | false on timeout | - |

## Limits and defaults

- WalkSpeed default 16 studs/s; JumpPower default 50 (0-1000); JumpHeight default 7.2 studs.
- MaxSlopeAngle: 0-89 degrees, default 89.
- MoveTo timeout: 8 seconds unless you call it again to reset.
- Default regeneration: 1% of MaxHealth per second; add an empty Script named Health to StarterCharacterScripts to turn it off.
- Health is clamped to 0..MaxHealth and locks at 0 once dead.

## Replication and authority

- WalkSpeed is client-replicated: a client can change it locally, so validate movement on the server.
- ChangeState works from a LocalScript when the client owns the character, or from the server when the server owns it.
- SetStateEnabled changes stay on the side that made them.
- Health and Jump carry Not Replicated tags on the page; apply damage from server code with TakeDamage.

## Common mistakes

- Avoid: freezing players with WalkSpeed = 0 as a security gate. Symptom: exploiters move anyway; enforce on the server.
- Avoid: TakeDamage when you mean to bypass shields. Symptom: no damage while a ForceField is present; set Health directly for that case.
- Avoid: Humanoid:LoadAnimation in new code. Symptom: deprecation warnings; load through the Animator child.
- Avoid: waiting forever on MoveToFinished for long paths. Symptom: the walk stops after 8 s; re-issue MoveTo per waypoint.
- Avoid: disabling the Dead state and expecting Died. Symptom: Died never fires.

## Checklist

- [ ] Apply damage and health changes on the server.
- [ ] Use Animator:LoadAnimation and ApplyDescriptionAsync.
- [ ] Set BreakJointsOnDeath false for ragdolls.
- [ ] Re-call MoveTo for each path waypoint.

Source: https://create.roblox.com/docs/reference/engine/classes/Humanoid (verified 2026-10-29)

<!-- related:start -->
## Related
[[Characters and Humanoids]] · [[Animator - Engine Reference Card]] · [[PathfindingService - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[Instance - Engine Reference Card]]
<!-- related:end -->
