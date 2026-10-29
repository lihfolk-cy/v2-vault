---
tags: [vfx, replication, remoteevent, networking, prediction, validation, rate-limit, multiplayer, lihfolk, type/guide, area/vfx, level/intermediate, area/networking, api/RemoteEvent]
---
# Replicating VFX - Server Validates, Clients Render

<!-- tldr:start -->
> [!tldr] TL;DR
> - Abilities feel laggy for the caster: Caster waits for the server echo -> Play on input; the server skips the caster
> - Caster sees every effect twice: Echo not skipped -> Skip the caster on the server; ignore own client-castable presets...
> - Network spikes in big fights: Effects built on the server, or tables of options in each payload -> Ids and numbers only; clients build
> - Caster plays on input; the server never echoes to the caster.
> - Payload is `(caster, presetId, cf, elementIndex, seed, aux)`; lists are append-only.
> - Server checks shape, allowed list, finite values, alive, range (clamp), per-preset cooldown and a token bucket.
>
> Cost: TL;DR ~200 tok · whole note ~2.6k tok. Read more: ## 2. The payload · ## 4. Who receives it · ## Common mistakes · ## Checklist
<!-- tldr:end -->

In a multiplayer game every effect has three audiences: the caster, who wants it on the frame they pressed the key; the people nearby, who need to see it to react; and the server, which decides what actually happened. The pattern that serves all three: **the caster predicts locally, the server validates and sends one compact payload to the players near the cast, and every other client builds the effect itself**. The server renders nothing. This note covers the payload, the validation steps with numbers, who receives what, seeds, and how persistent states differ from one-shots. Background: [[Client-Server Model]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Server Authority and Validation]], [[Rate Limiting and Abuse Prevention]], [[Client Prediction and Reconciliation for Combat]] and [[Interest Management and Per-Player Replication]]. The LihFolk VFX skill ships a working pair: `examples/AbilityVFXReplication.server.luau` and `.client.luau`, with `playPayload` in `LihFolkVFX_Abilities.luau`.

Source labels: **Roblox docs**, **LihFolk module** (shipped values, untested in Studio at the time of writing), **rule of thumb**.

---

## 1. Who does what

| Step | Caster's client | Server | Other clients |
|---|---|---|---|
| Input | plays the effect now (`important`), sends `(presetId, aim)` | - | - |
| Decide | - | checks the request, applies gameplay (hits, damage, movement) | - |
| Tell | - | one payload to each nearby player, skipping the caster | - |
| Draw | already drawn | nothing | build the effect from the payload |

Building effects on the server replicates every part, emitter and property change to every player and arrives late; the server has no screen to draw on anyway (**Roblox docs**: the server does no rendering). One small event per cast replaces all of that ([[VFX Performance Budgets and Culling]] lists it as a trap).

## 2. The payload

Send what the receiver cannot work out on its own, as numbers:

| Field | Type | Why |
|---|---|---|
| caster | `Player` (or nil for the world) | whose character to attach to; lets the caster skip its own echo |
| presetId | number | index into a shared, append-only list (`"Projectile"`, `"TelegraphCircle"`, ...) |
| cf | `CFrame` | where and which way |
| elementIndex | number | index into a shared element list |
| seed | number | same random layout for every onlooker |
| aux | `Vector3` or nil | second point for two-point effects (projectile target, teleport destination) |

- **Ids, not names or tables.** A number per preset and element keeps the payload to a handful of values. Keep both lists **append-only**: reordering a shipped list makes old servers and new clients disagree.
- **Tuning stays on the client.** Speeds, radii and durations live in a defaults table next to the presets (`PayloadDefaults` in the LihFolk module), so a payload never carries 20 option fields.
- **No colours, sizes or Instances from the caster.** The server picks the element from its own state (an attribute set when the player equips a kit).

## 3. Server validation, in order

1. **Shape:** `type(presetId) == "number"`, `typeof(aim) == "Vector3"`; anything else is dropped silently.
2. **Allowed:** the preset is in the client-castable list (`CastRules`). Telegraphs and level-ups are server-originated and never accepted from a client.
3. **Finite:** reject NaN (`v ~= v`) and huge vectors.
4. **State:** the character exists and `Humanoid.Health > 0`.
5. **Range:** clamp the aim to the preset's range (160 studs for a projectile, 40 for a teleport in the LihFolk example). Clamping instead of rejecting keeps the caster's predicted visual roughly right.
6. **Cooldown per preset** with a 0.05 s grace for clock jitter, and a **token bucket per player** (burst 6, refill 3 per second in the example) so no mix of presets can flood the server.
7. **Gameplay:** hits, damage, healing, movement, decided here and only here.

See [[Rate Limiting and Abuse Prevention]] for the bucket and [[Server Authority and Validation]] for the general rules.

## 4. Who receives it

