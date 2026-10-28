---
tags: [accessibility, colour-blindness, color, palette, ui, vfx, design-tokens, testing]
---
# Colour-Blind Safe Design

[[Accessibility]] already sets the rule: never let colour be the only signal. This note is the engineering behind that rule. It covers what colour vision deficiency actually does to a game palette, how to test a palette with numbers instead of by eye, how to build palette modes that swap cleanly at runtime, why a screen filter cannot fix the problem on Roblox, and where colour failures hide in 3D (telegraphs on grass, team outlines, particles under coloured lighting). It ends with a palette audit script you can run over your design tokens.

Sources: **Roblox docs (as of October 2026)** for engine behaviour (`ColorCorrectionEffect`, `Highlight`, accessibility guidelines), published colour science for the simulation and perceptual-distance formulas (cited inline), and **rule of thumb** for thresholds and design choices.

---

## 1. What colour vision deficiency does to a palette

Roblox docs (as of October 2026) state that over 5% of people have some form of colour blindness. The widely cited epidemiology figure is about 8% of men and 0.5% of women of Northern European descent with red-green deficiency (rule of thumb: the exact rate varies by population). On a platform with a young, global and mostly male-leaning audience in many genres, assume one player in every lobby of twelve to twenty has some deficiency.

The types matter because they fail differently:

| Type | Cone affected | What collapses | Typical game failure |
|---|---|---|---|
| Deuteranomaly / deuteranopia | Green (M) | Red, green, orange, brown, olive drift together | Health green vs damage red; "ready" green vs "locked" red |
| Protanomaly / protanopia | Red (L) | Same axis as deutan, and reds also look darker | Red enemy markers vanish on dark maps |
| Tritanomaly / tritanopia | Blue (S) | Blue vs green, yellow vs pink/violet | Mana blue vs stamina green; gold vs pink rarity |
| Achromatopsia (rare) | All | Only lightness remains | Anything that differs only in hue |

The "-anomaly" forms are partial: the colours are still different, just closer together. That is the important design point. Most colour-blind players can tell red from green when the two are large, saturated and side by side. They fail when the patches are **small** (a 6 px status pip, a thin outline, a distant marker), **far apart** (a green icon in one corner and a red one in another), **desaturated** (pastel UI themes), or **seen briefly** (a 0.2 s flash on a hit). Games create all four conditions all the time.

Two consequences follow:

1. **Lightness is the channel everyone keeps.** If two signals differ clearly in lightness, almost every player can separate them, including achromats. Hue is a bonus channel.
2. **Size and duration compensate.** A signal you cannot redesign can still be rescued by making it bigger or longer-lived.

---

## 2. Design rules that survive every deficiency

### 2.1 Encode with at least two channels

Pick a primary channel that is not hue, then use hue as reinforcement. The channels available in a Roblox UI or world:

| Channel | UI example | World example |
|---|---|---|
| Lightness | Dark locked button, bright claim button | Dark enemy silhouette on a bright arena |
| Shape | Circle vs triangle vs diamond markers | Ring telegraph vs cone telegraph |
| Icon or glyph | Tick / cross / lock | Skull above an elite enemy |
| Text | Rarity name, "LOCKED" | Name tag with team prefix |
| Pattern | Hatched bar when poisoned | Striped decal on a hazard floor |
| Position | Allies on the left of the scoreboard | Team spawns on opposite sides |
| Motion | A pulse on the active quest | A spinning pickup (respect reduced motion, see [[Motion Sensitivity and Camera Comfort]]) |
| Size | Larger icon for higher tier | Bigger aura for elites |

Rarity ladders are the classic case on Roblox. A ladder of grey, green, blue, purple, gold, red, pink collapses for deutan players into roughly three groups. The fix that costs nothing: put the rarity **name** on every card, add a pip count or frame shape per tier, and order tier lightness so it rises (or falls) monotonically. [[Rarity Ladders and Drop Pacing Math]] covers the ladder itself; this note covers making it readable.

