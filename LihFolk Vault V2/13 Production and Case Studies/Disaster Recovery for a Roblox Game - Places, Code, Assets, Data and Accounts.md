---
tags: [production, backups, disaster-recovery, accounts, security, datastore, runbook, type/guide, area/production, level/intermediate, area/data]
---
# Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Only Roblox-side history; nothing stored outside Roblox.
> - Avoid: Assets uploaded under personal accounts with no source files.
> - Avoid: One person holds every key and the group owner role.
> - Inventory table filled in for your game.
> - Weekly off-Roblox place exports; Git remote plus a second copy.
> - Asset source files and manifest; assets owned by the group.
>
> Cost: TL;DR ~130 tok · whole note ~2.2k tok. Read more: ## 2. Prevention by class · ## 3. Runbooks · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Version History and Backups]] covers place versions, snapshots and restores inside Studio. A real disaster is usually bigger than one bad edit: the owner account is compromised, an agent or teammate wipes half the place and publishes, a migration corrupts thousands of saves, an asset is moderated and every model using it breaks, or the one person with the group owner role disappears. This note is a recovery plan per asset class, with a runbook for each scenario. Write it before you need it.

Labels as marked. Data facts follow [[Data Loss Prevention and Recovery]] and [[DataStore Fundamentals]].

---

## 1. Inventory: what you would lose

| Asset class | Lives in | Roblox keeps | You must keep |
|---|---|---|---|
| Place (map, instances) | Roblox, as published versions | Version History per place (Roblox docs) | Periodic `.rbxl` exports off Roblox; named saves before risky work |
| Code | Place, or Git if you use Rojo | Script history in Studio; place versions | Git remote (and a second remote or offline clone) |
| Assets (meshes, images, audio, animations) | Roblox asset ids | The asset, unless moderated or deleted | **Source files** (`.blend`, `.png`, `.wav`, KeyframeSequences) and an asset id manifest |
| Player data | DataStores | Versions: a backup per key per UTC hour on first write, kept 30 days after being superseded (Roblox docs, via [[Data Loss Prevention and Recovery]]) | Migration logs, audit logs, ability to replay repairs |
| Products and passes | Creator Dashboard | Product records | A list of ids, prices, names and what each grants (in config code) |
| Config and secrets | Creator Dashboard Secrets, MemoryStore or DataStore config | As stored | Secret names and where to regenerate each; never the values in Git |
| Accounts and group | Roblox accounts | Account recovery flows | 2-step verification on every account with power; more than one trusted person able to act |
| Community | Discord, socials | Their own | Admin redundancy and recovery codes |

Anything in the right-hand column that you do not have is a single point of failure.

---

## 2. Prevention by class

### Places
- Named Version History save before any risky change, especially before an AI agent session ([[Safety Rules for AI Agents in Studio]]).
- Weekly `.rbxl` export to storage outside Roblox (and outside the same laptop). Rule of thumb: keep at least the last month.
- Separate **test** and **live** places. Agents and experiments work on test; live gets published builds only.

### Code
- Git with a remote; tags for every release ([[Git and Source Control for Roblox]]). With Rojo, the place can be rebuilt from Git plus the non-code place content.
- A second remote or a periodic bundle (`git bundle create`) stored elsewhere.

### Assets
- Keep source files in a shared drive or Git LFS, organised by asset id.
- A manifest: `asset id | name | source file | owner (user or group) | licence | uploaded by | date`. The licence column overlaps with [[Legal Basics - IP Licenses and Assets]]; the provenance column with [[Who Owns AI-Generated Code and Assets]].
- **Upload to the owning group, not a personal account,** so a person leaving does not take assets with them ([[Groups Roles and Permissions for Studios]]).

### Data
- Session locking and safe saves ([[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]]).
- Migration fixtures and golden files ([[Save Migration Tests - Fixture Saves and Golden Files]]).
- Audit logs for economic actions so damage can be scoped ([[Economy Exploits - Dupes Races and Purchase Abuse]]).
- A tested restore script for one player and for a list of players, using version APIs.

### Accounts
- 2-step verification on every account that owns or administers the game or group.
- Group ownership with a documented succession plan; at least two people who can publish.
- Open Cloud API keys scoped narrowly, IP-restricted where possible, one per purpose; rotate when people leave ([[Code Pipeline - Rojo Git and CI]]).
- No shared passwords. If someone needs access, give them a role.

