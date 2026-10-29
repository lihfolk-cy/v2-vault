"""Check every Roblox/Luau API name in the vault against the real API, so no note teaches a made-up
or silently deprecated API.

Usage (stdlib only, no network):
    python "LihFolk Vault V2/_tools/api_check.py"               # check, print summary, write _tools/reports/api_check.md
    python "LihFolk Vault V2/_tools/api_check.py" --strict      # exit 1 on any finding not in api_allow.txt (CI)
    python "LihFolk Vault V2/_tools/api_check.py" --refresh     # rebuild roblox_api.json from the local Studio install
                                                       # (or: --refresh --dump API-Dump.json --docs en-us.json)

What it checks, in code blocks and `inline code`:
    Instance.new("X")            X is a real class, creatable, not deprecated
    GetService("X")              X is a real service
    Enum.A / Enum.A.B            the enum and item exist and are not deprecated
    math.x / task.x / Vector3.x  Luau and Roblox library members exist (CFrame.lookAt, table.clone, ...)
    Class.Member / Class:Method  the member exists on the class or a superclass (Humanoid.WalkSpeed, ...)
    wait() / spawn() / :connect() and other deprecated calls
A deprecated name is fine when the text right around it says so (deprecated, legacy, avoid, instead, ...).
The API snapshot (roblox_api.json) is committed, so CI checks against a fixed, dated API version.
"""
import glob
import json
import os
import re
import sys
from collections import defaultdict

TOOLS = os.path.dirname(os.path.abspath(__file__))
KB = os.path.dirname(TOOLS)
SNAP = os.path.join(TOOLS, "roblox_api.json")
ALLOW = os.path.join(TOOLS, "api_allow.txt")
REPORT = os.path.join(TOOLS, "reports", "api_check.md")
CAVEAT = re.compile(r"(?i)deprecat|legacy|\bold\b|older|avoid|instead|don't|do not|never|replac|superseded|"
                    r"\bbad\b|wrong|outdated|was removed|no longer|-- ?x\b|not recommended|anti-pattern|before:")
SKIP_ROOT = {"INDEX.md", "INDEX_SLIM.md", "ROUTER.md", "LICENSE.md"}


# ---------------------------------------------------------------- snapshot
def find_local_sources():
    vers = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    docs = sorted(glob.glob(os.path.join(vers, "*", "content", "api_docs", "en-us.json")), key=os.path.getmtime)
    dumps = sorted(glob.glob(os.path.join(os.path.expanduser("~"), ".vscode", "extensions", "*", "server", "api",
                                          "API-Dump.json")) + glob.glob(os.path.join(vers, "*", "API-Dump.json")),
                   key=os.path.getmtime)
    return (dumps[-1] if dumps else None), (docs[-1] if docs else None)


def refresh(dump_path, docs_path):
    dump = json.load(open(dump_path, encoding="utf-8"))
    docs = json.load(open(docs_path, encoding="utf-8")) if docs_path else {}
    def dep(key):
        """0, or the replacement the docs name (or 1) when the docs mark it deprecated."""
        doc = (docs.get(key) or {}).get("documentation", "")
        if "<strong>Deprecated" not in doc:
            return 0
        m = re.search(r"(?:superseded by|in favor of|favour of|use|replaced by)\s+(?:using\s+)?<code>([^<]+)</code>",
                      doc.split("<br>")[0], re.I)
        return m.group(1) if m else 1
    classes = {}
    for c in dump["Classes"]:
        tags = c.get("Tags") or []
        classes[c["Name"]] = {
            "super": c.get("Superclass") or "",
            "service": "Service" in tags, "notcreatable": "NotCreatable" in tags,
            "deprecated": "Deprecated" in tags or dep(f"@roblox/globaltype/{c['Name']}"),
            "members": {m["Name"]: dep(f"@roblox/globaltype/{c['Name']}.{m['Name']}")
                        or int("Deprecated" in (m.get("Tags") or [])) for m in c["Members"]}}
    types = {}  # data types (CFrame, RaycastParams, UDim2, ...): their properties and methods
    for key in docs:
        m = re.match(r"^@roblox/globaltype/(\w+)\.(\w+)$", key)
        if m and m.group(1) in classes:  # members documented in the newer docs file but missing from the dump
            classes[m.group(1)]["members"].setdefault(m.group(2), dep(key))
        elif m:
            types.setdefault(m.group(1), {})[m.group(2)] = dep(key)
    enums = {e["Name"]: {i["Name"]: dep(f"@roblox/enum/{e['Name']}.{i['Name']}")
                         or int("Deprecated" in (i.get("Tags") or [])) for i in e["Items"]} for e in dump["Enums"]}
    for key in docs:
        m = re.match(r"^@roblox/enum/(\w+)\.(\w+)$", key)
        if m:
            enums.setdefault(m.group(1), {}).setdefault(m.group(2), dep(key))
        m = re.match(r"^@roblox/enum/(\w+)$", key)
        if m:
            enums.setdefault(m.group(1), {})
    globs = {}
    for key in docs:
        m = re.match(r"^@(?:roblox|luau)/global/([\w.]+)$", key)
        if m:
            globs[m.group(1)] = dep(key)
    luau = luau_libs()  # the Luau runtime is newer than the Studio docs file (coroutine.finally, ...)
    for k in luau:
        globs.setdefault(k, 0)
    snap = {"source": {"luau": f"{len(luau)} library members from {LUAU_EXE}" if luau else "","dump": os.path.basename(os.path.dirname(os.path.dirname(dump_path))) + "/API-Dump.json",
                       "docs": (os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(docs_path))))
                                if docs_path else ""),
                       "dump_date": _date(dump_path), "docs_date": _date(docs_path) if docs_path else ""},
            "classes": classes, "types": types, "enums": enums, "globals": globs}
    with open(SNAP, "w", encoding="utf-8", newline="\n") as f:
        json.dump(snap, f, sort_keys=True, separators=(",", ":"))
        f.write("\n")
    print(f"wrote {SNAP}: {len(classes)} classes, {len(enums)} enums, {len(globs)} globals")