### 2.2 Avoid the dangerous pairs, or separate them in lightness

Pairs that are safe for trichromats but fail for many players (rule of thumb):

- Red and green, red and brown, green and brown, green and orange
- Blue and purple (purple loses its red component for protan and deutan viewers)
- Blue and green, yellow and light pink (tritan)
- Any two pastels

When a pair is unavoidable (a red "enemy" team and a green "ally" convention your players expect), push them apart in lightness: a dark red and a bright green, or the reverse. Then also add shape.

### 2.3 Prefer blue and orange for binary oppositions

Blue against orange (or blue against yellow) is the most robust two-team pairing because it differs strongly in the blue-yellow axis that red-green deficiencies keep, and also in lightness. Tritan viewers can lose some of it, so still add shape and text. Many games default to blue versus orange teams for exactly this reason.

### 2.4 Colour the big thing, not the thin thing

A 1 px `UIStroke` or a thin `Highlight` outline carries very little colour information. If team identity lives in an outline, make it a thick outline plus a fill tint plus an icon. For `Highlight`, both `FillColor` and `OutlineColor` exist (Roblox docs, as of October 2026); use a fill with modest transparency rather than relying on the outline alone. See [[Highlights and Selection Effects]] for the instance limits that also apply here.

---

## 3. Measuring a palette instead of eyeballing it

Eyeballing a palette in a simulator screenshot is useful but slow, and it does not scale to 60 design tokens. The faster approach is to compute, for every pair of colours that must be distinguishable, the perceptual distance between them under normal vision and under each simulated deficiency, and flag the pairs that fall below a threshold.

### 3.1 The pipeline

1. Convert sRGB (0 to 1) to linear RGB.
2. For each deficiency, multiply by a 3 x 3 simulation matrix (in linear RGB).
3. Convert each result to Oklab, a perceptual colour space where Euclidean distance roughly matches perceived difference.
4. Compare distance against a threshold.

The simulation matrices below are the full-severity matrices from Machado, Oliveira and Fernandes (2009), "A Physiologically-based Model for Simulation of Color Vision Deficiency", as they are commonly reproduced in open-source tools. The Oklab conversion is Björn Ottosson's published 2020 definition. Both are approximations of human perception, not ground truth; treat results as a screening tool, then confirm the flagged cases by eye.

### 3.2 Thresholds

Oklab lightness runs from 0 to 1, and a distance of about 0.02 is near the threshold of noticing a difference side by side (rule of thumb). Games need far more than "noticeable side by side", because signals are small, brief and far apart. Working thresholds (rule of thumb):

| Situation | Minimum Oklab distance under every simulation |
|---|---|
| Large adjacent patches (two big buttons) | 0.08 |
| Small or separated signals (pips, markers, outlines) | 0.15 |
| Critical gameplay reads (enemy vs ally, safe vs harmful floor) | 0.20, plus a non-colour channel |

Lightness alone is worth checking separately: a difference in Oklab `L` of 0.15 or more survives even achromatopsia.

### 3.3 The audit script

Run this from the command bar or as a test in your test runner ([[Automated Testing with TestEZ and Jest-Lua]]). It takes a token table and a list of pairs that must stay distinguishable.

