"""Chibi chicken v2. Vault rules for cute (Organic and Creature Modeling, Low-Poly and Stylized Modeling):
round shape language, smooth stylised, whole body is the head, no neck, eyes BELOW the middle of the head,
eyes are the most contrasted pixels, tiny limbs, thick everything, tapers and bulges (pear body), one
focal feature (the face). Rig: vault Bird_Winged bone names. Preview only.
Run: blender -b --factory-startup --python build_chicken_chibi.py"""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
random.seed(2)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, rgb, rough=0.55, emit=0.0, sheen=0.0, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    if emit: b.inputs["Emission Color"].default_value = (*rgb, 1); b.inputs["Emission Strength"].default_value = emit
    if sheen and "Sheen Weight" in b.inputs: b.inputs["Sheen Weight"].default_value = sheen
    if coat and "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    m.diffuse_color = (*rgb, 1); return m
def gradient_mat(name, low, high, z0, z1, rough=0.6, sheen=0.35):
    """Warm underside fading to bright top, by object-space height (survives any lighting)."""
    m = mat(name, high, rough, sheen=sheen); nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = z0; mr.inputs["From Max"].default_value = z1
    cr = nt.nodes.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].color = (*low, 1); cr.color_ramp.elements[1].color = (*high, 1)
    nt.links.new(tc.outputs["Object"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], cr.inputs["Fac"]); nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
    return m
FEATHER = gradient_mat("Chibi_Feather", (0.93, 0.8, 0.66), (1.0, 0.98, 0.94), 0.4, 3.6)
BIB = gradient_mat("Chibi_Bib", (1.0, 0.82, 0.55), (1.0, 0.93, 0.78), 0.5, 2.6)
WINGM = gradient_mat("Chibi_Wing", (0.92, 0.82, 0.7), (1.0, 0.97, 0.92), 0.8, 2.4)
RED = gradient_mat("Chibi_Red", (0.85, 0.08, 0.1), (1.0, 0.33, 0.28), 4.1, 5.3, rough=0.35, sheen=0)
WATTLE = mat("Chibi_Wattle", (0.92, 0.14, 0.14), 0.35, coat=0.3)
BEAK = gradient_mat("Chibi_Beak", (1.0, 0.5, 0.05), (1.0, 0.78, 0.2), 1.75, 2.15, rough=0.35, sheen=0)
BEAK_LO = mat("Chibi_BeakLow", (0.95, 0.45, 0.06), 0.4)
FEET = mat("Chibi_Feet", (1.0, 0.62, 0.12), 0.45, coat=0.2)
EYE = mat("Chibi_Eye", (0.025, 0.02, 0.035), 0.06, coat=1.0)
IRIS = mat("Chibi_Iris", (0.32, 0.16, 0.08), 0.1, coat=1.0)
SHINE = mat("Chibi_Shine", (1, 1, 1), 0.1, emit=3)
BLUSH = mat("Chibi_Blush", (1.0, 0.48, 0.55), 0.7)
TAILTIP = gradient_mat("Chibi_TailTip", (1.0, 0.95, 0.88), (0.98, 0.78, 0.52), 3.2, 4.6)

S = {}
def bone(n, h, t, p=None): S[n] = (Vector(h), Vector(t), p)
bone("RootPart", (0, 0, 1.0), (0, -0.6, 1.0))
bone("Body", (0, 0.2, 0.9), (0, 0.0, 2.4), "RootPart")
bone("Neck", (0, 0.0, 2.4), (0, -0.1, 2.9), "Body")
bone("Head", (0, -0.1, 2.9), (0, -0.2, 4.4), "Neck")
bone("Beak", (0, -2.0, 2.05), (0, -2.45, 1.95), "Head")
bone("Tail1", (0, 1.7, 2.6), (0, 2.1, 3.4), "Body"); bone("Tail2", (0, 2.1, 3.4), (0, 2.2, 4.1), "Tail1")
for side, sx in (("Left", 1), ("Right", -1)):
    bone(f"{side}Wing1", (sx * 2.0, 0.0, 1.95), (sx * 2.35, 0.3, 1.5), "Body")
    bone(f"{side}Wing2", (sx * 2.35, 0.3, 1.5), (sx * 2.45, 0.5, 1.1), f"{side}Wing1")
    bone(f"{side}Wing3", (sx * 2.45, 0.5, 1.1), (sx * 2.45, 0.6, 0.85), f"{side}Wing2")
    bone(f"{side}UpperLeg", (sx * 0.75, -0.2, 0.6), (sx * 0.8, -0.3, 0.35), "Body")
    bone(f"{side}LowerLeg", (sx * 0.8, -0.3, 0.35), (sx * 0.8, -0.35, 0.12), f"{side}UpperLeg")
    bone(f"{side}Foot", (sx * 0.8, -0.35, 0.12), (sx * 0.8, -0.95, 0.06), f"{side}LowerLeg")

