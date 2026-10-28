---
name: lihfolk-ui
description: 'LihFolk: house cartoon/simulator UI kit (Luau components) for shop, codes, rebirth, settings, daily rewards, HUD, buttons, progress bars; also "UI broken on phone" / "buttons too small".'
---

# LihFolk UI

LihFolk UI is an original cartoon and simulator UI kit for Roblox. Its look is called **Ink and Candy**: a deep dusk-violet canvas, thick ink outlines, candy-coloured tactile slabs that sink when pressed, faint diagonal candy bands tinted with each menu's colour, and Fredoka One display type with ink outlines. Every menu gets its own header colour, and every menu is plainly part of the same family.

The kit is in `src/` and runs as is. The examples in `examples/` build the five menu types players expect in a simulator. This file gives the rules. The modules already apply them, so build with the modules and do not hand-place frames.

## Inputs

- `VAULT`: the LihFolk knowledge base at `../../knowledge/` (plugin root `knowledge/`). The overview and the full spec are in `VAULT/21 LihFolk UI Design System/`.
- Kit: `src/LihFolkUITheme.luau`, `src/LihFolkUIIcons.luau`, `src/LihFolkUIComponents.luau`, `src/LihFolkUIController.luau`.
- Examples: `examples/ShopMenu`, `CodesMenu`, `RebirthMenu`, `SettingsMenu`, `DailyRewardsMenu`, `ButtonsShowcase` (all `.client.luau`).
- Quality bar: `../quality-score/rubrics/ui.md`. The minimum is **8.5**.

## Install

```
ReplicatedStorage
  LihFolkUI (Folder)
    LihFolkUITheme        ModuleScript   <- src/LihFolkUITheme.luau
    LihFolkUIIcons        ModuleScript   <- src/LihFolkUIIcons.luau
    LihFolkUIComponents   ModuleScript   <- src/LihFolkUIComponents.luau
    LihFolkUIController   ModuleScript   <- src/LihFolkUIController.luau
StarterPlayer/StarterPlayerScripts
  ShopMenu, CodesMenu, ...  LocalScripts <- examples/*.client.luau (pick what you need)
```

With Rojo, map `src/` to `ReplicatedStorage.LihFolkUI`. Files ending in `.client.luau` become LocalScripts. Every client script calls `Controller.start()`, which is safe to call more than once, so the examples can run together.

Minimal menu:

```lua
local C = require(UI.LihFolkUIComponents)
local Controller = require(UI.LihFolkUIController)
Controller.start()
local window = C.Window({ name = "Pets", title = "Pets", theme = "rebirth", icon = "pet" })
C.SectionHeader("Equipped", "rebirth", 1, window.body)
-- ... cards, buttons ...
Controller.register(window)
Controller.addHudButton({ window = "Pets", label = "Pets", icon = "pet", theme = "rebirth" })
```

## Design tenets

1. **One focal action per screen.** Each screen has one `go` (green) slab. Every other action is `neutral`, `info` or `premium`. A player should know what to press within three seconds.
2. **Everything you can press looks like a slab.** It has a gradient face on a darker lip with an ink outline. Pressing sinks the face into the lip. Anything flat cannot be pressed.
3. **Colour plus one more cue.** Each state also differs in lightness and carries a word or glyph (CLAIMED with a tick, LOCKED with a lock, ON/OFF text, a `!` badge). Never rely on hue alone.
4. **The menu colour lives in the header and the bands, not the body.** Bodies stay dusk so text contrast holds in every menu.
5. **Design units, not pixels.** Author at a UIScale of 1. The controller fits each window to the safe area and never lets a tap target draw under 44 px.
6. **Motion confirms; it does not decorate.** Opens are short and centre-anchored. Animations retarget from wherever they are when interrupted. Under Reduced Motion, the spins, pulses and pops turn off.

## Tokens (summary; exact values in `LihFolkUITheme.luau`)

