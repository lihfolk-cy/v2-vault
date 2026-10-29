"""Grow the LihFolk Vault V2 graph with links, atlas nodes and tags that are generated from the notes themselves.

Usage (stdlib only, deterministic; running it twice changes nothing):
    python "LihFolk Vault V2/_tools/link_builder.py"                # all four steps
    python "LihFolk Vault V2/_tools/link_builder.py" --check        # exit 1 if anything would change
    python "LihFolk Vault V2/_tools/link_builder.py" --no-inbound   # skip step 4 (first-mention links)
    python "LihFolk Vault V2/_tools/link_builder.py" --show "DataStore Fundamentals"   # print one note's Related picks
    python "LihFolk Vault V2/_tools/link_builder.py" -v             # list changed files
Then run build_index.py so atlas notes get TL;DRs and land in INDEX/ROUTER.

1. Related notes. Every prose note (one that build_index gives a TL;DR) ends with a block between
   <!-- related:start --> and <!-- related:end -->: `## Related` and one line of 6-10 [[links]] chosen by TF-IDF
   cosine over title, tags, headings, TL;DR and body, plus shared tags and shared outgoing links. Links already
   in the note are never repeated. Folder "galaxies": up to 8 picks come from the note's own section, and at most
   2 cross-section picks are added, only when they are about as strong as the best in-section match.
2. API and concept atlas. One note per Roblox class, service, enum, member, data type or core concept that 3+
   notes mention, in `57 API and Concept Atlas/`. Every sentence in an atlas note is copied from a vault note and
   cites it (Roblox docs / Measured labels come from the source). Terms without a defining sentence and at
   least 2 key facts are skipped. "Mentioned in" links the 25 most relevant notes (by section); the rest are
   listed as plain text so broad terms do not glue every section together. Atlas notes carry
   <!-- atlas:generated --> and are rewritten or deleted only by this tool (their TL;DR block is kept).
3. Tags. Existing tags are kept; `type/`, `area/`, `level/` and `api/` tags are added up to 12 tags per note.
   A note that already has a `level/` or `type/` tag keeps it (manual override).
4. First-mention links. The first plain-prose mention of an atlas term (or of a concept that already has its
   own note, such as Server Authority) becomes a [[link]]: never inside code, headings, links, URLs, comments
   or generated blocks; at most 12 per note; terms spread over more than 6 sections are not auto-linked.
   This edits note text outside markers, so it is idempotent but not reversible by re-running; --no-inbound
   skips it.
"""
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

TOOLS = os.path.dirname(os.path.abspath(__file__))
KB = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import build_index as bi  # noqa: E402  (reuses TLDR_RE, insert_tldr and the prose-note rules)

ATLAS = "57 API and Concept Atlas"
HUB = "API and Concept Atlas Start Here"
GEN = "<!-- atlas:generated -->"
RS, RE_ = "<!-- related:start -->", "<!-- related:end -->"
RELATED_RE = re.compile(r"\n*" + re.escape(RS) + r".*?" + re.escape(RE_) + r"\n?", re.S)
SKIP_ROOT = {"INDEX.md", "INDEX_SLIM.md", "ROUTER.md", "SYMPTOMS.md", "LICENSE.md", "Untitled.md"}
NS_TAG = re.compile(r"^(area|level|type|api)/")
MAX_TAGS, MAX_INBOUND, MAX_SECTIONS_FOR_INBOUND, MENTION_LINKS = 12, 12, 6, 25
SAME_MAX, CROSS_MAX, MIN_LINKS = 8, 2, 6

# ---------------------------------------------------------------- term rules
# Single-word class names are counted only inside code (they are also English words); these are excluded anyway.
CLASS_EXCLUDE = {"Studio", "Status", "Path", "Object", "Fire", "Light", "Message", "Plane", "Snap", "Rotate",
                 "Style", "Controller", "Selection", "Chat", "Torque", "PlayerData", "Packages", "Constraint",
                 "Hint", "Flag", "Glue", "Hat", "Sky", "Pages", "Hole", "Platform", "Configuration", "Translator",
                 "Stats", "Wire", "Dialog", "Mouse", "PlayerScripts", "GeneratedFolder", "ConfigSnapshot", "Handles", "WorldRoot", "LayerCollector",
                 "GuiBase2d", "JointInstance", "PoseBase", "BaseWrap", "LuaSourceContainer", "Snap"}
# single-word classes that are distinctive enough to count and link in prose
PROSE_SINGLE = {"Humanoid", "Animator", "Workspace", "Terrain", "Beam", "Trail", "Highlight", "Atmosphere"}
MEMBER_SINGLE = {"Heartbeat", "Touched", "Raycast", "Emit", "Kick", "Destroying", "Triggered", "Activated"}
MEMBER_EXCLUDE = {"PlayerData", "Profile", "Attack", "Idle", "Running", "Data", "Type", "Level", "Open", "Left",
                  "Right", "Root", "Head", "Start", "Step", "Move", "Speed", "Weight", "Priority", "Source", "Call",
                  "Origin", "Length", "Transform", "Color", "Position", "Size", "Name", "Enabled", "Value", "Text",
                  "Visible", "Scale", "Parent", "Rotation", "Target", "Time", "Phase", "Order", "Asset", "Title",
                  "Version", "Owner", "Track", "Load", "Sink", "Signal", "Error", "Next", "Angle", "Ended",
                  "Stopped", "Changed", "Release", "Cancel", "Clear", "Loop", "Offset", "Rate", "Undo", "Select",
                  "Refresh", "Jump", "Neck", "Waist", "Health", "Character", "Ragdoll", "Disabled", "Active",
                  "Brightness", "Saturation", "Ambient", "Volume", "Anchored", "PlayerGui", "UserId", "JobId",
                  "FinishRecording", "TryBeginRecording", "GetValue", "Swimming", "Jumping", "GettingUp",
                  "FallingDown", "PlatformStanding", "Seated", "RightShoulder", "Packages", "GetCurrentPage"}
TYPE_EXCLUDE = {"Axes", "Faces", "Content", "Font", "Enum", "Enums", "Instance", "Random", "Ray", "Region3int16",
                "Vector3int16", "Vector2int16", "DateTime", "Path2DControlPoint", "SharedTable", "Secret"}

# (title, regex, case_sensitive). Concepts are matched in prose only. A title that is already a note's title
# (for example Server Authority in 52 Core Concepts) gets no atlas note: first mentions link to that note instead.
C = []


def concept(title, rx=None, cs=False):
    C.append((title, rx or r"\b" + re.escape(title.lower()) + r"s?\b", cs))