OBJS = []
def add(name, bm, m, weights, smooth=True):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(m)
    for p in me.polygons: p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me); scene.collection.objects.link(ob)
    groups = {}
    for vi, wd in enumerate(weights(ob) if callable(weights) else [weights] * len(me.vertices)):
        for bn, w in wd.items():
            if w <= 0: continue
            g = groups.get(bn) or ob.vertex_groups.new(name=bn); groups[bn] = g; g.add([vi], w, "REPLACE")
    OBJS.append(ob); return ob
def ball(bm, c, r, rot=(0, 0, 0), seg=24, ring=14):
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=1.0)
    M = Matrix.Translation(Vector(c)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*r, 1))
    bmesh.ops.transform(bm, matrix=M, verts=res["verts"]); return res["verts"]
def tube(bm, pts, r0, r1, sides=12, cap=True):
    """Smooth tapered tube along a polyline (feathers, toes, tail plumes)."""
    rings = []; n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        s = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized(); u = s.cross(d)
        r = r0 + (r1 - r0) * (i / (n - 1)) ** 1.2
        rings.append([bm.verts.new(p + (s * math.cos(a) + u * math.sin(a)) * r) for a in (k / sides * math.tau for k in range(sides))])
    for a, b in zip(rings, rings[1:]):
        for k in range(sides): bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if cap:
        c0 = bm.verts.new(pts[0] - (pts[1] - pts[0]).normalized() * r0 * 0.6); c1 = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * r1 * 0.8)
        for k in range(sides):
            bm.faces.new((rings[0][(k + 1) % sides], rings[0][k], c0)); bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], c1))
def curve(p0, p1, p2, n=10):
    return [p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t for t in (i / n for i in range(n + 1))]

# ---------------- body: bottom-heavy pear, whole body = head ----------------
bm = bmesh.new()
vs = ball(bm, (0, 0, 2.2), (2.1, 2.0, 2.15), seg=48, ring=28)
for v in vs:
    z = v.co.z
    w = 1.0 + 0.11 * max(0, 1.9 - z) - 0.05 * max(0, z - 3.3)          # wide hips, slightly narrower crown
    v.co.x *= w; v.co.y *= w
    if v.co.y > 0.6 and z > 1.5: v.co.y += 0.3 * (z - 1.5) / 2.6        # back slopes up into the tail
    if v.co.y < -1.2 and 1.0 < z < 2.6: v.co.y -= 0.12 * math.sin((z - 1.0) / 1.6 * math.pi)  # chest swell
    if z < 0.35: v.co.z = 0.35 + (z - 0.35) * 0.35                       # flatten the sitting bottom
def body_w(ob):
    out = []
    for v in ob.data.vertices:
        h = min(1, max(0, (v.co.z - 2.2) / 1.2)); out.append({"Body": 1 - h, "Head": h})
    return out
add("Chibi_Body", bm, FEATHER, body_w)

# feather bib: smooth patch with a scalloped top edge
bm = bmesh.new()
ball(bm, (0, -1.25, 1.2), (1.45, 0.95, 1.0), seg=32, ring=18)
for i in range(5):
    x = (i - 2) * 0.55; z = 2.0 - abs(i - 2) * 0.16
    ball(bm, (x, -1.62 + abs(i - 2) * 0.12, z), (0.36, 0.3, 0.32), seg=16, ring=10)
add("Chibi_Bib", bm, BIB, {"Body": 1.0})

