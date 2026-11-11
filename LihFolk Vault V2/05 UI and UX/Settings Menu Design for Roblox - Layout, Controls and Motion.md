---
tags: [ui, gui, settings-menu, menus, motion, accessibility, type/guide, area/ui, level/intermediate, api/CanvasGroup, api/UIScale, api/UIStroke]
---
# Settings Menu Design for Roblox - Layout, Controls and Motion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Fixed pixel sizes copied from a desktop mockup.
> - Avoid: Only the resting state designed. Symptom: controls with no hover, pressed, disabled or gamepad-selected look.
> - Avoid: Tweening the slider fill while dragging.
> - Page scrolls; rail and footer stay fixed; fits a landscape phone.
> - Every control has rest, pressed, disabled and gamepad-selected states.
> - Hit areas are at least about 44 points tall.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 1. Layout · ## 3. Motion · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A settings menu is the one screen that holds almost every common widget at once: tabs, sliders, segmented choices, toggles, dropdowns, and primary and secondary buttons. That makes it a good first build for a new UI style or a new design-to-Roblox pipeline: if the settings menu works on a phone, with a gamepad and in another language, most other menus will too. This note covers the layout, each control's states, how the menu should move, and the save model behind it. What belongs in the menu is in [[Menu Archetypes - Shop Settings Codes Rewards]]; motion timing in general is in [[UI and GUI Animation]] and [[UI Motion Language and Timing]].

Trust labels: **Roblox docs** (class behaviour), **Rule of thumb** (numbers and layout choices, which are starting points to tune).

---

## 1. Layout

A settings menu has three zones:

1. **Category rail.** Audio, Graphics, Controls, Accessibility, Account. Five or fewer categories keep the rail readable; more than that usually means two categories should merge.
2. **Page.** A header for the category, then rows. Each row has an icon (optional), a label, a one-line description in a quieter colour, and a control on the right.
3. **Footer.** Either a single hint line ("Changes save automatically") or a pair of buttons (Reset and Apply). Pick one model; see section 5.

Rules of thumb for the page:

- One control per row, right-aligned, so the eye scans labels down the left and values down the right.
- The description line says what the setting changes in plain words ("Fewer particles, better battery"), not the setting's name again.
- Group rows under small subheaders once a page passes about six rows.
- The page scrolls; the rail and footer do not.

### Fitting a phone

- **Design phone first.** A landscape phone can leave under 350 points of usable height after the top bar and safe areas ([[Safe Areas and Insets]]). Five category tabs plus six rows will not fit at a readable size, so the page must scroll and the rail may need to collapse to icons below a height threshold.
- **Scale, not Offset.** Rebuild any fixed-pixel mockup with Scale sizes, `UIAspectRatioConstraint` where shapes matter, and one scale controller ([[Layout - Scale Offset and Constraints]], [[Responsive UI for Phone Tablet Console and PC]]).
- **Text floor.** Labels and descriptions must stay at or above about 12 px drawn on the smallest supported phone ([[Readable Text and UI Scale]]).

---

## 2. Controls and their states

Draw every state before building. A mockup usually shows only the resting state.

| Control | States to design | Notes |
|---|---|---|
| Category tab | rest, hover, pressed, active, gamepad-selected | Active and gamepad-selected must look different: one means "this page is open", the other "your cursor is here" |
| Slider | rest, dragging, disabled, gamepad-selected | Hit area at least about 44 points tall even when the track art is thin; show the value as a number next to the track |
| Segmented choice | rest, selected option, disabled option | Left and right on a gamepad move the selection |
| Toggle | off, on, disabled | Do not rely on colour alone: move the knob and change the label or icon |
| Dropdown | closed, open, option hover | On phones, a dropdown with three or four options is often better as a segmented choice |
| Primary button | rest, hover, pressed, disabled, pending | Pending while a save is in flight |
| Secondary button | rest, hover, pressed | Visibly quieter than the primary |

Gamepad navigation (Roblox docs, `GuiService.SelectedObject` and selection groups): every control must be reachable with the D-pad, sliders and segmented choices step with left and right, shoulder buttons switch categories, and `B` closes the menu ([[Gamepad and Console UX]]).

---

## 3. Motion

The menu should feel responsive without making players wait to change a volume.