```lua
--!strict
-- PaletteAudit: flags colour pairs that collapse under simulated colour vision deficiency.
-- Simulation: Machado et al. 2009, severity 1.0, applied in linear RGB.
-- Perceptual distance: Oklab (Ottosson 2020), Euclidean.

type Mat3 = { number }
type Lab = { L: number, a: number, b: number }

local SIMS: { [string]: Mat3 } = {
	protan = {
		0.152286, 1.052583, -0.204868,
		0.114503, 0.786281, 0.099216,
		-0.003882, -0.048116, 1.051998,
	},
	deutan = {
		0.367322, 0.860646, -0.227968,
		0.280085, 0.672501, 0.047413,
		-0.011820, 0.042940, 0.968881,
	},
	tritan = {
		1.255528, -0.076749, -0.178779,
		-0.078411, 0.930809, 0.147602,
		0.004733, 0.691367, 0.303900,
	},
}

local function toLinear(c: number): number
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function cbrt(x: number): number
	return if x < 0 then -((-x) ^ (1 / 3)) else x ^ (1 / 3)
end

local function linearToOklab(r: number, g: number, b: number): Lab
	local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	local l_, m_, s_ = cbrt(l), cbrt(m), cbrt(s)
	return {
		L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
	}
end

local function view(color: Color3, sim: Mat3?): Lab
	local r, g, b = toLinear(color.R), toLinear(color.G), toLinear(color.B)
	if sim then
		r, g, b =
			clamp01(sim[1] * r + sim[2] * g + sim[3] * b),
			clamp01(sim[4] * r + sim[5] * g + sim[6] * b),
			clamp01(sim[7] * r + sim[8] * g + sim[9] * b)
	end
	return linearToOklab(r, g, b)
end

local function distance(p: Lab, q: Lab): number
	local dL, da, db = p.L - q.L, p.a - q.a, p.b - q.b
	return math.sqrt(dL * dL + da * da + db * db)
end

export type Pair = { a: string, b: string, min: number }
export type Finding = { a: string, b: string, vision: string, distance: number, min: number }

local PaletteAudit = {}

function PaletteAudit.run(tokens: { [string]: Color3 }, pairs: { Pair }): { Finding }
	local findings: { Finding } = {}
	for _, pair in pairs do
		local ca, cb = tokens[pair.a], tokens[pair.b]
		assert(ca and cb, `unknown token in pair {pair.a} / {pair.b}`)
		for _, name in { "normal", "protan", "deutan", "tritan" } do
			local sim = SIMS[name] -- nil for "normal"
			local d = distance(view(ca, sim), view(cb, sim))
			if d < pair.min then
				table.insert(findings, { a = pair.a, b = pair.b, vision = name, distance = d, min = pair.min })
			end
		end
		-- Lightness-only check (achromatopsia and greyscale screenshots).
		local dLight = math.abs(view(ca, nil).L - view(cb, nil).L)
		if dLight < 0.15 and pair.min >= 0.15 then
			table.insert(findings, { a = pair.a, b = pair.b, vision = "lightness", distance = dLight, min = 0.15 })
		end
	end
	table.sort(findings, function(x, y)
		return x.distance < y.distance
	end)
	return findings
end

return PaletteAudit
```

Usage:

```lua
--!strict
local PaletteAudit = require(script.Parent.PaletteAudit)

local tokens = {
	ally = Color3.fromRGB(60, 200, 90),
	enemy = Color3.fromRGB(220, 60, 50),
	rare = Color3.fromRGB(70, 130, 255),
	epic = Color3.fromRGB(160, 80, 230),
}

for _, f in PaletteAudit.run(tokens, {
	{ a = "ally", b = "enemy", min = 0.20 },
	{ a = "rare", b = "epic", min = 0.15 },
}) do
	print(`{f.a} vs {f.b} under {f.vision}: {string.format("%.3f", f.distance)} (needs {f.min})`)
end
```

Worked results for these values (computed with a direct port of the same maths, so treat the third decimal as approximate):

| Pair | Normal | Protan | Deutan | Tritan | Lightness gap | Verdict |
|---|---|---|---|---|---|---|
| ally green vs enemy red | 0.364 | 0.287 | **0.127** | 0.392 | **0.140** | Fails deutan and lightness at the 0.20 bar |
| rare blue vs epic purple | 0.155 | **0.080** | **0.041** | 0.162 | **0.033** | Fails protan, deutan and lightness |
| blue (60,170,255) vs orange (255,120,40) | 0.338 | 0.275 | 0.298 | 0.328 | **0.006** | Hue pair is excellent, lightness is identical |