for t, rx in [
    ("Server Authority", r"\bserver[- ]authorit(y|ative)\b"), ("Session Lock", r"\bsession[- ]lock(s|ing)?\b"),
    ("Network Ownership", r"\bnetwork ownership\b"), ("Instance Streaming", r"\binstance streaming\b"),
    ("Object Pooling", r"\bobject pool(s|ing)?\b"), ("Rate Limiting", r"\brate[- ]limit(s|ing|er|ed)?\b"),
    ("Idempotency", r"\bidempoten(t|cy)\b"), ("Replication", r"\breplication\b"),
    ("Client Prediction", r"\bclient[- ](side )?prediction\b"), ("Lag Compensation", r"\blag compensation\b"),
    ("Interpolation", r"\binterpolat(ion|e|es|ed|ing)\b"), ("Sanity Checks", r"\bsanity[- ]checks?\b"),
    ("Debounce", r"\bdebounc(e|es|ed|ing)\b"), ("Parallel Luau", r"\bparallel luau\b"),
    ("Strict Type Checking", r"\b(strict mode|type[- ]checking|type annotations?)\b"),
    ("Metatables", r"\bmetatables?\b"), ("Coroutines", r"\bcoroutines?\b"),
    ("Task Scheduler", r"\btask scheduler\b"), ("Memory Leaks", r"\bmemory leaks?\b"),
    ("Garbage Collection", r"\bgarbage[- ]collect(ion|or|ed)\b"), ("Race Conditions", r"\brace conditions?\b"),
    ("Fixed Timestep", r"\bfixed[- ]time ?step\b"), ("Entity Component System", r"\b(entity component systems?|ECS)\b"),
    ("State Machines", r"\b(finite )?state machines?\b"), ("Behaviour Trees", r"\bbehaviou?r trees?\b"),
    ("Pathfinding", r"\bpathfinding\b"), ("Spatial Queries", r"\bspatial quer(y|ies)\b"),
    ("Hitboxes", r"\bhitbox(es)?\b"), ("Level of Detail", r"\b(level of detail|LODs?)\b"),
    ("Texture Memory", r"\btexture memory\b"), ("Developer Console", r"\b(developer console|dev console)\b"),
    ("Autosave", r"\bauto-?sav(e|es|ed|ing)\b"), ("Exponential Backoff", r"\b(exponential )?backoff\b"),
    ("Leaderboards", r"\bleaderboards?\b"), ("Item Duplication", r"\b(dupes?|duping|duplication (glitch|exploit|bug)s?)\b"),
    ("Developer Products", r"\b(developer|dev) products?\b"), ("Game Passes", r"\bgame ?pass(es)?\b"),
    ("Premium Payouts", r"\bpremium payouts?\b"), ("Subscriptions", r"\bsubscriptions?\b"),
    ("Rewarded Video Ads", r"\brewarded video( ads?)?\b"), ("Paid Random Items", r"\b(paid random items?|loot ?box(es)?)\b"),
    ("Price Testing", r"\bprice test(s|ing)?\b"), ("Creator Rewards", r"\bcreator rewards\b"),
    ("Conversion Rate", r"\bconversion rates?\b"), ("Day-N Retention", r"\b(D1|D7|D30)( retention)?\b"),
    ("FTUE", r"\b(FTUE|first[- ]time user experience)\b"), ("Rebirth", r"\b(rebirths?|prestige)\b"),
    ("Gacha", r"\bgacha\b"), ("Drop Rates", r"\bdrop rates?\b"), ("Offline Earnings", r"\boffline (earnings|progress(ion)?)\b"),
    ("Daily Rewards", r"\bdaily rewards?\b"), ("Login Streaks", r"\b(login )?streaks?\b"),
    ("Battle Pass", r"\b(battle|season) pass(es)?\b"), ("Live Events", r"\b(live|limited[- ]time) events?\b"),
    ("Private Servers", r"\b(private|VIP|reserved) servers?\b"), ("Matchmaking", r"\bmatchmaking\b"),
    ("Lobby", r"\b(lobby|lobbies)\b"), ("Tycoon", r"\btycoons?\b"), ("Obby", r"\b(obby|obbies)\b"),
    ("Tower Defense", r"\btower defen[cs]e\b"), ("Roguelike", r"\brogue-?(like|lite)s?\b"),
    ("Juice", r"\b(juice|juicy)\b"), ("Screen Shake", r"\b(screen|camera) shake\b"),
    ("Coyote Time", r"\bcoyote time\b"), ("Telegraphing", r"\btelegraph(s|ed|ing)?\b"),
    ("Invincibility Frames", r"\b(i-frames|invincibility frames|iframes)\b"), ("Cooldowns", r"\bcooldowns?\b"),
    ("Damage Numbers", r"\bdamage numbers\b"), ("Knockback", r"\bknockback\b"), ("Combos", r"\bcombos?\b"),
    ("Stamina", r"\bstamina\b"), ("9-Slice Scaling", r"\b(9-slice|nine-slice|9-sliced)\b"),
    ("Dark Patterns", r"\bdark patterns?\b"), ("Gamepad Support", r"\bgamepads?\b"),
    ("Touch Controls", r"\b(touch controls?|mobile controls?|thumbsticks?)\b"), ("Haptics", r"\bhaptics?\b"),
    ("Localization", r"\blocali[sz]ation\b"), ("Colour Blindness", r"\bcolou?r[- ]?blind(ness)?\b"),
    ("Reduced Motion", r"\breduced motion\b"), ("Text Filtering", r"\b(text filtering|filter(ed|ing)? text)\b"),
    ("Post-Processing", r"\bpost[- ]processing\b"), ("Flipbooks", r"\bflipbooks?\b"),
    ("Sprite Sheets", r"\bsprite ?sheets?\b"), ("Impact Frames", r"\bimpact frames?\b"),
    ("Colour Grading", r"\bcolou?r grading\b"), ("Spatial Audio", r"\b(spatial audio|3D audio)\b"),
    ("Inverse Kinematics", r"\b(inverse kinematics|IK)\b"), ("Animation Priority", r"\banimation priorit(y|ies)\b"),
    ("Animation Blending", r"\banimation blending\b"), ("Root Motion", r"\broot motion\b"),
    ("Rest Pose", r"\b(rest|bind) poses?\b"), ("Procedural Animation", r"\bprocedural animations?\b"),
    ("Ragdolls", r"\bragdoll(s|ing|ed)?\b"), ("R15", r"\bR15\b"), ("R6", r"\bR6\b"),
    ("Retargeting", r"\bretarget(ing|ed)?\b"), ("FACS", r"\bFACS\b"), ("Squash and Stretch", r"\bsquash and stretch\b"),
    ("Follow-Through", r"\bfollow[- ]through\b"), ("Topology", r"\btopology\b"), ("Retopology", r"\bretopo(logy)?\b"),
    ("UV Unwrapping", r"\b(UV unwrap(ping)?|unwrap(ping)? UVs?|UV maps?)\b"), ("Normal Maps", r"\bnormal maps?\b"),
    ("Texture Baking", r"\b(bak(e|ed|ing) (the )?(normals?|textures?|maps?|AO|lighting)|texture baking)\b"),
    ("PBR", r"\bPBR\b"), ("Trim Sheets", r"\btrim ?sheets?\b"), ("Vertex Colours", r"\bvertex colou?rs?\b"),
    ("Edge Flow", r"\bedge flow\b"), ("Bevels", r"\bbevel(s|led|ed)?\b"), ("Weighted Normals", r"\bweighted normals?\b"),
    ("Decimation", r"\bdecimat(e|ion|ed)\b"), ("Voxels", r"\bvoxels?\b"), ("MagicaVoxel", r"\bMagicaVoxel\b"),
    ("Blockbench", r"\bBlockbench\b"), ("Substance Painter", r"\bSubstance( 3D)? Painter\b"), ("FBX", r"\bFBX\b"),
    ("glTF and GLB", r"\b(glTF|GLB)\b"), ("Silhouette", r"\bsilhouettes?\b"), ("Low Poly", r"\blow[- ]poly\b"),
    ("Kitbashing", r"\bkitbash(ing|ed)?\b"), ("Modular Kits", r"\bmodular (kits?|pieces)\b"),
    ("Greyboxing", r"\b(gr[ae]ybox(ing|ed)?|block-?outs?)\b"), ("Team Create", r"\bteam create\b"),
    ("Version Control", r"\bversion control\b"), ("Continuous Integration", r"\b(continuous integration|CI)\b"),
    ("Playtesting", r"\bplaytest(s|ing|ed|ers?)?\b"), ("Kill Switches", r"\bkill[- ]switch(es)?\b"),
    ("Soft Launch", r"\bsoft[- ]launch(es|ed|ing)?\b"), ("A/B Testing", r"\bA/B test(s|ing)?\b"),
    ("Funnels", r"\bfunnels?\b"), ("Maturity Labels", r"\b(maturity labels?|content maturity)\b"),
    ("Age Verification", r"\b(age verification|age checks?|age[- ]verified)\b"), ("Open Cloud", r"\bOpen Cloud\b"),
    ("Model Context Protocol", r"\b(MCP|Model Context Protocol)\b"), ("Roblox Assistant", r"\bRoblox Assistant\b"),
    ("Dot Product", r"\bdot products?\b"), ("Cross Product", r"\bcross products?\b"), ("Lerp", r"\blerp(s|ing|ed)?\b"),
    ("Slerp", r"\bslerp\b"), ("Quaternions", r"\bquaternions?\b"), ("Bezier Curves", r"\bb[eé]zier( curves?)?\b"),
    ("Perlin Noise", r"\b(perlin|simplex) noise\b"), ("Weighted Random", r"\bweighted (random|tables?|picks?|rolls?)\b"),
    ("Random Seeds", r"\b(random )?seed(s|ed)?\b"), ("Poisson Disk Sampling", r"\bpoisson[- ]dis[ck]\b"),
    ("Wave Function Collapse", r"\bwave function collapse\b"), ("Cellular Automata", r"\bcellular automat(a|on)\b"),
    ("Exploit Executors", r"\bexecutors?\b"), ("Speed Hacks", r"\bspeed ?hack(s|ing|ers)?\b"),
    ("Noclip", r"\bnoclip(ping)?\b"), ("Anti-Cheat", r"\banti-?cheat\b"), ("Honeypots", r"\bhoneypots?\b"),
    ("Obfuscation", r"\bobfuscat(ion|ed|e)\b"), ("Backdoors", r"\bbackdoors?\b"), ("Free Models", r"\bfree models?\b"),
    ("Discord", r"\bDiscord\b"), ("Talent Hub", r"\bTalent Hub\b"), ("DevForum", r"\bDevForum\b"),
    ("Thumbnails", r"\bthumbnails?\b"), ("Sponsored Ads", r"\b(sponsored (ads?|experiences?)|Ads Manager)\b"),
    ("Discovery Algorithm", r"\b(discovery|recommendation) (algorithm|system|surfaces?)\b"),
    ("Pixel Art", r"\bpixel art\b"), ("Tilemaps", r"\btile ?maps?\b"), ("Parallax", r"\bparallax\b"),
    ("Sightlines", r"\bsight ?lines?\b"), ("Landmarks", r"\blandmarks?\b"), ("Chokepoints", r"\bchoke ?points?\b"),
    ("Wayfinding", r"\bwayfinding\b"), ("Spawn Points", r"\bspawn (points?|locations?)\b"),
    ("Quests", r"\bquests?\b"), ("Dialogue Systems", r"\bdialogue\b"), ("NPCs", r"\bNPCs?\b"),
    ("Cutscenes", r"\bcutscenes?\b"), ("Lore", r"\blore\b"), ("Layered Clothing", r"\blayered clothing\b"),
    ("UGC", r"\bUGC\b"), ("Dynamic Heads", r"\bdynamic heads?\b"), ("Live Ops", r"\blive[- ]?ops\b"),
    ("Rojo", r"\bRojo\b"), ("Wally", r"\bWally\b"), ("Selene", r"\bSelene\b"), ("StyLua", r"\bStyLua\b"),
    ("ProfileStore", r"\bProfileStore\b"), ("ProfileService", r"\bProfileService\b"), ("Knit", r"\bKnit\b"),
    ("React Luau", r"\b(React[- ]Luau|react-lua|Roact)\b"), ("Janitor and Trove", r"\b(Janitor|Trove|Maid)\b"),
    ("Promise Library", r"\bPromises?\b"), ("TestEZ", r"\bTestEZ\b"), ("Lune", r"\bLune\b"),
    ("Robux", r"\bRobux\b"), ("DevEx", r"\bDevEx\b"), ("MicroProfiler", r"\bMicroProfiler\b"),
    ("Blender", r"\bBlender\b"), ("Draw Calls", r"\bdraw calls?\b"), ("Frame Budget", r"\bframe budgets?\b"),
    ("Triangle Budget", r"\btriangle budgets?\b"), ("Safe Area", r"\bsafe areas?\b"), ("Core Loop", r"\bcore loops?\b"),
    ("Easing", r"\beasing\b"), ("Hit-Stop", r"\bhit-?stop\b"), ("Anticipation", r"\banticipation\b"),
    ("Input Buffering", r"\binput buffer(ing|s)?\b"), ("Feature Flags", r"\bfeature flags?\b"),
    ("Pity Timer", r"\bpity( timers?| systems?)?\b"), ("Faucets and Sinks", r"\b(faucets? and sinks?|currency sinks?)\b"),
    ("Event Bus", r"\bevent bus(es)?\b"), ("Skinning Weights", r"\b(skin(ning)? weights?|weight paint(ing)?)\b"),
    ("Texel Density", r"\btexel density\b"), ("Expected Value", r"\bexpected value\b"),
    ("Input Action System", r"\binput action system\b"), ("Audio API", r"\b(new )?audio API\b"),
]:
    concept(t, rx, any(ch.isupper() for ch in rx.replace(r"\b", "")) and t in {
        "R15", "R6", "FACS", "PBR", "FBX", "glTF and GLB", "UGC", "Open Cloud", "Roblox Assistant", "MagicaVoxel",
        "Blockbench", "Substance Painter", "Discord", "Talent Hub", "DevForum", "Rojo", "Wally", "Selene", "StyLua",
        "ProfileStore", "ProfileService", "Knit", "Fusion", "React Luau", "Janitor and Trove", "Promise Library",
        "TestEZ", "Lune", "Robux", "DevEx", "MicroProfiler", "Blender", "Day-N Retention", "FTUE",
        "Model Context Protocol", "Continuous Integration", "Entity Component System", "Level of Detail",
        "Inverse Kinematics", "NPCs", "A/B Testing"})

