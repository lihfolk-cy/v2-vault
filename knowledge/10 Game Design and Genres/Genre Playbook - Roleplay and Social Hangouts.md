---
tags: [game-design, genre, roleplay, hangout, social, expression, safety]
---
# Genre Playbook - Roleplay and Social Hangouts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: A huge, empty map -> Dense story locations, vehicles, teleports
> - Avoid: Goals forced on RP players -> Optional light systems
> - Avoid: Client-side house locks -> Server enforcement and kick
> - Map is a set of recognisable story locations within short travel.
> - Expression tools: outfits, emotes, props, houses, vehicles, camera mode.
> - Non-chat communication for everyone.
>
> Read more (13 KB note): ## 5. Houses and permissions · ## 7. Safety: the core of the genre · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

Roleplay (RP) towns, life games, pet-raising worlds and hangouts are among the most played experiences on Roblox, and they break most rules in this folder: they have weak or no core loops in the usual sense, little progression, and almost no failure. What they offer instead is a **stage**: places, props, outfits, vehicles, houses and roles that players use to make their own stories with friends. The docs list Roleplaying and Customization among the platform's common genres and cite an RP town's hide-the-UI "Creator Cam" as a feature built for content creators (Docs, "Design for Roblox"). This playbook covers what makes a good stage, expression tools, the light systems that support RP, server and performance design, and the safety work these genres demand.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; used for social-feature lessons), **Rule of thumb** (most of this note).

---

## 1. Why RP and hangouts work on Roblox

| Docs observation | RP consequence |
|---|---|
| Younger users prefer exploring, experimenting and socialising over competition | No winners or losers; pretend play |
| Social play drives retention; players create content for each other | Other players are the content |
| Keep the shared avatar identity unless there is a strong reason | Players come as themselves; outfits extend the avatar |
| Players follow creators | RP stories are natural video formats |
| Intentional co-play days are a discovery signal | Friends meet here on purpose |

The design job is not "what is the loop" but "what stories can players tell here, and what do they need to tell them".

---

## 2. The stage: places that suggest stories

A good RP map is a set of **story prompts**. Each location should suggest roles and situations without instructions.

| Location type | Roles it suggests | Props that help |
|---|---|---|
| Homes | Family, roommates, hosts, guests | Beds, kitchens, doors that lock, furniture to arrange |
| School | Teacher, student, principal | Desks, a board, a bell |
| Hospital | Doctor, patient, nurse | Beds, a reception desk, an ambulance |
| Police station and jail | Officer, suspect | Cells, a car with lights |
| Shops and cafes | Worker, customer | Counter, register, food items |
| Fire station | Firefighter | Truck, hose, fires to fight |
| Park, beach, pool | Friends hanging out | Swings, boats, music |
| Secret places | Explorers | Hidden doors, puzzles, easter eggs |

Rules of thumb:
- **Recognisable over realistic.** Kids should know a hospital at a glance from the outside.
- **Short walks, vehicles for the rest.** A town 3 minutes across on foot needs cars or teleports.
- **Interiors matter more than exteriors.** Stories happen indoors.
- **Hidden secrets** (a basement, a lab, a cave) create rumours and return visits.

See [[Level Design for Roblox]] and [[Environment Art Styles]].

---

## 3. Expression tools

RP players need ways to show who they are and what they are doing.

