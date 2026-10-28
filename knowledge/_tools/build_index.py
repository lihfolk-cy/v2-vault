"""Build the token-saving layer of LihFolk Vault V2 from the notes themselves.

Usage (from the repo root or anywhere):
    python knowledge/_tools/build_index.py              # regenerate everything
    python knowledge/_tools/build_index.py --check      # exit 1 if anything would change
    python knowledge/_tools/build_index.py --measure    # print the 8-task token comparison
    python knowledge/_tools/build_index.py --no-tldr-in "56 Field Notes"   # leave that section's notes untouched

Generates (all deterministic, stdlib only, no network; running it twice changes nothing):
    knowledge/INDEX.md           title | path | tags | first sentence (<= 110 chars), tags deduped
    knowledge/INDEX_SLIM.md      title | path | tags
    knowledge/ROUTER.md          <= 6 KB keyword -> section + best notes map; the first file an agent reads
    knowledge/_maps/<section> - Map.md   one line per note: title + first TL;DR bullet
    a TL;DR block in every prose note, between <!-- tldr:start --> and <!-- tldr:end -->,
    distilled from the note's own "Common mistakes" and "Checklist" items. Nothing outside
    the markers is ever changed.
"""
import math
import os
import re
import sys
from collections import Counter, defaultdict

KB = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # knowledge/
START, END = "<!-- tldr:start -->", "<!-- tldr:end -->"
TLDR_RE = re.compile(re.escape(START) + r"\n.*?" + re.escape(END) + r"\n\n", re.S)

# Root files that are not notes (or are navigation) and stay out of the index, as before.
ROOT_NOT_INDEXED = {"00 Start Here.md", "000 Home.md", "Glossary.md", "INDEX.md", "INDEX_SLIM.md",
                    "ROUTER.md", "LICENSE.md", "Open Questions - Whole Vault.md"}
ROOT_SECTION = "31 AI Skills for Roblox"  # root skill notes are listed under this pseudo-section
# Folders that are link libraries or assets, not prose: indexed (if .md) but never given a TL;DR.
NO_TLDR_SECTIONS = {"46 Resource Library"}
NO_TLDR_TITLE = re.compile(r"(Start Here|Link Check| - Map$|^Concept Sheets$|^LICENSE$)")
NAV_HEAD = re.compile(r"(?i)^(\d+[.)]\s*)?(see also|connected notes|related\b|sources|links\b|topics|"
                      r"the notes|reading|suggested|contents|tiny example|example|references?|further|where this shows up)")
MISTAKES_HEAD = re.compile(r"(?i)mistakes|gotchas|pitfalls|failure modes|anti-patterns")
CHECK_HEAD = re.compile(r"(?i)checklist")
KEY_HEAD = re.compile(r"(?i)nuance|gotcha|rule|docs do not say|things|why it matters|key|diagnos|"
                      r"principle|lesson|takeaway|when to use|what it does|in short|summary")
MAX_BULLET = 130

