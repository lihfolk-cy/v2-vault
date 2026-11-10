---
tags: [gameplay, combat, shooters, recoil, spread, bloom, headshots, hit-zones, game-feel, type/guide, area/gameplay, level/advanced, server-authority]
---
# Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Viewmodel kicks, crosshair still -> Pattern applied to the view
> - Avoid: Pure random recoil -> Authored pattern, small jitter
> - Avoid: Bloom not shown -> Crosshair size equals real cone
> - Recoil pattern per weapon with view recovery and index decay.
> - Spread from stance, movement and bloom; crosshair matches the cone.
> - Server validates shot direction against the maximum cone or a shared seed.
>
> Cost: TL;DR ~140 tok · whole note ~2.4k tok. Read more: ## 3. Spread and bloom · ## 4. Hit zones and multipliers · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Genre Playbook - Shooters FPS and TPS]] sets the design rules (learnable recoil, spread that grows with movement, TTK by range). This note is the implementation layer: how to split recoil into camera kick and aim offset, how to author and recover a recoil pattern, how to sample spread and bloom so the server can reproduce it, and how to map ray hits (including hats and accessories) to hit zones with multipliers. Hit registration and rewind are in [[Hitboxes and Hit Detection]]; viewmodel motion in [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Two kinds of recoil

| | Camera kick | Aim recoil |
|---|---|---|
| What moves | The view (camera rotation) | Where bullets go relative to the crosshair |
| Player control | Pulled down by the player | Pattern learned and compensated |
| Feel | Punch, weight | Skill ceiling |
| Recovery | Springs back toward the pre-fire view, partly | Pattern index decays when not firing |

Most shooters combine: each shot adds a pattern step to the **view** (so the crosshair moves and the player compensates by pulling down), plus a small, fast-recovering **visual** kick on the viewmodel and a tiny screen shake. If only the viewmodel kicks and the crosshair stays still, the gun feels weightless; if bullets leave the crosshair without the crosshair moving, it feels like random spread.

## 2. Authoring a recoil pattern

Store per weapon a list of `(pitch, yaw)` steps in degrees for shots 1..N, plus a small random jitter per step:

```lua
--!strict
export type Recoil = {
	pattern: { Vector2 },   -- x = yaw, y = pitch (degrees), per shot index
	jitter: number,         -- max random degrees added per shot
	recoverPerSecond: number, -- pattern index recovery when not firing
	viewRecover: number,    -- fraction of accumulated pitch the camera returns (0..1)
}

local AR: Recoil = {
	pattern = {
		Vector2.new(0, 0.9), Vector2.new(0.1, 0.8), Vector2.new(-0.1, 0.8), Vector2.new(0.2, 0.7),
		Vector2.new(0.35, 0.5), Vector2.new(0.4, 0.4), Vector2.new(-0.3, 0.4), Vector2.new(-0.5, 0.3),
	},
	jitter = 0.08,
	recoverPerSecond = 10,
	viewRecover = 0.6,
}
```

**Rule of thumb.** First shots mostly vertical (easy to learn), later shots drift sideways; loop the last few steps for long magazines. Keep jitter under about 20% of the step size or the pattern stops being learnable.

Client applies each step to the camera through an additive layer at camera priority, not by writing `Camera.CFrame` raw ([[Layering Camera Feedback on the Default Camera]]). Recovery: when the trigger is released, return `viewRecover` of accumulated pitch over 0.2 to 0.4 s with a spring, and decay the pattern index by `recoverPerSecond`.

## 3. Spread and bloom

**Spread** is a cone around the (recoiled) aim direction. **Bloom** is spread that grows with sustained fire and recovers when not firing.

```
cone = base(hip or aim) * stanceMult(crouch, stand, airborne) * moveMult(speed) + bloom
bloom += perShot (capped at maxBloom); bloom -= recover * dt when not firing
```

Typical shape: aim-down-sights base small, hip base 3 to 6 times larger, airborne 2 to 3 times; bloom adds up to the hip base.

**Sampling.** Uniform in a disk: radius `= tan(cone) * sqrt(u)`, angle `= 2 * pi * v`. Shotguns sample N pellets; use a fixed pellet pattern with small jitter rather than pure random for consistent damage.

**Server reproducibility.** Two options:
1. **Seeded spread**: the server gives the client a seed per magazine or per weapon equip; each shot `i` derives its random numbers from `Random.new(seed + i)`. The client renders the true spread; the server recomputes the same direction from the client's reported aim direction and shot index and checks they match within tolerance.
2. **Cone check**: the server accepts the client's ray direction if its angle from the reported aim is inside the maximum possible cone for the weapon's current state (state tracked on the server: fire rate, stance, speed).

Option 2 is simpler and adequate for most Roblox shooters. Never let the client report "cone = 0".

