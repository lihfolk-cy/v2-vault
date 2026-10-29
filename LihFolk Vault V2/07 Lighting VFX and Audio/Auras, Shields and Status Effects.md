---
tags: [vfx, aura, shield, status-effects, buffs, highlight, forcefield, attachments, persistent, lihfolk, type/guide, area/vfx, level/intermediate, api/Highlight, api/Attachment]
---
# Auras, Shields and Status Effects

<!-- tldr:start -->
> [!tldr] TL;DR
> - Character tinted by its own aura: Highlight fill or a big translucent shell over the body -> `FillTransparency` 1; rims and wisps around the body
> - Shins glow in the aura colour: Effect light at foot height -> Light off, or above and behind at low power
> - Auras cost frame time across the map: Streams never sleep -> Sleep beyond 160 studs, wake inside 136
> - Persistent layers at 3-8 per second; about 15 particles alive per aura.
> - Everything on Attachments or adornments; nothing welded to the body.
> - Rim with an outline-only Highlight; no fill, no wash; light off unless asked.
>
> Cost: TL;DR ~190 tok · whole note ~3.1k tok. Read more: ## 4. Shields · ## 7. Replicate states as attributes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Auras, shields and status visuals sit on a character for seconds or minutes, so they follow different rules from a hit burst: **low rates, attached through Attachments, a rim instead of a wash, and sleep when far away**. The character must stay readable underneath, because the player is looking at their own avatar the whole time. This note gives numbers for a character aura, a bubble shield with hit ripples and a break, a status-effect visual table, and the attribute-based replication that late joiners also see. The rules on tinting and rims come from [[VFX Readability and Value - Lessons from Blind Reviews]]; Highlight limits and ownership from [[Highlights and Selection Effects]]; sleeping long-lived effects from [[VFX Performance Budgets and Culling]]; the logic of durations and stacks from [[Status Effects Buffs and Stacking Rules]]; one-shot pickups and celebrations from [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] and [[Reward Moments and Celebrations]]. The LihFolk VFX skill ships `Aura`, `Shield`, `Heal`, `Buff` and `LevelUp` in `LihFolkVFX_Abilities.luau`.

Source labels: **Roblox docs**, **LihFolk module** (shipped values, untested in Studio at the time of writing), **rule of thumb**.

---

## 1. Persistent effects play by different rules

| Rule | One-shot burst | Persistent (aura, shield, status) |
|---|---|---|
| Emission | `Emit` counts | low `Rate` streams, 3-8 per second per layer |
| Particles alive | 20-80 for under a second | 10-20 for as long as it lasts |
| Placement | world space at the hit | Attachments on the character, adornments with the root as `Adornee` |
| Distance | culled beyond 220 studs | sleeps beyond 160 studs, wakes inside 136 (85 percent) |
| Lights | one short pulse | none by default; one dim light above and behind when asked |
| Screen share | brief, can be large | small and steady; the body stays clear |

The arithmetic is the reason: an aura at 15 particles on each of 12 players is 180 particles all the time, a fifth of the 900 PC cap before anyone attacks (**rule of thumb**). Persistent layers have to be cheap.

## 2. The aura recipe

| Layer | Numbers (LihFolk module, intensity 1, scale 1) | Job |
|---|---|---|
| Rim | `Highlight` on the character, `FillTransparency` 1, `OutlineTransparency` 0.3, `DepthMode` Occluded, element glow colour | the element colour on the silhouette, nothing on the body |
| Motes | from a feet Attachment, `Rate` 7, life 1.1-1.6 s, speed 1.2-2.6 up in a 70 degree spread, `Acceleration` +2.5 Y, size 0 -> 0.22 -> 0 | rising energy |
| Dark specks | `Rate` 3, life 0.9-1.3 s, square flecks, `LightEmission` 0 | the dark value layer (decoration) |
| Foot ring | ring adornment 2.55-2.8 studs breathing at 2.4 rad/s over a darker, wider ring | grounds the aura on any floor |
| Orbit wisps | 2 Trails (lifetime 0.35) between Attachment pairs orbiting at radius 2.1, opposite directions, 2.4-3.2 rad/s | motion around, not across, the body (decoration) |
| Light | off by default; when on, `Brightness` 0.6, `Range` 8, 3.5 studs up and 1.5 behind | a nearby light colours the body, so it stays opt-in |

