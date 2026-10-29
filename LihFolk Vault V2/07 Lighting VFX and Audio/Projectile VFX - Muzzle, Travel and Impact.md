---
tags: [vfx, projectile, muzzle-flash, trail, impact, homing, combat, prediction, lihfolk, type/guide, area/vfx, level/intermediate, api/Trail, api/ParticleEmitter]
---
# Projectile VFX - Muzzle, Travel and Impact

<!-- tldr:start -->
> [!tldr] TL;DR
> - Shot reads as a dot: Trail too short for its speed -> Lifetime so that speed x lifetime is 12-30 studs
> - Shot reads as a laser: Trail too long, or no taper -> `WidthScale` 1 to 0, transparency rising to 1
> - Flat, one-colour core: No hot centre or dark layer -> Hot inner ball plus a dark wake
> - Muzzle 1-2 studs ahead of the hand, flash about 0.6x the impact flash, sparks forward.
> - Core has a hot centre and a body colour; dark elements use a rim shell.
> - Trail streak is 12-30 studs (speed x lifetime) and tapers.
>
> Cost: TL;DR ~170 tok · whole note ~2.4k tok. Read more: ## 3. The travelling core · ## 5. The impact · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A projectile effect has three beats: the **muzzle** says "it left", the **travelling core** says "here it comes, this way", and the **impact** says "it landed, right here". This note gives numbers for each beat, a homing step that looks intentional, and the networking shape for a visual that starts on the caster's frame. The simulation, hit maths and server validation live in [[Projectiles and Ballistics]]; the prediction and fast-forward pattern in [[Client Prediction and Reconciliation for Combat]]; trail and beam behaviour in [[Beams and Trails]]; emitter properties in [[Particle Emitters In Depth]]; value and flash rules in [[VFX Readability and Value - Lessons from Blind Reviews]]. A working implementation is `Projectile` in the LihFolk VFX skill (`LihFolkVFX_Abilities.luau`).

Source labels: **Roblox docs**, **LihFolk module** (values shipped in `LihFolkVFX_Abilities`, untested in Studio at the time of writing), **rule of thumb**.

---

## 1. The three beats on one clock

| Beat | Starts | Lasts | Job | Main layers |
|---|---|---|---|---|
| Muzzle | cast frame | 2 frames (0.05-0.07 s) flash, sparks 0.16-0.3 s | direction and commitment | small flash, forward spark cone |
| Travel | cast frame | distance / speed | position, speed, element | Neon core with a hot centre, tapered Trail, wake particles, one light |
| Impact | contact | 0.8-0.9 s total | location and weight | flash 1 frame after contact, sparks around the normal, chips, surface rings, light pulse |

Keep the muzzle smaller than the impact: a muzzle flash about 0.6-0.7x the impact flash (LihFolk module: 1.8 vs 2.6 studs at scale 1) makes the landing the payoff (**rule of thumb**, from [[Escalation and Grandeur Without Clutter]]).

## 2. The muzzle

1. **Place it ahead of the hand**, 1-2 studs along the aim, so the flash never sits on the body.
2. **Flash:** one sprite, life 0.05-0.07 s, size ending about 1.25x its start, `LightEmission` 1.
3. **Sparks:** 6-10 streaks in a 20-25 degree cone along the aim, speed 18-34 studs/s, `Drag` 6, life 0.16-0.3 s, `Orientation = VelocityParallel`. They point the way the shot travels.
4. **Skip smoke on light shots.** A puff at the muzzle reads well on rockets and cannons; on a 3-per-second spell it becomes clutter.

## 3. The travelling core

### Layers

| Layer | Numbers (LihFolk module, scale 1) | Why |
|---|---|---|
| Body | Neon `Ball`, 0.9 studs, element colour | readable silhouette at any distance |
| Hot centre | Neon `Ball`, 0.5 studs, near white | the white-hot core of the value stack |
| Dark-element variant | body stays dark, a `ForceField` ball at 1.15 studs gives the rim | dark elements carry light in the rim, not the body |
| Trail | `Lifetime` 0.2, `WidthScale` 1 to 0, colour hot -> body -> deep, transparency 0.05 -> 0.45 -> 1, `FaceCamera` true | the streak shows speed and direction |
| Wake | `Rate` 36, life 0.22-0.36, `Drag` 5, size 0.55 to 0 | about 13 particles alive; texture for the path |
| Dark wake | `Rate` 12, life 0.35-0.5, `LightEmission` 0, dark colour | the third value layer; decoration (dropped at low quality) |
| Light | one `PointLight`, `Brightness` 1.4, `Range` 9, `Shadows` false | travels with the core, then becomes the impact pulse |

Streams are fine while the core flies; turn `Rate` to 0 at impact so the wake fades out on its own lifetime instead of being cut.

### Trail length is speed times lifetime

The streak behind the core is about `speed * Trail.Lifetime` studs long:

| Speed (studs/s) | Feel | Trail lifetime | Streak |
|---|---|---|---|
| 40-60 | slow orb, dodgeable | 0.3-0.4 s | 12-24 studs |
| 80-120 | standard spell or arrow | 0.18-0.25 s | 15-30 studs |
| 150-250 | fast bolt | 0.08-0.12 s | 12-30 studs |
| 300+ | effectively hitscan | use a Beam tracer instead | - |

Aim for a streak of 12-30 studs at your typical camera distance (**rule of thumb**): shorter reads as a dot, longer reads as a laser.

