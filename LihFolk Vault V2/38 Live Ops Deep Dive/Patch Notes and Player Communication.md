---
tags: [live-ops, communication, patch-notes, community, updates, trust, luau, type/guide, area/liveops, level/advanced, api/ConfigService, area/scripting]
---
# Patch Notes and Player Communication

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: "Bug fixes and improvements" -> Specific, numbered changes
> - Avoid: Notes shown on every join -> Once per version, server-tracked
> - Avoid: Notes only in an external community -> In-game panel is canonical
> - In-game What's New panel is the canonical source; other channels derive from it
> - Panel shows once per version, skips brand-new players, never blocks play
> - Notes stored as versioned config data, with translations if the game is localised
>
> Cost: TL;DR ~160 tok · whole note ~4.4k tok. Read more: ## 3. Hard messages · ## 4. An in-game What's New panel that respects players · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Players do not experience your update; they experience what they notice of it. A balance change nobody explained feels like a stealth nerf. A fixed bug nobody mentioned is invisible. An outage with no message feels like the game died. Patch notes and the other player-facing messages around an update are how a live game turns changes into trust, and on Roblox the channels are narrower and stricter than on other platforms: 60-character announcements, personalised-only notifications, and limits on pointing players off-platform.

[[Live Ops Events and Updates]] lists the platform channels and their limits. [[Update Cadence and Hype Cycles]] covers teasing and update-day structure. [[Release Process and Rollbacks]] shows an internal build log and why it is not a release log. This note covers the player-facing layer in depth: which channel carries which message, how to write notes players read, communicating nerfs, removals and mistakes, an in-game "What's New" system that cannot nag, incident messages, and the habits that keep it honest.

Source labels: **Roblox docs (as of October 2026)**, **rule of thumb**, **measured in the reference project**.

## 1. The channels and what each is for

| Channel | Reach | Limits (Roblox docs, as of October 2026) | Best for |
|---|---|---|---|
| Update announcement (Creator Dashboard, Engagement > Updates) | Players who turned on notifications for your game | **60 characters**, at most **one every three days** | The single headline of an update |
| Experience Events | Game page, event page, Notify Me RSVPs, Trending Events sort | Up to 10 ongoing or upcoming events; featuring submissions 7+ days ahead | Timed beats with a start time |
| Experience notifications | Opted-in players aged 13+ | Personalised to the player's own activity, 99-character strings, one per user per day, no disguised ads or false time pressure | "Your crops are ready" style messages, not patch notes |
| Game description | Everyone who views the page | Plain text, filtered | A short "latest update" line and the game's evergreen pitch |
| In-game What's New panel | Players who join | Your design | The real patch notes |
| In-game banners and toasts | Players in session | Your design | Live incidents, event starts, maintenance |
| Community spaces you run | Your community members | Their own rules; see the note on external links below | Long-form notes, discussion, feedback |

Two platform facts to design around:

- **Under-13 players** can receive experience updates but cannot receive experience notifications (Roblox docs, as of October 2026). For a young audience, in-game communication is the main channel.
- **External links.** [[Live Ops Events and Updates]] and [[Age Checks and Safety Features]] record a 2026 restriction on pointing players to external social links from in-game text. Check the current policy before writing "join our community at..." anywhere in the game, and make sure the in-game notes are complete on their own.

The practical conclusion: **the in-game What's New panel is the canonical patch note**, and every other channel is a pointer to the game. Write the full notes once, in game; derive the 60-character headline, the event description and the community post from it.

## 2. Writing notes players read

### Structure

A template that works for most updates (rule of thumb):

1. **Headline** (one line): the biggest player-visible thing. "Frost Peaks: a new zone with 6 bosses."
2. **New** (3 to 6 bullets): content and features, each with where to find it.
3. **Changes** (balance and quality of life), with numbers.
4. **Fixes**: the ones players reported or noticed.
5. **Known issues**: what you know is still broken and whether a workaround exists.
6. **Coming next** (optional, one line): only if you are confident.

