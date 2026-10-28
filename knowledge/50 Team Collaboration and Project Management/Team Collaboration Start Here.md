---
cssclasses: [vault-hub]
tags: [team, hub, start-here, collaboration, production, project-management]
---
# Team Collaboration Start Here

Most Roblox games are made by small teams. The engine gives them a shared place with no branches or locks, group permissions, packages and group payouts. Everything else (who changes what, how work is planned and reviewed, how money is split, how newcomers learn the project) is up to the team. This section covers that.

The vault already has the foundations. Read them first, then use this section to go deeper:

- Studio features: [[Team Create and Collaboration]], [[Packages and Asset Reuse]], [[Version History and Backups]], [[Places Universes and Experience Settings]]
- Code on disk: [[Code Pipeline - Rojo Git and CI]], [[Git and Source Control for Roblox]], [[External Tooling - Rojo Wally Selene StyLua]]
- Production: [[Planning and Scoping a Roblox Game]], [[Scoping and Roles for Small Teams]], [[Team Roles and Workflows]], [[Documentation and Knowledge Bases]], [[Safe Changes in a Shared Place]], [[Release Process and Rollbacks]]
- People and money: [[Groups Roles and Permissions for Studios]], [[Hiring Freelancers and Revenue Shares]], [[Commissions Pricing and Contracts]], [[DevEx and Cashing Out]]

## The six deep notes

| Note | The question it answers |
|---|---|
| [[Team Create Permissions and Workflows]] | Access per project stage, contractor sandboxes as separate experiences, drafts or live scripting as a team, claiming areas with code, the access audit |
| [[Packages and Shared Assets Across Places]] | Asset ids versus packages versus code, how a package change reaches players, dev and stable pairs, drift across places, migrating a departing owner's packages |
| [[Code Review for Luau Teams]] | Review order, Luau smells with fixes, size and turnaround, automating style, Studio-only and AI-generated code |
| [[Roadmaps Milestones and Scope Control]] | Planning layers, checkable exit criteria, ranged estimates and buffers, change budgets and kill lists, platform items, live roadmaps |
| [[Working with Contractors and Revenue Splits]] | Engagement lifecycle, acceptance criteria and change orders, an intake scanner, how payout splits cascade, points pools, offboarding |
| [[Documentation and Onboarding New Developers]] | Access lead time, one-command setup, a day-one document, starter tasks, module headers and ADRs, a generated remote index, onboarding non-programmers |

## Suggested reading order

1. **Starting a team:** Team Create Permissions and Workflows, then Roadmaps Milestones and Scope Control, then Documentation and Onboarding New Developers.
2. **Hiring outside help:** Working with Contractors and Revenue Splits, then Team Create Permissions and Workflows (the sandbox section), then [[Hiring Freelancers and Revenue Shares]].
3. **Growing past three scripters:** Code Review for Luau Teams, then [[Code Pipeline - Rojo Git and CI]].
4. **Several places or several games:** Packages and Shared Assets Across Places, then [[Teleporting and Multi-Place Games]].

## Shared ideas across the section

- **Groups early.** Only group roles give non-friends Edit, separate editing from publishing, and keep the game when someone leaves.
- **Least access, by experience.** Permissions attach to experiences, so outsiders get separate sandbox experiences.
- **Machine-readable contracts.** Claims, `Doc` attributes, package attribute names and acceptance criteria can all be checked by a script.
- **Ranges, not promises.** Estimates, roadmaps and shares are stated as ranges or rules.
- **Write it down the same day.** Changelog lines, change orders, ADRs, payout records and handover notes are cheap now and expensive later.

## Related notes elsewhere in the vault

- Releasing and operating: [[Feature Flags and Staged Rollouts]], [[Live Incident Response and Post-Mortems]], [[Event Calendars and Content Planning]], [[Update Cadence and Hype Cycles]]
- Quality: [[Automated Testing with TestEZ and Jest-Lua]], [[Multi-Client and Device Playtesting Protocols]], [[QA Checklists Before Release]], [[Server Authority and Validation]]
- Security around collaborators: [[Creator Store and Toolbox Safety]], [[Plugin Security and Permissions]], [[Open Cloud APIs]]
- AI in the team: [[Working with AI Assistants in Studio]], [[AI Code Assistants for Luau]]
- From a live game: [[Release Process and Rollbacks]], [[Running a Small Studio as a Business]]

## Source labels

Facts are labelled **Roblox docs (as of October 2026)**, **measured in the reference project** (one live production game), or **rule of thumb**. Native branching and package overrides were reportedly announced in September 2026 but are unconfirmed here; check the Creator Hub first.

## Connected notes
<!-- auto-links:start -->
[[Business and Careers Start Here]] · [[Links - Team Create]] · [[Lessons Learned Index]] · [[Animation Asset Permissions and Groups]] · [[Plugin Development Start Here]] · [[Live Ops Deep Dive Start Here]]
<!-- auto-links:end -->