---

## 3. Runbooks

Each runbook starts the same way: **stop the bleeding, preserve evidence, then restore.**

### A. Bad publish (broken game, wiped content)

1. Revert: restore the last good version in Version History and publish it, or redeploy the last good Git tag ([[Build Test and Release Pipeline]]).
2. Restart servers so players get the restored version (Version History restore alone does not update running servers; see [[Version History and Backups]]).
3. If the bad build wrote data, go to runbook C.
4. Post-mortem: what gate missed it ([[QA Checklists Before Release]]).

### B. Compromised account

1. Use Roblox's account recovery and support channels; change passwords; revoke sessions; re-secure email.
2. From another account with rights, remove the compromised account's group roles if possible.
3. Rotate every API key and secret that account could see.
4. Check recent place versions, product price changes, payout settings and game settings for tampering; restore from known-good versions.
5. Tell your team and community through channels the attacker does not control.

### C. Corrupted player data

1. **Feature-flag off** the system that writes bad data ([[Feature Flags and Staged Rollouts]]).
2. Scope: from audit logs and migration logs, list affected keys and the time window.
3. Restore or repair with a migration step that is pure, logged and paid-value-safe ([[Schema Migrations - Worked Case Studies]]). Restore from versions **within 30 days**; after that, versions superseded earlier are gone.
4. Never overwrite a key that a live server has session-locked; repair on load or after locks are released.
5. Compensate visibly if players lost value.

### D. Moderated or deleted asset

1. Find usages (MCP `search_game_tree` or a script searching for the asset id).
2. Re-upload from source (fixed if the moderation was right), update the manifest and replace ids in config.
3. If you have no source file, recreate it. This is why source files are kept.

### E. Lost person (owner unavailable, contributor leaves)

1. Group owner unreachable: this is why succession was documented. Roblox support may be the only path; it can take time.
2. Contributor leaves: remove roles, rotate keys they had, check their personal-account assets used in the game and re-upload under the group if licences allow.

### F. AI agent damage

1. Stop the agent; do not let it "fix" its own damage with undo in a shared place ([[Safety Rules for AI Agents in Studio]]).
2. Restore from the named save taken before the session, or from Git.
3. Review the transcript to list everything it touched, including data writes in test universes.

---

## 4. Test the plan

A backup you have never restored is a hope. Rule of thumb: once a quarter, restore a place export into a scratch place, rebuild from a Git tag, restore one test player's data from a version, and confirm a second person can publish. Record how long each took.

---

## Common mistakes

- Only Roblox-side history; nothing stored outside Roblox.
- Assets uploaded under personal accounts with no source files.
- One person holds every key and the group owner role.
- No 2-step verification on accounts that can publish.
- Discovering a data bug after 30 days of version history has expired.
- Never practising a restore.

## Checklist

- [ ] Inventory table filled in for your game.
- [ ] Weekly off-Roblox place exports; Git remote plus a second copy.
- [ ] Asset source files and manifest; assets owned by the group.
- [ ] Player restore script tested; audit and migration logs on.
- [ ] 2-step verification everywhere; succession documented; keys scoped and rotated.
- [ ] Runbooks A to F written where the team can find them; quarterly restore drill done.

## See also

- [[Version History and Backups]], [[Data Loss Prevention and Recovery]], [[Build Test and Release Pipeline]]
- [[Groups Roles and Permissions for Studios]], [[Feature Flags and Staged Rollouts]]
- [[Agent Handoff Notes - Project State and Resume Templates]]

## Connected notes

[[Debugging Live Servers]] · Team Create and Collaboration · Asset Upload Automation with Open Cloud · Running a Small Studio as a Business

<!-- related:start -->
## Related
[[Creator Account Security and Takeover Recovery]] · [[Release Process and Rollbacks]] · [[Live Incident Response and Post-Mortems]] · [[Safe Changes in a Shared Place]] · [[Scoping and Roles for Small Teams]] · [[Documentation and Knowledge Bases]] · [[Team Roles and Workflows]] · [[Lessons Learned Index]] · [[Planning and Scoping a Roblox Game]]
<!-- related:end -->
