---
tags: [authoring, craft, combat, hit-stop, latency, markers, type/guide, area/animation, level/intermediate, api/AdjustSpeed, area/gameplay, api/AnimationTrack]
---
# Combat Animation Craft

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Strike eases into contact -> arrive at speed, decelerate after contact
> - Avoid: Hit-stop baked into the clip -> runtime hit-stop only on confirmed hits
> - Avoid: No input buffer -> buffer during startup/active; execute at the cancel window
> - Something moves on the input frame
> - Anticipation 2 to 6 frames (light) / 6 to 15 (heavy); direction obvious
> - Strike 1 to 3 frames with dense in-betweens and a trail window
>
> Cost: TL;DR ~150 tok · whole note ~4.4k tok. Read more: ## 4. The hit frame and markers · ## 6. Recovery and cancel windows · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

Combat animation is where craft meets frame data. An attack must feel instant to the attacker, be readable to the target and bystanders, line up exactly with damage, survive network delay, and chain into the next action. This note covers the anatomy of an attack (anticipation, active frames, recovery), smears and trails, the hit frame and markers, hit-stop, cancel windows and combos, readability for other players, latency, and layering attacks on movement.

The system side (combo state machines, ability kits) is in [[Combat Combo Systems]], [[Ability Kits Architecture]] and [[Weapon and Combat Animation]]. Swing shapes and weapon mechanics are in [[Weapon Swing Design]].

Labels: "reference project" = measured or standardised in one live action game; "rule of thumb" = common practice.

## 1. Anatomy of an attack

Fighting-game vocabulary is the clearest way to think about it:

| Phase | Also called | What the animation does | What gameplay does |
|---|---|---|---|
| **Startup** | anticipation, wind-up | shows what is coming | no damage yet; often interruptible |
| **Active** | strike, contact | the weapon travels through the hit zone | damage can land |
| **Recovery** | follow-through, settle | returns to ready | vulnerable; may be cancellable late |

Two numbers matter most:
- **Time to hit** (startup + strike): how responsive the attack feels.
- **Total length** (to when the next action can start): how committal it feels.

Reference project values (seconds to hit / minimum gap between attacks):

| Weapon class | Hits in the combo | Minimum gap |
|---|---|---|
| Sword | 0.20 / 0.20 / 0.217 / 0.367 (finisher lunge) | 0.42 |
| Katana | 0.217 / 0.217 / 0.20 / 0.383 | 0.42 |
| Staff | 0.40 / 0.38 / 0.62 | 0.6 |
| Heavy (older set) | 0.42 / 0.38 / 0.74 | 0.7 |

Notice the pattern: fast openers, a slower and bigger finisher. The finisher's longer startup is acceptable because the player chose to continue the combo.

## 2. Startup: anticipation without lag

The player's own attack must react on the input frame, even if the "true" wind-up takes longer:
1. **Frame 0 to 1**: something visibly moves (the shoulder drops, the hips start turning).
2. **Frames 1 to 5** (light attacks, 30 fps): the wind-up pose. The reference project's standard: 2 to 6 frames of anticipation for light player attacks, 6 to 15 for heavy ones.
3. **Hide anticipation in the previous swing.** In a combo, the follow-through of swing N is the wind-up of swing N+1. The reference project's chain rule: each swing starts on the pose the previous one holds at its link, and ends on the class rest pose (idle plus carry).

