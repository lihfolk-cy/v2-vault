---
tags: [core-concept, accessibility, ui, art, type/reference, area/ui, level/beginner, area/accessibility]
---
# Accessibility Contrast

<!-- tldr:start -->
> [!tldr] TL;DR
> - Roblox players read UI on small phone screens, outdoors, at low brightness, on TVs across a room, and with all kinds of vision.
> - Busy 3D backgrounds break any ratio. HUD text floats over a world that changes every second: sky, snow, lava.
> - Colour is not contrast. Red on green can have nearly the same brightness and becomes invisible for many colour-blind players.
> - Never carry meaning by colour alone. Rarity, team and status need a second cue: a shape, an icon, a label or a pattern.
>
> Cost: TL;DR ~160 tok · whole note ~940 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Accessibility contrast** is the difference in brightness between text (or an important icon) and what is behind it, measured as a contrast ratio from 1:1 (identical) to 21:1 (black on white). The common web standard, WCAG, asks for at least 4.5:1 for normal text and 3:1 for large text and essential graphics (WCAG 2.x, an external standard, not a Roblox rule).

## Why it matters on Roblox

Roblox players read UI on small phone screens, outdoors, at low brightness, on TVs across a room, and with all kinds of vision. Low-contrast text that looks stylish on a designer's monitor becomes unreadable in those conditions. Contrast is also not only for players with low vision: everyone reads high-contrast UI faster, which matters in combat and in shops.

## The nuance most people miss

1. **Busy 3D backgrounds break any ratio.** HUD text floats over a world that changes every second: sky, snow, lava. Put text on a panel, give it a `UIStroke` outline, or add a soft dark backing so contrast holds against anything.
2. **Colour is not contrast.** Red on green can have nearly the same brightness and becomes invisible for many colour-blind players. Check UI in greyscale; meaning must survive.
3. **Never carry meaning by colour alone.** Rarity, team and status need a second cue: a shape, an icon, a label or a pattern.
4. **Transparency lowers contrast.** A white label at 0.3 transparency over a mid-grey frame may fall far below 4.5:1. Measure the final, blended colours.
5. **Thin fonts need more contrast.** Contrast ratios assume reasonable stroke weight. Thin fonts at small sizes need higher contrast or a heavier weight.
6. **Disabled states still need to be readable.** A "locked" button that is too faint leaves players unable to read what it costs to unlock.

## Tiny example

```lua
-- Relative luminance and contrast ratio (WCAG formula).
local function lum(c: Color3): number
	local function ch(v: number)
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
end

local function contrast(a: Color3, b: Color3): number
	local la, lb = lum(a), lum(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

print(contrast(Color3.new(1, 1, 1), Color3.fromRGB(59, 88, 102))) -- about 7.6
```

## Where this shows up

- [[Accessibility]]: the overview.
- [[Colour-Blind Safe Design]]: meaning beyond colour.
- [[Readable Text and UI Scale]]: size and weight with contrast.
- [[Text Fonts and Rich Text]]: font choice and strokes.
- [[HUD Design]]: text over the 3D world.
- [[UI Design Systems]]: contrast as a design token rule.
- [[World-Space UI - BillboardGui and SurfaceGui]]: labels over any background.
- [[Captions and Audio Accessibility]]: readable captions.
- [[Menu Archetypes - Shop Settings Codes Rewards]]: locked and disabled states.
- [[Atmosphere Sky Clouds and Post-Processing]]: post effects that wash out UI-like elements in the world.
- [[Debugging UI Layout and Input]]: checking UI on real devices.

Related concepts: [[Safe Area]], [[Thumbnail Contrast]], [[Easing]].

## Connected notes
<!-- auto-links:start -->
[[Accessibility Start Here]] · Stylized Lighting Recipes · Skill - Roblox UI Builder · Colour Scripts and Value Structure for Untextured Art · Highlights and Selection Effects · UI Asset Pipeline · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Texel Density]] · [[Tween vs Spring]] · [[Draw Calls]] · [[Anticipation]] · [[Replication Boundary]] · [[Triangle Budget]] · [[Click-Through Rate]] · [[Hit-Stop]]
<!-- related:end -->
