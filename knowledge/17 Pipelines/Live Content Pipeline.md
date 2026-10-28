---
tags: [pipelines, live-ops, events, live-config, open-cloud, changelog, documentation]
---
# Live Content Pipeline

A live game changes between publishes: a weekend event starts, the shop rotates, a promo code goes live, a broken feature is switched off, a bonus is announced to every server. If each of those needs a code change and a publish, live operations become slow and risky. This note is the pipeline for **content that changes while the game is running**: what can be live and what must ship in a build, how to push data to running servers safely with Open Cloud, how to schedule events, and the record keeping (changelogs, decision logs, notes) that lets a small team run a live game without losing track. Design of events is in [[Live Ops Events and Updates]]; the runtime config mechanism is in [[Global State and Live Config]]; cross-server messaging in [[Cross-Server Messaging]] and [[MemoryStore Service]].

## What can change live, and what cannot

Roblox servers run the code and assets of the place version they started with. You cannot push new code or new instances to a running server. You **can** push data. So the rule is:

| Ship in the build (publish) | Change live (data) |
|---|---|
| all code, including event logic | which event is active, start and end times |
| all models, UI, sounds, VFX the event uses | multipliers, odds boosts, prices within limits |
| default values for every live setting | shop rotation lists (from items already in the build) |
| kill switch code paths | kill switch states |
| new items' definitions | which items are purchasable or droppable right now |
| translations | announcement text keys (and arguments) |

Practical consequence: **an event is shipped dormant in an earlier build and woken up by data**. Build it, publish it behind a flag, test it in the live game with the flag on for a test group or a private server, then flip it on for everyone at the scheduled time.

## The pieces

| Piece | Mechanism | Notes |
|---|---|---|
| Live config document | a DataStore entry (versioned JSON) | durable; read at server start and refreshed |
| Fast fan-out | MessagingService topic | tell running servers "config changed, re-read now" |
| Shared fast state | MemoryStore (sorted maps, queues, hash maps) | cross-server counters, global event progress |
| Push from outside | Open Cloud Data Stores and Messaging APIs | your tools and CI can change config without Studio |
| Defaults | shipped in the build | the game must work if the live document is missing or invalid |
| Schedules | times in UTC in the config | servers compute state from the clock, not from a message |

## Stage 1: the live config document

One JSON document (or a few, by area), with a **schema version**, a **revision number**, and only data:

```json
{
  "schema": 3,
  "revision": 41,
  "updatedBy": "liveops-tool",
  "flags": { "ultCinema": true, "mutations": false, "rarityLocks": false },
  "events": [
    { "id": "void_rift", "startsAt": "2026-10-31T18:00:00Z", "endsAt": "2026-11-02T18:00:00Z",
      "params": { "spawnEveryMin": 20, "lobbySec": 45 } }
  ],
  "shop": { "rotation": ["sword_iron", "sword_moon"], "rotatesAt": "2026-10-27T00:00:00Z" },
  "boosts": { "luck": 1.0, "cash": 1.0 },
  "announce": { "key": "announce.weekend_luck", "args": { "mult": 2 }, "until": "2026-10-28T00:00:00Z" }
}
```

Server-side loader with validation, defaults and caching:

