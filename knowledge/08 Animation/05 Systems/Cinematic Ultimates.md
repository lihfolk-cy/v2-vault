---
tags: [systems, abilities, ultimates, camera, cinematics, networking]
---
# Cinematic Ultimates

<!-- tldr:start -->
> [!tldr] TL;DR
> - Explosion next to the enemies: Damage, VFX and enemy position use different centres -> One anchor, shared compute
> - Enemies die during the drag: Damage before pull -> Pull-only first hit
> - Impact a few frames off the cut: Enemy snap on server time -> Local climax for the caster
>
> Read more (15 KB note): ## The anchor contract · ## Layer one: the additive ultimate camera (everyone) · ## Common mistakes
<!-- tldr:end -->

An ultimate is the move players save up for and want to show off. In one live action game (the reference project) every weapon's last move is an ultimate, and every ultimate is a short cutscene for its caster, an additive camera package for everyone, and a choreographed sequence for the enemies it hits. Making those three line up (the enemies are exactly at the centre of the explosion, on the exact frame the camera cuts to it) took an explicit contract between four subsystems. This note documents that contract and the two camera layers, with their numbers.

## The problem the contract solves

Before the contract, each ultimate's damage was centred wherever its kit's server said, its explosion VFX wherever its client said, enemies stood wherever they happened to be, and the camera framed the caster. Measured result: enemies were up to **19 studs** from the visual centre of the effect. Players saw a giant explosion next to the enemies, then the enemies died anyway.

After the contract: 87 ultimate servers plus 4 older ones anchored, **centre error 0.00**.

## The anchor contract

Four owners, one shared definition:

| Owner | Responsibility |
|---|---|
| Combat (server) | Computes the anchor, pulls enemies to it before damage, centres climax hits on it |
| Enemy (server AI + client motion) | Holds caught enemies at the anchor until the climax, then reacts |
| Ultimate camera (client) | Frames the anchor; times the climax |
| VFX (client) | Draws the climax at the anchor |

### 1. The anchor

**Anchor = where the enemy body centre must be at the climax = the visual centre of the ultimate's explosion.** Declared per ultimate in the kit's server move table:

```lua
anchor = { fwd = 18, right = 0, up = nil } -- studs in the CAST frame
-- fwd along the flat look vector, right along the flat right vector, up = world Y
-- up omitted: enemies stand on the ground there (server raycasts the floor)
```

A shared module computes it identically on server and client:

```lua
-- compute(castCF, spec, ignore?) -> position, grounded
local function compute(castCF: CFrame, spec: { fwd: number, right: number, up: number? }, ignore: Instance?): (Vector3, boolean)
	local look = (castCF.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = (castCF.RightVector * Vector3.new(1, 0, 1)).Unit
	local p = castCF.Position + look * spec.fwd + right * spec.right
	if spec.up then
		return Vector3.new(p.X, castCF.Position.Y + spec.up, p.Z), false
	end
	-- floor raycast (CanCollide geometry, skipping Humanoid models); fallback below the caster
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { ignore } else {}
	local hit = workspace:Raycast(p + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y else castCF.Position.Y - 4.8
	return Vector3.new(p.X, y, p.Z), true
end
```

