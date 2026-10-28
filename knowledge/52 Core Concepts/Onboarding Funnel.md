---
tags: [core-concept, analytics, onboarding, game-design, retention]
---
# Onboarding Funnel

<!-- tldr:start -->
> [!tldr] TL;DR
> - New players arrive from discovery with low commitment and many alternatives one click away.
> - Start the funnel before gameplay. "Loaded" and "first input" are steps.
> - Steps must be ordered and each logged once.
> - The biggest drop is not always the one to fix.
>
> Read more (3 KB note): ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

An **onboarding funnel** is the ordered list of steps a new player should pass through in their first session (joined, loaded, moved, finished the first action, got the first reward, made the first upgrade), with the share of players who reach each step. Each drop between steps shows where new players give up.

## Why it matters on Roblox

New players arrive from discovery with low commitment and many alternatives one click away. The first minutes decide day-1 retention more than anything else in the game. Roblox supports this directly: `AnalyticsService:LogOnboardingFunnelStepEvent` records steps that appear as a funnel in the Creator Dashboard, and `LogFunnelStepEvent` covers other funnels such as a shop flow (Roblox docs, "Funnel events", as of October 2026).

## The nuance most people miss

1. **Start the funnel before gameplay.** "Loaded" and "first input" are steps. A big drop between join and first input usually means slow loading or a confusing first screen, not a bad game.
2. **Steps must be ordered and each logged once.** Onboarding funnels assume a fixed sequence. Logging a step twice or out of order makes the chart meaningless. Keep a per-player record of which steps were logged.
3. **The biggest drop is not always the one to fix.** A large drop at a step that comes right after a long wait may be caused by the wait. Look at time between steps, not only at counts.
4. **Returning players must be excluded.** Only first sessions belong in an onboarding funnel. Log steps only when the player has no saved data or a "tutorial done" flag is false.
5. **Fewer, sharper steps.** Eight to twelve steps is plenty (rule of thumb). Fifty steps produce a chart nobody reads.
6. **Teach by doing.** Every step that is "read this text" tends to lose players; steps that are "do this action" keep them. Funnels usually show it clearly.

## Tiny example

```lua
local AnalyticsService = game:GetService("AnalyticsService")
local STEPS = { "Loaded", "FirstMove", "FirstCatch", "FirstSell", "FirstUpgrade" }

local function logStep(player: Player, profile, step: number)
	if profile.TutorialDone or (profile.OnboardStep or 0) >= step then return end
	profile.OnboardStep = step
	AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEPS[step])
end
```

## Where this shows up

- [[First-Time User Experience and Onboarding]]: designing the first session.
- [[Analytics and Funnels]]: funnels across the game.
- [[Teaching Through Level Design]]: teaching without text.
- [[Case Study - Fast Join and Deferred Loading]]: fixing the earliest drop.
- [[Lobby and Hub Design]]: the first space a player sees.
- [[Quest Chain System End to End]]: a tutorial as a quest chain.
- [[Lore Delivery Without Walls of Text]]: avoiding reading steps.
- [[A-B Testing and Experiments on Roblox]]: testing onboarding changes.
- [[Launch Strategy - The First Two Weeks]]: onboarding under launch traffic.
- [[Difficulty Options and Cognitive Load]]: overload in the first minutes.
- [[Documentation and Onboarding New Developers]]: the same idea applied to new team members.

Related concepts: [[Retention Cohorts]], [[Core Loop]], [[Telemetry Events]], [[Session Length]].

## Connected notes
<!-- auto-links:start -->
[[Click-Through Rate]] · [[Links - Analytics]] · [[Discovery and the Algorithm]] · [[Core Loops and Session Design]] · [[Links - Quests and progression]] · [[Level Design Start Here]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
