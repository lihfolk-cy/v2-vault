---
tags: [systems, enemies, networking, attributes, protocol, code]
---
# Enemy Animation State Protocol

<!-- tldr:start -->
> [!tldr] TL;DR
> - Same attack twice in a row plays once: Listening to `Anim` only -> Always rewrite and listen to `AnimT`
> - Wrong speed on first frames: Client read `Anim` before `AnimSpeed` -> Write `AnimT` last, react to it
> - Late joiners see attacks restart: No offset -> `TimePosition = offset * speed`
>
> Cost: TL;DR ~110 tok · whole note ~3.4k tok. Read more: ## The attributes · ## Joining late · ## Common mistakes
<!-- tldr:end -->

This note specifies a server-to-client protocol for enemy animation: the server writes a handful of replicated attributes with server timestamps; every client plays clips locally, joins late correctly, layers partial clips, detaches parts and fires marker effects. It is the protocol used for the enemy runtime of one live action game (the reference project), generalised. The attribute names below drop that project's prefix (it used `SixAnim`, `SixHurt` and so on); keep a prefix in your own game so attributes from different systems never collide.

## Why a protocol

Three alternatives, and why they lose:

| Approach | Problem |
|---|---|
| Server plays clips on the enemy's Animator | Server CPU per enemy; joint data replicated and interpolated; clients see a smoothed, delayed copy |
| Server fires a RemoteEvent "play X" | Late joiners and streamed-in models miss events; no way to join a clip in progress |
| Client AI predicts animation | Diverges from server truth; hits do not match swings |

Attributes are **state, not events**: a client that streams the model in late reads the current values and reconstructs exactly where the clip should be. Paired with a server timestamp, that gives correct late joins for free.

## The time base

All timestamps are `workspace:GetServerTimeNow()`, which is synchronised across server and clients (to within network jitter). Never use `os.clock()` or `tick()` in attributes; they are per-machine.

## The attributes

| Attribute | Type | Written when | Client behaviour |
|---|---|---|---|
| `Anim` | string | a one-shot or state clip starts (attacks, Spawn, Taunt, Stagger, PhaseShift, Intro, Death); `""` clears | Play it, joined at the right time position |
| `AnimT` | number | with `Anim` (always written, so the same clip twice still triggers) | Start time on the server clock |
| `AnimSpeed` | number | with `Anim` | Playback speed (attack speed buffs, stagger 0.5x) |
| `AnimLoop` | boolean | with `Anim` | Loop instead of one-shot |
| `Hurt` / `HurtT` | string / number | on a hit | Directional flinch (HitFront, HitLeft, HitRight, HeavyHit) at Action2 |
| `Layer` / `LayerT` | string / number | a partial clip once over the base (an arch breaking) | Play at Action3 |
| `State` / `StateT` | string / number | AI state changes (Idle, Move, Attack, Stagger, Caught, Dead...) | Gates loco, loops and the death fit |
| `StunUntil` | number | a parry stun | Stun loop until that server time |
| `Phase` | number | boss phase changes | Phase layers, texture swaps |
| `Detach_<key>` | boolean | a part breaks off | Hide / drop a copy / fade |
| `Retreat` | boolean | AI backing off | Retreat clip instead of walk |
| `Dead` | boolean | death | Stop loco and layers, hold Death, start ground fit |

Write order matters: **write `Anim`, `AnimSpeed`, `AnimLoop` first and `AnimT` last**, and have the client react to `AnimT` changes. Do not rely on the order in which a client's change signals fire for attributes written in the same server frame: a client listening to `Anim` alone can run its handler before it has seen the new `AnimSpeed`, and writing the same clip name twice does not fire a change at all. The reference client connects to `GetAttributeChangedSignal("AnimT")`.

## Priorities by kind

| Kind | Priority | Fade in | Fade out |
|---|---|---|---|
| Idle | Idle | 0.2 | 0.2 |
| Locomotion | Movement | 0.2 | 0.2 |
| One-shot (attacks, spawn, stagger, loops like Stun) | Action | 0.08 (loops 0.1) | 0.1 to 0.15 |
| Hurt (directional flinch, HeavyHit) | Action2 | 0.05 | clip end |
| Layer (partial clips) | Action3 | 0.06 | 0.12 |
| Death | Action4 | 0.08 | never (held) |

Death at the top means nothing, not even a flinch arriving in the same frame, can override the fall. Hurt above one-shots means flinches overlay attacks without stopping them (see [[Hit Reactions Stagger and Hit-Stop]]).

## Joining late

