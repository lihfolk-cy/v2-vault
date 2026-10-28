---
tags: [worked-build, library, datastore, session-locking, processreceipt, idempotency, odds, policyservice, luau, strict]
---
# LihFolk Systems - Data and Purchase Guarantees

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Adding a second writer (admin tool with `SetAsync`) -> route through `PlayerData` or respect the lease
> - Avoid: Editing a released migration step -> add a new step, bump `schemaVersion`
> - Avoid: Grant function that yields or mutates before validating -> validate first, then mutate synchronously
> - Only `PlayerData` writes player keys; only `Receipts` sets `ProcessReceipt`.
> - `SimulateLoadFailure` kicks without saving; `TestProfileKey` gives a fresh profile.
> - Play/Stop/Play quickly exercises the locked path without data loss.
>
> Cost: TL;DR ~180 tok · whole note ~2.2k tok. Read more: ## 2. Guarantee: one server writes a profile · ## 6. Guarantee: a Robux purchase grants exactly once · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This note explains, guarantee by guarantee, how the [[LihFolk Systems Library]] keeps player data and Robux purchases safe: what each guarantee is, the exact mechanism in `PlayerData`, `Receipts`, `Shop`, `EggHatch` and `Policy`, and the failure each one prevents. Read it before changing those modules or porting a game's existing data layer onto them.

**Trust label:** code is **reviewed, not run** in Studio. Platform numbers are Roblox docs (as of October 2026) unless marked "rule of thumb" or "measured in the reference project". Paid random item rules are policy and change; recheck the Creator Hub before shipping.

---

## 1. The stored record

One DataStore key per player (`U_<userId>`; Studio uses the `<storeName>_STUDIO` store and optional `T_<word>_` keys):

```
{ Schema = 3,
  Data   = { Currency = {...}, Inventory = {...}, Eggs = {...}, ... },   -- one entry per slice
  Meta   = { Created, Receipts = { [PurchaseId] = time }, ReceiptOrder = {...}, PurchaseLog = {...} },
  Session = { Token, JobId, PlaceId, ExpiresAt } }                       -- nil when released
```

`Meta` sits outside `Data` on purpose: a data reset or a migration that rebuilds `Data` cannot erase the receipt history that stops double grants ([[Purchase Data and Receipts]]).

## 2. Guarantee: one server writes a profile

- **Claim** is an `UpdateAsync` transform that refuses (returns nil, cancelling the write) when another token holds an unexpired lease, otherwise writes its own `Session` with `ExpiresAt = os.time() + 90`.
- **Every save** is an `UpdateAsync` that first checks `old.Session.Token == profile.Token`. If not, the profile becomes `lost`, the server stops writing and kicks the player with "opened on another server". This is the fence that turns a slow or partitioned old server from a data-loss bug into a harmless rejected write.
- **Lease timing:** 90 s lease, autosave every 30 s (clamped to lease/3). The autosave is also the heartbeat, so an active profile never expires; a crashed server's lease frees itself in at most 90 s. Leases under about 30 s are unsafe because server clocks disagree (rule of thumb from [[Session Locking and Profile Libraries]]). Locked claims retry 6 times, 1.5 s apart, about 7.5 s in total (measured in the reference project).
- **Same-server rejoin** waits for this server's own release save before claiming.

## 3. Guarantee: a failed load can never save

