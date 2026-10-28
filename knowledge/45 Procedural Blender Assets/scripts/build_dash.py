"""Dash effect presentation: an R15 character (the vault's 18 Rigs and Skeletons/R15_Blocky) dashes with afterimages,
energy ribbons, speed lines, a launch burst, ground streak and sparkles. 48 frames at 24 fps -> MP4 + key-frame stills.
Vault: 45 Mesh VFX Packs Built in Blender, Dramatic Showcase Renders in Eevee, Blender 5 Python Gotchas.
blender -b --factory-startup --python build_dash.py"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__)); random.seed(4)
RIG_BLEND = os.path.normpath(os.path.join(HERE, "..", "..", "18 Rigs and Skeletons", "R15_Blocky", "R15_Blocky.blend"))
bpy.ops.wm.open_mainfile(filepath=RIG_BLEND)
scene = bpy.context.scene
for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]: bpy.data.objects.remove(o)
if scene.world is None: scene.world = bpy.data.worlds.new("World")
scene.world.use_nodes = True
for c in bpy.data.collections:                      # the rig collection ships excluded / unlinked: bring it in
    if c.name not in scene.collection.children and not any(c.name in p.children for p in bpy.data.collections): scene.collection.children.link(c)
def unexclude(lc):
    lc.exclude = False; lc.hide_viewport = False
    for ch in lc.children: unexclude(ch)
unexclude(bpy.context.view_layer.layer_collection)
for c in bpy.data.collections: c.hide_render = False; c.hide_viewport = False
rig = bpy.data.objects["R15_Blocky_Armature"]
PARTS = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig]
if rig.animation_data: rig.animation_data.action = None

# classic colours, chunky bevels, a simple face on the head (faces -Y)
def flat(name, hexc, rough=0.55):
    m = bpy.data.materials.new(name); m.use_nodes = True; pb = m.node_tree.nodes["Principled BSDF"]
    pb.inputs["Base Color"].default_value = tuple((int(hexc[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1,)
    pb.inputs["Roughness"].default_value = rough; return m
SKIN, SHIRT, PANTS, SHOE, FACE = flat("Skin", "F5CD30"), flat("Shirt", "1E6FD9"), flat("Pants", "2B2F3A"), flat("Shoe", "15171C"), flat("Face", "111111", 0.3)
for o in PARTS:
    n = o.name; m = SKIN if ("Head" in n or "Hand" in n or "LowerArm" in n) else SHIRT if ("Torso" in n or "UpperArm" in n) else SHOE if "Foot" in n else PANTS
    if n == "LowerTorso": m = PANTS
    o.data.materials.clear(); o.data.materials.append(m)
    bv = o.modifiers.new("Bevel", "BEVEL"); bv.width = 0.07; bv.segments = 3
    for p in o.data.polygons: p.use_smooth = True
    o.data.shade_smooth() if hasattr(o.data, "shade_smooth") else None
head_o = bpy.data.objects["Head"]
bm = bmesh.new(); bm.from_mesh(head_o.data); dl = bm.verts.layers.deform.verify(); gi = head_o.vertex_groups["Head"].index
head_o.data.materials.append(FACE)
def face_box(c, s):
    r = bmesh.ops.create_cube(bm, size=1)
    for v in r["verts"]:
        v.co = Vector((v.co.x * s[0] + c[0], v.co.y * s[1] + c[1], v.co.z * s[2] + c[2])); v[dl][gi] = 1.0
    for f in {f for v in r["verts"] for f in v.link_faces}: f.material_index = 1
face_box((0.24, -0.6, 4.72), (0.13, 0.04, 0.24)); face_box((-0.24, -0.6, 4.72), (0.13, 0.04, 0.24))
face_box((0.25, -0.6, 4.84), (0.24, 0.04, 0.05)); face_box((-0.25, -0.6, 4.84), (0.24, 0.04, 0.05))   # flat serious brows
face_box((0, -0.6, 4.42), (0.34, 0.04, 0.05))
bm.to_mesh(head_o.data); bm.free()

LAT, FWD, Z = Vector((1, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1))
F = 48; scene.frame_start, scene.frame_end = 1, F; scene.render.fps = 24
START, END, T0, T1 = 14.0, -3.0, 10, 15          # dash from y=START to y=END between frames T0 and T1

def rot(name, axis, deg):
    pb = rig.pose.bones[name]; pb.rotation_mode = "QUATERNION"
    ax = rig.data.bones[name].matrix_local.to_3x3().inverted() @ axis
    pb.rotation_quaternion = Quaternion(ax.normalized(), math.radians(deg))
# +deg about the lateral axis swings a hanging limb backward and tips the torso forward (character faces -Y)
DASH = {"LowerTorso": 12, "UpperTorso": 22, "Head": -22,
        "LeftUpperArm": 75, "RightUpperArm": 62, "LeftLowerArm": 12, "RightLowerArm": 20,
        "LeftUpperLeg": -62, "LeftLowerLeg": 78, "LeftFoot": -12, "RightUpperLeg": 30, "RightLowerLeg": 55, "RightFoot": 25}
CROUCH = {"LowerTorso": 8, "UpperTorso": 26, "Head": -20, "LeftUpperArm": 35, "RightUpperArm": 30, "LeftLowerArm": -45,
          "RightLowerArm": -40, "LeftUpperLeg": -58, "RightUpperLeg": -40, "LeftLowerLeg": 88, "RightLowerLeg": 80,
          "LeftFoot": -30, "RightFoot": -40}
def pose(table, frame):
    for pb in rig.pose.bones: pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = (1, 0, 0, 0)
    for n, d in table.items(): rot(n, LAT, d)
    for pb in rig.pose.bones: pb.keyframe_insert("rotation_quaternion", frame=frame)
pose({}, 1); pose(CROUCH, 8); pose(CROUCH, T0 - 1); pose(DASH, T0 + 1); pose(DASH, T1 + 4); pose({}, 32)

def key_obj(o, frame, loc=None, rot_x=None):
    if loc is not None: o.location = loc; o.keyframe_insert("location", frame=frame)
    if rot_x is not None: o.rotation_euler.x = math.radians(rot_x); o.keyframe_insert("rotation_euler", frame=frame)
key_obj(rig, 1, (0, START, 0), 0); key_obj(rig, 8, (0, START + 0.3, -0.75), 0); key_obj(rig, T0 - 1, (0, START + 0.4, -0.85), 0)
key_obj(rig, T0, (0, START, 0.2), 4)
for f in range(T0 + 1, T1 + 1):
    t = (f - T0) / (T1 - T0); e = 1 - (1 - t) ** 3
    key_obj(rig, f, (0, START + (END - START) * e, 0.35 * math.sin(math.pi * t) - 0.35), 0)
key_obj(rig, T1 + 3, (0, END - 0.8, -0.3), 0); key_obj(rig, T1 + 8, (0, END - 1.0, 0), 0); key_obj(rig, F, (0, END - 1.0, 0), 0)

# ---------- materials ----------
def glow_mat(name, rgb, strength, render_blend=True):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (*rgb, 1)
    val = nt.nodes.new("ShaderNodeValue"); val.outputs[0].default_value = 1.0
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = strength
    nt.links.new(val.outputs[0], mul.inputs[0]); nt.links.new(mul.outputs[0], em.inputs["Strength"])
    add = nt.nodes.new("ShaderNodeAddShader"); nt.links.new(tr.outputs[0], add.inputs[0]); nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    for attr, v in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try: setattr(m, attr, v)
        except Exception: pass
    return m, val
def ramp_mat(name, rgb_tail, rgb_head, strength, power=1.6):
    """additive glow that fades from the ribbon's tail (u=0) to its head (u=1) and across its width (v)."""
    m, val = glow_mat(name, rgb_head, strength); nt = m.node_tree
    em = [n for n in nt.nodes if n.type == "EMISSION"][0]; mul = em.inputs["Strength"].links[0].from_node
    uv = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(uv.outputs["UV"], sep.inputs[0])
    pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = power; nt.links.new(sep.outputs[0], pw.inputs[0])
    edge = nt.nodes.new("ShaderNodeMath"); edge.operation = "SUBTRACT"; edge.inputs[0].default_value = 1
    vv = nt.nodes.new("ShaderNodeMath"); vv.operation = "ABSOLUTE"
    c = nt.nodes.new("ShaderNodeMath"); c.operation = "MULTIPLY_ADD"; c.inputs[1].default_value = 2; c.inputs[2].default_value = -1
    nt.links.new(sep.outputs[1], c.inputs[0]); nt.links.new(c.outputs[0], vv.inputs[0]); nt.links.new(vv.outputs[0], edge.inputs[1])
    a1 = nt.nodes.new("ShaderNodeMath"); a1.operation = "MULTIPLY"; nt.links.new(pw.outputs[0], a1.inputs[0]); nt.links.new(edge.outputs[0], a1.inputs[1])
    a2 = nt.nodes.new("ShaderNodeMath"); a2.operation = "MULTIPLY"; nt.links.new(a1.outputs[0], a2.inputs[0]); nt.links.new(mul.outputs[0], a2.inputs[1])
    nt.links.new(a2.outputs[0], em.inputs["Strength"])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; ins = [s for s in mix.inputs if s.type == "RGBA"]
    ins[0].default_value = (*rgb_tail, 1); ins[1].default_value = (*rgb_head, 1); nt.links.new(sep.outputs[0], mix.inputs[0])
    nt.links.new([s for s in mix.outputs if s.type == "RGBA"][0], em.inputs["Color"])
    return m, val
