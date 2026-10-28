---
tags: [accessibility, difficulty, assist-modes, cognitive-load, game-design, server-authority, onboarding, multiplayer]
---
# Difficulty Options and Cognitive Load

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One "Easy / Hard" toggle that bundles unrelated changes.
> - Avoid: Client-trusted multipliers that become god mode.
> - Avoid: Assists that can be toggled mid-fight to dodge a hit.
> - Difficulty split into named assists, with presets for players who do not configure.
> - Each assist classified: personal, personal with fairness impact, or world-level (instanced only).
> - Assists stored and enforced on the server, sanitised, rate-limited, locked in combat where needed.
>
> Cost: TL;DR ~160 tok · whole note ~4.9k tok. Read more: ## 3. Server-authoritative assists · ## 6. Cognitive load: what it is and how to cut it · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Some players cannot finish a game not because of their eyes, ears or hands, but because the game asks for too much at once: too many timers, too many systems, too little room for a mistake, too much to remember between sessions. [[Accessibility]] lists the basics (one objective at a time, consistent placement, clear feedback). This note goes into the design and the engineering: granular assist options instead of "Easy / Normal / Hard", how assists work in a multiplayer, server-authoritative Roblox game, how to keep leaderboards fair, adaptive help that does not patronise, and how to measure and cut cognitive load.

Sources: **rule of thumb** for most design numbers (difficulty and cognitive load are design fields more than engine facts), **measured in the reference project** where noted, and **Roblox docs (as of October 2026)** for the few engine facts used.

---

## 1. Difficulty is several dials, not one

A single difficulty setting bundles things that different players need separately. A player with a tremor needs wider timing windows but may want hard enemies. A player with memory difficulties needs objective reminders, not weaker enemies. A young player needs more forgiving checkpoints. Splitting difficulty into independent assists lets each player remove exactly the barrier they face and keep the challenge they want.

| Assist | What it changes | Who it helps |
|---|---|---|
| Damage taken multiplier | Incoming damage (for example 50% to 100%) | Players who struggle with reaction-heavy combat |
| Timing window scale | Parry, dodge, QTE and combo windows (for example 100% to 200%) | Motor and processing speed |
| Game speed (single-player spaces only) | Simulation speed of enemies and hazards | Processing speed, tremor |
| Aim assist strength or lock-on | Target acquisition | Fine motor control |
| Checkpoint frequency | How much progress a failure costs | Everyone, especially young players |
| Skip a section after N failures | Lets a player continue the story | Players who would otherwise quit |
| Hints and guidance | Waypoints, highlighted interactables, puzzle hints | Memory, attention, new players |
| Enemy count or aggression | How many things demand attention at once | Attention, overwhelm |
| Fall protection / no instant death | Converts instant kills into damage or a reset to the ledge | Platforming anxiety, motor |

"Easy, Normal, Hard" can still exist as **presets** that set these dials, so players who do not want to configure anything get a sensible bundle. The individual dials sit under an "Assists" section for those who want control.

### Naming

Name assists by what they do ("Wider dodge window"), not by who they are for ("Easy mode", "Kids mode"). Players who need help often avoid options labelled as lesser. Avoid in-game mockery of assisted players (no "chicken" badge for using assists).

---

## 2. Multiplayer changes everything

Single-player games apply difficulty to the whole world. Most Roblox games are shared servers, where a world-level setting affects everyone. Sort each assist into one of three kinds before implementing it:

| Kind | Examples | Implementation |
|---|---|---|
| **Personal, no effect on others** | Damage taken by this player, timing windows for this player's parries, hints, waypoints, checkpoint frequency in an obby | Per-player value on the server, applied in that player's damage and input validation paths |
| **Personal, affects fairness** | Aim assist, lock-on, damage dealt, skipping stages | Per-player, plus a flag on any score or leaderboard entry earned with it |
| **World-level** | Game speed, enemy count, boss health | Only in solo spaces: a private or reserved server, an instanced dungeon for one party, or a per-party scaling rule |

**Game speed** is the clearest example. You cannot slow server physics for one player in a shared server. If slower play matters to your game, run the slow version in an instance that only that player or party is in, and scale the instance's enemies and timers through your own code (animation speed, attack cooldowns, projectile speed), since engine physics speed is not a per-player setting. [[Teleporting and Multi-Place Games]] and [[Reserved and Private Servers in Practice]] cover instancing.

**Party scaling** is the usual world-level compromise: an instanced boss uses the most assisted member's settings, or the party leader picks a difficulty before entering. Make the rule visible in the lobby so no one is surprised.

