"""LihFolk curve helpers: Bezier / Catmull-Rom maths and budget-aware curve-to-mesh builders
for Roblox-ready models (tested headless on Blender 5.2).

    import sys; sys.path.append(r"<plugin>/skills/roblox-blender-modeling/scripts")
    import lihfolk_curves as lc, lihfolk_bpy as lf

Curve maths (pure Python + mathutils; points are Vector or tuples, 2D or 3D):
    lc.bezier_eval(ctrl, t)              any-degree Bezier by de Casteljau
    lc.bezier_deriv(ctrl, t, order=1)    1st / 2nd derivative (tangent, bend)
    lc.bezier_split(ctrl, t)             -> (left_ctrl, right_ctrl), same shape
    lc.bezier_bbox(ctrl)                 tight axis-aligned box of a cubic (derivative roots)
    lc.bezier_path(segments, n)          chain of cubic segments -> dense polyline
    lc.catmull_rom(points, alpha=0.5)    through every point; centripetal by default (no cusps/loops); only C1
    lc.bspline(points)                   near the points, C2 (no curvature steps) - best for sweeps/silhouettes
    lc.resample(polyline, count|spacing) arc-length even points (even rings, even fence posts)
    lc.round_corners(pts, r, mode)       "arc" fillet (G1, like pipe elbows) or "g2" (curvature-continuous)
    lc.helix(...), lc.circle(n), lc.lens(...), lc.rounded_rect(...)   paths and profiles
    lc.fairness(polyline)                curvature check: kinks, curvature jumps, inflections
    lc.fairness_score(report, expected_inflections)   0-100 summary of the above
    lc.rmf_frames(points, tangents, up)  rotation-minimising frames (double reflection), no Frenet flips

Mesh builders (one watertight mesh, quads + fan-triangle caps, no n-gons, one UV map in 0-1):
    lc.sweep(name, path, profile, radius, twist, ...)   tubes, horns, cables, blades, leaves, ribbons
    lc.lathe(name, profile_rz, steps)                   vases, bottles, pillars, mushrooms
    lc.extrude_outline(name, outline2d, depth, bevel)    signs, badges, logos, flat blades (bevel clamped, no looped insets)
    lc.mirror_outline(right_half)                         symmetric outlines: author half, mirror (shields, badges)
    lc.is_simple_polygon(pts), lc.max_inset(pts)          outline checks used by extrude_outline
    lc.estimate_sweep_tris / lc.adaptive_stations        budget before you build
    lc.join(name, objs), lc.deform(ob, fn), lc.set_color(ob, rgb)
    lc.paint(ob, fn), lc.vertex_color_material(ob), lc.hex_rgb   vertex-colour palettes (one white material)
    lc.curve_object(...), lc.measure_curve_tris(ob)       editable Blender curves and their mesh cost

Tested by test_lihfolk_curves.py, kept outside this repo (maths/budget checks, extrude outline cases,
symmetry/alignment checks + 7 gated assets).

Every builder takes cls= (a lihfolk_bpy.BUDGETS key). It estimates triangles first and, with
auto_fit=True (default), coarsens the station spacing until the estimate fits the class ceiling,
else raises BudgetError. Run lf.finish(ob, "smooth") and lf.gate(ob, cls) afterwards.
"""
import math
import bpy, bmesh
from mathutils import Vector, Matrix

try:
    import lihfolk_bpy as _lf
    BUDGETS = _lf.BUDGETS
except Exception:  # module usable for pure maths outside the plugin folder
    _lf = None
    BUDGETS = {"small": (600, 1500), "medium": (2000, 4000), "weapon": (2500, 4000)}

EPS = 1e-9


class BudgetError(ValueError):
    pass


def _v(p):
    p = Vector(p)
    return p.to_3d() if len(p) == 2 else p


# ---------------------------------------------------------------- Bezier maths

def bezier_eval(ctrl, t):
    """de Casteljau: repeated lerps. Stable for any degree (2 pts = line, 3 = quadratic, 4 = cubic)."""
    pts = [Vector(p) for p in ctrl]
    while len(pts) > 1:
        pts = [a.lerp(b, t) for a, b in zip(pts, pts[1:])]
    return pts[0]


def bezier_deriv(ctrl, t, order=1):
    """Derivative of a Bezier is a lower-degree Bezier of scaled control-point differences."""
    pts = [Vector(p) for p in ctrl]
    for _ in range(order):
        n = len(pts) - 1
        if n < 1:
            return pts[0] * 0
        pts = [(b - a) * n for a, b in zip(pts, pts[1:])]
    return bezier_eval(pts, t)


def bezier_split(ctrl, t=0.5):
    """Split at t. The de Casteljau triangle's left and right edges are the two halves' control points."""
    pts = [Vector(p) for p in ctrl]
    left, right = [pts[0]], [pts[-1]]
    while len(pts) > 1:
        pts = [a.lerp(b, t) for a, b in zip(pts, pts[1:])]
        left.append(pts[0]); right.append(pts[-1])
    return left, right[::-1]


def bezier_bbox(ctrl):
    """Tight AABB of a cubic: endpoints plus points where a coordinate's derivative is zero."""
    p = [Vector(c) for c in ctrl]
    assert len(p) == 4, "cubic only"
    ts = [0.0, 1.0]
    for k in range(len(p[0])):
        a = -p[0][k] + 3 * p[1][k] - 3 * p[2][k] + p[3][k]
        b = 2 * (p[0][k] - 2 * p[1][k] + p[2][k])
        c = p[1][k] - p[0][k]  # derivative / 3 = a t^2 + b t + c
        if abs(a) < 1e-12:
            if abs(b) > 1e-12:
                ts.append(-c / b)
        else:
            d = b * b - 4 * a * c
            if d >= 0:
                r = math.sqrt(d)
                ts += [(-b + r) / (2 * a), (-b - r) / (2 * a)]
    pts = [bezier_eval(p, t) for t in ts if 0 <= t <= 1]
    lo = Vector([min(q[k] for q in pts) for k in range(len(p[0]))])
    hi = Vector([max(q[k] for q in pts) for k in range(len(p[0]))])
    return lo, hi


