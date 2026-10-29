---
tags: [vfx, highlight, outline, selection, readability, feedback, type/guide, area/vfx, level/intermediate, api/AlwaysOnTop, area/gameplay, api/TweenService]
---
# Highlights and Selection Effects

<!-- tldr:start -->
> [!tldr] TL;DR
> - New highlights do not appear: Slot limit reached, often by disabled highlights -> Destroy unused highlights.
> - Outline stopped showing after a hit flash: A leftover Highlight on the same model -> One arbiter per object, or destroy flashes.
> - Frame spike on every flash: Creating and destroying Highlights -> Animate transparency of a persistent one.
> - Every Highlight sets fill, outline and depth mode explicitly.
> - One owner per highlighted object (arbiter) or one container Highlight per class.
> - Flashes animate a persistent Highlight; unused Highlights destroyed, not disabled.
>
> Cost: TL;DR ~190 tok · whole note ~3.4k tok. Read more: ## 1. Highlight properties · ## 2. One Highlight per object, and who owns it · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A `Highlight` draws an outline around a model or part and an optional tinted fill over it, optionally visible through walls. It is the cheapest way to say "this matters": the interactable chest, the enemy that just aggroed, the teammate behind a wall, the character that took damage, the tutorial target. Because it is so easy to use, games accumulate highlights from five systems that fight over the same character, and on mobile the first one on screen costs real GPU time.

This note covers `Highlight` properties and limits, how several systems can share highlights without conflict, the classic selection adornments (`SelectionBox`, `SelectionSphere`, `SurfaceSelection`), and alternatives such as Neon shells.

Source labels: **Docs** (October 2026), **API dump**, **Reference project** (one production game), **Rule of thumb**.

---

## 1. Highlight properties

| Property | Default (API dump) | Notes |
|---|---|---|
| `Adornee` | nil | The instance to highlight. If nil, the Highlight applies to its parent (Docs: parent it directly to a Model or BasePart, or set Adornee from elsewhere). |
| `DepthMode` | `AlwaysOnTop` | `AlwaysOnTop`: visible through anything. `Occluded`: hidden where something is between camera and object (Docs). |
| `Enabled` | true | Toggling is lightweight, but a disabled Highlight **still uses a slot** (Docs). |
| `FillColor` | (1, 0, 0) red | Interior tint. |
| `FillTransparency` | 0.5 (API dump) | The guide calls 0 the default; the API dump says 0.5. Set it explicitly. 1 = outline only. |
| `OutlineColor` | white | |
| `OutlineTransparency` | 0 | 1 hides the outline. |

The default look (red half-transparent fill, white outline, visible through walls) is almost never what you want. Every Highlight you create in code should set all five visual properties.

### Limits and costs (Docs)

- **Up to 255 Highlights display at once on a client**; extras are silently ignored. Disabled ones count. Delete highlights you will not use again rather than disabling them.
- **Adding or removing a Highlight can trigger a geometry rebuild**: performance spikes and extra draw calls. Changing properties of an existing Highlight is lightweight. So for a flashing effect, keep the Highlight and animate its transparency, rather than creating and destroying it each flash.
- The **first Highlight on screen carries most of the cost** (up to 1 ms of GPU time on mobile); further ones add little.
- On **mobile**, cost grows with screen coverage; on other platforms it does not.
- Highlights not visible on screen (disabled or fully transparent) cost nothing.
- Objects with Highlights nested inside other highlighted objects can draw wrongly because of back-to-front order; keep highlighted objects out of parent/child relationships with each other.
- Low-end devices may draw highlights more pixelated.

