---
tags: [ai, agents, ai-skill, datastore, data, type/guide, area/data, level/intermediate, api/DataStore, area/ai]
---
# Skill - Roblox DataStore Safety

**Skill file:** [skills/roblox-datastore-safety/SKILL.md](../skills/roblox-datastore-safety/SKILL.md) (folder name `roblox-datastore-safety`)

## What it does

This skill makes an agent write or review player-data code against three guarantees: one server owns a player's data at a time, a failed load can never save over real data, and every grant happens at most once.

The procedure covers:

- **Finding every writer.** Player data must have exactly one writer module; admin, support, trading and gift code must go through it.
- **Retries.** Every call in `pcall` with bounded, jittered backoff; no tight retry loops on throttling.
- **Session locking.** `UpdateAsync` with a lease checked and renewed in the same transform as the data, fenced by a session token. The reference project used a 90 second lease renewed every 30 seconds (measured).
- **Three load outcomes.** Ready, locked and failed are different; "new player" only when the read succeeded and returned nil.
- **Autosave, leave and shutdown.** Staggered, dirty-gated autosave shorter than the lease; release on leave; parallel saves with a deadline in `BindToClose` (the server waits at most 30 seconds).
- **Schema migrations.** A `Schema` integer, ordered steps never edited after release, newer schemas refused, per-player template copies, engine types converted, stable item ids, measured profile size.
- **Receipts.** One `ProcessReceipt`; grant and `PurchaseId` in the same write; `PurchaseGranted` only after the save.
- **Studio isolation and recovery.** Test keys or a test store, snapshots before data releases, uncached verification reads, restores that respect leases.

## When to use it

Any code that touches DataStoreService; reports of lost progress, rollbacks or duplicated items; before shipping a migration.

## Disputed facts it flags

The experience write budget appears as 300 or 250 plus a per-player amount on two docs pages, and an old "one write per key every 6 seconds" rule conflicts with the documented per-key throughput. Both are in [[Open Questions - Whole Vault]].

## Notes behind it

[[DataStore Fundamentals]], [[Session Locking and Profile Libraries]], [[Saving Correctly - Autosave and BindToClose]], [[Data Schema Design and Migrations]], [[Schema Migrations - Worked Case Studies]], [[Purchase Data and Receipts]], [[Data Loss Prevention and Recovery]], [[Trading Systems Without Duplication]], [[Debugging DataStore Problems]], [[Cookbook - Data and Saving]], [[Saved Inventory End to End]].

## Related

- [[AI Skills Start Here]]
- [[Skill - Roblox Monetization Compliance]]
- [[Skill - Roblox System Builder]]

## Connected notes
<!-- auto-links:start -->
[[Session Lock]] · Idempotency · [[Skill - Roblox Vault Research]] · Data Schema Versioning · Developer Products and ProcessReceipt · Error Handling and Retries
<!-- auto-links:end -->
