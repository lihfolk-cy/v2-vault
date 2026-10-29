---
tags: [qol, accessibility, cross-links, settings, inclusive-design, map, type/reference, area/accessibility, level/beginner, area/design]
---
# Accessibility Cross-Links for QoL Settings

<!-- tldr:start -->
> [!tldr] TL;DR
> - Same feature built twice: QoL and accessibility owned by different people -> One settings schema, mapped here
> - Settings only after tutorial: Menu gated by progression -> Settings from the first second
> - Accessibility toggles hidden in a separate tab no one opens: Siloed -> Put them in the groups players look in (Audio, Camera, Interface)
> - Each QoL setting mapped to its accessibility need and implemented once.
> - Platform preferences read and respected.
> - Settings reachable from the loading screen.
>
> Cost: TL;DR ~170 tok · whole note ~1.6k tok. Read more: ## 1. Map: QoL setting → accessibility need · ## 2. Shared rules (do these once) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most QoL settings double as accessibility features, and most accessibility features are QoL for everyone: captions help players in noisy rooms, remapping helps left-handed players, reduced motion helps people on a bus. Section 42 ([[Accessibility Start Here]]) covers accessibility in depth. This note does **not** repeat it; it maps each QoL setting in this section to the accessibility note that explains the need, so you build each feature once and serve both goals.

Sources: the linked notes; external guideline collections used across section 42: Game Accessibility Guidelines (https://gameaccessibilityguidelines.com/), Xbox Accessibility Guidelines (https://learn.microsoft.com/en-us/gaming/accessibility/guidelines), WCAG 2.x (https://www.w3.org/TR/WCAG21/). Platform settings: **Roblox docs** for `GuiService.ReducedMotionEnabled` and `GuiService.PreferredTextSize` (https://create.roblox.com/docs/reference/engine/classes/GuiService).

## 1. Map: QoL setting → accessibility need

| QoL setting (this section) | Accessibility need | Read |
|---|---|---|
| [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] | Motion sickness, vestibular disorders | [[Motion Sensitivity and Camera Comfort]] |
| [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] | Photosensitivity, migraine, cognitive load | [[Motion Sensitivity and Camera Comfort]], [[Difficulty Options and Cognitive Load]] |
| [[Audio Mixer Settings with SoundGroups]] | Hearing differences, sensory overload | [[Captions and Audio Accessibility]] |
| [[UI Scale HUD Hide and Compact Mode]] | Low vision, small screens | [[Readable Text and UI Scale]] |
| [[Colourblind Palettes Text Size and Tooltips]] | Colour vision deficiency, low vision, reading | [[Colour-Blind Safe Design]], [[Readable Text and UI Scale]] |
| [[Rebinding Controls with the Input Action System]] | Motor differences, one-handed play | [[Input Remapping and One-Handed Play]] |
| [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] | Fatigue, limited grip strength | [[Input Remapping and One-Handed Play]] |
| [[Mobile Button Layout Editor]] | Hand size, grip, single-thumb play | [[Input Remapping and One-Handed Play]] section 6 |
| [[Controller Support QoL]] | Alternative controllers, couch play | [[Gamepad and Console UX]] |
| [[Skippable Tutorials and Replayable Tips]] | Memory, attention, re-learning | [[Difficulty Options and Cognitive Load]] |
| [[Notification Queues and Limits]] | Attention, sensory overload | [[Difficulty Options and Cognitive Load]] |
| [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] | Reaction time, timing precision | [[Difficulty Options and Cognitive Load]] |
| [[Aim Assist and Generous Hitboxes]] | Fine motor control | [[Input Remapping and One-Handed Play]], [[Difficulty Options and Cognitive Load]] |

The general overview with Roblox's platform hooks is [[Accessibility]] (section 05); quick contrast rules are in [[Accessibility Contrast]].

## 2. Shared rules (do these once)

These apply to every setting in this section; section 42 explains each in depth.

1. **Respect platform preferences first.** `GuiService.ReducedMotionEnabled` and `GuiService.PreferredTextSize` are the player's stated wishes across all games (**Roblox docs**). Start from them; let your settings override in either direction.
2. **Settings reachable before they are needed.** The settings menu must be openable from the loading screen or the first second of play, not after the tutorial, because players who need large text or no flashes need it during the tutorial.
3. **Never only one channel.** Colour + shape, sound + caption, vibration + visual. A setting that turns off one channel must leave another.
4. **Settings menu itself accessible**: navigable by gamepad, readable at large text, no hover-only explanations, works with UI scale at maximum.
5. **Persist everything** server-side ([[Settings Menu Essentials and Persistence]]) so players set things once, not every session.
6. **Name options by effect** ("Reduce screen flashes", "Larger text"), not by diagnosis.

## 3. Where QoL and accessibility disagree

- **Difficulty**: aim assist and generous timing windows help accessibility but change competitive balance. Offer them in casual modes, or as assists that are visible to others in ranked play. See [[Difficulty Options and Cognitive Load]].
- **Hiding the HUD**: great for screenshots, but must never hide critical warnings a player relies on.
- **Compact mode** saves space but must not shrink text below readable sizes; it removes elements, not legibility.
- **Auto-play features** (auto-sprint, auto-equip, auto-attack) reduce input load, and can conflict with anti-AFK rules; treat assisted input as active play when it is player-enabled and the player is present ([[AFK Detection Idle Kicks and AFK Reward Rules]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Same feature built twice | QoL and accessibility owned by different people | One settings schema, mapped here |
| Settings only after tutorial | Menu gated by progression | Settings from the first second |
| Accessibility toggles hidden in a separate tab no one opens | Siloed | Put them in the groups players look in (Audio, Camera, Interface) |
| Platform text size ignored | Game-only slider | Start from `PreferredTextSize` |

## Checklist

- [ ] Each QoL setting mapped to its accessibility need and implemented once.
- [ ] Platform preferences read and respected.
- [ ] Settings reachable from the loading screen.
- [ ] No setting removes the only channel for important information.
- [ ] Settings menu passes its own gamepad, large-text and max-scale test.

## See also

- [[Accessibility Start Here]]
- [[Accessibility]]
- [[Player QoL Start Here]]
- [[QoL Audit Checklist]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Accessibility Start Here]] · [[Settings Menu Essentials and Persistence]] · Difficulty Options and Cognitive Load
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Top 25 QoL Wins by Effort]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Quick Respawn and Spawn Protection]] · [[Loading Screen Skip and First-Session Goals]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Console and VR Release Checklists]]
<!-- related:end -->
