---
tags: [atlas, api, type/atlas, area/ui, area/animation, api/GuiService]
---
# GuiService

<!-- tldr:start -->
> [!tldr] TL;DR
> - GuiService is a client service: it is not created by scripts and its state is not replicated.
> - All three `GuiService` preferences honoured and listened to.
> - Reduced motion. When the player has reduced motion on (`GuiService.ReducedMotionEnabled`, Roblox docs as of October 2026), the...
> - `GuiService.ViewportDisplaySize` returns `Small`, `Medium` or `Large`, described as the physical rendering size of the viewport.
>
> Cost: TL;DR ~150 tok · whole note ~840 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

GuiService is a client service: it is not created by scripts and its state is not replicated. (from [[GuiService - Engine Reference Card]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- All three `GuiService` preferences honoured and listened to. ([[Accessibility]])
- Reduced motion. When the player has reduced motion on (`GuiService.ReducedMotionEnabled`, Roblox docs as of October 2026), the line appears at once. ([[Dialogue System End to End]])
- `GuiService.ViewportDisplaySize` returns `Small`, `Medium` or `Large`, described as the physical rendering size of the viewport. ([[Readable Text and UI Scale]])

## Mentioned in

53 notes in 21 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[Gamepad and Console UX]] · [[HUD Design]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Safe Areas and Insets]] · [[ScreenGui Fundamentals]] · [[UI Motion Language and Timing]] · [[Virtualized Lists and Large Inventories]]

### 08 Animation
[[Emotes and Social Animation]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Chase Cameras and Speed Effects for Vehicles]]

### 12 Performance Testing and Debugging
[[In-Game Bug Report Button with Automatic Context]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 42 Accessibility and Inclusive Design
[[Motion Sensitivity and Camera Comfort]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Readable Text and UI Scale]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Avatar Context Menus Profiles and Social Surfaces]]

### 58 Player QoL and Game Tweaks
[[Accessibility Cross-Links for QoL Settings]] · [[Colourblind Palettes Text Size and Tooltips]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Controller Support QoL]]

### 62 Engine Reference Cards
[[GuiService - Engine Reference Card]]

Also mentioned in (not linked): AI Pitfalls - UI and Input · Bundles Animation Packs and Emotes for Sale · Camera Settings - FOV Shake Sensitivity and Shift-Lock · Camera Shake and Camera FX · Centre-Screen Announcements That Stay Centred · Console and VR Release Checklists · Designing Roblox UI in Figma - Frames, Safe Areas and Tokens · Engine Reference Cards Start Here · Game Feel and Juice · Input - UserInputService and ContextActionService · Instance Streaming · LihFolk UI Spec · Menu Archetypes - Shop Settings Codes Rewards · Mobile Button Layout Editor · Mobile and Low-End Optimization · Official Docs - UI · Open Questions - Whole Vault · Reward Moments and Celebrations · Safe Area · Settings Menu Design for Roblox - Layout, Controls and Motion · Settings Menu Essentials and Persistence · Skill - Roblox UI Builder · Text Fonts and Rich Text · UI Automation with VirtualInput and StudioTestService · UI Scale HUD Hide and Compact Mode · UI and GUI Animation · UserInputService - Engine Reference Card · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer

<!-- atlas:generated -->
