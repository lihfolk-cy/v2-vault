---
tags: [qol, comfort, reduced-motion, flashes, photosensitivity, damage-numbers, hit-stop, juice, settings, type/guide, area/game-feel, level/intermediate, api/GuiService]
---
# Comfort Toggles - Flashes Damage Numbers and Hit-Stop

<!-- tldr:start -->
> [!tldr] TL;DR
> - Some effects ignore the toggle: Each effect checks settings itself -> One `Comfort` gate module
> - Flashes off removes damage feedback: Feedback was only the flash -> Vignette and direction indicator
> - Strobing rarity reveals: No flash limiter -> Three per second cap
> - Reduced motion: Follow / On / Off.
> - Flash toggle with replacement feedback and a 3-per-second limiter.
> - Damage numbers: All / Mine only / Off, merged, capped, pooled.
>
> Cost: TL;DR ~150 tok · whole note ~1.8k tok. Read more: ## 2. One gate every effect asks · ## 3. Flashes: replace, do not just remove · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Juice makes a game feel great until it is the 400th impact of a session, or until it triggers a migraine. Four toggles cover most complaints: **reduced motion**, **screen flashes**, **damage numbers** and **hit-stop**. This note is about exposing them cleanly and making every effect obey them through one gate. The safety and sickness reasoning is in [[Motion Sensitivity and Camera Comfort]]; the tuning numbers for hit-stop and shake are in [[Hit-Stop and Screen Shake Tuning by Numbers]]; the effects themselves in [[Game Feel and Juice]] and [[Hit Reactions Stagger and Hit-Stop]].

Sources: **Roblox docs** for `GuiService.ReducedMotionEnabled` (https://create.roblox.com/docs/reference/engine/classes/GuiService); **WCAG 2.3.1** three-flashes threshold (https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold.html); Game Accessibility Guidelines (https://gameaccessibilityguidelines.com/). Defaults are **Rule of thumb**.

## 1. The four toggles and their defaults

| Toggle | Default | Under platform reduced motion | What it controls |
|---|---|---|---|
| Reduced motion (game override) | Follow platform | n/a | UI tweens, idle bobbing, parallax, camera kicks |
| Screen flashes | On | Off | Full-screen white/red flashes, impact frames, rarity strobes |
| Damage numbers | On | On | Floating numbers above targets |
| Hit-stop | On | Shortened | Freeze frames on hit |

Reduced motion is a three-way choice: **Follow Roblox setting**, **On**, **Off**. A player whose OS setting is off may still want less motion in your game, and vice versa.

Damage numbers are not a comfort issue for most players but a clutter issue; some like them, some find them noisy. Offer three states: **All**, **Mine only**, **Off**. "Mine only" (numbers from the local player's hits) is the best default in busy multiplayer fights (**Rule of thumb**).

## 2. One gate every effect asks

```lua
--!strict
-- StarterPlayerScripts/Comfort (ModuleScript)
local GuiService = game:GetService("GuiService")
local ClientSettings = require(script.Parent.ClientSettings)

local M = {}

function M.reducedMotion(): boolean
	local choice = ClientSettings.get("reducedMotion") :: string -- "follow" | "on" | "off"
	if choice == "on" then return true end
	if choice == "off" then return false end
	return GuiService.ReducedMotionEnabled
end

function M.flashesAllowed(): boolean
	return ClientSettings.get("flashes") == true and not M.reducedMotion()
end

-- Returns a duration multiplier for hit-stop: 1 normal, 0.4 reduced, 0 off.
function M.hitStopScale(): number
	if ClientSettings.get("hitStop") ~= true then return 0 end
	return if M.reducedMotion() then 0.4 else 1
end

function M.showDamageNumber(fromLocalPlayer: boolean): boolean
	local mode = ClientSettings.get("damageNumbers") :: string -- "all" | "mine" | "off"
	if mode == "off" then return false end
	return mode == "all" or fromLocalPlayer
end

return M
```

Schema additions: `reducedMotion` choice (`follow`, `on`, `off`), `flashes` bool, `hitStop` bool, `damageNumbers` choice (`all`, `mine`, `off`). The `ReducedMotionEnabled` value can change at runtime (**Roblox docs**), so long-running effects should listen to `GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")` and to `ClientSettings.Changed`.

## 3. Flashes: replace, do not just remove

Turning flashes off should not remove the information. A red full-screen flash on damage tells the player they were hit. With flashes off, replace it with:

- a **steady vignette** at the screen edges that fades over about 0.3 s, at low opacity;
- a **directional damage indicator** (arc pointing at the source);
- the **health bar shake or flash** only (small area, not full screen).

Even with flashes on, keep a limiter: no more than three full-screen flashes in any one-second window, and avoid saturated red full-screen flashes (WCAG 2.3.1 threshold, **Roblox docs do not enforce this; it is your job**).

```lua
--!strict
local recent: { number } = {}
local function tryFlash(): boolean
	local now = os.clock()
	for i = #recent, 1, -1 do
		if now - recent[i] > 1 then table.remove(recent, i) end
	end
	if #recent >= 3 then return false end
	table.insert(recent, now)
	return true
end
```

## 4. Hit-stop on clients only

Hit-stop must never pause the server simulation or another player's game. It is a local presentation effect: slow the attacker's and victim's animation tracks for a few frames on each client that sees the hit, scaled by `hitStopScale()`. Multiply the authored duration; at scale 0 skip the freeze but keep the hit sound and spark, which carry most of the impact on their own. See [[Client Hit Prediction for Melee Feedback]] for timing on the attacker's client.

## 5. Damage number clutter controls

Even players who keep numbers on benefit from:

- **Merging**: hits on the same target within about 0.15 s add into one number that pops slightly larger.
- **A cap**: at most around 12 numbers on screen; drop the oldest.
- **Crits stand out by size and colour, not by flashing.**
- **Abbreviation** with [[Big Numbers Precision and Formatting]] (12.4K, not 12412).
- **Pooled labels** so a 30-player fight does not create thousands of `BillboardGui` instances.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Some effects ignore the toggle | Each effect checks settings itself | One `Comfort` gate module |
| Flashes off removes damage feedback | Feedback was only the flash | Vignette and direction indicator |
| Strobing rarity reveals | No flash limiter | Three per second cap |
| Hit-stop desyncs combat | Applied on the server | Client presentation only |
| Busy fights unreadable | Numbers from every player | "Mine only" default, merging, cap |
| Reduced motion ignored after toggling OS | Read once at startup | Listen to the property change |

## Checklist

- [ ] Reduced motion: Follow / On / Off.
- [ ] Flash toggle with replacement feedback and a 3-per-second limiter.
- [ ] Damage numbers: All / Mine only / Off, merged, capped, pooled.
- [ ] Hit-stop toggle, client-only, scaled under reduced motion.
- [ ] All effects ask one gate module and react to live changes.

## See also

- [[Motion Sensitivity and Camera Comfort]]
- [[Hit-Stop and Screen Shake Tuning by Numbers]]
- [[Game Feel and Juice]]
- [[Accessibility Cross-Links for QoL Settings]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Reward Moments and Celebrations]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Settings Menu Essentials and Persistence]] · [[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Colourblind Palettes Text Size and Tooltips]] · [[UI Scale HUD Hide and Compact Mode]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Controller Support QoL]]
<!-- related:end -->
