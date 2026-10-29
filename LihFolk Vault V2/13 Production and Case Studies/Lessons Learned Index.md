---
tags: [production, lessons, index, moc, case-study, type/case-study, area/production, level/intermediate, area/monetization]
---
# Lessons Learned Index

This is a map of the transferable lessons from one project (the reference project): a live action game built over a few weeks by an owner directing several parallel workstreams in one Studio place. Each lesson is one line, says what happened, and links to the note that explains it. Use it as a pre-mortem checklist for your own project: for each line, ask "could this happen to us, and what would we see first?"

Labels: **(measured)** = numbers from the reference project; everything else is the lesson drawn from it. The full story is in [[Post-Mortem - Building a Melee Action Game]].

## Planning and scope

| Lesson | What happened | Read |
|---|---|---|
| Count content before building | "2 types + 1 mini-boss per zone" became dozens of designs, which made the cost visible | [[Planning and Scoping a Roblox Game]] |
| Gate on style before volume | A generated lobby kit was swapped in live and reverted the same day as low-detail | [[Planning and Scoping a Roblox Game]] |
| Build reusable parts first | A staging map was deleted; its enemies survived because they were map-independent | [[Case Study - Enemy Roster Rebuild]] |
| Write pacing in player minutes | Zones shrunk to 40% and restored the same day; a stage corridor built and reverted in a day | [[Planning and Scoping a Roblox Game]] |
| Delete the old version last | A replaced lobby (a few thousand instances) had to be copied back from an older version | [[Safe Changes in a Shared Place]] |
| Make budgets checkable | Enemy triangle counts ran 3 to 7x the plan after a redesign (measured) | [[Planning and Scoping a Roblox Game]], [[Art Budgets - Triangles Draw Calls Memory]] |
| Decide one place vs many early | The place grew until join time and Studio speed forced a cleanup | [[Case Study - Fast Join and Deferred Loading]] |
| Keep a pending-decisions list | About twenty open owner decisions at one point; questions stopped repeating | [[Documentation and Knowledge Bases]] |
| Ask the owner in batches | A 30-question sitting produced a plan that held where it was asked | [[Planning and Scoping a Roblox Game]] |

## Team and workflow

| Lesson | What happened | Read |
|---|---|---|
| Own areas by instance path | Without it, one workflow archived another's work as "foreign" | [[Team Roles and Workflows]] |
| Write contracts before splitting a feature | A stage feature split between two workstreams met without integration bugs | [[Team Roles and Workflows]] |
| Schedule play-testing as a role | "Nothing since this date is play-tested" became a standing note | [[Team Roles and Workflows]], [[Multi-Client and Live Testing]] |
| Keep Play mode out of a shared session | One session's Play check locked everyone out of Edit | [[Working with AI Assistants in Studio]] |
| Hand testers a specific checklist | Builders know what they could not check in Edit | [[Team Roles and Workflows]] |
| Clear test flags | A forced intro and a stale test save key changed what the next tester saw | [[Release Process and Rollbacks]] |
| One style, one header, one button | Ended per-screen restyles | [[UI Design Systems]] |
| Reserve names | A clip named like a sibling RemoteEvent broke a kit's damage | [[Team Roles and Workflows]] |
| Put admin ids in one module | Admin ids lived in six scripts | [[Team Roles and Workflows]] |
| Use review rubrics and independent judges | A UI audit reached 10.00 over more than 80 screen views (measured) | [[Team Roles and Workflows]] |

## Safe changes

| Lesson | What happened | Read |
|---|---|---|
| Never use undo in a shared place | Undo went about 40 waypoints back and erased other sessions' work (measured) | [[Safe Changes in a Shared Place]] |
| Record originals as `Pre*` attributes | Zero-instance undo data; selective revert per operation | [[Safe Changes in a Shared Place]] |
| Snapshot terrain before bulk writes | A regeneration overwrote other work; hundreds of rock placements were unrecoverable | [[Safe Changes in a Shared Place]] |
| Terrain colours are global | Darkening one zone's grass changed every zone; the workaround removed grass blades | [[Safe Changes in a Shared Place]] |
| Never fill large areas with terrain water | A large sea stalled joining (measured) | [[Safe Changes in a Shared Place]] |
| Read current source before writing | Stale local copies overwrite newer work | [[Working with AI Assistants in Studio]] |
| Clone-require to read module state | `require` in the command bar returns a cached copy | [[Working with AI Assistants in Studio]], [[Module Scripts and Requiring]] |
| Prove no references before deleting | Including dynamic names, ObjectValues and comments | [[Case Study - Instance Cleanup and Place Size]] |
| Budget script size | Two modules crossed 200,000 characters and could not be saved (measured) | [[Safe Changes in a Shared Place]] |
| One change at a time | Failures stay attributable | [[Safe Changes in a Shared Place]] |
| Backups belong outside the place | In-place backups drove the place to 1.07M instances and 15 fps (measured) | [[Case Study - Instance Cleanup and Place Size]] |

