---
tags: [atlas, concept, type/atlas, area/ui, area/animation]
---
# Reduced Motion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Reduced motion is a three-way choice: Follow Roblox setting, On, Off.
> - Shake 0-100%, applied at the sum point, starts low under reduced motion.
> - A "flashes" setting is separate from reduced motion.
> - `Motion.to` returns `nil` when there is nothing to animate (reduced motion with only motion properties).
>
> Cost: TL;DR ~120 tok · whole note ~660 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Reduced motion is a three-way choice: Follow Roblox setting, On, Off. (from [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]])

Reduced motion is a spectrum. `ReducedMotionEnabled` is binary, but players who need it differ. (from [[Snippets - Camera Shake and FX]])

## Key facts

- Shake 0-100%, applied at the sum point, starts low under reduced motion. ([[Camera Settings - FOV Shake Sensitivity and Shift-Lock]])
- A "flashes" setting is separate from reduced motion. Some players are fine with motion but not flashes, and the reverse. ([[Motion Sensitivity and Camera Comfort]])
- `Motion.to` returns `nil` when there is nothing to animate (reduced motion with only motion properties). ([[UI Motion Language and Timing]])

## Mentioned in

36 notes in 11 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[Declarative UI - React-Lua and Fusion]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[UI Motion Language and Timing]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]]

### 08 Animation
[[Camera Shake and Camera FX]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Reference - Purple Anime Settings UI (Claude + Figma)]] · [[Snippets - Camera Shake and FX]] · [[UI and GUI Animation]]

### 09 Gameplay Systems
[[Camera Systems]] · [[Custom Character Controllers]]

### 21 LihFolk UI Design System
[[LihFolk UI Design System]] · [[LihFolk UI Spec]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]] · [[Motion Sensitivity and Camera Comfort]] · [[Onboarding Accessibility and Cross-Device Prompts]]

### 47 Game Feel and Juice
[[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Reward Moments and Celebrations]] · [[Squash Stretch and Anticipation in UI and Characters]]

### 56 Field Notes
[[Layering Camera Feedback on the Default Camera]]

### 58 Player QoL and Game Tweaks
[[Accessibility Cross-Links for QoL Settings]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]

Also mentioned in (not linked): Game Feel Start Here · Narrative Start Here · Notification and Toast Systems · Onboarding and FTUE - Tutorials That Keep Players · QA Checklists Before Release · QoL Audit Checklist · Readable Text and UI Scale · Settings Menu Essentials and Persistence · Tutorial Step Design Patterns - Teach by Doing · UI Design Systems · Writing Dialogue for Roblox Players

<!-- atlas:generated -->
