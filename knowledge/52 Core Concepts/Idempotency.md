---
tags: [core-concept, data, purchases, reliability, security]
---
# Idempotency

An operation is **idempotent** when running it twice has the same effect as running it once. "Grant purchase 7f3a" is idempotent if the second call notices the purchase was already granted and does nothing. "Add 100 gems" is not.

## Why it matters on Roblox

Roblox systems retry. `ProcessReceipt` is called again for the same purchase until your callback returns `PurchaseGranted`, including after server crashes and in later sessions (Roblox docs, "Developer products", as of October 2026). DataStore calls fail and get retried. Players double-click buttons, and remotes can arrive twice when a client fires them twice. Any of these turns a non-idempotent grant into duplicated currency, which is the most common way economies break.

## The nuance most people miss

1. **Idempotency needs a stable key.** For purchases the key is `receiptInfo.PurchaseId`. For your own actions (claim daily reward, redeem code, finish quest) you must invent one: `"daily:" .. dayNumber`, `"code:" .. code`, `"quest:" .. questId`. No key, no idempotency.
2. **The key must be saved in the same write as the effect.** Storing "granted 7f3a" in one DataStore key and the gems in another can leave them out of sync if one write fails. Keep processed ids inside the player's profile so a single save commits both.
3. **The ledger must be bounded.** A list of every PurchaseId forever grows without limit. Keep the most recent few hundred, or a map pruned by age; the 4 MB per-key DataStore limit (Roblox docs) is far away but load time is not.
4. **Check-then-act must not yield between the check and the act.** If you read "not claimed", call a yielding function, then write "claimed", a second request can slip into the gap. Do the check and the mark in one non-yielding block, then do slow work.
5. **Return `PurchaseGranted` only after the grant is durable**, meaning the profile with the new PurchaseId is saved or session-locked so it will be.

## Tiny example

```lua
local function grantOnce(profile, key: string, grant: () -> ())
	if profile.Processed[key] then return true end -- already done: same outcome
	profile.Processed[key] = os.time()               -- mark before any yield
	grant()                                          -- mutate the same profile
	return true
end

grantOnce(profile, "daily:" .. math.floor(os.time() / 86400), function()
	profile.Coins += 500
end)
```

## Where this shows up

- [[Developer Products and ProcessReceipt]]: the canonical retried callback.
- [[Purchase Data and Receipts]]: storing the processed-receipt ledger.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: what missing idempotency costs.
- [[Trading Systems Without Duplication]]: two-party idempotent transfers.
- [[Codes Redemption System End to End]]: one key per code per player.
- [[Daily Rewards System End to End]]: day number as the key.
- [[Debugging Race Conditions and Yield Order]]: the check-yield-act gap.
- [[Error Handling and Retries]]: retries are only safe on idempotent work.
- [[Refunds Chargebacks and Purchase Support]]: reconciling when grants did or did not happen.
- [[Saving Correctly - Autosave and BindToClose]]: making the mark durable.
- [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]: firing a remote twice on purpose.
- [[Live Content Pipeline]]: re-running a content publish without double effects.

Related concepts: [[Session Lock]], [[Data Schema Versioning]], [[Server Authority]].

## Connected notes
<!-- auto-links:start -->
[[Shop with Game Passes and Developer Products End to End]] · [[Skill - Roblox DataStore Safety]] · [[Links - Developer products]] · [[Skill - Roblox Monetization Compliance]] · [[Server Authority and Validation]] · [[Battle Pass and Season Design]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
