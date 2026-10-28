---
tags: [systems, vfx, markers, trails, timing, audio, performance]
---
# VFX Timing with Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Sparks before the blade arrives after hit-stops: Plain freeze plus wall-clock effects -> Catch-up hit-stop
> - Sheet of trail under the blade: Trail on through the wind-up -> Trail window on markers, or crescents
> - Streak across the body when a trail enables: Trail not cleared -> `Trail:Clear()` before enabling
>
> Read more (12 KB note): ## Three clocks · ## Layered hits · ## Common mistakes
<!-- tldr:end -->

Visual effects sell an animation only when they land on the right frame. A slash crescent one frame late reads as lag; a trail left on through the wind-up draws a sheet of colour under the blade; an explosion that fires twice reads as a bug. This note covers how to time VFX (and sound) to animation in Roblox: markers as the shared clock, the three clocks that drift apart, trail windows, slash crescents, afterimages, juice beats, layered hits and readability budgets. Numbers come from one live action game (the reference project). Building the effects themselves (particles, beams, meshes) is a separate craft; this note is about **when**.

## One source of truth: markers

Every timed effect should hang off the same data that times damage: the clip's markers (see [[Markers and Events]]).

| Marker | Typical effect |
|---|---|
| `Hit` | Spark at the blade tip, impact sound, local hit-stop, slash crescent |
| `TrailOn` / `TrailOff` | Enable and disable the weapon trail for just the cut |
| Beat names (`Slash`, `Strike`, `Impact`, `Detonate`...) | Shake, glint, flash, tiered VFX by strength |
| `FX_<name>`, `Step*`, `Release` | Enemy effects, footstep sounds, projectile release |
| `Open`, climax marker | Ultimate camera beats, charge and climax VFX |
| Value markers (`StaffSpin = "2,0.5,1,F,0,0"`) | Commands with parameters for code |

The marker is authored once by the animator, survives bakes (the pipeline must guarantee it), and is read by the client for VFX and mirrored by the server for damage (`t = marker - 0.06`, see [[Combat Combo Systems]]). When the clip is retimed, everything moves together.

## Three clocks

Effects fail when they are timed on a different clock from the body:

| Clock | What runs on it | Drifts when |
|---|---|---|
| Track time | The body pose; `GetMarkerReachedSignal` | Speed changes, hit-stop, fades, frame drops (track time is float32, see [[How the Animator Really Behaves]]) |
| Wall clock (`task.delay`, `os.clock`) | Effects scheduled at cast time | Never; it is the reference |
| Server clock (`GetServerTimeNow`) | Damage, enemy reactions, synced events | Offset by latency from the caster's view |

Rules:
- **Effects that sit on the body** (trail, tip spark, hand glow) follow **track time**: fire from markers.
- **Effects scheduled ahead** (a VFX timeline in a move module) use the wall clock, so anything that alters track time must give it back. That is exactly why the reference hit-stop slows to 0.12x for `d` and then runs at 1.88x for `d`: after `2d` the track is back on the wall clock and every pre-scheduled effect still lines up (see [[Hit Reactions Stagger and Hit-Stop]]).
- **Effects on other entities** that the server decides (enemy deaths, ultimate climaxes for onlookers) use server time; the caster can use a local climax to align the impact with its own cut (see [[Cinematic Ultimates]]).

### Speed-aware scheduling

If you schedule from data instead of listening for markers, divide by playback speed and subtract any join offset:

```lua
-- Fire fn at a clip-time mark, for a track started `offset` real seconds ago at `speed`.
local function atMark(markTime: number, speed: number, offset: number, token: {}, current: () -> {}, fn: () -> ())
	local delay = markTime / math.max(speed, 0.05) - offset
	if delay < 0 then return end -- already passed: do not fire late marks on join
	task.delay(delay, function()
		if current() == token then fn() end -- clip replaced or cancelled meanwhile: skip
	end)
end
```

The token check is not optional. Without it, a cancelled attack still fires its later sparks.

## Trail windows

A weapon trail (`Trail` between two attachments on the blade) should cover the cut only. Wind-ups and follow-throughs swing the blade low and back, and a trail there draws a flat sheet under the weapon.

