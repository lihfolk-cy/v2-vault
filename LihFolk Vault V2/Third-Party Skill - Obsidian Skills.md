---
tags: [ai, agents, ai-skill, obsidian, third-party]
---
# Third-Party Skill - Obsidian Skills

**Source:** [github.com/kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) by Steph Ango, MIT licence, version 1.0.1 as of October 2026. Not written for this vault and not shipped with it: install it from the link above if you want it.

## What it does

Six agent skills that teach an AI agent how Obsidian files actually work, so it edits this vault without breaking links, properties or embeds:

| Skill | Use it for |
|---|---|
| `obsidian-markdown` | Wikilinks, embeds, callouts, properties (frontmatter) and tags in `.md` notes |
| `obsidian-bases` | `.base` files: table and card views of notes with filters, formulas and summaries |
| `json-canvas` | `.canvas` files: mind maps and flowcharts with nodes, edges and groups |
| `obsidian-cli` | Reading, searching and managing a vault through the Obsidian CLI, plus plugin and theme debugging |
| `defuddle` | Turning a web page into clean Markdown before saving it as a note (fewer tokens than raw HTML) |
| `knap` | Generating notes in bulk from a template plus JSON or CSV data |

## Already installed in this vault

The README's manual install for Claude Code is "put the skills in a `.claude` folder at the vault root", and that is done. Open Claude Code with the vault folder as the working directory and the six skills load on their own. Obsidian hides folders that start with a dot, so the files do not appear in search or the graph.

To use them everywhere instead of only in this vault, install the plugin in Claude Code:

```
/plugin marketplace add kepano/obsidian-skills
/plugin install obsidian@obsidian-skills
```

Other agents: copy the `skills` folder into the tool's skills path (Codex uses `~/.codex/skills`), or run `npx skills add https://github.com/kepano/obsidian-skills`.

## Using them with this vault

- **Adding your own notes.** Ask the agent to write notes in your own folder. `obsidian-markdown` keeps wikilinks and tags in the vault's style. Keep the vault's habits: label sources, no invented numbers, link to existing notes by exact title.
- **Dashboards with Bases.** Ask for a `.base` that lists, for example, every note tagged `ai-skill` or every Worked Build, as a table. This is a quick way to build your own study tracker over the vault.
- **Visual maps with Canvas.** Ask for a `.canvas` laying out one section's notes as a learning path, such as [[AI Skills Start Here]] to each skill note.
- **Saving research.** `defuddle` turns a Roblox docs or DevForum page into clean Markdown for a personal note. Rewrite it in your own words; do not paste whole pages into a shared vault.
- **Pair with the research skill.** [[Skill - Roblox Vault Research]] tells an agent how to answer questions from the vault; the Obsidian skills tell it how to write vault files correctly.

## Cautions

- Agents can edit or rename many notes at once. Back up the vault or use version control before bulk changes, and review what changed, as in [[Agent Review Loops and Guardrails in Practice]].
- `obsidian-cli`, `defuddle` and `knap` call separate command-line tools that must be installed first; the skill files explain how.
- The vault's own skills never edit vault notes. These skills exist to edit them, so point them at your own folders, not the shipped sections, if you want clean updates when a new vault version comes out.

## Related

- [[AI Skills Start Here]]
- [[Third-Party Skill - Caveman Token Saver]]
- [[Using This Vault in Obsidian]]

## Connected notes
<!-- auto-links:start -->
[[LICENSE]] · [[Skill - Roblox Debugging]] · [[LihFolk UI Design System]] · [[Studio Assistant and AI Tools]] · [[Setting Up MCP Clients]] · [[CHANGELOG]]
<!-- auto-links:end -->
