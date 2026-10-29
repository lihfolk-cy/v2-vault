"""Benchmark v2: blind multi-arm grading files + aggregation with bootstrap CIs and inter-rater agreement.

  py -I v2_aggregate.py blind      -> runs/v2/blind_<set>.json (arms x reps shuffled per task, labels R1..Rn) + _key
  py -I v2_aggregate.py report     -> RESULTS_v2.md from runs/v2/grade_<set>_<g>.json
Arms are answer files runs/v2/<arm>_r<rep>_<set>.json  ({"<id>": "<answer>"}); timing/tokens in runs/v2/usage.json.
"""
import json, os, random, statistics as st, sys, glob, itertools

B = os.path.dirname(os.path.abspath(__file__))
R = os.path.join(B, "runs", "v2")
SETS = {"A": "questions.json", "B": "questions_b.json"}


def tasks(s):
    q = json.load(open(os.path.join(B, SETS[s]), encoding="utf-8"))
    return q["tasks"] if isinstance(q, dict) and "tasks" in q else q


def answers(s):
    out = {}
    for f in sorted(glob.glob(os.path.join(R, f"*_r*_{s}.json"))):
        name = os.path.basename(f)[: -len(f"_{s}.json")]
        out[name] = json.load(open(f, encoding="utf-8"))
    return out


def blind():
    for s in SETS:
        if not os.path.exists(os.path.join(B, SETS[s])):
            continue
        ans = answers(s)
        if not ans:
            continue
        rnd = random.Random(f"lihfolk-{s}")
        items, key = [], {}
        for t in tasks(s):
            runs = list(ans.items())
            rnd.shuffle(runs)
            labels = {f"R{i+1}": name for i, (name, _) in enumerate(runs)}
            key[t["id"]] = labels
            items.append({"id": t["id"], "category": t.get("category"), "points": t["points"], "prompt": t["prompt"],
                          "answer_key": t["answer_key"],
                          "responses": {lab: ans[name].get(t["id"], "") for lab, name in labels.items()}})
        json.dump(items, open(os.path.join(R, f"blind_{s}.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        json.dump(key, open(os.path.join(R, f"_key_{s}.json"), "w", encoding="utf-8"), indent=1)
        print(s, len(items), "tasks,", len(ans), "runs blinded")


def boot_ci(vals, n=4000, seed=7):
    rnd = random.Random(seed)
    if not vals:
        return (0, 0)
    means = sorted(st.mean(rnd.choice(vals) for _ in vals) for _ in range(n))
    return means[int(0.025 * n)], means[int(0.975 * n)]


def report():
    lines = ["# LihFolk Benchmark v2", ""]
    usage = json.load(open(os.path.join(R, "usage.json"), encoding="utf-8")) if os.path.exists(os.path.join(R, "usage.json")) else {}
    for s in SETS:
        kp = os.path.join(R, f"_key_{s}.json")
        if not os.path.exists(kp):
            continue
        key = json.load(open(kp, encoding="utf-8"))
        T = {t["id"]: t for t in tasks(s)}
        grades = [json.load(open(f, encoding="utf-8")) for f in sorted(glob.glob(os.path.join(R, f"grade_{s}_*.json")))]
        if not grades:
            continue
        per = {}  # (run, task) -> [scores per grader]
        for g in grades:
            for row in g:
                for lab, sc in row["scores"].items():
                    per.setdefault((key[row["id"]][lab], row["id"]), []).append(float(sc))
        med = {k: st.median(v) for k, v in per.items()}
        runs = sorted({r for r, _ in med})
        arms = sorted({r.rsplit("_r", 1)[0] for r in runs})
        total = sum(t["points"] for t in T.values())
        lines += [f"## Set {s} ({len(T)} tasks, {total} points, {len(grades)} graders)", "",
                  "| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |", "|---|---:|---:|---:|---:|---:|---:|"]
        for a in arms:
            ar = [r for r in runs if r.startswith(a + "_r")]
            totals = [sum(med.get((r, tid), 0) for tid in T) for r in ar]
            pertask = [st.mean(med.get((r, tid), 0) for r in ar) / T[tid]["points"] for tid in T]
            lo, hi = boot_ci(pertask)
            u = [usage.get(f"{r}_{s}", {}) for r in ar]
            tm = st.mean([x.get("seconds", 0) for x in u]) if u else 0
            tk = st.mean([x.get("tokens", 0) for x in u]) if u else 0
            lines.append(f"| {a} | {st.mean(totals):.1f} / {total} (±{(st.pstdev(totals) if len(totals) > 1 else 0):.1f}) | {lo*100:.0f}-{hi*100:.0f}% | {st.mean(totals)/total*100:.1f}% | {len(ar)} | {tm:.0f} s | {tk/1000:.0f}k |")
        # category breakdown
        cats = sorted({t.get("category") for t in T.values()})
        lines += ["", "| Category | " + " | ".join(arms) + " |", "|---|" + "---:|" * len(arms)]
        for c in cats:
            ids = [tid for tid, t in T.items() if t.get("category") == c]
            row = []
            for a in arms:
                ar = [r for r in runs if r.startswith(a + "_r")]
                row.append(f"{st.mean([sum(med.get((r, tid), 0) for tid in ids) for r in ar]):.1f}/{sum(T[i]['points'] for i in ids)}")
            lines.append(f"| {c} | " + " | ".join(row) + " |")
        # inter-rater agreement: mean absolute difference between graders, normalised by task points
        diffs = []
        for (r, tid), v in per.items():
            for x, y in itertools.combinations(v, 2):
                diffs.append(abs(x - y) / T[tid]["points"])
        lines += ["", f"Grader agreement: mean |difference| between graders = {st.mean(diffs)*100:.1f}% of task points (lower is better)." if diffs else "", ""]
    open(os.path.join(B, "RESULTS_v2.md"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    os.makedirs(R, exist_ok=True)
    {"blind": blind, "report": report}[sys.argv[1]]()