**Limit history:** the limit used to be 31 simultaneous highlights, and many older codebases (including the reference project's) budget against 31. As of October 2026 the docs say 255. Budgets are still worth keeping: the conflict problems below and the mobile cost do not care about the limit.

---

## 2. One Highlight per object, and who owns it

The real-world failure is not the slot limit. It is **several systems highlighting the same character**:

- In the reference project, a hit-flash system left a **disabled** Highlight on characters after a flash. A separate outline system's Highlight on the same model then stopped showing. The fix was to create a fresh Highlight per flash and destroy it after the fade, and to have the outline system recreate its outline if missing.
- The same project's enemy stroke (a black outline on every enemy) was a **single Highlight** whose `Adornee` was the container holding all enemies: one slot for the whole roster. While a hit flash, aggro throb or elite rim Highlight existed on a specific enemy, that one won.

Two workable designs:

| Design | How | Good for |
|---|---|---|
| Container highlight | One Highlight adorned to a folder or model of many objects | Uniform outlines on a whole class (all enemies, all pickups) |
| Arbiter per object | One Highlight per object, owned by an arbiter; systems push requests with priorities | Objects that need different looks at different times (hit flash over aggro over idle outline) |

### A highlight arbiter

```lua
--!strict
-- HighlightArbiter (client): one Highlight per target, highest-priority request wins.
local TweenService = game:GetService("TweenService")

export type Look = {
	fillColor: Color3,
	fillTransparency: number,
	outlineColor: Color3,
	outlineTransparency: number,
	depthMode: Enum.HighlightDepthMode,
}

type Slot = {
	highlight: Highlight,
	requests: { [string]: { priority: number, look: Look } },
}

local HIDDEN: Look = {
	fillColor = Color3.new(1, 1, 1),
	fillTransparency = 1,
	outlineColor = Color3.new(1, 1, 1),
	outlineTransparency = 1,
	depthMode = Enum.HighlightDepthMode.Occluded,
}

local slots: { [Instance]: Slot } = {}

local Arbiter = {}

local function getSlot(target: Instance): Slot
	local slot = slots[target]
	if slot and slot.highlight.Parent then
		return slot
	end
	local h = Instance.new("Highlight")
	h.Name = "ArbiterHighlight"
	h.Adornee = target
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Parent = target
	slot = { highlight = h, requests = {} }
	slots[target] = slot
	target.Destroying:Once(function()
		slots[target] = nil
	end)
	return slot
end

local function refresh(target: Instance, fade: number)
	local slot = slots[target]
	if not slot then
		return
	end
	local best: { priority: number, look: Look }? = nil
	for _, r in slot.requests do
		if best == nil or r.priority > best.priority then
			best = r
		end
	end
	if best == nil then
		-- Nothing wants it: destroy rather than disable (disabled still takes a slot).
		slot.highlight:Destroy()
		slots[target] = nil
		return
	end
	local look = best.look
	local h = slot.highlight
	h.DepthMode = look.depthMode
	TweenService:Create(h, TweenInfo.new(fade), {
		FillColor = look.fillColor,
		FillTransparency = look.fillTransparency,
		OutlineColor = look.outlineColor,
		OutlineTransparency = look.outlineTransparency,
	}):Play()
end

function Arbiter.request(target: Instance, id: string, priority: number, look: Look, fade: number?)
	local slot = getSlot(target)
	slot.requests[id] = { priority = priority, look = look }
	refresh(target, fade or 0.08)
end

function Arbiter.release(target: Instance, id: string, fade: number?)
	local slot = slots[target]
	if not slot then
		return
	end
	slot.requests[id] = nil
	refresh(target, fade or 0.15)
end

Arbiter.HIDDEN = HIDDEN
return Arbiter
```

A hit flash becomes `Arbiter.request(char, "hit", 50, redLook, 0.03)` then `task.delay(0.12, Arbiter.release, char, "hit", 0.2)`. The idle outline is a long-lived request at priority 0 that comes back by itself.

Note the trade-off: the arbiter destroys the Highlight when no request remains (good for slots), which creates geometry rebuilds when requests come and go often. For something that flashes many times per second, keep a long-lived low-priority request (even an invisible look) so the Highlight persists while it matters.

---

## 3. Highlight recipes

| Use | Look | Reference |
|---|---|---|
| Hit flash | Red or white fill 0.3 to 0.5, no outline, 0.03 s in, 0.12 to 0.2 s out; throttle one per 0.12 s per character; stronger for big hits (reference project: bigger flash for hits of 12% or more of max health) | Reference project |
| Charge pulse | `FillTransparency` 1 to 0.4 to 0.6, Circular InOut, reversing, 0.18 to 0.3 s | Studied VFX packs |
| Aggro / elite rim | Coloured outline, no fill, `Occluded` | Reference project |
| Enemy stroke for readability | Black outline, no fill, `Occluded`, one Highlight adorned to the enemy container | Reference project |
| Teammates through walls | Outline only, `AlwaysOnTop`, team colour, outline transparency 0.3 | Rule of thumb |
| Tutorial target | Pulsing outline plus a guide beam and a label; up to 4 biggest pieces of a large target, one Highlight each | Reference project |
| Interactable hover | Thin white outline, `Occluded`, fade in 0.1 s on hover or proximity | Rule of thumb |

**Do not convey state by colour alone.** Red versus green outlines are unreadable for many colour-blind players. Pair colour with shape, pulse rhythm or an icon ([[Accessibility]]).

**[[AlwaysOnTop]] is information.** A Highlight that shows enemies through walls is a gameplay feature (a wallhack) if the player should not know that. Use `Occluded` unless seeing through walls is intended.

---

## 4. Classic selection adornments

Before `Highlight`, games used adornments. They are still useful for bounding boxes, build tools and placement previews.

| Class | Key properties (API dump defaults) | Draws |
|---|---|---|
| `SelectionBox` | `Adornee` (any Instance, typically a part or model), `LineThickness` 0.15, `Color3`, `Transparency`, `SurfaceColor3` blue, `SurfaceTransparency` 1 | Wireframe box around the adornee's bounding box, optional filled faces |
| `SelectionSphere` | `Adornee` (a PVInstance), `Color3`, `Transparency`, `SurfaceColor3`, `SurfaceTransparency` 1 | Sphere around it |
| `SurfaceSelection` | `Adornee`, `TargetSurface` (`Right` default), `Color3` | One face of a part |
| Handle adornments (`BoxHandleAdornment` and similar) | Size, offset, `AlwaysOnTop`, `ZIndex` | Primitive shapes for gizmos |

Strengths: box-shaped, crisp, no Highlight slot, no silhouette rendering. Weaknesses: they show the bounding box, not the shape, so they look wrong on characters. Use them for build mode, plot outlines, hit-box debugging ([[Hitboxes and Hit Detection]]), and placement grids.

---

## 5. Alternatives to Highlight

| Technique | When |
|---|---|
| **Neon shell** (a slightly enlarged duplicate mesh in Neon, high transparency 0.9 to 0.97) | Glows, auras, "powered up" states. Costs one draw per shell and no Highlight slot. |
| **[[ForceField]] material shell** | Animated energy shield look. The reference project used a ForceField shell instead of a glass-refraction effect. |
| **Material or colour swap** | Hit flash on simple parts: tween `Color` to white and back. Cheapest of all, but needs per-part bookkeeping. |
| **BillboardGui marker** | Distant objectives, off-screen indicators. See [[World-Space UI - BillboardGui and SurfaceGui]]. |
| **Particles at the feet** | Selection rings for RTS-style selection; one flat ring card under each unit. |

Shell technique notes: set `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` to false on shells; weld them to the target; keep `Material.Neon` with `Transparency` at least 0.9 so they read as a sheen, not a solid.

---

## 6. Performance budget (rule of thumb)

- Highlights on mobile: keep the visible count low and small on screen; disable decorative highlights at low detail.
- Prefer one container Highlight over hundreds of per-object ones for uniform outlines.
- Never create and destroy Highlights per frame or per rapid flash; animate an existing one.
- Clean up on death and despawn: a Highlight parented to a character that respawns is destroyed with the old model, but one parented elsewhere with `Adornee` set will linger pointing at nothing.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| New highlights do not appear | Slot limit reached, often by disabled highlights | Destroy unused highlights. |
| Outline stopped showing after a hit flash | A leftover Highlight on the same model | One arbiter per object, or destroy flashes. |
| Frame spike on every flash | Creating and destroying Highlights | Animate transparency of a persistent one. |
| Enemies visible through walls | Default `AlwaysOnTop` | `Occluded` unless intended. |
| Default red tint on everything | Fill defaults left in place | Set all visual properties explicitly. |
| Highlight looks broken on nested models | Highlighted object inside another highlighted object | Keep highlighted objects separate. |
| Colour-blind players miss the cue | Colour-only signalling | Add pulse, shape or icon. |

## Checklist

- [ ] Every Highlight sets fill, outline and depth mode explicitly.
- [ ] One owner per highlighted object (arbiter) or one container Highlight per class.
- [ ] Flashes animate a persistent Highlight; unused Highlights destroyed, not disabled.
- [ ] `Occluded` by default; `AlwaysOnTop` only when seeing through walls is intended.
- [ ] Cues readable without colour.
- [ ] Mobile tested with the maximum realistic number of highlights on screen.

See also: [[VFX Design Playbook]], [[Game Feel and Juice]], [[Light Sources and Shadows]], [[Hit Reactions Stagger and Hit-Stop]], [[Hitboxes and Hit Detection]], [[First-Time User Experience and Onboarding]], [[Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Links - Highlights and selection]] · Voxel Art - Studs Outlines and Style Kits · Rendering Performance · Accessibility Contrast · Colour-Blind Safe Design · Voxel and Blocky Modeling
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[VFX Performance Budgets and Culling]] · [[Gore Policy and Kid-Friendly Hit Feedback]] · [[Particle Emitters In Depth]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Beams and Trails]] · [[Stylized Lighting Recipes]] · [[Atmosphere Sky Clouds and Post-Processing]]
<!-- related:end -->
