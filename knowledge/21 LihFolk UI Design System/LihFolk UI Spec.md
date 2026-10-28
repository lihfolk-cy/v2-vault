---
tags: [ui, design-system, lihfolk-ui, tokens, spec, motion, accessibility]
---
# LihFolk UI Spec

The numbers behind [[LihFolk UI Design System]]. The source of truth is `skills/lihfolk-ui/src/LihFolkUITheme.luau`. If this note and the module ever disagree, the module wins, and this note should be fixed.

All sizes are **design units**: pixels at a UIScale of 1. The controller scales them per device (section 6).

---

## 1. Palette

| Token | Hex | Use | Contrast |
|---|---|---|---|
| ink | `#160F2B` | Outlines, text strokes | |
| dusk | `#2D2852` | Panel canvas | |
| duskRaised | `#3B3566` | Card body (bottom of gradient) | |
| duskRaisedHi | `#4A437A` | Card top | |
| duskSunken | `#1F1B3D` | Tracks, text fields | |
| line | `#57508F` | Dividers (65% opaque) | |
| textHi | `#FFFFFF` | Titles, primary text | 13.7:1 dusk, 11.1:1 card |
| textMid | `#D6D0F5` | Body | 9.2:1 dusk, 7.5:1 card |
| textLow | `#B0A9DD` | Captions, placeholders | 6.2:1 dusk, 5.1:1 card |
| positive | `#7BF5A6` | Success line | 10.1:1 dusk |
| negative | `#FF8FA8` | Error line | 6.3:1 dusk |
| gold | `#FFD24A` | Featured outline, sunburst | |
| backdrop | `#0B0718` | Dimmer at 0.45 transparency | |

## 2. Roles (button and slab colours)

| Role | Face top | Face bottom | Lip | Text | Ink-to-face contrast | Oklab L (bottom) |
|---|---|---|---|---|---|---|
| go | `#7BF5A6` | `#25C773` | `#12804A` | white + ink stroke | 8.3:1 | 0.73 |
| neutral | `#9C94DB` | `#6E66B3` | `#40397A` | white + ink stroke | 3.7:1 (white 5.0:1) | 0.55 |
| premium | `#FFE27A` | `#FFB224` | `#B06B00` | white + ink stroke | 10.2:1 | 0.82 |
| danger | `#FF7A98` | `#EE3D66` | `#9A1838` | white + ink stroke | 4.8:1 | 0.64 |
| info | `#7CC8FF` | `#3D93F0` | `#1D58A8` | white + ink stroke | 5.8:1 | 0.66 |
| done | `#ECE9FA` | `#C4BEE0` | `#827BA8` | `#2D2852`, no stroke | text 7.7:1 | 0.82 |
| locked | `#4F4980` | `#3A3466` | `#221D42` | `#B3ACDB`, no stroke | text 5.3:1 | 0.36 |

Faces are a three-stop vertical gradient: top, a 55 percent mix at 45 percent height, then bottom. The face Frame is white and the UIGradient supplies the colour.

## 3. Menu themes (header slab and candy bands)

| Theme | Top | Bottom | Lip |
|---|---|---|---|
| shop (Tangerine) | `#FFB54D` | `#FF7B22` | `#B9480A` |
| codes (Lagoon) | `#5DEBDB` | `#18B5C6` | `#0C6F80` |
| rebirth (Orchid) | `#CF9BFF` | `#9257F2` | `#5A2AAE` |
| settings (Denim) | `#86AEFF` | `#4F7BEA` | `#2B4CA3` |
| daily (Bubblegum) | `#FF9ACD` | `#F25AA2` | `#A82568` |
| neutral (Lilac) | `#9C94DB` | `#6E66B3` | `#40397A` |

Candy bands use one Frame filled with the theme's top colour and one UIGradient at Rotation 32. Its transparency alternates between 1 and 0.9 across 13 keypoints, which gives 6 soft bands. If a `pattern` tile is registered, it replaces the bands as a tiled image (96 x 96, 0.9 transparency).

## 4. Typography

