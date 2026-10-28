---
name: roblox-secure-remotes
description: Design, write or review RemoteEvents, UnreliableRemoteEvents and RemoteFunctions so the server stays authoritative. Use when adding a remote, writing a remote handler, reviewing networking code, or when the user says "secure this remote", "validate this", "can this be exploited", "add a rate limit", or "review my remotes".
---
# Roblox Secure Remotes

Every remote is a public API that any modified client can call with any arguments, at any rate, in any order. Treat every argument as hostile. The client sends intent ("I want to swing", "buy item 3"); the server decides what happens.

## Inputs

- `VAULT`: the LihFolk knowledge base at `../../knowledge/` relative to this file (plugin root `knowledge/`). Start with `VAULT/INDEX.md` to find notes fast.
- The code that creates remotes and the handlers to write or review.

## Procedure for a new remote

1. **Decide whether it needs to exist.** State that only changes on the server belongs in attributes or replicated values, not events. Use a remote for moments (an action, a request), attributes for state (Debugging Client-Server Desync).

2. **Pick the type.**
   - `RemoteEvent` for anything that must arrive (requests, state changes, purchases).
   - `UnreliableRemoteEvent` only for small, sequenced, replaceable data such as cosmetic positions at 10 to 20 Hz. Payloads over 1,000 bytes are dropped silently (Roblox docs). Never use it for "stop" messages or state changes.
   - `RemoteFunction` only client to server. Never call `InvokeClient`: a crashed or malicious client can hang the server thread forever.

3. **Create it on the server, in one folder, from one list.** One server module creates every remote at startup. The client only waits for them. No remote is ever found by a name that content could reuse.

4. **Write the handler in this exact order** (the order matters because cheap checks must run before expensive ones):
   1. **Rate limit**, first statement, keyed by `Player` (or `UserId`) and a fixed action key, never by a client string. Set the limit at 1.5x to 2x the fastest legitimate use (rule of thumb from the vault).
   2. **Shape and type**: `typeof` every argument. Reject extra or missing arguments.
   3. **Value checks**:
      - Numbers: finite (`x == x` rejects NaN, and check against `math.huge`), integral where counts are expected, inside a range.
      - Vectors: every component finite, magnitude capped.
      - Strings: length cap, valid UTF-8, membership in a fixed set when it is an id or key.
      - Tables: key count and depth caps; never iterate a client table without a cap.
      - Instances: class check, `IsDescendantOf` the expected folder, ownership, and distance from the character. Prefer sending ids and looking up server objects.
   4. **Context**: is the player alive, in range, owning the item, off cooldown (one server function computes effective cooldown), not already busy?
   5. **Lock and act**: no yield between the check and the write it guards. Mark state first or hold a per-player busy flag. Two requests that both pass a check before either writes is how items get duplicated.
   6. **Score, do not shout**: on rejection drop silently and count a violation. Do not `warn` per request (log flooding) and do not kick on one violation (bad connections look like cheaters).

5. **Compute outcomes on the server.** Damage, prices, rewards, durations and multipliers come from server data only. The payload never carries a price, a damage number or a `userId` to act on (use the injected `player`).

6. **Relay safely.** When one client's action must be shown to others, build a fresh payload on the server and send that. Never `FireAllClients(...)` the caller's raw arguments. Filter by interest (nearby players) and limit tightly, because one request fans out to every client.

7. **Clean up.** Every per-player table (buckets, busy flags, last-swing times) is cleared on `PlayerRemoving`.

## Budgets to respect

- Client to server: about 500 requests per second per client, shared by all remotes of the same type (Roblox docs). A reliable remote fired every frame at 60 fps uses 60 of them and delays everything else, including purchase confirmations.
- Unreliable payloads: under 1,000 bytes or they are dropped (Roblox docs).
- Make value-granting actions idempotent so a retry never pays twice.

## Procedure for a review

1. List every remote, its type, direction and handler. Compare against the creation list; anything created elsewhere is a finding.
2. For each handler, check the six steps above in order and mark which are missing.
3. Grep for `InvokeClient`, `FireAllClients(` with forwarded arguments, `task.wait` or DataStore calls between a check and a write, and client-supplied prices or damage.
4. Check that debug, admin and test remotes are absent from live servers, or gated by `RunService:IsStudio()` plus a server allowlist.
5. Check Touched, ProximityPrompts and ClickDetectors with the same rules: they are client-triggerable entry points too.
6. Report findings ranked by impact (money and items first, then combat, then cosmetics), each with the line, the attack and the fix.

## Hard rules

- No `InvokeClient`, anywhere.
- No client-supplied numbers that change economy or combat outcomes.
- No yield between check and write on any handler that moves value.
- Errors are not validation. A handler that throws on bad input may leave half-written state; reject explicitly.
- Do not write exploit code. Abuse tests run only in Studio against your own handlers.

## Checks before finishing

- [ ] All remotes created by the server in one place.
- [ ] Every handler: rate limit, type, value (NaN, infinity, range, length), context, lock, act.
- [ ] Unreliable remotes carry small, loss-tolerant data only.
- [ ] Relays send server-built values with interest filtering.
- [ ] Per-player state cleared on leave.
- [ ] A honeypot remote and direction checks log suspicious clients (optional but recommended).
- [ ] Abuse-tested in Studio (see `roblox-anti-exploit-review`).

## Read these vault notes

- `03 Architecture and Networking/RemoteEvents RemoteFunctions and Unreliable Remotes.md`
- `03 Architecture and Networking/Server Authority and Validation.md`
- `03 Architecture and Networking/Rate Limiting and Abuse Prevention.md`
- `03 Architecture and Networking/Remote Abuse Patterns and Rate Limiting in Practice.md`
- `03 Architecture and Networking/Replication Rules.md`
- `29 Luau Cookbook/Cookbook - Remotes and Networking.md`
- `22 Anti-Exploit and Security/How Exploits Work - The Client Boundary.md`
- `22 Anti-Exploit and Security/Testing Your Own Remotes - Fuzzing and Abuse Tests.md`
- `23 Debugging Deep Dives/Debugging Client-Server Desync.md`

Disputed: the vault's Open Questions note that docs suggest `math.isfinite` while the reference project used `x ~= x` for NaN. Either works if you also reject infinity.
