---
tags: [systems, camera, shake, game-feel, accessibility, code]
---
# Camera Shake and Camera FX

<!-- tldr:start -->
> [!tldr] TL;DR
> - FOV ends up a degree off after a session: Exponential decays never reach 0 -> Finite envelopes ending at exactly 0
> - Effects fight sprint FOV: Two writers of FieldOfView -> One owner adds the stack's delta
> - Camera turns slightly after every dash: Look rotated in the offset, not undone -> Translation and roll only; undo before the module
>
> Cost: TL;DR ~130 tok · whole note ~4.1k tok. Read more: ## The envelope model · ## Trauma-based shake · ## Common mistakes
<!-- tldr:end -->

Short camera effects (a FOV punch on a dash, a dip on landing, a shake on a heavy hit, impact frames, a letterbox) are animation for the viewer. They multiply the weight of body animation for almost no cost, and they are the fastest way to make a game nauseating. This note gives a design that composes many effects safely, the measured numbers from one live action game (the reference project), trauma-based shake, reduced-motion rules, and the letterbox fix. Ownership of the camera (additive vs Scriptable) is in [[Cameras and Cutscenes]].

## The envelope model

Every effect is a **timed envelope**: it rises, maybe holds, and falls, and it **ends at exactly 0**. The system sums all live envelopes per channel, caps the totals, and applies the result additively.

| Channel | Unit | Reference cap |
|---|---|---|
| FOV | degrees added | 12 |
| Offset | studs of camera-space translation | 1.6 |
| Roll | degrees about the look axis | 4 |
| Blur | `BlurEffect.Size` | per effect |

Why these rules:
- **Ending at exactly 0** guarantees the camera returns to the player's base. Exponential decays never quite reach 0; after a few hundred effects the residue shows as a slightly wrong FOV. Use envelopes with a finite end, or snap to 0 below a threshold.
- **Summing with caps** handles overlap: a dash during a landing during a hit still stays inside 12 degrees of FOV.
- **Offset is translation plus roll only**, in camera space. The look direction is never touched, so there is no drift and the player's aim is never moved by an effect.
- **One owner per channel.** FOV in particular is written by many systems (sprint, zoom, abilities). In the reference project the effect stack exposes `Fov()` and the main character controller adds it into its own single FOV write; when that controller's FOV handling is off, the stack writes base plus offset itself. Two systems each tweening `Camera.FieldOfView` will fight every frame.

### Reference effect table

| Event | Effect |
|---|---|
| Dash | +9 FOV (0.06 s in, 0.25 s out), 0.7 stud kick along the dash, 2.5 degree roll, `BlurEffect` size 5 for 0.1 s; an existing 0.3 trauma dash shake kept |
| Jump | +3 FOV and a 0.35 stud lag (x0.6 for air and wall jumps) |
| Landing | A dip from 0.12 to 1.1 studs scaled by fall speed 45 to 140 studs/s (`k^2` where `k` is the normalised fall speed), FOV -2k, a mini shake past `k = 0.5`, not on slam landings (they have their own) |
| Combo finisher | 0.2 trauma shake |

Why `k^2` for landings: perceived impact grows faster than linearly with fall height, and squaring keeps small hops almost invisible while big falls land hard. The same idea is why shake uses trauma squared (below).

### When effects are off

- A player setting (Settings > Gameplay > Camera Effects).
- Only while the camera is `Custom` and following your own character.
- Off during cutscenes (`CutsceneLock`), station or menu locks, while downed, and while dead.
- First person: FOV only (offsets and roll in first person feel like the head is being shoved).

## Trauma-based shake