When `AnimT` changes (or when the client first sees a model), compute how far into the clip the server is:

```lua
local function onAnim(st)
	local m = st.model
	local name = m:GetAttribute("Anim") or ""
	if name == "" then stopOneShot(st) return end
	local speed = m:GetAttribute("AnimSpeed") or 1
	local loop = m:GetAttribute("AnimLoop") == true
	local t0 = m:GetAttribute("AnimT") or workspace:GetServerTimeNow()
	local offset = math.max(0, workspace:GetServerTimeNow() - t0) -- seconds of real time since start
	local def = st.def.clips[name] -- duration and marks from data
	-- Joined after a one-shot already ended (model streamed in late): show nothing.
	if def and not loop and not def.loop and name ~= "Death" and offset > def.dur / math.max(speed, 0.05) then
		return
	end
	playOneShot(st, name, speed, loop, offset)
end
```

Inside `playOneShot`:

```lua
local t = trackFor(st, name, if name == "Death" then "death" else "one")
if st.one and st.one ~= t and st.one.IsPlaying then st.one:Stop(0.1) end
t.Looped = loop
t:Play(0.08, 1, speed)
-- offset is real seconds; track time advances at `speed`, so multiply. Skip tiny offsets (normal latency).
if offset > 0.05 and t.Length > 0 then
	t.TimePosition = math.min(offset * speed, t.Length - 0.05)
end
```

Three details:
- **Tiny offsets are ignored** (under 0.05 s). Normal latency would otherwise skip the first frames of every clip on every client, eating anticipation.
- **`TimePosition` is clamped** to `Length - 0.05` so a late join never lands exactly on the end (which would end the clip immediately and fade it out).
- **Death holds.** The client schedules `AdjustSpeed(0)` at `len / speed - offset - 0.06`, just before the end, so the corpse stays in its final pose instead of the Animator's end-of-clip 0.3 s fade back to idle.

### Marker effects when joining late

FX and sound markers (`FX_*`, `Step*`, `Release`) are fired from **data mark times**, scheduled with `task.delay((markTime / speed) - offset)`, skipping marks already in the past. Firing from data rather than `GetMarkerReachedSignal` means:
- effects fire even for clips with no published id (blockout enemies still get sounds),
- a late joiner does not get a burst of every past marker,
- marks can be cancelled with a token when the clip is replaced.

## Clip lookup order

Where the client gets a clip, first match wins:

1. Model attribute `ClipId_<clip>` (set by an install tool; lets one model override).
2. The definition's `clips[clip].id`.
3. **No id**: the Lua keyframe player plays the clip from streamed clip data (compiled and sent once per client per kit; see [[Lua Keyframe Player]]).
4. Studio only: a mirror registered through `KeyframeSequenceProvider` for A/B comparison (these ids never load live).
5. Nothing at all: a **procedural Root-bone pose** (a bob, a lean) so the enemy is never a frozen statue.

The procedural fallback is underrated. It means a model that streams in before its clip data, or a new enemy whose clips are not exported yet, still moves plausibly, and the game is playable.

## Locomotion on the client

Loco is not in the protocol at all: the client derives it from the root's horizontal velocity while `State` is one of the "can move" states (Idle, Move, Spawn, Hurt, Attack, Strike, Guard, Shift, Intro). Velocity already replicates with the physics; sending a loco attribute would only add lag and traffic. Details and rate clamps in [[Enemy and NPC Animation]].

## Loops that follow states

Some loops are implied by state rather than sent:
- `State == "Caught"`: play Knockup (sent as a one-shot), then a **Stun** loop once Knockup finishes.
- `State == "Stagger"` on a flyer: after the Stagger one-shot, a **StaggerGround** loop (it has fallen).
- `StunUntil > now` (parry stun) and not staggered or dead: **Stun** loop.

## Layers

Partial clips over the base, declared in the enemy definition:

| Layer kind | Plays | Example |
|---|---|---|
| Always | from spawn | a spinning rotor |
| By attribute | while an attribute is true | holding a portcullis up |
| With a clip, from/to marks | from mark A to mark B of a one-shot | inflating from `Tele` to `Hit` of an attack |
| If-attribute | a "with" layer only while an attribute holds | a slam that only happens while the portcullis is up |
| Per phase | a loop while `Phase == n` | a floating disk in phase 2 |
| Paused by clips | a phase loop that stops while certain one-shots play | the disk loop pauses when an attack animates the disk itself |

"With" layers compute their delays from data marks divided by speed, minus the join offset, and check a token so a replaced clip cancels its pending layers.

## Detachable parts

