---
tags: [studio, assistant, ai, mcp, code-assist, generation, workflow, type/guide, area/studio, level/intermediate, area/ai]
---
# Studio Assistant and AI Tools

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Letting an assistant "fix everything" in one go -> Planning Mode, small steps
> - Avoid: No snapshot before AI bulk edits -> Snapshot plus named save
> - Avoid: Accepting Code Assist output verbatim -> Review and lint
> - Team conventions skill written and enabled for everyone.
> - Planning Mode for multi-system work.
> - Snapshot and named save before AI-driven bulk changes.
>
> Cost: TL;DR ~140 tok · whole note ~3.5k tok. Read more: ## 2. Assistant · ## 5. The Studio MCP server · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Studio now ships several AI features: **Assistant** (a chat agent that reads and edits your place), **Code Assist** (inline code completion), the **Material Generator** and **Texture Generator**, mesh and procedural model generation, and a built-in **MCP server** that lets external AI coding tools drive Studio. These tools are fast at the boring 80% and confidently wrong in the interesting 20%. Every action they take is a real edit to your data model, which in a shared place reaches everyone. This note documents what each tool does and its limits as of October 2026 (all of this changes quickly; re-check the docs), then the guardrails that keep AI-driven edits as safe as human ones. For team process around AI assistants, see [[Working with AI Assistants in Studio]].

Labels: **Docs**, **Observed** (seen in practice with these tools, not documented), **Rule of thumb**.

---

## 1. The tools at a glance

| Tool | Where | Does |
|---|---|---|
| **Assistant** | Mezzanine, right side | Chat agent: answers questions, creates and edits instances and scripts, searches and inserts store assets, generates meshes, materials, textures and procedural models, plans multi-step work |
| **Code Assist** | Script Editor and Command Bar | Inline suggestions; `Tab` accepts, `Alt \` requests one |
| **Material Generator** | **Window > 3D**, or **Generate** in the Material widget | Text to tiling MaterialVariant |
| **Texture Generator** | **Model** tab, **Texture**, with a mesh selected | Text or image to a mesh-specific texture |
| **Studio MCP server** | Assistant, ⋯, **Manage MCP Servers** | Lets external AI clients read and edit the open place |
| **External LLM keys** | Assistant, ⋯, **Manage API Keys** | Run Assistant on a third-party model with your key |

## 2. Assistant

Capabilities (Docs):
- Answers Roblox questions and explains selected code.
- Creates and modifies objects and scripts; for example asking for a remote-driven feature can produce the server script, the client script and the `RemoteEvent` together. Generated scripts go under the selected object, or where Assistant decides if nothing is selected.
- **Search and insert assets** from the Creator Store (free and paid) and your personal or group inventories, filtered by type, price, duration or verified creators; it shows options before placing anything. `/insert_asset` inserts by id.
- A **screen capture subagent** captures the viewport (Edit or Play) so Assistant can judge the scene.

Chats (Docs):
- Several chats per place, stored in the cloud and synced across devices; each chat has its own context window; branch a chat from any response.
- Chats are scoped to the **place**, not the game. Deleted chats cannot be recovered.

**Planning Mode** (Docs): choose **Plan** in the input dropdown or type `/plan`. Assistant writes an editable Markdown plan stored in the cloud (private to you, tied to the game and your profile), and nothing executes until you click **Build**. Use it for anything that touches more than one system: review the plan the way you would review a colleague's design.

**Skills** (Docs): Markdown documents with `name`, `description`, `enabled` front matter and instructions; Assistant loads one automatically when a request matches its description, or you invoke it manually. Skills belong to your account and apply in every place you open. Roblox-authored skills use the reserved `rbx-` prefix, including `rbx-debug` (breakpoints, call stacks), `rbx-device-simulator-lua`, `rbx-docs-search`, `rbx-perf-profiling` (MicroProfiler traces), `rbx-scene-analysis` (SceneAnalysisService audits: rendering cost, memory, unparented instances), `rbx-unit-test` (Jest-Lua or TestEZ) and `rbx-create-skill`.

A team skill is the best place to put your conventions, so the assistant writes code that looks like yours:

```markdown
---
name: team-luau-conventions
description: Apply our Luau conventions whenever writing or editing scripts in this project.
enabled: true
---

