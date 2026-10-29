---
tags: [index, unresolved, research, type/guide, level/intermediate, api/DataStore, api/SurfaceAppearance, api/Terrain]
---
# Open Questions - Whole Vault

Conflicts the writers found between Roblox's own documentation pages, between the docs and measured behaviour, and inside the reference project's history. Nothing here was silently resolved: each entry says what disagrees and which note discusses it. Checked October 2026. Animation-engine questions (easing shapes, rotation interpolation, scale, markers) have their own detailed note: [[Open Questions]].

## 1. Roblox platform changes worth knowing (not conflicts, but easy to miss)
| Change | Where |
|---|---|
| `Lighting.Technology` deprecated in favour of `LightingStyle` (Realistic / Soft) + `PrioritizeLightingQuality` | [[Lighting Technologies and Settings]] |
| Classic `Sound` / `SoundGroup` / `SoundEffect` discouraged in favour of the Audio API | [[The Audio API - Players Emitters Wires and Effects]] |
| Highlights: limit raised from 31 to 255; disabled Highlights still take a slot | [[Highlights and Selection Effects]] |
| Gotham fonts removed; they now render as Montserrat | [[Text Fonts and Rich Text]] |
| `IgnoreGuiInset = true` now means "device safe", not fullscreen | [[Safe Areas and Insets]] |
| Raycast / overlap filters: `ExcludeInstances` / `IncludeInstances` supersede `FilterDescendantsInstances` / `FilterType` (old names still appear in some notes' code and still work) | [[Raycasts Shapecasts and Spatial Queries]] |
| Collision-group methods moved to `WorldRoot` (`workspace`), 32 per world | [[Collision and Physics Geometry]] |
| `LoadCharacterAsync`, `ApplyDescriptionAsync`, `GetProductInfoAsync`, `ReserveServerAsync`, `CreateDockWidgetPluginGuiAsync` replace their non-Async forms (`ReserveServerAsync` is itself deprecated since October 2026: use `TeleportOptions.ReservedServerId` with a GUID, **Roblox docs**) | [[Characters and Humanoids]], [[Plugins - Using and Writing]] |
| Server Authority mode (`Workspace.AuthorityMode`, `RunService:BindToSimulation`, client prediction) documented; docs call it beta in places | [[Client-Server Model]], [[Custom Character Controllers]] |
| `KeyframeSequenceProvider` deprecated for `AnimationClipProvider` | [[Animator Deep Dive]] |
| New Type Solver general release (Nov 2025); strict users opt in via `Workspace.UseNewLuauTypeSolver` | [[Luau Type System and Strict Mode]] |
| Premium Payouts replaced by [[Creator Rewards]] (July 2025); Roblox Plus launched April 2026, Premium closed to new sign-ups, `PromptPremiumPurchase` deprecated | [[Subscriptions and Premium Payouts]] |
| Cross-game pass and product sales ended May 30, 2026 | [[Game Passes]] |
| Maturity tiers now Kids 5-8, Select 9-15, 16+, Content May Vary, Restricted 18+ | [[Roblox Policies Ratings and Compliance]] |
| External social links in experiences banned (January 2026); player text must go through `TextChatService` | [[Age Checks and Safety Features]] |
| Roblox Studio MCP server is now built into Studio; the old open-source server repo was archived April 2026 | [[Roblox Studio MCP Server]] |
| `GenerationService:GenerateMeshAsync` deprecated for `GenerateModelAsync` | [[Roblox Generative AI - Cube Mesh and Texture Generation]] |
| Knit archived (July 2024) | [[Frameworks - Knit Matter and Others]] |

## 2. Docs that contradict other docs
| Topic | Claim A | Claim B | Discussed in |
|---|---|---|---|
| Texture size | "up to 4096x4096" | "up to 1024x1024 pixel spaces for texture maps"; accessories capped at 2048; a performance page says keep images at 512 or below | [[Textures Decals and Texture Memory]], [[Texturing and PBR Baking]] |
| [[ShadowSoftness]] | default 0.2, works with ShadowMap/Future | API dump default 0.5; guide says only with LightingStyle Realistic | [[Light Sources and Shadows]] |
| Highlight.FillTransparency default | 0 (guide) | 0.5 (API dump) | [[Highlights and Selection Effects]] |
| Flipbook texture | must be 1024x1024 (error message) | an exact multiple of the layout (reference) | [[Particle Emitters In Depth]] |
| MicroProfiler shortcut | Ctrl+F6 | Ctrl+Alt+F6 | [[MicroProfiler Guide]] |
| Stats overlays | Shift+Ctrl+F1 to F5 | Shift+F2 / F3 / F5 | [[Developer Console and Stats]] |
| Console tabs | Log, Memory, Luau heap, Network, Script Profiler | also Server Jobs, Server Stats | [[Developer Console and Stats]] |
| Memory category names | console: PhysicsParts, TerrainPhysics | `DeveloperMemoryTag`: BaseParts, GeometryCSG, GraphicsSlimModels, Internal | [[Memory Budgets and Leaks]] |
| Server memory guidance | 6.25 GiB + 100 MiB per player, under 50% | "stay under about 3 GB" | [[Memory Budgets and Leaks]] |
| `Model.LevelOfDetail` | `Automatic` currently behaves like `Disabled` | projects still pin `Disabled` in case the default changes | [[Level of Detail and Model Streaming]] |
| Cyclic require | hangs with no error (reference) | errors "Requested module was required recursively" (guide) | [[Module Scripts and Requiring]] |
| `Humanoid.MoveDirection`, `ControllerBase.Active` | read-only (description) | ReadWrite (API listing) | [[Characters and Humanoids]] |
| [[ApplyImpulse]] on player characters | client or server may call it | in practice a server impulse arrives late or is overwritten | [[Mover Constraints and Physics Controllers]] |
| DataStore experience limits | 300 + CCU x 40 / 20 (limits page) | 250 + CCU x 40 / 20; List 10 + CCU x 2 (Extended Services). Resolved: these are pre-2026-07-29 figures; 300 is current | [[DataStore Fundamentals]], [[Data and Cloud Changes 2025-2026]] |
| DataStore storage | 500 MB + 1 MB per lifetime user | 100 MB + 1 MB. Resolved: 100 MB was the pre-2026-07-29 baseline | [[DataStore Fundamentals]], [[Data and Cloud Changes 2025-2026]] |
| Open Cloud calls from HttpService | don't count toward 500/min | do count | [[HttpService and External APIs]], [[Open Cloud APIs]] |
| Live config publish speed | ~15 s to 1 min (or 15 min rollout) | "over five minutes" | [[Global State and Live Config]] |
| DataStore metadata table | "Key-value pairs: 300" | the text says a 300-character total; a RemoveVersionAsync row describes RemoveAsync | [[DataStore Fundamentals]] |
| Team Create auto-save | live scripting "every 5 minutes" | session "every four minutes" (same page) | [[Team Create and Collaboration]] |
| Place file name | `.rblx` (typo on publish page) | `.rbxl` | [[Publishing an Experience]] |
| Plugins guide | shows `CreateDockWidgetPluginGui`, `SetWaypoint` | reference marks them deprecated / "deprecated soon" | [[Plugins - Using and Writing]] |
| Kids / Select review | expedited fee 50,000 Robux; threshold 250 engaged age-checked plays in 60 days; refund after 25 engaged players for 60 days | DevForum: 100,000 Robux; 500 Highly Engaged Players; refund 90 days after eligibility | [[Publishing an Experience]], [[Roblox Policies Ratings and Compliance]] |
| Rewarded video method | `ShowRewardedVideoAsync` | `ShowRewardedVideoAdAsync` (reference) | [[Ads and Rewarded Video]] |
| Social link visibility | age-checked 13+ (Feb 2026) | 16+ (June 2026) | [[Age Checks and Safety Features]] |
| UGC upload fee | 200 Robux (July 2026 post) | 80 Robux, 500 with emissive (fees page, later update) | [[UGC Avatar Items and Accessories]] |
| Limited publishing | 1 per day (cached docs) | 50 free per day, paid unlimited (current page) | [[UGC Avatar Items and Accessories]] |
| SurfaceAppearance at runtime | not script-modifiable (PBR guide) | only the map properties are Plugin Security; `Color` was set at runtime successfully | [[Materials MaterialVariants and SurfaceAppearance]] |
| `TextGenerator` rate | 100 per minute | 100 per second (guide, reported) | [[In-Game AI - LLM NPCs and Text Generation]] |
| `TextGenerator` JsonSchema | missing from the parameter table | present in the request table | [[In-Game AI - LLM NPCs and Text Generation]] |
| Filtering AI text | through `TextChatService` | through `TextService:FilterStringAsync` | [[Roblox Policies on AI-Generated Content]] |
| Texture Generator quota | 1024 px, 5 per day (beta) | Fast 1K / Quality 4K, no stated quota | [[AI Material and Texture Generation]] |
| Luau Execution rate | 5 per minute per key owner | 40 per minute (one page) | [[Asset Upload Automation with Open Cloud]] |
| Assets API file size | 20 MB | 3.75 GB for video | [[Asset Upload Automation with Open Cloud]] |
| Thumbnails | "10 maximum" (search summary) | 2 to 5 active for personalization (official) | [[Thumbnails Icons and Store Page]] |
| StreamingIntegrityMode | docs list PauseOutsideLoadedArea | projects also use MinimumRadiusPause (undocumented semantics) | [[Instance Streaming]] |
| Place publishing API | does not update PartOperation, SurfaceAppearance, EditableMesh/Image, BaseWrap | (a gap, not a conflict: plan for it) | [[Build Test and Release Pipeline]] |
| Blender export for Roblox | units "None", FBX Unit Scale, avatar FBX faces +Z | many guides use Metric 1 m = 1 stud, Scale 0.01; GLB route front at Blender -Y | [[Blender Workflow for Roblox Creators]], [[Exporting and Validating Models for Roblox]] |

## 3. Docs vs the reference project
| Topic | Docs | Project | Discussed in |
|---|---|---|---|
| Streaming | MinRadius 64, PauseOutsideLoadedArea | MinRadius 256, MinimumRadiusPause | [[Instance Streaming]] |
| NaN checks | `math.isfinite` | `x ~= x` | [[Server Authority and Validation]] |
| Text floor | `MinTextSize` not below 9 | 12 px drawn text, 44 px taps on phones | [[Responsive UI for Phone Tablet Console and PC]] |
| DataStore write rate | per-key throughput (4 MB/min write, 25 MB/min read) | an older "one write per key per ~6 s" rule | [[DataStore Fundamentals]] |
| Load failure | sample plays on default data that never saves | kick the player | [[Session Locking and Profile Libraries]] |
| Script Source size | not documented | 200,000-character cap measured | [[Command Bar and Studio Scripting]] |
| HttpService budget | 500/min on game servers | also hit in Studio tooling | [[Studio Plugins and Local HTTP Bridges]] |

## 4. Inside the reference project (history, not errors)
- Tutorial first roll: a guaranteed Rare, later a plain "1 in 3" Common. [[First-Time User Experience and Onboarding]]
- Zone gate prices: planned 2.6x per zone, shipped x3 in region 1 and x2.2 in region 2; power base 1.17 replaced by 1.16 after a blow-up at stage 50; elite health 2.5x planned, 12x / 1.5x later. [[Progression and Pacing Design]], [[Balancing with Spreadsheets and Data]]
- Enemy triangle budgets: planned 3-6k (bosses 10-15k), shipped 10-42k. [[Art Budgets - Triangles Draw Calls Memory]], [[Case Study - Enemy Roster Rebuild]]
- Enemy scale 1.61 vs 1.6 / 2.1 (different bases); aggro range 28, 42, 36, then 72 with a notice multiplier. [[NPC AI and Behaviour]]
- Swing hit times: 0.20 / 0.20 / 0.217 / 0.367, later 0.20 / 0.20 / 0.23 / 0.30. Guard and parry designed, then switched off. [[Combat Systems Architecture]]
- Terrain rendered surface: about 2 studs above voxel tops in one note, 0.8 to 1.6 in another. [[Terrain Tools and Terrain API]]
- Materials: one note says legacy materials, another that 2022 textures show. [[Materials MaterialVariants and SurfaceAppearance]]
- Studio-call budget for tools: 5 s, then 3.5 s, then 1.5 s. [[Safety Rules for AI Agents in Studio]]
- Deletion policy changed twice (never delete, delete after proof, no backups in the place). [[Safe Changes in a Shared Place]]
- UI scale floor: how low a phone scale can go before text drops under 12 px drawn (the reference project landed near 0.82), and whether decorative loops such as sunbursts should run per frame or as idle-free tweens. [[UI Design Systems]]

## 5. Compliance risks spotted in the reference project
Kept here as general warnings because they are common in RNG games:
- **Paid luck boosts are probability modifiers** under Roblox's paid random items policy: odds must be shown as percentages that sum to 100% and update while a boost is active, with an info button. [[Genre Playbook - RNG and Collection Games]], [[Ethical Design and Player Trust]]
- **Receipts in a separate store** can lose a purchase if a server dies between the two writes; keep the receipt marker in the same document as the grant. [[Developer Products and ProcessReceipt]]
- **Refusing a purchase inside the receipt path** (e.g. an off-rotation item) takes money without granting. Validate before prompting. [[Pricing and Store Design]]
- **Hard-coded prices** drift from managed pricing and Plus discounts; read prices live. **Descriptions that disagree with code** ("1.5x" shown, 2x granted) erode trust. [[Pricing and Store Design]]
- **No server-side roll cooldown**: rate-limit anyway. [[Rate Limiting and Abuse Prevention]]

## Not verified anywhere
Assistant daily caps; `ShowAdResult` values; whether unprocessed receipts auto-refund; MessagingService in Studio; tangent space (MikkTSpace) and UV wrapping in Roblox; the 2,048-stud part size limit; top bar height (58 px reported); Open Cloud localization API; Assets API rate limits. Each is marked "unverified" where it appears.

See also: [[00 Start Here]], [[Glossary]], [[Open Questions]].

## Round 2 additions (October 2026)

### Platform changes found
- **Server authority mode** (`Workspace.AuthorityMode = Server`): announced as fully released and opt-in on the DevForum ("[Full Release] Ship Fair And Competitive Games with Server Authority", 9 July 2026). Older notes ([[Client-Server Model]], [[Server Authority and Validation]]) and some security doc pages still call it beta. Known limits: 8 playing tracks per Animator, 64 attributes per instance, attribute names and string values up to 50 characters, more server load.
- **Ban API details:** `BanAsync` calls run in Studio but do not ban in production; `GetBanHistoryAsync` fails in Studio; `ApplyDeviceBlock` lasts 24 hours; up to 50 UserIds per call; DisplayReason up to 400 characters, PrivateReason up to 1,000; Open Cloud user-restriction updates limited to 2 per minute per user. See [[Logging Bans and Appeals]].
- **Open Cloud Luau Execution:** stable; 5-minute default timeout, at most 10 unfinished tasks per place, 4 MB scripts and return values, about 450 KB of logs, no physics, game scripts do not run, DataStore calls are real. Rate limits: 5 task creations, 200 task reads and 45 log reads per minute, per API key owner. [[Testing Strategies and Frameworks]] gives "45 per minute per IP", which looks like the logs limit.
- **Expanded Terrain:** up to 62 custom materials; the Shorelines upgrade cannot be reverted after saving. See [[Terrain Deep Dive - Materials Water and Performance]].

### Doc-vs-doc and note-vs-note
- Texture size: one docs page says textures up to 4096 x 4096, another says maps up to 1024 x 1024. Notes recommend 1024 or less.
- Backpack replication: [[Client-Server Model]] says owner-only; a DevForum comment says other clients see it. Unconfirmed.
- The Developer Console Network tab shows web calls (HttpService, DataStore), not remote traffic.
- [[Data Schema Design and Migrations]] advises refusing newer schemas; that turns a release rollback into mass load failures. [[Schema Migrations - Worked Case Studies]] adds a `MinReader` field and an expand-and-contract pattern.
- "Device Emulator" and "Device Simulator" both appear for the same Studio feature.
- The reference project's zone price formula (2500 x 2.6^(zone - 2)) does not match its own listed prices above zone 20. [[Rarity Ladders and Drop Pacing Math]] uses the formula values.

### Not verified (marked in the notes)
- Pathfinding: `Humanoid:MoveTo` 8-second timeout; when `ComputeAsync` returns ClosestNoPath; navmesh rebuild delay after geometry changes.
- Monetization: refund webhook field names, and whether its transaction id equals the ProcessReceipt PurchaseId; whether refunds revoke private-server access or claw back earnings; whether a cash-priced egg counts as a paid random item when a Robux pass multiplies cash.
- Engine: whether off-screen ParticleEmitters keep simulating; AudioCompressor units; what the TonemapperPreset items do; the Studio Script Timeout default; whether any event fires when network ownership changes; the client interpolation buffer; the Studio incoming-replication-lag setting name; no API found for replicating Workspace objects to chosen players only.
- UI: the `SetCore("SendNotification")` field list; `TweenService:SmoothDamp` behaviour; whether `TextChannel:DisplaySystemMessage` supports rich text.
- Security: Roblox's client anti-tamper is not described in the Creator docs; alt-account detection is undocumented.
- Benchmarks in [[Luau Performance Patterns with Benchmarks]] give expected directions and a harness, not measured numbers.
- The "50 KB/s per client" bandwidth figure is community folklore with no official source.

## Round 3 additions (October 2026)

### Platform changes found
- **Platform-integrated chat** (`TextChatService.PlatformIntegratedChat`, announced October 2026): opt-in now, on by default from February 2027, required from May 2027 (one table in the announcement says opting out ends "before March 2027", which conflicts). When it is on, `TextChatMessage.Text` and `.Translation` return empty strings, `PrefixText` is unsupported, and `OnIncomingMessage` / `Player.Chatted` no longer give text, so chat commands must use `TextChatCommand`. This affects the chat-tag patterns in [[Age Checks and Safety Features]] and [[Community Building]]. See [[Text Chat Customization with TextChatService]].
- **DevEx:** 0.0038 USD per Earned Robux (balances from before 5 September 2025 cash out first at 0.0035); a 0.0054 rate from 8 June 2026 for qualifying purchases by age-verified U.S. adults. See [[DevEx and Cashing Out]].
- **Creator Store selling:** models and plugins only, in USD; plugins 4.99 to 249.99, models 2.99 to 49.99; 30-day escrow; group-owned assets cannot be sold.
- **Cross-game pass sales** are disabled from 30 May 2026 (Roblox docs). Not yet reflected in older monetization notes.
- **Creator Affiliate program** was deprecated in July 2025 and replaced by Creator Rewards; older guides still describe it.
- **Experiments:** Configs and Experiments run 14 to 60 days with up to two variants plus control. See [[A-B Testing and Experiments on Roblox]].
- `MarketplaceService:PromptProductPurchase` is marked deprecated on its reference page with no replacement named, while the Developer Products guide still uses it.

### Doc gaps and disputes
- Constraint pages give no units or defaults (hinge angular velocity assumed radians per second); `RigidConstraint` destruction properties are hidden and undocumented; the `GeometryService.GenerateFragmentSites` page describes `Radius` like `Origin` (likely a docs error).
- Terrain water density 1 and wave behaviour come from DevForum testing only.
- DataStores accepting `buffer` values, `TextSource.Name` equalling the user id, group ranks with the new multi-role model, and whether `TextChatCommand.Triggered` fires on the server are unconfirmed.
- Refund webhook field names and whether its transaction id equals the receipt's PurchaseId are undocumented.
- Several Luau Cookbook limits (collision groups 32, DataStore 4 MB, per-key write cooldown) were written from existing notes, not re-fetched.

### Case studies
- The reference project's own sources disagree on counts (weapons and moves differ between sources) and on late zone prices versus its formula. The case studies use the dated figures and mark computed values "computed here".
- No retention or analytics data existed in the project notes, so the case studies make no retention claims.

## Round 4 additions (October 2026)

### Platform changes found
- **Async renames (2026):** many methods were deprecated in favour of `Async` versions: `ApplyDescription` / `ApplyDescriptionReset`, `GetHumanoidDescriptionFromUserId`, `CreateHumanoidModelFromDescription`, `LoadCharacterWithHumanoidDescription`, `LoadCharacter` (now `LoadCharacterAsync`), `PlayerOwnsAsset`, `GetProductInfo` (now `GetProductInfoAsync`), and [[AvatarEditorService]] getters such as `GetInventory`, `SearchCatalog` and `GetItemDetails`. Older notes and older code samples in this vault may still use the old names; they work for now but should be migrated. See [[HumanoidDescription and Outfit Systems]].
- `WrapLayer.Puffiness` and `ShrinkFactor` are deprecated.
- `TextService:FilterAndTranslateStringAsync` is marked deprecated; [[Localization]] still presents it as an option. Use `FilterStringAsync`.
- `Plugin:GetStudioUserId` is deprecated in favour of `StudioService:GetUserId`; [[Plugins - Using and Writing]] still lists the old call. The docs' own "Studio widgets" guide still shows the deprecated `CreateDockWidgetPluginGui`.
- Limiteds: turning on "Resellable" cannot be undone, disables restocking, and is unavailable to Japan-based accounts. Avatar Settings now include Single Collider collision, accessory effect toggles and a Character Controller Library option.
- Configs: publishing takes 15 seconds to 1 minute, "Publish over 15 min" is the only gradual option, up to 1,000 configs and 100 targeting conditions per game. No percentage rollout condition is documented, so [[Feature Flags and Staged Rollouts]] builds its own.
- Plugins: price 4.99 to 249.99 USD, 30-day escrow, distribution limited to 10 per 30 days for verified accounts (2 unverified).

### Doc gaps and disputes
- The chunk-seed formula in [[Procedural World Generation]] produces structured collisions; [[Seeds Determinism and Reproducible Worlds]] explains why and gives a hash-combine instead.
- Luau has no `__gc` finalizers and no ephemeron tables (luau.org), so a weak-keyed table whose value references its key never empties. This settles an open point from round 2.
- Unconfirmed: whether `math.noise` and seeded `Random` are bit-identical across platforms and engine updates; whether DataStores accept `buffer` values; how `JSONEncode` treats NaN, infinity and sparse tables; what `TweenService:SmoothDamp` does (signature only); whether `CFrame:Lerp` slerps; the platform body-scale ranges; AvatarEditorService rate limits; whether ProximityPrompt text is auto-captured for translation; the ProximityPrompt default activation distance; several ChangeHistoryService edge cases in Team Create.
- The Marketplace publishing page contradicts itself on whether a Limited's per-user copy limit can be changed after publishing.

## Round 5 (sections 41 to 44)

**Multiplayer Services**
- Does Roblox's automatic move during a server restart keep players in their reserved or private server?
- Can GetPartyAsync return a stale JobId for a member who is mid-teleport?
- Is there really no engine API to list an experience's public servers, its region, or players' join privacy settings?
- Does teleport data survive on the TeleportOptions that TeleportInitFailed passes back? The code sets it again to be safe.
- What are the exact field names on MemoryStoreHashMapPages items?

**Accessibility**
- Can InputBinding.KeyCode in the Input Action System be rebound at runtime? The notes use ContextActionService instead.
- What are AudioTextToSpeech's text length and rate limits, and is it still in beta?
- Which devices support HapticEffect? The docs say it supersedes HapticService.
- Is GuiService.ViewportDisplaySize read-only? The docs contradict themselves.
- The colour-blindness matrices (Machado 2009) and the Oklab constants were written from memory and need a spot check against the papers.

**Genre Systems**
- Which collision group calls are deprecated? Recheck RegisterCollisionGroup and CollisionGroupSetCollidable against the PhysicsService page.
- Player:LoadCharacter now shows as deprecated in favour of LoadCharacterAsync.
- Resolved 2026-10-29: Humanoid:MoveTo's 8-second timeout and the default WalkSpeed of 16 (from StarterPlayer.CharacterWalkSpeed) are both stated on the Humanoid reference page (**Roblox docs**).
- "Saved Inventory End to End": reconcile refills non-empty template arrays, and PlayerData has no BeforeRelease pre-save hook, so writes at leave time race the leave save.

**Materials and Surfaces**
- How are same-key MaterialVariants resolved during a theme swap, and does [[MaterialService]] replicate to clients?
- Do different SurfaceAppearance.Color tints stop meshes from instancing together?
- In what order do Decal UVScale and UVOffset combine with [[StudsPerTile]]?
- Lighting.Technology is deprecated in favour of LightingStyle and [[PrioritizeLightingQuality]]. Older lighting notes still treat Technology as current.
- Textures can be uploaded at up to 4096 px, but PBR guidance still says 1024; the CC0 library note says 1024.

## Section 45 (Procedural Blender Assets)

- The build scripts were run in Blender 5.2 only. Compositor, Glare and EEVEE engine names changed in Blender 5, so check them on other versions.
- None of the section 45 assets (the owl, chicken, swords, gate, VFX pack and trees) have been test-imported into Roblox Studio as a set. Import one and check the scale and skinning first.
- The chibi chicken is about 14k triangles before subdivision and needs decimating for game use.

## Rounds 6 to 8 (October 2026)
- Texture size limit: the Roblox specifications page mentions both 4096 and 1024. Notes that state a hard 1024 cap may be out of date. See [[Texel Density]].
- DataStore budgets are now 60 + 40 per player per minute for get and set; older notes may still say 60 + 10.
- UnreliableRemoteEvent payload limit: the docs now say 1000 bytes, older pages said 900. Design for 900.
- Do Open Cloud calls count toward the 500 HTTP requests per minute limit? Docs pages disagree.
- MemoryStoreSortedMap:GetRangeAsync maximum count and the exact UpdateAsync return value are not documented.
- IsPaidItemTradingAllowed appears on the paid random items page but not on the PolicyService reference page.
- Top games case studies: peak player counts from trackers (RoMonitor, Rolimons, RoWatcher) could not be read directly and sometimes disagree; developer product prices are not available without logging in.
- Not documented: whether math.sin and atan2 give identical results on every device, MessagingService ordering, and seeded Random stability across engine versions.

## Round 9 (sections 53 to 55, modelling)
- Vertex colours on MeshParts: the importer keeps them and community guides say they multiply with MeshPart.Color, but the MeshPart reference does not document this or whether they show under a SurfaceAppearance. Older notes call it measured.
- SurfaceAppearance.ResampleMode Pixelated: does it also stop mipmap blending at distance? MeshPart has no [[ResampleMode]].
- Do MeshPart and SurfaceAppearance textures repeat when UVs go past 0 to 1? Greedy-meshed voxel faces with tiling studs depend on it.
- Do custom or [[weighted normals]] survive automatic mesh LODs (RenderFidelity Automatic, bands under 250, 250 to 500 and over 500 studs)?
- Default camera zoom distances and the starting camera distance (about 12 to 13 studs) are set by the camera scripts and not documented on the StarterPlayer page.
- Voxel grain: older voxel notes use 0.3 and 0.4 stud grains; [[Voxel Scale Grids and Stud Alignment]] prefers binary 0.25 and 0.5 for anything tiled or scripted. Both are reasonable; pick one per project.
- [[MagicaVoxel]]'s 256 voxels per axis limit and its OBJ exporter behaviour come from community sources; [[Blockbench]] glTF unit mapping and Goxel face merging are unconfirmed.
