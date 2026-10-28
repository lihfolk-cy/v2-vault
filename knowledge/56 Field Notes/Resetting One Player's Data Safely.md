---
tags: [field-notes, datastore, data, reset, support, versioning, live-ops, luau]
---
# Resetting One Player's Data Safely

<!-- tldr:start -->
> [!tldr] TL;DR
> - Reset did nothing: Player was online; session save wrote the old data back -> Kick, wait for lock release, then remove
> - Some progress survived: A second store or key format missed -> Find every store and key format in code
> - Old data came back on next join: Legacy migration read an old store -> Check the load path for legacy reads
> - Stores and key formats listed from code, including legacy reads.
> - Player kicked from all servers; session lock released.
> - Current values dumped to disk before removal.
>
> Cost: TL;DR ~170 tok · whole note ~1.6k tok. Read more: ## 1. Find the exact stores and key formats in code · ## 3. Remove with RemoveAsync, which is recoverable · ## Common mistakes · ## Checklist
<!-- tldr:end -->

"Please reset my data" (or a tester who needs a fresh account, or a corrupted profile) sounds like one `RemoveAsync`. In a real game it is several stores with different key formats, a session system that will happily write the old data back, and purchase records that must not be touched. Done carelessly, the reset either does nothing (the next save restores everything) or does too much (the player is re-granted purchases). This note is the procedure that worked. Foundations: [[DataStore Fundamentals]], [[Session Locking and Profile Libraries]]; deletion requests: [[Player Privacy and Data Deletion]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Find the exact stores and key formats in code

Do not guess. Search every script for `GetDataStore(`, `GetOrderedDataStore(` and the profile library's store name, and note for each:

- the **store name** (and scope, if one is passed),
- the **key format** (`"Player_" .. userId`, `tostring(userId)`, `"u" .. userId .. "_v3"`),
- what the store holds (profile, inventory, settings, leaderboard stats, **purchase receipts**).

**Measured.** The reference project's resets started with exactly this search; a large game accumulates several stores and key formats over time, and a reset that clears only the main profile leaves the rest behind.

Old versions of the save code matter too: a migration may still read a legacy store and "restore" from it if the new key is missing. Check the load path, not just the save path.

## 2. The player must not be in a live server

Session-based saving keeps the player's data in server memory and writes it on autosave and on leave ([[Saving Correctly - Autosave and BindToClose]]). If you remove the key while they are online, the next autosave or their leave writes the cached old data straight back. The reset silently does nothing.

So, in order:

1. Make sure the player has left every live server. If they are online, kick them (for example through a `MessagingService` topic that every server listens to and that calls `Player:Kick` for that user id).
2. Wait for the session lock to be released, or for longer than its expiry if the server crashed.
3. Then remove.

## 3. Remove with RemoveAsync, which is recoverable

For standard data stores, `GlobalDataStore:RemoveAsync(key)` removes the key and returns the old value (Roblox docs). With data store versioning, the removal creates a deletion marker and earlier versions stay retrievable for a limited period (about 30 days per Roblox docs) via `ListVersionsAsync` and `GetVersionAsync`. That makes a mistaken reset recoverable. Prefer it to overwriting with an empty table, which makes the "before" harder to find.

```lua
-- Server context with DataStore access (a Studio session with API access, or a server admin command).
local DataStoreService = game:GetService("DataStoreService")

local userId = 0 -- set this
local targets = {
	-- Fill from the code search; never from memory.
	{ store = "PlayerProfiles", key = "Player_" .. userId },
	{ store = "Inventory_v2", key = tostring(userId) },
	{ store = "Settings", key = "u" .. userId },
	-- Purchase receipts / processed-purchase stores are deliberately NOT listed.
}

for _, t in targets do
	local store = DataStoreService:GetDataStore(t.store)
	local ok, oldValue = pcall(store.RemoveAsync, store, t.key)
	print(t.store, t.key, if ok then (oldValue ~= nil and "removed" or "was empty") else ("FAILED: " .. tostring(oldValue)))
	task.wait(0.5) -- stay inside request budgets
end
```

Before running it, print the current value of each key with `GetAsync` and save the output to disk. That is your own backup, independent of versioning.

`OrderedDataStore` entries (leaderboards) are separate and are not versioned. Remove the player's entries from each leaderboard store explicitly if the reset should clear rankings.

**Studio warning:** a Studio session with API access enabled talks to the **live** data stores of the experience (Roblox docs). A reset run from Studio is a real reset.

## 4. Leave receipts and purchase records intact

Stores that record processed purchases (the idempotency records your `ProcessReceipt` handler checks) and any purchase history must survive the reset. If you remove them:

- A receipt that Roblox retries (for example after a server crashed mid-grant) finds no record, and your handler grants it again ([[Developer Products and ProcessReceipt]]).
- You lose the evidence needed for support and refunds.

Decide what the player keeps after a reset (usually permanent purchases and game passes, which are owned on the platform anyway) and make the profile loader re-grant those from ownership checks, not from the deleted profile.

## 5. Verify

After the removal, have the player (or the tester account) join. Confirm the fresh profile was created, permanent purchases are present, and no legacy store restored old data. Then log the reset with date, user id, stores touched, and who requested it.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Reset did nothing | Player was online; session save wrote the old data back | Kick, wait for lock release, then remove |
| Some progress survived | A second store or key format missed | Find every store and key format in code |
| Old data came back on next join | Legacy migration read an old store | Check the load path for legacy reads |
| Purchases granted twice | Receipt records removed | Never touch receipt or purchase stores |
| Reset cannot be undone | Overwrote with an empty table, no backup | `RemoveAsync` plus a `GetAsync` dump first |

## Checklist

- [ ] Stores and key formats listed from code, including legacy reads.
- [ ] Player kicked from all servers; session lock released.
- [ ] Current values dumped to disk before removal.
- [ ] `RemoveAsync` per key; ordered stores handled explicitly.
- [ ] Receipt and purchase stores untouched; permanent purchases re-granted from ownership.
- [ ] Fresh join verified and the reset logged.

## Connected notes
<!-- auto-links:start -->
[[DataStore Fundamentals]] · [[Session Locking and Profile Libraries]] · [[Player Privacy and Data Deletion]] · [[Debugging DataStore Problems]] · [[Developer Products and ProcessReceipt]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
