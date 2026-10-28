"""LihFolk Blender helpers for Roblox-ready models (Blender 4.1+, tested on 5.2).

Use from Blender MCP (execute_blender_code) or headless:
    import sys; sys.path.append(r"<plugin>/skills/roblox-blender-modeling/scripts"); import lihfolk_bpy as lf

Main entry points:
    lf.setup_scene()                         1 Blender unit = 1 stud, clean units
    lf.finish(ob, style="soft")              bevel + weighted normals (or flat), cleanup, apply transforms
    lf.set_origin(ob, "bottom")              bottom | back | corner | center
    lf.qa_mesh(ob, budget)                   automated gate (dict); lf.gate(ob, cls) -> (passed, report)
    lf.render_review(ob, out_dir)            front / 3-4 / top / silhouette PNGs for the visual rubric
    lf.export_glb(ob, path)                  Roblox-correct GLB export (modifiers applied, vertex colors kept)
"""
import bpy, bmesh, math, os
from mathutils import Vector

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


def set_origin(ob, where="bottom"):
    """bottom = bottom-center (floor props), back = back-center (wall props), corner = min corner (modular), center."""
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    target = {"bottom": Vector((c.x, c.y, mn.z)), "back": Vector((c.x, mx.y, c.z)),
              "corner": mn, "center": c}[where]
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


def gate(ob, cls="small", foliage_card=False):
    """Hard pass/fail gate (checks A1-A6, A8, A10). Returns (passed, failures, report)."""
    target, ceiling = BUDGETS.get(cls, (HARD_TRIS, HARD_TRIS))
    r = qa_mesh(ob, ceiling)
    fails = []
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


def render_review(ob, out_dir, size=512):
    """Renders front, three-quarter, top and silhouette views (Workbench) for the visual rubric V1-V9."""
    os.makedirs(out_dir, exist_ok=True)
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
    out = {}
    prev_world_color = None
    try:
        sh.light = "STUDIO"; sh.color_type = "MATERIAL"; sh.show_cavity = True; sh.show_object_outline = True
        for name, d in list(views.items()) + [("silhouette", views["three_quarter"])]:
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
