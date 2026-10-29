---
tags: [interaction, clickdetector, proximityprompt, touched, doors, pickups, shops, buttons, type/guide, area/gameplay, level/beginner, api/ClickDetector, api/ProximityPrompt, api/BasePart, api/TweenService]
---
# Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: granting rewards from a `Touched` handler with no debounce.
> - Avoid: building "is in the area" on `TouchEnded`.
> - Avoid: trusting `Triggered` or `MouseClick` without a server distance and state check.
> - Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries.
> - Every handler runs on the server and checks distance, state and a cooldown.
> - `Touched` handlers map the part to a player, ignore non-characters, and debounce per player or per object.
>
> Cost: TL;DR ~170 tok · whole note ~3.5k tok. Read more: ## 2. ProximityPrompt · ## 6. Worked pattern: a door with ProximityPrompt and TweenService (server) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Doors, buttons, pickups, shop counters, levers and NPCs all need the same thing: a way for a player to say "use this" that works on PC, phone and console, and that the server can trust. Roblox gives you three built-in tools (`ClickDetector`, `ProximityPrompt`, `Touched`) plus spatial queries for areas. This note is about picking the right one and validating it on the server. Area enter and exit (music, lighting, safe zones) has its own note, [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]; prompt key clashes on gamepad are in [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]]; tween details in [[Tween and CFrame Animation of Objects]] and [[TweenService - Engine Reference Card]]; pickup visuals in [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]].

Source labels: **Roblox docs** (create.roblox.com and the creator-docs reference YAML, checked 2026-10-29), **Rule of thumb** (experience, not a documented limit). Code is strict Luau, **compiled, not run in a live server**.

---

## 1. Pick the trigger

| Tool | Player action | Gives you | Best for | Watch out for |
|---|---|---|---|---|
| `ProximityPrompt` | Walk close, press a key or tap the prompt (or hold) | `Triggered(player)` | Doors, shops, NPC talk, levers, chests, anything "press to use" | Default keys `E` and `ButtonX` can clash with your binds |
| `ClickDetector` | Point at the part and click or tap | `MouseClick(player)` | Buttons on a panel, many small clickables close together, hover highlights | No on-screen hint; on gamepad it needs the centre dot and the bound button |
| `Touched` | Walk into it | `Touched(otherPart)` | Pickups, coins, kill bricks, jump pads, checkpoints | Fires per body part, needs a debounce, no player argument |
| Spatial query / point test | Stand inside an area | Parts or a yes/no | Zones, capture points, "is anyone on the plate" | You poll; see the zone note |

Rule of thumb: default to `ProximityPrompt` for anything the player chooses to use. It shows its own key hint on every device, so players do not have to guess what to press. Use `Touched` only when walking into it *is* the action.

## 2. ProximityPrompt

Roblox docs:

- Works when parented to a `BasePart`, an `Attachment`, or a `Model` with `PrimaryPart` set, in the workspace.
- `Triggered(playerWhoTriggered)` fires on press, or after `HoldDuration` seconds of holding (0 means instant). `TriggerEnded` fires on release. Server scripts can listen, and so can `ProximityPromptService.PromptTriggered` for all prompts in one place.
- `KeyboardKeyCode` defaults to `E`, `GamepadKeyCode` to `ButtonX`. `ActionText` defaults to "Interact"; `ObjectText` is an optional object name.
- `MaxActivationDistance` is how close the character must be for the prompt to appear. `RequiresLineOfSight` (default true) hides the prompt unless there is a clear path from the **camera** to the prompt's parent.
- `ClickablePrompt`: whether clicking or tapping the prompt UI triggers it. When false, click and tap are off except on mobile, so phones always work.
- `Exclusivity` (`Enum.ProximityPromptExclusivity`: `OnePerButton`, `OneGlobally`, `AlwaysShow`) decides which prompts can show together.
- `Style = Enum.ProximityPromptStyle.Custom` removes the default UI; you draw your own from `PromptShown` and `PromptHidden` in a `LocalScript`.

Rule of thumb: put the prompt on an `Attachment` at the handle or counter, not the centre of a big part, so distance and line of sight are measured from where players look. A large part with `RequiresLineOfSight` on can hide its own prompt when the camera is inside or behind it; turn it off for prompts on thin or enclosed parts.

## 3. ClickDetector

Roblox docs:

