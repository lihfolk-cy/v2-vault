---
tags: [systems, combat, hit-reaction, stagger, hit-stop, game-feel]
---
# Hit Reactions Stagger and Hit-Stop

<!-- tldr:start -->
> [!tldr] TL;DR
> - Sword arrives after its sparks in flurries: Plain freeze hit-stop with clock-timed VFX -> Catch-up hit-stop
> - Enemy twitches while held or stunned: Flinch not skipped in higher states -> Ladder skip rules
> - Stagger feels like lag: Attack clips slowed -> Only slow the stagger clip
>
> Cost: TL;DR ~110 tok · whole note ~3.4k tok. Read more: ## Directional flinches · ## Hit-stop · ## Common mistakes
<!-- tldr:end -->

A hit is not one event on screen; it is a short stack of reactions on both bodies, layered over a tenth of a second: the attacker's motion catches, the target flashes, flinches in the direction of the blow, maybe staggers, the camera kicks, a spark and a sound land. Getting each layer's timing and priority right is most of what players call "impact". This note covers the reaction ladder, directional flinches, stagger and poise, parry and guard, and hit-stop done in a way that survives networked, clock-timed effects. Numbers are from one live action game (the reference project) unless marked as rules of thumb. Procedural (physics) reactions are in [[Procedural Death Knockdown and Hit Reactions]] and [[Ragdolls and Physics-Based Animation]].

## The reaction ladder

Order reactions by how much control they take from the target:

| Level | What plays | Control lost | Reference trigger |
|---|---|---|---|
| Flash | White highlight, 0.1 s fade | none | every hit |
| Flinch | Short directional clip (HitFront / HitLeft / HitRight) | none (AI keeps acting) | every hit, unless a higher state plays |
| Heavy hit | `HeavyHit` clip, or an additive recoil on bosses | brief | heavy beats, ultimates on bosses |
| Stagger | Stagger clip at 0.5x speed | AI interrupted 1.6 s (bosses 0.9 s) | health crosses 75 / 50 / 25% |
| Knockup / Caught | Knockup, then a Stun loop | AI locked | pulled into an ultimate |
| Stun | Stun loop | AI locked | parried (2.2 s) |
| Death | Death clip, held on the last frame | all | health 0 |

The ladder gives you the **skip rules** for free: a lower reaction never interrupts a higher one. In the reference enemy client:
- The flinch is skipped while Stagger, Knockup or Death is the current one-shot, and while the enemy is Caught or Stunned. Otherwise a flinch at Action2 would visibly twitch a body that is supposed to be helpless.
- No turning while Caught or knocked up (the server stops rotating the root).
- The full Caught clip always plays; a longer hold extends the state rather than cutting the clip.

## Directional flinches

Three or four short clips (0.2 to 0.4 s, rule of thumb) cover every direction, played at **Action2 with a 0.05 s fade** so they sit over locomotion and attack one-shots (Action) without stopping them. Because the flinch is a short overlay at full weight, the attack underneath keeps its timing: the enemy flinches mid-swing and the swing still lands on schedule. That is usually what you want for regular enemies (hits feel acknowledged without making them trivially stun-locked); for "stun-lockable" fodder, stop the attack instead.

Picking the direction from the attacker's position in the target's frame:

```lua
-- Returns the flinch clip name for an attacker at attackerPos hitting a target whose root is root.
local function flinchFor(root: BasePart, attackerPos: Vector3, heavy: boolean): string
	if heavy then return "HeavyHit" end
	local toAttacker = (attackerPos - root.Position) * Vector3.new(1, 0, 1)
	if toAttacker.Magnitude < 1e-3 then return "HitFront" end
	toAttacker = toAttacker.Unit
	local cf = root.CFrame
	local front = cf.LookVector:Dot(toAttacker)
	local right = cf.RightVector:Dot(toAttacker)
	-- Hits from behind also use HitFront in a 3-clip set: a backward lurch reads fine from any side
	-- at gameplay distance. Add HitBack if your camera often sees enemies from behind.
	if math.abs(right) > math.abs(front) then
		-- convention here: the name says where the hit CAME FROM (attacker on the right -> HitRight,
		-- a clip in which the body recoils toward its left)
		return if right > 0 then "HitRight" else "HitLeft"
	end
	return "HitFront"
end
```

Naming convention matters: decide whether `HitLeft` means "hit from the left" or "recoils to the left" and write it in the clip metadata. Half of directional-flinch bugs are a mirrored naming assumption.

