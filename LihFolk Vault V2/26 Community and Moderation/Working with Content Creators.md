---
tags: [community, creators, influencers, marketing, safety, live-ops, luau, type/guide, area/community, level/intermediate, api/AnalyticsService, area/scripting]
---
# Working with Content Creators

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Paying for a video without disclosure in the agreement.
> - Avoid: Scripting praise or forbidding criticism.
> - Avoid: Admin powers or rigged luck for a creator on camera.
> - Game filmable: hide-UI mode, fast start, readable big moments, private servers
> - Creator fit checked: genre, audience age, conduct
> - Written agreement with disclosure, honesty, payment and guardian terms
>
> Cost: TL;DR ~140 tok · whole note ~3.9k tok. Read more: ## 1. Safety first · ## 5. Deals and agreements · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

Video creators (long-form, short-form and live streamers) are the biggest single source of sudden traffic for Roblox games. One video can bring more players in an afternoon than a month of sponsored ads. Working with them well is part craft (making the game filmable), part relationship (finding the right creators and treating them fairly), part logistics (surviving the surge) and part ethics: their audiences are mostly children, and paid promotion aimed at children carries obligations. This note covers all four, plus how to measure what a collaboration did. The marketing side is expanded in [[Short-Form Video Marketing]] and [[Launch Strategy - The First Two Weeks]]; in-game social features in [[Community Building]].

Facts are labelled "Roblox docs (as of October 2026)", "Announcement", "measured in the reference project" or "rule of thumb". This is general information, not legal advice; advertising disclosure rules differ by country.

---

## 1. Safety first

- **The audience is young.** Anything you ask a creator to say reaches children. No pressure tactics ("buy before it's gone"), no implied free Robux, no exaggerated odds, no thumbnails that misrepresent the game. These backfire too: Roblox moderates misleading content, and a misled audience leaves fast ([[Ethical Design and Player Trust]]).
- **Disclose paid promotion.** In many countries paid or gifted promotion must be clearly labelled as an ad (for example under consumer protection and advertising rules); platforms such as YouTube and TikTok have their own paid-promotion labels. Put "the creator must disclose the partnership using the platform's tools" in every agreement. Check the rules where you and the creator live.
- **Many creators are minors.** Contracts, payments and NDAs with a minor need a parent or guardian ([[Commissions Pricing and Contracts]], [[Hiring Freelancers and Revenue Shares]]). Communicate with young creators where a parent can see, never in private DMs from an adult staff account.
- **No off-platform funnels for children.** Do not ask creators to send their viewers to your Discord or anywhere else outside Roblox in a way that targets young viewers; social links are already restricted to age-checked 16+ on Roblox pages (Announcement, June 2026; [[Discord Servers for Roblox Games]]).
- **No rule-breaking traffic.** The [[Creator Rewards]] program prohibits bots, automated tools, manipulated teleports, encouraging alt accounts and impersonation; violations can forfeit rewards or end in account termination (Roblox docs). A creator who promises "guaranteed players" with bots is a liability, not a partner.
- **No special in-game powers for creators.** Admin commands, invisible moderation tools or rigged luck for a creator's video mislead viewers and break trust. Give creators access to things players could also see (a private server, a preview build), not hidden advantages.

---

## 2. Why creators matter on Roblox specifically

