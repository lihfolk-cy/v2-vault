---
tags: [studio, team-create, collaboration, drafts, workflow, shared-place]
---
# Team Create and Collaboration

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Experimenting in the shared place -> Sandbox place
> - Avoid: Reverting while others are editing -> Disable Team Create, then revert
> - Avoid: Drafts on one PC, working from another -> Commit before switching machines
> - Game owned by a group with role-based edit rights.
> - Age-check and trusted-friend requirements checked for every collaborator.
> - Ownership table and test-object naming agreed.
>
> Cost: TL;DR ~140 tok · whole note ~3.4k tok. Read more: ## 4. Scripts: live scripting or drafts · ## 6. What a shared place really means · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

Team Create turns a place into a live shared document: everyone with edit access works in the same data model at the same time, and Studio saves it to the cloud continuously. That is wonderful for small teams and dangerous for any team that does not agree on rules, because a shared place has no branches, no private working copy for anything except script drafts, and one wrong bulk operation reaches everyone instantly. This note covers the official features (permissions, age checks, live scripting, drafts, comments, script history) as of October 2026, then the operating rules that a production team needs, most of them learned in the reference project where several people and automated tools edited one place simultaneously.

Labels: **Docs**, **Measured**, **Rule of thumb**.

---

## 1. Access and permissions

### Age checks (time-sensitive, as of October 2026)

To add collaborators through Team Create you must complete an age check (ID verification or facial age estimation); group or game owners must do so for collaborators to join. You can use Team Create alone without one (Docs). By default you collaborate only with compatible age groups:

| Your age group | Can collaborate with | Cannot |
|---|---|---|
| Under 9 | Under 13 | 13 and older |
| 9-12 | Under 16 | 16 and older |
| 13-15 | 9-17 | Under 9 and 18+ |
| 16-17 | 13 and older | Under 13 |
| 18+ | 16 and older | Under 16 |

Becoming **trusted friends** with every collaborator who already accessed the game, or parental permission through linked parent accounts, lifts the restriction; **Safety > Collaborators** in the Creator Hub shows who blocks whom (Docs). Collaborators blocked from Team Create keep **Edit** permission for Save As copies, Open Cloud APIs and Creator Hub metadata (Docs). Plan team composition around this before hiring a contractor.

### Permission levels (Docs)

| Level | Means |
|---|---|
| Owner | Configures permissions |
| Edit | Edits the game; implies Play |
| Play | Plays privately |
| No Access | Neither |

- **User-owned games**: Edit can only go to Roblox friends; Play to any user or group. Open **Collaborate** on the mezzanine's right side.
- **Group-owned games**: edit rights come from group **roles**, either across all group games (Creator Hub, group, **Roles**) or per game in Studio's **Manage Collaborators** for roles without global edit. Individual users can be added to group games for **Play** only (Docs).

Rule of thumb: put any game with more than two editors in a group from the start. Ownership transfers are painful (assets, packages and animations are owned by the uploader; see [[Animation Asset Permissions and Groups]] and [[Packages and Asset Reuse]]).

### Joining

Creator Dashboard, **Creations**, **My Experiences** (group selected) or **Shared With Me** (personal), then **Edit in Studio** on the tile (Docs).

## 2. Seeing each other

- Collaborator avatars sit at the top right, each with a colour consistent on every device. Click one to open **Live Collaborators**: who is active (inactive after 5 minutes without using Studio) and where they work (Docs).
- Selections in the viewport and code selections in the Script Editor are outlined in each person's colour; the Explorer marks objects others have selected with coloured dots. You can hide others' selections for yourself (Docs).
- **Join** in Live Collaborators jumps your camera, or your editor, to where that person is working (Docs).

Use the coloured dots: before deleting or rebuilding something, check that nobody has it selected.

## 3. Comments

Press `C` (or the **Comment** button) and click any BasePart, including Terrain, to pin a comment; `@username` tags a collaborator; the **Comments** window (**Window > Collaboration**) lists threads, filters mentions and resolves them; email digests summarise mentions and replies (Docs). Comments are the best place for "do not touch, half-built" markers on world areas because they live where the problem is.

## 4. Scripts: live scripting or drafts

