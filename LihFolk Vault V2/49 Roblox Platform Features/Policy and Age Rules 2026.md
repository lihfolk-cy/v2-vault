---
tags: [delta, policy, age-checks, chat, textchatservice, maturity, roblox-kids, roblox-select, paid-random-items, compliance, policyservice, type/guide]
verified: 2026-10-28
---
# Policy and Age Rules 2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Publishing without completing the maturity questionnaire, then wondering why nobody can join.
> - Avoid: Showing odds as "Rare / Epic / Legendary" with no numbers, or showing base odds while a luck pass is active.
> - Avoid: Selling a "luck x2" pass without stating the resulting odds.
> - Maturity questionnaire complete for every published place.
> - Every paid random item and luck modifier shows numeric odds summing to 100% before purchase.
> - `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed` honoured server-side.
>
> Cost: TL;DR ~180 tok · whole note ~2.7k tok. Read more: ## 4. Paid random items (clarified May 26, 2026) · ## 5. Chat: legacy removed, TextChatService lockdown coming · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Between late 2025 and October 2026 Roblox gated chat behind age checks, split under-16 users into curated account tiers, raised the age floor for several game types, tightened paid random item rules, and announced a lockdown of chat message access for scripts. Most of these change what a game must do, not only what players see. Labels follow [[Roblox Changes 2025-2026]].

## 1. Age checks for chat (global since January 2026)

