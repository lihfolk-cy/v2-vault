---
tags: [ui, accessibility, reduced-motion, text-size, contrast, colour-blindness]
---
# Accessibility

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `TextScaled` everywhere, ignoring the player's text size.
> - Avoid: Fixed boxes that clip at `Largest`.
> - Avoid: Glass panels that ignore `PreferredTransparency`.
> - All three `GuiService` preferences honoured and listened to.
> - Every screen tested at `Largest` text size.
> - Contrast at least 4.5:1 for body text (or outlined text on art).
>
> Cost: TL;DR ~130 tok · whole note ~3.4k tok. Read more: ## 1. The three platform preferences · ## 2. Contrast · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Accessible UI is UI more players can use: players with low vision, colour blindness, motion sensitivity, hearing loss, limited dexterity, or simply a small phone in bright sunlight. Docs cite that over 26% of people have some type of disability and over 5% have some form of colour blindness. On Roblox there is also a platform side: players set **Text Size**, **Background Transparency** and **Reduce Motion** in Roblox's settings, and your UI is expected to honour them. This note covers those three settings and their exact engine behaviour, contrast and colour rules, motion and flashing, input accessibility, and the reference project's reduced-motion implementation.

Sources: **Docs** ("Accessibility guidelines", `GuiService.PreferredTextSize`, `PreferredTransparency`, `ReducedMotionEnabled`, `TextService`; October 2026), **WCAG 2.x** for contrast ratios (public standard), the **reference project** (one production game), and **rule of thumb**.

---

## 1. The three platform preferences

All three are read-only `GuiService` properties that change at runtime; listen with `GetPropertyChangedSignal` (Docs).

### PreferredTextSize

`Enum.PreferredTextSize`: `Medium` (default), `Large`, `Larger`, `Largest`. The engine enlarges text itself, with rules you must design for (Docs):

| Your text setup | Effect of a larger preferred size |
|---|---|
| Fixed `TextSize` | Scaled up by the engine |
| `UITextSizeConstraint` | Never grows past `MaxTextSize` or shrinks below `MinTextSize` |
| `TextScaled = true` | **Not** scaled by the preference |
| `AutomaticSize` on the element | Bounds grow to fit the larger text |
| `TextWrapped = true` | Wraps to more lines, within the element's size |
| `TextService:GetTextSize` / `GetTextBoundsAsync` | Return the enlarged size |

`TextService:GetTextSizeOffsetAsync()` returns the offset used to up-scale text for the current setting, as an additive value for the height of a label (Docs; it can fail, wrap in `pcall`).

Design consequences:

- UI built with `TextScaled` everywhere ignores this accessibility setting entirely. Another reason to prefer fixed sizes with `AutomaticSize` ([[Text Fonts and Rich Text]]).
- Fixed-size boxes with fixed-size text overflow or clip at `Largest`. Test every screen at `Largest`.
- A tight `MaxTextSize` on body text defeats the setting; use constraints only where layout truly cannot grow (single-line buttons) and let body text breathe.

### PreferredTransparency

A number from 0 to 1; 1 is the default, 0 means the player wants fully opaque backgrounds for readability. Docs recommend **multiplying** each background's authored transparency by it:

```lua
--!strict
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")

local TAG = "TransparentBack"
local authored: { [GuiObject]: number } = {}

local function apply(obj: GuiObject)
	local base = authored[obj]
	if base then
		obj.BackgroundTransparency = base * GuiService.PreferredTransparency
	end
end

local function onAdded(inst: Instance)
	if inst:IsA("GuiObject") then
		authored[inst] = inst.BackgroundTransparency
		apply(inst)
	end
end

for _, inst in CollectionService:GetTagged(TAG) do
	onAdded(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(onAdded)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	authored[inst :: GuiObject] = nil
end)
GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
	for obj in authored do
		apply(obj)
	end
end)
```

This is the docs' pattern, slightly condensed. Tag every glass or translucent panel. Solid-canvas design systems (the cartoon style uses opaque windows) already satisfy the setting.

### ReducedMotionEnabled

True when the player turned on **Reduce Motion** (Docs). They want motion effects reduced or removed. Docs suggest either a tween time of 0 (snap) or replacing movement with a fade, for example fading a whole panel through a `CanvasGroup`'s `GroupTransparency` instead of sliding it.