Pose the wind-up so the **direction** of the coming cut is obvious: the blade cocked on the side it will come from, the torso turned away (about 24 degrees of root yaw in the reference project's flat cuts), the weight on the back foot.

## 3. Active frames: speed, smears and trails

### The strike is fast
At 30 fps a light strike takes 1 to 3 frames. The reference project's standard cites measured sword blade speeds at impact of 1,000 to 2,000 degrees/s, and caps sustained arm joint speeds at 2,200 to 2,600 degrees/s outside a cut's active frames (the strike itself may exceed them: "smear territory").

### Smears on a rigid rig
Film animators draw smear frames (a stretched, blurred shape). Roblox rigs are rigid, so smears come from elsewhere:
- **Trails**: a `Trail` between two attachments on the blade, enabled only during the strike. The reference project gated trails with `TrailOn` / `TrailOff` markers so the trail shows the cut and nothing else.
- **Smear meshes**: a curved slash mesh spawned along the arc for 2 to 4 frames.
- **Motion blur / afterimages**: a few fading copies of the weapon at previous positions.
- **Squash in the body**: the torso and spine compress into the strike and extend at contact.
Timing effects to the animation is covered in [[VFX Timing with Animation]].

### Dense in-betweens on the strike
Fast arcs need samples. The reference project's baker sampled strike segments every **0.035 to 0.045 s** instead of its default 0.1 s, so the arc survived interpolation. With sparse keys, the Animator's joint-space interpolation can cut the corner of a wide arc.

## 4. The hit frame and markers

The hit must happen on one specific, readable frame: the blade at the target with the body fully committed.

- Put a **`Hit` marker** on that frame (a `KeyframeMarker` added with the editor's Animation Events, or in code). Multi-hit moves use `Hit`, `Hit2`, and so on, or one marker name with a parameter.
- **Drive damage from data, verify against markers.** The reference project stored hit times per move in data, checked them equal to the clip's `Hit` marker in dry runs, and had the server apply hits at the **marker time minus 0.06 s**. The server never needed to load the clip.
- **Effects and audio key off the same time.** In the reference project VFX and audio keyed off the swing's hit time, with the audio's crack peak aligned on the hit.
- **Contact moving hold**: 2 to 4 frames of near-zero velocity at contact, then 4 to 8 frames of settle (reference standard).

Listening for markers (client side, for effects):

```lua
--!strict
local function playAttack(animator: Animator, anim: Animation, onHit: (string) -> ())
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	-- connect BEFORE Play so a marker near t = 0 is not missed
	local conn = track:GetMarkerReachedSignal("Hit"):Connect(onHit) -- receives the marker's Value
	track.Stopped:Once(function()
		conn:Disconnect() -- tracks are reused; never leak connections
	end)
	track:Play(0.05) -- short fade for combat (the reference project used 0.05 s)
	return track
end
```

Pitfalls:
- **Double firing**: if both a full-body clip and its upper-body copy play, every marker fires twice. Listen on one of them only.
- **Fade-in eats early markers?** Markers fire by track time, not by weight; a marker at 0.02 s fires during the fade. That is usually what you want for effects, but not for anything that needs the pose visible.
- **Speed changes move markers in real time.** At `AdjustSpeed(1.5)` a hit at 0.30 s clip time arrives 0.20 s after play. Data tables must divide by speed.

## 5. Hit-stop

Hit-stop (hit-lag, hit-freeze) briefly pauses the attacker and the victim on impact. It sells weight more than any pose change. Rules:
- **Runtime, not baked.** The reference project's standard says it plainly: hit-stop is added at runtime by the effects module and is not baked. Baked freezes make whiffs (attacks that hit nothing) look like they hit.
- **Short.** Rule of thumb: 30 to 60 ms for light hits, 80 to 150 ms for heavy hits and finishers. Longer reads as lag.
- **Both sides.** Freeze the attacker's attack track and the victim's reaction; add a small camera shake on the attacker's client.
- **Do not freeze physics or input timers** unless your design wants it; freeze the visuals.

```lua
--!strict
-- Pause one AnimationTrack for `duration` seconds, then restore its speed.
local function hitStop(track: AnimationTrack, duration: number)
	local speed = track.Speed -- current speed (read-only; set via AdjustSpeed)
	track:AdjustSpeed(0)
	task.delay(duration, function()
		if track.IsPlaying then
			track:AdjustSpeed(speed) -- restore whatever speed it had (attack-speed buffs etc.)
		end
	end)
end
```

Notes: stacking two hit-stops on the same track restores the wrong speed; keep one pending restore per track. Marker times in seconds after the hit move later by the hit-stop duration, so server timing must either ignore hit-stop (usual) or add it. See [[Hit Reactions Stagger and Hit-Stop]].

## 6. Recovery and cancel windows

Recovery is where responsiveness is won or lost.
- **Make recovery visually complete but mechanically short.** Let the player cancel into the next attack, a dodge or a block before the clip ends; the next clip's fade-in covers the cut.
- **Mark cancel windows in the clip**, so animators control them: for example a `CancelOpen` marker. Gameplay code reads it; designers tune by moving the marker.
- **Buffer input** during the late startup and active frames, and execute it when the window opens. Without a buffer, players feel dropped inputs.
- **Movement during attacks**: the reference project slowed movement while attacking with a speed scale that went 0.55, then 0.6, then 0.9 (more freedom felt better), applied to the current target speed.
- **End on the class rest.** The last frame must be close to the pose that takes over, because a one-shot that ends holds its last pose and fades out over 0.3 s (measured). The reference project's QA requires the last frame within 75 degrees per arm joint of the idle.

Sketch of a combo step that respects these:

```lua
--!strict
type Combo = {
	animator: Animator,
	clips: { Animation },
	index: number,
	buffered: boolean,
	canChain: boolean,
	current: AnimationTrack?,
}

local function startStep(c: Combo)
	local anim = c.clips[c.index]
	local track = c.animator:LoadAnimation(anim) -- in production cache tracks per clip
	track.Priority = Enum.AnimationPriority.Action4
	c.canChain = false
	c.buffered = false
	track:GetMarkerReachedSignal("CancelOpen"):Once(function()
		c.canChain = true
		if c.buffered then -- the player pressed during startup/active frames
			c.index = c.index % #c.clips + 1
			startStep(c) -- the next swing's 0.05 s fade covers the cut
		end
	end)
	track.Stopped:Once(function()
		if c.current == track then
			c.current = nil
			c.index = 1 -- combo dropped
		end
	end)
	local prev = c.current
	c.current = track -- set BEFORE stopping prev, so prev's Stopped handler sees it is no longer current
	track:Play(0.05)
	if prev then
		prev:Stop(0.05) -- same priority: fade the old swing out while the new one fades in
	end
end

local function onAttackPressed(c: Combo)
	if c.current == nil then
		startStep(c)
	elseif c.canChain then
		c.index = c.index % #c.clips + 1
		startStep(c)
	else
		c.buffered = true
	end
end
```

(Server validation, damage and cooldowns are separate; see [[Combat Combo Systems]].)

## 7. Readability for other players

The attacker knows what they pressed. Everyone else only has the animation, seen late and from any angle.

- **Unique wind-up shapes.** Each attack type has a recognisable startup silhouette.
- **Strike planes that read from behind and the side.** Diagonal planes read better than pure horizontal ones from a third-person camera behind the attacker.
- **Effects carry the arc.** The trail is often the only thing a bystander sees of a 2-frame strike.
- **Sound on the hit frame.** Ears forgive what eyes miss.
- **Enemy telegraphs are long on purpose.** The reference project kept enemy attack markers locked at least **0.45 s** before the blow and boss warnings and combo links at **0.5 s or more**, with **0.40 s** of boss-class dodge i-frames. See [[Animating Creatures and Monsters]] and [[Enemy Animation State Protocol]].
- **Hit reactions confirm hits.** A directional flinch on the victim tells everyone the hit landed and from where. The reference project's enemies had directional hit reactions and skipped flinches while caught, knocked up or stunned, so the important state animation was never interrupted.

## 8. Latency

On Roblox, a player character's animation tracks played on the owning client replicate to the server and other clients (see [[Replication and Ownership]]). Timeline of an attack seen by a bystander:

1. Attacker presses; the attacker's client starts the clip immediately.
2. The play event reaches the server after about half the attacker's round-trip time.
3. The server relays to other clients after about half their round-trip time.
4. The bystander starts the clip from time 0, typically 50 to 200 ms after the attacker did (rule of thumb for normal pings).

Consequences for animation:
- **Startup shorter than the network delay is invisible to others.** A 3-frame wind-up (0.1 s) may never be seen by a bystander on a 150 ms connection; they see the strike first. Make the strike and the trail readable on their own.
- **Do not time damage from what a remote client sees.** Use server-side timing from data (the reference project's `marker - 0.06 s`), validated against server state.
- **Give the attacker immediate feedback** (local hit effects, local hit-stop) and correct if the server disagrees. Waiting for the server makes attacks feel laggy.
- **Preload clips.** A track that loads on first use plays late. The reference project traced an ability that fired "about 5 s late" to its stance clips not being loaded; the fix was creating the tracks and calling `ContentProvider:PreloadAsync` when the kit loaded. Generic lesson: preload every combat clip before it can be used.
- **Custom Lua players** (see [[Lua Keyframe Player]]) must replicate themselves. The reference project batched track events through a remote and a server relay, sending speed changes immediately when they changed by 6% or more and otherwise at most every 0.25 s.

## 9. Attacks on the move: upper-body copies

Players attack while running. A full-body attack stops the legs (it overrides the locomotion's leg keys), which feels sticky.
- Publish an **upper-body copy** of each attack with the hips and legs not keyed (weight 0). The reference project published "<Clip>Upper" variants and set a separate id for them; without one, swings on the move fell back to the full-body clip.
- Choose per move: grounded heavy moves and cinematic moves stay full body; light attacks and casts use the upper copy while moving. The reference project's "walking casts" used upper copies so the legs kept walking.
- **Travel moves** (lunges, dashes) need the whole body. The reference project gave them full body control from frame 0, capped at 0.45 s plus 0.25 s after release.
- Beware the **double marker** problem from section 4 when both copies exist.

### The carry layer
Between attacks the weapon arm holds a carry pose, as a separate one-arm clip:
- Reference project: right arm only, priority Action, faded off while swinging (back in over the swing's last 0.22 s), guarding, dashing, during equip flourishes, while anchored, or during a special idle.
- The carry pose **equals the swings' end pose**, so the forearm does not turn when the swing hands off to the carry.
- A carry at a higher priority (Action2) cancelled equip flourishes and read to other systems as an attack: keep layers at the lowest priority that works. See [[Playback, Priorities and Blending]].

## 10. Clip length is balance

Animation length feeds design numbers. In the reference project an ability's damage floor used `max(0.45 x cooldown, 1.2 x animation length)` per swing pace, and enemy attack tempo was dominated by clip length ("Clip length is most of each cycle, so bigger gains would need faster blows"). When you retime a clip, tell whoever owns balance, and regenerate any marker-time tables.

## 11. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Strike eases into contact | hit looks soft | arrive at speed, decelerate after contact |
| Hit-stop baked into the clip | whiffs look like hits | runtime hit-stop only on confirmed hits |
| No [[Input Buffering\|input buffer]] | dropped combo inputs | buffer during startup/active; execute at the cancel window |
| Ending far from the idle | 0.3 s slide to idle | end on the class rest |
| Full-body attacks while running | legs freeze mid-stride | upper-body copies |
| Damage from client animation timing | inconsistent hits | server timing from data |
| Clips not preloaded | first use plays late | load tracks and preload on equip / kit load |
| Same marker on full and upper copies | effects fire twice | listen to one copy |
| Telegraph shorter than reaction time | unfair enemy attacks | 0.45 to 0.5 s minimum readable warning |

## 12. Checklist

- [ ] Something moves on the input frame
- [ ] Anticipation 2 to 6 frames (light) / 6 to 15 (heavy); direction obvious
- [ ] Strike 1 to 3 frames with dense in-betweens and a trail window
- [ ] `Hit` marker on the contact frame; data hit times match
- [ ] Contact moving hold, then settle
- [ ] Cancel window marked; input buffered
- [ ] Last frame near the class rest; first frame near the previous link pose
- [ ] Upper-body copy if the move can be used while moving
- [ ] Clips preloaded
- [ ] Readable from behind and from a bystander's distance

## See also
[[Weapon Swing Design]], [[Timing Spacing and Frame Charts]], [[Markers and Events]], [[Hit Reactions Stagger and Hit-Stop]], [[Combat Combo Systems]], [[VFX Timing with Animation]], [[Replication and Ownership]], [[Animation Review Checklist]].

## Connected notes
<!-- auto-links:start -->
[[Principles of Animation for Games]] · [[Hitboxes and Hit Detection]] · Hit-Stop · Anticipation · Input Responsiveness Buffering and Coyote Time · Melee Combat System End to End · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Locomotion and Melee Reference Numbers]] · [[Spec-Driven Move Authoring]] · [[Posing and Silhouettes]] · [[Publishing Animations]] · [[Snippets - Playing Animations]] · [[Stance and Charge Moves]] · [[Idle Breathing and Secondary Motion]] · [[Equip Draw and Flourish Systems]]
<!-- related:end -->
