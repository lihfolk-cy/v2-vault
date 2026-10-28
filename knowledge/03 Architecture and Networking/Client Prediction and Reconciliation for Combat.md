---
tags: [networking, combat, prediction, latency, reconciliation, server-authority]
---
# Client Prediction and Reconciliation for Combat

<!-- tldr:start -->
> [!tldr] TL;DR
> - Own animations, sounds and VFX start on input, never after a round trip.
> - Every predicted action carries a sequence number; the server answers with the last processed one.
> - Displayed resources = server value + unconfirmed predictions, recomputed on each answer.
> - Server cooldowns have a small tolerance; cooldown ends are sent in server time.
> - Rejections roll back quietly; rejection rates are measured.
> - Rules (costs, cooldowns, shapes) live in one shared module.
>
> Read more (21 KB note): ## 3. Sequence numbers: the backbone of reconciliation · ## 9. The engine's server authority model · ## Checklist
<!-- tldr:end -->

Every combat game on Roblox lives with a round trip of roughly 50 to 300 ms between a player's input and the server's verdict. If the client waits for the server before showing anything, combat feels like wading through mud. If the client decides everything, exploiters decide everything. Prediction is the middle path: the client **shows** the likely result immediately, the server **decides** the real one, and reconciliation makes the two agree without the player noticing.

This note covers what to predict in melee and ability combat (and what never to predict), the sequence-number pattern that makes reconciliation exact, predicting resources and cooldowns, rejecting gracefully, projectiles, movement abilities, testing under lag, and the engine's own server authority model with prediction and rollback. Hit validation and rewind basics live in [[Hitboxes and Hit Detection]]; the damage pipeline in [[Combat Systems Architecture]].

Facts about the server authority model come from the Roblox docs page "Server authority model" and the DevForum full-release announcement (as of October 2026). Numbers marked measured come from the reference project.

---

## 1. Vocabulary

| Term | Meaning in a Roblox combat game |
|---|---|
| **Prediction** | The local client applies the expected effect of its own input before the server confirms it |
| **Reconciliation** | When the server's answer arrives, the client corrects its predicted state to match, replaying anything still unconfirmed |
| **Interpolation** | Showing remote entities (other players, NPCs) slightly in the past, smoothly between received states. The engine does this for replicated physics |
| **Extrapolation** | Guessing where a remote entity is now from its last velocity. Cheap, wrong on direction changes |
| **Lag compensation (rewind)** | The server checks a hit against where the target was when the attacker saw it |
| **Authority** | Who decides the final value. In classic Roblox, the server decides game state, but your own character's physics is simulated by your client |

The classic Roblox model is unusual: your **own character's movement is already client-authoritative physics** (the player always owns their character, see [[Network Ownership]]). So movement "prediction" comes for free, and the hard part is everything else: abilities, resources, hits, cooldowns and enemy reactions. The server authority model (section 9) changes this.

---

## 2. What to predict, what to confirm, what never to predict

| Effect | Predict locally? | Why |
|---|---|---|
| Own swing or cast animation, sound, trail | Yes, always | Pure presentation; delaying it is the number one cause of "laggy" feel |
| Own cooldown UI starting | Yes | Server will almost always agree; a rare correction is fine |
| Own resource spend (stamina, mana, ammo) | Yes, with reconciliation | Players notice bars that lag; the server value is authoritative |
| Hit spark and hit sound on the target | Yes (cosmetic) | Instant feedback; the server can still reject damage |
| Damage number | Usually wait, or show provisional | A number that later "didn't happen" erodes trust; see section 6 |
| Target health bar drop | Optional, short-lived | Predict for PvE feel; reconcile fast |
| Enemy flinch / stagger animation | Rarely | Wrong flinches look like bugs; tie to server confirmation |
| Knockback of others | No | You do not own them; prediction fights replication |
| Kills, deaths, loot, currency, XP | Never | Value and fairness; always server-confirmed |
| Your own dash or movement ability | Yes (you own the character) | The server validates distance afterwards |

