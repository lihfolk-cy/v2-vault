---
tags: [ui, motion, animation, tweenservice, timing, easing, springs, reduced-motion, design-system]
---
# UI Motion Language and Timing

A motion language is the small set of rules that decides how every piece of UI moves: which direction things come from, how long they take, which easing they use, what happens when the player interrupts them, and what all of it collapses to when the player asks for reduced motion. Without one, every panel gets tuned by whoever built it, and the game ends up with 40 different "open" animations that feel like 40 different products.

This note goes past the button numbers already listed in [[UI Design Systems]] and [[Game Feel and Juice]], and the pattern catalogue in [[UI and GUI Animation]]. It is about the decisions behind the numbers: timing that scales with distance, interruption, choreography, what property to animate, and the failure modes that only show up when real players mash buttons on a phone at 30 fps.

---

## 1. What motion is for

UI motion has exactly four jobs. If an animation does none of them, cut it.

| Job | Question it answers | Example |
|---|---|---|
| **Orientation** | Where did this come from, where did it go? | The shop slides in from the shop button; closing it shrinks back toward the button |
| **Causality** | What did my input do? | Press squash on a button; a coin flying from the enemy into the counter |
| **Hierarchy** | What should I look at first? | The reward card arrives before the "Claim" button; the button arrives last |
| **State** | Is this busy, ready, locked, new? | A breathing glow on a claimable reward; a shake on a locked one |

"It looks nice" is not on the list. Decorative motion is allowed, but it is idle life (see [[UI and GUI Animation]], looping tweens) and it has a budget, not a job.

The corollary: **motion must be consistent to carry meaning.** If the shop enters from the right and the inventory enters from the bottom for no reason, players learn nothing from direction. If every panel that is "on top of the world" scales in from centre and every panel that is "part of the HUD" slides from its edge, direction starts to mean something.

---

## 2. The vocabulary: five verbs

Define motion as verbs, not as per-element tweens. Every animation in the game should be one of these:

| Verb | Use | Easing family | Duration (rule of thumb) |
|---|---|---|---|
| **Enter** | Something appears | Out (decelerate into rest); Back Out for playful styles | 0.18 to 0.30 s |
| **Exit** | Something leaves | In (accelerate away); never Back In for anything that blocks input | 0.10 to 0.18 s |
| **Move** | Something already visible changes place or size | InOut (Quad or Sine) | 0.20 to 0.40 s, scaled by distance |
| **Feedback** | Confirm an input | Out, very short; springs if interruptible | 0.06 to 0.12 s down, 0.20 to 0.30 s back |
| **Emphasis** | Draw the eye to a change | Back Out pop, or a spring kick | 0.25 to 0.45 s |

Why exits are faster than entrances: the player chose to leave, so the old content is no longer interesting, and anything blocking the screen delays the next action. A good rule of thumb is exit time = 0.6 to 0.75 of enter time. The reference project landed on 0.26 s in and 0.14 s out for its popups, a ratio of about 0.54, and players read it as "snappy", not "abrupt".

Why Back In is dangerous on exits: Back In first moves the element *the wrong way* (it grows slightly before shrinking). On a close button that reads as hesitation, and on a fast double tap it reads as the panel refusing to close. Use Quad In or Quint In for exits; save overshoot for arrivals.

Roblox's `Enum.EasingStyle.Back` has a fixed overshoot (you cannot pass a tension parameter to `TweenInfo`). If Back is too bouncy for a large element, either shorten it, animate a smaller range (scale from 0.92, not from 0), or use a spring where you control damping ([[Springs Damping and Smoothing]]).

---

## 3. Timing numbers and why they scale

### Perception bands (rule of thumb)

| Duration | How it reads |
|---|---|
| Under 0.1 s | Instant; the motion itself is barely seen, only its result |
| 0.1 to 0.2 s | Snappy; ideal for feedback and exits |
| 0.2 to 0.35 s | Visible motion; ideal for entrances and small moves |
| 0.35 to 0.6 s | Deliberate; only for big reveals or large travel |
| Over 0.6 s | Slow; the player is waiting on you. Acceptable only in a reward sequence the player is enjoying, never in navigation |

These are not Roblox facts, they are general interaction design guidance, but they hold on Roblox with one twist: **frame rate**. A 0.12 s tween at 30 fps is 3 or 4 frames. At that length the easing curve is not visible at all, only the endpoints. On low-end phones, very short tweens degrade into a pop, so durations below about 0.08 s are pointless except as a way of saying "instant but not jarring".

### Duration should scale with distance