| Token | Hex | Use |
|---|---|---|
| ink | `#160F2B` | Every outline and text stroke |
| dusk | `#2D2852` | Panel canvas |
| duskRaised / duskRaisedHi | `#3B3566` / `#4A437A` | Cards (gradient top to bottom) |
| duskSunken | `#1F1B3D` | Progress tracks, text fields, toggle tracks |
| textHi / textMid / textLow | `#FFFFFF` / `#D6D0F5` / `#B0A9DD` | 13.7 / 9.2 / 6.2 : 1 on dusk |
| gold | `#FFD24A` | Featured outlines, sunburst |

Button roles (face top to bottom, lip):

| Role | Face | Lip | Meaning |
|---|---|---|---|
| `go` | `#7BF5A6` to `#25C773` | `#12804A` | Claim, buy, confirm: the one primary action |
| `neutral` | `#9C94DB` to `#6E66B3` | `#40397A` | Secondary, back, tabs |
| `premium` | `#FFE27A` to `#FFB224` | `#B06B00` | Robux, skip, boosts |
| `danger` | `#FF7A98` to `#EE3D66` | `#9A1838` | Close, reset, destructive confirm |
| `info` | `#7CC8FF` to `#3D93F0` | `#1D58A8` | Help, header actions |
| `done` | `#ECE9FA` to `#C4BEE0` | `#827BA8` | Claimed or owned (dark text, not pressable) |
| `locked` | `#4F4980` to `#3A3466` | `#221D42` | Not yet (muted text, not pressable, darkest slab) |

Menu header themes: shop **Tangerine** `#FFB54D` to `#FF7B22`, codes **Lagoon** `#5DEBDB` to `#18B5C6`, rebirth **Orchid** `#CF9BFF` to `#9257F2`, settings **Denim** `#86AEFF` to `#4F7BEA`, daily **Bubblegum** `#FF9ACD` to `#F25AA2`, neutral **Lilac**.

## Typography

| Style | Face | Size (design) | Ink stroke |
|---|---|---|---|
| display | Fredoka One | 36 | 3.5 |
| title | Fredoka One | 26 | 2.5 |
| button | Fredoka One | 24 | 2.5 |
| number | Fredoka One | 30 | 3 |
| small | Fredoka One | 18 | 2 |
| body | Builder Sans Bold | 18 | none |
| caption | Builder Sans SemiBold | 15 | none |

Why these faces: Fredoka One is built into Roblox, so there is no download and no fallback flash. It is round and heavy, which suits a toy-like simulator, and its open counters stay readable under a thick outline. Builder Sans is Roblox's own interface face and covers many languages, so long text and translations stay clean. Two families is the limit. Strokes are about 9 to 10 percent of the text size with round joins. White text on a bright slab (go, premium) **must** keep its ink stroke: white on lime is only 2.2:1, while ink on lime is 8.3:1. The minimum text size is 15 design units, which still draws at about 12.7 px at the 0.85 touch scale floor.

## Spacing, radii, sizes

- Spacing steps: 4, 8, 12, 16, 24, 32.
- Radii: panel 22, header 14 (panel radius minus the 8 px inset), card 14, button 12, input 10, pills fully round. The rule: an inner radius equals the outer radius minus the gap between them.
- Strokes: panel 4, card and button 3, input 2.5 (3 when focused), divider 2.
- Sizes: button height 56 with a 6 px lip; smallest tap box 52 (an invisible hit pad grows small visuals to fit); close button 52 round; header 72 including its lip; toggle 84 x 40; progress bar 30; text field 56; HUD launcher 64; default window 760 x 520.

## Component recipes