LUAU_EXE = os.environ.get("LUAU", "luau")


def luau_libs():
    """Ask a local `luau` binary (env LUAU or PATH) which standard-library members exist."""
    import subprocess
    import tempfile
    code = ('for _, lib in {"math","string","table","coroutine","bit32","utf8","os","debug","buffer","vector"} do '
            'local t = _G[lib] if type(t) == "table" then for k in t do print(lib .. "." .. k) end end end')
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    try:
        out = subprocess.run([LUAU_EXE, f.name], capture_output=True, text=True, timeout=30).stdout
        return sorted(set(out.split()))
    except (OSError, subprocess.SubprocessError):
        return []
    finally:
        os.unlink(f.name)


def _date(p):
    import time
    return time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(p)))


# ---------------------------------------------------------------- extraction
def note_files():
    for root, dirs, fs in os.walk(KB):
        dirs[:] = sorted(d for d in dirs if not d.startswith((".", "_")))
        for f in sorted(fs):
            if f.endswith(".md") and not (root == KB and f in SKIP_ROOT):
                yield os.path.join(root, f)


def code_spans(text):
    """(start, code) for fenced blocks (any language but obvious non-Luau) and inline code."""
    spans, taken = [], []
    for m in re.finditer(r"^```([\w+-]*)[^\n]*\n(.*?)^```", text, re.S | re.M):
        lang = m.group(1).lower()
        taken.append((m.start(), m.end()))
        if lang in ("", "lua", "luau", "text") or lang.startswith("lua"):
            spans.append((m.start(2), m.group(2), True))
    for m in re.finditer(r"`([^`\n]+)`", text):
        if not any(a <= m.start() < b for a, b in taken):
            spans.append((m.start(1), m.group(1), False))
    return spans


def strip_strings_comments(code):
    """Blank out comments and string contents (keeping the first argument of Instance.new/GetService)."""
    code = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: " " * len(m.group(0)), code, flags=re.S)
    code = re.sub(r"--[^\n]*", lambda m: " " * len(m.group(0)), code)
    keep = re.compile(r'(Instance\.new|GetService|FindFirstChildOfClass|FindFirstAncestorOfClass|IsA|'
                      r'FindFirstChildWhichIsA|FindFirstAncestorWhichIsA)\(\s*$')

    def repl(m):
        before = code[max(0, m.start() - 40): m.start()]
        return m.group(0) if keep.search(before) else m.group(0)[0] + " " * (len(m.group(0)) - 2) + m.group(0)[-1]
    return re.sub(r'"[^"\n]*"|\'[^\'\n]*\'', repl, code)