| Mode | Behaviour (Docs) | Good for |
|---|---|---|
| **Live Scripting** (default) | Everyone edits the same script in real time, with coloured cursors. Edits auto-save; `Ctrl S` saves at once; versions go to Script History | Pairing, small teams, quick fixes |
| **Drafts** | Each person edits a local draft and tests it alone; **Commit** publishes it to the shared copy. Conflicts show a green ⊕; **Compare With Server** and **Merge From Server** resolve them | Teams that want a commit step, larger systems |

Drafts details (Docs):
- Enable in **File > Experience Settings**, **Enable Drafts Mode**. All collaborators must leave the session for the change to apply (or disable and re-enable collaboration).
- The **Drafts** window is not on a default tab; add it to a custom tab.
- Drafts are saved on **your machine** and persist between sessions on that machine. They do not follow you to another PC.
- If someone deletes a script you are drafting, a red ⊘ appears; **Restore Script** puts it back under **Workspace**, so re-parent it.
- **Collaborative testing** with others uses the committed versions, not your draft.

Script History: right-click a script, **View Script History** to see every saved or committed version, compare a version with the previous one, compare two selected versions, and open old versions (Docs).

**Docs inconsistency.** The collaboration page says live-scripting edits auto-save "every 5 minutes just like place edits", and in the next section that the session saves to the cloud "every four minutes". Treat the interval as a few minutes and save explicitly before risky work.

For real source control on top of Team Create, use Script Sync (official, works with Team Create) or Rojo with its Team Create sync lock (Rojo 7.3+). See [[External Tooling - Rojo Wally Selene StyLua]] and [[Git and Source Control for Roblox]]. Script Sync appends numeric suffixes to new instances under a synced tree to avoid duplicate names, and warns against several people syncing and editing the same files at once (Docs).

## 5. Saving, reverting, disabling

- The session auto-saves to the cloud every few minutes (see above). Everything anyone does is saved, including mistakes and previews.
- The owner can revert to an earlier version through Version History (Docs). **Warning from the docs**: if anyone is still editing, their auto-save can overwrite the revert. Disable collaboration first.
- **Disable Team Create**: Live Collaborators window, ⋯, **Disable Team Create**; the place reloads non-collaborative (Docs).
- **Activity History** (Window menu) logs publishes, permission changes, settings changes and draft commits with who and when (Docs). Check it first when "something changed".

See [[Version History and Backups]].

## 6. What a shared place really means

A Team Create place is closer to a shared production database than to a file in a Git repo. Things that happened in the reference project, all in one month (Measured):

| Incident | Cause | Rule that followed |
|---|---|---|
| An undo to recover a terrain edit rolled back about 40 waypoints of other people's changes, and redo was wiped | Shared undo history in one session | Never undo; snapshot first ([[Command Bar and Studio Scripting]]) |
| A freshly built set of 1,200+ wall parts was destroyed by someone else mid-task | Another actor cleaned up what looked like clutter | Ownership markers: folder owner attribute plus a comment; never delete what you did not create without asking |
| 40 newly placed grass clones vanished mid-task | Same | Re-added under a distinct name; clean-up tools exclude unknown owners |
| A capture tool's temporary lighting stayed in the place | The network dropped mid-job, the place closed, the temporary state had already synced | Temporary edits get an explicit off path and a checklist on reopen |
| Odd behaviour during tests | Someone else was playtesting and had set test flags | Check who is playing before debugging |
| UI layout probes in StarterGui kept stale `Padding` values | Fractional UDim offsets plus Team Create sync (cause not fully understood) | Use integer offsets; run layout probes in a non-replicated container |
| A long revert was interrupted when Studio closed | Crash during a multi-step operation | Snapshots on disk to verify the recovered autosave against |

The underlying principles (Rule of thumb):
1. **Everything is visible and permanent.** There is no "just for me" edit outside script drafts. A preview, a test object, a temporary light: everyone sees it, and it is saved within minutes.
2. **Nothing is locked.** Any editor can delete anything. Studio does not stop someone deleting the folder you are working in.
3. **There are no branches.** Experiments that might fail belong in a **separate place** (Save to Roblox As into a sandbox place), not in the shared one.
4. **Concurrent edits do not merge.** The last write to a property wins; two people moving the same model fight.

