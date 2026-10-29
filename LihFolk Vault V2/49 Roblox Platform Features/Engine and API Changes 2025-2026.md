---
tags: [delta, engine, api, deprecations, async-rename, mesh-streaming, textures, fonts, type-solver, ui-styling, character-controller, streaming, luau]
verified: 2026-10-28
---
# Engine and API Changes 2025-2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Writing `GetProductInfo`, `LoadCharacter` or `AwardBadge` in new code.
> - Avoid: Setting `RenderFidelity = Performance` as an optimisation.
> - Avoid: Assuming UI images can be 4K because 3D textures can.
> - `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer|Re...
> - No gameplay logic depends on `RenderFidelity`.
> - Text uses `FontFace`.
>
> Cost: TL;DR ~150 tok · whole note ~3.1k tok. Read more: ## 1. Yielding methods renamed with `Async` (January 14, 2026) · ## 8. Smaller changes worth knowing · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Engine and Studio API changes from January 2025 to October 2026 that matter when writing or reviewing code. Server Authority, replication and the Input Action System are big enough to have their own note: [[Server Authority and Input Migration 2026]]. Labels follow [[Roblox Changes 2025-2026]].

## 1. Yielding methods renamed with `Async` (January 14, 2026)

**Roblox docs** (DevForum PSA, January 14, 2026: https://devforum.roblox.com/t/psa-several-common-yielding-methods-have-been-renamed/4257585). 46 yielding methods gained an `Async` suffix. The old names are deprecated "informationally": same behaviour, not scheduled for removal. Script analysis flags them.

The ones generated code uses most:

| Old | New |
|---|---|
| `MarketplaceService:GetProductInfo` | `GetProductInfoAsync` |
| `MarketplaceService:PlayerOwnsAsset` / `PlayerOwnsBundle` | `PlayerOwnsAssetAsync` / `PlayerOwnsBundleAsync` |
| `BadgeService:AwardBadge` | `AwardBadgeAsync` |
| `Player:LoadCharacter` | `LoadCharacterAsync` |
| `Player:IsInGroup` / `GetRankInGroup` / `GetRoleInGroup` | `IsInGroupAsync`; for rank and role use `GroupService:GetRolesInGroupAsync` (`GetRankInGroupAsync` and `GetRoleInGroupAsync` are deprecated too; `IsInGroupAsync` is not) |
| `Player:IsFriendsWith` / `GetFriendsOnline` | `...Async` |
| `Humanoid:ApplyDescription` / `ApplyDescriptionReset` / `PlayEmote` | `...Async` |
| `Players:CreateHumanoidModelFromDescription` / `FromUserId` | `...Async` |
| `Players:GetHumanoidDescriptionFromUserId` / `FromOutfitId` | `...Async` |
| `TeleportService:ReserveServer` | `ReserveServerAsync`, itself deprecated on October 29, 2026: use `TeleportOptions.ReservedServerId` with a GUID ([[API Renames and Deprecations 2025-2026]]) |
| `Plugin:CreateDockWidgetPluginGui`, `ImportFbxRig`, `ImportFbxAnimation` | `...Async` |
| `StudioService:PromptImportFile(s)` | `...Async` |

**Not renamed:** `Instance:WaitForChild`, `BindableFunction:Invoke`, `RemoteFunction:InvokeServer` and `InvokeClient`.

**Reported:** a forum reply says the oldest mobile client versions lacked some `Async` names right after release. Irrelevant on the server; on the client, it only matters for players on stale builds.

```lua
-- before
local info = MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
-- after (same arguments, same return)
local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.Product)
```

`DataStoreService:GetRequestBudgetForRequestType` and `TextService:FilterStringAsync` were not on the list. The full map is in `_data/roblox_facts_2026.json`; later deprecations (teleports, subscriptions, chat, input) are collected in [[API Renames and Deprecations 2025-2026]].

## 2. Mesh streaming and cloud LoDs replace `RenderFidelity`

**Roblox docs** (DevForum, April 27, 2026: https://devforum.roblox.com/t/introducing-mesh-streaming-and-improved-cloud-lods-in-published-experiences-opt-in-phase/4601232).

- `Workspace.MeshStreamingAndImprovedLoDs` (`Default`, `Enabled`, `Disabled`). When `Enabled`, every mesh uses the cloud LoD transcoder and mesh streaming, and **`MeshPart.RenderFidelity` is ignored**.
- Phase 1 opt-in (April 2026). Phase 2 opt-out, `Default` maps to `Enabled`, planned for "about July 2026". Phase 3 removes the property and `RenderFidelity`.
- **Unverified:** whether Phase 2 shipped. No official confirmation found as of 2026-10-28. Check the property's effective value in Studio.
- Collision geometry is unaffected; only the rendered mesh streams.
- **Reported:** bug threads describe meshes stuck at the lowest LoD, and Studio showing a streamed LoD despite a close camera.

Migration: delete code that sets `RenderFidelity` for performance; budget triangles at the source (see [[Mesh Optimization for Mobile]]). Guard any remaining reads:

```lua
local ok, fidelity = pcall(function() return meshPart.RenderFidelity end)
-- ok is false once the property is removed; do not branch gameplay on it
```

## 3. 4K textures render in live games (January 30, 2026)

**Roblox docs** (DevForum, January 30, 2026: https://devforum.roblox.com/t/4k-texture-rendering/4316229).

- Up to **4096 x 4096** renders through texture streaming on MeshPart (skinned and not), SurfaceAppearance, Texture, Decal and MaterialVariant.
- Image uploads up to 8K are accepted and transcoded to 4K.
- Devices get lower mips when memory is short, so 4K is a ceiling, not a guarantee.
- GUI images were not covered by the post. **Reported** (bug threads, June 2026): the decal upload page still downsizes to 1024 x 1024. **Reported:** the clothing docs now say 2048 x 2048.

The old "1024 is the max" rule is out of date for 3D surfaces. Do not move UI art to 4K on that basis.

## 4. Fonts: `Enum.Font` is legacy, some families removed

**Roblox docs** (Font enum reference, https://create.roblox.com/docs/reference/engine/enums/Font, checked 2026-10-28): `Enum.Font` is legacy; use `FontFace` and the `Font` datatype. Gotham variants are listed as removed and map to Montserrat; Arial and ArialBold are removed and map to Arimo. New fonts exist only as asset IDs. **Unverified:** the exact removal dates.

```lua
label.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold)
-- or by asset: Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
```

A design that specifies "GothamBlack" renders as Montserrat Black. Pick fonts by what actually renders. See [[Text Fonts and Rich Text]].

## 5. Luau's new type solver is the default

**Roblox docs** (DevForum "[General Release] Luau's New Type Solver", https://devforum.roblox.com/t/general-release-luau%E2%80%99s-new-type-solver/4084991, late 2025; exact date **Unverified**).

- The new solver is the standard for `--!nocheck` and `--!nonstrict` scripts, together with "non-strict by default".
- The Studio Beta toggle was scheduled for removal in the first release of 2026 (January 7, 2026). Projects that used the new solver in strict mode during the beta were told to set `UseNewLuauTypeSolver` from `Default` to `Enabled`.
- **Reported:** enabling it on large strict codebases surfaces many new errors.

Impact: type functions, better refinement and generics are available. Code written to satisfy the old solver (casts through `any`, duplicated annotations) is noise now. See [[Luau Type System and Strict Mode]].

## 6. UI Styling is released

**Roblox docs** (DevForum "[Full Release] UI Styling is officially released", https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082, early 2026; guide https://create.roblox.com/docs/ui/styling).

`StyleSheet`, `StyleRule` (with `Selector`), `StyleLink`, `StyleDerive`, and `$token` attribute references. Only one StyleSheet can apply to a given tree. **Unverified status:** StyleQuery (container and media-query-like rules, `@` selectors, announced May 11, 2026) and Styling Transitions were still described as Studio Beta features in the posts found.

```lua
local sheet = Instance.new("StyleSheet")
sheet:SetAttribute("Accent", Color3.fromHex("FFB000"))
local rule = Instance.new("StyleRule")
rule.Selector = "TextButton"
rule:SetProperties({ BackgroundColor3 = "$Accent", AutoButtonColor = false })
rule.Parent = sheet
local link = Instance.new("StyleLink")
link.StyleSheet = sheet
link.Parent = screenGui
```

## 7. Character Controller Library (April 11, 2026)

**Roblox docs** (DevForum full release, https://devforum.roblox.com/t/full-release-the-future-of-character-movement-character-controller-library/4565267; docs https://create.roblox.com/docs/characters/character-controller-library).

- Opt-in per experience in Avatar Settings, Movement section. Built on `ControllerManager` plus the AvatarAbilities library.
- Roblox says Humanoid APIs are not deprecated and existing games are not changed; templates move to it over time.
- Roblox reports performance from equal to 2x faster than Humanoid. Custom abilities were not supported at release.
- **Reported:** missing Humanoid-era features (a forum reply names turn speed, `autoTurnSpeed`) and an R6-only bug.

Impact: code that assumes `Humanoid.WalkSpeed`, `Humanoid.Jump` or `Humanoid:ChangeState` drives movement may do nothing in a CCL game. Check which controller the place uses before editing movement.

## 8. Smaller changes worth knowing

| Change | Date | Label and source |
|---|---|---|
| `Player.FrustumStreaming` streams by camera frustum | Sept 2026 | Roblox docs, https://devforum.roblox.com/t/frustum-streaming-stream-what-your-players-see/4904553 |
| Custom terrain materials out of Early Access, up to **62** per game | Oct 2026 | Roblox docs, https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620 |
| `AssetService:PromptCreatePlatformContentAsync` (takes an `Object`, e.g. EditableImage) replaces `PromptCreateAssetAsync` | Oct 2026 | Roblox docs, https://devforum.roblox.com/t/in-game-editable-image-publishing/4944421/1 |
| `AssetService:CreateAssetAsync` accepts `AudioTextToSpeech` (Studio beta) | Oct 2026 | Roblox docs, https://devforum.roblox.com/t/studio-beta-text-to-speech-asset-creation-support-in-lua/4950480 |
| SLIM supports StarterHumanoids and StarterCharacters with `Workspace.EnableSLIMAvatars` | Oct 2026 update | Roblox docs, https://devforum.roblox.com/t/introducing-support-for-platform-avatars-in-slim/4632702 |
| `AvatarUnificationMode` deprecated | Dec 1, 2026 | Roblox docs, weekly recap Oct 19-23, 2026 |
| Server error stack traces deep-link to the script and place version in Studio | Oct 2026 | Roblox docs, https://devforum.roblox.com/t/announcing-studio-deep-links-on-stack-traces-for-server-logs/4953062 |
| `SignalBehavior.Default` still equals `Immediate`; will become `Deferred` (no date) | docs updated Oct 19, 2026 | Roblox docs, SignalBehavior enum page |
| Script Sync (Studio scripts mirrored to local `.luau` files) still Studio Beta; up to 10,000 scripts per synced root, 128 roots | docs updated June 19, 2026 | Roblox docs, https://create.roblox.com/docs/scripting/sync |
| EditableMesh and EditableImage creation can return `nil` when the device budget is exhausted | 2025 | Reported (staff replies in the DevForum beta threads) |
| Avatar body validation: Custom Height defaults to 3.6-6.5 studs for some templates | Oct 2026 update | Roblox docs, https://devforum.roblox.com/t/update-to-avatar-body-validation-ensuring-consistent-scaling-for-avatars/4817186/63 |

## Common mistakes

- Writing `GetProductInfo`, `LoadCharacter` or `AwardBadge` in new code. They run, but they are flagged and teach the next reader old names.
- Setting `RenderFidelity = Performance` as an optimisation. It is ignored under mesh streaming and is on the removal path.
- Assuming UI images can be 4K because 3D textures can.
- Choosing `Enum.Font.Gotham*` and expecting Gotham.
- Driving movement through Humanoid properties in a game that opted into the Character Controller Library.
- Treating Script Sync or StyleQuery as stable features in a team workflow (both betas as of 2026-10-28).

## Checklist

- [ ] `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ApplyDescription|ReserveServer|ReserveServerAsync)\(` returns nothing in new code (`AwardBadgeAsync`, `GetProductInfoAsync`, `LoadCharacterAsync`; reserved servers via `TeleportOptions.ReservedServerId`).
- [ ] No gameplay logic depends on `RenderFidelity`.
- [ ] Text uses `FontFace`.
- [ ] Movement edits checked against the controller in use (Humanoid or CCL).
- [ ] `EditableMesh`/`EditableImage` creation handles `nil`.

## See also

- [[Roblox Changes 2025-2026]]
- [[Server Authority and Input Migration 2026]]
- [[AI Pitfalls - Stale APIs and Luau]]
- [[Level of Detail and Model Streaming]]
- [[Textures Decals and Texture Memory]]
- [[Text Fonts and Rich Text]]
- [[Luau Type System and Strict Mode]]
- [[Instance Streaming]]

<!-- related:start -->
## Related
[[Discovery and Monetization Changes 2025-2026]] · [[Badges and Achievement Design]] · [[Data and Cloud Changes 2025-2026]] · [[Policy and Age Rules 2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Avatar Context Menus Profiles and Social Surfaces]] · [[Console and VR Release Checklists]]
<!-- related:end -->