A fixed 0.3 s for every move makes short moves look sluggish and long moves look frantic. Scale duration with distance, with a floor and a ceiling:

```
duration = clamp(base + k * sqrt(distance_in_px), minT, maxT)
```

The square root is the important part: doubling distance should not double time. With base 0.12, k 0.012, min 0.15, max 0.45 (rule of thumb starting values, tune by eye):

| Distance | Duration |
|---|---|
| 40 px | 0.19 s |
| 200 px | 0.29 s |
| 600 px | 0.41 s |
| 1200 px | 0.45 s (capped) |

Size matters too: a full-screen panel entering should be slower than a 60 px toast, even over the same distance, because more of the screen is changing. A practical shortcut is to give large surfaces their own token (`enterLarge`) about 1.3 times the small one, rather than computing area.

### Distance should be in screen space, not UDim

If you compute distance from `UDim2.Scale`, a move of 0.5 scale is 400 px on a phone and 1,280 px on a 2560 px monitor. Compute it from `AbsolutePosition` differences, or accept that durations will be "wrong" on one end. Reading `AbsolutePosition` is cheap; just do not read it every frame.

---

## 4. Easing choices that hold up

| Situation | Choice | Why |
|---|---|---|
| Panel enters | Back Out (playful) or Quint Out (clean) | Decelerating into rest feels like arrival |
| Panel exits | Quad In or Quint In | Accelerating away feels like departure |
| Tab indicator slides between tabs | Quad InOut or a critically damped spring | Starts and ends at rest; spring handles rapid tab switching |
| Progress bar fills | Quad Out | Fast start reads as responsive, slow end as precise |
| Number count-up | Quad Out, or Exponential Out for huge numbers | Most of the change happens early; the last digits settle |
| Looping idle (bob, breathe) | Sine InOut with `Reverses = true` | No visible seam at the turnaround |
| Shake | Not a tween; a decaying noise or spring kick | Tweens cannot express oscillation that decays |

**Linear is almost never right** for spatial motion. It is right for things that represent time (a cooldown sweep, a timer bar) because the player reads the bar as a clock.

**Elastic and Bounce styles** look fun in isolation and terrible at scale. Elastic overshoots several times; on a panel that means the content wobbles while the player tries to read it. Use them for single icons in a reward moment only.

---

## 5. Interruption: where most UI motion breaks

Players do not wait for animations. They double tap, they open the shop while the inventory is closing, they press B on a gamepad mid-entrance. Every animation must answer "what happens if this is interrupted at any frame?"

### What the engine does

- Creating and playing a new tween on a **property that another tween is already animating** on the same instance overrides the older tween; the older one stops and its `Completed` fires with `Enum.PlaybackState.Cancelled` (Roblox docs, "Tween Conflict" sample on `TweenBase`; the older reference wording described it as cancelled and overwritten). The new tween starts from **the current value**, not the old start value.
- Tweens animating **different properties** of the same instance run side by side.
- `Tween:Cancel()` stops the tween and leaves the property wherever it was; it does not snap back. The tween can be replayed from the start.
- `Tween:Pause()` keeps progress; `Play()` resumes.

### The three rules that follow

**Rule 1: never hide or destroy on `Completed` without checking the state.** The classic bug: close starts, `Completed` will set `Visible = false`; the player reopens before it finishes; the open tween overrides the close tween; the close tween's `Completed` fires with `Cancelled`; the handler hides the panel anyway. The player sees the shop open and then vanish.

```lua
closeTween.Completed:Connect(function(state: Enum.PlaybackState)
	if state == Enum.PlaybackState.Completed then
		panel.Visible = false
	end
end)
```

**Rule 2: drive animations from state, not from events.** Store "this panel should be open" as a boolean. Every input flips the boolean and calls one function that animates toward the state. Rapid toggling then always converges to the last requested state, and you never need "is it animating?" flags.

**Rule 3: retarget with proportional time.** If a close is interrupted at 80% by a reopen, the panel is only 20% away from fully open, so the reopen should take about 20% of the entrance time, not all of it. The remaining distance decides the time. For scale and transparency animations, compute the fraction left:

```lua
-- fraction of the way from `from` to `to` still remaining, given the current value
local function remainingFraction(current: number, from: number, to: number): number
	if from == to then
		return 0
	end
	return math.clamp((to - current) / (to - from), 0, 1)
end

local t = token.time * remainingFraction(scale.Scale, 0.9, 1)
```

Without this, a panel that was 95% closed when the player reopened it takes the full entrance time to travel 5% of the way, which feels like input lag.

### When to use springs instead