# ---------------------------------------------------------------- areas, levels, types
AREA_BY_SECTION = {
    "01": "studio", "02": "scripting", "03": "networking", "04": "data", "05": "ui", "06": "world", "07": "vfx",
    "08": "animation", "09": "gameplay", "10": "design", "11": "monetization", "12": "performance",
    "13": "production", "14": "modeling", "15": "ai", "16": "ai", "17": "pipelines", "18": "animation",
    "19": "art", "21": "ui", "22": "security", "23": "debugging", "24": "gameplay", "25": "physics",
    "26": "community", "27": "marketing", "28": "business", "29": "scripting", "31": "ai", "32": "design",
    "33": "world", "34": "procedural", "35": "scripting", "36": "narrative", "37": "avatars", "38": "liveops",
    "39": "studio", "40": "math", "41": "networking", "42": "accessibility", "43": "gameplay", "44": "materials",
    "45": "modeling", "47": "game-feel", "48": "economy", "49": "platform", "50": "production", "51": "2d",
    "53": "modeling", "54": "modeling", "55": "modeling"}
AREA_KEYWORDS = [  # (regex on non-namespaced tags + title, area)
    (r"datastore|persistence|saving|profile|\bdata\b", "data"), (r"\bui\b|gui|hud|menu|layout|button", "ui"),
    (r"vfx|particle|beam|trail|slash", "vfx"), (r"lighting|bloom|atmosphere", "lighting"),
    (r"audio|sound|music", "audio"), (r"animat|rig\b|rigging|keyframe", "animation"),
    (r"security|exploit|anti-?cheat|cheat", "security"), (r"performance|optimi|memory|profil", "performance"),
    (r"monetization|robux|purchase|game-?pass|product", "monetization"), (r"physics|vehicle|constraint", "physics"),
    (r"network|remote|replication|multiplayer", "networking"), (r"combat|weapon|hitbox|enemy|ability", "gameplay"),
    (r"blender|modell?ing|mesh|voxel|uv\b|texture", "modeling"), (r"\bai\b|mcp|agent|llm|prompt", "ai"),
    (r"economy|currency|inflation", "economy"), (r"luau|scripting|module|types?\b|strict", "scripting"),
    (r"debug", "debugging"), (r"design|retention|loop|progression", "design"), (r"live-?ops|event", "liveops"),
    (r"marketing|thumbnail|icon|growth", "marketing"), (r"math|vector|cframe|curve", "math"),
    (r"procedural|generation|noise", "procedural"), (r"accessib", "accessibility"), (r"studio|plugin|tooling", "studio"),
    (r"level design|world|terrain|map\b", "world"), (r"avatar|ugc|clothing", "avatars"),
]
BEGINNER = re.compile(r"(?i)fundamentals|basics|beginner|intro|getting started|start here|what is|overview|"
                      r"first steps|glossary|101\b|your first")
