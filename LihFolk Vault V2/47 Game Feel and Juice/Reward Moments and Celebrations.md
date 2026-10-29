---
tags: [game-feel, juice, rewards, celebrations, ui, rng, pacing, ethics, luau, type/guide, area/game-feel, level/intermediate]
---
# Reward Moments and Celebrations

<!-- tldr:start -->
> [!tldr] TL;DR
> - Collection grind feels slow despite pretty reveals: Reveal time not budgeted per hour -> Tier ladder, compact auto mode, skip after first view
> - Big drops do not feel big: Lower tiers already use the strongest channels -> Reserve world dimming and HUD hiding for the top tiers
> - Players accuse the game of rigging: Reels show unreachable items, or tells are random -> Reel from the real pool; tells driven by the result
> - A tier ladder with lengths and layers; each tier adds layers.
> - Reward animation time measured per hour of play, under about 10%.
> - Server decides results before animation; reels show only reachable items; tells derive from the result.
>
> Cost: TL;DR ~210 tok · whole note ~4.9k tok. Read more: ## 3. Honest suspense · ## 5. A queue that waits for safe moments · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A reward moment is the few seconds between "something good is coming" and "it is mine". Done well, it is the emotional peak of a session and the moment players clip and share. Done badly, it is a forced cutscene the hundredth time, a banner that covers the boss, or a reveal that lies. [[Game Feel and Juice]] gives the basic sequence (anticipation, reveal, payoff, settle) and the reference project's gating of popups; [[Notification and Toast Systems]] covers small, frequent messages. This note covers the big ones: how long each tier should take and what that costs over a session, honest suspense, manual versus automatic modes, a queue that waits for safe moments without starving, count-ups, social celebrations, and the accessibility rules that apply to flashing, full-screen moments.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Intensity is a budget, not a style

Every celebration spends three things: the player's **time**, their **attention** (the screen is not theirs while it plays), and their **sensitivity** (each big moment makes the next one feel smaller). Treat them as budgets.

### Time cost

The time cost is easy to underestimate because each reveal feels short in isolation. Multiply by frequency:

| Reveal length | Opens per hour | Time spent watching per hour |
|---|---|---|
| 0.5 s | 600 (an auto-roller) | 5 minutes |
| 1.5 s | 200 (an active egg opener) | 5 minutes |
| 3 s | 200 | 10 minutes |
| 6 s | 30 (rare high tiers only) | 3 minutes |

Rule of thumb: total time spent in reward animations should stay under about 10% of play time, and the player should be able to cut it further. A collection game where 20% of the session is waiting for reels feels slow even when every single reveal is pretty.

### A tier ladder

Map each rarity tier to a length and a set of layers. The ladder is the single most useful artefact for keeping celebrations consistent across a growing game (rule of thumb values; tune to your rarity distribution, see [[Rarity Ladders and Drop Pacing Math]]):

| Tier share of drops | Length | Layers |
|---|---|---|
| Common (most drops) | 0.3 to 0.5 s | Card pop, soft sound, count-up |
| Uncommon | 0.6 to 0.8 s | Plus rarity colour wash and a brighter sound |
| Rare | 1.0 to 1.5 s | Plus a burst of particles, a short riser before the reveal |
| Epic | 2 s | Plus a screen-edge glow, a banner, a short camera FOV punch |
| Legendary | 3 to 4 s | Plus a full-screen colour flash (within flashing limits), stronger shake, music sting |
| Top one or two tiers | 5 to 6 s | Plus world dimming, HUD hidden, a server-wide announcement |

Two principles hold the ladder together:

- **Each tier adds layers; it does not just get louder or longer.** The jump from Rare to Epic should be visible in what appears, not only in how long it lasts. This mirrors the "escalate with layers, not decibels" rule from [[Combat Sound Design and Feedback]].
- **Reserve whole channels for the top.** If only the top two tiers ever dim the world and hide the HUD, players learn that "the world went dark" means something extraordinary, and the moment does its job before the item even appears. Using that channel for Epic too wastes it.

---

## 2. The four beats, in seconds

The anticipation, reveal, payoff and settle sequence from [[Game Feel and Juice]] needs numbers to be reusable. For a Legendary reveal of about 3.5 s (rule of thumb):

| Beat | Time | What happens |
|---|---|---|
| Anticipation | 0.0 to 1.2 s | Container shakes with growing amplitude, a riser rises in pitch, light leaks from the seams |
| Reveal | 1.2 to 1.5 s | Flash (one frame white, or a rarity colour), burst, item appears at 1.15x with an instant squash and spring back |
| Payoff | 1.5 to 3.0 s | Name and rarity banner slide in, stats count up, music sting peaks, particles drift |
| Settle | 3.0 to 3.5 s | Background effects fade, buttons appear (Equip, Continue), input returns |

