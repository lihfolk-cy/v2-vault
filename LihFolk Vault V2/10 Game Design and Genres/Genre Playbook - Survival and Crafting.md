---
tags: [game-design, genre, survival, crafting, building, resources, inventory, persistence, type/guide, area/design, level/intermediate, area/data]
---
# Genre Playbook - Survival and Crafting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Persistent shared world as a first project -> Run-based or per-player bases first
> - Avoid: World-space saved coordinates -> Plot-relative, grid-snapped, versioned
> - Avoid: Loading a whole base in one frame -> Batched, nearest first
> - Persistence model chosen and explained in-game ("your base saves; the world resets").
> - Base save and load tested at the maximum piece count, including version migration.
> - Load time and server memory measured with a full server of large bases.
>
> Cost: TL;DR ~160 tok · whole note ~3.9k tok. Read more: ## 1. Core loop · ## 2. Session length and persistence model · ## 9. Common mistakes · ## 10. Launch checklist
<!-- tldr:end -->

Survival games put players in a hostile world with needs (hunger, thirst, temperature, health) and let them gather resources, craft tools, build shelter and push into more dangerous areas. On Roblox the genre spans several shapes: short-session co-op survival (survive a set number of nights), persistent-world sandbox survival with bases that save, PvP survival where other players are the main threat, and "survive the disaster" party variants. They share one engine: **gather, craft, build, survive, expand**.

The genre has deep retention when it works, because players invest hours in a base they care about. It also has the most dangerous technical profile on Roblox: thousands of player-placed parts, saving and loading those parts, item duplication bugs and griefing.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; its crafting and salvage lessons transfer), **Rule of thumb**.

---

## 1. Core loop

```
gather -> craft -> build / equip -> survive a threat -> unlock a new area or tier -> gather rarer things
```

| Loop | Length | Content |
|---|---|---|
| Action | Seconds | Swing at a tree, pick up a stone, eat |
| Trip | 2 to 10 min | Go out, gather, fight, come back before night or before needs run out |
| Day cycle | 8 to 20 min | Day gathering, night defence |
| Tier | Hours | Stone tools to metal to advanced; new biome unlocked |
| Base | Days to weeks | The thing players are really building |

### Pressure is the design lever
Survival only works if the world pushes back. Pressure sources, from gentle to harsh:

| Pressure | Effect | Risk |
|---|---|---|
| Needs (hunger, thirst) | Forces trips, gives food value | Tedious if drain is too fast |
| Day and night | Rhythm: safe gathering then danger | Nights too long bore; too short lack tension |
| Hostile creatures | Combat and defence | Griefs new players if spawns are near spawn |
| Weather and temperature | Gear and shelter matter | Hard to read on phones |
| Other players (PvP) | Highest tension | Toxicity, raiding offline bases |
| Decay (base upkeep) | Keeps the world clean | Players hate losing builds while offline |

Pick two or three, not all. A casual co-op survival game for young players might use only day/night and creatures, with needs that never kill (low food only slows you).

### Needs tuning
- Drain so that one trip uses about half of a full bar (rule of thumb). Players should think about food once per trip, not every minute.
- Starving should hurt slowly and warn loudly. Death from a need the player did not notice feels unfair.
- Food variety should matter (better food fills more or gives buffs), which gives farming and cooking a purpose.

---

## 2. Session length and persistence model

The most important decision in the genre: **what persists, and where?**

| Model | Session | What saves | Fit |
|---|---|---|---|
| Run-based (survive N nights, then reset) | 20 to 60 min | Meta unlocks only | Co-op, younger audiences, simple saving |
| Persistent personal world (private server or own plot) | Open | Whole base per player | Builders, solo and small groups |
| Persistent shared server world | Open | Server state, wiped on a schedule | PvP survival; complex and risky |
| Hybrid: base saved per player, world resets per server | Open | Base blueprint, inventory | The common Roblox compromise |

Run-based is by far the easiest to ship and the safest for retention: players get a complete arc in one session and a reason to come back (meta unlocks, new classes). Persistent shared worlds are what players often ask for and what most small teams should not build first.

### Saving a base
A base is a list of pieces: type, position relative to the base origin, rotation, health, owner, and for containers, their contents. Rules:
- **Save relative to a plot origin**, never in world coordinates. Plots move between servers.
- **Grid-snap positions** so you can store them as small integers. A base of 2,000 pieces stored as JSON with full-precision floats can approach DataStore value limits; a compact format (or a buffer, Base64-encoded) fits much more. Check the current per-key size limit in the docs before designing (Docs, "Data stores": 4 MB per value as of October 2026).
- **Version the format.** You will add piece types and change footprints. See [[Data Schema Design and Migrations]] and [[Schema Migrations - Worked Case Studies]].
- **Load progressively.** Spawning 2,000 pieces in one frame causes a long hitch; spawn in batches across frames, nearest first. See [[Case Study - Fast Join and Deferred Loading]].
- **Saving containers separately from layout** keeps item data atomic with the player's inventory and reduces duplication risk.