Keep the in-game panel short enough to read in under a minute; link nothing out. If the full list is long, show the top items and let a "more" section expand.

### Specific beats vague

The Roblox docs call out "bug fixes" as an example of an unhelpful update message, because it does not say what changed. The same holds inside the game. Compare:

| Vague | Specific |
|---|---|
| Bug fixes | Fixed pets sometimes vanishing after a teleport |
| Balance changes | Ice Sword damage 120 to 105; attack speed unchanged |
| Improved performance | Hub loads about 2 seconds faster on phones |
| New stuff! | New zone: Frost Peaks (unlock at zone 8) |

Numbers make changes checkable, which is exactly why some teams avoid them. Avoiding them does not stop players from measuring; it only means they find out from a video titled "SECRET NERF".

### Write for the audience

Roblox players are often young and often reading in a second language. Rules of thumb:

- Short sentences, common words, no internal names ("refactored ProfileService" means nothing to a player).
- Name things exactly as the game names them, including capitalisation, so players can find them.
- Use player-facing units ("about 2 seconds faster"), not engine metrics.
- Translate the notes if the game is localised. Notes stored as data (section 4) can carry a table per language; machine translation is acceptable for notes if reviewed for item names ([[Localization]], [[Localization Pipeline]]).
- No hype words in place of information. "Huge", "insane" and "best update ever" use up attention without saying anything.

## 3. Hard messages

### Nerfs

A nerf takes something away from players who invested in it. A good nerf note does four things:

1. **States the change with numbers.**
2. **Gives the reason in one honest sentence**: "Ice Sword was picked in 70 percent of boss runs; other swords were not worth using."
3. **Says what you are doing for affected players**, if anything: a free respec, a refund of upgrade materials, a cosmetic for owners.
4. **Says what you will watch next**: "We will check boss clear times over the next week."

Compensation should scale with investment. If players bought the nerfed thing with Robux, compensation is close to mandatory; if they earned it, a respec or material refund is usually enough (rule of thumb). [[Economy Resets and Seasonal Wipes]] covers larger compensations.

### Removals

Removing a feature or item is a nerf to zero. Announce it before it happens, say what replaces it, and keep anything purchased working or converted. "The old trading hall is closing on the 14th; trading moves to the market plaza with the same rules" is fine. Discovering the hall gone is not.

### Mistakes

When something you shipped hurts players (lost items, a broken event, a wrong reward), say so plainly and quickly:

- **What happened**, in one sentence, without blaming players or a platform unless that is genuinely the cause.
- **Who was affected** and how they will know.
- **What you are doing**, with a time frame you can keep.
- **What you are giving back.**

Apologies that over-explain internal causes read as excuses. Apologies that promise "this will never happen again" create a promise you cannot keep; say what changed in your process instead ([[Live Incident Response and Post-Mortems]]).

### Silent changes

Not every change needs a note. Server performance work and invisible refactors can go unannounced. But anything a player could notice and measure (damage, drop rates, prices, timers, rewards) belongs in the notes. A drop rate lowered silently is the change most likely to be discovered by dataminers and framed as deception. For paid random items, changing odds without updating the disclosure is also a compliance problem ([[Paid Random Items and Odds Disclosure in Practice]]).

## 4. An in-game What's New panel that respects players

Requirements:

- Shows **once per new version** a player has not seen, not on every join.
- Never blocks play: dismissable with one tap, and not shown during onboarding for brand-new players (they have nothing to compare against).
- Notes stored as data, so a typo or a missing fix can be corrected without a publish.
- The last few versions remain readable from a button (settings or a news icon).

The server owns "has this player seen version N", stored in the profile; the notes come from a JSON config ([[Global State and Live Config]]).

