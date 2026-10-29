"""LihFolk house builders: parameterised modules for any small building (cabin, cottage, medieval, modern, fantasy).

Generalised from the snowy log cabin build (vault: 45 Procedural Blender Assets / Stylised Log Cabin Worked Example)
and tested headless on Blender 5.2 with a stone cottage. 1 Blender unit = 1 stud.

    import sys; sys.path.append(r"<plugin>/skills/roblox-blender-modeling/scripts")
    import lihfolk_bpy as lf, lihfolk_curves as lc, lihfolk_house as lh

House frame used by every builder (keep it, rotate the finished house in Studio instead):
    - footprint centred on the world origin, ridge along Y;
    - eave (long) walls on wall centre lines x = +-hx, gable (end) walls on y = +-hy;
    - the roof slopes across X: underside height  Gable.under(x) = eave_z + (hx - |x|) * tan(pitch);
    - wall faces are addressed as Face("-Y" | "+Y" | "-X" | "+X", plane) with local coordinates
      (u = along the wall, left to right seen from outside; z = height; d = distance out of the face).

Builders (each adds closed shells to a MeshBuilder; one builder = one exported module):
    MeshBuilder(name, rng)         box / obox / cyl / cone / prism / ico / outline_xz -> to_object()
    Gable(hx, eave_z, pitch_deg)   roof underside function shared by walls, roof, chimney and icicles
    house_faces(hx, hy, half_t)    the four outer wall faces
    log_walls(...)                 round logs, interlocking corners, gable logs cut by the roof, real openings
    coursed_walls(...)             stone / brick blocks with staggered joints, corner bond, quoins, lintels,
                                   gable courses cut by the roof, real openings snapped to course lines
    gable_roof(...)                slab or shingle-row roof with overhangs, ridge cap, optional snow with lip
    icicle_row(...)                icicles seated from the snow geometry (never by eye)
    chimney(...), window(...), door(...), steps(...), foundation(...), plank_deck(...)
    opening_footprint(...), check_wall_layout(...)   plan openings (frames + shutters) before modelling
Pipeline helpers:
    recentre(modules)              ONE shared origin: bottom centre of the whole house, for every module
    finish_modules(modules, map)   lf.finish + Triangulate(n-gons only) after the bevel + materials
    floating_shells(modules, base) whole-house floating-part scan (the per-module gate cannot see these)
    gate_modules(modules, classes) lf.gate per module -> {name: (passed, fails, report)}
    export_modules(modules, dir)   one GLB per module + one combined GLB
    render_preview(modules, path)  Workbench three-quarter preview of the whole house
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

import lihfolk_bpy as lf
import lihfolk_curves as lc

hx_rgb = lc.hex_rgb


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def jitter(rng, c, a=0.04):
    return tuple(max(0.0, min(1.0, v * (1 + rng.uniform(-a, a)))) for v in c)


def by_normal(up, side, down=None, up_min=0.25, down_max=-0.3):
    """Colour function: faces pointing up get `up` (snow, moss, roof top), sides `side`, faces pointing down `down`.
    Fakes ambient occlusion in vertex colours so forms survive Roblox's flatter lighting."""
    down = down or side
    return lambda c, n, co: up if n.z > up_min else (side if n.z > down_max else down)


