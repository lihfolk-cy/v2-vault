"""One-call search for LihFolk Vault V2: the best notes for a task, with their TL;DRs.

Usage (stdlib only, no network; paths are under LihFolk Vault V2/):
    python "LihFolk Vault V2/_tools/vault.py" "hit camera shake goes black"      # top 3 notes (compact) + matching symptoms
    python "LihFolk Vault V2/_tools/vault.py" --full "hit camera shake goes black"   # raw TL;DR blocks with paths and sizes
    python "LihFolk Vault V2/_tools/vault.py" -k 5 "datastore session lock"      # top 5
    python "LihFolk Vault V2/_tools/vault.py" --paths "slash vfx"                # titles and paths only (cheapest)
    python "LihFolk Vault V2/_tools/vault.py" --json "processreceipt"            # machine-readable
    python "LihFolk Vault V2/_tools/vault.py" --read "DataStore Fundamentals" "UpdateAsync"   # print one ## section
    python "LihFolk Vault V2/_tools/vault.py" --sections "DataStore Fundamentals"             # list its ## headings

Ranking is BM25F over title, tags, TL;DR, headings and body, plus links from SYMPTOMS.md, so a bug
described in everyday words ("screen goes black when I get hit") still finds the note. The index is
cached in _tools/.cache/ and rebuilt automatically when any note changes.

Default output is compact: each note's TL;DR bullets and section list without the callout header, cost
line or path, then matching symptom lines. --full prints the raw TL;DR blocks with paths and sizes;
--brief keeps only the first two TL;DR lines of notes #2 and #3 (cheapest, but can hide facts).
"""
import hashlib
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

KB = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # LihFolk Vault V2/
CACHE = os.path.join(KB, "_tools", ".cache", "search.json")
START, END = "<!-- tldr:start -->", "<!-- tldr:end -->"
SKIP_ROOT = {"INDEX.md", "INDEX_SLIM.md", "ROUTER.md", "SYMPTOMS.md", "LICENSE.md", "000 Home.md"}
FIELDS = {"title": 4.0, "tags": 2.5, "tldr": 2.0, "heads": 1.5, "body": 0.4, "sym": 2.0}  # sym = SYMPTOMS.md lines
K1, B = 1.2, 0.75
SYMPTOM_WEIGHT = 0.0  # extra boost from matched symptom lines; 0 = symptoms act only as the sym field
# Notes that should rank below a real explanation when both match: link lists, short glossary-style concept
# notes, hubs and visual references. (path prefix or title suffix, multiplier)
DAMP = [("46 Resource Library/", 0.5), ("57 API and Concept Atlas/", 0.5), ("52 Core Concepts/", 0.75), ("Start Here", 0.7),
        ("08 Animation/09 References/", 0.6), ("Skill - ", 0.8)]
STOP = set("""a an and are as at be but by can do does for from get got how i if in into is it its make
my me of on or so that the then there this to too up use using want way what when where which while
why will with without you your we our not no just also should would could any some all""".split())
# Small, general synonym map: everyday words -> vault vocabulary. Applied to the query only.
SYN = {
    "lag": ["performance", "fps"], "laggy": ["performance", "fps"], "stutter": ["performance", "hitch"],
    "fps": ["performance", "frame"], "slow": ["performance"], "crash": ["memory", "crash"],
    "save": ["datastore"], "saving": ["datastore"], "saves": ["datastore"], "data": ["datastore"],
    "progress": ["datastore"], "wipe": ["datastore", "reset"], "dupe": ["duplication", "exploit"],
    "buy": ["purchase"], "bought": ["purchase", "receipt"], "robux": ["purchase", "monetization"],
    "exploit": ["exploiter", "security"], "hack": ["exploit", "exploiter"], "cheat": ["exploit", "anticheat"],
    "gui": ["ui"], "ui": ["gui"], "menu": ["ui", "gui"], "button": ["ui", "button"], "hud": ["ui", "hud"],
    "phone": ["mobile"], "mobile": ["phone", "touch"], "controller": ["gamepad"], "xbox": ["gamepad", "console"],
    "sword": ["weapon", "blade", "tool"], "weapon": ["tool", "weapon"], "anim": ["animation"],
    "particles": ["particle", "vfx"], "effect": ["vfx"], "effects": ["vfx"], "sound": ["audio", "sound"],
    "music": ["audio", "sound"], "npc": ["npc", "humanoid", "enemy"], "enemy": ["npc", "enemy"],
    "map": ["level", "world"], "blender": ["blender", "export"], "model": ["mesh", "model"],
    "remote": ["remoteevent"], "remotes": ["remoteevent"], "server": ["server"], "lobby": ["hub", "lobby"],
    "shop": ["shop", "store"], "pets": ["pet"], "eggs": ["egg", "hatch"], "leaderboard": ["leaderboard", "ordereddatastore"],
}