def bezier_path(segments, samples=24):
    """segments: list of cubic control lists [p0,p1,p2,p3] (end of one = start of next)."""
    out = []
    for si, seg in enumerate(segments):
        for i in range(0 if si == 0 else 1, samples + 1):
            out.append(_v(bezier_eval(seg, i / samples)))
    return out


def arc_handle(radius, angle_rad):
    """Handle length for a cubic that best matches a circular arc: 4/3 * tan(angle/4) * r (0.5523 r per 90 deg)."""
    return 4.0 / 3.0 * math.tan(angle_rad / 4.0) * radius


# ---------------------------------------------------------------- Catmull-Rom

def catmull_rom(points, alpha=0.5, samples=16, closed=False):
    """Curve through every point. alpha 0 = uniform, 0.5 = centripetal (no cusps or self-loops
    inside a segment, Yuksel et al. 2011), 1 = chordal. Barry-Goldman pyramid evaluation."""
    P = [_v(p) for p in points]
    if closed:
        P = [P[-1]] + P + [P[0], P[1]]
    else:
        P = [2 * P[0] - P[1]] + P + [2 * P[-1] - P[-2]]  # mirrored phantom ends
    out = []
    for i in range(len(P) - 3):
        p0, p1, p2, p3 = P[i:i + 4]
        t0 = 0.0
        t1 = t0 + max((p1 - p0).length, EPS) ** alpha
        t2 = t1 + max((p2 - p1).length, EPS) ** alpha
        t3 = t2 + max((p3 - p2).length, EPS) ** alpha
        for j in range(0 if i == 0 else 1, samples + 1):
            t = t1 + (t2 - t1) * j / samples
            a1 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
            a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
            a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
            b1 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
            b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
            out.append(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)))
    if closed:
        out.pop()  # last == first
    return out


def bspline(points, samples=16, closed=False):
    """Uniform cubic B-spline: does NOT pass through the inner points (it approximates them) but is
    C2 - curvature never steps - so sweeps and silhouettes shade with no bands. Open curves repeat
    the end points three times so the curve starts and ends exactly on them."""
    P = [_v(p) for p in points]
    if closed:
        P = P + P[:3]
    else:
        P = [P[0]] * 2 + P + [P[-1]] * 2
    out = []
    for i in range(len(P) - 3):
        p0, p1, p2, p3 = P[i:i + 4]
        for j in range(0 if i == 0 else 1, samples + 1):
            t = j / samples
            t2, t3 = t * t, t * t * t
            b0 = (1 - t) ** 3 / 6
            b1 = (3 * t3 - 6 * t2 + 4) / 6
            b2 = (-3 * t3 + 3 * t2 + 3 * t + 1) / 6
            b3 = t3 / 6
            out.append(p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3)
    if closed:
        out.pop()
    return out


# ---------------------------------------------------------------- polylines

def cumulative_lengths(pts, closed=False):
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    if closed:
        L.append(L[-1] + (pts[0] - pts[-1]).length)
    return L


def point_at(pts, L, d, closed=False):
    """Point at arc length d along polyline pts with cumulative lengths L."""
    seq = pts + [pts[0]] if closed else pts
    d = min(max(d, 0.0), L[-1])
    lo, hi = 0, len(L) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if L[mid] < d:
            lo = mid
        else:
            hi = mid
    seg = L[hi] - L[lo]
    f = (d - L[lo]) / seg if seg > 0 else 0.0
    return seq[lo].lerp(seq[hi], f)


def resample(pts, count=None, spacing=None, closed=False):
    """Evenly spaced points by arc length (even t is NOT even spacing on a Bezier)."""
    pts = [_v(p) for p in pts]
    L = cumulative_lengths(pts, closed)
    total = L[-1]
    if count is None:
        count = max(2, int(round(total / spacing)) + (0 if closed else 1))
    n = count if closed else count - 1
    out = [point_at(pts, L, total * i / n, closed) for i in range(count)]
    return out


def round_corners(points, radius, mode="arc", segs=None, max_step_deg=15, closed=False):
    """Round every corner of a polyline (2D or 3D).
    mode="arc": circular fillet - tangent (G1) to the straights, curvature jumps 0 -> 1/r (pipe elbows).
    mode="g2" : quintic Bezier whose first three and last three control points sit on the two legs,
                so curvature is zero at both joins (G2): straights flow into the bend with no
                shading/highlight break (premium edges). Its setback is 1.35x the arc's so the
                tightest radius roughly matches r (measured: same setback pinches to ~0.74 r).
                The cheaper cubic A,C,C,B is also G2 but pinches to ~0.27 r - avoid it.
    radius may be a number or a list per corner. Corners too tight for the radius are clamped."""
    P = [_v(p) for p in points]
    n = len(P)
    out = []
    idx = range(n) if closed else range(1, n - 1)
    if not closed:
        out.append(P[0])
    for i in idx:
        a, c, b = P[i - 1], P[i], P[(i + 1) % n]
        din, dout = (c - a), (b - c)
        la, lb = din.length, dout.length
        if la < EPS or lb < EPS:
            continue
        din /= la; dout /= lb
        turn = din.angle(dout, 0.0)
        r = radius[i] if isinstance(radius, (list, tuple)) else radius
        if turn < 1e-4 or r <= 0:
            out.append(c); continue
        setback = r * math.tan(turn / 2) * (1.35 if mode == "g2" else 1.0)
        setback = min(setback, 0.5 * la if (closed or i > 1) else la * 0.95, 0.5 * lb if (closed or i < n - 2) else lb * 0.95)
        A, B = c - din * setback, c + dout * setback
        k = segs or max(2, int(math.ceil(math.degrees(turn) / max_step_deg)))
        if mode == "g2":
            ctrl = [A, A.lerp(c, 1 / 3), A.lerp(c, 2 / 3), B.lerp(c, 2 / 3), B.lerp(c, 1 / 3), B]
            k = max(k, 4)
            for j in range(k + 1):
                out.append(bezier_eval(ctrl, j / k))
        else:
            # circular arc via centre: offset from corner along the bisector
            rr = setback / math.tan(turn / 2)
            bis = (dout - din)
            if bis.length < EPS:
                out.append(c); continue
            centre = c + bis.normalized() * math.sqrt(rr * rr + setback * setback)
            va, vb = A - centre, B - centre
            ang = va.angle(vb, 0.0)
            axis = va.cross(vb)
            if axis.length < EPS:
                out += [A, B]; continue
            axis.normalize()
            for j in range(k + 1):
                out.append(centre + Matrix.Rotation(ang * j / k, 3, axis) @ va)
    if not closed:
        out.append(P[-1])
    # drop consecutive duplicates
    clean = [out[0]]
    for q in out[1:]:
        if (q - clean[-1]).length > 1e-6:
            clean.append(q)
    return clean


