---
tags: [data, open-cloud, api-keys, automation, datastore, messaging, webhooks, type/guide, area/data, level/advanced, api/HttpService, api/DataStore]
---
# Open Cloud APIs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One all-powerful key used everywhere (A leak exposes every game and permission)
> - Avoid: Unthrottled scripts (Live saves throttled; 429s)
> - Avoid: Editing online players' keys (Edit overwritten, or session marked lost)
> - Separate, minimal-scope keys per tool, experience-restricted, stored in a secret manager.
> - Rate limiter in every script; 429 and `retry-after` handled.
> - Edits only to offline players, logged, reversible.
>
> Cost: TL;DR ~150 tok · whole note ~3.9k tok. Read more: ## The data endpoints · ## Budgets: Open Cloud and your game share them · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Open Cloud is Roblox's public web API: the same data stores, memory stores, messaging, configs, bans, products and places your game uses, reachable from any program that can send HTTPS requests. It turns a Roblox game into something you can operate: support portals that fix a player's inventory, scripts that migrate data, release pipelines that snapshot data and publish places, live-ops dashboards that announce events to every server, and right-to-erasure bots. This note covers authentication, the data-related endpoints, how Open Cloud shares budgets with live servers, rate limiting, webhooks, and operational patterns. Calling Open Cloud from inside a game is in [[HttpService and External APIs]].

All facts as of October 2026 from Roblox's Open Cloud documentation; endpoint lists change, so check the reference before building on a specific one.

## Authentication

| Method | Use it for | Notes |
|---|---|---|
| **API key** | Your own scripts, servers, CI | Created at Creator Dashboard > Credentials. Access = the permissions of the user who owns it, narrowed by the scopes and experiences you select |
| **OAuth 2.0** | Apps other creators or users authorize | Rate limits apply per access token (per user and app) |

API key hygiene (Roblox's recommendations):

- Add only the **scopes** (permissions) the job needs, for example `universe-datastores.objects:read` and `universe-datastores.objects:list` for a read-only support viewer; add `:update` only for the tool that edits.
- Keep **Restrict by Experience** on, selecting only the target games. With it off, the key reaches every game you can access, including future ones.
- **IP restrictions** (CIDR notation, e.g. `192.168.0.0/24`) for keys used from fixed machines. Do **not** IP-restrict keys used from Roblox game servers.
- **Expiration dates** for short-lived jobs; for long-lived automation only with a rotation process, or it fails unexpectedly.
- For group games, create keys on a **dedicated alternate account** that is only in that group with minimal role permissions, so a leak cannot reach your personal games.
- Never commit keys to source control. Use a secret manager; inside Roblox use the secrets store.

## The data endpoints

Base URL for the v2 resources: `https://apis.roblox.com/cloud/v2/`.

| Area | Operations (names as listed in the docs) |
|---|---|
| Data stores | List data stores, **Snapshot data stores**, list / create / get / update / increment / delete entries, list entry revisions (with and without scopes), delete and undelete data stores |
| Ordered data stores | List (sorted), create, get, update, increment, delete entries |
| Memory stores | Create / read / discard queue items; list / create / get / update / delete sorted map items; **flush** a scope |
| Messaging | `PublishUniverseMessage` (the Open Cloud twin of `MessagingService:PublishAsync`) |
| Configs | Read values, drafts (update, overwrite, delete), publish, revisions, restore (repositories `InExperienceConfig`, and `DataStoresConfig` for RTBF templates) |
| Universes and places | Get/update universe, `RestartUniverseServers`, get/update place, publish place versions |
| User restrictions | Ban / unban / list (universe or place) |

Example: a support tool reading and then patching one player's profile (Node.js, following Roblox's own sample).