ADVANCED = re.compile(r"(?i)advanced|deep dive|internals|parallel|buffers?\b|prediction|reconcil|lag compensation|"
                      r"metatable|\becs\b|entity component|deterministic|memory leak|bisect|race condition|serializ|"
                      r"binary|quaternion|inverse kinematics|\bik\b|microprofiler|open cloud|lockstep")
CASE = re.compile(r"(?i)case stud|postmortem|post-mortem|teardown|lessons from|what .* got right")
REFERENCE = re.compile(r"(?i)reference|glossary|cheat ?sheet|limits\b|^links - |cookbook|quick ref|lookup|"
                       r"\bindex\b|\bapi\b|catalog|palette|sheet\b|snippets?")
GENERIC_API = {"GetService", "WaitForChild", "FindFirstChild", "Destroy", "Clone", "GetChildren", "GetDescendants",
               "Disconnect", "Instance", "Players", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
               "ModuleScript", "LocalScript", "Workspace", "RunService", "BasePart", "CFrame", "Vector3", "Color3",
               "GetAttribute", "SetAttribute", "StarterPlayer", "StarterPlayerScripts", "StarterGui", "PlayerGui",
               "DataModel", "FindFirstChildOfClass", "MeshPart", "UDim2", "Vector2", "TweenInfo"}


# ---------------------------------------------------------------- io helpers
def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write(path, text, changed, check):
    if os.path.exists(path) and read(path) == text:
        return
    changed.append(os.path.relpath(path, KB).replace(os.sep, "/"))
    if check:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def collect():
    notes = []
    for root, dirs, files in os.walk(KB):
        dirs[:] = sorted(d for d in dirs if not d.startswith((".", "_")))
        rel = os.path.relpath(root, KB)
        for f in sorted(files):
            if not f.endswith(".md") or (rel == "." and f in SKIP_ROOT):
                continue
            p = os.path.join(root, f)
            notes.append({"title": f[:-3], "abs": p, "path": os.path.relpath(p, KB).replace(os.sep, "/"),
                          "section": "root" if rel == "." else rel.split(os.sep)[0],
                          "folder": rel.replace(os.sep, "/"), "text": read(p)})
    return notes


# ---------------------------------------------------------------- masking and cleaning
GEN_BLOCK = re.compile(r"<!-- (tldr|auto-links|related):start -->.*?<!-- \1:end -->", re.S)
PROTECT = [re.compile(r"\A---\n.*?\n---\n", re.S), GEN_BLOCK, re.compile(r"^(```|~~~).*?^\1[^\n]*$", re.S | re.M),
           re.compile(r"`[^`\n]+`"), re.compile(r"!?\[\[[^\]\n]*\]\]"), re.compile(r"\[[^\]\n]*\]\([^)\n]*\)"),
           re.compile(r"https?://\S+"), re.compile(r"<!--.*?-->", re.S), re.compile(r"<[^>\n]+>"),
           re.compile(r"^#{1,6} .*$", re.M)]


def masked(text):
    """Same-length copy where everything that must not be linked or mined as prose is blanked out."""
    chars = list(text)
    for rx in PROTECT:
        for m in rx.finditer(text):
            for i in range(m.start(), m.end()):
                if chars[i] != "\n":
                    chars[i] = " "
    return "".join(chars)


def unlink(s):
    s = re.sub(r"!\[\[[^\]]*\]\]", "", s)
    s = re.sub(r"\[\[([^\]|\\]+)\\?\|([^\]]+)\]\]", r"\2", s)
    return re.sub(r"\[\[([^\]#]+)(#[^\]]*)?\]\]", r"\1", s)


def clean(text):
    """Note text without frontmatter and generated blocks, wikilinks reduced to their display text."""
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    return unlink(GEN_BLOCK.sub("", text))


def code_text(c):
    return " ".join(re.findall(r"```.*?```|`[^`\n]+`", c, re.S))


def prose_text(c):
    return masked(c)


def get_tags(text):
    fm = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    m = re.search(r"^tags:\s*\[(.*?)\]", fm.group(1), re.M) if fm else None
    return [t.strip().strip("'\"") for t in m.group(1).split(",") if t.strip()] if m else []


def tldr_bullets(text):
    m = re.search(re.escape(bi.START) + r"(.*?)" + re.escape(bi.END), text, re.S)
    return [l[4:].strip() for l in m.group(1).split("\n") if l.startswith("> - ")] if m else []


def headings(c):
    return re.findall(r"^#{1,4} +(.+)$", re.sub(r"```.*?```", "", c, flags=re.S), re.M)


