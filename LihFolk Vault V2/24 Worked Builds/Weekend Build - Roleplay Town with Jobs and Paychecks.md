---
tags: [worked-build, roleplay, jobs, teams, paychecks, housing, ownership, economy, safety, fast-ship, type/build, area/gameplay]
---
# Weekend Build - Roleplay Town with Jobs and Paychecks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Paying for time online. AFK farms and auto-clickers drain your economy.
> - Avoid: Client-side door locks. Anyone can walk in with a simple exploit.
> - Avoid: Unlimited police slots. Kills the cops-vs-civilians balance.
> - Jobs as Teams set by server; caps per job; tools swapped cleanly.
> - Paycheck requires server-observed job activity in the window; zero pay explained.
> - House ownership, lock and guests on server; interior volume enforced.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 3. Paychecks that resist AFK farming · ## 4. Houses with server-enforced ownership · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A small roleplay town: three jobs (Police, Medic, Cashier), a paycheck every few minutes for players who are actually working, and a claimable house with a door only its owner (and invited friends) can open. It is the skeleton of the city RP genre, with the two things that usually go wrong handled from the start: AFK paycheck farming and client-enforced house locks. Genre context: [[Genre Playbook - Roleplay and Social Hangouts]] and [[Case Study - Brookhaven RP]].

Source labels: **Roblox docs**, **Rule of thumb**. Code is original, reviewed but not run as a whole.

## 1. Scope

- Jobs as `Team`s with uniforms and one job tool each; switch at a job board (a `ProximityPrompt`).
- Paycheck every 3 minutes, scaled by job, only if the player did job activity in that window.
- Cash saved; spent on a house claim fee (soft currency) and a car spawn later.
- 6 houses; one per player; ownership lasts for the server session; owner can lock, unlock and add friends.

## 2. Jobs and teams

```lua
--!strict
local JOBS = {
	Police = { pay = 60, team = "Police", tool = "Cuffs", cap = 6 },
	Medic = { pay = 55, team = "Medic", tool = "MedKit", cap = 4 },
	Cashier = { pay = 40, team = "Cashier", tool = "Register", cap = 4 },
	Citizen = { pay = 15, team = "Citizen", tool = nil, cap = math.huge },
}
```

Server handler for the job board: validate the job id, check the cap by counting `Team:GetPlayers()`, set `player.Team`, clear old job tools from `Backpack` and character, give the new tool, apply the uniform. Caps matter: a server of 20 police with no criminals is a dead server. The client never sets `Team` itself; the server does and it replicates.

## 3. Paychecks that resist AFK farming

Pay players for *activity*, not time. Each job has a server-observed activity signal:

| Job | Activity that counts (server-observed) |
|---|---|
| Police | Used cuffs on a player, or drove the patrol car a minimum distance |
| Medic | Healed a player below full health |
| Cashier | Completed a register interaction with another player or an NPC customer |
| Citizen | Moved a minimum distance (small pay only) |

```lua
local PAY_INTERVAL = 180
local activeSince: {[Player]: number} = {} -- last time a job action was observed

local function markActive(player: Player)
	activeSince[player] = os.clock()
end

task.spawn(function()
	while true do
		task.wait(PAY_INTERVAL)
		local now = os.clock()
		for _, player in game:GetService("Players"):GetPlayers() do
			local job = JOBS[player.Team and player.Team.Name or "Citizen"] or JOBS.Citizen
			local last = activeSince[player]
			if last and now - last <= PAY_INTERVAL then
				addCash(player, job.pay)
				notifyPaycheck(player, job.pay)
			else
				notifyPaycheck(player, 0) -- "No paycheck: you were not working"
			end
		end
	end
end)
```

Call `markActive` from the server code that handles each job action (the heal, the cuff, the register sale), never from a client "I am working" remote. Tell players why they were not paid; silent zero paychecks look like bugs.

