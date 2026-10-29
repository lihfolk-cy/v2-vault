# Vault tools

Python 3, standard library only. Everything here is deterministic, and every check runs on GitHub on each push (`.github/workflows/vault-checks.yml`).

| Tool | What it does | Command |
|---|---|---|
| `vault.py` | One-call search: the best 3 notes for a task or bug, with their TL;DR bullets and section lists, and matching symptom lines. Reads one section of a note on request. | `python "LihFolk Vault V2/_tools/vault.py" "screen goes black when I get hit"` |
| `build_index.py` | Regenerates TL;DRs, `INDEX.md`, `INDEX_SLIM.md` and `ROUTER.md` from the notes. | `python "LihFolk Vault V2/_tools/build_index.py"` (`--check` in CI) |
| `api_check.py` | Checks every Roblox and Luau API name in the notes against the real API. | `python "LihFolk Vault V2/_tools/api_check.py" --strict` |
| `snippets.py` | Compiles every Luau code block with the official Luau compiler. | `python "LihFolk Vault V2/_tools/snippets.py" --strict` |
| `consistency.py` | Finds notes that disagree on a number, and date stamps that are getting old. | `python "LihFolk Vault V2/_tools/consistency.py" --strict` |
| `eval.py` | Scores the search on 90 hand-written tasks with known answers. | `python "LihFolk Vault V2/_tools/eval.py"` |
| `link_builder.py` | Graph layer: `## Related` blocks (mostly same-section), the `57 API and Concept Atlas` notes, `area/ level/ type/ api/` tags and first-mention links. Run it before `build_index.py`. | `python "LihFolk Vault V2/_tools/link_builder.py"` (`--check`, `--no-inbound`) |

Reports are written to `reports/`.

## vault.py: one-call search

```
python "LihFolk Vault V2/_tools/vault.py" "datastore session lock"                 # best 3 notes' TL;DR bullets + symptom lines
python "LihFolk Vault V2/_tools/vault.py" --brief "datastore session lock"         # cheaper: notes 2-3 cut to two lines (can hide facts)
python "LihFolk Vault V2/_tools/vault.py" --full "datastore session lock"          # raw TL;DR blocks with paths and sizes
python "LihFolk Vault V2/_tools/vault.py" --paths "slash vfx"                      # titles and paths only
python "LihFolk Vault V2/_tools/vault.py" -k 5 --json "processreceipt"             # machine-readable
python "LihFolk Vault V2/_tools/vault.py" --sections "DataStore Fundamentals"      # list a note's ## headings
python "LihFolk Vault V2/_tools/vault.py" --read "DataStore Fundamentals" "UpdateAsync"   # print one section
```

Ranking is BM25F over each note's title, tags, TL;DR, headings, body and the `SYMPTOMS.md` lines that link to it. A small synonym map turns everyday words into vault vocabulary (lag → performance, save → datastore, buy → purchase). Link lists, short glossary notes and hubs are ranked below full explanations. The index is cached in `.cache/` (git-ignored) and rebuilt when any note changes. A cold run takes about 2 s, and a cached run about 0.3 s.

## Measured retrieval quality (`eval.py`)

`eval/tasks.jsonl` holds 90 tasks written by an agent that never saw the search code. Each task lists 1-3 acceptable notes, chosen by reading the notes. The mix is about 34% feature requests, 30% bugs described in everyday words, 20% API questions and 16% art, build and design tasks, spread over 46 sections. Search weights were tuned only on the 60 `dev` tasks. The 30 `test` tasks were not used for tuning, so their score is the honest one.

| Split | Tasks | hit@1 | hit@3 | MRR@3 | Baseline hit@3 |
|---|---:|---:|---:|---:|---:|
| dev | 60 | 63% | 92% | 0.76 | 52% |
| **test (held out)** | 30 | **77%** | **93%** | 0.84 | 60% |

- **Baseline:** the same ranking on titles and tags only, which is roughly what grepping `INDEX_SLIM.md` finds.
- **Cost per task:** an agent reads about 600 tokens of output: three TL;DRs and section lists without the callout and cost boilerplate, plus any symptom lines (`--full` is about 745, `--brief` about 400).
- **Older protocol:** grep the index, then read "Common mistakes" and "Checklist" from 2 notes. That costs about 1,600 tokens per task (see `--measure` below) and needs 3-5 tool calls instead of one.

