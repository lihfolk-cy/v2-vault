---
tags: [systems, ui, gui, tweenservice, game-feel, accessibility, code, type/guide, area/animation, level/intermediate, api/UIScale, area/ui]
---
# UI and GUI Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Pop grows from a corner: Default AnchorPoint -> Scale about the centre
> - List jiggles during a pop: Tweening `Size` in a layout -> `UIScale`
> - Phone gets hot in menus: Per-frame loops while hidden -> Loops only while visible
>
> Cost: TL;DR ~100 tok · whole note ~4.6k tok. Read more: ## Pattern 1: the pop · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

UI animation is the part of game animation players touch most directly: every button press, reward, toast and menu. Done well it makes a game feel expensive; done badly it makes menus slow and phones hot. This note covers the Roblox tools (TweenService, `UIScale`, `UIGradient`, `CanvasGroup`, flipbooks, hand-written springs), patterns with concrete numbers from one production game's UI passes (the reference project), performance rules and reduced motion. World-object tweens (doors, lids) are in [[Tween and CFrame Animation of Objects]].

## The toolbox

| Tool | Animate what | Notes |
|---|---|---|
| `TweenService:Create(obj, TweenInfo, goals)` | Any numeric, `UDim2`, `Color3`, `Vector2`, `CFrame` property | Runs in the engine; cheap; supports repeat and reverse |
| `UIScale.Scale` | Whole subtree size | Pops and presses: scales children, text and strokes together without re-layout of siblings |
| `UIGradient.Offset` / `Rotation` / `Color` / `Transparency` | Shine sweeps, scrolling colour, fades across an element | `Offset` from about -1 to 1 sweeps a band across |
| `CanvasGroup.GroupTransparency` / `GroupColor3` | Fade or tint a whole group as one image | Renders the group to a texture; fixes "stacked transparency" artefacts |
| `ImageLabel.ImageRectOffset` / `ImageRectSize` | Sprite sheet flipbooks | Step the offset by frame |
| `UIStroke.Thickness` / `Transparency` | Outline pulses | |
| `Rotation` on GuiObjects | Rocks, spins, sunbursts | Rotates about the AnchorPoint |

`TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)`: `repeatCount = -1` loops forever; `reverses = true` ping-pongs. TweenService easing directions are the intuitive ones (`In` = slow start). The reversed legacy `Cubic` behaviour of keyframe easing does not apply to TweenService (see [[Keyframes, Easing and Interpolation]]).

## Pattern 1: the pop

The single most used UI animation. Reference values (an invite popup): scale **0.6 to 1.05 to 1**, with `Back` easing, about the element's **centre**; a **0.25 s** pop-out.

```lua
local TweenService = game:GetService("TweenService")

-- Pop a GuiObject in about its centre using a UIScale (created if missing).
local function pop(gui: GuiObject, duration: number?)
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	-- Re-anchor to the middle WITHOUT moving it, so the zoom grows from the centre.
	local abs, pos = gui.AbsoluteSize, gui.Position
	local old = gui.AnchorPoint
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Position = pos + UDim2.fromOffset((0.5 - old.X) * abs.X, (0.5 - old.Y) * abs.Y)
	scale.Scale = 0.6
	local d = duration or 0.35
	-- Back Out overshoots by about 10% of the change (0.6 -> 1 peaks near 1.04) and settles at 1.
	-- For a bigger overshoot like the reference 1.05, chain two tweens: 0.6 -> 1.05 (Quad Out), 1.05 -> 1 (Sine InOut).
	TweenService:Create(scale, TweenInfo.new(d, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function popOut(gui: GuiObject, onDone: (() -> ())?)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if not scale then gui.Visible = false return end
	local tw = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	tw.Completed:Once(function() gui.Visible = false; scale.Scale = 1; if onDone then onDone() end end)
	tw:Play()
end
```

Why `UIScale` and not `Size`: tweening `Size` of a child of a `UIListLayout` or `UIGridLayout` re-lays out every sibling every frame (the whole list jiggles), and text with `TextScaled` re-fits every frame. `UIScale` scales the rendered subtree only.

**Zoom from the middle.** A UI pass in the reference project made every hover, press and pop zoom scale about the object's middle, because the default `AnchorPoint` (0, 0) makes a scale grow from the top-left corner, which reads as the element sliding. Objects placed by layouts cannot simply change anchor; the fix there was a centred inner "content" frame that scales inside the layout slot.

