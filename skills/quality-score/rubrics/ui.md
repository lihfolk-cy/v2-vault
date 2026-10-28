# Rubric: UI screen / HUD

Sources: skills `roblox-ui-builder` and `lihfolk-ui`, Accessibility notes. Evidence: screenshots at phone (about 375 px wide), tablet and PC sizes via Studio MCP.

## Hard gates
- Nothing clipped or off-screen at phone, tablet and PC sizes; respects safe areas and the notch
- Every button reachable and at least about 44 px touch size on phone
- No overlapping elements; text never overflows its box
- Works with gamepad or keyboard navigation if the game supports them

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| U1 | Clarity: a new player knows what to press in 3 seconds | 3 | confusing | ok | instant |
| U2 | Visual hierarchy (one focal point, grouping, spacing rhythm) | 2 | flat | some | clear |
| U3 | Style consistency (fonts, strokes, palette, corner radius per the design system) | 2 | mixed | minor drift | consistent |
| U4 | Motion and feedback (hover, press, open and close tweens, sounds) | 2 | none | some | polished |
| U5 | Readability (contrast, font size on phone) | 2 | hard to read | ok | crisp |
| U6 | Performance (no per-frame UI rebuilds, pooled lists) | 1 | heavy | ok | lean |