| Need | Call | Notes |
|---|---|---|
| Window | `C.Window{ name, title, theme, icon?, size?, headerAction? }` | The header is an inset tactile slab in the menu colour, with the close button on the right and an optional action before it. The body scrolls. |
| Primary / secondary button | `C.Button{ text, role, icon?, size? }` | Returns `setText`, `setRole`, `setIcon`, `setEnabled`, `setCallback` |
| Claim states | `C.StateButton{ state, texts?, onActivated(state) }` | claim (green, breathing outline), claimed (pale, tick), locked (dark, lock), skip (gold, Robux), pending (`...`) |
| Price | `C.CurrencyButton{ price, currency }` | Formats `1,250`, or `2.5M` for in-game currency over 100k |
| Close / header action | `C.CloseButton(fn)`, `C.HeaderAction{ text?, icon?, onActivated }` | Round when the button has an icon only |
| Section | `C.SectionHeader(text, theme, order, parent)` | Accent pill in the menu colour, a title and a faint underline |
| Card | `C.Card{ size, featured? }` | Raised gradient. `featured` gives a gold outline. |
| Progress | `C.ProgressBar{ value, role, text }` | Recessed track, glossy fill, minimum visible sliver, Quad Out 0.35 s fill |
| Tier flow | `C.TierCompare{ current, nextTier, theme }` | NOW card, nudging arrow, NEXT card (featured) |
| Reward | `C.RewardCard{ title, amount, icon, state, featured? }` | Claimed cards get a veil and a tick badge. Featured cards get a sunburst and a BIG REWARD pill. |
| Toggle / setting | `C.Toggle{ value, onChanged }`, `C.SettingRow{ label, description, icon, value }` | ON/OFF text inside the track. The whole row is the tap target. |
| Text input | `C.TextInput{ placeholder, maxLength }` | Focus ring, a status line with a tick or `!` prefix, and a shake on error |
| Decoration | `C.Sunburst{}`, `C.Pattern(panel, color)`, `C.Pill(text, {role})` | Procedural unless you register `sunburst` or `pattern` art |
| Launcher | `Controller.addHudButton{ window, label, icon, theme }` | Left edge, vertically centred. `setBadge(true)` shows a `!` badge. |

## Menu archetypes

- **Shop:** Game Passes section, then a Coins (products) section, as 220 x 236 cards in a three-column grid. Each card has an icon, a name, a one-line benefit and a price button. One product is featured, with a gold outline, a sunburst and a BEST VALUE pill. Owned passes switch to `done` with OWNED and a tick, after an ownership check. The buttons only prompt. The server grants (see `roblox-monetization-compliance`).
- **Codes:** one instruction line, one recessed field with a 24-character limit, and one REDEEM `go` button. The status line shows the server's reply. The field shakes on error. The button reads CHECKING... while the request is in flight, and a 2 s client cooldown applies. The server owns the codes and the rate limit (see `roblox-secure-remotes`).
- **Rebirth:** a TierCompare of NOW and NEXT with the multiplier, a progress bar of `have / need`, one line saying what resets and what stays, a REBIRTH state button (NEED CASH while locked), and a premium Skip price button. Rebirth asks for confirmation: the first tap turns the button `danger` with TAP TO CONFIRM for 3 s.
- **Settings:** one SettingRow per option, each with an icon, a label, a one-line description and a toggle. Include music, sound effects, Reduced Motion (which defaults to the platform setting), hide other players' effects, and larger menus. RESET is the header action. Saves are batched.
- **Daily rewards:** days 1 to 4 on the top row, then days 5 and 6 plus a **double-width day 7** card (featured, sunburst). Days before today are claimed, today is claim (or claimed), and later days are locked. A countdown to the next UTC midnight ticks only while the menu is open. The HUD badge shows when a reward is ready. The streak rule is stated on screen.

## Layout and responsive rules

- Use two ScreenGuis. The backdrop uses `ScreenInsets.None` and holds only the dimmer. The main layer uses `ScreenInsets.CoreUISafeInsets` and holds everything you can tap. Both use `SafeAreaCompatibility.None`, `ResetOnSpawn = false` and `ZIndexBehavior.Sibling`.
- Each window is a centre-anchored slot sized in design units, with a `Fit` UIScale. The panel inside it carries a separate `Motion` UIScale, so fitting and animation never fight over one property.
- The scale is `min(deviceBase x playerScale, fit)`, then raised to the touch floor of 44 / 52 = 0.846 on touch devices. If the floor would push a window off the screen, the slot shrinks instead and the body scrolls. Device base values: phone 1.0 (the fit clamp decides), desktop and tablet `clamp(height / 1000, 0.85, 1.4)`, console 1.35. A phone is a touch device whose safe-area short side is under 520 px.
- Keep a 16 px margin to the safe-area edge. The HUD launcher sits on the left edge, vertically centred, clear of the top bar, the thumbstick and the jump button.
- Test at 1920 x 1080, 1366 x 768, 1024 x 768 (touch), 844 x 390 and 667 x 375, in both landscape orientations on a notched profile.

