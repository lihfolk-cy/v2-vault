---
name: roblox-datastore-safety
description: Write or review Roblox player-data code so progress is never lost or duplicated: session locking, retries, autosave, BindToClose, schema migrations, purchase receipts and idempotency. Use when touching DataStoreService, profiles, saving or loading, or when the user says "save data", "data loss", "rollback", "duplicated items", "migrate the data", or "review my DataStore code".
---
# Roblox DataStore Safety

Player data lives in server memory during a session and is written back periodically. That is only safe if one server at a time owns each player's data, if a failed load can never save over real data, and if every grant happens at most once. Build or review against those three guarantees.

## Inputs

- `VAULT`: the LihFolk knowledge base at `../../knowledge/` relative to this file (plugin root `knowledge/`). Start with `VAULT/INDEX.md` to find notes fast.
- The data module(s), the receipt handler, and any other code that writes to data stores.

## Procedure

1. **Find every writer.** Grep for `GetDataStore`, `SetAsync`, `UpdateAsync`, `IncrementAsync`, `RemoveAsync`. Player data must be written by exactly one module. Every other writer (admin tools, support tools, trading, gifts) is a finding unless it goes through that module and respects the lock.

2. **Wrap every call.** Every data store call runs in `pcall` with bounded retries, exponential backoff with jitter, and no retry on permanent errors. Never retry throttled calls in a tight loop. Check `GetRequestBudgetForRequestType` before non-urgent bursts.

3. **Use `UpdateAsync` with a lease.** Not `GetAsync` then `SetAsync`. Inside the same `UpdateAsync` transform:
   - read the lease (owner job id, session token, `ExpiresAt` from `os.time()`),
   - refuse if another live session owns it,
   - write the data and renew the lease.
   Fence every save with the per-session token so a server that lost its lease stops writing. Leases shorter than about 30 seconds are unsafe because of clock skew. The reference project used a 90 second lease renewed every 30 seconds, with 6 claim attempts over 7.5 seconds before giving up (measured). Never yield inside the transform: compute first, then call. Pass `keyInfo:GetUserIds()` and `keyInfo:GetMetadata()` through, or they vanish.

4. **Separate the three load outcomes.** Load returns `ready`, `locked` or `failed`. "New player" means the read succeeded and returned nil. A thrown error is never a new player. A profile that did not reach `ready` has no save path at all: kick with a clear message (the reference project's choice) or play on defaults that never save (the docs sample). Never save defaults over real data.

5. **Autosave correctly.**
   - Interval shorter than the lease; clamp it to at most a third of the lease. The vault's example uses 120 seconds clamped to `lease / 3`.
   - Stagger per player so every server does not write in the same second.
   - Gate on a dirty flag; never save on every coin pickup.
   - Budget: each save costs from the server budget (60 + 40 per player per minute) and the experience budget, and a key has a write throughput cap of about 4 MB per minute (Roblox docs, as of October 2026). Values are capped at 4,194,304 characters per key.

6. **Save on leave and shutdown.**
   - `PlayerRemoving`: save immediately with lease release; do not yield before the save.
   - `BindToClose`: save all players in parallel with a deadline, and wait for in-flight leave-saves. The server waits at most 30 seconds (Roblox docs). In Studio, do not hold `BindToClose` open (every Stop then takes about 25 seconds); Studio stop is not a test of shutdown saving.

7. **Version the schema.**
   - A `Schema` integer on every profile and `CURRENT_SCHEMA` in code.
   - Ordered, deterministic, non-yielding migration steps that are never edited after release.
   - Refuse to load a newer schema than the server knows (rolling updates and rollbacks otherwise destroy new fields).
   - Reconcile additive defaults from a template copied per player (never one shared `DEFAULT` table).
   - Convert engine types at the boundary (`Vector3` and `CFrame` cannot be saved); keep arrays dense; store enums by name; never store NaN or infinity.
   - Give every item a stable unique id; never equip by array index.
   - Measure size with `#HttpService:JSONEncode(profile)` and cap growing lists.

8. **Make purchases idempotent.**
   - Exactly one `ProcessReceipt` assignment in the codebase.
   - Wait for the profile; return `NotProcessedYet` if it cannot be saved.
   - Record the grant and the `PurchaseId` together, in the same key, in the same write.
   - Return `PurchaseGranted` only after a confirmed save.
   - Keep the receipt list bounded and keep it across resets. Run one-off side effects (announcements, analytics) only after the durable save, once.
   - Gifts and cross-profile grants go through a ledger claimed with `UpdateAsync`.

9. **Protect live data from Studio.** Either keep Studio API access off on the live experience, or route Studio to a test key or test store. Fuzzers and migration tests never touch live keys.

10. **Plan recovery.** Take a snapshot before any release that touches data code. Know that per-key version history exists but versions older than 30 days after being superseded are gone. Never restore with `SetAsync` while the player is online; restores respect leases. Verify saves with an uncached read (`UseCache = false`).

## Hard rules

- No `SetAsync` for player profiles.
- No save path for a profile that failed to load.
- No yield inside an `UpdateAsync` transform.
- No grant without recording the `PurchaseId` in the same write.
- No shared default tables between players.

## Checks before finishing

- [ ] One module writes player data; all writers respect the lock.
- [ ] Lease checked and renewed inside the data's `UpdateAsync`; saves fenced.
- [ ] `ready` / `locked` / `failed` are distinct; failed never saves.
- [ ] Autosave staggered, dirty-gated, shorter than the lease.
- [ ] Leave save releases the lease; `BindToClose` saves in parallel with a deadline.
- [ ] Schema versioned; newer schema refused; migrations unit-tested on real historical shapes.
- [ ] Receipts idempotent; `PurchaseGranted` only after a confirmed save.
- [ ] Studio cannot reach live keys.
- [ ] Snapshot step in the release plan.

## Read these vault notes

- `04 Data and Persistence/DataStore Fundamentals.md`
- `04 Data and Persistence/Session Locking and Profile Libraries.md`
- `04 Data and Persistence/Saving Correctly - Autosave and BindToClose.md`
- `04 Data and Persistence/Data Schema Design and Migrations.md`
- `04 Data and Persistence/Schema Migrations - Worked Case Studies.md`
- `04 Data and Persistence/Purchase Data and Receipts.md`
- `04 Data and Persistence/Data Loss Prevention and Recovery.md`
- `04 Data and Persistence/Trading Systems Without Duplication.md`
- `23 Debugging Deep Dives/Debugging DataStore Problems.md`
- `29 Luau Cookbook/Cookbook - Data and Saving.md`
- `24 Worked Builds/Saved Inventory End to End.md`

Disputed (see `Open Questions - Whole Vault.md`): the experience write budget base (300 vs 250 plus a per-CCU amount on two docs pages), and the old "one write per key every 6 seconds" rule versus the documented per-key throughput limits. Design with headroom under both.
