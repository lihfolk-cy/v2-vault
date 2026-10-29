# Changelog

## 2.4.0 (2026-10-29): Worlds, onboarding and top-game teardowns

**Highlights:** a worldbuilding skill and a tutorial skill, 33 new teardowns of top Roblox games, leaner token use with higher search accuracy, and the Celestial look across the whole app.

### Added
- **Worldbuilding (`lihfolk-worldbuilding`):** brief and world pillars, five build passes with numbers and checkpoints, composition, lighting moods, materials and terrain, budgets for PC and phone, and a Luau toolkit (`placeOnGround`, `isAreaClear`, Poisson-disk `scatter`, `faceToward`, `budgetReport`, `auditWorld`). Plus a village-square example and the note **World Composition and Set Dressing**.
- **Tutorials (`lihfolk-tutorial`):** onboarding that keeps first-time players, with a data-driven Luau step module (server-owned progress and rewards, skip and resume, stuck-only hints, device-aware prompts, guidance arrows, funnel analytics), a tutorial review rubric and five new pages on FTUE, step design, onboarding by genre, measuring onboarding and cross-device prompts.
- **59 Viral and Trend Game Teardowns:** 15 teardowns (Steal An Egg, Plants vs Brainrots, +1 Speed Keyboard Escape, Escape Tsunami for Brainrots, Fish It, Ride A Pet, Tap Simulator REBORN, Sol's RNG, Ink Game, Bee Swarm Simulator, Build A Boat For Treasure, Natural Disaster Survival, Fling Things and People, Tower of Hell, PLS DONATE) and **Viral Game Anatomy - Hooks, Loops and Timing**.
- **60 High-Craft Game Teardowns:** 16 teardowns (Pressure, Grace, Dandy's World, Piggy, Evade, Apocalypse Rising 2, Phantom Forces, Arsenal, BedWars, Blade Ball, Jujutsu Shenanigans, Deepwoken, Welcome to Bloxburg, Funky Friday, Anime Vanguards, Driving Empire) and **What Craft Looks Like on Roblox - Lessons from Top Studios**.
- **Celestial chrome:** the file list, side panels, ribbon, tab bar, status bar, menus, dialogs and scrollbars now share the cosmic look; the graph page has twinkling stars and moon rocks drifting across the sky.

### Improved
- **Leaner and sharper (benchmark v2.1):** always-loaded skill descriptions from about 1,720 to 1,120 tokens, the router from about 1,610 to 720 tokens, and search output from 745 to 594 tokens per lookup. Search accuracy on practice questions rose from 85% to 92% top-3, the held-out set stays at 93%, and benchmark scores held under the same graders (set A 56.2 vs 55.4, set B 61.6 vs 60.7). Lookups also run about a third faster. See `benchmark/RESULTS_v2.1.md`.
- **Lookup agent:** leads with dated facts, renames, deprecations and limits, retries with exact API names, and finds a working Python launcher first.
- **Search:** 10 new symptom lines in `SYMPTOMS.md`; `vault.py --brief` and `--full` options.

## Unreleased: leaner context, same accuracy

### Improved
- **Smaller always-loaded footprint:** skill, agent and command descriptions trimmed from about 1,720 to 1,120 tokens, with the same routing on a 30-request test.
- **Leaner router:** the `lihfolk` skill body went from about 1,610 to 720 tokens; the folder map, specialist list and extra tips now live in `skills/lihfolk/references/vault-map.md`.
- **Compact search output:** `vault.py` prints TL;DR bullets and section lists without boilerplate, about 594 tokens per task instead of 745. `--full` keeps the old output and `--brief` is cheaper still.
- **Sharper lookup agent:** replies lead with dated facts, renames, deprecations and limits, retry once with exact API names, and check the Python launcher once.
- **Better search:** 10 new symptom lines (dev hit@3 85% to 92%, held-out test unchanged at 93%), including mesh streaming overriding `RenderFidelity`.
- **Benchmark v2.1:** lookup arm re-graded blind next to the original answers: 56.2 vs 55.4 on set A and 61.6 vs 60.7 on set B under the same graders (`benchmark/RESULTS_v2.1.md`).

## 2.3.0 (2026-10-29): Assets, sound and combat

**Highlights:** find and import original assets with one command, premium sound design, new combat VFX and animations, a reusable house-building kit, and a plugin that works from any project folder.

### Added
- **Asset finder (`/lihfolk:assets`):** searches the LihFolk Asset Pack catalogues for models, materials, skies, animations and VFX, offers only finished assets and gives import steps for each type. Set `LIHFOLK_ASSETS` to the pack folder.
- **Sound design (`lihfolk-sfx`):** a typed Luau sound module with layered, varied sounds, voice pooling, volume buses and animation-marker sync, plus a guide to licensed premium sources (Roblox's licensed library first, then Sonniss, BOOM Library, A Sound Effect, Soundly and Splice) with a quality checklist.
- **Combat VFX:**
  - **SpinAttack:** an escalating wind vortex, a rune circle and a frontal crescent finisher.
  - **VoidImpact** and **VoidOrb:** a charge, hold and release orb with an ink-burst impact.
- **Animations:** new SpinAttack and TwistBackflip clips (in progress, with previews).
- **House building:** a House Construction Method note (cabin, cottage, medieval, modern and fantasy) and `lihfolk_house.py`, a Blender kit for walls with real openings, snowy gable roofs, chimneys, windows, doors and steps, with a floating-part check.
- **New knowledge:**
  - VFX readability and value, and escalation without clutter;
  - whole-body moves and locomotion clips;
  - art-direction principles, UI Style Directions (20 named UI styles with a Luau style preset) and blind-review method.
- **Glossy icon style** for the LihFolk UI kit.
- **Reviewer guide (`REVIEWERS.md`):** every claim with the command that verifies it.
- **Benchmark v2 (`benchmark/`), fully reproducible:**
  - **Main set:** 94.4% with the vault, 68.4% without.
  - **Held-out set:** 94.8% with the vault, 91.7% without.
  - **2025-2026 Roblox changes:** 22.8/23 with the vault, 8.2/23 without.
- **Sample data:** `LihFolk-Asset-Pack-Sample.zip` (about 120 MB) on the release, sample catalogues for the asset finder and a sample quality ledger.

### Improved
- **Plugin:**
  - **Lookups:** vault lookups work from any project folder, using `py` on Windows.
  - **Clearer skill triggers:** general UI requests go to `roblox-ui-builder` and the house style to `lihfolk-ui`, and installing ready-made modules is separate from building custom systems.
  - **Council:** the council's method now has its own skill (`council-method`); `/lihfolk:council` works as before.
- **Code checks:**
  - standard Roblox game loops that call other modules pass;
  - `.lua` files are checked inside Roblox projects only;
  - the bash and PowerShell engines give identical results.
- **Animations:**
  - SwordLight3 now passes the 8.5 bar;
  - Sprint has a full arm pump;
  - Jump has arms that lead the push-off and a deep landing;
  - Jump and Idle are approved, so 9 clips are now ready to use.
- **Systems library:**
  - Studio tests use separate leaderboards;
  - paid boosts always grant;
  - leaderboard saves finish before shutdown;
  - tests ship in their own `test.project.json`.
- **Knowledge accuracy:**
  - the Game Passes ownership pattern;
  - purchase saves that keep user ids and metadata;
  - the current group-role API;
  - remote event ordering;
  - the 2026 DataStore limits;
  - particle flipbook and screen-flash formulas;
  - refined index pages.
- **Asset Pack:** catalogues for animations and VFX, a top-level `INDEX.md`, and a status on every row.
- **Obsidian:**
  - the whole look now runs on CSS snippets;
  - a V2 ringed planet on the home page;
  - a warp-speed new-tab screen with rainbow shooting stars and portal rifts, under an "Income Multiplier." greeting;
  - rainbow graph colours, with the optional LihFolk Graph plugin colouring every link;
  - the Everforest base theme ships with its MIT licence.

### Getting started
Play-test the Luau modules (systems, VFX, SFX) in Studio inside your own game, then upload your assets and paste their ids where the modules show `REPLACE_ME`.

## 2.2.0 (2026-10-29)
- 1,294 notes (+~430): 116 original gap notes (vehicles, maps, weather, combat AI, systems, camera, audio, genres, growth, testing/QA, AI workflow), new section 58 Player QoL and Game Tweaks (29 notes), 57 API and Concept Atlas (269 hubs), 13 lessons-learned notes, VFX recipes (slash, ice ball approved reference).
- Graph: Related links (80% same-section), section-local Connected notes, richer tags: per-section galaxies. Search accuracy held (top-3 93%).
- Speed/cost: lihfolk-lookup agent (haiku) for vault lookups; quality-score no longer auto-triggers; hook blocks only on errors. Benchmark: LihFolk 61.8/64 vs plain Claude 45.4/64.
- LihFolk VFX: frontal-only slashes (SlashSweep), IceExplosion, IceBallCast, more presets in progress. Celestial V2 Obsidian theme, Style Settings panel, Moon Map canvas.
- Vault folder renamed to `LihFolk Vault V2`.

## 2.1.0 (2026-10-28)
- **LihFolk systems library** (`lihfolk-systems` skill, `/lihfolk:new-system`): 19 typed Luau modules (Net validation, session-locked PlayerData, idempotent Receipts, Shop, EggHatch with 2026 odds rules + PolicyService, Codes, DailyRewards, Rebirth, Quests, Leaderboard...). Play-test in Studio before publishing.
- **Code-check hooks** + `/lihfolk:audit`: 17 checks on every Luau file the AI writes (sh/awk + PowerShell engines, no Node/Python needed).
- **Expert delta notes**: Roblox changes 2025-2026 (async renames, Server Authority, Input Action System, TextChat lockdown, DataStore limits, odds rules, money changes) and What AI Models Get Wrong in Roblox; `LihFolk Vault V2/_data/roblox_facts_2026.json`.
- **Token savings**: TL;DR on 655+ notes, `INDEX_SLIM.md`, `ROUTER.md`, section maps, `build_index.py`; per-note token costs; skill descriptions -58%; `roblox-vault-research` merged into the router; accuracy rule for high-stakes topics. See Token Cost Benchmarks.
- **Quality**: minimum score 8.5; model gates A15-A18 (symmetry, alignment/seating, self-intersection, clean caps); feature close-ups in reviews; arm-twist gate for animation.
- **New knowledge**: 56 Field Notes (21 notes), curve modelling notes, Human Swing Biomechanics, Locomotion and Melee Reference Numbers.

## 2.0.0 (2026-10-28): LihFolk Vault V2
- First public plugin + vault release: 800+ notes, knowledge router, quality-score (9/10 rubrics with a learning ledger), council (Quick/Standard/Full), Blender modelling with quality gate, trend-game playbook, 10 specialist skills.
- Vault redesign: new home page, 8-domain graph colours, theme.
- Removed third-party scraped assets (Kenney, Poly Haven) from the release.
