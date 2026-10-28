---
tags: [ai, evaluation, rubric, tools, process, cost, licensing, verification]
---
# Evaluating AI Tools - A Practical Rubric

New AI tools for game development appear every month, each with a demo video that looks like it will replace a job. Most of them do not survive contact with a real Roblox project. This note is a method for deciding, with evidence instead of vibes, whether a tool earns a place in your pipeline: the questions that matter, a weighted scoring rubric, a two-week trial protocol built on tasks from your own backlog, how to measure the cost of verification (the hidden cost that sinks most tools), kill criteria, and how to re-evaluate when the tool changes under you.

The landscape itself (which tools exist, what Roblox's own AI features do) is in [[AI in Roblox Development Overview]] and the notes it links. This note is deliberately tool-neutral: products change monthly, the method does not. Any product facts are labelled "as of October 2026". Source labels: **Roblox docs**, **measured in the reference project** (one production game built with heavy use of AI coding agents connected to Roblox Studio and Blender), **rule of thumb**.

---

## 1. The one number that matters: time to accepted result

Demos measure **time to first output**: type a prompt, get a mesh in 30 seconds. Production cares about **time to accepted result**: the time from starting a task until the output is in the game, reviewed, and you would not be embarrassed to ship it. That includes:

```
time to accepted result =
    prompt and setup time
  + generation time (all attempts)
  + verification time (reading, testing, checking licences)
  + fix time (cleanup, retopology, rewriting the wrong 20 percent)
  + integration time (import, naming, wiring into systems)
```

Compare that against the same task done your usual way. A tool that generates in 30 seconds but needs 3 hours of cleanup loses to a 2-hour hand-made asset. A code agent that writes a system in 5 minutes that takes 40 minutes to review and debug wins against a 3-hour hand-written version, but only if the review actually catches the bugs.

The reference project is a clear example of both outcomes. Its agents writing tooling (Studio loaders, offline solvers, QA scorers, render pipelines) were the most valuable AI work in the project. Its early AI-generated meshes were all replaced, and the rule became "build everything in Blender with clean topology". Automated material generation through a Studio tool "failed almost every job" (its notes say so more than once), so it was dropped. The same team, the same discipline, wildly different results by task type. That is why you evaluate per task type, not per tool.

---

## 2. The rubric

Score each criterion 0 to 3 on evidence from your trial (section 3), not from the vendor's page. Weights depend on what kind of tool it is; three common profiles are given.

| # | Criterion | 0 | 3 | Code agent weight | Art generator weight | Audio / voice weight |
|---|---|---|---|---|---|---|
| 1 | **Accepted-result rate** on your tasks | Under 20 percent usable after fixes | Over 70 percent | 5 | 5 | 5 |
| 2 | **Verification cost** | Every output needs line-by-line or vertex-by-vertex checking | Errors are visible quickly, or checks are automatable | 5 | 3 | 2 |
| 3 | **Roblox correctness** | Invents APIs, ignores Roblox limits (20,000 triangles per mesh, 4 bone influences, Luau syntax) | Current APIs and limits, unprompted | 4 | 3 | 1 |
| 4 | **Style and consistency control** | Every output looks different | Can match a reference set repeatedly | 1 | 5 | 4 |
| 5 | **Integration** | Copy-paste only; manual import | Works with your files, Studio (plugin or MCP), version control | 4 | 3 | 2 |
| 6 | **Licensing and policy fit** | Unclear commercial rights, or output conflicts with Roblox rules | Clear commercial licence; output passes Roblox moderation and policy | 3 | 5 | 5 |
| 7 | **Data and privacy** | Uploads your place or code to unknown places; trains on it by default | Clear data policy; opt-out; can run locally or with your own keys | 3 | 2 | 2 |
| 8 | **Safety of actions** | Can make destructive changes without confirmation | Read-only by default; permissions; dry runs; snapshots | 4 | 1 | 1 |
| 9 | **Cost predictability** | Usage caps or bills you cannot forecast | Known price per task; caps you can live with | 2 | 2 | 2 |
| 10 | **Exit cost** | Proprietary formats; lose everything if the vendor dies | Standard outputs (Luau files, GLB/FBX, WAV, PNG) | 2 | 2 | 2 |

**Total score** = sum of (score times weight) divided by (3 times the sum of weights), as a percentage.

Rule of thumb thresholds: under 50 percent, do not adopt; 50 to 70 percent, adopt for named task types only; over 70 percent, adopt broadly and keep measuring. **Any 0 on criteria 1, 6 or 8 is a veto** regardless of total: a tool that cannot produce usable results, whose output you cannot legally ship, or that can wreck your place is not saved by a good average.

### Why these criteria and not others

- **Speed is missing on purpose.** Generation speed is almost never the bottleneck; it is inside criterion 1 through time to accepted result.
- **"Quality" is split** into accepted-result rate (does it work) and style control (does it match). An art tool can make beautiful assets that never match each other, which for a game is a failure.
- **Verification cost gets its own row** because it is the cost people forget. For code agents it is the dominant cost; see section 4.
- **Roblox correctness** separates general tools from Roblox-aware ones. General code models still produce Lua 5.3 bitwise operators or deprecated APIs ([[AI Code Assistants for Luau]] lists the common ones); general 3D generators ignore the per-mesh triangle limit and produce 200,000-triangle blobs ([[AI 3D Model Generation Outside Roblox]]).

---

## 3. The trial protocol

A trial is a small, honest experiment. Two weeks of part-time use is usually enough.

### Step 1: pick tasks from your real backlog

Choose 8 to 12 tasks you would do anyway, across difficulty:

| Difficulty | Example (code agent) | Example (art) |
|---|---|---|
| Easy (3 to 4 tasks) | A settings toggle wired to a saved value; a leaderboard display | A crate; a rock set |
| Medium (3 to 4) | A daily reward with server validation; a shop purchase flow with `ProcessReceipt` | A market stall to a kit's style; a weapon to a concept |
| Hard (2 to 4) | A session-locked save system with migration; a combat hit validation path | A creature for a custom rig; a modular wall kit that tiles |

Never evaluate on the vendor's examples or toy tasks ("make a part spin"). Every tool looks good on those.

### Step 2: define "accepted" before you start

For each task, write the acceptance criteria first, so you cannot move the goalposts after seeing the output:

- Code: compiles in strict mode; passes the linter; passes named tests; reviewer finds no correctness bug; follows the project's architecture (see [[Prompting and Verifying AI Output]] for the verification ladder).
- Art: under budget (see [[Mesh Optimization for Mobile]]); UVs and texel density match the kit; silhouette approved by the art lead in a side-by-side with existing assets; imports cleanly ([[Exporting and Validating Models for Roblox]]).
- Audio: levelled to your target loudness; no artefacts at the start or end; licence allows commercial use in a Roblox experience ([[AI Audio - Voice Music and SFX]]).

### Step 3: run with a stopwatch

For each task log: attempts, generation time, verification time, fix time, integration time, outcome (accepted, accepted with major fixes, abandoned). Also log every **defect found later** (a bug in review, a problem in a play test) and which stage should have caught it.

### Step 4: run the baseline

Do at least three of the same tasks your normal way (or use honest past timings). Without a baseline you are measuring how fast the tool is, not whether it helps.

### Step 5: score and decide

Fill in the rubric from the log. Write one paragraph: "We adopt this for X and Y, not Z, because ..." and the date.

### Example log (illustrative numbers, not a real product)

| Task | Tool attempts | Gen | Verify | Fix | Integrate | Total | Baseline | Outcome |
|---|---|---|---|---|---|---|---|---|
| Daily reward | 2 | 4 min | 25 min | 15 min | 10 min | 54 min | 2 h | Accepted |
| Session-locked save | 4 | 12 min | 60 min | 90 min | 20 min | 3 h 2 min | 4 h | Accepted, 1 bug found in review |
| Combat validation | 3 | 9 min | 45 min | abandoned | | 54 min lost | 3 h | Abandoned: wrong trust model |
| Market stall mesh | 5 | 3 min | 10 min | 2 h 30 min | 20 min | 3 h 3 min | 2 h 30 min | Accepted, slower than baseline |

This pattern (strong on medium code, weak on security-critical code, no gain on style-matched art) is typical. The decision would be: adopt for gameplay and tooling code with review; not for trust-boundary code without a senior reviewer; not for kit art.

---

## 4. Measuring verification cost properly

Verification is where AI tools quietly cost the most, and where trials lie the most, because a trial reviewer is careful and a tired developer in week ten is not.

Three measures to collect:

1. **Verification time per accepted output** (from the log).
2. **Escape rate:** defects found *after* acceptance divided by accepted outputs. An escape is a bug that reached a play test, or an asset problem found after import. If the escape rate is high, your verification time was too low, not the tool's quality high.
3. **Automatable share:** what fraction of the checks can a machine run? A code tool whose output can be checked by the compiler, a strict type check, a linter and tests is cheaper to verify than one whose output needs a human reading every line.

The reference project made verification cheap by automating it. Every script change went through a gate before saving: the source must compile, a "use before definition" scanner must return nothing (it caught real crashes, such as calling a local function before it was defined), the source had to stay under the 200,000 character script limit, and modules were tested by requiring a fresh clone (because `require` in Edit returns a cached copy). Animation output had numeric quality scores and a "do not install" rule when the score failed. Changes that could not be play-tested by the agent were labelled "not play-tested" so a human knew what remained. Those gates are what made a high volume of AI output safe; without them the same tools would have scored much lower on criteria 1 and 2. See [[MCP Workflows for Scripting and Debugging]] and [[Agent Review Loops and Guardrails in Practice]].

Rule of thumb: **if you cannot automate at least half of the checks for a task type, budget human review time equal to at least the generation-plus-fix time,** and expect a lower adoption score.

---

## 5. Licensing, policy and data: the vetoes

These three rarely show up in demos and can end a project.

### Licensing

Read the terms, not the marketing page:

- **Commercial use** of outputs: allowed on free tiers? Some tools allow commercial use only on paid plans.
- **Ownership:** do you own the output, or have a licence to use it? Can the vendor reuse it?
- **Indemnity:** does the vendor stand behind the output if a claim arises? Most do not.
- **Training inputs:** if the tool reproduces recognisable copyrighted content, you carry the risk on Roblox, not the vendor. Roblox's own rules on uploaded content apply whatever made it ([[Roblox Policies on AI-Generated Content]]).

### Roblox policy

Output that passes your eye may still fail moderation or policy: generated images with near-copies of brands, voices that imitate real people, runtime text generation without filtering. Score criterion 6 low if a tool's typical output needs policy review every time.

### Data and privacy

- What does the tool send off your machine? A code agent reads your project; an MCP-connected agent can read your whole place. A Studio-connected tool may see player data in your test places.
- Is your data used for training by default? Can you opt out? Is there a business tier with different terms?
- **Secrets:** API keys, Open Cloud keys and webhook URLs must never be in what the tool reads. The reference project's rules forbade keys and tokens in anything an agent handled. If a tool's design makes that hard, score criterion 7 at 0.

---

## 6. Cost: forecast it before you need it

Subscription prices are easy; usage-based costs and caps are where surprises happen. As of October 2026, examples of limits that shape real use (Roblox docs and announcements; re-check before relying on them): Roblox's Assistant is free within daily usage limits whose numbers are not published, procedural model generation has a rolling daily cap, and `TextGenerator` has per-experience request limits. External coding agents bill per token or per seat with usage tiers.

Forecast with your trial log:

```
monthly cost ~= (tasks per month of this type) x (attempts per task) x (cost per attempt)
             + seats or subscriptions
```

Then compare against the time saved at a realistic hourly value. Also note **cap risk**: a tool that hits a daily cap in the middle of a release crunch is worse than a slower tool you can always use.

---

## 7. Kill criteria and re-evaluation

Decide in advance what would make you stop using a tool, and write it next to the adoption decision:

- Escape rate above an agreed threshold for two consecutive weeks (for example, more than one in ten accepted code changes causing a play-test bug).
- A destructive incident (lost work, a broken place) attributable to the tool's actions, unless a guardrail is added that would have prevented it.
- A terms change that removes commercial rights or adds training on your data without opt-out.
- Cost growth beyond the forecast by an agreed margin.

**Re-evaluate on change.** AI tools change model, pricing and behaviour without asking. Keep your trial tasks and acceptance criteria as a small regression set and re-run three or four of them when:

- the vendor announces a new model or major version;
- the price or limits change;
- you notice a shift in output quality (people will say "it got worse"; measure it);
- every three months anyway.

This is cheap because the work is already done: the tasks, the criteria and the old timings exist. A re-run that takes half a day can save weeks of slowly degrading output.

### A tiny scoring helper

Keeping the scores in a file makes trends visible across re-evaluations. A minimal Python helper:

```python
# rubric.py : weighted rubric score with vetoes. Usage: python rubric.py scores.csv
import csv, sys

VETO = {"accepted_rate", "licensing_policy", "action_safety"}

def score(path):
    total, maxi, vetoed = 0.0, 0.0, []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):  # columns: criterion, score (0-3), weight
            s, w = float(row["score"]), float(row["weight"])
            total += s * w
            maxi += 3 * w
            if row["criterion"] in VETO and s == 0:
                vetoed.append(row["criterion"])
    pct = 100 * total / maxi if maxi else 0
    verdict = "VETO" if vetoed else ("adopt" if pct >= 70 else "named tasks only" if pct >= 50 else "do not adopt")
    print(f"{pct:.0f}% -> {verdict}" + (f" (veto: {', '.join(vetoed)})" if vetoed else ""))

if __name__ == "__main__":
    score(sys.argv[1])
```

---

## 8. Nuance: where the obvious evaluation is wrong

- **"It worked in the demo" measures the vendor's task, not yours.** Always use your backlog.
- **The best tool for a task can be the worst for the project.** A generator that makes great single assets but cannot match a kit style scores high on criterion 1 for one-offs and fails the project. Score against the project's acceptance criteria.
- **A tool that makes you faster can make the team slower.** If one developer generates code ten times faster but reviewers drown, the team's throughput drops. Measure review queues, not just authoring time.
- **Low scores can be your setup, not the tool.** Code agents score far better in a file-based project with types, a linter and tests than in a single place file with no checks ([[AI Code Assistants for Luau]]). Before rejecting a code tool, check whether your project gives it (and you) any way to verify.
- **Do not average across task types.** "Good for tooling, bad for art" is a useful decision; "60 percent overall" is not.
- **Roblox's own tools are not automatically the safest choice.** They are integrated and policy-aware, which helps criteria 5 and 6, but their output still needs the same acceptance criteria; built-in generation that fails almost every job in your use (as the reference project found for one material tool) scores 0 on criterion 1 no matter how convenient it is.

---

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Evaluating on toy tasks | Every tool looks good; adoption disappoints | Backlog tasks across difficulty |
| Counting generation time only | Hidden cleanup and review costs | Time to accepted result |
| No baseline | Cannot tell if the tool helped | Time the same tasks your usual way |
| Moving acceptance criteria after seeing output | Bias towards the tool | Write criteria first |
| Ignoring escapes | Review looked cheap because it missed bugs | Track defects after acceptance |
| Skipping the terms | Unshippable output | Licensing as a veto |
| One evaluation forever | Silent drift as models change | Regression set, re-run on change and quarterly |
| Averaging across task types | Vague decisions | Decide per task type |

## Checklist

- [ ] 8 to 12 real backlog tasks chosen, across difficulty.
- [ ] Acceptance criteria written before the trial.
- [ ] Every task logged: attempts, generation, verification, fix, integration, outcome.
- [ ] Baseline timings for at least three tasks.
- [ ] Escapes tracked for two weeks after acceptance.
- [ ] Rubric scored with the right weight profile; vetoes checked.
- [ ] Terms read: commercial use, ownership, training, indemnity.
- [ ] Data flow understood; no secrets reachable by the tool.
- [ ] Cost forecast from the log; cap risk noted.
- [ ] Decision written per task type, with kill criteria and a re-evaluation date.

See also: [[AI in Roblox Development Overview]], [[Prompting and Verifying AI Output]], [[AI Code Assistants for Luau]], [[Roblox Studio Assistant]], [[AI 3D Model Generation Outside Roblox]], [[AI Material and Texture Generation]], [[Roblox Policies on AI-Generated Content]], [[AI Agents and Autonomous Workflows]], [[Agent Review Loops and Guardrails in Practice]], [[Working with AI Assistants in Studio]].

## Connected notes
<!-- auto-links:start -->
[[Team Roles and Workflows]] · [[Case Study - Building a Game with AI Agents]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[Working with Contractors and Revenue Splits]] · [[Safety Rules for AI Agents in Studio]] · [[Third-Party Skill - Caveman Token Saver]]
<!-- auto-links:end -->
