---
tags: [game-design, social, multiplayer, trading, pvp, friends, safety]
---
# Social Design and Multiplayer Play

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Social features that need 10 players in a server of 3 -> Design for low density first; scale up with events
> - Avoid: Last-hit takes all -> Credit every meaningful contributor
> - Avoid: PvP everywhere by default -> Opt-in arena, normalised damage
> - At least three rungs of the social ladder.
> - Rare moments visible to the whole server.
> - Hub designed as the social centre; density checked.
>
> Read more (17 KB note): ## 4. Friends · ## 5. Cooperation · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

Every Roblox game is multiplayer by default: players share a server, see each other's avatars, and usually arrived with or because of friends. Social design is deciding **what other players mean to you** in that shared space: scenery, audience, helpers, rivals, trading partners. Done well, it is the strongest retention force on the platform and an explicit discovery signal. Done badly, it produces griefing, scams and empty-feeling servers. This note covers the forms of social play, the features that make other players matter, trading and PvP design, and the safety rules that are not optional on a platform with young players.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. Why social design matters on Roblox

- The docs say social play drives retention because players create ongoing content for each other, and that single-player games "often struggle" to build and keep an audience (Docs, "Design for Roblox").
- For D30 retention the docs list social mechanics explicitly: trading, parties, guilds, PvP, tournaments and leaderboards (Docs, "Retention").
- Discovery counts **intentional co-play days per user** as an important ranking signal (Docs, "Discovery").
- Players often move between games together and follow creators (YouTubers) into games (Docs, "Design for Roblox").
- Younger players prefer exploring, experimenting and socialising over competition (Docs, "Design for Roblox"), so most social features should be **positive-sum**.

---

## 2. A ladder of social interaction

Each rung asks more of players and gives more back. Most successful games have at least three rungs.

| Rung | What players do | Examples | Cost and risk |
|---|---|---|---|
| Co-presence | See each other | Shared hub, visible avatars, nametags | Almost free; servers must not feel empty |
| Display | Show off | Titles, rare-pull announcements, cosmetics, leaderboards | Cheap; status envy if it is pay-only |
| Parallel play | Do the same thing side by side | Everyone farming the same zone | Kill-stealing and resource competition |
| Cooperation | Need or benefit from each other | Group bosses, server-wide boosts, raids | Needs matchmaking or density |
| Exchange | Trade, gift | Trading, gifting purchases | Scams, real-money trading, policy |
| Competition | Beat each other | PvP arenas, races, rankings | Toxicity, power gaps |
| Expression and roleplay | Play roles, build, decorate | Houses, jobs, emotes | Moderation load |

The rest of this note goes through the rungs that need the most design.

---

## 3. Make other players visible and meaningful

The cheapest social features turn other players into **advertisements for the loop**.

### Display what people achieved
- **Rare-pull announcements.** When anyone rolls a high tier, the whole server sees a banner with the player's name, the item and its odds. In the reference project the roll reveal also had tier-specific banners ("GODLY PULL!") and a burst in the world for Rare and above.
- **Titles above heads.** The reference project added the held weapon's name above every player, animated per letter by rarity (the designer: "that will be the social factor"). A Divine title walking past is a stronger pitch for rolling than any shop banner. Budget it: the project limited the effect to 16 active titles within 120 studs and on screen.
- **Public celebrations.** A rebirth plays a large effect (rings, a light pillar, a burst) visible to the whole server.
- **Leaderboards in the hub.** The reference project used rebirths, time played and Robux spent. See section 8 on whether to rank spending.

### Make the hub a place
The hub is where the social layer lives: everyone passes through it, it holds the shop, the roll altar, crafting stations, quest giver, leaderboards and timed activities (in the reference project: daily chest, lucky spin, AFK fishing, training dummies, an event portal). Put idle activities there so even AFK players make it look alive. See [[Level Design for Roblox]].