# ---------------- face: eyes below centre, iris crescent, catchlights, smile beak, blush ----------------
EZ = 2.3
for sx in (1, -1):
    ex = sx * 0.78
    bm = bmesh.new(); ball(bm, (ex, -1.83, EZ), (0.4, 0.24, 0.52), rot=(0, 0, sx * -0.35), seg=24, ring=16)
    add(f"Chibi_Eye{sx}", bm, EYE, {"Head": 1.0})
    bm = bmesh.new(); ball(bm, (ex, -1.86, EZ - 0.2), (0.3, 0.2, 0.28), rot=(0, 0, sx * -0.35), seg=20, ring=12)
    add(f"Chibi_Iris{sx}", bm, IRIS, {"Head": 1.0})
    bm = bmesh.new()
    ball(bm, (ex - sx * 0.1, -2.05, EZ + 0.2), (0.15, 0.06, 0.17), seg=14, ring=8)   # big catchlight, upper outer
    ball(bm, (ex + sx * 0.12, -2.03, EZ - 0.22), (0.07, 0.04, 0.07), seg=10, ring=6)  # small catchlight, lower inner
    add(f"Chibi_Shine{sx}", bm, SHINE, {"Head": 1.0})
    bm = bmesh.new(); ball(bm, (sx * 1.3, -1.58, EZ - 0.48), (0.34, 0.12, 0.2), rot=(0, 0, sx * -0.62), seg=18, ring=8)
    add(f"Chibi_Blush{sx}", bm, BLUSH, {"Head": 1.0})
bm = bmesh.new()                       # upper beak: soft triangle pointing forward-down
tube(bm, curve(Vector((0, -1.95, 2.05)), Vector((0, -2.35, 2.02)), Vector((0, -2.5, 1.86)), 6), 0.27, 0.04, sides=10)
add("Chibi_BeakTop", bm, BEAK, {"Beak": 1.0})
bm = bmesh.new()                       # lower beak: smaller, tucked: reads as a little smile
tube(bm, curve(Vector((0, -1.95, 1.9)), Vector((0, -2.22, 1.84)), Vector((0, -2.3, 1.8)), 5), 0.17, 0.04, sides=10)
add("Chibi_BeakLow", bm, BEAK_LO, {"Beak": 1.0})
bm = bmesh.new(); ball(bm, (0, -1.95, 1.6), (0.15, 0.11, 0.24), seg=12, ring=8)
add("Chibi_Wattle", bm, WATTLE, {"Head": 1.0})
bm = bmesh.new()                       # comb: three plump lobes, tilted forward
for (y, z, r) in ((-0.85, 4.32, 0.42), (-0.25, 4.62, 0.55), (0.35, 4.42, 0.44)):
    ball(bm, (0, y, z), (0.28, r, r), rot=(0.25, 0, 0), seg=20, ring=12)
add("Chibi_Comb", bm, RED, {"Head": 1.0})

# ---------------- wings: leaf flaps with scalloped tips ----------------
for side, sx in (("Left", 1), ("Right", -1)):
    bm = bmesh.new(); ball(bm, (sx * 2.05, 0.2, 1.5), (0.3, 0.8, 0.65), rot=(0.35, sx * 0.25, 0), seg=24, ring=14)
    for k in range(3):
        ball(bm, (sx * 2.08, 0.55 + 0.3 * k, 0.98 + 0.13 * k), (0.24, 0.28, 0.24), seg=14, ring=8)
    add(f"Chibi_{side}Wing", bm, WINGM, {f"{side}Wing1": 1.0})

# ---------------- tail: three curled plumes that show over the back ----------------
bm = bmesh.new(); tbm = bmesh.new()
for a in (-0.42, 0.0, 0.42):
    base = Vector((a * 0.9, 1.65, 2.4))
    pts = curve(base, base + Vector((a * 0.6, 0.55, 1.1 - abs(a) * 0.5)), base + Vector((a * 1.2, 1.35, 1.05 - abs(a) * 0.6)), 10)
    tube(bm, pts[:8], 0.36, 0.3, sides=12)
    tube(tbm, pts[7:], 0.3, 0.2, sides=12)
