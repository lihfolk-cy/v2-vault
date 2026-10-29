---
tags: [ui, icons, style, shine, lihfolk, type/guide, area/ui, level/beginner, area/marketing]
verified: 2026-10-29
---
# Glossy Icon Style: Owner Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Thin or black outlines: they lose the toy look and vanish at 32 px.
> - Avoid: Smooth gradient shading instead of a crisp two-tone split: it looks generic.
> - Avoid: A shine streak that runs the full length of the edge: it reads as a second outline.
>
> Cost: TL;DR ~100 tok · whole note ~580 tok. Read more: ## Recipe · ## Common mistakes
<!-- tldr:end -->

The LihFolk owner picked a chunky, glossy mouse-pointer icon as the reference for icon art. The thing to copy is **the shine**: the icon looks like a carved, hard-candy solid, not a flat sticker.

## Recipe

| Part | Rule |
|---|---|
| Silhouette | One bold shape, tilted 15-25°, rounded corners, fills about 75% of the tile, readable at 32 px |
| Outline | Thick, uniform dark navy (about `#1c2440`), 6-8% of the icon width; never black, never thin |
| Facets | Split along the main ridge: the lit side is near-white; the shade side is cool pale blue-grey (`#b9c6d8` to `#8fa0b8`). Crisp split, no blur |
| Specular streak | A pure white band just inside the outline on the lit edge. It starts at the tip, tapers and fades out about halfway |
| Tip glint | A small white hot spot at the tip |
| Bounce rim | A faint lighter line on the shade facet against the outline, so the dark side never goes flat |
| Light | Always from the top left, the same across the set |
| Shadow | At most a small soft drop shadow, low opacity, down and right, in the ink colour. No outer glow |

The highlights pair hard inner edges with soft fading tails, and that combination is what reads as gloss. Fully soft highlights read as matte plastic. Fully hard ones read as cel-shaded.

For coloured icons (coin, gem, star), keep the same recipe: base hue on the lit side, a darker shade of it on the shade side, white shine and navy ink.

## Common mistakes

- Thin or black outlines: they lose the toy look and vanish at 32 px.
- Smooth gradient shading instead of a crisp two-tone split: it looks generic.
- A shine streak that runs the full length of the edge: it reads as a second outline. Let it fade.
- Mixed light directions within one icon set.

## See also

- [[LihFolk UI Design System]]
- `lihfolk-ui` skill, section "Icon art style"

<!-- related:start -->
## Related
[[VFX Readability and Value - Lessons from Blind Reviews]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Hand-Painted and Stylized Texturing]] · [[UI Style Directions - A Visual Vocabulary for Briefs]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[LihFolk UI Spec]]
<!-- related:end -->
