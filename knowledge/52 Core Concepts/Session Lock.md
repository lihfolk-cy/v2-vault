---
tags: [core-concept, data, datastore, persistence]
---
# Session Lock

A **session lock** is a marker in a player's saved data that says "server X owns this profile right now". Only the owning server may write the profile; other servers wait, retry or refuse until the lock is released or expires.

## Why it matters on Roblox

A player can be in two servers at once for a few seconds: teleporting between places, rejoining quickly after a crash, or joining a friend while the old server is still running `BindToClose`. Without a lock, both servers load the same data, both modify it, and whichever saves last overwrites the other. Depending on order that is lost progress or duplicated items (sell in server A, keep in server B). DataStoreService has no built-in lock (Roblox docs, as of October 2026); you build it with `UpdateAsync` or use a profile library that does.

## The nuance most people miss

1. **The lock is only as good as the write that takes it.** Taking a lock with `GetAsync` then `SetAsync` is a race. Use `UpdateAsync`, whose transform function sees the latest value and can refuse.
2. **Locks need expiry.** A server that crashes never releases. Store a timestamp with the owner id and treat a lock older than a few autosave intervals (rule of thumb: 2 to 5 minutes, longer than your autosave period) as stale.
3. **Expiry has a trade-off.** Too short and a slow but alive server loses its lock mid-session (a duplicate source). Too long and players who crashed wait on join. Most teams refresh the lock on every autosave and pick an expiry of about three autosave periods.
4. **Releasing is a write too.** On leave, the final save and the release should be the same `UpdateAsync` call, so there is no window where data is saved but still locked or unlocked but unsaved.
5. **MemoryStore is not a substitute for the saved lock** on its own: it expires and is not durable. It can speed up handoffs, but the DataStore record is the source of truth.

## Tiny example

```lua
local SERVER_ID = game.JobId
store:UpdateAsync(key, function(old)
	old = old or { Data = DEFAULT(), Lock = nil }
	local lock = old.Lock
	if lock and lock.Owner ~= SERVER_ID and os.time() - lock.Time < 300 then
		return nil -- someone else owns it: cancel the write
	end
	old.Lock = { Owner = SERVER_ID, Time = os.time() }
	return old
end)
```

Returning `nil` from the transform cancels the update (Roblox docs, `UpdateAsync`).

## Where this shows up

- [[Session Locking and Profile Libraries]]: the full design and the libraries that implement it.
- [[DataStore Fundamentals]]: UpdateAsync semantics and limits.
- [[Saving Correctly - Autosave and BindToClose]]: release on shutdown.
- [[Teleporting and Multi-Place Games]]: the most common double-session window.
- [[Session State Across Places]]: carrying state while the lock moves.
- [[Data Loss Prevention and Recovery]]: what to do when a lock went wrong.
- [[Debugging DataStore Problems]]: stuck locks and their symptoms.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: dupes that rely on two sessions.
- [[Server Shutdowns Soft Updates and Migration]]: mass handoffs during updates.
- [[Saved Inventory End to End]]: a worked inventory on a locked profile.
- [[Skill - Roblox DataStore Safety]]: a review checklist that includes locks.
- [[MemoryStore Service]]: fast, expiring state that complements the lock.

Related concepts: [[Idempotency]], [[Data Schema Versioning]], [[Rate Limiting]].

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Data and Saving]] · [[Multiplayer Services Start Here]] · [[Links - DataStoreService]] · [[Trading Systems Without Duplication]] · [[Purchase Data and Receipts]] · [[Codes Redemption System End to End]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
