---
tags: [gameplay, tools, inventory, backpack, equip, items, type/guide, area/gameplay, level/intermediate, api/HttpService, api/Humanoid, api/Tool]
---
# Tools and Inventory Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Inventory as Tools in Backpack -> Data inventory, Tool only for equipped
> - Avoid: Client sends stats or rewards -> Server catalogue
> - Avoid: Yield between check and apply -> Plan then apply, no yields
> - Tool used only for holding; inventory lives in the profile.
> - Every action validated, rate-limited, idempotent, non-yielding during mutation.
> - Protection rules shared by every bulk action.
>
> Cost: TL;DR ~140 tok · whole note ~3.5k tok. Read more: ## 1. The Tool object · ## 4. Server-authoritative inventory actions · ## 8. Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has a built-in item model: `Tool` objects that live in a player's `Backpack`, appear in the default hotbar, and are held in the right hand when equipped. It is perfect for a sword-fighting place in 2010 and a poor fit for a game where players own 300 weapons with stats, stars and upgrade levels. Most modern games keep the Tool for **holding** (it gives you equip events, the grip, and compatibility with other systems) and build their own **inventory** as server data. This note covers the Tool API, its traps, and the design of a server-authoritative inventory that scales.

Related: [[Combat Systems Architecture]], [[Data Schema Design and Migrations]], [[Economies and Currencies]], [[Equip Draw and Flourish Systems]], [[Custom Rigs - Weapons and Props]].

Source labels: **Docs** (Tool reference, checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. The Tool object

| Member | Behaviour (Docs) |
|---|---|
| `Handle` | A BasePart named `Handle`; held in the right hand by default |
| `RequiresHandle` | When true the Tool only works with a Handle; `Equipped`/`Unequipped` do not fire without one |
| `Grip` (with hidden `GripPos`, `GripForward`, `GripRight`, `GripUp`) | Offset of the handle in the hand |
| `CanBeDropped` | Backspace drops the Tool into Workspace when true |
| `Enabled` | False blocks `Activate`/`Deactivate` and their events |
| `ManualActivationOnly` | True: clicks do not fire `Activated`, only `Tool:Activate()` does |
| `ToolTip`, `TextureId` | Hover text and hotbar icon |
| `Activated` / `Deactivated` | Click pressed / released while equipped; not fired with Ctrl held |
| `Equipped(mouse)` / `Unequipped` | Moved into / out of the character |

Where Tools live:
- `StarterPack`: copied into every player's Backpack on each spawn (Docs).
- `Player.Backpack`: the player's unequipped tools. Recreated on respawn; `LoadCharacterAsync` clears it (Docs).
- The character model: the equipped tool is parented under the character.
- `StarterGear` (per player): tools that persist across respawns for that player in the session.

`Humanoid:EquipTool(tool)` and `Humanoid:UnequipTools()` equip and unequip from code.

### Tool traps
- **Equipping moves the instance.** The Tool's parent changes from Backpack to character. Code that cached `backpack.Sword` breaks while it is equipped. Look up by attribute or by your own registry.
- **Respawn wipes the Backpack.** Granting tools once on join loses them on death. Grant from `StarterGear`, from your inventory data on every `CharacterAdded`, or not as Tools at all.
- **`Activated` carries no aim.** The server learns a click happened, not where the mouse was. Send aim through your own remote and validate it.
- **Click spam.** `Activated` fires per click; rate-limit on the server ([[Rate Limiting and Abuse Prevention]]).
- **Dropping.** `CanBeDropped` defaults to dropping with Backspace in many templates. A dropped weapon is an instance in Workspace that anyone can pick up. Set it false unless dropping is a feature.
- **Name collisions.** `FindFirstChild("Sword")` returns the first child with that name, whatever its class. **Measured:** a clip named `Origin` added to a folder that also held a RemoteEvent `Origin` stopped a whole weapon kit's damage, because a lookup found the clip. Keep different kinds of children in separate folders or check `IsA`.

### Holding a weapon for animation
The default grip is a `Weld` named `RightGrip` created between the right hand and the Handle. Welds cannot be animated. Games with weapon animations replace it with a `Motor6D` so clips can move the weapon relative to the hand. **Measured:** the reference project's held weapon is a Tool named `Blade` with a `BladeId` attribute; the server builds it, destroys `RightGrip`, and attaches the handle with a Motor6D (`C0` at the right-grip attachment, `C1` from the tool's `Grip`). A client-side copy of the build function had to be kept in step with the server's. See [[Custom Rigs - Weapons and Props]] and [[Weapon Rig Player]].