def helix(radius, pitch, turns, samples_per_turn=48, radius_end=None):
    """Spiral up Z. radius_end makes a cone spiral (horns, swirls)."""
    re = radius if radius_end is None else radius_end
    n = max(2, int(turns * samples_per_turn))
    out = []
    for i in range(n + 1):
        f = i / n
        r = radius + (re - radius) * f
        a = 2 * math.pi * turns * f
        out.append(Vector((r * math.cos(a), r * math.sin(a), pitch * turns * f)))
    return out


# ---------------------------------------------------------------- 2D profiles (x = side, y = up)

def circle(n=8, r=1.0, phase=0.0):
    return [Vector((r * math.cos(2 * math.pi * i / n + phase), r * math.sin(2 * math.pi * i / n + phase))) for i in range(n)]


def ellipse(n, rx, ry):
    return [Vector((rx * math.cos(2 * math.pi * i / n), ry * math.sin(2 * math.pi * i / n))) for i in range(n)]


def lens(width, thickness, n_side=2):
    """Thin closed lens (sharp side edges, rounded faces): ribbons, leaves, flat blades."""
    pts = []
    for i in range(2 * n_side + 2):
        a = math.pi * i / (n_side + 1)
        sn = math.sin(a)
        pts.append(Vector((width / 2 * math.cos(a), thickness / 2 * math.copysign(abs(sn) ** 0.8, sn))))
    return pts


def rounded_rect(w, h, r, segs=2):
    r = min(r, w / 2 - 1e-4, h / 2 - 1e-4)
    sq = [Vector((w / 2, -h / 2)), Vector((w / 2, h / 2)), Vector((-w / 2, h / 2)), Vector((-w / 2, -h / 2))]
    return [p.to_2d() for p in round_corners(sq, r, "arc", segs=segs, closed=True)]


# ---------------------------------------------------------------- curvature / fairness

def fairness(points, closed=False, samples=400, kink_deg=20.0, jump_frac=0.25, step_ratio=0.75):
    """Curvature check on a curve given as a polyline (resampled evenly first).
    kinks          : corners (G0) - the curve turns sharply at one spot
    curvature_jumps: places where curvature STEPS (G1 joins, e.g. a straight meeting a circular arc)
    inflections    : bend direction flips (S-curves). One deliberate S is fine; wobbles are not.
    Curvature is Menger (three-point circle) curvature over a window at least twice the input's
    longest segment, so polyline facets are not mistaken for wobbles. A jump is tested at two window
    sizes: a real step measures the same at both, a steep-but-smooth G2 ramp halves with the window."""
    src = [_v(p) for p in points]
    # facet scale: at every vertex that actually turns, the shorter of its two segments
    seg_max = 0.0
    for i in range(1, len(src) - 1):
        e0, e1 = src[i] - src[i - 1], src[i + 1] - src[i]
        if e0.length > EPS and e1.length > EPS and e0.angle(e1, 0.0) > math.radians(0.5):
            seg_max = max(seg_max, min(e0.length, e1.length))
    P = resample(src, count=samples, closed=closed)
    n = len(P)
    h = cumulative_lengths(P, closed)[-1] / (n if closed else n - 1)
    w1 = max(2, int(math.ceil(1.05 * seg_max / h)) if h > 0 else 2)
    w2 = 2 * w1

    def idx(i):
        return i % n if closed else i

    def ok(i, reach):
        return closed or (reach <= i < n - reach)

    kinks = []
    for i in (range(n) if closed else range(1, n - 1)):
        e0, e1 = P[i] - P[idx(i - 1)], P[idx(i + 1)] - P[i]
        if e0.length > EPS and e1.length > EPS and math.degrees(e0.angle(e1, 0.0)) > kink_deg:
            if not kinks or i - kinks[-1] > 2:
                kinks.append(i)
    near_kink = lambda i, r: any(abs(i - k) <= r for k in kinks)

    def menger(w):
        k, c = [0.0] * n, [Vector((0, 0, 0))] * n
        for i in range(n):
            if not ok(i, w):
                continue
            A, B, C = P[idx(i - w)], P[i], P[idx(i + w)]
            ab, bc, ac = B - A, C - B, C - A
            den = ab.length * bc.length * ac.length
            if den > EPS:
                cr = ab.cross(bc); k[i] = 2 * cr.length / den; c[i] = cr
        return k, c

    k1, cross = menger(w1)
    k2, _ = menger(w2)
    ref = None; N = Vector((0, 0, 0))
    for c in cross:
        if c.length > 1e-12:
            ref = ref or c
            N += c if c.dot(ref) >= 0 else -c
    N = N.normalized() if N.length > 0 else Vector((0, 0, 1))
    smooth_k = [k1[i] for i in range(n) if not near_kink(i, 2 * w1)]
    kmax = max(smooth_k) if smooth_k and max(smooth_k) > 0 else 1e-9
    jumps, last = [], -10 ** 9
    for i in range(n):
        if not ok(i, 2 * w2) or near_kink(i, 2 * w2):
            continue
        d1 = abs(k1[idx(i + w1)] - k1[idx(i - w1)])
        d2 = abs(k2[idx(i + w2)] - k2[idx(i - w2)])
        if d2 > jump_frac * kmax and d1 > step_ratio * d2:
            if i - last > w1:
                jumps.append(i)
            last = i
    signs = []
    for i in range(n):
        if k1[i] > 0.08 * kmax and not near_kink(i, 2 * w1):
            s = 1 if cross[i].dot(N) >= 0 else -1
            if not signs or signs[-1] != s:
                signs.append(s)
    return {"length": h * (n if closed else n - 1), "max_curvature": kmax,
            "min_radius": 1.0 / kmax if kmax > 1e-6 else float("inf"),
            "kinks": len(kinks), "kink_at": [round(i / (n - 1), 3) for i in kinks],
            "curvature_jumps": len(jumps), "jump_at": [round(i / (n - 1), 3) for i in jumps],
            "inflections": max(0, len(signs) - 1), "window": round(w1 * h, 4), "curvature": k1}


