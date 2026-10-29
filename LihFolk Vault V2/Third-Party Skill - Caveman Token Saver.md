---
tags: [ai, agents, ai-skill, tokens, third-party, type/guide, area/ai, level/intermediate]
---
# Third-Party Skill - Caveman Token Saver

**Source:** [github.com/JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (Apache-2.0, by Julius Brussee). Not written for this vault and not shipped in the `skills` folder; install it from the source. Everything below is from the project's README as of October 2026 and is labelled **unverified** unless it says otherwise. Recheck the README before relying on any number.

## What it does

Caveman makes an AI coding agent write shorter answers and read less input, so long Roblox sessions (big Luau modules, Studio MCP output, playtest logs) last longer before the context fills and cost fewer tokens. It is split into separate parts, each with its own on/off switch:

- **Say less.** The agent leads with the result, drops greetings, preambles and recaps, and may drop articles. It keeps negations ("not", "never", "no") and exact numbers and units.
- **Payload verbatim.** Code, commands, file paths and error messages are left character for character. Your Luau is never "caveman-ified".
- **Your prompts are untouched.** It does not rewrite what you type.
- **Full sentences when it matters.** Security warnings, irreversible actions and confused users get normal prose.
- **Read less (proxy).** Logs, JSON, CSV, YAML and test output are shrunk before the model reads them; originals stay on disk.
- **Extras.** `caveman shrink -- <command>` compresses noisy command output, `caveman browse <url>` returns a compressed web page, and **Auto** routes each request to a model and effort level.

## Install (Claude Code)

From a terminal:

```
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
```

Or inside Claude Code:

```
/plugin marketplace add JuliusBrussee/caveman
/plugin install caveman@caveman
```

Skill only, without the proxy:

```
npx skills add JuliusBrussee/caveman -g
```

Full installer (detects your agents, adds a status line badge, needs Node.js 22.13 or newer):

```
npx @caveman-ai/cli@latest
```

The README lists Claude Code, Codex, Gemini CLI, OpenCode, Aider and others. Windows works through PowerShell.

## Commands

| In the agent | Effect |
|---|---|
| `/caveman` | Default terse voice |
| `/ultracave` | More compressed |
| `/megacave` | Classical Chinese style, the most compressed |
| `/caveman status` / `/caveman off` | Show the mode / turn it off (or say "stop caveman") |
| `/caveman-commit` | One-line Conventional Commit message |
| `/caveman-review` | Code review, one finding per line |
| `/caveman-compress <file>` | Shrinks a memory or instructions file, keeps a backup |
| `/caveman-stats`, `/caveman-help` | Savings and help |

Terminal: `caveman status`, `caveman on <rock>` / `caveman off <rock>`, `caveman stats`, `caveman doctor`, `caveman telemetry off`.

## Reported numbers (unverified, from the README)

- Ten dev questions on one model: about 6,983 output tokens with no instruction, 4,334 with a plain "be concise", 4,119 with `/caveman`, 2,693 with `/ultracave`.
- Whole Claude Code sessions with Read less: 33.2% fewer tokens, 18 of 18 answers still correct (run on an older engine).
- The voice rules themselves add about 1,160 input tokens per request, so on per-request billing shorter answers can save nothing.
- HTML has no compressor yet and came out larger in their test; tiny web forms also got larger through `caveman browse`.

Note the gap between plain "be concise" and `/caveman` is small. The bigger wins come from Read less and `/ultracave`.

## Using it on a Roblox project

- **Good fits:** long agent sessions over a large codebase, MCP-heavy work where tool output floods the context (see [[Roblox Studio MCP Server]] and [[MCP Workflows for Scripting and Debugging]]), and compressing a long project instructions file with `/caveman-compress`.
- **Keep it off** when you want explanations: learning Luau, writing player-facing text, design discussions, or handing a write-up to someone else. Terse answers are worse teaching material.
- **Review compressed instruction files** after `/caveman-compress`. Check that hard rules (never touch live DataStores, Edit mode only) survived word for word. Rules from [[Safety Rules for AI Agents in Studio]] must not be shortened into ambiguity.
- **It works alongside the vault skills.** Caveman changes how the agent talks, not what it does, so [[Skill - Roblox Secure Remotes]] and the others still apply. Ask for the full reasoning when a skill's "checks before finishing" matter.
- **Measure, do not assume.** Compare a normal week against a Caveman week with `/caveman-stats` and your provider's usage page before keeping it on. See [[Evaluating AI Tools - A Practical Rubric]].

## Privacy

- The skill runs locally. `/caveman-compress` sends the file to your configured model provider.
- The CLI sends anonymous usage stats by default. Turn off with `caveman telemetry off` or the `DO_NOT_TRACK=1` environment variable.
- **Auto** routing needs a free account (`caveman login`) and sends your latest request, the previous one and related metadata to Caveman's cloud. Leave it off (`caveman off routing`) on private or unreleased game code.

## Uninstall

```
npx -y github:JuliusBrussee/caveman -- --uninstall
npx skills remove JuliusBrussee/caveman -g
```

On npm 12 or newer, add `--allow-git=root` to the first command.

## Related

- [[AI Skills Start Here]]
- [[AI Code Assistants for Luau]]
- [[Prompting and Verifying AI Output]]
- [[Agent Review Loops and Guardrails in Practice]]

## Connected notes
<!-- auto-links:start -->
[[Third-Party Skill - Obsidian Skills]] · [[Setting Up MCP Clients]] · AI in Roblox Development Overview · Writing Your Own MCP Server · Case Study - Building a Game with AI Agents · Studio Assistant and AI Tools
<!-- auto-links:end -->
