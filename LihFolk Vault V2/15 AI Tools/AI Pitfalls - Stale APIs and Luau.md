---
tags: [ai-pitfalls, luau, deprecated-apis, async-rename, task-library, chat, fonts, type-solver, lint, type/guide, area/ai, level/intermediate]
verified: 2026-10-28
---
# AI Pitfalls - Stale APIs and Luau

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Replacing `wait` with `task.wait` inside a polling loop that should be an event connection.
> - Avoid: Converting `BodyVelocity` to `LinearVelocity` without an attachment or with `RelativeTo` wrong.
> - Avoid: Treating deprecation warnings as optional in new code.
> - Every lint pattern above returns nothing in new code.
> - Animator created on the server; tracks loaded once and reused.
> - No chat code outside TextChatService.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## 2. Methods renamed with `Async` (January 14, 2026) · ## 10. Invented members · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The most visible AI mistake is old API surface: code that was idiomatic in 2019, or correct until January 2026. Most of it still runs, which is why it survives review. This note lists each stale pattern, why a model produces it, the current form, and a grep to find it. Hub: [[What AI Models Get Wrong in Roblox]]. Change dates: [[Engine and API Changes 2025-2026]].

## 1. Legacy scheduler: `wait`, `spawn`, `delay`

- **Wrong:** `wait(1)`, `spawn(fn)`, `delay(2, fn)`.
- **Why:** the bulk of public Roblox code uses them. **Reported:** community guides cite legacy `wait()` as the commonest sign of AI-written Luau.
- **Right:** `task.wait`, `task.spawn`, `task.defer`, `task.delay`. They run on the engine scheduler without legacy throttling, and `task.spawn` resumes immediately.
- **Detect:** `rg -n "(^|[^.:\w])(wait|spawn|delay)\("`.

## 2. Methods renamed with `Async` (January 14, 2026)