def fairness_score(report, expected_inflections=0):
    extra = max(0, report["inflections"] - expected_inflections)
    return max(0, 100 - 20 * report["kinks"] - 8 * report["curvature_jumps"] - 4 * extra)


# ---------------------------------------------------------------- frames

def rmf_frames(points, tangents, up=(0, 0, 1), closed=False):
    """Rotation-minimising frames by double reflection (Wang, Juttler, Zheng, Liu 2008).
    Returns list of (T, U, S): tangent, up, side. No sudden flips on straights (unlike Frenet)."""
    T = [Vector(t).normalized() for t in tangents]
    up = Vector(up)
    U0 = up - up.dot(T[0]) * T[0]
    if U0.length < 1e-6:
        U0 = Vector((1, 0, 0)) - T[0].x * T[0]
    U = [U0.normalized()]
    for i in range(len(points) - 1):
        v1 = points[i + 1] - points[i]
        c1 = v1.dot(v1)
        if c1 < EPS:
            U.append(U[-1].copy()); continue
        rL = U[i] - (2 / c1) * v1.dot(U[i]) * v1
        tL = T[i] - (2 / c1) * v1.dot(T[i]) * v1
        v2 = T[i + 1] - tL
        c2 = v2.dot(v2)
        r = rL if c2 < EPS else rL - (2 / c2) * v2.dot(rL) * v2
        r = r - r.dot(T[i + 1]) * T[i + 1]
        U.append(r.normalized())
    if closed and len(points) > 2:
        # close the loop: spread the leftover roll evenly so the seam matches
        v1 = points[0] - points[-1]; c1 = v1.dot(v1) or 1
        rL = U[-1] - (2 / c1) * v1.dot(U[-1]) * v1
        tL = T[-1] - (2 / c1) * v1.dot(T[-1]) * v1
        v2 = T[0] - tL; c2 = v2.dot(v2)
        rEnd = rL if c2 < EPS else rL - (2 / c2) * v2.dot(rL) * v2
        ang = math.atan2(U[0].cross(rEnd).dot(T[0]), U[0].dot(rEnd))
        m = len(points)
        U = [Matrix.Rotation(-ang * i / m, 3, T[i]) @ U[i] for i in range(m)]
    return [(T[i], U[i], U[i].cross(T[i]).normalized()) for i in range(len(points))]


# ---------------------------------------------------------------- budgeting

def _fnum(f, s, default):
    if f is None:
        return default
    if callable(f):
        return f(s)
    if isinstance(f, (tuple, list)):
        return f[0] + (f[1] - f[0]) * s
    return f


def adaptive_stations(path, closed=False, max_turn_deg=10.0, max_len=None, radius=None, twist=None,
                      radius_tol=0.08, twist_tol=12.0, features=(), dense=600, profile=None, profile_tol=0.08):
    """Pick ring positions (normalised arc length 0..1): many on bends and where radius/twist/profile
    change, few on straights. This is where curve meshes save most of their triangles."""
    P = resample(path, count=dense, closed=closed)
    L = cumulative_lengths(P, closed)
    total = L[-1]
    rmax = max(abs(_fnum(radius, i / 50, 1.0)) for i in range(51)) or 1.0
    prof_size = 0.0
    if callable(profile):
        prof_size = max(max(Vector(q).length for q in profile(i / 20)) for i in range(21)) or 1.0

    def prof_delta(a, b):
        pa, pb = profile(a), profile(b)
        return max((Vector(x) - Vector(y)).length for x, y in zip(pa, pb)) * abs(_fnum(radius, b, 1.0))
    st = [0.0]
    acc = 0.0
    last = 0
    m = len(P)
    for i in range(1, m):
        if i < m - 1 or closed:
            e0, e1 = P[i] - P[i - 1], P[(i + 1) % m] - P[i]
            if e0.length > EPS and e1.length > EPS:
                acc += math.degrees(e0.angle(e1, 0.0))
        s, s0 = L[i] / total, st[-1]
        split = acc >= max_turn_deg
        if max_len and (L[i] - L[last]) >= max_len:
            split = True
        if radius is not None and abs(_fnum(radius, s, 1) - _fnum(radius, s0, 1)) > radius_tol * rmax:
            split = True
        if twist is not None and abs(_fnum(twist, s, 0) - _fnum(twist, s0, 0)) > twist_tol:
            split = True
        if prof_size and not split and prof_delta(s0, s) > profile_tol * prof_size * rmax:
            split = True
        if split:
            st.append(s); acc = 0.0; last = i
    if closed:
        if 1.0 - st[-1] < 0.25 / max(1, len(st)):
            st.pop()
    else:
        if 1.0 - st[-1] < 1e-4:
            st.pop()
        st.append(1.0)
    for f in features:
        st.append(min(max(f, 0.0), 1.0))
    st = sorted(set(round(x, 6) for x in st))
    return st


