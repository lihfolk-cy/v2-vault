# AGENTS.md: using LihFolk with any AI coding agent

For Roblox work (Luau, Studio, remotes, DataStores, UI, worldbuilding, modelling, VFX, animation, design, monetisation, performance, security, publishing):

1. **One call first:** run `python "LihFolk Vault V2/_tools/vault.py" "<the task or bug in plain words>"` (Windows without `python` on PATH: `py`). It prints the best 3 notes' TL;DR bullets and section lists, plus matching lines from `LihFolk Vault V2/SYMPTOMS.md` (symptom | cause | fix | note) for bugs. Measured: the right note is in the top 3 for 93% of held-out tasks. `--paths` prints titles only; `-k 5` widens.
2. **No Python, or a miss?** Grep `LihFolk Vault V2/INDEX_SLIM.md` (`title | path | tags`) for exact API names, and `LihFolk Vault V2/SYMPTOMS.md` for what the bug looks like. `LihFolk Vault V2/ROUTER.md` (about 5 KB) maps core topics to their best notes; read it only at the start of a long multi-topic session.
3. **TL;DR before sections:** the search already printed the TL;DRs. For a note found another way (1-2 best notes, up to 4 for big tasks), read only its TL;DR block: `grep -A 10 "tldr:start" "LihFolk Vault V2/<path>"` (Claude Code: `Grep pattern="tldr:start" glob="**/<title>.md" output_mode=content -A 10`). It distils the note's Common mistakes and Checklist and names the sections worth reading.
4. **Open a full section only when the TL;DR isn't enough:** `python "LihFolk Vault V2/_tools/vault.py" --read "<title>" "<heading words>"` prints just that section (or `grep -n "^## "` the note and read that range). Never read whole large notes.
5. **Apply and cite** the note titles you used.
6. **Trust labels:** prefer `Roblox docs` and `Measured`; verify `Unverified` claims; never invent APIs or asset ids.
7. **Quality bar:** for generated assets and systems, score against `skills/quality-score/rubrics/<type>.md`. Hard gates must pass, and the minimum is 8.5/10. Don't grade your own work alone; get an independent review.

**Accuracy over savings (non-negotiable):** the TL;DR is a pointer, not a substitute. For high-stakes work (player data and DataStores, purchases and receipts, paid random items and policy, remotes and security, anything that ships to live players), always read the note's full `## Common mistakes` and `## Checklist` sections, and the section that holds the exact numbers or API rules you are about to use. Also read further whenever the TL;DR leaves any doubt. Never cite a number you only saw in a TL;DR without opening its section.

Deeper workflows (Blender modelling, trend games, council review) are in `skills/*/SKILL.md`; any agent can follow them as plain instructions.