```lua
--!strict
-- LiveConfig (server). Reads a versioned JSON document, validates it, falls back to defaults.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local STORE = DataStoreService:GetDataStore("LiveConfig")
local KEY = "main"
local TOPIC = "LiveConfigChanged"
local REFRESH_SEC = 120

local DEFAULTS: any = { -- any: validated by hand below
	schema = 3, revision = 0,
	flags = { ultCinema = true, mutations = false, rarityLocks = false },
	events = {}, shop = { rotation = {} }, boosts = { luck = 1, cash = 1 },
}

local LiveConfig = { current = DEFAULTS, changed = Instance.new("BindableEvent") }

local function clampBoost(v: any): number
	return if type(v) == "number" and v == v then math.clamp(v, 0.5, 5) else 1 -- hard limits in code
end

local function validate(doc: any): any?
	if type(doc) ~= "table" or doc.schema ~= DEFAULTS.schema or type(doc.revision) ~= "number" then
		return nil
	end
	local out = table.clone(DEFAULTS)
	out.revision = doc.revision
	out.flags = table.clone(DEFAULTS.flags)
	if type(doc.flags) == "table" then
		for k, v in doc.flags do
			if DEFAULTS.flags[k] ~= nil and type(v) == "boolean" then out.flags[k] = v end -- known flags only
		end
	end
	out.boosts = { luck = clampBoost(doc.boosts and doc.boosts.luck), cash = clampBoost(doc.boosts and doc.boosts.cash) }
	out.events = if type(doc.events) == "table" then doc.events else {}
	out.shop = if type(doc.shop) == "table" then doc.shop else DEFAULTS.shop
	out.announce = doc.announce
	return out
end

local function load()
	local ok, raw = pcall(function()
		return STORE:GetAsync(KEY)
	end)
	if not ok or raw == nil then return end -- keep what we have
	local decoded = if type(raw) == "string" then select(2, pcall(HttpService.JSONDecode, HttpService, raw)) else raw
	local doc = validate(decoded)
	if doc and doc.revision > LiveConfig.current.revision then
		LiveConfig.current = doc
		LiveConfig.changed:Fire(doc)
	elseif not doc then
		warn("LiveConfig: invalid document ignored")
	end
end

task.spawn(function()
	load()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function()
			task.wait(math.random() * 5) -- spread re-reads so 500 servers do not read at once
			load()
		end)
	end)
	while true do
		task.wait(REFRESH_SEC)
		load()
	end
end)

return LiveConfig
```

Design points:

- **Unknown fields are ignored, known fields are type-checked, numbers are clamped in code.** A typo in the document can never set luck to 1000x.
- **Revisions only move forward.** A stale cached read cannot roll the game back.
- **Messaging is a hint, polling is the guarantee.** Messages can be missed; the periodic refresh catches up.
- **Jitter** on re-reads protects DataStore limits when many servers react to one message.
- `GetAsync` results are cached by the engine for a few seconds (the reference project measured about 4 s); when verifying a write from a tool inside the game, read with caching disabled (`DataStoreGetOptions.UseCache = false`).

## Stage 2: schedules are computed, not triggered

Do not "start the event" by sending a message at 18:00. Servers that start at 18:05 would miss it, and a dropped message means some servers never start. Put `startsAt` and `endsAt` in the config (UTC) and let every server compute the state from its clock:

```lua
local function isLive(ev: { startsAt: string, endsAt: string }): boolean
	local ok1, s = pcall(DateTime.fromIsoDate, ev.startsAt)
	local ok2, e = pcall(DateTime.fromIsoDate, ev.endsAt)
	if not (ok1 and ok2 and s and e) then return false end
	local now = DateTime.now().UnixTimestampMillis
	return now >= s.UnixTimestampMillis and now < e.UnixTimestampMillis
end
```

The reference project's daily systems used UTC resets throughout (free gifts by play time with a UTC daily reset; daily rewards), and its timed world event carried an explicit end time (`EndsAt`) that clients used to hide the invitation a second after it passed. Times as data, computed everywhere, is what makes that robust.

## Stage 3: pushing changes from outside the game

With Open Cloud your live-ops tool (a script, a small web panel, a CI job) can change config without opening Studio (Roblox docs, as of October 2026):

| Action | Endpoint | Key permission |
|---|---|---|
| list entries | `GET https://apis.roblox.com/cloud/v2/universes/{universe}/data-stores/{dataStore}/entries` | `universe-datastores.objects:list` |
| read an entry | `GET https://apis.roblox.com/cloud/v2/<entry path from the list>` | `universe-datastores.objects:read` |
| update an entry | `PATCH` the entry path with a JSON body `{ "value": ... }` | `universe-datastores.objects:update` (create is a separate permission) |
| tell servers | `POST https://apis.roblox.com/cloud/v2/universes/{universe}:publishMessage` with `{ "topic": ..., "message": ... }` | messaging service, `universe-messaging-service:publish` |

