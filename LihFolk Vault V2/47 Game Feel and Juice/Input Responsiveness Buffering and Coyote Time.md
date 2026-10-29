---
tags: [game-feel, input, responsiveness, buffering, coyote-time, controls, combat, platformer, luau, type/guide, area/game-feel, level/intermediate]
---
# Input Responsiveness Buffering and Coyote Time

<!-- tldr:start -->
> [!tldr] TL;DR
> - Combos drop when players mash: No buffer, or window shorter than hit-stop plus reaction -> Attack buffer 0.15 to 0.3 s; pause ageing during hit-stop
> - An attack fires after the player stopped: Window too long, or no consume-once -> Shorter window; consume on use
> - Dodge loses to attack when both pressed: No priority -> Defensive actions outrank offensive
> - Every input produces a visible or audible response on the frame it is read.
> - Nothing waits for a server reply before showing local feedback.
> - Buffer windows per action; consume once; priorities; cleared on state changes.
>
> Cost: TL;DR ~190 tok · whole note ~5.6k tok. Read more: ## 2. Input buffering · ## 4. Coyote time on the default Humanoid · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most "this game feels bad" complaints are not about effects at all. They are about **input**: a jump that did not happen on the edge of a platform, an attack pressed slightly early that was swallowed, a dodge that came out a beat late, a phone button that only reacts when the finger lifts. [[Custom Character Controllers]] introduces coyote time and jump buffering in two bullet points with typical windows. This note goes into the mechanism: the responsiveness budget, the first-frame rule, buffering semantics (windows, priority, consumption, clearing), cancel windows, a full coyote and jump-buffer implementation on the default Humanoid, the forgiveness family beyond jumping, touch and gamepad specifics, and how the server should treat inputs that arrive slightly early.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. The responsiveness budget

The classic human-computer interaction figure is that a response within about 100 ms feels instantaneous and connected to the action (rule of thumb, long-standing usability guidance). In an action game the bar is tighter for the **first sign** of a response, and looser for the **outcome**:

| What the player perceives | Target (rule of thumb) |
|---|---|
| Something visibly reacts to the press (pose shift, button press, sound) | Within 1 to 2 frames of the input being read: under about 35 ms at 60 fps |
| The action itself is clearly underway | Within about 100 ms |
| The outcome (hit, damage, reward) | Whenever the design says; can be hundreds of ms if the first two are met |

The budget is consumed by things you do not control (touch screen sampling, display refresh, the frame in which input is read) and things you do (when your handler runs, whether it waits for anything, how long the first visible change takes to appear). On a 30 fps phone, a single frame is already 33 ms; any extra frame of delay you add costs another 33.

### The first-frame rule

**Every action shows something on the frame the input is read**, even when the action itself must wait. Examples:

- An attack on cooldown still plays a tiny "denied" sound and greys the button flash, instead of nothing.
- A server-validated action (open a chest, buy an item) starts its anticipation immediately; the result follows the reply. The latency mask is in [[Squash Stretch and Anticipation in UI and Characters]].
- A sword swing starts its first frame of motion immediately; the hit can come 0.2 s later. The reference project's light combo hits landed 0.20 to 0.217 s after input (measured in the reference project; see [[Principles of Animation for Games]]), which feels responsive precisely because the motion starts at once.

The biggest single offender on Roblox is code that **waits for the server before showing anything**: `RemoteFunction:InvokeServer` in the input handler, then the animation. At 150 ms round trip that is 150 ms of nothing. The fix is always the same: local presentation first, server confirmation second ([[Client Prediction and Reconciliation for Combat]]).

---

## 2. Input buffering

A buffer remembers a press for a short window and executes it as soon as the action becomes possible. It exists because humans press early: in a fast sequence, players start the next input before the current action ends, and a game that ignores early presses feels like it is eating inputs.

### Windows by action

| Action | Buffer window (rule of thumb) | Why that length |
|---|---|---|
| Jump (before landing) | 0.10 to 0.15 s | Longer feels like a jump you did not press |
| Light attack in a combo | 0.15 to 0.30 s | Players mash; too short loses combos, too long fires attacks after the player stopped |
| Dodge or roll | 0.10 to 0.20 s | Defensive; must feel immediate |
| Ability (keyboard or button) | 0.10 to 0.20 s | Similar to dodge |
| Interact (open, talk) | No buffer, or 0.1 s | Interactions on the wrong target are worse than a missed press |
| Menu toggles | No buffer | A buffered menu open after a fight is confusing |

