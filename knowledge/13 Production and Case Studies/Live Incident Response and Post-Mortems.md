---
tags: [production, live-ops, incidents, rollback, post-mortem, kill-switch, datastore, communication]
---
# Live Incident Response and Post-Mortems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hunting the bug while the bug keeps corrupting data.
> - Avoid: No kill switches, so the only containment is a full rollback.
> - Avoid: Fixing forward with an untested hot fix instead of rolling back.
> - Severity assigned in the first five minutes; data and Robux issues start at SEV1.
> - Containment applied (flag, read-only saves, prompts off, rollback, restart).
> - Timeline started immediately with incident start time.
>
> Read more (19 KB note): ## 3. Containment: stop the bleeding before you understand it · ## 7. The post-mortem · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Something is wrong in the live game: players say their coins vanished, the shop takes Robux and gives nothing, a boss cannot be damaged, servers crash every ten minutes. [[Release Process and Rollbacks]] lists the rollback tools and [[Crash and Error Telemetry]] shows how to see errors. This note is about the hour when you need them: how to judge severity, contain the damage before you understand it, fix it, talk to players, and then learn from it with a post-mortem that changes something.

The order matters. Teams lose the most when they skip straight to "find the bug" while the bug keeps doing damage.

```
Detect -> Assess -> Contain -> Diagnose -> Fix -> Recover players -> Communicate -> Post-mortem
```

---

## 1. Severity first

Decide severity in the first five minutes, because it decides everything else: whether you stop the game, whether you wake someone up, whether you post publicly.

| Level | Definition | Examples | Response |
|---|---|---|---|
| **SEV1** | Lasting harm to players or money; spreading | Save data lost or corrupted; purchases charged and not granted; an exploit duplicating currency | Contain within minutes, even at the cost of shutting features or servers. All hands |
| **SEV2** | Core loop broken for many players, no lasting harm | Cannot damage bosses; joining fails on phones; crash every few minutes | Contain within the hour; fix or roll back today |
| **SEV3** | Degraded for some players | One zone's lighting broken; a quest does not complete for players who did X | Fix in the next update; a workaround message if common |
| **SEV4** | Cosmetic | Typo, misaligned button | Backlog |

Two rules that prevent the worst outcomes (rule of thumb):
- **Anything touching saved data or Robux starts at SEV1** until proven otherwise. These are the incidents where every minute increases the clean-up.
- **Escalate freely, downgrade carefully.** It costs little to treat a SEV2 as SEV1 for twenty minutes; treating a SEV1 as SEV3 for a day can be unrecoverable.

---

## 2. Detection

You find out from one of four places. Know which ones you are watching.

| Source | Speed | Notes |
|---|---|---|
| Your own error pipeline and alerts | Minutes | Only as good as what you instrumented ([[Crash and Error Telemetry]]) |
| Roblox's Error Report and Performance dashboard (Creator Hub) | Delayed | Good for trends and crash rates; not real time |
| Analytics funnels and custom events | Hours | A drop in "first purchase" or "tutorial complete" can be the only sign ([[Analytics and Funnels]]) |
| Players (community server, group wall, comments) | Fast but noisy | Often the first report of logic bugs that throw no errors |

Player reports are the most underrated source. In the reference project, players saying "there's a luck bug" led to a real defect: an item meant to roll about 1 in 3 was rolling about 1 in 370 (measured). No error was ever thrown; only players noticed. Give your community a clear place to report bugs and read it after every release.

Also check the obvious before blaming your code: Roblox's own status page. If DataStore requests or joins are failing everywhere, publishing a "fix" during a platform incident makes things worse.

---

## 3. Containment: stop the bleeding before you understand it

Containment is any action that stops new damage, even if the cause is unknown. It is usually faster and safer than a fix. Pick the smallest action that stops the harm.

| Action | Time | Stops | Cost |
|---|---|---|---|
| Turn off a live flag (kill switch) | Seconds | One feature, all servers | Feature unavailable ([[Global State and Live Config]]) |
| Disable purchase prompts for the affected product | Seconds with a flag | New bad purchases | Lost sales for the duration |
| Put saves into read-only mode | Seconds with a flag | Bad data being written | Progress during the incident is not saved; tell players |
| Publish the previous place version | Minutes | Everything new in the release | Loses everything else in the release ([[Version History and Backups]]) |
| Restart servers (outdated only) | Minutes plus the bleed-off delay | Old code still running | Players moved; short disruption |
| Restart all servers | Minutes | Corrupted in-memory state everywhere | Everyone disconnected and moved |

