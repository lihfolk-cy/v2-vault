"""LihFolk stylised creature builder (Blender 5.2, headless or Blender MCP).

A small JSON spec -> one soft, fused, mirrored creature with a hand-painted look baked into ONE texture,
a light bone rig with automatic weights and a looping idle/swim action, exported as a Roblox-ready GLB.

    import sys; sys.path.append(r"<plugin>/skills/roblox-blender-modeling/scripts")
    import lihfolk_creature as lcr
    stats = lcr.build_creature(spec_dict, out_dir)          # everything, returns the stats dict
Headless (spec as a JSON file):
    blender -b --factory-startup --python lihfolk_creature.py -- spec.json <out_dir> [--blend file.blend] [--no-render]

Pipeline (each step is also a public function):
    field = lcr.Field(spec)                SDF of the body: lofted cross-sections, round cones, ellipsoids, flat fins,
                                           smooth-unioned (blend k per part); parts with x > 0 are mirrored (|x|)
    body  = lcr.build_body(spec, field)    surface nets -> voxel remesh -> QuadriFlow (quad-ish) to the tri budget
                                           -> keep +X half, project onto the SDF + tangential relax -> mirror
    eyes  = lcr.build_eyes(spec, field)    separate glossy lens shells seated into the head (exact mirror)
    ob    = lcr.join_creature(...)         one object, one material, per-vertex tags (fin, fin_t, lip, eye, eyeloc)
    lcr.unwrap(ob); lcr.bake_paint(ob, spec, out_dir)   Cycles EMIT bake of the procedural "paint" (gradient,
                                           counter-shaded belly, AO creases, warm top light, bounce rim, spots,
                                           blush, stroke noise, painted highlights, glossy eyes) -> colour + roughness
    arm   = lcr.build_rig(spec, ob)        spine/tail chain + appendage chains, auto weights, <= 4 influences
    lcr.swim_action(spec, arm)             looping idle/swim (sine with a phase offset along the chain)
    lcr.export_creature(ob, arm, out_dir)  GLB (+Y up, 1 unit = 1 stud, Armature + action) and an FBX copy
    lcr.preview(...)                       atmospheric hero + turntable strip, neutral views, silhouettes, close-ups,
                                           wireframe and animation strips for the blind review
Conventions follow lihfolk_bpy: 1 Blender unit = 1 stud, creature faces -Y (Roblox -Z), left = +X, origin at the
body centre (the Root bone sits on it), the lf.gate() quality gate with symmetric="X" before rigging.
"""
import bpy, bmesh, math, os, sys, json, time
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lihfolk_bpy as lf

# ======================================================================= defaults
DEFAULTS = {
    "tris": 3200,           # whole creature incl. eyes; "quad_boost" (default 1.15) scales the QuadriFlow target (class "creature" target 5,000, style target 2-4k)
    "texture": 1024,
    "grid": 0.025,          # SDF sampling step (studs); finest feature (fin half-thickness) >= 2 steps
    "relax": 2,
    "normals": "weighted",  # "weighted" (Weighted Normal, face-area) | "sdf" (analytic SDF gradient)
    "eye_segments": [24, 12],
    "bake_samples": 64,
    "palette": {
        "main_front": "#FFB347", "main_back": "#FF7A3D", "belly": "#FFF0D2", "warm": "#FFE08A",
        "rim": "#BFF3EE", "spot": "#C9502B", "blush": "#FF7F8E", "fin_root": "#FF9E5E", "fin_tip": "#E8553A",
        "lip": "#FF8A80", "fin_ray": "#C8402E", "fin_edge": "#FFD9B0", "ao": "#C0603A", "highlight": "#FFF7DD",
        "eye_dark": "#151A3A", "eye_light": "#2F6E9E", "eye_glint": "#FFFFFF",
    },
    "paint": {
        "belly_line": -0.15, "belly_soft": 0.28, "warm_amt": 0.35, "rim_amt": 0.35, "ao_amt": 0.55, "bands": 0.35, "ao_dist": 0.45,
        "spot_scale": 3.2, "spot_r": [0.10, 0.17], "spot_amt": 0.85, "stroke_amt": 0.10, "stroke_scale": [7.0, 2.2, 7.0],
        "cheek": None, "cheek_r": 0.32, "fin_rays": 3.0, "ray_amt": 0.35, "fin_edge_amt": 0.7, "highlights": [],   # [[x, y, z, rx, ry, rz, amount], ...]
        "rough_body": 0.55, "rough_fin": 0.45, "rough_lip": 0.4, "rough_eye": 0.06,
    },
    "anim": {"frames": 60, "fps": 30, "step": 2, "beats": 2, "phase_step": 1.6, "tail_amp": 40.0, "head_amp": 7.0, "accent": 0.35, "pec_offset": 0.6,
             "fin_amp": 34.0, "fin_twist": 10.0, "fin_lag": 1.0, "skew": 0.55, "bob": 0.14, "pitch": 6.0, "roll": 7.0,
             "surge": 0.05},
}


def _merge(spec):
    s = json.loads(json.dumps(DEFAULTS))
    for k, v in spec.items():
        if isinstance(v, dict) and isinstance(s.get(k), dict):
            s[k].update(v)
        else:
            s[k] = v
    return s


def hex_rgb(h, linear=True):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    if linear:
        c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return c


