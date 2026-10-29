---
tags: [pipelines, production, tooling, automation, workflow, type/guide, area/pipelines, level/intermediate, area/monetization]
---
# Pipeline Design Principles

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Editing the output instead of the source.
> - Avoid: Installs that create duplicates on re-run.
> - Avoid: Ids typed by hand. One wrong digit plays someone else's sound.
> - Source of truth named for every content type
> - Stable id scheme used in files, attributes and config
> - Every install idempotent and marked with attributes
>
> Cost: TL;DR ~130 tok · whole note ~5.5k tok. Read more: ## Principle 1: one source of truth per thing, and it is not the place · ## Principle 2: every install is idempotent · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A pipeline is the path a piece of content travels from "someone had an idea" to "it is live in a published place and we can change it again safely". Every Roblox game has pipelines whether or not anyone designed them: a modeller exporting a mesh, a designer pasting numbers into a ModuleScript, a scripter syncing files with Rojo. The difference between a team that ships weekly and a team that is scared of its own place is almost never talent. It is whether those paths are **repeatable, checkable and reversible**.

This note is the shared vocabulary for the rest of the section. Each later note ([[Art Pipeline - Concept to In-Game Asset]], [[Audio Pipeline]], [[Code Pipeline - Rojo Git and CI]] and so on) is a concrete recipe built on these rules. The overview of asset pipelines in production lives in [[Asset Pipelines]]; the animation-specific pipelines live in the Animation section ([[Pipeline - New Animated Weapon]], [[Pipeline - Importing Animated Enemies]], [[Pipeline - Arm IK Baking and QA]], [[Studio Tooling Architecture]]) and are not repeated here.

Most examples come from **one production game** (the reference project): a live action game built over a few weeks by one owner and several AI coding agents working through the Roblox Studio MCP server and Blender MCP. That project ran dozens of pipelines hundreds of times, so its failures are well documented. Its numbers are marked "measured in one production game".

## What a pipeline is made of

Every pipeline, from a sound effect to a whole zone, has the same parts. Name them explicitly and most design questions answer themselves.

| Part | Question it answers | Example (weapon icon) |
|---|---|---|
| **Source** | Where does the truth live? | the `.glb` and the setup file on disk, not the Studio copy |
| **Stages** | What transforms happen, in what order? | parse, render beauty + emission, post-process, upload, write id into config |
| **Artifacts** | What does each stage produce, in what format? | `.exr` passes, a 512 px `.png`, an asset id |
| **Naming** | How does a stage find its inputs without a human? | `<id>.png`, `parts_<id>.json`, `<id>=<file>.glb` in a map file |
| **Gates** | What must be true before the next stage runs? | file exists, size within budget, no forbidden id, compiles |
| **Install** | How does the artifact get into the place? | an idempotent Luau stage that writes one config row |
| **Rollback** | How do we undo it? | the previous value stored in an attribute, or a saved `.rbxm` |
| **Record** | How will the next person know what happened? | changelog line, id map JSON, note in the knowledge base |

If you cannot fill in a row, that is where the pipeline will break.

## Principle 1: one source of truth per thing, and it is not the place

A Roblox place is a terrible source of truth. It has no diff, no merge, no blame, and (in a shared place) several people or agents editing it at once. Studio's own version history is coarse: it restores the whole place, not one module (see [[Version History and Backups]]).

So decide, per content type, where the source lives:

| Content | Recommended source | Why |
|---|---|---|
| Scripts | Git repo, synced by Rojo | diffable, reviewable, CI can check it ([[Code Pipeline - Rojo Git and CI]]) |
| Meshes and props | `.blend` + a build script (`build_<thing>.py`) | rebuildable when the style changes ([[Blender Automation with Python]]) |
| Balance numbers | spreadsheet or JSON, generated into a ModuleScript | designers edit numbers, not Luau ([[Data and Config Pipeline - Spreadsheets to Game]]) |
| Asset ids | JSON id maps written by the upload step | the only record of what was uploaded from what ([[Asset Upload Automation with Open Cloud]]) |
| UI layouts | builder modules that bake the static StarterGui copy | the saved copy and the runtime copy cannot drift ([[UI Asset Pipeline]]) |
| Level geometry | the place, plus exported manifests | level work is spatial; keep it in Studio but export a manifest to rebuild or audit ([[Environment and Level Pipeline]]) |