# Hand-curated core topics for ROUTER.md: (keywords, [note titles]). Titles are validated.
CORE = [
    ("remotes: RemoteEvent/Function, Unreliable, validation, rate limits",
     ["RemoteEvents RemoteFunctions and Unreliable Remotes", "Server Authority and Validation",
      "Remote Abuse Patterns and Rate Limiting in Practice"]),
    ("DataStores: UpdateAsync, session lock, BindToClose, migration",
     ["DataStore Fundamentals", "Session Locking and Profile Libraries",
      "Saving Correctly - Autosave and BindToClose"]),
    ("monetization: ProcessReceipt, dev products, game passes, pricing",
     ["Developer Products and ProcessReceipt", "Purchase Data and Receipts", "Monetization Overview"]),
    ("UI: ScreenGui, UIScale, safe area, mobile, responsive",
     ["ScreenGui Fundamentals", "Responsive UI for Phone Tablet Console and PC", "Safe Areas and Insets"]),
    ("VFX: ParticleEmitter, Beam, Trail, slash, impact, aura",
     ["VFX Design Playbook", "Particle Emitters In Depth", "Beams and Trails"]),
    ("animation: Animator, AnimationTrack, priority, blending",
     ["Animator Deep Dive", "Playback, Priorities and Blending", "Debugging Animation Problems"]),
    ("combat: hitboxes, raycasts, prediction",
     ["Hitboxes and Hit Detection", "Combat Systems Architecture",
      "Client Prediction and Reconciliation for Combat"]),
    ("physics: assemblies, constraints, network ownership, vehicles",
     ["Physics Assemblies and Constraints", "Network Ownership", "Mover Constraints and Physics Controllers"]),
    ("performance: MicroProfiler, frame budget, memory leaks",
     ["Performance Fundamentals", "MicroProfiler Guide", "Hunting Memory Leaks Step by Step"]),
    ("security: exploits, server authority, anti-cheat, dupes",
     ["How Exploits Work - The Client Boundary", "Economy Exploits - Dupes Races and Purchase Abuse",
      "Detecting Combat Exploits - Reach Rate and Aim"]),
    ("debugging: bisect, desync, race conditions",
     ["The Debugging Method - Reproduce Isolate Bisect", "Debugging Client-Server Desync",
      "Debugging Race Conditions and Yield Order"]),
    ("Blender/modeling: FBX/GLB export, scale, triangles",
     ["Exporting and Validating Models for Roblox", "Modeling in Blender for Roblox",
      "Modelling to the Roblox Camera and Player Scale"]),
    ("worldbuilding: level design, terrain, environment art",
     ["Level Design for Roblox", "Terrain Tools and Terrain API", "Environment Art Styles"]),
    ("design/economy: core loop, retention, currencies, sinks",
     ["Core Loops and Session Design", "Economy Inflation Sinks and Faucets Math",
      "Currency Architecture - Soft Hard and Event Currencies"]),
    ("publishing: release, rollback, QA, store page",
     ["Publishing an Experience", "Release Process and Rollbacks", "QA Checklists Before Release"]),
]

# Realistic tasks for --measure: (task, grep regex an agent would use, [2 best notes], the one section it needs)
TASKS = [
    ("secure a RemoteEvent for buying", r"remoteevent", ["RemoteEvents RemoteFunctions and Unreliable Remotes",
                                                           "Server Authority and Validation"], "Argument rules"),
    ("DataStore session locking", r"session.lock", ["Session Locking and Profile Libraries", "DataStore Fundamentals"],
     "Leases, not locks"),
    ("ProcessReceipt", r"processreceipt", ["Developer Products and ProcessReceipt", "Purchase Data and Receipts"],
     "2. The receipt contract"),
    ("mobile-safe ScreenGui", r"screengui|safe.area", ["ScreenGui Fundamentals", "Safe Areas and Insets"],
     "6. The two-layer pattern"),
    ("slash VFX", r"slash", ["Beams and Trails", "VFX Design Playbook"], "2. Slash crescents with beams"),
    ("hitbox", r"hitbox", ["Hitboxes and Hit Detection", "Detecting Combat Exploits - Reach Rate and Aim"],
     "2. Where the hit is decided"),
    ("memory leak", r"leak", ["Hunting Memory Leaks Step by Step", "Memory Budgets and Leaks"],
     "2. Find the category that grows"),
    ("Blender export scale", r"export", ["Exporting and Validating Models for Roblox",
                                         "Modelling to the Roblox Camera and Player Scale"], "3. Export settings"),
]


# ---------------------------------------------------------------- helpers
def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write_if_changed(path, text, changed):
    if os.path.exists(path) and read(path) == text:
        return
    changed.append(os.path.relpath(path, KB).replace(os.sep, "/"))
    if CHECK:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def strip_md(s):
    s = re.sub(r"!\[\[[^\]]*\]\]", "", s)
    s = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", s)
    s = re.sub(r"\[\[([^\]]+)\]\]", r"\1", s)
    s = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", s)
    s = s.replace("**", "").replace("<br>", " ")
    return " ".join(s.split()).strip()


def first_sentence(s):
    m = re.search(r"(?<=[.!?])\s+(?=[A-Z`\"(\[])", s)
    return s[:m.start()] if m else s