### Who decides, who plays

The server decides that a hit happened and which reaction applies; it writes that as replicated state (for example an attribute with the reaction name and a server timestamp), and **every client plays the clip locally**. The server never waits for a reaction clip. See [[Enemy Animation State Protocol]] for the full attribute protocol.

## Stagger and poise

Stagger is a long interruption that opens a punish window. Two common designs:

| Design | How | Pros | Cons |
|---|---|---|---|
| Health thresholds (reference) | Stagger when health crosses 75%, 50%, 25% | Predictable rhythm, readable | Burst damage skips windows |
| Poise meter | Each hit drains poise; stagger at 0; regenerates | Rewards sustained pressure | Needs UI to be readable |

The reference values: stagger lasts **1.6 s** for regular enemies and **0.9 s** for bosses, and the stagger hit clip plays at **0.5x speed**, the only time enemy animation runs below 1x. That rule ("enemy animations never play below 1x, except the stagger") exists because slowed attack clips read as lag, while a slowed stagger reads as weight. A flying enemy's stagger chains into a `StaggerGround` loop (it drops to the floor) until the state ends.

Health-bar staggers must not break special states: in the reference project a stagger while the enemy was held by an ultimate used to cancel the catch; the rule became "health-bar stagger no longer breaks a catch".

## Bosses react differently

- **Bosses are never pulled** into ultimates. Dragging a 50-stud boss into a stack looks absurd and breaks arena fights.
- Instead they get what the project notes call an "additive" heavy-hit recoil, triggered by a `HeavyHit` value in the hurt attribute: a short clip at Action2 that pushes the upper body back without stopping the boss's attack. It is not additive blending in the engine sense; it is a brief full-weight overlay on the joints it keys, which looks additive because it is short and keys only the upper body.
- Boss stagger is shorter (0.9 s) and phase-shift clips are **untouchable** (no damage during them). See [[Boss Animation and Phases]].

## Hit flash

A white flash on hit is the cheapest, most legible reaction. The reference implementation:

- A **pool** of white `Highlight` instances, at most 8 live at once.
- 0.1 s fade.
- A RenderStepped connection that exists **only while at least one flash is live** (no per-frame cost when nobody is being hit).

Highlights have an engine limit on how many render at once (255 as of October 2026; older docs and many codebases say 31, see [[Highlights and Selection Effects]]; treat it as a budget shared with outlines, selection and VFX). The reference project's VFX rules capped decorative Highlights at 3 for exactly this reason. For crowds, bake outlines into meshes and use Highlights only for transient flashes and bosses. See [[Performance and Memory]].

## Hit-stop

Hit-stop (hit pause) freezes the action for a few frames on impact. Game-feel practice puts it at about **50 to 100 ms**, with flash, shake and sound all landing inside that window (rule of thumb, widely cited in action game postmortems).

### The naive version and why it breaks

The obvious implementation is `track:AdjustSpeed(0)` on attacker and target for 40 to 90 ms, then restore. In a networked game with clock-timed effects this causes drift:

- The server scheduled the next hit at `marker - 0.06` seconds after the cast (see [[Combat Combo Systems]]). It does not know about your local freeze.
- VFX and sounds for later markers were often scheduled with `task.delay` from the cast, on the wall clock.
- So after a 70 ms freeze, the body is 70 ms behind its own effects and the server's hits. Three hit-stops into a flurry, the sword visibly arrives after the sparks.

### The catch-up version (reference project)

The reference juice module slows the move almost to a stop, then runs it fast for the same duration so it **ends exactly where the clock says it should be**:

```lua
-- Hit-stop with catch-up: slow for d seconds, then fast for d seconds.
-- Track time advanced over 2d = 0.12*d + 1.88*d = 2*d, exactly what normal playback would advance,
-- so the body is back in sync with clock-timed VFX and server hits after 2d.
local stopping = false
local function hitStop(tracks: { AnimationTrack }, strength: number, reducedMotion: boolean)
	if stopping or reducedMotion then return end
	stopping = true
	local d = 0.03 + 0.045 * strength -- strength 0.45 -> 0.050 s, strength 1.3 -> 0.0885 s
	local held: { [AnimationTrack]: number } = {}
	for _, t in tracks do
		if t.IsPlaying then
			held[t] = t.Speed
			t:AdjustSpeed(t.Speed * 0.12)
		end
	end
	task.delay(d, function()
		for t, sp in held do if t.IsPlaying then t:AdjustSpeed(sp * 1.88) end end
		task.delay(d, function()
			for t, sp in held do if t.IsPlaying then t:AdjustSpeed(sp) end end
			stopping = false
		end)
	end)
end
```