```lua
--!strict
-- Encoding a grid-snapped base piece compactly. 4-stud grid, 16-bit coordinates, 4 rotations.
local GRID = 4

export type Piece = { kind: number, gx: number, gy: number, gz: number, rot: number }

local function encode(pieces: { Piece }): buffer
	local b = buffer.create(#pieces * 8)
	for i, p in pieces do
		local o = (i - 1) * 8
		buffer.writeu16(b, o, p.kind)
		buffer.writei16(b, o + 2, p.gx)
		buffer.writei16(b, o + 4, p.gy)
		buffer.writei8(b, o + 6, p.gz)  -- vertical layers; small range
		buffer.writeu8(b, o + 7, p.rot) -- 0..3 quarter turns
	end
	return b
end

local function decode(b: buffer): { Piece }
	local out: { Piece } = {}
	for o = 0, buffer.len(b) - 8, 8 do
		table.insert(out, {
			kind = buffer.readu16(b, o),
			gx = buffer.readi16(b, o + 2),
			gy = buffer.readi16(b, o + 4),
			gz = buffer.readi8(b, o + 6),
			rot = buffer.readu8(b, o + 7),
		})
	end
	return out
end

-- World position of a piece relative to a plot origin CFrame.
local function pieceCFrame(origin: CFrame, p: Piece): CFrame
	local offset = Vector3.new(p.gx * GRID, p.gz * GRID, p.gy * GRID)
	return origin * CFrame.new(offset) * CFrame.Angles(0, p.rot * math.pi / 2, 0)
end

return { encode = encode, decode = decode, pieceCFrame = pieceCFrame }
```

Note the axis choice: here `gy` is the horizontal second axis and `gz` the vertical layer, packed into one signed byte (-128 to 127 layers). Document your own convention in the module; mixed-up axes are the most common base-saving bug. DataStores accept buffers directly in recent engine versions; if you store strings instead, Base64-encode the bytes. Verify which your setup uses before relying on it. See [[Buffers and Binary Data]] and [[DataStore Fundamentals]].

---

## 3. Crafting design

### Recipes and tiers
- Organise recipes into **tiers** gated by a station (workbench, forge, lab) and by resources from a specific biome. A new tier should require a trip somewhere new.
- **Show recipes the player cannot make yet**, with missing ingredients highlighted. Hidden recipes create wiki dependence and confuse young players.
- **Crafting time**: instant for basic items, short timers (2 to 10 s) for advanced, never long real-time timers in a session-based game.
- **Salvage**: breaking items into part of their materials gives every drop value. The reference project's salvage-then-forge loop worked because duplicates always had a use.

### Resource economy
Write the economy as faucets (gathering, loot) and sinks (crafting, repairs, upkeep). Durability is the classic survival sink: tools break, players gather more. Keep durability generous; a pickaxe breaking every two minutes is a chore. See [[Economy Inflation Sinks and Faucets Math]] and [[Economies and Currencies]].

### Inventory
Survival inventories are dense: stacks, slots, a hotbar, containers, equipment. Server-authoritative moves only (the client asks "move stack from slot 4 to chest slot 12"; the server checks both containers, ownership, distance to the chest, and stack limits). Every move that can create items (split, merge, transfer) is a duplication risk. See [[Tools and Inventory Systems]], [[Saved Inventory End to End]] and [[Economy Exploits - Dupes Races and Purchase Abuse]].

---

## 4. Building

| Approach | Pros | Cons |
|---|---|---|
| Grid snapping (walls, floors, roofs on a fixed grid) | Easy to save, easy to validate, clean-looking | Less creative freedom |
| Free placement with surface snapping | Creative | Hard to validate, overlap exploits, ugly bases |
| Prefab structures (place a whole hut) | Fast, good for young players | Little expression |

Most Roblox survival games use grid snapping with a few free-placed decorations. Validation on the server: the player owns the build area (or the area is unclaimed), the piece fits the grid, it is supported (if structural integrity exists), it does not overlap other pieces or players, and the player has the materials. See [[Grid Placement and Player Building Systems]] and [[Modular Environment Kits]].

### Structural integrity (optional)
Requiring pieces to connect to a foundation prevents floating bases and makes raiding meaningful. Compute support as a graph walk from foundations when pieces are added or destroyed; cache it. Recomputing integrity for an entire 2,000-piece base on every hit is a server spike waiting to happen.

### Instance and part budgets
A full server of eight players with 1,500 pieces each is 12,000 models, each possibly several parts. Use simple meshes, anchor everything, turn off `CanTouch` and `CanQuery` where not needed, and use streaming so far bases are not loaded on every client. See [[Art Budgets - Triangles Draw Calls Memory]], [[Instance Streaming]] and [[Case Study - Cutting a Million Instances]].

---

## 5. World and creatures