- **Players within a radius** of the cast (250 studs in the example, just beyond the 220-stud client cull) get it with `RemoteEvent:FireClient`. Players farther away would not draw it, so sending is waste ([[Interest Management and Per-Player Replication]]).
- **Skip the caster.** It already drew the effect. The client also ignores an echo of its own client-castable preset, as a second guard; server-originated effects (a level-up) still play for the caster.
- **Reliable or unreliable.** `UnreliableRemoteEvent` suits frequent cosmetic events (footstep puffs, rapid tracers): it may drop or reorder, and the docs drop payloads over 1000 bytes (older versions said 900; keep under 900, see [[Network Bandwidth Budgets and Measuring Them]]). Telegraphs, heals and anything a player must react to go on a reliable `RemoteEvent`.

```lua
--!strict
-- Server: one payload to everyone near `cf`, except `skip`.
local Players = game:GetService("Players")

local RADIUS = 250
local rng = Random.new()

local function broadcast(remote: RemoteEvent, caster: Player?, presetId: number, cf: CFrame, elementIndex: number, aux: Vector3?, skip: Player?)
	local seed = rng:NextInteger(1, 2147483646)
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p ~= skip and root and root:IsA("BasePart") and (root.Position - cf.Position).Magnitude <= RADIUS then
			remote:FireClient(p, caster, presetId, cf, elementIndex, seed, aux)
		end
	end
end

return broadcast
```

## 5. Prediction on the caster

- **Play on the input frame.** Waiting a round trip (80-250 ms on typical connections, **rule of thumb**) makes every ability feel sticky ([[Client Prediction and Reconciliation for Combat]]).
- **Mirror the server's rules** (cooldown, range) on the client so it predicts only casts the server will accept. The same table can serve both sides.
- **A rejected cast** leaves a cosmetic effect that did nothing. For most VFX that is acceptable; for an effect that implies an outcome (a teleport), hold a handle and stop it, or move the character back, when the server says no.
- **Server-confirmed outcomes** that differ from the prediction (a projectile that hit something else) arrive as a second, small event; the visual snaps to it (`Impact(position)` on the LihFolk projectile handle).

## 6. Seeds

Particle emitters randomise inside the engine, so no seed reproduces a particle cloud. What a seed does reproduce is every choice your script makes: orbit phases, ripple sizes, which way debris is thrown, bolt shapes. Pass it to `Random.new(seed)` per effect, draw every scripted random number from that object, and onlookers standing side by side see the same layout. The caster's predicted copy uses its own seed; nobody compares their screen with the caster's.

## 7. States travel as attributes, moments as events

| Kind | Examples | Channel | Late joiner sees it? |
|---|---|---|---|
| Moment | projectile, impact, telegraph, heal, level-up | event payload | no, and that is fine: it is over |
| State | aura on, shield up, burning, stunned | attribute on the character, read with `GetAttributeChangedSignal` | yes, attributes replicate with the character |

A shield started by an event is invisible to anyone who joins or streams in a second later. Set an attribute on the character instead and let each client start and stop its own visual ([[Auras, Shields and Status Effects]] has the client side).

## 8. Server-originated effects

Bosses, hazards and rewards start on the server. They use the same remote and payload with no player skipped: a boss slam sends `TelegraphCircle` to everyone nearby, then damage resolves at the pop time with the same shape numbers ([[AoE Telegraphs - Readable Ground Warnings]]). For long warnings, add the server start time (`Workspace:GetServerTimeNow()`) so late receivers fill only the remainder.

---

## Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| Abilities feel laggy for the caster | Caster waits for the server echo | Play on input; the server skips the caster |
| Caster sees every effect twice | Echo not skipped | Skip the caster on the server; ignore own client-castable presets on the client |
| Network spikes in big fights | Effects built on the server, or tables of options in each payload | Ids and numbers only; clients build |
| Exploiters spam giant effects | Client sends size, colour or CFrame and the server trusts it | Server picks element and frame; clamp range; cooldown and bucket |
| Aura missing for some players | State sent as a one-time event | Attribute on the character |
| Old clients play the wrong preset after an update | Preset list reordered | Append-only id lists |
| Onlookers see different debris layouts | Script randomness unseeded | `Random.new(seed)` per effect |
| Far players receive effects they never draw | `FireAllClients` for local effects | Per-player send within a radius |

## Checklist

- [ ] Caster plays on input; the server never echoes to the caster.
- [ ] Payload is `(caster, presetId, cf, elementIndex, seed, aux)`; lists are append-only.
- [ ] Server checks shape, allowed list, finite values, alive, range (clamp), per-preset cooldown and a token bucket.
- [ ] Gameplay decided on the server only; the visual's raycasts never deal damage.
- [ ] Sent to players within about 250 studs; reliable for anything players react to.
- [ ] Scripted randomness seeded per effect.
- [ ] Persistent states as character attributes; moments as events.
- [ ] Server-originated effects use the same remote, with a start time for long warnings.

<!-- related:start -->
## Related
[[Projectile VFX - Muzzle, Travel and Impact]] · [[Combat Sound Design and Feedback]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[VFX Design Playbook]] · [[Escalation and Grandeur Without Clutter]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Particle Emitters In Depth]]
<!-- related:end -->