PLACEHOLDER = re.compile(r"^(X|Y|Z|Name|Foo|Bar|Something|Change|Thing|Item|MyThing)$")
ERR_CAVEAT = re.compile(r"(?i)\bno\b|\bnot\b|doesn't|does not|isn't|removed|missing|unavailable|there is no|"
                        r"hallucinat|invent|made.up|fake|nonexistent|non-existent")


def dep_msg(d, what="deprecated"):
    return f"{what}, use {d}" if isinstance(d, str) else what


class Checker:
    def __init__(self, snap):
        self.c, self.e, self.g, self.t = snap["classes"], snap["enums"], snap["globals"], snap.get("types", {})
        self.lib = {k.split(".")[0] for k in self.g if "." in k}
        self.method_owners = defaultdict(list)
        for c in self.c.values():
            for mn, d in c["members"].items():
                self.method_owners[mn].append(d)

    def member(self, cls, name):
        seen = set()
        while cls and cls in self.c and cls not in seen:
            seen.add(cls)
            if name in self.c[cls]["members"]:
                return self.c[cls]["members"][name]
            cls = self.c[cls]["super"]
        return None

    def check(self, code, inline):
        """Yield (kind, symbol, message, offset). kind: error | unknown | deprecated."""
        src = strip_strings_comments(code) if not inline else code
        defined = set(re.findall(r"(?:local\s+function\s+|local\s+|function\s+)(\w+)", src))
        for m in re.finditer(r'Instance\.new\(\s*["\'](\w+)["\']', src):
            n = m.group(1)
            if PLACEHOLDER.match(n):
                continue
            if n not in self.c:
                yield "error", f'Instance.new("{n}")', f"no class named {n}", m.start()
            elif self.c[n]["deprecated"]:
                yield "deprecated", f'Instance.new("{n}")', dep_msg(self.c[n]["deprecated"], f"{n} is deprecated"), m.start()
            elif self.c[n]["notcreatable"]:
                yield "error", f'Instance.new("{n}")', f"{n} cannot be created with Instance.new", m.start()
        for m in re.finditer(r'GetService\(\s*["\'](\w+)["\']', src):
            n = m.group(1)
            if PLACEHOLDER.match(n):
                continue
            if n not in self.c:
                yield "error", f'GetService("{n}")', f"no class named {n}", m.start()
            elif not self.c[n]["service"]:
                yield "error", f'GetService("{n}")', f"{n} is not a service", m.start()
        for m in re.finditer(r'(?:IsA|OfClass|WhichIsA)\(\s*["\'](\w+)["\']', src):
            if m.group(1) not in self.c and not PLACEHOLDER.match(m.group(1)):
                yield "error", m.group(0) + ")", f"no class named {m.group(1)}", m.start()
        for m in re.finditer(r"(?<![\w.])Enum\.(\w+)(?:\.(\w+))?", src):
            en, item = m.group(1), m.group(2)
            if PLACEHOLDER.match(en) or item and PLACEHOLDER.match(item):
                continue
            if en not in self.e:
                yield "error", f"Enum.{en}", f"no enum named {en}", m.start()
            elif item and item not in ("Name", "Value", "EnumType") and not item.startswith("Get"):
                if item not in self.e[en]:
                    yield "error", f"Enum.{en}.{item}", f"Enum.{en} has no item {item}", m.start()
                elif self.e[en][item]:
                    yield "deprecated", f"Enum.{en}.{item}", dep_msg(self.e[en][item]), m.start()
        for m in re.finditer(r"(?<![\w.:])([A-Za-z]\w*)([.:])([A-Za-z_]\w*)\b", src):
            obj, sep, name = m.groups()
            if obj == "Enum" or obj in defined or PLACEHOLDER.match(name) or len(name) == 1:
                continue
            if obj in self.lib or obj in self.t:  # math.x, task.x, CFrame.lookAt, RaycastParams.FilterType
                key = f"{obj}.{name}"
                if key in self.g:
                    if self.g[key]:
                        yield "deprecated", key, dep_msg(self.g[key]), m.start()
                elif name in self.t.get(obj, {}):
                    if self.t[obj][name]:
                        yield "deprecated", key, dep_msg(self.t[obj][name]), m.start()
                elif obj not in self.c:
                    yield "error", key, f"{obj} has no member {name}", m.start()
                continue
            if obj in self.c and obj[0].isupper():
                d = self.member(obj, name)
                if d is None and sep == ":" and name[0].isupper():  # a dot may be a child; a method call cannot
                    yield "unknown", f"{obj}:{name}", f"{obj} has no method {name}", m.start()
                elif d:
                    yield "deprecated", f"{obj}{sep}{name}", dep_msg(d), m.start()
        for m in re.finditer(r"(?<![\w.:])([a-z]\w*)\s*\(", src):
            n = m.group(1)
            if n not in defined and self.g.get(n):
                yield "deprecated", n + "()", dep_msg(self.g[n], "deprecated global"), m.start()
        for m in re.finditer(r":(\w+)\s*\(", src):
            n = m.group(1)
            if n in ("connect", "disconnect"):  # RBXScriptSignal/Connection lower-case aliases
                yield "deprecated", ":" + n + "()", "deprecated lower-case alias, use :" + n.capitalize() + "()", m.start()
                continue
            owners = self.method_owners.get(n)
            # lower-case names are usually the note's own objects (signal:fire(), janitor:destroy())
            if n[0].isupper() and owners and all(owners) and n != "LoadAnimation":
                rep = next((d for d in owners if isinstance(d, str)), 1)
                yield "deprecated", ":" + n + "()", dep_msg(rep), m.start()