# ======================================================================= SDF primitives (numpy, N x 3)
def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def round_cone(P, a, b, r1, r2):
    """Exact SDF of a cone with spherical caps (tapered capsule)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a; l2 = ba.dot(ba); rr = r1 - r2; a2 = l2 - rr * rr; il2 = 1.0 / l2
    pa = P - a; y = pa @ ba; z = y - l2
    xv = pa * l2 - y[:, None] * ba; x2 = np.einsum("ij,ij->i", xv, xv)
    y2 = y * y * l2; z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
    d = np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - r1, d)
    d = np.where(np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - r2, d)
    return d


def ellipsoid(P, c, r):
    q = P - np.asarray(c, float); r = np.asarray(r, float)
    k0 = np.linalg.norm(q / r, axis=1); k1 = np.linalg.norm(q / (r * r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def _pchip(x, xs, ys):
    """Monotone cubic interpolation (no overshoot between stations)."""
    xs = np.asarray(xs, float); ys = np.asarray(ys, float)
    if len(xs) < 3:
        return np.interp(x, xs, ys)
    hk = np.diff(xs); dk = np.diff(ys) / hk
    m = np.zeros_like(ys)
    for i in range(1, len(xs) - 1):
        if dk[i - 1] * dk[i] > 0:
            w1, w2 = 2 * hk[i] + hk[i - 1], hk[i] + 2 * hk[i - 1]
            m[i] = (w1 + w2) / (w1 / dk[i - 1] + w2 / dk[i])
    m[0], m[-1] = dk[0], dk[-1]
    i = np.clip(np.searchsorted(xs, x) - 1, 0, len(xs) - 2)
    t = (x - xs[i]) / hk[i]
    h00 = (1 + 2 * t) * (1 - t) ** 2; h10 = t * (1 - t) ** 2; h01 = t * t * (3 - 2 * t); h11 = t * t * (t - 1)
    return h00 * ys[i] + h10 * hk[i] * m[i] + h01 * ys[i + 1] + h11 * hk[i] * m[i + 1]


def loft(P, stations, caps=(0.3, 0.3)):
    """Lofted elliptical cross-sections along Y. stations: [[y, half_width, half_height, z_centre], ...] sorted by y
    (front = smallest y, the creature faces -Y). caps: ellipsoidal dome lengths beyond the first / last station."""
    st = np.asarray(stations, float)
    ys = st[:, 0]; y = P[:, 1]
    yc = np.clip(y, ys[0], ys[-1])
    a = _pchip(yc, ys, st[:, 1]); b = _pchip(yc, ys, st[:, 2]); zc = _pchip(yc, ys, st[:, 3])
    cf, cb = caps
    of = np.maximum(ys[0] - y, 0); ob = np.maximum(y - ys[-1], 0)
    s = np.ones_like(y)
    if cf > 0:
        s = np.where(of > 0, np.sqrt(np.clip(1 - (of / cf) ** 2, 0, 1)), s)
    if cb > 0:
        s = np.where(ob > 0, np.minimum(s, np.sqrt(np.clip(1 - (ob / cb) ** 2, 0, 1))), s)
    a = np.maximum(a * s, 1e-3); b = np.maximum(b * s, 1e-3)
    x = P[:, 0]; z = P[:, 2] - zc
    k0 = np.sqrt((x / a) ** 2 + (z / b) ** 2); k1 = np.sqrt((x / a ** 2) ** 2 + (z / b ** 2) ** 2)
    d = k0 * (k0 - 1) / np.maximum(k1, 1e-9)
    # beyond the domes: distance to the dome tip
    tipf = of - cf; tipb = ob - cb
    d = np.where(tipf > 0, np.sqrt(x ** 2 + z ** 2 + tipf ** 2), d)
    d = np.where(tipb > 0, np.sqrt(x ** 2 + z ** 2 + tipb ** 2), d)
    return d


def _fin_frame(part):
    root = np.asarray(part["root"], float); tip = np.asarray(part["tip"], float)
    u = tip - root; L = float(np.linalg.norm(u)); u = u / L
    n = np.asarray(part.get("normal", [1, 0, 0]), float)
    w = n - u * n.dot(u); w = w / np.linalg.norm(w)
    v = np.cross(w, u)
    return root, u, v, w, L


def fin(P, part):
    """Flat rounded fin / flipper / paddle: a tapered 2-D capsule (root radius -> tip radius) in the fin plane,
    extruded to a half-thickness that tapers root -> tip, with fully rounded (bead) edges. `bend` curls the
    plane (studs of offset at the tip along the plane normal)."""
    root, u, v, w, L = _fin_frame(part)
    q = P - root
    lu, lv, lw = q @ u, q @ v, q @ w
    s = np.clip(lu / L, 0, 1)
    lw = lw - part.get("bend", 0.0) * s * s
    r1, r2 = part["r"]; t1, t2 = part.get("t", [0.08, 0.05])
    d2 = round_cone(np.column_stack([lu, lv, np.zeros_like(lu)]), [0, 0, 0], [L, 0, 0], r1, r2)
    tt = t1 + (t2 - t1) * s
    rr = tt * 0.95
    dd = d2 + rr; ww = np.abs(lw) - (tt - rr)
    return np.minimum(np.maximum(dd, ww), 0) + np.sqrt(np.maximum(dd, 0) ** 2 + np.maximum(ww, 0) ** 2) - rr


class Field:
    """Signed distance field of the creature from spec["parts"] (in order, each smooth-unioned with blend k into
    what came before; op "subtract" carves). Every part is evaluated at |x|, so the field is an exact X mirror:
    author right-half parts (x > 0) once and they appear on both sides."""

    def __init__(self, spec):
        self.parts = spec["parts"]

    def part_d(self, P, part):
        t = part["type"]
        if t == "loft":
            return loft(P, part["stations"], part.get("caps", (0.3, 0.3)))
        if t == "cone":
            return round_cone(P, part["a"], part["b"], part["r"][0], part["r"][1])
        if t == "ellipsoid":
            return ellipsoid(P, part["c"], part["r"])
        if t == "fin":
            return fin(P, part)
        raise ValueError("unknown part type " + t)

    def __call__(self, P, parts=False):
        P = np.asarray(P, float).copy(); P[:, 0] = np.abs(P[:, 0])
        d = None; ds = {}
        for part in self.parts:
            dp = self.part_d(P, part); ds[part["name"]] = dp
            k = part.get("k", 0.1)
            if d is None:
                d = dp
            elif part.get("op") == "subtract":
                d = smax(d, -dp, k)
            else:
                d = smin(d, dp, k)
        return (d, ds) if parts else d

    def grad(self, P, e=1e-4):
        g = np.zeros_like(P)
        for i in range(3):
            o = np.zeros(3); o[i] = e
            g[:, i] = (self(P + o) - self(P - o)) / (2 * e)
        return g

    def project(self, P, iters=4):
        P = np.asarray(P, float).copy()
        for _ in range(iters):
            d = self(P); g = self.grad(P)
            P -= (d / np.maximum((g * g).sum(1), 1e-9))[:, None] * g
        return P

    def raymarch(self, o, dirn, tmax=6.0):
        o = np.asarray(o, float); dirn = np.asarray(dirn, float); dirn = dirn / np.linalg.norm(dirn); t = 0.0
        for _ in range(600):
            d = self((o + dirn * t)[None])[0]
            if d < 1e-5:
                return self.project((o + dirn * t)[None], 6)[0]
            t += max(d * 0.7, 1e-4)
            if t > tmax:
                return None
        return None

    def bounds(self, pad=0.1):
        lo = np.full(3, 1e9); hi = np.full(3, -1e9)
        for p in self.parts:
            if p.get("op") == "subtract":
                continue
            t = p["type"]
            if t == "loft":
                st = np.asarray(p["stations"], float); cf, cb = p.get("caps", (0.3, 0.3))
                plo = [-st[:, 1].max(), st[0, 0] - cf, (st[:, 3] - st[:, 2]).min()]
                phi = [st[:, 1].max(), st[-1, 0] + cb, (st[:, 3] + st[:, 2]).max()]
            elif t == "cone":
                a, b = np.asarray(p["a"]), np.asarray(p["b"]); r = max(p["r"])
                plo = np.minimum(a, b) - r; phi = np.maximum(a, b) + r
            elif t == "ellipsoid":
                c, r = np.asarray(p["c"]), np.asarray(p["r"]); plo, phi = c - r, c + r
            else:
                a, b = np.asarray(p["root"]), np.asarray(p["tip"]); r = max(p["r"]) + max(p.get("t", [0.1])) + abs(p.get("bend", 0))
                plo = np.minimum(a, b) - r; phi = np.maximum(a, b) + r
            lo = np.minimum(lo, plo); hi = np.maximum(hi, phi)
        xm = max(abs(lo[0]), abs(hi[0])); lo[0], hi[0] = -xm, xm
        return lo - pad, hi + pad

    def tags(self, P):
        """Per-point soft membership of tagged parts: {"fin": w, "lip": w, ..., "fin_t": 0 root .. 1 tip}."""
        P = np.asarray(P, float).copy(); P[:, 0] = np.abs(P[:, 0])
        ds = {p["name"]: self.part_d(P, p) for p in self.parts}
        out = {}
        tags = {p.get("tag") for p in self.parts if p.get("tag")}
        for tg in tags:
            mine = [p for p in self.parts if p.get("tag") == tg and p.get("op") != "subtract"]
            rest = [p for p in self.parts if p.get("tag") != tg and p.get("op") != "subtract"]
            dT = np.min([ds[p["name"]] for p in mine], 0)
            dO = np.min([ds[p["name"]] for p in rest], 0) if rest else np.full(len(P), 1e3)
            k = max(np.mean([p.get("k", 0.1) for p in mine]), 0.03)
            out[tg] = np.clip(0.5 + (dO - dT) / (1.2 * k), 0, 1)
        fins = [p for p in self.parts if p["type"] == "fin"]
        if fins:
            # soft-min weights over the fins, so overlapping fins (two tail lobes) blend their paint coordinates
            # instead of switching at the crossing (a hard switch paints a visible seam)
            dd = np.stack([ds[p["name"]] for p in fins])
            wts = np.exp(-(dd - dd.min(0)) / 0.04); wts /= wts.sum(0)
            ft = np.zeros(len(P)); fv = np.zeros(len(P)); fe = np.zeros(len(P))
            for i, p in enumerate(fins):
                root, u, v, w, L = _fin_frame(p)
                q = P - root; lu, lv = q @ u, q @ v
                s_ = np.clip(lu / L, 0, 1)
                half = p["r"][0] + (p["r"][1] - p["r"][0]) * s_
                d2 = round_cone(np.column_stack([lu, lv, np.zeros_like(lu)]), [0, 0, 0], [L, 0, 0], p["r"][0], p["r"][1])
                ft += wts[i] * s_
                fv += wts[i] * np.clip(lv / np.maximum(half, 1e-6), -1, 1)   # -1 .. 1 across the fin (for rays)
                fe += wts[i] * np.clip(1 + d2 / (0.6 * max(p["r"])), 0, 1)   # 1 at the fin outline (painted edge)
            out["fin_t"] = ft; out["fin_v"] = fv; out["fin_edge"] = fe
        return out


# ======================================================================= meshing
def surface_nets(field, h, lo=None, hi=None):
    """Dense quad mesh of the zero set (surface nets on an h-stud grid), Newton-projected onto the field."""
    if lo is None:
        lo, hi = field.bounds(3 * h)
    n = [int(math.ceil((hi[k] - lo[k]) / h)) + 1 for k in range(3)]
    nx, ny, nz = n
    xs = lo[0] + h * np.arange(nx); ys = lo[1] + h * np.arange(ny); zs = lo[2] + h * np.arange(nz)
    G = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), -1).reshape(-1, 3)
    F = np.empty(len(G))
    for i0 in range(0, len(G), 300000):
        F[i0:i0 + 300000] = field(G[i0:i0 + 300000])
    F = F.reshape(nx, ny, nz); F[F == 0] = 1e-9
    inside = F < 0
    cells = np.zeros((nx - 1, ny - 1, nz - 1), np.int8)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                cells += inside[dx:nx - 1 + dx, dy:ny - 1 + dy, dz:nz - 1 + dz]
    active = (cells > 0) & (cells < 8)
    vid = -np.ones(active.shape, np.int64); vid[active] = np.arange(active.sum())
    acc = np.zeros((active.sum(), 3)); cnt = np.zeros(active.sum()); faces = []
    for ax in range(3):
        sl0 = [slice(None)] * 3; sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, -1); sl1[ax] = slice(1, None)
        F0, F1 = F[tuple(sl0)], F[tuple(sl1)]
        ch = (F0 < 0) != (F1 < 0)
        idx = np.argwhere(ch)
        t = F0[ch] / (F0[ch] - F1[ch])
        pos = lo + h * idx.astype(float); pos[:, ax] += t * h
        o1, o2 = [a for a in range(3) if a != ax]
        quad = []
        for d1, d2 in ((0, 0), (1, 0), (1, 1), (0, 1)):
            c = idx.copy(); c[:, o1] -= 1 - d1; c[:, o2] -= 1 - d2; quad.append(c)
        ok = np.ones(len(idx), bool)
        for c in quad:
            ok &= np.all(c >= 0, 1) & (c[:, 0] < nx - 1) & (c[:, 1] < ny - 1) & (c[:, 2] < nz - 1)
        for c in quad:
            cc = c[ok]; v = vid[cc[:, 0], cc[:, 1], cc[:, 2]]
            np.add.at(acc, v, pos[ok]); np.add.at(cnt, v, 1)
        q = np.stack([vid[c[ok][:, 0], c[ok][:, 1], c[ok][:, 2]] for c in quad], 1)
        flip = F0[ch][ok] < 0
        if (o1, o2) == ((ax + 1) % 3, (ax + 2) % 3):
            q = np.where(flip[:, None], q, q[:, ::-1])
        else:
            q = np.where(flip[:, None], q[:, ::-1], q)
        faces.append(q)
    verts = acc / np.maximum(cnt, 1)[:, None]
    verts = field.project(verts, 3)
    return verts, np.concatenate(faces)


def _mesh_obj(name, verts, faces):
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces]); me.update()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob


def _relax_project(bm, field, relax=2, keep_seam=True):
    verts = list(bm.verts)
    for it in range(relax + 1):
        if it < relax:
            bm.normal_update()
            new = []
            for v in verts:
                nb = [e.other_vert(v).co for e in v.link_edges]
                if not nb:
                    new.append(v.co.copy()); continue
                c = sum(nb, Vector()) / len(nb); d = c - v.co; d -= v.normal * d.dot(v.normal)
                new.append(v.co + d * 0.4)
            for v, p in zip(verts, new):
                seam = keep_seam and v.co.x == 0.0
                v.co = p
                if seam:
                    v.co.x = 0.0
        arr = field.project(np.array([v.co[:] for v in verts]), 3)
        for v, p in zip(verts, arr):
            seam = keep_seam and v.co.x == 0.0
            v.co = Vector(p)
            if seam:
                v.co.x = 0.0
    bm.normal_update()


def build_body(spec, field, log=print, seeds=(0, 1, 2, 3, 4, 5)):
    """Fused body shell at the tri budget: surface nets -> voxel remesh (clean manifold) -> QuadriFlow quads ->
    +X half -> project + relax -> mirror (exact symmetry). Thin fins near the quad size can fold (self-intersecting
    faces after projection): QuadriFlow is retried with other seeds and the first clean shell is kept (the one with
    the fewest problems otherwise). Falls back to Decimate if QuadriFlow fails."""
    best = None
    for sd in seeds:
        body = _build_body_once(spec, field, log, sd)
        si = lf.self_intersections(body)["self"]; sa = lf.shading_artifacts(body)
        bad = si + sa["flipped"] + sa["degenerate"]
        log(f"seed {sd}: self-intersections {si}, flipped {sa['flipped']}")
        if best is None or bad < best[0]:
            if best is not None:
                bpy.data.objects.remove(best[1], do_unlink=True)
            best = (bad, body)
        else:
            bpy.data.objects.remove(body, do_unlink=True)
        if bad == 0:
            break
    best[1].name = spec["name"] + "_body"
    return best[1]


def _build_body_once(spec, field, log=print, seed=0):
    s = spec; h = s["grid"]; t0 = time.time()
    V, F = surface_nets(field, h)
    dense = _mesh_obj(s["name"] + "_dense", V, F)
    lf._activate(dense)
    rm = dense.modifiers.new("vx", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = h * 0.9
    bpy.ops.object.modifier_apply(modifier=rm.name)
    log(f"dense {len(dense.data.polygons)} faces, {time.time() - t0:.1f}s")
    eye_tris = 2 * 2 * s["eye_segments"][0] * (s["eye_segments"][1] - 1)
    body_quads = max(200, int((s["tris"] - eye_tris) / 2 * s.get("quad_boost", 1.15)))
    nq = len(dense.data.polygons)
    if nq > 12 * body_quads:          # thin out first so QuadriFlow stays fast
        dm = dense.modifiers.new("pre", "DECIMATE"); dm.ratio = 12 * body_quads / nq
        bpy.ops.object.modifier_apply(modifier=dm.name)
    ok = False
    try:
        r = bpy.ops.object.quadriflow_remesh(target_faces=body_quads, use_mesh_symmetry=False, use_preserve_sharp=False,
                                             use_preserve_boundary=False, smooth_normals=False, seed=seed)
        ok = "FINISHED" in r and len(dense.data.polygons) > 0.5 * body_quads
    except Exception as e:
        log("quadriflow failed: " + str(e))
    if not ok:
        dm = dense.modifiers.new("dec", "DECIMATE"); dm.ratio = 2 * body_quads / max(1, len(dense.data.polygons) * 2)
        dm.use_symmetry = True; dm.symmetry_axis = "X"; bpy.ops.object.modifier_apply(modifier=dm.name)
    log(f"remeshed ({'quadriflow' if ok else 'decimate'}) {len(dense.data.polygons)} faces, {time.time() - t0:.1f}s")
    bm = bmesh.new(); bm.from_mesh(dense.data)
    vv = field.project(np.array([v.co[:] for v in bm.verts]), 4)
    for v, p in zip(bm.verts, vv):
        v.co = Vector(p)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5, plane_co=(0, 0, 0),
                           plane_no=(1, 0, 0), clear_inner=True)
    for v in bm.verts:
        if abs(v.co.x) < 2e-4:
            v.co.x = 0.0
    # fold tiny slivers left by the bisect cut into their neighbours
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=h * 0.6 * 0.35)
    for v in bm.verts:                       # every open-border vertex of the half lies on the mirror plane
        if v.is_boundary or abs(v.co.x) < 2e-4:
            v.co.x = 0.0
    _relax_project(bm, field, s["relax"])
    ng = [f for f in bm.faces if len(f.verts) > 4]      # triangulate n-gons on the half, so the mirror is exact
    if ng:
        bmesh.ops.triangulate(bm, faces=ng, quad_method="BEAUTY", ngon_method="BEAUTY")
    # mirror to -X
    geom = bmesh.ops.duplicate(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:])
    dv = [e for e in geom["geom"] if isinstance(e, bmesh.types.BMVert)]
    df = [e for e in geom["geom"] if isinstance(e, bmesh.types.BMFace)]
    for v in dv:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=df)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(s["name"] + "_body"); bm.to_mesh(me); bm.free()
    body = bpy.data.objects.new(s["name"] + "_body", me); bpy.context.scene.collection.objects.link(body)
    bpy.data.objects.remove(dense, do_unlink=True)
    log(f"body {sum(len(p.vertices) - 2 for p in me.polygons)} tris, {time.time() - t0:.1f}s")
    return body


def build_eyes(spec, field):
    """Big glossy lens eyes: flattened UV spheres on the surface normal, seated `seat` of their depth into the head.
    Right eye built from the spec, left eye is its exact mirror. Returns (objects, eye frames)."""
    e = spec["eyes"]; r = e["r"]; depth = e.get("depth", 0.75); seg_u, seg_v = spec["eye_segments"]
    at = np.asarray(e["at"], float); dirn = np.asarray(e["dir"], float); dirn /= np.linalg.norm(dirn)
    p = field.raymarch(at + dirn * 3.0, -dirn)
    n = field.grad(p[None])[0]; n /= np.linalg.norm(n)
    z = n * (1 - e.get("aim", 0.3)) + dirn * e.get("aim", 0.3); z /= np.linalg.norm(z)
    up = np.array([0, 0, 1.0]); y = up - z * up.dot(z); y /= np.linalg.norm(y)
    x = -np.cross(y, z)                      # points to the creature's front (-Y) for the +X eye
    c = p - z * (r * depth * e.get("seat", 0.45))
    spec["_eye_frame"] = {"c": c.tolist(), "x": x.tolist(), "y": y.tolist(), "z": z.tolist(), "r": r, "depth": depth}
    frames = []
    obs = []
    for side in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg_u, v_segments=seg_v, radius=1.0)
        for v in bm.verts:          # poles on the eye's side axis: rings, not a pole fan, face the viewer
            v.co = Vector((v.co.z, v.co.y, -v.co.x))
        M = np.column_stack([x, y, z])
        cc = c.copy()
        if side < 0:
            M = np.diag([-1, 1, 1]) @ M; cc = cc * np.array([-1, 1, 1])
        loc = []
        for v in bm.verts:
            l = np.array(v.co[:]) * np.array([r, r, r * depth]); loc.append(l / r)
            v.co = Vector(cc + M @ l)
        if side < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        me = bpy.data.meshes.new(f"{spec['name']}_eye{'R' if side > 0 else 'L'}")
        bm.to_mesh(me); bm.free()
        a = me.attributes.new("eyeloc", "FLOAT_VECTOR", "POINT")
        a.data.foreach_set("vector", np.array(loc).ravel())
        ob = bpy.data.objects.new(me.name, me); bpy.context.scene.collection.objects.link(ob)
        obs.append(ob); frames.append((cc, M))
    return obs, frames


def _set_attr(me, name, vals, kind="FLOAT"):
    if name in me.attributes:
        me.attributes.remove(me.attributes[name])
    a = me.attributes.new(name, kind, "POINT")
    a.data.foreach_set("vector" if kind == "FLOAT_VECTOR" else "value", np.asarray(vals, float).ravel())


def join_creature(spec, field, body, eyes, frames=None):
    """Writes per-vertex tags (tag_<tag>, fin_t, fin_v, fin_edge, eye, eyeloc, eye_near) and joins body + eyes into
    one object. eye_near (1 at the eye, 0 beyond 1.5 eye radii) keeps the AO bake from painting a dark disc
    around each eye: the lens shells occlude the body skin around and under them."""
    co = np.array([v.co[:] for v in body.data.vertices])
    near = np.zeros(len(co))
    for cc, M in (frames or []):
        r = spec["eyes"]["r"]
        d = np.linalg.norm(co - np.asarray(cc), axis=1) / r
        t_ = np.clip((1.9 - d) / 0.9, 0, 1)
        near = np.maximum(near, t_ * t_ * (3 - 2 * t_))
    _set_attr(body.data, "eye_near", near)
    tg = field.tags(co)
    names = sorted({p.get("tag") for p in field.parts if p.get("tag")})
    for t in names:
        _set_attr(body.data, "tag_" + t, tg[t])
    for nm in ("fin_t", "fin_v", "fin_edge"):
        _set_attr(body.data, nm, tg.get(nm, np.zeros(len(co))))
    _set_attr(body.data, "eye", np.zeros(len(co)))
    _set_attr(body.data, "eyeloc", np.zeros((len(co), 3)), "FLOAT_VECTOR")
    for e in eyes:
        nv = len(e.data.vertices)
        for t in names:
            _set_attr(e.data, "tag_" + t, np.zeros(nv))
        for nm in ("fin_t", "fin_v", "fin_edge"):
            _set_attr(e.data, nm, np.zeros(nv))
        _set_attr(e.data, "eye", np.ones(nv)); _set_attr(e.data, "eye_near", np.ones(nv))
    bpy.ops.object.select_all(action="DESELECT")
    for o in [body] + eyes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = spec["name"]; body.data.name = spec["name"]
    lf.cleanup(body, 1e-6)
    return body


def set_normals(ob, field, mode="weighted"):
    lf._activate(ob); bpy.ops.object.shade_smooth()
    if mode == "sdf":
        me = ob.data
        co = np.array([v.co[:] for v in me.vertices]); g = field.grad(co)
        g /= np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]
        eye = np.zeros(len(co)); me.attributes["eye"].data.foreach_get("value", eye)
        vn = np.array([v.normal[:] for v in me.vertices])
        g[eye > 0.5] = vn[eye > 0.5]
        me.normals_split_custom_set_from_vertices([tuple(x) for x in g])
    else:
        wn = ob.modifiers.new("LF_WeightedNormal", "WEIGHTED_NORMAL"); wn.mode = "FACE_AREA"; wn.weight = 50
        wn.keep_sharp = False
        bpy.ops.object.modifier_apply(modifier=wn.name)


def unwrap(ob, margin=0.012, mirror=True):
    """Smart UV project. mirror=True unwraps only the +X half and gives every -X face its mirror twin's UVs:
    the painted bake is X-symmetric by construction (all paint terms read |x|), so overlapping mirrored UVs
    double the texel density for free. Roblox accepts overlapping UVs (one UV set, inside 0-1)."""
    lf._activate(ob)
    me = ob.data
    if mirror:
        for poly in me.polygons:
            poly.select = poly.center.x > 0
    else:
        for poly in me.polygons:
            poly.select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    if mirror:      # hide the -X half so it takes no part in projecting or packing (else islands overlap)
        bpy.ops.mesh.hide(unselected=True)
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(80), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
    # smart project flattens each normal cluster onto ONE plane, so a cluster that folds (flank behind a fin root)
    # overlaps itself; re-flatten every island with angle-based unwrap along the island borders, then pack
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.seams_from_islands(mark_seams=True)
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=margin)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.mesh.reveal(select=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if mirror:
        from mathutils.kdtree import KDTree
        kd = KDTree(len(me.vertices))
        for v in me.vertices:
            kd.insert(v.co, v.index)
        kd.balance()
        mir = [kd.find(Vector((-v.co.x, v.co.y, v.co.z)))[1] for v in me.vertices]
        uv = me.uv_layers.active.data
        bykey = {}; missing = []
        for poly in me.polygons:
            if poly.center.x > 0:
                bykey[frozenset(poly.vertices)] = poly
        for poly in me.polygons:
            if poly.center.x > 0:
                continue
            twin = bykey.get(frozenset(mir[i] for i in poly.vertices))
            if twin is None:
                missing.append(poly.index)
                continue
            tl = {me.loops[li].vertex_index: uv[li].uv.copy() for li in twin.loop_indices}
            for li in poly.loop_indices:
                uv[li].uv = tl[mir[me.loops[li].vertex_index]]
        if missing:
            print(f"unwrap: {len(missing)} -X faces have no mirror twin, unwrapping both halves instead"); return unwrap(ob, margin, mirror=False)
    while len(ob.data.uv_layers) > 1:
        ob.data.uv_layers.remove(ob.data.uv_layers[1])


# ======================================================================= the painted bake
class _G:
    """Tiny shader-graph helper: every call returns an output socket; numbers become default values."""

    def __init__(self, nt):
        self.nt = nt; self.x = 0

    def n(self, kind, **props):
        nd = self.nt.nodes.new(kind); nd.location = (self.x, 0); self.x += 30
        for k, v in props.items():
            setattr(nd, k, v)
        return nd

    def _in(self, sock, val):
        if isinstance(val, bpy.types.NodeSocket):
            self.nt.links.new(val, sock)
        else:
            sock.default_value = val

    def math(self, op, a, b=0.0, clamp=False):
        nd = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._in(nd.inputs[0], a); self._in(nd.inputs[1], b)
        return nd.outputs[0]

    def ss(self, x, a, b):
        """smoothstep(a, b, x) (a > b gives the falling edge)."""
        nd = self.n("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self._in(nd.inputs["Value"], x)
        if a > b:
            nd.inputs["From Min"].default_value = b; nd.inputs["From Max"].default_value = a
            nd.inputs["To Min"].default_value = 1.0; nd.inputs["To Max"].default_value = 0.0
        else:
            nd.inputs["From Min"].default_value = a; nd.inputs["From Max"].default_value = b
        return nd.outputs["Result"]

    def rgb(self, hexs):
        nd = self.n("ShaderNodeRGB"); nd.outputs[0].default_value = (*hex_rgb(hexs), 1.0)
        return nd.outputs[0]

    def mix(self, fac, a, b, blend="MIX"):
        nd = self.n("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_factor=True)
        self._in(nd.inputs["Factor"], fac)
        self._in(nd.inputs[6], a); self._in(nd.inputs[7], b)
        return nd.outputs[2]

    def sep(self, vec):
        nd = self.n("ShaderNodeSeparateXYZ"); self._in(nd.inputs[0], vec)
        return nd.outputs[0], nd.outputs[1], nd.outputs[2]

    def comb(self, x, y, z):
        nd = self.n("ShaderNodeCombineXYZ")
        for i, v in enumerate((x, y, z)):
            self._in(nd.inputs[i], v)
        return nd.outputs[0]

    def vlen(self, v):
        nd = self.n("ShaderNodeVectorMath", operation="LENGTH"); self._in(nd.inputs[0], v)
        return nd.outputs["Value"]

    def attr(self, name, out="Fac"):
        return self.n("ShaderNodeAttribute", attribute_name=name).outputs[out]

    def mul(self, a, b):
        return self.math("MULTIPLY", a, b)


def _paint_graph(nt, spec, rough=False):
    pal, pt = spec["palette"], spec["paint"]
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    g = _G(nt)
    pos = g.n("ShaderNodeTexCoord").outputs["Object"]
    geo = g.n("ShaderNodeNewGeometry")
    X, Y, Z = g.sep(pos); nX, nY, nZ = g.sep(geo.outputs["Normal"])
    aX = g.math("ABSOLUTE", X)
    fin = g.attr("tag_fin") if any(p.get("tag") == "fin" for p in spec["parts"]) else 0.0
    lip = g.attr("tag_lip") if any(p.get("tag") == "lip" for p in spec["parts"]) else 0.0
    eye = g.attr("eye")
    out = g.n("ShaderNodeOutputMaterial")
    emit = g.n("ShaderNodeEmission"); nt.links.new(emit.outputs[0], out.inputs["Surface"])
    if rough:
        v = g.math("ADD", pt["rough_body"], g.mul(fin, pt["rough_fin"] - pt["rough_body"]))
        v = g.math("ADD", v, g.mul(lip, pt["rough_lip"] - pt["rough_body"]))
        v = g.math("ADD", g.mul(v, g.math("SUBTRACT", 1.0, eye)), g.mul(eye, pt["rough_eye"]))
        nt.links.new(g.comb(v, v, v), emit.inputs["Color"])
        return
    ylo, yhi = spec["_ybounds"]
    # 1. base gradient head -> tail, warm top light
    base = g.mix(g.ss(Y, ylo + 0.15 * (yhi - ylo), ylo + 0.85 * (yhi - ylo)), g.rgb(pal["main_front"]), g.rgb(pal["main_back"]))
    lit = g.ss(nZ, 0.25, 1.0)
    if pt.get("bands"):     # soft posterised light: 3 painted value steps blended with the smooth ramp
        fl = g.math("FLOOR", g.mul(lit, 3.0))
        stepped = g.ss(g.math("SUBTRACT", g.mul(lit, 3.0), fl), 0.35, 0.65)
        stepped = g.mul(g.math("ADD", fl, stepped), 1.0 / 3.0)
        lit = g.math("ADD", g.mul(lit, 1 - pt["bands"]), g.mul(stepped, pt["bands"]))
    base = g.mix(g.mul(lit, pt["warm_amt"]), base, g.rgb(pal["warm"]))
    # 2. belly counter-shading (position + normal, soft)
    bl = g.math("ADD", g.math("SUBTRACT", pt["belly_line"], Z), g.mul(nZ, -0.3))
    belly = g.ss(bl, -pt["belly_soft"], pt["belly_soft"])
    notfin = g.math("SUBTRACT", 1.0, fin)
    base = g.mix(g.mul(belly, notfin), base, g.rgb(pal["belly"]))
    # 3. bounce rim: a cool reflected-light band on the lower flank, just above the belly
    rim = g.mul(g.ss(nZ, 0.05, -0.35), g.ss(nZ, -0.55, -0.9))
    rim = g.mul(g.mul(rim, g.math("SUBTRACT", 1.0, belly)), pt["rim_amt"])
    base = g.mix(rim, base, g.rgb(pal["rim"]), "SCREEN")
    # 4. painted spots on the back (Voronoi, soft edge), never on the belly
    vor = g.n("ShaderNodeTexVoronoi", feature="F1"); vor.inputs["Scale"].default_value = pt["spot_scale"]
    vor.inputs["Randomness"].default_value = 0.85
    g._in(vor.inputs["Vector"], g.comb(aX, Y, Z))
    spot = g.ss(vor.outputs["Distance"], pt["spot_r"][1], pt["spot_r"][0])
    spot = g.mul(g.mul(spot, g.math("SUBTRACT", 1.0, belly)), g.ss(Z, spec["paint"]["belly_line"] + 0.15, spec["paint"]["belly_line"] + 0.6))
    spot = g.mul(g.mul(spot, notfin), pt["spot_amt"])
    base = g.mix(spot, base, g.rgb(pal["spot"]))
    # 5. cheek blush
    if pt.get("cheek"):
        cx, cy, cz = pt["cheek"]
        d = g.vlen(g.comb(g.math("SUBTRACT", aX, cx), g.math("SUBTRACT", Y, cy), g.mul(g.math("SUBTRACT", Z, cz), 1.6)))
        base = g.mix(g.mul(g.ss(d, pt["cheek_r"], 0.0), 0.75), base, g.rgb(pal["blush"]))
    # 6. fins: own gradient root -> tip, painted rays, pale translucent-looking edge
    ft = g.attr("fin_t")
    fincol = g.mix(g.ss(ft, 0.15, 1.0), g.rgb(pal["fin_root"]), g.rgb(pal["fin_tip"]))
    rays = g.math("ADD", 0.5, g.mul(g.math("SINE", g.mul(g.attr("fin_v"), math.pi * pt["fin_rays"])), 0.5))
    rays = g.mul(g.mul(g.ss(rays, 0.68, 0.9), g.ss(ft, 0.2, 0.5)), pt["ray_amt"])
    fincol = g.mix(rays, fincol, g.rgb(pal["fin_ray"]))
    fincol = g.mix(g.mul(g.ss(g.attr("fin_edge"), 0.55, 0.95), pt["fin_edge_amt"]), fincol, g.rgb(pal["fin_edge"]))
    base = g.mix(fin, base, fincol)
    # 7. lips
    base = g.mix(lip, base, g.rgb(pal["lip"]))
    # 8. painted highlight strokes (soft elongated blobs on the top planes)
    for hx, hy, hz, rx, ry, rz, amt in pt.get("highlights", []):
        d = g.vlen(g.comb(g.math("DIVIDE", g.math("SUBTRACT", aX, hx), rx), g.math("DIVIDE", g.math("SUBTRACT", Y, hy), ry),
                          g.math("DIVIDE", g.math("SUBTRACT", Z, hz), rz)))
        base = g.mix(g.mul(g.ss(d, 1.0, 0.2), amt), base, g.rgb(pal["highlight"]))
    # 9. stroke noise: stretched noise = brush-direction value variation
    sc = pt["stroke_scale"]
    nz = g.n("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 1.0; nz.inputs["Detail"].default_value = 3.0
    g._in(nz.inputs["Vector"], g.comb(g.mul(aX, sc[0]), g.mul(Y, sc[1]), g.mul(Z, sc[2])))
    hsv = g.n("ShaderNodeHueSaturation")
    g._in(hsv.inputs["Value"], g.math("ADD", 1.0, g.mul(g.math("SUBTRACT", nz.outputs["Fac"], 0.5), 2 * pt["stroke_amt"])))
    g._in(hsv.inputs["Color"], base); base = hsv.outputs["Color"]
    # 10. soft AO in creases, tinted (hand-painted shadows are warm and saturated, not grey)
    ao = g.n("ShaderNodeAmbientOcclusion", only_local=True, samples=16); ao.inputs["Distance"].default_value = pt["ao_dist"]
    occ = g.mul(g.math("SUBTRACT", 1.0, ao.outputs["AO"]), pt["ao_amt"])
    occ = g.mul(occ, g.math("SUBTRACT", 1.0, g.mul(g.attr("eye_near"), 0.9)))
    base = g.mix(occ, base, g.rgb(pal["ao"]), "MULTIPLY")
    # 11. eyes: deep iris with a lighter lower glow, two glints
    ef = spec.get("_eye_frame")
    if ef:      # per-pixel eye coordinates from the object position (|x| mirrors the right eye's frame)
        q = [g.math("SUBTRACT", comp, ef["c"][i]) for i, comp in enumerate((aX, Y, Z))]

        def dot(axis, scale):
            return g.math("DIVIDE", g.math("ADD", g.math("ADD", g.mul(q[0], axis[0]), g.mul(q[1], axis[1])), g.mul(q[2], axis[2])), scale)
        eX, eY, eZ = dot(ef["x"], ef["r"]), dot(ef["y"], ef["r"]), dot(ef["z"], ef["r"] * ef["depth"])
    else:
        eX, eY, eZ = g.sep(g.attr("eyeloc", "Vector"))
    iris = g.mix(g.ss(eY, 0.05, -0.85), g.rgb(pal["eye_dark"]), g.rgb(pal["eye_light"]))
    front = g.ss(eZ, 0.2, 0.45)
    for gx, gy, gr in ((0.30, 0.36, 0.26), (-0.30, -0.30, 0.10)):
        d = g.vlen(g.comb(g.math("SUBTRACT", eX, gx), g.math("SUBTRACT", eY, gy), 0.0))
        iris = g.mix(g.mul(g.ss(d, gr, gr * 0.82), front), iris, g.rgb(pal["eye_glint"]))
    base = g.mix(eye, base, iris)
    nt.links.new(base, emit.inputs["Color"])


def bake_paint(ob, spec, out_dir, log=print):
    """Bakes the procedural paint (colour, sRGB) and roughness (non-colour) to spec["texture"]-px PNGs with Cycles,
    then gives the object its final single material (Principled: colour + roughness maps). Returns the paths."""
    s = spec; size = s["texture"]; sc = bpy.context.scene
    co = np.array([v.co[:] for v in ob.data.vertices]); s["_ybounds"] = (float(co[:, 1].min()), float(co[:, 1].max()))
    prev = sc.render.engine
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = s["bake_samples"]
    sc.render.bake.margin = 16; sc.render.bake.use_clear = True
    paths = {}
    mat = bpy.data.materials.new(s["name"] + "_Bake"); mat.use_nodes = True
    ob.data.materials.clear(); ob.data.materials.append(mat)
    for key, rough in (("color", False), ("roughness", True)):
        _paint_graph(mat.node_tree, s, rough)
        img = bpy.data.images.new(f"{s['name']}_{key}", size, size, alpha=False)
        img.colorspace_settings.name = "Non-Color" if rough else "sRGB"
        tn = mat.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = img
        mat.node_tree.nodes.active = tn
        lf._activate(ob)
        t0 = time.time(); bpy.ops.object.bake(type="EMIT", margin=16)
        p = os.path.join(out_dir, f"{s['name']}_{'Color' if not rough else 'Roughness'}.png")
        img.filepath_raw = p; img.file_format = "PNG"; img.save(); paths[key] = p
        log(f"baked {key} {size}px in {time.time() - t0:.1f}s")
    sc.render.engine = prev
    bpy.data.materials.remove(mat)
    final = bpy.data.materials.new(s["name"] + "_Mat"); final.use_nodes = True
    nt = final.node_tree; bsdf = nt.nodes["Principled BSDF"]
    ci = nt.nodes.new("ShaderNodeTexImage"); ci.image = bpy.data.images.load(paths["color"], check_existing=False)
    ri = nt.nodes.new("ShaderNodeTexImage"); ri.image = bpy.data.images.load(paths["roughness"], check_existing=False)
    ri.image.colorspace_settings.name = "Non-Color"
    nt.links.new(ci.outputs["Color"], bsdf.inputs["Base Color"]); nt.links.new(ri.outputs["Color"], bsdf.inputs["Roughness"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.5
    ob.data.materials.clear(); ob.data.materials.append(final)
    return paths


# ======================================================================= rig, weights, animation
def _chain_points(spec):
    r = spec["rig"]; pts = [np.asarray(p, float) for p in r["spine"]]   # head tip -> tail tip, on x = 0
    return pts, r.get("body_index", 1)


def build_rig(spec, ob, log=print):
    """Root (origin, no deform) -> Body (segment body_index of the spine polyline, points to the head) -> Head chain
    forward and Tail1..N backward; every fin part with "bones": n gets an n-bone chain root -> tip (mirrored fins
    get .L (+X) and .R). Automatic (heat) weights, eyes 100 % on the nearest head bone, unweighted vertices
    filled from the nearest bone, then <= 4 influences per vertex and normalised."""
    s = spec; pts, bi = _chain_points(s); sc = bpy.context.scene
    ad = bpy.data.armatures.new(s["name"] + "_Rig"); arm = bpy.data.objects.new(s["name"] + "_Rig", ad)
    sc.collection.objects.link(arm); lf._activate(arm); bpy.ops.object.mode_set(mode="EDIT")
    eb = ad.edit_bones
    root = eb.new("Root"); root.head = (0, 0, 0); root.tail = (0, 0, 0.25 * s["rig"].get("root_len", 1.0)); root.use_deform = False
    body = eb.new("Body"); body.head = Vector(pts[bi + 1]); body.tail = Vector(pts[bi]); body.parent = root
    spine = ["Body"]
    prev = body; head_names = []
    for i in range(bi - 1, -1, -1):          # forward: Head, Head2...
        nm = "Head" if i == bi - 1 else f"Head{bi - i}"
        b = eb.new(nm); b.head = Vector(pts[i + 1]); b.tail = Vector(pts[i]); b.parent = prev; b.use_connect = True
        prev = b; head_names.append(nm); spine.insert(0, nm)
    prev = body
    tails = []
    for j, i in enumerate(range(bi + 1, len(pts) - 1)):
        nm = s["rig"].get("tail_names", [])[j] if j < len(s["rig"].get("tail_names", [])) else f"Tail{j + 1}"
        b = eb.new(nm); b.head = Vector(pts[i]); b.tail = Vector(pts[i + 1]); b.parent = prev
        b.use_connect = (prev.tail - b.head).length < 1e-6
        prev = b; tails.append(nm); spine.append(nm)
    for b in eb:
        b.roll = 0.0
    fins = []
    for p in s["parts"]:
        nb = p.get("bones", 0)
        if p["type"] != "fin" or not nb:
            continue
        root_p = np.asarray(p["root"], float); tip_p = np.asarray(p["tip"], float)
        sides = [1, -1] if root_p[0] > 0.02 else [0]
        for sd in sides:
            m = np.array([sd if sd else 1, 1, 1], float)
            a, b_ = root_p * m, tip_p * m
            # parent: spine bone whose segment is nearest to the fin root
            best = None
            for nm in spine:
                bb = eb[nm]; h_, t_ = np.array(bb.head[:]), np.array(bb.tail[:])
                u = t_ - h_; tt = np.clip((a - h_).dot(u) / u.dot(u), 0, 1); d = np.linalg.norm(h_ + u * tt - a)
                if best is None or d < best[0]:
                    best = (d, nm)
            par = eb[best[1]]
            suffix = "" if not sd else (".L" if sd > 0 else ".R")
            for k in range(nb):
                nm = f"{p['name'].capitalize()}{k + 1 if nb > 1 else ''}{suffix}"
                bb = eb.new(nm); bb.head = Vector(a + (b_ - a) * k / nb); bb.tail = Vector(a + (b_ - a) * (k + 1) / nb)
                bb.roll = 0.0; bb.parent = par; bb.use_connect = k > 0; par = bb
                fins.append((nm, p["name"], sd, k))
    bpy.ops.object.mode_set(mode="OBJECT")
    arm["lf_spine"] = spine; arm["lf_heads"] = head_names; arm["lf_tails"] = tails
    arm["lf_fins"] = json.dumps(fins)
    # --- skin
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    me = ob.data; nv = len(me.vertices)
    eye = np.zeros(nv); me.attributes["eye"].data.foreach_get("value", eye)
    deform = [b for b in ad.bones if b.use_deform]
    for b in deform:
        if b.name not in ob.vertex_groups:
            ob.vertex_groups.new(name=b.name)
    co = np.array([v.co[:] for v in me.vertices])

    def nearest_bone(p, names):
        best = None
        for nm in names:
            b = ad.bones[nm]; h_, t_ = np.array(b.head_local[:]), np.array(b.tail_local[:]); u = t_ - h_
            tt = np.clip((p - h_).dot(u) / u.dot(u), 0, 1); d = np.linalg.norm(h_ + u * tt - p)
            if best is None or d < best[0]:
                best = (d, nm)
        return best[1]
    eye_bone = head_names[0] if head_names else "Body"
    filled = 0
    for v in me.vertices:
        i = v.index
        if eye[i] > 0.5:
            for g in v.groups[:]:
                ob.vertex_groups[g.group].remove([i])
            ob.vertex_groups[eye_bone].add([i], 1.0, "REPLACE")
        elif sum(g.weight for g in v.groups) < 1e-4:
            ob.vertex_groups[nearest_bone(co[i], [b.name for b in deform])].add([i], 1.0, "REPLACE"); filled += 1
    lf._activate(ob)
    bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    maxinf = max(len([g for g in v.groups if g.weight > 0]) for v in me.vertices)
    unw = sum(1 for v in me.vertices if sum(g.weight for g in v.groups) < 0.99)
    log(f"rig {len(ad.bones)} bones ({len(deform)} deform), filled {filled}, max influences {maxinf}, unnormalised {unw}")
    return arm


def _skew(w, k):
    """Phase warp: sin(_skew(w, k)) rises fast and falls slow (power stroke ~35 %, eased recovery ~65 % for k 0.55)."""
    return w - k * math.sin(w)


def swim_action(spec, arm):
    """Looping idle/swim: each spine bone yaws (world Z) with a skewed sine (fast power stroke, eased recovery)
    whose phase lags phase_step rad per bone toward the tail and whose amplitude grows to tail_amp (an S-wave);
    the head counter-yaws; paired fins row (world-Z sweep + twist) out of phase with the tail, lagging down each
    fin chain; the Body bone bobs, pitches, rolls against each tail stroke and surges forward on the fin power
    stroke. Integer cycles per loop and keys on both ends -> the first frame equals the last."""
    a = spec["anim"]; sc = bpy.context.scene
    N, step, beats = a["frames"], a["step"], a["beats"]
    sc.render.fps = a["fps"]; sc.frame_start = 0; sc.frame_end = N
    spine = list(arm["lf_spine"]); heads = list(arm["lf_heads"]); tails = list(arm["lf_tails"])
    fins = json.loads(arm["lf_fins"])
    lf._activate(arm); bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "QUATERNION"

    def local_axis(name, world):
        return (arm.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(world)).normalized()
    Zw = (0, 0, 1)
    amps = {}
    for i, nm in enumerate(heads):
        amps[nm] = (-a["head_amp"] / (i + 1), -(i + 1) * 0.3)
    amps["Body"] = (-a["head_amp"] * 0.8, 0.0)          # body counter-yaws against the tail
    for j, nm in enumerate(tails):
        amps[nm] = (a["tail_amp"] * (j + 1) / max(1, len(tails)), (j + 1) * a["phase_step"])
    act = bpy.data.actions.new(spec["name"] + "_Swim"); arm.animation_data_create(); arm.animation_data.action = act
    for f in range(0, N + 1, step):
        t = f / N; w = 2 * math.pi * beats * t
        acc = 1.0 + a.get("accent", 0.0) * math.cos(2 * math.pi * t)   # strong beat, then a softer glide beat
        for nm, (amp, ph) in amps.items():
            q = Quaternion(local_axis(nm, Zw), math.radians(amp * acc) * math.sin(_skew(w - ph, a["skew"])))
            if nm == "Body":
                q = q @ Quaternion(local_axis(nm, (1, 0, 0)), math.radians(a["pitch"]) * math.sin(2 * math.pi * t + 1.2))
                q = q @ Quaternion(local_axis(nm, (0, 1, 0)), math.radians(a["roll"]) * math.sin(_skew(w - a["phase_step"], a["skew"])))
                surge = -a["surge"] * max(0.0, math.sin(_skew(w + math.pi / 2, a["skew"])))
                lv = arm.data.bones[nm].matrix_local.to_3x3().inverted() @ Vector((0, surge, a["bob"] * math.sin(2 * math.pi * t)))
                pb[nm].location = lv; pb[nm].keyframe_insert("location", frame=f)
            pb[nm].rotation_quaternion = q; pb[nm].keyframe_insert("rotation_quaternion", frame=f)
        for nm, part, sd, k in fins:
            sgn = sd if sd else 1
            lag = k * a["fin_lag"]
            if sd:     # paired fins row: sweep about world Z + twist about the fin bone
                ph_ = _skew(w + math.pi / 2 - lag - (a.get("pec_offset", 0.0) if sd < 0 else 0.0), a["skew"])
                ang = a["fin_amp"] * (0.85 ** k) * math.sin(ph_)
                tw = a["fin_twist"] * (0.85 ** k) * math.cos(ph_)
                q = Quaternion(local_axis(nm, Zw), math.radians(ang * sgn)) @ Quaternion((0, 1, 0), math.radians(tw * sgn))
            else:      # median fins follow the tail wave
                ang = a["tail_amp"] * 0.45 * acc * math.sin(_skew(w - a["phase_step"] * 2.2 - lag, a["skew"]))
                q = Quaternion(local_axis(nm, Zw), math.radians(ang))
            pb[nm].rotation_quaternion = q; pb[nm].keyframe_insert("rotation_quaternion", frame=f)
    bpy.ops.object.mode_set(mode="OBJECT")
    # loop check: pose matrices at frame 0 and N
    def pose_at(fr):
        sc.frame_set(fr); return [b.matrix.copy() for b in arm.pose.bones]
    p0, p1 = pose_at(0), pose_at(N)
    err = max(max(abs(m0[r][c] - m1[r][c]) for r in range(4) for c in range(4)) for m0, m1 in zip(p0, p1))
    sc.frame_set(0)
    return {"frames": N, "fps": a["fps"], "seconds": N / a["fps"], "keys_every": step, "loop_error": round(err, 6), "action": act.name}


# ======================================================================= export
def export_creature(ob, arm, out_dir, name):
    """GLB: +Y up, 1 unit = 1 stud, mesh + Armature + the swim action (all bones, incl. the non-deform Root).
    Also an FBX copy (FBX_SCALE_UNITS, no leaf bones, baked animation) for importers that prefer FBX for rigs."""
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    glb = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_normals=True, export_texcoords=True, export_skins=True, export_animations=True,
                              export_def_bones=False, export_force_sampling=True, export_frame_range=True,
                              export_vertex_color="NONE", export_draco_mesh_compression_enable=False)
    fbx = os.path.join(out_dir, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z",
                             axis_up="Y", add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False,
                             bake_anim_use_nla_strips=False, path_mode="COPY", embed_textures=True, use_mesh_modifiers=True,
                             primary_bone_axis="Y", secondary_bone_axis="X")
    return glb, fbx


def glb_check(path):
    """Re-imports the GLB into a scratch scene: counts meshes, bones, max joints per vertex, animations."""
    import struct
    with open(path, "rb") as f:
        data = f.read()
    ln = struct.unpack("<I", data[12:16])[0]
    js = json.loads(data[20:20 + ln])
    return {"meshes": len(js.get("meshes", [])), "skins": len(js.get("skins", [])),
            "joints": len(js["skins"][0]["joints"]) if js.get("skins") else 0,
            "animations": len(js.get("animations", [])), "images": len(js.get("images", [])),
            "materials": len(js.get("materials", [])), "bytes": len(data)}


# ======================================================================= previews
def _img_np(path):
    im = bpy.data.images.load(path, check_existing=False); w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]; bpy.data.images.remove(im)
    return a


def compose(paths, cols, out, bg=(1, 1, 1, 1)):
    """Tiles same-size PNGs into one sheet (row-major, top-left first)."""
    ims = [_img_np(p) for p in paths]; h, w = ims[0].shape[:2]; rows = math.ceil(len(ims) / cols)
    sheet = np.ones((rows * h, cols * w, 4), np.float32) * np.array(bg, np.float32)
    for i, im in enumerate(ims):
        r, c = divmod(i, cols); sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = im
    img = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    img.pixels.foreach_set(sheet[::-1].ravel()); img.filepath_raw = out; img.file_format = "PNG"; img.save()
    bpy.data.images.remove(img)
    return out


def onion(paths, out, bg=(0.86, 0.89, 0.92, 1)):
    """Onion skin: transparent renders blended oldest (faint) to newest (solid) over a flat background."""
    ims = [_img_np(p) for p in paths]; h, w = ims[0].shape[:2]
    acc = np.ones((h, w, 4), np.float32) * np.array(bg, np.float32)
    n = len(ims)
    for i, im in enumerate(ims):
        op = 0.22 + 0.78 * (i / (n - 1)) ** 2
        a = im[..., 3:4] * op
        acc[..., :3] = acc[..., :3] * (1 - a) + im[..., :3] * a
    img = bpy.data.images.new("onion", w, h, alpha=True)
    img.pixels.foreach_set(acc[::-1].ravel()); img.filepath_raw = out; img.file_format = "PNG"; img.save()
    bpy.data.images.remove(img)
    return out


def _bounds_world(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def _cam(sc, target, direction, dist, lens=60, ortho=None):
    cd = bpy.data.cameras.new("LF_Cam"); cd.lens = lens; cd.clip_end = 500
    if ortho:
        cd.type = "ORTHO"; cd.ortho_scale = ortho
    cam = bpy.data.objects.new("LF_Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
    d = Vector(direction).normalized(); cam.location = Vector(target) + d * dist
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    return cam


def _world(sc, top, bottom, strength=1.0):
    w = bpy.data.worlds.new("LF_World"); sc.world = w; w.use_nodes = True; nt = w.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    g = _G(nt)
    tc = g.n("ShaderNodeTexCoord"); X, Y, Z = g.sep(tc.outputs["Generated"])
    col = g.mix(g.ss(Z, -0.6, 0.8), g.rgb(bottom), g.rgb(top))
    bg = g.n("ShaderNodeBackground"); g._in(bg.inputs["Color"], col); bg.inputs["Strength"].default_value = strength
    out = g.n("ShaderNodeOutputWorld"); nt.links.new(bg.outputs[0], out.inputs["Surface"])
    return w


def _light(sc, kind, loc, target, energy, color=(1, 1, 1), size=2.0):
    ld = bpy.data.lights.new("LF_" + kind, kind); ld.energy = energy; ld.color = color
    if kind == "AREA":
        ld.size = size
    if kind == "SUN":
        ld.angle = math.radians(22)
    lo = bpy.data.objects.new(ld.name, ld); sc.collection.objects.link(lo); lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return lo


def _render(sc, path, res=(768, 768)):
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def preview(ob, arm, out_dir, name, spec, size=768, log=print):
    """Review evidence. Atmospheric (EEVEE, AgX): hero three-quarter + 8-view turntable strip. Neutral (Standard view):
    front / side / back / top / three-quarter sheet, close-ups (eye, fin root, tail), wireframe, 4-view silhouettes
    at 96 px plus a 64 px three-quarter, animation strips (side, top, three-quarter; 8 frames over the loop) and
    onion skins (top, side; 6 ghosts over one beat)."""
    sc = bpy.context.scene; res = {}
    tmp = os.path.join(out_dir, "_frames"); os.makedirs(tmp, exist_ok=True)
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = 48
    except Exception:
        pass
    sc.render.film_transparent = False
    lo, hi = _bounds_world([ob]); ctr = (lo + hi) / 2; rad = (hi - lo).length / 2
    for o in sc.objects:
        if o.type == "LIGHT" or (o.type == "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)
    sc.frame_set(0)

    def atmosphere():
        sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
        _world(sc, "#8FD3E8", "#2E5F9A", 0.7)
        L = [_light(sc, "SUN", ctr + Vector((-3, -4, 8)), ctr, 3.6, (1.0, 0.94, 0.84)),
             _light(sc, "AREA", ctr + Vector((4, 5, 3)), ctr, 300, (0.75, 0.95, 1.0), 4.0),
             _light(sc, "AREA", ctr + Vector((-4, -5, -1)), ctr, 320, (1.0, 0.95, 0.86), 6.0)]
        bub = []
        rng = np.random.default_rng(3)
        for i in range(9):
            p = ctr + Vector((rng.uniform(-1, 1) * rad * 2.2, rng.uniform(0.6, 1.6) * rad, rng.uniform(-0.8, 0.9) * rad))
            bpy.ops.mesh.primitive_uv_sphere_add(radius=rng.uniform(0.04, 0.12) * rad, location=p, segments=24, ring_count=12)
            b = bpy.context.object; b.name = "LF_Bubble"; bpy.ops.object.shade_smooth()
            m = bpy.data.materials.get("LF_BubbleMat") or bpy.data.materials.new("LF_BubbleMat"); m.use_nodes = True
            pr = m.node_tree.nodes["Principled BSDF"]; pr.inputs["Base Color"].default_value = (0.8, 0.95, 1, 1)
            pr.inputs["Roughness"].default_value = 0.05; pr.inputs["Alpha"].default_value = 0.35
            b.data.materials.append(m); bub.append(b)
        return L + bub

    def neutral():
        sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
        _world(sc, "#E9EEF2", "#C9D2DA", 1.0)
        return [_light(sc, "SUN", ctr + Vector((-3, -4, 7)), ctr, 2.6, (1.0, 0.97, 0.92)),
                _light(sc, "AREA", ctr + Vector((5, 3, 2)), ctr, 120, (1, 1, 1), 5.0)]

    def drop(objs):
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    # ---- atmospheric hero + turntable
    tmpobjs = atmosphere()
    cam = _cam(sc, ctr, (0.9, -1.1, 0.45), rad * 3.4, 55)
    res["hero"] = _render(sc, os.path.join(out_dir, f"{name}_hero.png"), (1280, 960))
    bpy.data.objects.remove(cam, do_unlink=True)
    frames = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        cam = _cam(sc, ctr, (math.cos(a), math.sin(a), 0.35), rad * 3.4, 55)
        frames.append(_render(sc, os.path.join(tmp, f"turn_{i}.png"), (480, 480))); bpy.data.objects.remove(cam, do_unlink=True)
    res["turntable"] = compose(frames, 4, os.path.join(out_dir, f"{name}_turntable.png"))
    drop(tmpobjs)
    # ---- neutral views
    tmpobjs = neutral(); views = []
    for vn, d in (("front", (0, -1, 0.08)), ("side", (1, 0, 0.08)), ("back", (0, 1, 0.08)), ("top", (0.0, -0.001, 1)),
                  ("three_quarter", (0.9, -1.1, 0.55)), ("low_three_quarter", (-0.9, -1.0, -0.45))):
        cam = _cam(sc, ctr, d, rad * 3.4, 55)
        views.append(_render(sc, os.path.join(tmp, f"view_{vn}.png"), (512, 512))); bpy.data.objects.remove(cam, do_unlink=True)
    res["views"] = compose(views, 3, os.path.join(out_dir, f"{name}_views.png"))
    # close-ups
    closes = []
    for cn, (pt_, d, r) in spec.get("closeups", {}).items():
        cam = _cam(sc, Vector(pt_), d, r * 3.2, 55)
        closes.append(_render(sc, os.path.join(tmp, f"close_{cn}.png"), (512, 512))); bpy.data.objects.remove(cam, do_unlink=True)
    if closes:
        res["closeups"] = compose(closes, len(closes), os.path.join(out_dir, f"{name}_closeups.png"))
    # wireframe over a flat clay copy
    wire = ob.copy(); wire.data = ob.data.copy(); wire.name = "LF_Wire"; sc.collection.objects.link(wire)
    wm = wire.modifiers.new("w", "WIREFRAME"); wm.thickness = 0.008 * rad; wm.use_replace = True; wm.offset = 1
    wmat = bpy.data.materials.new("LF_WireMat"); wmat.use_nodes = True
    wmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.03, 0.05, 1)
    wire.data.materials.clear(); wire.data.materials.append(wmat)
    clay = bpy.data.materials.new("LF_Clay"); clay.use_nodes = True
    clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.75, 0.75, 1)
    keep = list(ob.data.materials); ob.data.materials.clear(); ob.data.materials.append(clay)
    wv = []
    for vn, d in (("side", (1, 0, 0.08)), ("three_quarter", (0.9, -1.1, 0.55))):
        cam = _cam(sc, ctr, d, rad * 3.4, 55)
        wv.append(_render(sc, os.path.join(tmp, f"wire_{vn}.png"), (512, 512))); bpy.data.objects.remove(cam, do_unlink=True)
    res["wireframe"] = compose(wv, 2, os.path.join(out_dir, f"{name}_wireframe.png"))
    bpy.data.objects.remove(wire, do_unlink=True)
    ob.data.materials.clear()
    for m in keep:
        ob.data.materials.append(m)
    # animation strips
    N = sc.frame_end
    for vn, d in (("side", (1, 0, 0.08)), ("top", (0.0, -0.001, 1)), ("three_quarter", (0.9, -1.1, 0.55))):
        cam = _cam(sc, ctr, d, rad * 2.9, 55); fr = []
        for i in range(8):
            sc.frame_set(int(round(i * N / 8)))
            fr.append(_render(sc, os.path.join(tmp, f"anim_{vn}_{i}.png"), (400, 400)))
        bpy.data.objects.remove(cam, do_unlink=True)
        res[f"anim_{vn}"] = compose(fr, 4, os.path.join(out_dir, f"{name}_anim_{vn}.png"))
    # onion skins: one beat (half the loop) as ghosts over the last pose, top and side
    sc.render.film_transparent = True
    for vn, d in (("top", (0.0, -0.001, 1)), ("side", (1, 0, 0.08))):
        cam = _cam(sc, ctr, d, rad * 2.6, 55); fr = []
        for i in range(6):
            sc.frame_set(int(round(i * N / 12)))
            fr.append(_render(sc, os.path.join(tmp, f"onion_{vn}_{i}.png"), (640, 640)))
        bpy.data.objects.remove(cam, do_unlink=True)
        res[f"onion_{vn}"] = onion(fr, os.path.join(out_dir, f"{name}_anim_onion_{vn}.png"))
    sc.render.film_transparent = False
    sc.frame_set(0)
    drop(tmpobjs)
    # silhouettes (Workbench flat black on white)
    sc.render.engine = "BLENDER_WORKBENCH"; sh = sc.display.shading
    sh.light = "FLAT"; sh.color_type = "SINGLE"; sh.single_color = (0, 0, 0); sh.show_cavity = False; sh.show_object_outline = False
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("LF_White"); w.color = (1, 1, 1); sc.world = w
    sil = []
    for vn, d in (("front", (0, -1, 0.08)), ("side", (1, 0, 0.08)), ("top", (0.0, -0.001, 1)), ("three_quarter", (0.9, -1.1, 0.55))):
        cam = _cam(sc, ctr, d, rad * 3.0, 55)
        sil.append(_render(sc, os.path.join(tmp, f"sil_{vn}.png"), (96, 96))); bpy.data.objects.remove(cam, do_unlink=True)
    res["silhouettes"] = compose(sil, 4, os.path.join(out_dir, f"{name}_silhouettes_96px.png"))
    cam = _cam(sc, ctr, (0.9, -1.1, 0.55), rad * 3.0, 55)
    res["sil64"] = _render(sc, os.path.join(out_dir, f"{name}_silhouette_64px.png"), (64, 64)); bpy.data.objects.remove(cam, do_unlink=True)
    sh.color_type = "MATERIAL"; sh.light = "STUDIO"
    sc.render.engine = "BLENDER_EEVEE"
    log("previews: " + ", ".join(res))
    return res


# ======================================================================= one call
def build_creature(spec, out_dir, render=True, blend=None, log=print):
    t0 = time.time()
    s = _merge(spec); name = s["name"]
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lf.setup_scene()
    field = Field(s)
    body = build_body(s, field, log)
    eyes, frames = build_eyes(s, field)
    seats = [lf.seated(e, body) for e in eyes]
    ob = join_creature(s, field, body, eyes, frames)
    set_normals(ob, field, s["normals"])
    unwrap(ob)
    passed, fails, rep = lf.gate(ob, "creature", symmetric="X", seats=seats)
    log(f"GATE passed={passed} fails={fails}")
    tex = bake_paint(ob, s, out_dir, log)
    arm = build_rig(s, ob, log)
    anim = swim_action(s, arm)
    log(f"anim {anim}")
    glb, fbx = export_creature(ob, arm, out_dir, name)
    chk = glb_check(glb)
    me = ob.data
    maxinf = max(len([g for g in v.groups if g.weight > 0]) for v in me.vertices)
    stats = {
        "name": name, "date": time.strftime("%Y-%m-%d"), "tris": rep["tris"], "verts": len(me.vertices),
        "bones": len(arm.data.bones), "deform_bones": sum(1 for b in arm.data.bones if b.use_deform),
        "bone_names": [b.name for b in arm.data.bones], "max_influences": maxinf,
        "texture_px": s["texture"], "texel_px_per_stud": round(rep.get("texel_px_per_stud") or 0, 1),
        "dimensions_studs": rep["dimensions"], "materials": len([m for m in me.materials if m]), "uv_layers": rep["uv_layers"],
        "gate_passed": passed, "gate_fails": fails,
        "gate": {k: rep[k] for k in ("non_manifold_edges", "boundary_edges", "ngons", "self_intersections", "cap_overlaps",
                                       "flipped_faces", "symmetry_error", "uv_out_of_0_1") if k in rep},
        "eye_seats": seats, "animation": anim, "glb": chk, "normals": s["normals"],
        "files": {"glb": os.path.basename(glb), "fbx": os.path.basename(fbx),
                  "color": os.path.basename(tex["color"]), "roughness": os.path.basename(tex["roughness"])},
    }
    if render:
        stats["previews"] = {k: os.path.basename(v) for k, v in preview(ob, arm, out_dir, name, s, log=log).items()}
    with open(os.path.join(out_dir, f"{name}_stats.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2, default=str)
    if blend:
        bpy.ops.wm.save_as_mainfile(filepath=blend)
    log(f"done in {time.time() - t0:.1f}s")
    return stats


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) >= 2:
        with open(argv[0], encoding="utf-8") as f:
            spec_ = json.load(f)
        blend_ = argv[argv.index("--blend") + 1] if "--blend" in argv else None
        st = build_creature(spec_, argv[1], render="--no-render" not in argv, blend=blend_)
        print("STATS", json.dumps({k: st[k] for k in ("tris", "bones", "max_influences", "gate_passed", "gate_fails")}))