### Watch server density
A 30-player server spread across 20 zones is 1.5 players per zone: effectively single-player. Options:
- Fewer, bigger zones, or a ladder where most players cluster in a few zones at a time.
- A shared hub that everyone returns to frequently (crafting, rolling, quests).
- Server events that pull everyone to one place.
- Server size tuned to the content (more players for hangouts, fewer for co-op dungeons). Set it in the place settings; see [[Places Universes and Experience Settings]].

---

## 4. Friends

### Reward playing with friends
A friend boost (for example +X% luck or cash per friend in the server, capped) turns "my friend is online" into a reason to join. The reference project had a friend luck boost shown as a HUD pill. Keep the cap low enough that solo players do not feel punished.

```lua
--!strict
-- Server: count friends in the server and publish a boost multiplier.
-- Player:IsFriendsWith yields (web call): cache results and call it in pcall.
local Players = game:GetService("Players")

local PER_FRIEND = 0.10 -- +10% per friend (example value)
local MAX_FRIENDS = 3   -- cap at +30%

local friendCache: { [Player]: { [number]: boolean } } = {}

local function isFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if not cache then
		cache = {}
		friendCache[a] = cache
	end
	local known = cache[b.UserId]
	if known ~= nil then return known end
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	local value = ok and result == true
	cache[b.UserId] = value
	return value
end

local function refresh(player: Player)
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and isFriend(player, other) then
			count += 1
		end
	end
	player:SetAttribute("FriendBoost", 1 + PER_FRIEND * math.min(count, MAX_FRIENDS))
end

local function refreshAll()
	for _, p in Players:GetPlayers() do
		task.spawn(refresh, p) -- each refresh may yield
	end
end

Players.PlayerAdded:Connect(refreshAll)
Players.PlayerRemoving:Connect(function(leaving)
	friendCache[leaving] = nil
	for _, cache in friendCache do
		cache[leaving.UserId] = nil
	end
	task.defer(refreshAll)
end)
```

Read the attribute in the server's reward code; never trust a boost value sent by the client.

### Invites
`SocialService:PromptGameInvite(player, options?)` opens Roblox's invite prompt; check `SocialService:CanSendGameInviteAsync(player)` first (it yields, so wrap it in `pcall`). Good moments to offer an invite: after a rare pull, before a co-op boss, when a friend boost would help. Never block progress behind inviting someone, and do not reward invites with something a player without friends on Roblox cannot get otherwise.

### Private servers
The docs advise against pricing private servers so high that friend groups are discouraged (Docs, "Design for Roblox"). A free or cheap private server is a social feature, not just a product.

---

## 5. Cooperation

Cooperation is the most valuable rung for retention and the hardest to fill with players.

| Pattern | How it works | Notes |
|---|---|---|
| Shared world boss | Everyone in the server can hit it; everyone who contributed gets loot | No kill-stealing: credit by damage share or participation |
| Scheduled server event | A countdown, a short join window, one arena for everyone | The reference project's event opens a rift in the hub for a 45 s join window; the boss spawns when everyone online is in or time runs out |
| Server-wide boosts | One player's purchase or action benefits the whole server | Server luck boosts in the reference project; announce who triggered it |
| Role combos | Healer, tank, damage | Needs matchmaking; works in dedicated dungeons |
| Shared objectives | Server meter fills from everyone's actions | Cheap, inclusive |

### Kill credit and loot
In parallel play, the player who lands the last hit should not get everything. Credit everyone who dealt meaningful damage recently:

