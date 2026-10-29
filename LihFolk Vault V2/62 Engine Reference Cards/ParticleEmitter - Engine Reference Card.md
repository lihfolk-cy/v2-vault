---
tags: [reference, engine, particleemitter, api/ParticleEmitter, type/reference, area/scripting, level/intermediate, api/Emit, api/LightInfluence, area/vfx]
---

# ParticleEmitter - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: copying Studio-tuned values into `Instance.new` emitters without setting `LightInfluence`.
> - Avoid: `Rate` above 400 or `Lifetime` above 20.
> - Avoid: toggling `Enabled` for a one-shot hit.
> - Bursts via `Emit`, sustained effects via `Rate`; budgets stay under 400/s per emitter.
> - `LightInfluence`, `LightEmission` and `Brightness` set explicitly in scripts.
> - Emitters cleaned up after `Lifetime.Max` with `Debris` or a delayed `Destroy`.
>
> Cost: TL;DR ~150 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Spawns textured 2D particles from a BasePart or Attachment, either continuously by `Rate` or in bursts with `Emit`. Topic notes: [[Particle Emitters In Depth]], [[VFX Performance Budgets and Culling]], [[Replicating VFX - Server Validates, Clients Render]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Enabled | prop | boolean | true | false stops new particles; live ones finish their lifetime | no |
| Rate | prop | number (particles/s) | 20 | Changing it leaves live particles alone | no |
| Emit | method | `(particleCount: number?)` | 16 | Instant burst; ideal for hits and pickups | no |
| Lifetime | prop | NumberRange (s) | 5 to 10 | Stored per particle; 0 means nothing emits | no |
| Speed | prop | NumberRange (studs/s) | 5 to 5 | Random per particle | no |
| SpreadAngle | prop | Vector2 (degrees) | `0, 0` | Replaces deprecated `VelocitySpread` | no |
| EmissionDirection | prop | `Enum.NormalId` | `Top` | Face the particles leave from | no |
| Shape / ShapeStyle / ShapeInOut / ShapePartial | prop | `Enum.ParticleEmitterShape` / ... / number | `Box` / `Volume` / `Outward` / 1 | Emission volume when parented to a part | no |
| Size / Transparency / Squash | prop | NumberSequence | 1 / 0 / 0 | Curves over each particle's life | no |
| Color | prop | ColorSequence | white | Tints the texture | no |
| Texture | prop | ContentId | built-in sparkles | Flipbooks need a 1024 x 1024 sheet | no |
| LightEmission | prop | number 0-1 | 0 | 1 = additive blending (glows) | no |
| [[LightInfluence]] | prop | number 0-1 | 0 from `Instance.new`, 1 from Studio | How much scene lighting tints particles | no |
| Acceleration / Drag | prop | Vector3 / number | `0, 0, 0` / 0 | Gravity-like pull and slow-down | no |
| WindAffectsDrag | prop | boolean | false | Follows `Workspace.GlobalWind` when `Drag` > 0 | no |
| LockedToPart | prop | boolean | false | Live particles move with the emitter | no |
| VelocityInheritance | prop | number 0-1 | 0 | Share of the parent part's velocity | no |
| Orientation | prop | `Enum.ParticleOrientation` | `FacingCamera` | `VelocityParallel` for streaks and sparks | no |
| FlipbookLayout / FlipbookMode / FlipbookFramerate | prop | `Enum.ParticleFlipbookLayout` / `Enum.ParticleFlipbookMode` / NumberRange | `None` / `Loop` / 1 fps | Grid2x2, Grid4x4, Grid8x8 or Custom | no |
| TimeScale | prop | number 0-1 | 1 | 0.5 = half speed, 0 = frozen | no |
| [[LocalTransparencyModifier]] | prop | number | - | Per-client fade; does not replicate | no |

## Limits and defaults

- Up to 400 particles per second per emitter (100 per second on mobile), per the Particle Emitters guide.
- Particle lifetime caps at 20 s; larger `Lifetime` values are clamped to 20.
- `FlipbookFramerate` maxes out at 30 frames per second; flipbook textures must be 1024 x 1024.
- `Emit` defaults to 16 particles when called with no count.
- `LightInfluence` is 1 when inserted with Studio tools and 0 from `Instance.new`, matching [[Engine Limits, Quotas and Defaults - Cheat Sheet]].

## Replication and authority

- An emitter in Workspace replicates like any instance, and server property changes reach everyone.
- Particles are drawn on each client, so cosmetic bursts are best triggered on the clients that see them.
- For combat and ability bursts, the server validates the action and fires a remote; each client clones the emitter and calls `Emit` locally.

## Common mistakes

- Avoid: copying Studio-tuned values into `Instance.new` emitters without setting `LightInfluence`. Symptom: particles look brighter or flatter than the tuned version.
- Avoid: `Rate` above 400 or `Lifetime` above 20. Symptom: the effect is sparser or shorter than designed, and sparser still on phones.
- Avoid: toggling `Enabled` for a one-shot hit. Symptom: a smeared trickle instead of a punch; use `Emit(n)`.
- Avoid: a flipbook on a texture that is not 1024 x 1024. Symptom: the flipbook does not animate.
- Avoid: `VelocitySpread` in new code. Symptom: deprecated property; use `SpreadAngle`.
- Avoid: destroying the emitter right after `Emit`. Symptom: the burst vanishes; wait out the maximum lifetime first.

## Checklist

- Bursts via `Emit`, sustained effects via `Rate`; budgets stay under 400/s per emitter.
- `LightInfluence`, `LightEmission` and `Brightness` set explicitly in scripts.
- Emitters cleaned up after `Lifetime.Max` with `Debris` or a delayed `Destroy`.
- Effects tested on a phone for the 100/s cap.

Source: https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter and https://create.roblox.com/docs/effects/particle-emitters - verified 2026-10-29

<!-- related:start -->
## Related
[[Designing VFX Textures and Flipbooks in Figma]] · [[BillboardGui - Engine Reference Card]] · [[SoundService - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[ScrollingFrame - Engine Reference Card]] · [[Workspace - Engine Reference Card]] · [[Animator - Engine Reference Card]]
<!-- related:end -->
