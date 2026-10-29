---
tags: [reference, ui, gui, figma, ai-workflow, settings-menu, type/reference, area/animation, level/intermediate, api/CanvasGroup, area/ui, api/UIScale]
source: https://www.tiktok.com/@las.rcd/video/7697675920353660212
source_author: "lasse (@las.rcd)"
source_date: 2026-10-17
studied: 2026-10-26
---
# Reference - Purple Anime Settings UI (Claude + Figma)

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Pixel-perfect Offset sizes from Figma. Symptom: menu overflows on phones, tiny on 4K.
> - Avoid: Treating the AI design as the spec. Symptom: widgets that look right but have no hover, pressed, disabled or gamepad-selected...
> - Avoid: Tweening slider fill while dragging. Symptom: fill lags behind the knob.
>
> Cost: TL;DR ~120 tok · whole note ~2.9k tok. Read more: ## Bringing it to life in Roblox (vault patterns) · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

A 15-second TikTok by **lasse (@las.rcd)**, posted 2026-10-17. The video was filmed on a phone pointed at a monitor. It shows a finished **Roblox-style Settings menu** open in a Figma prototype in the browser. The tab title reads roughly "Anime Settings UI - Purple - Figma". The on-screen caption says it was "all made with Claude with Figma UI Roblox skill". A second caption says the skill will be released at 1k likes. The post's tags are #claude #clauderoblox #roblox #robloxstudio.

This note records what the clip actually shows. It then maps the design onto the Roblox animation patterns in this vault, so the look can be rebuilt and brought to life in-game.

> **Source limits.** The clip is a static design shown in Figma. It has no in-game footage, no Studio, no code and no motion timing. Every animation number below comes from this vault ([[UI and GUI Animation]]) and is labelled as such. None of it was measured from the video. The "Figma UI Roblox skill" had not been released when this was studied, so its workflow is the author's claim, not something verified.

## What the clip shows (second by second)

| Time | On screen |
|---|---|
| 0-6 s | The Settings panel in the Figma prototype. The phone camera drifts slowly across it. Nothing on the panel moves. |
| ~7-8 s | A cut to a dark window full of scrolling green-on-black text: the generated output or terminal. |
| 8-15 s | Back to the Settings panel, from slightly different angles. |

The sparkles and the panel look the same in every frame: no tweening is visible. The only motion is the handheld camera.

## The design, piece by piece

**Frame and header**
- A large rounded panel with a thick lavender rim, a soft inner bevel and a dark violet inner well.
- A **"SETTINGS" title plaque** breaks the top edge. It is a pill shape with heavy white display lettering on a purple gradient, tilted a few degrees, with a small badge chip on its right end.

**Left tab rail**
- Five stacked pill tabs: **General** (active), **Audio**, **Graphics**, **Controls**, **Account**.
- Each tab has a small line icon.
- The active tab is a brighter magenta-pink gradient pill. The inactive tabs are muted, dark violet pills.

**General page**
- A section header, "GENERAL", with a small subtitle.
- **Rows:** each row has an icon chip, a bold label and a grey sub-label.
  - Music Volume ("Background tracks"): a slider with a white knob and a purple fill.
  - Sound Effects: a slider.
  - Graphics Quality ("Higher = prettier sparkles"): a slider.
  - Damage Numbers: a **segmented control** reading Low / Med / High / Ultra, with the selected segment lit.
  - A toggle row, a pill switch.
  - A dropdown reading "English".
- **Footer:** **RESET**, a dark pill button, and **SAVE**, a glowing pink-purple gradient pill.
- A small hint line, "Changes save automatically".

**Atmosphere**
- The background is a purple-to-magenta gradient.
- Four-point white **sparkle stars** sit around the panel's corners.
- Glossy highlights run along the top edge of each pill.

**Style read (rule of thumb):** this is the "anime / soft-premium" simulator look. It is the opposite of the chunky navy-rim cartoon style. It relies on:
- one hue family (violet to magenta),
- glow instead of hard outlines,
- pill shapes everywhere,
- decorative sparkles carrying the "premium" feel.

## The workflow it claims

Claude, driven by a custom skill, generated the design, and the result was a Figma file (a prototype link in the browser). The terminal cut suggests that Claude produced the layout as code or data that was then pushed into Figma. The usual routes are a Figma plugin or the Figma API.

What is **not** shown: how the Figma design reaches Roblox. A typical path is to export the art layers as images, upload them as decals, and rebuild the layout with `Frame` / `ImageLabel` / `UICorner` / `UIGradient` / `UIStroke`. An alternative is to have the same AI step generate the Luau GUI directly. Treat the in-Roblox half as unsolved by this clip.

## Bringing it to life in Roblox (vault patterns)

The design is static. The table below sets out how each part should move, using the patterns and numbers already in [[UI and GUI Animation]].

| Element | Motion | Pattern / values (source: vault) |
|---|---|---|
| Panel open | Pop in about its centre | Pop: `UIScale` 0.6 to 1.05 to 1, `Back`, about 0.25 s ([[UI and GUI Animation]] pattern 1) |
| Title plaque | Lands a beat after the panel, with a small overshoot on its tilt | Same pop, delayed (rule of thumb: about 0.05-0.1 s) |
| Tab switch | The active pill's highlight slides to the new tab; the page cross-fades | Tween the highlight's `Position`; fade the page with `CanvasGroup.GroupTransparency` so the stacked transparencies don't show through |
| Slider drag | The fill follows the knob; the knob grows while held | Fill `Size` set directly while dragging (no tween lag); knob `UIScale` press |
| Segmented control | The lit segment slides between options | Tween the selector frame's `Position` with `Quad Out` |
| Toggle | The knob slides and the track colour changes | Tween the knob position and the track `BackgroundColor3`; keep the colour change under reduced motion |
| SAVE glow | A slow shine sweep across the button | `UIGradient.Offset` sweep from about -1 to 1, looping only while the panel is visible |
| Sparkles | Twinkle (scale and transparency pulse), staggered | Decorative loop: starts on open, stops on close, skipped entirely under `GuiService.ReducedMotionEnabled` |
| Buttons | Press and hover | `UIScale` press/hover on a stored base scale, so device scaling is kept ([[UI and GUI Animation]] common mistakes) |