| Element | Motion | Starting values (Rule of thumb) |
|---|---|---|
| Menu open | Scale pop about the centre | Child `UIScale` from about 0.85 to 1, `Back` out, about 0.2 to 0.25 s ([[UI and GUI Animation]]) |
| Menu close | Quicker than open | About 0.12 to 0.15 s, no overshoot |
| Category switch | Active highlight slides to the new tab; the page cross-fades | Tween the highlight's `Position`; fade the page with `CanvasGroup.GroupTransparency` so stacked transparencies do not show through (Roblox docs) |
| Slider drag | Fill follows the finger exactly; the knob grows slightly while held | Set the fill `Size` directly every input change; tween only on release or reset |
| Segmented choice | Selector slides between options | `Quad` out, about 0.12 s |
| Toggle | Knob slides, track colour changes | About 0.1 to 0.15 s; keep the colour change under reduced motion |
| Buttons | Press and hover | Child `UIScale` on a stored base value so device scaling is kept |
| Decoration (shine, particles, patterns) | Slow loops | Start on open, stop on close, skip entirely under reduced motion |

Rules:

- **Respect reduced motion.** When `GuiService.ReducedMotionEnabled` is true (Roblox docs), replace slides and pops with instant changes or short fades, and turn decorative loops off rather than slowing them ([[Accessibility]]).
- **Preview live.** Volume, brightness and UI scale should change while the player drags, so they can hear or see the result before letting go.

---

## 4. Performance

- **CanvasGroup cost.** Each `CanvasGroup` renders its contents to a texture (Roblox docs). Keep one or two visible at a time and avoid nesting them; large ones can look soft or cost noticeable memory on low-end phones.
- **Images versus UI objects.** `UICorner`, `UIStroke` and `UIGradient` reproduce most panel looks without images. Reserve images for icons and special lettering, ideally from one sprite sheet ([[Textures Decals and Texture Memory]]).
- **One loop per screen.** Any per-frame decoration runs from one connection made on open and disconnected on close.

---

## 5. Saving: pick one model

| Model | Footer | How it saves |
|---|---|---|
| Auto save | A hint line: "Changes save automatically" | Apply locally at once; send changes to the server after a short idle (a few seconds) or when the menu closes; the server writes them with the player's save |
| Explicit save | Reset and Apply buttons | Apply previews locally; Apply sends them; closing without Apply asks whether to discard |

Mixing the two (an "auto save" hint next to a Save button) leaves players unsure whether their change stuck. Never write a DataStore on every slider tick: buffer on the client, validate on the server, and save through the normal profile path ([[Saving Correctly - Autosave and BindToClose]]).

---

## 6. Localisation

Category names and descriptions grow in other languages. Use `AutomaticSize` on tabs and pills, allow two-line descriptions, and test with the longest language you support ([[Localization]]).

---

## Common mistakes

1. **Fixed pixel sizes copied from a desktop mockup.** Symptom: the menu overflows on phones and looks tiny on 4K. Fix: rebuild with Scale sizes, constraints and one scale controller.
2. **Only the resting state designed.** Symptom: controls with no hover, pressed, disabled or gamepad-selected look. Fix: draw every state from section 2 before building.
3. **Tweening the slider fill while dragging.** Symptom: the fill lags behind the knob. Fix: set it directly during the drag; tween only on release or reset.
4. **Decoration loops left running when the menu is closed.** Symptom: phones heat up in the lobby. Fix: start on open, cancel on close.
5. **Settings applied only on save.** Symptom: players cannot hear a volume change while dragging. Fix: preview live, persist later.
6. **Two save models at once.** Symptom: players ask whether their settings saved. Fix: auto save with a hint, or Apply and Reset, never both.

## Checklist

- [ ] Page scrolls; rail and footer stay fixed; fits a landscape phone.
- [ ] Every control has rest, pressed, disabled and gamepad-selected states.
- [ ] Hit areas are at least about 44 points tall.
- [ ] Gamepad: D-pad reaches every control, shoulders switch categories, B closes.
- [ ] Reduced motion turns slides into instant changes and stops decoration.
- [ ] Volume and scale preview live while dragging.
- [ ] One save model; no DataStore write per slider tick.
- [ ] Tested with the longest supported language.

## Related decisions

- [[Menu Archetypes - Shop Settings Codes Rewards]]: what a settings menu should contain.
- [[UI and GUI Animation]]: the pop, slide and press patterns used above.
- [[Responsive UI for Phone Tablet Console and PC]]: turning one layout into phone, tablet, console and PC layouts.
- [[Gamepad and Console UX]]: selection and navigation for every control.
- [[Figma to Roblox UI - Pipeline and Handoff]]: bringing a settings mockup from a design tool into Roblox.
- [[UI Style Directions - A Visual Vocabulary for Briefs]]: choosing a look before building.

<!-- related:start -->
## Related
[[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]] · [[Cookbook - UI]] · [[UI Design Systems]] · [[UI Scale HUD Hide and Compact Mode]] · [[HUD Design]] · [[UI Layout Objects - Lists Grids and Pages]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Virtualized Lists and Large Inventories]] · [[ScreenGui Fundamentals]] · [[Figma Property Mapping for Roblox UI]]
<!-- related:end -->
