import bpy, bmesh, math, random, os
import numpy as np
from mathutils import Vector

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"), exist_ok=True)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")  # renders and exports land here
random.seed(11)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# =====================================================================
# Textures: 2D fractal noise, painted per effect (RGBA PNG)
# =====================================================================
S = 512
def save_img(name, rgba):
    img = bpy.data.images.new(name, S, S, alpha=True)
    img.pixels.foreach_set(np.clip(rgba, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png"); img.file_format = "PNG"; img.save()
    return img

def fbm(seed, octaves=5, base=4):
    r = np.random.default_rng(seed); out = np.zeros((S, S)); amp = 1.0; tot = 0
    for o in range(octaves):
        k = base * 2 ** o
        g = r.random((k + 1, k + 1)); g[:, -1] = g[:, 0]
        x = np.linspace(0, k, S, endpoint=False)
        i = np.floor(x).astype(int); f = x - i; f = f * f * (3 - 2 * f)
        a = g[i][:, i]; b = g[i][:, i + 1]; c = g[i + 1][:, i]; d = g[i + 1][:, i + 1]
        fy = f[:, None]; fx = f[None, :]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        tot += amp; amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min())

U = np.linspace(0, 1, S)[None, :].repeat(S, 0)   # along strip
V = np.linspace(0, 1, S)[:, None].repeat(S, 1)   # across strip
def gauss(x, c, w): return np.exp(-((x - c) / w) ** 2)
def ramp(t, stops):
    t = np.clip(t, 0, 1); out = np.zeros(t.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1); k = ((t - t0) / max(t1 - t0, 1e-6))[..., None]
        out[m] = (np.array(c0) * (1 - k) + np.array(c1) * k)[m]
    return out

def strip_texture(name, palette, seed, edge_pos=0.78, breakup=0.55, tail=1.7):
    nz = fbm(seed, base=6)
    st = fbm(seed + 50, octaves=4, base=24)[:, :1].repeat(S, 1)
    body = np.sin(np.clip(V, 0, 1) * math.pi) ** 0.5
    edge = gauss(V, edge_pos, 0.05)
    along = (U ** tail) * np.clip((1 - U) * 10, 0, 1)
    dissolve = np.clip((nz - (1 - U) * breakup) * 3, 0, 1)
    a = np.clip((body * (0.25 + 0.75 * st) + edge * 1.4) * along * (0.35 + 0.65 * dissolve), 0, 1)
    heat = np.clip(edge * 1.2 + body * 0.45 * st + U * 0.25, 0, 1)
    return save_img(name, np.dstack([ramp(heat, palette), a]))

PAL_ICE = [(0, (0.05, 0.08, 0.5)), (0.35, (0.1, 0.55, 1.0)), (0.7, (0.55, 0.9, 1.0)), (1, (1, 1, 1))]
PAL_FIRE = [(0, (0.4, 0.02, 0.0)), (0.35, (1.0, 0.25, 0.02)), (0.7, (1.0, 0.7, 0.15)), (1, (1, 1, 0.85))]
PAL_VOID = [(0, (0.15, 0.0, 0.35)), (0.4, (0.5, 0.2, 1.0)), (0.75, (0.8, 0.7, 1.0)), (1, (1, 1, 1))]
strip_texture("vfx_slash", PAL_ICE, 10)
strip_texture("vfx_slash_dark", [(0, (0.0, 0.0, 0.05)), (0.6, (0.05, 0.1, 0.35)), (1, (0.4, 0.8, 1))], 11, edge_pos=0.9, breakup=0.8)
strip_texture("vfx_swirl", PAL_FIRE, 12, edge_pos=0.6, breakup=0.7, tail=1.2)

rad_streak = fbm(20, octaves=4, base=32)[:1, :].repeat(S, 0)
lip = gauss(V, 0.88, 0.04); inner = V ** 2.5
a = np.clip(lip * 1.3 + inner * (0.2 + 0.8 * rad_streak) * (0.4 + 0.6 * fbm(21)), 0, 1)
save_img("vfx_ring", np.dstack([ramp(np.clip(lip + inner * 0.5 * rad_streak, 0, 1), PAL_FIRE), a]))

ridge = 1 - np.abs(fbm(30, base=6) * 2 - 1); ridge = np.clip((ridge - 0.82) * 6, 0, 1)
char = np.clip(1 - V * 0.9, 0, 1) * (0.6 + 0.4 * fbm(31))
glow = ridge * np.clip(1.2 - V, 0, 1)
col = ramp(glow, [(0, (0.05, 0.03, 0.02)), (0.5, (1.0, 0.35, 0.05)), (1, (1, 0.9, 0.5))])
save_img("vfx_scorch", np.dstack([col, np.clip(char * 0.85 + glow, 0, 1) * np.clip((1 - V) * 4, 0, 1)]))

warp = fbm(40, base=4); tongue = fbm(41, base=5)
h = V + (warp - 0.5) * 0.35
shape = np.clip((1 - h) * 1.6 - (1 - tongue) * 1.2 * h, 0, 1) * np.clip(V * 10, 0, 1)
heat = np.clip(shape * 1.3 - V * 0.2, 0, 1)
save_img("vfx_flame", np.dstack([ramp(heat, PAL_FIRE), np.clip(shape ** 0.7, 0, 1)]))

ticks = ((np.floor(U * 48) % 3) == 0) & (np.abs((U * 48) % 1 - 0.5) < 0.18)
glyph = (fbm(50, octaves=2, base=24) > 0.55)
band = (np.abs(V - 0.5) < 0.18)
runes = (band & glyph & ((np.floor(U * 24) % 2) == 0)).astype(float)
rings = gauss(V, 0.18, 0.025) + gauss(V, 0.82, 0.025) + gauss(V, 0.95, 0.012) * 0.8
a = np.clip(rings + runes * 0.9 + ticks * gauss(V, 0.88, 0.05), 0, 1)
save_img("vfx_runes", np.dstack([ramp(a, PAL_FIRE), a]))

flick = np.clip((fbm(60, octaves=3, base=20)[:1, :].repeat(S, 0) - 0.2) * 3, 0.3, 1)
core = gauss(V, 0.5, 0.05); halo = gauss(V, 0.5, 0.28)
save_img("vfx_bolt", np.dstack([ramp(np.clip(core + halo * 0.4, 0, 1), PAL_VOID), np.clip(core * 1.5 + halo * 0.55, 0, 1) * flick]))

x = U * 2 - 1; y = V * 2 - 1; rr = np.sqrt(x * x + y * y) + 1e-6
star = np.clip(np.exp(-np.abs(x) * 40) * np.exp(-np.abs(y) * 2.2) + np.exp(-np.abs(y) * 40) * np.exp(-np.abs(x) * 2.2), 0, 1)
bloom = np.exp(-rr * 4)
save_img("vfx_flash", np.dstack([ramp(np.clip(star + bloom, 0, 1), [(0, (1, 0.5, 0.1)), (0.6, (1, 0.85, 0.5)), (1, (1, 1, 1))]), np.clip(star + bloom * 0.9, 0, 1)]))

sm = fbm(70, base=5); sm2 = fbm(71, base=10)
a = np.clip((sm * 0.7 + sm2 * 0.3 - 0.35) * 2.2, 0, 1) * np.sin(V * math.pi) ** 0.6
col = ramp(np.clip((1 - V) * 0.9 * sm, 0, 1), [(0, (0.12, 0.1, 0.1)), (0.6, (0.45, 0.25, 0.15)), (1, (1.0, 0.55, 0.2))])
save_img("vfx_smoke", np.dstack([col, a * 0.85]))
pst = fbm(80, octaves=4, base=32)[:1, :].repeat(S, 0)
a = np.clip((0.35 + 0.65 * pst) * (1 - V) ** 1.5 * np.clip(V * 12, 0, 1), 0, 1)
save_img("vfx_pillar", np.dstack([ramp(np.clip(a * 1.3, 0, 1), PAL_FIRE), a]))
save_img("vfx_pillar_void", np.dstack([ramp(np.clip(a * 1.3, 0, 1), PAL_VOID), a]))
ra = np.clip(rings + runes * 0.9 + ticks * gauss(V, 0.88, 0.05), 0, 1)
save_img("vfx_runes_void", np.dstack([ramp(ra, PAL_VOID), ra]))
save_img("vfx_flash_void", np.dstack([ramp(np.clip(star + bloom, 0, 1), PAL_VOID), np.clip(star + bloom * 0.9, 0, 1)]))
save_img("vfx_flash_ice", np.dstack([ramp(np.clip(star + bloom, 0, 1), PAL_ICE), np.clip(star + bloom * 0.9, 0, 1)]))

# =====================================================================
# Materials
# =====================================================================
def mat(name, img, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images[img]
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength * 0.45
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    try: m.surface_render_method = "BLENDED"
    except Exception: pass
    m.use_backface_culling = False
    return m
def solid(name, rgb_, strength, alpha=1.0, rough=0.6):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb_, 1); b.inputs["Emission Color"].default_value = (*rgb_, 1)
    b.inputs["Emission Strength"].default_value = strength; b.inputs["Alpha"].default_value = alpha
    b.inputs["Roughness"].default_value = rough
    return m

M = {
 "slash": mat("VFX_Slash", "vfx_slash", 6), "slashdark": mat("VFX_SlashDark", "vfx_slash_dark", 1.5),
 "swirl": mat("VFX_Swirl", "vfx_swirl", 5), "ring": mat("VFX_Ring", "vfx_ring", 5),
 "scorch": mat("VFX_Scorch", "vfx_scorch", 3), "flame": mat("VFX_Flame", "vfx_flame", 5),
 "runes": mat("VFX_Runes", "vfx_runes", 6), "bolt": mat("VFX_Bolt", "vfx_bolt", 9), "flash": mat("VFX_Flash", "vfx_flash", 8),
 "shardice": solid("VFX_ShardIce", (0.6, 0.9, 1.0), 6), "shardhot": solid("VFX_ShardHot", (1.0, 0.45, 0.08), 3),
 "ember": solid("VFX_Ember", (1.0, 0.55, 0.12), 8), "rock": solid("VFX_Rock", (0.09, 0.08, 0.075), 0, rough=0.9),
 "rockhot": solid("VFX_RockHot", (0.9, 0.3, 0.05), 2.5), "spark": solid("VFX_SparkVoid", (0.85, 0.8, 1.0), 10),
 "smoke": mat("VFX_Smoke", "vfx_smoke", 0.6), "pillar": mat("VFX_Pillar", "vfx_pillar", 5),
 "pillarvoid": mat("VFX_PillarVoid", "vfx_pillar_void", 6), "runesvoid": mat("VFX_RunesVoid", "vfx_runes_void", 7),
 "flashvoid": mat("VFX_FlashVoid", "vfx_flash_void", 8), "flashice": mat("VFX_FlashIce", "vfx_flash_ice", 8),
}

def obj_from(name, verts, faces, uvs, material, loc=(0, 0, 0), rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces)
    if uvs:
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices: uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    me.update(); me.materials.append(material)
    ob = bpy.data.objects.new(name, me); scene.collection.objects.link(ob)
    ob.location = loc; ob.rotation_euler = rot
    return ob

def bm_obj(name, bm, material, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(material)
    ob = bpy.data.objects.new(name, me); scene.collection.objects.link(ob); ob.location = loc
    return ob

def shard(bm, c, d, length, width):
    d = d.normalized(); s = d.cross(Vector((0, 0, 1)))
    if s.length < 0.01: s = Vector((1, 0, 0))
    s.normalize(); u = s.cross(d).normalized()
    tip = bm.verts.new(c + d * length * 0.6); tail = bm.verts.new(c - d * length * 0.4)
    mid = [bm.verts.new(c + (s * math.cos(a) + u * math.sin(a)) * width) for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    for j in range(4):
        bm.faces.new((mid[j], mid[(j + 1) % 4], tip)); bm.faces.new((mid[(j + 1) % 4], mid[j], tail))

# =====================================================================
# 1. Crescent slash
# =====================================================================
def crescent(name, R, width, sweep, lift, material, n=96, grow=0.0, zoff=0.0, wave=0.0, loc=(0, 0, 0), rot=(0, 0, 0), phase=0.0):
    verts, faces, uvs = [], [], []
    for i in range(n + 1):
        t = i / n; a = -sweep / 2 + sweep * t + phase
        w = width * (math.sin(t * math.pi) ** 0.6) * (0.25 + 0.75 * t ** 0.8)
        r = R + grow * t + wave * math.sin(t * 9) * t
        z = math.sin(t * math.pi) * lift + zoff
        verts.append((math.cos(a) * (r - w * 0.55), math.sin(a) * (r - w * 0.55), z - w * 0.12))
        verts.append((math.cos(a) * (r + w * 0.45), math.sin(a) * (r + w * 0.45), z + w * 0.12))
        uvs += [(t, 0.0), (t, 1.0)]
        if i < n: k = i * 2; faces.append((k, k + 2, k + 3, k + 1))
    return obj_from(name, verts, faces, uvs, material, loc, rot)

X1, Z1 = -22, 4.2
ROT1 = (math.radians(78), math.radians(-22), math.radians(-8))
crescent("Slash_DarkUnder", 4.0, 3.4, math.radians(230), 0.5, M["slashdark"], zoff=-0.15, loc=(X1, 0, Z1), rot=ROT1)
crescent("Slash_Glow", 4.0, 2.8, math.radians(225), 0.55, M["slash"], loc=(X1, 0, Z1), rot=ROT1)
crescent("Slash_Core", 4.05, 1.1, math.radians(205), 0.6, M["slash"], loc=(X1, 0, Z1), rot=ROT1)
for k in range(6):
    crescent(f"Slash_Wisp{k}", 4.3 + k * 0.32, 0.22 - k * 0.02, math.radians(170 - k * 19), 0.7 + k * 0.15, M["slash"],
             n=64, zoff=0.12 * k, wave=0.05 * k, loc=(X1, 0, Z1), rot=ROT1)
# motion afterimages trailing behind the swing
for k in range(1, 4):
    crescent(f"Slash_Afterimage{k}", 4.0 - k * 0.12, 2.2 - k * 0.35, math.radians(200 - k * 25), 0.5, M["slashdark"],
             zoff=-0.1 * k, loc=(X1, 0, Z1), rot=ROT1, phase=-math.radians(14 * k))
# second swing crossing the first: an X slash
ROT1B = (math.radians(98), math.radians(30), math.radians(176))
crescent("Slash_CrossGlow", 3.6, 2.2, math.radians(190), 0.45, M["slash"], loc=(X1 + 0.3, 0.3, Z1 - 0.2), rot=ROT1B)
crescent("Slash_CrossCore", 3.65, 0.8, math.radians(175), 0.5, M["slash"], loc=(X1 + 0.3, 0.3, Z1 - 0.2), rot=ROT1B)
for k in range(3):
    crescent(f"Slash_CrossWisp{k}", 3.9 + k * 0.3, 0.16, math.radians(140 - k * 20), 0.6 + k * 0.1, M["slash"],
             n=56, zoff=0.1 * k, loc=(X1 + 0.3, 0.3, Z1 - 0.2), rot=ROT1B)
# flare where the two swings cross, plus straight speed streaks
for k in range(2):
    obj_from(f"Slash_Flare{k}", [(-1.8, 0, -1.8), (1.8, 0, -1.8), (1.8, 0, 1.8), (-1.8, 0, 1.8)], [(0, 1, 2, 3)],
             [(0, 0), (1, 0), (1, 1), (0, 1)], M["flashice"], loc=(X1 + 0.1, -0.6, Z1 + 0.2), rot=(0, math.radians(45 * k), 0))
bm = bmesh.new()
for i in range(14):
    c = Vector((random.uniform(-4.5, 4.5), random.uniform(-0.5, 0.5), random.uniform(-3.5, 3.5)))
    d = Vector((1, 0, random.uniform(-0.25, 0.25)))
    shard(bm, c, d, random.uniform(1.5, 3.5), 0.025)
bm_obj("Slash_SpeedLines", bm, M["shardice"], (X1, -0.8, Z1))
bm = bmesh.new()
for i in range(22):
    t = random.random(); a = math.radians(-112 + 225 * t); r = 4.0 + random.uniform(0.3, 2.2)
    c = Vector((math.cos(a) * r, math.sin(a) * r, random.uniform(-0.4, 0.8)))
    d = Vector((-math.sin(a), math.cos(a), random.uniform(-0.3, 0.3)))
    shard(bm, c, d, random.uniform(0.35, 0.9), random.uniform(0.04, 0.09))
sh = bm_obj("Slash_Shards", bm, M["shardice"], (X1, 0, Z1)); sh.rotation_euler = ROT1

# =====================================================================
# 2. Impact
# =====================================================================
def ring(name, r_in, r_out, cone, material, n=128, loc=(0, 0, 0), jag=0.0, seed=0):
    rr_ = random.Random(seed); verts, faces, uvs = [], [], []
    jags = [rr_.uniform(0, 1) for _ in range(n + 1)]; jags[-1] = jags[0]
    for i in range(n + 1):
        t = i / n; a = t * math.tau; ro = r_out + jag * jags[i]
        verts.append((math.cos(a) * r_in, math.sin(a) * r_in, 0))
        verts.append((math.cos(a) * ro, math.sin(a) * ro, cone + jag * jags[i] * 1.5))
        uvs += [(t, 0), (t, 1)]
        if i < n: k = i * 2; faces.append((k, k + 2, k + 3, k + 1))
    return obj_from(name, verts, faces, uvs, material, loc)

X2 = -7.5
ring("Impact_Scorch", 0.0, 5.5, 0.0, M["scorch"], loc=(X2, 0, 0.03))
ring("Impact_ShockFlat", 3.2, 5.0, 0.2, M["ring"], loc=(X2, 0, 0.08))
ring("Impact_ShockMid", 2.0, 3.0, 0.9, M["ring"], loc=(X2, 0, 0.1), jag=0.3, seed=3)
ring("Impact_Crown", 1.2, 1.7, 2.4, M["ring"], n=64, loc=(X2, 0, 0.1), jag=0.9, seed=4)
bm = bmesh.new()
for tier, (count, el0, el1, L0, L1, w) in enumerate([(30, 8, 35, 2.4, 5.0, 0.11), (20, 40, 80, 1.6, 3.6, 0.08), (14, 2, 12, 1.2, 2.4, 0.06)]):
    for i in range(count):
        az = (i + tier * 0.5) / count * math.tau + random.uniform(-0.12, 0.12)
        el = math.radians(random.uniform(el0, el1))
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        L = random.uniform(L0, L1)
        shard(bm, Vector((0, 0, 0.3)) + d * L * 0.5, d, L, w)
bm_obj("Impact_Spikes", bm, M["shardhot"], (X2, 0, 0))
for k in range(3):
    verts = [(-2.2, 0, -2.2), (2.2, 0, -2.2), (2.2, 0, 2.2), (-2.2, 0, 2.2)]
    obj_from(f"Impact_Flash{k}", verts, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)], M["flash"],
             loc=(X2, 0, 1.4), rot=(0, 0, k * math.pi / 3))
for i in range(14):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.15, 0.45))
    r = bpy.context.active_object; r.name = f"Impact_Debris{i}"
    for vtx in r.data.vertices: vtx.co *= random.uniform(0.6, 1.3)
    a = random.uniform(0, math.tau); d = random.uniform(1.2, 4.5)
    r.location = (X2 + math.cos(a) * d, math.sin(a) * d, random.uniform(0.3, 3.5))
    r.rotation_euler = (random.random() * 3, random.random() * 3, random.random() * 3)
    r.data.materials.append(M["rockhot"] if i % 3 == 0 else M["rock"])
    # ember trail pointing back toward the blast centre
    tb = bmesh.new(); back = (Vector((X2, 0, 0.3)) - r.location).normalized()
    shard(tb, back * 0.9, -back, random.uniform(1.0, 1.8), 0.06)
    bm_obj(f"Impact_DebrisTrail{i}", tb, M["shardhot"], tuple(r.location))

