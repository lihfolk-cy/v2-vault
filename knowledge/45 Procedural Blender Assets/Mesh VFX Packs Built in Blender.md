---
tags: [blender, vfx, meshes, textures, roblox]
---
# Mesh VFX Packs Built in Blender

![[p45_mesh_vfx_pack.png]]

A first VFX preview built in Studio from Parts and ParticleEmitters was called "incredibly weak". The rebuild made the effects as meshes in Blender with painted alpha textures, the way most good Roblox VFX are made (meshes animated with transparency and scale tweens, see [[VFX Design Playbook]]). Four effects were built: a crescent slash, an impact burst, a fire aura and a lightning strike.

## Why meshes beat Parts and default particles

- A crescent slash needs a curved ribbon whose width and alpha fade along its length. Parts can only approximate this with many segments; a mesh with UVs along the arc does it with one draw call.
- Painted textures carry the detail: streaks, a hot leading edge, dissolving tails. Flat neon Parts have none.
- Built-in particle textures are generic; a painted ring or flame texture is specific to the effect.

## The parts that made each effect

| Effect | Meshes | Texture |
|---|---|---|
| Crescent slash | Crescent ribbons (width swells toward the head, tapers at both tips): dark under-layer, glow layer, core, 6 thin wisps, motion afterimages, an X-crossing second swing, shard sparks, speed streaks, a flare card | Strip texture: U along the arc, V across; alpha fades toward the tail, a hot edge line, streaks, a noise dissolve at the tail |
| Impact burst | Scorch decal disc, three shock rings (flat, mid, a jagged crown), two tiers of spike shards, a tapered light pillar, smoke puffs, debris rocks with ember trails, crossed flash cards | Ring texture (V radial: bright lip, noisy inner smear), scorch (ridged-noise cracks glowing in char), pillar streaks, 4-point flash |
| Fire aura | Rune circle, ground burn, four nested flame shells with tongue silhouettes, a core column, uneven swirl ribbons, loose flame wisps, ember shards | Flame texture (V = height, domain-warped tongues), rune circle (rings, ticks, glyph band), swirl strip |
| Lightning strike | Fractal bolt as two crossed flat ribbons (reads from any side), branches and twigs, a ghost bolt behind, a sigil ring at the origin, a strike pillar, ground cracks, sparks | Bolt strip (thin white core, violet halo, flicker breaks), void pillar, void runes |

## Techniques worth reusing

- **2D fractal noise in numpy** for all textures, written to PNG through `bpy.data.images` and `pixels.foreach_set`. Tile the noise horizontally when the texture wraps around a ring.
- **Crossed ribbons for bolts.** Two perpendicular flat strips read as a glowing line from any angle without the tube look.
- **Nested shells for fire.** Three or four flame shells of decreasing radius and height, each with its own tongue count, give depth for very few triangles.
- **Uploading textures.** A local HTTP server in the texture folder plus Studio's image upload returns asset ids for every texture in one call.
- **Importing meshes is manual.** File > Import 3D with Merge Meshes off; then apply the uploaded textures and animate with TweenService.

## Look and render rules

- Strong bloom drowned detail; a bloom strength around 0.6 with a threshold near 1.2 kept the shapes readable.
- The owner liked the stage (dark backdrop, colours) and only wanted the effects themselves improved: when feedback is about one thing, change only that thing.

Related: [[Beams and Trails]], [[Particle Emitters In Depth]], [[Dramatic Showcase Renders in Eevee]], [[Procedural Blender Assets Start Here]].

## Nuances and edge cases