def fade(val, keys):
    for f, v in keys: val.outputs[0].default_value = v; val.outputs[0].keyframe_insert("default_value", frame=f)
CYAN, WHITE, BLUE, VIOLET = (0.25, 0.85, 1.0), (1, 1, 1), (0.1, 0.35, 1.0), (0.55, 0.3, 1.0)

def link(name, me, mat):
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o); me.materials.clear(); me.materials.append(mat)
    o.visible_shadow = False; return o

# ---------- afterimages: frozen copies of the dash pose along the path ----------
scene.frame_set(T0 + 2); dg = bpy.context.evaluated_depsgraph_get(); bake_y = rig.matrix_world.translation.y
gb = bmesh.new()
for o in PARTS:
    em = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); em.transform(o.matrix_world); gb.from_mesh(em)
ghost_mesh = bpy.data.meshes.new("GhostSrc"); gb.to_mesh(ghost_mesh); gb.free()
from mathutils import Matrix
base_m = Matrix.Identity(4)
for k in range(5):
    f = T0 + k; t = k / 5; e = 1 - (1 - t) ** 3; y = START + (END - START) * e
    me = ghost_mesh.copy(); bm = bmesh.new(); bm.from_mesh(me)
    for v in bm.verts: v.co = base_m @ v.co
    bm.to_mesh(me); bm.free()
    col = [CYAN, CYAN, BLUE, VIOLET, VIOLET][k]
    m, val = glow_mat(f"Ghost{k}", col, 0.55 - 0.08 * k)
    o = link(f"Afterimage{k}", me, m); o.location = (0, y - bake_y, 0.4 * math.sin(math.pi * t))
    o.scale = (1, 1.04 + 0.04 * k, 1)
    fade(val, [(1, 0), (f, 0), (f + 1, 1.0), (f + 3, 0.5), (f + 10, 0)])

