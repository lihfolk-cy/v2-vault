---
tags: [business, legal, licensing, open-source, libraries, wally, type/reference, area/business, level/intermediate]
---
# Open-Source Licenses for Roblox Libraries - Quick Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using "free on GitHub" code that has no licence.
> - Avoid: Deleting licence headers when copying a module into Studio.
> - Avoid: Assuming MPL tools make your code MPL.
> - Every third-party library has a known licence (no "none").
> - Licence text or header travels with each library's code.
> - Apache-2.0 changes marked; MPL file changes shared if distributed.
>
> Cost: TL;DR ~130 tok · whole note ~1.8k tok. Read more: ## 1. What each licence asks of a game · ## 2. Popular Roblox libraries and tools (checked 28 October 2026) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most serious Roblox games ship community libraries: a profile manager, a promise library, a signal class, a cleanup helper, a UI framework. Each one comes with a licence, and the licence comes with duties. [[Legal Basics - IP Licenses and Assets]] explains the licence families in general. This note is the quick reference: what each common licence asks of a Roblox game in practice, a table of popular Roblox libraries and tools with their licences as checked in October 2026, and a compliance setup that takes ten minutes.

Not legal advice. Licences in the table were read from the GitHub API on 28 October 2026 (**Measured**); repositories can change licence, so re-check before relying on a row.

---

## 1. What each licence asks of a game

A Roblox game is distributed to players' devices (client code and assets) and runs on Roblox servers (server code). Whether shipping a game counts as "distribution" of server-side code is a legal question with no Roblox-specific ruling; treat client-side use as distribution and be conservative with server-side (**Rule of thumb**).

| Licence | Practical duties for a game using the library | Risk level |
|---|---|---|
| **MIT** | Keep the copyright notice and licence text with copies of the code | Low |
| **BSD-2/3-Clause** | Same as MIT; 3-Clause also forbids using the authors' names to endorse | Low |
| **Apache-2.0** | Keep the licence and notices (including any NOTICE file); mark files you changed; patent grant and patent-retaliation clause | Low |
| **MPL-2.0** | Changes to the MPL-covered files themselves must be available under MPL if you distribute them; your other files stay yours | Low if you do not edit library files |
| **GPL / LGPL / AGPL** | Copyleft; scope for a Roblox game is unclear and debated | High uncertainty: most studios avoid in games |
| **CC0 / Unlicense** | None (public domain dedication) | Low |
| **No licence** | All rights reserved; you have no permission to use it | Do not use |

**Tools vs shipped code.** Tools you run on your machine or CI (Rojo, Wally, Selene, StyLua, Lune) do not ship inside your game. Their licences govern the tool, not your game's code; using an MPL-2.0 formatter does not make your code MPL.

---

## 2. Popular Roblox libraries and tools (checked 28 October 2026)

| Project | Repo | Licence | Notes |
|---|---|---|---|
| [[ProfileStore]] | MadStudioRoblox/ProfileStore | Apache-2.0 | Data sessions ([[Session Locking and Profile Libraries]]) |
| ProfileService | MadStudioRoblox/ProfileService | Apache-2.0 | Older sibling of ProfileStore |
| roblox-lua-promise | evaera/roblox-lua-promise | MIT | |
| Janitor | howmanysmall/Janitor | MIT | Cleanup |
| RbxUtil (Trove, Signal, Comm and others) | Sleitnick/RbxUtil | MIT | |
| Knit | Sleitnick/Knit | MIT | Repository archived |
| GoodSignal | stravant/goodsignal | MIT | |
| Fusion | dphfox/Fusion | MIT | UI |
| React Lua | jsdotlua/react-lua | MIT | UI |
| Roact | Roblox/roact | Apache-2.0 | Repository archived |
| Jest-Lua | jsdotlua/jest-lua | MIT | Tests ([[Automated Testing with TestEZ and Jest-Lua]]) |
| TestEZ | Roblox/testez | Apache-2.0 | Repository archived |
| ZonePlus | 1ForeverHD/ZonePlus | MIT | |
| jecs | Ukendio/jecs | MIT | [[Entity Component System\|ECS]] |
| Zap | red-blox/zap | MIT | Networking code generator |
| Rojo | rojo-rbx/rojo | MPL-2.0 | Tool, not shipped |
| Rokit | rojo-rbx/rokit | MIT | Tool |
| Wally | UpliftGames/wally | MPL-2.0 | Tool |
| Selene | Kampfkarren/selene | MPL-2.0 | Tool |
| StyLua | JohnnyMorganz/StyLua | MPL-2.0 | Tool |
| luau-lsp | JohnnyMorganz/luau-lsp | MIT | Tool |
| Lune | lune-org/lune | MPL-2.0 | Tool ([[Lune]]) |

