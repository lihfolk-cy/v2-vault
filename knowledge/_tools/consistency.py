"""Find notes that disagree with each other on a number, and notes whose facts are getting old.

Usage (stdlib only):
    python knowledge/_tools/consistency.py                 # report to stdout and _tools/reports/consistency.md
    python knowledge/_tools/consistency.py --strict        # exit 1 on any contradiction (CI)
    python knowledge/_tools/consistency.py --max-age 12    # flag "as of <month year>" stamps older than 12 months

Contradictions: each FACT is a platform number many notes repeat (DataStore value size, default WalkSpeed, ...).
Every mention is captured and compared with the agreed value; a different number is a contradiction unless the
sentence shows it is a different thing (the `unless` pattern). Add a FACT whenever two notes are found to disagree.
Freshness: notes carry "(as of October 2026)"-style stamps; old stamps mean the claim should be re-checked.
"""
import datetime
import os
import re
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
KB = os.path.dirname(TOOLS)
REPORT = os.path.join(TOOLS, "reports", "consistency.md")
SKIP_ROOT = {"INDEX.md", "INDEX_SLIM.md", "ROUTER.md", "LICENSE.md"}

# (fact, regex with one number group, agreed values, "unless" regex on the same sentence, where it is documented)
FACTS = [
    ("DataStore max value size", r"(?i)datastore[^.|\n]{0,60}?\b(\d+(?:\.\d+)?) ?MB", {"4"}, None,
     "DataStore Fundamentals"),
    ("Default Humanoid.WalkSpeed", r"(?i)default[^.|\n]{0,30}walk ?speed[^.|\n]{0,12}?\b(\d+)\b|walk ?speed`? (?:defaults? to|of|is) (\d+)",
     {"16"}, r"(?i)sprint|run speed|set|custom|pixel", "Characters and Humanoids"),
    ("Default Humanoid.JumpPower", r"(?i)jump ?power`?(?: defaults? to| default(?: of)?| of|:)? (\d+(?:\.\d+)?)\b",
     {"50"}, r"(?i)set|custom|higher|lower|=", "Characters and Humanoids"),
    ("Default Workspace.Gravity", r"(?i)gravity`?[^.|\n]{0,25}?\b(19\d(?:\.\d+)?)\b", {"196.2"}, None,
     "Physics Assemblies and Constraints"),
    ("HttpService request budget per server", r"(?i)(?:httpservice|http requests?)[^.|\n]{0,60}?\b(\d[\d,]*) (?:http )?requests? (?:per|a|/) ?min",
     {"500"}, r"(?i)backend|servers|TextGenerator|Open Cloud|API key", "HttpService and External APIs"),
    ("MemoryStore item size", r"(?i)memorystore[^.|\n]{0,60}?\b(\d+) ?KB", {"32"}, r"(?i)\bMB\b|quota", "MemoryStore"),
    ("DataStore key name length", r"(?i)key\b[^.|\n]{0,30}?\b(\d+) characters", {"50"}, None,
     "DataStore Fundamentals"),
    # Text stroke size: 8-15% is the general guide, but rounded heavy fonts fill their counters above ~7%.
    ("UIStroke on text: ratio guidance mentions the rounded-font limit",
     r"(?i)stroke[^.|\n]{0,60}?\b(8|10|11|12) (?:to \d+ ?)?%", {"__needs_context__"},
     r"(?i)7 ?%|counters|rounded|Glyph Counters", "UIStroke on Text - Glyph Counters and the Stroke Ratio"),
]
STAMP = re.compile(r"(?i)\b(?:as of|checked|verified)(?: in)?(?: \d{1,2})? (January|February|March|April|May|June|July|"
                   r"August|September|October|November|December) (20\d\d)")
MONTHS = {m: i + 1 for i, m in enumerate(["january", "february", "march", "april", "may", "june", "july", "august",
                                           "september", "october", "november", "december"])}


def notes():
    for root, dirs, fs in os.walk(KB):
        dirs[:] = sorted(d for d in dirs if not d.startswith((".", "_")))
        for f in sorted(fs):
            if f.endswith(".md") and not (root == KB and f in SKIP_ROOT):
                p = os.path.join(root, f)
                yield os.path.relpath(p, KB).replace(os.sep, "/"), open(p, encoding="utf-8").read()


def sentence(text, pos):
    a = max(text.rfind(". ", 0, pos), text.rfind("\n", 0, pos), text.rfind("|", 0, pos)) + 1
    ends = [i for i in (text.find(". ", pos), text.find("\n", pos), text.find("|", pos)) if i != -1]
    return text[a: min(ends) if ends else len(text)].strip()


def main():
    args = sys.argv[1:]
    max_age = int(args[args.index("--max-age") + 1]) if "--max-age" in args else 12
    today = datetime.date.today()
    conflicts, stale, seen = [], [], {}
    for rel, text in notes():
        body = re.sub(r"<!-- tldr:start -->.*?<!-- tldr:end -->", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)
        for name, rx, ok, unless, home in FACTS:
            for m in re.finditer(rx, body):
                val = next(g for g in m.groups() if g is not None).replace(",", "")
                sent = sentence(body, m.start())
                seen.setdefault(name, {}).setdefault(val, set()).add(rel)
                if val in ok or unless and re.search(unless, sent + body[m.end(): m.end() + 250]):  # this or the next sentence
                    continue
                if home in rel and "__needs_context__" not in ok:
                    continue
                line = body.count("\n", 0, m.start()) + 1
                conflicts.append((name, rel, line, val, sent[:160]))
        for m in STAMP.finditer(body):
            y, mo = int(m.group(2)), MONTHS[m.group(1).lower()]
            age = (today.year - y) * 12 + today.month - mo
            if age > max_age:
                stale.append((rel, body.count("\n", 0, m.start()) + 1, m.group(0), age))
    out = ["# Consistency report", "",
           f"Generated by `_tools/consistency.py` on {today}: {len(FACTS)} tracked facts, {len(conflicts)} "
           f"contradictions, {len(stale)} stamps older than {max_age} months.", "",
           "## Tracked facts (value: notes stating it)", ""]
    for name, *_ in FACTS:
        vals = seen.get(name, {})
        out.append(f"- **{name}**: " + ("; ".join(f"{v} ({len(ns)} notes)" for v, ns in sorted(vals.items()))
                                        or "no mentions"))
    out += ["", "## Contradictions", "", "| Fact | Note | Line | Value | Sentence |", "|---|---|---:|---|---|"]
    out += [f"| {n} | {r} | {l} | {v} | {s.replace('|', '/')} |" for n, r, l, v, s in conflicts]
    out += ["", "## Stale stamps", "", "| Note | Line | Stamp | Months old |", "|---|---:|---|---:|"]
    out += [f"| {r} | {l} | {s} | {a} |" for r, l, s, a in stale]
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(out[2])
    for n, r, l, v, s in conflicts:
        print(f"  {n}: {r}:{l} says {v}: {s[:120]}")
    if "--strict" in args and conflicts:
        sys.exit(1)


if __name__ == "__main__":
    main()