## 7. Operating rules for a shared place

These are the reference project's rules, generalised. See also [[Safe Changes in a Shared Place]] for the full playbook.

**Ownership**
- Each top-level area or system folder has an owner, recorded as an attribute (`Owner = "lighting"`, or a person's role) and in a short ownership table in the team docs.
- Test objects use a prefix per person or tool (for example `test_<initials>_`) and live at an agreed test location far from the map. Remove them when done.
- Never delete or restructure another owner's area. Ask.

**Before a risky change**
- Snapshot what you will change (Pre-attributes, `.rbxm` export, TerrainRegion; see [[Version History and Backups]]).
- **Save to Roblox with Notes** (`Ctrl Alt S`) so there is a named version to return to.
- For bulk terrain or whole-area rewrites, get the owner's OK first.
- Before overwriting a script, compare the live source with the version you based your edit on; abort if it changed.

**During**
- One heavy operation at a time per place. Long synchronous commands freeze everyone's Studio, not just yours (Measured).
- Do not leave previews on. Every preview tool has an `off` command used immediately after.
- Find targets by path, tag or attribute, never by Selection.

**After**
- Verify by data (counts, checksums, a scan), not by eye.
- Remove your temporary objects and attributes.
- Write a one-line note in the team changelog: what, where, how to undo.

**Deletion policy that worked**: delete things that are no longer needed only after proving nothing references them (search all scripts, including dynamic string lookups and config tables), keep one safety copy **outside** the place while the change is pending, then delete the copy after verification. Do not keep backup folders inside the place (they grew to hundreds of thousands of instances and slowed Studio to about 15 fps in the reference project).

## 8. Collaboration features worth combining

| Need | Tool |
|---|---|
| Work on a reusable asset without touching the shared place | [[Packages and Asset Reuse]]: edit, publish the package, copies update |
| Private iteration on a system | Drafts, or a personal sandbox place |
| Code review | Script Sync or Rojo plus Git pull requests |
| "Who changed this setting?" | Activity History |
| "What did this script look like yesterday?" | Script History |
| Shared playtest | Team Test ([[Testing Modes - Play Run and Multi-Client]]) |
| Handover notes in the world | Comments |

## 9. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Experimenting in the shared place | Everyone inherits half-finished changes | Sandbox place |
| Reverting while others are editing | Their auto-save overwrites your revert | Disable Team Create, then revert |
| Drafts on one PC, working from another | "My draft is gone" | Commit before switching machines |
| Undo to fix a mistake | Others' changes rolled back | Snapshots and data reverts |
| No ownership markers | Work deleted as clutter | Owner attribute and comment on every in-progress area |
| Previews left on | Lighting or UI changes ship | Explicit off path |
| Contractor joins a group game without age-check planning | Cannot join Team Create | Check age-group compatibility before onboarding |

## 10. Checklist

- [ ] Game owned by a group with role-based edit rights.
- [ ] Age-check and trusted-friend requirements checked for every collaborator.
- [ ] Ownership table and test-object naming agreed.
- [ ] Live scripting or Drafts chosen deliberately; Drafts window on the team tab if used.
- [ ] Source control for code (Script Sync or Rojo plus Git).
- [ ] Snapshot plus named save before every risky change.
- [ ] Nobody uses undo to fix shared mistakes.
- [ ] Revert procedure: disable Team Create, restore, re-enable.

## See also

- [[Safe Changes in a Shared Place]], [[Team Roles and Workflows]], [[Documentation and Knowledge Bases]]
- [[Version History and Backups]], [[Command Bar and Studio Scripting]], [[Packages and Asset Reuse]]
- [[Git and Source Control for Roblox]], [[External Tooling - Rojo Wally Selene StyLua]]
- [[Places Universes and Experience Settings]]

## Connected notes
<!-- auto-links:start -->
[[Team Create Permissions and Workflows]] · [[Links - Team Create]] · [[Team Collaboration Start Here]] · [[Studio Interface Tour]] · [[Documentation and Onboarding New Developers]] · [[Packages and Shared Assets Across Places]]
<!-- auto-links:end -->
