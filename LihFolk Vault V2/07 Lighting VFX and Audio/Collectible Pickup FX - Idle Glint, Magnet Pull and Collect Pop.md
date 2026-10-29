---
tags: [vfx, pickups, collectibles, simulator, obby, juice, magnet, particles, ui, client-visuals, type/guide, area/vfx]
---
# Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server-side `Touched` coins. Exploitable and expensive.
> - Avoid: One tween per coin. Hundreds of tweens; one shared loop is cheaper.
> - Avoid: Constant-fraction lerp magnet. Feels sticky at the end.
> - Server owns records and validates batched requests by distance and rate.
> - Per-player pickups are never server instances.
> - One shared animation loop with phase offsets; glint via occasional `Emit`.
>
> Cost: TL;DR ~140 tok · whole note ~2.0k tok. Read more: ## Beat 1: idle glint · ## Beat 2: magnet pull · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Simulators, obbies and tycoons spawn hundreds of coins, gems and orbs. The presentation has three beats: an **idle** state that says "grab me", a **magnet pull** that says "it is yours", and a **collect pop** that pays off with sound and a number. This note covers a reusable, pooled, client-rendered pickup system with server-authoritative collection, and the gotchas that make pickup-heavy games stutter on phones.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## The authority split

The single most important decision: **the server decides what exists and who collected it; the client draws everything.**

- Server: owns a table of pickup records (`id`, `position`, `value`, `kind`, `ownerUserId` if per-player). It validates collection requests by distance from the character and rate, then credits currency.
- Client: spawns pooled visuals from records, animates idle, runs the magnet, and plays the pop.
- Per-player pickups (most simulators) should not exist as server instances at all. Send records to one client; nobody else needs them.

Spawning hundreds of physical, server-owned parts with `Touched` handlers is the classic mistake: replication cost, physics cost and `Touched` spam that exploiters trigger from anywhere.

## Beat 1: idle glint

Goal: visible from across the area, cheap per item.

- **Bob and spin in one shared loop**, not a tween per coin. One `RenderStepped` (or `PreRender`) connection iterates active visuals and sets their `CFrame` with `BulkMoveTo` for large counts (Roblox docs: `WorldRoot:BulkMoveTo`, called as `workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)`). Hundreds of individual tweens are a measurable cost.
- **Phase offsets.** Seed each item's bob phase from its id so a field of coins does not move in lockstep.
- **Glint, not glow.** A periodic star sparkle (one `ParticleEmitter:Emit(1)` every 1.5 to 3 s, random per item) reads better and costs less than a constant emitter on every coin. For rare pickups, add a `Highlight` outline sparingly; Highlights have a hard concurrent limit (see [[Highlights and Selection Effects]]).
- **Rarity through motion and colour**, never through size alone: rare items bob slower, glint more often, and get a vertical light beam visible over terrain.

## Beat 2: magnet pull

When the player is inside the pickup radius (often a purchasable stat in simulators):

```lua
--!strict
-- Client: pull a visual toward the character with an accelerating curve.
-- Returns true when it has arrived and should pop.
local function stepMagnet(visual: BasePart, target: Vector3, state: {speed: number}, dt: number): boolean
	local offset = target - visual.Position
	local dist = offset.Magnitude
	if dist < 1.5 then
		return true
	end
	state.speed = math.min(state.speed + 120 * dt, 90) -- studs/s, accelerating
	local step = math.min(state.speed * dt, dist)
	visual.Position += offset.Unit * step
	return false
end
```

Rules of thumb:

- **Accelerate, do not lerp at a constant fraction.** A constant-fraction lerp slows down as it arrives, which feels sticky. Speed should increase toward the player.
- **Aim at the torso, not the feet.** The pop happens where the eye already is.
- **Send the collect request at the start of the pull, not at arrival.** The server validates distance against where the player is now. If you wait for arrival, laggy players fail validation and feel robbed. If the server rejects it, cancel the visual and return it to the pool.
- **Batch requests.** In a coin field, the client sends one remote every 0.1 to 0.25 s with a list of ids, not one remote per coin.

