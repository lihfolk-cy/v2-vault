---
tags: [blender, python, vfx, eevee, r15, animation, rendering, bloom, video, type/guide, area/modeling, level/intermediate]
---
# Dash VFX Presentation on an R15 Rig

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Empty renders after opening a rig file. Cause: the collection is excluded or unlinked.
> - Avoid: Ghosts in the wrong place. Cause: offsetting a world-space bake by the absolute path position.
> - Avoid: Dark shapes under the effects. Cause: FX casting shadows.
> - Rig collection linked and un-excluded; old lights and cameras removed
> - Anticipation, short action, long follow-through
> - One additive material type; fades keyed on a Value node
>
> Cost: TL;DR ~150 tok · whole note ~3.7k tok. Read more: ## The glow material · ## Light, camera and shadows · ## Common mistakes · ## Checklist
<!-- tldr:end -->

![[p45_dash_burst.png]]

A two-second presentation of a dash ability, rendered from one Python script: a blocky R15 character crouches, bursts forward 17 studs in five frames and lands. Around it: five fading afterimages, energy ribbons along the path, speed lines, a launch burst (ring, shards and dust), a ground streak, sparkles, a travelling point light and a hit of camera shake, all finished with bloom and written to an MP4. The character is the vault's `R15_Blocky` rig from [[Skeleton Library]]. The script is `scripts/build_dash.py`.

The goal is a showcase clip and a set of stills for an ability (store page, devlog, design review), and a reference for the in-game version. Numbers are measured in this build (Blender 5.2, October 2026) unless marked rule of thumb.

## Timeline

48 frames at 24 fps:

| Frames | Beat |
|---|---|
| 1 to 9 | Idle into crouch; the burst ring charges at the feet; the point light warms up |
| 10 to 15 | The dash: 17 studs in 5 frames on a cubic ease-out, with a 0.35 stud hop arc |
| 11 to 13 | Peak: afterimages appear one per frame, ribbons and speed lines flash on, shards fly, camera shakes |
| 16 to 24 | Landing crouch and recovery; trails fade |
| 25 to 48 | Settle; sparkles drift up and fade |

Anticipation (crouch), a very short action and a long follow-through is the standard shape for a fast ability ([[VFX Design Playbook]]). The action is only five frames; everything else is there to make those five frames readable.

## Loading the rig: the excluded collection trap

```python
bpy.ops.wm.open_mainfile(filepath=RIG_BLEND)    # 18 Rigs and Skeletons/R15_Blocky/R15_Blocky.blend
for c in bpy.data.collections:
    if c.name not in scene.collection.children and not any(c.name in p.children for p in bpy.data.collections):
        scene.collection.children.link(c)
def unexclude(lc):
    lc.exclude = False; lc.hide_viewport = False
    for ch in lc.children: unexclude(ch)
unexclude(bpy.context.view_layer.layer_collection)
```

The rig file's collection loads excluded from the view layer (or not linked to the scene at all). Its objects exist in `bpy.data`, so a script can find the armature and pose it without errors, but excluded parts **neither render nor deform**: the first renders showed an empty stage. Link every orphan collection to the scene, then clear `exclude` and the hide flags recursively. The script also removes the file's own lights and cameras so they do not fight the staging.

The body parts get flat classic colours (yellow skin, blue shirt, dark trousers), chunky 0.07 stud bevels and smooth shading. A simple face is added by creating small boxes inside the head's bmesh and weighting them fully to the `Head` vertex group, so the face follows the head bone with no extra object.

## Posing

Poses are tables of degrees about the lateral axis, applied with the same world-to-bone axis helper used in [[Low-Poly Creature From a Flat Reference Sheet]]. The character faces -Y, so a positive angle swings a hanging limb backward and tips the torso forward:

```python
DASH = {"LowerTorso": 12, "UpperTorso": 22, "Head": -22,
        "LeftUpperArm": 75, "RightUpperArm": 62, "LeftUpperLeg": -62, "LeftLowerLeg": 78, ...}
pose({}, 1); pose(CROUCH, 8); pose(CROUCH, T0 - 1); pose(DASH, T0 + 1); pose(DASH, T1 + 4); pose({}, 32)
```

The head counter-rotates (minus 22) against the torso lean so the eyes stay on the direction of travel. The armature object carries the translation: crouch down 0.85 studs, then the eased dash.

## The glow material

Every effect uses one additive material: a Transparent BSDF plus an Emission through an Add Shader, with the emission strength driven by a Value node so it can be keyframed.

```python
tr = nt.nodes.new("ShaderNodeBsdfTransparent"); em = nt.nodes.new("ShaderNodeEmission")
val = nt.nodes.new("ShaderNodeValue")
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = strength
nt.links.new(val.outputs[0], mul.inputs[0]); nt.links.new(mul.outputs[0], em.inputs["Strength"])
add = nt.nodes.new("ShaderNodeAddShader")
nt.links.new(tr.outputs[0], add.inputs[0]); nt.links.new(em.outputs[0], add.inputs[1])
m.surface_render_method = "BLENDED"
```

