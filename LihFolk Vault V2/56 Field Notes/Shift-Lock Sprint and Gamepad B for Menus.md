---
tags: [field-notes, input, shift-lock, sprint, gamepad, menus, contextactionservice, type/guide, area/ui, level/intermediate, api/ContextActionService]
---
# Shift-Lock Sprint and Gamepad B for Menus

<!-- tldr:start -->
> [!tldr] TL;DR
> - Camera flips into shift-lock when sprinting: Sprint and mouse lock both on Shift -> Move sprint, or disable the option and provide your own lock
> - Dash on B dead outside menus: B bound globally to close panels -> Bind only while a panel is open
> - Dash fires as a menu closes: Release reached the dash binding -> Sink every state of the close action
> - Sprint and mouse lock do not share a key, or the overlap is intended and documented.
> - If the platform shift-lock is disabled, an alternative exists and releases for menus.
> - B close-binding exists only while a panel is open, at high priority.
>
> Cost: TL;DR ~190 tok · whole note ~1.6k tok. Read more: ## 1. Shift-lock steals Shift · ## 2. Gamepad B: close menus only while a menu is open · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Two binding conflicts every action game meets. On PC, Shift is the obvious sprint key, and Roblox's shift-lock (mouse lock) option already uses Shift, so pressing it both sprints and toggles the camera lock. On gamepad, B is the obvious "back" button for menus and also an obvious dash or dodge button, so a global "B closes menus" binding eats the dash. The fixes are about *who owns a key, and when*. General input patterns are in [[Input - UserInputService and ContextActionService]]; controller layout in [[Gamepad and Console UX]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Shift-lock steals Shift

`StarterPlayer.EnableMouseLockOption` (Roblox docs) lets players toggle mouse lock, and the default player scripts bind the toggle to Shift. (In the `PlayerModule`'s mouse lock controller the bound keys have been read from a `BoundKeys` string value defaulting to the Shift keys; treat that as an implementation detail that can change.) If your sprint is also on Shift, a sprint press toggles shift-lock and the camera jumps into over-the-shoulder mode.

**Measured.** In the reference project, sprint on Shift with mouse lock enabled made the camera flip in and out of shift-lock on every sprint.

Options, in the order that worked best (rule of thumb):

1. **Move sprint off Shift**, or make sprint automatic (hold-to-run past a speed threshold, or double-tap W). Keeps the platform shift-lock that many PC players rely on.
2. **Disable the platform option** (`StarterPlayer.EnableMouseLockOption = false`) and offer your own lock toggle on a different key (or a settings switch) that sets `UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter` and offsets the camera. You then own the feature, including its edge cases (menus must release the lock).
3. **Leave both on Shift** only if your sprint is a toggle and you are happy that the camera mode changes with it. Few games are.

Whatever you choose, show the binding in the controls screen. Players who are used to shift-lock in other games will look for it.

## 2. Gamepad B: close menus only while a menu is open

The bad version binds B globally to "close the top panel". With no panel open, the binding still consumes B, and the dash bound to B stops working, or works only sometimes depending on binding order.

The fix: **bind B at high priority only while at least one panel is open, and unbind when the last one closes.** `ContextActionService:BindActionAtPriority` (Roblox docs) takes a priority; higher priorities receive input first, and returning `Sink` stops lower bindings from also receiving it.

```lua
-- Client UI manager: owns a stack of open panels.
local ContextActionService = game:GetService("ContextActionService")

local CLOSE_ACTION = "CloseTopPanel"
local openPanels: { GuiObject } = {}

local function onClose(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local top = openPanels[#openPanels]
	if top then
		UI.close(top) -- calls panelClosed below
	end
	return Enum.ContextActionResult.Sink
end

local function updateBinding()
	if #openPanels > 0 then
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, onClose, false,
			Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction(CLOSE_ACTION)
	end
end

function UI.panelOpened(panel: GuiObject)
	table.insert(openPanels, panel)
	updateBinding()
end

function UI.panelClosed(panel: GuiObject)
	local i = table.find(openPanels, panel)
	if i then
		table.remove(openPanels, i)
	end
	updateBinding()
end
```

Details that matter:

- **A stack, not a counter.** Counters drift when a panel is closed by code paths that forget to decrement. A stack of real panels can be audited and self-heals: remove entries whose panel is no longer visible before checking `#openPanels`.
- **Sink the release too.** If the press closes the menu and the release reaches the dash binding, some dash implementations fire on release. Sinking both states keeps the whole press inside the menu.
- **Rebinding is cheap** (`BindActionAtPriority` with the same name replaces the binding), so calling `updateBinding` on every open and close is fine.
- **HUD elements are not panels.** Only modal or semi-modal screens join the stack; a quest tracker should never make B close something.
- **Disable the dash while a panel is open anyway**, so a missed binding never results in dashing off a ledge behind a shop screen.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Camera flips into shift-lock when sprinting | Sprint and mouse lock both on Shift | Move sprint, or disable the option and provide your own lock |
| Dash on B dead outside menus | B bound globally to close panels | Bind only while a panel is open |
| Dash fires as a menu closes | Release reached the dash binding | Sink every state of the close action |
| B stops closing menus after a while | Open-panel counter drifted | Stack of panels, pruned when checked |

## Checklist

- [ ] Sprint and mouse lock do not share a key, or the overlap is intended and documented.
- [ ] If the platform shift-lock is disabled, an alternative exists and releases for menus.
- [ ] B close-binding exists only while a panel is open, at high priority.
- [ ] Close action sinks Begin and End.
- [ ] Panels tracked as a stack; HUD elements excluded.
- [ ] Combat actions disabled while a modal panel is open.

## Connected notes
<!-- auto-links:start -->
[[Input - UserInputService and ContextActionService]] · Gamepad and Console UX · Input Remapping and One-Handed Play · [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]] · [[Hold-to-Attack Input That Never Sticks]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Layering Camera Feedback on the Default Camera]] · [[A Stuck Player Watchdog That Logs the Cause]] · [[Server-Authoritative Freeze and Stun Timestamps]] · [[Held Weapons on Motor6D - Locking the Grip During Attacks]] · [[Shared Close Buttons and Headers Across Many Screens]] · [[Resetting One Player's Data Safely]]
<!-- related:end -->