## Beat 3: collect pop

The payoff stack, all client-side and all fired within one frame of arrival:

1. Scale pop: the visual grows to about 1.3x over 0.05 s and vanishes. Return it to the pool, do not `Destroy`.
2. Burst: `Emit` 6 to 12 small sparkles in the item colour. Radial is fine here; it is a collect burst, not a slash.
3. Sound: short, bright, with pitch rising for streaks (pitch up a semitone per pickup within 0.5 s, reset after a pause). This is the single most effective juice in the genre.
4. Number: a floating "+25" or a coin icon flying to the currency counter in the HUD, followed by a counter bump ([[Game Feel and Juice]]).

For big multi-collects, aggregate: one "+1,240" number per 0.2 s window, not one per coin.

## Pooling and budgets

- Pool visuals per kind. Pre-warm the pool to your expected peak at load.
- Cap simultaneous visible pickups per client (rule of thumb: a few hundred on desktop, fewer on phones) and cull by distance; items far away can be hidden and only their record kept ([[VFX Performance Budgets and Culling]]).
- Use one `ParticleEmitter` per kind attached to a hidden pooled part, moved to the pop position before `Emit`, rather than one emitter per coin.
- Anchored, `CanCollide`, `CanTouch` and `CanQuery` all false on visuals so they cost nothing in physics or raycasts.

## Server validation sketch

```lua
-- Server: validate a batch of collection ids from one player.
local MAX_BATCH = 40
local function onCollect(player: Player, ids: {any})
	if typeof(ids) ~= "table" or #ids > MAX_BATCH then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local radius = getMagnetRadius(player) + 6 -- slack for latency
	for _, id in ids do
		local rec = pickups[id]
		if rec and (rec.owner == nil or rec.owner == player.UserId)
			and (rec.position - root.Position).Magnitude <= radius then
			pickups[id] = nil
			grantCurrency(player, rec.kind, rec.value)
		end
	end
end
```

`getMagnetRadius`, `pickups` and `grantCurrency` are your own functions. Grant through your single currency function so economy analytics stay complete ([[Analytics and Funnels]]).

## Common mistakes

- **Server-side `Touched` coins.** Exploitable and expensive. Use records plus distance checks.
- **One tween per coin.** Hundreds of tweens; one shared loop is cheaper.
- **Constant-fraction lerp magnet.** Feels sticky at the end.
- **Requesting collection at arrival.** Laggy players fail validation.
- **`Destroy` on collect.** Garbage and instance churn; pool instead.
- **A number per coin.** Unreadable spam; aggregate.
- **Highlights on every pickup.** You will hit the Highlight limit and other effects will stop appearing.

## Checklist

- [ ] Server owns records and validates batched requests by distance and rate.
- [ ] Per-player pickups are never server instances.
- [ ] One shared animation loop with phase offsets; glint via occasional `Emit`.
- [ ] Accelerating magnet aimed at the torso; request sent at pull start.
- [ ] Pop: scale, burst, rising-pitch sound, aggregated number, counter bump.
- [ ] Pools pre-warmed; visible cap and distance culling; physics flags off.

## See also

- [[Game Feel and Juice]]
- [[Particle Emitters In Depth]]
- [[Highlights and Selection Effects]]
- [[VFX Performance Budgets and Culling]]
- [[Genre Playbook - Simulators]]
- [[Genre Playbook - Obbies and Platformers]]

## Connected notes

[[Juice on a Budget - Mobile and Low-End]] · Economy Exploits - Dupes Races and Purchase Abuse · Currency Architecture - Soft Hard and Event Currencies · [[Sound Design for Games]]

<!-- related:start -->
## Related
[[VFX Design Playbook]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Light Sources and Shadows]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Gore Policy and Kid-Friendly Hit Feedback]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]
<!-- related:end -->