- **Transparent plus emission, added** behaves like additive blending: the surface hides nothing behind it and only adds light. Overlapping ribbons get brighter, never muddier, which is what energy effects should do.
- **`surface_render_method = "BLENDED"`** is the Blender 5 Eevee setting that makes the transparency render; the script tries the older `blend_method` too inside a try block.
- **Fades are keyframes on the Value node's output,** one helper call per effect:

```python
def fade(val, keys):
    for f, v in keys: val.outputs[0].default_value = v; val.outputs[0].keyframe_insert("default_value", frame=f)
```

Every object that shares a material shares its fade, so 60 sparkles fade as one. For staggered fades, give each group its own material.

## Afterimages from the evaluated, posed mesh

```python
scene.frame_set(T0 + 2); dg = bpy.context.evaluated_depsgraph_get()
bake_y = rig.matrix_world.translation.y
gb = bmesh.new()
for o in PARTS:
    em = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); em.transform(o.matrix_world); gb.from_mesh(em)
```

At a frame mid-dash, each body part's evaluated mesh (armature deform and bevel applied) is copied, moved to world space and merged into one ghost mesh. Five copies are placed along the path at the positions the character passes on frames 10 to 14, coloured cyan to blue to violet, each slightly stretched along the travel axis (4 to 20 percent) and each fading in on its own frame, to half by 3 frames later and out by 10.

**The offset trap:** the ghost mesh is already in world space at the rig's position on the bake frame. Placing a copy at the path position `y` therefore needs `y - bake_y`, not `y`. Using `y` directly doubles the offset and the ghosts appear several studs ahead of the character.

## Ribbons with a UV gradient

Six ribbons run along the path, each a strip of 40 segments with a sine wave sideways and vertically, widening from 25 percent at the tail to full width at the head, some twisted. UVs run u along the length and v across:

```python
for (a0, b0, u0), (a1, b1, u1) in zip(rows, rows[1:]):
    f = bm.faces.new((a0, a1, b1, b0))
    for l, uv in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))): l[uvl].uv = uv
```

The ribbon material multiplies the emission strength by `u ** power` (bright at the head, fading to the tail, power 1.6) and by `1 - |2v - 1|` (bright in the centre line, zero at the edges), and mixes the colour from a tail colour to a head colour along u. The edge falloff is what turns a flat strip into a soft energy trail; without it, ribbons show hard rectangular edges. This is the shader version of a Beam's transparency sequence ([[Beams and Trails]]).

## Speed lines, burst and streak

- **Speed lines:** 16 thin quads (3 to 7 studs long, under 0.1 wide) parallel to the path, 1.6 to 4.5 studs either side of it, with the same ramp material. They flash on for one frame at launch and fade over 9.
- **Burst ring:** a flat 40-segment ring (inner radius 1.0, outer 1.35) at the start point, scaling from 0.2 during the crouch to 5 after launch while its strength rises to 1.4 and drops to zero. It charges before the dash, so the launch has a cause.
- **Shards and dust:** 10 bright small shards and 12 dim large dust puffs (icospheres) thrown outward and back from the start point. Shards rise and shrink to nothing; dust spreads, flattens and fades.
- **Ground streak:** a wide ribbon laid flat on the floor along the path, violet at the start to cyan at the end, lingering longest of all.
- **Sparkles:** 60 tiny emissive bits scattered along the path, drifting upward to the end of the clip.

## Light, camera and shadows

A point light parented to the rig travels with the character; its energy is keyed 0, 150 during the charge, 1,600 at launch, 400 after landing, 60 at rest. Its specular is off so it lights the floor and body without a hot reflection spot. The stage is a near-black glossy floor (roughness 0.28) with a cool key and cyan and violet rim area lights, so the effect colours read as the brightest thing in frame.

**FX objects cast shadows by default.** Ribbons, ghosts and sparkles all threw dark shapes on the floor under the key light. Every effect object gets `o.visible_shadow = False`.

![[p45_dash_arrive.png]]

The camera is side-on at 28 mm. **Framing a 17-stud dash needs about 22 studs of camera distance at 28 mm**; closer and the start or end falls out of frame. Shake is random offsets of up to 0.18 studs scaled by a triangle that peaks at the launch frame and dies out over 5 frames, plus a slow drift of 0.02 studs per frame so the shot never feels locked off:

```python
k = max(0.0, 1 - abs(f - (T0 + 1)) / 5) if f >= T0 - 1 else 0.0
cam.location = base + Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.18 * k \
               + Vector((0, -0.02 * f, 0))
```

Shake is keyed per frame from seeded randoms, so it is identical every render. [[Camera Shake and Camera FX]] covers the in-game equivalent.

## Bloom and video output

