# Changelog

## 2.5.0 (2026-10-29): Ability VFX, Figma, engine reference cards

**Highlights:** ability VFX beyond slashes, a Figma-to-Roblox UI skill, 32 engine reference cards and a limits cheat sheet verified against the official docs, every 2025-2026 API rename, and a lookup that is cheaper per search and checks API names before answering. On four fresh held-out benchmark sets the plugin scores 91-94%, 3 to 13 points above the same model without it.

### Added
- **Ability VFX (`LihFolkVFX_Abilities`):** projectiles, auras, AoE ground warnings, shields, beam lasers, heals and buffs, teleports, level-up bursts, camera shake and hit-stop, with per-preset budgets, built-in looks when no textures are uploaded, and a server-validated replication pair. Four vault notes: projectiles, telegraphs, auras and shields, replicating VFX.
- **Figma to Roblox (`lihfolk-figma`):** Figma frames to ScreenGuis through the Figma MCP or a deterministic exported-JSON converter (`figma_to_roblox.py`, with tests and a sample), variables to a Luau theme, and four notes including designing VFX flipbooks in Figma.
- **62 Engine Reference Cards:** 32 cards (Player, Humanoid, Workspace, BasePart, DataStoreService, MemoryStoreService, RemoteEvent, RunService, TweenService, TeleportService, MarketplaceService and more) with the members that matter, defaults, limits, yields, replication, mistakes and checklists.
- **Engine Limits, Quotas and Defaults cheat sheet:** about 95 sourced rows across DataStores, MemoryStores, messaging, HTTP, remotes, teleports, badges, instances, defaults, UI, VFX, audio, terrain and publishing.
- **API Renames and Deprecations 2025-2026:** all 46 `...Async` renames plus reserved servers by `ReservedServerId`, collision groups on WorldRoot, chat permission APIs, subscriptions and more; teleport, chat, badge and physics notes updated.
- **61 Thumbnails and CTR:** eight notes on specs and policy, composition, genre patterns, personalization testing, the CTR-to-CCU arithmetic, production and a review rubric.
- **Stylized creatures:** a Blender creature builder (`lihfolk_creature.py`: soft forms, painted bake, light rig, swim loop) and a note; **voxel chibi heroes:** a class-roster and rarity-ladder style note.
- **New guides:** text filtering with TextService, and clickable/interactive parts (ClickDetector, ProximityPrompt, Touched).
- **Benchmark sets C-F:** held-out sets written without access to the vault, with source-checked keys, blind three-arm runs and graded results.

### Improved
- **Cheaper, sharper lookup:** search output about 626 to 577 tokens (repeats printed once, section list for the top note only); `vault.py --api` checks API names against the snapshot plus `api_overrides.json` for the newest doc deprecations, and the lookup agent checks every name it cites. Lookups batch at most 6 questions so no answer gets squeezed, and answers use the lookup's dated facts.
- **Everyday phrasing:** small synonym additions; a 30-question everyday probe went from 22 to 30 right notes in the top 3, with the held-out eval steady at 93%.
- **Accuracy fixes:** about 40 corrections and additions verified against the docs (Blender glTF export, receipts, remotes, streaming, pathfinding, localization, lighting, buffers, DataStore throttling, UI list ordering and more), and more cross-checked facts in `consistency.py`.
- **Originality:** everything not written for this project is gone: the bundled Everforest theme (replaced by our own Celestial base styles), third-party credits and study notes, and the link library cut to official documentation only.

## 2.4.0 (2026-10-29): Worlds, onboarding and top-game teardowns

**Highlights:** a worldbuilding skill and a tutorial skill, 31 new teardowns of top Roblox games, leaner token use with higher search accuracy, and the Celestial look across the whole app.

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
  - art-direction principles, UI Style Directions (16 UI style directions in four families, with a Luau style preset) and blind-review method.
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
  - our own Celestial base styles under every snippet.

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