def stem(w):
    for suf, rep in (("ies", "y"), ("ing", ""), ("ed", ""), ("es", ""), ("s", "")):
        if len(w) > len(suf) + 3 and w.endswith(suf):
            return w[: -len(suf)] + rep
    return w


def tokens(s):
    out = []
    for word in re.findall(r"[A-Za-z][A-Za-z0-9]*|\d+", s):
        low = word.lower()
        if low in STOP or len(low) < 2:
            continue
        out.append(stem(low))
        parts = re.findall(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+", word)
        if len(parts) > 1:  # CamelCase: UpdateAsync -> updateasync + update + async
            out += [stem(p.lower()) for p in parts if p.lower() not in STOP and len(p) > 1]
    return out


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def note_files():
    files = []
    for root, dirs, fs in os.walk(KB):
        dirs[:] = sorted(d for d in dirs if not d.startswith((".", "_")))
        rel = os.path.relpath(root, KB)
        for f in sorted(fs):
            if f.endswith(".md") and not (rel == "." and f in SKIP_ROOT):
                files.append(os.path.join(root, f))
    return files


def parse(path):
    text = read(path)
    fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    tags = re.search(r"^tags:\s*\[(.*?)\]", fm.group(1), re.M) if fm else None
    tags = [t.strip().strip("'\"") for t in tags.group(1).split(",")] if tags else []
    body = text[fm.end():] if fm else text
    m = re.search(re.escape(START) + r"\n(.*?)" + re.escape(END), body, re.S)
    tldr = m.group(1).strip() if m else ""
    if m:
        body = body[: m.start()] + body[m.end():]
    # generated "## Related" blocks (link_builder.py) are navigation, not content
    body = re.sub(r"<!-- related:start -->.*?<!-- related:end -->", "", body, flags=re.S)
    heads = re.findall(r"^#{1,4} +(.+)$", body, re.M)
    plain = re.sub(r"```.*?```", lambda c: c.group(0)[:600], body, flags=re.S)  # code counts, but capped
    title = os.path.basename(path)[:-3]
    rel = os.path.relpath(path, KB).replace(os.sep, "/")
    summary = ""
    if not tldr:
        for para in re.split(r"\n\s*\n", body):
            p = para.strip()
            if p and not p.startswith(("#", "|", "!", "<!--", ">", "-", "```")):
                summary = " ".join(p.split())[:300]
                break
    return {"title": title, "path": rel, "tags": tags, "tldr": tldr, "summary": summary,
            "f": {"title": tokens(title), "tags": tokens(" ".join(tags)), "tldr": tokens(tldr),
                  "heads": tokens(" ".join(heads)), "body": tokens(plain)},
            "kb": round(len(text.encode("utf-8")) / 1024)}


def parse_symptoms():
    path = os.path.join(KB, "SYMPTOMS.md")
    if not os.path.exists(path):
        return []
    out, area = [], ""
    for line in read(path).split("\n"):
        if line.startswith("## "):
            area = line[3:].strip()
        if not line.startswith("- ") or line.count(" | ") < 3:
            continue
        parts = line[2:].split(" | ")
        links = re.findall(r"\[\[([^\]|]+)", parts[-1])
        if links:
            out.append({"line": line[2:], "area": area, "links": links,
                        "toks": tokens(" ".join(parts[:-1]) + " " + area)})
    return out


def signature(files):
    h = hashlib.sha1()
    for p in files + [os.path.join(KB, "SYMPTOMS.md"), os.path.abspath(__file__)]:
        if os.path.exists(p):
            st = os.stat(p)
            h.update(f"{p}|{st.st_mtime_ns}|{st.st_size}".encode())
    return h.hexdigest()


def load_index():
    files = note_files()
    sig = signature(files)
    if os.path.exists(CACHE):
        try:
            idx = json.loads(read(CACHE))
            if idx.get("sig") == sig:
                return idx
        except (OSError, ValueError):
            pass
    docs = [parse(p) for p in files]
    for d in docs:  # store term counts, not token lists
        d["tf"] = {f: Counter(t) for f, t in d.pop("f").items()}
        d["len"] = {f: sum(c.values()) for f, c in d["tf"].items()}
    symptoms = parse_symptoms()
    by_title = {d["title"]: d for d in docs}
    for d in docs:
        d["tf"]["sym"], d["len"]["sym"] = Counter(), 0
    for s in symptoms:  # a symptom line is extra searchable text on the notes it links to
        for t in s["links"]:
            if t in by_title:
                by_title[t]["tf"]["sym"].update(s["toks"])
                by_title[t]["len"]["sym"] += len(s["toks"])
    idx = {"sig": sig, "docs": docs, "symptoms": symptoms}
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w", encoding="utf-8") as f:
            json.dump(idx, f)
    except OSError:
        pass
    return idx


def bm25f(query_terms, docs):
    n = len(docs)
    avg = {f: sum(d["len"][f] for d in docs) / n or 1 for f in FIELDS}
    df = Counter()
    for d in docs:
        for t in {t for f in FIELDS for t in d["tf"][f]}:
            df[t] += 1
    scores = []
    for d in docs:
        s = 0.0
        for t, qw in query_terms.items():
            if not df[t]:
                continue
            tf = sum(w * d["tf"][f].get(t, 0) / (1 - B + B * d["len"][f] / avg[f]) for f, w in FIELDS.items())
            if tf:
                s += qw * math.log(1 + (n - df[t] + 0.5) / (df[t] + 0.5)) * tf / (K1 + tf)
        scores.append(s)
    return scores


def query_terms(q):
    base = tokens(q)
    terms = Counter(base)
    for w in re.findall(r"[a-z]+", q.lower()):
        for s in SYN.get(w, []):
            terms[stem(s)] += 0.4
    return terms


def search(q, k=3, idx=None):
    idx = idx or load_index()
    docs, terms = idx["docs"], query_terms(q)
    scores = bm25f(terms, docs)
    by_title = {d["title"]: i for i, d in enumerate(docs)}
    hits = []
    if idx["symptoms"]:
        sdf = Counter(t for s in idx["symptoms"] for t in set(s["toks"]))
        ns = len(idx["symptoms"])
        avg = sum(len(s["toks"]) for s in idx["symptoms"]) / ns
        for s in idx["symptoms"]:
            c = Counter(s["toks"])
            sc = sum(qw * math.log(1 + (ns - sdf[t] + 0.5) / (sdf[t] + 0.5)) * c[t] * (K1 + 1)
                     / (c[t] + K1 * (1 - B + B * len(s["toks"]) / avg)) for t, qw in terms.items() if t in c)
            if sc > 0:
                hits.append((sc, s))
        hits.sort(key=lambda x: -x[0])
        top = hits[0][0] if hits else 0
        for sc, s in hits[:8]:
            for t in s["links"]:
                if t in by_title and sc >= 0.5 * top:
                    scores[by_title[t]] += SYMPTOM_WEIGHT * sc
    for i, d in enumerate(docs):
        for prefix, mult in DAMP:
            if d["path"].startswith(prefix) or d["title"].endswith(prefix):
                scores[i] *= mult
    order = sorted(range(len(docs)), key=lambda i: -scores[i])[:k]
    best = hits[0][0] if hits else 0
    return [(scores[i], docs[i]) for i in order if scores[i] > 0], [s for sc, s in hits[:3] if sc >= 0.6 * best]


def find_note(title, idx):
    for d in idx["docs"]:
        if d["title"].lower() == title.lower():
            return d
    cands = [d for d in idx["docs"] if title.lower() in d["title"].lower()]
    return cands[0] if len(cands) == 1 else None


def print_section(title, heading, idx):
    d = find_note(title, idx)
    if not d:
        sys.exit(f"note not found (or ambiguous): {title}")
    text = read(os.path.join(KB, d["path"]))
    heads = [(m.start(), len(m.group(1)), m.group(2).strip()) for m in re.finditer(r"^(#{2,3}) +(.+)$", text, re.M)]
    if heading is None:
        print(f"{d['title']} ({d['path']}, {d['kb']} KB)")
        for _, lvl, h in heads:
            print("  " * (lvl - 1) + "#" * lvl + " " + h)
        return
    hit = [h for h in heads if heading.lower() in h[2].lower()]
    if not hit:
        sys.exit(f"no heading containing '{heading}' in {d['title']}; use --sections")
    pos, level, _ = hit[0]
    nxt = re.compile(r"^#{2,%d} " % level, re.M).search(text, pos + 1)
    print(text[pos: nxt.start() if nxt else len(text)].rstrip())


def tldr_parts(d):
    """TL;DR bullets and the 'Read more' section list, without the callout header and cost boilerplate."""
    if not d["tldr"]:
        return ([d["summary"]] if d["summary"] else []), ""
    bullets, more = [], ""
    for line in d["tldr"].split("\n"):
        line = line.lstrip(">").strip()
        if not line or line.startswith("[!tldr]"):
            continue
        if line.startswith("Cost:"):
            m = re.search(r"Read more:\s*(.*)", line)
            more = m.group(1).replace("## ", "").strip() if m else ""
            continue
        bullets.append(line if line.startswith("- ") else "- " + line)
    return bullets, more


def main():
    try:  # Windows consoles default to cp1252, and notes contain arrows and dashes
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return
    idx = load_index()
    if args[0] == "--read":
        print_section(args[1], args[2] if len(args) > 2 else None, idx)
        return
    if args[0] == "--sections":
        print_section(args[1], None, idx)
        return
    k, mode, words = 3, "compact", []
    it = iter(args)
    for a in it:
        if a == "-k":
            k = int(next(it))
        elif a in ("--paths", "--json", "--full", "--brief"):
            mode = a[2:]
        else:
            words.append(a)
    results, symptoms = search(" ".join(words), k, idx)
    if mode == "json":
        print(json.dumps({"results": [{"title": d["title"], "path": d["path"], "score": round(s, 2),
                                       "tldr": d["tldr"] or d["summary"]} for s, d in results],
                          "symptoms": [s["line"] for s in symptoms]}, indent=1))
        return
    if not results:
        print("no match; try other words or grep LihFolk Vault V2/INDEX_SLIM.md")
        return
    if mode == "paths":
        for s, d in results:
            print(f"{d['title']} | {d['path']}")
        return
    if mode == "full":
        for s, d in results:
            print(f"## {d['title']}  ({d['path']}, {d['kb']} KB)")
            print(d["tldr"] or ("> " + d["summary"] if d["summary"] else "> (no summary)"))
            print()
        if symptoms:
            print("Symptom matches (symptom | cause | fix | note):")
            for s in symptoms:
                print("- " + s["line"])
            print()
        print('Next: python "LihFolk Vault V2/_tools/vault.py" --read "<title>" "<heading words>"  (one section only)')
        return
    for rank, (s, d) in enumerate(results, 1):
        bullets, more = tldr_parts(d)
        print(f"{rank}. {d['title']}")
        brief = mode == "brief" and rank > 1
        print("\n".join(bullets[:2] if brief else bullets))
        if more and not brief:
            print("Sections: " + more)
    if symptoms:
        print("Symptoms (symptom | cause | fix | note):")
        for s in symptoms:
            print("- " + s["line"])


if __name__ == "__main__":
    main()
