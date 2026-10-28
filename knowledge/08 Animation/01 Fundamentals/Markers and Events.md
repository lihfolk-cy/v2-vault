---
tags: [fundamentals, markers, events, combat, timing]
---
# Markers and Events

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Parry window built from client markers. Symptom: parry feels inconsistent across devices and is exploitable.
> - Avoid: Footstep markers on every far character.
> - Avoid: Renamed marker in one clip. Symptom: one weapon's hits have no sparks.
> - Every gameplay marker also exists in a generated data table; the server reads the table.
> - Listeners connect once per track and disconnect on `Ended`.
> - Upper-body copies are marked so cosmetic listeners skip them.
>
> Cost: TL;DR ~160 tok · whole note ~4.0k tok. Read more: ## Exactly when a marker fires · ## Nuances and edge cases · ## Checklist · ## Common mistakes in production
<!-- tldr:end -->

Markers are how a clip tells code "now": the frame the blade connects, a footstep, the moment a trail should start, the instant a projectile leaves the hand. They are the bridge between animation and gameplay, and in a combat game they carry most of the timing. This note covers the three event mechanisms, exactly when markers fire (and when they silently do not), how to keep server timing honest, and the data-driven patterns that kept one game's 350 markers consistent across bakes, upper-body copies and network relays.

## Three mechanisms

