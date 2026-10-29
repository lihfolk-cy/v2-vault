---
tags: [atlas, api, type/atlas, area/ui, area/animation, api/UIStroke]
---
# UIStroke

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UIStroke.ApplyStrokeMode` is `Contextual` by default, which on a text object outlines the glyph shapes; `Border` outlines the...
> - Avoid: Using `Size` tweens for pops or animating `UIStroke.Thickness` on text.
> - Set `UIStroke.StrokeSizingMode` to `ScaledSize` so thickness is relative to the text size (listed in Text Fonts and Rich Text...
> - Rounded heavy fonts such as Fredoka One need less: above about 7% the stroke fills the holes in 0, a and e (UIStroke on Text...
>
> Cost: TL;DR ~160 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UIStroke.ApplyStrokeMode` is `Contextual` by default, which on a text object outlines the glyph shapes; `Border` outlines the box instead (Roblox docs). (from [[UIStroke on Text - Glyph Counters and the Stroke Ratio]])

API snapshot: class, inherits `UIComponent` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Using `Size` tweens for pops or animating `UIStroke.Thickness` on text. ([[LihFolk UI Spec]])
- Set `UIStroke.StrokeSizingMode` to `ScaledSize` so thickness is relative to the text size (listed in Text Fonts and Rich Text from the docs), and pick the ratio once. ([[UIStroke on Text - Glyph Counters and the Stroke Ratio]])
- Rounded heavy fonts such as Fredoka One need less: above about 7% the stroke fills the holes in 0, a and e (UIStroke on Text - Glyph Counters and the Stroke Ratio). ([[Text Fonts and Rich Text]])
- `UIStroke` with `ApplyStrokeMode.Border` draws centred on the border by default. ([[Layout - Scale Offset and Constraints]])

## Mentioned in

22 notes in 11 sections. The 22 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[Layout - Scale Offset and Constraints]] · [[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Safe Areas and Insets]] · [[ScreenGui Fundamentals]] · [[Text Fonts and Rich Text]] · [[UI Design Systems]] · [[UI Motion Language and Timing]] · [[Virtualized Lists and Large Inventories]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]]

### 08 Animation
[[Reference - Purple Anime Settings UI (Claude + Figma)]] · [[UI and GUI Animation]]

### 17 Pipelines
[[UI Asset Pipeline]]

### 21 LihFolk UI Design System
[[LihFolk UI Spec]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]] · [[Readable Text and UI Scale]]

### 46 Resource Library
[[Links - Layouts and constraints]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]]

### 52 Core Concepts
[[Accessibility Contrast]]

### 56 Field Notes
[[Field Notes Start Here]] · [[UIStroke on Text - Glyph Counters and the Stroke Ratio]]

<!-- atlas:generated -->