def pillar(name, R, H, material, loc, n=64, taper=0.6):
    verts, faces, uvs = [], [], []
    for i in range(n + 1):
        t = i / n; a = t * math.tau
        for j, s in enumerate((0.0, 0.5, 1.0)):
            rr_ = R * (1 - (1 - taper) * s)
            verts.append((math.cos(a) * rr_, math.sin(a) * rr_, H * s)); uvs.append((t, s))
    for i in range(n):
        for j in range(2):
            k = i * 3 + j; k2 = (i + 1) * 3 + j; faces.append((k, k2, k2 + 1, k + 1))
    return obj_from(name, verts, faces, uvs, material, loc)
pillar("Impact_Pillar", 1.1, 9.0, M["pillar"], (X2, 0, 0.05), taper=0.35)
pillar("Impact_PillarWide", 2.0, 4.5, M["pillar"], (X2, 0, 0.05), taper=0.7)
for i in range(9):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=random.uniform(0.8, 1.4))
    pf = bpy.context.active_object; pf.name = f"Impact_Smoke{i}"
    for vtx in pf.data.vertices:
        n_ = vtx.co.normalized(); vtx.co *= 1 + 0.25 * math.sin(n_.x * 5 + i) * math.cos(n_.y * 4 - i) + 0.12 * math.sin(n_.z * 9)
    bpy.ops.object.shade_smooth()
    uvl = pf.data.uv_layers[0] if pf.data.uv_layers else pf.data.uv_layers.new(name="UVMap")
    for poly in pf.data.polygons:
        for li in poly.loop_indices:
            co = pf.data.vertices[pf.data.loops[li].vertex_index].co.normalized()
            uvl.data[li].uv = (math.atan2(co.y, co.x) / math.tau + 0.5, co.z * 0.5 + 0.5)
    a = i / 9 * math.tau + random.uniform(-0.2, 0.2); d = random.uniform(3.0, 4.4)
    pf.location = (X2 + math.cos(a) * d, math.sin(a) * d, random.uniform(0.4, 1.0))
    pf.scale = (1.3, 1.3, 0.8)
    pf.data.materials.append(M["smoke"])

