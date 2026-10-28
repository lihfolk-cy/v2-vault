"""Celestial gate: carved stone voussoir ring with gold-trimmed keystone, glowing rune band, two brass gear
rings, crystal clusters, flanking obelisk pylons with floating crystals, stepped dais with glowing inlays,
swirling vortex event horizon + depth tunnel, lightning arcs, debris spiralling in, sparkles, floor mist.
Portal faces -Y, centre at (0, 0, 7.5). Preview render only.
Run: blender -b --factory-startup --python build_portal.py"""
import bpy, bmesh, math, random, os
import numpy as np
from mathutils import Vector, Matrix, Euler

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
C = Vector((0, 0, 7.5))            # portal centre
R_IN, R_OUT, DEPTH = 5.2, 6.9, 1.7

# =====================================================================
# Materials
# =====================================================================
def mat(name, rgb, rough=0.5, metal=0.0, emit=0.0, emit_rgb=None, coat=0.0, trans=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if emit: b.inputs["Emission Color"].default_value = (*(emit_rgb or rgb), 1); b.inputs["Emission Strength"].default_value = emit
    if coat and "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    if trans and "Transmission Weight" in b.inputs: b.inputs["Transmission Weight"].default_value = trans
    m.diffuse_color = (*rgb, 1); return m
def stone_mat(name, rgb, scale=3.0):
    m = mat(name, rgb, 0.8); nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 10
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    cr = nt.nodes.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].color = (rgb[0] * 0.5, rgb[1] * 0.5, rgb[2] * 0.5, 1); cr.color_ramp.elements[1].color = (rgb[0] * 1.5, rgb[1] * 1.5, rgb[2] * 1.6, 1)
    nt.links.new(nz.outputs["Fac"], cr.inputs["Fac"]); nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35
    nz2 = nt.nodes.new("ShaderNodeTexNoise"); nz2.inputs["Scale"].default_value = scale * 6; nz2.inputs["Detail"].default_value = 12
    nt.links.new(tc.outputs["Object"], nz2.inputs["Vector"]); nt.links.new(nz2.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m
STONE = stone_mat("CarvedStone", (0.07, 0.068, 0.085))
STONE_DK = stone_mat("DarkStone", (0.035, 0.034, 0.045), 2.0)
FLOOR = stone_mat("WetFloor", (0.02, 0.02, 0.028), 1.2); FLOOR.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.18
GOLD = mat("Gold", (1.0, 0.7, 0.3), 0.25, 1.0)
BRASS = mat("Brass", (0.75, 0.5, 0.25), 0.35, 1.0)
CRYSTAL = mat("Crystal", (0.55, 0.25, 1.0), 0.05, emit=3.5, emit_rgb=(0.6, 0.25, 1.0), coat=1.0)
CRYSTAL_C = mat("CrystalCyan", (0.3, 0.8, 1.0), 0.05, emit=4, coat=1.0)
RIM = mat("InnerRim", (0.6, 0.85, 1.0), 0.2, emit=10)
ARC = mat("Lightning", (0.75, 0.9, 1.0), 0.2, emit=12)
INLAY = mat("Inlay", (0.6, 0.3, 1.0), 0.3, emit=6)
SPARK = mat("Spark", (1, 0.95, 1), 0.2, emit=20)
ROCK = mat("Debris", (0.03, 0.028, 0.035), 0.7)

# rune band texture: rows of procedural glyphs (strokes on a 3x4 grid), emissive mask
TEXW, TEXH = 4096, 256
mask = np.zeros((TEXH, TEXW), np.float32)
yy, xx = np.mgrid[0:TEXH, 0:TEXW]
def seg_mask(x0, y0, x1, y1, w):
    dx, dy = x1 - x0, y1 - y0; L2 = dx * dx + dy * dy + 1e-6
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / L2, 0, 1)
    d = np.sqrt((xx - x0 - t * dx) ** 2 + (yy - y0 - t * dy) ** 2)
    return np.clip((w - d) / 2.0, 0, 1)
