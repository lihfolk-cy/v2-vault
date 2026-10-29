---
tags: [atlas, api, type/atlas, area/ui, area/gameplay, api/AnchorPoint]
---
# AnchorPoint

<!-- tldr:start -->
> [!tldr] TL;DR
> - `AnchorPoint` was left at (0, 0), so the label's *left edge* sat at the centre, pushing it right by half its own width.
> - Message sits right of centre on some devices: Offset from a width measured on another container -> `AnchorPoint (0.5, 0.5)`...
> - Off-centre by half the label width: `AnchorPoint` left at (0, 0) -> Centre anchor.
> - Pop grows from a corner: Default AnchorPoint -> Scale about the centre.
>
> Cost: TL;DR ~140 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`AnchorPoint` was left at (0, 0), so the label's *left edge* sat at the centre, pushing it right by half its own width. (from [[Centre-Screen Announcements That Stay Centred]]; Measured)

API snapshot: member of `GuiObject`, `StudioCallout` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Message sits right of centre on some devices: Offset from a width measured on another container -> `AnchorPoint (0.5, 0.5)` and scale 0.5. ([[Centre-Screen Announcements That Stay Centred]])
- Off-centre by half the label width: `AnchorPoint` left at (0, 0) -> Centre anchor. ([[Centre-Screen Announcements That Stay Centred]])
- Pop grows from a corner: Default AnchorPoint -> Scale about the centre. ([[UI and GUI Animation]])
- Constraints converted to `AnchorPoint`, Position and Size per the table. ([[Figma Property Mapping for Roblox UI]])
- Corner widgets drift off screen: Wrong `AnchorPoint` -> Anchor at the corner they hug. ([[UI Scale HUD Hide and Compact Mode]])

## Mentioned in

23 notes in 10 sections. The 23 most relevant are linked:

### 05 UI and UX
[[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]] · [[Figma Property Mapping for Roblox UI]] · [[Figma to Roblox UI - Pipeline and Handoff]] · [[Layout - Scale Offset and Constraints]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Race HUD - Position, Laps, Splits, Speedometer and Minimap]] · [[ScreenGui Fundamentals]] · [[UI Design Systems]] · [[UI Layout Objects - Lists Grids and Pages]]

### 08 Animation
[[UI and GUI Animation]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Daily Rewards System End to End]] · [[Saved Inventory End to End]] · [[Shop with Game Passes and Developer Products End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 46 Resource Library
[[Official Docs - UI]]

### 47 Game Feel and Juice
[[Squash Stretch and Anticipation in UI and Characters]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]

### 56 Field Notes
[[Centre-Screen Announcements That Stay Centred]] · [[Shared Close Buttons and Headers Across Many Screens]]

### 58 Player QoL and Game Tweaks
[[UI Scale HUD Hide and Compact Mode]]

<!-- atlas:generated -->