| | `KeyframeMarker` (use this) | Named Keyframe (legacy) | `MarkerCurve` (CurveAnimation) |
|---|---|---|---|
| Lives in | A child of a `Keyframe` | The `Keyframe`'s own Name (anything but "Keyframe") | A curve in a CurveAnimation |
| Authoring | Animation Editor event track ("Add Event", optional parameter), or code `kf:AddMarker(m)` | Rename the keyframe | Curve editor / `InsertMarkerAtTime` |
| Listen | `track:GetMarkerReachedSignal("Hit"):Connect(function(value) end)` | `track.KeyframeReached:Connect(function(name) end)` | Same as KeyframeMarker |
| Payload | `Value` string (the editor's "parameter") | none | marker string |
| Multiple per time | yes | one name per keyframe | yes |

Prefer `KeyframeMarker`. The named-keyframe mechanism still works (the default Animate script relies on keyframes named `End`), but names are easy to lose when tools rebuild clips, carry no value, and cannot be listened to by name.

## Exactly when a marker fires

The rules below come from a Lua re-implementation that matched the real Animator on 319 of 319 marker events in one project, plus the docs.

- A marker at time `m` fires on the **first Animator step whose time interval contains it**: `previousTime < m <= currentTime`. At 60 fps a marker can therefore fire up to about 16.7 ms after its nominal time; on a throttled or LOD-reduced rig, later.
- **Markers at time 0 fire** on the first step after `Play()`.
- If one step jumps past several markers (low frame rate, high speed), **all of them fire**, in time order, on that step.
- **Looping:** markers up to the end fire, then the loop wraps and markers from 0 up to the new time fire in the same step.
- A non-looped track reaching its end fires markers up to and including `Length`.
- Setting `TimePosition` **skips** markers in the jumped span: they do not fire.
- `AdjustSpeed(0)`: nothing fires while paused.
- **After `Stop()`**: the track's time keeps advancing during the fade-out, but in the reference Lua model markers stop firing at `Stop()`. That matches the project's measurements but was not separately verified on the real Animator: do not put essential gameplay markers in the part of a clip that may be cut off by `Stop`.
- The listener receives the marker's `Value` string (the editor calls it the parameter).
- Handlers run as normal signal handlers. With deferred signal behaviour (`Workspace.SignalBehavior`), they run at the next resumption point, not inside the Animator step.

### Markers on other clients
Tracks replicated to other clients are real `AnimationTrack`s on those clients, so they fire markers there too. Hook them with `Animator.AnimationPlayed` (fires for replicated tracks), then connect to the markers you care about. This is how cosmetic effects (footstep dust, weapon trails, sounds) appear for everyone without any networking of the events themselves.

```lua
--!strict
-- Client: attach cosmetic handlers to ANY character's tracks, including other players'.
local function watch(animator: Animator, handlers: {[string]: (track: AnimationTrack, value: string) -> ()})
	local hooked: {[AnimationTrack]: boolean} = setmetatable({}, { __mode = "k" }) :: any
	animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if hooked[track] then
			return -- this track object was already hooked on an earlier Play
		end
		hooked[track] = true
		for name, fn in handlers do
			track:GetMarkerReachedSignal(name):Connect(function(value: string)
				fn(track, value)
			end)
		end
		track.Destroying:Once(function() hooked[track] = nil end)
	end)
end
```

Note the guard: `AnimationPlayed` fires on **every** `Play()`, and the same track object is reused across plays (a cached attack track is played hundreds of times). Connecting on each play would fire each handler once per previous play. Hook each track object once.

## Gameplay timing: do not trust markers on the server

Two problems with using markers directly for gameplay:
1. **The client controls player tracks.** A client can play anything; markers it reports are claims, not facts.
2. **Markers wait for the asset.** Until the clip loads (`Length == 0`) no marker fires at all.

The robust pattern is to **extract marker times into data** when the clip is made, and have every system read the data:

```lua
-- ReplicatedStorage.MoveTimes (generated by a tool from the clips; never hand-edited)
return {
	Slash1 = { length = 0.42, Hit = 0.20, TrailOn = 0.12, TrailOff = 0.26 },
	Slash2 = { length = 0.42, Hit = 0.20, TrailOn = 0.11, TrailOff = 0.27 },
	Finisher = { length = 0.62, Hit = 0.30, TrailOn = 0.18, TrailOff = 0.40 },
}
```

- The **server** schedules damage from the data (adjusted for the track's speed), validates the client's timing against it, and never needs the clip.
- The **client** plays the clip and uses markers for cosmetic sync (trail, sound, camera shake), falling back to the data before the clip has loaded.
- A build step **regenerates the table** whenever clips change, and a dry-run test checks that each chain's hit times equal its Hit markers.

One production game's server hit time was `marker time - 0.06 s` (a small lead so the hit registers as the blade visibly connects despite latency). Its enemy pipeline exported marker times from the source clips into each enemy's definition, so the server never loaded an enemy clip at all: telegraph-to-hit used the clip's marker when a clip existed, else the definition's mark times.

### Chain timings from that game (seconds from swing start to Hit)

| Weapon set | Hits | Minimum gap between swings |
|---|---|---|
| Sword | 0.20 / 0.20 / 0.217 / 0.367 (lunge finisher) | 0.42 |
| Katana | 0.217 / 0.217 / 0.20 / 0.383 | 0.42 |
| Staff | 0.40 / 0.38 / 0.62 | 0.6 |

Rule from the same system: after a later-hitting swing, the next click waits for the hit difference, so a fast click never lands two hits closer than the minimum gap.

## Marker vocabularies that worked

| Domain | Markers |
|---|---|
| Player swings | `Hit`, `TrailOn`, `TrailOff` |
| Abilities | `Hit`, `Hit2`..., cast markers (`Cast`, `Release`, `Burst`, `Fire`) |
| Stance and draw | `Charge`, `Full` (stance); `Draw`, `Cut`, `End` (draw strike) |
| Enemies | `Tele` (telegraph), `Hit`, `Hit2`..., `Proj`, `Summon`, `MoveStart` / `MoveEnd`, `Step`, `FX_<name>`, `Release` |
| Ultimates | `Open`, `Impact` / `Climax` (camera beats) |
| Sounds | `Roar`, `Charge`, `Breath`, `Slam`, `Claw`, footsteps per family |

Keep names short, stable and documented. Renaming a marker silently breaks every listener.

### Parameters in the Value
`Value` is a free string. Use it for parameters so one listener can drive many behaviours:

```lua
-- Marker "StaffSpin" with Value "turns,dur,dir,axis,up,down", e.g. "2,0.35,1,H,0,0"
track:GetMarkerReachedSignal("StaffSpin"):Connect(function(value: string)
	local f = string.split(value, ",")
	local turns = tonumber(f[1]) or 1
	local duration = tonumber(f[2]) or 0.3
	local direction = tonumber(f[3]) or 1
	local axis = f[4] or "H" -- F/R/U = chest axes, H = forearm, or "x:y:z"
	spinHeldStaff(turns, duration, direction, axis)
end)
```

One game drove all its staff hand work this way, because a welded weapon cannot spin itself: `StaffSpin`, `StaffSplit` / `StaffJoin` (dur), `StaffFlip` (dur, state), `StaffThrow` / `StaffCatch`, read on every client on the track's own clock. Its clip specs wrote `mk = "Name=value"` and the builder split that into the marker's Name and Value.

### Beat tables: juice as data
Rather than each move script triggering shake and flashes, map markers to "beats":
```lua
-- MoveBeats[kit][move][marker] = beat kind
local MoveBeats = {
	Ember = { Flare = { Hit = "heavy", Hit2 = "light" }, Nova = { Climax = "ult" } },
}
```
One project had 45 kits, 110 moves and 349 markers in such a table, driving camera shake, VFX tiers and travel moves from one place. See [[VFX Timing with Animation]] and [[Hit Reactions Stagger and Hit-Stop]].

## Traps

### Duplicate firing from layered copies
If a full-body clip and its upper-body copy both play (or a system plays the copy while another plays the original), both fire every marker. One project's effects layer saw marks "fired twice" and from then on skipped upper-body duplicates explicitly. Mark copies (an attribute on the Animation such as `UpperCopy = true`) so listeners can ignore them.

### Tools that eat markers
Every tool that rebuilds a clip (thinning, IK rebakes, stubbing, format conversion) must keep **keyframes that carry markers**, even if they no longer carry poses, and keep marker times exact. One pipeline's rules: drop empty keyframes except the first, the last and any with markers; keep body keys within one frame of a marker; and re-verify marker counts after every bake. Hit timing on the server depended on markers surviving.

### Marker at the very end
A marker exactly at `Length` fires as the clip ends, in the same step that fires `Stopped`. Order between the marker handler and `Stopped` is not something to rely on. Put "end" events slightly before the end, or use `Stopped`.

### Marker after the last pose extends the clip
`Length` is the last keyframe's time. A marker keyframe after the final pose makes the clip longer: the rig holds the last pose until then and the end fade starts later.

### Retiming clips without retiming data
If you change a clip's timing, regenerate the marker table. One ability system read its dash timing from a table of marker times (sheath 0.05 / 0.15 / 0.45 s); a retimed clip with a stale table dashes at the wrong moment.

## Extracting marker times (Studio command bar or plugin)

```lua
--!strict
-- Prints a Lua table of marker times for every KeyframeSequence under a folder.
local function markerTable(folder: Instance): string
	local lines = { "return {" }
	for _, ks in folder:GetDescendants() do
		if ks:IsA("KeyframeSequence") then
			local length, entries = 0, {}
			for _, kf in ks:GetKeyframes() do
				local k = kf :: Keyframe
				length = math.max(length, k.Time)
				for _, m in k:GetMarkers() do
					table.insert(entries, string.format("%s = %.3f", m.Name, k.Time))
				end
			end
			table.insert(lines, string.format("\t[%q] = { length = %.3f, %s },", ks.Name, length, table.concat(entries, ", ")))
		end
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end
print(markerTable(game.ServerStorage.ClipSources))
```
Duplicate marker names in one clip (two `Hit`s) overwrite each other in this simple version; name them `Hit`, `Hit2`.

## Checklist
- [ ] Every gameplay marker also exists in a generated data table; the server reads the table.
- [ ] Listeners connect once per track and disconnect on `Ended`.
- [ ] Upper-body copies are marked so cosmetic listeners skip them.
- [ ] Bakes and conversions preserve marker keyframes; counts verified after each bake.
- [ ] No essential marker in a span that `Stop()` or `TimePosition` jumps can skip.
- [ ] Marker names documented per domain.

## See also
[[AnimationTrack Reference]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Weapon and Combat Animation]] · [[Combat Combo Systems]] · [[VFX Timing with Animation]] · [[Enemy Animation State Protocol]] · [[Replication and Ownership]]

## Nuances and edge cases

1. **Frame rate sets marker precision.** A marker fires on the first step whose interval contains it, so its error is up to one frame: about 4 ms at 240 FPS, 17 ms at 60, 33 ms at 30, 50 ms on a phone dropping to 20. For cosmetic sparks that is invisible. For anything a player times against (a parry window drawn from a marker, a rhythm cue), it is the difference between a fair and an unfair window. Use markers to trigger visuals; use data times compared to a clock for windows.
2. **Throttled and far rigs fire late or in bursts.** When the engine evaluates a distant rig less often, several markers can arrive together. A footstep sound per `Step` marker then plays as a double tap on far characters. Drop or merge cosmetic marker effects beyond a distance rather than playing every one.
3. **Crowd cost.** In a 50-player fight, every client receives marker events for every visible character's attacks. Ten handlers per swing times dozens of swings per second is a lot of small work, plus whatever VFX they spawn. Gate handlers by distance and by importance (your own and your target's at full detail, others reduced), and pool the VFX they spawn.
4. **Exploiters and markers.** Markers fire on the client from the track; a modified client can play any animation on its own character to fire any marker, or skip them. That is why gameplay timing lives on the server's data. The same applies to client-side cosmetic triggers that look like gameplay (a fake "hit" spark can mislead an opponent but cannot deal damage).
5. **Marker names are a schema.** Once several systems listen for `Hit`, `Hit2`, `Tele`, renaming one breaks listeners silently, because a signal for a name that never fires simply never fires. Treat marker vocabularies like a data schema: documented, validated by a tool that lists unknown names per clip, and changed with a migration.
6. **Speed changes stretch everything.** `AdjustSpeed(1.5)` makes markers fire 1.5 times sooner in real time. If the server's data uses unscaled times and the client speeds clips up for an attack speed buff, visuals land before damage. Apply the same speed factor to the server's data timings, from one shared value.
7. **Deferred signals add a frame.** With deferred signal behaviour, a handler runs at the next resumption point, which can push a VFX spawn into the following frame. For a hit spark that should coincide with hit-stop, trigger both from the same handler so they stay together even if both are a frame late.

