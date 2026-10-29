"""Cosmic sword: long sharp double-edged blade of nebula glass with a white-hot edge line, crescent
obsidian/gold guard around a star-core gem with an orbit ring, planet pommel. Staged in deep space with
floating micro rocks, volumetric gas, sparkles and star flares. Sword stands vertical, point down.
Preview render only. Run: blender -b --factory-startup --python build_cosmic_sword.py"""
import bpy, bmesh, math, random, os
import numpy as np
from mathutils import Vector, Matrix, Euler

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
random.seed(42)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# =====================================================================
# Materials
# =====================================================================
def mat(name, rgb, rough=0.4, metal=0.0, emit=0.0, emit_rgb=None, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if emit: b.inputs["Emission Color"].default_value = (*(emit_rgb or rgb), 1); b.inputs["Emission Strength"].default_value = emit
    if coat and "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    m.diffuse_color = (*rgb, 1); return m
OBSIDIAN = mat("Obsidian", (0.02, 0.02, 0.03), 0.18, 0.6, coat=0.8)
GOLD = mat("Gold", (1.0, 0.72, 0.32), 0.22, 1.0)
EDGE = mat("EdgeLight", (0.85, 0.95, 1.0), 0.2, emit=9)
CORE = mat("StarCore", (0.55, 0.9, 1.0), 0.1, emit=14)
SPARK_W = mat("SparkWhite", (1, 1, 1), 0.2, emit=18)
SPARK_C = mat("SparkCyan", (0.4, 0.85, 1.0), 0.2, emit=14)
SPARK_P = mat("SparkPink", (1.0, 0.35, 0.9), 0.2, emit=14)
ROCK = mat("Rock", (0.018, 0.016, 0.024), 0.7)
ROCK_HOT = mat("RockEmber", (0.35, 0.6, 1.0), 0.6, emit=4)

def nebula_mat(name, scale=1.4, strength=3.0, stars=True):
    """Emissive nebula: layered noise drives a purple-pink-cyan ramp; voronoi pinpoint stars on top."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.005, 0.004, 0.012, 1); b.inputs["Roughness"].default_value = 0.08
    if "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = 1.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n1 = nt.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = scale; n1.inputs["Detail"].default_value = 10; n1.inputs["Distortion"].default_value = 1.2
    n2 = nt.nodes.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = scale * 3.5; n2.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"]); nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    mixf = nt.nodes.new("ShaderNodeMath"); mixf.operation = "MULTIPLY"
    nt.links.new(n1.outputs["Fac"], mixf.inputs[0]); nt.links.new(n2.outputs["Fac"], mixf.inputs[1])
    cr = nt.nodes.new("ShaderNodeValToRGB"); el = cr.color_ramp.elements
    el[0].position = 0.12; el[0].color = (0.0, 0.0, 0.0, 1)
    el[1].position = 0.55; el[1].color = (0.3, 0.75, 1.0, 1)
    e2 = el.new(0.28); e2.color = (0.25, 0.02, 0.45, 1)
    e3 = el.new(0.4); e3.color = (0.95, 0.15, 0.7, 1)
    nt.links.new(mixf.outputs[0], cr.inputs["Fac"])
    col = cr.outputs["Color"]
    if stars:
        vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 26
        nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
        st = nt.nodes.new("ShaderNodeMapRange"); st.inputs["From Min"].default_value = 0.06; st.inputs["From Max"].default_value = 0.0
        nt.links.new(vor.outputs["Distance"], st.inputs["Value"])
        pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 3
        nt.links.new(st.outputs["Result"], pw.inputs[0])
        add = nt.nodes.new("ShaderNodeMix"); add.data_type = "RGBA"; add.blend_type = "ADD"; add.inputs[0].default_value = 1.0
        nt.links.new(col, add.inputs[6]); nt.links.new(pw.outputs[0], add.inputs[7])
        col = add.outputs[2]
    nt.links.new(col, b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = strength
    return m
NEBULA = nebula_mat("NebulaGlass", 1.1, 3.2)
PLANET = nebula_mat("PlanetSurface", 3.0, 2.5, stars=False)

def obj(name, bm, mats, smooth=False):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    for p in me.polygons: p.use_smooth = smooth
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o); return o
def bez(p0, p1, p2, n=16): return [p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t for t in (i / n for i in range(n + 1))]
def slab_outline(bm, pts2d, thick, bevel=0.0, plane="XZ"):
    vs = [bm.verts.new(Vector((x, -thick / 2, z))) for x, z in pts2d]
    try: f = bm.faces.new(vs)
    except ValueError: return
    res = bmesh.ops.extrude_face_region(bm, geom=[f]); nv = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in nv: v.co.y += thick
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bevel: bmesh.ops.bevel(bm, geom=list({e for v in vs + nv for e in v.link_edges}), offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
def outline_from_center(center, w0, w1=0.0, power=0.8):
    n = len(center); left, right = [], []
    for i, p in enumerate(center):
        d = (center[min(i + 1, n - 1)] - center[max(i - 1, 0)]).normalized(); nrm = Vector((-d.y, d.x))
        t = i / (n - 1); w = w1 + (w0 - w1) * (1 - t) ** power
        left.append(p + nrm * w / 2); right.append(p - nrm * w / 2)
    return [(p.x, p.y) for p in left] + [(p.x, p.y) for p in reversed(right[1:-1])]

# =====================================================================
# Blade (vertical, point down along -Z; flat faces toward +-Y)
# material 0 = nebula glass flat, 1 = white-hot edge bevel, 2 = obsidian ricasso
# =====================================================================
L = 10.0; N = 80
def half_w(s):                       # s = 0 at the guard, 1 at the point
    w = 0.52 - 0.08 * s + 0.06 * math.sin(s * math.pi * 0.9)        # slight leaf swell
    return w * (1 - max(0.0, (s - 0.72) / 0.28) ** 1.6) + 0.0
bm = bmesh.new(); rows = []
for i in range(N + 1):
    s = i / N; z = -0.35 - s * L; w = max(half_w(s), 0.0); th = 0.11 * (1 - 0.7 * s) + 0.004
    be = min(0.09, w * 0.3)
    ring = [(-w, 0, z), (-(w - be), -th * 0.55, z), (0, -th, z), ((w - be), -th * 0.55, z), (w, 0, z), ((w - be), th * 0.55, z), (0, th, z), (-(w - be), th * 0.55, z)]
    rows.append([bm.verts.new(Vector(c)) for c in ring])
tipv = bm.verts.new(Vector((0, 0, -0.35 - L - 0.05)))
EDGE_SEG = {0, 3, 4, 7}
for a, b_ in zip(rows, rows[1:]):
    for k in range(8):
        k2 = (k + 1) % 8; f = bm.faces.new((a[k], a[k2], b_[k2], b_[k])); f.material_index = 1 if k in EDGE_SEG else 0
for k in range(8): bm.faces.new((rows[-1][k], rows[-1][(k + 1) % 8], tipv)).material_index = 1
cap = bm.faces.new(list(reversed(rows[0]))); cap.material_index = 2
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
obj("Blade", bm, [NEBULA, EDGE, OBSIDIAN])
bm = bmesh.new()                    # energy core running down the ridge, both faces
for side in (-1, 1):
    pts = [Vector((0, side * (0.11 * (1 - 0.7 * s) + 0.012), -0.4 - s * L * 0.82)) for s in (i / 40 for i in range(41))]
    rings = []
    for j, p in enumerate(pts):
        r = 0.028 * (1 - j / 40) + 0.004
        rings.append([bm.verts.new(p + Vector((math.cos(t) * r, side * abs(math.sin(t)) * r * 0.4, 0))) for t in (q / 6 * math.tau for q in range(6))])
    for a, b_ in zip(rings, rings[1:]):
        for q in range(6): bm.faces.new((a[q], a[(q + 1) % 6], b_[(q + 1) % 6], b_[q]))
obj("CoreLine", bm, [CORE], smooth=True)

# =====================================================================
# Guard: crescent wings sweeping up, gold trim, star-core gem in a bezel, orbit ring with moons
# =====================================================================
bm = bmesh.new()
for sx in (-1, 1):
    outer = [Vector((p.x, p.y)) for p in bez(Vector((0.0, -0.1)), Vector((sx * 1.6, -0.45)), Vector((sx * 2.3, 0.85)), 18)]
    slab_outline(bm, outline_from_center(outer, 0.55, 0.0, 0.7), 0.34, bevel=0.06)
    claw = [Vector((p.x, p.y)) for p in bez(Vector((sx * 0.5, -0.25)), Vector((sx * 1.2, -0.9)), Vector((sx * 1.05, -1.45)), 10)]
    slab_outline(bm, outline_from_center(claw, 0.24, 0.0, 0.7), 0.22, bevel=0.03)
obj("GuardWings", bm, [OBSIDIAN])
bm = bmesh.new()
for sx in (-1, 1):                  # gold inlay riding the wing's upper edge
    trim = [Vector((p.x, p.y + 0.12)) for p in bez(Vector((sx * 0.25, 0.0)), Vector((sx * 1.55, -0.3)), Vector((sx * 2.22, 0.82)), 18)]
    pts = outline_from_center(trim, 0.09, 0.0, 0.6)
    vs = [bm.verts.new(Vector((x, -0.24, z))) for x, z in pts]
    try:
        f = bm.faces.new(vs); res = bmesh.ops.extrude_face_region(bm, geom=[f])
        for v in [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]: v.co.y += 0.48
    except ValueError: pass
bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.42, radius2=0.42, depth=0.5,
                      matrix=Matrix.Translation((0, 0, 0.05)) @ Euler((math.radians(90), 0, 0)).to_matrix().to_4x4())
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
obj("GuardGold", bm, [GOLD], smooth=False)
bm = bmesh.new()                    # star-core gem: elongated octahedron facing both sides
gem = [Vector((0, 0, 0.42)), Vector((0, 0, -0.32)), Vector((0.26, 0, 0.05)), Vector((-0.26, 0, 0.05)), Vector((0, 0.34, 0.05)), Vector((0, -0.34, 0.05))]
gv = [bm.verts.new(p) for p in gem]
for a, b_ in ((2, 4), (4, 3), (3, 5), (5, 2)):
    bm.faces.new((gv[0], gv[a], gv[b_])); bm.faces.new((gv[1], gv[b_], gv[a]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
obj("StarGem", bm, [CORE])
bm = bmesh.new()                    # orbit ring + two tiny moons
res = bmesh.ops.create_circle(bm, cap_ends=False, segments=96, radius=1.35)
ring_pts = [v.co.copy() for v in res["verts"]]; bmesh.ops.delete(bm, geom=res["verts"], context="VERTS")
rings = []
for p in ring_pts:
    d = p.normalized(); rings.append([bm.verts.new(p + d * math.cos(t) * 0.035 + Vector((0, 0, math.sin(t) * 0.035))) for t in (q / 6 * math.tau for q in range(6))])
for a, b_ in zip(rings, rings[1:] + rings[:1]):
    for q in range(6): bm.faces.new((a[q], a[(q + 1) % 6], b_[(q + 1) % 6], b_[q]))
ringobj = obj("OrbitRing", bm, [GOLD], smooth=True); ringobj.rotation_euler = (math.radians(72), math.radians(18), 0); ringobj.location = (0, 0, 0.05)
for k, (ang, r) in enumerate(((0.6, 0.11), (3.4, 0.08))):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
    mo = obj(f"Moon{k}", bm, [PLANET if k == 0 else SPARK_C], smooth=True)
    mo.parent = ringobj; mo.location = (math.cos(ang) * 1.35, math.sin(ang) * 1.35, 0)

# =====================================================================
# Grip and pommel planet
# =====================================================================
bm = bmesh.new(); SEG, RINGS = 32, 120; z0, z1 = 0.35, 2.65; rows = []
for i in range(RINGS + 1):
    z = z0 + (z1 - z0) * i / RINGS; row = []
    for j in range(SEG):
        th = j / SEG * math.tau; phase = (th / math.tau + (z - z0) * 3.0) % 1.0
        r = 0.16 + 0.018 * (1 - abs(2 * phase - 1)) ** 0.35 + 0.01 * math.sin((z - z0) / (z1 - z0) * math.pi)
        row.append(bm.verts.new(Vector((math.cos(th) * r, math.sin(th) * r, z))))
    rows.append(row)
for a, b_ in zip(rows, rows[1:]):
    for j in range(SEG): bm.faces.new((a[j], a[(j + 1) % SEG], b_[(j + 1) % SEG], b_[j]))
obj("Grip", bm, [OBSIDIAN], smooth=True)
bm = bmesh.new()
pts = [Vector((math.cos(t * 3.0 * math.tau + 0.5) * 0.185, math.sin(t * 3.0 * math.tau + 0.5) * 0.185, z0 + t * (z1 - z0))) for t in (i / 300 for i in range(301))]
rings = []
for p in pts:
    rings.append([bm.verts.new(p + Vector((0, 0, math.cos(q) * 0.012)) + Vector((p.x, p.y, 0)).normalized() * math.sin(q) * 0.012) for q in (k / 5 * math.tau for k in range(5))])
for a, b_ in zip(rings, rings[1:]):
    for q in range(5): bm.faces.new((a[q], a[(q + 1) % 5], b_[(q + 1) % 5], b_[q]))
for zc, r in ((0.32, 0.22), (2.7, 0.21)):
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=r, radius2=r * 0.92, depth=0.12, matrix=Matrix.Translation((0, 0, zc)))
obj("GripGold", bm, [GOLD], smooth=True)
bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=0.38, matrix=Matrix.Translation((0, 0, 3.12)))
obj("PommelPlanet", bm, [PLANET], smooth=True)
bm = bmesh.new()
res = bmesh.ops.create_circle(bm, cap_ends=False, segments=64, radius=0.62)
inner = bmesh.ops.create_circle(bm, cap_ends=False, segments=64, radius=0.47)
ov, iv = res["verts"], inner["verts"]
for k in range(64): bm.faces.new((ov[k], ov[(k + 1) % 64], iv[(k + 1) % 64], iv[k]))
pr = obj("PommelRing", bm, [GOLD], smooth=True); pr.location = (0, 0, 3.12); pr.rotation_euler = (math.radians(70), math.radians(-20), 0)

sword_parts = [o for o in scene.objects if o.type == "MESH"]
tris = 0
for o in sword_parts: o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
print("SWORD TRIS", tris)

# =====================================================================
# Space stage: micro rocks, gas, sparkles, star flares
# =====================================================================
def rock(bm, c, r):
    res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    sq = Vector((random.uniform(0.6, 1.0), random.uniform(0.6, 1.0), random.uniform(0.5, 0.9)))
    ph = [random.uniform(0, 6) for _ in range(3)]
    for v in res["verts"]:
        n = v.co.normalized()
        bump = 1 + 0.22 * math.sin(n.x * 5 + ph[0]) * math.cos(n.y * 4 + ph[1]) + 0.12 * math.sin(n.z * 9 + ph[2])
        v.co = Vector((v.co.x * sq.x, v.co.y * sq.y, v.co.z * sq.z)) * bump + Vector(c)
rock_bm = bmesh.new(); hot_bm = bmesh.new()
for i in range(140):
    t = random.random(); ang = t * math.tau * 3.2 + random.uniform(-0.4, 0.4)
    z = 3.0 - t * 13.0 + random.uniform(-0.5, 0.5); rad = max(1.1, random.uniform(1.0, 3.6) * (0.6 + 0.6 * random.random()))
    c = (math.cos(ang) * rad, math.sin(ang) * rad * 0.7 + random.uniform(-0.4, 0.4), z)
    rock(hot_bm if i % 9 == 0 else rock_bm, c, random.uniform(0.03, 0.17) * (1.6 if i % 17 == 0 else 1))
obj("MicroRocks", rock_bm, [ROCK]); obj("EmberRocks", hot_bm, [ROCK_HOT])
spark = {k: bmesh.new() for k in ("w", "c", "p")}
for i in range(420):
    ang = random.uniform(0, math.tau); rad = abs(random.gauss(0, 1.6)) + 0.25
    c = Vector((math.cos(ang) * rad, math.sin(ang) * rad * 0.8, random.uniform(-10.5, 3.6)))
    k = random.choice("wwcp"); bmesh.ops.create_icosphere(spark[k], subdivisions=1, radius=random.uniform(0.006, 0.022), matrix=Matrix.Translation(c))
obj("SparksWhite", spark["w"], [SPARK_W]); obj("SparksCyan", spark["c"], [SPARK_C]); obj("SparksPink", spark["p"], [SPARK_P])

# volumetric gas: a box of noisy emissive fog that thins away from the blade
gas = bpy.data.materials.new("Gas"); gas.use_nodes = True; nt = gas.node_tree; nt.nodes.clear()
outn = nt.nodes.new("ShaderNodeOutputMaterial"); vol = nt.nodes.new("ShaderNodeVolumePrincipled")
tc = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.9; nz.inputs["Detail"].default_value = 8; nz.inputs["Distortion"].default_value = 0.8
nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
cr = nt.nodes.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].position = 0.52; cr.color_ramp.elements[1].position = 0.8
nt.links.new(nz.outputs["Fac"], cr.inputs["Fac"])
sepx = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sepx.inputs[0])
lx = nt.nodes.new("ShaderNodeVectorMath"); lx.operation = "LENGTH"
cmb = nt.nodes.new("ShaderNodeCombineXYZ"); nt.links.new(sepx.outputs["X"], cmb.inputs["X"]); nt.links.new(sepx.outputs["Y"], cmb.inputs["Y"])
nt.links.new(cmb.outputs[0], lx.inputs[0])
fall = nt.nodes.new("ShaderNodeMapRange"); fall.inputs["From Min"].default_value = 1.2; fall.inputs["From Max"].default_value = 8.0
fall.inputs["To Min"].default_value = 1.0; fall.inputs["To Max"].default_value = 0.0
nt.links.new(lx.outputs["Value"], fall.inputs["Value"])
dens = nt.nodes.new("ShaderNodeMath"); dens.operation = "MULTIPLY"
nt.links.new(cr.outputs["Color"], dens.inputs[0]); nt.links.new(fall.outputs["Result"], dens.inputs[1])
d2 = nt.nodes.new("ShaderNodeMath"); d2.operation = "MULTIPLY"; d2.inputs[1].default_value = 0.16
nt.links.new(dens.outputs[0], d2.inputs[0]); nt.links.new(d2.outputs[0], vol.inputs["Density"])
colr = nt.nodes.new("ShaderNodeValToRGB"); ce = colr.color_ramp.elements
ce[0].color = (0.25, 0.05, 0.6, 1); ce[1].color = (0.2, 0.7, 1.0, 1); e = ce.new(0.5); e.color = (0.9, 0.15, 0.65, 1)
nz2 = nt.nodes.new("ShaderNodeTexNoise"); nz2.inputs["Scale"].default_value = 0.35
nt.links.new(tc.outputs["Object"], nz2.inputs["Vector"]); nt.links.new(nz2.outputs["Fac"], colr.inputs["Fac"])
nt.links.new(colr.outputs["Color"], vol.inputs["Color"]); nt.links.new(colr.outputs["Color"], vol.inputs["Emission Color"])
emd = nt.nodes.new("ShaderNodeMath"); emd.operation = "MULTIPLY"; emd.inputs[1].default_value = 1.6
nt.links.new(dens.outputs[0], emd.inputs[0]); nt.links.new(emd.outputs[0], vol.inputs["Emission Strength"])
nt.links.new(vol.outputs[0], outn.inputs["Volume"])
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -3.5)); gbox = bpy.context.active_object; gbox.name = "GasVolume"
gbox.scale = (26, 22, 30); bpy.ops.object.transform_apply(scale=True); gbox.data.materials.append(gas)

# star flares: 4-point star cards that face the camera
S = 256; yy, xx = np.mgrid[-1:1:S * 1j, -1:1:S * 1j]; rr = np.sqrt(xx * xx + yy * yy) + 1e-6
flare = np.clip(np.exp(-np.abs(xx) * 60) * np.exp(-np.abs(yy) * 2.5) + np.exp(-np.abs(yy) * 60) * np.exp(-np.abs(xx) * 2.5) + np.exp(-rr * 9), 0, 1)
img = bpy.data.images.new("flare", S, S, alpha=True)
img.pixels.foreach_set(np.dstack([np.ones_like(flare), np.ones_like(flare), np.ones_like(flare), flare]).astype(np.float32).ravel())
fm = bpy.data.materials.new("Flare"); fm.use_nodes = True; nt = fm.node_tree; nt.nodes.clear()
o_ = nt.nodes.new("ShaderNodeOutputMaterial"); tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = img
em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Strength"].default_value = 12; em.inputs["Color"].default_value = (0.85, 0.92, 1, 1)
tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mx = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(tx.outputs["Alpha"], mx.inputs[0]); nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], o_.inputs["Surface"])
try: fm.surface_render_method = "BLENDED"
except Exception: pass
flares = []
for c, size in (((0, -0.25, 0.05), 1.6), ((0.0, 0.0, -10.4), 1.2), ((1.8, -0.6, -2.5), 0.5), ((-2.2, -0.3, -6.0), 0.6), ((1.2, 0.4, -8.2), 0.4), ((-1.0, -0.8, 1.5), 0.45)):
    bpy.ops.mesh.primitive_plane_add(size=size, location=c); f = bpy.context.active_object; f.data.materials.append(fm); flares.append(f)

# =====================================================================
# World: star field + faint nebula; lights; camera; render
# =====================================================================
world = bpy.data.worlds.new("Space"); world.use_nodes = True; nt = world.node_tree; bg = nt.nodes["Background"]
tc = nt.nodes.new("ShaderNodeTexCoord"); vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 180
nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
st = nt.nodes.new("ShaderNodeMapRange"); st.inputs["From Min"].default_value = 0.08; st.inputs["From Max"].default_value = 0.0
nt.links.new(vor.outputs["Distance"], st.inputs["Value"])
pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 6; nt.links.new(st.outputs["Result"], pw.inputs[0])
nb = nt.nodes.new("ShaderNodeTexNoise"); nb.inputs["Scale"].default_value = 2.0; nb.inputs["Detail"].default_value = 8
nt.links.new(tc.outputs["Generated"], nb.inputs["Vector"])
ncr = nt.nodes.new("ShaderNodeValToRGB"); ncr.color_ramp.elements[0].position = 0.45; ncr.color_ramp.elements[0].color = (0.004, 0.003, 0.012, 1)
ncr.color_ramp.elements[1].color = (0.08, 0.02, 0.14, 1)
nt.links.new(nb.outputs["Fac"], ncr.inputs["Fac"])
add = nt.nodes.new("ShaderNodeMix"); add.data_type = "RGBA"; add.blend_type = "ADD"; add.inputs[0].default_value = 1
nt.links.new(ncr.outputs["Color"], add.inputs[6]); nt.links.new(pw.outputs[0], add.inputs[7]); nt.links.new(add.outputs[2], bg.inputs["Color"])
scene.world = world
def area(name, loc, rot_, e, col, size):
    l = bpy.data.lights.new(name, "AREA"); l.energy = e; l.color = col; l.size = size
    o = bpy.data.objects.new(name, l); scene.collection.objects.link(o); o.location = loc; o.rotation_euler = rot_
area("Key", (-6, -8, 6), (math.radians(60), 0, math.radians(-38)), 1500, (0.75, 0.85, 1.0), 4)
area("RimPink", (6, 6, 2), (math.radians(-70), 0, math.radians(135)), 2500, (1.0, 0.3, 0.8), 3)
area("RimCyan", (-6, 7, -5), (math.radians(-110), 0, math.radians(-140)), 2200, (0.3, 0.8, 1.0), 3)
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
for f in flares:
    c = f.constraints.new("TRACK_TO"); c.target = cam; c.track_axis = "TRACK_Z"; c.up_axis = "UP_Y"
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
try: scene.eevee.use_raytracing = True
except Exception: pass
for attr_, val in (("volumetric_tile_size", "4"), ("volumetric_samples", 96), ("volumetric_end", 80.0)):
    try: setattr(scene.eevee, attr_, val)
    except Exception: pass
scene.render.resolution_x = 1080; scene.render.resolution_y = 1620; scene.view_settings.view_transform = "AgX"
try: scene.view_settings.look = "AgX - Punchy"
except Exception: pass
ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree"); scene.compositing_node_group = ng
rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare")
ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor"); go = ng.nodes.new("NodeGroupOutput")
for nm, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 0.85), ("Size", 0.75), ("Quality", "High")):
    if nm in gl.inputs:
        try: gl.inputs[nm].default_value = val
        except Exception: pass
ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], go.inputs[0])
# whole sword tilted for drama
root = bpy.data.objects.new("CosmicSword", None); scene.collection.objects.link(root)
for o in sword_parts:
    if o.parent is None: o.parent = root
root.rotation_euler = (math.radians(8), math.radians(-14), math.radians(20))
def shot(fname, loc, tgt, lens, focus=None):
    cam.location = loc; cd.lens = lens; cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cd.dof.use_dof = True; cd.dof.aperture_fstop = 2.8; cd.dof.focus_distance = ((Vector(focus or tgt)) - cam.location).length
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
shot("cosmic_sword_hero.png", (-5.0, -15.5, -1.0), (0, 0, -3.3), 38, focus=(0, 0, -2.5))
scene.render.resolution_x = 1920; scene.render.resolution_y = 1080
shot("cosmic_sword_guard.png", (-3.0, -8.5, 0.6), (0, 0, 0.3), 50, focus=(0, -0.2, 0.2))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "CosmicSword.blend"))
print("DONE")