1. **Mesh VFX cost instances, not particles.** A crescent slash built from a dark layer, a glow layer, a core, six wisps and afterimages is ten or more MeshParts per swing. In a one-player preview that is nothing. In a 30-player arena where everyone swings twice a second, it is hundreds of short-lived instances a second on every client. Pool the meshes (create once, reuse, reset transparency and size), and give each effect a "low" version with two or three layers for crowded fights and weak devices (rule of thumb).
2. **Who spawns the effect.** If the server creates the meshes, every one replicates to every client with network delay, and the slash arrives after the hit. Spawn VFX on each client in response to one small remote or attribute change that says "this player swung, here is the direction". The server decides the hit; clients draw the picture.
3. **Transparency sorting.** Several semi-transparent layers stacked at the same position can flicker or swap draw order as the camera moves, because transparent surfaces are sorted per object, not per pixel. Offset layers slightly, keep the number of overlapping transparent layers small, and test from many angles, especially in first person.
4. **Tweening many properties at once.** Each Tween is cheap but not free. Ten layers, each tweening Size, CFrame and Transparency, is thirty tweens per swing. For effects that fire constantly, drive all layers from one RenderStepped or Heartbeat loop with a shared progress value instead of one tween per property.
5. **Texture memory.** Painted alpha textures are the detail that makes these effects good, but every unique texture costs memory on every client that has seen it. Four effects with four or five textures each is fine; forty effects with unique 1024 textures each is a phone memory problem. Share strip, ring and flame textures across effects and recolour them where possible.
6. **Bloom is a global setting.** The render used tuned bloom, but in a game the Bloom effect lives in Lighting and affects the whole scene. Tuning bloom so a slash glows can make every bright UI-coloured part and sky glow too. Get the glow from the texture and the Neon material first and keep scene bloom moderate.
7. **Photosensitivity.** Lightning with flicker breaks and a full-screen flash card can produce rapid bright flashes. Keep flashes short and few, avoid strobing faster than a few times a second, and offer a reduced-flash setting.
8. **Readability at speed.** An effect judged in a slow-motion render can be invisible at real speed. Judge every effect at game speed, at the distance and camera angle players use, on a phone screen.

## Common mistakes

1. **Merge Meshes left on at import.** Symptom: every layer arrives as one mesh, so layers cannot fade or scale separately. Fix: import with Merge Meshes off, as this pack does.
2. **Meshes collidable or queryable.** Symptom: slashes block players, trip hitbox raycasts or shift physics. Fix: set CanCollide, CanTouch and CanQuery false on every VFX mesh, and set Anchored true.
3. **Destroying and recreating per hit.** Symptom: frame spikes during busy fights and growing memory. Fix: pool and reuse the meshes.
4. **UV direction reversed.** Symptom: the slash fades toward the head instead of the tail. Fix: keep U along the arc and test with a gradient texture before painting the real one.
5. **Tiled noise seam on rings.** Symptom: a visible line on shock rings. Fix: make noise tile horizontally for any texture wrapped around a ring.
6. **Every effect on the server.** Symptom: effects lag behind the action, and server bandwidth climbs with player count. Fix: fire one event, build the visuals on each client.
7. **Only testing on PC.** Symptom: effects fine on desktop, dropped frames on phones. Fix: test the busiest scene on a low-end device and switch to the low version where needed.

## Related decisions

- [[VFX Performance Budgets and Culling]]: how many of these layers a scene can afford.
- [[Juice on a Budget - Mobile and Low-End]]: designing the cheap version of each effect.
- [[Feedback Timing - Sound Visual and Haptic Sync]]: lining the slash up with sound and hit frames.
- [[Hit-Stop and Screen Shake Tuning by Numbers]]: what plays alongside an impact burst.
- [[Tween and CFrame Animation of Objects]]: animating the mesh layers.
- [[Textures Decals and Texture Memory]]: the memory cost of painted alpha textures.
- [[Motion Sensitivity and Camera Comfort]]: flashes and motion that can hurt some players.
- [[Interest Management and Per-Player Replication]]: sending effect events only to players who can see them.
- [[Combat Systems Architecture]]: where the "swing happened" event comes from.

## Connected notes
<!-- auto-links:start -->
[[Dash VFX Presentation on an R15 Rig]] · [[VFX Timing with Animation]] · [[Stylised Weapons From a Concept]] · [[Light Sources and Shadows]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Hand-Painted and Stylized Texturing]]
<!-- auto-links:end -->