## Motion rules

| Interaction | Value |
|---|---|
| Window open | Motion scale 0.86 to 1, 0.22 s Back Out; dimmer to 0.45 transparency in 0.18 s Quad Out |
| Window close | Scale to 0.90, 0.12 s Quad In, then hidden; dimmer out in 0.12 s |
| Hover / gamepad select | Body scale 1.04, 0.10 s Quad Out |
| Press | Face sinks by lip minus 2 px, scale 0.96, 0.05 s Quad Out |
| Release | Back Out, 0.16 s |
| Toggle | Knob and track colour, 0.16 s Quad Out |
| Progress fill | 0.35 s Quad Out |
| Claimable glow | Outline transparency 0.35 to 0.85, Sine InOut, 0.8 s half period, looping |
| Tier arrow nudge | ±3 px, Sine InOut, 0.6 s half period |
| Sunburst | One turn per 16 s, Linear |
| Error shake | 8, -8, 5, -5, 2, 0 px, 0.04 s steps |

Interruption: opening and closing are driven by state (`entry.open`). A reopen during a close continues from the current scale for the remaining fraction of the time. A cancelled close never hides the panel. Looping tweens belong to their window: they play on open and pause on close, so idle UI costs nothing. Under Reduced Motion there is no scale, spin, glow pulse, nudge or shake. Tween `UIScale.Scale`, never `Size`, for pops, and never tween the stroke `Thickness` on text.

## Accessibility

- Contrast: textHi 13.7:1, textMid 9.2:1, textLow 6.2:1 on dusk, and 5.1:1 or better on cards. Done text is 7.7:1 and locked text 5.3:1 on their slabs.
- States never depend on hue alone. Claimed is light with a tick and a veil. Locked is the darkest slab (Oklab L 0.36 against 0.73 for go) with a lock and LOCKED. Toggles show ON/OFF. Status lines start with a tick or `!`.
- Touch: 52 design units, never drawn under 44 px. Invisible pads extend small visuals. Keep at least 8 px between targets.
- Gamepad: every control is selectable with a white ring as its `SelectionImageObject`. Opening a window moves focus to its `defaultSelection`, or to the close button. Closing restores the previous focus. ButtonB closes. Setting rows are a single selection stop.
- Reduced Motion follows `GuiService.ReducedMotionEnabled` and the player can override it in Settings. Players can enlarge menus (0.8 to 1.3), but the fit clamp still wins.
- Escape belongs to Roblox. Use ButtonB, the close button or a tap outside the window.

## Icons

`LihFolkUIIcons.Assets` ships **empty**. Every name (close, coin, gem, robux, shop, codes, rebirth, settings, daily, lock, check, star and others) draws a fallback: a coloured circle, square or diamond with an ink outline and a glyph. Menus therefore work and read correctly with no art. To add art, upload your own square PNGs and paste `"rbxassetid://<id>"` into the registry, or call `Icons.register("coin", id)` at runtime. Never paste ids you have not uploaded or checked. For Robux, use Roblox's official icon under their brand rules. You can also register a `pattern` tile and a `sunburst` image to replace the procedural versions.

## Procedure

1. **Pre-flight** (as `quality-score` requires): open `../quality-score/recipes/ui.md` and the project ledger if one exists. Write 3 to 6 lines covering which archetype this is, its one focal action, the menu theme, the device list to test, and which known misses this draft avoids.
2. **Start from the closest example.** Copy it, rename the window, and change the content. Keep the Window, Controller and component calls.
3. **Data stays on the server.** The UI renders state that the server owns (attributes, remotes) and sends intents. Prices come from `GetProductInfo`. Grants happen in `ProcessReceipt`. Codes, rewards and rebirths are validated on the server.
4. **Test** at the five viewports above, with touch, mouse and gamepad, with Reduced Motion on, at UI scale 1.3, and with long translated strings.
5. **Score** against `../quality-score/rubrics/ui.md`, then log the result. Fix the lowest high-weight criterion first.

