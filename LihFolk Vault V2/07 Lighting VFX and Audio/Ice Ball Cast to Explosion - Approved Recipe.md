---
tags: [vfx, animation, ice, projectile, explosion, recipe, cast, lihfolk, type/guide, area/vfx, level/intermediate, area/animation]
verified: 2026-10-29
---
# Ice Ball Cast to Explosion: Approved Recipe

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Wide, static camera for a hand-scale effect: the charge becomes invisible.
> - Avoid: Flash on the impact frame hiding the landing.
> - Avoid: Thin shard spikes and flat disc rings: they read as glass and water, not ice.
> - Markers `ChargeStart`, `Release`, `Impact` on the clip
> - Charge readable at game camera distance (test zoomed out too)
> - Projectile and explosion stay in front of the caster
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## Timing (30 fps, 3.7 s) · ## What made v2 work (v1 → v2, Measured) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A full spell sequence (charge in hand, throw, flight, ice explosion, recover) that the LihFolk owner approved as the reference for future ability VFX ("ice ball v2 is awesome"). Use it as the template for any cast-and-throw ability: fireball, void orb, lightning spear. Clip: `IceCastThrow` (LihFolk Asset Pack, Animations/Combat). Luau: `LihFolkVFX.playIceBallCast(track, character)` in the `lihfolk-vfx` skill, **untested in Studio**. Preview: `VFX/Previews/IceBall_Cast_to_Explosion.mp4`.

## Timing (30 fps, 3.7 s)

| Beat | Frames | What happens |
|---|---|---|
| Ready | 0-11 | Neutral stance |
| Charge | 12-48 (`ChargeStart` f12) | Frost motes and mist spiral **into** the palm; the ball grows from a seed with a small overshoot; the off arm braces, a slight crouch and lean back |
| Wind-up and throw | to f49 (`Release`) | Ball drawn back, torso coils, then hips lead, the shoulder rotates internally, the elbow extends, the wrist snaps |
| Flight | 49-63 | About 0.5 s on a slight arc, in front of the character, frost trail and shed sparkles |
| Impact | f64 (`Impact`) | The ball stays visible until it touches the ground; the explosion starts **1 frame later** |
| Explosion | 64-90 | Small fast flash (0.6x), frosted crackle ring, chunky faceted crystal spikes, shatter, low mist |
| Recover | 90-110 | Back to ready |

## What made v2 work (v1 → v2, Measured)

- **Camera follows the beat:** tight during the charge (character about 45% of frame height, ball readable), pull back for the throw and flight, settle on the impact. v1's wide static camera made the character tiny and the ball muddy.
- **Readable ball:** white core glow, pale-cyan faceted body, strong rim and glints; brighter, denser motes in a tighter spiral close to the hand.
- **A real whip:** kinematic chain hips → torso → shoulder → elbow → wrist, with the planted foot staying flat through release and rolling on its toe only after. Foot slide went from 0.39 to 0.0004 studs. v1 read as a push.
- **Impact readability:** don't cover the landing with the flash. Delay it a frame and shrink it; pull shards and mist toward the camera so the spikes don't hide them.
- **Ice look:** chunky hexagonal crystal clusters (white edge, pale cyan body, deep blue core) beat thin glass shards; a crackled frost ring with feathery edges beats a flat white disc.
- **Colour:** previews must convert Roblox sRGB colours correctly or everything washes out (see [[VFX Previews in Blender for Roblox - Colour and Framing]]).

## Preferred charge pose (owner reference, 2026-10-29)

For ball-forming charges the owner prefers a **two-handed, grounded charge** over a single raised palm: a deep wide lunge with hips dropped, torso leaning toward the hands, head down watching the energy, **both hands cupped together at hip or waist height** (one palm above, one below) with the ball forming between them, elbows tucked and shoulders tense. The ball lights the hands, forearms and face; ground mist swirls at the feet. Sink in with a dip-and-settle anticipation, hold with a subtle tremble while the ball grows, then draw it back to one hand for the throw.

## Known issues (open)

- Arm overlap during the whip: head and right upper arm up to 0.28 studs, torso and forearm 0.26 (41 frames over 0.05).
- Forearm roll peaks around 36 deg/frame during the throw; plan a single pronation curve ([[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]]).
- The Luau sequence (weld growth, raycast landing point, timing) has never run in Studio.

## Common mistakes

- Wide, static camera for a hand-scale effect: the charge becomes invisible.
- Flash on the impact frame hiding the landing.
- Thin shard spikes and flat disc rings: they read as glass and water, not ice.
- Throws without hip lead and wrist snap: they read as pushing.
- Judging colour from a preview without sRGB conversion.

## Checklist

- [ ] Markers `ChargeStart`, `Release`, `Impact` on the clip
- [ ] Charge readable at game camera distance (test zoomed out too)
- [ ] Projectile and explosion stay in front of the caster
- [ ] Flash delayed 1 frame and smaller than the explosion body
- [ ] Planted foot doesn't slide through release
- [ ] Tested once in Studio on PC and phone

## See also

- [[VFX Readability and Value - Lessons from Blind Reviews]] (the general rules behind this recipe: small late flash, forward-biased release burst, saturated ink)
- [[Escalation and Grandeur Without Clutter]]
- [[Slash VFX Recipes - Crescent and Ring]]
- [[Human Swing Biomechanics]]
- [[VFX Previews in Blender for Roblox - Colour and Framing]]

## Connected notes

[[VFX Design Playbook]] · [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]]

<!-- related:start -->
## Related
[[Projectile VFX - Muzzle, Travel and Impact]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Auras, Shields and Status Effects]] · [[AoE Telegraphs - Readable Ground Warnings]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[Replicating VFX - Server Validates, Clients Render]] · [[Beams and Trails]] · [[Light Sources and Shadows]]
<!-- related:end -->