```javascript
const BASE = 'https://apis.roblox.com/cloud/v2/';
const headers = { 'x-api-key': process.env.ROBLOX_API_KEY };

async function getProfile(universeId, userId) {
  const url = `${BASE}universes/${universeId}/data-stores/PlayerData_v1/entries/User_${userId}`;
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`get ${res.status}`);
  return res.json(); // { path, value, revisionId, ... } (check the reference for the full shape)
}

async function patchProfile(universeId, userId, value) {
  const url = `${BASE}universes/${universeId}/data-stores/PlayerData_v1/entries/User_${userId}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ value }),
  });
  if (!res.ok) throw new Error(`patch ${res.status}: ${await res.text()}`);
}
```

Differences from the engine API that cause bugs:

- **Universe id everywhere**: Open Cloud is stateless.
- **Create and update are separate operations and permissions** (the engine's `SetAsync` does both). A support tool can be allowed to edit existing entries without being able to create new ones.
- **You serialize JSON yourself.** Values written by the engine that contain `inf`, `-inf` or `nan` come back as tagged objects like `{"m": null, "t": "numeric", "v": "inf"}`; handle them or your tool crashes on old data.
- **No `UpdateAsync` transform.** A live server can write between your read and your write. Either only edit keys whose session lease is not live (players offline) or use whatever conditional-update option the reference offers (not verified here). With a fenced session module ([[Session Locking and Profile Libraries]]), editing a key under a live lease makes the next save fail as `lost`, which is safe but disrupts the player: kick them first.

## Budgets: Open Cloud and your game share them

The experience-wide data store limits (`300 + CCU x 40` reads per minute, `300 + CCU x 20` writes, `300 + CCU x 2` list, etc.; see [[DataStore Fundamentals]]) are **shared between game servers and Open Cloud**. A migration script that reads as fast as it can will throttle your live servers' saves, and live peaks will throttle your script. Per-key throughput limits (25 MB/min read, 4 MB/min write) also apply to Open Cloud.

Roblox's advice: Open Cloud has no built-in limiter, so add one.

- **Simple**: wait `60 / desiredRequestsPerMinute` seconds after each request (no bursts).
- **Robust**: a leaky-bucket limiter per operation type (Roblox's sample uses list 5 burst at 1/s, get 10 at 2/s, update 5 at 1/s).
- Run heavy jobs at your lowest-CCU hour; note that budgets scale with CCU, so off-peak budgets are smaller too.

### Rate limit responses

Many responses carry `x-ratelimit-limit`, `x-ratelimit-remaining` and `x-ratelimit-reset`. On HTTP 429, honour `retry-after` if present, else back off exponentially. Roblox warns undocumented limits (abuse protection) may also apply. API key limits are per **owner** (user or group) across all their keys and callers, including in-game `HttpService` calls.

```python
import random, time, requests

def call(method, url, **kw):
    delay = 1.0
    for attempt in range(6):
        r = requests.request(method, url, timeout=30, **kw)
        if r.status_code != 429 and r.status_code < 500:
            return r
        wait = float(r.headers.get('retry-after', delay))
        time.sleep(wait * (0.5 + random.random()))
        delay = min(delay * 2, 60)
    return r
```

## Messaging from outside

`PublishUniverseMessage` delivers to `MessagingService` subscribers in all live servers. Limits are **shared** with in-game messaging: message size 1,024 characters, messages sent per server `600 + 240 x players` per minute, received per topic `40 + 80 x servers` per minute, received for the whole game `400 + 200 x servers` per minute. API key permission: `universe-messaging-service:publish`. Delivery is best effort. Typical uses: announcements, admin commands from a web panel, triggering a live event. For durable state (an event that must be "on" even for servers that miss the message), write a config or data store value and use the message only as a nudge ([[Global State and Live Config]], [[Cross-Server Messaging]]).

## Snapshots before releases

`SnapshotDataStores` snapshots all of a game's data stores; one per day. Roblox recommends taking it **before publishing any update that changes data logic**, because hourly version backups can be overwritten by corrupted writes within the release hour. Put it in your release script:

```bash
# Snapshot (check the reference for the exact method and body; requires a key with the snapshot permission)
curl -X POST "https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores:snapshot" \
  -H "x-api-key: $KEY" -H "Content-Type: application/json" -d '{}'