Check a repo yourself in one command (unauthenticated GitHub API, rate limited):

```bash
curl -s https://api.github.com/repos/evaera/roblox-lua-promise | python -c "import json,sys; print(json.load(sys.stdin)['license']['spdx_id'])"
```

Libraries copied from the Creator Store, a DevForum post or a Discord message often have **no licence** at all. Ask the author for one, or write your own.

---

## 3. A ten-minute compliance setup

1. **Keep licence text with the code.** For each third-party library, keep its LICENSE (and NOTICE for Apache-2.0) next to it in the repo, for example `Packages/_licenses/<name>.txt` or a comment block at the top of the vendored module.
2. **Put notices in the place too.** If you vendor code into Studio, add the licence as a comment header in the ModuleScript. Rojo syncs scripts, not loose `.txt` files, unless you map them; a comment header always travels with the code.
3. **Credits screen (optional, good practice).** An in-game "Credits and licences" page listing libraries and authors satisfies the spirit of attribution licences and builds goodwill.
4. **Mark your changes** to Apache-2.0 files (a "Modified by <studio>, <date>" line), and publish changes to MPL files if you distribute them.
5. **Licence log.** One row per dependency: name, version, licence, source URL, date checked. The same log covers assets ([[Legal Basics - IP Licenses and Assets]]).
6. **Re-check on update.** A version bump can change licence; check when Wally updates a dependency.

---

## 4. AI-generated code and licences

AI assistants sometimes reproduce well-known library code. If a generated module looks like a known library (same function names, same comments), treat it as that library: find the original, use it with its licence, or rewrite. See [[Who Owns AI-Generated Code and Assets]].

---

## 5. When selling or licensing your game

Buyers and publishers ask for a dependency list with licences. With the log from section 3 this is a copy-paste; without it, it is a week of archaeology. GPL or unlicensed code found late can block a deal.

---

## Common mistakes

- Using "free on GitHub" code that has no licence.
- Deleting licence headers when copying a module into Studio.
- Assuming MPL tools make your code MPL.
- GPL code in a commercial game without legal advice.
- Never re-checking licences after updates.
- Treating AI output that copies a library as licence-free.

## Checklist

- [ ] Every third-party library has a known licence (no "none").
- [ ] Licence text or header travels with each library's code.
- [ ] Apache-2.0 changes marked; MPL file changes shared if distributed.
- [ ] Licence log kept and re-checked on updates.
- [ ] No GPL-family or unlicensed code in the game without a deliberate decision.
- [ ] Optional credits screen lists libraries and authors.

## See also

- [[Legal Basics - IP Licenses and Assets]], [[Who Owns AI-Generated Code and Assets]]
- [[External Tooling - Rojo Wally Selene StyLua]], [[Creator Store and Toolbox Safety]]
- [[Free Mocap and Mixamo Licensing for Roblox]]

## Connected notes

[[Running a Small Studio as a Business]] · [[Module Scripts and Requiring]] · Code Pipeline - Rojo Git and CI · Session Locking and Profile Libraries

<!-- related:start -->
## Related
[[Frameworks - Knit Matter and Others]] · [[Code Pipeline - Rojo Git and CI]] · [[Commissions Pricing and Contracts]] · [[Hiring Freelancers and Revenue Shares]] · [[Building a Portfolio as a Roblox Developer]] · [[DevEx and Cashing Out]]
<!-- related:end -->