# =====================================================================
# 3. Fire aura
# =====================================================================
X3 = 7.5
def flame_shell(name, R, H, tongues, seed, n=96, rows=14):
    r = random.Random(seed); ph = [r.uniform(0, math.tau) for _ in range(4)]
    verts, faces, uvs = [], [], []
    for i in range(n + 1):
        t = i / n; a = t * math.tau
        h = H * (0.5 + 0.5 * abs(math.sin(a * tongues / 2 + ph[0])) ** 1.8 + 0.12 * math.sin(a * 5 + ph[1]))
        for j in range(rows + 1):
            s = j / rows; rad = R * (1 - 0.8 * s ** 1.4) * (1 + 0.08 * math.sin(a * 7 + s * 6 + ph[2]))
            sway = 0.45 * s * s * math.sin(a * 2 + ph[3])
            verts.append((math.cos(a) * rad + sway, math.sin(a) * rad, h * s)); uvs.append((t, s))
    for i in range(n):
        for j in range(rows):
            k = i * (rows + 1) + j; k2 = (i + 1) * (rows + 1) + j; faces.append((k, k2, k2 + 1, k + 1))
    return obj_from(name, verts, faces, uvs, M["flame"], (X3, 0, 0))
ring("Aura_RuneCircle", 2.2, 4.4, 0.0, M["runes"], loc=(X3, 0, 0.05))
ring("Aura_GroundBurn", 0.0, 2.6, 0.0, M["scorch"], loc=(X3, 0, 0.04))
flame_shell("Aura_FlameOuter", 2.5, 7.4, 13, 1)
flame_shell("Aura_FlameMid", 2.0, 6.0, 10, 2)
flame_shell("Aura_FlameInner", 1.4, 4.6, 7, 3)
flame_shell("Aura_FlameCore", 0.8, 3.4, 5, 4)
pillar("Aura_CoreColumn", 0.9, 10.0, M["pillar"], (X3, 0, 0.05), taper=0.25)
pillar("Aura_HeatHaze", 3.0, 3.0, M["pillar"], (X3, 0, 0.05), taper=0.85)
def swirl(name, R, H, turns, width, phase, z0=0.0, wob=0.0):
    verts, faces, uvs = [], [], []; n = 140
    for i in range(n + 1):
        t = i / n; a = phase + t * turns * math.tau
        r = R * (1 - 0.55 * t) * (1 + wob * math.sin(t * 11 + phase)); z = z0 + H * t
        w = width * math.sin(t * math.pi) ** 0.7 * (0.6 + 0.4 * math.sin(t * 7 + phase * 3)); p = Vector((math.cos(a) * r, math.sin(a) * r, z))
        nrm = Vector((math.cos(a), math.sin(a), 0))
        off = (Vector((0, 0, 1)) * 0.8 + nrm * 0.2).normalized() * w / 2
        verts += [tuple(p - off), tuple(p + off)]; uvs += [(t, 0), (t, 1)]
        if i < n: k = i * 2; faces.append((k, k + 2, k + 3, k + 1))
    return obj_from(name, verts, faces, uvs, M["swirl"], (X3, 0, 0))
