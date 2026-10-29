---
tags: [ai, agents, ai-skill, architecture, luau, worked-build, type/guide, area/ai, level/intermediate, area/scripting]
---
# Skill - Roblox System Builder

**Skill file:** [skills/roblox-system-builder/SKILL.md](../skills/roblox-system-builder/SKILL.md) (folder name `roblox-system-builder`)

## What it does

This skill makes an agent build a whole feature the way the Worked Builds section does, so each new system fits the last one instead of inventing its own plumbing. The steps:

1. **Find the closest worked build** and read it. If none matches, start from [[Saved Inventory End to End]], the foundation build whose data layer, remote helper and rate limiter the others reuse.
2. **Write the decisions** that otherwise become support tickets (for example, a fixed daily reset in UTC rather than a rolling 24 hours, and refusing a claim when the bag is full).
3. **Lay out folders** by one convention: shared config and the remote helper in ReplicatedStorage, one server Script plus modules in ServerScriptService, client-unclonable things in ServerStorage, one controller per client feature.
4. **Shared config** asserted at startup, with odds labels and bonus text generated from it.
5. **A server service** of plain, synchronous, all-or-nothing functions behind thin, validated remote handlers.
6. **Saving** through the session-locked profile module.
7. **Purchases** through the single receipt dispatcher, with live prices and odds disclosure.
8. **A client controller** that renders server-owned state and sends intent only.
9. **Studio tests** in a fixed order: API access on with a separate test key, command-bar grants, persistence, fresh profile, simulated load failure, lock contention, two clients, spam and fuzz, unit tests for pure logic.
10. **An exploits table** listing each attack and what stops it, plus what the system does not stop on its own.

It calls the other skills where they apply: [[Skill - Roblox Secure Remotes]] for handlers, [[Skill - Roblox DataStore Safety]] for saving, [[Skill - Roblox Monetization Compliance]] for purchases and [[Skill - Roblox UI Builder]] for screens.

## When to use it

Adding any feature that spans client and server: inventory, shop, daily rewards, codes, quests, pets, rounds, combat or leaderboards.

## Honesty rule

Worked-build code in the vault is labelled "reviewed, not run". The skill keeps that label on new code until it has been played in Studio.

## Notes behind it

[[Saved Inventory End to End]], [[Daily Rewards System End to End]], [[Pet Hatching and Following End to End]], [[Round-Based Minigame Loop End to End]], [[Shop with Game Passes and Developer Products End to End]], [[Codes Redemption System End to End]], [[Global Leaderboards End to End]], [[Quest Chain System End to End]], [[Melee Combat System End to End]], [[Rebirth and Prestige System End to End]], [[Project Structure and Bootstrapping]], [[Server Authority and Validation]], [[Luau Type System and Strict Mode]], [[Module Scripts and Requiring]], [[Automated Testing with TestEZ and Jest-Lua]], [[Testing Modes - Play Run and Multi-Client]], [[Tools and Inventory Systems]].

## Related

- [[AI Skills Start Here]]
- [[Case Study - Building a Game with AI Agents]]

## Connected notes
<!-- auto-links:start -->
[[Worked Builds Start Here]] · [[Skill - Roblox Anti-Exploit Review]] · [[Skill - Roblox Debugging]] · [[Skill - Roblox Vault Research]] · LihFolk UI Design System · Dependency Injection in Luau
<!-- auto-links:end -->
