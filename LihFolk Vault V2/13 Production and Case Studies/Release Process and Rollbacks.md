---
tags: [production, release, publishing, rollback, kill-switch, datastore, live-ops, case-study]
---
# Release Process and Rollbacks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Publishing without a pre-release grep for Studio-only features.
> - Avoid: Forgetting that old servers keep running old code.
> - Avoid: No kill switch on a feature that replaces old behaviour.
> - No runtime-registered keyframe clips in gameplay code
> - Animations are published to the experience owner
> - Product and pass ids are real
>
> Cost: TL;DR ~130 tok · whole note ~3.5k tok. Read more: ## Kill switches · ## Data releases: versioned stores · ## Pre-release checklist · ## Common mistakes
<!-- tldr:end -->

Editing a place in Studio changes nothing for players. A change reaches players only when the place is published and running servers move to the new version. Between "it works in Studio" and "it works for players" sit several steps that small teams skip: a pre-release check, a publish, a server restart decision, a watch period, and a ready way back. This note covers that path and the rollback tools that make releasing often safe.

The examples come from one production game (the reference project), whose notes end almost every entry with "Edit only, publish to ship". That phrase is the subject of this note: a growing pile of Edit-only changes is a release that has not been planned.

## What "released" means on Roblox

| State | What players see | How you get there |
|---|---|---|
| Edited in Studio | Nothing | Any edit |
| Saved to Roblox | Nothing (a saved version exists in version history) | Studio save to Roblox |
| Published | New servers run the new version; existing servers keep the old one | Studio publish |
| Servers restarted | Everyone on the new version | Creator Hub server restart (below) |

Published but not restarted is a real state that lasts: old servers keep running old code until they empty. Roblox docs describe this as non-disruptive but warn that players may be on different versions for a long time, and suggest restarting when your data format changes (Roblox docs, as of October 2026).

### Restarting servers

As of October 2026 the Creator Hub flow is: the experience, then Configure, Server management, select places, **Restart Servers**, with two options: **"Restart only servers with outdated versions"** (docs recommend it) and **"Delay server restart"** by 1 to 60 minutes so players can leave on their own ("server bleed-off"). Players are teleported to the new version, and players from one old server go to the same new server. Servers being shut down get the `DataModel.ServerRestartScheduled` event, which you can use to show a warning. Menu labels change; check [[Publishing an Experience]] and the current docs.

Rule of thumb: restart outdated servers with a short delay when the update changes saved data, remotes, or anything the client and server must agree on. Let servers bleed off naturally for content-only updates.

## Pre-release checklist

A release is the right moment to catch the classes of bug that never show in Studio. The reference project's list of "Studio-only" traps is a good starting point:

| Check | Why | How |
|---|---|---|
| No runtime-registered keyframe clips in gameplay code | `RegisterKeyframeSequence` ids only work in Studio; in a live server the track plays nothing, silently | Grep all sources for the call; dozens of weapon kits in the reference project had blade-part moves that never animated live. See [[Case Study - Abilities That Only Worked in Studio]] |
| Animations are published to the experience owner | Clips owned by another account will not play | See [[Publishing Animations]] |
| Product and pass ids are real | Ids left at 0 make purchase buttons dead or hidden | The reference project had every product id at 0 for weeks; the shop hid cards with id 0 |
| Test flags cleared | A forced intro or a test save key changes what players see | List all test attributes; assert they are unset at server start in live servers |
| Admin grants gated | An owner grant (every item, every gate) ran on the real save until it was put behind a flag | Admin code checks a flag and an allowlist in one module |
| Editable mesh / image features off in live | They failed in published games by default (measured in the reference project) | Do not build runtime visuals on them without checking current docs |
| Script sizes under the limit | A module over 200,000 characters cannot be saved (measured) | Size report in the release script |
| Phone layout checked | Most players are on phones | See [[Case Study - Phone UI Overhaul]] |
| Data version decided | A schema change needs a migration or a new store | See below |

```lua
--!strict
-- Server start: refuse to run with Studio test flags in a live server.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local TEST_FLAGS = { "TestProfileKey", "ForceIntro", "ForceVoidEvent", "ForceOffline", "AdminGrant" }

if not RunService:IsStudio() then
	for _, name in TEST_FLAGS do
		if ServerStorage:GetAttribute(name) ~= nil then
			warn(`[release] test flag {name} is set in a live server; ignoring it`)
			ServerStorage:SetAttribute(name, nil)
		end
	end
end
```