## api_check.py: no made-up or deprecated APIs

The script checks these names in code blocks and `inline code`:
- `Instance.new("X")` and `GetService("X")`
- `Enum.A.B`
- library members, for example `math.x`, `task.x`, `table.clone` and `CFrame.lookAt`
- `Class.Member` and `Class:Method`
- deprecated globals and lower-case aliases

The reference is `roblox_api.json`, a committed and dated snapshot (944 classes, 656 enums, 885 globals). It is built by `--refresh` from three local sources:
- Studio's own API docs file;
- the Roblox API dump;
- the standard-library members reported by a local `luau` binary (set `LUAU`).

A deprecated name is accepted when the text around it says it is deprecated or legacy. Reviewed exceptions go in `api_allow.txt` with a reason.

The first run found 30 problems in 24 notes, all now fixed:
- calls to methods Roblox has renamed with an `Async` suffix, such as `LoadCharacter`, `CreateHumanoidModelFromDescription`, `GetProductInfo`, `PlayEmote` and `IsInGroup`;
- `GetRankInGroup`, whose `Async` version is itself deprecated in favour of `GroupService:GetRolesInGroupAsync`;
- `TeleportToPlaceInstance`, replaced by `TeleportAsync` with `ServerInstanceId`;
- `plugin:GetStudioUserId()`;
- `GuiService:AddSelectionParent`;
- a misspelt `Vector3.fromNormalId`.

## snippets.py: every Luau block compiles

Needs `luau-compile` from https://github.com/luau-lang/luau/releases (set `LUAU_COMPILE`; CI downloads 0.744). It covers all 1,603 `lua`/`luau` blocks:
- 1,592 compile;
- 11 are deliberate excerpts, such as one entry of a migrations table, listed in `snippet_allow.txt` by block hash with a reason;
- 3 real bugs were found and fixed: statements starting with `(` after a call, which Luau rejects as ambiguous syntax.

This is a syntax and compile check. API names are `api_check.py`'s job, and there is no full type check against Roblox's type definitions.

## consistency.py: notes agree with each other

`FACTS` lists numbers many notes repeat:
- DataStore value size;
- default `WalkSpeed`, `JumpPower` and `Gravity`;
- the HttpService budget and MemoryStore item size;
- the text stroke ratio.

Every mention is compared with the agreed value. The first run found one real conflict: 3 notes recommended 8-15% text strokes without the limit of about 7% for rounded heavy fonts. Those notes now carry the limit and link to the Field Note. The script also flags "as of <month year>" stamps older than 12 months. All 900+ stamps are currently October 2026.

## build_index.py

```
python "LihFolk Vault V2/_tools/build_index.py"              # regenerate everything (run after adding or editing notes)
python "LihFolk Vault V2/_tools/build_index.py" --check      # exit 1 if anything is out of date (CI)
python "LihFolk Vault V2/_tools/build_index.py" --measure    # 8-task token comparison of the grep protocols
python "LihFolk Vault V2/_tools/build_index.py" --no-tldr-in "56 Field Notes"   # don't touch that section's notes
```

- **TL;DR blocks:** every prose note gets one under its title, between `<!-- tldr:start -->` and `<!-- tldr:end -->`. It holds 3-6 bullets taken from the note's own "Common mistakes" (`Avoid: X -> fix`) and "Checklist", shortened with no new claims, then `Read more (N KB note): ## <sections>`. Only the text between the markers is ever rewritten.
- **`INDEX.md`:** one line per note, `title | path | tags | first sentence`.
- **`INDEX_SLIM.md`:** the same without the first sentence, for grepping.
- **`ROUTER.md`:** 5 KB of reading rules plus core topics mapped to their best notes.
- **Not indexed:** link lists in `46 Resource Library`, `Start Here` hubs and root pointer notes get no TL;DR. `SYMPTOMS.md` is an index, not a note.

`--measure` compares two ways of reading notes. The old way reads "Common mistakes" and "Checklist" in full. The TL;DR way reads only the TL;DR blocks, which is 53% fewer tokens, or 32% fewer per lookup including the index grep and one section.
