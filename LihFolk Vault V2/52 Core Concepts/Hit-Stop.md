---
tags: [core-concept, game-feel, combat, animation, type/reference, area/animation, level/beginner, api/AdjustSpeed, area/gameplay]
---
# Hit-Stop

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox combat games are crowded and fast, and most hits happen at a distance where detail is lost.
> - Freeze local time, never the world. On Roblox you cannot pause the server for one player.
> - Clock-timed systems drift during a stop.
> - Frame rate quantises the stop. At 30 fps a 50 ms stop is one or two frames depending on timing, so light stops flicker between...
>
> Cost: TL;DR ~130 tok · whole note ~950 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Hit-stop** (also hit-pause or freeze frames) briefly freezes or slows the attacker and target at the moment of impact, typically for 30 to 120 ms (rule of thumb). The pause makes the hit read as contact with something solid instead of a weapon passing through air.

## Why it matters on Roblox

Roblox combat games are crowded and fast, and most hits happen at a distance where detail is lost. Hit-stop is one of the strongest signals that a hit landed, it costs almost nothing to render, and it works on every device. It is also easy to get wrong in ways that make the game feel laggy.

## The nuance most people miss

1. **Freeze local time, never the world.** On Roblox you cannot pause the server for one player. Hit-stop is a client effect: pause the attacker's animation tracks (`AdjustSpeed(0)`) and effects for a few frames, then resume. Other players and the server keep running.
2. **Clock-timed systems drift during a stop.** If hitboxes, VFX or sounds are scheduled by wall clock while the animation is paused, they fall out of sync. Either pause those clocks too or catch the animation up after the stop (the "catch-up" approach in the deep dive).
3. **Frame rate quantises the stop.** At 30 fps a 50 ms stop is one or two frames depending on timing, so light stops flicker between visible and invisible on phones. Anything that must be felt needs about 66 ms or more.
4. **Stops add up in flurries.** Five quick hits with 50 ms each spend 250 ms frozen and feel sticky. Cap total hit-stop per short window.
5. **Scale by strength, with the other layers.** One strength value should drive stop length, shake, sound and particles, so a heavy hit is heavier on every channel at once.
6. **Respect the defender's control.** Freezing the victim's movement locally fights their own input; prefer freezing their animation pose and leave their controls alone.

## Tiny example

```lua
local function hitStop(tracks: { AnimationTrack }, seconds: number)
	local speeds = {}
	for i, t in tracks do speeds[i] = t.Speed; t:AdjustSpeed(0) end
	task.delay(seconds, function()
		for i, t in tracks do
			if t.IsPlaying then t:AdjustSpeed(speeds[i]) end
		end
	end)
end
```

## Where this shows up

- [[Hit-Stop and Screen Shake Tuning by Numbers]]: the numbers by strength tier.
- [[Hit Reactions Stagger and Hit-Stop]]: the catch-up approach.
- [[Combat Animation Craft]]: [[impact frames]] in animation.
- [[Feedback Timing - Sound Visual and Haptic Sync]]: syncing sound with the stop.
- [[Camera Shake and Camera FX]]: the layer usually paired with it.
- [[Combat Systems Architecture]]: where the client effect is triggered.
- [[Weapon Swing Design]]: swing timing around contact.
- [[Combat Sound Design and Feedback]]: impact sounds during the stop.
- [[Genre Playbook - Battlegrounds and Arena Fighters]]: genres that rely on it.
- [[Motion Sensitivity and Camera Comfort]]: comfort options for strong feedback.
- [[Boss Fight Design Patterns]]: longer stops on big moments.
- [[Melee Combat System End to End]]: hit-stop inside a full build.

Related concepts: [[Anticipation]], [[Easing]], [[Input Buffering]], [[Frame Budget]].

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · Game Feel and Juice · VFX Timing with Animation · Timing Spacing and Frame Charts · Snippets - Camera Shake and FX · Hitboxes and Hit Detection · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Tween vs Spring]] · [[Input Buffering]] · [[Server Authority]] · [[Core Loop]] · [[Deterministic Simulation]] · [[Skinning Weights]] · [[Streaming Radius]] · [[Object Pooling]]
<!-- related:end -->