Springs handle interruption natively: a spring keeps velocity, so retargeting mid-motion curves smoothly instead of restarting an easing curve from zero velocity. That is why tab indicators, sliders, drag-and-release, and HUD tiles that get poked often are better as springs. The cost is a per-frame update while moving. The reference project ran one shared render-step connection that existed only while any spring was unsettled and disconnected when everything came to rest, so idle UI cost zero Lua per frame ([[HUD Design]], section 7). The math and frame-rate-independent integrators are in [[Springs Damping and Smoothing]].

Newer engine builds also list a `TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?)` method that returns the new value and new velocity (Roblox docs, as of October 2026). It is a critically damped follower in the style of other engines. It is a reasonable built-in for "follow the target smoothly" motion; it does not overshoot, so it cannot replace a bouncy spring. The docs page lists the signature but little behavioural detail, so test it before building a system on it.

---

## 6. Choreography: several things moving at once

### Stagger

When a grid of reward cards or a list of quests appears, staggering their entrances tells the eye the reading order. Two numbers matter: the per-item step and the total cap.

| Item count | Step | Total |
|---|---|---|
| 2 to 5 | 0.05 to 0.07 s | under 0.3 s |
| 6 to 12 | 0.03 to 0.04 s | 0.3 to 0.4 s |
| More than 12 | Stagger only the first row or the first 8, then show the rest together | 0.4 s cap |

The cap is the important part. A 40-item inventory staggered at 0.05 s takes 2 s to finish appearing, and the player cannot click item 30 until it arrives. Compute the step as `min(step, cap / (count - 1))`.

### Lead and follow

In a composite panel, one element leads and the rest follow:

1. The **container** enters (scale or slide), 0.2 to 0.26 s.
2. The **content** fades or rises 0.04 to 0.08 s later, over a shorter duration, so it finishes about the same time as the container.
3. The **primary action button** arrives last, with emphasis (a small pop), because it is what the player does next.

Exits reverse the hierarchy but compress it: everything leaves together. Nobody wants to watch a choreographed goodbye.

### Overlap, not sequence

Chained animations (`Completed:Wait()` then the next) add up. Three 0.25 s steps in sequence is 0.75 s of the player waiting. Overlap them: start step 2 when step 1 is about 60% done. A `task.delay` with the right offset is simpler and more robust than waiting on `Completed`, which also never fires if the tween is overridden in some code paths you did not expect.

---

## 7. What property to animate

The property you tween decides the cost and the side effects.

| Property | Cost and side effects | Use for |
|---|---|---|
| `UIScale.Scale` | Cheap; scales the whole subtree including text and strokes; does not change layout slots | Pops, panel entrances, press squash |
| `Size` | Triggers layout of siblings and re-wraps text every frame; `TextScaled` text recomputes | List items growing into place on purpose (see [[UI Layout Objects - Lists Grids and Pages]], section 9) |
| `Position` | Cheap unless a layout owns the element (layouts overwrite it) | Slides, flying gains |
| `Rotation` | Cheap; children rotate with it; clipping (`ClipsDescendants`) does not rotate with content | Wiggles, spinners |
| `BackgroundTransparency` / `ImageTransparency` per element | One tween per element; children are unaffected | Single-element fades |
| `CanvasGroup.GroupTransparency` | One property fades the whole subtree correctly, but the group renders to an off-screen texture (memory, and text inside can look soft) | Whole-panel fades |
| `UIGradient.Offset` / `Rotation` | Cheap; great for shine sweeps | Shine, shimmer |
| Text content (count-up) | Every write re-shapes text and invalidates the ScreenGui cache | Counters, at a capped update rate |

Two non-obvious points:

- **Scaling a panel with `UIScale` makes `TextScaled` text and `UIStroke` thickness scale too**, which is usually what you want for a pop. Tweening `Size` instead makes `TextScaled` text jump between font sizes as the box grows, which shows as visible stepping in the text. If a pop "shimmers", check whether it is a `Size` tween.
- **Fading without a CanvasGroup** means tweening each element's transparency, so remember each element's designed base transparency (an attribute set the first time) and fade toward it. Otherwise a frame designed at 0.3 fades in to 0 and the design changes after the first open.

---

## 8. A motion module that enforces the language

The point of a module is not convenience. It is that nobody can write `TweenInfo.new(0.37, Enum.EasingStyle.Elastic)` in a panel script without it being obvious in review.

