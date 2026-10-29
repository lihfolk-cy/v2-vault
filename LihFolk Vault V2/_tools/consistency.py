"""Find notes that disagree with each other on a number, and notes whose facts are getting old.

Usage (stdlib only):
    python "LihFolk Vault V2/_tools/consistency.py"                 # report to stdout and _tools/reports/consistency.md
    python "LihFolk Vault V2/_tools/consistency.py" --strict        # exit 1 on any contradiction (CI)
    python "LihFolk Vault V2/_tools/consistency.py" --max-age 12    # flag "as of <month year>" stamps older than 12 months

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
    ("DataStore key name length", r"(?i)key\b[^.|\n]{0,30}?(?<![\d,.])\b(\d+) characters", {"50"}, None,
     "DataStore Fundamentals"),
    # Text stroke size: 8-15% is the general guide, but rounded heavy fonts fill their counters above ~7%.
    ("UIStroke on text: ratio guidance mentions the rounded-font limit",
     r"(?i)stroke[^.|\n]{0,60}?\b(8|10|11|12) (?:to \d+ ?)?%", {"__needs_context__"},
     r"(?i)7 ?%|counters|rounded|Glyph Counters", "UIStroke on Text - Glyph Counters and the Stroke Ratio"),
    # From the Engine Limits cheat sheet and the 62 Engine Reference Cards (verified against Creator Hub docs 2026-10-29).
    ("Default Humanoid.JumpHeight", r"(?i)jump ?height`?(?: defaults? to| default(?: of)?| of| is|:)? (\d+(?:\.\d+)?)\b",
     {"7.2"}, r"(?i)set|custom|higher|lower|=", "Characters and Humanoids"),
    ("Default Players.RespawnTime", r"(?i)respawn ?time`?(?:,? which)?(?: defaults? to| default(?: of|:)?| of| is|:| \|| ?\()? ?(\d+(?:\.\d+)?) ?(?:s\b|sec)",
     {"5", "5.0"}, r"(?i)set|custom|shorter|longer|=", "Players - Engine Reference Card"),
    ("Humanoid:MoveTo timeout", r"(?i)MoveTo[^.|\n]{0,60}?(?:times? ?out|timeout)[^.|\n]{0,25}?\b(\d+)(?: ?s\b| ?sec|-second)",
     {"8"}, None, "Humanoid - Engine Reference Card"),
    ("Max collision groups per world",
     r"(?i)(?:max(?:imum)?|up to|limit(?: of)?|cap(?: of)?)[^.|\n]{0,15}?\b(\d+) collision groups"
     r"|collision groups?[^.|\n]{0,30}?(?:max(?:imum)?|limit|cap(?:ped)?|up to)[^.|\n]{0,10}?\b(\d+)\b(?! ?char)"
     r"|collision groups?[^.|\n]{0,60}?\b(\d+) per world|collision groups (\d+)\b",
     {"32"}, None, "PhysicsService - Engine Reference Card"),
    ("Raycast max length", r"(?i)(?:\bray(?:cast)?s?\b|direction)[^.|\n]{0,60}?(?:max(?:imum)?|at most|up to|limit(?:ed)?|longer than|cap(?:ped)?)"
     r"[^.|\n]{0,20}?\b(\d{1,3}(?:,\d{3})+|\d{4,6}) studs"
     r"|max(?:imum)? ray(?:cast)? (?:length|distance)[^.|\n]{0,10}?\b(\d{1,3}(?:,\d{3})+|\d{4,6}) studs", {"15000"}, None, "Workspace - Engine Reference Card"),
    # 1 kB in the engine docs; the Open Cloud messaging guide says "1,024 characters (1 KiB)".
    ("MessagingService message size", r"(?i)messaging(?: ?service)?[^.|\n]{0,80}?\b(\d+(?:\.\d+)?) ?[kK]i?B\b"
     r"|messages? (?:size )?(?:up to |of |is |:)?(\d[\d,]*) char", {"1", "1024"},
     r"(?i)\bMB\b", "Cross-Server Messaging"),
    ("MessagingService topic name length", r"(?i)topic(?: name)?s?[^.|\n]{0,30}?\b(\d+) char", {"80"}, None,
     "MessagingService - Engine Reference Card"),
    ("UnreliableRemoteEvent payload limit", r"(?i)unreliable[^.|\n]{0,80}?\b(\d[\d,]*) ?(?:bytes|B\b)"
     r"|unreliable[^.|\n]{0,80}?\b(\d+) ?KB\b", {"1000", "900", "1"}, None, "RemoteEvents RemoteFunctions and Unreliable Remotes"),
    ("MemoryStore max expiration", r"(?i)(?:memory ?store|sorted map|hash map|queue)[^.|\n]{0,80}?(?:expir\w*|ttl)[^.|\n]{0,30}?\b(\d+) days"
     r"|(?:expir\w*|ttl)[^.|\n]{0,30}?(?:max(?:imum)?|at most|up to)[^.|\n]{0,25}?\b(\d+) days",
     {"45"}, None, "MemoryStore"),
    ("MemoryStore key length", r"(?i)(?:memory ?store|sorted map|hash map)[^.|\n]{0,60}?keys?[^.|\n]{0,20}?\b(\d+) char",
     {"128"}, None, "MemoryStore"),
    ("DataStore name/scope length", r"(?i)(?:data ?store|scope) ?names?[^.|\n]{0,30}?\b(\d+) char|scopes?[^.|\n]{0,20}?\b(\d+) char",
     {"50"}, None, "DataStore Fundamentals"),
    ("DataStore GetAsync cache time", r"(?i)(?:GetAsync|data ?store)[^.|\n]{0,40}?cache[^.|\n]{0,30}?\b(\d+) ?(?:s\b|sec)",
     {"4"}, None, "DataStore Fundamentals"),
    ("Instance.Name length", r"(?i)(?:Instance\.Name|instance names?)`?[^.|\n]{0,30}?\b(\d+) char", {"100"}, None,
     "Instance - Engine Reference Card"),
    ("Attribute name length", r"(?i)attribute names?[^.|\n]{0,30}?\b(\d+) char", {"100"},
     r"(?i)playing tracks|attributes per instance",  # Server Authority's own replicated-attribute limits
     "Instance - Engine Reference Card"),
    ("ParticleEmitter rate cap",
     r"(?i)(?:particle|emitter)[^.|\n]{0,50}?(?:cap(?:ped|s)?|max(?:imum)?|limit|up to|at most)[^.|\n]{0,20}?\b(\d+) (?:particles ?)?(?:per second|/s|particles/s)"
     r"|\bRate cap\W{0,6}(\d+) (?:particles ?)?(?:per second|/s) per emitter",
     {"400", "100"}, None, "ParticleEmitter - Engine Reference Card"),
    ("Particle lifetime cap", r"(?i)lifetime[^.|\n]{0,30}?(?:caps?|capped|max(?:imum)?|clamped|limit)[^.|\n]{0,20}?\b(\d+)\b",
     {"20"}, None, "ParticleEmitter - Engine Reference Card"),
    ("FlipbookFramerate max", r"(?i)flipbook ?frame ?rate`?[^.|\n]{0,30}?(?:max(?:imum|es out)?|cap(?:ped|s)?|up to|at most|limit)[^.|\n]{0,15}?\b(\d+)",
     {"30"}, None, "ParticleEmitter - Engine Reference Card"),
    ("Mesh triangle limit", r"(?i)(?:mesh|triangle|tri)[^.|\n]{0,40}?(?:limit|max(?:imum)?|cap|ceiling|at most|hard)[^.|\n]{0,20}?"
     r"\b(\d{1,3}(?:,\d{3})+|\d{4,6}|\d+k) (?:tris\b|triangles|polys|polygons)", {"20000", "20k", "20K"},
     r"(?i)budget|aim|target|keep|LOD|per (?:character|prop|model|asset)|scene|total|generat|measured|cage|layered|clothing",
     "Parts Unions and MeshParts"),
    ("Place file size limit", r"(?i)place (?:file )?size[^.|\n]{0,30}?\b(\d+) ?MB", {"100"}, None,
     "Engine Limits, Quotas and Defaults - Cheat Sheet"),
    ("Default StreamingMinRadius", r"(?i)StreamingMinRadius`?(?: defaults?(?: to| of| is)?:?| default:?| is| of)? (\d+)",
     {"64"}, r"(?i)set|=|rais|lower|custom|increase|decrease|chosen|recommend|\buse\b|\btry\b", "Instance Streaming"),
    ("Default StreamingTargetRadius", r"(?i)StreamingTargetRadius`?(?: defaults?(?: to| of| is)?:?| default:?| is| of)? (\d+)",
     {"1024"}, r"(?i)set|=|rais|lower|custom|increase|decrease|chosen|recommend|\buse\b|\btry\b", "Instance Streaming"),
    ("Default Camera.FieldOfView",
     r"(?i)(?:FieldOfView|\bFOV)`?[^.|\n]{0,20}?default[^.|\n]{0,10}?\b(\d+)|default (?:FieldOfView|FOV)`?[^.|\n]{0,10}?\b(\d+)",
     {"70"}, None, "Camera - Engine Reference Card"),
    ("Default TweenInfo EasingStyle",
     r"(?i)(?:defaults?|TweenInfo\.new\(\))[^.|\n]{0,30}?(?:EasingStyle|easing style)`?(?:\.| is| of|:)? ?`?(?:Enum\.EasingStyle\.)?"
     r"(Linear|Quad|Sine|Cubic|Quart|Quint|Exponential|Back|Bounce|Elastic|Circular)\b",
     {"Quad"}, None, "TweenService - Engine Reference Card"),
    ("Players per TeleportAsync call", r"(?i)TeleportAsync[^.|\n]{0,60}?\b(\d+) players|(\d+) players per `?TeleportAsync",
     {"50"}, None, "TeleportService - Engine Reference Card"),
    ("TextChat SendAsync metadata length", r"(?i)(?:SendAsync|TextChat\w*|chat)[^.|\n]{0,40}?metadata[^.|\n]{0,30}?\b(\d+) char",
     {"200"}, None, "TextChatService - Engine Reference Card"),
    ("BanAsync DisplayReason length", r"(?i)DisplayReason`?[^.|\n/]{0,20}?\b(\d[\d,]*) char", {"400"}, None,
     "Players - Engine Reference Card"),
    ("BanAsync PrivateReason length", r"(?i)PrivateReason`?[^.|\n/]{0,20}?\b(\d[\d,]*) char", {"1000"}, None,
     "Players - Engine Reference Card"),
    ("WaitForChild infinite-yield warning delay", r"(?i)(?:infinite[- ]yield|WaitForChild)[^.|\n]{0,60}?\bafter (\d+) ?(?:s\b|sec)",
     {"5"}, None, "Instance - Engine Reference Card"),
    ("Default animation fade time", r"(?i)fade ?time[^.|\n]{0,20}?(?:defaults?|default of|is)[^.|\n]{0,15}?\b(\d+(?:\.\d+)?) ?(?:s\b|sec)"
     r"|default fade(?: time)?(?: of| is)? (\d+(?:\.\d+)?)", {"0.1"}, None, "Animator - Engine Reference Card"),
    ("Default health regeneration rate", r"(?i)regen\w*[^.|\n]{0,40}?\b(\d+(?:\.\d+)?) ?% of `?MaxHealth", {"1"}, None,
     "Humanoid - Engine Reference Card"),
    ("Default Sound.Volume", r"(?i)(?:Sound\.|(?<![\w.]))Volume`?(?: defaults?(?: to| of| is)?| default:?) (\d+(?:\.\d+)?)"
     r"|default (?:Sound\.)?Volume`?(?: of| is)? (\d+(?:\.\d+)?)", {"0.5"}, None, "SoundService - Engine Reference Card"),
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