The general rule: **predict what is local and cosmetic, reconcile what is numeric and yours, and never predict outcomes that involve other players' state or value.**

---

## 3. Sequence numbers: the backbone of reconciliation

Without ids, the client cannot tell which server answer belongs to which input, especially when the player presses quickly and answers arrive late or out of order. Give every predicted action a client-side sequence number.

**Client side:**

```lua
--!strict
-- Client: PredictedActions module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CastRemote = Remotes:WaitForChild("Cast") :: RemoteEvent
local CastResult = Remotes:WaitForChild("CastResult") :: RemoteEvent

type Pending = {
	seq: number,
	abilityId: string,
	cost: number,          -- predicted resource spend
	sentAt: number,
	rollback: () -> (),    -- undo presentation if rejected
}

local nextSeq = 0
local pending: { Pending } = {}         -- ordered by seq
local confirmedMana = 100                -- last value the server told us
local onManaChanged: (number) -> () = function(_) end

local function predictedMana(): number
	local m = confirmedMana
	for _, p in pending do
		m -= p.cost
	end
	return m
end

local function cast(abilityId: string, cost: number, play: () -> (() -> ())): boolean
	if predictedMana() < cost then
		return false -- client-side check for UX only; the server checks again
	end
	nextSeq += 1
	local rollback = play() -- starts animation/VFX now; returns an undo function
	table.insert(pending, {
		seq = nextSeq, abilityId = abilityId, cost = cost,
		sentAt = os.clock(), rollback = rollback,
	})
	CastRemote:FireServer(nextSeq, abilityId)
	onManaChanged(predictedMana())
	return true
end

-- Server answers: (lastSeq, accepted, authoritativeMana)
CastResult.OnClientEvent:Connect(function(seq: number, accepted: boolean, mana: number)
	confirmedMana = mana
	-- drop everything the server has processed up to and including seq
	local i = 1
	while i <= #pending do
		local p = pending[i]
		if p.seq <= seq then
			if p.seq == seq and not accepted then
				p.rollback()
			end
			table.remove(pending, i)
		else
			i += 1
		end
	end
	onManaChanged(predictedMana()) -- server value plus still-unconfirmed spends
end)

return {
	cast = cast,
	setManaListener = function(fn: (number) -> ()) onManaChanged = fn end,
}
```

**Server side:**

```lua
--!strict
-- Server: authoritative cast handling (validation details trimmed)
local lastSeq: { [Player]: number } = {}

CastRemote.OnServerEvent:Connect(function(player: Player, seq: unknown, abilityId: unknown)
	if typeof(seq) ~= "number" or seq ~= seq or seq % 1 ~= 0 then return end
	if typeof(abilityId) ~= "string" or #abilityId > 32 then return end
	if not limiter:allow(player) then return end

	local prev = lastSeq[player] or 0
	if seq <= prev then return end          -- duplicate or replayed
	lastSeq[player] = seq

	local accepted = tryCast(player, abilityId) -- checks cooldown, mana, state; spends mana
	CastResult:FireClient(player, seq, accepted, getMana(player))
end)

Players.PlayerRemoving:Connect(function(player) lastSeq[player] = nil end)
```

Why this works:

- The displayed value is **server value + unconfirmed predictions**, recomputed on every answer. There is no drift: each answer resets the base.
- Out-of-order answers are harmless because the server processes in order (reliable `RemoteEvent`s from one client arrive in order, see [[RemoteEvents RemoteFunctions and Unreliable Remotes]]) and each answer carries the last processed sequence.
- Rejections roll back exactly the action that failed.
- Replays and duplicates are dropped by the monotonic sequence check. Note that an exploiter can still choose sequence numbers; the check prevents replays, not cheating. All value checks remain in `tryCast`.

**Reset sequence state on respawn or reconnect** if your game resets resources on death. A stale `pending` list after a respawn produces a wrong bar until the next answer.