def step_features(s_list, eps=0.004):
    """For hard radius steps (flanges, collars): stations just before/after each step."""
    out = []
    for s in s_list:
        out += [s - eps, s, s + eps]
    return out


def estimate_sweep_tris(n_stations, n_profile, closed=False, cap_start=True, cap_end=True, pole_start=False, pole_end=False):
    rings = n_stations
    t = 2 * n_profile * (rings - 1) if not closed else 2 * n_profile * rings
    if not closed:
        # a pole end replaces a ring+cap: its band is n triangles not 2n, and needs no cap
        for cap, pole in ((cap_start, pole_start), (cap_end, pole_end)):
            if pole:
                t -= n_profile
            elif cap:
                t += n_profile
    return t


def _ceiling(cls):
    return BUDGETS.get(cls, (20000, 20000))[1]


# ---------------------------------------------------------------- mesh building

def _new_object(name, bm, color=None):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if color is not None:
        set_color(ob, color)
    return ob


def set_color(ob, rgb, name=None):
    mat = bpy.data.materials.new(name or (ob.name + "_Mat"))
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    return mat


def _uv_face(f, uvl, uvs):
    for loop, uv in zip(f.loops, uvs):
        loop[uvl].uv = uv


def _clamp01(x):
    return min(max(x, 0.0), 1.0)


def sweep(name, path, profile=None, radius=1.0, twist=0.0, closed=False, up=(0, 0, 1),
          stations=None, segments=None, max_turn_deg=10.0, max_len=None, features=(),
          caps=True, cls="small", auto_fit=True, color=None, report=None, radius_tol=0.08, twist_tol=12.0):
    """Sweep a 2D profile along a 3D path.
    path     : dense polyline (from bezier_path / catmull_rom / helix / round_corners)
    profile  : list of 2D points (x = side, y = up) or callable(s)->list (same count each call); default circle(8)
    radius   : number, (start, end) linear taper, or callable(s) - uniform profile scale. 0 at an end = pointed tip.
    twist    : degrees, (start, end), or callable(s)
    stations : explicit ring positions 0..1, else `segments` uniform, else adaptive (max_turn_deg / max_len)
    Returns the object. report (dict) receives tris_estimate, stations, length."""
    profile = profile or circle(8)
    prof = (lambda s: profile(s)) if callable(profile) else (lambda s: profile)
    P = [_v(p) for p in path]
    if closed and (P[0] - P[-1]).length < 1e-6:
        P = P[:-1]
    nprof = len(prof(0.0))
    ceiling = _ceiling(cls)

    def pick(turn, mlen):
        if stations is not None:
            return list(stations)
        if segments:
            m = segments
            return [i / m for i in range(m)] if closed else [i / m for i in range(m + 1)]
        return adaptive_stations(P, closed, turn, mlen, radius, twist, radius_tol=radius_tol, twist_tol=twist_tol,
                                 features=features,
                                 profile=profile if callable(profile) else None)

    def poles(st):
        ps = (not closed) and abs(_fnum(radius, st[0], 1)) < 1e-6
        pe = (not closed) and abs(_fnum(radius, st[-1], 1)) < 1e-6
        return ps, pe

    turn, mlen = max_turn_deg, max_len
    for _ in range(12):
        st = pick(turn, mlen)
        ps, pe = poles(st)
        est = estimate_sweep_tris(len(st), nprof, closed, caps, caps, ps, pe)
        if est <= ceiling or not auto_fit or stations is not None or segments:
            break
        turn *= 1.4
        mlen = (mlen or 1e9) * 1.4 if mlen else None
    if est > ceiling:
        raise BudgetError(f"{name}: estimated {est} tris > {cls} ceiling {ceiling}; use fewer profile points or stations")

    L = cumulative_lengths(P, closed)
    total = L[-1]
    h = total / 2000.0
    pos, tan = [], []
    for s in st:
        d = s * total
        p = point_at(P, L, d, closed)
        if closed:
            a, b = point_at(P, L, (d - h) % total, True), point_at(P, L, (d + h) % total, True)
        else:
            a, b = point_at(P, L, max(d - h, 0), False), point_at(P, L, min(d + h, total), False)
        pos.append(p); tan.append((b - a).normalized())
    frames = rmf_frames(pos, tan, up, closed)

    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rings = []
    for k, s in enumerate(st):
        T, U, S = frames[k]
        r = _fnum(radius, s, 1.0)
        tw = math.radians(_fnum(twist, s, 0.0))
        c, sn = math.cos(tw), math.sin(tw)
        if not closed and abs(r) < 1e-6 and k in (0, len(st) - 1):
            rings.append([bm.verts.new(pos[k])])
            continue
        ring = []
        for q in prof(s):
            x, y = q[0] * c - q[1] * sn, q[0] * sn + q[1] * c
            ring.append(bm.verts.new(pos[k] + S * (x * r) + U * (y * r)))
        rings.append(ring)

    nseg = len(st) if closed else len(st) - 1
    vs = [s for s in st] + ([1.0] if closed else [])
    for k in range(nseg):
        A, B = rings[k], rings[(k + 1) % len(rings)]
        v0, v1 = vs[k], vs[k + 1]
        for j in range(nprof):
            j2 = (j + 1) % nprof
            u0, u1 = j / nprof, (j + 1) / nprof
            if len(A) == 1:
                f = bm.faces.new((A[0], B[j], B[j2]))
                _uv_face(f, uvl, [((u0 + u1) / 2, v0), (u0, v1), (u1, v1)])
            elif len(B) == 1:
                f = bm.faces.new((A[j], A[j2], B[0]))
                _uv_face(f, uvl, [(u0, v0), (u1, v0), ((u0 + u1) / 2, v1)])
            else:
                f = bm.faces.new((A[j], A[j2], B[j2], B[j]))
                _uv_face(f, uvl, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    if not closed and caps:
        for ring in (rings[0], rings[-1]):
            if len(ring) < 3:
                continue
            ctr = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
            for j in range(nprof):
                f = bm.faces.new((ring[j], ring[(j + 1) % nprof], ctr))
                a = 2 * math.pi * j / nprof; b = 2 * math.pi * (j + 1) / nprof
                _uv_face(f, uvl, [(0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a)),
                                  (0.5 + 0.5 * math.cos(b), 0.5 + 0.5 * math.sin(b)), (0.5, 0.5)])
    ob = _new_object(name, bm, color)
    if report is not None:
        report.update({"tris_estimate": est, "stations": len(st), "profile": nprof, "length": round(total, 3)})
    return ob