About 15 particles alive at quality 1, 2 Trails, 2 adornments, 1 Highlight.

**Intensity, not on and off.** One number 0 to 1 drives the motes' `Rate`, the rim's `OutlineTransparency` (1 at 0, 0.3 at 1), the ring's transparency and whether the wisps draw. Map stacks or charge levels onto it (for example 1 stack = 0.4, 3 stacks = 0.75, 5 stacks = 1) so one aura grows instead of new layers piling on.

## 3. Attach with Attachments, not welded parts

- An `Attachment` on the `HumanoidRootPart` moves with the character for free: no welds, no mass, no `Massless` flags, nothing for physics to consider.
- Emitters, Trails and lights parent to Attachments; rings and discs are adornments with the root as `Adornee`. The feet sit at `-(root.Size.Y / 2 + Humanoid.HipHeight)` below the root's centre on R15; use -3 for R6.
- **Cleanup is one list.** Keep every instance you created on the character in a table and destroy them together when the effect ends or the character is removed.
- Glowing Neon parts welded to the torso are the classic way to tint a character green; keep glow on the silhouette (rim) and around the body (wisps, ring).

## 4. Shields

### The bubble

| Piece | Numbers (LihFolk module) |
|---|---|
| Shell | `Ball` part, `Material` ForceField (an animated, edge-bright look built into the engine), element body colour, radius 0.6 x character height clamped to 3-8 studs |
| Rim | `Highlight` on the shell, `FillTransparency` 1, `OutlineTransparency` 0.3 breathing by 0.1 at 7.5 rad/s |
| Grow-in | radius from 5 percent to full with an ease-out-back over 0.22 s |
| Glints | 4 per second on the sphere surface, life 0.4-0.6 s (decoration) |
| Follow | the shell is anchored and moved to the root every frame; no weld |

### Hit ripple

Each hit draws a ring on the plane tangent to the sphere at the hit point, and the ring rides the shell:

```lua
--!strict
-- A ripple ring where `worldPos` hits a sphere shell of radius R (CylinderHandleAdornment lies along its Z).
local function addRipple(shell: BasePart, R: number, worldPos: Vector3, color: Color3): CylinderHandleAdornment
	local centre = shell.Position
	local d = worldPos - centre
	local dir = if d.Magnitude > 1e-3 then d.Unit else Vector3.yAxis
	local surface = centre + dir * R
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = shell
	ring.CFrame = shell.CFrame:ToObjectSpace(CFrame.lookAt(surface, surface + dir))
	ring.Height = 0.04
	ring.Radius = 0.2
	ring.InnerRadius = 0
	ring.Color3 = color
	ring.Parent = shell
	return ring -- animate Radius 0.2 -> 1.8 and Transparency 0 -> 1 over 0.35 s, eased out
end

return addRipple
```

Add 10 sparks along the outward normal and flash the shell colour 70 percent toward white, fading over 0.18 s. Cap live ripples at 4 and retire the oldest; a flurry of hits stays readable that way.

### Break

1. The shell expands to 1.3x in 0.18 s while its transparency goes to 1.
2. 22 shards (square flecks, gravity -30, spin) and 12 sparks burst outward.
3. A horizontal ring grows from R to 2.2 R in 0.32 s, thinning and fading.
4. One light above the bubble, `Brightness` 2 to 0 over 0.25 s.
5. Everything is gone 0.8 s after the break.

A shield that times out without breaking fades quietly over 0.25 s instead; the burst is reserved for the moment the shield was beaten.

## 5. Status effects at a glance

Status visuals tell the player and everyone around them what is on a character. Keep each one to one or two layers so three statuses at once still read (**rule of thumb**):

| Status | Visual | Rate / count |
|---|---|---|
| Burning | warm rim (Highlight outline orange) + ember motes rising from the feet | 6/s, life 0.8 s |
| Frozen or slowed | ice-blue rim + frost specks falling slowly; slow the animation speed to match the slow | 3/s |
| Poisoned | green bubbles rising from the chest Attachment, popping (size 0 -> 0.3 -> 0.4, transparency to 1) | 4/s |
| Stunned | 3 small orbiting stars or sparks above the head, radius 0.9, 4 rad/s | Trails or a ring of 3 parts |
| Regenerating | a soft green pulse at each heal tick: one ring at the feet and 3 motes | 1 pulse per tick |
| Empowered | the element aura at intensity 0.4-1 | see section 2 |