## Common mistakes in production

1. **Parry window built from client markers.** Symptom: parry feels inconsistent across devices and is exploitable. Fix: server window from data times and receipt time, client marker only for the flash.
2. **Footstep markers on every far character.** Symptom: sound clutter and CPU cost in crowds. Fix: distance cutoff and a per-frame cap on step sounds.
3. **Renamed marker in one clip.** Symptom: one weapon's hits have no sparks. Fix: a validation tool that reports clips missing expected markers.
4. **Speed buff applied to clips only.** Symptom: damage arrives after the swing visually finished. Fix: one speed factor for clip and server data.
5. **VFX created per marker without pooling.** Symptom: GC spikes and frame drops in big fights. Fix: pool effect instances and reuse them.

## Related decisions

- [[Server Authority and Validation]]: why gameplay timing must not come from client markers.
- [[Hitboxes and Hit Detection]]: building hit windows from data times.
- [[Feedback Timing - Sound Visual and Haptic Sync]]: aligning marker-driven sound, VFX and rumble.
- [[VFX Performance Budgets and Culling]]: limiting marker-driven VFX in crowds.
- [[Sound Design for Games]]: footstep and impact sounds that markers trigger.
- [[Data Schema Design and Migrations]]: treating marker vocabularies as a versioned schema.
- [[Events Signals and Connections]]: connection hygiene for marker handlers.
- [[Detecting Combat Exploits - Reach Rate and Aim]]: spotting attack timing that markers alone cannot prove.

## Connected notes
<!-- auto-links:start -->
[[Snippets - Enemy Client Animator]] · [[Combat Animation Craft]] · [[Animation Editor Advanced]] · [[Snippets - Playing Animations]] · [[Building a Signal Library]] · [[Hit-Stop]] · [[Animation Start Here]]
<!-- auto-links:end -->
