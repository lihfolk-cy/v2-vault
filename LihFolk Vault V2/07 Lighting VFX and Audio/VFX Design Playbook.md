---
tags: [vfx, design, playbook, combat, particles, beams, budgets, type/guide, area/vfx, level/intermediate, api/ParticleEmitter, area/gameplay]
---
# VFX Design Playbook

<!-- tldr:start -->
> [!tldr] TL;DR
> - Effect is a white blob: All additive, no dark layer, big sprites too bright -> Dark contrast layer; brightness by area.
> - Effect feels slow or floaty: Phases too long -> Cut every phase; hot frame under 0.1 s.
> - Sparks look random: Radial sparks on a directional hit -> Sparks along the swing direction.
> - Layer table written before building; six phases considered.
> - White core, colour edge, dark rim; one dark layer per bright stack.
> - Tier ladder written and audited.
>
> Cost: TL;DR ~160 tok · whole note ~4.3k tok. Read more: ## 1. Design before Studio · ## 5. Budgets and architecture · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This is the method for designing effects that look professional in Roblox, distilled from decoding several open-source effect packs (slashes, glass combos, lightning hand charges, water explosions, staggered beam slashes, auras) and from shipping hundreds of ability effects in one live action game (the reference project). The individual tools are covered elsewhere: [[Particle Emitters In Depth]], [[Beams and Trails]], [[Highlights and Selection Effects]], [[Light Sources and Shadows]]. Timing against animation is in [[VFX Timing with Animation]]. This note is about **design**: how to decide what layers an effect needs, what numbers make them read, how to scale effects by importance, and how to keep a fight readable and fast.

Source labels: **Docs**, **Reference project** (production game and its studies), **Rule of thumb**.

---

## 1. Design before Studio

Professional effects are designed on paper first. The method:

1. **Study a reference frame by frame.** Pause a video of an effect you admire and step through it. Write down what appears on each frame: a flash, then a shape, then sparks, then smoke. Most people are surprised how short each phase is.
2. **Write the layer stack as a table** before building anything:

| Role | Class | Texture | Size curve | Transparency | Life | Brightness / LightEmission | ZOffset |
|---|---|---|---|---|---|---|---|
| Hot flash | ParticleEmitter | star flash | 0 to 20 | 0 | 0.05 | 20 / 1 | 6 |
| Body | 6 slash cards | 4x4 slash flipbook | constant 12 | 0 to 0.5 then 1 | 0.3 | 1 to 20 / 0 to 1 | -0.2 to 0.1 |
| Sparks | ParticleEmitter | spark streak | 3.5 to 0 | 0 | 0.3 to 0.6 | 30 / 1 | 0 |
| Ground | 3 ring cards | wind ring | 0 to 30 ease-out | 0.85 to 1 | 0.4 | 0.1 / 1 | 2 |
| Dark contrast | ring | thick ring, black | 0 to 25 | 0.5 to 1 | 0.4 | 6 / 0.25 | 1 |
| Tail | haze | soft glow | 0 to 30 | 0.9 to 1 | 1.0 | 0.05 / 1 | 0 |

3. **Build to the table**, then tune.

### The six phases of a hit

Every hit effect is made of these phases, in this time order (studied packs):

| Phase | Duration | Content |
|---|---|---|
| Anticipation (optional) | before the hit | Converging specks, an imploding mesh, a highlight pulse, a charge glint |
| Hot frame | 0.03 to 0.09 s | Star or impact flash, size 0 to 16 to 24 (or 30 to 0), LightEmission 1, Brightness 10 to 40, ZOffset 4 to 10 |
| Body | 0.2 to 0.4 s | The shape that reads: slash cards, beam arc, splash sheets, bolt |
| Secondary | 0.3 to 0.8 s | Sparks, shards, specks, wisps, debris with gravity and drag |
| Ground | 0.3 to 0.7 s | Flat rings, wind, cracks, dust, a smoke ring |
| Tail | 0.6 to 2 s | Haze, mist, lingering glow at very low brightness |

The reference project's own ladder, phrased the same way: anticipation, flash frame, shockwave, energy body, directional sparks and debris (along the swing, not radial), smoke, lingering residue. A guideline quoted there from a well-known studio's VFX guidance: **if your effects feel long, they are far too long.**

### Value and colour

