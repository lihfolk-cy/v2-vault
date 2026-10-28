---
tags: [game-design, ethics, dark-patterns, monetization, odds, child-safety, trust]
---
# Ethical Design and Player Trust

Roblox's audience is young, and many players spend money that belongs to their parents. Every technique in this folder (hooks, streaks, timers, RNG, status, offers) can be used to make a game better or to pressure children into playing and spending more than is good for them. This note sets out the rules Roblox itself enforces, the dark patterns researchers have documented in Roblox games, honest alternatives for each, and a review checklist for any feature that touches time, money or randomness. It is opinionated on purpose: trust is the one resource a game cannot buy back.

Labels: **Docs** (create.roblox.com and Roblox help pages, checked October 2026), **Research** (external studies, cited), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. Why this matters on Roblox specifically

- **Researchers have found manipulative monetisation to be common.** A 2025 USENIX SOUPS paper ("How Predatory Monetization Designs Manifest in Child-Friendly Video Games") interviewed Roblox developers and analysed games, reporting that many developers are aware of predatory designs and that some deploy them. A 2026 University of Sydney report on 15 top-earning Roblox games reported misleading or deceptive monetisation practices in 14 of them (as summarised in the university's own news release). Read the originals; the point here is that regulators, researchers and parents are watching this genre closely.
- **Regulation is real.** Roblox's paid-random-item disclosure and restriction features exist because of laws in some countries (press coverage links the 2026 worldwide odds disclosure to South Korea's game law; treat that as secondary reporting). More may follow.
- **Roblox enforces rules.** Paid random items must disclose odds (Docs, "Paid random items"). Roblox's rules prohibit gambling that exchanges Robux or items of value and prohibit selling items with misleading or inaccurate descriptions (Roblox Rules of Conduct; check the current text). Breaking them risks moderation of the experience.
- **Trust compounds.** Communities, creators and parents talk. A game known for "scam bundles" or "rigged odds" loses the word of mouth that discovery on Roblox depends on.

---

## 2. Principles

1. **Honesty.** What the game says is what happens: odds, contents, timers, prices.
2. **Transparency.** Players can always see what they will get, what it costs in Robux, and how random rewards work.
3. **Respect for time.** Hooks invite players back; they never punish them for having a life.
4. **No pressure.** No artificial urgency, guilt, or social shaming around spending.
5. **Fair free play.** A player who never pays can enjoy the game and progress at a reasonable pace.
6. **Safety first.** Child safety beats engagement in every trade-off.
7. **Privacy.** Collect nothing you do not need; never ask for personal information.

The "parent test" (rule of thumb): would you be comfortable explaining exactly how this feature works, and why it is designed that way, to the parent of a nine-year-old player? If not, redesign it.

---

## 3. Dark patterns and honest alternatives

| Dark pattern | What it looks like | Why it harms | Honest alternative |
|---|---|---|---|
| Fake scarcity | "Only 3 left!" on a digital item that never runs out | Lies to create urgency | Real limits only; say "available this week" if it rotates |
| Fake or resetting timers | A "sale ends in 10:00" that restarts every session | Deceptive urgency | Real end dates; no countdowns on permanent prices |
| Confirm-shaming | "No thanks, I like being weak" | Guilt as a sales tool | Neutral "Close" / "Not now" |
| Pop-up ambush | Purchase offers on join, on death, mid-fight | Exploits frustration and impulse | Offers in the shop and at calm, relevant moments ([[Pricing and Store Design]]) |
| Pain-to-pay friction | Progress made deliberately miserable so the skip sells | Wastes players' time to create demand | Fair free pacing; skips as convenience |
| Obscured cost | Gems at irregular exchange rates so prices are hard to compare | Children cannot judge value | Show Robux equivalents; packs that match prices |
| Bait bundles | A bundle "worth 10,000 Robux" based on invented values | Misleading value claims | List contents plainly; no invented "worth" |
| Near-miss on paid rolls | The reel stops one card from the jackpot after a purchase | Slot-machine technique that sells the next spin | No near-miss on anything bought with Robux |
| Misleading odds | "1 in 1,000" when the real chance is lower | Deception; policy breach for paid items | Display odds computed from the real algorithm |
| Loss-aversion streaks | A 30-day streak that resets on one miss, with a paid "restore" | Punishes absence, sells relief | Grace days; no paid streak restore |
| Spending status | Public "top spenders" boards, "non-VIP" markers | Social pressure on children to spend | Status from play; private purchase history |
| Accidental purchases | A buy button where a common button usually sits | Taps by mistake | Buy buttons in consistent, separate places; Roblox's prompt still confirms |
| Hidden auto-spend | Auto-roll quietly consuming paid consumables | Spending without noticing | Auto-modes never spend paid items unless the player opts in each time |
| Gifting pressure | "Your friend needs this! Buy it for them" | Uses friendship as leverage | Gifting only on the player's initiative |