| Tool | Notes |
|---|---|
| Outfits and role uniforms | Layer on the avatar; respect the player's identity |
| Name and role tags | Custom text **must be filtered** with `TextService` before others see it |
| Emotes and poses | Sit, wave, dance, sleep, cry; a wheel on phones. See [[Emotes and Social Animation]] |
| Held props | Food, phones, books, tools of a job |
| Houses | Choose, decorate, lock, invite |
| Vehicles | Cars, bikes, boats; spawn near the player |
| Pets or companions | Care loops (feed, play) add light goals |
| Music and sound | Radios, instruments (within licensing and audio rules) |
| Camera modes | Hide-UI mode for recording (the docs' Creator Cam example) |

### Quick communication without chat
Some players cannot use chat (age, settings, parental controls). Give everyone non-text ways to communicate: emotes, a quick-phrase wheel with fixed phrases, pings on the map, role icons. This also helps players who do not share a language. See [[Accessibility]] and [[Localization]].

---

## 4. Light systems that support RP

Pure sandboxes can feel aimless. Light systems give structure without forcing it.

| System | Purpose | Keep it light by |
|---|---|---|
| Jobs that pay | A reason to do a role; money for furniture or cars | Simple tasks (deliver, cook, cut hair), no punishment |
| Houses and furniture | Long-term personal project | Free starter house, purchasable upgrades |
| Collections (pets, outfits, cars) | Return goals | Many earnable through play |
| Daily rewards and events | Return hooks | See [[Retention and Return Hooks]] |
| Day and night | Changes mood and activities | Short cycle (minutes) |
| Seasonal updates | D30 retention | Holiday maps and items |

Pet-raising worlds add a care loop (feed, grow, age up) and trading, which turns them into collection games with an RP shell; see [[Genre Playbook - RNG and Collection Games]] and the trading section of [[Social Design and Multiplayer Play]].

---

## 5. Houses and permissions

Houses are the heart of many RP games and the main griefing vector. Ownership and permissions belong on the server.

```lua
--!strict
-- Server: house ownership, door locks and kick. Houses are Models tagged "House".
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

type House = { model: Model, owner: Player?, locked: boolean, guests: { [Player]: boolean } }

local houses: { [Model]: House } = {}
for _, m in CollectionService:GetTagged("House") do
	if m:IsA("Model") then
		houses[m] = { model = m, owner = nil, locked = false, guests = {} }
	end
end

local function canEnter(house: House, player: Player): boolean
	if not house.locked then return true end
	return player == house.owner or house.guests[player] == true
end

local function claim(house: House, player: Player): boolean
	if house.owner then return false end
	for _, h in houses do
		if h.owner == player then return false end -- one house per player
	end
	house.owner = player
	house.model:SetAttribute("OwnerUserId", player.UserId)
	return true
end

local function setLocked(house: House, player: Player, locked: boolean)
	if house.owner ~= player then return end -- only the owner
	house.locked = locked
	house.model:SetAttribute("Locked", locked)
end

-- Remote handlers call these after validating input types and rate limits.
-- Door: a server-side check moves non-permitted characters outside instead of trusting a client door.

Players.PlayerRemoving:Connect(function(p)
	for _, h in houses do
		if h.owner == p then
			h.owner, h.locked, h.guests = nil, false, {}
			h.model:SetAttribute("OwnerUserId", nil)
			h.model:SetAttribute("Locked", nil)
		end
		h.guests[p] = nil
	end
end)
```

Design rules:
- **Locking must be enforced on the server.** A client-side door can be bypassed. Check positions periodically (or use a server-owned barrier with collision groups) and move intruders outside.
- **Kick from my house** is a core feature, not an extra.
- **Saved decoration** goes in the player's profile as item ids and positions relative to the house origin, so it rebuilds in any plot on any server. See [[Data Schema Design and Migrations]].
- **Decoration limits**: cap placed items per house for performance.

---

## 6. Servers, density and performance

| Decision | Guidance (rule of thumb) |
|---|---|
| Server size | Larger than most genres (crowds are the content), limited by map size and performance |
| Vehicles | Cap per player (one active) and per server; despawn when abandoned |
| Spawnable props | Cap per player; clean up on leave |
| Houses | Load interiors with streaming; see [[Instance Streaming]] |
| Avatars | Many detailed avatars cost memory on phones; avoid adding heavy extras per player |
| Private servers | Popular for friend groups and RP communities; keep the price friendly (Docs) |

Large RP towns are among the most demanding places on low-end phones; plan budgets early. See [[Mobile and Low-End Optimization]] and [[Art Budgets - Triangles Draw Calls Memory]].

---

## 7. Safety: the core of the genre

RP and hangouts are where young players spend the most unstructured time with strangers. Safety design is not optional and policies change; treat [[Age Checks and Safety Features]] and [[Roblox Policies Ratings and Compliance]] as required reading.

| Risk | Design response |
|---|---|
| Unfiltered player text (names, signs, notes, bios) | Filter all player text with `TextService` for the right audience; never display raw input |
| Inappropriate roleplay | Follow Roblox's community rules for the content allowed in your maturity label; avoid features that facilitate romantic or adult roleplay (check the current rules for exact wording) |
| Strangers following children | Personal space options, house locks, kick, block and report reachable at all times |
| Off-platform contact requests | Do not build features to share external links or contact details; filtering and policy restrict them |
| Harassment through props or emotes | Limit what can be spawned or shown to others; moderation tools for server admins in private servers |
| Bathroom and bedroom scenes | Many RP games avoid private interiors that invite inappropriate scenes, or keep them clearly non-private |
| Impersonation of staff | Distinct visual markers for real moderators; never let players fake them |

Remember that chat restrictions apply per player: a design that requires chat leaves some players out. Quick-phrase wheels and emotes keep everyone included safely.

---

## 8. Content cadence and events

RP games depend heavily on updates: new houses, new vehicles, new locations, seasonal maps. The docs' general guidance is smaller updates every 2 to 4 weeks and larger features every 2 to 3 months (Docs, "Retention"). For RP specifically (rule of thumb):
- Seasonal decorations change the stage for free stories.
- Limited items create collection pressure; keep most earnable and avoid fake scarcity (see [[Ethical Design and Player Trust]]).
- In-world events (a parade, a storm, a festival) give the whole server a shared story.

See [[Live Ops Events and Updates]].

---

## 9. Monetisation

| Product | Notes |
|---|---|
| Premium houses and furniture | The classic; free options must remain usable and nice |
| Vehicles | Popular; keep a free car |
| Outfits and accessories in game | Cosmetic, safe |
| Roles with special props | Fine if the base roles are complete |
| Pets (often via eggs) | If eggs are bought with Robux or Robux-bought currency, they are paid random items: percentage odds before purchase, policy restrictions (Docs, "Paid random items") |
| Private servers | A social feature; price friendly |

RP players are especially sensitive to status gaps: if every nice house is paid, free players feel second class in their own stories. Give free players visible, attractive options.

---

## 10. Lessons from the reference project

The reference project is a combat game, but two of its social decisions transfer directly:
- **Status from play shown above heads.** It displayed each player's held weapon name above them, animated by rarity, as its main "social factor". RP games can do the same with earned titles and roles.
- **One rule for pop-ups.** No automatic pop-up during onboarding, over a panel, in combat, or within 8 s of another. RP sessions are long and social; constant prompts break scenes.

---

## 11. Common mistakes

| Mistake | Better |
|---|---|
| A huge, empty map | Dense story locations, vehicles, teleports |
| Goals forced on RP players | Optional light systems |
| Client-side house locks | Server enforcement and kick |
| Raw player text | Filter everything |
| Features that need chat | Emotes and quick phrases for everyone |
| Unlimited vehicles and props | Per-player and per-server caps |
| Every nice item paid | Attractive free options |
| No updates | Small updates every few weeks, seasonal stages |

## 12. Checklist

- [ ] Map is a set of recognisable story locations within short travel.
- [ ] Expression tools: outfits, emotes, props, houses, vehicles, camera mode.
- [ ] Non-chat communication for everyone.
- [ ] House ownership, locks and kick enforced on the server; decorations saved relatively.
- [ ] All player text filtered; reporting and blocking reachable.
- [ ] Caps on vehicles and props; low-end phone budget checked.
- [ ] Paid random pets (if any) disclose odds and respect policy restrictions.
- [ ] Update cadence planned.

## See also
- [[Social Design and Multiplayer Play]], [[Emotes and Social Animation]], [[Level Design for Roblox]]
- [[Age Checks and Safety Features]], [[Roblox Policies Ratings and Compliance]], [[Ethical Design and Player Trust]]
- [[Instance Streaming]], [[Mobile and Low-End Optimization]], [[Data Schema Design and Migrations]]
- [[Live Ops Events and Updates]], [[Community Building]], [[Retention and Return Hooks]]

## Connected notes
<!-- auto-links:start -->
[[Case Study - Brookhaven RP]] · [[Genre Playbook - Racing and Driving]] · [[Community and Moderation Start Here]] · [[Player Reports and In-Game Moderation]] · [[Top Games Case Studies Start Here]] · [[Physics and Vehicles Start Here]]
<!-- auto-links:end -->