```lua
--!strict
local function inCone(aim: Vector3, shot: Vector3, maxConeDeg: number): boolean
	local cosAngle = aim.Unit:Dot(shot.Unit)
	return cosAngle >= math.cos(math.rad(maxConeDeg + 0.25)) -- small tolerance
end

local function sampleSpread(aim: Vector3, coneDeg: number, rng: Random): Vector3
	local cf = CFrame.lookAt(Vector3.zero, aim)
	local r = math.tan(math.rad(coneDeg)) * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber() * math.pi * 2
	return (cf.LookVector + cf.RightVector * r * math.cos(a) + cf.UpVector * r * math.sin(a)).Unit
end
```

## 4. Hit zones and multipliers

| Zone | Parts (R15) | Typical multiplier |
|---|---|---|
| Head | `Head` | 1.5 to 2.0 (snipers up to 2.5 to 4) |
| Torso | `UpperTorso`, `LowerTorso`, `HumanoidRootPart` | 1.0 |
| Arms | `*UpperArm`, `*LowerArm`, `*Hand` | 0.8 to 0.9 |
| Legs | `*UpperLeg`, `*LowerLeg`, `*Foot` | 0.75 to 0.9 |

**Accessories.** Raycasts hit accessory handles (hats, hair, backpacks) unless you filter them. A large hat should not grant a headshot two studs above the head, and a backpack should not absorb bullets. Options:
- Exclude accessories from weapon raycasts (collision group or filter list; handles inside `Accessory` instances), and test against body parts only.
- Or map an accessory hit to the body part it is attached to (the part its `AccessoryWeld` connects to), then **re-check** that the ray passes within a small distance of that part; otherwise ignore the hit and continue the ray.

Remember that avatars differ in body scale and proportions: a hitbox based on real limbs gives tall or wide avatars bigger hitboxes. Competitive games often normalise with invisible uniform hitboxes or force a standard body ([[Characters and Humanoids]]).

**Rule of thumb.** Headshot multiplier sets the skill ceiling. Make sure body-shot TTK is still viable (2x headshot with 4 body shots to kill is a common baseline) and cap the product with crits or weak-point bonuses ([[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]]).

## 5. Feedback that sells the shot

- **Fire**: muzzle flash (one frame of light and a flipbook), tracer for every Nth bullet on automatics, shell eject, sound with slight pitch variation, crosshair expansion matching the real cone (players learn bloom from it).
- **Hit**: hitmarker (distinct for head), short hit sound, damage number, blood or spark on the target; on kill, a distinct kill sound and marker ([[Combat Sound Design and Feedback]]).
- **Latency**: play fire feedback instantly on the client; hit feedback can be predicted locally and corrected by the server confirm ([[Client Prediction and Reconciliation for Combat]]).
- **Mobile**: smaller recoil (thumb aiming is slower to compensate), slightly larger aim-assist friction near targets, and an auto-fire option.

## 6. Tuning loop

Record test patterns: fire full magazines at a wall at 25 and 50 studs without compensation and with compensation; screenshot the groupings. Each weapon class should have a recognisable grouping. Log server-side hit rates by zone and weapon in live games; a weapon with unusually high headshot share often has spread too small at hip ([[Balancing with Spreadsheets and Data]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Viewmodel kicks, crosshair still | Weightless guns | Pattern applied to the view |
| Pure random recoil | Unlearnable, unfair | Authored pattern, small jitter |
| Bloom not shown | Players blame hit reg | Crosshair size equals real cone |
| Accessories count as heads | Headshots on big hats | Filter or map plus re-check |
| Client-reported cone | No-spread exploits | Server tracks state; cone check |
| Writing camera CFrame directly for kick | Drift and fights with camera scripts | Additive layer, removed each frame |

## Checklist
- [ ] Recoil pattern per weapon with view recovery and index decay.
- [ ] Spread from stance, movement and bloom; crosshair matches the cone.
- [ ] Server validates shot direction against the maximum cone or a shared seed.
- [ ] Hit zones mapped from R15 parts; accessories filtered or re-checked.
- [ ] Headshot multipliers capped in the damage pipeline.
- [ ] Grouping tests per weapon at two ranges; zone hit rates logged.

## See also
[[Genre Playbook - Shooters FPS and TPS]] · [[Hitboxes and Hit Detection]] · [[Projectiles and Ballistics]] · [[Procedural Weapon Motion]] · [[Camera Shake and Camera FX]] · [[Detecting Combat Exploits - Reach Rate and Aim]]

## Connected notes
<!-- auto-links:start -->
[[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · Time-to-Kill Math and a Weapon Balance Sheet · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · Game Feel and Juice
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Teardown - Phantom Forces]] · [[Time-to-Kill Math and a Weapon Balance Sheet]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[Combat Systems Architecture]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Camera Systems]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Custom Character Controllers]]
<!-- related:end -->