Bloom uses the Blender 5 compositor setup from [[Blender 5 Python Gotchas for Headless Builds]]: a `CompositorNodeTree` group assigned to `scene.compositing_node_group`, a Glare node set to Bloom (threshold 0.9, strength 0.85, size 0.6). The view transform is Standard so effect colours stay saturated rather than drifting to white.

Five stills render first (frames 6, 11, 13, 17 and 27), then the MP4:

```python
scene.render.image_settings.media_type = "VIDEO"      # Blender 5: set this first
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"; scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "HIGH"
```

In Blender 5, `FFMPEG` is not a valid file format while the image settings are still in image mode; setting `media_type = "VIDEO"` first makes it available. The line is wrapped in a try block so the script still runs on versions without the property.

## Carrying it into Roblox

The render is a presentation, but each layer maps to an in-game part (rule of thumb; tune against the real camera):

| Render layer | In-game version |
|---|---|
| Afterimages | Cloned character parts, anchored, tinted, transparency tweened out; or a Highlight on clones |
| Ribbons | Beams or Trails with a transparency sequence fading to the tail |
| Speed lines | A short particle burst of stretched quads, or camera-attached beams |
| Burst ring, shards, dust | A mesh ring scaled by tween, plus two particle emitters |
| Point light | A PointLight in the root part, brightness tweened |
| Camera shake | A local camera offset on the dashing player's client only |

[[Mesh VFX Packs Built in Blender]] covers building the ring and slash meshes; [[Particle Emitters In Depth]] the bursts; [[Ability Kits Architecture]] where the effect lives in code.

## Nuances and edge cases

1. **Additive effects need a dark stage.** On a bright sky the same strengths wash out to white. For a daytime showcase, lower the strengths and lean on colour, not brightness.
2. **Bloom threshold decides what glows.** At 0.9, only emissive parts and hot highlights bloom. Lower thresholds make the character's yellow skin bloom too.
3. **Ghost meshes are snapshots.** They do not follow later pose edits; rerun the bake if the dash pose changes.
4. **Shared materials share fades.** Convenient for groups, wrong for anything that should stagger.
5. **Five frames is very fast.** At 24 fps it reads as a teleport without the trails; the afterimages are what carry the motion. In game at 60 fps the same dash is 12 frames, and the trails can be shorter.
6. **The clip length sets the file size.** 48 frames at 1280 by 720 is a small MP4; longer clips for social video need more frames of follow-through, not a slower dash.
7. **Shake on the player's own client only.** Shaking every observer's camera when someone else dashes is disorienting.

## Common mistakes

1. **Empty renders after opening a rig file.** Cause: the collection is excluded or unlinked. Fix: link and un-exclude recursively.
2. **Ghosts in the wrong place.** Cause: offsetting a world-space bake by the absolute path position. Fix: subtract the rig position at the bake frame.
3. **Dark shapes under the effects.** Cause: FX casting shadows. Fix: `visible_shadow = False`.
4. **Hard-edged ribbons.** Cause: no falloff across the width. Fix: multiply by `1 - |2v - 1|`.
5. **`FFMPEG` rejected as a file format.** Fix: set `media_type = "VIDEO"` first.
6. **Start or end of the dash out of frame.** Fix: about 22 studs of distance at 28 mm for a 17-stud move, or a wider lens.

## Checklist

- [ ] Rig collection linked and un-excluded; old lights and cameras removed
- [ ] Anticipation, short action, long follow-through
- [ ] One additive material type; fades keyed on a Value node
- [ ] Afterimages baked from the evaluated mesh, offset from the bake position
- [ ] Ribbons with length and width falloff
- [ ] All FX objects `visible_shadow = False`
- [ ] Point light parented to the character, specular off
- [ ] Camera frames the whole path; shake peaks at launch only
- [ ] Bloom via the compositor group; Standard view transform
- [ ] `media_type = "VIDEO"` before `FFMPEG`

## Related decisions

- [[R15 Rig Anatomy and Attachments]]: the bone and part names the poses use.
- [[Dramatic Showcase Renders in Eevee]]: staging, bloom and view transforms for showcase shots.
- [[Icon and Thumbnail Rendering Pipeline]]: reusing the stills as ability icons.
- [[Short-Form Video Marketing]]: where clips like this get used.
- [[Procedural Blender Assets Start Here]]: the other builds in this section.

## Connected notes
<!-- auto-links:start -->
[[VFX Timing with Animation]] · Light Sources and Shadows · Stylized Lighting Recipes · Game Feel and Juice · Texturing and PBR Baking · Lighting Untextured Art in Roblox
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Slash VFX Recipes - Crescent and Ring]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Stylised Shop Stand Worked Example]] · [[Stylised Weapons From a Concept]] · [[Matching a Concept Sheet - Boss Creature Case Study]] · [[Chibi Character Rules in Practice]] · [[Low-Poly Tree Set Worked Example]]
<!-- related:end -->
