"""Three low-poly trees, following the vault's tree recipe (Low-Poly and Stylized Modeling):
5-8 sided tapered trunk with a root flare and a branch or two; canopy of 3-5 overlapping displaced
icospheres in 2-3 greens, darker underneath and lighter on top; flat shaded; 200-1,500 tris each.
Trees: round oak, layered pine, autumn birch. 1 unit = 1 stud. Exports one FBX per tree + a preview.
Run: blender -b --factory-startup --python build_trees.py"""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, rgb, rough=0.85):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*rgb, 1); return m
BARK = mat("Bark", (0.28, 0.16, 0.09)); BARK_BIRCH = mat("BarkBirch", (0.86, 0.84, 0.78)); BIRCH_MARK = mat("BirchMark", (0.12, 0.1, 0.1))
G_DARK = mat("LeafDark", (0.13, 0.36, 0.11)); G_MID = mat("LeafMid", (0.24, 0.55, 0.16)); G_LIGHT = mat("LeafLight", (0.45, 0.72, 0.22))
P_DARK = mat("PineDark", (0.06, 0.26, 0.17)); P_MID = mat("PineMid", (0.1, 0.38, 0.22)); P_LIGHT = mat("PineLight", (0.2, 0.52, 0.28))
A_DARK = mat("AutumnDark", (0.72, 0.22, 0.05)); A_MID = mat("AutumnMid", (0.95, 0.45, 0.08)); A_LIGHT = mat("AutumnLight", (1.0, 0.72, 0.18))
MATS = [BARK, BARK_BIRCH, BIRCH_MARK, G_DARK, G_MID, G_LIGHT, P_DARK, P_MID, P_LIGHT, A_DARK, A_MID, A_LIGHT]
MI = {m.name: i for i, m in enumerate(MATS)}

def trunk(bm, base, top, r0, r1, sides, mat_name, flare=0.0, lean=Vector()):
    """Tapered faceted trunk with an optional root flare (bottom ring pushed out, alternating)."""
    n = 4; rings = []
    for i in range(n + 1):
        t = i / n; c = base.lerp(top, t) + lean * (t * t)
        r = r0 + (r1 - r0) * t
        ring = []
        for k in range(sides):
            a = k / sides * math.tau + i * 0.3
            rr = r * (1 + (flare if (i == 0 and k % 2 == 0) else 0) + (flare * 0.4 if (i == 0 and k % 2) else 0))
            ring.append(bm.verts.new(c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0))))
        rings.append(ring)
    faces = [bm.faces.new(list(reversed(rings[0])))]
    for a, b_ in zip(rings, rings[1:]):
        for k in range(sides): faces.append(bm.faces.new((a[k], a[(k + 1) % sides], b_[(k + 1) % sides], b_[k])))
    faces.append(bm.faces.new(rings[-1]))
    for f in faces: f.material_index = MI[mat_name]
    return rings[-1]

def blob(bm, c, radii, mat_name, seed, jitter=0.14, sub=2):
    r = random.Random(seed)
    res = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in res["verts"]:
        n = v.co.normalized()
        d = 1 + r.uniform(-jitter, jitter)
        if n.z < -0.4: d *= 0.82                      # flatter underside
        v.co = Vector((n.x * radii[0] * d, n.y * radii[1] * d, n.z * radii[2] * d)) + Vector(c)
    faces = {f for v in res["verts"] for f in v.link_faces}
    for f in faces: f.material_index = MI[mat_name]
    return faces

def shade_by_height(bm, faces, z_lo, z_hi, names):
    """Darker greens low, lighter on top: fake light that survives any sky (vault tree rule)."""
    for f in faces:
        z = f.calc_center_median().z; t = (z - z_lo) / max(1e-4, z_hi - z_lo)
        up = f.normal.z
        idx = 0 if t < 0.35 or up < -0.35 else (2 if t > 0.7 and up > 0.2 else 1)
        f.material_index = MI[names[idx]]

def finish(name, bm, loc):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in MATS: me.materials.append(m)
    for p in me.polygons: p.use_smooth = False
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o); o.location = loc
    me.calc_loop_triangles(); print(name, "TRIS", len(me.loop_triangles))
    return o

# ---------------- 1. Round oak: flared trunk, two branches, 5 canopy blobs ----------------
random.seed(1); bm = bmesh.new()
trunk(bm, Vector((0, 0, 0)), Vector((0, 0, 6.5)), 1.0, 0.55, 7, "Bark", flare=0.55)
for d, h, l in ((Vector((1, 0.3, 0.9)), 3.8, 2.6), (Vector((-0.9, -0.4, 1.0)), 4.6, 2.2)):
    trunk(bm, Vector((0, 0, h)), Vector((0, 0, h)) + d.normalized() * l, 0.38, 0.2, 6, "Bark")
leaves = set()
for i, (c, r) in enumerate((((0, 0, 8.6), (3.6, 3.4, 2.9)), ((2.6, 0.8, 7.4), (2.4, 2.2, 2.0)), ((-2.5, -0.9, 7.8), (2.3, 2.3, 2.0)),
                            ((0.6, -2.2, 8.0), (2.2, 2.0, 1.9)), ((-0.4, 1.9, 9.8), (2.2, 2.0, 1.8)))):
    leaves |= blob(bm, c, r, "LeafMid", 10 + i)
shade_by_height(bm, leaves, 5.6, 11.3, ("LeafDark", "LeafMid", "LeafLight"))
oak = finish("Tree_Oak", bm, (-9, 0, 0))