(The reference module also skips models with Humanoids in the floor ray and keeps a replicated mirror of every kit's spec, `Specs[weaponId] = { fwd, right, up?, t = climax seconds after cast, hold }`, 88 entries.)

The server sets two character attributes at cast: `FinisherAnchor` (the Vector3) and `UltAnchorT` (`workspace:GetServerTimeNow()` at cast), cleared after `t + hold + 1 s`. The caster's client computes the anchor locally (no network wait); onlookers read the attributes.

### 2. Pull before damage

**Rule: pull enemies to the anchor before any damage.** The ultimate's first hit is a pull-only entry:

```lua
{ t = 0.15, pullOnly = true, anchor = true, pull = HOLD }
```

It pulls every target into a **tight stack** around the anchor (spacing at most 1.5 studs, centred), gliding them over about 0.7 s, and holds them there through the climax. Every damage hit of the climax marked `anchor = true` is centred on the anchor. Bosses are never pulled (they get a heavy-hit recoil instead; see [[Hit Reactions Stagger and Hit-Stop]]).

Why pull first: damage during the drag would kill enemies on the way in, and they would die away from the explosion. Pull, hold, then hit.

### 3. The caught enemy

The enemy side receives `caught(model, centre, hold, { climaxAt, glide, air, tight })`:
- `climaxAt` is the **server time** of the final blast: `UltAnchorT + spec.t`.
- `glide` is the drag-in time (0.7 s default).
- `air` is the hold height: omitted means a vortex hover at about 0.25 x body height; `0` means pinned on the ground (slams); a higher centre lifts the body to it.
- Combat glides the root to its stack slot and **leaves it there until `climaxAt`**; the enemy motion never moves the root during the hold (limbs only).
- Hits before the climax play as **jolts** on the held body. At the climax: an impact snap, then survive (blowback, stagger, idle) or die (thrown, then its own death clip).
- Attributes written once at catch (`CaughtSeq`, `CaughtAt`, `CaughtCentre`, `CaughtClimax`, `CaughtAir`) let every client animate the sequence locally. AI is locked until the climax plus a family-specific reaction time (about 1.4 to 1.8 s).
- A health-bar stagger no longer breaks a catch.

See [[Enemy and NPC Animation]] for the per-family procedural motion.

### 4. Climax alignment on the caster's screen

The enemies' impact snap is scheduled on server time. But the caster's cutscene times its climax cut on the caster's own clip. Those differ by latency, so the impact landed a few frames off the cut. The fix: the enemy motion asks the cinema for the **local climax** (`localClimax(anchor)` returns the caster's own `os.clock()` of the climax and the impact hold), so on the caster's screen the impact snap lands **exactly on the climax frame** and holds for the tier's hit-stop. Onlookers use server time. Aligning those needed **18 corrections to spec `t` values**, where the data's climax time did not match the clip's climax marker.

A related constant: the ability controller fires the cast to the server **0.06 s** after the clip starts (`CLIENT_LEAD = 0.06`), and kit servers time hits from receipt with `t = marker - 0.06`. The cinema accounts for it when converting between clip time and server time. Four player-authored kits drew their explosions from the **server's** clock (receipt plus spec `t`) and are flagged so the cinema times them differently.

## Layer one: the additive ultimate camera (everyone)

Applied on top of the player's own camera, never Scriptable for onlookers. Tier from the weapon's rarity. Beats from markers:
- **OPEN** at t = 0 (or an `Open` marker): FOV punch in over 0.12 s, held to the `Open` mark (usually about 0.21 s, clamped 0.15 to 0.6), then over 0.55 s the widen, dolly back and lift, orbit bias toward the anchor and a partial aim. Grade in over 0.25 s, letterbox in over 0.35 s (under the HUD), a title card "<RARITY> ULTIMATE" plus the move name held 1.35 s; the top two tiers add a low rumble building to the climax.
- **CLIMAX** on the strongest `Impact` / `Detonate` / `Execute` / `Collapse` marker (latest on a tie; `Erupt` / `Shock` as fallbacks; a per-move override). Without a marker: the spec `t`, else 66% of the clip, with a 0.35 s guard when a marker exists. Then impact frames inside the hit-stop, FOV kick, shake when the freeze ends, blur, colour punch (see [[Camera Shake and Camera FX]]).
- **RECOVER** starts at `clamp(clipEnd - 0.6 x recover, climax + post, climax + post + 0.9)` and eases everything to 0 with smootherstep.

### Tier table (reference)

Dolly and lift are studs for a 1.0 body, multiplied by body scale (1.6 in game).

