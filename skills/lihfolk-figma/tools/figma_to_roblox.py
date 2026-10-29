"""Figma REST node JSON -> Roblox Luau ModuleScript that builds the GUI tree.

Python 3, standard library only, deterministic (same input, same output).

Usage:
    py -I figma_to_roblox.py input.json --node "Settings" -o SettingsUI.luau
    py -I figma_to_roblox.py input.json --node 12:34 -o SettingsUI.luau --manifest SettingsUI.assets.json
    py -I figma_to_roblox.py input.json --node "Settings" --report            # unsupported-feature report only
Options:
    --reference 1920x1080      design reference resolution (the Fit UIScale is 1.0 at this size)
    --screen                   the frame is a full screen (HUD): root fills the screen, each top-level
                               child is anchored to its own edge and gets its own Fit UIScale
    --per-corner               emit UICorner per-corner radii (beta in Roblox as of 2026-10) for mixed corners
    --rotation-units rad|deg   unit of the REST `rotation` field (default rad; see references/property-mapping.md)

Input: the response of GET /v1/files/:key/nodes?ids=... ({"nodes": {id: {"document": ...}}}),
a whole file (GET /v1/files/:key, {"document": ...}) or a bare node. The token stays in the user's
FIGMA_TOKEN env var; this tool never reads the network or the token.

The mapping rules live in ../references/property-mapping.md. Keep the two in step.
"""
import argparse
import json
import math
import re
import sys

# ----------------------------------------------------------------------------------------- tables

# Built-in Roblox font families (rbxasset://fonts/families/<file>.json) and the weights each ships.
# Read from a local Studio install's content/fonts/families folder on 2026-10-29.
ROBLOX_FAMILIES = {
    "Accanthis ADF Std": ("AccanthisADFStd", [400]),
    "Amatic SC": ("AmaticSC", [400, 700]),
    "Arimo": ("Arimo", [400, 500, 600, 700]),
    "Balthazar": ("Balthazar", [400]),
    "Bangers": ("Bangers", [400]),
    "Builder Extended": ("BuilderExtended", [300, 400, 600, 700, 800]),
    "Builder Mono": ("BuilderMono", [300, 400, 700]),
    "Builder Sans": ("BuilderSans", [100, 300, 400, 500, 600, 700, 800]),
    "Comic Neue Angular": ("ComicNeueAngular", [400]),
    "Creepster": ("Creepster", [400]),
    "Denk One": ("DenkOne", [400]),
    "Fondamento": ("Fondamento", [400]),
    "Fredoka One": ("FredokaOne", [400]),
    "Grenze Gotisch": ("GrenzeGotisch", [100, 200, 300, 400, 500, 600, 700, 800, 900]),
    "Guru": ("Guru", [400]),
    "Highway Gothic": ("HighwayGothic", [400]),
    "Inconsolata": ("Inconsolata", [200, 300, 400, 500, 600, 700, 800, 900]),
    "Indie Flower": ("IndieFlower", [400]),
    "Josefin Sans": ("JosefinSans", [100, 200, 300, 400, 500, 600, 700]),
    "Jura": ("Jura", [300, 400, 500, 600, 700]),
    "Kalam": ("Kalam", [300, 400, 700]),
    "Luckiest Guy": ("LuckiestGuy", [400]),
    "Merriweather": ("Merriweather", [300, 400, 700, 900]),
    "Michroma": ("Michroma", [400]),
    "Montserrat": ("Montserrat", [100, 200, 300, 400, 500, 600, 700, 800, 900]),
    "Nunito": ("Nunito", [200, 300, 400, 600, 700, 800, 900]),
    "Oswald": ("Oswald", [200, 300, 400, 500, 600, 700]),
    "Patrick Hand": ("PatrickHand", [400]),
    "Permanent Marker": ("PermanentMarker", [400]),
    "Press Start 2P": ("PressStart2P", [400]),
    "Roboto": ("Roboto", [100, 300, 400, 500, 700, 900]),
    "Roboto Condensed": ("RobotoCondensed", [300, 400, 700]),
    "Roboto Mono": ("RobotoMono", [100, 200, 300, 400, 500, 600, 700]),
    "Roman Antique": ("RomanAntique", [400]),
    "Sarpanch": ("Sarpanch", [400, 500, 600, 700, 800, 900]),
    "Source Sans Pro": ("SourceSansPro", [200, 300, 400, 600, 700, 900]),
    "Special Elite": ("SpecialElite", [400]),
    "Titillium Web": ("TitilliumWeb", [200, 300, 400, 600, 700, 900]),
    "Ubuntu": ("Ubuntu", [300, 400, 500, 700]),
    "Zekton": ("Zekton", [400]),
}
# Common Figma families that Roblox does not ship -> closest built-in look (a warning is always logged).
FAMILY_FALLBACK = {
    "Inter": "Builder Sans", "SF Pro": "Builder Sans", "SF Pro Display": "Builder Sans",
    "SF Pro Text": "Builder Sans", "Helvetica": "Arimo", "Helvetica Neue": "Arimo", "Arial": "Arimo",
    "Open Sans": "Source Sans Pro", "Lato": "Nunito", "Poppins": "Montserrat", "Gotham": "Montserrat",
    "Gotham Rounded": "Nunito", "Fredoka": "Fredoka One", "Baloo 2": "Fredoka One",
    "Lilita One": "Luckiest Guy", "Bebas Neue": "Oswald", "Roboto Slab": "Merriweather",
    "JetBrains Mono": "Roboto Mono", "Source Code Pro": "Roboto Mono",
}
DEFAULT_FAMILY = "Builder Sans"
WEIGHTS = [(100, "Thin"), (200, "ExtraLight"), (300, "Light"), (400, "Regular"), (500, "Medium"),
           (600, "SemiBold"), (700, "Bold"), (800, "ExtraBold"), (900, "Heavy")]

VECTOR_TYPES = {"VECTOR", "BOOLEAN_OPERATION", "STAR", "LINE", "REGULAR_POLYGON"}
CONTAINER_TYPES = {"FRAME", "GROUP", "COMPONENT", "COMPONENT_SET", "INSTANCE", "SECTION"}
MAX_TEXTURE = 1024  # Roblox image uploads are capped at 1024 px on the long side
MIN_DRAWN_TEXT = 12  # vault rule: drawn text never under 12 px


# ----------------------------------------------------------------------------------------- formatting