### The grey zone: VIP, luck and doublers
Many standard Roblox products are fine in moderation and harmful in excess:
- **Multiplier passes** (x2 cash) are a fair trade when the free pace is good.
- **Luck products** put money directly on the gamble. Keep them modest, explain them numerically, and update displayed odds while active (Docs requirement for paid probability modifiers).
- **"Claim x2" on rewards** (offline earnings, quest rewards) is fine when the free claim is generous; it becomes a pattern of pressure if every reward screen leads with the paid button.

---

## 4. Randomness and money

The detail is in [[Genre Playbook - RNG and Collection Games]]; the ethical summary:

- **Disclose real odds as percentages** for every paid random item, including items bought with currency that Robux can buy, and including luck boosts and pity systems; update the odds while boosts are active (Docs, "Paid random items").
- **Respect restrictions.** If `PolicyService` reports `ArePaidRandomItemsRestricted` for a player, give them one of the treatments the docs list (a free earnable path, direct purchase, hide or block). If `IsPaidItemTradingAllowed` is false, do not let them trade paid items or paid random outcomes.
- **Prefer direct purchase.** A specific item for a fixed price is always cleaner than a paid chance at it.
- **Offer pity on paid randomness**, and show the counter.
- **Never let paid outcomes be cashed out**: no trading paid items for real money or off-platform value, no features that make that easy. Roblox's rules prohibit gambling with items of value.
- **Free randomness is fun.** Free spins, free gifts and drops from play carry no money risk; show odds anyway. The reference project's free gift screen shows the odds it actually rolls.

---

## 5. Respecting time

| Practice | Why |
|---|---|
| Grace days on streaks | One missed day should not erase a week |
| Daily caps on timers | Prevents "leave the game running all night" pressure |
| Offline earnings at a fraction of active, capped | Rewards returning, does not demand constant presence |
| No penalty for absence (decay, lost items) | Children cannot always play |
| Sessions with natural end points | A chapter, a rebirth, a full vault: good places to stop |
| No login or playtime quests | The reference project removed them in favour of quests about playing |

The discovery algorithm itself caps playtime credit at 60 minutes per user per game per day (Docs, "Discovery"), so there is no ranking reason to design for marathon sessions.

---

## 6. Onboarding and purchase timing

New players are the most vulnerable to pressure: they do not yet know what anything is worth. Rules of thumb:
- **No purchase prompts during onboarding.** The reference project's pop-up gate blocks every automatic pop-up during the tutorial (and treats a missing tutorial state as "tutorial" for the first 180 s), over another panel, in combat, or within 8 s of another.
- **Let players experience the free game first.** The starter offer can exist in the shop from minute one; it should not chase the player.
- **Contextual offers** at relevant, calm moments are fine (a speed pass offered after the player has rolled a few hundred times), as Roblox's own "Contextual purchases" guidance describes. Not on death screens.

A small server-side guard for any purchase prompt your game triggers on its own:

```lua
--!strict
-- Server: only prompt purchases the game initiates when the moment is appropriate.
local MarketplaceService = game:GetService("MarketplaceService")

local lastPrompt: { [Player]: number } = {}
local MIN_GAP = 300 -- seconds between game-initiated offers (example)

local function mayOffer(player: Player): boolean
	if player:GetAttribute("OnboardingDone") ~= true then return false end
	if player:GetAttribute("InCombat") == true then return false end
	if player:GetAttribute("RecentlyDied") == true then return false end
	local last = lastPrompt[player]
	if last and os.clock() - last < MIN_GAP then return false end
	return true
end

local function offerProduct(player: Player, productId: number)
	if not mayOffer(player) then return end
	lastPrompt[player] = os.clock()
	MarketplaceService:PromptProductPurchase(player, productId)
end

game:GetService("Players").PlayerRemoving:Connect(function(p)
	lastPrompt[p] = nil
end)
```

