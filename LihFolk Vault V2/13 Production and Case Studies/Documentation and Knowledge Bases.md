---
tags: [production, documentation, notes, changelog, knowledge-base, obsidian, case-study, type/case-study, area/production, level/intermediate, api/HttpService, area/monetization]
---
# Documentation and Knowledge Bases

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One document doing four jobs. The map fills with history and nobody can find anything.
> - Avoid: Long change entries. Nobody reads them; put depth in systems notes.
> - Avoid: No revert line. The change cannot be undone by anyone but its author.
> - A project map exists, is short, and is edited in place.
> - The changelog is append-only with tagged, dated entries of a few lines.
> - Every entry has the request quote, paths, verification level and revert.
>
> Cost: TL;DR ~160 tok · whole note ~3.8k tok. Read more: ## Four documents, four jobs · ## Generated documentation from the place · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Roblox place does not explain itself. The Explorer shows that `ReplicatedStorage.Enemies.EnemyDefs` exists; it does not say that it replaced an older system, that a flag in the old system's loop skips zones the new one owns, that the old system's script is 300 characters from the Source limit, or that the owner decided bosses do not scale. That knowledge lives in people's heads, in chat, or in notes. Only notes survive a week off, a new teammate, or a parallel workstream that was not in the room.

This note covers what to document, in what shape, and how to keep it true. It draws on one production game (the reference project), which grew a 300 KB running notes file, a 290 KB history file, a per-day changelog and a linked Obsidian vault of several hundred notes in about four weeks, and learned what each of those is good and bad at.

## Four documents, four jobs

Most teams need exactly four kinds of document. Mixing their jobs is the main cause of documentation rot.

| Document | Job | Shape | Read when |
|---|---|---|---|
| **Project map** | Where things are and what they are called, now | Short, canonical, edited in place | First, every session |
| **Running notes / changelog** | What changed, when, why, how to revert | Append-only, dated, a few lines per change | When something looks odd, or before touching an area |
| **Decisions and open questions** | What the owner decided and what is waiting on them | Table: date, decision, quote, status | Before proposing a change in that area |
| **Reference / systems notes** | How a system works | One note per system, updated when it changes | When working on that system |

### The project map

The map is the one document that must always be current. In the reference project it was a section at the top of the running notes, marked "canonical: read first; keep current". It listed, in a few hundred words:

- the plain names people use and the instance paths they mean ("the hub" = this folder, centre at these coordinates; "Realm I" = that folder);
- the zone layout as numbers (gate x positions, zone widths);
- which workstream owns which area;
- the active systems and their entry points;
- the rules that override everything below.

The map is edited in place: when a gate moves, the gate list changes; there is no "as of" history in the map. History goes in the changelog. A map that accumulates history becomes a changelog and stops being readable.

### Running notes: append-only, later wins

The running notes were a single chronological file with one rule: **later sections win**. When the hub was replaced and then reverted, both entries stayed, and the later one was true. This is simple and robust, with two costs:

1. **Size.** The file reached about 300 KB. At that size nobody reads it start to finish. The reference project split it: older material moved to a dated history file (read "on demand only, grep it for a system name"), and the live file kept the map, the rules and recent sections.
2. **Superseded lines mislead greps.** A grep for a system name finds the old description first. The fix used in the project was inline markers: `[SUPERSEDED: ...]` and `REMOVED by ...` at the start of entries that no longer apply, with a pointer to what replaced them.

The owner eventually imposed a length rule: "Keep notes here to a few lines per change." That is the right instinct. A change entry needs: a tag, the date, the request quote, what changed (with paths), the verification level, and how to revert. Anything longer belongs in a systems note or a design doc.

A template that worked:

```text
- TAG-NAME (2026-10-23, request: "make zone 0 smaller, players should reach zone 1 quicker";
  Edit only, NOT play-tested, publish to ship):
  what: zone 0 squashed toward gate 1 (x' = 650 - 0.4 * (650 - x) for x < 650); 117 items moved by pivot.
  where: Map.Zone0, the return portal, zone-0 walls; terrain x 96..720 resampled.
  revert: every moved instance has attribute Z0Shrink_CF; terrain backup TerrainRegion + paste corner.
  check in Play: portal-to-gate walk feels short; nothing floats; tutorial box still covers zone 0.
```

The `TAG-NAME` makes entries greppable and linkable from code comments (`-- (ZONE0-SHRINK) ...`), which is how you find the reason for a strange line six weeks later.

### Decisions log

Decisions need their own document because they outlive the change that implemented them. The reference project's decisions log was a table, newest first, with the owner's words quoted:

