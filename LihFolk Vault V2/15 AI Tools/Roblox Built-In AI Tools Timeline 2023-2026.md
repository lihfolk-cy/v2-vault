---
tags: [ai, roblox, timeline, assistant, mcp, cube, generative-ai, history, type/reference, area/ai, level/beginner]
---
# Roblox Built-In AI Tools Timeline 2023-2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Following an AI tutorial without checking when it was written.
> - Avoid: Assuming a model knows about tools released after its training data.
> - Avoid: Treating betas as stable.
> - Advice dated before acting on it.
> - Tool names checked against the current MCP tool list.
> - New announcements added with links and dates.
>
> Cost: TL;DR ~120 tok · whole note ~1.9k tok. Read more: ## 1. The timeline · ## 2. Using it to spot stale advice · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI advice about Roblox goes stale fast. A 2024 tutorial says "Assistant can only write snippets"; a 2025 guide says "install the Rust MCP server"; a model trained before 2026 does not know Studio has an MCP server built in. This timeline lists what Roblox shipped and when, so you (or an agent) can date a piece of advice and know whether it is still true. Each row cites its source; rows without a firm date say so.

Labels: dates from **Roblox docs**, the **DevForum**, the **Roblox newsroom**, or **Measured** (GitHub API, October 2026). Feature details live in the linked notes; this is an index by date.

---

## 1. The timeline