Details that matter:

- **The sound peak lands on the reveal frame, not after it.** A riser that peaks exactly as the flash fires is the strongest single trick in the sequence; see [[Feedback Timing - Sound Visual and Haptic Sync]] for why the riser can deliberately lead the visual here.
- **Buttons appear last**, and the primary one becomes clickable only after a short delay (about 0.3 s, rule of thumb). Otherwise players mashing "open" to skip will accidentally confirm the next purchase or dismiss an item they wanted to inspect.
- **The anticipation hides the server round trip.** The client should send the request on press and play anticipation immediately; the reveal waits for the reply. The latency mask pattern is in [[Squash Stretch and Anticipation in UI and Characters]].

---

## 3. Honest suspense

Anticipation is suspense, and suspense in a reward system can easily turn into deception. The line matters for player trust in general ([[Ethical Design and Player Trust]]), and for paid random items it also touches platform policy and odds disclosure ([[Paid Random Items and Odds Disclosure in Practice]]). Rules that keep suspense honest:

### The server decides first, the animation follows

The result is rolled on the server before any reveal animation begins, and the animation is built to **land** on that result. Never animate a spinning reel and then pick the result where it stops: a client-side pick is exploitable, and a reel whose physics decides the outcome would need to be identical on every client to be fair.

### The reel shows only what was possible

A spinning reel or a carousel of possibilities is a claim: "these are the things you could have got". It must show only items from the pool this player could actually have received **at this moment**. The reference project capped both the reel contents and its near-miss tiles by the current world's maximum rarity, so players in an early world never saw a top-tier item flash past that they had zero chance of getting (measured in the reference project). That is the right default.

### Escalating tells must be driven by the actual result

A popular pattern is a tell that escalates during anticipation: the egg glows blue, then purple, then gold. There are two ways to build it:

| Approach | What the tell means | Honest? |
|---|---|---|
| Tell derived from the result | Gold glow means the result is at least Legendary | Yes. The tell is early information, and players love it |
| Tell randomised for drama | Gold glow sometimes ends in a Common | No. It manufactures a near-miss feeling the outcome does not support |

The first version is as exciting and does not erode trust. It also makes clips better: a gold glow is the start of the clip.

### Near misses

A reel that slows down and stops one tile past the rare item feels exciting, which is exactly why it is controversial: it suggests "almost", when the result was fixed before the reel moved. For free rewards, a mild landing animation is common practice; for paid random items, avoid engineered near misses entirely (rule of thumb, and the conservative reading of trust and policy concerns). If you show neighbouring tiles at all, draw them from the real distribution, not from the rarest items.

---

## 4. Manual and automatic modes

Repeated rewards (auto-rolling, auto-hatching, idle collection) cannot use full-screen reveals at all; the player would never see the game. A pattern that works:

- **Manual action, full reveal.** The reference project's manual roll used a roll screen: world dimmed, HUD hidden, the automatic-mode toggle moved to the bottom centre (measured in the reference project).
- **Automatic action, compact reveal.** The same roll in automatic mode showed a small reel over the character's head, leaving the screen and controls alone (measured in the reference project).
- **Threshold interrupts.** In automatic mode, only results at or above a player-chosen tier escalate to the full reveal. Default the threshold to the top two tiers; let players lower it.
- **Banner text for the top.** The reference project put tier-named banner text ("... PULL!") on its highest tiers only, which made those few moments recognisable in clips.

The same split works for any repeated reward: a damage number versus a level-up, a coin versus a chest, a quest step versus a quest completion.

---

## 5. A queue that waits for safe moments

Rewards often arrive together: a kill drops an item, completes a quest and levels you up in the same frame. They also arrive at bad times: mid-fight, during a cutscene, while a shop panel is open. The reference project's celebration popups were suppressed during the tutorial and waited out cutscenes, deaths and open panels for up to 20 s (measured in the reference project, described in [[Game Feel and Juice]]). Going deeper, a queue needs four properties:

1. **Priority.** Higher tiers and rarer events go first. A level-up outranks a quest step.
2. **Merging.** Same-kind rewards in a short window combine ("+3 items" with the best one shown).
3. **Safe moments.** A predicate that says the player can be interrupted: not in combat in the last few seconds, no cutscene, not dead, no blocking panel open.
4. **Anti-starvation.** A reward that has waited too long downgrades to a toast instead of waiting forever. A player in constant combat would otherwise never see their level-up.

