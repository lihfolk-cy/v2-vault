---
tags: [fundamentals, animate-script, locomotion, emotes, tools, type/guide, area/animation, level/beginner, api/CharacterAppearanceLoaded, api/Humanoid, api/Animator, api/Animation]
---
# The Default Animate Script

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Setting ids before `CharacterAppearanceLoaded` -> Set after appearance loads
> - Avoid: Not stopping playing tracks after swapping ids -> `Stop(0)` the playing tracks
> - Avoid: Stopping all tracks every frame -> Stop only your own tracks, by reference
>
> Cost: TL;DR ~110 tok · whole note ~3.5k tok. Read more: ## How the script reacts to changes · ## Walk and run blending (the part people get wrong) · ## Common mistakes
<!-- tldr:end -->

Every player character gets a LocalScript named `Animate`. It is Roblox's whole default animation system: it listens to Humanoid state events, picks clips from a set of `StringValue` folders, blends walk and run by speed, plays the tool hold, and handles emotes. Most games either customise it (swap ids), replace it (their own controller), or run their own system **on top of it** and hand rare states back. Whichever you do, you need to know what it does, because it keeps running and keeps playing tracks underneath yours.

The internals below are from the R15 Animate script as it ships to characters (structure and constants read from a recent copy; Roblox updates the script occasionally and gates some behaviour behind feature flags, so read your own copy: press Play, find `Workspace.<YourCharacter>.Animate`, copy it). The R6 script is a different, simpler script with the same broad structure.

## Where it lives and how to replace it

- It is inserted into each spawning character. If `StarterPlayer.StarterCharacterScripts` contains a script named `Animate`, **yours is used instead** of the default.
- It runs on the client (LocalScript). Its tracks replicate because they play on the character's server-created Animator.
- Its configuration is data, not code: child `StringValue`s named after each animation set, each holding `Animation` children. You can change those ids at runtime.

## The animation sets

Each set is a `StringValue` child of the script holding one or more `Animation` objects. An `Animation` may carry a `NumberValue` child named `Weight` (default 1). When a set has several animations, one is chosen at random with probability `weight / total weight`.

| Set (StringValue) | Child Animation name(s) per docs | Default weights | Used for |
|---|---|---|---|
| `idle` | `Animation1`, `Animation2` (some packs add a third) | 1, 1 and 9 for the third in the R15 default | standing |
| `walk` | `WalkAnim` | 10 | moving slowly |
| `run` | `RunAnim` | 10 | moving fast |
| `jump` | `JumpAnim` | 10 | Jumping state |
| `fall` | `FallAnim` | 10 | Freefall |
| `climb` | `ClimbAnim` | 10 | Climbing |
| `sit` | (one Animation) | 10 | Seated |
| `swim` | `Swim` | 10 | Swimming, moving |
| `swimidle` | `SwimIdle` | 10 | Swimming, still |
| `toolnone` | (one) | 10 | holding a Tool with a Handle |
| `toolslash`, `toollunge` | (one each) | 10 | legacy tool attacks |
| `wave`, `point`, `laugh`, `cheer` | (one each) | 10 | one-shot emotes |
| `dance`, `dance2`, `dance3` | three each | 10 each | looping emotes |

The docs give the paths used to swap ids: `animate.run.RunAnim.AnimationId`, `animate.walk.WalkAnim.AnimationId`, `animate.jump.JumpAnim`, `animate.idle.Animation1` / `Animation2`, `animate.fall.FallAnim`, `animate.swim.Swim`, `animate.swimidle.SwimIdle`, `animate.climb.ClimbAnim`.

## How the script reacts to changes