- **Value hierarchy:** a white-hot core, the element or weapon colour at the edges, a dark rim for contrast.
- **Palette:** one base hue (often dark, on emitters at high brightness), one hot accent (orange or white), white for wind and foam. Saturated colours read better than pastel in motion.
- **Every bright stack gets one dark layer:** a black-coloured ring at LightEmission 0.25, negative LightEmission (-0.4 to -2) on smoke and debris, a black Neon shell, or grey smoke at LightEmission 0 under additive smoke. Without it, additive layers sum to white and the effect has no shape.
- **Brightness inversely proportional to screen area** (numbers in [[Particle Emitters In Depth]]).
- **Dark layers stay saturated** (blue-black thinning to blue, deep oxblood under fire), never grey: grey ink is what reviewers call "muddy". Add **one** contrasting accent hue at most. Blind-review lessons on value, clutter, smoke, flashes, effect lights and character tinting are collected in [[VFX Readability and Value - Lessons from Blind Reviews]]; multi-beat moves in [[Escalation and Grandeur Without Clutter]].

---

## 2. Core recipes

### Slash card stack
6 to 8 emitters on **one** attachment, each a 4x4 `OneShot` flipbook card, Lifetime 0.3, constant size 10 to 17, `VelocityPerpendicular` with Speed 0.001 and SpreadAngle 0, rotation offsets between 90 and 270, RotSpeed -360 to +800, ZOffset -0.2 to +0.1, Brightness 0.2 to 30, transparency 0 to t 0.5 then to 1. Add a glow copy at 1.3x size, LightEmission 1, Brightness 20, transparency 0.93 (barely there). Different textures per card (base, underlay, core, edge, wisps) give depth.

### Beam crescent
See [[Beams and Trails]]: semicircle with 4/3 r handles, Width0 30 to Width1 0, a sweep of about 175 degrees in 0.18 to 0.25 s with widths shrinking, band copies for a travelling highlight.

### Ground burst
A flat invisible plate (or a Disc emitter) with 3 to 6 ring cards: size 0 to 25 to 35 eased out, envelope 4 to 8, RotSpeed -1050 to -100, TimeScale 0.7 to 0.8, Brightness at most 0.15 for big rings and 6 to 10 for thin hard rings; plus debris that bursts then hangs (Speed 80 to 100, Drag 7, gravity -31) and a dark smoke ring.

### Neon meshes
Rings, domes, shells and swirls as meshes: Material Neon, double-sided, CastShadow off, transparency 0.9 to 0.97 going to 1 (a sheen, not a solid), size from 0 to about 35 x 7 x 35 or imploding 42 to 5.6, random yaw, ±45 to 180 degree spin, 0.3 to 0.5 s with Quad or Cubic Out.

### Lightning
Crackle: 4x4 OneShot lightning flipbooks on a `LockedToPart` disc, Rate 10, life 0.25 to 0.4, Rotation ±360, Brightness 10 to 30, LightEmission 0 (flicker comes from overlap). Bolts: scripted Neon segments (5 segments with ±3 stud jitter, each width swelling then pinching over 0.35 s, 10 ms between segments so the bolt grows, cleaned up after 0.45 s).

### Water
Flash, then random-angle 4x4 splash cards (LightEmission -0.1 to -0.5, Brightness 10 to 45), spray with gravity and drag, ground rings and a fan, then mist (LightEmission 0.98, Brightness 0.005 to 0.06, 1 to 2 s), ripples and bubbles (Acceleration +3 to +5).

### Auras
Breathing sprites (Speed 0.001, LockedToPart, life 2, Rate 1, transparency 1 to 0 to 1, three sizes), ground decals at the feet, rising specks (Rate 20, Acceleration +3), beam cages on limbs, orbiters with trails, and a down-facing SpotLight in the aura colour.

### Composition tricks
- **Stagger copies with delays.** One authored unit copied five times with 0.15 s delays traced a star in a studied pack.
- **Copy the impact to the far end** of a beam slash with a 0.1 s delay so the hit travels.
- **Implode and explode together:** a vortex mesh shrinking while rings expand.
- **Fire everything from animation markers**, not from wall-clock guesses ([[Markers and Events]]).

---

## 3. Tiers: scaling effects by importance

Not every hit deserves every layer. Tie layer count to importance (rarity, move strength, ultimate) with a ladder. The reference project's ladder by item rarity:

