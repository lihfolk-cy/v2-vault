---
tags: [game-feel, juice, feedback, ui, vfx, audio, combat]
---
# Game Feel and Juice

Game feel is the sense that the game responds to you: a click that pops, a hit that lands, a reward that pays out. "Juice" is the pile of small, cheap feedback that creates it: scale pops, flashes, particles, sounds, numbers that count up, a tiny shake. On Roblox, where a new player decides in the first minute whether to stay, juice is not polish to add at the end; it is part of the core loop ([[Core Loops and Session Design]]).

This note covers the feedback stack for an action, UI juice (with working code for a click burst and a floating gain number), combat juice, how to keep juice from becoming noise, and accessibility.

Source labels: **Docs**, **Reference project** (one production game), **Rule of thumb**.

---

## 1. The feedback stack

Every meaningful action should answer three questions within about 100 ms: *did it register*, *what happened*, *how much*. Layers, ordered by cost-effectiveness (rule of thumb):

| Layer | Example | Cost |
|---|---|---|
| Scale pop | Button to 1.1x and back, 0.1 s out, 0.15 s back | Trivial |
| Colour flash | White wash over the element | Trivial |
| Sound | A click, a coin, a whoosh, with slight pitch variation | Low |
| Count-up numbers | 1,240 rolls up to 2,380 instead of snapping | Low |
| Particle burst | Sparkles at the reward source | Low to medium |
| Motion to destination | Coins fly from the source to the counter | Medium |
| Shake | 2 to 4 px UI shake or a small camera shake, rare | Low, but tiring if overused |
| Anticipation | 0.3 s wind-up before a reveal | Free, and it makes the payoff land |

A good rule: **every input gets at least a pop and a sound; every reward gets motion and a number; only big moments get shake.**

---

## 2. UI juice

### Button motion numbers (reference project)

The reference project's shared UI motion module, after a pass asked for "bouncy and smooth":

| State | Motion |
|---|---|
| Hover | Scale 1.06, lift 3 px, a soft white wash on filled faces |
| Press | Scale 0.9 over 0.08 s |
| Release | Back easing, 0.3 s |
| Gamepad selection | Same as hover |
| Panel open | Scale 0.82 to 1, Back Out, 0.26 s |
| Panel close | Back In to 0.9, 0.14 s |
| Reduced motion | No scale or lift; wash fade or group fade only |

Two engineering notes from that pass:
- **One on-demand frame loop**, not one per button. It ran only while something was animating and stopped when idle.
- **Idempotent attachment** (a weak table of buttons already wired), so re-running setup on rebuilt UI never doubled the animations.

General motion advice (springs versus tweens, easing vocabulary) is in [[UI and GUI Animation]] and [[Springs Damping and Smoothing]].

### Click bursts and floating gains

A clicker-style reference the reference project emulated: a **white ring with spokes** bursting at every click or tap, a **"+$X" gain** floating from the click into the cash counter with a fading "ghost echo", and a rolling **"+$X/s" rate** under the counter. This is the kind of feedback that makes repetitive actions feel good.