| Style | Font | Size | Stroke | Typical use |
|---|---|---|---|---|
| display | Fredoka One | 36 | 3.5 ink | Window title (scaled to fit) |
| title | Fredoka One | 26 | 2.5 | Section headers, card names |
| button | Fredoka One | 24 | 2.5 | Button captions (scaled, capped) |
| number | Fredoka One | 30 | 3 | Prices, amounts, multipliers |
| small | Fredoka One | 18 | 2 | Pills, bar labels, day tags, row labels |
| body | Builder Sans Bold | 18 | none | Descriptions |
| caption | Builder Sans SemiBold | 15 | none | Hints, timers, status lines |

- Font assets: `rbxasset://fonts/families/FredokaOne.json` (Regular; the face is heavy by design) and `rbxasset://fonts/families/BuilderSans.json` (Bold and SemiBold).
- Strokes: `UIStroke`, Contextual, round joins, about 9 to 10 percent of the size.
- Minimum: 15 design units. At the 0.846 touch floor that draws at about 12.7 px, above the 12 px phone floor in [[Readable Text and UI Scale]].
- Fitting: captions and titles use `TextScaled` capped at the style size. Fixed labels truncate with an ellipsis. Nothing overflows.

## 5. Spacing, radii, strokes, sizes

| Group | Values |
|---|---|
| Spacing | xs 4, sm 8, md 12, lg 16, xl 24, xxl 32 |
| Radii | panel 22, header 14, card 14, button 12, input 10, pill = half height |
| Strokes | panel 4, card 3, button 3, input 2.5, focus 3, divider 2 |
| Buttons | height 56, lip 6 (small: 4), touch box 52 minimum, close 52 round, HUD 64 |
| Window | default 760 x 520; header 72 incl. lip, inset 8; body inset 16, top at 92 |
| Controls | toggle 84 x 40 (knob 32), progress 30 high (fill inset 4), text field 56 |
| Cards | shop 220 x 236, daily 156 x 196 (day 7: 324 x 196), tier cards half width x 176 |

Nested radius rule: the inner radius equals the outer radius minus the gap. The header's 14 is the panel's 22 minus the 8 px inset.

## 6. Responsive rules

| Rule | Value |
|---|---|
| Layers | Backdrop `ScreenInsets.None` (DisplayOrder 40), main `CoreUISafeInsets` (41); both `SafeAreaCompatibility.None`, `ResetOnSpawn = false`, Sibling ZIndex |
| Device base scale | phone 1.0; desktop / tablet `clamp(safeHeight / 1000, 0.85, 1.4)`; console (large display or ten-foot) 1.35 |
| Phone | touch device with safe-area short side under 520 px |
| Fit | `scale = max(min(base x player, fit), touchFloor)`, with `fit` computed against the safe area minus a 16 px margin |
| Touch floor | 44 / 52 = 0.846 on touch devices, so a 52-unit target draws at 44 px or more |
| Overflow | If the floor beats the fit, the slot shrinks to `available / scale` and the body scrolls |
| Player scale | 0.8 to 1.3; the fit clamp still wins |
| HUD launcher | Left edge, vertically centred, 16 px margin, scaled like windows (capped at 1.3) |

Test viewports: 1920 x 1080, 1366 x 768, 1024 x 768 (touch), 844 x 390, 667 x 375. Test both landscape directions on a notched profile.

## 7. Components

| Component | Anatomy | States |
|---|---|---|
| Window | Slot (Fit UIScale) > Panel (Motion UIScale, dusk, ink 4) > bands, header slab (icon chip, title, action, close), scrolling body (8 padding, 12 gap) | open, closing, closed |
| Button | Slot > Body (centre anchor, Fx UIScale) > Base (lip colour, ink 3) + Face (gradient, ZIndex 2) > icon + label; invisible Hit on top | default, hover, pressed, selected, disabled |
| StateButton | Button + Glow ring (ZIndex 0) | claim, claimed, locked, skip, pending |
| CurrencyButton | Button with currency icon, `number` caption | per role |
| Card | Gradient duskRaisedHi to duskRaised, ink 3, padded content | default, featured (gold 4) |
| ProgressBar | Sunken track + top recess shade + inset fill (gradient, gloss, minimum sliver) + label | empty, filling, full |
| TierCompare | NOW card, nudging arrow, NEXT card (featured, value in theme colour) | |
| RewardCard | Day tag, icon area (sunburst if featured), amount, StateButton; veil and tick when claimed | claim, claimed, locked, pending |
| Toggle | Pill track (go or locked colour) with ON/OFF text, white knob | on, off |
| SettingRow | Card row: icon, label, description, toggle; the row is the hit area | |
| TextInput | Sunken field, focus ring (info top, 3), status line | idle, focused, ok, error (shake) |
| HudButton | 64 slab in the menu colour, caption, `!` badge | badge on or off |

