# AGENTS.md: using LihFolk with any AI coding agent

For Roblox work (Luau, Studio, remotes, DataStores, UI, worldbuilding, modelling, VFX, animation, design, monetisation, performance, security, publishing):

1. **Grep first, don't read:** grep `knowledge/INDEX_SLIM.md` (`title | path | tags`) for the exact APIs and topics in the task. It's the cheapest lookup. `knowledge/INDEX.md` adds a first sentence per note. Paths are relative to `knowledge/`.
2. **Router only when it pays:** read `knowledge/ROUTER.md` (about 5 KB, core topics with their best notes) once at the start of a long, multi-topic session, or when the grep is empty or ambiguous. For a single quick lookup, skip it: it costs more than it saves.
3. **TL;DR before sections:** in the 1-2 best notes (up to 4 for big tasks), read only the TL;DR block: `grep -A 10 "tldr:start" "knowledge/<path>"` (Claude Code: `Grep pattern="tldr:start" glob="**/<title>.md" output_mode=content -A 10`). It distils the note's Common mistakes and Checklist and names the sections worth reading.
4. **Open a full section only when the TL;DR isn't enough:** `grep -n "^## "` the note, then read just that range. Never read whole large notes.
5. **Apply and cite** the note titles you used.
6. **Trust labels:** prefer `Roblox docs` and `Measured`; verify `Unverified` claims; never invent APIs or asset ids.
7. **Quality bar:** for generated assets and systems, score against `skills/quality-score/rubrics/<type>.md`. Hard gates must pass, and the minimum is 8.5/10. Don't grade your own work alone; get an independent review.

**Accuracy over savings (non-negotiable):** the TL;DR is a pointer, not a substitute. For high-stakes work (player data and DataStores, purchases and receipts, paid random items and policy, remotes and security, anything that ships to live players), always read the note's full `## Common mistakes` and `## Checklist` sections, and the section that holds the exact numbers or API rules you are about to use. Also read further whenever the TL;DR leaves any doubt. Never cite a number you only saw in a TL;DR without opening its section.

Deeper workflows (Blender modelling, trend games, council review) are in `skills/*/SKILL.md`; any agent can follow them as plain instructions.
