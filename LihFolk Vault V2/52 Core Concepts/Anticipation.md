---
tags: [core-concept, animation, game-feel, combat, ui, type/reference, area/ui, level/beginner, area/animation]
---
# Anticipation

<!-- tldr:start -->
> [!tldr] TL;DR
> - In games anticipation does two jobs. For the player's own actions it adds feel, but every frame of wind-up is input delay.
> - Player anticipation must be short. Rule of thumb: keep wind-up on player attacks under about 100 ms for light actions; longer...
> - Anticipation can hide latency. Start the wind-up on the client the instant the player presses, and send the request at the...
> - Enemy telegraphs must outlast latency plus reaction time.
>
> Cost: TL;DR ~150 tok · whole note ~900 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Anticipation** is the small movement before the main action that prepares the viewer for it: the wind-up before a punch, the crouch before a jump, the button shrinking slightly before it pops. It is one of the classic principles of animation and one of the main tools for making actions readable.

## Why it matters on Roblox

In games anticipation does two jobs. For the **player's own actions** it adds feel, but every frame of wind-up is input delay. For **enemies and bosses** it is a telegraph: the warning that lets players react, and the main thing that makes a fight feel fair. Roblox adds network latency on top, which changes the maths for both.

## The nuance most people miss

1. **Player anticipation must be short.** Rule of thumb: keep wind-up on player attacks under about 100 ms for light actions; longer wind-ups belong to heavy or charged moves where the delay is the cost of the power.
2. **Anticipation can hide latency.** Start the wind-up on the client the instant the player presses, and send the request at the same time. The server's confirmation arrives during the wind-up, so the hit lands on time without the player feeling the round trip.
3. **Enemy telegraphs must outlast latency plus reaction time.** Human reaction is roughly 200 to 300 ms, and a player on a phone with 150 ms ping sees the telegraph late. A boss slam telegraphed for 300 ms is fair on a PC on a good connection and unfair on mobile. Rule of thumb: 500 ms or more for attacks that must be dodged.
4. **Telegraphs need more than motion.** On a small phone screen at distance, a wind-up pose is easy to miss. Pair it with a sound, a colour flash or a ground decal.
5. **UI anticipation is tiny.** A 0.95 scale dip for 60 ms before a reward pops reads as anticipation; anything longer reads as lag.

## Tiny example

```lua
-- Client: start the wind-up and the request together.
local function onAttackPressed()
	windupTrack:Play(0.05)            -- local feel starts now
	AttackRemote:FireServer(aimDir)   -- server confirms during the wind-up
end
```

## Where this shows up

- [[Squash Stretch and Anticipation in UI and Characters]]: the deep dive.
- [[Principles of Animation for Games]]: anticipation among the classic principles.
- [[Boss Fight Design Patterns]]: telegraph design.
- [[Boss Animation and Phases]]: animating readable telegraphs.
- [[Client Prediction and Reconciliation for Combat]]: hiding latency.
- [[Weapon Swing Design]]: wind-up, contact and recovery.
- [[Stance and Charge Moves]]: anticipation as a cost.
- [[Combat Arena and Encounter Layout]]: space to react to telegraphs.
- [[Difficulty Options and Cognitive Load]]: longer telegraphs as an option.
- [[Horror Monster Chase AI End to End]]: telegraphing a chase.
- [[Combat Sound Design and Feedback]]: audio telegraphs.
- [[Enemy and NPC Animation]]: enemy wind-ups.

Related concepts: [[Hit-Stop]], [[Input Buffering]], [[Easing]], [[Tween vs Spring]].

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · Timing Spacing and Frame Charts · Combat Animation Craft · Hitboxes and Hit Detection · Animating Creatures and Monsters · Genre Playbook - Combat and RPG · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Input Buffering]] · [[Server Authority]] · [[Skinning Weights]] · [[Onboarding Funnel]] · [[Thumbnail Contrast]] · [[Accessibility Contrast]] · [[Deterministic Simulation]] · [[Safe Area]]
<!-- related:end -->