```lua
--!strict
-- Motion: the only place TweenInfo is created for UI.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

export type TokenName = "feedback" | "release" | "enter" | "enterLarge" | "exit" | "move" | "emphasis"

local TOKENS: { [TokenName]: TweenInfo } = {
	feedback = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	enter = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	enterLarge = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	exit = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	move = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	emphasis = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

-- Properties that are "motion" (removed under reduced motion). Fades stay.
local MOTION_PROPS = { Position = true, Size = true, Rotation = true, Scale = true }

local Motion = {}

-- A game-level override so players can reduce motion even if the OS setting is off.
Motion.forceReduced = false

function Motion.reduced(): boolean
	return Motion.forceReduced or GuiService.ReducedMotionEnabled
end

local function scaledInfo(info: TweenInfo, fraction: number): TweenInfo
	return TweenInfo.new(info.Time * math.clamp(fraction, 0, 1), info.EasingStyle, info.EasingDirection)
end

-- Animate `inst` toward `goals` with a named token.
-- fraction (optional) shortens the tween when retargeting mid-motion.
function Motion.to(inst: Instance, token: TokenName, goals: { [string]: any }, fraction: number?): Tween?
	local info = TOKENS[token]
	if fraction then
		info = scaledInfo(info, fraction)
	end

	if Motion.reduced() then
		local fades: { [string]: any } = {}
		local hasFade = false
		for prop, value in goals do
			if MOTION_PROPS[prop] then
				(inst :: any)[prop] = value -- jump straight to the end state
			else
				fades[prop] = value
				hasFade = true
			end
		end
		if not hasFade then
			return nil
		end
		goals = fades
		info = TweenInfo.new(math.min(info.Time, 0.15), Enum.EasingStyle.Linear)
	end

	local tween = TweenService:Create(inst, info, goals)
	tween:Play()
	return tween
end

-- Stagger a callback over items with a capped total duration.
function Motion.stagger(items: { GuiObject }, step: number, cap: number, fn: (GuiObject, number) -> ())
	local n = #items
	local s = if n > 1 then math.min(step, cap / (n - 1)) else 0
	if Motion.reduced() then
		s = 0
	end
	for i, item in items do
		if s == 0 then
			fn(item, i)
		else
			task.delay((i - 1) * s, function()
				if item.Parent then -- the list may have been rebuilt meanwhile
					fn(item, i)
				end
			end)
		end
	end
end

return Motion
```

Notes on the module:

- `Motion.to` returns `nil` when there is nothing to animate (reduced motion with only motion properties). Callers that wait on `Completed` must handle that; a helper that returns a finished state immediately is a good addition.
- `GuiService.ReducedMotionEnabled` is a read-only, client-side property that mirrors the player's Roblox reduced-motion setting (Roblox docs, as of October 2026). Read it on the client. Also offer your own in-game toggle (`forceReduced`), because many players never find the platform setting.
- The `fraction` argument is how panels implement Rule 3 from section 5.

### A panel controller using it

```lua
--!strict
local Motion = require(script.Parent.Motion)

local function makePanel(panel: CanvasGroup)
	local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = panel
	local wantOpen = false

	local function apply()
		if wantOpen then
			panel.Visible = true
			local fraction = 1 - math.clamp((scale.Scale - 0.9) / 0.1, 0, 1)
			Motion.to(scale, "enter", { Scale = 1 }, math.max(fraction, 0.3))
			Motion.to(panel, "enter", { GroupTransparency = 0 }, math.max(fraction, 0.3))
		else
			local t = Motion.to(panel, "exit", { GroupTransparency = 1 })
			Motion.to(scale, "exit", { Scale = 0.9 })
			if t then
				t.Completed:Connect(function(state: Enum.PlaybackState)
					if state == Enum.PlaybackState.Completed and not wantOpen then
						panel.Visible = false
					end
				end)
			else
				panel.Visible = false
			end
		end
	end

	return function(open: boolean)
		if open == wantOpen then
			return
		end
		wantOpen = open
		apply()
	end
end

return makePanel
```

The `max(fraction, 0.3)` floor keeps a reopen from being so short it pops; tune it. The `not wantOpen` check in `Completed` is belt and braces on top of the state check.

---

## 9. Panel stacking and navigation motion

- **One panel on top at a time** for most Roblox games. When panel B opens from panel A (shop to a product detail), either replace A (A exits, B enters, overlapped) or stack B on A with a backdrop dim on A. Do not slide both around.
- **Backdrop dim**: a full-screen black frame at 0.5 to 0.6 transparency fading in with the panel (same token). It doubles as the click-outside-to-close target. Fade it, never scale it.
- **Back navigation reverses direction**. If going deeper slides content left, going back slides it right. Players read direction as depth.
- **Gamepad selection** should not wait for the entrance. Set `GuiService.SelectedObject` at the start of the entrance, not on `Completed`, or a fast player presses A on nothing ([[Gamepad and Console UX]]).
- **Input during entrance**: buttons should accept input from the first frame they are visible. Disabling input until the animation finishes is the most common reason a UI "feels slow" even with short tweens.

