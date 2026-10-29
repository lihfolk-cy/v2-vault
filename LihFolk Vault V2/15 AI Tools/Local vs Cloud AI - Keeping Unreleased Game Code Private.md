---
tags: [ai, privacy, security, local-models, data-retention, workflow, type/guide, area/ai, area/security, level/intermediate, api/HttpService, area/data]
---
# Local vs Cloud AI - Keeping Unreleased Game Code Private

<!-- tldr:start -->
> [!tldr] TL;DR
> - Never deciding on the consumer training toggle.
> - Avoid: Secrets in `.env` files the agent reads freely.
> - Avoid: Sharing a session via `/feedback` or a public paste without checking content.
> - Account type and training setting chosen deliberately; recorded for the team.
> - Secret files denied in agent permissions; no keys in the repo.
> - Local transcript retention set for the machine's risk.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 2. What a cloud coding agent sends · ## 4. Local models: when they are worth it · ## Common mistakes · ## Checklist
<!-- tldr:end -->

When an AI coding agent works on your game, your server code, economy numbers, unreleased update plans and sometimes API keys leave your machine and go to a model provider. For most Roblox developers that is an acceptable trade, but it should be a decision, not an accident. This note covers what actually gets sent, what providers keep and for how long, the settings that change it, when a local model is worth it, and the habits that matter more than the choice of model.

Labels as marked. Provider facts are dated; re-check them, they change.

---

## 1. What you are protecting, and from whom

Rank what leaks would cost you:

| Asset | Cost if it leaks | Note |
|---|---|---|
| Secrets (Open Cloud API keys, webhook URLs, HttpService tokens) | High and immediate | Never belongs in code or prompts at all ([[HttpService and External APIs]]) |
| Server code | Medium: exploiters learn your validation; cloners copy systems | Clients never receive server scripts, which is your main protection ([[How Exploits Work - The Client Boundary]]) |
| Unreleased content and update plans | Medium: leaks spoil launches | |
| Economy numbers and analytics | Low to medium | |
| Client code and assets | Low | Players already receive these; exploit tools can read them |

The threats are different: a provider's **retention and training** policy, a **breach** of a provider or a tool, a **malicious or careless tool** (a community MCP server or plugin that exfiltrates), and **your own mistakes** (a key pasted into a prompt, a transcript shared publicly). The last two cause most real incidents (**Rule of thumb**).

---

## 2. What a cloud coding agent sends

