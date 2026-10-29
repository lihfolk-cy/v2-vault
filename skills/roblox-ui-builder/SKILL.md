---
name: roblox-ui-builder
description: 'LihFolk: responsive Roblox UI review and build (layout, safe areas, motion, accessibility). Use for any ScreenGui/HUD/menu work or "UI broken on phone", "buttons under the notch".'
---
# LihFolk UI Builder

UI is done when it passes measured rules on every target screen, not when it looks right on the developer's monitor. Define "fits" as numbers, build to them, and check them at fixed viewports.

## Inputs

- `VAULT`: LihFolk Vault V2, the knowledge base at `../../LihFolk Vault V2/` relative to this file (plugin root `LihFolk Vault V2/`). Start with `VAULT/INDEX.md` to find notes fast.
- What to build (screen, menu archetype, HUD element) and the target platforms.
- Whether the game uses the LihFolk house style (the `lihfolk-ui` skill, for a cartoon or simulator look) or its own design system.

## Procedure

1. **Structure.**
   - One `LocalScript` boots the UI from `StarterPlayerScripts`. Menus set `ResetOnSpawn = false`.
   - Assign `DisplayOrder` bands per ScreenGui and write them down.
   - Every `ScreenGui` sets `ScreenInsets` explicitly. Use `SafeAreaCompatibility = None` on new guis.
   - Split each screen into two layers: interactive content in a safe-area gui (`CoreUISafeInsets` or `DeviceSafeInsets`), edge-to-edge art (letterbox, vignette) in a separate `None` gui that no scaler touches.
   - `IgnoreGuiInset = true` means device-safe, not fullscreen.
   - Read the top bar position live from `GuiService.TopbarInset`; never hard-code its height. Top-down HUD slots start below it on phones.