G = 56; cw = TEXW / G
for g in range(G):
    x_base = g * cw + cw * 0.18; gw = cw * 0.64; y_base = TEXH * 0.2; gh = TEXH * 0.6
    nodes = [(x_base + gw * i / 2, y_base + gh * j / 3) for i in range(3) for j in range(4)]
    r = random.Random(g)
    for _ in range(r.randint(3, 6)):
        a, b_ = r.sample(nodes, 2)
        if abs(a[0] - b_[0]) > gw * 0.6 and abs(a[1] - b_[1]) > gh * 0.5: continue
        sub = (slice(int(max(0, min(a[1], b_[1]) - 12)), int(min(TEXH, max(a[1], b_[1]) + 12))), slice(int(max(0, min(a[0], b_[0]) - 12)), int(min(TEXW, max(a[0], b_[0]) + 12))))
        xs, ys = xx[sub], yy[sub]
        dx, dy = b_[0] - a[0], b_[1] - a[1]; L2 = dx * dx + dy * dy + 1e-6
        t = np.clip(((xs - a[0]) * dx + (ys - a[1]) * dy) / L2, 0, 1)
        d = np.sqrt((xs - a[0] - t * dx) ** 2 + (ys - a[1] - t * dy) ** 2)
        mask[sub] = np.maximum(mask[sub], np.clip((7 - d) / 2.0, 0, 1))
    if r.random() < 0.5:   # a dot
        cx, cy = x_base + gw * r.choice((0, 0.5, 1)), y_base + gh * r.choice((0, 1))
        sub = (slice(int(cy - 14), int(cy + 14)), slice(int(cx - 14), int(cx + 14)))
        d = np.sqrt((xx[sub] - cx) ** 2 + (yy[sub] - cy) ** 2); mask[sub] = np.maximum(mask[sub], np.clip((9 - d) / 2.0, 0, 1))
mask[int(TEXH * 0.06):int(TEXH * 0.1), :] = 1.0; mask[int(TEXH * 0.9):int(TEXH * 0.94), :] = 1.0       # border lines
rimg = bpy.data.images.new("runes", TEXW, TEXH, alpha=False)
rimg.pixels.foreach_set(np.dstack([mask, mask, mask, np.ones_like(mask)]).ravel())
RUNES = bpy.data.materials.new("RuneBand"); RUNES.use_nodes = True; nt = RUNES.node_tree; b = nt.nodes["Principled BSDF"]
tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = rimg
b.inputs["Base Color"].default_value = (0.03, 0.03, 0.04, 1); b.inputs["Roughness"].default_value = 0.6
b.inputs["Emission Color"].default_value = (0.55, 0.3, 1.0, 1)
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 9
nt.links.new(tx.outputs["Color"], mul.inputs[0]); nt.links.new(mul.outputs[0], b.inputs["Emission Strength"])