---

## 3. Server-authoritative assists

Assists change gameplay, so they live on the server. The client asks; the server validates, stores and applies. Clients must not be able to set arbitrary multipliers (a client that sends `damageTaken = 0` has made itself invincible).

```lua
--!strict
-- ServerScriptService/Assists.lua: per-player assist values, validated and applied on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type AssistKey = "damageTaken" | "timingWindow" | "aimAssist" | "hints" | "fallProtection" | "skipAfterFails"

type Spec = {
	kind: "number" | "boolean",
	min: number?,
	max: number?,
	default: any,
	affectsFairness: boolean,
	lockedInCombat: boolean,
}

local SPECS: { [AssistKey]: Spec } = {
	damageTaken = { kind = "number", min = 0.5, max = 1, default = 1, affectsFairness = true, lockedInCombat = true },
	timingWindow = { kind = "number", min = 1, max = 2, default = 1, affectsFairness = false, lockedInCombat = true },
	aimAssist = { kind = "number", min = 0, max = 1, default = 0.3, affectsFairness = true, lockedInCombat = false },
	hints = { kind = "boolean", default = true, affectsFairness = false, lockedInCombat = false },
	fallProtection = { kind = "boolean", default = false, affectsFairness = true, lockedInCombat = false },
	skipAfterFails = { kind = "boolean", default = true, affectsFairness = true, lockedInCombat = false },
}

local Assists = {}

local values: { [Player]: { [AssistKey]: any } } = {}
local lastChange: { [Player]: number } = {}
local MIN_INTERVAL = 0.5

local remote = ReplicatedStorage.Remotes.SetAssist :: RemoteEvent

-- Supplied by the combat system: true while the player is in combat.
local InCombat = require(script.Parent.InCombat)

local function sanitize(key: AssistKey, raw: unknown): any
	local spec = SPECS[key]
	if spec.kind == "boolean" then
		return if type(raw) == "boolean" then raw else nil
	end
	if type(raw) ~= "number" or raw ~= raw then -- reject NaN
		return nil
	end
	-- Snap to steps of 0.05 so values stay comparable and saves stay small.
	local snapped = math.round(raw * 20) / 20
	return math.clamp(snapped, spec.min :: number, spec.max :: number)
end

local function fairnessFlag(player: Player)
	local assisted = false
	for key, spec in SPECS do
		if spec.affectsFairness and values[player][key] ~= spec.default then
			assisted = true
			break
		end
	end
	player:SetAttribute("Assisted", assisted)
end

function Assists.get(player: Player, key: AssistKey): any
	local v = values[player]
	if v and v[key] ~= nil then
		return v[key]
	end
	return SPECS[key].default
end

function Assists.load(player: Player, saved: unknown)
	local v: { [AssistKey]: any } = {}
	if type(saved) == "table" then
		for key in SPECS do
			local clean = sanitize(key, (saved :: any)[key])
			if clean ~= nil then
				v[key] = clean
			end
		end
	end
	for key, spec in SPECS do
		if v[key] == nil then
			v[key] = spec.default
		end
		player:SetAttribute(`Assist_{key}`, v[key])
	end
	values[player] = v
	fairnessFlag(player)
end

function Assists.export(player: Player): { [string]: any }
	return table.clone(values[player] or {})
end

remote.OnServerEvent:Connect(function(player: Player, key: unknown, raw: unknown)
	if type(key) ~= "string" or SPECS[key :: AssistKey] == nil or values[player] == nil then
		return
	end
	local now = os.clock()
	if now - (lastChange[player] or 0) < MIN_INTERVAL then
		return
	end
	lastChange[player] = now
	local k = key :: AssistKey
	if SPECS[k].lockedInCombat and InCombat.is(player) then
		return -- the client UI greys the option out in combat; this is the enforcement
	end
	local clean = sanitize(k, raw)
	if clean == nil then
		return
	end
	values[player][k] = clean
	player:SetAttribute(`Assist_{k}`, clean)
	fairnessFlag(player)
end)

Players.PlayerRemoving:Connect(function(player)
	values[player] = nil
	lastChange[player] = nil
end)

return Assists
```

How the rest of the game uses it:

