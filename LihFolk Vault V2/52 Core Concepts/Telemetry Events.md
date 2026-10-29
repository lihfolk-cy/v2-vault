---
tags: [core-concept, analytics, live-ops, debugging, economy, type/reference, area/economy, level/beginner, api/AnalyticsService, area/debugging, api/HttpService]
---
# Telemetry Events

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox gives you built-in channels: `AnalyticsService` has methods for economy events, progression events, funnel steps and...
> - Decide the questions first. "Log everything" produces data nobody reads.
> - Names and fields are a schema. Rename an event and your charts break.
> - Log on the server. Client-logged events can be forged and are lost when the client crashes.
>
> Cost: TL;DR ~130 tok · whole note ~980 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Telemetry events** are small structured records your game emits when something meaningful happens: a purchase, a level-up, a funnel step, an error, a currency gain. Collected across thousands of sessions they show what players actually do, as opposed to what you assumed.

## Why it matters on Roblox

Roblox gives you built-in channels: `AnalyticsService` has methods for economy events, progression events, funnel steps and custom events that appear in the Creator Dashboard (Roblox docs, "Analytics" and `AnalyticsService`, as of October 2026). Errors appear in the error report pages. Anything beyond that you send yourself, usually to an external service through `HttpService`, which brings privacy and rate-limit duties.

## The nuance most people miss

1. **Decide the questions first.** "Log everything" produces data nobody reads. Start from questions ("where do new players quit?", "which sink removes the most coins?") and log exactly the events that answer them.
2. **Names and fields are a schema.** Rename an event and your charts break. Keep a written list of events, fields and meanings, and version it like save data.
3. **Log on the server.** Client-logged events can be forged and are lost when the client crashes. Gameplay facts (purchases, rewards, kills) should be logged where they are decided.
4. **Sample high-frequency events.** Logging every hit in a busy combat game is noise and cost. Aggregate (hits per minute per player) or sample a percentage of sessions.
5. **Respect limits and privacy.** Built-in analytics have custom-event and field limits (check current limits in the docs); external endpoints count against HttpService budgets. Do not send personal data, chat text or anything you would not want leaked; see the privacy notes.
6. **Telemetry lies quietly when broken.** A missing event looks like zero activity. Add a heartbeat or count check so you notice when logging itself fails after an update.

## Tiny example

```lua
local AnalyticsService = game:GetService("AnalyticsService")

-- Server: log a sink when a player buys an upgrade with soft currency.
AnalyticsService:LogEconomyEvent(
	player,
	Enum.AnalyticsEconomyFlowType.Sink,
	"Coins",
	price,
	profile.Coins,           -- balance after the transaction
	Enum.AnalyticsEconomyTransactionType.Shop.Name,
	"SpeedUpgrade"
)
```

## Where this shows up

- [[Analytics and Funnels]]: the built-in dashboards.
- [[Economy Telemetry and Balancing Live]]: telemetry for economies.
- [[Crash and Error Telemetry]]: errors as events.
- [[Debugging Live Servers]]: logs from production.
- [[Logging Bans and Appeals]]: enforcement records.
- [[Player Privacy and Data Deletion]]: what not to collect.
- [[HttpService and External APIs]]: sending to your own backend.
- [[A-B Testing and Experiments on Roblox]]: events that measure experiments.
- [[Debugger Breakpoints and Logging]]: local logging versus telemetry.
- [[Live Incident Response and Post-Mortems]]: telemetry during incidents.
- [[Balancing with Spreadsheets and Data]]: turning events into tables.
- [[False Positives Lag and Fair Enforcement]]: telemetry before enforcement.

Related concepts: [[Onboarding Funnel]], [[Retention Cohorts]], [[Faucets and Sinks]], [[Feature Flags]].

## Connected notes
<!-- auto-links:start -->
[[Links - Analytics]] · [[Session Length]] · Anti-Exploit Start Here · Economy Design Start Here · Debugging Start Here · Skill - Roblox Debugging · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Faucets and Sinks]] · [[Click-Through Rate]] · [[Variance]] · [[Rate Limiting]] · [[Expected Value]] · [[Data Schema Versioning]] · [[Power Curve]] · [[Core Loop]]
<!-- related:end -->