# vortex: polar swirl noise, hot centre
def vortex_mat(name, twist, scale, bright, hue_shift=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
    ang = nt.nodes.new("ShaderNodeMath"); ang.operation = "ARCTAN2"; nt.links.new(sep.outputs["Y"], ang.inputs[0]); nt.links.new(sep.outputs["X"], ang.inputs[1])
    cmb = nt.nodes.new("ShaderNodeCombineXYZ"); nt.links.new(sep.outputs["X"], cmb.inputs["X"]); nt.links.new(sep.outputs["Y"], cmb.inputs["Y"])
    rad = nt.nodes.new("ShaderNodeVectorMath"); rad.operation = "LENGTH"; nt.links.new(cmb.outputs[0], rad.inputs[0])
    lg = nt.nodes.new("ShaderNodeMath"); lg.operation = "LOGARITHM"; lg.inputs[1].default_value = 2.718
    radc = nt.nodes.new("ShaderNodeMath"); radc.operation = "ADD"; radc.inputs[1].default_value = 0.05
    nt.links.new(rad.outputs["Value"], radc.inputs[0]); nt.links.new(radc.outputs[0], lg.inputs[0])
    tw = nt.nodes.new("ShaderNodeMath"); tw.operation = "MULTIPLY_ADD"; tw.inputs[1].default_value = twist
    nt.links.new(lg.outputs[0], tw.inputs[0]); nt.links.new(ang.outputs[0], tw.inputs[2])
    sinx = nt.nodes.new("ShaderNodeMath"); sinx.operation = "SINE"; cosx = nt.nodes.new("ShaderNodeMath"); cosx.operation = "COSINE"
    nt.links.new(tw.outputs[0], sinx.inputs[0]); nt.links.new(tw.outputs[0], cosx.inputs[0])
    v = nt.nodes.new("ShaderNodeCombineXYZ"); nt.links.new(cosx.outputs[0], v.inputs["X"]); nt.links.new(sinx.outputs[0], v.inputs["Y"]); nt.links.new(lg.outputs[0], v.inputs["Z"])
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 12; nz.inputs["Distortion"].default_value = 0.6
    nt.links.new(v.outputs[0], nz.inputs["Vector"])
    cr = nt.nodes.new("ShaderNodeValToRGB"); el = cr.color_ramp.elements
    el[0].position = 0.3; el[0].color = (0.0, 0.0, 0.0, 1); el[1].position = 0.78; el[1].color = (0.7, 0.95, 1.0, 1)
    e = el.new(0.45); e.color = (0.18 + hue_shift, 0.02, 0.5, 1); e = el.new(0.6); e.color = (0.95, 0.15, 0.75, 1)
    nt.links.new(nz.outputs["Fac"], cr.inputs["Fac"])
    core = nt.nodes.new("ShaderNodeMapRange"); core.inputs["From Min"].default_value = 0.0; core.inputs["From Max"].default_value = R_IN
    core.inputs["To Min"].default_value = 4.0; core.inputs["To Max"].default_value = 0.6
    nt.links.new(rad.outputs["Value"], core.inputs["Value"])
    sm = nt.nodes.new("ShaderNodeMath"); sm.operation = "MULTIPLY"; sm.inputs[1].default_value = bright
    nt.links.new(core.outputs["Result"], sm.inputs[0])
    nt.links.new(cr.outputs["Color"], em.inputs["Color"]); nt.links.new(sm.outputs[0], em.inputs["Strength"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m
VORTEX = vortex_mat("Vortex", 2.2, 1.6, 1.6)
VORTEX_B = vortex_mat("VortexDeep", -1.4, 2.4, 1.0, 0.1)

def obj(name, bm, mats, smooth=False, loc=None):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    for p in me.polygons: p.use_smooth = smooth
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o)
    if loc: o.location = loc
    return o
def extrude_poly(bm, pts, y0, y1, bevel=0.0, mat_index=0):
    vs = [bm.verts.new(Vector((p[0], y0, p[1]))) for p in pts]
    try: f = bm.faces.new(vs)
    except ValueError: return []
    f.material_index = mat_index
    res = bmesh.ops.extrude_face_region(bm, geom=[f]); nv = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in nv: v.co.y = y1
    for e in res["geom"]:
        if isinstance(e, bmesh.types.BMFace): e.material_index = mat_index
    if bevel: bmesh.ops.bevel(bm, geom=list({e for v in vs + nv for e in v.link_edges}), offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    return vs + nv
def sector(r0, r1, a0, a1, n=6):
    pts = [(math.cos(a0 + (a1 - a0) * i / n) * r1, math.sin(a0 + (a1 - a0) * i / n) * r1) for i in range(n + 1)]
    pts += [(math.cos(a1 - (a1 - a0) * i / n) * r0, math.sin(a1 - (a1 - a0) * i / n) * r0) for i in range(n + 1)]
    return pts

# =====================================================================
# 1. Voussoir ring + keystone
# =====================================================================
NB = 26; gap = math.radians(0.9)
bm = bmesh.new()
for i in range(NB):
    a0 = i / NB * math.tau + gap; a1 = (i + 1) / NB * math.tau - gap
    mid = (a0 + a1) / 2
    is_key = abs(((mid - math.pi / 2 + math.pi) % math.tau) - math.pi) < math.pi / NB
    ro = R_OUT + (0.9 if is_key else 0.0) + (0.12 if i % 2 else 0.0)
    pts = [(x + C.x, z + C.z) for x, z in sector(R_IN, ro, a0, a1)]
    extrude_poly(bm, pts, -DEPTH / 2 - (0.25 if is_key else 0), DEPTH / 2, bevel=0.07)
obj("Voussoirs", bm, [STONE])
bm = bmesh.new()                                   # stepped back ring (second course)
for i in range(NB):
    a0 = (i + 0.5) / NB * math.tau + gap; a1 = (i + 1.5) / NB * math.tau - gap
    extrude_poly(bm, [(x + C.x, z + C.z) for x, z in sector(R_IN + 0.3, R_OUT - 0.25, a0, a1)], DEPTH / 2, DEPTH / 2 + 0.9, bevel=0.05)
obj("BackCourse", bm, [STONE_DK])
bm = bmesh.new()                                   # gold trim rings on the front face
for r0, r1 in ((R_IN - 0.02, R_IN + 0.14), (R_OUT - 0.16, R_OUT - 0.02)):
    pts = [(x + C.x, z + C.z) for x, z in sector(r0, r1, 0, math.tau, 160)]
    outer = [bm.verts.new(Vector((math.cos(t * math.tau) * r1 + C.x, -DEPTH / 2 - 0.06, math.sin(t * math.tau) * r1 + C.z))) for t in (k / 160 for k in range(160))]
    inner = [bm.verts.new(Vector((math.cos(t * math.tau) * r0 + C.x, -DEPTH / 2 - 0.06, math.sin(t * math.tau) * r0 + C.z))) for t in (k / 160 for k in range(160))]
    for k in range(160): bm.faces.new((outer[k], outer[(k + 1) % 160], inner[(k + 1) % 160], inner[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.06)
obj("GoldTrim", bm, [GOLD])
bm = bmesh.new()                                   # keystone gem + bezel
gem_c = Vector((C.x, -DEPTH / 2 - 0.45, C.z + R_OUT + 0.35))
gv = [bm.verts.new(gem_c + d) for d in (Vector((0, 0, 0.75)), Vector((0, 0, -0.75)), Vector((0.45, 0, 0)), Vector((-0.45, 0, 0)), Vector((0, -0.45, 0)), Vector((0, 0.3, 0)))]
for a, b_ in ((2, 4), (4, 3), (3, 5), (5, 2)):
    bm.faces.new((gv[0], gv[a], gv[b_])); bm.faces.new((gv[1], gv[b_], gv[a]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
obj("KeyGem", bm, [CRYSTAL_C])

# rune band annulus on the front face
bm = bmesh.new(); uv = bm.loops.layers.uv.verify(); SEGS = 256; rr0, rr1 = R_IN + 0.3, R_IN + 0.95
ov = [bm.verts.new(Vector((math.cos(k / SEGS * math.tau) * rr1 + C.x, -DEPTH / 2 - 0.03, math.sin(k / SEGS * math.tau) * rr1 + C.z))) for k in range(SEGS + 1)]
iv = [bm.verts.new(Vector((math.cos(k / SEGS * math.tau) * rr0 + C.x, -DEPTH / 2 - 0.03, math.sin(k / SEGS * math.tau) * rr0 + C.z))) for k in range(SEGS + 1)]
for k in range(SEGS):
    f = bm.faces.new((iv[k], iv[k + 1], ov[k + 1], ov[k]))
    for lp in f.loops:
        idx = (iv + ov).index(lp.vert); kk = idx % (SEGS + 1); outer_ = idx > SEGS
        lp[uv].uv = (kk / SEGS * 2 % 1.0001, 1.0 if outer_ else 0.0)
obj("RuneBand", bm, [RUNES])

# glowing inner rim
bm = bmesh.new(); rings = []
for k in range(200):
    a = k / 200 * math.tau; p = Vector((math.cos(a) * R_IN, 0, math.sin(a) * R_IN)) + C; d = Vector((math.cos(a), 0, math.sin(a)))
    rings.append([bm.verts.new(p + d * math.cos(t) * 0.09 + Vector((0, math.sin(t) * 0.5, 0))) for t in (q / 8 * math.tau for q in range(8))])
for a, b_ in zip(rings, rings[1:] + rings[:1]):
    for q in range(8): bm.faces.new((a[q], a[(q + 1) % 8], b_[(q + 1) % 8], b_[q]))
obj("InnerRim", bm, [RIM], smooth=True)

# =====================================================================
# 2. Brass gear rings behind and around the stone
# =====================================================================
for gi, (r0, r1, yoff, teeth, rot) in enumerate(((R_OUT + 0.25, R_OUT + 0.6, 0.55, 96, 0.0), (R_OUT + 0.85, R_OUT + 1.15, 1.1, 120, 0.02))):
    bm = bmesh.new()
    pts = []
    for k in range(teeth * 2):
        a = k / (teeth * 2) * math.tau + rot; rr = r1 + (0.18 if k % 2 == 0 else 0.0)
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    outer = [bm.verts.new(Vector((x + C.x, yoff - 0.12, z + C.z))) for x, z in pts]
    inner = [bm.verts.new(Vector((math.cos(k / (teeth * 2) * math.tau) * r0 + C.x, yoff - 0.12, math.sin(k / (teeth * 2) * math.tau) * r0 + C.z))) for k in range(teeth * 2)]
    n = teeth * 2
    for k in range(n): bm.faces.new((outer[k], outer[(k + 1) % n], inner[(k + 1) % n], inner[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.24)
    for k in range(8):                              # spokes / rivet blocks
        a = k / 8 * math.tau + 0.2
        bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Translation((math.cos(a) * (r0 + r1) / 2 + C.x, yoff - 0.3, math.sin(a) * (r0 + r1) / 2 + C.z)) @ Euler((0, -a, 0)).to_matrix().to_4x4() @ Matrix.Diagonal((0.5, 0.25, 0.25, 1)))
    obj(f"GearRing{gi}", bm, [BRASS], smooth=False)

# =====================================================================
# 3. Crystal clusters at the diagonals + crown
# =====================================================================
def crystal(bm, base, d, length, radius, sides=6):
    d = d.normalized(); s = d.cross(Vector((0, 1, 0))); s = s.normalized() if s.length > 1e-3 else Vector((1, 0, 0)); u = s.cross(d)
    ring0 = [bm.verts.new(base + (s * math.cos(t) + u * math.sin(t)) * radius) for t in (k / sides * math.tau for k in range(sides))]
    ring1 = [bm.verts.new(base + d * length * 0.78 + (s * math.cos(t) + u * math.sin(t)) * radius * 0.92) for t in (k / sides * math.tau for k in range(sides))]
    tip = bm.verts.new(base + d * length)
    bm.faces.new(list(reversed(ring0)))
    for k in range(sides):
        bm.faces.new((ring0[k], ring0[(k + 1) % sides], ring1[(k + 1) % sides], ring1[k])); bm.faces.new((ring1[k], ring1[(k + 1) % sides], tip))
bm = bmesh.new(); bmc = bmesh.new()
for k, ang in enumerate((45, 135, 225, 315, 90)):
    a = math.radians(ang); out_ = Vector((math.cos(a), 0, math.sin(a)))
    base = C + out_ * (R_OUT + 0.4)
    for j in range(7 if ang != 90 else 5):
        spread = Vector((random.uniform(-0.45, 0.45), random.uniform(-0.4, 0.4), random.uniform(-0.45, 0.45)))
        L = random.uniform(1.0, 2.8) * (1.4 if j == 0 else 1.0) * (0.8 if ang == 90 else 1.0)
        crystal(bmc if (j % 3 == 1) else bm, base + spread * 0.6, out_ + spread, L, random.uniform(0.14, 0.32))
obj("Crystals", bm, [CRYSTAL]); obj("CrystalsCyan", bmc, [CRYSTAL_C])

# =====================================================================
# 4. Dais, stairs with glowing inlays, pylons with floating crystals
# =====================================================================
bm = bmesh.new(); bmi = bmesh.new()
for k, (w, d, h) in enumerate(((17, 10, 0.5), (14.5, 8.0, 0.5), (12.5, 6.4, 0.5))):
    z0 = k * 0.5; x0 = w / 2; y0 = d / 2 + 0.6
    octo = [(-x0 + 0.8, -y0), (x0 - 0.8, -y0), (x0, -y0 + 0.8), (x0, y0 - 0.8), (x0 - 0.8, y0), (-x0 + 0.8, y0), (-x0, y0 - 0.8), (-x0, -y0 + 0.8)]
    vs = [bm.verts.new(Vector((x, y, z0))) for x, y in octo]; f = bm.faces.new(vs)
    res = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]: v.co.z = z0 + h
    # glowing inlay line on each step's front riser
    bmesh.ops.create_cube(bmi, size=1, matrix=Matrix.Translation((0, -y0 - 0.01, z0 + h * 0.5)) @ Matrix.Diagonal((w - 2.2, 0.04, 0.06, 1)))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
for k in range(6):                                  # front stairs
    bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Translation((0, -5.6 - 0.5 - k * 0.55 + 0.0, 1.5 - (k + 1) * 0.25 - 0.0)) @ Matrix.Diagonal((5.0, 0.55, 0.25 * (k + 1) * 2, 1)))
obj("Dais", bm, [STONE_DK]); obj("Inlays", bmi, [INLAY])
bm = bmesh.new()                                    # portal base plinth the ring sits in
bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Translation((0, 0, 1.75)) @ Matrix.Diagonal((5.2, 2.4, 0.5, 1)))
obj("Plinth", bm, [STONE])
for sx in (-1, 1):
    bm = bmesh.new(); px = sx * 9.8
    for k, (w, h, z) in enumerate(((1.8, 1.2, 1.5), (1.4, 7.0, 2.7), (1.7, 0.5, 9.7), (1.2, 1.0, 10.2))):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=w * 0.72, radius2=w * (0.55 if k == 1 else 0.72), depth=h,
                              matrix=Matrix.Translation((px, 0, z + h / 2)) @ Euler((0, 0, math.radians(45))).to_matrix().to_4x4())
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.85, radius2=0.0, depth=1.2, matrix=Matrix.Translation((px, 0, 11.8)) @ Euler((0, 0, math.radians(45))).to_matrix().to_4x4())
    obj(f"Pylon{sx}", bm, [STONE])
    bm = bmesh.new()
    for z in (3.5, 5.5, 7.5):                       # glowing bands carved into the obelisk
        bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.98 - (z - 3.5) * 0.04, radius2=0.98 - (z - 3.5) * 0.04, depth=0.12,
                              matrix=Matrix.Translation((px, 0, z)) @ Euler((0, 0, math.radians(45))).to_matrix().to_4x4())
    obj(f"PylonBands{sx}", bm, [INLAY])
    bm = bmesh.new(); top = Vector((px, 0, 13.6))
    crystal(bm, top - Vector((0, 0, 0.9)), Vector((0, 0, 1)), 1.8, 0.45); crystal(bm, top + Vector((0, 0, 0.9)), Vector((0, 0, -1)), 1.2, 0.45)
    obj(f"PylonCrystal{sx}", bm, [CRYSTAL_C])
    l = bpy.data.lights.new(f"PylonGlow{sx}", "POINT"); l.energy = 800; l.color = (0.4, 0.8, 1.0); l.shadow_soft_size = 0.5
    lo = bpy.data.objects.new(f"PylonGlow{sx}", l); scene.collection.objects.link(lo); lo.location = top

# =====================================================================
# 5. Vortex, tunnel, lightning, debris, sparkles, mist
# =====================================================================
for nm, m, y, r in (("VortexFront", VORTEX, 0.15, R_IN + 0.05), ("VortexBack", VORTEX_B, 1.6, R_IN)):
    bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, segments=128, radius=r)
    o = obj(nm, bm, [m]); o.rotation_euler = (math.radians(90), 0, 0); o.location = C + Vector((0, y, 0))
bm = bmesh.new()                                    # tunnel cone receding behind the gate
res = bmesh.ops.create_cone(bm, cap_ends=False, segments=96, radius1=R_IN, radius2=0.4, depth=14,
                            matrix=Matrix.Translation(C + Vector((0, 7.5, 0))) @ Euler((math.radians(-90), 0, 0)).to_matrix().to_4x4())
bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
tun = obj("Tunnel", bm, [VORTEX_B])
VORTEX_B.use_backface_culling = False
def bolt(bm, a, b_, depth, disp, r):
    pts = [a, b_]
    for _ in range(depth):
        new = [pts[0]]
        for p, q in zip(pts, pts[1:]):
            m_ = (p + q) / 2 + Vector((r.uniform(-1, 1), r.uniform(-0.3, 0.3), r.uniform(-1, 1))) * disp
            new += [m_, q]
        pts = new; disp *= 0.55
    for p, q in zip(pts, pts[1:]):
        d = q - p; L_ = d.length
        if L_ < 1e-4: continue
        bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.022, radius2=0.018, depth=L_,
                              matrix=Matrix.Translation((p + q) / 2) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4())