Load returns `ready`, `locked`, `failed`, `corrupt` (stored value is not a table) or `newer` (schema above the server's). Only `ready` creates a profile; everything else kicks with a specific message and releases any lease it took. A thrown error is retried with backoff and never treated as a new player. A new player is only "the read succeeded and nothing was there" (or only a `Session` from an earlier claim). Permanent errors (codes 1xx and 4xx: bad request, no API access) are not retried; throttling (3xx) and server errors (5xx) are (rule of thumb).

## 4. Guarantee: saves are complete and readable

- The save serialises a **deep copy** taken before the first yield, so gameplay mutating `Data` during the request cannot produce a half-applied save.
- `findUnsavable` walks the snapshot and refuses to write NaN, infinity, Instances or Vector3s, non-string/number keys, arrays mixed with dictionary keys, and arrays with holes, keeping the last good save instead of corrupting it.
- Size is measured with `JSONEncode`; a warning fires above 75% of the 4,194,304-character per-key cap.
- `keyInfo:GetMetadata()` is passed back and the player's UserId is attached on every write, so metadata survives and data-deletion requests can find the key.

## 5. Guarantee: leaving and shutdown save once

`PlayerRemoving` removes the profile from the active map first (no service can mutate after the final snapshot), fires `Releasing` for services that need final values (leaderboards read the detached profile), then saves with the lease released. `BindToClose` releases every profile in parallel and waits up to 26 s (the server allows 30 s) or 3 s in Studio, where Stop is not a shutdown test ([[Saving Correctly - Autosave and BindToClose]]).

## 6. Guarantee: a Robux purchase grants exactly once

`Receipts` is the only `ProcessReceipt`. For each receipt:

1. Unknown product id: `NotProcessedYet` (a later server build that knows it will grant). Player not in this server, or profile not ready within 15 s: `NotProcessedYet`.
2. `PlayerData.purchaseCore`:
   - `PurchaseId` already in `Meta.Receipts` and confirmed by a save: **duplicate**, answer `PurchaseGranted`, grant nothing.
   - Already in `Meta.Receipts` but its save failed earlier: save again, grant nothing; `PurchaseGranted` only if this save succeeds.
   - Otherwise: run the grant (synchronous, validate-then-mutate), record the `PurchaseId` and a log entry, then save. `PurchaseGranted` only after the write succeeds.
3. Side effects (`Receipts.Granted`) fire after the durable save, on the first confirmation in this server.

The check, grant and record have no yield between them, so two concurrent deliveries of one receipt cannot both grant. Paid grants force past a full inventory (the player already paid). Per-player limits and the paid-random-item gate run in `Shop.PromptProduct` **before** the prompt, never by refusing a paid receipt, which would leave it stuck ([[Developer Products and ProcessReceipt]]). The receipt list keeps the last 500 ids and the log the last 100 entries (rule of thumb).

## 7. Guarantee: odds shown are odds rolled

`EggHatch.computeFinals(player, egg)` combines: effective luck (one function, one cap, paid sources excluded for restricted players), hard pity (the roll numbered `rolls` without the pity tier or better excludes lower tiers), and once-per-player items already obtained (removed, emptied tiers drop to zero so the rest renormalises). The hatch roll and `Eggs.GetOdds` both call it. The display returns every final outcome with a percentage formatted to four places below the first non-zero digit (never 0% for a non-zero chance), a "1 in N" supplement, the pity rule with base and effective rates, and the rounding disclaimer. `EffectiveLuck` and an `Eggs.OddsChanged` push keep an open panel live when boosts start or expire ([[Paid Random Items and Odds Disclosure in Practice]]).

## 8. Guarantee: restricted players are kept out, server-side

`Policy` fetches `GetPolicyInfoForPlayerAsync` with retries, publishes **restricted** until a fetch succeeds, treats any missing key or non-boolean as restricted, and retries failures in the background. `CanBuyPaidRandom` (paid eggs, luck products, luck passes) and `CanTradePaid` (`Inventory.CanTrade` for items with `Paid` provenance) are separate gates. Both are enforced in server handlers; the attributes exist only to draw UI ([[Roblox Policies Ratings and Compliance]]).

---

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Adding a second writer (admin tool with `SetAsync`) | overwrites a live session's data | route through `PlayerData` or respect the lease |
| Editing a released migration step | profiles migrated twice disagree | add a new step, bump `schemaVersion` |
| Grant function that yields or mutates before validating | partial grant on error | validate first, then mutate synchronously |
| Refusing a paid receipt for a limit | receipt stuck pending | check limits at prompt time |
| Luck source not marked `paid` for a paid pass | restricted players get paid odds | mark it paid |
| Treating `ForceRestrictedPolicy` as optional testing | side pop-ups bypass the gate unnoticed | walk every purchase surface with it on |

## Checklist

- [ ] Only `PlayerData` writes player keys; only `Receipts` sets `ProcessReceipt`.
- [ ] `SimulateLoadFailure` kicks without saving; `TestProfileKey` gives a fresh profile.
- [ ] Play/Stop/Play quickly exercises the locked path without data loss.
- [ ] Test purchase, then rejoin: one grant, one log entry.
- [ ] Odds panel matches a chi-square roll test for each egg and luck state.
- [ ] `ForceRestrictedPolicy` blocks paid eggs, luck products and luck passes server-side.

## See also
[[LihFolk Systems Library]] · [[Session Locking and Profile Libraries]] · [[Saving Correctly - Autosave and BindToClose]] · [[Data Schema Design and Migrations]] · [[Purchase Data and Receipts]] · [[Developer Products and ProcessReceipt]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Roblox Policies Ratings and Compliance]] · [[Trading Systems Without Duplication]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Idempotency]] · [[Session Lock]]
