---
cssclasses: [vault-hub]
tags: [core-concept, hub, start-here, type/hub, level/beginner]
---
# Core Concepts Start Here

This section holds short, atomic notes on the ideas that keep coming back across the whole vault. Each note defines one concept, says why it matters on Roblox, gives the nuance most people miss and a tiny example, and then lists where the concept shows up in other sections. Use them as junctions: when a deep dive mentions "idempotent" or "frame budget", the concept note explains it once and points you to every other place it matters.

Source labels: **Roblox docs (as of October 2026)** for engine facts, **rule of thumb** for experience-based numbers, and **measured in the reference project** for numbers from one production game.

## Networking, security and data

| Concept | One line |
|---|---|
| [[Server Authority]] | The server owns the state that matters; clients send intent |
| [[Replication Boundary]] | What crosses from server to client automatically, and what never does |
| [[Rate Limiting]] | Caps on how often things may happen, inbound and outbound |
| [[Idempotency]] | Doing it twice has the same effect as doing it once |
| [[Session Lock]] | One server owns a player's profile at a time |
| [[Data Schema Versioning]] | Versioned saves with a chain of migrations |

## Performance and engine

| Concept | One line |
|---|---|
| [[Frame Budget]] | The milliseconds every system shares each frame |
| [[Draw Calls]] | Why batching usually matters more than triangle count |
| [[Instance Count]] | The cost of every object in the DataModel |
| [[Streaming Radius]] | How much of the world a client holds |
| [[Object Pooling]] | Reuse instead of create and destroy |
| [[Deterministic Simulation]] | Same inputs, same result, on every machine |

## Code architecture and operations

| Concept | One line |
|---|---|
| [[Event Bus]] | Publish facts, let systems subscribe |
| [[Dependency Injection in Luau]] | Pass dependencies in so code is testable |
| [[Feature Flags]] | Runtime switches for safe rollouts and kill switches |
| [[Telemetry Events]] | Structured records that show what players really do |

## Motion and game feel

| Concept | One line |
|---|---|
| [[Tween vs Spring]] | Fixed-duration curves versus target-following physics |
| [[Easing]] | The shape of change over time |
| [[Hit-Stop]] | A brief freeze that makes impacts land |
| [[Anticipation]] | The wind-up that makes actions readable and hides latency |
| [[Input Buffering]] | Remembering early presses so inputs are never eaten |

## Game design, economy and maths

| Concept | One line |
|---|---|
| [[Core Loop]] | The shortest repeating cycle of play |
| [[Session Length]] | How long one visit lasts, and why longer is not always better |
| [[Retention Cohorts]] | Who comes back, grouped by when they started |
| [[Onboarding Funnel]] | Where new players drop off in the first session |
| [[Faucets and Sinks]] | Currency in, currency out |
| [[Power Curve]] | How strength and costs grow together |
| [[Expected Value]] | The long-run average of a random reward |
| [[Variance]] | How far individual results stray from the average |
| [[Pity Timer]] | A cap on the worst bad luck |

## Discovery, UI and accessibility

| Concept | One line |
|---|---|
| [[Click-Through Rate]] | Clicks divided by impressions |
| [[Thumbnail Contrast]] | Whether a tile reads at a glance at small size |
| [[Safe Area]] | Where UI is safe from notches, core UI and overscan |
| [[Accessibility Contrast]] | Brightness difference that keeps text readable |

## Art and assets

| Concept | One line |
|---|---|
| [[Texel Density]] | Texture pixels per stud, kept consistent |
| [[Triangle Budget]] | Agreed geometry limits per asset and per scene |
| [[Skinning Weights]] | How bones move the vertices of a skinned mesh |

## Suggested paths

- **Building your first system:** [[Server Authority]], [[Replication Boundary]], [[Rate Limiting]], [[Idempotency]], [[Session Lock]].
- **Your game lags on phones:** [[Frame Budget]], [[Draw Calls]], [[Instance Count]], [[Object Pooling]], [[Streaming Radius]].
- **Balancing an RNG or simulator game:** [[Core Loop]], [[Power Curve]], [[Faucets and Sinks]], [[Expected Value]], [[Variance]], [[Pity Timer]].
- **Growing the player base:** [[Click-Through Rate]], [[Thumbnail Contrast]], [[Onboarding Funnel]], [[Retention Cohorts]], [[Session Length]].

For broader orientation, see [[Glossary]] and the other section hubs such as [[Game Feel Start Here]], [[Economy Design Start Here]] and [[Debugging Start Here]].

## Connected notes
<!-- auto-links:start -->
[[Live Ops Deep Dive Start Here]] · Balancing with Spreadsheets and Data · Discovery and the Algorithm · Analytics and Funnels · Advanced Luau Start Here · Core Loops and Session Design
<!-- auto-links:end -->