# ---------------- 2. Pine: tall trunk, 5 stacked faceted cones, slight twist per tier ----------------
random.seed(2); bm = bmesh.new()
trunk(bm, Vector((0, 0, 0)), Vector((0, 0, 3.2)), 0.65, 0.42, 6, "Bark", flare=0.4)
tiers = [(2.4, 4.1, 3.2), (4.3, 3.4, 3.0), (6.0, 2.7, 2.8), (7.6, 2.0, 2.6), (9.0, 1.3, 2.4)]
pine_faces = []
for i, (z, r, h) in enumerate(tiers):
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=r, radius2=0.0, depth=h,
                                matrix=Matrix.Translation((0, 0, z + h / 2)) @ Euler((0, 0, i * 0.39)).to_matrix().to_4x4())
    for v in res["verts"]:
        if v.co.z < z + 0.05:                          # ragged hanging skirt: alternate rim verts drop
            k = math.atan2(v.co.y, v.co.x); v.co.z -= 0.35 * (0.5 + 0.5 * math.sin(k * 4 + i))
    fs = {f for v in res["verts"] for f in v.link_faces}
    for f in fs:
        f.material_index = MI["PineDark"] if f.normal.z < -0.2 else (MI["PineLight"] if i >= 3 else MI["PineMid"])
pine = finish("Tree_Pine", bm, (0, 0, 0))

# ---------------- 3. Autumn birch: slim leaning white trunk with dark marks, airy 4-blob crown ----------------
random.seed(3); bm = bmesh.new()
lean = Vector((0.9, 0.2, 0))
trunk(bm, Vector((0, 0, 0)), Vector((0, 0, 8.0)), 0.5, 0.28, 6, "BarkBirch", flare=0.35, lean=lean)
for i in range(7):                                     # dark bark marks: thin squashed boxes on the trunk
    t = 0.12 + i * 0.12; c = Vector((0, 0, 8.0 * t)) + lean * (t * t); a = random.uniform(0, math.tau); r = 0.5 + (0.28 - 0.5) * t
    res = bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Translation(c + Vector((math.cos(a) * r, math.sin(a) * r, 0))) @ Euler((0, 0, a)).to_matrix().to_4x4() @ Matrix.Diagonal((0.14, 0.42, 0.11, 1)))
    for v in res["verts"]:
        for f in v.link_faces: f.material_index = MI["BirchMark"]
trunk(bm, Vector((0.25, 0.05, 5.0)), Vector((-1.6, 0.4, 7.4)), 0.2, 0.1, 5, "BarkBirch")
leaves = set()
top = Vector((0, 0, 8.0)) + lean
for i, (o, r) in enumerate((((0, 0, 1.2), (2.4, 2.3, 2.2)), ((-1.9, 0.4, -0.2), (1.8, 1.7, 1.6)), ((1.5, -0.8, 0.0), (1.7, 1.6, 1.5)), ((0.3, 1.2, 2.6), (1.5, 1.4, 1.4)))):
    leaves |= blob(bm, top + Vector(o), r, "AutumnMid", 30 + i, jitter=0.22)
shade_by_height(bm, leaves, top.z - 1.8, top.z + 4.0, ("AutumnDark", "AutumnMid", "AutumnLight"))
birch = finish("Tree_Birch", bm, (9, 0, 0))

# ---------------- export one FBX per tree (origin at the trunk base) ----------------
for o in (oak, pine, birch):
    loc = o.location.copy(); o.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, o.name + ".fbx"), use_selection=True, mesh_smooth_type="FACE")
    o.location = loc

# ---------------- preview: grass island, sun, soft sky ----------------
bm = bmesh.new(); res = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=16, radius2=15.2, depth=1.6)
for v in res["verts"]:
    v.co.z -= 0.8; v.co.x *= 1.15
    if v.co.z < -0.5: v.co *= 0.8
me = bpy.data.meshes.new("Island"); bm.to_mesh(me); bm.free(); me.materials.append(mat("Grass", (0.3, 0.6, 0.2)))
scene.collection.objects.link(bpy.data.objects.new("Island", me))
world = bpy.data.worlds.new("Sky"); world.use_nodes = True; nt = world.node_tree; bg = nt.nodes["Background"]
tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); cr = nt.nodes.new("ShaderNodeValToRGB")
cr.color_ramp.elements[0].color = (0.95, 0.85, 0.72, 1); cr.color_ramp.elements[1].color = (0.45, 0.68, 0.95, 1)
nt.links.new(tc.outputs["Window"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], cr.inputs["Fac"]); nt.links.new(cr.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.6; scene.world = world
sun = bpy.data.lights.new("Sun", "SUN"); sun.energy = 3.5; sun.color = (1, 0.95, 0.85); sun.angle = math.radians(6)
so = bpy.data.objects.new("Sun", sun); scene.collection.objects.link(so); so.rotation_euler = (math.radians(48), math.radians(12), math.radians(-40))
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
try: scene.eevee.use_raytracing = True
except Exception: pass
scene.render.resolution_x = 1920; scene.render.resolution_y = 1080; scene.view_settings.view_transform = "Standard"
cam.location = (2, -34, 10); cd.lens = 38
cam.rotation_euler = (Vector((0, 0, 5.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.join(OUT, "trees_preview.png"); bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "LowPolyTrees.blend"))
print("DONE")
