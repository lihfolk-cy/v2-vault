"""Stylised market shop stand, following 14 Low-Poly and Stylized Modeling: thick parts, bevels, tilts of 2 to 6
degrees, varied plank widths, one focal feature (the striped awning and sign), studs as units, faces -Y.
blender -b --factory-startup --python build_shop_stand.py"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Euler

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"); os.makedirs(OUT, exist_ok=True)  # renders and exports land here
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
def lin(h): return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1,)
MATS = {}
def mat(name, hexc, rough=0.75, emit=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True; p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = lin(hexc); p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = lin(hexc); p.inputs["Emission Strength"].default_value = emit
    MATS[name] = m; return m
WOOD, WOOD2, WOODD = mat("WoodLight", "C98A4E"), mat("WoodMid", "A5693C"), mat("WoodDark", "6E4426")
RED, CREAM = mat("AwningRed", "D9483B", 0.85), mat("AwningCream", "F3E4C4", 0.85)
GOLD, METAL = mat("Gold", "F2C14E", 0.35), mat("Iron", "4A4F57", 0.5)
APPLE, LEAF = mat("Apple", "C8312F", 0.45), mat("Leaf", "5FA343", 0.7)
POT_B, POT_P, POT_G = mat("PotionBlue", "4CB5E8", 0.15, 0.6), mat("PotionPink", "E2589B", 0.15, 0.6), mat("PotionGreen", "7BD66A", 0.15, 0.6)
GLOW, SIGNTXT = mat("LanternGlow", "FFD27A", 0.3, 6.0), mat("SignText", "FFF3D6", 0.6)
parts = []

def obj(name, bm, m, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, seg=2, smooth=False):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o)
    o.location = loc; o.rotation_euler = Euler([math.radians(a) for a in rot]); me.materials.append(m)
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL"); b.width = bevel; b.segments = seg; b.limit_method = "ANGLE"
    for p in me.polygons: p.use_smooth = smooth
    parts.append(o); return o
def box(name, size, m, loc, rot=(0, 0, 0), bevel=0.06):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts: v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return obj(name, bm, m, loc, rot, bevel)
def cyl(name, r, h, m, loc, rot=(0, 0, 0), seg=10, r2=None, bevel=0.03):
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    return obj(name, bm, m, loc, rot, bevel, smooth=True)
def ball(name, r, m, loc, sc=(1, 1, 1), sub=2):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts: v.co = Vector((v.co.x * sc[0], v.co.y * sc[1], v.co.z * sc[2]))
    return obj(name, bm, m, loc, smooth=True)
jit = lambda a: random.uniform(-a, a)

# ---------- counter ----------
box("Skirt", (8.2, 3.2, 0.45), WOODD, (0, 0, 0.22))
box("CounterTop", (8.8, 3.6, 0.5), WOOD, (0, -0.05, 3.65), (jit(1), 0, 0), 0.1)
box("TopTrim", (8.9, 0.35, 0.35), WOODD, (0, -1.95, 3.35), bevel=0.08)
x, i = -3.9, 0
while x < 3.9:                                                     # front planks, varied widths, small tilts
    w = min(random.uniform(0.7, 1.0), 3.9 - x)
    box(f"Plank{i}", (w - 0.06, 0.3, 3.0), WOOD2 if i % 2 else WOOD, (x + w / 2, -1.55, 1.9), (jit(1.5), jit(2.5), 0), 0.07)
    x += w; i += 1
box("BraceX", (7.4, 0.22, 0.32), WOODD, (0, -1.74, 1.9), (0, 16, 0), 0.06)
box("BraceX2", (7.4, 0.22, 0.32), WOODD, (0, -1.74, 1.9), (0, -16, 0), 0.06)
for s in (1, -1):
    box(f"Side{s}", (0.3, 3.0, 3.0), WOOD2, (s * 4.0, 0, 1.9), (0, 0, jit(1)), 0.07)

# ---------- posts and awning (focal feature) ----------
for sx in (1, -1):
    for sy, h in ((-1, 7.6), (1, 9.0)):
        cyl(f"Post{sx}{sy}", 0.24, h, WOODD, (sx * 4.15, sy * 1.55, h / 2), (jit(2), jit(2), 0), seg=8, r2=0.2)
        box(f"PostCap{sx}{sy}", (0.62, 0.62, 0.25), WOOD, (sx * 4.15, sy * 1.55, h + 0.05), bevel=0.06)
back, front = Vector((0, 1.9, 9.35)), Vector((0, -2.8, 7.55))
slope = math.degrees(math.atan2(back.z - front.z, back.y - front.y)); depth = (back - front).length
N, Wd = 8, 9.6
for k in range(N):
    cx = -Wd / 2 + Wd / N * (k + 0.5); sag = -0.12 * math.sin(math.pi * (k + 0.5) / N)
    m = RED if k % 2 == 0 else CREAM
    mid = (back + front) / 2
    box(f"Stripe{k}", (Wd / N + 0.01, depth, 0.16), m, (cx, mid.y, mid.z + sag), (slope, 0, 0), 0.03)
    bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, segments=16, radius=Wd / N / 2 - 0.02)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.001], context="VERTS")
    bmesh.ops.contextual_create(bm, geom=bm.edges[:])
    for v in bm.verts: v.co = Vector((v.co.x, 0, v.co.y))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.14)
    obj(f"Scallop{k}", bm, m, (cx, front.y + 0.02, front.z + sag + 0.02), (0, 0, 0), 0.02)
box("AwningBar", (9.8, 0.3, 0.3), WOODD, (0, front.y + 0.08, front.z + 0.12), bevel=0.06)
box("AwningBarBack", (9.8, 0.3, 0.3), WOODD, (0, back.y - 0.1, back.z - 0.05), bevel=0.06)

# ---------- sign ----------
for sx in (1.4, -1.4):
    box(f"SignPole{sx}", (0.2, 0.2, 1.6), WOODD, (sx, 0.1, 9.55), bevel=0.04)
box("SignBoard", (4.4, 0.32, 1.45), WOOD2, (0, 0.05, 10.75), (6, 0, jit(2)), 0.12)
box("SignFrame", (4.75, 0.24, 1.8), WOODD, (0, 0.14, 10.75), (6, 0, 0), 0.1)
cu = bpy.data.curves.new("SignText", "FONT"); cu.body = "SHOP"; cu.align_x = "CENTER"; cu.align_y = "CENTER"
cu.size = 1.05; cu.extrude = 0.06; cu.bevel_depth = 0.015
to = bpy.data.objects.new("SignText", cu); scene.collection.objects.link(to)
to.location = (0, -0.16, 10.72); to.rotation_euler = (math.radians(96), 0, 0); cu.materials.append(SIGNTXT)
bpy.context.view_layer.objects.active = to; to.select_set(True); bpy.ops.object.convert(target="MESH"); to.select_set(False)
parts.append(to)
cyl("SignCoin", 0.42, 0.12, GOLD, (-2.75, -0.12, 10.75), (96, 0, 0), seg=16)
cyl("SignCoin2", 0.42, 0.12, GOLD, (2.75, -0.12, 10.75), (96, 0, 0), seg=16)

# ---------- goods ----------
box("Crate", (1.9, 1.4, 0.85), WOOD2, (-2.55, -0.25, 4.32), (0, 0, 6), 0.08)
for k in range(9):
    a = k * 2.4; r = 0.18 + 0.42 * (k % 3) / 2
    p = Vector((-2.55 + r * math.cos(a) * 1.3, -0.25 + r * math.sin(a), 4.95 + 0.12 * (k % 2)))
    ball(f"Apple{k}", 0.3, APPLE, p, (1, 1, 0.9))
    cyl(f"Stem{k}", 0.03, 0.14, WOODD, p + Vector((0, 0, 0.3)), seg=5)
    ball(f"LeafA{k}", 0.09, LEAF, p + Vector((0.08, 0, 0.32)), (1.6, 0.6, 0.35), 1)
box("Crate2", (1.3, 1.1, 0.7), WOOD, (-1.0, 0.75, 4.25), (0, 0, -9), 0.07)
for k, (m, dx) in enumerate(((POT_B, 1.55), (POT_P, 2.3), (POT_G, 3.05))):
    h = 0.42 + 0.1 * k
    ball(f"PotionBody{k}", 0.38, m, (dx, -0.4 + 0.25 * (k % 2), 3.9 + h), (1, 1, 1.1 + 0.1 * k))
    cyl(f"PotionNeck{k}", 0.13, 0.42, m, (dx, -0.4 + 0.25 * (k % 2), 4.35 + h + 0.12 * k), seg=8)
    cyl(f"Cork{k}", 0.15, 0.2, WOODD, (dx, -0.4 + 0.25 * (k % 2), 4.62 + h + 0.12 * k), seg=8, r2=0.17)
for k in range(6):
    cyl(f"Coin{k}", 0.3, 0.08, GOLD, (0.25 + jit(0.04), -0.75 + jit(0.04), 3.94 + 0.085 * k), (jit(3), jit(3), 0), seg=14)
for k in range(3):
    cyl(f"CoinL{k}", 0.3, 0.08, GOLD, (0.95 + 0.25 * k, -0.95 + jit(0.15), 3.94), (jit(8), jit(8), 0), seg=14)
box("PriceTag", (0.9, 0.08, 0.55), CREAM, (-2.55, -1.0, 4.35), (12, 0, -6), 0.03)

# ---------- lantern, barrel ----------
cyl("LanternRope", 0.03, 0.7, METAL, (-4.15, -2.05, 7.1), seg=5)
box("LanternTop", (0.6, 0.6, 0.16), METAL, (-4.15, -2.05, 6.72), bevel=0.04)
box("LanternGlass", (0.44, 0.44, 0.62), GLOW, (-4.15, -2.05, 6.33), bevel=0.04)
box("LanternBase", (0.6, 0.6, 0.14), METAL, (-4.15, -2.05, 5.97), bevel=0.04)
for sx in (1, -1):
    for sy in (1, -1):
        box(f"LanternBar{sx}{sy}", (0.07, 0.07, 0.66), METAL, (-4.15 + sx * 0.24, -2.05 + sy * 0.24, 6.33), bevel=0)
bm = bmesh.new()
rings = [(0, 0.82), (0.25, 0.95), (0.9, 1.05), (1.55, 0.95), (1.8, 0.82)]
bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=1, radius2=1, depth=1.8)
for v in bm.verts:
    z = v.co.z + 0.9; r = 0.82 + 0.23 * math.sin(math.pi * z / 1.8); v.co.x *= r; v.co.y *= r
obj("Barrel", bm, WOOD2, (5.3, -1.2, 0.9), (0, 0, 0), 0.04, smooth=True)
for z in (0.35, 1.45):
    cyl(f"Hoop{z}", 0.97, 0.12, METAL, (5.3, -1.2, z), seg=12)
cyl("BarrelLid", 0.84, 0.08, WOODD, (5.3, -1.2, 1.82), seg=12)

# ---------- ground, light, camera ----------
gd = bpy.data.meshes.new("Ground"); gbm = bmesh.new(); bmesh.ops.create_circle(gbm, cap_ends=True, radius=60, segments=48); gbm.to_mesh(gd); gbm.free()
g = bpy.data.objects.new("Ground", gd); scene.collection.objects.link(g); gd.materials.append(mat("Grass", "8DBF5A", 0.95))
world = bpy.data.worlds.new("Sky"); world.use_nodes = True; bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = lin("BFDDF5"); bg.inputs["Strength"].default_value = 0.9; scene.world = world
ld = bpy.data.lights.new("Sun", "SUN"); ld.energy = 3.2; ld.angle = math.radians(4); ld.color = (1.0, 0.95, 0.86)
sun = bpy.data.objects.new("Sun", ld); sun.rotation_euler = (math.radians(50), math.radians(8), math.radians(-35)); scene.collection.objects.link(sun)
pl = bpy.data.lights.new("LanternLight", "POINT"); pl.energy = 60; pl.color = (1, 0.8, 0.45)
plo = bpy.data.objects.new("LanternLight", pl); plo.location = (-4.15, -2.3, 6.3); scene.collection.objects.link(plo)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
def shot(fname, loc, tgt, lens=50, res=(1400, 1050)):
    scene.render.resolution_x, scene.render.resolution_y = res; cd.lens = lens
    cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
shot("shop_hero.png", (-13, -21, 9.5), (0, 0, 5.2), 45)
shot("shop_front.png", (0, -26, 5.5), (0, 0, 5.5), 50)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "ShopStand.blend"))
bpy.ops.object.select_all(action="DESELECT")
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "ShopStand.glb"), export_format="GLB", use_selection=True, export_apply=True)
print("TRIS", sum(len(p.vertices) - 2 for o in parts for p in o.data.polygons), "PARTS", len(parts))
