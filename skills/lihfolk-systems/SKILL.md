---
name: lihfolk-systems
description: 'LihFolk: Drop-in Luau systems library for Roblox. Copy tested-by-design modules instead of writing systems from scratch: session-locked PlayerData, validated Net remotes, Currency, Shop, ProcessReceipt router, Inventory, EggHatch (odds disclosure, pity, luck, PolicyService), Codes, DailyRewards, Rebirth, Quests, Leaderboard, RateLimit, Signal, Janitor. Use when the user asks to add a shop/inventory/pets/eggs/quests/daily rewards/codes/rebirth/leaderboard/combat/trading/data saving system, says "add a shop", "add pets", "egg hatching", "data saving", "save player data", "add codes", "daily rewards", "rebirth system", "global leaderboard", "quest system", or runs /lihfolk:new-system.'
---
# LihFolk Systems Library

Strict Luau modules that already pass the hard gates of `quality-score/rubrics/system.md` by construction, so an agent installs and configures them instead of re-deriving session locking, receipt idempotency or odds disclosure (the places where generated code is most often subtly wrong). Each module follows `roblox-secure-remotes`, `roblox-datastore-safety` and `roblox-monetization-compliance`, and the shapes of the vault's Worked Builds.

**Honesty label:** all code is **reviewed, not run in Studio**. It was checked with a structural checker (blocks, brackets, interpolation, deprecated APIs), parsed by Roblox LSP with zero syntax errors, and built into a place with Rojo 7.7. The specs in `tests/` have not been executed. Until they pass in Studio, the rubric gate "runs without errors / tests pass" is open and the score is capped at 5.0. Say so.

## Inputs

- `LIB`: this folder (`skills/lihfolk-systems/`). `VAULT`: `../../LihFolk Vault V2/` (start with `VAULT/INDEX.md`).
- The user's project: Rojo tree or Studio place, existing data module, existing `ProcessReceipt`, existing remotes.

## Layout and install paths

| File | Install as | Role |
|---|---|---|
| `src/Shared/Signal.luau` | `ReplicatedStorage/LihFolk/Signal` | events between modules |
| `src/Shared/Janitor.luau` | `ReplicatedStorage/LihFolk/Janitor` | cleanup of connections, instances, threads |
| `src/Shared/RateLimit.luau` | `ReplicatedStorage/LihFolk/RateLimit` | token bucket per player, cleared on leave |
| `src/Shared/Net.luau` | `ReplicatedStorage/LihFolk/Net` | the one place remotes are created; rate + type + range validation |
| `src/Shared/Odds.luau` | `ReplicatedStorage/LihFolk/Odds` | flatten, pick, format, pity maths, chi-square |
| `src/Shared/Feedback.luau` | `ReplicatedStorage/LihFolk/Feedback` | client: result codes to kind messages |
| `src/Server/*.luau` | `ServerScriptService/LihFolk/<Name>` | PlayerData, Policy, Currency, Inventory, Rewards, Receipts, Shop, EggHatch, Codes, DailyRewards, Rebirth, Quests, Leaderboard |
| `src/Config/LihFolkConfig.luau` | `ReplicatedStorage/LihFolkConfig` | display-safe config (items, prices, odds, quests) |
| `src/Config/LihFolkSecrets.luau` | `ServerStorage/LihFolkSecrets` | codes (never replicated) |
| `examples/Main.server.luau` | `ServerScriptService/Main` (Script) | the only server Script; wiring order |
| `examples/<System>.server.luau` / `.client.luau` | Script / LocalScript | minimal wiring per system (use these OR Main) |
| `tests/Runner.luau`, `tests/*.spec.luau` | `ServerScriptService/LihFolkTests` | TestEZ-style specs + tiny runner |
| `default.project.json` | project root | Rojo mapping of all of the above |

Rojo users: merge `default.project.json` into theirs. Studio-only users: create the folders above and paste each file into a ModuleScript (`.server` = Script, `.client` = LocalScript). Enable Game Settings > Security > Enable Studio Access to API Services. Studio automatically uses `<storeName>_STUDIO`, so tests never touch live saves.

