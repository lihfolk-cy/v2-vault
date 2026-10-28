---
tags: [ui, design-system, lihfolk-ui, simulator, cartoon, menus, hud]
---
# LihFolk UI Design System

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating the kit as a style to imitate by hand instead of calling the components.
> - Avoid: Adding a second green button to a screen.
> - Avoid: Removing the ink stroke from captions on bright slabs.
> - Modules in `ReplicatedStorage/LihFolkUI`; one LocalScript per menu; `Controller.start()` and `register` called.
> - Each window has a theme, an icon, one `go` action and a `defaultSelection`.
> - Server owns every outcome; placeholders replaced.
>
> Read more (7 KB note): ## 1. The look: Ink and Candy · ## 3. How to use it · ## Common mistakes · ## Checklist
<!-- tldr:end -->

**LihFolk UI** is LihFolk's own design system for cartoon and simulator Roblox games. It comes with a typed Luau kit: theme tokens, components, a window controller and an icon registry. There are ready examples for the five menus every simulator needs (Shop, Codes, Rebirth, Settings, Daily Rewards) plus a buttons showcase. The skill that applies it is `skills/lihfolk-ui/` in the plugin. The exact numbers are in [[LihFolk UI Spec]].

---

## 1. The look: Ink and Candy

| Element | What it is | Why |
|---|---|---|
| Dusk canvas | Every panel body is deep violet `#2D2852` | One dark, calm surface keeps white and lavender text at 9 to 14:1 contrast in every menu |
| Ink outlines | `#160F2B` strokes on panels, cards, slabs and display text | Separates shapes on any background and keeps white captions readable on bright slabs |
| Candy slabs | Every pressable thing is a gradient face on a darker lip; pressing sinks the face | "If it has a lip, you can press it." A player learns the rule once and it holds everywhere |
| Inset header slab | The header is itself a tactile slab in the menu's colour, inset 8 px inside the panel | Gives each menu an identity and makes the header read as part of the same toy family |
| Candy bands | Faint diagonal bands across the panel, tinted with the menu colour (one UIGradient, no images) | Texture without noise; costs a single frame |
| Sunburst | Slowly turning rays behind featured rewards and best-value items | Draws the eye to the one thing you want looked at |
| Fredoka One + Builder Sans | A rounded heavy display face with ink outline; a clean UI face for body text | Friendly, legible at phone sizes, both built into Roblox |

Each menu owns a header colour: Shop **Tangerine**, Codes **Lagoon**, Rebirth **Orchid**, Settings **Denim**, Daily Rewards **Bubblegum**. The body stays dusk in every menu, so the colour identifies the menu without changing how text reads.

## 2. What is in the kit

| Module | Role |
|---|---|
| `LihFolkUITheme` | Palette, the seven button roles, the menu themes, type styles, spacing, radii, strokes, sizes, motion timings, sound slots, number formatting, the Reduced Motion check |
| `LihFolkUIIcons` | An icon registry that ships **empty**, with drawn fallbacks (shape + glyph) for every name |
| `LihFolkUIComponents` | Window, Button, StateButton, CurrencyButton, CloseButton, HeaderAction, HudButton, SectionHeader, Card, Pill, ProgressBar, TierCompare, RewardCard, Toggle, SettingRow, TextInput, Sunburst, Pattern, Row, Grid, Text |
| `LihFolkUIController` | Safe-area screen layers, responsive fit with a touch floor, open and close motion, dimmer, one-menu-at-a-time, gamepad focus and ButtonB close, HUD launcher with badges |

## 3. How to use it

1. Put the four modules in `ReplicatedStorage/LihFolkUI` (with Rojo, map `src/` there).
2. Copy the example closest to your menu into `StarterPlayerScripts` (files ending in `.client.luau` become LocalScripts).
3. Change the content: window name and title, theme, items, and the remote names your server uses.
4. Replace placeholders: every `id = 0` (game passes, products) and any icon you want to show as art.
5. Build the server side with [[Skill - Roblox System Builder]]: the UI renders state the server owns and sends intents. It never decides prices, rewards or rebirths.
6. Test at phone, tablet and PC sizes with touch, mouse and gamepad, then score against the UI rubric (see section 5).