## Verification

| Lesson | What happened | Read |
|---|---|---|
| Label every change "Edit-verified" or "play-tested" | Makes test lists and release risk visible | [[Documentation and Knowledge Bases]] |
| Prefer numbers to screenshots | Raycast grids, fit errors, overlap counts, deep-equal refactor checks | [[Working with AI Assistants in Studio]] |
| Compile, scan for use-before-definition, clone-require | Caught runtime crashes that compiled fine | [[Working with AI Assistants in Studio]] |
| Edit mode has blind spots | No physics, no rate emitters, no ViewportFrame animation | [[Testing Animations in Studio]], [[Engine Gotchas]] |
| Avoid quadratic pattern searches over sources | A `[^\n]*X` search pinned a core on a long single-line module | [[Working with AI Assistants in Studio]] |
| Keep calls short and heavy jobs offline | About 18 parallel bake processes froze Studio for about 25 minutes (measured) | [[Working with AI Assistants in Studio]] |
| `ipairs` stops at the first nil | A phone page list silently skipped the armour page | [[Case Study - Phone UI Overhaul]] |
| Unbounded wait loops freeze clients | A `while true` waiting on a destroyed parent froze the UI on click | [[Post-Mortem - Building a Melee Action Game]] |
| Report the measured effect of a tuning change | An attack-tempo change flagged its own +41% outlier | [[Case Study - Enemy Roster Rebuild]] |

## Pipelines and assets

| Lesson | What happened | Read |
|---|---|---|
| Five stages: source, export, install, place, verify | A weapon took about 1 to 1.5 hours end to end (measured) | [[Asset Pipelines]] |
| Write an id map for every upload | Prevents lost, invented or confused ids | [[Asset Pipelines]] |
| Install to a library, place from the library | Reinstalls and reverts stay mechanical | [[Asset Pipelines]] |
| Keep blockouts as colliders under art | Collision unchanged by art swaps (1,620-ray check, measured) | [[Asset Pipelines]] |
| Separate identity from appearance | About fifty enemy looks replaced in a day, fit error 0.000 (measured) | [[Case Study - Enemy Roster Rebuild]] |
| Render icons from game models with a hide list | Icons stay true to what players see | [[Asset Pipelines]] |
| Measure every sound's loudness; ban rejected ids | Hundreds of unmeasured ids played unlevelled (measured) | [[Asset Pipelines]] |
| Importer axis conventions in code | GLBs arrive turned 180 degrees; clips needed an axis fix | [[Enemy Import Axis Fix]] |
| Never trust toolbox scripts | A sandboxed copied script could not require config | [[Creator Store and Toolbox Safety]] |

## Animation and Studio-only traps

| Lesson | What happened | Read |
|---|---|---|
| Runtime-registered keyframe clips work only in Studio | Dozens of kits' weapon-part moves would not animate live | [[Case Study - Abilities That Only Worked in Studio]] |
| Publish or bake every clip before release | Hundreds of clips stayed "publish before live" for weeks | [[Publishing Animations]] |
| Keyframe instances dominate instance counts | Baking cut ReplicatedStorage from 392k to 107k (measured) | [[Case Study - Cutting a Million Instances]] |
| Preload clips when a kit loads | First use of an ability was about 5 seconds late | [[Engine Gotchas]] |

## Performance and join

| Lesson | What happened | Read |
|---|---|---|
| ReplicatedStorage is the join cost | Over 100k instances replicated before `game.Loaded` (measured) | [[Case Study - Fast Join and Deferred Loading]] |
| A loading screen hides the wait; it does not shorten it | The team's own conclusion after measuring | [[Case Study - Fast Join and Deferred Loading]] |
| Measure join time per device from the first publish | Custom analytics events for loaded, ready, play | [[Case Study - Fast Join and Deferred Loading]] |
| Defer non-essential kits | Menu kit, armour, pets, drops moved off the join path | [[Case Study - Fast Join and Deferred Loading]] |
| Streaming properties are Studio-only | Scripts cannot set them; a person must | [[Instance Streaming]] |
| Studio speed is team speed | 15 fps and 18 GB at 1.07M instances (measured) | [[Case Study - Instance Cleanup and Place Size]] |
| Representation beats deletion | Buffers in attributes instead of thousands of keyframe instances | [[Case Study - Cutting a Million Instances]] |
| Cull per-enemy work off-screen | Enemy animation had distance LOD but no off-screen cull | [[Animation LOD]] |
| Require kit code lazily | Tens of megabytes of kit source were required at client start (measured) | [[Case Study - Fast Join and Deferred Loading]] |

## UI and phones