2. **Layout.**
   - Author panels at one design resolution (1920 x 1080 is the vault's baseline) with one device `UIScale` per branch, clamped. Compute the floor from the smallest authored text so drawn text never falls below 12 px.
   - Square things (icons, slots) use `SizeConstraint` or `UIAspectRatioConstraint`, never Scale on both axes.
   - Variable-length text uses `AutomaticSize`, not `TextScaled`. Never combine the two. Auto-sized containers use Offset or auto children on the automatic axis.
   - Pop and press scales live on a child `UIScale`, separate from the device scale. Never two `UIScale`s on one object.
   - Use `UIPadding` for text insets, not position nudges. Do not read `AbsoluteSize` in the same frame you set `Size`.
   - Large lists are virtualized; do not rebuild a list on every change.

3. **Input.**
   - Buttons use `Activated` (works for mouse, touch and gamepad), not `MouseButton1Click`.
   - World input handlers respect `gameProcessedEvent`. Decorative full-screen frames have `Active = false`.
   - Every menu sets `GuiService.SelectedObject` at the start of its entrance and contains gamepad selection inside it.
   - Only one menu open at a time, managed by one panel manager.
   - Classify devices by capability (layout family separate from input type). `TouchEnabled` does not mean "phone".

4. **Motion.**
   - All UI tweens go through one motion module with named tokens; no panel builds its own `TweenInfo`.
   - Durations: 0.1 to 0.2 s for feedback and exits, 0.2 to 0.35 s for entrances, 0.35 to 0.6 s only for big reveals (rule of thumb). Below about 0.08 s a tween is invisible on low-end phones.
   - Scale move duration with screen-space distance: `clamp(base + k * sqrt(px), min, max)`, starting values base 0.12, k 0.012, min 0.15, max 0.45.
   - Exits are faster than entrances and use In easing without overshoot (no Back In on exits).
   - Hide-on-`Completed` checks the playback state and the current intent. Rapid toggling (10 taps per second) must end in the last requested state.
   - Staggers total at most about 0.4 s. Pops tween a `UIScale`, not `Size`. Idle loops pause when hidden.
   - Accept input from the first visible frame; never lock input until an entrance ends.

5. **House menu style (cartoon and simulator games).** LihFolk's own design system is the `lihfolk-ui` skill. Use it for the five common menu archetypes (Shop, Codes, Rebirth, Settings, Daily Rewards) and take exact sizes, colours, fonts and icons from it rather than from memory. Whatever style the game uses, a menu ships only when:
   - Buttons look pressable (a raised edge or shadow), never flat rectangles.
   - Each button state (available, done, locked, skip or premium) has its own colour and also a word or icon, so colour is never the only signal.
   - Hover and press feedback scale from the centre (`AnchorPoint` 0.5, 0.5 with a child `UIScale`), small enough that the layout never jumps.
   - Every menu uses the same close button, in the same corner, at the same size.
   - Icons come from one registry and keep their own aspect ratio.
   - Decorative idle animation (spinning rays, shimmer) stops while the menu is hidden.
   - The menu fits both the smallest phone and a large desktop at the clamped device scale.
   - Fonts: do not use the Gotham family; Roblox retired it and it now renders as Montserrat (Roblox docs, as of October 2026). Pick a heavy `FontFace` such as `BuilderSansExtraBold`.
   - Every price comes from `GetProductInfoAsync`; paid random items show odds before purchase (see `roblox-monetization-compliance`).

6. **Accessibility.**
   - Honour and listen to `GuiService` preferences: preferred text size, `PreferredTransparency`, and `ReducedMotionEnabled`. Reduced motion swaps movement for fades and colour, not "shorter tweens" and not "nothing".
   - Test every screen at the `Largest` text size.
   - Body text contrast at least 4.5:1, or outlined text over art.
   - No colour-only signals (rarity, team, state also get a word, icon or shape).
   - Flashes at most three per second, with a screen-effects setting. Every important sound has a visual.
   - Tap targets at least 44 px drawn (48 for HUD buttons in the reference project), 8 px gaps, no rapid-tap requirements.

7. **Test at fixed viewports** in the Device Emulator during a play test: 1920 x 1080, 1366 x 768, 1024 x 600, 932 x 430, 844 x 390, 667 x 375, plus a notched 844 x 390 in both landscape orientations, and TV at 1920 x 1080 with the Large display size and a gamepad. Pass criteria (measured on the drawn result): text at least 12 px, taps at least 44 px, gaps at least 8 px, zero overlaps between interactive objects, nothing interactive outside the safe area. Then play on a real phone.

## Hard rules

- No hard-coded top bar heights or prices.
- No `TextScaled` with `AutomaticSize`; no two `UIScale`s on one branch.
- No interactive buttons in a `None` inset gui.
- Labels bind to server-owned values, never local guesses.
- Do not sign off phone UI without playing on a phone.

## Checks before finishing

- [ ] `ScreenInsets` set on every gui; edge art separated.
- [ ] One clamped device `UIScale`; 12 px text and 44 px taps at the floor.
- [ ] `Activated` everywhere; gamepad selection on open.
- [ ] Motion through tokens; interruption safe; reduced motion honoured.
- [ ] Seven viewports, a notched phone and a gamepad tested.
- [ ] Accessibility checks pass at `Largest` text.

## Read these vault notes

- `05 UI and UX/ScreenGui Fundamentals.md`
- `05 UI and UX/Layout - Scale Offset and Constraints.md`
- `05 UI and UX/Responsive UI for Phone Tablet Console and PC.md`
- `05 UI and UX/Safe Areas and Insets.md`
- `05 UI and UX/UI Motion Language and Timing.md`
- `05 UI and UX/Accessibility.md`
- `05 UI and UX/Menu Archetypes - Shop Settings Codes Rewards.md`
- `05 UI and UX/UI Design Systems.md`
- `05 UI and UX/Virtualized Lists and Large Inventories.md`
- `05 UI and UX/Gamepad and Console UX.md`
- The `lihfolk-ui` skill (house menu style, sizes, colours, icons)
- `23 Debugging Deep Dives/Debugging UI Layout and Input.md`
- `29 Luau Cookbook/Cookbook - UI.md`
- `13 Production and Case Studies/Case Study - Phone UI Overhaul.md`

Disputed: the docs allow `MinTextSize` down to 9, while the reference project's floor is 12 px drawn text (see `Open Questions - Whole Vault.md`). This skill uses 12 px.