**Mana regenerates.** If a resource regenerates over time, the client should simulate regeneration on top of `confirmedMana` using the same formula as the server and a shared clock (`workspace:GetServerTimeNow()`), and the server should send its value together with the server time it was computed at. Otherwise the bar visibly snaps back every answer.

---

## 4. Cooldowns under latency

A cooldown has two clocks: the client's (starts when the button is pressed) and the server's (starts when the request arrives, about half a round trip later). Problems:

- **Client-faster-than-server rejection.** The client's cooldown ends; the player presses; the request arrives at the server slightly before the server's cooldown ends because the previous request took longer to arrive than this one (jitter). The server rejects an honest input.
- **Bunching after a lag spike.** Several inputs queued on a stalled connection arrive together.

Fixes:

1. **Tolerance.** Enforce the cooldown at a fraction of its authored value on the server. **Measured:** the reference project enforces ability cooldowns at 0.95x the authored value for latency jitter ([[Rate Limiting and Abuse Prevention]]). For a 6 s cooldown that allows a 0.3 s early arrival, which covers jitter without meaningful advantage.
2. **Banking instead of refusing.** For rapid melee chains, queue an early input and execute it when allowed instead of rejecting it. **Measured:** the reference project's swing guard banks each swing's minimum interval and refused 0 of 24 legitimate sequences in dry runs while capping the rate ([[Hitboxes and Hit Detection]]).
3. **Server-timestamped cooldown end.** Send `readyAt` in server time (`GetServerTimeNow`), and let the client display against the same clock. Do not send durations; durations drift by the one-way latency.

---

## 5. Rejecting gracefully

When the server says no, the client has already played something. Options, from least to most visible:

| Situation | Rollback |
|---|---|
| Rejected before the hit frame | Cut the animation with a short fade, play a "fizzle" sound, refund the predicted cost, clear the cooldown UI |
| Rejected after the hit frame | Let the animation finish; suppress damage numbers; do not replay anything |
| Rejected because the player is stunned or dead | Snap to the server state; the stun animation explains it |
| Rejected for rate limit | Do nothing visible (honest clients should never hit it) |

Do not show error text for normal rejections. A brief cooldown flash on the button is enough. If players see fizzles often, the prediction is wrong (client and server disagree on rules); fix the shared rules, not the rollback.

**Shared rules module.** The cheapest way to keep mispredictions rare is one ModuleScript in ReplicatedStorage with the pure rule functions (cost, cooldown, range, can-cast-in-state) that both sides call. The server is still authoritative; the client copy exists so predictions match. **Measured:** the reference project keeps hit shapes in one shared module used by the server's hit test and by the client's telegraph markers, so the marker a player dodges is literally the shape the server tests ([[Hitboxes and Hit Detection]]).

---

## 6. Damage numbers and health bars

Three strategies, with trade-offs:

| Strategy | Feel | Risk |
|---|---|---|
| **Wait for server** (number appears after round trip) | 50 to 300 ms delay; fine in slower PvE with big hits | Feels laggy on fast combos |
| **Provisional number**, confirmed or faded | Instant; on rejection the number fades early or greys out | Players can notice greyed numbers |
| **Predict and trust** | Instant | Numbers that never happened; crit display mismatches if crits are rolled on the server |

Crits are the classic trap: if the server rolls crits with its own random generator, a client cannot predict them. Either show the crit only on confirmation (common), or derive the crit roll from data both sides know, such as a seeded generator keyed by the sequence number, while keeping the server's result authoritative. The second option leaks future crits to exploiters who read the seed, which matters only in PvP.

For health bars on enemies, predict the drop for responsiveness and let the next replicated health value correct it. Keep the predicted bar slightly behind (for example, an animated "chip" segment) so a correction upward is not jarring.

---

## 7. Projectiles

A fireball has a travel time, which makes prediction and fairness interact.

**Pattern: client visual, server truth, fast-forward for observers.**