---

## 2. Custom hotbar and backpack

To use your own UI, disable the default one on each client:

```lua
-- LocalScript
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
```

Then bind your own number keys and gamepad buttons ([[Input - UserInputService and ContextActionService]]) and call a server remote to equip. The server equips with `Humanoid:EquipTool` after validation, so the client never parents Tools itself.

---

## 3. Inventory as data

The inventory is a **list of entries in the player's saved profile**, not a folder of Tools. Tools (or models) are created only for what is equipped.

```lua
--!strict
export type ItemEntry = {
	uid: string,        -- unique per owned copy; never reuse
	id: string,         -- catalogue id, e.g. "frostblade"
	stars: number,      -- fusion stars 0..5
	forge: number,      -- upgrade level 0..3
	locked: boolean,    -- protected from salvage, sale, fusion
	favorite: boolean,
	obtainedAt: number, -- os.time()
}

export type Inventory = {
	items: { ItemEntry },
	equipped: string?,  -- uid
	cap: number,
}
```

Design rules:
- **Unique ids per copy.** Stacked counts (`{id = "potion", count = 12}`) suit consumables; equipment with per-copy state (stars, upgrades) needs a `uid`. Generate it with `HttpService:GenerateGUID(false)` on the server.
- **Catalogue on the server.** Stats come from a shared config by `id`; never trust stats sent by the client.
- **Dense arrays.** Save arrays as arrays. **Measured:** sparse Lua tables saved to DataStores came back with string keys in the reference project; keep saved lists dense ([[Data Schema Design and Migrations]]).
- **Removing items from the game.** When a catalogue item is deleted, saves still contain it. The reference project drops unknown ids on load. Decide whether to refund, replace or drop, and do it in one migration.
- **Caps.** A bag cap (with headroom for passes: the reference project's VIP gave 1.5x) keeps saves small and creates a reason to salvage or fuse.

### Protection rules
Bulk actions (sell duplicates, auto-salvage, fuse, craft, trade) must never consume:
- the equipped item;
- favourites and locked items;
- special items (developer-only, event exclusives);
- anything while a trade involving the player is in progress.

**Measured.** The reference project's fusion and auto-salvage code had exactly this list and "sell dupes" was changed to keep starred or marked copies and prefer the most-starred keeper. One missing rule here produces the worst support ticket a game can get: "it deleted my best item".

---

## 4. Server-authoritative inventory actions

Every inventory change goes through the server with validation, idempotency and no yields in the middle of a mutation.

### Plan, then apply
Compute the whole change first (which entries are removed, what is added, currency deltas), check it, then apply it in one go without yielding. A yield in the middle (a DataStore call, a `WaitForChild`) lets a second request run against half-changed state: the classic duplication bug.

### Tokens and quotes
For destructive or valuable actions, use a two-step **quote then commit**:
1. Client asks for a quote ("salvage these 12 items").
2. Server computes the result, stores it under a one-time token with a short expiry, returns token and preview.
3. Client shows the preview; on confirm, sends the token.
4. Server re-validates (items still owned, not equipped, not locked) and applies; the token is consumed so a repeated commit does nothing.

**Measured.** The reference project's salvage service used Quote, token, Commit, plus a server range check (18 studs) to the salvage station when it was a world object. Its fusion service used token receipts (idempotent), a 0.4 s throttle, and plan-then-apply with no yield.

```lua
--!strict
local HttpService = game:GetService("HttpService")

type Quote = { player: Player, uids: { string }, reward: { [string]: number }, expires: number }
local quotes: { [string]: Quote } = {}

local Salvage = {}

function Salvage.quote(player: Player, inv: any, uids: { string }, rewardFor: (any) -> { [string]: number }): (string?, { [string]: number }?)
	local total: { [string]: number } = {}
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if typeof(uid) ~= "string" or seen[uid] then return nil end
		seen[uid] = true
		local entry = inv.byUid[uid]
		if not entry or entry.locked or entry.favorite or inv.equipped == uid then
			return nil
		end
		for k, v in rewardFor(entry) do
			total[k] = (total[k] or 0) + v
		end
	end
	local token = HttpService:GenerateGUID(false)
	quotes[token] = { player = player, uids = table.clone(uids), reward = total, expires = os.clock() + 30 }
	return token, total
end

function Salvage.commit(player: Player, inv: any, token: unknown, grant: (Player, { [string]: number }) -> ()): boolean
	if typeof(token) ~= "string" then return false end
	local q = quotes[token]
	quotes[token] = nil -- consume first: a repeat does nothing
	if not q or q.player ~= player or os.clock() > q.expires then return false end
	-- Re-validate: state may have changed since the quote.
	for _, uid in q.uids do
		local e = inv.byUid[uid]
		if not e or e.locked or e.favorite or inv.equipped == uid then return false end
	end
	-- Apply without yielding.
	for _, uid in q.uids do
		inv.remove(uid)
	end
	grant(player, q.reward)
	return true
end

return Salvage
```

---

## 5. Replicating inventory to the client

The client needs the inventory to draw the backpack. Options:

| Method | Notes |
|---|---|
| A RemoteEvent with the full list on change | Simple; send diffs when lists are large |
| A JSON string attribute on the Player | Easy to read, but attributes on Player replicate to **every** client |
| Owner-only channel | Data under the player's own `PlayerGui` (replicates only to that player) |
| Instances (Folders/Values) in the player | Visible to all; heavy at scale |

**Measured.** The reference project originally wrote inventory, bestiary, quest and potion JSON as attributes on the Player. In a crowded server every client received every player's inventory on each change, which showed up as lag. The fix moved them to attributes on a disabled ScreenGui inside each player's own `PlayerGui` (owner-only replication, `ResetOnSpawn` false), mirrored locally onto the LocalPlayer so client readers did not change; other players' data is fetched on request (for trading or inspecting). See [[Replication Rules]] and [[Network Performance]].

---

## 6. Equipping

Server flow for "equip uid X":
1. Validate: uid owned, not already equipped, player alive, not in a locked state (cutscene, trade).
2. Unequip the current tool (destroy its Tool instance).
3. Build the Tool or model for the new entry from the catalogue (or clone a template), set attributes (`ItemId`, `Uid`, `Stars`).
4. Parent to the character and call `Humanoid:EquipTool`.
5. Save `equipped` in the profile; re-equip on each `CharacterAdded`.

Visual extras (an equip flourish, a title above the head, a trail) are client presentation driven by those attributes ([[Equip Draw and Flourish Systems]]).

Auto-equip the best item for new players. The reference project's tutorial equipped the first rolled weapon on a single button with a spotlight, because a new player who never equips sees no reason to roll again ([[First-Time User Experience and Onboarding]]).

---

## 7. Trading (briefly)

Trading multiplies every inventory risk. Minimum rules: both players confirm the final offer after a short countdown; any change resets confirmations; the server re-validates ownership and protection at commit; both inventories change in one non-yielding step; both profiles save promptly; log every trade. Lock items in an active trade (a `TradeBusy` flag) so no other action can consume them. Requirements to trade (minimum play time, rolls or rebirths; the reference project required 500 rolls and 2 rebirths) reduce alt-account abuse.

---

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Inventory as Tools in Backpack | Lost on respawn, cannot hold stats | Data inventory, Tool only for equipped |
| Client sends stats or rewards | Exploits | Server catalogue |
| Yield between check and apply | Duplication | Plan then apply, no yields |
| No protection list | "It deleted my best item" | Equipped, favourite, locked, trade-busy never consumed |
| Inventory on Player attributes | Lag in full servers | Owner-only channel |
| Repeatable commits | Double rewards | One-time tokens |
| Sparse saved arrays | Corrupted lists | Dense arrays |

## Checklist
- [ ] Tool used only for holding; inventory lives in the profile.
- [ ] Every action validated, rate-limited, idempotent, non-yielding during mutation.
- [ ] Protection rules shared by every bulk action.
- [ ] Inventory replicated only to its owner.
- [ ] Removed catalogue items handled in a migration.

## See also
[[Economies and Currencies]] · [[RNG Drops and Luck Systems]] · [[Progression Levels and Unlocks]] · [[Data Schema Design and Migrations]] · [[Purchase Data and Receipts]] · [[Equip Draw and Flourish Systems]] · [[Custom Rigs - Weapons and Props]] · [[Menu Archetypes - Shop Settings Codes Rewards]]

## Connected notes
<!-- auto-links:start -->
[[Trading Systems Without Duplication]] · Saved Inventory End to End · Links - Inventory and items · Pet Hatching and Following End to End · Schema Migrations - Worked Case Studies · Procedural Loot and Item Generation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Quests and Objectives]] · [[Character Select and Class Systems with Different Rigs]] · [[Spawning Teams and Rounds]] · [[Characters and Humanoids]] · [[Status Effects Buffs and Stacking Rules]] · [[Downed, Revive and Bleed-Out States]] · [[Hitboxes and Hit Detection]] · [[Custom Character Controllers]]
<!-- related:end -->
