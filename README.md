# LihFolk Vault V2: Roblox game dev knowledge for humans and AI

**Read it as a vault. Install it as a plugin.** 1,290+ expert notes on making Roblox games, written so both you and your AI can use them. Each note has trust labels, common mistakes and checklists.

## Two ways to use it

### 1. Obsidian vault (read and browse)
1. Download this repo (green **Code** button, then **Download ZIP**, or `git clone`).
2. In Obsidian: **Open folder as vault**, then pick the `LihFolk Vault V2` folder.
3. Start at **000 Home**. The Celestial look (starry backdrop, V2 home planet, journal banners, moon calendar) and the graph colours load automatically from the CSS snippets in `.obsidian/snippets`, which are already switched on in `appearance.json`. No community plugin is needed, and the snippets still work if Obsidian opens the vault in Restricted mode. One small optional plugin of our own, **LihFolk Graph**, is bundled and colours each graph link by its note; turn on community plugins to use it. Journal and month templates live in `_templates`.

### 2. Claude Code plugin (your AI builds like a pro)
In Claude Code:
```
/plugin marketplace add lihfolk-cy/v2-vault
/plugin install lihfolk@lihfolk
```
After that, Roblox tasks automatically use the knowledge base. You also get:

| | What it does |
|---|---|
| **Knowledge router** | Finds the right notes for each task and applies their mistakes and checklists, sized to the task so it stays cheap |
| **Quality score** | Generated models, animations, UI, systems, worlds and VFX must score at least **8.5/10** on fixed rubrics. Every attempt is logged so first drafts get better over time (`/lihfolk:learn`) |
| **Council** | Blind, anonymised multi-agent review for objective verdicts: Quick, Standard or Full tier (`/lihfolk:council`) |
| **Blender modelling** | Roblox-ready modelling with an automatic quality gate and correct export (no 100x scale, no lost bevels) |
| **Trend games** | The 2025-2026 trend-game playbook with the new Roblox rules (`/lihfolk:trend-game`) |
| **Systems library** | 19 drop-in typed Luau modules: validated remotes, session-locked data, idempotent purchases, shop, eggs with 2026 odds rules, codes, daily rewards, rebirth, quests, leaderboards (`/lihfolk:new-system`) |
| **Asset pack** | Finds original models, materials, skies, animations and VFX in the separately downloaded LihFolk Asset Pack by catalogue search, shippable rows only, with import steps (`/lihfolk:assets`, set `LIHFOLK_ASSETS`) |
| **Sound effects** | Layered, varied combat and UI sounds: a pooled Luau module with volume buses and animation-marker sync matched to the VFX presets, sourced only from premium, properly licensed sounds (Roblox-licensed Creator Store audio first, then a library you own) with a quality checklist and editing pipeline (`lihfolk-sfx`) |
| **Code checks** | A hook scans every Luau file the AI writes for 17 known Roblox mistakes and makes it fix them (`.lua` files are checked inside Roblox projects); `/lihfolk:audit` reviews a whole project |
| **LihFolk UI** | Original cartoon/simulator menu kit with Luau components |
| **2025-2026 knowledge** | What changed on Roblox since most models were trained, and what AI models get wrong |
| **Specialist skills** | Secure remotes, DataStore safety, UI building (plus the LihFolk house style), performance, debugging, anti-exploit, monetisation compliance, asset import, system builder |

### Other AI tools (Cursor, Codex, ChatGPT and others)
Point your tool at this folder. `AGENTS.md` tells any agent how to search the vault and apply the notes.

## Built to be trusted by AI agents

- **One-call search:** from the repo folder, `python "LihFolk Vault V2/_tools/vault.py" "my sword floats away from the hand when I attack"` returns the 3 best notes with their TL;DRs (use `python3` or, on Windows, `py` if that's your launcher). It understands bugs described in everyday words through `LihFolk Vault V2/SYMPTOMS.md`, which has 250+ symptom → cause → fix lines. On a held-out test set of hand-written tasks, the right note is in the top 3 **93%** of the time, against 57% for grepping the index. The average answer costs about 700 tokens.
- **No made-up APIs:** every Roblox and Luau API name in the notes is checked against a dated snapshot of the real API, including deprecations. Methods Roblox renamed to `...Async` are already updated throughout.
- **Code that compiles:** all 1,800+ Luau code blocks are compiled with the official Luau compiler on every push.
- **Notes that agree:** numbers repeated across notes, such as limits, defaults and ratios, are cross-checked, and stale date stamps are flagged.
- **Checked on every push:** `.github/workflows/vault-checks.yml` runs all of it. Details and numbers are in `LihFolk Vault V2/_tools/README.md`.

## Trust labels
Every claim is marked **Roblox docs** (official), **Measured** (tested in a real project), **Rule of thumb** (craft knowledge) or **Unverified** (awaiting confirmation). Roblox changes fast, so dated claims say "as of".

## What's inside
- `LihFolk Vault V2/`: the vault (55 sections, index, home page, theme)
- `benchmark/`: the v2 benchmark (questions, answers, blind grades) and the script that reproduces the results
- `REVIEWERS.md`: every claim and the command that checks it
- `skills/`, `agents/`, `commands/`: the Claude Code plugin
- `.claude-plugin/`: plugin and marketplace manifests

## License
Notes, images and scripts: **CC BY 4.0**. Credit "LihFolk Vault V2" and link back. Code snippets inside notes may be used in your games without attribution.

LihFolk Asset Pack (download from [Releases](https://github.com/lihfolk-cy/v2-vault/releases), including a small sample zip): free to use and modify in your own games, commercial ones included, with no credit needed; you may not resell or redistribute the assets themselves. Full terms in [LICENSE.md](LICENSE.md).

Not affiliated with or endorsed by Roblox Corporation.