| Tier | Punch / widen / kick (FOV) | Dolly / lift | Orbit bias | Letterbox | Impact frames | Blur | Trauma (shake x) | Post / recover (s) |
|---|---|---|---|---|---|---|---|---|
| Epic | -3 / +5 / -3 | 1.6 / 0.4 | 10 deg | none | none | 4 | 0.40 (1.0) | 0.55 / 0.55 |
| Legendary | -4 / +7 / -4 | 2.0 / 0.5 | 13 deg | 3.5% | white | 6 | 0.50 (1.1) | 0.60 / 0.60 |
| Mythic | -5 / +9 / -5 | 2.6 / 0.6 | 16 deg | 4.5% | white, colour | 8 | 0.60 (1.2) | 0.65 / 0.65 |
| Celestial | -6 / +11 / -6 | 3.2 / 0.75 | 19 deg | 5.5% | mono, colour | 10 | 0.70 (1.3) | 0.70 / 0.70 |
| Divine | -7 / +12 / -7 | 3.8 / 0.9 | 22 deg | 6.5% | negative, mono, colour | 12 | 0.82 (1.45) | 0.75 / 0.75 |
| Eternal | -8 / +14 / -8 | 4.4 / 1.0 | 25 deg | 7.5% | negative, negative+tint, white, colour | 14 | 0.95 (1.6) | 0.80 / 0.80 |

A "wide" frame (effect box over 28 studs) applies x1.25 dolly, x1.15 widen and x0.85 aim; "tight" x0.7, x0.8, x1.15. Measured in Edit: with the camera turned 60 degrees away from the anchor, the look turns 21 (Legendary) to 36 degrees (Eternal) toward it and the anchor is on screen at every climax sample; turned 150 degrees away, the look moves at most 1.2 degrees (the bias fades out instead of spinning the player around).

The additive package respects player control: bias yields up to 65% while the player turns faster than 40 degrees per second, is halved under shift-lock, skips framing in first person, and does nothing in VR.

### Kits must not drive the camera themselves

Older kits had their own shake, FOV and grade helpers, which fought the package. Every helper now calls a gate first (`Gate(kind, pos)`) that returns a multiplier; while the ultimate camera owns the character, the gate suppresses the kit's own camera, grade and banner effects. The gate is a lazy, `pcall`-guarded lookup that returns 1 when the camera module is missing, so a kit behaves exactly as before without it. A patcher inserts the gate into kit code, and **must be re-run on any rebuilt kit** (a rebuilt kit without the gate double-shakes).

## Layer two: the caster's cutscene

At the owner's request ("all ultimates cinematic for the caster"), the additive package hands off to a caster-only Scriptable cutscene. Onlookers keep the additive package.

### Shot grammar

| Shot | When | What |
|---|---|---|
| HERO | 0 to about `Open + 0.28` | Low on the caster, close, a quick push-in (Celestial and up: a dutch tilt easing out) |
| ESTABLISH | While the pull drags enemies in | Wide orbit behind the caster framing the anchor |
| ACTION | 1 shot (Legendary to Celestial), 2 (Divine, Eternal), +1 for long build-ups | TRACK (side tracking a travelling caster), SHOULDER (over the shoulder at the anchor), CRANE (aerial ultimates), LOWORBIT (around a held caster), TOPDOWN (biggest top-tier ultimates) |
| CLIMAX | Cut `pre` seconds before the climax | Low three-quarter from past the anchor, stacked enemies framed by their live bounds, caster behind, pushing in; slow motion on the climax |
| IMPACT | Divine and Eternal | Smash cut on the climax frame (under the impact frames) to the reverse low angle |
| AFTERMATH | After the climax | Wide crane up and back: the blast, survivors thrown, the dead falling |
| RETURN | End | 0.55 s blend into the player's own camera (their zoom and look direction from before) |

The path of the caster (does the move travel, is it aerial) comes from preview data sampled per move, so shot choice is automatic.

### Per-tier grammar values

