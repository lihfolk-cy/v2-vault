---
tags: [analytics, onboarding, ftue, funnels, drop-off, ab-testing, retention, d1-retention, analyticsservice, type/guide, area/monetization, area/design, level/intermediate, api/AnalyticsService]
verified: 2026-10-29
---
# Measuring Onboarding - Funnels, Drop-off and A-B Tests

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Logging steps from the client -> Server-only, validated
> - Avoid: Same step number logged twice -> Forward-only guard per player
> - Avoid: Testing in Studio and seeing nothing -> Expected: events come from published servers
> - Joined, every step and Finished logged on the server, forward-only.
> - Skip and hint events with the step id in a custom field.
> - Versioned funnel name whenever steps are reordered.
>
> Cost: TL;DR ~150 tok · whole note ~1.7k tok. Read more: ## 1. What to log · ## 2. Numbers worth tracking · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A tutorial you do not measure is a guess. This note covers what to log for onboarding, how to read where players drop, which numbers to compare, and how to A/B test small changes without fooling yourself. The general analytics API and its limits are in [[Analytics and Funnels]]; the concept is in [[Onboarding Funnel]]. The plugin skill **lihfolk-tutorial** logs the funnel below automatically.

Trust labels: **Roblox docs** (AnalyticsService reference and the funnel analytics pages, as of October 2026), **Reference project** (see [[First-Time User Experience and Onboarding]]), **Rule of thumb**.

---

## 1. What to log

| Event | Call | When |
|---|---|---|
| Funnel step 1 "Joined" | `LogOnboardingFunnelStepEvent(player, 1, "Joined")` | When the tutorial attaches to a player who has not finished it |
| Each tutorial step | `LogOnboardingFunnelStepEvent(player, n, stepId)` | When the server marks the step done |
| "Finished" | the last step number | When every required step is done |
| Skip | `LogCustomEvent(player, "TutorialSkipped", 1, fields)` | Field 1: the step that was open |
| Hint shown | `LogCustomEvent(player, "TutorialHintShown", 1, fields)` | Field 1: the step id |
| Versioned funnel | `LogFunnelStepEvent(player, "Tutorial_v3", nil, n, stepId)` | After reordering steps, so old and new data stay apart |

Rules from the docs (**Roblox docs**): analytics events are sent from the **server** in a **published** game only (Studio sends nothing); a funnel starts when step 1 is logged; only the first instance of each step counts; if a step is skipped, the earlier steps count as complete; custom fields use `Enum.AnalyticsCustomFieldKeys.CustomField01.Name` to `CustomField03.Name` with values from small fixed sets.

```lua
--!strict
-- Server: log one onboarding step, forward-only, never breaking gameplay.
local AnalyticsService = game:GetService("AnalyticsService")

local highest: { [Player]: number } = {}

local function logStep(player: Player, step: number, name: string)
	if step <= (highest[player] or 0) then
		return
	end
	highest[player] = step
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
	if not ok then
		warn("[Onboarding]", err)
	end
end

return logStep
```

Clear `highest[player]` on `PlayerRemoving`.

## 2. Numbers worth tracking

| Number | Why | Starting target |
|---|---|---|
| Step-to-step conversion | Finds the confusing step | 90% or more per early step (**Rule of thumb**) |
| Joined to first reward | The first-minute promise | Under 60 s median (**Rule of thumb**) |
| Tutorial completion (of starters) | Overall health | 70% or more (**Rule of thumb**) |
| Skip rate by step | A step people want out of | Watch for spikes at one step |
| Hint rate by step | A step that is unclear | A high rate means the objective or target is weak |
| D1 retention, new players | The real outcome | Compare cohorts before and after a change |
| Sessions under 60 s and 1 to 3 min | Discovery reads these (**Roblox docs**, Discovery) | Falling after a change is good |

## 3. Reading drop-off

- **Joined to step 1 is low:** loading, spawn or the first objective. Check join-to-control time and whether the player spawns facing the target ([[Loading Screen Skip and First-Session Goals]]).
- **One step drops sharply:** the step is unclear, too long, or broken. Check its hint rate; play it fresh on a phone; check it can complete at all (the Reference project found a step that depended on a system that had been switched off).
- **A combat or fail-able step drops:** add a safe version or move it later (**Reference project**: large losses at fight and elite steps).
- **Finished, but D1 is low:** the tutorial ends in a dead end. Add a next-goal chain ([[Quests and Objectives]], [[Retention and Return Hooks]]).
- **The biggest drop is not always the one to fix.** A step after a confusing one inherits its confused players. Fix from the earliest weak step forward ([[Onboarding Funnel]]).
- **Segment** by platform (phone players drop at different steps from PC players), new versus returning, and country before concluding.

## 4. A-B testing onboarding

- **Test one small thing:** hint delay (5 s against 10 s, the docs' own example), reward size, step order, objective wording, whether a step exists at all.
- **Assign by user id**, stable across sessions, and log the variant in a custom field on your onboarding events.
- **Wait for enough players.** With low daily new users, noise is large; a few hundred new players per variant is a sensible minimum (**Rule of thumb**; see [[A-B Testing and Experiments on Roblox]]).
- **Compare by join-date cohort**, and annotate the release date. Do not overlap your test with a thumbnail or price test.
- **Decide on the outcome metric** (D1, completion) before looking, not on whichever number moved.

## Common mistakes

| Mistake | Better |
|---|---|
| Logging steps from the client | Server-only, validated |
| Same step number logged twice | Forward-only guard per player |
| Testing in Studio and seeing nothing | Expected: events come from published servers |
| Reordering steps inside one funnel | New versioned funnel name |
| User ids or free text in custom fields | Values from small fixed sets |
| Reading averages only | Medians and per-platform splits |
| Calling a test after two days | Wait for enough players per variant |

## Checklist

- [ ] Joined, every step and Finished logged on the server, forward-only.
- [ ] Skip and hint events with the step id in a custom field.
- [ ] Versioned funnel name whenever steps are reordered.
- [ ] Weekly read: step conversion, time to first reward, completion, D1 by cohort and platform.
- [ ] One change per release, annotated with its date.
- [ ] A/B variants assigned by user id, logged in a field, judged on a pre-chosen metric.

## See also

[[Analytics and Funnels]] · [[Onboarding Funnel]] · [[Funnels]] · [[Day-N Retention]] · [[Retention Cohorts]] · [[A-B Testing and Experiments on Roblox]] · [[Onboarding and FTUE - Tutorials That Keep Players]] · [[First-Time User Experience and Onboarding]] · [[Onboarding by Genre - The First Five Minutes]] · [[Discovery and the Algorithm]]

<!-- related:start -->
## Related
[[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Robux Price Points and Offer Design]] · [[Monetization Overview]] · [[Live Ops Events and Updates]] · [[Ads and Rewarded Video]] · [[Community Building]] · [[Economy Inflation Sinks and Faucets Math]]
<!-- related:end -->