for k, (R_, H_, tu, wd, z0) in enumerate([(3.1, 7.8, 1.5, 0.8, 0.0), (2.7, 6.0, 1.2, 0.55, 1.2), (3.4, 5.0, 0.9, 0.4, 2.5),
                                          (2.4, 8.5, 1.8, 0.35, 0.3), (2.9, 4.2, 0.7, 0.6, 4.0)]):
    swirl(f"Aura_Swirl{k}", R_, H_, tu, wd, k * 1.37, z0=z0, wob=0.08)
# loose flame wisps peeling off the shell
for k in range(10):
    a0 = random.uniform(0, math.tau); z0 = random.uniform(3.5, 7.5)
    swirl(f"Aura_Wisp{k}", random.uniform(2.0, 2.8), random.uniform(1.2, 2.4), random.uniform(0.15, 0.3), random.uniform(0.25, 0.45), a0, z0=z0).data.materials[0] = M["flame"]
bm = bmesh.new()
for i in range(40):
    a = random.uniform(0, math.tau); r = random.uniform(1.0, 3.2); z = random.uniform(0.5, 9)
    shard(bm, Vector((math.cos(a) * r, math.sin(a) * r, z)), Vector((random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), 1)),
          random.uniform(0.15, 0.4), random.uniform(0.03, 0.07))
