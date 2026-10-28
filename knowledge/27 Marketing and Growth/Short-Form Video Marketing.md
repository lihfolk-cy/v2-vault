---
tags: [marketing, growth, video, short-form, share-links, content-creators, capture]
---
# Short-Form Video Marketing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Filming in the live game with real players' names visible.
> - Avoid: Opening the clip with a logo or title card.
> - Avoid: Text in the bottom or right edge, covered by the app's UI.
> - Capture place with debug flags clearly marked, lighting matching live
> - UI hide toggle and free camera for clean shots
> - Hook in the first 1 to 2 seconds; text in the safe middle area
>
> Read more (16 KB note): ## 3. Capturing clean footage in Studio · ## 4. Share links and attribution · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

Short vertical video (the 15 to 60 second clips on the big video and social apps) is the cheapest way for a small Roblox team to reach players outside Roblox. It is also the channel with the most ways to go wrong: audiences that skew young, platform rules about children, Roblox's own rules about pointing players off-platform, and a format that rewards exaggeration in ways that hurt a game's real metrics.

This note covers what to film, how to capture it cleanly in Studio, how to attribute the traffic with share links, how off-platform traffic relates to Roblox's payouts and ranking, and where the honesty lines are. Facts about Roblox features are labelled "Roblox docs (as of October 2026)". Facts about video platforms change often and differ by country; they are given as general guidance, not as each platform's current rules. Working with outside creators is covered in [[Working with Content Creators]]; this note focuses on video your own team makes.

---

## 1. Why short-form works for Roblox games (and when it does not)

Roblox games have properties that suit the format:
- **The moment is visual and fast.** A rare drop reveal, a boss's final hit, a tycoon finally filling the screen. Five seconds tells the story.
- **The audience already plays Roblox.** Viewers do not need to install anything new, so the gap between "that looks fun" and "I am in the game" is small.
- **Updates create news.** A new zone or item is a reason to post that is true and timely.

It works poorly when:
- The fun takes ten minutes to arrive (deep strategy, slow-burn horror). Short video can still work, but you film the payoff and the game must deliver it fast, or the viewers bounce on arrival.
- The first session is broken. Video traffic arrives in bursts; a burst into a leaky funnel wastes the one chance a viral clip gives you. Fix the funnel first ([[Launch Strategy - The First Two Weeks]]).
- You are relying on it for ranking. Off-platform players are not counted in Recommended for You signals; the docs say only players who joined organically from Recommended count, though other sources can "accelerate consideration" (Roblox docs, as of October 2026; see [[Discovery and the Algorithm]]).

---

## 2. Formats that work (rule of thumb)

| Format | What it shows | Why it works | Risk |
|---|---|---|---|
| **The reveal** | A roll, hatch or chest opening, cut at the moment of the rare result | Suspense and payoff in under 10 s | Must be a real outcome at real odds; staged "every roll is mythic" clips mislead |
| **The before/after** | Base at minute 1 vs hour 5, character level 1 vs level 100 | Shows progression and promise | Must be reachable by normal play |
| **The fail or chaos moment** | A trap triggering on a group, physics going wild | Shareable, social | Keep other players' names hidden (privacy) |
| **The new thing** | Update content: a boss, a weapon, a zone | News value; returning-player hook | Post when it is live, not weeks before |
| **The devlog** | How you built a system, timelapse of a map | Builds a following of other creators and older players | Slower to convert to plays |
| **The challenge** | "Can you beat this obby with no jumps?" | Invites participation | Avoid dangerous real-world challenges entirely |

### Structure of a clip
1. **Hook (0 to 2 s):** the most interesting frame first. Not a logo, not a title card. Many viewers decide in the first second or two.
2. **Context (2 to 6 s):** one line of on-screen text that says what the game is: "Rolling for a 1 in 10,000 sword".
3. **Payoff (6 to 15 s):** the reveal, the hit, the transformation.
4. **Loop or call to play:** end on a frame that loops back to the start, or a short "Play: [game name] on Roblox". No external URLs in the game itself (see section 6).

Length: 15 to 30 seconds is a safe default. Longer clips need a second payoff.

Text: large, high-contrast, in the centre-safe area. Platform UI covers the bottom and right edges of a vertical video (captions, buttons). Rule of thumb: keep text inside the middle 70% of height and away from the right 15%.

---

## 3. Capturing clean footage in Studio

Vertical video is **9:16, typically 1080x1920**. Roblox games are designed for landscape; plan the shot.