# ---------- energy ribbons along the path ----------
def ribbon(name, y0, y1, x, z, width, wave, phase, mat, n=40, twist=0.0):
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap"); rows = []
    for i in range(n + 1):
        u = i / n; y = y0 + (y1 - y0) * u
        c = Vector((x + wave * math.sin(u * 7 + phase), y, z + wave * 0.7 * math.cos(u * 5 + phase)))
        w = width * (0.25 + 0.75 * u); a = twist * u
        side = Vector((math.cos(a) * 0.15, 0, math.sin(a))) if twist else Vector((0, 0, 1))
        rows.append((bm.verts.new(c - side * w / 2), bm.verts.new(c + side * w / 2), u))
    for (a0, b0, u0), (a1, b1, u1) in zip(rows, rows[1:]):
        f = bm.faces.new((a0, a1, b1, b0))
        for l, uv in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))): l[uvl].uv = uv
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); return link(name, me, mat)
specs = [(0.0, 3.6, 1.3, 0.6, 0.0, CYAN, 3.5), (0.9, 2.6, 0.7, 0.5, 1.5, BLUE, 5), (-0.9, 2.8, 0.7, 0.45, 3.0, BLUE, 5),
         (0.5, 5.2, 0.5, 0.35, 4.2, VIOLET, 4), (-0.6, 1.4, 0.45, 0.3, 2.2, CYAN, 4), (0.0, 4.4, 0.7, 0.7, 5.1, WHITE, 2)]
for i, (x, z, w, wave, ph, col, s) in enumerate(specs):
    m, val = ramp_mat(f"Ribbon{i}", BLUE if col != WHITE else CYAN, col, s)
    ribbon(f"Ribbon{i}", START + 2.5, END + 1.2, x, z, w, wave, ph, m, twist=0.6 if i % 2 else 0)
    fade(val, [(1, 0), (T0, 0), (T0 + 2, 1.0), (T1 + 2, 0.8), (T1 + 18, 0)])

# ---------- speed lines ----------
m_lines, v_lines = ramp_mat("SpeedLines", BLUE, WHITE, 2.2, power=1.4)
bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
for i in range(16):
    x = random.choice((-1, 1)) * random.uniform(1.6, 4.5); z = random.uniform(0.3, 5.5)
    y0 = random.uniform(END + 2, START - 2); L = random.uniform(3, 7); w = random.uniform(0.04, 0.09)
    vs = [bm.verts.new(p) for p in ((x, y0 + L, z - w), (x, y0, z - w), (x, y0, z + w), (x, y0 + L, z + w))]
    f = bm.faces.new(vs)
    for l, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))): l[uvl].uv = uv