add("Chibi_Tail", bm, FEATHER, {"Tail1": 1.0}); add("Chibi_TailTips", tbm, TAILTIP, {"Tail2": 1.0})

# ---------------- stubby legs, round toes ----------------
for side, sx in (("Left", 1), ("Right", -1)):
    bm = bmesh.new(); tube(bm, [Vector((sx * 0.8, -0.3, 0.6)), Vector((sx * 0.8, -0.33, 0.35)), Vector((sx * 0.8, -0.35, 0.14))], 0.15, 0.13)
    add(f"Chibi_{side}Leg", bm, FEET, {f"{side}LowerLeg": 1.0})
    bm = bmesh.new()
    for tx, ty in ((-0.33, -0.55), (0.0, -0.62), (0.33, -0.55), (0.0, 0.35)):
        a = Vector((sx * 0.8, -0.35, 0.12)); b = a + Vector((tx * sx, ty, -0.04))
        tube(bm, [a, a.lerp(b, 0.5), b], 0.12, 0.11, sides=10)
    add(f"Chibi_{side}Foot", bm, FEET, {f"{side}Foot": 1.0})

# ---------------- join + rig ----------------
bpy.ops.object.select_all(action="DESELECT")
for o in OBJS: o.select_set(True)
bpy.context.view_layer.objects.active = OBJS[0]; bpy.ops.object.join()
chk = bpy.context.active_object; chk.name = "ChibiChicken"
arm = bpy.data.armatures.new("ChibiChickenRig"); rig = bpy.data.objects.new("ChibiChickenRig", arm); scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for n, (h, t, _) in S.items():
    b = arm.edit_bones.new(n); b.head = h; b.tail = t; eb[n] = b
for n, (_, _, p) in S.items():
    if p: eb[n].parent = eb[p]
bpy.ops.object.mode_set(mode="OBJECT")
chk.parent = rig; chk.modifiers.new("Armature", "ARMATURE").object = rig
sub = chk.modifiers.new("Subsurf", "SUBSURF"); sub.levels = 1; sub.render_levels = 1
rig.hide_render = True
print("BONES", len(arm.bones), "TRIS(base)", sum(len(p.vertices) - 2 for p in chk.data.polygons),
      "UNWEIGHTED", sum(1 for v in chk.data.vertices if not v.groups))

# pose: head tilt, a happy wave, little lean
bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode="POSE")
pb = rig.pose.bones
def rot(n, axis, deg):
    b = pb[n]; bpy.context.view_layer.update(); p = b.head.copy()
    b.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ b.matrix
    bpy.context.view_layer.update()
rot("Head", "Y", 8); rot("RootPart", "Z", -16)
rot("LeftWing1", "Y", -62); rot("LeftWing1", "X", -18)
rot("Tail1", "X", 6)
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------- stage: pastel sky, grass plinth with flowers, tufts and an egg ----------------
world = bpy.data.worlds.new("Sky"); world.use_nodes = True; nt = world.node_tree; bg = nt.nodes["Background"]
tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); cr = nt.nodes.new("ShaderNodeValToRGB")
cr.color_ramp.elements[0].color = (1.0, 0.84, 0.74, 1); cr.color_ramp.elements[1].color = (0.55, 0.78, 1.0, 1)
nt.links.new(tc.outputs["Window"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], cr.inputs["Fac"]); nt.links.new(cr.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.6; scene.world = world
stage = []
bm = bmesh.new(); res = bmesh.ops.create_cone(bm, cap_ends=True, segments=64, radius1=3.9, radius2=3.7, depth=0.7)
for v in res["verts"]: v.co.z -= 0.35
bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.calc_length() > 0.1 and abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-3 and e.verts[0].co.z > -0.01],
                offset=0.15, segments=3, affect="EDGES")