- **Damage pipeline:** the server's damage function multiplies incoming damage by `Assists.get(target, "damageTaken")`. One place, not every weapon ([[Combat Systems Architecture]]).
- **Timing windows:** the server's parry or dodge validation widens its accepted window by `timingWindow`. The client also reads the replicated attribute to widen the visual cue, but the server's check is the authority.
- **Attributes replicate**, so the client UI shows current values and other systems (a nameplate icon for assisted players, if you choose to show one) can read them without extra remotes.
- **Locked in combat** stops a player from toggling damage reduction in the last second of a boss fight to survive a hit, which would make the assist an exploit rather than an accessibility setting.
- **Saved with the profile** via `Assists.export`, loaded on join with `Assists.load`, which sanitises again in case limits changed.

---

## 4. Fair leaderboards without punishing assists

When assists affect fairness, the options are:

1. **Separate boards.** "Speedrun (assisted)" and "Speedrun". Clean, but splits the community.
2. **One board with a marker.** An icon next to assisted entries. Visible, respectful, keeps one community.
3. **Exclude fairness-affecting assists from ranked modes only.** Casual play allows everything; ranked queues require default values for the few assists that change outcomes.

Option 3 is usually right for competitive PvP; option 2 for PvE time trials and progression boards. Whatever you choose, record the `Assisted` flag **at the time the score was earned** (store it with the entry), not at the time the board is read; players change settings. [[OrderedDataStores and Leaderboards]] covers board storage.

Avoid making progression rewards depend on not using assists (for example, the best item drops only on assist-free runs). That turns accessibility into a tax.

---

## 5. Adaptive help that does not patronise

Detecting struggle and offering help works well when it **offers** rather than **imposes**:

- **Failure streaks.** After three failures at the same obstacle (rule of thumb), show a small, dismissible offer: "Want a hint?" or "Skip this stage?". Never trigger it after one failure.
- **Idle confusion.** If a new player has not made progress toward the current objective for a while (for example 90 seconds) and has not opened a menu, pulse the objective tracker or show the waypoint. [[First-Time User Experience and Onboarding]] covers the first-session version.
- **Return after a break.** On rejoin after more than a few days, show a short "Last time..." recap: current goal, where to go, what was unlocked. Memory difficulties and long gaps both benefit.
- **Silent dynamic difficulty** (quietly weakening enemies when a player struggles) is controversial. It helps retention, but players who notice feel cheated, and in multiplayer it is visible ("why does his boss have less health?"). If you use it, keep it small, keep it per-player and personal (fewer projectiles aimed at this player, not less boss health for everyone), and let players turn it off.

For obbies specifically, "skip after N failures" is often monetised as a paid skip. Offer a free path too (a longer wait, a slower skip earned by attempts) so that a player who physically cannot do a jump is not forced to pay or quit. [[Ethical Design and Player Trust]] covers the wider principle.

---

## 6. Cognitive load: what it is and how to cut it

Cognitive load is how much the player must hold in mind and process at once. Working memory is small: a common estimate is about four chunks at a time (rule of thumb, from cognitive psychology research). Roblox games often exceed that in the first minute: currency, a second currency, a quest, a timer, a shop popup, a daily reward, a battle pass badge, and a tutorial arrow.

### Sources of load and fixes

| Source | Example | Fix |
|---|---|---|
| Simultaneous goals | Three quest trackers, a timer and a pop-up | One active objective on the HUD; others in a log |
| Hidden state | Cooldowns only in memory | Visible cooldown rings with numbers |
| Memorised rules | "Fire beats ice except at night" | On-screen hints at the moment of choice |
| Inconsistent controls | Interact is E in one place, F in another | One key per verb, everywhere |
| Inconsistent UI | Close button moves between screens | Fixed positions ([[UI Design Systems]]) |
| Time pressure in menus | Offers that expire while reading | No timers on choices that matter |
| Unexplained numbers | "+12.5% LCK" | Words first ("+12.5% luck: rarer drops") |
| Interruptions | Pop-ups during combat | Queue notifications until a calm moment ([[Notification and Toast Systems]]) |
| Dense text | Paragraph tutorials | Short imperatives, one step at a time ([[Lore Delivery Without Walls of Text]]) |

### Progressive disclosure

Reveal systems when the player needs them, not at join. A simulator might show only the main currency and the first action for the first two minutes, then reveal upgrades when the player can afford one, then rebirth when it becomes relevant. The reference project's tutorial lines were rewritten repeatedly toward one short imperative per step (measured in the reference project; see [[Accessibility]]), and players followed them more reliably.

### A HUD decluttering option

Offer a "simple HUD" or "focus mode" setting that hides non-essential elements (event banners, social buttons, secondary currencies) and leaves health, the current objective and the primary action. This helps players with attention difficulties, players on small phones, and streamers. Make sure hidden elements are still reachable from a menu, and that the setting does not hide anything the player needs to survive. [[HUD Design]] covers HUD hierarchy in general.