The reference project learned this the hard way: for several weeks scripts lived only in the place, and agents had to "compare Studio's source with your local base file" before every overwrite, because another session might have changed it. When everything was finally driven from files, those conflicts became visible diffs instead of silent losses.

**Nuance:** "the place is not the source" does not mean "never edit in Studio". Level layout, lighting tuning and VFX timing are faster by eye. The rule is: when you edit in Studio, **export what you changed back to a file** (a manifest, a JSON of positions, an `.rbxm` of the model) before you forget.

## Principle 2: every install is idempotent

An install step must give the same result whether it runs once or five times. This is the most important rule in the section, because in practice every install runs more than once: it fails halfway, someone re-runs it after a fix, two people run it, a new asset arrives and the whole batch runs again.

Concretely:

- **Find or create, never just create.** Look up the target by a stable name or a tag before making it.
- **Write values, do not add them.** `part.Size = target`, not `part.Size += delta`.
- **Mark what you touched.** Put an attribute on each changed instance (`InstalledBy = "IconPass"`, `InstallVersion = 3`), so a re-run can skip it or update it, and a cleanup can find it.
- **Store the old value before the first write.** The reference project used attributes named `Pre<Pass>_<Property>` (`PreTex_Material`, `PreHero_CFrame`, `PreBuilderFont`). The first run writes the backup; later runs see the backup exists and leave it alone. One revert function walks the attributes and restores.
- **Dry run by default.** The installer reports what it would do; a flag makes it act. The project's cleanup tool shipped with `dryRun = true` as the default and caught several wrong deletions that way.

```lua
--!strict
-- Idempotent "set a property, remember the original" helper.
-- Re-running never overwrites the stored original, so Revert always restores the
-- value from before the FIRST run of this pass.
local Pass = {}

local function attrName(pass: string, prop: string): string
	return "Pre" .. pass .. "_" .. prop
end

function Pass.set(inst: Instance, pass: string, prop: string, value: any)
	local key = attrName(pass, prop)
	if inst:GetAttribute(key) == nil then
		-- Attributes cannot hold every type (no Instance refs, no tables).
		-- CFrame, Vector3, Color3, number, string, boolean, UDim2 and Font are fine.
		inst:SetAttribute(key, (inst :: any)[prop])
	end
	(inst :: any)[prop] = value
end

function Pass.revert(root: Instance, pass: string): number
	local prefix = "Pre" .. pass .. "_"
	local restored = 0
	for _, inst in root:GetDescendants() do
		for key, old in inst:GetAttributes() do
			if string.sub(key, 1, #prefix) == prefix then
				local prop = string.sub(key, #prefix + 1)
				;(inst :: any)[prop] = old
				inst:SetAttribute(key, nil)
				restored += 1
			end
		end
	end
	return restored
end

return Pass
```

**When not to:** attribute backups are cheap per instance but they add up. A pass that touches 500,000 instances adds 500,000 attributes to the place file. For huge passes, export a JSON of the old values to disk instead and keep only a pass marker in the place.

## Principle 3: gates between stages, cheap ones first

A gate is a check that stops the pipeline before a bad artifact moves on. Order them by cost: string checks before compiles, compiles before Studio runs, Studio runs before human review.

Gates the reference project used on every script it saved (measured in one production game; each one caught real bugs):