### A capture place
Keep a copy of the game as a capture place (the same idea as the thumbnail "photo booth" in [[Thumbnails Icons and Store Page]]):
- Debug flags to grant items, set luck to the real odds or force a specific roll **for capture only**. Label these clearly; never ship them enabled in the live place.
- A free camera script for smooth moves, or cutscene tools ([[Cameras and Cutscenes]]).
- Lighting identical to the live game. Video thumbnails on the store page forbid graphics enhanced beyond what players see (Roblox docs); off-platform videos are not reviewed by Roblox in the same way, but the same honesty rule keeps your bounce rate down.

### Hiding the UI and framing for vertical
```lua
--!strict
-- LocalScript in the capture place only: toggles all ScreenGuis and the CoreGui
-- for clean footage. Bind to a key so the recording operator can flip it.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local hidden = false

local function setHidden(value: boolean)
	hidden = value
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			gui.Enabled = not value
		end
	end
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not value)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F8 then
		setHidden(not hidden)
	end
end)
```

Reviewed, not run. A ScreenGui disabled this way stays disabled until toggled back; if your UI code re-enables guis on state changes, it will fight this script, so add a `CaptureMode` attribute your UI checks instead.

Framing tips (rule of thumb):
- Record landscape at the highest resolution your monitor allows, then crop a 9:16 window in your editor. Keep the subject in the centre third of the landscape frame so the crop holds it.
- Or resize the Studio window to a tall shape for shots that must be native vertical (a falling sequence, a tall tower).
- Use the game's real VFX and sound; sound design sells reveals ([[Combat Sound Design and Feedback]], [[Game Feel and Juice]]).
- Music: use audio you have rights to use off-platform. Roblox's audio library licences cover use inside Roblox; whether a given track may be used in an external video depends on its licence, which this note could not confirm generally. Use your own music or a licence that explicitly covers social video.

### Other players in footage
Do not show other players' usernames or display names without consent, and do not record voice chat. Film with your team's accounts or test accounts in a private server. This protects players (many are children) and avoids takedown requests.

---

## 4. Share links and attribution

Share links are unique trackable links created in the Creator Dashboard (Creations, Share Links tab), as many as you like per game, optionally carrying custom LaunchData; their analytics show new users reaching the game page through each link and which channel brought the most engaged users (Roblox docs, as of October 2026).

Practical setup:
- **One link per channel and per campaign**: `video_a`, `video_b`, `bio`, `update_oct`. The docs recommend a separate link per channel.
- **LaunchData** for a small, fair welcome perk (a cosmetic, a starter boost). Because anyone can copy the link, treat LaunchData perks as public: never a valuable or tradeable item, and never stackable with repeated joins. See the whitelisting pattern in [[Sponsored Ads and Campaign Math]].
- Read the join source on the server and log it as a funnel field so you can compare the D1 of video viewers with organic players ([[Analytics and Funnels]]).

### Why share links matter financially
Creator Rewards' **Audience Expansion** pays the creator a **35% revenue share on a new or reactivated user's first $100 of qualifying purchases** anywhere on Roblox in their first 60 days, when the user arrives through your Share Link (or a direct link or a name search) and plays 10+ minutes that day; reactivated users must have been inactive for 60 consecutive days; the experience must average 100+ DAU for the 60 days after; one reward per user; you need an ID-verified account in good standing (Roblox docs, as of October 2026). Qualifying purchases are Robux, Premium and UGC subscriptions.

So a video that brings genuinely new players to Roblox through your share link can earn you money even if those players never buy anything in your game, provided they meet the rules. That changes the value of short-form traffic compared with sponsored ads, where I could not confirm that ad-acquired users qualify (see that note). The docs say the framework may change; check the Creator Rewards page before planning around it.

---

## 5. Platform and audience rules you must respect

This section is general. Each video platform has its own terms, minimum ages and children's content rules, and laws differ by country. Read the current terms of each platform you post on.

- **Minimum ages.** Major short-video apps generally require users to be at least 13 in most countries (and older in some). If your team includes members under that age, they should not run the accounts; a parent or adult team member should.
- **Children's audiences.** Some platforms require you to declare whether content is made for children, which limits comments, personalised ads and features on that video. Roblox content often attracts children; answer such questions honestly, as misdeclaring can bring penalties under children's privacy laws in some countries.
- **Paid promotion disclosure.** If you pay a creator, or a creator pays you, or you give items in exchange for coverage, the video must disclose it in a way the audience understands. A 2023 review by the US Children's Advertising Review Unit found that some Roblox-related influencer content did not disclose clearly enough for children and suggested child-friendly wording such as "I get paid when you use my code". See [[Working with Content Creators]].
- **No "free Robux".** Promising free Robux, fake giveaways or "codes for Robux" in a video is a scam pattern under Roblox's Community Standards and will get both the video and possibly the game reported.

---

## 6. Inside the game: what you may and may not say