| Lesson | What happened | Read |
|---|---|---|
| Scaling the desktop UI is not a phone layout | Text and taps shrank below usable sizes | [[Case Study - Phone UI Overhaul]] |
| Zoom-and-pan is a stopgap | Shipped for one day, retired on schedule | [[Case Study - Phone UI Overhaul]] |
| Design phone panels at one fixed height | W x 430 units; W 764 to 930 on target phones (measured) | [[Case Study - Phone UI Overhaul]] |
| Automate text, tap, gap and overlap checks | About two dozen screens, 0 overlaps at 2 phone sizes (measured) | [[Case Study - Phone UI Overhaul]] |
| Respect the top-bar inset | Elements sat half under the Roblox top bar | [[Safe Areas and Insets]] |
| Change input for phones, not just layout | Sprint on move; bigger touch ability bar | [[Case Study - Phone UI Overhaul]] |
| Player-facing updates are headlines | Too-specific patch notes were rewritten | [[Documentation and Knowledge Bases]] |

## Combat, enemies and balance

| Lesson | What happened | Read |
|---|---|---|
| Migrate systems zone by zone with flags | The old combat script yielded zones to the new service | [[Case Study - Enemy Roster Rebuild]] |
| Inventory side effects before migrating | Hit sounds vanished because the new service never fired the old remote | [[Case Study - Enemy Roster Rebuild]] |
| Size enemies by target height with clamps | Several global scale changes in a few days before this settled | [[Case Study - Enemy Roster Rebuild]] |
| Tie enemy damage to player health when health scales | 40 to 100+ hits to die before a damage floor (measured) | [[Case Study - Enemy Roster Rebuild]] |
| Keep entry gates clear of spawns | Probability ramp toward the next gate | [[Case Study - Enemy Roster Rebuild]] |
| Weighted picks must use real weights | A "1 in 3" item dropped at about 1 in 370 (measured) | [[RNG Drops and Luck Systems]] |
| Price upgrades in minutes of income | Survives later economy changes | [[Economies and Currencies]] |
| Derive numbers from targets | Drop pacing, enemy size and progression speed churned without them | [[Balancing with Spreadsheets and Data]] |

## Release and data

| Lesson | What happened | Read |
|---|---|---|
| Edit-only changes do nothing for players | "Publish to ship" on most entries for weeks | [[Release Process and Rollbacks]] |
| Kill switch every replacing feature | Old paths restorable with one flag | [[Release Process and Rollbacks]] |
| Versioned stores make wipes reversible | Three store bumps; rename back to restore | [[Release Process and Rollbacks]] |
| Keep receipts and settings outside versioned stores | Wipes never touched purchase history | [[Purchase Data and Receipts]] |
| Product ids at 0 hide the shop | Cards with id 0 were hidden for weeks | [[Release Process and Rollbacks]] |
| Old servers keep old code | Restart outdated servers after data or remote changes | [[Release Process and Rollbacks]] |
| Confirm saves succeed | Cloud saves timed out and the place reopened at an older version (measured) | [[Safe Changes in a Shared Place]] |

## Documentation

| Lesson | What happened | Read |
|---|---|---|
| Four documents, four jobs | Map, changelog, decisions, systems notes | [[Documentation and Knowledge Bases]] |
| Later entries win; mark superseded ones | A 300 KB notes file stayed usable | [[Documentation and Knowledge Bases]] |
| Quote the owner | Decisions keep their scope and strength | [[Documentation and Knowledge Bases]] |
| Generate data-heavy notes from the place | Hand tables of enemies went stale | [[Documentation and Knowledge Bases]] |
| Every entry has a revert line | Reverts nobody can find are not reverts | [[Documentation and Knowledge Bases]] |
| Tooling must earn its upkeep | A knowledge graph was switched off for routine work | [[Documentation and Knowledge Bases]] |

## The five that matter most

If you keep only five:

1. **Never undo in a shared place; record originals instead.**
2. **Play-test on a schedule; label everything else "Edit-verified".**
3. **Keep backups and imported sources out of the place.**
4. **Measure join time and ReplicatedStorage size from the first publish.**
5. **Settle pacing targets in player minutes before rebuilding the world.**

## See also

- [[Post-Mortem - Building a Melee Action Game]]
- [[Planning and Scoping a Roblox Game]], [[Team Roles and Workflows]], [[Asset Pipelines]], [[Documentation and Knowledge Bases]]
- [[Working with AI Assistants in Studio]], [[Safe Changes in a Shared Place]], [[Release Process and Rollbacks]]
- [[Case Study - Phone UI Overhaul]], [[Case Study - Instance Cleanup and Place Size]], [[Case Study - Fast Join and Deferred Loading]], [[Case Study - Enemy Roster Rebuild]]
- [[Troubleshooting Table]] and [[Engine Gotchas]] in the Animation section

## Connected notes
<!-- auto-links:start -->
[[Team Collaboration Start Here]] · Case Study - Building a Game with AI Agents · Pipeline Design Principles · [[Scoping and Roles for Small Teams]] · AI Agents and Autonomous Workflows · Multiple Agents in One Studio
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Building a Game with AI Agents]] · [[Pipeline Design Principles]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Case Study - Building LihFolk V2 with AI Agents]] · [[Live Incident Response and Post-Mortems]] · [[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Template Reskin Checklist - One Codebase, New Game]]
<!-- related:end -->