- **Biomes as tiers**: each biome has resources for the next tier and creatures that test the current tier's gear. See [[Zone and Biome Art Direction]].
- **Procedural or hand-made worlds**: procedural worlds give replay in run-based games; hand-made worlds give landmarks and better navigation. A hand-made world with procedural resource placement is a good compromise. See [[Procedural World Generation]].
- **Creature counts** follow the same rules as any NPC-heavy game: cap per area, despawn far from players, simplify AI when nobody is near. See [[NPC AI and Behaviour]] and [[Pathfinding Edge Cases and Fallbacks]].
- **Night raids on bases** need pathfinding to bases, which is expensive for complex player-built shapes. Many games let creatures attack the nearest wall piece rather than path inside.
- **Terrain gathering** (digging, chopping) should modify instances, not voxel terrain, unless the game is designed around it; editing terrain at scale and saving it is costly. See [[Terrain Deep Dive - Materials Water and Performance]].

---

## 6. Multiplayer, PvP and griefing

- **Co-op default.** Small groups (2 to 6) surviving together is the friendliest form, and friends invite friends.
- **PvP opt-in.** If PvP exists, consider zones, flags or separate servers. Raiding offline players' bases is the most-complained-about mechanic in the genre; offline protection (bases invulnerable while the owner is away, or raids only in set windows) prevents it.
- **Griefing** (blocking doors, building walls around others, stealing from shared chests) needs ownership rules: build permissions per plot, chest locks, team-based access. See [[Social Design and Multiplayer Play]].
- **Trading** between players is common; build it as an atomic server-side exchange. See [[Trading Systems Without Duplication]].

---

## 7. Monetisation that fits

| Product | Fit | Notes |
|---|---|---|
| Private servers | Strong | Players want a world for their friends |
| Cosmetic building sets (themes, colours, decorations) | Strong | Bases are displayed; expression sells |
| Character cosmetics | Good | |
| Extra storage or base size | Good | Clear value; base game must be enough to enjoy |
| Starter kits (tools and food) | Acceptable | Speeds early game; keep modest |
| Revives / keep inventory on death | Careful | Fine in co-op; pay-to-win in PvP |
| Resource packs in PvP | Avoid | Directly buys power over others |

Remember that young players can lose purchased items to bugs or raids; your support policy for lost paid items should be decided before launch. See [[Refunds Chargebacks and Purchase Support]].

---

## 8. Patterns successful survival games share

Patterns, not copies:
- **A strong first night.** The first 10 minutes teach gathering, crafting a tool, building a shelter and surviving one threat. Players who survive night one stay. See [[First-Time User Experience and Onboarding]].
- **A clear "next tier" goal** always visible: the next station or tool, with its ingredients.
- **Shared spaces for showing off** (visiting friends' bases, base rating).
- **Seasons and wipes** in persistent PvP servers, announced in advance, with meta rewards that survive the wipe.
- **Events that change the world** (a meteor, a blood moon, a boss invasion) give reasons to log in.
- **Generous saving and honest communication** about what saves.

---

## 9. Common mistakes

| Mistake | Better |
|---|---|
| Persistent shared world as a first project | Run-based or per-player bases first |
| World-space saved coordinates | Plot-relative, grid-snapped, versioned |
| Loading a whole base in one frame | Batched, nearest first |
| Client-authoritative inventory moves | Server validates every move |
| Needs that drain every minute | One bar per trip; warnings |
| Raids on offline players | Offline protection or raid windows |
| Recomputing integrity for whole bases on every hit | Incremental graph updates |
| Tools that break constantly | Generous durability; salvage |

## 10. Launch checklist

- [ ] Persistence model chosen and explained in-game ("your base saves; the world resets").
- [ ] Base save and load tested at the maximum piece count, including version migration.
- [ ] Load time and server memory measured with a full server of large bases.
- [ ] Inventory moves fuzzed for duplication (split, merge, transfer, disconnect mid-move).
- [ ] Session locking on player data. See [[Session Locking and Profile Libraries]].
- [ ] First night completed by new testers without help.
- [ ] Griefing protections: plot permissions, chest locks, PvP rules.
- [ ] Creature caps and despawn rules measured.
- [ ] Support policy for lost paid items.

## See also
- [[Genre Playbook - Tycoons]], [[Genre Playbook - Simulators]], [[Core Loops and Session Design]]
- [[Grid Placement and Player Building Systems]], [[Tools and Inventory Systems]], [[Saving Correctly - Autosave and BindToClose]]
- [[Data Loss Prevention and Recovery]], [[Progression and Pacing Design]], [[Retention and Return Hooks]]

## Connected notes
<!-- auto-links:start -->
[[Procedural Generation Start Here]] · Case Study - 99 Nights in the Forest · Tycoon Plots and Droppers End to End · Progression Levels and Unlocks · Top Games Case Studies Start Here · Multiplayer Services Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weekend Build - Survival Gather, Craft and Place]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Party and Minigame Collections]] · [[Simulator and RNG Genre Teardown]] · [[Genre Playbook - Horror and Story]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Genre Playbook - Combat and RPG]]
<!-- related:end -->
