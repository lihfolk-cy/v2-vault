---
tags: [marketing, growth, live-ops, updates, cadence, events, retention]
---
# Update Cadence and Hype Cycles

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Publishing the update and opening it to players at the same moment, with no time to catch release bugs.
> - Avoid: Countdowns that restart, or "last chance" claims that are not true.
> - Avoid: Teasing a feature that is not built.
> - A written cadence: weekly rotation, weekend events, content every 2 to 4 weeks
> - Feature freeze at T-10; event public at T-7; featuring submitted if eligible
> - Publish before go-live; content gated by server time
>
> Read more (13 KB note): ## 2. Choosing a cadence · ## 3. Building anticipation honestly · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Roblox players expect games to change. A game that updates on a predictable rhythm trains players to come back on update day, gives the recommendation system fresh reasons to see returning players (play days on days 2 to 7 and 8 to 28 are ranking signals; see [[Discovery and the Algorithm]]), and gives your page, notifications and videos something true to say. A game that updates in random bursts, or that promises an update and misses it, burns the same goodwill.

[[Live Ops Events and Updates]] covers the platform tools (Experience Events, update announcements, notifications) and how to code timed content. This note is about the *shape over time*: how big and how often, how to build anticipation honestly, what the spike after an update looks like and how to read it, how to keep a small team from burning out on a content treadmill, and what to do when an update slips. Platform facts are labelled "Roblox docs (as of October 2026)"; the rest is rule of thumb.

---

## 1. The anatomy of an update spike

Almost every content update produces the same curve:

```
players
  |            ___
  |           /   \__
  |          /       \___
  |    _____/            \_______ new baseline
  |___/ tease
  +---------------------------------------------- time
      T-7    T0  T+2    T+7      T+14
```

- **Tease (T-7 to T0):** small lift from players who saw the event, notification or clip and came back to check.
- **Spike (T0 to T+2):** returning players plus curiosity from new ones. Usually peaks on the first weekend.
- **Decay (T+2 to T+14):** players finish the new content. The speed of decay tells you how much content you shipped relative to how fast players consume it.
- **New baseline:** the number that matters. A good update leaves the baseline higher than before. A spike that returns to the old baseline was a temporary visit, not growth.

### Reading the curve
| Pattern | Meaning |
|---|---|
| Big spike, baseline back to old level in a week | Content was consumed fast; no lasting new goal |
| Small spike, baseline rises | New systems or goals that keep giving (a new collection, a new progression tier) |
| Spike, then baseline *below* old level | The update broke something or annoyed existing players (a nerf, a reset, a bug). Check the error report and economy dashboards ([[Analytics and Funnels]]) |
| No spike at all | Nobody knew (no event, no announcement), or the update was invisible (fixes only) |

Annotate every update on your charts. Without dates, you will misread a school holiday as a successful update.

---

## 2. Choosing a cadence

### The constraint is consumption speed vs production speed
Players consume content far faster than teams produce it. A zone that took two weeks to build may be cleared in two hours by your most engaged players. That gap decides your strategy:

| Approach | How it closes the gap | Cost |
|---|---|---|
| **Frequent small updates** (weekly) | Small goals often | Constant pressure, risk of shallow updates |
| **Larger updates less often** (every 3 to 4 weeks) | Big spikes, room for quality | Long quiet gaps; decay between updates |
| **Systems over content** | Replayable systems (collections, randomised dungeons, ranked modes, trading) produce engagement without new assets | Harder to design; economy risk ([[Economy Inflation Sinks and Faucets Math]]) |
| **Timed events over permanent content** | Limited events reuse existing assets with new rules | Fatigue if every week is an "event" |
| **Rotations** | Weekly shop, weekly quests from a deterministic schedule ([[Live Ops Events and Updates]]) | Low effort after setup; feels stale without new entries |

Most healthy games combine them: a weekly rotation that runs itself, a small event most weekends, and a content update every two to four weeks.

### A sustainable default for a team of 1 to 4

| Rhythm | Content | Who / effort |
|---|---|---|
| Weekly (automatic) | Shop rotation, weekly quests | Data only, from a schedule |
| Most weekends | Boost event (2x currency, luck), or a community goal | Config change + Experience Event |
| Every 2 to 3 weeks | Content update: one new goal for existing players, one improvement for new players | Most of the team's sprint |
| Every 2 to 3 months | Seasonal or major update with a new system | Planned 4 to 6 weeks ahead |