Purchases the **player** starts (tapping a shop item) are never blocked; this only limits offers the game pushes. Granting still happens in `ProcessReceipt`; see [[Developer Products and ProcessReceipt]].

---

## 7. Child safety

| Area | Rule |
|---|---|
| Text | Filter all player-authored text shown to others with `TextService`; never display raw input |
| Contact | No features to exchange personal details or off-platform contacts |
| Personal information | Never ask for real names, ages, locations, schools, photos |
| Content | Stay inside your maturity label; check rules for violence, fear and romance (see [[Roblox Policies Ratings and Compliance]]) |
| Social features | Block, report and kick reachable; house locks; opt-in PvP |
| Age-dependent features | Respect Roblox's age checks and chat settings; design so restricted players are not excluded from play ([[Age Checks and Safety Features]]) |
| Data | Handle data deletion requests and keep only what you need ([[Player Privacy and Data Deletion]]) |
| Testing | Use isolated test profiles, never real players' saves (the reference project kept a test-profile key so live saves were never touched) |

---

## 8. Self-review: the reference project

Applying the checklist to one real game is instructive; it contains both good practice and things worth reconsidering.

| Good practice | Worth reconsidering |
|---|---|
| Free gift odds shown are the odds rolled | Daily chest streak resets on one missed day (no grace) |
| One pop-up gate: nothing during the tutorial, in combat, or within 8 s of another | A public "Robux spent" leaderboard in the hub |
| Claims marked before paying; saved at once | Near-miss effect on the roll reel (fine for free rolls; keep it off paid rolls) |
| Trading requires real play (500 rolls, 2 rebirths) | Several luck products: need percentage odds that update while active |
| Opt-in PvP with normalised damage and anti-farm | "Claim x2" offline product: keep the free claim generous and the paid button secondary |
| Login and playtime quests removed | VIP chat tag and gold title for pass owners: balance with status earned by play |
| Offline earnings capped and a fraction of active | |
| Exclusive items sold directly, never random | |

None of the right-hand column is unusual on Roblox; that is the point. Ethical design is mostly the sum of small defaults.

---

## 9. Feature review checklist

Run this for every feature that touches money, time or randomness:

- [ ] Can a player see exactly what they get, in plain words, before paying?
- [ ] Is every price shown in Robux (or with a Robux equivalent)?
- [ ] Are any odds shown as real percentages computed from the code, updated for active boosts?
- [ ] Does the feature work for players restricted from paid random items or paid trading?
- [ ] Is there any countdown, scarcity or "last chance" claim? Is it literally true?
- [ ] Does any button text shame or guilt the player?
- [ ] Can the feature trigger a purchase prompt during onboarding, combat, death or another panel?
- [ ] Does it punish absence? Is there a grace mechanism?
- [ ] Could auto-modes spend paid items without a fresh opt-in?
- [ ] Is any status visible to others that depends only on spending?
- [ ] Is all player-authored text filtered?
- [ ] Would you explain it, as designed, to a parent?

## 10. Common mistakes

| Mistake | Better |
|---|---|
| "Everyone does it" as the justification | The parent test |
| Odds typed by hand | Odds computed from the rolling code |
| Timers on permanent prices | Real end dates only |
| Pop-ups on join and death | One gate rule; offers in calm moments |
| Strict streaks with paid restore | Grace days, no paid restore |
| Status only from spending | Status from play |
| Ignoring `PolicyService` | Check on join; fail closed |

## See also
- [[Genre Playbook - RNG and Collection Games]], [[Retention and Return Hooks]], [[Social Design and Multiplayer Play]]
- [[Monetization Overview]], [[Pricing and Store Design]], [[Developer Products and ProcessReceipt]], [[Game Passes]]
- [[Roblox Policies Ratings and Compliance]], [[Age Checks and Safety Features]], [[Player Privacy and Data Deletion]]
- [[First-Time User Experience and Onboarding]], [[Core Loops and Session Design]]

## Connected notes
<!-- auto-links:start -->
[[Paid Random Items and Odds Disclosure in Practice]] · [[Skill - Roblox Monetization Compliance]] · [[Robux Price Points and Offer Design]] · [[Limited-Time Offers - Design and Ethics]] · [[Pity Timer]] · [[RNG Drops and Luck Systems]]
<!-- auto-links:end -->