### Reading level

Write for a young reader even if your audience skews older. Short sentences, common words, verbs first, numbers as digits. Test by reading UI text aloud: if it is awkward to say, it is slow to read. Combine with [[Localization-Ready Writing]], since simpler English also translates better.

### Pausing in a game that cannot pause

Most Roblox games cannot pause the world. Players who need breaks (fatigue, medical needs, a parent calling) are punished by systems that run while they are away. Mitigations:

- Safe zones where nothing can hurt the player.
- A "rest" or AFK state that makes the player untargetable when they have not moved for a while in a safe area.
- Timers and events that are long enough to survive a short break, or that pause per player when they are in a menu (for personal timers only).
- Never punish disconnects in PvE by losing all progress; save at checkpoints ([[Saving Correctly - Autosave and BindToClose]]).

---

## 7. Measuring difficulty and load

Analytics tell you where players struggle; accessibility work tells you why ([[Analytics and Funnels]]):

- **Failure heat maps** by stage or encounter: deaths, retries and quits per stage. A stage with a quit spike is a candidate for checkpoints or an assist offer.
- **Assist adoption:** what share of players change each assist, and whether they stay longer afterwards. Low adoption with high quit rates often means the option is hard to find.
- **Time to first action** for new players: a long time often means they did not understand what to do.
- **Hint requests per puzzle:** a puzzle where most players ask for a hint is either too hard or badly signposted.

Keep assist settings in your analytics events (as dimensions), so you can compare assisted and unassisted funnels. Do not use them to shame or segment players for monetisation.

---

## 8. When not to do this

- **Do not remove the challenge for everyone.** Some games are about difficulty. Assists let players opt in to help; they do not require you to make the default easy.
- **Do not add assists that break your economy.** A damage-dealt assist that doubles farming speed is an economy multiplier. Keep assists to survival and timing, or exclude assisted farming from the rates that matter ([[Economy Inflation Sinks and Faucets Math]]).
- **Do not hide assists behind progression.** If players must reach level 10 to unlock "wider dodge window", the players who need it never get there.
- **Do not make difficulty a monetisation lever.** Selling the way past a barrier you created is the opposite of accessible design.

---

## 9. Testing

- Play the first 10 minutes as a new player with a stopwatch and count how many distinct things the screen asks of you at each minute. More than four at once is a warning sign.
- Turn every assist to its most helpful value and finish the hardest content. Check that nothing breaks (economy, leaderboards, achievements).
- Try toggling assists during combat via the remote directly (a test harness or a modified client in a test place) and confirm the server refuses.
- Rejoin after clearing your session and see whether the "Last time..." recap orients you.
- Watch a young player or a non-gamer play without help. Note every question they ask.

---

## Common mistakes

- One "Easy / Hard" toggle that bundles unrelated changes.
- Client-trusted multipliers that become god mode.
- Assists that can be toggled mid-fight to dodge a hit.
- Leaderboard flags computed at read time rather than stored with the score.
- Assists labelled as "kids mode" or mocked in-game.
- Paid-only skips for physically demanding sections.
- A first minute that shows six currencies and four pop-ups.
- No way to rest in a world that never pauses.

## Checklist

- [ ] Difficulty split into named assists, with presets for players who do not configure.
- [ ] Each assist classified: personal, personal with fairness impact, or world-level (instanced only).
- [ ] Assists stored and enforced on the server, sanitised, rate-limited, locked in combat where needed.
- [ ] Fairness flag stored with each score; ranked rules clear.
- [ ] Adaptive offers after repeated failure, dismissible, never forced.
- [ ] One active objective on the HUD; progressive disclosure; simple HUD option.
- [ ] Safe zones or rest states for breaks.
- [ ] Analytics track failure spikes and assist adoption.

See also: [[Accessibility Start Here]], [[Accessibility]], [[First-Time User Experience and Onboarding]], [[Progression and Pacing Design]], [[HUD Design]], [[Ethical Design and Player Trust]], [[Genre Playbook - Obbies and Platformers]], [[Boss Fight Design Patterns]], [[Input Remapping and One-Handed Play]], [[Analytics and Funnels]].

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Puzzle and Escape Rooms]] · [[Obby Checkpoints and Stage Saves End to End]] · [[Quests and Objectives]] · [[Obby and Platforming Level Design]] · [[Links - Leaderboards]] · [[Core Loops and Session Design]]
<!-- auto-links:end -->