1. **Compiles.** `loadstring(source)` in the command bar or plugin context returns a function, not `nil, err`.
2. **No use-before-definition.** A small scanner flagged calls to a `local function` before the line that defines it. In Luau that call hits `nil` at runtime, not at compile time, so the compile gate misses it. The scanner caught real crashes.
3. **Size under the cap.** A Script's `Source` has a hard limit of 200,000 characters (measured in one production game; the exact wording of the limit is not in the API reference, so treat it as observed). Two core modules sat at about 199,000 and 199,800 characters; the rule became "never edit those, extend through a child module".
4. **Fresh require.** In Edit mode `require` caches a module for the session, so a test require sees the old code. The gate clones the module beside the original, requires the clone, checks it returns the expected shape, then destroys the clone.
5. **Content rules.** Reserved names (a move called `Origin` once replaced a RemoteEvent called `Origin` and broke all damage for one weapon), a banned asset id list, no em dashes in player text.

For assets the equivalents are triangle counts, texture sizes, naming patterns, "is the id in the id map", and loudness measured within range.

**Nuance:** gates must be fast enough that nobody skips them. If the full check takes five minutes, people will run only the install. Split into a fast gate on every run and a slow audit nightly or before release ([[Build Test and Release Pipeline]]).

## Principle 4: name things so machines can find them

Pipelines stall at the hand-off between stages when a human has to say "the file is over there". Fix that with names.

| Rule | Example | Why |
|---|---|---|
| One stable id per content item, lowercase, no spaces | `ember_blade`, `zone11_crater`, `ui_shop_header` | used in file names, attributes, config keys, URLs |
| Files are named by id and stage | `<id>.glb`, `<id>_beauty.exr`, `<id>.png`, `upq_ids_<tag>.json` | a stage finds its input by formula |
| Mesh names inside an upload carry the target | `<id>__<Part>` | the installer maps uploaded mesh to live part without a table |
| Studio objects carry their id as an attribute | `ItemId = "ember_blade"` | renames in Explorer do not break lookups |
| Never rely on Selection or "the first one found" | find a top-level Model by name | several imports can sit in Workspace at once |
| Avoid characters that tools mangle | no dots or spaces in mesh names | the reference project had to re-upload parts whose names contained dots |

Also keep paths short. Blender and many native Windows executables fail on paths longer than 260 characters (measured in one production game; it is the classic Windows `MAX_PATH`). The project ran every Blender and Python call through the short 8.3 form of a deep temp folder.

## Principle 5: small calls, sliced jobs

Studio is single-threaded for your Edit-mode scripts. A long loop in the command bar, a plugin action or an MCP `execute_luau` call freezes the whole editor until it ends, and in Team Create every collaborator waits.

Rules that came out of the reference project (measured in one production game):

- **Each Studio call under about 1.5 s.** Studio froze for about 25 minutes when roughly 18 offline baker processes ran while in-Studio simulations were also going.
- **Slice long jobs into resumable steps.** Keep a cursor in a module-level table or `_G`, process N items per call, return progress. A bake that needs 47 frames at about 0.5 s per frame runs as many short calls, each well under budget.
- **Heavy maths offline.** Python (or [[Lune]], or Node) does IK solves, image processing, audio analysis; Studio only does I/O.
- **Throttle offline workers.** At most two Python processes per agent, each with `OMP_NUM_THREADS=1` (and the OpenBLAS / MKL equivalents), so numpy does not grab every core.
- **Respect HttpService limits.** About 500 requests per minute place-wide (Roblox docs list 500 per minute for HttpService). Post one JSON per batch, not one per item.

See [[Batch Processing Tools in Studio]] for the slicing pattern in code.

## Principle 6: humans own the steps machines cannot do, and those steps are written down

Some steps cannot be automated (as of October 2026):

- **Importing a local file into Studio.** No script or MCP call can read your disk into the place. File > Import 3D is manual (or a plugin with a file picker).
- **Publishing animations, in some setups.** Open Cloud can upload animation assets, but many teams still publish from the Animation Editor; see [[Publishing Animations]].
- **Creating Developer Products and Game Passes** is done on the Creator Dashboard (there are Open Cloud endpoints for some monetization objects; check [[Open Cloud APIs]]).
- **The play test.** Automated checks catch wrong values; only a person catches "this feels bad".

