"""Void Owl v4, built the vault's way.

Brief (Art Pipeline - Concept to In-Game Asset, stage 1):
  boss, faceted low-poly (Low-Poly and Stylized Modeling), triangles/spikes shape language,
  one exaggerated feature = huge raised wings + talons, eyes are the brightest pixels,
  budget 10-15k tris, every mesh under 20k, modelled at final stud size facing -Y, Left = +X.
Build (Organic and Creature Modeling): box-modelled body+head as ONE faceted mass, ear tufts
  extruded from the head; wings as layered tier plates with blocky feather tabs (skinned along the
  wing bones); talons/beak rigid. Rig: the vault's Bird_Winged bone names (Skeleton Library).
Glow markings: painted masks (texture), not geometry.
Run: blender -b --factory-startup --python build_void_owl_v4.py
"""
import bpy, bmesh, math, random, os
import numpy as np
from mathutils import Vector, Matrix, Euler

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
random.seed(3)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# =====================================================================
# Palette and materials
# =====================================================================
GLOW_RGB = (1.0, 0.08, 0.8)
def mat(name, rgb, rough=0.6, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1); b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*rgb, 1)
    return m

TEX = 1024
UU, VV = np.meshgrid(np.linspace(0, 1, TEX), np.linspace(0, 1, TEX))
def save_mask(name, mask):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    img.pixels.foreach_set(np.dstack([mask, mask, mask, np.ones_like(mask)]).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png"); img.file_format = "PNG"; img.save()
    img.colorspace_settings.name = "Non-Color"
    return img
def crescent(cu, cv, r, w, a0, a1, su=1.0, sv=1.0):
    du = (UU - cu) / su; dv = (VV - cv) / sv
    d = np.sqrt(du * du + dv * dv); ang = np.arctan2(dv, du)
    mid = (a0 + a1) / 2; half = (a1 - a0) / 2
    t = np.clip(1 - np.abs((ang - mid + math.pi) % math.tau - math.pi) / half, 0, 1)
    return np.clip((w * np.sqrt(t) - np.abs(d - r)) / 0.003, 0, 1) * (t > 0)
def line(u0, v0, u1, v1, w, su=1.0, sv=1.0):
    pu = (UU - u0) / su; pv = (VV - v0) / sv; du = (u1 - u0) / su; dv = (v1 - v0) / sv
    L2 = du * du + dv * dv; t = np.clip((pu * du + pv * dv) / L2, 0, 1)
    dist = np.sqrt((pu - t * du) ** 2 + (pv - t * dv) ** 2)
    width = w * (0.55 + 0.45 * t)
    return np.clip((width - dist) / 0.003, 0, 1)

def marked_mat(name, rgb, mask_img, strength=7.0, front_only=False):
    """Base colour with a painted glow mask. front_only limits the mask to faces looking along -Y."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.6
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = mask_img
    fac = tex.outputs["Color"]
    if front_only:
        geo = nt.nodes.new("ShaderNodeNewGeometry"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = -0.15; mr.inputs["From Max"].default_value = -0.45
        mul0 = nt.nodes.new("ShaderNodeMath"); mul0.operation = "MULTIPLY"
        nt.links.new(geo.outputs["Normal"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
        nt.links.new(tex.outputs["Color"], mul0.inputs[0]); nt.links.new(mr.outputs["Result"], mul0.inputs[1])
        fac = mul0.outputs[0]
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    mix.inputs[6].default_value = (*rgb, 1); mix.inputs[7].default_value = (*GLOW_RGB, 1)
    nt.links.new(fac, mix.inputs[0]); nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = strength
    nt.links.new(fac, mul.inputs[0]); nt.links.new(mul.outputs[0], b.inputs["Emission Strength"])
    b.inputs["Emission Color"].default_value = (*GLOW_RGB, 1)
    m.diffuse_color = (*rgb, 1)
    return m

HORN = mat("Void_Horn", (1.0, 0.14, 0.8), 0.3, emit=1.4)
EYE = mat("Void_Eye", (1.0, 0.8, 1.0), 0.2, emit=3.5)
EYE_RIM = mat("Void_EyeRim", GLOW_RGB, 0.3, emit=6)
BLACK = mat("Void_Black", (0.02, 0.018, 0.026), 0.4)
VIOLET = (0.26, 0.035, 0.75); VIOLET_HI = (0.4, 0.08, 0.98); VIOLET_LO = (0.15, 0.018, 0.48)

# =====================================================================
# Skeleton: vault Bird_Winged bone names, placed at the owl's joints (Left = +X)
# =====================================================================
S = {}
def bone(name, head, tail, parent=None): S[name] = (Vector(head), Vector(tail), parent)
bone("RootPart", (0, 0, 5.5), (0, -1.5, 5.5))
bone("Body", (0, 0.4, 2.0), (0, 0.0, 7.4), "RootPart")
bone("Neck", (0, 0.0, 7.4), (0, -0.2, 8.6), "Body")
bone("Head", (0, -0.2, 8.6), (0, -0.3, 12.0), "Neck")
bone("Beak", (0, -2.4, 10.1), (0, -3.4, 8.4), "Head")
bone("Tail1", (0, 2.2, 3.4), (0, 3.4, 1.8), "Body")
bone("Tail2", (0, 3.4, 1.8), (0, 4.4, 0.4), "Tail1")
WING = {}
for side, sx in (("Left", 1), ("Right", -1)):
    pts = [Vector((sx * 3.4, 0.4, 8.0)), Vector((sx * 7.0, 0.9, 11.2)), Vector((sx * 10.6, 1.4, 13.4)), Vector((sx * 13.6, 1.8, 15.8))]
    WING[side] = pts
    bone(f"{side}Wing1", pts[0], pts[1], "Body"); bone(f"{side}Wing2", pts[1], pts[2], f"{side}Wing1"); bone(f"{side}Wing3", pts[2], pts[3], f"{side}Wing2")
    hip = (sx * 1.6, -0.9, 3.0); knee = (sx * 1.8, -2.0, 1.8); ankle = (sx * 2.0, -3.2, 0.8)
    bone(f"{side}UpperLeg", hip, knee, "Body"); bone(f"{side}LowerLeg", knee, ankle, f"{side}UpperLeg")
    bone(f"{side}Foot", ankle, (sx * 2.0, -4.6, 0.5), f"{side}LowerLeg")

OBJS = []   # (object) each carries its own vertex groups
def finish(name, bm, materials, weights):
    """weights: list per vertex of {bone: w}. Builds an object with vertex groups."""
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in materials: me.materials.append(m)
    ob = bpy.data.objects.new(name, me); scene.collection.objects.link(ob)
    groups = {}
    for vi, wd in enumerate(weights):
        for bn, w in wd.items():
            if w <= 0: continue
            g = groups.get(bn) or ob.vertex_groups.new(name=bn); groups[bn] = g
            g.add([vi], w, "REPLACE")
    OBJS.append(ob); return ob

def frame(d, up=Vector((0, -1, 0))):
    d = d.normalized(); s = d.cross(up)
    if s.length < 1e-3: s = d.cross(Vector((0, 0, 1)))
    s.normalize(); return d, s, s.cross(d).normalized()

# =====================================================================
# 1. Body + head: one box-modelled faceted mass
# =====================================================================
def lerp_profile(z, ks, vs):
    if z <= ks[0]: return vs[0]
    for i in range(len(ks) - 1):
        if z <= ks[i + 1]:
            f = (z - ks[i]) / (ks[i + 1] - ks[i]); f = f * f * (3 - 2 * f)
            return vs[i] + (vs[i + 1] - vs[i]) * f
    return vs[-1]
ZK = [1.2, 2.6, 4.6, 6.6, 7.6, 8.6, 10.2, 11.7, 12.5]
WK = [1.6, 3.2, 4.0, 3.7, 3.3, 3.7, 4.0, 3.5, 2.3]       # half width
DK = [1.4, 2.9, 3.3, 3.0, 2.7, 2.8, 3.0, 2.6, 1.6]       # half depth
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=2.0)
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
for v in bm.verts:
    p = v.co.normalized()
    Z = ZK[0] + (p.z + 1) / 2 * (ZK[-1] - ZK[0])
    rh = math.hypot(p.x, p.y)
    if rh < 1e-4: v.co = Vector((0, 0, Z)); continue
    ux, uy = p.x / rh, p.y / rh
    roundness = math.sqrt(max(0.0, 1 - abs(p.z) ** 6))         # soften the very top and bottom
    X = ux * lerp_profile(Z, ZK, WK) * roundness
    Y = uy * lerp_profile(Z, ZK, DK) * roundness
    if Y < 0 and Z > 8.8: Y *= 0.82                              # flat facial disc
    if 2.5 < Z < 7.0: Y -= 0.45 * math.sin((Z - 2.5) / 4.5 * math.pi) * max(0, -uy)   # chest pushes forward
    v.co = Vector((X, Y + 0.2, Z)) + Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.07
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts[:], edges=bm.edges[:])   # merge into bigger facets
bmesh.ops.triangulate(bm, faces=bm.faces[:])
# ear tufts: extruded out of the head, three steps up and out, ending in a point (material 1 = horn)
for sx in (1, -1):
    target = Vector((sx * 2.0, -1.0, 12.0))
    cand = [f for f in bm.faces if f.normal.z > 0.2 and f.material_index == 0]
    f = min(cand, key=lambda f: (f.calc_center_median() - target).length)
    geom = [f]
    for step, (dz, out, back, sc) in enumerate(((1.2, 0.35, 0.15, 0.85), (1.7, 0.55, 0.35, 0.7), (1.8, 0.65, 0.5, 0.05))):
        res = bmesh.ops.extrude_face_region(bm, geom=geom)
        nv = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        nf = [e for e in res["geom"] if isinstance(e, bmesh.types.BMFace)]
        c = sum((v.co for v in nv), Vector()) / len(nv)
        for v in nv: v.co = c + (v.co - c) * sc + Vector((sx * out, back, dz))
        for ff in nf: ff.material_index = 1
        for e in res["geom"]:
            if isinstance(e, bmesh.types.BMFace): pass
        # side walls of the extrusion are horn too
        for v in nv:
            for ff in v.link_faces: ff.material_index = 1
        geom = nf
    bmesh.ops.delete(bm, geom=[], context="VERTS")
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
# front-projected UVs for the painted face/chest marks
FRONT = (-3.8, 3.8, 0.0, 13.0)
uvl = bm.loops.layers.uv.verify()
for f in bm.faces:
    for lp in f.loops:
        lp[uvl].uv = ((lp.vert.co.x - FRONT[0]) / (FRONT[1] - FRONT[0]), (lp.vert.co.z - FRONT[2]) / (FRONT[3] - FRONT[2]))
def body_weights(v):
    z = v.co.z
    if z > 11.8: return {"Head": 1.0}
    h = min(1, max(0, (z - 7.6) / 1.2)); n = 1 - abs((z - 7.9) / 0.9) if 7.0 < z < 8.8 else 0
    w = {"Body": max(0, 1 - min(1, max(0, (z - 6.8) / 1.0))), "Neck": max(0, n), "Head": h}
    tot = sum(w.values()) or 1
    return {k: x / tot for k, x in w.items()}
weights = [body_weights(v) for v in bm.verts]

su, sv = 1 / (FRONT[1] - FRONT[0]), 1 / (FRONT[3] - FRONT[2])
def U(x): return (x - FRONT[0]) * su
def Vz(z): return (z - FRONT[2]) * sv
fm = np.zeros((TEX, TEX))
for row in range(7):                                      # chest: U scales in a V-shaped field
    z = 7.0 - row * 0.62; cnt = 6 if row % 2 == 0 else 5
    for c in range(cnt):
        x = (c - (cnt - 1) / 2) * 0.74
        if abs(x) > 2.3 - 0.2 * row: continue
        fm = np.maximum(fm, crescent(U(x), Vz(z), 0.28, 0.06, math.radians(-165), math.radians(-15), su, sv))
for sx in (1, -1):
    for k in range(3):                                    # cheek marks under the eyes
        x = sx * (0.9 + 0.5 * k); z = 9.05 - 0.15 * k
        fm = np.maximum(fm, crescent(U(x), Vz(z), 0.22, 0.055, math.radians(-165), math.radians(-15), su, sv))
    # glowing brow lines running from above the beak up into the tufts
    fm = np.maximum(fm, line(U(sx * 0.25), Vz(10.8), U(sx * 1.7), Vz(11.4), 0.24, su, sv))
    fm = np.maximum(fm, line(U(sx * 1.7), Vz(11.4), U(sx * 2.3), Vz(12.3), 0.24, su, sv))
BODY_MAT = marked_mat("Void_Body", VIOLET, save_mask("void4_body_marks", fm), front_only=True)
finish("Owl_Body", bm, [BODY_MAT, HORN], weights)

# eyes: glowing rim + white-hot disc seated in the facial disc; beak: black hook (rigid)
def disc(bm, c, r, n, sides=10, depth=0.3):
    _, s, u = frame(n, Vector((0, 0, 1)))
    rf = [bm.verts.new(c + (s * math.cos(a) + u * math.sin(a)) * r) for a in (k / sides * math.tau for k in range(sides))]
    rb = [bm.verts.new(v.co - n * depth) for v in rf]; ctr = bm.verts.new(c + n * 0.05)
    for k in range(sides):
        bm.faces.new((rf[k], rf[(k + 1) % sides], ctr)); bm.faces.new((rb[(k + 1) % sides], rb[k], rf[k], rf[(k + 1) % sides]))
for nm, m, r, dy in (("Owl_EyeRims", EYE_RIM, 1.05, 0.0), ("Owl_Eyes", EYE, 0.74, -0.12)):
    bm = bmesh.new()
    for sx in (1, -1): disc(bm, Vector((sx * 1.5, -2.5 + dy, 10.15)), r, Vector((sx * 0.3, -1, 0.05)).normalized())
    finish(nm, bm, [m], [{"Head": 1.0}] * len(bm.verts) if False else None) if False else None
    me_bm = bm
    n = len(me_bm.verts); finish(nm, me_bm, [m], [{"Head": 1.0}] * n)

def spike(bm, base, d, length, radius, sides=4, up=Vector((0, -1, 0)), bend=None, segs=3):
    d0 = d.normalized(); pts = [base]
    for i in range(1, segs + 1): pts.append(pts[-1] + (d0 + (bend or Vector()) * (i / segs)).normalized() * length / segs)
    rings = []
    for i, p in enumerate(pts[:-1]):
        _, s, n = frame(pts[i + 1] - p, up); r = radius * (1 - i / segs) ** 0.8
        rings.append([bm.verts.new(p + (s * math.cos(a) + n * math.sin(a)) * r) for a in (k / sides * math.tau for k in range(sides))])
    tip = bm.verts.new(pts[-1]); bm.faces.new(list(reversed(rings[0])))
    for a, b in zip(rings, rings[1:]):
        for k in range(sides): bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    for k in range(sides): bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
bm = bmesh.new()
spike(bm, Vector((0, -2.2, 10.3)), Vector((0, -1.0, -0.25)), 2.9, 1.0, sides=4, up=Vector((1, 0, 0)), bend=Vector((0, 1.1, -2.4)), segs=4)
finish("Owl_Beak", bm, [BLACK], [{"Beak": 1.0}] * len(bm.verts))

# =====================================================================
# 2. Wings: three layered tier plates with blocky feather tabs, painted marks
# =====================================================================
def wing_param(pts):
    lens = [(pts[i + 1] - pts[i]).length for i in range(3)]; tot = sum(lens)
    def at(t):
        d = t * tot
        for i in range(3):
            if d <= lens[i] or i == 2:
                f = min(1.0, d / lens[i]); return pts[i].lerp(pts[i + 1], f), i, f
            d -= lens[i]
    return at, tot
def wing_weights(seg, f, side):
    names = [f"{side}Wing1", f"{side}Wing2", f"{side}Wing3"]
    w = {names[seg]: 1.0}
    if f < 0.15 and seg > 0: a = 0.5 + f / 0.3; w = {names[seg]: a, names[seg - 1]: 1 - a}
    elif f > 0.85 and seg < 2: a = 0.5 + (1 - f) / 0.3; w = {names[seg]: a, names[seg + 1]: 1 - a}
    return w
UVS = 20.0
TIERS = [  # name, feathers, depth(t), y offset, colour
    ("Primaries", 10, lambda t: 6.2 + 4.2 * t, 0.5, VIOLET_LO),
    ("Secondaries", 8, lambda t: 4.2 + 2.3 * t, 0.0, VIOLET),
    ("Coverts", 7, lambda t: 2.3 + 1.1 * t, -0.5, VIOLET_HI),
]
def fdir(t, sx):
    a = math.radians(-96 + 128 * t ** 1.08)
    return Vector((sx * math.cos(a), 0.05, math.sin(a))).normalized()
masks = {}
for ti, (tname, N, D, yoff, rgb) in enumerate(TIERS):
    m = np.zeros((TEX, TEX))
    prevD = TIERS[ti + 1][2] if ti + 1 < len(TIERS) else (lambda t: 0.0)
    at, tot = wing_param(WING["Left"])
    for j in range(N):
        tc = (j + 0.5) / N; u = tc * tot
        lo, hi = prevD(tc), D(tc) * 0.88
        rows = 2 if ti == 0 else 1
        for r in range(rows):
            dep = lo + (hi - lo) * ((r + 1) / (rows + 1) if ti < 2 else 0.5)
            m = np.maximum(m, crescent(u / UVS, dep / UVS, 0.5 / UVS, 0.13 / UVS, math.radians(20), math.radians(160)))
    masks[tname] = marked_mat(f"Void_{tname}", rgb, save_mask(f"void4_{tname.lower()}_marks", m))
for side, sx in (("Left", 1), ("Right", -1)):
    at, tot = wing_param(WING[side])
    for ti, (tname, N, D, yoff, rgb) in enumerate(TIERS):
        bm = bmesh.new(); uvl = bm.loops.layers.uv.verify(); weights = []
        for j in range(N):
            t0, t1 = j / N, (j + 1) / N; tm = t0 + 0.62 * (t1 - t0)
            P0, s0, f0 = at(t0); P1, s1, f1 = at(t1)
            outline = [  # (point, t, depth)
                (P0, t0, 0.0), (P1, t1, 0.0),
                (P1 + fdir(t1, sx) * D(t1) * 0.8, t1, D(t1) * 0.8),
                (at(tm)[0] + fdir(tm, sx) * D(tm), tm, D(tm)),
                (P0 + fdir(t0, sx) * D(t0), t0, D(t0)),
            ]
            th = 0.5; off = Vector((0, yoff, 0))
            front = [bm.verts.new(p + off - Vector((0, th / 2, 0))) for p, _, _ in outline]
            back = [bm.verts.new(p + off + Vector((0, th / 2, 0))) for p, _, _ in outline]
            uvs = {}
            for (p, t, dep), a, b in zip(outline, front, back):
                uvs[a] = uvs[b] = (t * tot / UVS, dep / UVS)
                _, seg, f = at(t); w = wing_weights(seg, f, side)
            faces = [bm.faces.new(front if sx > 0 else list(reversed(front))), bm.faces.new(list(reversed(back)) if sx > 0 else back)]
            for k in range(5):
                k2 = (k + 1) % 5; faces.append(bm.faces.new((front[k], front[k2], back[k2], back[k])))
            for f in faces:
                for lp in f.loops: lp[uvl].uv = uvs[lp.vert]
        bm.verts.index_update()
        # weights from each vertex's position along the leading edge
        for v in bm.verts:
            best = min(range(61), key=lambda i: (at(i / 60)[0] - v.co).length if False else 0)
        weights = []
        for v in bm.verts:
            bt = min((i / 120 for i in range(121)), key=lambda t: ((at(t)[0] - v.co) - (at(t)[0] - v.co).project(fdir(t, sx))).length)
            _, seg, f = at(bt); weights.append(wing_weights(seg, f, side))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        finish(f"Owl_{side}{tname}", bm, [masks[tname]], weights)

for side, sx in (("Left", 1), ("Right", -1)):
    pts = WING[side]
    for i in range(3):
        bm = bmesh.new()
        a, b = pts[i], pts[i + 1]
        spike(bm, a - (b - a).normalized() * 0.4, b - a, (b - a).length * (1.15 if i == 2 else 1.25), 0.95 - 0.2 * i, sides=6, segs=1)
        finish(f"Owl_{side}Arm{i + 1}", bm, [masks["Coverts"]], [{f"{side}Wing{i + 1}": 1.0}] * len(bm.verts))

# =====================================================================
# 3. Tail fan, legs and big black talons
# =====================================================================
bm = bmesh.new(); tw = []
for a in (-36, -18, 0, 18, 36):
    r = math.radians(a); base = Vector((0, 2.0, 3.6)); d = Vector((math.sin(r) * 0.7, 0.5, -1.0)).normalized()
    dd, s, n = frame(d, Vector((0, 1, 0.4)))
    pts = [base - s * 0.75, base + s * 0.75, base + d * 4.0 + s * 0.6, base + d * 4.8, base + d * 4.2 - s * 0.6]
    F = [bm.verts.new(p - n * 0.2) for p in pts]; B = [bm.verts.new(p + n * 0.2) for p in pts]
    bm.faces.new(F); bm.faces.new(list(reversed(B)))
    for k in range(5): bm.faces.new((F[k], F[(k + 1) % 5], B[(k + 1) % 5], B[k]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
finish("Owl_Tail", bm, [masks["Primaries"]], [{"Tail1": 1.0}] * len(bm.verts))

def ico(bm, c, radii, jitter=0.06):
    res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    for v in res["verts"]:
        v.co *= 1 + random.uniform(-jitter, jitter); v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + c
    return res["verts"]
for side, sx in (("Left", 1), ("Right", -1)):
    hip, knee, _ = S[f"{side}UpperLeg"]; _, ankle, _ = S[f"{side}LowerLeg"]
    bm = bmesh.new(); ico(bm, hip + Vector((0, -0.2, -0.2)), (1.6, 1.5, 1.7))
    finish(f"Owl_{side}Thigh", bm, [BODY_MAT], [{f"{side}UpperLeg": 1.0}] * len(bm.verts))
    bm = bmesh.new(); spike(bm, knee, ankle - knee, (ankle - knee).length + 0.3, 0.6, sides=5, segs=1)
    finish(f"Owl_{side}Shin", bm, [BLACK], [{f"{side}LowerLeg": 1.0}] * len(bm.verts))
    bm = bmesh.new(); ico(bm, ankle, (0.95, 0.9, 0.7))
    for tx, ty in ((-0.75, -1.0), (0.0, -1.15), (0.75, -1.0), (0.0, 1.0)):
        fw = Vector((tx * sx, ty, -0.15)).normalized()
        spike(bm, ankle, fw, 1.9, 0.55, sides=5, up=Vector((0, 0, 1)), segs=1)
        tip = ankle + fw * 1.6
        spike(bm, tip, fw + Vector((0, 0, 0.5)), 2.6, 0.5, sides=5, up=Vector((0, 0, 1)), bend=Vector((0, 0, -3.2)), segs=4)
    finish(f"Owl_{side}Talons", bm, [BLACK], [{f"{side}Foot": 1.0}] * len(bm.verts))

# =====================================================================
# Join, armature, checks
# =====================================================================
bpy.ops.object.select_all(action="DESELECT")
for o in OBJS:
    o.select_set(True)
    for p in o.data.polygons: p.use_smooth = False
bpy.context.view_layer.objects.active = OBJS[0]; bpy.ops.object.join()
owl = bpy.context.active_object; owl.name = "VoidOwl"
arm = bpy.data.armatures.new("VoidOwlRig"); rig = bpy.data.objects.new("VoidOwlRig", arm); scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (h, t, _) in S.items():
    b = arm.edit_bones.new(name); b.head = h; b.tail = t; eb[name] = b
for name, (_, _, par) in S.items():
    if par: eb[name].parent = eb[par]
bpy.ops.object.mode_set(mode="OBJECT")
owl.parent = rig; owl.modifiers.new("Armature", "ARMATURE").object = rig
rig.hide_render = True
tris = sum(len(p.vertices) - 2 for p in owl.data.polygons)
unweighted = sum(1 for v in owl.data.vertices if not v.groups)
print("BONES", len(arm.bones), "TRIS", tris, "UNWEIGHTED", unweighted, "GROUPS", sorted(g.name for g in owl.vertex_groups))

# =====================================================================
# Renders: front + three-quarter (look), black silhouette (vault readability test)
# =====================================================================
world = bpy.data.worlds.new("W"); world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.03, 0.08, 1); scene.world = world
def light(name, loc, rot, energy, col, size=16):
    l = bpy.data.lights.new(name, "AREA"); l.energy = energy; l.color = col; l.size = size
    o = bpy.data.objects.new("Preview" + name, l); scene.collection.objects.link(o); o.location = loc; o.rotation_euler = rot
light("Key", (-14, -24, 26), (math.radians(42), 0, math.radians(-30)), 7000, (0.9, 0.9, 1.0))
light("Moon", (8, 22, 22), (math.radians(-50), 0, math.radians(165)), 9000, (0.55, 0.7, 1.0))
light("Fill", (18, -14, 6), (math.radians(78), 0, math.radians(52)), 1500, (0.6, 0.5, 1.0))
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("PreviewCam", cd); scene.collection.objects.link(cam); scene.camera = cam
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 1600; scene.render.resolution_y = 1200
scene.view_settings.view_transform = "Standard"
try:
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree"); scene.compositing_node_group = ng
    rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor"); go = ng.nodes.new("NodeGroupOutput")
    for nm, val in (("Type", "Bloom"), ("Threshold", 0.9), ("Strength", 0.75), ("Size", 0.65), ("Quality", "High")):
        if nm in gl.inputs:
            try: gl.inputs[nm].default_value = val
            except Exception: pass
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], go.inputs[0])
except Exception as e:
    print("glare skipped", e)
def shot(fname, loc, tgt, lens):
    cam.location = loc; cd.lens = lens
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
shot("void_owl_v4_front.png", (0, -50, 9), (0, 0, 9.5), 40)
shot("void_owl_v4_34.png", (-26, -34, 6), (0, 0, 9.5), 36)
shot("void_owl_v4_side.png", (-46, -6, 8), (0, 0, 8.5), 40)
# silhouette test: flat black on white (workbench)
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading; sh.light = "FLAT"; sh.color_type = "SINGLE"; sh.single_color = (0, 0, 0)
sh.background_type = "VIEWPORT"; sh.background_color = (1, 1, 1)
scene.compositing_node_group = None
shot("void_owl_v4_silhouette.png", (0, -50, 9), (0, 0, 9.5), 40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "VoidOwl_v4.blend"))
print("DONE")