def lathe(name, profile_rz, steps=16, cls="small", auto_fit=True, color=None, report=None, max_turn_deg=None):
    """Spin a (radius, height) profile, listed bottom -> top, around Z. r = 0 at an end makes a pole;
    r > 0 at an end gets a triangle-fan cap. max_turn_deg simplifies a dense profile first."""
    prof = [Vector((p[0], p[1], 0)) for p in profile_rz]
    if max_turn_deg:
        st = adaptive_stations(prof, False, max_turn_deg, None, features=())
        Lp = cumulative_lengths(prof)
        prof = [point_at(prof, Lp, s * Lp[-1]) for s in st]
    ceiling = _ceiling(cls)

    def est_for(n):
        t = 0
        for a, b in zip(prof, prof[1:]):
            t += n if (a.x < 1e-6 or b.x < 1e-6) else 2 * n
        t += (n if prof[0].x > 1e-6 else 0) + (n if prof[-1].x > 1e-6 else 0)
        return t
    est = est_for(steps)
    while est > ceiling and auto_fit and steps > 6:
        steps -= 2; est = est_for(steps)
    if est > ceiling:
        raise BudgetError(f"{name}: estimated {est} tris > {cls} ceiling {ceiling}")
    Lp = cumulative_lengths(prof)
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    rings = []
    for p in prof:
        if p.x < 1e-6:
            rings.append([bm.verts.new((0, 0, p.y))])
        else:
            rings.append([bm.verts.new((p.x * math.cos(2 * math.pi * j / steps), p.x * math.sin(2 * math.pi * j / steps), p.y)) for j in range(steps)])
    for k in range(len(rings) - 1):
        A, B = rings[k], rings[k + 1]
        v0, v1 = Lp[k] / Lp[-1], Lp[k + 1] / Lp[-1]
        for j in range(steps):
            j2 = (j + 1) % steps; u0, u1 = j / steps, (j + 1) / steps
            if len(A) == 1 and len(B) == 1:
                continue
            if len(A) == 1:
                f = bm.faces.new((A[0], B[j], B[j2])); _uv_face(f, uvl, [((u0 + u1) / 2, v0), (u0, v1), (u1, v1)])
            elif len(B) == 1:
                f = bm.faces.new((A[j], A[j2], B[0])); _uv_face(f, uvl, [(u0, v0), (u1, v0), ((u0 + u1) / 2, v1)])
            else:
                f = bm.faces.new((A[j], A[j2], B[j2], B[j])); _uv_face(f, uvl, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    for ring, z in ((rings[0], prof[0].y), (rings[-1], prof[-1].y)):
        if len(ring) > 1:
            ctr = bm.verts.new((0, 0, z))
            for j in range(steps):
                f = bm.faces.new((ring[j], ring[(j + 1) % steps], ctr))
                a, b = 2 * math.pi * j / steps, 2 * math.pi * (j + 1) / steps
                _uv_face(f, uvl, [(0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a)), (0.5 + 0.5 * math.cos(b), 0.5 + 0.5 * math.sin(b)), (0.5, 0.5)])
    ob = _new_object(name, bm, color)
    if report is not None:
        report.update({"tris_estimate": est, "rings": len(prof), "steps": steps})
    return ob


def _offset_polygon(pts, d, miter_limit=3.0):
    """Inset (d > 0) a closed CCW 2D polygon with clamped miters."""
    n = len(pts); out = []
    for i in range(n):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % n]
        e0, e1 = (b - a).normalized(), (c - b).normalized()
        n0, n1 = Vector((-e0.y, e0.x)), Vector((-e1.y, e1.x))  # left normals = inward for CCW
        m = n0 + n1
        if m.length < 1e-6:
            m = n0
        m.normalize()
        cosh = max(m.dot(n0), 1.0 / miter_limit)
        out.append(b + m * (d / cosh))
    return out


def _signed_area(pts):
    return 0.5 * sum(pts[i - 1].x * pts[i].y - pts[i].x * pts[i - 1].y for i in range(len(pts)))