```lua
--!strict
-- ClickBurst (client): ring + spokes at the pointer on every click or tap.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local gui = Instance.new("ScreenGui")
gui.Name = "ClickBurst"
gui.IgnoreGuiInset = true -- GetMouseLocation is in full-screen coordinates
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local SPOKES = 8
local REDUCED_MOTION = false -- wire to your settings

local function burst(pos: Vector2)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(pos.X, pos.Y)
	ring.Size = UDim2.fromOffset(10, 10)
	ring.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = ring
	ring.Parent = gui

	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(56, 56) }):Play()
	TweenService:Create(stroke, info, { Transparency = 1, Thickness = 1 }):Play()

	if not REDUCED_MOTION then
		for i = 1, SPOKES do
			local angle = (i / SPOKES) * math.pi * 2
			local dir = Vector2.new(math.cos(angle), math.sin(angle))
			local spoke = Instance.new("Frame")
			spoke.AnchorPoint = Vector2.new(0.5, 0.5)
			spoke.BackgroundColor3 = Color3.new(1, 1, 1)
			spoke.BorderSizePixel = 0
			spoke.Size = UDim2.fromOffset(10, 3)
			spoke.Rotation = math.deg(angle)
			local start = pos + dir * 10
			local finish = pos + dir * 34
			spoke.Position = UDim2.fromOffset(start.X, start.Y)
			spoke.Parent = gui
			TweenService:Create(spoke, info, {
				Position = UDim2.fromOffset(finish.X, finish.Y),
				Size = UDim2.fromOffset(4, 2),
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.4, spoke.Destroy, spoke)
		end
	end
	task.delay(0.4, ring.Destroy, ring)
end

UserInputService.InputBegan:Connect(function(input: InputObject)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		burst(UserInputService:GetMouseLocation())
	end
end)
```

For touch, `GetMouseLocation()` returns the last touch position on most devices; if you need exact multi-touch, use `input.Position` (which is inset-relative; add `GuiService:GetGuiInset()` when the ScreenGui ignores the inset). If clicks are frequent, pool the frames rather than creating them; at a few clicks per second creation is fine.

### Floating gains into the counter

```lua
--!strict
-- FloatGain: a "+X" label that flies from a screen point into a target GuiObject, then pops it.
local TweenService = game:GetService("TweenService")

local function floatGain(layer: ScreenGui, from: Vector2, target: GuiObject, text: string)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(120, 255, 120)
	label.Text = text
	label.Position = UDim2.fromOffset(from.X, from.Y)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = layer

	-- Rise a little first (anticipation), then fly to the counter.
	local rise = from + Vector2.new(0, -30)
	local up = TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(rise.X, rise.Y),
	})
	up:Play()
	up.Completed:Wait()

	-- AbsolutePosition is inset-relative; this assumes `layer` and the target's ScreenGui use the same IgnoreGuiInset.
	local dest = target.AbsolutePosition + target.AbsoluteSize / 2
	local fly = TweenService:Create(label, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(dest.X, dest.Y),
		TextSize = 16,
	})
	fly:Play()
	fly.Completed:Wait()
	label:Destroy()

	-- Payoff: pop the counter.
	local scale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = target
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
```

This function yields; call it with `task.spawn`. For world sources (a coin dropped by an enemy), convert with `Camera:WorldToViewportPoint` to get the screen start point.

### Numbers

- **Count up**, do not snap: tween a `NumberValue` and render its value each step, or use a spring. Snapped numbers feel like a spreadsheet.
- **Merge rapid gains**: the reference project's popup system merged same-kind numbers within 0.55 s and pooled at most 12 on screen.
- **Format** large numbers (1.2K, 3.4M) and keep digit width stable (tabular fonts or fixed widths) so counters do not jitter.

### Reward moments
Big rewards earn a sequence: anticipation (a charge, rising pitch), a reveal (flash, burst, banner), a payoff (number, item card), and a settle. The reference project gated celebration popups: none during the tutorial, and they waited out cutscenes, deaths and open panels (up to 20 s) so they never landed on top of something else. See [[Genre Playbook - RNG and Collection Games]] for reveal pacing.

---

## 3. Combat juice

| Beat | Tool | Reference numbers |
|---|---|---|
| Hit confirm | Hit-stop on your own hits | From marker strength 0.45 (reference project); see [[Hit Reactions Stagger and Hit-Stop]] |
| Contact | Spark at the blade tip, flash frame | Glint size 2.5 + 3s, life 0.18 + 0.08s (strength-scaled) |
| Weight | Camera shake | Medium impact: amplitude 0.07, frequency 0.22, fade in 0.05, sustain 0.1, fade out 0.6, falloff 30 studs (studied pack) |
| Damage taken | Highlight flash on the character | Throttled to one per 0.12 s, stronger for 12%+ of max health (reference project) |
| Damage dealt | Damage numbers | Pooled, merged, optional in settings |
| Body | Hit sound with peak on the frame | See [[Sound Design for Games]] |
| Kill | Death burst, slow-mo for bosses only | Rule of thumb |

