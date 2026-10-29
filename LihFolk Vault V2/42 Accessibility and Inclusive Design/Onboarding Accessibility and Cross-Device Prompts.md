---
tags: [accessibility, onboarding, tutorial, ftue, input, glyphs, gamepad, touch, reduced-motion, captions, safe-area, type/guide, area/accessibility, area/ui, level/intermediate, api/UserInputService, api/GuiService, api/InputAction, api/ProximityPrompt]
verified: 2026-10-29
---
# Onboarding Accessibility and Cross-Device Prompts

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: "Press E" for everyone -> Token resolved per device, updated on switch
> - Avoid: Labels ignore remapped keys -> Read the bound key from the input binding
> - Avoid: Tutorial banner under the notch -> `ScreenInsets` set to the core UI safe area
> - Prompt text resolved per device and re-rendered on device change.
> - Remapped bindings shown correctly.
> - Tutorial UI inside the safe area; readable at phone width; targets 44 px or more.
>
> Cost: TL;DR ~150 tok · whole note ~1.5k tok. Read more: ## 1. Device-aware prompt text · ## 3. Accessible guidance · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A tutorial is the first thing every player meets, so it is where accessibility matters most: a player who cannot read the prompt, does not know which button "Press E" means on their controller, or feels sick from a swinging camera leaves before the game starts. This note covers device-aware prompt text, layout on small screens, guidance that works without colour or motion, and pacing for slower readers. Broader topics are in [[Accessibility Start Here]]; tutorial structure is in [[Onboarding and FTUE - Tutorials That Keep Players]].

Trust labels: **Roblox docs** (`UserInputService`, `GuiService`, `InputAction`, `ProximityPrompt`, `ScreenGui` reference, as of October 2026), **Rule of thumb**.

---

## 1. Device-aware prompt text

- **Which device?** `UserInputService.PreferredInput` (`Enum.PreferredInput`: `KeyboardAndMouse`, `Touch`, `Gamepad`, `MicroGamepad`) says what the player is using; fall back to `GetLastInputType()`. Re-render on `LastInputTypeChanged` and on the `PreferredInput` property change, because players switch mid-step (**Roblox docs**).
- **Tokens, not literals.** Write objectives as "{INTERACT} to sell", and resolve the token on the client: "Press E", "Tap", "Press X".
- **Follow remapping.** If the game uses the Input Action System, read the action's `InputBinding` children and show the bound key; `UserInputService:GetStringForKeyCode` gives the label for the player's keyboard layout ([[Rebinding Controls with the Input Action System]], [[Input Remapping and One-Handed Play]]).
- **Prompts already know.** A `ProximityPrompt` shows the right key or button per device by itself, so "walk up and press" steps need no custom glyph.
- **Touch verbs are different verbs.** "Drag the stick", "Tap Jump" and "Hold" are not translations of keyboard keys; write them separately.

## 2. Layout on small screens

- Put tutorial UI inside the safe area: `ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets` keeps it clear of the notch and Roblox's own buttons ([[Safe Areas and Insets]]).
- Top-centre for the objective, a line below for the hint; never over the thumb zones on phones or the middle of the play area.
- Touch targets at least about 44 px (**Rule of thumb**, matching the LihFolk UI kit); a Skip button counts.
- Respect `GuiService.PreferredTextSize` and keep text growing without clipping ([[Readable Text and UI Scale]]).
- Test at about 375 px wide, on a tablet, on PC and at TV distance (`GuiService:IsTenFootInterface()`).

## 3. Accessible guidance

- **Colour plus shape plus words.** A gold beam, a white outline and the objective text together; never a colour alone ([[Colour-Blind Safe Design]]).
- **Reduced Motion.** When `GuiService.ReducedMotionEnabled` is on: no pulsing highlights, static beam textures, no camera nudges, instant HUD reveals (**Roblox docs** for the property; [[Motion Sensitivity and Camera Comfort]]).
- **Captions** for any voiced line or important sound cue in the tutorial ([[Captions and Audio Accessibility]]).
- **No timed text that vanishes.** Objectives stay until the step is done; dialogue advances on tap with a fast-text option ([[Writing Dialogue for Roblox Players]]).
- **Gamepad reachability.** HUD targets must be reachable with selection; point at the selected button, and select it for the player when the step starts ([[Gamepad and Console UX]], [[Controller Support QoL]]).
- **Cognitive load.** One goal at a time, plain words, hints only after being stuck, and a tips page to revisit later ([[Difficulty Options and Cognitive Load]], [[Skippable Tutorials and Replayable Tips]]).
- **Localisation.** Keep tokens outside translated strings and leave room for longer text ([[Localization]]).

## Common mistakes

| Mistake | Better |
|---|---|
| "Press E" for everyone | Token resolved per device, updated on switch |
| Labels ignore remapped keys | Read the bound key from the input binding |
| Tutorial banner under the notch | `ScreenInsets` set to the core UI safe area |
| Colour-only target cue | Beam + outline + text |
| Pulsing guidance under Reduced Motion | Static guidance when the setting is on |
| Timed text that disappears | Objective stays until the step is done |
| HUD target unreachable on gamepad | Select the target button when the step starts |

## Checklist

- [ ] Prompt text resolved per device and re-rendered on device change.
- [ ] Remapped bindings shown correctly.
- [ ] Tutorial UI inside the safe area; readable at phone width; targets 44 px or more.
- [ ] Every cue uses colour plus shape plus words.
- [ ] Reduced Motion disables pulses, moving textures and camera nudges.
- [ ] Voiced lines captioned; text stays until done; tap to advance.
- [ ] Tested on phone, tablet, PC and gamepad.

## See also

[[Accessibility Start Here]] · [[Accessibility]] · [[Onboarding and FTUE - Tutorials That Keep Players]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[Input - UserInputService and ContextActionService]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Readable Text and UI Scale]] · [[Colour-Blind Safe Design]] · [[Motion Sensitivity and Camera Comfort]] · [[Captions and Audio Accessibility]]

<!-- related:start -->
## Related
[[Accessibility Cross-Links for QoL Settings]] · [[AI Pitfalls - UI and Input]] · [[Safe Area]] · [[Mobile Button Layout Editor]] · [[Colourblind Palettes Text Size and Tooltips]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]
<!-- related:end -->