Rule of thumb from small teams: if every update requires overtime, the cadence is too fast. Players notice quality drops faster than they notice a schedule moving from two weeks to three.

### Day and time
- Publish code early in the week; open the event at a fixed time (Friday or Saturday in your main region's afternoon or evening). Separating "publish" from "go live" lets you find release bugs with live servers before the crowd arrives ([[Release Process and Rollbacks]]).
- Use a consistent day. Players who learn "Saturday is update day" come back without a notification.
- Check school holidays and big platform events in your main regions; the same update can spike very differently.

---

## 3. Building anticipation honestly

### The toolkit (Roblox docs, as of October 2026)
- **Experience Events** with **Notify Me**: players get an inbox notification when the event starts. Events appear on your page and, past 1,000 RSVPs and within 7 days of start, can reach the Trending Events sort. Events can be submitted for off-platform featuring at least **7 days** before start.
- **Update announcements**: up to **60 characters**, at most **one every three days**, to players with notifications on. Docs ask for specific text.
- **Experience notifications**: personal, about something that happened to the player; one per user per day; **no dark patterns** such as false time pressure or bait-and-switch.
- **Thumbnails**: a new variant showing the new content added to the personalisation pool ([[Thumbnails Icons and Store Page]]).

### A tease timeline
| When | Action |
|---|---|
| T-10 | Content locked (feature freeze). Event created as private, featuring submission prepared |
| T-7 | Event made public with a unique thumbnail; featuring submitted if eligible |
| T-5 to T-2 | In-game hint: a closed gate, a covered statue, a countdown sign showing the real start time. One short clip off-platform ([[Short-Form Video Marketing]]) |
| T-1 | Publish the update with the new content gated behind the start time |
| T0 | Event starts; update announcement; thumbnail variant on; code live |
| T+1 to T+3 | Watch errors and economy; post clips of real player moments (with consent) |
| T+7 | Retro: spike, decay, new baseline |

### In-game countdowns
A countdown sign is effective when it is true. Drive it from the same deterministic schedule module the server uses, and show the start time in UTC-derived local time from `workspace:GetServerTimeNow()`, not the client's clock.

```lua
--!strict
-- ReplicatedStorage/LiveOps/Countdown (ModuleScript): text for a countdown that
-- matches the server's schedule. The server decides when content unlocks; this is display.
local Countdown = {}

function Countdown.Text(startsAt: number): string
	local now = workspace:GetServerTimeNow()
	local left = math.max(0, math.floor(startsAt - now))
	if left == 0 then
		return "LIVE NOW"
	end
	local d = left // 86400
	local h = (left % 86400) // 3600
	local m = (left % 3600) // 60
	if d > 0 then
		return string.format("%dd %02dh", d, h)
	end
	return string.format("%02dh %02dm", h, m)
end

return Countdown
```

Reviewed, not run. The server still checks the unlock time itself; a client can edit its own sign.

### What counts as a dark pattern here
Roblox's notification rules explicitly forbid false time pressure and bait-and-switch (Roblox docs). Apply that standard everywhere:
- A countdown that restarts when it hits zero is false urgency.
- "Last chance!" on an item that returns next week is false scarcity. If an item may return, say "returns in a future event" or just say nothing.
- A teaser showing a feature that is later cut is bait-and-switch. Only tease what is built.

See [[Ethical Design and Player Trust]].

---

## 4. What an update should contain

Each update should serve more than one audience (rule of thumb):

| Audience | What they need | Example |
|---|---|---|
| Existing engaged players | A new goal above where they are | Next rarity tier, next zone, harder boss |
| Lapsed players | A reason to return and a fast route back to fun | Catch-up boost for returning players, "what's new" panel |
| New players | A better first session | One onboarding fix, faster first reward |
| Social players | Something to do together | Co-op event, group goal |
| Store page visitors | A visible change | New thumbnail, event, accurate "NEW" line in the description |

The new-player item is the one teams skip, and it often has the largest effect on ranking, because first-play bounce and D1 are ranking signals for every new player, every day, not just on update day.

### The update notes
Short, specific, honest:
- What is new, in player words ("New zone: Frost Peaks, 6 bosses, 12 new items").
- What changed in balance, including nerfs. Hidden nerfs are discovered within hours and cost far more trust than an honest line.
- Known issues if any.
- The code, if there is one.

---

## 5. When an update slips

It will happen. What you do decides whether trust survives.

1. **Decide early.** If on T-3 the content is not done, move the date then. Do not ship broken content to hit a date.
2. **Say so plainly** in your community space and the event description: new date, one sentence of why.
3. **Do not leave a countdown running to a date you will miss.** Change the event's start time before it passes; players who RSVPed are watching.
4. **Give something small and real** on the original date if possible: a weekend boost, a cosmetic. Not an apology currency dump that breaks the economy.
5. **Do not split the update** into a hollow "part 1" just to keep the date unless part 1 stands on its own.

Rule of thumb: one honest delay costs little; a pattern of missed dates teaches players to ignore your announcements, and then the tease tools stop working.

---

## 6. The content treadmill and how to step off it

Signs you are on the treadmill:
- Each update's spike is similar or smaller, and the baseline does not rise.
- Players clear new content in hours and ask "when's the next update?" the same day.
- The team has not fixed a known first-session problem in months because every sprint is content.

Ways off (rule of thumb):
- **Ship a system instead of a zone** once in a while: a collection book, a ranked mode, crafting, trading ([[Trading Systems Without Duplication]]), a randomised challenge. Systems create goals without new art.
- **Raise depth, not width**: mastery tiers on existing items, harder versions of existing bosses.
- **Let players create the variety**: social modes, building, private server games.
- **Lengthen the cadence and say so.** Moving from two weeks to four, with bigger updates, is fine if announced.
- **Measure what the update did for the baseline**, not the spike, and drop content types that only spike.

---

## 7. Worked example: two cadences compared

Two small games with similar audiences, illustrative numbers.

**Game A** ships a new zone every week. Each spike is +40% for two days, then back to baseline. After two months the baseline is flat. The team is tired; bugs creep in; one release breaks saves for an hour and the baseline drops 10%.

**Game B** ships every three weeks: one new progression tier, one onboarding improvement, a weekend event between updates driven by config. Spikes are +25%, but each update's baseline ends about 8% above the previous one, mostly from improved D1 among new players. After two months it is ahead of Game A with fewer hours worked.

The lesson is not "slower is better". It is that the baseline, and especially the new-player share of it, is what compounds.

---

## 8. Common mistakes
- Publishing the update and opening it to players at the same moment, with no time to catch release bugs.
- Countdowns that restart, or "last chance" claims that are not true.
- Teasing a feature that is not built.
- Update notes that hide nerfs.
- No new-player improvement in any update for months.
- Reading the spike instead of the new baseline.
- Too many update announcements; docs limit them to one every three days and ask for specific text.
- Every weekend an event, so events stop feeling special.

## 9. Checklist
- [ ] A written cadence: weekly rotation, weekend events, content every 2 to 4 weeks
- [ ] Feature freeze at T-10; event public at T-7; featuring submitted if eligible
- [ ] Publish before go-live; content gated by server time
- [ ] Countdowns driven by the server schedule; no false urgency
- [ ] Every update: a new goal, a returning-player hook, a new-player fix, a visible page change
- [ ] Honest update notes including nerfs
- [ ] Slip plan: move the date early, say so, change the event time
- [ ] Spike, decay and new baseline reviewed at T+7 and T+14

## See also
[[Marketing and Growth Start Here]] · [[Live Ops Events and Updates]] · [[Discovery and the Algorithm]] · [[Retention and Return Hooks]] · [[Release Process and Rollbacks]] · [[Live Content Pipeline]] · [[Global State and Live Config]] · [[Launch Strategy - The First Two Weeks]] · [[Short-Form Video Marketing]] · [[Community Building]]

## Connected notes
<!-- auto-links:start -->
[[Event Calendars and Content Planning]] · [[Patch Notes and Player Communication]] · [[Experience Notifications and Return Prompts]] · [[Live Ops Deep Dive Start Here]] · [[Retention Cohorts]] · [[Roadmaps Milestones and Scope Control]]
<!-- auto-links:end -->