Two lessons hide in that table. First, protan viewers separate this particular red and green better than deutan viewers, so test both rather than assuming "red-green" is one condition. Second, the blue and orange team pair that the rest of this note recommends passes every simulation and still fails the lightness check: in greyscale or on a washed-out phone screen the two teams are the same grey. The fix is cheap (make one team clearly lighter), but you only find it by measuring. The matrices model full-severity dichromacy; anomalous trichromats sit between normal and simulated, so a pass is a good sign, not a guarantee.

### 3.4 What the numbers will not tell you

- **Context.** The script compares swatches. In the game the colour sits on terrain, under `Lighting` and `Atmosphere`, inside a particle with transparency and `LightEmission`. Run the audit on tokens, then always verify in scene.
- **Size.** A pair that passes at 0.15 can still fail as a 4 px pip. Size is a separate rule.
- **Adjacency.** A pair that is never on screen together matters less than one that is. Choose pairs to audit from real screens, not every combination.

---

## 4. Palette modes at runtime

Even with good defaults, a colour mode setting helps players with stronger deficiencies and players who simply prefer higher contrast. The right architecture is **semantic tokens with swappable palettes**, not a screen filter.

### 4.1 Why a filter does not work on Roblox

Some engines offer a post-process that remaps hues for colour-blind players (daltonisation). On Roblox the screen-wide colour tool is `ColorCorrectionEffect`, whose properties are `Brightness`, `Contrast`, `Saturation` and `TintColor` (Roblox docs, as of October 2026). `TintColor` is multiplicative per channel and `Saturation` changes intensity, so neither can move red information into the blue-yellow axis, which is what a correction filter needs. A tint can only make things worse for some colours while helping others. Rule of thumb: do not ship a "colour-blind filter" built from `ColorCorrectionEffect`; ship palette modes.

`ColorCorrectionEffect` is still useful for **testing**: docs state `Saturation` reaches full desaturation at -1, which gives a quick greyscale view of the real scene in Studio. If a signal disappears in greyscale, it relies on hue alone.

### 4.2 Semantic tokens

UI and VFX should never reference raw colours like `Color3.fromRGB(220, 60, 50)`. They reference meanings: `team.enemy`, `state.danger`, `rarity.epic`, `feedback.heal`. A palette maps meanings to colours. A mode is a different palette. This is the same token idea as [[UI Design Systems]], extended to gameplay and world colour.

```lua
--!strict
-- Theme: semantic colour tokens with swappable palette modes (client).
local Theme = {}

export type Mode = "Default" | "RedGreenSafe" | "BlueYellowSafe" | "HighContrast"
export type Token = "team.ally" | "team.enemy" | "state.danger" | "state.safe" | "feedback.heal" | "feedback.damage"

local PALETTES: { [Mode]: { [Token]: Color3 } } = {
	Default = {
		-- Ally and enemy here are the pair from the audit table: same lightness.
		-- Before shipping, lift one of them (for example ally to a paler blue) and re-run the audit.
		["team.ally"] = Color3.fromRGB(60, 170, 255),
		["team.enemy"] = Color3.fromRGB(255, 120, 40),
		["state.danger"] = Color3.fromRGB(230, 50, 50),
		["state.safe"] = Color3.fromRGB(70, 210, 110),
		["feedback.heal"] = Color3.fromRGB(110, 235, 140),
		["feedback.damage"] = Color3.fromRGB(255, 70, 70),
	},
	RedGreenSafe = {
		["team.ally"] = Color3.fromRGB(40, 140, 255),
		["team.enemy"] = Color3.fromRGB(255, 170, 0),
		["state.danger"] = Color3.fromRGB(255, 150, 0),
		["state.safe"] = Color3.fromRGB(40, 120, 255),
		["feedback.heal"] = Color3.fromRGB(120, 200, 255),
		["feedback.damage"] = Color3.fromRGB(255, 190, 40),
	},
	BlueYellowSafe = {
		["team.ally"] = Color3.fromRGB(0, 170, 170),
		["team.enemy"] = Color3.fromRGB(230, 40, 90),
		["state.danger"] = Color3.fromRGB(230, 40, 90),
		["state.safe"] = Color3.fromRGB(0, 170, 170),
		["feedback.heal"] = Color3.fromRGB(90, 220, 220),
		["feedback.damage"] = Color3.fromRGB(240, 70, 110),
	},
	HighContrast = {
		["team.ally"] = Color3.fromRGB(255, 255, 255),
		["team.enemy"] = Color3.fromRGB(255, 220, 0),
		["state.danger"] = Color3.fromRGB(255, 220, 0),
		["state.safe"] = Color3.fromRGB(255, 255, 255),
		["feedback.heal"] = Color3.fromRGB(255, 255, 255),
		["feedback.damage"] = Color3.fromRGB(255, 220, 0),
	},
}

local current: Mode = "Default"
local changed = Instance.new("BindableEvent")
Theme.Changed = changed.Event

function Theme.get(token: Token): Color3
	return PALETTES[current][token]
end

function Theme.mode(): Mode
	return current
end

function Theme.setMode(mode: Mode)
	if mode == current or PALETTES[mode] == nil then
		return
	end
	current = mode
	changed:Fire(mode)
end

return Theme
```