Start every script with --!strict.
Server validates every RemoteEvent argument: type, range, rate. Never trust client values for currency or damage.
Use task.* (never wait, spawn, delay). Use attributes for per-instance data.
Modules return a table; no _G. Connections are stored and disconnected on cleanup.
Never edit scripts over 150,000 characters; add a child module instead.
Find instances by path or CollectionService tag, never by the current selection.
```

### Generation commands (Docs)

| Command | Notes |
|---|---|
| `/generate_mesh <prompt>` | Text or reference image (not both). Select a Part first to use it as a bounding box. Optional max triangle count, default 10,000 |
| `/generate_procedural_model <prompt>` | Parametric models built from primitives, adjustable later, kept in a `GeneratedFolder`; limit **50 per rolling 24 hours** |
| Segmentation | Text-prompted generations can be split into up to **8 named parts**; previews first, then **Add to place** |
| `/segment_mesh` | Split an imported MeshPart into up to 5 named parts per run (early preview; topology dependent) |
| `/generate_texture` | Texture Generator through Assistant |
| `/plan` | Planning Mode |

## 3. Code Assist

Suggests lines or functions as you type, automatically after a pause or on `Alt \`; `Tab` accepts (Docs). Limitations the docs list: suggestions may use older APIs or plain Lua instead of Luau, may be wrong or incomplete, manual triggering does not always produce one, and there is a **daily cap** on suggestions. Privacy (Docs): Roblox does not train on non-public data; your code is not suggested to others, except code you post in free marketplace items.

Get better suggestions by naming things descriptively, writing a comment describing the inputs and outputs, and keeping functions small (Docs). Watch for: `wait()` instead of `task.wait()`, `spawn`, deprecated `:connect`, client-side trust of values, and missing `--!strict` types (see [[Luau Language Essentials]]).

## 4. Material and Texture Generators

**Material Generator** (Docs): type keywords, **Generate**, preview on selected parts, adjust **Studs Per Tile** and the **Organic** toggle (less visible repetition), choose a **Base Material** for physical properties, **Save & Apply Variant** into the Material Manager. Prompt tips from the docs: "close up", "top down", "texture" for patterns; "simple", "symmetrical", "flat" for clean repeats; "photorealistic", "cartoon", "hand-drawn" for style; "grayscale" when you want to tint later.

**Texture Generator** (Docs): select a mesh (or a model of meshes forming one body), **Model > Texture**, prompt with text or an image, **Preview** (three previews in about 10 s), then **Fast** (1K diffuse, under 30 s) or **Quality** (4K PBR, a couple of minutes). Choose **Manual** view to set the preview angle from your camera. Do not edit the asset while generation runs; it can fail. For tiling surfaces use the Material Generator instead.

Art direction still matters more than the generator. Generated textures drift in style between prompts; lock a style phrase and palette and reuse it (see [[Environment Art Styles]] and [[Materials MaterialVariants and SurfaceAppearance]]). Check texture memory: a 4K PBR set per prop is expensive on phones (see [[Textures Decals and Texture Memory]]).

## 5. The Studio MCP server

Studio includes an MCP server so external AI clients (the docs list quick connect for Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI and VS Code) can work on the open place (Docs). Enable it in Assistant, ⋯, **Manage MCP Servers**, **Enable Studio as MCP server**; a green indicator shows connected clients. It uses stdio transport; on Windows the config runs `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` (Docs).

Tools the server exposes (Docs), grouped:

| Group | Tools |
|---|---|
| Scripts | `script_read`, `multi_edit`, `script_search` (up to 10 results), `script_grep` (up to 50 matches) |
| Data model | `search_game_tree`, `inspect_instance`, `subagent` (explore, playtest) |
| Execution | `execute_luau` (Edit, Client or Server data model) |
| Playtesting | `get_studio_state`, `start_stop_play`, `get_console_output`, `screen_capture` |
| Input | `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| Assets | `generate_mesh`, `generate_material`, `generate_procedural_model`, `wait_job_finished`, `search_asset`, `insert_asset`, `upload_image`, `store_image` |
| Docs | `http_get` (allowed Roblox doc URLs), `skill` |
| Sessions | `list_roblox_studios` |

Every call names a `studio_id`; use `list_roblox_studios` to pick the right Studio when several are open (Docs). The docs warn that MCP clients can read and modify your open places, so connect only clients you trust.