Rules that keep combat juice working:
- **Juice scales with distance.** Other players' small juice only within about 220 studs of your camera (reference project).
- **Screen effects belong to you.** Never apply shake, grade or FOV from someone else's move. During an ultimate, only the ultimate system owns them.
- **Strength drives layers.** A light hit gets a glint; a finisher gets glint, glow, streak, flash and shake. Uniform juice flattens everything.
- **Juice on the hit, not on the click.** Feedback scheduled at input time fires even when the attack whiffs; place it on the hit marker ([[VFX Timing with Animation]]).

Camera shake implementation is in [[Camera Shake and Camera FX]] and [[Snippets - Camera Shake and FX]].

---

## 4. Audio juice

- Every interactive UI element has a sound; pick a coherent kit (pop click, soft tick, air whoosh, open bloop, reward run). The reference project synthesised such a kit to match a reference clip, then levelled it so a UI click sits far below combat (target effective loudness 0.025 for clicks, 0.07 for rewards, against 0.17 to 0.27 for combat hits).
- Vary pitch slightly (±3 to 6%) on repetitive sounds to avoid machine-gun fatigue.
- Rising pitch on streaks (combo counter, consecutive coins) is satisfying, but reset it after a pause.
- Throttle: a click sound that plays 30 times a second during auto-actions becomes noise. Cap per-sound rate.

See [[Sound Design for Games]] and [[Spatial Audio and Mixing]].

---

## 5. When juice becomes noise

- **Habituation.** Players stop noticing feedback they see every second. Reserve big layers for rare events.
- **Competition.** When everything flashes, nothing does. Rank events and let higher ones suppress lower ones briefly.
- **Clutter.** Floating numbers that cover the enemy you are fighting are a readability bug.
- **Fatigue.** Shake and flashes cause discomfort. Keep shakes short, rare and optional.
- **Performance.** UI juice that creates hundreds of instances per second leaks into GC hitches. Pool.

### Accessibility

Provide settings for: reduced motion (no scale bounce, no shake, fades only), reduced flashing, damage numbers on/off, separate UI volume. The reference project's reduced-motion path kept wash and fade feedback but removed scale and lift. Roblox has a platform-level reduce-motion preference that affects some built-in features ([[Accessibility]]).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Game feels unresponsive | No immediate feedback on input | Pop plus sound on every input within 100 ms. |
| Rewards feel flat | Numbers snap | Motion to the counter, count-up, pop. |
| Juice on whiffs | Feedback scheduled at click time | Fire on the hit marker. |
| Screen chaos in groups | Others' shakes and flashes applied to you | Screen effects only for your own actions. |
| Hitches during clicking | Instances created per click without limit | Pool; cap concurrent effects. |
| Players complain of nausea | Constant shake and flashes | Rare, short, optional. |
| UI animations double after rebuild | Setup not idempotent | Weak-table guard per element. |

## Checklist

- [ ] Every input: pop and sound.
- [ ] Every reward: motion, number, payoff pop.
- [ ] Big moments: anticipation then reveal.
- [ ] Combat juice scaled by strength and distance; screen effects only for your own actions.
- [ ] Sound kit levelled below combat; pitch variance; rate caps.
- [ ] Reduced motion, reduced flashing and damage-number settings.
- [ ] Pools for bursts and numbers; one frame loop for UI motion.

See also: [[UI and GUI Animation]], [[HUD Design]], [[UI Design Systems]], [[VFX Timing with Animation]], [[Hit Reactions Stagger and Hit-Stop]], [[Camera Shake and Camera FX]], [[Sound Design for Games]], [[Core Loops and Session Design]], [[Accessibility]].