Binding instances to tokens with attributes keeps the swap automatic. Tag any `GuiObject` with `ThemeColor` and give it an attribute `ColorToken = "team.enemy"`; a small binder sets `BackgroundColor3` (or `TextColor3`, or `ImageColor3`, chosen by a second attribute) on add and on `Theme.Changed`. The same binder can handle `Highlight.FillColor`, `ParticleEmitter.Color` (rebuild a `ColorSequence`) and `Beam.Color`. The pattern is the same as the tagged transparency binder in [[Accessibility]].

### 4.3 Things that must not change between modes

- **Lightness ordering.** If "danger" was the brightest signal in Default, keep it the brightest in every mode, or players who switch modes relearn the game.
- **Icons and shapes.** Modes change colour only. Shapes, icons and text are the constant channels.
- **Meaning.** A mode that swaps ally to orange and enemy to blue is a disaster for anyone who switches mid-session. Keep hue families stable where you can, and change lightness and saturation first.

### 4.4 Where to store the mode

Treat it like any other client setting: save it in the player's profile so it follows them across devices ([[Data Schema Design and Migrations]]), apply it before the first frame of UI is shown, and expose a live preview in the settings menu so the player sees a sample team marker, a rarity card and a danger floor while choosing. Default to "Default". Do not try to detect colour blindness.

---

## 5. Colour in the 3D world

UI is the easy half. Most colour-only failures in Roblox games are in the world.

### 5.1 Telegraphs

A red circle on green grass is the single most common failure: for deutan and protan players the red and the grass are close in hue and often close in lightness. The fix, in order of value:

1. **A bright edge.** A thick, high-lightness ring at the border of the area, regardless of fill colour.
2. **A fill pattern.** Hatching or chevrons in the decal or `Texture`, so the area reads as "marked" even in greyscale.
3. **A shape language.** Circles for area attacks, cones or rectangles for directional ones, consistent across the game.
4. **A timing signal.** The fill grows from the centre to the edge as the attack charges. Growth is information that does not depend on colour.

[[Boss Fight Design Patterns]] and [[VFX Design Playbook]] cover telegraph timing; the rule here is that the telegraph must read in greyscale.

### 5.2 Lighting shifts your palette

`Lighting.Ambient`, `OutdoorAmbient`, coloured `Atmosphere` and post effects all tint the scene. A token that passes the audit in the UI can fail in a sunset zone where everything is pushed toward orange. For each zone with strong grading ([[Atmosphere Sky Clouds and Post-Processing]]), take a screenshot of the key gameplay signals there and check them in a simulator and in greyscale. Neon and particles with high `LightEmission` also wash toward white, which compresses hue differences: rely on shape for anything emissive.