| Tier | Bars | Actions | Smash | Swoop | Climax cut lead (s) | Slow-mo (s at rate) | Enemy impact hold (s) | Dutch (deg) | Orbit (deg) |
|---|---|---|---|---|---|---|---|---|---|
| Legendary (and Epic) | 9.5% | 1 | no | no | 0.24 | 0.16 at 0.32 | 0.08 | 0 | 22 |
| Mythic | 10% | 1 | no | no | 0.26 | 0.20 at 0.26 | 0.09 | 0 | 28 |
| Celestial | 10.5% | 1 | no | no | 0.28 | 0.24 at 0.22 | 0.10 | 3 | 32 |
| Divine | 11% | 2 | yes | no | 0.30 | 0.28 at 0.20 | 0.11 | 5 | 38 |
| Eternal | 12% | 2 | yes | yes | 0.34 | 0.34 at 0.16 | 0.12 | 7 | 46 |

### Slow motion without slowing the game

The slow-motion beat slows **camera time**, not the world: the cinema evaluates its shot at a warped time `u` that runs at `slowK` for `slow` seconds after the climax, then ramps back to rate 1 over 0.15 s with a quadratic blend (so velocity is continuous). The gameplay clock, server hits and other players are untouched; only the caster's camera dwells on the moment. Combined with the enemies' impact hold, it reads as slow motion.

### Hygiene

While the cutscene runs: every PlayerGui ScreenGui, the CoreGui, the topbar, the cursor, proximity prompts, nameplates and enemy health, stagger and aggro tags are hidden; input is locked with `CutsceneLock = "UltCinema"`; every eye is raycast clear of walls and kept above ground. Everything is restored at the end (the blend), and at once on death, respawn, a weapon swap (quick blend), a cancel before the climax (quick return), the camera being taken by something else, a script error, or the watchdog (no frame for 0.6 s, or past the ultimate's length plus 2 s). A second ultimate continues the cutscene instead of restarting it. **Kill switch:** `UltCinema.Enabled = false` reverts every ultimate to the additive package. See [[Cameras and Cutscenes]].

## VFX on the anchor

The reference VFX rules for ultimates: a vortex at the anchor from 0.15 s (when the pull starts), a charge effect at `Open` (higher tiers), and the climax effect at the spec `t`, on the anchor. A per-cast budget (5,600 particles over 2 s for the caster in one version). Kits that draw their own climax claim it (`claim(char, {"forge"})`) so the shared layer does not double it. Ultimates never draw their own screen grade, shake or FOV: the camera package owns them. See [[VFX Timing with Animation]].

## Authoring rules

- The ultimate is the **last move** of the kit.
- Every ultimate has an `Open` marker and exactly one strongest climax marker.
- The anchor spec's `t` equals the climax marker time (check after every retime; 18 mismatches were found).
- The anchor is where the effect is drawn, not where the caster ends up.
- Pull first (`t = 0.15`, pull only), damage at or after the climax.
- The clip must look good from the hero, establish and climax angles: no hidden-side cheats.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Explosion next to the enemies | Damage, VFX and enemy position use different centres | One anchor, shared compute |
| Enemies die during the drag | Damage before pull | Pull-only first hit |
| Impact a few frames off the cut | Enemy snap on server time | Local climax for the caster |
| Double shake on some ultimates | Kit's own helpers ungated | Re-run the gate patcher |
| HUD missing after an ultimate | Restore path missed | Watchdog plus every exit hook |
| Onlookers lose control | Scriptable used for everyone | Caster only |

See also: [[Ability Kits Architecture]], [[Cameras and Cutscenes]], [[Camera Shake and Camera FX]], [[Boss Animation and Phases]], [[Markers and Events]].

## Connected notes
<!-- auto-links:start -->
[[Camera Systems]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Snippets - Camera Shake and FX]] · [[VFX Design Playbook]] · [[Genre Playbook - Combat and RPG]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Animation Start Here]]
<!-- auto-links:end -->