## 4. Homing that looks intentional

Homing feels fair when it **turns at a capped rate**. Snapping the direction to the target every frame looks like the projectile is glued to a string.

| Turn rate | Reads as |
|---|---|
| 45-90 deg/s | gentle seeker: can be outrun by a sidestep |
| 120-180 deg/s | strong seeker: curves round corners |
| 360+ deg/s | near-guaranteed hit; give it a slow speed or a long telegraph |

```lua
--!strict
-- Turn `dir` toward `want` by at most `turnRate` radians per second. Both are unit vectors.
local function steer(dir: Vector3, want: Vector3, turnRate: number, dt: number): Vector3
	local angle = math.acos(math.clamp(dir:Dot(want), -1, 1))
	if angle < 1e-4 then
		return dir
	end
	local k = math.min(1, (turnRate * dt) / angle)
	return dir:Lerp(want, k).Unit
end

return steer
```

Lerp then normalise is close to a true [[slerp]] for the small per-frame angles involved (a few degrees at 60 fps). The module takes `homing` in degrees per second and converts it once.

## 5. The impact

1. **Flash one frame after contact**, about 2.6 studs, so the contact frame is seen first ([[VFX Readability and Value - Lessons from Blind Reviews]]).
2. **Sparks around the surface normal**, 12-18 in a 60-70 degree cone, speed 22-40.
3. **Chips:** 6-8 dark flecks with gravity (`Acceleration` about -40), life 0.35-0.55 s; decoration.
4. **Surface rings aligned to the normal:** a bright ring 0.4 to 3.6 studs in 0.3 s, then a dark ring 0.6 to 4.4 studs in 0.42 s, starting 0.03 s later. Different size, speed and value, so two rings read as one shockwave instead of a stamp.
5. **Light pulse:** the travelling light moves to the impact, `Brightness` 3 to 0 over 0.2 s.
6. **Ground mark (optional):** a decal on a thin plate for 1.6 s, only when you have uploaded a texture for it.
7. **Air pop:** a shot that reaches max range plays the same impact with the normal facing back along its path.

Build a surface frame whose Y axis is the hit normal and lay rings flat in it; a world-up ring on a wall looks pasted on. `Workspace:Raycast` returns `RaycastResult.Normal` for exactly this.

## 6. Prediction and replay

- The **caster's client** plays the projectile on the input frame (zero latency) and sends a request ([[Replicating VFX - Server Validates, Clients Render]]).
- The **server** simulates and decides the hit ([[Projectiles and Ballistics]]). The visual's own wall raycast is only for where the visual stops; it never deals damage.
- **Onlookers** replay from one payload: muzzle CFrame, target position, element index, seed. For fast shots, fast-forward by the server time already elapsed ([[Client Prediction and Reconciliation for Combat]]).
- When the server confirms a hit somewhere the visual has not reached (a target dodged into it), call the handle's `Impact(position)` so the burst plays where the hit happened.

## 7. Budget

Per shot at quality 1 (LihFolk module): 9 muzzle particles, about 19 wake particles alive in flight, 25 at impact; 1 Trail, 1 light, 2 Neon parts, 2 ring adornments.

Worked arithmetic for a full server (**rule of thumb**): 8 players, 3 shots per second each, each shot alive about 2 s (1 s flight, 0.9 s impact) gives about 6 live shots per player and 48 in total. At about 30 particles each that is 1,440, above the 900 PC cap. The answer is the onlooker share: others' shots at half detail, culled beyond 220 studs, decoration (dark wake, chips, second ring) dropped beyond 160 studs, and the global cap halving counts above 75 percent ([[VFX Performance Budgets and Culling]]). Your own shots stay full.

---

## Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| Shot reads as a dot | Trail too short for its speed | Lifetime so that speed x lifetime is 12-30 studs |
| Shot reads as a laser | Trail too long, or no taper | `WidthScale` 1 to 0, transparency rising to 1 |
| Flat, one-colour core | No hot centre or dark layer | Hot inner ball plus a dark wake |
| Flash hides the landing | Flash on the contact frame | Flash one frame after contact, 2-3 studs |
| Rings look pasted on walls | Rings built in world up | Surface frame from the hit normal |
| Homing looks glued on | Direction snapped to the target | Cap the turn rate in degrees per second |
| Wake cut off at impact | Emitter destroyed with the core | Set `Rate` to 0, destroy after the longest lifetime |
| Lag with many casters | Every shot at full detail | Onlooker half detail, distance drops, live cap |

## Checklist

- [ ] Muzzle 1-2 studs ahead of the hand, flash about 0.6x the impact flash, sparks forward.
- [ ] Core has a hot centre and a body colour; dark elements use a rim shell.
- [ ] Trail streak is 12-30 studs (speed x lifetime) and tapers.
- [ ] One light per shot, no shadows, reused for the impact pulse.
- [ ] Homing uses a capped turn rate.
- [ ] Impact: flash 1 frame late, sparks around the normal, rings in the surface plane, life under 1 s.
- [ ] The visual starts on the caster's input; the server decides hits; onlookers replay one payload.
- [ ] Budget checked for a full server with the onlooker share.

<!-- related:start -->
## Related
[[Auras, Shields and Status Effects]] · [[VFX Design Playbook]] · [[Slash VFX Recipes - Crescent and Ring]] · [[AoE Telegraphs - Readable Ground Warnings]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]]
<!-- related:end -->