The general rule: **the window is short enough that a buffered action never surprises the player**. If an attack fires half a second after the player stopped pressing, it is not a buffer; it is input lag.

### Semantics that matter more than the window

- **Buffer on press, not release.** Releases are 50 to 150 ms after presses for taps; buffering on release adds that much latency.
- **Consume once.** A buffered press fires at most one action, then is gone. Without this, one press can fire two attacks if two "can act" moments happen within the window.
- **Priority across actions.** If both an attack and a dodge are buffered when the player becomes free, dodge wins. Defensive actions outrank offensive ones (rule of thumb), because being hit while you pressed dodge is the most frustrating outcome in action games.
- **Last press within an action class wins.** For direction-sensitive actions (a dodge with a direction), use the latest direction, not the one at the moment of the press.
- **Clear on state change.** Death, stun, knock-up, opening a menu, starting a cutscene: all clear the buffer. A dodge buffered before being stunned must not fire when the stun ends 1.6 s later.
- **Hit-stop does not age the buffer unfairly.** During hit-stop, the game is visibly frozen; players keep pressing. Either pause buffer ageing during the stop or make sure the window is longer than your longest stop. With the reference project's maximum stop of about 89 ms ([[Hit Reactions Stagger and Hit-Stop]]), a 0.15 s attack window would lose more than half its length to a heavy hit-stop.

### A buffer module

```lua
--!strict
-- InputBuffer: remembers presses briefly and hands out the best allowed one when the character is free.
local InputBuffer = {}

export type Action = "Dodge" | "Ability" | "Attack" | "Jump"

local WINDOW: { [Action]: number } = {
	Dodge = 0.15,
	Ability = 0.15,
	Attack = 0.22,
	Jump = 0.12,
}

local PRIORITY: { [Action]: number } = {
	Dodge = 4,
	Ability = 3,
	Attack = 2,
	Jump = 1,
}

type Entry = { at: number, data: any }

local pressed: { [Action]: Entry } = {}
local frozenSince: number? = nil
local frozenTotal = 0 -- seconds of hit-stop to exclude from ageing

local function clock(): number
	-- Buffer age ignores time spent frozen in hit-stop.
	local now = os.clock()
	local frozen = frozenTotal
	if frozenSince then
		frozen += now - frozenSince
	end
	return now - frozen
end

function InputBuffer.press(action: Action, data: any?)
	pressed[action] = { at = clock(), data = data } -- last press wins (latest direction, etc.)
end

-- Call when hit-stop starts and ends.
function InputBuffer.setFrozen(frozen: boolean)
	if frozen and not frozenSince then
		frozenSince = os.clock()
	elseif not frozen and frozenSince then
		frozenTotal += os.clock() - frozenSince
		frozenSince = nil
	end
end

-- Returns the highest-priority live press among the allowed actions, and removes it.
function InputBuffer.consume(allowed: { [Action]: boolean }): (Action?, any)
	local now = clock()
	local best: Action? = nil
	local bestPriority = -1
	for action, entry in pressed do
		if now - entry.at > WINDOW[action] then
			pressed[action] = nil -- expired
		elseif allowed[action] and PRIORITY[action] > bestPriority then
			best = action
			bestPriority = PRIORITY[action]
		end
	end
	if best then
		local entry = pressed[best]
		pressed[best] = nil
		return best, if entry then entry.data else nil
	end
	return nil, nil
end

function InputBuffer.clear()
	table.clear(pressed)
end

return InputBuffer
```

The combat controller calls `InputBuffer.press` from its input handlers and, every frame (or at every "can act" moment), calls `consume` with the set of actions the current state allows. A recovery phase that allows only dodges passes `{ Dodge = true }`; a free state passes everything.

---

## 3. Cancel windows: where buffered inputs land

Buffering decides **whether** an early press survives; cancel windows decide **when** it comes out. An attack has phases:

