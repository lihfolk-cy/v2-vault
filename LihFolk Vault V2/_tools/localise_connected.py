"""Make each note's "## Connected notes" block mostly section-local so the graph forms per-section galaxies.

Same-section [[links]] stay links; the first cross-section link stays a link (a "bridge"); other cross-section
links become plain text (the title stays readable, the graph edge goes). Idempotent. Usage:
    python "LihFolk Vault V2/_tools/localise_connected.py" [--dry-run]
"""
import os, re, sys

KB = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY = "--dry-run" in sys.argv
LINK = re.compile(r"\[\[([^\]|#]+)(#[^\]|]*)?(\|[^\]]*)?\]\]")


def section_of(rel):
    first = rel.replace(os.sep, "/").split("/")[0]
    return first if re.match(r"^\d\d ", first) else "_root"


titles = {}
for dp, dns, fns in os.walk(KB):
    dns[:] = [d for d in dns if not d.startswith((".", "_"))]
    for f in fns:
        if f.endswith(".md"):
            titles.setdefault(f[:-3], section_of(os.path.relpath(os.path.join(dp, f), KB)))

changed = kept = unlinked = 0
for dp, dns, fns in os.walk(KB):
    dns[:] = [d for d in dns if not d.startswith((".", "_"))]
    for f in fns:
        if not f.endswith(".md"):
            continue
        path = os.path.join(dp, f)
        sec = section_of(os.path.relpath(path, KB))
        text = open(path, encoding="utf-8").read()
        m = re.search(r"(?m)^## Connected notes[^\n]*\n", text)
        if not m:
            continue
        start = m.end()
        nxt = re.search(r"(?m)^(## |<!-- related:start)", text[start:])
        end = start + nxt.start() if nxt else len(text)
        block = text[start:end]
        bridge_used = False

        def fix(mm):
            global kept, unlinked
            nonlocal_bridge = fix.bridge
            target = mm.group(1).strip()
            alias = (mm.group(3) or "")[1:]
            tsec = titles.get(target)
            if tsec is None or tsec == sec:
                kept += 1
                return mm.group(0)
            if not fix.bridge:
                fix.bridge = True
                kept += 1
                return mm.group(0)
            unlinked += 1
            return alias or target

        fix.bridge = False
        new_block = LINK.sub(fix, block)
        if new_block != block:
            changed += 1
            if not DRY:
                open(path, "w", encoding="utf-8", newline="").write(text[:start] + new_block + text[end:])
print(f"notes changed {changed}; links kept {kept}; cross links unlinked {unlinked}{' (dry run)' if DRY else ''}")