For Claude Code, the docs state that prompts and model outputs are sent to the API over TLS, which means every file the agent reads into context is sent (Claude Code docs: [Data usage](https://code.claude.com/docs/en/data-usage)). Key points as of October 2026:

| Account type | Training on your code | Retention |
|---|---|---|
| Consumer (Free, Pro, Max) | Only if you allow it in privacy settings | 5 years if you allow training; 30 days if not |
| Commercial (Team, Enterprise, API) | Not trained on, unless you opt into a programme such as the Development Partner Program | 30 days standard; zero data retention available for qualified Enterprise organisations |

Other local facts from the same page:

- Claude Code stores session transcripts **locally in plaintext** under `~/.claude/projects/` for 30 days by default (`cleanupPeriodDays` changes it). Anything the agent read, including a secret it opened by mistake, is in those files.
- `/feedback`, `/bug` and `/share` send the conversation, including code, and those reports are retained for 5 years. Telemetry metrics do not include code or prompts; `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` turn optional traffic off.
- Routing through Amazon Bedrock, Google Cloud or Microsoft Foundry keeps the provider relationship with that cloud; their own data terms apply.

Other tools (Cursor, Copilot, Codex, Gemini CLI, [[Roblox Assistant]]) have their own policies and privacy modes. **Unverified** here: read each vendor's current data page before relying on it.

**Roblox Assistant** runs on Roblox's service and sees your place's data model; since early 2026 it can also call external models with your own API key (DevForum, 21 February 2026: [Studio MCP Server Updates and External LLM Support](https://devforum.roblox.com/t/studio-mcp-server-updates-and-external-llm-support-for-assistant/4415631)), in which case that provider's terms apply too.

---

## 3. Settings that matter most

1. **Consumer accounts: decide on the training toggle** at claude.ai privacy settings (or your vendor's equivalent). With it off, retention drops to 30 days for Claude consumer accounts.
2. **Use a commercial plan** for a studio's codebase, so the no-training default applies and you have a contract.
3. **Deny reads of secret files** with permission rules. In Claude Code settings:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ]
  }
}
```

(Adapt the list to where your secrets actually live. Permission rule syntax: Claude Code settings and permissions docs. Deny rules on `Read` do not stop a shell command such as `cat` unless Bash is also restricted; check the current docs for how your version applies them.)

4. **Shorten local transcript retention** on shared machines (`cleanupPeriodDays`), or encrypt the disk.
5. **Turn off non-essential traffic** if your organisation requires it.

---

## 4. Local models: when they are worth it

Running an open-weight model locally (through a local inference server) means code never leaves the machine. Trade-offs (**Rule of thumb**, as of 2026):

| | Cloud frontier model | Local model |
|---|---|---|
| Luau and Roblox API knowledge | Strongest; still makes Roblox mistakes ([[What AI Models Get Wrong in Roblox]]) | Noticeably weaker on Roblox specifics; more invented APIs |
| Long agentic tasks with tools | Good | Usually unreliable for long multi-step work |
| Privacy | Depends on terms and settings | Code stays local |
| Cost | Per token or subscription | Hardware; a strong local model needs a high-memory GPU |

Sensible splits:

- **Local for the sensitive slice**: anti-cheat heuristics, economy formulas before an update, anything under NDA with a brand partner.
- **Cloud for the rest**: UI, tooling, refactors, tests, docs.
- Whatever model you use, the LihFolk vault workflow works the same: `vault.py` runs locally, and the hook checker runs locally. Ground a weaker local model with the vault's notes to cut invented APIs.

---

## 5. Habits that beat any setting

- **No secrets in the repo.** Use Roblox Secrets for HttpService keys and CI secrets for Open Cloud keys ([[Code Pipeline - Rojo Git and CI]]). If a key was ever in a file an agent read, rotate it.
- **Vet tools that see your code.** A community MCP server or Studio plugin has the access of the agent itself ([[Built-In Studio MCP vs Community MCP Servers - Migration Guide]], [[Plugin Security and Permissions]]).
- **Scope what the agent can read.** Start agents in the project folder, not your home directory.
- **Do not share transcripts publicly** without reading them; they contain code and paths.
- **Assume server code will leak eventually.** Security that depends on secret code is weak; validation on the server is what protects you ([[Server Authority and Validation]]).

---

## Common mistakes

- Never deciding on the consumer training toggle.
- Secrets in `.env` files the agent reads freely.
- Sharing a session via `/feedback` or a public paste without checking content.
- Installing unknown MCP servers with access to the whole repo.
- Switching to a weak local model for everything and shipping its invented APIs.
- Believing hidden server code is the anti-exploit.

## Checklist

- [ ] Account type and training setting chosen deliberately; recorded for the team.
- [ ] Secret files denied in agent permissions; no keys in the repo.
- [ ] Local transcript retention set for the machine's risk.
- [ ] Every third-party tool with code access vetted.
- [ ] Sensitive slices identified; local or restricted workflow for those if needed.
- [ ] Any key an agent saw has been rotated.

## See also

- [[AI Code Assistants for Luau]], [[Evaluating AI Tools - A Practical Rubric]], [[Safety Rules for AI Agents in Studio]]
- [[HttpService and External APIs]], [[Plugin Security and Permissions]]
- [[Who Owns AI-Generated Code and Assets]]

## Connected notes

[[AI in Roblox Development Overview]] · [[Setting Up MCP Clients]] · [[Roblox Studio Assistant]] · [[Token Cost Benchmarks]]

<!-- related:start -->
## Related
[[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[AI Agents and Autonomous Workflows]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]] · [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] · [[Prompting and Verifying AI Output]] · [[Roblox Policies on AI-Generated Content]] · [[Windows Tooling Pitfalls for Agent Pipelines]]
<!-- related:end -->