1. The caster's client spawns a **visual** projectile immediately and sends `(seq, origin, direction)`.
2. The server validates (origin near the character, direction a unit vector, cooldown), then simulates its **own** projectile from that origin, starting from the cast time estimated with the player's latency. The server's projectile decides hits.
3. The server tells other clients `(projectileId, origin, direction, serverStartTime)`. Each observer spawns a visual and **fast-forwards** it by `GetServerTimeNow() - serverStartTime`, so it appears where it should be now rather than at the muzzle.
4. On a server hit, everyone gets `(projectileId, hitPosition)`; clients snap their visual there and play the impact.

```lua
--!strict
-- Observer client: spawn a remote projectile already in flight.
local function spawnRemoteProjectile(origin: Vector3, dir: Vector3, speed: number, serverStart: number)
	local elapsed = math.clamp(workspace:GetServerTimeNow() - serverStart, 0, 0.5)
	local startPos = origin + dir * speed * elapsed
	return spawnVisual(startPos, dir, speed) -- your client-only visual
end
```

Clamp the fast-forward (0.5 s above) so a stalled client does not spawn a projectile that is already past its target. Visuals are client-only instances: the server never creates parts for them, which also saves replication ([[Interest Management and Per-Player Replication]]).

**Caster-side mismatch.** The caster's visual started about half a round trip before the server's projectile. For fast projectiles this is small; for slow ones, the visual may reach a target slightly before the server decides the hit. Play impact effects on the server's hit message, not on the visual's own collision, or the caster sees hits that did not happen.

---

## 8. Movement abilities

Dashes, leaps and blinks move the player's own character, which the client simulates. That means:

- **Apply locally** for instant feel: the client sets velocity or uses a mover constraint ([[Mover Constraints and Physics Controllers]]).
- **Validate on the server afterwards**: compare the character's position before and after against the ability's maximum distance plus tolerance. Correct only when the excess is clearly beyond tolerance, and correct by moving the character back (or to the furthest legal point), not by fighting the client every frame.
- **Invulnerability windows must use server time.** **Measured:** the reference project gives a dash 0.40 s of immunity against boss-class attacks counted from the server's receipt of the dash, and enforces telegraphs of at least 0.45 to 0.5 s so a dash on the player's screen is still in time on the server's ([[Hitboxes and Hit Detection]]).

Rubber-banding (repeated corrections) means your tolerance is too tight or the server is measuring at the wrong moment. Log corrections with ping before tightening anything; see [[Exploits and Anti-Cheat]] for movement validation and suspicion scores.

---

## 9. The engine's server authority model

As of October 2026, Roblox offers an opt-in **server authority model**: set `Workspace.AuthorityMode` to `Server`. The DevForum announcement marked it as a full release on 9 July 2026 ("available for all creators"). Earlier notes in this vault describe it as beta; that was correct at the time of writing and is now outdated. It changes the classic model in which your own character is client-simulated.

What it does (Roblox docs):

- The server is the single source of truth; clients send **inputs**, and predict the results to hide latency.
- When a prediction is wrong, the client **rolls back** to the last authoritative server state and **resimulates** forward, reapplying its local inputs.
- Core logic goes into functions bound with `RunService:BindToSimulation()`, which run on both client and server and are re-run during resimulation. Only members marked with Simulation Access may be used inside them.
- Inputs that affect simulation must use the **Input Action System** (`InputAction`, `InputContext`), not `UserInputService.InputBegan`.
- **Attributes** are the main channel for custom predicted data (health, ammo). A mismatch between client and server attribute values triggers a rollback, so write predicted attributes only inside bound functions.
- `time()` is synchronised and rewinds during resimulation; `tick()`, `os.time()` and `os.clock()` do not and should not drive simulation logic.
- Rendering (animations, sounds, VFX) should read simulation results from a separate `RenderStepped` function.
- `RunService:SetPredictionMode()` forces prediction on or off per instance; by default the engine predicts Simulation Access properties near the local character.

Setting `AuthorityMode = Server` automatically sets five other properties: `NextGenerationReplication` enabled, `PlayerScriptsUseInputActionSystem` enabled, `SignalBehavior` Deferred, `UseFixedSimulation` enabled, and `StreamingEnabled` enabled.