- **Wrong:** `GetProductInfo`, `PlayerOwnsAsset`, `AwardBadge`, `LoadCharacter`, `IsInGroup`, `GetRankInGroup`, `ApplyDescription`, `ReserveServer`, `CreateHumanoidModelFromDescription`.
- **Why:** the rename post-dates most training data. **Roblox docs:** old names are deprecated but keep working (https://devforum.roblox.com/t/psa-several-common-yielding-methods-have-been-renamed/4257585).
- **Right:** the same name plus `Async`, same arguments. Wrap in `pcall`; these are network calls.
- **Detect:** `rg -n ":(GetProductInfo|PlayerOwnsAsset|PlayerOwnsBundle|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|GetRoleInGroup|IsFriendsWith|ApplyDescription|PlayEmote|ReserveServer|CreateHumanoidModelFrom\w+|GetHumanoidDescriptionFrom\w+)\("`. Full map: `_data/roblox_facts_2026.json`.

## 3. `Humanoid:LoadAnimation`

- **Wrong:** `humanoid:LoadAnimation(anim)`.
- **Why:** the most common tutorial form for years.
- **Right:** `humanoid:WaitForChild("Animator"):LoadAnimation(anim)` (or `AnimationController.Animator`). Load once per character and reuse the track. **Roblox docs:** the Animator should be created by the server so playback replicates; a client-created Animator does not replicate.
- **Detect:** `rg -n "[Hh]umanoid:LoadAnimation"`.

## 4. Body movers and old physics members

| Wrong | Right |
|---|---|
| `BodyVelocity` | `LinearVelocity` |
| `BodyPosition` | `AlignPosition` |
| `BodyGyro` | `AlignOrientation` |
| `BodyForce` / `BodyThrust` | `VectorForce` |
| `BodyAngularVelocity` | `AngularVelocity` |
| `part.Velocity` / `RotVelocity` | `AssemblyLinearVelocity` / `AssemblyAngularVelocity` |
| `model:SetPrimaryPartCFrame(cf)` / `GetPrimaryPartCFrame` | `model:PivotTo(cf)` / `GetPivot()` |
| `inst:Remove()` | `inst:Destroy()` (or `Parent = nil` to keep it) |

Constraints need `Attachment`s; models often forget `Attachment0` or set `MaxForce` to 0 and see nothing move. See [[Mover Constraints and Physics Controllers]]. **Detect:** `rg -n "Body(Velocity|Position|Gyro|Force|Thrust|AngularVelocity)|SetPrimaryPartCFrame|\.RotVelocity|:Remove\(\)"`.

## 5. Raycasting

- **Wrong:** `workspace:FindPartOnRay(Ray.new(o, d), ignore)`, `RaycastFilterType.Blacklist`.
- **Right:**

```lua
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude -- Blacklist/Whitelist are deprecated
params.FilterDescendantsInstances = { character }
local hit = workspace:Raycast(origin, direction * maxDistance, params) -- direction is NOT unit-length
```

- Models also pass a unit vector as `direction` and get 1-stud rays. **Measured:** prop placement with a default exclude list landed props on trees, colliders and earlier props; a terrain-only include list fixed it (see [[Raycasts Shapecasts and Spatial Queries]] and [[MCP Workflows for Building Worlds]]).
- **Detect:** `rg -n "FindPartOnRay|Ray\.new|Blacklist|Whitelist"`.

## 6. Legacy and locked-down chat

- **Wrong:** `game:GetService("Chat"):Chat(...)`, `ChatServiceRunner`, `SayMessageRequest`, custom chat UIs reading `TextChatMessage.Text`, moderation in `OnIncomingMessage` or `Player.Chatted`.
- **Why:** pre-2025 tutorials; legacy chat was removed by April 30, 2025, and the October 2026 lockdown is newer than any model.
- **Right:** TextChatService only. `TextChannel:SendAsync`, `TextChatCommand`, `TextChannelWindow` for custom UI; filtering and age rules are the platform's. Plan for `TextChatMessage.Text` returning `""` to scripts by May 2027. See [[Policy and Age Rules 2026]].
- **Detect:** `rg -n "game\.Chat|GetService\(\"Chat\"\)|ChatService|SayMessageRequest|\.Chatted|OnIncomingMessage|ChatVersion"`.

## 7. Fonts

- **Wrong:** `label.Font = Enum.Font.GothamBold`.
- **Right:** `label.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold)`. Gotham is removed and maps to Montserrat; Arial maps to Arimo (Roblox docs, Font enum page).
- **Detect:** `rg -n "Enum\.Font\."`.

## 8. Clocks

- **Wrong:** `tick()` for durations or cooldowns.
- **Right:** `os.clock()` for local durations, `workspace:GetServerTimeNow()` for cross-machine timestamps, `time()` inside Server Authority simulation (synchronised and rolled back). `os.time()` is whole seconds UTC: fine for daily resets, wrong for cooldowns.
- **Detect:** `rg -n "tick\(\)"`.

## 9. Lua that is not Luau, and Luau the model under-uses

- **Not available or discouraged:** `goto`, `io.*`, `os.execute`, `debug.sethook`; `loadstring` is off unless `ServerScriptService.LoadStringEnabled`; `getfenv`/`setfenv` disable optimisations.
- **Under-used:** compound assignment (`x += 1`), string interpolation (`` `{n} coins` ``), `if a then b else c` expressions, generalised iteration (`for k, v in t`), `table.clone`, `table.freeze`, `buffer` for compact binary data, `--!strict` with the new type solver (default since early 2026). See [[Luau Type System and Strict Mode]] and [[Buffers and Binary Data]].
- **Old-solver workarounds** (`:: any` casts to silence errors) hide real type errors under the new solver. Remove and re-check.

## 10. Invented members

Models confidently write members that do not exist or live elsewhere:

| Invented | Real |
|---|---|
| `player.Health`, `player.WalkSpeed` | `player.Character.Humanoid.Health` |
| `Players.LocalPlayer` in a server Script | `nil` on the server; get the player from the event |
| `part.Touched:Connect(function(player)` | Argument is the other `BasePart`; resolve with `Players:GetPlayerFromCharacter(hit.Parent)` |
| `TweenService:Create(part, 1, {...})` | Second argument is a `TweenInfo` |
| `Humanoid.Running` used as a boolean | `Running` is an event (speed); use `MoveDirection.Magnitude` or `GetState()` |
| `MarketplaceService:UserOwnsGamePass(...)` | `UserOwnsGamePassAsync(userId, passId)` |

**Detect:** script analysis warnings ("Unknown global", "Key ... not found in class"). Treat any member you have not seen in the reference as unverified.

## Common mistakes

- Replacing `wait` with `task.wait` inside a polling loop that should be an event connection.
- Converting `BodyVelocity` to `LinearVelocity` without an attachment or with `RelativeTo` wrong.
- Treating deprecation warnings as optional in new code.
- Keeping old-solver `any` casts after the switch.

## Checklist

- [ ] Every lint pattern above returns nothing in new code.
- [ ] Animator created on the server; tracks loaded once and reused.
- [ ] No chat code outside TextChatService.
- [ ] Script analysis shows no deprecation or unknown-member warnings.

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Engine and API Changes 2025-2026]]
- [[Task Library Coroutines and Yielding]]
- [[Mover Constraints and Physics Controllers]]
- [[Luau Language Essentials]]
- [[Luau Type System and Strict Mode]]
- [[Text Fonts and Rich Text]]

<!-- related:start -->
## Related
[[Roblox Changes 2025-2026]] · [[AI Code Assistants for Luau]] · [[AI Pitfalls - Physics and Animation]] · [[AI Pitfalls - UI and Input]] · [[AI Pitfalls - Data and Monetization]] · [[AI Pitfalls - Networking and Security]] · [[Prompting and Verifying AI Output]] · [[Roblox Studio Assistant]]
<!-- related:end -->