## Nuances and edge cases

1. **Latency decides where juice must run.** Feedback that waits for a server round trip arrives 100 to 300 ms late on typical connections, which feels sluggish. The first layer of feedback (button press, swing sound, a small particle) should run on the client immediately; the confirmed layer (damage number, reward burst) follows the server. Never show the confirmed layer before confirmation, or players see rewards that never arrive.
2. **Frame rate changes perceived juice.** A 0.08-second pop is five frames at 60 FPS and two at 25 FPS on a struggling phone; it may not be seen at all. Prefer effects of at least 0.12 to 0.15 seconds for important feedback (rule of thumb), and drive animations by elapsed time, not frame counts.
3. **Juice multiplies with player count.** One player's hit sparks are fine; 30 players fighting in one place, each seeing everyone's sparks, shakes and sounds, is noise and frame drops. Apply full juice to your own actions, reduced juice to others' actions, and none for far-away ones.
4. **Haptics differ by platform.** Phones and controllers can vibrate; PC usually cannot. Haptic feedback is a strong cue on console and phone, so design it as a bonus channel, never the only one, and respect player settings.
5. **Juice must not lie about game state.** A big hit effect on a blocked attack, or a coin burst for a purchase that failed, teaches players the wrong thing. Tie each effect to the event it describes, and use distinct, smaller effects for blocks, misses and failures.
6. **Diminishing returns over a session.** The first level-up fanfare is delightful; the hundredth in an idle simulator is irritating. Scale celebrations by rarity: frequent events get small feedback, rare events get the big moment. Let players skip long celebrations.
7. **Juice costs memory and instances.** Each burst that creates new instances adds garbage. A pooled set of particles and UI elements, reused, is the difference between smooth clicking and hitches on low-end devices.
8. **Hit-stop in multiplayer.** Freezing time on a hit works in single-player; in multiplayer you cannot freeze the world, only your local presentation (animation speed, camera). Keep it short (a few hundredths of a second) and local.

The senior trade-off: juice is cheap to add and expensive to tune. A small set of consistent, well-timed effects beats many inconsistent ones. Decide the feedback vocabulary (what a hit, a reward, a failure each look and sound like) before adding effects.

## Common mistakes (advanced)

1. **Showing rewards before the server confirms.** Symptom: players see coins they do not get. Fix: show optimistic input feedback only; show rewards on confirmation.
2. **Frame-counted effects.** Symptom: feedback invisible on low frame rates. Fix: time-based durations.
3. **Everyone's juice at full strength.** Symptom: chaos and frame drops in crowded fights. Fix: scale by ownership and distance.
4. **The same big celebration for common events.** Symptom: players mute the game or ignore rewards. Fix: tiered feedback by rarity.
5. **Hit-stop applied on the server.** Symptom: the whole server stutters for everyone. Fix: local presentation only.
6. **No setting to reduce shake and flashes.** Symptom: comfort complaints and drop-off. Fix: an options toggle respected by every effect.

## Related decisions

- [[Hit Reactions Stagger and Hit-Stop]]: hit-stop timing and implementation.
- [[UI Motion Language and Timing]]: consistent UI feedback durations.
- [[Client Prediction and Reconciliation for Combat]]: what may be shown before confirmation.
- [[Combat Sound Design and Feedback]]: the audio half of juice.
- [[VFX Performance Budgets and Culling]]: limiting effects in crowds.
- [[Motion Sensitivity and Camera Comfort]]: settings for shake and flashes.
- [[Rarity Ladders and Drop Pacing Math]]: matching celebration size to rarity.
- [[Notification and Toast Systems]]: feedback that does not interrupt play.

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · [[Reward Moments and Celebrations]] · [[Hit-Stop]] · [[Juice on a Budget - Mobile and Low-End]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Feedback Timing - Sound Visual and Haptic Sync]]
<!-- auto-links:end -->