bm_obj("Aura_Embers", bm, M["ember"], (X3, 0, 0))

# =====================================================================
# 4. Lightning
# =====================================================================
X4 = 21
def fractal(a, b, depth, disp, r):
    if depth == 0: return [a, b]
    m = (a + b) / 2 + Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1, 1))) * disp
    return fractal(a, m, depth - 1, disp * 0.55, r)[:-1] + fractal(m, b, depth - 1, disp * 0.55, r)

def ribbons(name, pts, w0, w1, material):
    verts, faces, uvs = [], [], []; n = len(pts)
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0))):
        base = len(verts)
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            s = d.cross(axis)
            if s.length < 0.01: s = d.cross(Vector((0, 0, 1)))
            s.normalize(); w = w0 + (w1 - w0) * i / (n - 1)
            verts += [tuple(p - s * w), tuple(p + s * w)]; uvs += [(i / (n - 1), 0), (i / (n - 1), 1)]
            if i < n - 1: k = base + i * 2; faces.append((k, k + 2, k + 3, k + 1))
    return obj_from(name, verts, faces, uvs, material)

r = random.Random(9)
A = Vector((X4 - 3.5, 0, 10)); B = Vector((X4 + 0.8, 0.3, 0.1))
main = fractal(A, B, 6, 2.2, r)
ribbons("Bolt_Main", main, 0.55, 0.35, M["bolt"])
ribbons("Bolt_MainCore", main, 0.16, 0.1, M["bolt"])
for k in range(9):
    st = main[r.randint(4, len(main) - 10)]
    end = st + Vector((r.uniform(-4, 4), r.uniform(-2.5, 2.5), -r.uniform(1.2, 4.5)))
    br = fractal(st, end, 5, 1.1, r)
    ribbons(f"Bolt_Branch{k}", br, 0.3, 0.03, M["bolt"])
    for j in range(2):
        st2 = br[r.randint(len(br) // 4, len(br) - 4)]
        sub = fractal(st2, st2 + Vector((r.uniform(-1.8, 1.8), r.uniform(-1, 1), -r.uniform(0.6, 2))), 3, 0.5, r)
        ribbons(f"Bolt_Twig{k}_{j}", sub, 0.14, 0.015, M["bolt"])
# second, fainter bolt behind the main one (lightning rarely strikes alone)
ghost = fractal(A + Vector((1.2, 1.5, 0.5)), B + Vector((0.4, 0.8, 0)), 6, 2.6, r)
ribbons("Bolt_Ghost", ghost, 0.3, 0.2, M["bolt"])
# charged sigil at the origin, void pillar and flash at the strike, glowing cracks
ring("Bolt_Sigil", 1.2, 3.2, 0.0, M["runesvoid"], loc=(A.x, A.y, A.z + 0.3))
ring("Bolt_SigilInner", 0.3, 1.0, -0.3, M["bolt"], loc=(A.x, A.y, A.z + 0.3), jag=0.15, seed=12)
pillar("Bolt_StrikePillar", 1.0, 6.0, M["pillarvoid"], (B.x, B.y, 0.05), taper=0.3)
for k in range(2):
    obj_from(f"Bolt_Flash{k}", [(-2.4, 0, -2.4), (2.4, 0, -2.4), (2.4, 0, 2.4), (-2.4, 0, 2.4)], [(0, 1, 2, 3)],
             [(0, 0), (1, 0), (1, 1), (0, 1)], M["flashvoid"], loc=(B.x, B.y, 0.9), rot=(0, 0, k * math.pi / 2))
for k in range(8):
    ang = k / 8 * math.tau + r.uniform(-0.3, 0.3)
    p0 = Vector((B.x, B.y, 0.06)); p1 = p0 + Vector((math.cos(ang), math.sin(ang), 0)) * r.uniform(2.5, 4.5)
    crack = fractal(p0, p1, 4, 0.5, r)
    crack = [Vector((q.x, q.y, 0.06)) for q in crack]
    verts, faces, uvs = [], [], []
    for i, q in enumerate(crack):
        d = (crack[min(i + 1, len(crack) - 1)] - crack[max(i - 1, 0)]).normalized(); s = Vector((-d.y, d.x, 0)) * 0.12 * (1 - i / len(crack))
        verts += [tuple(q - s), tuple(q + s)]; uvs += [(i / (len(crack) - 1), 0), (i / (len(crack) - 1), 1)]
        if i < len(crack) - 1: kk = i * 2; faces.append((kk, kk + 2, kk + 3, kk + 1))
    obj_from(f"Bolt_Crack{k}", verts, faces, uvs, M["bolt"])
ring("Bolt_StrikeRing", 0.4, 2.6, 0.2, M["bolt"], loc=(B.x, B.y, 0.08), jag=0.25, seed=8)
ring("Bolt_Scorch", 0.0, 3.0, 0.0, M["scorch"], loc=(B.x, B.y, 0.03))
bm = bmesh.new()
for i in range(26):
    az = random.uniform(0, math.tau); el = math.radians(random.uniform(10, 70))
    d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
    shard(bm, d * random.uniform(0.6, 2.4), d, random.uniform(0.3, 0.8), 0.035)
bm_obj("Bolt_Sparks", bm, M["spark"], (B.x, B.y, 0.2))

# =====================================================================
# Preview render, then export
# =====================================================================
world = bpy.data.worlds.new("W"); world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.008, 0.01, 0.02, 1); scene.world = world
bpy.ops.mesh.primitive_plane_add(size=80); floor = bpy.context.active_object; floor.name = "PreviewFloor"
floor.data.materials.append(solid("Floor", (0.02, 0.022, 0.03), 0, rough=0.35))
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam)
cam.location = (0, -36, 9); cam.rotation_euler = (math.radians(80), 0, 0); cd.lens = 23; scene.camera = cam
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 1920; scene.render.resolution_y = 900
scene.view_settings.view_transform = "AgX"
glare_ok = False
try:
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    scene.compositing_node_group = ng
    rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    go = ng.nodes.new("NodeGroupOutput")
    print("GLARE inputs", [i.name for i in gl.inputs], [p.identifier for p in gl.bl_rna.properties])
    for nm, val in (("Type", "Bloom"), ("Threshold", 1.2), ("Strength", 0.6), ("Size", 0.6), ("Quality", "High")):
        if nm in gl.inputs:
            try: gl.inputs[nm].default_value = val
            except Exception as e: print("set", nm, e)
    for gt in ("BLOOM", "FOG_GLOW"):
        try:
            gl.glare_type = gt; break
        except Exception: pass
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], go.inputs[0])
    glare_ok = True
except Exception as e:
    print("glare skipped", e)
scene.render.filepath = os.path.join(OUT, "preview.png")
bpy.ops.render.render(write_still=True)

bpy.data.objects.remove(floor); bpy.data.objects.remove(cam)
for o in [o for o in scene.objects if o.name.startswith("PreviewLight")]: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "Mesh_VFX_Pack.fbx"), use_selection=True, path_mode="COPY", embed_textures=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "Mesh_VFX_Pack.glb"), export_format="GLB", use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Mesh_VFX_Pack.blend"))
print("DONE", len(scene.objects), "glare", glare_ok)