Roblox's Community Standards say you may not link to, share or display URLs of external websites or services, except through the Social Links feature, which requires an age check and is shown to users 16+ (as of October 2026; see [[Age Checks and Safety Features]]). Content with off-platform calls to action falls under Roblox's Advertising Standards and must be registered through ad integrations, even when you promote your own content (Roblox docs).

In practice:
- Do not put "Follow us on [app] at [handle]" in a sign, billboard or UI in your game unless you have confirmed it is permitted and registered where required.
- Use the game page's Social Links (16+ visibility) and your Roblox group for pointers.
- Put **codes** in the update notes, event description and video captions; players type them into your codes UI ([[Codes Redemption System End to End]]).
- Do not create a game "solely to send users off Roblox"; it is listed as prohibited under "Repetitive and Misleading Content" (Community Standards).

---

## 7. A posting cadence a small team can sustain

| Cadence | Content | Effort |
|---|---|---|
| 3 to 5 per week | Reveals and chaos moments cut from playtests | 20 to 40 min each once the capture place exists |
| Per update | One "new thing" clip on update day, posted when the update is live | 1 to 2 hours |
| Monthly | One devlog or timelapse | Half a day |

Rule of thumb: most clips get modest views; a few get far more. Volume and consistency beat polish on any single clip. Track per-channel share link visits and D1 of those players; stop formats that bring clicks but not players who stay.

### Worked example: tying video to update day
1. Monday: update published, servers restarted ([[Release Process and Rollbacks]]).
2. Wednesday: capture place updated, three clips recorded: the new boss's entrance, a rare drop of the new item at real odds, a before/after of the new zone.
3. Friday at the event start: post clip 1 with the share link `upd_boss`, the update announcement goes out, the event opens ([[Live Ops Events and Updates]]).
4. Saturday and Sunday: clips 2 and 3 with their own links.
5. Next Friday: compare link visits, D1 and session time per link; keep the format that brought players who stayed.

---

## 8. Dishonest tactics and why they backfire

| Tactic | Why it backfires |
|---|---|
| Faked rare drops (debug flag on, presented as normal play) | Viewers who arrive expecting fast rare drops bounce; comments call it out; bounce rate is a ranking signal |
| Showing content not in the game ("coming soon" presented as live) | Same bounce problem; erodes trust before the content exists |
| "Free Robux" or "free admin" hooks | Scam pattern; reports against the game; attracts players looking for exploits |
| Bought views or bot followers | Inflates a vanity number; share link data shows no new players, so you learn nothing; may break the platform's terms |
| Reaction bait about other games or creators | Drama attracts the wrong audience and can stray into harassment or impersonation (both against Community Standards) |
| Copying another game's footage or thumbnails | IP infringement; confusingly similar content is a Community Standards issue |

The underlying principle: short-form views are not a Roblox metric. The Roblox metrics are play-through, bounce, retention and spend. A clip is good if the players it brings stay. Measure that with share links, not with view counts.

---

## 9. Common mistakes
- Filming in the live game with real players' names visible.
- Opening the clip with a logo or title card.
- Text in the bottom or right edge, covered by the app's UI.
- One share link for everything, so no channel can be compared.
- LaunchData that grants valuable items, which spread across the internet.
- Posting an update clip days before the update is live.
- Using music without a licence for social video.
- Treating views as success without checking D1 of the arrivals.

## 10. Checklist
- [ ] Capture place with debug flags clearly marked, lighting matching live
- [ ] UI hide toggle and free camera for clean shots
- [ ] Hook in the first 1 to 2 seconds; text in the safe middle area
- [ ] Real odds and real content in every clip
- [ ] No other players' names or voices without consent
- [ ] One share link per channel and campaign; LaunchData perks small and whitelisted
- [ ] Join source logged as a funnel field; D1 per link reviewed weekly
- [ ] No external URLs inside the game outside Social Links
- [ ] Paid relationships disclosed in child-friendly words
- [ ] Accounts run by adults; each platform's terms read

## See also
[[Marketing and Growth Start Here]] · [[Working with Content Creators]] · [[Discovery and the Algorithm]] · [[Thumbnails Icons and Store Page]] · [[Update Cadence and Hype Cycles]] · [[Community Building]] · [[Age Checks and Safety Features]] · [[Subscriptions and Premium Payouts]] · [[Icon and Thumbnail Rendering Pipeline]]

## Connected notes
<!-- auto-links:start -->
[[Discord Servers for Roblox Games]] · [[Community and Moderation Start Here]] · [[Ads and Rewarded Video]] · [[Click-Through Rate]] · [[Friend Invites Referrals and Experience Invites]] · [[Legal Basics - IP Licenses and Assets]]
<!-- auto-links:end -->