**Roblox docs** (newsroom, November 2025: https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat; global rollout press release January 7, 2026: https://secure.businesswire.com/news/home/20260107986568/en/Roblox-Requires-Users-Worldwide-to-Age-Check-to-Access-Chat).

- Chat requires a completed age check (facial age estimation, or ID for 13+). Testing began December 2025 in Australia, New Zealand and the Netherlands; worldwide from January 2026.
- Age groups: under 9, 9-12, 13-15, 16-17, 18-20, 21+. Chat is generally limited to similar age groups.
- **Reported** (May 2026 press): more than half of users had completed the check.

Developer impact:
- You cannot read a player's age. `PolicyService:GetPolicyInfoForPlayerAsync` returns policy flags, not ages. Do not infer age from it.
- To put chat-compatible players together, use `TextChatService:GetChatGroupsAsync(players)` (players sharing a group ID can chat), and check pairs with `CanUsersChatAsync(fromUserId, toUserId)` or `CanUsersDirectChatAsync(requester, userIds)` before creating private channels (Roblox docs, TextChatService reference).
- A social game whose loop depends on chat should expect many players without chat.

## 2. Roblox Kids and Roblox Select (announced April 13, 2026; rollout early June 2026)

**Roblox docs** (newsroom: https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts; content maturity page: https://create.roblox.com/docs/production/promotion/content-maturity).

| Account | Ages | Games available |
|---|---|---|
| Roblox Kids | 5-8 | Minimal or Mild label **and** passes selection |
| Roblox Select | 9-15 | Up to Moderate **and** passes selection |
| Standard | 16+ | Unchanged |

Selection: developer verification, real-time evaluation (how users 16+ engage with the game, user reports), maturity rating and default exclusions. Social hangouts, sensitive issues and free-form drawing games are excluded by default. Creator requirements: **ID verification, two-step verification, and an active Roblox Plus subscription**. Roblox plans to move to the IARC rating framework later in 2026 (status **Unverified** as of 2026-10-28). In Roblox Kids all communication is off by default.

Impact: a game for young players needs a Minimal or Mild label, a verified owner with Plus, and nothing that classifies it as a hangout or free-form creation game.

## 3. Maturity labels and feature age floors

**Roblox docs** (content maturity page, checked 2026-10-28):

| Label or feature | Who can play |
|---|---|
| Minimal, Mild | Kids, Select, standard |
| Moderate | Select (9-15) and 16+ |
| Content May Vary | Age-checked 16+ |
| Restricted | Age-verified (ID) 18+ |
| Social hangout, no private spaces | Age-checked 16+ |
| Social hangout with private spaces (bedrooms, stalls, tents) | Age-verified 18+ |
| Free-form user creation | 16+ |
| Sensitive issues as primary theme | 16+, not recommended or discoverable unless age-verified |
| Romantic themes, alcohol, strong language, strong violence, heavy realistic blood | Age-verified 18+ |

- **Games without content maturity information are unplayable for all players.** Fill in the questionnaire for every place you publish, including test places you share.
- Answer for the most extreme content in the game. A Restricted game cannot lower its maturity level.
- **Reported** (third-party summary): the floor for hangouts, free-form creation and sensitive issues rose from 13 to 16 around May 19, 2026.

## 4. Paid random items (clarified May 26, 2026)

**Roblox docs** (Creator Hub: https://create.roblox.com/docs/production/monetization/paid-random-items; DevForum "Clarifying Requirements for Paid Random Items": https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622). **Reported** (TechTimes, June 26, 2026): the change followed South Korean law but applies worldwide.

- Applies to anything bought with Robux or with currency purchasable with Robux, **including indirect** purchases: keys, re-roll tokens, spin tickets.
- Before purchase, show **every outcome with its numerical odds**, as percentages that sum to 100%. Rounding to at least four places after the first non-zero digit is allowed with a disclaimer. Long lists may sit behind a labelled "Info" or "Details" button; a bare (i) icon is not enough.
- One-time outcomes: update the remaining odds for that player.
- **Odds-modifying items** (luck boosts, pity, rate-up) must be explained numerically before purchase, and the displayed odds must update while they are active.
- **Reported** (staff forum reply): a bundle containing a random item makes the whole bundle a paid random item; previewing the next result does not exempt a system whose later results are random.
- For players where `PolicyService` returns `ArePaidRandomItemsRestricted = true`: offer a free earnable path, a fixed disclosed order, direct purchase at [[expected value]], hide or block the item, or keep the player out of that area. If `IsPaidItemTradingAllowed` is false, block trading of paid outcomes.

```lua
-- Server: one table drives both the roll and the displayed odds (Measured practice)
local EGG = { { id = "Cat", w = 60 }, { id = "Dog", w = 30 }, { id = "Dragon", w = 10 } }
local function displayOdds(pool, luckMult: number)
	local adj, total = {}, 0
	for _, e in pool do
		local w = if e.id == "Dragon" then e.w * luckMult else e.w
		adj[#adj + 1] = { id = e.id, w = w }; total += w
	end
	for _, e in adj do e.pct = e.w / total * 100 end -- send these exact numbers to the shop UI
	return adj
end
```

See [[Paid Random Items and Odds Disclosure in Practice]] and [[RNG Drops and Luck Systems]].

## 5. Chat: legacy removed, TextChatService lockdown coming

- **Legacy chat** (`Chat` service scripts, `ChatServiceRunner`, `SayMessageRequest`) was removed by April 30, 2025, with automatic migration afterwards (Roblox docs, https://devforum.roblox.com/t/migrate-to-textchatservice-removing-support-for-legacy-chat-and-custom-chat-systems/3237100). `TextChatService.ChatVersion` is deprecated.
- **Lockdown** (Roblox docs, DevForum October 21, 2026: https://devforum.roblox.com/t/important-textchatservice-updates-how-to-test-and-what%E2%80%99s-next/4948433/1):
  - All user-to-user chat must use TextChatService. Chat outside it breaks the Chat System Guidelines.
  - `TextChatMessage.Text` and `.Translation` will return empty strings to scripts (with a warning).
  - `OnIncomingMessage` and `Player.Chatted` are unsupported for custom moderation; `TextChatMessage.PrefixText` is unsupported (native prefixes planned early 2027).
  - Custom chat UI moves to `TextChannelWindow` (`Target`, can sit on a SurfaceGui). Custom commands move to TextChatCommands; presets to Quick Words.
  - **Non-chat player text** (signs, pet names, boards, plates) must be rate-limited to **one submission per minute** or routed through a TextChannel. Admin modules that let players message each other must be updated or disabled.
  - Opt in now with `TextChatService.PlatformIntegratedChat = Enabled`. Automatic opt-in February 2027 with opt-out; required May 2027.

```lua
-- Non-chat text: filter AND rate-limit (1 per minute per player). SetPetName is a RemoteEvent, pet the player's pet model
local TextService = game:GetService("TextService")
local lastSubmit: { [number]: number } = {}
SetPetName.OnServerEvent:Connect(function(player, raw)
	if typeof(raw) ~= "string" or #raw > 20 then return end
	local now = os.clock()
	if now - (lastSubmit[player.UserId] or -math.huge) < 60 then return end
	lastSubmit[player.UserId] = now
	local ok, result = pcall(TextService.FilterStringAsync, TextService, raw, player.UserId)
	if ok then pet:SetAttribute("Name", result:GetNonChatStringForBroadcastAsync()) end
end)
```

## 6. Other policy dates

| Change | Date | Source |
|---|---|---|
| Updated Terms of Use and Privacy Policy take effect | November 1, 2026 | Roblox docs, https://devforum.roblox.com/t/updates-to-the-roblox-terms-of-use-november-2026/4907620/1 |
| Usernames of accounts deleted under RTBF are retired permanently | late Sept 2026 | Roblox docs, https://create.roblox.com/docs/production/publishing/RTBF-and-creators |
| Community Standards apply at Roblox events | Sept 2026 | Roblox docs, weekly recap Sept 28-Oct 2, 2026 |

## Common mistakes

- Publishing without completing the maturity questionnaire, then wondering why nobody can join.
- Showing odds as "Rare / Epic / Legendary" with no numbers, or showing base odds while a luck pass is active.
- Selling a "luck x2" pass without stating the resulting odds.
- Reading `message.Text` in `OnIncomingMessage` to build a custom filter or command system.
- Free-text sign or pet-name inputs with no cooldown.
- Inferring player age from `PolicyService` flags.
- Designing a game for under-9s with a hangout or drawing feature (excluded by default).

## Checklist

- [ ] Maturity questionnaire complete for every published place.
- [ ] Every paid random item and luck modifier shows numeric odds summing to 100% before purchase.
- [ ] `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed` honoured server-side.
- [ ] All player-to-player text goes through TextChatService; non-chat text filtered and limited to 1 per minute.
- [ ] Custom chat UI planned onto `TextChannelWindow` before February 2027.
- [ ] If targeting under-16s: owner ID-verified with 2SV and Plus; label Minimal, Mild or Moderate; no default-excluded features.

## See also

- [[Roblox Changes 2025-2026]]
- [[Age Checks and Safety Features]]
- [[Roblox Policies Ratings and Compliance]]
- [[Paid Random Items and Odds Disclosure in Practice]]
- [[RNG Drops and Luck Systems]]
- [[AI Pitfalls - Data and Monetization]]

<!-- related:start -->
## Related
[[Regional Compliance - Paid Random Items and Country Rules]] · [[Discovery and Monetization Changes 2025-2026]] · [[Data and Cloud Changes 2025-2026]] · [[Engine and API Changes 2025-2026]] · [[Console and VR Release Checklists]] · [[Commerce and Physical Goods]] · [[Server Authority and Input Migration 2026]]
<!-- related:end -->
