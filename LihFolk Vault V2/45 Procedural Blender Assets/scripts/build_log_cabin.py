"""Stylised snowy log cabin for Roblox (1 unit = 1 stud). Headless:
Run: blender -b --factory-startup --python build_log_cabin.py
Builds the 8 cabin modules (walls, roof, chimney, porch, trim, glow, smoke, base) + staging props (pines, fence,
ground, moon, stars) and saves scripts/out/cabin.blend. Uses the LihFolk Blender helpers (lihfolk_bpy, lihfolk_curves)
from skills/roblox-blender-modeling/scripts in this repo."""
import sys, math, random, json
import os
HERE = os.path.dirname(os.path.abspath(__file__))
# the vault repo layout: <repo>/LihFolk Vault V2/45 Procedural Blender Assets/scripts -> <repo>/skills/.../scripts
sys.path.append(os.path.normpath(os.path.join(HERE, "..", "..", "..", "skills", "roblox-blender-modeling", "scripts")))
import importlib, bpy, bmesh
import lihfolk_bpy as lf, lihfolk_curves as lc
importlib.reload(lf); importlib.reload(lc)
from mathutils import Vector, Matrix

OUT = os.path.join(HERE, "out").replace("\\", "/")  # renders and exports land here
os.makedirs(OUT, exist_ok=True)
rng = random.Random(7)

# wipe factory scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
lf.setup_scene()


def hx(h):
    return lc.hex_rgb(h)


def jit(c, a=0.04):
    return tuple(max(0, min(1, v * (1 + rng.uniform(-a, a)))) for v in c)


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


# ---------------------------------------------------------------- palette (sRGB)
LOG = [hx("#9A5B2C"), hx("#8A4F25"), hx("#A8693A"), hx("#93552A"), hx("#7E4823")]
LOG_END_IN, LOG_END_OUT = hx("#E2B47A"), hx("#9C6234")
ROOF_WOOD = hx("#4A2C18")
SNOW = hx("#F4F7FC")
SNOW_SH = hx("#DCE6F4")
ICE = hx("#CFE6FA")
BRICK = [hx("#A8402C"), hx("#963726"), hx("#B24A33")]
STONE = hx("#5E5A58")
TRIM = hx("#EAE0CC")
MULLION = hx("#3B2414")
SHUTTER = [hx("#2E5A6A"), hx("#27505F")]
DOOR = [hx("#7A4826"), hx("#6E4021"), hx("#83502B"), hx("#744423")]
DOOR_DARK = hx("#4E2D16")
DECK = [hx("#7A5233"), hx("#6F4A2D"), hx("#86593A")]
POST = hx("#8A5A31")
FW_SIDE, FW_IN, FW_OUT = hx("#6A4327"), hx("#DDAA6C"), hx("#8F5F35")
IRON = hx("#2C2A28")
GLOW = hx("#FFB24A")


