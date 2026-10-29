---
tags: [platform, console, xbox, playstation, vr, quest, release, qa, type/checklist, area/platform, area/testing, level/intermediate]
---
# Console and VR Release Checklists

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Enabling console and VR because the toggles exist, with no test session.
> - Avoid: Core flows that need the virtual cursor or a keyboard.
> - Avoid: UI tuned on a monitor at arm's length, unreadable on a TV.
> - Maturity questionnaire done; platform gaps listed.
> - Console: full controller pass, 10-foot UI, safe areas, device button prompts, chat per guideline.
> - VR: default or merged cameras, comfort respected, steady frame rate, controller-usable UI.
>
> Cost: TL;DR ~160 tok · whole note ~1.9k tok. Read more: ## 2. Console pass (Xbox and PlayStation) · ## 3. VR pass (Meta Quest and PC VR) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox runs on Xbox, PlayStation and VR headsets (Meta Quest and PC VR), and every platform you enable is a promise that the game works there. Console players sit across the room with a controller and no keyboard; VR players feel every frame drop in their stomach. This note is a release pass per platform, built from the Roblox guidelines, with the rest marked as rule of thumb. UI design itself is in [[Gamepad and Console UX]] and [[Responsive UI for Phone Tablet Console and PC]].

Sources: [Console development guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines) and [VR guidelines](https://create.roblox.com/docs/production/publishing/vr-guidelines) on the Creator Hub (both read October 2026). Device toggles live in the experience's settings in the Creator Dashboard; **Unverified:** the exact menu path, which has moved before (DevForum users reported an outdated help article in 2025).

---

## 1. Before enabling any platform

- **Content maturity questionnaire completed and accurate.** The console guidelines say console games must provide content maturity information to support smooth releases and reduce the risk of removal from consoles (Roblox docs). See [[Maturity Labels]] and [[Policy and Age Rules 2026]].
- **Platform-specific gaps known.** List features that do not work on the platform (keyboard-only minigames, tiny mobile-style UI) and fix or disable them there.
- **Analytics split by platform** so you can see whether console or VR players leave early ([[Analytics and Funnels]]).

---

## 2. Console pass (Xbox and PlayStation)

### Input (Roblox docs unless marked)

- [ ] Every UI element reachable with the baseline controls: four directions, select and back.
- [ ] Custom layouts have planned controller navigation (selection order, `NextSelection*` where the default guess is wrong). Default directional selection and the virtual cursor exist, but do not rely on the cursor for core flows (Rule of thumb).
- [ ] Key actions take only a few button presses; shortcuts exist for essential actions.
- [ ] Button prompts match the device: `InputActionLabel` for Input Action System bindings, otherwise `UserInputService:GetStringForKeyCode()` or `GetImageForKeyCode()`. Xbox and PlayStation images exist for button keys only.
- [ ] Gameplay works without keyboard and mouse at all. Test by unplugging them (Rule of thumb).
- [ ] Haptics through `HapticEffects` for dramatic events and UI feedback, not constant buzzing ([[Haptics]]).

### UI and the 10-foot view (Roblox docs)

- [ ] Players sit about 8 to 10 feet from the screen: text and icons readable at that distance.
- [ ] Relative sizes and positions; designed for lower resolutions first; `UISizeConstraint` where needed.
- [ ] Checked `GuiService.ViewportDisplaySize`; `Enum.DisplaySize.Large` (most TVs) considered.
- [ ] Important elements inside the TV-safe area; nothing critical at the screen edges ([[Safe Areas and Insets]]).
- [ ] Progressive disclosure: rare features on secondary screens, not crammed onto one.
- [ ] Audio feedback on selection and navigation.
- [ ] The chat window disabled for console, as the guidelines direct. **Unverified:** whether this is enforced or a recommendation; DevForum discussion is mixed, so follow the guideline.

### Content and commerce (Rule of thumb, check current platform rules)

- [ ] No text telling players to visit websites, social media or external stores. Console storefronts are strict about off-platform links.
- [ ] Purchase prompts work with the controller and can be cancelled with back.
- [ ] Any feature that needs typing has a controller path (on-screen keyboard works, or the feature is optional).

### Test

- [ ] Studio Device Simulator console preset for layout ([[Testing Modes - Play Run and Multi-Client]]).
- [ ] A real controller on PC for the full core loop.
- [ ] A real console session before release if you can get one; TV overscan and distance are not simulated.

---

## 3. VR pass (Meta Quest and PC VR)

Roblox VR uses OpenXR for all devices, so one implementation runs on Quest and PC headsets, and testing on a PC VR headset is described as a valid proxy for Quest 2 (Roblox docs). Oculus drivers on PC need a GTX 1060 class GPU or better (Roblox docs).

### Comfort (Roblox docs)

- [ ] Default cameras kept where possible. They live under `CameraModule` in PlayerScripts and support the comfort options; custom VR cameras opt out of future updates and must be merged manually.
- [ ] Comfort settings respected: players can choose Comfort, Default, Expert or Custom (Vignette, Stepped Rotation, 3rd Person Fixed Camera). Do not override them with forced camera motion.
- [ ] No forced camera shakes, rolls or cutscene camera moves without fade (Rule of thumb).

### Performance (Roblox docs)

- [ ] Instance streaming on.
- [ ] Steady frame rate on Quest. Auto Quality Mode aims for at least 72 FPS by scaling detail; if the game looks bad under it, optimise rather than relying on it.
- [ ] Limited CPU-heavy work such as raycasts; low draw calls; light custom meshes.
- [ ] Few semi-transparent objects (decals, Glass); few and simple SurfaceGuis, which are costly in VR.
- [ ] Frame-accurate timing via `RunService.Heartbeat` rather than `task.wait()` loops.
- [ ] Input written with device-agnostic input (`InputAction` and friends), not keyboard-specific code.

### UI (Rule of thumb)

- [ ] Every menu usable with VR controllers; nothing requires a keyboard.
- [ ] ScreenGui content readable in the headset; world-space UI kept to what is needed (each SurfaceGui costs).
- [ ] Text large enough; no essential UI at the edges of the view.

### Test

- [ ] At least one full session in a headset, ideally Quest 2 class hardware as the docs recommend.
- [ ] Watch for discomfort as a bug: anyone feeling sick in 10 minutes is a failure.

---

## 4. After release

- Watch per-platform retention and crash or error rates for the first days ([[Crash and Error Telemetry]]).
- If a platform performs badly and you cannot fix it soon, disabling that device is better than a bad first impression.
- Re-run the relevant pass whenever UI, camera or input code changes.

---

## Common mistakes

- Enabling console and VR because the toggles exist, with no test session.
- Core flows that need the virtual cursor or a keyboard.
- UI tuned on a monitor at arm's length, unreadable on a TV.
- Custom VR camera that ignores comfort settings.
- Treating Auto Quality Mode as the optimisation plan.
- Off-platform links or "type here" features with no controller path.

## Checklist

- [ ] Maturity questionnaire done; platform gaps listed.
- [ ] Console: full controller pass, 10-foot UI, safe areas, device button prompts, chat per guideline.
- [ ] VR: default or merged cameras, comfort respected, steady frame rate, controller-usable UI.
- [ ] Real-hardware session for each enabled platform.
- [ ] Per-platform analytics and errors watched after launch.

## See also

- [[Gamepad and Console UX]], [[Responsive UI for Phone Tablet Console and PC]], [[Safe Areas and Insets]]
- [[QA Checklists Before Release]], [[Genre QA Passes - Test Checklists per Game Type]]
- [[Mobile and Low-End Optimization]], [[Instance Streaming]]

## Connected notes

[[Haptics]] · Maturity Labels · [[Policy and Age Rules 2026]] · Testing Modes - Play Run and Multi-Client

<!-- related:start -->
## Related
[[Controller Support QoL]] · [[AI Pitfalls - UI and Input]] · [[Safe Area]] · [[QoL Audit Checklist]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Roblox Changes 2025-2026]]
<!-- related:end -->