`configureAnimationSet` connects `ChildAdded`/`ChildRemoved` on each set and `Changed`/`ChildAdded`/`ChildRemoved` on each Animation. **Any change rebuilds that set** and preloads its tracks. Practical meaning:
- Changing an `AnimationId` on the live character takes effect, but the currently playing track keeps playing until the next time the set is chosen. To force it, stop the playing tracks (the docs' example stops every playing track with `Stop(0)` on `CharacterAppearanceLoaded`, then sets the ids).
- Changing ids in a loop (every frame) rebuilds and reloads constantly. Set once.
- If a set has no Animation children, the script falls back to its built-in default ids.
- The hidden `StarterPlayer.AllowCustomAnimations` (driven by the experience's avatar animation setting) decides whether players' own animation packs apply.

### Swapping a set safely
```lua
--!strict
-- Server Script: give every character a custom run and idle.
local Players = game:GetService("Players")

local RUN_ID = "rbxassetid://1234567890"  -- placeholder ids
local IDLE_ID = "rbxassetid://1234567891"

local function apply(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local animate = character:WaitForChild("Animate")
	-- Stop what is already playing so the new ids are picked up immediately.
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end
	local runAnim = animate:WaitForChild("run"):WaitForChild("RunAnim") :: Animation
	local idle1 = animate:WaitForChild("idle"):WaitForChild("Animation1") :: Animation
	local idle2 = animate:WaitForChild("idle"):WaitForChild("Animation2") :: Animation
	runAnim.AnimationId = RUN_ID
	idle1.AnimationId = IDLE_ID
	idle2.AnimationId = IDLE_ID
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(apply) -- after the avatar's own pack has been applied
end)
```
Waiting for `CharacterAppearanceLoaded` matters: the avatar's animation pack is applied while the appearance loads and would overwrite ids you set earlier.

## Priorities it uses

| Tracks | Priority |
|---|---|
| idle, walk, run, jump, fall, climb, swim, sit, emotes | `Core` |
| `toolnone` (the arm-out tool hold) | `Idle` |
| `toolslash`, `toollunge` | `Action` |

Everything you play at `Idle` or above beats Animate's locomotion on the joints you key; `Movement` and above also beats the tool hold. `Core` is the lowest priority even though its enum value is 1000 (see [[Playback, Priorities and Blending]]).

## The main loop and state handling

- State events (`Running`, `Jumping`, `Climbing`, `Swimming`, `FreeFalling`, `Died`, `GettingUp`, `FallingDown`, `Seated`, `PlatformStanding`) set a `pose` variable and play the obvious clip immediately for running, jumping, climbing, swimming and falling.
- A loop calls `stepAnimate` about every **0.1 s** (`wait(0.1)` in the copies examined). It handles the delayed transitions: jump to fall, sitting, tool animation timers, and stopping animations for Dead / GettingUp / FallingDown / Seated / PlatformStanding poses.
- Transition (fade) times: idle 0.2, walk 0.2, jump 0.1, fall 0.2, climb 0.1, swim 0.4, swimidle 0.4, sit 0.5, toolnone 0.1, slash and lunge 0, emote 0.1 (`EMOTE_TRANSITION_TIME`).
- **Jump to fall:** the jump clip runs for `jumpAnimDuration = 0.31` s; once that has elapsed and the pose is FreeFall, `fall` plays with `fallTransitionTime = 0.2`. Because the loop ticks at 0.1 s, the actual switch can be up to about 0.1 s later.
- **End handling:** a `KeyframeReached` handler watches for keyframes named `End`. For non-looping clips that end, it replays the current animation (re-rolling the weighted choice for multi-clip sets such as idle, which is how idle variations rotate); emotes either loop or return to idle.

## Walk and run blending (the part people get wrong)

The R15 script plays **walk and run together** and cross-fades them by speed. Reconstructed from the script:

```
onRunning(speed):
    heightScale = getHeightScale()           -- 1 for a default-size avatar
    if speed > 0.75 * heightScale:           -- (emotes use a movement-dependent threshold)
        play walk set (fade 0.2); setAnimationSpeed(speed / 16)
    else:
        play idle (fade 0.2)

setRunSpeed(x):                              -- x = speed / 16
    runSpeed = x * 1.25 / heightScale        -- "root motion compensation"
    walk weight, run weight, walk rate, run rate:
      runSpeed <= 0.5        : walk 1,  run ~0,  walk rate = runSpeed / 0.5,  run rate = runSpeed / 1
      0.5 < runSpeed < 1     : crossfade linearly, both rates 1
      runSpeed >= 1          : walk ~0, run 1,   rates as above
    ("~0" = 0.0001, "smallButNotZero", so both tracks keep running and stay in phase)
```

For a default avatar (`heightScale = 1`) that means:

| Ground speed (studs/s) | What plays |
|---|---|
| under 0.75 | idle |
| 0.75 to 6.4 | walk only, rate = speed / 6.4 |
| 6.4 to 12.8 | walk fading into run, both at rate 1 |
| 12.8 and up | run only, rate = speed / 12.8 (so 1.25 at the default `WalkSpeed` 16) |

Consequences:
- At the default `WalkSpeed` 16 a player is always fully in the run clip, at 1.25x speed. Raising `WalkSpeed` to 32 plays the run at 2.5x: feet blur. That is a design choice of the script, not a bug in your clip.
- Your custom walk/run clips should be authored so the walk's stride matches about 6.4 studs/s at rate 1 and the run's about 12.8 studs/s at rate 1 (for a default-size avatar), or the feet will slide.
- Both tracks are always playing; scripts that "stop all tracks except mine" will break the blend.

## Scale handling

`getHeightScale()` returns:
- `HipHeight / 2` (2 being the baseline R15 hip height) when `Humanoid.AutomaticScalingEnabled` is true;
- a damped version if the script has a `ScaleDampeningPercent` NumberValue: `1 + (HipHeight - 2) * value / 2`;
- recent copies use `Character:GetScale()` when automatic scaling is off;
- gated by a feature flag (`UserAnimateScaleRun`) in the copies examined.

Taller avatars therefore play walk/run slower for the same ground speed (longer legs, fewer strides), which keeps feet planted. Climb speed is divided by height scale and then by 5 (`speed / heightScale / 5`); swim switches from swimidle to swim above 1 stud/s and uses `speed / 10`. See [[Scale and Animation]].

## Tools

- When the character holds a `Tool` with a `Handle`, the script plays `toolnone` at `Idle` priority: the right arm held out forward. It keeps playing as long as the tool is held.
- Legacy tool scripts request attacks by inserting a `StringValue` named `toolanim` into the Tool with value `Slash` or `Lunge`. Animate reads it, removes it, plays `toolslash` or `toollunge` (Action priority), and holds that state for 0.3 s (`toolAnimTime`) before returning to `None`.
- **The arm-out problem.** If your weapon has its own hold, or the weapon is sheathed while "equipped", `toolnone` still forces the arm out on any joint your clips do not key. Fixes used in production: play your own carry or idle clip at `Movement` or above that keys the right arm; or fade Animate's `toolnone` track to a tiny weight (one game used 0.001) while the blade is not held; or give the Tool no `Handle` (`RequiresHandle = false`) and attach the model yourself.

## Emotes

- Chat commands `/e <name>` and `/emote <name>` play the named emote, only when the pose is Standing and the name is a known emote.
- The script exposes a `PlayEmote` BindableFunction. It accepts a default emote name or an `Animation` instance and returns `true, track` on success. `Humanoid:PlayEmoteAsync(name)` (the current API; `PlayEmote` is deprecated) plays an emote equipped on the avatar's HumanoidDescription through this path.
- `StarterPlayer.UserEmotesEnabled` turns the emote wheel and user emotes on or off.
- Emotes run at `Core` priority: any of your tracks on the same joints overrides them. Moving cancels non-looping emotes back to idle (the "moved during emote" logic in `onRunning`).
- Looping emotes (dances) keep going until the player moves. Your own systems should stop or override emotes when combat starts.

See [[Emotes and Social Animation]].

## Working with Animate instead of against it

| Goal | Approach |
|---|---|
| Custom idle/walk/run only | Swap ids in the StringValues; author to the 6.4 / 12.8 studs/s stride speeds |
| Full custom locomotion | Replace `Animate` via StarterCharacterScripts, or keep it and play your locomotion at `Movement` priority so it wins everywhere you key |
| Keep Roblox handling climb/swim/sit | Keep Animate; stop your loco tracks in those states so Animate's Core tracks show |
| Remove the tool arm-out | Key the right arm in your own carry layer, or fade `toolnone` |
| Upper-body attacks while walking | Play attacks at Action+ keying only upper-body joints; Animate's walk keeps the legs |

One production game did exactly the "keep it and override" approach: its universal locomotion ran at `Movement` (over Animate and its `toolnone`, under every action), and in Climbing, Swimming, Seated, Ragdoll and PlatformStanding it handed control back to Animate. Its unarmed set even used **copies of Animate's own default clips**, played through its own player, so that unarmed movement looked exactly like Roblox's while sharing its blending and LOD.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Setting ids before `CharacterAppearanceLoaded` | Your ids get overwritten by the avatar's pack | Set after appearance loads |
| Not stopping playing tracks after swapping ids | Old clip until next state change | `Stop(0)` the playing tracks |
| Stopping all tracks every frame | Walk/run blend broken, idle restarts | Stop only your own tracks, by reference |
| Authoring a walk for 16 studs/s at rate 1 | Feet slide (Animate plays it at 2.5x) | Author for 6.4 studs/s, or replace Animate's blending |
| Ignoring `toolnone` | Arm sticks out over your idle | Key the arm at higher priority or fade it |
| Emote keeps dancing during combat | Looks broken | Stop emote tracks when combat starts |

## See also
[[Humanoid States and Animation]] · [[Locomotion Systems]] · [[Playback, Priorities and Blending]] · [[Emotes and Social Animation]] · [[Scale and Animation]] · [[Custom Characters and StarterCharacter]]

## Connected notes
<!-- auto-links:start -->
[[Snippets - Playing Animations]] · [[Custom Locomotion Controller Design]] · [[Bundles Animation Packs and Emotes for Sale]] · [[Snippets - Animation Controller Module]] · Characters and Humanoids · Official Docs - Characters and Animation · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Objects]] · [[AnimationTrack Reference]] · [[R15 Run Cycle Key Poses]] · [[Mounts and Rideable Creatures]] · [[How the Animator Really Behaves]] · [[Replication and Ownership]] · [[Procedural Gait and Footstep Planning]] · [[Engine Gotchas]]
<!-- related:end -->
