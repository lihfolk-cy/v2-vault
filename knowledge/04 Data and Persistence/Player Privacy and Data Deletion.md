---
tags: [data, privacy, gdpr, rtbf, right-to-erasure, compliance, webhooks]
---
# Player Privacy and Data Deletion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No templates and nobody reads the daily message (Requests pile up unprocessed; compliance risk)
> - Avoid: Templates for the main store only (Leaderboards, settings, old `_vN` stores still hold the data)
> - Avoid: Webhook without a secret (Anyone can trigger deletions)
> - Inventory of every store, key pattern and external system that holds user ids.
> - Deletion templates for every standard and ordered key pattern, including old stores.
> - Templates tested end to end with a dummy account.
>
> Read more (13 KB note): ## Mechanism 1: automated deletion templates · ## Mechanism 2: the Right to Erasure webhook · ## Common mistakes · ## Checklist
<!-- tldr:end -->

If your game stores anything keyed by user id, you hold personal data, and global privacy laws (GDPR, CCPA, LGPD, PIPA and others) give users the right to have it deleted. Roblox passes those requests to you, and you are responsible for completing them. As of October 2026 Roblox offers three mechanisms: a daily message listing requests, **automated data store deletion templates**, and a **Right to Erasure webhook** for custom automation. This note explains what counts as personal data in a Roblox game, how each mechanism works, how to design keys so deletion is automatic, and the edge cases (scopes, ordered boards, period stores, backups, external services) that templates miss.

This is engineering guidance, not legal advice. For policy context see [[Roblox Policies Ratings and Compliance]].

## What counts as personal data here

Roblox's RTBF page defines personal data broadly: any information relating to an identifiable living person. In practice, in a Roblox game:

| Data | Personal? |
|---|---|
| A profile stored under `User_<userId>` | Yes: the key itself identifies the user |
| Ordered leaderboard entries `u_<userId>` | Yes |
| Gift records naming a buyer and a recipient | Yes, for both users |
| Support reports, chat or moderation logs with user ids | Yes |
| Trade history with counterpart ids | Yes, for both parties |
| Aggregate stats with no user ids ("12,000 swords crafted") | No |
| Data in your own web services (analytics, Discord bots, databases) | Yes, and Roblox's templates cannot reach it |

The webhook guide says it plainly: if you store personally identifiable information, such as user ids, you are responsible for permanently deleting it upon a user request under the applicable frameworks.

## How requests reach you

From Roblox's "RTBF and creators" page (October 2026):

1. **Roblox messages**: Roblox sends an automated message each day to your inbox listing RTBF requests that need action and the affected games. This happens **regardless** of any automation you configure.
2. **Automated data store deletion**: if you configured deletion templates, Roblox deletes matching keys and stores itself when it processes a request.
3. **Creator webhook**: if you configured a webhook with the Right to Erasure trigger, Roblox calls it for affected games, with the user id and the game ids.

Roblox's recommended order: use automated templates for everything they support; use the webhook for the rest (custom logic, unsupported schemas, data outside data stores). You remain responsible for everything; review the daily message and check that data outside your automation is deleted too. The templates page asks you to confirm deletions happen within **30 days** of a request appearing in your messages.

For group-owned games, only the **group owner** receives right-to-erasure requests and can configure webhooks.

## Mechanism 1: automated deletion templates

You declare where user data lives using patterns containing the token `{UserId}` (case-sensitive; `{userId}` is not accepted). Roblox substitutes the requester's id and deletes matches. Limits and rules (Roblox docs):

- Up to **100 templates** per game.
- **Key templates** match keys in a standard or ordered store: data store name, `key_pattern`, optional `scope_pattern` (blank or omitted means `global`).
- **Data store templates** match whole data stores by name pattern, standard stores only (for designs with a store per user).
- Eligibility: the user id must appear in the **name or the scope** of the store or key, in a **static string pattern** such as `User_{UserId}`.

### Configure in Creator Hub

Creator Dashboard > your game > Configurations > Data stores manager > **RTBF Deletion** tab > Create Template > choose Standard Data Store, Standard Key or Ordered Key > enter the pattern > check the sample output > Create. Group games need View Analytics to view configs and Edit and publish experience to edit them, and the editing account must be eligible to publish games.

### Configure with the Configs API

Templates are a JSON config named `user_data_templates` in the `DataStoresConfig` repository of the Open Cloud configs API (the same API family used for experience configs; see [[Global State and Live Config]]). The API key needs `universe:read` and `universe:write`. Flow: overwrite the draft, read it back, publish, read the full config to confirm.