**Performance:** the sparkles and the shine are per-frame decoration. Run them only while the panel is open, as the vault's "phone gets hot in menus" row warns.

## Takeaways
- AI-generated UI is already producing presentable static designs. The craft still needed is the **motion layer** and the **Roblox rebuild**, and that is what this vault covers.
- To copy the look, copy its constraints:
  - one hue family,
  - pills everywhere,
  - a clear active state in a brighter gradient,
  - a sub-label under every setting,
  - decorative sparkles as a separate layer that can be turned off.
- A Settings menu like this is a good first test for any AI-to-Roblox UI pipeline: it has every common widget (tabs, slider, segmented control, toggle, dropdown, primary and secondary buttons).

See also: [[UI and GUI Animation]], [[Tween and CFrame Animation of Objects]], [[Springs Damping and Smoothing]], [[Performance and Memory]].

## Nuances and edge cases

Rebuilding a static design like this in Roblox is where the real decisions are. The points below apply to any AI-generated or Figma-first menu, not just this one.

1. **Phone first, not monitor first.** Figma frames are usually drawn at 1920 by 1080. On a phone in landscape the usable height after the top bar and safe areas can be under 350 points. A five-tab rail plus six rows does not fit at a readable text size; the rows need a scrolling page, and the tab rail may need to collapse to icons only below a height threshold.
2. **Touch targets.** Slider knobs drawn at 20 pixels look right on a monitor but are hard to grab with a thumb. Make the hit area (an invisible parent button) at least about 44 points tall even if the art stays small (rule of thumb from mobile platform guidelines).
3. **Gamepad navigation.** On console every widget must be reachable with the D-pad. Sliders need left and right to step the value, the segmented control needs left and right to move the selection, and the tab rail needs shoulder buttons. Design the selection highlight now; the pink gradient "active" style should not be confused with "selected by gamepad".
4. **CanvasGroup cost.** Fading a whole page through `GroupTransparency` is clean, but each CanvasGroup renders its contents to a texture. Rule of thumb: keep one or two CanvasGroups visible at a time, and avoid nesting them; on low-end phones, large CanvasGroups can render blurry or cost noticeable memory.
5. **Image count and texture memory.** A design built from many exported PNG layers (rims, bevels, sparkles, highlights) can easily reach 20 to 40 separate images. Each one is a separate download and texture. `UIGradient`, `UIStroke` and `UICorner` reproduce most of this look with no images; reserve images for the plaque lettering and the sparkles, ideally in one sprite sheet.
6. **Localization breaks pill widths.** "SETTINGS" in German or Portuguese is noticeably longer, and sub-labels like "Higher = prettier sparkles" can double in length. Use `AutomaticSize` on pills and allow two-line sub-labels.
7. **"Changes save automatically" is a promise.** Saving every slider tick to a DataStore would hit limits; buffer changes locally and save on close or after a short idle (a few seconds). The RESET and SAVE buttons then become confusing; pick one model (auto save or explicit save) and remove the other.
8. **Reduced motion and decoration.** The sparkles and the shine are pure decoration. Under reduced motion, stop them entirely rather than slowing them.

## Common mistakes

1. **Pixel-perfect Offset sizes from Figma.** Symptom: menu overflows on phones, tiny on 4K. Fix: rebuild with Scale sizes plus `UIAspectRatioConstraint` and a UI scale controller.
2. **Treating the AI design as the spec.** Symptom: widgets that look right but have no hover, pressed, disabled or gamepad-selected states. Fix: draw the missing states before building.
3. **Tweening slider fill while dragging.** Symptom: fill lags behind the knob. Fix: set directly during drag, tween only on release or on reset.
4. **Decoration loops left running when closed.** Symptom: phones heat up in the lobby. Fix: start on open, cancel on close.
5. **Settings applied only on SAVE.** Symptom: players cannot hear the volume change while dragging. Fix: preview live, persist later.

## Related decisions

- [[Responsive UI for Phone Tablet Console and PC]]: the layout rules that turn a monitor-sized frame into one that fits every device.
- [[Gamepad and Console UX]]: selection and navigation for every widget in this menu.
- [[Readable Text and UI Scale]]: minimum text sizes for labels and sub-labels.
- [[Localization]]: making pills and rows survive longer strings.
- [[Saving Correctly - Autosave and BindToClose]]: when settings actually reach the DataStore.
- [[Textures Decals and Texture Memory]]: the cost of building the look from many exported images.
- [[Prompting and Verifying AI Output]]: checking AI-generated designs for missing states before building them.
- [[UI Asset Pipeline]]: getting design layers from Figma into Roblox repeatably.

## Connected notes
<!-- auto-links:start -->
[[UI Design Systems]] · UI Motion Language and Timing · Menu Archetypes - Shop Settings Codes Rewards · LihFolk UI Spec · Debugging UI Layout and Input · UI Layout Objects - Lists Grids and Pages · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Cookbook - UI]] · [[Layout - Scale Offset and Constraints]] · [[Accessibility]] · [[LihFolk UI Design System]] · [[UI Motion Language and Timing]] · [[LihFolk UI Spec]]
<!-- related:end -->