And one more that is easy to miss: **compression**. When the queue holds more than about three big moments, play them in a compressed form (each at its tier's length times 0.5, rule of thumb), or a long fight's backlog will turn into a 30 second slideshow.

```lua
--!strict
-- RewardQueue: prioritised, merged, safe-moment-aware celebration queue (client).
local RewardQueue = {}

export type Reward = {
	kind: string,          -- "Item", "LevelUp", "Quest", ...
	tier: number,          -- 1 common .. 6 top tier
	payload: any,          -- whatever the presenter needs
	count: number,         -- merged count
	queuedAt: number,
}

export type Presenter = (reward: Reward, compressed: boolean) -> () -- yields until done
export type Toast = (reward: Reward) -> ()                          -- quick, non-blocking

local MERGE_WINDOW = 0.6       -- seconds
local MAX_WAIT = 20            -- seconds before downgrading to a toast
local COMPRESS_AT = 3          -- queued big moments before compressing
local BIG_TIER = 3             -- tiers below this never block; they toast immediately

local queue: { Reward } = {}
local running = false
local presenter: Presenter? = nil
local toast: Toast? = nil
local isSafe: () -> boolean = function()
	return true
end

function RewardQueue.configure(p: Presenter, t: Toast, safe: () -> boolean)
	presenter = p
	toast = t
	isSafe = safe
end

local function sortQueue()
	table.sort(queue, function(a: Reward, b: Reward): boolean
		if a.tier ~= b.tier then
			return a.tier > b.tier
		end
		return a.queuedAt < b.queuedAt
	end)
end

local function pump()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local now = os.clock()
			-- Downgrade anything that has waited too long.
			for i = #queue, 1, -1 do
				local r = queue[i]
				if now - r.queuedAt > MAX_WAIT then
					table.remove(queue, i)
					if toast then
						toast(r)
					end
				end
			end
			if #queue == 0 then
				break
			end
			if not isSafe() then
				task.wait(0.25)
				continue
			end
			sortQueue()
			local nextReward = table.remove(queue, 1)
			if nextReward and presenter then
				presenter(nextReward, #queue + 1 >= COMPRESS_AT)
			end
		end
		running = false
	end)
end

function RewardQueue.push(kind: string, tier: number, payload: any)
	local now = os.clock()
	if tier < BIG_TIER then
		if toast then
			toast({ kind = kind, tier = tier, payload = payload, count = 1, queuedAt = now })
		end
		return
	end
	-- Merge with a same-kind, same-tier reward that arrived moments ago.
	for _, r in queue do
		if r.kind == kind and r.tier == tier and now - r.queuedAt < MERGE_WINDOW then
			r.count += 1
			r.payload = payload -- keep the latest; the presenter shows "x count"
			return
		end
	end
	table.insert(queue, { kind = kind, tier = tier, payload = payload, count = 1, queuedAt = now })
	pump()
end

return RewardQueue
```

A typical `isSafe` checks a `CutsceneLock` attribute, the character's health, the time since the player last dealt or took damage (3 s is a good threshold, rule of thumb), and whether a blocking panel is open. Keep the predicate cheap; it runs four times a second while anything waits.

Rewards are **granted** on the server when earned, never when the celebration plays. The queue is presentation only. A player who leaves mid-queue still has everything ([[Purchase Data and Receipts]] for the purchase case).

---

## 6. Count-ups that feel right at every scale

Snapping numbers feel like a spreadsheet, but a count-up that takes the same time for +5 and +5,000,000 is wrong at one end. Scale duration with the logarithm of the gain (rule of thumb):

```
duration = clamp(0.35 + 0.22 x log10(gain), 0.35, 1.8)
```

That gives 0.35 s for +1, about 0.57 s for +10, 1.0 s for +1,000 and 1.67 s for +1,000,000. Ease with Quad Out or Exponential Out so most of the change happens early ([[UI Motion Language and Timing]] lists easing choices).

Ticks are the other half: a soft tick sound while counting, with rising pitch, makes a count-up satisfying. Two rules (rule of thumb): limit ticks to about 12 to 20 per second regardless of how fast the digits change, and raise pitch across the count by about four to seven semitones total, then play a distinct "done" sound on the final value. Update the label text at a capped rate too (about 30 Hz); every text change re-shapes the string.

---

## 7. Social celebrations

A top-tier drop is a social event. Other players seeing it is part of its value, and it advertises the reward to everyone else in the server.

| Audience | What they see (rule of thumb) |
|---|---|
| The winner | The full reveal |
| Players nearby | A light beam or aura over the winner for a few seconds, a compact sound |
| The whole server | A one-line banner: display name, item, tier colour |
| Other servers | Optional, only for the rarest tier, via cross-server messaging ([[Cross-Server Messaging]]) |

Rules:

- **Rate-limit announcements.** No more than one server banner every few seconds, merged when several arrive. During an event with boosted luck the banner channel can flood.
- **Announce the rare, not the routine.** If a tier drops several times an hour in a full server, it is not banner-worthy.
- **Let players opt out of seeing others' banners**, and keep the winner's own reveal unaffected by that setting.
- **Never celebrate paid results more loudly than earned ones of the same tier.** Doing so turns the banner into an ad that pressures other players.

---

## 8. Firsts, milestones and fatigue

The same Legendary is worth less the tenth time. Two adjustments keep moments fresh (rule of thumb):

- **First-of-a-kind gets the full sequence**, repeats get the compressed one. A "NEW" stamp on first discoveries is cheap and powerful, especially in collection games ([[Genre Playbook - RNG and Collection Games]]).
- **Milestones outrank their tier.** Level 10, the first boss kill, the collection reaching 50% deserve a bigger moment than their raw value. They are progress, which is the story of the session ([[Progression and Pacing Design]]).

And one subtraction: **skippable after the first time**. A tap anywhere after about 0.5 s jumps to the payoff (not past it; the player still needs to see what they got). A setting can make high-tier reveals always compact.

---

## 9. Accessibility for big moments

Big reward moments combine the things that cause problems: flashes, shakes, loud stings and full-screen takeovers.

- **Flashing.** Keep full-screen flashes to at most three in any one second (the WCAG 2.3.1 "three flashes" guideline), and prefer one. Large saturated red flashes are the most problematic. A colour wash that fades in over 0.1 s is gentler than a hard cut. See [[Motion Sensitivity and Camera Comfort]].
- **Reduced motion.** `GuiService.ReducedMotionEnabled` reflects the platform preference (read-only, Roblox docs as of October 2026); combine it with your own setting. Keep the information (tier colour, banner, sound) and remove shake, zoom and particle storms.
- **Sound-independent.** Tier must be readable without audio: colour plus text label plus shape, not colour alone ([[Colour-Blind Safe Design]]).
- **Time.** Never put a timed decision (accept within 5 s) inside a celebration.

---

## 10. When not to celebrate

- **Losses disguised as wins.** Celebrating a reward worth less than what was spent to get it ("You won 5 coins!" after paying 50) is a known dark pattern from gambling machines. Scale the celebration by net value, or not at all.
- **Purchases themselves.** Confirm a purchase clearly; celebrate what it gives, not the act of spending.
- **Mid-combat**, unless the reward is the combat result (a boss kill). Queue it.
- **For other players' failures.** No celebration that frames someone else's loss as your win in front of them.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Collection grind feels slow despite pretty reveals | Reveal time not budgeted per hour | Tier ladder, compact auto mode, skip after first view |
| Big drops do not feel big | Lower tiers already use the strongest channels | Reserve world dimming and HUD hiding for the top tiers |
| Players accuse the game of rigging | Reels show unreachable items, or tells are random | Reel from the real pool; tells driven by the result |
| Level-up never shows during long fights | Queue waits for safe moments forever | Max wait, then downgrade to a toast |
| Accidental confirms after reveals | Buttons clickable the moment they appear | Delay the primary button about 0.3 s |
| Server chat flooded with banners in events | No rate limit, tier too common | Merge, rate-limit, raise the announcement tier |
| Count-up for huge numbers drags | Duration linear in value | Log-scaled duration, capped |

## Checklist

- [ ] A tier ladder with lengths and layers; each tier adds layers.
- [ ] Reward animation time measured per hour of play, under about 10%.
- [ ] Server decides results before animation; reels show only reachable items; tells derive from the result.
- [ ] Manual and automatic modes, with a player-set interrupt tier.
- [ ] Queue with priority, merging, safe moments, max wait and compression.
- [ ] Count-ups log-scaled, ticks capped, a distinct final sound.
- [ ] Social banners rate-limited, optional for viewers, not louder for paid results.
- [ ] Flash limits, reduced motion, colour plus text for tiers.
- [ ] No celebrations for net losses.

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · [[RNG Drops and Luck Systems]] · [[Juice on a Budget - Mobile and Low-End]] · Simulator and RNG Genre Teardown · Accessibility · Variance
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Simulator and RNG Genre Teardown]] · [[Pity Timer]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Drop Tables Rarity and Pity Systems]] · [[Input Responsiveness Buffering and Coyote Time]]
<!-- related:end -->