```json
{
  "entries": {
    "user_data_templates": [
      { "key_template": { "data_store_type": "STANDARD", "data_store_name": "PlayerData_v1", "key_pattern": "User_{UserId}", "scope_pattern": "global" } },
      { "key_template": { "data_store_type": "STANDARD", "data_store_name": "Settings_v1", "key_pattern": "User_{UserId}" } },
      { "key_template": { "data_store_type": "ORDERED", "data_store_name": "LB_Coins_v1", "key_pattern": "u_{UserId}", "scope_pattern": "global" } }
    ]
  }
}
```

```bash
BASE="https://apis.roblox.com/creator-configs-public-api/v1/configs/universes/$UNIVERSE_ID/repositories/DataStoresConfig"
curl -X PUT  "$BASE/draft:overwrite" -H "x-api-key: $KEY" -H "Content-Type: application/json" --data @templates.json
curl         "$BASE/draft"           -H "x-api-key: $KEY"
curl -X POST "$BASE/publish"         -H "x-api-key: $KEY" -H "Content-Type: application/json" --data '{"deploymentStrategy":"Immediate"}'
curl         "$BASE/full"            -H "x-api-key: $KEY"
```

Roblox notes that publishing can only be undone by restoring a previous version.

### Testing templates

Roblox's suggestion: build a test game and a dummy account, write dummy data for that account's id, request RTBF for the dummy account, and verify the data disappears once processed. Also compare patterns against your live Luau in the Data Stores Manager before publishing; a typo in a pattern silently deletes nothing.

## Designing keys so templates work

This is the main design lesson: **key patterns are a privacy decision**, made on day one.