- **Discovery signals.** New players who arrive and stay boost the engagement signals discovery uses ([[Discovery and the Algorithm]]).
- **Audience Expansion pays you for new and returning players** (Roblox docs, Creator Rewards): a new or reactivated user who clicks your game's share link and joins, plays 10+ minutes that day, in a game averaging 100+ DAU for 60 days after the join, earns you a 35% share of their first $100 of qualifying purchases in their first 60 days. Requires an ID-verified account in good standing; for group games, a member who can configure group revenue must be ID-verified.
- **Video Stars.** Roblox's Video Stars program lets member influencers earn Daily Engagement and Audience Expansion rewards themselves (Roblox docs). Creators in it have their own reason to send viewers to games with share links.
- The old Creator Affiliate program (affiliate share links paying up to 50% of a new user's Robux purchases) was deprecated in July 2025 and replaced by Creator Rewards (Roblox docs). Ignore older guides that describe it.

---

## 3. Make the game filmable before you contact anyone

Creators choose games that make good videos. Rule-of-thumb checklist:

| Feature | Why |
|---|---|
| Hide-UI toggle and a free camera or photo mode | Clean shots; the docs cite a well-known roleplay game's creator camera as an example |
| Readable big moments | Rare drops, boss kills, transformations with clear audio and VFX ([[Game Feel and Juice]]) |
| Fast start | A creator will not film a 10-minute tutorial; get to the fun in under a minute ([[First-Time User Experience and Onboarding]]) |
| Private servers | Creators play with fans or friends without random disruption |
| Events at predictable times | Creators plan videos around them ([[Live Ops Events and Updates]]) |
| Codes | A creator-specific code gives viewers a reason to try ([[Menu Archetypes - Shop Settings Codes Rewards]]) |
| Stable servers under a surge | Section 6 |

### A minimal creator camera mode

```lua
--!strict
-- LocalScript: toggle HUD visibility for recording. Reviewed, not run.
-- Hides your ScreenGuis tagged "HUD"; core GUI stays as the player chooses.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local hidden = false

local function setHidden(value: boolean)
	hidden = value
	for _, gui in CollectionService:GetTagged("HUD") do
		if gui:IsA("ScreenGui") then
			gui.Enabled = not value
		end
	end
end

ContextActionService:BindAction("ToggleCreatorCam", function(_, state)
	if state == Enum.UserInputState.Begin then
		setHidden(not hidden)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)
```

Keep a visible way back (a small corner button on touch devices) so a player who hides the HUD by accident is not stuck ([[HUD Design]], [[Gamepad and Console UX]]).

---

## 4. Finding the right creators

Rule of thumb:
- **Fit beats size.** A creator with 50,000 subscribers who plays your genre every day converts better than a 2-million creator who plays everything once. Look at their last 20 videos: genre, viewer age (comments are a clue), and whether they return to games.
- **Watch their thumbnails and titles.** If they routinely use misleading thumbnails ("FREE ROBUX", fake rare items), their audience trusts less and your game may be associated with it.
- **Check their conduct.** Search for past controversies. A partnership is a public association.
- **Short-form creators** generate many small spikes; long-form creators fewer, larger, longer ones; streamers bring concurrent players at a specific hour ([[Short-Form Video Marketing]]).
- **Your own players** who make videos are the best early partners. They already understand the game.

How to approach: one short message through their business contact (never DMing a minor directly), what your game is, why it fits their content, what you offer, and a link to the official game page. No pressure, no follow-up spam.

---

## 5. Deals and agreements

| Model | How it works | Watch out for |
|---|---|---|
| Free access and a heads-up | Early access to an update, a code | Cheapest; works for small creators who like the game |
| Flat fee per video | Payment for a dedicated video or segment | Agree the deliverable (length, date, disclosure), not the opinion |
| Fee plus performance bonus | Bonus by share-link joins or retained players | Define the metric and its source before starting |
| Revenue share | Percent of game revenue for a period | Complex to track; time-limit it; usually only for creators who become partners |
| Cosmetic collaboration | A creator-themed cosmetic | IP and likeness rights in writing; who owns the design; what happens if the partnership ends |

Every agreement, even informal, should say (rule of thumb, not legal advice):
- What is delivered and by when.
- That the creator discloses the partnership using the platform's tools.
- That the creator gives an honest opinion; you do not script praise or forbid criticism.
- What the creator must not say (no false claims about odds, rewards or "free Robux").
- Payment, in what currency and how (Robux group payouts or money; [[DevEx and Cashing Out]] for the Robux side).
- For minors, the parent or guardian's agreement.
- What happens if either side has a public controversy.

Paying in Robux through group one-time payouts is possible (Roblox docs, Groups), but a creator who is not a group member must join first, and the payment becomes visible in your group finances. Large or recurring deals are usually better as normal business payments ([[Running a Small Studio as a Business]]).

**Early access and NDAs.** Giving a creator a preview build means giving them access to a private place (Playtest permission on a test place, [[Groups Roles and Permissions for Studios]]). Assume anything you show leaks. NDAs with minors need a guardian and are rarely worth it; show only what you would be fine seeing early.

---

## 6. Surviving the surge

A creator video can multiply concurrent players 10 to 50 times within an hour (rule of thumb; varies hugely). What breaks:

| Weak point | Prevention |
|---|---|
| Data store budget on join and leave | Per-server budgets scale with players; avoid extra reads on join ([[DataStore Fundamentals]], [[Saving Correctly - Autosave and BindToClose]]) |
| Join time | Fast join and deferred loading ([[Case Study - Fast Join and Deferred Loading]]) |
| New-player funnel | Onboarding tested with fresh accounts ([[First-Time User Experience and Onboarding]]) |
| A bug the creator hits on camera | Freeze risky changes for 48 hours before a known video ([[Release Process and Rollbacks]]) |
| Code redemption flood | Server-side validation and rate limits ([[Codes Redemption System End to End]]) |
| Moderation | Extra moderators during the video premiere; new players are targets for scams ([[Player Reports and In-Game Moderation]]) |
| Live config not ready | A kill switch for any new feature ([[Global State and Live Config]]) |

Coordinate the date. Ask the creator to tell you when the video goes live; a surprise video during a broken update is the worst case.

---

## 7. Measuring a collaboration

Signals, in order of trust (rule of thumb):
1. **Share link analytics**: clicks, signups, reactivations and estimated payout per link (Roblox docs, Creator Rewards). Whether you can create a separate share link per creator for clean attribution was not something I could confirm on the docs page (unverified); if you can, do it.
2. **Creator codes**: a code per creator is a clean attribution signal for players who redeem it. Log redemptions as a custom analytics event.
3. **CCU and new-user curves** around the video's publish time ([[Analytics and Funnels]]).
4. **Retention of the cohort**: day-1 and day-7 retention of users who joined in the 24 hours after the video, compared with your baseline.

```lua
--!strict
-- Server: attribute a creator code redemption once per player. Reviewed, not run.
-- Assumes your codes module has already validated and granted the code.
local AnalyticsService = game:GetService("AnalyticsService")

local CREATOR_CODES: { [string]: string } = {
	-- code (uppercase) -> internal creator tag; never a real name in analytics
	EXAMPLECODE = "creator_a",
}

local function onCodeRedeemed(player: Player, code: string, firstTimeForPlayer: boolean)
	local tag = CREATOR_CODES[string.upper(code)]
	if not tag or not firstTimeForPlayer then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "CreatorCodeRedeemed", 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tag,
		})
	end)
end

return onCodeRedeemed
```

Verify the custom field usage against the current `AnalyticsService` reference before shipping; custom field keys and limits change (unverified in detail here).

What a "good" result looks like depends on your game. A useful bar: did the cohort's day-7 retention stay within a few points of your baseline? If it collapsed, the video sold a different game than the one players found, and that harms your discovery signals more than it helps.

---

## 8. When it goes wrong

| Situation | Response (rule of thumb) |
|---|---|
| The creator misrepresents the game (fake rewards, wrong odds) | Ask privately for a correction; if refused, state the facts on your own channels; end the partnership |
| The creator has a public scandal | Pause the partnership; remove creator-themed items from sale if the association harms players; refund where appropriate |
| A creator demands admin powers or rigged results | Decline; offer a private server and preview access instead |
| Viewers raid your game to harass | Extra moderators, temporary server size limits, report to Roblox; talk to the creator |
| The video drives players to a broken update | Roll back fast, post an honest status message, compensation code ([[Live Incident Response and Post-Mortems]]) |
| A creator video reveals an exploit | Thank them, patch, do not punish players retroactively for using a bug they saw in a video unless the abuse was deliberate and large ([[False Positives Lag and Fair Enforcement]]) |

---

## 9. When not to work with creators

- The game is not ready: the first five minutes are weak, or servers cannot handle 10x. You get one first impression per creator.
- The creator's audience does not match your label (a Moderate horror game and a creator whose audience is 8-year-olds).
- The only way the deal pays off is with misleading content.

---

## 10. Common mistakes

- Paying for a video without disclosure in the agreement.
- Scripting praise or forbidding criticism.
- Admin powers or rigged luck for a creator on camera.
- No warning before a video, so the update ships that day.
- No attribution: no share link or code, so you cannot tell what worked.
- Contracts with minors without a parent or guardian.

## 11. Checklist

- [ ] Game filmable: hide-UI mode, fast start, readable big moments, private servers
- [ ] Creator fit checked: genre, audience age, conduct
- [ ] Written agreement with disclosure, honesty, payment and guardian terms
- [ ] No in-game advantages for creators
- [ ] Surge plan: change freeze, extra moderators, kill switches
- [ ] Attribution: share link and creator code; custom analytics event
- [ ] Cohort retention compared with baseline after each collaboration

## See also
[[Community and Moderation Start Here]] · [[Short-Form Video Marketing]] · [[Launch Strategy - The First Two Weeks]] · [[Community Building]] · [[Discovery and the Algorithm]] · [[Analytics and Funnels]] · [[Thumbnails Icons and Store Page]] · [[Discord Servers for Roblox Games]] · [[Ethical Design and Player Trust]] · [[Marketing and Growth Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Business and Careers Start Here]] · Legal Basics - IP Licenses and Assets · Sponsored Ads and Campaign Math · Subscriptions and Premium Payouts · Monetization Overview · Working with Contractors and Revenue Splits
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]] · [[Monetization Overview]] · [[Sponsored Ads and Campaign Math]] · [[Legal Basics - IP Licenses and Assets]] · [[Voice Chat and Safety Features]] · [[Text Chat Customization with TextChatService]]
<!-- related:end -->