Practical behaviour worth knowing (Observed, may change with updates):
- Studio instance ids change when Studio restarts; look them up again rather than caching them.
- Viewport captures can come back black when Studio is not the focused window, and may not draw `AlwaysOnTop` BillboardGuis.
- A capture from a custom camera position can leave the edit camera in `Scriptable` mode; restore `CameraType = Custom` afterwards (a short delay helped).
- `require` inside executed Luau returns the Edit-session cached module, not the running game's copy, and does not see recent module edits; use the clone-require pattern ([[Command Bar and Studio Scripting]]).
- While Studio is in a playtest, Edit data model calls fail; tools must wait for Edit mode.
- Large scripts are better loaded from files (HTTP loader) than pasted through tool calls.

## 6. Guardrails for AI-driven edits

AI tools edit the same data model you do, faster, and without the instinct to stop when something looks odd. Treat them like a new contractor with admin rights (Rule of thumb, and the same rules the reference project applied to every automated tool):

| Risk | Guardrail |
|---|---|
| Bulk edits you cannot reverse | Snapshot first (Pre-attributes, `.rbxm` export, TerrainRegion) and **Save to Roblox with Notes**. Never rely on undo in a shared place ([[Version History and Backups]]) |
| Acting on the wrong objects | Instruct tools to resolve targets by path or tag, never by the current selection |
| Long operations freezing Studio | Ask for chunked, resumable work with a time budget per call |
| Editing scripts unsafely | Size check (200,000 character Source limit), compile check, changed-underneath check, clone-require verify ([[Command Bar and Studio Scripting]]) |
| Inserting third-party assets | Same rules as the Toolbox: scratch place, read scripts, audit ([[Creator Store and Toolbox Safety]]); or forbid store inserts entirely |
| Invented asset ids or APIs | Require ids that exist in your inventory or project files; verify APIs against the reference (`rbx-docs-search` or the docs) |
| Starting playtests in a shared session | Decide who may start Play; tools that start tests interrupt everyone's Edit session |
| Previews left on | Every preview has an explicit off step |
| Generated code quality | Code review, CI lint and type check ([[Git and Source Control for Roblox]]) |
| Style drift in generated art | A written style guide and fixed prompt phrases; human art review |

And the soft rule: **verify by data, not by the assistant's summary.** After any AI-driven change, check counts, run the audit, read the diff, and play-test what matters. A confident "done" is not a test.

## 7. Where AI tools pay off

| Good fit | Poor fit |
|---|---|
| Boilerplate: remotes, UI scaffolding, data tables | Core architecture decisions |
| Explaining unfamiliar code | Security-critical validation without review |
| Bulk renames and property passes with snapshots | Unreviewed edits in a live shared place |
| Greybox meshes and placeholder materials | Final hero art in a defined style |
| Documentation lookups and API reminders | Exact limits, prices and policies (always check the docs) |
| Profiling interpretation with real traces | Guessing at performance without a trace |

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Letting an assistant "fix everything" in one go | Large unreviewable change | Planning Mode, small steps |
| No snapshot before AI bulk edits | No clean revert | Snapshot plus named save |
| Accepting Code Assist output verbatim | Old APIs, client trust bugs | Review and lint |
| Using generated 4K textures everywhere | Mobile memory blowouts | Fast mode or budgets |
| Connecting unknown MCP clients | Untrusted code edits your place | Trusted clients only |
| Treating chat history as documentation | Lost when deleted, private | Write decisions into team docs |

## 9. Checklist

- [ ] Team conventions skill written and enabled for everyone.
- [ ] Planning Mode for multi-system work.
- [ ] Snapshot and named save before AI-driven bulk changes.
- [ ] Rules for AI tools: no Selection-based targeting, budgets, edit-only, no third-party inserts without audit.
- [ ] Generated assets reviewed for style, triangles and texture memory.
- [ ] Code from any AI tool goes through review and CI.

## See also

- [[Working with AI Assistants in Studio]], [[Safe Changes in a Shared Place]], [[Team Roles and Workflows]]
- [[Command Bar and Studio Scripting]], [[Plugins - Using and Writing]], [[Creator Store and Toolbox Safety]]
- [[Materials MaterialVariants and SurfaceAppearance]], [[Asset Pipelines]], [[MicroProfiler Guide]]

## Connected notes
<!-- auto-links:start -->
[[Roblox Studio Assistant]] · Roblox Studio MCP Server · AI Material and Texture Generation · AI in Roblox Development Overview · AI Code Assistants for Luau · Setting Up MCP Clients
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Roblox Studio MCP Server]] · [[AI in Roblox Development Overview]] · [[Studio Interface Tour]] · [[Team Create and Collaboration]] · [[Packages and Asset Reuse]] · [[Studio Settings and Shortcuts]] · [[Explorer Properties and Selection]]
<!-- related:end -->