Design the pipeline so the manual steps are **few, early and checkable**: the reference project's weapon pipeline asked a human for exactly one import per weapon, and the very next automated stage (`probe`) reported whether the import was there and correct. When it was missing, the agent did every offline step first, then asked for the import once, with the exact menu path and options to use.

## Principle 7: reversible beats careful

You will make mistakes in a live place. Plan for undo before you need it.

| Mechanism | Granularity | Cost | Use for |
|---|---|---|---|
| Studio version history | whole place | free | last resort, see [[Version History and Backups]] |
| `.rbxm` export of a model or folder to disk | one subtree | disk space | before deleting or replacing anything big |
| `Pre*` attributes | per property | a few bytes per instance | property passes (textures, fonts, positions) |
| JSON snapshot on disk | anything serialisable | disk | big passes, terrain regions, layouts |
| Git | scripts | free | everything code ([[Git and Source Control for Roblox]]) |
| Kill switch (a config flag or attribute) | one feature | one `if` | new systems in the live game |

Two warnings from the reference project:

- **Never use undo in a shared place.** `ChangeHistoryService` keeps one undo stack per place session, shared by everyone editing. An agent once undid "about 40 waypoints" to recover terrain and rolled back other people's work; each scripted change also adds a waypoint that wipes redo. Snapshot first instead (for terrain: `Terrain:CopyRegion` into a `TerrainRegion` stored in ServerStorage). See [[Safe Changes in a Shared Place]].
- **Backups inside the place are not free.** The project once held 1.07 million instances, many of them backup folders, and Studio dropped to 15 fps. The rule became: at most one small safety copy per in-progress pass, deleted after verification; everything else on disk. See [[Case Study - Instance Cleanup and Place Size]] and [[Case Study - Cutting a Million Instances]].

## Principle 8: record as you go

Pipelines produce facts nobody will remember: which id is which mesh, why a value was 0.825, which pass changed a font. The reference project kept three records, and they paid for themselves daily:

1. **Id maps.** Every upload wrote a JSON of `name -> assetId` (one file per batch). Installers read the map; nobody types an id.
2. **A dated changelog line per change**, with a short tag (`LEVELS-2`, `HUB-HERO`), what changed, the backup location, and an honest status ("Edit only, not play-tested"). The tag is greppable in code comments too.
3. **A knowledge base** (an Obsidian vault plus a long notes file) with rules, gotchas and per-system notes, regenerated partly from a data dump of the place. See [[Documentation and Knowledge Bases]].

The "not play-tested" label deserves emphasis. A pipeline that ran its gates cleanly has proven the data is consistent, not that the game is fun or even works in Play. Saying so in the record stops the next person assuming more than was checked.

## Principle 9: build the pipeline on the second time, not the first

Automating something you have done once usually automates the wrong thing. The reference project's weapon pipeline was built while adding one weapon by hand, then reused: the first run took about 50 minutes of wall clock (about 12 of them waiting out someone else's play test), and the recorded total per weapon settled at about 1 to 1.5 hours, most of it the creative kit design and an arm bake. The same day it ran a whole batch of new weapons, and each new edge case the batch exposed became a flag or a branch, not a rewrite.

| Times you have done it | What to build |
|---|---|
| 1 | nothing; write down the steps |
| 2 | a checklist and the scripts you wished you had |
| 3+ | a driver that chains the scripts, with gates and a dry run |
| 10+ | batch mode, a queue, resumability, a report |

**When not to automate at all:** one-off creative work (a cutscene, a boss arena), things whose rules change every time, and anything where the check is "does it look right" and the look changes per item. Automate the boring edges around it instead (import, naming, upload, registration).

## Principle 10: pipelines for agents need the same rules, written harder

AI coding agents driving Studio and Blender through MCP (see [[Roblox Studio MCP Server]], [[Blender MCP]], [[AI Agents and Autonomous Workflows]]) are fast and tireless, and they follow written rules literally. That makes pipeline discipline more important, not less. The reference project packaged its weapon pipeline as an agent **skill** (triggered by phrases like "added <X> weapon" or "new blade"), backed by a toolkit folder (an offline driver, Studio stage scripts, a kit template) and a written checklist with the numbered steps and measured times. Any new agent session could follow it to add a weapon end to end.

