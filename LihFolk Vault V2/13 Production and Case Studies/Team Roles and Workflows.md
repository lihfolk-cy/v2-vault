---
tags: [production, team, workflow, ownership, collaboration, case-study, type/case-study, area/production, level/intermediate, area/monetization]
---
# Team Roles and Workflows

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No ownership map. Two people "improve" the same folder in the same hour.
> - Avoid: Contracts in chat, not in notes. The second half of the feature is built against a misremembered interface.
> - Avoid: Play-testing in the shared session while others build.
> - Roles are named, even if one person holds several.
> - An ownership map exists, by path, and is kept current.
> - Shared hot files have a written edit protocol.
>
> Cost: TL;DR ~150 tok · whole note ~3.7k tok. Read more: ## The ownership map · ## The daily loop · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Roblox game is usually made by a small group: an owner who decides taste and holds the account, one or more builders and scripters, sometimes an artist or animator, and testers who are often friends or the owner. Studio makes it easy for all of them to work in the same place at the same time ([[Team Create and Collaboration]]). It does not make it easy for them to avoid stepping on each other. This note is about roles, ownership and the daily loop that keeps several people (or several parallel workstreams) productive in one place.

Examples come from one production game (the reference project), where up to five parallel workstreams edited the same Studio place at once, sharing terrain, the undo stack, config modules and the owner's attention. Most of the rules below were written after something went wrong.

## Roles that exist even on a two-person team

Name the roles even if one person holds several. The failure mode on small teams is not missing skills; it is nobody being responsible for the in-between work.

| Role | Owns | Typical failure when missing |
|---|---|---|
| Owner / creative director | Taste, priorities, the "approved" decision, the Roblox account, products and prices | Builders guess at taste; work is redone after review |
| Lead / integrator | The plan, ownership map, shared modules, notes, final verification and cleanup | Shared files get edited by everyone; nobody deletes temporary copies |
| Systems scripter | Services, data, remotes, security | Gameplay code spreads into UI scripts |
| Content builder | Maps, props, enemies, weapons through a pipeline | One-off assets that bypass budgets |
| UI builder | Screens, HUD, phone layouts, the design system | Each screen invents its own look |
| Tester | Play-tests, bug reports with steps | "Works in Studio" ships |
| Publisher / release owner | When to publish, server restarts, rollbacks | Changes sit unpublished for days, or ship untested |

In the reference project the owner did **all** play-testing by explicit rule ("don't play test, I'll do it"). That made the owner the release bottleneck: by the end of the first month nearly every system carried the label "Edit only, not play-tested". The fix is not to remove the rule (there are good reasons to keep Play mode out of a shared session; see below) but to schedule testing as a role with time allocated. See [[Multi-Client and Live Testing]].

## The ownership map

The single most effective coordination tool is a short table that says who owns which part of the place. In the reference project it looked like this (anonymised):

| Workstream | Areas it owns |
|---|---|
| Lead | The notes file, briefs, shared config review, final cleanup |
| Systems | Roll service, shop, leaderboards, world travel UI, save status |
| Map A | Terrain floors and cliffs, gate fills, prop thinning, enemy aggro alert, loot drops |
| Map B | One city zone and the zone-10 boss arena |
| UI | Every menu, HUD, phone layouts |

Rules that make an ownership map work:

1. **Owners are by folder or by instance path, not by feature.** "Combat" is ambiguous; "ServerScriptService.EnemyServer and ReplicatedStorage.Enemies" is not.
2. **Announce before touching another owner's area.** If you need a change there, ask the owner or the lead. The cost of asking is minutes; the cost of a silent overwrite is a lost day.
3. **Shared hot files get a protocol.** Some files everybody needs: the main config module, the HUD layout table, the ability registry. In the reference project the main config was shared with another workstream, so the rule for adding a weapon was "one insert, re-read first, back up, compile check, scan, clone-require" ([[Safe Changes in a Shared Place]]).
4. **Undocumented areas are a warning.** A Studio dump found nine map folders and seven storage folders that no notes described. Undocumented work cannot be safely changed or deleted; treat it as owned by "someone" until proven otherwise.

You can enforce ownership in tooling with an attribute convention. Folders carry an `Owner` attribute; your own scripts refuse to write under someone else's folder.