# ---------------------------------------------------------------- mesh builder (one shell per primitive)
class MB:
    """Accumulates closed primitive shells with face-corner vertex colours ("Col", sRGB)."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.parts = {}   # tag -> list of (lo, hi) bbox, for seat/align checks

    def add(self, verts, faces, colfn, tag=None, fix=True):
        ctr = sum((Vector(v) for v in verts), Vector()) / len(verts)
        vs = [self.bm.verts.new(Vector(v)) for v in verts]
        for f in faces:
            face = self.bm.faces.new([vs[i] for i in f])
            face.normal_update()
            c = face.calc_center_median()
            nrm = face.normal.copy()
            if fix and (c - ctr).dot(nrm) < 0:
                nrm = -nrm
            for lp in face.loops:
                col = colfn(c, nrm, lp.vert.co) if callable(colfn) else colfn
                lp[self.col] = (col[0], col[1], col[2], 1.0)
        if tag:
            lo = Vector((min(v[0] for v in verts), min(v[1] for v in verts), min(v[2] for v in verts)))
            hi = Vector((max(v[0] for v in verts), max(v[1] for v in verts), max(v[2] for v in verts)))
            self.parts.setdefault(tag, []).append((lo, hi))

    def add_bm(self, tbm, M, colfn, tag=None):
        tbm.verts.ensure_lookup_table()
        idx = {v: i for i, v in enumerate(tbm.verts)}
        verts = [M @ v.co for v in tbm.verts]
        faces = [[idx[v] for v in f.verts] for f in tbm.faces]
        tbm.free()
        self.add(verts, faces, colfn, tag, fix=False)

    def box(self, lo, hi, col, tag=None):
        x0, y0, z0 = lo; x1, y1, z1 = hi
        v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add(v, f, col, tag)

    def obox(self, centre, size, M3, col, tag=None):
        """Oriented box: size in local axes, rotated by 3x3 matrix M3."""
        c = Vector(centre); hx_, hy, hz = (s / 2 for s in size)
        loc = [(-hx_, -hy, -hz), (hx_, -hy, -hz), (hx_, hy, -hz), (-hx_, hy, -hz),
               (-hx_, -hy, hz), (hx_, -hy, hz), (hx_, hy, hz), (-hx_, hy, hz)]
        v = [c + M3 @ Vector(p) for p in loc]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add(v, f, col, tag)

    def cyl(self, p0, p1, r, n, side, cap_in, cap_out=None, phase=None, tag=None, r1=None):
        """Closed cylinder p0->p1, fan caps with a centre vertex (no n-gons). Caps shade from cap_in (centre)
        to cap_out (rim) for end-grain rings."""
        p0, p1 = Vector(p0), Vector(p1)
        ax = (p1 - p0).normalized()
        u = ax.orthogonal().normalized(); w = ax.cross(u)
        ph = rng.uniform(0, math.pi) if phase is None else phase
        r1 = r if r1 is None else r1
        verts = []
        for k, (p, rr) in enumerate(((p0, r), (p1, r1))):
            for i in range(n):
                a = ph + 2 * math.pi * i / n
                verts.append(p + (u * math.cos(a) + w * math.sin(a)) * rr)
        verts.append(p0); verts.append(p1)
        c0, c1 = 2 * n, 2 * n + 1
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
            faces.append((c0, j, i))
            faces.append((c1, n + i, n + j))
        cap_out = cap_out or cap_in

        def colfn(c, nrm, co):
            if abs(nrm.dot(ax)) > 0.9:
                ctr = p0 if (c - p0).dot(ax) < (p1 - p0).length / 2 else p1
                t = min(1.0, (co - ctr).length / max(r, 1e-6))
                return mix(cap_in, cap_out, t)
            return side
        self.add(verts, faces, colfn, tag)

    def cone(self, base, tip, r, n, col, tag=None):
        base, tip = Vector(base), Vector(tip)
        ax = (tip - base).normalized(); u = ax.orthogonal().normalized(); w = ax.cross(u)
        ph = rng.uniform(0, math.pi)
        verts = [base + (u * math.cos(ph + 2 * math.pi * i / n) + w * math.sin(ph + 2 * math.pi * i / n)) * r for i in range(n)]
        verts += [base, tip]
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces.append((n, j, i)); faces.append((i, j, n + 1))
        self.add(verts, faces, col, tag)

    def prism_x(self, cx, y0, y1, zb, w, h, colfn, tag=None):
        """Gable cap: triangle (width w along X, height h) extruded along Y from y0 to y1."""
        v = []
        for y in (y0, y1):
            v += [(cx - w / 2, y, zb), (cx + w / 2, y, zb), (cx, y, zb + h)]
        f = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
        self.add(v, f, colfn, tag)

    def prism_y(self, cy, x0, x1, zb, w, h, colfn, tag=None):
        v = []
        for x in (x0, x1):
            v += [(x, cy - w / 2, zb), (x, cy + w / 2, zb), (x, cy, zb + h)]
        f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        self.add(v, f, colfn, tag)

    def ico(self, centre, scale, col, subdiv=1):
        tbm = bmesh.new()
        bmesh.ops.create_icosphere(tbm, subdivisions=subdiv, radius=1.0)
        M = Matrix.Translation(centre) @ Matrix.Diagonal((*scale, 1))
        self.add_bm(tbm, M, col)

    def outline_xz(self, outline, y0, y1, bevel, colfn, tag=None):
        """Slab from a 2D (x, z) outline extruded along Y (lc.extrude_outline, chamfered, ear-clipped caps)."""
        ob = lc.extrude_outline("_tmp", outline, abs(y1 - y0), bevel=bevel, cls="building")
        M = Matrix.Translation((0, (y0 + y1) / 2, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")
        tbm = bmesh.new(); tbm.from_mesh(ob.data)
        me = ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
        for l in list(tbm.loops.layers.uv):
            tbm.loops.layers.uv.remove(l)
        self.add_bm(tbm, M, colfn, tag)

    def to_object(self, coll):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me); self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        ca = me.color_attributes["Col"]
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
        return ob


def coll(name):
    c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c); return c


C_CABIN, C_STAGE = coll("Cabin"), coll("Staging")

# ---------------------------------------------------------------- dimensions
XW, YW = 9.0, 11.0          # wall centre lines
R, DZ, NC = 0.62, 1.12, 11  # log radius, course spacing, courses on the side walls
OV = 1.05                   # log ends past the corners
T = math.tan(math.radians(50))
Z_EAVE = R + (NC - 1) * DZ + R          # top of the last side log = roof underside at |x| = XW
def zb(x):  # roof underside
    return Z_EAVE + (XW - abs(x)) * T
D_WOOD, D_SNOW = 0.9, 1.6
FRONT = -(YW + R)            # outer face of the front gable wall (y)
SIDE = XW + R                # outer face of the right wall (x)
LOGN = 10

# ================================================================ WALLS
W = MB("Cabin_Walls")
for i in range(NC):
    z = R + i * DZ
    for sx in (-1, 1):   # side walls run along Y
        ext = OV + rng.uniform(-0.12, 0.12)
        W.cyl((sx * XW, -(YW + ext), z), (sx * XW, YW + ext, z), R * rng.uniform(0.96, 1.03), LOGN,
              jit(rng.choice(LOG)), LOG_END_IN, LOG_END_OUT, tag="log")
for i in range(-1, NC - 1):   # gable walls run along X, offset half a course; i=-1 is the sill log
    z = R + DZ / 2 + i * DZ if i >= 0 else 0.47
    rr = R if i >= 0 else 0.47
    for sy in (-1, 1):
        ext = OV + rng.uniform(-0.12, 0.12)
        W.cyl((-(XW + ext), sy * YW, z), (XW + ext, sy * YW, z), rr * rng.uniform(0.96, 1.03), LOGN,
              jit(rng.choice(LOG)), LOG_END_IN, LOG_END_OUT, tag="log")
# gable triangles: logs shorten under the roof slope
k = NC - 1
while True:
    z = R + DZ / 2 + k * DZ
    hw = XW - (z + R - Z_EAVE) / T + 0.15
    if hw < 1.0:
        break
    for sy in (-1, 1):
        W.cyl((-hw, sy * YW, z), (hw, sy * YW, z), R * 0.97, LOGN, jit(rng.choice(LOG)), LOG_END_IN, LOG_END_OUT, tag="log")
    k += 1
walls_ob = W.to_object(C_CABIN)

# ================================================================ ROOF (+snow, icicles)
RF = MB("Cabin_Roof")
XE_W, XE_S = XW + 1.9, XW + 2.55
Y_W, Y_S = YW + 1.65, YW + 2.05


def chevron(xe, z_off, thick, lip=0.0):
    zt = lambda x: zb(x) + z_off
    pts = [(-xe, zt(-xe) - lip), (0, zt(0)), (xe, zt(xe) - lip),
           (xe, zt(xe) + thick), (0, zt(0) + thick), (-xe, zt(-xe) + thick)]
    return pts


wood = chevron(XE_W, 0.0, D_WOOD)
RF.outline_xz(wood, -Y_W, Y_W, 0.1, lambda c, n, co: ROOF_WOOD if n.z < 0.3 else mix(ROOF_WOOD, SNOW, 0.0), tag="roofwood")
# snow: rounded lip and soft ridge
sn = chevron(XE_S, D_WOOD - 0.02, D_SNOW, lip=0.45)
sn = lc.round_corners(sn, [0.5, 0.05, 0.5, 0.75, 1.1, 0.75], mode="arc", closed=True, max_step_deg=30)
sn = [(p[0], p[1]) for p in sn]
RF.outline_xz(sn, -Y_S, Y_S, 0.35,
              lambda c, n, co: SNOW if n.z > 0.25 else (SNOW_SH if n.z > -0.3 else hx("#C9D6E8")), tag="snow")
# icicles along both eaves and the front/back rakes
def icicle_row(p0, p1, count, skip=None):
    p0, p1 = Vector(p0), Vector(p1)
    for i in range(count):
        t = (i + 0.5 + rng.uniform(-0.3, 0.3)) / count
        p = p0.lerp(p1, t)
        if skip and skip(p):
            continue
        L = rng.choice([0.7, 1.0, 1.3, 1.7, 2.1]) * rng.uniform(0.8, 1.15)
        r = rng.uniform(0.2, 0.28); L *= 1.25
        RF.cone((p.x, p.y, p.z + 0.45), (p.x, p.y, p.z - L), r, 5, ICE, tag="icicle")

zl = zb(XE_S - 0.55) + D_WOOD - 0.02 - 0.45 * (XE_S - 0.55) / XE_S + 0.05   # snow underside just inside the lip
for sx in (-1, 1):
    icicle_row((sx * (XE_S - 0.55), -Y_S + 0.4, zl), (sx * (XE_S - 0.55), Y_S - 0.4, zl), 34,
               skip=(lambda p: -10.2 < p.y < 10.2) if sx > 0 else None)
for sy in (-1, 1):  # rake (gable edge) icicles: shorter
    for side in (-1, 1):
        for i in range(6):
            x = side * (1.2 + i * 1.55 + rng.uniform(-0.2, 0.2))
            zz = zb(x) + D_WOOD - 0.15
            L = rng.uniform(0.45, 1.1)
            RF.cone((x, sy * (Y_S - 0.3), zz + 0.2), (x, sy * (Y_S - 0.3), zz - L), rng.uniform(0.11, 0.16), 5, ICE, tag="icicle")
roof_ob = RF.to_object(C_CABIN)

# ================================================================ CHIMNEY
CH = MB("Cabin_Chimney")
CX, CY, CS = 1.7, -4.6, 2.4
z = 19.4; i = 0
while z < 27.4:
    h = 0.62
    s = CS + (0.06 if i % 2 else -0.02)
    CH.box((CX - s / 2, CY - s / 2, z), (CX + s / 2, CY + s / 2, z + h + 0.03), jit(BRICK[i % 3], 0.05), tag="brick")
    z += h; i += 1
CH.box((CX - 1.55, CY - 1.55, z), (CX + 1.55, CY + 1.55, z + 0.45), STONE, tag="crown")
CH.box((CX - 1.45, CY - 1.45, z + 0.4), (CX + 1.45, CY + 1.45, z + 0.95), lambda c, n, co: SNOW if n.z > 0.3 else SNOW_SH, tag="chsnow")
CH.box((CX - 0.55, CY - 0.55, z + 0.7), (CX + 0.55, CY + 0.55, z + 1.55), hx("#4A4644"), tag="flue")
CH_TOP = z + 1.55
chim_ob = CH.to_object(C_CABIN)

# ================================================================ WINDOWS (trim) + GLOW
TR = MB("Cabin_Trim")
GL = MB("Cabin_Glow")


def window_front(cx, cz, w, h, shutters=True, cap=True):
    y_wall = FRONT + 0.12
    fb = 0.34
    yf = FRONT - 0.36
    # glass (Glow) recessed behind the frame face
    GL.box((cx - w / 2 - 0.05, y_wall - 0.02, cz - h / 2 - 0.05), (cx + w / 2 + 0.05, FRONT - 0.1, cz + h / 2 + 0.05), GLOW, tag="glass")
    # frame: 4 bars
    TR.box((cx - w / 2 - fb, yf, cz - h / 2 - fb), (cx + w / 2 + fb, y_wall, cz - h / 2 + 0.01), TRIM, tag="frame")
    TR.box((cx - w / 2 - fb + 0.01, yf - 0.01, cz + h / 2), (cx + w / 2 + fb - 0.01, y_wall + 0.01, cz + h / 2 + fb), TRIM, tag="frame")
    TR.box((cx - w / 2 - fb + 0.02, yf + 0.01, cz - h / 2 + 0.03), (cx - w / 2, y_wall - 0.01, cz + h / 2 + 0.02), TRIM, tag="frame")
    TR.box((cx + w / 2, yf + 0.01, cz - h / 2 + 0.03), (cx + w / 2 + fb - 0.02, y_wall - 0.01, cz + h / 2 + 0.02), TRIM, tag="frame")
    # mullions (cross)
    TR.box((cx - 0.09, FRONT - 0.3, cz - h / 2 - 0.12), (cx + 0.09, FRONT - 0.05, cz + h / 2 + 0.12), MULLION, tag="mullion")
    TR.box((cx - w / 2 - 0.12, FRONT - 0.28, cz + h * 0.12 - 0.08), (cx + w / 2 + 0.12, FRONT - 0.07, cz + h * 0.12 + 0.08), MULLION, tag="mullion")
    # sill
    TR.box((cx - w / 2 - 0.6, FRONT - 0.62, cz - h / 2 - fb - 0.28), (cx + w / 2 + 0.6, y_wall + 0.03, cz - h / 2 - fb + 0.02),
           lambda c, n, co: SNOW if n.z > 0.5 else TRIM, tag="sill")
    if shutters:
        sw = w * 0.5
        for sx in (-1, 1):
            x0 = cx + sx * (w / 2 + fb + 0.08)
            x1 = x0 + sx * sw
            a, b = min(x0, x1), max(x0, x1)
            mid = (a + b) / 2
            TR.box((a, FRONT - 0.32, cz - h / 2 - 0.15), (mid - 0.03, y_wall, cz + h / 2 + 0.15), SHUTTER[0], tag="shutter")
            TR.box((mid + 0.03, FRONT - 0.3, cz - h / 2 - 0.14), (b, y_wall - 0.01, cz + h / 2 + 0.16), SHUTTER[1], tag="shutter")
            TR.box((a + 0.05, FRONT - 0.42, cz - h / 2 + 0.35), (b - 0.05, FRONT - 0.3, cz - h / 2 + 0.6), SHUTTER[1], tag="shutter")
            TR.box((a + 0.05, FRONT - 0.42, cz + h / 2 - 0.6), (b - 0.05, FRONT - 0.29, cz + h / 2 - 0.35), SHUTTER[1], tag="shutter")
    if cap:
        TR.prism_x(cx, FRONT - 0.7, y_wall, cz + h / 2 + fb - 0.02, w + 1.3, 1.05,
                   lambda c, n, co: SNOW if n.z > 0.3 else (TRIM if n.y < -0.5 else hx("#6A4326")), tag="cap")


def window_side(cy, cz, w, h, cap=True):
    x_wall = SIDE - 0.12
    fb = 0.34
    xf = SIDE + 0.36
    GL.box((SIDE + 0.1, cy - w / 2 - 0.05, cz - h / 2 - 0.05), (x_wall + 0.02, cy + w / 2 + 0.05, cz + h / 2 + 0.05), GLOW, tag="glass")
    TR.box((x_wall, cy - w / 2 - fb, cz - h / 2 - fb), (xf, cy + w / 2 + fb, cz - h / 2 + 0.01), TRIM, tag="frame")
    TR.box((x_wall - 0.01, cy - w / 2 - fb + 0.01, cz + h / 2), (xf + 0.01, cy + w / 2 + fb - 0.01, cz + h / 2 + fb), TRIM, tag="frame")
    TR.box((x_wall + 0.01, cy - w / 2 - fb + 0.02, cz - h / 2 + 0.03), (xf - 0.01, cy - w / 2, cz + h / 2 + 0.02), TRIM, tag="frame")
    TR.box((x_wall + 0.01, cy + w / 2, cz - h / 2 + 0.03), (xf - 0.01, cy + w / 2 + fb - 0.02, cz + h / 2 + 0.02), TRIM, tag="frame")
    TR.box((SIDE + 0.05, cy - 0.09, cz - h / 2 - 0.12), (SIDE + 0.3, cy + 0.09, cz + h / 2 + 0.12), MULLION, tag="mullion")
    TR.box((SIDE + 0.07, cy - w / 2 - 0.12, cz + h * 0.12 - 0.08), (SIDE + 0.28, cy + w / 2 + 0.12, cz + h * 0.12 + 0.08), MULLION, tag="mullion")
    TR.box((x_wall - 0.03, cy - w / 2 - 0.6, cz - h / 2 - fb - 0.28), (SIDE + 0.62, cy + w / 2 + 0.6, cz - h / 2 - fb + 0.02),
           lambda c, n, co: SNOW if n.z > 0.5 else TRIM, tag="sill")
    if cap:
        TR.prism_y(cy, x_wall, SIDE + 0.7, cz + h / 2 + fb - 0.02, w + 1.3, 1.05,
                   lambda c, n, co: SNOW if n.z > 0.3 else (TRIM if n.x > 0.5 else hx("#6A4326")), tag="cap")


WIN_Z, WIN_W, WIN_H = 5.7, 2.8, 3.4
window_front(-4.5, WIN_Z, WIN_W, WIN_H)
window_front(4.5, WIN_Z, WIN_W, WIN_H)
window_front(0.0, 16.3, 2.0, 2.5, shutters=False)
window_side(4.6, WIN_Z, 2.6, 3.2)

# ================================================================ PORCH
PO = MB("Cabin_Porch")
PX0, PX1 = SIDE - 0.05, SIDE + 6.0      # deck from the wall to the outer edge
PY0, PY1 = -10.2, 10.2
DECK_H = 0.9
n_pl = 6
pw = (PX1 - PX0) / n_pl
for i in range(n_pl):
    PO.box((PX0 + i * pw + 0.03, PY0 + rng.uniform(-0.05, 0.05), 0.0), (PX0 + (i + 1) * pw - 0.03, PY1 + rng.uniform(-0.05, 0.05), DECK_H + rng.uniform(-0.02, 0.02)),
           lambda c, n, co, col=jit(rng.choice(DECK)): SNOW if (n.z > 0.5 and c.x > PX1 - pw * 1.2) else col, tag="deck")
# steps in front of the door
DOOR_Y, DOOR_W, DOOR_H = -5.2, 3.6, 7.5
PO.box((PX1 - 0.1, DOOR_Y - 2.0, 0.0), (PX1 + 0.95, DOOR_Y + 2.0, 0.62), jit(DECK[0]), tag="step")
PO.box((PX1 + 0.85, DOOR_Y - 2.05, 0.0), (PX1 + 1.85, DOOR_Y + 2.05, 0.31), jit(DECK[2]), tag="step")
# porch roof (lean-to), wood + snow
PR_Z0, PR_Z1, PR_X1 = 10.05, 8.75, PX1 + 0.9
slope = (PR_Z0 - PR_Z1) / (PR_X1 - SIDE)
pz = lambda x: PR_Z0 - (x - SIDE) * slope
pw_out = [(SIDE - 0.4, pz(SIDE - 0.4)), (PR_X1, pz(PR_X1)), (PR_X1, pz(PR_X1) + 0.45), (SIDE - 0.4, pz(SIDE - 0.4) + 0.45)]
PO.outline_xz(pw_out, PY0 - 0.5, PY1 + 0.5, 0.08, ROOF_WOOD, tag="proof")
ps_out = [(SIDE - 0.4, pz(SIDE - 0.4) + 0.43), (PR_X1 + 0.45, pz(PR_X1 + 0.45) + 0.13), (PR_X1 + 0.45, pz(PR_X1 + 0.45) + 0.95),
          (SIDE - 0.4, pz(SIDE - 0.4) + 1.2)]
ps_out = lc.round_corners(ps_out, [0.05, 0.35, 0.4, 0.05], mode="arc", closed=True, max_step_deg=30)
PO.outline_xz([(p[0], p[1]) for p in ps_out], PY0 - 0.85, PY1 + 0.85, 0.3,
              lambda c, n, co: SNOW if n.z > 0.25 else SNOW_SH, tag="psnow")
# beam + posts
PO.box((PX1 - 0.75, PY0 - 0.3, pz(PX1 - 0.75) - 0.75), (PX1 - 0.05, PY1 + 0.3, pz(PX1 - 0.05) + 0.02), POST, tag="beam")
POSTS_Y = [PY0 + 0.4, DOOR_Y + 2.4, 1.4, PY1 - 0.4]
for py in POSTS_Y:
    PO.box((PX1 - 0.7, py - 0.35, DECK_H - 0.05), (PX1 - 0.1, py + 0.35, pz(PX1 - 0.4) - 0.6), jit(POST), tag="post")
# railing on the right section (window + firewood side)
for zz in (2.2, 3.9):
    PO.box((PX1 - 0.6, POSTS_Y[1] + 0.3, zz), (PX1 - 0.2, PY1 - 0.7, zz + 0.32), jit(POST),
           tag="rail")
    PO.box((PX1 - 0.62, PY0 + 0.7, zz), (PX1 - 0.18, DOOR_Y - 2.3, zz + 0.32), jit(POST), tag="rail")
# icicles along the porch roof edge
for i in range(16):
    y = PY0 - 0.5 + (i + 0.5 + rng.uniform(-0.3, 0.3)) * (PY1 - PY0 + 1.0) / 16
    zz = pz(PR_X1 + 0.3) + 0.1
    PO.cone((PR_X1 + 0.25, y, zz + 0.2), (PR_X1 + 0.25, y, zz - rng.choice([0.6, 0.9, 1.2, 1.5])), rng.uniform(0.12, 0.18), 5, ICE, tag="icicle")
# door (planks + battens + frame + knob)
dz0 = DECK_H
for i in range(4):
    y0 = DOOR_Y - DOOR_W / 2 + i * DOOR_W / 4
    PO.box((SIDE - 0.2, y0 + 0.02, dz0 + 0.01), (SIDE + 0.12 + rng.uniform(0, 0.03), y0 + DOOR_W / 4 - 0.02, dz0 + DOOR_H), jit(DOOR[i], 0.05), tag="door")
for zz in (dz0 + 1.4, dz0 + DOOR_H - 1.6):
    PO.box((SIDE + 0.1, DOOR_Y - DOOR_W / 2 + 0.25, zz), (SIDE + 0.28, DOOR_Y + DOOR_W / 2 - 0.25, zz + 0.4), DOOR_DARK, tag="door")
PO.box((SIDE - 0.1, DOOR_Y - DOOR_W / 2 - 0.45, dz0 - 0.03), (SIDE + 0.32, DOOR_Y - DOOR_W / 2 + 0.01, dz0 + DOOR_H + 0.45), POST, tag="doorframe")
PO.box((SIDE - 0.1, DOOR_Y + DOOR_W / 2 - 0.01, dz0 - 0.02), (SIDE + 0.33, DOOR_Y + DOOR_W / 2 + 0.45, dz0 + DOOR_H + 0.46), POST, tag="doorframe")
PO.box((SIDE - 0.11, DOOR_Y - DOOR_W / 2 - 0.6, dz0 + DOOR_H - 0.02), (SIDE + 0.36, DOOR_Y + DOOR_W / 2 + 0.6, dz0 + DOOR_H + 0.5), POST, tag="doorframe")
PO.cyl((SIDE + 0.08, DOOR_Y + DOOR_W / 2 - 0.55, dz0 + 3.6), (SIDE + 0.55, DOOR_Y + DOOR_W / 2 - 0.55, dz0 + 3.6), 0.13, 6, IRON, IRON, tag="knob")
# wall lantern
LY, LZ = DOOR_Y + DOOR_W / 2 + 1.35, 6.9
PO.box((SIDE - 0.7, LY - 0.18, LZ + 0.9), (SIDE + 0.75, LY + 0.18, LZ + 1.12), IRON, tag="lantern")
PO.box((SIDE + 0.15, LY - 0.45, LZ - 0.12), (SIDE + 1.05, LY + 0.45, LZ + 0.06), IRON, tag="lantern")
PO.cone((SIDE + 0.6, LY, LZ + 0.95), (SIDE + 0.6, LY, LZ + 1.6), 0.68, 4, IRON, tag="lantern")
GL.box((SIDE + 0.25, LY - 0.33, LZ + 0.04), (SIDE + 0.95, LY + 0.33, LZ + 0.98), GLOW, tag="lanternglass")
LANTERN = Vector((SIDE + 0.6, LY, LZ + 0.5))
# firewood stack against the wall, ends facing +X
FW_R = 0.33
for row in range(5):
    zc = DECK_H + FW_R * 0.93 + row * FW_R * 1.4
    ys = 6.6 + (FW_R if row % 2 else 0)
    ncols = 5 - (row // 2) if row < 4 else 3
    for c in range(ncols):
        y = ys + c * FW_R * 2.02 + rng.uniform(-0.03, 0.03)
        if y > PY1 - 0.4:
            continue
        x0 = SIDE + 0.05 + rng.uniform(0, 0.15)
        PO.cyl((x0, y, zc), (x0 + 1.9 + rng.uniform(-0.1, 0.1), y, zc), FW_R * rng.uniform(0.97, 1.04), 7, jit(FW_SIDE), FW_IN, FW_OUT, tag="firewood")
porch_ob = PO.to_object(C_CABIN)
trim_ob = TR.to_object(C_CABIN)
glow_ob = GL.to_object(C_CABIN)

# ================================================================ SMOKE (sweep along an S curve)
pts = [(CX, CY, CH_TOP - 0.3), (CX - 0.2, CY - 0.2, CH_TOP + 1.6), (CX + 0.7, CY - 0.4, CH_TOP + 3.2),
       (CX + 0.1, CY - 0.7, CH_TOP + 4.8), (CX - 1.1, CY - 0.9, CH_TOP + 6.1), (CX - 1.5, CY - 1.2, CH_TOP + 7.6),
       (CX - 0.6, CY - 1.4, CH_TOP + 8.9), (CX + 1.0, CY - 1.6, CH_TOP + 9.6)]
path = lc.catmull_rom(pts, samples=10)
smoke_tmp = lc.sweep("Cabin_Smoke", path, radius=lambda s: 0.4 + 0.6 * math.sin(math.pi * min(1, s * 1.15)) ** 0.8 * (1 - 0.65 * s),
                     segments=26, profile=lc.circle(7), cls="small")
SM = MB("Cabin_Smoke_b")
tbm = bmesh.new(); tbm.from_mesh(smoke_tmp.data)
for l in list(tbm.loops.layers.uv):
    tbm.loops.layers.uv.remove(l)
me = smoke_tmp.data; bpy.data.objects.remove(smoke_tmp); bpy.data.meshes.remove(me)
SM.add_bm(tbm, Matrix(), lambda c, n, co: mix(hx("#C9CED8"), hx("#F2F4F8"), min(1, max(0, (co.z - CH_TOP) / 10))))
SM.name = "Cabin_Smoke"
smoke_ob = SM.to_object(C_CABIN)

# ================================================================ BASE (snow plate + drifts)
BA = MB("Cabin_Base")
BX0, BX1, BY0, BY1 = -13.5, PX1 + 3.6, -15.0, 15.0
outline = lc.rounded_rect(BX1 - BX0, BY1 - BY0, 3.0, segs=3)
ob = lc.extrude_outline("_plate", outline, 0.6, bevel=0.25, cls="building")
tbm = bmesh.new(); tbm.from_mesh(ob.data)
for l in list(tbm.loops.layers.uv):
    tbm.loops.layers.uv.remove(l)
me = ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
BA.add_bm(tbm, Matrix.Translation(((BX0 + BX1) / 2, (BY0 + BY1) / 2, -0.3 + 0.08)),
          lambda c, n, co: SNOW if n.z > 0.5 else SNOW_SH, tag="plate")
# drifts hugging the walls (flattened icospheres)
drifts = []
for x in (-7.5, -3.0, 1.5, 6.0):
    drifts.append(((x + rng.uniform(-0.6, 0.6), FRONT - 0.5, 0.05), (3.4, 1.7, 0.85)))
for y in (-7.0, 0.0, 7.0):
    drifts.append(((-SIDE - 0.5, y + rng.uniform(-0.6, 0.6), 0.05), (1.7, 3.4, 0.9)))
for x in (-6.0, 0.0, 6.0):
    drifts.append(((x, YW + R + 0.5, 0.05), (3.4, 1.6, 0.8)))
drifts += [((-XW - 1.2, FRONT - 0.9, 0.05), (2.0, 2.0, 1.0)), ((PX1 + 2.0, PY0 - 1.2, 0.05), (2.2, 1.6, 0.6)),
           ((PX1 + 2.2, PY1 + 1.0, 0.05), (2.0, 1.8, 0.65))]
for c, s in drifts:
    BA.ico(c, (s[0] * rng.uniform(0.9, 1.1), s[1] * rng.uniform(0.9, 1.1), s[2]), lambda c_, n, co: SNOW if n.z > 0.2 else SNOW_SH)
base_ob = BA.to_object(C_CABIN)

MODULES = [walls_ob, roof_ob, chim_ob, porch_ob, trim_ob, glow_ob, smoke_ob, base_ob]

# ---------------------------------------------------------------- seat checks (on raw parts, before finishing)
part_info = {m.name: {k: len(v) for k, v in b.parts.items()} for m, b in
             zip(MODULES, [W, RF, CH, PO, TR, GL, SM, BA])}

# ---------------------------------------------------------------- re-centre: bottom centre of the whole cabin at the origin
bpy.context.view_layer.update()
pts_all = [m.matrix_world @ v.co for m in MODULES for v in m.data.vertices]
lo = Vector((min(p.x for p in pts_all), min(p.y for p in pts_all), min(p.z for p in pts_all)))
hi = Vector((max(p.x for p in pts_all), max(p.y for p in pts_all), max(p.z for p in pts_all)))
shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
for m in MODULES:
    m.data.transform(Matrix.Translation(shift))
SHIFT = shift

# ---------------------------------------------------------------- finishing + materials
vc = None
FINISH = {"Cabin_Walls": dict(style="soft", bevel_width=0.07, smooth_angle=60),
          "Cabin_Roof": dict(style="soft", bevel_width=0.08, smooth_angle=75),
          "Cabin_Chimney": dict(style="soft", bevel_width=0.07, smooth_angle=60),
          "Cabin_Porch": dict(style="soft", bevel_width=0.06, smooth_angle=60),
          "Cabin_Trim": dict(style="soft", bevel_width=0.05, smooth_angle=60),
          "Cabin_Glow": dict(style="faceted"),
          "Cabin_Smoke": dict(style="smooth", smooth_angle=80),
          "Cabin_Base": dict(style="smooth", smooth_angle=50)}
for m in MODULES:
    lf.finish(m, **FINISH[m.name])
    if FINISH[m.name]["style"] == "soft":
        tri = m.modifiers.new("LF_TriNgons", "TRIANGULATE"); tri.min_vertices = 5
        tri.keep_custom_normals = True; m.modifiers.move(len(m.modifiers) - 1, 1)
    if m.name == "Cabin_Glow":
        mat = bpy.data.materials.new("LF_Glow")
        mat.use_nodes = True
        b = mat.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (1.0, 0.45, 0.1, 1)
        b.inputs["Emission Color"].default_value = (1.0, 0.5, 0.14, 1)
        b.inputs["Emission Strength"].default_value = 9.0
        m.data.materials.clear(); m.data.materials.append(mat)
    elif m.name == "Cabin_Smoke":
        mat = bpy.data.materials.new("LF_Smoke")
        mat.use_nodes = True
        nt = mat.node_tree
        b = nt.nodes["Principled BSDF"]
        v = nt.nodes.new("ShaderNodeVertexColor"); v.layer_name = "Col"
        nt.links.new(v.outputs["Color"], b.inputs["Base Color"])
        zr = nt.nodes.new("ShaderNodeNewGeometry"); sz = nt.nodes.new("ShaderNodeSeparateXYZ")
        am = nt.nodes.new("ShaderNodeMapRange"); am.clamp = True
        am.inputs["From Min"].default_value = CH_TOP + SHIFT.z; am.inputs["From Max"].default_value = CH_TOP + SHIFT.z + 10
        am.inputs["To Min"].default_value = 0.5; am.inputs["To Max"].default_value = 0.0
        nt.links.new(zr.outputs["Position"], sz.inputs[0]); nt.links.new(sz.outputs["Z"], am.inputs["Value"])
        nt.links.new(am.outputs["Result"], b.inputs["Alpha"])
        b.inputs["Roughness"].default_value = 1.0
        mat.surface_render_method = "BLENDED"
        m.data.materials.clear(); m.data.materials.append(mat)
    else:
        lc.vertex_color_material(m)
    lf.set_origin(m, "point", at=(0, 0, 0))

# ================================================================ STAGING (not exported)
ST = []


def stage_obj(b, finish="soft"):
    ob = b.to_object(C_STAGE)
    lf.finish(ob, finish, bevel_width=0.06, smooth_angle=60) if finish == "soft" else lf.finish(ob, finish)
    lc.vertex_color_material(ob)
    ST.append(ob)
    return ob


PINE, PINE2 = hx("#2E4A3C"), hx("#3A5A48")
TRUNK = hx("#4A3222")


def pine(name, x, y, s):
    b = MB(name)
    b.cyl((x, y, -0.2), (x, y, 3.0 * s), 0.45 * s, 6, TRUNK, TRUNK)
    tiers = [(1.6, 4.6, 5.0), (3.9, 3.8, 4.4), (6.0, 3.0, 4.0), (8.0, 2.2, 3.6), (9.8, 1.4, 3.0)]
    for zb_, r, h in tiers:
        zb_ *= s; r *= s; h *= s
        rr = r * rng.uniform(0.92, 1.05)
        b.cone((x, y, zb_), (x, y, zb_ + h), rr, 9, jit(PINE if rng.random() < .5 else PINE2))
        b.cone((x, y, zb_ + 0.38 * s), (x, y, zb_ + h + 0.2 * s), rr * 0.86, 9, SNOW)
    return stage_obj(b)


def fence(name, p0, p1, n):
    b = MB(name)
    p0, p1 = Vector(p0), Vector(p1)
    for i in range(n + 1):
        p = p0.lerp(p1, i / n)
        b.cyl((p.x, p.y, -0.3), (p.x, p.y, 4.2 + rng.uniform(-0.2, 0.2)), 0.24, 6, jit(POST), FW_IN, FW_OUT)
        b.cyl((p.x, p.y, 4.1), (p.x, p.y, 4.45), 0.3, 6, SNOW, SNOW)
    d = (p1 - p0)
    for zz in (1.6, 3.2):
        b.cyl((p0.x - d.x * 0.03, p0.y - d.y * 0.03, zz), (p1.x + d.x * 0.03, p1.y + d.y * 0.03, zz + 0.15), 0.17, 6, jit(POST), FW_IN, FW_OUT)
    return stage_obj(b)


# positions are in the re-centred frame
sx, sy = SHIFT.x, SHIFT.y
fence("Stage_Fence", (-13 + sx, -22 + sy, 0), (-27 + sx, -19 + sy, 0), 3)
for i, (x, y, s) in enumerate([(-24, 10, 1.25), (-30, -2, 1.05), (-20, 24, 1.4), (6, 32, 1.5), (26, 20, 1.35), (34, 4, 1.15),
                                (-40, 18, 1.6), (18, 40, 1.7), (40, 30, 1.5), (-10, 38, 1.6), (52, 8, 1.3), (-44, -8, 1.4),
                                (-6, 52, 2.0), (-32, 40, 1.8), (-60, 30, 2.0), (-55, 55, 2.2), (-30, 70, 2.3), (0, 80, 2.4), (25, 70, 2.2), (50, 55, 2.0), (65, 30, 1.9), (-70, 5, 1.9), (-48, 75, 2.5), (40, 85, 2.5), (70, 70, 2.3), (-80, 45, 2.4)]):
    pine(f"Stage_Pine_{i:02d}", x + sx, y + sy, s)
# ground
g = MB("Stage_Ground")
g.box((-400, -400, -1.0), (400, 400, 0.45), SNOW_SH)
gob = g.to_object(C_STAGE); lc.vertex_color_material(gob); ST.append(gob)
# moon
mbm = MB("Stage_Moon"); mbm.ico((60, 260, 120), (6, 6, 6), (1, 1, 1), subdiv=2)
moon = mbm.to_object(C_STAGE)
mm = bpy.data.materials.new("LF_Moon"); mm.use_nodes = True
mb = mm.node_tree.nodes["Principled BSDF"]
mb.inputs["Emission Color"].default_value = (0.9, 0.93, 1.0, 1); mb.inputs["Emission Strength"].default_value = 6
moon.data.materials.append(mm)
# stars (tiny emissive tetrahedra on a far dome)
stb = MB("Stage_Stars")
for i in range(450):
    az = rng.uniform(0, 2 * math.pi); el = rng.uniform(math.radians(4), math.radians(45))
    d = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))) * 600
    stb.ico(d, (rng.uniform(0.6, 1.4),) * 3, (1, 1, 1), subdiv=0)
stars = stb.to_object(C_STAGE)
stars.data.materials.append(mm)

info = {"shift": list(SHIFT), "modules": [m.name for m in MODULES], "parts": part_info,
        "lantern": list(LANTERN + SHIFT),
        "windows": [list(Vector(p) + SHIFT) for p in [(-4.5, FRONT, WIN_Z), (4.5, FRONT, WIN_Z), (0, FRONT, 16.3), (SIDE, 4.6, WIN_Z)]],
        "door": list(Vector((SIDE, DOOR_Y, DECK_H + DOOR_H / 2)) + SHIFT), "chimney_top": list(Vector((CX, CY, CH_TOP)) + SHIFT)}
json.dump(info, open(OUT + "/build_info.json", "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/cabin.blend")
print("BUILD OK", {m.name: len(m.data.polygons) for m in MODULES})