Reference approach for basic swings (earlier version): turn the trail on at `hit - 0.12 s`, call `Trail:Clear()` first (otherwise the trail connects from wherever the blade was when it was last enabled, drawing a streak across the body), and turn it off 0.24 s later.

**Then it was removed for basic swings entirely.** The combo's arm sweeps carried the blade tip 150 to 350 degrees around the body, and even a 0.24 s window wrapped a ribbon around the character on every swing. The cut was shown with **slash crescents** instead. Lesson: trails suit arcs under about 120 degrees; wide sweeps need a drawn shape.

For abilities, the trail is gated by `TrailOn` / `TrailOff` markers so each move's animator decides the window.

## Slash crescents

A crescent is a curved mesh or beam in the swing's plane, spawned on the hit and fading in 0.1 to 0.3 s (rule of thumb). The reference set:
- One shape per swing **direction**: horizontal right to left, horizontal left to right (flipped), rising diagonal, and a 360 ring for the spin finisher. Each combo step carries a `flip` flag so the crescent matches the arm.
- Radius about 15 studs (at 1.6x characters), recoloured by the weapon's colour attribute (a vivid colour derived from the model, stored per weapon).
- An older fallback tweened template slashes forward from 2.6 to 8.5 studs in front of the root (10 on a lunge).

Placing the crescent on the hit (not on the click) is what makes the swing feel like it connects; placing it in the swing's actual plane (not a fixed horizontal) is what makes it feel like the blade drew it.

## Afterimages

Afterimages (ghost copies of the body) show speed. Reference rules:
- Only when the body moves fast through a move: above **26 studs/s** (a run is about 22, so normal running never ghosts).
- One ghost every **0.05 s**, at most **10 per move**.
- On the combo finisher only: 3 dark ghosts, 0.035 s apart, starting **0.06 s before the hit**, alpha 0.45, life 0.22 s. On every cut they read as stray slashes.

## Juice beats

Marker strength drives a ladder of small effects (reference juice module, strengths in [[Ability Kits Architecture]]):

| Strength | Effect at the blade tip | Extra on your own moves |
|---|---|---|
| any | Glint (size 2.5 + 3s, life 0.18 + 0.08s) | |
| 0.45 and up | | Hit-stop |
| 0.5 and up | Glow | |
| 0.8 and up | Streak | Impact flash on screen (also 0.6 and up on top-tier weapons) |

Other players' moves get these extras only within **220 studs** of the camera. Beyond that nobody can see a glint, and the effect budget is better spent close.

Also on every ability: a luminous ribbon off the blade while any ability plays, a pulse of light over the blade at move start, a magic circle and embers under the caster at an ultimate's open.

## Layered hits

A premium hit is a short stack, not one emitter. The reference VFX ladder, in order of appearance:

1. Anticipation (a gather, a charge glint) before the hit.
2. A **flash frame** on the hit.
3. A shockwave ring.
4. The energy body (the main shape: slash, burst, pillar).
5. Directional sparks and debris (along the swing, not radial).
6. Smoke.
7. Lingering residue (scorch, embers).

Timing rule quoted in the project's ladder, from a well-known studio's VFX guidance: if your effects feel long, they are far too long. Value hierarchy: a **white-hot core**, the **weapon colour** at the edges, a **dark rim** for contrast. Bigger tiers (rarities) earn more layers: in the reference, Legendary and up add an impact or shockwave, Mythic a crater, Celestial a slash, Divine dark bursts and smoke columns, Eternal a pillar on the biggest hit.