### Kill switches have to exist before the incident

A kill switch you write during an incident is a release under pressure. Build them in advance for every risky system: trading, new currencies, new products, anything that writes to saves. The pattern:

```lua
--!strict
-- LiveFlags: read flags from a shared source, cache them, refresh periodically.
-- The source can be a DataStore key or MemoryStore; see Global State and Live Config.
local LiveFlags = {}

local flags: { [string]: boolean } = {}
local REFRESH = 30 -- seconds; push updates with MessagingService if you need faster

local function fetchFlags(): { [string]: boolean }?
	-- Replace with a read of your config store, wrapped in pcall.
	return nil
end

function LiveFlags.isOn(name: string, default: boolean): boolean
	local v = flags[name]
	if v == nil then
		return default
	end
	return v
end

task.spawn(function()
	while true do
		local ok, result = pcall(fetchFlags)
		if ok and result then
			flags = result
		end
		-- On failure keep the last known flags: never flip features on a read error.
		task.wait(REFRESH)
	end
end)

return LiveFlags
```

Then, at every risky entry point:

```lua
if not LiveFlags.isOn("TradingEnabled", true) then
	return false, "Trading is paused for maintenance"
end
```

Edge cases:
- **Default values.** A flag for a dangerous new feature should default to *off*, so a config read failure fails safe. A flag for an old, stable feature defaults to on.
- **Read failures.** Keep the last known value; do not reset to defaults on a failed read, or every DataStore hiccup toggles features.
- **The old path must work.** Turning off a feature has to leave the game in a sane state: open trade windows close, pending trades cancel and return items. Test the off path, not just the on path.

### Read-only saves

When an incident might be writing bad data, stopping writes is the most valuable containment you have. Add a flag check in your save function so saves are skipped (and logged) while it is on. Players lose progress made during the window, which is far better than overwriting good saves with bad ones. If you use a session-locking library, read its documentation for a supported way to pause saving rather than bypassing it ([[Session Locking and Profile Libraries]]).

### Purchases

If products are charging without granting, disable the prompts with a flag first. For purchases already made, Roblox calls your `ProcessReceipt` callback again later if it did not return `PurchaseGranted`, so a granting bug that errors (rather than wrongly returns granted) is recoverable once fixed. A bug that returns `PurchaseGranted` without granting is not retried; those players need manual compensation from your purchase records ([[Developer Products and ProcessReceipt]], [[Purchase Data and Receipts]]).

### Restarting servers

Roblox docs (as of October 2026): in the Creator Hub, open the experience's Server Management page, select places, and choose **Restart Servers**. The confirmation dialog offers **restart only servers with outdated versions** (recommended unless your update does not depend on place version) and a **delayed restart** of 1 to 60 minutes so players can leave on their own (server bleed-off). Roblox stops matchmaking to those servers, then teleports players to the updated version, keeping players from one old server together. When a delayed restart is scheduled, `DataModel.ServerRestartScheduled` fires on affected servers with the restart time, a `CloseReason` (developer update or Roblox maintenance) and optional attributes.

Use the event to warn players and save early:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Announce = ReplicatedStorage:WaitForChild("Announce") :: RemoteEvent