When two statuses both want the rim, give the rim to the stronger one and show the other with particles only. A character carries one Highlight per system ([[Highlights and Selection Effects]] has an arbiter for exactly this).

## 6. Pickups and celebrations are one-shots

Heal, buff and level-up moments are short bursts on the character, so they follow the one-shot rules:

- **Heal:** a ring expanding from 1.2 to 4.5 studs in 0.55 s, a faint ground disc fading over 0.7 s, motes rising for 0.9 s (3 every 0.08 s), 6 gold glints at the chest. About 39 particles.
- **Buff:** the ring implodes from 4.5 to 1.1 studs in 0.32 s (gathering), then a small bright pop ring and 3 volleys of upward streaks. About 48 particles. Implode-then-pop reads differently from the heal's outward ring, so players tell them apart without reading colour.
- **Level-up:** two foot rings that escalate (the second bigger, faster and thinner), a scan ring rising from the feet past the head, a light pillar that starts above the head (the body stays clear), a sparkle fountain, confetti and one light above. About 76 particles; a celebration, not an attack ([[Reward Moments and Celebrations]]).

## 7. Replicate states as attributes

One-shots travel as events; **states travel as attributes** on the character. Attributes replicate to everyone, including players who join after the aura started, and clients react with `GetAttributeChangedSignal`:

```lua
--!strict
-- Client: start, update or stop an aura from the character's "Aura" (element) and "AuraLevel" (0..1) attributes.
type AuraHandle = { SetIntensity: (any, number) -> (), Destroy: (any) -> () }
type AuraApi = { Aura: (Model, { [string]: any }) -> AuraHandle }

local function watchAura(character: Model, api: AuraApi)
	local handle: AuraHandle? = nil
	local function refresh()
		local element = character:GetAttribute("Aura")
		local level = character:GetAttribute("AuraLevel")
		local intensity = if type(level) == "number" then math.clamp(level, 0, 1) else 1
		if type(element) ~= "string" then
			if handle then
				handle:Destroy()
				handle = nil
			end
			return
		end
		if not handle then
			handle = api.Aura(character, { element = element, intensity = intensity })
		else
			handle:SetIntensity(intensity)
		end
	end
	character:GetAttributeChangedSignal("Aura"):Connect(refresh)
	character:GetAttributeChangedSignal("AuraLevel"):Connect(refresh)
	refresh()
end

return watchAura
```

The server sets the attributes when the status starts, changes and ends ([[Status Effects Buffs and Stacking Rules]] section 7); clients never write them. More detail on the event side is in [[Replicating VFX - Server Validates, Clients Render]].

---

## Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| Character tinted by its own aura | Highlight fill or a big translucent shell over the body | `FillTransparency` 1; rims and wisps around the body |
| Shins glow in the aura colour | Effect light at foot height | Light off, or above and behind at low power |
| Auras cost frame time across the map | Streams never sleep | Sleep beyond 160 studs, wake inside 136 |
| Aura missing for late joiners | State sent as a one-time event | Character attributes |
| Stacks of the same buff pile up layers | One aura per application | One aura per character, intensity from the stack count |
| Shield hit invisible in a flurry | Ripples replace each other or pile up | Up to 4 ripples, oldest retired, 0.35 s each |
| Shield reads as a solid ball | Opaque or plastic shell | ForceField material plus an outline-only Highlight |
| Leftover attachments on the character | Instances not tracked | One cleanup list per effect |

## Checklist

- [ ] Persistent layers at 3-8 per second; about 15 particles alive per aura.
- [ ] Everything on Attachments or adornments; nothing welded to the body.
- [ ] Rim with an outline-only Highlight; no fill, no wash; light off unless asked.
- [ ] One intensity value drives every layer; stacks map onto it.
- [ ] Sleeps by distance with hysteresis.
- [ ] Shield: ForceField shell, outline rim, ripples on the tangent plane (max 4), a break burst for the beaten shield and a quiet fade for a timeout.
- [ ] Status visuals at one or two layers each; one Highlight owner per character.
- [ ] States replicate as attributes; one-shots as events.

<!-- related:start -->
## Related
[[Projectile VFX - Muzzle, Travel and Impact]] · [[AoE Telegraphs - Readable Ground Warnings]] · [[VFX Design Playbook]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Light Sources and Shadows]] · [[Particle Emitters In Depth]]
<!-- related:end -->
