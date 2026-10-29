---
tags: [ai-pitfalls, physics, animation, motor6d, cframe, priorities, animator, network-ownership, rigs, server-authority]
verified: 2026-10-28
---
# AI Pitfalls - Physics and Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Debugging a pose in world space when the error is in the joint frame.
> - Avoid: Tuning animation playback speed to hide foot sliding; fix strides at the source (Measured: forcing 2-4x rates looked frantic).
> - Avoid: Expecting Edit-mode previews to match Play.
> - No per-frame `C0` writes; procedural layers use `Transform` in `PreSimulation`.
> - Every track has an explicit priority; no `.Value` sorting.
> - Attack clips that play while moving have no lower-body keys.
>
> Cost: TL;DR ~160 tok · whole note ~1.9k tok. Read more: ## 1. Motor6D composition order · ## 2. Priorities and weights · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Generated physics and animation code fails on maths conventions (which frame a CFrame is in), on engine behaviour the docs only hint at, and on Edit-mode versus Play-mode differences. Several entries below are **Measured** in the LihFolk reference project, which built hundreds of animated weapons and enemies. Hub: [[What AI Models Get Wrong in Roblox]].

## 1. Motor6D composition order

- **Wrong:** `motor.C0 = CFrame.new(offset) * CFrame.Angles(...)` every frame to animate, or treating `C0` as a world CFrame, or composing `C1 * Transform * C0`.
- **Why:** C0 and C1 look like "the offset", and many tutorials animate by editing C0.
- **Right:** `Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse()`. `C0`/`C1` are the rest pose; the Animator writes `Transform`. Procedural layers modify `Transform` in `RunService.PreSimulation` (after animation is applied); `Transform * extra` follows the animated limb, `extra * Transform` re-aims the whole limb. Editing `C0` per frame fights the Animator and replicates as property spam.

```lua
-- Place Part1 at a desired world CFrame by solving for C0 (one-off re-pose, not per frame)
motor.C0 = motor.Part0.CFrame:Inverse() * desiredPart1World * motor.C1
-- Per-frame aim on top of animation
RunService.PreSimulation:Connect(function()
	local j = neck.Part0.CFrame * neck.C0 * neck.Transform
	local localR = j.Rotation:Inverse() * aimWorldRotation * j.Rotation
	neck.Transform *= localR
end)
```

- **Detect:** `C0 =` inside `RenderStepped`, `Heartbeat` or loops. Source: [[Motor6D Math and CFrame Composition]].

## 2. Priorities and weights

- **Wrong:** everything at `Action`; leaving the uploaded clip's priority at `Core`; sorting priorities by `Enum.AnimationPriority.X.Value`; expecting two tracks at weight 1 to each show fully.
- **Right:**
  - Order is Core < Idle < Movement < Action < Action2 < Action3 < Action4. **`Core.Value` is 1000**, so sorting by `.Value` puts Core on top. Map explicitly.
  - Priority works **per joint**: a track only competes on joints it keys. An attack clip with leg keys takes the legs and the character skates; strip lower-body keys for "swing while walking".
  - **Measured:** when weights at one priority sum past 1, they are normalised.
  - Set `track.Priority` in code after loading if you cannot trust the asset.
- Source: [[Playback, Priorities and Blending]].

## 3. Animator setup and replication

- **Wrong:** `Instance.new("Animator", humanoid)` in a LocalScript; loading a new track every time an ability fires.
- **Right:** player characters already have a server-created Animator; a client-created one plays only for that client. Load each track once per character and reuse it. Under Server Authority, do not cache tracks across frames; use `Animator:GetTrackByAnimationId()`, and at release only 8 tracks could play per Animator.
- **Detect:** `Instance.new("Animator"` in client code; `LoadAnimation` inside an input or remote handler.

## 4. Root motion and the top-level pose

