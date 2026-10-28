---
tags: [field-notes, combat, melee, prediction, latency, networking, game-feel, luau]
---
# Client Hit Prediction for Melee Feedback

<!-- tldr:start -->
> [!tldr] TL;DR
> - "Hits land at the end of the animation": Feedback waits for a server round trip -> Play feel locally at the contact frame
> - Attacker hears every hit twice: Server echo not suppressed -> Per-target echo window
> - Third enemy in a sweep double-flashes: Echo keyed per swing, not per target -> Key by target
> - Flash, hit-stop and sound play on the attacker's client at the contact frame.
> - Damage, numbers and status effects only from the server.
> - Server echo suppressed per target within a short window.
>
> Cost: TL;DR ~170 tok · whole note ~1.6k tok. Read more: ## Why the hit feels late · ## Suppress the server echo per target · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A melee hit that only plays its flash, hit-stop and sound when the server confirms it will feel late on every connection, and players describe it precisely: "the hit lands at the end of the animation". This note explains where that delay comes from, and how to play the *feel* of the hit on the attacker's client at the hit frame while keeping damage and outcomes on the server. The general model is in [[Client Prediction and Reconciliation for Combat]]; hit detection in [[Hitboxes and Hit Detection]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## Why the hit feels late

Take a 0.45 s swing whose contact frame is at 0.18 s. With server-driven feedback, the timeline on the attacker's screen is:

1. 0.00 s: input, animation starts locally (immediately).
2. 0.18 s: contact frame. The client tells the server, or the server reaches the contact frame on its own copy of the timing.
3. Plus half a round trip to reach the server, plus server processing and the next replication send.
4. Plus half a round trip back to the attacker.

On a 150 ms round trip, feedback arrives at about 0.18 + 0.15 + a frame or two, roughly 0.35 s. That is near the *end* of a 0.45 s swing, during the follow-through. On a 250 ms phone connection it arrives after the swing has finished. The animation and the feedback have come apart, which is exactly what players report.

**Measured.** In the reference project, moving the hit feel to the attacker's client removed the "hits land at the end of the animation" complaint without any change to the server's damage model.

## The split: feel local, outcome remote

| Played on the attacker's client at the hit frame | Stays server-driven |
|---|---|
| Target flash or highlight | Damage and health |
| Hit-stop on the attacker's animation | Damage numbers |
| Impact sound and small VFX | Knockback, stun, death |
| Camera kick | Rewards, kill credit |

The rule: anything that would be embarrassing if wrong for 200 ms is presentation and can be predicted; anything that changes game state waits for the server. Damage numbers stay server-driven because players read them as truth, and a predicted "120" that becomes "0 (blocked)" is worse than a number that appears 150 ms later.

## Suppress the server echo per target

The server then broadcasts the confirmed hit to everyone so other players see it. The attacker would see the flash and hear the sound twice. Suppress the echo for a short window, keyed by target:

```lua
-- Attacker client
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local ECHO_WINDOW = 0.35 -- seconds; covers a slow round trip
local predictedAt: { [Model]: number } = {}

local function onContactFrame(swingId: number)
	-- Same shape and timing the server will validate against.
	local targets = Hitbox.queryLocal(player.Character, swingId)
	for _, target in targets do
		predictedAt[target] = os.clock()
		HitFeedback.play(target) -- flash, sound, small VFX; local only
	end
	if #targets > 0 then
		HitFeel.attackerStop(swingId) -- hit-stop on our own animation
	end
	CombatRemote:FireServer("Swing", swingId)
end

HitConfirmed.OnClientEvent:Connect(function(attacker: Player, target: Model, damage: number)
	if attacker == player then
		local t = predictedAt[target]
		if t and os.clock() - t <= ECHO_WINDOW then
			predictedAt[target] = nil
			DamageNumbers.show(target, damage) -- numbers are always the server's
			return
		end
	end
	HitFeedback.play(target)
	DamageNumbers.show(target, damage)
end)
```

Why key per target and not per swing: a sweep may hit three enemies on the client while the server confirms two, or confirms them in a different order. Per-target keys handle both. Why a time window: if the server rejects the hit, no echo arrives and the entry simply ages out; if the client missed but the server hit (lag in the other direction), the echo is not suppressed and plays normally, a little late, which is correct.

The server remains authoritative: it decides hits from its own timing and positions, or validates the client's claim against range, facing, swing timing and cooldown ([[Melee Combat System End to End]]). The client's local query only decides what to *show*.

## When prediction is wrong

- **Predicted hit, server miss.** The attacker saw a flash on a target that takes no damage. Keep predicted feedback small and fast (one flash, one sound) so a miss reads as a graze, not a lie. Never predict death effects.
- **Blocked or parried on the server.** Send the outcome with the confirmation and let the attacker's client play a short "clank" overlay when the outcome differs from the prediction.
- **Rate.** **Rule of thumb:** if more than about one predicted hit in ten is rejected in normal play, your client and server hitboxes or timings disagree; fix that rather than tuning the window.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| "Hits land at the end of the animation" | Feedback waits for a server round trip | Play feel locally at the contact frame |
| Attacker hears every hit twice | Server echo not suppressed | Per-target echo window |
| Third enemy in a sweep double-flashes | Echo keyed per swing, not per target | Key by target |
| Damage numbers "change" after appearing | Numbers predicted locally | Numbers only from the server |
| Many flashes on enemies that take no damage | Client and server hit shapes differ | Share one hitbox module and timing table |

## Checklist

- [ ] Flash, hit-stop and sound play on the attacker's client at the contact frame.
- [ ] Damage, numbers and status effects only from the server.
- [ ] Server echo suppressed per target within a short window.
- [ ] Predicted feedback is small enough that a rejected hit reads as a graze.
- [ ] Client and server use the same hitbox shapes and contact times.
- [ ] Rejection rate logged in playtests.

## Connected notes
<!-- auto-links:start -->
[[Client Prediction and Reconciliation for Combat]] · [[Hitboxes and Hit Detection]] · [[Melee Combat System End to End]] · [[Combat Sound Design and Feedback]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
