---
tags: [ai, benchmark, evaluation, vault, knowledge-base, accuracy, tokens, lihfolk, type/reference, area/ai, level/intermediate]
---
# Benchmark - Does a Knowledge Vault Make AI Better at Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Concluding the vault makes the model "smarter".
> - Avoid: Benchmarking only on tasks the vault was written for, then quoting the number as general.
> - Avoid: Ignoring cost: always-on lookups double latency on questions that didn't need them.
> - Answer keys cite primary sources
> - Same model both arms; blind, shuffled grading; median of 3
> - Results split by category (recent vs evergreen)
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## 4. What this means for using a vault · ## 5. Designing your own benchmark · ## Common mistakes · ## Checklist
<!-- tldr:end -->

verified: 2026-10-28

Does giving an AI model a curated Roblox knowledge vault make its answers better, and what does that cost? This note reports LihFolk Benchmark v1, run on this vault. All numbers are **Measured** in this project from a single run per arm, so treat small differences as noise.

## 1. Setup

- **24 Roblox tasks, 64 points.** Answer keys were checked against primary sources: Roblox Creator Docs, official DevForum posts, the Roblox newsroom, and the Blender manual for one export task.
- **Two arms, same model.** One arm could use LihFolk Vault V2. The other was told not to.
- **Blind grading.** Three independent graders scored shuffled responses. The X/Y labels were randomised per task, and the per-task median was used.
- **Three categories:** post-training platform changes (2025-2026), classic gotchas, and practical tasks.

## 2. Results

| Setup | Score | Accuracy | Time | Tokens |
|---|---:|---:|---:|---:|
| Model + LihFolk Vault V2 | 61.8 / 64 | 96.6 % | 470 s | 134k |
| Plain model | 45.4 / 64 | 70.9 % | 242 s | 81k |

| Category | Plain | Vault | Max |
|---|---:|---:|---:|
| Post-training changes (2025-2026) | 7.9 | 22.6 | 23 |
| Classic gotchas | 18.5 | 18.7 | 20 |
| Practical tasks | 19.0 | 20.5 | 21 |

## 3. Reading it honestly

- **The gain is recency, not intelligence.** About +14.7 of the +16.4 points come from platform changes the base model cannot know. On evergreen gotchas the two arms were level (18.5 vs 18.7).
- **It costs about 1.9x time and 1.7x tokens.** The vault arm made 48 lookups across 24 tasks, about two per task.
- **One task got worse.** On a Blender glTF export question the vault arm scored 1.3 / 2 against 1.7 / 2. The cause was not isolated, but Blender export behaviour moves quickly between releases (Blender 5.2, for example, exports every colour attribute as its own layer). A vault can confidently spread a stale fact, which is why notes carry a `verified:` date.
- **Limits.** One run per arm. Both arms ran as sub-agents in the same environment, and the plain arm was only *instructed* not to read the vault. 8 of 24 tasks target post-training changes, which favours any up-to-date source, not this vault in particular.

## 4. What this means for using a vault

- **Look up when the topic could have changed since the model's training cutoff:** monetisation and policy rules, new APIs, deprecations, Studio features, age and discovery rules, recent Blender versions.
- **Skip the lookup for stable basics** (CFrame maths, remotes 101, ModuleScripts). The base model already knows them and the lookup only adds cost.
- **Search, don't read.** A one-call search returning three TL;DRs costs about 700 tokens. Reading whole index files costs tens of thousands. See [[Token Cost Benchmarks]].
- **Keep notes dated and checkable.** The single regression was on a fast-moving tool (Blender export), exactly where a note goes stale first.

## 5. Designing your own benchmark

1. Write tasks with a verifiable answer key and its primary source. Avoid "explain X" tasks that graders can't score consistently.
2. Mix categories so that you can see *where* a gain comes from. A single total hides the fact that most of the gain is recency.
3. Use the same model in both arms and isolate the knowledge source as the only difference.
4. Use blind graders, randomised labels and a median of three.
5. Record time and tokens, not just accuracy. A 35 % accuracy gain at 1.7x tokens is a good trade. A 2 % gain at 3x is not.
6. Re-run after big vault changes, and run more than once before trusting differences under about 2 points.

## Common mistakes

- Concluding the vault makes the model "smarter". It mostly makes it current.
- Benchmarking only on tasks the vault was written for, then quoting the number as general.
- Ignoring cost: always-on lookups double latency on questions that didn't need them.
- Letting the plain arm read the vault by accident (same working directory, shared tools).
- Trusting one run. Variance between runs is real.

## Checklist

- [ ] Answer keys cite primary sources
- [ ] Same model both arms; blind, shuffled grading; median of 3
- [ ] Results split by category (recent vs evergreen)
- [ ] Time and token cost recorded beside accuracy
- [ ] Regressions investigated and the stale note fixed and re-dated
- [ ] Re-run after major vault edits

## See also

- [[Token Cost Benchmarks]]
- [[What AI Models Get Wrong in Roblox]]
- [[AI Pitfalls - Stale APIs and Luau]]
- [[Evaluating AI Tools - A Practical Rubric]]

## Connected notes

[[Case Study - Building LihFolk V2 with AI Agents]] · [[Obsidian Vaults for AI Agents - Structure, Graph and Theming]] · Documentation and Knowledge Bases

<!-- related:start -->
## Related
[[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Windows Tooling Pitfalls for Agent Pipelines]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[AI Pitfalls - Assets and Import]] · [[Who Owns AI-Generated Code and Assets]] · [[AI Agents and Autonomous Workflows]]
<!-- related:end -->
