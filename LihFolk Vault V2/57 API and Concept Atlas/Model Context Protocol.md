---
tags: [atlas, concept, type/atlas, area/ai, area/pipelines]
---
# Model Context Protocol

<!-- tldr:start -->
> [!tldr] TL;DR
> - MCP is the right pipe for decisions and small results (the agent asks, Studio answers in a few lines).
> - Studio updated; MCP enabled; green indicator shows the client.
> - Tool names checked against the current MCP tool list.
>
> Cost: TL;DR ~100 tok · whole note ~840 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

MCP is the right pipe for decisions and small results (the agent asks, Studio answers in a few lines). (from [[Studio Plugins and Local HTTP Bridges]])

MCP is versioned by date (2024-11-05, 2025-03-26, 2025-06-18, 2025-11-25, 2026-07-28 at the time of writing). (from [[What Is MCP]])

## Key facts

- Studio updated; MCP enabled; green indicator shows the client. ([[Roblox Studio MCP Server]])
- Tool names checked against the current MCP tool list. ([[Roblox Built-In AI Tools Timeline 2023-2026]])
- Spec: the MCP specification at modelcontextprotocol.io (revisions 2025-06-18 and 2026-07-28 were read for this note). ([[What Is MCP]])
- `command` + `args` start a stdio server: the host launches this process and talks to it over stdin and stdout (What Is MCP). ([[Setting Up MCP Clients]])

## Mentioned in

53 notes in 12 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Studio Assistant and AI Tools]]

### 12 Performance Testing and Debugging
[[UI Automation with VirtualInput and StudioTestService]]

### 15 AI Tools
[[AI Agents and Autonomous Workflows]] · [[AI Code Assistants for Luau]] · [[AI in Roblox Development Overview]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Roblox Studio Assistant]]

### 16 MCP and Agents
[[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Agent Review Loops and Guardrails in Practice]] · [[Blender MCP]] · [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · [[Case Study - Building a Game with AI Agents]] · [[MCP Workflows for Building Worlds]] · [[MCP Workflows for Scripting and Debugging]] · [[Multiple Agents in One Studio]] · [[Roblox Studio MCP Server]] · [[Safety Rules for AI Agents in Studio]] · [[Setting Up MCP Clients]] · [[Studio Plugins and Local HTTP Bridges]] · [[What Is MCP]] · [[Writing Your Own MCP Server]]

### 17 Pipelines
[[Blender Automation with Python]] · [[Pipeline Design Principles]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): 000 Home · AI 3D Model Generation Outside Roblox · AI Material and Texture Generation · AI Pitfalls - Stale APIs and Luau · Agent Handoff Notes - Project State and Resume Templates · Asset Upload Automation with Open Cloud · Batch Processing Tools in Studio · Blender 5 Python Gotchas for Headless Builds · Blender Workflow for Roblox Creators · Code Pipeline - Rojo Git and CI · Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts · Environment and Level Pipeline · Evaluating AI Tools - A Practical Rubric · Glossary · Icon and Thumbnail Rendering Pipeline · Moving Data Out of a Play Session · Open Questions - Whole Vault · Plugin Development Start Here · Plugin Security and Permissions · Roblox Generative AI - Cube Mesh and Texture Generation · Roblox Policies on AI-Generated Content · Skill - Roblox Asset Import · Skill - Roblox Debugging · Studio Automation Without Freezing Studio · Testing Time-Based Features with a Controllable Clock · Third-Party Skill - Caveman Token Saver · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos · Windows Tooling Pitfalls for Agent Pipelines

<!-- atlas:generated -->