What "motion" means in practice:

| Effect | Reduced-motion version |
|---|---|
| Panel slide or scale pop | Fade (or instant) |
| Hover scale and lift | No scale or lift; a colour or wash change only |
| Bouncy springs | Off |
| Idle bobbing, rocking icons, rotating sunbursts | Still |
| Camera shake, screen punch, FOV kicks | Off or reduced to a minimum |
| Parallax, sweeping shines | Off |
| Typewriter text | Show instantly |
| Count-up numbers | Show the final value |

The reference project implemented this per system: its motion module disables scale and lift and uses fades only; its auto-roll button's dice stand still and its pulsing dot is static; reward banners fade only; its blade preview card stays still; toast letters do not wave. A single global helper keeps that consistent:

```lua
--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Motion = {}

function Motion.reduced(): boolean
	return GuiService.ReducedMotionEnabled
end

-- Tween that becomes an instant set when reduced motion is on.
function Motion.tween(obj: Instance, info: TweenInfo, goal: { [string]: any }): Tween?
	if Motion.reduced() then
		for prop, value in goal do
			(obj :: any)[prop] = value
		end
		return nil
	end
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

-- Open a panel: scale pop normally, fade only for reduced motion.
function Motion.openPanel(group: CanvasGroup, scale: UIScale)
	if Motion.reduced() then
		scale.Scale = 1
		group.GroupTransparency = 1
		TweenService:Create(group, TweenInfo.new(0.15), { GroupTransparency = 0 }):Play()
	else
		group.GroupTransparency = 0
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

return Motion
```

Remember to react if the setting changes mid-session: stop running idle loops when it turns on.

---

## 2. Contrast

Docs ask for "sufficient color contrast" without numbers; the public WCAG 2.x guideline gives them:

| Text | Minimum contrast ratio (WCAG AA) |
|---|---|
| Body text | 4.5 : 1 |
| Large text (about 24 px regular or 19 px bold and up) | 3 : 1 |
| UI components and icons | 3 : 1 |

Game UI often puts text over busy art, gradients or the 3D world, where a single contrast ratio is not defined. The practical tools:

- **Outlines.** White text with a dark `UIStroke` (8 to 15% of the text size) stays legible over almost anything; the cartoon style uses it everywhere.
- **Plates.** Put text on a solid or near-solid panel rather than directly on the world.
- **Avoid pastel on white and grey on grey.** The reference project's style rule banned pastel or pale lime text colours for this reason.

```lua
--!strict
-- WCAG relative luminance contrast between two colours.
local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(color: Color3): number
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

local function contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	local hi, lo = math.max(la, lb), math.min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
end

-- contrast(Color3.new(1, 1, 1), Color3.fromRGB(59, 88, 102)) is about 7.6: passes AA
```

Run this over your design tokens once; it is cheap insurance.

---

## 3. Colour non-reliance

Never let colour be the only signal. Docs illustrate this by showing a scene in greyscale and adding symbols.

Common game cases:

| Signal | Add |
|---|---|
| Item rarity | Rarity name text, a distinct frame shape or pip count |
| Claim / claimed / locked buttons | Text ("Claim", "Done", lock icon) |
| Team or enemy markers | Shape or icon |
| Health bar state | Numbers on hover/tap, or a pattern when low |
| Correct / incorrect | Icons (tick / cross) |

The reference project picked a new rarity colour with a measured colour difference of at least 45 (Delta E) from every existing tier and kept the rarity **name** on cards, so the ladder reads for colour-blind players too.

---

## 4. Text size and density on phones

The 12 px drawn minimum and 44 px tap targets that the reference project enforced on phones are accessibility rules as much as layout rules ([[Responsive UI for Phone Tablet Console and PC]]). Docs' own minimum (`MinTextSize` not below 9) is a floor, not a target.

Also:

- Limit line length (about 40 to 60 characters per line for body text) so wrapped text is readable.
- Do not use all caps for long text; it reads slower. The reference project's font standard kept Title Case for headers and recased only ALL-CAPS words of four or more letters.
- Prefer one clear sentence over two clever ones in tutorials. The reference project's tutorial lines were rewritten repeatedly towards short imperatives: "Press UPGRADES, then buy LUCK I!".

---

## 5. Flashing and intensity

Large flashes and strobing can trigger photosensitive seizures. The widely used guideline (WCAG) is no more than three flashes in any one-second period for large areas.