- **Wrong:** keying root motion on the `HumanoidRootPart` pose (or a bone rig's top `Root`).
- **Right:** **Measured:** the first pose under each keyframe is never applied by the Animator. Put root motion on a child joint (`LowerTorso`) or move the root in code. See [[Animator Deep Dive]].

## 5. Edit-mode rigs are not Play-mode rigs

- **Measured:** `Players:CreateHumanoidModelFromDescription(Async)` in Edit mode returns a rig **without Motor6Ds**, and `Humanoid:BuildRigFromAttachments` on it fails quietly. Animation previews in Edit need a real rig or anchored FK posing.
- **Measured:** `AnimationTrack` time is float32, `Stop()` keeps time running through the fade, and `StepAnimations(dt)` needs `dt > 0` to advance. The Animator "coin-flips" the direction of an exact 180-degree segment; avoid exact 180-degree keys.
- **Measured:** animation ids from `KeyframeSequenceProvider:RegisterKeyframeSequence` work in Studio only. Upload clips for live games.
- Source: [[How the Animator Really Behaves]], [[Testing Animations in Studio]].

## 6. Moving models and welds

- **Wrong:** setting `.Position` or `.CFrame` on each part of a welded or constrained model; `SetPrimaryPartCFrame`; tweening unanchored parts.
- **Right:** `model:PivotTo(cf)` for teleports. Setting `CFrame` on one part of a welded assembly moves the assembly, but setting `Position` per part breaks relative layout. Tween anchored parts, or drive unanchored ones with constraints (`AlignPosition`, `AlignOrientation`). Create `WeldConstraint`s **after** positioning parts (they lock the current offset).

## 7. Physics ownership and NPC jitter

- **Wrong:** unanchored NPCs left on automatic ownership; `SetNetworkOwner` on an anchored part (errors) or a non-root part.
- **Right:** NPC root `SetNetworkOwner(nil)` on the server; ownership is per assembly. Projectiles: simulate on the server or cast on the server and render on clients. See [[Network Ownership]].
- From June 2026 the physics replication backend changed. If desync appears that your code did not cause, test `Workspace.ImprovedPhysicsReplication = Disabled` before rewriting (see [[Server Authority and Input Migration 2026]]).

## 8. Humanoid assumptions

- **Wrong:** `FloorMaterial ~= Air` as "grounded" for gameplay refills; `Humanoid.WalkSpeed` checks on the server as anti-speed; assuming every character uses Humanoid movement.
- **Right:** **Measured:** the Humanoid reports a floor on steep walls, which enabled a wall-jump exploit; check the floor normal with a downward raycast. The server sees the client-simulated position, so speed checks must use position deltas over time. Games may use the **Character Controller Library** (released April 11, 2026), where Humanoid movement properties may not drive movement. See [[Characters and Humanoids]].

## 9. Spatial queries

- **Wrong:** treating `GetPartBoundsInBox` hits as exact contact.
- **Right:** **Measured:** it tests bounding boxes, so a large curved mesh reports overlaps in empty air. Confirm with a raycast or `GetPartsInPart` for precise geometry. See [[Raycasts Shapecasts and Spatial Queries]].

## 10. Scale

- **Wrong:** scaling a rig in Studio to fix an import, then playing clips authored at the old scale.
- **Right:** animation translations scale with `Model:GetScale()`, but body-scaled avatars report 1. Fix scale at export, not in Studio (see [[Scale and Animation]] and [[AI Pitfalls - Assets and Import]]).

## Common mistakes

- Debugging a pose in world space when the error is in the joint frame.
- Tuning animation playback speed to hide foot sliding; fix strides at the source (**Measured**: forcing 2-4x rates looked frantic).
- Expecting Edit-mode previews to match Play.

## Checklist

- [ ] No per-frame `C0` writes; procedural layers use `Transform` in `PreSimulation`.
- [ ] Every track has an explicit priority; no `.Value` sorting.
- [ ] Attack clips that play while moving have no lower-body keys.
- [ ] Animator is server-created; tracks loaded once.
- [ ] Root motion on a child joint.
- [ ] NPC roots server-owned.
- [ ] Animations tested in a published or team-test server, not only Studio.

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Motor6D Math and CFrame Composition]]
- [[Playback, Priorities and Blending]]
- [[Rigs and Joints]]
- [[Debugging Physics and Network Ownership]]
- [[Mover Constraints and Physics Controllers]]
- [[Procedural Animation]]