| Date | Decision |
|---|---|
| day 7 | Remove the sword foley bank ("remove the most recent basic sword sounds"): never reuse those ids |
| day 10 | Deletion policy changed: remove unused things ("I do not need to export things that we will not use again") |
| day 15 | All in-place backup folders deleted ("backups are not necessary") |
| day 21 | New hub replaces the old one entirely ("replace ... entirely", "delete old stuff") |

Quotes matter. A paraphrase ("owner wants fewer backups") loses the force and the scope. A quote tells the next person both what was decided and how strongly.

The companion is a **pending decisions** table: things only the owner can decide, with context. It prevents the same question being asked in five sessions and makes the owner's review efficient. See [[Planning and Scoping a Roblox Game]].

### Systems notes

One note per system: what it is, where its code lives, its data, its knobs, its gotchas, its open issues, and links to related systems. Systems notes are where depth goes, and they are what new contributors read. They rot fastest, because nobody is forced to update them when code changes. Two mitigations:

- **Date every note** (`updated:` in front matter) and treat anything older than its system's last changelog entry as suspect.
- **Generate what can be generated.** The reference project generated its per-weapon, per-zone and per-enemy notes from a read-only dump of the Studio place (a script exported config tables to JSON; an offline script wrote the notes). Hand-written notes held only the parts that cannot be generated: design intent, history, gotchas.

## Generated documentation from the place

The dump-and-generate approach is worth copying. Steps:

1. A Studio script serialises what you want to document: config tables, folder structures, attribute values, instance counts. It sends JSON to a local receiver or prints it in chunks.
2. An offline script turns JSON into notes with a fixed template.
3. A link checker confirms every `[[link]]` resolves.

The Studio side is simple:

```lua
--!strict
-- Command bar: dump each enemy model's key attributes as JSON lines.
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local models = ServerStorage:FindFirstChild("EnemyModels")
if models then
	for _, model in models:GetChildren() do
		local row = {
			name = model.Name,
			attributes = model:GetAttributes(), -- only JSON-safe values survive encoding
			parts = #model:GetDescendants(),
		}
		local ok, json = pcall(HttpService.JSONEncode, HttpService, row)
		print(if ok then json else ("-- could not encode " .. model.Name))
	end
end
```

`JSONEncode` supports only JSON-shaped data (tables, strings, numbers, booleans, nil); Roblox datatypes like `Vector3`, `Color3` or `CFrame` are not supported (Roblox docs). `GetAttributes` returns such values, so convert them to plain arrays first; the `pcall` keeps one bad row from stopping the dump.

And a link checker for an Obsidian-style vault, run before every publish of the notes:

```python
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
titles = {p.stem for p in root.rglob("*.md")}
link = re.compile(r"\[\[([^\]|#]+)")
missing = []
for note in root.rglob("*.md"):
    for m in link.finditer(note.read_text(encoding="utf-8")):
        target = m.group(1).strip()
        if "." in Path(target).name:      # embedded file such as image.png
            continue
        if target not in titles:
            missing.append((note.name, target))
for src, target in sorted(missing):
    print(f"{src}: [[{target}]]")
print(f"{len(missing)} broken links")
```

## What to document that people forget

From the reference project, these were the entries that saved the most time later:

| Entry type | Example | Why it pays |
|---|---|---|
| **Engine facts learned the hard way** | "Script Source hard limit 200,000 characters"; "terrain colours are global per material"; "Edit mode cannot advance animations inside a ViewportFrame" | Each one cost hours to discover; the note costs one line |
| **Revert recipes** | "Undo = `require(Tool:Clone()).Undo()`"; "set this attribute back to true" | A revert you cannot find is not a revert |
| **Kill switches** | A table of flags that turn features off | Fast incident response; see [[Release Process and Rollbacks]] |
| **Test hooks** | Studio-only attributes that force an event, fake time away, or isolate a test save | Testers need them; forgotten ones change what the next tester sees |
| **Forbidden things** | Asset ids, names, fonts, patterns | Prevents regressions by people who were not there |
| **Who owns what** | The ownership map | See [[Team Roles and Workflows]] |
| **What was verified how** | "Edit only, NOT play-tested" | Honest status; see below |
| **Stale-on-purpose files** | "These layout files are stale after the shrink; don't rebuild from them" | Prevents someone regenerating old content |

### Honest verification labels

