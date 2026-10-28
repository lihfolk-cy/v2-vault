---
tags: [field-notes, input, contextactionservice, combat, stamina, gamepad, luau]
---
# Hold-to-Attack Input That Never Sticks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Held attacks faster than clicking: Loop bypasses pace or stamina gates -> Loop calls the same `tryAttack`
> - Character keeps attacking after alt-tab: No End event arrived -> Reset on `WindowFocusReleased`
> - Attacking continues with button up: Release consumed elsewhere -> Poll `IsMouseButtonPressed` in the loop
> - Hold loop uses exactly the same gates as a click.
> - Held state cleared on End, Cancel, `WindowFocusReleased`, death and menu open.
> - Polled button state checked inside the loop.
>
> Read more (7 KB note): ## 1. Track held state from Begin and End, loop through the normal gates · ## 2. The stuck-held cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players expect to hold the attack button and keep swinging. Implementing that is a dozen lines; implementing it so the attack never gets stuck "on" after an alt-tab, never bypasses the stamina or pacing rules, and never spams "not enough stamina" twenty times a second takes a little more thought. This note gives a pattern that held up in a shipped melee game. Input APIs are in [[Input - UserInputService and ContextActionService]]; buffering in [[Input Responsiveness Buffering and Coyote Time]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Track held state from Begin and End, loop through the normal gates

The tempting version starts a separate fast loop that calls the swing animation directly. That loop then skips the cooldown, stamina and state checks that a single click goes through, and held attacks end up faster or cheaper than clicked ones. The rule: **holding is just clicking again as soon as you are allowed to.** The loop calls the same `tryAttack` function a click calls.

```lua
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local held = false
local heldBy: Enum.UserInputType? = nil
local loopRunning = false
local lastDenyNotice = 0
local DENY_NOTICE_GAP = 1.5 -- seconds between "no stamina" messages

local function stillPhysicallyHeld(): boolean
	if heldBy == Enum.UserInputType.MouseButton1 then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	elseif heldBy == Enum.UserInputType.Gamepad1 then
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
	end
	return true -- touch: rely on End/Cancel
end

local function attackLoop()
	if loopRunning then
		return
	end
	loopRunning = true
	while held do
		if not stillPhysicallyHeld() then
			held = false -- End never arrived; the button is up anyway
			break
		end
		local ok, reason = Combat.tryAttack() -- the same pace, stamina and state gates as a click
		if not ok and reason == "Stamina" and os.clock() - lastDenyNotice > DENY_NOTICE_GAP then
			lastDenyNotice = os.clock()
			Feedback.staminaDenied()
		end
		task.wait(Combat.timeUntilNextAttack()) -- returns a small positive number when gated
	end
	loopRunning = false
end

local function onAttack(_: string, state: Enum.UserInputState, input: InputObject)
	if state == Enum.UserInputState.Begin then
		held = true
		heldBy = input.UserInputType
		task.spawn(attackLoop)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		held = false
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("Attack", onAttack, false,
	Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

UserInputService.WindowFocusReleased:Connect(function()
	held = false
end)
```

Notes on the details:

- The first swing happens in the loop's first pass, so a single click and the start of a hold behave identically.
- `loopRunning` stops a second Begin (for example, mouse and trigger together) from starting two loops.
- `Cancel` arrives when the action is unbound or overridden by a higher-priority binding (Roblox docs); treat it like End.
- `Combat.timeUntilNextAttack` should never return 0 while denied, or the loop spins every frame. Clamp it to at least one frame (`math.max(t, 1/60)`).
- `Pass` lets other bindings and the camera see the input. Return `Sink` only if a held attack must block something else.

## 2. The stuck-held cases

**Measured.** The reference project's first version stuck in "always attacking" in two ways:

1. **Alt-tab or a focus change while holding.** The window loses focus, the release happens outside the game, and no End event arrives. `UserInputService.WindowFocusReleased` fires when the window loses focus (Roblox docs); clear the held state there.
2. **Release swallowed by something else.** A menu opening under the cursor, a CoreGui overlay, or a rebinding at higher priority can take the release. The loop's `stillPhysicallyHeld` check catches this: if the mouse button is up, the hold is over regardless of events. `IsMouseButtonPressed` and `IsGamepadButtonDown` are polled state, not events, so they are reliable here.

Touch has no polled equivalent per button, so touch holds rely on End and Cancel plus a safety: stop the loop when the character dies, a menu opens or input is locked by a status effect.

## 3. Stamina deny spam

Without a gate, a player holding attack at zero stamina gets a deny message, sound and shake every time the loop tries, which can be every frame. Rules that worked (rule of thumb):

- **Notify once per denial episode**, then at most every 1.5 s while still held.
- **Do not play the deny sound on every retry**; play it with the notice.
- **Back off the retry rate** while denied (for example 0.2 s between tries) instead of trying every frame.
- When stamina recovers enough, the next try simply succeeds; no extra message is needed.

## 4. Server side

The server must not trust a held state at all. It receives individual attack requests and applies the same rate limit to each, whether the client clicked or held. If held attacks ever arrive faster than clicked ones, the client loop is wrong, and the server should already be rejecting the extras ([[Rate Limiting]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Held attacks faster than clicking | Loop bypasses pace or stamina gates | Loop calls the same `tryAttack` |
| Character keeps attacking after alt-tab | No End event arrived | Reset on `WindowFocusReleased` |
| Attacking continues with button up | Release consumed elsewhere | Poll `IsMouseButtonPressed` in the loop |
| "Not enough stamina" floods the screen | Deny feedback on every retry | One notice per episode, rate-limited |
| Two swings per input occasionally | Two loops started | `loopRunning` guard |

## Checklist

- [ ] Hold loop uses exactly the same gates as a click.
- [ ] Held state cleared on End, Cancel, `WindowFocusReleased`, death and menu open.
- [ ] Polled button state checked inside the loop.
- [ ] Deny feedback rate-limited; retries backed off while denied.
- [ ] Server rate-limits attacks independently of input method.

## Connected notes
<!-- auto-links:start -->
[[Input - UserInputService and ContextActionService]] · [[Input Responsiveness Buffering and Coyote Time]] · [[Input Buffering]] · [[Combat Systems Architecture]] · [[Gamepad and Console UX]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