def cap(s, n):
    if len(s) <= n:
        return s
    cut = s[:n - 3]
    if " " in cut[n // 2:]:
        cut = cut[:cut.rfind(" ")]
    return cut.rstrip(" ,;:-") + "..."


def short(s, n=MAX_BULLET):
    s = strip_md(s)
    one = first_sentence(s)
    if len(one) < 40 and len(one) < len(s):  # a bold lead like "Test at real size." needs its follow-up
        one = one + " " + first_sentence(s[len(one):].strip())
    return cap(one, n)


def split_row(line):
    line = line.strip().replace("\\|", "\x00")
    cells = [c.strip().replace("\x00", "|") for c in line.strip("|").split("|")]
    return cells


def sections(body):
    """[(level, heading, text)] for ## and ### headings, skipping fenced code."""
    out, cur, buf, fence = [], (0, "", ), [], False
    for line in body.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
        m = None if fence else re.match(r"^(#{2,3}) +(.+?)\s*$", line)
        if m:
            out.append((cur[0], cur[1], "\n".join(buf)))
            cur, buf = (len(m.group(1)), m.group(2)), []
        else:
            buf.append(line)
    out.append((cur[0], cur[1], "\n".join(buf)))
    return out[1:]


def h2_with_children(secs, i):
    """Text of an H2 section including its ### subsections."""
    parts = [secs[i][2]]
    for lvl, h, t in secs[i + 1:]:
        if lvl <= 2:
            break
        parts.append("### " + h + "\n" + t)
    return "\n".join(parts)


def list_items(text, limit):
    items, fence = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        m = re.match(r"^(?:[-*]|\d+[.)])\s+(?:\[[ xX]\]\s+)?(.+)$", line)
        if m and m.group(1).strip():
            items.append(m.group(1))
            if len(items) >= limit:
                break
    return items


def table_rows(text):
    lines = [l for l in text.split("\n") if l.strip().startswith("|")]
    if len(lines) < 3 or not re.match(r"^\|?\s*:?-{2,}", lines[1].strip()):
        return None, []
    return [c.lower() for c in split_row(lines[0])], [split_row(l) for l in lines[2:]]


def mistake_bullets(text, limit, are_mistakes=True):
    head, rows = table_rows(text)
    first_tbl = text.find("|")
    first_list = re.search(r"^(?:[-*]|\d+[.)])\s", text, re.M)
    use_table = head and (not first_list or first_tbl < first_list.start())
    out = []
    if use_table:
        def col(pat):
            for i, h in enumerate(head):
                if re.search(pat, h):
                    return i
            return None
        fix = col(r"fix|better|instead|response|check|test|do this")
        cause = col(r"cause")
        symptom_first = re.search(r"symptom|on screen|looks like", head[0])
        conseq = col(r"consequence|result|effect|happens|symptom|what you see|on screen|looks|shows|spot")
        for r in rows[:limit]:
            if not r or not r[0]:
                continue
            c = lambda i: cap(first_sentence(strip_md(r[i])), 70) if i is not None and i < len(r) and r[i] else ""
            if symptom_first:
                s = c(0) + (": " + c(cause) if cause not in (None, 0) and c(cause) else "")
            else:
                s = "Avoid: " + c(0)
                if fix in (None, 0) and conseq not in (None, 0) and c(conseq):
                    s += " (" + c(conseq) + ")"
            if fix not in (None, 0) and c(fix):
                s += " -> " + c(fix)
            out.append(cap(s, 170))
    else:
        for it in list_items(text, limit):
            s = short(it)
            keep = not are_mistakes or re.match(r"(?i)(avoid|don't|do not|never|not )", s)
            out.append(s if keep else "Avoid: " + s)
    if not out:  # ### subsections or paragraphs
        subs = re.findall(r"^### +(.+)$", text, re.M)
        out = [("Avoid: " if are_mistakes else "") + short(s) for s in subs[:limit]]
    return out


def checklist_bullets(text, limit):
    head, rows = table_rows(text)
    items = list_items(text, limit)
    if not items and rows:
        items = [r[0] for r in rows[:limit]]
    return [short(i) for i in items]


META = re.compile(r"(?i)(:$|\b(below|this list|this table|the following|taken from|this note|this section)\b)")


def fallback_bullets(secs, limit=4):
    """First items / first sentence of key sections, for notes with no mistakes or checklist."""
    cands = []
    for i, (lvl, h, t) in enumerate(secs):
        if lvl != 2 or NAV_HEAD.search(h):
            continue
        cands.append((0 if KEY_HEAD.search(h) else 1, i, h, t))
    cands.sort(key=lambda c: (c[0], c[1]))
    out = []
    for prio, i, h, t in cands:
        for block in re.split(r"\n\s*\n", t.strip()):
            b = block.strip()
            if not b or b.startswith(("|", "```", "!", "<", ">", "#")):
                continue
            items = list_items(b, 3 if prio == 0 else 1)
            got = [short(x) for x in items] if items else [short(b)]
            got = [g for g in got if len(g) >= 20 and not META.search(g)]
            if got:
                out += [g for g in got if g not in out]
                break
        if len(out) >= limit:
            break
    return out[:limit]


def parse_note(text):
    fm = re.match(r"^---\n.*?\n---\n", text, re.S)
    tags = re.search(r"^tags:\s*\[(.*?)\]", fm.group(0) if fm else "", re.M)
    tags = [t.strip().strip("'\"") for t in tags.group(1).split(",")] if tags else []
    seen, dedup = set(), []
    for t in tags:
        if t and t.lower() not in seen:
            seen.add(t.lower())
            dedup.append(t)
    return fm, dedup


def summary_of(text):
    body = re.sub(r"^---.*?---", "", text, count=1, flags=re.S)
    body = re.sub(r"```.*?```", "", body, flags=re.S)
    for para in re.split(r"\n\s*\n", body):
        p = para.strip()
        if not p or p.startswith(("#", "!", "|", "<!--", "- ", ">", "Part of")) or p.startswith("**Measured"):
            continue
        p = re.sub(r"\[\[([^\]|]+)\|?([^\]]*)\]\]", lambda m: m.group(2) or m.group(1), p)
        p = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", p)
        p = re.sub(r"[*`]", "", " ".join(p.split()))
        return cap(re.split(r"(?<=[.!?])\s", p)[0], 110)
    return ""


# ---------------------------------------------------------------- collect
def collect():
    notes = []
    for root, dirs, files in os.walk(KB):
        dirs[:] = sorted(d for d in dirs if not d.startswith((".", "_")))
        rel = os.path.relpath(root, KB)
        for f in sorted(files):
            if not f.endswith(".md"):
                continue
            if rel == "." and f in ROOT_NOT_INDEXED:
                continue
            path = os.path.join(root, f)
            relp = os.path.relpath(path, KB).replace(os.sep, "/")
            sec = ROOT_SECTION if rel == "." else rel.split(os.sep)[0]
            notes.append({"title": f[:-3], "path": relp, "abs": path, "section": sec, "text": read(path)})
    return notes


def tldr_for(note):
    clean = TLDR_RE.sub("", note["text"], count=1)
    note["clean"] = clean
    if note["section"] in NO_TLDR_SECTIONS or NO_TLDR_TITLE.search(note["title"]) or note["section"] == ROOT_SECTION:
        return None, "hub/link list/pointer"
    fm, _ = parse_note(clean)
    body = clean[fm.end():] if fm else clean
    secs = sections(body)
    m_idx = [i for i, s in enumerate(secs) if s[0] == 2 and re.search(r"(?i)mistakes", s[1])]
    if not m_idx:
        m_idx = [i for i, s in enumerate(secs) if s[0] == 2 and MISTAKES_HEAD.search(s[1])]
    if not m_idx:  # mistakes as ### under e.g. "## 11. Common mistakes and extensions" handled; also ### level
        m_idx = [i for i, s in enumerate(secs) if s[0] == 3 and MISTAKES_HEAD.search(s[1])]
    c_idx = [i for i, s in enumerate(secs) if CHECK_HEAD.search(s[1])]
    bullets = []
    if m_idx:
        bullets += mistake_bullets(h2_with_children(secs, m_idx[0]), 3, "mistake" in secs[m_idx[0]][1].lower())
    if c_idx:
        bullets += checklist_bullets(h2_with_children(secs, c_idx[0]), 6 - len(bullets) if not m_idx else 3)
    kind = "mistakes/checklist"
    if len(bullets) < 3:
        extra = fallback_bullets(secs, 4)
        bullets += [b for b in extra if b not in bullets][: max(0, 4 - len(bullets))]
        kind = "key headings" if not (m_idx or c_idx) else kind
    bullets = list(dict.fromkeys(b for b in bullets if b))[:6]
    if len(bullets) < 3:
        return None, "too little extractable text"
    special = {secs[i][1] for i in m_idx[:1] + c_idx[:1]}
    content = [(len(h2_with_children(secs, i)), i, s[1]) for i, s in enumerate(secs)
               if s[0] == 2 and s[1] not in special and not NAV_HEAD.search(s[1])
               and not MISTAKES_HEAD.search(s[1]) and not CHECK_HEAD.search(s[1])]
    top = sorted(sorted(content, reverse=True)[:2], key=lambda c: c[1])
    names = [c[2] for c in top] + [secs[i][1] for i in sorted(m_idx[:1] + c_idx[:1])]
    size = len(clean.encode("utf-8"))
    lines = [START, "> [!tldr] TL;DR"] + ["> - " + b for b in bullets] + [">"]
    tldr_bytes = len("\n".join(lines).encode("utf-8")) + 120
    lines.append(f"> Cost: TL;DR {fmt_tok(tldr_bytes)} · whole note {fmt_tok(size)}. Read more: "
                 + " · ".join("## " + n for n in names))
    lines.append(END)
    return "\n".join(lines) + "\n", kind


def fmt_tok(nbytes):
    """Token estimate shown in notes and indexes: ~bytes/4 (English Markdown averages 3.5-4.5 bytes per token)."""
    t = nbytes / 4
    return f"~{t / 1000:.1f}k tok" if t >= 1000 else f"~{int(round(t, -1)) or 10} tok"


def insert_tldr(clean, block):
    fm = re.match(r"^---\n.*?\n---\n", clean, re.S)
    pos = fm.end() if fm else 0
    h1 = re.compile(r"^# .*\n", re.M).search(clean, pos)
    if h1 and clean[pos:h1.start()].strip() == "":
        pos = h1.end()
    else:
        while clean.startswith("\n", pos):
            pos += 1
    if clean.startswith("\n", pos):
        pos += 1
    return clean[:pos] + block + "\n" + clean[pos:]


# ---------------------------------------------------------------- outputs
def build_index(notes, slim):
    if slim:
        head = ["# LihFolk Vault V2 Index (slim)", "",
                "One line per note: `title | path | tags | ~whole-note tokens`. Grep it for an API name, topic or tag; paths are relative to",
                "`knowledge/`. Then read the note's TL;DR block, not the whole note. Generated by `_tools/build_index.py`.", ""]
    else:
        head = ["# LihFolk Vault V2 Index", "",
                "Machine-friendly index of every note: `title | path | tags | first sentence`. Built for AI agents: grep this file for an API name,",
                "topic or tag, then open only the notes you need. Generated by `_tools/build_index.py` (do not edit by hand);",
                "`INDEX_SLIM.md` is the same without first sentences, `ROUTER.md` is the keyword map. Asset folders (20, 30) are not indexed.", ""]
    out, by = head, defaultdict(list)
    for n in notes:
        by[n["section"]].append(n)
    for sec in sorted(by):
        out += [f"## {sec}", ""]
        for n in by[sec]:
            cost = fmt_tok(len(n.get("clean", n["text"]).encode("utf-8")))
            row = f"- {n['title']} | {n['path']} | {', '.join(n['tags'])} | {cost}"
            out.append(row if slim else f"{row} | {n['summary']}")
        out.append("")
    return "\n".join(out)


def build_router(notes, ntags):
    by_title = {n["title"]: n for n in notes}
    lines = ["# LihFolk Router (read this first)", "",
             "Generated by `_tools/build_index.py`. All paths are under `knowledge/`.", "",
             "1. Topic below? Use its notes. Else `Grep` `INDEX_SLIM.md` (`title | path | tags`) for the API/keyword.",
             "2. TL;DR only: `Grep pattern=\"tldr:start\" glob=\"**/<title>.md\" output_mode=content -A 10`.",
             "3. Still unsure? `Grep \"^## \" -n` in the note, Read just that section (offset/limit). Never whole notes.",
             "4. Cite titles. Disputes: `Open Questions - Whole Vault.md`. Section rules: `_maps/<section> - Map.md`.", "",
             "## Core topics: keywords -> section: best notes", ""]
    missing, covered = [], set()
    for kw, titles in CORE:
        ok = [t for t in titles if t in by_title]
        missing += [t for t in titles if t not in by_title]
        secs = sorted({by_title[t]["section"][:2] for t in ok})
        covered |= set(secs)
        lines.append(f"- {kw} -> {'/'.join(secs)}: " + "; ".join(ok))
    lines += ["", "## Other sections (top tags; * = has a `Start Here` hub)", ""]
    by_sec = defaultdict(list)
    for n in notes:
        by_sec[n["section"]].append(n)
    df = Counter()
    for sec, ns in by_sec.items():
        for t in {t.lower() for n in ns for t in n["tags"]}:
            df[t] += 1
    S = len(by_sec)
    sec_lines = []
    for sec in sorted(by_sec):
        tf = Counter(t.lower() for n in by_sec[sec] for t in n["tags"])
        name = set(re.findall(r"[a-z0-9]+", sec.lower()))
        name |= {w.rstrip("s") for w in name}
        # skip tags that repeat the section name or are used all over the vault (luau, strict, ...)
        fresh = [t for t in tf if not set(re.findall(r"[a-z0-9]+", t)) <= name and df[t] <= S * 0.3]
        score = sorted(fresh, key=lambda t: (-tf[t] * math.log((S + 1) / df[t]) ** 0.5, t))
        hub = next((n["title"] for n in by_sec[sec] if n["title"].endswith("Start Here")), "")
        sec_lines.append((sec, score, hub))
    body, cur = [], ""
    for sec, score, hub in sec_lines:
        if sec[:2] in covered:
            continue
        item = f"{sec}{'*' if hub else ''}" + (f" ({', '.join(score[:ntags])})" if score[:ntags] else "")
        if cur and len(cur) + len(item) > 110:
            body.append(cur + " ·")
            cur = ""
        cur = (cur + " · " if cur else "") + item
    text = "\n".join(lines + body + [cur, ""])
    if len(text.encode("utf-8")) > 6144:
        missing.append("(ROUTER.md is over 6 KB: shorten CORE keywords)")
    return text, missing


def build_map(sec, ns):
    out = [f"# {sec} - Map", "",
           f"One line per note in `{sec}`: title, then the first TL;DR bullet (or the first sentence).",
           "Generated by `_tools/build_index.py`; open a note's TL;DR block before reading it.", ""]
    for n in ns:
        out.append(f"- {n['title']}: {n['map']}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- measure
def section_text(text, heading):
    m = re.search(r"^## " + re.escape(heading) + r"\s*$", text, re.M)
    if not m:
        return ""
    nxt = re.search(r"^## ", text[m.end():], re.M)
    return text[m.start(): m.end() + (nxt.start() if nxt else len(text) - m.end())]


def mc_headings(text):
    fm, _ = parse_note(text)
    h2 = [x[1] for x in sections(text[fm.end():] if fm else text) if x[0] == 2]
    mh = next((h for h in h2 if re.search(r"(?i)mistakes", h)), None) or \
        next((h for h in h2 if MISTAKES_HEAD.search(h)), None)
    return [h for h in (mh, next((h for h in h2 if CHECK_HEAD.search(h)), None)) if h]


def measure(notes):
    """Old protocol: grep INDEX + Common mistakes + Checklist of 2 notes + one section.
    New protocol: ROUTER + grep INDEX_SLIM + TL;DR of 2 notes + the same section. Tokens ~ bytes / 4."""
    by_title = {n["title"]: n for n in notes}
    idx, slim, router = (read(os.path.join(KB, f)) for f in ("INDEX.md", "INDEX_SLIM.md", "ROUTER.md"))
    rb = len(router.encode())
    grep = lambda txt, rx: sum(len(l.encode()) + 1 for l in txt.split("\n") if re.search(rx, l, re.I) and l.startswith("- "))
    print(f"ROUTER.md = {rb:,} bytes (read once per session)\n")
    print("| Task | Old: index grep + M/C + section = bytes | New: slim grep + TL;DRs + section = bytes "
          "| Old tok | New tok (+router) | New tok (router already read) | Saved (+router / already read) |")
    print("|---|---|---|---:|---:|---:|---|")
    to = tn = tw = gs = mcs = tls = 0
    for task, rx, titles, heading in TASKS:
        g_old, g_new = grep(idx, rx), grep(slim, rx)
        mc = tl = 0
        for t in titles:
            text = by_title[t]["clean"]
            full = sum(len(section_text(text, h).encode()) for h in mc_headings(text))
            mc += full
            m = re.search(re.escape(START) + ".*?" + re.escape(END), by_title[t]["text"], re.S)
            tl += len(m.group(0).encode()) + 1 if m else full
        sec = max(len(section_text(by_title[t]["clean"], heading).encode()) for t in titles)
        o, w = g_old + mc + sec, g_new + tl + sec
        n = w + rb
        to, tn, tw = to + o, tn + n, tw + w
        gs, mcs, tls = gs + g_new, mcs + mc, tls + tl
        print(f"| {task} | {g_old:,} + {mc:,} + {sec:,} = {o:,} | {g_new:,} + {tl:,} + {sec:,} = {w:,} | {o // 4:,} "
              f"| {n // 4:,} | {w // 4:,} | {100 - 100 * n // o}% / {100 - 100 * w // o}% |")
    print(f"| **Total (8 tasks)** | {to:,} | {tw:,} | {to // 4:,} | {tn // 4:,} | {tw // 4:,} "
          f"| {100 - 100 * tn // to}% / {100 - 100 * tw // to}% |")
    print(f"\nSession of all 8 tasks, router read once: old {to // 4:,} tok, new {(tw + rb) // 4:,} tok "
          f"({100 - 100 * (tw + rb) // to}% saved).")
    hit = tw - gs + rb
    print(f"Same session when the router names the notes (all 8 are core topics, so no INDEX_SLIM grep): "
          f"new {hit // 4:,} tok ({100 - 100 * hit // to}% saved).")
    print(f"Notes part alone (Common mistakes + Checklist vs TL;DR, 16 notes): {mcs // 4:,} -> {tls // 4:,} tok "
          f"({100 - 100 * tls // mcs}% saved).")


# ---------------------------------------------------------------- main
def main():
    global CHECK
    args = sys.argv[1:]
    CHECK = "--check" in args
    skip_tldr = {args[i + 1] for i, a in enumerate(args) if a == "--no-tldr-in" and i + 1 < len(args)}
    notes = collect()
    changed, report = [], defaultdict(list)
    for n in notes:
        n["fm"], n["tags"] = parse_note(n["text"])
        block, kind = tldr_for(n)
        n["summary"] = summary_of(n["clean"])
        if block and n["section"] in skip_tldr:
            report["left untouched (--no-tldr-in)"].append(n["path"])
            n["map"] = n["summary"]
            continue
        if block:
            new = insert_tldr(n["clean"], block)
            report[kind].append(n["path"])
            n["map"] = block.split("\n")[2][4:]
            if new != n["text"]:
                write_if_changed(n["abs"], new, changed)
                n["text"] = new
        else:
            report["skipped: " + kind].append(n["path"])
            n["map"] = n["summary"]
            if n["clean"] != n["text"]:  # a stale block on a note that no longer qualifies
                write_if_changed(n["abs"], n["clean"], changed)
                n["text"] = n["clean"]
    if "--measure" in args:
        measure(notes)
        return
    write_if_changed(os.path.join(KB, "INDEX.md"), build_index(notes, False), changed)
    write_if_changed(os.path.join(KB, "INDEX_SLIM.md"), build_index(notes, True), changed)
    router, missing = build_router(notes, 2)
    write_if_changed(os.path.join(KB, "ROUTER.md"), router, changed)
    by_sec = defaultdict(list)
    for n in notes:
        by_sec[n["section"]].append(n)
    for sec, ns in sorted(by_sec.items()):
        write_if_changed(os.path.join(KB, "_maps", f"{sec} - Map.md"), build_map(sec, ns), changed)
    for k in sorted(report):
        print(f"{k}: {len(report[k])}")
    for t in missing:
        print("WARNING: router note not found:", t)
    for f in ("INDEX.md", "INDEX_SLIM.md", "ROUTER.md"):
        print(f"{f}: {os.path.getsize(os.path.join(KB, f)):,} bytes" if os.path.exists(os.path.join(KB, f)) else f)
    print(f"{'would change' if CHECK else 'changed'}: {len(changed)} files")
    if "-v" in args:
        for c in changed:
            print("  ", c)
    if CHECK and changed:
        sys.exit(1)


CHECK = False
if __name__ == "__main__":
    main()