def is_prose(n):
    return not (n["section"] in ("root", ATLAS) or n["section"] in bi.NO_TLDR_SECTIONS
                or bi.NO_TLDR_TITLE.search(n["title"]))


# ---------------------------------------------------------------- tokens for similarity
STOP = set("""a an and are as at be but by can do does for from get got how i if in into is it its make my me of on
or so that the then there this to too up use using want way what when where which while why will with without you
your we our not no just also should would could any some all one two more most than them they their see each only
very every other same these those has have had was were been here note notes""".split())


def stem(w):
    for suf, rep in (("ies", "y"), ("ing", ""), ("ed", ""), ("es", ""), ("s", "")):
        if len(w) > len(suf) + 3 and w.endswith(suf):
            return w[: -len(suf)] + rep
    return w


def toks(s):
    out = []
    for word in re.findall(r"[A-Za-z][A-Za-z0-9]*", s):
        low = word.lower()
        if low in STOP or len(low) < 3:
            continue
        out.append(stem(low))
        parts = re.findall(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+", word)
        if len(parts) > 1:
            out += [stem(p.lower()) for p in parts if p.lower() not in STOP and len(p) > 2]
    return out


# ---------------------------------------------------------------- analysis
def analyse(notes):
    for n in notes:
        n["clean"] = clean(n["text"])
        n["code"] = code_text(n["clean"])
        n["prose"] = prose_text(n["clean"])
        n["tags"] = get_tags(n["text"])
        n["base_tags"] = [t for t in n["tags"] if not NS_TAG.match(t)]
        n["tldr"] = tldr_bullets(n["text"])
        n["heads"] = headings(n["clean"])
        n["ids_all"] = Counter(re.findall(r"(?<![\w.])([A-Za-z_][A-Za-z0-9_]*)", n["clean"]))
        n["ids_code"] = Counter(re.findall(r"(?<![\w.])([A-Za-z_][A-Za-z0-9_]*)", n["code"]))
        n["enum_ids"] = Counter(re.findall(r"\bEnum\.([A-Za-z]+)", n["clean"]))
        n["prose_low"] = n["prose"].lower()


def caps2(w):
    return len(re.findall(r"[A-Z]", w)) >= 2 or bool(re.search(r"\d", w))


def api_terms(api):
    terms = {}
    members = defaultdict(set)
    for c, v in api["classes"].items():
        for m, dep in v["members"].items():
            members[m].add(c)
    for c, v in api["classes"].items():
        if len(c) >= 4 and c not in CLASS_EXCLUDE:
            kind = "service" if v.get("service") else "class"
            terms[c] = {"kind": kind, "ctx": "any" if caps2(c) or c in PROSE_SINGLE else "code",
                        "info": v, "prose_link": caps2(c) or c in PROSE_SINGLE}
    for e, vals in api["enums"].items():
        if e not in terms:
            terms[e] = {"kind": "enum", "ctx": "enum", "info": vals, "prose_link": False}
    for t in api.get("types", {}):
        if t not in terms and t not in TYPE_EXCLUDE and len(t) >= 4:
            terms[t] = {"kind": "datatype", "ctx": "any" if caps2(t) else "code", "info": None,
                        "prose_link": caps2(t)}
    for m, owners in members.items():
        if m in terms or m in MEMBER_EXCLUDE or not m[:1].isupper() or len(m) < 4:
            continue
        if not caps2(m) and m not in MEMBER_SINGLE:
            continue
        live = sorted(o for o in owners if not api["classes"][o].get("deprecated"))
        terms[m] = {"kind": "member", "ctx": "any" if caps2(m) else "code", "owners": live or sorted(owners),
                    "deprecated": all(api["classes"][o]["members"][m] for o in owners), "info": None,
                    "prose_link": caps2(m) and not m[-1].isdigit()}  # Part1 in prose is often an instance name
    return terms


def term_hits(name, spec, notes, sources):
    out = {}
    if spec.get("concept"):
        rx = spec["rx"]
        for n in sources:
            k = len(rx.findall(n["prose"] if spec["cs"] else n["prose_low"]))
            if k:
                out[n["title"]] = k
        return out
    for n in sources:
        if spec["ctx"] == "enum":
            k = n["enum_ids"].get(name, 0)
        elif spec["ctx"] == "code":
            k = n["ids_code"].get(name, 0)
        else:
            k = n["ids_all"].get(name, 0)
        if k:
            out[n["title"]] = k
    return out


SENT_SPLIT = re.compile(r"(?<=[.!?])\s+(?=[A-Z`\"(\[*])")
VERBS = (r"(is|are|was|returns?|fires?|lets?|gives?|holds?|stores?|runs?|controls?|makes?|does|keeps?|sends?|"
         r"creates?|plays?|moves?|reads?|writes?|means?|decides?|replicates?|defines?|tracks?|draws?|renders?|"
         r"handles?|exposes?|provides?|turns?|adds?|applies?|caps?|limits?|can|only|never|always|has|have|"
         r"yields?|blends?|drives?|replaces?|works?|needs?|sets?|uses?|takes?|loads?|saves?|grants?|calls?|"
         r"shows?|changes?|scales?|checks?)")
PRONOUN = re.compile(r"^(It|This|That|These|Those|They|But|So|And|Or|Then|Also|Here|There|Both|Yes|No|Its|"
                     r"Their|He|She|We|You|If so|Same)\b")


def sentences(n):
    """[(sentence, heading, is_item)] from a note's prose, tables reduced to cells (glossary rows -> Term: meaning)."""
    if "sents" in n:
        return n["sents"]
    out, head, fence = [], "", False
    glossary = n["title"].endswith("Glossary")
    for line in n["clean"].split("\n"):
        s = line.strip()
        if s.startswith(("```", "~~~")):
            fence = not fence
            continue
        if fence or not s:
            continue
        if re.match(r"^#{1,6} ", s):
            head = s.lstrip("# ")
            continue
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if glossary and len(cells) >= 2 and cells[0].startswith("**"):
                out.append((cells[0].strip("*") + ": " + cells[1].rstrip(".") + ".", head, "glossary"))
            continue
        item = bool(re.match(r"^(?:[-*]|\d+[.)])\s+", s))
        s = re.sub(r"^(?:>\s*)?(?:[-*]|\d+[.)])\s+(?:\[[ xX]\]\s+)?", "", s).lstrip("> ").strip()
        for sent in SENT_SPLIT.split(s):
            if 25 <= len(sent) <= 400:
                out.append((sent, head, "item" if item else "para"))
    n["sents"] = out
    return out


def term_regex(name, spec):
    if spec.get("concept"):
        return re.compile(spec["rx"].pattern, 0 if spec["cs"] else re.I)
    if spec["kind"] == "enum":
        return re.compile(r"\bEnum\." + re.escape(name) + r"\b")
    return re.compile(r"(?<![\w.])" + re.escape(name) + r"(?![\w])")


def label_for(sent, head):
    if re.search(r"(?i)roblox docs|\bdocs\b", sent) or re.search(r"(?i)\bmeasured\b", sent):
        return ""
    if re.search(r"(?i)roblox docs|\(docs", head):
        return "Roblox docs"
    if re.search(r"(?i)\bmeasured\b", head):
        return "Measured"
    return ""


def tidy(s):
    s = s.replace("**", "").strip()
    return s if s.endswith((".", "!", "?", ")", "`")) else s + "."


def define(name, spec, ranked, by_title):
    rx = term_regex(name, spec)
    cands = []
    pool = ranked[:40] + [t for t in ranked[40:] if t.endswith("Glossary")]  # curated glossary rows always count
    for rank, t in enumerate(pool):
        n = by_title[t]
        for sent, head, kind in sentences(n):
            m = rx.search(sent)
            if not m or "http" in sent:
                continue
            sc = 0.0
            pos = m.start() - (2 if sent[:2] == "**" else 0)
            sc += 3 if pos <= 2 else -2
            after = sent[m.end():].lstrip("`* ")
            if pos <= 2 and re.match(r"(\([^)]*\)\s*)?" + VERBS + r"\b", after):
                sc += 6
            if pos <= 2 and re.match(r"(\([^)]*\)\s*)?(is|are) (a|an|the|how|what|one|roblox)\b", after, re.I):
                sc += 5
            if sent.count('"') % 2 or sent.count("`") % 2 or sent.count("(") != sent.count(")"):
                sc -= 6
            if re.search(r"\b(is|are) (a|an|the|one|how|what|where|when)\b", sent):
                sc += 2
            if kind == "glossary":
                sc += 8
            if name.lower() in t.lower():
                sc += 3
            sc += 2 - min(rank, 20) / 10
            L = len(sent)
            sc -= 0 if 50 <= L <= 260 else 5
            if PRONOUN.match(sent):
                sc -= 4
            if "?" in sent or sent.rstrip().endswith(":"):
                sc -= 6
            if re.search(r"(?i)^avoid|\bavoid:|->|→|\|", sent):
                sc -= 3
            if kind == "item":
                sc -= 1
            cands.append((sc, rank, sent, head, t))
    cands.sort(key=lambda c: (-c[0], c[1], c[2]))
    out, used = [], set()
    for sc, _, sent, head, t in cands:
        if sc < (6 if not out else 10) or t in used:
            continue
        lab = label_for(sent, head)
        out.append(f"{tidy(sent)} (from [[{t}]]{'; ' + lab if lab else ''})")
        used.add(t)
        if len(out) == 2:
            break
    return out


def key_facts(name, spec, ranked, by_title):
    rx = term_regex(name, spec)
    facts, per = [], Counter()
    for t in ranked:
        for b in by_title[t]["tldr"]:
            if rx.search(b) and per[t] < 2 and "http" not in b and not any(b in f for f in facts):
                facts.append(f"{tidy(b)} ([[{t}]])")
                per[t] += 1
        if len(facts) >= 5:
            return facts
    if len(facts) < 3:  # fill from list items in the most relevant notes
        for t in ranked[:30]:
            for sent, head, kind in sentences(by_title[t]):
                if kind != "item" or not rx.search(sent) or per[t] >= 1 or PRONOUN.match(sent) or "http" in sent:
                    continue
                if 40 <= len(sent) <= 220 and "?" not in sent and not sent.endswith(":"):
                    facts.append(f"{tidy(sent)} ([[{t}]])")
                    per[t] += 1
            if len(facts) >= 4:
                break
    return facts[:5]


def area_of(n):
    sec = n["section"][:2]
    areas = []
    if sec in AREA_BY_SECTION:
        areas.append(AREA_BY_SECTION[sec])
    if "audio" in " ".join(n["base_tags"]).lower() and sec == "07":
        areas.append("audio")
    hay = (" ".join(n["base_tags"]) + " " + n["title"]).lower()
    for rx, a in AREA_KEYWORDS:
        if a not in areas and re.search(rx, hay):
            areas.append(a)
    return areas[:2]


def build_atlas(notes, api):
    by_title = {n["title"]: n for n in notes}
    lower_titles = {n["title"].lower(): n["title"] for n in notes if n["section"] != ATLAS}
    sources = [n for n in notes if n["section"] != ATLAS]
    specs = api_terms(api)
    for title, rx, cs in C:
        specs[title] = {"concept": True, "kind": "concept", "rx": re.compile(rx if cs else rx.lower(), 0),
                        "cs": cs, "prose_link": True}
    atlas, link_targets = {}, {}
    for name, spec in specs.items():
        hits = term_hits(name, spec, notes, sources)
        if len(hits) < 3:
            continue
        rank = {t: k + (10 if name.lower() in t.lower() else 0)
                + (4 if any(name.lower() in h.lower() for h in by_title[t]["heads"]) else 0)
                + (2 if is_prose(by_title[t]) else 0) for t, k in hits.items()}
        ranked = sorted(hits, key=lambda t: (-rank[t], t))
        secs = {by_title[t]["section"] for t in hits}
        if name.lower() in lower_titles:  # a real note already owns this title: link to it, no atlas note
            if spec.get("prose_link") and len(secs) <= MAX_SECTIONS_FOR_INBOUND:
                link_targets[name] = (lower_titles[name.lower()], spec)
            continue
        defs = define(name, spec, ranked, by_title)
        facts = key_facts(name, spec, ranked, by_title)
        if defs:  # a fact that repeats the definition adds nothing (and would leave the TL;DR short)
            first = defs[0].rsplit(" (from [[", 1)[0]
            facts = [f for f in facts if f.rsplit(" ([[", 1)[0] != first]
        if not defs or len(facts) < 2:
            continue
        atlas[name] = {"spec": spec, "hits": hits, "ranked": ranked, "defs": defs, "facts": facts, "secs": secs}
    # keep the vault's best-backed 500: concepts and types first, then by number of notes
    if len(atlas) > 500:
        order = sorted(atlas, key=lambda k: (atlas[k]["spec"]["kind"] == "member", -len(atlas[k]["hits"]), k))
        atlas = {k: atlas[k] for k in order[:500]}
    for name, a in atlas.items():
        if a["spec"].get("prose_link") and len(a["secs"]) <= MAX_SECTIONS_FOR_INBOUND:
            link_targets[name] = (name, a["spec"])
    return atlas, link_targets


def atlas_note(name, a, by_title, api_date):
    spec, kind = a["spec"], a["spec"]["kind"]
    sec_count = Counter(by_title[t]["section"] for t in a["hits"])
    areas = []
    for sec, _ in sec_count.most_common():
        ar = AREA_BY_SECTION.get(sec[:2])
        if ar and ar not in areas:
            areas.append(ar)
        if len(areas) == 2:
            break
    tags = ["atlas", "concept" if kind == "concept" else "api", "type/atlas"] + ["area/" + x for x in areas]
    if kind != "concept":
        tags.append("api/" + name)
    lines = ["---", f"tags: [{', '.join(tags)}]", "---", f"# {name}", "", "## In short", ""]
    lines += [a["defs"][0], ""]
    if len(a["defs"]) > 1:
        lines += [a["defs"][1], ""]
    if kind != "concept":
        if kind == "member":
            own = spec["owners"]
            what = f"member of {', '.join('`' + o + '`' for o in own[:4])}" + (f" and {len(own) - 4} more" if len(own) > 4 else "")
            if spec.get("deprecated"):
                what += "; flagged deprecated"
        elif kind == "enum":
            what = f"enum `Enum.{name}`"
        elif kind == "datatype":
            what = "Luau data type"
        else:
            info = spec["info"]
            what = ("service" if kind == "service" else "class") + (f", inherits `{info['super']}`" if info.get("super") else "")
            if info.get("notcreatable") and kind != "service":
                what += ", not creatable with `Instance.new`"
            if info.get("deprecated"):
                what += "; flagged deprecated"
        lines += [f"API snapshot: {what} (`_tools/roblox_api.json`, docs build of {api_date}).", ""]
    lines += ["## Key facts", ""] + ["- " + f for f in a["facts"]] + [""]
    linked = a["ranked"][:MENTION_LINKS]
    rest = sorted(a["ranked"][MENTION_LINKS:])
    lines += ["## Mentioned in", "",
              f"{len(a['hits'])} notes in {len(sec_count)} sections. The {len(linked)} most relevant are linked:", ""]
    groups = defaultdict(list)
    for t in linked:
        groups[by_title[t]["section"]].append(t)
    for sec in sorted(groups):
        lines += [f"### {'Root notes' if sec == 'root' else sec}", " · ".join(f"[[{t}]]" for t in sorted(groups[sec])), ""]
    if rest:
        lines += ["Also mentioned in (not linked): " + " · ".join(rest), ""]
    lines += [GEN, ""]
    return "\n".join(lines)


def hub_note(atlas):
    groups = defaultdict(list)
    names = {"service": "Services", "class": "Classes", "member": "Methods, events and properties",
             "enum": "Enums", "datatype": "Data types", "concept": "Concepts"}
    for k, a in atlas.items():
        groups[a["spec"]["kind"]].append(k)
    lines = ["---", "tags: [atlas, hub, start-here, type/hub]", "---", f"# {HUB}", "",
             f"{len(atlas)} short nodes, one per Roblox API or core concept that at least 3 notes mention. Each one quotes "
             "the vault's own sentences (with the note it came from), lists key facts from those notes' TL;DRs and links "
             "the most relevant notes. Generated by `_tools/link_builder.py`; do not edit by hand.", ""]
    for kind in ("concept", "service", "class", "member", "datatype", "enum"):
        if groups[kind]:
            lines += [f"## {names[kind]} ({len(groups[kind])})", "", " · ".join(f"[[{k}]]" for k in sorted(groups[kind], key=str.lower)), ""]
    lines += [GEN, ""]
    return "\n".join(lines)


# ---------------------------------------------------------------- related notes
def related(notes, link_target_titles):
    prose = [n for n in notes if is_prose(n)]
    lower = {n["title"].lower(): n for n in notes}
    df, vecs = Counter(), {}
    for n in prose:
        body = re.sub(r"```.*?```", " ", n["clean"], flags=re.S)
        c = Counter()
        for w, f in ((n["title"], 3), (" ".join(n["base_tags"]).replace("-", " "), 2), (" ".join(n["heads"]), 2),
                     (" ".join(n["tldr"]), 2), (body, 1)):
            for t in toks(w):
                c[t] += f
        n["tf"] = c
        df.update(c.keys())
    N = len(prose)
    post = defaultdict(list)
    for n in prose:
        v = {t: (1 + math.log(f)) * math.log(N / df[t]) for t, f in n["tf"].items() if df[t] < N * 0.5}
        top = dict(sorted(v.items(), key=lambda x: -x[1])[:250])
        norm = math.sqrt(sum(x * x for x in top.values())) or 1
        vecs[n["title"]] = {t: x / norm for t, x in top.items()}
        for t, x in vecs[n["title"]].items():
            post[t].append((n["title"], x))
    out = {}
    for n in prose:
        existing = set()
        for m in re.finditer(r"\[\[([^\]|#\\]+)", RELATED_RE.sub("", n["text"])):
            tl = m.group(1).strip().lower()
            if tl in lower and lower[tl]["title"] not in link_target_titles:
                existing.add(lower[tl]["title"])
        n["outlinks"] = existing
    for n in prose:
        sc = Counter()
        for t, x in vecs[n["title"]].items():
            for other, y in post[t]:
                sc[other] += x * y
        tags = {t.lower() for t in n["base_tags"]}
        res = []
        for other, s in sc.items():
            if other == n["title"] or other in n["outlinks"]:
                continue
            o = lower[other.lower()]
            ot = {t.lower() for t in o["base_tags"]}
            s += 0.15 * (len(tags & ot) / len(tags | ot) if tags | ot else 0)
            s += 0.15 * (len(n["outlinks"] & o["outlinks"]) / len(n["outlinks"] | o["outlinks"]) if n["outlinks"] | o["outlinks"] else 0)
            if o["folder"] == n["folder"]:
                s += 0.03
            res.append((round(s, 6), other))
        res.sort(key=lambda x: (-x[0], x[1]))
        floor = max(0.06, 0.4 * res[0][0]) if res else 0.06  # weak in-folder matches do not count
        same = [r for r in res if lower[r[1].lower()]["section"] == n["section"] and r[0] >= floor][:SAME_MAX]
        best = same[0][0] if same else 0
        cross_floor = max(0.25, 0.85 * best) if len(same) >= MIN_LINKS else 0.12
        cross = [r for r in res if lower[r[1].lower()]["section"] != n["section"] and r[0] >= cross_floor][:CROSS_MAX]
        picks = same + cross
        if len(picks) < MIN_LINKS:  # small or already well-linked folder: top up with the next best notes anywhere
            picks += [r for r in res if r not in picks][:MIN_LINKS - len(picks)]
        out[n["title"]] = [t for _, t in sorted(picks, key=lambda x: (-x[0], x[1]))]
    return out


def with_related(text, links):
    base = RELATED_RE.sub("", text).rstrip("\n") + "\n"
    if not links:
        return base
    return base + "\n" + RS + "\n## Related\n" + " · ".join(f"[[{t}]]" for t in links) + "\n" + RE_ + "\n"


# ---------------------------------------------------------------- tags
def enrich_tags(n, api_rank):
    tags = list(dict.fromkeys(t.strip() for t in n["tags"] if t.strip()))
    low = {t.lower() for t in tags}
    hay = (" ".join(n["base_tags"]) + " " + n["title"] + " " + n["section"]).lower()
    adds = []
    if not any(t.startswith("type/") for t in low):
        if n["section"] == ATLAS:
            ty = "atlas"
        elif bi.NO_TLDR_TITLE.search(n["title"]) or "hub" in low:
            ty = "hub"
        elif "checklist" in hay:
            ty = "checklist"
        elif CASE.search(n["title"]) or "case-study" in low or n["section"][:2] in ("32",):
            ty = "case-study"
        elif REFERENCE.search(n["title"]) or n["section"][:2] in ("19", "46", "52") or "reference" in low:
            ty = "reference"
        else:
            ty = "guide"
        adds.append("type/" + ty)
    areas = [] if n["section"] == ATLAS else area_of(n)
    if areas:
        adds.append("area/" + areas[0])
    if not any(t.startswith("level/") for t in low) and n["section"] != ATLAS:
        size = len(re.sub(r"```.*?```", "", n["clean"], flags=re.S))
        blocks = n["clean"].count("```") // 2
        if n["section"][:2] == "52" or BEGINNER.search(n["title"]) or "fundamentals" in low:
            lv = "beginner"
        elif n["section"][:2] in ("35", "23") or "deep dive" in n["section"].lower() or ADVANCED.search(hay) \
                or (size > 30000 and blocks >= 8):
            lv = "advanced"
        else:
            lv = "intermediate"
        adds.append("level/" + lv)
    apis = api_rank.get(n["title"], [])
    if apis:
        adds.append("api/" + apis[0])
    if len(areas) > 1:
        adds.append("area/" + areas[1])
    adds += ["api/" + a for a in apis[1:3]]
    for a in adds:
        if a.lower() not in low and len(tags) < MAX_TAGS:
            tags.append(a)
            low.add(a.lower())
    return tags


def set_tags(text, tags):
    line = f"tags: [{', '.join(tags)}]"
    fm = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not fm:
        return f"---\n{line}\n---\n" + text
    body = fm.group(1)
    if re.search(r"^tags:.*$", body, re.M):
        new = re.sub(r"^tags:.*$", lambda m: line, body, count=1, flags=re.M)
    else:
        new = line + "\n" + body
    return text[:fm.start(1)] + new + text[fm.end(1):]


def api_ranking(notes, atlas):
    """Top API atlas terms per note: occurrences x rarity, ignoring plumbing every note uses."""
    N = len(notes)
    out = {}
    names = [k for k, a in atlas.items() if a["spec"]["kind"] != "concept" and k not in GENERIC_API]
    for n in notes:
        sc = []
        for k in names:
            c = atlas[k]["hits"].get(n["title"], 0)
            if c >= 3 or (c and (k in n["title"] or any(k in h for h in n["heads"]))):
                sc.append((-(c + (6 if k in n["title"] else 0)) * math.log(N / len(atlas[k]["hits"])), k))
        out[n["title"]] = [k for _, k in sorted(sc)[:3]]
    return out


# ---------------------------------------------------------------- first-mention links
def inbound(text, n, targets):
    if n["section"] == ATLAS:
        return text
    mask = masked(text)
    linked = {m.group(1).strip().lower() for m in re.finditer(r"\[\[([^\]|#\\]+)", text)}
    found = []
    for name, (target, spec) in targets.items():
        if target.lower() in linked or target == n["title"]:
            continue
        rx = re.compile(spec["rx"].pattern, 0 if spec["cs"] else re.I) if spec.get("concept") else \
            re.compile(r"(?<![\w./:#@-])" + re.escape(name) + r"(?![\w/]|[.:]\w|\()")
        m = rx.search(mask)
        if m:
            found.append((m.start(), m.end(), target))
    found.sort()
    keep, last = [], -1
    for a, b, t in found:
        if a >= last and t not in {k[2] for k in keep}:
            keep.append((a, b, t))
            last = b
        if len(keep) >= MAX_INBOUND:
            break
    for a, b, t in sorted(keep, reverse=True):
        shown = text[a:b]
        line_start = text.rfind("\n", 0, a) + 1
        in_table = text[line_start:a].lstrip().startswith("|")
        if shown.lower() == t.lower():
            rep = f"[[{shown}]]"
        else:
            rep = f"[[{t}{chr(92) if in_table else ''}|{shown}]]"
        text = text[:a] + rep + text[b:]
    return text


# ---------------------------------------------------------------- main
def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    args = sys.argv[1:]
    check, do_inbound = "--check" in args, "--no-inbound" not in args
    api = json.loads(read(os.path.join(TOOLS, "roblox_api.json")))
    api_date = api.get("source", {}).get("docs_date", "unknown")
    notes = collect()
    analyse(notes)
    by_title = {n["title"]: n for n in notes}
    atlas, targets = build_atlas(notes, api)
    rel = related(notes, {t for t, _ in targets.values()})
    if "--show" in args:
        t = args[args.index("--show") + 1]
        print(t, "->", rel.get(t))
        return
    changed = []
    # atlas notes (keep any TL;DR block build_index already put in)
    adir = os.path.join(KB, ATLAS)
    wanted = {os.path.join(adir, k + ".md"): atlas_note(k, a, by_title, api_date) for k, a in atlas.items()}
    wanted[os.path.join(adir, HUB + ".md")] = hub_note(atlas)
    for path, text in sorted(wanted.items()):
        if os.path.exists(path):
            m = bi.TLDR_RE.search(read(path))
            if m:
                text = bi.insert_tldr(text, m.group(0)[:-1])
        write(path, text, changed, check)
    dropped = set()
    if os.path.isdir(adir):
        for f in sorted(os.listdir(adir)):
            p = os.path.join(adir, f)
            if f.endswith(".md") and p not in wanted and GEN in read(p):
                changed.append(f"{ATLAS}/{f} (deleted)")
                dropped.add(f[:-3])
                if not check:
                    os.remove(p)
    # first-mention links to an atlas note that no longer exists go back to plain text
    unwrap = [(re.compile(r"\[\[" + re.escape(t) + r"\]\]"), t) for t in dropped] + \
             [(re.compile(r"\[\[" + re.escape(t) + r"\\?\|([^\]\n]+)\]\]"), r"\1") for t in dropped]
    # tags, first-mention links and related blocks on every other note
    api_rank = api_ranking([n for n in notes if n["section"] != ATLAS], atlas)
    stats = Counter()
    for n in notes:
        if n["section"] == ATLAS:
            continue
        text = n["text"]
        for rx, rep in unwrap:
            text = rx.sub(lambda m, r=rep: m.expand(r) if "\\" in r else r, text)
        tags = enrich_tags(n, api_rank)
        if tags != n["tags"]:
            text = set_tags(text, tags)
            stats["notes with new tags"] += 1
        if do_inbound:
            new = inbound(text, n, targets)
            if new != text:
                stats["notes with first-mention links"] += 1
                stats["first-mention links"] += new.count("[[") - text.count("[[")
            text = new
        if n["title"] in rel:
            text = with_related(text, rel[n["title"]])
        write(n["abs"], text, changed, check)
    same = sum(by_title[t]["section"] == by_title[s]["section"] for s, ts in rel.items() for t in ts)
    total = sum(len(v) for v in rel.values())
    kinds = Counter(a["spec"]["kind"] for a in atlas.values())
    print(f"atlas notes: {len(atlas)} ({', '.join(f'{k} {v}' for k, v in sorted(kinds.items()))}) + hub")
    print(f"related blocks: {len(rel)} notes, {total} links ({total / max(1, len(rel)):.1f}/note), "
          f"{100 * same / max(1, total):.0f}% same section")
    print(f"auto-link targets: {len(targets)} (terms in <= {MAX_SECTIONS_FOR_INBOUND} sections)")
    for k, v in sorted(stats.items()):
        print(f"{k}: {v}")
    print(f"{'would change' if check else 'changed'}: {len(changed)} files")
    if "-v" in args:
        for c in changed:
            print("  ", c)
    if check and changed:
        sys.exit(1)


if __name__ == "__main__":
    main()
