# Changelog

## 2.3.0 (2026-10-29): Assets, sound and combat
- **New skill: `lihfolk-assets`** (`/lihfolk:assets`). It finds original models, materials, skies, animations and VFX in the LihFolk Asset Pack by searching its catalogues rather than browsing folders. It only offers finished or owner-approved assets and gives import steps for each type. Point it at the pack with `LIHFOLK_ASSETS`.
- **New skill: `lihfolk-sfx`**. A premium sound design playbook plus a `--!strict` Luau sound module:
  - **Module:** layered sounds, random pitch and volume, take rotation without repeats, voice limits with pooling, SoundGroup mix buses, animation-marker sync with the VFX kit, 2D UI sounds and caption hooks.
  - **Licensed sources only:** Roblox's licensed Creator Store library comes first, then premium libraries you own (Sonniss GDC, BOOM Library, A Sound Effect, Soundly Pro, Splice). Licence terms were checked on each vendor's own page.
  - **Quality bar:** a vetting checklist (sample rate, peak, onset, loudness target, variations) and search keywords for every VFX preset.
- **VFX:**
  - New **SpinAttack**: a rapid three-turn whirl that speeds up each turn, with a growing wind vortex, a rune circle under the pivot, and a huge frontal crescent finisher with a shockwave, ground cracks and a dust blast.
  - New **VoidImpact** (white flash, radial streaks, indigo ink burst) and **VoidOrb** (a black orb with an indigo rim and swirling violet crescents, which charges, holds and releases).
- **Animations:**
  - **SwordLight3** re-authored so the forearm rolls in one planned turn with no wrist pop. **Sprint** reworked with a full arm pump and chest counter-twist.
  - **Jump** rebuilt: arms lead the push-off, a tuck at the apex, the legs reach for the ground, and the landing is deep and absorbed.
  - **SwordLight3** now passes (blind median 8.7). **Jump** and **Idle** are owner-approved at 8.3.
  - New **SpinAttack** and **TwistBackflip** clips (drafts). Whole-body rotation is keyed on the Root joint, and the twist backflip records `end_offset_studs` so the game can move the HumanoidRootPart.
  - 9 clips are now finished or owner-approved.
  - Pipeline: an optional per-clip `GRIP_ROLL` and a clip-scoped `overlap_exempt` (see `PIPELINE.md`).
- **Building and modelling:** a general **House Construction Method** note (cabin, cottage, medieval, modern and fantasy) and a reusable Blender helper, `lihfolk_house.py` (walls with real openings, gable roofs with snow, chimneys, windows, doors, steps, floating-part scan). Proven on a stone cottage: every gate passes, and 0 of 317 parts float.
- **General lessons as knowledge:** new notes on VFX readability and value, escalation without clutter, spin and whole-body moves, locomotion clips, and blind-review noise. Twelve general VFX rules are in the `lihfolk-vfx` skill, plus new VFX and animation recipes in `quality-score`.
- **Sample data:** `LihFolk-Asset-Pack-Sample.zip` (about 120 MB of shippable assets with the full pack's layout) on the release; sample catalogues for the assets skill; a sample ledger for quality-score.
- **For reviewers:** `REVIEWERS.md` lists each claim with the command that verifies it.
- **Asset Pack:** catalogues added for Animations and VFX, plus a top-level `INDEX.md`. Every catalogue row carries its blind-review score and status (`shipped`, `approved` or `draft`). Scores now use the latest 3-reviewer panel.
- **Benchmark v2:** 3 runs per setup, scored blind by 3 graders, with a held-out question set and bootstrap confidence intervals. With the vault, Claude scored 94.4% on the main set and 94.8% on the held-out set, against 68.4% and 91.7% without it. The biggest gain is on recent Roblox platform changes: 22.8/23 against 8.2/23. See `benchmark/RESULTS_v2.md`; the questions, answers, blind files, keys and grades are in `benchmark/` (`py -I benchmark/v2_aggregate.py report` reproduces the numbers).
- **LihFolk UI:** a house icon style (chunky, glossy, navy outline, two-tone faceting, specular shine), added to the `lihfolk-ui` skill and the vault.
- **Obsidian:**
  - The look now ships as CSS snippets only, with no community plugin needed. The old Celestial Vault plugin's banners, moon phases, moon calendar and streak orb are now CSS.
  - A new V2 ringed gas giant on the home page and the new-tab screen.
  - The new-tab screen has a rainbow sparkle field, glowing shooting stars, two drifting portal rifts and soft nebula depth, under an "Income Multiplier." greeting.
  - Rainbow section colours in the graph. The optional **LihFolk Graph** plugin, about 50 lines of our own code, colours each link by its note.
  - The Everforest base theme now ships with its MIT licence.
- **Known limitations:** the Luau modules (VFX, SFX, systems) have not yet been run in Studio. All asset ids are `REPLACE_ME` until you upload your own.

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