Rule of thumb on numbers: pay should let an active player afford their first meaningful purchase (the house) within the first 10 to 15 minutes. Model the economy before tuning ([[Economy Inflation Sinks and Faucets Math]]). If you sell cash for Robux later, keep paychecks meaningful so free players are not locked out.

## 4. Houses with server-enforced ownership

Each house model has attributes `HouseId`, `Owner` (UserId or 0), `Locked`, and a door part with a `ProximityPrompt`.

```lua
local houseOf: {[Player]: Model} = {}
local guests: {[Model]: {[number]: boolean}} = {}

local function canEnter(player: Player, house: Model): boolean
	local owner = house:GetAttribute("Owner")
	if owner == player.UserId then return true end
	if not house:GetAttribute("Locked") then return true end
	local list = guests[house]
	return list ~= nil and list[player.UserId] == true
end

local function claim(player: Player, house: Model)
	if houseOf[player] or house:GetAttribute("Owner") ~= 0 then return end
	if not spendCash(player, 250) then return end
	house:SetAttribute("Owner", player.UserId)
	house:SetAttribute("Locked", true)
	houseOf[player] = house
	guests[house] = {}
end
```

The lock that matters is on the server:

- The door's collision is the visible barrier, but players can noclip on their own client. A server check on a trigger volume inside the house (polled with `GetPartsInPart` or a zone module every 0.5 s) teleports out any character that fails `canEnter`. See [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] and [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].
- On `PlayerRemoving`, reset `Owner` to 0, clear guests and items placed inside.
- "Add friend" is a server remote that validates the target is in the server and not blocked by the owner.

## 5. Safety for an RP game

Roleplay games are social first; safety is a core system, not an afterthought ([[Genre Playbook - Roleplay and Social Hangouts]]).

- Owners can kick guests from their house instantly (server teleport to the door).
- Every player can hide or mute others using Roblox's built-in features; do not block them.
- Free-text props (signs, name plates) must go through `TextService` filtering for the right context before display ([[Text Chat Customization with TextChatService]]).
- Police "arrest" moves the target to a jail area for a short, capped time; the target can leave the job game entirely by switching to Citizen after release. Never let one player trap another indefinitely.

## 6. Testing

- Three clients: job caps enforced; switching jobs removes old tools.
- An idle player receives no job pay; a working player is paid exactly once per interval.
- A second client with noclip (simulate by disabling collisions locally) is removed from a locked house within a second.
- Owner leaves: house resets and is claimable.

## Common mistakes

- **Paying for time online.** AFK farms and auto-clickers drain your economy.
- **Client-side door locks.** Anyone can walk in with a simple exploit.
- **Unlimited police slots.** Kills the cops-vs-civilians balance.
- **Activity marked by a client remote.** Exploiters spam it.
- **No reason shown for a zero paycheck.** Players think the game is broken.
- **Unfiltered player text on signs.** Moderation risk.

## Checklist

- [ ] Jobs as Teams set by server; caps per job; tools swapped cleanly.
- [ ] Paycheck requires server-observed job activity in the window; zero pay explained.
- [ ] House ownership, lock and guests on server; interior volume enforced.
- [ ] Reset ownership on leave.
- [ ] Text props filtered; jail time capped.
- [ ] Multi-client tests for caps, pay and locks.

## See also

- [[Genre Playbook - Roleplay and Social Hangouts]]
- [[Case Study - Brookhaven RP]]
- [[Spawning Teams and Rounds]]
- [[Currency Architecture - Soft Hard and Event Currencies]]
- [[Server Authority and Validation]]

## Connected notes

[[Genre Playbook - Open-World City and Crime Roleplay]] · Tools and Inventory Systems · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience · [[Worked Builds Start Here]]

<!-- related:start -->
## Related
[[Police Chases and Wanted Levels]] · [[Instanced Interiors - Pooled House and Room Copies for Many Players]] · [[Case Study - Jailbreak]] · [[Genre Playbook - Racing and Driving]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · [[Weekend Build - Survival Gather, Craft and Place]]
<!-- related:end -->
