---
tags: [qol, sprint, hold-vs-toggle, auto-sprint, auto-equip, hotbar, quick-slots, controls, server-authority, type/guide, area/input, area/gameplay, level/intermediate, api/InputAction, api/Humanoid]
---
# Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots

<!-- tldr:start -->
> [!tldr] TL;DR
> - Respawn still sprinting: Toggle state not cleared -> Force-off on death, menu, focus loss
> - Hand fatigue complaints: Hold-only sprint/aim -> Hold/Toggle option
> - Speed exploit via sprint remote: Client sets WalkSpeed or server trusts value -> Server picks speed from its own state
> - Hold/Toggle for every sustained action, with force-off paths.
> - Auto-sprint option; touch defaults sensible.
> - Server decides speed; client prediction corrected.
>
> Cost: TL;DR ~150 tok · whole note ~2.0k tok. Read more: ## 2. Auto-sprint · ## 3. Auto-equip · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Small control conveniences add up to whether a game feels effortless or tiring. Holding Shift for a whole session hurts hands; re-equipping the same tool after every respawn is tedious; digging into an inventory for a potion mid-fight gets players killed. This note covers four options: **hold vs toggle** for sustained actions, **auto-sprint**, **auto-equip** on spawn, and **quick-use slots**, with the server-authority rules that keep them from becoming exploits. Hold-input pitfalls are in [[Hold-to-Attack Input That Never Sticks]]; the shift-lock conflict in [[Shift-Lock Sprint and Gamepad B for Menus]]; tools in [[Tools and Inventory Systems]].

Sources: **Roblox docs** for `InputAction` events (https://create.roblox.com/docs/reference/engine/classes/InputAction) and `Humanoid:EquipTool` (https://create.roblox.com/docs/reference/engine/classes/Humanoid). Defaults are **Rule of thumb**, aligned with the Xbox Accessibility Guidelines on input (https://learn.microsoft.com/en-us/gaming/accessibility/guidelines).

## 1. Hold vs toggle for every sustained action

Any action held for more than a second or two (sprint, aim, block, crouch, charge) should offer **Hold** and **Toggle** modes. Implement it once:

```lua
--!strict
-- Wraps a Bool InputAction so gameplay code only sees "active" changes.
local function holdOrToggle(action: InputAction, getMode: () -> string, onActive: (boolean) -> ())
	local active = false
	local function set(v: boolean)
		if v == active then return end
		active = v
		onActive(v)
	end
	action.Pressed:Connect(function()
		if getMode() == "toggle" then set(not active) else set(true) end
	end)
	action.Released:Connect(function()
		if getMode() == "hold" then set(false) end
	end)
	return function() set(false) end -- force-off, e.g. on death or menu open
end
```

The returned force-off matters: toggles must clear on death, on stun, when a menu opens and when the window loses focus (`UserInputService.WindowFocusReleased`), or the player respawns still "sprinting".

## 2. Auto-sprint

Auto-sprint means "run whenever moving". Common in simulators and obbies where walking has no purpose. Options: **Off**, **Hold/Toggle key**, **Always**. On touch, "Always" is often the best default because there is no free thumb for a sprint button (**Rule of thumb**).

Server authority: the client asks to sprint; the server decides the speed. Stamina, slows and stuns are server state.

```lua
--!strict
-- Server: validate sprint requests; the client never sets WalkSpeed itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.SetSprint :: RemoteEvent

local WALK, RUN = 16, 24
local lastToggle: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player: Player, wants: any)
	if typeof(wants) ~= "boolean" then return end
	local now = os.clock()
	if now - (lastToggle[player] or 0) < 0.1 then return end
	lastToggle[player] = now
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return end
	local stunned = player.Character:GetAttribute("Stunned") == true
	local stamina = (player:GetAttribute("Stamina") or 0) :: number
	humanoid.WalkSpeed = if wants and not stunned and stamina > 0 then RUN else WALK
end)
```

Responsiveness gotcha: waiting for the server round trip before speeding up feels laggy. The common compromise is to let the client predict the speed change locally and have the server correct it; movement anti-cheat then checks distance against the server-known speed with tolerance ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]). Whatever you choose, the server's value wins.

## 3. Auto-equip

"Equip my last tool on spawn" saves a click every life. Store the last equipped tool's id (not the instance) on the server when the player equips; on `CharacterAdded`, wait until the backpack is populated and equip it.

```lua
--!strict
local Players = game:GetService("Players")

local lastEquipped: { [Player]: string } = {}

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then lastEquipped[player] = child:GetAttribute("ItemId") :: string end
	end)
	local wanted = lastEquipped[player]
	if wanted == nil or player:GetAttribute("AutoEquip") ~= true then return end
	task.defer(function()
		local backpack = player:WaitForChild("Backpack")
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("ItemId") == wanted then
				humanoid:EquipTool(tool)
				return
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(c) onCharacter(player, c) end)
end)
```

The `AutoEquip` attribute is set by the settings service from the player's saved value. Do not auto-equip into a safe zone where tools are disabled, or during a cutscene.

## 4. Quick-use slots

A quick slot binds a consumable or ability to a key/button without opening the inventory. Rules:

- **Bind by item type, not instance**: slot 1 = "Health Potion"; it keeps working as the stack changes, and shows a count.
- **Server validates every use**: the player owns one, the cooldown has passed, the item is usable now. The slot UI is a request, never the authority.
- **Cooldown shown on the slot** (radial sweep and seconds remaining); see [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]].
- **Controller**: d-pad directions map well to four slots; on touch, a small expandable cluster near the attack button.
- **Empty slot behaviour**: greyed with "0", not removed, so muscle memory survives.
- **Save the slot assignments** per player; they are settings, not inventory.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Respawn still sprinting | Toggle state not cleared | Force-off on death, menu, focus loss |
| Hand fatigue complaints | Hold-only sprint/aim | Hold/Toggle option |
| Speed exploit via sprint remote | Client sets WalkSpeed or server trusts value | Server picks speed from its own state |
| Auto-equip fails sometimes | Backpack not populated yet | Defer and look up by item id |
| Quick slot uses item you do not have | Client-trusted use | Server validates ownership and cooldown |
| Slot breaks when stack runs out | Bound to instance | Bind to item type |

## Checklist

- [ ] Hold/Toggle for every sustained action, with force-off paths.
- [ ] Auto-sprint option; touch defaults sensible.
- [ ] Server decides speed; client prediction corrected.
- [ ] Auto-equip by item id, deferred, respects safe zones.
- [ ] Quick slots by item type, server-validated, cooldown visible, saved.

## See also

- [[Hold-to-Attack Input That Never Sticks]]
- [[Tools and Inventory Systems]]
- [[Server Authority and Validation]]
- [[Rebinding Controls with the Input Action System]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Shift-Lock Sprint and Gamepad B for Menus]] · [[Controller Support QoL]] · [[Mobile Button Layout Editor]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Accessibility Cross-Links for QoL Settings]] · [[Top 25 QoL Wins by Effort]] · [[Quick Respawn and Spawn Protection]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Inventory QoL - Sort Filter Search Stack and Lock]] · [[Aim Assist and Generous Hitboxes]] · [[Settings Menu Essentials and Persistence]]
<!-- related:end -->
