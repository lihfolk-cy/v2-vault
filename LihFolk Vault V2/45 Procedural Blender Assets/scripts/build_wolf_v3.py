"""Grey wolf v3, built with the vault workflow (45 Procedural Blender Assets + 08 Creature Rig Conventions +
14 Low-Poly and Stylized Modeling):
  one carved mass (lofts traced from the side view, voxel-fused, then triangulate / dissolve_limit / triangulate),
  flat per-face colour from a palette atlas, quadruped rig (Root at origin, faces -Y, 1 unit = 1 stud, ~8 studs
  to the head), reach-normalised skinning (max 2 influences), walk cycle, GLB export.
blender -b --factory-startup --python build_wolf_v3.py"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix, Quaternion

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"); os.makedirs(OUT, exist_ok=True)  # renders and exports land here
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
S = 5.6                                                     # design units -> studs (head top ~8 studs)
def T(p): x, y, z = p; return Vector((S * y, -S * x, S * z))  # +X forward design frame -> faces -Y, scaled
X0, Y0 = Vector((1, 0, 0)), Vector((0, 1, 0)); Z = Vector((0, 0, 1))
FWD, LAT = Vector((0, -1, 0)), Vector((1, 0, 0))            # world axes after T

# ---------- loft helpers (design frame) ----------
def ring(c, u, v, a, b, n=24, e=2.0):
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n; ct, st = math.cos(t), math.sin(t)
        out.append(c + u * (a * math.copysign(abs(ct) ** (2 / e), ct)) + v * (b * math.copysign(abs(st) ** (2 / e), st)))
    return out
def loft(bm, rings):
    vs = [[bm.verts.new(p) for p in r] for r in rings]; n = len(vs[0])
    for r0, r1 in zip(vs, vs[1:]):
        for i in range(n): bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    for r, flip in ((vs[0], True), (vs[-1], False)):
        c = bm.verts.new(sum((v.co for v in r), Vector()) / n)
        for i in range(n):
            f = (r[i], r[(i + 1) % n], c); bm.faces.new(f[::-1] if flip else f)
def lerp_table(tab, x):
    for k0, k1 in zip(tab, tab[1:]):
        if k0[0] <= x <= k1[0]:
            t = (x - k0[0]) / (k1[0] - k0[0]); t = t * t * (3 - 2 * t) * 0.5 + t * 0.5
            return [a + (b - a) * t for a, b in zip(k0[1:], k1[1:])]
    return list((tab[0] if x < tab[0][0] else tab[-1])[1:])
def along_x(bm, tab, y=0.0, step=0.015, e=2.0):
    x0, x1 = tab[0][0], tab[-1][0]; n = max(2, int((x1 - x0) / step)); rings = []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n; top, bot, w = lerp_table(tab, x)
        rings.append(ring(Vector((x, y, (top + bot) / 2)), Y0, Z, w, (top - bot) / 2, e=e))
    loft(bm, rings)
def tube(bm, pts, radii, step=0.015, flat=1.0, n=20):
    L = [0.0]
    for a, b in zip(pts, pts[1:]): L.append(L[-1] + (Vector(b) - Vector(a)).length)
    k_n = max(2, int(L[-1] / step)); rings = []
    for i in range(k_n + 1):
        s = L[-1] * i / k_n
        k = min(max(j for j in range(len(L) - 1) if L[j] <= s + 1e-9), len(L) - 2)
        t = (s - L[k]) / (L[k + 1] - L[k]); p = Vector(pts[k]).lerp(Vector(pts[k + 1]), t)
        r = radii[k] + (radii[k + 1] - radii[k]) * t
        d = (Vector(pts[k + 1]) - Vector(pts[k])).normalized()
        side = Y0 if abs(d.dot(Y0)) < 0.9 else X0
        u = (side - d * side.dot(d)).normalized(); v = d.cross(u).normalized()
        rings.append(ring(p, u, v, r * flat, r, n=n))
    loft(bm, rings)
def cone(bm, base, tip, r, flat=0.55, n=8):
    d = Vector(tip) - Vector(base); dn = d.normalized()
    u = (Y0 - dn * Y0.dot(dn)).normalized() if abs(dn.dot(Y0)) < 0.9 else X0; v = dn.cross(u)
    loft(bm, [ring(Vector(base) - dn * r * 0.8, u, v, r * flat, r, n=n), ring(Vector(base), u, v, r * flat, r, n=n),
              ring(Vector(base) + d * 0.55, u, v, r * flat * 0.45, r * 0.45, n=n), ring(Vector(tip), u, v, 0.002, 0.002, n=n)])

# ---------- 1. one mass, traced from the side view ----------
bm = bmesh.new()
along_x(bm, [(-0.64, 0.80, 0.62, 0.09), (-0.58, 0.85, 0.53, 0.15), (-0.45, 0.87, 0.50, 0.17), (-0.25, 0.875, 0.53, 0.165),
             (-0.05, 0.90, 0.50, 0.18), (0.10, 0.95, 0.46, 0.195), (0.22, 0.99, 0.47, 0.185), (0.32, 1.02, 0.55, 0.15),
             (0.38, 1.03, 0.68, 0.09)])
tube(bm, [(0.17, 0, 0.78), (0.30, 0, 0.96), (0.44, 0, 1.12), (0.50, 0, 1.17)], [0.19, 0.19, 0.15, 0.12], flat=0.95)
along_x(bm, [(0.40, 1.27, 1.07, 0.10), (0.47, 1.29, 1.05, 0.125), (0.55, 1.28, 1.06, 0.115), (0.62, 1.22, 1.08, 0.08),
             (0.70, 1.195, 1.09, 0.06), (0.75, 1.19, 1.10, 0.05), (0.78, 1.18, 1.115, 0.032)])
for s in (1, -1):
    yf, yh = 0.13 * s, 0.135 * s
    tube(bm, [(0.13, yf, 0.75), (0.14, yf, 0.55), (0.12, yf, 0.42), (0.14, yf, 0.12), (0.16, yf, 0.05)],
         [0.10, 0.075, 0.06, 0.045, 0.045], flat=0.85)
    along_x(bm, [(0.10, 0.085, 0.0, 0.05), (0.16, 0.09, 0.0, 0.058), (0.235, 0.06, 0.0, 0.05)], y=yf, step=0.0135, e=2.2)
    tube(bm, [(-0.45, yh * 0.7, 0.78), (-0.44, yh, 0.62), (-0.37, yh, 0.44), (-0.50, yh, 0.24), (-0.49, yh, 0.10), (-0.46, yh, 0.05)],
         [0.15, 0.145, 0.09, 0.052, 0.045, 0.045], flat=0.8)
    along_x(bm, [(-0.53, 0.085, 0.0, 0.05), (-0.47, 0.09, 0.0, 0.058), (-0.395, 0.06, 0.0, 0.05)], y=yh, step=0.0135, e=2.2)
    cone(bm, (0.47, 0.065 * s, 1.24), (0.44, 0.085 * s, 1.44), 0.07, flat=0.5)          # ear
    cone(bm, (0.50, 0.10 * s, 1.08), (0.42, 0.155 * s, 0.98), 0.045)                     # cheek tufts
    cone(bm, (0.45, 0.11 * s, 1.03), (0.37, 0.175 * s, 0.92), 0.05)
    cone(bm, (0.12, 0.10 * s, 0.50), (0.06, 0.12 * s, 0.39), 0.04)                       # elbow tuft
tube(bm, [(-0.58, 0, 0.80), (-0.68, 0, 0.70), (-0.75, 0, 0.52), (-0.80, 0, 0.32), (-0.83, 0, 0.17), (-0.84, 0, 0.12)],
     [0.06, 0.085, 0.11, 0.105, 0.06, 0.012], flat=0.75)
for b, t in (((0.33, 0, 0.62), (0.37, 0, 0.46)), ((0.30, 0.07, 0.60), (0.31, 0.095, 0.44)), ((0.30, -0.07, 0.60), (0.31, -0.095, 0.44)),
             ((0.37, 0, 0.78), (0.45, 0, 0.66)), ((0.20, 0, 1.00), (0.11, 0, 1.09)), ((0.30, 0, 1.08), (0.22, 0, 1.17)),
             ((-0.80, 0, 0.30), (-0.90, 0, 0.22)), ((-0.76, 0, 0.45), (-0.86, 0, 0.42))):
    cone(bm, b, t, 0.05)
me = bpy.data.meshes.new("Wolf"); bm.to_mesh(me); bm.free()
tmp = bpy.data.objects.new("tmp", me); scene.collection.objects.link(tmp)
for kind, kw in (("REMESH", dict(mode="VOXEL", voxel_size=0.009)), ("SMOOTH", dict(factor=0.6, iterations=8))):
    md = tmp.modifiers.new(kind, kind)
    for k, v in kw.items(): setattr(md, k, v)
dg = bpy.context.evaluated_depsgraph_get(); dense = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
tmp.modifiers.clear(); tmp.data = dense
md = tmp.modifiers.new("DEC", "DECIMATE"); md.ratio = 2600 / len(dense.polygons)   # about 5k triangles, even spread
md.use_symmetry = True; md.symmetry_axis = "Y"
dg = bpy.context.evaluated_depsgraph_get(); body = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
bpy.data.objects.remove(tmp)

# ---------- 2. carve: triangulate, merge near-flat triangles into facets, triangulate ----------
bm = bmesh.new(); bm.from_mesh(body)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(5), verts=bm.verts[:], edges=bm.edges[:])
bmesh.ops.triangulate(bm, faces=bm.faces[:])

# ---------- 3. palette colours per face (flat-art regions as ellipsoids in the design frame) ----------
PAL = ["3F3D47", "2F2E36", "55545D", "67666F", "76757E", "2A2930", "0A090C", "1E1D22", "E9A93B", "FFFFFF", "8E8189"]
BASE, DARK, MID, LIGHT, PALE, PAW, NOSE, LINE, AMBER, WHITE, INNER = range(11)
def blob(p, c, r, tilt=0.0):
    d = p - Vector(c); a = math.radians(tilt)
    x = d.x * math.cos(a) + d.z * math.sin(a); z = -d.x * math.sin(a) + d.z * math.cos(a)
    return (x / r[0]) ** 2 + (d.y / r[1]) ** 2 + (z / r[2]) ** 2 < 1
def region(p):
    c = BASE
    for col, args in ((LIGHT, ((-0.14, 0, 0.40), (0.42, 0.9, 0.16), 6)), (LIGHT, ((-0.40, 0, 0.47), (0.12, 0.9, 0.15), -25)),
                      (MID, ((0.03, 0, 1.00), (0.22, 0.9, 0.12), -8)), (DARK, ((0.36, 0, 0.80), (0.20, 0.9, 0.40), 35)),
                      (PALE, ((0.42, 0, 0.78), (0.15, 0.9, 0.36), 35)), (MID, ((0.40, 0, 1.11), (0.15, 0.9, 0.10), 30)),
                      (MID, ((0.53, 0, 1.27), (0.16, 0.9, 0.08), 0)), (LIGHT, ((0.62, 0, 1.08), (0.17, 0.9, 0.07), 8)),
                      (PALE, ((0.66, 0, 1.06), (0.14, 0.9, 0.04), 6)), (LIGHT, ((0.74, 0, 1.21), (0.09, 0.9, 0.04), 5)),
                      (DARK, ((-0.84, 0, 0.16), (0.11, 0.9, 0.15), 0)), (DARK, ((0.45, 0, 1.36), (0.06, 0.9, 0.1), 0))):
        if blob(p, *args): c = col
    if p.z < 0.07: c = PAW
    return c
pal_layer = bm.faces.layers.int.new("pal")
for f in bm.faces: f[pal_layer] = region(f.calc_center_median())
# majority filter: a face whose colour none of its edge neighbours share takes the neighbours' colour (kills slivers)
for _ in range(2):
    new = {}
    for f in bm.faces:
        nb = [g[pal_layer] for e in f.edges for g in e.link_faces if g is not f]
        if nb and f[pal_layer] not in nb: new[f] = max(set(nb), key=nb.count)
    for f, c in new.items(): f[pal_layer] = c
# details: small separate meshes joined into the palette mesh (face design omitted from this copy)
def add_detail(build, col):
    b2 = bmesh.new(); build(b2); tmpm = bpy.data.meshes.new("d"); b2.to_mesh(tmpm); b2.free()
    for f in bm.faces: f.tag = True                       # new faces can reuse freed slots, so mark the old ones
    bm.from_mesh(tmpm)
    for f in bm.faces:
        if not f.tag: f[pal_layer] = col
def nose_b(b):
    bmesh.ops.create_icosphere(b, subdivisions=1, radius=0.036)
    for v in b.verts: v.co = Vector((v.co.x * 1.0, v.co.y * 1.15, v.co.z * 0.8)) + Vector((0.785, 0, 1.16))
add_detail(nose_b, NOSE)
for s in (1, -1):
    add_detail(lambda b, s=s: cone(b, (0.468, s * 0.093, 1.265), (0.448, s * 0.104, 1.405), 0.042, flat=0.3), INNER)  # inner ear
# palette atlas UVs: every face's loops at its swatch centre
uv = bm.loops.layers.uv.new("UVMap")
for f in bm.faces:
    u = (f[pal_layer] + 0.5) / len(PAL); du = 0.2 / len(PAL)                # small non-degenerate triangle inside the swatch
    for k, l in enumerate(f.loops): l[uv].uv = (u + du * (-1, 1, 0, 0)[k % 4], (0.4, 0.4, 0.6, 0.5)[k % 4])
# design frame -> studs, facing -Y
for v in bm.verts: v.co = T(v.co)
mesh = bpy.data.meshes.new("Wolf"); bm.to_mesh(mesh); bm.free()
for p in mesh.polygons: p.use_smooth = False
wolf = bpy.data.objects.new("Wolf", mesh); scene.collection.objects.link(wolf)
tris = len(mesh.polygons); print("WOLF TRIS", tris)

W = 16 * len(PAL)
img = bpy.data.images.new("WolfPalette", W, 4); px = []
for _ in range(4):
    for i in range(W):
        h = PAL[i // 16]; px += [int(h[k:k + 2], 16) / 255 for k in (0, 2, 4)] + [1.0]
img.pixels = px; img.filepath_raw = os.path.join(OUT, "Wolf_Palette.png"); img.file_format = "PNG"; img.save()
mat = bpy.data.materials.new("WolfPalette"); mat.use_nodes = True; nt = mat.node_tree; pb = nt.nodes["Principled BSDF"]
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], pb.inputs["Base Color"]); pb.inputs["Roughness"].default_value = 0.9
mesh.materials.append(mat)

# ---------- 4. quadruped rig (vault naming, Root on the ground at the origin) ----------
ad = bpy.data.armatures.new("WolfRig"); rig = bpy.data.objects.new("WolfRig", ad); scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig; rig.select_set(True); bpy.ops.object.mode_set(mode="EDIT")
B, REACH = {}, {}
def bone(n, h, t, p=None, reach=0.1, conn=False):
    b = ad.edit_bones.new(n); b.head = T(h); b.tail = T(t)
    if p: b.parent = B[p]; b.use_connect = conn
    B[n] = b; REACH[n] = reach
bone("Root", (0, 0, 0), (0.0, 0, 0.15), reach=0)
bone("Hips", (-0.42, 0, 0.72), (-0.15, 0, 0.73), "Root", 0.21)
bone("Spine", (-0.15, 0, 0.73), (0.12, 0, 0.76), "Hips", 0.21, True)
bone("Chest", (0.12, 0, 0.76), (0.28, 0, 0.92), "Spine", 0.23, True)
bone("Neck", (0.28, 0, 0.92), (0.45, 0, 1.12), "Chest", 0.19, True)
bone("Head", (0.45, 0, 1.12), (0.82, 0, 1.16), "Neck", 0.14, True)
for s, sy in (("L", 1), ("R", -1)):
    yf, yh = 0.13 * sy, 0.135 * sy
    bone("Ear" + s, (0.47, 0.065 * sy, 1.25), (0.44, 0.085 * sy, 1.44), "Head", 0.05)
    bone("UpperArm" + s, (0.14, yf, 0.70), (0.12, yf, 0.42), "Chest", 0.085)
    bone("LowerArm" + s, (0.12, yf, 0.42), (0.14, yf, 0.10), "UpperArm" + s, 0.06, True)
    bone("FrontPaw" + s, (0.14, yf, 0.10), (0.24, yf, 0.04), "LowerArm" + s, 0.06, True)
    bone("Thigh" + s, (-0.44, yh, 0.68), (-0.37, yh, 0.44), "Hips", 0.13)
    bone("Shin" + s, (-0.37, yh, 0.44), (-0.50, yh, 0.24), "Thigh" + s, 0.075, True)
    bone("Hock" + s, (-0.50, yh, 0.24), (-0.48, yh, 0.08), "Shin" + s, 0.055, True)
    bone("HindPaw" + s, (-0.48, yh, 0.08), (-0.39, yh, 0.04), "Hock" + s, 0.06, True)
bone("Tail1", (-0.58, 0, 0.80), (-0.70, 0, 0.66), "Hips", 0.09)
bone("Tail2", (-0.70, 0, 0.66), (-0.78, 0, 0.42), "Tail1", 0.11, True)
bone("Tail3", (-0.78, 0, 0.42), (-0.84, 0, 0.12), "Tail2", 0.1, True)
SEG = {n: (b.head.copy(), b.tail.copy()) for n, b in B.items()}
bpy.ops.object.mode_set(mode="OBJECT")

# ---------- 5. skinning: distance to each bone divided by its reach, 2 influences, sides kept apart ----------
def seg_d(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared)); return (p - (a + ab * t)).length
groups = {n: wolf.vertex_groups.new(name=n) for n in B if n != "Root"}
for v in mesh.vertices:
    p = v.co; side = p.x / S                                     # design +Y (left) is world +X
    cand = []
    for n, (a, b) in SEG.items():
        if n == "Root": continue
        if n.endswith("L") and side < -0.03: continue
        if n.endswith("R") and side > 0.03: continue
        cand.append((seg_d(p, a, b) / (REACH[n] * S), n))
    cand.sort(); (d1, n1), (d2, n2) = cand[0], cand[1]
    if d2 > d1 * 1.6: groups[n1].add([v.index], 1.0, "REPLACE")
    else:
        w1, w2 = 1 / max(d1, 1e-4) ** 4, 1 / max(d2, 1e-4) ** 4
        groups[n1].add([v.index], w1 / (w1 + w2), "REPLACE"); groups[n2].add([v.index], w2 / (w1 + w2), "REPLACE")
wolf.parent = rig; arm = wolf.modifiers.new("Armature", "ARMATURE"); arm.object = rig

# ---------- 6. walk cycle: rotations only, 24 frames, treadmill ----------
act = bpy.data.actions.new("Walk"); rig.animation_data_create(); rig.animation_data.action = act
for p_ in rig.pose.bones: p_.rotation_mode = "QUATERNION"
def rot(name, axis_world, deg):
    ax = rig.data.bones[name].matrix_local.to_3x3().inverted() @ axis_world
    rig.pose.bones[name].rotation_quaternion = Quaternion(ax.normalized(), math.radians(deg))
F = 24; scene.frame_start, scene.frame_end = 1, F; scene.render.fps = 24
PH = {"F_L": 0.25, "F_R": 0.75, "H_L": 0.0, "H_R": 0.5}
for f in range(F + 1):
    ph = f / F
    for s in ("L", "R"):
        pf = 2 * math.pi * (ph + PH["F_" + s]); pr = 2 * math.pi * (ph + PH["H_" + s])
        rot("UpperArm" + s, LAT, -22 * math.sin(pf)); rot("LowerArm" + s, LAT, 40 * max(0.0, math.sin(pf + 1.2)))
        rot("FrontPaw" + s, LAT, 28 * max(0.0, math.sin(pf + 1.6)))
        rot("Thigh" + s, LAT, -20 * math.sin(pr)); rot("Shin" + s, LAT, -18 * max(0.0, math.sin(pr + 1.2)))
        rot("Hock" + s, LAT, 28 * max(0.0, math.sin(pr + 1.4))); rot("Ear" + s, LAT, 4 * math.sin(4 * math.pi * ph + 0.5))
        for n in ("UpperArm", "LowerArm", "FrontPaw", "Thigh", "Shin", "Hock", "Ear"):
            rig.pose.bones[n + s].keyframe_insert("rotation_quaternion", frame=f + 1)
    rot("Hips", FWD, 3 * math.sin(2 * math.pi * ph)); rot("Chest", FWD, -3 * math.sin(2 * math.pi * ph))
    rot("Neck", Z, 2 * math.sin(2 * math.pi * ph)); rot("Head", LAT, 3 * math.sin(4 * math.pi * ph))
    for i, n in enumerate(("Tail1", "Tail2", "Tail3")): rot(n, Z, 7 * math.sin(2 * math.pi * ph - 0.6 * i))
    for n in ("Hips", "Chest", "Neck", "Head", "Tail1", "Tail2", "Tail3"):
        rig.pose.bones[n].keyframe_insert("rotation_quaternion", frame=f + 1)

# ---------- 7. showcase renders (Dramatic Showcase Renders note: soft key, rim, Standard view) ----------
world = bpy.data.worlds.new("W"); world.use_nodes = True; bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (1, 1, 1, 1); bg.inputs["Strength"].default_value = 0.75; scene.world = world
def sun(name, e, rx, rz, ang):
    ld = bpy.data.lights.new(name, "SUN"); ld.energy = e; ld.angle = math.radians(ang)
    o = bpy.data.objects.new(name, ld); o.rotation_euler = (math.radians(rx), 0, math.radians(rz)); scene.collection.objects.link(o)
sun("Key", 2.0, 45, -50, 6); sun("Rim", 1.0, 60, 130, 3)
gd = bpy.data.meshes.new("Ground"); gbm = bmesh.new(); bmesh.ops.create_circle(gbm, cap_ends=True, radius=40, segments=64); gbm.to_mesh(gd); gbm.free()
ground = bpy.data.objects.new("Ground", gd); scene.collection.objects.link(ground)
gm = bpy.data.materials.new("G"); gm.use_nodes = True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.86, 0.86, 0.88, 1)
gd.materials.append(gm)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
def shot(fname, loc, tgt, ortho=None, res=(1100, 900), frame=1):
    scene.frame_set(frame); scene.render.resolution_x, scene.render.resolution_y = res
    cd.type = "ORTHO" if ortho else "PERSP"
    if ortho: cd.ortho_scale = ortho * S
    else: cd.lens = 55
    loc, tgt = T(loc), T(tgt)
    cam.location = loc; cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
rig.animation_data.action = None
for p_ in rig.pose.bones: p_.rotation_quaternion = (1, 0, 0, 0)
shot("wolf3_side.png", (-0.02, -6, 0.70), (-0.02, 0, 0.70), ortho=1.9)
shot("wolf3_back.png", (-6, 0, 0.70), (0, 0, 0.70), ortho=1.6, res=(700, 900))
shot("wolf3_front.png", (6, 0, 0.70), (0, 0, 0.70), ortho=1.6, res=(700, 900))
shot("wolf3_hero.png", (2.0, -2.4, 1.15), (-0.02, 0, 0.62), res=(1200, 900))
rig.animation_data.action = act
os.makedirs(os.path.join(OUT, "walk3"), exist_ok=True)
for f in range(1, F + 1, 2):
    shot(os.path.join("walk3", f"w{f:02d}.png"), (1.6, -2.6, 1.0), (-0.02, 0, 0.6), res=(640, 520), frame=f)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Wolf_v3.blend"))
bpy.ops.object.select_all(action="DESELECT"); wolf.select_set(True); rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "Wolf.glb"), export_format="GLB", use_selection=True, export_yup=True,
                          export_animations=True)
print("DONE")
