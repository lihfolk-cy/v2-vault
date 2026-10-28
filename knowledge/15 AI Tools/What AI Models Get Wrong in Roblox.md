---
tags: [ai-pitfalls, ai, code-review, luau, roblox, verification, lint, deprecated-apis, security]
verified: 2026-10-28
---
# What AI Models Get Wrong in Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: 1
> - Avoid: 2
> - Avoid: 3
> - Lint table run; every hit resolved or justified.
> - Each RemoteEvent handler validated against AI Pitfalls - Networking and Security.
> - Data and purchase code checked against AI Pitfalls - Data and Monetization.
>
> Cost: TL;DR ~100 tok · whole note ~2.0k tok. Read more: ## Why capable models fail here · ## A cheap lint pass for generated code · ## The ten most common mistakes · ## Checklist
<!-- tldr:end -->

Strong models write Luau that compiles, reads well and is wrong in ways specific to Roblox. This hub collects the failure patterns that show up even in good output, says why models produce them, and gives the correct pattern and a cheap way to detect each one. It assumes you already know Roblox; basics are skipped. Platform changes the model may not know about are in [[Roblox Changes 2025-2026]].

Labels: **Roblox docs** (Creator Hub or official announcement), **Reported** (DevForum community, press, third-party write-ups), **Measured** (observed in the LihFolk reference project), **Unverified**.

## Why capable models fail here

