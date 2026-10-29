---
tags: [core-concept, marketing, art, thumbnails, ui, type/reference, area/ui, level/beginner, area/marketing]
---
# Thumbnail Contrast

<!-- tldr:start -->
> [!tldr] TL;DR
> - Experience icons appear tiny on phones, in rows of similar tiles, often on a dark theme.
> - Test at real size. Shrink the icon to about 100 pixels wide and view it next to ten competitors' icons.
> - Value contrast beats colour. Two different hues of the same brightness blur together, especially for colour-blind viewers.
> - One subject, big. A character or object filling 50 to 70 percent of the frame (rule of thumb from studying top games) reads; a...
>
> Cost: TL;DR ~150 tok · whole note ~930 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Thumbnail contrast** is how strongly the subject of an icon or thumbnail separates from its background and from neighbouring tiles: value contrast (light against dark), colour contrast (complementary hues), and shape contrast (a clear silhouette). It decides whether a tile can be read at a glance at small size.

## Why it matters on Roblox

Experience icons appear tiny on phones, in rows of similar tiles, often on a dark theme. A beautiful, detailed image with mid-tones everywhere turns into grey mush at that size. High-contrast tiles are read first, which directly drives [[Click-Through Rate]].

## The nuance most people miss

1. **Test at real size.** Shrink the icon to about 100 pixels wide and view it next to ten competitors' icons. If you cannot tell what it is in half a second, contrast or composition is wrong. Squinting at it (or blurring it) shows value contrast quickly.
2. **Value contrast beats colour.** Two different hues of the same brightness blur together, especially for colour-blind viewers. Check the image in greyscale.
3. **One subject, big.** A character or object filling 50 to 70 percent of the frame (rule of thumb from studying top games) reads; a wide scene with ten small elements does not.
4. **Stand out from the row, not just from black.** If every tile in your genre is saturated yellow, a saturated yellow tile is camouflage. Look at the actual sort you will appear in.
5. **Dark and light themes both exist.** A thin white outline that pops on dark mode may vanish on light mode. A subject with its own dark outline and a bright rim works on both.
6. **Text adds little on tiles.** At icon size, small text is unreadable and the title already appears below. Short, very large text can work on thumbnails; never on the icon.

## Tiny example

A sword icon: version A shows a silver sword on a grey stone background (low value contrast). Version B shows the same sword with a warm rim light, a dark outline and a saturated blue radial background. In greyscale, A is a grey rectangle; B is a bright shape on a dark field. B will be read first in a row.

## Where this shows up

- [[Thumbnails Icons and Store Page]]: the main design note.
- [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]: patterns from top games.
- [[Icon and Thumbnail Rendering Pipeline]]: lighting renders for contrast.
- [[Dramatic Showcase Renders in Eevee]]: rim lights and backgrounds in Blender.
- [[Colour-Blind Safe Design]]: value over hue.
- [[Posing and Silhouettes]]: shape contrast from posing.
- [[Stylized Lighting Recipes]]: rim and key lights.
- [[UI Asset Pipeline]]: the same contrast rules for in-game item icons.
- [[AI Image Generation for Icons Thumbnails and Concepts]]: generated variants and their contrast pitfalls.
- [[Competitor Analysis Method]]: studying the row you will sit in.
- [[Environment Art Styles]]: style choices that read at small sizes.

Related concepts: [[Click-Through Rate]], [[Accessibility Contrast]], [[Texel Density]].

## Connected notes
<!-- auto-links:start -->
[[Colour Scripts and Value Structure for Untextured Art]] · Voxel Palettes - Ramps Hue Shifting and Limits · Shape Language and Silhouette Testing · [[Core Concepts Start Here]] · Voxel and Blocky Modeling · Hand-Painted and Stylized Texturing
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Game Icon Design - Readable at Small Sizes]] · [[Draw Calls]] · [[Safe Area]] · [[Triangle Budget]] · [[VFX Readability and Value - Lessons from Blind Reviews]] · [[Shape Language and Silhouette Testing]]
<!-- related:end -->
