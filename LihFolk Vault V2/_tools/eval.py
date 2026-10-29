"""Score vault.py search on the hand-written retrieval test set (eval/tasks.jsonl).

Usage:
    python "LihFolk Vault V2/_tools/eval.py"                 # dev + test scores, plus a title/tags-only baseline
    python "LihFolk Vault V2/_tools/eval.py" --misses dev    # list the dev tasks whose answer is not in the top 3
    python "LihFolk Vault V2/_tools/eval.py" --min-hit3 0.8  # exit 1 if test hit@3 drops below 0.8 (CI)

Each task lists 1-3 acceptable notes, chosen by reading the notes (not by running the search). The "dev" split
may be used to tune the search; "test" must not be, so its score is the honest one.
Tokens = bytes / 4 of what an agent actually reads: the default vault.py output (top 3 TL;DRs + symptom lines).
"""
import io
import json
import os
import sys
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vault  # noqa: E402

TASKS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "eval", "tasks.jsonl")


def run(tasks, idx, fields=None):
    saved = dict(vault.FIELDS)
    if fields:
        vault.FIELDS.clear()
        vault.FIELDS.update(fields)
    syms = idx["symptoms"]
    if fields:
        idx = dict(idx, symptoms=[])
    rows = []
    for t in tasks:
        res, _ = vault.search(t["task"], 3, idx)
        titles = [d["title"] for _, d in res]
        rank = next((i + 1 for i, x in enumerate(titles) if x in t["expected"]), 0)
        rows.append((t, titles, rank))
    vault.FIELDS.clear()
    vault.FIELDS.update(saved)
    idx["symptoms"] = syms
    return rows


def score(rows):
    n = len(rows) or 1
    return (sum(r[2] == 1 for r in rows) / n, sum(r[2] > 0 for r in rows) / n,
            sum(1 / r[2] for r in rows if r[2]) / n)


def tokens(tasks):
    total = 0
    for t in tasks:
        buf = io.StringIO()
        sys.argv = ["vault.py", t["task"]]
        with redirect_stdout(buf):
            vault.main()
        total += len(buf.getvalue().encode("utf-8"))
    return total / 4 / max(1, len(tasks))


def main():
    args = sys.argv[1:]
    tasks = [json.loads(l) for l in open(TASKS, encoding="utf-8") if l.strip()]
    idx = vault.load_index()
    print("| Split | Tasks | hit@1 | hit@3 | MRR@3 | Baseline hit@3 (title + tags only, like grepping INDEX_SLIM) |")
    print("|---|---:|---:|---:|---:|---:|")
    result = {}
    for split in ("dev", "test"):
        ts = [t for t in tasks if t["split"] == split]
        rows = run(ts, idx)
        base = run(ts, idx, {"title": 4.0, "tags": 2.5})
        h1, h3, mrr = score(rows)
        result[split] = (rows, h3)
        print(f"| {split} | {len(ts)} | {h1:.0%} | {h3:.0%} | {mrr:.2f} | {score(base)[1]:.0%} |")
    print(f"\nAverage tokens an agent reads per task (default output): {tokens(tasks):,.0f}")
    if "--misses" in args:
        split = args[args.index("--misses") + 1]
        for t, titles, rank in result[split][0]:
            if not rank:
                print(f"\n{t['id']}: {t['task']}\n  expected: {t['expected']}\n  got:      {titles}")
    if "--min-hit3" in args and result["test"][1] < float(args[args.index("--min-hit3") + 1]):
        sys.exit(1)


if __name__ == "__main__":
    main()