| Pattern | Template-friendly? |
|---|---|
| `User_{UserId}` in a fixed store | Yes |
| `u_{UserId}` in an ordered store | Yes (Ordered Key template) |
| `TEST_{name}_{UserId}` (Studio test keys) | Not with a static pattern, because `{name}` varies. Keep test data in a test experience, or delete it yourself when testing ends (Roblox's lifecycle advice too) |
| `{UserId}` alone as a key | Yes, but collides with other uses; prefer a prefix |
| Store per period, `LB_Week_{N}` with keys `u_{UserId}` | One template per store name; new period stores need new templates. Prefer few long-lived stores, or delete old period stores entirely |
| Keyed by `PurchaseId` with user ids inside the value | No: the id is not in the key. Use the webhook path |
| One shared key holding many users (a guild roster, a trade log) | No: needs custom logic to remove one user's entries |
| Display names in keys | Never (also not stable) |

Roblox's best-practices page connects the two explicitly: static key patterns are what let automated RTBF processing identify player data.

Every account reset that renames stores (`_v5` to `_v6`, a common pattern; see [[Data Schema Design and Migrations]]) leaves the old stores holding personal data. Either add templates for old store names too, or delete old stores once you no longer need the rollback option.

## Mechanism 2: the Right to Erasure webhook

For data the templates cannot reach. Setup (Roblox docs):

1. Creator Dashboard > Webhooks: add your endpoint URL, a **secret**, and select **Right to Erasure Request** under triggers. Use **Test Response** to receive a `SampleNotification`.
2. Your endpoint receives a POST:

```json
{
  "NotificationId": "string",
  "EventType": "RightToErasureRequest",
  "EventTime": "2023-12-30T16:24:24.2118874Z",
  "EventPayload": { "UserId": 1, "GameIds": [1234, 2345] }
}
```

3. **Verify the signature.** With a secret configured, Roblox sends header `roblox-signature: t=<timestamp>,v1=<signature>`. Recompute `base64(HMAC-SHA256(secret, timestamp + "." + rawBody))` and compare; also reject old timestamps to stop replays. Without a secret anyone who learns the URL can trigger deletions of arbitrary users' data.
4. Delete the user's data with Open Cloud (API key with data store Delete Entry permission, and ordered store Write permission if you delete ordered entries), in your own databases, and in any third-party tools.
5. Failed deliveries are retried **5 times** and then dropped, so log every request you receive and alert on failures; the daily message is your backstop.

Roblox's tutorial wires the webhook to a private Discord server with a bot; any HTTPS endpoint works. A minimal verification sketch (Node.js, mirroring the official sample):

```javascript
const crypto = require('crypto');
function verify(req, rawBody, secret, maxAgeSeconds = 600) {
  const parts = Object.fromEntries((req.headers['roblox-signature'] || '').split(',')
    .map(p => [p.slice(0, p.indexOf('=')), p.slice(p.indexOf('=') + 1)])); // base64 may end in '='
  if (!parts.t || !parts.v1) return false;
  if (Math.abs(Date.now() / 1000 - Number(parts.t)) > maxAgeSeconds) return false; // replay window
  const expected = crypto.createHmac('sha256', secret).update(`${parts.t}.${rawBody}`).digest('base64');
  const a = Buffer.from(expected), b = Buffer.from(parts.v1);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
```

The payload lists **game ids** the user played; map them to your universes and only touch those games' data.

## Deleting correctly

Know what "delete" means for each store type (Roblox docs):

| Store | Delete call | What remains |
|---|---|---|
| Standard data store key | `RemoveAsync` / Open Cloud Delete Entry | A tombstone version; older versions readable through version APIs until they expire. "Removed objects will be deleted permanently after 30 days" |
| Ordered data store key | `RemoveAsync` / Delete Ordered Entry | Nothing; deleted permanently (no versions) |
| Whole standard data store | Data Stores Manager or Open Cloud delete | Inaccessible immediately; restorable during a 30-day buffer, then permanently deleted |
| Memory store items | Remove calls, or let TTL expire (max 45 days) | Nothing after expiry |
| Your external systems | Your code | Whatever you forgot: backups, logs, analytics exports |

Before deleting, make sure no live session will write the data back: if the player is somehow online in an old server, its next save recreates the key. In practice RTBF requests come from deleted accounts, so this is rare, but your deletion tool should still go through the lease-aware path (or simply be re-run).

Partial deletion inside shared records (a guild roster, a trade log, a gift ledger record that names the user as recipient): rewrite the record without that user's id. Prefer designs that avoid storing other users' ids long-term: keep the newest N trades, expire gift ledgers after the purchase is resolved, and keep support reports for a fixed period.

## Collect less in the first place

- Do not store data you will not use. "Last 1,000 matches with opponents" is personal data about 1,000 other people.
- Use user ids, never usernames or display names, in stored data; names can be looked up when displayed.
- Pass the `userIds` array when writing standard store keys that belong to a user. Roblox calls it "highly recommended to assist with GDPR tracking/removal", and it helps you find the user's keys with tooling.
- Never send player data to external services you do not control or cannot delete from ([[HttpService and External APIs]]). Every external analytics or logging tool joins your deletion obligations.
- Free-text from players (bios, pet names, reports) is especially sensitive; filter it on input with `TextService` and store as little as possible ([[Roblox Policies Ratings and Compliance]]).

## Common mistakes

| Mistake | Consequence |
|---|---|
| No templates and nobody reads the daily message | Requests pile up unprocessed; compliance risk |
| Templates for the main store only | Leaderboards, settings, old `_vN` stores still hold the data |
| Webhook without a secret | Anyone can trigger deletions |
| Webhook returns errors silently | After 5 retries the notification is gone |
| Key patterns with variable parts | Cannot be matched by templates |
| Thinking `RemoveAsync` is instant erasure | Versions remain until they expire (30 days) |
| External analytics keyed by user id with no deletion path | Data you cannot erase |

## Checklist

- [ ] Inventory of every store, key pattern and external system that holds user ids.
- [ ] Deletion templates for every standard and ordered key pattern, including old stores.
- [ ] Templates tested end to end with a dummy account.
- [ ] Webhook with a secret, signature check, logging and alerting for custom data.
- [ ] Someone reviews the daily message; deletions confirmed within 30 days.
- [ ] Period stores and test data cleaned up on a schedule.
- [ ] Shared records avoid long-term storage of other users' ids.

## See also
[[DataStore Fundamentals]] · [[OrderedDataStores and Leaderboards]] · [[Open Cloud APIs]] · [[HttpService and External APIs]] · [[Roblox Policies Ratings and Compliance]] · [[Age Checks and Safety Features]] · [[Data Schema Design and Migrations]]

## Connected notes
<!-- auto-links:start -->
[[Links - Open Cloud and external APIs]] · [[Refunds Chargebacks and Purchase Support]] · [[Links - Session locking and data safety]] · [[Cookbook - Data and Saving]] · [[Logging Bans and Appeals]] · [[Crash and Error Telemetry]]
<!-- auto-links:end -->