- Works when parented to a `BasePart`, `Model` or `Folder`. `MouseClick(playerWhoClicked)`, `RightMouseClick`, `MouseHoverEnter` and `MouseHoverLeave` fire on both server and client.
- Touch devices fire click events on tap. On gamepad, the default control scripts bind `ButtonR2` through `ContextActionService:BindActivate`; the centre dot hovers and the bound button clicks.
- `MaxActivationDistance` is in studs between the character and the detector.
- Priority: the deepest detector wins; a `ContextActionService` bind on the same input takes priority over the detector; `UserInputService.InputBegan` fires first.

So `ClickDetector` does work on phone and console, but console players must aim the centre dot and know to press R2, and nothing on screen tells them. If console players report "nothing happens", add a `ProximityPrompt` or a visible hint. A `LocalScript` placed inside a detector in the workspace will not run; listen from `StarterPlayerScripts` for client-only effects (hover highlight).

## 4. Touched and TouchEnded

Roblox docs: `Touched(otherPart)` fires on both parts in a contact, only from physical movement (not from setting `CFrame` so parts overlap), at least one part must be unanchored, and both parts need `CanTouch = true`. `TouchEnded` is the reverse.

What that means in practice:

- A walking character touches with several parts (feet, legs, root), so one step fires several events. Map `otherPart` to a player with `Players:GetPlayerFromCharacter(otherPart.Parent)` (accessories sit one level deeper, so they return nil: ignore those) and debounce per player.
- `TouchEnded` misses when a player teleports, dies or is destroyed while touching. Do not build "inside the area" state on it; use a point test or spatial query (see [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] and [[Raycasts Shapecasts and Spatial Queries]]).
- The client owns its character's physics, so an exploiter can move their character into any touch part or report touches against it. The server must still check that the touch makes sense (the player is alive and near the part, the pickup is not already taken, the cooldown has passed).
- A `Touched` listener in a `LocalScript` is for effects only (a sound, a glint). Rewards are granted by the server.

## 5. Server validation for all three

Prompt and click events arrive with a `Player` from the engine, but treat them as requests, not facts:

- **Distance.** Check the character's root position against the part (the property's distance plus a small margin for latency). It costs nothing and catches teleport exploits and stale prompts.
- **State.** Is the door locked, the chest already opened, the pickup already taken, the player alive, does the player own this plot?
- **Cooldown.** Per player and, for shared objects like a door, per object. A door that toggles every frame is a griefing tool.
- **Effects on the server, presentation anywhere.** The server changes the door's state and collision; tweens and sounds can run on the server or be replicated to clients.

See [[Server Authority and Validation]] and [[Rate Limiting and Abuse Prevention]] for the general rules.

## 6. Worked pattern: a door with ProximityPrompt and TweenService (server)

```lua
--!strict
-- Script inside the door model. Expects: Door (Model), Door.Hinge (BasePart, anchored),
-- Door.Panel (BasePart welded to Hinge), Door.Hinge.Attachment.ProximityPrompt
local TweenService = game:GetService("TweenService")

local door = script.Parent :: Model
local hinge = door:WaitForChild("Hinge") :: BasePart
local prompt = hinge:WaitForChild("Attachment"):WaitForChild("ProximityPrompt") :: ProximityPrompt

local OPEN_ANGLE = math.rad(95)
local COOLDOWN = 0.8
local MAX_DISTANCE = prompt.MaxActivationDistance + 4 -- margin for latency

local closedCFrame = hinge.CFrame
local openCFrame = closedCFrame * CFrame.Angles(0, OPEN_ANGLE, 0)
local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local isOpen = false
local busyUntil = 0

prompt.ActionText = "Open"
prompt.ObjectText = "Door"

prompt.Triggered:Connect(function(player: Player)
	local now = os.clock()
	if now < busyUntil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - hinge.Position).Magnitude > MAX_DISTANCE then
		return
	end
	if door:GetAttribute("Locked") == true then
		return
	end

	busyUntil = now + COOLDOWN
	isOpen = not isOpen
	prompt.ActionText = if isOpen then "Close" else "Open"
	TweenService:Create(hinge, tweenInfo, { CFrame = if isOpen then openCFrame else closedCFrame }):Play()
end)
```

Tweening an anchored hinge moves the welded panel with it; the panel must be unanchored and welded, or you tween the panel's `CFrame` directly. Tween `CFrame`, not `Position`, so rotation and position stay together.

## 7. Worked pattern: a debounced Touched pickup (server)