## 8. Motion

| Interaction | Property | Value |
|---|---|---|
| Open | Motion `UIScale.Scale` | 0.86 to 1, 0.22 s, Back Out (time scaled by the remaining fraction) |
| Close | Motion `UIScale.Scale` | to 0.90, 0.12 s, Quad In, hide only on Completed |
| Dimmer | BackgroundTransparency | to 0.45 in 0.18 s Quad Out; out in 0.12 s Quad In |
| Hover / select | Fx `UIScale.Scale` | 1.04, 0.10 s Quad Out |
| Press | Face Position + Fx scale | sink by lip - 2, scale 0.96, 0.05 s Quad Out |
| Release | same | 0.16 s Back Out |
| Toggle | Knob Position, track colour | 0.16 s Quad Out |
| Progress | Fill Size | 0.35 s Quad Out |
| Claim glow | Stroke Transparency | 0.35 to 0.85, 0.8 s Sine InOut, looping |
| Tier arrow | Position | ±3 px, 0.6 s Sine InOut, looping |
| Sunburst | Spinner Rotation | 0 to 360 in 16 s Linear, looping |
| Error shake | Field Position | 8, -8, 5, -5, 2, 0 px at 0.04 s |

Loops belong to a window: they play on open and pause on close. Under Reduced Motion (`GuiService.ReducedMotionEnabled` or the player's setting), there is no scale, spin, glow pulse, nudge or shake. State still changes instantly and the dimmer still fades.

## 9. Icons

The registry `LihFolkUIIcons.Assets` maps names to `rbxassetid://` strings and ships with every value empty. Fallbacks: a circle, a rounded square (corner 0.28) or a diamond (a square at 45 degrees, 68 percent size). Each has an ink outline of 2.5, a lightened top gradient and a Fredoka glyph with an ink stroke of 2. Names: close, back, info, check, lock, timer, arrow_right, plus, shop, codes, rebirth, settings, daily, coin, gem, robux, cash, gift, star, crown, boost, pet, music, sound, motion, eye, scale, pattern, sunburst. Unknown names draw a `?` circle. Invalid asset strings warn once and draw the fallback.

---

## Common mistakes

- Changing a hex in a component instead of in the Theme. The kit drifts and the audit is lost.
- Using `Size` tweens for pops or animating `UIStroke.Thickness` on text.
- Setting text below 15 design units, or turning `TextScaled` off without a size cap or truncation.
- A 40 px visual button without a hit pad. The kit adds one, but hand-made buttons forget it.
- Edge art in the safe-area layer, or tappable UI in the `None` layer.
- Locked and claimed states that differ only in hue.

## Checklist

- [ ] Every colour, size and timing used comes from `LihFolkUITheme`.
- [ ] Text meets the contrast column above; bright slabs keep the ink stroke.
- [ ] Tap targets are at least 52 units (44 px drawn) with at least 8 px between them.
- [ ] Motion matches section 8 and stops under Reduced Motion.
- [ ] Layout checked at all five viewports.

## See also

- [[LihFolk UI Design System]]: overview and how to use.
- [[UI Design Systems]], [[UI Motion Language and Timing]], [[Text Fonts and Rich Text]].
- [[Safe Areas and Insets]], [[Responsive UI for Phone Tablet Console and PC]], [[Safe Area]].
- [[Readable Text and UI Scale]], [[Colour-Blind Safe Design]], [[Gamepad and Console UX]].

License: this note is CC BY 4.0 (LihFolk). The LihFolk UI code is free to use and modify in your games.

## Connected notes
<!-- auto-links:start -->
<!-- auto-links:end -->