Messaging limits from the guide: topic names up to 80 characters, messages up to 1,024 characters; the guide also says topics are currently defined in Studio first, and servers receive messages with `MessagingService:SubscribeAsync`.

```python
# tools/liveops.py : bump the live config safely, then notify servers.
# Usage: py -I tools/liveops.py set boosts.luck 2.0
import json, os, sys, requests

U = os.environ["RBX_UNIVERSE_ID"]
H = {"x-api-key": os.environ["RBX_LIVEOPS_KEY"], "Content-Type": "application/json"}
BASE = "https://apis.roblox.com/cloud/v2"
ENTRY = f"universes/{U}/data-stores/LiveConfig/entries/main"   # check against the path the list call returns

def get():
    r = requests.get(f"{BASE}/{ENTRY}", headers=H, timeout=30); r.raise_for_status()
    v = r.json()["value"]
    return json.loads(v) if isinstance(v, str) else v

def put(doc):
    r = requests.patch(f"{BASE}/{ENTRY}", headers=H, json={"value": doc}, timeout=30); r.raise_for_status()

def notify(rev):
    r = requests.post(f"{BASE}/universes/{U}:publishMessage", headers=H,
                      json={"topic": "LiveConfigChanged", "message": json.dumps({"revision": rev})}, timeout=30)
    r.raise_for_status()

def set_path(doc, dotted, value):
    node = doc
    *parents, leaf = dotted.split(".")
    for p in parents:
        node = node.setdefault(p, {})
    node[leaf] = value

if __name__ == "__main__":
    _, cmd, path, raw = sys.argv
    doc = get()
    before = json.dumps(doc, sort_keys=True)
    set_path(doc, path, json.loads(raw))
    doc["revision"] = int(doc.get("revision", 0)) + 1
    doc["updatedBy"] = os.environ.get("USER") or os.environ.get("USERNAME") or "liveops"
    print("diff:", path, "->", raw, "| revision", doc["revision"])
    if input("apply? [y/N] ").strip().lower() != "y":
        sys.exit("aborted")
    open(f"liveconfig_rev{doc['revision'] - 1}.json", "w").write(before)   # local backup of the old doc
    put(doc); notify(doc["revision"])
    print("done")
```

Safety rules for live pushes:

- **Validate before writing** with the same schema the game uses (share it; generate both from one definition if you can).
- **Show the diff and confirm.** A live-ops tool that writes without a confirmation step will eventually write the wrong thing.
- **Back up the previous document** (the script writes the old revision to disk), so rollback is one push.
- **Least privilege keys**: the live-ops key can update the config store only (keys can be restricted to one data store), not player data.
- **Race**: two people editing at once can overwrite each other; serialise pushes through one tool or use the API's concurrency features (check the reference for conditional updates).

## Stage 4: rolling out gradually

For risky toggles, roll out by percentage of servers or players instead of all at once: a `rollout` number in the config and a stable hash of the server's `JobId` or the player's `UserId` deciding who gets it. Watch metrics at 10%, then go to 100%. This is the live equivalent of the staging play test in [[Build Test and Release Pipeline]].

```lua
local function inRollout(userId: number, percent: number, salt: string): boolean
	-- stable per user and feature: the same player stays in or out across servers
	local h = 0
	for i = 1, #salt do h = (h * 31 + string.byte(salt, i)) % 2^31 end
	h = (h * 31 + userId) % 1000
	return h < percent * 10
end
```

## Stage 5: codes, limited items and announcements