Design details:
- **Only your own moves.** Hit-stop is local presentation for the attacker; other players' characters are not paused on your screen (that would desync what they see of themselves from what you see).
- **Only ability-priority tracks** (Action4) are slowed, so locomotion under an upper-body cast keeps moving and the legs do not freeze mid-stride.
- **Triggered by beat strength**: only beats of 0.45 or more stop (strength table in [[Ability Kits Architecture]]). Light cuts get a glint, not a pause.
- **0.12, not 0.** A tiny residual speed keeps the pose alive (a perfectly frozen frame next to a moving camera shake reads as a hitch, not an impact).
- **One at a time** (`stopping` guard). Overlapping hit-stops would multiply speeds.
- **Reduced Motion** disables it entirely, along with the impact flash.

The `d` formula gives 50 ms at the lightest stopping beat and about 89 ms at the heaviest, inside the 50 to 100 ms rule of thumb. The ultimate camera places its impact frames (1/30 s each) **inside** the same hit-stop window and starts its shake when the freeze lets go; see [[Camera Shake and Camera FX]].

### Hit-stop on the target

On enemies animated locally by each client, you can apply the same slow-then-catch-up to the target's flinch track on the attacker's client only. Do not touch server-side state (the enemy's AI timers, root movement); presentation only. For the target, a flinch that starts on the hit and a flash cover most of the effect, so many games skip target hit-stop for regular enemies and keep it for heavy beats.

## Guard and parry

Reference guard numbers:

| Parameter | Value |
|---|---|
| Parry window (from raising guard) | 0.26 s |
| Parry result | no damage, attacker enemy stunned 2.2 s |
| Held block | damage x0.25 |
| Re-arm after releasing guard | 0.55 s |
| Movement while guarding | speed halved |

The guard clip keys the upper body only (Action), so legs keep moving. The guard sets a `GuardingLocal` attribute that blocks swings, turns off the carry layer and cancels equip flourishes. The 0.55 s re-arm prevents "parry spam": without it, tapping guard every 0.26 s keeps a parry window open permanently.

Parry windows and animation: the parry window should start on the **input**, not on the guard clip's pose reaching "up". Input-anchored windows feel fair at any ping; pose-anchored windows punish players for animation fade time.

## Displacement reactions on players

Enemy attacks in the reference project could apply: knockback away from the enemy, knock-up, pull toward the enemy or a shape's centre, hold (rooted), slow, tether (slowed and reeled in, with a drawn chain) and drag (reeled in for a duration). Each is sent as a short message to the client that owns the character, because the player's client owns its character's physics. Animation-wise, knock-ups want a dedicated airborne clip; small knockbacks look fine with the flinch plus the physical push.

## Death as the last reaction

Player death in the reference project: a death clip (hit recoil, kneel, fall onto the back, hold) started via a character attribute, fizzle-out at about 1.55 s, death camera at about 2.45 s, with the old side-topple as a fallback. Enemy deaths hold their last frame (the client stops the track's speed just before the end) and are ground-fitted so corpses do not sink or float; see [[Enemy and NPC Animation]] and [[Ground Fitting Pipeline]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Sword arrives after its sparks in flurries | Plain freeze hit-stop with clock-timed VFX | Catch-up hit-stop |
| Enemy twitches while held or stunned | Flinch not skipped in higher states | Ladder skip rules |
| Stagger feels like lag | Attack clips slowed | Only slow the stagger clip |
| Hits from the left flinch right | Mirrored naming assumption | Define and document the convention |
| Flashes stop appearing in big fights | Highlight limit reached | Pool, cap, bake outlines for crowds |
| Parry spam | No re-arm time | 0.5 s class re-arm |
| Double hit-stop per hit | Upper-body copy fires the same marker | Skip tagged copies |

See also: [[Combat Combo Systems]], [[Ability Kits Architecture]], [[Enemy Animation State Protocol]], [[Camera Shake and Camera FX]], [[VFX Timing with Animation]], [[Boss Animation and Phases]].

## Connected notes
<!-- auto-links:start -->
[[Snippets - Enemy Client Animator]] · [[Combat Animation Craft]] · [[Weapon and Combat Animation]] · [[Hit-Stop]] · [[Combat Systems Architecture]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Animation Start Here]]
<!-- auto-links:end -->
