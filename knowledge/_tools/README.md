# Vault tools

## build_index.py

Rebuilds the vault's token-saving layer from the notes. Python 3, standard library only, no network. It is deterministic and idempotent: a second run changes nothing.

```
python knowledge/_tools/build_index.py              # regenerate everything (run after adding or editing notes)
python knowledge/_tools/build_index.py --check      # exit 1 if anything is out of date (CI-friendly)
python knowledge/_tools/build_index.py --measure    # print the 8-task token comparison below
python knowledge/_tools/build_index.py --no-tldr-in "56 Field Notes"   # don't touch that section's notes
python knowledge/_tools/build_index.py -v           # also list every file it changed
```

New notes are picked up automatically: any `.md` under a section folder gets indexed, mapped and (if it is prose) a TL;DR.

### What it generates

| Output | What it is |
|---|---|
| `knowledge/ROUTER.md` | The first file an agent reads (5 KB, capped at 6 KB). Core topics (remotes, DataStores, ProcessReceipt, UI, VFX, animation, combat, physics, performance, security, debugging, Blender, worldbuilding, economy, publishing) map to their section and 3 best notes. The other sections are listed with their most distinctive tags. The keyword map is `CORE` in the script, and titles are checked on every run. |
| `knowledge/INDEX.md` | `title \| path \| tags \| first sentence`, one line per note, same format as before. First sentences are cut to 110 characters and tags are deduplicated. |
| `knowledge/INDEX_SLIM.md` | `title \| path \| tags`, for grepping. |
| TL;DR blocks | In every prose note, under the title, between `<!-- tldr:start -->` and `<!-- tldr:end -->`. They hold 3 to 6 bullets taken from the note's own "Common mistakes" (`Avoid: X -> fix`) and "Checklist" items, shortened and with no new claims, then `Read more (N KB note): ## <sections>`. Notes with neither section get the first items or sentences of their key headings instead. Only the text between the markers is ever rewritten. |
| `knowledge/_maps/<section> - Map.md` | One line per note: its title and the first TL;DR bullet (or its first sentence). |

Skipped on purpose:
- `.obsidian`, `_assets`, `_tools` and `_maps`, and non-Markdown files.
- Link lists in `46 Resource Library`.
- `Start Here` hubs and the root skill-pointer notes.
- Three table-only reference notes with no prose to distil: `08 Animation/07 Gotchas/Open Questions.md`, `08 Animation/07 Gotchas/Troubleshooting Table.md` and `13 Production and Case Studies/Lessons Learned Index.md`.

### Reading protocol for agents

1. Grep `INDEX_SLIM.md` first; read `ROUTER.md` only at the start of a long multi-topic session or when the grep is ambiguous (on a single lookup it costs more than it saves).
2. If it doesn't name the notes, grep `INDEX_SLIM.md`.
3. Read only the TL;DR: `Grep pattern="tldr:start" glob="**/<title>.md" output_mode=content -A 10`, or `grep -A 10 "tldr:start" "<path>"`.
4. Only if that isn't enough, `grep -n "^## "` the note and read just the section the TL;DR points to.
5. Never read whole notes, and cite titles.

### Measured savings (`--measure`, tokens ≈ bytes / 4)

- **Old protocol:** grep `INDEX.md`, then read "Common mistakes" + "Checklist" of 2 notes, plus one section.
- **New protocol:** `ROUTER.md`, grep `INDEX_SLIM.md`, then read 2 TL;DRs, plus the same section.

| Task | Old tok | New tok, router already read | Saved |
|---|---:|---:|---:|
| secure a RemoteEvent for buying | 1,224 | 846 | 31% |
| DataStore session locking | 1,810 | 1,170 | 36% |
| ProcessReceipt | 1,872 | 1,424 | 24% |
| mobile-safe ScreenGui | 1,355 | 875 | 36% |
| slash VFX | 1,980 | 1,392 | 30% |
| hitbox | 1,132 | 805 | 29% |
| memory leak | 1,955 | 1,463 | 26% |
| Blender export scale | 1,693 | 1,003 | 41% |
| **All 8** | **13,023** | **8,980** | **32%** |

- **The router costs about 1,260 tokens and is read once per session.** For the whole 8-task session that gives 10,238 tokens instead of 13,023 (22% saved). When the router already names the notes, so no index grep is needed, it is 8,732 tokens (33% saved).
- **The router doesn't pay off on a single isolated task:** that task costs 33 to 82% more.
- **The notes part alone shrinks from 5,629 to 2,675 tokens (53% saved),** comparing the TL;DR with the "Common mistakes" + "Checklist" sections it replaces. The one full section read is the same in both protocols and is now the largest cost.