- **Codes** live in config or a dedicated store with `{ code, reward, expiresAt, maxUses }`; redemption is server-side, idempotent per player (record redeemed codes in the profile), and global use counts go through MemoryStore or an atomic DataStore update. See [[Menu Archetypes - Shop Settings Codes Rewards]].
- **Limited items** are defined in the build and enabled by config; the purchase path checks the live window on the server.
- **Announcements** send a **localization key and arguments**, not English text, so each client shows it in its language ([[Localization Pipeline]]). Respect the player's attention: the reference project gated every automatic pop-up through one rule (never during onboarding, never in combat or over another panel, at least 8 seconds after another pop-up).

## Stage 6: the record: changelogs, decisions and notes

Live games are run from their records. The reference project, a game built by one owner with several AI agents in parallel, kept a record system that is worth copying in any team:

| Record | Format | Rule |
|---|---|---|
| **Dated changelog** | one note per day plus an index; each entry has a **TAG**, what changed, where the backup is, and the verification status | written at the end of every change, not at the end of the week |
| **Decisions log** | date, decision, who decided, why | so the same argument is not had twice |
| **Pending decisions** | open questions waiting for the owner | so agents and teammates do not decide them silently |
| **Known issues** | symptom, cause if known, workaround | read before any bug hunt |
| **Rules and gotchas** | short imperative lists (working rules, tooling gotchas, who owns what) | the first thing every new person or agent reads |
| **System notes** | one note per system (combat, audio, UI...) | updated when the system changes |
| **Generated reference** | notes generated from a data dump of the live place (items, zones, enemies) | regenerated, never hand-edited |

Tags tie it together: the same tag (`FREE-GIFTS`, `LEVELS-2`, `HUB-HERO`) appears in the changelog, in code comments around the change ("-- AUTO-ANIM begin/end"), in attribute names for backups (`PreFreeGifts_Name`), and in commit messages. Months later, one search finds the code, the backup and the reason.

Two habits made the difference:

1. **Status honesty.** Entries say "Edit only, not play-tested", "publish to ship", or "not done / weak: ..." when that is the truth. Release leads read statuses ([[Build Test and Release Pipeline]]).
2. **Supersession, not deletion.** When a later change replaces an earlier one, the old entry is marked superseded with a pointer ("look superseded by FLAT-WALLS below"), and a rule line says which wins ("2026-10-20 standard wins over everything below"). The history stays readable and nobody follows a dead instruction.

See [[Documentation and Knowledge Bases]] for structuring the knowledge base itself.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Event never started on some servers | started by a message | schedules in config, computed from the clock |
| A typo set a boost to 100x | no validation or clamps | schema validation in the tool and the game; clamps in code |
| Config change rolled back by itself | stale cached read overwrote newer state | revision numbers only move forward |
| DataStore throttling after a push | every server re-read at once | jitter on message-triggered reloads |
| Event content missing | assets not in the build | ship dormant content in an earlier publish |
| Nobody knows why a flag is off | no decision record | decisions log and changelog tags |
| A teammate redid a reverted change | old notes still read as current | supersession markers in notes |

## Checklist

- [ ] Everything an event needs is in a published build, behind a flag
- [ ] Live config document with schema, revision and defaults in the build
- [ ] Server validation, clamps and forward-only revisions
- [ ] Schedules as UTC times computed on every server
- [ ] Messaging as a hint plus periodic refresh with jitter
- [ ] Live-ops tool: validate, diff, confirm, back up, push, notify
- [ ] Least-privilege keys; one tool serialises pushes
- [ ] Gradual rollout for risky toggles
- [ ] Changelog with tags and honest statuses; decisions, pending, known issues kept

## See also

[[Global State and Live Config]] · [[Live Ops Events and Updates]] · [[Open Cloud APIs]] · [[Cross-Server Messaging]] · [[MemoryStore Service]] · [[DataStore Fundamentals]] · [[Build Test and Release Pipeline]] · [[Documentation and Knowledge Bases]] · [[Retention and Return Hooks]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Links - Cross-server messaging]] · [[Codes Redemption System End to End]] · [[Live Ops Deep Dive Start Here]] · [[Feature Flags]] · [[Places Universes and Experience Settings]] · [[Feature Flags and Staged Rollouts]]
<!-- auto-links:end -->