game.ServerRestartScheduled:Connect(function(restartTime: DateTime, source: Enum.CloseReason, _attributes: any)
	local seconds = math.max(0, restartTime.UnixTimestamp - DateTime.now().UnixTimestamp)
	Announce:FireAllClients(string.format("Server updating in %d minutes. Your progress is saved.", math.ceil(seconds / 60)))
	-- A good moment to flush saves and close open trades, ahead of BindToClose.
end)
```

Restarting does not fix bad data already saved, and it does not fix bad code if you publish nothing new. It is only useful together with a published fix or rollback, or to clear corrupted in-memory server state ([[Server Lifecycle and Shutdown]]).

---

## 4. Diagnosis under pressure

Once harm has stopped, find the cause. Practices that work in a hurry:

- **Diff the release.** Most incidents follow a release. What changed? Release notes and a change log are the fastest diagnostic tool you have ([[Release Process and Rollbacks]]).
- **Reproduce in the test place** with the same build, not in the live game.
- **One person types, one person writes the timeline.** The timeline (who did what, when, what was observed) is the raw material for the post-mortem and is impossible to rebuild afterwards.
- **Change one thing at a time.** Two simultaneous "fixes" make it impossible to know which worked.
- **Prefer a rollback to a hot fix** when the fix is not obvious. A rollback is a known state; a rushed fix is a new release with no testing.

Classes of incident from the reference project worth knowing, because they look nothing like their cause (measured, anonymised):
- **"Abilities don't work in the live game."** Animation clips registered at runtime only load in Studio, so every ability using that path worked in Studio and silently failed live. No error in Studio, nothing obvious live. See [[Case Study - Abilities That Only Worked in Studio]].
- **A weapon kit stopped doing damage entirely.** An animation clip was named the same as one of the kit's remotes and replaced it in the folder. A naming collision looked like a combat bug.
- **"The ability is about 5 seconds late."** The data timing was instant; the delay was the first-use load of animation assets. Preloading fixed it.

The lesson: when the symptom makes no sense, look at what changed in *content and naming*, not only in code.

---

## 5. Recovering players

### Data restore

DataStores keep versions. Roblox docs (as of October 2026): a backup version is created by the first write to each key in each UTC hour; later writes in the same hour overwrite it; old versions expire 30 days after being overwritten; the latest version never expires. `DataStore:ListVersionsAsync`, `GetVersionAsync` and `GetVersionAtTimeAsync` read them. That means:

- You can restore a player's data to "before the incident" with hourly granularity, if you act within 30 days.
- You need the incident start time, from your timeline or error logs. Write it down early.
- A restore throws away legitimate progress since that time. Decide per incident whether to restore, compensate, or both.
- Session-locked profiles must be restored when the player is not in a server, or through the library's supported path; writing under a live session lock gets overwritten by the next autosave.

```lua
--!strict
-- Read a player's save as it was at a given time (Unix ms). Admin tool, server only.
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData")

local function readAtTime(key: string, unixMs: number): any
	local ok, value = pcall(function()
		return store:GetVersionAtTimeAsync(key, unixMs)
	end)
	if not ok then
		warn("version read failed: " .. tostring(value))
		return nil
	end
	return value
end
```

Inspect before you write. Restoring blindly from the wrong timestamp is a second incident. See [[Data Loss Prevention and Recovery]].

### Compensation

Rule of thumb: compensate generously, quickly and uniformly. A gift of in-game currency or an exclusive cosmetic to everyone active during the incident costs little and builds trust. Make sure the compensation itself cannot be farmed: grant it once per player, recorded in their save, with an expiry ([[Ethical Design and Player Trust]]).

### Exploit incidents

Duplication and economy exploits need a decision about the gains: roll back the exploiters' data, wipe only the duplicated items, or leave them. Find the accounts from your server logs or trade records, act on those, and avoid broad rollbacks that punish everyone. Fix the validation hole first ([[Exploits and Anti-Cheat]]).

---

## 6. Communication

Players forgive bugs; they do not forgive silence or dishonesty. Rules of thumb:

- **Acknowledge early**, before you know the cause: "We know coins are not saving. Saves are paused while we fix it. Your progress before 14:00 is safe."
- **Say what players should do** (or not do): "Do not trade until we post an update."
- **Update on a schedule** (every 30 to 60 minutes during SEV1), even if the update is "still working on it".
- **Close it out** with what happened, what was fixed, and what compensation is coming.
- **Do not blame Roblox** unless it is confirmed on the status page, and do not blame players for "using it wrong".
- Use the channels you own: an in-game announcement (as in the code above), the group, your community server ([[Community Building]]).

---

## 7. The post-mortem

Within a few days of every SEV1 and SEV2, write a post-mortem. It is the only part of the incident that makes the next one less likely.

### Blameless means about systems

The question is never "who broke it", it is "what let a normal mistake reach players". People make mistakes at a steady rate; systems decide whether those mistakes are caught. A post-mortem that ends with "be more careful" has failed.

### Template

```
# Post-mortem: <one-line title>
Severity: SEV1     Duration: 14:02 to 16:40 (2 h 38 min)     Players affected: about N

## Summary
Three sentences: what happened, impact, how it was resolved.

## Timeline (all times in one timezone)
14:02  Release 0.43.0 published, outdated servers restarted
14:20  First player report in the community server
14:31  Confirmed in test place; saves set read-only (containment)
...

## Impact
What players lost or experienced; numbers where known.