```

The exact path above follows Roblox's v2 resource naming but was not verified character by character for this note; copy it from the reference. See [[Data Loss Prevention and Recovery]] and [[Release Process and Rollbacks]].

## Webhooks

Creator Dashboard > Webhooks sends Roblox events to your URL. Triggers (October 2026): **Right to Erasure / Deletion Request** and **Transaction Refunded** (developer products, passes, private servers, paid access; not subscriptions). Each payload has `NotificationId`, `EventType`, `EventTime`, `EventPayload`. Configure a **secret**: requests then carry `roblox-signature: t=...,v1=...`, an HMAC-SHA256 (base64) of `timestamp + "." + body`. Verify it and reject old timestamps. Failed deliveries are retried 5 times, then dropped. For group games only the group owner can configure them. Details and verification code: [[Player Privacy and Data Deletion]].

## Operational patterns

| Tool | Endpoints | Safety rules |
|---|---|---|
| **Support portal** (view/fix a player) | Get / update entry, list revisions | Read-only key for viewers; edit key separate; only edit offline players; log every change with who and why; keep the previous revision id |
| **Bulk migration** | List entries (paged), get, update | Snapshot first; rate-limit; skip live leases; idempotent transform; resumable from a cursor |
| **Leaderboard on a website** | List ordered entries | Cache aggressively; it shares the list budget (`300 + 2 x CCU`) |
| **Live-ops panel** | Configs publish, `PublishUniverseMessage` | Two-person review for publishes; configs have revision history and restore |
| **Ban tooling** | User restrictions | Keep reasons and durations; follow policy |
| **RTBF bot** | Delete entries, ordered delete | Signature check; only the user's patterns |
| **CI release** | Snapshot, publish place, restart servers | Snapshot before publish; never on a schedule nobody watches |

Roblox's **Data Stores Batch Processor** (open source CLI) is built for large data store jobs, and Data Stores Manager covers one-off views and reverts. Both are preferable to ad hoc scripts for big operations.

## Worked example: a safe "fix this player" workflow

The most common real use of Open Cloud is customer support: a player reports a lost item, a stuck purchase or a broken quest. A workflow that has held up (rule of thumb, combining Roblox's guidance with the session-locking design in this folder):

1. **Identify** the player by user id (never by display name) and the time of the problem.
2. **Read** the current entry and list its revisions around that time (`ListDataStoreEntryRevisions`). Revisions are roughly one per UTC hour of activity and live 30 days after being superseded ([[DataStore Fundamentals]]).
3. **Check the lease**. If the record's session field shows a live lease, the player is online: ask them to leave, or kick them through an in-game admin command, and wait for the lease to clear. Editing under a live lease either gets overwritten or ends their session.
4. **Decide the change** as a small, explicit diff ("add item X with a new Uid", "restore Coins to the 14:00 value"), not "paste the old profile back", which would also undo legitimate progress since then.
5. **Write** the new value, recording the change inside the profile (`Support = { at, ticket, change }`) so a later investigation sees it, and log it outside too (who, why, before, after).
6. **Verify** by reading the entry again, and in game after the player rejoins (their client may have shown cached UI).

Split the tooling by permission: most support staff need a read-only key (`objects:read`, `objects:list`, revisions); only a few need the update key. Wrapping the API in a small internal web app with its own login is far safer than handing out raw keys.

## Other Open Cloud features worth knowing

- **Luau execution sessions**: run a Luau script against a place version in the cloud and read its logs. Useful for headless tests and data checks in CI ([[Testing Strategies and Frameworks]]); check the reference for limits.
- **Place publishing and universe restarts**: CI can publish a built place file and restart servers (`RestartUniverseServers`), which completes the release pipeline described in [[Release Process and Rollbacks]]. Snapshot data first.
- **Secrets store management**: create and rotate in-game secrets from your deployment scripts instead of the dashboard.
- **Memory store flush**: `POST /cloud/v2/universes/{universeId}/memory-store:flush` with `scope=LIVE` or `TEST`, then poll the returned operation until `done`. It wipes every queue, sorted map and hash map in that scope ([[MemoryStore Service]]).
- **Extended Services**: if legitimate traffic, including your tooling, exceeds the free data store or memory store quotas, paid capacity is available (October 2026 data store prices: $0.08 per 1M get requests, $0.80 per 1M set requests, $0.12 per GB-month of storage over the allowance; requires an ID-verified 18+ owner and a payment method). Reduce and throttle first.

## Common mistakes

| Mistake | Consequence |
|---|---|
| One all-powerful key used everywhere | A leak exposes every game and permission |
| Unthrottled scripts | Live saves throttled; 429s |
| Editing online players' keys | Edit overwritten, or session marked lost |
| Ignoring tagged non-finite numbers | Tool crashes or writes garbage back |
| IP-restricting a key used from Roblox servers | Every in-game call fails |
| Expiring a key used by production automation | Silent failure on the expiry date |
| No snapshot before a data-changing release | Unrecoverable corruption window |

## Checklist

- [ ] Separate, minimal-scope keys per tool, experience-restricted, stored in a secret manager.
- [ ] Rate limiter in every script; 429 and `retry-after` handled.
- [ ] Edits only to offline players, logged, reversible.
- [ ] Snapshot step in the release process.
- [ ] Webhooks with secrets and signature verification.
- [ ] Group automation on a dedicated low-permission account.

## See also
[[HttpService and External APIs]] · [[DataStore Fundamentals]] · [[Data Loss Prevention and Recovery]] · [[Player Privacy and Data Deletion]] · [[MemoryStore Service]] · [[Global State and Live Config]] · [[Release Process and Rollbacks]] · [[Live Ops Events and Updates]] · [[External Tooling - Rojo Wally Selene StyLua]]

## Connected notes
<!-- auto-links:start -->
[[Live Content Pipeline]] · Places Universes and Experience Settings · Links - Open Cloud and external APIs · Debugging DataStore Problems · Refunds Chargebacks and Purchase Support · Links - Cross-server messaging
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Data and Cloud Changes 2025-2026]] · [[Data Schema Design and Migrations]] · [[Saving Correctly - Autosave and BindToClose]] · [[OrderedDataStores and Leaderboards]] · [[Schema Migrations - Worked Case Studies]] · [[Serial-Numbered Limited Items - Atomic Counters]] · [[Purchase Data and Receipts]] · [[Trading Systems Without Duplication]]
<!-- related:end -->
