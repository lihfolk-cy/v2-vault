"""Pose the Void Owl v4 rig into the key-art lunge and render showcase previews.
Run: blender -b VoidOwl_v4.blend --python pose_void_owl.py"""
import bpy, math, os
from mathutils import Vector, Matrix

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
scene = bpy.context.scene
rig = bpy.data.objects["VoidOwlRig"]
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")
pb = rig.pose.bones

def rot(name, axis, deg, pivot=None):
    """Rotate a pose bone about a world (armature-space) axis through its head (or a pivot)."""
    b = pb[name]
    bpy.context.view_layer.update()
    p = Vector(pivot) if pivot else b.head.copy()
    R = Matrix.Rotation(math.radians(deg), 4, axis)
    b.matrix = Matrix.Translation(p) @ R @ Matrix.Translation(-p) @ b.matrix
    bpy.context.view_layer.update()

# body leans into the lunge, slight turn toward camera-left
rot("RootPart", "X", 16); rot("RootPart", "Z", -10)
# wings: raised high, swept forward, tips curling in (asymmetric so it reads as motion)
for side, s, lift, sweep in (("Left", 1, -22, -24), ("Right", -1, 16, 18)):
    rot(f"{side}Wing1", "Y", lift); rot(f"{side}Wing1", "Z", sweep)
    rot(f"{side}Wing2", "Z", -12 * s); rot(f"{side}Wing2", "Y", -8 * s)
    rot(f"{side}Wing3", "Z", -16 * s); rot(f"{side}Wing3", "X", 10)
# talons thrust forward, one leg further than the other, claws hooked
for side, reach in (("Left", -62), ("Right", -48)):
    rot(f"{side}UpperLeg", "X", reach); rot(f"{side}LowerLeg", "X", -18); rot(f"{side}Foot", "X", 28)
# head dips toward the target, beak open a touch
rot("Head", "X", 10); rot("Head", "Z", 8); rot("Beak", "X", -6)
rot("Tail1", "X", -20)
bpy.ops.object.mode_set(mode="OBJECT")

# ---------- showcase stage ----------
for o in [o for o in scene.objects if o.type in ("LIGHT", "CAMERA") or o.name.startswith("Preview")]:
    bpy.data.objects.remove(o)
world = bpy.data.worlds.new("Showcase"); world.use_nodes = True; nt = world.node_tree; bg = nt.nodes["Background"]
tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping"); gr = nt.nodes.new("ShaderNodeTexGradient")
mp.inputs["Rotation"].default_value = (0, math.radians(90), 0)
cr = nt.nodes.new("ShaderNodeValToRGB")
cr.color_ramp.elements[0].color = (0.10, 0.03, 0.22, 1); cr.color_ramp.elements[1].color = (0.01, 0.012, 0.04, 1)
sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Window"], sep.inputs[0])
nt.links.new(sep.outputs["Y"], cr.inputs["Fac"]); nt.links.new(cr.outputs["Color"], bg.inputs["Color"])
cr.color_ramp.elements[0].color = (0.006, 0.008, 0.03, 1); cr.color_ramp.elements[1].color = (0.07, 0.02, 0.16, 1)
bg.inputs["Strength"].default_value = 1.0
# keep the backdrop out of the lighting: camera sees the gradient, everything else gets near-black
lp = nt.nodes.new("ShaderNodeLightPath"); mixw = nt.nodes.new("ShaderNodeMixShader"); bg2 = nt.nodes.new("ShaderNodeBackground")
bg2.inputs["Color"].default_value = (0.02, 0.02, 0.05, 1); out = nt.nodes["World Output"]
nt.links.new(lp.outputs["Is Camera Ray"], mixw.inputs[0]); nt.links.new(bg2.outputs[0], mixw.inputs[1]); nt.links.new(bg.outputs[0], mixw.inputs[2])
nt.links.new(mixw.outputs[0], out.inputs["Surface"])
scene.world = world
# big moon behind the owl
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=14, fill_type="NGON", location=(10, 45, 18), rotation=(math.radians(90), 0, 0))
moon = bpy.context.active_object; mm = bpy.data.materials.new("Moon"); mm.use_nodes = True
mb = mm.node_tree.nodes["Principled BSDF"]; mb.inputs["Base Color"].default_value = (0.75, 0.8, 1, 1)
mb.inputs["Emission Color"].default_value = (0.7, 0.75, 1, 1); mb.inputs["Emission Strength"].default_value = 1.1
moon.data.materials.append(mm)
# glowing void ring on the ground below
bpy.ops.mesh.primitive_torus_add(major_radius=9, minor_radius=0.12, location=(0, -2, -3.5))
ring = bpy.context.active_object; rmm = bpy.data.materials.new("Ring"); rmm.use_nodes = True
rb = rmm.node_tree.nodes["Principled BSDF"]; rb.inputs["Emission Color"].default_value = (1, 0.08, 0.8, 1); rb.inputs["Emission Strength"].default_value = 6
ring.data.materials.append(rmm)
def light(name, loc, rot_, energy, col, size=16):
    l = bpy.data.lights.new(name, "AREA"); l.energy = energy; l.color = col; l.size = size
    o = bpy.data.objects.new(name, l); scene.collection.objects.link(o); o.location = loc; o.rotation_euler = rot_
light("Key", (-16, -26, 26), (math.radians(42), 0, math.radians(-32)), 8000, (0.9, 0.9, 1.0))
light("Moonrim", (10, 26, 22), (math.radians(-52), 0, math.radians(160)), 14000, (0.5, 0.65, 1.0))
light("Under", (0, -16, -8), (math.radians(125), 0, 0), 2500, (0.9, 0.2, 1.0))
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 1920; scene.render.resolution_y = 1080
scene.view_settings.view_transform = "Standard"
ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree"); scene.compositing_node_group = ng
rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare")
ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor"); go = ng.nodes.new("NodeGroupOutput")
for nm, val in (("Type", "Bloom"), ("Threshold", 0.85), ("Strength", 0.9), ("Size", 0.75), ("Quality", "High")):
    if nm in gl.inputs:
        try: gl.inputs[nm].default_value = val
        except Exception: pass
ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], go.inputs[0])
def shot(fname, loc, tgt, lens):
    cam.location = loc; cd.lens = lens
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, fname); bpy.ops.render.render(write_still=True)
shot("void_owl_showcase_hero.png", (-26, -50, 3), (0, -3, 11), 30)
shot("void_owl_showcase_front.png", (4, -60, 7), (0, -3, 11), 30)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "VoidOwl_v4_posed.blend"))
print("DONE")