## Procedure

1. **Survey first.** Grep the project for `ProcessReceipt`, `GetDataStore`, `UpdateAsync`, `SetAsync`, `RemoteEvent`, `RemoteFunction`. If a data module or receipt handler already exists, do not install a second one: either migrate to `PlayerData`/`Receipts` (one writer, one `ProcessReceipt`) or adapt the services to the existing module's `Get`/`MarkDirty` equivalent. Two writers or two receipt handlers is a hard failure.
2. **Install only what is needed**, plus dependencies: every server service needs `PlayerData`; `Rewards` needs `Currency` + `Inventory`; `Inventory` needs `Policy`; `Shop` needs `Receipts`; `EggHatch` needs `Currency`, `Inventory`, `Policy`. All need the Shared folder.
3. **Configure.** Edit `LihFolkConfig` (replace every `id = 0` with real Developer Product / Game Pass ids; ask the user, or leave 0 and say so: id 0 products are never prompted) and `LihFolkSecrets`. Mark every currency `paid = true` if Robux can buy it directly or indirectly.
4. **Wire in this order** (see `examples/Main.server.luau`): `PlayerData.Configure` -> `Policy.Init` -> service `Init(config)` calls -> cross-module hooks (luck sources, custom grants, prompt checks, quest feeds) -> `Receipts.Start` -> `PlayerData.Start`. Services register their profile slice and remotes in `Init`; nothing loads before the slices exist; `Receipts.Start` asserts every product has a grant.
5. **Client.** Clients use `Net.Request` / `Net.On`, render attributes (`Coins`, `Rebirths`, `EffectiveLuck`, `Pass_<key>`, `PaidRandomAllowed`, `DataReady`) and show `Feedback.Text(result.code)`. Build real UI with `roblox-ui-builder`.
6. **Extend** with new services in the same shape: `Init(config)` that asserts config, calls `PlayerData.RegisterSlice`, declares remotes with `Net.Handle`; public functions that validate then mutate `profile.Data` synchronously and call `PlayerData.MarkDirty`.
7. **Test** (step list below), then score with `quality-score` (system rubric, minimum 8.5).

## Module contracts (the parts agents get wrong)