def num(x):
    """Short, stable number text: integers stay integers, others keep up to 3 decimals."""
    x = float(x)
    if abs(x - round(x)) < 1e-6:
        return str(int(round(x)))
    s = ("%.3f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def lua_str(s):
    out = []
    for ch in s:
        o = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif o < 32 or o == 127:
            out.append("\\%03d" % o)
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def rgb255(c):
    return tuple(max(0, min(255, int(round(float(c.get(k, 0)) * 255)))) for k in ("r", "g", "b"))


def color3(c):
    r, g, b = rgb255(c)
    return "Color3.fromRGB(%d, %d, %d)" % (r, g, b)


def hex_color(c):
    return "#%02X%02X%02X" % rgb255(c)


def clean_name(name):
    name = re.sub(r"[\x00-\x1f\x7f]", "", str(name or "")).strip()
    return (name or "Node")[:100]


def tidy(x):
    """JSON-friendly number: 48.0 -> 48, 12.345678 -> 12.35."""
    x = round(float(x), 2)
    return int(x) if x == int(x) else x


def rich_escape(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace('"', "&quot;").replace("'", "&apos;"))


# ----------------------------------------------------------------------------------------- pure mapping

def gradient_rotation(handles, width, height):
    """UIGradient.Rotation (degrees, clockwise, y-down) from Figma gradientHandlePositions.

    Handles are in normalised object space (0..1 of the bounding box), so convert to pixels first:
    a 45-degree handle in a 200 x 100 box is really atan2(100, 200) = 26.565 degrees.
    """
    (x0, y0), (x1, y1) = (handles[0]["x"], handles[0]["y"]), (handles[1]["x"], handles[1]["y"])
    dx, dy = (x1 - x0) * width, (y1 - y0) * height
    if abs(dx) < 1e-9 and abs(dy) < 1e-9:
        return 0.0
    deg = math.degrees(math.atan2(dy, dx))
    deg = round(deg, 3)
    return 0.0 if deg == 0 else deg


def remap_stops(handles, stops, width, height):
    """Figma stops (positions along handle 0 -> handle 1) to Roblox keypoint times.

    Roblox stretches the gradient between the element's edges along the rotated axis; Figma
    anchors it to the handles. Project the box corners on the axis to find the Roblox extent,
    map every stop into it, clamp, add end keys, and cap at the 20-keypoint limit.
    Returns [(time, (r,g,b,a 0..1))].
    """
    (x0, y0), (x1, y1) = (handles[0]["x"] * width, handles[0]["y"] * height), \
                         (handles[1]["x"] * width, handles[1]["y"] * height)
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    ux, uy = dx / length, dy / length
    proj = [((cx - x0) * ux + (cy - y0) * uy) for cx, cy in ((0, 0), (width, 0), (0, height), (width, height))]
    tmin, tmax = min(proj), max(proj)
    span = (tmax - tmin) or 1.0

    def col(stop):
        c = stop["color"]
        return (float(c.get("r", 0)), float(c.get("g", 0)), float(c.get("b", 0)), float(c.get("a", 1)))

    pts = sorted(((float(s.get("position", 0)) * length - tmin) / span, col(s)) for s in stops)
    if not pts:
        return [(0.0, (1, 1, 1, 1)), (1.0, (1, 1, 1, 1))]

    def sample(t):
        if t <= pts[0][0]:
            return pts[0][1]
        if t >= pts[-1][0]:
            return pts[-1][1]
        for (ta, ca), (tb, cb) in zip(pts, pts[1:]):
            if ta <= t <= tb:
                f = 0.0 if tb == ta else (t - ta) / (tb - ta)
                return tuple(a + (b - a) * f for a, b in zip(ca, cb))
        return pts[-1][1]

    keys = [(0.0, sample(0.0))]
    keys += [(round(t, 4), c) for t, c in pts if 0.0 < t < 1.0]
    keys.append((1.0, sample(1.0)))
    if len(keys) > 20:  # ColorSequence holds 2..20 keypoints
        step = (len(keys) - 1) / 19.0
        keys = [keys[int(round(i * step))] for i in range(20)]
        keys[0], keys[-1] = (0.0, keys[0][1]), (1.0, keys[-1][1])
    return keys


def map_constraint_axis(mode, start, length, parent_length):
    """One axis of a Figma LayoutConstraint -> (anchor, posScale, posOffset, sizeScale, sizeOffset).

    start/length are the child's position and size in the parent's box, in design px.
    """
    end_gap = parent_length - (start + length)
    if mode in ("RIGHT", "BOTTOM", "MAX"):
        return 1.0, 1.0, -end_gap, 0.0, length
    if mode == "CENTER":
        return 0.5, 0.5, (start + length / 2.0) - parent_length / 2.0, 0.0, length
    if mode in ("LEFT_RIGHT", "TOP_BOTTOM", "STRETCH"):
        return 0.0, 0.0, start, 1.0, -(parent_length - length)
    if mode == "SCALE" and parent_length > 0:
        return 0.0, round(start / parent_length, 5), 0.0, round(length / parent_length, 5), 0.0
    return 0.0, 0.0, start, 0.0, length  # LEFT / TOP / MIN / unknown


def map_font_weight(weight, family_weights=None):
    """Figma numeric fontWeight -> (Enum.FontWeight item name, weight actually used)."""
    try:
        w = float(weight)
    except (TypeError, ValueError):
        w = 400.0
    target = min((abs(w - v), v) for v, _ in WEIGHTS)[1]
    if family_weights:
        # nearest shipped face; ties go to the heavier one so headings never get lighter
        target = min(family_weights, key=lambda v: (abs(v - target), -v))
    return dict(WEIGHTS)[target], target


def map_family(family):
    """Figma fontFamily -> (Roblox family display name, file stem, weights, warning or None)."""
    fam = (family or "").strip()
    if fam in ROBLOX_FAMILIES:
        stem, ws = ROBLOX_FAMILIES[fam]
        return fam, stem, ws, None
    for k in ROBLOX_FAMILIES:
        if k.lower() == fam.lower() or ROBLOX_FAMILIES[k][0].lower() == fam.replace(" ", "").lower():
            stem, ws = ROBLOX_FAMILIES[k]
            return k, stem, ws, None
    sub = FAMILY_FALLBACK.get(fam, DEFAULT_FAMILY)
    stem, ws = ROBLOX_FAMILIES[sub]
    return sub, stem, ws, "font '%s' is not built into Roblox; using %s (or upload the family as a font asset)" % (fam, sub)


def map_auto_layout(node):
    """Figma auto layout fields -> dict of UIListLayout / UIPadding values (None when no auto layout)."""
    mode = node.get("layoutMode", "NONE")
    if mode not in ("HORIZONTAL", "VERTICAL"):
        return None
    horizontal = mode == "HORIZONTAL"
    prim = node.get("primaryAxisAlignItems", "MIN")
    cross = node.get("counterAxisAlignItems", "MIN")
    h_names = {"MIN": "Left", "CENTER": "Center", "MAX": "Right", "SPACE_BETWEEN": "Left"}
    v_names = {"MIN": "Top", "CENTER": "Center", "MAX": "Bottom", "SPACE_BETWEEN": "Top", "BASELINE": "Center"}
    out = {
        "FillDirection": "Horizontal" if horizontal else "Vertical",
        "Padding": 0 if prim == "SPACE_BETWEEN" else float(node.get("itemSpacing", 0) or 0),
        "Wraps": node.get("layoutWrap") == "WRAP",
        "padding": [float(node.get(k, 0) or 0) for k in ("paddingTop", "paddingBottom", "paddingLeft", "paddingRight")],
        "notes": [],
    }
    if horizontal:
        out["HorizontalAlignment"] = h_names.get(prim, "Left")
        out["VerticalAlignment"] = v_names.get(cross, "Top")
    else:
        out["VerticalAlignment"] = v_names.get(prim, "Top")
        out["HorizontalAlignment"] = {"MIN": "Left", "CENTER": "Center", "MAX": "Right"}.get(cross, "Left")
    if prim == "SPACE_BETWEEN":
        out["HorizontalFlex" if horizontal else "VerticalFlex"] = "SpaceBetween"
    if cross == "BASELINE":
        out["notes"].append("BASELINE alignment approximated as Center")
    if out["Wraps"] and float(node.get("counterAxisSpacing", out["Padding"]) or 0) != out["Padding"]:
        out["notes"].append("counterAxisSpacing differs from itemSpacing; UIListLayout has one Padding (line gap uses it)")
    if node.get("counterAxisAlignContent") == "SPACE_BETWEEN":
        out["notes"].append("counterAxisAlignContent SPACE_BETWEEN has no direct equivalent")
    return out


def child_sizing(child, parent_horizontal):
    """(main, cross) sizing of a child inside an auto layout parent: FIXED / HUG / FILL."""
    h = child.get("layoutSizingHorizontal")
    v = child.get("layoutSizingVertical")
    if h is None:  # older exports: layoutGrow / layoutAlign
        h = "FILL" if (parent_horizontal and child.get("layoutGrow") == 1) or \
                      (not parent_horizontal and child.get("layoutAlign") == "STRETCH") else "FIXED"
    if v is None:
        v = "FILL" if (not parent_horizontal and child.get("layoutGrow") == 1) or \
                      (parent_horizontal and child.get("layoutAlign") == "STRETCH") else "FIXED"
    return (h, v) if parent_horizontal else (v, h)


def export_scale(w, h, wanted=2.0):
    """Largest export scale <= wanted that keeps the long side within the 1024 px upload cap."""
    long_side = max(w, h, 1.0)
    s = min(wanted, MAX_TEXTURE / long_side)
    return tidy(math.floor(s * 100) / 100.0)


# ----------------------------------------------------------------------------------------- input

def load_root(data, node_query):
    """Find the requested node in any supported JSON shape."""
    candidates = []
    if isinstance(data.get("nodes"), dict):
        for entry in data["nodes"].values():
            if entry and isinstance(entry.get("document"), dict):
                candidates.append(entry["document"])
    elif isinstance(data.get("document"), dict):
        candidates.append(data["document"])
    elif "type" in data:
        candidates.append(data)
    if not candidates:
        raise SystemExit("error: no Figma document or node found in the input JSON")

    def walk(n):
        yield n
        for c in n.get("children", []) or []:
            yield from walk(c)

    if node_query:
        q = node_query.strip()
        for root in candidates:
            for n in walk(root):
                if n.get("id") == q:
                    return n
        for root in candidates:
            for n in walk(root):
                if str(n.get("name", "")).strip().lower() == q.lower() and n.get("type") in CONTAINER_TYPES:
                    return n
        raise SystemExit("error: node '%s' not found (match by id like 12:34 or by frame name)" % q)
    for root in candidates:
        for n in walk(root):
            if n.get("type") in ("FRAME", "COMPONENT", "INSTANCE"):
                return n
    return candidates[0]


# ----------------------------------------------------------------------------------------- converter

class Converter:
    def __init__(self, reference=(1920, 1080), screen=False, per_corner=False, rotation_units="rad"):
        self.reference = reference
        self.screen = screen
        self.per_corner = per_corner
        self.rotation_units = rotation_units
        self.lines = []
        self.depth = 1
        self.counter = 0
        self.warnings = []
        self.manifest = []
        self.unsupported = {}
        self.ref_names = {}
        self.min_text = None
        self.type_counts = {}

    # -- bookkeeping
    def emit(self, line=""):
        self.lines.append(("\t" * self.depth + line) if line else "")

    def warn(self, path, msg, feature=None):
        self.warnings.append("%s: %s" % (path, msg))
        if feature:
            self.unsupported[feature] = self.unsupported.get(feature, 0) + 1

    def new_var(self):
        self.counter += 1
        return "o%d" % self.counter

    def ref_key(self, name):
        key = name
        n = 2
        while key in self.ref_names:
            key = "%s_%d" % (name, n)
            n += 1
        self.ref_names[key] = True
        return key

    # -- geometry
    def rotation_deg(self, node):
        rt = node.get("relativeTransform")
        if isinstance(rt, list) and len(rt) >= 2:
            # Figma (plugin docs): rotation = atan2(-m10, m00), counter-clockwise positive
            return math.degrees(math.atan2(-float(rt[1][0]), float(rt[0][0])))
        r = float(node.get("rotation", 0) or 0)
        return math.degrees(r) if self.rotation_units == "rad" else r

    def box(self, node, path):
        bb = node.get("absoluteBoundingBox") or {}
        x, y = float(bb.get("x", 0)), float(bb.get("y", 0))
        W, H = float(bb.get("width", 0)), float(bb.get("height", 0))
        rot = self.rotation_deg(node)
        if abs(rot) < 0.01:
            return x, y, W, H, 0.0
        size = node.get("size")
        if isinstance(size, dict) and "x" in size:
            w, h = float(size["x"]), float(size["y"])
        else:
            c, s = abs(math.cos(math.radians(rot))), abs(math.sin(math.radians(rot)))
            det = c * c - s * s
            if abs(det) < 1e-3:
                w = h = W / (c + s) if (c + s) else W
                self.warn(path, "rotated near 45 degrees without `size`; assumed square (export with geometry=paths)")
            else:
                w, h = (W * c - H * s) / det, (H * c - W * s) / det
        cx, cy = x + W / 2.0, y + H / 2.0
        return cx - w / 2.0, cy - h / 2.0, w, h, rot

    # -- paint helpers
    @staticmethod
    def visible_paints(paints):
        return [p for p in (paints or []) if p.get("visible", True) is not False]

    def emit_gradient(self, var, paint, w, h, path):
        kind = paint["type"]
        handles = paint.get("gradientHandlePositions") or [{"x": 0, "y": 0.5}, {"x": 1, "y": 0.5}, {"x": 0, "y": 1}]
        stops = paint.get("gradientStops") or []
        g = self.new_var()
        self.emit('local %s = Instance.new("UIGradient")' % g)
        if kind == "GRADIENT_LINEAR":
            rot = gradient_rotation(handles, w, h)
            keys = remap_stops(handles, stops, w, h)
        else:
            # radial family: keep Figma stop positions (centre = 0, edge = 1)
            keys = [(round(min(1, max(0, float(s.get("position", 0)))), 4),
                     tuple(float(s["color"].get(k, 1 if k == "a" else 0)) for k in "rgba")) for s in stops]
            keys.sort(key=lambda k: k[0])
            if not keys:
                keys = [(0.0, (1, 1, 1, 1)), (1.0, (1, 1, 1, 1))]
            if keys[0][0] > 0:
                keys.insert(0, (0.0, keys[0][1]))
            if keys[-1][0] < 1:
                keys.append((1.0, keys[-1][1]))
            keys = keys[:19] + [keys[-1]] if len(keys) > 20 else keys
            rot = gradient_rotation(handles, w, h)
            cx, cy = float(handles[0]["x"]), float(handles[0]["y"])
            rx = math.hypot((handles[1]["x"] - cx) * w, (handles[1]["y"] - cy) * h)
            ry = math.hypot((handles[2]["x"] - cx) * w, (handles[2]["y"] - cy) * h) if len(handles) > 2 else rx
            enum_item = {"GRADIENT_RADIAL": "Elliptical", "GRADIENT_ANGULAR": "Conical",
                         "GRADIENT_DIAMOND": "Elliptical"}[kind]
            self.emit("-- %s: GradientType may need the UI beta in Studio; Linear is the fallback" % kind)
            self.emit("pcall(function()")
            self.emit("\t%s.Type = Enum.GradientType.%s" % (g, enum_item))
            self.emit("end)")
            if abs(cx - 0.5) > 1e-3 or abs(cy - 0.5) > 1e-3:
                self.emit("%s.Offset = Vector2.new(%s, %s)" % (g, num(cx - 0.5), num(cy - 0.5)))
            if w > 0 and h > 0:
                scale = ((rx / (w / 2.0)) + (ry / (h / 2.0))) / 2.0
                if abs(scale - 1) > 1e-3:
                    self.emit("%s.Scale = %s" % (g, num(max(0.001, scale))))
            if kind != "GRADIENT_RADIAL":
                self.warn(path, "%s approximated with %s" % (kind, enum_item), kind)
        if rot:
            self.emit("%s.Rotation = %s" % (g, num(rot)))
        color_keys = ", ".join("ColorSequenceKeypoint.new(%s, %s)" % (num(t), color3({"r": c[0], "g": c[1], "b": c[2]}))
                               for t, c in keys)
        self.emit("%s.Color = ColorSequence.new({ %s })" % (g, color_keys))
        if any(c[3] < 0.999 for _, c in keys):
            tkeys = ", ".join("NumberSequenceKeypoint.new(%s, %s)" % (num(t), num(1 - c[3])) for t, c in keys)
            self.emit("%s.Transparency = NumberSequence.new({ %s })" % (g, tkeys))
        self.emit("%s.Parent = %s" % (g, var))

    def emit_stroke(self, var, node, is_text, path, opacity):
        strokes = self.visible_paints(node.get("strokes"))
        weight = float(node.get("strokeWeight", 0) or 0)
        if not strokes or weight <= 0:
            return
        paint = strokes[-1]
        if len(strokes) > 1:
            self.warn(path, "%d strokes; using the top one" % len(strokes), "multiple strokes")
        if paint.get("type") == "SOLID":
            c = paint.get("color", {})
        else:
            stops = paint.get("gradientStops") or [{"color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
            c = stops[0]["color"]
            self.warn(path, "%s stroke flattened to its first stop colour" % paint.get("type"), "gradient stroke")
        alpha = float(c.get("a", 1)) * float(paint.get("opacity", 1)) * opacity
        s = self.new_var()
        self.emit('local %s = Instance.new("UIStroke")' % s)
        if is_text:
            self.emit("%s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual" % s)
        else:
            self.emit("%s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border" % s)
            pos = {"INSIDE": "Inner", "OUTSIDE": "Outer", "CENTER": "Center"}.get(node.get("strokeAlign", "INSIDE"), "Inner")
            self.emit("%s.BorderStrokePosition = Enum.BorderStrokePosition.%s" % (s, pos))
        self.emit("%s.Thickness = %s" % (s, num(weight)))
        self.emit("%s.Color = %s" % (s, color3(c)))
        if alpha < 0.999:
            self.emit("%s.Transparency = %s" % (s, num(1 - alpha)))
        join = {"MITER": "Miter", "BEVEL": "Bevel", "ROUND": "Round"}.get(node.get("strokeJoin", ""))
        if join:
            self.emit("%s.LineJoinMode = Enum.LineJoinMode.%s" % (s, join))
        self.emit("%s.Parent = %s" % (s, var))
        if node.get("individualStrokeWeights"):
            self.warn(path, "per-side stroke weights: UIStroke is uniform; use divider frames for single sides",
                      "individualStrokeWeights")
        if node.get("strokeDashes"):
            self.warn(path, "dashed stroke: export the outline as an image (img_ or 9s_ prefix)", "strokeDashes")

    def emit_corner(self, var, node, w, h, path):
        if node.get("type") == "ELLIPSE":
            c = self.new_var()
            self.emit('local %s = Instance.new("UICorner")' % c)
            self.emit("%s.CornerRadius = UDim.new(0.5, 0)" % c)
            self.emit("%s.Parent = %s" % (c, var))
            if abs(w - h) > 0.5:
                self.warn(path, "non-circular ellipse drawn as a pill; export as image for a true ellipse", "ellipse")
            return
        radii = node.get("rectangleCornerRadii")
        r = float(node.get("cornerRadius", 0) or 0)
        half = min(w, h) / 2.0

        def udim(v):
            return "UDim.new(0.5, 0)" if half > 0 and v >= half - 0.01 else "UDim.new(0, %s)" % num(v)

        if radii and len(radii) == 4 and len(set(float(v) for v in radii)) > 1:
            tl, tr, br, bl = (float(v) for v in radii)
            c = self.new_var()
            self.emit('local %s = Instance.new("UICorner")' % c)
            if self.per_corner:
                self.emit("%s.TopLeftRadius = %s" % (c, udim(tl)))
                self.emit("%s.TopRightRadius = %s" % (c, udim(tr)))
                self.emit("%s.BottomRightRadius = %s" % (c, udim(br)))
                self.emit("%s.BottomLeftRadius = %s" % (c, udim(bl)))
                self.warn(path, "per-corner radii emitted (UI beta feature)", None)
            else:
                self.emit("%s.CornerRadius = %s -- mixed corners %s; see --per-corner" %
                          (c, udim(max(tl, tr, br, bl)), "/".join(num(v) for v in (tl, tr, br, bl))))
                self.warn(path, "mixed corner radii collapsed to the largest; use --per-corner or a covering strip",
                          "mixed corner radii")
            self.emit("%s.Parent = %s" % (c, var))
        elif r > 0:
            c = self.new_var()
            self.emit('local %s = Instance.new("UICorner")' % c)
            self.emit("%s.CornerRadius = %s" % (c, udim(r)))
            self.emit("%s.Parent = %s" % (c, var))
        if node.get("cornerSmoothing"):
            self.warn(path, "corner smoothing (squircle) not available; plain radius used", "cornerSmoothing")

    # -- text
    def text_markup(self, node, base_style, path):
        chars = node.get("characters", "") or ""
        overrides = node.get("characterStyleOverrides") or []
        table = node.get("styleOverrideTable") or {}
        case = base_style.get("textCase", "ORIGINAL")

        def apply_case(s, case_mode):
            if case_mode == "UPPER":
                return s.upper()
            if case_mode == "LOWER":
                return s.lower()
            if case_mode == "TITLE":
                return s.title()
            return s

        if not overrides or not any(overrides):
            text = apply_case(chars, case)
            if case in ("SMALL_CAPS", "SMALL_CAPS_FORCED"):
                return "<sc>%s</sc>" % rich_escape(text), True
            deco = base_style.get("textDecoration", "NONE")
            if deco in ("UNDERLINE", "STRIKETHROUGH"):
                tag = "u" if deco == "UNDERLINE" else "s"
                return "<%s>%s</%s>" % (tag, rich_escape(text), tag), True
            return text, False
        # mixed styles -> RichText runs
        runs = []
        cur, buf = None, []
        for i, ch in enumerate(chars):
            sid = overrides[i] if i < len(overrides) else 0
            if sid != cur and buf:
                runs.append((cur, "".join(buf)))
                buf = []
            cur = sid
            buf.append(ch)
        if buf:
            runs.append((cur, "".join(buf)))
        parts = []
        for sid, text in runs:
            st = table.get(str(sid)) if sid else None
            text = rich_escape(apply_case(text, (st or {}).get("textCase", case)))
            if not st:
                parts.append(text)
                continue
            attrs = []
            fills = self.visible_paints(st.get("fills"))
            if fills and fills[-1].get("type") == "SOLID":
                attrs.append('color="%s"' % hex_color(fills[-1]["color"]))
            if "fontSize" in st:
                attrs.append('size="%s"' % num(st["fontSize"]))
            if "fontWeight" in st:
                attrs.append('weight="%s"' % map_font_weight(st["fontWeight"])[1])
            if "fontFamily" in st:
                _, stem, _, w = map_family(st["fontFamily"])
                attrs.append('family="rbxasset://fonts/families/%s.json"' % stem)
                if w:
                    self.warn(path, w, "font substitution")
            if attrs:
                text = "<font %s>%s</font>" % (" ".join(attrs), text)
            if st.get("italic"):
                text = "<i>%s</i>" % text
            if st.get("textDecoration") == "UNDERLINE":
                text = "<u>%s</u>" % text
            elif st.get("textDecoration") == "STRIKETHROUGH":
                text = "<s>%s</s>" % text
            parts.append(text)
        return "".join(parts), True

    def emit_text(self, var, node, opacity, path, sizing_hug):
        st = node.get("style") or {}
        fam, stem, weights, fam_warn = map_family(st.get("fontFamily"))
        if fam_warn:
            self.warn(path, fam_warn, "font substitution")
        weight_name, used = map_font_weight(st.get("fontWeight", 400), weights)
        asked = st.get("fontWeight", 400)
        if abs(float(asked) - used) > 50:
            self.warn(path, "weight %s not shipped for %s; using %d" % (num(asked), fam, used), "font weight snap")
        style = "Italic" if st.get("italic") else "Normal"
        self.emit('%s.FontFace = Font.new("rbxasset://fonts/families/%s.json", Enum.FontWeight.%s, Enum.FontStyle.%s)'
                  % (var, stem, weight_name, style))
        size = float(st.get("fontSize", 14) or 14)
        self.min_text = size if self.min_text is None else min(self.min_text, size)
        self.emit("%s.TextSize = %s" % (var, num(size)))
        text, rich = self.text_markup(node, st, path)
        if rich:
            self.emit("%s.RichText = true" % var)
        self.emit("%s.Text = %s" % (var, lua_str(text)))
        fills = self.visible_paints(node.get("fills"))
        if fills:
            p = fills[-1]
            c = p.get("color") if p.get("type") == "SOLID" else (p.get("gradientStops") or [{"color": {}}])[0]["color"]
            if p.get("type") != "SOLID":
                self.warn(path, "gradient text: use a UIGradient on the label (tints the glyphs) or export as image",
                          "gradient text fill")
            alpha = float(c.get("a", 1)) * float(p.get("opacity", 1)) * opacity
            self.emit("%s.TextColor3 = %s" % (var, color3(c)))
            if alpha < 0.999:
                self.emit("%s.TextTransparency = %s" % (var, num(1 - alpha)))
        xa = {"LEFT": "Left", "CENTER": "Center", "RIGHT": "Right", "JUSTIFIED": "Left"}.get(st.get("textAlignHorizontal", "LEFT"), "Left")
        if st.get("textAlignHorizontal") == "JUSTIFIED":
            self.warn(path, "justified text drawn left-aligned", "justified text")
        ya = {"TOP": "Top", "CENTER": "Center", "BOTTOM": "Bottom"}.get(st.get("textAlignVertical", "TOP"), "Top")
        self.emit("%s.TextXAlignment = Enum.TextXAlignment.%s" % (var, xa))
        self.emit("%s.TextYAlignment = Enum.TextYAlignment.%s" % (var, ya))
        lh = None
        unit = st.get("lineHeightUnit")
        if unit == "PIXELS" and st.get("lineHeightPx"):
            lh = float(st["lineHeightPx"]) / size
        elif unit == "FONT_SIZE_%" and st.get("lineHeightPercentFontSize"):
            lh = float(st["lineHeightPercentFontSize"]) / 100.0
        if lh is not None:
            if lh < 1.0 or lh > 3.0:
                self.warn(path, "line height %.2f outside Roblox's 1.0-3.0; clamped" % lh, "line height clamp")
            lh = min(3.0, max(1.0, lh))
            if abs(lh - 1.0) > 0.01:
                self.emit("%s.LineHeight = %s" % (var, num(round(lh, 3))))
        if float(st.get("letterSpacing", 0) or 0) != 0:
            self.warn(path, "letterSpacing %s px has no TextLabel equivalent; keep default tracking" %
                      num(st["letterSpacing"]), "letterSpacing")
        resize = st.get("textAutoResize", "NONE")
        if resize == "WIDTH_AND_HEIGHT" or sizing_hug == "XY":
            self.emit("%s.AutomaticSize = Enum.AutomaticSize.XY" % var)
        else:
            self.emit("%s.TextWrapped = true" % var)
            if resize == "HEIGHT" or sizing_hug == "Y":
                self.emit("%s.AutomaticSize = Enum.AutomaticSize.Y" % var)
        if st.get("textTruncation") == "ENDING" or resize == "TRUNCATE":
            self.emit("%s.TextTruncate = Enum.TextTruncate.AtEnd" % var)
            if st.get("maxLines"):
                self.warn(path, "maxLines %s: size the box to that many lines" % st["maxLines"], "maxLines")

    # -- node
    def convert_node(self, node, parent_var, parent_box, flow, index, count, path, reverse_z=False, top_level=False):
        name = clean_name(node.get("name"))
        path = "%s/%s" % (path, name)
        ntype = node.get("type", "FRAME")
        self.type_counts[ntype] = self.type_counts.get(ntype, 0) + 1
        lower = name.lower()
        if lower.startswith("skip_"):
            return
        x, y, w, h, rot = self.box(node, path)
        px, py, pw, ph = parent_box
        rx, ry = x - px, y - py
        opacity = float(node.get("opacity", 1) or 0) if "opacity" in node else 1.0

        fills = self.visible_paints(node.get("fills"))
        image_fill = next((p for p in reversed(fills) if p.get("type") == "IMAGE"), None)
        is_9s = lower.startswith("9s_")
        flatten = lower.startswith("img_") or is_9s or ntype in VECTOR_TYPES
        is_button = lower.startswith("btn_")
        is_scroll = lower.startswith("scroll_")
        if ntype == "TEXT":
            cls = "TextButton" if is_button else "TextLabel"
        elif flatten or image_fill is not None:
            cls = "ImageButton" if is_button else "ImageLabel"
        elif is_button:
            cls = "TextButton"
        elif is_scroll:
            cls = "ScrollingFrame"
        else:
            cls = "Frame"
        for p in fills:
            if p.get("type") in ("EMOJI", "VIDEO", "PATTERN"):
                self.warn(path, "%s paint not supported; export as image" % p["type"], p["type"] + " paint")
        blend = node.get("blendMode", "PASS_THROUGH")
        if blend not in ("PASS_THROUGH", "NORMAL"):
            self.warn(path, "blend mode %s not available in UI; bake into an image" % blend, "blendMode")
        if node.get("isMask"):
            self.warn(path, "mask layer: use ClipsDescendants or a CanvasGroup, or bake into an image", "mask")

        effects = [e for e in (node.get("effects") or []) if e.get("visible", True) is not False]
        shadow = next((e for e in effects if e.get("type") == "DROP_SHADOW"), None) if not flatten else None
        for e in effects:
            t = e.get("type")
            if flatten:
                break
            if t == "DROP_SHADOW" and e is not shadow:
                self.warn(path, "extra drop shadow ignored (one shadow image per node)", "multiple shadows")
            elif t == "INNER_SHADOW":
                self.warn(path, "inner shadow: use an Inner UIStroke or a gradient overlay frame", "INNER_SHADOW")
            elif t in ("LAYER_BLUR", "BACKGROUND_BLUR", "TEXTURE", "NOISE"):
                self.warn(path, "%s: bake it into an exported image (img_ prefix)" % t, t)

        # --- layout placement values
        text_resize = (node.get("style") or {}).get("textAutoResize", "NONE") if ntype == "TEXT" else "NONE"
        hug_x = hug_y = False
        flex = None
        if flow is not None:
            horizontal = flow["FillDirection"] == "Horizontal"
            main, cross = child_sizing(node, horizontal)
            anchor = (0.0, 0.0)
            pos = None
            if main == "FILL" or cross == "FILL":
                flex = (main == "FILL", cross == "FILL")
            hug_x = (main if horizontal else cross) == "HUG"
            hug_y = (cross if horizontal else main) == "HUG"
            sxs, sxo, sys_, syo = 0.0, w, 0.0, h
        else:
            cons = node.get("constraints") or {"horizontal": "LEFT", "vertical": "TOP"}
            ax, pxs, pxo, sxs, sxo = map_constraint_axis(cons.get("horizontal", "LEFT"), rx, w, pw)
            ay, pys, pyo, sys_, syo = map_constraint_axis(cons.get("vertical", "TOP"), ry, h, ph)
            if rot:
                # Roblox rotates about the centre: move the anchor to the centre, same visual spot
                pxs, pxo = pxs + (0.5 - ax) * sxs, pxo + (0.5 - ax) * sxo
                pys, pyo = pys + (0.5 - ay) * sys_, pyo + (0.5 - ay) * syo
                ax, ay = 0.5, 0.5
            anchor = (ax, ay)
            pos = "UDim2.new(%s, %s, %s, %s)" % (num(pxs), num(pxo), num(pys), num(pyo))
        if node.get("layoutMode") in ("HORIZONTAL", "VERTICAL") and flow is None:
            hug_x = node.get("layoutSizingHorizontal") == "HUG"
            hug_y = node.get("layoutSizingVertical") == "HUG"
        if text_resize == "WIDTH_AND_HEIGHT":
            hug_x = hug_y = True
        elif text_resize == "HEIGHT":
            hug_y = True
        hug_axes = "XY" if hug_x and hug_y else ("X" if hug_x else ("Y" if hug_y else ""))
        # a hugging axis starts from 0 and grows with AutomaticSize (so shorter or translated text shrinks it)
        if hug_x and sxs == 0:
            sxo = 0.0
        if hug_y and sys_ == 0:
            syo = 0.0
        size = "UDim2.new(%s, %s, %s, %s)" % (num(sxs), num(sxo), num(sys_), num(syo))

        z = (count - index) if reverse_z else (index + 1)

        # --- drop shadow slot: the slot takes the layout place; shadow and node sit inside it
        target_parent = parent_var
        slot_var = None
        if shadow is not None:
            slot_var = self.new_var()
            self.emit("do -- %s (slot holding the drop shadow)" % name)
            self.depth += 1
            self.emit('local %s = Instance.new("Frame")' % slot_var)
            self.emit("%s.Name = %s" % (slot_var, lua_str(name + "_Slot")))
            self.emit("%s.BackgroundTransparency = 1" % slot_var)
            self.emit_place(slot_var, anchor, pos, size, z, index, flow, rot)
            if flex:
                self.emit_flex(slot_var, flex)
            self.emit_shadow(slot_var, node, shadow, w, h, path)
            target_parent = slot_var
            anchor, pos, size = (0.0, 0.0), "UDim2.fromOffset(0, 0)", "UDim2.fromScale(1, 1)"
            if hug_axes:
                self.warn(path, "hugging node with a drop shadow: the slot keeps the design size", "hug + shadow")
        var = self.new_var()
        self.emit("do -- %s (%s)" % (name, ntype))
        self.depth += 1
        self.emit('local %s = Instance.new("%s")' % (var, cls))
        self.emit("%s.Name = %s" % (var, lua_str(name)))
        if shadow is not None:
            self.emit_place(var, anchor, pos, size, 2, None, None, 0.0)
        else:
            self.emit_place(var, anchor, pos, size, z, index, flow, rot)
            if flex:
                self.emit_flex(var, flex)
        if node.get("visible", True) is False:
            self.emit("%s.Visible = false" % var)
        self.emit("%s.BorderSizePixel = 0" % var)
        self.emit('%s:SetAttribute("FigmaId", %s)' % (var, lua_str(str(node.get("id", "")))))
        if node.get("componentId"):
            self.emit('%s:SetAttribute("FigmaComponentId", %s)' % (var, lua_str(node["componentId"])))
            for pname, prop in sorted((node.get("componentProperties") or {}).items()):
                if isinstance(prop, dict) and prop.get("type") == "VARIANT":
                    key = re.sub(r"[^A-Za-z0-9_]", "", pname.split("#")[0]) or "Variant"
                    self.emit('%s:SetAttribute(%s, %s)' % (var, lua_str("Variant_" + key), lua_str(str(prop.get("value", "")))))
        if opacity < 0.999 and node.get("children"):
            self.warn(path, "layer opacity %.2f applied to this node only; use a CanvasGroup to fade the whole group" % opacity,
                      "group opacity")

        # --- background / image
        if ntype == "TEXT":
            self.emit("%s.BackgroundTransparency = 1" % var)
            if cls == "TextButton":
                self.emit("%s.AutoButtonColor = false" % var)
            self.emit_text(var, node, opacity, path, hug_axes)
            self.emit_stroke(var, node, True, path, opacity)
        elif flatten:
            self.emit("%s.BackgroundTransparency = 1" % var)
            only_image = image_fill if (not is_9s and not node.get("children") and len(fills) == 1) else None
            self.emit_image(var, node, w, h, path, is_9s, only_image)
            if cls == "ImageButton":
                self.emit("%s.AutoButtonColor = false" % var)
        else:
            solid_under = None
            if image_fill is not None:
                below = [p for p in fills if p is not image_fill]
                solid_under = below[-1] if below else None
                if solid_under and solid_under.get("type") != "SOLID":
                    solid_under = None
                self.emit_image(var, node, w, h, path, False, image_fill)
                if opacity < 0.999 or float(image_fill.get("opacity", 1)) < 0.999:
                    self.emit("%s.ImageTransparency = %s" % (var, num(1 - opacity * float(image_fill.get("opacity", 1)))))
                if cls == "ImageButton":
                    self.emit("%s.AutoButtonColor = false" % var)
                bg = solid_under
            else:
                bg = fills[-1] if fills else None
                if len(fills) > 1:
                    self.warn(path, "%d stacked fills; using the top one (layer frames or export for the rest)" % len(fills),
                              "stacked fills")
            if cls == "TextButton":
                self.emit('%s.Text = ""' % var)
                self.emit("%s.AutoButtonColor = false" % var)
            if bg is None:
                self.emit("%s.BackgroundTransparency = 1" % var)
            elif bg.get("type") == "SOLID":
                c = bg.get("color", {})
                alpha = float(c.get("a", 1)) * float(bg.get("opacity", 1)) * opacity
                self.emit("%s.BackgroundColor3 = %s" % (var, color3(c)))
                if alpha < 0.999:
                    self.emit("%s.BackgroundTransparency = %s" % (var, num(1 - alpha)))
            elif str(bg.get("type", "")).startswith("GRADIENT_"):
                alpha = float(bg.get("opacity", 1)) * opacity
                self.emit("%s.BackgroundColor3 = Color3.new(1, 1, 1)" % var)
                if alpha < 0.999:
                    self.emit("%s.BackgroundTransparency = %s" % (var, num(1 - alpha)))
                self.emit_gradient(var, bg, w, h, path)
            else:
                self.emit("%s.BackgroundTransparency = 1" % var)
            if node.get("clipsContent") and node.get("children"):
                self.emit("%s.ClipsDescendants = true" % var)
                painted = any(c.get("type") != "TEXT" and self.visible_paints(c.get("fills"))
                              for c in node.get("children") or [])
                if float(node.get("cornerRadius", 0) or 0) > 0 and painted:
                    self.warn(path, "clips to a rounded shape: ClipsDescendants clips the rectangle; "
                                    "use a CanvasGroup with the UICorner if children reach the corners", "rounded clipping")
            self.emit_corner(var, node, w, h, path)
            self.emit_stroke(var, node, False, path, opacity)
        if cls == "ScrollingFrame":
            self.emit("%s.CanvasSize = UDim2.new()" % var)
            al = map_auto_layout(node)
            axis = "Y" if not al or al["FillDirection"] == "Vertical" else "X"
            self.emit("%s.AutomaticCanvasSize = Enum.AutomaticSize.%s" % (var, axis))
            self.emit("%s.ScrollingDirection = Enum.ScrollingDirection.%s" % (var, axis))
            self.emit("%s.ScrollBarThickness = 6" % var)

        if hug_axes and ntype != "TEXT":
            self.emit("%s.AutomaticSize = Enum.AutomaticSize.%s" % (var, hug_axes))

        # --- the Fit scale: one per root (or per top-level child in --screen mode)
        if top_level:
            outer = slot_var or var  # the shadow slot (when there is one) is what gets placed and scaled
            if not self.screen:
                self.emit("root = %s" % outer)
            self.emit_fit_scale(outer)

        if is_button or is_scroll or top_level:
            key = self.ref_key(name)
            self.emit("refs[%s] = %s" % (lua_str(key), var))

        # --- children
        children = [c for c in (node.get("children") or [])] if not flatten else []
        if flatten and node.get("children"):
            self.type_counts["(flattened children)"] = self.type_counts.get("(flattened children)", 0) + len(node["children"])
        if children:
            al = map_auto_layout(node)
            if node.get("layoutMode") == "GRID":
                self.warn(path, "grid auto layout placed absolutely; consider a UIGridLayout", "GRID layout")
            my_box = (x, y, w, h)
            flow_parent = var
            if al:
                absolute = [c for c in children if c.get("layoutPositioning") == "ABSOLUTE"]
                if absolute:
                    flow_parent = self.new_var()
                    self.emit('local %s = Instance.new("Frame")' % flow_parent)
                    self.emit('%s.Name = "Flow"' % flow_parent)
                    self.emit("%s.BackgroundTransparency = 1" % flow_parent)
                    self.emit("%s.Size = UDim2.fromScale(1, 1)" % flow_parent)
                    self.emit("%s.Parent = %s" % (flow_parent, var))
                    if hug_axes:
                        self.warn(path, "hugging frame with absolute children: check the size in Studio", "hug + absolute")
                self.emit_list_layout(flow_parent, al, path)
            rev = bool(node.get("itemReverseZIndex"))
            n = len(children)
            for i, child in enumerate(children):
                if al and child.get("layoutPositioning") != "ABSOLUTE":
                    self.convert_node(child, flow_parent, my_box, al, i, n, path, rev)
                else:
                    self.convert_node(child, var, my_box, None, i, n, path, rev)
        if target_parent:
            self.emit("%s.Parent = %s" % (var, target_parent))
        self.depth -= 1
        self.emit("end")
        if slot_var:
            if parent_var:
                self.emit("%s.Parent = %s" % (slot_var, parent_var))
            self.depth -= 1
            self.emit("end")

    def emit_place(self, var, anchor, pos, size, z, index, flow, rot):
        if anchor != (0.0, 0.0):
            self.emit("%s.AnchorPoint = Vector2.new(%s, %s)" % (var, num(anchor[0]), num(anchor[1])))
        if pos is not None:
            self.emit("%s.Position = %s" % (var, pos))
        self.emit("%s.Size = %s" % (var, size))
        if rot:
            self.emit("%s.Rotation = %s" % (var, num(round(-rot, 3))))  # Figma CCW+, Roblox CW+
        self.emit("%s.ZIndex = %d" % (var, z))
        if flow is not None and index is not None:
            self.emit("%s.LayoutOrder = %d" % (var, (index + 1) * 10))

    def emit_flex(self, var, flex):
        fill_main, fill_cross = flex
        f = self.new_var()
        self.emit('local %s = Instance.new("UIFlexItem")' % f)
        self.emit("%s.FlexMode = Enum.UIFlexMode.%s" % (f, "Fill" if fill_main else "None"))
        if fill_cross:
            self.emit("%s.ItemLineAlignment = Enum.ItemLineAlignment.Stretch" % f)
        self.emit("%s.Parent = %s" % (f, var))

    def emit_list_layout(self, var, al, path):
        l = self.new_var()
        self.emit('local %s = Instance.new("UIListLayout")' % l)
        self.emit("%s.FillDirection = Enum.FillDirection.%s" % (l, al["FillDirection"]))
        self.emit("%s.SortOrder = Enum.SortOrder.LayoutOrder" % l)
        self.emit("%s.HorizontalAlignment = Enum.HorizontalAlignment.%s" % (l, al["HorizontalAlignment"]))
        self.emit("%s.VerticalAlignment = Enum.VerticalAlignment.%s" % (l, al["VerticalAlignment"]))
        self.emit("%s.Padding = UDim.new(0, %s)" % (l, num(al["Padding"])))
        if al["Wraps"]:
            self.emit("%s.Wraps = true" % l)
        if "HorizontalFlex" in al:
            self.emit("%s.HorizontalFlex = Enum.UIFlexAlignment.%s" % (l, al["HorizontalFlex"]))
        if "VerticalFlex" in al:
            self.emit("%s.VerticalFlex = Enum.UIFlexAlignment.%s" % (l, al["VerticalFlex"]))
        self.emit("%s.Parent = %s" % (l, var))
        for note in al["notes"]:
            self.warn(path, note, "auto layout approximation")
        top, bottom, left, right = al["padding"]
        if any(v > 0 for v in (top, bottom, left, right)):
            p = self.new_var()
            self.emit('local %s = Instance.new("UIPadding")' % p)
            for prop, v in (("PaddingTop", top), ("PaddingBottom", bottom), ("PaddingLeft", left), ("PaddingRight", right)):
                if v:
                    self.emit("%s.%s = UDim.new(0, %s)" % (p, prop, num(v)))
            self.emit("%s.Parent = %s" % (p, var))

    def emit_image(self, var, node, w, h, path, is_9s, paint):
        name = clean_name(node.get("name"))
        stem = re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_") or "image"
        stem = re.sub(r"__\d+$", "", stem)
        scale = export_scale(w, h)
        entry = {"id": node.get("id"), "name": name, "file": stem + ".png", "designSize": [tidy(w), tidy(h)],
                 "exportScale": scale, "pixelSize": [int(round(w * scale)), int(round(h * scale))]}
        if paint is not None:
            entry["kind"] = "image-fill"
            entry["imageRef"] = paint.get("imageRef")
            mode = paint.get("scaleMode", "FILL")
            st = {"FILL": "Crop", "FIT": "Fit", "TILE": "Tile", "STRETCH": "Stretch"}.get(mode, "Crop")
            self.emit("%s.ScaleType = Enum.ScaleType.%s" % (var, st))
            if mode == "TILE":
                f = float(paint.get("scalingFactor", 1) or 1)
                self.emit("%s.TileSize = UDim2.fromOffset(%s, %s) -- source image size x scalingFactor %s; check in Studio"
                          % (var, num(64 * f), num(64 * f), num(f)))
                self.warn(path, "tiled image: set TileSize to the image's design size", "tiled image")
            if mode == "STRETCH" and paint.get("imageTransform"):
                self.warn(path, "image crop transform ignored; crop the PNG before upload", "imageTransform")
            entry["note"] = "export the original image (GET /v1/files/:key/images gives a URL per imageRef), not the frame"
        elif is_9s:
            entry["kind"] = "9slice"
            m = re.search(r"__(\d+)$", name)
            radius = float(node.get("cornerRadius", 0) or 0)
            inset = float(m.group(1)) if m else max(radius, float(node.get("strokeWeight", 0) or 0)) + 2
            if not m:
                self.warn(path, "9-slice inset guessed as %s px; name it like 9s_panel__24" % num(inset), "9-slice inset guess")
            # export a small source: corners plus a short stretchable middle
            tw, th = min(w, 2 * inset + 8), min(h, 2 * inset + 8)
            scale = export_scale(tw, th)
            entry.update({"designSize": [tidy(tw), tidy(th)], "exportScale": scale,
                          "pixelSize": [int(round(tw * scale)), int(round(th * scale))], "sliceInset": inset,
                          "note": "export a %s x %s px design-size copy of this node (resize in Figma first)" % (num(tw), num(th))})
            k = scale
            self.emit("%s.ScaleType = Enum.ScaleType.Slice" % var)
            self.emit("%s.SliceCenter = Rect.new(%s, %s, %s, %s)" % (var, num(inset * k), num(inset * k),
                                                                    num((tw - inset) * k), num((th - inset) * k)))
            if abs(k - 1) > 1e-6:
                self.emit("%s.SliceScale = %s" % (var, num(round(1 / k, 4))))
        else:
            entry["kind"] = "flatten"
            entry["note"] = "export this node as PNG with transparent background, trimmed"
            self.emit("%s.ScaleType = Enum.ScaleType.Fit" % var)
        self.emit('%s.Image = "" -- REPLACE_ME: upload %s (%dx%d px at %sx) and paste its rbxassetid'
                  % (var, entry["file"], entry["pixelSize"][0], entry["pixelSize"][1], num(entry["exportScale"])))
        if max(w, h) * 2 > MAX_TEXTURE:
            self.warn(path, "image is %sx%s design px; @2x would pass 1024, exported at %sx" % (num(w), num(h), num(scale)),
                      "image over 1024 at 2x")
        self.manifest.append(entry)

    def emit_shadow(self, slot, node, eff, w, h, path):
        c = eff.get("color", {"r": 0, "g": 0, "b": 0, "a": 0.25})
        off = eff.get("offset", {"x": 0, "y": 0})
        grow = float(eff.get("radius", 0) or 0) + float(eff.get("spread", 0) or 0)
        radius = float(node.get("cornerRadius", 0) or 0)
        inset = math.ceil(grow + radius)
        tex = 2 * inset + 4
        k = export_scale(tex, tex)
        s = self.new_var()
        self.emit('local %s = Instance.new("ImageLabel")' % s)
        self.emit('%s.Name = "Shadow"' % s)
        self.emit("%s.BackgroundTransparency = 1" % s)
        self.emit("%s.Position = UDim2.fromOffset(%s, %s)" % (s, num(float(off.get("x", 0)) - grow), num(float(off.get("y", 0)) - grow)))
        self.emit("%s.Size = UDim2.new(1, %s, 1, %s)" % (s, num(2 * grow), num(2 * grow)))
        self.emit("%s.ZIndex = 1" % s)
        self.emit("%s.ScaleType = Enum.ScaleType.Slice" % s)
        self.emit("%s.SliceCenter = Rect.new(%s, %s, %s, %s)" % (s, num(inset * k), num(inset * k), num((tex - inset) * k), num((tex - inset) * k)))
        if abs(k - 1) > 1e-6:
            self.emit("%s.SliceScale = %s" % (s, num(round(1 / k, 4))))
        self.emit("%s.ImageColor3 = %s" % (s, color3(c)))
        self.emit("%s.ImageTransparency = %s" % (s, num(round(1 - float(c.get("a", 1)), 3))))
        fname = "shadow_r%s_b%s.png" % (num(radius), num(grow))
        self.emit('%s.Image = "" -- REPLACE_ME: upload %s (white soft shadow, 9-slice) and paste its rbxassetid' % (s, fname))
        self.emit("%s.Parent = %s" % (s, slot))
        if not any(m.get("file") == fname for m in self.manifest):
            self.manifest.append({"id": node.get("id"), "name": clean_name(node.get("name")) + " shadow", "file": fname,
                                  "kind": "shadow", "designSize": [tex, tex], "exportScale": k,
                                  "pixelSize": [int(round(tex * k)), int(round(tex * k))], "sliceInset": inset,
                                  "note": "a %sx%s rect, corner radius %s, WHITE drop shadow blur %s spread %s, no offset; "
                                          "export only the shadow (hide the fill), tint in engine with ImageColor3"
                                          % (num(tex - 2 * grow), num(tex - 2 * grow), num(radius), num(eff.get("radius", 0)),
                                             num(eff.get("spread", 0)))})

    def emit_fit_scale(self, var):
        f = self.new_var()
        self.emit('local %s = Instance.new("UIScale")' % f)
        self.emit('%s.Name = "Fit"' % f)
        self.emit("%s.Parent = %s" % (f, var))

    # -- module
    def convert(self, root):
        x, y, w, h, _ = self.box(root, "root")
        name = clean_name(root.get("name"))
        self.depth = 1
        if self.screen:
            # root fills the screen; top-level children anchor to their own constraint edges
            rv = self.new_var()
            self.emit('local %s = Instance.new("Frame")' % rv)
            self.emit("%s.Name = %s" % (rv, lua_str(name)))
            self.emit("%s.Size = UDim2.fromScale(1, 1)" % rv)
            self.emit("%s.BackgroundTransparency = 1" % rv)
            self.emit('%s:SetAttribute("FigmaId", %s)' % (rv, lua_str(str(root.get("id", "")))))
            self.emit("root = %s" % rv)
            if self.visible_paints(root.get("fills")):
                self.warn(name, "screen frame background ignored (put full-screen art in a ScreenInsets.None gui)",
                          "screen background")
            kids = root.get("children") or []
            for i, child in enumerate(kids):
                self.convert_node(child, rv, (x, y, w, h), None, i, len(kids), name, False, True)
        else:
            # panel: centred in its parent at its design size; the Fit UIScale does the rest
            centred = dict(root)
            centred["constraints"] = {"horizontal": "CENTER", "vertical": "CENTER"}
            ref_w, ref_h = self.reference
            fake_parent = (x + w / 2.0 - ref_w / 2.0, y + h / 2.0 - ref_h / 2.0, ref_w, ref_h)
            self.convert_node(centred, None, fake_parent, None, 0, 1, "", False, True)
        return name, w, h

    def module(self, root, source_label):
        name, w, h = self.convert(root)
        ref_w, ref_h = self.reference
        floor = round(MIN_DRAWN_TEXT / self.min_text, 3) if self.min_text else 0.5
        out = []
        a = out.append
        a("--!strict")
        a("-- Generated by skills/lihfolk-figma/tools/figma_to_roblox.py from %s." % source_label)
        a("-- Figma frame: %s (%s), %s x %s design px at a %d x %d reference." % (name, root.get("id", "?"), num(w), num(h), ref_w, ref_h))
        a("-- Sizes are Offset at the reference resolution; the Fit UIScale scales them per device.")
        a("-- Regenerate instead of hand-editing layout; put behaviour (states, tweens, data) in a controller.")
        a('-- Every Image = "" line is a REPLACE_ME: upload the PNG named next to it (see the asset manifest).')
        a("")
        a("local Builder = {}")
        a("")
        a("Builder.REFERENCE = Vector2.new(%d, %d)" % (ref_w, ref_h))
        a("Builder.DESIGN_SIZE = Vector2.new(%s, %s)" % (num(w), num(h)))
        a("Builder.SCREEN = %s" % ("true" if self.screen else "false"))
        a("-- Smallest authored text is %s px, so a scale of %s keeps it at 12 px drawn." %
          (num(self.min_text or 0), num(floor)))
        a("Builder.TEXT_FLOOR = %s" % num(floor))
        a("")
        a("export type Refs = { [string]: GuiObject }")
        a("")
        a("-- Builds the tree, parents it to `parent` last, and returns the root plus named objects")
        a("-- (the root, every btn_ and scroll_ node, and in screen mode each top-level child).")
        a("function Builder.build(parent: Instance?): (GuiObject, Refs)")
        a("\tlocal refs: Refs = {}")
        a("\tlocal root: GuiObject")
        out.extend(self.lines)
        a("\troot.Parent = parent")
        a("\treturn root, refs")
        a("end")
        a("")
        a(FIT_HELPER)
        a("return Builder")
        a("")
        return "\n".join(out)


FIT_HELPER = '''export type FitOptions = {
	minScale: number?, -- default TEXT_FLOOR (smallest text stays 12 px drawn)
	maxScale: number?, -- default 1.4 (large monitors and TVs stop growing)
	margin: number?, -- px kept clear to the safe-area edge in panel mode (default 16)
}

-- Drives every UIScale named "Fit" under `root` from the size of the root's parent, which is
-- the ScreenGui's safe area when that gui uses ScreenInsets.CoreUISafeInsets. Returns a disconnect.
-- scale = clamp(min(area / REFERENCE), minScale, maxScale); a panel never grows past what fits.
function Builder.bindFit(root: GuiObject, options: FitOptions?): () -> ()
	local opts: FitOptions = options or {}
	local minScale = opts.minScale or Builder.TEXT_FLOOR
	local maxScale = opts.maxScale or 1.4
	local margin = opts.margin or 16
	local scales: { UIScale } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "Fit" then
			table.insert(scales, d)
		end
	end
	local own = root:FindFirstChild("Fit")
	if own and own:IsA("UIScale") then
		table.insert(scales, own)
	end
	local area = root.Parent
	if not (area and area:IsA("GuiBase2d")) then
		warn("bindFit: parent the root to a ScreenGui or Frame first")
		return function() end
	end
	local function update()
		local size = area.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local s = math.min(size.X / Builder.REFERENCE.X, size.Y / Builder.REFERENCE.Y)
		s = math.clamp(s, math.min(minScale, maxScale), maxScale)
		if not Builder.SCREEN then
			local fit = math.min((size.X - 2 * margin) / Builder.DESIGN_SIZE.X, (size.Y - 2 * margin) / Builder.DESIGN_SIZE.Y)
			if s > fit then
				s = math.max(fit, 0.05) -- fitting wins over the text floor: use a phone layout or a scrolling body
			end
		end
		for _, scale in scales do
			scale.Scale = s
		end
	end
	update()
	local connection = area:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	return function()
		connection:Disconnect()
	end
end
'''


# ----------------------------------------------------------------------------------------- report

def report_text(conv, root, label):
    lines = ["# Figma to Roblox report: %s" % clean_name(root.get("name")), "",
             "Source: %s. Reference %dx%d." % (label, conv.reference[0], conv.reference[1]), "",
             "## Node types", ""]
    for t, n in sorted(conv.type_counts.items()):
        lines.append("- %s: %d" % (t, n))
    lines += ["", "## Needs attention (feature: count)", ""]
    if conv.unsupported:
        for f, n in sorted(conv.unsupported.items(), key=lambda kv: (-kv[1], kv[0])):
            lines.append("- %s: %d" % (f, n))
    else:
        lines.append("- none")
    lines += ["", "## Images to export (%d)" % len(conv.manifest), ""]
    for m in conv.manifest:
        lines.append("- %s (%s): %dx%d px at %sx" % (m["file"], m["kind"], m["pixelSize"][0], m["pixelSize"][1], num(m["exportScale"])))
    lines += ["", "## Warnings", ""] + (["- " + w for w in conv.warnings] or ["- none"])
    if conv.min_text:
        lines += ["", "Smallest text %s px: keep the device scale >= %s for 12 px drawn text." %
                  (num(conv.min_text), num(round(MIN_DRAWN_TEXT / conv.min_text, 3)))]
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description="Figma REST node JSON -> Roblox Luau GUI builder")
    ap.add_argument("input")
    ap.add_argument("--node", help="frame id (12:34) or frame name")
    ap.add_argument("-o", "--output", help="Luau ModuleScript to write")
    ap.add_argument("--reference", default="1920x1080")
    ap.add_argument("--manifest", help="asset manifest JSON to write")
    ap.add_argument("--report", action="store_true", help="print the unsupported-feature report")
    ap.add_argument("--screen", action="store_true")
    ap.add_argument("--per-corner", action="store_true")
    ap.add_argument("--rotation-units", choices=("rad", "deg"), default="rad")
    args = ap.parse_args(argv)

    m = re.match(r"^(\d+)\s*[xX]\s*(\d+)$", args.reference)
    if not m:
        raise SystemExit("error: --reference must look like 1920x1080")
    reference = (int(m.group(1)), int(m.group(2)))
    with open(args.input, encoding="utf-8") as f:
        data = json.load(f)
    root = load_root(data, args.node)
    label = "%s (node %s)" % (args.input.replace("\\", "/").split("/")[-1], root.get("id", "?"))
    conv = Converter(reference, args.screen, args.per_corner, args.rotation_units)
    text = conv.module(root, label)
    if args.output:
        with open(args.output, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("wrote %s (%d lines, %d images, %d warnings)" % (args.output, text.count("\n"), len(conv.manifest), len(conv.warnings)))
    if args.manifest:
        with open(args.manifest, "w", encoding="utf-8", newline="\n") as f:
            json.dump({"frame": root.get("name"), "frameId": root.get("id"), "reference": list(reference),
                       "maxTexture": MAX_TEXTURE,
                       "exportHint": "GET https://api.figma.com/v1/images/:key?ids=<id>&format=png&scale=<exportScale> "
                                     "with your own X-Figma-Token from $FIGMA_TOKEN",
                       "images": conv.manifest}, f, indent=2)
            f.write("\n")
        print("wrote %s" % args.manifest)
    if args.report or not (args.output or args.manifest):
        sys.stdout.write(report_text(conv, root, label))
    elif conv.warnings:
        print("%d warnings (run with --report for the list)" % len(conv.warnings))
    return 0


if __name__ == "__main__":
    sys.exit(main())