Pair this with a Studio-side check in the release script that prints every set flag before you publish. See [[QA Checklists Before Release]].

## Release notes and a release log

Each publish should produce two things:

- **A player-facing updates row**: headline features, 1 to 3 short lines. See [[Documentation and Knowledge Bases]].
- **An internal release log entry**: date, version number from version history, the list of change tags included, what was play-tested, known issues, and the rollback plan.

The internal entry turns "what changed between Tuesday and today?" from archaeology into a lookup, which matters when a bug report arrives.

## Kill switches

The fastest rollback is not a rollback. It is a flag that turns a feature off without a code change. The reference project kept a table of them:

| Feature | Switch |
|---|---|
| Caster cutscene on ultimates | `UltCinema.Enabled = false` |
| A shared ability on every weapon | `SharedMoves.<Ability>.Enabled = false` restores every replaced move |
| Intro cutscene | Replicated attribute `IntroEnabled = false` |
| Enemy attack-tempo change | `AggroTempo.Enabled = false` |
| Pets | `PetConfig.Enabled = false` |
| Cosmetics shop | a config constant |
| Toon VFX on all kits | one attribute on the VFX root |
| Weapon equip flourishes | one config boolean |

Two kinds of switch:

- **Config switches** in a ModuleScript. Changing one needs a publish, but the change is one line and low risk.
- **Live switches** read at runtime from somewhere you can change without publishing, such as a DataStore or MemoryStore value, or an attribute set by an admin command. See [[Global State and Live Config]].

```lua
--!strict
-- A tiny flag reader: attribute on ReplicatedStorage wins, then the config default.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defaults = {
	UltCinema = true,
	AggroTempo = true,
	Pets = false,
}

local Flags = {}

function Flags.on(name: string): boolean
	local override = ReplicatedStorage:GetAttribute("Flag_" .. name)
	if typeof(override) == "boolean" then
		return override
	end
	local default = Defaults[name]
	return default == true
end

-- React when an admin flips a flag at runtime.
function Flags.changed(name: string, callback: (boolean) -> ())
	ReplicatedStorage:GetAttributeChangedSignal("Flag_" .. name):Connect(function()
		callback(Flags.on(name))
	end)
end

return Flags
```

Setting attributes on `ReplicatedStorage` from the server replicates to clients, so one admin command flips the flag for everyone on that server. For all servers at once you need a cross-server mechanism ([[Cross-Server Messaging]]).

Design rule: **every feature that replaces old behaviour keeps the old path behind its switch until the new one has survived a release.** The reference project's shared ability replaced each kit's weakest move but kept the replaced moves, so the switch restored all of them.

## Data releases: versioned stores

The scariest release is one that changes saved data. The reference project used a blunt, effective tool more than once: **renaming the DataStore** to start everyone fresh while leaving the old data untouched.

| Event | Stores | Why |
|---|---|---|
| Difficulty rebalance (day 18) | main store, skills store and 4 leaderboards `v1` to `v2` | Progression made about 2x slower; old saves would trivialise it |
| Account reset (day 19) | `v4` to `v5` | Owner-confirmed reset |
| Later reset | `v5` to `v6` | Another reset; purchase receipts and settings kept |

Properties of this approach:

- **Rollback is a rename back.** The old store is never touched.
- **Purchase records must survive.** Receipts and gift intents lived in separate stores that were not versioned, so a wipe never lost paid items' history. Design for this from day one. See [[Purchase Data and Receipts]].
- **Settings survive.** Player settings were in their own store too.
- **It is still a wipe for players.** On a live game with an audience, a wipe needs communication and usually compensation; prefer a migration ([[Data Schema Design and Migrations]]).

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")

-- One place to bump: a new suffix = a fresh start, old data untouched for rollback.
local DATA_VERSION = "v6"

local Stores = {
	profile = DataStoreService:GetDataStore("PlayerData_" .. DATA_VERSION),
	skills = DataStoreService:GetDataStore("PlayerSkills_" .. DATA_VERSION),
	-- NOT versioned: these must survive every reset
	receipts = DataStoreService:GetDataStore("PurchaseReceipts"),
	settings = DataStoreService:GetDataStore("PlayerSettings_v1"),
}