```lua
--!strict
-- Track damage by player on an enemy and pay everyone who contributed >= 10% (or the top hitter).
type Ledger = { [Player]: number }

local ledgers: { [Instance]: Ledger } = {}

local function recordDamage(enemy: Instance, player: Player, amount: number)
	local l = ledgers[enemy]
	if not l then
		l = {}
		ledgers[enemy] = l
	end
	l[player] = (l[player] or 0) + amount
end

local function payout(enemy: Instance, reward: number, pay: (Player, number) -> ())
	local l = ledgers[enemy]
	ledgers[enemy] = nil
	if not l then return end
	local total = 0
	for _, dmg in l do total += dmg end
	if total <= 0 then return end
	for player, dmg in l do
		if player.Parent and dmg / total >= 0.10 then
			pay(player, reward) -- full reward each: cooperation is never worse than solo
		end
	end
end
```

Paying **full** reward to every meaningful contributor (rather than splitting it) makes helping strangers strictly positive, which is what you want in a game for young players. Make sure enemy health scales with the number of attackers if that would otherwise trivialise fights.

---

## 6. Trading

Trading is a powerful long-term social loop (collections gain value, players negotiate, communities form) and the biggest source of social harm: scams, pressure, real-money trading and alt-account farming.

### Policy constraints
- Players whose `PolicyService` info has `IsPaidItemTradingAllowed` false must not be able to trade items bought with Robux or with Robux-bought currency, including outcomes of paid random items (Docs, "Paid random items"). Check `PolicyService:GetPolicyInfoForPlayerAsync(player)` on the server (it yields; use `pcall` and fail closed).
- Trading items for real money or off-platform value breaks Roblox's rules. Do not build features that make that easy (for example cross-server "trade for Robux" listings). See [[Roblox Policies Ratings and Compliance]].

### Trade UX that prevents scams
| Rule | Why |
|---|---|
| Both sides see the full offer, item rarity and an estimated value | Young players cannot judge value |
| Any change to the offer resets both "ready" states | The classic last-second swap scam |
| A short countdown (a few seconds) after both accept | Time to notice a swap |
| Server validates ownership at commit, atomically | No duplication on lag or disconnect |
| Trade log saved per player | Support and rollback |
| Requirements before trading | Blocks fresh alt accounts used to funnel items |

The reference project required **500 rolls and 2 rebirths** before a player could trade. That is a good shape: requirements that a real player meets naturally and a throwaway alt does not.

See [[Tools and Inventory Systems]] and [[Server Authority and Validation]] for the transaction side, and [[Data Loss Prevention and Recovery]] for logs.

---

## 7. Competition and PvP

Competitive features retain a minority of players very strongly, and can drive away the majority if forced on them.

### Opt-in PvP
Keep PvP in a clearly marked area or mode. The reference project's arena is a separate floating colosseum reached through one gate of the hub. Its rules are a good template:
- **Normalised damage**: hits deal a percentage of the target's health, so a player with a much stronger weapon does not one-shot a newer player. Progression still matters (abilities, skill) but the gap is compressed.
- **Short knock-out**: 3 seconds, then respawn in an alcove with a 2-second shield.
- **Anti-farm**: kill rewards capped at 2 per victim per minute, so two friends cannot farm each other.
- A live kill feed and scoreboard for the arena only.

### Rankings
- Rank on things players control (rebirths, best time, wins), not on raw playtime alone, which rewards AFK.
- Weekly or seasonal resets give newcomers a chance; all-time boards are for status.
- Use `OrderedDataStore` for global boards; see [[OrderedDataStores and Leaderboards]].

---

## 8. Status and spending

A leaderboard of **Robux spent**, a gold "VIP" chat tag, or a sweeping gold title for pass owners all turn spending into social status. These are common on Roblox (the reference project has a VIP chat prefix and a gold title floor for VIP owners, and a Robux leaderboard in the hub).

They work commercially, and they also put social pressure on children to spend. Rules of thumb:
- Cosmetic status from purchases is acceptable when free players have **equally visible** status routes (rarity titles from play, rebirth counts, achievements).
- Avoid public ranking of money spent. If you keep it, do not put it next to the spawn point.
- Never show "X has not bought VIP" or anything that marks non-payers.

More in [[Ethical Design and Player Trust]].

---

## 9. Communication and safety

