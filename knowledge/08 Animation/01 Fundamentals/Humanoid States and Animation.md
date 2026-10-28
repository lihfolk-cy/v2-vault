---
tags: [fundamentals, humanoid, states, locomotion]
---
# Humanoid States and Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating `Jumping(false)` as landing -> `StateChanged` to Landed
> - Avoid: Choosing walk vs idle by state -> Speed thresholds with hysteresis
> - Avoid: `SetStateEnabled` on the server for a player -> Run it on the client
>
> Cost: TL;DR ~100 tok · whole note ~3.0k tok. Read more: ## The states · ## Building animation on states: patterns that work · ## Common mistakes
<!-- tldr:end -->

The `Humanoid` runs a state machine (running, jumping, falling, climbing, swimming, seated and so on) and fires events as it changes state. Character animation is mostly a function of that state plus speed: the default Animate script is little more than a state-to-clip table (see [[The Default Animate Script]]), and most custom locomotion systems start the same way. This note documents every state, every state event with its real semantics, the ownership rules that decide where state code must run, and the traps that make animations lag, stick or fire twice.

## The states

`Enum.HumanoidStateType` (values from the API dump). "Animate" is what the default Animate script plays in that state.

| State | Value | Meaning | Entered | Animate plays |
|---|---|---|---|---|
| `FallingDown` | 0 | Tripped; tries to get up after a short time (about 3 s) | Automatic or `ChangeState` | nothing new (pose "FallingDown") |
| `Ragdoll` | 1 | Hit by something fast, uncontrolled fall; can recover | Deprecated; set manually | nothing new |
| `GettingUp` | 2 | Getting back up after FallingDown (about 3 s) or Ragdoll (about 1 s) | Automatic | nothing new |
| `Jumping` | 3 | Just jumped; brief, then Freefall or Landed | Automatic | jump clip |
| `Swimming` | 4 | In terrain water | Automatic | swim / swimidle |
| `Freefall` | 5 | Falling (after a jump apex or walking off a ledge) | Automatic | fall clip (after the jump clip's time) |
| `Flying` | 6 | Not animated, like PlatformStand | Manual | nothing |
| `Landed` | 7 | Touched ground after Freefall; brief | Automatic | nothing (running state follows) |
| `Running` | 8 | On the ground, **including standing still** | Automatic | idle / walk / run by speed |
| `RunningNoPhysics` | 10 | Running away from physical objects | Deprecated | |
| `StrafingNoPhysics` | 11 | Unused; `ChangeState` to it reverts to RunningNoPhysics | Unusable | |
| `Climbing` | 12 | On a truss or ladder | Automatic | climb clip, speed scaled |
| `Seated` | 13 | In a Seat or VehicleSeat | Automatic | sit clip |
| `PlatformStanding` | 14 | `PlatformStand = true`; free-falls, cannot move | Automatic from the property | nothing (pose stops) |
| `Dead` | 15 | Died; setting it kills the Humanoid | Automatic or owner `ChangeState` | nothing (scripts usually play a death clip or ragdoll) |
| `Physics` | 16 | No automatic transitions, **applies no forces of its own** | Manual only | nothing |
| `None` | 18 | Placeholder for an unknown internal state | Unusable | |

There is **no idle state**. "Standing still" is `Running` with speed near 0. Detect idle from the `Running` event's speed or from the root's velocity.

## State events and what they really mean

| Event | Parameter | Real semantics (docs plus field notes) |
|---|---|---|
| `StateChanged(old, new)` | two states | Fires on every transition. The only reliable way to detect `Landed`. |
| `Running(speed)` | studs/s | Fires as ground speed changes, **with 0 when the Humanoid stops**. On average equals `WalkSpeed` while moving. |
| `Jumping(active)` | boolean | `true` on jump, then `false` shortly after. The `false` is **not** a landing. |
| `FreeFalling(active)` | boolean | Entering/leaving Freefall. Can fire `false` mid-air on a state change; do not use as "landed". |
| `Climbing(speed)` | studs/s | Climb speed when it changes; Humanoids climb at 70% of `WalkSpeed`. Does not always fire 0 when climbing stops. |
| `Swimming(speed)` | studs/s | Swim speed; Humanoids swim at 87.5% of `WalkSpeed`. Same "may not fire 0" caveat. |
| `FallingDown(active)`, `GettingUp(active)`, `Ragdoll(active)`, `PlatformStanding(active)` | boolean | Enter/leave pairs. |
| `Seated(active, seatPart)` | boolean, BasePart | Seat on enter, nil on leave. |
| `Died()` | | Only if the Humanoid is in the Workspace and the Dead state is enabled. |
| `StateEnabledChanged(state, enabled)` | | When `SetStateEnabled` is called. |

## Ownership: where state code must run

- The state machine runs on the **network owner** of the character's root. For a player character that is the player's **client**. The server sees replicated state, later.
- `ChangeState` from a LocalScript works only if that client owns the character; from a server Script only if the server owns it. Calling it from the wrong side silently does nothing.
- `SetStateEnabled` **does not replicate**. Disable `Jumping` on the server and the player can still jump. Disable states on the owning client (for players, a LocalScript in StarterCharacterScripts).
- `Dead` can be set by the owner; setting it kills.
- Speeds you read on the server (`Running` speed, velocities) lag the client by the network delay. Server-side animation decisions for player characters will be late; make them on the client.

So: **player locomotion animation belongs on the client**, driven by the client's state events and the client's view of velocity. NPC state belongs on whichever side owns the NPC's physics (usually the server, unless you deliberately give clients ownership).

## Turning off the brain: EvaluateStateMachine and the Physics state

| Tool | Effect | Use |
|---|---|---|
| `Humanoid.EvaluateStateMachine = false` | No forces, no floor/obstacle sensing (no auto-jump), no collision changes, no automatic transitions. Manually set states and `StateChanged` still fire, so the Animate script still reacts. | NPCs moved entirely by your own code that still want Humanoid features (health, nameplates, accessories) |
| `ChangeState(Physics)` | The Humanoid stops applying forces and stops transitioning until you change state again | Ragdolls, knockbacks driven by physics, vehicles, cutscene puppeting |
| `PlatformStand = true` | PlatformStanding: free-falls, cannot move; jumping does not exit | Stuns, "stunned and spinning" moments |
| `SetStateEnabled(state, false)` | That state can never be entered | Disable climbing on a map with trusses you do not want climbed; keep Ragdoll from ending by disabling GettingUp |

One production combat system kept full body control for abilities while "the kit had control": Physics state, anchored root, PlatformStand, or a custom `KitControl` attribute. Any one of those signals told the locomotion layer to yield.

## Building animation on states: patterns that work

### State plus speed, not state alone
The `Running` state covers idle, walk, run and sprint. Choose the clip by **horizontal speed**, not by the state:

```lua
--!strict
-- A minimal chooser. Thresholds from one production game (characters about 1.6x default size):
-- idle under 1 stud/s, walk under 16, jog under 38, run above. Rates match authored ground speeds.
type Gait = { name: string, groundSpeed: number }
local GAITS: {Gait} = {
	{ name = "Walk", groundSpeed = 11 },
	{ name = "Jog", groundSpeed = 22 },
	{ name = "Run", groundSpeed = 64 },
}

local function choose(speed: number): (string, number)
	if speed < 1 then return "Idle", 1 end
	local g = if speed < 16 then GAITS[1] elseif speed < 38 then GAITS[2] else GAITS[3]
	return g.name, math.clamp(speed / g.groundSpeed, 0.5, 2) -- playback rate so feet match the ground
end
```

Read speed from the root's `AssemblyLinearVelocity` with Y removed, smoothed over a few frames, rather than from `Running(speed)`: the event can stall on moving platforms and does not fire every frame. Keep the stride **phase** when swapping gaits (start the new gait at the same normalised time) so feet do not jump. Details in [[Locomotion Systems]] and [[Custom Locomotion Controller Design]].

### Jump, fall, land
- Play the jump clip on `StateChanged` to `Jumping`. The default Animate script then lets the jump clip run for 0.31 s before allowing the fall clip (its `jumpAnimDuration`).
- One custom controller timed its jump clip at 0.42 s from `Jumping`, then Fall (looped).
- Play a **land** clip only after a meaningful airtime. Field value: more than 0.3 s airborne. Small hops and stair steps flicker through Freefall-Landed; landing on every one looks like stumbling.
- Detect landing with `StateChanged` (`new == Landed` or `old == Freefall and new == Running`), never `Jumping(false)` or `FreeFalling(false)`.

### Hand the rare states back
A custom locomotion layer does not have to own everything. One production game's universal locomotion handled idle/walk/jog/run/jump/fall/land and handed `Climbing`, `Swimming`, `Seated`, `Ragdoll` and `PlatformStanding` back to the default Animate script, by stopping its own tracks in those states and letting Animate's (lower priority) tracks show. Its own tracks ran at `Movement` priority, above Animate's `Core` locomotion, so outside those states they won.

### Dash and the Humanoid's brakes
A Humanoid on the ground brakes toward its move input. If you launch a dash with a `LinearVelocity` from a standstill, the controller fights it and the dash dies early. One fix that worked: for the length of the dash, bind a `RenderStep` callback after the control script that calls `humanoid:Move(dashDirection)`, so the controller "wants" to go that way too.

## Hip height and why crouch clips sink feet

`Humanoid.HipHeight` is how far the Humanoid holds the root above the floor (R15: total height = `0.5 * RootPart.Size.Y + HipHeight`). Clips do not change it. A crouch that lowers `LowerTorso` by 2 studs lowers the body relative to a root that stays at hip height, so the feet go 2 studs into the floor unless the legs bend to compensate. Rules from one project's authoring specs:
- Keep root (LowerTorso) drops shallow: about -1.0 stud at most at that project's scale; deeper drops pushed feet 1-2.5 studs through the floor.
- If a pose must go low (kneel, slam), bend the knees in the clip to keep feet on the ground, or use foot IK at runtime (see [[Foot Placement and Ground IK]]).
- For NPCs, a wrong `HipHeight` makes every clip float or sink: one game fixed HipHeight on 17 enemy templates after ground-fitting their death clips.

## Death

- `Humanoid.BreakJointsOnDeath` (default true) breaks the joints on death: the body falls apart, and any death clip has nothing to drive. Set it false to play a death animation or ragdoll.
- `Humanoid.RequiresNeck` (default true) kills the Humanoid if the neck joint is removed: careful when rebuilding joints at runtime.
- Death clips: one game played a death clip (hit recoil, kneel, fall onto the back, hold) through a character attribute so every client played it, faded the body out at 1.55 s and moved the camera at 2.45 s. The older side-topple stayed as a fallback.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Treating `Jumping(false)` as landing | Land clip plays mid-air | `StateChanged` to Landed |
| Choosing walk vs idle by state | Walk plays while standing on a moving platform, or never stops | Speed thresholds with hysteresis |
| `SetStateEnabled` on the server for a player | Player can still do it | Run it on the client |
| Server deciding player locomotion clips | Animations late by ping | Client-side |
| No airtime threshold for land | Stumble on every step | Land only after > 0.3 s airborne |
| Deep crouch on LowerTorso | Feet through floor | Shallow drops, bent knees, foot IK |
| Forgetting `BreakJointsOnDeath = false` | Death clip never plays | Set it before death |

## See also
[[The Default Animate Script]] · [[Locomotion Systems]] · [[Custom Locomotion Controller Design]] · [[Playback, Priorities and Blending]] · [[Ragdolls and Physics-Based Animation]] · [[Replication and Ownership]] · [[Scale and Animation]]

## Connected notes
<!-- auto-links:start -->
[[Characters and Humanoids]] · [[Snippets - Animation Controller Module]] · [[Links - Humanoids and character controllers]] · [[Snippets - Ragdoll]] · [[Mover Constraints and Physics Controllers]] · [[Custom Character Controllers]] · [[Animation Start Here]]
<!-- auto-links:end -->
