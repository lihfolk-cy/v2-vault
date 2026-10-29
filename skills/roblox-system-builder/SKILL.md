---
name: roblox-system-builder
description: 'LihFolk: build a gameplay feature end to end (config, server, client, remotes, saving, UI, tests). Use for "add a system/feature": inventory, shop, quests, pets, rounds, combat, leaderboards.'
---
# LihFolk System Builder

A feature is finished when its decisions are written down, the server owns every outcome, its data survives crashes and server hops, the client only displays and requests, and it has been tested with persistence, failure, two clients and spam. Follow the same shape every time so features fit together.

## Inputs

- `VAULT`: LihFolk Vault V2, the knowledge base at `../../LihFolk Vault V2/` relative to this file (plugin root `LihFolk Vault V2/`). Start with `VAULT/INDEX.md` to find notes fast.
- The feature request and the existing project layout (if any).
- Whether the project already has a data layer, remote helper and rate limiter (the Saved Inventory build provides all three).

## Procedure

1. **Find the closest worked build.** List `24 Worked Builds/` and read the matching note fully before writing code. If none matches, read `24 Worked Builds/Saved Inventory End to End.md`: it is the foundation build whose data layer, remote helper and rate limiter the others reuse. Reuse existing plumbing instead of creating parallel versions.

2. **Write the decisions first.** A short table of the choices that generate support tickets if left implicit. Examples from the builds: what a "day" is (fixed reset at 00:00 UTC plus an offset beats a rolling 24 hours), what happens on a missed day, what happens when the bag is full (refuse the claim so "either everything happened or nothing did"), what is stackable versus unique, and what the client is allowed to know.

3. **Lay out the folders.**
   ```
   ReplicatedStorage/Shared        config, item catalog, remote helper (Net), types
   ServerScriptService/Server      Main (the only server Script), PlayerData,
                                   DataTemplate, RateLimiter, Services/<Feature>Service
   ServerStorage                   things the client must never clone (Tools, secret tables)
   StarterPlayerScripts/Client     one LocalScript or controller per client feature
   ```
   One server `Script` requires modules in a known order; everything else is a `ModuleScript`. Display data (names, icons) is shared; prices, odds and grants are read by the server from its own copy. Secrets never sit in `ReplicatedStorage`. Use `--!strict` and typed exports.

4. **Shared config.** One module describes the content (items, rewards, odds, prices by product key). The server rolls and grants from it; the client only displays it. Odds labels and bonus text are generated from it, never typed by hand. Assert at startup that config is consistent (every reward exists, every odds table sums correctly, every product has a grant).

5. **Server service.**
   - Public functions are plain, testable functions (`Add`, `Remove`, `Claim`, `Equip`) that validate and mutate profile data synchronously, all-or-nothing.
   - Remote handlers are thin: rate limit, type and value checks, then call the service. Follow `roblox-secure-remotes`.
   - No yield between a check and the write it guards.
   - Pure logic (streak rules, day maths, odds rolls) lives in pure functions you can unit-test.
   - Server time comes from `os.time()` or `workspace:GetServerTimeNow()`, never the client.
   - Clear per-player state on `PlayerRemoving`.

6. **Saving.** Use the existing session-locked profile module. If none exists, build it with `roblox-datastore-safety`: `UpdateAsync` with a lease, distinct ready, locked and failed load outcomes, a schema version, staggered autosave below the lease, release on leave, parallel `BindToClose`. Add new fields through the template and reconcile, never by editing old migration steps. Only the data module touches the data store.

7. **Purchases (if any).** Grants go through the single `ProcessReceipt` dispatcher, recorded with the `PurchaseId` in the same write. Prices on screen come from `GetProductInfoAsync`. Paid random items need full odds disclosure and PolicyService gating. Follow `roblox-monetization-compliance`.

8. **Client controller and UI.**
   - The controller listens to server-owned state (attributes or a snapshot remote) and renders it. Labels never show local guesses.
   - Requests are sent as intent; the UI shows the server's answer (`ok`, `TooFast`, `NotOwned`, `BagFull`) with a clear message.
   - Per-entity visuals (pets following, effects) run on clients, culled by distance, with frame-rate independent smoothing.
   - Build UI with `roblox-ui-builder`.

9. **Test in Studio** (the worked builds' sequence):
   1. Enable Game Settings, Security, Enable Studio Access to API Services, and keep Studio on a separate test key or store.
   2. Give yourself content from the command bar through the service's own functions.
   3. Persistence: change state, Stop, Play again; it must still be there.
   4. Fresh profile via a test key attribute.
   5. Simulated load failure: you must be kicked (or play unsaved) and your save untouched.
   6. Lock contention: Play, Stop, Play quickly; the locked path must behave.
   7. Multi-client with two players: one player's actions never leak to the other.
   8. Spam and fuzz the remotes from a Studio-only script: most return `TooFast`, nothing is created from nothing.
   9. Unit-test pure functions (TestEZ or Jest-Lua).

10. **Write the exploits table.** For each attack (unowned ids, NaN or negative counts, long strings, double submit, join a second server before the first saves, local Tool clones, request floods, edited client config), name what stops it. Note what the system does not stop on its own, such as future callers of `Add` without validation.

## Hard rules

- One server Script, one remote creation list, one data writer, one `ProcessReceipt`.
- The client never decides prices, rewards, odds, damage or time.
- No yields between check and write; all-or-nothing grants.
- Studio tests never touch live data.
- All code labelled honestly: say "reviewed, not run" until it has been played.

## Checks before finishing

- [ ] Decisions table written.
- [ ] Folder layout matches the convention; strict types on.
- [ ] Config asserted at startup.
- [ ] Remote handlers rate limited and validated; services synchronous.
- [ ] Data saved through the session-locked module; schema updated.
- [ ] Client renders server state only.
- [ ] Persistence, fresh key, load failure, lock, two-client and spam tests run.
- [ ] Exploits table written.

## Read these vault notes

- `24 Worked Builds/Saved Inventory End to End.md` (foundation)
- `24 Worked Builds/Daily Rewards System End to End.md`
- `24 Worked Builds/Pet Hatching and Following End to End.md`
- `24 Worked Builds/Round-Based Minigame Loop End to End.md`
- `24 Worked Builds/Shop with Game Passes and Developer Products End to End.md`
- `24 Worked Builds/Codes Redemption System End to End.md`
- `24 Worked Builds/Global Leaderboards End to End.md`
- `24 Worked Builds/Quest Chain System End to End.md`
- `24 Worked Builds/Melee Combat System End to End.md`
- `24 Worked Builds/Rebirth and Prestige System End to End.md`
- `03 Architecture and Networking/Project Structure and Bootstrapping.md`
- `03 Architecture and Networking/Server Authority and Validation.md`
- `02 Luau Scripting/Luau Type System and Strict Mode.md`
- `02 Luau Scripting/Module Scripts and Requiring.md`
- `12 Performance Testing and Debugging/Automated Testing with TestEZ and Jest-Lua.md`
- `01 Studio and Workflow/Testing Modes - Play Run and Multi-Client.md`
- `09 Gameplay Systems/Tools and Inventory Systems.md`