```lua
local UI = game:GetService("ReplicatedStorage"):WaitForChild("LihFolkUI")
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

Controller.start()
local window = C.Window({ name = "Quests", title = "Quests", theme = "codes", icon = "star" })
C.SectionHeader("Today", "codes", 1, window.body)
C.ProgressBar({ value = 0.4, text = "4 / 10 Coins collected", layoutOrder = 2, parent = window.body })
C.StateButton({ state = "locked", texts = { locked = "NOT DONE" }, layoutOrder = 3, window = window, parent = window.body })
Controller.register(window)
Controller.addHudButton({ window = "Quests", label = "Quests", icon = "star", theme = "codes" })
```

## 4. The five menus at a glance

| Menu | Focal action | Signature detail |
|---|---|---|
| Shop | Price buttons | Passes then products; one featured product with a gold outline, sunburst and BEST VALUE pill; owned passes become OWNED |
| Codes | REDEEM | One field, a status line with a tick or `!`, a shake on error, CHECKING... while the request is out |
| Rebirth | REBIRTH | NOW to NEXT tier cards, a recessed progress bar, a line saying what resets, a two-tap confirm, a paid Skip |
| Settings | Toggles | One row per option, the whole row tappable, Reduced Motion defaulting to the platform setting, RESET in the header |
| Daily Rewards | CLAIM | Days 1 to 4 on top, days 5 to 6 plus a double-width day-7 big-reward card below, a UTC countdown, a HUD badge when ready |

## 5. Quality bar

LihFolk scores UI with `skills/quality-score/rubrics/ui.md`. The bar is 9.0. The kit passes the hard gates by design: fit and touch floor, scrolling bodies, hit pads, text limits, selection rings. **Your content can still break them.** The criterion that most often costs the 9 is U1 (clarity, weight 3). Keep one green action with a verb on it, and say why a button is locked.

---

## Common mistakes

- Treating the kit as a style to imitate by hand instead of calling the components. Hand-built frames drift within a week.
- Adding a second green button to a screen.
- Removing the ink stroke from captions on bright slabs.
- Parenting a window to a custom ScreenGui, which bypasses fitting, focus and the dimmer.
- Using the colours as the only state signal (see [[Colour-Blind Safe Design]]).
- Leaving `id = 0` placeholders in a published game, or pasting icon ids found online.
- Letting the client grant anything: rewards, owned passes or rebirths.

## Checklist

- [ ] Modules in `ReplicatedStorage/LihFolkUI`; one LocalScript per menu; `Controller.start()` and `register` called.
- [ ] Each window has a theme, an icon, one `go` action and a `defaultSelection`.
- [ ] Server owns every outcome; placeholders replaced.
- [ ] Tested at 1920 x 1080, 1366 x 768, 1024 x 768 touch, 844 x 390, 667 x 375; touch, mouse, gamepad; Reduced Motion; UI scale 1.3.
- [ ] Scored 9.0 or higher on the UI rubric and logged.

## See also

- [[LihFolk UI Spec]]: tokens, sizes, components, motion, in numbers.
- [[UI Design Systems]]: what a design system contains and how systems decay.
- [[Menu Archetypes - Shop Settings Codes Rewards]]: menu anatomy and the server rules behind each menu.
- [[Safe Areas and Insets]] and [[Safe Area]]: the two-layer pattern the controller uses.
- [[Responsive UI for Phone Tablet Console and PC]]: device classes and test viewports.
- [[UI Motion Language and Timing]]: interruption rules the controller follows.
- [[Text Fonts and Rich Text]]: font choice and stroke thickness.
- [[Readable Text and UI Scale]], [[Colour-Blind Safe Design]], [[Accessibility]].
- [[Gamepad and Console UX]]: selection and focus.

License: this note is CC BY 4.0 (LihFolk). The LihFolk UI code is free to use and modify in your games.

## Connected notes
<!-- auto-links:start -->
<!-- auto-links:end -->