### 5.3 Team and name colours

Default player name colours and team colours on Roblox come from the `Team.TeamColor` you choose. Pick team colours from the blue and orange family, then reinforce in places the default UI does not reach: a team icon in your custom nameplate, a shape on the minimap, a different outline style for enemies. If the game has more than two teams, accept that colour alone cannot carry four or more identities for everyone, and give each team an emblem.

### 5.4 Damage numbers and feedback

Heal green against damage red is the classic pair. Add a sign ("+120" vs "-120"), a different font weight, or a different motion direction (heals float up, damage pops out). Critical hits should be bigger, not just yellower.

---

## 6. When not to do this

- **Do not desaturate the whole game "for accessibility".** Colour-blind players still see colour; most see a lot of it. Colour-blind safe means redundant, not grey.
- **Do not treat a mode toggle as permission for a bad default.** Most colour-blind players never open settings. The default palette should pass the audit for critical pairs.
- **Do not over-engineer cosmetic colour.** Avatar items, decorative props and lighting mood do not need to pass anything. Audit only colours that carry information.
- **Do not chase 100% of pairs.** Some brand or genre conventions (gold for legendary) are worth keeping. Keep them, and make sure a second channel carries the meaning.

---

## 7. Testing

- **Greyscale pass in Studio.** Insert a `ColorCorrectionEffect` under `Lighting` with `Saturation = -1` and play a session. Anything you cannot read is relying on hue. This covers 3D and UI in one go (UI is not affected by Lighting effects, so for UI take screenshots and desaturate them in any image editor).
- **Simulator pass.** Take screenshots of key screens and zones and view them through any colour vision deficiency simulator. Do protan, deutan and tritan.
- **Numeric pass.** Run the audit script in CI over the token table.
- **Real players.** If you can, ask colour-blind testers. Simulators approximate dichromacy; anomalous trichromats see something in between, and lived experience catches failures that models miss.
- **Small and far.** Check markers at their smallest on-screen size and at the edge of the screen, on a phone, outdoors brightness if possible ([[Multi-Client and Device Playtesting Protocols]]).

---

## Common mistakes

- Red/green for ally/enemy, ready/locked or heal/damage with no second channel.
- Rarity tiers that differ only in hue, with the name hidden on small cards.
- Status effects shown as small coloured pips.
- A "colour-blind filter" made from `ColorCorrectionEffect`, which cannot remap hues.
- Palettes checked as swatches but never in the lit scene.
- Modes that change shapes or swap hue families, forcing players to relearn.
- Thin outlines as the only team signal.
- Telegraphs that are a coloured fill with no edge, pattern or growth.

## Checklist

- [ ] Every information-carrying colour has a second channel (shape, icon, text, pattern, lightness).
- [ ] Critical pairs pass the audit under normal, protan, deutan and tritan, with lightness checked.
- [ ] Two-team games use blue/orange (or similar) plus emblems.
- [ ] UI and VFX reference semantic tokens, not raw colours.
- [ ] Palette modes swap colour only; lightness order, shapes and meaning are stable.
- [ ] Telegraphs read in greyscale (edge, pattern, growth).
- [ ] Each strongly graded zone checked with a greyscale and simulator pass.
- [ ] The colour mode is saved and previewed live.

See also: [[Accessibility Start Here]], [[Accessibility]], [[Readable Text and UI Scale]], [[UI Design Systems]], [[Highlights and Selection Effects]], [[VFX Design Playbook]], [[Rarity Ladders and Drop Pacing Math]], [[Atmosphere Sky Clouds and Post-Processing]].

## Connected notes
<!-- auto-links:start -->
[[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Colour Scripts and Value Structure for Untextured Art]] · [[Accessibility Contrast]] · [[Stylized Lighting Recipes]] · [[Thumbnail Contrast]] · [[Environment Art Styles]]
<!-- auto-links:end -->
