# Changelog

## 2.2.0 (2026-10-29)
- 1,294 notes (+~430): 116 original gap notes (vehicles, maps, weather, combat AI, systems, camera, audio, genres, growth, testing/QA, AI workflow), new section 58 Player QoL and Game Tweaks (29 notes), 57 API and Concept Atlas (269 hubs), 13 lessons-learned notes, VFX recipes (slash, ice ball approved reference).
- Graph: Related links (80% same-section), section-local Connected notes, richer tags: per-section galaxies. Search accuracy held (top-3 93%).
- Speed/cost: lihfolk-lookup agent (haiku) for vault lookups; quality-score no longer auto-triggers; hook blocks only on errors. Benchmark: LihFolk 61.8/64 vs plain Claude 45.4/64.
- LihFolk VFX: frontal-only slashes (SlashSweep), IceExplosion, IceBallCast, more presets (drafts). Celestial V2 Obsidian theme, Style Settings panel, Moon Map canvas.
- Vault folder renamed to `LihFolk Vault V2`.

## 2.1.0 (2026-10-28)
- **LihFolk systems library** (`lihfolk-systems` skill, `/lihfolk:new-system`): 19 typed Luau modules (Net validation, session-locked PlayerData, idempotent Receipts, Shop, EggHatch with 2026 odds rules + PolicyService, Codes, DailyRewards, Rebirth, Quests, Leaderboard...). Not yet run in Studio.
- **Code-check hooks** + `/lihfolk:audit`: 17 checks on every Luau file the AI writes (sh/awk + PowerShell engines, no Node/Python needed).
- **Expert delta notes**: Roblox changes 2025-2026 (async renames, Server Authority, Input Action System, TextChat lockdown, DataStore limits, odds rules, money changes) and What AI Models Get Wrong in Roblox; `LihFolk Vault V2/_data/roblox_facts_2026.json`.
- **Token savings**: TL;DR on 655+ notes, `INDEX_SLIM.md`, `ROUTER.md`, section maps, `build_index.py`; per-note token costs; skill descriptions -58%; `roblox-vault-research` merged into the router; accuracy rule for high-stakes topics. See Token Cost Benchmarks.
- **Quality**: minimum score 8.5; model gates A15-A18 (symmetry, alignment/seating, self-intersection, clean caps); feature close-ups in reviews; arm-twist gate for animation.
- **New knowledge**: 56 Field Notes (21 notes), curve modelling notes, Human Swing Biomechanics, Locomotion and Melee Reference Numbers.
## 2.0.0 (2026-10-28): LihFolk Vault V2
- First public plugin + vault release: 800+ notes, knowledge router, quality-score (9/10 rubrics with a learning ledger), council (Quick/Standard/Full), Blender modelling with quality gate, trend-game playbook, 10 specialist skills.
- Vault redesign: new home page, 8-domain graph colours, theme.
- Removed third-party scraped assets (Kenney, Poly Haven) from the release.