def main():
    args = sys.argv[1:]
    if "--refresh" in args:
        dump = args[args.index("--dump") + 1] if "--dump" in args else None
        docs = args[args.index("--docs") + 1] if "--docs" in args else None
        ld, lc = find_local_sources()
        dump, docs = dump or ld, docs or lc
        if not dump:
            sys.exit("no API-Dump.json found; pass --dump <path>")
        refresh(dump, docs)
        return
    snap = json.load(open(SNAP, encoding="utf-8"))
    ck = Checker(snap)
    allow = set()
    if os.path.exists(ALLOW):
        for line in open(ALLOW, encoding="utf-8"):
            line = line.split("#", 1)[0].strip()
            if line:
                p = [x.strip() for x in line.split("|")]
                allow.add((p[0], p[1]) if len(p) > 1 else ("*", p[0]))
    found, intentional, allowed = [], 0, 0
    counts = defaultdict(int)
    for path in note_files():
        rel = os.path.relpath(path, KB).replace(os.sep, "/")
        text = open(path, encoding="utf-8").read()
        for start, code, block in code_spans(text):
            for kind, sym, msg, off in ck.check(code, not block):
                pos = start + off
                ctx = text[max(0, pos - 220): pos + 160]
                row = text[text.rfind("\n", 0, pos) + 1: text.find("\n", pos) % (len(text) + 1)]
                if kind == "deprecated" and (CAVEAT.search(ctx) or row.startswith("|") and "task." in row) or \
                        kind != "deprecated" and ERR_CAVEAT.search(text[max(0, pos - 120): pos + 80]):
                    intentional += 1
                    continue
                if (rel, sym) in allow or ("*", sym) in allow:
                    allowed += 1
                    continue
                line = text.count("\n", 0, pos) + 1
                found.append((kind, rel, line, sym, msg))
    uniq = {}  # `Player:LoadCharacter` and `:LoadCharacter()` on one line are one finding
    for f in sorted(found, key=lambda f: -len(f[3])):
        uniq.setdefault((f[1], f[2], re.sub(r"^.*[.:]|\(\)$", "", f[3].replace("()", ""))), f)
    found = sorted(uniq.values(), key=lambda f: (f[0], f[1], f[2]))
    for f in found:
        counts[f[0]] += 1
    src = snap["source"]
    out = ["# API check report", "",
           f"Generated by `_tools/api_check.py` against `roblox_api.json` (Studio API docs {src.get('docs_date')}, "
           f"API dump {src.get('dump_date')}): {len(snap['classes'])} classes, {len(snap['enums'])} enums, "
           f"{len(snap['globals'])} globals.", "",
           f"- Findings: {len(found)} (" + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())) + ")",
           f"- Deprecated names used with a caveat nearby (fine, not listed): {intentional}",
           f"- Allowed by `api_allow.txt`: {allowed}", "",
           "| Kind | Note | Line | Symbol | Problem |", "|---|---|---:|---|---|"]
    out += [f"| {k} | {p} | {ln} | `{s}` | {m} |" for k, p, ln, s, m in found]
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("\n".join(out[3:7]))
    for k, p, ln, s, m in found[:60]:
        print(f"  {k:10} {p}:{ln}  {s}  ({m})")
    if len(found) > 60:
        print(f"  ... {len(found) - 60} more in {os.path.relpath(REPORT, KB)}")
    if "--strict" in args and found:
        sys.exit(1)


if __name__ == "__main__":
    main()