Known limitations from the announcement (as of October 2026): attributes limited to 64 per instance, with replication also requiring names and string values of at most 50 characters (docs); at most 8 actively playing animation tracks per Animator; remote events are not synchronised with the simulation timeline (a staff reply put the offset at about 40 to 50 ms); the default Animate script lacks custom emotes, mood animations and strafing; changing Tools during a misprediction can delete the Tool's weld on the client; mobile and console clients can lag desktop updates by a few days; server utilisation increases (no figure given).

**When to adopt it.** It is a strong fit for new competitive games where movement cheating matters (racing, sports, shooters), which is why the official templates are racing, soccer and laser tag. For an existing combat game built on client-owned characters, remotes and many animation tracks, it is a migration, not a switch: the 8-track limit alone can rule it out for layered combat animation ([[Playback, Priorities and Blending]]). Roblox recommends converting on a copy of the project. Everything else in this note (sequence numbers, rejection UX, projectiles) remains useful for actions that travel over remotes in either model.

The docs page itself did not state a tick rate or a "currently resimulating" query API when checked; do not assume one exists.

---

## 10. Testing under lag

Prediction bugs only appear with latency, and Studio's local test has almost none.

- **Simulate latency in Studio.** Studio's network settings include an incoming replication lag option for test sessions (rule of thumb: check the exact setting name in your Studio version). Test at 0, 150 and 300 ms.
- **Multi-client tests** ([[Multi-Client and Live Testing]]): one attacker, one observer, one victim. Watch each screen.
- **Live tests on a phone over mobile data.** Jitter, not average ping, causes most cooldown rejections.
- **Instrument mispredictions.** Count rejections per ability and per reason on the server, and rollbacks on the client. A rate above about 1% of honest casts means the shared rules disagree (rule of thumb).

What failures look like:

| Symptom | Likely cause |
|---|---|
| Bar jumps up after every cast, then down | Client not adding pending spends on top of the server value |
| Bar slowly drifts from the server | Applying deltas instead of recomputing from the confirmed value |
| Fizzles on fast but legal presses | Server cooldown without tolerance; jitter |
| Double damage numbers | Predicted number plus confirmed number, no id matching |
| Dash snaps back on mobile | Movement tolerance too tight; validation at the wrong time |
| Observers see projectiles appear mid-flight far from the caster | Fast-forward not clamped |
| Everything broken after respawn | Sequence or pending state not reset |

---

## Checklist

- [ ] Own animations, sounds and VFX start on input, never after a round trip.
- [ ] Every predicted action carries a sequence number; the server answers with the last processed one.
- [ ] Displayed resources = server value + unconfirmed predictions, recomputed on each answer.
- [ ] Server cooldowns have a small tolerance; cooldown ends are sent in server time.
- [ ] Rejections roll back quietly; rejection rates are measured.
- [ ] Rules (costs, cooldowns, shapes) live in one shared module.
- [ ] Kills, loot and currency are never predicted.
- [ ] Projectiles: client visuals, server simulation, observers fast-forward with a clamp.
- [ ] Movement abilities validated after the fact with logged corrections.
- [ ] Server authority model evaluated against its limits (8 tracks, 64 attributes) before adopting.
- [ ] Tested at 150 and 300 ms simulated latency and on a phone.

## See also

[[Hitboxes and Hit Detection]] · [[Combat Systems Architecture]] · [[Client-Server Model]] · [[Network Ownership]] · [[Server Authority and Validation]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Exploits and Anti-Cheat]] · [[Rate Limiting and Abuse Prevention]] · [[Interest Management and Per-Player Replication]] · [[Combat Combo Systems]] · [[Multi-Client and Live Testing]]

## Connected notes
<!-- auto-links:start -->
[[Detecting Combat Exploits - Reach Rate and Aim]] · [[Server Authority]] · [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[Links - Latency and prediction]] · [[Projectiles and Ballistics]] · [[Debugging Client-Server Desync]]
<!-- auto-links:end -->