Shake from random offsets every frame looks like a broken camera. The widely used model (popularised in a GDC talk on juicing cameras, cited by the reference project's camera spec):

- Events add **trauma** (0 to 1). Trauma decays linearly over time.
- Shake amount is **trauma squared**, so small hits are subtle and big ones violent, and stacking hits ramps smoothly.
- Offsets come from **smooth noise** (Perlin, `math.noise`) sampled along time, one independent channel per axis, not from `math.random`.
- Shake is applied to the **render camera only**, never to gameplay aim.

Reference parameters for ultimates: noise at **16 Hz**, trauma decaying **1.45 per second**, base amplitude **2.6 degrees** times a per-tier factor (1.0 at the lowest tier up to 1.6 at the highest). Onlookers of someone else's ultimate get **0.3x** the trauma with distance falloff, full at 30 studs and zero at 150.

```lua
--!strict
-- CameraFX: envelopes + trauma shake, applied additively (see Cameras and Cutscenes for the undo/redo binding).
local CameraFX = {}

type Env = { t0: number, attack: number, hold: number, release: number,
	fov: number, offset: Vector3, roll: number }

local live: { Env } = {}
local trauma = 0
local DECAY = 1.45   -- trauma per second
local FREQ = 16      -- Hz, noise speed
local BASE_DEG = 2.6 -- max rotation at trauma 1
local CAP_FOV, CAP_OFFSET, CAP_ROLL = 12, 1.6, 4
CameraFX.reducedMotion = false

-- Add an envelope: rises over `attack`, holds, falls over `release`, then is exactly 0.
function CameraFX.pulse(attack: number, hold: number, release: number, fov: number?, offset: Vector3?, roll: number?)
	table.insert(live, { t0 = os.clock(), attack = attack, hold = hold, release = release,
		fov = fov or 0, offset = offset or Vector3.zero, roll = roll or 0 })
end

function CameraFX.addTrauma(amount: number)
	trauma = math.min(1, trauma + amount)
end

local function weight(e: Env, now: number): number?
	local t = now - e.t0
	if t < e.attack then return t / e.attack end
	t -= e.attack
	if t < e.hold then return 1 end
	t -= e.hold
	if t < e.release then
		local u = 1 - t / e.release
		return u * u -- ease out toward exactly 0
	end
	return nil -- finished
end

-- Call once per frame (from the apply render step). Returns FOV delta and a camera-space CFrame offset.
function CameraFX.step(dt: number): (number, CFrame)
	local now = os.clock()
	local fov, roll, offset = 0, 0, Vector3.zero
	for i = #live, 1, -1 do
		local e = live[i]
		local w = weight(e, now)
		if not w then
			table.remove(live, i)
		else
			fov += e.fov * w; roll += e.roll * w; offset += e.offset * w
		end
	end
	trauma = math.max(0, trauma - DECAY * dt)
	local shake = trauma * trauma
	local rx, ry, rz = 0, 0, 0
	if shake > 0 then
		local s = now * FREQ
		-- independent smooth noise per axis (math.noise is about -1..1 in practice)
		rx = math.noise(s, 0.1) * shake
		ry = math.noise(s, 10.1) * shake
		rz = math.noise(s, 20.1) * shake
	end
	if CameraFX.reducedMotion then
		-- reference rule for gameplay effects: FOV at half strength, nothing else
		return math.clamp(fov, -CAP_FOV, CAP_FOV) * 0.5, CFrame.identity
	end
	fov = math.clamp(fov, -CAP_FOV, CAP_FOV)
	if offset.Magnitude > CAP_OFFSET then offset = offset.Unit * CAP_OFFSET end
	roll = math.clamp(roll, -CAP_ROLL, CAP_ROLL)
	local deg = math.rad(BASE_DEG)
	local cf = CFrame.new(offset)
		* CFrame.Angles(rx * deg, ry * deg, math.rad(roll) + rz * deg)
	return fov, cf
end

return CameraFX
```

Note the shake **does** rotate pitch and yaw, unlike the envelope offsets. That is fine because it is zero-mean noise applied through the undo/redo binding: it is removed every frame before the camera module reads the camera, so it cannot accumulate into a turn.

Usage for the reference dash: `CameraFX.pulse(0.06, 0, 0.25, 9, Vector3.new(0, 0, -0.7), 2.5)` plus a 0.1 s blur; for a finisher `CameraFX.addTrauma(0.2)`.

## Hit-time effects: punch, kick, impact frames

The ultimate camera's climax sequence (reference spec) is a good template for any big hit:

1. **Hit-stop** starts on the mark (`0.03 + 0.045 x strength` seconds; see [[Hit Reactions Stagger and Hit-Stop]]).
2. **Impact frames** play inside the hit-stop: 1 or 2 frames of a high-contrast or negative image, at 1/30 s per frame (at least one rendered frame).
3. The **FOV kick** lands at half the hit-stop and springs back over 0.5 s with a small overshoot.
4. The **shake starts when the freeze lets go**. Shaking during a freeze makes the freeze unreadable.
5. A **blur pulse** after the impact frames (exponential with a 0.09 s e-folding time).
6. A **colour punch** (saturation plus a tint of the weapon's colour) decaying over 0.35 s.

Game-feel practice behind it: 50 to 100 ms of hit-stop with flash, shake and sound stacked inside about 100 ms; exaggerate briefly and return to rest; scale feedback with the event's importance. Ordering matters as much as amplitude.

Impact frames are cheap in Roblox: a full-screen `Frame` (white, or an `ImageLabel` with a negative-looking texture) shown for one or two frames, or a `ColorCorrectionEffect` with high contrast and negative saturation toggled on and off. Never more than 2 frames; anything longer is a strobe.

## Reduced motion

Roblox exposes the user's preference as `GuiService.ReducedMotionEnabled` (read-only). Respect it, plus your own setting. The reference rules differ by system, which is a reasonable pattern:

| System | Under reduced motion |
|---|---|
| Gameplay camera FX | FOV changes at 0.5x only; no offsets, roll or shake |
| Ultimate camera | No impact frames, no blur, 0.3x shake, 0.25x kick, 0.5x FOV moves |
| Hit-stop and impact flash on abilities | Off |
| UI idle animations | Static poses (see [[UI and GUI Animation]]) |

Rule of thumb: keep **information** (an ultimate is happening, you landed hard) and remove **motion**. A brief FOV change carries information with little vestibular cost; shake and roll are the main nausea sources.

## Ultimates: additive package numbers

The reference ultimate camera is additive on the caster's camera (never Scriptable for onlookers) with per-rarity tiers. Its full tier table lives in [[Cinematic Ultimates]]. The parts relevant here:
- OPEN: FOV punch in over 0.12 s (ease out), held to the `Open` mark (usually about 0.21 s, clamped 0.15 to 0.6), then over 0.55 s the widen, dolly back and lift, orbit bias toward the anchor and a partial aim.
- The bias yields up to 65% while the player turns the camera faster than 40 degrees per second, fades out when the target is behind the camera, and is halved under shift-lock.
- FOV is clamped to 35 to 105 overall.
- Restore: 0.3 s ease home if the clip stops early, at once on death, respawn or another script taking the camera, 0.2 s on weapon change or a new ultimate. Verified end state equals the player's camera exactly.

## The letterbox fix

Letterbox bars are two black frames sliding in from top and bottom. On phones they drifted, were inset, or scaled out of place. The fix that held:

```lua
local bars = Instance.new("ScreenGui")
bars.Name = "Letterbox"
bars.IgnoreGuiInset = true
bars.ScreenInsets = Enum.ScreenInsets.None                       -- draw to the true screen edges
bars.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None     -- the project notes call this "Off"
bars.ClipToDeviceSafeArea = false
bars.DisplayOrder = 50 -- under the HUD for additive ultimates; raise it for full cutscenes
bars:SetAttribute("SkipAutoScale", true) -- your own UI auto-scaler must ignore the bars
bars.Parent = game:GetService("Players").LocalPlayer.PlayerGui

local function bar(anchorY: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, anchorY)
	f.Position = UDim2.fromScale(0, anchorY)
	f.Size = UDim2.fromScale(1, 0) -- tween the Y scale to e.g. 0.1 to show
	f.Parent = bars
	return f
end
local top, bottom = bar(0), bar(1)
```

Bar height by tier in the reference: 3.5% to 7.5% of the screen for the additive package, 9.5% to 12% in the caster cutscene. When the bars appear with a FOV change, compensate FOV so the subject does not shrink.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| FOV ends up a degree off after a session | Exponential decays never reach 0 | Finite envelopes ending at exactly 0 |
| Effects fight sprint FOV | Two writers of FieldOfView | One owner adds the stack's delta |
| Camera turns slightly after every dash | Look rotated in the offset, not undone | Translation and roll only; undo before the module |
| Shake during hit-stop | Shake starts on the hit | Start shake when the freeze ends |
| Nausea complaints | Roll and shake on every action | Caps, settings, reduced motion |
| Letterbox wrong on phones | Safe-area insets and auto-scaler | `ScreenInsets.None`, compatibility None, no clipping, skip scaler |

See also: [[Cameras and Cutscenes]], [[Cinematic Ultimates]], [[Hit Reactions Stagger and Hit-Stop]], [[Snippets - Camera Shake and FX]], [[UI and GUI Animation]].

## Nuances and edge cases

The companion note [[Snippets - Camera Shake and FX]] covers implementation edge cases (frame rate, bind order, blur cost). These are the design-level ones.

1. **Shake on the victim is a gameplay penalty.** In PvP, shaking the screen of the player who was hit makes it harder for them to react. A little reads as impact; a lot is a stun the designer did not intend. If a move should disorient, make that an explicit, balanced effect; otherwise keep victim shake small and short (well under the attacker's).
2. **Competitive players turn it off.** If shake can be disabled, top players will disable it, so it must never carry information they need (for example, the only cue that a big attack is coming). Pair every shake with a sound and a visual in the world.
3. **Onlookers and scale.** In a 2-player duel, onlooker shake is irrelevant. In a 50-player arena, each player is an onlooker to dozens of events per minute. Onlookers should feel only rare, large events (ultimates, boss slams), and with distance falloff; otherwise the screen never rests.
4. **Session fatigue.** A shake that feels great in a 5-minute test can be exhausting in a 45-minute session. Test feel with long sessions, and expect to reduce intensity after the first playtests rather than increase it.
5. **Content creators.** Video creators often like strong camera effects because they read on small phone screens in short-form video. That pressure pushes toward more shake. Resist it in the default and offer a "cinematic" or "intense" preset instead, so the default stays comfortable.
6. **Controller rumble.** On gamepad, rumble can replace much of the shake. Roblox exposes rumble through `HapticService` (Roblox docs (as of October 2026) list motor control for gamepads; support on phones and other devices varies, so check `IsVibrationSupported` and `IsMotorSupported` before relying on it). Rumble should follow the same envelope and the same caps, and respect the same settings toggle.
7. **Spectators and replays.** Spectating another player's camera with their shake applied is uncomfortable. Spectator cameras should get onlooker-level effects, not the victim's or attacker's.
8. **Low-end and readability.** At 20 to 30 FPS, shake becomes stepping and FOV punches become jumps. On low graphics quality, scale shake amplitude down rather than up; the effect reads worse, not better, when choppy.

## Common mistakes in production

1. **Victim shake as strong as attacker shake.** Symptom: PvP players complain about being stunlocked by the camera. Fix: separate presets for attacker, victim and onlooker.
2. **Shake as the only cue.** Symptom: players with shake disabled miss attacks. Fix: always pair with sound and world VFX.
3. **Settings that only affect some effects.** Symptom: "I turned shake off but my screen still moves." Fix: every camera effect reads the same settings module.
4. **Rumble without a cap.** Symptom: controllers buzz constantly in crowded fights. Fix: sum and cap rumble like shake, and keep it for the local player's own actions and hits.
5. **Tuning on a high-end PC only.** Symptom: on phones effects look jerky and overwhelming. Fix: tune on a mid phone at 30 FPS as well.

## Related decisions

- [[Hit-Stop and Screen Shake Tuning by Numbers]]: numeric presets per hit tier.
- [[Feedback Timing - Sound Visual and Haptic Sync]]: putting shake, sound and rumble on the same frame.
- [[Motion Sensitivity and Camera Comfort]]: comfort limits and settings design.
- [[Difficulty Options and Cognitive Load]]: treating intense feedback as an option rather than a default.
- [[Genre Playbook - Shooters FPS and TPS]]: why aim-affecting shake is especially costly in shooters.
- [[Combat Sound Design and Feedback]]: the audio half of impact.
- [[Short-Form Video Marketing]]: the pull toward intense effects for clips, and how to serve it without hurting players.
- [[Juice on a Budget - Mobile and Low-End]]: scaling effects down on weak devices.

## Connected notes
<!-- auto-links:start -->
[[Camera Systems]] · [[Game Feel Start Here]] · [[Hit-Stop]] · [[Game Feel and Juice]] · [[Custom Character Controllers]] · [[Links - Cameras]] · [[Animation Start Here]]
<!-- auto-links:end -->
