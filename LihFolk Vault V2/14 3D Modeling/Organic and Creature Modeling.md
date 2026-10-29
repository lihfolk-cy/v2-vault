---
tags: [modeling, organic, creatures, sculpting, blender, enemies, rigging-prep, type/guide, area/modeling, level/intermediate, area/animation]
---
# Organic and Creature Modeling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Choosing skinned vs segmented after modelling -> Decide first, in the brief
> - Avoid: Flat cuts between rigid pieces -> Ball-and-socket or overlapping sleeves
> - Avoid: Modelling in a relaxed, arms-down pose -> A-pose or T-pose
> - Skinned, segmented or mixed decided before modelling.
> - Modelled at final stud size, facing -Y, root at the origin.
> - One exaggerated feature; silhouette reads as a filled shape.
>
> Cost: TL;DR ~150 tok · whole note ~4.3k tok. Read more: ## 1. The first decision: skinned or segmented · ## 2. Three ways to build an organic form · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Organic modelling covers anything grown rather than built: creatures, monsters, faces, hands, trees, roots, tentacles, rocks with soft forms. In a game the organic model has a second job beyond looking right: it must **move**. That makes the first decision in every creature project a rigging decision, not a sculpting one: will this creature be one skinned mesh that bends, or a set of rigid pieces on joints? The answer changes how you model the shoulders, where the polygons go, how many meshes you export and how much the creature costs.

This note covers that decision, the three ways to build an organic form (box modelling, the Skin modifier, sculpt then retopologise), proportion and anatomy for readable game creatures, faces, and the reference project's creature pipeline with its real numbers. Topology for deformation has its own note ([[Topology and Edge Flow]]), as do rig conventions ([[Creature Rig Conventions]]) and retopology ([[Retopology and Decimation]]).

---

## 1. The first decision: skinned or segmented

| | Skinned mesh (Bones) | Segmented rigid parts (Motor6D per piece) |
|---|---|---|
| What it is | One or a few continuous meshes deformed by an armature; vertices weighted to up to 4 bones (Roblox limit, Docs) | Each body part is its own MeshPart; joints between parts rotate them rigidly |
| Looks like | Organic: skin bends, bellies squash, tails curve smoothly | Toy, robot, armour, voxel, insect, skeleton, golem |
| Modelling cost | High: deformation topology, weight painting | Low: model each piece, overlap at joints |
| Runtime cost | Skinning cost per vertex; one mesh can carry the whole body | One part per piece; more instances, no skinning |
| Per-mesh 20,000-tri limit | Split into several skinned meshes bound to one armature if needed | Each piece is far under it naturally |
| Who writes the joints | Animator on Bones | Animator or code on Motor6D / [[AnimationConstraint]] |
| Failure modes | Candy-wrapper twists, collapsing elbows, bad weights | Gaps or intersections at joints, "floating parts" look |

Rules of thumb:

- **Skin** when the creature's appeal is in how it bends: snakes, dragons, quadruped mammals, slimes, anything with a neck or long tail.
- **Segment** when the style allows it: armoured knights, golems, mechs, bugs, skeletons, voxel creatures, and anything that will spawn in numbers on low-end devices.
- **Mix** freely: a skinned body with rigid armour plates, horns and weapons welded to bones is the normal case. See [[Accessories and Armor That Follow Animation]].

The reference project used both: its 49 Realm 1 enemies were segmented voxel models (rigid parts on a rebuilt rig), while its second boss was rebuilt properly in Blender as "6 flat meshes, 42 bones, 23 clips". Its first boss was a static mesh with **19 Motor6Ds inserted** at chosen joint points, which worked for a stiff creature; the project's conclusion: "for anything organic, rebuild with a skeleton." See [[Custom Rigs - Weapons and Props]] section 5.

### Modelling for segmented rigs