def _seg_cross(a, b, c, d):
    """Proper 2D segment intersection (shared end points excluded)."""
    def orient(p, q, r):
        return (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
    o1, o2, o3, o4 = orient(a, b, c), orient(a, b, d), orient(c, d, a), orient(c, d, b)
    return (o1 > 0) != (o2 > 0) and (o3 > 0) != (o4 > 0) and abs(o1) > 1e-12 and abs(o2) > 1e-12 \
        and abs(o3) > 1e-12 and abs(o4) > 1e-12


def is_simple_polygon(pts):
    """True when a closed 2D outline does not cross itself (O(n^2); fine for outlines)."""
    P = [Vector((p[0], p[1])) for p in pts]
    n = len(P)
    for i in range(n):
        a, b = P[i], P[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            if _seg_cross(a, b, P[j], P[(j + 1) % n]):
                return False
    return True


def max_inset(pts):
    """Largest inset distance before an edge of a closed CCW outline collapses or flips.
    An inset by d shortens each edge by d * (tan(ta/2) + tan(tb/2)) where ta, tb are the signed turning
    angles at its ends (convex > 0, reflex < 0); the edge reverses when that exceeds its length."""
    P = [Vector((p[0], p[1])) for p in pts]
    n = len(P)
    t = []
    for i in range(n):
        e0, e1 = (P[i] - P[i - 1]), (P[(i + 1) % n] - P[i])
        ang = math.atan2(e0.x * e1.y - e0.y * e1.x, e0.dot(e1))
        t.append(math.tan(max(min(ang, math.radians(170)), math.radians(-170)) / 2))
    best = float("inf")
    for i in range(n):
        L = (P[(i + 1) % n] - P[i]).length
        k = t[i] + t[(i + 1) % n]
        if k > 1e-9:
            best = min(best, L / k)
    return best


def ear_clip(pts):
    """Triangulate a simple 2D polygon (any winding, concave OK) by ear clipping, always cutting the ear with
    the largest smallest-angle (fewer slivers). Returns index triples, wound like the input."""
    P = [Vector((p[0], p[1])) for p in pts]
    idx = list(range(len(P)))
    if _signed_area(P) < 0:
        idx.reverse(); rev = True
    else:
        rev = False

    def cross(o, a, b):
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

    def inside(p, a, b, c):
        return cross(a, b, p) >= -1e-12 and cross(b, c, p) >= -1e-12 and cross(c, a, p) >= -1e-12

    def min_angle(a, b, c):
        def ang(o, p, q):
            u, v = p - o, q - o
            if u.length < 1e-12 or v.length < 1e-12:
                return 0.0
            return u.angle(v, 0.0)
        return min(ang(a, b, c), ang(b, c, a), ang(c, a, b))
    tris = []
    while len(idx) > 3:
        best = None
        m = len(idx)
        for k in range(m):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % m]
            a, b, c = P[i0], P[i1], P[i2]
            if cross(a, b, c) <= 1e-14:
                continue
            if any(inside(P[j], a, b, c) for j in idx if j not in (i0, i1, i2)
                   and (P[j] - a).length > 1e-9 and (P[j] - b).length > 1e-9 and (P[j] - c).length > 1e-9):
                continue
            q = min_angle(a, b, c)
            if best is None or q > best[0]:
                best = (q, k)
        if best is None:          # numerically stuck (collinear run): cut the flattest vertex
            k = min(range(m), key=lambda k: abs(cross(P[idx[k - 1]], P[idx[k]], P[idx[(k + 1) % m]])))
        else:
            k = best[1]
        tris.append((idx[k - 1], idx[k], idx[(k + 1) % m]))
        idx.pop(k)
    tris.append(tuple(idx))
    return [(c, b, a) for a, b, c in tris] if rev else tris


def mirror_outline(half, axis_x=0.0):
    """Author a symmetric outline as its RIGHT half, listed from the top point on the mirror line down to the
    bottom point on the mirror line (both get x = axis_x). Returns the full closed outline: exact mirror
    symmetry, the point at bottom centre. Never draw both halves by hand."""
    H = [Vector((p[0], p[1])) for p in half]
    H[0].x = axis_x; H[-1].x = axis_x
    left = [Vector((2 * axis_x - p.x, p.y)) for p in reversed(H[1:-1])]
    return H + left


def hex_rgb(h):
    """'#E0A530' -> (r, g, b) floats 0-1 in sRGB."""
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def extrude_outline(name, outline, depth, bevel=0.1, bevel_segs=1, cls="small", color=None, report=None):
    """Thick slab from a closed 2D outline (XY), centred on Z, with chamfer (segs=1) or round bevel.
    Caps are triangulated (beauty), no n-gons. UVs: planar XY into 0-1.
    The bevel is clamped to what the outline allows (max_inset: no edge may collapse or flip at the corners
    of stars, crosses, crescents, gears) and every inset ring is checked to be a simple polygon; a looping
    inset fills the cap with overlapping triangles (a visible 'square patch'). report gets bevel_used."""
    pts = [Vector((p[0], p[1])) for p in outline]
    if _signed_area(pts) < 0:
        pts = pts[::-1]
    # drop near-duplicate and collinear points (rounding nearly straight corners makes clusters of them);
    # they give sliver cap triangles that cleanup later dissolves into n-gons
    span0 = max(max(p.x for p in pts) - min(p.x for p in pts), max(p.y for p in pts) - min(p.y for p in pts)) or 1.0
    keep = []
    for i, p in enumerate(pts):
        a, c = pts[i - 1], pts[(i + 1) % len(pts)]
        e0, e1 = p - a, c - p
        if e0.length < 2e-3 * span0:
            continue
        if e1.length > 1e-12 and e0.length > 1e-12 and e0.angle(e1, 0.0) < math.radians(0.5):
            continue
        keep.append(p)
    pts = keep if len(keep) >= 3 else pts
    if not is_simple_polygon(pts):
        raise ValueError(f"{name}: outline crosses itself")
    n = len(pts)
    h = depth / 2.0
    b = min(bevel, h * 0.999) if bevel > 0 else 0.0
    if b > 0:
        b = min(b, 0.8 * max_inset(pts))
        for _ in range(8):   # miter clamping can still loop a ring: shrink until the ring is simple
            if is_simple_polygon(_offset_polygon(pts, b)):
                break
            b *= 0.6
    layers = []  # (inset, z)
    if b > 1e-5:
        for j in range(bevel_segs + 1):
            ph = (math.pi / 2) * j / bevel_segs
            layers.append((b - b * math.cos(ph), h - b + b * math.sin(ph)))
        front = layers
        back = [(i, -z) for (i, z) in reversed(front)]
        if abs(h - b) < 1e-6:
            back = back[:-1]
        layers = back + front
    else:
        b = 0.0
        layers = [(0.0, -h), (0.0, h)]
    est = 2 * n * (len(layers) - 1) + 2 * (n - 2)
    if est > _ceiling(cls):
        raise BudgetError(f"{name}: estimated {est} tris > {cls} ceiling {_ceiling(cls)}")
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts)))
    span = max(hi.x - lo.x, hi.y - lo.y) or 1.0
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    rings = []
    for inset, z in layers:
        poly = _offset_polygon(pts, inset) if inset > 0 else pts
        rings.append([bm.verts.new((p.x, p.y, z)) for p in poly])
    uv = lambda v: (_clamp01((v.co.x - lo.x) / span), _clamp01((v.co.y - lo.y) / span))
    for k in range(len(rings) - 1):
        A, B = rings[k], rings[k + 1]
        for j in range(n):
            j2 = (j + 1) % n
            f = bm.faces.new((A[j], A[j2], B[j2], B[j]))
            _uv_face(f, uvl, [uv(v) for v in f.verts])
    # caps: ear clipping on the 2D ring (bmesh's BEAUTY ngon fill produced triangles outside concave
    # outlines - they crossed the bevel faces and showed as a square patch on star emblems)
    for ring, flip in ((rings[-1], False), (rings[0], True)):
        for a, b_, c in ear_clip([v.co.to_2d() for v in ring]):
            tri = (ring[a], ring[b_], ring[c]) if not flip else (ring[c], ring[b_], ring[a])
            f = bm.faces.new(tri)
            _uv_face(f, uvl, [uv(v) for v in f.verts])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    ob = _new_object(name, bm, color)
    if report is not None:
        report.update({"tris_estimate": est, "layers": len(layers), "outline_pts": n, "bevel_used": round(b, 5)})
    return ob