What made it work, in order of importance:

1. **Hard rules at the top**, phrased as never/always: Edit mode only, never start or stop Play (others are play-testing), one Studio call at a time under 1.5 s, one insert into shared config modules with re-read, backup, compile, scan and clone-require.
2. **Each step is one command** with its expected output ("repeat until it says STAGED").
3. **Times per step**, so the agent (and the human) knows when something is stuck.
4. **A gotcha list** written from real failures (`require` caches in Edit, so clone-require; reserved move names that collide with remotes; long scratch paths break native executables, so call tools through short paths and start helper servers as separate processes).
5. **The manual steps called out**, with the exact words to send to the human.

The detailed weapon steps are in [[Pipeline - New Animated Weapon]]; the safety rules are in [[Safety Rules for AI Agents in Studio]] and [[Multiple Agents in One Studio]].

## The anatomy of a good pipeline, as a template

```text
pipeline: <name>
source of truth: <files / repo / sheet>
id scheme: <how one item is named everywhere>
stages:
  1. <stage>  in: <files>  out: <files>  tool: <script>  time: <measured>
     gate: <check that must pass before stage 2>
  2. ...
install: <idempotent Studio stage>, dry run default, marks instances with <attr>
rollback: <how>, tested on <date>
manual steps: <list>, asked for at <stage>
record: id map <file>, changelog tag <TAG>, note <title>
failure modes seen: <symptom -> cause -> fix>
```

Fill this in before you write code. It is a page of text and it will save days.

## Common mistakes

- **Editing the output instead of the source.** You fix a texture in Studio; the next rebuild from Blender overwrites the fix. Fix the source, rebuild.
- **Installs that create duplicates on re-run.** Two `ShopHeader` frames, three copies of a sound. Find or create, always.
- **Ids typed by hand.** One wrong digit plays someone else's sound. Ids come from id maps or the upload response.
- **No dry run on destructive steps.** Deletion and mass replace must show their plan first.
- **Gates that only run on the author's machine.** If it matters, it runs in CI or in a shared Studio tool everyone calls.
- **Long Studio calls.** A 20-second loop freezes every collaborator. Slice it.
- **Backups that live forever in the place.** Export to disk, delete from the place after verification.
- **No record.** A pass nobody wrote down cannot be reverted, because nobody knows what it touched.

## Checklist

- [ ] Source of truth named for every content type
- [ ] Stable id scheme used in files, attributes and config
- [ ] Every install idempotent and marked with attributes
- [ ] Original values stored before the first write (attributes or JSON on disk)
- [ ] Dry run default on anything destructive
- [ ] Gates ordered cheap to expensive; fast gate on every run
- [ ] Studio calls sliced under about 1.5 s
- [ ] Manual steps listed, early, with a probe that checks them
- [ ] Id maps written by the upload step, read by the install step
- [ ] Changelog tag and honest test status recorded

## See also

[[Asset Pipelines]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Batch Processing Tools in Studio]] · [[Build Test and Release Pipeline]] · [[Studio Tooling Architecture]] · [[Safe Changes in a Shared Place]] · [[Release Process and Rollbacks]] · [[Documentation and Knowledge Bases]] · [[Studio Plugins and Local HTTP Bridges]]

## Connected notes
<!-- auto-links:start -->
[[Case Study - Building a Game with AI Agents]] · Writing Your Own MCP Server · MCP Workflows for Building Worlds · [[Icon and Thumbnail Rendering Pipeline]] · Working with AI Assistants in Studio · MCP Workflows for Scripting and Debugging
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Command Bar and Studio Scripting]] · [[Working with AI Assistants in Studio]] · [[MCP Workflows for Building Worlds]] · [[Live Content Pipeline]] · [[Character and Creature Pipeline]] · [[Localization Pipeline]]
<!-- related:end -->