| Tier | Adds on its abilities |
|---|---|
| Below Legendary | Base kit effects only |
| Legendary and up | Impact or shockwave |
| Mythic and up | A crater; a charge effect at an ultimate's open |
| Celestial and up | A slash layer |
| Divine and up | Dark bursts and smoke columns |
| Eternal | A pillar on the biggest hit |

Plus, on every ultimate: a vortex at the anchor shortly after start, and a climax effect at the scripted climax time. Marker strength drove a smaller ladder of "juice" on every move (glint on any beat, glow from strength 0.5, streak from 0.8; see [[VFX Timing with Animation]]).

An audit against the ladder found 170 of 373 moves below their tier's minimum, mostly in density, which drove a second pass. **Write the ladder down and audit against it**; "feels underwhelming" becomes a checklist item.

### No doubling: claims

When several systems can draw the same beat (a kit's own effect, a shared tier layer, an ultimate climax), they must **claim** it. A claim names a kind ("climax", "slash", "forge") on a character for a duration; other systems skip claimed kinds. Without claims, the reference project drew three explosions in one spot on some climaxes.

```lua
--!strict
-- Claims: avoid two systems drawing the same beat on the same character.
local claims: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local Claims = {}

function Claims.claim(owner: Instance, kinds: { string }, duration: number)
	local t = claims[owner]
	if not t then
		t = {}
		claims[owner] = t
	end
	local untilTime = os.clock() + duration
	for _, kind in kinds do
		t[kind] = math.max(t[kind] or 0, untilTime)
	end
end

function Claims.isClaimed(owner: Instance, kind: string): boolean
	local t = claims[owner]
	return t ~= nil and (t[kind] or 0) > os.clock()
end

return Claims
```

---

## 4. Readability budgets

Effects that hide the fight are worse than no effects. The reference project's readability pass set per-cast budgets: one ground "floor" at a time, at most 3 large non-floor pieces, at most 35% of the screen covered (55% during an ultimate) by scaling pieces down to no less than 0.6 or dropping them, pieces on the line between the camera and the player's head forced at least 0.75 transparent, and life caps of 1.4 s (floors 2.2). The full table is in [[VFX Timing with Animation]].

Other readability rules:
- **Telegraph enemy attacks** with the same visual language every time (a ground circle that fills, a glint before a swing). Players learn the language; changing it per enemy breaks that.
- **Your effects vs others' effects.** Onlookers see half the particle budget and no screen-space effects (shake, grade, flash) from other players' moves.
- **Dark zones.** A stylised effect set designed in daylight disappeared in dark zones and had to be rebaked brighter, with a small coloured light on large pieces. A "void" element whose palette was near-black drew almost nothing; it was fixed by an inverted treatment (dark body, bright emissive rim). Test every effect in your darkest and brightest zone.

---

## 5. Budgets and architecture

### Client-side only
The server decides that something happened and tells clients (remote, attribute, or replicated marker). Clients build the effect. Server-built effects replicate instances to everyone, cost bandwidth, and arrive late. A VFX runtime the reference project used is client-only and breaks if run on the server.

### Budgets (reference project)

| Budget | Value |
|---|---|
| Particles per premium effect library | 3,200 per 2 s per caster (onlookers half); ultimate caster 5,600 |
| Per sword swing | about 30 emitters and 140 beams; finisher about 44 and 210 |
| Emitters per ability kit folder | 16 |
| Lights per kit | 2 (Range 18, Brightness 1.6) |
| Highlights in the tier layer | 3 |
| Distance | Decoration layers dropped for others' effects beyond about 160 studs; small juice beyond 220 |
| Instances per kit folder | under 2,500 |

### Templates and pooling
- Author effects as templates (a root part or attachment with child attachments and emitters, meshes, beams) in `ReplicatedStorage`. Tag optional layers with attributes (`MinTier`, `MaxTier`, `Detail`, a recolour slot) so code can tier and recolour without editing art.
- Clone each template once per client into a pool; reuse; release after the longest lifetime.
- Recolour by role: a greyscale texture plus `Color` lets one template serve every element; a recolour attribute (main, hot, white, accent, dark, smoke) on each layer tells code which palette slot to apply.

```lua
--!strict
-- Recolour a template by role attributes. Layers carry attribute "C" = "main" | "hot" | "dark" | ...
export type Palette = { [string]: Color3 }

local function recolour(root: Instance, palette: Palette)
	for _, d in root:GetDescendants() do
		local role = d:GetAttribute("C")
		if type(role) ~= "string" then
			continue
		end
		local color = palette[role]
		if not color then
			continue
		end
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Color = ColorSequence.new(color)
		elseif d:IsA("BasePart") then
			d.Color = color
		elseif d:IsA("Light") then
			d.Color = color
		end
	end
end
```

### Assets you cannot rely on at runtime

- **Fresh uploads** fail `PreloadAsync` for about 20 to 60 seconds (reference project). Never judge a texture broken in the first minute; never ship before testing a new upload in a live server.
- **EditableImage and EditableMesh fail in published games by default.** They require the experience setting "Allow Mesh / Image APIs" (Docs), have strict client memory budgets, and `EditableImage` is limited to 1024 x 1024 (Docs). The reference project's rule: never build runtime VFX on them. Bake textures and meshes offline and upload them.
- **Third-party textures** from public packs may be "not approved for the requester" in your experience (the asset's permissions do not include you). Check each one loads in a live server; prefer your own uploads for anything shipped.

### Licences
Many open-source VFX packs are study-only or require credit. Study the technique and rebuild it with your own textures; do not paste another creator's instances into your place unless the licence allows it. See [[Creator Store and Toolbox Safety]].

---

## 6. Stylised (toon) effects pipeline

One approach the reference project used for a cel-shaded effect style, generated offline:
1. Start from a UV gradient over the effect shape.
2. Add noise.
3. Quantise to a constant 4-tone ramp (dark outline band, body, core, hot line).
4. Alpha-threshold over 4 frames to make erosion (dissolve) frames.
5. Pack frames into 4x4 flipbooks; one palette per element.
6. Pair with simple meshes (crescent, burst cones, swirl, torus) and a small coloured light on large pieces.

Lesson from its rollout: the first bake was too dark for dark zones; the second used brighter bands and a wider hot line, and kept the dark tone only as an outline band.

---

## 7. QA

- Freeze and slow effects for review (TimeScale 0 for stills, 0.2 to 0.4 for motion).
- Capture at marker times, not at round numbers.
- Watch at real camera distance, on a phone screen, in the darkest and brightest zones, with 4 to 8 players casting at once.
- Check the readability budgets with a full party, not alone.
- Edit-mode caveat: streams do not run in Edit; bursts do.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Effect is a white blob | All additive, no dark layer, big sprites too bright | Dark contrast layer; brightness by area. |
| Effect feels slow or floaty | Phases too long | Cut every phase; hot frame under 0.1 s. |
| Sparks look random | Radial sparks on a directional hit | Sparks along the swing direction. |
| Three explosions at once | Several systems draw the same beat | Claims. |
| Fights unreadable | No budgets | Floors, piece count, screen share, life caps. |
| Effect invisible in dark zone | Designed in daylight; near-black palette | Brighter bands, emissive rim, small light. |
| Effect blank on first use | Textures not preloaded or freshly uploaded | Preload with the owner; wait out new uploads. |
| Works in Studio, not live | Built on EditableImage/Mesh or unapproved assets | Bake offline; check permissions. |

## Checklist

- [ ] Layer table written before building; six phases considered.
- [ ] White core, colour edge, dark rim; one dark layer per bright stack.
- [ ] Tier ladder written and audited.
- [ ] Claims prevent doubled beats.
- [ ] Readability budgets enforced per cast.
- [ ] Client-only, pooled, recolourable templates.
- [ ] Textures preloaded, own uploads, permissions verified live.
- [ ] Reviewed slowed, at distance, on phone, in dark and bright zones, with a full party.

See also: [[VFX Readability and Value - Lessons from Blind Reviews]], [[Escalation and Grandeur Without Clutter]], [[Particle Emitters In Depth]], [[Beams and Trails]], [[Highlights and Selection Effects]], [[VFX Timing with Animation]], [[Game Feel and Juice]], [[Ability Kits Architecture]], [[Cinematic Ultimates]], [[Combat Systems Architecture]], [[Textures Decals and Texture Memory]], [[Rendering Performance]].

## Connected notes
<!-- auto-links:start -->
[[Mesh VFX Packs Built in Blender]] · [[VFX Performance Budgets and Culling]] · Dash VFX Presentation on an R15 Rig · Links - Particle emitters · Voxel and Blocky Modeling · Dramatic Showcase Renders in Eevee
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]]
<!-- related:end -->
