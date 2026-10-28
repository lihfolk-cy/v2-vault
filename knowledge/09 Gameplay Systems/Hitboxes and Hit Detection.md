---
tags: [gameplay, combat, hitbox, hit-detection, latency, server-authority]
---
# Hitboxes and Hit Detection

Hit detection decides whether a swing, shot or spell touched something. On Roblox it is shaped by one hard fact: the attacker, the victim and the server all see slightly different worlds, because each player's character is simulated on their own client and arrives at others 100 to 300 ms late. Every design is a trade between **feel** (the attacker's screen is right), **fairness** (the victim's screen is right) and **security** (the server's view is right). This note lays out the techniques, how to time hits on the server, how to handle latency, and how one production game did melee for players and telegraphed attacks for enemies.

Architecture around this: [[Combat Systems Architecture]]. Queries: [[Raycasts Shapecasts and Spatial Queries]]. Animation side: [[Weapon Swing Design]], [[Markers and Events]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. Techniques

| Technique | How | Good | Bad |
|---|---|---|---|
| `Touched` on the weapon | Physics contact events | Zero code | Misses fast swings, fires on the owner's machine, client can fake it (Docs), double hits |
| Part hitbox + overlap | A box/sphere at the hit moment, `GetPartsInPart` or bounds query | Simple, predictable, designer-tunable | One instant: a long swing needs several samples |
| Query shape from data | No part: a CFrame and size from data, queried at the hit time | No instances, server-friendly, the same shape drives telegraphs | Must keep data in sync with animation |
| Raycast "blade" | Rays from points along the blade, from last frame's to this frame's positions | Matches the visual arc exactly | Needs the animated blade where the query runs (client, or server with animation) |
| Sweep (Blockcast/Spherecast/Shapecast) | Move a shape along the swing path | Catches fast motion | Misses targets the shape starts inside (Docs) |
| Pure maths | Distance and angle checks against a list of bodies | Fastest, no filtering issues | Only for simple shapes (cones, circles, capsules) |

**Rule of thumb.** For melee in an action game, the most robust choice is **shape from data, queried on the server at the hit time**, with the client doing an identical query for instant feedback. Never use `Touched` for damage.

### Cone check (the cheapest melee hitbox)
Most melee swings are well approximated by "within reach and within an angle of facing":

```lua
--!strict
local function inCone(origin: CFrame, targetPos: Vector3, reach: number, halfAngleDeg: number, bodyRadius: number): boolean
	local offset = targetPos - origin.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local dist = flat.Magnitude
	if dist > reach + bodyRadius then
		return false
	end
	if dist < bodyRadius then
		return true -- overlapping the attacker: always in front enough
	end
	local look = origin.LookVector * Vector3.new(1, 0, 1)
	local cosA = look.Unit:Dot(flat / dist)
	-- widen the cone by the angle the target's body subtends
	local extra = math.deg(math.asin(math.clamp(bodyRadius / dist, 0, 1)))
	return cosA >= math.cos(math.rad(halfAngleDeg + extra))
end
```

Add a vertical check (`math.abs(offset.Y) <= height`) so you cannot hit enemies on a balcony above.

---

## 2. Where the hit is decided

| Model | Flow | Feel | Security |
|---|---|---|---|
| Client authoritative | Client detects, tells server "I hit X" | Perfect for attacker | Exploitable unless heavily validated |
| Server authoritative | Client says "I swung"; server detects at hit time | Victim and attacker both see server truth, attacker sees lag | Strong |
| Hybrid (common) | Client detects for instant feedback; server re-checks with tolerance | Good | Good if validation is strict |

### Hybrid validation (server)
When the client claims a hit, the server checks:
1. **Rate:** this swing was allowed (cooldown, combo pacing; see section 3).
2. **Existence:** the target exists, is alive, is hittable (not in an i-frame, not a tutorial-protected enemy, same zone).
3. **Reach:** the target is within reach plus a latency allowance. Use the server's positions, widened by `targetSpeed * latency` for the victim and a little slack for the attacker.
4. **Line of sight:** no wall between them (a ray, ignoring both characters).
5. **One hit per target per swing:** the server keeps the set of targets already hit by swing id.

Reach tolerance is the main tuning knob. Too tight: "my hits don't register" complaints on mobile connections. Too loose: reach hacks. Rule of thumb: allow `reach + 4 studs + speed * 0.2 s` and log claims beyond `reach + 2`, so you can see real distributions before tightening.

---

## 3. Server hit timing from data

If the server decides hits, it must know *when* the blade connects. The client sends "swing N started"; the server waits until the hit time and queries then.

**Measured.** The reference project stores a hit time per swing segment: a sword chain hits at 0.20 / 0.20 / 0.217 / 0.367 s into each swing (the last is a finisher lunge), a katana chain at 0.217 / 0.217 / 0.20 / 0.383. These numbers equal the time of the `Hit` marker in each animation; a dry-run test asserts `chain hit time == Hit marker time` for every clip, so retiming an animation without updating data fails a test instead of shipping a desync. A later swing rework set swings of 0.42 / 0.42 / 0.47 / 0.62 s with hits at 0.20 / 0.20 / 0.23 / 0.30.

```lua
--!strict
-- Server: schedule the hit query for a swing the client reported.
type SwingDef = { hitTime: number, reach: number, halfAngle: number, damageMult: number }

local SWINGS: { SwingDef } = {
	{ hitTime = 0.20, reach = 9, halfAngle = 60, damageMult = 1.0 },
	{ hitTime = 0.20, reach = 9, halfAngle = 60, damageMult = 1.0 },
	{ hitTime = 0.23, reach = 9, halfAngle = 70, damageMult = 1.1 },
	{ hitTime = 0.30, reach = 11, halfAngle = 90, damageMult = 1.6 },
}

local function onSwing(player: Player, segment: number, resolve: (Player, SwingDef) -> ())
	local def = SWINGS[segment]
	if not def then return end
	-- The client started the swing about half a round trip ago; shorten the wait by
	-- an estimate of that so the server query lands close to the client's hit frame.
	local rtt = player:GetNetworkPing() -- round trip, seconds (Docs)
	local oneWay = math.clamp(rtt / 2, 0, 0.25)
	task.delay(math.max(0, def.hitTime - oneWay), resolve, player, def)
end
```

`Player:GetNetworkPing()` "returns the round-trip, isolated network latency of the player in seconds" (Docs), so halve it for the one-way estimate, and clamp it so a lagging client cannot claim enormous compensation.

### Pacing without refusing input
The server must stop autoclickers from swinging faster than the animation allows, but a naive cooldown check drops legitimate inputs that arrive bunched together after a lag spike. **Measured.** The reference project's swing guard uses a **bank**: each swing deposits its minimum interval; the next swing waits for the difference instead of being refused. A swing whose hit is later than the previous one makes the next click wait for the hit difference. In dry runs it refused 0 of 24 legitimate sequences at cooldowns of 0.38, 0.55 and 0.68 s, while capping the rate. Minimum gap between chain links was 0.42 s.

A token bucket per player per action implements the same idea ([[Rate Limiting and Abuse Prevention]]).

---

## 4. Latency: whose screen is right?

Suppose the attacker has 120 ms ping and the victim 80 ms. When the attacker's client sees the victim, it sees where the victim was roughly 200 ms ago plus interpolation. A server that checks the victim's *current* position will reject hits the attacker clearly landed.

Options:
- **Tolerance** (widen reach by the victim's speed times latency). Simple; good enough for melee against NPCs and most PvE.
- **Rewind (lag compensation).** The server keeps a short position history per character and checks the hit against the victim's position at "now minus the attacker's latency minus interpolation delay". Standard in shooters; costs memory and complexity.
- **Favour the victim.** For dodges and parries, the victim's input timing matters more; widen i-frames rather than rewinding.

```lua
--!strict
-- Server position history for rewind (per character root), sampled each Heartbeat.
local RunService = game:GetService("RunService")

local HISTORY_SECONDS = 1
type Sample = { t: number, pos: Vector3 }
local history: { [BasePart]: { Sample } } = {}

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for root, samples in history do
		if not root.Parent then
			history[root] = nil
			continue
		end
		table.insert(samples, { t = now, pos = root.Position })
		while #samples > 0 and now - samples[1].t > HISTORY_SECONDS do
			table.remove(samples, 1)
		end
	end
end)

local function track(root: BasePart)
	history[root] = {}
end

local function positionAt(root: BasePart, t: number): Vector3
	local samples = history[root]
	if not samples or #samples == 0 then return root.Position end
	for i = #samples, 2, -1 do
		local a, b = samples[i - 1], samples[i]
		if a.t <= t and t <= b.t then
			local alpha = (t - a.t) / math.max(b.t - a.t, 1e-6)
			return a.pos:Lerp(b.pos, alpha)
		end
	end
	return if t < samples[1].t then samples[1].pos else samples[#samples].pos
end

return { track = track, positionAt = positionAt }
```

`table.remove(samples, 1)` is O(n); for many characters use a ring buffer ([[Luau Performance and Native Codegen]]). Cap rewind at about 250 ms so high-ping players cannot hit people who are long gone.

---

## 5. Enemy attacks on players: telegraphs and shapes

Enemies are server-owned; players are client-owned. When an enemy swings, the server checks against the player's position as the server sees it, which is behind where the player sees themselves. Players perceive this as "I dodged and still got hit". The defences:

- **Telegraph every attack** with a ground marker or wind-up that shows the exact shape and the moment it lands. Players dodge the marker, not the animation.
- **Generous dodge windows.** **Measured:** the reference project gives a dash 0.40 s of immunity against boss-class attacks from the server's `dashAt`, and enforces that boss warnings and combo links are at least 0.5 s and follow markers lock at least 0.45 s before the blow, so a dash on the player's screen is still in time on the server's.
- **One hit-shape source.** The reference project keeps hit shapes (circles, cones, lines, rings) in a shared module used by both the server's hit test and the client's telegraph markers. The marker you see is literally the shape that is tested.
- **Hit timing from markers or data.** Enemy hits fire on the clip's `KeyframeMarker` when the clip is known; placeholder rigs without clips use data mark times. Either way the server, the telegraph and the animation share one time.
- **Telegraph tokens.** To stop many enemies hitting at once, enemies take a token from a small pool before a telegraphed attack (the reference project used budgets such as 3 normal, 1 gold, 1 blue, swarms counting 0.5). Fewer simultaneous telegraphs = readable fights ([[NPC AI and Behaviour]]).

```lua
--!strict
-- Shared shape test used by the server's hit check and the client's marker builder.
export type Shape =
	{ kind: "circle", radius: number }
	| { kind: "cone", radius: number, halfAngle: number }
	| { kind: "line", length: number, width: number }

local Shapes = {}

function Shapes.contains(shape: Shape, origin: CFrame, point: Vector3, bodyRadius: number): boolean
	local l = origin:PointToObjectSpace(point)
	local flat = Vector3.new(l.X, 0, l.Z)
	if shape.kind == "circle" then
		return flat.Magnitude <= shape.radius + bodyRadius
	elseif shape.kind == "cone" then
		if flat.Magnitude > shape.radius + bodyRadius then return false end
		if flat.Magnitude < 1e-3 then return true end
		local angle = math.deg(math.acos(math.clamp(-l.Z / flat.Magnitude, -1, 1))) -- -Z is forward
		return angle <= shape.halfAngle
	else
		return -l.Z >= -bodyRadius and -l.Z <= shape.length + bodyRadius
			and math.abs(l.X) <= shape.width / 2 + bodyRadius
	end
end

return Shapes
```

---

## 6. Ability hitboxes

Abilities usually hit areas rather than swings. **Measured.** The reference project's ability targeting returns targets whose distance is within `max(11, 1.5 * r) + 2 + bodyRadius` of the cast point (it was `1.35 r` before a pass that measured coverage) plus a short capsule 0.15 s ahead of a moving caster, because a caster travelling during the cast otherwise left the circle behind. Measured coverage of "enemies visually inside the effect that took damage" rose from 93.7% to 97.5%.

Lessons:
- Measure coverage: record what the VFX covered and what took damage, and compare. Visual radius and hit radius drift apart quietly.
- Include body radius. A large enemy whose root is just outside the radius but whose body is clearly inside should be hit.
- Lead moving casters.
- Clamp enemy travel on aim assist to the aimed target, so a lunge does not overshoot.

---

## 7. Feedback: make hits feel instant even when decided later

When the server decides, the attacker's client still needs instant feedback:
- Play the swing, trail, whoosh immediately.
- Run the same shape query locally at the hit frame and play a **provisional** impact (spark, sound, small hit-stop) on what it finds.
- Show damage numbers and kills only when the server confirms.

Players forgive a damage number that appears 100 ms late; they do not forgive a swing that waits for the server to start. See [[Hit Reactions Stagger and Hit-Stop]] and [[Game Feel and Juice]].

---

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `Touched` sword | Random misses and double hits | Query at hit time |
| Damage per part hit | 15x damage on R15 | Dedupe by model per swing |
| Trusting client damage numbers | One-shot exploits | Server computes damage from server stats |
| Server waits full hit time after receipt | Hits land late | Subtract clamped one-way latency |
| Refusing bunched inputs | "My clicks get eaten" after lag | Bank pacing |
| Telegraph and hit shapes differ | "It hit me outside the circle" | One shared shape module |
| Animation retimed, data not | Hits before or after the blade | Test that data hit time equals marker time |
| Unbounded rewind | Hits on players long gone | Cap at about 250 ms |

## Checklist
- [ ] Hit shapes defined in data and shared by server, client feedback and telegraphs.
- [ ] Server hit time derived from the animation markers, enforced by a test.
- [ ] Reach validation with logged distances and latency tolerance.
- [ ] One hit per target per swing id.
- [ ] Dodge windows tuned for the server's late view of the player.
- [ ] Coverage measured for area abilities.

## See also
[[Combat Systems Architecture]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Weapon Swing Design]] · [[Markers and Events]] · [[Combat Combo Systems]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Server Authority and Validation]] · [[Exploits and Anti-Cheat]]

## Connected notes
<!-- auto-links:start -->
[[Detecting Combat Exploits - Reach Rate and Aim]] · [[Melee Combat System End to End]] · [[Combat Animation Craft]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Client Prediction and Reconciliation for Combat]] · [[Anticipation]]
<!-- auto-links:end -->
