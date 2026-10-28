"""LihFolk Blender helpers for Roblox-ready models (Blender 4.1+, tested on 5.2).

Use from Blender MCP (execute_blender_code) or headless:
    import sys; sys.path.append(r"<plugin>/skills/roblox-blender-modeling/scripts"); import lihfolk_bpy as lf

Main entry points:
    lf.setup_scene()                         1 Blender unit = 1 stud, clean units
    lf.finish(ob, style="soft")              bevel + weighted normals (or flat), cleanup, apply transforms
    lf.set_origin(ob, "bottom")              bottom | back | corner | center
    lf.qa_mesh(ob, budget)                   automated gate (dict); lf.gate(ob, cls) -> (passed, report)
    lf.render_review(ob, out_dir)            front / 3-4 / top / silhouette PNGs for the visual rubric
                                             (+ close-ups of child features with features=[...])
    lf.export_glb(ob, path)                  Roblox-correct GLB export (modifiers applied, vertex colors kept)

Geometry-correctness checks (feed gate() hard gates A15-A18):
    lf.symmetry_error(ob, "X")               mirror each vertex across the bbox mid-plane -> nearest vertex, / size
    lf.alignment_report(parts, parent)       feature centres vs the parent's centre / axis, / parent size
    lf.seated(feature, surface)              gap (floating) or penetration between a feature and its surface
    lf.self_intersections(ob)                faces of one shell crossing each other (BVH overlap, non-adjacent)
    lf.planar_cap_check(ob)                  coplanar caps with overlapping / folded triangles
    lf.shading_artifacts(ob)                 degenerate faces and faces flipped against all their neighbours
"""
import bpy, bmesh, math, os
from mathutils import Vector, geometry as _geo
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

# Proposed class budgets (tris): (target_max, ceiling). See references/quality-research.md section 2.7.
BUDGETS = {
    "tiny": (150, 300), "small": (600, 1500), "medium": (2000, 4000), "rock": (400, 1000),
    "tree": (2000, 5000), "weapon": (2500, 4000), "module": (800, 2000), "building": (6000, 10000),
    "creature": (5000, 10742), "hero": (10000, 20000),
}
HARD_TRIS = 20000


def setup_scene():
    s = bpy.context.scene
    s.unit_settings.system = "NONE"
    s.unit_settings.scale_length = 1.0
    return s