1. **Training lag.** Most Roblox code online predates 2024. Deprecated APIs (`wait`, `Humanoid:LoadAnimation`, body movers, `FindPartOnRay`) dominate the corpus, and 2026 changes (Async renames, Server Authority, the Input Action System, TextChatService lockdown) are absent. **Reported:** community guides list legacy `wait()` as a telltale of AI code (https://picoo.io/blog/lua-vs-luau-ai-codegen-differences).
2. **A single-machine mental model.** Code is written as if one program sees one world. Roblox runs a server and many clients with different views, ownership and timing.
3. **Studio success is not live success.** Play Solo hides latency, streaming, throttling, publishing and moderation. **Measured:** in the reference project, animations registered with `KeyframeSequenceProvider:RegisterKeyframeSequence` played in every Studio test and did nothing live, across dozens of weapon kits (see [[Testing Modes - Play Run and Multi-Client]]).
4. **Plausible names.** Models invent members that "should" exist, or use the right member on the wrong class.
5. **Contextual reasoning is the weak spot.** **Roblox docs** (OpenGameEval, December 17, 2025: https://about.roblox.com/newsroom/2025/12/opengameeval-benchmark-agentic-ai-assistants-roblox-studio): across 47 Studio tasks, leading models were near-perfect on atomic edits but scored very low on tasks needing context (finding existing damage scripts before adding regeneration, finding signals whose names do not say "traffic light", or an object not named "logo").
6. **Unit and convention mismatches** between tools (Blender metres vs studs, Y-up vs Z-up, glTF modifier defaults).

## The ten most common mistakes

| # | Wrong | Right | Child note |
|---|---|---|---|
| 1 | Server trusts values the client sends (price, damage, target position, item id it "owns") | Client sends intent; server recomputes and validates | [[AI Pitfalls - Networking and Security]] |
| 2 | Legacy and renamed APIs: `wait`, `spawn`, `Humanoid:LoadAnimation`, `BodyVelocity`, `FindPartOnRay`, `GetProductInfo` | `task.*`, `Animator`, mover constraints, `workspace:Raycast`, `...Async` names | [[AI Pitfalls - Stale APIs and Luau]] |
| 3 | `SetAsync` read-modify-write, no session lock, no retry budget | `UpdateAsync` or a session-locked profile; bounded retries | [[AI Pitfalls - Data and Monetization]] |
| 4 | Granting purchases in `PromptProductPurchaseFinished`, non-idempotent `ProcessReceipt` | Grant once per `PurchaseId` in `ProcessReceipt`, save, then return `PurchaseGranted` | [[AI Pitfalls - Data and Monetization]] |
| 5 | Assuming replication order and presence: property set before a remote arrives first; part exists on client under streaming | Send values with the remote; wait for or react to streamed instances | [[AI Pitfalls - Networking and Security]] |
| 6 | Motor6D edits through `C0` every frame, or wrong composition order | `Part1 = Part0 * C0 * Transform * C1:Inverse()`; procedural offsets via `Transform` after animation | [[AI Pitfalls - Physics and Animation]] |
| 7 | Animation priority and weight assumptions; top-level pose keys; Animator created on the client | Explicit priorities (Action2-4 exist), weights normalise, root motion on a child joint, server-created Animator | [[AI Pitfalls - Physics and Animation]] |
| 8 | UI in Offset or Scale without aspect constraints; `TextScaled` with no max; no safe-area handling; keyboard-only input | Scale plus `UIAspectRatioConstraint` and `UITextSizeConstraint`, `ScreenInsets`, Input Action bindings for all devices | [[AI Pitfalls - UI and Input]] |
| 9 | Asset scale and export defaults: FBX 100x, glTF modifiers dropped, vertex colours lost, decal id used as image id | Apply scale at export, `export_apply=True`, white `MeshPart.Color` with vertex colours, resolve image ids | [[AI Pitfalls - Assets and Import]] |
| 10 | Paid random items without numerical odds; hard-coded prices; Premium-based perks | Odds for every outcome before purchase; `GetProductInfoAsync`; Plus-aware perks | [[AI Pitfalls - Data and Monetization]] |

## A cheap lint pass for generated code

Run these over generated Luau before reading it in detail. Each hit is a question, not proof.

| Pattern (ripgrep) | Smell |
|---|---|
| `(^|[^.:\w])(wait|spawn|delay)\(` | Legacy scheduler |
| `Humanoid:LoadAnimation|humanoid:LoadAnimation` | Deprecated loader |
| `Body(Velocity|Position|Gyro|Force|AngularVelocity|Thrust)` | Legacy body movers |
| `FindPartOnRay|Ray\.new|Blacklist|Whitelist` | Legacy raycast |
| `:(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer)\(` | Pre-2026 names |
| `OnServerEvent:Connect\(function\(\w+,\s*\w*(price|cost|damage|amount|reward)` | Client-trusted numbers |
| `:SetAsync\(` near `:GetAsync\(` on the same key | Read-modify-write race |
| `PromptProductPurchaseFinished|PromptPurchaseFinished` in a granting path | Wrong grant hook |
| `SetPrimaryPartCFrame|\.Velocity\b|RotVelocity|:Remove\(\)` | Deprecated members |
| `tick\(\)` | Legacy clock; wrong under Server Authority |
| `InvokeClient` | Server can hang on a client |
| `game\.Chat|ChatService|SayMessageRequest|OnIncomingMessage` | Legacy or soon-unsupported chat |
| `Enum\.Font\.` | Legacy fonts |
| `RenderFidelity` | Ignored under mesh streaming |

## Verification habits that catch the rest

- Run a multi-client test (two players minimum) with network latency simulation before accepting networking code. See [[Testing Modes - Play Run and Multi-Client]].
- Check every API name against the reference when it is not in this vault. See [[Prompting and Verifying AI Output]].
- Prefer reading the place (scripts, existing services, tags) before writing code. OpenGameEval's failures are mostly "did not look first".
- For agent-driven Studio work, follow [[Safety Rules for AI Agents in Studio]]. **Measured:** a use-before-definition scan caught locals referenced above their declaration that compile and fail at runtime; scripts over 200,000 characters of `Source` fail to save.

## Common mistakes

- Reviewing generated code for style while missing the trust boundary.
- Accepting "it worked in Play Solo" as evidence.
- Fixing deprecated calls one by one without asking why the model chose them (the surrounding code is usually from the same era).
- Letting the model invent a limit. Take numbers from `_data/roblox_facts_2026.json` or the reference.

## Checklist

- [ ] Lint table run; every hit resolved or justified.
- [ ] Each RemoteEvent handler validated against [[AI Pitfalls - Networking and Security]].
- [ ] Data and purchase code checked against [[AI Pitfalls - Data and Monetization]].
- [ ] Tested with two clients, latency, and StreamingEnabled on.
- [ ] Asset imports checked for scale, colours and bevels.

## See also

- [[AI Pitfalls - Stale APIs and Luau]]
- [[AI Pitfalls - Networking and Security]]
- [[AI Pitfalls - Data and Monetization]]
- [[AI Pitfalls - Physics and Animation]]
- [[AI Pitfalls - UI and Input]]
- [[AI Pitfalls - Assets and Import]]
- [[Roblox Changes 2025-2026]]
- [[AI Code Assistants for Luau]]
- [[Prompting and Verifying AI Output]]
- [[Agent Review Loops and Guardrails in Practice]]