| When | What | Source |
|---|---|---|
| March 2023 (GDC) | **Code Assist** and **Material Generator** released in beta: code suggestions from comments, and materials from text prompts | Press coverage at the time ([Voicebot, 22 Mar 2023](https://voicebot.ai/2023/03/22/roblox-debuts-generative-ai-game-creation-tools/)); RDC 2023 recap says "earlier this year, we released Code Assist and Material Generator into beta" |
| September 2023 (RDC) | **[[Roblox Assistant]]** announced as a conversational AI for creators | Roblox newsroom, [RDC 2023](https://about.roblox.com/newsroom/2023/09/rdc-2023-roblox-going-next). **Unverified:** exact date Assistant reached Studio beta |
| 18 March 2024 (GDC) | **Avatar Auto Setup** (alpha) and **Texture Generator** (public beta) announced | Roblox newsroom, [AI-powered avatar and texturing technologies](https://about.roblox.com/newsroom/2024/03/roblox-introduces-ai-powered-avatar-and-texturing-technologies-to-accelerate-3d-creation) |
| 2 October 2024 | Avatar Auto Setup open beta, including publishing to the Marketplace | DevForum, [Avatar Auto Setup Beta Release](https://devforum.roblox.com/t/avatar-auto-setup-beta-release/2960683). Later "Production Release" post exists; **Unverified** date |
| March 2025 | **Cube** announced as Roblox's "core generative AI system for 3D and 4D"; Cube 3D open-sourced; mesh generation from text | Roblox newsroom "Introducing Roblox Cube" (March 2025), see [[Roblox Generative AI - Cube Mesh and Texture Generation]]; `Roblox/cube` repo created 11 Mar 2025 (Measured) |
| 9 May 2025 | `Roblox/studio-rust-mcp-server`: open-source reference MCP server (Rust binary plus Studio plugin) | Measured: GitHub repo creation date |
| 30 June 2025 | Text-to-Speech API beta | DevForum, cited in [[AI Audio - Voice Music and SFX]] |
| 5 September 2025 | Assistant update: multi-step actions, planning, deeper data model search; **Studio natively acts as an MCP server, Assistant as an MCP client** | DevForum, [Assistant Update](https://devforum.roblox.com/t/assistant-update-boost-your-productivity-by-executing-complex-tasks/3920088) |
| 22 September 2025 | Text Generation API beta expands access (`TextGenerator` for in-game LLM text) | DevForum, cited in [[In-Game AI - LLM NPCs and Text Generation]] |
| 4 December 2025 | **StudioTestService**: plugins can start Play and Run tests and get results back | DevForum, [Introducing StudioTestService](https://devforum.roblox.com/t/introducing-studiotestservice/4116257) |
| December 2025 | **OpenGameEval** benchmark for agentic assistants in Studio | Roblox newsroom (December 2025), cited in [[What AI Models Get Wrong in Roblox]] |
| 21 February 2026 | Open-source MCP server gains `get_console_output`, `start_stop_play`, `run_script_in_play_mode`, `get_studio_mode`; **Assistant accepts external LLM API keys** (Anthropic, OpenAI, Google Gemini) | DevForum, [Studio MCP Server Updates and External LLM Support](https://devforum.roblox.com/t/studio-mcp-server-updates-and-external-llm-support-for-assistant/4415631) |
| 3 April 2026 | Reference MCP repository archived; Roblox directs users to the **built-in Studio MCP server** (about 25 tools, toggled in Assistant settings) | Repo notice and Roblox docs, see [[Roblox Studio MCP Server]] |
| April 2026 | "Studio Assistant & MCP Playtest Agent" beta | DevForum, cited in [[Roblox Studio Assistant]] |
| October 2026 | Built-in MCP tool set includes generation tools (`generate_mesh`, `generate_material`, `generate_procedural_model`; `generate_texture` and `segment_mesh` seen but undocumented) | [[Roblox Studio MCP Server]] (Roblox docs plus Measured) |

---

## 2. Using it to spot stale advice

| Advice says | Written before | Today |
|---|---|---|
| "Install the Rust MCP server and its plugin" | April 2026 | Use the built-in server; migrate configs ([[Built-In Studio MCP vs Community MCP Servers - Migration Guide]]) |
| "Assistant only writes snippets" | September 2025 | Assistant plans and runs multi-step tasks and can drive playtests |
| "Assistant can only use Roblox's model" | February 2026 | External API keys supported |
| "There is no way to automate playtests from a plugin" | December 2025 | StudioTestService |
| "AI can't make meshes in Studio" | March 2025 | Cube mesh generation and MCP `generate_mesh` |
| "Use `run_code` / `get_studio_mode`" | 2026 built-in server | `execute_luau` / `get_studio_state` |

Rule for agents: when advice names a Roblox AI tool, check its date against this table and the linked note before acting. LihFolk's `lihfolk-lookup` agent and `vault.py` will return the dated notes; prefer them to model memory for anything after the model's training cutoff.

---

## 3. What has stayed constant

Some things did not change across all these releases (**Rule of thumb** from the linked notes):

- Generated code still needs review against current APIs ([[AI Pitfalls - Stale APIs and Luau]]).
- Generated assets still need inspection, import checks and scoring ([[AI Pitfalls - Assets and Import]]; LihFolk `quality-score` rubrics, minimum 8.5).
- Policy duties (disclosure, rights, moderation) apply whatever made the content ([[Roblox Policies on AI-Generated Content]]).

---

## 4. Keeping this note current

- Add a row when Roblox announces a tool on the DevForum Announcements category or the newsroom. Use the post date, and link the post.
- Mark betas as beta; note when they reach full release.
- If a date is from press coverage rather than Roblox, say so.
- Do not backfill dates from memory: if you cannot find a primary source, write **Unverified**.

---

## Common mistakes

- Following an AI tutorial without checking when it was written.
- Assuming a model knows about tools released after its training data.
- Treating betas as stable.
- Mixing community tools with official releases in the history.

## Checklist

- [ ] Advice dated before acting on it.
- [ ] Tool names checked against the current MCP tool list.
- [ ] New announcements added with links and dates.
- [ ] Betas flagged until full release.

## See also

- [[AI in Roblox Development Overview]], [[Roblox Studio Assistant]], [[Roblox Studio MCP Server]]
- [[Roblox Generative AI - Cube Mesh and Texture Generation]], [[AI Material and Texture Generation]]
- [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]]

## Connected notes

[[What AI Models Get Wrong in Roblox]] · [[AI Pitfalls - Stale APIs and Luau]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[Roblox Changes 2025-2026]]

<!-- related:start -->
## Related
[[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]] · [[AI Agents and Autonomous Workflows]] · [[AI Code Assistants for Luau]] · [[Evaluating AI Tools - A Practical Rubric]] · [[Who Owns AI-Generated Code and Assets]] · [[Token Cost Benchmarks]] · [[AI Image Generation for Icons Thumbnails and Concepts]]
<!-- related:end -->
