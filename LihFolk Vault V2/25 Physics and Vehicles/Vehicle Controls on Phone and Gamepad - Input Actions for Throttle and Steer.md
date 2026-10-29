---
tags: [physics, vehicles, input, mobile, gamepad, touch, input-action-system, type/guide, area/physics, area/ui, level/intermediate, api/InputAction, api/InputBinding, api/InputContext, api/VehicleSeat]
---
# Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Throttle and brake on one stick axis on gamepad -> Separate `Direction1D` actions on R2 and L2
> - Avoid: Default thumbstick and jump visible while driving -> Hide touch controls on sit, restore on exit
> - Avoid: Reading actions only in `StateChanged` -> Poll `GetState()` every frame
> - Decided: default `VehicleSeat` floats, or a Driving `InputContext`.
> - Throttle, brake, steer, handbrake, exit bound for keyboard, gamepad and touch.
> - Context enabled on sit and disabled on exit and death.
>
> Cost: TL;DR ~170 tok · whole note ~2.8k tok. Read more: ## 1. Option A: the default VehicleSeat input · ## 2. Option B: vehicle actions with the Input Action System · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox players are on phones, and a car that is only fun on WASD loses most of its audience in the first minute. This note covers vehicle input across touch, gamepad and keyboard: when the default `VehicleSeat` input is enough, how to build throttle, brake and steer as Input Action System actions with analog triggers and touch buttons, touch layouts that work with thumbs, and how input should reach the simulation (client-owned car versus Server Authority). General input APIs are in [[Input - UserInputService and ContextActionService]]; this note is the vehicle-specific angle.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

## 1. Option A: the default VehicleSeat input

When a character sits in a `VehicleSeat`, the default player scripts write `VehicleSeat.ThrottleFloat` and `SteerFloat` (-1 to 1) from the platform's movement input: WASD or arrows on keyboard, the left thumbstick on gamepad, and the on-screen thumbstick on touch (Roblox docs, https://create.roblox.com/docs/reference/engine/classes/VehicleSeat). Your drive script reads those two floats.

Good enough when: casual driving, RP cars, prototypes. It works on every device with no input code.

Not good enough when:

- You want **analog triggers** for throttle and brake on gamepad (the default maps both axes to one stick).
- You need more verbs: handbrake, boost, horn, gear shift, camera toggle, exit.
- The touch thumbstick makes it hard to steer and accelerate independently, which matters in any racing game.
- You fork or replace the player scripts. The Input Action System player scripts went to full release on June 11, 2026 and become the default in a later phase; code that reaches into `PlayerModule` internals breaks (Roblox docs, DevForum: https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416; see [[Server Authority and Input Migration 2026]]).

## 2. Option B: vehicle actions with the Input Action System