r = random.Random(3); bm = bmesh.new()
for k in range(5):
    a = r.uniform(0, math.tau); start = C + Vector((math.cos(a) * R_IN, -0.4, math.sin(a) * R_IN))
    end = C + Vector((math.cos(a + r.uniform(0.6, 1.6)) * r.uniform(0.3, 2.5), -0.35, math.sin(a + r.uniform(0.6, 1.6)) * r.uniform(0.3, 2.5)))
    bolt(bm, start, end, 5, 1.2, r)
obj("Lightning", bm, [ARC])
bm = bmesh.new()
for k in range(160):                                # debris spiralling inward in front of the horizon
    t = random.random(); a = t * math.tau * 2.5 + random.uniform(-0.3, 0.3); rad = 1.2 + (1 - t) * 6.5
    c = C + Vector((math.cos(a) * rad, -random.uniform(0.6, 3.5) * (1 - t * 0.6), math.sin(a) * rad * 0.9))
    res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=random.uniform(0.04, 0.22))
    for v in res["verts"]: v.co = Vector((v.co.x * random.uniform(0.6, 1.3), v.co.y, v.co.z * random.uniform(0.6, 1.2))) + c
obj("Debris", bm, [ROCK])
bm = bmesh.new()
for k in range(500):
    a = random.uniform(0, math.tau); rad = abs(random.gauss(0, 3.5)) + 0.3
    c = C + Vector((math.cos(a) * rad * 1.3, -random.uniform(0.2, 6), math.sin(a) * rad))
    if c.z < 0.3: continue
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=random.uniform(0.01, 0.035), matrix=Matrix.Translation(c))
obj("Sparkles", bm, [SPARK])
mist = bpy.data.materials.new("Mist"); mist.use_nodes = True; nt = mist.node_tree; nt.nodes.clear()
outn = nt.nodes.new("ShaderNodeOutputMaterial"); vol = nt.nodes.new("ShaderNodeVolumePrincipled")
tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
fall = nt.nodes.new("ShaderNodeMapRange"); fall.inputs["From Min"].default_value = 0.0; fall.inputs["From Max"].default_value = 1.6
fall.inputs["To Min"].default_value = 1.0; fall.inputs["To Max"].default_value = 0.0; nt.links.new(sep.outputs["Z"], fall.inputs["Value"])
nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.4; nz.inputs["Detail"].default_value = 6; nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
dm = nt.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"; nt.links.new(fall.outputs["Result"], dm.inputs[0]); nt.links.new(nz.outputs["Fac"], dm.inputs[1])
d2 = nt.nodes.new("ShaderNodeMath"); d2.operation = "MULTIPLY"; d2.inputs[1].default_value = 0.07; nt.links.new(dm.outputs[0], d2.inputs[0])
nt.links.new(d2.outputs[0], vol.inputs["Density"]); vol.inputs["Color"].default_value = (0.6, 0.45, 1.0, 1)
vol.inputs["Emission Color"].default_value = (0.35, 0.15, 0.7, 1)
e2 = nt.nodes.new("ShaderNodeMath"); e2.operation = "MULTIPLY"; e2.inputs[1].default_value = 0.25; nt.links.new(dm.outputs[0], e2.inputs[0]); nt.links.new(e2.outputs[0], vol.inputs["Emission Strength"])
nt.links.new(vol.outputs[0], outn.inputs["Volume"])
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -4, 1.5)); mb = bpy.context.active_object; mb.name = "FloorMist"; mb.scale = (40, 30, 3); mb.data.materials.append(mist)
bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, 0)); fl = bpy.context.active_object; fl.data.materials.append(FLOOR)