```lua
--!strict
-- ServerScriptService/Live/WhatsNew (ModuleScript)
-- Decides whether to show patch notes to a player and sends them.
local ConfigService = game:GetService("ConfigService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WhatsNew") :: RemoteEvent

export type Notes = {
	version: number,
	headline: string,
	sections: { { title: string, lines: { string } } },
}

local WhatsNew = {}
local latest: Notes? = nil

local function parse(raw: any): Notes?
	local value = raw
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		value = if ok then decoded else nil
	end
	if type(value) ~= "table" or type(value.version) ~= "number" or type(value.headline) ~= "string" then
		return nil
	end
	local sections = {}
	if type(value.sections) == "table" then
		for _, s in value.sections do
			if type(s) == "table" and type(s.title) == "string" and type(s.lines) == "table" then
				local lines = {}
				for _, line in s.lines do
					if type(line) == "string" then
						table.insert(lines, line)
					end
				end
				table.insert(sections, { title = s.title, lines = lines })
			end
		end
	end
	return { version = value.version, headline = value.headline, sections = sections }
end

-- Call after the profile loads. `isNewPlayer` skips the panel during onboarding,
-- and marks the version as seen so it does not appear later for an old update.
function WhatsNew.onProfileLoaded(player: Player, data: any, isNewPlayer: boolean)
	local notes = latest
	if not notes then
		return
	end
	local seen = tonumber(data.NotesSeen) or 0
	if seen >= notes.version then
		return
	end
	data.NotesSeen = notes.version -- mark first: a disconnect must not re-show it forever
	if not isNewPlayer then
		remote:FireClient(player, notes)
	end
end

-- For the "news" button: always returns the latest notes on request.
function WhatsNew.get(): Notes?
	return latest
end

task.spawn(function()
	local ok, snap = pcall(function()
		return ConfigService:GetConfigAsync()
	end)
	if not ok then
		return -- no notes is a safe failure
	end
	latest = parse(snap:GetValue("patchNotes"))
	snap:GetValueChangedSignal("patchNotes"):Connect(function(value)
		local parsed = parse(value)
		if parsed then
			latest = parsed
		end
	end)
	snap.UpdateAvailable:Connect(function()
		pcall(function()
			snap:Refresh()
		end)
	end)
end)

return WhatsNew
```

Notes on the design:

- **Version numbers are integers that only go up.** Showing the panel when `seen < version` means a typo fix to the current notes (same version) does not re-show the panel, while a new update (version + 1) does.
- **Marking before sending** trades a rare missed panel (the remote fails) for never nagging. The news button covers the miss.
- **The client renders plain text** into `TextLabel`s. If you use rich text for headings, escape any characters that would break the markup ([[Text Fonts and Rich Text]]).
- **One config per language** (`patchNotes_es`, `patchNotes_pt`) or a language map inside the JSON, chosen by the player's locale on the server. Keep the English version as the fallback.
- **Pair the panel with the build number** shown in a corner of the settings screen. When players report bugs, "which version are you on?" has an answer, and support can tell whether the player is on an old server ([[Release Process and Rollbacks]]).

### Release notes as a release log

The same JSON doubles as your release log: one entry per publish that reached players, with version, date and whether servers were restarted. The reference project kept a detailed daily build log but no separate record of what each release contained, which made "what changed for players on day X" hard to answer later (measured in the reference project; [[Release Process and Rollbacks]]). Writing player notes per release fixes that as a side effect.

## 5. Live incident messages

During an incident (servers crashing, purchases failing, data not loading), communicate in the game first, because that is where affected players are:

- **A server-wide banner** driven by a config string: "Purchases are paused while we fix an issue. Nothing you bought is lost." A config change reaches servers in about a minute (Roblox docs, as of October 2026), much faster than a publish.
- **Turn off the broken thing and say so**: a kill switch that hides the shop should also show a reason, not leave a blank space ([[Feature Flags and Staged Rollouts]]).
- **Data-loading failures:** tell the player their data did not load and that they should rejoin, rather than letting them play on a blank profile that might save over the real one ([[Data Loss Prevention and Recovery]]).
- **After the fix**: a short note in What's New and, if players lost something, the compensation and how it reaches them.