me = bpy.data.meshes.new("SpeedLines"); bm.to_mesh(me); bm.free(); link("SpeedLines", me, m_lines)
fade(v_lines, [(1, 0), (T0, 0), (T0 + 1, 1.0), (T1 + 1, 0.7), (T1 + 9, 0)])

# ---------- launch burst: ring, shards, dust ----------
m_ring, v_ring = glow_mat("BurstRing", CYAN, 3.5)
bm = bmesh.new()
for r0, r1 in ((1.0, 1.35),):
    ring_o = [bm.verts.new((r1 * math.cos(a), r1 * math.sin(a), 0.05)) for a in [2 * math.pi * i / 40 for i in range(40)]]
    ring_i = [bm.verts.new((r0 * math.cos(a), r0 * math.sin(a), 0.05)) for a in [2 * math.pi * i / 40 for i in range(40)]]
    for i in range(40): bm.faces.new((ring_i[i], ring_i[(i + 1) % 40], ring_o[(i + 1) % 40], ring_o[i]))
me = bpy.data.meshes.new("BurstRing"); bm.to_mesh(me); bm.free(); ring = link("BurstRing", me, m_ring)
ring.location = (0, START + 0.3, 0)
for f, s in ((1, 0.2), (T0 - 6, 0.6), (T0 - 1, 1.2), (T0 + 1, 2.4), (T0 + 10, 5.0)):
    ring.scale = (s, s, 1); ring.keyframe_insert("scale", frame=f)
fade(v_ring, [(1, 0), (T0 - 8, 0.6), (T0 - 1, 1.0), (T0 + 1, 1.4), (T0 + 10, 0)])
m_dust, v_dust = glow_mat("Dust", (0.55, 0.65, 0.85), 0.35)
m_shard, v_shard = glow_mat("Shards", CYAN, 9)
for i in range(22):
    a = random.uniform(0, 2 * math.pi); r = random.uniform(0.6, 1.6)
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=1, radius=random.uniform(0.25, 0.6) if i < 12 else random.uniform(0.05, 0.12))
    me = bpy.data.meshes.new("p"); bm.to_mesh(me); bm.free()
    o = link(f"Dust{i}" if i < 12 else f"Shard{i}", me, m_dust if i < 12 else m_shard)
    p0 = Vector((r * math.cos(a), START + 0.5 + r * math.sin(a) * 0.6, 0.2))
    d = Vector((math.cos(a), math.sin(a) * 0.6 + 0.5, 0)).normalized()
    o.location = p0; o.scale = (0.01, 0.01, 0.01); o.keyframe_insert("location", frame=T0); o.keyframe_insert("scale", frame=T0 - 1)
    o.scale = (1, 1, 0.6); o.keyframe_insert("scale", frame=T0 + 1)
    o.location = p0 + d * random.uniform(1.5, 3.5) + Vector((0, 0, random.uniform(0.3, 1.8) if i >= 12 else 0.4))
    o.keyframe_insert("location", frame=T0 + 12)
    o.scale = (1.6, 1.6, 0.9) if i < 12 else (0.01, 0.01, 0.01); o.keyframe_insert("scale", frame=T0 + 16)
fade(v_dust, [(1, 0), (T0, 0), (T0 + 1, 1), (T0 + 18, 0)]); fade(v_shard, [(1, 0), (T0, 0), (T0 + 1, 1), (T0 + 14, 0)])

# ---------- charge glow at the feet, ground streak, arrival sparkles ----------
m_streak, v_streak = ramp_mat("Streak", VIOLET, CYAN, 4, power=0.8)
ribbon("GroundStreak", START, END + 0.5, 0, 0.03, 1.4, 0.0, 0, m_streak, n=10).rotation_euler.y = 0
gs = bpy.data.objects["GroundStreak"]; bm = bmesh.new(); bm.from_mesh(gs.data)
for v in bm.verts: v.co.x, v.co.z = (v.co.z - 0.03) * 1.0, 0.03          # lay the strip flat on the ground
bm.to_mesh(gs.data); bm.free()
fade(v_streak, [(1, 0), (T0, 0), (T0 + 2, 1), (T1 + 6, 0.6), (F, 0)])
m_sp, v_sp = glow_mat("Sparkles", WHITE, 14)
for i in range(60):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=1, radius=random.uniform(0.025, 0.07))
    me = bpy.data.meshes.new("s"); bm.to_mesh(me); bm.free(); o = link(f"Sparkle{i}", me, m_sp)
    y = random.uniform(END, START); p = Vector((random.uniform(-1.6, 1.6), y, random.uniform(0.3, 4.5)))
    o.location = p; o.keyframe_insert("location", frame=T0 + 1)
    o.location = p + Vector((random.uniform(-0.6, 0.6), random.uniform(0.5, 1.5), random.uniform(0.3, 1.2))); o.keyframe_insert("location", frame=F)