# =====================================================================
# Lights, world, camera, render
# =====================================================================
l = bpy.data.lights.new("PortalCore", "POINT"); l.energy = 9000; l.color = (0.65, 0.4, 1.0); l.shadow_soft_size = 3
lo = bpy.data.objects.new("PortalCore", l); scene.collection.objects.link(lo); lo.location = C + Vector((0, -1.2, 0))
def area(name, loc, rot_, e, col, size):
    l = bpy.data.lights.new(name, "AREA"); l.energy = e; l.color = col; l.size = size
    o = bpy.data.objects.new(name, l); scene.collection.objects.link(o); o.location = loc; o.rotation_euler = rot_
area("Moon", (-18, -20, 26), (math.radians(45), 0, math.radians(-40)), 6000, (0.55, 0.65, 1.0), 12)
area("RimBack", (10, 18, 14), (math.radians(-55), 0, math.radians(150)), 9000, (1.0, 0.35, 0.8), 10)
world = bpy.data.worlds.new("Night"); world.use_nodes = True; nt = world.node_tree; bg = nt.nodes["Background"]
tcw = nt.nodes.new("ShaderNodeTexCoord"); vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 220
nt.links.new(tcw.outputs["Generated"], vor.inputs["Vector"])
st = nt.nodes.new("ShaderNodeMapRange"); st.inputs["From Min"].default_value = 0.07; st.inputs["From Max"].default_value = 0.0; nt.links.new(vor.outputs["Distance"], st.inputs["Value"])
pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 6; nt.links.new(st.outputs["Result"], pw.inputs[0])
sky = nt.nodes.new("ShaderNodeMix"); sky.data_type = "RGBA"; sky.blend_type = "ADD"; sky.inputs[0].default_value = 1
sky.inputs[6].default_value = (0.006, 0.006, 0.02, 1); nt.links.new(pw.outputs[0], sky.inputs[7]); nt.links.new(sky.outputs[2], bg.inputs["Color"])
scene.world = world
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
try: scene.eevee.use_raytracing = True
except Exception: pass
for attr_, val in (("volumetric_tile_size", "4"), ("volumetric_samples", 96), ("volumetric_end", 120.0)):
    try: setattr(scene.eevee, attr_, val)
    except Exception: pass
scene.render.resolution_x = 1920; scene.render.resolution_y = 1080; scene.view_settings.view_transform = "AgX"
try: scene.view_settings.look = "AgX - Punchy"
except Exception: pass
ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree"); scene.compositing_node_group = ng
rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare")
ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor"); go = ng.nodes.new("NodeGroupOutput")
for nm, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 0.8), ("Size", 0.75), ("Quality", "High")):
    if nm in gl.inputs:
        try: gl.inputs[nm].default_value = val
        except Exception: pass
ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], go.inputs[0])
tris = 0
for o in [o for o in scene.objects if o.type == "MESH" and o.name not in ("FloorMist",)]:
    o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
print("TRIS", tris)
def shot(fname, loc, tgt, lens):
    cam.location = loc; cd.lens = lens; cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
shot("portal_hero.png", (-9, -27, 4.5), (0, 0, 7.0), 26)
shot("portal_front.png", (0, -30, 6.5), (0, 0, 7.0), 30)
shot("portal_detail.png", (-7.5, -8.5, 12.5), (-3.8, 0, 11.0), 40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "CelestialGate.blend"))
print("DONE")