## Root cause
The technical cause, and the conditions that let it ship.

## What went well
## What went badly
## Where we got lucky

## Action items
| Action | Type | Owner | Due |
|---|---|---|---|
| Add statistical test for weighted picks | prevent | ... | ... |
| Add kill switch to the rolling service | mitigate | ... | ... |
| Alert on purchase-grant errors | detect | ... | ... |
```

### Good action items

Sort them into **prevent** (stop the cause recurring), **detect** (find it faster) and **mitigate** (reduce harm next time). A good post-mortem has at least one of each. Each has an owner and a date; otherwise it is a wish.

Watch for "five whys" going wrong: it is a useful prompt, but it tends to stop at the first human error ("the developer forgot to update the table"). Keep going: why could the table be forgotten? Why did no test catch it? Why did no alert fire?

### A worked example (reconstructed and simplified)

The luck bug from section 2, written as a post-mortem summary:

- **Summary.** A weighted random pick returned a common item far less often than configured (about 1 in 370 instead of about 1 in 3). Found from player reports, fixed the same day.
- **Root cause.** A defect in the weighted-pick logic; no test compared observed rates with configured odds.
- **Why it reached players.** Odds bugs throw no errors and look plausible in a handful of manual rolls.
- **Actions.** Prevent: a statistical test over every odds table, run before release ([[Automated Testing with TestEZ and Jest-Lua]]). Detect: log roll outcomes as analytics events and compare rates with configured odds daily. Mitigate: keep the odds table behind live config so a correction does not need a full release.

(The specific defect is simplified here; the measured facts are the reported and actual rates, the source of the report, and the same-day fix.)

### Keep an index

Post-mortems are only useful if people read them. Keep them in one folder, link each from the release it followed, and fold repeated lessons into checklists ([[Lessons Learned Index]], [[QA Checklists Before Release]]).

---

## 8. Preparing before anything happens

An incident goes as well as the preparation allowed. A one-page runbook, written in calm times:

- Who can publish, restart servers and change live flags (at least two people; [[Scoping and Roles for Small Teams]]).
- Where the kill switches are and what each one does.
- How to put saves into read-only mode.
- How to roll back a release (which version, how to publish it).
- How to read a player's data version history.
- Where to post announcements.
- The severity table above.

Practise once: pick a quiet hour, pretend a SEV1, and walk through the runbook on the test place. The first practice always finds a missing permission or an untested kill switch.

---

## Common mistakes

- Hunting the bug while the bug keeps corrupting data.
- No kill switches, so the only containment is a full rollback.
- Fixing forward with an untested hot fix instead of rolling back.
- Restarting servers without publishing anything, expecting the bug to go away.
- Restoring data from a guessed timestamp without inspecting it first.
- Restoring session-locked data while the player is online.
- Going silent with players until the fix is ready.
- Post-mortems that blame a person or end with "be more careful".
- Action items without owners or dates.

## Checklist

- [ ] Severity assigned in the first five minutes; data and Robux issues start at SEV1.
- [ ] Containment applied (flag, read-only saves, prompts off, rollback, restart).
- [ ] Timeline started immediately with incident start time.
- [ ] Platform status checked.
- [ ] Cause reproduced in the test place, not in live.
- [ ] Fix or rollback published; outdated servers restarted with a sensible delay.
- [ ] Data restored from versions where needed, inspected first.
- [ ] Compensation granted once per player, recorded.
- [ ] Players told early, updated regularly, closed out.
- [ ] Post-mortem written with prevent, detect and mitigate actions, each with an owner.

## See also

[[Release Process and Rollbacks]], [[Crash and Error Telemetry]], [[Global State and Live Config]], [[Data Loss Prevention and Recovery]], [[Session Locking and Profile Libraries]], [[Developer Products and ProcessReceipt]], [[Server Lifecycle and Shutdown]], [[Exploits and Anti-Cheat]], [[Community Building]], [[Live Ops Events and Updates]], [[Lessons Learned Index]], [[Post-Mortem - Building a Melee Action Game]]

## Connected notes
<!-- auto-links:start -->
[[Server Shutdowns Soft Updates and Migration]] · [[Feature Flags and Staged Rollouts]] · [[Feature Flags]] · [[Live Ops Deep Dive Start Here]] · [[Build Test and Release Pipeline]] · [[Patch Notes and Player Communication]]
<!-- auto-links:end -->