**No doubling.** When several systems can draw a beat (a kit's own effect, a shared tier layer, an ultimate climax), they **claim** it: `claim(char, {"climax"}, duration)`, and others skip claimed kinds. Without claims, a climax could draw three explosions in one spot.

## Readability budgets

Effects that hide the fight are worse than no effects. A readability pass in the reference project set per-cast budgets:

| Budget | Value |
|---|---|
| Ground "floors" (discs, circles) live at once | 1 (a smaller one never stacks on a live one) |
| Large non-floor pieces | 3 |
| Share of the screen covered | 35% (55% during an ultimate), by scaling pieces down (to at least 0.6) or dropping them |
| Pieces on the camera-to-own-head line | at least 0.75 transparent (0.85 when the camera is inside them) |
| Life caps | 1.4 s (floors 2.2; ultimates 2.0 / 2.8) |
| Lights per kit | 2 (range 18, brightness 1.6) |
| Emitters per kit folder | 16 (was 24) |
| Particles per effect library | 3,200 per 2 s (onlookers half); 5,600 per 2 s for an ultimate caster |

`ParticleEmitter:Emit()` bypasses Roblox's automatic quality thinning of emission rates, so burst-heavy effects must thin themselves by graphics quality. Pool emitters and parts: memory stays allocated until instances are destroyed, and creating effects per hit churns the garbage collector. See [[Performance and Memory]].

## Sound timing

Sounds have their own internal timing: the loudest moment of a whoosh or crack is rarely at sample 0. The reference project measured **onset and peak** for every sound in a palette (a draw scrape peaking at 0.37 s, a quick swish at 0.13 s) and started each sound at `beat - peak` so the peak lands on the visual beat. Swing sounds were cut so their **crack peak lands on the hit**. Enemy sound takes were trimmed to their onset and levelled by measured loudness, so marker time equals heard time. Energy-blade ignition length was even derived from the sound (see [[Equip Draw and Flourish Systems]]).

```lua
-- Play a sound so that its peak lands at `beatAt` (os.clock time).
local function playPeakAt(sound: Sound, peak: number, beatAt: number)
	local startIn = beatAt - peak - os.clock()
	if startIn <= 0 then
		-- late: skip into the sound so the peak is still close to the beat
		sound.TimePosition = math.min(-startIn, peak)
		sound:Play()
	else
		task.delay(startIn, function() sound:Play() end)
	end
end
```

## Double firing from upper-body copies

When a move has a full-body clip and an upper-body copy (see [[Ability Kits Architecture]]), both carry the same markers. A juice module that listened to both fired every spark, hit-stop and flash twice. The fix in every listener: **skip tracks tagged as upper copies** (an attribute on the Animation such as `KitUpper`); the full clip lands the marks. The staff trick handler had the same rule.

## Lua-played clips

If clips play through a Lua keyframe player instead of the Animator, Animator signals (`AnimationPlayed`, `GetPlayingAnimationTracks`) do not see them. Every VFX listener (juice, stance FX, staff spins, flourish controller, ultimate camera) must subscribe to the player's own `OnPlayed` / `PlayingTracks` and marker signals. Missing one is silent: that effect simply never fires live. See [[Lua Keyframe Player]].

## QA

- Capture filmstrips at the marker times, not at round numbers; the frame where the spark appears should show the blade at the contact point.
- In Edit, freeze effects for stills (a "still" flag on the effect layer) and slow them (0.2 to 0.4x) for captures.
- Watch a move at 0.25x playback with effects: misaligned layers are obvious slowed down and invisible at speed until a player feels "something is off".

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Sparks before the blade arrives after hit-stops | Plain freeze plus wall-clock effects | Catch-up hit-stop |
| Sheet of trail under the blade | Trail on through the wind-up | Trail window on markers, or crescents |
| Streak across the body when a trail enables | Trail not cleared | `Trail:Clear()` before enabling |
| Ribbon wraps the body | Trail on wide sweeps | Crescents for sweeps over about 120 degrees |
| Every effect twice | Upper copy and full clip both listened to | Skip tagged copies |
| Effects fire after a cancel | No token on scheduled effects | Token check |
| Sound feels late | Started at the beat, peak later | Start at beat minus peak |
| Fight unreadable in big pulls | No budgets | Floors, piece count, screen share, life caps |

See also: [[Markers and Events]], [[Combat Combo Systems]], [[Hit Reactions Stagger and Hit-Stop]], [[Cinematic Ultimates]], [[Weapon and Combat Animation]], [[Performance and Memory]].

## Connected notes
<!-- auto-links:start -->
[[VFX Design Playbook]] · [[Beams and Trails]] · [[Combat Animation Craft]] · [[Sound Design for Games]] · [[Mesh VFX Packs Built in Blender]] · [[Game Feel and Juice]] · [[Animation Start Here]]
<!-- auto-links:end -->