- **Net.** `Net.Handle(name, { rate = { burst, perSecond }, args = { validators }, handler })`. Order: rate limit -> arg count -> per-arg type/range -> handler (context checks, act). Extra args rejected. `exclusive` (default on) gives one in-flight request per player per remote. Rejections are scored (`Net.Violation`, `Net.GetViolationScore`), logged at most once per 30 s per player, never kicked on one. Validators: `T.integer`, `T.number`, `T.string(maxBytes, pattern)` (UTF-8 checked), `T.key(map)`, `T.oneOf`, `T.guid`, `T.vector3`, `T.array`, `T.instance`, `T.optional`. No `InvokeClient` exists anywhere.
- **PlayerData.** Lease `{Token, JobId, ExpiresAt}` (90 s) checked inside `UpdateAsync`; every save fenced by token; `ready`/`locked`/`failed`/`corrupt`/`newer` are distinct and only `ready` has a save path; staggered dirty-gated autosave that doubles as the lease heartbeat (30 s, clamped to lease/3); save + release on leave; parallel `BindToClose` with a 26 s deadline (3 s in Studio); `findUnsavable` refuses NaN, infinity, Instances/Vector3, mixed or holed arrays before writing; `keyInfo` user ids and metadata passed through. `ProcessPurchaseAsync` records grant + `PurchaseId` + purchase log in the same document and write; returns `granted` only after the save. Studio switches (ServerStorage attributes): `TestProfileKey`, `SimulateLoadFailure`.
- **Receipts.** The only `ProcessReceipt`. Unknown product, absent player or unloaded profile -> `NotProcessedYet`. Paid grants force past a full bag. Limits and policy are checked at prompt time in `Shop.PromptProduct`, never by refusing a paid receipt. Retired products keep their entry.
- **Shop.** Soft-currency `Shop.Buy(key, qty)`: price from server config, affordability and bag space checked, then spend + grant with no yield. Passes: ownership cache from `UserOwnsGamePassAsync` (errors retried, never cached as "not owned"), updated by `PromptGamePassPurchaseFinished`. Prices on screen: `GetProductInfoAsync` on the client (see `examples/Shop.client.luau`).
- **EggHatch.** `computeFinals` (luck, pity counter, obtained once-items) feeds both the roll and `Eggs.GetOdds`, so display and roll cannot diverge. Luck has one function and one cap; paid luck sources and boosts are excluded for restricted players. `EffectiveLuck` attribute + `Eggs.OddsChanged` push keep open odds panels live. Boost preview returns numeric before/after and `atCap`. Paid eggs (price currency `paid = true` or `paid` flag) are refused server-side when `ArePaidRandomItemsRestricted` is not exactly `false`; `restrictedNote` names the alternative (the example config gives a free quest path). Pity counters are saved. Hatched uniques carry `Paid` provenance.
- **Policy.** Two separate gates, `CanBuyPaidRandom` and `CanTradePaid`, fail closed (missing key, error, not fetched = restricted), retried in the background. `ForceRestrictedPolicy` ServerStorage attribute forces the restricted path in Studio.
- **Inventory.** Stable GUID per unique, never index-based; `CanAdd` before `Add`; `CanTrade(player, uid)` combines `tradable` with `Policy.CanTradePaid` for `Paid` items.
- **Codes / DailyRewards / Quests.** Mark-and-grant in one synchronous block after `Rewards.CanGrant`; refused (nothing marked) on a full bag. Codes: server-only list, normalised input, expiry by server UTC, one use per player, miss lockout by UserId. Daily: fixed UTC reset with offset, streak/grace as pure functions, countdown computed on the server. Quests: progress only from server code via `Quests.Report`.
- **Rebirth.** Closed-form geometric bulk cost and max, corrected to exact; registers the earn multiplier on its currency.
- **Leaderboard.** Profile is the truth; ordered store is an index. Writes every 120 s only when changed, plus once on leave from the detached profile; reads one page per board per 120 s, staggered; budget checked before both; monotonic boards never lower; weekly boards are a new store each Monday 00:00 UTC; `LogEncode` for simulator-scale numbers; `exclude` for bans and deletion requests.

## Decisions baked in (change consciously)

| Decision | Default | Why |
|---|---|---|
| Load failure | kick with a clear message | never play on defaults that could save over real data |
| Newer schema | refuse and kick | rolling updates would strip new fields |
| Day reset | 00:00 UTC + offset | honest countdown, every server agrees |
| Full bag on free reward | refuse, nothing marked | all-or-nothing |
| Full bag on paid receipt | grant anyway (force) | the player already paid |
| Rebirth | whole balance resets | the leftover is part of the trade |
| Timed luck boosts | expire in real time, offline too | simple and honest; state it in UI |
| Odds disclosure | on every egg, paid or not | removes the "is this paid?" grey zone |

## Rubric gates (system.md) and how the library meets them

| Gate | Met by | Still needs |
|---|---|---|
| Runs without errors / tests pass | 18 spec modules + runner; structural and LSP parse clean; Rojo build OK | **run `tests/Runner` and a Play test in Studio** (not done) |
| Server-authoritative remotes (type, range, rate) | `Net.Handle`/`Net.Listen` on every remote; no client prices, rewards, odds or time | keep new remotes on `Net` |
| Data: pcall + retry, session lock, BindToClose, idempotent receipts | `PlayerData` + `Receipts` | one writer: remove any other DataStore writer |
| Paid random items: odds shown, PolicyService fail-closed | `EggHatch` + `Odds` + `Policy` + `Shop.PromptProduct` | an "Odds" labelled button on every purchase surface in the UI |
| No deprecated APIs, no unbounded loops | `task.*` only; long-lived loops yield every iteration | keep it that way |

Criteria help: S1 edge cases (rejoin, leave mid-load, double submit, redelivered receipts) are handled in PlayerData/Net/Receipts; S2 exploits table below; S3 pushes are coalesced, per-player tables cleared on leave; S4 config separate, typed modules; S5 depends on the UI you build (Feedback gives the messages); S6 scripted specs.

