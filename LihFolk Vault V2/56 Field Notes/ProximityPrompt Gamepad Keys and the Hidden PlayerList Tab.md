---
tags: [field-notes, input, gamepad, proximityprompt, coregui, playerlist, console, type/guide, area/ui, level/intermediate, api/ProximityPrompt, area/ai]
---
# ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab

<!-- tldr:start -->
> [!tldr] TL;DR
> - Ability press opens a nearby shop on console: Prompt default `ButtonX` shared with an ability -> Remap every prompt's `GamepadKeyCode`
> - Some prompts still use X: Prompt created or changed after the initial pass -> `DescendantAdded` plus `PromptShown`
> - Accidental shop opens during fights on PC: `E` shared with an ability, instant trigger -> Different key or a short `HoldDuration`
> - One prompt gamepad key, used by no gameplay bind.
> - Remap applied on start, on `DescendantAdded` and on `PromptShown`.
> - Deliberate exceptions marked with an attribute.
>
> Cost: TL;DR ~180 tok · whole note ~1.6k tok. Read more: ## 1. Prompt keys collide with ability binds · ## 2. Hiding the player list kills Tab · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Two small defaults that bite games with a full controller layout. First, every `ProximityPrompt` uses `ButtonX` on gamepad by default, which is also a natural ability or attack button, so walking past a chest while pressing your ability does both. Second, hiding the CoreGui player list also removes the Tab key's toggle, and PC players lose a feature they use constantly. Both are one-time fixes; both are easy to forget. Controller design in general is in [[Gamepad and Console UX]]; remapping for accessibility in [[Input Remapping and One-Handed Play]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Prompt keys collide with ability binds

`ProximityPrompt.GamepadKeyCode` defaults to `Enum.KeyCode.ButtonX` and `KeyboardKeyCode` to `E` (Roblox docs). When a prompt is visible and in range, pressing its key triggers it. It does not stop your own `ContextActionService` binding for the same button from also firing.

**Measured.** In the reference project, the default `ButtonX` on prompts clashed with an ability bound to the same button, so pressing the ability near a prompt did both.

The fix is to choose a prompt button that no gameplay bind uses (a d-pad direction or `ButtonY`, depending on your layout) and apply it to *every* prompt, including ones created later by other systems, streamed in, or replicated from the server.

```lua
-- LocalScript (StarterPlayerScripts): one gamepad key for every prompt.
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local PROMPT_GAMEPAD_KEY = Enum.KeyCode.ButtonY -- pick one no ability uses

local function remap(prompt: ProximityPrompt)
	if prompt:GetAttribute("KeepGamepadKey") then
		return -- deliberate exceptions opt out
	end
	if prompt.GamepadKeyCode ~= PROMPT_GAMEPAD_KEY then
		prompt.GamepadKeyCode = PROMPT_GAMEPAD_KEY
	end
end

for _, d in Workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		remap(d)
	end
end

Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		remap(d)
	end
end)

-- Safety net: fires just before a prompt is shown, so anything missed above is fixed in time.
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	remap(prompt)
end)
```

Why both hooks: `DescendantAdded` catches prompts as they arrive (including through instance streaming), and `PromptShown` (Roblox docs, on `ProximityPromptService`, passes the prompt and input type) catches anything whose key was set after it arrived, such as a server script that assigns `GamepadKeyCode` explicitly. A local change to the property only affects this client, which is what you want.

If you control all prompt creation, also set the key in the shared prompt factory or in the server-side builder so the data is right at the source; the client script is then just a guard.

Also check the reverse collision: the prompt's **keyboard** key `E` against your PC ability binds, and **hold duration**. A `HoldDuration` of 0.3 to 0.5 s on shop prompts (rule of thumb) makes accidental triggering during combat rare even if keys overlap.

## 2. Hiding the player list kills Tab

Many games hide the CoreGui leaderboard by default to free screen space:

```lua
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
```

That also removes the built-in Tab toggle, because the toggle belongs to the player list itself. **Measured:** the reference project lost its Tab toggle exactly this way when the list was hidden by default.

If you hide it, bind Tab yourself to bring it back on demand:

```lua
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")

local function togglePlayerList(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local on = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not on)
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("TogglePlayerList", togglePlayerList, false, Enum.KeyCode.Tab)
```

If you replaced the list with your own leaderboard, bind Tab to that instead. Either way, check that Tab is not also used by a menu (tab switching) in a way that conflicts, and that a `TextBox` with focus does not receive the toggle (bindings do not fire while typing in a focused `TextBox`, rule of thumb; verify on your build).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Ability press opens a nearby shop on console | Prompt default `ButtonX` shared with an ability | Remap every prompt's `GamepadKeyCode` |
| Some prompts still use X | Prompt created or changed after the initial pass | `DescendantAdded` plus `PromptShown` |
| Accidental shop opens during fights on PC | `E` shared with an ability, instant trigger | Different key or a short `HoldDuration` |
| "Tab doesn't work" | PlayerList CoreGui disabled | Bind Tab to toggle it or your own list |

## Checklist

- [ ] One prompt gamepad key, used by no gameplay bind.
- [ ] Remap applied on start, on `DescendantAdded` and on `PromptShown`.
- [ ] Deliberate exceptions marked with an attribute.
- [ ] Prompt keyboard key and hold duration checked against PC binds.
- [ ] If the player list is hidden, Tab is bound to show a list.

## Connected notes
<!-- auto-links:start -->
[[Gamepad and Console UX]] · Input Remapping and One-Handed Play · Input - UserInputService and ContextActionService · [[Shift-Lock Sprint and Gamepad B for Menus]] · Responsive UI for Phone Tablet Console and PC · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[ProximityPrompt - Engine Reference Card]] · [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[Controller Support QoL]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Hold-to-Attack Input That Never Sticks]] · [[Input - UserInputService and ContextActionService]]
<!-- related:end -->
