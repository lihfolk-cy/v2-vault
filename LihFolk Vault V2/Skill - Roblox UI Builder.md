---
tags: [ai, agents, ai-skill, ui, lihfolk-ui, accessibility]
---
# Skill - Roblox UI Builder

**Skill file:** [skills/roblox-ui-builder/SKILL.md](../skills/roblox-ui-builder/SKILL.md) (folder name `roblox-ui-builder`)

## What it does

This skill makes an agent build UI to measured rules rather than "looks fine on my monitor". It covers:

- **Structure**: one UI boot script, `DisplayOrder` bands, `ScreenInsets` set on every gui, interactive content in a safe-area gui and edge-to-edge art in a separate `None` gui, the top bar read live from `GuiService.TopbarInset`.
- **Layout**: one design resolution with one clamped device `UIScale`, square things kept square with constraints, `AutomaticSize` for variable text and never with `TextScaled`, pop scales on a child `UIScale`.
- **Input**: `Activated` everywhere, `gameProcessedEvent` respected, gamepad selection set as a menu opens, one menu at a time.
- **Motion**: one motion module with named tokens, durations by perception band, duration scaled with the square root of screen distance, faster exits, interruption-safe hides, staggers capped at about 0.4 s.
- **LihFolk UI**: when the game uses the [[LihFolk UI Design System]] (LihFolk's own cartoon and simulator style with Shop, Codes, Rebirth, Settings and Daily Rewards menus), the agent follows the `lihfolk-ui` skill's spec and ship checks for exact sizes, colours, motion and scaling.
- **Accessibility**: the three `GuiService` preferences, `Largest` text tests, 4.5:1 contrast, no colour-only signals, at most three flashes per second, 44 px taps with 8 px gaps.
- **Testing**: seven fixed viewports from 1920 x 1080 down to 667 x 375, a notched phone in both orientations, TV with a gamepad, and pass criteria of 12 px text, 44 px taps, 8 px gaps and zero overlaps. Then a real phone.

## When to use it

Building any ScreenGui, HUD or menu; fixing phone layout, notch or gamepad problems; adding animation to panels; or reviewing UI before release.

## Disputed facts it flags

The docs allow `MinTextSize` down to 9, while the reference project's floor is 12 px drawn text. The skill uses 12 px. See [[Open Questions - Whole Vault]].

## Notes behind it

[[ScreenGui Fundamentals]], [[Layout - Scale Offset and Constraints]], [[Responsive UI for Phone Tablet Console and PC]], [[Safe Areas and Insets]], [[UI Motion Language and Timing]], [[Accessibility]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[UI Design Systems]], [[Virtualized Lists and Large Inventories]], [[Gamepad and Console UX]], [[LihFolk UI Spec]], [[Debugging UI Layout and Input]], [[Cookbook - UI]], [[Case Study - Phone UI Overhaul]].

## Related

- [[AI Skills Start Here]]
- [[Skill - Roblox Monetization Compliance]] for prices and odds on shop screens

## Connected notes
<!-- auto-links:start -->
[[Safe Area]] · [[Skill - Roblox System Builder]] · [[Skill - Roblox Secure Remotes]] · [[Skill - Roblox DataStore Safety]] · [[Readable Text and UI Scale]] · [[UI Asset Pipeline]]
<!-- auto-links:end -->