## Testing in Studio

1. `require(game.ServerScriptService.LihFolkTests.Runner)()` from the command bar: expect `N passed, 0 failed`.
2. Play: change state, Stop, Play: it persists. `TestProfileKey = "a"`: fresh profile. `SimulateLoadFailure = true`: kicked, save untouched. Play/Stop/Play fast: the locked path behaves.
3. Two-client test (Test > Clients and Servers): no state leaks between players.
4. `ForceRestrictedPolicy = true`: paid eggs, luck products and the luck pass are refused server-side; free eggs show base-luck odds.
5. Fuzz remotes from a Studio-only server script with wrong types, NaN, huge strings, extra args and floods: `Invalid`/`TooFast`, nothing created from nothing (`roblox-anti-exploit-review`).
6. Purchases: Studio test purchases with real product ids; rejoin mid-purchase; check the purchase log in the profile.

## Exploits this library stops (and what it does not)

| Attack | Stopped by |
|---|---|
| Wrong types, NaN, infinity, fractions, long or invalid UTF-8 strings, extra args | `Net` validators |
| Remote floods / auto-clickers | `RateLimit` per remote per player, `exclusive` busy flag |
| Double submit / race to dupe | synchronous check-and-write, no yields, busy flag |
| Second server writing old data | lease + token fence in every `UpdateAsync` |
| Redelivered or concurrent receipts | `PurchaseId` recorded with the grant, `duplicate` path |
| Client-sent prices, odds, rewards, time | none accepted; all from server config and `os.time()` |
| Brute-forcing codes | rate limit + miss lockout by UserId |
| Restricted player buying paid random items via a side pop-up | gate in the server prompt path, not the UI |

Not stopped on its own: future server code that calls `Currency.Add` or `Inventory.Add` with unvalidated values; trades between players (no Trade module yet: use `Inventory.CanTrade` for both sides plus a ledger, vault `Trading Systems Without Duplication`); movement and combat exploits (use the Melee Combat worked build).

## Not in the library yet

Combat (follow `24 Worked Builds/Melee Combat System End to End.md` with `Net` + `RateLimit`), trading (ledger claimed with `UpdateAsync`; gate both players with `Inventory.CanTrade`), live codes and global code limits (`Codes Redemption System End to End.md`), MemoryStore matchmaking. Build these with `roblox-system-builder` on top of this library's `PlayerData` and `Net`.

## Hard rules

- One `PlayerData`, one `Receipts.Start` (`ProcessReceipt`), one `Main` Script, one place that creates remotes (`Net`).
- Never edit migration steps after release; add a new one and bump `schemaVersion`.
- Never call `PlayerData.Get` inside a leaderboard `source` (use the profile argument).
- Never prompt a product with `id = 0`; never hard-code a Robux price.
- Treat policy facts as "as of October 2026" and tell the user to recheck the Creator Hub before shipping.
- Label results "reviewed, not run" until the specs and Play tests pass.

## Read these vault notes

- `24 Worked Builds/LihFolk Systems Library.md` (this library) and `24 Worked Builds/LihFolk Systems - Data and Purchase Guarantees.md`
- `24 Worked Builds/Saved Inventory End to End.md`, `Shop with Game Passes and Developer Products End to End.md`, `Pet Hatching and Following End to End.md`, `Codes Redemption System End to End.md`, `Daily Rewards System End to End.md`, `Global Leaderboards End to End.md`, `Quest Chain System End to End.md`, `Rebirth and Prestige System End to End.md`
- `04 Data and Persistence/Session Locking and Profile Libraries.md`, `Purchase Data and Receipts.md`, `Trading Systems Without Duplication.md`
- `11 Monetization Publishing and Live Ops/Paid Random Items and Odds Disclosure in Practice.md`, `Developer Products and ProcessReceipt.md`, `Roblox Policies Ratings and Compliance.md`
- `03 Architecture and Networking/Rate Limiting and Abuse Prevention.md`, `22 Anti-Exploit and Security/Testing Your Own Remotes - Fuzzing and Abuse Tests.md`
