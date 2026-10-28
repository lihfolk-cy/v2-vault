---
cssclasses: [vault-hub]
tags: [index, start, worked-build]
---
# Worked Builds Start Here

The rest of this vault explains systems one concept at a time: how session locking works, why `ProcessReceipt` must be idempotent, what a rate limiter protects. This section does the opposite. Each note starts from an empty place and ends with one complete, working system: the folder layout across `ServerScriptService`, `ReplicatedStorage` and `StarterPlayerScripts`, every script in full, the UI wiring, how to test it in Studio, the exploits it has to resist, and how to extend it.

## How to read these notes

- **All code is marked "reviewed, not run".** It is strict Luau (`--!strict`), written against the documented APIs as of October 2026 and checked by reading, but not executed in that exact form. Treat it as a strong starting point: paste it, press Play, fix the odd typo, and run the test steps in each note before trusting it with players.
- **Server-authoritative throughout.** Clients ask; the server decides. Every remote payload is type-checked, length-capped and rate-limited. No client ever reports a score, a price or a purchase.
- **Safe saving throughout.** Player data goes through one session-locked module. Grants and the records that make them happen-once are written together.
- **The UI is built in code** so each note is complete; you can design it in Studio instead.
- Facts are labelled "Roblox docs (as of October 2026)", "measured in the reference project", or "rule of thumb". Unconfirmed points are marked in the notes.

## The foundation and the data-driven builds

[[Saved Inventory End to End]] comes first. Besides the inventory, it writes the shared pieces the next four builds reuse: the `PlayerData` profile module (lease-based session locking, autosave, `BindToClose`, Studio-only test keys), the `Net` remote helper, the `RateLimiter`, the `DataTemplate` with migrations, and a `Main` bootstrap that starts any service present.

1. [[Saved Inventory End to End]]: stackable and unique items, coins, equip and sell over a validated remote, tools rebuilt from data.
2. [[Daily Rewards System End to End]]: a seven-day streak on server UTC days, missed-day rules, a countdown that ignores the device clock.
3. [[Shop with Game Passes and Developer Products End to End]]: pass ownership as a query, products as an idempotent transaction, live per-player prices, purchases blocked until data loads.
4. [[Codes Redemption System End to End]]: server-only and live codes, normalisation, single use, global limits, brute-force lockout.
5. [[Global Leaderboards End to End]]: all-time and weekly ordered-store boards on a computed request budget, batched names, in-world display, deletion and exclusion paths.

## The gameplay builds

These are written alongside the ones above and stand on their own; each carries whatever data layer it needs, and most pair well with the foundation.

6. [[Round-Based Minigame Loop End to End]]: lobby, intermission, map vote, pluggable minigames, winners and cleanup.
7. [[Pet Hatching and Following End to End]]: eggs with shown odds, server-side rolls, saved pets, client-rendered following.
8. [[Quest Chain System End to End]]: quests as data, server-reported progress, claims and a tracker UI.
9. [[Melee Combat System End to End]]: a combo sword with server hitboxes, blocking, stun and knockback.
10. [[Rebirth and Prestige System End to End]]: two reset layers with closed-form bulk buys and safe saving.

A sensible order: Saved Inventory, then Shop for a first monetisation pass, Daily Rewards and Codes for launch retention, Leaderboards for competition, and the gameplay builds for your core loop.

## What these builds deliberately leave out

They are complete systems, not complete games: no art, sound, onboarding or balance. See [[Core Loops and Session Design]], [[First-Time User Experience and Onboarding]] and [[Balancing with Spreadsheets and Data]]. For security depth, [[Anti-Exploit Start Here]]; for persistence theory, [[Session Locking and Profile Libraries]]; for monetisation policy, [[Monetization Overview]].

## Before you ship any of them

- [ ] Studio API access enabled for testing, and Studio sessions kept off live keys
- [ ] Every test step in the note run, including the failure ones
- [ ] Multi-client test done ([[Multi-Client and Device Playtesting Protocols]])
- [ ] Remotes fuzzed ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]])
- [ ] Release checklist followed ([[QA Checklists Before Release]])

## Two save modules, one idea
The first five builds share the `PlayerData` profile module from [[Saved Inventory End to End]]. The last five each include their own copy of a smaller `PlayerStore` module so every note stands alone. Both do the same job (session lock, autosave, `BindToClose`, kick when loading fails). In a real game, keep one: start from `PlayerData` and port the other builds to it.

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox System Builder]] · [[Genre Systems Start Here]] · [[Tycoon Plots and Droppers End to End]] · [[Idempotency]] · [[Skill - Roblox DataStore Safety]] · [[Genre Playbook - Party and Minigame Collections]]
<!-- auto-links:end -->
