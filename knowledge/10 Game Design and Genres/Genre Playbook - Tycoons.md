---
tags: [game-design, genre, tycoon, idle, payback, plots]
---
# Genre Playbook - Tycoons

A Roblox **tycoon** gives each player a plot and a growing machine that earns money: droppers drop, conveyors carry, a collector converts, and buy buttons appear one after another to add more machines, walls, floors and decorations until the plot is a finished base, factory, restaurant or theme park. Tycoon is one of the genres the docs list as common on the platform (Docs, "Design for Roblox"). This playbook covers why tycoons work, the button chain as the core design object, payback maths, plot and server design, performance (the genre's classic trap), saving, and how modern tycoons add depth.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game; used here for pacing and economy lessons, not tycoon specifics), **Rule of thumb**.

---

## 1. Why tycoons work

| Trait | Why it fits Roblox |
|---|---|
| A visible thing grows | The plot is a progress bar you can walk around in |
| Ownership | "My base" is identity; friends visit |
| Idle income | Money accrues while players explore or chat |
| Built-in tutorial | The next button is always glowing in front of you |
| Building fantasy | Players feel like architects without learning building tools |
| Short decisions | Each purchase is a one-tap choice |

The weakness: once the plot is finished, the game is finished, unless rebirth, upgrades, decoration or competition continue it. Tycoons are mostly about the **first build**, so the long loop needs deliberate design.

---

## 2. The button chain

The central design object in a tycoon is the **ordered list of purchases** (buttons). Each button has a cost, an effect (income, a new area, a decoration, a defence), and prerequisites. A good chain:

1. **Starts with a free or near-free button** that builds the first dropper. The player's first input is a purchase.
2. **Alternates income and spectacle**: dropper, wall, upgrade, floor, new dropper type, big decoration.
3. **Keeps 1 to 3 buttons available at once.** One button is a corridor; ten buttons is a menu nobody reads on a phone.
4. **Puts the next button where the player is looking**, usually next to the thing just built.
5. **Opens branches** later (a second floor, a garden, a garage) so players feel they choose their build order.
6. **Ends a stage with a big reveal** (a floor appears, a roof, a vehicle), the tycoon's version of a boss kill.

Represent the chain as data:

```lua
--!strict
-- ServerStorage/TycoonChain (ModuleScript). One row per button.
export type Button = {
	id: string,
	cost: number,
	income: number,          -- income per second this adds (0 for decoration)
	requires: { string },    -- button ids that must be bought first
	model: string,           -- name of the model to reveal in the plot template
	kind: "Income" | "Build" | "Decor" | "Upgrade",
}

local CHAIN: { Button } = {
	{ id = "dropper1", cost = 0,     income = 1,   requires = {},            model = "Dropper1", kind = "Income" },
	{ id = "wall1",    cost = 25,    income = 0,   requires = { "dropper1" }, model = "Wall1",    kind = "Build" },
	{ id = "dropper2", cost = 60,    income = 2,   requires = { "dropper1" }, model = "Dropper2", kind = "Income" },
	{ id = "upgrade1", cost = 150,   income = 3,   requires = { "dropper2" }, model = "Upgrader1", kind = "Upgrade" },
	{ id = "floor2",   cost = 600,   income = 0,   requires = { "wall1", "upgrade1" }, model = "Floor2", kind = "Build" },
	-- ...
}

return CHAIN
```

The server reveals the button's model from a hidden plot template and records the id as owned. The client only draws buttons and plays the build animation.

---

## 3. Payback maths

For an income button, **payback time** is the time it takes to earn back its cost:

```
payback(i) = cost(i) / income(i)       (seconds)
```

For the player, what matters is **time to afford the next button** given everything owned:

```
wait(k) = cost(k + 1) / R(k)           R(k) = total income after k purchases
```

Design rules (rule of thumb, adjust per game):
- Early buttons pay back in **10 to 60 seconds**, so the first minutes are a stream of purchases.
- Payback grows **slowly** along the chain (for example x1.1 to x1.3 per income button), so each purchase still feels worth it.
- Decorations and build pieces have zero payback (they are pure sinks). Space them so the wait between purchases never exceeds the current stage's target (for example 2 minutes early, 5 to 10 minutes late).
- Put a **spectacle button** right after any wait that runs long; it pays the player in feelings instead of income.

In the sheet ([[Balancing with Spreadsheets and Data]]), list the chain in order with cumulative income and compute `wait(k)` for every row. Plot it. Spikes are where players leave.

### The efficient-order problem
If players can choose order, they will buy the best payback first. If your chain's "intended" order differs, either:
- enforce it with prerequisites, or
- make payback equal across the choices available at once, so order does not matter for income and the choice is about look and feel.

---

## 4. Plots and servers

| Decision | Options | Notes |
|---|---|---|
| Plots per server | Usually 6 to 12 | Server size equals plot count plus a few visitors |
| Plot assignment | Claim on join (touch a door, or auto-assign) | Auto-assign avoids the "all plots taken by AFK players" problem |
| Plot persistence | Save purchased ids; rebuild on join into any free plot | Players do not keep the same physical plot across servers |
| Visiting | Others can walk in or not | Open plots are social; locked plots protect from griefing |
| Leaving | Plot clears on leave | Stop that player's income loop and clean up their models |

### Saving a tycoon
Save **purchase ids**, not model positions:

```lua
--!strict
-- Profile shape for a tycoon (one save per player, rebuilt into whatever plot they get).
export type TycoonSave = {
	owned: { [string]: boolean }, -- button id -> bought
	cash: number,
	rebirths: number,
	version: number,              -- bump when the chain changes; migrate old ids
}
```

When the chain changes after launch (buttons renamed, removed, reordered), migrate old ids in a versioned load step. See [[Data Schema Design and Migrations]].

### Rebuilding fast
A returning player with 150 buttons should not watch 150 build animations. Rebuild silently on join (reveal all owned models at once), then animate only new purchases.

---

## 5. Performance: the dropper trap

The classic tycoon dropper spawns a physical part every second per dropper, lets it roll down a conveyor, and pays when it touches the collector. With 10 players and 15 droppers each, that is 150 new physics parts per second, each touching things, each replicating. Servers lag, phones overheat, and the game feels broken exactly when the player's plot is most impressive.

Better architecture (rule of thumb, widely used):

| Layer | Responsibility |
|---|---|
| Server | Ticks income per player on a timer (`income per second * dt`), no parts |
| Client | Spawns **visual-only** drops for plots near the camera, moves them along the conveyor path with a simple tween or CFrame update, destroys them at the collector |
| Client (far plots) | Spawns nothing, or a reduced rate |

```lua
--!strict
-- Server: income tick without physical drops.
local Players = game:GetService("Players")

local incomePerSecond: { [Player]: number } = {}
local cash: { [Player]: number } = {}

local function setIncome(player: Player, ips: number)
	incomePerSecond[player] = ips
	player:SetAttribute("IncomePerSecond", ips) -- HUD and client drop visuals read this
end

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		local dt = now - last
		last = now
		for player, ips in incomePerSecond do
			if player.Parent then
				cash[player] = (cash[player] or 0) + ips * dt
				player:SetAttribute("Cash", math.floor(cash[player]))
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	incomePerSecond[p] = nil
	cash[p] = nil -- save first, in your profile code
end)
```

The collector can still show a "+$12" pop as each visual drop arrives; the number is cosmetic, the server tick is authoritative. See [[Performance Fundamentals]], [[Physics Performance]] and [[Network Performance]].

If your tycoon's identity really is physical (ore sorting, Rube Goldberg machines), cap active parts per plot, use client-owned simulation for visuals, and keep money independent of physics outcomes so a lag spike never costs the player money.

---

## 6. The long loop for tycoons

A finished plot is the end of the classic tycoon. Ways to continue:

| Long loop | How | Risk |
|---|---|---|
| Rebirth | Reset plot for a permanent multiplier and new items in the next run | Players dislike losing a base they decorated; keep cosmetics |
| Multiple stages | Plot expands (second floor, new building, new land) | Content cost |
| Upgrade tiers | Each dropper can be upgraded several levels | Can become a long list of identical purchases |
| Decoration | Free placement of cosmetic items (a light building mode) | Needs a placement system and moderation of what can be built |
| Management layer | Hire workers, serve customers, manage stock | Adds a real second verb |
| Competition | Leaderboards for income, base ratings, visits | Rank things players control |
| Raiding / PvP | Old-style tycoons let players attack bases | Griefing and frustration for young players; opt-in only |

Rebirth maths is the same as in [[Progression and Pacing Design]]: the multiplier should grow geometrically, slightly slower than the rebirth cost.

---

## 7. Social design for tycoons

- **Visits.** A friend walking around your base is the core social moment. Make bases look different (themes, colours, chosen branches).
- **Neighbour envy.** Seeing the next plot's bigger build is an advertisement. Plots should be visible from each other.
- **Co-op plots.** Two friends sharing one plot doubles the social value; split ownership carefully in the save.
- **Gifting.** Let a player buy an upgrade for a friend's plot (with clear confirmation).
- **Raids**: if you include them, use an opt-in toggle, a shield after being raided, and losses limited to temporary resources. Never let one player destroy hours of another's progress.

See [[Social Design and Multiplayer Play]].

---

## 8. Monetisation patterns

| Product | Notes |
|---|---|
| Income multiplier pass | Most common; price against "minutes saved" |
| Auto-collect | Removes the walk to the collector; quality-of-life |
| Exclusive droppers or decorations | Cosmetic or income; keep income versions modest |
| Instant build / skip | Sells time; keep the free wait reasonable |
| Extra plot slots or themes | Cosmetic |

A tycoon whose free pacing is deliberately painful so that "skip" sells is the genre's main ethical risk. See [[Ethical Design and Player Trust]].

---

## 9. Lessons from the reference project that apply to tycoons

The reference project is not a tycoon, but its economy lessons transfer:
- **Price in minutes of income.** Its upgrade board was priced as 1 to 2 minutes of income for first-ring nodes and 1 to 2 hours for capstones, at the zone where each unlocks. Do the same with tycoon buttons.
- **Offline income should be a fraction of active income and capped** (15% of active, 8 hours, nothing in the first session before the tutorial ends). Tycoons are the genre most tempted to pay full idle income; it collapses pacing.
- **One goal on screen.** Its next-goal tracker gave a single target with a trail; in a tycoon, the glowing next button plays that role, so do not let five buttons glow at once.

---

## 10. Common mistakes

| Mistake | Better |
|---|---|
| Physical parts for every drop on the server | Server income tick; client-only visual drops |
| Ten buttons visible at once | One to three available, next to the last build |
| Payback rising sharply mid-chain | Plot wait(k); smooth spikes with spectacle buttons |
| Saving positions instead of ids | Save purchase ids; rebuild from the template |
| Rebuild animation for every owned button on join | Silent rebuild, animate only new purchases |
| Plot finished, game over | Stages, upgrades, decoration, rebirth |
| Full-rate idle income | A capped fraction of active |
| Forced PvP raids | Opt-in, shields, limited losses |

## 11. Checklist

- [ ] First input is a free purchase that builds the first income source.
- [ ] Chain data in one module; prerequisites encode intended order.
- [ ] wait(k) plotted; early payback 10 to 60 s; spikes smoothed.
- [ ] Next button always visible near the last build.
- [ ] Income ticked on the server without physics; visuals client-side.
- [ ] Save purchase ids with a version and migrations.
- [ ] Long loop planned before launch.
- [ ] Plots visible to each other; visiting works.

## See also
- [[Genre Playbook - Simulators]], [[Core Loops and Session Design]], [[Progression and Pacing Design]]
- [[Balancing with Spreadsheets and Data]], [[Economies and Currencies]], [[Data Schema Design and Migrations]]
- [[Performance Fundamentals]], [[Physics Performance]], [[Network Performance]]
- [[Social Design and Multiplayer Play]], [[Game Passes]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Tycoon Plots and Droppers End to End]] · [[Genre Playbook - Survival and Crafting]] · [[Core Loop]] · [[Pricing Curves and Upgrade Costs]] · [[Power Curve]] · [[Genre Systems Start Here]]
<!-- auto-links:end -->
