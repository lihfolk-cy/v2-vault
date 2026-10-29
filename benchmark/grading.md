# Blind grading rules

## What the grader sees

For each task the grader gets exactly:

1. the task `prompt`
2. the task `answer_key` (checklist) and `grader_notes`, if any
3. two or three responses, labelled only **A**, **B** and **C**

The grader never sees which condition produced a response (plugin on, plugin off, other). The label-to-condition mapping is reshuffled for every task and kept in a separate file the grader cannot see.

Before grading, the operator strips anything that identifies the condition from every response: the words "LihFolk", "vault" and "plugin"; note titles or `[[wiki links]]`; file paths; skill or tool names; "according to my notes"-style phrasing. Remove only the identifying words and keep the technical content unchanged. If a response can't be anonymised without changing its meaning, flag it rather than grade it.

Use a fresh grader (human, or a model with no tools and no Roblox notes loaded) for each batch. Never use the system under test as the grader.

## Scoring each checklist item

Score every item of the answer key separately:

| Score | Meaning |
|---|---|
| **1 (full)** | The response states the fact correctly and specifically enough to act on, in any wording. Equivalent correct names and numbers count (for example `UpdateAsync` uses "1 read + 1 write" = "consumes both budgets"). |
| **0.5 (partial)** | Correct direction but incomplete or vague (for example "the old names are deprecated" without saying they still work), or the item says partial credit applies (for example P2 with only 1-2 settings named, P5 with a base of 250). |
| **0 (missing)** | Not addressed, or only hinted at. A hedged wrong guess ("I think it might be X, verify in the docs") also scores 0, with no penalty. |
| **-1 (confident wrong)** | The response states a fact for this item confidently, and it contradicts the key or the sources (wrong method name, wrong number, wrong order, says old names were removed, and so on). |

Task score = `points x (sum of item scores) / (number of items)`, floored at `-points`. Round to 2 decimals.

## Errors outside the checklist

A confidently stated wrong Roblox fact that is not covered by any checklist item, and that would mislead a developer (a non-existent API, a wrong limit, unsafe security advice), costs **-1 point** off the task score. The cap is -2 per task. Don't penalise style, naming preferences or debatable best practice.

Code that would not run as written (wrong method name, wrong argument order, a client-only API used on the server) counts as a confident wrong fact. Small syntax slips that don't change the meaning do not.

## No credit for verbosity

- Extra correct information outside the checklist earns nothing.
- Length, formatting, headings and confidence earn nothing.
- If a response clearly ignores the length budget (about 200 words or a short snippet) and the checklist facts are buried in a long dump, grade only what a reader would find in the first ~250 words (or ~40 lines of code). Content after that is ignored for credit but still counts for penalties.
- Listing many possibilities so one of them hits ("it could be A, B, C or D") earns at most 0.5 for that item.

## Ambiguity

- `grader_notes` override the default rules for that task.
- Where the key says "or", any listed alternative earns full credit.
- If the grader believes a key item is wrong, they still grade against the key, flag the task in the output, and the operator checks it against the sources. Never fix a key mid-run.

## Output format

One JSON line per task and label:

```json
{"task":"P5","label":"B","items":[1,0.5,1,0],"outside_penalty":0,"task_score":1.88,"flag":null,"note":"base 250 given"}
```

The operator then un-blinds the labels and reports, per condition: total out of 64, per-category totals (post_training 23, classic_gotcha 20, practical 21), and the number of -1 items. Use at least 3 independent runs per condition and report the mean and range.