---

## 10. Performance

- **Tweens run in the engine**, not in Lua, so a few dozen concurrent tweens are cheap. The cost of UI motion is mostly in what the tween invalidates: layout passes (`Size` under a layout), text shaping (text changes, `TextScaled`), and CanvasGroup re-renders.
- **Every property change invalidates the ScreenGui's cached render** ([[ScreenGui Fundamentals]]). Constantly animated pieces belong in their own small ScreenGui so the static HUD keeps its cache.
- **Infinite tweens** (`RepeatCount = -1`) keep running while invisible. Pause or cancel idle loops when their panel closes. A closed shop with six breathing glows still pays for them.
- **Per-frame Lua springs** should share one connection that disconnects when idle. A spring per button with its own `RenderStepped` connection is the most common motion-related performance leak.
- Low-end phone check: open the busiest panel at the lowest graphics setting on a real device and watch the MicroProfiler for layout or text spikes during entrance ([[MicroProfiler Guide]], [[Mobile and Low-End Optimization]]).

---

## 11. Reduced motion, done properly

"Reduced motion" does not mean "no feedback". It means no spatial movement that the player did not cause directly, and no large or looping motion.

| Normal | Reduced |
|---|---|
| Panel scales in from 0.9 | Panel fades in, 0.1 to 0.15 s |
| Button squash and lift on hover/press | Colour or brightness change only |
| Cards stagger in | All cards appear together |
| Coin flies to counter | Counter pulses its colour once |
| Screen shake on a big reward | No shake; a brief flash or sound |
| Idle bobbing icons | Static |

The reference project's rule was "fades only, no scale or lift" under reduced motion, and its camera effects kept only a halved FOV punch. Also see [[Accessibility]].

---

## Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Hiding on `Completed` without checking state | Panel opens then vanishes when reopened quickly | Check `Enum.PlaybackState.Completed` and current intent |
| Back In on exits | Close looks hesitant; panel briefly grows | Quad or Quint In |
| Input disabled until entrance ends | "UI feels laggy" reports with short durations | Accept input from first visible frame |
| Same duration for every distance | Small moves sluggish, big moves frantic | Scale with sqrt of pixel distance, clamp |
| Unbounded stagger | Long lists take seconds to appear | Cap total at about 0.4 s |
| Tweening `Size` for a pop | Text steps between sizes; siblings jitter | Tween a `UIScale` |
| Full-time idle loops on closed panels | Frame time cost with nothing on screen | Pause loops when hidden |
| Each panel creates its own `TweenInfo` | Inconsistent feel; review cannot catch it | One motion module with tokens |
| Reduced motion means "do nothing" | No feedback at all for those players | Swap motion for fades and colour |
| Gamepad selection set on `Completed` | First A press does nothing | Select at start of entrance |

---

## Checklist

- [ ] All UI tweens go through one module with named tokens.
- [ ] Exits are faster than entrances and use In easing without overshoot.
- [ ] Moves scale duration with screen-space distance, clamped.
- [ ] Every hide or destroy on `Completed` checks the playback state and the current intent.
- [ ] Rapid toggling (10 taps per second) always ends in the last requested state.
- [ ] Retargeted tweens use proportional duration.
- [ ] Staggers are capped at about 0.4 s total.
- [ ] Pops use `UIScale`, not `Size`.
- [ ] Idle loops pause when their panel is hidden; springs share one connection that stops when idle.
- [ ] `GuiService.ReducedMotionEnabled` plus an in-game toggle swap motion for fades.
- [ ] Input and gamepad selection work from the first visible frame.
- [ ] Tested on a low-end phone at its lowest graphics level.

## See also

[[UI and GUI Animation]], [[Springs Damping and Smoothing]], [[Game Feel and Juice]], [[UI Design Systems]], [[HUD Design]], [[Notification and Toast Systems]], [[Virtualized Lists and Large Inventories]], [[Accessibility]], [[ScreenGui Fundamentals]], [[Declarative UI - React-Lua and Fusion]]

## Connected notes
<!-- auto-links:start -->
[[Easing]] · [[Tween vs Spring]] · [[Links - Tweening and UI animation]] · [[Squash Stretch and Anticipation in UI and Characters]] · [[Skill - Roblox UI Builder]] · [[Tween and CFrame Animation of Objects]]
<!-- auto-links:end -->