me = bpy.data.meshes.new("Plinth"); bm.to_mesh(me); bm.free()
for p in me.polygons: p.use_smooth = True
me.materials.append(gradient_mat("Grass", (0.3, 0.62, 0.25), (0.55, 0.88, 0.42), -0.7, 0.0, rough=0.8, sheen=0.3))
stage.append(bpy.data.objects.new("Plinth", me))
def prop(name, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    stage.append(bpy.data.objects.new(name, me))
GRASS_T = mat("Tuft", (0.32, 0.7, 0.26), 0.7)
bm = bmesh.new()
for i in range(22):
    a = random.uniform(0, math.tau); r = random.uniform(2.4, 3.5); c = Vector((math.cos(a) * r, math.sin(a) * r, 0))
    for k in range(3):
        tip = c + Vector((random.uniform(-0.18, 0.18), random.uniform(-0.18, 0.18), random.uniform(0.35, 0.6)))
        tube(bm, [c + Vector((k * 0.06, 0, 0)), (c + tip) / 2 + Vector((0, 0, 0.05)), tip], 0.07, 0.01, sides=6)
prop("Tufts", bm, GRASS_T)
PETAL_P = mat("PetalPink", (1.0, 0.62, 0.78), 0.5); PETAL_W = mat("PetalWhite", (1, 0.97, 0.95), 0.5); CORE = mat("FlowerCore", (1.0, 0.8, 0.2), 0.4)
for idx, (a, r, petal) in enumerate(((2.2, 2.9, PETAL_P), (2.75, 3.2, PETAL_W), (3.9, 3.0, PETAL_P), (5.3, 3.1, PETAL_W), (0.6, 3.3, PETAL_P))):
    c = Vector((math.cos(a) * r, math.sin(a) * r, 0.22))
    bm = bmesh.new()
    for k in range(5):
        pa = k / 5 * math.tau; ball(bm, c + Vector((math.cos(pa) * 0.17, math.sin(pa) * 0.17, 0)), (0.13, 0.13, 0.05), seg=10, ring=6)
    prop(f"Petals{idx}", bm, petal)
    bm = bmesh.new(); ball(bm, c + Vector((0, 0, 0.04)), (0.09, 0.09, 0.06), seg=10, ring=6); prop(f"Core{idx}", bm, CORE)
bm = bmesh.new(); vs = ball(bm, (2.1, -1.2, 0.42), (0.36, 0.36, 0.46), seg=24, ring=14)
for v in vs:
    if v.co.z > 0.42: v.co.x = 2.1 + (v.co.x - 2.1) * (1 - 0.18 * (v.co.z - 0.42) / 0.46); v.co.y = -1.2 + (v.co.y + 1.2) * (1 - 0.18 * (v.co.z - 0.42) / 0.46)
prop("Egg", bm, mat("Egg", (1.0, 0.9, 0.78), 0.45, coat=0.2))
for o in stage: scene.collection.objects.link(o)

def area(name, loc, rot_, e, col, size):
    l = bpy.data.lights.new(name, "AREA"); l.energy = e; l.color = col; l.size = size
    o = bpy.data.objects.new(name, l); scene.collection.objects.link(o); o.location = loc; o.rotation_euler = rot_
area("Key", (-6, -8, 10), (math.radians(42), 0, math.radians(-35)), 1700, (1, 0.94, 0.86), 7)
area("Rim", (4, 7, 7), (math.radians(-55), 0, math.radians(150)), 2200, (0.7, 0.82, 1), 6)
area("Fill", (8, -6, 2.5), (math.radians(80), 0, math.radians(50)), 450, (1, 0.86, 0.92), 6)
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
for attr, val in (("use_raytracing", True), ("use_gtao", True), ("use_shadows", True)):
    try: setattr(scene.eevee, attr, val)
    except Exception: pass
try: scene.eevee.ray_tracing_options.use_denoise = True
except Exception: pass
scene.render.resolution_x = 1920; scene.render.resolution_y = 1080; scene.view_settings.view_transform = "Standard"
cd.dof.use_dof = True; cd.dof.aperture_fstop = 5.6
def shot(fname, loc, tgt, lens):
    cam.location = loc; cd.lens = lens; cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cd.dof.focus_distance = (Vector(tgt) - cam.location).length
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
shot("chibi_chicken_hero.png", (-6.0, -13.5, 4.2), (0, -0.4, 2.2), 40)
shot("chibi_chicken_side.png", (-12.5, -3.0, 3.6), (0, 0.3, 2.3), 40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "ChibiChicken.blend"))
print("DONE")