fade(v_sp, [(1, 0), (T0, 0), (T0 + 2, 1), (T1 + 10, 0.5), (F, 0)])

# ---------- stage: dark glossy floor, cool key, coloured rims ----------
gd = bpy.data.meshes.new("Floor"); bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, radius=80, segments=64); bm.to_mesh(gd); bm.free()
fl = bpy.data.objects.new("Floor", gd); scene.collection.objects.link(fl)
fm = bpy.data.materials.new("Floor"); fm.use_nodes = True; p = fm.node_tree.nodes["Principled BSDF"]
p.inputs["Base Color"].default_value = (0.012, 0.014, 0.024, 1); p.inputs["Roughness"].default_value = 0.28; gd.materials.append(fm)
world = scene.world; bg = world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = (0.006, 0.008, 0.02, 1); bg.inputs["Strength"].default_value = 1
def light(name, kind, e, loc, rot_, col, spec=1.0, size=1.0):
    ld = bpy.data.lights.new(name, kind); ld.energy = e; ld.color = col; ld.specular_factor = spec
    if kind == "AREA": ld.size = size
    o = bpy.data.objects.new(name, ld); o.location = loc; o.rotation_euler = [math.radians(a) for a in rot_]; scene.collection.objects.link(o)
light("Key", "SUN", 3.2, (0, 0, 20), (40, 0, 60), (0.85, 0.9, 1.0), spec=0.3)
light("RimCyan", "AREA", 900, (-8, -6, 7), (60, 0, -130), (0.3, 0.8, 1.0), size=8)
light("RimViolet", "AREA", 700, (8, 10, 6), (60, 0, 40), (0.6, 0.35, 1.0), spec=0.0, size=8)
dl = bpy.data.lights.new("DashGlow", "POINT"); dl.color = (0.3, 0.8, 1.0); dl.specular_factor = 0
dlo = bpy.data.objects.new("DashGlow", dl); scene.collection.objects.link(dlo); dlo.parent = rig; dlo.location = (0, 2.5, 2.5)
for f, e in ((1, 0), (T0 - 6, 150), (T0 + 1, 1600), (T1 + 6, 400), (F, 60)): dl.energy = e; dl.keyframe_insert("energy", frame=f)

# ---------- camera with a hit of shake on launch ----------
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
cd.lens = 28; base = Vector((22, 3.4, 4.8)); tgt = Vector((0, 3.6, 2.4))
cam.rotation_euler = (tgt - base).to_track_quat("-Z", "Y").to_euler()
for f in range(1, F + 1):
    k = max(0.0, 1 - abs(f - (T0 + 1)) / 5) if f >= T0 - 1 else 0.0
    cam.location = base + Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.18 * k \
                   + Vector((0, -0.02 * f, 0))
    cam.keyframe_insert("location", frame=f)

# ---------- render: Eevee + bloom (compositor group, Blender 5 style) ----------
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
try:
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree"); scene.compositing_node_group = ng
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare"); go = ng.nodes.new("NodeGroupOutput")
    for k, v in (("Type", "Bloom"), ("Threshold", 0.9), ("Strength", 0.85), ("Size", 0.6), ("Quality", "High")):
        try: gl.inputs[k].default_value = v
        except Exception: pass
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], go.inputs[0])
except Exception as ex: print("COMPOSITOR", ex)
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
OUT = os.path.join(HERE, "out"); os.makedirs(OUT, exist_ok=True)  # renders and video land here
for f in (6, T0 + 1, T0 + 3, T1 + 2, T1 + 12):
    scene.frame_set(f); scene.render.filepath = os.path.join(OUT, f"dash_f{f:02d}.png"); bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Dash.blend"))
print("STILLS DONE")
try: scene.render.image_settings.media_type = "VIDEO"
except Exception: pass
scene.render.image_settings.file_format = "FFMPEG"; scene.render.ffmpeg.format = "MPEG4"; scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "HIGH"
scene.render.filepath = os.path.join(OUT, "dash_effect.mp4"); bpy.ops.render.render(animation=True)
print("VIDEO DONE")