Communication features are where social design meets child safety. Roblox handles core chat, but any text **your game** shows that came from a player must be filtered.

| Feature | Requirement |
|---|---|
| Chat | Use `TextChatService`; Roblox applies filtering and age-based restrictions |
| Custom text shown to others (pet names, sign text, guild names, trade notes) | Filter with `TextService:FilterStringAsync` and display the filtered result for the right audience; never show raw player text |
| Voice | Roblox controls eligibility; do not build workarounds |
| Off-platform links | Restricted by policy and by `PolicyService` link rules; do not ask players to join external chats |
| Reporting | Keep Roblox's report flow reachable; do not hide the menu |

Age checks, chat restrictions for younger players and other platform safety features change over time. See [[Age Checks and Safety Features]] and [[Roblox Policies Ratings and Compliance]] for the current state, and design features so they still work for a player who cannot chat (emotes, quick-chat wheels, pings).

### Griefing prevention
| Grief | Prevention |
|---|---|
| Body-blocking doors and NPCs | Players do not collide with each other (collision groups) in crowded areas |
| Kill-stealing | Shared credit (section 5) |
| Loot-stealing | Per-player drops; only the owner sees and collects |
| Spawn-camping in PvP | Spawn shields, multiple spawn points, PvP only in the arena |
| Trolling with physics items | Server-owned or client-only props; rate-limit spawnable objects |
| Harassing new players | Tutorial targets owned per player (the reference project's tutorial enemies only targeted their own player) |

---

## 10. Social features for the content creator audience

Players follow creators into games (Docs). Features that help:
- A **hide-UI / camera mode** for recording; the docs cite Brookhaven's "Creator Cam" as an example.
- **Codes** that creators can share (see [[Menu Archetypes - Shop Settings Codes Rewards]]).
- **Recordable moments**: big reveals with readable odds, boss kills, rebirth bursts.
- Server events at predictable times so creators can plan videos.

---

## 11. Common mistakes

| Mistake | Better |
|---|---|
| Social features that need 10 players in a server of 3 | Design for low density first; scale up with events |
| Last-hit takes all | Credit every meaningful contributor |
| PvP everywhere by default | Opt-in arena, normalised damage |
| Trading with no requirements | Requirements a real player meets naturally; policy checks |
| Raw player text in signs or names | Filter everything through `TextService` |
| Status only for payers | Equal visible status from play |
| Invite rewards that need friends on Roblox | Rewards reachable without inviting |
| Leaderboards on AFK time | Rank actions players control |

## 12. Checklist

- [ ] At least three rungs of the social ladder.
- [ ] Rare moments visible to the whole server.
- [ ] Hub designed as the social centre; density checked.
- [ ] Friend boost capped; invites offered at good moments, never required.
- [ ] Shared bosses pay every contributor.
- [ ] Trading: policy check, reset-on-change, countdown, atomic commit, logs, requirements.
- [ ] PvP opt-in with normalised damage and anti-farm.
- [ ] All player-authored text filtered.
- [ ] Features work for players who cannot chat.

## See also
- [[Core Loops and Session Design]], [[Retention and Return Hooks]], [[Genre Playbook - Roleplay and Social Hangouts]]
- [[Ethical Design and Player Trust]], [[Age Checks and Safety Features]], [[Roblox Policies Ratings and Compliance]]
- [[OrderedDataStores and Leaderboards]], [[Cross-Server Messaging]], [[Teleporting and Multi-Place Games]]
- [[Emotes and Social Animation]], [[Community Building]], [[Discovery and the Algorithm]]

## Connected notes
<!-- auto-links:start -->
[[Community and Moderation Start Here]] · [[Robux Price Points and Offer Design]] · [[Friend Invites Referrals and Experience Invites]] · [[Platform Features Start Here]] · [[Trading Systems Without Duplication]] · [[Links - Community and social]]
<!-- auto-links:end -->