# ---------------------------------------------------------------- object utilities

def join(name, objs):
    """Merge several builder outputs into one mesh object (one material: the first object's)."""
    bm = bmesh.new()
    for o in objs:
        tmp = o.data.copy(); tmp.transform(o.matrix_world)
        bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    mat = objs[0].data.materials[0] if objs[0].data.materials else None
    for o in objs:
        me = o.data; bpy.data.objects.remove(o, do_unlink=True)
        if me.users == 0:
            bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    me.materials.clear()
    if mat:
        me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
    return ob


def deform(ob, fn):
    """Apply fn(Vector) -> Vector to every vertex (bends, curls, folds). Topology unchanged."""
    for v in ob.data.vertices:
        v.co = fn(v.co.copy())
    ob.data.update()
    return ob


def paint(ob, fn, per="face", name="Col"):
    """Vertex colours (face-corner, byte sRGB) for stylised kits: one material, crisp colour regions.
    fn(info) -> (r, g, b) sRGB 0-1 or '#RRGGBB'. info has: center (face centre, object space), normal,
    uv (face-average UV: sweeps v = position along the path, u = around the profile; lathe v = along
    the profile), index; with per="corner" also co (this corner's vertex) and luv (this corner's UV),
    so colours can blend along a sweep. Repainting replaces the attribute. Pair with vertex_color_material."""
    from types import SimpleNamespace
    me = ob.data
    if name in me.color_attributes:
        me.color_attributes.remove(me.color_attributes[name])
    att = me.color_attributes.new(name, "BYTE_COLOR", "CORNER")
    uvl = me.uv_layers.active
    for p in me.polygons:
        luvs = [uvl.data[li].uv.copy() for li in p.loop_indices] if uvl else [Vector((0, 0))] * p.loop_total
        info = SimpleNamespace(center=p.center.copy(), normal=p.normal.copy(), index=p.index,
                               uv=sum(luvs, Vector((0, 0))) / len(luvs))
        col = None if per == "corner" else fn(info)
        for k, li in enumerate(p.loop_indices):
            if per == "corner":
                info.co = me.vertices[me.loops[li].vertex_index].co.copy(); info.luv = luvs[k]
                col = fn(info)
            c = hex_rgb(col) if isinstance(col, str) else col
            att.data[li].color_srgb = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = att
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
    return att


def vertex_color_material(ob, name="LF_VertexColor", attr="Col"):
    """One white material whose Base Color reads the colour attribute, so glTF exports COLOR_0 and Roblox
    shows the vertex colours (set MeshPart.Color to white in Studio)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (1, 1, 1, 1)
    mat.use_backface_culling = True     # glTF doubleSided=false: closed meshes must not import as DoubleSided
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    if nt is not None and not any(n.type == "VERTEX_COLOR" for n in nt.nodes):
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
            out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
            nt.links.new(bsdf.outputs[0], out.inputs[0])
        vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = attr
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.6
    ob.data.materials.clear(); ob.data.materials.append(mat)
    return mat


def curve_object(name, path, bevel_depth=0.1, bevel_resolution=1, resolution_u=6, poly=True):
    """Editable Blender curve (poly or Bezier with auto handles) for hand-tweaking in the GUI.
    Convert with bpy.ops.object.convert(target='MESH') or measure_curve_tris() first."""
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"
    cu.bevel_depth = bevel_depth; cu.bevel_resolution = bevel_resolution; cu.resolution_u = resolution_u
    cu.use_fill_caps = True
    if poly:
        sp = cu.splines.new("POLY"); sp.points.add(len(path) - 1)
        for p, q in zip(sp.points, path):
            p.co = (*_v(q), 1.0)
    else:
        sp = cu.splines.new("BEZIER"); sp.bezier_points.add(len(path) - 1)
        for p, q in zip(sp.bezier_points, path):
            p.co = _v(q); p.handle_left_type = p.handle_right_type = "AUTO"
    ob = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(ob)
    return ob


def measure_curve_tris(ob):
    """Triangles a curve object would cost once converted to mesh."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    t = sum(len(p.vertices) - 2 for p in me.polygons)
    ob.evaluated_get(dg).to_mesh_clear()
    return t
