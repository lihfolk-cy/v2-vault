---
tags: [ai, agents, windows, powershell, encoding, utf-8, paths, tooling, lihfolk, type/troubleshooting, area/ai, area/studio, level/intermediate]
---
# Windows Tooling Pitfalls for Agent Pipelines

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using `Get-Content | ... | Set-Content` on UTF-8 notes in Windows PowerShell 5.1.
> - Avoid: Renaming a project folder without grepping for the old name.
> - Avoid: Writing `python` in commands that agents will run on Windows.
> - File edits go through UTF-8-safe tools or explicit `-Encoding utf8`
> - Mojibake grep after any bulk text edit
> - Every path quoted; forward slashes in Bash
>
> Cost: TL;DR ~140 tok · whole note ~1.5k tok. Read more: ## 1. PowerShell 5.1 and UTF-8 mojibake · ## 3. Renaming the vault folder breaks every path · ## Common mistakes · ## Checklist
<!-- tldr:end -->

verified: 2026-10-28

Most Roblox developers work on Windows, and AI agents driving their tools hit a recurring set of traps: text encoding in Windows PowerShell 5.1, paths with spaces, the Microsoft Store `python` alias, and hard-coded paths that break when a folder moves. Each item below was hit while building LihFolk V2 (**Measured** where noted).

## 1. PowerShell 5.1 and UTF-8 mojibake

Windows ships **Windows PowerShell 5.1**, not PowerShell 7. Its file cmdlets do not default to UTF-8:

- `Get-Content` without `-Encoding` reads a BOM-less UTF-8 file as the ANSI code page. Em dashes, arrows, degree signs and emoji come back as two or three garbage characters.
- `Set-Content` and `Add-Content` write the ANSI code page by default. Writing back what was just read **saves the mojibake permanently**.
- `Out-File` and `>` write UTF-16 LE in 5.1 by default (some configured environments use UTF-8 with BOM). Python, Git and Obsidian may then see null bytes or a stray BOM.

**Measured:** this happened to vault notes during the build. A read-modify-write through `Get-Content`/`Set-Content` turned non-ASCII punctuation (dashes, arrows, symbols) into mojibake, and nothing failed loudly: the corruption is only visible when someone reads the text.

Fixes, in order of preference:

1. Edit files with the agent's own file tools (they read and write UTF-8), or with Python using `encoding="utf-8"` explicitly.
2. In PowerShell 5.1 always pass `-Encoding utf8` to `Get-Content`, `Set-Content` and `Out-File`. Note this writes a BOM in 5.1; strip it if a tool dislikes it.
3. Use PowerShell 7 (`pwsh`), where UTF-8 without BOM is the default.
4. After a bulk edit, grep for typical mojibake sequences (for example `Ã`, `â€`) before committing.

## 2. Paths with spaces

Project folders like `D:\LihFolk Build\LihFolk Plugin` break any command that does not quote paths.

- Quote every path in shell commands, including inside scripts written by the agent.
- In Bash on Windows, use forward slashes (`/d/LihFolk Build/...`) and quotes.
- Pass paths as arguments, not by string-concatenating them into a command line.

## 3. Renaming the vault folder breaks every path

Skills, hooks, CI workflows, README commands, generator scripts and the notes themselves referred to the vault by its folder name. Renaming the folder silently broke all of them: skills pointed to a missing directory and hooks ran against nothing.

- Before renaming, grep the whole repo for the old name, including `.claude/`, `.github/`, skill reference files and plugin manifests.
- Prefer one configured root (an environment variable or a single constant) that everything else derives from.
- After renaming, run every tool once (search, index build, checks) and a skill that reads the vault, and confirm each finds its files.

## 4. `python` opens the Microsoft Store

On a fresh Windows install, `python` and `python3` on PATH are Store aliases. Running them from an agent prints "Python was not found; run without arguments to install from the Microsoft Store" and exits (**Measured** in this environment).

- Use the launcher: `py script.py` (or `py -3`).
- Or disable the aliases in Settings > Apps > Advanced app settings > App execution aliases.
- In docs and skills, write commands that work with either (`py` on Windows, `python3` elsewhere), or detect the interpreter once.

## 5. Line endings and Git

- Git's `core.autocrlf=true` converts LF to CRLF on checkout. Generated files then show whole-file diffs when a script rewrites them with LF.
- Add a `.gitattributes` with `* text=auto eol=lf` for Markdown, Luau and Python, so every tool agrees.
- Shell scripts with CRLF fail in Bash with `$'\r': command not found`.

## 6. Two shells, two syntaxes

Agents on Windows often have both Git Bash and PowerShell. Common slips:

- PowerShell 5.1 has no `&&`; use `;` or `if ($?) { ... }`.
- `2>&1` on native programs in PowerShell 5.1 wraps stderr lines as errors and marks the command failed even on exit code 0.
- `/dev/null` in Bash, `$null` in PowerShell.
- Heredocs are Bash; PowerShell uses here-strings with the closing `'@` at column 0.

## Common mistakes

- Using `Get-Content | ... | Set-Content` on UTF-8 notes in Windows PowerShell 5.1.
- Renaming a project folder without grepping for the old name.
- Writing `python` in commands that agents will run on Windows.
- Unquoted paths in generated scripts.
- Mixing CRLF and LF in generated files and drowning reviews in whitespace diffs.

## Checklist

- [ ] File edits go through UTF-8-safe tools or explicit `-Encoding utf8`
- [ ] Mojibake grep after any bulk text edit
- [ ] Every path quoted; forward slashes in Bash
- [ ] Folder renames preceded by a repo-wide grep, followed by running every tool
- [ ] `py` launcher or disabled Store aliases
- [ ] `.gitattributes` sets LF for text files

## See also

- [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]]
- [[Git and Source Control for Roblox]]
- [[Setting Up MCP Clients]]

## Connected notes

[[Case Study - Building LihFolk V2 with AI Agents]] · [[Obsidian Vaults for AI Agents - Structure, Graph and Theming]] · [[AI Agents and Autonomous Workflows]]

<!-- related:start -->
## Related
[[Token Cost Benchmarks]] · [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[AI Code Assistants for Luau]] · [[Roblox Studio Assistant]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[AI in Roblox Development Overview]]
<!-- related:end -->