- Impact frames, screen-wide white flashes, and strobing rarity reveals are the risky effects in Roblox games. The reference project's cinematic ultimates used white, monochrome and negative impact frames: keep each to a single short frame and never repeat several per second.
- Offer a setting to reduce screen effects (flashes, shake, chromatic effects), and tie it to `ReducedMotionEnabled` by default.
- Avoid full-screen red pulsing at low health for long periods; use a vignette with a slow pulse or a static border.

---

## 6. Sound non-reliance

Docs: hearing-impaired players, or anyone with sound off, miss events conveyed only by sound. Pair every important sound with a visual: a boss spawn sound with a banner, an incoming attack wind-up sound with a telegraph on the ground, a "ready" chime with a badge. See [[Sound Design for Games]].

---

## 7. Input and motor accessibility

- Large targets with gaps (44 px, 8 px gaps).
- No required rapid tapping; offer hold or auto options. Auto-roll and auto-collect features in simulators are also accessibility features.
- No precise timing requirements in menus (no "tap within 0.5 s" to claim).
- Full controller support, so players can use adaptive controllers ([[Gamepad and Console UX]]).
- Avoid hover-only information; provide tap or select equivalents.
- Long-press and multi-finger gestures only as shortcuts, never the only way.

---

## 8. Cognitive load

- One objective at a time for new players; reveal features progressively ([[HUD Design]]).
- Consistent placement: the close button is always top-right, primary action always the bright button.
- Clear feedback for every action, including failure ("Not enough gems: need 120 more").
- Undo or confirmation for destructive actions (salvage, rebirth, selling).

---

## 9. An in-game accessibility settings group

Platform settings cover text size, transparency and motion. Games add their own controls for things only the game knows about. A compact set that covers most needs:

| Setting | Default | Effect |
|---|---|---|
| Screen effects | On (Off if `ReducedMotionEnabled`) | Shake, flashes, impact frames, chromatic effects |
| Camera shake strength | 100% | Scales every shake call |
| UI scale | 100% | Multiplies the device `UIScale` (clamped 80 to 130%) |
| Hide other players' effects | Off | Readability and performance in crowds |
| Damage numbers | On | Some players find them noisy |
| Colour-blind assists | Off | Adds patterns or icons where colour carries meaning, or swaps a palette |
| Hold to repeat | On | Holding a button repeats the action (rolling, clicking) |

Store these in the player's save so they follow the player across devices, and expose them to every system through one settings module with change signals. A setting that is read only once at startup and then ignored is a common bug.

---

## 10. Testing accessibility

- Toggle Roblox's Text Size to `Largest`, Background Transparency to opaque, and Reduce Motion on; play every screen.
- View screenshots in greyscale (any image editor) to check colour reliance.
- Run the contrast function over theme tokens.
- Play with sound off.
- Play a session with only a gamepad, and one on a small phone.

---

## Common mistakes

- `TextScaled` everywhere, ignoring the player's text size.
- Fixed boxes that clip at `Largest`.
- Glass panels that ignore `PreferredTransparency`.
- Reduced motion implemented as "shorter tweens" instead of no movement.
- Rarity, state or team shown by colour only.
- Repeated full-screen flashes.
- Information only in sound.

## Checklist

- [ ] All three `GuiService` preferences honoured and listened to.
- [ ] Every screen tested at `Largest` text size.
- [ ] Contrast at least 4.5:1 for body text (or outlined text on art).
- [ ] No colour-only signals.
- [ ] A screen-effects setting; flashes at most three per second.
- [ ] Every important sound has a visual.
- [ ] Targets 44 px, gaps 8 px, no rapid-tap requirements.

See also: [[Text Fonts and Rich Text]], [[UI Design Systems]], [[Responsive UI for Phone Tablet Console and PC]], [[Gamepad and Console UX]], [[UI and GUI Animation]], [[Camera Shake and Camera FX]], [[Ethical Design and Player Trust]].

## Connected notes
<!-- auto-links:start -->
[[Accessibility Start Here]] · [[Accessibility Contrast]] · [[Readable Text and UI Scale]] · [[Motion Sensitivity and Camera Comfort]] · [[Skill - Roblox UI Builder]] · [[Game Feel and Juice]]
<!-- auto-links:end -->