## Quality bar: how this kit earns 8.5+

Hard gates (any failure caps the score at 5): nothing clipped at phone, tablet or PC sizes; tap targets at least 44 px on phone; no overlaps and no text overflow; gamepad and keyboard reachable. The kit covers these with the fit clamp and touch floor, scrolling bodies, invisible hit pads, `TextScaled` with size limits or truncation on every label, and selection rings with focus handling. **You** still have to check content you add.

| # | Criterion (weight) | How to reach 2/2 |
|---|---|---|
| U1 | Clarity (3) | One `go` slab per screen with a verb on it (CLAIM, REDEEM, REBIRTH). Locked buttons say why (NEED CASH). |
| U2 | Hierarchy (2) | A featured card has a gold outline and sunburst. A section header comes before each group. Spacing stays on the 4-point steps. |
| U3 | Consistency (2) | Use only Theme tokens and components. Use no other fonts, colours or radii. |
| U4 | Motion and feedback (2) | Use the Controller and components unchanged and fill the `Theme.Sounds` slots with your audio. |
| U5 | Readability (2) | Keep text styles at or above caption size, and keep the ink stroke on bright slabs. |
| U6 | Performance (1) | Build each window once and update text and state in place. Loops pause while closed. Do not rebuild every frame. |

`score = 10 x sum(weight x points / 2) / 12`. You reach 9.0 only with U1 at 2. Any single weight-2 criterion at 1 still scores 9.2. A weight-3 miss drops the score to 8.8. Clarity and the other judged criteria need a reviewer that is not the maker (a Quick `council` seat). Report the result as `Score x/10 ... Logged.`

## Implementation checklist

- [ ] The four modules are in `ReplicatedStorage.LihFolkUI`. Each menu is one LocalScript, `Controller.start()` is called, and the window is registered.
- [ ] Every window has a theme, an icon name, one `go` action and a `defaultSelection`.
- [ ] Every price, reward and state comes from the server or a shared config. Every `id = 0` placeholder is replaced.
- [ ] Icons are registered or fallbacks accepted. No unknown asset ids.
- [ ] Sounds are filled or knowingly left silent.
- [ ] Tested at 5 viewports, with touch, mouse and gamepad, Reduced Motion, UI scale 1.3 and long strings.
- [ ] Scored against `rubrics/ui.md` (8.5 or higher) and logged.

## Common mistakes

- Two green buttons on one screen. Demote one to `neutral`.
- Removing the ink stroke from white captions on lime or gold slabs. They become unreadable at 2:1.
- Tweening `Size` for pops. The text steps and layouts reflow. Use the UIScale the kit gives you.
- Hiding a panel in a tween's `Completed` without checking the playback state. The Controller already handles this, so do not bypass it.
- Parenting windows to your own ScreenGui. They then miss fitting, the dimmer, focus handling and ButtonB.
- Putting the dimmer or edge art in the safe-area layer, or putting tappable UI in the `None` layer.
- Marking a pass owned from the prompt callback alone. Re-check ownership, and let the server grant.
- Pasting asset ids from the internet into the icon registry.

## Read these vault notes

- `21 LihFolk UI Design System/LihFolk UI Design System.md`, `21 LihFolk UI Design System/LihFolk UI Spec.md`
- `05 UI and UX/Safe Areas and Insets.md`, `05 UI and UX/Responsive UI for Phone Tablet Console and PC.md`
- `05 UI and UX/UI Motion Language and Timing.md`, `05 UI and UX/Text Fonts and Rich Text.md`
- `05 UI and UX/Menu Archetypes - Shop Settings Codes Rewards.md`, `05 UI and UX/Gamepad and Console UX.md`
- `42 Accessibility and Inclusive Design/Readable Text and UI Scale.md`, `42 Accessibility and Inclusive Design/Colour-Blind Safe Design.md`
- `52 Core Concepts/Safe Area.md`

License: the kit's code is free to use and modify in your games. This document is CC BY 4.0 (LihFolk).
