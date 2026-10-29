---
tags: [core-concept, input, game-feel, combat, controls, type/reference, area/gameplay, level/beginner]
---
# Input Buffering

<!-- tldr:start -->
> [!tldr] TL;DR
> - Players press early, especially in combos and platforming.
> - The buffer window must be short enough never to surprise.
> - Buffer one action, latest wins (usually).
> - Some actions should not buffer. Interacting with the wrong target or opening a menu after a fight are worse than a missed press.
>
> Cost: TL;DR ~120 tok · whole note ~930 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Input buffering** remembers a button press for a short window and performs it as soon as the action becomes possible. If a player presses attack 80 ms before the current swing ends, a buffered system fires the next swing on the first allowed frame instead of ignoring the press.

## Why it matters on Roblox

Players press early, especially in combos and platforming. Without a buffer the game "eats inputs", which players describe as unresponsive controls, not as missing a window. Roblox adds touch controls (presses land late and imprecisely), gamepads and varying frame rates, all of which make tight windows harder to hit.

## The nuance most people miss

1. **The buffer window must be short enough never to surprise.** Rule of thumb: 100 to 200 ms for attacks and jumps. An action that fires half a second after the player stopped pressing feels like lag, not forgiveness.
2. **Buffer one action, latest wins (usually).** Store the most recent buffered press, not a queue of five. Players who mash should not get a five-attack backlog.
3. **Some actions should not buffer.** Interacting with the wrong target or opening a menu after a fight are worse than a missed press.
4. **Clear the buffer on state changes.** Getting stunned, dying or opening UI should drop the buffered action.
5. **The server needs matching grace.** If the client buffers an attack and fires at the exact moment the client-side cooldown ends, the request can reach the server a few milliseconds "early" by the server's clock. Allow a small tolerance (rule of thumb: 50 to 100 ms) on server cooldown checks, or honest players get rejected.
6. **Coyote time is the mirror image.** Buffering forgives pressing too early; coyote time forgives pressing slightly too late (a jump just after leaving a ledge).

## Tiny example

```lua
local BUFFER = 0.15
local bufferedAt: number? = nil

local function onAttackInput()
	if canAttack() then doAttack() else bufferedAt = os.clock() end
end

RunService.Heartbeat:Connect(function()
	if bufferedAt and canAttack() then
		if os.clock() - bufferedAt <= BUFFER then doAttack() end
		bufferedAt = nil
	end
end)
```

## Where this shows up

- [[Input Responsiveness Buffering and Coyote Time]]: the deep dive.
- [[Combat Combo Systems]]: buffering between combo steps.
- [[Custom Character Controllers]]: jump buffering in controllers.
- [[Input - UserInputService and ContextActionService]]: where presses arrive.
- [[Gamepad and Console UX]]: controller timing.
- [[2D Collision Physics and Platformer Movement]]: buffering in a 2D platformer.
- [[Obby and Platforming Level Design]]: forgiving jumps in obbies.
- [[Rate Limiting and Abuse Prevention]]: server tolerance versus abuse limits.
- [[Input Remapping and One-Handed Play]]: wider windows as an accessibility option.
- [[Melee Combat System End to End]]: a buffer inside a full combat build.
- [[Genre Playbook - Obbies and Platformers]]: genre expectations for forgiveness.

Related concepts: [[Anticipation]], [[Hit-Stop]], [[Rate Limiting]], [[Server Authority]].

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · Combat Animation Craft · 2D Game Development Start Here · [[Core Concepts Start Here]] · Snippets - Playing Animations · Stance and Charge Moves
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Deterministic Simulation]] · [[Frame Budget]] · [[Tween vs Spring]] · [[Safe Area]] · [[Easing]] · [[Session Lock]] · [[Core Loop]] · [[Feature Flags]]
<!-- related:end -->