```lua
--!strict
-- Walk up from an instance to the nearest ancestor with an Owner attribute.
local function ownerOf(inst: Instance): string?
	local node: Instance? = inst
	while node do
		local owner = node:GetAttribute("Owner")
		if typeof(owner) == "string" then
			return owner
		end
		node = node.Parent
	end
	return nil
end

-- Call this at the top of any tool that writes into the place.
local function assertMayEdit(inst: Instance, me: string)
	local owner = ownerOf(inst)
	if owner ~= nil and owner ~= me then
		error(`{inst:GetFullName()} belongs to {owner}; ask before editing`, 2)
	end
end

assertMayEdit(workspace:WaitForChild("Map"), "map-a")
```

The attribute costs nothing at runtime and survives in the place file, so the ownership map lives where the content lives.

## Contracts between workstreams

When two people build halves of one feature, write the interface first. In the reference project, a stage-based redesign split the work: one workstream built the stage art, another built the stage logic. The contract was written down before either started:

- each stage is a model `Stage_<n>` with attributes `Stage`, `Boss`, `RecommendedPower`;
- it contains `Floor`, `Arena`, `Spawns`, `Wall.Gate` and `Sign.StageSign`;
- the travel remote is server-validated and keyed on a `HighestStage` player attribute.

Both halves were built the same day and met without integration bugs. The same pattern worked for a hub replacement: the new hub kept the old folder path and every hook name, so the existing station scripts kept working unchanged.

Rule of thumb: a contract names **paths, attribute names and types, remote names and payloads, and who owns each side**. If you cannot write it in ten lines, the feature is not split cleanly yet. See [[Project Structure and Bootstrapping]] and [[RemoteEvents RemoteFunctions and Unreliable Remotes]].

## The daily loop

A loop that worked for the reference project, written as steps:

1. **Request.** The owner states the change, in their words. Record the quote. Quotes like "make zones 60% smaller ... players have to run for too long" carry the reason, which matters when the change is later reversed.
2. **Plan.** For anything non-trivial, a short plan: what changes, where, how it is reverted. For big work, a written plan with a gate (see [[Planning and Scoping a Roblox Game]]).
3. **Build in Edit.** Changes are made in Edit mode. Test objects use a prefix and a known test spot so they are easy to find and remove.
4. **Static checks.** Compile check, a use-before-definition scan, clone-require of edited modules, size limits, overlap checks for UI. See [[Testing Strategies and Frameworks]].
5. **Label the verification level honestly.** "Edit-verified" and "play-tested" are different states. Every note line says which.
6. **Owner play-test.** The owner (or tester) plays with a checklist written by the builder: "spawn lands on the pad facing the tower; every prompt opens its UI; walking on the stairs; no falling through the island; performance on phone".
7. **Publish.** Changes in Studio do nothing for players until published. See [[Release Process and Rollbacks]].
8. **Record.** A few lines in the notes and changelog: what, where, how to revert. See [[Documentation and Knowledge Bases]].

Step 6's checklist is the most underrated artifact in the loop. A builder knows exactly which edge cases they could not check in Edit; writing them down turns a vague "please test" into a ten-minute task.

### Why Play mode is dangerous in a shared session

Several reference-project rules exist because Play mode and shared Edit sessions interact badly:

- While one person is in Play, Edit calls from tools fail ("Edit datamodel is not available in Play mode"). A long Play-mode verification by one workstream blocked all others for its duration.
- The owner sometimes played in the same session while tests ran, which made odd behaviour hard to attribute. Rule: check the server log for someone else's activity before chasing a bug.
- Studio test flags left on (a forced intro cutscene, a test save key) changed what the next tester saw. Flags must be cleared after use and listed in the notes while set.

## Review and judging

For quality-sensitive work (UI especially), independent review rounds were effective. The reference project's HUD redesign used a written rubric and two independent judges scoring each round, with several rounds before acceptance. A UI audit tool scored every screen out of 10 for specific defects (paint bleeding past rounded corners, nested rounding, uneven row heights, off-centre captions) and the average reached 10.00 over 84 screen views after fixes (measured).

What made review useful:

- **A rubric written before building.** Judges score against criteria, not taste.
- **Independent reviewers.** A reviewer who sees only the result, not the builder's reasoning, catches more.
- **Automated checks for the mechanical parts.** Overlap, minimum text size, minimum tap size, gaps. Humans then judge only what a script cannot. See [[Case Study - Phone UI Overhaul]].

## Conventions that remove friction

Small conventions repaid themselves many times in the reference project:

| Convention | Why |
|---|---|
| Test objects named `<prefix>_<workstream>_*` at a known spot | Easy to find and remove; never mistaken for content |
| Forbidden names list | A clip named `Origin` replaced a kit's `Origin` RemoteEvent (same parent, `FindFirstChild` found the wrong child) and broke all damage for that kit. Moves and clips may never be named `Attack`, `Origin`, `FX`, `LocalCast`, `Moves`, `ItemRig` |
| One font rule | "Only these two fonts anywhere", enforced by a runtime enforcer and a scan script |
| One button style, one header style, one close button | The owner's rule was blunt ("do that or you will be banished"); it ended per-screen restyles |
| Player-facing text plain and short, no em dashes | Consistent voice; easier localisation |
| New sound ids go through a loudness table | Otherwise they play unlevelled next to measured sounds |
| A forbidden asset list | Sounds the owner rejected, plus one removed by moderation, must never come back |
| Reserved test spots per workstream | Two people never build test rigs on top of each other |

## Handling the owner's feedback

The owner's feedback in the reference project was fast and specific, often iterative: crystal trees went through seven rounds in one session ("more spread out", "slightly less dense 20%", "way too many small trees", "vary in size greatly, no trees too small", "30% less dense"). Lessons:

- **Make parameters, not placements.** The tree scatter was a script with density, size distribution and spacing knobs, so each round was a re-run, not a rebuild.
- **Confirm intent when the words are ambiguous.** "Restore the old movement animation" turned out to mean a different set than the one restored; a one-line question would have saved a round trip.
- **Keep reversals cheap.** Grass darkened, then "a lot darker", then "not that dark", then reverted because the method removed the 3D grass blades (only the Grass terrain material grows them). The revert was quick because the original colours were recorded first.

## Working with external contributors

Owners often bring in models, sounds or code from outside. Rules from the reference project:

- **Imports go through the pipeline.** An imported model gets the same rig fix, scale, collision and budget checks as one built in-house ([[Asset Pipelines]]).
- **Toolbox and third-party scripts are suspect.** A nametag script copied from the toolbox was marked `Sandboxed`, so its `require` of the config module failed and the feature silently never showed. See [[Creator Store and Toolbox Safety]].
- **Admin lists live in one place.** Admin user ids ended up in six scripts in the reference project; adding an admin meant grepping all six. Put them in one server module.

## Common mistakes

- **No ownership map.** Two people "improve" the same folder in the same hour.
- **Contracts in chat, not in notes.** The second half of the feature is built against a misremembered interface.
- **Play-testing in the shared session while others build.** Edits fail, logs mix.
- **Leaving test flags on.** The next tester sees a forced cutscene or a test save.
- **Unlabelled verification.** "Done" means four different things to four people.
- **Restyling per screen.** Ten screens, ten looks; then a costly unification pass.

## Checklist

- [ ] Roles are named, even if one person holds several.
- [ ] An ownership map exists, by path, and is kept current.
- [ ] Shared hot files have a written edit protocol.
- [ ] Split features start from a written contract.
- [ ] Every change records the request quote, the location and the revert.
- [ ] Verification level is labelled on every change.
- [ ] Builders hand testers a specific play-test checklist.
- [ ] Test flags and test objects are listed while they exist and removed after.
- [ ] Review uses a rubric and automated mechanical checks.

## See also

- [[Planning and Scoping a Roblox Game]], [[Documentation and Knowledge Bases]], [[Safe Changes in a Shared Place]]
- [[Working with AI Assistants in Studio]] for the same problems when some contributors are automated
- [[Team Create and Collaboration]], [[Version History and Backups]], [[Git and Source Control for Roblox]]
- [[UI Design Systems]] for the one-style rule
- [[Animation Review Checklist]] for a review rubric in another discipline
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Scoping and Roles for Small Teams]] · [[Multiple Agents in One Studio]] · Team Collaboration Start Here · [[Post-Mortem - Building a Melee Action Game]] · Documentation and Onboarding New Developers · Evaluating AI Tools - A Practical Rubric
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Instance Cleanup and Place Size]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Case Study - Enemy Roster Rebuild]] · [[Case Study - Building LihFolk V2 with AI Agents]] · [[Live Incident Response and Post-Mortems]] · [[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Case Study - Fast Join and Deferred Loading]] · [[Template Reskin Checklist - One Codebase, New Game]]
<!-- related:end -->