## Pattern 2: the shine sweep

A diagonal highlight band crossing a card or button. A `UIGradient` with a narrow bright band in its `Transparency` sequence, rotated about 20 to 30 degrees, with `Offset` tweened from (-1, 0) to (1, 0).

Reference cadences: a toast's shine every **1.6 s** while it holds; a weapon card's shine every **3.4 s**; an idle "next goal" card's shine every **7 s**. The pattern: the more important and the shorter-lived the element, the more often it shines. A constant shine on a permanent HUD element becomes noise within a minute.

```lua
local function shineLoop(gradient: UIGradient, every: number, sweep: number)
	task.spawn(function()
		while gradient.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			TweenService:Create(gradient, TweenInfo.new(sweep, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Offset = Vector2.new(1, 0) }):Play()
			task.wait(every)
		end
	end)
end
```

## Pattern 3: idle life with looping tweens

Persistent elements that should feel alive (an "auto" toggle while on, a reward chest icon) need idle motion. The reference rule: **looping tweens only, no per-frame Lua**. Example, an auto-roll toggle while on:

| Element | Motion |
|---|---|
| Front die | Rocks +/-12 degrees around its -14 degree rest, bobs 3 px up |
| Back die | Rocks +/-9 degrees the other way, on a slower period |
| Status dot | Size pulses 22 to 27 px, 0.45 s each way |
| Glow ring | Swells and fades over 0.9 s |
| Turning off | Cancel all loops, 0.2 s `Quad` ease to the rest pose **captured at start** |
| Reduced motion | Still dice, static dot |

Two details worth stealing:
- **Different periods for related elements** (the two dice) so the composite never visibly repeats.
- **Capture the rest pose before animating** and ease back to it, rather than to hard-coded values. Layout code may have moved the element since it was authored.

```lua
local function rock(gui: GuiObject, amplitude: number, period: number): Tween
	-- ping-pong forever around the current rotation
	local rest = gui.Rotation
	gui.Rotation = rest - amplitude
	local tw = TweenService:Create(gui, TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = rest + amplitude })
	tw:Play()
	return tw -- keep it: Cancel() it, then tween back to `rest`
end
```

## Pattern 4: text and toasts

A reference toast ("potion started"): while it holds, the letters ride a sine wave, the badge wiggles and breathes, the time chip rocks, and a shine sweeps every 1.6 s; on exit the letters **pop out right to left**, the subtitle fades, the badge shrinks, then the panel folds. Per-letter animation needs one `TextLabel` per character (or `RichText` tricks for colour only). It is expensive in instances, so reserve it for short-lived, high-value moments (rewards, level up, a "Welcome back" title with per-letter bounce), never for persistent HUD.

Rainbow title: a `UIGradient` whose colour keypoints are hue-scrolled every frame plus a slow rotation sway, a 2.5 px navy `UIStroke`, a float of 3 px and a 2% scale pulse. Hue scrolling needs per-frame updates (a `ColorSequence` cannot be tweened), so run it only while visible.

## Pattern 5: hero stages and cards

The reference inventory card: a rarity gradient behind the item, a turning rim gradient, two counter-turning sunbursts and a pulsing radial aura inside a rounded `CanvasGroup`, 4 to 8 drifting twinkles, a shine band every 3.4 s, the item art floating, swaying and "breathing", and an equip flash. Hovering a card tilts, lifts, shines and bobs the art. All of it ran in **one Heartbeat (or RenderStepped) connection that exists only while the screen is enabled and the detail is visible**, and reduced motion freezes it to a still pose.

The structural lesson: **one loop per screen, connected on open, disconnected on close**, not one loop per element and never a loop that runs while hidden. A slowly turning sunburst can even be a single engine tween (`Rotation` 0 to 360, `Linear`, repeat -1) started on open.

## Springs

TweenService has no spring easing, and tweens are bad at interruptible motion (a hover that starts while the previous un-hover is still tweening restarts from a fixed curve). A tiny spring integrator gives natural, interruptible motion for hover lift, drag follow and number roll-ups:

```lua
--!strict
-- Damped spring toward a target. zeta < 1 overshoots, zeta = 1 is critically damped.
export type Spring = { x: number, v: number, target: number, freq: number, zeta: number }

local function newSpring(x: number, freq: number, zeta: number): Spring
	return { x = x, v = 0, target = x, freq = freq, zeta = zeta }
end

local function stepSpring(s: Spring, dt: number)
	-- semi-implicit Euler, sub-stepped for stability at low frame rates
	local w = 2 * math.pi * s.freq
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local a = -w * w * (s.x - s.target) - 2 * s.zeta * w * s.v
		s.v += a * h
		s.x += s.v * h
	end
end

-- Usage: hover lift. freq 4 Hz, zeta 0.6 gives a quick move with a small overshoot.
-- local lift = newSpring(0, 4, 0.6)
-- on hover: lift.target = -6   on leave: lift.target = 0
-- each frame while the screen is open: stepSpring(lift, dt); frame.Position = base + UDim2.fromOffset(0, lift.x)
```

Rule of thumb values: UI hovers 3 to 6 Hz with damping 0.5 to 0.8; number counters 2 to 3 Hz critically damped. See [[Springs Damping and Smoothing]] for the maths.

## Flipbooks

Two kinds:

1. **GUI sprite sheets**: one `ImageLabel` showing a grid of frames; step `ImageRectOffset` by frame with `ImageRectSize` set to one cell. Uploaded images are limited in resolution (Roblox downscales large uploads; plan sheets around about 1024 px per side), so a 4 x 4 sheet gives 256 px frames.

```lua
local function playFlipbook(img: ImageLabel, cols: number, rows: number, cell: Vector2, fps: number, loop: boolean)
	task.spawn(function()
		local n = cols * rows
		local i = 0
		img.ImageRectSize = cell
		while img.Parent do
			local c, r = i % cols, math.floor(i / cols)
			img.ImageRectOffset = Vector2.new(c * cell.X, r * cell.Y)
			i += 1
			if i >= n then
				if not loop then break end
				i = 0
			end
			task.wait(1 / fps)
		end
	end)
end
```

2. **Particle flipbooks** for world VFX: `ParticleEmitter` has `FlipbookLayout` (`Enum.ParticleFlipbookLayout`), `FlipbookMode` (`Enum.ParticleFlipbookMode`), `FlipbookFramerate` (a `NumberRange`), `FlipbookStartRandom`, `FlipbookBlendFrames`, and `FlipbookSizeX` / `FlipbookSizeY` for custom grids. The reference VFX used 4 x 4 greyscale flipbooks tinted per element. See [[VFX Timing with Animation]].

## Performance rules

- **Prefer engine tweens to per-frame Lua.** A looping tween costs nothing in Lua. A Heartbeat loop that touches 40 properties per frame on a phone is measurable.
- **Run loops only while visible**, and disconnect on close. The reference HUD ran gem sheen, glow pulse and wobble "in one Heartbeat loop only while shown".
- **Do not create Tween objects per frame.** Create on events.
- **Avoid tweening layout-driving properties** (`Size` inside layouts, `TextScaled` labels) every frame; use `UIScale`.
- **`CanvasGroup` costs a render target.** Use it where you need group fades or clipping of rounded content, not on every button.

## Gotchas found in production

- A `UIGradient` on a `ViewportFrame` **tints the 3D model** inside it. Put the gradient on a backdrop frame behind the viewport instead.
- `ClipsDescendants` **ignores `UICorner`**: a child painted past a rounded parent's corners shows square "pockets". Clip rounded content with a `CanvasGroup` (which respects its own corner) or inset the child.
- Nested rounding (a rounded child inside a rounded parent with a different radius) looks uneven at the corners; derive the inner radius from the outer minus the inset.
- Scales and pops must account for a global UI scaler (phones): store a base scale (`BaseScale` attribute) and multiply, or a pop to 1 undoes the device scaling.

## Reduced motion and accessibility

Read `GuiService.ReducedMotionEnabled` (a read-only user preference) and your own setting. Reference behaviour: idle animations become still poses, toasts skip their letter animation, decorative loops do not start. Keep **state changes** visible (a toggle still changes colour; a reward still appears) and remove **decorative motion**. `GuiService.PreferredTransparency` similarly reports a preference for less transparent backgrounds.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Pop grows from a corner | Default AnchorPoint | Scale about the centre |
| List jiggles during a pop | Tweening `Size` in a layout | `UIScale` |
| Phone gets hot in menus | Per-frame loops while hidden | Loops only while visible |
| Hover flickers between states | Restarting tweens on rapid enter/leave | Spring toward a target |
| Pop undoes phone scaling | Tween to 1 ignores the base scale | Multiply by a stored base |
| Model in viewport tinted | Gradient on the ViewportFrame | Gradient on a backdrop |