def _activate(ob):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def cleanup(ob, merge_dist=1e-4):
    """Merge doubles, drop loose/degenerate geometry, recalc normals outward."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge_dist)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=merge_dist)
    loose = [v for v in bm.verts if not v.link_edges]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    wires = [e for e in bm.edges if e.is_wire]
    bmesh.ops.delete(bm, geom=wires, context="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free(); me.update()


def apply_transforms(ob):
    _activate(ob)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def finish(ob, style="soft", bevel_width=0.08, segments=1, smooth_angle=30):
    """Edge treatment for the house style.
    soft    : 1-seg bevel (angle limit) + harden normals + Weighted Normal  -> chunky stylized look
    faceted : flat shading, no bevel                                       -> low-poly faceted look
    smooth  : Smooth by Angle only (organics)
    """
    apply_transforms(ob)
    cleanup(ob)
    if style == "soft":
        bv = ob.modifiers.new("LF_Bevel", "BEVEL")
        bv.width = bevel_width; bv.segments = segments
        bv.limit_method = "ANGLE"; bv.angle_limit = math.radians(smooth_angle)
        bv.harden_normals = True; bv.use_clamp_overlap = True
        wn = ob.modifiers.new("LF_WeightedNormal", "WEIGHTED_NORMAL")
        wn.keep_sharp = True; wn.weight = 50
        _activate(ob); bpy.ops.object.shade_smooth()
    elif style == "faceted":
        _activate(ob); bpy.ops.object.shade_flat()
    else:
        _activate(ob); bpy.ops.object.shade_auto_smooth(angle=math.radians(smooth_angle))
    return ob


def set_origin(ob, where="bottom", at=None):
    """bottom = bottom-center (floor props), back = back-center (wall props), corner = min corner (modular), center,
    point = the world point `at` (e.g. a weapon's grip centre)."""
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    target = {"bottom": Vector((c.x, c.y, mn.z)), "back": Vector((c.x, mx.y, c.z)),
              "corner": mn, "center": c, "point": Vector(at) if at is not None else c}[where]
    cur = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = target
    _activate(ob); bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = cur
    ob.location = (0, 0, 0) if where != "corner" else ob.location
    return ob


def qa_mesh(ob, tri_budget=HARD_TRIS, tex_px=1024):
    """Automated gate metrics (tested against a deliberately broken mesh in Blender 5.2)."""
    r = {"name": ob.name}
    r["scale_applied"] = all(abs(s - 1) < 1e-6 for s in ob.scale)
    r["rotation_applied"] = all(abs(a) < 1e-6 for a in ob.rotation_euler)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    bm = bmesh.new(); bm.from_mesh(me)
    r["tris"] = sum(len(f.verts) - 2 for f in bm.faces)
    r["ngons"] = sum(1 for f in bm.faces if len(f.verts) > 4)
    r["non_manifold_edges"] = sum(1 for e in bm.edges if not e.is_manifold and not e.is_wire)
    r["boundary_edges"] = sum(1 for e in bm.edges if e.is_boundary)
    r["inconsistent_normal_edges"] = sum(1 for e in bm.edges if e.is_manifold and not e.is_contiguous)
    r["loose_verts"] = sum(1 for v in bm.verts if not v.link_edges)
    r["loose_edges"] = sum(1 for e in bm.edges if e.is_wire)
    r["degenerate_faces"] = sum(1 for f in bm.faces if f.calc_area() < 1e-8)
    r["signed_volume"] = bm.calc_volume(signed=True)
    uv = bm.loops.layers.uv.active
    r["uv_layers"] = len(me.uv_layers)
    if uv:
        us = [l[uv].uv for f in bm.faces for l in f.loops]
        r["uv_out_of_0_1"] = sum(1 for u in us if not (-1e-5 <= u.x <= 1 + 1e-5 and -1e-5 <= u.y <= 1 + 1e-5))
        a3 = sum(f.calc_area() for f in bm.faces)
        def uva(f):
            p = [l[uv].uv for l in f.loops]
            return abs(sum(p[i].x * p[(i + 1) % len(p)].y - p[(i + 1) % len(p)].x * p[i].y for i in range(len(p)))) / 2
        auv = sum(uva(f) for f in bm.faces)
        r["uv_coverage"] = auv
        r["texel_px_per_stud"] = math.sqrt(auv / a3) * tex_px if a3 else None
    r["materials"] = len([m for m in ob.data.materials if m])
    r["dimensions"] = tuple(round(d, 3) for d in ob.dimensions)
    r["within_budget"] = r["tris"] <= tri_budget
    bm.free(); ob.evaluated_get(dg).to_mesh_clear()
    return r


# ---------------------------------------------------------------- geometry-correctness checks (A15-A18)

def _eval_bm(ob, world=True):
    """bmesh of the evaluated mesh (modifiers applied), in world space by default. Caller frees it."""
    dg = bpy.context.evaluated_depsgraph_get()
    eo = ob.evaluated_get(dg)
    me = eo.to_mesh()
    bm = bmesh.new(); bm.from_mesh(me)
    eo.to_mesh_clear()
    if world:
        bm.transform(ob.matrix_world)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    bm.normal_update()
    return bm


def _bounds(pts):
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def symmetry_error(ob, axis="X", centre=None):
    """Mirror every vertex across the plane through the bbox centre (or world coordinate `centre`) normal to
    `axis`, find the nearest real vertex, and return the worst distance divided by the largest bbox size.
    0 = perfect mirror; > 0.01 (1 %) means visibly lopsided. Author symmetric objects as half + mirror."""
    k = "XYZ".index(axis.upper())
    bm = _eval_bm(ob)
    pts = [v.co.copy() for v in bm.verts]
    bm.free()
    if not pts:
        return 0.0
    lo, hi = _bounds(pts)
    size = max(hi - lo) or 1.0
    c = (lo[k] + hi[k]) / 2 if centre is None else centre
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    worst = 0.0
    for p in pts:
        q = p.copy(); q[k] = 2 * c - q[k]
        worst = max(worst, kd.find(q)[2])
    return worst / size


def _centre(ob, mode="bbox"):
    bm = _eval_bm(ob)
    pts = [v.co.copy() for v in bm.verts]
    if mode == "area":
        tot = sum(f.calc_area() for f in bm.faces) or 1.0
        c = sum((f.calc_center_median() * f.calc_area() for f in bm.faces), Vector()) / tot
    else:
        lo, hi = _bounds(pts); c = (lo + hi) / 2
    lo, hi = _bounds(pts)
    bm.free()
    return c, lo, hi


def alignment_report(parts, parent, axes="X", mode="bbox", target=None):
    """Offsets of each feature's centre from the parent's centre (or world point `target`) along `axes`,
    divided by the parent's largest size. parts: objects or (name, object). mode: "bbox" or "area"
    (surface centroid: the visual centre of a star or a pointed shield). Use BEFORE joining parts.
    Returns [{"name", "offset": {axis: frac}, "max": frac}] -> gate(..., align=...) fails A16 above 2 %."""
    pc, plo, phi = _centre(parent, mode)
    size = max(phi - plo) or 1.0
    c = Vector(target) if target is not None else pc
    out = []
    for it in parts:
        name, o = it if isinstance(it, tuple) else (it.name, it)
        fc = _centre(o, mode)[0]
        off = {a: round((fc["XYZ".index(a)] - c["XYZ".index(a)]) / size, 5) for a in axes.upper()}
        out.append({"name": name, "offset": off, "max": max(abs(v) for v in off.values())})
    return out


def seated(feature, surface, name=None):
    """Gap (feature floating off) or penetration (sunk in) between a feature and the surface it sits on.
    Signed distance of the feature's vertices to the surface; any face overlap counts as contact.
    Returns {"name", "gap", "penetration", "gap_frac", "seated"} -> gate(..., seats=[...]) fails A16 when it floats."""
    bs = _eval_bm(surface); bf = _eval_bm(feature)
    lo, hi = _bounds([v.co for v in bs.verts])
    size = max(hi - lo) or 1.0
    ts, tf = BVHTree.FromBMesh(bs), BVHTree.FromBMesh(bf)
    dmin = float("inf")
    for v in bf.verts:
        loc, nrm, idx, dist = ts.find_nearest(v.co)
        if loc is None:
            continue
        d = dist if (v.co - loc).dot(nrm) >= 0 else -dist
        dmin = min(dmin, d)
    touching = bool(tf.overlap(ts))
    bs.free(); bf.free()
    gap = 0.0 if touching else max(0.0, dmin)
    return {"name": name or feature.name, "gap": round(gap, 5), "penetration": round(max(0.0, -dmin), 5),
            "gap_frac": round(gap / size, 5), "seated": gap <= 0.01 * size}


def self_intersections(ob, max_examples=5):
    """Face pairs that cross each other inside ONE connected shell (folded caps, looped insets, sweeps that
    pass through themselves). Faces sharing a vertex are ignored. Separate shells that overlap on purpose
    (a star pushed through a plate) are counted apart as cross_shell, which is not a failure."""
    bm = _eval_bm(ob, world=False)
    par = list(range(len(bm.verts)))

    def find(i):
        while par[i] != i:
            par[i] = par[par[i]]; i = par[i]
        return i
    for e in bm.edges:
        a, b = find(e.verts[0].index), find(e.verts[1].index)
        if a != b:
            par[a] = b
    tree = BVHTree.FromBMesh(bm)
    seen = set(); same = cross = 0; ex = []
    for i, j in tree.overlap(tree):
        if i == j:
            continue
        key = (min(i, j), max(i, j))
        if key in seen:
            continue
        seen.add(key)
        fi, fj = bm.faces[key[0]], bm.faces[key[1]]
        if set(fi.verts) & set(fj.verts):
            continue
        if find(fi.verts[0].index) == find(fj.verts[0].index):
            same += 1
            if len(ex) < max_examples:
                ex.append(key)
        else:
            cross += 1
    bm.free()
    return {"self": same, "cross_shell": cross, "examples": ex}


def planar_cap_check(ob, angle_deg=1.0):
    """Groups connected faces that share a plane (normal within angle_deg, same offset) and looks for
    overlapping or folded triangles inside each group: the 'square patch' you get when an inset outline
    loops over itself and the cap fill stacks triangles. Returns {"regions", "overlap_pairs", "examples"}."""
    bm = _eval_bm(ob, world=False)
    lo, hi = _bounds([v.co for v in bm.verts]) if bm.verts else (Vector(), Vector((1, 1, 1)))
    tol = 1e-4 * (max(hi - lo) or 1.0)
    cos_t = math.cos(math.radians(angle_deg))
    seen = set(); regions = []
    for f in bm.faces:
        if f.index in seen:
            continue
        n0, p0 = f.normal.copy(), f.verts[0].co.copy()
        reg = [f]; seen.add(f.index); stack = [f]
        while stack:
            g = stack.pop()
            for e in g.edges:
                for h in e.link_faces:
                    if h.index in seen or h.normal.dot(n0) < cos_t:
                        continue
                    if any(abs((v.co - p0).dot(n0)) > tol for v in h.verts):
                        continue
                    seen.add(h.index); reg.append(h); stack.append(h)
        if len(reg) >= 2:
            regions.append((n0, reg))
    pairs = 0; ex = []
    for n0, reg in regions:
        if len(reg) > 3000:
            continue
        ax = n0.orthogonal().normalized(); ay = n0.cross(ax)
        tris = []
        for f in reg:
            p = [Vector((v.co.dot(ax), v.co.dot(ay))) for v in f.verts]
            c = sum(p, Vector((0, 0))) / len(p)
            p = [c + (q - c) * 0.999 for q in p]   # shrink a hair so shared edges never count as overlap
            ts = [(p[0], p[k], p[k + 1]) for k in range(1, len(p) - 1)]
            bb = (min(q.x for q in p), min(q.y for q in p), max(q.x for q in p), max(q.y for q in p))
            tris.append((f, set(f.verts), ts, bb))
        for a in range(len(tris)):
            fa, va, ta, ba = tris[a]
            for b in range(a + 1, len(tris)):
                fb, vb, tb, bb = tris[b]
                if va & vb or ba[2] < bb[0] or bb[2] < ba[0] or ba[3] < bb[1] or bb[3] < ba[1]:
                    continue
                if any(_geo.intersect_tri_tri_2d(*x, *y) for x in ta for y in tb):
                    pairs += 1
                    if len(ex) < 5:
                        ex.append((fa.index, fb.index))
    bm.free()
    return {"regions": len(regions), "overlap_pairs": pairs, "examples": ex}


def shading_artifacts(ob):
    """Faces that shade wrong: degenerate (near-zero area) and flipped (normal opposite to every neighbour)."""
    bm = _eval_bm(ob, world=False)
    deg = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
    flipped = 0
    for f in bm.faces:
        nb = [h for e in f.edges for h in e.link_faces if h is not f]
        if len(nb) >= 2 and all(f.normal.dot(h.normal) < -0.3 for h in nb):
            flipped += 1
    bm.free()
    return {"degenerate": deg, "flipped": flipped}


def gate(ob, cls="small", foliage_card=False, symmetric=None, align=None, seats=None, surface_checks=True,
         sym_tol=0.01, align_tol=0.02, seat_tol=0.01):
    """Hard pass/fail gate (checks A1-A6, A8, A10, A15-A18). Returns (passed, failures, report).
    symmetric : None | "X" | "Y" | "Z" | "XY"...  object is mirror-symmetric by design (shields, bottles, swords...)
                -> A15 fails when symmetry_error > sym_tol (1 % of size)
    align     : list from alignment_report() (features meant to be centred) -> A16 fails when any is off by > align_tol
    seats     : list of seated() dicts (features meant to sit on a surface) -> A16 fails when one floats
    surface_checks : A17 no self-intersecting shells, A18 clean planar caps / no flipped or degenerate faces."""
    target, ceiling = BUDGETS.get(cls, (HARD_TRIS, HARD_TRIS))
    r = qa_mesh(ob, ceiling)
    fails = []
    if symmetric:
        r["symmetry_error"] = {a: round(symmetry_error(ob, a), 5) for a in symmetric.upper()}
        for a, e in r["symmetry_error"].items():
            if e > sym_tol:
                fails.append(f"A15 not symmetric in {a}: error {e:.2%} of size > {sym_tol:.0%}")
    for it in (align or []):
        if it["max"] > align_tol:
            fails.append(f"A16 feature '{it['name']}' off-centre by {it['max']:.2%} of size > {align_tol:.0%}")
    for it in (seats or []):
        if it["gap_frac"] > seat_tol:
            fails.append(f"A16 feature '{it['name']}' floats {it['gap']:.3f} studs above its surface")
    if align:
        r["alignment"] = align
    if seats:
        r["seats"] = seats
    if surface_checks:
        si = self_intersections(ob)
        pc = planar_cap_check(ob)
        sa = shading_artifacts(ob)
        r["self_intersections"] = si["self"]; r["cross_shell_overlaps"] = si["cross_shell"]
        r["cap_overlaps"] = pc["overlap_pairs"]; r["flipped_faces"] = sa["flipped"]
        if si["self"]:
            fails.append(f"A17 {si['self']} self-intersecting face pairs within one shell")
        if pc["overlap_pairs"] or sa["flipped"]:
            fails.append(f"A18 dirty caps: {pc['overlap_pairs']} overlapping coplanar face pairs, {sa['flipped']} flipped faces")
    if r["tris"] > HARD_TRIS: fails.append(f"A1 tris {r['tris']} > hard 20000")
    elif r["tris"] > ceiling: fails.append(f"A1 tris {r['tris']} > {cls} ceiling {ceiling}")
    if not foliage_card and (r["boundary_edges"] or r["non_manifold_edges"]):
        fails.append(f"A2 not watertight (boundary {r['boundary_edges']}, non-manifold {r['non_manifold_edges']})")
    if r["inconsistent_normal_edges"] or (not foliage_card and r["signed_volume"] < 0):
        fails.append("A3 flipped/inconsistent normals")
    if r["ngons"]: fails.append(f"A4 {r['ngons']} n-gons")
    if r["loose_verts"] or r["loose_edges"] or r["degenerate_faces"]: fails.append("A5 loose/degenerate geometry")
    if not (r["scale_applied"] and r["rotation_applied"]): fails.append("A6 transforms not applied")
    if r["uv_layers"] > 1: fails.append("A8 more than one UV map")
    if r.get("uv_out_of_0_1"): fails.append("A8 UVs outside 0-1")
    if r["materials"] > 1: fails.append("A10 more than one material")
    if max(r["dimensions"]) > 2048: fails.append("A7 larger than 2048 studs")
    r["budget_note"] = "over target - justify or simplify" if r["tris"] > target else "ok"
    return (not fails), fails, r


def render_review(ob, out_dir, size=512, features=None, color=None):
    """Renders front, three-quarter, top and silhouette views (Workbench) for the visual rubric V1-V9.
    features: optional close-ups of child features (star, gem, guard, cork...) so small cap artifacts,
              pinches and seams are visible: list of (name, centre_xyz_world, radius) or objects.
              Each gives <ob>_close_<name>_studio.png and _flat.png at `size` px (three-quarter camera).
    color   : Workbench colour source; None = vertex colours when the mesh has a colour attribute, else material."""
    out = _render_views(ob, out_dir, size, color)
    for f in (features or []):
        if isinstance(f, bpy.types.Object):
            pts = [f.matrix_world @ Vector(c) for c in f.bound_box]
            c = sum(pts, Vector()) / 8
            f = (f.name, c, max((p - c).length for p in pts))
        name, c, r = f
        for light in ("studio", "flat"):
            out[f"close_{name}_{light}"] = _render_views(ob, out_dir, size, color, close=(name, Vector(c), r, light))
    return out


def _render_views(ob, out_dir, size=512, color=None, close=None):
    os.makedirs(out_dir, exist_ok=True)
    if color is None:
        ca = getattr(ob.data, "color_attributes", None)
        color = "VERTEX" if ca is not None and len(ca) else "MATERIAL"
    s = bpy.context.scene
    prev = (s.render.engine, s.camera, s.render.resolution_x, s.render.resolution_y, s.render.filepath)
    s.render.engine = "BLENDER_WORKBENCH"
    s.render.resolution_x = s.render.resolution_y = size
    sh = s.display.shading
    hidden = [o for o in s.objects if o is not ob and not o.hide_render and o.type in {"MESH", "CURVE"}]
    for o in hidden: o.hide_render = True
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    ctr = sum(pts, Vector()) / 8
    rad = max((p - ctr).length for p in pts) or 1
    cam_data = bpy.data.cameras.new("LF_ReviewCam"); cam_data.lens = 50
    cam = bpy.data.objects.new("LF_ReviewCam", cam_data); s.collection.objects.link(cam); s.camera = cam
    dist = rad * 3.2
    views = {"front": Vector((0, -1, 0.15)), "three_quarter": Vector((0.8, -1, 0.6)), "top": Vector((0.001, -0.001, 1))}
    todo = list(views.items()) + [("silhouette", views["three_quarter"])]
    if close is not None:
        cname, ctr, crad, light = close
        dist = max(crad, 1e-3) * 3.2
        todo = [(f"close_{cname}_{light}", views["three_quarter"])]
    out = {}
    prev_world_color = None
    try:
        sh.light = "STUDIO"; sh.color_type = color; sh.show_cavity = True; sh.show_object_outline = True
        if close is not None and close[3] == "flat":
            sh.light = "FLAT"; sh.show_cavity = False
        for name, d in todo:
            if name == "silhouette":
                sh.light = "FLAT"; sh.color_type = "SINGLE"; sh.single_color = (0, 0, 0)
                sh.show_cavity = False; sh.show_object_outline = False
                if s.world is None:
                    s.world = bpy.data.worlds.new("LF_ReviewWorld")
                prev_world_color = tuple(s.world.color)
                s.world.color = (1, 1, 1)
            cam.location = ctr + d.normalized() * dist
            cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
            s.render.filepath = os.path.join(out_dir, f"{ob.name}_{name}.png")
            bpy.ops.render.render(write_still=True)
            out[name] = s.render.filepath
        if close is not None:
            return out[todo[0][0]]
    finally:
        if prev_world_color is not None:
            s.world.color = prev_world_color
        sh.light = "STUDIO"; sh.color_type = "MATERIAL"; sh.show_cavity = True; sh.show_object_outline = True
        bpy.data.objects.remove(cam, do_unlink=True)
        for o in hidden: o.hide_render = False
        s.render.engine, s.camera, s.render.resolution_x, s.render.resolution_y, s.render.filepath = prev
    return out


def export_glb(ob, path):
    """Roblox-correct GLB: 1 unit = 1 stud, modifiers applied, Y-up, vertex colors kept, no Draco."""
    _activate(ob)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_normals=True,
        export_vertex_color="ACTIVE", export_draco_mesh_compression_enable=False)
    return path


def export_fbx(ob, path):
    """FBX alternative. FBX_SCALE_UNITS prevents the 100x import scale."""
    _activate(ob)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS", axis_forward="Z", axis_up="Y",
        add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True,
        use_mesh_modifiers=True)
    return path