- **Cut at the joints, not between them.** Each piece ends at a pivot (shoulder, elbow, knee). Set each piece's origin on its joint centre.
- **Overlap or socket every joint.** A ball-and-socket (a sphere at the end of the upper arm sitting inside a cup on the lower arm) or a sleeve (the upper piece's rim overlapping the lower piece) hides the gap at every angle. A flat cut shows a gap at 30 degrees.
- **Hide seams under features**: belts, bracers, armour rims, fur tufts.
- **Keep pieces closed.** Each piece is a separate mesh in Roblox and needs to be watertight on its own (Docs: watertight, no exposed backfaces).
- **Exaggerate around the pivots.** The project's Rail Riot style rebuild made fists 1.4x and forearms 1.25x "around the existing pivots: scale meshes about their joint points, never move the joints", so every existing clip still fit ([[Creature Rig Conventions]]).

### Modelling for skinned rigs

- Model in a **neutral pose**: limbs slightly bent, arms in an A-pose (about 45 degrees down) or T-pose, fingers spread, mouth closed. A neutral pose has the least distortion in both directions.
- **Loops at every joint**: at least three edge loops at elbows, knees, knuckles; five or more at shoulders and hips. Details in [[Topology and Edge Flow]].
- **Even density** where it bends; sparse where it does not (the flat of a back, a skull).
- Split meshes by region if you approach 20,000 triangles (head, body, tail), all bound to the same armature. Split along existing seams (a collar, belt or armour edge), not across a smooth belly.

---

## 2. Three ways to build an organic form

### A. Box (poly) modelling

Start from a cube or cylinder and extrude, loop-cut and shape. Best for low-poly and stylised creatures, where you control every edge from the start and the final topology is the one you model.

Typical sequence for a quadruped:

1. Cube for the torso, scaled to body proportions, Mirror modifier on X with Clipping.
2. Extrude the chest face forward for the neck, then the head.
3. Extrude legs from faces on the bottom (inset first so the legs come from a square patch with loops around it).
4. Loop-cut along the body for the rib cage and belly, then shape with proportional editing (O, scroll to resize the falloff).
5. Subdivision level 1 for a softer form, applied, then cleaned.

### B. Skin modifier: a base mesh from a stick figure

The Skin modifier turns a network of vertices and edges into a quad tube mesh with radius per vertex. It is the fastest way to get a clean base mesh for limbs, tentacles, tails and trees.

```python
# Blender: quad base mesh for a 4-legged creature from a skeleton of edges (Skin modifier).
import bpy, bmesh

# (position, radius) per joint, Z up, creature faces -Y, 1 unit = 1 stud.
pts = {
    "hip":   ((0, 1.2, 2.4), 0.9),  "chest": ((0, -1.0, 2.6), 1.1),
    "neck":  ((0, -1.9, 3.4), 0.6), "head":  ((0, -2.6, 3.7), 0.7),
    "tail1": ((0, 2.2, 2.6), 0.4),  "tail2": ((0, 3.4, 3.0), 0.2),
}
for side, x in (("L", -0.7), ("R", 0.7)):
    pts["fknee" + side] = ((x, -1.0, 1.3), 0.35); pts["ffoot" + side] = ((x, -1.1, 0.2), 0.3)
    pts["bknee" + side] = ((x, 1.3, 1.3), 0.4);   pts["bfoot" + side] = ((x, 1.4, 0.2), 0.3)
edges = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "tail1"), ("tail1", "tail2")]
for s in ("L", "R"):
    edges += [("chest", "fknee" + s), ("fknee" + s, "ffoot" + s),
              ("hip", "bknee" + s), ("bknee" + s, "bfoot" + s)]

mesh = bpy.data.meshes.new("CreatureBase")
obj = bpy.data.objects.new("CreatureBase", mesh)
bpy.context.collection.objects.link(obj)
bm = bmesh.new()
verts = {k: bm.verts.new(p) for k, (p, r) in pts.items()}
for a, b in edges:
    bm.edges.new((verts[a], verts[b]))
bm.to_mesh(mesh)
bm.free()

obj.modifiers.new("Skin", 'SKIN')                      # creates the skin vertex data layer
skin = mesh.skin_vertices[0].data
names = list(pts.keys())                               # verts were created in dict order
for i, name in enumerate(names):
    r = pts[name][1]
    skin[i].radius = (r, r)
skin[names.index("hip")].use_root = True               # one root per connected piece
sub = obj.modifiers.new("Subsurf", 'SUBSURF')
sub.levels = 1
```

Apply both modifiers, then sculpt or edit. The result has continuous quad loops around every limb, which is exactly what deformation wants. Branches (where the legs meet the body) are the messiest part and usually need manual cleanup.

### C. Sculpt, then retopologise

Sculpt the form freely in Sculpt mode (Dyntopo or a voxel-remeshed base), then build game topology over it. Best for detailed realistic creatures and for anything where the form is discovered by sculpting. It is also the slowest route: retopology for a full creature is hours to days. The manual is blunt: automatic remesh tools "generally don't result in topology that lends itself to deformation", so a deforming creature needs manual retopology. See [[Retopology and Decimation]].

Sculpting tips for game creatures:

- Sculpt at a **low resolution first** (voxel remesh at 0.05-0.1 studs on a 10-stud creature) and only go finer once the primary forms are right.
- Use the **Draw Sharp, Clay Strips, Inflate, Grab and Smooth** brushes for most work; avoid fine skin detail that will only become a normal map.
- **Check the silhouette** from the game camera's angle (usually slightly above) often.
- Keep **symmetry** on (X) until the very end.

| Route | Speed | Topology quality | Best style |
|---|---|---|---|
| Box modelling | Medium | You control it | Low-poly, stylised |
| Skin modifier | Fast | Good on limbs, messy at branches | Base meshes, tentacles, trees |
| Sculpt + retopo | Slow | Best (if retopo is done well) | Detailed, realistic, hero creatures |

---

## 3. Proportion and anatomy for game creatures

Players read creatures at 20-80 studs, from above, in motion. Real anatomy matters less than readable anatomy:

- **Pick one exaggeration.** Huge arms (brute), huge head (cute), long neck (grace), huge jaw (threat). The reference project's style guide for outlined voxel enemies: "Exaggerate one feature: one part is 1.5-2x realistic size."
- **Hunch for menace.** Head below the shoulder line, shoulders 2.2-2.5x the head width, arms reaching the knees, forearms thicker than upper arms (the project's brute archetype).
- **Big head for cute.** Big forehead, eyes below the middle of the head, no neck (the project's pet style: "baby proportions read as cute").
- **Simplify joints into shapes.** A knee is a sphere between two tapered cylinders; a shoulder is a ball under a plate.
- **Taper limbs.** Every limb tapers toward its end (and the forearm/calf has its widest point about a third of the way down). Untapered limbs read as tubes.
- **Leave negative space.** Gaps between legs, between arm and torso, under the jaw make the silhouette readable.

### Size and scale in the world

The reference project sized regular enemies to about 13 studs tall against 9-stud players (a size controller enforced `target = 13, min = 1.15, max = 3.2` scale), so the smallest creatures grew up to 3.2x. Model creatures **at their final stud size** in Blender ("authored at final stud height" is a project rule, [[Creature Rig Conventions]]), because scaling in Studio after rigging moves pivots and changes root motion.

### Playback scale for big creatures

Bigger creatures should move slower: the project slowed walk clips to `0.85 / sqrt(scale)` for scaled enemies, the pendulum rule (stride frequency falls with the square root of leg length). This matters for modelling only in that leg length decides how fast a creature can look natural moving. A 13-stud creature that must chase a sprinting player needs long legs or a gallop.

---

## 4. Faces and heads

Faces are where creatures fail most often. The reference project's lead even noted "the face is off, and normally always is" before building a reusable face kit. Its method, which you can follow by hand or in code:

1. Start from **one quad sphere** for the skull (a subdivided cube cast to a sphere has even quads with no poles at the top).
2. **Displace in anatomical order**: flatten the face plane, push out the muzzle (a dome), cut the palate (mouth line), raise cheekbones, then the brow, then the nose, then sink the eye sockets.
3. **Seat the eyes by raycast** against the socket, so they sit in the skull rather than float. Add lids; the lid tilt sets the expression (angry: inner corners down).
4. **Teeth on a dental arch**: place teeth along a curve following the jaw line, not in a straight row.
5. **Jaw as its own piece on the real hinge**, just below and in front of the ear, so it opens with a rotation that looks anatomical.

The project ran this as a Blender Python kit with presets (Brute, Beast, Skull, Golem) and used it "for every new head".

Expression and readability:

- **Eyes are the brightest pixels** on a creature in every reference style in this vault (neon eyes on dark bodies, white-hot catchlights on cute pets). Model a clear eye socket or eye plate so the eye has somewhere to sit.
- **Brows carry expression.** A heavy brow ridge makes even a static face look angry.
- **Mouth line** (the edge between lips or jaw plates) should be a clean loop so the jaw can open without the face tearing; see [[Topology and Edge Flow]].
- For animated faces on avatars ([[FACS]]), follow the dynamic head specification in [[Facial Animation and Dynamic Heads]].

---

## 5. Non-character organics

### Trees and plants

- **Trunks and branches**: Skin modifier on a branching edge skeleton, or curves with a bevel (Curve > Geometry > Bevel depth) converted to mesh. Taper every branch.
- **Canopies**: clumps of low-poly blobs (icospheres with a Displace modifier, decimated) or leaf cards (planes with an alpha texture, double-sided or solidified). Clumps read better in stylised Roblox games and cost no transparency sorting.
- **Variation from one source**: the reference project made a 128-tree forest from 5 tree types with random crown turn, leaf jitter, scale 0.6 to 3.47 with a long tail of giants, and tilts up to 4 degrees. Five well-made sources plus variation beats 50 unique trees. See [[Foliage Props and Scatter]].

### Rocks and cliffs

Rocks are organic but rigid: start from a cube or icosphere, use Displace with a Voronoi or noise texture, decimate (*Planar* mode keeps flat faces flat), then bevel or weighted-normal for chunky stylised rocks. See [[Low-Poly and Stylized Modeling]].

### Tentacles, tails, vines

Use a Curve modifier on a cylinder with many length segments, or the Skin modifier. For animated tentacles, keep evenly spaced loops along the length (one loop per bone segment plus one between), and taper the radius toward the tip. The project's voxel octopus style used "stepped tubes that taper and curl at the tip (a hook of 3-4 cells)".

---

## 6. Production numbers

| Creature (reference project) | Build | Triangles |
|---|---|---|
| 49 Realm 1 enemies (outlined voxel style) | Segmented, many parts | 10,268 to 42,240 each |
| Zone 5 boss rebuild | Segmented, 32 parts | 31k (largest part 6.5k) |
| Second boss | Skinned: 6 meshes, 42 bones, 23 clips | Not recorded in the notes |
| A thorn titan test build | Procedural: 529 shapes | 19,772 |
| Revamp plan target | Hand-painted, one 1K atlas per enemy | 3-6k regulars, 10-15k bosses |

The gap between the plan (3-6k) and what shipped (15-40k) is the cost of a voxel style with geometric studs and seams. A smooth stylised creature with a painted atlas fits the plan's numbers; see [[Low-Poly and Stylized Modeling]] and [[Voxel and Blocky Modeling]] for what each style costs.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Choosing skinned vs segmented after modelling | Remodel the shoulders, hips and neck | Decide first, in the brief |
| Flat cuts between rigid pieces | Gaps at 30 degrees of bend | Ball-and-socket or overlapping sleeves |
| Modelling in a relaxed, arms-down pose | Armpits collapse when arms rise | A-pose or T-pose |
| Too few loops at joints | Elbows and knees fold like paper | 3+ loops at hinges, 5+ at shoulders and hips |
| Scaling the creature in Studio after rigging | Pivots and root motion wrong | Model at final stud size |
| Floating eyes | Dead, uncanny face | Seat eyes into sockets; add lids |
| Fine skin detail in geometry | Triangles without readable gain | Bake or paint it |
| Untapered limbs | Tube-like creatures | Taper toward the extremity |

## Checklist

- [ ] Skinned, segmented or mixed decided before modelling.
- [ ] Modelled at final stud size, facing -Y, root at the origin.
- [ ] One exaggerated feature; silhouette reads as a filled shape.
- [ ] Neutral pose (A or T); loops at every joint (skinned) or sockets at every joint (segmented).
- [ ] Each segmented piece closed, origin on its joint.
- [ ] Eyes seated, jaw on its hinge, mouth line clean.
- [ ] Per-mesh triangles under 20,000; total within the creature budget.

## See also

[[Topology and Edge Flow]] · [[Retopology and Decimation]] · [[Creature Rig Conventions]] · [[Rigging in Blender]] · [[Weight Painting and Skinning for Roblox]] · [[Bones and Skinned Meshes]] · [[Animating Creatures and Monsters]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Voxel and Blocky Modeling]] · [[Character and Creature Pipeline]] · [[Case Study - Enemy Roster Rebuild]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Characters - Proportions Joints and Rigging]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · Skinning Weights · Skeleton Library · Low-Poly Creature From a Flat Reference Sheet · Chibi Character Rules in Practice
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Modeling Fundamentals for Games]] · [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[Hard-Surface Modeling]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Weapons and Props]] · [[Mesh Optimization for Mobile]] · [[UGC Avatar Items and Accessories]] · [[Normal Maps and Detail Baking]]
<!-- related:end -->