The IAS gives one `InputAction` per verb, each with `InputBinding`s for every device, grouped in an `InputContext` you enable while driving (Roblox docs guide: https://create.roblox.com/docs/input/input-action-system). Action `Type` values include `Bool`, `Direction1D` and `Direction2D` (Roblox API).

Suggested actions:

| Action | Type | Keyboard | Gamepad | Touch |
|---|---|---|---|---|
| Throttle | Direction1D | W / Up | Right trigger (`ButtonR2`) | Gas button |
| Brake | Direction1D | S / Down | Left trigger (`ButtonL2`) | Brake button |
| Steer | Direction2D (use X) | A/D as composite `Left`/`Right` | Left thumbstick (`Thumbstick1`) | Left/right buttons or tilt |
| Handbrake | Bool | Space | `ButtonX` or `ButtonB` | Drift button |
| Boost | Bool | Shift | `ButtonA` or `ButtonR1` | Boost button |
| Exit | Bool | F | `ButtonY` | Exit button (with hold) |

Separate throttle and brake are better than one signed axis: triggers are naturally 0 to 1, and players brake and accelerate at the same time to drift or launch.

```lua
--!strict
-- LocalScript (StarterPlayerScripts). Builds the Driving context on the client.
-- Under Server Authority, build it on the server and parent it under the Player instead.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("DriveHud") :: ScreenGui

local context = Instance.new("InputContext")
context.Name = "Driving"
context.Enabled = false
context.Priority = 100 -- above default gameplay contexts

local function action(name: string, kind: Enum.InputActionType): InputAction
	local a = Instance.new("InputAction")
	a.Name = name
	a.Type = kind
	a.Parent = context
	return a
end

local function bindKey(a: InputAction, key: Enum.KeyCode)
	local b = Instance.new("InputBinding")
	b.KeyCode = key
	b.Parent = a
end

local function bindButton(a: InputAction, buttonName: string)
	local b = Instance.new("InputBinding")
	b.UIButton = gui:WaitForChild(buttonName) :: GuiButton
	b.Parent = a
end

local throttle = action("Throttle", Enum.InputActionType.Direction1D)
bindKey(throttle, Enum.KeyCode.W)
bindKey(throttle, Enum.KeyCode.ButtonR2)
bindButton(throttle, "Gas")

local brake = action("Brake", Enum.InputActionType.Direction1D)
bindKey(brake, Enum.KeyCode.S)
bindKey(brake, Enum.KeyCode.ButtonL2)
bindButton(brake, "Brake")

local steer = action("Steer", Enum.InputActionType.Direction2D)
local stick = Instance.new("InputBinding")
stick.KeyCode = Enum.KeyCode.Thumbstick1
stick.Parent = steer
local keys = Instance.new("InputBinding")
keys.Left = Enum.KeyCode.A
keys.Right = Enum.KeyCode.D
keys.Parent = steer

local handbrake = action("Handbrake", Enum.InputActionType.Bool)
bindKey(handbrake, Enum.KeyCode.Space)
bindKey(handbrake, Enum.KeyCode.ButtonX)
bindButton(handbrake, "Drift")

context.Parent = player

-- Poll every frame: StateChanged only fires on change (Roblox docs).
local function read(): (number, number, number, boolean)
	local t = throttle:GetState() :: number
	local b = brake:GetState() :: number
	local s = (steer:GetState() :: Vector2).X
	local h = handbrake:GetState() :: boolean
	return t, b, s, h
end

return { context = context, read = read }
```

**Unverified details to check in Studio before shipping:** the exact value a plain key binding produces on a `Direction1D` action (expected: the binding's `Scale`, default 1), and how two bindings active at once combine. Touch buttons bound through `UIButton` are digital (0 or 1). Steering on touch therefore needs rate limiting in the car, the same as keyboard ([[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]]).

Enable the context on sit and disable it on exit; disabling the context is the supported way to stop the actions, not reaching into the control module.

## 3. Touch layout that works

Rule of thumb from mobile racing conventions:

- **Steer on the left thumb, pedals on the right.** Gas largest and lowest-right, brake above or left of it, so the thumb rocks between them. Drift and boost within the same thumb's arc.
- **Hide the default thumbstick and jump button while driving** (`GuiService.TouchControlsEnabled = false`, restore on exit; Roblox docs). Otherwise players hit jump and nothing happens, or steer with the stick and the gas at once with one thumb.
- **Buttons at least about 9 to 10 mm** physical size, more for gas. Respect safe areas on notched phones ([[Safe Areas and Insets]], [[Responsive UI for Phone Tablet Console and PC]]).
- **Offer an auto-accelerate option.** Many phone players prefer steering-only driving; it is also an accessibility win ([[Input Remapping and One-Handed Play]]).
- **Tilt steering as an option, never the default.** Read gravity from `UserInputService:GetDeviceGravity()` when `UserInputService.AccelerometerEnabled` is true; map roll to steer with a deadzone and a calibrate button.
- **Exit needs a hold or a confirm.** An accidental exit at speed is the most-hated mobile vehicle bug.

## 4. Gamepad details

- **Deadzones.** Thumbsticks rest a few percent off-centre. Apply a radial deadzone (around 0.1 to 0.15) and rescale the remainder so steering starts smoothly from 0 ([[Gamepad and Console UX]]). `InputBinding` has `Deadzone` and `ResponseCurve` properties (Roblox API); test their behaviour before relying on them.
- **Steering curve.** A mild expo curve (`sign(x) * |x|^1.5`) gives precision near centre and full lock at the edge.
- **Rumble.** `HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, v)` scaled by engine RPM or surface roughness, and short pulses on gear shifts and impacts. Always turn motors off on exit ([[Haptics]]).
- **Show the right glyphs.** `InputAction.PreferredBinding` tells you which binding matches the active device so hints show "RT" or a touch icon correctly.

## 5. Where input goes

- **Client-owned car (the common case):** the driver's client reads the actions and applies motors or forces locally in `RunService.PreSimulation`. Nothing needs to go to the server every frame; other clients see the motion through physics replication. Send discrete verbs the server must decide (boost with a cooldown, horn, exit) as rate-limited remotes ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]).
- **Server Authority (`Workspace.AuthorityMode = Server`):** contexts must be descendants of the `Player`, and simulation code reads action state inside `RunService:BindToSimulation` on both sides (Roblox docs, [[Server Authority and Input Migration 2026]]). Build the context on the server per player, as in that note.
- **Feeding a community chassis:** if a kit reads `VehicleSeat.ThrottleFloat`/`SteerFloat`, you can leave the default input in place. If it reads the keyboard directly, patch it to read your action module.

## Common mistakes

| Mistake | Fix |
|---|---|
| Throttle and brake on one stick axis on gamepad | Separate `Direction1D` actions on R2 and L2 |
| Default thumbstick and jump visible while driving | Hide touch controls on sit, restore on exit |
| Reading actions only in `StateChanged` | Poll `GetState()` every frame |
| Binding keyboard only | Every action gets keyboard, gamepad and touch bindings |
| One-tap exit button | Hold or confirm |
| Disabling driving via `PlayerModule:GetControls()` | Enable and disable the `InputContext` |
| Rumble left on after exit | Reset motors on exit and on death |

## Checklist

- [ ] Decided: default `VehicleSeat` floats, or a Driving `InputContext`.
- [ ] Throttle, brake, steer, handbrake, exit bound for keyboard, gamepad and touch.
- [ ] Context enabled on sit and disabled on exit and death.
- [ ] Touch: thumb-friendly layout, safe areas, default controls hidden, auto-accelerate option.
- [ ] Gamepad: deadzone, steering curve, rumble with reset, correct glyphs.
- [ ] Input applied on the owning client, or in bound simulation under Server Authority.

## See also

[[Input - UserInputService and ContextActionService]] · [[Server Authority and Input Migration 2026]] · [[Gamepad and Console UX]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Input Remapping and One-Handed Play]] · [[Haptics]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Genre Playbook - Racing and Driving]]

## Connected notes
<!-- auto-links:start -->
[[AI Pitfalls - UI and Input]] · Safe Areas and Insets · [[Physics and Vehicles Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Aircraft and Flight Models]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Boats Buoyancy and Water]]
<!-- related:end -->