| Phase | Typical share of a light attack (rule of thumb) | What can cancel it |
|---|---|---|
| Startup (wind-up) | 20 to 30% | Dodge, in forgiving designs; nothing in strict ones |
| Active (hit frames) | 10 to 20% | Nothing; the hit must resolve |
| Recovery (follow-through) | 50 to 70% | Next combo hit after the link point; dodge after a short lock |

A buffered attack fires at the **combo link** point, which [[Combat Combo Systems]] places on the pose the previous swing holds; a buffered dodge fires as soon as the recovery allows dodges. Two practical consequences:

- **Recovery is where feel lives.** Most of an attack's length is recovery, and it is the part players most want to cancel. Allowing dodge cancels after the active frames (often after a small lock of 0.1 to 0.15 s, rule of thumb) makes combat feel fluid without making attacks free.
- **Animation must support the cancel.** A dodge cancel from the middle of a big follow-through needs a blend that does not pop ([[Playback, Priorities and Blending]]). Short fades (0.05 to 0.1 s) are fine for dodges because they are fast motions; the motion hides the blend.

---

## 4. Coyote time on the default Humanoid

Coyote time lets the player jump for a short time after leaving a ledge. It exists because the player's sense of "I am on the platform" lags their character's position: they see the character at the edge and press jump, but the character stepped off a frame or two ago. Without it, players "fall off while pressing jump" and blame the controls. Typical window: 0.08 to 0.15 s (rule of thumb; the vault's controller note uses about 0.1 s).

### What makes it tricky on Roblox

- The default Humanoid only jumps from grounded states. Once it is in `Freefall`, setting `Humanoid.Jump` does nothing. A coyote jump has to force the jump, commonly with `Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)`, the same technique widely used for double jumps (community practice; not a documented guarantee, so test it on your rig and controller settings).
- **Not every `Freefall` is a ledge.** Walking down stairs or over small bumps can produce brief `Freefall` states. Coyote time quietly smooths these too, which is a feature: a jump pressed on a staircase works.
- **Not every airborne state should grant coyote.** After a jump (you already jumped), after knockback or a launch (you were thrown; a coyote jump would cancel the throw), while stunned or during a dash with its own physics.
- **`JumpRequest` can fire more than once for one press** on some input paths; the docs' own sample uses a debounce (Roblox docs, as of October 2026). The "jumped since grounded" flag below doubles as that debounce.

### Coyote time and jump buffering together

```lua
--!strict
-- CoyoteJump (LocalScript in StarterCharacterScripts): coyote time after leaving a ledge,
-- and a jump buffer that fires on landing if jump was pressed shortly before.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local COYOTE = 0.10 -- seconds after leaving the ground that a jump is still allowed
local BUFFER = 0.12 -- seconds before landing that a press is remembered

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local player = Players.LocalPlayer

local leftGroundAt = -math.huge
local jumpedSinceGrounded = false
local jumpPressedAt = -math.huge

local function blocked(): boolean
	-- Your own states that must not allow coyote or buffered jumps.
	return character:GetAttribute("Stunned") == true
		or character:GetAttribute("Launched") == true
		or character:GetAttribute("Dashing") == true
		or humanoid.Health <= 0
end

local function forceJump()
	jumpedSinceGrounded = true
	jumpPressedAt = -math.huge
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
	if new == Enum.HumanoidStateType.Jumping then
		jumpedSinceGrounded = true
	elseif new == Enum.HumanoidStateType.Freefall then
		-- Walked off something: start the coyote clock (not after a real jump).
		if old ~= Enum.HumanoidStateType.Jumping and not jumpedSinceGrounded then
			leftGroundAt = os.clock()
		end
	elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
		jumpedSinceGrounded = false
		leftGroundAt = -math.huge
		-- Buffered jump: pressed just before touching down.
		if os.clock() - jumpPressedAt <= BUFFER and not blocked() then
			task.defer(forceJump) -- after the state change finishes
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if player.Character ~= character or blocked() then
		return
	end
	local now = os.clock()
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall then
		if not jumpedSinceGrounded and now - leftGroundAt <= COYOTE then
			forceJump() -- coyote jump
		else
			jumpPressedAt = now -- remember for the landing
		end
	end
	-- Grounded presses are handled by the default controls.
end)
```

Edge cases this handles, and some it does not:

- **Coyote does not consume air-jump charges.** If you add double jumps, a coyote jump is a ground jump; refill logic in [[Custom Character Controllers]] (verify the ground with rays) still applies.
- **Holding jump on PC** already re-jumps on landing with the default controls (rule of thumb, observed behaviour), so the buffer mostly matters for taps on touch and gamepad. Test that a held key plus the buffer does not produce a double jump on your controls; the `jumpedSinceGrounded` flag should prevent it.
- **Server checks.** A coyote jump starts slightly below the ledge height. Server-side movement checks ([[Server Authority and Validation]]) need a tolerance for it, or they will flag your own forgiveness as an exploit.
- **Custom controllers** (a `ControllerManager` instead of Humanoid jumping) implement coyote time as a grounded flag with a grace timer, which is simpler; the logic is the same.

---

## 5. The forgiveness family

Coyote time is one member of a family of small, invisible kindnesses. They share a philosophy: **the game resolves ambiguity in the player's favour, as long as that never gives them an unfair advantage over another player**.

| Forgiveness | What it does | Typical size (rule of thumb) |
|---|---|---|
| Coyote time | Jump after leaving a ledge | 0.08 to 0.15 s |
| Jump buffer | Jump pressed before landing fires on landing | 0.10 to 0.15 s |
| Corner correction | A jump that clips a ceiling corner by a few studs is nudged around it | 0.3 to 0.6 studs |
| Ledge magnetism | A jump that falls just short of a platform edge is pulled on | 0.3 to 0.5 studs |
| Generous player hitboxes | Your attacks hit slightly beyond the visual | 10 to 20% larger |
| Strict enemy hitboxes | Enemy attacks hit slightly inside the visual | 10 to 20% smaller |
| Input-anchored parry | The parry window starts on the press, not the pose | From the reference project's guard design; see [[Hit Reactions Stagger and Hit-Stop]] |
| Aim assist | On touch and gamepad, a slight pull toward targets | Small; never on PvP between mixed input types without care |

Where forgiveness goes wrong:

- **PvP.** Generous hitboxes for everyone are not forgiveness; they are a range buff. In PvP, forgiveness should apply to environment interaction (jumps, ledges), not to hitting other players.
- **Mixed input fairness.** Aim assist that makes gamepad better than mouse at close range causes resentment. Scale it down when the target is another player.
- **Speedrun and obby communities** notice everything. Document forgiveness in an obby game's help or patch notes; hidden changes to jump windows break learned routes ([[Genre Playbook - Obbies and Platformers]]).

---

## 6. Touch and gamepad specifics

### Touch

- **Act on press for action buttons.** Many button events fire on release (a completed click). For gameplay buttons (attack, jump, ability), react to the press: `InputBegan` on the button, or a `ContextActionService` action, which receives `Enum.UserInputState.Begin`. Press-to-release time for a tap is often 50 to 150 ms (rule of thumb), all of which is added latency if you wait for the release. Keep release-to-act for menus, where it lets players slide off a button to cancel.
- **Bigger targets are faster.** Small buttons get missed and re-pressed; a missed press is a full second of lost responsiveness. Minimum targets are in [[Readable Text and UI Scale]] and [[Responsive UI for Phone Tablet Console and PC]].
- **Tap versus drag threshold.** A finger moves a few pixels during a tap. Treat movement under about 10 to 15 logical pixels as a tap, or camera drags will cancel button presses and vice versa (rule of thumb).
- **Multi-touch.** Players hold the thumbstick with one thumb and press attack with the other. Handle each `InputObject` separately; never read "the" touch position.

### Gamepad

- **Deadzones.** Sticks rest slightly off centre. A radial deadzone of about 0.15 to 0.2 on stick magnitude, with the remaining range rescaled to 0 to 1, keeps characters from drifting and keeps slow walking available (rule of thumb).
- **Trigger thresholds.** Analog triggers report a position; fire on crossing about 0.5 with a lower release threshold (about 0.3) to avoid chatter.
- **Input type changes.** `UserInputService.PreferredInput` (values `KeyboardAndMouse`, `Gamepad`, `Touch`, `MicroGamepad`) and `GetLastInputType` / `LastInputTypeChanged` tell you which input the player is using (Roblox docs, as of October 2026). Use it to switch prompts and to scale forgiveness (more aim assist for gamepad and touch).

See [[Input - UserInputService and ContextActionService]], [[Gamepad and Console UX]] and [[Input Remapping and One-Handed Play]] for the APIs and remapping.

---

## 7. The server side of buffered, early inputs

Buffering is client-side presentation and timing; the server still enforces the rules. The interaction creates a classic false positive: the client fires the next attack exactly when its cooldown ends **on the client**, and network jitter delivers that request to the server a little early relative to the previous request. A strict server cooldown rejects it, and the player sees an attack that animated but did nothing.

Rules that hold up (rule of thumb, consistent with [[Server Authority and Validation]]):

- **Grace on cooldowns.** Accept a request when at least about 85 to 90% of the cooldown has passed since the server received the previous one, or a fixed grace of about 50 to 100 ms. Exploiters gain at most that grace, which is too little to matter; real players stop losing attacks.
- **Track a rolling rate, not single intervals.** Over ten requests, the average interval must respect the cooldown. Jitter averages out; cheating does not.
- **Never trust client timestamps for gameplay.** Use them, if at all, only for diagnostics.
- **Reject quietly, and reconcile presentation.** If the server rejects, the client should not replay a "fail" animation after the fact (see [[Combat Sound Design and Feedback]] on correction sounds); the next valid action simply proceeds.

---

## 8. Measuring responsiveness

- **Frame-step a recording.** Record at 60 fps or higher (a phone filming the screen catches touch latency too), count frames from finger contact to first visible change. Over three frames at 60 fps is worth investigating.
- **Log swallowed inputs.** In a debug build, count presses that neither executed nor were buffered (pressed during a state that allows nothing). A high count in a specific state (for example, recovery of a heavy attack) points at a missing cancel window.
- **Log buffered execution delay.** Time from press to execution for buffered actions. A long tail (over 0.25 s) means windows are too long or priorities are wrong.
- **Ask the edge-of-platform question.** Watch new players on your hardest jump. If they fall while visibly pressing jump, coyote time is too short or not working.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Combos drop when players mash | No buffer, or window shorter than hit-stop plus reaction | Attack buffer 0.15 to 0.3 s; pause ageing during hit-stop |
| An attack fires after the player stopped | Window too long, or no consume-once | Shorter window; consume on use |
| Dodge loses to attack when both pressed | No priority | Defensive actions outrank offensive |
| Buffered dodge fires after a stun | Buffer not cleared on state change | Clear on stun, death, menus, cutscenes |
| "I pressed jump on the edge" | No coyote time | Coyote window on walk-offs only |
| Coyote jump after knockback cancels the launch | Coyote granted for every Freefall | Block coyote after launches and jumps |
| Phone buttons feel slow | Acting on release | Act on press for gameplay buttons |
| Attacks animate but do nothing on bad Wi-Fi | Strict server cooldown vs jittered arrival | Grace and rolling-rate checks |

## Checklist

- [ ] Every input produces a visible or audible response on the frame it is read.
- [ ] Nothing waits for a server reply before showing local feedback.
- [ ] Buffer windows per action; consume once; priorities; cleared on state changes.
- [ ] Buffer ageing paused during hit-stop, or windows longer than the longest stop.
- [ ] Cancel windows defined per attack phase; dodge cancels recovery after a short lock.
- [ ] Coyote time on walk-offs only; jump buffer on landing; both blocked in special states.
- [ ] Forgiveness favours the player against the environment, not against other players.
- [ ] Touch gameplay buttons act on press; tap and drag thresholds set; deadzones on sticks.
- [ ] Server cooldowns have a small grace and a rolling-rate check.

## Connected notes
<!-- auto-links:start -->
[[Input Buffering]] · [[Game Feel Start Here]] · 2D Collision Physics and Platformer Movement · Rate Limiting · Combat Animation Craft · Genre Playbook - Battlegrounds and Arena Fighters
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Input Buffering]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Anticipation]] · [[2D Collision Physics and Platformer Movement]] · [[Hold-to-Attack Input That Never Sticks]] · [[Combat Animation Craft]]
<!-- related:end -->
