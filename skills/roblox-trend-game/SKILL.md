---
name: roblox-trend-game
description: 'LihFolk: plan, build and run fast trend games (Steal/Grow a ___, collect-upgrade-steal) under 2026 Roblox rules; discovery, retention, thumbnails, luck boosts, live ops.'
---

# LihFolk Trend Game

Full sourced research: `references/trend-games-research.md` (labels: Roblox docs / Reported / Expert practice / Derived / Unverified). Read the **Executive summary**, **section 0 (platform context)** and the section for the current step before acting. Never quote a number from it without its label.

## Non-negotiables (2026 platform)

1. **Paid random items** (eggs, crates, spins, luck boosts, pity, bundles): show numerical odds summing to 100%, update odds live while a boost is active, every outcome gives something, gate with `PolicyService` (fail closed), separate check for trading. Breaking this risks removal and suspension. See section 8.1; also use the `roblox-monetization-compliance` skill.
2. **Under-16 reach** requires passing the new-experience evaluation and owner verification. Plan launch around a 16+ trial (section 4.5, 8.6).
3. **No copied UI, art or names** from the hit you're riffing on (lawsuits are active). Original characters and twist (section 8.4). No misleading thumbnails (8.3). No botting (8.5).
4. **Discovery rewards retention + monetization together**, first-play bounce rate, 28-day windows, playtime capped at 60 min/player/day. Optimise the first 60 seconds above everything (section 4.1).

## The skeleton (section 1.2)

Units earn passive income -> rarity + mutations multiply value -> shared server where others can steal/trade/see -> rebirth for multipliers -> weekly events / admin abuse to bring players back. The loop is repeatable; execution, twist and live ops decide the hit.

## Workflow (map to the 7-day plan, section 9)

- **Day 0**: verification, template setup (systems from `roblox-system-builder`, UI from `roblox-ui-builder`).
- **Day 1 - trend + twist**: identify the trend and its decay stage (section 2). Run a **Quick** `council` (one Skeptic seat) on the twist: must be distinct, explainable in one sentence, and visible in the thumbnail.
- **Day 2 - core loop playable** in under 60 seconds from spawn.
- **Day 3 - social mechanic, rarity/mutations, rebirth.** Economy numbers go through a **Standard** `council` (3 seats) once, at the end of the day, not per change; a human tunes them.
- **Day 4 - theme, art, juice, UI.** Original art via `roblox-blender-modeling`; feel via game-feel notes. This is where AI slop is decided: run a **Quick** `council` with the Art Director lens on one screenshot set; escalate to Standard only if it comes back weak.
- **Day 5 - monetization + compliance + live-ops framework** (timers, event scheduler, admin events).
- **Day 6 - performance (mobile first), QA, metadata, maturity questionnaire.** Use `roblox-performance-audit`, `roblox-secure-remotes`, `roblox-anti-exploit-review`.
- **Day 7 - launch**, small ads test, watch first-play bounce and D1.
- **Week 2+** - weekly updates, events, read analytics, kill or double down (section 6).

## What separates hits from the hundreds of clones (section 7)

Instant clarity, juice and feedback on every action, a twist visible in the thumbnail, mobile performance, fast weekly updates, and an economy that never stalls. Generic AI output is spotted in seconds by players. A human must stay in the loop for economy tuning, security, compliance and original characters (section 3.5).

## Honesty rules

Roblox publishes no per-game revenue, ARPDAU or "good retention" cutoffs. When estimating, show the math (section 5.2) and label it Derived. Peaks collapse fast (section 1.1); never promise a hit.