```lua
--!strict
-- Script inside a pickup part (anchored, CanCollide false, CanTouch true).
local Players = game:GetService("Players")

local pickup = script.Parent :: BasePart
local RESPAWN_TIME = 10
local VALUE = 5

local taken = false

local function award(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += amount
	end
end

pickup.Touched:Connect(function(otherPart: BasePart)
	if taken then
		return
	end
	local character = otherPart.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	taken = true -- set before anything that could yield or fire again
	pickup.Transparency = 1
	award(player, VALUE)

	task.delay(RESPAWN_TIME, function()
		pickup.Transparency = 0
		taken = false
	end)
end)
```

Do not toggle `CanTouch` to hide a pickup: Roblox docs say setting it to `false` after a touch event is connected disconnects the event and removes the `TouchTransmitter`, so turning it back on does not bring your handler back. The `taken` flag plus `Transparency` is enough. For a pickup that is personal (each player collects their own coin), keep a `taken` set per player instead of one flag.

## 8. Shops and buttons

- **Shop counter:** `ProximityPrompt` with `ActionText = "Shop"`. On `Triggered`, the server checks distance and fires a remote to that client to open the shop UI. Purchases then go through their own validated remote; never let "the prompt was triggered" stand in for "the purchase is allowed".
- **Button panel or keypad:** `ClickDetector` per button is fine for PC and phone. For console, either add a single prompt that opens a UI version of the panel, or make the buttons big enough to aim the centre dot at.
- **Hold to confirm:** use `HoldDuration` (0.5 to 1.5 s, rule of thumb) on destructive or costly actions such as selling or resetting.

## 9. Accessibility across PC, phone and console

- `ProximityPrompt` shows the right key glyph per device and can be tapped on mobile. It is the most accessible default.
- Change `GamepadKeyCode` and `KeyboardKeyCode` if your game uses `ButtonX` or `E`, and keep every prompt on the same keys.
- Keep `HoldDuration` short and only where it prevents mistakes; long holds are hard for players with motor impairments.
- Give `ClickDetector`s a hover highlight and a hint, and make the click target big. See [[Onboarding Accessibility and Cross-Device Prompts]] and [[Input Remapping and One-Handed Play]].
- Do not put two prompts on top of each other with `Exclusivity = AlwaysShow`; players cannot tell which key does what.

## Common mistakes

- Avoid: granting rewards from a `Touched` handler with no debounce. Symptom: one step awards a pickup three or four times, once per body part.
- Avoid: building "is in the area" on `TouchEnded`. Symptom: players stay "inside" a zone after dying or teleporting out.
- Avoid: trusting `Triggered` or `MouseClick` without a server distance and state check. Symptom: exploiters open doors and claim chests from across the map.
- Avoid: using only `ClickDetector`s for important actions. Symptom: console players report nothing happens because there is no on-screen hint for the centre dot and R2.
- Avoid: leaving prompts on the default `ButtonX` when an ability uses it. Symptom: pressing an ability near a shop opens the shop.
- Avoid: `RequiresLineOfSight` on a prompt inside a big or enclosed part. Symptom: the prompt never appears because the part itself blocks the camera's view of it.
- Avoid: a `LocalScript` inside a `ClickDetector` or touch part in the workspace. Symptom: the script never runs, so clicks or touches seem dead.
- Avoid: tweening `Position` on a hinged door. Symptom: the door slides instead of swinging, or snaps back to its old rotation.
- Avoid: one shared cooldown flag for a per-player pickup. Symptom: when one player collects it, every other player sees it gone.

## Checklist

- [ ] Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries.
- [ ] Every handler runs on the server and checks distance, state and a cooldown.
- [ ] `Touched` handlers map the part to a player, ignore non-characters, and debounce per player or per object.
- [ ] Prompt keys do not clash with ability binds on keyboard or gamepad.
- [ ] Prompts sit on an `Attachment` where the player looks; line of sight checked in play.
- [ ] Tested on PC, phone (emulator) and gamepad.
- [ ] Doors tween `CFrame`; pickups hide and respawn cleanly.

<!-- related:start -->
## Related
[[ProximityPrompt - Engine Reference Card]] · [[Lobby and Hub Design]] · [[Network Ownership]] · [[Exploits and Anti-Cheat]] · [[Cookbook - UI]] · [[Downed, Revive and Bleed-Out States]]
<!-- related:end -->
