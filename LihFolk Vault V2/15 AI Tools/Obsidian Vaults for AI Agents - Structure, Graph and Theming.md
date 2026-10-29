---
tags: [ai, obsidian, vault, knowledge-base, graph, css, theming, documentation, lihfolk, type/guide, area/ai, level/intermediate]
---
# Obsidian Vaults for AI Agents - Structure, Graph and Theming

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Adding a "Home" link to every note and wondering why the graph is one ball.
> - Avoid: Debugging CSS while the vault is in restricted mode.
> - Avoid: Snippet rules without `!important` competing with a theme that uses it.
> - Fixed note shape; hub per section; generated TL;DR and slim index
> - Links mostly section-local; few deliberate bridges
> - Restricted mode off before theme debugging
>
> Cost: TL;DR ~140 tok · whole note ~1.6k tok. Read more: ## 2. Graph shape follows link structure · ## 3. Theming with CSS snippets · ## Common mistakes · ## Checklist
<!-- tldr:end -->

verified: 2026-10-28

How to build an Obsidian vault that serves two readers at once: AI agents that search and read notes as plain Markdown, and humans who browse it in Obsidian with a graph and a custom theme. Lessons from building LihFolk Vault V2; **Measured** marks things observed in this project.

## 1. Structure for agents first

Agents never see the theme. They see files. What helps them:

- **Numbered section folders** (`07 Lighting VFX and Audio`) with a "Start Here" hub per section.
- **One fixed note shape:** frontmatter tags, H1 title equal to the file name, numbered `##` sections, then `## Common mistakes`, `## Checklist`, `## See also`, `## Connected notes`. Agents learn to jump straight to the section they need.
- **A generated TL;DR block** at the top of each note and a generated slim index, so a search returns a few hundred tokens instead of whole notes. See [[Token Cost Benchmarks]].
- **A symptom file** that maps everyday bug descriptions ("screen goes black when hit") to notes. Agents search with the user's words, not the vault's vocabulary.
- **Dated claims** (`verified:` line) and labels such as Measured, so the agent can weigh a fact.
- **Machine checks in CI:** broken links, unknown API names, Luau snippets that fail to compile, numbers that disagree between notes.

## 2. Graph shape follows link structure

Obsidian's graph is a force layout: linked notes attract, everything else repels. The shape you get is decided by *how* notes link, not by colour settings.

- **Folder-local links** (each note links to siblings and its own section hub) produce **separate clusters**, one per section: the "galaxy" look.
- **Global hub links** (every note links to Home, INDEX or the router) pull everything to the centre and produce **one dense ball**. **Measured:** in this vault, the link structure alone flipped the graph between one ball (hub-wide links) and separated section clusters (section-local links); colour and force settings did not.
- Colour groups (`graph.json`, queries like `path:"07 Lighting VFX and Audio/"`) only tint nodes. They do not separate anything.
- If you want clusters, generate "related" links within the section and allow only a few deliberate cross-section bridges.
- Large generated index notes linking to every note act as a gravity well. Exclude them from the graph with a filter, or accept the ball.

## 3. Theming with CSS snippets

- **`!important` precedence.** Themes and plugins often set colours with `!important`. A snippet rule without it loses even with a more specific selector. When two snippets both use `!important`, the more specific selector wins, then the one loaded later. Keep one snippet as the "owner" of each property to avoid fights.
- **Style Settings.** The Style Settings plugin reads a `/* @settings ... */` YAML comment block at the top of a snippet and turns its variables into toggles and sliders. The block must be valid YAML (indentation matters), and each setting `id` must match the CSS variable or class it controls. A YAML error makes the whole panel disappear without a message.
- **Restricted mode disables plugins.** Obsidian's restricted mode (the default for a newly opened vault) turns off all community plugins: Style Settings, Linter, 3D graph, icon folders. A theme that depends on Style Settings variables then looks broken. Turn restricted mode off for the vault before debugging CSS.

## 4. Screenshots and "blank" renders

Obsidian (Electron) stops repainting when its window is covered or minimised. A screenshot taken through automation then comes back blank or stale. **Measured:** blank captures during theme work were not CSS bugs; bringing the window to the front and waiting a moment fixed them. Before chasing a "nothing renders" bug, make sure the window is visible.

## 5. Plugins that fight generated content

- **Linter can wreck generated blocks.** Obsidian Linter's format-on-save rules (heading spacing, list markers, trailing spaces, YAML ordering) rewrite text between generator markers such as `<!-- tldr:start -->`. The next index build then sees a diff everywhere, or the markers break. Exclude generated folders and notes from Linter, or turn off lint-on-save, and let the generator own its blocks.
- Smart-connection or embedding plugins write caches (for example `.smart-env/`) that should be git-ignored.

## 6. Folder names are API

Skills, hooks, CI and scripts address the vault by path. Renaming the vault folder breaks every reference at once. Grep before renaming. See [[Windows Tooling Pitfalls for Agent Pipelines]].

## Common mistakes

- Adding a "Home" link to every note and wondering why the graph is one ball.
- Debugging CSS while the vault is in restricted mode.
- Snippet rules without `!important` competing with a theme that uses it.
- Invalid YAML in the `@settings` block, which silently hides the Style Settings panel.
- Letting Linter reformat generated blocks.
- Treating a blank automated screenshot as a rendering bug.

## Checklist

- [ ] Fixed note shape; hub per section; generated TL;DR and slim index
- [ ] Links mostly section-local; few deliberate bridges
- [ ] Restricted mode off before theme debugging
- [ ] One snippet owns each property; `!important` used deliberately
- [ ] `@settings` YAML validated; ids match CSS variables
- [ ] Linter excluded from generated blocks
- [ ] Window visible before taking screenshots

## See also

- [[Documentation and Knowledge Bases]]
- [[Third-Party Skill - Obsidian Skills]]
- [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]]

## Connected notes

[[Case Study - Building LihFolk V2 with AI Agents]] · [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] · [[Token Cost Benchmarks]]

<!-- related:start -->
## Related
[[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[AI Agents and Autonomous Workflows]] · [[Roblox Studio Assistant]] · [[AI in Roblox Development Overview]] · [[Prompting and Verifying AI Output]] · [[AI Code Assistants for Luau]]
<!-- related:end -->