Template for an incident banner (rule of thumb): what is affected, what is safe, what to do, when you will update. "Trading is off while we fix a bug. Your items are safe. Please do not trade until this message is gone." Keep it under about 120 characters so it fits a phone screen in one or two lines.

## 6. Maintenance and shutdown messages

When you publish and restart servers ([[Server Lifecycle and Shutdown]]), players in a server about to close should see a countdown with a reason ("Updating to version 416: Frost Peaks!") rather than a sudden disconnect. A 30 to 60 second warning, a save, then a teleport into an updated server is a common pattern (rule of thumb). The message is also free marketing: the player is about to see the new update.

## 7. Listening is half of communicating

Notes are one direction. Players will tell you what they noticed through reviews, dislikes, community channels and support. Habits that close the loop (rule of thumb):

- **A known issues list** in the notes, updated as reports come in. It reduces duplicate reports and shows players that reports are read.
- **Credit player reports** in fixes ("thanks to everyone who reported the teleport bug"), without naming individual minors.
- **Read the first day of reactions** after any nerf or price change, and decide within a week whether to adjust. Changing your mind is fine; doing it silently is not.
- **Keep a log of promises** made in notes ("coming next: trading"). Broken promises are remembered longer than delivered ones ([[Community Building]], [[Player Reports and In-Game Moderation]]).

## 8. Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| "Bug fixes and improvements" | Players learn nothing; changes look hidden | Specific, numbered changes |
| Notes shown on every join | Players dismiss without reading; annoyance | Once per version, server-tracked |
| Notes only in an external community | Under-13 players and most others never see them | In-game panel is canonical |
| Nerf without reason or compensation | Backlash, dislikes | Numbers, reason, compensation, follow-up |
| Silent drop-rate change | Dataminers frame it as deception; disclosure out of date | Every measurable change in notes; update odds displays |
| Incident with no in-game message | Players assume the game is broken or dead | Config-driven banner within minutes |
| Promising dates you cannot keep | Trust loss on every slip | Promise content, not dates, unless certain |
| Patch notes hard-coded in a script | Typos need a publish | Notes as config data |

## 9. Checklist

- [ ] In-game What's New panel is the canonical source; other channels derive from it
- [ ] Panel shows once per version, skips brand-new players, never blocks play
- [ ] Notes stored as versioned config data, with translations if the game is localised
- [ ] Headline fits the 60-character update announcement
- [ ] Every measurable change (damage, rates, prices, timers) is listed with numbers
- [ ] Nerfs carry a reason, compensation where earned or paid, and a follow-up
- [ ] Known issues section maintained
- [ ] Incident banner driven by config, with a template ready
- [ ] Build number visible in game for support
- [ ] External links checked against current Roblox policy before use

## See also
[[Live Ops Deep Dive Start Here]] · [[Live Ops Events and Updates]] · [[Update Cadence and Hype Cycles]] · [[Release Process and Rollbacks]] · [[Release Process and Rollbacks]] · [[Live Incident Response and Post-Mortems]] · [[Community Building]] · [[Notification and Toast Systems]] · [[Localization]] · [[Feature Flags and Staged Rollouts]] · [[Economy Resets and Seasonal Wipes]]

## Connected notes
<!-- auto-links:start -->
[[Event Calendars and Content Planning]] · [[Experience Notifications and Return Prompts]] · Feature Flags · Server Shutdowns Soft Updates and Migration · Discord Servers for Roblox Games · Live Content Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Server Shutdowns Soft Updates and Migration]] · [[Discord Servers for Roblox Games]] · [[Feature Flags]] · [[Limited-Time Offers - Design and Ethics]] · [[Battle Pass and Season Design]] · [[Roadmaps Milestones and Scope Control]]
<!-- related:end -->