# ---------------------------------------------------------------- mesh builder (one closed shell per primitive)
class MeshBuilder:
    """Accumulates closed primitive shells with face-corner vertex colours ("Col", sRGB 0-1).
    colour arguments are an (r, g, b) tuple or a function f(face_centre, face_normal, vertex_co) -> rgb."""

    def __init__(self, name, rng=None):
        self.name = name
        self.rng = rng or random.Random(0)
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.parts = {}   # tag -> list of (lo, hi) bboxes, for seat / alignment checks

    def add(self, verts, faces, colfn, tag=None, fix=True):
        ctr = sum((Vector(v) for v in verts), Vector()) / len(verts)
        vs = [self.bm.verts.new(Vector(v)) for v in verts]
        for f in faces:
            face = self.bm.faces.new([vs[i] for i in f])
            face.normal_update()
            c = face.calc_center_median()
            nrm = face.normal.copy()
            if fix and (c - ctr).dot(nrm) < 0:   # convex primitive: outward = away from its centroid
                nrm = -nrm
            for lp in face.loops:
                col = colfn(c, nrm, lp.vert.co) if callable(colfn) else colfn
                lp[self.col] = (col[0], col[1], col[2], 1.0)
        if tag:
            lo = Vector([min(v[i] for v in verts) for i in range(3)])
            hi = Vector([max(v[i] for v in verts) for i in range(3)])
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
        """Oriented box: size in local axes, rotated by the 3x3 matrix M3."""
        c = Vector(centre); a, b, h = (s / 2 for s in size)
        loc = [(-a, -b, -h), (a, -b, -h), (a, b, -h), (-a, b, -h), (-a, -b, h), (a, -b, h), (a, b, h), (-a, b, h)]
        v = [c + M3 @ Vector(p) for p in loc]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add(v, f, col, tag)

    def cyl(self, p0, p1, r, n, side, cap_in=None, cap_out=None, phase=None, tag=None, r1=None):
        """Closed cylinder p0 -> p1 with fan caps around a centre vertex (no n-gons). Caps shade from cap_in
        (centre) to cap_out (rim): end grain on logs and firewood for zero texture cost."""
        p0, p1 = Vector(p0), Vector(p1)
        ax = (p1 - p0).normalized()
        u = ax.orthogonal().normalized(); w = ax.cross(u)
        ph = self.rng.uniform(0, math.pi) if phase is None else phase
        r1 = r if r1 is None else r1
        verts = []
        for p, rr in ((p0, r), (p1, r1)):
            for i in range(n):
                a = ph + 2 * math.pi * i / n
                verts.append(p + (u * math.cos(a) + w * math.sin(a)) * rr)
        verts += [p0, p1]
        c0, c1 = 2 * n, 2 * n + 1
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces += [(i, j, n + j, n + i), (c0, j, i), (c1, n + i, n + j)]
        cap_in = cap_in or side
        cap_out = cap_out or cap_in
        L = (p1 - p0).length

        def colfn(c, nrm, co):
            if abs(nrm.dot(ax)) > 0.9:
                ctr = p0 if (c - p0).dot(ax) < L / 2 else p1
                return mix(cap_in, cap_out, min(1.0, (co - ctr).length / max(r, 1e-6)))
            return side(c, nrm, co) if callable(side) else side
        self.add(verts, faces, colfn, tag)

    def cone(self, base, tip, r, n, col, tag=None):
        base, tip = Vector(base), Vector(tip)
        ax = (tip - base).normalized(); u = ax.orthogonal().normalized(); w = ax.cross(u)
        ph = self.rng.uniform(0, math.pi)
        verts = [base + (u * math.cos(ph + 2 * math.pi * i / n) + w * math.sin(ph + 2 * math.pi * i / n)) * r for i in range(n)]
        verts += [base, tip]
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces += [(n, j, i), (i, j, n + 1)]
        self.add(verts, faces, col, tag)

    def prism(self, a0, a1, b0, b1, apex0, apex1, col, tag=None):
        """Triangular prism from two triangles (a0, b0, apex0) and (a1, b1, apex1): gable caps, ridge caps."""
        v = [a0, b0, apex0, a1, b1, apex1]
        f = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
        self.add(v, f, col, tag)

    def ico(self, centre, scale, col, subdiv=1, tag=None):
        tbm = bmesh.new()
        bmesh.ops.create_icosphere(tbm, subdivisions=subdiv, radius=1.0)
        M = Matrix.Translation(centre) @ Matrix.Diagonal((*scale, 1))
        self.add_bm(tbm, M, col, tag)

    def outline_xz(self, outline, y0, y1, bevel, col, tag=None):
        """Slab from a closed 2D (x, z) outline extruded along Y (lc.extrude_outline: chamfered, ear-clipped caps)."""
        ob = lc.extrude_outline("_lh_tmp", outline, abs(y1 - y0), bevel=bevel, cls="hero")
        M = Matrix.Translation((0, (y0 + y1) / 2, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")
        tbm = bmesh.new(); tbm.from_mesh(ob.data)
        me = ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
        for l in list(tbm.loops.layers.uv):
            tbm.loops.layers.uv.remove(l)
        self.add_bm(tbm, M, col, tag)

    def to_object(self, collection=None):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me); self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        ca = me.color_attributes["Col"]
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
        return ob


def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# ---------------------------------------------------------------- house frame
class Gable:
    """Gable roof underside, ridge along Y. hx = eave wall centre line, eave_z = roof underside on that line."""

    def __init__(self, hx, eave_z, pitch_deg):
        self.hx, self.eave_z, self.pitch = hx, eave_z, pitch_deg
        self.T = math.tan(math.radians(pitch_deg))

    def under(self, x):
        return self.eave_z + (self.hx - abs(x)) * self.T

    @property
    def ridge_z(self):
        return self.under(0.0)

    def half_width_at(self, z_top, tuck=0.15):
        """Half-length of a gable-wall course whose top is z_top, so its ends stay tucked under the roof."""
        return self.hx - (z_top - self.eave_z) / self.T + tuck


class Face:
    """Outer face of a wall. key: "-Y" front gable, "+Y" back gable, "+X" / "-X" eave walls; plane = its coordinate.
    Local coordinates: u along the wall (left -> right seen from outside), z height, d outward from the face."""
    US = {"-Y": 1, "+Y": -1, "+X": 1, "-X": -1}

    def __init__(self, key, plane):
        self.key, self.plane = key, plane
        self.axis = key[1]
        self.sign = 1 if key[0] == "+" else -1
        self.us = self.US[key]
        self.out = Vector((0, self.sign, 0)) if self.axis == "Y" else Vector((self.sign, 0, 0))

    def p(self, u, z, d=0.0):
        a, n = self.us * u, self.plane + self.sign * d
        return Vector((a, n, z)) if self.axis == "Y" else Vector((n, a, z))

    def box(self, b, lo, hi, col, tag=None):
        """lo / hi = (u, z, d) corners in face coordinates."""
        p0, p1 = self.p(*lo), self.p(*hi)
        b.box(tuple(min(p0[i], p1[i]) for i in range(3)), tuple(max(p0[i], p1[i]) for i in range(3)), col, tag)

    def facing(self, n, thresh=0.5):
        return n.dot(self.out) > thresh


def house_faces(hx, hy, half_t):
    """Outer faces of a rectangular house whose wall centre lines are x = +-hx, y = +-hy; half_t = half wall thickness
    (log radius for log walls)."""
    return {"-Y": Face("-Y", -(hy + half_t)), "+Y": Face("+Y", hy + half_t),
            "-X": Face("-X", -(hx + half_t)), "+X": Face("+X", hx + half_t)}


def _subtract(spans, holes, min_len=0.0):
    """1-D spans [(a, b)] minus holes [(a, b)] -> remaining spans longer than min_len."""
    out = list(spans)
    for h0, h1 in holes:
        nxt = []
        for a, b in out:
            if h1 <= a or h0 >= b:
                nxt.append((a, b)); continue
            if h0 > a: nxt.append((a, h0))
            if h1 < b: nxt.append((h1, b))
        out = nxt
    return [(a, b) for a, b in out if b - a > min_len]


def _wall_axis_to_u(face, a, b):
    """World span along the wall axis -> span in face u."""
    u0, u1 = face.us * a, face.us * b
    return (min(u0, u1), max(u0, u1))


# ---------------------------------------------------------------- walls: round logs
def log_walls(b, hx, hy, *, radius=0.62, spacing=1.12, courses=11, overhang=1.05, pitch_deg=50.0,
              colours, end_in, end_out, sides=10, sill_radius=None, openings=None, min_gable=1.0, faces=None):
    """Stacked-log walls on centre lines x = +-hx (eave walls, along Y) and y = +-hy (gable walls, along X).
    - eave walls: `courses` logs, ends `overhang` past the corners (jittered);
    - gable walls offset half a course so logs interlock at the corners; bottom gable log is a thinner sill;
    - gable logs above the eave shorten under the roof (Gable.half_width_at) until shorter than 2*min_gable;
    - openings: {face_key: [(u0, u1, z0, z1)]}: logs crossing an opening are split there (real openings,
      interior-ready), and their cut ends get end grain.
    Returns (gable, faces): the Gable spec (eave = top of the last eave log) and house_faces for windows / doors."""
    rng = b.rng
    R, DZ = radius, spacing
    sill = sill_radius or R * 0.76
    eave_z = R + (courses - 1) * DZ + R
    g = Gable(hx, eave_z, pitch_deg)
    faces = faces or house_faces(hx, hy, R)
    openings = openings or {}

    def run(face, a, b_, z, r):
        holes = []
        for (u0, u1, z0, z1) in openings.get(face.key, []):
            ov = min(z + r, z1) - max(z - r, z0)
            if ov > 0.3 * r:
                holes.append((u0, u1))
        for u0, u1 in _subtract([_wall_axis_to_u(face, a, b_)], holes, min_len=0.6):
            w0, w1 = face.us * u0, face.us * u1
            if face.axis == "Y":      # gable wall, runs along X
                p0, p1 = (w0, face.plane - face.sign * R, z), (w1, face.plane - face.sign * R, z)
            else:
                p0, p1 = (face.plane - face.sign * R, w0, z), (face.plane - face.sign * R, w1, z)
            b.cyl(p0, p1, r * rng.uniform(0.96, 1.03), sides, jitter(rng, rng.choice(colours)), end_in, end_out, tag="log")

    for i in range(courses):
        z = R + i * DZ
        for key in ("-X", "+X"):
            e0, e1 = overhang + rng.uniform(-0.12, 0.12), overhang + rng.uniform(-0.12, 0.12)
            run(faces[key], -(hy + e0), hy + e1, z, R)
    for i in range(-1, courses - 1):
        z, r = (R + DZ / 2 + i * DZ, R) if i >= 0 else (sill, sill)
        for key in ("-Y", "+Y"):
            e0, e1 = overhang + rng.uniform(-0.12, 0.12), overhang + rng.uniform(-0.12, 0.12)
            run(faces[key], -(hx + e0), hx + e1, z, r)
    k = courses - 1
    while True:   # gable triangles
        z = R + DZ / 2 + k * DZ
        hw = g.half_width_at(z + R)
        if hw < min_gable:
            break
        for key in ("-Y", "+Y"):
            run(faces[key], -hw, hw, z, R * 0.97)
        k += 1
    return g, faces


# ---------------------------------------------------------------- walls: coursed stone / brick
def snap_openings(openings, z0, course_h):
    """Snap opening bottoms / tops to course lines, so lintels and sills sit on whole courses."""
    s = lambda z: z0 + round((z - z0) / course_h) * course_h
    return {k: [(u0, u1, s(a), s(c)) for (u0, u1, a, c) in v] for k, v in (openings or {}).items()}


def coursed_walls(b, hx, hy, *, thickness=1.2, z0=0.0, eave_z=10.0, course_h=1.25, block_len=(2.2, 3.6),
                  gap=0.08, colours, mortar, quoin=None, quoin_len=(1.9, 1.3), proud=0.06, gable=None,
                  openings=None, lintel_ext=0.55, min_gable=0.8, core_inset=0.12):
    """Coursed block walls (stone, brick, adobe blocks) on centre lines x = +-hx, y = +-hy.
    - every course is a dark core strip (shows as mortar in the joints) plus blocks with `gap` joints, staggered
      half a block on alternate courses;
    - corner bond: eave walls run through the corner on even courses, gable walls on odd courses; the end block
      of the through-running wall is a quoin (`quoin` colour, `quoin_len` long/short alternating, proud);
    - gable courses above the eave shorten under `gable` and stop below 2*min_gable. For block walls build the
      Gable on the OUTER face line, Gable(hx + thickness / 2, eave_z, pitch): a gable on the centre line lets the
      outer top edge of the eave walls poke through a thin roof (thickness / 2 * tan(pitch) studs);
    - openings {face_key: [(u0, u1, z0, z1)]} are snapped to course lines and cut through every course; the
      course on top of an opening gets one lintel block (quoin colour) `lintel_ext` past each side.
    The course height is stretched so a whole number of courses reaches eave_z exactly.
    Returns (faces, openings_snapped, course_h_used)."""
    rng = b.rng
    t = thickness
    n_eave = max(1, round((eave_z - z0) / course_h))
    ch = (eave_z - z0) / n_eave
    faces = house_faces(hx, hy, t / 2)
    ops = snap_openings(openings, z0, ch)
    quoin = quoin or colours[0]

    def course(face, a, b_, zc0, zc1, through):
        """One course of one wall between world coords a..b_ along the wall axis."""
        holes, lintels = [], []
        for (u0, u1, oz0, oz1) in ops.get(face.key, []):
            if min(zc1, oz1) - max(zc0, oz0) > 0.05:
                holes.append((u0, u1))
            elif abs(zc0 - oz1) < 0.05:
                lintels.append((u0 - lintel_ext, u1 + lintel_ext))
        span = _wall_axis_to_u(face, a, b_)
        # which u-ends are outer corners (quoins) on a through-running course
        corner_lo = corner_hi = through
        for s0, s1 in _subtract([span], holes, min_len=0.3):
            dlo, dhi = -t + core_inset, -core_inset      # d of the wall's inner and outer core faces
            ce = gap / 2 + 0.03       # core ends stop behind the end blocks, or a dark core square shows at corners
            face.box(b, (s0 + ce, zc0 + 0.001, dlo), (s1 - ce, zc1 - 0.001, dhi), mortar, tag="core")
            # pieces: lintels as single blocks, the rest filled with random blocks
            pieces = []
            cur = s0
            for l0, l1 in sorted(lintels):
                l0, l1 = max(l0, s0), min(l1, s1)
                if l1 - l0 < 0.5:
                    continue
                if l0 > cur:
                    pieces.append(("fill", cur, l0))
                pieces.append(("lintel", l0, l1)); cur = l1
            if cur < s1:
                pieces.append(("fill", cur, s1))
            for kind, p0, p1 in pieces:
                if kind == "lintel":
                    _block(face, p0, p1, zc0, zc1, quoin, proud * 1.5); continue
                cuts = [p0]
                x = p0
                at_lo = corner_lo and abs(p0 - span[0]) < 1e-6
                at_hi = corner_hi and abs(p1 - span[1]) < 1e-6
                lo_q = quoin_len[parity] if at_lo else None
                hi_q = quoin_len[parity] if at_hi else None
                end = p1 - (hi_q or 0)
                if lo_q:
                    x = p0 + lo_q; cuts.append(x)
                else:
                    first = rng.uniform(*block_len) * (0.5 if parity else 1.0)
                    if x + first < end - 0.4:
                        x += first; cuts.append(x)
                while x < end - 1e-6:
                    L = rng.uniform(*block_len)
                    if end - (x + L) < block_len[0] * 0.45:
                        L = end - x
                    x += L; cuts.append(min(x, end))
                if hi_q:
                    cuts.append(p1)
                for j in range(len(cuts) - 1):
                    c0, c1 = cuts[j], cuts[j + 1]
                    if c1 - c0 < 0.15:
                        continue
                    is_q = (j == 0 and lo_q) or (j == len(cuts) - 2 and hi_q)
                    col = quoin if is_q else jitter(rng, rng.choice(colours), 0.05)
                    _block(face, c0, c1, zc0, zc1, col, proud * (1.4 if is_q else rng.uniform(0.0, 1.0)))

    def _block(face, u0, u1, zc0, zc1, col, pr):
        face.box(b, (u0 + gap / 2, zc0 + gap / 2, -t), (u1 - gap / 2, zc1 - gap / 2, pr), col, tag="block")

    for k in range(n_eave):
        zc0, zc1 = z0 + k * ch, z0 + (k + 1) * ch
        parity = k % 2
        full_y, part_y = (-hy - t / 2, hy + t / 2), (-hy + t / 2, hy - t / 2)
        full_x, part_x = (-hx - t / 2, hx + t / 2), (-hx + t / 2, hx - t / 2)
        for key in ("-X", "+X"):
            course(faces[key], *(full_y if parity == 0 else part_y), zc0, zc1, parity == 0)
        for key in ("-Y", "+Y"):
            course(faces[key], *(part_x if parity == 0 else full_x), zc0, zc1, parity == 1)
    if gable is not None:
        k = n_eave
        while True:
            zc0, zc1 = z0 + k * ch, z0 + (k + 1) * ch
            parity = k % 2
            hw = gable.half_width_at(zc1, tuck=0.1)
            if hw < min_gable:
                break
            for key in ("-Y", "+Y"):
                course(faces[key], -hw, hw, zc0, zc1, False)
            k += 1
    return faces, ops, ch


# ---------------------------------------------------------------- roof
def gable_roof(b, gable, half_length, *, thickness=0.9, overhang_x=1.9, overhang_y=1.65, colour, underside=None,
               style="slab", rows=None, ridge=None, snow=None, bevel=0.1):
    """Gable roof over a Gable spec. Overhangs: overhang_x past the eave wall centre line, overhang_y past the gable
    wall centre lines (half_length = hy). style:
      "slab" one chevron slab (cabins, modern);
      "rows" a thinner slab plus shingle / tile rows: rows = dict(width=1.3, thick=0.22, tilt=4, colours=[...]);
    ridge = dict(colour=, width=, height=) adds a ridge cap prism;
    snow  = dict(thick=1.6, extra_x=0.65, extra_y=0.4, lip=0.45, radii=(0.5, 0.05, 0.5, 0.75, 1.1, 0.75),
                 colours=(top, side, under)) adds a rounded snow layer whose lip droops below the eave.
    Returns a dict: under(x), top(x), xe, ye, and snow_under(x) (the snow's lower surface, for seating icicles)."""
    xe, ye = gable.hx + overhang_x, half_length + overhang_y
    under = gable.under
    slab_t = thickness if style == "slab" else thickness * 0.55
    top = lambda x: under(x) + slab_t

    def chevron(xe_, z_off, thick, lip=0.0):
        zt = lambda x: under(x) + z_off
        return [(-xe_, zt(-xe_) - lip), (0, zt(0)), (xe_, zt(xe_) - lip),
                (xe_, zt(xe_) + thick), (0, zt(0) + thick), (-xe_, zt(-xe_) + thick)]

    under_col = underside or colour
    b.outline_xz(chevron(xe, 0.0, slab_t), -ye, ye, bevel, lambda c, n, co: colour if n.z > 0.3 else under_col, tag="roof")
    info = {"under": under, "top": top, "xe": xe, "ye": ye}
    if style == "rows":
        rw = rows.get("width", 1.3); rt = rows.get("thick", 0.22); tilt = math.radians(rows.get("tilt", 4))
        cols = rows.get("colours", [colour])
        p = math.radians(gable.pitch)
        S = xe / math.cos(p)                 # slope length ridge -> eave edge
        n_rows = max(1, math.ceil((S - rw * 0.25) / (rw * 0.75)))
        for side in (-1, 1):
            theta = side * (p - tilt)
            M3 = Matrix.Rotation(theta, 3, "Y")
            nrm = Vector((side * math.sin(p), 0, math.cos(p)))
            for k in range(n_rows):
                s = S - rw / 2 - k * rw * 0.75
                if s < rw * 0.35:
                    s = rw * 0.35
                x = side * s * math.cos(p)
                base = Vector((x, 0, top(x)))
                ctr = base + nrm * (rt / 2 - 0.04)
                L = 2 * ye + 0.1 + b.rng.uniform(-0.05, 0.05)
                b.obox(ctr, (rw, L, rt), M3, jitter(b.rng, b.rng.choice(cols), 0.04), tag="row")
        info["top"] = lambda x: top(x) + rt
    if ridge:
        w, h = ridge.get("width", 1.1), ridge.get("height", 0.55)
        z = info["top"](0) - 0.12
        zb = info["top"](w / 2) - 0.05          # seated on the slope at the cap's edges, not hovering
        y0, y1 = -ye - 0.05, ye + 0.05
        b.prism(Vector((-w / 2, y0, zb)), Vector((-w / 2, y1, zb)),
                Vector((w / 2, y0, zb)), Vector((w / 2, y1, zb)),
                Vector((0, y0, z + h)), Vector((0, y1, z + h)), ridge["colour"], tag="ridge")
    if snow:
        st = snow.get("thick", 1.6); ex = snow.get("extra_x", 0.65); ey = snow.get("extra_y", 0.4)
        lip = snow.get("lip", 0.45)
        radii = list(snow.get("radii", (0.5, 0.05, 0.5, 0.75, 1.1, 0.75)))
        xs = xe + ex
        z_off = info["top"](0) - under(0) - 0.02
        sn = lc.round_corners(chevron(xs, z_off, st, lip=lip), radii, mode="arc", closed=True, max_step_deg=30)
        top_c, side_c, und_c = snow.get("colours", (hx_rgb("#F4F7FC"), hx_rgb("#DCE6F4"), hx_rgb("#C9D6E8")))
        b.outline_xz([(p[0], p[1]) for p in sn], -(ye + ey), ye + ey, 0.35, by_normal(top_c, side_c, und_c), tag="snow")
        info["snow_under"] = lambda x: under(x) + z_off - lip * abs(x) / xs
        info["snow_xe"], info["snow_ye"] = xs, ye + ey
    return info


def icicle_row(b, p0, p1, count, *, colour, lengths=(0.7, 1.0, 1.3, 1.7, 2.1), scale=(0.8, 1.15),
               radius=(0.2, 0.28), embed=0.45, sides=5, skip=None, z_at=None):
    """Icicles hung along p0 -> p1. Seat them from the geometry: pass z_at(x, y) (e.g. roof['snow_under'] evaluated
    just inside the lip) and each cone top is embedded `embed` studs into it. Lengths come from a short list, which
    gives the long/short rhythm of real eaves."""
    p0, p1 = Vector(p0), Vector(p1)
    for i in range(count):
        t = (i + 0.5 + b.rng.uniform(-0.3, 0.3)) / count
        p = p0.lerp(p1, t)
        if skip and skip(p):
            continue
        z = z_at(p.x, p.y) if z_at else p.z
        L = b.rng.choice(lengths) * b.rng.uniform(*scale)
        b.cone((p.x, p.y, z + embed), (p.x, p.y, z - L), b.rng.uniform(*radius), sides, colour, tag="icicle")


# ---------------------------------------------------------------- chimney, foundation, deck
def chimney(b, x, y, z0, z1, *, size=2.4, course_h=0.62, colours, crown=None, flue=None, cap_snow=None):
    """Coursed chimney stack (alternate courses +-0.04 for a hand-built edge) from z0 (start it inside the roof:
    z0 below roof under(x)) to z1, with a crown slab, optional snow cap and a flue. Returns the top z."""
    z, i = z0, 0
    while z < z1 - 1e-6:
        h = min(course_h, z1 - z)
        s = size + (0.06 if i % 2 else -0.02)
        b.box((x - s / 2, y - s / 2, z), (x + s / 2, y + s / 2, z + h + 0.03), jitter(b.rng, colours[i % len(colours)], 0.05), tag="course")
        z += h; i += 1
    c = size / 2 + 0.35
    b.box((x - c, y - c, z), (x + c, y + c, z + 0.45), crown or colours[0], tag="crown")
    top = z + 0.45
    if cap_snow:
        b.box((x - c + 0.1, y - c + 0.1, z + 0.4), (x + c - 0.1, y + c - 0.1, z + 0.95), by_normal(*cap_snow[:2], up_min=0.3), tag="snowcap")
        top = z + 0.95
    if flue:
        f = size * 0.23
        b.box((x - f, y - f, top - 0.25), (x + f, y + f, top + 0.6), flue, tag="flue")
        top += 0.6
    return top


def foundation(b, hx, hy, half_t, *, height=0.6, margin=0.3, colour):
    """Plinth slab under the walls (walls then start at z0 = height). Grounds the house on uneven terrain too:
    sink it in Studio rather than leaving a gap."""
    e = half_t + margin
    b.box((-hx - e, -hy - e, 0.0), (hx + e, hy + e, height), colour, tag="foundation")
    return height


def plank_deck(b, x0, x1, y0, y1, z_top, *, planks=6, along="Y", colours, z_bottom=0.0, snow_edge=None):
    """Plank deck / floor: `planks` boards running `along`, 0.06 gaps, small jitter. snow_edge colours the top of
    the outermost board."""
    span = (x1 - x0) if along == "Y" else (y1 - y0)
    pw = span / planks
    for i in range(planks):
        col = jitter(b.rng, b.rng.choice(colours))
        top_col = (lambda c, n, co, col=col: snow_edge if n.z > 0.5 else col) if (snow_edge and i == planks - 1) else col
        j = b.rng.uniform(-0.05, 0.05); h = z_top + b.rng.uniform(-0.02, 0.02)
        if along == "Y":
            b.box((x0 + i * pw + 0.03, y0 + j, z_bottom), (x0 + (i + 1) * pw - 0.03, y1 + j, h), top_col, tag="deck")
        else:
            b.box((x0 + j, y0 + i * pw + 0.03, z_bottom), (x1 + j, y0 + (i + 1) * pw - 0.03, h), top_col, tag="deck")


# ---------------------------------------------------------------- openings: windows, doors, steps
def window(trim, glow, face, u, zc, w, h, *, recess=0.0, frame=0.34, proud=0.36, colours, shutters=None,
           cap=None, sill=True, sill_top=None, mullions=True):
    """Window centred at (u, zc) on `face`, w x h glass. recess = how far the glass sits behind the face (0 for an
    overlay on logs; about half the wall thickness for a real opening). colours: dict(frame=, mullion=, glass=).
    shutters: (colour_a, colour_b) or None; cap: dict(top=, front=, under=) gable cap with a snow / moss top, or None.
    Glass goes in the `glow` builder (its own module: Neon in Studio); everything else in `trim`."""
    F, M, G = colours["frame"], colours.get("mullion", colours["frame"]), colours["glass"]
    fb = frame
    di = -(recess + 0.12)
    face.box(glow, (u - w / 2 - 0.05, zc - h / 2 - 0.05, -recess - 0.10), (u + w / 2 + 0.05, zc + h / 2 + 0.05, -recess + 0.10), G, tag="glass")
    face.box(trim, (u - w / 2 - fb, zc - h / 2 - fb, di), (u + w / 2 + fb, zc - h / 2 + 0.01, proud), F, tag="frame")
    face.box(trim, (u - w / 2 - fb + 0.01, zc + h / 2, di - 0.01), (u + w / 2 + fb - 0.01, zc + h / 2 + fb, proud + 0.01), F, tag="frame")
    face.box(trim, (u - w / 2 - fb + 0.02, zc - h / 2 + 0.03, di + 0.01), (u - w / 2, zc + h / 2 + 0.02, proud - 0.01), F, tag="frame")
    face.box(trim, (u + w / 2, zc - h / 2 + 0.03, di + 0.01), (u + w / 2 + fb - 0.02, zc + h / 2 + 0.02, proud - 0.01), F, tag="frame")
    if mullions:
        face.box(trim, (u - 0.09, zc - h / 2 - 0.12, -recess + 0.05), (u + 0.09, zc + h / 2 + 0.12, proud - 0.06), M, tag="mullion")
        face.box(trim, (u - w / 2 - 0.12, zc + h * 0.12 - 0.08, -recess + 0.07), (u + w / 2 + 0.12, zc + h * 0.12 + 0.08, proud - 0.08), M, tag="mullion")
    if sill:
        top = sill_top or F
        face.box(trim, (u - w / 2 - 0.6, zc - h / 2 - fb - 0.28, di + 0.03), (u + w / 2 + 0.6, zc - h / 2 - fb + 0.02, proud + 0.26),
                 lambda c, n, co: top if n.z > 0.5 else F, tag="sill")
    if shutters:
        sw = w * 0.5
        for s in (-1, 1):
            x0 = u + s * (w / 2 + fb + 0.08); x1 = x0 + s * sw
            a, bb = min(x0, x1), max(x0, x1); mid = (a + bb) / 2
            face.box(trim, (a, zc - h / 2 - 0.15, di), (mid - 0.03, zc + h / 2 + 0.15, 0.32), shutters[0], tag="shutter")
            face.box(trim, (mid + 0.03, zc - h / 2 - 0.14, di + 0.01), (bb, zc + h / 2 + 0.16, 0.30), shutters[1], tag="shutter")
            # battens: keep every part at least 3x the bevel width thick (0.12-thick battens with a 0.06 bevel
            # collapsed into 16 degenerate faces = gate A5 in the log test)
            face.box(trim, (a + 0.05, zc - h / 2 + 0.35, 0.29), (bb - 0.05, zc - h / 2 + 0.6, 0.47), shutters[1], tag="shutter")
            face.box(trim, (a + 0.05, zc + h / 2 - 0.6, 0.28), (bb - 0.05, zc + h / 2 - 0.35, 0.47), shutters[1], tag="shutter")
    if cap:
        zb, cw, chh = zc + h / 2 + fb - 0.02, w + 1.3, 1.05
        out = face.out
        col = lambda c, n, co: cap["top"] if n.z > 0.3 else (cap["front"] if n.dot(out) > 0.5 else cap["under"])
        a0, a1 = face.p(u - cw / 2, zb, di), face.p(u - cw / 2, zb, 0.7)
        b0, b1 = face.p(u + cw / 2, zb, di), face.p(u + cw / 2, zb, 0.7)
        t0, t1 = face.p(u, zb + chh, di), face.p(u, zb + chh, 0.7)
        trim.prism(a0, a1, b0, b1, t0, t1, col, tag="cap")


def door(b, face, u, z0, w, h, *, recess=0.2, planks=4, colours, batten, frame, knob, frame_w=0.45, proud=0.32):
    """Plank door (vertical boards, two battens, frame, knob) with its bottom at z0 (threshold / floor level).
    recess = how far the boards sit behind the face. Size it from the avatar: 3.5-4 x 7-8 studs for R15."""
    for i in range(planks):
        a = u - w / 2 + i * w / planks
        face.box(b, (a + 0.02, z0 + 0.01, -recess - 0.2), (a + w / planks - 0.02, z0 + h, -recess + 0.12 + b.rng.uniform(0, 0.03)),
                 jitter(b.rng, colours[i % len(colours)], 0.05), tag="door")
    for zz in (z0 + 1.4, z0 + h - 1.6):
        face.box(b, (u - w / 2 + 0.25, zz, -recess + 0.1), (u + w / 2 - 0.25, zz + 0.4, -recess + 0.28), batten, tag="door")
    face.box(b, (u - w / 2 - frame_w, z0 - 0.03, -recess - 0.1), (u - w / 2 + 0.01, z0 + h + frame_w, proud), frame, tag="doorframe")
    face.box(b, (u + w / 2 - 0.01, z0 - 0.02, -recess - 0.1), (u + w / 2 + frame_w, z0 + h + frame_w + 0.01, proud + 0.01), frame, tag="doorframe")
    face.box(b, (u - w / 2 - frame_w - 0.15, z0 + h - 0.02, -recess - 0.11), (u + w / 2 + frame_w + 0.15, z0 + h + frame_w + 0.05, proud + 0.04), frame, tag="doorframe")
    kp0 = face.p(u + w / 2 - 0.55, z0 + h * 0.48, -recess + 0.08)
    kp1 = face.p(u + w / 2 - 0.55, z0 + h * 0.48, -recess + 0.55)
    b.cyl(kp0, kp1, 0.13, 6, knob, knob, knob, tag="knob")


def steps(b, face, u, width, z_top, *, n=2, run=1.0, z_ground=0.0, colours):
    """n steps down from a threshold at z_top to z_ground, in front of `face` at u. Each step is a solid block to the
    ground (no floating treads); rise = (z_top - z_ground) / (n + 1)."""
    for k in range(n):
        top = z_ground + (z_top - z_ground) * (n - k) / (n + 1)
        wk = width / 2 + 0.05 * k
        face.box(b, (u - wk, z_ground, -0.1 + k * run), (u + wk, top, (k + 1) * run), jitter(b.rng, colours[k % len(colours)]), tag="step")


def opening_footprint(w, frame=0.34, shutters=False, shutter_gap=0.08):
    """Half-width a window or door really takes on the wall: glass + frame (+ two shutters of w/2)."""
    return w / 2 + frame + ((shutter_gap + w / 2) if shutters else 0.0)


def check_wall_layout(face_len, items, end_clear=1.0, min_pier=0.6):
    """Plan openings before building: items = [(name, u_centre, half_footprint)] on a wall whose outer length is
    face_len (centred on u = 0). Fails when a footprint (frame and shutters included) passes the wall end minus
    end_clear (quoin / corner logs) or two footprints leave less than min_pier of wall between them.
    The cottage test's first layout put a shutter 0.7 studs past the corner; this catches it before modelling."""
    probs = []
    lim = face_len / 2 - end_clear
    its = sorted(items, key=lambda it: it[1])
    for name, u, hw in its:
        if u - hw < -lim or u + hw > lim:
            probs.append(f"{name}: footprint {u - hw:.2f}..{u + hw:.2f} passes the wall end (+-{lim:.2f})")
    for (n0, u0, h0), (n1, u1, h1) in zip(its, its[1:]):
        if (u1 - h1) - (u0 + h0) < min_pier:
            probs.append(f"{n0} / {n1}: only {(u1 - h1) - (u0 + h0):.2f} studs of wall between them")
    return probs


# ---------------------------------------------------------------- pipeline helpers
def recentre(modules):
    """One shared origin for every module: the bottom centre of the WHOLE house at (0, 0, 0). Imported together, the
    modules land on each other with no hand placement. Returns the shift applied to the geometry."""
    bpy.context.view_layer.update()
    pts = [m.matrix_world @ v.co for m in modules for v in m.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for m in modules:
        m.data.transform(Matrix.Translation(shift))
    return shift


def glow_material(ob, rgb=(1.0, 0.5, 0.14), strength=9.0, name="LF_Glow"):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = mat.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Emission Color"].default_value = (*rgb, 1)
    bs.inputs["Emission Strength"].default_value = strength
    ob.data.materials.clear(); ob.data.materials.append(mat)
    return mat


def finish_modules(modules, finish, glow=()):
    """finish = {name: dict(style=, bevel_width=, smooth_angle=)}. After a "soft" bevel, a Triangulate modifier with
    min_vertices=5 cuts only the n-gons the bevel makes on fan caps and box corners (gate A4) and keeps custom
    normals. Keep bevel_width <= 1/3 of the thinnest part in the module (thinner parts collapse into degenerate
    faces, gate A5). Modules named in `glow` get an emissive material, the rest the vertex-colour material. Origins go to
    the shared (0, 0, 0)."""
    for m in modules:
        kw = dict(finish.get(m.name, {"style": "soft", "bevel_width": 0.05, "smooth_angle": 60}))
        lf.finish(m, **kw)
        if kw.get("style") == "soft":
            tri = m.modifiers.new("LF_TriNgons", "TRIANGULATE"); tri.min_vertices = 5
            tri.keep_custom_normals = True
            m.modifiers.move(len(m.modifiers) - 1, 1)   # directly after the bevel
        if m.name in glow:
            glow_material(m)
        else:
            lc.vertex_color_material(m)
        lf.set_origin(m, "point", at=(0, 0, 0))


def _shells(bm):
    parent = list(range(len(bm.verts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for e in bm.edges:
        a, c = find(e.verts[0].index), find(e.verts[1].index)
        if a != c:
            parent[a] = c
    groups = {}
    for f in bm.faces:
        groups.setdefault(find(f.verts[0].index), []).append(f.index)
    return list(groups.values())


def floating_shells(modules, base_names=(), tol=0.02, ground_z=None):
    """Whole-house floating-part scan. Joins the evaluated meshes of every module (world space), splits them into
    shells, links shells that touch or overlap (BVH overlap, or a vertex within `tol` of the other surface), and
    flood-fills from the base: shells of modules in base_names plus any shell touching the ground plane (lowest z).
    A shell not reached floats: an icicle under the lip, a door knob off the door, a log in the air.
    Returns {"shells", "floating", "examples": [(module, centre)]}."""
    bm = bmesh.new()
    owner = []
    dg = bpy.context.evaluated_depsgraph_get()
    for m in modules:
        eo = m.evaluated_get(dg); me = eo.to_mesh()
        tmp = bmesh.new(); tmp.from_mesh(me); eo.to_mesh_clear()
        tmp.transform(m.matrix_world)
        n0 = len(bm.faces)
        me2 = bpy.data.meshes.new("_lh_scan"); tmp.to_mesh(me2); tmp.free()
        bm.from_mesh(me2); bpy.data.meshes.remove(me2)
        owner += [m.name] * (len(bm.faces) - n0)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table(); bm.verts.index_update(); bm.faces.index_update()
    shells = _shells(bm)
    if ground_z is None:
        ground_z = min(v.co.z for v in bm.verts)
    info = []
    for s in shells:
        vs = {v for fi in s for v in bm.faces[fi].verts}
        cos = [v.co.copy() for v in vs]
        lo = Vector([min(c[i] for c in cos) for i in range(3)]); hi = Vector([max(c[i] for c in cos) for i in range(3)])
        tris = []
        vmap = {}
        verts = []
        for fi in s:
            idx = []
            for v in bm.faces[fi].verts:
                if v.index not in vmap:
                    vmap[v.index] = len(verts); verts.append(v.co.copy())
                idx.append(vmap[v.index])
            tris.append(idx)
        info.append({"lo": lo, "hi": hi, "verts": verts, "bvh": BVHTree.FromPolygons(verts, tris),
                     "owner": owner[s[0]]})
    n = len(info)
    adj = [[] for _ in range(n)]
    order = sorted(range(n), key=lambda i: info[i]["lo"].x)
    for ai, a in enumerate(order):
        A = info[a]
        for b_ in order[ai + 1:]:
            B = info[b_]
            if B["lo"].x > A["hi"].x + tol:
                break
            if any(B["lo"][k] > A["hi"][k] + tol or A["lo"][k] > B["hi"][k] + tol for k in (1, 2)):
                continue
            touch = bool(A["bvh"].overlap(B["bvh"]))
            if not touch:
                small, big = (A, B) if len(A["verts"]) < len(B["verts"]) else (B, A)
                touch = any(big["bvh"].find_nearest(p, tol)[0] is not None for p in small["verts"])
                if not touch:
                    touch = any(small["bvh"].find_nearest(p, tol)[0] is not None for p in big["verts"])
            if touch:
                adj[a].append(b_); adj[b_].append(a)
    seen = set(i for i in range(n) if info[i]["owner"] in base_names or info[i]["lo"].z <= ground_z + tol)
    stack = list(seen)
    while stack:
        i = stack.pop()
        for j in adj[i]:
            if j not in seen:
                seen.add(j); stack.append(j)
    floating = [i for i in range(n) if i not in seen]
    bm.free()
    return {"shells": n, "floating": len(floating),
            "examples": [(info[i]["owner"], [round(c, 2) for c in (info[i]["lo"] + info[i]["hi"]) / 2]) for i in floating[:12]]}


def gate_modules(modules, classes, **gate_kw):
    """lf.gate on every module with its budget class: {name: (passed, fails, report)}."""
    return {m.name: lf.gate(m, classes.get(m.name, "medium"), **gate_kw) for m in modules}


def export_modules(modules, out_dir, combined=None):
    """One GLB per module (lf.export_glb) plus, if `combined` is a name, one GLB holding every module (same settings:
    modifiers applied, vertex colours ACTIVE, 1 unit = 1 stud)."""
    os.makedirs(out_dir, exist_ok=True)
    paths = {m.name: lf.export_glb(m, os.path.join(out_dir, m.name + ".glb")) for m in modules}
    if combined:
        bpy.ops.object.select_all(action="DESELECT")
        for m in modules:
            m.select_set(True)
        bpy.context.view_layer.objects.active = modules[0]
        path = os.path.join(out_dir, combined + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_normals=True, export_vertex_color="ACTIVE",
                                  export_draco_mesh_compression_enable=False)
        paths[combined] = path
    return paths


def render_preview(modules, path, size=(1280, 900), direction=(1.0, -1.25, 0.65), lens=50, margin=1.25):
    """Workbench three-quarter preview of the whole house, vertex colours, Standard view transform (shows the exact
    hexes Roblox shows). Other mesh objects are hidden while rendering."""
    s = bpy.context.scene
    prev = (s.render.engine, s.camera, s.render.resolution_x, s.render.resolution_y, s.render.filepath,
            s.view_settings.view_transform)
    others = [o for o in s.objects if o not in modules and o.type in {"MESH", "CURVE"} and not o.hide_render]
    for o in others:
        o.hide_render = True
    bpy.context.view_layer.update()
    pts = [m.matrix_world @ Vector(c) for m in modules for c in m.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    ctr = (lo + hi) / 2; rad = (hi - lo).length / 2
    cd = bpy.data.cameras.new("LH_PreviewCam"); cd.lens = lens
    cam = bpy.data.objects.new("LH_PreviewCam", cd); s.collection.objects.link(cam); s.camera = cam
    d = Vector(direction).normalized()
    fov = 2 * math.atan(18 / lens)
    cam.location = ctr + d * (rad * margin / math.tan(fov / 2))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    sh = s.display.shading
    try:
        s.render.engine = "BLENDER_WORKBENCH"
        s.render.resolution_x, s.render.resolution_y = size
        s.view_settings.view_transform = "Standard"
        sh.light = "STUDIO"; sh.color_type = "VERTEX"; sh.show_cavity = True; sh.show_object_outline = True
        if s.world is None:
            s.world = bpy.data.worlds.new("LH_World")
        s.world.color = (0.62, 0.7, 0.8)
        s.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        bpy.data.objects.remove(cam, do_unlink=True)
        for o in others:
            o.hide_render = False
        (s.render.engine, s.camera, s.render.resolution_x, s.render.resolution_y, s.render.filepath,
         s.view_settings.view_transform) = prev
    return path