See also: [[Settings Menu Design for Roblox - Layout, Controls and Motion]] (a full settings menu, control by control), [[Tween and CFrame Animation of Objects]], [[Springs Damping and Smoothing]], [[Camera Shake and Camera FX]], [[Emotes and Social Animation]], [[Performance and Memory]].

## Nuances and edge cases

1. **Motion budget is per screen, not per widget.** One pop is delightful; eight elements popping at once when a menu opens is noise. Pick one hero motion per screen transition (the panel), and keep children to quick fades or a short stagger (around 20 to 40 ms between items, rule of thumb, capped so the last item lands within about 0.3 s).
2. **Input must never wait for motion.** If a button only becomes clickable after its 0.25 s pop finishes, fast players tap through dead buttons. Make the element interactive on frame one and let the animation be cosmetic. The same applies to closing: a closing menu should stop eating input immediately.
3. **Phones and frame drops.** Tweens are time based, so a dropped frame skips motion rather than slowing it. On a low-end phone at 20 FPS, a 0.15 s pop is three frames and reads as a jump. That is fine; do not lengthen motion for phones. Do cut decorative loops on low graphics quality.
4. **Gamepad selection motion.** On console, the selected object needs a clear, animated focus state. Animating `GuiService.SelectedObject` changes (a highlight that slides between buttons) helps players track focus, but the highlight must update instantly on fast D-pad presses; tween with a short time (under 0.1 s) or snap.
5. **Large lists.** Animating every row in a 200-item inventory on open costs real time on phones, especially if each row has its own tween. Animate the container, and only the first visible rows; rows that scroll into view later should appear without motion, or with a single cheap fade.
6. **Server-driven UI changes.** Currency counters that tween on every server update can lag behind the real value when updates arrive faster than the tween. Retarget the tween from its current value to the new target instead of queueing, so the display always converges on the latest number.
7. **Localization.** Text that animates letter by letter assumes left-to-right single-codepoint characters. Right-to-left languages and grapheme clusters (emoji, combined characters) break naive per-character reveals. Reveal with `MaxVisibleGraphemes` (which counts graphemes, Roblox docs (as of October 2026)) rather than substring slicing.
8. **Reduced motion is not "no feedback".** Under reduced motion, keep colour and state changes and short fades; remove scaling, bouncing, sliding and looping decoration.

The senior trade-off: UI motion is the cheapest juice in the game and the easiest to overdo. Players spend more time in menus than designers expect; anything that delays a repeated action (opening the inventory 50 times a session) must be faster than anything players see once.

## Common mistakes in production

1. **Buttons inactive until the pop finishes.** Symptom: fast taps do nothing. Fix: interactive immediately.
2. **Counter tween queues.** Symptom: coin counter lags seconds behind after a big payout. Fix: retarget from current value, cap the tween length.
3. **Letter reveal with `string.sub`.** Symptom: broken characters in some languages, emoji split in half. Fix: `MaxVisibleGraphemes`.
4. **Every row animated in long lists.** Symptom: inventory opening stutters on phones. Fix: animate the container and first rows only.
5. **Close animation that blocks the next open.** Symptom: double-tapping a menu button leaves it closed or half open. Fix: cancel the running tween and go to the new target state.

## Related decisions

- [[UI Motion Language and Timing]]: the timing system these patterns should follow across the whole game.
- [[Virtualized Lists and Large Inventories]]: animating rows in lists that only render what is visible.
- [[Gamepad and Console UX]]: focus motion for controller navigation.
- [[Notification and Toast Systems]]: motion for toasts that stack and expire.
- [[Localization]]: text reveals and animated labels across languages.
- [[Motion Sensitivity and Camera Comfort]]: reduced-motion behaviour shared with the camera.
- [[Reward Moments and Celebrations]]: where big, slow UI motion is worth its time.
- [[Declarative UI - React-Lua and Fusion]]: how motion is handled when UI is built declaratively.
- [[Mobile and Low-End Optimization]]: trimming decorative loops on weak devices.

## Connected notes
<!-- auto-links:start -->
[[Official Docs - UI]] · Debugging UI Layout and Input · Tween vs Spring · Accessibility · Squash Stretch and Anticipation in UI and Characters · Cookbook - UI · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cameras and Cutscenes]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Equip Draw and Flourish Systems]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Custom Locomotion Controller Design]] · [[Enemy and NPC Animation]]
<!-- related:end -->
