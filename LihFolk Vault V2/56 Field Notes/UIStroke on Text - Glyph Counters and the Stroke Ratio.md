---
tags: [field-notes, ui, uistroke, text, fonts, readability, numbers, type/guide, area/ui, level/intermediate, api/UIStroke, area/gameplay]
---
# UIStroke on Text - Glyph Counters and the Stroke Ratio

<!-- tldr:start -->
> [!tldr] TL;DR
> - "10" reads as "1" plus a blob: Stroke closes the 0's counter -> Stroke at or below 7% of text size for rounded fonts
> - "Fast" reads "Fust": "a" bowl filled -> Same; or a font with larger counters
> - Looks fine in Studio, bad on phone: Fixed-pixel stroke on `TextScaled` text that shrinks -> `ScaledSize` stroke or fixed text sizes
> - Stroke ratio set per font, measured on the rendered size.
> - Rounded heavy fonts at or below about 7% stroke.
> - Test string with 0, 6, 8, 9, a and e checked at the smallest size on a phone.
>
> Cost: TL;DR ~170 tok · whole note ~1.6k tok. Read more: ## What the stroke does to a glyph · ## How to test · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A thick outline makes cartoon text pop, and past a certain thickness it starts eating the letters. A `UIStroke` in `Contextual` mode grows outward *and* into the small enclosed holes of glyphs (the counters of 0, 6, 8, 9, a, e, o), so "10" and "20" turn into blobs and "Fast" reads as "Fust". This note gives the ratio that avoids it, why scaling does not help, and how to test. The general outline properties are in [[Text Fonts and Rich Text]]; minimum sizes in [[Readable Text and UI Scale]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## What the stroke does to a glyph

`UIStroke.ApplyStrokeMode` is `Contextual` by default, which on a text object outlines the glyph shapes; `Border` outlines the box instead (Roblox docs). The contextual stroke is drawn centred on, or outward from, the glyph edge, so it also grows *inward* into any closed counter. A counter only a few pixels wide closes completely once the stroke on each side meets in the middle.

Rounded, bubbly fonts are hit hardest. Fonts in the Fredoka family have soft, heavy strokes and small counters relative to their cap height; the "a" in a heavy weight has a counter about the size of a full stop at small sizes. Geometric fonts with big open counters (Gotham-style) tolerate thicker strokes.

**Measured.** In the reference project, stat labels in a heavy rounded font with a generous stroke:

- "10" and "20" read as a digit followed by a dark blob on phones.
- "Fast" read as "Fust": the closed bowl of the "a" filled in and the remaining shape matched a "u".

Thinning the stroke to the ratio below fixed both, with no visible loss of pop against busy backgrounds.

## The ratio

**Rule of thumb:** for rounded, heavy fonts such as Fredoka, keep `UIStroke.Thickness` at or below about **7% of the rendered text size**. For geometric fonts with large counters, the 8 to 15% range quoted in [[Text Fonts and Rich Text]] is workable. The difference between those two rules is the font, not taste: test the specific font and weight.

| Rendered text size | Max stroke, rounded heavy font (7%) | Typical geometric font (11%) |
|---|---|---|
| 14 px | 1 px | 1.5 px |
| 20 px | 1.4 px | 2.2 px |
| 28 px | 2 px | 3 px |
| 48 px | 3.4 px | 5.3 px |

Use the *rendered* size. With `TextScaled = true` the rendered size changes with the box and the device, while a pixel `Thickness` does not. Two fixes, either of which works:

- Set `UIStroke.StrokeSizingMode` to `ScaledSize` so thickness is relative to the text size (listed in [[Text Fonts and Rich Text]] from the docs), and pick the ratio once.
- Or avoid `TextScaled` for stroked text and use fixed sizes with a `UITextSizeConstraint`.

## Why UIScale does not fix it

The instinct is "the label is small on phones, so scale it up". A `UIScale` multiplies the whole subtree, stroke included (field-tested: scaling a stroked label up did not reopen a single counter). The stroke-to-glyph ratio stays exactly the same, so the counters stay closed, just larger. The only fixes are a thinner stroke relative to the text, a font with bigger counters, or a heavier weight change in the other direction (a lighter weight has larger counters).

Do not tween `Thickness` on text for a pulse effect either; the docs warn that it rebuilds glyph caches every frame. Pulse a `UIScale` instead, which keeps the ratio constant.

## How to test

1. **Test two-digit numbers, not words.** Make a test label with "10 20 60 80 88 00" and "Fast Speed Rage". Numbers with 0, 6, 8 and 9 close first; the "a" and "e" are the word tells.
2. Test at the **smallest rendered size** the label reaches, on a phone emulator at 1x, not in the Studio viewport at desktop size.
3. Test on the **real background**. A stroke that reads on a plain panel may be needed on a busy world view; if it is, add contrast with a backing pill or `UIGradient` rather than more stroke.
4. Squint test: blur your eyes or screenshot at 50%. If "10" looks like "1-blob", it fails.

A quick Studio check that flags risky strokes across a GUI:

```lua
-- Command bar: list stroked text whose stroke exceeds 7% of its rendered size.
for _, d in game:GetService("StarterGui"):GetDescendants() do
	if d:IsA("UIStroke") and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		local label = d.Parent
		if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
			local size = label.TextBounds.Y > 0 and label.TextBounds.Y or label.TextSize
			local ratio = d.Thickness / size
			if ratio > 0.07 then
				print(("%.0f%%  %s"):format(ratio * 100, label:GetFullName()))
			end
		end
	end
end
```

`TextBounds` is the rendered height of the text, which is the right denominator for scaled text (for single-line labels; for wrapped labels divide by the line count).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| "10" reads as "1" plus a blob | Stroke closes the 0's counter | Stroke at or below 7% of text size for rounded fonts |
| "Fast" reads "Fust" | "a" bowl filled | Same; or a font with larger counters |
| Looks fine in Studio, bad on phone | Fixed-pixel stroke on `TextScaled` text that shrinks | `ScaledSize` stroke or fixed text sizes |
| Scaled up with UIScale, still unreadable | UIScale preserves the ratio | Change the ratio, not the scale |
| Flicker when text pulses | Tweening stroke `Thickness` | Pulse a `UIScale` |

## Checklist

- [ ] Stroke ratio set per font, measured on the rendered size.
- [ ] Rounded heavy fonts at or below about 7% stroke.
- [ ] Test string with 0, 6, 8, 9, a and e checked at the smallest size on a phone.
- [ ] Scaled text uses `StrokeSizingMode = ScaledSize` or avoids `TextScaled`.
- [ ] No tweened text stroke thickness.

## Connected notes
<!-- auto-links:start -->
[[Text Fonts and Rich Text]] · Readable Text and UI Scale · Responsive UI for Phone Tablet Console and PC · Accessibility Contrast · [[Centre-Screen Announcements That Stay Centred]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Layout - Scale Offset and Constraints]] · [[UI Design Systems]] · [[Accessibility]] · [[LihFolk UI Spec]] · [[Shared Close Buttons and Headers Across Many Screens]] · [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]]
<!-- related:end -->