return Stores
```

Verify saves without the read cache when testing: `GetAsync` can return a cached value for a few seconds; the reference project used `DataStoreGetOptions` with `UseCache = false` to confirm a write (Roblox docs describe the option). See [[Saving Correctly - Autosave and BindToClose]].

## Rollback options, fastest first

| Option | Time | Scope | Risk |
|---|---|---|---|
| Live flag off | Seconds | One feature, current servers | Low; old path must still work |
| Config flag off + publish + restart outdated servers | Minutes | One feature | Low |
| Revert specific changes from records (`Pre*` attributes, disk copies) + publish | Minutes to an hour | Exactly those changes | Low if records exist |
| Copy one folder from an older version + publish | About an hour | One area | Medium: references between that folder and newer code |
| Restore a whole older place version + publish | Minutes | Everything | High: loses all work since then |
| Data store rename back | Minutes | All saves | High: progress made on the new store is invisible after |

The reference project used most of these. The hub revert copied one folder from an older version opened in a second Studio window, plus three data modules "byte-exact from the old version", then re-ran the station hook installer (measured). A zone resize was undone from per-instance attributes and a terrain backup, then confirmed against a 27-point check. A crash recovery came from the 22:50 autosave. Each worked because a record existed; the one that did not (cliff positions deleted without backup, autosave older than the layout) could not be rolled back and was rebuilt.

## Watching after release

After publishing, watch for an hour:

- **Errors**: the server and client error logs in the developer console and the Creator Hub error reports ([[Crash and Error Telemetry]]).
- **Join time**: the reference project logged join timings as analytics custom events (loaded, menu ready, play pressed, by device and graphics preset). A release that adds replicated content shows up here first. See [[Case Study - Fast Join and Deferred Loading]].
- **Funnels**: tutorial completion, first purchase, retention events. The reference project added a goal-completion event to its next-goal tracker. See [[Analytics and Funnels]].
- **Player reports**: "players are saying there's a luck bug" led to finding a real weighted-pick bug (a "1 in 3" common item was rolling at about 1 in 370) and a fix the same day (measured).

## Cadence

Rule of thumb for a small team: release small and often, with one theme per release, on a day you can watch it. The reference project's failure mode was the opposite: a month of Edit-only changes across UI, combat, enemies, maps and data, many never play-tested, all waiting for one publish. That makes every release a big-bang release and every bug report ambiguous. If you build fast, publish fast, behind flags.

## Common mistakes

- **Publishing without a pre-release grep** for Studio-only features.
- **Forgetting that old servers keep running old code.**
- **No kill switch on a feature that replaces old behaviour.**
- **Wiping data without separating receipts.**
- **Whole-place restore as the first rollback.** It reverts everyone's work.
- **No release log.** Bug reports cannot be matched to changes.
- **Product ids still 0** at release.

## Checklist

- [ ] Pre-release script: test flags, product ids, script sizes, Studio-only calls, unpublished animations.
- [ ] Release log entry with change tags, test status, known issues and rollback plan.
- [ ] Player-facing updates row.
- [ ] Kill switches for every new feature that replaces old behaviour.
- [ ] Data changes: migration, or a versioned store with receipts and settings outside it.
- [ ] Restart decision made (outdated only, delay or not).
- [ ] One hour of watching errors, join time and funnels.

## See also

- [[Publishing an Experience]], [[Live Ops Events and Updates]], [[Global State and Live Config]]
- [[Data Schema Design and Migrations]], [[Data Loss Prevention and Recovery]], [[Purchase Data and Receipts]]
- [[Server Lifecycle and Shutdown]], [[QA Checklists Before Release]], [[Crash and Error Telemetry]]
- [[Safe Changes in a Shared Place]], [[Version History and Backups]]
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Server Shutdowns Soft Updates and Migration]] · [[Live Incident Response and Post-Mortems]] · [[Build Test and Release Pipeline]] · [[Feature Flags]] · [[Places Universes and Experience Settings]] · [[Data Schema Versioning]]
<!-- auto-links:end -->