`Detach_<key> = true` triggers the definition's detach entry:
- `hide`: set the part's (or a list of parts') `LocalTransparencyModifier` to 1.
- `drop = seconds`: leave a copy lying where it was **at the bone's animated pose** for that long. Using the rest pose drops the part where it would be in the bind pose, visibly teleporting it.
- `fade = seconds`: fade the part out.

Ownership rule: if several keys can hide the same part, it shows only when **no** key hides it. Without this, a phase change that "shows" a part can resurrect one that a break already hid.

## Texture swaps on phase

A definition can map texture attributes to alternates while an attribute is true (a "cracked" skin in a later phase). Cheap, readable phase feedback without new geometry. See [[Boss Animation and Phases]].

## Combos joined part-way

Chained enemy attacks use the protocol's offset deliberately. When an attack's last stage strikes and a chained attack follows at once, the server writes the next clip with `AnimT` **in the past**, so clients join it part-way and its first hit lands exactly the desired telegraph time later:

```
offset = firstHitTime - max(window, minTele, gap)
```

where `window` is the authored warning time for the link (or `Hit - TeleE` from the clip), `minTele` is the minimum telegraph (0.4 s default in the reference), and `gap` the minimum time since the previous hit. The server simply sets `AnimT = now - offset / speed`. The client's ordinary late-join code does the rest; no special combo code on clients.

Server-side rules for links, from the same runtime:
- A link's marker appears only when the previous stage strikes, never earlier.
- If the previous stage was cut short (or missed, when the link requires a hit), the combo ends.
- **Only the last link may be gold** (unblockable). An earlier gold link is turned red at load with a warning; a gold link mid-chain would force a dash that the next link then punishes.
- **Telegraph tokens**: every red, gold or blue marker aimed at a player takes a token on that player until it strikes or cancels. A link whose marker has no free token ends the combo. This caps how many attacks can target one player at once, which keeps crowds fair.

## Server side: writing state

```lua
-- Server: start a clip on an enemy model. The client reacts to AnimT.
local function playOnClients(model: Model, clip: string, speed: number?, loop: boolean?, joinOffset: number?)
	model:SetAttribute("Anim", clip)
	model:SetAttribute("AnimSpeed", speed or 1)
	model:SetAttribute("AnimLoop", loop == true)
	-- joinOffset > 0 starts the clip "in the past" so clients join part-way (combo links).
	model:SetAttribute("AnimT", workspace:GetServerTimeNow() - (joinOffset or 0) / (speed or 1))
end

-- The hit is scheduled from DATA marks, never from a played track:
local function scheduleHit(def, clip: string, speed: number, onHit: () -> ())
	local hitAt = def.clips[clip].marks.Hit
	task.delay(hitAt / speed, onHit)
end
```

The server uses the clip's marker time when the clip exists in data, else fallback mark times from the definition (a default of telegraph at 0.1 s, hit at 0.6 s, duration 1 s in the reference).

## Testing the protocol

- **Dry-run clients**: load the client animator against a fake model whose attributes you set by hand, and step it. The reference project had a dry client for exactly this.
- **Late-join test**: set `AnimT` to `now - 0.7` on a 1.0 s clip and check the track starts at 0.7 x speed.
- **Stream-in test**: move a player far away and back so the model streams out and in mid-attack.
- **Speed test**: an attack at 1.3x must hit at `Hit / 1.3` on both server and client.

See [[Testing Animations in Studio]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Same attack twice in a row plays once | Listening to `Anim` only | Always rewrite and listen to `AnimT` |
| Wrong speed on first frames | Client read `Anim` before `AnimSpeed` | Write `AnimT` last, react to it |
| Late joiners see attacks restart | No offset | `TimePosition = offset * speed` |
| Corpses stand back up | Death not held | `AdjustSpeed(0)` just before the end |
| Burst of sounds on stream-in | Past markers fired | Skip marks before the offset |
| Broken parts reappear | Show and hide from different keys | Show only when no key hides |
| Enemies frozen on join | No clip data yet, no fallback | Procedural root pose |

See also: [[Enemy and NPC Animation]], [[Boss Animation and Phases]], [[Replication and Ownership]], [[Snippets - Enemy Client Animator]], [[Frame Order and RunService Timing]].

## Connected notes
<!-- auto-links:start -->
[[Replication Rules]] · [[Animating Creatures and Monsters]] · [[Markers and Events]] · [[Custom Locomotion Controller Design]] · [[Case Study - Enemy Roster Rebuild]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Animation Start Here]]
<!-- auto-links:end -->