Every change entry in the reference project carried one of: "verified in Edit", "Edit only, NOT play-tested", "play-tested", or "publish to ship". This looks like bureaucracy and is the opposite. It lets the tester build a checklist from the notes, lets the publisher know what has never run in a live server, and stops "done" from meaning four different things. When a whole period goes unverified, the notes say so plainly ("Nothing since day 14 is play-tested: assume every system needs a playtest"), which is more useful than a hundred optimistic "done" lines. See [[QA Checklists Before Release]].

## Documentation rot: how it happened

The reference project's notes rotted in specific, preventable ways:

- **A stale table.** The "zones and enemies" table described an enemy roster that no longer existed. A Studio dump revealed it. Fix: generate tables from the place, or mark hand tables with the date they were checked.
- **Comments pointing at deleted backups.** Many scripts said "backup in ServerStorage.X" after X was deleted in a cleanup. Script comments are documentation too; a cleanup must grep comments as well as code.
- **Undocumented work.** A dump found folders no note described, made by parallel workstreams. Fix: the ownership rule "nothing enters the place without a notes line".
- **Two sources of truth.** At one point both a notes file and a vault described the same systems. The owner ruled "never use the vault; no vault changelog lines" for the live notes, to stop duplicate maintenance. Pick one canonical source per fact; other documents link to it.

## Knowledge graph and navigation

At several hundred notes, navigation matters more than any single note. What helped:

- **Maps of content** (MOC notes): a home note with tables of entry points per area.
- **Links in every note**: "Related" lines at the bottom so readers can walk the graph.
- **A generated graph index** that found hub notes (the most-linked ones) and surprising cross-links. It was useful for orientation, and the owner later turned it off for routine work because maintaining it cost more than it saved. Tooling must earn its upkeep.

## Player-facing documentation

Players also need documentation: an updates panel, patch notes, tooltips. Rules from the reference project's main-menu updates panel:

- **Headlines only.** The first version listed tweaks ("birds in the hub"); the owner's verdict was "way too specific". Rewritten to 1 to 3 short lines per release, features only, no numbers or fixes.
- **One row per release, newest first, with a "new" badge for 7 days.**
- **Data, not layout.** Rows live in a small module so adding one is one edit.

```lua
--!strict
-- ReplicatedFirst.MainMenu.Updates (a ModuleScript): newest first.
export type UpdateRow = { date: string, title: string, lines: { string } }

local rows: { UpdateRow } = {
	{ date = "Oct 23", title = "New Main Menu", lines = { "A new menu with graphics presets for your device." } },
	{ date = "Oct 22", title = "Free Gifts and a New Forge", lines = { "Claim free gifts while you play.", "The forge has a fresh look." } },
}

return rows
```

See [[Live Ops Events and Updates]] and [[Localization]].

## Common mistakes

- **One document doing four jobs.** The map fills with history and nobody can find anything.
- **Long change entries.** Nobody reads them; put depth in systems notes.
- **No revert line.** The change cannot be undone by anyone but its author.
- **Paraphrased decisions.** The scope and strength of the decision are lost.
- **Hand-maintained tables of live data.** They go stale; generate them.
- **No verification label.** "Done" is ambiguous.
- **Two canonical sources.** They diverge within days.

## Checklist

- [ ] A project map exists, is short, and is edited in place.
- [ ] The changelog is append-only with tagged, dated entries of a few lines.
- [ ] Every entry has the request quote, paths, verification level and revert.
- [ ] A decisions log quotes the owner; a pending list holds open questions.
- [ ] Systems notes are dated and link to their neighbours.
- [ ] Data-heavy notes are generated from the place.
- [ ] A link checker runs before the notes are shared.
- [ ] Superseded entries are marked where they stand.
- [ ] Player-facing updates are headlines, stored as data.

## See also

- [[Team Roles and Workflows]], [[Safe Changes in a Shared Place]], [[Release Process and Rollbacks]]
- [[Working with AI Assistants in Studio]] for notes as the hand-off between automated sessions
- [[Version History and Backups]], [[Git and Source Control for Roblox]]
- [[Debugging Animation Problems]] and [[Troubleshooting Table]] for symptom-indexed reference notes
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Live Content Pipeline]] · [[Case Study - Instance Cleanup and Place Size]] · Documentation and Onboarding New Developers · Pipeline Design Principles · Multiple Agents in One Studio · Safety Rules for AI Agents in Studio
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Post-Mortem - Building a Melee Action Game]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Scoping and Roles for Small Teams]] · [[Asset Pipelines]] · [[Case Study - Building LihFolk V2 with AI Agents]] · [[Case Study - Phone UI Overhaul]] · [[Case Study - Enemy Roster Rebuild]] · [[Live Incident Response and Post-Mortems]]
<!-- related:end -->
